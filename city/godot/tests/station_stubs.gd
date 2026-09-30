## What the station computer's app tests share: a stub source whose every
## answer the test scripts, the streams it hands out (each recording what
## the app sends), station rows of the protocol's shape, and helpers that
## open an app as the computer would. `test_station_apps.gd` (Task 6's
## apps), `test_chat_app.gd` and `test_work_app.gd` extend it; the runner
## runs only files named test_*.
extends TestSuite

const SETTINGS_FILE := "user://test_station_apps.cfg"
## The Work app's station links in these tests, never the player's own.
const LINKS_FILE := "user://test_station_links.cfg"
const ESC := "\u001b"


## A source whose calls wait for the test to answer them, and whose streams
## the test drives. It records every call.
class StubSource extends StationSource:
	var live := false
	## Every call: {method, args, id}, in order.
	var calls: Array = []
	var terminals: Array = []
	var log_streams: Array = []
	var chats: Array = []
	var board_streams: Array = []
	## The agent a station's Work app finds already linked, by station ID.
	var built_in_links := {}

	func _is_live() -> bool:
		return live

	func _record(method: String, args: Array) -> int:
		var call_id := _new_call_id()
		calls.append({"method": method, "args": args, "id": call_id})
		return call_id

	## The calls to `method`, in order.
	func calls_to(method: String) -> Array:
		return calls.filter(func(c): return c["method"] == method)

	func last(method: String) -> Dictionary:
		var made := calls_to(method)
		return made.back() if not made.is_empty() else {}

	## Answers the last call to `method`.
	func reply(method: String, body: Variant) -> void:
		result.emit(last(method)["id"], true, body, 200)

	## Fails the last call to `method` with an error of `kind`.
	func refuse(method: String, kind: String, message := "refused", status := 502) -> void:
		result.emit(last(method)["id"], false, StationSource.make_error(kind, message), status)

	func built_in_agent_link(station_id: String) -> String:
		return built_in_links.get(station_id, "")

	func list_stations() -> int:
		return _record("list_stations", [])

	func health(station_id: String) -> int:
		return _record("health", [station_id])

	func files(station_id: String, path: String) -> int:
		return _record("files", [station_id, path])

	func file(station_id: String, path: String, max_bytes: int) -> int:
		return _record("file", [station_id, path, max_bytes])

	func lifecycle(station_id: String, action: String) -> int:
		return _record("lifecycle", [station_id, action])

	func changeset_status(station_id: String, base: String) -> int:
		return _record("changeset_status", [station_id, base])

	func changeset_diff(station_id: String, side: String, path: String) -> int:
		return _record("changeset_diff", [station_id, side, path])

	func open_logs(_station_id: String) -> StationStream.Logs:
		var stream := StubLogs.new()
		log_streams.append(stream)
		return stream

	func open_terminal(_station_id: String) -> StationStream.Terminal:
		var stream := StubTerminal.new()
		terminals.append(stream)
		return stream

	func open_chat(station_id: String, mode: String, new_session := false) -> StationStream.Chat:
		_record("open_chat", [station_id, mode, new_session])
		var stream := StubChat.new()
		chats.append(stream)
		return stream

	func watch_chat(station_id: String) -> StationStream.Chat:
		_record("watch_chat", [station_id])
		var stream := StubChat.new()
		chats.append(stream)
		return stream

	func end_chat(session_id: String) -> int:
		return _record("end_chat", [session_id])

	func boards() -> int:
		return _record("boards", [])

	func board(board_id: String) -> StationStream.Board:
		_record("board", [board_id])
		var stream := StubBoard.new()
		stream.board_id = board_id
		board_streams.append(stream)
		return stream

	func agents() -> int:
		return _record("agents", [])

	func card_activities(board_id: String, card_id: String) -> int:
		return _record("card_activities", [board_id, card_id])

	func move_card(board_id: String, card_id: String, to_stage: String) -> int:
		return _record("move_card", [board_id, card_id, to_stage])

	func resolve_gate(board_id: String, gate_id: String, decision: String, comment: String) -> int:
		return _record("resolve_gate", [board_id, gate_id, decision, comment])

	func answer(board_id: String, elicitation_id: String, option: String, text: String) -> int:
		return _record("answer", [board_id, elicitation_id, option, text])


## A terminal the test drives: it records what the app sends.
class StubTerminal extends StationStream.Terminal:
	var inputs: Array = []
	var resizes: Array = []
	## Raw keystrokes sent as bytes (a NUL, which a String cannot carry).
	var bytes_sent := PackedByteArray()

	func send_input(text: String) -> void:
		inputs.append(text)

	func send_bytes(bytes: PackedByteArray) -> bool:
		bytes_sent.append_array(bytes)
		return true

	func send_resize(cols: int, rows: int) -> void:
		resizes.append(Vector2i(cols, rows))

	func close() -> void:
		_set_state("closed")

	func open() -> void:
		_set_state("open")

	## Everything sent, joined.
	func sent() -> String:
		return "".join(inputs)


