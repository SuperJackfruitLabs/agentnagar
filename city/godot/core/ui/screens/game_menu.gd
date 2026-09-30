## The game menu, opened over play by Esc or Start. The world keeps
## running behind it (in a shared city one visitor cannot stop time), dimmed
## by the skin's scrim colour. A header says who you are; below it are the
## actions, in a centred panel, which steps aside while a screen opened
## from it is on top (a see-through skin would show it through that
## screen). Back closes it, as Resume does.
extends Screen
class_name GameMenu

## The panel's width, in pixels.
const WIDTH := 420.0
## The buttons, top to bottom. Each is named with its text before the
## skin's case is applied.
const ACTIONS := ["Resume", "Map", "Visual style", "Settings", "About", "Quit to title", "Quit"]

signal resume
signal open_map
signal open_style
signal open_settings
## About: the version, the licence, the source and the notices.
signal open_about
signal quit_to_title
signal quit_game

## Whether the map can be opened; its button is hidden when it cannot.
var map_available := true
## Whether the settings screen exists yet; its button is hidden until it
## does.
var settings_available := false
## Whether the title screen exists yet; "Quit to title" is hidden until it
## does.
var title_available := false

## Who you are: "Visitor · walking", or "Watching" without a player. Set by
## main after the menu is pushed.
var header: Label
## The centred panel that holds the header and the buttons.
var panel: PanelContainer
var scrim: ColorRect
var buttons: Array[Button] = []


func build() -> void:
	scrim = ColorRect.new()
	scrim.name = "Scrim"
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	panel = PanelContainer.new()
	panel.custom_minimum_size.x = WIDTH
	centre.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	header = Label.new()
	header.name = "Header"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(header)

	var signals := [resume, open_map, open_style, open_settings, open_about, quit_to_title, quit_game]
	for i in ACTIONS.size():
		var b := Button.new()
		b.name = ACTIONS[i]
		b.text = ACTIONS[i]
		b.pressed.connect(signals[i].emit)
		box.add_child(b)
		buttons.append(b)
	if stack != null:
		stack.changed.connect(_on_stack_changed)
	_show_available()


## The panel shows only while the menu is the top screen.
func _on_stack_changed(top: Screen) -> void:
	panel.visible = top == self


## Hides the actions whose screens are not available, and Quit in a web
## build, where a page cannot close itself.
func _show_available() -> void:
	action_button("Map").visible = map_available
	action_button("Settings").visible = settings_available
	action_button("Quit to title").visible = title_available
	action_button("Quit").visible = not OS.has_feature("web")
	_link_focus()


## The button for one of `ACTIONS`, by its name.
func action_button(action: String) -> Button:
	return buttons[ACTIONS.find(action)]


## Up and down move between the shown buttons, wrapping at either end, so
## the d-pad never lands on a hidden one or leaves the panel.
func _link_focus() -> void:
	var shown := buttons.filter(func(b): return b.visible)
	for i in shown.size():
		var b: Button = shown[i]
		b.focus_neighbor_top = b.get_path_to(shown[i - 1])
		b.focus_neighbor_bottom = b.get_path_to(shown[(i + 1) % shown.size()])
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)
		b.focus_previous = b.focus_neighbor_top
		b.focus_next = b.focus_neighbor_bottom


func restyle() -> void:
	scrim.color = ui.colour("scrim")
	header.add_theme_font_override("font", ui.display_font)
	header.add_theme_font_size_override("font_size", ui.display_size(24))
	header.add_theme_color_override("font_color", ui.colour("ink_muted"))
	var height := float(ui.spec.get("button", {}).get("height", 48))
	for b in buttons:
		b.text = ui.case(b.name)
		b.custom_minimum_size.y = height
