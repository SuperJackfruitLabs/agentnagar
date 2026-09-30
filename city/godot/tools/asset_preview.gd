extends SceneTree
## Renders kit assets as the game shows them for art review: the anime kit
## toon-shaded with the city's ink line pass (and character outlines), a lit
## style's kit (--lit, or a pack whose style.json says "shading": "lit")
## with physically based light, faces and glowing robot eyes:
##   godot --path godot --resolution 1280x960 --script res://tools/asset_preview.gd -- NAME_PREFIX... \
##     [--yaw DEG] [--pitch DEG] [--fill F] [--night] [--outline] [--lit] [--dir res://styles/anime_cel/assets]
## Writes ~/.cache/agentnagar-anime-preview/<name>.png.
var out := OS.get_environment("HOME") + "/.cache/agentnagar-anime-preview/"


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	# Kit modules face Godot's -Z: the default view is from their front,
	# 30 degrees round and a little above.
	var opts := {"yaw": "210", "pitch": "-22", "fill": "1.0", "dir": "res://styles/anime_cel/assets"}
	var prefixes := []
	var k := 0
	while k < args.size():
		var a: String = args[k]
		if a in ["--night", "--outline", "--lit"]:
			opts[a.substr(2)] = "1"
		elif a.begins_with("--"):
			opts[a.substr(2)] = args[k + 1]
			k += 1
		else:
			prefixes.append(a)
		k += 1
	DirAccess.make_dir_recursive_absolute(out)
	if _style_is_lit(opts["dir"]):
		opts["lit"] = "1"
	LitFace.read_files = true
	AnimeLook.tune_viewport(root)
	var names := []
	for f in DirAccess.get_files_at(opts["dir"]):
		if f.ends_with(".glb") and (prefixes.is_empty() or prefixes.any(func(p): return f.begins_with(p))):
			names.append(f.get_basename())
	names.sort()
	for name in names:
		await _shoot(name, opts)
	print("preview: %d assets rendered to %s" % [names.size(), out])
	quit()


static func _style_is_lit(dir: String) -> bool:
	var f := FileAccess.open(dir.get_base_dir().path_join("style.json"), FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	return data is Dictionary and data.get("shading", "") == "lit"


## A lit style's preview light: a clear warm day, or a navy night.
static func _lit_stage(stage: Node3D, opts: Dictionary) -> void:
	var night := opts.has("night")
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#0B1330") if night else Color("#4F9BE0")
	sm.sky_horizon_color = Color("#1E2C55") if night else Color("#CFE3EE")
	sm.ground_horizon_color = sm.sky_horizon_color
	sm.ground_bottom_color = Color("#10162A") if night else Color("#B9B09C")
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35 if night else 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_intensity = 1.2
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.0
	env.glow_intensity = 0.6
	we.environment = env
	stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, float(opts["yaw"]) + 35.0, 0)
	sun.light_color = Color("#9DB0E8") if night else Color("#FFE6C4")
	sun.light_energy = 0.15 if night else 1.5
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	stage.add_child(sun)


