## The fake hub's WebSockets: AgentPod's terminal (§4) and console session
## (§5a) sockets, and Superpipeline's board channel (§7). It does the RFC
## 6455 server side by hand (the handshake, reading masked frames, writing
## plain ones), because the routes must read the upgrade's path, query and
## headers, which `WebSocketPeer.accept_stream` keeps to itself.
##
## The drift guard: every frame the client sends is checked against the
## frames recorded in `recordings/*.json` (their `t`, their keys and each
## value's type), and anything else is a violation, which fails the running
## test. The board takes no frames at all. A raw control character in a
## frame is a violation too: the hub's JSON.parse refuses one.
##
## Refusing and closing follow the hub. A token it does not take is
## answered HTTP 401 before any upgrade: `authMiddleware` runs on `/api/*`
## ahead of the socket routes (agentpod@9bc1997:apps/hub/src/index.ts,
## apps/hub/src/auth/middleware.ts). Past it, a route's own refusal
## upgrades and then closes (1008), a missing node or station closes 1011
## after `{t:"exit"}`, and the frames before a close are written with it,
## in one piece, as a real server's usually arrive.
extends RefCounted

## Its sockets: [method, template, kind], per product.
const ROUTES := {
	"hub": [
		["GET", "/api/stations/:id/terminal", "terminal"],
		["GET", "/api/acp/sessions/:id/ws", "chat"],
	],
	"superpipeline": [
		["GET", "/v1/boards/:id/ws", "board"],
	],
}
const GUID := "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
## What an unknown board's Durable Object holds: `snapshot()` with no
## `boardId` (superpipeline@d53992f:apps/api/src/board/board-do.ts).
const EMPTY_BOARD := {"boardId": null, "tenantId": null, "name": null, "stages": [], "cards": [], "gates": [],
	"elicitations": [], "references": [], "usage": {"totalCostUsd": 0, "estimatedCostUsd": 0, "budgetUsd": null,
	"cardUsdCap": null, "overBudget": false}, "github": {"issueTrigger": false, "webhookConfigured": false,
	"triggerGrantCount": null}}
## What `authMiddleware` answers a token it does not take
## (agentpod@9bc1997:apps/hub/src/auth/middleware.ts).
const UNAUTHORIZED := {"error": "Unauthorized", "message": "Valid session or API key required"}
## What stands in for a NUL while a frame is parsed: Godot's JSON parser
## logs an error on `\u0000`.
const NUL_MARK := "␀"

const OP_CONTINUATION := 0
const OP_TEXT := 1
const OP_BINARY := 2
const OP_CLOSE := 8
const OP_PING := 9
const OP_PONG := 10


## Whether `request` asks for a WebSocket.
static func is_upgrade(request: Dictionary) -> bool:
	return str(request["headers"].get("upgrade", "")).to_lower() == "websocket"


