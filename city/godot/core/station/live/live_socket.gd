## One WebSocket connection of a live stream: the terminal's, the chat's
## session or a board's push channel. It asks the credential for a token
## before each attempt (a fresh one when asked), connects, polls every
## frame, and hands each JSON text frame to its stream. When the connection
## ends it says how, and its stream decides what that means; `retry_later`
## then tries again after the backoff: 1, 2, 4, 8 and 16 seconds, then
## every 30, until the stream stops it.
##
## The hub takes a WebSocket's token as `?token=` (a handshake has no other
## way to carry one) and Superpipeline only as `Authorization: Bearer`, set
## in `handshake_headers`. No Origin header is sent: the hub refuses a
## browser's that it does not know, and a program's is never needed.
##
## A link can go quiet without closing (a half-open connection): each
## socket pings every `LiveSource.heartbeat_s` and counts a ping still
## unanswered at the next as the link lost, and a handshake unfinished
## after CONNECT_DEADLINE_S, on `LiveSource.clock`, is given up.
##
## Nothing here is logged: the URL carries the token. Godot logs a URL it
## cannot parse whole, so every URL is checked first with `parses`, the
## same rules as Godot's own parser.
class_name LiveSocket
extends RefCounted

## The handshake finished: the connection is up.
signal opened()
## A text frame arrived, parsed. A frame that is not a JSON object is
## dropped.
signal message(value: Dictionary)
## The connection ended or never opened: its close `code` and `reason` as
## the other end sent them (-1 and "" when it sent none: the connection
## dropped, could not be made, or its handshake was refused, as the hub
## refuses a token with HTTP 401 before the upgrade; HANDSHAKE_TIMED_OUT
## when the handshake had no answer by CONNECT_DEADLINE_S), and whether
## it had opened.
signal lost(code: int, reason: String, was_open: bool)
## No attempt could be made: no token (`signed_out`, `offline` or
## `failed`, as the credential says), or no address (`no_address`).
signal refused(kind: String)

## The waits between attempts, in seconds; after the last, BACKOFF_CEILING_S.
const BACKOFF_S: Array[float] = [1.0, 2.0, 4.0, 8.0, 16.0]
const BACKOFF_CEILING_S := 30.0
## A connection that lasted this long counts as having worked: the next
## loss waits the shortest time again.
const STABLE_S := 10.0
## How long a handshake may take.
const CONNECT_DEADLINE_S := 10.0
## `lost`'s code for a handshake unanswered by its deadline: a link gone
## quiet, not a refusal, which a close code of -1 before opening may be.
const HANDSHAKE_TIMED_OUT := -2

var _source: LiveSource
## "hub" or "superpipeline": whose address, and how the token goes.
var _product: String
## The socket's path, from the product's address.
var _target: String
var _peer: WebSocketPeer
var _was_open := false
var _began_msec := 0
var _opened_msec := 0
## Attempts since the stream last said the connection worked.
var _attempt := 0
var _stopped := false
var _polling := false
## Bumped by every attempt and by `stop`, so a token or a timer that
## answers for an older attempt changes nothing.
var _generation := 0


func _init(source: LiveSource, product: String, target: String) -> void:
	_source = source
	_product = product
	_target = target


## How long attempt `attempt` (0 for the first retry) waits, in seconds.
static func backoff_s(attempt: int) -> float:
	return BACKOFF_S[attempt] if attempt < BACKOFF_S.size() else BACKOFF_CEILING_S


## Whether Godot's URL parser (`String::parse_url`, which
## `WebSocketPeer.connect_to_url` runs, logging the whole URL when it
## fails) takes `url`: a host, and a port from 1 to 65535 if any. Its
## rules, step for step, since GDScript cannot call it.
static func parses(url: String) -> bool:
	var rest := url
	var at := rest.find("://")
	if at != -1:
		var scheme_ok := true
		for i in at:
			var c := rest.unicode_at(i)
			if not (is_ascii_alphanumeric(c) or c in [0x2B, 0x2D, 0x2E]):
				scheme_ok = false
				break
		if scheme_ok:
			rest = rest.substr(at + 3)
	for mark in ["#", "/"]:
		at = rest.find(mark)
		if at != -1:
			rest = rest.substr(0, at)
	at = rest.find("@")
	if at != -1:
		rest = rest.substr(at + 1)
	var host := ""
	if rest.begins_with("["):
		at = rest.rfind("]")
		if at == -1:
			return false
		host = rest.substr(1, at - 1)
		rest = rest.substr(at + 1)
	else:
		if rest.get_slice_count(":") > 2:
			return false
		at = rest.rfind(":")
		host = rest if at == -1 else rest.substr(0, at)
		rest = "" if at == -1 else rest.substr(at)
	if host.is_empty():
		return false
	if rest.begins_with(":"):
		var port := rest.substr(1)
		if not port.is_valid_int() or port.to_int() < 1 or port.to_int() > 65535:
			return false
	return true


static func is_ascii_alphanumeric(c: int) -> bool:
	return (c >= 0x30 and c <= 0x39) or (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A)


## Whether a loss is a connection that never opened for want of an answer
## to read: a handshake refused (the hub refuses a token with HTTP 401
## before the upgrade, which Godot logs and does not pass on) or a
## connection that could not be made. Its stream exchanges its token again
## and asks over REST why (see LiveTerminal, LiveChat, LiveBoard).
static func never_opened(code: int, was_open: bool) -> bool:
	return not was_open and code == -1


