extends Node3D
## Sample-only shared room. Fixed disjoint routes with continuous swept guards.
const Station = preload("res://workshop_station.gd")
const Fixture = preload("res://fixture_model.gd")
# Circumscribed horizontal square radii plus the visitor's .24m capsule.
const SAFE_RADIUS := 0.82
const CHAIR_SAFE_RADIUS := 0.71
const ROOT_TRAVEL := Vector3(0,0,0.3363034344)
var stations := {}
var walker: CharacterBody3D
var eye: Camera3D
var overview: Camera3D
var camera_mode := "overview"
var missing: Array[String] = []
var cutaway_nodes: Array[Node3D] = []
var capture_mode := false
var reduced_motion := false
var controls: PanelContainer
var notice: Label
var status: Label
var text_view: Label
var toggle: Button
var _ui: Control
var _options := {}
var _cycle := false
var _measuring := false
var selectors := {}
var _phase_labels := {}

func _ready() -> void:
	build_world()
	build_layout()
	build_ui()
	set_camera("overview")
	get_viewport().size_changed.connect(layout_ui)
	layout_ui()
	call_deferred("run_options")

func build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e9e3d3")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff0da")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.light_energy = 0.85
	add_child(sun)
	overview = Camera3D.new()
	overview.near = 0.1
	overview.far = 70
	add_child(overview)
	walker = CharacterBody3D.new()
	walker.name = "Visitor"
	walker.position = Vector3(9,0,1)
	walker.rotation.y = PI/2
	add_child(walker)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.55
	collision.shape = capsule
	collision.position.y = 0.8
	walker.add_child(collision)
	eye = Camera3D.new()
	eye.position.y = 1.52
	eye.fov = 75
	eye.near = 0.06
	walker.add_child(eye)

