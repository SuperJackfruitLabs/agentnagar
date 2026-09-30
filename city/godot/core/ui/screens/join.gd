## The Join screen, opened by Explore on a first launch. It asks how to
## enter (Visitor, a registered player who takes a place like anyone else;
## Observer, an anonymous one who takes no seat; or Just watch, with no
## player at all), then, unless watching, for a look: one of eight outfits
## and four hair styles, shown on a figure turning in a small view of its
## own. Start says how and in what look with `done`. Opened from Settings
## with `look_only`, it asks for the look alone and keeps how you enter.
extends Screen
class_name JoinScreen

## The ways in, in order: the button's text, what `done` carries, and a
## line saying what it means.
const WAYS := [
	["Visitor", "registered", "Take a place in the city, like anyone else."],
	["Observer", "observer", "Walk about unseen. You take no seat."],
	["Just watch", "none", "No player: the camera is yours."],
]
const OUTFITS := Player.OUTFITS
const HAIRS := Player.HAIRS
## How fast the figure turns.
const TURN_RAD_S := 0.5
## The preview's size, in pixels.
const PREVIEW_SIZE := Vector2i(220, 280)
## A 2D figure's frames are small: the preview shows them this many times
## over, a whole number, so pixels stay square.
const SPRITE_SCALE := 4
## A 2D figure's sheets have a row for each of eight facings, clockwise
## from north; the third faces the viewer.
const FACINGS := 8
const FACING_VIEWER := 3
const VALUE_WIDTH := 160.0

signal done(as_: String, look: String)

## Only the look, as from Settings: the question is skipped and `done`
## carries `join_as` as it is.
var look_only := false
## How you enter: "registered", "observer" or "none".
var join_as := "registered"
var outfit := 0
var hair := 0
## The style shown now, which makes the figure. Without one, or when it
## makes none, the look step shows the numbers only. A style switched while
## the screen is open (from the developer panel) frees it: `set_pack` gives
## the screen the new one.
var pack: StylePack
## 1 while asking how to enter, 2 while choosing the look.
var step := 1

var title: Label
var choice_box: VBoxContainer
## The three ways in, as buttons, named as `WAYS` gives them.
var choices: Array[Button] = []
var look_box: HBoxContainer
## The turning figure's view, or null when there is no figure to show.
var preview: SubViewportContainer
## The figure in the preview, or null.
var figure: Node
var outfit_row: HBoxContainer
var hair_row: HBoxContainer
var start_button: Button
var _descriptions: Array[Label] = []
var _viewport: SubViewport
## How far the figure has turned, in radians.
var _turned := 0.0


## Takes a look as the core does, "OUTFIT,HAIR"; anything unreadable is
## the first.
func set_look(text: String) -> void:
	var parts := text.split(",")
	outfit = posmod(int(parts[0]), OUTFITS) if parts.size() > 0 and parts[0].is_valid_int() else 0
	hair = posmod(int(parts[1]), HAIRS) if parts.size() > 1 and parts[1].is_valid_int() else 0


## The look as the core takes it, "OUTFIT,HAIR".
func look_text() -> String:
	return "%d,%d" % [outfit, hair]


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
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	title = Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	choice_box = VBoxContainer.new()
	choice_box.name = "Choices"
	choice_box.add_theme_constant_override("separation", 12)
	box.add_child(choice_box)
	for way in WAYS:
		var b := Button.new()
		b.name = way[0]
		b.text = way[0]
		b.custom_minimum_size.x = 360
		b.pressed.connect(choose.bind(way[1]))
		choice_box.add_child(b)
		choices.append(b)
		var line := Label.new()
		line.text = way[2]
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		choice_box.add_child(line)
		_descriptions.append(line)
	_link(choices)

	look_box = HBoxContainer.new()
	look_box.name = "Look"
	look_box.add_theme_constant_override("separation", 24)
	box.add_child(look_box)
	_build_preview()
	var rows := VBoxContainer.new()
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 16)
	look_box.add_child(rows)
	outfit_row = _row("outfit", "Outfit", step_outfit)
	rows.add_child(outfit_row)
	hair_row = _row("hair", "Hair", step_hair)
	rows.add_child(hair_row)
	start_button = Button.new()
	start_button.name = "Start"
	start_button.text = "Start"
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.custom_minimum_size.x = VALUE_WIDTH
	start_button.pressed.connect(start)
	rows.add_child(start_button)
	_link([outfit_row.get_node("Value"), hair_row.get_node("Value"), start_button])
	_show_look()
	_show_step(2 if look_only else 1)


