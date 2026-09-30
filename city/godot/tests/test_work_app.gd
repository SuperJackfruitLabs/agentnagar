## The station computer's Work app (Part B's Task 7): the station agent's
## Superpipeline cards, gates and questions, against Sample station and a
## scripted stub board (station_stubs.gd).
extends "res://tests/station_stubs.gd"


static func work_card(id: String, title: String, stage: String, state: String, delegate: Variant) -> Dictionary:
	return {"id": id, "title": title, "spec": "", "ownerUserId": "usr_a", "queuedBy": "usr_a", "queuedGrant": null,
		"currentStageKey": stage, "state": state, "delegateAgentId": delegate, "priority": 0, "contextId": null,
		"createdAt": "2026-09-29T00:00:00.000Z", "updatedAt": null, "costUsd": 0, "overBudget": false, "attemptCount": 1}


static func work_gate(id: String, card_id: String, status: String, produced_by: String) -> Dictionary:
	return {"id": id, "cardId": card_id, "stageKey": "review", "status": status,
		"decision": null if status != "resolved" else "approve", "options": [], "producedBy": produced_by,
		"createdAt": "2026-09-29T00:00:00.000Z", "decidedBy": null, "comment": null, "resolvedAt": null}


static func work_question(id: String, card_id: String, agent_id: String, options: Array, status := "pending") -> Dictionary:
	return {"id": id, "cardId": card_id, "runId": "run_" + id, "stageKey": "build", "agentId": agent_id,
		"question": "Question " + id + "?", "signal": null, "options": options, "status": status, "answer": null,
		"createdAt": "2026-09-29T00:00:00.000Z"}


## A board whose cards test the filter: agt_a's by delegation, by a pending
## gate it produced and by an open question it asked, and others' or
## settled ones that are not agt_a's.
static func work_board(board_id := "brd_a", name := "Launch board") -> Dictionary:
	return {
		"boardId": board_id, "tenantId": "tnt_a", "name": name,
		"stages": [
			{"key": "review", "name": "Review", "order": 2, "ownerKind": "human", "gate": "approval"},
			{"key": "backlog", "name": "Backlog", "order": 0, "ownerKind": "human"},
			{"key": "build", "name": "Build", "order": 1, "ownerKind": "capability", "owner": "code", "wipLimit": 2},
			{"key": "done", "name": "Done", "order": 3, "ownerKind": "human"},
		],
		"cards": [
			work_card("crd_mine", "Delegated to agt_a", "build", "working", "agt_a"),
			work_card("crd_theirs", "Delegated to agt_b", "build", "working", "agt_b"),
			work_card("crd_gated", "At agt_a's gate", "review", "input-required", null),
			work_card("crd_asked", "Asked by agt_a", "build", "input-required", null),
			work_card("crd_settled", "Its gate settled", "done", "completed", null),
			work_card("crd_moved", "Its gate cancelled", "backlog", "submitted", null),
			work_card("crd_other_gate", "At agt_b's gate", "review", "input-required", null),
			work_card("crd_answered", "Its question answered", "build", "working", null),
		],
		"gates": [
			work_gate("gate_1", "crd_gated", "pending", "agt_a"),
			work_gate("gate_2", "crd_settled", "resolved", "agt_a"),
			work_gate("gate_3", "crd_moved", "cancelled", "agt_a"),
			work_gate("gate_4", "crd_other_gate", "pending", "agt_b"),
		],
		"elicitations": [
			work_question("elc_1", "crd_asked", "agt_a", []),
			work_question("elc_2", "crd_answered", "agt_a", [], "answered"),
		],
		"references": [], "usage": {}, "github": {},
	}


const WORK_AGENTS := {"agents": [
	{"id": "agt_a", "tenantId": "tnt_a", "name": "Agent A", "capabilities": ["code"]},
	{"id": "agt_b", "tenantId": "tnt_a", "name": "Agent B", "capabilities": ["code"]},
]}


