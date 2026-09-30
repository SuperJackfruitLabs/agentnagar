## The agent's console session over AgentPod's session WebSocket (protocol
## reference §5a). Its session is found over REST first (created by
## `open_chat`, only attached to by `watch_chat`), then its socket opens at
## once: `{t:"subscribe", sinceSeq}`, answered by `session`, the replay of
## every `event` after `sinceSeq`, `replay-done`, then live events, and
## `bye` when the session ends.
##
## `sinceSeq` is the last `seq` it has passed on, so a reconnection replays
## only what it missed, and an event at or below it is never passed on
## twice. An event whose `seq` is 0 (the hub's answer to a message it could
## not take) is outside the transcript and never moves that cursor.
##
## What the player sends while the chat is not open (reconnecting, or not
## yet subscribed) is kept, and sent in order once it has subscribed again;
## past MAX_OUTBOX it is refused, and `unsent` says so.
##
## How a connection ends:
## - never opened (`LiveSocket.never_opened`): the hub refuses a token with
##   HTTP 401 before the upgrade (its `authMiddleware`), which a socket
##   cannot read. So the token is exchanged again and it retries at once;
##   failing again, the station's sessions are listed, as `LiveBoard` asks
##   its board: `signed_out` (the credential refused), `no_access` or
##   `not_found` fail the stream, and anything else is `offline` and a
##   reconnection after the backoff;
## - 1000: the session ended. The hub sends the `state: ended` event and
##   `bye` first, and Godot drops frames that arrive with a close, so the
##   session's row is read again over REST and passed on, which says
##   `ended`. When the row's `lastSeq` is the one event after the last
##   passed on, that event was the `ended` state, and it is rebuilt from
##   the row (its status and `endedReason`) and passed on too;
## - 1008: the route refused, so the token is exchanged again and it
##   retries once; a second is `not_found` for "session not found", else
##   `no_access`. (The route's 1008 "Unauthorized" is for an anonymous
##   caller, whom the middleware has already answered 401.)
## - 1011, or the connection lost: `offline`, and it reconnects after the
##   backoff.
## The state is `open` from each connection's `session` frame.
extends StationStream.Chat

const ROUTE := "WS /api/acp/sessions/:id/ws"

var station_id: String
## The session attached to, an `AcpSessionRow`; {} before.
var session_row := {}
## The last `seq` passed on: where a reconnection's replay starts.
var last_seq := 0

var _source: LiveSource
var _socket: LiveSocket
## Set when this run of failed connections has retried with a fresh token
## (after a 1008, or a handshake refused before the upgrade), and when it
## has listed the sessions to learn why one never opened; both start over
## at the next `session` frame.
var _refusal_retried := false
var _asked_why := false
## Whether the hub said the session ended (`bye`, or an `ended` row or
## state).
var _ended := false
## Frames sent while not open, in order, sent once subscribed again.
var _outbox: Array[Dictionary] = []
## The most kept; MAX_OUTBOX but in tests.
var max_outbox := MAX_OUTBOX
## The most frames kept; past it, a new one is refused.
const MAX_OUTBOX := 64


func _init(source: LiveSource, station_id_: String) -> void:
	_source = source
	station_id = station_id_


## Attaches to the session `row` and opens its socket.
func attach(row: Dictionary) -> void:
	if state == "closed":
		return
	session_row = row.duplicate(true)
	_ended = str(row.get("status", "")) == "ended"
	_socket = LiveSocket.new(_source, "hub", "/api/acp/sessions/%s/ws" % str(row.get("id", "")).uri_encode())
	_socket.opened.connect(_on_opened)
	_socket.message.connect(_on_message)
	_socket.lost.connect(_on_lost)
	_socket.refused.connect(_on_refused)
	_socket.connect_now()


## Fails the stream and closes it.
func fail(reason: Dictionary) -> void:
	if state == "closed":
		return
	failed.emit(reason)
	close()


func close() -> void:
	if _socket != null:
		_socket.stop()
	_set_state("closed")


func prompt(text: String) -> void:
	_send({"t": "prompt", "text": text})


func cancel() -> void:
	_send({"t": "cancel"})


func answer(request_seq: int, option_id: String) -> void:
	_send({"t": "permission-answer", "requestSeq": request_seq, "optionId": option_id})


func set_mode(mode: String) -> void:
	_send({"t": "set-mode", "mode": mode})


func _send(frame: Dictionary) -> void:
	if state == "closed":
		return
	if state == "open" and _outbox.is_empty() and _socket != null and _socket.send(frame):
		return
	if _outbox.size() >= max_outbox:
		unsent.emit()
		return
	_outbox.append(frame)


