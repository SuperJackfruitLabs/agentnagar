extends SceneTree
## A resident departing past a SEATED neighbour is the case bay pitch has to
## clear. Departure pulls the chair 1.30 m toward -Z before standing, so a
## mover only closes on a neighbour seated at LOWER z; a neighbour at higher z
## never approaches. The two ordered pairs are directional, so every resident
## must take a turn as the mover, with all others seated, to actually
## exercise the binding (lower-z-neighbour) direction.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run_tests")
func run_tests() -> void:
	var scene = load("res://shared_workshop.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	await physics_frame
	check(scene.missing_assets().is_empty(), "all workshop assets import")
	var keys := []
	for k in scene.stations: keys.append(k)
	keys.sort()
	check(keys.size() >= 2, "at least two residents to test against each other")
	# Every resident takes a turn as the mover, with all others seated, so both
	# ordered pairs (and the directional, binding one) get exercised.
	for mover in keys:
		scene.request_leave(mover)
		for i in range(900): scene.advance_demo(0.1)
		var m = scene.stations[mover]
		check(m.movement.phase == "away", mover + ": departing resident cleared its seated neighbours, got: " + m.movement.phase)
		check(not m.waiting, mover + ": departing resident must not be left waiting on a seated neighbour")
		for k in keys:
			if k == mover: continue
			check(scene.stations[k].movement.phase == "seated", mover + ": neighbour " + k + " must stay seated")
		scene.request_return(mover)
		for i in range(900): scene.advance_demo(0.1)
		check(scene.stations[mover].movement.phase == "seated", mover + ": returning resident reached its bay")
	print(JSON.stringify({"test": "bay_pitch", "failures": failures}))
	quit(0 if failures == 0 else 1)
