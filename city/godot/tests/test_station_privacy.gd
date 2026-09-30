## Private stays private (spec section 1, criterion 6; Part B's Task 10;
## Review Focus 4 and 5). A scripted live session against the fake hub,
## through main as a player plays it, plants a marker in each kind of
## station content: the station's name and purpose, the terminal's output
## and what is typed there, the chat's reply, its permission request and
## what is typed there, a file's name and contents, a log line, a diff, a
## card's title and activity, a question, and the gate comment and answer
## the player writes. The fake's tokens, the device's secret and the error
## bodies count as markers too. The session opens every app, answers the
## permission request, the gate and the question, and meets a 401, a 502,
## malformed frames and a malformed address.
##
## Then every channel out of the station computer is read, and none may
## hold a marker:
## - every CityWorld call, its arguments and its answer, through a
##   recording bridge put between main and the world;
## - the core's input log, its projections for every viewer and its
##   replay, which must match, byte for byte, a session at the same desk
##   with nothing done on the computer;
## - the client's log files (user://logs), and everything logged while the
##   session ran, print output and errors alike;
## - the error watch;
## - anything addressed to a city server: there is none, the station code
##   names none, and every connection it made reached the fake.
## Others see `using` and nothing more of the station; "Look at screen" is
## offered only where the player's source can see the station, and
## watching sends nothing, to the city or to the station.
extends TestSuite

const FakeHub := preload("res://tests/fake_hub/fake_hub.gd")
const SETTINGS_FILE := "user://test_station_privacy.cfg"
const CREDENTIAL_FILE := "user://test_station_privacy_credential.json"
const STATION := "stn_build"
const BOARD := "brd_build"
## The placed workstation the watch fixture binds to STATION, and where it
## stands: in the reading room, beside its hot desks, facing east as its
## chairs do.
const BOUND_DESK := "placement:station-desk"
const BOUND_DESK_AT := {"x": 3100, "z": 300}
## The watch fixture's desk owner: a person the feed brings in, who uses
## the bound desk and then stands up, each at a tick the test names.
const OWNER := "person:owner"
const OWNER_USES_AT := 110
const OWNER_LEAVES_AT := 300
## Where both sessions of the live-session test step the world, the test
## being its clock (the driver's own is stopped): TICKS_AT_CHECKPOINT ticks
## at each, named for what the live session has just done there.
const CHECKPOINTS := ["the computer opened", "the terminal", "the chat", "the files", "the logs", "the health",
	"the changes", "the work", "a malformed address"]
const TICKS_AT_CHECKPOINT := 2


## Passes every call on to the world, and notes each one: its name, its
## arguments and its answer. Put in where main holds the world (the
## driver and the player), it sees everything the client says to the core
## and hears back.
class RecordingWorld:
	var world
	var calls: Array = []

	func _init(world_) -> void:
		world = world_

	func _note(name: String, arguments: Array, answer: Variant) -> Variant:
		calls.append({"name": name, "arguments": arguments, "answer": answer})
		return answer

	func step() -> int:
		return _note("step", [], world.step())

	func tick() -> int:
		return _note("tick", [], world.tick())

	func set_operator(on: bool) -> void:
		world.set_operator(on)
		_note("set_operator", [on], null)

	func project_json(viewer: String) -> String:
		return _note("project_json", [viewer], world.project_json(viewer))

	func layout_json() -> String:
		return _note("layout_json", [], world.layout_json())

	func set_fixture_dir(dir: String) -> void:
		world.set_fixture_dir(dir)
		_note("set_fixture_dir", [dir], null)

	func panel_json(target: String) -> String:
		return _note("panel_json", [target], world.panel_json(target))

	func catalogue_json() -> String:
		return _note("catalogue_json", [], world.catalogue_json())

	func grid_answers() -> PackedInt32Array:
		return _note("grid_answers", [], world.grid_answers())

	func join(as_: String, look: String) -> String:
		return _note("join", [as_, look], world.join(as_, look))

	func command(json: String) -> String:
		return _note("command", [json], world.command(json))

	func board() -> String:
		return _note("board", [], world.board())

	func alight() -> String:
		return _note("alight", [], world.alight())

	func take_player_events() -> String:
		return _note("take_player_events", [], world.take_player_events())

	func leave() -> String:
		return _note("leave", [], world.leave())

	func input_log_jsonl() -> String:
		return _note("input_log_jsonl", [], world.input_log_jsonl())

	func viewer() -> String:
		return _note("viewer", [], world.viewer())

	func set_checking(on: bool) -> void:
		world.set_checking(on)
		_note("set_checking", [on], null)

	func violations_json() -> String:
		return _note("violations_json", [], world.violations_json())

	func replay_json() -> String:
		return _note("replay_json", [], world.replay_json())

	## The commands sent, parsed, from call `since` on.
	func commands(since := 0) -> Array:
		return calls.slice(since).filter(func(c): return c["name"] == "command") \
			.map(func(c): return JSON.parse_string(c["arguments"][0]))


## Everything logged while it is added: print output and errors alike.
class LogCapture extends Logger:
	var lines: Array[String] = []

	func _log_message(message: String, _error: bool) -> void:
		lines.append(message)

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		lines.append("%s %s %s:%d %s" % [code, rationale, file, line, function])


# ---- The markers ----

## A marker for each kind of content, unique to this run, so no older log
## can hold one: {what it marks: marker}.
func markers() -> Dictionary:
	var run := Crypto.new().generate_random_bytes(5).hex_encode().to_upper()
	var out := {}
	for what in ["station name", "station purpose", "terminal output", "typed in the terminal", "chat reply",
			"permission request", "typed in the chat", "file name", "file content", "log line", "diff",
			"changed path", "card title", "card activity", "question", "gate comment", "answer",
			"error body", "401 body", "malformed body", "malformed frame", "malformed address"]:
		out[what] = "PRIV%s%s" % [what.to_upper().replace(" ", ""), run]
	return out


## Plants `marks` in the fake's recordings: the station's row, a file and
## its listing, the diff, a card's title and activity, and the question.
## The rest (the terminal, the chat, the log) the fake sends as the
## session runs.
func plant(hub, marks: Dictionary) -> void:
	var row: Dictionary = hub.agentpod["fleet_agents"]["agents"][0]
	row["agentName"] = "Build box " + marks["station name"]
	row["workspacePath"] = "/home/player/" + marks["station purpose"]
	var name: String = marks["file name"] + ".txt"
	hub.agentpod["files"]["."].append({"name": name, "path": name, "type": "file", "size": 40,
		"modified": "2026-09-29T08:00:00.000Z"})
	hub.agentpod["file_contents"][name] = {"encoding": "utf8", "content": "notes: " + marks["file content"] + "\n"}
	hub.agentpod["changeset_status"]["uncommitted"]["files"][0]["path"] = marks["changed path"] + ".rs"
	hub.agentpod["changeset_diff"]["content"] = "--- a/x\n+++ b/x\n@@ -1 +1 @@\n-old\n+" + marks["diff"] + "\n"
	var snapshot: Dictionary = hub.superpipeline["snapshot"]
	for card in snapshot["cards"]:
		if card["id"] == "crd_sample_tabs":
			card["title"] = "Tabs " + marks["card title"]
	snapshot["elicitations"][0]["question"] = "Which? " + marks["question"]
	hub.superpipeline["activities"]["crd_sample_tabs"]["activities"][0]["body"] = marks["card activity"]


