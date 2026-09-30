## The low-poly city around the rooms, assembled from the v2 kit
## (city/tools/styles/lowpoly): whole buildings from façade, corner and roof
## modules laid along each footprint, and the scenery from tiles and blocks.
## Small connective pieces (low walls for the cut-away, the library's main
## roof, road markings, the catenary wire) are batched meshes in the pack's
## palette.
extends KitTown

const HALL_BAY := 4.0
const HALL_H := 5.2
const LIB_BAY := 2.0
const LIB_H := 8.0
## A door bay: the door's opening, clear in the walking band, and a
## reveal either side its leaves fold into (the kit's DOOR_REVEAL). The
## door pieces are drawn for a 2 m door, DOOR_BAY wide.
const DOOR_REVEAL := 0.3
const DOOR_BAY := 2.0 + 2.0 * DOOR_REVEAL
## Near-façade stand-ins shown while a building is open.
const LOW_WALL := 0.6
const SIDEWALK := 1.6
## How far outside the bridge's deck its parapets' inner faces stand.
const PARAPET_CLEAR := 0.01
## How far above the style's deck height a bridge piece's own walking
## surface may stand before it counts as rising from the deck.
const DECK_TOP := 0.02

# ---- Buildings ----

func wall_height(b: Dictionary) -> float:
	return HALL_H if b["roof"] == "sawtooth" else LIB_H


## {root, roof, sides: {side: {full, low, normal}}, centre}. The walls
## stand outside the rooms, `wall` thick (the building kind's, spec §3):
## every piece's walking-band slice is fitted into that ring, and each
## door bay is as wide as its door, its opening clear.
func building(b: Dictionary) -> Dictionary:
	var hall := str(b["roof"]) == "sawtooth"
	var fp: Rect2 = b["footprint"]
	var wall: float = b.get("wall", 0.25)
	var root := Node3D.new()
	root.name = str(b["id"]).replace(":", "_")
	var sides := {}
	for s in b["sides"]:
		var full := Node3D.new()
		full.name = s["side"] + "_full"
		root.add_child(full)
		var a: Vector2 = s["a"]
		var bb: Vector2 = s["b"]
		var length := a.distance_to(bb)
		var along := (bb - a) / length
		var normal: Vector2 = s["normal"]
		var list := bays(length, s["openings"], HALL_BAY if hall else LIB_BAY, s["widths"].map(func(w): return w + 2.0 * DOOR_REVEAL))
		for k in list.size():
			var bay: Dictionary = list[k]
			var width: float = bay["t1"] - bay["t0"]
			var name_: String
			var nominal: float
			if hall:
				nominal = DOOR_BAY if bay["door"] else HALL_BAY
				name_ = "hall_door_wall" if bay["door"] else ("hall_wall" if width < HALL_BAY * 0.75 or k % 3 == 2 else "hall_window_wall")
			else:
				nominal = DOOR_BAY if bay["door"] else LIB_BAY
				name_ = "lib_entrance" if bay["door"] else "lib_wall_arch"
			fitted(full, name_, a, along, normal, bay["t0"], bay["t1"], 0.0, wall, nominal,
				("hall_wall" if hall else "lib_wall_arch") if bay["door"] else "")
			if bay["door"]:
				var leaves := "hall_door_leaves" if hall else "lib_door_leaves"
				fitted(full, leaves, a, along, normal, bay["t0"], bay["t0"] + DOOR_REVEAL, 0.0, wall)
				fitted(full, leaves, a, along, normal, bay["t1"] - DOOR_REVEAL, bay["t1"], 0.0, wall)
			if not hall:
				_column(full, a, along, normal, list, k, wall)
				if bay["door"]:
					for t in [bay["t0"] - 0.9, bay["t1"] + 0.9]:
						var g: Vector2 = a + along * t + normal * wall
						piece(full, "lib_banner", Vector3(g.x, 7.2, g.y), normal)
		if hall:
			# The pier fills the ring's corner square before the side.
			fitted(full, "hall_corner", a, along, normal, -wall, 0.0, 0.0, wall)
		var low := MeshBatch.new()
		low_wall(low, a, bb, normal, s["openings"], s["widths"], hall, wall)
		var ln := low.build(s["side"] + "_low")
		ln.visible = false
		root.add_child(ln)
		sides[s["side"]] = {"full": full, "low": ln, "normal": normal}
	var roof := Node3D.new()
	roof.name = "roof"
	root.add_child(roof)
	# The roof covers the walls too.
	if hall:
		_sawtooth(roof, fp.grow(wall))
	else:
		_library_roof(roof, fp.grow(wall))
	return {"root": root, "roof": roof, "sides": sides, "centre": fp.get_center()}


