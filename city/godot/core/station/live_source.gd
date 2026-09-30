## The live station: the player's own stations on their AgentPod hub, and
## their Superpipeline work, asked for as the player with a five-minute
## token from `StationCredential` (protocol reference §2, §3 and §5 to §7).
## It answers in the routes' own shapes, as `SampleSource` does, so an app
## never asks which source it has.
##
## Failures are normalised, `{kind, message}`:
## - 401 exchanges the token again and retries once; a second 401 in a row
##   is `signed_out` (and, from the hub, signs the player out);
## - 403 is `no_access` and 404 `not_found`;
## - 409 is `offline` from the station's write, lifecycle and changeset
##   routes, and `conflict` from Superpipeline;
## - 502 from health, files, file and logs is `offline` when its error
##   names the node offline or disconnected, else `failed`;
## - no answer at all is `offline`.
## A message is a fixed line with the route's template and the status,
## never a body, a token or a query string. Superpipeline's own refusal
## ("WIP limit reached …") is the one exception: its board's words, read
## from any of its three error shapes, are the message of a conflict or a
## failure there, for a 4xx refusal only. Nothing here is printed or logged.
##
## The terminal, the chat's session and the board's push channel are
## WebSockets, in `live/`: each reconnects on its own after the backoff
## (`LiveSocket`) while its app holds it open.
class_name LiveSource
extends StationSource

const LiveTerminal := preload("res://core/station/live/live_terminal.gd")
const LiveChat := preload("res://core/station/live/live_chat.gd")
const LiveBoard := preload("res://core/station/live/live_board.gd")

## The route families, which read some statuses differently.
enum Family { FLEET, STATION_READ, STATION_WRITE, SESSION, SUPERPIPELINE }

## The hub's cap on one file read.
const FILE_READ_MAX_BYTES := 8 << 20
## The longest of Superpipeline's own words a message carries.
const MAX_MESSAGE_CHARS := 200

const SIGNED_OUT := "Your sign-in has ended"
const NO_ACCESS := "You don't have access to this"
const NOT_FOUND := "Not found"
const OFFLINE := "Station offline"
const CONFLICT := "That conflicts with how things stand now"
const FAILED := "The request failed"
const UNREADABLE := "The answer could not be read"
const NO_ADDRESS := "Set its address in Settings, under Station computer"
## Why a terminal's clean close was not its shell's exit, by the health
## answer after it.
const NO_STATION_ACCESS := "You don't have access to this station"
const STATION_GONE := "This station no longer exists"

var credential: StationCredential
## The addresses, as the settings hold them; main keeps them current.
var hub_url := ""
var superpipeline_url := ""
## Waits `seconds` and then calls `then`, for a stream's reconnection. Tests
## put in their own, so a backoff never really waits.
var wait: Callable = wait_real
## The streams' clock, in milliseconds, for a handshake's deadline and a
## board's refreshes. Tests put in one they can move on.
var clock: Callable = Time.get_ticks_msec
## How often a stream's socket pings, in seconds; one ping unanswered by
## the next counts the link as lost. Tests shorten it.
var heartbeat_s := 20.0

## The control characters `escape_controls` writes out, made once.
static var _controls: RegEx

## The station IDs the last successful station list held, or null while
## unknown: before a list, or after a refused one or a sign-out. "Look at
## screen" is offered only at desks bound to one of them.
var _listed_ids: Variant = null


func _init(credential_: StationCredential, hub_url_ := "", superpipeline_url_ := "") -> void:
	credential = credential_
	hub_url = hub_url_
	superpipeline_url = superpipeline_url_
	# Signed out, the player's stations are no longer known.
	if credential != null:
		credential.signed_out.connect(forget_stations)


func _is_live() -> bool:
	return true


# --- Stations (AgentPod) ---

