## The Work app: the station agent's Superpipeline work (spec section 5.2;
## protocol section 7). No route links an AgentPod station to its
## Superpipeline agent, so the first time Work opens for a station it asks
## which agent works there, and keeps the answer on this device, IDs only
## (`user://station_links.cfg`). A source that knows the link already (the
## sample's is built in) spares the question.
##
## Each board is opened as its snapshot and push-only stream, and the view
## follows the stream's events without asking again; a reconnection's
## snapshot replaces what the events built. The agent's cards (delegated to
## it, or waiting at a gate it produced, or on a question it asked) show
## grouped by board and stage, each with its state. On them the player can:
##
## - decide a pending gate: approve, request changes or reject, with a
##   comment; the last two ask first, naming the board;
## - answer an open question: free text, one of its options, or an
##   interactive option with text;
## - read the card's activity, by selecting it;
## - move it to another stage, where a refusal (a full stage) shows the
##   board's own words.
##
## A card shown stays in view until Work opens again, even once the gate or
## question that made it the agent's is settled, marked with what became of
## it: a card vanishing on Approve would read as a failure.
##
## The board's state lives in `WorkBoardState`, the links in
## `StationLinks`, and each card's row is a `WorkCardRow`.
class_name WorkApp
extends StationApp

const WHICH_AGENT := "Which Superpipeline agent works at this station?"
const NONE := "None"
const NO_AGENT := "No Superpipeline agent works at this station."
const NOT_LINKED := "This station's Superpipeline agent is not set on this device."
const NO_CARDS := "Nothing on your boards is this agent's."
const NO_BOARDS := "You have no boards."
const LOADING := "Loading…"
const RECONNECTING := "Reconnecting…"
const CHANGE_AGENT := "Change agent"
## What live Request changes and Reject add to their question.
const REAL := {
	"request_changes": "This is real: the card goes back for more work.",
	"reject": "This is real: the card is rejected.",
}
## Superpipeline's failures in its own words: its refusals are not the
## station's. A refused sign-in is most often a hub registration without
## Superpipeline's audience (spec section 10, "found while planning Part
## B"); signing in again is still what to do.
const NOT_ACCEPTED := "Superpipeline did not accept this sign-in"
const UNREACHABLE := "Superpipeline can't be reached"
const NO_BOARD_ACCESS := "You don't have access to this board"
## The failure line's keys.
const AGENTS := "agents"
const BOARDS := "boards"

## The links file; tests give their own.
var links_path := StationLinks.PATH
## The agent that works at the station, "" for none.
var linked_agent := ""
## Whether the link is known: built in, kept, or just chosen.
var link_known := false

var header: HBoxContainer
var agent_label: Label
var change_link_button: Button
var link_prompt: VBoxContainer
var link_question: Label
var link_list: VBoxContainer
var body_scroll: ScrollContainer
var boards_box: VBoxContainer
var note_label: Label

## Each open board's snapshot, as the stream and the player's changes
## keep it, by board ID.
var boards := {}
## The boards, in the order `boards()` gave them.
var board_order: Array = []
## Each board's stream, by board ID.
var streams := {}

## The agents, as `agents()` gave them.
var _agents: Array = []
var _agents_loaded := false
var _agents_call := 0
## Each board's name from the list, for its heading before its snapshot.
var _board_names := {}
## Each board's section, by board ID.
var _sections := {}
## Each shown card's row, by "board/card".
var _rows := {}
## The last event applied on each board, so none is applied twice.
var _last_seq := {}
## Whether the board list has come.
var _boards_listed := false
## The selected card's key, or "".
var _selected := ""
## Every card shown since Work opened (and its agent was chosen), by key:
## each stays in view until Work opens again.
var _kept := {}


