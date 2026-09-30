## The player gate: the local player's route through the district in every
## style — click-walk from the tram stop to the Guild hall, queue because
## it is full, get in and sit at a free desk, stand and steer in first
## person with WASD and then a stick, cross the square into the library,
## and switch styles at the hall and at the library — with every invariant
## held on every tick and the input log replaying the session byte for
## byte. Repeated as an observer, no public projection ever holds them.
extends TestSuite


func booted(args: Array):
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(args))
	assert_true(not main.hud.error_label.visible, "booted: " + main.hud.error_label.text)
	main.driver.world.set_checking(true)
	return main


func public_ids(main) -> Array:
	return Player.views_of(JSON.parse_string(main.driver.world.project_json("public"))).map(func(v): return v["id"])


## Runs the client for `seconds` of 60 fps frames, as the engine would.
func frames(main, seconds: float) -> void:
	for f in int(round(seconds * 60.0)):
		main._process(1.0 / 60.0)
		main.driver.advance(1.0 / 60.0)


func until(main, ticks: int, done: Callable) -> bool:
	for i in ticks:
		if done.call():
			return true
		main.driver.step_once()
	return done.call()


func room_of(main) -> String:
	return main.nav.room_at(main.player.cell)


func key(code: int, pressed := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e


func stick(y: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_Y
	e.axis_value = y
	return e


## Every pack draws the avatar where the player is.
func switch_everywhere(main, where: String) -> void:
	for dir in main.styles:
		main._activate(dir)
		frames(main, 0.1)
		assert_true(main.host.pack.nodes.has(main.player.id), "%s: %s draws the avatar" % [where, dir.get_file()])
	for dir in main.styles:
		if dir.get_file() == "lowpoly_tropical":
			main._activate(dir)


func held(main) -> void:
	assert_eq(JSON.parse_string(main.driver.world.violations_json()), [], "every invariant held to tick %d" % main.driver.world.tick())


func test_the_players_route_through_every_style() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	assert_true(until(main, 80, func(): return main.player.present and not main.player.view.get("moving", false)), "arrived")
	# The player rides in on east:1, the first tram to reach the Square,
	# and steps off at 35.
	assert_eq(room_of(main), "room:tram-stop", "at the tram stop")
	# The Guild hall's workshop fills, with a queue, by about tick 72 at
	# this seed: the story's people ride in first.
	var full := until(main, 80, func():
		for room in JSON.parse_string(main.driver.world.project_json("public"))["rooms"]:
			if room["id"] == "room:workshop" and room["occupants"].size() >= room["capacity"] and room["waiting"].size() > 0:
				return true
		return false)
	assert_true(full, "the workshop is full, with a queue")

	# Click-walk to the hall.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = main.host.pack.screen_at(Vector2(-2600, -600))
	main.router.handle(click)
	# Lambdas capture locals by value, so the flag lives in a dictionary.
	var seen := {"queued": false}
	var inside := until(main, 260, func():
		if main.player.view.get("queue") != null:
			seen["queued"] = true
		return room_of(main) == "room:workshop" and main.player.view.get("queue") == null and seen["queued"])
	assert_true(seen["queued"], "it queued, the hall being full")
	assert_true(inside, "and got in")
	held(main)

	# Sit at a free desk.
	var desk := ""
	for s in main.nav.seats:
		if s["room"] == "room:workshop" and not main.player.unavailable_seats().has(s["id"]):
			desk = s["id"]
	assert_true(desk != "", "a free desk")
	main.player.go_seat(desk)
	assert_true(until(main, 60, func(): return main.player.view.get("seat") == desk), "sitting at " + desk)
	switch_everywhere(main, "at the hall")
	held(main)

	# Stand and steer in first person, with WASD and then a stick.
	main._toggle_fpv()
	frames(main, 0.1)
	assert_true(main.host.first_person, "first person")
	var from: Vector2 = main.player.shown
	main.router.handle(key(KEY_W))
	frames(main, 3.0)
	main.router.handle(key(KEY_W, false))
	frames(main, 1.0)
	assert_true(main.player.view.get("seat") == null, "W stood up")
	var walked: Vector2 = main.player.shown
	assert_true(walked.distance_to(from) > 50.0, "and walked: %s → %s" % [from, walked])
	main.host.pack.fpv.look(180.0, 0.0)
	main.router.handle(stick(-1.0))
	frames(main, 3.0)
	main.router.handle(stick(0.0))
	frames(main, 1.0)
	assert_true(main.player.shown.distance_to(walked) > 50.0, "the stick walks too")
	main._toggle_fpv()
	held(main)

	# Across the square into the library.
	main.player.go_room("room:reading")
	assert_true(until(main, 240, func(): return room_of(main) == "room:reading" and not main.player.view.get("moving", false)), "into the library")
	frames(main, 0.1)
	assert_true(main.host.pack.is_open("facility:library"), "the library opens round the avatar")
	switch_everywhere(main, "at the library")
	held(main)

	var replay: Dictionary = JSON.parse_string(main.driver.world.replay_json())
	assert_eq(replay.get("identical"), true, "the input log replays the session byte for byte: %s" % replay)
	main.free()


func test_an_observer_never_shows_in_public() -> void:
	var main = booted(["--crowd=20", "--style=voxel", "--as=observer"])
	assert_eq(main.player.id, "person:observer-1", "joined as an observer")
	assert_true(main.hud.status_text.begins_with("Observer"), "marked observer: " + main.hud.status_text)
	var seen_public := false
	for t in 120:
		if t == 30:
			main.player.go_room("room:workshop")
		if t == 80:
			main.player.go_room("room:reading")
		main.driver.step_once()
		if main.player.id in public_ids(main):
			seen_public = true
	assert_true(main.player.present, "the observer walked the district")
	assert_true(not seen_public, "no public projection held the observer")
	held(main)
	var replay: Dictionary = JSON.parse_string(main.driver.world.replay_json())
	assert_eq(replay.get("identical"), true, "replayed byte for byte: %s" % replay)
	main.free()
