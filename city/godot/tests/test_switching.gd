## Switching styles, or re-activating one in place (a viewer switch), leaves
## the viewport, the renderer and the shared kit materials as the style
## now shown wants them: nothing of the style before leaks in, and the
## style before does not undo the new one's settings as it goes.
extends TestSuite


func manifest() -> Dictionary:
	return JSON.parse_string(CityPaths.district_manifest())


func model_at(minutes: int) -> SceneModel:
	var m := SceneModel.new()
	m.apply({"rooms": [], "in_transit": [], "time_of_day": minutes})
	return m


func _expect_settings(h: StyleHost, label: String) -> void:
	var pack = h.pack
	var want_msaa: int = pack.msaa_level() if pack.has_method("msaa_level") and (pack is LitPack or pack.get_script().resource_path.contains("anime")) else int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0))
	assert_eq(runner.root.msaa_3d, want_msaa, label + ": MSAA")
	var want_ssaa := Viewport.SCREEN_SPACE_AA_FXAA if pack is LitPack else int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa", 0))
	assert_eq(runner.root.screen_space_aa, want_ssaa, label + ": screen-space AA")
	var want_shadows: Dictionary = pack.shadow_settings() if pack.has_method("shadow_settings") else {}
	if not want_shadows.is_empty():
		assert_eq(Pack3D.renderer_shadows, want_shadows, label + ": the renderer's shadow atlas and filter")


func test_every_switch_leaves_the_new_styles_settings() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	var order := ["lowpoly_tropical", "anime_cel", "solarpunk", "neon_noir", "neon_noir", "anime_cel", "anime_cel", "lowpoly_tropical", "voxel"]
	for dir in order:
		assert_true(h.activate("res://styles/" + dir, manifest(), model_at(720), Motion.new(), 0.0), dir + " builds")
		_expect_settings(h, "after switching to " + dir)
	h.free()


func test_re_activating_a_lit_style_keeps_its_glass_and_neon() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	h.activate("res://styles/neon_noir", manifest(), model_at(1320), Motion.new(), 0.0)
	var neon_night := {}
	for m in h.pack.town.neon_materials:
		neon_night[m.resource_path] = m.emission
	for k in 3:
		h.activate("res://styles/neon_noir", manifest(), model_at(720), Motion.new(), 0.0)
	h.pack.set_time_of_day(1320)
	for m in h.pack.town.neon_materials:
		if neon_night.has(m.resource_path):
			assert_eq(m.emission, neon_night[m.resource_path], "neon keeps its own colour at night: " + m.resource_path.get_file())
	h.activate("res://styles/solarpunk", manifest(), model_at(1320), Motion.new(), 0.0)
	var glass_night := {}
	for m in h.pack._room_glass:
		glass_night[m.resource_path] = m.albedo_color
	h.activate("res://styles/solarpunk", manifest(), model_at(720), Motion.new(), 0.0)
	h.activate("res://styles/solarpunk", manifest(), model_at(720), Motion.new(), 0.0)
	var glass: Array = h.pack._room_glass.keys()
	assert_true(not glass.is_empty(), "the workshop and library have room glass")
	for m in glass:
		assert_eq(m.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "room glass still see-through by day: " + m.resource_path.get_file())
	h.pack.set_time_of_day(1320)
	for m in glass:
		assert_true(glass_night.has(m.resource_path), "the same room glass")
		assert_eq(m.albedo_color, glass_night.get(m.resource_path), "lit panes at night in their own colour, not the day tint")
	h.free()


func test_switching_at_night_in_steady_rain_shows_night_reflections() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	var m := model_at(1320)
	m.rain = 80
	h.activate("res://styles/lowpoly_tropical", manifest(), m, Motion.new(), 0.0)
	for f in 120:
		h.tick_frame(0.5, Motion.new(), 1.0, 1.0 / 30.0)
	assert_true(h.rain > 0.7, "the rain has set in (%.2f)" % h.rain)
	h.activate("res://styles/anime_cel", manifest(), m, Motion.new(), 0.0)
	assert_true(not h.pack._streaks.is_empty(), "lamps streak on the wet ground")
	var s: MeshInstance3D = h.pack._streaks[0]
	assert_true(s.transparency < 0.5, "at their night strength, not the day's: transparency %.2f" % s.transparency)
	h.free()


func test_the_anime_far_crowd_draws_only_the_far_body() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	var m := SceneModel.new()
	m.apply({"rooms": [{"id": "room:plaza", "occupants": [{"id": "person:f", "kind": {"type": "Human", "tier": "Registered"}, "display_name": "f", "role": "",
		"badge": null, "appearance": {"palette": "3", "hair": "1"}, "seat": null, "presence": {"headline": "Present"}, "pos": {"x": 0, "z": 0}}], "waiting": []}], "in_transit": [], "time_of_day": 720})
	h.activate("res://styles/anime_cel", manifest(), m, Motion.new(), 0.0)
	var model: Node = h.pack.nodes["person:f"].get_node("Model")
	for part in ["shoes", "details"]:
		var n = model.find_child(part, true, false)
		assert_eq(n.visibility_range_end, Pack3D.FAR_M, part + " gives way to the far body")
	h.free()
