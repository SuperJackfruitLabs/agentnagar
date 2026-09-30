## A fake AgentPod hub and Superpipeline API for the live source's tests,
## run inside the test process: two HTTP/1.1 servers on 127.0.0.1, each on
## an ephemeral port, polled every frame. They mirror the named handlers
## of AgentPod at 9bc1997 and Superpipeline at d53992f (each route names
## the one it mirrors, as `<repo>@<sha>:<path>`), answer with the shapes
## the protocol reference records (§1 to §3 and §6 to §8), from
## `recordings/*.json`, and check what the client sends as the real ones
## would: the bearer token, its audience, its expiry, and each body. Where
## the fake and a handler differ, the handler is right.
##
## So the client cannot drift from the recordings, a route the fake does
## not know answers 404 and a body it does not know answers 400, and both
## are violations, which fail the running test through `report`.
##
## The routes themselves are in fake_hub_routes.gd and its WebSockets (the
## terminal, the console session and the board's channel, with the drift
## guard on every frame the client sends) in fake_hub_sockets.gd; this file
## is the server, the sign-in state (codes, devices, tokens), the sockets'
## state (shells, session events, board events) and the switches a test
## flips: token lifetime, stations offline, refusals, one-off answers and
## dropped connections.
extends RefCounted

const Routes := preload("res://tests/fake_hub/fake_hub_routes.gd")
const Sockets := preload("res://tests/fake_hub/fake_hub_sockets.gd")
const RECORDINGS := "res://tests/fake_hub/recordings/"
## Why the hub ends a session whose node did not come back in time.
const NODE_LOST := "Couldn't reach the node."

## Called with each violation's description; tests pass the runner's
## `fail`. Violations are kept in `violations` too.
var report := Callable()
var violations: Array[String] = []

var hub_url := ""
var superpipeline_url := ""
## The client the hub knows (`HUB_OAUTH_CLIENTS`).
var client_id := "agentnagar"
## Who the browser's session is signed in as: the account a sign-in's
## code, and its human token, belong to. A test switches it to sign in as
## someone else.
var browser_user := "usr_player"

## How long a token lives, in seconds (`expiresIn`): 300, as the hub's
## (agentpod@9bc1997:apps/hub/src/routes/devices.ts, `TOKEN_TTL` "5m"); a
## test shortens it.
var token_lifetime_s := 300
## Stations whose node is offline, by station ID.
var offline_stations := {}
## Each station's account, by station ID, where not the usual player's (see
## `owner_of_station`): the hub answers each account for its own stations
## only (`getStation(userId, …)`).
var station_owners := {}
## Refusals still to give: [{product, status, left}], oldest first.
var refusals: Array = []
## One-off answers still to give: [{product, route, status, body, left}].
var scripted: Array = []

## Every request, in order: {product, method, path, query, headers, body,
## route}, with header names in lower case and `route` the template it
## matched ("" for none).
var requests: Array = []
## How many 401s it gave for an expired or unknown token.
var unauthorized := 0

