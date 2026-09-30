## The shared geometry every pack draws buildings and scenery from.
extends TestSuite


func district() -> Dictionary:
	return JSON.parse_string(CityPaths.district_manifest())


func _building(id: String) -> Dictionary:
	for b in CityGeometry.buildings(district(), StylePack.kinds()):
		if b["id"] == id:
			return b
	return {}


func test_buildings_are_the_facilities_with_a_building_kind() -> void:
	var ids := CityGeometry.buildings(district(), StylePack.kinds()).map(func(b): return b["id"])
	ids.sort()
	assert_eq(ids, ["facility:guild-hall", "facility:library"], "two buildings")
	var hall := _building("facility:guild-hall")
	assert_eq(hall["kind"], "guild-hall", "the hall's kind")
	assert_eq(_building("facility:library")["kind"], "library", "the library's")
	assert_eq(hall["footprint"], Rect2(-34, -14, 16, 24), "the hall covers the workshop and the commons")
	assert_eq(hall["roof"], "sawtooth", "roof from the manifest")
	assert_eq(hall["storeys"], 1, "one storey by default")
	var lib := _building("facility:library")
	assert_eq(lib["roof"], "dome", "the library's dome")
	assert_eq(lib["storeys"], 2, "two storeys")


func test_sides_carry_the_outside_doors_only() -> void:
	var hall := _building("facility:guild-hall")
	var by_side := {}
	for s in hall["sides"]:
		by_side[s["side"]] = s
	assert_eq(by_side.keys().size(), 4, "four sides")
	var east: Dictionary = by_side["east"]
	assert_eq(east["a"], Vector2(-18, -14), "east side starts at the north-east corner")
	assert_eq(east["b"], Vector2(-18, 10), "and ends at the south-east corner")
	assert_eq(east["normal"], Vector2(1, 0), "facing east")
	assert_eq(east["openings"], [8.0, 20.0], "the two doors to the square; the inner door is not an opening")
	assert_eq(by_side["west"]["openings"], [], "no doors on the west")
	assert_eq(by_side["north"]["normal"], Vector2(0, -1), "north faces -z")
	assert_eq(east["widths"], [2.0, 2.0], "each opening as wide as the kind's door_width (200 cm)")
	assert_eq(hall["wall"], 0.25, "the kind's wall, in metres")


func test_a_doors_own_width_widens_its_opening() -> void:
	var m := district()
	for f in m["city"]["districts"][0]["facilities"]:
		if f["id"] == "facility:library":
			f["rooms"][0]["doors"][0]["width"] = 300
	var west := {}
	for b in CityGeometry.buildings(m, StylePack.kinds()):
		if b["id"] != "facility:library":
			continue
		for s in b["sides"]:
			if s["side"] == "west":
				west = s
	assert_true(not west.is_empty(), "the library has a west side")
	assert_eq(west.get("widths"), [3.0], "the door's width, 300 cm")


func test_interior_door_widths_default_to_a_metre() -> void:
	var commons: Dictionary = {}
	for f in district()["city"]["districts"][0]["facilities"]:
		for r in f["rooms"]:
			if r["id"] == "room:commons":
				commons = r
	var inner: Dictionary = commons["doors"].filter(func(d): return d["to"] == "room:workshop")[0]
	assert_eq(CityGeometry.door_width(inner, StylePack.kinds()["guild-hall"], false), 1.0, "an interior door is 100 cm")
	assert_eq(CityGeometry.door_width({"width": 150}, StylePack.kinds()["guild-hall"], false), 1.5, "unless it says")
	assert_eq(CityGeometry.door_width({}, StylePack.kinds()["guild-hall"], true), 2.0, "an exterior door takes the kind's door_width")


func test_perimeter_edges_are_told_from_partitions() -> void:
	var fp := Rect2(-34, -14, 16, 24)
	assert_true(CityGeometry.on_perimeter(Vector2(-34, -14), Vector2(-18, -14), fp), "north edge")
	assert_true(CityGeometry.on_perimeter(Vector2(-18, -14), Vector2(-18, 2), fp), "part of the east edge")
	assert_true(not CityGeometry.on_perimeter(Vector2(-34, 2), Vector2(-18, 2), fp), "the partition between rooms")


