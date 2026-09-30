extends SceneTree
var failures := 0
func _initialize() -> void:
	var path := "res://movement_controller.gd"
	if not FileAccess.file_exists(path):
		check(false, "Movement controller exists")
		quit(1)
		return
	var script = load(path)
	var a = script.new()
	var b = script.new()
	check(a.phase == "seated", "starts seated")
	check(a.request_leave(), "leave accepted")
	check(not a.request_leave() and not a.request_return(), "overlapping commands rejected")
	a.advance(0.325)
	check(a.chair_position.is_equal_approx(Vector3(0,0,-0.975)), "chair visibly slides halfway")
	check(a.actor_position == a.chair_position, "actor follows sliding chair")
	a.advance(0.325 + 32.0/24.0)
	check(a.actor_position.is_equal_approx(Vector3(0,0,-0.9636965656)), "standing endpoint compensates authored root")
	b.request_leave()
	b.advance(4.0)
	a.advance(4.0 - 0.65 - 32.0/24.0)
	check(a.actor_position.is_equal_approx(b.actor_position) and a.phase == b.phase, "elapsed time independent of frame partition")
	a.advance(100)
	check(a.phase == "away" and a.actor_position == Vector3(1.45,0,1.15), "outbound completes")
	check(a.request_return(), "return accepted")
	a.advance(100)
	check(a.phase == "seated" and a.actor_position == Vector3(0,0,-0.65), "return completes at desk")
	a.request_leave()
	a.advance(1)
	a.set_reduced_motion(true)
	check(a.phase == "away", "reduced motion snaps outbound destination")
	a.request_return()
	check(a.phase == "seated", "reduced motion returns immediately")
	a.set_reduced_motion(false)
	a.request_leave()
	a.advance(3)
	a.reset()
	a.advance(100)
	check(a.phase == "seated", "reset cancels pending phases")
	a.available = false
	check(not a.request_leave(), "missing assets fail closed")
	print(JSON.stringify({"test":"movement", "failures":failures}))
	quit(0 if failures == 0 else 1)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
