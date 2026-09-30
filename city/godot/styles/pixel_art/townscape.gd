## Assembles the pixel city from the pre-rendered kit (city/tools/styles/pixel;
## the placement conventions are in assets/kit.json): buildings a façade
## metre at a time with corners, roofs and the dome; blocks fitted to their
## lots; the ground as 1 m cells (streets with kerbs, dashes, crossings and
## the transit lines' tracks, the river with its quays); the bridge in back
## and front slices; the tram in 1 m slices; railings.
##
## Every sprite stands on a ground point and y-sorts there, so people pass
## in front of and behind a building a metre at a time.
extends RefCounted

## Wall thickness behind every façade's outer face (kit.json WALL): the
## building kind's `wall`, which the walls stand in outside the rooms.
const WALL := 0.25
## Width of one sawtooth tooth, and the tram's length in slices.
const TOOTH := 4
const TRAM_SLICES := 20
## Lots for houses and shops, in metres; a house is 5 x 5, a shop 5 x 4.
const HOUSE_LOT := Vector2(6.0, 6.0)
const SHOP_LOT := Vector2(6.0, 5.0)
const TOWER := 12.0
const TOWER_BASE := 4.0
const TOWER_STOREY := 3.0

## The pixel pack: _sprite(), iso(), paint(), resolve() and the style.
var pack


func _init(p) -> void:
	pack = p


static func _hash01(v) -> float:
	return float(hash(v) % 1000) / 1000.0


func _pick(list: Array, key):
	return list[hash(key) % list.size()] if not list.is_empty() else null


# ---- Buildings ----

## Each of a building side's doorways, as [its first metre, its width in
## metres]: the metre offsets in increasing x (north, south) or z (east,
## west) the opening spans, centred on the door. Sides run clockwise
## (CityGeometry.sides_of), so south and west measure their openings from
## their far end. The kit draws an opening a metre at a time, so a width
## that is not whole metres is drawn at the nearest whole width.
static func door_starts(side: Dictionary, fp: Rect2) -> Array:
	var n := int(round(fp.size.x if side["side"] in ["north", "south"] else fp.size.y))
	var widths: Array = side.get("widths", [])
	var out := []
	for k in side["openings"].size():
		var from_start: float = side["openings"][k]
		if side["side"] in ["south", "west"]:
			from_start = n - from_start
		var w: float = widths[k] if k < widths.size() else 2.0
		var metres := maxi(1, roundi(w))
		if not is_equal_approx(w, metres):
			push_warning("pixel art: a %.2f m doorway is drawn %d m wide" % [w, metres])
		out.append([clampi(roundi(from_start - metres / 2.0), 0, maxi(0, n - metres)), metres])
	return out


## Module names for a face `n` metres long with doorways `doors` ([first
## metre, width]): each opening a `door_m` a metre, between the reveals
## `door_l` and `door_r` where its leaves stand folded; 2 m window bays, a
## plain metre where a bay does not fit, banners beside doorways where the
## building flies them.
static func facade_plan(n: int, doors: Array, banners: bool) -> Array:
	var names := []
	names.resize(n)
	for d in doors:
		var start: int = d[0]
		var width: int = d[1]
		for k in width:
			names[start + k] = "door_m"
		for side in [[start - 1, "door_l"], [start + width, "door_r"]]:
			if side[0] >= 0 and side[0] < n and names[side[0]] == null:
				names[side[0]] = side[1]
		if banners:
			for b in [start - 2, start + width + 1]:
				if b >= 0 and b < n and names[b] == null:
					names[b] = "banner"
	var k := 0
	while k < n:
		if names[k] == null:
			if k + 1 < n and names[k + 1] == null:
				names[k] = "wall_0"
				names[k + 1] = "wall_1"
				k += 2
				continue
			names[k] = "plain"
		k += 1
	return names