## One look row: its name, and its value between left and right arrows.
## The value is what the d-pad focuses; left and right on it step, and the
## arrows do the same for the mouse.
func _row(row_name: String, text: String, stepper: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.name = "Label"
	label.text = text
	label.custom_minimum_size.x = 96
	row.add_child(label)
	var less := Button.new()
	less.name = "Less"
	less.text = "‹"
	less.focus_mode = Control.FOCUS_NONE
	less.pressed.connect(stepper.bind(-1))
	row.add_child(less)
	var value := Button.new()
	value.name = "Value"
	value.custom_minimum_size.x = VALUE_WIDTH
	value.gui_input.connect(_on_value_input.bind(stepper, value))
	row.add_child(value)
	var more := Button.new()
	more.name = "More"
	more.text = "›"
	more.focus_mode = Control.FOCUS_NONE
	more.pressed.connect(stepper.bind(1))
	row.add_child(more)
	return row


## Left and right on a look row's value step it, where the d-pad would
## otherwise move the focus.
func _on_value_input(event: InputEvent, stepper: Callable, value: Control) -> void:
	for pair in [["ui_left", -1], ["ui_right", 1]]:
		if event.is_action_pressed(pair[0], true):
			stepper.call(pair[1])
			value.accept_event()
			return


## Up and down run through `list`, wrapping at either end; left and right
## stay put (the look rows use them to step).
func _link(list: Array) -> void:
	for i in list.size():
		var c: Control = list[i]
		c.focus_neighbor_top = c.get_path_to(list[i - 1])
		c.focus_neighbor_bottom = c.get_path_to(list[(i + 1) % list.size()])
		c.focus_neighbor_left = c.get_path_to(c)
		c.focus_neighbor_right = c.get_path_to(c)
		c.focus_previous = c.focus_neighbor_top
		c.focus_next = c.focus_neighbor_bottom


## Shows the question (1) or the look (2), focusing its first control.
func _show_step(n: int) -> void:
	step = n
	choice_box.visible = n == 1
	look_box.visible = n == 2
	title.text = "How will you enter?" if n == 1 else "Your look"
	var first: Control = choices[0] if n == 1 else outfit_row.get_node("Value")
	if first.is_visible_in_tree():
		first.grab_focus()


## A way in chosen: Just watch is done at once; the others go on to the
## look.
func choose(as_: String) -> void:
	join_as = as_
	if as_ == "none":
		done.emit(join_as, look_text())
	else:
		_show_step(2)


func start() -> void:
	done.emit(join_as, look_text())


func step_outfit(direction: int) -> void:
	outfit = posmod(outfit + direction, OUTFITS)
	_show_look()


func step_hair(direction: int) -> void:
	hair = posmod(hair + direction, HAIRS)
	_show_look()


## The numbers in the rows, and the figure dressed to match.
func _show_look() -> void:
	outfit_row.get_node("Value").text = "%d of %d" % [outfit + 1, OUTFITS]
	hair_row.get_node("Value").text = "%d of %d" % [hair + 1, HAIRS]
	_dress()


## Back from the look returns to the question; from the question, or from
## the look alone, it closes the screen.
func on_back() -> bool:
	if step == 2 and not look_only:
		_show_step(1)
		return true
	return false


# ---- The preview ----

## Takes `p` as the style shown now, and rebuilds the preview in it (a 3D
## style's lit world, or a 2D one's sprite), in the look chosen so far.
func set_pack(p: StylePack) -> void:
	pack = p
	if not _built:
		return
	if preview != null:
		preview.free()
	preview = null
	_viewport = null
	figure = null
	_build_preview()
	if preview != null:
		look_box.move_child(preview, 0)


## A view of its own for the figure: lit, in a world of its own, for a 3D
## style; the sprite at a whole-number scale for a 2D one. None when the
## style makes no figure.
func _build_preview() -> void:
	var first: Node = pack.preview_figure(outfit, hair) if is_instance_valid(pack) else null
	if first == null:
		return
	preview = SubViewportContainer.new()
	preview.name = "Preview"
	preview.stretch = true
	preview.custom_minimum_size = PREVIEW_SIZE
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	look_box.add_child(preview)
	_viewport = SubViewport.new()
	_viewport.name = "View"
	_viewport.size = PREVIEW_SIZE
	_viewport.transparent_bg = true
	preview.add_child(_viewport)
	if first is Node3D:
		_viewport.own_world_3d = true
		var environment := Environment.new()
		environment.background_mode = Environment.BG_CLEAR_COLOR
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(1, 1, 1)
		environment.ambient_light_energy = 0.55
		var world := WorldEnvironment.new()
		world.environment = environment
		_viewport.add_child(world)
		var light := DirectionalLight3D.new()
		light.name = "Light"
		light.rotation_degrees = Vector3(-40, 30, 0)
		_viewport.add_child(light)
		var camera := Camera3D.new()
		camera.name = "Camera"
		camera.fov = 35.0
		var eye := Vector3(0, 1.0, 3.4)
		camera.transform = Transform3D(Basis.looking_at(Vector3(0, 0.9, 0) - eye), eye)
		camera.current = true
		_viewport.add_child(camera)
	else:
		_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_place_figure(first)


## Puts `node` in the preview in place of the figure there, facing as far
## round as the last one had turned.
func _place_figure(node: Node) -> void:
	if figure != null and is_instance_valid(figure):
		figure.free()
	figure = node
	if node is Node2D:
		node.position = Vector2(PREVIEW_SIZE.x / 2.0, PREVIEW_SIZE.y * 0.82)
		node.scale = Vector2.ONE * SPRITE_SCALE
	_viewport.add_child(node)
	_idle()
	turn(0.0)


## A 3D figure breathes: its idle clip plays on its own, which the crowd's
## do only when the pack advances them.
func _idle() -> void:
	var players := figure.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var player: AnimationPlayer = players[0]
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	var clip := str(pack.resolve("occupants", "Human").get("clips", {}).get("idle", "idle"))
	if player.has_animation(clip):
		player.play(clip)


## Dresses the figure in the look now chosen.
func _dress() -> void:
	if _viewport == null or not is_instance_valid(pack):
		return
	var node := pack.preview_figure(outfit, hair)
	if node != null:
		_place_figure(node)


## Turns the figure on by `delta` seconds: a 3D figure smoothly; a 2D one a
## facing at a time, from the sheet's eight.
func turn(delta: float) -> void:
	_turned = fmod(_turned + TURN_RAD_S * delta, TAU)
	if figure is Node3D:
		figure.rotation.y = _turned
	elif figure is Node2D:
		var body = figure.get_node_or_null("Body")
		if body is AnimatedSprite2D:
			var facing := (FACING_VIEWER + int(floor(_turned / (TAU / FACINGS)))) % FACINGS
			var clip := "idle_%d" % facing
			if body.sprite_frames.has_animation(clip) and body.animation != clip:
				body.play(clip)


func _process(delta: float) -> void:
	if step == 2 and figure != null:
		turn(delta)


func restyle() -> void:
	title.add_theme_font_override("font", ui.display_font)
	title.add_theme_font_size_override("font_size", ui.display_size(28))
	var height := float(ui.spec.get("button", {}).get("height", 48))
	for b in choices:
		b.text = ui.case(b.name)
		b.custom_minimum_size.y = height
	for line in _descriptions:
		line.add_theme_color_override("font_color", ui.colour("ink_muted"))
	start_button.text = ui.case("Start")
	start_button.custom_minimum_size.y = height
	for row in [outfit_row, hair_row]:
		row.get_node("Value").custom_minimum_size.y = height
		for part in ["Less", "More"]:
			row.get_node(part).custom_minimum_size = Vector2(height, height)