## The station's side of the session, as markers too: the fake's tokens,
## its devices' secrets and its sign-in codes.
func secrets_of(hub) -> Dictionary:
	var out := {}
	for token in hub.tokens:
		out["a token"] = out.get("a token", []) + [token]
	for device in hub.devices.values():
		out["a device secret"] = out.get("a device secret", []) + [device["secret"]]
	for code in hub.codes:
		out["a sign-in code"] = out.get("a sign-in code", []) + [code]
	return out


## Which of `forbidden` ({what: marker, or a list of them}) `text` holds,
## by what they mark (never the marker itself, which a failure's message
## would print).
static func found_in(text: String, forbidden: Dictionary) -> Array:
	var out := []
	for what in forbidden:
		var values: Array = forbidden[what] if forbidden[what] is Array else [forbidden[what]]
		for value in values:
			if str(value) != "" and text.contains(str(value)):
				out.append(what)
				break
	return out


# ---- The city ----

func fake_hub() -> Variant:
	var hub = FakeHub.new()
	hub.report = runner.fail
	hub.start()
	return hub


## Boots the lowpoly city on the district, or on `manifest` and `feed`,
## with this suite's settings and credential files, and lets the player
## arrive.
func boot(manifest := "", feed := "") -> Node:
	var main = load("res://main.gd").new()
	main.settings_path = SETTINGS_FILE
	main.credential_path = CREDENTIAL_FILE
	main.fixture_manifest = manifest
	main.feed_jsonl = feed
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_FILE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CREDENTIAL_FILE))
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=lowpoly_tropical"]))
	for i in 80:
		main.driver.step_once()
		if main.player.present and not main.player.view.get("moving", false):
			break
	assert_true(main.player.present, "the player arrived")
	return main


## Puts a recording bridge between main and its world.
func record_bridge(main) -> RecordingWorld:
	var recording := RecordingWorld.new(main.driver.world)
	main.driver.world = recording
	main.player.world = recording
	return recording


## Live mode on against the fake, signed in: a credential for a device the
## fake knows, where main keeps it, as a finished sign-in leaves one.
func go_live(main, hub) -> void:
	var id: String = hub.serial("dev_")
	hub.devices[id] = {"secret": hub.serial("sec_"), "name": "Agentnagar on test-box", "revoked": false}
	var file := FileAccess.open(CREDENTIAL_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"hub": hub.hub_url, "device_id": id, "secret": hub.devices[id]["secret"]}))
	file.close()
	for pair in [["hub_url", hub.hub_url], ["superpipeline_url", hub.superpipeline_url], ["live", true]]:
		main.settings.set_value("station", pair[0], pair[1])


func thing(main, id: String) -> Dictionary:
	for t in main.interact.things:
		if t["target"] == id:
			return t
	return {}


func frames(main, seconds: float) -> void:
	for f in int(round(seconds * 60.0)):
		main._process(1.0 / 60.0)
		main.driver.advance(1.0 / 60.0)


func tick(main) -> void:
	main.driver.step_once()
	frames(main, 0.05)


func until_ticks(main, done: Callable, most: int) -> bool:
	for i in most:
		if done.call():
			return true
		tick(main)
	return done.call()


func walk_to(main, pos: Vector2) -> void:
	main.player.go_point(pos)
	for i in 80:
		tick(main)
		if not main.player.view.get("moving", false) and not main.player.following:
			break


## Uses the computer at `seat` as A on "Use computer" does: a Go to the
## seat, then a Use at its use anchor, stepped until the core has the
## player using it. Returns the computer that opened.
func use_desk(main, seat: String) -> ComputerScreen:
	main.interact.taken = {}
	var target: Dictionary = main.interact.candidate_of(thing(main, seat), 1)
	main.interaction._act(target, 0)
	for i in 300:
		tick(main)
		var using = main.player.view.get("using")
		if using is Dictionary and using.get("capability") == "use":
			break
	frames(main, 0.05)
	assert_true(main._computer_open(), "at the computer")
	return main.computer


func settle(n := 3) -> void:
	for f in n:
		await runner.process_frame


## Waits frame by frame until `done` holds, for at most `most_s` seconds.
func soon(done: Callable, most_s := 5.0) -> bool:
	var began := Time.get_ticks_msec()
	while not done.call():
		if Time.get_ticks_msec() - began > int(most_s * 1000.0):
			return false
		await runner.process_frame
	return true


func key(code: int, unicode := 0) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.unicode = unicode
	e.pressed = true
	return e


## Presses and lets go of `code` through the window, as the player would.
func tap(code: int) -> void:
	var down := key(code)
	var up := key(code)
	up.pressed = false
	runner.root.push_input(down)
	runner.root.push_input(up)


## Types `text` through the window, a key at a time, then Enter.
func type_line(text: String) -> void:
	for i in text.length():
		runner.root.push_input(key(KEY_NONE, text.unicode_at(i)))
	tap(KEY_ENTER)


## A text frame of `text` from the fake, on every open socket of `kind`,
## as sent: however malformed.
func raw_frame(hub, kind: String, text: String) -> void:
	for connection in hub.sockets(kind):
		connection["outbox"].append_array(FakeHub.Sockets.encode(FakeHub.Sockets.OP_TEXT, text.to_utf8_buffer()))


## What viewers other than the player see of it, now: its view in the
## public projection and in Asha's.
func others_view_of(main) -> Dictionary:
	var out := {}
	for viewer in ["public", "person:asha"]:
		for v in Player.views_of(StationSource.parse_json(main.driver.world.project_json(viewer))):
			if v.get("id") == main.player.id:
				out[viewer] = v
	return out


## Every file in user://logs, the client's log files: the one this run
## writes, and older ones (which hold no marker of this run's).
static func log_files() -> String:
	var text := ""
	for name in DirAccess.get_files_at("user://logs"):
		text += FileAccess.get_file_as_string("user://logs/" + name) + "\n"
	return text


## Where main keeps the station links in a test run.
static func main_links_path() -> String:
	return load("res://main.gd").TEST_LINKS_PATH


## The world steps TICKS_AT_CHECKPOINT ticks at checkpoint `name`, and
## `seen` keeps what others see of the player there.
func checkpoint(main, name: String, seen: Dictionary) -> void:
	for i in TICKS_AT_CHECKPOINT:
		tick(main)
	seen[name] = others_view_of(main)


## The two addresses the fake serves, as destinations ("host:port").
static func fake_origins(hub) -> Array:
	return [hub.hub_url.trim_prefix("http://"), hub.superpipeline_url.trim_prefix("http://")]


## Where a destination may be: the fake's two origins, or the sign-in's
## own listener on 127.0.0.1 (a credential's callback), for `credential`.
static func allowed_destinations(hub, credential: StationCredential) -> Array:
	var out := fake_origins(hub)
	if credential != null and credential._redirect_uri != "":
		out.append(credential._redirect_uri.trim_prefix("http://").get_slice("/", 0))
	return out


