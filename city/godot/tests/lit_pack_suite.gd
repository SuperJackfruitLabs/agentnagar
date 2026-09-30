## What every lit style (09 Solarpunk, 10 Neon noir) must do, run against
## each pack by its own test file: lit, not toon; robot agents whose eyes
## glow; City Agent A1 by id; semi-real faces; glass alight at night; rain
## that wets the ground and opens umbrellas outdoors only; and a viewport
## and environment left as found when the style is switched away.
extends TestSuite

var dir := ""


func manifest() -> Dictionary:
	return JSON.parse_string(CityPaths.district_manifest())


func person(id: String, kind: Dictionary, x: int, z: int, palette := "3") -> Dictionary:
	return {"id": id, "kind": kind, "display_name": id, "role": "", "badge": null,
		"appearance": {"palette": palette, "hair": "2"}, "seat": null, "presence": {"headline": "Present"},
		"pos": {"x": x, "z": z}}


func model_with(views: Array, minutes := 720) -> SceneModel:
	var m := SceneModel.new()
	m.apply({"rooms": [{"id": "room:plaza", "occupants": views, "waiting": []}], "in_transit": [], "time_of_day": minutes})
	return m


func host(views := [], minutes := 720) -> StyleHost:
	var h := StyleHost.new()
	runner.root.add_child(h)
	assert_true(h.activate(dir, manifest(), model_with(views, minutes), Motion.new(), 0.0), "the style builds: " + h.last_error)
	return h


func test_nothing_is_toon() -> void:
	var h := host()
	var toon := 0
	var seen := 0
	for n in [h.pack.world] + h.pack.world.find_children("*", "", true, false):
		for m in Toon.materials_of(n):
			if m is BaseMaterial3D:
				seen += 1
				if m.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON:
					toon += 1
	assert_true(seen > 50, "the city has materials (%d)" % seen)
	assert_eq(toon, 0, "lit, not toon")
	assert_true(h.pack.rig.camera.get_node_or_null("InkLines") == null, "no ink pass")
	h.free()


func test_agents_are_robots_whose_eyes_glow() -> void:
	var h := host([person("agent:g", {"type": "GuildAgent"}, 0, 0)])
	var model: Node = h.pack.nodes["agent:g"].get_node("Model")
	var eyes: GeometryInstance3D = model.find_child("eyes", true, false)
	assert_true(eyes != null, "a robot with an eyes plate")
	assert_true(eyes.material_override is ShaderMaterial and eyes.material_override.shader == LitFace.EYES_SHADER, "drawn as light")
	assert_true(model.find_child("visor", true, false) != null, "behind a visor")
	assert_true(model.find_child("face", true, false) == null, "no human face")
	h.free()


func test_eyes_glow_brighter_at_night() -> void:
	var h := host([person("agent:g", {"type": "GuildAgent"}, 0, 0)], 720)
	var eyes: GeometryInstance3D = h.pack.nodes["agent:g"].get_node("Model").find_child("eyes", true, false)
	var noon: float = eyes.get_instance_shader_parameter("glow")
	h.pack.set_time_of_day(1320)
	var night: float = eyes.get_instance_shader_parameter("glow")
	assert_true(noon > 0.5, "readable by day: %s" % noon)
	assert_true(night > noon and night < 4.0, "brighter at night, not blown out: %s" % night)
	h.free()


func test_a1_is_the_style_agent_by_id() -> void:
	var h := host([person("city:librarian", {"type": "CityRoleAgent"}, 0, 0), person("agent:c", {"type": "CityRoleAgent"}, 200, 0)])
	var a1: Node = h.pack.nodes["city:librarian"].get_node("Model")
	var other: Node = h.pack.nodes["agent:c"].get_node("Model")
	assert_true(a1.find_child("eyes", true, false) != null, "A1 is a robot")
	var a1_look: Dictionary = h.pack.style.get("a1_look", {})
	assert_true(not a1_look.is_empty(), "the style says how A1 looks")
	for part in a1_look:
		var n = a1.find_child(part, true, false)
		assert_true(n != null and n.material_override != null, "A1's %s is painted" % part)
		assert_eq(n.material_override.albedo_color.to_html(false), Color(str(a1_look[part])).to_html(false), "A1's %s" % part)
	assert_true(other.find_child("eyes", true, false) != null, "other agents are robots too")
	h.free()