## The recordings, and the state the routes change.
var agentpod: Dictionary
var superpipeline: Dictionary
## Authorization codes: code -> {challenge, redirect_uri, used}.
var codes := {}
## Devices: id -> {secret, name, revoked, revokedAt, owner}.
var devices := {}
## Tokens: token -> {kind ("sign_in" or "device"), expires_msec, device}.
var tokens := {}
## Console sessions: AcpSessionRow dictionaries, newest first.
var sessions: Array = []
## Set, a station keeps one open session, as a node that cannot key an
## agent process per session does: a second POST is refused with 409. Off,
## as a current hub, every POST makes a new session.
var single_session := false
## How long a session whose node dropped waits at `waiting` before the hub
## gives up on it (`offlineGraceMs`, 60 s); a test shortens it. And the
## sessions waiting so: session ID -> {since (msec), turn (one was under
## way)}.
var offline_grace_s := 60.0
var parked := {}
## Each session's events, `AcpEvent`s in `seq` order, by session ID.
var session_events := {}
## How many events before `sinceSeq` a replay sends again (0, as the hub
## does); a test raises it to check the client drops what it has seen.
var replay_overlap := 0
## The shells, which outlive their sockets: station ID -> {size: [cols,
## rows], input: everything typed, a NUL as NUL_MARK}.
var shells := {}
## How many terminal sockets attached a shell.
var terminal_attaches := 0
## Every `sinceSeq` the client subscribed with, in order.
var subscribes: Array = []
var cancels := 0
## Every frame a client sent on a socket: {kind, frame, text}.
var frames: Array = []
## The board's last event `seq`.
var board_seq := 0
## How many polls a terminal socket takes to attach its shell, as the hub's
## `term.open` round trip does; the hub ignores frames that arrive before.
var attach_delay_polls := 3
## Terminal frames that arrived before their shell attached, and so were
## ignored.
var dropped_before_attach := 0
## How many of a station's last log lines a tail starts with, as the
## node's follow mode does, on every opening; and whether a tail ends as
## soon as it starts, as one does when the node's tail errs.
var tail_replay_lines := 10
var tails_end_at_once := false
## Every log line pushed, by station ID.
var log_history := {}
## Set, the servers go quiet: a request or an upgrade is never answered
## and a ping never gets its pong, as over a link gone half-open.
var silent := false
## Polls so far.
var polls := 0
var _serial := 0

var _servers := {}
var _connections: Array = []
var _running := false


func _init() -> void:
	agentpod = _read("agentpod.json")
	superpipeline = _read("superpipeline.json")


## Starts both servers on ephemeral ports and polls them every frame.
func start() -> void:
	for product in ["hub", "superpipeline"]:
		var server := TCPServer.new()
		var err := server.listen(0, "127.0.0.1")
		assert(err == OK, "the fake hub listens")
		_servers[product] = server
	hub_url = "http://127.0.0.1:%d" % _servers["hub"].get_local_port()
	superpipeline_url = "http://127.0.0.1:%d" % _servers["superpipeline"].get_local_port()
	_running = true
	(Engine.get_main_loop() as SceneTree).process_frame.connect(poll)


## Stops both servers and drops every connection.
func stop() -> void:
	if not _running:
		return
	_running = false
	(Engine.get_main_loop() as SceneTree).process_frame.disconnect(poll)
	for connection in _connections:
		connection["peer"].disconnect_from_host()
	_connections.clear()
	for server in _servers.values():
		server.stop()


## Records a violation and fails the running test.
func violation(what: String) -> void:
	violations.append(what)
	if report.is_valid():
		report.call("fake hub: " + what)


## A new ID or secret, unique in this fake.
func serial(prefix: String) -> String:
	_serial += 1
	return "%s%d_%s" % [prefix, _serial, Crypto.new().generate_random_bytes(8).hex_encode()]


## Makes a token of `kind` for `device` ("" for the sign-in's), naming
## `user` (by default the device's owner, or the browser's).
func mint(kind: String, device: String, user := "") -> String:
	if user == "":
		user = str(devices[device].get("owner", "usr_player")) if devices.has(device) else browser_user
	var token := serial("tok_" + kind + "_")
	tokens[token] = {"kind": kind, "device": device, "user": user,
		"expires_msec": Time.get_ticks_msec() + token_lifetime_s * 1000}
	return token


## Refuses the next `count` authenticated requests to `product` with
## `status` (401 or 403).
func refuse(product: String, status: int, count := 1) -> void:
	refusals.append({"product": product, "status": status, "left": count})


## Answers the next `count` requests on `route` ("METHOD /template") with
## `status` and `body` (a Dictionary, an Array or a String, as JSON; a
## PackedByteArray as it is, as a broken proxy might) instead.
func answer_with(product: String, route: String, status: int, body: Variant, count := 1) -> void:
	scripted.append({"product": product, "route": route, "status": status, "body": body, "left": count})


