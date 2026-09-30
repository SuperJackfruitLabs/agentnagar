## The station computer's Chat app (Part B's Task 7): the station agent's
## ACP console session, against Sample station and a scripted stub session
## (station_stubs.gd).
extends "res://tests/station_stubs.gd"


## An `AcpEvent` of the hub's shape.
static func acp(seq: int, type: String, payload: Dictionary) -> Dictionary:
	return {"sessionId": "acps_a", "seq": seq, "type": type, "payload": payload,
		"createdAt": "2026-09-29T00:00:%02d.000Z" % (seq % 60)}


static func chunk(seq: int, text: String, update := "agent_message_chunk") -> Dictionary:
	return acp(seq, "agent-update", {"sessionUpdate": update, "content": {"type": "text", "text": text}})


static func acp_state(seq: int, status: String) -> Dictionary:
	return acp(seq, "state", {"status": status})


## An `AcpSessionRow` of the hub's shape.
static func session_row(status := "idle", mode := "ask", id := "acps_a") -> Dictionary:
	return {"id": id, "stationId": "stn_a", "userId": "usr_a", "mode": mode, "status": status, "endedReason": null,
		"createdAt": "2026-09-29T00:00:00.000Z", "lastEventAt": "2026-09-29T00:00:05.000Z", "title": null, "lastSeq": 0}


static func permission_request(seq: int, auto := false) -> Dictionary:
	var payload := {
		"toolCall": {"toolCallId": "call_%d" % seq, "title": "Edit src/lib.rs", "kind": "edit", "status": "pending"},
		"options": [
			{"optionId": "opt_allow_once", "kind": "allow_once", "name": "Allow"},
			{"optionId": "opt_reject_once", "kind": "reject_once", "name": "Reject"},
		],
	}
	if auto:
		payload["auto"] = true
	return acp(seq, "permission-request", payload)


## Opens the chat on a stub, whose session replays `events`.
func open_chat(source: StubSource, events: Array, status := "idle", row := station_row(), read_only := false) -> ChatApp:
	var app: ChatApp = open("chat", source, row, read_only)
	source.chats.back().replay(session_row(status), events)
	app.flush()
	return app


## Every event type renders: the player's prompt as a bubble, text chunks
## joined into one bubble, a thought, a tool call and its updates in one
## row, a plan as a checklist, an unknown update as a quiet "(update)", a
## permission request (and one answered automatically), an error from its
## kind, and the state on the status chip.
func test_the_chat_renders_every_event_type() -> void:
	var source := StubSource.new()
	var app := open_chat(source, [
		acp_state(1, "idle"),
		acp(2, "user-prompt", {"text": "Run the tests."}),
		acp_state(3, "working"),
		chunk(4, "I'll run "),
		chunk(5, "the tests."),
		chunk(6, "Reading the suite first.", "agent_thought_chunk"),
		acp(7, "agent-update", {"sessionUpdate": "tool_call", "toolCallId": "call_1", "title": "cargo test",
			"kind": "execute", "status": "pending"}),
		acp(8, "agent-update", {"sessionUpdate": "tool_call_update", "toolCallId": "call_1", "status": "completed"}),
		acp(9, "agent-update", {"sessionUpdate": "plan", "entries": [
			{"content": "Run the tests", "status": "completed", "priority": "high"},
			{"content": "Fix the failure", "status": "in_progress", "priority": "high"},
			{"content": "Run them again", "status": "pending", "priority": "medium"}]}),
		acp(10, "agent-update", {"sessionUpdate": "a_future_update", "whatever": [1, 2]}),
		permission_request(11),
		permission_request(12, true),
		acp(13, "error", {"message": "provider said: quota for key sk-123 used up", "kind": "quota"}),
		acp_state(14, "waiting"),
	], "waiting")
	var kinds := app.rows().map(func(r): return r[0])
	assert_eq(kinds, ["prompt", "message", "thought", "tool", "plan", "update", "permission", "permission", "notice"],
		"one row each, the chunks and the tool call's updates joined")
	var texts := app.rows().map(func(r): return r[1])
	assert_eq(texts[0], "Run the tests.", "the player's prompt")
	assert_eq(texts[1], "I'll run the tests.", "the chunks, joined into one bubble")
	assert_true(texts[2].contains("Reading the suite first."), "the thought: %s" % texts[2])
	for part in ["cargo test", "execute", "completed"]:
		assert_true(texts[3].contains(part), "the tool call's %s: %s" % [part, texts[3]])
	assert_true(not texts[3].contains("pending"), "updated in place: %s" % texts[3])
	assert_eq(texts[4], "☑ Run the tests\n◐ Fix the failure\n☐ Run them again", "the plan as a checklist")
	assert_eq(texts[5], "(update)", "an unknown update, quietly")
	assert_true(texts[6].contains("Edit src/lib.rs") and texts[6].contains("Allow") and texts[6].contains("Reject"),
		"the request with its options: %s" % texts[6])
	assert_true(texts[7].contains(ChatApp.ANSWERED_AUTOMATICALLY), "an automatic one shows answered: %s" % texts[7])
	assert_true(not app.permission_card(12).find_child("Option_opt_allow_once", true, false).is_visible_in_tree(),
		"with nothing to choose")
	assert_eq(texts[8], ChatApp.ERROR_NOTICES["quota"], "the error, from its kind")
	assert_true(not app.text().contains("sk-123"), "and not from its message")
	assert_eq(app.status_chip.text, "Waiting", "the state on the chip")
	assert_eq(app.status, "waiting")
	close(app)


