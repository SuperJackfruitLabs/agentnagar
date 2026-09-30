## Sample station's Superpipeline: the recorded boards, agents and card
## histories from work.json, and the changes a player makes to them.
## `SampleSource` answers its Work calls through this, one call a method:
## each returns [ok, body, status] and makes its change as Superpipeline's
## board does (board-do.ts at d53992f), announcing it on the board's open
## streams.
class_name SampleWork
extends RefCounted

const GATE_DECISIONS := ["approve", "request_changes", "reject"]

## How fast the recording plays; the source keeps it in step with its own.
var speed := 1.0

var _work: Dictionary
var _streams: Array[WeakRef] = []


func _init(recording: Dictionary) -> void:
	_work = recording


## The Superpipeline agent that works at `station_id`, or "".
func agent_link(station_id: String) -> String:
	return _work["station_links"].get(station_id, "")


func has_board(board_id: String) -> bool:
	return _work["snapshots"].has(board_id)


## A copy of the board's snapshot as it stands now.
func snapshot(board_id: String) -> Dictionary:
	return _snapshot(board_id).duplicate(true)


## Sends the board's changes to `stream` from now on, while it is open.
func watch(stream: SampleBoardStream) -> void:
	SampleSource.forget_freed(_streams)
	_streams.append(weakref(stream))


func boards() -> Array:
	return SampleSource.success(_work["boards"].duplicate(true))


func agents() -> Array:
	return SampleSource.success(_work["agents"].duplicate(true))


func card_activities(board_id: String, card_id: String) -> Array:
	if not has_board(board_id):
		return _no_board()
	var history = _work["activities"][board_id].get(card_id)
	if history == null:
		return SampleSource.failure("not_found", "card not found: " + card_id, 404)
	var gates: Array = _snapshot(board_id)["gates"].filter(func(g): return g["cardId"] == card_id)
	return SampleSource.success({
		"activities": history["activities"].duplicate(true),
		"handoff": SampleSource.copy(history["handoff"]),
		"gates": gates.duplicate(true),
	})


func move_card(board_id: String, card_id: String, to_stage: String) -> Array:
	if not has_board(board_id):
		return _no_board()
	var state := _snapshot(board_id)
	var card := _find(state["cards"], card_id)
	if card.is_empty():
		return SampleSource.failure("not_found", "card not found: " + card_id, 404)
	var target := _find_stage(state, to_stage)
	if target.is_empty():
		return SampleSource.failure("failed", "unknown stage: " + to_stage, 400)
	if to_stage == card["currentStageKey"]:
		return SampleSource.success({"card": card.duplicate(true)})
	var held: int = state["cards"].filter(func(c): return c["currentStageKey"] == to_stage).size()
	if target.has("wipLimit") and held >= target["wipLimit"]:
		return SampleSource.failure(
			"conflict", 'WIP limit reached for stage "%s" (limit %d)' % [to_stage, target["wipLimit"]], 409
		)
	# As the board does: a person's move re-queues the card and retires
	# whatever it was waiting on.
	var now := SampleSource.timestamp()
	for gate in state["gates"]:
		if gate["cardId"] == card_id and gate["status"] == "pending":
			gate["status"] = "cancelled"
			gate["resolvedAt"] = now
	for question in state["elicitations"]:
		if question["cardId"] == card_id and question["status"] == "pending":
			question["status"] = "cancelled"
	var from: String = card["currentStageKey"]
	card["currentStageKey"] = to_stage
	card["state"] = "submitted"
	card["delegateAgentId"] = null
	card["queuedBy"] = SampleSource.PLAYER
	card["updatedAt"] = now
	_board_event(board_id, "card.moved", {"cardId": card_id, "from": from, "to": to_stage, "by": SampleSource.PLAYER})
	return SampleSource.success({"card": card.duplicate(true)})


func resolve_gate(board_id: String, gate_id: String, decision: String, comment: String) -> Array:
	if not has_board(board_id):
		return _no_board()
	if not decision in GATE_DECISIONS:
		return SampleSource.failure("failed", "Unknown decision.", 400)
	var state := _snapshot(board_id)
	var gate := _find(state["gates"], gate_id)
	if gate.is_empty():
		return SampleSource.failure("not_found", "gate not found: " + gate_id, 404)
	if gate["status"] != "pending":
		return SampleSource.failure("conflict", "gate is already resolved", 409)
	var now := SampleSource.timestamp()
	gate["status"] = "resolved"
	gate["decision"] = decision
	gate["comment"] = null if comment == "" else comment
	gate["decidedBy"] = SampleSource.PLAYER
	gate["resolvedAt"] = now
	var card := _find(state["cards"], gate["cardId"])
	var stages := _stages_in_order(state)
	var at := stages.find(gate["stageKey"])
	card["delegateAgentId"] = null
	card["updatedAt"] = now
	match decision:
		"approve":
			# The sample's review stage is followed by an ungated one, or by
			# none; a gated next stage would open another gate.
			if at + 1 < stages.size():
				card["currentStageKey"] = stages[at + 1]
				card["state"] = "submitted"
				_board_event(board_id, "card.advanced", {"cardId": card["id"], "from": stages[at], "to": stages[at + 1]})
			else:
				card["state"] = "completed"
				_board_event(board_id, "card.completed", {"cardId": card["id"]})
		"request_changes":
			# Back to the stage whose work was under review.
			var back: String = stages[maxi(at - 1, 0)]
			card["currentStageKey"] = back
			card["state"] = "submitted"
			_board_event(board_id, "card.changes_requested", {"cardId": card["id"], "gateId": gate_id, "to": back})
		"reject":
			card["state"] = "rejected"
			_board_event(board_id, "card.rejected", {"cardId": card["id"], "gateId": gate_id})
	_board_event(board_id, "gate.resolved", {
		"gateId": gate_id, "cardId": card["id"], "decision": decision, "decidedBy": SampleSource.PLAYER,
	})
	return SampleSource.success({"card": card.duplicate(true)})