## The library's column at the start of bay `k` of `list`: in the ring's
## corner square at the side's start, beside a door's opening where a
## door bay starts or ends there (never across it), else centred on the
## joint.
func _column(parent: Node3D, a: Vector2, along: Vector2, normal: Vector2, list: Array, k: int, wall: float) -> void:
	var t: float = list[k]["t0"]
	var half := band_box("lib_column").size.x / 2.0
	var u := Vector2(t - half, t + half)
	if k == 0:
		u = Vector2(-wall, 0.0)
	elif list[k]["door"]:
		u = Vector2(t - 2.0 * half, t)
	elif list[k - 1]["door"]:
		u = Vector2(t, t + 2.0 * half)
	fitted(parent, "lib_column", a, along, normal, u.x, u.y, 0.0, wall)


## Sawtooth roof tiles over the whole footprint, ridges running north–south,
## and a gable closing each tooth at both ends.
func _sawtooth(roof: Node3D, fp: Rect2) -> void:
	var cols := maxi(1, int(round(fp.size.x / HALL_BAY)))
	var rows := maxi(1, int(round(fp.size.y / HALL_BAY)))
	var sx := fp.size.x / (cols * HALL_BAY)
	var sz := fp.size.y / (rows * HALL_BAY)
	for i in cols:
		var x := fp.position.x + (i + 0.5) * HALL_BAY * sx
		for j in rows:
			var z := fp.position.y + (j + 0.5) * HALL_BAY * sz
			piece(roof, "hall_sawtooth_bay", Vector3(x, HALL_H, z), Vector2(0, -1), Vector3(sx, 1, sz))
		for z in [fp.position.y + 0.1, fp.end.y - 0.1]:
			piece(roof, "hall_sawtooth_gable", Vector3(x, HALL_H, z), Vector2(0, -1), Vector3(sx, 1, 1))


## A green-copper hip roof on a stone cornice, and the ribbed dome on its
## drum rising through it at the south-east.
func _library_roof(roof: Node3D, fp: Rect2) -> void:
	var bt := MeshBatch.new()
	bt.block(Vector3(fp.position.x + 0.1, LIB_H - 0.05, fp.position.y + 0.1), Vector3(fp.end.x - 0.1, LIB_H + 0.15, fp.end.y - 0.1), mat("sandstone"))
	bt.hip_roof(fp.size.x - 1.2, fp.size.y - 1.2, 2.4, Vector3(fp.get_center().x, LIB_H + 0.15, fp.get_center().y),
		MeshBatch.material(c("copper"), 0.5, Color(0, 0, 0, 0), 0.25), 0.1)
	roof.add_child(bt.build("slopes"))
	var r := 4.6
	piece(roof, "lib_dome", Vector3(fp.end.x - r - 1.0, LIB_H - 0.2, fp.end.y - r - 1.0))


## A low wall along a side in the shell's ring, `wall` thick outside the
## rooms, with a gap as wide as each door (the cut-away shows it instead
## of the façade).
func low_wall(bt: MeshBatch, a: Vector2, b: Vector2, normal: Vector2, openings: Array, widths: Array, hall: bool, wall: float) -> void:
	var length := a.distance_to(b)
	var along := (b - a) / length
	var basis := Basis(Vector3(along.x, 0, along.y), Vector3.UP, Vector3(normal.x, 0, normal.y))
	var cuts := [0.0]
	for k in openings.size():
		cuts.append(openings[k] - widths[k] / 2.0)
		cuts.append(openings[k] + widths[k] / 2.0)
	cuts.append(length)
	for k in range(0, cuts.size(), 2):
		var t0: float = cuts[k]
		var t1: float = cuts[k + 1]
		if t1 - t0 < 0.05:
			continue
		var g: Vector2 = a + along * ((t0 + t1) / 2.0) + normal * wall / 2.0
		bt.box(Vector3(t1 - t0, LOW_WALL, wall), Transform3D(basis, Vector3(g.x, LOW_WALL / 2.0, g.y)), mat("brick" if hall else "limewash"))
		bt.box(Vector3(t1 - t0, 0.08, wall), Transform3D(basis, Vector3(g.x, LOW_WALL + 0.04, g.y)), mat("wood" if hall else "sandstone"))


