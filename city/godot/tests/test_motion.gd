extends TestSuite


func track() -> Motion:
	var m := Motion.new()
	m.set_track("a", Vector2(0, 0), [{"x": 100, "z": 0}, {"x": 100, "z": 100}])
	return m


func test_starts_at_pos() -> void:
	assert_eq(track().sample("a", 0.0)["pos"], Vector2(0, 0), "t = 0")


func test_ends_at_last_waypoint() -> void:
	assert_eq(track().sample("a", 1.0)["pos"], Vector2(100, 100), "t = 1")


func test_moves_by_arc_length_and_faces_the_segment() -> void:
	var s := track().sample("a", 0.25)
	assert_true(s["pos"].distance_to(Vector2(50, 0)) < 0.01, "a quarter of 200 cm is 50 cm along x")
	assert_true(s["dir"].distance_to(Vector2(1, 0)) < 0.01, "facing along the first segment")
	var late := track().sample("a", 0.75)
	assert_true(late["pos"].distance_to(Vector2(100, 50)) < 0.01, "then down the second")


func test_stays_on_segments() -> void:
	var m := track()
	for k in 11:
		var p: Vector2 = m.sample("a", k / 10.0)["pos"]
		var on_first := is_equal_approx(p.y, 0.0) and p.x >= -0.01 and p.x <= 100.01
		var on_second := is_equal_approx(p.x, 100.0) and p.y >= -0.01 and p.y <= 100.01
		assert_true(on_first or on_second, "off the path at t=%s: %s" % [k / 10.0, p])


func test_empty_path_is_still_and_unknown_is_origin() -> void:
	var m := Motion.new()
	m.set_track("b", Vector2(30, 40), [])
	assert_eq(m.sample("b", 0.7)["pos"], Vector2(30, 40), "still")
	m.clear("b")
	assert_eq(m.sample("b", 0.5)["pos"], Vector2.ZERO, "cleared")
	assert_true(not m.has("b"), "forgotten")


func test_pace_is_the_ground_a_track_covers_in_its_tick() -> void:
	assert_eq(track().pace("a"), 200.0, "two metres this tick")
	var m := Motion.new()
	m.set_track("b", Vector2(30, 40), [])
	assert_eq(m.pace("b"), 0.0, "a still track has no pace")
	assert_eq(m.pace("nobody"), 0.0, "nor does no track")


## A vehicle's track: 10 m east, then 10 m south (cm).
const BENT: Array[Vector2] = [Vector2(0, 0), Vector2(1000, 0), Vector2(1000, 1000)]


func test_a_vehicle_follows_its_track_round_a_bend_over_the_tick() -> void:
	var m := Motion.new()
	# Its front went from 8 m to 12 m along: round the corner at 10 m.
	m.set_vehicle_track("v", BENT, [800, 1200], {"x": 1000, "z": 200})
	assert_eq(m.sample("v", 0.0)["pos"], Vector2(800, 0), "from where it was")
	assert_true(m.sample("v", 0.25)["pos"].distance_to(Vector2(900, 0)) < 0.01, "a quarter of the way: still heading east")
	assert_true(m.sample("v", 0.25)["dir"].distance_to(Vector2(1, 0)) < 0.01, "facing east")
	assert_true(m.sample("v", 0.5)["pos"].distance_to(Vector2(1000, 0)) < 0.01, "half way: at the corner, not cutting it")
	assert_true(m.sample("v", 0.75)["pos"].distance_to(Vector2(1000, 100)) < 0.01, "then south")
	assert_true(m.sample("v", 0.75)["dir"].distance_to(Vector2(0, 1)) < 0.01, "facing south")
	assert_eq(m.sample("v", 1.0)["pos"], Vector2(1000, 200), "to where it is")
	assert_eq(m.pace("v"), 400.0, "four metres this tick")


func test_a_vehicle_running_back_follows_its_track_the_other_way() -> void:
	var m := Motion.new()
	m.set_vehicle_track("v", BENT, [1200, 800], {"x": 800, "z": 0})
	assert_true(m.sample("v", 0.5)["pos"].distance_to(Vector2(1000, 0)) < 0.01, "through the corner")
	assert_true(m.sample("v", 0.25)["dir"].distance_to(Vector2(0, -1)) < 0.01, "north first")
	assert_true(m.sample("v", 0.75)["dir"].distance_to(Vector2(-1, 0)) < 0.01, "then west")


func test_a_vehicle_at_rest_is_exactly_where_it_is() -> void:
	var m := Motion.new()
	m.set_vehicle_track("v", BENT, [], {"x": 1000, "z": 437})
	assert_eq(m.sample("v", 0.6)["pos"], Vector2(1000, 437), "exact, at any fraction")
	assert_eq(m.pace("v"), 0.0, "and still")


func test_a_vehicle_past_the_end_of_its_track_runs_straight_on() -> void:
	var m := Motion.new()
	# Entering through a portal: its front comes on from 3 m before the start.
	m.set_vehicle_track("v", [Vector2(0, 0), Vector2(1000, 0)], [-300, 100], {"x": 100, "z": 0})
	assert_eq(m.sample("v", 0.0)["pos"], Vector2(-300, 0), "from beyond the portal")
	assert_true(m.sample("v", 0.5)["pos"].distance_to(Vector2(-100, 0)) < 0.01, "straight on")
