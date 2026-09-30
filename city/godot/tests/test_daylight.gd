## The sun moves every frame, not once a tick, so shadows glide rather than
## jump each second.
extends TestSuite


func test_the_sun_moves_smoothly_between_ticks() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=lowpoly_tropical", "--as=none"]))
	for i in 100:
		main.driver.step_once()
	var sun: DirectionalLight3D = main.host.pack.sun
	var angles := []
	for f in 61:
		main.driver.advance(1.0 / 60.0)
		main._process(1.0 / 60.0)
		angles.append(sun.rotation_degrees.y)
	var biggest := 0.0
	var moves := 0
	for k in range(1, angles.size()):
		var d := absf(angles[k] - angles[k - 1])
		biggest = maxf(biggest, d)
		if d > 0.0:
			moves += 1
	assert_true(moves > 50, "the sun moves on nearly every frame (%d of 60)" % moves)
	var per_tick := absf(angles[-1] - angles[0])
	assert_true(biggest < per_tick / 20.0, "no frame jumps a tick's worth (%.3f° of %.3f° a tick)" % [biggest, per_tick])
	main.free()


func test_daylight_eases_the_short_way_round_midnight() -> void:
	var host := StyleHost.new()
	host._ease_day_to(1438)
	host._ease_day_to(0)
	assert_true(absf(host._day_span() - 2.0) < 0.001, "1438 → 0 is two minutes on, not a day back: %f" % host._day_span())
	host._ease_day_to(600)
	assert_eq(host._day_span(), 0.0, "a leap of hours is taken at once")
	host.free()


## In the engine's order (the client's frame, then the driver's tick),
## the frame a tick lands on shows the sun where the frame before left
## it, not a tick ahead.
func test_the_tick_boundary_frame_does_not_jump_the_sun_ahead() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=lowpoly_tropical", "--as=none"]))
	for i in 100:
		main.driver.step_once()
	var sun: DirectionalLight3D = main.host.pack.sun
	var last := sun.rotation_degrees.y
	var biggest := 0.0
	for f in 180:
		main._process(1.0 / 60.0)
		main.driver.advance(1.0 / 60.0)
		biggest = maxf(biggest, absf(sun.rotation_degrees.y - last))
		last = sun.rotation_degrees.y
	assert_true(biggest < 0.05, "no frame moves the sun more than a frame's worth: %.3f°" % biggest)
	main.free()
