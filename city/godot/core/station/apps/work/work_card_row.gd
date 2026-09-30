## One of the agent's cards in the Work app: its title (which selects it),
## its state, a menu to move it, its pending gate's decisions, its open
## question, what became of the last gate or question it showed, and,
## while selected, its activity. The row stays while the card shows, so a
## comment or an answer being typed survives the board's events.
class_name WorkCardRow
extends PanelContainer

## What became of a gate the row showed, by its decision.
const OUTCOMES := {"approve": "Approved", "request_changes": "Changes requested", "reject": "Rejected"}
const ANSWERED := "Answered"
const GATE_CANCELLED := "Gate cancelled"
const QUESTION_CANCELLED := "Question cancelled"
const MOVE := "Move"
const ANSWER := "Answer"
const COMMENT_HINT := "Comment (optional)"
const ANSWER_HINT := "Your answer"
## A card's state as the chip says it; another state is shown capitalised.
const STATE_WORDS := {
	"submitted": "Submitted", "working": "Working", "input-required": "Input required",
	"auth-required": "Sign-in required", "completed": "Completed", "rejected": "Rejected", "failed": "Failed",
	"canceled": "Cancelled", "cancelled": "Cancelled",
}
## The gate's decisions, in the order offered, and their buttons' words.
const DECISIONS := [["approve", "Approve"], ["request_changes", "Request changes"], ["reject", "Reject"]]

var app: WorkApp
var board_id: String
var card_id: String
var title_button: Button
var state_chip: Label
var move_menu: MenuButton
## What became of the last gate or question the row showed.
var outcome_label: Label
var gate_box: VBoxContainer
var gate_label: Label
var gate_comment: LineEdit
## The decision buttons, by decision.
var decision_buttons := {}
var question_box: VBoxContainer
var question_label: Label
var options_box: HFlowContainer
## The option buttons, by option name.
var option_buttons := {}
var answer_field: LineEdit
var answer_button: Button
var activity: TextEdit

## The stages the menu offers, in its order, and what it was built from.
var _stages: Array = []
var _menu_built_from := ""
var _gate := {}
var _question := {}
## The chosen option's name, or "".
var _chosen := ""
## Whether a decision or an answer is on its way.
var _deciding := false
var _answering := false
## The skin's button height, for option buttons made after styling.
var _button_height := 0.0
## What the row was last shown from, so an unchanged card costs nothing.
var _shown_from := 0


func _init(owner_app: WorkApp, board: String, card: String) -> void:
	app = owner_app
	board_id = board
	card_id = card
	name = "Card"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	title_button = app.make_button("Title", "", func() -> void: app.select(board_id, card_id))
	title_button.flat = true
	title_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_button.clip_text = true
	title_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_button)
	state_chip = Label.new()
	state_chip.name = "State"
	top.add_child(state_chip)
	move_menu = MenuButton.new()
	move_menu.name = "Move"
	move_menu.text = MOVE
	move_menu.focus_mode = Control.FOCUS_ALL
	move_menu.visible = not app.read_only
	move_menu.get_popup().id_pressed.connect(func(index: int) -> void:
		if index >= 0 and index < _stages.size():
			move_to(_stages[index]))
	top.add_child(move_menu)
	box.add_child(top)

	outcome_label = Label.new()
	outcome_label.name = "Outcome"
	outcome_label.visible = false
	box.add_child(outcome_label)

	gate_box = VBoxContainer.new()
	gate_box.name = "Gate"
	gate_label = Label.new()
	gate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gate_box.add_child(gate_label)
	gate_comment = LineEdit.new()
	gate_comment.name = "Comment"
	gate_comment.placeholder_text = COMMENT_HINT
	gate_comment.visible = not app.read_only
	gate_box.add_child(gate_comment)
	var decisions := HBoxContainer.new()
	decisions.add_theme_constant_override("separation", 12)
	decisions.visible = not app.read_only
	for pair in DECISIONS:
		var b := app.make_button(str(pair[0]).capitalize().replace(" ", ""), pair[1], _decide.bind(pair[0]))
		decision_buttons[pair[0]] = b
		decisions.add_child(b)
	gate_box.add_child(decisions)
	gate_box.visible = false
	box.add_child(gate_box)

	question_box = VBoxContainer.new()
	question_box.name = "Question"
	question_label = Label.new()
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_box.add_child(question_label)
	options_box = HFlowContainer.new()
	options_box.add_theme_constant_override("h_separation", 12)
	question_box.add_child(options_box)
	answer_field = LineEdit.new()
	answer_field.name = "AnswerText"
	answer_field.placeholder_text = ANSWER_HINT
	answer_field.text_changed.connect(func(_text: String) -> void: _refresh_answer())
	answer_field.text_submitted.connect(func(_text: String) -> void: submit_answer())
	question_box.add_child(answer_field)
	answer_button = app.make_button("Answer", ANSWER, submit_answer)
	answer_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	question_box.add_child(answer_button)
	question_box.visible = false
	box.add_child(question_box)

	activity = TextEdit.new()
	activity.name = "Activity"
	activity.editable = false
	activity.custom_minimum_size = Vector2(0, 160)
	activity.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	activity.visible = false
	box.add_child(activity)
	add_child(box)


