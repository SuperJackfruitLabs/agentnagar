## The fake hub's routes: AgentPod's sign-in, device, fleet, station and
## console-session routes, and Superpipeline's board routes, answering as
## the protocol reference records them. `handle` matches a request to its
## route, checks its query, its bearer and its body, and answers.
extends RefCounted

const Sockets := preload("res://tests/fake_hub/fake_hub_sockets.gd")

const UNAUTHORIZED := {"error": "Unauthorized", "message": "Valid session or API key required"}
## Superpipeline's answer to a token it does not take
## (superpipeline@d53992f:apps/api/src/index.ts).
const SIGN_IN_TO_CONTINUE := {"error": "sign in to continue"}
const NOT_FOUND := {"error": "Not Found"}
const NODE_OFFLINE := {"error": "node offline"}
## What `resolveCaller` answers on the device routes to anything but a
## human token: no token, an expired one, or a device's (`amr: ["device"]`).
const DEVICE_ROUTE_REFUSED := {"error": "unauthorized"}
## The hub's cap on one file read (`FILE_READ_MAX_BYTES`).
const FILE_READ_MAX_BYTES := 8 << 20

## What each product serves: [method, template, auth], where auth is
## "none" (the route checks its own), "human" (the hub's bearer) or
## "audience" (Superpipeline's: a token exchanged with the city's client,
## whose audience names it; the sign-in's plain hub token is refused).
const ROUTES := {
	"hub": [
		["GET", "/api/auth/authorize", "none"],
		["POST", "/api/auth/token/exchange", "none"],
		["POST", "/api/auth/devices", "none"],
		["POST", "/api/auth/devices/token", "none"],
		["DELETE", "/api/auth/devices/:id", "none"],
		["GET", "/api/auth/devices", "none"],
		["GET", "/api/fleet/agents", "human"],
		["GET", "/api/stations/:id/health", "human"],
		["GET", "/api/stations/:id/files", "human"],
		["GET", "/api/stations/:id/file", "human"],
		["GET", "/api/stations/:id/logs", "human"],
		["POST", "/api/stations/:id/lifecycle", "human"],
		["POST", "/api/stations/:id/changeset/status", "human"],
		["POST", "/api/stations/:id/changeset/diff", "human"],
		["POST", "/api/stations/:id/acp/sessions", "human"],
		["GET", "/api/stations/:id/acp/sessions", "human"],
		["DELETE", "/api/acp/sessions/:id", "human"],
	],
	"superpipeline": [
		["GET", "/v1/boards", "audience"],
		["GET", "/v1/agents", "audience"],
		["GET", "/v1/boards/:id/cards/:cardId/activities", "audience"],
		["POST", "/v1/boards/:id/cards/:cardId/move", "audience"],
		["POST", "/v1/boards/:id/gates/:gateId/resolve", "audience"],
		["POST", "/v1/boards/:id/elicitations/:elicitationId/answer", "audience"],
	],
}

## The JSON body each route takes: [required keys, optional keys].
const BODIES := {
	"POST /api/auth/token/exchange": [["code", "code_verifier", "redirect_uri"], []],
	"POST /api/auth/devices": [["name"], []],
	"POST /api/stations/:id/lifecycle": [["action"], []],
	"POST /api/stations/:id/changeset/status": [[], ["base"]],
	"POST /api/stations/:id/changeset/diff": [["side"], ["path", "base", "maxBytes"]],
	"POST /api/stations/:id/acp/sessions": [["mode"], []],
	"POST /v1/boards/:id/cards/:cardId/move": [["toStageKey"], []],
	"POST /v1/boards/:id/gates/:gateId/resolve": [["decision"], ["comment"]],
	"POST /v1/boards/:id/elicitations/:elicitationId/answer": [[], ["option", "text"]],
}

## The values a body's key may take, where the protocol names them.
const VALUES := {
	"action": ["start", "stop", "restart"],
	"side": ["uncommitted", "committed"],
	"mode": ["ask", "accept-edits", "full-auto"],
	"decision": ["approve", "request_changes", "reject"],
}

