## The settings, opened from the game menu: six pages (Graphics, Controls,
## Interface, Accessibility, Developer and Station computer) under a tab
## bar, each a list of rows. A row is an `HBoxContainer` named after its
## setting's key, holding a label and the value's control: a choice list,
## an on/off switch, a slider for a sensitivity, or a text field for an
## address. Up and down move through the rows, left and right change the
## focused one, and Q and E (LB and RB) switch pages.
## Every change is saved and applied at once (main listens to
## `Settings.changed`), except that a display change asks to be kept and
## reverts after CONFIRM_S seconds without an answer.
extends Screen
class_name SettingsScreen

## How long a display change waits to be kept before it reverts.
const CONFIRM_S := 10.0
const PAGES := ["Graphics", "Controls", "Interface", "Accessibility", "Developer", "Station computer"]
## The sensitivities' range and step.
const SENSITIVITY_MIN := 0.25
const SENSITIVITY_MAX := 3.0
const SENSITIVITY_STEP := 0.25
## The label's width, and the value control's.
const LABEL_WIDTH := 300.0
const CONTROL_WIDTH := 260.0
## The page names' size in the narrow layout when the six of them at the
## skin's body size would run off the window (every style's, at 800 px).
const NARROW_TAB_SIZE := 16
## What the panel takes round its page names: its margins and a frame.
const TAB_ROOM := 96.0
## The Vsync row's words while an unlimited frame cap holds it off.
const VSYNC_FORCED_TEXT := "Off (unlimited frame cap)"
## The addresses that carry the station computer's secrets (the device
## credential, its tokens): each must be `https://`, or plain `http://` on
## this computer only (see StationHttp.is_secure_or_loopback). What
## Settings says of any other.
const SECRET_ADDRESSES := ["hub_url", "superpipeline_url"]
const NOT_HTTPS := "Use an https:// address (http:// only for this computer: localhost, 127.0.0.1 or [::1])."

## Every row, page by page: its key, section and label, and either the
## choices it offers ([text, value], in order), "toggle", "slider" or
## "text".
const ROWS := [
	{"key": "display", "section": "graphics", "page": 0, "label": "Display",
		"choices": [["Windowed", "windowed"], ["Fullscreen", "fullscreen"]]},
	{"key": "vsync", "section": "graphics", "page": 0, "label": "Vsync", "kind": "toggle"},
	{"key": "frame_cap", "section": "graphics", "page": 0, "label": "Frame cap",
		"choices": [["Display rate", 0], ["60", 60], ["120", 120], ["144", 144], ["240", 240], ["Unlimited", -1]]},
	{"key": "quality", "section": "graphics", "page": 0, "label": "Quality",
		"choices": [["High", "high"], ["Low", "low"]]},
	{"key": "mouse_sensitivity", "section": "controls", "page": 1, "label": "Mouse look sensitivity", "kind": "slider"},
	{"key": "stick_sensitivity", "section": "controls", "page": 1, "label": "Stick look sensitivity", "kind": "slider"},
	{"key": "invert_y", "section": "controls", "page": 1, "label": "Invert look Y", "kind": "toggle"},
	{"key": "names", "section": "interface", "page": 2, "label": "Name tags", "kind": "toggle"},
	{"key": "text_size", "section": "interface", "page": 2, "label": "Text size",
		"choices": [["100%", 1.0], ["125%", 1.25], ["150%", 1.5]]},
	{"key": "join_as", "section": "interface", "page": 2, "label": "Join as",
		"choices": [["Visitor", "registered"], ["Observer", "observer"], ["Just watch", "none"]]},
	{"key": "calm", "section": "accessibility", "page": 3, "label": "Calm mode", "kind": "toggle"},
	{"key": "tools", "section": "developer", "page": 4, "label": "Developer tools", "kind": "toggle"},
	{"key": "live", "section": "station", "page": 5, "label": "Live mode (connects to your AgentPod)", "kind": "toggle"},
	{"key": "hub_url", "section": "station", "page": 5, "label": "AgentPod hub address", "kind": "text"},
	{"key": "superpipeline_url", "section": "station", "page": 5, "label": "Superpipeline address", "kind": "text"},
	{"key": "console_url", "section": "station", "page": 5, "label": "AgentPod console address", "kind": "text"},
	{"key": "client_id", "section": "station", "page": 5, "label": "Client ID", "kind": "text"},
]

