## The rebinding screen, opened from the Controls page of the settings: one
## row per player action, with its key and its controller button. Choosing
## either waits for the next key or button press and binds it. Esc and B
## both cancel the wait, except that Esc is bound when waiting for the
## menu's key (Esc is its key), and B when waiting for Stop's button (B is
## its button); the hint says which cancels. A press another action already
## uses asks whether to swap the two. Bindings are saved to
## `controls/bindings` as `{action: {"key": physical keycode, "pad": button
## index}}` (-1 for none) and applied to the `InputMap` at once; the
## project's own map is kept from boot so "Reset to defaults" can restore
## it. A stick or trigger an action also has (walking, zooming) stays as it
## is.
extends Screen
class_name RebindScreen

const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "interact", "interact_alt", "cancel", "menu", "map",
	"toggle_fpv", "zoom_in", "zoom_out", "names", "cycle_look"]
## What each action is called on screen.
const LABELS := {
	"move_forward": "Move forward", "move_back": "Move back", "move_left": "Move left", "move_right": "Move right",
	"interact": "Act", "interact_alt": "More actions", "cancel": "Stop", "menu": "Menu", "map": "Map", "toggle_fpv": "First person",
	"zoom_in": "Zoom in", "zoom_out": "Zoom out", "names": "Name tags", "cycle_look": "Change look",
}
## The label's width, and each binding button's.
const LABEL_WIDTH := 240.0
const BUTTON_WIDTH := 200.0
## How tall the list may grow before it scrolls.
const LIST_HEIGHT := 360.0

var settings: Settings

## The action a press would swap with, while "Also used by …" is asked;
## "" otherwise.
var conflict := ""

## action -> {"key": Button, "pad": Button}
var rows := {}
var title: Label
## What the screen is waiting for, or how to use it.
var hint: Label
var back_button: Button
## The swap question, over the list.
var prompt: Control
var prompt_label: Label
var swap_button: Button
var cancel_button: Button

## The action and kind ("key" or "pad") waiting for a press; "" when none.
var _action := ""
var _kind := ""
## The press waiting on the swap question.
var _pending := -1

## action -> the project's own events for it, kept once at boot before any
## binding is applied.
static var _defaults := {}


## Keeps the project's input map for every action in ACTIONS, once: later
## calls do nothing, so bindings applied since are never taken for the
## defaults.
static func capture_defaults() -> void:
	if not _defaults.is_empty():
		return
	for action in ACTIONS:
		_defaults[action] = InputMap.action_get_events(action).map(func(e): return e.duplicate())


## Applies the saved bindings over the project's input map (run at boot).
## A saved binding wins over a default: another action whose default is
## the same key or button loses it, as a rebind on this screen would take
## it, so nothing answers to one press twice (the defaults change between
## versions: Y went from name tags to More actions).
static func apply_bindings(s: Settings) -> void:
	capture_defaults()
	_restore_defaults()
	var bindings = s.get_value("controls", "bindings")
	if not bindings is Dictionary:
		return
	for action in bindings:
		if not action in ACTIONS or not bindings[action] is Dictionary:
			continue
		for kind in ["key", "pad"]:
			if bindings[action].has(kind):
				_set_event(action, kind, int(bindings[action][kind]))
	for action in bindings:
		if not action in ACTIONS or not bindings[action] is Dictionary:
			continue
		for kind in ["key", "pad"]:
			if not bindings[action].has(kind):
				continue
			var code := int(bindings[action][kind])
			for other in ACTIONS:
				var saved = bindings.get(other, {})
				if other != action and not (saved is Dictionary and saved.has(kind)):
					_drop_event(other, kind, code)


## Takes key or controller button `code` off `action`, if it has it,
## leaving its other events.
static func _drop_event(action: String, kind: String, code: int) -> void:
	for e in InputMap.action_get_events(action):
		if kind == "key" and e is InputEventKey and _key_code(e) == code \
				or kind == "pad" and e is InputEventJoypadButton and e.button_index == code:
			InputMap.action_erase_event(action, e)