## Every status reads on the chip, and each change is announced for the
## monitor's pulse.
func test_the_chat_status_chip_and_signal() -> void:
	var source := StubSource.new()
	var app: ChatApp = open("chat", source, station_row())
	var seen := []
	app.status_changed.connect(func(status: String) -> void: seen.append(status))
	var stream: StubChat = source.chats[0]
	stream.replay(session_row("starting"), [])
	var seq := 1
	for status in ["idle", "working", "waiting", "ended"]:
		stream.event.emit(acp_state(seq, status))
		seq += 1
		assert_eq(app.status_chip.text, status.capitalize(), status)
	assert_eq(seen, ["starting", "idle", "working", "waiting", "ended"], "each change, once")
	close(app)


## Events are shown in `seq` order, once: a reconnect's replay adds
## nothing, a late event takes its place, and a refusal (seq 0) is a notice
## outside the order.
func test_the_chat_ignores_duplicate_seqs_and_keeps_seq_order() -> void:
	var source := StubSource.new()
	var events := [acp_state(1, "idle"), acp(2, "user-prompt", {"text": "one"}), acp_state(3, "working"),
		chunk(4, "reply one"), acp_state(5, "idle")]
	var app := open_chat(source, events)
	assert_eq(app.rows().size(), 2, "a prompt and a reply")
	var stream: StubChat = source.chats[0]
	stream.replay(session_row(), events + [acp(6, "user-prompt", {"text": "two"})])
	app.flush()
	assert_eq(app.rows().map(func(r): return r[1]), ["one", "reply one", "two"], "the replay added only seq 6")
	stream.event.emit(acp(8, "user-prompt", {"text": "four"}))
	stream.event.emit(acp(7, "user-prompt", {"text": "three"}))
	stream.event.emit(acp(8, "user-prompt", {"text": "four"}))
	app.flush()
	assert_eq(app.rows().map(func(r): return r[1]), ["one", "reply one", "two", "three", "four"],
		"seq order, and 8 once")
	stream.event.emit(acp(0, "error", {"message": "Session is busy — wait for the current turn to finish."}))
	stream.event.emit(acp(0, "error", {"message": "Session is busy — wait for the current turn to finish."}))
	app.flush()
	var notices := app.rows().filter(func(r): return r[0] == "notice")
	assert_eq(notices.size(), 2, "each refusal shows; seq 0 is never a duplicate")
	assert_eq(notices[0][1], "Session is busy — wait for the current turn to finish.", "in the hub's words")
	close(app)


## Choosing a permission option sends `answer(requestSeq, optionId)`, and
## the card shows the answer once the hub records it.
func test_the_chat_sends_the_permission_answer() -> void:
	var source := StubSource.new()
	var app := open_chat(source, [acp_state(1, "working"), permission_request(2), acp_state(3, "waiting")], "waiting")
	var stream: StubChat = source.chats[0]
	var allow: Button = app.permission_card(2).find_child("Option_opt_allow_once", true, false)
	allow.pressed.emit()
	assert_eq(stream.answers, [[2, "opt_allow_once"]], "the answer names the request's seq and the option")
	assert_true(allow.disabled, "and the options wait for the hub")
	stream.event.emit(acp(4, "permission-answer", {"requestSeq": 2, "optionId": "opt_allow_once"}))
	app.flush()
	assert_true(app.rows()[0][1].contains("Allow") and app.rows()[0][1].contains(ChatApp.ANSWERED),
		"the card says what was chosen: %s" % app.rows()[0][1])
	assert_true(not allow.is_visible_in_tree(), "and offers nothing more")
	close(app)

	# Answered as cancelled, when the turn is cancelled.
	source = StubSource.new()
	app = open_chat(source, [permission_request(1), acp(2, "permission-answer", {"requestSeq": 1, "cancelled": true})])
	assert_true(app.rows()[0][1].contains(ChatApp.CANCELLED), "cancelled: %s" % app.rows()[0][1])
	close(app)


