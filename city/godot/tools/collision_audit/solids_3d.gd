## The collision audit's reading of a 3D pack: every visible mesh (a
## MeshInstance3D, or each instance of a MultiMesh), cut to the walking
## band above the ground drawn under it (a bridge's deck on the bridge; a
## raised sidewalk, kerb, platform or quay edge where a style draws one,
## found by raise_ground), flattened, with what its faces enclose, and named by whose it is: the
## placement, seat, building, scenery or nothing (untagged) its nearest
## tagged ancestor says (the tags StylePack sets).
##
## What of a thing counts (the spike's rules, spec §7):
## - trees count at the trunk: their leaf surfaces are dropped, and street
##   trees and palms count only within TRUNK_R of their axis (the crown
##   spreads over people's heads);
## - the great tree keeps its roots; shrubs count whole;
## - an umbrella counts round its pole;
## - soft ground (a meadow's grass) is walked through: a copy drawn wholly
##   inside its lot is no solid, one reaching past it counts.
## People and trams are left out (trams are checked apart); so are far
## copies of trees (their near copy is read).
extends RefCounted

const Solid = preload("res://tools/collision_audit/solid.gd")

## The raster enclosed shapes are traced on, in world metres.
const PIXEL := 0.025
## How far from a tree's axis its trunk counts, in its own scale.
const TRUNK_R := 1.0
## Kinds that count only near their axis, and how near.
const AXIS_R := {"street-tree": TRUNK_R, "palm": TRUNK_R, "umbrella": 0.3}
## Kinds whose leaf surfaces are dropped.
const LEAFY := ["street-tree", "palm", "great-tree"]
## What a leaf surface's material is called in the kits.
const LEAF_MATERIAL := "leaf|leaves|foliage|frond"
## The most raster cells one silhouette is traced on; a larger shape is
## traced on a coarser raster.
const MAX_RASTER := 8_000_000
## The tags that name whose a node is, nearest first.
const TAGS := ["placement_id", "placement_ids", "building", "scenery", "lamp_of", "vehicle", "occupant"]

## (mesh, band, rule) -> {contours, pieces, pixel}, shared by every copy.
var _cache := {}
## Mesh -> its triangles {verts, surface of each, leafy surfaces}.
var _meshes := {}
var _leaf := RegEx.create_from_string(LEAF_MATERIAL)
var band := Vector2(0.25, 1.9)
## Placement or seat ID -> its kind.
var kinds := {}
## Soft ground's placement ID -> its lot, metres (CollisionAudit.soft_ground).
var soft := {}
var _deck: Callable
var _bridges: Array = []
## The grid the ground heights are kept on.
var nav: NavQuery
## Per cell: the height of the ground drawn under its centre, metres.
var ground := PackedFloat32Array()
## MultiMeshes (by path) whose pieces could not be placed, and how many.
var unplaced := {}
## Surfaces this high or higher are no ground a walker stands on: they
## are in the band, and solid.
const GROUND_TOP := 0.25


## Every solid `pack` draws in the band that `wanted(bounds)` (a world
## rectangle, grown by the clearance) says may matter.
func collect(pack, wanted: Callable) -> Array:
	_deck = pack.deck_at
	for b in pack.bridges:
		_bridges.append(Rect2(b["a"], Vector2.ZERO).expand(b["b"]).grow(b["width"] / 2.0 + 2.0))
	var skip := {}
	for n in pack.nodes.values():
		skip[n] = true
	for n in pack.vehicle_nodes.values():
		skip[n] = true
	for n in pack.clouds:
		skip[n] = true
	for extra in [pack.player_marker(), pack.reticle, pack.rain_node]:
		if extra != null and is_instance_valid(extra):
			skip[extra] = true
	# Every copy of every mesh: [mesh, world transform, tagged, node,
	# instance or -1].
	var copies := []
	var headless := DisplayServer.get_name() == "headless"
	for g in pack.find_children("*", "GeometryInstance3D", true, false):
		if not (g is MeshInstance3D or g is MultiMeshInstance3D):
			continue
		if not g.is_visible_in_tree() or g.has_meta("far_of") or g.visibility_range_begin > 0.0:
			continue
		var tagged := _tagged(g, pack, skip)
		if tagged.is_empty():
			continue
		if g is MeshInstance3D:
			if g.mesh != null:
				copies.append([g.mesh, g.global_transform, tagged, g, -1])
			continue
		var mm: MultiMesh = g.multimesh
		if mm == null or mm.mesh == null:
			continue
		var count := mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
		# KitTown keeps the pieces' transforms on the node: a headless
		# rendering server keeps none of a MultiMesh's, and reading them
		# there would stand every piece on the origin.
		var kept: Array = g.get_meta("instance_xforms", [])
		if kept.size() < count and headless:
			var path := str(pack.get_path_to(g))
			push_error("collision audit: %s keeps no transforms for its %d pieces" % [path, count])
			unplaced[path] = count
			continue
		for k in count:
			copies.append([mm.mesh, g.global_transform * (kept[k] if k < kept.size() else mm.get_instance_transform(k)), tagged, g, k])
	# The ground drawn under each cell, from everything that is not a
	# placement (placements stand on the ground).
	ground.resize(nav.cols * nav.rows)
	ground.fill(0.0)
	for c in copies:
		if c[2]["tag"] in ["placement_id", "placement_ids", "lamp_of"]:
			continue
		var mesh: Mesh = c[0]
		var xform: Transform3D = c[1]
		if (xform * mesh.get_aabb()).position.y >= GROUND_TOP:
			continue
		raise_ground(ground, nav, xform * _triangles(mesh)["verts"])
	var out := []
	for c in copies:
		var axis: Vector3 = c[1].origin if c[4] >= 0 else c[2]["node"].global_position
		_read(c[0], c[1], _owner(c[2], c[3], pack, c[4]), axis, wanted, out)
	return out