func vec(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func load_asset(asset: String, point: Vector3) -> Node3D:
	var path := "res://assets/" + asset
	if not ResourceLoader.exists(path):
		missing.append(asset)
		return null
	var packed = load(path)
	if not packed is PackedScene:
		missing.append(asset + " (import failed)")
		return null
	var node = packed.instantiate()
	node.position = point
	add_child(node)
	return node

func add_box(identity: String, point: Vector3, size: Vector3, yaw: float = 0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = identity
	body.position = point
	body.rotation_degrees.y = yaw
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	add_child(body)
	return body

func build_layout() -> void:
	var path := "res://assets/workshop/layout.json"
	if not FileAccess.file_exists(path):
		missing.append("workshop/layout.json")
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != 1:
		missing.append("workshop/layout.json (invalid version)")
		return
	for entry in data.instances:
		var node := load_asset(entry.asset, vec(entry.position))
		if node != null:
			node.rotation_degrees.y = entry.rotation_y
			if entry.group in ["roof", "front"]: cutaway_nodes.append(node)
	for entry in data.collisions:
		add_box(entry.id, vec(entry.position), vec(entry.size), entry.rotation_y)
	for entry in data.stations:
		var station = Station.new()
		station.build(self, entry.resident, vec(entry.origin))
		stations[entry.resident] = station

func missing_assets() -> Array[String]: return missing.duplicate()

func swept_near(start: Vector3, finish: Vector3, obstacle: Vector3, radius: float) -> bool:
	var a := Vector2(start.x,start.z)
	var b := Vector2(finish.x,finish.z)
	var p := Vector2(obstacle.x,obstacle.z)
	var segment := b-a
	var t := clampf((p-a).dot(segment) / maxf(segment.length_squared(), 0.000001),0,1)
	return (a + segment*t).distance_to(p) < radius

func blocked(station, before: Vector3, after: Vector3, chair_before: Vector3, chair_after: Vector3, phase_before: String) -> bool:
	if swept_near(before, after, walker.position, SAFE_RADIUS): return true
	if swept_near(chair_before + Vector3(0,0,-0.03), chair_after + Vector3(0,0,-0.03), walker.position, CHAIR_SAFE_RADIUS): return true
	# Imported stand/sit Root translates inside a stationary instance. Sweep its
	# entire authored interval conservatively, including phase boundaries.
	if phase_before in ["standing up","sitting down"] or station.movement.phase in ["standing up","sitting down"]:
		if swept_near(before, after + ROOT_TRAVEL, walker.position, SAFE_RADIUS): return true
	for other in stations.values():
		if other == station: continue
		if swept_near(before, after, other.actor_body.position, 1.14): return true
	return false

func advance_demo(delta: float) -> void:
	# Bound each trial at 1/60s, then sweep each actual segment. Large caller
	# deltas cannot shortcut around a corner or tunnel through a visitor.
	var remaining := maxf(delta,0)
	while remaining > 0.000001:
		var step := minf(remaining,1.0/60)
		remaining -= step
		for station in stations.values():
			station.waiting = false
			if station.movement.busy():
				var saved: Dictionary = station.snapshot()
				var before: Vector3 = station.origin + station.movement.actor_position
				var chair_before: Vector3 = station.origin + station.movement.chair_position
				station.movement.advance(step)
				if blocked(station, before, station.origin + station.movement.actor_position, chair_before, station.origin + station.movement.chair_position, saved.phase):
					station.restore(saved)
					station.waiting = true
			station.refresh(step)
	refresh_status()

func request_leave(who: String) -> bool: return request_journey(who, false)
func request_return(who: String) -> bool: return request_journey(who, true)
func request_journey(who: String, returning: bool) -> bool:
	var accepted := false
	for key in stations:
		if who != "all" and key != who: continue
		var station = stations[key]
		if not station.validate(): continue
		accepted = (station.movement.request_return() if returning else station.movement.request_leave()) or accepted
	if reduced_motion and accepted: advance_demo(30)
	refresh_status()
	return accepted

func set_fixture_state(who: String, state: String) -> void:
	if stations.has(who):
		stations[who].fixture.set_state(state)
		stations[who].refresh()
	refresh_status()

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	for station in stations.values(): station.fixture.set_reduced_motion(enabled)
	# Walk the guarded route without intermediate rendered frames. If obstructed,
	# retain a safe paused position; clearing the visitor completes the route.
	if enabled: advance_demo(30)
	for station in stations.values(): station.refresh()

func reset_workshop() -> void:
	walker.position = Vector3(9,0,1)
	walker.rotation = Vector3(0,PI/2,0)
	eye.rotation = Vector3.ZERO
	reduced_motion = false
	for station in stations.values():
		station.movement.reset()
		station.fixture.set_reduced_motion(false)
		station.fixture.set_state("working")
		station.waiting = false
		station.current_clip = ""
		station.refresh()
	for select in selectors.values(): select.select(0)
	set_camera("overview")
	refresh_status()

func describe() -> String:
	var result := "SAMPLE DATA — shared voxel workshop and courtyard. Three sawtooth roof bays; east doorway connects a flush courtyard path to fourteen work bays, %d of them currently occupied by independent robot residents.\n" % stations.size()
	# A full sentence per resident reads as a wall of text at fourteen. A
	# one-line phase tally up front keeps the hall's state scannable at a
	# glance; the per-resident lines below stay, one each, so any individual
	# resident's state is still reachable — just terser than before.
	var phase_counts := {}
	var waiting_count := 0
	for key in stations:
		var station = stations[key]
		phase_counts[station.movement.phase] = phase_counts.get(station.movement.phase,0) + 1
		if station.waiting: waiting_count += 1
	var tally: Array[String] = []
	for phase in phase_counts: tally.append("%d %s" % [phase_counts[phase], phase])
	result += "At a glance: " + ", ".join(tally)
	if waiting_count > 0: result += "; %d waiting for the visitor" % waiting_count
	result += ".\n"
	for key in stations:
		var station = stations[key]
		result += key.capitalize() + ": " + station.fixture.state + " / " + station.movement.phase + ("; waiting" if station.waiting else "") + ("; movement unavailable" if not station.movement.available else "") + "\n"
	result += "Fixed demonstration routes; fictional work states, no live feed. Camera: " + camera_mode + "."
	if not missing.is_empty(): result += " Missing assets: " + ", ".join(missing)
	return result

func _process(delta: float) -> void:
	if capture_mode: return
	if _cycle:
		for key in stations:
			if stations[key].movement.phase == "seated": request_leave(key)
			elif stations[key].movement.phase == "away": request_return(key)
	advance_demo(delta)

func set_camera(mode: String) -> void:
	if _measuring: return
	camera_mode = mode
	for node in cutaway_nodes: node.visible = mode != "overview"
	overview.current = mode != "first_person"
	eye.current = mode == "first_person"
	if mode == "exterior":
		overview.position = Vector3(17,13,19)
		overview.fov = 48
		overview.look_at(Vector3(2.5,0.8,0))
	elif mode == "overview":
		overview.position = Vector3(12,15,18)
		overview.fov = 43
		overview.look_at(Vector3(2.0,0,-0.3))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_status()

func _physics_process(_delta: float) -> void:
	if camera_mode != "first_person" or capture_mode or _measuring: return
	var input := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var direction := walker.basis * Vector3(input.x,0,input.y).normalized()
	walker.velocity = direction * 2.4
	walker.move_and_slide()
	walker.position.x = clampf(walker.position.x,-6.1,12.2)
	walker.position.z = clampf(walker.position.z,-8.2,8.2)

func _unhandled_input(event: InputEvent) -> void:
	if _measuring: return
	if event is InputEventMouseMotion and camera_mode == "first_person" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		walker.rotate_y(-event.relative.x * 0.0025)
		eye.rotation.x = clampf(eye.rotation.x-event.relative.y*0.0025,-1.2,1.2)
	elif event is InputEventMouseButton and event.pressed and camera_mode == "first_person": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_O: set_camera("overview")
			KEY_E: set_camera("exterior")
			KEY_F: set_camera("first_person")
			KEY_R: reset_workshop()
			KEY_L: request_leave("all")
			KEY_B: request_return("all")
			KEY_M: set_reduced_motion(not reduced_motion)
			KEY_T: text_view.visible = not text_view.visible
			KEY_C: controls.visible = not controls.visible

func button(parent: Node, title: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = title
	node.custom_minimum_size.y = 34
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	notice = Label.new()
	notice.text = "SHARED WORKSHOP  /  SAMPLE DATA"
	notice.add_theme_color_override("font_color",Color("22314b"))
	notice.add_theme_font_size_override("font_size",19)
	_ui.add_child(notice)
	toggle = button(_ui,"Controls [C]",func(): controls.visible = not controls.visible)
	controls = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fffaf0")
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	controls.add_theme_stylebox_override("panel",style)
	_ui.add_child(controls)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color",Color("22314b"))
	stack.add_child(status)
	var views := HBoxContainer.new()
	stack.add_child(views)
	for entry in [["Cutaway [O]","overview"],["Roof [E]","exterior"],["Walk [F]","first_person"]]:
		button(views,entry[0],set_camera.bind(entry[1])).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var journeys := HBoxContainer.new()
	stack.add_child(journeys)
	button(journeys,"All leave [L]",request_leave.bind("all")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(journeys,"All return [B]",request_return.bind("all")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# One compact row per resident (name, leave, return, fixture selector). At
	# fourteen residents this stack is taller than any panel we would want
	# fixed on screen, so every widget here is deliberately shorter than the
	# global buttons above, and layout_ui() gives the panel far more height
	# than the old fixed 188 px — the ScrollContainer still carries the rest.
	for key in stations:
		var row := HBoxContainer.new()
		stack.add_child(row)
		var name_label := Label.new()
		name_label.text = key.capitalize()
		name_label.custom_minimum_size.x = 118
		name_label.add_theme_color_override("font_color",Color("22314b"))
		row.add_child(name_label)
		# Per-row phase readout: moving detail here (instead of one long
		# per-resident sentence in the shared status line above) is what lets
		# that line collapse to a one-line tally at fourteen residents.
		var phase_label := Label.new()
		phase_label.custom_minimum_size.x = 132
		phase_label.clip_text = true
		phase_label.add_theme_color_override("font_color",Color("55606f"))
		row.add_child(phase_label)
		_phase_labels[key] = phase_label
		var leave_button := button(row,"Leave",request_leave.bind(key))
		leave_button.custom_minimum_size.y = 26
		var return_button := button(row,"Return",request_return.bind(key))
		return_button.custom_minimum_size.y = 26
		var select := OptionButton.new()
		for state in Fixture.STATES: select.add_item(state.capitalize())
		select.item_selected.connect(func(index: int): set_fixture_state(key,Fixture.STATES[index]))
		select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select.custom_minimum_size.y = 26
		row.add_child(select)
		selectors[key] = select
	var options := HBoxContainer.new()
	stack.add_child(options)
	button(options,"Motion [M]",func(): set_reduced_motion(not reduced_motion))
	button(options,"Text [T]",func(): text_view.visible = not text_view.visible)
	button(options,"Reset [R]",reset_workshop)
	text_view = Label.new()
	text_view.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_view.add_theme_color_override("font_color",Color("22314b"))
	text_view.hide()
	stack.add_child(text_view)
	var help := Label.new()
	help.text = "Walk: WASD · click to look · Esc releases mouse"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color",Color("22314b"))
	stack.add_child(help)
	controls.hide()

func layout_ui() -> void:
	var size := get_viewport().get_visible_rect().size
	notice.position = Vector2(12,10)
	notice.add_theme_font_size_override("font_size",14 if size.x < 600 else 19)
	toggle.position = Vector2(12,42)
	toggle.size = Vector2(132,34)
	# Fourteen resident rows no longer fit in the old fixed 188 px panel.
	# Grow it, but cap well short of the full viewport so the hall itself
	# (the reason this scene exists) stays visible above the panel; the
	# inner ScrollContainer carries whatever still does not fit.
	var panel_height := clampf(size.y*0.45,188,320)
	controls.position = Vector2(12,size.y-panel_height-12)
	controls.size = Vector2(size.x-24,panel_height)
	if size.x < 600:
		controls.position = Vector2(12,90)
		controls.size = Vector2(size.x-24,size.y-102)
		controls.hide()

func refresh_status() -> void:
	if status == null: return
	# One sentence-per-resident here was the first place fourteen residents
	# read as a wall of text; a short phase tally replaces it, and the detail
	# that used to live in this line now lives in each resident's own row.
	var phase_counts := {}
	var waiting_count := 0
	for key in stations:
		var station = stations[key]
		phase_counts[station.movement.phase] = phase_counts.get(station.movement.phase,0) + 1
		if station.waiting: waiting_count += 1
		if _phase_labels.has(key):
			_phase_labels[key].text = "waiting" if station.waiting else station.movement.phase
	var tally: Array[String] = []
	for phase in phase_counts: tally.append("%d %s" % [phase_counts[phase], phase])
	status.text = "     ·     ".join(tally) + (("     ·     %d waiting" % waiting_count) if waiting_count > 0 else "") + ("  ·  Reduced motion" if reduced_motion else "")
	text_view.text = describe()

func run_options() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			_options[arg.trim_prefix("--").get_slice("=",0)] = arg.substr(arg.find("=")+1)
	if _options.has("camera"): set_camera(_options.camera)
	if _options.has("visitor-position"):
		var xyz: PackedStringArray = _options["visitor-position"].split(",")
		walker.position = Vector3(float(xyz[0]),float(xyz[1]),float(xyz[2]))
	if _options.has("visitor-yaw"): walker.rotation_degrees.y = float(_options["visitor-yaw"])
	if _options.has("show-controls"): controls.show()
	if _options.has("measure-seconds"):
		await measure_live()
	elif _options.has("capture") or _options.has("capture-walkthrough"):
		await capture()

func metrics() -> Dictionary:
	return {"godot_version":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"viewport":[get_viewport().size.x,get_viewport().size.y],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"render_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"node_count":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"missing_assets":missing,"camera":camera_mode}

func save_report(path: String, report: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		push_error("Cannot write report: "+path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report,"  ")+"\n")
	print(JSON.stringify(report))

func measure_live() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Live renderer sampling needs a graphical display")
		get_tree().quit(1)
		return
	_measuring = true
	controls.hide()
	toggle.disabled = true
	_cycle = true
	var warmup := float(_options.get("warmup-seconds","5"))
	await get_tree().create_timer(warmup).timeout
	var samples: Array[float] = []
	var duration := float(_options["measure-seconds"])
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec()-start < duration*1000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		samples.append((now-previous)/1000.0)
		previous = now
	samples.sort()
	var report := metrics()
	report.merge({"measurement_scope":"Actual live process-frame intervals with all fourteen residents continuously cycling; local machine only, no target-device acceptance claim.","sample_count":samples.size(),"wall_span_seconds":(previous-start)/1000000.0,"warmup_seconds":warmup,"frame_ms_p50":samples[int(samples.size()*0.50)],"frame_ms_p95":samples[mini(int(samples.size()*0.95),samples.size()-1)],"frame_ms_max":samples[-1]})
	save_report(_options.get("report","user://shared-performance.json"),report)
	get_tree().quit()

func capture() -> void:
	capture_mode = true
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires graphical display")
		get_tree().quit(1)
		return
	for frame in range(12): await get_tree().process_frame
	if _options.has("capture-walkthrough"):
		await capture_walkthrough(_options["capture-walkthrough"])
		return
	if not _options.has("seated"):
		request_leave("all")
	advance_demo(float(_options.get("motion-time","0")))
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_options.capture)
	var report := metrics()
	report["measurement_scope"] = "Single deterministic offline capture; not live frame timing"
	report["error"] = error
	save_report(_options.capture.get_basename()+".json",report)
	get_tree().quit(0 if error == OK else 1)

func capture_walkthrough(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	request_leave("all")
	for frame in range(480):
		if frame == 0: set_camera("exterior")
		if frame == 72: set_camera("overview")
		if frame == 216:
			set_camera("first_person")
			walker.position = Vector3(9,0,1)
			walker.rotation.y = PI/2
		if frame >= 216 and frame < 300:
			walker.move_and_collide(Vector3(-0.055,0,0))
		if frame == 300:
			walker.position = Vector3(9,0,1)
			set_camera("overview")
		for key in stations:
			if stations[key].movement.phase == "away": request_return(key)
		advance_demo(1.0/24)
		await RenderingServer.frame_post_draw
		if get_viewport().get_texture().get_image().save_png(directory.path_join("frame-%04d.png" % frame)) != OK:
			get_tree().quit(1)
			return
	var report := metrics()
	var phases := {}
	for key in stations: phases[key] = stations[key].movement.phase
	report["final_phases"] = phases
	report.merge({"measurement_scope":"Offline fixed 24fps, same guarded stepping and blends as live; not a performance test", "frames":480,"fps":24,"sequence":"Exterior, all fourteen journeys in cutaway, courtyard through east doorway, return overview"})
	save_report(directory.path_join("capture.json"),report)
	get_tree().quit()
