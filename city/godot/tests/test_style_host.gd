extends TestSuite

const FAKE := "res://tests/fixtures/fake_pack"
const BROKEN := "res://tests/fixtures/broken_pack"


func manifest() -> Dictionary:
	return JSON.parse_string(CityPaths.district_manifest())


func view(id: String, extra := {}) -> Dictionary:
	var v := {"id": id, "kind": {"type": "GuildAgent"}, "display_name": id, "role": "",
		"badge": "Ai", "appearance": {}, "seat": null, "presence": {"headline": "Working"},
		"pos": {"x": 100, "z": 100}}
	v.merge(extra, true)
	return v


func model_with(views: Array, minutes := 600) -> SceneModel:
	var m := SceneModel.new()
	m.apply({"rooms": [{"id": "room:w", "occupants": views, "waiting": []}], "in_transit": [], "time_of_day": minutes})
	return m


func host() -> StyleHost:
	var h := StyleHost.new()
	runner.root.add_child(h)
	return h


func test_discover_finds_packs_in_order() -> void:
	var h := host()
	assert_eq(h.discover("res://tests/fixtures"), [FAKE, BROKEN], "ordered by style.json order")
	h.free()


func test_switch_preserves_occupants_poses_and_states() -> void:
	var h := host()
	var model := model_with([view("a", {"seat": "s"}), view("b", {"presence": {"headline": "Idle"}})])
	var motion := Motion.new()
	assert_true(h.activate(FAKE, manifest(), model, motion, 0.0), "first pack")
	assert_true(h.activate(FAKE, manifest(), model, motion, 0.0), "switched")
	var pack = h.pack
	assert_eq(pack.nodes.keys().size(), 2, "both present")
	assert_eq(pack.poses, {"a": "sitting", "b": "standing"}, "poses re-applied")
	assert_eq(pack.presence, {"a": "Working", "b": "Idle"}, "presence re-applied")
	assert_eq(pack.minutes, 600, "time re-applied")
	h.free()


func test_switch_mid_walk_keeps_interpolated_position() -> void:
	var h := host()
	var walker := view("w", {"moving": true, "pos": {"x": 0, "z": 0}, "path_ahead": [{"x": 100, "z": 0}]})
	var model := model_with([walker])
	var motion := Motion.new()
	motion.set_track("w", walker["pos"], walker["path_ahead"])
	h.activate(FAKE, manifest(), model, motion, 0.5)
	assert_eq(h.pack.places["w"], Vector2(50, 0), "placed mid-walk, not at a seat")
	h.free()


func test_failed_build_keeps_previous_pack() -> void:
	var h := host()
	var model := model_with([view("a")])
	h.activate(FAKE, manifest(), model, Motion.new(), 0.0)
	var before = h.pack
	assert_true(not h.activate(BROKEN, manifest(), model, Motion.new(), 0.0), "refused")
	assert_true(h.pack == before and before.built, "previous pack still active")
	assert_true(h.last_error != "", "the error is reported")
	h.free()


func test_missing_key_renders_placeholder_and_is_logged() -> void:
	var h := host()
	var human := view("h", {"kind": {"type": "Human", "tier": "Registered"}})
	h.activate(FAKE, manifest(), model_with([human]), Motion.new(), 0.0)
	assert_true("occupants/Human" in h.pack.missing, "missing key logged")
	assert_eq(h.pack.resolve("occupants", "Human"), {"placeholder": true}, "placeholder entry")
	h.free()


func test_public_viewer_creates_no_node_for_hidden_ids() -> void:
	var w = ClassDB.instantiate("CityWorld")
	w.load(CityPaths.district_manifest(), CityPaths.district_feed(), 7, 0)
	# The story's hidden arrivals ride in: Asha's agent steps off east:1 at
	# the Square at 35, the observer guest off west:2 at 68.
	for i in 70:
		w.step()
	var h := host()
	var public := SceneModel.new()
	public.apply(JSON.parse_string(w.project_json("public")))
	h.activate(FAKE, manifest(), public, Motion.new(), 0.0)
	assert_true(not h.pack.nodes.has("pa:asha-notes"), "no node for a private agent")
	assert_true(not h.pack.nodes.has("person:guest"), "no node for an observer")
	var asha := SceneModel.new()
	asha.apply(JSON.parse_string(w.project_json("person:asha")))
	h.activate(FAKE, manifest(), asha, Motion.new(), 0.0)
	assert_true(h.pack.nodes.has("pa:asha-notes"), "Asha sees her agent")
	h.free()