## The query keys each route reads; any other is a violation.
const QUERIES := {
	"GET /api/auth/authorize": ["client", "redirect_uri", "response_type", "state", "code_challenge",
		"code_challenge_method"],
	"POST /api/auth/devices/token": ["client"],
	"GET /api/stations/:id/files": ["path"],
	"GET /api/stations/:id/file": ["path", "maxBytes"],
	"GET /api/stations/:id/acp/sessions": ["limit", "before", "beforeId"],
}


static func handle(hub, connection: Dictionary, request: Dictionary) -> void:
	var matched := _match(request["product"], request["method"], request["path"])
	var route: String = matched.get("route", "")
	request["route"] = route
	request["params"] = matched.get("params", {})
	hub.requests.append(request)
	if route == "":
		hub.violation("no %s route for %s %s" % [request["product"], request["method"], request["path"]])
		hub.respond_json(connection, 404, NOT_FOUND)
		return
	# A token in a query string is for WebSocket upgrades alone; on REST it
	# would reach logs and history.
	if request["query"].has("token"):
		hub.violation("a token in the query string of " + route)
		hub.respond_json(connection, 401, UNAUTHORIZED)
		return
	for key in request["query"]:
		if not key in QUERIES.get(route, []):
			hub.violation("an unknown query key %s on %s" % [key, route])
			hub.respond_json(connection, 400, {"error": "unknown query"})
			return
	for script in hub.scripted:
		if script["product"] == request["product"] and script["route"] == route and script["left"] > 0:
			script["left"] -= 1
			if script["body"] is PackedByteArray:
				hub.respond(connection, script["status"], script["body"], {"Content-Type": "application/json"})
			else:
				hub.respond_json(connection, script["status"], script["body"])
			return
	var auth: String = matched["auth"]
	if auth != "none":
		var refused_401: Dictionary = UNAUTHORIZED if auth == "human" else SIGN_IN_TO_CONTINUE
		for refusal in hub.refusals:
			if refusal["product"] == request["product"] and refusal["left"] > 0:
				refusal["left"] -= 1
				hub.respond_json(connection, refusal["status"], refused_401 if refusal["status"] == 401 else {"error": "Forbidden"})
				return
		var held = _bearer_token(hub, request)
		if held == null or (auth == "audience" and held["kind"] != "device"):
			hub.unauthorized += 1
			hub.respond_json(connection, 401, refused_401)
			return
		# Whose request it is: the hub answers each account for its own.
		request["user"] = str(held["user"])
	if BODIES.has(route) and not _body_ok(hub, route, request):
		hub.respond_json(connection, 400, {"error": "invalid body"})
		return
	_dispatch(hub, connection, request, route)


static func _dispatch(hub, connection: Dictionary, request: Dictionary, route: String) -> void:
	var params: Dictionary = request["params"]
	match route:
		"GET /api/auth/authorize":
			_authorize(hub, connection, request)
		"POST /api/auth/token/exchange":
			_exchange_code(hub, connection, request)
		"POST /api/auth/devices":
			_make_device(hub, connection, request)
		"POST /api/auth/devices/token":
			_device_token(hub, connection, request)
		"DELETE /api/auth/devices/:id":
			_revoke_device(hub, connection, request, params["id"])
		"GET /api/auth/devices":
			_list_devices(hub, connection, request)
		"GET /api/fleet/agents":
			hub.respond_json(connection, 200, _fleet(hub, request["user"]))
		"DELETE /api/acp/sessions/:id":
			_end_session(hub, connection, params["id"], request["user"])
		"GET /v1/boards":
			hub.respond_json(connection, 200, hub.superpipeline["boards"])
		"GET /v1/agents":
			hub.respond_json(connection, 200, hub.superpipeline["agents"])
		_:
			if route.begins_with("GET /v1/") or route.begins_with("POST /v1/"):
				_board_route(hub, connection, request, route)
			else:
				_station_route(hub, connection, request, route)


