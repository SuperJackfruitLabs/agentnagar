## The live station's REST calls (Part B's Task 8): `LiveSource` against
## the fake hub, speaking AgentPod's and Superpipeline's recorded routes.
## Every call's request and parsed answer; every error mapping, 502 offline
## against 409 offline among them; the log tail's Server-Sent Events; the
## chat's session found over REST; tokens refreshed before they expire;
## and the redaction rule. Nothing here reaches a real hub.
extends TestSuite

const FakeHub := preload("res://tests/fake_hub/fake_hub.gd")
const CREDENTIAL_FILE := "user://test_live_rest_credential.json"
const STATION := "stn_build"
const BOARD := "brd_build"


func fake_hub() -> Variant:
	var hub = FakeHub.new()
	hub.report = runner.fail
	hub.start()
	return hub


## A credential for a device the fake already knows, as a finished sign-in
## leaves one.
func credential_for(hub) -> StationCredential:
	var id: String = hub.serial("dev_")
	hub.devices[id] = {"secret": hub.serial("sec_"), "name": "Agentnagar on test-box", "revoked": false}
	var file := FileAccess.open(CREDENTIAL_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"hub": hub.hub_url, "device_id": id, "secret": hub.devices[id]["secret"]}))
	file.close()
	return StationCredential.new(hub.hub_url, "agentnagar", CREDENTIAL_FILE)


## A live source whose reconnections wait a frame, not their backoff.
func live(hub) -> LiveSource:
	var source := LiveSource.new(credential_for(hub), hub.hub_url, hub.superpipeline_url)
	source.wait = func(_seconds: float, then: Callable) -> void:
		LiveSource.later(func() -> void:
			if then.is_valid():
				then.call())
	return source


## The answer to `call_id`, awaited: [ok, body, status].
func answer_of(source: StationSource, call_id: int) -> Array:
	var got := []
	var on_result := func(id: int, ok: bool, body: Variant, status: int) -> void:
		if id == call_id:
			got.append_array([ok, body, status])
	source.result.connect(on_result)
	await until(func() -> bool: return not got.is_empty())
	source.result.disconnect(on_result)
	return got


func until(done: Callable, most_s := 5.0) -> bool:
	var began := Time.get_ticks_msec()
	while not done.call():
		if Time.get_ticks_msec() - began > int(most_s * 1000.0):
			return false
		await runner.process_frame
	return true


func done_with(hub) -> void:
	assert_eq(hub.violations, [], "the fake saw nothing it does not know")
	hub.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CREDENTIAL_FILE))


## The body the client sent on the last request to `route`.
func sent_body(hub, route: String) -> Variant:
	var requests: Array = hub.requests_to(route)
	return StationSource.parse_json(requests.back()["body"].get_string_from_utf8()) if not requests.is_empty() else null


# ---- Stations ----

## The fleet, as the player: `GET /api/fleet/agents` with a device token in
## the Authorization header (never the query), the agents emitted before
## the answer, and whole numbers as ints.
func test_list_stations_asks_the_fleet() -> void:
	var hub = fake_hub()
	var source := live(hub)
	assert_true(source.LIVE and source.label() == "Live", "live")
	var emitted := []
	source.stations.connect(func(list: Array) -> void: emitted.append(list))
	var answer := await answer_of(source, source.list_stations())
	assert_eq(answer[0], true, "ok")
	assert_eq(answer[2], 200, "200")
	assert_eq(answer[1], hub.agentpod["fleet_agents"], "the fleet, as recorded")
	assert_eq(emitted, [hub.agentpod["fleet_agents"]["agents"]], "the stations were emitted")
	assert_eq(typeof(answer[1]["agents"][0]["uptimeSec"]), TYPE_INT, "whole numbers are ints")
	var request: Dictionary = hub.requests_to("GET /api/fleet/agents")[0]
	var bearer: String = request["headers"].get("authorization", "")
	assert_true(bearer.begins_with("Bearer ") and hub.tokens[bearer.substr(7)]["kind"] == "device", "a device token")
	assert_eq(request["query"], {}, "nothing in the query")
	done_with(hub)


## Health, files, file, lifecycle and the changeset: each call's request
## and its parsed answer.
func test_every_station_route_asks_and_answers_as_recorded() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var recorded: Dictionary = hub.agentpod
	var answer := await answer_of(source, source.health(STATION))
	assert_eq(answer, [true, recorded["health"], 200], "health")
	assert_eq(hub.requests_to("GET /api/stations/:id/health")[0]["path"], "/api/stations/stn_build/health", "for the station")

	answer = await answer_of(source, source.files(STATION, "."))
	assert_eq(answer, [true, recorded["files"]["."], 200], "the workspace's listing")
	answer = await answer_of(source, source.files(STATION, "src"))
	assert_eq(answer[1], recorded["files"]["src"], "a folder's")
	assert_eq(hub.requests_to("GET /api/stations/:id/files").map(func(r): return r["query"]),
		[{"path": "."}, {"path": "src"}], "the path in the query")

	answer = await answer_of(source, source.file(STATION, "src/main.rs", 0))
	assert_eq(answer, [true, {"text": recorded["file_contents"]["src/main.rs"]["content"], "truncated": false}, 200],
		"a text file, from its raw body")
	answer = await answer_of(source, source.file(STATION, "logo.png", 0))
	assert_eq(answer[1], {"bytes": Marshalls.base64_to_raw("iVBORw0KGgo="), "truncated": false}, "an image, as bytes")
	# "wc — words" cut inside its em dash: the text ends before it.
	answer = await answer_of(source, source.file(STATION, "src/main.rs", 30))
	assert_eq(answer[1], {"text": "fn main() {\n    println!(\"wc ", "truncated": true}, "cut, whole characters only")
	assert_eq(hub.requests_to("GET /api/stations/:id/file").map(func(r): return r["query"]),
		[{"path": "src/main.rs"}, {"path": "logo.png"}, {"path": "src/main.rs", "maxBytes": "30"}],
		"the path, and maxBytes only when asked")
	answer = await answer_of(source, source.file(STATION, "big.bin", 1 << 30))
	assert_eq(hub.requests_to("GET /api/stations/:id/file").back()["query"]["maxBytes"], str(8 << 20), "capped at 8 MiB")

	answer = await answer_of(source, source.lifecycle(STATION, "stop"))
	assert_eq(answer, [true, recorded["stopped_health"], 200], "stopped: the health after")
	assert_eq(sent_body(hub, "POST /api/stations/:id/lifecycle"), {"action": "stop"}, "the action")
	answer = await answer_of(source, source.lifecycle(STATION, "start"))
	assert_eq(answer[1], recorded["health"], "started")

	answer = await answer_of(source, source.changeset_status(STATION, ""))
	assert_eq(answer, [true, recorded["changeset_status"], 200], "the changeset")
	assert_eq(sent_body(hub, "POST /api/stations/:id/changeset/status"), {}, "no base: the default")
	await answer_of(source, source.changeset_status(STATION, "origin/main"))
	assert_eq(sent_body(hub, "POST /api/stations/:id/changeset/status"), {"base": "origin/main"}, "a base")
	answer = await answer_of(source, source.changeset_diff(STATION, "uncommitted", "src/main.rs"))
	assert_eq(answer, [true, recorded["changeset_diff"], 200], "a diff")
	assert_eq(sent_body(hub, "POST /api/stations/:id/changeset/diff"), {"side": "uncommitted", "path": "src/main.rs"}, "one file's")
	await answer_of(source, source.changeset_diff(STATION, "committed", ""))
	assert_eq(sent_body(hub, "POST /api/stations/:id/changeset/diff"), {"side": "committed"}, "a whole side")
	for request in hub.requests:
		assert_true(not request["headers"].has("origin"), "no Origin on " + request["route"])
		assert_true(not request["query"].has("token"), "no token in the query of " + request["route"])
	done_with(hub)