func test_subtracting_a_hole_leaves_the_rest() -> void:
	var parts := CityGeometry.subtract(Rect2(0, 0, 10, 10), Rect2(4, -5, 2, 20))
	var area := 0.0
	for p in parts:
		area += p.get_area()
		assert_true(not p.intersects(Rect2(4, -5, 2, 20)), "no part overlaps the hole")
	assert_eq(area, 80.0, "the hole's 20 m² removed")
	assert_eq(CityGeometry.subtract(Rect2(0, 0, 1, 1), Rect2(5, 5, 1, 1)), [Rect2(0, 0, 1, 1)], "a hole elsewhere changes nothing")


func test_ground_covers_the_extent_except_water() -> void:
	var m := district()
	var water := Rect2()
	for s in m["scenery"]:
		if s["kind"] == "water":
			water = CityGeometry.rect_m(s["rect"])
	var ext := CityGeometry.extent(m)
	assert_true(ext.encloses(water), "the extent includes the river")
	assert_true(ext.encloses(Rect2(-34, -14, 70, 44)), "and the rooms")
	var area := 0.0
	for g in CityGeometry.ground(m, 4.0):
		area += g.get_area()
		assert_true(not g.intersects(water), "no ground over water")
	var grown := ext.grow(4.0)
	assert_true(absf(area - (grown.get_area() - grown.intersection(water).get_area())) < 0.01, "everything else is ground")


func test_along_a_polyline() -> void:
	var line := [Vector2(0, 0), Vector2(10, 0)]
	var at := CityGeometry.along(line, 5.0)
	assert_eq(at.map(func(p): return p["pos"]), [Vector2(0, 0), Vector2(5, 0), Vector2(10, 0)], "every 5 m, both ends")
	assert_eq(at[0]["dir"], Vector2(1, 0), "facing along")
	var bend := [Vector2(0, 0), Vector2(4, 0), Vector2(4, 6)]
	assert_eq(CityGeometry.length(bend), 10.0, "length")
	var p := CityGeometry.point_at(bend, 7.0)
	assert_eq(p["pos"], Vector2(4, 3), "past the bend")
	assert_eq(p["dir"], Vector2(0, 1), "turned")
	assert_eq(CityGeometry.point_at(bend, 99.0)["pos"], Vector2(4, 6), "clamped to the end")


func test_blocks_split_into_lots() -> void:
	var lots := CityGeometry.lots(Rect2(0, 0, 12, 9), 6.0)
	assert_eq(lots, [Rect2(0, 0, 6, 9), Rect2(6, 0, 6, 9)], "two lots along the long side")
	assert_eq(CityGeometry.lots(Rect2(0, 0, 4, 4), 6.0), [Rect2(0, 0, 4, 4)], "a small block is one lot")


func test_scenery_points_are_metres() -> void:
	var m := district()
	for s in m["scenery"]:
		if s["kind"] == "bridge":
			var seg := CityGeometry.scenery_points(s)
			assert_eq(seg, [Vector2(-72, 23), Vector2(-42, 23)], "the bridge's ends")


## A fence is laid as modules of about `module` metres along each run
## (stretched to fit exactly), turning at its corners, with a post at
## each open end.
func test_a_fence_is_cut_into_modules_that_fit_each_run() -> void:
	var f := CityGeometry.fence([Vector2(0, 0), Vector2(5, 0), Vector2(5, 3)], 2.0)
	var modules: Array = f["modules"]
	assert_eq(modules.size(), 5, "three along the first run, two along the second")
	assert_true(absf(modules[0]["length"] - 5.0 / 3.0) < 1e-4, "stretched to fit: %s" % modules[0]["length"])
	assert_true(modules[0]["centre"].distance_to(Vector2(5.0 / 6.0, 0)) < 1e-4, "the first starts at the run's start")
	assert_eq(modules[0]["dir"], Vector2(1, 0), "running east")
	assert_eq(modules[3]["dir"], Vector2(0, 1), "then south")
	assert_true(absf(modules[3]["length"] - 1.5) < 1e-4, "1.5 m each on the 3 m run")
	assert_true(modules[4]["centre"].distance_to(Vector2(5, 2.25)) < 1e-4, "the last ends at the run's end")
	assert_eq(f["posts"], [Vector2(0, 0), Vector2(5, 3)], "a post closes each open end")
	var ring := CityGeometry.fence([Vector2(0, 0), Vector2(2, 0), Vector2(2, 2), Vector2(0, 2), Vector2(0, 0)], 2.0)
	assert_eq(ring["posts"], [], "a closed ring has no open end")