## Raises `heights` (per cell of `grid`, metres) to every surface of the
## triangle soup `verts` (world metres) that faces up, lies below
## GROUND_TOP and covers the cell's centre: a sidewalk, kerb or platform
## drawn above the street.
static func raise_ground(heights: PackedFloat32Array, grid: NavQuery, verts: PackedVector3Array) -> void:
	for t in verts.size() / 3:
		var a := verts[t * 3]
		var b := verts[t * 3 + 1]
		var c := verts[t * 3 + 2]
		var top := maxf(a.y, maxf(b.y, c.y))
		if top >= GROUND_TOP or top <= 0.0:
			continue
		# Faces up as Godot winds a front face (clockwise, seen from the
		# front): an underside faces down and is stood on by no one.
		if (b - a).cross(c - a).length_squared() < 1e-12 or Plane(a, b, c).normal.y < 0.7:
			continue
		var y := (a.y + b.y + c.y) / 3.0
		var lo := grid.cell_of(Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z))) * 100.0)
		var hi := grid.cell_of(Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z))) * 100.0)
		var pa := Vector2(a.x, a.z)
		var pb := Vector2(b.x, b.z)
		var pc := Vector2(c.x, c.z)
		for j in range(maxi(0, lo.y), mini(grid.rows, hi.y + 1)):
			for i in range(maxi(0, lo.x), mini(grid.cols, hi.x + 1)):
				var k := j * grid.cols + i
				if y > heights[k] and Geometry2D.point_is_inside_triangle(grid.centre(Vector2i(i, j)) / 100.0, pa, pb, pc):
					heights[k] = y


## The ground drawn at `p` (metres): a bridge's deck, or the cell's.
func _ground_at(p: Vector2, on_bridge: bool) -> float:
	var g := 0.0
	var c := nav.cell_of(p * 100.0)
	if c.x >= 0 and c.y >= 0 and c.x < nav.cols and c.y < nav.rows:
		g = ground[c.y * nav.cols + c.x]
	return maxf(g, _deck.call(p)) if on_bridge else g


## The lowest and highest ground drawn under world rectangle `r`.
func _ground_under(r: Rect2) -> Vector2:
	var a := nav.cell_of(r.position * 100.0)
	var b := nav.cell_of(r.end * 100.0)
	var lo := INF
	var hi := -INF
	for j in range(a.y, b.y + 1):
		for i in range(a.x, b.x + 1):
			var g := 0.0
			if i >= 0 and j >= 0 and i < nav.cols and j < nav.rows:
				g = ground[j * nav.cols + i]
			lo = minf(lo, g)
			hi = maxf(hi, g)
	return Vector2(lo, hi)


## The nearest tagged ancestor of `g` (itself included): {node, tag}; {}
## when it is a person, a vehicle or one of the pack's own markers; tag ""
## when nothing is tagged.
func _tagged(g: Node, pack: Node, skip: Dictionary) -> Dictionary:
	var n := g
	var found := {}
	while n != null and n != pack:
		if skip.has(n):
			return {}
		if found.is_empty():
			for tag in TAGS:
				if n.has_meta(tag):
					found = {"node": n, "tag": tag}
					break
		n = n.get_parent()
	if found.is_empty():
		return {"node": g, "tag": ""}
	if found["tag"] in ["vehicle", "occupant"]:
		return {}
	return found