## Lists the stations, and remembers which (see `may_see`); a refusal
## (signed out, or no access) forgets them.
func list_stations() -> int:
	var call_id := _new_call_id()
	_request(_hub("GET", "/api/fleet/agents", "GET /api/fleet/agents", Family.FLEET),
		func(ok: bool, body: Variant, status: int) -> void:
			if ok and body is Dictionary and body.get("agents") is Array:
				var ids := {}
				for row in body["agents"]:
					if row is Dictionary:
						ids[str(row.get("stationId", ""))] = true
				_listed_ids = ids
				stations.emit(body["agents"].duplicate(true))
			elif not ok and body is Dictionary and body.get("kind") in ["signed_out", "no_access"]:
				forget_stations()
			result.emit(call_id, ok, body, status))
	return call_id


## Forgets which stations were listed: they are unknown again, until the
## next list.
func forget_stations() -> void:
	_listed_ids = null


## Only a station the last list held, while signed in; unknown is no.
func may_see(station_id: String) -> bool:
	return _listed_ids != null and credential != null and credential.is_signed_in() \
		and (_listed_ids as Dictionary).has(station_id)


func health(station_id: String) -> int:
	return _call(_hub("GET", _station(station_id, "/health"), "GET /api/stations/:id/health", Family.STATION_READ))


func files(station_id: String, path: String) -> int:
	var at := path if path != "" else "."
	return _call(_hub("GET", _station(station_id, "/files?path=" + at.uri_encode()),
		"GET /api/stations/:id/files", Family.STATION_READ))


func file(station_id: String, path: String, max_bytes: int) -> int:
	var target := _station(station_id, "/file?path=" + path.uri_encode())
	if max_bytes > 0:
		target += "&maxBytes=%d" % mini(max_bytes, FILE_READ_MAX_BYTES)
	var request := _hub("GET", target, "GET /api/stations/:id/file", Family.STATION_READ)
	request["parse"] = _file_body
	return _call(request)


func lifecycle(station_id: String, action: String) -> int:
	return _call(_hub("POST", _station(station_id, "/lifecycle"), "POST /api/stations/:id/lifecycle",
		Family.STATION_WRITE, {"action": action}))


func changeset_status(station_id: String, base: String) -> int:
	var body := {}
	if base != "":
		body["base"] = base
	return _call(_hub("POST", _station(station_id, "/changeset/status"), "POST /api/stations/:id/changeset/status",
		Family.STATION_WRITE, body))


func changeset_diff(station_id: String, side: String, path: String) -> int:
	var body := {"side": side}
	if path != "":
		body["path"] = path
	return _call(_hub("POST", _station(station_id, "/changeset/diff"), "POST /api/stations/:id/changeset/diff",
		Family.STATION_WRITE, body))


func open_logs(station_id: String) -> StationStream.Logs:
	return LiveLogs.new(self, station_id)


func open_terminal(station_id: String) -> StationStream.Terminal:
	return LiveTerminal.new(self, station_id)


## The player's open session is listed first and attached to: a current
## hub keeps several sessions a station, each its own agent process, and
## answers every POST with a new one (201), so posting on every open would
## start a process each time and lose the conversation. A session is made
## only when none is open, or when the player asks for a new one
## (`new_session`, the Chat app's "New session"). An older node keeps one
## session a station and refuses a second with 409, which means another
## session opened meanwhile: that one is attached to.
func open_chat(station_id: String, mode: String, new_session := false) -> StationStream.Chat:
	var chat := LiveChat.new(self, station_id)
	if new_session:
		_start_session(chat, mode)
		return chat
	_request(_hub("GET", _station(station_id, "/acp/sessions"), "GET /api/stations/:id/acp/sessions",
		Family.SESSION), func(ok: bool, body: Variant, _status: int) -> void:
			if not ok:
				chat.fail(body)
				return
			var open := newest_open(body)
			if open.is_empty():
				_start_session(chat, mode)
			else:
				chat.attach(open))
	return chat


## A new session in `mode` for `chat`; a 409 (an older node's one session a
## station) attaches to the one open.
func _start_session(chat: LiveChat, mode: String) -> void:
	_request(_hub("POST", _station(chat.station_id, "/acp/sessions"), "POST /api/stations/:id/acp/sessions",
		Family.SESSION, {"mode": mode}), func(ok: bool, body: Variant, status: int) -> void:
			if ok and body is Dictionary:
				chat.attach(body)
			elif not ok and status == 409:
				_attach_newest(chat)
			else:
				chat.fail(body if not ok else make_error("failed", _message(UNREADABLE, "POST /api/stations/:id/acp/sessions", status))))


