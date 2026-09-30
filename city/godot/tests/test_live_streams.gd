## The live station's streams (Part B's Task 9): `LiveSource`'s terminal,
## console session and board channel against the fake hub's WebSockets.
## The terminal's round trip, its size and its end; the chat created or
## reused, replayed and then live; the board's snapshot and events;
## reconnecting after the backoff, with a fresh token when one is needed;
## the node going offline and coming back; and the fake's drift guard on
## every frame the client sends. Nothing here reaches a real hub, and no
## backoff really waits: the source's `wait` is the test's.
extends "res://tests/station_stubs.gd"

const FakeHub := preload("res://tests/fake_hub/fake_hub.gd")
const Sockets := preload("res://tests/fake_hub/fake_hub_sockets.gd")
const CREDENTIAL_FILE := "user://test_live_streams_credential.json"
const STATION := "stn_build"
const BOARD := "brd_build"


## The backoff's waits: each is recorded, and passes on the next frame,
## or when the test lets it while `hold` is set.
class Waits:
	var asked: Array[float] = []
	var held: Array[Callable] = []
	var hold := false

	func wait(seconds: float, then: Callable) -> void:
		asked.append(seconds)
		if hold:
			held.append(then)
		else:
			LiveSource.later(func() -> void: _pass(then))

	## Lets every held wait pass.
	func release() -> void:
		var due := held
		held = []
		for then in due:
			_pass(then)

	func _pass(then: Callable) -> void:
		if then.is_valid():
			then.call()


## Everything logged while it is added: messages and errors alike.
class LogCapture extends Logger:
	var lines: Array[String] = []

	func _log_message(message: String, _error: bool) -> void:
		lines.append(message)

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		lines.append("%s %s %s:%d %s" % [code, rationale, file, line, function])


## Everything a stream said: its states, failures, and what it carried.
class Heard:
	var states: Array[String] = []
	var failures: Array = []
	var data := PackedByteArray()
	var exits := 0
	var events: Array = []
	var sessions: Array = []
	var replays: Array = []
	var snapshots: Array = []
	var changes: Array = []
	var unsent := 0

	func _init(stream: StationStream) -> void:
		stream.state_changed.connect(func(s: String) -> void: states.append(s))
		stream.unsent.connect(func() -> void: unsent += 1)
		stream.failed.connect(func(reason: Dictionary) -> void: failures.append(reason))
		if stream is StationStream.Terminal:
			stream.data.connect(func(bytes: PackedByteArray) -> void: data.append_array(bytes))
			stream.exited.connect(func() -> void: exits += 1)
		elif stream is StationStream.Chat:
			stream.event.connect(func(e: Dictionary) -> void: events.append(e))
			stream.session.connect(func(row: Dictionary) -> void: sessions.append(row))
			stream.replay_done.connect(func(last: int) -> void: replays.append(last))
		elif stream is StationStream.Board:
			stream.snapshot.connect(func(board_state: Dictionary) -> void: snapshots.append(board_state))
			stream.board_event.connect(func(change: Dictionary) -> void: changes.append(change))

	func seqs() -> Array:
		return events.map(func(e): return e["seq"])

	func text() -> String:
		return data.get_string_from_utf8()


var waits: Waits
## The sockets' clock, which a test may move on: real time plus `skipped_ms`.
var skipped_ms := 0


func fake_hub() -> Variant:
	var hub = FakeHub.new()
	hub.report = runner.fail
	hub.start()
	return hub


## A credential for a device the fake already knows, as a finished sign-in
## leaves one.
func credential_for(hub) -> StationCredential:
	var id: String = hub.serial("dev_")
	hub.devices[id] = {"secret": hub.serial("sec_"), "name": "Agentnagar on test-box", "revoked": false}
	var file := FileAccess.open(CREDENTIAL_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"hub": hub.hub_url, "device_id": id, "secret": hub.devices[id]["secret"]}))
	file.close()
	return StationCredential.new(hub.hub_url, "agentnagar", CREDENTIAL_FILE)


func live(hub) -> LiveSource:
	var source := LiveSource.new(credential_for(hub), hub.hub_url, hub.superpipeline_url)
	waits = Waits.new()
	source.wait = waits.wait
	skipped_ms = 0
	source.clock = func() -> int: return Time.get_ticks_msec() + skipped_ms
	return source


## Waits frame by frame until `done` holds, for at most `most_s` seconds.
func soon(done: Callable, most_s := 5.0) -> bool:
	var began := Time.get_ticks_msec()
	while not done.call():
		if Time.get_ticks_msec() - began > int(most_s * 1000.0):
			return false
		await runner.process_frame
	return true


func done_with(hub, streams: Array = []) -> void:
	for stream in streams:
		stream.close()
	await settle(3)
	assert_eq(hub.violations, [], "the fake saw nothing it does not know")
	hub.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CREDENTIAL_FILE))


## The frames the client sent on sockets of `kind`, parsed.
func frames_of(hub, kind: String) -> Array:
	return hub.frames.filter(func(f): return f["kind"] == kind).map(func(f): return f["frame"])


## Gives the session `count` recorded events, before anyone subscribes.
func seed_events(hub, session_id: String, count: int) -> void:
	var recorded: Array = hub.agentpod["acp_events"]
	for i in count:
		hub.push_chat_event(session_id, recorded[i % recorded.size()]["type"], recorded[i % recorded.size()]["payload"])


## A session for the station, open, as the hub would hold one.
func open_session(hub, id := "acps_open") -> Dictionary:
	var row: Dictionary = hub.agentpod["acp_session"].duplicate(true)
	row.merge({"id": id, "stationId": STATION}, true)
	hub.sessions.push_front(row)
	return row


# ---- The terminal ----

## Round trip: the token in the query (a device token) and no Origin; the
## size sent the moment the socket opens, before anything typed, and again
## once the shell has attached (the hub drops frames before then, and so
## does the fake); keystrokes typed while the connection waits for its
## shell held and sent after it, in order, and those typed with no
## connection yet refused; typing echoed back through base64; control characters written as
## strict JSON; a NUL written by hand as \u0000, and the text "\u0000"
## kept as text; and the shell's end, whose `exit` Godot drops with the
## close, heard by asking the station's health: online, so it exited.
func test_the_terminal_round_trip() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var terminal := source.open_terminal(STATION)
	var heard := Heard.new(terminal)
	terminal.send_resize(120, 40)
	terminal.send_input("early ")
	assert_eq(heard.unsent, 1, "typed before there is a connection: refused, not held")
	assert_eq(heard.states, [], "nothing said inside the call")
	hub.attach_delay_polls = 20
	assert_true(await soon(func() -> bool: return (terminal as LiveSource.LiveTerminal)._socket.is_open()), "the socket opens")
	terminal.send_input("and ")
	assert_eq(terminal.state, "connecting", "but the stream is not open before the shell attaches")
	assert_true(await soon(func() -> bool: return terminal.state == "open"), "it opens")
	assert_true(hub.dropped_before_attach >= 1, "the first size arrived before the shell attached: %d" % hub.dropped_before_attach)
	var upgrade: Dictionary = hub.requests_to("GET /api/stations/:id/terminal")[0]
	assert_eq(upgrade["path"], "/api/stations/stn_build/terminal", "the station's terminal")
	assert_eq(upgrade["query"].keys(), ["token"], "the token in the query, alone")
	assert_eq(hub.tokens[upgrade["query"]["token"]]["kind"], "device", "a device token")
	assert_true(not upgrade["headers"].has("origin"), "no Origin header")
	assert_true(await soon(func() -> bool: return hub.shells.get(STATION, {}).get("size") == [120, 40]), "resized")
	assert_eq(frames_of(hub, "terminal")[0], {"t": "resize", "cols": 120, "rows": 40}, "the size first of all")

	terminal.send_input("ls\r")
	assert_true(await soon(func() -> bool: return heard.text() == "and ls\r"), "typing comes back, what came before attaching first")
	assert_eq(hub.shells[STATION]["input"], "and ls\r", "none of it lost")
	assert_eq(heard.unsent, 1, "and only the one refused")
	terminal.send_input("\u001b[A\u0003")
	assert_true(await soon(func() -> bool: return hub.shells[STATION]["input"].ends_with("\u001b[A\u0003")),
		"an arrow key and Ctrl-C arrive")
	assert_true(hub.frames.back()["text"].contains("\\u001b[A\\u0003"), "written as \\u00XX")
	terminal.send_bytes(PackedByteArray([0x61, 0, 0x62]))
	assert_true(await soon(func() -> bool: return hub.shells[STATION]["input"].ends_with("a" + Sockets.NUL_MARK + "b")),
		"a NUL arrives")
	assert_eq(hub.frames.back()["text"], "{\"t\":\"input\",\"data\":\"a\\u0000b\"}", "written by hand")
	assert_true(terminal.send_bytes(PackedByteArray([0x5c, 0x75, 0x30, 0x30, 0x30, 0x30])), "the text \\u0000")
	assert_true(await soon(func() -> bool: return hub.shells[STATION]["input"].ends_with("\\u0000")), "arrives as text")
	assert_true(not terminal.send_bytes(PackedByteArray([0x61, 0xff, 0])), "bytes that are not UTF-8 are refused, and said so")

	var raw := PackedByteArray([0xff, 0x00, 0x1b, 0x5b, 0x6d])
	var before := heard.data.size()
	hub.push_terminal(STATION, raw)
	assert_true(await soon(func() -> bool: return heard.data.size() >= before + raw.size()), "bytes that are not text")
	assert_eq(heard.data.slice(heard.data.size() - raw.size()), raw, "arrive as the bytes they are")

	hub.end_terminal(STATION)
	assert_true(await soon(func() -> bool: return terminal.state == "closed"), "the shell ended")
	assert_eq(hub.requests_to("GET /api/stations/:id/health").size(), 1, "the station's health asked")
	assert_eq(heard.exits, 1, "and the stream said so, once")
	assert_eq(heard.failures, [], "not a failure")
	assert_eq(waits.asked, [], "and nothing reconnects")
	await done_with(hub)