## The sample's own permission request, answered in the app, plays the
## recorded continuation.
func test_the_chat_plays_the_sample() -> void:
	var app: ChatApp = open("chat", sample(), sample_row())
	assert_true(await until(func() -> bool: return app.status == "waiting"), "the recorded session waits")
	app.flush()
	var card := app.permission_card(13)
	assert_true(card != null, "on its permission request")
	(card.find_child("Option_opt_allow_once", true, false) as Button).pressed.emit()
	assert_true(await until(func() -> bool:
		app.flush()
		return app.status == "idle" and app.text().contains("All 7 tests pass")), "the continuation plays")
	app.prompt_field.text = "Anything else?"
	app.send_button.pressed.emit()
	assert_true(await until(func() -> bool:
		app.flush()
		return app.text().contains("Connect your AgentPod to talk to a real agent.")), "and a prompt is answered")
	close(app)


## Sending a prompt, and cancelling while the agent works.
func test_the_chat_sends_a_prompt_and_cancels() -> void:
	var source := StubSource.new()
	var app := open_chat(source, [acp_state(1, "idle")])
	var stream: StubChat = source.chats[0]
	assert_true(not app.send_button.disabled and app.cancel_turn_button.disabled, "idle: send, nothing to cancel")
	assert_eq(app.typing_target, app.prompt_field, "the prompt field takes the typing")
	assert_true(StationApp.is_typing_target(app.prompt_field), "so Esc goes to it")
	app.prompt_field.text = "   "
	app.send_button.pressed.emit()
	assert_eq(stream.prompts, [], "nothing to send")
	app.prompt_field.text = "Run the tests."
	app.send_button.pressed.emit()
	assert_eq(stream.prompts, ["Run the tests."], "sent")
	assert_eq(app.prompt_field.text, "", "and the field emptied")
	app.prompt_field.text = "Fix it."
	app.prompt_field.grab_focus()
	app.prompt_field.gui_input.emit(key(KEY_ENTER))
	assert_eq(stream.prompts, ["Run the tests.", "Fix it."], "Enter sends too")
	stream.event.emit(acp_state(2, "working"))
	assert_true(app.send_button.disabled and not app.cancel_turn_button.disabled, "working: cancel, no send")
	app.cancel_turn_button.pressed.emit()
	assert_eq(stream.cancels, 1, "cancelled")
	close(app)


## `ask` and `accept-edits` switch at once; `full-auto` asks first, naming
## the station, and says it is real when live. Cancelling puts the picker
## back.
func test_full_auto_asks_for_confirmation() -> void:
	var source := StubSource.new()
	var app := open_chat(source, [acp_state(1, "idle")])
	var stream: StubChat = source.chats[0]
	app.pick_mode("accept-edits")
	assert_eq(stream.modes, ["accept-edits"], "accept-edits at once")
	app.pick_mode("full-auto")
	assert_eq(stream.modes, ["accept-edits"], "full-auto waits")
	assert_true(app.confirm_box.visible, "and asks")
	assert_true(app.confirm_label.text.contains(app.station_name()), "naming the station: %s" % app.confirm_label.text)
	assert_true(not app.confirm_label.text.contains("real"), "not live: %s" % app.confirm_label.text)
	app.cancel_button.pressed.emit()
	assert_eq(stream.modes, ["accept-edits"], "cancelled: nothing sent")
	assert_eq(app.mode_picker.get_item_text(app.mode_picker.selected), ChatApp.MODE_NAMES["accept-edits"], "the picker put back")
	app.pick_mode("full-auto")
	app.confirm_button.pressed.emit()
	assert_eq(stream.modes, ["accept-edits", "full-auto"], "confirmed: sent")
	assert_eq(app.mode, "full-auto", "no reply comes, so the app takes it as set")
	close(app)
	source = StubSource.new()
	source.live = true
	app = open_chat(source, [acp_state(1, "idle")])
	app.pick_mode("full-auto")
	assert_true(app.confirm_label.text.contains("real"), "live: it says it is real: %s" % app.confirm_label.text)
	assert_true(app.confirm_label.text.contains("Build box"), "naming the live station: %s" % app.confirm_label.text)
	close(app)