func build() -> void:
	header = HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 12)
	agent_label = Label.new()
	agent_label.name = "Agent"
	agent_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	agent_label.clip_text = true
	header.add_child(agent_label)
	change_link_button = make_button("ChangeAgent", CHANGE_AGENT, ask_link)
	change_link_button.visible = not read_only
	header.add_child(change_link_button)
	add_child(header)

	link_prompt = VBoxContainer.new()
	link_prompt.name = "LinkPrompt"
	link_prompt.add_theme_constant_override("separation", 8)
	link_question = Label.new()
	link_question.text = WHICH_AGENT
	link_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	link_prompt.add_child(link_question)
	link_list = VBoxContainer.new()
	link_list.name = "Choices"
	link_prompt.add_child(link_list)
	link_prompt.visible = false
	add_child(link_prompt)

	note_label = Label.new()
	note_label.name = "Note"
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.visible = false
	add_child(note_label)

	body_scroll = ScrollContainer.new()
	body_scroll.name = "Scroll"
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	boards_box = VBoxContainer.new()
	boards_box.name = "Boards"
	boards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boards_box.add_theme_constant_override("separation", 16)
	body_scroll.add_child(boards_box)
	add_child(body_scroll)

	_load_agents()
	# The file is read only where the source has no link of its own.
	var built_in := source.built_in_agent_link(station_id())
	var kept = StationLinks.read_link(links_path, station_id()) if built_in == "" else null
	if built_in != "":
		_set_link(built_in)
	elif kept != null:
		_set_link(str(kept))
	elif read_only:
		_show_note(NOT_LINKED)
	else:
		ask_link()
	_refresh_header()


func restyle() -> void:
	super()
	if ui == null:
		return
	for l in [agent_label, link_question, note_label]:
		l.add_theme_font_override("font", ui.body_font)
		l.add_theme_font_size_override("font_size", ui.font_size(text_size()))
		l.add_theme_color_override("font_color", ui.colour("ink"))
	for board_id in _sections:
		_style_section(_sections[board_id])
	for key in _rows:
		_rows[key].restyle(self)


func closing() -> void:
	_close_boards()
	super()


# ---- Which agent is this station's ----

## Asks which agent works at the station, listing the agents and None.
func ask_link() -> void:
	if read_only:
		return
	link_prompt.visible = true
	_fill_link_choices()
	if not _agents_loaded and _agents_call == 0:
		_load_agents()


## The choices the question offers, as shown.
func link_choices() -> Array:
	return link_list.get_children().map(func(b: Button) -> String: return b.text)


## Chooses the question's choice `index`, as listed: an agent, or None.
func choose_link(index: int) -> void:
	if read_only or not link_prompt.visible or index < 0 or index >= link_list.get_child_count():
		return
	var agent_id := str(link_list.get_child(index).get_meta("agent_id"))
	StationLinks.store_link(links_path, station_id(), agent_id)
	link_prompt.visible = false
	_set_link(agent_id)


func _set_link(agent_id: String) -> void:
	_close_boards()
	linked_agent = agent_id
	link_known = true
	_refresh_header()
	if agent_id == "":
		_show_note(NO_AGENT)
		return
	_show_note(LOADING)
	_open_boards()


func _load_agents() -> void:
	_agents_call = source.agents()
	request(_agents_call, _on_agents)


func _on_agents(ok: bool, body: Variant, _status: int) -> void:
	_agents_call = 0
	if not ok:
		show_error(body if body is Dictionary else {}, _load_agents, AGENTS)
		_fill_link_choices()
		return
	clear_error(AGENTS)
	var listed = body.get("agents", []) if body is Dictionary else []
	_agents = listed.filter(func(a): return a is Dictionary) if listed is Array else []
	_agents_loaded = true
	_refresh_header()
	_fill_link_choices()


## The agents as they have come, then None, which is there from the
## start: choosing it needs no list.
func _fill_link_choices() -> void:
	for b in link_list.get_children():
		link_list.remove_child(b)
		b.queue_free()
	var choices := []
	for agent in _agents:
		choices.append([str(agent.get("id", "")), str(agent.get("name", agent.get("id", "")))])
	choices.append(["", NONE])
	for i in choices.size():
		var b := make_button("Choice%d" % i, choices[i][1], choose_link.bind(i))
		b.set_meta("agent_id", choices[i][0])
		if ui != null:
			b.custom_minimum_size.y = float(ui.spec.get("button", {}).get("height", 48))
		link_list.add_child(b)