## Adds a station, a `FleetAgent` row, owned by account `owner`.
func add_station(row: Dictionary, owner: String) -> void:
	agentpod["fleet_agents"]["agents"].append(row)
	station_owners[row["stationId"]] = owner


## The account that owns station `station_id`: the recorded stations are
## the usual player's.
func owner_of_station(station_id: String) -> String:
	return str(station_owners.get(station_id, "usr_player"))


## The requests to `route`, in order.
func requests_to(route: String) -> Array:
	return requests.filter(func(r): return r["route"] == route)


## Sends a log chunk to every open tail of `station_id`, as the hub
## forwards one: a `data:` line for each of its lines, then a blank line.
func push_log(station_id: String, text: String) -> void:
	if not log_history.has(station_id):
		log_history[station_id] = []
	log_history[station_id].append_array(Array(text.split("\n")))
	for connection in _tails(station_id):
		_queue_chunk(connection, _log_event(text))


static func _log_event(text: String) -> PackedByteArray:
	var event := ""
	for piece in text.split("\n"):
		event += "data: " + piece + "\n"
	event += "\n"
	return event.to_utf8_buffer()


## Sends `bytes` as they are, one HTTP chunk, to every open tail of
## `station_id`: an event cut anywhere, to test the client's reassembly.
func push_raw(station_id: String, bytes: PackedByteArray) -> void:
	for connection in _tails(station_id):
		_queue_chunk(connection, bytes)


## Sends an SSE comment (a keep-alive) to every open tail of `station_id`.
func push_comment(station_id: String) -> void:
	for connection in _tails(station_id):
		_queue_chunk(connection, ": keep-alive\n\n".to_utf8_buffer())


## Ends every open tail of `station_id` cleanly.
func end_logs(station_id: String) -> void:
	for connection in _tails(station_id):
		connection["outbox"].append_array("0\r\n\r\n".to_ascii_buffer())
		connection["close_after"] = true
		connection["tail"] = ""


## How many tails of `station_id` are open.
func tails_open(station_id: String) -> int:
	return _tails(station_id).size()


# ---- Sockets ----

## Sends `value` as a text frame on `connection`.
func send_frame(connection: Dictionary, value: Dictionary) -> void:
	connection["outbox"].append_array(Sockets.encode(Sockets.OP_TEXT, JSON.stringify(value).to_utf8_buffer()))


## The open sockets of `kind` (terminal, chat or board; "" for all).
func sockets(kind := "") -> Array:
	return _connections.filter(func(c): return c.has("ws") and (kind == "" or c["ws"]["kind"] == kind) \
		and not c.get("close_sent", false) and not c.get("gone", false) and c["peer"].get_status() == StreamPeerTCP.STATUS_CONNECTED)


## The session with ID `id`, or {}.
func session(id: String) -> Dictionary:
	for row in sessions:
		if row["id"] == id:
			return row
	return {}


## The shell at `station_id` writes `bytes`: a `data` frame, base64, to its
## every socket.
func push_terminal(station_id: String, bytes: PackedByteArray) -> void:
	for connection in sockets("terminal"):
		if connection["ws"]["station"] == station_id:
			send_frame(connection, {"t": "data", "data": Marshalls.raw_to_base64(bytes)})


## The shell at `station_id` exits: `exit`, then the hub's bare close, in
## one piece.
func end_terminal(station_id: String) -> void:
	shells.erase(station_id)
	for connection in sockets("terminal"):
		if connection["ws"]["station"] == station_id:
			send_frame(connection, {"t": "exit"})
			Sockets.close_socket(self, connection, 1000, "")