# ---- Signing in ----

## The authorize page (agentpod@9bc1997:apps/hub/src/routes/auth-authorize.ts):
## the client, a loopback redirect, S256 and a state; `response_type` is
## not read.
static func _authorize(hub, connection: Dictionary, request: Dictionary) -> void:
	var query: Dictionary = request["query"]
	var redirect: String = query.get("redirect_uri", "")
	var challenge: String = query.get("code_challenge", "")
	var state: String = query.get("state", "")
	var problems := []
	if query.get("client", "") != hub.client_id:
		problems.append("an unknown client")
	if not (redirect.begins_with("http://127.0.0.1:") and redirect.ends_with("/callback")):
		problems.append("a redirect that is not the loopback callback")
	if query.get("code_challenge_method", "") != "S256":
		problems.append("a challenge method other than S256")
	if challenge.length() != 43 or not _is_base64url(challenge):
		problems.append("a code_challenge that is not 43 base64url characters")
	if state == "" or state.length() > 256:
		problems.append("a missing or long state")
	if not problems.is_empty():
		hub.violation("authorize with " + ", ".join(problems))
		hub.respond_json(connection, 400, {"error": "invalid_request", "error_description": "refused"})
		return
	var code: String = hub.serial("code_")
	# The browser's session: whoever it is signed in as gets the code.
	hub.codes[code] = {"challenge": challenge, "redirect_uri": redirect, "used": false, "user": hub.browser_user}
	hub.respond(connection, 302, PackedByteArray(),
		{"Location": "%s?code=%s&state=%s" % [redirect, code.uri_encode(), state.uri_encode()]})


static func _exchange_code(hub, connection: Dictionary, request: Dictionary) -> void:
	if request["headers"].has("origin"):
		hub.violation("the token exchange carried an Origin header")
		hub.respond_json(connection, 403, {"error": "invalid_request", "error_description": "origin refused"})
		return
	var body: Dictionary = _json_of(request)
	var issued = hub.codes.get(body["code"])
	if issued == null or issued["used"] or issued["redirect_uri"] != body["redirect_uri"] \
			or StationCredential.challenge_for(body["code_verifier"]) != issued["challenge"]:
		hub.respond_json(connection, 400, {"error": "invalid_grant", "error_description": "refused"})
		return
	issued["used"] = true
	hub.respond_json(connection, 200, {"token": hub.mint("sign_in", "", issued["user"])})


## `resolveCaller` (devices.ts): the device routes take a human token only;
## a device's own token is refused as if there were none.
static func _human_caller(hub, request: Dictionary) -> bool:
	return _human_user(hub, request) != ""


## The user a human token names, or "" for anything else.
static func _human_user(hub, request: Dictionary) -> String:
	var held = _bearer_token(hub, request)
	return str(held["user"]) if held != null and held["kind"] == "sign_in" else ""


## A device's owner; a device a test made by hand is the usual player's.
static func owner_of(device: Dictionary) -> String:
	return str(device.get("owner", "usr_player"))


static func _make_device(hub, connection: Dictionary, request: Dictionary) -> void:
	if not _human_caller(hub, request):
		hub.respond_json(connection, 401, DEVICE_ROUTE_REFUSED)
		return
	var id: String = hub.serial("dev_")
	var name: String = _json_of(request)["name"]
	hub.devices[id] = {"secret": hub.serial("sec_"), "name": name, "revoked": false, "revokedAt": null,
		"owner": _human_user(hub, request)}
	hub.respond_json(connection, 201, {"id": id, "secret": hub.devices[id]["secret"], "name": name,
		"expiresAt": "2026-12-28T00:00:00.000Z"})


