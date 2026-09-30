## The collision audit, run in every style (spec §1, success 1): what each
## draws against the core's walkable grid, counted six ways and held to
## evidence/placement-budget.json. A count above its budget fails, naming
## every offender; so does a count below it, so a budget comes down in the
## same commit that earns it, and never creeps back up.
## (tools/collision_audit.gd --write-budget writes the current counts.)
extends TestSuite

const BUDGET := "res://evidence/placement-budget.json"
const Solid = preload("res://tools/collision_audit/solid.gd")
const Solids3D = preload("res://tools/collision_audit/solids_3d.gd")
const Solids2D = preload("res://tools/collision_audit/solids_2d.gd")
## How many of a gate's offenders an over-budget failure prints.
const SHOWN := 20


func _budget() -> Dictionary:
	var text := FileAccess.get_file_as_string(BUDGET)
	var parsed = JSON.parse_string(text) if text != "" else null
	return parsed if parsed is Dictionary else {}


func test_every_style_keeps_to_its_collision_budget() -> void:
	var budget := _budget()
	assert_true(not budget.is_empty(), "%s holds a budget" % BUDGET)
	for style in CollisionAudit.STYLES:
		var result: Dictionary = await CollisionAudit.run(style, {"ticks": CollisionAudit.DAY_TICKS})
		assert_true(not result.has("error"), "%s activates" % style)
		if result.has("error"):
			continue
		# A kit sprite the audit cannot measure, or a MultiMesh whose pieces
		# it cannot place headless, would pass unseen.
		assert_eq(result["info"]["unmeasured_sprites"], {}, "%s draws only sprites the audit measures" % style)
		assert_eq(result["info"]["unplaced_multimeshes"], {}, "%s keeps every MultiMesh's transforms" % style)
		var allowed: Dictionary = budget.get(style, {})
		for gate in CollisionAudit.GATES:
			var count: int = result[gate]["count"]
			var limit := int(allowed.get(gate, -1))
			if count > limit:
				print("  %s %s by kind: %s" % [style, gate, result[gate]["by_kind"]])
				for o in result[gate]["offenders"].slice(0, SHOWN):
					print("  %s %s: %s" % [style, gate, _describe(o)])
			assert_eq(count, limit, "%s %s against its budget (%s)" % [style, gate,
				"over: its offenders by kind and the first %d are listed above" % SHOWN if count > limit
				else "under: lower the budget to %d" % count])


## One offender on a line: what it is, whose, where, and how deep.
static func _describe(o: Dictionary) -> String:
	var whose := str(o.get("placement_id", o.get("building", o.get("mesh", ""))))
	var text := "%s %s at cell (%d, %d), %d cm" % [o["kind"], whose, o["cell"][0], o["cell"][1], o["depth_cm"]]
	if o.has("visits"):
		text += ", %d visits" % o["visits"]
	return text


func test_a_solid_is_read_by_its_centres_distance() -> void:
	# A 1 m box: a centre inside it is through it, one 5 cm off is 5 cm
	# from it, and one beyond the clearance is not read at all.
	var box = Solid.new()
	var square := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	box.pieces.append(square)
	box.contours.append(square)
	box.pixel = 0.001
	box.place(Transform2D.IDENTITY)
	assert_true(box.probe(Vector2(0.5, 0.5), 0.1) < 0.0, "a centre inside is through")
	assert_true(absf(box.probe(Vector2(1.05, 0.5), 0.1) - 0.05) < 1e-4, "a centre 5 cm off is 5 cm from it")
	assert_eq(box.probe(Vector2(1.5, 0.5), 0.1), INF, "a centre beyond the clearance is not read")


func test_what_a_solids_faces_enclose_is_inside_it() -> void:
	# A wall seen from above is its faces: four segments round a 1 m
	# square. What they enclose is solid; outside them is not.
	var faces: Array[PackedVector2Array] = []
	var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for k in 4:
		faces.append(PackedVector2Array([corners[k], corners[(k + 1) % 4]]))
	var wall = Solid.new()
	wall.pieces = faces
	wall.contours = Solids3D._trace(faces, Solids3D.PIXEL)
	wall.pixel = Solids3D.PIXEL
	wall.place(Transform2D.IDENTITY)
	assert_true(wall.probe(Vector2(0.5, 0.5), 0.1) < -0.4, "the middle is 0.5 m inside")
	assert_true(wall.probe(Vector2(0.995, 0.5), 0.1) <= 0.0, "just inside a face is through")
	var gap: float = wall.probe(Vector2(1.08, 0.5), 0.1)
	assert_true(gap > 0.07 and gap < 0.09, "8 cm outside a face is 8 cm from it (%f)" % gap)