## The shell outlives its socket: a lost connection shows offline, waits
## a second and reconnects to the same shell, sending its size again
## unasked.
func test_a_lost_terminal_reconnects_to_the_same_shell() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var terminal := source.open_terminal(STATION)
	var heard := Heard.new(terminal)
	terminal.send_resize(100, 30)
	assert_true(await soon(func() -> bool: return terminal.state == "open"), "open")
	terminal.send_input("echo one")
	assert_true(await soon(func() -> bool: return heard.text() == "echo one"), "typed")
	await settle(3)
	var states_before := heard.states.size()
	var resizes := func() -> int: return frames_of(hub, "terminal").filter(func(f): return f["t"] == "resize").size()
	var before: int = resizes.call()
	hub.drop_sockets("terminal")
	assert_true(await soon(func() -> bool: return heard.states.has("offline")), "offline when lost")
	assert_true(await soon(func() -> bool: return terminal.state == "open"), "and open again")
	assert_eq(waits.asked, [1.0], "after one second")
	assert_eq(hub.terminal_attaches, 2, "a second attach")
	assert_true(await soon(func() -> bool: return resizes.call() > before), "the size sent again")
	assert_eq(hub.shells[STATION]["size"], [100, 30], "the size it had")
	terminal.send_input(" two")
	assert_true(await soon(func() -> bool: return hub.shells[STATION]["input"] == "echo one two"), "the same shell")
	assert_eq(heard.states.slice(states_before), ["offline", "open"], "offline, then open once attached")
	assert_eq(heard.failures, [], "no failure")
	await done_with(hub, [terminal])


## The node drops: the hub's `dropNode` ends every attached shell's stream,
## which the hub reads as the shell's end, `{t:"exit"}` and a bare close,
## exactly as a real exit. So a close like that asks the station's health:
## the node is offline, so the shell did not exit. The terminal says
## "Station offline" and reconnects after the backoff, to the same shell
## once the node is back.
func test_a_node_drop_is_offline_not_an_exit() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var terminal := source.open_terminal(STATION)
	var heard := Heard.new(terminal)
	assert_true(await soon(func() -> bool: return terminal.state == "open"), "open")
	terminal.send_input("make")
	assert_true(await soon(func() -> bool: return heard.text() == "make"), "typed")
	waits.hold = true
	hub.set_station_offline(STATION, true)
	assert_true(await soon(func() -> bool: return terminal.state == "offline"), "offline")
	assert_eq(heard.exits, 0, "not an exit")
	assert_eq(heard.failures, [], "not a failure")
	assert_eq(hub.requests_to("GET /api/stations/:id/health").size(), 1, "the health asked")
	assert_eq(waits.asked, [1.0], "and it waits to try again")
	hub.set_station_offline(STATION, false)
	waits.hold = false
	waits.release()
	assert_true(await soon(func() -> bool: return terminal.state == "open"), "back")
	terminal.send_input(" test")
	assert_true(await soon(func() -> bool: return hub.shells[STATION]["input"] == "make test"), "the same shell")
	await done_with(hub, [terminal])


## A socket address that Godot's own URL parser refuses (a port of 0 or
## past 65535, an unclosed `[`, more than one colon) is caught before
## Godot sees it, since Godot logs the whole URL, `?token=` and all: the
## stream fails "no address", and nothing with a token reaches the log.
func test_a_bad_address_never_reaches_the_log() -> void:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var hub = fake_hub()
	var messages := []
	for bad in ["http://127.0.0.1:0", "http://127.0.0.1:70000", "http://[::1", "http://127.0.0.1:1:2"]:
		var source := live(hub)
		source.hub_url = bad
		source.superpipeline_url = bad
		for which in ["terminal", "board"]:
			var stream: StationStream = source.open_terminal(STATION) if which == "terminal" else source.board(BOARD)
			var heard := Heard.new(stream)
			assert_true(await soon(func() -> bool: return stream.state == "closed"), bad + ": closed")
			assert_eq(heard.failures.size(), 1, bad + ": failed")
			assert_true(heard.failures[0]["message"].begins_with(LiveSource.NO_ADDRESS), bad + ": no address")
			messages.append(heard.failures[0]["message"])
	OS.remove_logger(capture)
	var logged := "\n".join(capture.lines) + "\n".join(runner.errors)
	assert_true(not logged.contains("token="), "no token query in the log")
	for token in hub.tokens:
		assert_true(not logged.contains(token), "no token in the log")
	assert_eq(runner.errors, [], "and no engine error")
	await done_with(hub)


## A link that goes quiet is noticed: pings every `heartbeat_s` (20 s in
## play) go unanswered, and the socket counts as lost; and a handshake
## that never finishes is given up after 10 s on the socket's clock. Both
## are losses like any other: offline, and the backoff.
func test_a_silent_link_is_noticed() -> void:
	var hub = fake_hub()
	var source := live(hub)
	source.heartbeat_s = 0.2
	open_session(hub)
	var chat := source.watch_chat(STATION)
	var heard := Heard.new(chat)
	assert_true(await soon(func() -> bool: return chat.state == "open"), "open")
	waits.hold = true
	hub.silent = true
	assert_true(await soon(func() -> bool: return chat.state == "offline", 3.0), "a link that stops answering pings is lost")
	assert_eq(waits.asked, [1.0], "and waited on")
	waits.release()
	await settle(10)
	assert_eq(chat.state, "offline", "a handshake with no answer")
	assert_eq(waits.asked.size(), 1, "is waited for")
	skipped_ms += 10001
	assert_true(await soon(func() -> bool: return waits.asked.size() == 2), "until its deadline passes")
	assert_eq(waits.asked, [1.0, 2.0], "then the backoff")
	hub.silent = false
	waits.hold = false
	waits.release()
	assert_true(await soon(func() -> bool: return chat.state == "open"), "and back when the hub answers")
	assert_eq(heard.failures, [], "no failure")
	await done_with(hub, [chat])


## Ruling: keystrokes typed while the terminal is offline are refused and
## said to be unsent, never held for later: replaying minutes-old input
## into a shell is dangerous. The Terminal app shows "Not sent". Only what
## is typed between a connection opening and its shell attaching is held.
func test_keystrokes_while_offline_are_not_sent() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var app := open("terminal", source, _station(), false, fresh_settings()) as TerminalApp
	var terminal := app.stream
	var heard := Heard.new(terminal)
	assert_true(await soon(func() -> bool: return terminal.state == "open"), "open")
	waits.hold = true
	hub.drop_sockets("terminal")
	assert_true(await soon(func() -> bool: return terminal.state == "offline"), "offline")
	assert_eq(app.error_text(), StationApp.OFFLINE, "offline")
	app.send("ls\r")
	assert_eq(app.error_text(), TerminalApp.NOT_SENT, "the app says it was not sent")
	assert_eq(heard.unsent, 1, "the app passed it on, and the stream refused it")
	terminal.send_input("rm -rf build\r")
	assert_eq(heard.unsent, 2, "as it refuses any, and says so")
	waits.release()
	assert_true(await soon(func() -> bool: return terminal.state == "open"), "back")
	assert_eq(app.error_text(), "", "the line goes")
	terminal.send_input("pwd\r")
	assert_true(await soon(func() -> bool: return hub.shells[STATION]["input"] == "pwd\r"), "only what came after")
	close(app)
	await done_with(hub)