## Every file under `dir` (user:// at first), hidden ones too, but the
## logs (read by log_files) and the engine's own caches of compiled
## shaders (shader_cache, vulkan), which only the renderer writes and which
## are tens of megabytes: the settings, credentials and links files and
## anything else a station or a test left.
static func user_files(dir := "user://") -> Array:
	var out := []
	var at := DirAccess.open(dir)
	if at == null:
		return out
	at.include_hidden = true
	for name in at.get_files():
		out.append(dir.path_join(name))
	for sub in at.get_directories():
		if dir == "user://" and sub in ["logs", "shader_cache", "vulkan"]:
			continue
		out.append_array(user_files(dir.path_join(sub)))
	return out


## Which of `forbidden` any of `files` holds, read as bytes (a binary file
## read as text would log its bad UTF-8): "<what> in <file>".
static func found_in_files(files: Array, forbidden: Dictionary) -> Array:
	var out := []
	for path in files:
		var hex := FileAccess.get_file_as_bytes(path).hex_encode()
		for what in forbidden:
			var values: Array = forbidden[what] if forbidden[what] is Array else [forbidden[what]]
			for value in values:
				var needle := str(value).to_utf8_buffer().hex_encode()
				var found := hex.find(needle)
				# A match counts only on a byte's boundary.
				while found != -1 and found % 2 != 0:
					found = hex.find(needle, found + 1)
				if needle != "" and found != -1:
					out.append("%s in %s" % [what, str(path).get_file()])
					break
	return out


## The answer to `call_id`, awaited: [ok, body, status].
func answer_of(source: StationSource, call_id: int) -> Array:
	var got := []
	var on_result := func(id: int, ok: bool, body: Variant, status: int) -> void:
		if id == call_id:
			got.append_array([ok, body, status])
	source.result.connect(on_result)
	await soon(func() -> bool: return not got.is_empty())
	source.result.disconnect(on_result)
	return got


## A live source signed in on the fake, with a device of its own.
func live_source(hub) -> LiveSource:
	var id: String = hub.serial("dev_")
	hub.devices[id] = {"secret": hub.serial("sec_"), "name": "Agentnagar on test-box", "revoked": false}
	var file := FileAccess.open(CREDENTIAL_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"hub": hub.hub_url, "device_id": id, "secret": hub.devices[id]["secret"]}))
	file.close()
	return LiveSource.new(StationCredential.new(hub.hub_url, "agentnagar", CREDENTIAL_FILE), hub.hub_url,
		hub.superpipeline_url)


## Whether "Look at screen" is offered on what the player faces.
static func offered(main) -> bool:
	return main.interact.verbs(main.interaction.current_target()).has("Look at screen")


# ---- The live session ----

## Review Focus 4, through main: a live session at a hot desk, every app
## opened and used, with a 401, a 502, malformed frames and a malformed
## address, leaves no marker in any channel out of the station computer;
## the city hears only the Use and the StopUsing, and the core's input log,
## projections and replay match a session at the same desk with nothing
## done on the computer, byte for byte. Others see `using` and nothing
## more.
func test_a_live_session_leaves_nothing_of_the_station_in_the_city() -> void:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var hub = fake_hub()
	var marks := markers()
	plant(hub, marks)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main_links_path()))
	var links_before := FileAccess.get_file_as_string(StationLinks.PATH)
	var links_existed := FileAccess.file_exists(StationLinks.PATH)
	var destinations := []
	StationSource.connecting = func(destination: String) -> void: destinations.append(destination)
	var main = boot()
	var recording := record_bridge(main)
	go_live(main, hub)
	var c := use_desk(main, "seat:rw1")
	# The test is the world's clock from here, in both sessions: it steps at
	# the same checkpoints, so the session without the computer can be
	# stepped alike, tick for tick.
	main.driver.set_process(false)
	var seen := {}
	var calls_at_open: int = recording.calls.size()
	checkpoint(main, CHECKPOINTS[0], seen)

	assert_true(await soon(func() -> bool: return c.state == "chooser"), "the hub's stations")
	assert_true(c.source is LiveSource, "live")
	c.choose(0)
	assert_eq(c.state, "desktop", "the station's desktop")
	assert_true(c.desk_purpose.text.contains(marks["station purpose"]) and c.station_label.text.contains(marks["station name"]),
		"the station's name and purpose are on the computer")

	await use_terminal(c, hub, marks)
	checkpoint(main, CHECKPOINTS[1], seen)
	await use_chat(c, hub, marks)
	checkpoint(main, CHECKPOINTS[2], seen)
	await use_files(c, hub, marks)
	checkpoint(main, CHECKPOINTS[3], seen)
	await use_logs(c, hub, marks)
	checkpoint(main, CHECKPOINTS[4], seen)
	await use_health(c, hub, marks)
	checkpoint(main, CHECKPOINTS[5], seen)
	await use_changes(c, marks)
	checkpoint(main, CHECKPOINTS[6], seen)
	await use_work(c, hub, marks)
	checkpoint(main, CHECKPOINTS[7], seen)
	await meet_a_malformed_address(main, c, marks)
	checkpoint(main, CHECKPOINTS[8], seen)
	assert_eq(seen.keys(), CHECKPOINTS, "every checkpoint, in order")

	var during: Array = recording.commands(calls_at_open)
	assert_eq(during, [], "while the computer was used, nothing was sent to the city")
	tap(KEY_F10)
	assert_true(not main._computer_open(), "F10 left")
	assert_eq(recording.commands(calls_at_open).map(func(sent): return sent["type"]), ["StopUsing"], "then only the StopUsing")
	for i in 3:
		tick(main)
	await settle(10)
	assert_eq(main.player.view.get("using"), null, "the player is up")

	# Everything the city heard and said, from boot on.
	var bridge := JSON.stringify(recording.calls)
	var world = recording.world
	var input_log: String = world.input_log_jsonl()
	var replay: String = world.replay_json()
	var projections := {}
	var player_id: String = main.player.id
	for viewer in ["public", "person:asha", player_id]:
		projections[viewer] = world.project_json(viewer)
	var every_command := recording.commands().map(func(sent): return sent["type"])
	for type in every_command:
		assert_true(type in ["Go", "Steer", "Use", "StopUsing"], "only the player's own moves reach the city: " + type)
	assert_eq(every_command.filter(func(t): return t in ["Use", "StopUsing"]), ["Use", "StopUsing"],
		"one Use and one StopUsing")
	assert_eq(JSON.parse_string(replay).get("identical"), true, "the replay matches")
	for name in seen:
		assert_eq(seen[name].size(), 2, name + ": the player is seen by the public and by Asha")
		for viewer in seen[name]:
			assert_eq(seen[name][viewer].get("using"), {"target": "seat:rw1", "capability": "use", "anchor": 1},
				"%s: %s sees the player using the desk" % [name, viewer])

	# Every connection the station computer made went to the fake, as each
	# was made: nothing went anywhere else, a city server least of all.
	StationSource.connecting = Callable()
	assert_true(destinations.size() > 10, "the connections were recorded: %d" % destinations.size())
	var allowed := allowed_destinations(hub, main.station_credential)
	for destination in destinations:
		assert_true(destination in allowed, "a connection went only to the fake: " + destination)
	assert_eq(hub.violations, [], "the fake saw nothing it does not know")

	# This run's own: the markers, the tokens and the secret, which no older
	# log can hold.
	var this_run: Dictionary = marks.duplicate()
	this_run.merge(secrets_of(hub))
	var forbidden: Dictionary = this_run.duplicate()
	forbidden["the station's ID"] = STATION
	forbidden["the hub's address"] = hub.hub_url
	forbidden["Superpipeline's address"] = hub.superpipeline_url
	assert_true(forbidden.has("a token") and forbidden.has("a device secret"), "the tokens and the secret are checked")
	main.free()
	hub.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CREDENTIAL_FILE))
	OS.remove_logger(capture)

	assert_eq(found_in(bridge, forbidden), [], "no marker in any bridge call, its arguments or its answer")
	assert_eq(found_in(input_log, forbidden), [], "none in the input log")
	assert_eq(found_in(replay, forbidden), [], "none in the replay")
	for viewer in projections:
		assert_eq(found_in(projections[viewer], forbidden), [], "none in the projection for " + viewer)
	assert_eq(found_in("\n".join(capture.lines), forbidden), [], "none in anything logged: print output or errors")
	assert_eq(found_in("\n".join(runner.errors), forbidden), [], "none in the error watch")
	assert_eq(found_in(log_files(), this_run), [], "none in the client's log files")
	var files := user_files()
	assert_true(files.any(func(path): return str(path).ends_with(SETTINGS_FILE.get_file())), "the user files are read")
	assert_eq(found_in_files(files, this_run), [], "none in any other file the client keeps")
	assert_eq(FileAccess.file_exists(StationLinks.PATH), links_existed, "the player's own station links file untouched")
	assert_eq(FileAccess.get_file_as_string(StationLinks.PATH), links_before, "and unchanged")

	# The same session at the same desk, with nothing done on the computer.
	var plain = boot()
	var plain_c := use_desk(plain, "seat:rw1")
	plain.driver.set_process(false)
	assert_true(plain_c.source is SampleSource, "the sample: live mode is off there")
	var plain_seen := {}
	for name in CHECKPOINTS:
		checkpoint(plain, name, plain_seen)
	tap(KEY_F10)
	for i in 3:
		tick(plain)
	# Compared whole, but never printed: a failure's message would put
	# whatever leaked into the log.
	assert_true(plain.driver.world.input_log_jsonl() == input_log, "the input log is the same, byte for byte")
	assert_true(plain.driver.world.replay_json() == replay, "so is the replay")
	assert_eq(plain.player.id, player_id, "the player joined as the same occupant")
	for viewer in projections:
		assert_true(plain.driver.world.project_json(viewer) == projections[viewer], "so is the projection for " + viewer)
	assert_eq(plain_seen, seen, "others saw the same of the player at every checkpoint: using, nothing more")
	plain.free()


