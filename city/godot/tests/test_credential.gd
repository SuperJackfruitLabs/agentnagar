## Signing in to AgentPod as `apn fleet login` does (protocol reference
## §1.3 to §1.5, and Part B's Task 8): the loopback PKCE flow against the
## fake hub with a scripted browser, the device credential and its
## owner-only file, five-minute tokens refreshed before they expire, being
## signed out, and Disconnect. Nothing here reaches a real hub: the fake
## listens on 127.0.0.1, on ephemeral ports.
extends TestSuite

const FakeHub := preload("res://tests/fake_hub/fake_hub.gd")
const CREDENTIAL_FILE := "user://test_credential.json"
const DEVICE_NAME := "Agentnagar on test-box"

## What the scripted browser was shown by the loopback listener, last first.
var pages: Array = []


func fake_hub() -> Variant:
	var hub = FakeHub.new()
	hub.report = runner.fail
	hub.start()
	return hub


## A credential for `hub`'s hub with no stored file, on a desktop, whose
## browser is the scripted one (`tamper` may rewrite the callback URL).
func fresh_credential(hub, tamper := Callable()) -> StationCredential:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CREDENTIAL_FILE))
	var credential := StationCredential.new(hub.hub_url, "agentnagar", CREDENTIAL_FILE)
	credential.platform = "desktop"
	credential.device_name = DEVICE_NAME
	credential.open_browser = func(url: String) -> void: browse(url, tamper)
	return credential


## The scripted browser: asks the hub's authorize page, follows its
## redirect to the loopback callback, and keeps the page it gets.
func browse(url: String, tamper := Callable()) -> void:
	var first := await fetch(HTTPClient.METHOD_GET, url)
	var location: String = first["headers"].get("location", "")
	if location == "":
		return
	if tamper.is_valid():
		location = tamper.call(location)
	pages.push_front(await fetch(HTTPClient.METHOD_GET, location))


## One request through StationHttp, awaited: {status, headers, body},
## with status 0 when nothing answered.
func fetch(method: int, url: String, headers := PackedStringArray(), body := PackedByteArray()) -> Dictionary:
	var request := StationHttp.start(method, url, headers, body)
	var done := {}
	request.finished.connect(func(status: int, response_headers: Dictionary, response: PackedByteArray) -> void:
		done.merge({"status": status, "headers": response_headers, "body": response.get_string_from_utf8()}))
	request.network_failed.connect(func() -> void: done.merge({"status": 0, "headers": {}, "body": ""}))
	while done.is_empty():
		await runner.process_frame
	return done


## Waits, a frame at a time, until `done` holds or `most_s` pass.
func until(done: Callable, most_s := 5.0) -> bool:
	var began := Time.get_ticks_msec()
	while not done.call():
		if Time.get_ticks_msec() - began > int(most_s * 1000.0):
			return false
		await runner.process_frame
	return true


## Signs in and waits for the outcome: [ok, message].
func sign_in(credential: StationCredential, most_s := 10.0) -> Array:
	var outcome := []
	credential.sign_in_finished.connect(func(ok: bool, message: String) -> void: outcome.append_array([ok, message]),
		CONNECT_ONE_SHOT)
	credential.sign_in()
	await until(func() -> bool: return not outcome.is_empty(), most_s)
	return outcome


## A token from the credential, awaited: [token, error].
func token_of(credential: StationCredential, fresh := false) -> Array:
	var got := []
	credential.request_token(func(token: String, error: String) -> void: got.append_array([token, error]), fresh)
	await until(func() -> bool: return not got.is_empty())
	return got


func stored() -> Variant:
	return StationSource.parse_json(FileAccess.get_file_as_string(CREDENTIAL_FILE))


func done_with(hub) -> void:
	hub.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CREDENTIAL_FILE))


## Whether anything still listens at `url` (the loopback callback).
func listening(url: String) -> bool:
	return (await fetch(HTTPClient.METHOD_GET, url))["status"] != 0


# ---- Signing in ----

