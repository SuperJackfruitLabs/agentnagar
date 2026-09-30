extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var script = load("res://fixture_model.gd")
	if script == null:
		fail("Fixture model is missing")
		quit(1)
		return
	var fixture = script.new()
	var clips: Array[String] = ["idle", "walk", "seated_idle", "typing", "attend"]
	fixture.set_state("working")
	check(fixture.clip_for(clips) == "typing", "working uses typing")
	for state in ["idle", "stale", "unavailable", "unknown"]:
		fixture.set_state(state)
		check(fixture.clip_for(clips) == "seated_idle", state + " does not type")
	fixture.set_state("working")
	fixture.set_reduced_motion(true)
	check(fixture.clip_for(clips) == "", "reduced motion stops fixture animation")
	fixture.set_reduced_motion(false)
	fixture.set_inspection("walk")
	check(fixture.clip_for(clips) == "walk", "explicit inspection previews requested clip")
	check(fixture.is_inspecting(), "inspection is distinctly labelled")
	fixture.set_inspection("typing")
	fixture.set_reduced_motion(true)
	check(fixture.clip_for(clips) == "", "reduced motion stops inspection animation")
	fixture.set_reduced_motion(false)
	fixture.set_inspection("")
	var missing_clips: Array[String] = ["idle"]
	check(fixture.clip_for(missing_clips) == "", "missing imported clip fails closed")
	check(not fixture.set_state("verified"), "unrecognised state cannot claim verified work")
	check(fixture.state == "working", "invalid state preserves prior fixture state")
	print(JSON.stringify({"test": "fixture", "failures": failures}))
	quit(0 if failures == 0 else 1)

func check(condition: bool, description: String) -> void:
	if not condition:
		fail(description)

func fail(description: String) -> void:
	failures += 1
	push_error(description)