## The first session of a listing that has not ended: the newest, as the
## hub lists the caller's own sessions newest activity first; {} for none.
static func newest_open(listing: Variant) -> Dictionary:
	for row in (listing if listing is Array else []):
		if row is Dictionary and str(row.get("status", "")) != "ended":
			return row
	return {}


func watch_chat(station_id: String) -> StationStream.Chat:
	var chat := LiveChat.new(self, station_id)
	_attach_newest(chat)
	return chat


func end_chat(session_id: String) -> int:
	return _call(_hub("DELETE", "/api/acp/sessions/" + session_id.uri_encode(), "DELETE /api/acp/sessions/:id",
		Family.SESSION))


# --- Work (Superpipeline) ---

func boards() -> int:
	return _call(_superpipeline("GET", "/v1/boards", "GET /v1/boards"))


func board(board_id: String) -> StationStream.Board:
	return LiveBoard.new(self, board_id)


func agents() -> int:
	return _call(_superpipeline("GET", "/v1/agents", "GET /v1/agents"))


func card_activities(board_id: String, card_id: String) -> int:
	return _call(_superpipeline("GET", "/v1/boards/%s/cards/%s/activities" % [board_id.uri_encode(), card_id.uri_encode()],
		"GET /v1/boards/:id/cards/:cardId/activities"))


func move_card(board_id: String, card_id: String, to_stage: String) -> int:
	return _call(_superpipeline("POST", "/v1/boards/%s/cards/%s/move" % [board_id.uri_encode(), card_id.uri_encode()],
		"POST /v1/boards/:id/cards/:cardId/move", {"toStageKey": to_stage}))


func resolve_gate(board_id: String, gate_id: String, decision: String, comment: String) -> int:
	var body := {"decision": decision}
	if comment.strip_edges() != "":
		body["comment"] = comment
	return _call(_superpipeline("POST", "/v1/boards/%s/gates/%s/resolve" % [board_id.uri_encode(), gate_id.uri_encode()],
		"POST /v1/boards/:id/gates/:gateId/resolve", body))


func answer(board_id: String, elicitation_id: String, option: String, text: String) -> int:
	var body := {}
	if option.strip_edges() != "":
		body["option"] = option.strip_edges()
	if text.strip_edges() != "":
		body["text"] = text.strip_edges()
	return _call(_superpipeline("POST", "/v1/boards/%s/elicitations/%s/answer" % [board_id.uri_encode(), elicitation_id.uri_encode()],
		"POST /v1/boards/:id/elicitations/:elicitationId/answer", body))


# --- Requests ---

## A hub request: its method, target (path and query), the route's
## template for messages, its family and its JSON body (null for none).
func _hub(method: String, target: String, route: String, family: Family, body: Variant = null) -> Dictionary:
	return {"product": "hub", "method": method, "target": target, "route": route, "family": family,
		"body": body, "parse": _json_body, "retried": false}


func _superpipeline(method: String, target: String, route: String, body: Variant = null) -> Dictionary:
	return {"product": "superpipeline", "method": method, "target": target, "route": route,
		"family": Family.SUPERPIPELINE, "body": body, "parse": _json_body, "retried": false}


func _station(station_id: String, rest: String) -> String:
	return "/api/stations/" + station_id.uri_encode() + rest


## Starts `request` and answers it through `result`, with `then` called
## on a success's body first.
func _call(request: Dictionary, then := Callable()) -> int:
	var call_id := _new_call_id()
	_request(request, func(ok: bool, body: Variant, status: int) -> void:
		if ok and then.is_valid():
			then.call(body)
		result.emit(call_id, ok, body, status))
	return call_id


## Runs `request`, with a token, and calls `done(ok, body, status)` on a
## later frame, never inside this call.
func _request(request: Dictionary, done: Callable) -> void:
	later(func() -> void: _send(request, done))


