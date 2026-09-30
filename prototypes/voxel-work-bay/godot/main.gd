extends Node3D

const Movement = preload("res://movement_controller.gd")
const Fixture = preload("res://fixture_model.gd")
const ASSET_NAMES: Array[String] = ["environment", "desk", "chair", "terminal", "kai", "lyra"]
const CREAM := Color("f4efdf")
const PAPER := Color("fffaf0")
const COBALT := Color("2549a7")
const INK := Color("22314b")
const EMERALD := Color("196c59")
const ORANGE := Color("d9863c")
const MUTED := Color("65717c")

var fixture = Fixture.new()
var movement = Movement.new()
var resident := "kai"
var _actors := {}
var _players := {}
var _clip_maps := {}
var _chair: Node3D
var _resident_selector: OptionButton
var _identity_label: Label
var _leave_button: Button
var _return_button: Button
var _capture_mode := false
var camera_mode := "overview"
var _overview: Camera3D
var _walker: CharacterBody3D
var _eye: Camera3D
var _kai: Node3D
var _preview_pad: MeshInstance3D
var _player: AnimationPlayer
var _actual_clips := {}
var _missing: Array[String] = []
var _current_clip := ""
var _status_label: Label
var _motion_button: CheckButton
var _text_button: CheckButton
var _text_label: Label
var _text_panel: PanelContainer
var _camera_button: Button
var _inspection_selector: OptionButton
var _controls_panel: PanelContainer
var _controls_toggle: Button
var _narrow_layout := false
var _state_buttons := {}

func _ready() -> void:
	_build_world()
	_load_assets()
	_build_ui()
	_refresh()
	get_viewport().size_changed.connect(func() -> void: _layout(get_viewport().get_visible_rect().size))
	call_deferred("_capture_if_requested")

func _build_world() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = CREAM
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("f4f0e8")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47, -35, 0)
	sun.light_color = Color("fff1d5")
	sun.light_energy = 0.82
	sun.shadow_enabled = false
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.8, 2.7, 2.4)
	fill.light_color = Color("dce8ff")
	fill.light_energy = 0.28
	fill.omni_range = 7.0
	add_child(fill)
	_overview = Camera3D.new()
	_overview.name = "OverviewCamera"
	_overview.position = Vector3(3.0, 2.25, 3.7)
	_overview.fov = 44.0
	_overview.near = 0.1
	_overview.far = 30.0
	_overview.current = true
	add_child(_overview)
	_overview.look_at(Vector3(1.50, 0.72, -0.55))
	_walker = CharacterBody3D.new()
	_walker.name = "FirstPersonWalker"
	_walker.position = Vector3(2.0, 0.0, 1.75)
	_walker.rotation.y = 0.7
	add_child(_walker)
	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.24
	shape.height = 1.55
	capsule.shape = shape
	capsule.position.y = 0.8
	_walker.add_child(capsule)
	_eye = Camera3D.new()
	_eye.position.y = 1.52
	_eye.fov = 70.0
	_eye.near = 0.1
	_eye.far = 30.0
	_walker.add_child(_eye)
	_add_box_collision("Floor", Vector3(0, -0.11, 0), Vector3(8, 0.22, 6))
	_add_box_collision("RearWall", Vector3(0, 1.4, -2.83), Vector3(8, 2.8, 0.18))
	_add_box_collision("LeftWall", Vector3(-3.83, 1.4, 0), Vector3(0.18, 2.8, 6))
	_add_box_collision("Desk", Vector3(0, 0.4, 0), Vector3(1.75, 0.8, 0.78))
	_add_box_collision("Chair", Vector3(0, 0.45, -0.68), Vector3(0.65, 0.9, 0.65))