func _refresh_header() -> void:
	if not link_known:
		agent_label.text = ""
		return
	if linked_agent == "":
		agent_label.text = "Agent: " + NONE
		return
	var name := linked_agent
	for agent in _agents:
		if str(agent.get("id", "")) == linked_agent:
			name = str(agent.get("name", linked_agent))
	agent_label.text = "Agent: " + name


func _show_note(text: String) -> void:
	note_label.text = text
	note_label.visible = text != ""


# ---- The boards ----

func _open_boards() -> void:
	request(source.boards(), _on_boards)


func _on_boards(ok: bool, body: Variant, _status: int) -> void:
	if not ok:
		show_error(body if body is Dictionary else {}, _open_boards, BOARDS)
		return
	clear_error(BOARDS)
	_close_boards()
	_boards_listed = true
	var listed = body.get("boards", []) if body is Dictionary else []
	for entry in listed if listed is Array else []:
		if not entry is Dictionary:
			continue
		var board_id := str(entry.get("id", ""))
		board_order.append(board_id)
		_board_names[board_id] = str(entry.get("name", board_id))
		_sections[board_id] = _make_section(board_id)
		_open_board(board_id)
	_refresh_note()


func _open_board(board_id: String) -> void:
	var stream := source.board(board_id)
	if stream == null:
		return
	streams[board_id] = stream
	stream.snapshot.connect(_on_snapshot.bind(board_id))
	stream.board_event.connect(_on_board_event.bind(board_id))
	stream.state_changed.connect(_on_board_state.bind(board_id))
	stream.failed.connect(_on_board_failed.bind(board_id))


## Opens a board's stream again, after it failed.
func _reopen_board(board_id: String) -> void:
	_let_go_of_board(board_id)
	clear_error("board " + board_id)
	_open_board(board_id)


func _let_go_of_board(board_id: String) -> void:
	var stream: StationStream.Board = streams.get(board_id)
	if stream == null:
		return
	streams.erase(board_id)
	for connection in stream.snapshot.get_connections() + stream.board_event.get_connections() \
			+ stream.state_changed.get_connections() + stream.failed.get_connections():
		if connection["callable"].get_object() == self:
			connection["signal"].disconnect(connection["callable"])
	stream.close()


## Closes every board and clears the view.
func _close_boards() -> void:
	for board_id in streams.keys():
		_let_go_of_board(board_id)
	for board_id in _sections:
		var section: Control = _sections[board_id]
		boards_box.remove_child(section)
		section.queue_free()
	_sections.clear()
	_rows.clear()
	boards.clear()
	board_order.clear()
	_last_seq.clear()
	_selected = ""
	_boards_listed = false
	_kept.clear()


func _on_board_failed(reason: Dictionary, board_id: String) -> void:
	show_error(reason, _reopen_board.bind(board_id), "board " + board_id)


func _on_board_state(state: String, board_id: String) -> void:
	var section: Control = _sections.get(board_id)
	if section == null:
		return
	var status: Label = section.get_meta("status")
	status.text = RECONNECTING if state == "offline" else ""
	status.visible = status.text != ""
	if state == "open":
		clear_error("board " + board_id)


## The whole board, on opening and on each reconnection: it replaces what
## the events built.
func _on_snapshot(board_state: Dictionary, board_id: String) -> void:
	boards[board_id] = board_state.duplicate(true)
	_on_board_state("open", board_id)
	_refresh_board(board_id)


func _on_board_event(change: Dictionary, board_id: String) -> void:
	var seq := int(change.get("seq", 0))
	if seq <= int(_last_seq.get(board_id, 0)):
		return
	_last_seq[board_id] = seq
	var state: Dictionary = boards.get(board_id, {})
	if state.is_empty():
		return
	var payload: Dictionary = change.get("payload", {}) if change.get("payload") is Dictionary else {}
	var type := str(change.get("type", ""))
	if type == "activity":
		# The board is unchanged; only a selected card's history grew.
		if _selected == _key(board_id, str(payload.get("cardId", ""))):
			_load_activity(board_id, str(payload.get("cardId", "")))
		return
	WorkBoardState.apply_event(state, type, payload)
	_refresh_board(board_id)