## Opens Work with the tests' own links file, emptied first when `fresh`.
func open_work(source: StationSource, row: Dictionary, fresh := true, read_only := false) -> WorkApp:
	if fresh:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LINKS_FILE))
	var app := ComputerScreen.make_app("work") as WorkApp
	app.links_path = LINKS_FILE
	app.ui = UiTheme.from_style({})
	app.setup(source, row, read_only)
	runner.root.add_child(app)
	app.restyle()
	app.size = Vector2(1200, 640)
	return app


## Opens Work on a stub whose station is linked to agt_a, with `boards` open.
func open_linked_work(boards := [work_board()], live := false) -> Array:
	var source := StubSource.new()
	source.live = live
	source.built_in_links = {"stn_a": "agt_a"}
	var app := open_work(source, station_row())
	source.reply("agents", WORK_AGENTS)
	source.reply("boards", {"boards": boards.map(func(b): return {"id": b["boardId"], "name": b["name"]})})
	for i in boards.size():
		source.board_streams[i].send_snapshot(boards[i])
	return [source, app]


## The first time Work opens for a station it asks which agent works there,
## listing the agents and None; the answer is kept on the device, IDs only,
## and not asked again.
func test_work_asks_which_agent_and_remembers() -> void:
	var source := StubSource.new()
	var app := open_work(source, station_row())
	assert_true(app.link_prompt.visible, "it asks")
	assert_true(app.text().contains(WorkApp.WHICH_AGENT), "in those words: %s" % app.text())
	assert_eq(source.calls_to("boards"), [], "and opens no board yet")
	source.reply("agents", WORK_AGENTS)
	assert_eq(app.link_choices(), ["Agent A", "Agent B", WorkApp.NONE], "each agent, and None")
	app.choose_link(0)
	assert_true(not app.link_prompt.visible, "answered")
	assert_eq(app.linked_agent, "agt_a")
	assert_eq(source.calls_to("boards").size(), 1, "then the boards open")
	var stored := FileAccess.get_file_as_string(LINKS_FILE)
	assert_true(stored.contains("stn_a") and stored.contains("agt_a"), "kept by station: %s" % stored)
	assert_true(not stored.contains("Agent A") and not stored.contains("Build box"), "IDs only: %s" % stored)
	close(app)

	source = StubSource.new()
	app = open_work(source, station_row(), false)
	assert_true(not app.link_prompt.visible, "remembered")
	assert_eq(app.linked_agent, "agt_a")
	assert_eq(source.calls_to("boards").size(), 1, "the boards open at once")
	app.change_link_button.pressed.emit()
	assert_true(app.link_prompt.visible, "it can be changed")
	source.reply("agents", WORK_AGENTS)
	app.choose_link(2)
	assert_eq(app.linked_agent, "", "None")
	assert_true(app.text().contains(WorkApp.NO_AGENT), "says so: %s" % app.text())
	close(app)

	source = StubSource.new()
	app = open_work(source, station_row(), false)
	assert_true(not app.link_prompt.visible, "None is remembered too")
	assert_eq(source.calls_to("boards"), [], "and opens no boards")
	close(app)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LINKS_FILE))


## Sample station's link is built in: no question, and nothing written.
func test_work_on_the_sample_needs_no_link_question() -> void:
	var app := open_work(sample(), sample_row())
	assert_true(not app.link_prompt.visible, "no question")
	assert_eq(app.linked_agent, "agt_sample")
	assert_true(await until(func() -> bool: return app.shown_cards().size() == 2), "its cards show")
	assert_eq(app.shown_cards(), ["crd_sample_json", "crd_sample_tabs"], "by stage: build, then review")
	assert_true(not FileAccess.file_exists(LINKS_FILE), "nothing kept on the device")
	assert_true(app.text().contains("Sample board") and app.text().contains("Build") and app.text().contains("Review"),
		"grouped by board and stage: %s" % app.text())
	close(app)


