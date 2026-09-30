## Sample station's console session: the recorded session from chat.json
## and what happens to it. Like the hub's, it outlives the chats that watch
## it, so reopening the chat replays everything. The messages a chat sends
## (prompt, answer, cancel, set-mode) change it as the hub's service does
## (acp-sessions.ts at 9bc1997), writing the events the hub would write and
## playing the agent's recorded steps. Ending it (the DELETE route) closes
## its chats, and the next chat starts a new, empty session.
class_name SampleChatState
extends RefCounted

## The hub's own words for a refused console message.
const SESSION_BUSY := "Session is busy — wait for the current turn to finish."
const NO_PENDING_REQUEST := "No pending permission request."
const INVALID_MESSAGE := "Invalid message."

const MODES := ["ask", "accept-edits", "full-auto"]
## Why the hub ends a session the player ends (station-acp.ts).
const ENDED_FROM_CONSOLE := "Ended from the console."

## How fast the recording plays; the source keeps it in step with its own.
var speed := 1.0

## The session's `AcpSessionRow`, as it stands now.
var session: Dictionary
## Every event in the session, in `seq` order.
var events: Array = []

var _recording: Dictionary
## The permission request waiting for an answer, or empty.
var _waiting_request := {}
## Bumped to stop a turn that is playing, when it is cancelled.
var _turn := 0
var _chats: Array[WeakRef] = []
## The sessions ended so far, which a second end finds.
var _ended_ids: Array[String] = []


func _init(recording: Dictionary) -> void:
	_recording = recording
	session = recording["session"].duplicate(true)
	events = recording["events"].duplicate(true)
	_waiting_request = _find_waiting_request(events)


## Sends the session's new events to `chat` from now on, while it is open.
func watch(chat: SampleChatStream) -> void:
	SampleSource.forget_freed(_chats)
	_chats.append(weakref(chat))


func prompt(chat: SampleChatStream, text: String) -> void:
	if text.is_empty():
		_refuse(chat, INVALID_MESSAGE)
		return
	if session["status"] != "idle":
		_refuse(chat, SESSION_BUSY)
		return
	if session["title"] == null:
		session["title"] = text.left(80)
	_record("user-prompt", {"text": text})
	_record("state", {"status": "working"})
	_play_turn(_recording["reply"], 0, _turn)


func answer(chat: SampleChatStream, request_seq: int, option_id: String) -> void:
	if _waiting_request.is_empty() or _waiting_request["seq"] != request_seq:
		_refuse(chat, NO_PENDING_REQUEST)
		return
	var kind := ""
	for option in _waiting_request["payload"]["options"]:
		if option["optionId"] == option_id:
			kind = option["kind"]
	_waiting_request = {}
	_record("permission-answer", {"requestSeq": request_seq, "optionId": option_id})
	_record("state", {"status": "working"})
	var continuation := "allow" if kind.begins_with("allow") else "reject"
	_play_turn(_recording["continuations"][continuation], 0, _turn)


func cancel() -> void:
	if not session["status"] in ["working", "waiting"]:
		return
	_turn += 1
	if not _waiting_request.is_empty():
		_record("permission-answer", {"requestSeq": _waiting_request["seq"], "cancelled": true})
		_waiting_request = {}
	_record("state", {"status": "idle"})


func set_mode(chat: SampleChatStream, mode: String) -> void:
	if not mode in MODES:
		_refuse(chat, INVALID_MESSAGE)
		return
	# The hub records the mode on the session and sends nothing.
	session["mode"] = mode


## Ends session `session_id`, as the DELETE route does: [ok, body, status].
func end_session(session_id: String) -> Array:
	if session_id in _ended_ids:
		return SampleSource.success(null, 204)
	if session_id != session["id"]:
		return SampleSource.failure("not_found", "Not Found", 404)
	_turn += 1
	if not _waiting_request.is_empty():
		_record("permission-answer", {"requestSeq": _waiting_request["seq"], "cancelled": true})
		_waiting_request = {}
	session["endedReason"] = ENDED_FROM_CONSOLE
	_record("state", {"status": "ended", "reason": ENDED_FROM_CONSOLE})
	_ended_ids.append(session_id)
	# The hub says bye and closes each socket.
	for ref in _chats:
		var chat: SampleChatStream = ref.get_ref()
		if chat != null:
			chat.close()
	return SampleSource.success(null, 204)


## Starts a new session in `mode`, after the last one ended: empty, idle,
## and numbered from 1, as the hub creates one.
func start_new(mode: String) -> void:
	var now := SampleSource.timestamp()
	session = {
		"id": "acps_sample_%d" % (_ended_ids.size() + 1), "stationId": session["stationId"],
		"userId": session["userId"], "mode": mode if mode in MODES else "ask", "status": "starting",
		"endedReason": null, "createdAt": now, "lastEventAt": now, "title": null, "lastSeq": 0,
	}
	events = []
	_waiting_request = {}
	_record("state", {"status": "idle"})


func _find_waiting_request(recorded: Array) -> Dictionary:
	var waiting := {}
	for event in recorded:
		if event["type"] == "permission-request" and not event["payload"].get("auto", false):
			waiting = event
		elif event["type"] == "permission-answer" and not waiting.is_empty() \
				and event["payload"]["requestSeq"] == waiting["seq"]:
			waiting = {}
	return waiting


## Records a new event in the session and sends it to every open chat, as
## the hub persists and fans one out.
func _record(type: String, payload: Dictionary) -> void:
	var now := SampleSource.timestamp()
	var seq: int = session["lastSeq"] + 1
	var event := {"sessionId": session["id"], "seq": seq, "type": type, "payload": payload, "createdAt": now}
	session["lastSeq"] = seq
	session["lastEventAt"] = now
	if type == "state":
		session["status"] = payload["status"]
	events.append(event)
	for ref in _chats:
		var chat: SampleChatStream = ref.get_ref()
		if chat != null and chat.state == "open":
			chat.event.emit(event.duplicate(true))


## An error for one chat only, outside the transcript: seq 0, never
## recorded, as the hub answers a message it refuses.
func _refuse(chat: SampleChatStream, message: String) -> void:
	if chat.state != "open":
		return
	chat.event.emit({
		"sessionId": session["id"], "seq": 0, "type": "error", "payload": {"message": message},
		"createdAt": SampleSource.timestamp(),
	})


## Plays the agent's recorded steps from `index`, unless the turn they
## belong to has been cancelled.
func _play_turn(steps: Array, index: int, turn: int) -> void:
	if index >= steps.size():
		return
	var step: Dictionary = steps[index]
	SampleSource.schedule(speed, minf(step["after"], SampleSource.MAX_GAP), func() -> void:
		if turn != _turn:
			return
		_record(step["type"], step["payload"].duplicate(true))
		_play_turn(steps, index + 1, turn))