func test_people_have_semi_real_faces_and_a_far_body() -> void:
	var h := host([person("person:a", {"type": "Human", "tier": "Registered"}, 0, 0)])
	var model: Node = h.pack.nodes["person:a"].get_node("Model")
	var face: GeometryInstance3D = model.find_child("face", true, false)
	assert_true(face.material_override is ShaderMaterial and face.material_override.shader == LitFace.FACE_SHADER, "the lit face")
	assert_eq(model.find_child("top", true, false).visibility_range_end, Pack3D.FAR_M, "near parts give way")
	assert_eq(model.find_child("far", true, false).visibility_range_begin, Pack3D.FAR_M, "to the far body")
	h.free()


func test_windows_glow_at_night() -> void:
	var h := host([], 1320)
	var glass: Array = h.pack.town.glass_materials.filter(func(g): return g.emission_energy_multiplier > 0.5)
	var panes: Array = h.pack.town.lamp_materials.filter(func(m): return str(m.resource_name) == "window_glow" and m.emission_energy_multiplier > 0.5)
	assert_true(not glass.is_empty() or not panes.is_empty(), "windows glow after dark")
	if not h.pack.style.get("glass_glow", true):
		assert_true(glass.is_empty(), "only the lit panes: plain glass stays dark")
	h.free()


func test_rain_wets_the_ground_and_opens_umbrellas_outdoors_only() -> void:
	var h := host([person("person:out", {"type": "Human", "tier": "Registered"}, 0, 800),
		person("person:in", {"type": "Human", "tier": "Registered"}, -2600, -800)], 1250)
	h.pack.set_rain(0.8)
	var out_umbrella: Node3D = h.pack.nodes["person:out"].get_node("Model").find_child("umbrella", true, false)
	var in_umbrella: Node3D = h.pack.nodes["person:in"].get_node("Model").find_child("umbrella", true, false)
	assert_true(out_umbrella.visible, "an umbrella in the square")
	assert_true(not in_umbrella.visible, "none in the workshop")
	assert_true(not h.pack._wet.is_empty(), "the paving wets")
	var m = h.pack._wet.keys()[0]
	assert_true(m.roughness < h.pack._wet[m][0], "glossier when wet")
	h.pack.set_rain(0.0)
	assert_true(not out_umbrella.visible, "furled when it stops")
	assert_true(absf(m.roughness - h.pack._wet[m][0]) < 0.001, "dry again")
	h.free()


func test_leaving_the_style_restores_the_viewport() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	h.activate(dir, manifest(), SceneModel.new(), Motion.new(), 0.0)
	assert_eq(runner.root.msaa_3d, h.pack.msaa_level(), "the style's MSAA while lit")
	h.activate("res://styles/anime_cel", manifest(), SceneModel.new(), Motion.new(), 0.0)
	h.activate("res://styles/lowpoly_tropical", manifest(), SceneModel.new(), Motion.new(), 0.0)
	assert_eq(runner.root.msaa_3d, int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0)), "the project's MSAA")
	assert_eq(runner.root.screen_space_aa, int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa", 0)), "the project's screen-space AA")
	h.free()


func test_every_piece_the_city_places_is_in_the_kit() -> void:
	var h := host()
	assert_eq(Array(h.pack.missing_scenes), [], "no placeholders in the city")
	h.free()


func test_the_sun_casts_no_shadow_when_it_is_only_a_dim_moon() -> void:
	var h := host([], 1320)
	assert_true(not h.pack.sun.shadow_enabled, "no moon shadows at night (invisible, and a whole shadow pass)")
	h.pack.set_time_of_day(720)
	h.pack.set_daylight(720.0)
	assert_true(h.pack.sun.shadow_enabled, "the sun casts shadows by day")
	h.free()
