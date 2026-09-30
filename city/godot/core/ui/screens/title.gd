## The title screen. The game opens on it: the city runs behind, seen by a
## slowly drifting camera, and a card at the left carries the name and the
## menu. Explore goes into play (asking how to enter on a first launch);
## Map & read opens the map over the title, without joining; Settings;
## About (the version, the licence, the source and the notices); and Quit,
## which a web build has no use for. Back does nothing here: there is nowhere to go
## back to. The fixture notice stays at the bottom left, as in play.
extends Screen
class_name TitleScreen

## The buttons, top to bottom. Each is named with its text before the
## skin's case is applied.
const ACTIONS := ["Explore", "Map & read", "Settings", "About", "Quit"]
## The name on the card.
const NAME := "AGENTNAGAR"
## How far the card sits from the left edge of the screen.
const INSET := 64
## The buttons' width.
const BUTTON_WIDTH := 300.0
## The name's size, and its size in the narrow layout, where a wide face
## (Press Start 2P) at the full size would run off an 800 px window.
const NAME_SIZE := 72
const NARROW_NAME_SIZE := 48
## The fixture notice's size. A pixel face snaps it to its grid, and a
## 10 px pixel face cannot be read at half size, so a pixel face takes the
## next whole step up instead.
const NOTICE_SIZE := 14

signal explore
signal map_and_read
signal open_settings
signal open_about
signal quit_game

## Whether the map can be opened; "Map & read" is hidden when it cannot.
var map_available := true

## The name, large, in the style's display font.
var name_label: Label
var panel: PanelContainer
var buttons: Array[Button] = []
## "Fixture data — not real agent state", small, at the bottom left.
var fixture: Label
var _fixture_chip: PanelContainer


func build() -> void:
	panel = PanelContainer.new()
	panel.name = "Card"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, INSET)
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	name_label = Label.new()
	name_label.name = "Name"
	name_label.text = NAME
	box.add_child(name_label)

	var gap := Control.new()
	gap.custom_minimum_size.y = 12
	box.add_child(gap)

	var signals := [explore, map_and_read, open_settings, open_about, quit_game]
	for i in ACTIONS.size():
		var b := Button.new()
		b.name = ACTIONS[i]
		b.text = ACTIONS[i]
		b.custom_minimum_size.x = BUTTON_WIDTH
		b.pressed.connect(signals[i].emit)
		box.add_child(b)
		buttons.append(b)

	# The card steps aside while a screen opened from it (the Join screen,
	# the settings) is over it; the city and the fixture line stay.
	if stack != null:
		stack.changed.connect(_on_stack_changed)

	_fixture_chip = PanelContainer.new()
	_fixture_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fixture_chip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	_fixture_chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_fixture_chip)
	fixture = Label.new()
	fixture.name = "Fixture"
	fixture.text = PlayHud.BANNER
	fixture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fixture_chip.add_child(fixture)
	_show_available()


func _on_stack_changed(top: Screen) -> void:
	panel.visible = top == self


## Back does nothing on the title.
func on_back() -> bool:
	return true


## Hides Map & read when the map cannot open, and Quit in a web build,
## where a page cannot close itself.
func _show_available() -> void:
	action_button("Map & read").visible = map_available
	action_button("Quit").visible = not OS.has_feature("web")
	_link_focus()


## The button for one of `ACTIONS`, by its name.
func action_button(action: String) -> Button:
	return buttons[ACTIONS.find(action)]


## Up and down move between the shown buttons, wrapping at either end, so
## the d-pad never lands on a hidden one or leaves the card.
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
	name_label.add_theme_font_override("font", ui.display_font)
	name_label.add_theme_font_size_override("font_size", ui.display_size(NARROW_NAME_SIZE if narrow else NAME_SIZE))
	name_label.add_theme_color_override("font_color", ui.colour("ink"))
	var height := float(ui.spec.get("button", {}).get("height", 48))
	for b in buttons:
		b.text = ui.case(b.name)
		b.custom_minimum_size.y = height
	_fixture_chip.add_theme_stylebox_override("panel", _chip_style())
	fixture.add_theme_font_size_override("font_size", notice_size(ui))
	fixture.add_theme_color_override("font_color", ui.colour("ink_muted"))


## NOTICE_SIZE in `t`'s body face: a pixel face that snaps it below
## NOTICE_SIZE takes one more step of its grid.
static func notice_size(t: UiTheme) -> int:
	var shown := t.font_size(NOTICE_SIZE)
	if t.spec.get("pixel_font", false) and shown < NOTICE_SIZE:
		shown += int(t.spec.get("pixel_base_body", t.spec.get("pixel_base", 10)))
	return shown


## The HUD's chip: the skin's panel colour at 85%, so it reads over any
## scene.
func _chip_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var c := ui.colour("panel")
	sb.bg_color = Color(c.r, c.g, c.b, 0.85)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb
