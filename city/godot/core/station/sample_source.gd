## Sample station: the recording bundled under res://sample_station/,
## played behind the station interface. Everyone without a sign-in gets it.
##
## It answers as the live routes do, in their shapes and on a later frame,
## and changes as they would: stopping the agent stops its health, the
## chat's permission request plays the recorded continuation once answered,
## and resolving the gate or answering the question moves the board. It
## reads nothing but the recording and opens no connection; see the README
## beside the recording for what each file stands in for.
##
## This file keeps the station itself: its list entry, health, files,
## lifecycle, and answers for the rest from helpers under sample/: the
## recorded workspace (`SampleWorkspace`), the console session
## (`SampleChatState`), the boards (`SampleWork`) and the stream players.
class_name SampleSource
extends StationSource

const ROOT := "res://sample_station/"

## The longest pause the recording plays, in recorded seconds; a longer one
## is cut to this.
const MAX_GAP := 3.0

## Each health reading is this many seconds after the last: the Health
## app's refresh.
const HEALTH_STEP_SECONDS := 5

## Who the sample's player is, where the routes would name the signed-in
## user.
const PLAYER := "usr_sample"

## How fast the recording plays: 1 is as recorded. Tests raise it so a
## recorded second passes in a moment.
var speed := 1.0:
	set(value):
		speed = value
		if _work != null:
			_work.speed = value
		if _chat_state != null:
			_chat_state.speed = value

## The recorded log, a line an entry.
var log_lines: PackedStringArray
## The terminal recording, as `SampleTerminalStream.read_cast` splits it.
var terminal_segments: Array = []

var _fleet: Dictionary
var _station_id: String
var _health_series: Array
var _workspace: SampleWorkspace
var _chat_state: SampleChatState
var _work: SampleWork

# The station's process, which lifecycle changes.
var _running := true
var _pid := 0
var _uptime := 0
var _health_index := 0


func _init() -> void:
	_fleet = _read_json("station.json")
	_station_id = _fleet["agents"][0]["stationId"]
	_health_series = _read_json("health.json")
	_pid = _health_series[0]["pid"]
	_uptime = _health_series[0]["uptimeSec"]
	_workspace = SampleWorkspace.new(
		_read_json("files.json"), _read_json("changeset.json"),
		FileAccess.get_file_as_string(ROOT + "diff.patch"), ROOT + "files/"
	)
	log_lines = FileAccess.get_file_as_string(ROOT + "logs.txt").strip_edges(false, true).split("\n")
	terminal_segments = SampleTerminalStream.read_cast(FileAccess.get_file_as_string(ROOT + "terminal.cast"))
	_chat_state = SampleChatState.new(_read_json("chat.json"))
	_work = SampleWork.new(_read_json("work.json"))


func _is_live() -> bool:
	return false


## Whether `station_id` is Sample station's, the only station it has.
func has_station(station_id: String) -> bool:
	return station_id == _station_id


## The Superpipeline agent that works at `station_id`, built into the
## recording so the Work app need not ask; empty for any other station.
func built_in_agent_link(station_id: String) -> String:
	return _work.agent_link(station_id)


# --- Stations ---

func list_stations() -> int:
	return _answer_later(func() -> Array:
		var body := _fleet.duplicate(true)
		var agent: Dictionary = body["agents"][0]
		var reading := _health_body()
		agent["status"] = "running" if _running else "stopped"
		agent["cpuPct"] = reading["cpuPct"]
		agent["memBytes"] = reading["memBytes"]
		agent["uptimeSec"] = reading["uptimeSec"]
		body["stats"]["running"] = 1 if _running else 0
		stations.emit(body["agents"].duplicate(true))
		return success(body))


func health(station_id: String) -> int:
	return _answer_later(func() -> Array:
		if not has_station(station_id):
			return _no_station()
		var body := _health_body()
		_health_index += 1
		if _running:
			_uptime += HEALTH_STEP_SECONDS
		return success(body))


func files(station_id: String, path: String) -> int:
	return _for_station(station_id, _workspace.files.bind(path))


func file(station_id: String, path: String, max_bytes: int) -> int:
	return _for_station(station_id, _workspace.file.bind(path, max_bytes))


func lifecycle(station_id: String, action: String) -> int:
	return _answer_later(func() -> Array:
		if not has_station(station_id):
			return _no_station()
		match action:
			"stop":
				_running = false
			"start":
				if not _running:
					_new_process()
			"restart":
				_new_process()
			_:
				return failure("failed", "Unknown lifecycle action.", 400)
		return success(_health_body()))


func changeset_status(station_id: String, base: String) -> int:
	return _for_station(station_id, _workspace.changeset_status.bind(base))