func _send(request: Dictionary, done: Callable) -> void:
	var base := _base(request["product"])
	if base == "":
		done.call(false, make_error("failed", _message(NO_ADDRESS, request["route"], 0)), 0)
		return
	credential.request_token(func(token: String, error: String) -> void:
		if error == "no_address":
			done.call(false, make_error("failed", _message(NO_ADDRESS, request["route"], 0)), 0)
			return
		if error != "":
			done.call(false, _error_of(request, error, 0), 0)
			return
		var headers := PackedStringArray(["Authorization: Bearer " + token, "Accept: application/json"])
		var bytes := PackedByteArray()
		if request["body"] != null:
			headers.append("Content-Type: application/json")
			bytes = strict_json(request["body"]).to_utf8_buffer()
		elif request["method"] != "GET":
			headers.append("Content-Length: 0")
		var http := StationHttp.start(_method_of(request["method"]), base + request["target"], headers, bytes)
		http.finished.connect(func(status: int, response_headers: Dictionary, response: PackedByteArray) -> void:
			_answered(request, done, status, response_headers, response))
		http.network_failed.connect(func() -> void:
			done.call(false, _error_of(request, "offline", 0), 0)),
		request["retried"])


func _answered(request: Dictionary, done: Callable, status: int, headers: Dictionary, response: PackedByteArray) -> void:
	if status >= 200 and status < 300:
		var parsed: Array = request["parse"].call(status, headers, response)
		if parsed[0]:
			done.call(true, parsed[1], status)
		else:
			done.call(false, make_error("failed", _message(UNREADABLE, request["route"], status)), status)
		return
	if status == 401:
		if not request["retried"]:
			request["retried"] = true
			_send(request, done)
			return
		if request["product"] == "hub":
			credential.refuse()
		done.call(false, _error_of(request, "signed_out", status), status)
		return
	done.call(false, _error_of(request, kind_for(request["family"], status, response), status, response), status)


## The error kind of a failed answer, by the route's family.
static func kind_for(family: Family, status: int, response: PackedByteArray) -> String:
	match status:
		401:
			return "signed_out"
		403:
			return "no_access"
		404:
			return "not_found"
		409:
			return "offline" if family == Family.STATION_WRITE else "conflict"
		502:
			if family in [Family.STATION_READ, Family.SESSION] and names_node_offline(response):
				return "offline"
	return "failed"


## Whether a station route's error names the node offline or disconnected.
static func names_node_offline(response: PackedByteArray) -> bool:
	var parsed = _error_body(response)
	if not parsed is Dictionary or not parsed.get("error") is String:
		return false
	var error: String = parsed["error"].to_lower()
	return error.contains("offline") or error.contains("disconnected")


## Superpipeline's own words for a refusal, from any of its three shapes: a
## bare string, `{message}`, or a failed `Result` (`{ok, code, message}`);
## "" when there are none.
static func superpipeline_message(response: PackedByteArray) -> String:
	var parsed = _error_body(response)
	if not parsed is Dictionary:
		return ""
	var error = parsed.get("error")
	var words := ""
	if error is String:
		words = error
	elif error is Dictionary and error.get("message") is String:
		words = error["message"]
	return words.strip_edges().get_slice("\n", 0).left(MAX_MESSAGE_CHARS)


## An error's body, parsed, or null: an error is small, and anything else
## (a proxy's page, say) is not read.
static func _error_body(response: PackedByteArray) -> Variant:
	if response.size() > 65536 or not StationSource.is_utf8(response):
		return null
	return parse_json(response.get_string_from_utf8())


func _error_of(request: Dictionary, kind: String, status: int, response := PackedByteArray()) -> Dictionary:
	# Its words for a refusal (4xx) only: a server error's may be anything.
	if request["family"] == Family.SUPERPIPELINE and kind in ["conflict", "failed"] and status >= 400 and status < 500:
		var words := superpipeline_message(response)
		if words != "":
			return make_error(kind, words)
	var line: String = {"signed_out": SIGNED_OUT, "no_access": NO_ACCESS, "not_found": NOT_FOUND,
		"offline": OFFLINE, "conflict": CONFLICT}.get(kind, FAILED)
	return make_error(kind, _message(line, request["route"], status))