# ---- Scenery ----

func ground(rects: Array, _floors := [], _near := Rect2()) -> Node3D:
	var bt := MeshBatch.new()
	for g in rects:
		bt.block(Vector3(g.position.x, -0.4, g.position.y), Vector3(g.end.x, -0.02, g.end.y), mat("grass"))
	return bt.build("Ground", false)


func water(rect: Rect2) -> Node3D:
	var root := Node3D.new()
	var xf := []
	var nx := int(ceil(rect.size.x / 4.0))
	var nz := int(ceil(rect.size.y / 4.0))
	var sx := rect.size.x / (nx * 4.0)
	var sz := rect.size.y / (nz * 4.0)
	for i in nx:
		for j in nz:
			var at := Vector3(rect.position.x + (i + 0.5) * 4.0 * sx, water_y, rect.position.y + (j + 0.5) * 4.0 * sz)
			xf.append(Transform3D(Basis().scaled(Vector3(sx, 1, sz)), at))
	root.add_child(tiles("water_tile", xf, "Surface"))
	# The riverbed, and stone quays along both banks with a coping.
	var bt := MeshBatch.new()
	var bed := water_y - 2.05
	bt.block(Vector3(rect.position.x, bed, rect.position.y), Vector3(rect.end.x, water_y - 1.05, rect.end.y), mat("water_deep"))
	for x in [rect.position.x, rect.end.x]:
		var inward := 1.0 if x == rect.position.x else -1.0
		bt.block(Vector3(x - 0.5 * inward - 0.4, bed, rect.position.y), Vector3(x - 0.5 * inward + 0.4, 0.0, rect.end.y), mat("stone"))
		bt.block(Vector3(x - 0.5 * inward - 0.55, 0.0, rect.position.y), Vector3(x - 0.5 * inward + 0.55, 0.15, rect.end.y), mat("sandstone"))
	root.add_child(bt.build("Quays"))
	return root


## Stone arches of about 8 m across the water, a pier at every joint
## between them; the deck sits a little above the street at both ends.
## `opts`: the deck's
## `width` (metres), its `height` (the style's bridge_deck) and the
## bridge's own room (`deck`, a Rect2). The arches span the part of the
## line that room covers, stretched across so their parapets stand just
## outside the deck (spec §7); beyond it, where the line runs on over
## other ground, the deck carries on as a plain landing, open either side.
func bridge(a: Vector2, b: Vector2, opts := {}) -> Node3D:
	var root := Node3D.new()
	var full := a.distance_to(b)
	var along := (b - a) / full
	var half := float(opts.get("width", 4.0)) / 2.0
	var height := float(opts.get("height", 0.0))
	var span := Vector2(0.0, full)
	var deck: Rect2 = opts.get("deck", Rect2())
	if deck.has_area():
		var ts := [deck.position, deck.end, Vector2(deck.position.x, deck.end.y), Vector2(deck.end.x, deck.position.y)].map(
			func(p): return (p - a).dot(along))
		span = Vector2(clampf(ts.min(), 0.0, full), clampf(ts.max(), 0.0, full))
	var length := span.y - span.x
	var n := maxi(1, int(round(length / 8.0)))
	var s := length / (n * 8.0)
	var facing := Vector2(-along.y, along.x)
	var y := -0.9
	# Whatever rises above the deck, in the pieces' own heights: beside
	# the deck the band is measured from the ground (or water) below, so a
	# parapet's kerb counts too.
	var band := Vector2(height + DECK_TOP - y, height + 1.9 - y)
	var across := (half + PARAPET_CLEAR) / clear_half_width("bridge_span", band)
	for k in n:
		var mid: Vector2 = a + along * (span.x + (k + 0.5) * 8.0 * s)
		piece(root, "bridge_span", Vector3(mid.x, y, mid.y), facing, Vector3(s, 1, across))
	across = (half + PARAPET_CLEAR) / clear_half_width("bridge_pier", band)
	# Piers stand at the joints between arches, not at the ends, where
	# the deck meets the ground beyond it.
	for k in range(1, n):
		var joint: Vector2 = a + along * (span.x + k * 8.0 * s)
		piece(root, "bridge_pier", Vector3(joint.x, y, joint.y), facing, Vector3(1, 1, across))
	var bt := MeshBatch.new()
	var basis := Basis(Vector3(along.x, 0, along.y), Vector3.UP, Vector3(facing.x, 0, facing.y))
	for landing in [Vector2(0.0, span.x), Vector2(span.y, full)]:
		if landing.y - landing.x > 0.05:
			var mid: Vector2 = a + along * (landing.x + landing.y) / 2.0
			bt.box(Vector3(landing.y - landing.x, height, half * 2.0), Transform3D(basis, Vector3(mid.x, height / 2.0, mid.y)), mat("paving"))
	if not bt.is_empty():
		root.add_child(bt.build("Landing"))
	return root