## The terminal: the shell's output shown, a line typed through the
## window and sent, and malformed frames from the hub (cut short, data that
## is not base64, data that is a number, a frame that is no object) dropped
## without a word, the shell still answering after.
func use_terminal(c: ComputerScreen, hub, marks: Dictionary) -> void:
	c.open_app("terminal")
	var terminal := c.app as TerminalApp
	assert_true(await soon(func() -> bool: return terminal.stream != null and terminal.stream.state == "open"), "the shell")
	hub.push_terminal(STATION, (marks["terminal output"] + "\r\n").to_utf8_buffer())
	assert_true(await soon(func() -> bool: return terminal.screen_text().contains(marks["terminal output"])),
		"the shell's output is on the computer")
	type_line(marks["typed in the terminal"])
	assert_true(await soon(func() -> bool: return hub.shells[STATION]["input"].contains(marks["typed in the terminal"] + "\r")),
		"what was typed reached the shell")
	var frame: String = marks["malformed frame"]
	raw_frame(hub, "terminal", "{\"t\":\"data\",\"data\":\"" + frame)
	raw_frame(hub, "terminal", "{\"t\":\"data\",\"data\":\"" + frame + "!\"}")
	raw_frame(hub, "terminal", "{\"t\":\"data\",\"data\":7,\"x\":\"" + frame + "\"}")
	raw_frame(hub, "terminal", "[\"" + frame + "\"]")
	hub.push_terminal(STATION, "still here\r\n".to_utf8_buffer())
	assert_true(await soon(func() -> bool: return terminal.screen_text().contains("still here")), "the shell carries on")


## The chat: a prompt typed and sent, the agent's reply, a permission
## request answered, and malformed frames dropped.
func use_chat(c: ComputerScreen, hub, marks: Dictionary) -> void:
	c.open_app("chat")
	var chat := c.app as ChatApp
	assert_true(await soon(func() -> bool: return chat.stream != null and chat.stream.state == "open" and not chat.send_button.disabled),
		"the agent's session, idle")
	var session_id := str(chat.session_row.get("id", ""))
	chat.prompt_field.grab_focus()
	chat.prompt_field.text = marks["typed in the chat"]
	tap(KEY_ENTER)
	assert_true(await soon(func() -> bool: return hub.session_events.get(session_id, []).any(
		func(e): return e["type"] == "user-prompt")), "the prompt reached the hub")
	hub.push_chat_event(session_id, "state", {"status": "working"})
	hub.push_chat_event(session_id, "agent-update", {"sessionUpdate": "agent_message_chunk",
		"content": {"type": "text", "text": marks["chat reply"]}})
	var request: Dictionary = hub.push_chat_event(session_id, "permission-request", {
		"toolCall": {"toolCallId": "call_1", "title": marks["permission request"], "kind": "execute"},
		"options": [{"optionId": "opt_1", "kind": "allow_once", "name": "Allow once"},
			{"optionId": "opt_2", "kind": "reject_once", "name": "Reject"}]})
	assert_true(await soon(func() -> bool: return chat.permission_card(request["seq"]) != null), "the permission request")
	chat.choose_option(request["seq"], "opt_1")
	assert_true(await soon(func() -> bool: return hub.session_events[session_id].any(
		func(e): return e["type"] == "permission-answer")), "answered")
	var frame: String = marks["malformed frame"]
	raw_frame(hub, "chat", "{\"t\":\"event\",\"event\":" + frame)
	raw_frame(hub, "chat", "{\"t\":\"event\",\"event\":\"" + frame + "\"}")
	raw_frame(hub, "chat", "{\"t\":\"event\",\"event\":{\"seq\":0,\"type\":\"agent-update\",\"payload\":\"" + frame + "\"}}")
	hub.push_chat_event(session_id, "state", {"status": "idle"})
	assert_true(await soon(func() -> bool: return str(chat.rows()).contains(marks["chat reply"]) \
		and str(chat.rows()).contains(marks["permission request"])), "the reply and the request are on the computer")
	assert_true(await soon(func() -> bool: return not chat.send_button.disabled), "and the chat is idle again")


## Files: the listing (whose first answer is a 401 with a marker in its
## body, exchanged again and retried) and a file's contents.
func use_files(c: ComputerScreen, hub, marks: Dictionary) -> void:
	hub.answer_with("hub", "GET /api/stations/:id/files", 401, {"error": "unauthorized " + marks["401 body"]})
	c.open_app("files")
	var files := c.app as FilesApp
	var name: String = marks["file name"] + ".txt"
	assert_true(await soon(func() -> bool: return files.listed(".").has(name)), "the file is listed")
	files.open_file(name)
	assert_true(await soon(func() -> bool: return files.preview.text.contains(marks["file content"])), "and read")