## A fixed line, the route's template and the status: all a message holds.
static func _message(line: String, route: String, status: int) -> String:
	return "%s (%s, %s)" % [line, route, str(status) if status > 0 else "no answer"]


## The product's address, or "" when it is not one: split_url must take
## it, and so must Godot's own URL parser, which logs a URL it refuses. And
## it must be `https://`, or plain `http://` to this computer only
## (`StationHttp.is_secure_or_loopback`): a token never crosses a network
## in cleartext.
func _base(product: String) -> String:
	var base := (hub_url if product == "hub" else superpipeline_url).strip_edges().rstrip("/")
	return base if StationHttp.is_secure_or_loopback(base) and LiveSocket.parses(base) else ""


static func _method_of(method: String) -> int:
	return {"GET": HTTPClient.METHOD_GET, "POST": HTTPClient.METHOD_POST,
		"DELETE": HTTPClient.METHOD_DELETE}[method]


func _json_body(status: int, _headers: Dictionary, response: PackedByteArray) -> Array:
	if status == 204 or response.is_empty():
		return [true, null]
	var parsed = parse_json(response.get_string_from_utf8())
	return [parsed != null, parsed]


## A file read is a raw body: text as `text/plain`, anything else as bytes,
## with its truncation in `X-Truncated`. The node sends text only when it
## is UTF-8, but a cut one may end inside a character; it ends before it.
func _file_body(_status: int, headers: Dictionary, response: PackedByteArray) -> Array:
	var truncated := str(headers.get("x-truncated", "false")).strip_edges().to_lower() == "true"
	var type := str(headers.get("content-type", "")).to_lower()
	if not type.begins_with("text/"):
		return [true, {"bytes": response, "truncated": truncated}]
	var end := whole_characters_end(response)
	return [true, {"text": response.slice(0, end).get_string_from_utf8(), "truncated": truncated}]


## Where the last whole UTF-8 character of `bytes` ends: its size, or the
## start of a character cut short at the end.
static func whole_characters_end(bytes: PackedByteArray) -> int:
	var start := bytes.size() - 1
	while start >= 0 and bytes.size() - start <= 4 and bytes[start] & 0xC0 == 0x80:
		start -= 1
	if start < 0 or bytes[start] < 0x80:
		return bytes.size()
	var length := 2 if bytes[start] < 0xE0 else (3 if bytes[start] < 0xF0 else 4)
	return bytes.size() if bytes.size() - start >= length else start


## Runs `callable` on the next frame.
static func later(callable: Callable) -> void:
	(Engine.get_main_loop() as SceneTree).process_frame.connect(callable, CONNECT_ONE_SHOT)


## A real wait: calls `then` after `seconds`.
static func wait_real(seconds: float, then: Callable) -> void:
	(Engine.get_main_loop() as SceneTree).create_timer(seconds).timeout.connect(then, CONNECT_ONE_SHOT)


## `value` as JSON that a strict parser takes. Godot's JSON.stringify
## (`String::json_escape`) leaves control characters other than \b, \f,
## \n, \r and \t raw in a string, and writes 0x0B as `\v`, an escape JSON
## has not. JavaScript's JSON.parse (the hub's) refuses both, so an arrow
## key (Esc [ A), Ctrl-C or Ctrl-K would be lost; they are written as
## \u00XX here.
static func strict_json(value: Variant) -> String:
	return escape_controls(JSON.stringify(value))


