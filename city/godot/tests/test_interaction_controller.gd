## The interaction controller (Part B task 1's refactor out of main.gd):
## current_target is computed once a call to frame(), however many of
## main.gd's own per-frame readers (the prompt, the surface in focus) ask
## for it afterwards (Part A's final review found it run twice a frame).
extends TestSuite

const NOTICEBOARD := "placement:square-noticeboard"


func booted(args: Array):
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(args))
	assert_true(not main.hud.error_label.visible, "booted: " + main.hud.error_label.text)
	return main


func arrive(main) -> void:
	for i in 80:
		main.driver.step_once()
		if main.player.present and not main.player.view.get("moving", false):
			break
	for i in 40:
		if not tram_by_the_square(main.driver.world):
			break
		main.driver.step_once()
	assert_true(main.player.present, "arrived")


func frames(main, seconds: float) -> void:
	for f in int(round(seconds * 60.0)):
		main._process(1.0 / 60.0)
		main.driver.advance(1.0 / 60.0)


## A _process() frame drives both the prompt (InteractionController.frame,
## through _update_prompt) and the surface in focus (_surface_target) from
## the same target: current_target's own computation runs once for that
## frame, not once for each of those two readers.
func test_current_target_runs_once_a_process_frame_for_both_readers() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	frames(main, 0.05)
	var before: int = main.interaction.target_calc_calls
	main._process(1.0 / 60.0)
	assert_eq(main.interaction.target_calc_calls - before, 1,
		"current_target ran once, though the prompt and the surface in focus both read it")
	main.free()


## current_target() and choice() stay ordinary, always-fresh calls off the
## per-frame path: called directly (as a test, or the HUD's own refresh,
## may), each recomputes rather than answering from a frame() gone stale.
func test_current_target_and_choice_stay_fresh_when_called_directly() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	frames(main, 0.05)
	# Close a room the crosshair was aimed into, with no frame() in between:
	# a direct call must see it at once, exactly as choice() always did.
	main.player.go_point(Vector2(-1500, 600))
	for i in 60:
		main.driver.step_once()
		frames(main, 0.05)
		if not main.player.view.get("moving", false) and not main.player.following:
			break
	main._toggle_fpv()
	var cam: FpvCamera = main.host.pack.fpv
	cam.yaw = FpvCamera.yaw_along(Vector2(-1, 0))
	cam.pitch = 0.0
	cam.look(0.0, -5.0)
	frames(main, 0.05)
	main.nav.set_closed([])
	assert_eq(main.interaction.choice()["text"], "Go in", "open, called directly")
	main.nav.set_closed(["room:commons"])
	assert_eq(main.interaction.choice()["text"], "Go in · Full", "full, called directly with no frame() in between")
	main.free()