## The device exchange (agentpod@9bc1997:apps/hub/src/routes/devices.ts).
static func _device_token(hub, connection: Dictionary, request: Dictionary) -> void:
	if request["query"].get("client", "") != hub.client_id:
		hub.violation("a device exchange without the city's client")
		hub.respond_json(connection, 400, {"error": "this hub does not know that client"})
		return
	var pair: String = str(request["headers"].get("authorization", "")).trim_prefix("Bearer ")
	var id := pair.get_slice(":", 0)
	var device = hub.devices.get(id)
	if device == null or device["revoked"] or pair.substr(pair.find(":") + 1) != device["secret"]:
		hub.respond_json(connection, 401, {"error": "invalid device credential"})
		return
	# The exchange marks the device used (services/device-credentials.ts).
	device["lastUsedAt"] = "2026-09-29T09:%02d:00.000Z" % mini(hub.tokens.size(), 59)
	hub.respond_json(connection, 200, {"token": hub.mint("device", id), "expiresIn": hub.token_lifetime_s,
		"device": {"id": id, "name": device["name"]}})


static func _revoke_device(hub, connection: Dictionary, request: Dictionary, id: String) -> void:
	if not _human_caller(hub, request):
		hub.respond_json(connection, 401, DEVICE_ROUTE_REFUSED)
		return
	# Scoped to the caller, as the hub's is: another account's device is
	# not found, the same as one already revoked.
	var device = hub.devices.get(id)
	if device == null or device["revoked"] or owner_of(device) != _human_user(hub, request):
		hub.respond_json(connection, 404, {"error": "no such live device"})
		return
	device["revoked"] = true
	device["revokedAt"] = "2026-09-29T10:00:00.000Z"
	for token in hub.tokens.keys():
		if hub.tokens[token]["device"] == id:
			hub.tokens.erase(token)
	hub.respond_json(connection, 200, {"revoked": true})


## The caller's own devices, revoked ones with their `revokedAt`, as
## `listDeviceCredentials` selects them
## (agentpod@9bc1997:apps/hub/src/services/device-credentials.ts).
static func _list_devices(hub, connection: Dictionary, request: Dictionary) -> void:
	var user := _human_user(hub, request)
	if user == "":
		hub.respond_json(connection, 401, DEVICE_ROUTE_REFUSED)
		return
	var listed := []
	for id in hub.devices:
		var device: Dictionary = hub.devices[id]
		if owner_of(device) == user:
			listed.append({"id": id, "name": device["name"], "createdAt": "2026-09-29T09:00:00.000Z",
				"lastUsedAt": device.get("lastUsedAt"), "expiresAt": "2026-12-28T00:00:00.000Z",
				"revokedAt": device.get("revokedAt")})
	hub.respond_json(connection, 200, {"devices": listed})


## The unexpired token `request` bears in its Authorization header, or null.
static func _bearer_token(hub, request: Dictionary) -> Variant:
	var header: String = request["headers"].get("authorization", "")
	if not header.begins_with("Bearer "):
		return null
	var held = hub.tokens.get(header.substr(7))
	if held == null or Time.get_ticks_msec() >= held["expires_msec"]:
		return null
	return held


# ---- Stations ----

## `GET /api/fleet/agents` for account `user`: its own stations only, a
## row whose node is offline with `status: "unknown"` and no numbers
## (`deriveStatus`), and the stats counted from those rows
## (`computeFleetStats`) (agentpod@9bc1997:apps/hub/src/routes/fleet.ts,
## apps/hub/src/services/fleet.ts, packages/contract/src/fleet.ts).
static func _fleet(hub, user: String) -> Dictionary:
	var agents := []
	for recorded in hub.agentpod["fleet_agents"]["agents"]:
		if hub.owner_of_station(recorded["stationId"]) != user:
			continue
		var row: Dictionary = recorded.duplicate(true)
		if hub.offline_stations.has(row["stationId"]):
			row["nodeStatus"] = "offline"
		if row["nodeStatus"] == "offline":
			row.merge({"status": "unknown", "cpuPct": null, "memBytes": null, "uptimeSec": null}, true)
		agents.append(row)
	var nodes := {}
	for row in agents:
		nodes[row["nodeId"]] = row["nodeStatus"] == "online"
	return {"stats": {"nodes": {"total": nodes.size(), "online": nodes.values().count(true)},
		"agents": {"total": agents.size()}, "updatesAvailable": agents.filter(func(r): return r["updateAvailable"]).size(),
		"running": agents.filter(func(r): return r["status"] == "running").size()}, "agents": agents}


