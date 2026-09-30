## The client's copy of the walkable grid: loaded from the core's, it
## agrees with the core cell for cell, follows the cells placements change,
## and tells ground clear of the walkable floor.
extends TestSuite

## The neighbours CityWorld.grid_answers reports steps to, in its order.
const STEPS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]


func loaded():
	var w = ClassDB.instantiate("CityWorld")
	var r: Dictionary = JSON.parse_string(w.load(CityPaths.district_manifest(), CityPaths.district_feed(), 7, 0))
	assert_eq(r.get("ok"), true, "the district loads")
	return w


func nav_of(w) -> NavQuery:
	return NavQuery.from_layout(JSON.parse_string(w.layout_json()))


## Every cell's room index, or -1, row by row.
func rooms_of(nav: NavQuery) -> Array:
	var out := []
	for j in nav.rows:
		for i in nav.cols:
			out.append(nav.room_ids.find(nav.room_at(Vector2i(i, j))))
	return out


func test_the_loaded_grid_agrees_with_the_core_on_every_cell() -> void:
	var w = loaded()
	var nav := nav_of(w)
	var answers: PackedInt32Array = w.grid_answers()
	assert_true(nav.cols > 0 and nav.rows > 0, "the grid has cells")
	assert_eq(answers.size(), nav.cols * nav.rows, "the core answers for every cell")
	var wrong := []
	var counts := {"floor": 0, "span": 0, "seat": 0, "steps": 0, "allowed": 0}
	for k in answers.size():
		var c := Vector2i(k % nav.cols, k / nav.cols)
		var a := answers[k]
		var room := (a & 0xffff) - 1
		var span := (a >> 16) & 1 == 1
		var seat := (a >> 17) & 1 == 1
		counts["floor"] += 1 if room >= 0 else 0
		counts["span"] += 1 if span else 0
		counts["seat"] += 1 if seat else 0
		if nav.walkable(c) != (room >= 0) or nav.room_at(c) != (nav.room_ids[room] if room >= 0 else "") \
				or nav.in_door_span(c) != span or nav.is_seat_cell(c) != seat:
			wrong.append(["cell", c])
		if k % 7 != 0:
			continue
		for n in STEPS.size():
			var to: Vector2i = c + STEPS[n]
			var allowed := (a >> (18 + n)) & 1 == 1
			var to_k := to.y * nav.cols + to.x
			var to_seat := to.x >= 0 and to.y >= 0 and to.x < nav.cols and to.y < nav.rows and (answers[to_k] >> 17) & 1 == 1
			counts["steps"] += 1
			counts["allowed"] += 1 if allowed else 0
			if nav.can_step(c, to, true) != allowed:
				wrong.append(["step to a destination", c, to])
			# A step is never steered onto a seat: only a walk to it ends there.
			if nav.can_step(c, to) != (allowed and not to_seat):
				wrong.append(["steered step", c, to])
	assert_eq(wrong.slice(0, 10), [], "%d disagreements with the core" % wrong.size())
	assert_true(counts["floor"] > 0 and counts["span"] > 0 and counts["seat"] > 0 and counts["allowed"] > 0,
		"the district has floor, door spans, seats and steps: %s" % counts)


func test_apply_changes_flips_exactly_the_listed_cells() -> void:
	var nav := nav_of(loaded())
	var before := rooms_of(nav)
	var floor := before.find(nav.room_ids.find("room:plaza"))
	var off := before.find(-1)
	assert_true(floor >= 0 and off >= 0, "a plaza cell and a cell off the floor")
	var closing := Vector2i(floor % nav.cols, floor / nav.cols)
	var opening := Vector2i(off % nav.cols, off / nav.cols)
	var reading := nav.room_ids.find("room:reading")
	nav.apply_changes([{"i": closing.x, "j": closing.y, "walkable": false},
		{"i": opening.x, "j": opening.y, "walkable": true, "room": reading}])
	var after := rooms_of(nav)
	var expected := before.duplicate()
	expected[floor] = -1
	expected[off] = reading
	assert_true(after == expected, "only the two listed cells changed")
	assert_true(not nav.walkable(closing), "the closed cell is not floor")
	assert_eq(nav.room_at(opening), "room:reading", "the opened cell is the named room's floor")


## A grid of 4 by 2 cells, one open-air room, whose ground level's runs
## cover `runs`.
func tiny_grid(runs: Array) -> Dictionary:
	return {"origin": {"x": 0, "z": 0}, "cols": 4, "rows": 2, "rooms": ["room:a"], "outdoor": [true],
		"levels": [{"rooms": runs}], "spans": [], "seats": []}


## A grid whose runs do not cover its cells exactly is an error: the cells
## no run reaches stay off the floor, never another room's, and runs past
## the last cell are dropped.
func test_a_grid_whose_runs_do_not_cover_its_cells_is_an_error() -> void:
	for case in [
		[[[0, 5]], [true, true, true, true, true, false, false, false]],
		[[[0, 3], [-1, 1], [0, 6]], [true, true, true, false, true, true, true, true]],
	]:
		var nav := NavQuery.new()
		nav._load(tiny_grid(case[0]))
		var logged: Array = runner.errors.filter(func(e): return "runs cover" in e)
		runner.errors.clear()
		assert_eq(logged.size(), 1, "%s: said, once: %s" % [case[0], logged])
		var walkable := []
		for k in 8:
			walkable.append(nav.walkable(Vector2i(k % 4, k / 4)))
		assert_eq(walkable, case[1], "%s: the floor the runs give, and no more" % [case[0]])
	var exact := NavQuery.new()
	exact._load(tiny_grid([[0, 6], [-1, 2]]))
	assert_true(exact.walkable(Vector2i(1, 1)) and not exact.walkable(Vector2i(2, 1)), "an exact grid loads as given")


func test_the_grid_changes_of_a_placement_bring_the_copy_to_the_cores_grid() -> void:
	var w = loaded()
	var nav := nav_of(w)
	# Commands come from a joined session; the operator's place things.
	assert_eq(JSON.parse_string(w.join("observer", "1,1")).get("ok"), true, "joins")
	w.set_operator(true)
	var place := {"type": "Place", "placement": {"id": "placement:planter", "kind": "planter", "at": {"x": 1000, "z": 1000}}}
	assert_eq(JSON.parse_string(w.command(JSON.stringify(place))), {"ok": true}, "the operator places a planter")
	w.step()
	var changes: Array = JSON.parse_string(w.project_json("public")).get("grid_changes", [])
	assert_true(not changes.is_empty(), "the planter changes the grid")
	nav.apply_changes(changes)
	assert_true(rooms_of(nav) == rooms_of(nav_of(w)), "the copy is the core's grid after the planter")
	var remove := {"type": "RemovePlacement", "id": "placement:planter"}
	assert_eq(JSON.parse_string(w.command(JSON.stringify(remove))), {"ok": true}, "and removes it")
	w.step()
	nav.apply_changes(JSON.parse_string(w.project_json("public")).get("grid_changes", []))
	assert_true(rooms_of(nav) == rooms_of(nav_of(w)), "and after it goes")


func test_clear_of_walkable_is_true_on_the_water_and_false_on_the_plaza() -> void:
	var nav := nav_of(loaded())
	assert_true(CityGeometry.clear_of_walkable(nav, Rect2i(-6800, -3800, 1000, 1000)), "open water is clear")
	assert_true(not CityGeometry.clear_of_walkable(nav, Rect2i(-400, -400, 100, 100)), "the plaza is floor")