func street(points: Array, width: float) -> Node3D:
	var root := Node3D.new()
	var road := []
	var kerbs := []
	var bt := MeshBatch.new()
	for k in range(1, points.size()):
		var a: Vector2 = points[k - 1]
		var b: Vector2 = points[k]
		var along := (b - a).normalized()
		var side := Vector2(-along.y, along.x)
		var length := a.distance_to(b)
		var basis := Basis(Vector3(along.x, 0, along.y), Vector3.UP, Vector3(side.x, 0, side.y))
		var nl := maxi(1, int(round(length / 2.0)))
		var nw := maxi(1, int(round(width / 2.0)))
		var sl := length / (nl * 2.0)
		var sw := width / (nw * 2.0)
		for i in nl:
			for j in nw:
				var g: Vector2 = a + along * (i + 0.5) * 2.0 * sl + side * ((j + 0.5) * 2.0 * sw - width / 2.0)
				road.append(Transform3D(basis.scaled_local(Vector3(sl, 1, sw)), Vector3(g.x, 0.0, g.y)))
			for sgn in [-1.0, 1.0]:
				var g: Vector2 = a + along * (i + 0.5) * 2.0 * sl + side * sgn * (width / 2.0 + 0.17)
				# The kerb's road side (its local +Z) faces the carriageway.
				var inward := Vector3(-side.x * sgn, 0, -side.y * sgn)
				var kb := Basis(Vector3.UP.cross(inward), Vector3.UP, inward)
				kerbs.append(Transform3D(kb.scaled_local(Vector3(sl, 1, 1)), Vector3(g.x, 0.08, g.y)))
		if width >= 5.0:
			var t := 1.0
			while t < length - 1.0:
				var g: Vector2 = a + along * (t + 0.9)
				bt.box(Vector3(1.8, 0.02, 0.16), Transform3D(basis, Vector3(g.x, 0.01, g.y)), mat("limewash"))
				t += 4.5
		# Sidewalks: sandstone slabs outside both kerbs, jointed every 1.6 m.
		for sgn in [-1.0, 1.0]:
			var off: float = sgn * (width / 2.0 + 0.34 + SIDEWALK / 2.0)
			var mid: Vector2 = (a + b) / 2.0 + side * off
			bt.box(Vector3(length, 0.1, SIDEWALK), Transform3D(basis, Vector3(mid.x, 0.03, mid.y)), mat("paving"))
			var j := 0.8
			while j < length:
				var g: Vector2 = a + along * j + side * off
				bt.box(Vector3(0.05, 0.1, SIDEWALK), Transform3D(basis, Vector3(g.x, 0.035, g.y)), mat("paving_dark"))
				j += 1.6
	root.add_child(tiles("street_tile", road, "Road"))
	root.add_child(tiles("street_kerb", kerbs, "Kerbs"))
	if not bt.is_empty():
		root.add_child(bt.build("Markings", false))
	return root