## Puts the project's input map back and forgets every saved binding.
static func reset(s: Settings) -> void:
	capture_defaults()
	_restore_defaults()
	s.set_value("controls", "bindings", {})


static func _restore_defaults() -> void:
	for action in _defaults:
		InputMap.action_erase_events(action)
		for e in _defaults[action]:
			InputMap.action_add_event(action, e.duplicate())


## The key (a physical keycode, or the keycode where the project gives
## only that) or controller button `action` answers to now; -1 for none.
static func current(action: String, kind: String) -> int:
	for e in InputMap.action_get_events(action):
		if kind == "key" and e is InputEventKey:
			return _key_code(e)
		if kind == "pad" and e is InputEventJoypadButton:
			return e.button_index
	return -1


static func _key_code(e: InputEventKey) -> int:
	return e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode


## Replaces `action`'s keys (or controller buttons) with `code`, or with
## none when `code` is negative. Its sticks and triggers are left alone.
static func _set_event(action: String, kind: String, code: int) -> void:
	for e in InputMap.action_get_events(action):
		if (kind == "key" and e is InputEventKey) or (kind == "pad" and e is InputEventJoypadButton):
			InputMap.action_erase_event(action, e)
	if code < 0 or (kind == "key" and code == KEY_NONE):
		return
	var event: InputEvent
	if kind == "key":
		event = InputEventKey.new()
		event.physical_keycode = code
	else:
		event = InputEventJoypadButton.new()
		event.button_index = code
	# Any device, as the project's own events are.
	event.device = -1
	InputMap.action_add_event(action, event)


## Whether a press is awaited.
func waiting() -> bool:
	return _action != ""


## Waits for the next key (`kind` "key") or controller button ("pad") to
## bind to `action`.
func begin(action: String, kind: String) -> void:
	_action = action
	_kind = kind
	conflict = ""
	_refresh()


## Takes a press while one is awaited: binds it, asks about a conflict, or
## cancels the wait (Esc, unless waiting for the menu's key; B, unless
## waiting for Stop's button). Releases, repeats and anything else are
## ignored.
func capture(event: InputEvent) -> void:
	if _action == "" or conflict != "" or not event.is_pressed() or event.is_echo():
		return
	var code := -1
	if event is InputEventKey:
		var key := _key_code(event)
		if key == KEY_ESCAPE and (_kind == "pad" or _action != "menu"):
			_stop()
			return
		if _kind != "key":
			return
		code = key
	elif event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_B and (_kind == "key" or _action != "cancel"):
			_stop()
			return
		if _kind != "pad":
			return
		code = event.button_index
	else:
		return
	var other := _user_of(_kind, code)
	if other != "" and other != _action:
		conflict = other
		_pending = code
		_ask()
		return
	_bind(_action, _kind, code)
	_stop()


## Answers the swap question: swap gives the action the press and the
## other action this one's old binding; cancel leaves both as they were.
func resolve(swap: bool) -> void:
	if conflict == "":
		return
	if swap:
		var mine := current(_action, _kind)
		_bind(_action, _kind, _pending)
		_bind(conflict, _kind, mine)
	conflict = ""
	_pending = -1
	if prompt != null:
		prompt.visible = false
	_stop()


## The other action in ACTIONS bound to `code`, or "".
func _user_of(kind: String, code: int) -> String:
	for action in ACTIONS:
		if action != _action and current(action, kind) == code:
			return action
	return ""


## Saves and applies one binding.
func _bind(action: String, kind: String, code: int) -> void:
	var bindings = settings.get_value("controls", "bindings")
	bindings = bindings.duplicate(true) if bindings is Dictionary else {}
	var entry: Dictionary = bindings.get(action, {}).duplicate()
	entry[kind] = code
	bindings[action] = entry
	_set_event(action, kind, code)
	settings.set_value("controls", "bindings", bindings)


