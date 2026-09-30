## Trams drawn from the projection: the host forwards each vehicle to the
## pack shown, interpolates it along its track over the tick, and carries
## its riders inside it. Every style draws the rails from the manifest's
## lines and keeps no tram clock of its own.
extends TestSuite

const FAKE := "res://tests/fixtures/fake_pack"
const EAST := "vehicle:boulevard:east:1"
const WEST := "vehicle:boulevard:west:1"
## Where an eastbound tram's front is when it stands at the Square: its
## centre on the stop's `at` (1800 cm along), half its 2050 cm past it.
const AT_SQUARE := 2825


func manifest() -> Dictionary:
	return JSON.parse_string(CityPaths.district_manifest())


## A vehicle as the core projects it on the district's straight line: the
## eastbound track is 1.5 m north of the centreline (z 1900), the westbound
## 1.5 m south (z 2200), both from x = -1800.
func vehicle(id: String, along: int, extra := {}) -> Dictionary:
	var east := id.contains(":east:")
	var v := {"id": id, "line": "line:boulevard", "direction": "east" if east else "west",
		"pos": {"x": -1800 + along, "z": 1900 if east else 2200}, "heading": 90 if east else 270,
		"along": along, "trail": [], "status": "running", "doors_open": false}
	v.merge(extra, true)
	return v


func person(id: String, extra := {}) -> Dictionary:
	var v := {"id": id, "kind": {"type": "Human", "tier": "Registered"}, "display_name": id, "role": "",
		"badge": null, "appearance": {"palette": "1", "hair": "1"}, "seat": null,
		"presence": {"headline": "Present"}, "pos": {"x": 900, "z": 1600}}
	v.merge(extra, true)
	return v


func rider(id: String, vehicle_id: String, slot) -> Dictionary:
	return person(id, {"vehicle": vehicle_id, "slot": slot})


func projection(vehicles: Array, aboard := [], on_platform := []) -> Dictionary:
	return {"rooms": [{"id": "room:tram-stop", "occupants": on_platform, "waiting": []}], "in_transit": [],
		"vehicles": vehicles, "aboard": aboard, "time_of_day": 720}


func host() -> StyleHost:
	var h := StyleHost.new()
	runner.root.add_child(h)
	return h


func near(a: Vector2, b: Vector2, within := 1.0) -> bool:
	return a.distance_to(b) <= within


# ---- The host and a pack that records what it is asked ----

func test_the_host_spawns_moves_and_despawns_a_vehicle() -> void:
	var h := host()
	var model := SceneModel.new()
	var motion := Motion.new()
	h.activate(FAKE, manifest(), model, motion, 0.0)
	h.apply_changes(model.apply(projection([vehicle(EAST, 1000)])), motion)
	assert_true(h.pack.vehicle_nodes.has(EAST), "spawned")
	assert_eq(h.pack.vehicle_places[EAST], [Vector2(-800, 1900), 90.0], "placed at its front, heading east")
	h.apply_changes(model.apply(projection([vehicle(EAST, 1700, {"trail": [1000, 1700]})])), motion)
	h.tick_frame(0.0, motion)
	assert_true(near(h.pack.vehicle_places[EAST][0], Vector2(-800, 1900)), "the tick replays from where it was")
	h.tick_frame(0.5, motion)
	assert_true(near(h.pack.vehicle_places[EAST][0], Vector2(-450, 1900)), "half way along its track half way through")
	assert_eq(h.pack.vehicle_places[EAST][1], 90.0, "heading the way it runs")
	h.tick_frame(1.0, motion)
	assert_true(near(h.pack.vehicle_places[EAST][0], Vector2(-100, 1900)), "and ends where it is")
	h.apply_changes(model.apply(projection([vehicle(EAST, 1700, {"doors_open": true, "status": "standing"})])), motion)
	assert_eq(h.pack.doors[EAST], true, "its doors open")
	var node: Node = h.pack.vehicle_nodes[EAST]
	h.apply_changes(model.apply(projection([])), motion)
	assert_true(h.pack.vehicle_nodes.is_empty(), "despawned")
	assert_true(not is_instance_valid(node), "its node is gone")
	assert_true(not motion.has(EAST), "and its track")
	h.free()


func test_a_standing_vehicle_is_placed_once_not_every_frame() -> void:
	var h := host()
	var model := SceneModel.new()
	var motion := Motion.new()
	h.activate(FAKE, manifest(), model, motion, 0.0)
	h.apply_changes(model.apply(projection([vehicle(EAST, AT_SQUARE, {"status": "standing"})])), motion)
	var placed := 0
	for f in 20:
		h.pack.vehicle_places.clear()
		h.tick_frame(f / 20.0, motion)
		placed += h.pack.vehicle_places.size()
	assert_true(placed <= 1, "a tram at rest costs nothing between ticks: %d" % placed)
	h.free()


