## The anime style's toon materials, outlines and line pass: every material
## under a node turns toon once, keeping its identity (so night glow still
## reaches glass), characters get an inverted-hull outline, and a camera
## gets the full-screen line pass.
extends TestSuite


func tree() -> Node3D:
	var root := Node3D.new()
	var a := MeshInstance3D.new()
	var box := BoxMesh.new()
	var surface := StandardMaterial3D.new()
	surface.resource_name = "glass_a"
	box.material = surface
	a.mesh = box
	root.add_child(a)
	var b := MeshInstance3D.new()
	b.mesh = SphereMesh.new()
	b.material_override = StandardMaterial3D.new()
	a.add_child(b)
	var mm := MultiMeshInstance3D.new()
	mm.multimesh = MultiMesh.new()
	var tile := BoxMesh.new()
	tile.material = StandardMaterial3D.new()
	mm.multimesh.mesh = tile
	root.add_child(mm)
	return root


func all_materials(root: Node) -> Array:
	var out := []
	for n in [root] + root.find_children("*", "", true, false):
		if n is MeshInstance3D:
			if n.material_override != null:
				out.append(n.material_override)
			for s in n.mesh.get_surface_count():
				if n.mesh.surface_get_material(s) != null:
					out.append(n.mesh.surface_get_material(s))
		elif n is MultiMeshInstance3D:
			for s in n.multimesh.mesh.get_surface_count():
				out.append(n.multimesh.mesh.surface_get_material(s))
	return out


func test_every_material_turns_toon_and_runtime_materials_are_copied() -> void:
	var root := tree()
	var before := all_materials(root)
	assert_eq(before.size(), 3, "three materials to convert")
	Toon.apply(root)
	var after := all_materials(root)
	for k in after.size():
		assert_true(after[k] != before[k], "runtime material %d is copied, not changed" % k)
		assert_eq(before[k].diffuse_mode, BaseMaterial3D.DIFFUSE_BURLEY, "the original stays as other styles use it")
		assert_eq(after[k].diffuse_mode, BaseMaterial3D.DIFFUSE_TOON, "toon diffuse")
		assert_eq(after[k].specular_mode, BaseMaterial3D.SPECULAR_TOON, "toon specular")
		assert_true(after[k].rim_enabled, "a rim light")
		assert_true(after[k].has_meta("toon"), "marked converted")
	var rough: float = after[0].roughness
	after[0].roughness = 0.99
	Toon.apply(root)
	assert_true(is_equal_approx(after[0].roughness, 0.99), "a second pass leaves converted materials alone")
	after[0].roughness = rough
	root.free()


func test_the_anime_kits_own_materials_turn_in_place() -> void:
	var packed = load("res://styles/anime_cel/assets/hall_window_wall.glb")
	var model: Node3D = packed.instantiate()
	var before := all_materials(model)
	Toon.apply(model)
	var after := all_materials(model)
	assert_true(not before.is_empty(), "the kit piece has materials")
	for k in after.size():
		assert_true(after[k] == before[k], "kit material %d keeps its identity (night glow holds it)" % k)
		assert_eq(after[k].diffuse_mode, BaseMaterial3D.DIFFUSE_TOON, "and turns toon")
	model.free()


func test_an_outline_is_an_inverted_hull_in_ink() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = SphereMesh.new()
	mi.material_override = StandardMaterial3D.new()
	mi.material_override.albedo_color = Color("#2F63C8")
	Toon.outline(mi, 1.5)
	var hull: Material = mi.material_override.next_pass
	assert_true(hull is ShaderMaterial, "a hull pass follows the surface")
	assert_eq(hull.shader.resource_path, "res://styles/anime_cel/shaders/outline.gdshader", "the outline shader")
	var ink: Color = hull.get_shader_parameter("ink")
	assert_true(ink.v < 0.5 and ink.b > ink.r, "ink is a dark, cool tone of the fill, never black: %s" % ink)
	assert_true(ink.v > 0.05, "not pure black")
	assert_eq(hull.get_shader_parameter("width_px"), 1.5, "its width")
	Toon.outline(mi, 1.5)
	assert_true(mi.material_override.next_pass.next_pass == null, "outlining twice adds one hull")
	mi.free()


func test_a_camera_gets_one_line_pass() -> void:
	var cam := Camera3D.new()
	var pass_ := Toon.line_pass(cam)
	assert_true(pass_.get_parent() == cam, "the pass rides the camera")
	assert_true(pass_.material_override.shader.resource_path.ends_with("lines.gdshader"), "the lines shader")
	assert_true(Toon.line_pass(cam) == pass_, "asking again gives the same pass")
	cam.free()


func test_pack_3d_offers_a_style_hook_the_existing_styles_leave_alone() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	assert_true(h.activate("res://styles/lowpoly_tropical", JSON.parse_string(CityPaths.district_manifest()), SceneModel.new(), Motion.new(), 0.0), "builds")
	assert_true(h.pack.has_method("_style_node"), "the hook exists")
	var any_toon := false
	for m in all_materials(h.pack.world):
		if m is BaseMaterial3D and m.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON:
			any_toon = true
	assert_true(not any_toon, "the low-poly style is untouched")
	h.free()