func _add_box_collision(label: String, point: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label + "Collision"
	body.position = point
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _load_assets() -> void:
	var positions := {
		"environment": Vector3.ZERO,
		"desk": Vector3.ZERO,
		"chair": Vector3(0, 0, -0.65),
		"terminal": Vector3(0, 0.78, 0.12),
		"kai": Vector3(0, 0, -0.65),
		"lyra": Vector3(0, 0, -0.65),
	}
	for asset_name in ASSET_NAMES:
		var path := "res://assets/" + asset_name + ".glb"
		if not FileAccess.file_exists(path):
			_missing.append(asset_name + ".glb")
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			_missing.append(asset_name + ".glb (import failed)")
			continue
		var instance := packed.instantiate() as Node3D
		if instance == null:
			_missing.append(asset_name + ".glb (invalid scene)")
			continue
		instance.name = asset_name.capitalize()
		instance.position = positions[asset_name]
		add_child(instance)
		if asset_name == "chair":
			_chair = instance
		if asset_name in ["kai", "lyra"]:
			_kai = instance
			_actors[asset_name] = instance
			_actual_clips = {}
			var players := _kai.find_children("*", "AnimationPlayer", true, false)
			if not players.is_empty():
				_player = players[0] as AnimationPlayer
				for imported_name in _player.get_animation_list():
					var short_name := str(imported_name).get_slice("/", str(imported_name).get_slice_count("/") - 1)
					short_name = short_name.get_slice("|", short_name.get_slice_count("|") - 1).to_lower()
					if Fixture.CLIPS.has(short_name):
						_actual_clips[short_name] = imported_name
						_player.get_animation(imported_name).loop_mode = Animation.LOOP_NONE if short_name in ["sit_down", "stand_up"] else Animation.LOOP_LINEAR
				_players[asset_name] = _player
			_clip_maps[asset_name] = _actual_clips
	_select_actor("kai")
	if _kai != null:
		_preview_pad = MeshInstance3D.new()
		_preview_pad.name = "StandingPreviewMark"
		var pad_mesh := CylinderMesh.new()
		pad_mesh.top_radius = 0.57
		pad_mesh.bottom_radius = 0.57
		pad_mesh.height = 0.018
		pad_mesh.radial_segments = 32
		_preview_pad.mesh = pad_mesh
		var pad_material := StandardMaterial3D.new()
		pad_material.albedo_color = Color(0.145, 0.286, 0.655, 0.44)
		pad_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pad_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_preview_pad.material_override = pad_material
		_preview_pad.position = Vector3(1.45, 0.015, 1.15)
		_preview_pad.visible = false
		add_child(_preview_pad)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CanvasLayer"
	add_child(layer)
	var overlay := Control.new()
	overlay.name = "PilotInterface"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	var title_panel := PanelContainer.new()
	title_panel.name = "IdentityPanel"
	title_panel.add_theme_stylebox_override("panel", _panel_style(PAPER, COBALT, 2))
	overlay.add_child(title_panel)
	var title_margin := MarginContainer.new()
	title_margin.add_theme_constant_override("margin_left", 20)
	title_margin.add_theme_constant_override("margin_right", 20)
	title_margin.add_theme_constant_override("margin_top", 14)
	title_margin.add_theme_constant_override("margin_bottom", 14)
	title_panel.add_child(title_margin)
	var title_stack := VBoxContainer.new()
	title_stack.add_theme_constant_override("separation", 4)
	title_margin.add_child(title_stack)
	_identity_label = _label("Kai’s workshop bay", 23, COBALT)
	title_stack.add_child(_identity_label)
	title_stack.add_child(_label("Voxel pilot • local scene inspection", 14, MUTED))
	var sample := _label("SAMPLE DATA  ·  Fictional work state", 15, INK)
	sample.name = "SampleDataNotice"
	var notice := PanelContainer.new()
	notice.name = "SampleNotice"
	notice.add_theme_stylebox_override("panel", _panel_style(Color("ffdc9c"), ORANGE, 2))
	overlay.add_child(notice)
	var notice_margin := MarginContainer.new()
	notice_margin.add_theme_constant_override("margin_left", 14)
	notice_margin.add_theme_constant_override("margin_right", 14)
	notice_margin.add_theme_constant_override("margin_top", 8)
	notice_margin.add_theme_constant_override("margin_bottom", 8)
	notice.add_child(notice_margin)
	notice_margin.add_child(sample)
	_controls_toggle = _button("Hide controls", COBALT)
	_controls_toggle.name = "ControlsToggle"
	_controls_toggle.pressed.connect(_toggle_controls)
	_controls_toggle.hide()
	overlay.add_child(_controls_toggle)
	_controls_panel = PanelContainer.new()
	_controls_panel.name = "Controls"
	_controls_panel.add_theme_stylebox_override("panel", _panel_style(PAPER, COBALT, 2))
	overlay.add_child(_controls_panel)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls_panel.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	scroll.add_child(margin)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	stack.add_child(_label("Inspect the bay", 23, INK))
	stack.add_child(_label("Try a sample state or request a desk journey.", 15, MUTED, true))
	stack.add_child(_divider())
	stack.add_child(_label("Resident", 17, COBALT))
	_resident_selector = OptionButton.new()
	_resident_selector.name = "ResidentSelection"
	_resident_selector.add_item("Coder Kai")
	_resident_selector.add_item("Artistic Lyra")
	_resident_selector.item_selected.connect(func(index: int) -> void: set_resident("kai" if index == 0 else "lyra"))
	_resident_selector.add_theme_font_size_override("font_size", 15)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		_resident_selector.add_theme_color_override(state, INK)
	for state in ["normal", "hover", "pressed"]:
		_resident_selector.add_theme_stylebox_override(state, _panel_style(CREAM, COBALT, 1))
	_resident_selector.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, ORANGE, 2))
	stack.add_child(_resident_selector)
	_leave_button = _button("Leave desk", COBALT)
	_leave_button.pressed.connect(request_leave)
	stack.add_child(_leave_button)
	_return_button = _button("Return to desk", COBALT)
	_return_button.pressed.connect(request_return)
	stack.add_child(_return_button)
	stack.add_child(_label("Camera", 17, COBALT))
	_camera_button = _button("Enter first person", COBALT)
	_camera_button.pressed.connect(_toggle_camera)
	stack.add_child(_camera_button)
	stack.add_child(_label("WASD move · Esc release\nO overview · F first person · R reset", 13, MUTED, true))
	stack.add_child(_divider())
	stack.add_child(_label("Sample fixture state", 17, COBALT))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	stack.add_child(grid)
	for state in Fixture.STATES:
		var button := _button(state.capitalize(), EMERALD if state == "working" else COBALT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.pressed.connect(set_fixture_state.bind(state))
		grid.add_child(button)
		_state_buttons[state] = button
	_status_label = _label("", 15, INK, true)
	stack.add_child(_status_label)
	stack.add_child(_divider())
	stack.add_child(_label("Animation inspection", 17, COBALT))
	_inspection_selector = OptionButton.new()
	_inspection_selector.name = "AnimationInspection"
	_inspection_selector.add_item("Follow fixture state")
	for clip in Fixture.CLIPS:
		_inspection_selector.add_item("Preview " + clip.replace("_", " "))
	_inspection_selector.item_selected.connect(func(index: int) -> void: set_inspection("" if index == 0 else Fixture.CLIPS[index - 1]))
	_inspection_selector.add_theme_font_size_override("font_size", 15)
	_inspection_selector.add_theme_color_override("font_color", INK)
	_inspection_selector.add_theme_color_override("font_hover_color", INK)
	_inspection_selector.add_theme_color_override("font_focus_color", INK)
	_inspection_selector.add_theme_color_override("font_pressed_color", INK)
	_inspection_selector.add_theme_stylebox_override("normal", _panel_style(CREAM, COBALT, 1))
	_inspection_selector.add_theme_stylebox_override("hover", _panel_style(PAPER, COBALT, 1))
	_inspection_selector.add_theme_stylebox_override("pressed", _panel_style(PAPER, COBALT, 1))
	_inspection_selector.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, ORANGE, 2))
	stack.add_child(_inspection_selector)
	_motion_button = CheckButton.new()
	_motion_button.name = "ReducedMotionToggle"
	_motion_button.text = "Reduce motion"
	_motion_button.toggled.connect(set_reduced_motion)
	_motion_button.add_theme_font_size_override("font_size", 15)
	_motion_button.add_theme_color_override("font_color", INK)
	_motion_button.add_theme_color_override("font_hover_color", INK)
	_motion_button.add_theme_color_override("font_focus_color", INK)
	_motion_button.add_theme_color_override("font_pressed_color", INK)
	_motion_button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, ORANGE, 2))
	stack.add_child(_motion_button)
	_text_button = CheckButton.new()
	_text_button.name = "TextDescriptionToggle"
	_text_button.text = "Show text description"
	_text_button.toggled.connect(_show_text)
	_text_button.add_theme_font_size_override("font_size", 15)
	_text_button.add_theme_color_override("font_color", INK)
	_text_button.add_theme_color_override("font_hover_color", INK)
	_text_button.add_theme_color_override("font_focus_color", INK)
	_text_button.add_theme_color_override("font_pressed_color", INK)
	_text_button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, ORANGE, 2))
	stack.add_child(_text_button)
	var reset := _button("Reset scene", COBALT)
	reset.pressed.connect(reset_pilot)
	stack.add_child(reset)
	_text_panel = PanelContainer.new()
	_text_panel.name = "TextAlternative"
	_text_panel.add_theme_stylebox_override("panel", _panel_style(PAPER, EMERALD, 2))
	stack.add_child(_text_panel)
	var text_margin := MarginContainer.new()
	text_margin.add_theme_constant_override("margin_left", 16)
	text_margin.add_theme_constant_override("margin_right", 16)
	text_margin.add_theme_constant_override("margin_top", 12)
	text_margin.add_theme_constant_override("margin_bottom", 12)
	_text_panel.add_child(text_margin)
	_text_label = _label("", 15, INK, true)
	text_margin.add_child(_text_label)
	_text_panel.hide()
	_layout(get_viewport().get_visible_rect().size)