## {root, roof, near, low, far} for one building: near façades (south and
## east, and the corners on them) with their low twins for the cut-away
## (a doorway's opening has none), far façades (north and west, seen from
## inside when open) and the roof, which sorts at the footprint's
## south-east corner above every slice. The walls stand in the ring the
## kind's `wall` deep outside the rooms, where the core blocks them, their
## corners in the squares where two sides meet.
func building(parent: Node, b: Dictionary) -> Dictionary:
	var ext: Dictionary = pack.resolve("exteriors", str(b["kind"]))
	var folder := "assets/" + str(ext.get("folder", "buildings/hall"))
	var fp: Rect2 = b["footprint"]
	var x0 := int(round(fp.position.x))
	var z0 := int(round(fp.position.y))
	var x1 := int(round(fp.end.x))
	var z1 := int(round(fp.end.y))
	var root := Node2D.new()
	root.name = str(b["id"]).replace(":", "_")
	root.y_sort_enabled = true
	parent.add_child(root)
	var shell := {"root": root, "near": [], "low": [], "far": []}
	var banners: bool = ext.get("banners", false)
	var w := float(b.get("wall", WALL))
	for side in b["sides"]:
		var s: String = side["side"]
		var plan := facade_plan(x1 - x0 if s in ["north", "south"] else z1 - z0, door_starts(side, fp), banners)
		for k in plan.size():
			# A slice's outer line: the ring's outer edge on the near sides,
			# the rooms' edge on the far ones, whose slices are seen from
			# inside with their thickness outward.
			var at: Vector2
			var prefix := "s_" if s in ["north", "south"] else "e_"
			match s:
				"north":
					at = Vector2(x0 + k + 1, z0)
				"south":
					at = Vector2(x0 + k + 1, z1 + w)
				"west":
					at = Vector2(x0, z0 + k + 1)
				_:
					at = Vector2(x1 + w, z0 + k + 1)
			var full: Sprite2D = pack._sprite(folder.path_join(prefix + str(plan[k]) + ".png"), pack.iso(at.x, at.y), root)
			if s in ["south", "east"]:
				shell["near"].append(full)
				if plan[k] == "door_m":
					continue
				var low: Sprite2D = pack._sprite(folder.path_join(prefix + "low.png"), pack.iso(at.x, at.y), root)
				low.visible = false
				shell["low"].append(low)
			else:
				shell["far"].append(full)
	var h := w / 2.0
	for c in [Vector2(x0 - h, z0 - h), Vector2(x1 + h, z0 - h), Vector2(x0 - h, z1 + h), Vector2(x1 + h, z1 + h)]:
		var pier: Sprite2D = pack._sprite(folder.path_join("corner.png"), pack.iso(c.x, c.y), root)
		if c == Vector2(x0 - h, z0 - h):
			shell["far"].append(pier)
			continue
		shell["near"].append(pier)
		var low: Sprite2D = pack._sprite(folder.path_join("corner_low.png"), pack.iso(c.x, c.y), root)
		low.visible = false
		shell["low"].append(low)
	shell["roof"] = _roof(root, ext, folder, Rect2i(x0, z0, x1 - x0, z1 - z0), w)
	return shell


## The roof: one node at the wall ring's south-east corner (so it sorts
## after every wall slice), its pieces drawn back to front inside it.
func _roof(root: Node2D, ext: Dictionary, folder: String, r: Rect2i, wall: float) -> Node2D:
	var roof := Node2D.new()
	roof.name = "Roof"
	roof.position = pack.iso(r.end.x + wall, r.end.y + wall)
	root.add_child(roof)
	var lift := float(ext.get("wall_top", 5.2))
	if str(ext.get("roof", "")) == "sawtooth":
		for t in r.size.x / TOOTH:
			var xb := r.position.x + TOOTH * t + TOOTH
			for k in range(r.position.y, r.end.y):
				var piece := "roof_n" if k == r.position.y else ("roof_s" if k == r.end.y - 1 else "roof_mid")
				pack._sprite(folder.path_join(piece + ".png"), pack.iso(xb, k + 1) - roof.position, roof, false, lift)
	else:
		var tiles := {}
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				tiles[Vector2i(x, z)] = str(ext.get("roof_tile", ""))
		pack.bake(tiles, roof, "RoofTiles", lift, 1, -roof.position)
	if ext.get("dome") != null:
		var c := Vector2(r.position.x + r.size.x / 2.0, r.position.y + r.size.y / 2.0)
		pack._sprite(str(ext["dome"]), pack.iso(c.x, c.y) - roof.position, roof, false, lift)
	return roof