## An audit of a bare 12 × 12 cell floor holding one seat of `kind` at
## `pos` (metres) facing `facing`, and `solids` (Solid discs, [x, z, r] in
## metres, and their owner's ID).
func _seat_audit(kind: String, pos: Vector2, facing: float, solids: Array) -> CollisionAudit:
	var audit := CollisionAudit.new()
	var nav := NavQuery.new()
	nav.cols = 12
	nav.rows = 12
	nav._room.resize(144)
	nav._room.fill(0)
	audit.nav = nav
	audit.near.resize(144)
	audit.near.fill(1)
	audit.add_seat("seat:s", kind, pos, facing)
	for s in solids:
		var disc = Solid.new()
		disc.owner = {"kind": kind, "placement_id": s[1]}
		disc.discs.append(s[0])
		disc.place(Transform2D.IDENTITY)
		audit.solids.append(disc)
	audit._nearest()
	return audit


static func _cells(gate: Dictionary) -> Array:
	return gate["offenders"].map(func(o): return Vector2i(o["cell"][0], o["cell"][1]))


## Cell `c`'s centre, metres.
static func _centre(c: Vector2i) -> Vector2:
	return (Vector2(c) * 25.0 + Vector2(12, 12)) / 100.0


func test_a_seats_own_furniture_is_exempt_within_its_protected_square() -> void:
	# A seat on a cell corner (as the district's are): the four cells round
	# it lie within 25 cm of its point, the square the sitter sits and
	# turns in. Its own furniture there (the chair, the bench's seat) is
	# neither through nor near them; at a cell outside the square it
	# counts, and another seat's furniture counts inside it too.
	var corner := Vector2(1.25, 1.25)
	for kind in ["desk", "workstation", "bench", "cafe-table", "reading-chair"]:
		var own := []
		for c in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)]:
			own.append([Vector3(_centre(c).x, _centre(c).y, 0.05), "seat:s"])
		# 5 cm off the centre of (6, 5), 37 cm east of the point.
		own.append([_disc_near(_centre(Vector2i(6, 5))), "seat:s"])
		var audit := _seat_audit(kind, corner, 90.0, own)
		var through := _cells(audit._through())
		var within := _cells(audit._within())
		for c in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)]:
			assert_true(not through.has(c) and not within.has(c), "%s: its own furniture is exempt at %s" % [kind, c])
		assert_true(within.has(Vector2i(6, 5)), "%s: its own furniture counts outside the square" % kind)
		assert_eq(audit._within()["by_kind"], {kind: within.size()}, "%s: the offenders by kind" % kind)
		for owner in ["seat:other", "placement:planter"]:
			var other := _seat_audit(kind, corner, 90.0, [[Vector3(_centre(Vector2i(5, 5)).x, _centre(Vector2i(5, 5)).y, 0.05), owner]])
			assert_true(_cells(other._through()).has(Vector2i(5, 5)), "%s: %s counts inside its square" % [kind, owner])


func test_a_seats_protected_square_turns_with_it() -> void:
	# On a cell's centre the square holds the nine cells round it, edges
	# included; turned 45°, it is a diamond whose corners reach 35 cm, so
	# the diagonal neighbours (35 cm off) fall outside it and the straight
	# ones (25 cm) stay in.
	var centre := _centre(Vector2i(5, 5))
	var diagonal := Vector2i(6, 6)
	var straight := Vector2i(6, 5)
	for facing in [0.0, 45.0]:
		var audit := _seat_audit("bench", centre, facing, [[Vector3(_centre(diagonal).x, _centre(diagonal).y, 0.05), "seat:s"],
			[Vector3(_centre(straight).x, _centre(straight).y, 0.05), "seat:s"]])
		var through := _cells(audit._through())
		assert_eq(through.has(diagonal), facing == 45.0, "facing %d: the diagonal neighbour is outside only when turned" % facing)
		assert_true(not through.has(straight), "facing %d: the straight neighbour is inside" % facing)


func test_the_reverse_problem_reads_a_seats_own_furniture_everywhere() -> void:
	# The exemption is for the sitter's cells; a blocked cell under a
	# seat's own furniture is still something drawn, not open ground.
	var audit := _seat_audit("bench", Vector2(1.25, 1.25), 0.0, [[Vector3(_centre(Vector2i(5, 5)).x, _centre(Vector2i(5, 5)).y, 0.05), "seat:s"]])
	assert_true(audit.nearest[5 * 12 + 5] <= 0.0, "the cell under its own furniture reads it")