func test_apply_changes_spawns_moves_and_despawns() -> void:
	var h := host()
	var model := SceneModel.new()
	var motion := Motion.new()
	h.activate(FAKE, manifest(), model, motion, 0.0)
	var p1 := {"rooms": [{"id": "room:w", "occupants": [view("a")], "waiting": []}], "in_transit": []}
	h.apply_changes(model.apply(p1), motion)
	assert_true(h.pack.nodes.has("a"), "spawned")
	h.apply_changes(model.apply({"rooms": [], "in_transit": []}), motion)
	assert_true(not h.pack.nodes.has("a"), "despawned")
	h.free()


func test_walkers_replay_what_happened_not_what_was_planned() -> void:
	var h := host()
	var model := SceneModel.new()
	var motion := Motion.new()
	h.activate(FAKE, manifest(), model, motion, 0.0)
	var at := func(x: int, trail: Array, plan: Array) -> Dictionary:
		return {"rooms": [], "in_transit": [view("w", {"moving": true, "pos": {"x": x, "z": 0},
			"trail": trail, "path_ahead": plan})]}
	h.apply_changes(model.apply(at.call(0, [], [{"x": 25, "z": 0}, {"x": 50, "z": 0}])), motion)
	h.tick_frame(0.5, motion)
	assert_eq(h.pack.places["w"], Vector2(0, 0), "a plan alone does not move anyone")
	h.apply_changes(model.apply(at.call(50, [{"x": 25, "z": 0}, {"x": 50, "z": 0}], [{"x": 75, "z": 0}])), motion)
	h.tick_frame(0.0, motion)
	assert_eq(h.pack.places["w"], Vector2(0, 0), "replay starts where it was")
	h.tick_frame(1.0, motion)
	assert_eq(h.pack.places["w"], Vector2(50, 0), "and ends where it is")
	h.apply_changes(model.apply(at.call(50, [], [{"x": 75, "z": 0}])), motion)
	h.tick_frame(0.5, motion)
	assert_eq(h.pack.places["w"], Vector2(50, 0), "a held-up walker stays put")
	h.free()


## Walkers walk while they are shown moving and not a moment longer: the
## core's pose changes at the tick, but its last steps replay over the next.
func test_the_walk_lasts_exactly_as_long_as_the_shown_movement() -> void:
	var h := host()
	var model := SceneModel.new()
	var motion := Motion.new()
	h.activate(FAKE, manifest(), model, motion, 0.0)
	var at := func(x: int, trail: Array, extra: Dictionary) -> Dictionary:
		var v := view("w", {"moving": false, "pos": {"x": x, "z": 0}, "trail": trail})
		v.merge(extra, true)
		return {"rooms": [], "in_transit": [v]}
	h.apply_changes(model.apply(at.call(0, [], {})), motion)
	h.apply_changes(model.apply(at.call(50, [{"x": 25, "z": 0}, {"x": 50, "z": 0}], {"moving": true})), motion)
	h.tick_frame(0.5, motion, 2.0)
	assert_eq(h.pack.poses["w"], "walking", "walking while the steps replay")
	assert_eq(h.pack.strides["w"], 100.0, "at the pace shown: 50 cm a tick, two ticks a second")
	# It sits on arrival, but the last step is still being shown.
	h.apply_changes(model.apply(at.call(75, [{"x": 75, "z": 0}], {"seat": "s"})), motion)
	h.tick_frame(0.0, motion, 2.0)
	assert_eq(h.pack.poses["w"], "walking", "the last step is walked, not glided")
	h.tick_frame(0.9, motion, 2.0)
	assert_eq(h.pack.poses["w"], "walking", "to its end")
	h.apply_changes(model.apply(at.call(75, [], {"seat": "s"})), motion)
	h.tick_frame(0.0, motion, 2.0)
	assert_eq(h.pack.poses["w"], "sitting", "then it sits")
	# Held up mid-walk, the core still says moving, but nobody is shown moving.
	h.apply_changes(model.apply(at.call(75, [], {"moving": true})), motion)
	h.tick_frame(0.5, motion, 2.0)
	assert_eq(h.pack.poses["w"], "standing", "a held-up walker stands, not walks on the spot")
	h.free()


