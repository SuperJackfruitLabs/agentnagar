## Assembles a style's kit (GLBs made by city/tools/styles/<style>) into
## buildings and scenery: single pieces turned to face a side, many copies
## of a piece as one MultiMesh, and the bays along a side with a door bay
## on each opening. Collects the kit's glass and lamp materials so night can
## light them. A pack's townscape extends this with its own assembly.
extends RefCounted
class_name KitTown

## The river surface's height; the riverbed, quays and moored boats follow it.
var water_y := -0.55
var pal := {}
## Loads a kit GLB (a path under the pack) as a new node; set by the pack.
var load_scene: Callable
## Where kit pieces named without a folder live, under the pack.
var prefix := "assets/"
## Every material that glows at night: window glass and lamps.
var glass_materials: Array[BaseMaterial3D] = []
var lamp_materials: Array[BaseMaterial3D] = []
## Neon tubes (a kit's `neon_*` colours), which a style lights by night.
var neon_materials: Array[BaseMaterial3D] = []
var _meshes := {}


func _init(palette: Dictionary, loader: Callable, kit_prefix := "assets/") -> void:
	pal = palette
	load_scene = loader
	prefix = kit_prefix


func c(key: String, fallback := "#FF00FF") -> Color:
	return Color.html(str(pal.get(key, fallback)))


func mat(key: String, roughness := 0.85) -> StandardMaterial3D:
	return MeshBatch.material(c(key), roughness)


static func _hash01(s: String) -> float:
	return float(hash(s) % 1000) / 1000.0


## Turns local -Z (a module's front) toward the ground normal n.
static func yaw_to(n: Vector2) -> float:
	return atan2(-n.x, -n.y)


## The pack path of a kit piece: a bare name lives under `prefix`.
func path_of(name_: String) -> String:
	return name_ if "/" in name_ else "%s%s.glb" % [prefix, name_]


# ---- Kit pieces ----

## A kit piece at ground position `at` (metres), front turned to `facing`.
func piece(parent: Node3D, name_: String, at: Vector3, facing := Vector2(0, -1), stretch := Vector3.ONE) -> Node3D:
	var n: Node3D = load_scene.call(path_of(name_))
	n.set_meta("piece", name_)
	n.position = at
	n.rotation.y = yaw_to(facing)
	n.scale = stretch
	parent.add_child(n)
	_collect(n)
	return n


## Where a piece's `light` part glows, in its parent's space (the middle of
## its mesh, or 3 m up without one).
static func light_point(n: Node3D) -> Vector3:
	var l = n.find_child("light", true, false)
	var at := Vector3(0, 3.0, 0)
	if l is MeshInstance3D:
		at = l.transform * l.get_aabb().get_center()
		var p: Node = l.get_parent()
		while p != null and p != n:
			at = p.transform * at
			p = p.get_parent()
	return n.transform * at


## The mesh inside a kit piece, for tiling it with a MultiMesh.
func mesh_of(name_: String) -> Mesh:
	if not _meshes.has(name_):
		var n: Node3D = load_scene.call(path_of(name_))
		var mi = n.find_children("*", "MeshInstance3D", true, false)
		if n is MeshInstance3D:
			mi.push_front(n)
		_meshes[name_] = mi[0].mesh if not mi.is_empty() else BoxMesh.new()
		for m in mi:
			_collect(m)
		n.free()
	return _meshes[name_]


## Tiled pieces are split into chunks this many metres a side, so the
## renderer culls each on its own (off screen, outside a shadow split)
## instead of drawing the whole district's planting in every pass.
const CHUNK_M := 32.0