func test_riders_ride_inside_their_vehicle_seated_or_standing() -> void:
	var h := host()
	var model := SceneModel.new()
	var motion := Motion.new()
	model.apply(projection([vehicle(EAST, AT_SQUARE, {"status": "standing"})],
		[rider("r0", EAST, 0), rider("r6", EAST, 6), rider("hidden", EAST, null)]))
	h.activate(FAKE, manifest(), model, motion, 0.0)
	var tram: Node = h.pack.vehicle_nodes[EAST]
	for id in ["r0", "r6", "hidden"]:
		assert_eq(h.pack.nodes[id].get_parent(), tram, id + " rides inside the tram's node")
		assert_eq(h.pack.riders[id], EAST, id + " is known to ride it")
	assert_eq(h.pack.rider_offsets["r0"], Vector2(-51, 50), "slot 0: the front row, left of travel")
	assert_eq(h.pack.rider_offsets["r6"], Vector2(-358, 50), "slot 6: the row by the first door")
	assert_eq(h.pack.rider_offsets["hidden"], Vector2(-1025, 0), "a rider with no slot rides in the middle")
	assert_eq(h.pack.poses["r0"], "sitting", "a seat row sits")
	assert_eq(h.pack.poses["r6"], "standing", "by the doors they stand")
	assert_eq(h.pack.poses["hidden"], "standing", "so does a rider with no slot")
	# The tram moves; its riders go with it and are never placed themselves.
	h.apply_changes(model.apply(projection([vehicle(EAST, 3525, {"trail": [AT_SQUARE, 3525]})],
		[rider("r0", EAST, 0), rider("r6", EAST, 6), rider("hidden", EAST, null)])), motion)
	for f in 5:
		h.pack.places.clear()
		h.tick_frame(f / 5.0, motion)
		assert_true(not h.pack.places.has("r0") and not h.pack.places.has("r6"), "riders are not placed each frame")
	assert_eq(h.pack.poses["r0"], "sitting", "still seated as it runs")
	h.free()


func test_a_rider_steps_off_onto_the_platform_without_a_pop() -> void:
	var h := host()
	var model := SceneModel.new()
	var motion := Motion.new()
	var standing := vehicle(EAST, AT_SQUARE, {"status": "standing", "doors_open": true})
	model.apply(projection([standing], [rider("r0", EAST, 0)]))
	h.activate(FAKE, manifest(), model, motion, 0.0)
	var node: Node = h.pack.nodes["r0"]
	h.apply_changes(model.apply(projection([standing], [], [person("r0", {"pos": {"x": 610, "z": 1780}})])), motion)
	assert_true(is_instance_valid(node) and h.pack.nodes["r0"] == node, "the same node, never despawned")
	assert_eq(node.get_parent(), h.pack.occupant_parent(), "back among the people on the ground")
	assert_true(not h.pack.riders.has("r0"), "no longer riding")
	assert_eq(h.pack.places["r0"], Vector2(610, 1780), "standing where it stepped off")
	assert_eq(h.pack.poses["r0"], "standing", "on its feet")
	# And boards again: the same node goes back inside.
	h.apply_changes(model.apply(projection([standing], [rider("r0", EAST, 7)])), motion)
	assert_eq(h.pack.nodes["r0"], node, "still the same node")
	assert_eq(node.get_parent(), h.pack.vehicle_nodes[EAST], "inside the tram again")
	h.free()


func test_a_vehicle_going_never_takes_a_node_with_it() -> void:
	var h := host()
	var model := SceneModel.new()
	var motion := Motion.new()
	model.apply(projection([vehicle(EAST, 5000)], [rider("r0", EAST, 0)]))
	h.activate(FAKE, manifest(), model, motion, 0.0)
	var node: Node = h.pack.nodes["r0"]
	h.pack.despawn_vehicle(EAST)
	assert_true(is_instance_valid(node), "a rider still aboard is set down, not freed")
	assert_eq(node.get_parent(), h.pack.occupant_parent(), "among the people on the ground")
	h.free()


# ---- Every style ----

func test_the_3d_styles_draw_their_trams_as_wide_as_the_tram_kind() -> void:
	# The core blocks the tram kind's width (250 cm) round its track; the
	# fitted styles draw the body that wide where people walk, no wider.
	var width: float = StylePack.kinds()["tram"]["width"] / 100.0
	for style in ["lowpoly_tropical", "anime_cel", "solarpunk", "neon_noir", "voxel"]:
		var h := host()
		assert_true(h.activate("res://styles/" + style, manifest(), SceneModel.new(), Motion.new(), 0.0), style + " builds: " + h.last_error)
		var body: Node3D = h.pack.town.tram()
		var band := KitTown.band_box_of(body, Vector2(0.25, 1.9))
		assert_true(absf(band.size.y - width) < 0.005, "%s draws its tram %.3f m wide where people walk" % [style, band.size.y])
		assert_true(absf(band.get_center().y) < 0.005, "%s centres it on its track (%.3f)" % [style, band.get_center().y])
		body.free()
		h.free()