static func _key(board_id: String, card_id: String) -> String:
	return board_id + "/" + card_id


# ---- Drawing the boards ----

func _make_section(board_id: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.name = "Board"
	section.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.name = "Title"
	title.text = _board_names.get(board_id, board_id)
	section.add_child(title)
	var status := Label.new()
	status.name = "Connection"
	status.visible = false
	section.add_child(status)
	section.set_meta("title", title)
	section.set_meta("status", status)
	section.set_meta("stages", {})
	boards_box.add_child(section)
	_style_section(section)
	return section


func _style_section(section: Control) -> void:
	if ui == null:
		return
	var title: Label = section.get_meta("title")
	title.add_theme_font_override("font", ui.heading_font(text_size()))
	title.add_theme_font_size_override("font_size", ui.heading_size(text_size()))
	title.add_theme_color_override("font_color", ui.colour("ink"))
	var status: Label = section.get_meta("status")
	status.add_theme_color_override("font_color", ui.colour("ink_muted"))
	var stages: Dictionary = section.get_meta("stages")
	for key in stages:
		var heading: Label = stages[key].get_meta("heading")
		heading.add_theme_font_override("font", ui.body_font)
		heading.add_theme_font_size_override("font_size", ui.font_size(text_size()))
		heading.add_theme_color_override("font_color", ui.colour("ink_muted"))


## Brings a board's section up to its state: stage by stage, the agent's
## cards in the board's order, and every card shown since Work opened. A
## card's row is kept while it shows, so a comment or answer being typed
## survives the board's events. One pass over the cards: a board event
## costs little however many there are.
func _refresh_board(board_id: String) -> void:
	var section: Control = _sections.get(board_id)
	var state: Dictionary = boards.get(board_id, {})
	if section == null or state.is_empty():
		return
	(section.get_meta("title") as Label).text = str(state.get("name", _board_names.get(board_id, board_id)))
	var stages := WorkBoardState.stages_in_order(state)
	var waits := WorkBoardState.waits_by_card(state)
	# The cards to show, by stage, in the board's order.
	var by_stage := {}
	for card in state.get("cards", []):
		if not card is Dictionary:
			continue
		var card_id := str(card.get("id", ""))
		var key := _key(board_id, card_id)
		if not _kept.has(key) and not WorkBoardState.is_agents_card(card, linked_agent,
				waits[0].get(card_id, {}), waits[1].get(card_id, {})):
			continue
		_kept[key] = true
		var stage_key := str(card.get("currentStageKey", ""))
		if not by_stage.has(stage_key):
			by_stage[stage_key] = []
		by_stage[stage_key].append(card)
	var stage_boxes: Dictionary = section.get_meta("stages")
	var shown := {}
	var at := 2
	for stage in stages:
		var stage_key := str(stage.get("key", ""))
		var group: VBoxContainer = stage_boxes.get(stage_key)
		if group == null:
			group = _make_stage_group(stage_key)
			stage_boxes[stage_key] = group
			section.add_child(group)
			_style_section(section)
		section.move_child(group, at)
		at += 1
		(group.get_meta("heading") as Label).text = str(stage.get("name", stage_key))
		var cards_box: VBoxContainer = group.get_meta("cards")
		var cards: Array = by_stage.get(stage_key, [])
		for index in cards.size():
			var card: Dictionary = cards[index]
			var card_id := str(card.get("id", ""))
			var key := _key(board_id, card_id)
			shown[key] = true
			var row: WorkCardRow = _rows.get(key)
			if row == null:
				row = WorkCardRow.new(self, board_id, card_id)
				_rows[key] = row
				row.restyle(self)
			if row.get_parent() != cards_box:
				if row.get_parent() != null:
					row.get_parent().remove_child(row)
				cards_box.add_child(row)
			if row.get_index() != index:
				cards_box.move_child(row, index)
			row.refresh(card, waits[0].get(card_id, {}), waits[1].get(card_id, {}), stages, state)
		group.visible = not cards.is_empty()
	# Stages the board no longer has go.
	var keys := stages.map(func(s): return str(s.get("key", "")))
	for stage_key in stage_boxes.keys():
		if not stage_key in keys:
			var gone: Control = stage_boxes[stage_key]
			section.remove_child(gone)
			gone.queue_free()
			stage_boxes.erase(stage_key)
	# Cards gone from the board (or from its stages) go.
	for key in _rows.keys():
		if key.begins_with(board_id + "/") and not shown.has(key):
			var row: WorkCardRow = _rows[key]
			_rows.erase(key)
			if row.get_parent() != null:
				row.get_parent().remove_child(row)
			row.queue_free()
			if _selected == key:
				_selected = ""
	_refresh_note()


func _make_stage_group(stage_key: String) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.name = "Stage"
	group.set_meta("key", stage_key)
	group.add_theme_constant_override("separation", 6)
	var heading := Label.new()
	heading.name = "Heading"
	group.add_child(heading)
	var cards_box := VBoxContainer.new()
	cards_box.name = "Cards"
	cards_box.add_theme_constant_override("separation", 6)
	group.add_child(cards_box)
	group.set_meta("heading", heading)
	group.set_meta("cards", cards_box)
	return group


## Says when there is nothing to show: no boards, or none of the agent's
## cards once every board has come; "Loading…" until then.
func _refresh_note() -> void:
	if not link_known or linked_agent == "":
		return
	if not _rows.is_empty():
		_show_note("")
	elif not _boards_listed or boards.size() < board_order.size():
		_show_note(LOADING)
	else:
		_show_note(NO_BOARDS if board_order.is_empty() else NO_CARDS)


## The shown cards' IDs, top to bottom.
func shown_cards() -> Array:
	var ids := []
	for board_id in board_order:
		var section: Control = _sections.get(board_id)
		if section == null:
			continue
		for group in section.get_children():
			if not group.has_meta("cards") or not group.visible:
				continue
			for row in (group.get_meta("cards") as Control).get_children():
				if row is WorkCardRow:
					ids.append(row.card_id)
	return ids


## The row of card `card_id` on board `board_id`, or null when it is not
## shown.
func card_row(board_id: String, card_id: String) -> WorkCardRow:
	return _rows.get(_key(board_id, card_id))


func _board_name(board_id: String) -> String:
	return str(boards.get(board_id, {}).get("name", _board_names.get(board_id, board_id)))


## Shows a failure as Superpipeline's, not the station's.
func show_error(error: Dictionary, retry: Callable, key := "") -> void:
	match str(error.get("kind", "failed")):
		"offline":
			show_line(UNREACHABLE, RETRY, retry, key)
		"no_access":
			show_line(NO_BOARD_ACCESS, "", Callable(), key)
		"signed_out":
			show_line(NOT_ACCEPTED, SIGN_IN_AGAIN, sign_in_requested.emit, key)
		_:
			super(error, retry, key)


# ---- What the player does ----

## A refusal as the board says it: a conflict (a full stage, a settled
## gate) is its own words with nothing to retry; anything else as usual.
func _show_refusal(body: Variant, retry: Callable, key: String) -> void:
	var error: Dictionary = body if body is Dictionary else {}
	if str(error.get("kind", "")) == "conflict":
		var message := str(error.get("message", "")).strip_edges().get_slice("\n", 0)
		show_line(message if message != "" else SOMETHING_WENT_WRONG, "", Callable(), key)
		return
	show_error(error, retry, key)


## Decides the card's pending gate: approve at once; request changes and
## reject ask first, naming the board. The comment is the one in the field
## when the decision is sent, after any question.
func decide(board_id: String, card_id: String, gate_id: String, decision: String) -> void:
	if read_only:
		return
	if decision == "approve":
		_resolve(board_id, card_id, gate_id, decision)
		return
	var title := str(WorkBoardState.find(boards.get(board_id, {}).get("cards", []), card_id).get("title", "this card"))
	var question := ("Request changes to “%s” on %s?" if decision == "request_changes" else "Reject “%s” on %s?") \
			% [title, _board_name(board_id)]
	if source.LIVE:
		question += " " + REAL[decision]
	var verb := "Request changes" if decision == "request_changes" else "Reject"
	ask_first(question, verb, _resolve.bind(board_id, card_id, gate_id, decision))


func _resolve(board_id: String, card_id: String, gate_id: String, decision: String) -> void:
	var key := "gate " + gate_id
	var row := card_row(board_id, card_id)
	var comment := row.gate_comment.text.strip_edges() if row != null else ""
	if row != null:
		row.set_deciding(true)
	request(source.resolve_gate(board_id, gate_id, decision, comment),
		func(ok: bool, body: Variant, _status: int) -> void:
			var now := card_row(board_id, card_id)
			if now != null:
				now.set_deciding(false)
			if not ok:
				_show_refusal(body, _resolve.bind(board_id, card_id, gate_id, decision), key)
				return
			clear_error(key)
			var state: Dictionary = boards.get(board_id, {})
			if state.is_empty():
				return
			WorkBoardState.settle_gate(state, gate_id, decision)
			if body is Dictionary and body.get("card") is Dictionary:
				WorkBoardState.put(state, "cards", body["card"])
			_refresh_board(board_id))


## Answers a question on a card: `option` ("" for none) and `text` (""
## for none).
func answer_question(board_id: String, card_id: String, elicitation_id: String, option: String, text: String) -> void:
	if read_only:
		return
	var key := "answer " + elicitation_id
	var row := card_row(board_id, card_id)
	if row != null:
		row.set_answering(true)
	request(source.answer(board_id, elicitation_id, option, text), func(ok: bool, body: Variant, _status: int) -> void:
		var now := card_row(board_id, card_id)
		if now != null:
			now.set_answering(false)
		if not ok:
			_show_refusal(body, answer_question.bind(board_id, card_id, elicitation_id, option, text), key)
			return
		clear_error(key)
		var state: Dictionary = boards.get(board_id, {})
		if state.is_empty():
			return
		if body is Dictionary:
			if body.get("elicitation") is Dictionary:
				WorkBoardState.put(state, "elicitations", body["elicitation"])
			if body.get("card") is Dictionary:
				WorkBoardState.put(state, "cards", body["card"])
		_refresh_board(board_id))


## Moves a card to `stage_key`.
func move(board_id: String, card_id: String, stage_key: String) -> void:
	if read_only:
		return
	var key := "move " + card_id
	request(source.move_card(board_id, card_id, stage_key), func(ok: bool, body: Variant, _status: int) -> void:
		if not ok:
			_show_refusal(body, move.bind(board_id, card_id, stage_key), key)
			return
		clear_error(key)
		var state: Dictionary = boards.get(board_id, {})
		if state.is_empty():
			return
		WorkBoardState.retire_waits(state, card_id)
		if body is Dictionary and body.get("card") is Dictionary:
			WorkBoardState.put(state, "cards", body["card"])
		_refresh_board(board_id))


## Selects a card, showing its activity, or unselects it.
func select(board_id: String, card_id: String) -> void:
	var key := _key(board_id, card_id)
	var was := _selected
	if _rows.has(was):
		_rows[was].activity.visible = false
	_selected = "" if was == key else key
	if _selected == "":
		return
	var row: WorkCardRow = _rows.get(key)
	if row == null:
		return
	row.activity.visible = true
	place_text(row.activity, LOADING)
	_load_activity(board_id, card_id)


func _load_activity(board_id: String, card_id: String) -> void:
	var key := "activity " + card_id
	request(source.card_activities(board_id, card_id), func(ok: bool, body: Variant, _status: int) -> void:
		var row: WorkCardRow = _rows.get(_key(board_id, card_id))
		if row == null or _selected != _key(board_id, card_id):
			return
		if not ok:
			show_error(body if body is Dictionary else {}, _load_activity.bind(board_id, card_id), key)
			return
		clear_error(key)
		place_text(row.activity, WorkBoardState.activity_text(body if body is Dictionary else {}))
		_scroll_to.call_deferred(row.activity))


## Scrolls `control` into view, when it is still there by then: the card
## may have left, or Work closed, in between.
func _scroll_to(control: Variant) -> void:
	if closed or not is_instance_valid(control) or not (control as Control).is_inside_tree():
		return
	body_scroll.ensure_control_visible(control)