## A station route, for the caller's own station only: another account's,
## or none, is 404 (`getStation(userId, …)`,
## agentpod@9bc1997:apps/hub/src/routes/stations.ts and its siblings).
static func _station_route(hub, connection: Dictionary, request: Dictionary, route: String) -> void:
	var station_id: String = request["params"]["id"]
	if not _fleet(hub, request["user"])["agents"].any(func(row): return row["stationId"] == station_id):
		hub.respond_json(connection, 404, NOT_FOUND)
		return
	var offline: bool = hub.offline_stations.has(station_id)
	var body := _json_of(request) if BODIES.has(route) else {}
	match route:
		"GET /api/stations/:id/health":
			if offline:
				hub.respond_json(connection, 502, NODE_OFFLINE)
			else:
				hub.respond_json(connection, 200, hub.agentpod["stopped_health" if hub.agentpod.get("stopped", {}).has(station_id) else "health"])
		"GET /api/stations/:id/files":
			var listing = hub.agentpod["files"].get(request["query"].get("path", "."))
			if offline:
				hub.respond_json(connection, 502, NODE_OFFLINE)
			elif listing == null:
				hub.respond_json(connection, 502, {"error": "no such directory"})
			else:
				hub.respond_json(connection, 200, listing)
		"GET /api/stations/:id/file":
			_file(hub, connection, request, offline)
		"GET /api/stations/:id/logs":
			if offline:
				hub.respond_json(connection, 502, NODE_OFFLINE)
			else:
				hub.open_tail(connection, station_id)
		"POST /api/stations/:id/lifecycle":
			if offline:
				hub.respond_json(connection, 409, NODE_OFFLINE)
				return
			if not hub.agentpod.has("stopped"):
				hub.agentpod["stopped"] = {}
			if body["action"] == "stop":
				hub.agentpod["stopped"][station_id] = true
			else:
				hub.agentpod["stopped"].erase(station_id)
			hub.respond_json(connection, 200, hub.agentpod["stopped_health" if hub.agentpod["stopped"].has(station_id) else "health"])
		"POST /api/stations/:id/changeset/status":
			if offline:
				hub.respond_json(connection, 409, NODE_OFFLINE)
			else:
				hub.respond_json(connection, 200, hub.agentpod["changeset_status"])
		"POST /api/stations/:id/changeset/diff":
			if offline:
				hub.respond_json(connection, 409, NODE_OFFLINE)
			else:
				hub.respond_json(connection, 200, hub.agentpod["changeset_diff"])
		"POST /api/stations/:id/acp/sessions":
			_new_session(hub, connection, station_id, body["mode"], offline, request["user"])
		"GET /api/stations/:id/acp/sessions":
			# The caller's own sessions at the station, newest first
			# (agentpod@9bc1997:apps/hub/src/routes/station-acp.ts).
			hub.respond_json(connection, 200, hub.sessions.filter(func(row): return row["stationId"] == station_id \
				and str(row.get("userId", "usr_player")) == request["user"]))