## Partition walls inside a building (the workshop and commons): low
## slices of the building's family straddling the rooms' shared edge a to
## b, `wall` thick, so the rooms stay readable when open. `gaps` are its
## doorways, [centre, width] in metres: each is left open exactly as wide
## as its door, and the slices either side run up to it (the last in a
## run overlapping its neighbour when the run is not whole metres).
func partition(parent: Node2D, folder: String, a: Vector2, b: Vector2, gaps: Array, building: String, wall := WALL) -> void:
	var along_x := is_equal_approx(a.y, b.y)
	var lo := minf(a.x, b.x) if along_x else minf(a.y, b.y)
	var hi := maxf(a.x, b.x) if along_x else maxf(a.y, b.y)
	var cuts := []
	for g in gaps:
		var at: Vector2 = g[0]
		var t := at.x if along_x else at.y
		cuts.append([t - float(g[1]) / 2.0, t + float(g[1]) / 2.0])
	cuts.sort()
	var runs := []
	var from := lo
	for c in cuts:
		runs.append([from, c[0]])
		from = c[1]
	runs.append([from, hi])
	for run in runs:
		var length: float = run[1] - run[0]
		if length <= 0.01:
			continue
		for k in ceili(length - 0.01):
			var end := minf(run[0] + k + 1.0, run[1])
			var at := Vector2(end, a.y + wall / 2.0) if along_x else Vector2(a.x + wall / 2.0, end)
			pack._sprite(folder.path_join(("s_" if along_x else "e_") + "low.png"), pack.iso(at.x, at.y), parent).set_meta("building", building)


# ---- Blocks ----

## The pixel lattice, metres: one metre east is 16 px across and 8 down,
## so a ground point on a multiple of 12.5 cm (2 px and 1 px) lands
## exactly on a pixel, and the audit reads it back exactly.
const LATTICE := 0.125
## A block's garden wall (models.py GARDEN_WALL_T): how thick it stands,
## and how far its middle line runs inside the lot's edge, a lattice step,
## so its outer face stands 2.5 cm inside the lot.
const GARDEN_WALL_T := 0.2
const GARDEN_WALL_IN := LATTICE
## How far a building stands inside the lot's edge at the least: inside
## its wall.
const LOT_INSET := GARDEN_WALL_IN + GARDEN_WALL_T / 2.0


## Houses and shops in a grid of lots across the block, each centred in
## its lot; a tower centred on the block with a storey count of its own;
## all inside a garden wall along the lot's edges, with a closed gate in
## the side facing `street` (a point on the nearest street; none when it
## is Vector2.INF), as the 3D kits wall their lots.
func block(r: Rect2, height_class: String, seed_: String, street := Vector2.INF) -> Node2D:
	var root := container("Block")
	var sc: Dictionary = pack.style.get("scenery", {})
	garden_wall(root, r, street)
	var inner := r.grow(-LOT_INSET)
	if height_class == "tower":
		var t: Dictionary = sc.get("tower", {})
		var se := _inside(r.get_center() + Vector2(TOWER / 2.0, TOWER / 2.0), _band(t.get("base")), inner)
		var mids := 3 + hash(seed_) % 3
		var at: Vector2 = pack.iso(se.x, se.y)
		pack._sprite(t.get("base"), at, root)
		for k in mids:
			pack._sprite(t.get("mid"), at, root, false, TOWER_BASE + k * TOWER_STOREY)
		pack._sprite(t.get("top"), at, root, false, TOWER_BASE + mids * TOWER_STOREY)
		return root
	var shop := height_class == "shop"
	var lot := SHOP_LOT if shop else HOUSE_LOT
	var size := Vector2(5.0, 4.0) if shop else Vector2(5.0, 5.0)
	var nx := maxi(1, int(r.size.x / lot.x))
	var nz := maxi(1, int(r.size.y / lot.y))
	var cell := Vector2(r.size.x / nx, r.size.y / nz)
	var list: Array = sc.get("shops" if shop else "houses", [])
	for iz in nz:
		for ix in nx:
			var centre := r.position + Vector2((ix + 0.5) * cell.x, (iz + 0.5) * cell.y)
			# Neighbouring lots never repeat a house; the block's seed turns
			# the sequence so blocks differ too.
			var pick = list[posmod(ix + 2 * iz + hash(seed_), list.size())] if not list.is_empty() else null
			var se := _inside(centre + size / 2.0, _band(pick), inner)
			pack._sprite(pick, pack.iso(se.x, se.y), root)
	return root