## A large body is read as fast as it arrives, not a 64 KiB chunk a frame.
func test_a_large_body_is_read_as_it_arrives() -> void:
	var hub = fake_hub()
	hub.agentpod["file_contents"]["big.txt"] = {"encoding": "utf8", "content": "a".repeat(4 << 20)}
	var source := live(hub)
	await answer_of(source, source.health(STATION))
	var call_id := source.file(STATION, "big.txt", 8 << 20)
	var got := []
	source.result.connect(func(id: int, ok: bool, body: Variant, _status: int) -> void:
		if id == call_id:
			got.append([ok, body]))
	var frames := 0
	while got.is_empty() and frames < 600:
		await runner.process_frame
		frames += 1
	assert_eq([got[0][0], got[0][1]["text"].length()], [true, 4 << 20], "the whole body")
	assert_true(frames < 32, "in far fewer frames than its 64 chunks of 64 KiB: %d" % frames)
	done_with(hub)


## A path with spaces and non-ASCII letters reaches the hub as it is.
func test_paths_are_encoded_in_the_query() -> void:
	var hub = fake_hub()
	hub.agentpod["files"]["docs/día 1 & 2"] = []
	var source := live(hub)
	var answer := await answer_of(source, source.files(STATION, "docs/día 1 & 2"))
	assert_eq(answer, [true, [], 200], "listed")
	assert_eq(hub.requests_to("GET /api/stations/:id/files")[0]["query"], {"path": "docs/día 1 & 2"}, "decoded as sent")
	done_with(hub)


# ---- Superpipeline ----

## Boards, agents, a card's history, and moving, deciding and answering:
## Bearer only, with the same device token, and the bodies the routes
## take (an empty comment left out).
func test_every_superpipeline_route_asks_and_answers_as_recorded() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var recorded: Dictionary = hub.superpipeline
	assert_eq(await answer_of(source, source.boards()), [true, recorded["boards"], 200], "boards")
	assert_eq(await answer_of(source, source.agents()), [true, recorded["agents"], 200], "agents")
	var card := "crd_sample_tabs"
	var answer := await answer_of(source, source.card_activities(BOARD, card))
	assert_eq(answer[1]["activities"], recorded["activities"][card]["activities"], "a card's history")
	assert_eq(answer[1]["gates"].map(func(g): return g["id"]), ["gate_sample"], "with its gates")
	answer = await answer_of(source, source.move_card(BOARD, "crd_sample_json", "review"))
	assert_eq([answer[0], answer[1]["card"]["currentStageKey"]], [true, "review"], "moved")
	assert_eq(sent_body(hub, "POST /v1/boards/:id/cards/:cardId/move"), {"toStageKey": "review"}, "to the stage")
	answer = await answer_of(source, source.resolve_gate(BOARD, "gate_sample", "approve", "  "))
	assert_eq([answer[0], answer[1]["card"]["id"]], [true, card], "decided")
	assert_eq(sent_body(hub, "POST /v1/boards/:id/gates/:gateId/resolve"), {"decision": "approve"}, "an empty comment left out")
	hub.superpipeline["snapshot"]["gates"][0]["status"] = "pending"
	await answer_of(source, source.resolve_gate(BOARD, "gate_sample", "request_changes", "Split it"))
	assert_eq(sent_body(hub, "POST /v1/boards/:id/gates/:gateId/resolve"), {"decision": "request_changes", "comment": "Split it"},
		"a comment sent")
	answer = await answer_of(source, source.answer(BOARD, "elc_sample", "array", ""))
	assert_eq([answer[0], answer[1]["elicitation"]["status"]], [true, "answered"], "answered")
	assert_eq(sent_body(hub, "POST /v1/boards/:id/elicitations/:elicitationId/answer"), {"option": "array"}, "an option only")
	hub.superpipeline["snapshot"]["elicitations"][0]["status"] = "pending"
	await answer_of(source, source.answer(BOARD, "elc_sample", "", "Both, with a flag"))
	assert_eq(sent_body(hub, "POST /v1/boards/:id/elicitations/:elicitationId/answer"), {"text": "Both, with a flag"}, "text only")
	var hub_token: String = hub.requests_to("GET /v1/boards")[0]["headers"]["authorization"]
	for request in hub.requests.filter(func(r): return r["product"] == "superpipeline"):
		assert_eq(request["headers"].get("authorization"), hub_token, "Bearer, the device token, on " + request["route"])
		assert_eq(request["query"], {}, "nothing in the query of " + request["route"])
	done_with(hub)


# ---- Errors ----

## 401 exchanges the token again and retries once.
func test_a_401_exchanges_again_and_retries_once() -> void:
	var hub = fake_hub()
	var source := live(hub)
	await answer_of(source, source.health(STATION))
	hub.refuse("hub", 401, 1)
	var answer := await answer_of(source, source.health(STATION))
	assert_eq([answer[0], answer[2]], [true, 200], "answered after the retry")
	assert_eq(hub.requests_to("GET /api/stations/:id/health").size(), 3, "asked again once")
	assert_eq(hub.requests_to("POST /api/auth/devices/token").size(), 2, "with a new token")
	assert_true(source.credential.is_signed_in(), "still signed in")
	done_with(hub)


## Two 401s in a row sign the player out: the call fails `signed_out`,
## and later calls fail at once, asking nothing. From Superpipeline the
## call fails the same way, but the hub's sign-in stands.
func test_two_401s_in_a_row_sign_the_player_out() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var signed_out := []
	source.credential.signed_out.connect(func() -> void: signed_out.append(true))
	hub.refuse("superpipeline", 401, 2)
	var answer := await answer_of(source, source.boards())
	assert_eq([answer[0], answer[1]["kind"], answer[2]], [false, "signed_out", 401], "Superpipeline refused the sign-in")
	assert_true(source.credential.is_signed_in() and signed_out.is_empty(), "the hub's sign-in stands")
	hub.refuse("hub", 401, 2)
	answer = await answer_of(source, source.health(STATION))
	assert_eq([answer[0], answer[1]["kind"], answer[2]], [false, "signed_out", 401], "signed out")
	assert_eq(signed_out, [true], "the player is signed out")
	assert_true(not source.credential.is_signed_in(), "not signed in")
	var asked: int = hub.requests.size()
	answer = await answer_of(source, source.list_stations())
	assert_eq([answer[0], answer[1]["kind"]], [false, "signed_out"], "later calls too")
	assert_eq(hub.requests.size(), asked, "without asking the hub")
	done_with(hub)