## A file as the hub sends one: the raw body, text or bytes, with its
## truncation in `X-Truncated`.
static func _file(hub, connection: Dictionary, request: Dictionary, offline: bool) -> void:
	if offline:
		hub.respond_json(connection, 502, NODE_OFFLINE)
		return
	var stored = hub.agentpod["file_contents"].get(request["query"].get("path", ""))
	if stored == null:
		hub.respond_json(connection, 502, {"error": "no such file"})
		return
	var bytes: PackedByteArray
	var type := "text/plain; charset=utf-8"
	if stored["encoding"] == "base64":
		bytes = Marshalls.base64_to_raw(stored["content"])
		type = stored["mime"]
	else:
		bytes = str(stored["content"]).to_utf8_buffer()
	var limit := int(request["query"].get("maxBytes", "1048576"))
	if limit < 1 or limit > FILE_READ_MAX_BYTES:
		hub.violation("a maxBytes of %d, outside the hub's 1 to 8 MiB" % limit)
		hub.respond_json(connection, 400, {"error": "invalid maxBytes"})
		return
	var truncated := bytes.size() > limit
	hub.respond(connection, 200, bytes.slice(0, limit) if truncated else bytes,
		{"Content-Type": type, "X-Truncated": "true" if truncated else "false"})


## A new session, as `createSession` makes one
## (agentpod@9bc1997:apps/hub/src/services/acp-sessions.ts `openSession`):
## a station keeps several at once, each its own agent process, so every
## POST makes one (201). Only a node that cannot key a process per session
## refuses a second while one is open (409), which `single_session` turns
## on. The node offline is `Node is offline.`, a 502
## (apps/hub/src/routes/station-acp.ts `createErrorStatus`).
static func _new_session(hub, connection: Dictionary, station_id: String, mode: String, offline: bool, user: String) -> void:
	if offline:
		hub.respond_json(connection, 502, {"error": "Node is offline."})
		return
	for row in hub.sessions:
		if hub.single_session and row["stationId"] == station_id and row["status"] != "ended":
			hub.respond_json(connection, 409, {"error": "An active session already exists for this agent."})
			return
	var row: Dictionary = hub.agentpod["acp_session"].duplicate(true)
	row["id"] = hub.serial("acps_")
	row["stationId"] = station_id
	row["userId"] = user
	row["mode"] = mode
	hub.sessions.push_front(row)
	hub.respond_json(connection, 201, row)


## Ends the session as `endSession` does: a `state` event of `ended`,
## which says `bye` to its sockets and closes them (1000). Another
## account's session is 404, as an absent one
## (agentpod@9bc1997:apps/hub/src/routes/station-acp.ts).
static func _end_session(hub, connection: Dictionary, session_id: String, user: String) -> void:
	for row in hub.sessions:
		if row["id"] == session_id and str(row.get("userId", "usr_player")) == user:
			if row["status"] != "ended":
				hub.push_chat_event(session_id, "state", {"status": "ended", "reason": "Ended from the console."})
			hub.respond_json(connection, 204, null)
			return
	hub.respond_json(connection, 404, NOT_FOUND)


# ---- Superpipeline ----

static func _board_route(hub, connection: Dictionary, request: Dictionary, route: String) -> void:
	var params: Dictionary = request["params"]
	var snapshot: Dictionary = hub.superpipeline["snapshot"]
	if params["id"] != snapshot["boardId"]:
		hub.respond_json(connection, 404, {"error": "board not found"})
		return
	var body := _json_of(request) if BODIES.has(route) else {}
	match route:
		"GET /v1/boards/:id/cards/:cardId/activities":
			var history = hub.superpipeline["activities"].get(params["cardId"])
			if history == null:
				hub.respond_json(connection, 404, _result("CARD_NOT_FOUND", "card not found"))
				return
			hub.respond_json(connection, 200, {"activities": history["activities"], "handoff": history["handoff"],
				"gates": snapshot["gates"].filter(func(g): return g["cardId"] == params["cardId"])})
		"POST /v1/boards/:id/cards/:cardId/move":
			var card := _find(snapshot["cards"], params["cardId"])
			if card.is_empty():
				hub.respond_json(connection, 404, _result("CARD_NOT_FOUND", "card not found"))
			elif not snapshot["stages"].any(func(s): return s["key"] == body["toStageKey"]):
				hub.respond_json(connection, 400, _result("UNKNOWN_STAGE", "unknown stage"))
			else:
				card["currentStageKey"] = body["toStageKey"]
				hub.respond_json(connection, 200, {"card": card})
		"POST /v1/boards/:id/gates/:gateId/resolve":
			var gate := _find(snapshot["gates"], params["gateId"])
			if gate.is_empty():
				hub.respond_json(connection, 404, _result("GATE_NOT_FOUND", "gate not found"))
			elif gate["status"] != "pending":
				hub.respond_json(connection, 409, _result("GATE_NOT_PENDING", "gate is not pending"))
			else:
				gate["status"] = "resolved"
				gate["decision"] = body["decision"]
				gate["comment"] = body.get("comment")
				hub.respond_json(connection, 200, {"card": _find(snapshot["cards"], gate["cardId"])})
		"POST /v1/boards/:id/elicitations/:elicitationId/answer":
			var question := _find(snapshot["elicitations"], params["elicitationId"])
			if question.is_empty():
				hub.respond_json(connection, 404, _result("ELICITATION_NOT_FOUND", "elicitation not found"))
			elif question["status"] != "pending":
				hub.respond_json(connection, 409, _result("ELICITATION_NOT_PENDING", "question is not pending"))
			else:
				question["status"] = "answered"
				question["answer"] = {"option": body.get("option"), "text": body.get("text"),
					"answeredBy": "usr_player", "answeredAt": "2026-09-29T09:30:00.000Z"}
				hub.respond_json(connection, 200, {"card": _find(snapshot["cards"], question["cardId"]),
					"elicitation": question})