## Stops waiting, and puts focus back on the button that started it.
func _stop() -> void:
	var was := _action
	var kind := _kind
	_action = ""
	_kind = ""
	_refresh()
	if rows.has(was) and rows[was][kind].is_visible_in_tree():
		rows[was][kind].grab_focus()


## While a press is awaited, every key and controller button goes to
## `capture` before anything else sees it: the stack must not take Esc for
## Back, nor a button its focus.
func _input(event: InputEvent) -> void:
	if _action == "" or conflict != "" or (stack != null and stack.top() != self):
		return
	if event is InputEventKey or event is InputEventJoypadButton:
		capture(event)
		get_viewport().set_input_as_handled()


## Back cancels a wait or the swap question before it closes the screen.
func on_back() -> bool:
	if conflict != "":
		resolve(false)
		return true
	if _action != "":
		_stop()
		return true
	return false


func build() -> void:
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var panel := PanelContainer.new()
	centre.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	title = Label.new()
	title.name = "Title"
	title.text = "Controls"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var heading := HBoxContainer.new()
	heading.name = "Heading"
	for text in ["", "Keyboard", "Controller"]:
		var h := Label.new()
		h.text = text
		h.custom_minimum_size.x = LABEL_WIDTH if text == "" else BUTTON_WIDTH
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.add_child(h)
	box.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.name = "List"
	scroll.custom_minimum_size.y = LIST_HEIGHT
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for action in ACTIONS:
		list.add_child(_row(action))

	hint = Label.new()
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = "Back"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func(): _close.call_deferred())
	box.add_child(back_button)

	_build_prompt()
	_link_focus()
	_refresh()