func test_every_style_spawns_moves_and_despawns_a_tram_with_its_riders() -> void:
	var h := host()
	for dir in h.discover():
		var model := SceneModel.new()
		var motion := Motion.new()
		assert_true(h.activate(dir, manifest(), model, motion, 0.0), dir + " builds: " + h.last_error)
		var pack: StylePack = h.pack
		var standing := vehicle(EAST, AT_SQUARE, {"status": "standing", "doors_open": true})
		h.apply_changes(model.apply(projection([standing, vehicle(WEST, 4000)],
			[rider("r0", EAST, 0), rider("r6", EAST, 6)])), motion)
		assert_eq(pack.vehicle_nodes.size(), 2, dir + " draws both trams")
		var tram: Node = pack.vehicle_nodes[EAST]
		for id in ["r0", "r6"]:
			assert_true(tram.is_ancestor_of(pack.nodes[id]), dir + " carries %s inside the tram" % id)
		if tram is Node3D:
			assert_true(tram.global_position.distance_to(Vector3(10.25, 0, 19.0)) < 0.01, dir + " puts the front at the stop's far end: %s" % tram.global_position)
			assert_true(tram.global_basis.x.distance_to(Vector3(1, 0, 0)) < 0.01, dir + " runs it east")
			var r0: Vector3 = pack.nodes["r0"].global_position
			assert_true(Vector2(r0.x, r0.z).distance_to(Vector2(9.74, 18.5)) < 0.05, dir + " seats slot 0 at the front on the left: %s" % r0)
			var west: Node3D = pack.vehicle_nodes[WEST]
			assert_true(west.global_basis.x.distance_to(Vector3(-1, 0, 0)) < 0.01, dir + " runs the other one west")
			# The body fills the line's 20.5 m behind the front at the kit's
			# own width (ruling: the tracks are 3 m apart, so trams passing
			# clear each other unsqueezed; it was fitted to 2 m).
			var box: AABB = Pack3D._bounds(tram.get_child(0), Transform3D.IDENTITY)
			assert_true(absf(box.position.x + 20.5) < 0.05 and absf(box.end.x) < 0.05, dir + " fits the tram to its length: %s" % box)
			assert_true(box.size.z > 2.3 and box.size.z < 2.65, dir + " keeps the tram's modelled width: %s" % box)
		else:
			assert_eq(tram.position, pack.call("iso", 0.0, 19.0), dir + " centres the tram on the stop")
			var r0: Vector2 = pack.call("ground_of", pack.nodes["r0"])
			assert_true(r0.distance_to(Vector2(9.74, 18.5)) < 0.1, dir + " puts slot 0 at the front on the left: %s" % r0)
			assert_eq(pack.vehicle_nodes[WEST].position, pack.call("iso", 32.25, 22.0), dir + " a westbound tram trails east of its front")
		# It runs on 7 m, drawn half way at half the tick.
		h.apply_changes(model.apply(projection([vehicle(EAST, 3525, {"trail": [AT_SQUARE, 3525]}), vehicle(WEST, 4000)],
			[rider("r0", EAST, 0), rider("r6", EAST, 6)])), motion)
		h.tick_frame(0.5, motion)
		if tram is Node3D:
			assert_true(absf(tram.global_position.x - 13.75) < 0.01, dir + " moves the tram smoothly: %s" % tram.global_position)
		else:
			assert_eq(tram.position, pack.call("iso", 3.5, 19.0), dir + " moves the tram smoothly")
		assert_true(tram.is_ancestor_of(pack.nodes["r0"]), dir + " and its riders with it")
		# Its riders step off, and it leaves.
		h.apply_changes(model.apply(projection([], [], [person("r0"), person("r6", {"pos": {"x": 700, "z": 1600}})])), motion)
		assert_true(pack.vehicle_nodes.is_empty(), dir + " despawns the trams")
		for id in ["r0", "r6"]:
			assert_eq(pack.nodes[id].get_parent(), pack.occupant_parent(), dir + " sets %s down on the ground" % id)
	h.free()


func test_no_pack_keeps_its_own_tram_clock() -> void:
	var found := []
	for path in _scripts("res://core") + _scripts("res://styles") + ["res://main.gd"]:
		var text := FileAccess.get_file_as_string(path)
		for word in ["tram_clock", "_move_trams", "tram_at(", "\"tram-line\""]:
			if text.contains(word):
				found.append("%s: %s" % [path, word])
	assert_eq(found, [], "trams come from the projection alone")


func _scripts(root: String) -> Array:
	var out := []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(root.path_join(f))
	for sub in dir.get_directories():
		out.append_array(_scripts(root.path_join(sub)))
	return out


func test_every_style_draws_the_rails_from_the_lines() -> void:
	var h := host()
	var m := manifest()
	for item in m["scenery"]:
		assert_true(item["kind"] != "tram-line", "the district has no tram-line scenery: its track is a line")
	for dir in h.discover():
		assert_true(h.activate(dir, m, SceneModel.new(), Motion.new(), 0.0), dir + " builds: " + h.last_error)
		var pack: StylePack = h.pack
		assert_eq(pack.track_nodes.size(), 2, dir + " draws both of the line's tracks")
		for node in pack.track_nodes:
			assert_eq(node.get_meta("line", ""), "line:boulevard", dir + " from the boulevard line")
		if pack.track_nodes[0] is Node3D:
			for k in 2:
				var z := 19.0 if k == 0 else 22.0
				var pieces := 0
				var xs := []
				# Each chunk of track pieces records where they stand on
				# average (instance transforms stay with a renderer).
				for mmi in pack.track_nodes[k].find_children("*", "MultiMeshInstance3D", true, false):
					if not str(mmi.name).begins_with("Track"):
						continue
					pieces += mmi.multimesh.instance_count
					var at: Vector3 = mmi.global_transform * (mmi.get_meta("centre") as Vector3)
					assert_true(absf(at.z - z) < 0.01, dir + " lays track %d along z %s: %s" % [k, z, at])
					xs.append(at.x)
				assert_eq(pieces, 43, dir + " lays track %d in 2 m pieces over its 86 m" % k)
				assert_true(not xs.is_empty() and xs.min() < -5.0 and xs.max() > 60.0,
					dir + " lays track %d from portal to portal: %s" % [k, xs])
		else:
			# Each track runs on a cell edge (z 19 and 22), so it is laid
			# in the two rows either side, half a track in each.
			var ground: Dictionary = pack.style["ground"]
			for x in range(-18, 68):
				for row in [[18, "track_x_s"], [19, "track_x_n"], [21, "track_x_s"], [22, "track_x_n"]]:
					assert_eq(str(pack.cells.get(Vector2i(x, row[0]))), str(ground[row[1]]),
						dir + " lays half a track in row %d at %d" % [row[0], x])
			assert_true(not str(pack.cells.get(Vector2i(0, 20))).contains("track"), dir + " leaves the gap between the tracks")
	# A city without a line draws no rails.
	var bare := manifest()
	bare.erase("lines")
	h.activate(FAKE, bare, SceneModel.new(), Motion.new(), 0.0)
	assert_eq(h.pack.track_nodes.size(), 0, "no line, no rails")
	h.free()