func _label(value: String, size: int, color: Color, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return label

func _button(value: String, color: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 39
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", PAPER)
	button.add_theme_color_override("font_focus_color", PAPER)
	button.add_theme_color_override("font_pressed_color", PAPER)
	button.add_theme_stylebox_override("normal", _panel_style(color, color, 0))
	button.add_theme_stylebox_override("hover", _panel_style(color.lightened(0.1), color, 0))
	button.add_theme_stylebox_override("pressed", _panel_style(color.darkened(0.12), color, 0))
	button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, ORANGE, 2))
	return button

func _panel_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	return style

func _divider() -> HSeparator:
	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", Color("d8d5c9"))
	return divider

func _layout(view_size: Vector2) -> void:
	var overlay := get_node("CanvasLayer/PilotInterface") as Control
	var width := view_size.x
	var height := view_size.y
	var side_width := minf(410.0, width * 0.43)
	var title := overlay.get_node("IdentityPanel") as PanelContainer
	title.position = Vector2(20, 20)
	title.size = Vector2(minf(440, width - side_width - 60), 99)
	var notice := overlay.get_node("SampleNotice") as PanelContainer
	notice.position = Vector2(20, 130)
	notice.size = Vector2(minf(385, width - side_width - 60), 39)
	var controls := _controls_panel
	controls.position = Vector2(width - side_width - 20, 20)
	controls.size = Vector2(side_width, height - 40)
	_narrow_layout = width < 800
	_controls_toggle.visible = _narrow_layout
	if _narrow_layout:
		title.size = Vector2(width - 40, 99)
		notice.size = Vector2(width - 40, 39)
		_controls_toggle.position = Vector2(20, 181)
		_controls_toggle.size = Vector2(width - 40, 39)
		controls.position = Vector2(20, 230)
		controls.size = Vector2(width - 40, maxf(height - 250, 220))
		controls.visible = camera_mode == "overview"
	else:
		controls.visible = true
	_controls_toggle.text = "Hide controls" if controls.visible else "Show controls"