## The cards shown are the linked agent's: delegated to it, or waiting at a
## gate it produced, or on a question it asked. Each has a state chip.
func test_work_filters_cards_by_the_linked_agent() -> void:
	var pair := open_linked_work([work_board(), work_board("brd_b", "Second board")])
	var source: StubSource = pair[0]
	var app: WorkApp = pair[1]
	assert_eq(source.calls_to("board").map(func(c): return c["args"][0]), ["brd_a", "brd_b"], "each board opens")
	assert_eq(app.shown_cards(), ["crd_mine", "crd_asked", "crd_gated", "crd_mine", "crd_asked", "crd_gated"],
		"agt_a's cards, board by board, stage by stage")
	assert_eq(app.card_row("brd_a", "crd_mine").state_chip.text, "Working", "with a state chip")
	assert_eq(app.card_row("brd_a", "crd_gated").state_chip.text, "Input required")
	assert_true(app.text().contains("Second board"), "under each board's name")
	close(app)


## The gate's three decisions: approve at once; request changes and reject
## ask first, naming the board, and say they are real when live. Each
## sends its decision and the comment.
func test_work_gate_decisions_send_the_right_body() -> void:
	for live in [false, true]:
		var pair := open_linked_work([work_board()], live)
		var source: StubSource = pair[0]
		var app: WorkApp = pair[1]
		var row := app.card_row("brd_a", "crd_gated")
		assert_true(row.gate_box.visible, "the pending gate shows")
		row.gate_comment.text = "Looks right."
		row.decision_buttons["approve"].pressed.emit()
		assert_eq(source.last("resolve_gate")["args"], ["brd_a", "gate_1", "approve", "Looks right."], "approve, at once")
		# Each decision waits for its answer; this one fails, so the gate stays.
		source.refuse("resolve_gate", "offline")
		for decision in ["request_changes", "reject"]:
			var before := source.calls_to("resolve_gate").size()
			row.gate_comment.text = "Not yet: " + decision
			row.decision_buttons[decision].pressed.emit()
			assert_true(app.confirm_box.visible, "%s asks" % decision)
			assert_true(app.confirm_label.text.contains("Launch board"), "naming the board: %s" % app.confirm_label.text)
			assert_eq(app.confirm_label.text.contains("real"), live, "real only when live: %s" % app.confirm_label.text)
			app.cancel_button.pressed.emit()
			assert_eq(source.calls_to("resolve_gate").size(), before, "cancelled: nothing sent")
			row.decision_buttons[decision].pressed.emit()
			app.confirm_button.pressed.emit()
			assert_eq(source.last("resolve_gate")["args"], ["brd_a", "gate_1", decision, "Not yet: " + decision], decision)
			if decision == "request_changes":
				source.refuse("resolve_gate", "offline")
		source.refuse("resolve_gate", "conflict", "gate is already resolved", 409)
		assert_eq(app.error_text(), "gate is already resolved", "a refusal shows its message")
		close(app)


## The answer's body for each question shape: free text with no options;
## an option alone; an interactive option with its text. Options may lack
## `promptFill` and `interactive`.
func test_work_answer_body_for_each_question_shape() -> void:
	var board := work_board()
	board["elicitations"] = [
		work_question("elc_free", "crd_asked", "agt_a", []),
		work_question("elc_pick", "crd_mine", "agt_a", [{"name": "prod", "title": "Production"},
			{"name": "staging", "title": "Staging"}]),
		work_question("elc_mixed", "crd_gated", "agt_a", [
			{"name": "object", "title": "One object", "promptFill": null, "interactive": false},
			{"name": "other", "title": "Something else", "promptFill": null, "interactive": true}]),
	]
	var pair := open_linked_work([board])
	var source: StubSource = pair[0]
	var app: WorkApp = pair[1]

	var free := app.card_row("brd_a", "crd_asked")
	assert_true(free.question_box.visible and free.answer_field.visible, "free text: a field")
	assert_eq(free.option_buttons.size(), 0, "and no options")
	free.answer_field.text = "  Staging, please.  "
	free.answer_button.pressed.emit()
	assert_eq(source.last("answer")["args"], ["brd_a", "elc_free", "", "Staging, please."], "the text alone")

	var pick := app.card_row("brd_a", "crd_mine")
	assert_eq(pick.option_buttons.keys(), ["prod", "staging"], "choices")
	assert_true(not pick.answer_field.visible, "and no field")
	assert_true(pick.answer_button.disabled, "nothing chosen yet")
	pick.option_buttons["staging"].pressed.emit()
	pick.answer_button.pressed.emit()
	assert_eq(source.last("answer")["args"], ["brd_a", "elc_pick", "staging", ""], "the option alone")

	var mixed := app.card_row("brd_a", "crd_gated")
	mixed.option_buttons["object"].pressed.emit()
	assert_true(not mixed.answer_field.visible, "a plain option takes no text")
	mixed.option_buttons["other"].pressed.emit()
	assert_true(mixed.answer_field.visible, "an interactive one does")
	assert_true(mixed.answer_button.disabled, "and needs it")
	mixed.answer_field.text = "Newline-delimited JSON."
	mixed.answer_field.text_changed.emit(mixed.answer_field.text)
	mixed.answer_button.pressed.emit()
	assert_eq(source.last("answer")["args"], ["brd_a", "elc_mixed", "other", "Newline-delimited JSON."], "both")
	close(app)