## Logs: a line from the tail.
func use_logs(c: ComputerScreen, hub, marks: Dictionary) -> void:
	c.open_app("logs")
	var logs := c.app as LogsApp
	assert_true(await soon(func() -> bool: return hub.tails_open(STATION) == 1), "the tail")
	hub.push_log(STATION, marks["log line"])
	assert_true(await soon(func() -> bool: return logs.line_count() > 0 and logs.line(logs.line_count() - 1).contains(marks["log line"])),
		"the log line is on the computer")


## Health: a 502 whose body the player never sees; retried, a body that is
## not JSON, cut short with a marker in it; retried again, the health.
func use_health(c: ComputerScreen, hub, marks: Dictionary) -> void:
	hub.answer_with("hub", "GET /api/stations/:id/health", 502, {"error": "health failed " + marks["error body"]})
	hub.answer_with("hub", "GET /api/stations/:id/health", 200, "{\"running\": \"" + marks["malformed body"])
	c.open_app("health")
	var health := c.app as HealthApp
	assert_true(await soon(func() -> bool: return health.error_text() != ""), "the 502 is shown")
	var first := health.error_text()
	assert_eq(found_in(first, {"the error body": marks["error body"]}), [], "as a fixed line, not its body")
	health.press_error_button()
	assert_true(await soon(func() -> bool: return health.error_text() != "" and health.error_text() != first),
		"the malformed body is shown as unreadable")
	assert_eq(found_in(health.error_text(), {"the malformed body": marks["malformed body"]}), [], "not as its body")
	health.press_error_button()
	assert_true(await soon(func() -> bool: return not health.health.is_empty()), "then the health")


## Changes: the changed file and its diff.
func use_changes(c: ComputerScreen, marks: Dictionary) -> void:
	c.open_app("changes")
	var changes := c.app as ChangesApp
	assert_true(await soon(func() -> bool: return changes.diff.text.contains(marks["diff"])), "the diff is on the computer")
	assert_true(str(changes.listed("uncommitted")).contains(marks["changed path"]), "and the changed file")


## Work: the station's agent chosen, a card's activity read, its gate
## approved with a comment, the question answered, malformed board frames
## dropped, and Superpipeline's two 401s in a row shown as signed out.
func use_work(c: ComputerScreen, hub, marks: Dictionary) -> void:
	c.open_app("work")
	var work := c.app as WorkApp
	assert_true(await soon(func() -> bool: return work.link_choices().has("Sample agent")), "which agent works here")
	work.choose_link(work.link_choices().find("Sample agent"))
	assert_true(await soon(func() -> bool: return work.card_row(BOARD, "crd_sample_tabs") != null \
		and work.card_row(BOARD, "crd_sample_json") != null), "the agent's cards")
	var gated := work.card_row(BOARD, "crd_sample_tabs")
	var asked := work.card_row(BOARD, "crd_sample_json")
	assert_true(gated.title_button.text.contains(marks["card title"]), "the card's title is on the computer")
	assert_true(asked.question_label.text.contains(marks["question"]), "and the question")
	work.select(BOARD, "crd_sample_tabs")
	assert_true(await soon(func() -> bool: return gated.activity.text.contains(marks["card activity"])), "and the activity")
	gated.gate_comment.text = marks["gate comment"]
	work.decide(BOARD, "crd_sample_tabs", "gate_sample", "approve")
	assert_true(await soon(func() -> bool: return hub.superpipeline["snapshot"]["gates"][0]["status"] != "pending"), "the gate approved")
	assert_eq(hub.superpipeline["snapshot"]["gates"][0].get("comment"), marks["gate comment"], "with the comment")
	work.answer_question(BOARD, "crd_sample_json", "elc_sample", "other", marks["answer"])
	assert_true(await soon(func() -> bool: return hub.superpipeline["snapshot"]["elicitations"][0]["status"] != "pending"),
		"the question answered")
	var frame: String = marks["malformed frame"]
	raw_frame(hub, "board", "{\"kind\":\"event\",\"event\":" + frame)
	raw_frame(hub, "board", "{\"kind\":\"snapshot\",\"state\":\"" + frame + "\"}")
	raw_frame(hub, "board", "{\"kind\":\"event\",\"event\":{\"seq\":99,\"type\":\"card.moved\",\"payload\":\"" + frame + "\"}}")
	await settle(5)
	hub.refuse("superpipeline", 401, 2)
	work.select(BOARD, "crd_sample_json")
	assert_true(await soon(func() -> bool: return work.error_text() != ""), "signed out of Superpipeline, said so")


## A malformed address: Superpipeline's, which the settings hold, cannot be
## parsed; the Work app says so, and nothing with it, or a token, is
## logged.
func meet_a_malformed_address(main, c: ComputerScreen, marks: Dictionary) -> void:
	var source: LiveSource = main._live_source
	var address := source.superpipeline_url
	source.superpipeline_url = "http://127.0.0.1:70000/" + marks["malformed address"]
	c.open_app("work")
	assert_true(await soon(func() -> bool: return c.app.error_text() != ""), "no address, said so")
	assert_eq(found_in(c.app.error_text(), {"the address": marks["malformed address"]}), [], "without the address")
	source.superpipeline_url = address
	c.show_desktop()


# ---- Watching ----

## The watch fixture: the district with a workstation placed in the
## reading room and bound to STATION (the district's own desks are hot
## desks), and a feed in which OWNER comes in, walks to it, uses it at
## OWNER_USES_AT and stands up at OWNER_LEAVES_AT: explicit commands at
## ticks the test names, not the fixture's schedule. Returns [manifest,
## feed].
static func bound_desk_fixture() -> Array:
	var manifest = StationSource.parse_json(CityPaths.district_manifest())
	manifest["city"]["districts"][0]["placements"].append({"id": BOUND_DESK, "kind": "workstation",
		"at": BOUND_DESK_AT, "facing": 90, "binding": {"source": "agentpod", "ref": STATION}})
	var profile := {"id": OWNER, "display_name": "Owner", "kind": {"type": "Human", "tier": "Registered"},
		"appearance": {"hair": "1", "palette": "2"}}
	var added := [
		{"at": 2, "command": {"type": "Arrive", "occupant": OWNER, "profile": profile, "room": "room:reading"}},
		{"at": 45, "command": {"type": "Go", "occupant": OWNER, "to": {"type": "Point", "pos": BOUND_DESK_AT}}},
		{"at": OWNER_USES_AT, "command": {"type": "Use", "occupant": OWNER, "target": BOUND_DESK, "capability": "use",
			"anchor": 1}},
		{"at": OWNER_LEAVES_AT, "command": {"type": "StopUsing", "occupant": OWNER}},
	]
	var lines := CityPaths.district_feed().strip_edges().split("\n")
	var entries := []
	for i in range(1, lines.size()):
		entries.append([int(JSON.parse_string(lines[i])["at"]), entries.size(), lines[i]])
	for entry in added:
		entry.merge({"record": "entry", "fixture": true})
		entries.append([int(entry["at"]), entries.size(), JSON.stringify(entry)])
	# By tick, and in the order written within one: the feed's own rule.
	entries.sort()
	return [JSON.stringify(manifest), lines[0] + "\n" + "\n".join(entries.map(func(e): return e[2])) + "\n"]


