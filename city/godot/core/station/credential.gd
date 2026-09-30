## The player's sign-in to their own AgentPod hub, kept the way
## `apn fleet login` keeps its (protocol reference §1.3 to §1.5):
##
## - Signing in is the authorization-code flow with PKCE through a loopback
##   listener on 127.0.0.1 and the system browser. The hub's one-time token
##   then mints a device credential, `{id, secret}`, good for ninety days.
## - The credential is stored in `user://station_credential.json`, readable
##   by its owner only. Tokens stay in memory: each is a five-minute one the
##   credential is exchanged for, as the city's own client (`agentnagar`),
##   so it carries Superpipeline's audience as well as the hub's.
## - Disconnecting forgets the credential at once, then revokes the device
##   with a human token from a browser sign-in (the same PKCE flow, making
##   no device): the hub refuses a device's own token for that (its
##   `resolveCaller` refuses `amr: ["device"]`). Signing in again revokes
##   the device held before, with the new sign-in's human token.
##
## The hub must be `https://`, or plain `http://` on this computer only
## (`StationHttp.is_secure_or_loopback`): elsewhere nothing is sent, not
## the secret, a token or a sign-in's code.
##
## Nothing here is logged: not a token, a secret, a code, a URL's query or
## a response body. A failure is one of the fixed lines below.
class_name StationCredential
extends RefCounted

## Signing in ended: `ok`, or not, with the line that says why.
signal sign_in_finished(ok: bool, message: String)
## The hub refused the credential, so the player is signed out.
signal signed_out
## Disconnecting finished: the device was `revoked`, or it was not and
## `message` says so, naming it and the console (see `not_revoked`). The
## file was gone from the start.
signal disconnect_finished(revoked: bool, message: String)

const PATH := "user://station_credential.json"
## A whole browser flow (signing in, or Disconnect's revoking), from
## opening the browser to its end.
const SIGN_IN_TIMEOUT_S := 300.0
## A token is exchanged again when this little of its life is left.
const REFRESH_MARGIN_S := 30.0
## Readable and writable by its owner only (0600).
const OWNER_ONLY := FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER
## The private directory the file is written in first: its owner's only
## (0700), so the file is never readable by anyone else, even for a moment.
const PRIVATE_DIR := FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_EXECUTE_OWNER
const PRIVATE_DIR_NAME := ".station_private"

const DESKTOP_ONLY := "Sign-in needs the desktop app for now."
const NO_HUB := "Set your hub's address in Settings, under Station computer."
const NOT_HTTPS := "Your hub's address must use HTTPS; plain HTTP is only for this computer."
const CANNOT_LISTEN := "Sign-in could not start on this computer."
const TIMED_OUT := "Signing in took too long. Try again."
const CANCELLED := "Signing in was cancelled."
const MISMATCH := "That sign-in did not start here. Try again."
const REFUSED := "The hub did not sign you in."
const UNREACHABLE := "The hub could not be reached."
const NOT_REMEMBERED := "The hub signed you in but would not remember this computer."
const NOT_SAVED := "The sign-in could not be saved on this computer."
const REVOKED := "Revoked."

## What the browser shows once the hub has sent it back: back to the
## game, or that the sign-in did not finish.
const RETURN_PAGE := "<!doctype html><meta charset=\"utf-8\"><title>Agentnagar</title><p>You can return to Agentnagar.</p>"
const FAILED_PAGE := "<!doctype html><meta charset=\"utf-8\"><title>Agentnagar</title><p>The sign-in did not finish. Go back to Agentnagar to try again.</p>"
const MISMATCH_PAGE := "<!doctype html><meta charset=\"utf-8\"><title>Agentnagar</title><p>This sign-in did not start in Agentnagar. You can close this page.</p>"
## The most a browser's request to the listener may be, in bytes.
const MAX_CALLBACK_BYTES := 16384

## The hub's address, as the settings hold it.
var hub_url := ""
## The city's registration with the hub.
var client_id := "agentnagar"
## Where the credential is stored; tests use their own file.
var path := PATH
## "desktop", "web" or "mobile": sign-in needs a desktop.
var platform := ComputerScreen.current_platform()
## Opens a URL in the system browser. Tests replace it with a scripted one.
var open_browser := open_in_system_browser
## What the hub lists this device as.
var device_name := "Agentnagar on " + host_name()
var sign_in_timeout_s := SIGN_IN_TIMEOUT_S
var refresh_margin_s := REFRESH_MARGIN_S
## Whether the last browser flow's line names a device the player should
## revoke in the AgentPod console: one not revoked, or made but not stored.
var console_hint := false