func _toggle_controls() -> void:
	_controls_panel.visible = not _controls_panel.visible
	_controls_toggle.text = "Hide controls" if _controls_panel.visible else "Show controls"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func set_fixture_state(state: String) -> void:
	if fixture.set_state(state):
		_refresh()

func set_reduced_motion(enabled: bool) -> void:
	fixture.set_reduced_motion(enabled)
	movement.set_reduced_motion(enabled)
	_refresh()

func set_inspection(clip: String) -> void:
	if fixture.set_inspection(clip):
		movement.reset()
		_current_clip = ""
		_refresh()

func _select_actor(value: String) -> void:
	resident = value
	_kai = _actors.get(value)
	_player = _players.get(value)
	_actual_clips = _clip_maps.get(value, {})
	for key in _actors:
		_actors[key].visible = key == resident
	for player in _players.values(): player.stop()
	movement.available = _kai != null and _chair != null and _kai.find_children("*", "MeshInstance3D", true, false).size() > 0 and _chair.find_children("*", "MeshInstance3D", true, false).size() > 0
	for required in Fixture.CLIPS:
		if not _actual_clips.has(required): movement.available = false
	_current_clip = ""

func set_resident(value: String) -> void:
	if value not in ["kai", "lyra"]: return
	movement.reset()
	fixture.set_inspection("")
	_select_actor(value)
	if _resident_selector != null: _resident_selector.select(0 if value == "kai" else 1)
	if _inspection_selector != null: _inspection_selector.select(0)
	_refresh()

