## The voxel city around the rooms, assembled from the v2 voxel kit
## (city/tools/styles/voxel, 10 cm voxels): the yellow sawtooth workshop and
## the orange barrel-vault library from their wall, corner, door and roof
## modules along each footprint (with low twins for the cut-away), and the
## river, bridge, streets, tram, blocks and ground from tiles and pieces.
extends KitTown

## The workshop's walls and bays, and the library's.
const WS_H := 5.0
const WS_BAY := 4.0
const LIB_H := 6.0
const LIB_BAY := 2.0
## A door piece (ws_door, lib_entrance) is drawn DOOR_PIECE wide round an
## opening DOOR_OPENING wide, clear in the walking band; a door's bay is
## the piece stretched so that opening is as wide as the door.
const DOOR_PIECE := 4.0
const DOOR_OPENING := 2.0
## The vault's span; a wider or narrower library stretches it.
const VAULT_SPAN := 18.0


## Modules along a side: [{"t", "w", "kind"}], `t` the centre's distance
## from the side's start. A door bay on each opening, its piece's opening
## as wide as the door (`widths`, metres, one per opening); between them
## `unit` modules following `pattern`, a `half` where the unit grid
## breaks, and each run stretched a little to fit exactly.
static func modules(length: float, openings: Array, widths: Array, unit: float, half: float, pattern: Array) -> Array:
	var out := []
	var cursor := 0.0
	var marks := []
	for k in openings.size():
		marks.append([openings[k], widths[k] * DOOR_PIECE / DOOR_OPENING])
	marks.sort()
	for o in marks:
		var d0: float = clampf(o[0] - o[1] / 2.0, cursor, length)
		_run(out, cursor, d0, unit, half, pattern)
		var d1: float = minf(o[0] + o[1] / 2.0, length)
		out.append({"t": (d0 + d1) / 2.0, "w": d1 - d0, "kind": "door"})
		cursor = d1
	_run(out, cursor, length, unit, half, pattern)
	return out


static func _run(out: Array, a: float, b: float, unit: float, half: float, pattern: Array) -> void:
	var span := b - a
	if span < 0.05:
		return
	var widths := []
	var left := span
	while left >= unit - 0.01:
		widths.append(unit)
		left -= unit
	if left >= half * 0.5 or widths.is_empty():
		widths.append(half)
	var total := 0.0
	for w in widths:
		total += w
	var s := span / total
	var t := a
	for k in widths.size():
		var w: float = widths[k] * s
		var kind: String = "half" if widths[k] < unit else str(pattern[k % pattern.size()])
		out.append({"t": t + w / 2.0, "w": w, "kind": kind})
		t += w


# ---- Buildings ----

## {root, roof, sides: {side: {full, low, normal}}, centre}. The walls
## stand outside the rooms, `wall` thick (the building kind's, spec §3):
## every module's walking-band slice is fitted into that ring, the corner
## piers fill its corner squares, and each door bay's opening is as wide
## as its door.
func building(b: Dictionary) -> Dictionary:
	var hall := str(b["roof"]) == "sawtooth"
	var fp: Rect2 = b["footprint"]
	var wall: float = b.get("wall", 0.25)
	var root := Node3D.new()
	root.name = str(b["id"]).replace(":", "_")
	var sides := {}
	var signed := false
	for s in b["sides"]:
		var full := Node3D.new()
		full.name = s["side"] + "_full"
		var low := Node3D.new()
		low.name = s["side"] + "_low"
		low.visible = false
		root.add_child(full)
		root.add_child(low)
		var a: Vector2 = s["a"]
		var bb: Vector2 = s["b"]
		var length := a.distance_to(bb)
		var along := (bb - a) / length
		var normal: Vector2 = s["normal"]
		var across: bool = s["side"] in ["north", "south"]
		var pattern: Array = (["window", "glazed"] if across else ["window", "wall"]) if hall else ["plain", "wall"]
		# A door bay keeps in line with the wall bays beside it.
		var plain := "ws_wall" if hall else "lib_wall_plain"
		for m in modules(length, s["openings"], s["widths"], WS_BAY if hall else LIB_BAY, 2.0, pattern):
			var names := _module_names(hall, str(m["kind"]))
			var nominal := DOOR_PIECE if m["kind"] == "door" else (2.0 if m["kind"] == "half" else (WS_BAY if hall else LIB_BAY))
			var t0: float = m["t"] - m["w"] / 2.0
			var t1: float = m["t"] + m["w"] / 2.0
			var door: bool = m["kind"] == "door"
			fitted(full, names[0], a, along, normal, t0, t1, 0.0, wall, nominal, plain if door else "")
			fitted(low, names[1], a, along, normal, t0, t1, 0.0, wall, nominal, ("ws_wall_low" if hall else "lib_wall_low") if door else "")
			if m["kind"] == "door" and not signed:
				# One name board a building, over its first door, on the
				# wall's face.
				signed = true
				var at: Vector2 = a + along * float(m["t"]) + normal * wall
				piece(full, "ws_sign" if hall else "lib_sign", Vector3(at.x, 3.5 if hall else 4.3, at.y), normal)
		# The corner pier at the side's start belongs to this side: it
		# fills the ring's corner square there.
		fitted(full, "ws_corner" if hall else "lib_corner", a, along, normal, -wall, 0.0, 0.0, wall)
		fitted(low, "ws_corner_low" if hall else "lib_corner_low", a, along, normal, -wall, 0.0, 0.0, wall)
		sides[s["side"]] = {"full": full, "low": low, "normal": normal}
	var roof := Node3D.new()
	roof.name = "roof"
	root.add_child(roof)
	# The roof covers the walls too.
	if hall:
		_sawtooth(roof, fp.grow(wall))
	else:
		_vault(roof, fp.grow(wall))
	return {"root": root, "roof": roof, "sides": sides, "centre": fp.get_center()}


