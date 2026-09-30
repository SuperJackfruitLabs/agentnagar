extends TestSuite

## Sample station: the recording under res://sample_station/, played by
## `SampleSource` behind the `StationSource` interface. Field names are the
## protocol reference's; a live source must answer with the same ones.

const STATION := "stn_sample"
const BOARD := "brd_sample"

const FLEET_AGENT_KEYS := [
	"stationId", "nodeId", "nodeName", "agentName", "harness", "kind", "nodeStatus", "agentVersion",
	"latestVersion", "updateAvailable", "capabilities", "workspacePath", "status", "cpuPct", "memBytes",
	"uptimeSec",
]
const HEALTH_KEYS := ["running", "pid", "cpuPct", "memBytes", "diskBytes", "uptimeSec", "lastActivity", "note"]
const FS_ENTRY_KEYS := ["name", "path", "type", "size", "modified"]
const CHANGESET_KEYS := ["repo", "base", "uncommitted", "committed", "truncatedFiles"]
const CHANGESET_FILE_KEYS := ["path", "oldPath", "status", "insertions", "deletions", "binary"]
const COMMIT_KEYS := ["sha", "shortSha", "subject", "author", "committedAt"]
const DIFF_KEYS := ["content", "truncated", "binary"]
const SESSION_KEYS := [
	"id", "stationId", "userId", "mode", "status", "endedReason", "createdAt", "lastEventAt", "title", "lastSeq",
]
const EVENT_KEYS := ["sessionId", "seq", "type", "payload", "createdAt"]
const SNAPSHOT_KEYS := [
	"boardId", "tenantId", "name", "stages", "cards", "gates", "elicitations", "references", "usage", "github",
]
const CARD_KEYS := [
	"id", "title", "spec", "ownerUserId", "queuedBy", "queuedGrant", "currentStageKey", "state",
	"delegateAgentId", "priority", "contextId", "createdAt", "updatedAt", "costUsd", "overBudget", "attemptCount",
]
const GATE_KEYS := [
	"id", "cardId", "stageKey", "status", "decision", "options", "producedBy", "createdAt", "decidedBy",
	"comment", "resolvedAt",
]
const ELICITATION_KEYS := [
	"id", "cardId", "runId", "stageKey", "agentId", "question", "signal", "options", "status", "answer", "createdAt",
]
const ELICITATION_OPTION_KEYS := ["name", "title", "promptFill", "interactive"]
const ACTIVITY_KEYS := ["seq", "runId", "type", "ts", "body", "action", "parameter", "result", "signal"]
const AGENT_KEYS := [
	"id", "tenantId", "name", "capabilities", "iconUrl", "concurrency", "externalId", "externalSource", "tokenIds",
]
const BOARD_EVENT_KEYS := ["seq", "type", "payload", "ts"]
const ACP_EVENT_TYPES := ["user-prompt", "agent-update", "permission-request", "permission-answer", "state", "error"]
const ACP_STATUSES := ["starting", "idle", "working", "waiting", "ended"]
const TASK_STATES := [
	"submitted", "working", "input-required", "auth-required", "completed", "rejected", "failed", "canceled",
]

## A source that plays the recording quickly: a recorded second passes in a
## millisecond, so a test never waits real seconds.
func _source() -> SampleSource:
	var source := SampleSource.new()
	source.speed = 1000.0
	return source


func _keys(d: Dictionary) -> Array:
	var keys := d.keys()
	keys.sort()
	return keys


func _sorted(a: Array) -> Array:
	var copy := a.duplicate()
	copy.sort()
	return copy


func _assert_shape(d: Dictionary, expected: Array, what: String) -> void:
	assert_eq(_keys(d), _sorted(expected), what + " has exactly the protocol's fields")


## Waits frame by frame until `condition` holds, for at most `frames`.
func _until(condition: Callable, frames := 3000) -> bool:
	for i in frames:
		if condition.call():
			return true
		await runner.process_frame
	return condition.call()


## Collects every `result` a source emits, keyed by call ID.
func _results(source: StationSource) -> Dictionary:
	var got := {}
	source.result.connect(func(call_id: int, ok: bool, body, status: int) -> void:
		got[call_id] = {"ok": ok, "body": body, "status": status})
	return got


## Makes one call and waits for its answer.
func _call(source: StationSource, got: Dictionary, call_id: int) -> Dictionary:
	await _until(func() -> bool: return got.has(call_id))
	assert_true(got.has(call_id), "call %d was answered" % call_id)
	return got.get(call_id, {"ok": false, "body": {}, "status": 0})


func test_the_label_is_sample_and_it_is_not_live() -> void:
	var source := _source()
	assert_eq(source.label(), "Sample")
	assert_eq(source.LIVE, false, "Sample station never reaches a real station")
	assert_true(source is StationSource, "it implements the station interface")