func request_leave() -> bool:
	if fixture.is_inspecting(): set_inspection("")
	var accepted: bool = movement.request_leave()
	_refresh()
	return accepted

func request_return() -> bool:
	if fixture.is_inspecting(): set_inspection("")
	var accepted: bool = movement.request_return()
	_refresh()
	return accepted

func advance_demo(delta: float) -> void:
	movement.advance(delta)
	_refresh(delta)

func _process(delta: float) -> void:
	if not _capture_mode and movement.busy(): advance_demo(delta)

func _refresh(delta: float = 0.0) -> void:
	var wanted: String = fixture.clip_for(imported_clips())
	if not fixture.is_inspecting() and movement.phase != "seated": wanted = movement.clip()
	if fixture.reduced_motion: wanted = ""
	var standing_preview := _standing_preview()
	if _kai != null:
		_kai.position = Movement.FLOOR if standing_preview else movement.actor_position
		_kai.rotation.y = movement.yaw
		if fixture.is_inspecting() and fixture.inspection in ["sit_down", "stand_up"] and not fixture.reduced_motion:
			_kai.position = Movement.PULLED
	if _chair != null:
		_chair.position = Movement.PULLED if fixture.is_inspecting() and fixture.inspection in ["sit_down", "stand_up"] and not fixture.reduced_motion else movement.chair_position
		get_node("ChairCollision").position = _chair.position + Vector3(0, 0.45, -0.03)
	if _preview_pad != null: _preview_pad.visible = standing_preview or movement.phase == "away"
	if _player != null:
		_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if movement.busy() or _capture_mode else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
		if fixture.reduced_motion:
			var still := "idle" if movement.phase == "away" else "seated_idle"
			if _actual_clips.has(still):
				_player.play(_actual_clips[still])
				_player.seek(0, true)
			_player.pause()
		elif wanted != "" and _actual_clips.has(wanted):
			if wanted != _current_clip:
				var blend := 0.12 if _current_clip != "" and _current_clip not in ["stand_up", "sit_down"] and wanted not in ["stand_up", "sit_down"] else 0.0
				_player.play(_actual_clips[wanted], blend)
				_player.advance(0)
			if movement.busy():
				var animation: Animation = _player.get_animation(_actual_clips[wanted])
				if delta > 0: _player.advance(delta)
				var sample_time: float = fposmod(movement.elapsed, animation.length) if animation.loop_mode != Animation.LOOP_NONE else minf(movement.elapsed, animation.length)
				_player.seek(sample_time, true)
		else:
			_player.stop()
	_current_clip = wanted if _actual_clips.has(wanted) else ""
	if _status_label != null:
		_status_label.text = fixture.state.capitalize() + " · fictional fixture\n" + _status_detail() + "\nDemo: " + movement.phase + ("" if movement.available else " — movement unavailable (required asset or clip missing)")
		for state in _state_buttons:
			(_state_buttons[state] as Button).set_pressed_no_signal(state == fixture.state)
	if _identity_label != null: _identity_label.text = ("Kai" if resident == "kai" else "Lyra") + "’s workshop bay"
	if _leave_button != null: _leave_button.disabled = not movement.available or movement.phase != "seated"
	if _return_button != null: _return_button.disabled = not movement.available or movement.phase != "away"
	if _motion_button != null: _motion_button.set_pressed_no_signal(fixture.reduced_motion)
	if _inspection_selector != null: _inspection_selector.select(Fixture.CLIPS.find(fixture.inspection) + 1)
	if _text_label != null: _text_label.text = describe()

func _standing_preview() -> bool:
	return fixture.is_inspecting() and (fixture.inspection == "idle" or fixture.inspection == "walk") and not fixture.reduced_motion