## Through the Terminal app: what is typed while the connection waits for
## its shell ("connecting", the socket open) goes to the stream, which
## holds it and sends it in order once the shell attaches, with no "Not
## sent". Typed while offline, it is not sent and the app says so, once
## for each thing typed, bytes included.
func test_the_terminal_app_holds_what_is_typed_while_connecting() -> void:
	var hub = fake_hub()
	var source := live(hub)
	hub.attach_delay_polls = 30
	var app := open("terminal", source, _station(), false, fresh_settings()) as TerminalApp
	var terminal := app.stream as LiveSource.LiveTerminal
	var heard := Heard.new(terminal)
	assert_true(await soon(func() -> bool: return terminal._socket.is_open()), "the socket opens")
	assert_eq(terminal.state, "connecting", "while the shell attaches")
	app.send("echo ")
	app.send_bytes(PackedByteArray([0x61, 0, 0x62]))
	app.send(" done\r")
	assert_eq(app.error_text(), "", "no Not sent")
	assert_true(await soon(func() -> bool: return terminal.state == "open"), "attached")
	assert_true(await soon(func() -> bool: return hub.shells[STATION]["input"] == "echo a" + Sockets.NUL_MARK + "b done\r"),
		"sent in order once attached: %s" % hub.shells.get(STATION, {}).get("input", ""))
	assert_eq(heard.unsent, 0, "nothing refused")
	assert_eq(app.not_sent_shown, 0, "and nothing said to be unsent")

	app.send_bytes(PackedByteArray([0x61, 0xff]))
	assert_eq(app.not_sent_shown, 1, "bytes that cannot be sent: said once")
	assert_eq(app.error_text(), TerminalApp.NOT_SENT, "as not sent")

	waits.hold = true
	hub.drop_sockets("terminal")
	assert_true(await soon(func() -> bool: return terminal.state == "offline"), "offline")
	var shown := app.not_sent_shown
	app.send("ls\r")
	assert_eq(app.not_sent_shown, shown + 1, "typed while offline: said once")
	app.send_bytes(PackedByteArray([0]))
	assert_eq(app.not_sent_shown, shown + 2, "bytes while offline: said once")
	assert_eq(app.error_text(), TerminalApp.NOT_SENT, "as not sent")
	waits.hold = false
	waits.release()
	assert_true(await soon(func() -> bool: return terminal.state == "open"), "back")
	assert_true(not hub.shells[STATION]["input"].contains("ls"), "and what was typed offline never went")
	close(app)
	await done_with(hub)


## Held input has a limit; past it, what cannot be kept is refused and
## said to be unsent, and what was kept goes in order. The chat's outbox
## too.
func test_overflow_is_reported() -> void:
	var hub = fake_hub()
	var source := live(hub)
	hub.attach_delay_polls = 30
	var terminal := source.open_terminal(STATION) as LiveSource.LiveTerminal
	var heard := Heard.new(terminal)
	terminal.max_held_bytes = 80
	assert_true(await soon(func() -> bool: return terminal._socket.is_open()), "the socket opens")
	terminal.send_input("one ")
	terminal.send_input("two ")
	terminal.send_input("three is too many ")
	assert_eq(heard.unsent, 1, "past the limit, refused and said")
	assert_true(await soon(func() -> bool: return hub.shells.get(STATION, {}).get("input", "") == "one two "), "the rest, in order")
	terminal.close()

	# Held for one connection's shell only: lost before it attaches, what
	# was held is dropped, said to be unsent, and never reaches the next.
	hub.attach_delay_polls = 100000
	terminal = source.open_terminal(STATION) as LiveSource.LiveTerminal
	heard = Heard.new(terminal)
	waits.hold = true
	assert_true(await soon(func() -> bool: return terminal._socket.is_open()), "another socket")
	terminal.send_input("held ")
	assert_eq(heard.unsent, 0, "held")
	hub.drop_sockets("terminal")
	assert_true(await soon(func() -> bool: return terminal.state == "offline"), "lost before attaching")
	assert_eq(heard.unsent, 1, "the held keystrokes dropped, and said so")
	hub.attach_delay_polls = 3
	waits.hold = false
	waits.release()
	assert_true(await soon(func() -> bool: return terminal.state == "open"), "back")
	terminal.send_input("new ")
	assert_true(await soon(func() -> bool: return hub.shells[STATION]["input"].ends_with("new ")), "sent")
	assert_true(not hub.shells[STATION]["input"].contains("held"), "and the held ones never were")
	terminal.close()
	waits.hold = false

	open_session(hub)
	var chat := source.open_chat(STATION, "ask") as LiveSource.LiveChat
	var chat_heard := Heard.new(chat)
	chat.max_outbox = 2
	assert_true(await soon(func() -> bool: return chat.state == "open"), "the chat")
	waits.hold = true
	hub.drop_sockets("chat")
	assert_true(await soon(func() -> bool: return chat.state == "offline"), "offline")
	chat.prompt("first")
	chat.prompt("second")
	chat.prompt("third")
	assert_eq(chat_heard.unsent, 1, "the third refused, and said")
	waits.release()
	assert_true(await soon(func() -> bool: return chat_heard.events.size() == 2), "back")
	assert_eq(chat_heard.events.map(func(e): return e["payload"]["text"]), ["first", "second"], "the kept ones, in order")
	await done_with(hub, [chat])


## A clean close whose health answer is a refusal says why, rather than
## that the shell exited: no access (403), or a station that is gone (404).
func test_a_refused_health_after_a_clean_close_says_why() -> void:
	var hub = fake_hub()
	var source := live(hub)
	for case in [[403, "no_access", "You don't have access to this station"],
			[404, "not_found", "This station no longer exists"]]:
		var terminal := source.open_terminal(STATION)
		var heard := Heard.new(terminal)
		assert_true(await soon(func() -> bool: return terminal.state == "open"), "open")
		hub.answer_with("hub", "GET /api/stations/:id/health", case[0], {"error": "refused"})
		hub.end_terminal(STATION)
		assert_true(await soon(func() -> bool: return terminal.state == "closed"), "%d: closed" % case[0])
		assert_eq(heard.exits, 0, "%d: not an exit" % case[0])
		assert_eq(heard.failures.map(func(f): return f["kind"]), [case[1]], "%d: %s" % [case[0], case[1]])
		assert_true(heard.failures[0]["message"].begins_with(case[2]), "%d: %s" % [case[0], heard.failures[0]["message"]])
	await done_with(hub)


## A 1011 is the hub's server error: the node offline, `term.open` failed,
## or the station not found (agentpod@9bc1997:
## apps/hub/src/routes/station-terminal.ts). The station's health tells
## which, as after a clean close: a station gone is "This station no
## longer exists" (it never reconnects), and a station online or its node
## offline is a reconnection after the backoff.
func test_a_1011_asks_the_station_s_health() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var gone := source.open_terminal("stn_gone")
	var heard := Heard.new(gone)
	assert_true(await soon(func() -> bool: return gone.state == "closed"), "a station gone: closed")
	assert_eq(heard.failures.map(func(f): return f["kind"]), ["not_found"], "not found")
	assert_true(heard.failures[0]["message"].begins_with(LiveSource.STATION_GONE), heard.failures[0]["message"])
	assert_eq(hub.requests_to("GET /api/stations/:id/health").size(), 1, "asked once")
	assert_eq(waits.asked, [], "and never reconnects")
	var terminal := source.open_terminal(STATION)
	heard = Heard.new(terminal)
	assert_true(await soon(func() -> bool: return terminal.state == "open"), "open")
	hub.close_sockets("terminal", 1011, "term.open failed")
	assert_true(await soon(func() -> bool: return heard.states.has("offline")), "offline")
	assert_true(await soon(func() -> bool: return terminal.state == "open"), "the station well: back after the backoff")
	assert_eq(waits.asked, [1.0], "a second later")
	assert_eq(heard.exits, 0, "not an exit")
	assert_eq(heard.failures, [], "nor a failure")
	await done_with(hub, [terminal])