## Every mapping: 403, 404, the station routes' 502-offline against the
## write routes' 409-offline, a 502 that is not offline, Superpipeline's
## conflicts in its three error shapes, a 404 ending a session, and no
## answer at all.
func test_every_error_maps_to_its_kind() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var expect := func(call_id: int, kind: String, status: int, what: String) -> Dictionary:
		var answer := await answer_of(source, call_id)
		assert_eq([answer[0], answer[1].get("kind"), answer[2]], [false, kind, status], what)
		return answer[1]

	hub.refuse("hub", 403, 1)
	await expect.call(source.health(STATION), "no_access", 403, "403 is no access")
	await expect.call(source.health("stn_missing"), "not_found", 404, "404 is not found")

	hub.offline_stations[STATION] = true
	await expect.call(source.health(STATION), "offline", 502, "health: 502 naming the node is offline")
	await expect.call(source.files(STATION, "."), "offline", 502, "files: the same")
	await expect.call(source.file(STATION, "README.md", 0), "offline", 502, "file: the same")
	await expect.call(source.lifecycle(STATION, "restart"), "offline", 409, "lifecycle: 409 is offline")
	await expect.call(source.changeset_status(STATION, ""), "offline", 409, "changeset status: the same")
	await expect.call(source.changeset_diff(STATION, "uncommitted", ""), "offline", 409, "changeset diff: the same")
	hub.offline_stations.clear()
	hub.answer_with("hub", "GET /api/stations/:id/health", 502, {"error": "node disconnected"})
	await expect.call(source.health(STATION), "offline", 502, "a disconnected node is offline too")
	hub.answer_with("hub", "GET /api/stations/:id/health", 502, {"error": "health failed"})
	await expect.call(source.health(STATION), "failed", 502, "a 502 that is not offline failed")
	await expect.call(source.files(STATION, "nowhere"), "failed", 502, "a missing folder failed")
	hub.answer_with("hub", "POST /api/stations/:id/lifecycle", 502, {"error": "node offline"})
	await expect.call(source.lifecycle(STATION, "stop"), "failed", 502, "a write route's 502 failed: its offline is 409")
	hub.answer_with("hub", "GET /api/stations/:id/health", 502, "<html>Bad gateway</html>")
	await expect.call(source.health(STATION), "failed", 502, "a proxy's page failed")
	hub.answer_with("hub", "GET /api/stations/:id/health", 200, "not json")
	await expect.call(source.health(STATION), "failed", 200, "an unreadable answer failed")

	hub.answer_with("superpipeline", "POST /v1/boards/:id/cards/:cardId/move", 409,
		{"error": {"ok": false, "code": "WIP_LIMIT", "message": "WIP limit reached for stage \"review\" (limit 1)"}})
	var error: Dictionary = await expect.call(source.move_card(BOARD, "crd_sample_json", "review"), "conflict", 409, "a full stage")
	assert_eq(error["message"], "WIP limit reached for stage \"review\" (limit 1)", "in Superpipeline's words")
	hub.superpipeline["snapshot"]["gates"][0]["status"] = "resolved"
	error = await expect.call(source.resolve_gate(BOARD, "gate_sample", "approve", ""), "conflict", 409, "a settled gate")
	assert_eq(error["message"], "gate is not pending", "a Result's message")
	hub.answer_with("superpipeline", "POST /v1/boards/:id/cards/:cardId/move", 400, {"error": "toStageKey is required"})
	error = await expect.call(source.move_card(BOARD, "crd_sample_json", "review"), "failed", 400, "a bare string")
	assert_eq(error["message"], "toStageKey is required", "its words")
	hub.answer_with("superpipeline", "POST /v1/boards/:id/cards/:cardId/move", 400, {"error": {"message": "stage is archived"}})
	error = await expect.call(source.move_card(BOARD, "crd_sample_json", "review"), "failed", 400, "a {message} wrapper")
	assert_eq(error["message"], "stage is archived", "its words")
	hub.answer_with("superpipeline", "POST /v1/boards/:id/cards/:cardId/move", 500, {"error": {"message": "TypeError at x.ts:12"}})
	error = await expect.call(source.move_card(BOARD, "crd_sample_json", "review"), "failed", 500, "a server error")
	assert_eq(error["message"], "The request failed (POST /v1/boards/:id/cards/:cardId/move, 500)",
		"its words are for refusals (4xx) only: a 5xx is a fixed line")
	await expect.call(source.card_activities("brd_missing", "crd_x"), "not_found", 404, "a missing board")
	hub.refuse("superpipeline", 403, 1)
	await expect.call(source.boards(), "no_access", 403, "Superpipeline's 403")

	await expect.call(source.end_chat("acps_missing"), "not_found", 404, "ending a session that is not there")

	var elsewhere := LiveSource.new(source.credential, source.hub_url, "http://127.0.0.1:%d" % closed_port())
	var answer := await answer_of(elsewhere, elsewhere.boards())
	assert_eq([answer[0], answer[1]["kind"], answer[2]], [false, "offline", 0], "no answer at all is offline")
	var unset := LiveSource.new(source.credential, source.hub_url, "")
	answer = await answer_of(unset, unset.agents())
	assert_eq([answer[0], answer[1]["kind"], answer[2]], [false, "failed", 0], "an address not set")
	done_with(hub)


## A port nothing listens on.
func closed_port() -> int:
	var server := TCPServer.new()
	server.listen(0, "127.0.0.1")
	var port := server.get_local_port()
	server.stop()
	return port


## Nothing answers inside the call that asked, even a call refused at once.
func test_nothing_answers_inside_the_call() -> void:
	var hub = fake_hub()
	var source := LiveSource.new(StationCredential.new(hub.hub_url, "agentnagar", "user://no_such_credential.json"),
		hub.hub_url, hub.superpipeline_url)
	var heard := []
	source.result.connect(func(id: int, ok: bool, body: Variant, _status: int) -> void: heard.append([id, ok, body]))
	var call_id := source.health(STATION)
	var logs := source.open_logs(STATION)
	var failures := []
	logs.failed.connect(func(reason: Dictionary) -> void: failures.append(reason))
	assert_eq(heard, [], "not inside the call")
	await until(func() -> bool: return not heard.is_empty() and not failures.is_empty())
	assert_eq([heard[0][0], heard[0][1], heard[0][2]["kind"]], [call_id, false, "signed_out"], "signed out, a frame later")
	assert_eq(failures[0]["kind"], "signed_out", "the tail too")
	assert_eq(hub.requests, [], "nothing was asked")
	done_with(hub)


# ---- The log tail ----

## Server-Sent Events: each `data:` line is a log line, in order, whatever
## the chunks; comments are skipped; the tail ending says so; closing it
## closes the connection.
func test_log_lines_arrive_in_order() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var logs := source.open_logs(STATION)
	var lines := []
	var states := []
	logs.line.connect(func(text: String) -> void: lines.append(text))
	logs.state_changed.connect(func(state: String) -> void: states.append(state))
	logs.failed.connect(func(reason: Dictionary) -> void: runner.fail("the tail failed: %s" % reason["kind"]))
	await until(func() -> bool: return logs.state == "open" and hub.tails_open(STATION) == 1)
	assert_eq(states, ["open"], "open")
	var request: Dictionary = hub.requests_to("GET /api/stations/:id/logs")[0]
	assert_eq(request["headers"].get("accept"), "text/event-stream", "asked as an event stream")
	hub.push_log(STATION, "one\ntwo\n")
	hub.push_comment(STATION)
	hub.push_log(STATION, "three")
	hub.push_log(STATION, "día four\nfive")
	await until(func() -> bool: return lines.size() >= 5)
	assert_eq(lines, ["one", "two", "three", "día four", "five"], "in order")
	hub.end_logs(STATION)
	await until(func() -> bool: return states.size() >= 3 and hub.tails_open(STATION) == 1)
	assert_eq(states, ["open", "offline", "open"], "an ended tail is offline, and follows again after the backoff")
	hub.push_log(STATION, "six")
	await until(func() -> bool: return not lines.is_empty() and lines.back() == "six")
	assert_eq(lines.back(), "six", "and reads on")
	logs.close()
	await until(func() -> bool: return hub.tails_open(STATION) == 0)

	var again := source.open_logs(STATION)
	await until(func() -> bool: return again.state == "open" and hub.tails_open(STATION) == 1)
	again.close()
	await until(func() -> bool: return hub.tails_open(STATION) == 0)
	assert_eq([again.state, hub.tails_open(STATION)], ["closed", 0], "closing drops the connection")
	done_with(hub)