## [full, low] module names for a bay of `kind`.
static func _module_names(hall: bool, kind: String) -> Array:
	if hall:
		match kind:
			"door":
				return ["ws_door", "ws_door_low"]
			"half":
				return ["ws_wall_half", "ws_wall_low_half"]
			"glazed":
				return ["ws_wall_glazed", "ws_wall_low"]
			"wall":
				return ["ws_wall", "ws_wall_low"]
		return ["ws_window", "ws_wall_low"]
	match kind:
		"door":
			return ["lib_entrance", "lib_entrance_low"]
		"plain":
			return ["lib_wall_plain", "lib_wall_low"]
	return ["lib_wall", "lib_wall_low"]


## Sawtooth teeth every 4 m along z, ridges running along x and glazing
## facing south towards the square's diagonal, as on the sheets; a gable
## closes each tooth at the west and east ends.
func _sawtooth(roof: Node3D, fp: Rect2) -> void:
	var cols := maxi(1, int(round(fp.size.x / WS_BAY)))
	var rows := maxi(1, int(round(fp.size.y / WS_BAY)))
	var sx := fp.size.x / (cols * WS_BAY)
	var sz := fp.size.y / (rows * WS_BAY)
	var east := Vector2(1, 0)
	for j in rows:
		var z := fp.position.y + (j + 0.5) * WS_BAY * sz
		for i in cols:
			# A bay turned east runs its ridge west from its origin.
			piece(roof, "ws_roof_bay", Vector3(fp.position.x + (i + 1) * WS_BAY * sx, WS_H, z), east, Vector3(sz, 1, sx))
		piece(roof, "ws_gable", Vector3(fp.position.x + 0.3, WS_H, z), east, Vector3(sz, 1, 1))
		piece(roof, "ws_gable", Vector3(fp.end.x, WS_H, z), east, Vector3(sz, 1, 1))


## The orange barrel vault along the library's length (z), a white rounded
## cap at each end and 2 m segments between.
func _vault(roof: Node3D, fp: Rect2) -> void:
	var cx := fp.get_center().x
	var sx := fp.size.x / VAULT_SPAN
	piece(roof, "lib_vault_end", Vector3(cx, LIB_H, fp.position.y), Vector2(0, -1), Vector3(sx, 1, 1))
	piece(roof, "lib_vault_end", Vector3(cx, LIB_H, fp.end.y), Vector2(0, 1), Vector3(sx, 1, 1))
	var inner := fp.size.y - 8.0
	var n := maxi(0, int(round(inner / 2.0)))
	var sz := inner / (n * 2.0) if n > 0 else 1.0
	for k in n:
		piece(roof, "lib_vault", Vector3(cx, LIB_H, fp.position.y + 4.0 + (k + 0.5) * 2.0 * sz), Vector2(0, -1), Vector3(sx, 1, sz))