func _owner(tagged: Dictionary, g: Node, pack: Node, instance: int) -> Dictionary:
	var node: Node = tagged["node"]
	var path := str(pack.get_path_to(g))
	match tagged["tag"]:
		"placement_id":
			var id := str(node.get_meta("placement_id"))
			return {"kind": kinds.get(id, "placement"), "placement_id": id}
		"placement_ids":
			var ids: PackedStringArray = node.get_meta("placement_ids")
			if instance >= 0 and instance < ids.size():
				return {"kind": kinds.get(ids[instance], "placement"), "placement_id": ids[instance]}
			return {"kind": "untagged", "mesh": "%s#%d" % [path, instance]}
		"lamp_of":
			var id := str(node.get_meta("lamp_of"))
			return {"kind": kinds.get(id, "placement"), "placement_id": id}
		"building":
			return {"kind": "building", "building": str(node.get_meta("building")), "mesh": path}
		"scenery":
			return {"kind": "scenery:" + str(node.get_meta("scenery")), "mesh": path}
	return {"kind": "untagged", "mesh": path + ("#%d" % instance if instance >= 0 else "")}


## Adds the solid one copy of `mesh` at `xform` draws in the band, when it
## reaches the band and `wanted` its bounds.
func _read(mesh: Mesh, xform: Transform3D, owner: Dictionary, axis_world: Vector3, wanted: Callable, out: Array) -> void:
	var box := xform * mesh.get_aabb()
	var flat := Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
	var on_bridge := false
	for b in _bridges:
		if b.intersects(flat):
			on_bridge = true
			break
	var under := _ground_under(flat)
	if on_bridge:
		under.y = maxf(under.y, maxf(_deck.call(flat.position), maxf(_deck.call(flat.end), _deck.call(flat.get_center()))))
	if box.end.y <= under.x + band.x or box.position.y >= under.y + band.y:
		return
	if not wanted.call(flat):
		return
	if walked_through(soft, owner, flat):
		return
	var kind := str(owner.get("kind", ""))
	var rule := {"leafy": kind in LEAFY, "axis_r": float(AXIS_R.get(kind, -1.0))}
	var b := xform.basis
	var level := absf(b.x.y) < 1e-4 and absf(b.z.y) < 1e-4 and absf(b.y.x) < 1e-4 and absf(b.y.z) < 1e-4
	var sx := Vector2(b.x.x, b.x.z)
	var sz := Vector2(b.z.x, b.z.z)
	var uniform := absf(sx.length() - sz.length()) < 1e-3 and absf(sx.dot(sz)) < 1e-3 * sx.length_squared()
	var solid := Solid.new()
	solid.owner = owner
	var shape: Dictionary
	var placed := Transform2D.IDENTITY
	if level and uniform and not on_bridge and b.y.y > 1e-6 and under.y - under.x < 0.005:
		# On level ground: the kit piece's own frame, shared by every copy
		# at this height and scale.
		var s := sx.length()
		var lo := (under.x + band.x - xform.origin.y) / b.y.y
		var hi := (under.x + band.y - xform.origin.y) / b.y.y
		var to_world := Transform2D(sx, sz, Vector2(xform.origin.x, xform.origin.z))
		var axis := to_world.affine_inverse() * Vector2(axis_world.x, axis_world.z)
		var key := "%d|%.3f|%.3f|%s|%.3f|%.3f,%.3f|%.4f" % [mesh.get_instance_id(), lo, hi, rule["leafy"],
			rule["axis_r"], axis.x, axis.y, PIXEL / s]
		if not _cache.has(key):
			var tris := _triangles(mesh)
			_cache[key] = _silhouette(tris["verts"], tris["surface"], tris["leafy"], rule, axis, Vector2(lo, hi), PackedFloat32Array(), PIXEL / s)
		shape = _cache[key]
		placed = to_world
	else:
		# Turned out of level, stretched, or across a change in the ground
		# (a kerb, a bridge's deck): read in the world's frame, each
		# triangle over the ground beneath it.
		var tris := _triangles(mesh)
		var verts: PackedVector3Array = xform * tris["verts"]
		var grounds := PackedFloat32Array()
		grounds.resize(verts.size() / 3)
		for t in grounds.size():
			var c := (verts[t * 3] + verts[t * 3 + 1] + verts[t * 3 + 2]) / 3.0
			grounds[t] = _ground_at(Vector2(c.x, c.z), on_bridge)
		shape = _silhouette(verts, tris["surface"], tris["leafy"], rule, Vector2(axis_world.x, axis_world.z), band, grounds, PIXEL)
	if shape["pieces"].is_empty():
		return
	solid.contours = shape["contours"]
	solid.pieces = shape["pieces"]
	solid.pixel = shape["pixel"]
	solid.place(placed)
	out.append(solid)