## Many copies of one kit piece: one MultiMeshInstance3D when they fit in
## one chunk, else a node of them, one per chunk, all named `node_name`'s.
## Copies that are placements carry their IDs (`ids`, one per transform),
## which each MultiMesh keeps in its instances' order as its
## `placement_ids`. Copies that sway (a soft kind's: a meadow's clumps)
## carry `custom_data`, a push for the sway shader per instance (see
## SoftContacts); nothing else pays for it.
func tiles(name_: String, xforms: Array, node_name: String, shadows := false, ids := PackedStringArray(), custom_data := false) -> Node3D:
	var cells := {}
	for k in xforms.size():
		var x: Transform3D = xforms[k]
		var key := Vector2i(floori(x.origin.x / CHUNK_M), floori(x.origin.z / CHUNK_M))
		if not cells.has(key):
			cells[key] = {"xforms": [], "ids": PackedStringArray()}
		cells[key]["xforms"].append(x)
		if not ids.is_empty():
			cells[key]["ids"].append(ids[k])
	if cells.size() <= 1:
		return _multimesh(name_, xforms, node_name, shadows, ids, custom_data)
	var root := Node3D.new()
	root.name = node_name
	var keys := cells.keys()
	keys.sort()
	for key in keys:
		root.add_child(_multimesh(name_, cells[key]["xforms"], "%s_%d_%d" % [node_name, key.x, key.y], shadows, cells[key]["ids"], custom_data))
	return root


