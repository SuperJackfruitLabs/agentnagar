## 09 Solarpunk: the lit styles' contract (lit_pack_suite.gd), plus fairy
## lights in the great tree after dark.
extends "res://tests/lit_pack_suite.gd"


func _init() -> void:
	dir = "res://styles/solarpunk"


func test_fairy_lights_glow_in_the_great_tree_at_night() -> void:
	var h := host([], 1320)
	var fairy: Array = h.pack.town.lamp_materials.filter(func(m): return str(m.resource_name) == "fairy_glow")
	assert_true(not fairy.is_empty(), "the tree has fairy lights")
	assert_true(fairy[0].emission_energy_multiplier > 1.0, "lit after dark")
	h.pack.set_time_of_day(720)
	assert_eq(fairy[0].emission_energy_multiplier, 0.0, "dark by day")
	h.free()