## A `data:` line and a multi-byte character split across two chunks
## arrive whole; a line that is not UTF-8 is skipped, not read as the
## blank line ending an event; and a line that never ends is not held
## without limit.
func test_log_lines_split_across_chunks_arrive_whole() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var logs := source.open_logs(STATION) as LiveSource.LiveLogs
	var lines := []
	logs.line.connect(func(text: String) -> void: lines.append(text))
	await until(func() -> bool: return logs.state == "open" and hub.tails_open(STATION) == 1)
	var event := "data: día one\n\n".to_utf8_buffer()
	var cut := event.find(0xC3) + 1
	assert_true(cut > 1, "the cut falls inside í's two bytes")
	hub.push_raw(STATION, event.slice(0, cut))
	await until(func() -> bool: return false, 0.2)
	assert_eq(lines, [], "nothing until the line ends")
	hub.push_raw(STATION, event.slice(cut))
	await until(func() -> bool: return not lines.is_empty())
	assert_eq(lines, ["día one"], "whole")

	var bad := "data: two\n".to_utf8_buffer()
	bad.append_array(PackedByteArray([0x64, 0x61, 0x74, 0x61, 0x3A, 0x20, 0xFF, 0xFE, 0x0A]))
	bad.append_array("data: three\n\n".to_utf8_buffer())
	hub.push_raw(STATION, bad)
	await until(func() -> bool: return lines.size() >= 3)
	assert_eq(lines, ["día one", "two", "three"], "the bad line skipped, the event whole")

	var endless := PackedByteArray()
	endless.resize(LiveSource.LiveLogs.MAX_PENDING_BYTES + 1)
	endless.fill(0x61)
	logs._on_chunk(endless)
	assert_true(logs._pending.size() <= LiveSource.LiveLogs.MAX_PENDING_BYTES, "a line that never ends is dropped")
	# The long line ends (its tail dropped with it), and the tail goes on.
	logs._on_chunk("still the long line\n".to_utf8_buffer())
	hub.push_log(STATION, "four")
	await until(func() -> bool: return lines.size() >= 4)
	assert_eq(lines.back(), "four", "and the tail goes on")
	logs.close()
	done_with(hub)


## A line longer than the cap is dropped whole, to its newline: its tail
## never becomes a line of its own, nor a blank ending the event early.
func test_an_over_long_log_line_is_dropped_to_its_end() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var logs := source.open_logs(STATION) as LiveSource.LiveLogs
	var lines := []
	logs.line.connect(func(text: String) -> void: lines.append(text))
	await until(func() -> bool: return logs.state == "open")
	var long := "data: ".to_utf8_buffer()
	var filler := PackedByteArray()
	filler.resize(LiveSource.LiveLogs.MAX_PENDING_BYTES + 10)
	filler.fill(0x61)
	long.append_array(filler)
	logs._on_chunk("data: before\n".to_utf8_buffer())
	logs._on_chunk(long)
	logs._on_chunk("aaa\ndata: forged\n".to_utf8_buffer())
	assert_eq(lines, [], "nothing yet: the event has not ended")
	logs._on_chunk("\ndata: after\n\n".to_utf8_buffer())
	assert_eq(lines, ["before", "forged", "after"], "the long line's tail is dropped, the event whole")
	var more := "data: ".to_utf8_buffer()
	more.append_array(filler)
	logs._on_chunk(more)
	logs._on_chunk("data: tail-looks-like-data\n\ndata: next\n\n".to_utf8_buffer())
	assert_eq(lines.slice(3), ["next"], "a tail that looks like a line or a blank is dropped with it")
	logs.close()
	done_with(hub)


## A body arriving faster than a frame reads is read a budget a frame, so
## one frame is never held by it.
func test_a_body_is_read_within_a_budget_each_frame() -> void:
	var hub = fake_hub()
	hub.agentpod["file_contents"]["big.txt"] = {"encoding": "utf8", "content": "b".repeat(2 << 20)}
	var credential := credential_for(hub)
	var tokens := []
	credential.request_token(func(token: String, _error: String) -> void: tokens.append(token))
	await until(func() -> bool: return not tokens.is_empty())
	var request := StationHttp.start(HTTPClient.METHOD_GET, hub.hub_url + "/api/stations/stn_build/file?path=big.txt&maxBytes=%d" % (4 << 20),
		PackedStringArray(["Authorization: Bearer " + tokens[0]]))
	assert_eq(StationHttp.FRAME_BUDGET_BYTES, 1 << 20, "a mebibyte a frame, by default")
	request.frame_budget_bytes = 256 << 10
	var got := []
	request.finished.connect(func(_s: int, _h: Dictionary, body: PackedByteArray) -> void: got.append(body.size()))
	var frames := 0
	while got.is_empty() and frames < 600:
		await runner.process_frame
		frames += 1
	assert_eq(got, [2 << 20], "the whole body")
	assert_true(frames >= 8, "at most 256 KiB a frame: %d frames for 2 MiB" % frames)
	done_with(hub)


## The fake holds the client to the hub's 8 MiB cap on one file read.
func test_the_fake_hub_refuses_a_read_over_the_cap() -> void:
	var hub = FakeHub.new()
	hub.start()
	var credential := credential_for(hub)
	var tokens := []
	credential.request_token(func(token: String, _error: String) -> void: tokens.append(token))
	await until(func() -> bool: return not tokens.is_empty())
	var request := StationHttp.start(HTTPClient.METHOD_GET,
		hub.hub_url + "/api/stations/stn_build/file?path=README.md&maxBytes=%d" % ((8 << 20) + 1),
		PackedStringArray(["Authorization: Bearer " + tokens[0]]))
	var done := []
	request.finished.connect(func(status: int, _h: Dictionary, _b: PackedByteArray) -> void: done.append(status))
	await until(func() -> bool: return not done.is_empty())
	assert_eq(done, [400], "refused")
	assert_eq(hub.violations.size(), 1, "a violation: %s" % [hub.violations])
	hub.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CREDENTIAL_FILE))


## An offline node's tail (502, before the stream opens) is offline, not a
## failure, and tries again after the backoff until the node is back; a
## 401 is retried once with a new token; a refusal while reconnecting
## fails it.
func test_the_tail_waits_out_an_offline_node_and_retries_a_401() -> void:
	var hub = fake_hub()
	var source := live(hub)
	hub.offline_stations[STATION] = true
	var logs := source.open_logs(STATION)
	var failures := []
	var states := []
	logs.failed.connect(func(reason: Dictionary) -> void: failures.append(reason))
	logs.state_changed.connect(func(state: String) -> void: states.append(state))
	await until(func() -> bool: return hub.requests_to("GET /api/stations/:id/logs").size() >= 3)
	assert_eq(states, ["offline"], "offline, and trying again")
	assert_eq(failures, [], "not a failure")
	hub.offline_stations.clear()
	await until(func() -> bool: return logs.state == "open")
	assert_eq(logs.state, "open", "open once the node is back")
	logs.close()
	hub.refuse("hub", 401, 1)
	var before: int = hub.requests_to("GET /api/stations/:id/logs").size()
	logs = source.open_logs(STATION)
	await until(func() -> bool: return logs.state == "open")
	assert_eq(logs.state, "open", "open after one retry")
	assert_eq(hub.requests_to("GET /api/stations/:id/logs").size() - before, 2, "asked again once")
	logs.failed.connect(func(reason: Dictionary) -> void: failures.append(reason))
	hub.refuse("hub", 403, 1)
	hub.end_logs(STATION)
	await until(func() -> bool: return logs.state == "closed")
	assert_eq(failures.map(func(f): return f["kind"]), ["no_access"], "a refusal on reconnecting fails it")
	done_with(hub)