## The whole flow: authorize with PKCE, the loopback callback, the code
## traded for a token with no Origin header, a device made with it, and
## the device stored; the listener then closes.
func test_signing_in_runs_the_loopback_pkce_flow_and_stores_a_device() -> void:
	var hub = fake_hub()
	pages.clear()
	var credential := fresh_credential(hub)
	assert_true(not credential.is_signed_in(), "not signed in before")
	var outcome := await sign_in(credential)
	assert_eq(outcome, [true, ""], "signed in")
	var authorize: Array = hub.requests_to("GET /api/auth/authorize")
	assert_eq(authorize.size(), 1, "the browser opened the authorize page once")
	var query: Dictionary = authorize[0]["query"]
	assert_eq(query.get("client"), "agentnagar", "as the city's own client, under the key `client`")
	assert_eq(query.get("response_type"), "code", "for a code")
	assert_eq(query.get("code_challenge_method"), "S256", "S256")
	assert_eq(str(query.get("code_challenge")).length(), 43, "a 43-character challenge")
	assert_true(str(query.get("state")).length() >= 32, "a random state")
	var redirect: String = query.get("redirect_uri", "")
	assert_true(redirect.begins_with("http://127.0.0.1:") and redirect.ends_with("/callback"), "a loopback redirect: %s" % redirect)
	assert_true(not pages.is_empty() and pages[0]["status"] == 200 and "You can return to Agentnagar" in pages[0]["body"],
		"the browser is told to go back")
	var exchange: Array = hub.requests_to("POST /api/auth/token/exchange")
	assert_eq(exchange.size(), 1, "the code was exchanged once")
	assert_true(not exchange[0]["headers"].has("origin"), "with no Origin header")
	var sent = StationSource.parse_json(exchange[0]["body"].get_string_from_utf8())
	assert_eq(sent.keys(), ["code", "code_verifier", "redirect_uri"], "code, verifier and redirect")
	assert_eq(sent["redirect_uri"], redirect, "the same redirect")
	assert_eq(StationCredential.challenge_for(sent["code_verifier"]), query["code_challenge"], "the verifier answers the challenge")
	assert_eq(str(sent["code_verifier"]).length(), 64, "48 random bytes in base64url")
	var made: Array = hub.requests_to("POST /api/auth/devices")
	assert_eq(made.size(), 1, "a device was made")
	assert_eq(StationSource.parse_json(made[0]["body"].get_string_from_utf8()), {"name": DEVICE_NAME}, "named for this computer")
	var bearer: String = made[0]["headers"].get("authorization", "")
	assert_eq(hub.tokens.get(bearer.trim_prefix("Bearer "), {}).get("kind"), "sign_in", "with the sign-in's token")
	var device_id: String = hub.devices.keys()[0]
	assert_eq(stored(), {"hub": hub.hub_url, "device_id": device_id, "secret": hub.devices[device_id]["secret"],
		"name": DEVICE_NAME}, "the hub, the device, its secret and its name are stored, and nothing else")
	assert_true(credential.is_signed_in() and credential.device_id == device_id, "signed in as that device")
	assert_true(not await listening(redirect), "the listener closed")
	# A credential read back from the file is signed in too.
	assert_true(StationCredential.new(hub.hub_url, "agentnagar", CREDENTIAL_FILE).is_signed_in(), "the file signs in")
	assert_true(not StationCredential.new("http://127.0.0.1:1", "agentnagar", CREDENTIAL_FILE).is_signed_in(),
		"but not for another hub")
	assert_eq(hub.violations, [], "the fake saw nothing it does not know")
	done_with(hub)


## A callback whose state is not the one sent is refused: the code is
## never exchanged and nothing is stored.
func test_a_state_that_does_not_match_is_refused() -> void:
	var hub = fake_hub()
	pages.clear()
	var credential := fresh_credential(hub, func(location: String) -> String:
		var state := location.get_slice("state=", 1)
		return location.replace("state=" + state, "state=forged"))
	var outcome := await sign_in(credential)
	assert_eq(outcome, [false, StationCredential.MISMATCH], "refused")
	assert_eq(hub.requests_to("POST /api/auth/token/exchange").size(), 0, "the code was not exchanged")
	assert_true(not pages.is_empty() and pages[0]["status"] == 400 and not "You can return" in pages[0]["body"],
		"the browser is told it did not start here")
	assert_true(not FileAccess.file_exists(CREDENTIAL_FILE), "nothing stored")
	assert_true(not credential.is_signed_in(), "not signed in")
	var redirect: String = hub.requests_to("GET /api/auth/authorize")[0]["query"]["redirect_uri"]
	assert_true(not await listening(redirect), "the listener closed")
	done_with(hub)