# ---- Scenery ----

## Lawn tiles over the land near the district, leaving the rooms (they
## have floors) open, and a flat lawn beyond, to the horizon.
func ground(rects: Array, floors: Array, near: Rect2) -> Node3D:
	var root := Node3D.new()
	root.name = "Ground"
	var xf := []
	for r in rects:
		var area: Rect2 = r.intersection(near)
		if area.size.x <= 0.0 or area.size.y <= 0.0:
			continue
		var z: float = floor(area.position.y / 2.0) * 2.0 + 1.0
		while z < area.end.y:
			var x: float = floor(area.position.x / 2.0) * 2.0 + 1.0
			while x < area.end.x:
				var p := Vector2(x, z)
				if not floors.any(func(f): return f.grow(0.5).has_point(p)):
					xf.append(Transform3D(Basis(), Vector3(x, -0.02, z)))
				x += 2.0
			z += 2.0
	root.add_child(tiles("lawn_tile", xf, "Lawn"))
	var bt := MeshBatch.new()
	for r in rects:
		for part in CityGeometry.subtract(r, near):
			bt.block(Vector3(part.position.x, -0.5, part.position.y), Vector3(part.end.x, -0.12, part.end.y), mat("lawn", 0.95))
	if not bt.is_empty():
		root.add_child(bt.build("Far", false))
	return root


func water(rect: Rect2) -> Node3D:
	var root := Node3D.new()
	var xf := []
	var nx := int(ceil(rect.size.x / 4.0))
	var nz := int(ceil(rect.size.y / 4.0))
	var sx := rect.size.x / (nx * 4.0)
	var sz := rect.size.y / (nz * 4.0)
	for i in nx:
		for j in nz:
			xf.append(Transform3D(Basis().scaled(Vector3(sx, 1, sz)), Vector3(rect.position.x + (i + 0.5) * 4.0 * sx, -2.0, rect.position.y + (j + 0.5) * 4.0 * sz)))
	root.add_child(tiles("water_tile", xf, "Surface"))
	# Stone quays down both banks, their water side facing the river.
	var quays := []
	var z := rect.position.y
	while z < rect.end.y - 0.01:
		quays.append(Transform3D(Basis(Vector3.UP, yaw_to(Vector2(1, 0))), Vector3(rect.end.x, 0, z + 1.0)))
		quays.append(Transform3D(Basis(Vector3.UP, yaw_to(Vector2(-1, 0))), Vector3(rect.position.x, 0, z + 1.0)))
		z += 2.0
	root.add_child(tiles("quay", quays, "Quays", true))
	return root


## How far outside the bridge's deck its parapets' inner faces stand.
const PARAPET_CLEAR := 0.01
## How far above the deck a span's own surfaces may stand and still be
## deck: its raised pavements (10 cm) are walked on, as low steps are.
const DECK_TOP := 0.12


## Grey stone spans 4 m at a time, a pier every other joint. `opts`: the
## deck's `width` (metres), its `height` (the style's bridge_deck) and the
## bridge's own room (`deck`, a Rect2). The spans cover the part of the
## line that room covers, stretched across so their parapets stand just
## outside the deck (spec §7); beyond it the line runs on over ground the
## deck is level with, and needs no span.
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
	var n := maxi(1, int(round(length / 4.0)))
	var s := length / (n * 4.0)
	var facing := Vector2(-along.y, along.x)
	# The deck's top is the pieces' y = 0; what rises above it in the band
	# is the parapets.
	var across := (half + PARAPET_CLEAR) / clear_half_width("bridge_span", Vector2(DECK_TOP, 1.9))
	for k in n:
		var mid: Vector2 = a + along * (span.x + (k + 0.5) * 4.0 * s)
		piece(root, "bridge_span", Vector3(mid.x, height, mid.y), facing, Vector3(s, 1, across))
	for k in range(2, n - 1, 2):
		var joint: Vector2 = a + along * (span.x + k * 4.0 * s)
		piece(root, "bridge_pier", Vector3(joint.x, height, joint.y), facing, Vector3(1, 1, across))
	return root