## Superpipeline's failed `Result`, as a Durable Object call serialises one.
static func _result(code: String, message: String) -> Dictionary:
	return {"error": {"ok": false, "code": code, "message": message}}


# ---- Matching and checking ----

## The route `path` matches for `product` and `method`: {route, auth,
## params}, or {} for none.
static func _match(product: String, method: String, path: String) -> Dictionary:
	var parts := path.split("/", false)
	for entry in ROUTES.get(product, []):
		if entry[0] != method:
			continue
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
			return {"route": "%s %s" % [method, entry[1]], "auth": entry[2], "params": params}
	return {}


## Whether `request`'s body is the JSON object `route` takes, with the keys
## and values it knows; a violation when it is not.
static func _body_ok(hub, route: String, request: Dictionary) -> bool:
	if str(request["headers"].get("content-type", "")) != "application/json":
		hub.violation("a body that is not JSON on " + route)
		return false
	for byte in request["body"]:
		if byte < 0x20:
			hub.violation("a raw control character in the body of %s, which JSON.parse refuses" % route)
			return false
	if Sockets.json_escapes(request["body"].get_string_from_utf8()).is_empty():
		hub.violation("an escape JSON has not in the body of " + route)
		return false
	var body = StationSource.parse_json(request["body"].get_string_from_utf8())
	if not body is Dictionary:
		hub.violation("a body that is not a JSON object on " + route)
		return false
	var shape: Array = BODIES[route]
	for key in shape[0]:
		if not body.has(key):
			hub.violation("a body without %s on %s" % [key, route])
			return false
	for key in body:
		if not key in shape[0] and not key in shape[1]:
			hub.violation("an unknown key %s on %s" % [key, route])
			return false
		if VALUES.has(key) and not body[key] in VALUES[key]:
			hub.violation("an unknown %s on %s" % [key, route])
			return false
		if key in ["comment", "option", "text", "base", "path"] and (not body[key] is String or body[key] == ""):
			hub.violation("an empty %s on %s" % [key, route])
			return false
	return true


static func _json_of(request: Dictionary) -> Dictionary:
	var body = StationSource.parse_json(request["body"].get_string_from_utf8())
	return body if body is Dictionary else {}


static func _find(rows: Array, id: String) -> Dictionary:
	for row in rows:
		if row["id"] == id:
			return row
	return {}


static func _is_base64url(text: String) -> bool:
	for c in text:
		if not (c >= "a" and c <= "z" or c >= "A" and c <= "Z" or c >= "0" and c <= "9" or c == "-" or c == "_"):
			return false
	return true
