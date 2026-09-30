## A Superpipeline board's push channel, `WS /v1/boards/:id/ws` (protocol
## reference §7): the token only in `Authorization: Bearer`, and nothing
## ever sent. Each connection opens with `{kind:"snapshot", state}`, the
## whole board, and then sends `{kind:"event", event:{seq, type, payload,
## ts}}` for each change; the state is `open` from each snapshot.
##
## Two events name a new row without carrying it: `gate.opened` gives
## `{gateId, cardId, stageKey}` and `elicitation.opened` gives
## `{elicitationId, cardId, runId, signal}` (board-do.ts). After either, the
## channel connects again for a fresh snapshot, which holds the row; the
## board has no route that reads one gate or question. It does so at most
## once every REFRESH_EVERY_S: a burst of them is one refresh at once and
## one more for the rest.
##
## Any loss reconnects after the backoff. Superpipeline refuses a bad token
## before the handshake, which a WebSocket cannot read, so when a
## connection fails before it opens the board asks `GET /v1/boards` with a
## token, which retries a 401 once with a fresh one: `signed_out` or
## `no_access` there fail the stream, and anything else keeps trying.
extends StationStream.Board

const ROUTE := "WS /v1/boards/:id/ws"
## The events whose row only a snapshot brings.
const NAME_A_NEW_ROW := ["gate.opened", "elicitation.opened"]
const REFRESH_EVERY_S := 1.0

var _source: LiveSource
var _socket: LiveSocket
## Whether the board was asked about this run of failed handshakes.
var _asked := false
## When the last refresh began (on the source's clock), and whether one
## waits for its turn.
var _refreshed_msec := -1000000
var _refresh_due := false


func _init(source: LiveSource, board_id: String) -> void:
	_source = source
	_socket = LiveSocket.new(source, "superpipeline", "/v1/boards/%s/ws" % board_id.uri_encode())
	_socket.message.connect(_on_message)
	_socket.lost.connect(_on_lost)
	_socket.refused.connect(_on_refused)
	LiveSource.later(_socket.connect_now)


func close() -> void:
	_socket.stop()
	_set_state("closed")


func _on_message(frame: Dictionary) -> void:
	if state == "closed":
		return
	match frame.get("kind"):
		"snapshot":
			if not frame.get("state") is Dictionary:
				return
			_asked = false
			_socket.reset_backoff()
			_set_state("open")
			snapshot.emit(frame["state"])
		"event":
			var change = frame.get("event")
			if not change is Dictionary:
				return
			board_event.emit(change)
			if state != "closed" and change.get("type") in NAME_A_NEW_ROW:
				_refresh()


## Connects again for a fresh snapshot, or, within a second of the last
## refresh, once that second is up.
func _refresh() -> void:
	if _refresh_due:
		return
	var since: int = _source.clock.call() - _refreshed_msec
	var every := int(REFRESH_EVERY_S * 1000.0)
	if since >= every:
		_refreshed_msec = _source.clock.call()
		_socket.connect_now()
		return
	_refresh_due = true
	(Engine.get_main_loop() as SceneTree).create_timer((every - since) / 1000.0).timeout.connect(_on_refresh_due)


func _on_refresh_due() -> void:
	_refresh_due = false
	if state != "closed":
		_refresh()


func _on_lost(_code: int, _reason: String, was_open: bool) -> void:
	if state == "closed":
		return
	if was_open or _asked:
		_retry()
		return
	_asked = true
	_source._request(_source._superpipeline("GET", "/v1/boards", "GET /v1/boards"),
		func(ok: bool, body: Variant, _status: int) -> void:
			if state == "closed":
				return
			if not ok and body is Dictionary and body.get("kind") in ["signed_out", "no_access"]:
				failed.emit(LiveSource.stream_error(body["kind"], ROUTE, 0))
				close()
				return
			_retry())


func _on_refused(kind: String) -> void:
	if state == "closed":
		return
	match kind:
		"signed_out":
			failed.emit(LiveSource.stream_error("signed_out", ROUTE, 0))
			close()
		"no_address":
			failed.emit(LiveSource.stream_error("failed", ROUTE, 0, LiveSource.NO_ADDRESS))
			close()
		_:
			_retry()


func _retry() -> void:
	_set_state("offline")
	_socket.retry_later()