func test_every_call_answers_on_a_later_frame_never_inside_the_call() -> void:
	var source := _source()
	var got := _results(source)
	var listed := []
	source.stations.connect(func(list: Array) -> void: listed.append(list))
	var ids := [
		source.list_stations(), source.health(STATION), source.files(STATION, "."),
		source.file(STATION, "src/lib.rs", 0), source.changeset_status(STATION, ""),
		source.changeset_diff(STATION, "uncommitted", ""), source.boards(), source.agents(),
		source.card_activities(BOARD, "crd_sample_tabs"),
	]
	assert_eq(got.size(), 0, "no result arrives synchronously, as none can from the network")
	assert_eq(listed.size(), 0, "nor the station list")
	var unique := {}
	for call_id in ids:
		unique[call_id] = true
	assert_eq(unique.size(), ids.size(), "every call has its own ID")
	await _until(func() -> bool: return got.size() == ids.size())
	assert_eq(got.size(), ids.size(), "and every call is answered")
	assert_eq(listed.size(), 1, "the station list arrives once")


func test_the_station_list_is_fleet_agents() -> void:
	var source := _source()
	var got := _results(source)
	var listed := []
	source.stations.connect(func(list: Array) -> void: listed.append(list))
	var answer := await _call(source, got, source.list_stations())
	assert_true(answer["ok"], "listing succeeds")
	assert_eq(answer["status"], 200)
	assert_eq(_keys(answer["body"]), ["agents", "stats"], "the route's body: stats and agents")
	assert_eq(listed.size(), 1)
	var agents: Array = listed[0]
	assert_eq(agents.size(), 1, "one station")
	var agent: Dictionary = agents[0]
	_assert_shape(agent, FLEET_AGENT_KEYS, "FleetAgent")
	assert_eq(agent["stationId"], STATION)
	assert_eq(agent["agentName"], "Sample agent")
	assert_eq(agent["nodeName"], "sample-node")
	assert_eq(agent["nodeStatus"], "online")
	assert_eq(agent["status"], "running")
	assert_eq(
		agent["capabilities"], ["health", "logs", "fs.read", "terminal", "lifecycle", "acp", "changeset"],
		"a coding agent's capabilities"
	)
	assert_eq(source.built_in_agent_link(STATION), "agt_sample", "Sample's Work link is built in")


func test_health_is_a_station_health_and_lifecycle_changes_it() -> void:
	var source := _source()
	var got := _results(source)
	var first := await _call(source, got, source.health(STATION))
	assert_true(first["ok"], "health answers")
	_assert_shape(first["body"], HEALTH_KEYS, "StationHealth")
	assert_eq(first["body"]["running"], true)
	var pid: int = first["body"]["pid"]

	var stopped := await _call(source, got, source.lifecycle(STATION, "stop"))
	assert_true(stopped["ok"], "stop succeeds")
	_assert_shape(stopped["body"], HEALTH_KEYS, "lifecycle answers with the post-action health")
	assert_eq(stopped["body"]["running"], false, "stopped")
	assert_eq(stopped["body"]["pid"], null, "a stopped station has no process")
	var after_stop := await _call(source, got, source.health(STATION))
	assert_eq(after_stop["body"]["running"], false, "health stays stopped")
	var listed := []
	source.stations.connect(func(list: Array) -> void: listed.append(list))
	await _call(source, got, source.list_stations())
	assert_eq(listed[0][0]["status"], "stopped", "the station list follows the lifecycle")

	var started := await _call(source, got, source.lifecycle(STATION, "start"))
	assert_eq(started["body"]["running"], true, "started again")
	assert_true(started["body"]["pid"] != pid, "as a new process")
	assert_eq(started["body"]["uptimeSec"], 0, "whose uptime starts over")

	var refused := await _call(source, got, source.lifecycle(STATION, "explode"))
	assert_eq(refused["ok"], false, "an unknown action is refused")
	assert_eq(refused["body"]["kind"], "failed")