## Where a building whose band outline about its south-east corner is
## `band` ([x0, x1, z0, z1], kit.json) stands with that corner nearest
## `se`, on the pixel lattice, its outline inside `inner`.
static func _inside(se: Vector2, band: Array, inner: Rect2) -> Vector2:
	var out := se
	for axis in 2:
		var lo: float = inner.position[axis] - float(band[2 * axis])
		var hi: float = inner.end[axis] - float(band[2 * axis + 1])
		lo = ceilf(lo / LATTICE - 1e-6) * LATTICE
		hi = floorf(hi / LATTICE + 1e-6) * LATTICE
		out[axis] = clampf(snappedf(se[axis], LATTICE), lo, hi) if lo <= hi else snappedf((lo + hi) / 2.0, LATTICE)
	return out


## A block sprite's band outline about its south-east corner (kit.json
## `band`), or none.
func _band(path) -> Array:
	var info: Dictionary = pack.kit_sprites.get(str(path).trim_prefix("assets/"), {})
	return info.get("band", [0.0, 0.0, 0.0, 0.0])


## A garden wall a metre at a time along the inside of lot `r`'s edges,
## with a closed gate (two metres) in the side facing `street`, where the
## street comes nearest along it and clear of the corners.
func garden_wall(root: Node2D, r: Rect2, street: Vector2) -> void:
	var sc: Dictionary = pack.style.get("scenery", {}).get("garden", {})
	var side := KitTown.side_toward(r, street)
	var x0 := int(round(r.position.x))
	var z0 := int(round(r.position.y))
	var x1 := int(round(r.end.x))
	var z1 := int(round(r.end.y))
	# Each side: along x or z, the line its middle runs on, its metres.
	var sides := [[true, z0 + GARDEN_WALL_IN, x0, x1], [true, z1 - GARDEN_WALL_IN, x0, x1],
		[false, x0 + GARDEN_WALL_IN, z0, z1], [false, x1 - GARDEN_WALL_IN, z0, z1]]
	for k in sides.size():
		var along_x: bool = sides[k][0]
		var line: float = sides[k][1]
		var lo: int = sides[k][2]
		var hi: int = sides[k][3]
		var gated := k == side and hi - lo >= 4
		var gate := clampi(roundi(street.x if along_x else street.y), lo + 2, hi - 2) if gated else 0
		var m := lo
		while m < hi:
			if gated and m == gate - 1:
				var g := Vector2(gate, line) if along_x else Vector2(line, gate)
				pack._sprite(sc.get("gate_x" if along_x else "gate_z"), pack.iso(g.x, g.y), root)
				m += 2
				continue
			var at := Vector2(m + 0.5, line) if along_x else Vector2(line, m + 0.5)
			pack._sprite(sc.get("wall_x" if along_x else "wall_z"), pack.iso(at.x, at.y), root)
			m += 1


func container(name_: String) -> Node2D:
	var n := Node2D.new()
	n.name = name_
	n.y_sort_enabled = true
	return n


# ---- Ground: streets, the track and the river as cells ----

## Paints the ground cells of every water and street item and of every
## track in `tracks` ({key, points}, points in metres), so crossings and
## junctions can see each other; returns item index (or a track's key) ->
## {cell: tile}. Tracks win their cells from the streets under them.
func paint_scenery(items: Array, tracks := []) -> Dictionary:
	var g: Dictionary = pack.style.get("ground", {})
	var owned := {}
	var street_cells := {}
	for i in items.size():
		var item: Dictionary = items[i]
		match str(item.get("kind", "")):
			"water":
				owned[i] = _water(CityGeometry.rect_m(item["rect"]), g)
			"street":
				owned[i] = {}
				var pts := CityGeometry.scenery_points(item)
				var w := float(item.get("width", 400)) / 100.0
				for k in range(1, pts.size()):
					_street(pts[k - 1], pts[k], w, g, owned[i], street_cells, i)
	# Junctions are plain asphalt; zebra crossings on either side of them.
	for i in owned:
		var item: Dictionary = items[i]
		if str(item["kind"]) != "street":
			continue
		for c in owned[i]:
			if street_cells[c].size() > 1:
				owned[i][c] = g.get("street")
		_crossings(items, i, owned, street_cells, g)
	for track in tracks:
		var key := str(track["key"])
		owned[key] = {}
		var pts: Array = track["points"]
		for k in range(1, pts.size()):
			var a: Vector2 = pts[k - 1]
			var b: Vector2 = pts[k]
			var along_x := absf(b.x - a.x) >= absf(b.y - a.y)
			var steps := int(round(a.distance_to(b)))
			for s in steps:
				var p := a.lerp(b, (s + 0.5) / steps)
				# A track whose middle runs along a cell edge is laid half in
				# each row (or column) beside it.
				var across := p.y if along_x else p.x
				var laid := {}
				if absf(across - roundf(across)) < 0.25:
					var edge := int(roundf(across))
					if along_x:
						laid[Vector2i(floori(p.x), edge - 1)] = g.get("track_x_s")
						laid[Vector2i(floori(p.x), edge)] = g.get("track_x_n")
					else:
						laid[Vector2i(edge - 1, floori(p.y))] = g.get("track_z_e")
						laid[Vector2i(edge, floori(p.y))] = g.get("track_z_w")
				else:
					laid[Vector2i(floori(p.x), floori(p.y))] = g.get("track_x" if along_x else "track_z")
				for c in laid:
					owned[key][c] = laid[c]
					for j in owned:
						if str(j) != key:
							owned[j].erase(c)
	return owned


