## The station's shell over AgentPod's terminal WebSocket (protocol
## reference §4): `{t:"input"}` and `{t:"resize"}` out, `{t:"data"}` (base64
## output) and `{t:"exit"}` in. The shell outlives its socket, so a
## reconnection resumes it.
##
## The hub upgrades first and attaches the shell after (`term.open`, then
## `term.attach`), ignoring every frame that arrives before. It says
## nothing when it has attached, so a connection counts as attached at the
## shell's first output, or once ATTACH_GRACE_S has passed without a close.
## Until then keystrokes are held, and sent in order once attached (up to
## MAX_HELD_BYTES; past it they are refused and `unsent` says so); the
## size last asked for is sent as the socket opens (the hub opens every
## shell at 80×24) and again on attaching. The stream is `open` only once
## attached, so it never shows open for a moment before a refusal.
##
## Keystrokes sent with no connection (offline, or reconnecting) are
## refused, with `unsent`, never held for later: replayed minutes on into a
## shell, they could do harm. Only a connection's wait for its shell holds
## them.
##
## How a connection ends says what happened, because Godot drops the frames
## that arrive with a close, and the hub sends `exit` before every close:
## - never opened (`LiveSocket.never_opened`): the hub refuses a token with
##   HTTP 401 before the upgrade (its `authMiddleware`), which a socket
##   cannot read. So the token is exchanged again and it retries at once;
##   failing again, the station's health is asked, as `LiveBoard` asks its
##   board: `signed_out` (the credential refused), `no_access` or
##   `not_found` fail the stream, and anything else is `offline` and a
##   reconnection after the backoff;
## - 1000 or no code: the shell's stream ended, which is what the hub says
##   for a real exit and for a node that dropped (`dropNode` ends every
##   attached stream alike). So the station's health is asked: its node
##   offline is `offline` and a reconnection after the backoff; a refusal
##   says why (`no_access`, or `not_found` for a station that is gone);
##   anything else, the shell exited;
## - 1008: the route refused (a capability, the control pair), so the
##   token is exchanged again and it retries once; a second is
##   `no_access`. (The route's 1008 "Unauthorized" is for an anonymous
##   caller, whom the middleware has already answered 401.)
## - 1011, the hub's server error (the node offline, `term.open` failed,
##   the station not found): the station's health is asked, as after a
##   clean close, but a station that is well is a reconnection after the
##   backoff, not an exit; a station gone fails as `not_found`, so it never
##   reconnects to nothing;
## - the connection lost: `offline`, and it reconnects after the backoff.
extends StationStream.Terminal

const ROUTE := "WS /api/stations/:id/terminal"
const HEALTH_ROUTE := "GET /api/stations/:id/health"
## How long after the handshake a quiet shell counts as attached.
const ATTACH_GRACE_S := 1.0
## The most keystrokes held for a shell not yet attached, in bytes of
## frames; past it, new ones are refused.
const MAX_HELD_BYTES := 1 << 20

## Standard base64 with its padding, as the hub writes a shell's output.
## Godot's decoder logs an error for anything else, so a malformed frame
## is checked first and dropped quietly.
static var _base64: RegEx

var _source: LiveSource
var _station_id: String
var _socket: LiveSocket
## The size last asked for (0 until the app asks), and the one this
## connection has been sent.
var _cols := 0
var _rows := 0
var _sent := Vector2i.ZERO
## Whether this connection's shell has attached.
var _attached := false
## Input frames held until the shell attaches, in order.
var _held: Array[String] = []
var _held_bytes := 0
## The most held; MAX_HELD_BYTES but in tests.
var max_held_bytes := MAX_HELD_BYTES
## Set when this run of failed connections has retried with a fresh token
## (after a 1008, or a handshake refused before the upgrade), and when it
## has asked the station's health why one never opened; both start over
## once a shell attaches.
var _refusal_retried := false
var _asked_why := false
## Counts connections, so a grace timer knows its own.
var _connection := 0


func _init(source: LiveSource, station_id: String) -> void:
	_source = source
	_station_id = station_id
	_socket = LiveSocket.new(source, "hub", source._station(station_id, "/terminal"))
	_socket.opened.connect(_on_opened)
	_socket.message.connect(_on_message)
	_socket.lost.connect(_on_lost)
	_socket.refused.connect(_on_refused)
	LiveSource.later(_socket.connect_now)


func close() -> void:
	_socket.stop()
	_held.clear()
	_held_bytes = 0
	_set_state("closed")


func send_input(text: String) -> void:
	_send_input_frame(LiveSource.strict_json({"t": "input", "data": text}))


## A NUL cannot live in a Godot String, so the frame is written by hand:
## each piece between NULs is written as strict JSON, and each NUL as
## `\u0000`. Bytes that are not UTF-8 cannot be sent as the text the frame
## carries, and are refused, with `unsent`, like any refusal.
func send_bytes(bytes: PackedByteArray) -> bool:
	var pieces: Array[String] = []
	var start := 0
	while start <= bytes.size():
		var nul := bytes.find(0, start)
		var end := nul if nul >= 0 else bytes.size()
		var piece := bytes.slice(start, end)
		if not piece.is_empty() and not StationSource.is_utf8(piece):
			unsent.emit()
			return false
		pieces.append(LiveSource.strict_json(piece.get_string_from_utf8()).trim_prefix("\"").trim_suffix("\""))
		if nul < 0:
			break
		start = nul + 1
	return _send_input_frame("{\"t\":\"input\",\"data\":\"" + "\\u0000".join(pieces) + "\"}")