## A handshake refused before the upgrade (401) exchanges the token again
## and retries at once. 1008 (the route's own refusal, after the upgrade)
## does too, once; a second is `no_access`. (The route's 1008
## "Unauthorized" is for an anonymous caller, whom the hub's middleware
## answers 401 before the upgrade: see the next tests.)
func test_terminal_refusals() -> void:
	var hub = fake_hub()
	var source := live(hub)
	hub.refuse("hub", 401, 1)
	var terminal := source.open_terminal(STATION)
	var heard := Heard.new(terminal)
	assert_true(await soon(func() -> bool: return hub.shells.has(STATION)), "a refusal once is retried")
	assert_eq(hub.requests_to("POST /api/auth/devices/token").size(), 2, "with a token exchanged again")
	assert_eq(waits.asked, [], "at once")
	assert_eq(heard.failures, [], "and nothing failed")
	terminal.close()
	_take_refused_handshake_errors(source)

	hub.refuse("hub", 403, 2)
	terminal = source.open_terminal(STATION)
	heard = Heard.new(terminal)
	assert_true(await soon(func() -> bool: return terminal.state == "closed"), "refused twice")
	assert_eq(heard.failures.map(func(f): return f["kind"]), ["no_access"], "no access")
	assert_eq(heard.failures[0]["message"], "You don't have access to this (WS /api/stations/:id/terminal, 1008)",
		"a fixed line, the route and the close code")
	assert_true(source.credential.is_signed_in(), "still signed in")

	await done_with(hub)


# ---- The chat ----

## Opening with none open creates a session and subscribes from 0: the
## session row, the replay in order, replay-done, then live events. Opened
## again, it attaches to the open one, with no POST. An event whose `seq`
## is 0 is passed on but never moves the cursor.
func test_the_chat_replays_then_goes_live() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var chat := source.open_chat(STATION, "ask") as LiveSource.LiveChat
	var heard := Heard.new(chat)
	assert_true(await soon(func() -> bool: return chat.state == "open"), "open")
	assert_eq(hub.requests_to("POST /api/stations/:id/acp/sessions").size(), 1, "a session made")
	var session_id: String = chat.session_row["id"]
	assert_eq(hub.requests_to("GET /api/acp/sessions/:id/ws")[0]["path"], "/api/acp/sessions/%s/ws" % session_id,
		"its socket, at once")
	assert_eq(hub.subscribes, [0], "subscribed from the start")
	assert_eq(heard.sessions.size(), 1, "the session row")
	chat.close()

	seed_events(hub, session_id, 3)
	var again := source.open_chat(STATION, "ask") as LiveSource.LiveChat
	heard = Heard.new(again)
	assert_true(await soon(func() -> bool: return heard.replays == [3]), "replayed")
	assert_eq(hub.requests_to("POST /api/stations/:id/acp/sessions").size(), 1, "no new one asked for")
	assert_eq(again.session_row["id"], session_id, "the open one, attached to")
	assert_eq(heard.seqs(), [1, 2, 3], "the transcript, in order")
	assert_eq(heard.sessions.size(), 1, "after its row")

	hub.push_chat_event(session_id, "agent-update", hub.agentpod["acp_events"][2]["payload"])
	assert_true(await soon(func() -> bool: return heard.seqs() == [1, 2, 3, 4]), "then live")
	hub.push_unsequenced_error(session_id, "Couldn't understand that message.")
	assert_true(await soon(func() -> bool: return heard.events.size() == 5), "a seq 0 error is passed on")
	assert_eq(again.last_seq, 4, "and moves nothing")
	await done_with(hub, [again])


## What the player sends: a prompt, a permission answer, a mode switch
## (whose answer is a later session row) and a cancel, each frame as
## recorded; the drift guard checks every one.
func test_the_chat_sends_prompts_answers_and_modes() -> void:
	var hub = fake_hub()
	var source := live(hub)
	open_session(hub)
	var chat := source.open_chat(STATION, "ask")
	var heard := Heard.new(chat)
	assert_true(await soon(func() -> bool: return chat.state == "open"), "open")
	chat.prompt("run the tests")
	assert_true(await soon(func() -> bool: return heard.events.size() == 1), "the prompt comes back as an event")
	assert_eq(heard.events[0]["type"], "user-prompt", "a user prompt")
	assert_eq(heard.events[0]["payload"], {"text": "run the tests"}, "with its text")
	chat.answer(1, "opt_1")
	assert_true(await soon(func() -> bool: return heard.events.size() == 2), "an answer")
	assert_eq(heard.events[1]["payload"], {"requestSeq": 1, "optionId": "opt_1"}, "to its request")
	chat.set_mode("accept-edits")
	assert_true(await soon(func() -> bool: return heard.sessions.size() == 2), "a later session row")
	assert_eq(heard.sessions[1]["mode"], "accept-edits", "says the new mode")
	chat.cancel()
	assert_true(await soon(func() -> bool: return hub.cancels == 1), "a cancel")
	assert_eq(frames_of(hub, "chat"), [
		{"t": "subscribe", "sinceSeq": 0},
		{"t": "prompt", "text": "run the tests"},
		{"t": "permission-answer", "requestSeq": 1, "optionId": "opt_1"},
		{"t": "set-mode", "mode": "accept-edits"},
		{"t": "cancel"},
	], "every frame, as recorded")
	await done_with(hub, [chat])


## Sent while the chat is retrying, a message is kept, never lost: the
## state is `offline` meanwhile, and the message goes once the chat has
## subscribed again, after the subscribe. A refusal (1008) retried is
## offline too, never `open` with no socket.
func test_the_chat_keeps_what_is_sent_while_retrying() -> void:
	var hub = fake_hub()
	var source := live(hub)
	open_session(hub)
	var chat := source.open_chat(STATION, "ask")
	var heard := Heard.new(chat)
	assert_true(await soon(func() -> bool: return chat.state == "open"), "open")
	waits.hold = true
	hub.drop_sockets("chat")
	assert_true(await soon(func() -> bool: return chat.state == "offline"), "offline while retrying")
	chat.prompt("while away")
	chat.cancel()
	waits.release()
	assert_true(await soon(func() -> bool: return hub.cancels == 1), "sent once back")
	assert_eq(frames_of(hub, "chat").slice(1), [{"t": "subscribe", "sinceSeq": 0}, {"t": "prompt", "text": "while away"},
		{"t": "cancel"}], "after subscribing again, in order")
	assert_true(heard.events.any(func(e): return e["payload"].get("text") == "while away"), "and the hub took it")

	var open_states := heard.states.size()
	hub.close_sockets("chat", 1008, "Unauthorized")
	assert_true(await soon(func() -> bool: return heard.states.size() >= open_states + 2), "refused while open, and back")
	assert_eq(heard.states.slice(open_states), ["offline", "open"], "offline while the refusal is retried")
	var states_before := heard.states.size()
	hub.expire_tokens()
	source.credential.refresh_margin_s = 0.0
	hub.drop_sockets("chat")
	waits.hold = false
	assert_true(await soon(func() -> bool: return hub.unauthorized >= 1 and chat.state == "open"), "refused, then back")
	assert_eq(heard.states.slice(states_before), ["offline", "open"], "offline throughout the retry")
	_take_refused_handshake_errors(source)
	await done_with(hub, [chat])


## The session ending closes the socket (1000) with `bye`, and Godot drops
## the frames that come with a close (the `state` event among them), so
## the chat reads the row again: it passes on the ended row and, the row's
## `lastSeq` being the next, the `ended` state rebuilt from it, and closes
## and never reconnects.
func test_an_ended_session_closes_the_chat() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var row := open_session(hub)
	var chat := source.watch_chat(STATION)
	var heard := Heard.new(chat)
	assert_true(await soon(func() -> bool: return chat.state == "open"), "watching")
	hub.push_chat_event(row["id"], "state", {"status": "ended", "reason": "Ended from the console."})
	assert_true(await soon(func() -> bool: return chat.state == "closed"), "closed")
	assert_eq(heard.sessions.back()["status"], "ended", "the row read again says it ended")
	assert_eq(hub.requests_to("GET /api/stations/:id/acp/sessions").size(), 2, "read over REST")
	assert_eq(heard.events.size(), 1, "and the lost event is recovered")
	assert_eq(heard.events[0]["seq"], 1, "at the row's lastSeq")
	assert_eq(heard.events[0]["type"], "state", "a state")
	assert_eq(heard.events[0]["payload"], {"status": "ended", "reason": "Ended from the console."}, "ended, with its reason")
	assert_eq((chat as LiveSource.LiveChat).last_seq, 1, "the cursor with it")
	assert_eq(heard.failures, [], "not a failure")
	assert_eq(waits.asked, [], "and it does not reconnect")
	assert_eq(hub.requests_to("POST /api/stations/:id/acp/sessions"), [], "watching never makes a session")
	await done_with(hub)


# ---- The board ----