# ---- The chat's session, over REST ----

## Watching never starts a session: it lists the station's and attaches
## to the newest not ended, or fails "No session".
func test_watching_the_chat_never_posts_a_session() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var chat := source.watch_chat(STATION) as LiveSource.LiveChat
	var failures := []
	chat.failed.connect(func(reason: Dictionary) -> void: failures.append(reason))
	await until(func() -> bool: return chat.state == "closed")
	assert_eq(failures, [StationSource.make_error("not_found", StationSource.NO_SESSION)], "no session to watch")

	var ended: Dictionary = hub.agentpod["acp_session"].duplicate(true)
	ended.merge({"id": "acps_old", "status": "ended"}, true)
	var open: Dictionary = hub.agentpod["acp_session"].duplicate(true)
	open.merge({"id": "acps_open", "status": "working"}, true)
	hub.sessions = [ended, open]
	chat = source.watch_chat(STATION) as LiveSource.LiveChat
	assert_true(await until(func() -> bool: return chat.state == "open"), "attached")
	assert_eq(chat.session_row.get("id"), "acps_open", "the newest not ended")
	chat.close()
	assert_eq(hub.requests_to("POST /api/stations/:id/acp/sessions"), [], "never a POST")
	assert_eq(hub.requests_to("GET /api/stations/:id/acp/sessions").size(), 2, "only listings")
	done_with(hub)


## Ruling (final review): the hub keeps several sessions a station, each
## its own agent process, and answers every POST with a new one. So opening
## the chat lists the player's sessions first and attaches to the newest
## open one: opened twice, or closed and opened again, it is the same
## session, and only one was made. One is made when none is open, and when
## the player asks for a new one ("New session": ended, then opened anew),
## even beside another open session; each opens its socket at once.
func test_opening_the_chat_attaches_to_the_open_session() -> void:
	var hub = fake_hub()
	var source := live(hub)
	var first := source.open_chat(STATION, "accept-edits") as LiveSource.LiveChat
	assert_true(await until(func() -> bool: return first.state == "open"), "its socket open")
	first.close()
	assert_eq(hub.requests_to("GET /api/stations/:id/acp/sessions").size(), 1, "listed first")
	assert_eq(sent_body(hub, "POST /api/stations/:id/acp/sessions"), {"mode": "accept-edits"}, "none open: made, in the mode asked")
	var created: String = first.session_row.get("id", "")
	assert_true(created != "" and hub.sessions[0]["id"] == created, "a new session")
	var second := source.open_chat(STATION, "ask") as LiveSource.LiveChat
	var third := source.open_chat(STATION, "ask") as LiveSource.LiveChat
	assert_true(await until(func() -> bool: return second.state == "open" and third.state == "open"), "their sockets open")
	second.close()
	third.close()
	assert_eq([second.session_row.get("id"), third.session_row.get("id")], [created, created],
		"closed and opened again, twice: the same session")
	assert_eq(hub.requests_to("POST /api/stations/:id/acp/sessions").size(), 1, "and exactly one was made")
	assert_eq(hub.sessions.size(), 1, "one agent process on the hub")

	# "New session": the open one ended, then a new one asked for.
	var answer := await answer_of(source, source.end_chat(created))
	assert_eq(answer, [true, null, 204], "ended")
	assert_eq(hub.requests_to("DELETE /api/acp/sessions/:id")[0]["path"], "/api/acp/sessions/" + created, "that session")
	var fresh := source.open_chat(STATION, "ask", true) as LiveSource.LiveChat
	assert_true(await until(func() -> bool: return fresh.state == "open"), "its socket open")
	fresh.close()
	var second_id: String = fresh.session_row.get("id", created)
	assert_true(second_id != created, "a second session")
	assert_eq(hub.sessions.size(), 2, "made on the hub")
	# Another session opened elsewhere (the console, say) is attached to by
	# an ordinary open, and never taken for the player's "New session".
	var elsewhere: Dictionary = hub.agentpod["acp_session"].duplicate(true)
	elsewhere.merge({"id": "acps_console", "stationId": STATION}, true)
	hub.sessions.push_front(elsewhere)
	var newer := source.open_chat(STATION, "ask", true) as LiveSource.LiveChat
	assert_true(await until(func() -> bool: return newer.state == "open"), "its socket open")
	newer.close()
	assert_true(not newer.session_row.get("id", "") in ["acps_console", second_id, ""], "a new one beside the open ones")
	assert_eq(hub.requests_to("POST /api/stations/:id/acp/sessions").size(), 3, "made only when none was open, or asked for")
	done_with(hub)


## An older node keeps one session a station and refuses a second with 409.
## Listed first, the open one is attached to without a POST; and a 409 (a
## session opened between the listing and the POST) still attaches to the
## open one, the newest not ended.
func test_an_older_node_s_409_still_attaches_to_the_open_session() -> void:
	var hub = fake_hub()
	hub.single_session = true
	var source := live(hub)
	var open: Dictionary = hub.agentpod["acp_session"].duplicate(true)
	open.merge({"id": "acps_open", "stationId": STATION}, true)
	hub.sessions.push_front(open)
	var chat := source.open_chat(STATION, "ask") as LiveSource.LiveChat
	assert_true(await until(func() -> bool: return chat.state == "open"), "its socket open")
	chat.close()
	assert_eq(chat.session_row.get("id"), "acps_open", "the open one")
	assert_eq(hub.requests_to("POST /api/stations/:id/acp/sessions"), [], "with no POST")
	# The listing misses it (it opened just after), so the POST meets a 409.
	hub.answer_with("hub", "GET /api/stations/:id/acp/sessions", 200, [])
	chat = source.open_chat(STATION, "ask") as LiveSource.LiveChat
	assert_true(await until(func() -> bool: return chat.state == "open"), "its socket open")
	chat.close()
	assert_eq(hub.requests_to("POST /api/stations/:id/acp/sessions").size(), 1, "a POST")
	assert_eq(chat.session_row.get("id"), "acps_open", "refused (409), and the open one attached to")
	assert_eq(hub.sessions.size(), 1, "no second session")
	done_with(hub)


# ---- Tokens ----

## Review Focus 1: with two-second tokens exchanged again when one second
## is left, a steady run of calls never meets an expired token.
func test_tokens_are_refreshed_before_they_expire() -> void:
	var hub = fake_hub()
	hub.token_lifetime_s = 2
	var source := live(hub)
	source.credential.refresh_margin_s = 1.0
	var began := Time.get_ticks_msec()
	var calls := 0
	while Time.get_ticks_msec() - began < 3500:
		var answer := await answer_of(source, source.health(STATION))
		assert_true(answer[0], "call %d answered" % calls)
		calls += 1
		await until(func() -> bool: return false, 0.2)
	var exchanges: int = hub.requests_to("POST /api/auth/devices/token").size()
	assert_eq(hub.unauthorized, 0, "no call met an expired token")
	assert_true(exchanges >= 3, "exchanged again as each neared its end: %d" % exchanges)
	assert_true(exchanges < calls, "but not for every call: %d of %d" % [exchanges, calls])
	done_with(hub)