## The opening views (diagonal and street) frame the district as they did
## before the line: its outlying platforms are left out; top-down still
## frames everything placed.
func test_the_opening_views_leave_the_outlying_platforms_out() -> void:
	var h := host()
	var m := manifest()
	var avenue := Rect2(52, 15, 16, 11)
	for dir in h.discover():
		h.activate(dir, m, SceneModel.new(), Motion.new(), 0.0)
		var pack: StylePack = h.pack
		var framed: Rect2 = pack.rig.bounds if pack.get("rig") != null else pack.district
		assert_eq(framed, Rect2(-34, -14, 70, 44), dir + " frames the district as before the line")
		var whole: Rect2 = pack.rig.whole if pack.get("rig") != null else pack.whole
		assert_true(whole.encloses(avenue), dir + " still takes in the Avenue platforms from overhead")
	h.free()


# ---- Switching mid-line (Review Focus 4) ----

## The client booted on the district and run until a tram is running with
## riders aboard, shown half way through its tick.
func running_with_riders():
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=20", "--as=none", "--style=anime_cel"]))
	for i in 150:
		main.driver.advance(1.0)
		if _riding_vehicle(main) != "":
			break
	main.driver.tick_time = 0.5
	main.host.tick_frame(0.5, main.motion)
	return main


func _riding_vehicle(main) -> String:
	for id in main.model.vehicles:
		var v: Dictionary = main.model.vehicles[id]
		if v.get("trail", []).size() < 2 or v["trail"][0] == v["trail"][-1]:
			continue
		for o in main.model.occupants.values():
			if o["view"].get("vehicle") == id:
				return id
	return ""


## Checks the pack shown draws exactly the model's trams, each where it is
## half way through the tick, with every rider inside its own tram.
func assert_trams_drawn(main, label: String, with_riders := true) -> void:
	var pack: StylePack = main.host.pack
	var want: Array = main.model.vehicles.keys()
	want.sort()
	var have: Array = pack.vehicle_nodes.keys()
	have.sort()
	assert_eq(have, want, label + ": the trams the world has, and no others")
	for id in want:
		var v: Dictionary = main.model.vehicles[id]
		var trail: Array = v.get("trail", [])
		var along: float = float(v["along"]) if trail.size() < 2 else (float(trail[0]) + float(trail[-1])) / 2.0
		var expected := Vector2(-1800 + along, 1900 if v["direction"] == "east" else 2200)
		assert_true(near(pack.vehicle_places[id][0], expected), label + ": %s half way through its tick: %s, not %s" % [id, pack.vehicle_places[id][0], expected])
		assert_true(is_instance_valid(pack.vehicle_nodes[id]) and pack.vehicle_nodes[id].is_inside_tree(), label + ": %s is drawn" % id)
	var riders := 0
	for oid in main.model.occupants:
		var vid = main.model.occupants[oid]["view"].get("vehicle")
		if vid == null:
			assert_true(not pack.riders.has(oid), label + ": %s is on the ground" % oid)
			continue
		riders += 1
		assert_eq(pack.riders.get(oid), vid, label + ": %s rides %s" % [oid, vid])
		assert_true(pack.vehicle_nodes[vid].is_ancestor_of(pack.nodes[oid]), label + ": %s is drawn inside it" % oid)
	if with_riders:
		assert_true(riders > 0, label + ": with riders aboard")
	assert_eq(main.host.get_child_count(), 1, label + ": one pack shown, none left behind")


func test_a_style_switch_mid_line_draws_each_tram_where_it_is_with_its_riders() -> void:
	var main = running_with_riders()
	var id := _riding_vehicle(main)
	assert_true(id != "", "a tram is running with riders aboard")
	assert_trams_drawn(main, "anime")
	var old: Node = main.host.pack.vehicle_nodes[id]
	main._activate("res://styles/pixel_art")
	assert_true(not is_instance_valid(old), "the old style's tram is gone")
	assert_trams_drawn(main, "pixel art")
	main._activate("res://styles/lowpoly_tropical")
	assert_trams_drawn(main, "low-poly")
	# And the trams keep in step with the world after it.
	for i in 40:
		main.driver.advance(1.0)
	main.driver.tick_time = 0.5
	main.host.tick_frame(0.5, main.motion)
	assert_trams_drawn(main, "low-poly, 40 ticks on", false)
	main.free()


func test_a_viewer_switch_mid_line_rebuilds_the_trams_and_riders() -> void:
	var main = running_with_riders()
	assert_true(_riding_vehicle(main) != "", "a tram is running with riders aboard")
	main._set_viewer("person:asha")
	assert_trams_drawn(main, "Asha's view")
	main._set_viewer("public")
	assert_trams_drawn(main, "the public view again")
	main.free()


# ---- Doors, riders, roofs, portals and night (Task 9) ----

## A standing eastbound tram at the Square: its doors face the north
## platform, on its left.
func at_square(extra := {}) -> Dictionary:
	var v := vehicle(EAST, AT_SQUARE, {"status": "standing", "stop": "stop:square"})
	v.merge(extra, true)
	return v


