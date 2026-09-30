## What the Work app knows of a Superpipeline board (protocol section 7):
## the snapshot, kept up to date from the board's events and the player's
## own changes, and the questions asked of it. Every function works on a
## `BoardSnapshot` dictionary in place; none draws or asks anything.
class_name WorkBoardState
extends RefCounted


## Applies one board event to `state`, as far as its payload says; an
## event it does not know changes nothing, and the next snapshot has it.
## The payloads are Superpipeline's own (board-do.ts's `emit` calls, in
## the recordings). `gate.opened` and `elicitation.opened` name their new
## row without carrying it, so they change nothing here: the live board
## follows either with a fresh snapshot.
static func apply_event(state: Dictionary, type: String, payload: Dictionary) -> void:
	var card := find(state.get("cards", []), str(payload.get("cardId", "")))
	match type:
		"card.moved", "card.advanced", "card.changes_requested":
			if not card.is_empty() and payload.get("to") != null:
				card["currentStageKey"] = str(payload["to"])
			if type == "card.moved":
				# A move retires what the card waited on (the errata).
				retire_waits(state, str(payload.get("cardId", "")))
			if type == "card.changes_requested":
				settle_gate(state, str(payload.get("gateId", "")), "request_changes")
		"card.rejected":
			if not card.is_empty():
				card["state"] = "rejected"
			settle_gate(state, str(payload.get("gateId", "")), "reject")
		"card.completed":
			if not card.is_empty():
				card["state"] = "completed"
		"card.created", "card.updated":
			if payload.get("card") is Dictionary:
				put(state, "cards", payload["card"])
		"card.deleted":
			var gone := str(payload.get("cardId", ""))
			state["cards"] = state.get("cards", []).filter(func(c): return str(c.get("id", "")) != gone)
		"gate.resolved":
			settle_gate(state, str(payload.get("gateId", "")), str(payload.get("decision", "")))
		"elicitation.answered":
			var question := find(state.get("elicitations", []), str(payload.get("elicitationId", "")))
			if not question.is_empty():
				question["status"] = "answered"
		"board.renamed":
			if payload.get("name") is String:
				state["name"] = payload["name"]
		"board.stages_changed":
			if payload.get("stages") is Array:
				state["stages"] = payload["stages"]


## The row in `rows` with ID `id`, or {}.
static func find(rows: Variant, id: String) -> Dictionary:
	if rows is Array:
		for row in rows:
			if row is Dictionary and str(row.get("id", "")) == id:
				return row
	return {}


## Puts `row` into `state[list]`, replacing the one with its ID.
static func put(state: Dictionary, list: String, row: Dictionary) -> void:
	var rows: Array = state.get(list, [])
	for i in rows.size():
		if rows[i] is Dictionary and str(rows[i].get("id", "")) == str(row.get("id", "")):
			rows[i] = row.duplicate(true)
			return
	rows.append(row.duplicate(true))
	state[list] = rows


## Marks a pending gate resolved with `decision` ("" to leave it unsaid).
static func settle_gate(state: Dictionary, gate_id: String, decision: String) -> void:
	var gate := find(state.get("gates", []), gate_id)
	if gate.is_empty() or gate.get("status") != "pending":
		return
	gate["status"] = "resolved"
	if decision != "":
		gate["decision"] = decision


## Cancels a card's pending gate and question, as a person's move does.
static func retire_waits(state: Dictionary, card_id: String) -> void:
	for list in ["gates", "elicitations"]:
		for row in state.get(list, []):
			if row is Dictionary and str(row.get("cardId", "")) == card_id and row.get("status") == "pending":
				row["status"] = "cancelled"


## Each card's pending gate and open question, by card ID, gathered in one
## pass: [gates, questions].
static func waits_by_card(state: Dictionary) -> Array:
	var gates := {}
	var questions := {}
	for gate in state.get("gates", []):
		if gate is Dictionary and gate.get("status") == "pending" and not gates.has(str(gate.get("cardId", ""))):
			gates[str(gate.get("cardId", ""))] = gate
	for question in state.get("elicitations", []):
		if question is Dictionary and question.get("status") == "pending" \
				and not questions.has(str(question.get("cardId", ""))):
			questions[str(question.get("cardId", ""))] = question
	return [gates, questions]


## The card's pending gate, or {}.
static func pending_gate(state: Dictionary, card_id: String) -> Dictionary:
	return waits_by_card(state)[0].get(card_id, {})


## The card's open question, or {}.
static func open_question(state: Dictionary, card_id: String) -> Dictionary:
	return waits_by_card(state)[1].get(card_id, {})


## Whether `card` is `agent_id`'s: delegated to it, or waiting at a gate it
## produced (`gate`, the card's pending one or {}), or on a question it
## asked (`question`, likewise). A card waiting at a gate has no delegate,
## so the gate and the question say whose it is.
static func is_agents_card(card: Dictionary, agent_id: String, gate: Dictionary, question: Dictionary) -> bool:
	if agent_id == "":
		return false
	return str(card.get("delegateAgentId", "")) == agent_id \
		or str(gate.get("producedBy", "")) == agent_id \
		or str(question.get("agentId", "")) == agent_id


## The board's stages, in their order.
static func stages_in_order(state: Dictionary) -> Array:
	var stages: Array = state.get("stages", []).filter(func(s): return s is Dictionary)
	stages.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))
	return stages


## A card's history, a line an activity: its time, what it was, and what
## it said; then the handoff's summary.
static func activity_text(history: Dictionary) -> String:
	var lines := PackedStringArray()
	for activity in history.get("activities", []):
		if not activity is Dictionary:
			continue
		var ts := str(activity.get("ts", ""))
		var time := ts.substr(11, 5) if ts.length() >= 16 else ts
		var what := str(activity.get("action")) if activity.get("action") != null else str(activity.get("type", ""))
		var line := "%s  %s  %s" % [time, what, str(activity.get("body", "")).replace("\n", " ")]
		var outcome = activity.get("result")
		if outcome is Dictionary and outcome.has("exitCode"):
			line += "  (exit %s)" % str(outcome["exitCode"])
		lines.append(line)
	var handoff = history.get("handoff")
	if handoff is Dictionary and handoff.get("summary") != null:
		lines.append("Handoff: " + str(handoff["summary"]))
	if lines.is_empty():
		return "No activity yet."
	return "\n".join(lines)