func answer(board_id: String, elicitation_id: String, option: String, text: String) -> Array:
	if not has_board(board_id):
		return _no_board()
	var state := _snapshot(board_id)
	var question := _find(state["elicitations"], elicitation_id)
	if question.is_empty():
		return SampleSource.failure("not_found", "elicitation not found: " + elicitation_id, 404)
	if question["status"] != "pending":
		return SampleSource.failure("conflict", "this question is already %s" % question["status"], 409)
	var chosen := _find_option(question["options"], option.strip_edges())
	if option.strip_edges() != "" and chosen.is_empty():
		return SampleSource.failure("failed", '"%s" is not one of the offered options' % option, 400)
	if option.strip_edges() == "" and text.strip_edges() == "":
		var why := "pick one of the offered options" if not question["options"].is_empty() else "an answer needs some text"
		return SampleSource.failure("failed", why, 400)
	var card := _find(state["cards"], question["cardId"])
	if not card["state"] in ["input-required", "auth-required"]:
		return SampleSource.failure("conflict", 'a card in "%s" is not waiting on an answer' % card["state"], 409)
	var now := SampleSource.timestamp()
	var picked = null if chosen.is_empty() else chosen["name"]
	var said = null if text.strip_edges() == "" else text.strip_edges()
	question["status"] = "answered"
	question["answer"] = {"option": picked, "text": said, "answeredBy": SampleSource.PLAYER, "answeredAt": now}
	card["state"] = "working"
	card["updatedAt"] = now
	var parts := []
	for part in [chosen.get("title", ""), said]:
		if part != null and part != "":
			parts.append(part)
	_add_activity(board_id, card["id"], {
		"runId": question["runId"], "type": "prompt", "body": " — ".join(parts), "action": null,
		"parameter": {"elicitationId": elicitation_id, "option": picked}, "result": null,
	})
	_board_event(board_id, "elicitation.answered", {
		"elicitationId": elicitation_id, "cardId": card["id"], "runId": question["runId"],
		"option": picked, "answeredBy": SampleSource.PLAYER,
	})
	_play_agent_steps(board_id, card["id"], question["runId"], _work["after_answer"].get(elicitation_id, []), 0)
	return SampleSource.success({"card": card.duplicate(true), "elicitation": question.duplicate(true)})


func _no_board() -> Array:
	return SampleSource.failure("not_found", "board not found", 404)


func _snapshot(board_id: String) -> Dictionary:
	return _work["snapshots"][board_id]


func _find(rows: Array, id: String) -> Dictionary:
	for row in rows:
		if row["id"] == id:
			return row
	return {}


func _find_option(options: Array, name: String) -> Dictionary:
	for option in options:
		if option["name"] == name:
			return option
	return {}


func _find_stage(state: Dictionary, key: String) -> Dictionary:
	for stage in state["stages"]:
		if stage["key"] == key:
			return stage
	return {}


func _stages_in_order(state: Dictionary) -> Array:
	var stages: Array = state["stages"].duplicate()
	stages.sort_custom(func(a, b): return a["order"] < b["order"])
	return stages.map(func(s): return s["key"])


## Sends one change to every open stream on `board_id`, numbered after the
## board's last.
func _board_event(board_id: String, type: String, payload: Dictionary) -> void:
	var seq: int = _work["last_event_seq"][board_id] + 1
	_work["last_event_seq"][board_id] = seq
	var change := {"seq": seq, "type": type, "payload": payload, "ts": SampleSource.timestamp()}
	for ref in _streams:
		var stream: SampleBoardStream = ref.get_ref()
		if stream != null and stream.state == "open" and stream.board_id == board_id:
			stream.board_event.emit(change.duplicate(true))


## Adds an activity to a card's history, numbered after the board's last.
func _add_activity(board_id: String, card_id: String, fields: Dictionary) -> void:
	var seq := 0
	for history in _work["activities"][board_id].values():
		for activity in history["activities"]:
			seq = maxi(seq, activity["seq"])
	var activity := {
		"seq": seq + 1, "runId": fields["runId"], "type": fields["type"], "ts": SampleSource.timestamp(),
		"body": fields["body"], "action": fields["action"], "parameter": SampleSource.copy(fields["parameter"]),
		"result": SampleSource.copy(fields["result"]), "signal": null,
	}
	_work["activities"][board_id][card_id]["activities"].append(activity)


## Plays what the agent does next on a card, as recorded: each step is a
## new activity, which the board announces.
func _play_agent_steps(board_id: String, card_id: String, run_id: String, steps: Array, index: int) -> void:
	if index >= steps.size():
		return
	var step: Dictionary = steps[index]
	SampleSource.schedule(speed, minf(step["after"], SampleSource.MAX_GAP), func() -> void:
		var fields := step.duplicate(true)
		fields["runId"] = run_id
		_add_activity(board_id, card_id, fields)
		_board_event(board_id, "activity", {"runId": run_id, "cardId": card_id, "activityType": step["type"]})
		_play_agent_steps(board_id, card_id, run_id, steps, index + 1))