## The credential file is readable by its owner only, even where an old one
## was not.
func test_the_credential_file_is_owner_only() -> void:
	var hub = fake_hub()
	var credential := fresh_credential(hub)
	var old := FileAccess.open(CREDENTIAL_FILE, FileAccess.WRITE)
	old.store_string("{}")
	old.close()
	FileAccess.set_unix_permissions(CREDENTIAL_FILE, 0x1A4)
	# A temporary file left by a write that never finished (a crash, or
	# Windows' rename, which is not atomic) is cleared by the next.
	var private_dir := StationCredential.private_dir_of(CREDENTIAL_FILE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(private_dir))
	var stale := FileAccess.open(private_dir.path_join("credential.0badc0ffee.tmp"), FileAccess.WRITE)
	stale.store_string("{\"secret\": \"left behind\"}")
	stale.close()
	var outcome := await sign_in(credential)
	assert_eq(outcome, [true, ""], "signed in")
	if StationCredential.has_unix_permissions():
		assert_eq(FileAccess.get_unix_permissions(CREDENTIAL_FILE), StationCredential.OWNER_ONLY, "0600")
		assert_eq(StationCredential.OWNER_ONLY, 0x180, "which is 0600")
		# It was written in a private directory (0700) and moved into place,
		# so it was never readable by anyone else, even for a moment.
		var private := StationCredential.private_dir_of(CREDENTIAL_FILE)
		assert_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(private)), "the private directory exists")
		assert_eq(FileAccess.get_unix_permissions(private), StationCredential.PRIVATE_DIR, "0700")
		assert_eq(StationCredential.PRIVATE_DIR, 0x1C0, "which is 0700")
		assert_eq(Array(DirAccess.get_files_at(private)), [], "and nothing is left in it")
		var keys: Array = StationSource.parse_json(FileAccess.get_file_as_string(CREDENTIAL_FILE)).keys()
		keys.sort()
		assert_eq(keys, ["device_id", "hub", "name", "secret"], "the file holds the credential")
	else:
		assert_true(FileAccess.file_exists(CREDENTIAL_FILE), "stored (no Unix permissions here)")
	done_with(hub)


## The hub refusing the code, a refused device, and a hub that is not set
## each end the sign-in with their own line.
func test_a_refused_code_or_device_ends_the_sign_in() -> void:
	var hub = fake_hub()
	var credential := fresh_credential(hub)
	hub.answer_with("hub", "POST /api/auth/token/exchange", 400, {"error": "invalid_grant", "error_description": "used"})
	assert_eq(await sign_in(credential), [false, StationCredential.REFUSED], "a refused code")
	credential = fresh_credential(hub)
	hub.answer_with("hub", "POST /api/auth/devices", 403, {"error": "Forbidden"})
	assert_eq(await sign_in(credential), [false, StationCredential.NOT_REMEMBERED], "a refused device")
	assert_true(not FileAccess.file_exists(CREDENTIAL_FILE), "nothing stored")
	credential = fresh_credential(hub)
	credential.hub_url = ""
	assert_eq(await sign_in(credential), [false, StationCredential.NO_HUB], "no hub set")
	done_with(hub)


## Sign-in needs a desktop: on the web and phones it says so and opens no
## listener at all.
func test_sign_in_needs_the_desktop_app() -> void:
	var hub = fake_hub()
	for platform in ["web", "mobile"]:
		var credential := fresh_credential(hub)
		credential.platform = platform
		var before := StationSource.network_objects_created
		assert_eq(await sign_in(credential), [false, StationCredential.DESKTOP_ONLY], platform + " says so")
		assert_eq(StationSource.network_objects_created, before, platform + " makes nothing that could connect")
	assert_eq(hub.requests, [], "the hub heard nothing")
	done_with(hub)