func restyle(owner_app: WorkApp) -> void:
	var skin := owner_app.ui
	if skin == null:
		return
	add_theme_stylebox_override("panel", owner_app.well_box())
	owner_app.ink_button(title_button)
	owner_app.ink_button(move_menu)
	for field in [gate_comment, answer_field]:
		field.add_theme_color_override("font_placeholder_color", skin.colour("ink_muted"))
	for l in [state_chip, outcome_label, gate_label, question_label]:
		l.add_theme_font_override("font", skin.body_font)
		l.add_theme_font_size_override("font_size", skin.font_size(owner_app.text_size() - 2))
		l.add_theme_color_override("font_color", skin.colour("ink"))
	for l in [state_chip, outcome_label]:
		l.add_theme_color_override("font_color", skin.colour("ink_muted"))
	activity.add_theme_font_override("font", owner_app.mono_font())
	activity.add_theme_font_size_override("font_size", skin.font_size(maxi(10, owner_app.text_size() - 4)))
	activity.add_theme_color_override("font_readonly_color", skin.colour("ink"))
	activity.add_theme_stylebox_override("read_only", owner_app.well_box())
	_button_height = float(skin.spec.get("button", {}).get("height", 48))
	for b in find_children("*", "Button", true, false):
		b.custom_minimum_size.y = _button_height


## Shows `card` as it now stands, with its pending gate and open question
## ({} for none), among `stages`, on the board `state`: what became of a
## gate or question that has gone is looked up there.
func refresh(card: Dictionary, gate: Dictionary, question: Dictionary, stages: Array, state: Dictionary) -> void:
	var shown_from := [card, gate, question, stages].hash()
	if shown_from == _shown_from:
		return
	_shown_from = shown_from
	title_button.text = str(card.get("title", card_id))
	var card_state := str(card.get("state", ""))
	state_chip.text = STATE_WORDS.get(card_state, card_state.capitalize())
	var here := str(card.get("currentStageKey", ""))
	set_meta("stage", here)
	_refresh_menu(here, stages)
	var outcome := ""
	if gate.is_empty() and not _gate.is_empty():
		outcome = _gate_outcome(WorkBoardState.find(state.get("gates", []), str(_gate["id"])))
	if question.is_empty() and not _question.is_empty():
		outcome = _question_outcome(WorkBoardState.find(state.get("elicitations", []), str(_question["id"])))
	if outcome != "":
		outcome_label.text = outcome
	outcome_label.visible = outcome_label.text != "" and gate.is_empty() and question.is_empty()
	if str(gate.get("id", "")) != str(_gate.get("id", "")):
		gate_comment.text = ""
	_gate = gate
	gate_box.visible = not gate.is_empty()
	if not gate.is_empty():
		gate_label.text = "Waiting for your decision at %s." % _stage_name(stages, str(gate.get("stageKey", here)))
	if str(question.get("id", "")) != str(_question.get("id", "")):
		_show_question(question)
	_question = question
	question_box.visible = not question.is_empty()