## Sends what was kept, in order, as far as the connection takes it.
func _flush() -> void:
	while not _outbox.is_empty() and state == "open" and _socket.send(_outbox[0]):
		_outbox.remove_at(0)


func _on_opened() -> void:
	_socket.send({"t": "subscribe", "sinceSeq": last_seq})


func _on_message(frame: Dictionary) -> void:
	if state == "closed":
		return
	match frame.get("t"):
		"session":
			if not frame.get("session") is Dictionary:
				return
			session_row = frame["session"]
			_ended = _ended or str(session_row.get("status", "")) == "ended"
			_refusal_retried = false
			_asked_why = false
			_socket.reset_backoff()
			_set_state("open")
			session.emit(session_row.duplicate(true))
			_flush()
		"event":
			var acp_event = frame.get("event")
			if not acp_event is Dictionary:
				return
			var seq := int(acp_event.get("seq", 0)) if acp_event.get("seq") is int else 0
			if seq > 0:
				if seq <= last_seq:
					return
				last_seq = seq
			var payload = acp_event.get("payload")
			if acp_event.get("type") == "state" and payload is Dictionary and payload.get("status") == "ended":
				_ended = true
			event.emit(acp_event)
		"replay-done":
			var through := int(frame.get("lastSeq", 0)) if frame.get("lastSeq") is int else 0
			replay_done.emit(through)
		"bye":
			_ended = true


func _on_lost(code: int, reason: String, was_open: bool) -> void:
	if state == "closed":
		return
	if LiveSocket.never_opened(code, was_open):
		_never_opened()
		return
	match code:
		1000:
			_session_ended()
		1008:
			if not _refusal_retried:
				_refusal_retried = true
				if state == "open":
					_set_state("offline")
				_socket.connect_now(true)
				return
			_fail("not_found" if reason == "session not found" else "no_access", code)
		_:
			_refusal_retried = false
			_retry_later()


## The connection never opened: a fresh token at once, then (failing
## again) the station's session list, which says why; then the backoff.
func _never_opened() -> void:
	if not _refusal_retried:
		_refusal_retried = true
		_socket.connect_now(true)
		return
	if _asked_why:
		_retry_later()
		return
	_asked_why = true
	_source._request(_source._hub("GET", _source._station(station_id, "/acp/sessions"),
		"GET /api/stations/:id/acp/sessions", LiveSource.Family.SESSION), func(ok: bool, body: Variant, _status: int) -> void:
			if state == "closed":
				return
			if not ok and body is Dictionary and body.get("kind") in ["signed_out", "no_access", "not_found"]:
				fail(body)
				return
			_retry_later())


func _retry_later() -> void:
	_set_state("offline")
	_socket.retry_later()


func _on_refused(kind: String) -> void:
	if state == "closed":
		return
	match kind:
		"signed_out":
			_fail("signed_out", 0)
		"no_address":
			_fail("failed", 0, LiveSource.NO_ADDRESS)
		_:
			_retry_later()


## The hub closed the socket for good: the session ended. Unless its end
## has been heard, its row is read again, so the app learns it ended even
## when Godot dropped the last frames with the close.
func _session_ended() -> void:
	if _ended:
		close()
		return
	var session_id := str(session_row.get("id", ""))
	_source._request(_source._hub("GET", _source._station(station_id, "/acp/sessions"),
		"GET /api/stations/:id/acp/sessions", LiveSource.Family.SESSION), func(ok: bool, body: Variant, _status: int) -> void:
			if state == "closed":
				return
			for row in (body if ok and body is Array else []):
				if row is Dictionary and str(row.get("id", "")) == session_id:
					_recover_end(row)
			close())


## Passes on the row read after the close, and the `ended` state event it
## implies when that was the only event lost.
func _recover_end(row: Dictionary) -> void:
	session_row = row
	var through: int = row["lastSeq"] if row.get("lastSeq") is int else 0
	if str(row.get("status", "")) == "ended" and through == last_seq + 1:
		var payload := {"status": "ended"}
		if row.get("endedReason") is String:
			payload["reason"] = row["endedReason"]
		last_seq = through
		event.emit({"sessionId": str(row.get("id", "")), "seq": through, "type": "state", "payload": payload,
			"createdAt": str(row.get("lastEventAt", ""))})
	session.emit(row.duplicate(true))


func _fail(kind: String, code: int, line := "") -> void:
	fail(LiveSource.stream_error(kind, ROUTE, code, line))