## The board's channel: the token only in its Authorization header, the
## snapshot first, then events; nothing is ever sent on it. `gate.opened`
## names a new gate without carrying it, so the channel connects again
## and passes on a fresh snapshot, which has it.
func test_the_board_sends_its_snapshot_then_events() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var board := source.board(BOARD)
	var heard := Heard.new(board)
	assert_true(await soon(func() -> bool: return heard.snapshots.size() == 1), "the snapshot")
	assert_eq(heard.snapshots[0], hub.superpipeline["snapshot"], "the whole board")
	assert_eq(board.state, "open", "open")
	var upgrade: Dictionary = hub.requests_to("GET /v1/boards/:id/ws")[0]
	assert_eq(upgrade["query"], {}, "no token in the query")
	var bearer: String = upgrade["headers"].get("authorization", "")
	assert_true(bearer.begins_with("Bearer ") and hub.tokens[bearer.substr(7)]["kind"] == "device",
		"a device token in the header, which carries Superpipeline's audience")

	var recorded: Dictionary = hub.superpipeline["board_events"]
	var moved: Dictionary = hub.push_board_event("card.moved", recorded["card.moved"]["payload"])
	assert_true(await soon(func() -> bool: return heard.changes.size() == 1), "an event")
	assert_eq(heard.changes[0], moved, "as sent")
	assert_true(heard.changes[0]["ts"] is String, "its ts an ISO string")

	var gate: Dictionary = hub.superpipeline["snapshot"]["gates"][0].duplicate(true)
	gate.merge({"id": "gate_new", "cardId": "crd_sample_json", "status": "pending"}, true)
	hub.superpipeline["snapshot"]["gates"].append(gate)
	hub.push_board_event("gate.opened", recorded["gate.opened"]["payload"])
	assert_true(await soon(func() -> bool: return heard.snapshots.size() == 2), "a fresh snapshot")
	assert_true(heard.snapshots[1]["gates"].any(func(g): return g["id"] == "gate_new"), "holding the new gate")
	assert_eq(hub.requests_to("GET /v1/boards/:id/ws").size(), 2, "from a new connection")
	assert_eq(heard.states, ["open"], "the board stayed open throughout")
	hub.push_board_event("card.advanced", recorded["card.advanced"]["payload"])
	assert_true(await soon(func() -> bool: return heard.changes.size() == 3), "and events go on")
	assert_eq(frames_of(hub, "board"), [], "nothing was ever sent on it")
	await done_with(hub, [board])


## New gates and questions reconnect the board at most once a second: the
## first at once; those that come on the new connection within the second
## wait, together, for its end. (Events still on the old connection when
## it reconnects are in the fresh snapshot anyway.)
func test_board_refreshes_are_at_most_one_a_second() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var board := source.board(BOARD)
	var heard := Heard.new(board)
	assert_true(await soon(func() -> bool: return heard.snapshots.size() == 1), "open")
	var recorded: Dictionary = hub.superpipeline["board_events"]
	var began := Time.get_ticks_msec()
	hub.push_board_event("gate.opened", recorded["gate.opened"]["payload"])
	assert_true(await soon(func() -> bool: return heard.snapshots.size() == 2), "one refresh at once")
	hub.push_board_event("elicitation.opened", recorded["elicitation.opened"]["payload"])
	assert_true(await soon(func() -> bool: return heard.changes.size() == 2), "another on the new connection")
	hub.push_board_event("gate.opened", recorded["gate.opened"]["payload"])
	assert_true(await soon(func() -> bool: return heard.changes.size() == 3), "and another")
	await soon(func() -> bool: return false, 0.3)
	assert_eq(hub.requests_to("GET /v1/boards/:id/ws").size(), 2, "and no more within the second")
	assert_true(await soon(func() -> bool: return heard.snapshots.size() == 3, 3.0), "then one for the rest")
	assert_true(Time.get_ticks_msec() - began >= 1000, "a second after the first")
	await soon(func() -> bool: return false, 0.3)
	assert_eq(hub.requests_to("GET /v1/boards/:id/ws").size(), 3, "three connections in all")
	await done_with(hub, [board])


## The Work app keeps a gate the snapshot brings, and applies each
## recorded event payload without error.
func test_work_applies_the_recorded_event_payloads() -> void:
	var hub = FakeHub.new()
	var recorded: Dictionary = hub.superpipeline["board_events"]
	var state: Dictionary = hub.superpipeline["snapshot"].duplicate(true)
	for type in recorded:
		if type != "source":
			WorkBoardState.apply_event(state, type, recorded[type]["payload"])
	assert_eq(WorkBoardState.find(state["cards"], "crd_sample_files"), {}, "card.deleted took its card")
	assert_eq(WorkBoardState.find(state["gates"], "gate_new"), {}, "gate.opened alone adds no gate")
	assert_eq(WorkBoardState.find(state["elicitations"], "elc_sample")["status"], "answered", "an answer")


# ---- Coming back ----

## Review Focus 2: the node goes offline. The terminal: the hub ends the
## attached shell's stream as if the shell had exited, so the terminal
## asks the station's health, which says offline: it says "Station
## offline" and keeps trying, 1, 2, 4 and 8 seconds apart, while the hub
## refuses each attempt (1011), never showing open between; the node comes
## back and the terminal opens again.
##
## The chat follows the hub (agentpod@9bc1997:
## apps/hub/src/services/acp-sessions.ts `handleWireClosed`): its socket
## stays open; the pending permission request is answered as cancelled and
## the session parks at `waiting` with reason "node offline", which the
## Chat app shows as "Station offline" and the request as cancelled. After
## the grace (60 s; shortened here) the hub ends the session ("Couldn't
## reach the node.", `bye`, a 1000 close) and never reattaches it, even
## with the node back: the app says so and offers a new session, which
## opens on the node that is back.
func test_the_node_going_offline_and_coming_back() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var row := open_session(hub)
	var recorded: Array = hub.agentpod["acp_events"]
	for i in [0, 1, 3]:
		hub.push_chat_event(row["id"], recorded[i]["type"], recorded[i]["payload"])
	hub.push_chat_event(row["id"], "state", {"status": "waiting"})
	var app := open("terminal", source, _station(), false, fresh_settings()) as TerminalApp
	var terminal := app.stream
	var chat_app := open("chat", source, _station(), false, fresh_settings()) as ChatApp
	assert_true(await soon(func() -> bool: return terminal.state == "open" and chat_app.transcript.events.size() == 4),
		"both open")
	var request_seq := 3
	assert_true(chat_app.permission_card(request_seq) != null, "a permission request waits")
	var terminal_heard := Heard.new(terminal)
	var chat_heard := Heard.new(chat_app.stream)
	var chat_sockets: int = hub.requests_to("GET /api/acp/sessions/:id/ws").size()

	waits.hold = true
	hub.offline_grace_s = 3600.0
	hub.set_station_offline(STATION, true)
	assert_true(await soon(func() -> bool: return terminal.state == "offline"), "the terminal offline")
	assert_eq(app.error_text(), StationApp.OFFLINE, "the terminal says so")
	assert_true(await soon(func() -> bool: return chat_app.transcript.events.size() == 6), "the chat hears the hub")
	assert_eq(chat_app.transcript.events.slice(4).map(func(e): return [e["type"], e["payload"]]), [
		["permission-answer", {"requestSeq": request_seq, "cancelled": true}],
		["state", {"status": "waiting", "reason": "node offline"}],
	], "the request cancelled, then waiting: node offline")
	assert_eq(chat_app.stream.state, "open", "its socket stays open")
	assert_eq(chat_app.error_text(), StationApp.OFFLINE, "the chat says Station offline")
	assert_eq(chat_app.status_chip.text, ChatApp.STATUS_WORDS["waiting"], "waiting")
	var answer := chat_app.permission_card(request_seq).find_child("Answer", true, false) as Label
	assert_true(answer != null and answer.text == ChatApp.CANCELLED, "the request shows as cancelled")

	for _attempt in 3:
		await soon(func() -> bool: return waits.held.size() >= 1)
		waits.release()
		await soon(func() -> bool: return terminal.state == "offline" and not waits.held.is_empty(), 2.0)
	assert_eq(app.error_text(), StationApp.OFFLINE, "the terminal still offline, never flashing open")
	assert_eq(terminal_heard.states, ["offline"], "offline all along")
	assert_eq(waits.asked, [1.0, 2.0, 4.0, 8.0], "the terminal waited 1, 2, 4 and 8 seconds; the chat never")

	hub.set_station_offline(STATION, false)
	waits.hold = false
	waits.release()
	assert_true(await soon(func() -> bool: return terminal.state == "open"), "the terminal opens again")
	assert_eq(app.error_text(), "", "and the line goes")
	assert_true(await soon(func() -> bool: return hub.shells[STATION]["size"] == [app.columns, app.rows]),
		"at the app's size")
	assert_eq(hub.session(row["id"])["status"], "waiting", "the node back, the session still parked: no reattach")

	# The grace runs out.
	hub.offline_grace_s = 0.0
	assert_true(await soon(func() -> bool: return chat_app.status == "ended"), "the session ended")
	assert_eq(hub.session(row["id"])["endedReason"], "Couldn't reach the node.", "for want of its node")
	assert_true(await soon(func() -> bool: return chat_app.stream.state == "closed"), "its socket closed")
	assert_eq(chat_app.error_text(), "", "no longer offline")
	assert_true(chat_app.new_session_button.is_visible_in_tree(), "a new session offered")
	assert_eq(chat_app.ended_label.text, ChatApp.ENDED_NODE_LOST, "saying why it ended")
	assert_eq(chat_heard.failures, [], "the chat never failed")
	assert_eq(hub.requests_to("GET /api/acp/sessions/:id/ws").size(), chat_sockets, "and never reconnected")
	chat_app.new_session_button.pressed.emit()
	assert_true(await soon(func() -> bool: return chat_app.stream != null and chat_app.stream.state == "open" \
		and str(chat_app.session_row.get("id", "")) != row["id"]), "a new session, on the node back")
	assert_eq(chat_app.transcript.events.map(func(e): return e["type"]), [], "on an empty transcript")
	close(app)
	close(chat_app)
	await done_with(hub)