## A line's two tracks, offset from its centreline as the core offsets
## them (south-positive, mitred at a bend), in centimetres.
func test_a_lines_tracks_are_offset_and_mitred_as_the_core_lays_them() -> void:
	var line := {"points": [{"x": 0, "z": 0}, {"x": 1000, "z": 0}, {"x": 1000, "z": 1000}], "tracks": [-100, 100]}
	assert_eq(CityGeometry.track_points(line, 0), [Vector2(0, -100), Vector2(1100, -100), Vector2(1100, 1000)], "north track, outside the bend")
	assert_eq(CityGeometry.track_points(line, 1), [Vector2(0, 100), Vector2(900, 100), Vector2(900, 1000)], "south track, inside it")


func test_a_point_along_a_track_runs_straight_on_past_its_ends() -> void:
	var track: Array[Vector2] = [Vector2(0, 0), Vector2(1000, 0), Vector2(1000, 1000)]
	assert_eq(CityGeometry.point_along(track, 1500), Vector2(1000, 500), "round the bend")
	assert_eq(CityGeometry.point_along(track, -200), Vector2(-200, 0), "before the start")
	assert_eq(CityGeometry.point_along(track, 2300), Vector2(1000, 1300), "past the end")


## Slots two across and a row each 2 m (capacity 40 on a 20.5 m tram: 20
## rows), even slots on the left of travel, as the core's slot_point puts
## them; the rows at a door are for standing.
func test_rider_slots_sit_two_across_and_stand_by_the_doors() -> void:
	var spec := {"capacity": 40, "length": 2050, "doors": [410, 1025, 1640]}
	assert_eq(CityGeometry.slot_local(spec, 0), Vector2(-51, 50), "front row, left")
	assert_eq(CityGeometry.slot_local(spec, 1), Vector2(-51, -50), "front row, right")
	assert_eq(CityGeometry.slot_local(spec, 39), Vector2(-1998, -50), "back row, right")
	assert_eq(CityGeometry.slot_local(spec, null), Vector2(-1025, 0), "a hidden rider rides in the middle")
	assert_true(CityGeometry.slot_seated(spec, 0), "the front row sits")
	assert_true(not CityGeometry.slot_seated(spec, 6), "the row at the first door (3.6 m) stands")
	assert_true(not CityGeometry.slot_seated(spec, 19), "the rows at the middle door stand")
	assert_true(not CityGeometry.slot_seated(spec, null), "a hidden rider stands")
	var seated := range(40).filter(func(s): return CityGeometry.slot_seated(spec, s)).size()
	assert_eq(seated, 28, "fourteen rows of two seats, six rows by the doors to stand in")


## A building's type is its facility's `kind`.
func test_a_building_is_known_by_its_kind() -> void:
	var m := district()
	var kinds := {}
	for d in m["city"]["districts"]:
		for f in d["facilities"]:
			kinds[f["id"]] = CityGeometry.building_kind(f)
	assert_eq(kinds["facility:guild-hall"], "guild-hall", "the hall")
	assert_eq(kinds["facility:square"], "", "the square is no building")
	var ids := CityGeometry.buildings(m, StylePack.kinds()).map(func(b): return b["id"])
	ids.sort()
	assert_eq(ids, ["facility:guild-hall", "facility:library"], "the two buildings")


