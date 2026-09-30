## A person's look — outfit k and hair style h — reads the same in every
## style: pixel art draws a sheet per outfit and hair style, and every style
## gives a backpack to the same outfits.
extends TestSuite

const BACKPACKS := [1, 5, 6]


func manifest() -> Dictionary:
	return JSON.parse_string(CityPaths.district_manifest())


func person(k: int, h: int) -> Dictionary:
	return {"id": "person:look-%d-%d" % [k, h], "kind": {"type": "Human", "tier": "Registered"},
		"display_name": "L", "appearance": {"palette": str(k), "hair": str(h)}, "pos": {"x": 0, "z": 0}}


func test_pixel_art_draws_each_hair_style() -> void:
	var style: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://styles/pixel_art/style.json"))
	var sheets: Array = style["occupants"]["Human"]["outfits"]
	assert_eq(sheets.size(), 32, "a sheet per outfit and hair style")
	for s in sheets:
		assert_true(ResourceLoader.exists("res://styles/pixel_art/" + s), s)
	var h := StyleHost.new()
	runner.root.add_child(h)
	assert_true(h.activate("res://styles/pixel_art", manifest(), SceneModel.new(), Motion.new(), 0.0), "pixel builds")
	var pack = h.pack
	var seen := {}
	for hair in 4:
		var path: String = pack._sheet_path(person(3, hair))
		assert_eq(path, "assets/characters/human_3_%d.png" % hair, "outfit 3, hair %d" % hair)
		seen[path] = true
	assert_eq(seen.size(), 4, "four hair styles, four sheets")
	h.free()


func test_backpacks_go_with_the_outfit_in_3d() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	for dir in ["res://styles/lowpoly_tropical", "res://styles/voxel"]:
		assert_true(h.activate(dir, manifest(), SceneModel.new(), Motion.new(), 0.0), dir)
		for k in 8:
			var v := person(k, 0)
			h.pack.spawn(v, "standing")
			var pack = h.pack.nodes[v["id"]].get_node("Model").find_child("backpack", true, false)
			var hat = h.pack.nodes[v["id"]].get_node("Model").find_child("hat_sun", true, false)
			# A part a person never shows is let go (Pack3D._trim).
			assert_eq(pack != null and pack.visible, k in BACKPACKS, "%s outfit %d backpack" % [dir.get_file(), k])
			assert_true(hat == null or not hat.visible, "%s: registered people wear no sun hat (pixel cannot draw one)" % dir.get_file())
	h.free()
