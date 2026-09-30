## The local player in the client: joining, the "you" marker in every pack,
## the HUD's status line, steering and clicking through the router, and
## changing look.
extends TestSuite

const FAKE_ROOT := "res://tests/fixtures"


func booted(args: Array, styles_root := "res://styles"):
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(args), styles_root)
	assert_true(not main.hud.error_label.visible, "booted: " + main.hud.error_label.text)
	return main


func public_ids(main) -> Array:
	return Player.views_of(JSON.parse_string(main.driver.world.project_json("public"))).map(func(v): return v["id"])


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


## Runs the client for `seconds` of 60 fps frames, as the engine would.
func frames(main, seconds: float) -> void:
	for f in int(round(seconds * 60.0)):
		main._process(1.0 / 60.0)
		main.driver.advance(1.0 / 60.0)


static func key(code: int, pressed := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e


func test_launch_options_choose_who_joins_and_their_look() -> void:
	var o := CityArgs.parse(PackedStringArray())
	assert_eq(o["as"], "registered", "a registered person by default")
	assert_eq(o["look"], "0,0", "with the first look")
	o = CityArgs.parse(PackedStringArray(["--as=observer", "--look=3,1"]))
	assert_eq([o["as"], o["look"]], ["observer", "3,1"], "--as and --look")
	assert_eq(CityArgs.parse(PackedStringArray(["--as=none"]))["as"], "none", "or nobody")


func test_a_registered_join_shows_in_public_with_a_you_marker() -> void:
	var main = booted(["--crowd=0", "--style=fake_pack"], FAKE_ROOT)
	assert_eq(main.player.id, "person:you", "joined as the registered player")
	assert_eq(main.driver.viewer, "person:you", "seeing through its own eyes")
	assert_eq(main.dev.viewer_ids[0], "person:you", "offered first among the viewers")
	arrive(main)
	assert_true("person:you" in public_ids(main), "everyone can see a registered player")
	assert_eq(main.host.pack.player_id, "person:you", "the pack knows which occupant is you")
	assert_true(main.host.pack.player_marker() != null, "and marks it")
	assert_true(main.hud.status_text != "", "the HUD knows the player")
	assert_true(main.hud.status_text.begins_with("Visitor"), "labelled honestly: " + main.hud.status_text)
	assert_true(main.hud.fixture.is_visible_in_tree(), "under the fixture banner")
	main.free()


func test_an_observer_is_marked_in_the_hud_and_absent_from_public() -> void:
	var main = booted(["--crowd=0", "--style=fake_pack", "--as=observer"], FAKE_ROOT)
	assert_eq(main.player.id, "person:observer-1", "joined as the observer")
	# Through the ride in (it steps off at the Square at 35) and after.
	for i in 40:
		main.driver.step_once()
		assert_true(not "person:observer-1" in public_ids(main), "tick %d: never in public" % i)
	assert_true(main.player.present, "yet present to itself")
	assert_true(main.host.pack.nodes.has("person:observer-1"), "and drawn in its own view")
	assert_true(main.hud.status_text.begins_with("Observer"), "the HUD says so: " + main.hud.status_text)
	main.free()


func test_nobody_joins_with_as_none() -> void:
	var main = booted(["--crowd=0", "--style=fake_pack", "--as=none"], FAKE_ROOT)
	assert_eq(main.player.id, "", "no player")
	assert_eq(main.driver.viewer, "public", "the public view")
	assert_eq(main.hud.status_text, "", "no player line")
	main.free()


func test_the_hud_status_follows_the_queue() -> void:
	var main = booted(["--crowd=0", "--style=fake_pack"], FAKE_ROOT)
	arrive(main)
	# At this seed the Guild hall's workshop fills by about tick 35.
	var full := false
	for i in 60:
		main.driver.step_once()
		var p: Dictionary = JSON.parse_string(main.driver.world.project_json("public"))
		for room in p["rooms"]:
			if room["id"] == "room:workshop" and room["occupants"].size() >= room["capacity"] and room["waiting"].size() > 0:
				full = true
		if full:
			break
	assert_true(full, "the workshop is full, with a queue")
	var inside := Vector2(-2600, -600)
	assert_eq(main.player.go_point(inside).get("ok"), true, "Go into the Guild hall's workshop")
	var seen := []
	for i in 200:
		main.driver.step_once()
		var line: String = main.hud.status_text
		if seen.is_empty() or seen[-1] != line:
			seen.append(line)
		if main.player.view.get("queue") == null and seen.any(func(s): return "queued" in s) \
				and main.nav.room_at(main.player.cell) == "room:workshop":
			break
	var queued := seen.filter(func(s): return "queued at" in s)
	assert_true(not queued.is_empty(), "it queued: %s" % str(seen))
	assert_true(seen.has("Visitor · walking"), "it walked there first")
	var places := queued.map(func(s): return int(s.get_slice("queued at ", 1)))
	for k in range(1, places.size()):
		assert_true(places[k] < places[k - 1], "the place counts down: %s" % str(places))
	assert_eq(main.nav.room_at(main.player.cell), "room:workshop", "and it got in: %s" % str(seen))
	main.free()


func test_steering_moves_the_avatar_at_once_and_the_core_follows() -> void:
	var main = booted(["--crowd=0", "--style=fake_pack"], FAKE_ROOT)
	arrive(main)
	var start: Vector2 = main.host.pack.places["person:you"]
	var at: Vector2i = main.player.cell
	main.router.handle(key(KEY_D))
	frames(main, 0.1)
	assert_true(main.host.pack.places["person:you"].x > start.x, "the avatar moves east before the core has heard")
	frames(main, 1.0)
	main.router.handle(key(KEY_D, false))
	frames(main, 1.0)
	var core: Vector2i = main.nav.cell_of(Motion.point(main.player.view["pos"]))
	assert_true(main.player.cell.x > at.x + 4, "it walked east: %s to %s" % [at, main.player.cell])
	assert_eq(core, main.player.cell, "the core has it where the avatar is")
	assert_true(main.host.pack.places["person:you"].is_equal_approx(main.nav.centre(core)), "drawn there")
	main.free()


func test_a_click_on_the_ground_walks_there_in_every_pack() -> void:
	var main = booted(["--crowd=0"])
	arrive(main)
	var target: Vector2 = main.nav.centre(main.player.cell + Vector2i(-16, 0))
	for dir in main.styles:
		main._activate(dir)
		await runner.process_frame
		var screen = main.host.pack.screen_at(target)
		assert_true(screen != null, dir + " shows the target on screen")
		var ground = main.host.pack.ground_at(screen)
		assert_true(ground != null and ground.distance_to(target) < 13.0, dir + " finds the ground under it: %s" % str(ground))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = main.host.pack.screen_at(target)
	main.router.handle(click)
	for i in 10:
		main.driver.step_once()
	assert_true(Motion.point(main.player.view["pos"]).distance_to(target) < 40.0, "a Go walked it to the click")
	main.free()


func test_steering_goes_where_the_screen_says() -> void:
	var main = booted(["--crowd=0"])
	await runner.process_frame
	for dir in main.styles:
		main._activate(dir)
		for preset in ["topdown", "diagonal", "street"]:
			main.host.set_camera(preset)
			await runner.process_frame
			var pack: StylePack = main.host.pack
			# Three-quarters down the screen: ground in every preset, the
			# eye-level street view included (its centre is the horizon).
			var view: Vector2 = main.get_viewport().get_visible_rect().size
			var mid := Vector2(view.x / 2.0, view.y * 0.75)
			for screen_dir in [Vector2(1, 0), Vector2(0, -1)]:
				var want = pack.ground_at(mid + screen_dir * 2.0)
				var from = pack.ground_at(mid)
				assert_true(want != null and from != null, "%s %s: the probe point is on the ground" % [dir, preset])
				var got: Vector2 = pack.ground_direction(screen_dir)
				assert_true(got.dot((want - from).normalized()) > 0.99, "%s %s: %s on screen steers %s, toward %s" % [dir, preset, screen_dir, got, (want - from).normalized()])
	main.free()


func test_l_changes_look_by_joining_again() -> void:
	var main = booted(["--crowd=0", "--style=fake_pack", "--look=2,3"], FAKE_ROOT)
	arrive(main)
	assert_eq(main.player.view["appearance"], {"outfit": "2", "hair": "3"}, "the chosen look")
	main.router.handle(key(KEY_L))
	assert_true("changing look" in main.hud.status_text, "the HUD says what is happening")
	var back := false
	for i in 150:
		main.driver.step_once()
		if main.player.present and main.player.look == "3,0" and not main.player.view.is_empty():
			back = true
			break
	assert_true(back, "it left and joined again")
	assert_eq(main.player.view["appearance"], {"outfit": "3", "hair": "0"}, "with the next look")
	assert_true(main.host.pack.player_marker() != null, "still marked as you")
	main.free()


func test_every_pack_marks_you() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	var m := SceneModel.new()
	var you := {"id": "person:you", "kind": {"type": "Human", "tier": "Registered"}, "display_name": "You",
		"role": "", "badge": null, "appearance": {"outfit": "1", "hair": "2"}, "seat": null,
		"presence": {"headline": "Present"}, "pos": {"x": 0, "z": 1500}}
	m.apply({"rooms": [{"id": "room:tram-stop", "occupants": [you], "waiting": []}], "in_transit": [], "time_of_day": 600})
	h.set_avatar("person:you")
	for dir in h.discover():
		assert_true(h.activate(dir, JSON.parse_string(CityPaths.district_manifest()), m, Motion.new(), 0.0), dir + " builds")
		var marker = h.pack.player_marker()
		assert_true(marker != null, dir + " marks you")
		assert_true(marker.get_parent() == h.pack.nodes["person:you"], dir + ": the marker moves with the avatar")
		assert_eq(h.pack.views["person:you"]["appearance"].get("palette"), "1", dir + " dresses you in your outfit")
		h.pack.set_player("")
		assert_true(h.pack.player_marker() == null, dir + " can unmark you")
		h.pack.set_player("person:you")
		assert_true(h.pack.player_marker() != null, dir + " and mark you again")
	h.free()


func test_a_on_the_pad_sits_at_the_seat_ahead_and_stands_again() -> void:
	var main = booted(["--crowd=0", "--style=fake_pack"], FAKE_ROOT)
	arrive(main)
	var free: Array = main.nav.seats.filter(func(s): return s["room"] == "room:plaza" \
		and not main.player.unavailable_seats().has(s["id"]))
	assert_true(not free.is_empty(), "a free bench in the square")
	var bench: Dictionary = free[0]
	main.player.go_point(bench["pos"])
	for i in 40:
		main.driver.step_once()
	assert_true(Motion.point(main.player.view["pos"]).distance_to(bench["pos"]) <= 60.0, "it stands by the bench")
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	main.router.handle(a)
	for i in 5:
		main.driver.step_once()
	assert_eq(main.player.view.get("seat"), bench["id"], "A sits at it")
	assert_true(main.hud.status_text.ends_with("sitting"), "the HUD says so: " + main.hud.status_text)
	a.pressed = false
	main.router.handle(a)
	a.pressed = true
	main.router.handle(a)
	main.driver.step_once()
	assert_eq(main.player.view.get("seat"), null, "A again stands up")
	assert_true(main.hud.status_text.ends_with("standing"), "the HUD says so: " + main.hud.status_text)
	main.free()


## A click walk animates exactly while the avatar is shown moving: no
## gliding on without steps at either end, and the stride matches the pace.
func test_a_click_walk_steps_while_it_moves_and_only_then() -> void:
	var main = booted(["--crowd=0"])
	arrive(main)
	frames(main, 1.0)
	main.player.go_point(main.nav.centre(main.player.cell + Vector2i(-16, 0)))
	var last: Vector2 = main.player.shown
	var glides := 0
	var treads := 0
	var walked := 0
	var was_walking := false
	var stride := 0.0
	for f in 60 * 6:
		frames(main, 1.0 / 60.0)
		# The move into this frame's position was drawn with the last
		# frame's pose and stride.
		var moved: float = (main.player.shown - last).length()
		last = main.player.shown
		if moved > 0.5 and not was_walking:
			glides += 1
		if was_walking and moved < 0.1:
			treads += 1
		if was_walking:
			walked += 1
			assert_true(absf(stride - moved * 60.0) < 20.0 or moved < 0.1, "stride %.0f cm/s matches the %.0f cm/s shown" % [stride, moved * 60.0])
		was_walking = main.host.pack.poses.get(main.player.id) == "walking"
		stride = main.host.pack.strides.get(main.player.id, 0.0)
	assert_true(walked > 60, "it walked (%d frames)" % walked)
	assert_eq(glides, 0, "frames moving without walking")
	assert_true(treads <= 2, "frames walking without moving: %d" % treads)
	main.free()


## Clicking just after steering walks on from where the avatar is shown:
## the steps already taken are kept, never snatched back.
func test_a_click_after_steering_never_pulls_the_avatar_back() -> void:
	var main = booted(["--crowd=0"])
	arrive(main)
	frames(main, 1.0)
	var start: Vector2 = main.player.shown
	# 3 m west and 1 m north: south of the tram stop are the tracks now,
	# where no one is set down.
	var target: Vector2 = main.nav.centre(main.player.cell + Vector2i(-12, -4))
	var last: Vector2 = main.player.shown
	var worst := 0.0
	for f in 60 * 8:
		main.router.steering = Vector2(1, 0) if f < 90 else Vector2.ZERO
		if f == 90:
			main._on_walk_to(main.host.pack.screen_at(target))
		frames(main, 1.0 / 60.0)
		worst = maxf(worst, (main.player.shown - last).length())
		last = main.player.shown
	assert_true(worst < 4.0, "no frame jumps (worst %.1f cm)" % worst)
	assert_true(main.player.shown.distance_to(target) < 30.0, "it got there: %s from %s" % [main.player.shown, target])
	assert_true(start.distance_to(target) > 200.0, "a real walk")
	main.free()


## Steering walks without a break in the walk cycle, tick after tick.
func test_steering_walks_without_pausing_at_tick_boundaries() -> void:
	var main = booted(["--crowd=0"])
	arrive(main)
	frames(main, 1.0)
	main.router.steering = Vector2(1, 0)
	frames(main, 0.5)
	var breaks := 0
	for f in 60 * 3:
		frames(main, 1.0 / 60.0)
		if main.host.pack.poses.get(main.player.id) != "walking":
			breaks += 1
	assert_eq(breaks, 0, "frames not walking while steered on open ground")
	main.free()


## Esc cancels a Go even while it waits for the steered steps to be sent.
func test_esc_cancels_a_go_still_waiting_on_steered_steps() -> void:
	var main = booted(["--crowd=0"])
	arrive(main)
	frames(main, 1.0)
	main.router.steering = Vector2(1, 0)
	frames(main, 0.5)
	main.router.steering = Vector2.ZERO
	var target: Vector2 = main.nav.centre(main.player.cell + Vector2i(-12, 4))
	main._on_walk_to(main.host.pack.screen_at(target))
	main._cancel()
	frames(main, 4.0)
	assert_true(main.player.shown.distance_to(target) > 200.0, "it stayed put: %s" % main.player.shown)
	main.free()


## Overhead, the view follows a walking avatar: it never walks off the
## screen, in 3D or in 2D, however far it goes.
func test_the_view_keeps_a_walking_avatar_on_screen() -> void:
	var was: Vector2i = runner.root.size
	runner.root.size = Vector2i(1600, 900)
	for style in ["lowpoly_tropical", "pixel_art"]:
		var main = booted(["--crowd=0", "--style=" + style])
		arrive(main)
		frames(main, 1.0)
		# Start with the avatar in the middle of the view: the district's
		# frame, which it used to start near, is centred 16 m east of the
		# square now that it reaches the Avenue stop.
		main.host.pack.fly_to(main.player.shown, 0.0)
		await runner.process_frame
		# Close in, as a player watching their avatar would.
		for k in 12:
			main.host.pack.zoom_step(1)
		frames(main, 1.0)
		var rect: Rect2 = main.get_viewport().get_visible_rect()
		var start: Vector2 = main.player.shown
		main.router.steering = Vector2(1, 0)
		var off := 0
		for f in 60 * 25:
			frames(main, 1.0 / 60.0)
			var s = main.host.pack.screen_at(main.player.shown)
			if s == null or not rect.grow(-8.0).has_point(s):
				off += 1
		main.router.steering = Vector2.ZERO
		assert_true(main.player.shown.distance_to(start) > 1500.0, style + ": it walked a long way (%.0f cm)" % main.player.shown.distance_to(start))
		assert_eq(off, 0, style + ": frames with the avatar off screen")
		main.free()
	runner.root.size = was