## A new session: at once after the old one ended, or from the menu, which
## asks first and ends the one still open.
func test_the_chat_opens_a_new_session() -> void:
	var source := StubSource.new()
	var app := open_chat(source, [acp_state(1, "idle"), acp(2, "user-prompt", {"text": "old"}),
		acp(3, "state", {"status": "ended", "reason": "Session ended."})])
	assert_true(app.new_session_button.is_visible_in_tree(), "an ended session offers a new one")
	assert_true(app.send_button.disabled, "and takes no prompt")
	assert_true(app.text().contains(ChatApp.ENDED), "saying it ended: %s" % app.text())
	source.chats[0].close()
	app.new_session_button.pressed.emit()
	assert_eq(source.calls_to("end_chat"), [], "nothing to end")
	assert_eq(source.calls_to("open_chat").size(), 2, "a new chat opens")
	assert_eq(source.last("open_chat")["args"], ["stn_a", "ask", true], "a new one, in the chosen mode")
	source.chats[1].replay(session_row("idle", "ask", "acps_b"), [acp_state(1, "idle")])
	app.flush()
	assert_eq(app.rows(), [], "on an empty transcript")
	assert_true(not app.new_session_button.is_visible_in_tree(), "open again")

	app.menu_new_session()
	assert_true(app.confirm_box.visible, "from the menu, it asks while the session is open")
	app.confirm_button.pressed.emit()
	assert_eq(source.last("end_chat")["args"], ["acps_b"], "ends the open session")
	assert_eq(source.calls_to("open_chat").size(), 2, "and waits for that")
	source.reply("end_chat", {})
	assert_eq(source.chats[1].state, "closed", "the old stream is closed")
	assert_eq(source.calls_to("open_chat").size(), 3, "then opens a new one")
	assert_eq(source.last("open_chat")["args"][2], true, "asked for as new")
	var popup := app.menu.get_popup()
	assert_eq(popup.get_item_text(0), ChatApp.NEW_SESSION, "the menu holds it")
	close(app)


## Watching, the chat shows the session and sends nothing.
func test_a_watched_chat_sends_nothing() -> void:
	var source := StubSource.new()
	var app := open_chat(source, [acp_state(1, "working"), permission_request(2), acp_state(3, "waiting")],
		"waiting", station_row(), true)
	assert_true(not app.prompt_field.editable and app.prompt_field.focus_mode == Control.FOCUS_NONE, "no typing")
	assert_true(not app.send_button.is_visible_in_tree() and not app.mode_picker.is_visible_in_tree(), "no controls")
	assert_true(not app.permission_card(2).find_child("Option_opt_allow_once", true, false).is_visible_in_tree(), "no answers")
	app.send_prompt()
	app.pick_mode("full-auto")
	assert_eq(source.chats[0].prompts, [], "nothing sent")
	assert_eq(source.chats[0].modes, [], "nothing switched")
	close(app)


## A stream that fails shows its failure; one that cannot open at all says
## so and still leaves a field for the keys.
func test_the_chat_shows_a_failed_stream() -> void:
	var source := StubSource.new()
	var app: ChatApp = open("chat", source, station_row())
	source.chats[0].failed.emit(StationSource.make_error("offline", "gone"))
	assert_eq(app.error_text(), StationApp.OFFLINE, "offline")
	app.press_error_button()
	assert_eq(source.calls_to("open_chat").size(), 2, "Retry opens it again")
	assert_eq(source.last("open_chat")["args"][2], false, "the open session, not a new one")
	source.chats[1]._set_state("offline")
	assert_true(app.status_chip.text == ChatApp.RECONNECTING, "a dropped stream says it is reconnecting")
	close(app)