func test_a_perchs_own_seats_are_exempt_within_the_square_round_each_sit_anchor() -> void:
	# A low wall on the floor, facing north: its five sit anchors lie 25 cm
	# in front of its face, 60 cm apart, and a sitter's hips rest over each
	# on the seat the wall reaches out to them. Its own solid in the square
	# round a sit anchor is exempt; between two squares, and anywhere a
	# different placement draws, it counts.
	# Its places are at x 1.075 and 1.675 either side of the gap round
	# x 1.375, a cell's centre.
	var audit := _floor_audit()
	var at := Vector2(1.675, 2.0)
	audit.add_placement("placement:wall", "low-wall", at, 0.0)
	var sit := at + Vector2(0.0, -0.4)
	var own := _cell_of(sit)
	var between := _cell_of(Vector2(1.375, 1.6))
	assert_true(not CollisionAudit.in_own_square(audit.placed["placement:wall"], (Vector2(between) + Vector2(0.5, 0.5)) * 0.25),
		"the cell between two places lies in neither square")
	audit.solids.append(_disc([Vector3(sit.x, sit.y, 0.15)], "placement:wall"))
	audit.solids.append(_disc([Vector3(_centre(between).x, _centre(between).y, 0.03)], "placement:wall"))
	audit._nearest()
	var through := _cells(audit._through())
	assert_true(not through.has(own), "its own seat is exempt at the sit anchor's cell %s" % own)
	assert_true(through.has(between), "its own solid counts between two squares, at %s" % between)
	var other := _floor_audit()
	other.add_placement("placement:wall", "low-wall", at, 0.0)
	other.solids.append(_disc([Vector3(sit.x, sit.y, 0.15)], "placement:planter"))
	other._nearest()
	assert_true(_cells(other._through()).has(own), "another placement's solid counts inside the square")


func test_a_perchs_squares_turn_with_its_anchors() -> void:
	# The fountain's rim: its north-east place, 45° round, faces north-east,
	# so its square is a diamond in the world's frame.
	var audit := _floor_audit()
	var at := Vector2(1.5, 1.5)
	audit.add_placement("placement:fountain", "fountain-rim", at, 0.0)
	var sits: Array = audit.placed["placement:fountain"]["sits"]
	assert_eq(sits.size(), 8, "a square round each of its eight places")
	assert_true(sits[1]["pos"].is_equal_approx(at + Vector2(1.27, -1.27)), "the second place is north-east: %s" % sits[1]["pos"])
	assert_eq(sits[1]["facing"], 45.0, "and faces north-east")
	var place: Vector2 = sits[1]["pos"]
	assert_true(CollisionAudit.in_own_square(audit.placed["placement:fountain"], place + Vector2(0.24, 0.0).rotated(deg_to_rad(45))),
		"24 cm along its facing's square is inside")
	assert_true(not CollisionAudit.in_own_square(audit.placed["placement:fountain"], place + Vector2(0.24, 0.24)),
		"24 cm east and south, inside a square not turned, is outside the turned one")


## A bare 16 x 16 cell floor, every cell walkable and near it.
func _floor_audit() -> CollisionAudit:
	var audit := CollisionAudit.new()
	var nav := NavQuery.new()
	nav.cols = 16
	nav.rows = 16
	nav._room.resize(256)
	nav._room.fill(0)
	audit.nav = nav
	audit.near.resize(256)
	audit.near.fill(1)
	return audit


## A solid of discs ([x, z, r] metres) owned by placement `id`.
func _disc(discs: Array, id: String) -> Solid:
	var solid = Solid.new()
	solid.owner = {"kind": "", "placement_id": id}
	solid.discs.append_array(discs)
	solid.place(Transform2D.IDENTITY)
	return solid


static func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / 0.25), floori(p.y / 0.25))


func test_soft_ground_is_walked_through_inside_its_lot() -> void:
	# A meadow's grass parts as people pass (spec section 2): drawn wholly
	# inside its lot it is no solid; a clump reaching past its lot counts,
	# and so does anything of a placement with a footprint.
	var soft := {"placement:meadow": Rect2(0, 0, 2, 1.5)}
	assert_true(Solids3D.walked_through(soft, {"placement_id": "placement:meadow"}, Rect2(0.2, 0.2, 0.4, 0.4)), "a clump inside its lot")
	assert_true(not Solids3D.walked_through(soft, {"placement_id": "placement:meadow"}, Rect2(1.8, 0.2, 0.4, 0.4)),
		"a clump reaching past its lot")
	assert_true(not Solids3D.walked_through(soft, {"placement_id": "placement:planter"}, Rect2(0.2, 0.2, 0.4, 0.4)), "a planter in it")
	var audit := CollisionAudit.new()
	audit.main = {"manifest": {"city": {"districts": [{"placements": [
		{"id": "placement:meadow", "kind": "meadow", "at": {"x": 100, "z": 75}, "size": {"w": 200, "d": 150}},
		{"id": "placement:wall", "kind": "low-wall", "at": {"x": 500, "z": 500}}]}]}}}
	assert_eq(audit.soft_ground(), {"placement:meadow": Rect2(0, 0, 2, 1.5)}, "the district's soft ground is its meadows' lots")


