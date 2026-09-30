extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run_tests")
func run_tests() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene._capture_mode = true
	await process_frame
	for resident in ["kai", "lyra"]:
		scene.set_resident(resident)
		await process_frame
		check(scene.get_node("CanvasLayer/PilotInterface/IdentityPanel").size.y < 130, "resident identity remains a compact title")
		check(scene.movement.available, resident + " ready for complete motion")
		var actor: Node3D = scene._kai
		var player: AnimationPlayer = scene._player
		var skeleton: Skeleton3D = actor.find_children("*", "Skeleton3D", true, false)[0]
		var bone := skeleton.find_bone("Root")
		for clip in ["stand_up", "sit_down"]:
			check(player.get_animation(scene._actual_clips[clip]).loop_mode == Animation.LOOP_NONE, clip + " is one-shot")
		check(scene.request_leave(), "leave accepted")
		scene.advance_demo(0.325)
		check(is_equal_approx(scene._chair.position.z, -0.975), "visible chair slides")
		check(is_equal_approx(scene.get_node("ChairCollision").position.z, -1.005), "chair collision slides with mesh")
		scene.advance_demo(0.325 + 0.666666)
		check(scene.active_clip() == "stand_up", "real stand transition plays")
		check(actor.position.is_equal_approx(Vector3(0,0,-1.3)), "transition instance stays at pulled anchor")
		check(skeleton.get_bone_pose_position(bone).y > -0.29 and skeleton.get_bone_pose_position(bone).y < 0, "transition root has intermediate height")
		scene.set_fixture_state("stale")
		check(scene.active_clip() == "stand_up", "fixture change does not interrupt journey")
		scene.advance_demo(0.666668)
		check(actor.position.is_equal_approx(Vector3(0,0,-0.9636965656)), "switch to idle compensates root motion")
		scene.advance_demo(0.35 + 2.0)
		check(scene.active_clip() == "walk", "actor actually walking after two seconds of travel")
		check(is_equal_approx(player.current_animation_position, fposmod(scene.movement.elapsed, player.current_animation_length)), "walk samples wrap at measured cycle length")
		var thigh := skeleton.find_bone("Thigh.L")
		var rotation_before := skeleton.get_bone_pose_rotation(thigh)
		scene.advance_demo(0.2)
		check(not rotation_before.is_equal_approx(skeleton.get_bone_pose_rotation(thigh)), "walk limbs continue moving beyond first animation cycle")
		scene.advance_demo(100)
		check(scene.active_clip() == "idle", "away resident idles")
		scene.set_fixture_state("working")
		check(scene.active_clip() == "idle", "working never types away from keyboard")
		scene.request_return()
		scene.advance_demo(100)
		check(scene.active_clip() == "typing", "return restores requested fixture at desk")
		check(actor.position == Vector3(0,0,-0.65), "actual actor returns to seat")
		scene.request_leave()
		scene.advance_demo(1)
		scene.set_reduced_motion(true)
		check(scene.movement.phase == "away" and not player.is_playing(), "reduced motion snaps away and stops player")
		scene.request_return()
		check(scene.movement.phase == "seated" and not player.is_playing(), "reduced motion returns and stops player")
		scene.set_reduced_motion(false)
		scene.request_leave()
		scene.set_inspection("attend")
		check(scene.movement.phase == "seated" and not scene.movement.busy(), "manual inspection cancels movement")
		scene.reset_pilot()
	scene.request_leave()
	scene.advance_demo(1)
	scene.set_resident("kai")
	check(scene.movement.phase == "seated" and scene._actors.kai.visible and not scene._actors.lyra.visible, "resident change cancels and shows just one resident")
	# Offline recording and live frames must evaluate identical imported poses.
	var live = load("res://main.tscn").instantiate()
	root.add_child(live)
	live.set_process(false)
	scene.reset_pilot()
	live.reset_pilot()
	scene.request_leave()
	live.request_leave()
	for frame in range(150):
		scene.advance_demo(1.0/24.0)
		live.advance_demo(1.0/24.0)
		var captured_skeleton: Skeleton3D = scene._kai.find_children("*", "Skeleton3D", true, false)[0]
		var live_skeleton: Skeleton3D = live._kai.find_children("*", "Skeleton3D", true, false)[0]
		check(captured_skeleton.get_bone_pose(10).is_equal_approx(live_skeleton.get_bone_pose(10)), "capture preserves live thigh pose including blends")
	live.queue_free()
	scene.reset_pilot()
	scene._actual_clips.erase("stand_up")
	scene.set_resident("kai")
	check(not scene.request_leave() and scene.describe().contains("Movement unavailable"), "missing clip blocks demo honestly")
	print(JSON.stringify({"test":"journey", "failures":failures}))
	quit(0 if failures == 0 else 1)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
