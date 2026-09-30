## The frame-time benchmark's arithmetic and its budget gate (no GPU here:
## the scenes run in scripts/bench.sh on a real display).
extends TestSuite


func test_p99_is_the_nearest_rank_percentile() -> void:
	var samples := []
	for k in 100:
		samples.append(float(k + 1))
	assert_eq(Bench.percentile(samples, 99.0), 99.0, "the 99th of 1..100")
	assert_eq(Bench.percentile(samples, 50.0), 50.0, "the median")
	assert_eq(Bench.percentile([3.0, 1.0, 2.0], 99.0), 3.0, "a short run's worst")


func test_the_summary_of_a_scene() -> void:
	var s := Bench.summary("anime_cel", "diagonal", [2.0, 2.5, 3.0, 2.2])
	assert_eq(s["style"], "anime_cel", "style")
	assert_eq(s["scene"], "diagonal", "scene")
	assert_eq(s["frames"], 4, "frames")
	assert_eq(s["max"], 3.0, "worst frame")


func test_budgets_gate_only_styles_that_declare_them() -> void:
	var results := [
		{"style": "anime_cel", "scene": "diagonal", "heavy": false, "p99": 2.9},
		{"style": "anime_cel", "scene": "street-night-rain-300", "heavy": true, "p99": 4.0},
		{"style": "voxel", "scene": "diagonal", "heavy": false, "p99": 9.0},
	]
	var budgets := {"anime_cel": {"normal_ms": 2.78, "heavy_ms": 4.17}}
	var breaches := Bench.breaches(results, budgets)
	assert_eq(breaches.size(), 1, "one breach: %s" % str(breaches))
	assert_eq(breaches[0]["scene"], "diagonal", "the normal-play diagonal at 2.9 ms")
	assert_eq(breaches[0]["budget"], 2.78, "against 2.78 ms")


func test_the_scenes_cover_normal_play_and_the_heaviest() -> void:
	var names := Bench.SCENES.map(func(s): return s["name"])
	for want in ["topdown", "diagonal", "street", "fpv", "street-night-rain-300"]:
		assert_true(want in names, "a scene " + want)
	assert_eq(Bench.SCENES.filter(func(s): return s["heavy"]).size(), 1, "one heavy scene")


func test_the_menu_and_the_title_are_normal_play_scenes_at_a_crowd_of_60() -> void:
	# Spec section 1, criterion 4: with a menu open, and on the title, every
	# style stays within the normal-play gate.
	var by_name := {}
	for s in Bench.SCENES:
		by_name[s["name"]] = s
	for want in ["menu", "title"]:
		assert_true(by_name.has(want), "a scene " + want)
		if not by_name.has(want):
			continue
		var s: Dictionary = by_name[want]
		assert_eq(s["crowd"], 60, want + " at a crowd of 60")
		assert_eq(s["heavy"], false, want + " under the normal-play gate")
		assert_eq(s["screen"], want, want + " opens its screen")
	assert_eq(by_name.get("menu", {}).get("view"), "diagonal", "the menu over the diagonal view")
	assert_eq(by_name.get("title", {}).get("tick"), 150, "the title by day, like the other normal scenes")


func test_the_menu_and_title_scenes_are_gated_like_normal_play() -> void:
	var budgets := {"voxel": {"normal_fps": 360, "heavy_fps": 240, "missed_pct": 1.0}}
	var baseline := {"fps": 357.0, "missed_pct": 1.9}
	var results := [
		{"style": "voxel", "scene": "menu", "heavy": false, "fps": 340.0, "missed_pct": 0.5, "hz": 360.0, "p99": 3.0},
		{"style": "voxel", "scene": "title", "heavy": false, "fps": 356.0, "missed_pct": 3.2, "hz": 360.0, "p99": 3.0},
	]
	var breaches := Bench.breaches(results, budgets, baseline)
	var scenes := breaches.map(func(b): return b["scene"])
	scenes.sort()
	assert_eq(scenes, ["menu", "title"], "the menu under 97 percent of the empty scene, the title missing 1.3 points more: %s" % str(breaches))