## Rebuilds the move menu only when its stages or the card's changed.
func _refresh_menu(here: String, stages: Array) -> void:
	var built_from := here
	for stage in stages:
		built_from += "|%s=%s" % [stage.get("key", ""), stage.get("name", "")]
	if built_from == _menu_built_from:
		return
	_menu_built_from = built_from
	_stages = []
	var popup := move_menu.get_popup()
	popup.clear()
	for stage in stages:
		var key := str(stage.get("key", ""))
		if key != here:
			popup.add_item(str(stage.get("name", key)), _stages.size())
			_stages.append(key)


static func _gate_outcome(gate: Dictionary) -> String:
	match str(gate.get("status", "")):
		"resolved":
			return OUTCOMES.get(str(gate.get("decision", "")), "Decided")
		"cancelled":
			return GATE_CANCELLED
	return ""


static func _question_outcome(question: Dictionary) -> String:
	match str(question.get("status", "")):
		"answered":
			return ANSWERED
		"cancelled":
			return QUESTION_CANCELLED
	return ""


## The stages the card can move to, in order.
func move_targets() -> Array:
	return _stages.duplicate()


func move_to(stage_key: String) -> void:
	app.move(board_id, card_id, stage_key)


func _decide(decision: String) -> void:
	if _gate.is_empty() or _deciding:
		return
	app.decide(board_id, card_id, str(_gate["id"]), decision)


## The decision buttons wait while a decision is on its way.
func set_deciding(deciding: bool) -> void:
	_deciding = deciding
	for decision in decision_buttons:
		decision_buttons[decision].disabled = deciding


## The answer waits while it is on its way.
func set_answering(answering: bool) -> void:
	_answering = answering
	_refresh_answer()


func _show_question(question: Dictionary) -> void:
	for b in options_box.get_children():
		options_box.remove_child(b)
		b.queue_free()
	option_buttons.clear()
	_chosen = ""
	answer_field.text = ""
	question_label.text = str(question.get("question", ""))
	var options = question.get("options", [])
	for option in options if options is Array else []:
		if not option is Dictionary:
			continue
		var option_name := str(option.get("name", ""))
		var b := app.make_button("Option_" + option_name, str(option.get("title", option_name)), _choose.bind(option_name))
		b.toggle_mode = true
		b.disabled = app.read_only
		b.custom_minimum_size.y = _button_height
		b.set_meta("interactive", option.get("interactive", false) == true)
		option_buttons[option_name] = b
		options_box.add_child(b)
	_refresh_answer()


func _choose(option_name: String) -> void:
	if app.read_only:
		return
	_chosen = option_name
	for key in option_buttons:
		option_buttons[key].set_pressed_no_signal(key == option_name)
	_refresh_answer()


## Whether the answer needs text: with no options, or with an interactive
## option chosen.
func _needs_text() -> bool:
	if option_buttons.is_empty():
		return true
	return _chosen != "" and bool(option_buttons[_chosen].get_meta("interactive"))


func _refresh_answer() -> void:
	answer_field.visible = _needs_text() and not app.read_only
	answer_button.visible = not app.read_only
	var ready := _chosen != "" or option_buttons.is_empty()
	if _needs_text():
		ready = ready and answer_field.text.strip_edges() != ""
	answer_button.disabled = _answering or not ready


## Sends the answer: the text alone, the option alone, or both.
func submit_answer() -> void:
	if app.read_only or _question.is_empty() or _answering:
		return
	if not option_buttons.is_empty() and _chosen == "":
		return
	var text := answer_field.text.strip_edges() if _needs_text() else ""
	if _needs_text() and text == "":
		return
	app.answer_question(board_id, card_id, str(_question["id"]), _chosen, text)


static func _stage_name(stages: Array, key: String) -> String:
	for stage in stages:
		if str(stage.get("key", "")) == key:
			return str(stage.get("name", key))
	return key