## The Chat app on the live source: it replays the session, sends a
## prompt, says "Reconnecting…" while the connection is lost, and comes
## back subscribed from the last `seq` it had, with each event once though
## the hub replays two too many. "New session" ends the session on the hub
## and opens a new one, subscribed from its start.
func test_the_chat_app_reconnects_and_starts_new_sessions() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var row := open_session(hub)
	hub.push_chat_event(row["id"], "user-prompt", {"text": "hello"})
	hub.push_chat_event(row["id"], "state", {"status": "idle"})
	var app := open("chat", source, _station(), false, fresh_settings()) as ChatApp
	assert_true(await soon(func() -> bool: return app.transcript.events.size() == 2 and app.stream.state == "open"),
		"the transcript replayed")
	assert_eq(app.status_chip.text, ChatApp.STATUS_WORDS["idle"], "idle, as the session row says")
	app.prompt_field.text = "run the tests"
	app.send_prompt()
	assert_true(await soon(func() -> bool: return app.transcript.events.size() == 3), "the prompt, as the hub records it")

	waits.hold = true
	hub.replay_overlap = 2
	hub.drop_sockets("chat")
	assert_true(await soon(func() -> bool: return app.status_chip.text == ChatApp.RECONNECTING), "Reconnecting…")
	assert_true(app.send_button.disabled, "nothing to send to meanwhile")
	hub.push_chat_event(row["id"], "agent-update", hub.agentpod["acp_events"][2]["payload"])
	waits.release()
	assert_true(await soon(func() -> bool: return app.transcript.events.size() == 4), "back, with what it missed")
	assert_eq(app.transcript.events.map(func(e): return e["seq"]), [1, 2, 3, 4], "each once")
	assert_eq(app.status_chip.text, ChatApp.STATUS_WORDS["idle"], "and idle again")
	assert_eq(hub.subscribes, [0, 3], "from where it was")

	waits.hold = false
	app._end_then_open()
	assert_true(await soon(func() -> bool: return app.stream != null and app.stream.state == "open" \
		and str(app.session_row.get("id", "")) != row["id"]), "a new session")
	assert_eq(hub.session(row["id"])["status"], "ended", "the old one ended on the hub")
	assert_eq(hub.subscribes.back(), 0, "the new one subscribed from its start")
	assert_eq(app.transcript.events, [], "on an empty transcript")
	app.closing()
	app.free()
	await done_with(hub)


## A tail that ends as soon as it starts (the node's tail erred) waits
## longer each time, 1, 2, 4, 8, 16 and then 30 seconds, rather than asking
## again every second: opening alone does not count as working, and nor do
## lines, since the node starts every tail with its last ones. Ten seconds
## open, on the source's clock, does: the wait is a second again.
func test_a_tail_that_ends_at_once_backs_off() -> void:
	var hub = fake_hub()
	var source := live(hub)
	hub.tails_end_at_once = true
	var logs := source.open_logs(STATION)
	var heard := Heard.new(logs)
	assert_true(await soon(func() -> bool: return waits.asked.size() >= 7), "attempts")
	assert_eq(waits.asked.slice(0, 7), [1.0, 2.0, 4.0, 8.0, 16.0, 30.0, 30.0], "each waited longer")
	assert_eq(heard.failures, [], "not a failure")
	hub.tails_end_at_once = false
	var lines := []
	logs.line.connect(func(text: String) -> void: lines.append(text))
	assert_true(await soon(func() -> bool: return hub.tails_open(STATION) == 1), "a tail that stays")
	hub.push_log(STATION, "hello")
	assert_true(await soon(func() -> bool: return lines.has("hello")), "a line")
	var asked := waits.asked.size()
	hub.end_logs(STATION)
	assert_true(await soon(func() -> bool: return waits.asked.size() == asked + 1), "ended")
	assert_eq(waits.asked.back(), 30.0, "a line alone does not start the backoff over")
	assert_true(await soon(func() -> bool: return hub.tails_open(STATION) == 1), "open again")
	skipped_ms += 10001
	await settle(3)
	asked = waits.asked.size()
	hub.end_logs(STATION)
	assert_true(await soon(func() -> bool: return waits.asked.size() == asked + 1), "ended")
	assert_eq(waits.asked.back(), 1.0, "after ten seconds open, a second again")
	asked = waits.asked.size()
	hub.tails_end_at_once = true
	assert_true(await soon(func() -> bool: return waits.asked.size() >= asked + 2), "ending at once again")
	assert_eq(waits.asked.slice(asked, asked + 2), [2.0, 4.0], "it grows, though each tail starts with lines")
	await done_with(hub, [logs])


## The node's tail starts with its last lines, on a reconnection as on the
## first opening, so a reconnected tail repeats lines already shown. The
## Logs app starts its view afresh when the tail reopens, as its own Retry
## does, so no line shows twice.
func test_a_reconnected_tail_shows_no_line_twice() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var app := open("logs", source, _station(), false, fresh_settings()) as LogsApp
	assert_true(await soon(func() -> bool: return hub.tails_open(STATION) == 1), "the tail")
	hub.push_log(STATION, "one\ntwo")
	assert_true(await soon(func() -> bool: return app.line_count() == 2), "two lines")
	hub.end_logs(STATION)
	assert_true(await soon(func() -> bool: return app.stream.state == "offline"), "offline")
	assert_true(await soon(func() -> bool: return app.stream.state == "open" and app.line_count() == 2), "reopened, replayed")
	hub.push_log(STATION, "three")
	assert_true(await soon(func() -> bool: return app.line_count() == 3), "and on")
	var shown := []
	for i in app.line_count():
		shown.append(app.line(i))
	assert_eq(shown, ["one", "two", "three"], "each line once")
	close(app)
	await done_with(hub)


## The backoff: 1, 2, 4, 8 and 16 seconds, then every 30, while the
## terminal is open; closing it stops the attempts.
func test_the_backoff_grows_to_thirty_seconds() -> void:
	assert_eq(range(8).map(func(i): return LiveSocket.backoff_s(i)), [1.0, 2.0, 4.0, 8.0, 16.0, 30.0, 30.0, 30.0],
		"the schedule")
	var hub = fake_hub()
	var source := live(hub)
	hub.set_station_offline(STATION, true)
	var terminal := source.open_terminal(STATION)
	var heard := Heard.new(terminal)
	assert_true(await soon(func() -> bool: return waits.asked.size() >= 7), "attempts")
	assert_eq(waits.asked.slice(0, 7), [1.0, 2.0, 4.0, 8.0, 16.0, 30.0, 30.0], "waited as scheduled")
	assert_eq(heard.failures, [], "offline is not a failure")
	assert_eq(heard.states, ["offline"], "and never open, not even for a frame before a 1011")
	terminal.close()
	var asked := waits.asked.size()
	await settle(10)
	assert_true(waits.asked.size() <= asked + 1, "closing stops it")
	await done_with(hub)