class StubLogs extends StationStream.Logs:
	func close() -> void:
		_set_state("closed")

	func open() -> void:
		_set_state("open")


## A console session the test drives: it records what the app sends, and
## plays the hub's side.
class StubChat extends StationStream.Chat:
	var prompts: Array = []
	var cancels := 0
	## Each permission answer, [request_seq, option_id].
	var answers: Array = []
	var modes: Array = []

	func prompt(text: String) -> void:
		prompts.append(text)

	func cancel() -> void:
		cancels += 1

	func answer(request_seq: int, option_id: String) -> void:
		answers.append([request_seq, option_id])

	func set_mode(mode: String) -> void:
		modes.append(mode)

	func close() -> void:
		_set_state("closed")

	func open() -> void:
		_set_state("open")

	## Opens and replays `events` after the session row, as the hub does.
	func replay(row: Dictionary, events: Array) -> void:
		open()
		session.emit(row)
		var last := 0
		for e in events:
			event.emit(e)
			last = maxi(last, int(e["seq"]))
		replay_done.emit(last)


## A board channel the test drives.
class StubBoard extends StationStream.Board:
	var board_id := ""

	func close() -> void:
		_set_state("closed")

	func open() -> void:
		_set_state("open")

	## Opens with `state` as its snapshot, as a (re)connection does.
	func send_snapshot(state: Dictionary) -> void:
		open()
		snapshot.emit(state)


## A source whose terminal is already open when handed over, as a live one
## reusing its connection could be.
class OpenTerminalSource extends StubSource:
	func open_terminal(station_id: String) -> StationStream.Terminal:
		var stream: StubTerminal = super(station_id)
		stream.open()
		return stream


## A `FleetAgent` of the protocol's shape.
static func station_row(capabilities := EVERY_CAPABILITY, node_status := "online") -> Dictionary:
	return {
		"stationId": "stn_a", "nodeId": "node_1", "nodeName": "node-one", "agentName": "Build box",
		"harness": "claude-code", "kind": "leaf", "nodeStatus": node_status, "agentVersion": "1.0.0",
		"latestVersion": "1.0.0", "updateAvailable": false, "capabilities": capabilities,
		"workspacePath": "/work/repo", "status": "running", "cpuPct": 1.0, "memBytes": 1000, "uptimeSec": 60,
	}


const EVERY_CAPABILITY := ["health", "logs", "fs.read", "terminal", "lifecycle", "acp", "changeset"]


## Sample station's own row, as its list gives it.
static func sample_row() -> Dictionary:
	var fleet = JSON.parse_string(FileAccess.get_file_as_string("res://sample_station/station.json"))
	return StationSource.parse_json(JSON.stringify(fleet["agents"][0]))


## A source that plays the recording quickly: a recorded second passes in a
## millisecond.
func sample() -> SampleSource:
	var source := SampleSource.new()
	source.speed = 1000.0
	return source


func fresh_settings() -> Settings:
	var s := Settings.new()
	s.path = SETTINGS_FILE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(s.path))
	s.load_file()
	return s


## Makes app `id` as the computer would, in the window at `size`.
func open(id: String, source: StationSource, row: Dictionary, read_only := false, settings: Settings = null,
		size := Vector2(1200, 640), style := {}) -> StationApp:
	var app := ComputerScreen.make_app(id)
	app.ui = UiTheme.from_style(style)
	app.settings = settings
	app.setup(source, row, read_only)
	runner.root.add_child(app)
	app.restyle()
	app.position = Vector2.ZERO
	app.size = size
	return app


func close(app: StationApp) -> void:
	var streams := []
	if app is TerminalApp or app is LogsApp:
		streams.append(app.stream)
	app.closing()
	app.free()
	for stream in streams:
		if stream != null:
			assert_eq(stream.state, "closed", "closing the app closes its stream")


func settle(n := 3) -> void:
	for f in n:
		await runner.process_frame


## Waits frame by frame until `condition` holds, for at most `frames`.
func until(condition: Callable, frames := 3000) -> bool:
	for i in frames:
		if condition.call():
			return true
		await runner.process_frame
	return condition.call()


func key(code: int, unicode := 0, ctrl := false, alt := false, shift := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.unicode = unicode
	e.ctrl_pressed = ctrl
	e.alt_pressed = alt
	e.shift_pressed = shift
	e.pressed = true
	return e


func click(button: int) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.factor = 1.0
	return e