func _row(action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = action
	var label := Label.new()
	label.name = "Label"
	label.text = LABELS.get(action, action)
	label.custom_minimum_size.x = LABEL_WIDTH
	row.add_child(label)
	var buttons := {}
	for kind in ["key", "pad"]:
		var b := Button.new()
		b.name = kind.capitalize()
		b.custom_minimum_size.x = BUTTON_WIDTH
		b.pressed.connect(begin.bind(action, kind))
		row.add_child(b)
		buttons[kind] = b
	rows[action] = buttons
	return row


## "Also used by …. Swap?", with Swap and Cancel, over the list.
func _build_prompt() -> void:
	prompt = Control.new()
	prompt.name = "Prompt"
	prompt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	prompt.visible = false
	add_child(prompt)
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.add_child(scrim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.add_child(centre)
	var panel := PanelContainer.new()
	centre.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(prompt_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	swap_button = Button.new()
	swap_button.name = "Swap"
	swap_button.text = "Swap"
	swap_button.pressed.connect(resolve.bind(true))
	buttons.add_child(swap_button)
	cancel_button = Button.new()
	cancel_button.name = "Cancel"
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(resolve.bind(false))
	buttons.add_child(cancel_button)
	# The d-pad stays on the question until it is answered.
	for pair in [[swap_button, cancel_button], [cancel_button, swap_button]]:
		var b: Button = pair[0]
		var other: Button = pair[1]
		b.focus_neighbor_left = b.get_path_to(other)
		b.focus_neighbor_right = b.get_path_to(other)
		b.focus_neighbor_top = b.get_path_to(b)
		b.focus_neighbor_bottom = b.get_path_to(b)
		b.focus_next = b.get_path_to(other)
		b.focus_previous = b.get_path_to(other)


func _ask() -> void:
	prompt_label.text = "Also used by %s. Swap?" % LABELS.get(conflict, conflict)
	prompt.visible = true
	if swap_button.is_visible_in_tree():
		swap_button.grab_focus()


## The d-pad moves up and down a column, and across between a row's key
## and controller button; down from the last row reaches Back.
func _link_focus() -> void:
	var n := ACTIONS.size()
	for i in n:
		var row: Dictionary = rows[ACTIONS[i]]
		for kind in ["key", "pad"]:
			var b: Button = row[kind]
			var other: Button = row["pad" if kind == "key" else "key"]
			b.focus_neighbor_left = b.get_path_to(other)
			b.focus_neighbor_right = b.get_path_to(other)
			b.focus_neighbor_top = b.get_path_to(rows[ACTIONS[i - 1]][kind] if i > 0 else b)
			b.focus_neighbor_bottom = b.get_path_to(rows[ACTIONS[i + 1]][kind] if i < n - 1 else back_button)
			b.focus_previous = b.focus_neighbor_top
			b.focus_next = b.focus_neighbor_bottom
	back_button.focus_neighbor_top = back_button.get_path_to(rows[ACTIONS[n - 1]]["key"])
	back_button.focus_neighbor_bottom = back_button.get_path_to(back_button)
	back_button.focus_neighbor_left = back_button.get_path_to(back_button)
	back_button.focus_neighbor_right = back_button.get_path_to(back_button)
	back_button.focus_previous = back_button.focus_neighbor_top
	back_button.focus_next = back_button.get_path_to(rows[ACTIONS[0]]["key"])


## Every button's binding, the one waiting marked, and the hint.
func _refresh() -> void:
	if rows.is_empty():
		return
	for action in rows:
		for kind in ["key", "pad"]:
			var b: Button = rows[action][kind]
			if action == _action and kind == _kind:
				b.text = "Press a key…" if kind == "key" else "Press a button…"
			else:
				b.text = key_name(action) if kind == "key" else pad_name(action)
	if _action == "":
		hint.text = "Choose a key or button to change it."
	elif _kind == "key":
		hint.text = "Press the new key for %s. %s" % [LABELS.get(_action, _action), _cancel_text()]
	else:
		hint.text = "Press the new button for %s. %s" % [LABELS.get(_action, _action), _cancel_text()]


## What cancels the wait now: Esc on the keyboard and B on a controller,
## less whichever of the two is being bound (see `capture`).
func _cancel_text() -> String:
	var b := InputGlyphs.button_name(JOY_BUTTON_B)
	if _kind == "key":
		return "%s cancels." % b if _action == "menu" else "Esc or %s cancels." % b
	return "Esc cancels." if _action == "cancel" else "%s or Esc cancels." % b


## The name of `action`'s key, or "—" when it has none.
static func key_name(action: String) -> String:
	var code := current(action, "key")
	if code <= 0:
		return "—"
	var text := OS.get_keycode_string(code)
	return InputGlyphs.KEY_SHORT_NAMES.get(text, text)


## The name of `action`'s controller button, else of its stick or trigger,
## or "—" when it has none.
static func pad_name(action: String) -> String:
	var button := current(action, "pad")
	if button >= 0:
		return InputGlyphs.button_name(button)
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion:
			match e.axis:
				JOY_AXIS_TRIGGER_LEFT:
					return "LT"
				JOY_AXIS_TRIGGER_RIGHT:
					return "RT"
				JOY_AXIS_LEFT_X:
					return "Left stick " + ("left" if e.axis_value < 0 else "right")
				JOY_AXIS_LEFT_Y:
					return "Left stick " + ("up" if e.axis_value < 0 else "down")
	return "—"


## Closes the screen from its own Back button, once the press is over.
func _close() -> void:
	if stack != null and stack.top() == self:
		stack.pop()


func restyle() -> void:
	title.add_theme_font_override("font", ui.display_font)
	title.add_theme_font_size_override("font_size", ui.display_size(28))
	title.text = ui.case("Controls")
	hint.add_theme_color_override("font_color", ui.colour("ink_muted"))
	prompt.get_node("Scrim").color = ui.colour("scrim")
	var height := float(ui.spec.get("button", {}).get("height", 48))
	for b in [back_button, swap_button, cancel_button]:
		b.text = ui.case(str(b.name))
		b.custom_minimum_size = Vector2(160, height)
	for action in rows:
		for kind in ["key", "pad"]:
			rows[action][kind].custom_minimum_size.y = height
