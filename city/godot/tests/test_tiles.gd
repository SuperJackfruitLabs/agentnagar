## A kit piece tiled many times (KitTown.tiles) is split into chunks by
## ground cell, so the renderer can cull what is off screen and outside
## each shadow split, instead of drawing the whole district's planting in
## every pass.
extends TestSuite


func _town() -> KitTown:
	return KitTown.new({}, func(_path: String) -> Node3D:
		var n := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		n.add_child(mi)
		return n)


func _instances(n: Node) -> int:
	var total := 0
	for c in [n] + n.find_children("*", "MultiMeshInstance3D", true, false):
		if c is MultiMeshInstance3D:
			total += c.multimesh.instance_count
	return total


func test_a_spread_of_pieces_is_chunked_for_culling() -> void:
	var xf := []
	for i in 40:
		for j in 40:
			xf.append(Transform3D(Basis(), Vector3(i * 5.0, 0, j * 5.0)))
	var node := _town().tiles("tree", xf, "Planting", true)
	assert_eq(str(node.name), "Planting", "named as asked")
	assert_eq(_instances(node), 1600, "every piece drawn once")
	var chunks := node.find_children("*", "MultiMeshInstance3D", true, false)
	assert_true(chunks.size() > 1, "split into chunks (%d)" % chunks.size())
	for c in chunks:
		var lo := Vector3.INF
		var hi := -Vector3.INF
		for k in c.multimesh.instance_count:
			var p: Vector3 = c.multimesh.get_instance_transform(k).origin
			lo = lo.min(p)
			hi = hi.max(p)
		assert_true(hi.x - lo.x < KitTown.CHUNK_M and hi.z - lo.z < KitTown.CHUNK_M, "a chunk's pieces lie in one cell: %s" % (hi - lo))
		assert_eq(c.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "chunks keep the shadow setting")
	node.free()


func test_a_small_run_stays_one_multimesh() -> void:
	var xf := [Transform3D(Basis(), Vector3.ZERO), Transform3D(Basis(), Vector3(2, 0, 0))]
	var node := _town().tiles("kerb", xf, "Kerbs")
	assert_true(node is MultiMeshInstance3D, "no chunking needed")
	assert_eq(_instances(node), 2, "both drawn")
	node.free()


func test_a_door_bay_is_as_wide_as_its_door() -> void:
	var list := KitTown.bays(12.0, [4.0, 9.0], 4.0, [2.0, 3.0])
	var doors := list.filter(func(b): return b["door"])
	assert_eq(doors.size(), 2, "a bay for each door")
	assert_eq([doors[0]["t0"], doors[0]["t1"]], [3.0, 5.0], "a 2 m door's bay")
	assert_eq([doors[1]["t0"], doors[1]["t1"]], [7.5, 10.5], "a 3 m door's bay")
	var covered := 0.0
	for b in list:
		covered += b["t1"] - b["t0"]
	assert_eq(covered, 12.0, "the bays fill the side")


func test_a_voxel_door_bay_opens_as_wide_as_its_door() -> void:
	# Voxel's door pieces are drawn 4 m wide round a 2 m opening, clear
	# where people walk; a door's bay stretches the piece so the opening is
	# the door's width.
	var Voxel = load("res://styles/voxel/townscape.gd")
	var list: Array = Voxel.modules(20.0, [5.0, 14.0], [2.0, 3.0], 4.0, 2.0, ["wall"])
	var doors := list.filter(func(m): return m["kind"] == "door")
	assert_eq(doors.map(func(m): return [m["t"] - m["w"] / 2.0, m["t"] + m["w"] / 2.0]), [[3.0, 7.0], [11.0, 17.0]],
		"a 2 m door's bay is 4 m, a 3 m door's 6 m")
	var covered := 0.0
	for m in list:
		covered += m["w"]
	assert_eq(covered, 20.0, "the modules fill the side")
	for name_ in ["ws_door", "lib_entrance"]:
		var piece: Node3D = load("res://styles/voxel/assets/v2/%s.glb" % name_).instantiate()
		var inside := 0
		var jambs := 0
		for p in KitTown.band_points_of(piece, Vector2(0.25, 1.9)):
			if absf(p.x) < Voxel.DOOR_OPENING / 2.0 - 0.001:
				inside += 1
			elif absf(p.x) < Voxel.DOOR_OPENING / 2.0 + 0.1:
				jambs += 1
		assert_eq(inside, 0, "%s's opening is clear where people walk" % name_)
		assert_true(jambs > 0, "%s's jambs stand at the opening's edges" % name_)
		piece.free()


