extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run_tests")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run_tests() -> void:
	if not ResourceLoader.exists("res://shared_workshop.tscn"):
		check(false, "shared workshop scene must exist with simultaneous residents")
		quit(1)
		return
	var scene = load("res://shared_workshop.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	await physics_frame
	check(scene.stations.size() == 14, "fourteen independent stations")
	check(scene.missing_assets().is_empty(), "all actual workshop GLBs imported")
	var kai = scene.stations.kai
	var lyra = scene.stations.lyra
	check(kai.actor.visible and lyra.actor.visible, "Kai and Lyra visible simultaneously")
	check(kai.movement.available and lyra.movement.available, "Kai's and Lyra's imported rigs support journey")
	scene.set_fixture_state("lyra", "stale")
	check(kai.fixture.state == "working" and lyra.fixture.state == "stale", "fixture states independent")
	scene.request_leave("all")
	for frame in range(360):
		scene.advance_demo(1.0/24)
		check(kai.actor.position.distance_to(lyra.actor.position) > 1.0, "independent lanes never overlap")
	check(kai.movement.phase == "away" and lyra.movement.phase == "away", "both complete leave journey")
	scene.request_return("all")
	scene.advance_demo(30)
	check(kai.movement.phase == "seated" and lyra.movement.phase == "seated", "both complete return with large delta")
	check(kai.current_clip == "typing" and lyra.current_clip == "seated_idle", "arrival honors independent fixtures")
	scene.reset_workshop()
	scene.request_leave("kai")
	scene.advance_demo(0.65 + 0.66666)
	var skeleton: Skeleton3D = kai.actor.find_children("*", "Skeleton3D", true, false)[0]
	check(kai.current_clip == "stand_up", "actual imported transition playing")
	check(skeleton.get_bone_pose_position(skeleton.find_bone("Root")).y < 0, "transition root has authored intermediate height")
	var evaluated_root := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Root")).origin
	check(is_equal_approx(kai.actor_body.position.z,evaluated_root.z), "collision follows imported transition Root")
	scene.advance_demo(0.66668)
	check(kai.actor.position.is_equal_approx(kai.origin + Vector3(0,0,-0.9636965656)), "standing root offset compensation")
	scene.reset_workshop()
	scene.request_leave("kai")
	scene.walker.position = kai.origin + Vector3(1.1,0,-0.9636965656)
	scene.advance_demo(30)
	check(kai.waiting and kai.movement.phase == "walking", "swept visitor obstacle stops a large delta")
	check(kai.actor.position.distance_to(scene.walker.position) >= 0.6, "visitor safe stopping clearance")
	check(kai.fixture.state == "working", "waiting never changes work sample")
	check(lyra.movement.phase == "seated", "waiting does not move other resident")
	scene.walker.position = Vector3(8,0,1)
	scene.advance_demo(30)
	check(not kai.waiting and kai.movement.phase == "away", "visitor clearing lane resumes motion")
	scene.request_return("kai")
	scene.set_reduced_motion(true)
	check(kai.movement.phase == "seated" and not kai.player.is_playing(), "reduced motion valid seated endpoint")
	scene.request_leave("all")
	check(kai.movement.phase == "away" and lyra.movement.phase == "away", "reduced motion independent stable endpoints")
	scene.reset_workshop()
	check(kai.actor.position.is_equal_approx(kai.origin + Vector3(0,0,-0.65)), "reset valid anchor")
	# Physics sweep through real imported layout doorway, both directions.
	scene.walker.position = Vector3(6,0,1)
	await physics_frame
	var hit = scene.walker.move_and_collide(Vector3(-2,0,0))
	check(hit == null and scene.walker.position.x < 4.1, "visitor traverses east opening into hall")
	hit = scene.walker.move_and_collide(Vector3(2,0,0))
	check(hit == null and scene.walker.position.x > 5.9, "visitor traverses opening out to courtyard")
	scene.walker.position = Vector3(6,0,2.2)
	await physics_frame
	hit = scene.walker.move_and_collide(Vector3(-2,0,0))
	check(hit != null, "wall beside doorway remains solid")
	# Regression: round visitor against the corner of the actual square actor body.
	scene.reset_workshop()
	scene.walker.position = kai.origin + Vector3(0.61,0,-1.20)
	scene.request_leave("kai")
	scene.advance_demo(0.10)
	await physics_frame
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = scene.walker.get_child(0).shape
	query.transform = scene.walker.global_transform * scene.walker.get_child(0).transform
	query.exclude = [scene.walker.get_rid()]
	var overlaps: Array = scene.get_world_3d().direct_space_state.intersect_shape(query)
	for overlap in overlaps:
		check(overlap.collider != kai.actor_body, "diagonal visitor never overlaps actual actor collision box")
	# Chair and actor sweeps must also guard the first pullback segment.
	scene.reset_workshop()
	scene.walker.position = kai.origin + Vector3(0,0,-1.8)
	scene.request_leave("kai")
	scene.advance_demo(3)
	check(kai.waiting and kai.movement.phase == "pulling chair", "visitor behind chair blocks pullback before contact")
	check(kai.chair.position.distance_to(scene.walker.position) >= 0.6, "chair swept clearance preserved")
	scene.walker.position = Vector3(8,0,1)
	scene.advance_demo(30)
	check(kai.movement.phase == "away", "blocked chair journey resumes")
	check(scene.swept_near(Vector3(-2,0,0),Vector3(2,0,0),Vector3.ZERO,0.65), "segment sweep catches obstacle despite clear endpoints")
	# The UI state controls target their own actor. Look the selector up by
	# resident key, not position: at fourteen stations, the Nth OptionButton
	# found in the tree is whichever resident sits Nth in roster order, not
	# necessarily Lyra, so an index into a flat find_children() list would
	# silently test the wrong resident's control.
	scene.selectors["lyra"].item_selected.emit(2)
	check(lyra.fixture.state == "stale" and kai.fixture.state == "working", "Lyra UI selector does not change Kai")
	# Live and recorded frames use identical animation evaluations and blends.
	var live = load("res://shared_workshop.tscn").instantiate()
	root.add_child(live)
	live.set_process(false)
	scene.reset_workshop()
	live.reset_workshop()
	scene.request_leave("all")
	live.request_leave("all")
	for frame in range(160):
		scene.advance_demo(1.0/24)
		live._process(1.0/24)
		for key in ["kai","lyra"]:
			var captured: Skeleton3D = scene.stations[key].actor.find_children("*","Skeleton3D",true,false)[0]
			var playing: Skeleton3D = live.stations[key].actor.find_children("*","Skeleton3D",true,false)[0]
			check(captured.get_bone_pose(10).is_equal_approx(playing.get_bone_pose(10)), "offline/live imported pose parity")
	live.queue_free()
	scene.reset_workshop()
	kai.clips.erase("stand_up")
	check(not scene.request_leave("kai"), "missing required clip blocks travel")
	check(scene.describe().contains("unavailable"), "text reports unavailable motion honestly")
	print(JSON.stringify({"test":"shared_workshop", "failures":failures}))
	quit(0 if failures == 0 else 1)