func _shoot(name: String, opts: Dictionary) -> void:
	var stage := Node3D.new()
	var lit := opts.has("lit")
	root.add_child(stage)
	var night := opts.has("night")
	if lit:
		_lit_stage(stage, opts)
	else:
		var we := WorldEnvironment.new()
		var env := Environment.new()
		var sky := Sky.new()
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = Color("#0E1A3E") if night else AnimeLook.SKY_TOP
		sm.sky_horizon_color = Color("#243A6A") if night else AnimeLook.HORIZON
		sm.ground_horizon_color = sm.sky_horizon_color
		sm.ground_bottom_color = sm.sky_horizon_color
		sky.sky_material = sm
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("#3A4280") if night else AnimeLook.AMBIENT
		env.ambient_light_energy = 0.6 if night else AnimeLook.AMBIENT_ENERGY
		AnimeLook.tune(env)
		we.environment = env
		stage.add_child(we)
		var sun := DirectionalLight3D.new()
		# From over the camera's left shoulder, so fronts are lit.
		sun.rotation_degrees = Vector3(-48, float(opts["yaw"]) + 35.0, 0)
		sun.light_color = Color("#9AA8E0") if night else AnimeLook.SUN
		sun.light_energy = 0.25 if night else AnimeLook.SUN_ENERGY
		AnimeLook.tune_sun(sun)
		stage.add_child(sun)
	# Loaded from the file at runtime, without an import, so builders can
	# preview while other work runs in the project.
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path(opts["dir"].path_join(name + ".glb")), state)
	var model: Node3D = doc.generate_scene(state)
	stage.add_child(model)
	# A character: one hair style, no extras, the near body, its face.
	if model.find_child("face", true, false) != null:
		for part in ["hair_1", "hair_2", "hair_3", "hat_sun", "backpack", "far", "umbrella"]:
			var n = model.find_child(part, true, false)
			if n != null:
				n.visible = false
		if lit:
			var face := LitFace.dress(model, opts["dir"].path_join("face_atlas.png"), int(opts.get("variant", "0")), 0.37)
			LitFace.express(face, opts.get("expression", "neutral"))
		else:
			AnimeFace.dress(model, int(opts.get("variant", "0")), 0.37)
			var face = model.find_child("face", true, false)
			AnimeFace.express(face, opts.get("expression", "neutral"))
		var player = model.find_children("*", "AnimationPlayer", true, false)
		if not player.is_empty() and player[0].has_animation(opts.get("anim", "idle")):
			player[0].play(opts.get("anim", "idle"))
	var eyes := model.find_child("eyes", true, false)
	if lit and eyes != null:
		for part in ["far", "umbrella"]:
			var n = model.find_child(part, true, false)
			if n != null:
				n.visible = false
		LitFace.light_eyes(model, opts["dir"].path_join("eyes_atlas.png"), 0.37, 2.2 if night else 1.4)
		LitFace.express(eyes, opts.get("expression", "neutral"))
		var player = model.find_children("*", "AnimationPlayer", true, false)
		if not player.is_empty() and player[0].has_animation(opts.get("anim", "idle")):
			player[0].play(opts.get("anim", "idle"))
	if not lit:
		Toon.apply(model)
	if opts.has("outline"):
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			Toon.outline(mi, 1.5)
	var box := _bounds(model)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1) * maxf(box.size.x, box.size.z) * 4.0 + Vector2(4, 4)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#EADFCC")
	ground.material_override = gm
	ground.position = Vector3(box.get_center().x, box.position.y - 0.005, box.get_center().z)
	stage.add_child(ground)
	if not lit:
		Toon.apply(ground)
	var cam := Camera3D.new()
	cam.fov = 35.0
	stage.add_child(cam)
	var centre := box.get_center()
	var radius := box.size.length() / 2.0 / float(opts["fill"])
	# --focus head: frame a character's head and shoulders.
	if opts.get("focus") == "head":
		centre = Vector3(box.get_center().x, 1.56, box.get_center().z)
		radius = 0.3
	var dist := radius / sin(deg_to_rad(cam.fov / 2.0)) * 1.05
	var dir := Basis.from_euler(Vector3(deg_to_rad(float(opts["pitch"])), deg_to_rad(float(opts["yaw"])), 0)) * Vector3.BACK
	cam.position = centre + dir * dist
	cam.look_at(centre)
	cam.near = maxf(0.02, dist - radius * 2.0)
	cam.far = dist + radius * 4.0
	cam.current = true
	if not lit:
		Toon.line_pass(cam)
	for f in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var tag := (".night" if night else "") + ("." + str(opts["tag"]) if opts.has("tag") else "")
	root.get_viewport().get_texture().get_image().save_png(out + name + tag + ".png")
	stage.queue_free()
	await process_frame


static func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for vi in n.find_children("*", "VisualInstance3D", true, false):
		var b: AABB = vi.global_transform * vi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
