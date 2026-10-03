extends SceneTree
## Close views of one placed asset, for setting it beside its concept sheet
## and for measuring it. A pilot tool: asset_try.sh copies it into the
## working copy of the client (city/godot/tools/); it is not part of the client.
##   godot --path godot --resolution 1920x1080 --script res://tools/asset_views.gd -- STYLE NEEDLE [COUNT] [FRAME]
##   godot ... --script res://tools/asset_views.gd -- STYLE NEEDLE@KEY[:FRAME[:COUNT]],NEEDLE@KEY...
## The second form (this record's addition) takes several pieces in one start
## of the game, which is most of what a capture costs: each piece's views and
## its asset-views.json go into a folder KEY under the style's.
## Finds the placed pieces whose scene file's name contains NEEDLE (for
## example seat_bench_v2), or is NEEDLE when it is written with `=` before it
## (`=bench.glb` is the voxel kit's bench and not its workbench.glb: the one
## difference from the asset-to-sheet pilot's script of the same name, which
## setup.sh puts this one in the place of), takes up to COUNT of them that stand at different
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
## (a meadow's clumps, shrubs) have no scene of their own and are not found.
## Pieces the game puts inside a holder (a fountain's body, the perch seats
## at a wall's places to sit) are found: this record's second addition.
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
	var base := OS.get_environment("HOME") + "/.cache/agentnagar-sheets/%s/" % style
	# The pieces to take: [needle, folder under the style's, frame, count].
	var jobs := []
	if args[1].contains("@"):
		for job in args[1].split(","):
			var parts: PackedStringArray = job.split("@")
			var rest: PackedStringArray = parts[1].split(":")
			jobs.append([parts[0], rest[0] + "/", rest[1] if rest.size() > 1 else "prop", int(rest[2]) if rest.size() > 2 else 3])
	else:
		jobs.append([args[1], "", args[3] if args.size() > 3 else "prop", int(args[2]) if args.size() > 2 else 3])
	main = load("res://main.gd").new()
	root.add_child(main)
	main.boot_for_tool(PackedStringArray(["--crowd=60", "--style=" + style, "--as=none"]))
	main.driver.pause()
	main.hud.visible = false
	var pack = main.host.pack
	var night_first: bool = pack.style.get("sheet_night", false)
	await _to_tick(370 if night_first else 150)
	var placed_in_all := 0
	var captured_in_all := 0
	for job in jobs:
		out = base + job[1]
		DirAccess.make_dir_recursive_absolute(out)
		var took: Array = await _piece(pack, job[0], job[3], job[2])
		placed_in_all += took[0]
		captured_in_all += took[1]
		if jobs.size() > 1:
			print("  ", job[1], " ", job[0], ": ", took[0], " placed, ", took[1], " captured")
	print("asset views: ", placed_in_all, " placed, ", captured_in_all, " captured")
	quit()