## Whether a copy drawn for `owner` over `flat` (its bounds, metres) is
## soft ground walked through: soft ground's (`soft_`, its lots by
## placement ID), wholly inside its lot. Grass parts as people pass and
## pushes no one (interactions spec section 2).
static func walked_through(soft_: Dictionary, owner: Dictionary, flat: Rect2) -> bool:
	var lot = soft_.get(str(owner.get("placement_id", "")))
	return lot is Rect2 and lot.grow(1e-4).encloses(flat)


## A mesh's triangles as a flat vertex list, the surface each came from,
## and which surfaces are leaves.
func _triangles(mesh: Mesh) -> Dictionary:
	var key := mesh.get_instance_id()
	if _meshes.has(key):
		return _meshes[key]
	var verts := PackedVector3Array()
	var surface := PackedInt32Array()
	var leafy := PackedByteArray()
	for s in mesh.get_surface_count():
		var material := mesh.surface_get_material(s)
		leafy.append(1 if material != null and _leaf.search(material.resource_name.to_lower()) != null else 0)
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(s)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx = arrays[Mesh.ARRAY_INDEX]
		if idx is PackedInt32Array and idx.size() > 0:
			for i in idx:
				verts.append(v[i])
		else:
			verts.append_array(v.slice(0, v.size() / 3 * 3))
		var n := verts.size() / 3 - surface.size()
		for k in n:
			surface.append(s)
	_meshes[key] = {"verts": verts, "surface": surface, "leafy": leafy}
	return _meshes[key]


## The band slice of a triangle soup: each triangle's part between band.x
## and band.y (above `grounds[t]` when given), flattened to (x, z), and the
## outlines of all that they enclose, traced on a raster `pixel` wide.
## Leaf surfaces are dropped where `rule` says, and triangles farther than
## rule.axis_r from `axis` where it gives one.
static func _silhouette(verts: PackedVector3Array, surface: PackedInt32Array, leafy: PackedByteArray, rule: Dictionary,
		axis: Vector2, band_: Vector2, grounds: PackedFloat32Array, pixel: float) -> Dictionary:
	var pieces: Array[PackedVector2Array] = []
	var drop_leaves: bool = rule["leafy"]
	var axis_r: float = rule["axis_r"]
	var tiny := pixel * pixel * 0.0625
	for t in verts.size() / 3:
		if drop_leaves and leafy[surface[t]] == 1:
			continue
		var a := verts[t * 3]
		var b := verts[t * 3 + 1]
		var c := verts[t * 3 + 2]
		var lo := band_.x
		var hi := band_.y
		if not grounds.is_empty():
			lo += grounds[t]
			hi += grounds[t]
		if maxf(a.y, maxf(b.y, c.y)) <= lo or minf(a.y, minf(b.y, c.y)) >= hi:
			continue
		if axis_r >= 0.0 and Vector2((a.x + b.x + c.x) / 3.0, (a.z + b.z + c.z) / 3.0).distance_to(axis) > axis_r:
			continue
		var pts := PackedVector2Array()
		for v in [a, b, c]:
			if v.y >= lo and v.y <= hi:
				pts.append(Vector2(v.x, v.z))
		for e in [[a, b], [b, c], [c, a]]:
			var p: Vector3 = e[0]
			var q: Vector3 = e[1]
			var den := q.y - p.y
			if den == 0.0:
				continue
			for level in [lo, hi]:
				var s: float = (level - p.y) / den
				if s > 0.0 and s < 1.0:
					var m := p.lerp(q, s)
					pts.append(Vector2(m.x, m.z))
		if pts.is_empty():
			continue
		var hull := Geometry2D.convex_hull(pts)
		if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
			hull.resize(hull.size() - 1)
		if hull.size() >= 3 and absf(_area(hull)) > tiny:
			pieces.append(hull)
		else:
			pieces.append(_extremes(pts))
	if pieces.is_empty():
		return {"contours": [] as Array[PackedVector2Array], "pieces": pieces, "pixel": pixel}
	return {"contours": _trace(pieces, pixel), "pieces": pieces, "pixel": pixel}


static func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	var n := poly.size()
	for k in n:
		s += poly[k].cross(poly[(k + 1) % n])
	return s / 2.0


