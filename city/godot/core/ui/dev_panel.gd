## The developer panel: the old harness HUD's developer controls (speed,
## pause/step, the viewer menu, open all, roofs, camera presets, the style
## list), taken over behind F3 and shown only when developer tools are on.
## Its skin is fixed — a dark translucent panel in a monospace font — and
## does not follow `UiTheme`, so it never reads as part of the game in any
## style.
extends CanvasLayer
class_name DevPanel

signal style_requested(dir: String)
signal viewer_requested(viewer: String)
signal pause_toggled(paused: bool)
signal step_requested
signal speed_changed(speed: int)
signal open_all_toggled(on: bool)
## Whether roofs now stay on (true) or lift off (false).
signal roofs_toggled(on: bool)
signal camera_requested(preset: String)
## A short notice for the player, fired instead of calling `show_note`
## directly; main forwards this to `PlayHud.notify`.
signal note(text: String)

const SPEEDS := [1, 2, 4, 8]

## Whether developer tools are on, from the settings or `--dev`. `toggle()`
## shows or hides the panel, but only while this is true; the panel starts
## hidden either way.
var enabled := false

var style_dirs: Array = []
## The style shown now, as an index into style_dirs.
var style_index := 0
var viewer_ids: Array = []
var open_all := false
## Roofs stay on when buildings open (C).
var roofs_on := false
var paused := false
var speed := 1

## The status line: tick, time, style, viewer and speed.
var status: Label
var _viewer_menu: OptionButton
var _style_menu: OptionButton
var _open_all_button: CheckButton
var _roofs_button: CheckButton


func _init() -> void:
	layer = 30
	visible = false
	_build()


func _build() -> void:
	var font := SystemFont.new()
	font.font_names = ["monospace"]
	var skin := Theme.new()
	skin.default_font = font
	skin.default_font_size = 14

	var background := StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.75)
	background.content_margin_left = 8
	background.content_margin_right = 8
	background.content_margin_top = 8
	background.content_margin_bottom = 8

	var panel := PanelContainer.new()
	panel.theme = skin
	panel.position = Vector2(12, 12)
	panel.add_theme_stylebox_override("panel", background)
	add_child(panel)

	var box := VBoxContainer.new()
	panel.add_child(box)

	status = Label.new()
	status.add_theme_color_override("font_color", Color(1, 1, 1))
	box.add_child(status)

	var transport := HBoxContainer.new()
	box.add_child(transport)
	for spec in [["⏯", toggle_pause], ["⏭", request_step],
			["−", change_speed.bind(-1)], ["+", change_speed.bind(1)]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		transport.add_child(b)

	_viewer_menu = OptionButton.new()
	_viewer_menu.item_selected.connect(func(i): viewer_requested.emit(viewer_ids[i]))
	box.add_child(_viewer_menu)

	_open_all_button = CheckButton.new()
	_open_all_button.text = "Open all"
	_open_all_button.toggled.connect(func(on): _set_open_all(on))
	box.add_child(_open_all_button)

	_roofs_button = CheckButton.new()
	_roofs_button.text = "Roofs"
	_roofs_button.toggled.connect(func(on): _set_roofs(on))
	box.add_child(_roofs_button)

	var cameras := HBoxContainer.new()
	box.add_child(cameras)
	for spec in [["Top-down", "topdown"], ["Diagonal", "diagonal"], ["Street", "street"]]:
		var b := Button.new()
		b.text = spec[0]
		var preset: String = spec[1]
		b.pressed.connect(func(): request_camera(preset))
		cameras.add_child(b)

	_style_menu = OptionButton.new()
	_style_menu.item_selected.connect(func(i): _request_style(i))
	box.add_child(_style_menu)


## `styles` is [{dir, name}]; `viewers` the viewer IDs to offer.
func setup(styles: Array, viewers: Array) -> void:
	style_dirs = styles.map(func(s): return s["dir"])
	viewer_ids = viewers.duplicate()
	for v in viewer_ids:
		_viewer_menu.add_item(v)
	for s in styles:
		_style_menu.add_item(s["name"])


func set_status(tick: int, minutes: int, viewer: String, style: String) -> void:
	var clock := "" if minutes < 0 else " · %02d:%02d" % [minutes / 60, minutes % 60]
	status.text = "tick %d%s · %s · %s · %dx%s" % [tick, clock, style, viewer, speed, " · paused" if paused else ""]


## Shows or hides the panel; does nothing while `enabled` is false.
func toggle() -> void:
	if enabled:
		visible = not visible


## Whether the panel's keyboard shortcuts (number keys, T/G/Y, P, ., +/-)
## should act: only while developer tools are on.
func shortcuts_active() -> bool:
	return enabled


# ---- Intents (from the input router) ----

func toggle_open_all() -> void:
	_set_open_all(not open_all)


func _set_open_all(on: bool) -> void:
	open_all = on
	if _open_all_button != null and _open_all_button.button_pressed != on:
		_open_all_button.set_pressed_no_signal(on)
	open_all_toggled.emit(open_all)


func toggle_roofs() -> void:
	_set_roofs(not roofs_on)


func _set_roofs(on: bool) -> void:
	roofs_on = on
	if _roofs_button != null and _roofs_button.button_pressed != on:
		_roofs_button.set_pressed_no_signal(on)
	note.emit("Roofs stay on: buildings open by their near walls (C to lift them)." if roofs_on
		else "Roofs lift off the building you are in (C to keep them on).")
	roofs_toggled.emit(roofs_on)


func request_camera(preset: String) -> void:
	camera_requested.emit(preset)


func toggle_pause() -> void:
	paused = not paused
	pause_toggled.emit(paused)


func request_step() -> void:
	step_requested.emit()


func change_speed(direction: int) -> void:
	var k := clampi(SPEEDS.find(speed) + direction, 0, SPEEDS.size() - 1)
	if SPEEDS[k] != speed:
		speed = SPEEDS[k]
		speed_changed.emit(speed)


## The style with 1-based `index`, if there is one.
func pick_style(index: int) -> void:
	if index >= 1 and index <= style_dirs.size():
		_request_style(index - 1)


## The next (1) or previous (-1) style, wrapping round.
func step_style(direction: int) -> void:
	if not style_dirs.is_empty():
		_request_style(posmod(style_index + direction, style_dirs.size()))


## Notes the style now shown, so stepping starts from it.
func show_style(dir: String) -> void:
	style_index = maxi(0, style_dirs.find(dir))
	if _style_menu != null and style_index < _style_menu.item_count:
		_style_menu.select(style_index)


func _request_style(k: int) -> void:
	style_index = k
	style_requested.emit(style_dirs[k])


## Notes the viewer now shown, so cycling starts from it.
func show_viewer(viewer: String) -> void:
	if _viewer_menu != null and viewer in viewer_ids:
		_viewer_menu.select(viewer_ids.find(viewer))


## The next (1) or previous (-1) viewer, wrapping round.
func step_viewer(direction: int) -> void:
	if viewer_ids.is_empty():
		return
	var k := posmod(_viewer_menu.selected + direction, viewer_ids.size())
	_viewer_menu.select(k)
	viewer_requested.emit(viewer_ids[k])