## Answering the sample's question in the app plays the recorded result.
func test_work_answers_the_samples_question() -> void:
	var app := open_work(sample(), sample_row())
	assert_true(await until(func() -> bool: return app.shown_cards().size() == 2), "shown")
	var row := app.card_row("brd_sample", "crd_sample_json")
	row.option_buttons["array"].pressed.emit()
	row.answer_button.pressed.emit()
	assert_true(await until(func() -> bool: return not row.question_box.visible), "answered, the question goes")
	assert_eq(row.state_chip.text, "Working", "and the card works again")
	close(app)


## A move the board refuses (a full stage: WIP_LIMIT, 409) shows its message.
func test_a_refused_move_shows_its_message() -> void:
	var app := open_work(sample(), sample_row())
	assert_true(await until(func() -> bool: return app.shown_cards().size() == 2), "shown")
	var row := app.card_row("brd_sample", "crd_sample_tabs")
	assert_eq(row.move_targets(), ["backlog", "build", "done"], "the other stages, in order")
	row.move_to("build")
	assert_true(await until(func() -> bool: return app.error_text() != ""), "refused")
	assert_eq(app.error_text(), 'WIP limit reached for stage "build" (limit 1)', "in the board's words")
	close(app)

	var pair := open_linked_work()
	var source: StubSource = pair[0]
	app = pair[1]
	app.card_row("brd_a", "crd_mine").move_to("done")
	assert_eq(source.last("move_card")["args"], ["brd_a", "crd_mine", "done"], "the move's body")
	var moved := work_card("crd_mine", "Delegated to agt_a", "done", "submitted", "agt_a")
	source.reply("move_card", {"card": moved})
	assert_eq(app.card_row("brd_a", "crd_mine").get_meta("stage"), "done", "the answer's card shows where it went")
	close(app)