func test_files_list_fs_entries_and_read_text_and_bytes() -> void:
	var source := _source()
	var got := _results(source)
	var root := await _call(source, got, source.files(STATION, "."))
	assert_true(root["ok"], "the root lists")
	var names := []
	for entry in root["body"]:
		_assert_shape(entry, FS_ENTRY_KEYS, "FsEntry")
		assert_true(entry["type"] in ["file", "dir", "symlink"], "a known entry type")
		names.append(entry["name"])
	assert_true("src" in names and "Cargo.toml" in names, "the invented project: %s" % [names])
	var src := await _call(source, got, source.files(STATION, "src/"))
	assert_eq(src["body"][0]["path"], "src/lib.rs", "paths are relative to the workspace, trailing slash or not")

	var text := await _call(source, got, source.file(STATION, "src/lib.rs", 0))
	assert_true(text["ok"], "a text file reads")
	assert_eq(_keys(text["body"]), ["text", "truncated"])
	assert_true(text["body"]["text"].contains("split_whitespace"), "the fixed source")
	assert_eq(text["body"]["truncated"], false)

	var cut := await _call(source, got, source.file(STATION, "src/lib.rs", 16))
	assert_eq(cut["body"]["text"].length(), 16, "maxBytes cuts the body")
	assert_eq(cut["body"]["truncated"], true, "and says so")

	var binary := await _call(source, got, source.file(STATION, "tests/fixtures/latin1.txt", 0))
	assert_eq(_keys(binary["body"]), ["bytes", "truncated"], "text that is not UTF-8 comes back as bytes")
	assert_true(binary["body"]["bytes"] is PackedByteArray)

	var missing := await _call(source, got, source.file(STATION, "src/missing.rs", 0))
	assert_eq(missing["ok"], false, "an unknown path fails")
	assert_eq(missing["status"], 502, "as the node's error does")
	assert_eq(missing["body"]["kind"], "failed")
	var escape := await _call(source, got, source.file(STATION, "../README.md", 0))
	assert_eq(escape["ok"], false, "nothing outside the recorded workspace is read")
	var not_a_dir := await _call(source, got, source.files(STATION, "src/lib.rs"))
	assert_eq(not_a_dir["ok"], false, "a file is not a listing")


func test_the_changeset_and_its_diff() -> void:
	var source := _source()
	var got := _results(source)
	var status := await _call(source, got, source.changeset_status(STATION, ""))
	assert_true(status["ok"])
	var body: Dictionary = status["body"]
	_assert_shape(body, CHANGESET_KEYS, "ChangesetStatus")
	assert_eq(_keys(body["repo"]), ["branch", "detached", "head"])
	assert_eq(_keys(body["base"]), ["reason", "ref", "sha"])
	assert_true(body["base"]["reason"] in ["explicit", "upstream", "default-branch", "head"])
	assert_eq(_keys(body["uncommitted"]), ["deletions", "files", "insertions"])
	assert_eq(_keys(body["committed"]), ["commits", "deletions", "files", "insertions"])
	for side in ["uncommitted", "committed"]:
		for f in body[side]["files"]:
			_assert_shape(f, CHANGESET_FILE_KEYS, "ChangesetFile")
	for c in body["committed"]["commits"]:
		_assert_shape(c, COMMIT_KEYS, "ChangesetCommit")

	var uncommitted := await _call(source, got, source.changeset_diff(STATION, "uncommitted", ""))
	_assert_shape(uncommitted["body"], DIFF_KEYS, "ChangesetDiff")
	var content: String = uncommitted["body"]["content"]
	assert_true(content.begins_with("diff --git a/src/lib.rs"), "the uncommitted side is the fix")
	assert_true(not content.contains("tests/count.rs"), "and only the fix")

	var one := await _call(source, got, source.changeset_diff(STATION, "committed", "tests/count.rs"))
	var one_content: String = one["body"]["content"]
	assert_true(one_content.begins_with("diff --git a/tests/count.rs"), "one file's diff")
	assert_true(not one_content.contains("src/main.rs"), "and nothing else")
	var bad_side := await _call(source, got, source.changeset_diff(STATION, "sideways", ""))
	assert_eq(bad_side["ok"], false, "an unknown side is refused")


func test_the_changeset_against_an_explicit_base_and_an_unknown_one() -> void:
	var source := _source()
	var got := _results(source)
	var explicit := await _call(source, got, source.changeset_status(STATION, "origin/main"))
	assert_true(explicit["ok"], "the recorded base, named")
	assert_eq(explicit["body"]["base"]["ref"], "origin/main")
	assert_eq(explicit["body"]["base"]["reason"], "explicit", "a named base is explicit, not the upstream")
	var unknown := await _call(source, got, source.changeset_status(STATION, "origin/nowhere"))
	assert_eq(unknown["ok"], false, "a base the workspace does not have fails")
	assert_eq(unknown["status"], 502, "as the node's error does")
	assert_eq(unknown["body"]["kind"], "failed")


func test_an_unknown_station_is_not_found() -> void:
	var source := _source()
	var got := _results(source)
	var answer := await _call(source, got, source.health("stn_elsewhere"))
	assert_eq(answer["ok"], false)
	assert_eq(answer["status"], 404)
	assert_eq(_keys(answer["body"]), ["kind", "message"], "errors normalise to kind and message")
	assert_eq(answer["body"]["kind"], "not_found")
	var stream := source.open_terminal("stn_elsewhere")
	var failures := []
	stream.failed.connect(func(reason: Dictionary) -> void: failures.append(reason))
	await _until(func() -> bool: return not failures.is_empty())
	assert_eq(failures.size(), 1, "a stream to it fails")
	assert_eq(failures[0].get("kind", ""), "not_found")
	assert_eq(stream.state, "closed")