func _status_detail() -> String:
	if fixture.is_inspecting():
		return "Animation preview: " + fixture.inspection.replace("_", " ") + ". This is a manual clip check."
	match fixture.state:
		"working": return "Fictional work state; no live feed."
		"idle": return "Idle sample; typing stopped."
		"stale": return "Stale sample; typing stopped."
		"unavailable": return "Unavailable sample; typing stopped."
		_: return "Unknown sample; typing stopped."

func describe() -> String:
	var display_name := "Kai" if resident == "kai" else "Artistic Lyra"
	var result := "SAMPLE DATA — " + display_name + "’s voxel workshop bay.\n"
	result += "An open-front cream and wood workshop, cobalt accents, plants, a desk, chair, and terminal. Kai is a white voxel robot with a dark screen face, green eyes and smile, and a tool apron.\n"
	if _kai == null:
		result += "Kai is not visible because the character asset is missing.\n"
	elif fixture.is_inspecting() and fixture.inspection in ["stand_up", "sit_down"] and not fixture.reduced_motion:
		result += display_name + " previews a seat transition at the pulled chair; the one-shot holds its final pose.\n"
	elif movement.busy():
		result += display_name + " demo: " + movement.phase + ".\n"
	elif _standing_preview() or movement.phase == "away":
		result += "Kai stands on the clear floor inspection mark.\n"
	else:
		result += "Kai sits at the desk.\n"
	if resident == "lyra": result = result.replace("Kai", "Artistic Lyra").replace("a tool apron", "a reversible colour-panel vest and sketch-sheet pouch")
	if not movement.available: result += "Movement unavailable: required character, chair, or animation missing.\n"
	result += "State: " + fixture.state.capitalize() + ". " + _status_detail() + "\n"
	if fixture.is_inspecting():
		result += "Animation preview is manually selected and does not report real work.\n"
	if fixture.reduced_motion:
		result += "Reduced motion is on; animation is stopped.\n"
	elif _current_clip != "":
		result += "Imported animation: " + _current_clip.replace("_", " ") + ".\n"
	else:
		result += "No animation is playing.\n"
	if not _missing.is_empty():
		result += "Assets missing or not imported: " + ", ".join(_missing) + ".\n"
	result += "Camera: " + camera_mode + ". Use O for overview, F for first person, WASD to move, Escape to release mouse, R to reset."
	return result

func missing_assets() -> Array[String]:
	return _missing.duplicate()

func imported_clips() -> Array[String]:
	var result: Array[String] = []
	for clip in Fixture.CLIPS:
		if _actual_clips.has(clip):
			result.append(clip)
	return result

func active_clip() -> String:
	return _current_clip

func _toggle_camera() -> void:
	_set_camera("first_person" if camera_mode == "overview" else "overview")

func _set_camera(mode: String) -> void:
	camera_mode = mode
	_overview.current = mode == "overview"
	_eye.current = mode == "first_person"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mode == "first_person" and not _narrow_layout else Input.MOUSE_MODE_VISIBLE
	if _narrow_layout:
		_controls_panel.visible = mode == "overview"
		_controls_toggle.text = "Hide controls" if _controls_panel.visible else "Show controls"
	if _camera_button != null:
		_camera_button.text = "Return to overview" if mode == "first_person" else "Enter first person"
	if _text_label != null:
		_text_label.text = describe()

func _show_text(enabled: bool) -> void:
	_text_panel.visible = enabled
	_text_label.text = describe()

func reset_pilot() -> void:
	movement.reset()
	movement.set_reduced_motion(false)
	_current_clip = ""
	fixture.set_state("working")
	fixture.set_inspection("")
	fixture.set_reduced_motion(false)
	_walker.position = Vector3(2.0, 0.0, 1.75)
	_walker.rotation = Vector3(0, 0.7, 0)
	_eye.rotation = Vector3.ZERO
	_set_camera("overview")
	if _inspection_selector != null:
		_inspection_selector.select(0)
	if _text_button != null:
		_text_button.set_pressed_no_signal(false)
	if _text_panel != null:
		_text_panel.hide()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and camera_mode == "first_person" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_walker.rotate_y(-event.relative.x * 0.0025)
		_eye.rotation.x = clampf(_eye.rotation.x - event.relative.y * 0.0025, -1.2, 1.2)
	elif event is InputEventMouseButton and event.pressed and camera_mode == "first_person" and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_O: _set_camera("overview")
			KEY_F: _set_camera("first_person")
			KEY_R: reset_pilot()
			KEY_T:
				_text_button.button_pressed = not _text_button.button_pressed
			KEY_M:
				_motion_button.button_pressed = not _motion_button.button_pressed

