## Door-gap probe (spike, not production): measures, per 3D style, the
## opening each building door is drawn with, from the shell's own mesh
## triangles, and compares it with the core's walkable door span (1 m:
## four 25 cm cells either side of the door's position).
##
## For each opening it slices every triangle of the side's façade at a
## few heights, keeps the pieces within the wall's thickness band, and
## finds the clear interval around the door's position: once counting
## every mesh (what you see: leaves, glass, frames), once without pieces
## named door/entrance (the structural jambs only), and once without any
## surface that is glass or a door leaf (by material name).
##
## godot --headless --path city/godot --script res://tools/probes/door_gap_probe.gd -- styles=lowpoly_tropical,anime_cel
extends SceneTree

var opts := {"styles": "lowpoly_tropical,anime_cel,neon_noir,solarpunk,voxel", "band": "0.8"}
const HEIGHTS := [0.3, 1.0, 1.7]


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			opts[kv[0]] = kv[1]
	await process_frame
	for style in opts["styles"].split(","):
		var main = load("res://main.gd").new()
		root.add_child(main)
		main.boot_for_tool(PackedStringArray(["--crowd=0", "--as=none", "--style=" + style]))
		await process_frame
		var pack = main.host.pack
		for b in CityGeometry.buildings(main.manifest, StylePack.kinds()):
			if not pack.shells.has(b["id"]):
				print("GAP %s %s no shell" % [style, b["id"]])
				continue
			var shell: Dictionary = pack.shells[b["id"]]
			for s in b["sides"]:
				for t in s["openings"]:
					_measure(style, b["id"], s, float(t), shell["sides"][s["side"]]["full"])
		# Interior partitions (drawn by pack_3d's _walls as boxes): the
		# walls list the eye keeps clear of has their solid runs.
		if "walls" in pack:
			for w in pack.walls:
				var a: Vector2 = w["a"]
				var bb: Vector2 = w["b"]
				if absf(a.y - 2.0) < 0.01 and absf(bb.y - 2.0) < 0.01:
					print("WALLRUN %s z=2 partition run x %.2f..%.2f" % [style, minf(a.x, bb.x), maxf(a.x, bb.x)])
		main.free()
		await process_frame
	quit(0)


func _measure(style: String, building: String, side: Dictionary, t: float, full: Node3D) -> void:
	var a: Vector2 = side["a"]
	var along: Vector2 = (side["b"] - a).normalized()
	var normal: Vector2 = side["normal"]
	var band := float(opts["band"])
	var out := []
	var blockers := {}
	for mode in ["all", "no_door_pieces", "no_glass_or_leaf"]:
		var per_h := []
		for h in HEIGHTS:
			var cover := []
			var pieces := {}
			for mi in full.find_children("*", "MeshInstance3D", true, false):
				var piece := _piece_name(mi, full)
				if mode == "no_door_pieces" and ("door" in piece or "entrance" in piece):
					continue
				var xf: Transform3D = mi.global_transform
				var mesh: Mesh = mi.mesh
				if mesh == null:
					continue
				for si in mesh.get_surface_count():
					var mat = mi.get_active_material(si)
					var mname := str(mat.resource_name) if mat != null else ""
					if mode == "no_glass_or_leaf" and (mname.begins_with("glass") or "door" in mname or "leaf" in mname):
						continue
					var arr := mesh.surface_get_arrays(si)
					var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					var idx = arr[Mesh.ARRAY_INDEX]
					var n: int = idx.size() if idx != null and idx.size() > 0 else v.size()
					for k in range(0, n - 2, 3):
						var p0: Vector3 = xf * v[idx[k] if idx != null and idx.size() > 0 else k]
						var p1: Vector3 = xf * v[idx[k + 1] if idx != null and idx.size() > 0 else k + 1]
						var p2: Vector3 = xf * v[idx[k + 2] if idx != null and idx.size() > 0 else k + 2]
						var seg := _slice([p0, p1, p2], h)
						if seg.is_empty():
							continue
						var ts := []
						var ok := false
						for q in seg:
							var g := Vector2(q.x, q.z) - a
							var dn := g.dot(normal)
							if absf(dn) <= band:
								ok = true
							ts.append(g.dot(along))
						if ok and absf((ts[0] + ts[1]) / 2.0 - t) < 4.0:
							cover.append([minf(ts[0], ts[1]), maxf(ts[0], ts[1])])
							if minf(ts[0], ts[1]) <= t and maxf(ts[0], ts[1]) >= t and maxf(ts[0], ts[1]) - minf(ts[0], ts[1]) > 0.005:
								pieces[piece + "/" + mname] = true
			per_h.append(_gap(cover, t))
			if not pieces.is_empty() and h == 1.0:
				blockers[mode] = pieces.keys()
		out.append("%s: %s" % [mode, ", ".join(per_h.map(func(g): return "%.2f..%.2f (%.2f m)" % [g[0] - t, g[1] - t, g[1] - g[0]]))])
	if not blockers.is_empty():
		print("BLOCKERS %s %s %s at the door centre, 1.0 m up: %s" % [style, building, side["side"], blockers])
	print("GAP %s %s %s opening@%.2f  core walkable -0.50..0.50 (1.00 m), cell centres -0.375..0.375 | heights %s | %s" % [
		style, building, side["side"], t, HEIGHTS, " | ".join(out)])


static func _piece_name(mi: Node, stop: Node) -> String:
	var n := mi
	while n != null and n.get_parent() != stop:
		n = n.get_parent()
	return str(n.get_meta("piece", n.name)) if n != null else str(mi.name)


## The segment where a triangle crosses the plane y = h, or [].
static func _slice(tri: Array, h: float) -> Array:
	var pts := []
	for k in 3:
		var p: Vector3 = tri[k]
		var q: Vector3 = tri[(k + 1) % 3]
		if (p.y - h) * (q.y - h) < 0.0:
			var f := (h - p.y) / (q.y - p.y)
			pts.append(p.lerp(q, f))
	return pts if pts.size() == 2 else []


## The clear interval around `t` left by `cover` (intervals along the
## side), clipped to ±3 m.
static func _gap(cover: Array, t: float) -> Array:
	var lo := t - 3.0
	var hi := t + 3.0
	for c in cover:
		if c[1] - c[0] < 0.005:
			continue
		if c[0] <= t and c[1] >= t:
			return [t, t]
		if c[1] <= t:
			lo = maxf(lo, c[1])
		elif c[0] >= t:
			hi = minf(hi, c[0])
	return [lo, hi]