func tram_line(points: Array) -> Node3D:
	var root := Node3D.new()
	var track := []
	var bt := MeshBatch.new()
	for k in range(1, points.size()):
		var a: Vector2 = points[k - 1]
		var b: Vector2 = points[k]
		var along := (b - a).normalized()
		var side := Vector2(-along.y, along.x)
		var length := a.distance_to(b)
		var basis := Basis(Vector3(along.x, 0, along.y), Vector3.UP, Vector3(side.x, 0, side.y))
		var n := maxi(1, int(round(length / 2.0)))
		var s := length / (n * 2.0)
		for i in n:
			var g: Vector2 = a + along * (i + 0.5) * 2.0 * s
			track.append(Transform3D(basis.scaled_local(Vector3(s, 1, 1)), Vector3(g.x, 0.02, g.y)))
		# The catenary wire; its poles are the layout's catenary-pole
		# placements, their arms reaching out over it.
		var mid := (a + b) / 2.0
		bt.box(Vector3(length, 0.03, 0.03), Transform3D(basis, Vector3(mid.x, 5.7, mid.y)), mat("iron"))
	root.add_child(tiles("tram_track", track, "Track"))
	root.add_child(bt.build("Catenary"))
	return root


## The kit's tram, drawn as wide as the tram kind (250 cm, the width the
## core keeps clear round it) where people stand beside it.
func tram() -> Node3D:
	var root := Node3D.new()
	root.name = "Tram"
	# The kit's tram runs along its x; the pack turns this node to travel.
	fit_tram_width(piece(root, "tram", Vector3.ZERO, Vector2(0, -1)), "tram")
	return root


## A block cut into lots, each holding a house, shop or tower that faces
## `toward` (the district's heart), fitted to its lot, and a garden wall
## round the whole block on its edge: the block's lot is blocked ground, so
## what bounds it where people walk is drawn (spec §7).
## A block's lot of buildings on `rect`, facing `toward`, in a garden wall
## whose gate faces `street` (the nearest street's nearest point).
func block(rect: Rect2, height_class: String, seed_: String, toward := Vector2.ZERO, street := Vector2.INF) -> Node3D:
	var root := Node3D.new()
	_lot_wall(root, rect, street)
	var d := toward - rect.get_center()
	var facing := Vector2(signf(d.x), 0) if absf(d.x) > absf(d.y) else Vector2(0, signf(d.y) if d.y != 0.0 else 1.0)
	var along_x := facing.x == 0.0
	match height_class:
		"tower":
			var lot := rect.grow(-1.0)
			var s := minf(lot.size.x, lot.size.y) / 11.36
			piece(root, "tower_a", Vector3(lot.get_center().x, 0, lot.get_center().y), facing, Vector3.ONE * clampf(s, 0.8, 1.25))
		_:
			var shop := height_class == "shop"
			var width := 4.92 if shop else 6.63
			var depth := 8.95 if shop else 9.0
			var lots: Array = []
			var span := rect.size.x if along_x else rect.size.y
			var n := maxi(1, int(round(span / (width + 0.8))))
			for k in n:
				if along_x:
					lots.append(Rect2(rect.position.x + span / n * k, rect.position.y, span / n, rect.size.y))
				else:
					lots.append(Rect2(rect.position.x, rect.position.y + span / n * k, rect.size.x, span / n))
			for k in lots.size():
				var lot: Rect2 = lots[k].grow(-0.4)
				var lot_w := lot.size.x if along_x else lot.size.y
				var lot_d := lot.size.y if along_x else lot.size.x
				var name_ := "shop_a" if shop else ("house_a" if _hash01(seed_ + str(k)) < 0.5 else "house_b")
				# Never wider or deeper where people walk than its lot, inside
				# the garden wall.
				var box := band_box(name_)
				var sw := minf(clampf(lot_w / width, 0.7, 1.15), lot_w / box.size.x)
				var sd := minf(clampf(lot_d / depth, 0.7, 1.15), lot_d / box.size.y)
				var off := Vector3(box.get_center().x * sw, 0, box.get_center().y * sd)
				var at := Vector3(lot.get_center().x, 0, lot.get_center().y) - Basis(Vector3.UP, yaw_to(facing)) * off
				piece(root, name_, at, facing, Vector3(sw, minf(sw, sd), sd))
	return root
