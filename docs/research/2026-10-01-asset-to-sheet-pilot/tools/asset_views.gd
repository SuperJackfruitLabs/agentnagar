extends SceneTree
## Close views of one placed asset, for setting it beside its concept sheet
## and for measuring it. A pilot tool: asset_try.sh copies it into the
## working copy of the client (city/godot/tools/); it is not part of the client.
##   godot --path godot --resolution 1920x1080 --script res://tools/asset_views.gd -- STYLE NEEDLE [COUNT] [FRAME]
## Finds the placed pieces whose scene file's name contains NEEDLE (for
## example seat_bench_v2), takes up to COUNT of them that stand at different
## facings (then others, if there are fewer facings than that), nobody
## sitting on them if it can, and at the hour the style's
## sheets are drawn (13:00; 21:48 in a night-first style) saves for each,
## under ~/.cache/agentnagar-sheets/<style>/:
##   asset-eye-<k>.png    from eye height, three-quarter front
##   asset-above-<k>.png  from above, low enough to stay under a tree's crown
## FRAME is `prop` (the default: fixed camera places that suit a piece about
## the size of a bench) or `auto` (the cameras stand back by the piece's own
## size, so a lamp post, a tree or a building fills the frame).
## and beside each view three more of the same frame, for measuring:
##   ...-mask.png    the piece in flat magenta: which pixels are the piece
##   ...-kind.png    the piece in grey by its UV's u (its second UV layer's,
##                   where it has two): which material each pixel is, where
##                   the build marked it (shade.py's `kind_marks`); black
##                   where it did not
##   ...-albedo.png  the piece unlit, with no tone curve: its own colours
## Parts named light* (lamps the game drives) are left out of all three.
## asset-views.json records each piece's place, facing, use, size and the
## scale the game gave it. Pieces the game draws as instances of one mesh
## (a meadow's clumps) have no scene of their own and are not found.
var main
var out := ""