## Persists an event of `type` in the session with the next `seq`, and
## sends it to every subscribed socket; a `state` of `ended` ends the
## session, with `bye` and a 1000 close. Returns the event.
func push_chat_event(session_id: String, type: String, payload: Dictionary) -> Dictionary:
	var events: Array = session_events.get(session_id, [])
	session_events[session_id] = events
	var acp_event := {"sessionId": session_id, "seq": events.size() + 1, "type": type, "payload": payload,
		"createdAt": "2026-09-29T09:%02d:00.000Z" % mini(events.size(), 59)}
	events.append(acp_event)
	var row := session(session_id)
	var ended: bool = type == "state" and payload.get("status") == "ended"
	if ended:
		# `finalizeEnd` clears the grace timer.
		parked.erase(session_id)
	if not row.is_empty():
		row["lastSeq"] = acp_event["seq"]
		row["lastEventAt"] = acp_event["createdAt"]
	if type == "state" and not row.is_empty():
		row["status"] = payload.get("status", row["status"])
		if ended:
			row["endedReason"] = str(payload.get("reason", "Session ended."))
	for connection in sockets("chat"):
		if connection["ws"]["session"] == session_id and connection["ws"]["subscribed"]:
			send_frame(connection, {"t": "event", "event": acp_event})
			if ended:
				send_frame(connection, {"t": "bye", "reason": row.get("endedReason", "Session ended.")})
				Sockets.close_socket(self, connection, 1000, "session ended")
	return acp_event


## A synthetic event outside the transcript (`seq` 0), as the hub answers a
## message it could not take, to every subscribed socket of the session.
func push_unsequenced_error(session_id: String, message: String) -> void:
	for connection in sockets("chat"):
		if connection["ws"]["session"] == session_id and connection["ws"]["subscribed"]:
			send_frame(connection, {"t": "event", "event": {"sessionId": session_id, "seq": 0, "type": "error",
				"payload": {"message": message}, "createdAt": "2026-09-29T09:00:00.000Z"}})


## Takes the station's node offline, or brings it back. Going offline is
## the hub's `dropNode` (agentpod@9bc1997:apps/hub/src/services/broker.ts):
## every attached shell's stream is ended
## as if the shell had, so its sockets get `exit` and a bare close (1000),
## the same as a real exit. An attach while offline gets `exit` and 1011.
## Each open console session's wire ends too, which parks it (see `_park`);
## its sockets stay open. Coming back reattaches nothing.
func set_station_offline(station_id: String, offline: bool) -> void:
	if not offline:
		offline_stations.erase(station_id)
		return
	offline_stations[station_id] = true
	for connection in sockets("terminal"):
		if connection["ws"]["station"] == station_id:
			send_frame(connection, {"t": "exit"})
			Sockets.close_socket(self, connection, 1000, "")
	for row in sessions.duplicate():
		if row["stationId"] == station_id and row["status"] != "ended" and not parked.has(row["id"]):
			_park(row)


## A session whose node dropped, as `handleWireClosed` parks one on the
## wire's end (agentpod@9bc1997:apps/hub/src/services/acp-sessions.ts):
## each permission request still waiting is answered as cancelled
## (`rejectPendingPermissions`), then the state is `waiting` with reason
## "node offline". Its sockets stay open. `_end_parked` ends it once the
## grace has run out.
func _park(row: Dictionary) -> void:
	var id: String = row["id"]
	var turn: bool = row["status"] in ["working", "waiting"]
	for request_seq in _waiting_requests(id):
		push_chat_event(id, "permission-answer", {"requestSeq": request_seq, "cancelled": true})
	push_chat_event(id, "state", {"status": "waiting", "reason": "node offline"})
	parked[id] = {"since": Time.get_ticks_msec(), "turn": turn}


## The permission requests of session `id` that wait for an answer: asked
## (not answered by the mode itself) and not yet answered.
func _waiting_requests(id: String) -> Array:
	var asked := []
	for acp_event in session_events.get(id, []):
		if acp_event["type"] == "permission-request" and not acp_event["payload"].get("auto", false):
			asked.append(acp_event["seq"])
		elif acp_event["type"] == "permission-answer":
			asked.erase(acp_event["payload"].get("requestSeq"))
	return asked


