extends TestSuite


func view(id: String, extra := {}) -> Dictionary:
	var v := {
		"id": id, "kind": {"type": "GuildAgent"}, "display_name": id, "role": "",
		"badge": "Ai", "appearance": {}, "seat": null,
		"presence": {"headline": "Unknown", "connection": "Unknown", "process": "Unknown", "task": "Unknown"},
		"pos": {"x": 100, "z": 100},
	}
	v.merge(extra, true)
	return v


func projection(in_room := [], waiting := [], transit := [], minutes = null) -> Dictionary:
	var p := {"rooms": [{"id": "room:w", "occupants": in_room, "waiting": waiting}], "in_transit": transit}
	if minutes != null:
		p["time_of_day"] = minutes
	return p


func types(changes: Array) -> Array:
	return changes.map(func(c): return c["type"])


func test_first_projection_appears_everyone() -> void:
	var m := SceneModel.new()
	var ch := m.apply(projection([view("a")], [view("q")], [view("t", {"moving": true})], 420))
	assert_eq(types(ch), ["appeared", "appeared", "appeared", "time"], "order")
	var poses := {}
	for c in ch:
		if c["type"] == "appeared":
			poses[c["occupant"]["id"]] = c["pose"]
	assert_eq(poses, {"a": "standing", "q": "queued", "t": "walking"}, "poses")


func test_leaving_emits_left() -> void:
	var m := SceneModel.new()
	m.apply(projection([view("a"), view("b")]))
	var ch := m.apply(projection([view("a")]))
	assert_eq(types(ch), ["left"], "one left")
	assert_eq(ch[0]["id"], "b", "b left")
	assert_true(not m.occupants.has("b"), "forgotten")


func test_walk_then_sit() -> void:
	var m := SceneModel.new()
	m.apply(projection([], [], [view("a", {"moving": true, "path_ahead": [{"x": 125, "z": 100}]})]))
	var ch := m.apply(projection([view("a", {"seat": "seat:1", "pos": {"x": 150, "z": 100}})]))
	assert_eq(types(ch), ["pose", "moved"], "pose then move")
	assert_eq(ch[0]["pose"], "sitting", "sits")
	assert_eq(m.occupants["a"]["room"], "room:w", "now in the room")


func test_headline_change_only_when_changed() -> void:
	var m := SceneModel.new()
	m.apply(projection([view("a")]))
	assert_eq(m.apply(projection([view("a")])), [], "nothing changed")
	var working := view("a", {"presence": {"headline": "Working"}})
	var ch := m.apply(projection([working]))
	assert_eq(types(ch), ["presence"], "presence only")
	assert_eq(ch[0]["headline"], "Working", "new headline")


func test_time_change() -> void:
	var m := SceneModel.new()
	m.apply(projection([], [], [], 420))
	assert_eq(m.apply(projection([], [], [], 420)), [], "same minute")
	var ch := m.apply(projection([], [], [], 421))
	assert_eq(ch, [{"type": "time", "minutes": 421}], "new minute")


func test_current_matches_state() -> void:
	var m := SceneModel.new()
	m.apply(projection([view("b"), view("a", {"seat": "s"})], [], [], 600))
	var cur := m.current()
	assert_eq(cur.map(func(c): return c["occupant"]["id"]), ["a", "b"], "sorted by id")
	assert_eq(cur[0]["pose"], "sitting", "pose kept")
	assert_eq(m.time, 600, "time kept")


# ---- Vehicles and their riders ----

func vehicle(id: String, along: int, extra := {}) -> Dictionary:
	var v := {"id": id, "line": "line:boulevard", "direction": "east", "pos": {"x": -1800 + along, "z": 1950},
		"heading": 90, "along": along, "trail": [], "status": "running", "doors_open": false}
	v.merge(extra, true)
	return v


func with_vehicles(p: Dictionary, vehicles: Array, aboard := []) -> Dictionary:
	p["vehicles"] = vehicles
	p["aboard"] = aboard
	return p