## Fired by the Interface page's Look row, for the Join screen's look step.
signal open_look
## The Station computer page's "Disconnect": main revokes and forgets the
## AgentPod sign-in (see StationCredential.disconnect_device).
signal disconnect_requested
## "Open the AgentPod console", offered when a device was not revoked.
signal console_requested

var settings: Settings
## The page to open at, by name ("" for the first); set before pushing,
## as the station computer's "Connect your AgentPod" does.
var start_page := ""

## Whether "Keep this display setting?" is being asked.
var confirming := false

## The centred panel, which steps aside while a screen opened from it
## (rebinding, the look) is on top, as the game menu's does: a see-through
## skin would show it through that screen.
var panel: PanelContainer
var title: Label
var tabs: TabBar
## One VBoxContainer of rows per page, only the current one shown.
var pages: Array[VBoxContainer] = []
## How to switch pages, under them.
var hint: Label
var back_button: Button
var rebind_button: Button
var reset_button: Button
## The Interface page's Look row's button, which opens the Join screen's
## look step (see `open_look`).
var look_button: Button
## The Station computer page's Disconnect row's button, what it last said,
## and the console, offered when a device was not revoked. Main sets them
## through `show_station_account`.
var disconnect_button: Button
var disconnect_note: Label
var console_hint_button: Button
## Under the Station computer page's addresses: why the last one typed was
## refused, while it stands.
var address_note: Label
var _account := {"held": false, "running": false, "message": "", "console_hint": false}
## key -> the row's value control.
var _controls := {}
## key -> the slider row's value label ("1.25×").
var _amounts := {}
## The display question, over the pages.
var confirm: Control
var confirm_label: Label
var keep_button: Button
var revert_button: Button
var _confirm_left := 0.0
var _revert_to = null


func build() -> void:
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	panel = PanelContainer.new()
	centre.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	if stack != null:
		stack.changed.connect(_on_stack_changed)

	title = Label.new()
	title.name = "Title"
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	tabs = TabBar.new()
	tabs.name = "Pages"
	tabs.focus_mode = Control.FOCUS_NONE
	tabs.tab_alignment = TabBar.ALIGNMENT_CENTER
	# Every page's name shows whole: the panel widens, as far as the window
	# allows (see _fit_tabs).
	tabs.clip_tabs = false
	for page in PAGES:
		tabs.add_tab(page)
	box.add_child(tabs)

	for page in PAGES:
		var list := VBoxContainer.new()
		list.name = page
		list.add_theme_constant_override("separation", 12)
		list.custom_minimum_size.x = LABEL_WIDTH + CONTROL_WIDTH + 64
		box.add_child(list)
		pages.append(list)
	for row in ROWS:
		pages[row["page"]].add_child(_row(row))
		if row["key"] == SECRET_ADDRESSES.back():
			address_note = Label.new()
			address_note.name = "AddressNote"
			address_note.text = NOT_HTTPS
			address_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			address_note.custom_minimum_size.x = LABEL_WIDTH + CONTROL_WIDTH
			address_note.visible = false
			pages[row["page"]].add_child(address_note)

	rebind_button = _page_button("rebind", "Rebind…", 1)
	rebind_button.pressed.connect(open_rebind)
	reset_button = _page_button("reset", "Reset to defaults", 1)
	reset_button.pressed.connect(reset_controls)

	var look_row := HBoxContainer.new()
	look_row.name = "look"
	look_row.add_theme_constant_override("separation", 16)
	var look_label := Label.new()
	look_label.text = "Look"
	look_label.custom_minimum_size.x = LABEL_WIDTH
	look_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	look_row.add_child(look_label)
	look_button = Button.new()
	look_button.name = "Value"
	look_button.text = "Change…"
	look_button.custom_minimum_size.x = CONTROL_WIDTH
	look_button.pressed.connect(open_look.emit)
	look_row.add_child(look_button)
	pages[2].add_child(look_row)
	_build_disconnect()

	hint = Label.new()
	hint.name = "Hint"
	hint.text = "Q · E or LB · RB: switch pages"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = "Back"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func(): _close.call_deferred())
	box.add_child(back_button)

	_build_confirm()
	tabs.tab_changed.connect(_show_page)
	_show_page(maxi(PAGES.find(start_page), 0))