## Whether OWNER uses the bound desk, as the public sees it.
func owner_uses(main) -> bool:
	for v in Player.views_of(JSON.parse_string(main.driver.world.project_json("public"))):
		if v.get("id") == OWNER:
			var using = v.get("using")
			return using is Dictionary and using.get("target") == BOUND_DESK
	return false


## An open console session at STATION, as the owner left it, with the
## agent's reply in it.
func open_session(hub, reply: String) -> Dictionary:
	var row: Dictionary = hub.agentpod["acp_session"].duplicate(true)
	row.merge({"id": "acps_owner", "stationId": STATION}, true)
	hub.sessions.push_front(row)
	hub.push_chat_event(row["id"], "user-prompt", {"text": "run the tests"})
	hub.push_chat_event(row["id"], "agent-update", {"sessionUpdate": "agent_message_chunk",
		"content": {"type": "text", "text": reply}})
	hub.push_chat_event(row["id"], "state", {"status": "idle"})
	return row


## Review Focus 5 and Task 5's live watch, at a placed desk bound to the
## station, through play: behind a person at it, "Look at screen" is not
## offered with the sample (only where an agent sits), and is live, where
## the source can see the station. Watching opens the station read-only:
## every app shows what the station holds, and nothing is sent, to the
## city or to the station (no keystroke, no resize, no prompt, no session
## made, no operation). It closes by itself when the owner stands up, at
## the tick the feed names, and sends nothing then either. No marker
## reaches any channel.
func test_watching_a_bound_desk_live_sends_nothing() -> void:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var hub = fake_hub()
	var marks := markers()
	plant(hub, marks)
	open_session(hub, marks["chat reply"])
	var destinations := []
	StationSource.connecting = func(destination: String) -> void: destinations.append(destination)
	var fixture := bound_desk_fixture()
	var main = boot(fixture[0], fixture[1])
	var recording := record_bridge(main)
	assert_true(until_ticks(main, func() -> bool: return owner_uses(main), OWNER_USES_AT + 20), "the owner uses the bound desk")
	var desk := thing(main, BOUND_DESK)
	assert_eq(main.interaction.desk_of({"type": "placement", "target": BOUND_DESK})["binding"],
		{"source": "agentpod", "ref": STATION}, "the desk is bound to the station")
	walk_to(main, desk["anchors"][3]["pos"])
	main.player.view["facing"] = 90
	frames(main, 0.05)
	var target: Dictionary = main.interaction.current_target()
	assert_eq([target.get("target"), target.get("anchor")], [BOUND_DESK, 3], "behind the desk, at its stand anchor")
	assert_true(not main.interact.verbs(target).has("Look at screen"), "the sample: a person sits there, so not offered")

	go_live(main, hub)
	# Made as live mode comes on, the live source lists the stations at once;
	# until the list is in, the station is unknown, and not offered.
	assert_true(main.station_source is LiveSource, "a live source, made as live mode came on")
	assert_true(not offered(main), "live, before the list: not offered")
	assert_true(await soon(func() -> bool: return offered(main)), "once listed: offered")
	assert_eq(hub.requests_to("GET /api/fleet/agents").size(), 1, "listed once")
	# Signing in again, as another account that cannot see the station: the
	# source is replaced, the old one's list forgotten, and the new one's
	# leaves the desk out.
	var first: LiveSource = main.station_source
	var rows: Array = hub.agentpod["fleet_agents"]["agents"]
	hub.agentpod["fleet_agents"]["agents"] = [rows[1]]
	main._on_sign_in_finished(true, "", main.station_credential)
	assert_true(main.station_source != first and not first.may_see(STATION), "a new source; the old one's list forgotten")
	assert_true(not offered(main), "the new account's list not in yet: not offered")
	assert_true(await soon(func() -> bool: return hub.requests_to("GET /api/fleet/agents").size() == 2), "the new one lists")
	await settle(3)
	assert_true(not offered(main), "a list without the station: not offered")
	hub.agentpod["fleet_agents"]["agents"] = rows
	main._on_sign_in_finished(true, "", main.station_credential)
	assert_true(await soon(func() -> bool: return offered(main)), "the player's own account again: offered")
	target = main.interaction.current_target()
	assert_eq(main.interact.verbs(target)[0], "Look at screen", "live, at a desk bound to the station: offered first")
	var since: int = recording.calls.size()
	var frames_before: int = hub.frames.size()
	var requests_before: int = hub.requests.size()
	main._interact()
	assert_true(main._computer_open() and main.computer.watch, "watching")
	if not main._computer_open():
		main.free()
		hub.stop()
		OS.remove_logger(capture)
		return
	assert_true(main.driver.world.world.tick() < OWNER_LEAVES_AT, "before the owner stands up")
	# The test is the world's clock while it watches.
	main.driver.set_process(false)
	var c: ComputerScreen = main.computer
	assert_true(await soon(func() -> bool: return c.state == "desktop"), "the station's desktop, without the chooser")
	assert_eq(str(c.station.get("stationId")), STATION, "the desk's own station")

	c.open_app("terminal")
	var terminal := c.app as TerminalApp
	assert_true(await soon(func() -> bool: return terminal.stream != null and terminal.stream.state == "open"), "the owner's shell")
	hub.push_terminal(STATION, (marks["terminal output"] + "\r\n").to_utf8_buffer())
	assert_true(await soon(func() -> bool: return terminal.screen_text().contains(marks["terminal output"])), "its output shows")
	type_line(marks["typed in the terminal"])
	terminal.send("ls\r")
	terminal.paste("ls")
	c.open_app("chat")
	var chat := c.app as ChatApp
	assert_true(await soon(func() -> bool: return str(chat.rows()).contains(marks["chat reply"])), "the owner's chat shows")
	chat.prompt_field.text = marks["typed in the chat"]
	chat.send_prompt()
	chat.pick_mode("full-auto")
	for id in ["files", "logs", "health", "changes", "work"]:
		c.open_app(id)
		await settle(10)
	c.open_app("health")
	var health := c.app as HealthApp
	health.ask("stop")
	health.confirm()
	c.open_app("work")
	var work := c.app as WorkApp
	work.decide(BOARD, "crd_sample_tabs", "gate_sample", "reject")
	work.confirm()
	work.answer_question(BOARD, "crd_sample_json", "elc_sample", "other", marks["answer"])
	work.move(BOARD, "crd_sample_json", "review")
	await settle(10)
	c.show_desktop()
	await settle(5)

	var sent_frames: Array = hub.frames.slice(frames_before)
	assert_eq(sent_frames.filter(func(f): return f["kind"] != "chat"), [], "no frame on the terminal or the board")
	assert_eq(sent_frames.map(func(f): return f["frame"].get("t")), ["subscribe"], "the chat only subscribed")
	var asked: Array = hub.requests.slice(requests_before).map(func(r): return str(r["route"]))
	for route in asked:
		assert_true(route.begins_with("GET ") or route in ["POST /api/stations/:id/changeset/status",
			"POST /api/stations/:id/changeset/diff", "POST /api/auth/devices/token"],
			"only reads were asked for: " + route)
	assert_true(not asked.has("POST /api/stations/:id/acp/sessions"), "no session was made")
	assert_eq(hub.shells[STATION]["input"], "", "nothing was typed into the shell")
	assert_eq(recording.commands(since), [], "and nothing was sent to the city")

	var left := false
	for i in OWNER_LEAVES_AT + 5:
		if not main._computer_open():
			left = true
			break
		tick(main)
	assert_true(left, "the owner stood up: watching closed by itself")
	assert_eq(recording.commands(since), [], "sending nothing, no StopUsing among it")
	# Disconnecting forgets the list with the credential: the sample again.
	var live: LiveSource = main.station_source
	main._disconnect_station()
	assert_true(main.station_source is SampleSource and not live.may_see(STATION), "disconnected: the sample, the list forgotten")
	main.station_credential.cancel_browser()
	await settle(3)
	StationSource.connecting = Callable()
	assert_true(not destinations.is_empty(), "the connections were recorded")
	var allowed := allowed_destinations(hub, main.station_credential)
	for destination in destinations:
		assert_true(destination in allowed, "a connection went only to the fake: " + destination)
	var bridge := JSON.stringify(recording.calls)
	var input_log: String = main.driver.world.world.input_log_jsonl()
	var this_run: Dictionary = marks.duplicate()
	this_run.merge(secrets_of(hub))
	main.free()
	hub.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CREDENTIAL_FILE))
	OS.remove_logger(capture)
	assert_eq(hub.violations, [], "the fake saw nothing it does not know")
	assert_eq(found_in(bridge, this_run), [], "no marker in any bridge call")
	assert_eq(found_in(input_log, this_run), [], "none in the input log")
	assert_eq(found_in("\n".join(capture.lines), this_run), [], "none in anything logged")
	assert_eq(found_in("\n".join(runner.errors), this_run), [], "none in the error watch")
	assert_eq(found_in(log_files(), this_run), [], "none in the client's log files")