## Review Focus 1: the token expires mid-stream. On the client's own clock
## a reconnection exchanges a fresh one first; when the hub thinks it has
## expired and the client does not, the hub refuses the handshake (HTTP
## 401, before the upgrade, as its `authMiddleware` does) and the client
## exchanges again at once and retries. Either way the streams carry on,
## with no failure and no sign-in asked for, and Godot's lines for the
## refused handshake carry no token.
func test_a_token_expiring_mid_stream() -> void:
	var hub = fake_hub()
	hub.token_lifetime_s = 2
	var source := live(hub)
	source.credential.refresh_margin_s = 1.0
	var signed_out := []
	source.credential.signed_out.connect(func() -> void: signed_out.append(true))
	var row := open_session(hub)
	var terminal := source.open_terminal(STATION)
	var chat := source.open_chat(STATION, "ask")
	var board := source.board(BOARD)
	var heard := [Heard.new(terminal), Heard.new(chat), Heard.new(board)]
	assert_true(await soon(func() -> bool: return terminal.state == "open" and chat.state == "open" and board.state == "open"),
		"all open")
	var first_tokens: int = hub.tokens.size()

	# On the client's clock: the token has a second left, inside the margin.
	await soon(func() -> bool: return false, 1.2)
	hub.drop_sockets()
	assert_true(await soon(func() -> bool: return terminal.state == "open" and chat.state == "open" and board.state == "open" \
		and hub.requests_to("GET /v1/boards/:id/ws").size() == 2), "all back")
	assert_eq(hub.unauthorized, 0, "no attempt met an expired token")
	assert_true(hub.tokens.size() > first_tokens, "a fresh token was exchanged")

	# On the hub's clock: every token ends now, and the client thinks its
	# own (a fresh five-minute one) good for a while yet.
	hub.token_lifetime_s = 300
	source.credential.refresh_margin_s = 0.0
	var fresh := []
	source.credential.request_token(func(token: String, _error: String) -> void: fresh.append(token), true)
	assert_true(await soon(func() -> bool: return not fresh.is_empty()), "a five-minute token held")
	hub.expire_tokens()
	hub.drop_sockets("terminal")
	hub.drop_sockets("chat")
	assert_true(await soon(func() -> bool: return hub.unauthorized >= 1 and terminal.state == "open" and chat.state == "open"),
		"refused, exchanged and back")
	terminal.send_input("still here")
	assert_true(await soon(func() -> bool: return heard[0].text().ends_with("still here")), "the terminal works")
	chat.prompt("and you?")
	assert_true(await soon(func() -> bool: return heard[1].events.any(func(e): return e["type"] == "user-prompt")),
		"the chat works")
	hub.push_board_event("activity", hub.superpipeline["board_events"]["activity"]["payload"])
	assert_true(await soon(func() -> bool: return heard[2].changes.size() == 1), "the board works")
	for each in heard:
		assert_eq(each.failures, [], "no failure")
	assert_eq(signed_out, [], "no sign-in asked for")
	assert_true(source.credential.is_signed_in(), "still signed in")
	assert_eq(hub.session(row["id"])["status"], "idle", "the session carried on")
	_take_refused_handshake_errors(source)
	await done_with(hub, [terminal, chat, board])


## Ruling (final review): the hub refuses a socket's token with HTTP 401
## before the upgrade, which Godot logs and a socket cannot read. So a
## terminal or chat whose connection fails before it ever opened exchanges
## its token again once, at once, as `LiveBoard` does; a token the hub no
## longer takes (expired on its clock, or revoked with the credential
## still good) carries on, with no sign-in asked for and no backoff.
func test_a_refused_socket_token_recovers_while_the_credential_is_good() -> void:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var hub = fake_hub()
	var source := live(hub)
	source.credential.refresh_margin_s = 0.0
	var signed_out := []
	source.credential.signed_out.connect(func() -> void: signed_out.append(true))
	var row := open_session(hub)
	var terminal := source.open_terminal(STATION)
	var chat := source.watch_chat(STATION)
	var heard := [Heard.new(terminal), Heard.new(chat)]
	assert_true(await soon(func() -> bool: return terminal.state == "open" and chat.state == "open"), "both open")
	for how in ["expired", "revoked"]:
		var exchanges: int = hub.requests_to("POST /api/auth/devices/token").size()
		var refused: int = hub.unauthorized
		var waited := waits.asked.size()
		if how == "expired":
			hub.expire_tokens()
		else:
			# Revoked on the hub (a token it no longer knows), the device kept.
			hub.tokens.clear()
		hub.drop_sockets("terminal")
		hub.drop_sockets("chat")
		assert_true(await soon(func() -> bool: return hub.unauthorized >= refused + 2 and terminal.state == "open" \
			and chat.state == "open"), how + ": refused before the upgrade, and back")
		assert_true(hub.requests_to("POST /api/auth/devices/token").size() > exchanges, how + ": a fresh token exchanged")
		assert_eq(waits.asked.size(), waited + 2, how + ": the lost links waited on, the refusals retried at once")
	terminal.send_input("still here")
	assert_true(await soon(func() -> bool: return heard[0].text().ends_with("still here")), "the terminal works")
	chat.prompt("and you?")
	assert_true(await soon(func() -> bool: return hub.session_events.get(row["id"], []).size() == 1), "the chat works")
	for each in heard:
		assert_eq(each.failures, [], "no failure")
	assert_eq(signed_out, [], "no sign-in asked for")
	assert_true(source.credential.is_signed_in(), "still signed in")
	OS.remove_logger(capture)
	var logged := "\n".join(capture.lines)
	assert_true(not logged.contains("token="), "nothing with ?token= logged")
	for token in hub.tokens:
		assert_true(not logged.contains(token), "no token logged")
	_take_refused_handshake_errors(source)
	await done_with(hub, [terminal, chat])


## A socket refused before it opened, and again with a fresh token, asks
## over REST, which tells why: the terminal the station's health, the chat
## its session list. A credential the hub refuses ends in `signed_out` (and
## the player signed out); no access is `no_access`; a station gone,
## `not_found`; anything else is `offline`, and it keeps trying.
func test_a_socket_refused_before_it_opens_asks_why() -> void:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var hub = fake_hub()
	var source := live(hub)
	open_session(hub)
	var signed_out := []
	source.credential.signed_out.connect(func() -> void: signed_out.append(true))
	# The credential itself refused (the device revoked): the fresh
	# exchange says so.
	var terminal := source.open_terminal(STATION)
	var chat := source.watch_chat(STATION)
	var heard := [Heard.new(terminal), Heard.new(chat)]
	assert_true(await soon(func() -> bool: return terminal.state == "open" and chat.state == "open"), "both open")
	for id in hub.devices:
		hub.devices[id]["revoked"] = true
	hub.tokens.clear()
	hub.drop_sockets("terminal")
	hub.drop_sockets("chat")
	assert_true(await soon(func() -> bool: return terminal.state == "closed" and chat.state == "closed"), "both closed")
	for each in heard:
		assert_eq(each.failures.map(func(f): return f["kind"]), ["signed_out"], "signed out")
	assert_eq(signed_out, [true], "the player too, once")
	_take_refused_handshake_errors(source)
	assert_eq(hub.violations, [], "the fake saw nothing it does not know")
	hub.stop()

	# Refused before the upgrade, and again with a fresh token, the stream
	# asks over REST: two more 401s there sign the player out; 403 is no
	# access; 404 a station gone; the node offline (502) keeps trying.
	for case in [["terminal", "GET /api/stations/:id/health"], ["chat", "GET /api/stations/:id/acp/sessions"]]:
		for probe in [[401, "signed_out"], [403, "no_access"], [404, "not_found"], [502, "offline"]]:
			hub = fake_hub()
			source = live(hub)
			open_session(hub)
			var stream: StationStream = source.open_terminal(STATION) if case[0] == "terminal" else source.watch_chat(STATION)
			var stream_heard := Heard.new(stream)
			var what := "%s, %d" % [case[0], probe[0]]
			assert_true(await soon(func() -> bool: return stream.state == "open"), what + ": open")
			var asked_before: int = hub.requests_to(case[1]).size()
			if probe[0] == 401:
				hub.refuse("hub", 401, 4)
			else:
				hub.refuse("hub", 401, 2)
				hub.answer_with("hub", case[1], probe[0], {"error": "node offline"} if probe[0] == 502 else {"error": "refused"})
			hub.drop_sockets("terminal" if case[0] == "terminal" else "chat")
			if probe[1] == "offline":
				assert_true(await soon(func() -> bool: return waits.asked.size() == 2), what + ": waits")
				assert_eq(waits.asked, [1.0, 2.0], what + ": the lost link, then offline after asking")
				assert_true(await soon(func() -> bool: return stream.state == "open"), what + ": and back")
				assert_eq(stream_heard.failures, [], what + ": never a failure")
			else:
				assert_true(await soon(func() -> bool: return stream.state == "closed"), what + ": closed")
				assert_eq(stream_heard.failures.map(func(f): return f["kind"]), [probe[1]], what + ": " + probe[1])
			assert_eq(hub.requests_to(case[1]).size() - asked_before, 2 if probe[0] == 401 else 1,
				what + ": asked over REST once (a 401 retried)")
			assert_eq(source.credential.is_signed_in(), probe[0] != 401, what + ": signed in unless refused")
			stream.close()
			_take_refused_handshake_errors(source)
			assert_eq(hub.violations, [], "the fake saw nothing it does not know")
			hub.stop()
	OS.remove_logger(capture)
	assert_true(not "\n".join(capture.lines).contains("token="), "nothing with ?token= logged")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CREDENTIAL_FILE))