## The Station computer page's Disconnect row, its note and the console.
func _build_disconnect() -> void:
	var row := HBoxContainer.new()
	row.name = "disconnect"
	row.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.text = "AgentPod sign-in"
	label.custom_minimum_size.x = LABEL_WIDTH
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	disconnect_button = Button.new()
	disconnect_button.name = "Value"
	disconnect_button.text = "Disconnect"
	disconnect_button.custom_minimum_size.x = CONTROL_WIDTH
	disconnect_button.pressed.connect(func() -> void:
		if not disconnect_button.disabled:
			disconnect_requested.emit())
	row.add_child(disconnect_button)
	pages[5].add_child(row)
	disconnect_note = Label.new()
	disconnect_note.name = "DisconnectNote"
	disconnect_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	disconnect_note.custom_minimum_size.x = LABEL_WIDTH + CONTROL_WIDTH
	pages[5].add_child(disconnect_note)
	console_hint_button = _page_button("console_hint", "Open the AgentPod console", 5)
	console_hint_button.pressed.connect(console_requested.emit)
	_show_account()


## What the Disconnect row shows: offered while a device is `held`,
## disabled while one is `running` (and once there is nothing to
## disconnect), with the last `message`, and the console where a device
## was not revoked (`console_hint`). Hidden when there is nothing to say.
func show_station_account(held: bool, running: bool, message: String, console_hint: bool) -> void:
	_account = {"held": held, "running": running, "message": message, "console_hint": console_hint}
	if disconnect_button != null:
		_show_account()


func _show_account() -> void:
	var shown: bool = _account["held"] or _account["running"] or _account["message"] != ""
	disconnect_button.get_parent().visible = shown
	disconnect_button.visible = shown
	disconnect_button.disabled = _account["running"] or not _account["held"]
	disconnect_note.text = _account["message"]
	disconnect_note.visible = _account["message"] != ""
	console_hint_button.visible = _account["console_hint"]
	if back_button != null:
		_link_focus()


## One row: its label and its value control, named after the key.
func _row(row: Dictionary) -> HBoxContainer:
	var key: String = row["key"]
	var box := HBoxContainer.new()
	box.name = key
	box.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.name = "Label"
	label.text = row["label"]
	label.custom_minimum_size.x = LABEL_WIDTH
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(label)
	var control: Control
	var kind := _kind(row)
	if kind == "choice":
		var o := OptionButton.new()
		for choice in row["choices"]:
			o.add_item(choice[0])
		o.item_selected.connect(func(i): set_row(key, row["choices"][i][1]))
		control = o
	elif kind == "toggle":
		var c := CheckButton.new()
		c.toggled.connect(func(on): set_row(key, on))
		control = c
	elif kind == "text":
		# Saved when entered, or when the focus moves on.
		var field := LineEdit.new()
		field.text_submitted.connect(func(text): set_row(key, text))
		field.focus_exited.connect(func(): set_row(key, field.text))
		control = field
	else:
		var slider := HSlider.new()
		slider.min_value = SENSITIVITY_MIN
		slider.max_value = SENSITIVITY_MAX
		slider.step = SENSITIVITY_STEP
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(func(v): set_row(key, v))
		control = slider
	control.name = "Value"
	control.custom_minimum_size.x = CONTROL_WIDTH
	control.focus_mode = Control.FOCUS_ALL
	control.gui_input.connect(_on_row_input.bind(key, control))
	box.add_child(control)
	_controls[key] = control
	if kind == "slider":
		var amount := Label.new()
		amount.name = "Amount"
		amount.custom_minimum_size.x = 64
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		box.add_child(amount)
		_amounts[key] = amount
	_show_value(key)
	return box