func test_a_fitted_piece_fills_its_ring_in_the_walking_band() -> void:
	# A 2 m x 0.6 m block standing 3 m high, off-centre in its own frame.
	var town := KitTown.new({}, func(_path: String) -> Node3D:
		var n := Node3D.new()
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.0, 3.0, 0.6)
		mi.mesh = box
		mi.position = Vector3(0.3, 1.5, 0.1)
		n.add_child(mi)
		return n)
	var own := town.band_box("wall")
	assert_true(own.position.is_equal_approx(Vector2(-0.7, -0.2)) and own.size.is_equal_approx(Vector2(2.0, 0.6)),
		"its band slice, in its own frame: %s" % own)
	var root := Node3D.new()
	# The east side of a room: along +z from (5, 0), facing +x.
	var n := town.fitted(root, "wall", Vector2(5, 0), Vector2(0, 1), Vector2(1, 0), 1.0, 3.0, 0.0, 0.25)
	var placed := KitTown.band_box_of(root)
	assert_true(placed.position.is_equal_approx(Vector2(5.0, 1.0)) and placed.size.is_equal_approx(Vector2(0.25, 2.0)),
		"it fills x 5..5.25 (the ring outside the room), z 1..3: %s" % placed)
	assert_eq(n.get_parent(), root, "the piece is placed under its parent")
	root.free()


func test_a_pieces_band_reach_is_its_farthest_point_in_the_walking_band() -> void:
	# A 0.3 m trunk 3 m tall, and a 1 m crown above the band: the reach is
	# the trunk's, off its middle as the trunk stands off the origin.
	var town := KitTown.new({}, func(_path: String) -> Node3D:
		var n := Node3D.new()
		var trunk := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.3
		cylinder.bottom_radius = 0.3
		cylinder.height = 3.0
		trunk.mesh = cylinder
		trunk.position = Vector3(0.1, 1.5, 0.0)
		n.add_child(trunk)
		var crown := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 1.0
		ball.height = 2.0
		crown.mesh = ball
		crown.position = Vector3(0, 4.0, 0)
		n.add_child(crown)
		return n)
	assert_true(absf(town.band_reach("palm") - 0.4) < 1e-3, "the trunk's far side, 0.4 m out: %f" % town.band_reach("palm"))


func test_a_spans_clear_half_width_is_how_near_its_parapets_come_in_the_band() -> void:
	# Parapets 0.9 m and 1.0 m off a bridge span's middle, and a kerb that
	# crosses the middle below the band: the clear half-width is the nearer
	# parapet's inner face. A beam across the middle in the band closes it.
	var parts := [[Vector3(4, 1.0, 0.2), Vector3(0, 0.5, 1.0)], [Vector3(4, 1.0, 0.2), Vector3(0, 0.5, -1.1)],
		[Vector3(4, 0.1, 2.4), Vector3(0, 0.05, 0)]]
	var town_of := func(pieces: Array) -> KitTown:
		return KitTown.new({}, func(_path: String) -> Node3D:
			var n := Node3D.new()
			for part in pieces:
				var mi := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = part[0]
				mi.mesh = box
				mi.position = part[1]
				n.add_child(mi)
			return n)
	var band := Vector2(0.25, 1.9)
	var open_span: KitTown = town_of.call(parts)
	assert_true(absf(open_span.clear_half_width("span", band) - 0.9) < 1e-4, "the nearer parapet's inner face, 0.9 m out")
	var closed: KitTown = town_of.call(parts + [[Vector3(4, 0.2, 2.4), Vector3(0, 1.0, 0)]])
	assert_eq(closed.clear_half_width("span", band), 0.0, "a beam across the middle leaves none")