func test_a_vehicle_appears_moves_opens_its_doors_and_leaves() -> void:
	var m := SceneModel.new()
	var ch := m.apply(with_vehicles(projection(), [vehicle("vehicle:a", 0)]))
	assert_eq(types(ch), ["vehicle_appeared"], "appears")
	assert_eq(ch[0]["view"]["id"], "vehicle:a", "with its view")
	assert_true(m.vehicles.has("vehicle:a"), "kept")
	ch = m.apply(with_vehicles(projection(), [vehicle("vehicle:a", 700, {"trail": [0, 700]})]))
	assert_eq(types(ch), ["vehicle_moved"], "moves")
	assert_eq(ch[0]["id"], "vehicle:a", "which")
	assert_eq(ch[0]["view"]["along"], 700, "to its new along")
	assert_eq(ch[0]["from"], {"x": -1800, "z": 1950}, "from where it was")
	var standing := vehicle("vehicle:a", 700, {"status": "standing", "doors_open": true, "stop": "stop:square"})
	ch = m.apply(with_vehicles(projection(), [standing]))
	assert_eq(types(ch), ["vehicle_moved", "doors"], "it stops (its trail empties) and opens")
	assert_eq(ch[1], {"type": "doors", "id": "vehicle:a", "open": true}, "the doors open")
	assert_eq(m.apply(with_vehicles(projection(), [standing])), [], "nothing changes while it stands")
	ch = m.apply(with_vehicles(projection(), []))
	assert_eq(ch, [{"type": "vehicle_left", "id": "vehicle:a"}], "leaves")
	assert_true(m.vehicles.is_empty(), "forgotten")


func test_riders_are_occupants_aboard_their_vehicle() -> void:
	var m := SceneModel.new()
	var rider := view("r", {"vehicle": "vehicle:a", "slot": 3, "pos": {"x": -1851, "z": 2000}})
	var ch := m.apply(with_vehicles(projection(), [vehicle("vehicle:a", 0)], [rider]))
	assert_eq(types(ch), ["vehicle_appeared", "appeared"], "the vehicle first, then who rides it")
	assert_eq(ch[1]["occupant"]["vehicle"], "vehicle:a", "the rider carries its vehicle")
	assert_eq(ch[1]["room"], null, "and is in no room")
	assert_eq(m.occupants["r"]["pose"], "standing", "the core's pose for someone aboard")


func test_boarding_and_alighting_are_one_change_not_a_despawn() -> void:
	var m := SceneModel.new()
	var waiting := view("r", {"waiting_for": {"stop": "stop:square", "direction": "east"}})
	m.apply(with_vehicles(projection([waiting]), [vehicle("vehicle:a", 2825, {"status": "standing", "doors_open": true})]))
	var aboard := view("r", {"vehicle": "vehicle:a", "slot": 0, "pos": {"x": 974, "z": 1900}})
	var ch := m.apply(with_vehicles(projection(), [vehicle("vehicle:a", 2825, {"status": "standing", "doors_open": true})], [aboard]))
	assert_eq(types(ch), ["aboard", "moved"], "it boards and is drawn at its slot")
	assert_eq(ch[0], {"type": "aboard", "id": "r", "vehicle": "vehicle:a", "slot": 0, "pos": {"x": 974, "z": 1900}}, "which vehicle and slot")
	ch = m.apply(with_vehicles(projection([view("r", {"pos": {"x": 1000, "z": 1700}})]), [vehicle("vehicle:a", 2825, {"status": "standing", "doors_open": true})]))
	assert_eq(types(ch), ["aboard", "moved"], "it steps off")
	assert_eq(ch[0], {"type": "aboard", "id": "r", "vehicle": null, "slot": null, "pos": {"x": 1000, "z": 1700}}, "onto the ground, where it steps off")
	assert_eq(m.occupants["r"]["room"], "room:w", "into the platform's room")


func test_a_rider_steps_off_before_its_vehicle_leaves() -> void:
	var m := SceneModel.new()
	var aboard := view("r", {"vehicle": "vehicle:a", "slot": 0})
	m.apply(with_vehicles(projection(), [vehicle("vehicle:a", 8000)], [aboard]))
	var ch := m.apply(with_vehicles(projection([view("r")]), []))
	assert_eq(types(ch), ["aboard", "vehicle_left"], "the rider is off the vehicle before it goes")


func test_current_vehicles_rebuild_a_pack() -> void:
	var m := SceneModel.new()
	m.apply(with_vehicles(projection(), [vehicle("vehicle:b", 100), vehicle("vehicle:a", 0)]))
	var cur := m.current_vehicles()
	assert_eq(cur.map(func(c): return c["view"]["id"]), ["vehicle:a", "vehicle:b"], "sorted by id")
	assert_eq(types(cur), ["vehicle_appeared", "vehicle_appeared"], "as appearances")