func agent(id: String, extra := {}) -> Dictionary:
	return person(id, {"kind": {"type": "GuildAgent"}, "presence": {"headline": "Working"}}).merged(extra, true)


## Every style opens its tram's doors on the platform side over 0.4 s,
## the two leaves of each door sliding apart, and shuts them likewise.
func test_every_style_opens_its_tram_doors_on_the_platform_side_over_0_4_s() -> void:
	var h := host()
	for dir in h.discover():
		var model := SceneModel.new()
		var motion := Motion.new()
		assert_true(h.activate(dir, manifest(), model, motion, 0.0), dir + " builds: " + h.last_error)
		var pack: StylePack = h.pack
		h.apply_changes(model.apply(projection([at_square()])), motion)
		var leaves: Array = pack.door_leaves(EAST)
		assert_eq(leaves.size(), 12, dir + " draws two leaves a door, three doors a side")
		var rest := []
		for leaf in leaves:
			rest.append(leaf["node"].position)
		assert_eq(pack.door_amount(EAST), 0.0, dir + " starts with its doors shut")
		h.apply_changes(model.apply(projection([at_square({"doors_open": true})])), motion)
		pack.animate_vehicles(0.2)
		assert_true(absf(pack.door_amount(EAST) - 0.5) < 0.01, dir + " is half open at 0.2 s: %s" % pack.door_amount(EAST))
		pack.animate_vehicles(0.25)
		assert_eq(pack.door_amount(EAST), 1.0, dir + " is open by 0.4 s")
		var moved := {}
		for k in leaves.size():
			var leaf: Dictionary = leaves[k]
			var d: Vector2 = _flat(leaf["node"].position - rest[k])
			if leaf["side"] == "left":
				assert_true(d.length() > 4.0 if leaf["node"] is Node2D else d.length() > 0.5,
					dir + " slides %s open: %s" % [leaf["node"].name, d])
				moved[leaf["leaf"]] = moved.get(leaf["leaf"], Vector2.ZERO) + d
			else:
				assert_true(d.length() < 0.001, dir + " keeps %s shut, away from the platform" % leaf["node"].name)
		assert_true(moved["fore"].dot(moved["aft"]) < 0.0, dir + " slides each door's leaves apart")
		h.apply_changes(model.apply(projection([at_square()])), motion)
		pack.animate_vehicles(0.45)
		assert_eq(pack.door_amount(EAST), 0.0, dir + " shuts them again")
		for k in leaves.size():
			assert_true(_flat(leaves[k]["node"].position - rest[k]).length() < 0.001, dir + " back where it was")
	h.free()


func _flat(v) -> Vector2:
	return Vector2(v.x, v.z) if v is Vector3 else v


## Riders sit and stand inside the tram in every style: within its body,
## on its floor; in pixel art within its footprint, lifted onto its floor.
func test_every_style_draws_its_riders_inside_the_tram() -> void:
	var h := host()
	var layout := StylePack.tram_layout()
	var floor_m := float(layout["floor_cm"]) / 100.0
	for dir in h.discover():
		var model := SceneModel.new()
		var motion := Motion.new()
		h.activate(dir, manifest(), model, motion, 0.0)
		var pack: StylePack = h.pack
		h.apply_changes(model.apply(projection([at_square()],
			[rider("r0", EAST, 0), rider("r7", EAST, 7), rider("r39", EAST, 39), rider("r22", EAST, 22)])), motion)
		var tram: Node = pack.vehicle_nodes[EAST]
		for id in ["r0", "r7", "r39", "r22"]:
			var node = pack.nodes[id]
			if tram is Node3D:
				var local: Vector3 = tram.global_transform.affine_inverse() * node.global_position
				var box: AABB = Pack3D._bounds(tram.get_child(0), Transform3D.IDENTITY)
				assert_true(local.x > box.position.x + 0.2 and local.x < box.end.x - 0.2 and absf(local.z) < 1.1,
					dir + " draws %s inside the tram: %s in %s" % [id, local, box])
				assert_true(absf(local.y - float(tram.get_meta("floor_m", -1.0))) < 0.001 and absf(float(tram.get_meta("floor_m", -1.0)) - floor_m) < 0.11,
					dir + " stands %s on the tram's floor: %s" % [id, local.y])
			else:
				var ground: Vector2 = pack.call("ground_of", node)
				assert_true(ground.x > -10.25 and ground.x < 10.25 and absf(ground.y - 19.0) < 1.0,
					dir + " draws %s inside the tram's footprint: %s" % [id, ground])
				assert_eq(node.get_node("Body").position.y, -roundf(16.0 * floor_m), dir + " lifts %s onto the floor" % id)
		assert_eq(pack.poses["r7"], "standing", dir + " by the doors, standing")
		assert_eq(pack.poses["r22"], "sitting", dir + " in the seats, sitting")
	h.free()


## A rider's status icon, drawn over everything, is hidden while it rides,
## so it never pokes through the tram's roof; it shows again once off.
func test_a_riders_status_icon_is_hidden_aboard() -> void:
	var h := host()
	for dir in h.discover():
		var model := SceneModel.new()
		var motion := Motion.new()
		h.activate(dir, manifest(), model, motion, 0.0)
		var pack: StylePack = h.pack
		h.apply_changes(model.apply(projection([at_square({"doors_open": true})], [], [agent("agent:kai")])), motion)
		# A style shows the icon, or a glyph where it has none.
		var marks := func() -> bool:
			var node: Node = pack.nodes["agent:kai"]
			return node.get_node("Icon").visible or (node.has_node("Glyph") and node.get_node("Glyph").visible)
		assert_true(marks.call(), dir + " shows a working agent's icon on the ground")
		h.apply_changes(model.apply(projection([at_square({"doors_open": true})], [agent("agent:kai", {"vehicle": EAST, "slot": 3})])), motion)
		assert_true(not marks.call(), dir + " hides it while the agent rides")
		pack.set_presence("agent:kai", "Working")
		assert_true(not marks.call(), dir + " and keeps it hidden when its presence changes aboard")
		h.apply_changes(model.apply(projection([at_square({"doors_open": true})], [], [agent("agent:kai")])), motion)
		assert_true(marks.call(), dir + " shows it again once the agent steps off")
	h.free()