## The whole sign-in times out, and cancelling closes the listener.
func test_signing_in_times_out_and_cancelling_closes_the_listener() -> void:
	var hub = fake_hub()
	var credential := fresh_credential(hub)
	var opened := []
	credential.open_browser = func(url: String) -> void: opened.append(url)
	credential.sign_in_timeout_s = 0.3
	assert_eq(await sign_in(credential), [false, StationCredential.TIMED_OUT], "timed out")
	var redirect: String = StationCredential._query_of(opened[0])["redirect_uri"]
	assert_true(not await listening(redirect), "the listener closed")
	assert_eq(StationCredential.SIGN_IN_TIMEOUT_S, 300.0, "five minutes, by default")

	credential.sign_in_timeout_s = StationCredential.SIGN_IN_TIMEOUT_S
	var outcome := []
	credential.sign_in_finished.connect(func(ok: bool, message: String) -> void: outcome.append_array([ok, message]),
		CONNECT_ONE_SHOT)
	credential.sign_in()
	redirect = StationCredential._query_of(opened[1])["redirect_uri"]
	assert_true(credential.is_signing_in(), "signing in")
	credential.cancel_sign_in()
	await until(func() -> bool: return not outcome.is_empty())
	assert_eq(outcome, [false, StationCredential.CANCELLED], "cancelled")
	assert_true(not await listening(redirect), "the listener closed")
	done_with(hub)


# ---- Tokens ----

## A token is exchanged for with the device's `id:secret` and the city's
## client, kept in memory and reused, and exchanged again when 30 s (here
## scaled down) are left, before it expires.
func test_tokens_are_kept_and_exchanged_again_before_they_expire() -> void:
	var hub = fake_hub()
	var credential := fresh_credential(hub)
	await sign_in(credential)
	assert_eq(StationCredential.REFRESH_MARGIN_S, 30.0, "30 s before expiry, by default")
	var first := await token_of(credential)
	assert_eq(first[1], "", "a token")
	var exchanges: Array = hub.requests_to("POST /api/auth/devices/token")
	assert_eq(exchanges.size(), 1, "one exchange")
	assert_eq(exchanges[0]["query"], {"client": "agentnagar"}, "as the city's client")
	var device_id := credential.device_id
	assert_eq(exchanges[0]["headers"]["authorization"], "Bearer %s:%s" % [device_id, hub.devices[device_id]["secret"]],
		"with the device's id:secret")
	assert_eq(hub.tokens[first[0]]["kind"], "device", "a device token")
	assert_eq((await token_of(credential))[0], first[0], "reused while fresh")
	assert_eq(hub.requests_to("POST /api/auth/devices/token").size(), 1, "no second exchange")
	assert_true(not FileAccess.get_file_as_string(CREDENTIAL_FILE).contains(first[0]), "the token is never stored")

	# A 2 s token, exchanged again with 1 s left.
	hub.token_lifetime_s = 2
	credential.refresh_margin_s = 1.0
	var second := await token_of(credential, true)
	await until(func() -> bool: return false, 1.2)
	var third := await token_of(credential)
	assert_true(third[0] != second[0], "a new token once the margin is reached")
	assert_true(Time.get_ticks_msec() < hub.tokens[second[0]]["expires_msec"], "before the old one expired")
	done_with(hub)


## Several callers waiting at once share one exchange.
func test_callers_share_one_exchange() -> void:
	var hub = fake_hub()
	var credential := fresh_credential(hub)
	await sign_in(credential)
	var got := []
	for i in 3:
		credential.request_token(func(token: String, _error: String) -> void: got.append(token))
	await until(func() -> bool: return got.size() == 3)
	assert_eq(hub.requests_to("POST /api/auth/devices/token").size(), 1, "one exchange")
	assert_true(got[0] != "" and got[0] == got[1] and got[1] == got[2], "the same token for all")
	done_with(hub)


## A device the hub no longer knows (revoked elsewhere) signs the player
## out, and its dead credential is forgotten.
func test_a_refused_device_signs_out_and_is_forgotten() -> void:
	var hub = fake_hub()
	var credential := fresh_credential(hub)
	await sign_in(credential)
	var signed_out := []
	credential.signed_out.connect(func() -> void: signed_out.append(true))
	hub.devices[credential.device_id]["revoked"] = true
	assert_eq(await token_of(credential), ["", "signed_out"], "no token")
	assert_eq(signed_out, [true], "signed out")
	assert_true(not credential.is_signed_in(), "not signed in")
	assert_true(not FileAccess.file_exists(CREDENTIAL_FILE), "the dead credential is gone")
	assert_eq(await token_of(credential), ["", "signed_out"], "and stays signed out")
	assert_eq(hub.requests_to("POST /api/auth/devices/token").size(), 1, "without asking again")
	done_with(hub)


## A hub that cannot be reached gives no token, as `offline`, and signs
## nobody out.
func test_an_unreachable_hub_is_offline() -> void:
	var hub = fake_hub()
	var credential := fresh_credential(hub)
	await sign_in(credential)
	hub.stop()
	assert_eq(await token_of(credential), ["", "offline"], "offline")
	assert_true(credential.is_signed_in(), "still signed in")
	done_with(hub)


# ---- Disconnect ----

## Disconnect, awaited: [revoked, message].
func disconnect_of(credential: StationCredential, most_s := 10.0) -> Array:
	var outcome := []
	credential.disconnect_finished.connect(func(revoked: bool, message: String) -> void:
		outcome.append_array([revoked, message]), CONNECT_ONE_SHOT)
	credential.disconnect_device()
	await until(func() -> bool: return not outcome.is_empty(), most_s)
	return outcome


## The hub will not let a device token revoke a device or mint another
## (its `resolveCaller` refuses `amr: ["device"]`), and the fake agrees.
func test_a_device_token_can_neither_revoke_nor_mint() -> void:
	var hub = fake_hub()
	var credential := fresh_credential(hub)
	await sign_in(credential)
	var token: String = (await token_of(credential))[0]
	var bearer := PackedStringArray(["Authorization: Bearer " + token, "Content-Type: application/json"])
	var revoke := await fetch(HTTPClient.METHOD_DELETE, hub.hub_url + "/api/auth/devices/" + credential.device_id, bearer)
	assert_eq([revoke["status"], StationSource.parse_json(revoke["body"])], [401, {"error": "unauthorized"}], "no revoking")
	var mint := await fetch(HTTPClient.METHOD_POST, hub.hub_url + "/api/auth/devices", bearer,
		JSON.stringify({"name": "another"}).to_utf8_buffer())
	assert_eq([mint["status"], StationSource.parse_json(mint["body"])], [401, {"error": "unauthorized"}], "no minting")
	assert_true(not hub.devices[credential.device_id]["revoked"], "the device is still live")
	done_with(hub)


## Disconnect forgets the credential at once, then revokes the device with
## a human token from a browser sign-in (authorize and the code exchange,
## no device made), and says "Revoked".
func test_disconnect_forgets_at_once_and_revokes_through_the_browser() -> void:
	var hub = fake_hub()
	var credential := fresh_credential(hub)
	await sign_in(credential)
	var device_id := credential.device_id
	var outcome := []
	credential.disconnect_finished.connect(func(revoked: bool, message: String) -> void:
		outcome.append_array([revoked, message]), CONNECT_ONE_SHOT)
	credential.disconnect_device()
	assert_true(not FileAccess.file_exists(CREDENTIAL_FILE), "the file is gone at once")
	assert_true(not credential.is_signed_in() and credential.device_id == "", "and the credential forgotten")
	assert_true(credential.is_disconnecting(), "while the browser revokes it")
	await until(func() -> bool: return not outcome.is_empty(), 10.0)
	assert_eq(outcome, [true, StationCredential.REVOKED], "revoked")
	assert_true(hub.devices[device_id]["revoked"], "the hub revoked it")
	var revoke: Array = hub.requests_to("DELETE /api/auth/devices/:id")
	assert_eq(revoke.size(), 1, "revoked once")
	assert_eq(revoke[0]["path"], "/api/auth/devices/" + device_id, "this device")
	var bearer: String = revoke[0]["headers"].get("authorization", "").trim_prefix("Bearer ")
	assert_eq(hub.tokens.get(bearer, {}).get("kind"), "sign_in", "with a human token from the browser")
	assert_eq(hub.requests_to("GET /api/auth/authorize").size(), 2, "a second browser sign-in")
	assert_eq(hub.requests_to("POST /api/auth/devices").size(), 1, "which made no device")
	assert_true(not pages.is_empty() and "You can return to Agentnagar" in pages[0]["body"], "the browser is sent back")
	assert_true(not credential.is_disconnecting(), "done")
	done_with(hub)