## Ends each parked session whose grace has run out, as `finalizeEnd`
## does: the turn under way fails for want of the node (an `error` event,
## `turnErrorFromReason`), then the state is `ended` with its reason, which
## says `bye` and closes the session's sockets (1000).
func _end_parked() -> void:
	for id in parked.keys():
		if Time.get_ticks_msec() - int(parked[id]["since"]) < int(offline_grace_s * 1000.0):
			continue
		if parked[id]["turn"]:
			push_chat_event(id, "error", {"message": NODE_LOST, "kind": "node_offline", "harness": "claude-code",
				"source": "session-state", "retryable": true})
		push_chat_event(id, "state", {"status": "ended", "reason": NODE_LOST})


## Closes every socket of `kind` with `code` and `reason`.
func close_sockets(kind: String, code: int, reason: String) -> void:
	for connection in sockets(kind):
		Sockets.close_socket(self, connection, code, reason)


## Drops every socket of `kind` ("" for all) with no close frame, as a lost
## network does.
func drop_sockets(kind := "") -> void:
	for connection in sockets(kind):
		connection["peer"].disconnect_from_host()
		_connections.erase(connection)


## A board event of `type`, `{kind:"event", event:{seq, type, payload, ts}}`,
## to every board socket; `ts` is an ISO string (errata). Returns it.
func push_board_event(type: String, payload: Dictionary) -> Dictionary:
	board_seq += 1
	var change := {"seq": board_seq, "type": type, "payload": payload, "ts": "2026-09-29T09:30:%02d.000Z" % (board_seq % 60)}
	for connection in sockets("board"):
		send_frame(connection, {"kind": "event", "event": change})
	return change


## Ends every token's life now, as their five minutes would.
func expire_tokens() -> void:
	for token in tokens:
		tokens[token]["expires_msec"] = 0


func _tails(station_id: String) -> Array:
	return _connections.filter(func(c): return c["tail"] == station_id and c["peer"].get_status() == StreamPeerTCP.STATUS_CONNECTED)


# ---- The server ----

func poll() -> void:
	polls += 1
	_end_parked()
	for product in _servers:
		var server: TCPServer = _servers[product]
		while server.is_connection_available():
			_connections.append({"product": product, "peer": server.take_connection(),
				"inbox": PackedByteArray(), "outbox": PackedByteArray(), "handled": false,
				"close_after": false, "tail": ""})
	for connection in _connections.duplicate():
		_poll_connection(connection)


func _poll_connection(connection: Dictionary) -> void:
	var peer: StreamPeerTCP = connection["peer"]
	peer.poll()
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_connections.erase(connection)
		return
	var available := peer.get_available_bytes()
	if available > 0:
		var got: Array = peer.get_partial_data(available)
		if got[0] == OK:
			connection["inbox"].append_array(got[1])
	if silent:
		# Read and never answered: the client's handshake waits, and its
		# pings pile up unanswered.
		pass
	elif not connection["handled"]:
		var request := _parse(connection["inbox"])
		if not request.is_empty():
			connection["handled"] = true
			request["product"] = connection["product"]
			if Sockets.is_upgrade(request):
				Sockets.upgrade(self, connection, request)
			else:
				Routes.handle(self, connection, request)
	if connection.has("ws") and not silent:
		Sockets.read(self, connection)
	var outbox: PackedByteArray = connection["outbox"]
	if not outbox.is_empty():
		var sent: Array = peer.put_partial_data(outbox)
		if sent[0] == OK:
			connection["outbox"] = outbox.slice(sent[1])
	if connection["close_after"] and connection["outbox"].is_empty():
		peer.disconnect_from_host()
		_connections.erase(connection)