## Superpipeline refuses a bad token before the handshake, which Godot
## logs and a socket cannot read; the board then asks `GET /v1/boards`,
## whose 401 is exchanged and retried once, so a token that merely expired
## carries on and a refused sign-in fails as `signed_out`.
func test_the_board_after_a_refused_handshake() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var board := source.board(BOARD)
	var heard := Heard.new(board)
	assert_true(await soon(func() -> bool: return heard.snapshots.size() == 1), "open")
	hub.expire_tokens()
	source.credential.refresh_margin_s = 0.0
	hub.drop_sockets("board")
	assert_true(await soon(func() -> bool: return heard.snapshots.size() == 2), "back, with a fresh token")
	assert_eq(hub.requests_to("GET /v1/boards").size(), 2, "after asking the board, a 401 retried with a fresh token")
	assert_eq(heard.failures, [], "no failure")

	hub.refuse("superpipeline", 401, 3)
	hub.drop_sockets("board")
	assert_true(await soon(func() -> bool: return board.state == "closed"), "refused")
	assert_eq(heard.failures.map(func(f): return f["kind"]), ["signed_out"], "signed out")
	_take_refused_handshake_errors(source)
	await done_with(hub)


## Godot's own lines for a refused handshake ("Invalid status code"),
## which the test expects: they are checked to carry no token, then
## cleared, so the runner does not count them as failures.
func _take_refused_handshake_errors(source: LiveSource) -> void:
	var expected: Array = runner.errors.filter(func(e): return "status code" in e or "response headers" in e)
	assert_true(not expected.is_empty(), "Godot logged the refused handshake")
	var held := source.credential._token
	for line in runner.errors:
		assert_true(held == "" or not line.contains(held), "no token in Godot's lines")
		assert_true(not line.contains("token="), "no query in Godot's lines")
	for line in expected:
		runner.errors.erase(line)
	assert_eq(runner.errors, [], "and nothing else was logged")


# ---- The drift guard ----

## The fake fails the test on a client frame the recordings lack: an
## unknown `t`, a known one with a key too many or a value of the wrong
## type, a raw control character, and anything sent on the board.
func test_the_fake_fails_a_frame_the_recordings_lack() -> void:
	var hub = FakeHub.new()
	var reported := []
	hub.report = func(what: String) -> void: reported.append(what)
	hub.start()
	var source := live(hub)
	var terminal := source.open_terminal(STATION) as LiveSource.LiveTerminal
	var board := source.board(BOARD) as LiveSource.LiveBoard
	assert_true(await soon(func() -> bool: return terminal.state == "open" and board.state == "open"), "open")
	terminal._socket.send_text("{\"t\":\"shout\",\"data\":\"hi\"}")
	terminal._socket.send_text("{\"t\":\"input\",\"data\":\"hi\",\"echo\":false}")
	terminal._socket.send_text("{\"t\":\"resize\",\"cols\":\"80\",\"rows\":24}")
	terminal._socket.send_text("{\"t\":\"input\",\"data\":\"\u001b\"}")
	terminal._socket.send_text("{\"t\":\"input\",\"data\":\"\\v\"}")
	board._socket.send({"kind": "hello"})
	assert_true(await soon(func() -> bool: return reported.size() >= 6), "each reported: %s" % [reported])
	assert_eq(reported.size(), 6, "six violations")
	assert_true(reported.any(func(w): return "escape" in w), "the \\v escape, which JSON has not")
	for what in reported:
		assert_true(what.begins_with("fake hub: "), "reported as the fake's")
	assert_true(reported.any(func(w): return "shout" in w), "the unknown type")
	assert_true(reported.any(func(w): return "push-only" in w), "the board")
	assert_true(reported.any(func(w): return "control character" in w), "the raw control character")
	terminal.close()
	board.close()
	hub.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CREDENTIAL_FILE))


## Godot's JSON.stringify leaves control characters raw, which the hub's
## JSON.parse refuses; every frame and body goes out escaped, and the fake
## refuses a raw one, on REST as on a socket.
func test_json_goes_out_strict() -> void:
	assert_eq(LiveSource.strict_json({"d": "\u001b[A\u0003\t\n"}), "{\"d\":\"\\u001b[A\\u0003\\t\\n\"}", "escaped")
	assert_eq(LiveSource.strict_json({"d": "plain"}), "{\"d\":\"plain\"}", "plain text untouched")
	assert_eq(LiveSource.strict_json({"d": "\u000b"}), "{\"d\":\"\\u000b\"}", "\\v, which JSON has not, as \\u000b")
	assert_eq(LiveSource.strict_json({"d": "\\v"}), "{\"d\":\"\\\\v\"}", "a backslash then v is text, left alone")
	assert_eq(LiveSource.strict_json({"d": "\\\u000b"}), "{\"d\":\"\\\\\\u000b\"}", "a backslash then \\v")
	var every := ""
	for code in range(1, 32):
		every += String.chr(code)
	every += "\\\"/\u007f"
	var written := LiveSource.strict_json({"d": every})
	for code in range(0, written.length()):
		assert_true(written.unicode_at(code) >= 0x20, "no raw control character at %d" % code)
	var escapes := RegEx.create_from_string("\\\\(u[0-9a-f]{4}|.)").search_all(written)
	for found in escapes:
		assert_true(found.get_string(1).length() == 5 or found.get_string(1) in ["\"", "\\", "/", "b", "f", "n", "r", "t"],
			"only JSON's own escapes: \\" + found.get_string(1))
	assert_eq(JSON.parse_string(written), {"d": every}, "every control character, read back")
	var hub = fake_hub()
	var source := live(hub)
	var answered := []
	source.result.connect(func(_id: int, ok: bool, _body: Variant, _status: int) -> void: answered.append(ok))
	source.resolve_gate(BOARD, "gate_sample", "request_changes", "tabs\u0001and\u000bhere")
	assert_true(await soon(func() -> bool: return not answered.is_empty()), "answered")
	assert_eq(answered, [true], "the hub read it")
	assert_eq(hub.superpipeline["snapshot"]["gates"][0]["comment"], "tabs\u0001and\u000bhere", "as written")
	var terminal := source.open_terminal(STATION)
	assert_true(await soon(func() -> bool: return terminal.state == "open"), "a terminal")
	terminal.send_input("\u000b")
	assert_true(await soon(func() -> bool: return hub.shells[STATION]["input"] == "\u000b"), "Ctrl-K arrives")
	terminal.close()
	await done_with(hub)


## The streams' code logs nothing and makes its sockets only through the
## counter; a failure's message is a fixed line, a route and a code.
func test_the_stream_code_logs_nothing() -> void:
	for path in ["res://core/station/live/live_socket.gd", "res://core/station/live/live_terminal.gd",
			"res://core/station/live/live_chat.gd", "res://core/station/live/live_board.gd"]:
		var text := FileAccess.get_file_as_string(path)
		assert_true(not text.is_empty(), path + " reads")
		for name in ["print(", "print_rich(", "printerr(", "prints(", "push_warning(", "push_error(", "OS.alert("]:
			assert_true(not text.contains(name), "%s never calls %s" % [path.get_file(), name])
		for name in ["HTTPClient.new(", "TCPServer.new(", "StreamPeerTCP.new(", "WebSocketPeer.new(", "HTTPRequest",
				"ClassDB.instantiate("]:
			assert_true(not text.contains(name), "%s makes no %s but through the counter" % [path.get_file(), name])
	var hub = fake_hub()
	var source := live(hub)
	var before := StationSource.network_objects_created
	var terminal := source.open_terminal(STATION)
	assert_true(await soon(func() -> bool: return terminal.state == "open"), "open")
	assert_eq(StationSource.network_objects_created - before, 2, "an exchange and the socket, both counted")
	await done_with(hub, [terminal])


func _station() -> Dictionary:
	var row := station_row()
	row["stationId"] = STATION
	return row