## Review Focus 5 for the live source, as ruled: the source lists the
## player's stations once (as it is made, or signing in finishes), and until
## the list is in a station is unknown, and unknown is not offered. After,
## only a desk bound to a listed station. A refused list, forgetting (a
## replaced source) and a sign-out each forget what was listed, and a new
## source (another account) knows nothing yet. With the sample, only where
## an agent sits.
func test_look_at_screen_is_offered_only_where_the_source_can_see_the_station() -> void:
	var hub = fake_hub()
	var source := live_source(hub)
	var mine := {"target": BOUND_DESK, "binding": {"source": "agentpod", "ref": STATION}}
	var theirs := {"target": "placement:their-desk", "binding": {"source": "agentpod", "ref": "stn_theirs"}}
	var hot := {"target": "seat:w1", "binding": {}}
	assert_true(not ComputerScreen.may_watch(mine, source, false) and not ComputerScreen.may_watch(theirs, source, false),
		"nothing listed yet: unknown, so not offered")
	assert_true(not ComputerScreen.may_watch(hot, source, true), "never a hot desk, live")
	assert_true((await answer_of(source, source.list_stations()))[0], "listed")
	assert_true(ComputerScreen.may_watch(mine, source, false), "the player's own station's desk")
	assert_true(not ComputerScreen.may_watch(theirs, source, false), "not a desk bound to a station the player cannot see")
	hub.refuse("hub", 403, 1)
	assert_true(not (await answer_of(source, source.list_stations()))[0], "a list refused")
	assert_true(not ComputerScreen.may_watch(mine, source, false), "forgets what was listed")
	assert_true((await answer_of(source, source.list_stations()))[0], "listed again")
	assert_true(ComputerScreen.may_watch(mine, source, false), "and seen again")
	source.forget_stations()
	assert_true(not ComputerScreen.may_watch(mine, source, false), "forgotten, as main forgets a replaced source's")
	assert_true((await answer_of(source, source.list_stations()))[0], "listed once more")
	source.credential.refuse()
	assert_true(not ComputerScreen.may_watch(mine, source, false), "signed out: forgotten")
	var other := live_source(hub)
	assert_true(not ComputerScreen.may_watch(mine, other, false), "another account's new source knows nothing yet")
	var sample := SampleSource.new()
	assert_true(ComputerScreen.may_watch(hot, sample, true), "the sample: where an agent sits")
	assert_true(not ComputerScreen.may_watch(hot, sample, false) and not ComputerScreen.may_watch(mine, sample, false),
		"and nowhere else")
	hub.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CREDENTIAL_FILE))


## Offers "Look at screen" wherever it is asked, as Interact would behind
## any occupied desk: the gate alone may take it away.
class EveryDeskWatched extends Interact:
	func targets(_query: Dictionary) -> Array:
		return [{"type": "placement", "target": BOUND_DESK, "kind": "workstation", "anchor": 3,
			"capabilities": ["watch", "inspect"], "pos": Vector2.ZERO}]


## A tap goes through the same gate as the prompt: where the player's
## source may not see the screen, a tapped desk offers no "Look at screen".
func test_a_tap_offers_look_at_screen_only_where_the_prompt_would() -> void:
	var controller := InteractionController.new()
	controller.interact = EveryDeskWatched.new()
	assert_eq(controller.tap_target(Vector2.ZERO)["capabilities"], ["watch", "inspect"], "ungated, as Interact offers it")
	controller.watch_gate = func(_target: Dictionary) -> bool: return false
	assert_eq(controller.tap_target(Vector2.ZERO)["capabilities"], ["inspect"], "the gate refuses: no Look at screen")
	controller.watch_gate = func(target: Dictionary) -> bool: return target["target"] == BOUND_DESK
	assert_eq(controller.tap_target(Vector2.ZERO)["capabilities"], ["watch", "inspect"], "the gate allows: offered")


# ---- The code ----

## `text` with its comments taken out: from each `#` outside a string to
## the line's end.
static func code_of(text: String) -> String:
	var out := PackedStringArray()
	for line in text.split("\n"):
		var quote := ""
		var cut := line.length()
		var i := 0
		while i < line.length():
			var ch := line[i]
			if quote != "":
				if ch == "\\":
					i += 1
				elif ch == quote:
					quote = ""
			elif ch == "\"" or ch == "'":
				quote = ch
			elif ch == "#":
				cut = i
				break
			i += 1
		out.append(line.substr(0, cut))
	return "\n".join(out)


## Every script under `dir`, however deep.
static func scripts_under(dir: String) -> Array:
	var out := []
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):
			out.append(dir.path_join(name))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(scripts_under(dir.path_join(sub)))
	return out


## `code` (comments already out) with every string literal emptied, so
## what is left is the code alone: names in text a player reads are not
## calls.
static func without_literals(code: String) -> String:
	return RegEx.create_from_string("\"(?:[^\"\\\\\\n]|\\\\.)*\"|'(?:[^'\\\\\\n]|\\\\.)*'").sub(code, "\"\"", true)


## The string literals in `code` (comments already out).
static func literals_of(code: String) -> Array:
	return RegEx.create_from_string("\"(?:[^\"\\\\\\n]|\\\\.)*\"|'(?:[^'\\\\\\n]|\\\\.)*'").search_all(code) \
		.map(func(found: RegExMatch) -> String: return found.get_string())