const KIND_SHADER := "shader_type spatial;\nrender_mode unshaded;\nvoid fragment() { ALBEDO = vec3(UV.x); }\n"
## ... and for a mesh whose first UV layer is its texture's (leaf cards): the
## marks are then its second layer.
const KIND_SHADER_UV2 := "shader_type spatial;\nrender_mode unshaded;\nvoid fragment() { ALBEDO = vec3(UV2.x); }\n"


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var style: String = args[0]
	var needle: String = args[1]
	var count := int(args[2]) if args.size() > 2 else 3
	var frame: String = args[3] if args.size() > 3 else "prop"
	out = OS.get_environment("HOME") + "/.cache/agentnagar-sheets/%s/" % style
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://main.gd").new()
	root.add_child(main)
	main.boot_for_tool(PackedStringArray(["--crowd=60", "--style=" + style, "--as=none"]))
	main.driver.pause()
	main.hud.visible = false
	var pack = main.host.pack
	var night_first: bool = pack.style.get("sheet_night", false)
	await _to_tick(370 if night_first else 150)
	# The placed pieces drawn from that scene, each once.
	var found := []
	for node in pack.placement_nodes.values():
		if node is Node3D and str(node.scene_file_path).get_file().contains(needle) and not found.has(node):
			found.append(node)
	# Where people are, to tell a seat in use.
	var people := []
	for id in pack.nodes:
		var n = pack.nodes[id]
		if n is Node3D:
			people.append(n.global_position)
	var rows := []
	for node in found:
		var busy := false
		for p in people:
			if Vector2(p.x - node.global_position.x, p.z - node.global_position.z).length() < 0.8:
				busy = true
		rows.append({"node": node, "busy": busy, "turn": int(round(rad_to_deg(node.global_rotation.y) / 10.0)) * 10})
	# Free ones first, then one per facing.
	rows.sort_custom(func(a, b): return int(a["busy"]) < int(b["busy"]))
	var picked := []
	var turns := []
	for r in rows:
		if picked.size() < count and not turns.has(r["turn"]):
			picked.append(r)
			turns.append(r["turn"])
	# Fewer facings than views asked for (a piece that always stands one
	# way): others of the same facing, standing elsewhere.
	for r in rows:
		if picked.size() < count and not picked.has(r):
			picked.append(r)
	var record := []
	for k in picked.size():
		var node: Node3D = picked[k]["node"]
		var at := node.global_position
		var front := -node.global_transform.basis.z.normalized()
		var right := node.global_transform.basis.x.normalized()
		var box := _bounds(node)
		if frame == "auto":
			# Stand back by the piece's size: from eye height, and from 40 degrees up.
			var centre := box.get_center()
			var reach := box.size.length() * 0.5 / tan(deg_to_rad(38.0) * 0.5) * 1.1
			var toward := (front * 2.4 + right * 1.5).normalized()
			var level := sqrt(maxf(reach * reach - pow(centre.y - 1.6, 2.0), reach * reach * 0.25))
			await _view("asset-eye-%d" % k, Vector3(centre.x, 1.6, centre.z) + toward * level, centre, 38.0, node)
			await _view("asset-above-%d" % k, centre + toward * reach * cos(deg_to_rad(40.0)) + Vector3.UP * reach * sin(deg_to_rad(40.0)), centre, 38.0, node)
		else:
			await _view("asset-eye-%d" % k, at + front * 2.4 + right * 1.5 + Vector3(0, 1.45, 0), at + Vector3(0, 0.45, 0), 38.0, node)
			# Low enough to stay under a tree's crown (leaves start above the walking band).
			await _view("asset-above-%d" % k, at + front * 2.1 + right * 1.2 + Vector3(0, 2.7, 0), at + Vector3(0, 0.35, 0), 38.0, node)
		record.append({"at": [at.x, at.y, at.z], "turn_degrees": picked[k]["turn"], "in_use": picked[k]["busy"],
			"scale": [node.scale.x, node.scale.y, node.scale.z], "scene": str(node.scene_file_path),
			"size": [box.size.x, box.size.y, box.size.z], "frame": frame})
	var f := FileAccess.open(out + "asset-views.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"needle": needle, "placed": found.size(), "views": record}, "  "))
	f.close()
	print("asset views: ", found.size(), " placed, ", picked.size(), " captured")
	quit()


## What `node` draws, in the world: the bounds of its meshes.
func _bounds(node: Node3D) -> AABB:
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	var box := AABB(node.global_position, Vector3.ZERO)
	var first := true
	for mi in meshes:
		if mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _to_tick(t: int) -> void:
	while main.driver.world.tick() < t:
		main.driver.step_once()
	for f in 5:
		main._process(1.0 / 60.0)
		await process_frame


func _frames(n: int) -> void:
	for f in n:
		main._process(1.0 / 60.0)
		await process_frame
	await RenderingServer.frame_post_draw


func _save(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out + name + ".png")


func _view(name: String, from: Vector3, to: Vector3, fov: float, node: Node3D) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	main.host.pack.add_child(cam)
	cam.global_position = from
	cam.look_at(to)
	if main.host.pack.has_method("_style_node") and main.host.pack.get_script().resource_path.contains("anime"):
		Toon.line_pass(cam)
	var was := root.get_viewport().get_camera_3d()
	cam.make_current()
	await _frames(40)
	_save(name)
	# The measuring passes: no tone curve, haze or glow, so an unlit colour
	# comes out as it is.
	var env: Environment = main.host.pack.env
	var saved := [env.tonemap_mode, env.tonemap_exposure, env.fog_enabled, env.glow_enabled, env.adjustment_enabled]
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_enabled = false
	env.glow_enabled = false
	env.adjustment_enabled = false
	for kind_of in ["mask", "kind", "albedo"]:
		var undo := _override(node, kind_of)
		await _frames(6)
		_save(name + "-" + kind_of)
		for u in undo:
			u[0].set_surface_override_material(u[1], u[2])
	env.tonemap_mode = saved[0]
	env.tonemap_exposure = saved[1]
	env.fog_enabled = saved[2]
	env.glow_enabled = saved[3]
	env.adjustment_enabled = saved[4]
	if was != null:
		was.make_current()
	cam.queue_free()


## Draws `node`'s meshes for a measuring pass; returns what to put back:
## [[mesh instance, surface, its override before]].
func _override(node: Node3D, kind_of: String) -> Array:
	var undo := []
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mi in meshes:
		if str(mi.name).begins_with("light") or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			undo.append([mi, s, mi.get_surface_override_material(s)])
			var m: Material
			if kind_of == "mask":
				var flat := StandardMaterial3D.new()
				flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				flat.albedo_color = Color(1, 0, 1)
				m = flat
			elif kind_of == "kind":
				var sm := ShaderMaterial.new()
				var sh := Shader.new()
				sh.code = KIND_SHADER_UV2 if (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_TEX_UV2) != 0 else KIND_SHADER
				sm.shader = sh
				m = sm
			else:
				var own: Material = mi.get_active_material(s)
				if own is BaseMaterial3D:
					var unlit: BaseMaterial3D = own.duplicate()
					unlit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					unlit.next_pass = null
					unlit.emission_enabled = false
					m = unlit
				else:
					m = own
			mi.set_surface_override_material(s, m)
	return undo
