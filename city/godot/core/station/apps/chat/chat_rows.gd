## The Chat app's transcript as drawn: a row a thing said or done, in the
## transcript's order. Events wait in a queue and are drawn a few a frame
## (`draw_queued`, within a budget), so a long session's replay never holds
## a frame. A bubble's text is set once a frame, however many chunks joined
## it, and a bubble holds one label a paragraph, so a long reply streamed a
## chunk at a time re-lays only its last paragraph.
##
## The rows:
## - the player's prompt, the agent's text and its thoughts: bubbles, where
##   consecutive chunks join the last bubble of their kind;
## - a tool call: one collapsible row, which its updates change in place;
## - a plan: a checklist;
## - a permission request: a card with its options, until it is answered;
## - an error: a notice built from its kind;
## - anything else: a quiet "(update)".
class_name ChatRows
extends RefCounted

## What a paragraph break is in a bubble's text.
const PARAGRAPH := "\n\n"
## The kinds of row that are text: a bubble, or a line.
const TEXT_KINDS := ["prompt", "message", "thought", "plan", "update", "notice"]

var _app: ChatApp
## Where the rows go.
var _box: VBoxContainer
## Events waiting to be drawn, from `_queue_at` on.
var _queue: Array = []
var _queue_at := 0
## The last row drawn: a chunk joins it when it is a bubble of its kind.
var _last_row: Control
## Each tool call's row, by `toolCallId`.
var _tool_rows := {}
## Each permission request's card, by its seq.
var _permission_cards := {}
## The bubbles whose text grew since it was last set.
var _dirty := {}
## Each row kind's label settings and panel, shared by its rows.
var _label_settings := {}
var _panels := {}


func _init(app: ChatApp, box: VBoxContainer) -> void:
	_app = app
	_box = box


## Queues `acp_event` to be drawn.
func queue(acp_event: Dictionary) -> void:
	_queue.append(acp_event)


## Whether events or text are still waiting to be drawn.
func drawing() -> bool:
	return _queue_at < _queue.size() or not _dirty.is_empty()


## Draws everything waiting, at once.
func flush() -> void:
	draw_queued(-1)
	set_text()


## Draws waiting events until `budget_usec` has passed, or all of them when
## it is negative.
func draw_queued(budget_usec: int) -> void:
	var started := Time.get_ticks_usec()
	while _queue_at < _queue.size():
		_draw_event(_queue[_queue_at])
		_queue_at += 1
		if budget_usec >= 0 and Time.get_ticks_usec() - started >= budget_usec:
			break
	if _queue_at >= _queue.size():
		_queue.clear()
		_queue_at = 0


## Sets the text of every bubble that grew, once.
func set_text() -> void:
	for row: Control in _dirty:
		if is_instance_valid(row):
			_lay_out_text(row)
	_dirty.clear()


## Removes every row and everything waiting.
func clear() -> void:
	for row in _box.get_children():
		_box.remove_child(row)
		row.queue_free()
	_queue.clear()
	_queue_at = 0
	_last_row = null
	_tool_rows.clear()
	_permission_cards.clear()
	_dirty.clear()


## Draws the transcript again from `events`, in their order.
func redraw(events: Array) -> void:
	clear()
	_queue = events.duplicate()


## Re-applies the skin to every row.
func restyle() -> void:
	_label_settings.clear()
	_panels.clear()
	for row in _box.get_children():
		_style_row(row)


## The card for the permission request at `seq`, or null.
func permission_card(seq: int) -> Control:
	return _permission_cards.get(seq)


## Shows the answer the transcript holds for request `seq`, if its card is
## drawn.
func show_answer(seq: int) -> void:
	if _permission_cards.has(seq):
		_show_answer(_permission_cards[seq])


## Offers again the options of every request not yet answered: an answer
## sent while the stream dropped may never have reached the hub.
func reopen_options() -> void:
	for seq in _permission_cards:
		var card: Control = _permission_cards[seq]
		for b in (card.get_meta("options") as Control).get_children():
			b.disabled = false
		_show_answer(card)


## The options of request `seq` wait for the hub to record the answer.
func hold_options(seq: int) -> void:
	if _permission_cards.has(seq):
		for b in (_permission_cards[seq].get_meta("options") as Control).get_children():
			b.disabled = true


## The transcript as shown, for tests: each row's kind and its words (a
## text row's whole text; otherwise every label and button showing in it,
## a line each).
func rows() -> Array:
	var out := []
	for row in _box.get_children():
		if row.is_queued_for_deletion():
			continue
		var kind := str(row.get_meta("kind"))
		var words: String = row.get_meta("text") if row.has_meta("text") else "\n".join(_words(row))
		out.append([kind, words])
	return out


static func _words(node: Node) -> PackedStringArray:
	var words := PackedStringArray()
	for child in node.get_children():
		if child is CanvasItem and not child.visible:
			continue
		if (child is Label or child is Button) and child.text != "":
			words.append(child.text)
		words.append_array(_words(child))
	return words