## Standing people are placed once, not every frame: a crowd at rest costs
## nothing between ticks.
func test_still_walkers_are_not_placed_every_frame() -> void:
	var h := host()
	var model := SceneModel.new()
	var motion := Motion.new()
	h.activate(FAKE, manifest(), model, motion, 0.0)
	var p := {"rooms": [{"id": "room:w", "occupants": [view("a"), view("b", {"pos": {"x": 300, "z": 100}})], "waiting": []}], "in_transit": []}
	h.apply_changes(model.apply(p), motion)
	h.pack.places.clear()
	var counts := {"n": 0}
	h.pack.set_meta("count", true)
	for f in 30:
		h.pack.places.clear()
		h.tick_frame(f / 30.0, motion, 1.0, 1.0 / 60.0)
		counts["n"] += h.pack.places.size()
	assert_true(counts["n"] <= 2, "two standing people placed at most once each over 30 frames: %d" % counts["n"])
	# Someone who starts walking is placed every frame again.
	var walk := {"rooms": [{"id": "room:w", "occupants": [view("a"), view("b", {"moving": true, "pos": {"x": 350, "z": 100}, "trail": [{"x": 325, "z": 100}, {"x": 350, "z": 100}]})], "waiting": []}], "in_transit": []}
	h.apply_changes(model.apply(walk), motion)
	var seen := 0
	for f in 10:
		h.pack.places.clear()
		h.tick_frame(f / 10.0, motion, 1.0, 1.0 / 60.0)
		if h.pack.places.has("b"):
			seen += 1
	assert_eq(seen, 10, "a walker is placed every frame")
	h.free()


func test_walkers_out_of_view_are_placed_every_fourth_frame() -> void:
	var h := host()
	var model := SceneModel.new()
	var motion := Motion.new()
	h.activate(FAKE, manifest(), model, motion, 0.0)
	h.apply_changes(model.apply({"rooms": [{"id": "room:w", "occupants": [view("b", {"pos": {"x": 300, "z": 100}})], "waiting": []}], "in_transit": []}), motion)
	var walk := {"rooms": [{"id": "room:w", "occupants": [view("b", {"moving": true, "pos": {"x": 350, "z": 100}, "trail": [{"x": 325, "z": 100}, {"x": 350, "z": 100}]})], "waiting": []}], "in_transit": []}
	h.apply_changes(model.apply(walk), motion)
	h.pack.unseen["b"] = true
	var placed := 0
	for f in 16:
		h.pack.places.clear()
		h.tick_frame(f / 16.0, motion, 1.0, 1.0 / 400.0)
		if h.pack.places.has("b"):
			placed += 1
	assert_eq(placed, 4, "out of view: placed every fourth frame")
	h.pack.unseen.erase("b")
	placed = 0
	for f in 8:
		h.pack.places.clear()
		h.tick_frame(f / 8.0, motion, 1.0, 1.0 / 400.0)
		if h.pack.places.has("b"):
			placed += 1
	assert_eq(placed, 8, "in view: every frame")
	h.free()