func test_a_style_with_frame_rate_targets_is_gated_on_what_a_player_sees() -> void:
	# Measured with vsync at the display's rate: frames per second and the
	# share of refreshes missed. A target above the display's rate means the
	# display's rate.
	var budgets := {"anime_cel": {"normal_fps": 360, "heavy_fps": 240, "missed_pct": 1.0}}
	var results := [
		{"style": "anime_cel", "scene": "street", "heavy": false, "fps": 359.0, "missed_pct": 0.4, "hz": 360.0, "p99": 3.4},
		{"style": "anime_cel", "scene": "topdown", "heavy": false, "fps": 330.0, "missed_pct": 0.5, "hz": 360.0, "p99": 3.0},
		{"style": "anime_cel", "scene": "fpv", "heavy": false, "fps": 359.0, "missed_pct": 2.5, "hz": 360.0, "p99": 2.9},
		{"style": "anime_cel", "scene": "street-night-rain-300", "heavy": true, "fps": 250.0, "missed_pct": 20.0, "hz": 360.0, "p99": 5.0},
		{"style": "anime_cel", "scene": "diagonal", "heavy": false, "fps": 143.0, "missed_pct": 0.1, "hz": 144.0, "p99": 3.5},
	]
	var breaches := Bench.breaches(results, budgets)
	var scenes := breaches.map(func(b): return b["scene"])
	scenes.sort()
	assert_eq(scenes, ["fpv", "topdown"], "topdown under 360 fps, fpv missing too many refreshes; the heavy scene over its 240 floor passes, and 143 fps on a 144 Hz display is the display's rate: %s" % str(breaches))


func test_the_frame_rate_a_display_allows() -> void:
	assert_eq(Bench.target_fps(360, 360.0), 356.4, "within 1% of the display's rate")
	assert_eq(Bench.target_fps(360, 144.0), 142.56, "a slower display caps it")
	assert_eq(Bench.target_fps(240, 360.0), 240.0, "a floor below the display's rate is itself")


func test_normal_play_is_measured_against_what_the_display_gives_an_empty_scene() -> void:
	# An empty scene here reaches 357 fps and misses 1.9% of refreshes: a
	# style matches that within 3% and one point more of refreshes missed.
	var budgets := {"neon_noir": {"normal_fps": 360, "heavy_fps": 240, "missed_pct": 1.0}}
	var baseline := {"fps": 357.0, "missed_pct": 1.9}
	var results := [
		{"style": "neon_noir", "scene": "street", "heavy": false, "fps": 356.8, "missed_pct": 1.96, "hz": 360.0, "p99": 2.9},
		{"style": "neon_noir", "scene": "diagonal", "heavy": false, "fps": 349.2, "missed_pct": 0.86, "hz": 360.0, "p99": 4.2},
		{"style": "neon_noir", "scene": "topdown", "heavy": false, "fps": 340.0, "missed_pct": 0.5, "hz": 360.0, "p99": 4.1},
		{"style": "neon_noir", "scene": "fpv", "heavy": false, "fps": 357.0, "missed_pct": 3.5, "hz": 360.0, "p99": 3.7},
	]
	var breaches := Bench.breaches(results, budgets, baseline)
	var scenes := breaches.map(func(b): return b["scene"])
	scenes.sort()
	assert_eq(scenes, ["fpv", "topdown"], "topdown under 97 percent of the empty scene's fps, fpv missing 1.6 points more: %s" % str(breaches))


func test_the_bench_renders_at_the_display_s_native_size_or_fails() -> void:
	# What players see: fullscreen at the display's own pixels. A desktop
	# that gives the window anything else fails the run rather than
	# measuring a smaller picture.
	assert_eq(Bench.size_breach(Vector2i(1920, 1080), Vector2i(1920, 1080)), "", "native: no breach")
	var breach := Bench.size_breach(Vector2i(1280, 662), Vector2i(1920, 1080))
	assert_true(breach.contains("1280x662") and breach.contains("1920x1080"), "a smaller window is a breach that names both sizes: " + breach)