func send_resize(cols: int, rows: int) -> void:
	_cols = cols
	_rows = rows
	_send_size()


## Sends an input frame; holds it while this connection waits for its
## shell (the hub would drop it); else refuses it, with `unsent`. Returns
## whether it was sent or held.
func _send_input_frame(frame: String) -> bool:
	if state != "closed" and _attached and _socket.send_text(frame):
		return true
	if state != "closed" and not _attached and _socket.is_open() \
			and _held_bytes + frame.length() <= max_held_bytes:
		_held.append(frame)
		_held_bytes += frame.length()
		return true
	unsent.emit()
	return false


func _send_size() -> void:
	if _cols <= 0 or _rows <= 0 or _sent == Vector2i(_cols, _rows):
		return
	if _socket.send({"t": "resize", "cols": _cols, "rows": _rows}):
		_sent = Vector2i(_cols, _rows)


func _on_opened() -> void:
	_sent = Vector2i.ZERO
	_attached = false
	_connection += 1
	_send_size()
	(Engine.get_main_loop() as SceneTree).create_timer(ATTACH_GRACE_S).timeout.connect(_on_grace.bind(_connection))


## The connection lasted its grace without a word: the shell has attached.
func _on_grace(connection: int) -> void:
	if connection == _connection and not _attached and state != "closed" and _socket.is_open():
		_attach()


## The shell is attached: the size again (one sent before may have been
## dropped), then what was held, in order.
func _attach() -> void:
	_attached = true
	_refusal_retried = false
	_asked_why = false
	_sent = Vector2i.ZERO
	_send_size()
	while not _held.is_empty() and _socket.send_text(_held[0]):
		_held_bytes -= _held[0].length()
		_held.remove_at(0)
	_drop_held()
	_set_state("open")


## Lets go of held keystrokes that can no longer go in order, saying so.
func _drop_held() -> void:
	if _held.is_empty():
		return
	_held.clear()
	_held_bytes = 0
	unsent.emit()


func _on_message(frame: Dictionary) -> void:
	if state == "closed" or frame.get("t") != "data" or not frame.get("data") is String or not is_base64(frame["data"]):
		return
	_socket.reset_backoff()
	if not _attached:
		_attach()
	var bytes := Marshalls.base64_to_raw(frame["data"])
	if not bytes.is_empty():
		data.emit(bytes)


## Whether `text` is standard, padded base64, which Godot decodes without
## a word.
static func is_base64(text: String) -> bool:
	if _base64 == null:
		_base64 = RegEx.create_from_string("\\A(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?\\z")
	return _base64.search(text) != null


func _on_lost(code: int, _reason: String, was_open: bool) -> void:
	if state == "closed":
		return
	_attached = false
	# Held only for this connection's shell: never replayed into the next.
	_drop_held()
	if LiveSocket.never_opened(code, was_open):
		_never_opened()
		return
	match code:
		1000, 1005:
			_ask_health(_exited)
		1011:
			_refusal_retried = false
			_ask_health(_reconnect_later)
		1008:
			if not _refusal_retried:
				_refusal_retried = true
				if state == "open":
					_set_state("offline")
				_socket.connect_now(true)
				return
			_fail("no_access", code)
		_:
			_refusal_retried = false
			_reconnect_later()


## The connection never opened: a fresh token at once, then (failing
## again) the station's health, which says why; then the backoff.
func _never_opened() -> void:
	if not _refusal_retried:
		_refusal_retried = true
		_socket.connect_now(true)
		return
	if _asked_why:
		_reconnect_later()
		return
	_asked_why = true
	_ask_health(_reconnect_later)


## Asks the station's health what a connection's end meant: its node
## offline is a reconnection after the backoff, a refusal says why and
## fails the stream, and a station that is well calls `if_well`.
func _ask_health(if_well: Callable) -> void:
	_source._request(_source._hub("GET", _source._station(_station_id, "/health"), HEALTH_ROUTE,
		LiveSource.Family.STATION_READ), _on_health.bind(_connection, if_well))


func _on_health(ok: bool, body: Variant, status: int, connection: int, if_well: Callable) -> void:
	if state == "closed" or connection != _connection:
		return
	var kind: String = str(body.get("kind", "")) if not ok and body is Dictionary else ""
	match kind:
		"offline":
			_reconnect_later()
		"signed_out":
			_fail("signed_out", 0)
		"no_access", "not_found":
			failed.emit(LiveSource.stream_error(kind, HEALTH_ROUTE, status,
				LiveSource.NO_STATION_ACCESS if kind == "no_access" else LiveSource.STATION_GONE))
			close()
		_:
			if_well.call()


## The shell's stream ended with the station well: the shell exited.
func _exited() -> void:
	exited.emit()
	close()


func _reconnect_later() -> void:
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
			# The hub could not be reached for a token: as good as offline.
			_reconnect_later()


func _fail(kind: String, code: int, line := "") -> void:
	failed.emit(LiveSource.stream_error(kind, ROUTE, code, line))
	close()