## Every district placement, in ID order, in metres: the kind, the point,
## the facing, a sized kind's lot and the level.
func test_placements_are_read_in_id_order_in_metres() -> void:
	var list := CityGeometry.placements(district())
	assert_eq(list.size(), 843, "every placement in the district")
	var ids := list.map(func(p): return p["id"])
	var sorted := ids.duplicate()
	sorted.sort()
	assert_eq(ids, sorted, "in ID order")
	var by_id := {}
	for p in list:
		by_id[p["id"]] = p
	var shelf: Dictionary = by_id["placement:reading-shelf-1"]
	assert_eq(shelf["kind"], "bookshelf", "its kind")
	assert_eq(shelf["pos"], Vector2(35.25, -7.0), "its point in metres")
	assert_eq(shelf["facing"], 270.0, "its facing")
	assert_eq(shelf["size"], Vector2.ZERO, "no lot for an unsized kind")
	assert_eq(shelf["level"], 0, "on the ground")
	var house: Dictionary = by_id["placement:house-01"]
	assert_eq(house["facing"], 0.0, "facing north by default")
	assert_eq(house["size"], Vector2(6, 8), "a block's lot")
	assert_eq(CityGeometry.lot(house), Rect2(-41, -12, 6, 8), "centred on its point")


## A kind's footprint rects stand where a placement puts them: turned by
## its facing about its point (right angles exactly).
func test_a_footprint_turns_with_its_placement() -> void:
	var shelf := {"kind": "bookshelf", "pos": Vector2(35.25, -7.0), "facing": 270.0}
	var kind := {"footprint": [{"x": -90, "z": -30, "w": 180, "d": 60}]}
	var rects := CityGeometry.footprint_rects(kind, shelf)
	assert_eq(rects.size(), 1, "one rect")
	assert_true(rects[0].is_equal_approx(Rect2(34.95, -7.9, 0.6, 1.8)), "turned a quarter: %s" % rects[0])
	var bench := {"pos": Vector2(0, 0), "facing": 90.0}
	var offset := CityGeometry.footprint_rects({"footprint": [{"x": 0, "z": -100, "w": 50, "d": 20}]}, bench)
	assert_true(offset[0].is_equal_approx(Rect2(0.8, 0, 0.2, 0.5)), "north of the point turns to east of it: %s" % offset[0])
	assert_eq(CityGeometry.footprint_rects({"footprint": [{"x": 0, "z": 0, "r": 15}]}, bench), [], "discs are not rects")


func test_a_filled_footprint_is_drawn_to_the_cells_the_grid_blocks() -> void:
	var grid := NavQuery.new()
	grid.origin = Vector2i(0, 0)
	grid.cols = 100
	grid.rows = 100
	# Edges at 155 and 455 cm across; 55 and 145 cm down. Cell centres lie
	# at 12, 37, 62 ... cm; the core blocks those 10 cm or less outside.
	var drawn := CityGeometry.drawn_rect(grid, Rect2(1.55, 0.55, 3.0, 0.9))
	assert_true(is_equal_approx(drawn.position.x, 1.55), "no centre lies within 10 cm out of 155 cm (137 is 18 out): %s" % drawn)
	assert_true(is_equal_approx(drawn.end.x, 4.645), "462 cm lies 7 cm out of 455, so the edge moves past it: %s" % drawn)
	assert_true(is_equal_approx(drawn.position.y, 0.55), "37 cm lies 18 cm out of 55: %s" % drawn)
	assert_true(is_equal_approx(drawn.end.y, 1.45), "137 cm lies inside 145: %s" % drawn)
	var corner := CityGeometry.drawn_rect(grid, Rect2(1.55, 0.55, 3.0, 0.745))
	assert_true(is_equal_approx(corner.end.y, 1.395), "137 cm lies 7.5 cm out of 129.5, so the corner cell at 462, 137 is reached: %s" % corner)


func test_a_point_finds_the_nearest_street() -> void:
	var m := {"scenery": [
		{"kind": "street", "points": [{"x": 0, "z": 0}, {"x": 2000, "z": 0}], "width": 600},
		{"kind": "street", "points": [{"x": 3000, "z": -1000}, {"x": 3000, "z": 1000}], "width": 600},
		{"kind": "water", "rect": {"x": 0, "z": 500, "w": 100, "d": 100}}]}
	assert_eq(CityGeometry.nearest_street(m, Vector2(5, 4)), Vector2(5, 0), "straight across to the first street")
	assert_eq(CityGeometry.nearest_street(m, Vector2(27, 4)), Vector2(30, 4), "or across to the second, nearer")
	assert_eq(CityGeometry.nearest_street(m, Vector2(-5, -2)), Vector2(0, 0), "past a street's end, its end")
	assert_eq(CityGeometry.nearest_street({"scenery": []}, Vector2(1, 1)), Vector2.INF, "no street, none")