## Answers an upgrade: checks it as the product would, then upgrades and
## opens the socket's route, or refuses.
static func upgrade(hub, connection: Dictionary, request: Dictionary) -> void:
	var matched := _match(request["product"], request["path"])
	request["route"] = matched.get("route", "")
	request["params"] = matched.get("params", {})
	hub.requests.append(request)
	if matched.is_empty():
		hub.violation("no %s socket at %s" % [request["product"], request["path"]])
		hub.respond_json(connection, 404, {"error": "Not Found"})
		return
	var kind: String = matched["kind"]
	var query: Dictionary = request["query"]
	var headers: Dictionary = request["headers"]
	if headers.has("origin"):
		hub.violation("an Origin header on " + request["route"])
	if kind == "board":
		# Superpipeline: the bearer header only (§6); anything in the query
		# is refused, and so is a token its audience check would.
		if not query.is_empty():
			hub.violation("a query on " + request["route"] + ": the board takes its token in the header")
		var held = _held(hub, str(headers.get("authorization", "")).trim_prefix("Bearer "))
		if _refused_now(hub, "superpipeline") or held == null or held["kind"] != "device" \
				or not str(headers.get("authorization", "")).begins_with("Bearer "):
			hub.unauthorized += 1
			hub.respond_json(connection, 401, {"error": "sign in to continue"})
			return
		# The board's Durable Object upgrades whatever it holds: a board it
		# does not know sends an empty snapshot (superpipeline@d53992f:
		# apps/api/src/index.ts, board/board-do.ts `fetch`, `snapshot`).
		var known: bool = request["params"]["id"] == hub.superpipeline["snapshot"]["boardId"]
		_accept(connection, request)
		connection["ws"] = {"kind": "board", "board": request["params"]["id"]}
		hub.send_frame(connection, {"kind": "snapshot", "state": hub.superpipeline["snapshot"] if known else EMPTY_BOARD})
		return
	# The hub: `?token=` (or the header), nothing else in the query.
	for key in query:
		if key != "token":
			hub.violation("an unknown query key %s on %s" % [key, request["route"]])
	var token: String = query.get("token", str(headers.get("authorization", "")).trim_prefix("Bearer "))
	var held = _held(hub, token)
	var refusal := _refusal(hub)
	if refusal == 401 or held == null:
		# `authMiddleware`, before the route and so before the upgrade.
		hub.unauthorized += 1
		hub.respond_json(connection, 401, UNAUTHORIZED)
		return
	_accept(connection, request)
	var user := str(held["user"])
	match kind:
		"terminal":
			var station_id: String = request["params"]["id"]
			connection["ws"] = {"kind": "terminal", "station": station_id}
			# These come after the hub's awaits (the station, the grant, the
			# node), so a poll or more after the upgrade, as `term.open`'s do
			# (agentpod@9bc1997:apps/hub/src/routes/station-terminal.ts):
			# another account's station is not found, as none is.
			if refusal == 403:
				_refuse_later(hub, connection, 1008, "Forbidden: terminal capability")
			elif not _station_known(hub, station_id, user):
				_refuse_later(hub, connection, 1011, "station not found")
			elif hub.offline_stations.has(station_id):
				_refuse_later(hub, connection, 1011, "node offline")
			else:
				hub.terminal_attaches += 1
				connection["ws"]["attach_at"] = hub.polls + hub.attach_delay_polls
				if not hub.shells.has(station_id):
					hub.shells[station_id] = {"size": [80, 24], "input": ""}
		"chat":
			# Ownership: the session must be the caller's
			# (agentpod@9bc1997:apps/hub/src/routes/station-acp.ts).
			var session_id: String = request["params"]["id"]
			connection["ws"] = {"kind": "chat", "session": session_id, "subscribed": false}
			var row: Dictionary = hub.session(session_id)
			if refusal == 403 or row.is_empty() or str(row.get("userId", "usr_player")) != user:
				close_socket(hub, connection, 1008, "session not found")


## A terminal refusal that the hub sends after its awaits: `exit`, then
## the close, `attach_delay_polls` after the upgrade.
static func _refuse_later(hub, connection: Dictionary, code: int, reason: String) -> void:
	connection["ws"]["refuse_at"] = hub.polls + hub.attach_delay_polls
	connection["ws"]["refusal"] = [code, reason]


## Reads every whole frame the client has sent, and sends a refusal whose
## time has come.
static func read(hub, connection: Dictionary) -> void:
	var socket: Dictionary = connection.get("ws", {})
	if socket.has("refuse_at") and hub.polls >= socket["refuse_at"]:
		socket.erase("refuse_at")
		hub.send_frame(connection, {"t": "exit"})
		close_socket(hub, connection, socket["refusal"][0], socket["refusal"][1])
	while connection.has("ws") and not connection.get("gone", false):
		var inbox: PackedByteArray = connection["inbox"]
		var frame := _decode(inbox)
		if frame.is_empty():
			return
		connection["inbox"] = inbox.slice(frame["size"])
		if not frame["masked"]:
			hub.violation("an unmasked client frame")
		match frame["opcode"]:
			OP_TEXT, OP_CONTINUATION:
				connection["pending"] = connection.get("pending", PackedByteArray()) + frame["payload"]
				if frame["fin"]:
					var whole: PackedByteArray = connection["pending"]
					connection["pending"] = PackedByteArray()
					_client_frame(hub, connection, whole)
			OP_BINARY:
				hub.violation("a binary frame on the %s socket" % connection["ws"]["kind"])
			OP_CLOSE:
				if not connection.get("close_sent", false):
					connection["outbox"].append_array(encode(OP_CLOSE, frame["payload"].slice(0, 2)))
				connection["close_after"] = true
				connection["gone"] = true
			OP_PING:
				connection["outbox"].append_array(encode(OP_PONG, frame["payload"]))


## Sends a close frame with `code` and `reason`; the connection ends when
## the client answers, or once it is written.
static func close_socket(_hub, connection: Dictionary, code: int, reason: String) -> void:
	if connection.get("close_sent", false):
		return
	var payload := PackedByteArray([code >> 8, code & 0xFF])
	payload.append_array(reason.to_utf8_buffer())
	connection["outbox"].append_array(encode(OP_CLOSE, payload))
	connection["close_sent"] = true
	connection["close_after"] = true


