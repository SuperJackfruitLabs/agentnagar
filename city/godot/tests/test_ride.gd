## Riding the tram as the player (tram spec section 5): the HUD's prompts
## through waiting, boarding, riding and stepping off, by keyboard and by
## controller, in at most three presses; the game menu opened while
## waiting (Review Focus 3); the notices for being left behind and for
## each refusal; first person at a window seat; the overhead view following
## the tram; and when the next tram comes (TramTimes).
extends TestSuite


func booted(style := "fake_pack"):
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=" + style]), "res://tests/fixtures" if style == "fake_pack" else "res://styles")
	assert_true(not main.hud.error_label.visible, "booted: " + main.hud.error_label.text)
	main.driver.world.set_checking(true)
	return main


## Steps until the player has ridden in and stands still on the Square's
## platform, then until no tram is by the Square; then, with `settle`, it
## stands there a little over five seconds, after which the platform it
## stepped off onto offers the tram.
func arrive(main, settle := true) -> void:
	for i in 80:
		tick(main)
		if main.player.present and not main.player.view.get("moving", false):
			break
	for i in 40:
		if not tram_by_the_square(main.driver.world):
			break
		tick(main)
	assert_true(main.player.present and not tram_by_the_square(main.driver.world), "arrived, and the trams have left the Square")
	if settle:
		frames(main, main.OFFER_AFTER_S + 0.2)


## One tick, then a few frames drawn of it.
func tick(main) -> void:
	main.driver.step_once()
	for f in 3:
		main._process(1.0 / 60.0)


func frames(main, seconds: float) -> void:
	for f in int(round(seconds * 60.0)):
		main._process(1.0 / 60.0)
		main.driver.advance(1.0 / 60.0)


## The prompt the HUD shows now, or "" with none.
func prompt(main) -> String:
	return main.hud.prompt_label.text if main.hud.prompt.visible else ""


## Whether the prompt shows the act button's glyph.
func prompt_has_button(main) -> bool:
	return main.hud._prompt_key.visible or main.hud._prompt_icon.visible