func test_the_log_tail_arrives_line_by_line() -> void:
	var source := _source()
	var stream := source.open_logs(STATION)
	var states := []
	var lines := []
	stream.state_changed.connect(func(state: String) -> void: states.append(state))
	stream.line.connect(func(text: String) -> void: lines.append(text))
	assert_eq(stream.state, "connecting", "a stream starts connecting")
	assert_eq(lines.size(), 0, "nothing arrives inside the call")
	await _until(func() -> bool: return lines.size() >= 55)
	assert_eq(states.front(), "open", "then opens")
	assert_eq(lines.size(), 55, "every recorded line, the tail and then the follow")
	assert_true(lines[0].contains("sample-harness"), "in order: %s" % lines[0])
	assert_true(not lines[0].ends_with("\n"), "one line a signal, without its newline")
	stream.close()
	assert_eq(stream.state, "closed")
	assert_eq(states.back(), "closed")


func test_the_terminal_replays_echoes_typing_and_plays_a_command_on_enter() -> void:
	var source := _source()
	var terminal := source.open_terminal(STATION)
	var out := PackedByteArray()
	terminal.data.connect(func(bytes: PackedByteArray) -> void: out.append_array(bytes))
	var grid = ClassDB.instantiate("TermGrid")
	grid.setup(80, 24)
	terminal.data.connect(func(bytes: PackedByteArray) -> void: grid.feed(bytes))
	terminal.send_resize(100, 30)
	await _until(func() -> bool: return out.get_string_from_utf8().ends_with("$ "))
	var intro := out.get_string_from_utf8()
	assert_true(intro.contains("synthetic recording"), "the banner says it is a recording")
	assert_true(not intro.contains("cargo"), "and it waits at the prompt for Enter")

	out.clear()
	terminal.send_input("ls")
	await _until(func() -> bool: return out.size() >= 2)
	assert_eq(out.get_string_from_utf8(), "ls", "typing is echoed")
	terminal.send_input("\u007f")
	await _until(func() -> bool: return out.size() >= 5)
	assert_eq(out.slice(2).get_string_from_utf8(), "\b \b", "Backspace rubs a character out")

	out.clear()
	terminal.send_input("\r")
	await _until(func() -> bool: return out.get_string_from_utf8().contains("Finished"))
	var first := out.get_string_from_utf8()
	assert_true(first.begins_with("\b \b"), "Enter clears what was typed")
	assert_true(first.contains("cargo build"), "and plays the first recorded command")
	await _until(func() -> bool: return out.get_string_from_utf8().ends_with("$ "))

	out.clear()
	terminal.send_input("\r")
	await _until(func() -> bool: return out.get_string_from_utf8().contains("error"))
	await _until(func() -> bool: return out.get_string_from_utf8().ends_with("$ "))
	assert_true(out.get_string_from_utf8().contains("FAILED"), "the second is the failing test run")
	var screen := ""
	for row in 24:
		for run in grid.row_runs(row):
			screen += run["text"]
		screen += "\n"
	assert_true(screen.contains("test result: FAILED. 6 passed; 1 failed"), "TermGrid reads the bytes: %s" % screen)
	terminal.close()
	assert_eq(terminal.state, "closed")


func test_the_terminal_ends_on_ctrl_d() -> void:
	var source := _source()
	var terminal := source.open_terminal(STATION)
	var exits := []
	terminal.exited.connect(func() -> void: exits.append(true))
	await _until(func() -> bool: return terminal.state == "open")
	terminal.send_input("\u0004")
	await _until(func() -> bool: return not exits.is_empty())
	assert_eq(exits.size(), 1, "Ctrl-D on an empty line logs out")
	assert_eq(terminal.state, "closed")