## One piece's views: returns [how many are placed, how many were captured].
func _piece(pack, needle: String, count: int, frame: String) -> Array:
	# The placed pieces drawn from that scene, each once.
	var found := []
	var whole := needle.begins_with("=")
	var want := needle.substr(1) if whole else needle
	# A placement's node is the piece itself, or a holder with the piece and the seats the game stands at its
	# places to sit as its children (a fountain, a shelter, a flowerbed, steps): both are looked through.
	for top in pack.placement_nodes.values():
		if not (top is Node3D):
			continue
		var nodes: Array = [top]
		nodes.append_array(top.find_children("*", "Node3D", true, false))
		for node in nodes:
			if found.has(node) or str(node.scene_file_path) == "":
				continue
			var file := str(node.scene_file_path).get_file()
			if (file == want) if whole else file.contains(want):
				found.append(node)
	# A piece the game plants as copies of one mesh has no scene to find: its copies are looked for instead.
	if found.is_empty() and "_planted" in pack:
		return await _planted_piece(pack, needle, whole, want, count)
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
		if frame == "auto" or frame == "open" or frame.begins_with("box="):
			# Stand back by the piece's size: from eye height, and from 40 degrees up. `auto` takes the size
			# from what this piece draws, so two pieces of different size on one point get different cameras;
			# `box=W,H,D` (metres, standing on the piece's point) gives every piece put there the same camera.
			# `open` is `auto` from the side most of the piece shows from (eight are tried, by its mask): a
			# table on a terrace has a wall behind it and an umbrella over it.
			var centre := box.get_center()
			var size := box.size
			if frame.begins_with("box="):
				var given := frame.substr(4).split_floats("x")
				size = Vector3(given[0], given[1], given[2])
				centre = Vector3(at.x, at.y + size.y * 0.5, at.z)
			var reach := size.length() * 0.5 / tan(deg_to_rad(38.0) * 0.5) * 1.1
			var toward := (front * 2.4 + right * 1.5).normalized()
			var level := sqrt(maxf(reach * reach - pow(centre.y - 1.6, 2.0), reach * reach * 0.25))
			if frame == "open":
				var best := -1.0
				for step in 8:
					var dir := Vector3(sin(step * PI / 4.0), 0, cos(step * PI / 4.0))
					var share: float = await _shows(Vector3(centre.x, 1.6, centre.z) + dir * level, centre, 38.0, node)
					if share > best:
						best = share
						toward = dir
			await _view("asset-eye-%d" % k, Vector3(centre.x, 1.6, centre.z) + toward * level, centre, 38.0, node)
			await _view("asset-above-%d" % k, centre + toward * reach * cos(deg_to_rad(40.0)) + Vector3.UP * reach * sin(deg_to_rad(40.0)), centre, 38.0, node)
		else:
			await _view("asset-eye-%d" % k, at + front * 2.4 + right * 1.5 + Vector3(0, 1.45, 0), at + Vector3(0, 0.45, 0), 38.0, node)
			# Low enough to stay under a tree's crown (leaves start above the walking band).
			await _view("asset-above-%d" % k, at + front * 2.1 + right * 1.2 + Vector3(0, 2.7, 0), at + Vector3(0, 0.35, 0), 38.0, node)
		record.append({"at": [at.x, at.y, at.z], "turn_degrees": picked[k]["turn"], "in_use": picked[k]["busy"],
			"scale": [node.global_transform.basis.get_scale().x, node.global_transform.basis.get_scale().y, node.global_transform.basis.get_scale().z], "scene": str(node.scene_file_path),
			"size": [box.size.x, box.size.y, box.size.z], "frame": frame})
	var f := FileAccess.open(out + "asset-views.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"needle": needle, "placed": found.size(), "views": record}, "  "))
	f.close()
	return [found.size(), picked.size()]


## A piece the game plants as copies of one mesh (a street tree, a palm, a shrub): up to `count` of its copies,
## those nearest the middle of the town, each framed by its own size from the side the middle is on. In the
## measuring passes the other copies of its chunk are hidden, so the mask shows the one copy.
func _planted_piece(pack, needle: String, whole: bool, want: String, count: int) -> Array:
	var copies := []
	for path in pack._planted:
		var file := str(path).get_file()
		if not ((file == want) if whole else file.contains(want)):
			continue
		var holder: Node3D = pack._planted[path]
		var chunks: Array = [holder] if holder is MultiMeshInstance3D else holder.find_children("*", "MultiMeshInstance3D", true, false)
		for chunk in chunks:
			var xforms: Array = chunk.get_meta("instance_xforms", [])
			for k in xforms.size():
				copies.append({"chunk": chunk, "k": k, "xform": chunk.global_transform * xforms[k], "path": str(path)})
	if copies.is_empty():
		return [0, 0]
	copies.sort_custom(func(a, b): return Vector2(a["xform"].origin.x, a["xform"].origin.z).length() < Vector2(b["xform"].origin.x, b["xform"].origin.z).length())
	var record := []
	var taken := 0
	var tried := 0
	for c in copies:
		if taken >= count or tried >= 24:
			break
		tried += 1
		var x: Transform3D = c["xform"]
		var box: AABB = x * c["chunk"].multimesh.mesh.get_aabb()
		var centre := box.get_center()
		var reach := box.size.length() * 0.5 / tan(deg_to_rad(38.0) * 0.5) * 1.1
		var level := sqrt(maxf(reach * reach - pow(centre.y - 1.6, 2.0), reach * reach * 0.25))
		# From which side: a copy can stand behind a building, or the camera in one. The side from which most
		# of the copy shows at eye height is taken (eight are tried, by the mask alone); a copy that shows on
		# less than a two-hundred-and-fiftieth of the frame from every side is passed over (hidden behind a
		# building; a kit's palm, a thin trunk under a few fronds, fills well under a fiftieth when it is in
		# plain view, and at that limit none was captured).
		var toward := Vector3(0, 0, 1)
		var best := 0.0
		for step in 8:
			var dir := Vector3(sin(step * PI / 4.0), 0, cos(step * PI / 4.0))
			var share: float = await _shows(Vector3(centre.x, 1.6, centre.z) + dir * level, centre, 38.0, c)
			if share > best:
				best = share
				toward = dir
		if best < 0.004:
			continue
		await _view("asset-eye-%d" % taken, Vector3(centre.x, 1.6, centre.z) + toward * level, centre, 38.0, c)
		await _view("asset-above-%d" % taken, centre + toward * reach * cos(deg_to_rad(40.0)) + Vector3.UP * reach * sin(deg_to_rad(40.0)), centre, 38.0, c)
		var sc := x.basis.get_scale()
		record.append({"at": [x.origin.x, x.origin.y, x.origin.z], "turn_degrees": 0, "in_use": false, "scale": [sc.x, sc.y, sc.z], "scene": c["path"],
			"size": [box.size.x, box.size.y, box.size.z], "frame": "auto", "planted": true})
		taken += 1
	var f := FileAccess.open(out + "asset-views.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"needle": needle, "placed": copies.size(), "views": record}, "  "))
	f.close()
	return [copies.size(), taken]


## The share of the frame one copy of a planted piece fills, seen from `from`: its mask, a few frames, read
## back small.
func _shows(from: Vector3, to: Vector3, fov: float, node) -> float:
	var cam := Camera3D.new()
	cam.fov = fov
	main.host.pack.add_child(cam)
	cam.global_position = from
	cam.look_at(to)
	var was := root.get_viewport().get_camera_3d()
	cam.make_current()
	var undo := _override(node, "mask")
	await _frames(3)
	var image: Image = root.get_viewport().get_texture().get_image()
	for u in undo:
		if u is Callable:
			u.call()
		else:
			u[0].set_surface_override_material(u[1], u[2])
	if was != null:
		was.make_current()
	cam.queue_free()
	image.resize(160, 90, Image.INTERPOLATE_NEAREST)
	var hits := 0
	for y in 90:
		for x in 160:
			var c: Color = image.get_pixel(x, y)
			if c.r > 0.85 and c.g < 0.2 and c.b > 0.85:
				hits += 1
	return hits / 14400.0


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


func _view(name: String, from: Vector3, to: Vector3, fov: float, node) -> void:
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
			if u is Callable:
				u.call()
			else:
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
func _override(node, kind_of: String) -> Array:
	var undo := []
	if node is Dictionary:
		# One copy of a planted piece: the chunk's other copies are shrunk to nothing for the pass, and the
		# chunk takes one material for the mask or the kind pass; for the albedo pass its mesh's own
		# materials are swapped for unlit copies. Everything is put back by the calls returned.
		var chunk: MultiMeshInstance3D = node["chunk"]
		var mm: MultiMesh = chunk.multimesh
		var kept := []
		for k in mm.instance_count:
			kept.append(mm.get_instance_transform(k))
			if k != node["k"]:
				mm.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(0.0001, 0.0001, 0.0001)), kept[k].origin + Vector3(0, -50, 0)))
		undo.append(func():
			for k in kept.size():
				mm.set_instance_transform(k, kept[k]))
		if kind_of == "albedo":
			for s in mm.mesh.get_surface_count():
				var own: Material = mm.mesh.surface_get_material(s)
				if own is BaseMaterial3D:
					var unlit: BaseMaterial3D = own.duplicate()
					unlit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					unlit.next_pass = null
					unlit.emission_enabled = false
					mm.mesh.surface_set_material(s, unlit)
					undo.append(func(): mm.mesh.surface_set_material(s, own))
		else:
			var was: Material = chunk.material_override
			if kind_of == "mask":
				var flat := StandardMaterial3D.new()
				flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				flat.albedo_color = Color(1, 0, 1)
				chunk.material_override = flat
			else:
				var sm := ShaderMaterial.new()
				var sh := Shader.new()
				sh.code = KIND_SHADER
				sm.shader = sh
				chunk.material_override = sm
			undo.append(func(): chunk.material_override = was)
		return undo
	var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
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
