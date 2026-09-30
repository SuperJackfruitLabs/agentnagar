## The quiet in-play HUD: a context prompt, a crosshair, the clock and
## weather, short fading notices, input hints, the always-visible fixture
## notice, and an error panel. Pushed as the stack's bottom screen while the
## player is walking around; hidden on the title, all but its error panel,
## which shows over every screen. Unlike a menu screen, it lets the world
## keep receiving input underneath it, and it never eats a click meant for
## the world: every part of it is `MOUSE_FILTER_IGNORE` except a notice's
## own button, which the mouse presses but the focus never reaches (see
## `focus_first`). Each chip is anchored to its corner or edge and grows
## away from it, inward, as its text grows.
extends Screen
class_name PlayHud

## How long an unattended notice stays up before it fades.
const NOTICE_S := 4.0

## How long the input hints stay up before they fade from disuse.
const HINTS_S := 10.0

const BANNER := "Fixture data — not real agent state"

## Labels input actions for the current device (keyboard/mouse or pad). Set
## by main before `build()` runs.
var glyphs: InputGlyphs

## Always shown, even over the error panel or with controls hidden.
var fixture: Label
var _fixture_chip: PanelContainer

## The context prompt: what the act button does now, and, when the target
## has other verbs, the "E: more" hint (Y on a controller) that cycles
## them.
var prompt: PanelContainer
var prompt_label: Label
var _prompt_icon: TextureRect
var _prompt_key: Label
## The "more" hint: the cycling button's glyph or key, then "more".
var prompt_more: HBoxContainer
var _more_icon: TextureRect
var _more_key: Label

## First person only.
var crosshair: Label

var clock: Label
var weather_icon: TextureRect
var _clock_chip: PanelContainer

## Bottom to top on screen; oldest first. At most two are kept.
var notices: Array[Control] = []
var _notices_box: VBoxContainer

var hints: Label
var _hints_chip: PanelContainer
## Seconds of play since the hints were last shown in full.
var _hints_elapsed := 0.0

## On a canvas layer of its own above the screen stack, so an error shows
## over every screen, the title included, while the rest of the HUD hides.
var error_label: Label
var _error_layer: CanvasLayer

## "Visitor · walking" or "Observer · …", for the game menu's header.
## Nothing here shows it directly.
var status_text := ""


func _init() -> void:
	super._init()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build() -> void:
	_build_fixture()
	_build_prompt()
	_build_crosshair()
	_build_clock()
	_build_notices()
	_build_hints()
	_build_error()
	if glyphs != null:
		glyphs.device_changed.connect(func(_d): show_hints())


func restyle() -> void:
	var chip := _chip_style()
	for c in [_fixture_chip, prompt, _clock_chip, _hints_chip]:
		if c != null:
			c.add_theme_stylebox_override("panel", chip)
	for l in [crosshair, prompt_label, _prompt_key, _more_key]:
		if l != null:
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			l.add_theme_constant_override("outline_size", 4)
	_update_hints_text()
	_place_hints()
	# Off the HUD's own canvas, the error panel takes the skin by hand.
	if error_label != null:
		error_label.theme = ui.theme


## The play HUD lets the world keep moving underneath it; it is not a
## blocking menu.
func wants_world_input() -> bool:
	return true


## The HUD never holds the focus: with a control of its own focused, the act
## button (Space or A) would press that control rather than reach the world,
## and a focus ring would show over play. A notice's button is for the mouse.
func focus_first() -> void:
	pass


func _process(delta: float) -> void:
	tick(delta)


## Advances every notice's fade timer and the hints' idle timer.
func tick(delta: float) -> void:
	for n in notices.duplicate():
		if n.get_meta("has_button", false):
			continue
		var elapsed: float = n.get_meta("elapsed", 0.0) + delta
		n.set_meta("elapsed", elapsed)
		if elapsed >= NOTICE_S:
			_close_notice(n)
	if hints != null and hints.modulate.a > 0.0:
		_hints_elapsed += delta
		if _hints_elapsed >= HINTS_S:
			hints.modulate.a = 0.0


# ---- Fixture notice ----