# ---- The redaction rule ----

## Through a failing session (a refused sign-in, refusals, offline nodes,
## a node's error, Superpipeline's refusals, no answer, signing out), no
## response body, token, secret or query string reaches the log, the error
## watch or a failure's message; a message is a fixed line, the route's
## template and a status. Superpipeline's own words are allowed in a
## message, but never in the log.
func test_no_body_token_secret_or_query_reaches_a_log_or_a_message() -> void:
	var capture := LogCapture.new()
	OS.add_logger(capture)
	var hub = fake_hub()
	var planted := ["BODY-MARK-1", "BODY-MARK-2", "BODY-MARK-3", "DIR-MARK-4", "PAGE-MARK-5", "GRANT-MARK-6"]
	var superpipeline_words := "WIP-MARK-7 reached"
	var messages := []
	var credential := StationCredential.new(hub.hub_url, "agentnagar", CREDENTIAL_FILE)
	credential.platform = "desktop"
	credential.open_browser = func(url: String) -> void: follow(url)
	hub.answer_with("hub", "POST /api/auth/token/exchange", 400, {"error": "invalid_grant", "error_description": planted[5]})
	var outcome := []
	credential.sign_in_finished.connect(func(ok: bool, message: String) -> void: outcome.append_array([ok, message]))
	credential.sign_in()
	await until(func() -> bool: return not outcome.is_empty(), 10.0)
	messages.append(outcome[1])

	var source := live(hub)
	var collect := func(call_id: int) -> void:
		var answer := await answer_of(source, call_id)
		if not answer[0]:
			messages.append(answer[1]["message"])
	hub.answer_with("hub", "GET /api/stations/:id/health", 502, {"error": "health failed " + planted[0]})
	await collect.call(source.health(STATION))
	hub.answer_with("hub", "POST /api/stations/:id/lifecycle", 409, {"error": "node offline " + planted[1]})
	await collect.call(source.lifecycle(STATION, "restart"))
	hub.answer_with("hub", "GET /api/stations/:id/file", 404, {"error": planted[2]})
	await collect.call(source.file(STATION, planted[3] + "/secret.txt", 0))
	hub.answer_with("hub", "GET /api/fleet/agents", 502, "<html>" + planted[4] + "</html>")
	await collect.call(source.list_stations())
	hub.answer_with("superpipeline", "POST /v1/boards/:id/cards/:cardId/move", 409,
		{"error": {"ok": false, "code": "WIP_LIMIT", "message": superpipeline_words}})
	await collect.call(source.move_card(BOARD, "crd_sample_json", "review"))
	hub.refuse("hub", 403, 1)
	var logs := source.open_logs(STATION)
	logs.failed.connect(func(reason: Dictionary) -> void: messages.append(reason["message"]))
	await until(func() -> bool: return logs.state == "closed")
	hub.offline_stations[STATION] = true
	var chat := source.watch_chat(STATION)
	chat.failed.connect(func(reason: Dictionary) -> void: messages.append(reason["message"]))
	await until(func() -> bool: return chat.state == "closed")
	hub.refuse("hub", 401, 2)
	await collect.call(source.health(STATION))
	var elsewhere := LiveSource.new(credential_for(hub), "http://127.0.0.1:%d" % closed_port(), hub.superpipeline_url)
	var answer := await answer_of(elsewhere, elsewhere.files(STATION, planted[3]))
	messages.append(answer[1]["message"])
	OS.remove_logger(capture)

	var secrets: Array = planted.duplicate()
	secrets.append_array(hub.tokens.keys())
	for device in hub.devices.values():
		secrets.append(device["secret"])
	secrets.append_array(hub.codes.keys())
	for request in hub.requests:
		if request["target"].contains("?"):
			secrets.append(request["target"].get_slice("?", 1))
	assert_true(secrets.size() > planted.size() + 3, "tokens, secrets, codes and queries are checked: %d" % secrets.size())
	var logged := "\n".join(capture.lines) + "\n".join(runner.errors)
	for secret in secrets:
		assert_true(not logged.contains(secret), "never logged: a planted value, token, secret, code or query")
		for message in messages:
			assert_true(not str(message).contains(secret), "never in a message: " + str(message))
	assert_true(not logged.contains(superpipeline_words), "Superpipeline's words are never logged")
	assert_true(superpipeline_words in messages, "though they are its refusal's message")
	var shape := RegEx.create_from_string("^[^()]+ \\((GET|POST|DELETE|WS) /[^ ,]+, (\\d{3}|no answer)\\)$")
	for message in messages:
		if message != superpipeline_words and message != StationCredential.REFUSED and message != StationSource.NO_SESSION:
			assert_true(shape.search(message) != null, "a fixed line, a route and a status: " + message)
	assert_eq(messages.size(), 10, "every failure was heard")
	done_with(hub)


## The live code logs nothing at all, and makes its network objects only
## through `StationSource.new_network_object`, which counts them.
func test_the_live_code_logs_nothing_and_counts_what_it_connects_with() -> void:
	for path in ["res://core/station/http.gd", "res://core/station/credential.gd", "res://core/station/live_source.gd"]:
		var text := FileAccess.get_file_as_string(path)
		assert_true(not text.is_empty(), path + " reads")
		for name in ["print(", "print_rich(", "printerr(", "prints(", "push_warning(", "push_error(", "OS.alert("]:
			assert_true(not text.contains(name), "%s never calls %s" % [path.get_file(), name])
		for name in ["HTTPClient.new(", "TCPServer.new(", "StreamPeerTCP.new(", "WebSocketPeer.new(", "HTTPRequest",
				"ClassDB.instantiate("]:
			assert_true(not text.contains(name), "%s makes no %s but through the counter" % [path.get_file(), name])
	var hub = fake_hub()
	var source := live(hub)
	var before := StationSource.network_objects_created
	await answer_of(source, source.list_stations())
	assert_eq(StationSource.network_objects_created - before, 2, "an exchange and the call, both counted")
	done_with(hub)


## The scripted browser for the redaction test: follows the redirect.
func follow(url: String) -> void:
	var first := await fetch(url)
	var location: String = first["headers"].get("location", "")
	if location != "":
		await fetch(location)


func fetch(url: String) -> Dictionary:
	var request := StationHttp.start(HTTPClient.METHOD_GET, url, PackedStringArray())
	var done := {}
	request.finished.connect(func(status: int, headers: Dictionary, _body: PackedByteArray) -> void:
		done.merge({"status": status, "headers": headers}))
	request.network_failed.connect(func() -> void: done.merge({"status": 0, "headers": {}}))
	while done.is_empty():
		await runner.process_frame
	return done


## Everything logged while it is added: messages and errors alike.
class LogCapture extends Logger:
	var lines: Array[String] = []

	func _log_message(message: String, _error: bool) -> void:
		lines.append(message)

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		lines.append("%s %s %s:%d %s" % [code, rationale, file, line, function])


# ---- The fake hub keeps the client honest ----