func test_walkers_small_on_screen_are_moved_less_often() -> void:
	var h := host()
	var model := SceneModel.new()
	var motion := Motion.new()
	h.activate(FAKE, manifest(), model, motion, 0.0)
	h.apply_changes(model.apply({"rooms": [{"id": "room:w", "occupants": [view("b", {"pos": {"x": 300, "z": 100}})], "waiting": []}], "in_transit": []}), motion)
	var walk := {"rooms": [{"id": "room:w", "occupants": [view("b", {"moving": true, "pos": {"x": 350, "z": 100}, "trail": [{"x": 325, "z": 100}, {"x": 350, "z": 100}]})], "waiting": []}], "in_transit": []}
	h.apply_changes(model.apply(walk), motion)
	h.pack.steps["b"] = 2
	var placed := 0
	for f in 16:
		h.pack.places.clear()
		h.tick_frame(f / 16.0, motion, 1.0, 1.0 / 400.0)
		if h.pack.places.has("b"):
			placed += 1
	assert_eq(placed, 8, "small on screen: moved every second frame")
	h.free()


## The map's picture is kept (map spec section 4): the same request again
## is answered with the same texture, without the pack drawing it again,
## until the size or the style changes. Opening the map again is then
## cheap (success 3: no frame over 50 ms after the first open).
func test_the_map_picture_is_kept_until_the_size_or_the_style_changes() -> void:
	var h := host()
	var m := manifest()
	assert_true(h.activate(FAKE, m, SceneModel.new(), Motion.new(), 0.0), "shown")
	var extent := CityGeometry.extent(m)
	var got := []
	h.map_ready.connect(func(t, _d): got.append(t))
	h.request_map(extent, Vector2i(320, 200))
	await runner.process_frame
	assert_eq(got.size(), 1, "answered")
	h.request_map(extent, Vector2i(320, 200))
	await runner.process_frame
	assert_eq(got.size(), 2, "answered again")
	assert_true(got.size() == 2 and is_same(got[1], got[0]), "with the picture kept")
	h.request_map(extent, Vector2i(640, 400))
	await runner.process_frame
	assert_true(got.size() == 3 and not is_same(got[2], got[1]), "a new size is drawn anew")
	assert_eq(Vector2i(got[-1].get_size()), Vector2i(640, 400), "at that size")
	h.activate(FAKE, m, SceneModel.new(), Motion.new(), 0.0)
	h.request_map(extent, Vector2i(640, 400))
	await runner.process_frame
	assert_true(got.size() == 4 and not is_same(got[3], got[2]), "the style shown again draws it anew")
	h.free()


## A stand-in (a 3D pack given no picture to copy answers with the plain
## letterbox) is not kept: the next request asks the pack again.
func test_a_stand_in_map_picture_is_not_kept() -> void:
	var h := host()
	var m := manifest()
	assert_true(h.activate(FAKE, m, SceneModel.new(), Motion.new(), 0.0), "shown")
	h.pack.map_stand_in = true
	var extent := CityGeometry.extent(m)
	var got := []
	h.map_ready.connect(func(t, _d): got.append(t))
	h.request_map(extent, Vector2i(320, 200))
	await runner.process_frame
	assert_eq(got.size(), 1, "answered")
	h.request_map(extent, Vector2i(320, 200))
	await runner.process_frame
	assert_eq(h.pack.map_asks, 2, "asked of the pack again")
	assert_eq(got.size(), 2, "and answered")
	h.free()


## A kept picture at least as large as asked answers a smaller request
## (map spec section 4: kept "until the window grows past the resolution
## it was drawn at"); a larger one is drawn anew.
func test_a_kept_picture_at_least_as_large_answers_a_smaller_ask() -> void:
	var h := host()
	var m := manifest()
	assert_true(h.activate(FAKE, m, SceneModel.new(), Motion.new(), 0.0), "shown")
	var extent := CityGeometry.extent(m)
	var got := []
	h.map_ready.connect(func(t, _d): got.append(t))
	h.request_map(extent, Vector2i(640, 400))
	await runner.process_frame
	h.request_map(extent, Vector2i(320, 200))
	await runner.process_frame
	assert_eq(h.pack.map_asks, 1, "not drawn again")
	assert_true(got.size() == 2 and is_same(got[1], got[0]), "answered with the larger picture kept")
	h.request_map(extent, Vector2i(640, 401))
	await runner.process_frame
	assert_eq(h.pack.map_asks, 2, "a larger ask is drawn anew")
	h.free()