# ---- Drawing one event ----

func _draw_event(acp_event: Dictionary) -> void:
	var payload: Dictionary = acp_event.get("payload", {}) if acp_event.get("payload") is Dictionary else {}
	match str(acp_event.get("type", "")):
		"user-prompt":
			var text := str(payload.get("text", ""))
			var images: Array = payload.get("images", []) if payload.get("images") is Array else []
			if not images.is_empty():
				text += "\n(%d %s)" % [images.size(), "image" if images.size() == 1 else "images"]
			_add_text_row("prompt", text)
		"agent-update":
			_draw_update(payload)
		"permission-request":
			_add_permission_card(int(acp_event.get("seq", 0)), payload)
		"error":
			_add_text_row("notice", ChatApp.notice_for(payload))
		"state", "permission-answer":
			pass
		_:
			_add_text_row("update", ChatApp.UPDATE)


func _draw_update(payload: Dictionary) -> void:
	var update := str(payload.get("sessionUpdate", ""))
	match update:
		"agent_message_chunk", "agent_thought_chunk":
			var kind := "message" if update == "agent_message_chunk" else "thought"
			var text := ChatApp.content_text(payload.get("content"))
			if _last_row != null and _last_row.get_meta("kind") == kind:
				_last_row.set_meta("text", str(_last_row.get_meta("text")) + text)
				_dirty[_last_row] = true
			else:
				_add_text_row(kind, text)
		"tool_call", "tool_call_update":
			var id := str(payload.get("toolCallId", ""))
			var row: Control = _tool_rows.get(id)
			if row == null:
				row = _add_tool_row(id)
			_update_tool_row(row, payload)
		"plan":
			_add_text_row("plan", ChatApp.plan_text(payload.get("entries", [])))
		_:
			_add_text_row("update", ChatApp.UPDATE)


func _add_row(kind: String, row: Control) -> Control:
	row.set_meta("kind", kind)
	_style_row(row)
	_box.add_child(row)
	_last_row = row
	return row


## A bubble or a line of text: a panel holding a label a paragraph.
func _add_text_row(kind: String, text: String) -> Control:
	var row := PanelContainer.new()
	var paragraphs := VBoxContainer.new()
	paragraphs.add_theme_constant_override("separation", 6)
	row.add_child(paragraphs)
	row.set_meta("paragraphs", paragraphs)
	row.set_meta("text", text)
	# Where the last paragraph starts: those before it are laid out for good.
	row.set_meta("sealed", 0)
	_add_row(kind, row)
	_lay_out_text(row)
	return row


## Brings a text row's labels up to its text: each paragraph finished since
## last time gets its own label, and only the last paragraph's is set
## again.
func _lay_out_text(row: Control) -> void:
	var text: String = row.get_meta("text")
	var paragraphs: VBoxContainer = row.get_meta("paragraphs")
	var sealed: int = row.get_meta("sealed")
	if paragraphs.get_child_count() == 0:
		_add_paragraph(row)
	var at := text.find(PARAGRAPH, sealed)
	while at != -1:
		(paragraphs.get_child(-1) as Label).text = text.substr(sealed, at - sealed)
		sealed = at + PARAGRAPH.length()
		_add_paragraph(row)
		at = text.find(PARAGRAPH, sealed)
	row.set_meta("sealed", sealed)
	var last := paragraphs.get_child(-1) as Label
	var tail := text.substr(sealed)
	if last.text != tail:
		last.text = tail