func _build_fixture() -> void:
	_fixture_chip = PanelContainer.new()
	_fixture_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fixture_chip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	_fixture_chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_fixture_chip)
	fixture = Label.new()
	fixture.text = BANNER
	fixture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fixture_chip.add_child(fixture)


# ---- Context prompt ----

func _build_prompt() -> void:
	prompt = PanelContainer.new()
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt.visible = false
	add_child(prompt)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.add_child(row)
	_prompt_icon = TextureRect.new()
	_prompt_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_prompt_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_prompt_icon.custom_minimum_size = Vector2(24, 24)
	_prompt_icon.visible = false
	row.add_child(_prompt_icon)
	_prompt_key = Label.new()
	_prompt_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_key.visible = false
	row.add_child(_prompt_key)
	prompt_label = Label.new()
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(prompt_label)
	prompt_more = HBoxContainer.new()
	prompt_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_more.visible = false
	row.add_child(prompt_more)
	var dot := Label.new()
	dot.text = " · "
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_more.add_child(dot)
	_more_icon = TextureRect.new()
	_more_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_more_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_more_icon.custom_minimum_size = Vector2(24, 24)
	prompt_more.add_child(_more_icon)
	_more_key = Label.new()
	_more_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_more.add_child(_more_key)
	var more := Label.new()
	more.text = "more"
	more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_more.add_child(more)


## An empty `text` hides the prompt. With no `action` it only says what is
## happening ("Waiting — tram in 12 s"), with no button to press. With
## `more`, the target has other verbs, and the hint says which button
## shows the next (`interact_alt`: E, or Y on a controller).
func set_prompt(action: String, text: String, more := false) -> void:
	prompt_label.text = text
	prompt.visible = text != ""
	prompt_more.visible = more and text != "" and action != ""
	if text == "":
		return
	_show_glyph(action, _prompt_icon, _prompt_key)
	if prompt_more.visible:
		_show_glyph("interact_alt", _more_icon, _more_key)


## Shows `action`'s controller glyph in `icon`, or its key's name in
## `key` on the keyboard; neither for no action.
func _show_glyph(action: String, icon_rect: TextureRect, key: Label) -> void:
	if action == "":
		icon_rect.visible = false
		key.visible = false
		return
	var icon := glyphs.icon(action) if glyphs != null else null
	if icon != null:
		icon_rect.texture = icon
		icon_rect.visible = true
		key.visible = false
	else:
		key.text = glyphs.label(action) if glyphs != null else ""
		key.visible = true
		icon_rect.visible = false


# ---- Crosshair ----

func _build_crosshair() -> void:
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.grow_horizontal = Control.GROW_DIRECTION_BOTH
	crosshair.grow_vertical = Control.GROW_DIRECTION_BOTH
	crosshair.visible = false
	add_child(crosshair)


func show_crosshair(on: bool) -> void:
	crosshair.visible = on


# ---- Clock and weather ----

func _build_clock() -> void:
	_clock_chip = PanelContainer.new()
	_clock_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_clock_chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_clock_chip)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_chip.add_child(row)
	weather_icon = TextureRect.new()
	weather_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weather_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weather_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weather_icon.custom_minimum_size = Vector2(20, 20)
	row.add_child(weather_icon)
	clock = Label.new()
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(clock)


## The day's clock, and a sun, moon or rain icon: rain when `rain > 0.05`,
## else a sun from 06:30 to 18:30, else a moon. Hidden when `minutes < 0`.
func set_clock(minutes: int, rain: float) -> void:
	if minutes < 0:
		_clock_chip.visible = false
		return
	_clock_chip.visible = true
	clock.text = "%02d:%02d" % [minutes / 60, minutes % 60]
	_set_weather(_weather_kind(minutes, rain))


func _weather_kind(minutes: int, rain: float) -> String:
	if rain > 0.05:
		return "rain"
	var day_start := 6 * 60 + 30
	var day_end := 18 * 60 + 30
	if minutes >= day_start and minutes <= day_end:
		return "sun"
	return "moon"