func test_the_chat_replays_and_answers_its_permission_request() -> void:
	var source := _source()
	var chat := source.open_chat(STATION, "ask")
	var rows := []
	var events := []
	var done := []
	chat.session.connect(func(row: Dictionary) -> void: rows.append(row))
	chat.event.connect(func(event: Dictionary) -> void: events.append(event))
	chat.replay_done.connect(func(last_seq: int) -> void: done.append(last_seq))
	await _until(func() -> bool: return not done.is_empty())
	assert_eq(rows.size(), 1, "the session row comes first")
	_assert_shape(rows[0], SESSION_KEYS, "AcpSessionRow")
	assert_eq(rows[0]["status"], "waiting", "waiting on a permission answer")
	assert_eq(done[0], events.back()["seq"], "replay-done carries the last seq")

	var request := {}
	var saw_text := false
	var saw_tool_call := false
	var seq := 0
	for event in events:
		_assert_shape(event, EVENT_KEYS, "AcpEvent")
		assert_true(event["type"] in ACP_EVENT_TYPES, "a known event type: %s" % event["type"])
		assert_true(event["seq"] > seq, "seq rises")
		seq = event["seq"]
		if event["type"] == "state":
			assert_true(event["payload"]["status"] in ACP_STATUSES)
		if event["type"] == "agent-update":
			var update: String = event["payload"]["sessionUpdate"]
			saw_text = saw_text or update == "agent_message_chunk"
			saw_tool_call = saw_tool_call or update == "tool_call"
		if event["type"] == "permission-request":
			request = event
	assert_true(saw_text and saw_tool_call, "text chunks and a tool call")
	assert_eq(_keys(request.get("payload", {})), ["options", "toolCall"], "one permission request")
	for option in request["payload"]["options"]:
		assert_eq(_keys(option), ["kind", "name", "optionId"])
		assert_true(option["kind"] in ["allow_once", "allow_always", "reject_once", "reject_always"])

	events.clear()
	chat.answer(request["seq"], "opt_allow_once")
	assert_eq(events.size(), 0, "the answer plays later, not inside the call")
	await _until(func() -> bool: return not events.is_empty() and events.back()["type"] == "state" \
			and events.back()["payload"]["status"] == "idle")
	assert_eq(events[0]["type"], "permission-answer", "the hub records the answer first")
	assert_eq(events[0]["payload"], {"requestSeq": request["seq"], "optionId": "opt_allow_once"})
	assert_eq(events[0]["seq"], done[0] + 1, "continuing the session's seq")
	assert_eq(events[1]["payload"], {"status": "working"})
	var finished := false
	for event in events:
		if event["type"] == "agent-update" and event["payload"]["sessionUpdate"] == "agent_message_chunk":
			finished = finished or event["payload"]["content"]["text"].contains("All 7 tests pass")
	assert_true(finished, "the recorded continuation plays")

	events.clear()
	chat.answer(request["seq"], "opt_allow_once")
	await _until(func() -> bool: return not events.is_empty())
	assert_eq(events[0]["type"], "error", "a second answer is an error event")
	assert_eq(events[0]["seq"], 0, "outside the transcript, as the hub's are")


func test_the_chat_takes_a_prompt_and_a_reopened_chat_replays_everything() -> void:
	var source := _source()
	var chat := source.open_chat(STATION, "ask")
	var events := []
	chat.event.connect(func(event: Dictionary) -> void: events.append(event))
	await _until(func() -> bool: return not events.is_empty() and events.back()["type"] == "state")

	chat.prompt("hello")
	await _until(func() -> bool: return events.back()["type"] == "error")
	assert_eq(events.back()["seq"], 0, "a prompt while the agent waits is refused, as the hub does")

	chat.cancel()
	await _until(func() -> bool: return events.back()["type"] == "state" and events.back()["payload"]["status"] == "idle")
	assert_eq(events[-2]["type"], "permission-answer", "cancelling answers the request as cancelled")
	assert_eq(events[-2]["payload"]["cancelled"], true)

	chat.set_mode("accept-edits")
	chat.prompt("What's left to do?")
	await _until(func() -> bool: return events.back()["type"] == "state" and events.back()["payload"]["status"] == "idle" \
			and events[-2]["type"] == "agent-update")
	var prompt_event := {}
	for event in events:
		if event["type"] == "user-prompt" and event["payload"]["text"] == "What's left to do?":
			prompt_event = event
	assert_true(not prompt_event.is_empty(), "the prompt joins the transcript")

	chat.close()
	var again := source.open_chat(STATION, "ask")
	var replayed := []
	var rows := []
	again.event.connect(func(event: Dictionary) -> void: replayed.append(event))
	again.session.connect(func(row: Dictionary) -> void: rows.append(row))
	var done := []
	again.replay_done.connect(func(last_seq: int) -> void: done.append(last_seq))
	await _until(func() -> bool: return not done.is_empty())
	assert_eq(rows[0]["mode"], "accept-edits", "the session kept its mode")
	assert_eq(rows[0]["status"], "idle")
	assert_eq(replayed.back()["seq"], done[0], "the whole session replays")
	assert_true(replayed.any(func(e): return e["seq"] == prompt_event["seq"]), "with the new prompt in it")


func test_an_empty_prompt_and_an_unknown_mode_are_refused() -> void:
	var source := _source()
	var chat := source.open_chat(STATION, "ask")
	var events := []
	chat.event.connect(func(event: Dictionary) -> void: events.append(event))
	await _until(func() -> bool: return not events.is_empty() and events.back()["type"] == "state")
	chat.cancel()
	await _until(func() -> bool: return events.back()["type"] == "state" and events.back()["payload"]["status"] == "idle")
	var recorded: int = events.back()["seq"]

	chat.prompt("")
	await _until(func() -> bool: return events.back()["type"] == "error")
	assert_eq(events.back()["seq"], 0, "an empty prompt is refused outside the transcript")
	assert_eq(events.back()["payload"]["message"], "Invalid message.", "as the hub refuses an invalid message")
	for _frame in 5:
		await runner.process_frame
	assert_true(not events.any(func(e): return e["type"] == "user-prompt" and e["seq"] > recorded), "and nothing is recorded")

	chat.set_mode("reckless")
	var refusals := func() -> Array: return events.filter(func(e): return e["type"] == "error")
	await _until(func() -> bool: return refusals.call().size() >= 2)
	assert_eq(refusals.call().size(), 2, "an unknown mode is refused too")
	assert_eq(refusals.call()[1]["payload"]["message"], "Invalid message.")
	chat.close()
	var again := source.open_chat(STATION, "ask")
	var rows := []
	again.session.connect(func(row: Dictionary) -> void: rows.append(row))
	await _until(func() -> bool: return not rows.is_empty())
	assert_eq(rows[0]["mode"], "ask", "and the session keeps its mode")


## Ending the session, as `DELETE /api/acp/sessions/:id` does: a waiting
## request is answered as cancelled, the session ends with the hub's
## reason, and its chats close. The next chat opens a new, empty session in
## the mode asked for.
func test_ending_the_chat_and_opening_a_new_session() -> void:
	var source := _source()
	var got := _results(source)
	var chat := source.open_chat(STATION, "ask")
	var events := []
	var done := []
	chat.event.connect(func(event: Dictionary) -> void: events.append(event))
	chat.replay_done.connect(func(last_seq: int) -> void: done.append(last_seq))
	await _until(func() -> bool: return not done.is_empty())
	var nowhere := await _call(source, got, source.end_chat("acps_nowhere"))
	assert_eq([nowhere["ok"], nowhere["status"]], [false, 404], "an unknown session is not found")
	var ended := await _call(source, got, source.end_chat("acps_sample"))
	assert_eq([ended["ok"], ended["status"]], [true, 204], "ended")
	await _until(func() -> bool: return chat.state == "closed")
	assert_eq(chat.state, "closed", "and its chat closed, as the hub's bye does")
	var tail := events.slice(events.size() - 2)
	assert_eq(tail[0]["payload"], {"requestSeq": done[0] - 1, "cancelled": true}, "the waiting request cancelled")
	assert_eq(tail[1]["payload"], {"status": "ended", "reason": "Ended from the console."}, "then the end")
	var again := await _call(source, got, source.end_chat("acps_sample"))
	assert_eq(again["ok"], true, "ending it again is harmless")

	var fresh := source.open_chat(STATION, "accept-edits")
	var rows := []
	var replayed := []
	fresh.session.connect(func(row: Dictionary) -> void: rows.append(row))
	fresh.event.connect(func(event: Dictionary) -> void: replayed.append(event))
	await _until(func() -> bool: return not rows.is_empty())
	_assert_shape(rows[0], SESSION_KEYS, "AcpSessionRow")
	assert_true(rows[0]["id"] != "acps_sample", "a new session: %s" % rows[0]["id"])
	assert_eq(rows[0]["mode"], "accept-edits", "in the mode asked for")
	assert_eq(rows[0]["status"], "idle")
	assert_eq(replayed.map(func(e): return [e["seq"], e["type"]]), [[1, "state"]], "starting its own seq")
	fresh.close()


## Watching attaches to the open session and replays it, without starting
## one: once the session has ended, watching fails "No session" and the
## session stays ended, where opening the chat would start a new one.
func test_watching_the_chat_attaches_and_never_starts_a_session() -> void:
	var source := _source()
	var got := _results(source)
	var watched := source.watch_chat(STATION)
	var rows := []
	var done := []
	watched.session.connect(func(row: Dictionary) -> void: rows.append(row))
	watched.replay_done.connect(func(last_seq: int) -> void: done.append(last_seq))
	await _until(func() -> bool: return not done.is_empty())
	assert_eq(rows.map(func(r): return r["id"]), ["acps_sample"], "the open session, replayed")
	watched.close()
	await _call(source, got, source.end_chat("acps_sample"))
	var after := source.watch_chat(STATION)
	var failures := []
	after.failed.connect(func(reason: Dictionary) -> void: failures.append(reason))
	await _until(func() -> bool: return after.state == "closed")
	assert_eq(failures, [StationSource.make_error("not_found", StationSource.NO_SESSION)], "no session to watch")
	var again := source.watch_chat(STATION)
	await _until(func() -> bool: return again.state == "closed")
	assert_eq(again.state, "closed", "still none: watching started nothing")