## Rewrites JSON `text` so that a strict parser takes it: each raw control
## character, and each `\v`, as \u00XX. It reads escape by escape, so the
## text after an escaped backslash (`\\v`: a backslash, then v) is left as
## the text it is. Outside a string, JSON.stringify writes neither.
static func escape_controls(text: String) -> String:
	if _controls == null:
		_controls = RegEx.create_from_string("\\\\(.)|[\\x{01}-\\x{1f}]")
	var pieces := PackedStringArray()
	var at := 0
	for found in _controls.search_all(text):
		var escaped := found.get_string(1)
		if escaped != "" and escaped != "v":
			continue
		pieces.append(text.substr(at, found.get_start() - at))
		pieces.append("\\u%04x" % (0x0B if escaped == "v" else text.unicode_at(found.get_start())))
		at = found.get_end()
	if at == 0:
		return text
	pieces.append(text.substr(at))
	return "".join(pieces)


## A stream's normalised failure: `kind`'s fixed line (or `line`), the
## socket's route and the close code it ended with (0: none).
static func stream_error(kind: String, route: String, code: int, line := "") -> Dictionary:
	var words: String = line if line != "" else {"signed_out": SIGNED_OUT, "no_access": NO_ACCESS,
		"not_found": NOT_FOUND, "offline": OFFLINE}.get(kind, FAILED)
	return make_error(kind, _message(words, route, code))


# --- The chat's session, found over REST ---

## Attaches `chat` to the station's newest session that has not ended, or
## fails it with "No session".
func _attach_newest(chat: LiveChat) -> void:
	_request(_hub("GET", _station(chat.station_id, "/acp/sessions"), "GET /api/stations/:id/acp/sessions",
		Family.SESSION), func(ok: bool, body: Variant, _status: int) -> void:
			if not ok:
				chat.fail(body)
				return
			var open := newest_open(body)
			if open.is_empty():
				chat.fail(make_error("not_found", NO_SESSION))
			else:
				chat.attach(open))