## Trams fade over the last 10 m at each portal: gone with their middle at
## the portal, half there 5 m in, whole 10 m in; riders fade with them.
func test_every_style_fades_its_trams_over_the_last_10_m_at_each_portal() -> void:
	var h := host()
	var length := 8600
	for dir in h.discover():
		var model := SceneModel.new()
		var motion := Motion.new()
		h.activate(dir, manifest(), model, motion, 0.0)
		var pack: StylePack = h.pack
		for c in [[EAST, 1025, 0.0], [EAST, 1525, 0.5], [EAST, 2025, 1.0], [EAST, 5000, 1.0],
				[EAST, length + 1025, 0.0], [EAST, length + 525, 0.5],
				[WEST, -1025, 0.0], [WEST, -525, 0.5], [WEST, length - 1025 - 1000, 1.0]]:
			h.apply_changes(model.apply(projection([vehicle(c[0], c[1])], [rider("r0", c[0], 0)])), motion)
			pack.animate_vehicles(0.0)
			var got := pack.vehicle_opacity(c[0])
			assert_true(absf(got - c[2]) < 0.01, dir + " %s with its front %d cm along: opacity %s, not %s" % [c[0], c[1], got, c[2]])
			var tram: Node = pack.vehicle_nodes[c[0]]
			if tram is Node3D:
				var parts := tram.find_children("*", "GeometryInstance3D", true, false)
				for g in parts:
					if pack.nodes["r0"].is_ancestor_of(g) or not g.is_visible_in_tree():
						continue
					assert_true(absf(g.transparency - (1.0 - c[2])) < 0.01 or (str(g.name) in ["roof", "lights"] and g.transparency >= 1.0 - c[2] - 0.01),
						dir + " fades %s to %s: %s" % [g.name, c[2], g.transparency])
				assert_eq(tram.visible, c[2] > 0.0, dir + " hides a tram faded right out")
			else:
				assert_true(absf(tram.modulate.a - c[2]) < 0.01, dir + " fades the sprites to %s: %s" % [c[2], tram.modulate.a])
			h.apply_changes(model.apply(projection([])), motion)
	h.free()


## The 3D trams' roofs fade away in the overhead views up close, the way
## the buildings' roofs cut away, so their riders show from above; the
## street view keeps them unless the camera is inside the tram.
func test_the_tram_roof_fades_overhead_up_close_and_stays_in_the_street_view() -> void:
	assert_true(Pack3D.roof_cut(-89.0, 30.0, false, false), "top-down up close: cut")
	assert_true(Pack3D.roof_cut(-36.0, 40.0, false, false), "the diagonal up close: cut")
	assert_true(not Pack3D.roof_cut(-36.0, 66.0, false, false), "the diagonal far off: kept")
	assert_true(not Pack3D.roof_cut(4.4, 17.0, false, false), "the street view: kept")
	assert_true(Pack3D.roof_cut(4.4, 17.0, true, false), "the camera inside the tram: cut")
	assert_true(not Pack3D.roof_cut(-89.0, 30.0, false, true), "roofs kept on (C): kept")
	var h := host()
	for dir in h.discover():
		var model := SceneModel.new()
		var motion := Motion.new()
		h.activate(dir, manifest(), model, motion, 0.0)
		var pack: StylePack = h.pack
		if pack.get("rig") == null:
			continue
		h.apply_changes(model.apply(projection([at_square()], [rider("r0", EAST, 0)])), motion)
		var roof: Node3D = pack.vehicle_nodes[EAST].find_child("roof", true, false)
		assert_true(roof != null, dir + " has a roof to fade")
		pack.rig.apply_preset("topdown")
		pack.rig.position = Vector3(0, 0, 19)
		pack.rig.distance = 30.0
		pack.rig.update()
		pack.animate_vehicles(0.1)
		assert_true(pack.roof_shown(EAST) > 0.0 and pack.roof_shown(EAST) < 1.0, dir + " fades it rather than popping")
		pack.animate_vehicles(1.0)
		assert_eq(pack.roof_shown(EAST), 0.0, dir + " cuts it away top-down up close")
		assert_true(not roof.visible, dir + " and hides it once faded")
		pack.rig.distance = 90.0
		pack.rig.update()
		pack.animate_vehicles(1.0)
		assert_eq(pack.roof_shown(EAST), 1.0, dir + " keeps it top-down far off")
		pack.rig.apply_preset("street")
		pack.animate_vehicles(1.0)
		assert_eq(pack.roof_shown(EAST), 1.0, dir + " keeps it in the street view")
		assert_true(roof.visible and roof.transparency == 0.0, dir + " whole")
		# The camera inside the tram, looking along it.
		pack.rig.position = Vector3(0, 1.7, 19)
		pack.rig.distance = 0.5
		pack.rig.update()
		pack.animate_vehicles(1.0)
		assert_eq(pack.roof_shown(EAST), 0.0, dir + " cuts it with the camera inside")
	h.free()