## The fake answers 404 to a route it does not know, 400 to a body it does
## not know, and 401 to a token in a REST query or a token Superpipeline's
## audience check would refuse; each drift is a violation.
func test_the_fake_hub_refuses_what_it_does_not_know() -> void:
	var hub = FakeHub.new()
	hub.start()
	var credential := credential_for(hub)
	var tokens := []
	credential.request_token(func(token: String, _error: String) -> void: tokens.append(token))
	await until(func() -> bool: return not tokens.is_empty())
	var bearer := PackedStringArray(["Authorization: Bearer " + tokens[0], "Content-Type: application/json"])
	var status := func(method: int, url: String, body: String, headers: PackedStringArray) -> int:
		var request := StationHttp.start(method, url, headers, body.to_utf8_buffer())
		var done := []
		request.finished.connect(func(s: int, _h: Dictionary, _b: PackedByteArray) -> void: done.append(s))
		request.network_failed.connect(func() -> void: done.append(0))
		await until(func() -> bool: return not done.is_empty())
		return done[0]
	var hub_url: String = hub.hub_url
	assert_eq(await status.call(HTTPClient.METHOD_GET, hub_url + "/api/stations/stn_build/secrets", "", bearer), 404,
		"an unknown route")
	assert_eq(await status.call(HTTPClient.METHOD_POST, hub_url + "/api/stations/stn_build/lifecycle",
		"{\"action\":\"explode\"}", bearer), 400, "an unknown action")
	assert_eq(await status.call(HTTPClient.METHOD_POST, hub_url + "/api/stations/stn_build/changeset/diff",
		"{\"side\":\"uncommitted\",\"colour\":\"red\"}", bearer), 400, "an unknown key")
	assert_eq(await status.call(HTTPClient.METHOD_GET, hub_url + "/api/fleet/agents?token=" + tokens[0], "", bearer), 401,
		"a token in a REST query")
	assert_eq(hub.violations.size(), 4, "each a violation: %s" % [hub.violations])
	var sign_in_bearer := PackedStringArray(["Authorization: Bearer " + hub.mint("sign_in", "")])
	assert_eq(await status.call(HTTPClient.METHOD_GET, hub.superpipeline_url + "/v1/boards", "", sign_in_bearer), 401,
		"Superpipeline refuses the hub's own token (its audience)")
	assert_eq(await status.call(HTTPClient.METHOD_GET, hub_url + "/api/fleet/agents", "", sign_in_bearer), 200,
		"which the hub takes")
	hub.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CREDENTIAL_FILE))


## The live source listens for its credential's sign-out through a
## connection that names it without holding it: let go of, the source is
## freed, and the credential once nothing else holds it.
func test_the_live_source_holds_no_cycle_with_its_credential() -> void:
	var hub = fake_hub()
	var credential := credential_for(hub)
	var source := LiveSource.new(credential, hub.hub_url, hub.superpipeline_url)
	var source_ref: WeakRef = weakref(source)
	var credential_ref: WeakRef = weakref(credential)
	assert_true(credential.signed_out.is_connected(source.forget_stations), "the source listens for a sign-out")
	source = null
	assert_true(source_ref.get_ref() == null, "the source is freed")
	credential.refuse()
	credential = null
	assert_true(credential_ref.get_ref() == null, "and then the credential")
	done_with(hub)


## Ruling (final review): the device secret never crosses a network in
## cleartext. A hub or Superpipeline address must be `https://`, except on
## this computer (127.0.0.1, [::1] or localhost). A plain `http://` remote
## address is refused as no address, by the live source and the credential
## alike: no request, no socket, no browser and no secret sent. The fake
## hub, on 127.0.0.1, is allowed.
func test_a_plain_http_remote_address_is_refused() -> void:
	for url in ["https://hub.example", "https://hub.example:8443/", "http://127.0.0.1:8080", "http://localhost:3000",
			"http://[::1]:9000", "http://LOCALHOST"]:
		assert_true(StationHttp.is_secure_or_loopback(url), url + " allowed")
	for url in ["http://example.test", "http://10.0.0.5:8080", "http://127.0.0.1.example.test", "http://localhost.example",
			"http://[::2]", "ftp://hub.example", "", "hub.example"]:
		assert_true(not StationHttp.is_secure_or_loopback(url), url + " refused")

	var hub = fake_hub()
	var destinations := []
	StationSource.connecting = func(destination: String) -> void: destinations.append(destination)
	var remote := "http://example.test"
	var file := FileAccess.open(CREDENTIAL_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"hub": remote, "device_id": "dev_remote", "secret": "sec_remote"}))
	file.close()
	var credential := StationCredential.new(remote, "agentnagar", CREDENTIAL_FILE)
	var opened := []
	credential.open_browser = func(url: String) -> void: opened.append(url)
	var before := StationSource.network_objects_created
	var answered := []
	credential.request_token(func(token: String, error: String) -> void: answered.append([token, error]))
	assert_eq(answered, [["", "no_address"]], "the credential refuses to exchange its secret there")

	var source := LiveSource.new(credential, remote, remote)
	var failures := []
	failures.append(await answer_of(source, source.list_stations()))
	failures.append(await answer_of(source, source.health(STATION)))
	failures.append(await answer_of(source, source.boards()))
	for failure in failures:
		assert_eq([failure[0], failure[1]["kind"]], [false, "failed"], "refused: %s" % failure[1]["message"])
		assert_true(failure[1]["message"].begins_with(LiveSource.NO_ADDRESS), "as no address: %s" % failure[1]["message"])
	var streams: Array = [source.open_terminal(STATION), source.open_chat(STATION, "ask"), source.open_logs(STATION),
		source.board("brd_build")]
	var stream_failures := []
	for stream in streams:
		stream.failed.connect(func(reason: Dictionary) -> void: stream_failures.append(reason))
	assert_true(await until(func() -> bool: return stream_failures.size() == streams.size()), "every stream refused")
	for failure in stream_failures:
		assert_true(failure["message"].begins_with(LiveSource.NO_ADDRESS), "as no address: %s" % failure["message"])

	var finished := []
	credential.sign_in_finished.connect(func(ok: bool, message: String) -> void: finished.append([ok, message]))
	credential.sign_in()
	assert_true(await until(func() -> bool: return not finished.is_empty()), "signing in ends")
	assert_eq(finished, [[false, StationCredential.NOT_HTTPS]], "refused, saying why")
	var disconnected := []
	credential.disconnect_finished.connect(func(revoked: bool, _message: String) -> void: disconnected.append(revoked))
	credential.disconnect_device()
	assert_true(await until(func() -> bool: return not disconnected.is_empty()), "disconnecting ends")
	assert_eq(disconnected, [false], "not revoked there")
	assert_eq(opened, [], "no browser opened")
	assert_eq(destinations, [], "nothing sent anywhere")
	assert_eq(StationSource.network_objects_created, before, "not a network object made")

	# The fake, on this computer, over plain http.
	var local := live(hub)
	assert_true(local.hub_url.begins_with("http://127.0.0.1:"), "the fake hub is on 127.0.0.1")
	var listed := await answer_of(local, local.list_stations())
	assert_eq(listed[0], true, "and allowed")
	assert_true(not destinations.is_empty(), "reached")
	StationSource.connecting = Callable()
	done_with(hub)


## One request straight to the fake, awaited: [status, body parsed].
func raw(method: int, url: String, headers := PackedStringArray()) -> Array:
	var request := StationHttp.start(method, url, headers, PackedByteArray() if method == HTTPClient.METHOD_GET \
		else "".to_utf8_buffer())
	var done := []
	request.finished.connect(func(s: int, _h: Dictionary, b: PackedByteArray) -> void:
		done.append_array([s, StationSource.parse_json(b.get_string_from_utf8())]))
	request.network_failed.connect(func() -> void: done.append_array([0, null]))
	await until(func() -> bool: return not done.is_empty())
	return done


