## 10 Neon noir: the lit styles' contract (lit_pack_suite.gd), plus neon
## that lights at dusk and goes dark by day, lamp lights that fade with
## distance and cast no shadow, and reflections on wet ground.
extends "res://tests/lit_pack_suite.gd"


func _init() -> void:
	dir = "res://styles/neon_noir"


func test_neon_is_lit_at_night_and_dark_by_day() -> void:
	var h := host([], 1320)
	var neon: Array = h.pack.town.neon_materials
	assert_true(neon.size() > 0, "the city has neon")
	assert_true(neon.all(func(m): return m.emission_energy_multiplier > 1.0), "all lit at night")
	h.pack.set_time_of_day(720)
	assert_true(neon.all(func(m): return m.emission_energy_multiplier == 0.0), "dark glass by day")
	h.free()


func test_lamps_are_cheap_warm_lights() -> void:
	var h := host([], 1320)
	assert_true(h.pack.lamps.size() > 10, "many lamps (%d)" % h.pack.lamps.size())
	for lamp in h.pack.lamps:
		assert_true(not lamp.shadow_enabled, "no lamp casts shadows")
		assert_true(lamp.distance_fade_enabled, "far lamps fade out")
	h.free()


func test_wet_ground_reflects_in_rain() -> void:
	var h := host([], 1320)
	assert_true(not h.pack.env.ssr_enabled, "no reflections while dry")
	h.pack.set_rain(0.8)
	assert_true(h.pack.env.ssr_enabled, "screen-space reflections on the wet ground")
	h.pack.set_rain(0.0)
	assert_true(not h.pack.env.ssr_enabled, "off again")
	h.free()


func test_a_jacket_shows_on_the_far_body_too() -> void:
	var h := host([person("person:j", {"type": "Human", "tier": "Registered"}, 0, 0, "0")])
	var model: Node = h.pack.nodes["person:j"].get_node("Model")
	var jacket: GeometryInstance3D = model.find_child("jacket", true, false)
	assert_true(jacket.visible, "outfit 0 wears the jacket")
	var far: MeshInstance3D = model.find_child("far", true, false)
	var top_surface := -1
	for s in far.mesh.get_surface_count():
		if str(far.mesh.surface_get_material(s).resource_name) == "top":
			top_surface = s
	assert_true(top_surface >= 0, "the far body has a top")
	assert_eq(far.get_surface_override_material(top_surface), jacket.material_override, "from afar, the jacket's colour")
	h.free()


func test_a_hood_never_fights_a_ponytail_or_a_backpack() -> void:
	var views := []
	for k in 8:
		views.append(person("person:%d" % k, {"type": "Human", "tier": "Registered"}, k * 150, 0, str(k)))
	var h := host(views)
	var hooded := 0
	for k in 8:
		var model: Node = h.pack.nodes["person:%d" % k].get_node("Model")
		var hood = model.find_child("hood", true, false)
		if hood == null or not hood.visible:
			continue
		hooded += 1
		var tail = model.find_child("hair_2", true, false)
		var pack_ = model.find_child("backpack", true, false)
		assert_true(tail == null or not tail.visible, "no ponytail through the hood (outfit %d)" % k)
		assert_true(pack_ == null or not pack_.visible, "no backpack over the hood (outfit %d)" % k)
	h.free()


func test_the_great_tree_glows_from_below_at_night() -> void:
	var h := host([], 1320)
	var glows: Array = h.pack.lamps.filter(func(l): return l.has_meta("lights_of"))
	assert_eq(glows.size(), 1, "one warm light, under the great tree's lights (not every bench's strip)")
	assert_true(glows[0].light_energy > 1.0, "lit after dark")
	h.pack.set_time_of_day(720)
	assert_eq(glows[0].light_energy, 0.0, "off by day")
	h.free()


func test_low_lights_wash_less_than_lamp_posts() -> void:
	var h := host([], 1320)
	var low: Array = h.pack.lamps.filter(func(l): return l.position.y < 1.5 and not l.has_meta("lights_of"))
	var high: Array = h.pack.lamps.filter(func(l): return l.position.y >= 3.0)
	assert_true(not low.is_empty() and not high.is_empty(), "both kinds of light")
	assert_true(low[0].light_energy < high[0].light_energy * 0.5, "a ground light is dimmer: %s vs %s" % [low[0].light_energy, high[0].light_energy])
	assert_true(low.all(func(l): return l.omni_range <= 4.0), "and washes only the paving round it (a light's cost is its reach)")
	h.free()