func test_the_board_stream_opens_with_its_snapshot() -> void:
	var source := _source()
	var got := _results(source)
	var boards := await _call(source, got, source.boards())
	assert_eq(boards["body"], {"boards": [{"id": BOARD, "name": "Sample board"}]})
	var agents := await _call(source, got, source.agents())
	_assert_shape(agents["body"]["agents"][0], AGENT_KEYS, "AgentRecord")

	var stream := source.board(BOARD)
	var snapshots := []
	stream.snapshot.connect(func(state: Dictionary) -> void: snapshots.append(state))
	await _until(func() -> bool: return not snapshots.is_empty())
	var snapshot: Dictionary = snapshots[0]
	_assert_shape(snapshot, SNAPSHOT_KEYS, "BoardSnapshot")
	assert_eq(snapshot["name"], "Sample board")
	for card in snapshot["cards"]:
		_assert_shape(card, CARD_KEYS, "CardView")
		assert_true(card["state"] in TASK_STATES, "a known card state")
	for gate in snapshot["gates"]:
		_assert_shape(gate, GATE_KEYS, "GateView")
	for question in snapshot["elicitations"]:
		_assert_shape(question, ELICITATION_KEYS, "ElicitationView")
		for option in question["options"]:
			_assert_shape(option, ELICITATION_OPTION_KEYS, "an elicitation's option")
			assert_true(option["interactive"] is bool, "interactive is a flag")
		assert_true(question["options"].any(func(o): return o["interactive"]), "one option also takes text")
	var at_review: Array = snapshot["cards"].filter(func(c): return c["currentStageKey"] == "review")
	assert_eq(at_review.size(), 1, "one card at review")
	assert_eq(snapshot["gates"].filter(func(g): return g["status"] == "pending").size(), 1, "one pending gate")
	assert_eq(snapshot["elicitations"].filter(func(e): return e["status"] == "pending").size(), 1, "one open question")

	var history := await _call(source, got, source.card_activities(BOARD, "crd_sample_tabs"))
	assert_eq(_keys(history["body"]), ["activities", "gates", "handoff"])
	for activity in history["body"]["activities"]:
		_assert_shape(activity, ACTIVITY_KEYS, "ActivityView")
	assert_eq(history["body"]["gates"][0]["id"], "gate_sample", "the card's gates ride along")
	stream.close()


func test_resolving_the_gate_plays_its_result() -> void:
	var source := _source()
	var got := _results(source)
	var stream := source.board(BOARD)
	var events := []
	stream.board_event.connect(func(event: Dictionary) -> void: events.append(event))
	await _until(func() -> bool: return stream.state == "open")

	var bad := await _call(source, got, source.resolve_gate(BOARD, "gate_sample", "shrug", ""))
	assert_eq(bad["ok"], false, "only the three decisions")
	var answer := await _call(source, got, source.resolve_gate(BOARD, "gate_sample", "approve", "Looks right."))
	assert_true(answer["ok"], "the gate resolves")
	assert_eq(_keys(answer["body"]), ["card"], "answering with the card")
	assert_eq(answer["body"]["card"]["currentStageKey"], "done", "which moves on")
	await _until(func() -> bool: return events.size() >= 2)
	for event in events:
		_assert_shape(event, BOARD_EVENT_KEYS, "the board's event")
	assert_eq(events.map(func(e): return e["type"]), ["card.advanced", "gate.resolved"])
	assert_eq(events[1]["payload"]["decision"], "approve")
	assert_true(events[1]["seq"] > 0 and events[0]["seq"] < events[1]["seq"], "seq rises")

	var again := await _call(source, got, source.resolve_gate(BOARD, "gate_sample", "reject", ""))
	assert_eq(again["ok"], false, "a resolved gate cannot be resolved twice")
	assert_eq(again["status"], 409)
	assert_eq(again["body"]["kind"], "conflict")
	var reopened := source.board(BOARD)
	var later := []
	reopened.snapshot.connect(func(state: Dictionary) -> void: later.append(state))
	await _until(func() -> bool: return not later.is_empty())
	assert_eq(later[0]["gates"][0]["status"], "resolved", "a new snapshot holds the result")
	assert_eq(later[0]["gates"][0]["comment"], "Looks right.")


func test_answering_the_question_plays_the_agents_next_activities() -> void:
	var source := _source()
	var got := _results(source)
	var stream := source.board(BOARD)
	var events := []
	stream.board_event.connect(func(event: Dictionary) -> void: events.append(event))
	await _until(func() -> bool: return stream.state == "open")

	var unknown := await _call(source, got, source.answer(BOARD, "elc_sample", "sideways", ""))
	assert_eq(unknown["ok"], false, "an option must be one offered")
	var answer := await _call(source, got, source.answer(BOARD, "elc_sample", "array", ""))
	assert_true(answer["ok"], "the question is answered")
	assert_eq(_keys(answer["body"]), ["card", "elicitation"])
	assert_eq(answer["body"]["elicitation"]["status"], "answered")
	assert_eq(answer["body"]["elicitation"]["answer"]["option"], "array")
	assert_eq(answer["body"]["elicitation"]["answer"]["text"], null)
	assert_eq(answer["body"]["card"]["state"], "working", "the card resumes")
	await _until(func() -> bool: return events.size() >= 3)
	assert_eq(events[0]["type"], "elicitation.answered")
	assert_eq(events[1]["type"], "activity", "then the agent's recorded next steps")
	var history := await _call(source, got, source.card_activities(BOARD, "crd_sample_json"))
	var types: Array = history["body"]["activities"].map(func(a): return a["type"])
	assert_true(types.has("prompt"), "the answer joins the card's activities: %s" % [types])