## The stored credential; "" when there is none.
var device_id := ""
var _secret := ""
## The stored credential's hub, which must be the one in the settings,
## and the name the hub lists its device under.
var _stored_hub := ""
var _stored_name := ""
## Set when the hub refused the credential: signed out until signing in.
var _refused := false

var _token := ""
var _token_expires_msec := 0
var _exchange: StationHttp
## Who waits on the exchange under way: callables taking (token, error).
var _waiting: Array[Callable] = []

# The browser flow: "" when none runs, else what it is for, "sign_in" or
# "disconnect", at which hub, and the device it revokes ({hub, id, name},
# or {}): the one held before signing in, or the one disconnected.
var _flow := ""
var _flow_hub := ""
var _revoking := {}
# A line to report with the flow's end, about a device it could not revoke.
var _note := ""
var _polling := false
var _listener: TCPServer
var _peers: Array = []
var _verifier := ""
var _expected_state := ""
var _redirect_uri := ""
var _began_msec := 0
var _sign_in_request: StationHttp


func _init(hub_url_ := "", client_id_ := "agentnagar", path_ := PATH) -> void:
	hub_url = hub_url_
	client_id = client_id_
	path = path_
	load_file()


## base64url without padding (RFC 4648 §5), as PKCE writes it.
static func base64url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").rstrip("=")


## The S256 code challenge for `verifier`: base64url(SHA-256(verifier)).
static func challenge_for(verifier: String) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(verifier.to_ascii_buffer())
	return base64url(hashing.finish())


## This computer's name, for the hub's list of the player's devices.
static func host_name() -> String:
	for variable in ["HOSTNAME", "COMPUTERNAME"]:
		var value := OS.get_environment(variable).strip_edges()
		if value != "":
			return value
	if OS.get_name() != "Windows" and FileAccess.file_exists("/etc/hostname"):
		var value := FileAccess.get_file_as_string("/etc/hostname").strip_edges()
		if value != "":
			return value
	return "this computer"