## Stream events change the view without asking again; a reconnection's
## snapshot replaces it.
func test_work_follows_the_board_stream() -> void:
	var pair := open_linked_work()
	var source: StubSource = pair[0]
	var app: WorkApp = pair[1]
	var stream: StubBoard = source.board_streams[0]
	var calls := source.calls.size()
	stream.board_event.emit({"seq": 30, "type": "card.moved", "payload": {"cardId": "crd_mine", "from": "build", "to": "review", "by": "usr_a"},
		"ts": "2026-09-29T00:01:00.000Z"})
	assert_eq(app.card_row("brd_a", "crd_mine").get_meta("stage"), "review", "moved")
	stream.board_event.emit({"seq": 31, "type": "gate.resolved", "payload": {"gateId": "gate_1", "cardId": "crd_gated",
		"decision": "approve", "decidedBy": "usr_b"}, "ts": "2026-09-29T00:01:01.000Z"})
	var gated := app.card_row("brd_a", "crd_gated")
	assert_true(gated != null and not gated.gate_box.visible, "a card held only by its gate stays, its gate gone")
	assert_eq(gated.outcome_label.text, WorkCardRow.OUTCOMES["approve"], "marked with what became of it")
	stream.board_event.emit({"seq": 32, "type": "card.rejected", "payload": {"cardId": "crd_asked", "gateId": "x"},
		"ts": "2026-09-29T00:01:02.000Z"})
	assert_eq(app.card_row("brd_a", "crd_asked").state_chip.text, "Rejected", "rejected")
	stream.board_event.emit({"seq": 33, "type": "elicitation.answered", "payload": {"elicitationId": "elc_1",
		"cardId": "crd_asked"}, "ts": "2026-09-29T00:01:03.000Z"})
	var asked := app.card_row("brd_a", "crd_asked")
	assert_true(asked != null and not asked.question_box.visible, "and one held only by its question")
	assert_eq(asked.outcome_label.text, WorkCardRow.ANSWERED, "marked answered")
	stream.board_event.emit({"seq": 33, "type": "card.moved", "payload": {"cardId": "crd_mine", "from": "review", "to": "done"},
		"ts": "2026-09-29T00:01:03.000Z"})
	assert_eq(app.card_row("brd_a", "crd_mine").get_meta("stage"), "review", "an event seen before is not applied again")
	stream.board_event.emit({"seq": 34, "type": "something.new", "payload": {}, "ts": "2026-09-29T00:01:04.000Z"})
	assert_eq(source.calls.size(), calls, "no refetch")
	stream._set_state("offline")
	assert_true(app.text().contains(WorkApp.RECONNECTING), "a dropped board says so: %s" % app.text())
	var fresh := work_board()
	fresh["cards"][0]["title"] = "Renamed while away"
	stream.send_snapshot(fresh)
	assert_true(not app.text().contains(WorkApp.RECONNECTING), "back")
	assert_eq(app.card_row("brd_a", "crd_mine").get_meta("stage"), "build", "the snapshot replaces what the events built")
	assert_true(app.text().contains("Renamed while away"), "all of it")
	close(app)


## Selecting a card shows its activity.
func test_work_shows_a_cards_activity_when_selected() -> void:
	var app := open_work(sample(), sample_row())
	assert_true(await until(func() -> bool: return app.shown_cards().size() == 2), "shown")
	var row := app.card_row("brd_sample", "crd_sample_tabs")
	assert_true(not row.activity.visible, "not until selected")
	row.title_button.pressed.emit()
	assert_true(await until(func() -> bool: return row.activity.visible and row.activity.text.contains("cargo test")),
		"its activity: %s" % row.activity.text)
	assert_true(row.activity.text.contains("Words now split on any whitespace"), "to its last response")
	close(app)


## Watching, Work shows the cards and offers no decision, answer or move.
func test_watched_work_sends_nothing() -> void:
	var app := open_work(sample(), sample_row(), true, true)
	assert_true(await until(func() -> bool: return app.shown_cards().size() == 2), "shown")
	var row := app.card_row("brd_sample", "crd_sample_tabs")
	assert_true(not row.decision_buttons["approve"].is_visible_in_tree(), "no decisions")
	assert_true(not row.move_menu.is_visible_in_tree(), "no moves")
	var asked := app.card_row("brd_sample", "crd_sample_json")
	assert_true(not asked.answer_button.is_visible_in_tree(), "no answers")
	close(app)


## A card stays in view until Work opens again, even once the gate or
## question that made it the agent's is settled; opened again, it is gone.
func test_cards_stay_in_view_until_work_reopens() -> void:
	var app := open_work(sample(), sample_row())
	assert_true(await until(func() -> bool: return app.shown_cards().size() == 2), "shown")
	var row := app.card_row("brd_sample", "crd_sample_tabs")
	row.decision_buttons["approve"].pressed.emit()
	assert_true(await until(func() -> bool: return not row.gate_box.visible), "approved")
	assert_eq(app.card_row("brd_sample", "crd_sample_tabs"), row, "still in view")
	assert_eq(row.get_meta("stage"), "done", "where it went")
	assert_eq(row.state_chip.text, "Submitted", "in its new state")
	assert_eq(row.outcome_label.text, WorkCardRow.OUTCOMES["approve"], "and what became of its gate")
	var source := app.source
	close(app)
	app = open_work(source, sample_row())
	assert_true(await until(func() -> bool: return app.shown_cards().size() == 1), "opened again")
	assert_eq(app.shown_cards(), ["crd_sample_json"], "the approved card is no longer the agent's")
	close(app)