## A whole request from `inbox`, or {} until one has arrived: {method,
## target, path, query, headers, body}.
func _parse(inbox: PackedByteArray) -> Dictionary:
	var head_end := -1
	for i in range(0, inbox.size() - 3):
		if inbox[i] == 13 and inbox[i + 1] == 10 and inbox[i + 2] == 13 and inbox[i + 3] == 10:
			head_end = i
			break
	if head_end < 0:
		return {}
	var lines := inbox.slice(0, head_end).get_string_from_utf8().split("\r\n")
	var first := lines[0].split(" ")
	var headers := {}
	for i in range(1, lines.size()):
		var colon := lines[i].find(":")
		if colon > 0:
			headers[lines[i].substr(0, colon).strip_edges().to_lower()] = lines[i].substr(colon + 1).strip_edges()
	var length := int(headers.get("content-length", "0"))
	if inbox.size() < head_end + 4 + length:
		return {}
	var target: String = first[1] if first.size() > 1 else "/"
	var query := {}
	if "?" in target:
		for pair in target.get_slice("?", 1).split("&", false):
			query[pair.get_slice("=", 0).uri_decode()] = pair.substr(pair.find("=") + 1).uri_decode() if "=" in pair else ""
	return {"method": first[0], "target": target, "path": target.get_slice("?", 0), "query": query,
		"headers": headers, "body": inbox.slice(head_end + 4, head_end + 4 + length)}


const REASONS := {200: "OK", 201: "Created", 204: "No Content", 302: "Found", 400: "Bad Request",
	401: "Unauthorized", 403: "Forbidden", 404: "Not Found", 409: "Conflict", 426: "Upgrade Required",
	500: "Internal Server Error", 502: "Bad Gateway"}


## Answers `connection` and closes it once sent.
func respond(connection: Dictionary, status: int, body: PackedByteArray, headers := {}) -> void:
	var head := "HTTP/1.1 %d %s\r\n" % [status, REASONS.get(status, "Status")]
	for name in headers:
		head += "%s: %s\r\n" % [name, headers[name]]
	head += "Content-Length: %d\r\nConnection: close\r\n\r\n" % body.size()
	connection["outbox"].append_array(head.to_ascii_buffer())
	connection["outbox"].append_array(body)
	connection["close_after"] = true


## Answers with a JSON body (a Dictionary or Array), or a bare string as a
## JSON-less body.
func respond_json(connection: Dictionary, status: int, value: Variant) -> void:
	if status == 204:
		respond(connection, 204, PackedByteArray())
		return
	var text: String = value if value is String else JSON.stringify(value)
	respond(connection, status, text.to_utf8_buffer(), {"Content-Type": "application/json"})


## Opens a Server-Sent Events stream on `connection`, for `station_id`'s
## tail: chunked, and kept open.
## The tail starts with the station's last `tail_replay_lines` lines, as the
## node's follow mode does.
func open_tail(connection: Dictionary, station_id: String) -> void:
	var head := "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nTransfer-Encoding: chunked\r\n\r\n"
	connection["outbox"].append_array(head.to_ascii_buffer())
	connection["tail"] = station_id
	var history: Array = log_history.get(station_id, [])
	var last := history.slice(maxi(0, history.size() - tail_replay_lines))
	if not last.is_empty():
		_queue_chunk(connection, _log_event("\n".join(PackedStringArray(last))))
	if tails_end_at_once:
		connection["outbox"].append_array("0\r\n\r\n".to_ascii_buffer())
		connection["close_after"] = true
		connection["tail"] = ""


func _queue_chunk(connection: Dictionary, bytes: PackedByteArray) -> void:
	connection["outbox"].append_array(("%x\r\n" % bytes.size()).to_ascii_buffer())
	connection["outbox"].append_array(bytes)
	connection["outbox"].append_array("\r\n".to_ascii_buffer())


func _read(name: String) -> Dictionary:
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(RECORDINGS + name))
	return StationSource._whole_numbers_as_ints(json.data)