## Hundreds of events keep the chat responsive: a long session's replay is
## taken in one frame and drawn a few rows a frame, each frame inside the
## budget, and a long reply's chunks fill one bubble.
func test_a_long_session_stays_responsive() -> void:
	var source := StubSource.new()
	var app: ChatApp = open("chat", source, station_row())
	var events := []
	var seq := 0
	for turn in 60:
		seq += 1
		events.append(acp(seq, "user-prompt", {"text": "Turn %d: run the tests and fix what fails." % turn}))
		seq += 1
		events.append(acp_state(seq, "working"))
		for c in 8:
			seq += 1
			events.append(chunk(seq, "Part %d of a longer reply, with some words in it. " % c))
		seq += 1
		events.append(acp(seq, "agent-update", {"sessionUpdate": "tool_call", "toolCallId": "call_%d" % turn,
			"title": "cargo test", "kind": "execute", "status": "pending"}))
		seq += 1
		events.append(acp(seq, "agent-update", {"sessionUpdate": "tool_call_update", "toolCallId": "call_%d" % turn,
			"status": "completed"}))
		seq += 1
		events.append(acp_state(seq, "idle"))
	var budget_ms := 16.0 * machine_factor()
	var started := Time.get_ticks_usec()
	source.chats[0].replay(session_row(), events)
	var intake := (Time.get_ticks_usec() - started) / 1000.0
	var worst := intake
	var frames := 1
	while app.drawing() and frames < 1000:
		var t := Time.get_ticks_usec()
		await runner.process_frame
		worst = maxf(worst, (Time.get_ticks_usec() - t) / 1000.0)
		frames += 1
	print("chat: %d events taken in %.1f ms, drawn over %d frames, the worst %.1f ms (budget %.0f ms)" \
			% [events.size(), intake, frames, worst, budget_ms])
	assert_true(worst < budget_ms, "the worst frame took %.1f ms (budget %.0f ms)" % [worst, budget_ms])
	assert_eq(app.rows().size(), 60 * 3, "a prompt, a reply and a tool call a turn")
	# A long reply streamed a chunk at a time fills one bubble.
	var stream: StubChat = source.chats[0]
	stream.event.emit(acp(seq + 1, "user-prompt", {"text": "Write a long reply."}))
	for c in 400:
		stream.event.emit(chunk(seq + 2 + c, "word%d " % c))
	await runner.process_frame
	assert_eq(app.rows().size(), 60 * 3 + 2, "one more prompt and one bubble")
	assert_true(app.rows().back()[1].begins_with("word0 word1 ") and app.rows().back()[1].ends_with("word399 "), "the whole reply")
	close(app)


## The computer passes the chat's status on, for the monitor's pulse.
func test_the_computer_passes_the_chat_status_on() -> void:
	var stack := ScreenStack.new()
	stack.router = InputRouter.new()
	runner.root.add_child(stack.router)
	stack.ui = UiTheme.from_style({})
	runner.root.add_child(stack)
	var source := StubSource.new()
	var c := ComputerScreen.new()
	c.settings = fresh_settings()
	c.glyphs = InputGlyphs.new()
	c.platform = "desktop"
	c.touch = false
	stack.push(c)
	c.open({"target": "seat:w2", "kind": "workstation", "binding": {}}, source)
	source.reply("list_stations", {"stats": {}, "agents": [station_row()]})
	c.choose(0)
	var seen := []
	c.chat_status_changed.connect(func(status: String) -> void: seen.append(status))
	c.open_app("chat")
	source.chats[0].replay(session_row("idle"), [acp_state(1, "idle"), acp_state(2, "working")])
	assert_eq(c.chat_status, "working", "the computer holds the status")
	assert_eq(seen, ["idle", "working"], "and says when it changes")
	var router := stack.router
	stack.free()
	router.free()


## Watching attaches to the station's session and never starts one: the
## chat asks `watch_chat`, and Retry asks it again, never `open_chat`. With
## no session, it says so quietly, with nothing to retry.
func test_watching_attaches_and_never_opens_a_session() -> void:
	var source := StubSource.new()
	var app: ChatApp = open("chat", source, station_row(), true)
	assert_eq(source.calls_to("watch_chat").size(), 1, "it attaches")
	assert_eq(source.calls_to("open_chat"), [], "and opens nothing")
	source.chats[0].failed.emit(StationSource.make_error("not_found", StationSource.NO_SESSION))
	assert_eq(app.error_text(), "", "no session is not an error")
	assert_eq(app.status_chip.text, ChatApp.NO_SESSION, "it says so")
	source.chats.back().failed.emit(StationSource.make_error("offline", "gone"))
	assert_eq(app.error_text(), StationApp.OFFLINE, "a real failure shows")
	app.press_error_button()
	assert_eq(source.calls_to("watch_chat").size(), 2, "Retry attaches again")
	assert_eq(source.calls_to("open_chat"), [], "and still opens nothing")
	app.menu_new_session()
	assert_eq(source.calls_to("open_chat"), [], "nor does the menu, watching")
	close(app)

	# The sample's session is there to watch.
	var watched: ChatApp = open("chat", sample(), sample_row(), true)
	assert_true(await until(func() -> bool: return watched.status == "waiting"), "the sample's session shows")
	close(watched)