func _water(r: Rect2, g: Dictionary) -> Dictionary:
	var out := {}
	var water: Array = g.get("water", [])
	for z in range(floori(r.position.y), ceili(r.end.y)):
		for x in range(floori(r.position.x), ceili(r.end.x)):
			var tile = water[0] if not water.is_empty() else null
			if x == floori(r.position.x):
				tile = g.get("quay_w")
			elif x == ceili(r.end.x) - 1:
				tile = g.get("quay_e")
			out[Vector2i(x, z)] = tile
	return out


func _street(a: Vector2, b: Vector2, w: float, g: Dictionary, out: Dictionary, all: Dictionary, index: int) -> void:
	var along_x := absf(b.x - a.x) >= absf(b.y - a.y)
	var lo := minf(a.x, b.x) if along_x else minf(a.y, b.y)
	var hi := maxf(a.x, b.x) if along_x else maxf(a.y, b.y)
	var centre := a.y if along_x else a.x
	var rows := []
	for q in range(floori(centre - w / 2.0), ceili(centre + w / 2.0)):
		if q + 0.5 > centre - w / 2.0 and q + 0.5 < centre + w / 2.0:
			rows.append(q)
	var dash_row: int = rows[rows.size() / 2] if rows.size() >= 5 else -99999
	for s in range(floori(lo), ceili(hi)):
		if s + 0.5 < lo or s + 0.5 > hi:
			continue
		for q in rows:
			var c := Vector2i(s, q) if along_x else Vector2i(q, s)
			var tile = g.get("street")
			if q == rows[0]:
				tile = g.get("kerb_n" if along_x else "kerb_w")
			elif q == rows[-1]:
				tile = g.get("kerb_s" if along_x else "kerb_e")
			elif q == dash_row and posmod(s, 4) < 2:
				tile = g.get("dash_x" if along_x else "dash_z")
			out[c] = tile
			if not all.has(c):
				all[c] = []
			if not index in all[c]:
				all[c].append(index)


## Zebra crossings on a street just outside each junction with another.
func _crossings(items: Array, i: int, owned: Dictionary, all: Dictionary, g: Dictionary) -> void:
	var mine: Dictionary = owned[i]
	var pts := CityGeometry.scenery_points(items[i])
	var along_x := absf(pts[-1].x - pts[0].x) >= absf(pts[-1].y - pts[0].y)
	var junction := {}
	for c in mine:
		if all[c].size() > 1:
			junction[c.x if along_x else c.y] = true
	for s in junction:
		for step in [-1, 1]:
			var t: int = s + step
			if junction.has(t):
				continue
			for c in mine:
				var along: int = c.x if along_x else c.y
				if along != t:
					continue
				var tile: String = str(mine[c])
				if "kerb" in tile or all[c].size() > 1:
					continue
				mine[c] = g.get("crossing_x" if along_x else "crossing_z")


# ---- The bridge ----

## Back halves (the deck and the north parapet) sort at the north edge,
## front halves (the south parapet and the arches' face) at the south edge,
## so walkers on the deck pass between them.
func bridge(a: Vector2, b: Vector2, width: float) -> Node2D:
	var root := container("Bridge")
	var folder := "assets/" + str(pack.style.get("scenery", {}).get("bridge", {}).get("folder", "scenery/bridge"))
	var x0 := int(round(minf(a.x, b.x)))
	var n := int(round(absf(b.x - a.x)))
	var z := (a.y + b.y) / 2.0
	for k in n:
		var name_: String
		if k < 2:
			name_ = "end_w_%d" % k
		elif k >= n - 2:
			name_ = "end_e_%d" % (k - (n - 2))
		else:
			name_ = "span_%d" % ((k - 2) % 4)
		pack._sprite(folder.path_join(name_ + "_back.png"), pack.iso(x0 + k + 1, z - width / 2.0), root)
		pack._sprite(folder.path_join(name_ + "_front.png"), pack.iso(x0 + k + 1, z + width / 2.0), root)
	return root


