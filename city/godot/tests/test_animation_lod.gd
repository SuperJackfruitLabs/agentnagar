## People animate as closely as they are seen: every frame near the
## camera, a few frames at a time (the same speed on average) far away,
## and not at all out of view.
extends TestSuite


func person(id: String) -> Dictionary:
	return {"id": id, "kind": {"type": "Human", "tier": "Registered"}, "display_name": id, "role": "",
		"badge": null, "appearance": {"palette": "1", "hair": "1"}, "seat": null,
		"presence": {"headline": "Present"}, "pos": {"x": 0, "z": 0}}


func test_animation_follows_distance_and_view() -> void:
	var size_was: Vector2i = runner.root.size
	runner.root.size = Vector2i(1600, 900)
	var h := StyleHost.new()
	runner.root.add_child(h)
	var m := SceneModel.new()
	m.apply({"rooms": [{"id": "room:plaza", "occupants": [person("p:near"), person("p:far"), person("p:behind")], "waiting": []}], "in_transit": [], "time_of_day": 720})
	assert_true(h.activate("res://styles/lowpoly_tropical", JSON.parse_string(CityPaths.district_manifest()), m, Motion.new(), 0.0), "builds")
	await runner.process_frame
	var pack = h.pack
	pack.set_camera_preset("street")
	var cam: Camera3D = pack.rig.camera
	var ahead := -cam.global_transform.basis.z
	ahead = Vector3(ahead.x, 0, ahead.z).normalized()
	var ground := Vector3(cam.global_position.x, 0, cam.global_position.z)
	var at := {"p:near": ground + ahead * 12.0, "p:far": ground + ahead * 90.0, "p:behind": ground - ahead * 30.0}
	for id in at:
		pack.place(id, Vector2(at[id].x, at[id].z) * 100.0, Vector2.ZERO)
	var players := {}
	var start := {}
	for id in at:
		players[id] = Pack3D._player_of(pack.nodes[id].get_node("Model"))
		assert_eq(players[id].callback_mode_process, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, id + " is advanced by the pack")
		start[id] = players[id].current_animation_position
	# A real frame's time may still be owed to the far one when this starts
	# (0.14 s when station scripts load first), which a wall-clock budget
	# took for a fault: the flake the final review found. It is owed here
	# on purpose, and the check measures the work, what was owed and paid,
	# rather than the frames' time alone.
	pack._owed["p:far"] += 0.15
	var owed_before: float = pack._owed["p:far"]
	var near_moves := 0
	for f in 24:
		var was: float = players["p:near"].current_animation_position
		pack._process(1.0 / 60.0)
		if players["p:near"].current_animation_position != was:
			near_moves += 1
	assert_eq(near_moves, 24, "near: every frame")
	assert_eq(pack.move_every("p:near"), 1, "near: moved every frame")
	assert_true(pack.move_every("p:far") > 1, "far: moved less often (%d)" % pack.move_every("p:far"))
	var far_ran: float = fposmod(players["p:far"].current_animation_position - start["p:far"], players["p:far"].current_animation_length)
	var paid: float = owed_before + 24.0 / 60.0 - float(pack._owed["p:far"])
	assert_true(absf(far_ran - paid) < 0.001, "far: ran exactly what it was owed and paid (%.3f s of %.3f s)" % [far_ran, paid])
	assert_true(far_ran - owed_before > 0.2, "far: batched, about as far as near (%.3f s of 0.4 s)" % (far_ran - owed_before))
	assert_eq(players["p:behind"].current_animation_position, start["p:behind"], "out of view: still")
	h.free()
	runner.root.size = size_was


func test_near_animation_advances_at_most_120_times_a_second() -> void:
	var size_was: Vector2i = runner.root.size
	runner.root.size = Vector2i(1600, 900)
	var h := StyleHost.new()
	runner.root.add_child(h)
	var m := SceneModel.new()
	m.apply({"rooms": [{"id": "room:plaza", "occupants": [person("p:near")], "waiting": []}], "in_transit": [], "time_of_day": 720})
	assert_true(h.activate("res://styles/lowpoly_tropical", JSON.parse_string(CityPaths.district_manifest()), m, Motion.new(), 0.0), "builds")
	await runner.process_frame
	var pack = h.pack
	pack.set_camera_preset("street")
	var cam: Camera3D = pack.rig.camera
	var ahead := -cam.global_transform.basis.z
	ahead = Vector3(ahead.x, 0, ahead.z).normalized()
	var at := Vector3(cam.global_position.x, 0, cam.global_position.z) + ahead * 12.0
	pack.place("p:near", Vector2(at.x, at.z) * 100.0, Vector2.ZERO)
	var player: AnimationPlayer = Pack3D._player_of(pack.nodes["p:near"].get_node("Model"))
	pack._process(1.0 / 480.0)
	var start := player.current_animation_position
	var moves := 0
	for f in 48:
		var was: float = player.current_animation_position
		pack._process(1.0 / 480.0)
		if player.current_animation_position != was:
			moves += 1
	assert_true(moves >= 11 and moves <= 13, "at 480 fps, about every fourth frame: %d of 48" % moves)
	var ran: float = fposmod(player.current_animation_position - start, player.current_animation_length)
	assert_true(absf(ran - 0.1) < 1.0 / 120.0 + 0.001, "the same speed: %.3f s of 0.1 s" % ran)
	h.free()
	runner.root.size = size_was


func test_someone_whose_legs_fill_the_view_is_seen() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	var m := SceneModel.new()
	m.apply({"rooms": [{"id": "room:plaza", "occupants": [person("p:legs")], "waiting": []}], "in_transit": [], "time_of_day": 720})
	assert_true(h.activate("res://styles/lowpoly_tropical", JSON.parse_string(CityPaths.district_manifest()), m, Motion.new(), 0.0), "builds")
	var pack = h.pack
	pack.place("p:legs", Vector2(0, 0), Vector2.ZERO)
	# A narrow view at knee height, 3 m off: the legs fill it, the waist
	# (1 m up) is just above it.
	var cam := Camera3D.new()
	cam.fov = 20.0
	runner.root.add_child(cam)
	cam.global_position = Vector3(0, 0.3, 3.0)
	cam.look_at(Vector3(0, 0.3, 0))
	cam.make_current()
	await runner.process_frame
	pack._process(1.0 / 60.0)
	assert_true(pack.is_seen("p:legs"), "seen: their legs are in view")
	cam.free()
	h.free()