## A tool call ends the bubble before it: text after it is a new bubble.
func test_a_tool_call_ends_a_bubble() -> void:
	var source := StubSource.new()
	var app := open_chat(source, [chunk(1, "Before. "),
		acp(2, "agent-update", {"sessionUpdate": "tool_call", "toolCallId": "c", "title": "ls", "kind": "read", "status": "pending"}),
		chunk(3, "After.")])
	assert_eq(app.rows().map(func(r): return r[0]), ["message", "tool", "message"], "two bubbles")
	assert_eq(app.rows()[2][1], "After.", "the second holds only what came after")
	close(app)


## An event type the chat does not know is a quiet "(update)".
func test_an_unknown_event_type_is_quiet() -> void:
	var source := StubSource.new()
	var app := open_chat(source, [acp(1, "a-future-event", {"anything": true}), chunk(2, "Still here.")])
	assert_eq(app.rows(), [["update", ChatApp.UPDATE], ["message", "Still here."]], "quiet, then the rest")
	close(app)


## A refusal (seq 0) keeps its place when a late event draws the
## transcript again.
func test_refusals_stay_across_a_redraw() -> void:
	var source := StubSource.new()
	var app := open_chat(source, [acp(1, "user-prompt", {"text": "one"}), acp(3, "user-prompt", {"text": "three"})])
	var stream: StubChat = source.chats[0]
	stream.event.emit(acp(0, "error", {"message": "Session is busy."}))
	stream.event.emit(acp(2, "user-prompt", {"text": "two"}))
	assert_eq(app.rows().map(func(r): return r[1]), ["one", "two", "three", "Session is busy."],
		"the late event in its place, the refusal still after what it followed")
	close(app)


## A permission answer that was sent but never recorded (the stream
## dropped) can be sent again once the stream is back.
func test_permission_options_come_back_when_the_stream_reopens() -> void:
	var source := StubSource.new()
	var app := open_chat(source, [permission_request(1), acp_state(2, "waiting")], "waiting")
	var stream: StubChat = source.chats[0]
	var allow: Button = app.permission_card(1).find_child("Option_opt_allow_once", true, false)
	allow.pressed.emit()
	assert_true(allow.disabled, "waiting for the hub")
	stream._set_state("offline")
	stream._set_state("open")
	assert_true(not allow.disabled, "back once the stream is")
	close(app)


## Picking another mode puts away a full-auto question still showing.
func test_picking_a_mode_puts_away_the_full_auto_question() -> void:
	var source := StubSource.new()
	var app := open_chat(source, [acp_state(1, "idle")])
	app.pick_mode("full-auto")
	assert_true(app.asking(), "full auto asks")
	app.pick_mode("accept-edits")
	assert_true(not app.asking(), "put away")
	assert_eq(source.chats[0].modes, ["accept-edits"], "only the second was sent")
	assert_eq(app.mode_picker.get_item_text(app.mode_picker.selected), ChatApp.MODE_NAMES["accept-edits"])
	close(app)


## A 64 KiB reply streamed a chunk a frame never holds a frame over budget,
## and ends whole.
func test_a_64_kib_reply_streamed_a_chunk_a_frame() -> void:
	var source := StubSource.new()
	var app := open_chat(source, [acp_state(1, "working")], "working")
	var stream: StubChat = source.chats[0]
	var paragraph := "A sentence of an agent's long reply, with ordinary words in it and some `code`. ".repeat(8)
	var text := ""
	while text.length() < 64 * 1024:
		text += paragraph + "\n\n"
	var budget_ms := 16.0 * machine_factor()
	var worst := 0.0
	var seq := 2
	var at := 0
	while at < text.length():
		var t := Time.get_ticks_usec()
		stream.event.emit(chunk(seq, text.substr(at, 256)))
		await runner.process_frame
		worst = maxf(worst, (Time.get_ticks_usec() - t) / 1000.0)
		seq += 1
		at += 256
	print("chat: a %d KiB reply over %d chunks, the worst frame %.1f ms (budget %.0f ms)" \
			% [text.length() / 1024, seq - 2, worst, budget_ms])
	assert_true(worst < budget_ms, "the worst frame took %.1f ms (budget %.0f ms)" % [worst, budget_ms])
	assert_eq(app.rows().size(), 1, "one bubble")
	assert_eq(app.rows()[0][1], text, "the whole reply")
	close(app)