func test_the_map_is_a_normal_play_scene_at_a_crowd_of_60() -> void:
	# Map spec section 1, success 3: with the map open, every style meets
	# the normal-play gate.
	var map := {}
	for s in Bench.SCENES:
		if s["name"] == "map":
			map = s
	assert_true(not map.is_empty(), "a scene map")
	assert_eq(map.get("crowd"), 60, "at a crowd of 60")
	assert_eq(map.get("heavy"), false, "under the normal-play gate")
	assert_eq(map.get("screen"), "map", "it opens the map")
	assert_eq(map.get("tick"), 150, "by day, like the other normal scenes")


func test_opening_the_map_again_takes_no_frame_over_50_ms_in_any_style() -> void:
	# Map spec section 1, success 3: after the first open in a style, no
	# frame over 50 ms. It holds in every style, with or without a budget;
	# the first open is reported, not gated.
	var results := [
		{"style": "voxel", "scene": "map", "open_worst_ms": 180.0, "reopen_worst_ms": 12.0},
		{"style": "pixel_art", "scene": "map", "open_worst_ms": 30.0, "reopen_worst_ms": 50.5},
		{"style": "anime_cel", "scene": "diagonal"},
	]
	var breaches := Bench.reopen_breaches(results)
	assert_eq(breaches.size(), 1, "one breach: %s" % str(breaches))
	assert_eq(breaches[0].get("style"), "pixel_art", "the re-open over 50 ms")
	assert_eq(breaches[0].get("budget"), 50.0, "against 50 ms")


func test_the_tram_scene_is_normal_play_with_two_full_trams_at_a_crowd_of_60() -> void:
	# Tram spec section 1, criterion 4: the normal-play gate holds with two
	# trams in the district carrying 40 riders each, at a crowd of 60.
	var tram := {}
	for s in Bench.SCENES:
		if s["name"] == "tram":
			tram = s
	assert_true(not tram.is_empty(), "a scene tram")
	assert_eq(tram.get("crowd"), 60, "at a crowd of 60")
	assert_eq(tram.get("heavy"), false, "under the normal-play gate")
	assert_eq(tram.get("view"), "diagonal", "over the diagonal view, to set beside it")
	assert_eq(tram.get("trams"), 2, "two trams")
	assert_eq(tram.get("riders"), 40, "each carrying 40")
	assert_true(int(tram.get("tick", 0)) > int(Bench.TRAM_LOAD["at"]), "after its riders have arrived")


func test_the_tram_load_is_one_public_arrival_a_rider_bound_for_each_room_in_turn() -> void:
	var entries := Bench.rider_entries(136, 4, ["room:avenue", "room:south-lane"])
	assert_eq(entries.size(), 4, "one entry a rider")
	var ids := {}
	for k in entries.size():
		var e: Dictionary = entries[k]
		var c: Dictionary = e["command"]
		assert_eq(e["at"], 136, "all at the load's tick")
		assert_eq(e["fixture"], true, "labelled a fixture")
		assert_eq(e["record"], "entry", "a feed entry")
		assert_eq(c["type"], "Arrive", "an arrival")
		assert_eq(c["room"], ["room:avenue", "room:south-lane"][k % 2], "bound for each room in turn")
		assert_eq(c["profile"]["kind"], {"type": "SimCitizen"}, "a public citizen, so it takes a place aboard")
		assert_eq(c["profile"]["id"], c["occupant"], "its profile is its own")
		ids[c["occupant"]] = true
	assert_eq(ids.size(), 4, "every rider its own occupant")


func test_the_tram_load_joins_the_feed_in_tick_order() -> void:
	var feed := "{\"record\": \"header\"}\n{\"at\": 1, \"n\": \"a\"}\n{\"at\": 200, \"n\": \"b\"}\n"
	var merged := Bench.with_entries(feed, [{"at": 136, "n": "x"}, {"at": 136, "n": "y"}])
	var lines := merged.strip_edges().split("\n")
	assert_eq(lines.size(), 5, "the header and four entries")
	assert_eq(JSON.parse_string(lines[0]).get("record"), "header", "the header first")
	var order := []
	for k in range(1, lines.size()):
		order.append(JSON.parse_string(lines[k])["n"])
	assert_eq(order, ["a", "x", "y", "b"], "by tick, the load in its own order")


