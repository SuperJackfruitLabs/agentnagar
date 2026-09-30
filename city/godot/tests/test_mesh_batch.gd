## Batched meshes face outward (Godot's front faces wind clockwise) and cost
## one surface per material.
extends TestSuite


func _faces(root: Node3D) -> Array:
	var out := []
	for mi in root.get_children():
		var arrays: Array = mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for k in range(0, v.size(), 3):
			out.append({"a": v[k], "b": v[k + 1], "c": v[k + 2], "n": n[k]})
	return out


func _check_outward(root: Node3D, centre: Vector3, what: String) -> void:
	var ok := true
	for f in _faces(root):
		var mid: Vector3 = (f["a"] + f["b"] + f["c"]) / 3.0
		var geo: Vector3 = (f["b"] - f["a"]).cross(f["c"] - f["a"])
		if f["n"].dot(mid - centre) <= 0.0 or geo.dot(f["n"]) >= 0.0:
			ok = false
	assert_true(ok, what + " faces outward, wound clockwise")


func test_a_box_is_twelve_outward_triangles() -> void:
	var b := MeshBatch.new()
	b.box(Vector3(2, 1, 4), Transform3D(Basis(Vector3.UP, 0.4), Vector3(1, 2, 3)), MeshBatch.material(Color.RED))
	var root := b.build("box")
	assert_eq(root.get_child_count(), 1, "one material, one surface")
	assert_eq(_faces(root).size(), 12, "twelve triangles")
	_check_outward(root, Vector3(1, 2, 3), "the box")
	root.free()


func test_a_prism_of_any_winding_faces_outward() -> void:
	for profile in [PackedVector2Array([Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)]),
			PackedVector2Array([Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0)])]:
		var b := MeshBatch.new()
		b.prism(profile, 3.0, Transform3D(), MeshBatch.material(Color.BLUE))
		var root := b.build("prism")
		assert_eq(_faces(root).size(), 8, "three sides and two caps")
		_check_outward(root, Vector3(0, 1.0 / 3.0, 0), "the prism")
		root.free()


func test_materials_are_shared_by_colour() -> void:
	assert_true(MeshBatch.material(Color.RED) == MeshBatch.material(Color.RED), "same colour, same material")
	var b := MeshBatch.new()
	b.box(Vector3.ONE, Transform3D(), MeshBatch.material(Color.RED))
	b.box(Vector3.ONE, Transform3D(Basis(), Vector3(3, 0, 0)), MeshBatch.material(Color.RED))
	b.box(Vector3.ONE, Transform3D(), MeshBatch.material(Color.GREEN))
	var root := b.build("two")
	assert_eq(root.get_child_count(), 2, "one surface per material")
	root.free()


func test_hip_roof_and_dome_face_outward() -> void:
	var b := MeshBatch.new()
	b.hip_roof(6, 4, 2, Vector3.ZERO, MeshBatch.material(Color.ORANGE), 0.0)
	var roof := b.build("roof")
	_check_outward(roof, Vector3(0, 0.3, 0), "the hip roof")
	roof.free()
	b.dome(2.0, Vector3.ZERO, MeshBatch.material(Color.GREEN))
	var dome := b.build("dome")
	_check_outward(dome, Vector3(0, -0.01, 0), "the dome")
	dome.free()