## A button at the foot of a page.
func _page_button(button_name: String, text: String, page: int) -> Button:
	var b := Button.new()
	b.name = button_name
	b.text = text
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size.x = CONTROL_WIDTH
	pages[page].add_child(b)
	return b


## "Keep this display setting?", with Keep and Revert, over the pages.
func _build_confirm() -> void:
	confirm = Control.new()
	confirm.name = "Confirm"
	confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm.visible = false
	add_child(confirm)
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm.add_child(scrim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm.add_child(centre)
	var panel := PanelContainer.new()
	centre.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	confirm_label = Label.new()
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(confirm_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	keep_button = Button.new()
	keep_button.name = "Keep"
	keep_button.text = "Keep"
	keep_button.pressed.connect(answer.bind(true))
	buttons.add_child(keep_button)
	revert_button = Button.new()
	revert_button.name = "Revert"
	revert_button.text = "Revert"
	revert_button.pressed.connect(answer.bind(false))
	buttons.add_child(revert_button)
	# The d-pad stays on the question until it is answered.
	for pair in [[keep_button, revert_button], [revert_button, keep_button]]:
		var b: Button = pair[0]
		var other: Button = pair[1]
		b.focus_neighbor_left = b.get_path_to(other)
		b.focus_neighbor_right = b.get_path_to(other)
		b.focus_neighbor_top = b.get_path_to(b)
		b.focus_neighbor_bottom = b.get_path_to(b)
		b.focus_next = b.get_path_to(other)
		b.focus_previous = b.get_path_to(other)


static func _kind(row: Dictionary) -> String:
	return "choice" if row.has("choices") else str(row["kind"])


static func _row_def(key: String) -> Dictionary:
	for row in ROWS:
		if row["key"] == key:
			return row
	return {}


## The page names, in order.
func page_names() -> Array:
	var names := []
	for i in tabs.tab_count:
		names.append(tabs.get_tab_title(i))
	return names


## The value control of `key`'s row.
func value_control(key: String) -> Control:
	return _controls.get(key)


## Sets `key` to `value` as a change in its row would: saved (and so
## applied by whoever listens to the settings) and shown. A display change
## asks to be kept.
func set_row(key: String, value) -> void:
	var row := _row_def(key)
	if row.is_empty() or (key == "vsync" and _vsync_forced_off()):
		return
	if key in SECRET_ADDRESSES:
		# Refused, the address typed stays in its field to be corrected, and
		# the one saved stands.
		var address := str(value).strip_edges()
		var refused := address != "" and not StationHttp.is_secure_or_loopback(address)
		if address_note != null:
			address_note.visible = refused
		if refused:
			return
	var old = settings.get_value(row["section"], key)
	if _same(old, value):
		_show_value(key)
		return
	if key == "display" and not confirming:
		_ask_to_keep(old)
	settings.set_value(row["section"], key, value)
	_show_value(key)
	if key == "frame_cap":
		_show_value("vsync")


## Moves `key`'s value one step: the next or previous choice (stopping at
## either end), a switch flipped, or a sensitivity a quarter up or down.
func step_row(key: String, direction: int) -> void:
	var row := _row_def(key)
	if row.is_empty():
		return
	var value = settings.get_value(row["section"], key)
	match _kind(row):
		"choice":
			var choices: Array = row["choices"]
			var i := _choice_index(choices, value)
			var next := clampi(i + direction, 0, choices.size() - 1) if i >= 0 else 0
			set_row(key, choices[next][1])
		"toggle":
			set_row(key, not bool(value))
		"text":
			pass
		"slider":
			set_row(key, clampf(snappedf(float(value) + direction * SENSITIVITY_STEP, SENSITIVITY_STEP),
				SENSITIVITY_MIN, SENSITIVITY_MAX))


## Left and right on a focused row change its value, where the d-pad
## would otherwise move the focus.
func _on_row_input(event: InputEvent, key: String, control: Control) -> void:
	# In a text field, left and right move through the text.
	if _kind(_row_def(key)) == "text":
		return
	# A held direction repeats along a slider or a list, never on a switch.
	var repeat := _kind(_row_def(key)) != "toggle"
	for pair in [["ui_left", -1], ["ui_right", 1]]:
		if event.is_action_pressed(pair[0], repeat):
			step_row(key, pair[1])
			control.accept_event()
			return


## Shows `key`'s stored value in its row, without firing the row's change.
func _show_value(key: String) -> void:
	var row := _row_def(key)
	var control: Control = _controls.get(key)
	if control == null:
		return
	var value = settings.get_value(row["section"], key)
	match _kind(row):
		"choice":
			var index := _choice_index(row["choices"], value)
			(control as OptionButton).select(index)
			# Join as is empty until the first launch's choice is made.
			if index < 0:
				(control as OptionButton).text = "Not chosen yet"
		"toggle":
			var check := control as CheckButton
			if key == "vsync":
				# An unlimited frame cap turns vsync off whatever it is set
				# to (see Settings.frame_policy): the row shows it off, fixed,
				# and says why; the setting underneath is kept for later.
				var forced := _vsync_forced_off()
				check.disabled = forced
				check.text = VSYNC_FORCED_TEXT if forced else ""
				if forced:
					value = false
			check.set_pressed_no_signal(bool(value))
		"slider":
			(control as HSlider).set_value_no_signal(float(value))
			_amounts[key].text = amount_text(float(value))
		"text":
			var field := control as LineEdit
			if field.text != str(value):
				field.text = str(value)


## Whether the frame cap is unlimited, which turns vsync off.
func _vsync_forced_off() -> bool:
	return settings.get_value("graphics", "frame_cap") == -1


## A sensitivity as the row shows it: "1×", "1.25×", "0.5×".
static func amount_text(value: float) -> String:
	var text := "%.2f" % value
	text = text.rstrip("0").trim_suffix(".")
	return text + "×"


static func _choice_index(choices: Array, value) -> int:
	for i in choices.size():
		if _same(choices[i][1], value):
			return i
	return -1


## Equal, with numbers compared as numbers (a saved 1 and 1.0 are the
## same text size).
static func _same(a, b) -> bool:
	var numbers := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in numbers and typeof(b) in numbers:
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b


# ---- Pages ----

## The page names at the skin's size, unless in the narrow layout they
## would be wider than the window leaves them; then at NARROW_TAB_SIZE.
## Where even that is too wide (six names in pixel art's face, at 800 px),
## the bar scrolls instead, each name still whole and the page shown kept
## in view, rather than the panel running off the window.
func _fit_tabs() -> void:
	tabs.remove_theme_font_size_override("font_size")
	tabs.clip_tabs = false
	if size.x <= 0.0:
		return
	var room := size.x - TAB_ROOM
	if narrow and tabs.get_combined_minimum_size().x > room:
		tabs.add_theme_font_size_override("font_size", ui.font_size(NARROW_TAB_SIZE))
	if tabs.get_combined_minimum_size().x > room:
		tabs.clip_tabs = true
		tabs.ensure_tab_visible(tabs.current_tab)


## The panel shows only while the settings are the top screen.
func _on_stack_changed(top: Screen) -> void:
	panel.visible = top == self


## Shows page `index`, links its rows for the d-pad and focuses its first.
func _show_page(index: int) -> void:
	for i in pages.size():
		pages[i].visible = i == index
	if tabs.current_tab != index:
		tabs.current_tab = index
	tabs.ensure_tab_visible(index)
	_link_focus()
	var first := _focusables()
	if not confirming and not first.is_empty() and first[0].is_visible_in_tree():
		first[0].grab_focus()


## Steps to the next (1) or previous (-1) page, wrapping round.
func page_step(direction: int) -> void:
	_show_page(posmod(tabs.current_tab + direction, pages.size()))


## Q and E, or LB and RB, switch pages while this screen is on top and
## nothing is being asked.
func _unhandled_input(event: InputEvent) -> void:
	if confirming or (stack != null and stack.top() != self) or not event.is_pressed() or event.is_echo():
		return
	var direction := 0
	if event is InputEventKey:
		match event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode:
			KEY_Q:
				direction = -1
			KEY_E:
				direction = 1
	elif event is InputEventJoypadButton:
		match event.button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				direction = -1
			JOY_BUTTON_RIGHT_SHOULDER:
				direction = 1
	if direction != 0:
		page_step(direction)
		get_viewport().set_input_as_handled()


## The page's focusable controls in order, and Back.
func _focusables() -> Array[Control]:
	var list: Array[Control] = []
	for child in pages[tabs.current_tab].get_children():
		if not child.visible:
			continue
		if child is Button:
			list.append(child)
		else:
			var value = child.get_node_or_null("Value")
			if value != null:
				list.append(value)
	list.append(back_button)
	return list


## Up and down run through the page's rows and Back, wrapping at either
## end; left and right stay on a row (they change its value).
func _link_focus() -> void:
	var list := _focusables()
	for i in list.size():
		var c := list[i]
		c.focus_neighbor_top = c.get_path_to(list[i - 1])
		c.focus_neighbor_bottom = c.get_path_to(list[(i + 1) % list.size()])
		c.focus_neighbor_left = c.get_path_to(c)
		c.focus_neighbor_right = c.get_path_to(c)
		c.focus_previous = c.focus_neighbor_top
		c.focus_next = c.focus_neighbor_bottom


# ---- Display confirmation ----

func _ask_to_keep(old) -> void:
	confirming = true
	_revert_to = old
	_confirm_left = CONFIRM_S
	_show_countdown()
	confirm.visible = true
	if keep_button.is_visible_in_tree():
		keep_button.grab_focus()


## Keeps the display change, or reverts it.
func answer(keep: bool) -> void:
	if not confirming:
		return
	confirming = false
	confirm.visible = false
	if not keep:
		settings.set_value("graphics", "display", _revert_to)
		_show_value("display")
	_revert_to = null
	var display: Control = _controls["display"]
	if display.is_visible_in_tree():
		display.grab_focus()


## Counts the question down; unanswered after CONFIRM_S seconds, the
## display change reverts.
func tick(delta: float) -> void:
	if not confirming:
		return
	_confirm_left -= delta
	if _confirm_left <= 0.0:
		answer(false)
	else:
		_show_countdown()


func _show_countdown() -> void:
	confirm_label.text = "Keep this display setting?\nReverting in %d s." % ceili(_confirm_left)


func _process(delta: float) -> void:
	tick(delta)


## Back reverts a display change being asked about before it closes the
## screen.
func on_back() -> bool:
	if confirming:
		answer(false)
		return true
	return false


# ---- Controls page ----

## Pushes the rebinding screen.
func open_rebind() -> void:
	if stack == null:
		return
	var r := RebindScreen.new()
	r.settings = settings
	stack.push(r)


## Puts the Controls page back as it was at first launch: the project's
## input map, both sensitivities and invert look Y.
func reset_controls() -> void:
	RebindScreen.reset(settings)
	for row in ROWS:
		if row["section"] == "controls":
			set_row(row["key"], Settings.DEFAULTS["controls"][row["key"]])


## Closes the screen from its own Back button, once the press is over.
func _close() -> void:
	if stack != null and stack.top() == self:
		stack.pop()


func restyle() -> void:
	title.text = ui.case("Settings")
	title.add_theme_font_override("font", ui.display_font)
	title.add_theme_font_size_override("font_size", ui.display_size(28))
	_fit_tabs()
	hint.add_theme_color_override("font_color", ui.colour("ink_muted"))
	confirm.get_node("Scrim").color = ui.colour("scrim")
	var height := float(ui.spec.get("button", {}).get("height", 48))
	for b in [back_button, keep_button, revert_button]:
		b.text = ui.case(str(b.name))
		b.custom_minimum_size = Vector2(160, height)
	rebind_button.text = ui.case("Rebind") + "…"
	reset_button.text = ui.case("Reset to defaults")
	look_button.text = ui.case("Change") + "…"
	for b in [rebind_button, reset_button, look_button]:
		b.custom_minimum_size.y = height
	for key in _controls:
		_controls[key].custom_minimum_size.y = height
