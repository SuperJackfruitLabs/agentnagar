## Rain in the world: the projection's rain reaches every style, eased so
## it never jumps, and every style shows it.
extends TestSuite


func manifest() -> Dictionary:
	return JSON.parse_string(CityPaths.district_manifest())


func projection(rain) -> Dictionary:
	var p := {"rooms": [], "in_transit": [], "time_of_day": 1200}
	if rain != null:
		p["rain"] = rain
	return p


func test_the_scene_model_reports_rain_changes() -> void:
	var m := SceneModel.new()
	var first := m.apply(projection(60))
	assert_true(first.any(func(c): return c["type"] == "rain" and c["percent"] == 60), "rain arrives: %s" % str(first))
	assert_true(not m.apply(projection(60)).any(func(c): return c["type"] == "rain"), "no change, no news")
	var gone := m.apply(projection(null))
	assert_true(gone.any(func(c): return c["type"] == "rain" and c["percent"] == 0), "no rain reported as none")


func test_rain_eases_and_never_jumps() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	var model := SceneModel.new()
	var motion := Motion.new()
	h.activate("res://tests/fixtures/fake_pack", manifest(), model, motion, 0.0)
	h.apply_changes(model.apply(projection(60)), motion)
	var last := h.rain
	for f in 240:
		h.tick_frame(0.5, motion, 1.0, 1.0 / 60.0)
		assert_true(absf(h.rain - last) <= 0.05, "frame %d moves the rain %.3f" % [f, h.rain - last])
		last = h.rain
	assert_true(absf(h.rain - 0.6) < 0.001, "it settles at 60%%: %.3f" % h.rain)
	assert_eq(h.pack.rain, h.rain, "and the pack is told")
	h.free()


func test_every_style_shows_rain() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	for dir in h.discover():
		assert_true(h.activate(dir, manifest(), SceneModel.new(), Motion.new(), 0.0), dir + " builds")
		var pack: StylePack = h.pack
		pack.set_rain(0.8)
		var rain = pack.find_child("Rain", true, false)
		assert_true(rain != null and rain.visible, dir + " shows rain")
		pack.set_rain(0.0)
		assert_true(rain == null or not rain.visible, dir + " stops showing it")
	h.free()