## The log tail: `GET /api/stations/:id/logs`, as Server-Sent Events, each
## `data:` line a log line. Like the other streams it follows again on its
## own: a tail that ends or is lost, a node offline (502) or a hub out of
## reach is `offline`, and asked for again after LiveSocket's backoff,
## while the app holds it. The backoff starts over only once a tail has
## stayed open LiveSocket.STABLE_S. A 401 is retried once with a new token;
## any other refusal fails it.
class LiveLogs extends StationStream.Logs:
	const ROUTE := "GET /api/stations/:id/logs"
	## The longest line held while waiting for its end; a longer one is
	## dropped, so a stream that never ends a line cannot grow without limit.
	const MAX_PENDING_BYTES := 65536

	var _source: LiveSource
	var _station_id: String
	var _http: StationHttp
	var _retried := false
	## Attempts since the tail last worked, for the backoff: stayed open
	## LiveSocket.STABLE_S. A line does not count, since the node starts
	## every tail with its last lines, even one that ends at once. And a
	## count that a wait for an older attempt is checked against.
	var _attempt := 0
	var _opened_msec := -1
	var _generation := 0
	var _pending := PackedByteArray()
	## Set while a line longer than MAX_PENDING_BYTES runs on: the rest of
	## it, to its newline, is dropped.
	var _discarding := false
	var _data_lines: PackedStringArray = []

	func _init(source: LiveSource, station_id: String) -> void:
		_source = source
		_station_id = station_id
		LiveSource.later(_connect)

	func close() -> void:
		_stop()
		_generation += 1
		_set_state("closed")

	# While being freed a script's own methods cannot be called; the request
	# is cancelled directly, so a dropped tail stops at once.
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and _http != null:
			_http.cancel()

	func _stop() -> void:
		if _http != null:
			_http.cancel()
			_http = null

	func _connect() -> void:
		if state == "closed":
			return
		var base := _source._base("hub")
		if base == "":
			_fail("failed", 0, LiveSource.NO_ADDRESS)
			return
		_source.credential.request_token(func(token: String, error: String) -> void:
			if state == "closed":
				return
			if error == "signed_out":
				_fail(error, 0)
				return
			if error == "no_address":
				_fail("failed", 0, LiveSource.NO_ADDRESS)
				return
			if error != "":
				_retry_later()
				return
			_pending = PackedByteArray()
			_discarding = false
			_data_lines.clear()
			_http = StationHttp.start(HTTPClient.METHOD_GET, base + _source._station(_station_id, "/logs"),
				PackedStringArray(["Authorization: Bearer " + token, "Accept: text/event-stream"]), PackedByteArray(), true)
			_http.response_started.connect(_on_started)
			_http.chunk.connect(_on_chunk)
			_http.ended.connect(_on_ended)
			_http.finished.connect(_on_refused)
			_http.network_failed.connect(func() -> void:
				_http = null
				_retry_later()),
			_retried)

	func _on_started(_status: int, _headers: Dictionary) -> void:
		_opened_msec = _source.clock.call()
		_retried = false
		_set_state("open")

	## Offline, and asked for again after the backoff.
	func _retry_later() -> void:
		if state == "closed":
			return
		_stop()
		_set_state("offline")
		_generation += 1
		_source.wait.call(LiveSocket.backoff_s(_attempt), _on_waited.bind(_generation))
		_attempt += 1

	func _on_waited(generation: int) -> void:
		if generation == _generation and state != "closed":
			_retried = false
			_connect()

	## A refusal before the stream opened: 401 once is retried with a new
	## token; an offline node (502) waits and tries again; the rest are
	## failures.
	func _on_refused(status: int, _headers: Dictionary, response: PackedByteArray) -> void:
		_http = null
		if status == 401 and not _retried:
			_retried = true
			_connect()
			return
		if status == 401:
			_source.credential.refuse()
		var kind := LiveSource.kind_for(LiveSource.Family.STATION_READ, status, response)
		if kind == "offline":
			_retry_later()
			return
		_fail(kind, status)

	## The stream ended, cleanly or lost: offline, and followed again after
	## the backoff, which starts over if the tail had stayed open a while.
	func _on_ended(_lost: bool) -> void:
		_http = null
		if _opened_msec >= 0 and _source.clock.call() - _opened_msec >= int(LiveSocket.STABLE_S * 1000.0):
			_attempt = 0
		_opened_msec = -1
		_retry_later()

	func _fail(kind: String, status: int, line := "") -> void:
		if state == "closed":
			return
		var words: String = line if line != "" else {"signed_out": LiveSource.SIGNED_OUT,
			"no_access": LiveSource.NO_ACCESS, "not_found": LiveSource.NOT_FOUND,
			"offline": LiveSource.OFFLINE}.get(kind, LiveSource.FAILED)
		failed.emit(StationSource.make_error(kind, LiveSource._message(words, ROUTE, status)))
		_set_state("closed")

	## Reads Server-Sent Events: `data:` lines gather until a blank line
	## ends the event, whose data (the lines joined) is split into log
	## lines. Comments and other fields are skipped.
	## Bytes are held until their line ends, so a line (or a character) cut
	## across chunks arrives whole; a line that is not UTF-8 is skipped.
	func _on_chunk(bytes: PackedByteArray) -> void:
		_pending.append_array(bytes)
		while state != "closed":
			var newline := _pending.find(10)
			if newline < 0:
				if _pending.size() > MAX_PENDING_BYTES:
					# Too long to be a line worth holding: drop it, and all of it
					# that is still to come, so its tail never reads as a line
					# (or as the blank that ends an event).
					_pending = PackedByteArray()
					_discarding = true
				return
			var raw := _pending.slice(0, newline)
			_pending = _pending.slice(newline + 1)
			if _discarding:
				_discarding = false
				continue
			if not StationSource.is_utf8(raw):
				continue
			var text := raw.get_string_from_utf8().trim_suffix("\r")
			if text == "":
				_dispatch()
			elif text.begins_with("data:"):
				var value := text.substr(5)
				_data_lines.append(value.substr(1) if value.begins_with(" ") else value)

	func _dispatch() -> void:
		if _data_lines.is_empty():
			return
		var pieces := "\n".join(_data_lines).split("\n")
		_data_lines.clear()
		if pieces.size() > 1 and pieces[pieces.size() - 1] == "":
			pieces.remove_at(pieces.size() - 1)
		for piece in pieces:
			if state == "closed":
				return
			line.emit(piece)