## `http(s)://` as `ws(s)://`.
static func websocket_url(base: String) -> String:
	if base.begins_with("https://"):
		return "wss://" + base.substr(8)
	return "ws://" + base.trim_prefix("http://")


## Connects now, dropping any connection held without a word. `fresh`
## exchanges the credential again first, as after a refusal.
func connect_now(fresh := false) -> void:
	if _stopped:
		return
	_drop_peer()
	_generation += 1
	var generation := _generation
	var base := _source._base(_product)
	if base == "" or not parses(websocket_url(base) + _target):
		refused.emit("no_address")
		return
	_source.credential.request_token(_on_token.bind(generation), fresh)


## Tries again after the backoff, and returns the wait in seconds. The
## token is asked for again then, so it is fresh.
func retry_later() -> float:
	if _stopped:
		return 0.0
	_drop_peer()
	_generation += 1
	var wait := backoff_s(_attempt)
	_attempt += 1
	_source.wait.call(wait, _on_waited.bind(_generation))
	return wait


## The connection worked (the stream heard what proves it): the next loss
## waits the shortest time again.
func reset_backoff() -> void:
	_attempt = 0


## Sends `value` as a JSON text frame, strict JSON (see
## `LiveSource.strict_json`); false when there is no connection.
func send(value: Dictionary) -> bool:
	return send_text(LiveSource.strict_json(value))


## Sends `text` as a text frame; false when there is no connection.
func send_text(text: String) -> bool:
	if _peer == null or _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	return _peer.send_text(text) == OK


func is_open() -> bool:
	return _peer != null and _peer.get_ready_state() == WebSocketPeer.STATE_OPEN


## Stops for good: closes the connection (1000) and never tries again.
func stop() -> void:
	_stopped = true
	_generation += 1
	_drop_peer()


func _on_waited(generation: int) -> void:
	if generation == _generation:
		connect_now()


func _on_token(token: String, error: String, generation: int) -> void:
	if generation != _generation or _stopped:
		return
	if error != "":
		refused.emit(error)
		return
	var base := _source._base(_product)
	var url := websocket_url(base) + _target
	if base == "" or not parses(url):
		refused.emit("no_address")
		return
	var peer: WebSocketPeer = StationSource.new_network_object("WebSocketPeer")
	peer.heartbeat_interval = _source.heartbeat_s
	if _product == "hub":
		url += ("&" if "?" in _target else "?") + "token=" + token.uri_encode()
	else:
		peer.handshake_headers = PackedStringArray(["Authorization: Bearer " + token])
	_peer = peer
	_was_open = false
	_began_msec = _source.clock.call()
	var tls: TLSOptions = TLSOptions.client() if url.begins_with("wss://") else null
	var where := StationHttp.split_url(base)
	StationSource.note_destination(where[1], where[2])
	if peer.connect_to_url(url, tls) != OK:
		_peer = null
		# Said on the next frame, as a dropped connection would be.
		LiveSource.later(_report_lost.bind(generation, -1, "", false))
		return
	_ensure_polling()


func _report_lost(generation: int, code: int, reason: String, was_open: bool) -> void:
	if generation == _generation and not _stopped:
		lost.emit(code, reason, was_open)


func _ensure_polling() -> void:
	if not _polling:
		_polling = true
		(Engine.get_main_loop() as SceneTree).process_frame.connect(_poll)


func _stop_polling() -> void:
	if _polling:
		_polling = false
		(Engine.get_main_loop() as SceneTree).process_frame.disconnect(_poll)


func _poll() -> void:
	var peer := _peer
	if peer == null:
		_stop_polling()
		return
	peer.poll()
	var ready := peer.get_ready_state()
	if ready == WebSocketPeer.STATE_CONNECTING and _source.clock.call() - _began_msec > int(CONNECT_DEADLINE_S * 1000.0):
		# A handshake that never finishes: given up, as a lost link.
		_peer = null
		_stop_polling()
		lost.emit(HANDSHAKE_TIMED_OUT, "", false)
		return
	if ready == WebSocketPeer.STATE_OPEN and not _was_open:
		_was_open = true
		_opened_msec = _source.clock.call()
		opened.emit()
		if _peer != peer:
			return
	# Frames that arrived before a close are still read here; the ones
	# Godot drops with the close (it clears them in the same poll) are why
	# each stream reads the close code as well.
	while peer.get_available_packet_count() > 0:
		var packet := peer.get_packet()
		if not peer.was_string_packet() or not StationSource.is_utf8(packet):
			continue
		var value = StationSource.parse_json(packet.get_string_from_utf8())
		if value is Dictionary:
			message.emit(value)
			if _peer != peer:
				return
	if ready == WebSocketPeer.STATE_CLOSED:
		var code := peer.get_close_code()
		var reason := peer.get_close_reason()
		var was_open := _was_open
		if was_open and _source.clock.call() - _opened_msec >= int(STABLE_S * 1000.0):
			_attempt = 0
		_peer = null
		_stop_polling()
		lost.emit(code, reason, was_open)


## Lets go of the connection without a word, closing it politely if it
## is open.
func _drop_peer() -> void:
	if _peer == null:
		return
	if _peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_peer.close(1000)
	_peer = null
	_stop_polling()


# While being freed a script's own methods cannot be called; the socket is
# closed directly, so a dropped stream stops at once.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _peer != null:
		_peer.close(1000)
