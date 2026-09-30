extends SceneTree

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var packed = load("res://humanoid-wave.glb") as PackedScene
	if packed == null:
		fail("GLB failed to import")
		return
	var model = packed.instantiate()
	root.add_child(model)
	await process_frame
	var skeletons = model.find_children("*", "Skeleton3D", true, false)
	var players = model.find_children("*", "AnimationPlayer", true, false)
	var meshes = model.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 52:
		fail("Expected 52 character meshes, got " + str(meshes.size()))
		return
	if skeletons.size() != 1 or players.size() != 1:
		fail("Expected one skeleton and one animation player")
		return
	var skeleton = skeletons[0] as Skeleton3D
	var player = players[0] as AnimationPlayer
	var hand = skeleton.find_bone("hand_L")
	if hand < 0:
		hand = skeleton.find_bone("hand.L")
	if skeleton.get_bone_count() != 40 or hand < 0:
		fail("Missing rig bones")
		return
	var clip = ""
	for name in player.get_animation_list():
		if "Wave_Hello" in name:
			clip = name
	if clip.is_empty():
		fail("Wave_Hello missing: " + str(player.get_animation_list()))
		return
	player.play(clip)
	player.seek(0.0, true)
	skeleton.force_update_all_bone_transforms()
	var neutral = skeleton.get_bone_global_pose(hand)
	player.seek(1.6, true)
	skeleton.force_update_all_bone_transforms()
	var raised = skeleton.get_bone_global_pose(hand)
	player.seek(1.95, true)
	skeleton.force_update_all_bone_transforms()
	var waved = skeleton.get_bone_global_pose(hand)
	player.seek(player.get_animation(clip).length, true)
	skeleton.force_update_all_bone_transforms()
	var end = skeleton.get_bone_global_pose(hand)
	var displacement = neutral.origin.distance_to(raised.origin)
	var wave_angle = raised.basis.get_rotation_quaternion().angle_to(waved.basis.get_rotation_quaternion())
	var return_error = neutral.origin.distance_to(end.origin)
	if displacement < 0.4 or wave_angle < 0.1 or return_error > 0.01:
		fail("Motion failed: " + str([displacement, wave_angle, return_error]))
		return
	print(JSON.stringify({"result":"PASS", "bones":skeleton.get_bone_count(), "animation":clip,
		"duration_seconds":player.get_animation(clip).length, "hand_travel_m":displacement,
		"wrist_wave_radians":wave_angle, "return_error_m":return_error,
		"mesh_count":meshes.size()}))
	quit(0)

func fail(message: String) -> void:
	push_error(message)
	quit(1)