## The fake answers as the pinned hub and board do, account by account:
## - each account sees only its own stations (fleet, station routes, the
##   terminal socket) and its own sessions (the list, DELETE, the chat
##   socket); another's answers 404, or 1011 "station not found" on the
##   terminal socket, as `getStation(userId, …)` does
##   (agentpod@9bc1997:apps/hub/src/routes/stations.ts,
##   station-terminal.ts, station-acp.ts);
## - a node offline makes its rows `status: "unknown"` with no numbers
##   (packages/contract/src/fleet.ts, services/fleet.ts `deriveStatus`);
## - the device list has `lastUsedAt` (services/device-credentials.ts), a
##   device token lives `expiresIn: 300` (routes/devices.ts), and the
##   authorize page ignores `response_type` (routes/auth-authorize.ts);
## - Superpipeline's 401 is `{"error":"sign in to continue"}`, and an
##   unknown board's socket upgrades with an empty snapshot
##   (superpipeline@d53992f:apps/api/src/index.ts, board/board-do.ts).
func test_the_fake_answers_as_the_hub_does_account_by_account() -> void:
	var hub = fake_hub()
	var mine := live(hub)
	var other_row: Dictionary = hub.agentpod["fleet_agents"]["agents"][0].duplicate(true)
	other_row.merge({"stationId": "stn_other", "agentName": "Their box"}, true)
	hub.add_station(other_row, "usr_other")
	var theirs := LiveSource.new(StationCredential.new(hub.hub_url, "agentnagar", "user://test_live_rest_other.json"),
		hub.hub_url, hub.superpipeline_url)
	var id: String = hub.serial("dev_")
	hub.devices[id] = {"secret": hub.serial("sec_"), "name": "Theirs", "revoked": false, "owner": "usr_other"}
	var file := FileAccess.open("user://test_live_rest_other.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"hub": hub.hub_url, "device_id": id, "secret": hub.devices[id]["secret"]}))
	file.close()
	theirs.credential.load_file()
	var listed: Array = (await answer_of(mine, mine.list_stations()))[1]["agents"].map(func(r): return r["stationId"])
	assert_eq(listed, ["stn_build", "stn_quiet"], "mine: my stations")
	var their_list: Dictionary = (await answer_of(theirs, theirs.list_stations()))[1]
	assert_eq(their_list["agents"].map(func(r): return r["stationId"]), ["stn_other"], "theirs: theirs")
	assert_eq(their_list["stats"]["agents"]["total"], 1, "their stats, from their rows")
	assert_eq((await answer_of(mine, mine.health("stn_other")))[1].get("kind"), "not_found", "their station: 404")
	assert_eq((await answer_of(mine, mine.files("stn_other", "")))[1].get("kind"), "not_found", "its files: 404")
	var terminal := mine.open_terminal("stn_other")
	var failures := []
	terminal.failed.connect(func(reason: Dictionary) -> void: failures.append(reason))
	assert_true(await until(func() -> bool: return terminal.state == "closed"), "their terminal refused")
	assert_true(failures[0]["message"].begins_with(LiveSource.STATION_GONE), "a 1011, then no such station: %s" % failures[0]["message"])
	assert_eq(hub.requests_to("GET /api/stations/:id/terminal").size(), 1, "one attempt")

	var their_chat := theirs.open_chat("stn_other", "ask") as LiveSource.LiveChat
	assert_true(await until(func() -> bool: return their_chat.state == "open"), "their session")
	their_chat.close()
	var their_session: String = their_chat.session_row["id"]
	assert_eq(hub.session(their_session)["userId"], "usr_other", "made as them")
	assert_eq((await answer_of(mine, mine.end_chat(their_session)))[1].get("kind"), "not_found", "mine cannot end theirs")
	assert_eq(hub.session(their_session)["status"], "idle", "which carries on")
	var my_row: Dictionary = hub.agentpod["acp_session"].duplicate(true)
	my_row.merge({"id": "acps_mine", "stationId": "stn_build"}, true)
	hub.sessions.push_front(my_row)
	var theirs_list := await answer_of(theirs, theirs.end_chat("acps_mine"))
	assert_eq(theirs_list[1].get("kind"), "not_found", "nor theirs mine")
	var peek := mine.open_chat("stn_other", "ask")
	var peek_failures := []
	peek.failed.connect(func(reason: Dictionary) -> void: peek_failures.append(reason["kind"]))
	assert_true(await until(func() -> bool: return peek.state == "closed"), "their station's sessions refused")
	assert_eq(peek_failures, ["not_found"], "404")
	var sneak := LiveSource.LiveChat.new(mine, "stn_other")
	var sneak_failures := []
	sneak.failed.connect(func(reason: Dictionary) -> void: sneak_failures.append(reason["kind"]))
	sneak.attach(hub.session(their_session))
	assert_true(await until(func() -> bool: return sneak.state == "closed"), "their session's socket refused")
	assert_eq(sneak_failures, ["not_found"], "1008 session not found")

	# A node offline: its rows' status unknown, with no numbers.
	hub.set_station_offline("stn_build", true)
	var rows: Array = (await answer_of(mine, mine.list_stations()))[1]["agents"]
	for row in rows:
		assert_eq([row["nodeStatus"], row["status"], row["cpuPct"], row["memBytes"], row["uptimeSec"]],
			["offline", "unknown", null, null, null], row["stationId"] + ": offline, status unknown, no numbers")
	hub.set_station_offline("stn_build", false)

	# The device routes and the authorize page.
	var human := PackedStringArray(["Authorization: Bearer " + hub.mint("sign_in", "")])
	var devices: Array = (await raw(HTTPClient.METHOD_GET, hub.hub_url + "/api/auth/devices", human))[1]["devices"]
	assert_true(not devices.is_empty() and devices.all(func(d): return d.has("lastUsedAt")), "devices carry lastUsedAt")
	var exchange := await raw(HTTPClient.METHOD_POST, hub.hub_url + "/api/auth/devices/token?client=agentnagar",
		PackedStringArray(["Authorization: Bearer %s:%s" % [id, hub.devices[id]["secret"]], "Content-Length: 0"]))
	assert_eq(exchange[1]["expiresIn"], 300, "a device token lives 300 s")
	var authorize := "%s/api/auth/authorize?client=agentnagar&redirect_uri=%s&state=abc&code_challenge=%s&code_challenge_method=S256" \
		% [hub.hub_url, "http://127.0.0.1:1/callback".uri_encode(), StationCredential.challenge_for("v".repeat(43))]
	assert_eq((await raw(HTTPClient.METHOD_GET, authorize))[0], 302, "authorize with no response_type: it is not read")

	# Superpipeline.
	var refused := await raw(HTTPClient.METHOD_GET, hub.superpipeline_url + "/v1/boards")
	assert_eq(refused, [401, {"error": "sign in to continue"}], "Superpipeline's own refusal")
	var board := mine.board("brd_unknown")
	var snapshots := []
	board.snapshot.connect(func(state: Dictionary) -> void: snapshots.append(state))
	assert_true(await until(func() -> bool: return not snapshots.is_empty()), "an unknown board's socket opens")
	assert_eq([snapshots[0]["boardId"], snapshots[0]["cards"], snapshots[0]["stages"]], [null, [], []], "with an empty snapshot")
	board.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_live_rest_other.json"))
	done_with(hub)