func test_riders_aboard_counts_each_vehicle_s_riders() -> void:
	var p := {"aboard": [{"id": "a", "vehicle": "v:1"}, {"id": "b", "vehicle": "v:1"}, {"id": "c", "vehicle": "v:2"}]}
	assert_eq(Bench.riders_aboard(p), {"v:1": 2, "v:2": 1}, "two on one, one on the other")
	assert_eq(Bench.full_trams(p, 2), 1, "one carrying two")
	assert_eq(Bench.riders_aboard({}), {}, "none without riders")


func test_the_tram_load_fills_two_trams_in_the_district_at_the_scene_s_tick() -> void:
	# The riders ride in on the two trams in the district at the scene's
	# tick, each carrying 40, whichever way the district's own arrivals
	# have left the portals' turns.
	var scene := {}
	for s in Bench.SCENES:
		if s["name"] == "tram":
			scene = s
	var feed := Bench.tram_feed(CityPaths.district_manifest(), CityPaths.district_feed(), 7, int(scene.get("crowd", 60)))
	assert_true(feed != "", "a feed with the load")
	var w = ClassDB.instantiate("CityWorld")
	var r: Dictionary = JSON.parse_string(w.load(CityPaths.district_manifest(), feed, 7, int(scene.get("crowd", 60))))
	assert_eq(r.get("ok"), true, "the district loads with the load: %s" % str(r))
	while w.tick() < int(scene.get("tick", 0)):
		w.step()
	var p: Dictionary = JSON.parse_string(w.project_json("public"))
	assert_eq(Bench.full_trams(p, 40), 2, "two trams carrying 40 each: %s" % str(Bench.riders_aboard(p)))


## The diagonal view, moved to the middle of the boulevard at the same
## angle and distance, shows both full trams as the scene starts, and still
## shows both eight ticks on, just before the eastbound one lets its riders
## off at the Avenue.
func test_the_tram_scene_shows_both_full_trams_in_the_diagonal_view() -> void:
	var scene := {}
	for s in Bench.SCENES:
		if s["name"] == "tram":
			scene = s
	# Seen as the bench sees it, at 16:9 (a headless window is 64 x 64).
	var size_was: Vector2i = runner.root.size
	runner.root.size = Vector2i(1920, 1080)
	var main = load("res://main.gd").new()
	main.feed_jsonl = Bench.tram_feed(CityPaths.district_manifest(), CityPaths.district_feed(), 7, 60)
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=60", "--style=anime_cel"]))
	main.driver.pause()
	while main.driver.world.tick() < int(scene.get("tick", 0)):
		main.driver.step_once()
	main.host.set_camera(scene.get("view", "diagonal"))
	Bench.aim(main.host.pack, scene)
	for f in 3:
		main._process(1.0 / 60.0)
	for later in [0, 8]:
		for t in later:
			main.driver.step_once()
		var p: Dictionary = JSON.parse_string(main.driver.world.project_json(main.driver.viewer))
		var counts := Bench.riders_aboard(p)
		assert_eq(Bench.full_trams(p, 40), 2, "tick %d: the player sees two full trams: %s" % [main.driver.world.tick(), str(counts)])
		var rect: Rect2 = main.get_viewport().get_visible_rect()
		for v in p.get("vehicles", []):
			if int(counts.get(v["id"], 0)) < 40:
				continue
			var s = main.host.pack.screen_at(Vector2(float(v["pos"]["x"]), float(v["pos"]["z"])))
			assert_true(s != null and rect.has_point(s), "tick %d: %s in view: %s in %s" % [main.driver.world.tick(), v["id"], str(s), str(rect)])
	main.free()
	runner.root.size = size_was