func _multimesh(name_: String, xforms: Array, node_name: String, shadows: bool, ids := PackedStringArray(), custom_data := false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# Before the count: the buffer is laid out when the count is set.
	mm.use_custom_data = custom_data
	mm.mesh = mesh_of(name_)
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	# Where its pieces stand on average (a MultiMesh's own bounds are only
	# known to a rendering server, not headless).
	var centre := Vector3.ZERO
	for x in xforms:
		centre += x.origin
	mmi.set_meta("centre", centre / maxf(1.0, xforms.size()))
	# And each piece's transform, in instance order: a headless rendering
	# server keeps none of them, and the collision audit reads them there.
	mmi.set_meta("instance_xforms", xforms.duplicate())
	if not ids.is_empty():
		mmi.set_meta("placement_ids", ids)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


## Registers the kit's glass, lamp and neon materials so night can light
## them.
func _collect(n: Node) -> void:
	var meshes: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	for mi in meshes:
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m = mi.mesh.surface_get_material(s)
			if not (m is BaseMaterial3D):
				continue
			var rn: String = m.resource_name
			if rn.begins_with("glass") and not glass_materials.has(m):
				m.emission_enabled = true
				m.emission = c("glass_glow", "#FFC47A")
				m.emission_energy_multiplier = 0.0
				glass_materials.append(m)
			elif (rn == "lamp_glow" or rn == "window_glow" or rn == "fairy_glow" or rn == "light") and not lamp_materials.has(m):
				lamp_materials.append(m)
			elif rn.begins_with("neon") and not neon_materials.has(m):
				neon_materials.append(m)


## Bays along a side: [{"t0", "t1", "door"}], a door bay centred on each
## opening, as wide as its door (`widths`, metres, one per opening), and
## the rest filled with bays of about `bay` metres.
static func bays(length: float, openings: Array, bay: float, widths: Array) -> Array:
	var out := []
	var cursor := 0.0
	var marks := []
	for k in openings.size():
		marks.append([openings[k], widths[k]])
	marks.sort()
	for o in marks:
		var d0: float = clampf(o[0] - o[1] / 2.0, cursor, length)
		_fill(out, cursor, d0, bay)
		var d1: float = minf(o[0] + o[1] / 2.0, length)
		out.append({"t0": d0, "t1": d1, "door": true})
		cursor = d1
	_fill(out, cursor, length, bay)
	return out


static func _fill(out: Array, t0: float, t1: float, bay: float) -> void:
	var span := t1 - t0
	if span < 0.05:
		return
	var n := maxi(1, int(round(span / bay)))
	for k in n:
		out.append({"t0": t0 + span * k / n, "t1": t0 + span * (k + 1) / n, "door": false})


# ---- Fitting pieces to their footprints ----

## The heights a piece is measured over for the walking band (spec §7:
## 0.25-1.9 m above the ground), with a margin either side: the ground a
## piece stands on is drawn a little above or below its feet.
const BAND_MEASURE := Vector2(0.15, 2.2)
var _band_boxes := {}
var _band_reaches := {}
## What a leaf surface's material is called in the kits (as the collision
## audit reads them, tools/collision_audit/solids_3d.gd).
const LEAF := "leaf|leaves|foliage|frond"


## What kit piece `name_` draws in the walking band, flattened: the (x, z)
## bounds, in its own frame, of its faces cut to BAND_MEASURE.
func band_box(name_: String) -> Rect2:
	if not _band_boxes.has(name_):
		var n: Node3D = load_scene.call(path_of(name_))
		_band_boxes[name_] = band_box_of(n)
		n.free()
	return _band_boxes[name_]


## How far from its origin kit piece `name_` draws in the walking band
## (BAND_MEASURE), in its own frame: the radius of the disc its band slice
## fits, which a planted piece is drawn to fill (a trunk, a bush). With
## `trunk`, its leaves are left out, as the collision audit leaves out a
## tree's: a trunk is what stands where people walk.
func band_reach(name_: String, trunk := false) -> float:
	var key := "%s|%s" % [name_, trunk]
	if not _band_reaches.has(key):
		var n: Node3D = load_scene.call(path_of(name_))
		var reach := 0.0
		for p in band_points_of(n, BAND_MEASURE, trunk):
			reach = maxf(reach, p.length())
		_band_reaches[key] = reach
		n.free()
	return _band_reaches[key]


## The walking-band bounds of everything `root` draws, in its own frame
## (see band_box); an empty Rect2 with no face in the band.
static func band_box_of(root: Node3D, band := BAND_MEASURE) -> Rect2:
	var points := band_points_of(root, band)
	var box := Rect2(points[0], Vector2.ZERO) if not points.is_empty() else Rect2()
	for p in points:
		box = box.expand(p)
	return box


## The (x, z) points, in `root`'s frame, of its visible faces cut to heights
## band.x to band.y (see _band_points), without its leaves' (LEAF) when
## `leafless`.
static func band_points_of(root: Node3D, band := BAND_MEASURE, leafless := false) -> PackedVector2Array:
	var leaf := RegEx.create_from_string(LEAF)
	var out := PackedVector2Array()
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.push_front(root)
	for mi in meshes:
		if mi.mesh == null or not mi.visible:
			continue
		var xf := Transform3D()
		var n: Node = mi
		while n != root and n is Node3D:
			xf = n.transform * xf
			n = n.get_parent()
		for s in mi.mesh.get_surface_count():
			var material: Material = mi.mesh.surface_get_material(s)
			if leafless and material != null and leaf.search(material.resource_name.to_lower()) != null:
				continue
			out.append_array(_band_points(xf * _surface_triangles(mi.mesh, s), band))
	return out


static func _surface_triangles(mesh: Mesh, s: int) -> PackedVector3Array:
	var arrays := mesh.surface_get_arrays(s)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx = arrays[Mesh.ARRAY_INDEX]
	if not (idx is PackedInt32Array and idx.size() > 0):
		return v
	var out := PackedVector3Array()
	out.resize(idx.size())
	for k in idx.size():
		out[k] = v[idx[k]]
	return out


## The (x, z) points of triangle soup `verts` that lie between band.x and
## band.y: vertices inside it and where edges cross its two heights.
static func _band_points(verts: PackedVector3Array, band: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for t in verts.size() / 3:
		var tri := [verts[t * 3], verts[t * 3 + 1], verts[t * 3 + 2]]
		for k in 3:
			var p: Vector3 = tri[k]
			var q: Vector3 = tri[(k + 1) % 3]
			if p.y >= band.x and p.y <= band.y:
				out.append(Vector2(p.x, p.z))
			if p.y == q.y:
				continue
			for level in [band.x, band.y]:
				var f: float = (level - p.y) / (q.y - p.y)
				if f > 0.0 and f < 1.0:
					var m := p.lerp(q, f)
					out.append(Vector2(m.x, m.z))
	return out


## How near its middle (z = 0) kit piece `name_`'s faces between heights
## band.x and band.y come, across its z: the clear half-width a bridge
## span's parapets leave; 0 when something crosses the middle.
func clear_half_width(name_: String, band: Vector2) -> float:
	var n: Node3D = load_scene.call(path_of(name_))
	var inner := INF
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var xf := Transform3D()
		var node: Node = mi
		while node != n and node is Node3D:
			xf = node.transform * xf
			node = node.get_parent()
		for s in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = xf * _surface_triangles(mi.mesh, s)
			for t in verts.size() / 3:
				var pts := _band_points(verts.slice(t * 3, t * 3 + 3), band)
				if pts.is_empty():
					continue
				var z0 := INF
				var z1 := -INF
				for p in pts:
					z0 = minf(z0, p.y)
					z1 = maxf(z1, p.y)
				inner = minf(inner, 0.0 if z0 < 0.0 and z1 > 0.0 else minf(absf(z0), absf(z1)))
	n.free()
	return inner


## Kit piece `name_` along a building's side: its band slice spanning
## [u0, u1] along the side (from `origin`, along `along`) and [v0, v1] out
## from it (along `normal`, which the piece's front faces), whatever the
## piece's own proportions. With `nominal` > 0 the piece is stretched along
## by (u1 - u0) / nominal about the middle instead: a bay keeps its trim at
## its ends whatever its band slice spans. With `depth_of`, the piece is
## fitted across as that piece is: a door bay, with nothing in the band,
## keeps in line with the wall bays beside it.
func fitted(parent: Node3D, name_: String, origin: Vector2, along: Vector2, normal: Vector2,
		u0: float, u1: float, v0: float, v1: float, nominal := 0.0, depth_of := "") -> Node3D:
	var box := band_box(name_)
	if depth_of != "":
		var like := band_box(depth_of)
		box = Rect2(box.position.x, like.position.y, box.size.x, like.size.y)
	var sx := (u1 - u0) / nominal if nominal > 0.0 else (u1 - u0) / maxf(box.size.x, 1e-3)
	# A piece with nothing in the band keeps its own depth.
	var sz := (v1 - v0) / box.size.y if box.size.y > 1e-3 else 1.0
	# The piece's front (-z) faces out, so its least z lands on v1.
	var u := (u0 + u1) / 2.0 if nominal > 0.0 else u0 - box.position.x * sx
	var v := v1 + box.position.y * sz
	var at := origin + along * u + normal * v
	return piece(parent, name_, Vector3(at.x, 0, at.y), normal, Vector3(sx, 1, sz))


# ---- Trams and blocks ----

## Stretches `body`, kit piece `name_` (a tram running along its x), across
## so it is as wide as the tram kind where people walk (250 cm, the width
## the core keeps clear round the track) and centred on its track.
func fit_tram_width(body: Node3D, name_: String) -> void:
	var box := band_box(name_)
	var width := float(StylePack.kinds().get("tram", {}).get("width", 250)) / 100.0
	if box.size.y > 1e-3:
		body.scale.z = width / box.size.y
		body.position.z = -box.get_center().y * body.scale.z


## How high and thick a block's garden wall stands.
const LOT_WALL_H := 1.1
const LOT_WALL_T := 0.2
## Its gate: the leaf's width, its posts' width and height.
const GATE_W := 1.2
const GATE_POST := 0.3
const GATE_POST_H := 1.35


## A garden wall along the inside of `rect`'s edges, with a closed gate in
## the side facing `street` (a point on the nearest street; none when it
## is Vector2.INF), where the street the lot faces meets it.
func _lot_wall(root: Node3D, rect: Rect2, street := Vector2.INF) -> void:
	var bt := MeshBatch.new()
	var t := LOT_WALL_T
	var inner := rect.grow(-t)
	var side := side_toward(rect, street)
	var walls := [Rect2(rect.position, Vector2(rect.size.x, t)), Rect2(rect.position.x, inner.end.y, rect.size.x, t),
			Rect2(rect.position.x, inner.position.y, t, inner.size.y), Rect2(inner.end.x, inner.position.y, t, inner.size.y)]
	for k in walls.size():
		var wall: Rect2 = walls[k]
		if k == side:
			var gap := _gate(root, wall, street)
			var axis := 0 if k < 2 else 1
			var before := wall
			before.size[axis] = gap.x - wall.position[axis]
			var after := wall
			after.position[axis] = gap.y
			after.size[axis] = wall.end[axis] - gap.y
			for part in [before, after]:
				if part.size[axis] > 0.01:
					bt.block(Vector3(part.position.x, 0.0, part.position.y), Vector3(part.end.x, LOT_WALL_H, part.end.y), mat("limewash"))
			continue
		# One material: a block's wall is one draw, and there are many blocks.
		bt.block(Vector3(wall.position.x, 0.0, wall.position.y), Vector3(wall.end.x, LOT_WALL_H, wall.end.y), mat("limewash"))
	var node := bt.build("GardenWall")
	root.add_child(node)


## Which side of `rect` faces `street` (a point): 0 north, 1 south, 2 west
## or 3 east, the one it lies farthest beyond; -1 when it lies inside or is
## Vector2.INF.
static func side_toward(rect: Rect2, street: Vector2) -> int:
	if street == Vector2.INF:
		return -1
	var beyond := [rect.position.y - street.y, street.y - rect.end.y, rect.position.x - street.x, street.x - rect.end.x]
	var best := -1
	for k in 4:
		if beyond[k] > 0.0 and (best < 0 or beyond[k] > beyond[best]):
			best = k
	return best


## A closed gate in garden wall `wall` (the side's strip), where `street`
## comes nearest along it and clear of the corners: two stone posts and a
## timber leaf, all within the wall's thickness, so the lot stays closed
## where people walk. Returns the gap it fills along the wall's axis
## (from, to).
func _gate(root: Node3D, wall: Rect2, street: Vector2) -> Vector2:
	var axis := 0 if wall.size.x >= wall.size.y else 1
	var half := GATE_W / 2.0 + GATE_POST
	var lo: float = wall.position[axis] + half + 0.3
	var hi: float = wall.end[axis] - half - 0.3
	var at: float = clampf(street[axis], lo, hi) if lo <= hi else wall.get_center()[axis]
	var across: float = wall.get_center()[1 - axis]
	var t: float = wall.size[1 - axis]
	var bt := MeshBatch.new()
	var box := func(a0: float, a1: float, c0: float, c1: float, y0: float, y1: float, m: Material) -> void:
		var p0 := Vector3.ZERO
		var p1 := Vector3.ZERO
		p0[0 if axis == 0 else 2] = a0
		p1[0 if axis == 0 else 2] = a1
		p0[2 if axis == 0 else 0] = c0
		p1[2 if axis == 0 else 0] = c1
		p0.y = y0
		p1.y = y1
		bt.block(p0, p1, m)
	for s in [-1.0, 1.0]:
		var inner_edge: float = at + s * GATE_W / 2.0
		box.call(minf(inner_edge, inner_edge + s * GATE_POST), maxf(inner_edge, inner_edge + s * GATE_POST),
			across - t / 2.0, across + t / 2.0, 0.0, GATE_POST_H, mat("sandstone"))
	# The leaf, shut: boards across the gateway, a hand's width off the
	# ground.
	box.call(at - GATE_W / 2.0, at + GATE_W / 2.0, across - 0.03, across + 0.03, 0.06, 1.0, mat("wood"))
	var node := bt.build("GardenGate")
	root.add_child(node)
	return Vector2(at - half, at + half)