## A server frame: FIN, `opcode`, the length, and the payload unmasked.
static func encode(opcode: int, payload: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray([0x80 | opcode])
	var size := payload.size()
	if size < 126:
		out.append(size)
	elif size < 65536:
		out.append_array([126, size >> 8, size & 0xFF])
	else:
		out.append(127)
		for shift in [56, 48, 40, 32, 24, 16, 8, 0]:
			out.append((size >> shift) & 0xFF)
	out.append_array(payload)
	return out


# ---- The client's frames ----

static func _client_frame(hub, connection: Dictionary, payload: PackedByteArray) -> void:
	var socket: Dictionary = connection["ws"]
	var kind: String = socket["kind"]
	if kind == "board":
		hub.violation("the client sent on the board's push-only channel")
		return
	for byte in payload:
		if byte < 0x20:
			hub.violation("a raw control character in a %s frame, which JSON.parse refuses" % kind)
			return
	var text := payload.get_string_from_utf8()
	var escaped := json_escapes(text)
	if escaped.is_empty():
		hub.violation("a %s frame with an escape JSON has not: %s" % [kind, text.left(120)])
		return
	var frame = StationSource.parse_json(escaped[0])
	hub.frames.append({"kind": kind, "frame": frame, "text": text})
	if not _recorded(hub, kind, frame):
		hub.violation("a %s frame the recordings lack: %s" % [kind, text.left(120)])
		return
	match kind:
		"terminal":
			_terminal_frame(hub, connection, frame)
		"chat":
			_chat_frame(hub, connection, frame)


## Whether `frame` is one of the recorded client frames of `kind`: its `t`,
## exactly its keys, and each value's type.
static func _recorded(hub, kind: String, frame: Variant) -> bool:
	if not frame is Dictionary:
		return false
	var recorded: Dictionary = hub.agentpod["frames"][kind]["client"]
	var shape = recorded.get(str(frame.get("t", "")))
	if not shape is Dictionary or shape.size() != frame.size():
		return false
	for key in shape:
		if not frame.has(key) or typeof(frame[key]) != typeof(shape[key]):
			return false
	return true


static func _terminal_frame(hub, connection: Dictionary, frame: Dictionary) -> void:
	var station_id: String = connection["ws"]["station"]
	var shell: Dictionary = hub.shells.get(station_id, {})
	if shell.is_empty():
		return
	if not connection["ws"].has("attach_at") or hub.polls < connection["ws"]["attach_at"]:
		# The hub's `onMessage` returns while `attachId` is unset.
		hub.dropped_before_attach += 1
		return
	match frame["t"]:
		"input":
			var typed: String = frame["data"]
			shell["input"] += typed
			# The shell echoes what it is typed, as a line editor does.
			var echoed := typed.replace(NUL_MARK, "^@").to_utf8_buffer()
			hub.push_terminal(station_id, echoed)
		"resize":
			shell["size"] = [frame["cols"], frame["rows"]]


static func _chat_frame(hub, connection: Dictionary, frame: Dictionary) -> void:
	var session_id: String = connection["ws"]["session"]
	var row: Dictionary = hub.session(session_id)
	match frame["t"]:
		"subscribe":
			var since: int = frame["sinceSeq"]
			hub.subscribes.append(since)
			connection["ws"]["subscribed"] = true
			hub.send_frame(connection, {"t": "session", "session": row})
			var last := since
			for acp_event in hub.session_events.get(session_id, []):
				if acp_event["seq"] > since - hub.replay_overlap:
					hub.send_frame(connection, {"t": "event", "event": acp_event})
					last = maxi(last, acp_event["seq"])
			hub.send_frame(connection, {"t": "replay-done", "lastSeq": last})
			if row["status"] == "ended":
				hub.send_frame(connection, {"t": "bye", "reason": str(row.get("endedReason", "Session ended."))})
				close_socket(hub, connection, 1000, "session ended")
		"prompt":
			hub.push_chat_event(session_id, "user-prompt", {"text": frame["text"]})
		"cancel":
			hub.cancels += 1
		"permission-answer":
			hub.push_chat_event(session_id, "permission-answer",
				{"requestSeq": frame["requestSeq"], "optionId": frame["optionId"]})
		"set-mode":
			# No direct reply: the mode shows in a later session row (errata).
			row["mode"] = frame["mode"]
			for other in hub.sockets("chat"):
				if other["ws"]["session"] == session_id and other["ws"]["subscribed"]:
					hub.send_frame(other, {"t": "session", "session": row})


# ---- Helpers ----

## JSON `text` checked escape by escape, as a strict parser reads it:
## [text with each `\u0000` as NUL_MARK], or [] when it holds an escape
## JSON has not (Godot writes `\v`). An escaped backslash is one escape,
## so the text after it is read as text.
static func json_escapes(text: String) -> Array:
	var out := PackedStringArray()
	var at := 0
	for found in _escape_pattern().search_all(text):
		var escape := found.get_string(1)
		if escape.length() == 1 and not escape in ["\"", "\\", "/", "b", "f", "n", "r", "t"]:
			return []
		out.append(text.substr(at, found.get_start() - at))
		out.append(NUL_MARK if escape == "u0000" else found.get_string())
		at = found.get_end()
	out.append(text.substr(at))
	return ["".join(out)]


static var _escapes: RegEx


static func _escape_pattern() -> RegEx:
	if _escapes == null:
		_escapes = RegEx.create_from_string("\\\\(u[0-9a-fA-F]{4}|.)")
	return _escapes

## Accepts the upgrade: 101 with the key's answer.
static func _accept(connection: Dictionary, request: Dictionary) -> void:
	var key := str(request["headers"].get("sec-websocket-key", ""))
	var accept := Marshalls.raw_to_base64((key + GUID).sha1_buffer())
	var head := "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n\r\n" % accept
	connection["outbox"].append_array(head.to_ascii_buffer())
	connection["inbox"] = PackedByteArray()


## One whole frame from the front of `inbox`: {fin, opcode, masked,
## payload, size}, or {} until it has all arrived.
static func _decode(inbox: PackedByteArray) -> Dictionary:
	if inbox.size() < 2:
		return {}
	var size := inbox[1] & 0x7F
	var at := 2
	if size == 126:
		if inbox.size() < 4:
			return {}
		size = (inbox[2] << 8) | inbox[3]
		at = 4
	elif size == 127:
		if inbox.size() < 10:
			return {}
		size = 0
		for i in range(2, 10):
			size = (size << 8) | inbox[i]
		at = 10
	var masked := inbox[1] & 0x80 != 0
	var mask := PackedByteArray()
	if masked:
		if inbox.size() < at + 4:
			return {}
		mask = inbox.slice(at, at + 4)
		at += 4
	if inbox.size() < at + size:
		return {}
	var payload := inbox.slice(at, at + size)
	if masked:
		for i in payload.size():
			payload[i] = payload[i] ^ mask[i % 4]
	return {"fin": inbox[0] & 0x80 != 0, "opcode": inbox[0] & 0x0F, "masked": masked, "payload": payload,
		"size": at + size}


static func _match(product: String, path: String) -> Dictionary:
	var parts := path.split("/", false)
	for entry in ROUTES.get(product, []):
		var template: PackedStringArray = str(entry[1]).split("/", false)
		if template.size() != parts.size():
			continue
		var params := {}
		var matches := true
		for i in template.size():
			if template[i].begins_with(":"):
				params[template[i].substr(1)] = parts[i].uri_decode()
			elif template[i] != parts[i]:
				matches = false
				break
		if matches:
			return {"route": "%s %s" % [entry[0], entry[1]], "kind": entry[2], "params": params}
	return {}


## The unexpired token `token`, or null.
static func _held(hub, token: String) -> Variant:
	var held = hub.tokens.get(token)
	if held == null or Time.get_ticks_msec() >= held["expires_msec"]:
		return null
	return held


## The status of a refusal the test queued for the hub (401 or 403), used
## up; 0 for none.
static func _refusal(hub) -> int:
	for refusal in hub.refusals:
		if refusal["product"] == "hub" and refusal["left"] > 0:
			refusal["left"] -= 1
			return refusal["status"]
	return 0


static func _refused_now(hub, product: String) -> bool:
	for refusal in hub.refusals:
		if refusal["product"] == product and refusal["left"] > 0:
			refusal["left"] -= 1
			return true
	return false


## Whether `station_id` is one of account `user`'s stations.
static func _station_known(hub, station_id: String, user: String) -> bool:
	return hub.owner_of_station(station_id) == user \
		and hub.agentpod["fleet_agents"]["agents"].any(func(row): return row["stationId"] == station_id)
