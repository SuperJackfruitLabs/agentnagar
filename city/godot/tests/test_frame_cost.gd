## Things that cost a frame and show nothing: lamps switched off by day, and
## shadows from a person's small parts.
extends TestSuite


func manifest() -> Dictionary:
	return JSON.parse_string(CityPaths.district_manifest())


func host(dir: String, views := [], minutes := 720) -> StyleHost:
	var m := SceneModel.new()
	m.apply({"rooms": [{"id": "room:plaza", "occupants": views, "waiting": []}], "in_transit": [], "time_of_day": minutes})
	var h := StyleHost.new()
	runner.root.add_child(h)
	assert_true(h.activate(dir, manifest(), m, Motion.new(), 0.0), h.last_error)
	return h


func test_lamps_off_by_day_are_out_of_the_frame() -> void:
	var h := host("res://styles/neon_noir", [], 720)
	assert_true(h.pack.lamps.all(func(l): return not l.visible), "no lamp in the frame by day")
	h.pack.set_time_of_day(1320)
	assert_true(h.pack.lamps.all(func(l): return l.visible), "all lit at night")
	h.free()


func test_a_persons_small_parts_cast_no_shadow() -> void:
	var person := {"id": "person:a", "kind": {"type": "Human", "tier": "Registered"}, "display_name": "a", "role": "",
		"badge": null, "appearance": {"palette": "3", "hair": "2"}, "seat": null, "presence": {"headline": "Present"},
		"pos": {"x": 0, "z": 0}}
	for dir in ["res://styles/anime_cel", "res://styles/solarpunk"]:
		var h := host(dir, [person])
		var model: Node = h.pack.nodes["person:a"].get_node("Model")
		for part in ["face", "details"]:
			var n = model.find_child(part, true, false)
			if n is GeometryInstance3D:
				assert_eq(n.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s %s casts no shadow" % [dir, part])
		h.free()


func test_a_style_sets_its_shadow_quality_and_leaves_it_as_found() -> void:
	var h := host("res://styles/anime_cel")
	assert_eq(h.pack.shadow_settings(), {"atlas": 2048, "filter": RenderingServer.SHADOW_QUALITY_HARD}, "anime: a small atlas, crisp shadows")
	assert_eq(h.pack.sun.directional_shadow_mode, DirectionalLight3D.SHADOW_ORTHOGONAL, "one split")
	h.activate("res://styles/lowpoly_tropical", manifest(), SceneModel.new(), Motion.new(), 0.0)
	assert_eq(h.pack.shadow_settings(), {"atlas": ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", 4096),
		"filter": ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 2)}, "the next style gets the project's")
	h.free()


func test_neon_draws_without_ambient_occlusion() -> void:
	var h := host("res://styles/neon_noir")
	assert_true(not h.pack.env.ssao_enabled, "night light needs no occlusion pass")
	h.free()


func test_warming_up_the_people_leaves_no_one_behind() -> void:
	for dir in ["res://styles/anime_cel", "res://styles/neon_noir"]:
		var h := host(dir)
		assert_true(h.pack.nodes.is_empty(), dir + ": no occupants")
		assert_true(h.pack._mixers.keys().all(func(id): return not str(id).begins_with("warm:")), dir + ": no warm-up animators left")
		assert_true(h.pack.labels.keys().all(func(id): return not str(id).begins_with("warm:")), dir + ": no warm-up labels left")
		h.free()


func test_easing_rain_over_a_crowd_is_cheap() -> void:
	var views := []
	for k in 150:
		views.append({"id": "person:r%d" % k, "kind": {"type": "Human", "tier": "Registered"}, "display_name": "r", "role": "",
			"badge": null, "appearance": {"palette": str(k), "hair": "1"}, "seat": null, "presence": {"headline": "Present"},
			"pos": {"x": (k % 15) * 150 - 1000, "z": (k / 15) * 150 + 300}})
	var h := host("res://styles/anime_cel", views, 1250)
	h.pack.set_rain(0.2)
	var t0 := Time.get_ticks_usec()
	for k in 100:
		h.pack.set_rain(0.2 + 0.005 * k)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var rain_budget := 15.0 * machine_factor()
	assert_true(ms < rain_budget, "100 small steps of rain over 150 people: %.1f ms (called every frame as rain eases; budget %.1f ms)" % [ms, rain_budget])
	var outside := 0
	for id in h.pack.nodes:
		var u = h.pack.nodes[id].get_node("Model").find_child("umbrella", true, false)
		if u != null and u.visible:
			outside += 1
	assert_true(outside > 0, "umbrellas still open outdoors")
	h.pack.set_rain(0.0)
	for id in h.pack.nodes:
		var u = h.pack.nodes[id].get_node("Model").find_child("umbrella", true, false)
		assert_true(u == null or not u.visible, "and furl when it stops")
	h.free()