# ---- The tram ----

## The tram about its middle under one y-sorted node: its back half's 1 m
## slices (the far side, floor, seats and roof) sorting behind its riders,
## its front half's (the near side, windows open) in front of them, and a
## leaf sprite for each half of each door on both sides (named
## Back/FrontDoor_<k>_<fore|aft>), which the pack slides open.
func tram() -> Node2D:
	var n := container("Tram")
	var spec: Dictionary = pack.style.get("scenery", {}).get("tram", {})
	for half in ["back", "front"]:
		var list: Array = spec.get(half, [])
		var z := float(spec.get(half + "_z", -1.3 if half == "back" else 1.3))
		for i in list.size():
			var s: Sprite2D = pack._sprite(list[i], pack.iso(i + 0.5 - list.size() / 2.0, z), n)
			s.name = "%s_%02d" % [half.capitalize(), i]
	var leaf_z := float(spec.get("leaf_z", 1.22))
	var leaf := float(StylePack.tram_layout().get("door_width_cm", 130)) / 400.0
	for k in StylePack.tram_layout().get("doors_cm", []).size():
		var mid := float(StylePack.tram_layout()["length_cm"]) / 200.0 - float(StylePack.tram_layout()["doors_cm"][k]) / 100.0
		for half in ["Back", "Front"]:
			for part in [["fore", leaf], ["aft", -leaf]]:
				var z := -leaf_z if half == "Back" else leaf_z
				var s: Sprite2D = pack._sprite(spec.get("door"), pack.iso(mid + part[1], z), n)
				s.name = "%sDoor_%d_%s" % [half, k, part[0]]
	return n


# ---- Railings ----

## How far a railing stands off the floor it edges, metres: its rails'
## half depth (4 cm) and a centimetre more, taken up to a lattice step.
const FENCE_OFF := LATTICE


## A railing along `pts`, a metre-long slice at a time so each sorts at
## its own ground point, with a post at each open end. A fence runs along
## the edge of the walkable ground, so it stands FENCE_OFF off it on the
## side no room covers (spec §1: its band slice keeps clear of the floor's
## cells), and its end posts stand as far in from its ends.
func fence(pts: Array) -> Node2D:
	var root := container("Fence")
	var rail: Dictionary = pack.style.get("scenery", {}).get("railing", {})
	var f := CityGeometry.fence(pts, 1.0)
	var lattice := Vector2(LATTICE, LATTICE)
	var outs := []
	for m in f["modules"]:
		var along_x: bool = absf(m["dir"].x) >= absf(m["dir"].y)
		var out := _off_the_floor(m["centre"], m["dir"]) * FENCE_OFF
		outs.append(out)
		var at: Vector2 = (m["centre"] + out).snapped(lattice)
		pack._sprite(rail.get("x" if along_x else "z"), pack.iso(at.x, at.y) + Vector2(0, -16.0 * pack.deck_at(at)), root)
	for k in f["posts"].size():
		var m: Dictionary = f["modules"][0 if k == 0 else -1]
		var inward: Vector2 = m["dir"] * FENCE_OFF * (1.0 if k == 0 else -1.0)
		var p: Vector2 = (f["posts"][k] + (outs[0] if k == 0 else outs[-1]) + inward).snapped(lattice)
		pack._sprite(rail.get("post"), pack.iso(p.x, p.y) + Vector2(0, -16.0 * pack.deck_at(p)), root)
	return root


## The unit way across a fence run through `p` along `dir` toward the side
## no room's floor covers; zero when rooms (or none) lie either side.
func _off_the_floor(p: Vector2, dir: Vector2) -> Vector2:
	var across := Vector2(-dir.y, dir.x)
	var left := not _on_a_floor(p + across * 0.3)
	var right := not _on_a_floor(p - across * 0.3)
	if left == right:
		return Vector2.ZERO
	return across if left else -across


func _on_a_floor(p: Vector2) -> bool:
	for id in pack.room_rects:
		if CityGeometry.rect_m(pack.room_rects[id]["rect"]).has_point(p):
			return true
	return false
