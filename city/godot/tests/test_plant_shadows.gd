## Planting casts shadows only near the view: a style's "plant_shadow_m"
## keeps the shadow pass to the trees whose shadows can be seen, and its
## "msaa" sets the antialiasing it draws with.
extends TestSuite


func manifest() -> Dictionary:
	return JSON.parse_string(CityPaths.district_manifest())


func test_only_planting_near_the_view_casts_shadows() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	assert_true(h.activate("res://styles/anime_cel", manifest(), SceneModel.new(), Motion.new(), 0.0), h.last_error)
	var reach := float(h.pack.style.get("plant_shadow_m", 0.0))
	assert_true(reach > 0.0, "the style limits plant shadows")
	h.pack.update_plant_shadows(Vector3.ZERO)
	var near := 0
	var far := 0
	for n in h.pack.world.find_children("Planting*", "MultiMeshInstance3D", true, false):
		if n.has_meta("far_of"):
			continue
		var c: Vector3 = n.get_meta("centre")
		var d := Vector2(c.x, c.z).length()
		if d < reach * 0.5:
			near += 1
			assert_eq(n.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "a near chunk casts")
		elif d > reach + KitTown.CHUNK_M:
			far += 1
			assert_eq(n.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "a far chunk does not")
	assert_true(near > 0 and far > 0, "both kinds present (%d near, %d far)" % [near, far])
	h.free()


func test_a_style_sets_its_antialiasing() -> void:
	for dir in ["res://styles/anime_cel", "res://styles/solarpunk", "res://styles/neon_noir"]:
		var h := StyleHost.new()
		runner.root.add_child(h)
		assert_true(h.activate(dir, manifest(), SceneModel.new(), Motion.new(), 0.0), h.last_error)
		assert_eq(runner.root.msaa_3d, Viewport.MSAA_2X, dir + " draws with 2x MSAA")
		h.free()


func test_trees_with_a_far_version_swap_to_it_far_off() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	assert_true(h.activate("res://styles/anime_cel", manifest(), SceneModel.new(), Motion.new(), 0.0), h.last_error)
	var near := 0
	var far := 0
	for n in h.pack.world.find_children("Planting*", "MultiMeshInstance3D", true, false):
		if n.has_meta("far_of"):
			far += 1
			assert_eq(n.visibility_range_begin, Pack3D.FAR_TREE_M, "the far version from %d m" % Pack3D.FAR_TREE_M)
			assert_eq(n.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "no far shadows")
		elif n.visibility_range_end > 0.0:
			near += 1
			assert_eq(n.visibility_range_end, Pack3D.FAR_TREE_M, "the near version to there")
	assert_true(near > 0 and far > 0 and near == far, "each near chunk has its far twin (%d near, %d far)" % [near, far])
	h.free()
