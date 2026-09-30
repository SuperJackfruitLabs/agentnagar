extends TestSuite

var projections := []


func driver(operator := false) -> WorldDriver:
	var d := WorldDriver.new()
	runner.root.add_child(d)
	projections.clear()
	d.projected.connect(func(p): projections.append(p))
	var r := d.start(CityPaths.district_manifest(), CityPaths.district_feed(), 7, 0, operator)
	assert_eq(r.get("ok"), true, "driver starts")
	return d


func test_driver_steps_at_speed() -> void:
	var d := driver()
	assert_eq(projections.size(), 1, "projects once on start")
	d.set_speed(2)
	d.advance(0.5)
	assert_eq(d.world.tick(), 1, "half a second at 2x is one tick")
	d.advance(1.0)
	assert_eq(d.world.tick(), 3, "one more second is two more ticks")
	assert_eq(projections.size(), 4, "one projection per tick")
	d.pause()
	d.advance(5.0)
	assert_eq(d.world.tick(), 3, "paused")
	d.step_once()
	assert_eq(d.world.tick(), 4, "single step while paused")
	d.free()


func test_viewer_switch_reprojects_same_tick() -> void:
	var d := driver()
	d.advance(3.0)
	var tick: int = d.world.tick()
	assert_true(d.set_viewer("person:asha"), "switched")
	var p: Dictionary = projections[-1]
	assert_eq(int(p["tick"]), tick, "same tick")
	assert_eq(p["viewer"]["id"], "person:asha", "for Asha")
	d.free()


func test_operator_hidden_without_flag() -> void:
	var d := driver(false)
	assert_true(not d.set_viewer("operator"), "refused without --operator")
	assert_eq(d.viewers(), ["public", "person:asha"], "not offered")
	d.free()
	var o := driver(true)
	assert_true(o.set_viewer("operator"), "allowed with --operator")
	assert_true("operator" in o.viewers(), "offered")
	o.free()


func test_extension_missing_is_reported() -> void:
	var d := WorldDriver.new()
	d.class_exists = func(_n): return false
	var r := d.start("", "", 1, 0, false)
	assert_eq(r.get("error"), "extension-missing", "reported, not crashed")
	d.free()


func test_invalid_manifest_lists_issues() -> void:
	var d := WorldDriver.new()
	var r := d.start('{"schema_version": 9, "city": {"id": "c", "name": "C", "districts": []}}', CityPaths.district_feed(), 1, 0, false)
	assert_eq(r.get("ok"), false, "refused")
	assert_true(r.get("issues", []).size() > 0, "issues listed")
	d.free()


func test_in_play_a_tick_is_spread_over_frames() -> void:
	var d := driver()
	d.set_speed(1)
	var before := projections.size()
	# Short frames (a high frame rate), until the tick falls due.
	while d.world.tick() < 1:
		d.frame(0.004)
	assert_eq(d.world.tick(), 1, "the tick is stepped on the frame it falls due")
	assert_eq(projections.size(), before, "its projection waits for the next frame")
	assert_eq(d.shown_time(), 1.0, "walkers hold at the end of their steps meanwhile")
	d.frame(0.004)
	assert_eq(projections.size(), before + 1, "projected on the next frame")
	assert_true(d.shown_time() < 0.5, "and time runs on from the new tick: %s" % d.shown_time())
	d.free()


func test_several_ticks_due_at_once_are_all_projected() -> void:
	var d := driver()
	var before := projections.size()
	d.frame(3.2)
	d.frame(0.004)
	assert_eq(d.world.tick(), 3, "three ticks")
	assert_eq(projections.size(), before + 3, "each projected")
	d.free()


func test_when_frames_are_long_against_the_tick_it_lands_at_once() -> void:
	# At 8x on a 60 Hz display a frame is an eighth of a tick: holding the
	# walkers three frames for a staged landing would stutter them.
	var d := driver()
	d.set_speed(8)
	var before := projections.size()
	d.frame(1.0 / 60.0 * 7.6)
	assert_eq(d.world.tick(), 1, "stepped")
	assert_eq(projections.size(), before + 1, "and projected on the same frame")
	assert_true(not d.staged, "not staged")
	d.free()