## A browser that never comes back, a refused sign-in, a timeout and a hub
## that will not revoke all leave the device not revoked, said so with its
## name and the console; the file is gone all the same.
func test_a_disconnect_that_cannot_revoke_says_so_and_still_forgets() -> void:
	var hub = fake_hub()
	var not_revoked := StationCredential.not_revoked(DEVICE_NAME)
	assert_true(not_revoked.contains("Not revoked") and not_revoked.contains("'Agentnagar on test-box'")
		and not_revoked.contains("AgentPod console"), "the line names the device and the console: " + not_revoked)

	var credential := fresh_credential(hub)
	await sign_in(credential)
	var device_id := credential.device_id
	credential.open_browser = func(_url: String) -> void: pass
	var outcome := []
	credential.disconnect_finished.connect(func(revoked: bool, message: String) -> void:
		outcome.append_array([revoked, message]), CONNECT_ONE_SHOT)
	credential.disconnect_device()
	await until(func() -> bool: return credential.is_disconnecting())
	credential.cancel_browser()
	await until(func() -> bool: return not outcome.is_empty())
	assert_eq(outcome, [false, not_revoked], "cancelled: not revoked")
	assert_true(not FileAccess.file_exists(CREDENTIAL_FILE), "the file is gone")
	assert_true(not hub.devices[device_id]["revoked"], "the device is still live on the hub")

	credential = fresh_credential(hub, func(location: String) -> String:
		return location.get_slice("?", 0) + "?error=access_denied&state=" + location.get_slice("state=", 1))
	await sign_in(fresh_credential(hub))
	credential.load_file()
	pages.clear()
	assert_eq(await disconnect_of(credential), [false, not_revoked], "the browser refused: not revoked")
	assert_true(not pages.is_empty() and pages[0]["body"].contains("did not finish") and not pages[0]["body"].contains("You can return"),
		"the browser page says the sign-in did not finish")

	credential = fresh_credential(hub)
	await sign_in(credential)
	credential.open_browser = func(_url: String) -> void: pass
	credential.sign_in_timeout_s = 0.3
	assert_eq(await disconnect_of(credential), [false, not_revoked], "timed out: not revoked")

	credential = fresh_credential(hub)
	await sign_in(credential)
	hub.answer_with("hub", "DELETE /api/auth/devices/:id", 500, {"error": "internal"})
	assert_eq(await disconnect_of(credential), [false, not_revoked], "the hub would not revoke: not revoked")
	assert_true(not FileAccess.file_exists(CREDENTIAL_FILE), "the file is gone")
	done_with(hub)


## A credential the hub refused (two 401s in a row) is still revoked on
## Disconnect: the device is held, so it is revoked.
func test_disconnect_after_a_refusal_still_revokes() -> void:
	var hub = fake_hub()
	var credential := fresh_credential(hub)
	await sign_in(credential)
	var device_id := credential.device_id
	credential.refuse()
	assert_true(not credential.is_signed_in(), "signed out")
	assert_eq(await disconnect_of(credential), [true, StationCredential.REVOKED], "revoked all the same")
	assert_true(hub.devices[device_id]["revoked"], "on the hub")
	assert_true(not FileAccess.file_exists(CREDENTIAL_FILE), "and forgotten")
	done_with(hub)