func space(pressed := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.physical_keycode = KEY_SPACE
	e.pressed = pressed
	return e


func pad_a(pressed := true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_A
	e.pressed = pressed
	return e


func key(code: int, pressed := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e


## Presses of the act button so far (see press).
var presses := 0


## One press and release of the act button, on the keyboard or the pad.
func press(main, controller: bool) -> void:
	presses += 1
	main.router.handle(pad_a() if controller else space())
	main.router.handle(pad_a(false) if controller else space(false))


## The room the player's cell is in, or "".
func room_of_player(main) -> String:
	return main.nav.room_at(main.player.cell)


## Ticks on until `done` holds (up to `most` ticks); whether it did.
func until(main, done: Callable, most := 120) -> bool:
	for i in most:
		if done.call():
			return true
		tick(main)
	return done.call()


func assert_world_consistent(main, label: String) -> void:
	assert_eq(main.driver.world.violations_json(), "[]", label + ": no invariant broken")
	assert_eq(JSON.parse_string(main.driver.world.replay_json())["identical"], true, label + ": the replay is identical")


## Spec success 3 by keyboard: from the Square, one press waits; the tram
## that comes takes the player aboard; it rides to the Avenue and steps
## off there. The prompts say what is happening all the way, and the
## countdown is the tram's true arrival.
func test_a_whole_ride_by_keyboard_waits_boards_rides_and_steps_off_at_the_avenue() -> void:
	var main = booted()
	arrive(main)
	frames(main, 0.05)
	assert_eq(room_of_player(main), "room:tram-stop", "on the Square's north platform")
	assert_eq(prompt(main), "Wait for the tram", "the prompt offers the wait")
	assert_true(prompt_has_button(main), "on the act button")
	presses = 0
	press(main, false)
	tick(main)
	assert_true(main.player.waiting, "waiting after one press")
	assert_eq(main.player.status(), "waiting for the tram", "the status says so")
	# The countdown each tick, then the tick it boarded.
	var shown := {}
	var boarded := -1
	for i in 60:
		if main.player.aboard:
			boarded = main.driver.world.tick()
			break
		var m := RegEx.create_from_string("^Waiting — tram in (\\d+) s$").search(prompt(main))
		assert_true(m != null, "the waiting prompt: " + prompt(main))
		if m != null:
			shown[main.driver.world.tick()] = int(m.get_string(1))
		assert_true(not prompt_has_button(main), "waiting takes no press")
		tick(main)
	assert_true(boarded > 0, "the tram took the player aboard")
	for t in shown:
		assert_eq(shown[t], boarded - t, "at tick %d the countdown is the ticks to the tram" % t)
	assert_eq(main.player.status(), "aboard", "the status says aboard")
	assert_eq(prompt(main), "Get off here", "standing at the Square, the doors still open")
	assert_true(until(main, func(): return main.trams.vehicle(main.player.view.get("vehicle")).get("status") == "running", 20), "the tram runs on")
	assert_eq(prompt(main), "Next: Avenue", "running, the prompt names the next stop")
	assert_true(not prompt_has_button(main), "and asks for nothing")
	assert_true(until(main, func(): return main.player.present, 40), "stepped off")
	assert_eq(room_of_player(main), main.trams.platform_room("line:boulevard", "stop:avenue", 0), "at the Avenue, on its platform")
	assert_true(presses <= 3, "at most three presses")
	# The Avenue is the last stop east: from this platform no tram goes on,
	# and the prompt says where the trams back leave from.
	frames(main, main.OFFER_AFTER_S + 0.2)
	assert_eq(prompt(main), "Trams west leave from the other platform", "the way back is across the tracks")
	assert_true(not prompt_has_button(main), "and asks for nothing")
	assert_world_consistent(main, "the keyboard ride")
	main.free()


## Spec success 3 by controller: with the tram standing at the Square, A
## boards it at once; standing, the prompt offers the way off; it rides to
## the Avenue and steps off there.
func test_a_whole_ride_by_controller_boards_a_standing_tram_and_steps_off_at_the_avenue() -> void:
	var main = booted()
	arrive(main)
	assert_true(until(main, func(): return prompt(main) == "Board", 60), "a tram opens its doors at the platform: " + prompt(main))
	assert_true(not main.player.waiting, "the player never waited")
	presses = 0
	press(main, true)
	tick(main)
	assert_true(main.player.aboard, "A boards it")
	assert_eq(prompt(main), "Get off here", "still standing: A would step off")
	assert_true(until(main, func(): return prompt(main).begins_with("Next: "), 20), "it runs on")
	assert_eq(prompt(main), "Next: Avenue", "to the Avenue")
	assert_true(until(main, func(): return main.player.present, 40), "stepped off")
	assert_eq(room_of_player(main), "room:avenue-stop-north", "at the Avenue")
	assert_true(presses <= 3, "at most three presses")
	assert_world_consistent(main, "the controller ride")
	main.free()


## Aboard a tram still standing at its stop, A steps off again.
func test_get_off_here_steps_off_a_standing_tram() -> void:
	var main = booted()
	arrive(main)
	assert_true(until(main, func(): return prompt(main) == "Board", 60), "a tram stands at the platform")
	press(main, true)
	tick(main)
	assert_true(main.player.aboard, "aboard")
	press(main, true)
	tick(main)
	assert_true(main.player.present and not main.player.aboard, "stepped off")
	assert_eq(room_of_player(main), "room:tram-stop", "back on the Square's platform")
	assert_world_consistent(main, "on and off")
	main.free()


## Review Focus 3: the player waits, opens the game menu, and the tram
## comes while it is open. The player boards; nothing in the world acts
## on the menu's presses; the scene has the player inside the tram; and
## back in play the prompt and the ride carry on.
func test_the_menu_open_while_waiting_and_the_tram_arriving_boards_the_player() -> void:
	var main = booted()
	arrive(main)
	press(main, false)
	tick(main)
	assert_true(main.player.waiting, "waiting")
	main.router.handle(key(KEY_ESCAPE))
	main.router.handle(key(KEY_ESCAPE, false))
	assert_true(main.stack.top() is GameMenu, "the menu is open")
	assert_true(not main.router.world_enabled, "the world takes no input")
	var acted := [0]
	main.router.interact.connect(func(): acted[0] += 1)
	for i in 40:
		if main.player.aboard:
			break
		# Presses while the menu is open never reach the world.
		press(main, i % 2 == 0)
		frames(main, 1.0)
		tick(main)
	assert_eq(acted[0], 0, "no press reached the world")
	assert_true(main.player.aboard, "the tram took the player aboard behind the menu")
	assert_true(main.stack.top() is GameMenu, "the menu is still open")
	var vehicle: String = main.player.view["vehicle"]
	assert_eq(main.host.pack.riders.get(main.player.id), vehicle, "drawn inside its tram")
	assert_eq(main.model.occupants[main.player.id]["room"], null, "in no room")
	assert_true(main.model.vehicles.has(vehicle), "the tram is in the scene")
	assert_eq(main.player.status(), "aboard", "the status says aboard")
	assert_true("aboard" in main._menu.header.text, "and the menu's header: " + main._menu.header.text)
	main.stack.back()
	assert_eq(main.stack.top(), main.hud, "back in play")
	assert_true(until(main, func(): return prompt(main) == "Next: Avenue", 20), "the prompt carries on: " + prompt(main))
	assert_true(until(main, func(): return main.player.present, 40), "and the ride ends at the Avenue")
	assert_world_consistent(main, "the menu while waiting")
	main.free()


## A full tram leaving the player behind, and each refusal of a Board or
## an Alight, has a notice of its own.
func test_being_left_behind_and_each_refusal_have_their_own_notice() -> void:
	var main = booted()
	arrive(main)
	main.hud.dismiss_notices()
	main._notice_events([{"occupant": main.player.id, "kind": {"type": "LeftBehind", "stop": "stop:square", "vehicle": "vehicle:boulevard:east:2"}}])
	var n: int = main.trams.seconds_until("line:boulevard", "stop:square", 0, main.driver.tick_time)
	assert_eq(main.hud.notices.size(), 1, "one notice")
	assert_eq(main.hud.notices[0].get_meta("text"), "The tram is full — next one in %d s" % n, "left behind, with the next tram")
	var texts := {}
	for reason in ["NotOnPlatform", "VehicleFull", "NotYourDirection", "NotStanding", "NotAboard"]:
		main.hud.dismiss_notices()
		main._notice_events([{"occupant": main.player.id, "kind": {"type": "Rejected", "command": "Board", "reason": reason}}])
		assert_eq(main.hud.notices.size(), 1, reason + ": a notice")
		if main.hud.notices.size() == 1:
			texts[main.hud.notices[0].get_meta("text")] = reason
	assert_eq(texts.size(), 5, "five reasons, five notices: " + str(texts.keys()))
	# Other refusals (a steered step the core would not take) are the
	# prediction's to correct, not the player's to read.
	main.hud.dismiss_notices()
	main._notice_events([{"occupant": main.player.id, "kind": {"type": "Rejected", "command": "Steer", "reason": "BlockedStep"}}])
	assert_eq(main.hud.notices.size(), 0, "no notice for a refused step")
	# From the world itself: stepping off a tram the player is not on.
	main.player.alight()
	tick(main)
	assert_true(main.hud.notices.any(func(x): return x.get_meta("text") == main.tram_notice("NotAboard")), "the core's refusal shows")
	main.free()


## First person aboard: the eye sits at the player's slot at a seated eye
## height, looking out on the platform side; the mouse and the right stick
## look round, steering walks nowhere, and it rides with the tram. Leaving
## first person keeps the player aboard, and overhead the view follows the
## tram.
func test_first_person_aboard_sits_at_a_window_and_the_view_follows_the_tram_overhead() -> void:
	var main = booted("lowpoly_tropical")
	arrive(main)
	press(main, false)
	assert_true(until(main, func(): return main.player.aboard, 60), "aboard")
	frames(main, 0.05)
	main.router.handle(key(KEY_F))
	main.router.handle(key(KEY_F, false))
	frames(main, 0.05)
	assert_true(main.host.first_person, "F: first person aboard")
	var cam = main.get_viewport().get_camera_3d()
	assert_true(cam is FpvCamera and cam.seated, "the first-person camera, seated")
	# Alone aboard, the player sits mid-car, not in the front row in the
	# cab's walled nose: a seat with the tram's side glass beside it.
	var spec: Dictionary = main.trams.lines["line:boulevard"]["vehicle"]
	var seat = main.player.view.get("slot")
	var along := CityGeometry.slot_along(spec, seat)
	assert_true(CityGeometry.slot_seated(spec, seat), "a seat, not standing room: slot %s" % str(seat))
	assert_true(along > int(spec["length"]) / 4 and along < int(spec["length"]) * 3 / 4, "mid-car: %d cm behind the front" % along)
	var tram: Node3D = main.host.pack.vehicle_nodes[main.player.view["vehicle"]]
	assert_true(glass_beside(tram, -along / 100.0), "glass beside the seat, %d cm behind the front" % along)
	var front_row := CityGeometry.slot_along(spec, 0)
	assert_true(not glass_beside(tram, -front_row / 100.0), "where the front row sits, %d cm behind the front, the cab is walled" % front_row)
	var body: Node3D = main.host.pack.nodes[main.player.id]
	var sitting: bool = main.host.pack.poses.get(main.player.id) == "sitting"
	var eye := body.global_position + Vector3.UP * (FpvCamera.SEATED_EYE if sitting else FpvCamera.EYE_HEIGHT)
	assert_true(cam.position.distance_to(eye) < 0.01, "at the player's slot, at eye height: %s vs %s" % [cam.position, eye])
	# The eastbound tram's platform is north of it: the view looks north,
	# out of the window.
	var north: int = main.trams.platform_side("line:boulevard", "stop:square", 0, Vector2(0, 2050), Vector2.RIGHT)
	assert_eq(north, 1, "the Square's eastbound platform is on the tram's left")
	assert_true(cam.forward().dot(Vector2(0, -1)) > 0.95, "looking out on the platform side: %s" % cam.forward())
	# The mouse and the right stick look round.
	var yaw: float = cam.yaw
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(40, 0)
	main._input(motion)
	assert_true(absf(cam.yaw - yaw) > 1.0, "the mouse looks round")
	yaw = cam.yaw
	main.router.looking = Vector2(1, 0)
	frames(main, 0.2)
	main.router.looking = Vector2.ZERO
	assert_true(absf(cam.yaw - yaw) > 1.0, "and the right stick")
	# Steering walks nowhere: the player stays in its slot.
	var slot = main.player.view.get("slot")
	main.router.steering = Vector2(0, -1)
	frames(main, 0.5)
	main.router.steering = Vector2.ZERO
	assert_true(main.player.aboard and main.player.view.get("slot") == slot, "still in its slot")
	# It rides with the tram.
	assert_true(until(main, func(): return main.trams.vehicle(main.player.view.get("vehicle")).get("status") == "running", 20), "running")
	var from: Vector3 = cam.position
	frames(main, 1.5)
	body = main.host.pack.nodes[main.player.id]
	sitting = main.host.pack.poses.get(main.player.id) == "sitting"
	eye = body.global_position + Vector3.UP * (FpvCamera.SEATED_EYE if sitting else FpvCamera.EYE_HEIGHT)
	assert_true(cam.position.x > from.x + 3.0, "carried east with the tram")
	assert_true(cam.position.distance_to(eye) < 0.05, "still at the seat")
	# Out of first person: still aboard, and the overhead view follows.
	main.router.handle(key(KEY_F))
	main.router.handle(key(KEY_F, false))
	frames(main, 0.05)
	assert_true(not main.host.first_person and main.player.aboard, "overhead, still aboard")
	var ground_from = main.host.pack.camera_ground_pos()
	var rect: Rect2 = main.get_viewport().get_visible_rect()
	for i in 6:
		frames(main, 0.5)
		var s = main.host.pack.screen_at(main.rider_ground())
		assert_true(s != null and rect.has_point(s), "the player's tram stays in view: %s" % str(s))
	assert_true((main.host.pack.camera_ground_pos() as Vector2).x > (ground_from as Vector2).x + 300.0, "the view has followed it east")
	main.free()


## Whether the side of the tram `tram` (its node: front at its origin, x
## ahead) has glass at `x` metres along it on its left (the platform side
## at the Square), at a seated rider's eye height: some glass triangle of
## its body spans that point, going by the triangle's bounds.
func glass_beside(tram: Node3D, x: float) -> bool:
	var to_tram := tram.global_transform.affine_inverse()
	var eye := float(StylePack.tram_layout()["floor_cm"] + StylePack.tram_layout()["seated_eye_cm"]) / 100.0
	for mi in tram.find_children("*", "MeshInstance3D", true, false):
		if str(mi.name) != "body" or mi.mesh == null:
			continue
		var xform: Transform3D = to_tram * mi.global_transform
		for k in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(k)
			if m == null or not str(m.resource_name).begins_with("glass"):
				continue
			var arrays: Array = mi.mesh.surface_get_arrays(k)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index = arrays[Mesh.ARRAY_INDEX]
			var order: Array = Array(index) if index != null and index.size() > 0 else range(verts.size())
			for t in range(0, order.size() - 2, 3):
				var box := AABB(xform * verts[order[t]], Vector3.ZERO)
				box = box.expand(xform * verts[order[t + 1]]).expand(xform * verts[order[t + 2]])
				if box.end.z < -1.0 and box.position.x <= x and box.end.x >= x and box.position.y <= eye and box.end.y >= eye:
					return true
	return false


## Joining at launch, the player rides in at once: a tram enters on the
## first tick and takes it aboard, the view keeps that tram in sight from
## the portal, and it steps off at the Square within ten ticks.
func test_a_launch_join_rides_in_at_once_with_its_tram_in_view() -> void:
	var main = booted("lowpoly_tropical")
	main.host.set_camera("diagonal")
	var rect: Rect2 = main.get_viewport().get_visible_rect()
	var rode := 0
	for i in 10:
		tick(main)
		frames(main, 0.5)
		if main.player.aboard:
			rode += 1
			var s = main.host.pack.screen_at(main.rider_ground())
			assert_true(s != null and rect.has_point(s), "tick %d: the player's tram in view: %s" % [main.driver.world.tick(), str(s)])
		if main.player.present:
			break
	assert_true(rode > 0, "it rode in")
	assert_true(main.player.present, "and stepped off by tick %d" % main.driver.world.tick())
	assert_eq(room_of_player(main), "room:tram-stop", "at the Square")
	assert_world_consistent(main, "the launch join")
	main.free()


## A player standing still on the rails (its menu open, say) holds a tram
## only five ticks: the world steps it off the tracks, the HUD says so, and
## the tram runs on.
func test_standing_on_the_rails_the_player_is_stepped_off_for_the_tram() -> void:
	var main = booted()
	arrive(main)
	# Steer south off the platform onto the eastbound track (z 1800-2000).
	var id: String = main.player.id
	for i in 10:
		var at := Motion.point(main.player.view["pos"])
		if at.y >= 1850.0:
			break
		var c: Vector2i = main.nav.cell_of(at)
		var cells := []
		for k in range(1, 6):
			var p: Vector2 = main.nav.centre(c + Vector2i(0, k))
			cells.append({"x": int(p.x), "z": int(p.y)})
		main.driver.world.command(JSON.stringify({"type": "Steer", "occupant": id, "cells": cells}))
		tick(main)
	var on := Motion.point(main.player.view["pos"])
	assert_true(on.y >= 1850.0 and on.y <= 1950.0, "on the eastbound track: %s" % on)
	main.router.handle(key(KEY_ESCAPE))
	main.router.handle(key(KEY_ESCAPE, false))
	assert_true(main.stack.top() is GameMenu, "the menu is open")
	main.hud.dismiss_notices()
	var held := -1
	var moved := -1
	for i in 80:
		tick(main)
		for v in main.trams.vehicles:
			if v.get("direction") == "east" and v.get("status") == "held" and held < 0:
				held = main.driver.world.tick()
		if held > 0 and main.trams.vehicles.all(func(v): return v.get("status") != "held"):
			moved = main.driver.world.tick()
			break
	assert_true(held > 0, "a tram was held by the player")
	assert_true(moved > 0 and moved <= held + 5, "and moved on within five ticks (held %d, moved %d)" % [held, moved])
	var off := Motion.point(main.player.view["pos"])
	assert_true(off.y < 1800.0 or off.y > 2000.0, "the player stands off the track: %s" % off)
	assert_true(main.hud.notices.any(func(x): return x.get_meta("text") == main.STEPPED_ASIDE_NOTICE), "the HUD says why")
	assert_world_consistent(main, "stepped aside")
	main.free()


## The map's Go to a tram stop walks to the platform trams leave from, going
## on: at the Avenue, the last stop east, the westbound one.
func test_go_to_a_stop_walks_to_the_platform_with_trams_going_on() -> void:
	var main = booted()
	arrive(main, false)
	main.open_map("facility:avenue-stop")
	main.stack.top().press_go()
	assert_eq(main.player.last_go_room, "room:avenue-stop-south", "the Avenue's westbound platform")
	main.open_map("facility:tram-stop")
	main.stack.top().press_go()
	assert_eq(main.player.last_go_room, "room:tram-stop", "the Square's first platform: trams go on from both")
	main.free()


# ---- When the next tram comes ----

## A line 100 m long west to east, stops at 20 m and 70 m, trams 10 m long
## running 700 cm a tick, one each way every 30 ticks.
func line() -> Dictionary:
	return {"id": "line:test", "points": [{"x": 0, "z": 0}, {"x": 10000, "z": 0}], "tracks": [-100, 100],
		"stops": [{"id": "stop:a", "name": "A", "at": 2000, "platforms": ["room:a-north", "room:a-south"]},
			{"id": "stop:b", "name": "B", "at": 7000, "platforms": ["room:b-north", "room:b-south"]}],
		"timetable": {"headway": 30, "offset": [0, 15], "speed": 28, "dwell": 12},
		"vehicle": {"capacity": 40, "length": 1000, "doors": [200, 500, 800]}}


func times() -> TramTimes:
	var rooms := []
	for r in [["room:a-north", 1000, -400], ["room:a-south", 1000, 150], ["room:b-north", 6000, -400], ["room:b-south", 6000, 150]]:
		rooms.append({"id": r[0], "rect": {"x": r[1], "z": r[2], "w": 2000, "d": 250}})
	return TramTimes.from_layout({"lines": [line()], "city": {"districts": [{"facilities": [{"id": "facility:stops", "rooms": rooms}]}]}})


func test_the_next_tram_comes_by_the_timetable_and_the_trams_on_their_way() -> void:
	var t := times()
	t.observe({"tick": 0})
	# East: enters at 30 with its front at 0, stands with its centre on 20 m
	# (front 25 m): 2500 / 700 is 4 ticks.
	assert_eq(t.ticks_until("line:test", "stop:a", 0), 34, "east to A, by the timetable")
	# West: enters at 15 from 100 m, stands at B (front 65 m) after 5, a
	# dwell there, and at A (front 15 m) after 12 more: 5000 / 700 and
	# 3500 / 700 run as one 8500 / 700, 13 ticks, plus the dwell.
	assert_eq(t.ticks_until("line:test", "stop:a", 1), 15 + 13 + 12, "west to A, standing at B between")
	# A tram on its way: east at 700, running.
	t.observe({"tick": 31, "vehicles": [{"id": "vehicle:test:east:1", "line": "line:test", "direction": "east", "along": 700, "status": "running", "doors_open": false}]})
	assert_eq(t.ticks_until("line:test", "stop:a", 0), 3, "1800 cm to run")
	assert_eq(t.ticks_until("line:test", "stop:b", 0), 10 + 12, "6800 cm to B, 10 ticks, and a dwell at A between")
	# Standing at A with its doors open: now, and a dwell's rest to B.
	t.observe({"tick": 34, "vehicles": [{"id": "vehicle:test:east:1", "line": "line:test", "direction": "east", "along": 2500, "status": "standing", "doors_open": true, "stop": "stop:a"}]})
	assert_eq(t.ticks_until("line:test", "stop:a", 0), 0, "standing there")
	assert_eq(t.standing_open("line:test", "stop:a", 0)["id"], "vehicle:test:east:1", "doors open at A")
	# Standing there with its doors shut takes no one: the next one does.
	t.observe({"tick": 34, "vehicles": [{"id": "vehicle:test:east:1", "line": "line:test", "direction": "east", "along": 2500, "status": "standing", "doors_open": false, "stop": "stop:a"}]})
	assert_eq(t.ticks_until("line:test", "stop:a", 0), 60 - 34 + 4, "doors shut: the next by the timetable")
	t.observe({"tick": 34, "vehicles": [{"id": "vehicle:test:east:1", "line": "line:test", "direction": "east", "along": 2500, "status": "standing", "doors_open": true, "stop": "stop:a"}]})
	t.observe({"tick": 40, "vehicles": [{"id": "vehicle:test:east:1", "line": "line:test", "direction": "east", "along": 2500, "status": "standing", "doors_open": true, "stop": "stop:a"}]})
	assert_eq(t.ticks_until("line:test", "stop:b", 0), 6 + 8, "six ticks of its dwell left, then 5000 cm")
	# Passed A: the next east comes by the timetable, entering at 60.
	t.observe({"tick": 47, "vehicles": [{"id": "vehicle:test:east:1", "line": "line:test", "direction": "east", "along": 3200, "status": "running", "doors_open": false}]})
	assert_eq(t.ticks_until("line:test", "stop:a", 0), 60 - 47 + 4, "the next one")
	# Seconds: at 2x, half; part of the tick gone counts.
	t.speed = 2.0
	assert_eq(t.seconds_until("line:test", "stop:a", 0, 0.5), ceili((17 - 0.5) / 2.0), "real seconds at 2x")
	t.speed = 1.0
	assert_eq(t.card_line("line:test", "stop:a"), "East in 17 s · West in %d s" % t.ticks_until("line:test", "stop:a", 1), "the card's line")
	assert_eq(t.ticks_until("line:test", "stop:nowhere", 0), -1, "an unknown stop")


func test_platforms_stops_and_sides() -> void:
	var t := times()
	assert_eq(t.platform("room:a-south"), {"line": "line:test", "stop": "stop:a", "direction": 1}, "a platform's stop and side")
	assert_eq(t.platform("room:elsewhere"), {}, "not a platform")
	assert_eq(t.stop_among(["room:x", "room:b-north"]), {"line": "line:test", "stop": "stop:b"}, "a place's stop")
	assert_eq(t.stop_name("line:test", "stop:b"), "B", "named")
	assert_eq(t.next_stop({"line": "line:test", "direction": "west", "along": 6000, "status": "running"})["id"], "stop:a", "westbound past B: A next")
	assert_eq(t.next_stop({"line": "line:test", "direction": "east", "along": 1000, "status": "running"})["id"], "stop:a", "eastbound before A: A")
	assert_eq(t.platform_side("line:test", "stop:a", 0, Vector2(2000, -100), Vector2.RIGHT), 1, "east: north platform on the left")
	assert_eq(t.platform_side("line:test", "stop:a", 1, Vector2(2000, 100), Vector2.LEFT), 1, "west: south platform on its left")
	assert_eq(t.platform_side("line:test", "stop:a", 0, Vector2(2000, -100), Vector2.LEFT), -1, "running the other way it is on the right")


# ---- The review's fixes ----

## Waiting in first person, A does nothing: the prompt asks for nothing,
## and acting on the crosshair would walk the player off and end the wait.
func test_waiting_in_first_person_a_does_nothing() -> void:
	var main = booted("lowpoly_tropical")
	arrive(main)
	press(main, false)
	tick(main)
	assert_true(main.player.waiting, "waiting")
	main._toggle_fpv()
	frames(main, 0.05)
	assert_true(main.host.first_person, "first person")
	assert_eq(str(main.interaction.fpv_target().get("type")), "ground", "the crosshair rests on the ground ahead")
	assert_true(prompt(main).begins_with("Waiting — tram in "), "the prompt still says waiting: " + prompt(main))
	press(main, false)
	tick(main)
	tick(main)
	assert_true(main.player.waiting and not main.player.view.get("moving", false), "still waiting, going nowhere")
	main.free()


## A full tram's notice counts to the next tram the player waits for, the
## way it waits, whatever the vehicle's ID says.
func test_being_left_behind_counts_to_the_tram_the_player_waits_for() -> void:
	var main = booted()
	arrive(main)
	press(main, false)
	tick(main)
	assert_true(main.player.waiting, "waiting eastbound")
	var east: int = main.trams.seconds_until("line:boulevard", "stop:square", 0, main.driver.tick_time)
	var west: int = main.trams.seconds_until("line:boulevard", "stop:square", 1, main.driver.tick_time)
	assert_true(east != west, "the two ways differ here (%d, %d)" % [east, west])
	main.hud.dismiss_notices()
	main._notice_events([{"occupant": main.player.id, "kind": {"type": "LeftBehind", "stop": "stop:square", "vehicle": "vehicle:boulevard:west:7"}}])
	assert_eq(main.hud.notices[0].get_meta("text"), "The tram is full — next one in %d s" % east, "the next eastbound")
	main.free()


## The platform the player has just stepped onto from a tram (joining, or
## getting off) offers nothing at first: only after five seconds standing
## still there.
func test_the_platform_just_stepped_onto_offers_the_tram_after_five_seconds() -> void:
	var main = booted()
	arrive(main, false)
	frames(main, 0.1)
	assert_eq(prompt(main), "", "just stepped off: nothing offered")
	# Standing still since it stepped off (arriving drew some frames).
	var stood: float = main._stood_s
	assert_true(stood > 0.0 and stood < main.OFFER_AFTER_S - 0.5, "stood %.2f s so far" % stood)
	frames(main, main.OFFER_AFTER_S - stood - 0.3)
	assert_eq(prompt(main), "", "still nothing just short of five seconds")
	frames(main, 0.5)
	assert_eq(prompt(main), "Wait for the tram", "after five, the tram")
	# Getting off a tram at a platform is stepping onto it too.
	assert_true(until(main, func(): return prompt(main) == "Board", 60), "a tram stands there")
	press(main, true)
	tick(main)
	assert_true(main.player.aboard, "aboard")
	press(main, true)
	tick(main)
	frames(main, 0.1)
	assert_true(main.player.present, "off again")
	assert_eq(prompt(main), "", "just got off: nothing offered, not even Board")
	main.free()


## Walking onto a platform offers the tram at once.
func test_walking_onto_a_platform_offers_the_tram_at_once() -> void:
	var main = booted()
	arrive(main, false)
	var off := Vector2(0, 1100)
	assert_true(main.nav.room_at(main.nav.cell_of(off)) != "room:tram-stop", "a point off the platform")
	main.player.go_point(off)
	assert_true(until(main, func(): return main.nav.room_at(main.player.cell) != "room:tram-stop" and not main.player.view.get("moving", false), 30), "walked off")
	main.player.go_point(Vector2(0, 1600))
	assert_true(until(main, func(): return main.nav.room_at(main.player.cell) == "room:tram-stop" and not main.player.view.get("moving", false), 30), "walked back on")
	frames(main, 0.1)
	assert_true(prompt(main) in ["Wait for the tram", "Board"], "offered at once: " + prompt(main))
	main.free()


## In first person, a crosshair on the ground off the platform (or on a
## building) is what A does, not the wait; looking down at the platform,
## the wait is.
func test_in_first_person_a_target_off_the_platform_beats_the_wait() -> void:
	var main = booted("lowpoly_tropical")
	arrive(main)
	main._toggle_fpv()
	frames(main, 0.05)
	var fpv: FpvCamera = main.host.pack.fpv
	fpv.look(0.0, -70.0 - fpv.pitch)
	frames(main, 0.05)
	assert_eq(prompt(main), "Wait for the tram", "looking down at the platform: " + prompt(main))
	fpv.look(0.0, -8.0 - fpv.pitch)
	frames(main, 0.05)
	var hit: Dictionary = main.interaction.fpv_target()
	assert_true(hit.get("type") in ["ground", "building"], "the crosshair is off the platform: %s %s" % [hit.get("type"), hit.get("target")])
	assert_true(prompt(main) in ["Walk here", "Go in"], "the target's prompt: " + prompt(main))
	press(main, false)
	tick(main)
	tick(main)
	assert_true(not main.player.waiting, "A did not wait")
	assert_true(main.player.following or main.player.view.get("moving", false), "it walks there")
	main.free()


## A player sat on a tram shelter's bench (a perch) sees Board once a tram
## stands at the platform with its doors open, over Stand up, and boarding
## ends the sit. A reader is offered Board first too, and so is a player
## merely offered a perch or a display; a room seat keeps Stand up first
## (a seated player is offered no tram at all). While the doors are shut
## the use comes first.
func test_sat_at_a_shelter_board_comes_first_once_the_doors_open() -> void:
	var main = booted()
	arrive(main)
	var shelter := {}
	for t in main.interact.things:
		if t["kind"] == "tram-shelter" and main.nav.room_at(main.nav.cell_of(t["pos"])) == "room:tram-stop":
			if shelter.is_empty() or t["pos"].distance_to(main.player.shown) < shelter["pos"].distance_to(main.player.shown):
				shelter = t
	assert_true(not shelter.is_empty(), "a shelter on the Square's north platform")
	var sit: Dictionary = shelter["anchors"].filter(func(a): return a["type"] == "sit")[0]
	main.interaction._act(main.interact.candidate_of(shelter, sit["index"]), 0)
	assert_true(until(main, func(): return main.player.view.get("using") != null, 60), "sat on the bench")
	var using: Dictionary = main.player.view["using"]
	assert_eq([using["target"], using["capability"], int(using["anchor"])], [shelter["target"], "sit", sit["index"]], "on its sit anchor")
	assert_true(main.player.view.get("seat") == null, "a perch, not a room seat")
	if main.tram_prompt().get("text") != "Board":
		frames(main, 0.05)
		assert_eq(prompt(main), "Stand up", "the doors shut: Stand up first")
	assert_true(until(main, func(): return prompt(main) == "Board", 120), "a tram opens its doors: Board, over Stand up (%s)" % prompt(main))
	# Offered, not yet under way, a perch or a display yields to the open
	# doors as well; with the doors shut it comes first.
	var bench: Dictionary = main.interact.candidate_of(shelter, sit["index"])
	var board: Dictionary = main.interact.candidate_of(main.interact.things.filter(func(t): return t["target"] == "placement:square-noticeboard")[0], 0)
	for offered in [bench, board]:
		assert_true(main.interaction._tram_first({"text": "Board", "act": "board"}, offered), "%s offered, the doors open: Board first" % offered["target"])
		assert_true(not main.interaction._tram_first({"text": "Wait for the tram", "act": "board"}, offered), "%s offered, the doors shut: it comes first" % offered["target"])
	# A reader, on the same platform with the doors open: Board first too.
	var view: Dictionary = main.player.view
	var read := {"target": "placement:square-noticeboard", "capability": "read", "anchor": 0}
	main.player.view = view.merged({"using": read}, true)
	assert_eq(main.interaction.choice()["text"], "Board", "reading: Board first")
	# A room seat keeps Stand up first.
	var seat: String = main.nav.seats[0]["id"]
	main.player.view = view.merged({"seat": seat, "using": {"target": seat, "capability": "sit", "anchor": 0}}, true)
	assert_eq(main.interaction.choice()["text"], "Stand up", "a room seat: Stand up first")
	main.player.view = view
	press(main, false)
	tick(main)
	assert_true(main.player.aboard, "A boards the tram")
	assert_true(main.player.view.get("using") == null, "boarding ends the sit")
	assert_world_consistent(main, "sitting, then boarding")
	main.free()