func test_a_move_into_a_full_stage_is_a_conflict() -> void:
	var source := _source()
	var got := _results(source)
	var full := await _call(source, got, source.move_card(BOARD, "crd_sample_files", "build"))
	assert_eq(full["ok"], false, "Build holds one card")
	assert_eq(full["status"], 409)
	assert_eq(full["body"]["kind"], "conflict")
	assert_true(full["body"]["message"].contains("WIP limit"), "the board's own message")
	var moved := await _call(source, got, source.move_card(BOARD, "crd_sample_files", "review"))
	assert_true(moved["ok"], "a move elsewhere works")
	assert_eq(moved["body"]["card"]["currentStageKey"], "review")
	var nowhere := await _call(source, got, source.move_card(BOARD, "crd_sample_files", "moon"))
	assert_eq(nowhere["ok"], false, "an unknown stage is refused")


func test_nothing_reaches_the_network() -> void:
	# Read the player's own source, sample_source.gd and every file of its
	# helpers under sample/: no network class is named in any of them, and
	# the only files they read are the recording's.
	var scripts := ["res://core/station/sample_source.gd"]
	for name in DirAccess.get_files_at("res://core/station/sample"):
		if name.ends_with(".gd"):
			scripts.append("res://core/station/sample/" + name)
	assert_true(scripts.size() >= 7, "the source and its six helpers are scanned: %s" % [scripts])
	var regex := RegEx.create_from_string("res://[A-Za-z_./]*")
	for path in scripts:
		var text := FileAccess.get_file_as_string(path)
		assert_true(not text.is_empty(), "%s reads" % path)
		for name in ["HTTPClient", "HTTPRequest", "WebSocketPeer", "TCPServer", "StreamPeerTCP", "PacketPeerUDP",
				"new_network_object", "ClassDB", "OS.execute", "user://", "DirAccess"]:
			assert_true(not text.contains(name), "%s never mentions %s" % [path.get_file(), name])
		for found in regex.search_all(text):
			assert_true(
				found.get_string().begins_with("res://sample_station/"),
				"%s reads only the recording: %s" % [path.get_file(), found.get_string()]
			)

	# And at run time: every network object a source makes goes through
	# StationSource.new_network_object, which counts. Playing everything
	# the sample has leaves the count where it was.
	var before := StationSource.network_objects_created
	var source := _source()
	var got := _results(source)
	var ids := [
		source.list_stations(), source.health(STATION), source.files(STATION, "."),
		source.file(STATION, "Cargo.toml", 0), source.lifecycle(STATION, "restart"),
		source.changeset_status(STATION, ""), source.changeset_diff(STATION, "committed", ""),
		source.boards(), source.agents(), source.card_activities(BOARD, "crd_sample_json"),
		source.move_card(BOARD, "crd_sample_files", "backlog"),
		source.resolve_gate(BOARD, "gate_sample", "request_changes", "Split on tabs only."),
		source.answer(BOARD, "elc_sample", "other", "Newline-delimited JSON."),
	]
	var logs := source.open_logs(STATION)
	var terminal := source.open_terminal(STATION)
	var chat := source.open_chat(STATION, "ask")
	var board := source.board(BOARD)
	terminal.send_input("\r")
	await _until(func() -> bool: return got.size() == ids.size())
	for call_id in ids:
		assert_true(got[call_id]["ok"], "call %d answered from the recording" % call_id)
	for stream in [logs, terminal, chat, board]:
		stream.close()
	assert_eq(StationSource.network_objects_created, before, "no network object was made")

	# The counter is real: making one moves it.
	var probe = StationSource.new_network_object("StreamPeerBuffer")
	assert_eq(StationSource.network_objects_created, before + 1, "the hook counts what it makes")
	assert_true(probe is StreamPeerBuffer)
	StationSource.network_objects_created = before


func test_the_recording_is_marked_synthetic_and_holds_no_real_paths() -> void:
	var readme := FileAccess.get_file_as_string("res://sample_station/README.md")
	assert_true(readme.contains("synthetic"), "the README says it is synthetic")
	assert_true(readme.contains("no real station's data"), "and holds no real station's data")
	for name in ["station.json", "terminal.cast", "chat.json", "files.json", "logs.txt", "health.json",
			"changeset.json", "diff.patch", "work.json"]:
		var text := FileAccess.get_file_as_string("res://sample_station/" + name)
		assert_true(not text.is_empty(), name + " is bundled")
		for forbidden in ["/home/", "/Users/", "C:\\\\Users", "Bearer ", "superjackfruit"]:
			assert_true(not text.to_lower().contains(forbidden.to_lower()), "%s holds no %s" % [name, forbidden])