## "None" is there before the agents come, and when they fail to.
func test_none_is_offered_before_the_agents_come() -> void:
	var source := StubSource.new()
	var app := open_work(source, station_row())
	assert_eq(app.link_choices(), [WorkApp.NONE], "None at once")
	source.refuse("agents", "offline")
	assert_eq(app.link_choices(), [WorkApp.NONE], "and after a failure")
	assert_eq(app.error_text(), WorkApp.UNREACHABLE, "which shows")
	app.choose_link(0)
	assert_eq(app.linked_agent, "", "None chosen")
	assert_eq(StationLinks.read_link(LINKS_FILE, "stn_a"), "", "and kept")
	close(app)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LINKS_FILE))


## A decision's and an answer's buttons wait for their request, and come
## back when it fails.
func test_gate_and_answer_buttons_wait_for_their_request() -> void:
	var pair := open_linked_work()
	var source: StubSource = pair[0]
	var app: WorkApp = pair[1]
	var row := app.card_row("brd_a", "crd_gated")
	row.decision_buttons["approve"].pressed.emit()
	for decision in row.decision_buttons:
		assert_true(row.decision_buttons[decision].disabled, "%s waits" % decision)
	source.refuse("resolve_gate", "offline")
	for decision in row.decision_buttons:
		assert_true(not row.decision_buttons[decision].disabled, "%s is back" % decision)
	var asked := app.card_row("brd_a", "crd_asked")
	asked.answer_field.text = "Staging."
	asked.answer_field.text_changed.emit(asked.answer_field.text)
	asked.answer_button.pressed.emit()
	assert_true(asked.answer_button.disabled, "the answer waits")
	source.refuse("answer", "offline")
	assert_true(not asked.answer_button.disabled, "and is back")
	close(app)


## The comment sent is the one in the field when the choice is confirmed.
func test_the_gate_comment_is_read_when_confirmed() -> void:
	var pair := open_linked_work()
	var source: StubSource = pair[0]
	var app: WorkApp = pair[1]
	var row := app.card_row("brd_a", "crd_gated")
	row.gate_comment.text = "first thought"
	row.decision_buttons["reject"].pressed.emit()
	row.gate_comment.text = "second thought"
	app.confirm_button.pressed.emit()
	assert_eq(source.last("resolve_gate")["args"], ["brd_a", "gate_1", "reject", "second thought"], "the later comment")
	close(app)


## A board event costs little with many of the agent's cards in view: a
## quarter of a 16 ms frame with 303 of them, since events come in bursts
## while agents work.
func test_board_events_stay_cheap_with_many_cards() -> void:
	var board := work_board()
	for i in 300:
		board["cards"].append(work_card("crd_many_%d" % i, "Card %d" % i, ["backlog", "build", "done"][i % 3], "working", "agt_a"))
	var pair := open_linked_work([board])
	var source: StubSource = pair[0]
	var app: WorkApp = pair[1]
	var stream: StubBoard = source.board_streams[0]
	var budget_ms := 4.0 * machine_factor()
	var worst := 0.0
	for i in 60:
		var t := Time.get_ticks_usec()
		# Each moves a card, so the board is laid out again.
		stream.board_event.emit({"seq": 100 + i, "type": "card.moved", "payload": {"cardId": "crd_many_%d" % i,
			"from": ["backlog", "build", "done"][i % 3], "to": "review"}, "ts": "2026-09-29T00:02:00.000Z"})
		worst = maxf(worst, (Time.get_ticks_usec() - t) / 1000.0)
	assert_eq(app.card_row("brd_a", "crd_many_59").get_meta("stage"), "review", "the last moved")
	print("work: 303 cards, the worst board event %.2f ms (budget %.0f ms)" % [worst, budget_ms])
	assert_true(worst < budget_ms, "the worst event took %.2f ms (budget %.0f ms)" % [worst, budget_ms])
	close(app)
