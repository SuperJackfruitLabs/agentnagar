## Door captures (spike, not production; needs a display): each style's
## drawn building doors with the core's walkable door span overlaid (red
## squares: the 25 cm cells of the span; a step between rooms must go
## straight across, between two of them). Written as PNGs under `out`.
##
## godot --path city/godot --script res://tools/probes/capture_doors.gd -- out=/home/me/captures styles=lowpoly_tropical,pixel_art
extends SceneTree

var opts := {"out": "", "styles": "lowpoly_tropical,anime_cel,neon_noir,solarpunk,voxel,pixel_art",
	"doors": "door:workshop-plaza,door:reading-plaza"}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			opts[kv[0]] = kv[1]
	await process_frame
	DirAccess.make_dir_recursive_absolute(opts["out"])
	for style in opts["styles"].split(","):
		var main = load("res://main.gd").new()
		root.add_child(main)
		main.boot_for_tool(PackedStringArray(["--crowd=0", "--as=none", "--no-hud", "--style=" + style]))
		for i in 5:
			await process_frame
		var pack = main.host.pack
		var nav: NavQuery = main.nav
		for d in _doors(main.manifest):
			if not (d["id"] in opts["doors"].split(",")):
				continue
			var marks := []
			for c in _span(nav, d["pos"]):
				marks.append(_mark(pack, nav.centre(c)))
			var p: Vector2 = d["pos"] / 100.0
			var inward: Vector2 = d["inward"]
			if pack.get("rig") != null:
				var rig: OrbitRig = pack.rig
				rig.position = Vector3(p.x, 0, p.y)
				rig.yaw = FpvCamera.yaw_along(inward) + 20.0
				rig.pitch = -28.0
				rig.distance = 9.0
				rig.update()
			else:
				# A 2D style sees only the south and east faces from outside:
				# a door on a room's west or north side is seen from inside,
				# with the buildings cut away.
				var far := inward.x > 0.0 or inward.y > 0.0
				main.host.open_all = far
				main.host.set_roofs_on(not far)
				pack.camera.global_position = pack.world.to_global(pack.iso(p.x, p.y))
				pack.camera.zoom = Vector2(4, 4)
			for i in 12:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_viewport().get_texture().get_image()
			var path: String = opts["out"].path_join("%s_%s.png" % [style, str(d["id"]).trim_prefix("door:")])
			img.save_png(path)
			print("captured ", path)
			for m in marks:
				m.queue_free()
		main.queue_free()
		for i in 3:
			await process_frame
	quit(0)


func _doors(manifest: Dictionary) -> Array:
	var out := []
	for dist in manifest["city"]["districts"]:
		for f in dist["facilities"]:
			for r in f["rooms"]:
				var rc = r.get("rect")
				if rc == null:
					continue
				for door in r.get("doors", []):
					if door.get("pos") == null:
						continue
					var p := Vector2(door["pos"]["x"], door["pos"]["z"])
					var inward := Vector2(1, 0) if int(p.x) == int(rc["x"]) else (Vector2(-1, 0) if int(p.x) == int(rc["x"]) + int(rc["w"]) else (Vector2(0, 1) if int(p.y) == int(rc["z"]) else Vector2(0, -1)))
					out.append({"id": door["id"], "pos": p, "inward": inward})
	return out


func _span(nav: NavQuery, p: Vector2) -> Array:
	var out := []
	var c0 := nav.cell_of(p)
	# The span is the door's width along the wall and two cells deep
	# either side (spec §3): 200 cm doors reach five cells from the middle.
	for dj in range(-5, 6):
		for di in range(-5, 6):
			var c := c0 + Vector2i(di, dj)
			if nav.in_door_span(c) and nav.centre(c).distance_to(p) < 150:
				out.append(c)
	return out


func _mark(pack, cm: Vector2) -> Node:
	var m := cm / 100.0
	if pack.get("rig") != null:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.21, 0.03, 0.21)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0, 0)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		box.material = mat
		mi.mesh = box
		mi.position = Vector3(m.x, 0.05, m.y)
		pack.world.add_child(mi)
		return mi
	var poly := Polygon2D.new()
	var h := 0.105
	poly.polygon = PackedVector2Array([pack.iso(m.x - h, m.y - h), pack.iso(m.x + h, m.y - h), pack.iso(m.x + h, m.y + h), pack.iso(m.x - h, m.y + h)])
	poly.color = Color(1, 0, 0, 0.85)
	poly.z_index = 4000
	pack.world.add_child(poly)
	return poly