## A 3 cm disc whose edge is 5 cm from `p` (metres).
static func _disc_near(p: Vector2) -> Vector3:
	return Vector3(p.x + 0.08, p.y, 0.03)


func test_the_band_is_measured_from_the_ground_drawn_under_it() -> void:
	# A kerbed sidewalk drawn 15 cm up raises the ground its cells stand
	# on; a surface in the band (a bench's seat, a plinth at 30 cm) is no
	# ground, it is solid.
	var nav := NavQuery.new()
	nav.cols = 16
	nav.rows = 8
	var ground := PackedFloat32Array()
	ground.resize(128)
	var quad := func(x0: float, x1: float, y: float) -> PackedVector3Array:
		return PackedVector3Array([Vector3(x0, y, 0), Vector3(x1, y, 0), Vector3(x1, y, 2), Vector3(x0, y, 0),
			Vector3(x1, y, 2), Vector3(x0, y, 2)])
	var up: PackedVector3Array = quad.call(0.0, 1.0, 0.15)
	# Wound as Godot draws a face seen from above: clockwise, so its plane
	# faces up.
	assert_true(Plane(up[0], up[1], up[2]).normal.y > 0.99, "the sidewalk's face looks up")
	Solids3D.raise_ground(ground, nav, up)
	Solids3D.raise_ground(ground, nav, quad.call(1.0, 2.0, 0.30))
	assert_true(absf(ground[1 * 16 + 1] - 0.15) < 1e-4, "a sidewalk's cell stands 15 cm up (%f)" % ground[17])
	assert_eq(ground[1 * 16 + 5], 0.0, "a surface in the band raises no ground")
	# A rail's underside, 10 cm up, faces down: no one stands on it.
	var under: PackedVector3Array = quad.call(2.0, 3.0, 0.10)
	under.reverse()
	assert_true(Plane(under[0], under[1], under[2]).normal.y < -0.99, "the rail's underside looks down")
	Solids3D.raise_ground(ground, nav, under)
	assert_eq(ground[1 * 16 + 9], 0.0, "an underside raises no ground")


## Pixel art's garden gate, as city/tools/styles/pixel/models.py draws it
## at walking height: posts from 0.6 to 0.9 m either side of the middle,
## each capped 2 cm wider all round at 1.35–1.41 m. The audit reads every
## drawn corner of the caps as solid, in both turns of the sprite.
func test_the_pixel_garden_gate_s_post_caps_are_read_as_drawn() -> void:
	for name in ["scenery/garden_gate_x.png", "scenery/garden_gate_z.png"]:
		var shapes: Array = Solids2D.FOOT[name]
		for sx in [-1.0, 1.0]:
			for x in [0.58, 0.92]:
				for z in [-0.12, 0.12]:
					var at := Vector2(sx * x, z) if name.ends_with("_x.png") else Vector2(z, sx * x)
					var inside := shapes.any(func(s): return s[0] == "rect" \
						and at.x >= s[1] - 1e-6 and at.x <= s[2] + 1e-6 and at.y >= s[3] - 1e-6 and at.y <= s[4] + 1e-6)
					assert_true(inside, "%s: the cap's corner %s is solid" % [name, at])


func test_a_tram_on_an_unknown_line_still_counts_at_the_default_length() -> void:
	# A tram whose line the layout does not hold is an error, and its body
	# is taken at the length a pack draws a tram without one, so the gate
	# still counts the walker 1.37 m from its middle, 2.88 m behind its
	# front (drawn 1.5 m either side, the core's 1.25).
	var audit := CollisionAudit.new()
	var nav := NavQuery.new()
	nav.cols = 60
	nav.rows = 20
	nav._room.resize(1200)
	nav._room.fill(0)
	audit.nav = nav
	var day := {"vehicles": PackedFloat64Array([1, 0, 1000, 125, 90]), "vehicle_lines": ["line:gone"],
		"visits": PackedInt32Array([1, 0, 28, 10, 1])}
	var got := audit._tram_overlap(day, {}, {"half_width": 1.5, "centre": 0.0})
	var logged: Array = runner.errors.filter(func(e): return "line:gone" in e)
	runner.errors.clear()
	assert_eq(logged.size(), 1, "the unknown line is an error")
	assert_eq(got["count"], 1, "the walker inside the drawn tram counts")


func test_measurements_are_not_written_from_unplaced_meshes() -> void:
	# Kind sizes or a budget read while a MultiMesh's pieces could not be
	# placed would hold nothing of them.
	assert_eq(CollisionAudit.unwritable({"voxel": {"info": {"unplaced_multimeshes": {}}}}), "", "a clean run may be written")
	var why: String = CollisionAudit.unwritable({"voxel": {"info": {"unplaced_multimeshes": {"World/Planting": 12}}}})
	assert_true("voxel" in why and "World/Planting" in why, "an unplaced MultiMesh stops the write: %s" % why)