func test_parts_a_person_never_shows_are_let_go() -> void:
	var person := {"id": "person:a", "kind": {"type": "Human", "tier": "Registered"}, "display_name": "a", "role": "",
		"badge": null, "appearance": {"palette": "3", "hair": "2"}, "seat": null, "presence": {"headline": "Present"},
		"pos": {"x": 0, "z": 0}}
	for dir in ["res://styles/anime_cel", "res://styles/neon_noir"]:
		var h := host(dir, [person])
		var model: Node = h.pack.nodes["person:a"].get_node("Model")
		assert_true(model.find_child("hair_2", true, false) != null, dir + ": the chosen hair stays")
		for k in [0, 1, 3]:
			assert_true(model.find_child("hair_%d" % k, true, false) == null, dir + ": hair_%d is let go" % k)
		assert_true(model.find_child("umbrella", true, false) != null, dir + ": the umbrella stays (rain shows it)")
		assert_true(model.find_child("far", true, false) != null, dir + ": the far body stays")
		h.free()


func test_glow_is_drawn_only_while_the_lights_are_on() -> void:
	for dir in ["res://styles/anime_cel", "res://styles/solarpunk", "res://styles/neon_noir"]:
		var h := host(dir, [], 720)
		assert_true(not h.pack.env.glow_enabled, dir + ": no glow pass by day (nothing lit bright enough)")
		h.pack.set_time_of_day(1320)
		assert_true(h.pack.env.glow_enabled, dir + ": glow at night")
		h.free()


func test_the_sun_shadows_reach_the_ground_from_every_view() -> void:
	for dir in ["res://styles/anime_cel", "res://styles/solarpunk", "res://styles/neon_noir"]:
		var h := host(dir, [], 720)
		var style_reach := float(h.pack.style.get("shadow_distance", 0.0))
		h.pack.set_camera_preset("topdown")
		h.pack._process(1.0 / 60.0)
		var cam_height: float = h.pack.rig.camera.global_position.y
		assert_true(h.pack.sun.directional_shadow_max_distance > cam_height, "%s top-down: shadows reach the ground %.0f m below (%.0f m)" % [dir, cam_height, h.pack.sun.directional_shadow_max_distance])
		h.pack.set_camera_preset("street")
		h.pack._process(1.0 / 60.0)
		assert_eq(h.pack.sun.directional_shadow_max_distance, style_reach, dir + ": up close, the style's own reach")
		h.free()


## Plants that sway cost 0.3 ms or less a frame on the bench scene (spec
## section 2): 60 walkers crossing the park, each through one of its
## meadows, the camera over the park. Headless timing is noisy, so the
## contacts are updated alone, for a fixed crowd walked on a step a frame,
## and nine frames in ten are held to the budget.
func test_sixty_walkers_crossing_the_park_sway_it_within_budget() -> void:
	var h := host("res://styles/lowpoly_tropical")
	var soft: SoftContacts = h.soft
	assert_true(soft != null and soft.instance_count() > 0, "the park's meadows are soft")
	var meadows: Array[Rect2] = []
	for p in CityGeometry.placements(manifest()):
		if p["kind"] == "meadow":
			meadows.append(CityGeometry.lot(p))
	assert_eq(meadows.size(), 3, "the park's meadows")
	var centre := Rect2(-34.0, 16.0, 16.0, 14.0).get_center()
	# Twenty walkers to a meadow, each in a column of its own across it,
	# crossing it north to south and on (a little beyond either edge), 2 cm
	# a frame: most of them are in the grass at any time.
	var walkers := 60
	var bodies := PackedVector2Array()
	bodies.resize(walkers)
	var frames := 300
	var times := PackedFloat32Array()
	var least_moving := -1
	for f in frames:
		for k in walkers:
			var lot: Rect2 = meadows[k % 3]
			var column := (k / 3 + 0.5) / (walkers / 3)
			var x := lot.position.x + lot.size.x * column
			var z := lot.position.y - 0.3 + fposmod(f * 0.02 + k * 0.37, lot.size.y + 0.6)
			bodies[k] = Vector2(x, z)
		var t0 := Time.get_ticks_usec()
		soft.update(centre, bodies, walkers, 1.0 / 60.0)
		times.append(Time.get_ticks_usec() - t0)
		if f >= 60:
			var moving := 0
			for i in soft.instance_count():
				if soft.bend_of(i) > 0.0:
					moving += 1
			least_moving = moving if least_moving < 0 else mini(least_moving, moving)
	assert_true(least_moving >= 80, "the walkers keep the meadows moving (at least %d clumps a frame)" % least_moving)
	var sorted := Array(times)
	sorted.sort()
	var median_ms: float = sorted[frames / 2] / 1000.0
	var p90_ms: float = sorted[frames * 9 / 10] / 1000.0
	# The budget is the bench machine's: a slower machine (a shared CI
	# runner) gets it scaled by how much slower it runs the same fixed
	# GDScript work, and never less than the budget itself.
	var factor := machine_factor()
	var budget_ms := 0.3 * factor
	print("sway: p90 %.3f ms, median %.3f ms; machine factor %.2f, budget %.3f ms" % [p90_ms, median_ms, factor, budget_ms])
	assert_true(p90_ms <= budget_ms, "60 walkers crossing the park: %.3f ms a frame at the 90th percentile, %.3f ms at the median (budget %.3f ms: 0.3 ms on the bench machine, times %.2f here)" % [p90_ms, median_ms, budget_ms, factor])
	h.free()