## Whether this platform keeps Unix permissions, which the file must have.
static func has_unix_permissions() -> bool:
	return OS.get_name() in ["Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]


## The line for a device Disconnect could not revoke: the player can, in
## the console.
static func not_revoked(name: String) -> String:
	return "Not revoked: revoke '%s' in the AgentPod console." % name


## Whether `file` holds a device credential, for any hub: what Disconnect
## has to revoke, with live mode on or off.
static func holds_device(file: String) -> bool:
	return StationCredential.new("", "agentnagar", file).device_id != ""


## A hub's answer, parsed, or null: a body that is not UTF-8 is not read
## (decoded anyway, its bad bytes would pass for characters in a token or
## an ID).
static func _answer_of(body: PackedByteArray) -> Variant:
	return StationSource.parse_json(body.get_string_from_utf8()) if StationSource.is_utf8(body) else null


## Where the file is written before it is moved into place.
static func private_dir_of(file: String) -> String:
	return file.get_base_dir().path_join(PRIVATE_DIR_NAME)


## Opens `url` in the system browser (see SystemBrowser, which a test run
## makes open nothing).
static func open_in_system_browser(url: String) -> void:
	SystemBrowser.open(url)


## The hub's address without a trailing slash.
func hub() -> String:
	return hub_url.strip_edges().rstrip("/")


## Reads the stored credential, if there is one for this hub.
func load_file() -> void:
	device_id = ""
	_secret = ""
	_stored_hub = ""
	_stored_name = ""
	if not FileAccess.file_exists(path):
		return
	var stored = StationSource.parse_json(FileAccess.get_file_as_string(path))
	if not stored is Dictionary:
		return
	for key in ["hub", "device_id", "secret"]:
		if not stored.get(key) is String or stored[key] == "":
			return
	_stored_hub = stored["hub"]
	device_id = stored["device_id"]
	_secret = stored["secret"]
	_stored_name = stored["name"] if stored.get("name") is String and stored["name"] != "" else device_name


## Whether a credential for the configured hub is held and not refused.
func is_signed_in() -> bool:
	return device_id != "" and _stored_hub == hub() and not _refused


func is_signing_in() -> bool:
	return _flow == "sign_in"


func is_disconnecting() -> bool:
	return _flow == "disconnect"


# ---- The browser flow: signing in, and Disconnect's human token ----

## Starts signing in: a loopback listener, then the browser at the hub's
## authorize page. It ends with `sign_in_finished`, on a later frame. A
## device held already is revoked with the new sign-in's token, before the
## new one is made.
func sign_in() -> void:
	if _flow != "":
		return
	_revoking = _held()
	_begin_flow("sign_in", hub())


## Stops the browser flow under way: signing in ends as cancelled, and a
## Disconnect as not revoked.
func cancel_browser() -> void:
	if _flow != "":
		_end_flow(false, CANCELLED)


## The sign-in's name for `cancel_browser`.
func cancel_sign_in() -> void:
	if _flow == "sign_in":
		cancel_browser()


func _held() -> Dictionary:
	if device_id == "":
		return {}
	return {"hub": _stored_hub, "id": device_id, "name": _stored_name}


func _begin_flow(flow: String, at_hub: String) -> void:
	_flow = flow
	_flow_hub = at_hub
	_note = ""
	_began_msec = Time.get_ticks_msec()
	_start_polling()
	if platform != "desktop":
		_end_flow(false, DESKTOP_ONLY)
		return
	if StationHttp.split_url(at_hub).is_empty():
		_end_flow(false, NO_HUB)
		return
	if not StationHttp.is_secure_or_loopback(at_hub):
		# The sign-in's code, its token and the new secret would cross the
		# network in cleartext.
		_end_flow(false, NOT_HTTPS)
		return
	_listener = StationSource.new_network_object("TCPServer")
	if _listener.listen(0, "127.0.0.1") != OK:
		_end_flow(false, CANNOT_LISTEN)
		return
	_redirect_uri = "http://127.0.0.1:%d/callback" % _listener.get_local_port()
	var crypto := Crypto.new()
	_verifier = base64url(crypto.generate_random_bytes(48))
	_expected_state = base64url(crypto.generate_random_bytes(24))
	var query := [
		"client=" + client_id.uri_encode(),
		"redirect_uri=" + _redirect_uri.uri_encode(),
		"response_type=code",
		"state=" + _expected_state,
		"code_challenge=" + challenge_for(_verifier),
		"code_challenge_method=S256",
	]
	open_browser.call(at_hub + "/api/auth/authorize?" + "&".join(query))


## Ends the browser flow now, and says so on the next frame (never inside
## the call that started it): signing in with `ok` and `message` (on
## success, a note about a device it could not revoke), a Disconnect as
## revoked or not. `names_device` says a failure's line names a device to
## revoke in the console (see `console_hint`).
func _end_flow(ok: bool, message: String, names_device := false) -> void:
	var flow := _flow
	var revoking := _revoking
	_flow = ""
	_revoking = {}
	_close_listener()
	if _sign_in_request != null:
		_sign_in_request.cancel()
		_sign_in_request = null
	_verifier = ""
	_expected_state = ""
	var tree := Engine.get_main_loop() as SceneTree
	if flow == "disconnect":
		console_hint = not ok
		var line := REVOKED if ok else not_revoked(str(revoking.get("name", device_name)))
		tree.process_frame.connect(disconnect_finished.emit.bind(ok, line), CONNECT_ONE_SHOT)
	else:
		var line := message if not ok else _note
		console_hint = names_device or (ok and _note != "")
		tree.process_frame.connect(sign_in_finished.emit.bind(ok, line), CONNECT_ONE_SHOT)


func _close_listener() -> void:
	for peer_state in _peers:
		peer_state["peer"].disconnect_from_host()
	_peers.clear()
	if _listener != null:
		_listener.stop()
		_listener = null


func _start_polling() -> void:
	if not _polling:
		_polling = true
		(Engine.get_main_loop() as SceneTree).process_frame.connect(_poll)


func _poll() -> void:
	if _flow == "":
		_polling = false
		(Engine.get_main_loop() as SceneTree).process_frame.disconnect(_poll)
		return
	if Time.get_ticks_msec() - _began_msec > int(sign_in_timeout_s * 1000.0):
		_end_flow(false, TIMED_OUT)
		return
	if _listener == null:
		return
	while _listener.is_connection_available():
		_peers.append({"peer": _listener.take_connection(), "inbox": PackedByteArray()})
	for peer_state in _peers.duplicate():
		_read_peer(peer_state)
		if _listener == null:
			return


## Reads what a browser sent the listener; a whole request head is
## answered at once.
func _read_peer(peer_state: Dictionary) -> void:
	var peer: StreamPeerTCP = peer_state["peer"]
	peer.poll()
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_peers.erase(peer_state)
		return
	var available := peer.get_available_bytes()
	if available > 0:
		var got: Array = peer.get_partial_data(available)
		if got[0] == OK:
			peer_state["inbox"].append_array(got[1])
	var inbox: PackedByteArray = peer_state["inbox"]
	var text := inbox.get_string_from_ascii()
	var head_end := text.find("\r\n\r\n")
	if head_end < 0:
		if inbox.size() > MAX_CALLBACK_BYTES:
			_answer_browser(peer_state, 400, "Bad Request", "")
		return
	var request_line := text.substr(0, text.find("\r\n")).split(" ")
	if request_line.size() < 2 or request_line[0] != "GET":
		_answer_browser(peer_state, 405, "Method Not Allowed", "")
		return
	var target := request_line[1]
	var at_path := target.get_slice("?", 0)
	if at_path != "/callback":
		# A browser asks for more than the callback (a favicon, say).
		_answer_browser(peer_state, 404, "Not Found", "")
		return
	var query := _query_of(target)
	if query.get("state", "") != _expected_state:
		_answer_browser(peer_state, 400, "Bad Request", MISMATCH_PAGE)
		_end_flow(false, MISMATCH)
		return
	var code: String = query.get("code", "")
	if query.has("error") or code == "":
		_answer_browser(peer_state, 200, "OK", FAILED_PAGE)
		_end_flow(false, REFUSED)
		return
	_answer_browser(peer_state, 200, "OK", RETURN_PAGE)
	_close_listener()
	_exchange_code(code)


func _answer_browser(peer_state: Dictionary, status: int, reason: String, page: String) -> void:
	var peer: StreamPeerTCP = peer_state["peer"]
	var body := page.to_utf8_buffer()
	var head := "HTTP/1.1 %d %s\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n" % [status, reason, body.size()]
	peer.put_data(head.to_ascii_buffer() + body)
	peer.disconnect_from_host()
	_peers.erase(peer_state)


static func _query_of(target: String) -> Dictionary:
	var query := {}
	if not "?" in target:
		return query
	for pair in target.substr(target.find("?") + 1).split("&", false):
		var key := pair.get_slice("=", 0).uri_decode()
		query[key] = pair.substr(pair.find("=") + 1).uri_decode() if "=" in pair else ""
	return query


## Trades the one-time code for the hub's human token. No Origin header:
## the route refuses any request that carries one.
func _exchange_code(code: String) -> void:
	var body := JSON.stringify({"code": code, "code_verifier": _verifier, "redirect_uri": _redirect_uri})
	_sign_in_request = StationHttp.start(HTTPClient.METHOD_POST, _flow_hub + "/api/auth/token/exchange",
		PackedStringArray(["Content-Type: application/json", "Accept: application/json"]), body.to_utf8_buffer())
	_sign_in_request.finished.connect(_on_code_exchanged)
	_sign_in_request.network_failed.connect(_end_flow.bind(false, UNREACHABLE))


## The human token: first the device to revoke, if any, then (signing in)
## the new device. The token itself is dropped at the flow's end: it is the
## hub's alone (Superpipeline refuses its audience).
func _on_code_exchanged(status: int, _headers: Dictionary, body: PackedByteArray) -> void:
	_sign_in_request = null
	var answer = _answer_of(body) if status == 200 else null
	if not answer is Dictionary or not answer.get("token") is String or answer["token"] == "":
		_end_flow(false, REFUSED)
		return
	var human_token: String = answer["token"]
	if _revoking.is_empty():
		_make_device(human_token)
	elif str(_revoking["hub"]).rstrip("/") != _flow_hub:
		# Held for another hub: this hub's token is never sent there.
		_note = not_revoked(str(_revoking["name"]))
		_make_device(human_token)
	else:
		_revoke(human_token)


## Revokes `_revoking` with the human token. A 404 is not taken as
## revoked on its word: the caller's own list says (`_confirm_revoked`).
func _revoke(human_token: String) -> void:
	_sign_in_request = StationHttp.start(HTTPClient.METHOD_DELETE,
		_flow_hub + "/api/auth/devices/" + str(_revoking["id"]).uri_encode(),
		PackedStringArray(["Authorization: Bearer " + human_token, "Content-Length: 0"]))
	_sign_in_request.finished.connect(func(status: int, _headers: Dictionary, _body: PackedByteArray) -> void:
		_sign_in_request = null
		if status == 404:
			# The hub scopes a revoke to its caller: 404 is also what another
			# account's browser sign-in gets. Only the caller's own list says.
			_confirm_revoked(human_token)
		else:
			_revoked(human_token, status == 200))
	_sign_in_request.network_failed.connect(_end_flow.bind(false, UNREACHABLE))


## After a 404: whether the caller's own devices list `_revoking` as
## revoked (`revokedAt` set). Not listed, it belongs to another account.
func _confirm_revoked(human_token: String) -> void:
	_sign_in_request = StationHttp.start(HTTPClient.METHOD_GET, _flow_hub + "/api/auth/devices",
		PackedStringArray(["Authorization: Bearer " + human_token, "Accept: application/json"]))
	_sign_in_request.finished.connect(func(status: int, _headers: Dictionary, body: PackedByteArray) -> void:
		_sign_in_request = null
		var listed = _answer_of(body) if status == 200 else null
		var revoked := false
		if listed is Dictionary and listed.get("devices") is Array:
			for device in listed["devices"]:
				if device is Dictionary and device.get("id") is String and device["id"] == _revoking["id"]:
					revoked = device.get("revokedAt") is String and device["revokedAt"] != ""
		_revoked(human_token, revoked))
	_sign_in_request.network_failed.connect(_end_flow.bind(false, UNREACHABLE))


## The revoke's outcome: Disconnect ends on it; signing in names a device it
## could not revoke, and goes on to make the new one.
func _revoked(human_token: String, revoked: bool) -> void:
	if _flow == "disconnect":
		_end_flow(revoked, "")
		return
	if not revoked:
		_note = not_revoked(str(_revoking["name"]))
	_make_device(human_token)


func _make_device(human_token: String) -> void:
	if _flow != "sign_in":
		return
	var body_out := JSON.stringify({"name": device_name})
	_sign_in_request = StationHttp.start(HTTPClient.METHOD_POST, _flow_hub + "/api/auth/devices",
		PackedStringArray(["Authorization: Bearer " + human_token, "Content-Type: application/json",
			"Accept: application/json"]), body_out.to_utf8_buffer())
	_sign_in_request.finished.connect(_on_device_made)
	_sign_in_request.network_failed.connect(_end_flow.bind(false, UNREACHABLE))


func _on_device_made(status: int, _headers: Dictionary, body: PackedByteArray) -> void:
	_sign_in_request = null
	var made = _answer_of(body) if status == 201 or status == 200 else null
	if not made is Dictionary or not made.get("id") is String or not made.get("secret") is String \
			or made["id"] == "" or made["secret"] == "":
		_end_flow(false, NOT_REMEMBERED)
		return
	if not _store(_flow_hub, made["id"], made["secret"], device_name):
		# The hub has a device this computer cannot hold: name it.
		_end_flow(false, NOT_SAVED + " " + not_revoked(device_name), true)
		return
	_stored_hub = _flow_hub
	_stored_name = device_name
	device_id = made["id"]
	_secret = made["secret"]
	_refused = false
	_token = ""
	_token_expires_msec = 0
	_end_flow(true, "")


## Writes the credential so that it is never readable by anyone else, even
## for a moment: into a new file in a private directory (0700), made 0600
## there before its secret is written, then moved into place.
func _store(stored_hub: String, id: String, secret: String, name: String) -> bool:
	var private_dir := ProjectSettings.globalize_path(private_dir_of(path))
	# A directory that cannot be made (a file in its way) is a handled case
	# (NOT_SAVED), not an engine error to log.
	var was_printing := Engine.print_error_messages
	Engine.print_error_messages = false
	var made := DirAccess.make_dir_recursive_absolute(private_dir)
	Engine.print_error_messages = was_printing
	if made != OK:
		return false
	# A temporary file an earlier write left (it stopped, or Windows' rename,
	# which is not atomic, failed) holds a secret: it goes.
	for stale in DirAccess.get_files_at(private_dir):
		if stale.begins_with("credential.") and stale.ends_with(".tmp"):
			DirAccess.remove_absolute(private_dir.path_join(stale))
	var unix := has_unix_permissions()
	if unix and FileAccess.set_unix_permissions(private_dir, PRIVATE_DIR) != OK:
		return false
	var temporary := private_dir.path_join("credential.%s.tmp" % Crypto.new().generate_random_bytes(6).hex_encode())
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	if unix and FileAccess.set_unix_permissions(temporary, OWNER_ONLY) != OK:
		file.close()
		DirAccess.remove_absolute(temporary)
		return false
	file.store_string(JSON.stringify({"hub": stored_hub, "device_id": id, "secret": secret, "name": name}))
	file.close()
	if DirAccess.rename_absolute(temporary, ProjectSettings.globalize_path(path)) != OK:
		DirAccess.remove_absolute(temporary)
		return false
	return true


# ---- Tokens ----

## Calls `callback(token, error)` with a token good for a while yet, or
## with "" and an error kind (`signed_out`, `offline`, `failed`, or
## `no_address` for a hub that is neither `https://` nor on this computer,
## where the secret is never sent). A held token is given at once;
## otherwise the credential is exchanged, and everyone waiting shares that
## one exchange. `fresh` exchanges whatever is held, as after a 401.
func request_token(callback: Callable, fresh := false) -> void:
	if not is_signed_in():
		callback.call("", "signed_out")
		return
	if not StationHttp.is_secure_or_loopback(hub()):
		callback.call("", "no_address")
		return
	var left := _token_expires_msec - Time.get_ticks_msec()
	if not fresh and _token != "" and left > int(refresh_margin_s * 1000.0):
		callback.call(_token, "")
		return
	_token = ""
	_waiting.append(callback)
	if _exchange != null:
		return
	var url := hub() + "/api/auth/devices/token?client=" + client_id.uri_encode()
	_exchange = StationHttp.start(HTTPClient.METHOD_POST, url, PackedStringArray([
		"Authorization: Bearer %s:%s" % [device_id, _secret], "Accept: application/json", "Content-Length: 0"]))
	_exchange.finished.connect(_on_token_exchanged)
	_exchange.network_failed.connect(_on_token_unreachable)


## The hub refused a fresh token twice in a row: signed out. The file stays,
## so Disconnect can still revoke it; signing in again replaces it.
func refuse() -> void:
	if _refused:
		return
	_refused = true
	_token = ""
	signed_out.emit()


func _on_token_exchanged(status: int, _headers: Dictionary, body: PackedByteArray) -> void:
	_exchange = null
	if status == 401:
		# Unknown, revoked or expired: the credential is dead, so it goes.
		_forget()
		_refused = true
		_answer_waiting("", "signed_out")
		signed_out.emit()
		return
	var answer = _answer_of(body) if status == 200 else null
	if not answer is Dictionary or not answer.get("token") is String or answer["token"] == "":
		_answer_waiting("", "failed")
		return
	var lifetime_s: int = answer["expiresIn"] if answer.get("expiresIn") is int else 300
	_token = answer["token"]
	_token_expires_msec = Time.get_ticks_msec() + lifetime_s * 1000
	_answer_waiting(_token, "")


func _on_token_unreachable() -> void:
	_exchange = null
	_answer_waiting("", "offline")


func _answer_waiting(token: String, error: String) -> void:
	var waiting := _waiting
	_waiting = []
	for callback in waiting:
		# A stream let go of while it waited is gone; its answer goes nowhere.
		if callback.is_valid():
			callback.call(token, error)


# ---- Disconnecting ----

## Forgets the credential at once, then revokes its device with a human
## token from a browser sign-in (the hub refuses the device's own token for
## that). Ends with `disconnect_finished`; a cancelled, refused, timed-out
## or unreachable sign-in leaves the device not revoked, and says so. A
## refused credential still has a device, so it is revoked too.
func disconnect_device() -> void:
	if _flow == "disconnect":
		return
	if _flow == "sign_in":
		cancel_browser()
	var held := _held()
	_forget()
	_refused = false
	if held.is_empty():
		(Engine.get_main_loop() as SceneTree).process_frame.connect(disconnect_finished.emit.bind(true, ""),
			CONNECT_ONE_SHOT)
		return
	_revoking = held
	_begin_flow("disconnect", str(held["hub"]).rstrip("/"))


## Deletes the file and drops everything held.
func _forget() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	device_id = ""
	_secret = ""
	_stored_hub = ""
	_stored_name = ""
	_token = ""
	_token_expires_msec = 0