func _physics_process(delta: float) -> void:
	if camera_mode != "first_person":
		return
	var movement := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A): movement.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): movement.x += 1.0
	if Input.is_physical_key_pressed(KEY_W): movement.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): movement.y += 1.0
	var direction := _walker.global_transform.basis * Vector3(movement.x, 0, movement.y).normalized()
	_walker.velocity = Vector3(direction.x * 2.4, 0, direction.z * 2.4)
	_walker.move_and_slide()
	_walker.position.x = clampf(_walker.position.x, -3.45, 3.45)
	_walker.position.z = clampf(_walker.position.z, -2.45, 2.65)

func _capture_if_requested() -> void:
	var capture_path := ""
	var capture_camera := "overview"
	var motion_time := -1.0
	var sequence_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
		elif argument.begins_with("--resident="):
			set_resident(argument.trim_prefix("--resident="))
		elif argument.begins_with("--motion-time="):
			motion_time = argument.trim_prefix("--motion-time=").to_float()
		elif argument.begins_with("--capture-cycle="):
			sequence_path = argument.trim_prefix("--capture-cycle=")
		elif argument == "--camera=first_person":
			capture_camera = "first_person"
	if capture_path == "" and sequence_path == "":
		return
	_capture_mode = true
	if DisplayServer.get_name() == "headless":
		push_error("PNG capture needs a graphical display; run without --headless")
		get_tree().quit(2)
		return
	_set_camera(capture_camera)
	for frame in range(12):
		await get_tree().process_frame
	if sequence_path != "":
		await _capture_cycle(sequence_path)
		return
	if motion_time >= 0:
		if not movement.available:
			push_error("Cannot capture motion: required assets missing")
			get_tree().quit(1)
			return
		request_leave()
		advance_demo(motion_time)
	if _player != null and _current_clip != "":
		if motion_time < 0: _player.seek(0.4, true)
		_player.pause()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(capture_path)
	var report := {
		"capture": capture_path,
		"error": error,
		"viewport": image.get_size(),
		"camera": capture_camera,
		"resident": resident,
		"motion_time": motion_time,
		"motion_phase": movement.phase,
		"godot_version": Engine.get_version_info().string,
		"frames_drawn": Engine.get_frames_drawn(),
		"missing_assets": _missing,
		"clips": imported_clips(),
		"draw_calls_sample": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives_sample": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"render_objects_sample": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"static_memory_bytes_sample": Performance.get_monitor(Performance.MEMORY_STATIC),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"measurement_scope": "One local startup frame; not a target-device benchmark",
	}
	var metrics_file := FileAccess.open(capture_path.get_basename() + ".json", FileAccess.WRITE)
	if metrics_file != null:
		metrics_file.store_string(JSON.stringify(report, "  ") + "\n")
		metrics_file.close()
	else:
		push_error("Could not write capture metrics beside PNG")
	print(JSON.stringify(report))
	get_tree().quit(0 if error == OK and metrics_file != null else 1)

## Offline fixed-step frames: ffmpeg -framerate 24 -i frame-%04d.png ...
func _capture_cycle(directory: String) -> void:
	if not movement.available:
		push_error("Cannot capture motion: required assets missing")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	reset_pilot()
	var returning := false
	request_leave()
	for frame in range(600):
		if movement.phase == "away" and not returning:
			request_return()
			returning = true
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(directory.path_join("frame-%04d.png" % frame))
		if error != OK:
			get_tree().quit(1)
			return
		if returning and movement.phase == "seated":
			print(JSON.stringify({"capture_cycle":directory, "frames":frame+1, "fps":24, "resident":resident}))
			get_tree().quit(0)
			return
		advance_demo(1.0/24.0)
	push_error("Cycle failed to complete")
	get_tree().quit(1)