## The two points farthest apart (a vertical face seen from above), or the
## one point.
static func _extremes(pts: PackedVector2Array) -> PackedVector2Array:
	var best := PackedVector2Array([pts[0]])
	var far := 0.0
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			var d := pts[i].distance_squared_to(pts[j])
			if d > far:
				far = d
				best = PackedVector2Array([pts[i], pts[j]])
	return best


## The outlines of what `pieces` cover and enclose: drawn on a raster
## `pixel` wide (polygons filled, segments as unbroken lines), whose outer
## contours BitMap traces; holes are not traced, so what the pieces enclose
## is inside.
static func _trace(pieces: Array[PackedVector2Array], pixel: float) -> Array[PackedVector2Array]:
	var box := Rect2(pieces[0][0], Vector2.ZERO)
	for piece in pieces:
		for p in piece:
			box = box.expand(p)
	var px := pixel
	while (box.size.x / px + 5.0) * (box.size.y / px + 5.0) > MAX_RASTER:
		px *= 2.0
	var origin := box.position - Vector2(px, px) * 2.0
	var size := Vector2i(ceili(box.size.x / px) + 5, ceili(box.size.y / px) + 5)
	var bits := BitMap.new()
	bits.create(size)
	for piece in pieces:
		var local := PackedVector2Array()
		for p in piece:
			local.append((p - origin) / px)
		if local.size() >= 3:
			_fill(bits, local)
		for k in local.size():
			_line(bits, local[k], local[(k + 1) % local.size()])
	var out: Array[PackedVector2Array] = []
	for poly in bits.opaque_to_polygons(Rect2i(Vector2i.ZERO, size), 0.5):
		var world := PackedVector2Array()
		for p in poly:
			world.append(origin + p * px)
		out.append(world)
	return out


## Sets every raster cell whose centre lies in convex polygon `poly`
## (raster units).
static func _fill(bits: BitMap, poly: PackedVector2Array) -> void:
	var y0 := INF
	var y1 := -INF
	for p in poly:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	for j in range(maxi(0, floori(y0 - 0.5) + 1), mini(bits.get_size().y, floori(y1 - 0.5) + 1)):
		var y := j + 0.5
		var x0 := INF
		var x1 := -INF
		var n := poly.size()
		for k in n:
			var a := poly[k]
			var b := poly[(k + 1) % n]
			if (a.y - y) * (b.y - y) > 0.0 or a.y == b.y:
				continue
			var x := a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y)
			x0 = minf(x0, x)
			x1 = maxf(x1, x)
		if x0 <= x1:
			var i0 := maxi(0, floori(x0))
			var i1 := mini(bits.get_size().x - 1, floori(x1))
			if i1 >= i0:
				bits.set_bit_rect(Rect2i(i0, j, i1 - i0 + 1, 1), true)


## Sets every raster cell segment a-b crosses, 4-connected so a traced
## outline has no gaps (raster units).
static func _line(bits: BitMap, a: Vector2, b: Vector2) -> void:
	var n := ceili(a.distance_to(b) * 3.0) + 1
	var prev := Vector2i(a.floor())
	bits.set_bitv(prev, true)
	for s in range(1, n + 1):
		var c := Vector2i(a.lerp(b, float(s) / n).floor())
		if c == prev:
			continue
		if c.x != prev.x and c.y != prev.y:
			bits.set_bitv(Vector2i(c.x, prev.y), true)
		bits.set_bitv(c, true)
		prev = c


## The drawn tram body's half width and the offset of its middle across
## its length, from the kit's tram (which runs along its x): what it draws
## in the band.
func tram_half_width(pack) -> Dictionary:
	if pack.town == null:
		return {}
	var body: Node3D = pack.town.tram()
	var z0 := INF
	var z1 := -INF
	for g in body.find_children("*", "MeshInstance3D", true, false):
		if g.mesh == null:
			continue
		var xform: Transform3D = g.transform
		var n: Node = g.get_parent()
		while n != null and n != body.get_parent():
			if n is Node3D:
				xform = n.transform * xform
			n = n.get_parent()
		var tris := _triangles(g.mesh)
		var shape := _silhouette(xform * tris["verts"], tris["surface"], tris["leafy"], {"leafy": false, "axis_r": -1.0},
			Vector2.ZERO, band, PackedFloat32Array(), PIXEL)
		for piece in shape["pieces"]:
			for p in piece:
				z0 = minf(z0, p.y)
				z1 = maxf(z1, p.y)
	body.free()
	if z0 > z1:
		return {}
	return {"half_width": (z1 - z0) / 2.0, "centre": (z0 + z1) / 2.0}