func changeset_diff(station_id: String, side: String, path: String) -> int:
	return _for_station(station_id, _workspace.changeset_diff.bind(side, path))


func open_logs(station_id: String) -> StationStream.Logs:
	return SampleLogStream.new(self, station_id)


func open_terminal(station_id: String) -> StationStream.Terminal:
	return SampleTerminalStream.new(self, station_id)


func open_chat(station_id: String, mode: String, _new_session := false) -> StationStream.Chat:
	# While the recording's session is open this is the live source's reuse
	# path: it keeps its own mode, whatever was asked for. Once ended, a new
	# one starts in `mode`. The Chat app ends the one session before it asks
	# for a new one, so asking changes nothing here.
	if has_station(station_id) and _chat_state.session["status"] == "ended":
		_chat_state.start_new(mode)
	return SampleChatStream.new(self, _chat_state, station_id)


func watch_chat(station_id: String) -> StationStream.Chat:
	# Attaches only: an ended session is not replaced, as open_chat would.
	return SampleChatStream.new(self, _chat_state, station_id, true)


func end_chat(session_id: String) -> int:
	return _answer_later(_chat_state.end_session.bind(session_id))


# --- Work, which SampleWork keeps ---

func boards() -> int:
	return _answer_later(_work.boards)


func board(board_id: String) -> StationStream.Board:
	return SampleBoardStream.new(self, _work, board_id)


func agents() -> int:
	return _answer_later(_work.agents)


func card_activities(board_id: String, card_id: String) -> int:
	return _answer_later(_work.card_activities.bind(board_id, card_id))


func move_card(board_id: String, card_id: String, to_stage: String) -> int:
	return _answer_later(_work.move_card.bind(board_id, card_id, to_stage))


func resolve_gate(board_id: String, gate_id: String, decision: String, comment: String) -> int:
	return _answer_later(_work.resolve_gate.bind(board_id, gate_id, decision, comment))


func answer(board_id: String, elicitation_id: String, option: String, text: String) -> int:
	return _answer_later(_work.answer.bind(board_id, elicitation_id, option, text))


# --- Answering later, shared with the players under sample/ ---

## Runs `callable` `seconds` of recorded time from now, played at `speed`,
## on a later frame even when `seconds` is 0, so nothing answers inside
## the call that asked.
static func schedule(at_speed: float, seconds: float, callable: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.create_timer(maxf(seconds, 0.0) / maxf(at_speed, 0.001), true).timeout.connect(callable)


## A call's answer: [ok, body, status].
static func success(body: Variant, status := 200) -> Array:
	return [true, body, status]


static func failure(kind: String, message: String, status: int) -> Array:
	return [false, StationSource.make_error(kind, message), status]


## The time now, as the routes write it: ISO 8601 in UTC, to the millisecond.
static func timestamp() -> String:
	var unix := Time.get_unix_time_from_system()
	return Time.get_datetime_string_from_unix_time(int(unix)) + ".%03dZ" % (int(unix * 1000.0) % 1000)


static func copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


## Drops the streams their apps have let go of.
static func forget_freed(refs: Array[WeakRef]) -> void:
	for i in range(refs.size() - 1, -1, -1):
		if refs[i].get_ref() == null:
			refs.remove_at(i)


## `schedule` at this source's speed.
func after(seconds: float, callable: Callable) -> void:
	schedule(speed, seconds, callable)


## Answers a call on a later frame with what `compute` returns, an array
## of [ok, body, status]. The work happens then too, as the route's would.
func _answer_later(compute: Callable) -> int:
	var call_id := _new_call_id()
	after(0.0, func() -> void:
		var outcome: Array = compute.call()
		result.emit(call_id, outcome[0], outcome[1], outcome[2]))
	return call_id


func _no_station() -> Array:
	return failure("not_found", "Not Found", 404)


## Answers with `compute` for Sample station, and 404 for any other.
func _for_station(station_id: String, compute: Callable) -> int:
	return _answer_later(func() -> Array: return compute.call() if has_station(station_id) else _no_station())


# --- The station's process ---

func _health_body() -> Dictionary:
	var reading: Dictionary = _health_series[_health_index % _health_series.size()].duplicate()
	if not _running:
		return {
			"running": false, "pid": null, "cpuPct": null, "memBytes": null,
			"diskBytes": reading["diskBytes"], "uptimeSec": null,
			"lastActivity": reading["lastActivity"], "note": null,
		}
	reading["pid"] = _pid
	reading["uptimeSec"] = _uptime
	return reading


func _new_process() -> void:
	_running = true
	_pid += 1
	_uptime = 0


func _read_json(name: String) -> Variant:
	return StationSource.parse_json(FileAccess.get_file_as_string(ROOT + name))