## What code may not do to reach the city, each with why: the world and
## whatever holds it (main's driver, the player, the interaction path), and
## the scene tree's top, from which main could be found.
const REACHING_THE_CITY := {
	"\\b(CityWorld|WorldDriver|InteractionController|Player)\\b": "a class that holds or drives the world",
	"\\b(world|driver|player|interaction)\\b": "the world, or what holds it",
	"\\b(get_node|get_node_or_null|get_tree|current_scene|get_first_node_in_group|get_nodes_in_group)\\b":
		"the scene tree, where main is",
	"\\)\\s*\\.\\s*root\\b": "the scene tree's root",
}


## Nothing under core/station reaches the city: with comments and string
## literals taken out, no script names the world, what holds it, or the
## scene tree's top; no literal names a class that does, or a node path
## from the root. No script names a city server: every address literal is
## a scheme, the sign-in's own listener on 127.0.0.1, or this computer's
## loopback names (plain http may reach only those), and no setting
## names a server at all. In main, every function of the station computer's
## section, and every handler main connects to the computer, the
## credential or the watch gate, calls the world only through the player's
## StopUsing.
func test_the_station_code_names_no_city_server_and_never_reaches_the_world() -> void:
	var paths := scripts_under("res://core/station")
	assert_true(paths.size() >= 30, "every station script is read: %d" % paths.size())
	var addresses := RegEx.create_from_string("\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\b|localhost")
	var allowed := ["\"http://\"", "\"https://\"", "\"ws://\"", "\"wss://\"", "\"://\"",
		"\"http://127.0.0.1:%d/callback\"", "\"127.0.0.1\"", "\"::1\"", "\"localhost\""]
	for path in paths:
		var code := code_of(FileAccess.get_file_as_string(path))
		assert_true(not code.is_empty(), path + " reads")
		var bare := without_literals(code)
		for pattern in REACHING_THE_CITY:
			for found in RegEx.create_from_string(pattern).search_all(bare):
				assert_true(false, "%s reaches for %s: %s" % [path.get_file(), REACHING_THE_CITY[pattern], found.get_string()])
		for literal in literals_of(code):
			for name in ["CityWorld", "WorldDriver", "/root"]:
				assert_true(not literal.contains(name), "%s names %s in a literal" % [path.get_file(), name])
			# The game's own files (res://, user://) are no address.
			if literal.begins_with("\"res://") or literal.begins_with("\"user://"):
				continue
			if literal.contains("://") or addresses.search(literal) != null:
				assert_true(literal in allowed, "%s names an address: %s" % [path.get_file(), literal])
		for found in RegEx.create_from_string("get_value\\(\\s*\"(\\w+)\"").search_all(code):
			assert_eq(found.get_string(1), "station", path.get_file() + " reads only the station settings")
	# The rule itself catches what it should.
	var sample_bad := without_literals(code_of("var w = get_tree().root.get_node(\"Main\").driver.world\n"))
	var caught := 0
	for pattern in REACHING_THE_CITY:
		if RegEx.create_from_string(pattern).search(sample_bad) != null:
			caught += 1
	assert_eq(caught, 3, "the rules catch a reach for main through the tree")
	assert_eq(without_literals(code_of("label.text = \"the player's world\" # the world\n")).contains("world"), false,
		"and not a player's word in a label, nor a comment")
	for section in Settings.DEFAULTS:
		for key in Settings.DEFAULTS[section]:
			assert_true(not "server" in str(key).to_lower(), "no setting names a server: %s/%s" % [section, key])
	assert_eq(Settings.DEFAULTS["station"].keys(), ["live", "hub_url", "superpipeline_url", "console_url", "client_id"],
		"the station's addresses: the hub, Superpipeline and the console")

	# main.gd: the station computer's section, and every handler main
	# connects to the computer, a credential or the watch gate.
	var main_text := FileAccess.get_file_as_string("res://main.gd")
	# Taking comments and literals out keeps every line where it was.
	var main_code := without_literals(code_of(main_text))
	var functions := functions_of(main_code)
	var names := []
	var header := main_text.find("# ---- The station computer ----")
	assert_true(header > 0, "main's station section")
	var from_line := main_text.substr(0, header).count("\n")
	var section_end := main_text.find("\n# ---- ", header + 1)
	var to_line := main_text.substr(0, section_end).count("\n") if section_end > 0 else main_text.count("\n") + 1
	for name in functions:
		var line := main_code.substr(0, main_code.find("func " + name + "(")).count("\n")
		if line > from_line and line < to_line:
			names.append(name)
	var wiring := RegEx.create_from_string("(computer|station_credential|credential|interaction)\\.(\\w+)\\.connect\\((\\w+)|interaction\\.watch_gate\\s*=\\s*(\\w+)")
	for found in wiring.search_all(main_code):
		var handler := found.get_string(3) if found.get_string(3) != "" else found.get_string(4)
		if functions.has(handler) and not handler in names:
			names.append(handler)
	for handler in ["_on_computer_left", "_on_use_began", "_on_watch_requested", "_may_watch", "_open_settings",
			"_on_sign_in_finished", "_on_disconnect_finished"]:
		assert_true(handler in names, "main's %s is checked" % handler)
	var calls_the_world := RegEx.create_from_string("\\bdriver\\b|\\bworld\\b|\\bplayer\\.(?!stop_using\\()(\\w+)\\s*\\(|interaction\\._act\\b")
	var stands_up := 0
	for name in names:
		for found in calls_the_world.search_all(functions[name]):
			assert_true(false, "main's %s calls the world: %s" % [name, found.get_string()])
		stands_up += functions[name].count("player.stop_using()")
	assert_eq(stands_up, 1, "the one call to the world: the player's StopUsing, as the computer is left")


## `code`'s functions by name, each its text to the next function.
static func functions_of(code: String) -> Dictionary:
	var out := {}
	var starts := RegEx.create_from_string("(?m)^(?:static )?func (\\w+)").search_all(code)
	for i in starts.size():
		var end: int = starts[i + 1].get_start() if i + 1 < starts.size() else code.length()
		out[starts[i].get_string(1)] = code.substr(starts[i].get_start(), end - starts[i].get_start())
	return out


## A test run opens no real browser: the runner puts a no-op in the one
## seam every station browser page goes through (a sign-in, a Disconnect,
## the console, Superpipeline), and the credential no longer checks for the
## runner itself.
func test_a_test_run_opens_no_browser() -> void:
	var opened := []
	var was: Callable = SystemBrowser.opener
	SystemBrowser.opener = func(url: String) -> void: opened.append(url)
	StationCredential.open_in_system_browser("https://example.invalid/sign-in")
	var screen := ComputerScreen.new()
	screen.open_url.call("https://example.invalid/console")
	screen.free()
	SystemBrowser.opener = was
	assert_eq(opened, ["https://example.invalid/sign-in", "https://example.invalid/console"],
		"the credential and the computer both open pages through the seam")
	assert_true(not FileAccess.get_file_as_string("res://core/station/credential.gd").contains("run_all"),
		"the credential does not look for the test runner")
	assert_true(was.is_valid() and was.get_method() == "_open_no_browser", "the runner installs its no-op")