## The hub scopes a revoke to its caller: a browser signed in as another
## account gets 404 for this device. So a 404 is "Revoked." only when the
## caller's own device list shows it revoked; otherwise the device is named
## as not revoked.
func test_a_404_on_the_revoke_is_revoked_only_when_the_list_says_so() -> void:
	var hub = fake_hub()
	var credential := fresh_credential(hub)
	await sign_in(credential)
	var device_id := credential.device_id
	hub.browser_user = "usr_someone_else"
	assert_eq(await disconnect_of(credential), [false, StationCredential.not_revoked(DEVICE_NAME)],
		"another account: not revoked")
	assert_true(not hub.devices[device_id]["revoked"], "the device is still live")
	assert_eq(hub.requests_to("DELETE /api/auth/devices/:id").size(), 1, "the revoke was tried")
	var listing: Array = hub.requests_to("GET /api/auth/devices")
	assert_eq(listing.size(), 1, "then the caller's devices were read")
	assert_eq(listing[0]["headers"]["authorization"], hub.requests_to("DELETE /api/auth/devices/:id")[0]["headers"]["authorization"],
		"with the same human token")

	hub.browser_user = "usr_player"
	credential = fresh_credential(hub)
	await sign_in(credential)
	device_id = credential.device_id
	hub.devices[device_id]["revoked"] = true
	hub.devices[device_id]["revokedAt"] = "2026-09-29T10:00:00.000Z"
	assert_eq(await disconnect_of(credential), [true, StationCredential.REVOKED],
		"already revoked by its own account: the list says so")
	done_with(hub)


## The hub's answers are read with care: a body that is not UTF-8 (a
## proxy's, say) is refused as unreadable, never decoded (Godot logs an
## error decoding one), and a listed device's id that is not a string is
## not the device revoked.
func test_answers_that_are_not_utf8_or_not_strings_are_refused_quietly() -> void:
	var hub = fake_hub()
	# JSON whose strings hold bytes that are not UTF-8: decoded anyway,
	# each would read as a replacement character, and pass for a value.
	var not_utf8 := func(json: String) -> PackedByteArray:
		var bytes := json.to_utf8_buffer()
		var at := bytes.find(0x40)
		bytes[at] = 0xff
		return bytes
	var credential := fresh_credential(hub)
	hub.answer_with("hub", "POST /api/auth/token/exchange", 200, not_utf8.call("{\"token\":\"tok@\"}"))
	assert_eq(await sign_in(credential), [false, StationCredential.REFUSED], "a code exchange not UTF-8: refused")
	hub.answer_with("hub", "POST /api/auth/devices", 201, not_utf8.call("{\"id\":\"dev@\",\"secret\":\"sec\"}"))
	assert_eq(await sign_in(credential), [false, StationCredential.NOT_REMEMBERED], "a device not UTF-8: not remembered")
	assert_true(not FileAccess.file_exists(CREDENTIAL_FILE), "and not stored")
	assert_eq(await sign_in(credential), [true, ""], "signed in")
	hub.answer_with("hub", "POST /api/auth/devices/token", 200, not_utf8.call("{\"token\":\"tok@\",\"expiresIn\":300}"))
	assert_eq(await token_of(credential), ["", "failed"], "a token not UTF-8: failed")
	var device_id := credential.device_id
	var id_not_utf8: PackedByteArray = not_utf8.call("{\"devices\":[{\"id\":\"%s\",\"revokedAt\":\"@\"}]}" % device_id)
	for listing in [id_not_utf8, {"devices": [{"id": 7, "revokedAt": "2026-09-29T10:00:00.000Z"}]}]:
		hub.answer_with("hub", "DELETE /api/auth/devices/:id", 404, {"error": "no such live device"})
		hub.answer_with("hub", "GET /api/auth/devices", 200, listing)
		assert_eq(await disconnect_of(credential), [false, StationCredential.not_revoked(DEVICE_NAME)],
			"a listing %s: not revoked" % ("not UTF-8" if listing is PackedByteArray else "whose id is a number"))
		assert_true(not hub.devices[device_id]["revoked"], "the device is still live")
		credential = fresh_credential(hub)
		assert_eq(await sign_in(credential), [true, ""], "signed in again")
		device_id = credential.device_id
	done_with(hub)