func _add_paragraph(row: Control) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var kind := str(row.get_meta("kind", "message"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if kind == "prompt" else HORIZONTAL_ALIGNMENT_LEFT
	if _label_settings.has(kind):
		label.label_settings = _label_settings[kind]
	(row.get_meta("paragraphs") as Control).add_child(label)


## A tool call: its title, kind and status on a button that shows or hides
## what it did.
func _add_tool_row(id: String) -> Control:
	var row := PanelContainer.new()
	var box := VBoxContainer.new()
	var header := Button.new()
	header.name = "Header"
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.focus_mode = Control.FOCUS_ALL
	header.clip_text = true
	var details := Label.new()
	details.name = "Details"
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.visible = false
	header.pressed.connect(func() -> void:
		details.visible = not details.visible and details.text != ""
		_refresh_tool_header(row))
	box.add_child(header)
	box.add_child(details)
	row.add_child(box)
	row.set_meta("tool", {"toolCallId": id})
	row.set_meta("header", header)
	row.set_meta("details", details)
	_tool_rows[id] = row
	return _add_row("tool", row)


## Takes a tool call's fields, the first report's and each update's.
func _update_tool_row(row: Control, payload: Dictionary) -> void:
	var tool: Dictionary = row.get_meta("tool")
	for field in ["title", "kind", "status", "content", "locations"]:
		if payload.get(field) != null:
			tool[field] = payload[field]
	var lines := PackedStringArray()
	if tool.get("content") is Array:
		for item in tool["content"]:
			if not item is Dictionary:
				continue
			if item.get("type") == "diff":
				lines.append("Changed %s" % str(item.get("path", "")))
			else:
				var text := ChatApp.content_text(item.get("content", item))
				if text != "":
					lines.append(text)
	if tool.get("locations") is Array:
		for location in tool["locations"]:
			if location is Dictionary and location.has("path"):
				lines.append(str(location["path"]))
	var details: Label = row.get_meta("details")
	details.text = "\n".join(lines)
	_refresh_tool_header(row)


func _refresh_tool_header(row: Control) -> void:
	var tool: Dictionary = row.get_meta("tool")
	var details: Label = row.get_meta("details")
	var parts := PackedStringArray([str(tool.get("title", "Tool call"))])
	for field in ["kind", "status"]:
		if tool.get(field) != null and str(tool[field]) != "":
			parts.append(str(tool[field]))
	var mark := "▾" if details.visible else ("▸" if details.text != "" else "·")
	(row.get_meta("header") as Button).text = "%s %s" % [mark, " · ".join(parts)]


## A permission request: what the agent asks to do, and its options.
## Choosing one sends it; the card waits for the hub to record the answer.
func _add_permission_card(seq: int, payload: Dictionary) -> void:
	var row := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var tool: Dictionary = payload.get("toolCall", {}) if payload.get("toolCall") is Dictionary else {}
	var question := Label.new()
	question.name = "Question"
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.text = "The agent asks to: %s" % str(tool.get("title", "use a tool"))
	box.add_child(question)
	var options := HFlowContainer.new()
	options.name = "Options"
	options.add_theme_constant_override("h_separation", 12)
	var names := {}
	for option in payload.get("options", []):
		if not option is Dictionary:
			continue
		var option_id := str(option.get("optionId", ""))
		names[option_id] = str(option.get("name", option_id))
		options.add_child(_app.make_button("Option_" + option_id, names[option_id], _app.choose_option.bind(seq, option_id)))
	box.add_child(options)
	var answer := Label.new()
	answer.name = "Answer"
	answer.visible = false
	box.add_child(answer)
	row.add_child(box)
	row.set_meta("seq", seq)
	row.set_meta("label", question)
	row.set_meta("names", names)
	row.set_meta("options", options)
	row.set_meta("answer", answer)
	row.set_meta("auto", payload.get("auto", false) == true)
	_permission_cards[seq] = row
	_add_row("permission", row)
	_show_answer(row)


## Shows a card's answer, when there is one: what was chosen, or that it
## was cancelled or answered by the mode. Its options go.
func _show_answer(row: Control) -> void:
	var answered = _app.transcript.answer_to(int(row.get_meta("seq")))
	var auto: bool = row.get_meta("auto")
	var answer: Label = row.get_meta("answer")
	var options: Control = row.get_meta("options")
	if answered == null and not auto:
		options.visible = not _app.read_only
		answer.visible = false
		return
	options.visible = false
	answer.visible = true
	var automatic: bool = auto or (answered is Dictionary and answered.get("auto", false))
	var words := ChatApp.ANSWERED_AUTOMATICALLY if automatic else ChatApp.ANSWERED
	if answered is Dictionary and answered.get("cancelled", false):
		answer.text = ChatApp.CANCELLED
	elif answered is Dictionary and answered.has("optionId"):
		var names: Dictionary = row.get_meta("names")
		answer.text = "%s: %s" % [words, names.get(str(answered["optionId"]), str(answered["optionId"]))]
	else:
		answer.text = words


## Gives a row its kind's look: a panel and label settings shared by every
## row of the kind.
func _style_row(row: Control) -> void:
	var ui := _app.ui
	if ui == null:
		return
	var kind := str(row.get_meta("kind", "update"))
	if not _label_settings.has(kind):
		var settings := LabelSettings.new()
		settings.font = ui.body_font
		settings.font_size = ui.font_size(_app.text_size() - (4 if kind in ["update", "thought", "notice"] else 0))
		settings.font_color = ui.colour("ink_muted") if kind in ["update", "thought"] else ui.colour("ink")
		_label_settings[kind] = settings
		var panel := _app.well_box()
		if kind == "prompt":
			panel.bg_color = panel.bg_color.lerp(ui.colour("accent"), 0.15)
		elif kind in ["update", "thought", "notice"]:
			panel.bg_color.a = 0.0
			panel.set_border_width_all(0)
		_panels[kind] = panel
	row.add_theme_stylebox_override("panel", _panels[kind])
	if row.has_meta("header"):
		_app.ink_button(row.get_meta("header"))
	for key in ["label", "details", "answer"]:
		if row.has_meta(key):
			(row.get_meta(key) as Label).label_settings = _label_settings[kind]
	if row.has_meta("paragraphs"):
		for label in (row.get_meta("paragraphs") as Control).get_children():
			label.label_settings = _label_settings[kind]