## Riders cost only what can be seen of them (tram spec section 1,
## criterion 4): aboard, no part of them casts a shadow, seated or standing
## they hold their pose (posed once, never advanced again), a kit's far
## body takes over from RIDER_FAR_M, and with the roof on they are hidden
## from a camera looking down on it from afar. Stepping off undoes it all.
func test_riders_cast_no_shadow_hold_their_pose_and_go_far_early_in_every_3d_style() -> void:
	# Pack3D.RIDER_FAR_M and FAR_M: riders take the far body from 25 m,
	# walkers from 45 m.
	var rider_far := 25.0
	var walker_far := 45.0
	var size_was: Vector2i = runner.root.size
	runner.root.size = Vector2i(1600, 900)
	var h := host()
	for dir in h.discover():
		var model := SceneModel.new()
		var motion := Motion.new()
		h.activate(dir, manifest(), model, motion, 0.0)
		var pack: StylePack = h.pack
		if not (pack is Pack3D):
			continue
		await runner.process_frame
		# Up close over the Square, the roof faded: the riders show.
		pack.rig.apply_preset("topdown")
		pack.rig.position = Vector3(10, 0, 19)
		pack.rig.distance = 20.0
		pack.rig.update()
		h.apply_changes(model.apply(projection([at_square()], [rider("r7", EAST, 7), rider("r22", EAST, 22)], [person("walker")])), motion)
		assert_eq([pack.poses["r7"], pack.poses["r22"]], ["standing", "sitting"], dir + ": one standing, one seated")
		var parts := func(id: String) -> Array:
			return pack.nodes[id].get_node("Model").find_children("*", "GeometryInstance3D", true, false)
		for id in ["r7", "r22"]:
			var cast: Array = parts.call(id).filter(func(g): return g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			assert_eq(cast.size(), 0, dir + ": %s casts no shadow aboard: %s" % [id, cast.map(func(g): return str(g.name))])
		assert_true(parts.call("walker").any(func(g): return g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON), dir + ": a walker does")
		var seated: AnimationPlayer = Pack3D._player_of(pack.nodes["r22"].get_node("Model"))
		var standing: AnimationPlayer = Pack3D._player_of(pack.nodes["r7"].get_node("Model"))
		pack._process(1.0 / 60.0)
		var held := seated.current_animation_position
		var stood := standing.current_animation_position
		for f in 60:
			pack._process(1.0 / 60.0)
		assert_eq(seated.current_animation_position, held, dir + ": the seated rider holds its pose")
		assert_eq(standing.current_animation_position, stood, dir + ": and so does the standing one")
		assert_eq([seated.current_animation, standing.current_animation], [seated.assigned_animation, standing.assigned_animation], dir + ": each in its own clip")
		assert_true(not pack._live.has("r22") and not pack._live.has("r7"), dir + ": neither looked at each frame")
		# Up close each rider shows its near parts; further off than 25 m
		# (the diagonal view), a kit's far body alone, the rest hidden.
		var far = pack.nodes["r22"].find_child("far", true, false)
		var near_shown := func() -> bool:
			return parts.call("r22").any(func(g): return g != far and g.visible)
		if far != null:
			assert_true(near_shown.call() and not far.visible, dir + ": near parts up close")
		# The roof on, looking down on it from far off: hidden; through the
		# windows from the diagonal view: shown; near again: shown.
		pack.rig.distance = 90.0
		pack.rig.update()
		pack.animate_vehicles(1.0)
		assert_true(not pack.nodes["r22"].visible and not pack.nodes["r7"].visible, dir + ": hidden under the roof from 90 m above")
		pack.rig.apply_preset("diagonal")
		pack.rig.position = Vector3(10, 0, 19)
		pack.rig.update()
		pack.animate_vehicles(1.0)
		assert_true(pack.nodes["r22"].visible, dir + ": seen through the windows from the diagonal view, %.0f m off" % pack.rig.distance)
		if far != null:
			assert_true(far.visible and far.visibility_range_begin == 0.0 and not near_shown.call(), dir + ": by the far body alone from %.0f m (beyond %s m)" % [pack.rig.distance, rider_far])
			for k in far.mesh.get_surface_count():
				var mat: Material = far.get_surface_override_material(k)
				assert_true(mat == null or mat.next_pass == null, dir + ": the far body without its ink outline, surface %d" % k)
		else:
			var shoes = pack.nodes["r22"].find_child("shoes", true, false)
			assert_true(shoes != null and not shoes.visible, dir + ": with no far body, its shoes shed from %.0f m" % pack.rig.distance)
		pack.rig.apply_preset("topdown")
		pack.rig.position = Vector3(10, 0, 19)
		pack.rig.distance = 20.0
		pack.rig.update()
		pack.animate_vehicles(1.0)
		assert_true(pack.nodes["r22"].visible, dir + ": shown up close again")
		# Off the tram, a walker again.
		pack.rig.distance = 90.0
		pack.rig.update()
		pack.animate_vehicles(1.0)
		h.apply_changes(model.apply(projection([at_square({"doors_open": true})], [rider("r7", EAST, 7)], [person("walker"), person("r22")])), motion)
		assert_true(pack.nodes["r22"].visible, dir + ": shown once off")
		assert_true(pack._live.has("r22"), dir + ": animated again once off")
		assert_true(parts.call("r22").any(func(g): return g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON), dir + ": casting shadows again")
		var shoes_off = pack.nodes["r22"].find_child("shoes", true, false)
		assert_true(shoes_off == null or shoes_off.visible, dir + ": its shoes back on once off")
		if far != null:
			assert_eq(far.visibility_range_begin, walker_far, dir + ": the far body from %s m again" % walker_far)
			assert_true(far.visible and near_shown.call(), dir + ": near parts back, the walkers' distances deciding")
			assert_true(not far.get_meta_list().any(func(k): return str(k).begins_with("inked_")), dir + ": and its own materials back")
		h.apply_changes(model.apply(projection([])), motion)
	h.free()
	runner.root.size = size_was


## At night the tram's ceiling lights glow at the style's window energy,
## as lit windows do, and light its inside; by day they are out. Its glass
## is see-through, so its riders show.
func test_a_trams_inside_is_lit_at_night_as_windows_are() -> void:
	var h := host()
	for dir in h.discover():
		var model := SceneModel.new()
		var motion := Motion.new()
		h.activate(dir, manifest(), model, motion, 0.0)
		var pack: StylePack = h.pack
		if pack.get("rig") == null:
			continue
		h.apply_changes(model.apply(projection([at_square()])), motion)
		var tram: Node3D = pack.vehicle_nodes[EAST]
		var lights: MeshInstance3D = tram.find_child("lights", true, false)
		assert_true(lights != null, dir + " has ceiling lights")
		var mat: BaseMaterial3D = lights.mesh.surface_get_material(0)
		var glows := tram.find_children("*", "OmniLight3D", true, false)
		assert_true(not glows.is_empty(), dir + " lights its inside")
		pack.set_time_of_day(22 * 60)
		assert_true(absf(mat.emission_energy_multiplier - float(pack.style.get("window_energy", 2.5))) < 0.001,
			dir + " glows at the window energy by night: %s" % mat.emission_energy_multiplier)
		for g in glows:
			assert_true(g.visible and g.light_energy > 0.0, dir + " with its inside lit")
		pack.set_time_of_day(12 * 60)
		for g in glows:
			assert_true(not g.visible, dir + " and dark by day")
		var glass := 0
		for mi in tram.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var m: Material = mi.mesh.surface_get_material(s)
				if m is BaseMaterial3D and str(m.resource_name).begins_with("glass"):
					glass += 1
					assert_true(m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and m.albedo_color.a < 0.6,
						dir + " sees through %s's glass" % mi.name)
		assert_true(glass > 0, dir + " has glass")
	h.free()


## Pixel art: two trams standing side by side each sort as a unit, the
## nearer (south) one over the farther wherever they overlap, and each
## rider is drawn in its tram's windows: over the far side and the floor
## behind and beside it, under the near side. (A back slice further along
## holds nearer seats, which may hide a far rider's legs, as the near side
## does anyway.)
func test_pixel_trams_side_by_side_sort_as_units_with_riders_in_their_windows() -> void:
	var h := host()
	var model := SceneModel.new()
	var motion := Motion.new()
	h.activate("res://styles/pixel_art", manifest(), model, motion, 0.0)
	var pack: StylePack = h.pack
	var west_at := vehicle(WEST, AT_SQUARE - 2050, {"status": "standing", "stop": "stop:square"})
	h.apply_changes(model.apply(projection([at_square(), west_at],
		[rider("e0", EAST, 0), rider("e11", EAST, 11), rider("e30", EAST, 30),
		 rider("w0", WEST, 0), rider("w13", WEST, 13)])), motion)
	var north: Node2D = pack.vehicle_nodes[EAST]
	var south: Node2D = pack.vehicle_nodes[WEST]
	var items := {}
	for tram in [north, south]:
		for c in tram.get_children():
			if c is Node2D:
				items[c] = [tram, _rect_of(c), c.global_position.y, c.get_index()]
	var wrong := []
	for a in items:
		for b in items:
			if items[a][0] != north or items[b][0] != south or not items[a][1].intersects(items[b][1]):
				continue
			if not _draws_before(items[a], items[b]):
				wrong.append("%s over %s" % [a.name, b.name])
	assert_eq(wrong, [], "the far tram never draws over the near one")
	for id in ["e0", "e11", "e30", "w0", "w13"]:
		var rider_node: Node2D = pack.nodes[id]
		var tram: Node2D = rider_node.get_parent()
		var mine: Array = items[rider_node]
		# The slice the rider stands in, counting from the tram's -x end.
		var slice := floori(pack.call("ground_of", rider_node).x - pack.call("ground_of", tram).x + 10.5)
		for c in items:
			if items[c][0] != tram or c == rider_node or not items[c][1].intersects(mine[1]):
				continue
			if str(c.name).begins_with("Back_") and int(str(c.name).get_slice("_", 1)) <= slice:
				assert_true(_draws_before(items[c], mine), "%s draws over %s, the far side" % [id, c.name])
			elif str(c.name).begins_with("Front"):
				assert_true(_draws_before(mine, items[c]), "%s draws under %s, the near side" % [id, c.name])
	h.free()


func _draws_before(a: Array, b: Array) -> bool:
	return a[2] < b[2] or (a[2] == b[2] and a[0] == b[0] and a[3] < b[3])


## What a tram's child covers on screen: a sprite's texture, or a rider's
## body frame.
func _rect_of(n: Node2D) -> Rect2:
	var s: Node2D = n.get_node_or_null("Body") if n.get_node_or_null("Body") != null else n
	var r := Rect2()
	if s is Sprite2D and s.texture != null:
		r = Rect2(s.offset, s.texture.get_size())
	elif s is AnimatedSprite2D:
		r = Rect2(s.offset - Vector2(16, 34), Vector2(32, 40))
	return s.get_global_transform() * r
