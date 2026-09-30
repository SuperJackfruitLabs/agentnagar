## Controls from the spec's table and first-person section: the overhead
## soft reticle for A, the name tag of whoever you look at in first person,
## the pixel style's F per a setting, --camera=fpv, Esc and the camera
## presets in first person.
extends TestSuite


func booted(args: Array):
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(args))
	assert_true(not main.hud.error_label.visible, "booted: " + main.hud.error_label.text)
	return main


## Steps whole ticks until the player stands still in the city, then
## until no tram is by the Square: the player rides in and steps off there
## among the tram's other riders, who walk on past it, and the tests below
## start with it standing alone and the tracks clear, as it used to arrive.
func arrive(main) -> void:
	for i in 80:
		main.driver.step_once()
		if main.player.present and not main.player.view.get("moving", false):
			break
	for i in 40:
		if not tram_by_the_square(main.driver.world):
			break
		main.driver.step_once()
	assert_true(not tram_by_the_square(main.driver.world), "the trams have left the Square")


func frames(main, seconds: float) -> void:
	for f in int(round(seconds * 60.0)):
		main._process(1.0 / 60.0)
		main.driver.advance(1.0 / 60.0)


func key(code: int, pressed := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e


## Walks the player to stand facing a free plaza bench, one step away.
func face_a_bench(main) -> String:
	for s in main.nav.seats:
		if s["room"] == "room:plaza" and not main.player.unavailable_seats().has(s["id"]):
			main.player.go_point(s["pos"] + Vector2(0, 90))
			for i in 60:
				main.driver.step_once()
				var ahead: Dictionary = main.interaction.current_target()
				if not main.player.view.get("moving", false) and ahead.get("type") == "seat":
					return ahead["target"]
	return ""


func test_every_pack_draws_the_reticle_where_asked() -> void:
	var main = booted(["--crowd=0", "--as=none"])
	for dir in main.styles:
		main._activate(dir)
		var pack: StylePack = main.host.pack
		pack.show_reticle(Vector2(-600, 900))
		assert_true(pack.reticle != null and pack.reticle.visible, dir.get_file() + " shows a reticle")
		var at = pack.screen_at(Vector2(-600, 900))
		var node_at = pack.reticle_screen_pos()
		assert_true(at != null and node_at != null and node_at.distance_to(at) < 3.0, "%s: at the point (%s, %s)" % [dir.get_file(), at, node_at])
		pack.show_reticle(null)
		assert_true(not pack.reticle.visible, dir.get_file() + " hides it")
	main.free()


func test_overhead_the_reticle_shows_the_seat_a_would_take() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	var seat := face_a_bench(main)
	assert_true(seat != "", "standing by a free bench")
	frames(main, 0.1)
	var pack: StylePack = main.host.pack
	assert_true(pack.reticle != null and pack.reticle.visible, "the reticle is up")
	var want: Vector2 = main.nav.seats.filter(func(s): return s["id"] == seat)[0]["pos"]
	assert_true(pack.reticle_ground_pos().distance_to(want) < 1.0, "on the seat A would take")
	main._toggle_fpv()
	frames(main, 0.1)
	assert_true(not pack.reticle.visible, "not in first person: the crosshair does that")
	main.free()


func test_in_first_person_you_see_the_name_of_whoever_you_look_at() -> void:
	var main = booted(["--crowd=20", "--style=lowpoly_tropical"])
	arrive(main)
	for i in 40:
		main.driver.step_once()
	main._toggle_fpv()
	frames(main, 0.1)
	var cam: FpvCamera = main.host.pack.fpv
	var eye := Vector2(cam.position.x, cam.position.z)
	var who := ""
	var best := INF
	for id in main.model.occupants:
		# Someone on the ground: a tram's riders are drawn inside it.
		if id == main.player.id or main.model.occupants[id]["view"].get("vehicle") != null:
			continue
		var p: Vector2 = Motion.point(main.model.occupants[id]["view"]["pos"]) / 100.0
		var d := p.distance_to(eye)
		if d > 1.5 and d < best:
			best = d
			who = id
	assert_true(who != "", "someone in view")
	var p := Vector2(main.host.pack.nodes[who].position.x, main.host.pack.nodes[who].position.z)
	var to := p - eye
	cam.yaw = rad_to_deg(atan2(-to.x, -to.y))
	cam.pitch = -rad_to_deg(atan2(FpvCamera.EYE_HEIGHT - 1.2, to.length()))
	cam.look(0, 0)
	frames(main, 1.0 / 60.0)
	assert_eq(main.interaction.fpv_target().get("type"), "person", "the crosshair is on them")
	assert_true(main.host.pack.labels[who].visible, "their name tag shows")
	cam.look(180.0, 0.0)
	frames(main, 1.0 / 60.0)
	assert_true(not main.host.pack.labels[who].visible, "and goes when you look away")
	main.free()


func test_the_pixel_style_stays_overhead_when_set_to() -> void:
	assert_eq(CityArgs.parse(PackedStringArray())["fpv_in_2d"], "offer", "offers by default")
	var main = booted(["--crowd=0", "--style=pixel_art", "--fpv-in-2d=stay"])
	arrive(main)
	main._toggle_fpv()
	assert_true(not main.host.first_person, "stays overhead")
	assert_true(not main.hud.notices.is_empty() and main.hud.notices[-1].find_child("Action", true, false) == null,
		"says why, offers nothing")
	main.free()


func test_camera_fpv_starts_in_first_person() -> void:
	var main = booted(["--crowd=0", "--style=voxel", "--ticks=40", "--camera=fpv"])
	assert_true(main.host.first_person, "--camera=fpv")
	main.free()


func test_esc_in_first_person_frees_the_mouse_and_backspace_cancels_the_walk() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	main._toggle_fpv()
	frames(main, 0.1)
	main.host.pack.fpv.captured = true
	# A walk along the platform it stepped off onto: the way into the
	# square meets the tram's riders walking in at its doors.
	main.player.go_point(Vector2(1600, 1600))
	main.driver.step_once()
	assert_true(main.player.view.get("moving", false), "walking")
	main.router.handle(key(KEY_ESCAPE))
	main.router.handle(key(KEY_ESCAPE, false))
	# Two ticks: a walk can read as still for a single tick on its way.
	main.driver.step_once()
	main.driver.step_once()
	assert_true(not main.host.pack.fpv.captured, "Esc frees the mouse")
	assert_eq(main.stack.top(), main.hud, "and does nothing else: no menu")
	assert_true(main.player.view.get("moving", false), "the walk goes on")
	main.host.pack.fpv.captured = true
	main.router.handle(key(KEY_BACKSPACE))
	main.router.handle(key(KEY_BACKSPACE, false))
	main.driver.step_once()
	assert_true(not main.host.pack.fpv.captured, "Backspace frees the mouse")
	assert_true(not main.player.view.get("moving", false), "and the walk stopped, in one press")
	main.free()


func test_a_camera_preset_leaves_first_person() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical", "--dev"])
	arrive(main)
	main._toggle_fpv()
	frames(main, 0.1)
	main.router.handle(key(KEY_T))
	main.router.handle(key(KEY_T, false))
	frames(main, 0.1)
	assert_true(not main.host.first_person, "T leaves first person")
	assert_eq(main.host.camera_preset, "topdown", "for the top-down view")
	main.free()