func street(points: Array, width: float) -> Node3D:
	var root := Node3D.new()
	var plain := []
	var dashed := []
	var kerbs := []
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
				var xf := Transform3D(basis.scaled_local(Vector3(sl, 1, sw)), Vector3(g.x, 0.0, g.y))
				# The centre line: a dash every other tile on wide streets.
				if nw >= 3 and j == nw / 2 and i % 2 == 0:
					dashed.append(xf)
				else:
					plain.append(xf)
			for sgn in [-1.0, 1.0]:
				var g: Vector2 = a + along * (i + 0.5) * 2.0 * sl + side * sgn * (width / 2.0 + 0.15)
				kerbs.append(Transform3D(basis.scaled_local(Vector3(sl, 1, 1)), Vector3(g.x, 0.0, g.y)))
	root.add_child(tiles("street_tile", plain, "Road"))
	if not dashed.is_empty():
		root.add_child(tiles("street_dash", dashed, "Dashes"))
	root.add_child(tiles("kerb", kerbs, "Kerbs"))
	return root


func tram_line(points: Array) -> Node3D:
	var root := Node3D.new()
	var track := []
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
			track.append(Transform3D(basis.scaled_local(Vector3(s, 1, 1)), Vector3(g.x, 0.01, g.y)))
	root.add_child(tiles("tram_track", track, "Track"))
	return root


## The kit's tram, drawn as wide as the tram kind (250 cm, the width the
## core keeps clear round it) where people stand beside it.
func tram() -> Node3D:
	var root := Node3D.new()
	root.name = "Tram"
	# The kit's tram runs along its x; the pack turns this node to travel.
	fit_tram_width(piece(root, "tram", Vector3(0, 0.1, 0), Vector2(0, -1)), "tram")
	return root


## A block cut into lots, each holding a house, shop or tower facing
## `toward` (the district's heart), fitted to its lot and never wider or
## deeper than it where people walk, in a garden wall on the block's edge
## whose closed gate faces `street` (the nearest street's nearest point):
## the block's lot is blocked ground, so what bounds it is drawn (spec §7).
func block(rect: Rect2, height_class: String, seed_: String, toward := Vector2.ZERO, street := Vector2.INF) -> Node3D:
	var root := Node3D.new()
	_lot_wall(root, rect, street)
	var d := toward - rect.get_center()
	var facing := Vector2(signf(d.x), 0) if absf(d.x) > absf(d.y) else Vector2(0, signf(d.y) if d.y != 0.0 else 1.0)
	var along_x := facing.x == 0.0
	if height_class == "tower":
		var lot := rect.grow(-0.5)
		var name_ := "tower_a" if _hash01(seed_) < 0.5 else "tower_b"
		var size := 14.0 if name_ == "tower_a" else 12.8
		# Square, and never wider than its lot where people walk.
		var box := band_box(name_)
		var side := minf(lot.size.x, lot.size.y)
		var s := minf(clampf(side / size, 0.7, 1.1), side / maxf(box.size.x, box.size.y))
		var at := Vector3(lot.get_center().x, 0, lot.get_center().y) - Basis(Vector3.UP, yaw_to(facing)) * Vector3(box.get_center().x * s, 0, box.get_center().y * s)
		piece(root, name_, at, facing, Vector3.ONE * s)
		return root
	var shop := height_class == "shop"
	var width := 6.0
	var depth := 6.8 if shop else 6.0
	var span := rect.size.x if along_x else rect.size.y
	var n := maxi(1, int(round(span / (width + 0.8))))
	for k in n:
		var lot := Rect2(rect.position.x + span / n * k, rect.position.y, span / n, rect.size.y) if along_x \
			else Rect2(rect.position.x, rect.position.y + span / n * k, rect.size.x, span / n)
		lot = lot.grow(-0.4)
		var lot_w := lot.size.x if along_x else lot.size.y
		var lot_d := lot.size.y if along_x else lot.size.x
		var name_ := "shop_a" if shop else ("house_a" if _hash01(seed_ + str(k)) < 0.55 else "house_b")
		var box := band_box(name_)
		var sw := minf(clampf(lot_w / width, 0.7, 1.2), lot_w / box.size.x)
		var sd := minf(clampf(lot_d / depth, 0.7, 1.2), lot_d / box.size.y)
		var off := Vector3(box.get_center().x * sw, 0, box.get_center().y * sd)
		var at := Vector3(lot.get_center().x, 0, lot.get_center().y) - Basis(Vector3.UP, yaw_to(facing)) * off
		piece(root, name_, at, facing, Vector3(sw, minf(sw, sd), sd))
	return root
