## Voxel grids emit only the faces nobody can see through.
extends TestSuite


func _triangles(root: Node3D) -> int:
	var n := 0
	for mi in root.get_children():
		n += mi.mesh.surface_get_array_len(0) / 3
	return n


func test_a_lone_voxel_has_six_faces() -> void:
	var g := VoxelGrid.new(0.5)
	g.put(Vector3i(0, 0, 0), Color.RED)
	var root := g.build("one", 0.0)
	assert_eq(_triangles(root), 12, "six faces, twelve triangles")
	root.free()


func test_touching_voxels_hide_their_shared_faces() -> void:
	var g := VoxelGrid.new(1.0)
	g.fill(Vector3(0, 0, 0), Vector3(2, 1, 1), Color.RED)
	assert_eq(g.cells.size(), 2, "two voxels")
	var root := g.build("two", 0.0)
	assert_eq(_triangles(root), 20, "ten outer faces")
	root.free()


func test_fill_snaps_metres_to_cells() -> void:
	var g := VoxelGrid.new(0.5)
	g.fill(Vector3(-1, 0, 0), Vector3(0, 1, 0.5), Color.BLUE)
	assert_eq(g.cells.size(), 4, "a 2 x 2 x 1 block of half-metre voxels")
	assert_true(g.cells.has(Vector3i(-2, 1, 0)), "cells index from the floor of x / size")


func test_shade_varies_without_changing_the_hue_much() -> void:
	var g := VoxelGrid.new(1.0)
	g.fill(Vector3(0, 0, 0), Vector3(8, 1, 8), Color(0.8, 0.6, 0.2))
	var root := g.build("floor", 0.06)
	assert_true(root.get_child_count() > 1, "jittered voxels use a few shades")
	assert_true(root.get_child_count() <= 3, "but only a few")
	root.free()