## Signing in again as another account cannot revoke the old device: it
## is named, and the new one is made.
func test_signing_in_again_as_another_account_names_the_old_device() -> void:
	var hub = fake_hub()
	var credential := fresh_credential(hub)
	await sign_in(credential)
	var old_id := credential.device_id
	hub.browser_user = "usr_someone_else"
	assert_eq(await sign_in(credential), [true, StationCredential.not_revoked(DEVICE_NAME)], "signed in, the old device named")
	assert_true(not hub.devices[old_id]["revoked"], "the old device is still live")
	assert_true(credential.device_id != old_id and credential.is_signed_in(), "the new one held")
	done_with(hub)


## A device made but not stored (the file cannot be written) is named, so
## the player can revoke it in the console.
func test_a_device_made_but_not_stored_is_named() -> void:
	var hub = fake_hub()
	var blocker := "user://test_credential_blocker"
	var file := FileAccess.open(blocker, FileAccess.WRITE)
	file.store_string("a file where a directory should be")
	file.close()
	var credential := fresh_credential(hub)
	credential.path = blocker.path_join("credential.json")
	var outcome := await sign_in(credential)
	assert_eq(outcome, [false, StationCredential.NOT_SAVED + " " + StationCredential.not_revoked(DEVICE_NAME)],
		"not saved, and the device it made named")
	assert_true(credential.console_hint, "with the console offered")
	assert_eq(hub.devices.size(), 1, "the device was made")
	assert_true(not credential.is_signed_in(), "but is not held")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker))
	done_with(hub)


## Disconnect with nothing held revokes nothing and opens no browser.
func test_disconnect_with_nothing_held_does_nothing() -> void:
	var hub = fake_hub()
	var credential := fresh_credential(hub)
	assert_eq(await disconnect_of(credential), [true, ""], "nothing to revoke")
	assert_eq(hub.requests, [], "the hub heard nothing")
	done_with(hub)


## Signing in again revokes the device held before, with the new sign-in's
## human token, before making the new one; a device held for another hub
## is not sent that hub's token, and is named as not revoked.
func test_signing_in_again_revokes_the_old_device_first() -> void:
	var hub = fake_hub()
	var credential := fresh_credential(hub)
	await sign_in(credential)
	var old_id := credential.device_id
	credential.refuse()
	assert_eq(await sign_in(credential), [true, ""], "signed in again")
	assert_true(credential.device_id != old_id, "as a new device")
	assert_true(hub.devices[old_id]["revoked"], "the old one revoked")
	var order: Array = hub.requests.filter(func(r): return r["route"] in ["DELETE /api/auth/devices/:id", "POST /api/auth/devices"]).map(
		func(r): return r["route"])
	assert_eq(order, ["POST /api/auth/devices", "DELETE /api/auth/devices/:id", "POST /api/auth/devices"],
		"revoked before the new one was made")
	var bearer: String = hub.requests_to("DELETE /api/auth/devices/:id")[0]["headers"]["authorization"].trim_prefix("Bearer ")
	assert_eq(hub.tokens[bearer]["kind"], "sign_in", "with the new sign-in's human token")

	var other = fake_hub()
	var moved := StationCredential.new(other.hub_url, "agentnagar", CREDENTIAL_FILE)
	moved.platform = "desktop"
	moved.device_name = DEVICE_NAME
	moved.open_browser = func(url: String) -> void: browse(url)
	var held := moved.device_id
	assert_true(held != "" and not moved.is_signed_in(), "a device held for the first hub")
	assert_eq(await sign_in(moved), [true, StationCredential.not_revoked(DEVICE_NAME)], "signed in, the old device named")
	assert_eq(hub.requests_to("DELETE /api/auth/devices/:id").size(), 1, "the first hub was sent nothing new")
	assert_eq(other.requests_to("DELETE /api/auth/devices/:id").size(), 0, "nor the second asked to revoke it")
	assert_true(not hub.devices[held]["revoked"], "so it is still live there")
	other.stop()
	done_with(hub)


## The PKCE helpers: base64url without padding, and the RFC 7636 example.
func test_base64url_and_the_s256_challenge() -> void:
	assert_eq(StationCredential.base64url(PackedByteArray([0xfb, 0xff, 0xfe])), "-__-", "- and _, no padding")
	assert_eq(StationCredential.challenge_for("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
		"E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", "RFC 7636, appendix B")