func _set_weather(kind: String) -> void:
	weather_icon.set_meta("kind", kind)
	var path := "res://core/ui/glyphs/%s.svg" % kind
	if ResourceLoader.exists(path):
		weather_icon.texture = load(path)


# ---- Notices ----

func _build_notices() -> void:
	_notices_box = VBoxContainer.new()
	_notices_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notices_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	_notices_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_notices_box)


## Adds a notice at the top centre. At most two show at once; a third drops
## the oldest. One with a `button` stays until it is pressed or
## `dismiss_notices()` is called; one without fades after `NOTICE_S`
## seconds.
func notify(text: String, button := "", action := Callable()) -> void:
	var n := _build_notice(text, button, action)
	notices.append(n)
	_notices_box.add_child(n)
	if notices.size() > 2:
		_close_notice(notices[0])


func _build_notice(text: String, button: String, action: Callable) -> PanelContainer:
	var n := PanelContainer.new()
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.set_meta("text", text)
	n.set_meta("has_button", button != "")
	n.set_meta("elapsed", 0.0)
	n.add_theme_stylebox_override("panel", _chip_style())
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.add_child(row)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(label)
	if button != "":
		var b := Button.new()
		b.name = "Action"
		b.text = button
		# Clicked, never focused: see focus_first.
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			if action.is_valid():
				action.call()
			_close_notice(n))
		row.add_child(b)
	return n


func _close_notice(n: Control) -> void:
	notices.erase(n)
	n.queue_free()


## Closes every notice now shown, whether it has a button or not.
func dismiss_notices() -> void:
	for n in notices.duplicate():
		_close_notice(n)


# ---- Hints ----

func _build_hints() -> void:
	_hints_chip = PanelContainer.new()
	_hints_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints_chip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_hints_chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hints_chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_hints_chip)
	hints = Label.new()
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints_chip.add_child(hints)
	_update_hints_text()
	_fixture_chip.resized.connect(_place_hints)


## The hints sit at the bottom right, level with the fixture notice; in the
## narrow layout they stack above it, since side by side the two can meet.
func _place_hints() -> void:
	if _hints_chip == null:
		return
	var bottom := -12.0
	if narrow:
		bottom -= _fixture_chip.size.y + 8.0
	_hints_chip.offset_bottom = bottom
	_hints_chip.offset_top = bottom


func _update_hints_text() -> void:
	if hints == null or glyphs == null:
		return
	hints.text = "%s Menu · %s Map" % [glyphs.label("menu"), glyphs.label("map")]


## Brings the hints back to full opacity and resets their idle timer; also
## called when `glyphs.device_changed` fires.
func show_hints() -> void:
	_hints_elapsed = 0.0
	if hints != null:
		hints.modulate.a = 1.0
	_update_hints_text()


# ---- Errors ----

func _build_error() -> void:
	_error_layer = CanvasLayer.new()
	_error_layer.name = "Errors"
	_error_layer.layer = ScreenStack.LAYER + 1
	add_child(_error_layer)
	error_label = Label.new()
	error_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	error_label.visible = false
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.custom_minimum_size = Vector2(700, 0)
	error_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 80)
	error_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_error_layer.add_child(error_label)


## Shows the error panel, and logs it too, so a packaged or headless run
## (where no one sees the panel) still reports why it did not boot.
func show_error(text: String) -> void:
	error_label.text = text
	error_label.visible = true
	printerr("city: " + text.replace("\n", " "))


# ---- Player status (for the game menu's header) ----

func set_player(state: String, observer: bool) -> void:
	status_text = "%s · %s" % ["Observer" if observer else "Visitor", state]


# ---- Capture mode ----

## Hides everything but `fixture` (for `--no-hud` captures).
func show_controls(on: bool) -> void:
	for n in [prompt, crosshair, _clock_chip, _notices_box, _hints_chip, error_label]:
		n.visible = on


# ---- Shared styling ----

## A small translucent chip in the skin's `panel` colour at 85% alpha, so it
## reads over any scene.
func _chip_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var c := ui.colour("panel") if ui != null else Color(0.97, 0.97, 0.98)
	sb.bg_color = Color(c.r, c.g, c.b, 0.85)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb
