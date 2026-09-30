extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var packed = load("res://main.tscn") as PackedScene
	if packed == null:
		fail("Main scene is missing")
		quit(1)
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	var player := scene.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var skeleton := scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	check(scene.get_node_or_null("CanvasLayer/PilotInterface/IdentityPanel") != null, "identity is rendered")
	check(scene.get_node_or_null("CanvasLayer/PilotInterface/SampleNotice") != null, "sample notice stays visible")
	check(scene.get_node_or_null("CanvasLayer/PilotInterface/Controls") != null, "controls are rendered")
	check(scene.describe().contains("SAMPLE DATA"), "text alternative names sample data")
	check(scene.describe().contains("Kai"), "text alternative identifies Kai")
	check(scene.describe().contains("Working"), "initial state is described")
	scene.set_fixture_state("stale")
	check(scene.describe().contains("Stale"), "stale state appears in text alternative")
	check(scene.active_clip() != "typing", "stale state stops typing")
	check(scene.find_child("SampleDataNotice", true, false).visible, "sample notice persists in stale state")
	scene.set_fixture_state("unavailable")
	check(scene.active_clip() != "typing", "unavailable state stops typing")
	scene.set_fixture_state("unknown")
	check(scene.active_clip() != "typing", "unknown state stops typing")
	scene.set_fixture_state("working")
	var length := player.get_animation(player.current_animation).length
	player.advance(length + 0.1)
	check(player.is_playing() and player.current_animation_position < 0.2, "fixture animation keeps looping after its first duration")
	scene.set_inspection("walk")
	scene.set_reduced_motion(true)
	check(scene.active_clip() == "", "reduced motion stops scene playback")
	check(not player.is_playing(), "reduced motion pauses imported animation")
	check(skeleton.get_bone_pose_position(skeleton.find_bone("Root")).y < -0.2, "reduced motion keeps Kai seated")
	scene.set_reduced_motion(false)
	scene.set_inspection("attend")
	check(scene.describe().contains("Animation preview"), "inspection is labelled in text")
	if scene.missing_assets().is_empty():
		check(scene.active_clip() == "attend", "inspection drives imported attend clip")
	scene.set_inspection("walk")
	check(scene.find_child("Kai", false, false).position.z > 0.3, "standing inspection moves Kai onto clear floor")
	check(scene.describe().contains("Kai stands"), "text alternative describes standing inspection")
	check(not scene.describe().contains("Kai sits"), "standing inspection does not claim Kai is seated")
	scene.set_reduced_motion(true)
	check(scene.describe().contains("Kai sits"), "reduced motion describes the seated override")
	scene.set_reduced_motion(false)
	scene.set_inspection("")
	check(scene.find_child("Kai", false, false).position.z < 0.0, "fixture restores chair position")
	scene.set_inspection("walk")
	var text_toggle := scene.find_child("TextDescriptionToggle", true, false) as CheckButton
	check(text_toggle != null, "text alternative has a named keyboard control")
	if text_toggle != null:
		text_toggle.button_pressed = true
	scene._set_camera("first_person")
	check(scene.camera_mode == "first_person", "first person camera is selectable")
	var eye := scene.find_child("FirstPersonWalker", true, false).get_child(1) as Camera3D
	check(eye.current, "first person camera becomes current")
	var to_kai: Vector3 = (Vector3(0, 1.0, -0.65) - eye.global_position).normalized()
	check((-eye.global_basis.z).dot(to_kai) > 0.9, "first person begins facing Kai's work area")
	scene.reset_pilot()
	check(scene.camera_mode == "overview", "reset restores overview")
	check(scene.describe().contains("Working"), "reset restores fixture")
	check(not scene.describe().contains("Animation preview"), "reset exits inspection")
	check((scene.find_child("AnimationInspection", true, false) as OptionButton).selected == 0, "reset updates inspection selector")
	if text_toggle != null:
		check(not text_toggle.button_pressed, "reset closes text description")
	var motion_toggle := scene.find_child("ReducedMotionToggle", true, false) as CheckButton
	check(motion_toggle != null, "reduced motion has a named keyboard control")
	if motion_toggle != null:
		check(not motion_toggle.button_pressed, "reset clears reduced motion toggle")
	scene._layout(Vector2(360, 640))
	var notice := scene.get_node("CanvasLayer/PilotInterface/SampleNotice") as PanelContainer
	var controls := scene.get_node("CanvasLayer/PilotInterface/Controls") as PanelContainer
	check(controls.position.x >= 0 and controls.position.x + controls.size.x <= 360, "controls fit a 360 px viewport")
	check(controls.position.y >= notice.position.y + notice.size.y, "narrow layout stacks controls below notice")
	var controls_toggle := scene.find_child("ControlsToggle", true, false) as Button
	check(controls_toggle != null, "narrow layout offers a controls toggle")
	if controls_toggle != null:
		check(controls_toggle.visible, "controls toggle is visible at 360 px")
		scene._set_camera("first_person")
		check(not controls.visible, "first person reveals the scene at 360 px")
		controls_toggle.pressed.emit()
		check(controls.visible, "narrow controls can be reopened")
	var missing: Array[String] = scene.missing_assets()
	if missing.size() > 0:
		check(scene.active_clip() == "", "missing imported Kai never pretends to animate")
		check(scene.describe().contains("missing"), "missing assets named in text alternative")
	else:
		for clip in ["idle", "walk", "seated_idle", "typing", "attend"]:
			check(scene.imported_clips().has(clip), "Kai " + clip + " clip imported")
		check(scene.active_clip() == "typing", "fixture drives imported typing clip")
	print(JSON.stringify({"test": "scene", "failures": failures, "missing_assets": missing}))
	quit(0 if failures == 0 else 1)

func check(condition: bool, description: String) -> void:
	if not condition:
		fail(description)

func fail(description: String) -> void:
	failures += 1
	push_error(description)
