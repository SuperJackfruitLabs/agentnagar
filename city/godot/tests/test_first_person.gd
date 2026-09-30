## First-person view in the running client: F enters and leaves it in the
## 3D styles, the eye rides the avatar, the crosshair picks what `interact`
## acts on, and the pixel style declines with a way to a 3D one.
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


func f_key() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_F
	e.physical_keycode = KEY_F
	e.pressed = true
	return e


func space_key() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.physical_keycode = KEY_SPACE
	e.pressed = true
	return e


func release(e: InputEventKey) -> InputEventKey:
	var up: InputEventKey = e.duplicate()
	up.pressed = false
	return up


func test_f_enters_and_leaves_first_person_at_eye_height() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	main.router.handle(f_key())
	main.router.handle(release(f_key()))
	frames(main, 0.1)
	assert_true(main.host.first_person, "F: first person")
	var acted := [0]
	main.router.interact.connect(func(): acted[0] += 1)
	main.router.handle(space_key())
	main.router.handle(release(space_key()))
	assert_eq(acted[0], 1, "Space interacts")
	var cam = main.get_viewport().get_camera_3d()
	assert_true(cam is FpvCamera, "the first-person camera is current")
	assert_true(absf(cam.position.y - FpvCamera.EYE_HEIGHT) < 0.0001, "at eye height")
	var at: Vector2 = main.player.shown / 100.0
	assert_true(Vector2(cam.position.x, cam.position.z).distance_to(at) < 0.01, "over the avatar")
	assert_true(main.hud.crosshair.visible, "with a crosshair")
	# Walk forward a while: the eye stays at eye height over the avatar.
	main.router.steering = Vector2(0, -1)
	frames(main, 1.5)
	main.router.steering = Vector2.ZERO
	cam = main.get_viewport().get_camera_3d()
	assert_true(absf(cam.position.y - FpvCamera.EYE_HEIGHT) < 0.0001, "still at eye height after walking")
	main.router.handle(f_key())
	main.router.handle(release(f_key()))
	frames(main, 0.1)
	assert_true(not main.host.first_person, "F again: back overhead")
	assert_true(not (main.get_viewport().get_camera_3d() is FpvCamera), "the overhead camera is back")
	assert_true(not main.hud.crosshair.visible, "no crosshair")
	main.free()


func test_fpv_launch_option_starts_in_first_person() -> void:
	assert_eq(CityArgs.parse(PackedStringArray(["--fpv"]))["fpv"], true, "--fpv")
	var main = booted(["--crowd=0", "--style=voxel", "--ticks=40", "--fpv"])
	assert_true(main.host.first_person, "starts in first person once the ticks have run")
	main.free()


func test_the_avatar_body_is_hidden_but_casts_its_shadow() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	main._toggle_fpv()
	frames(main, 0.1)
	var body: Node = main.host.pack.nodes[main.player.id]
	var parts: Array = body.find_children("*", "GeometryInstance3D", true, false)
	assert_true(not parts.is_empty(), "the avatar has meshes")
	for g in parts:
		if not (g is MeshInstance3D):
			continue
		assert_eq(g.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "%s only casts a shadow" % g.name)
	main._toggle_fpv()
	frames(main, 0.1)
	for g in body.find_children("*", "GeometryInstance3D", true, false):
		if g is MeshInstance3D:
			assert_eq(g.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "%s shows again" % g.name)
	main.free()


func test_the_crosshair_picks_a_seat_it_is_aimed_at() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	# The nearest free seat, 2 m off: the crosshair reaches 3 m.
	var near: Vector2 = main.player.shown
	var best: Dictionary = {}
	for s in main.nav.seats:
		var d: float = s["pos"].distance_to(near)
		if best.is_empty() or d < best["d"]:
			best = {"id": s["id"], "pos": s["pos"] / 100.0, "d": d}
	main.player.go_point(best["pos"] * 100.0 + (near - best["pos"] * 100.0).normalized() * 200.0)
	for i in 60:
		main.driver.step_once()
		frames(main, 0.05)
		if not main.player.view.get("moving", false) and not main.player.following:
			break
	main._toggle_fpv()
	frames(main, 0.1)
	var cam: FpvCamera = main.host.pack.fpv
	var eye := Vector2(cam.position.x, cam.position.z)
	# The view turned onto it.
	var to: Vector2 = best["pos"] - eye
	assert_true(to.length() < Interact.FIRST_PERSON_REACH_M, "within reach: %.1f m" % to.length())
	cam.yaw = rad_to_deg(atan2(-to.x, -to.y))
	cam.pitch = -rad_to_deg(atan2(FpvCamera.EYE_HEIGHT, to.length()))
	cam.look(0, 0)
	frames(main, 1.0 / 60.0)
	var hit: Dictionary = main.interaction.fpv_target()
	assert_eq(hit["type"], "seat", "aimed at a seat: %s" % hit.get("target"))
	assert_eq(hit["target"], best["id"], "that seat")
	assert_true(main.hud.prompt.visible and main.hud.prompt_label.text.begins_with("Sit"), "the prompt says what A does: " + main.hud.prompt_label.text)
	main.free()


## Aimed at a building whose room "Go in" enters is closed to the player
## (full, or queued for by others), the prompt says "Full" beside "Go in".
func test_go_in_says_full_at_a_full_room() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	# 3 m out from the commons' door in the guild hall's east front, at
	# (-18, 6) m, facing it and a little down.
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
	var hit: Dictionary = main.interaction.fpv_target()
	assert_eq([hit.get("type"), hit.get("target")], ["building", "room:commons"], "the crosshair on the commons' door")
	main.nav.set_closed([])
	assert_eq(main.interaction.choice()["text"], "Go in", "open")
	main.nav.set_closed(["room:commons"])
	assert_eq(main.interaction.choice()["text"], "Go in · Full", "full")
	main._update_prompt()
	assert_eq(main.hud.prompt_label.text, "Go in · Full", "on the HUD")
	main.free()


## "Go in" enters the room behind the door nearest the crosshair's hit on
## the building, within 3 m of its span; only with no door that near does
## it fall back to the building's first room.
func test_go_in_enters_the_room_behind_the_door_faced() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	main._toggle_fpv()
	frames(main, 0.05)
	var hall := ""
	for b in main.interact.buildings:
		if "room:workshop" in b["rooms"]:
			hall = b["id"]
	assert_true(hall != "", "the guild hall")
	# Its east front: the workshop's door at z -6 m, the commons' at +6 m,
	# each 2 m wide.
	for case in [[Vector2(-18, 6), "room:commons", "the commons' door"], [Vector2(-18, 8.5), "room:commons", "beside the commons' door"],
			[Vector2(-18, -6), "room:workshop", "the workshop's door"], [Vector2(-18, -3.5), "room:workshop", "beside the workshop's door"],
			[Vector2(-18, 3.5), "room:commons", "nearer the commons' door"], [Vector2(-18, 0), "room:workshop", "no door within 3 m: the first room"]]:
		assert_eq(main.interact.go_in_room({"kind": "building", "id": hall, "point": case[0]}), case[1], case[2])
	main.free()


## Inside a building, "Walk here" walks to the building's own floor
## nearest the crosshair, never to the ground beyond its walls: in the
## workshop, facing the commons' doorway, it walks into the commons.
func test_inside_walk_here_stays_on_the_building_s_floor() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	main.player.go_point(Vector2(-2600, -100))
	for i in 60:
		main.driver.step_once()
		frames(main, 0.1)
		if not main.player.view.get("moving", false) and not main.player.following:
			break
	assert_eq(main.nav.room_at(main.player.cell), "room:workshop", "standing in the workshop")
	main._toggle_fpv()
	var cam: FpvCamera = main.host.pack.fpv
	cam.yaw = FpvCamera.yaw_along(Vector2(0, 1))
	cam.pitch = 0.0
	cam.look(0.0, -5.0)
	frames(main, 0.05)
	var hit: Dictionary = main.interaction.fpv_target()
	assert_eq(main.interact.verbs(hit), ["Walk here"], "the prompt: %s" % hit.get("type"))
	assert_eq(main.interaction.choice()["text"], "Walk here", "on the HUD")
	var sent := []
	main.player.world = Recorder.new(main.player.world, sent)
	main._interact()
	assert_eq(sent.size(), 1, "one Go")
	var to: Dictionary = sent[0]["to"]
	var at := Vector2(to["pos"]["x"], to["pos"]["z"])
	assert_eq(main.nav.room_at(main.nav.cell_of(at)), "room:commons", "to the commons' floor, not beyond its walls: %s" % at)
	main.free()


## Passes a world's calls through, noting each command sent.
class Recorder:
	var world
	var sent: Array

	func _init(world_, sent_: Array) -> void:
		world = world_
		sent = sent_

	func command(json: String) -> String:
		sent.append(JSON.parse_string(json))
		return world.command(json)


func test_the_pixel_style_declines_first_person_and_offers_a_3d_style() -> void:
	var main = booted(["--crowd=0", "--style=pixel_art"])
	arrive(main)
	main._toggle_fpv()
	assert_true(not main.host.first_person, "no first person in 2D")
	assert_true(not main.hud.notices.is_empty(), "a note says why")
	var note: Control = main.hud.notices[-1]
	assert_true("3D styles" in note.get_meta("text"), note.get_meta("text"))
	note.find_child("Action", true, false).pressed.emit()
	frames(main, 0.1)
	assert_eq(main.host.pack_dir.get_file(), "lowpoly_tropical", "its button switches to low-poly")
	assert_true(main.host.first_person, "in first person")
	main.free()


func test_switching_to_the_pixel_style_leaves_first_person() -> void:
	var main = booted(["--crowd=0", "--style=voxel"])
	arrive(main)
	main._toggle_fpv()
	frames(main, 0.1)
	assert_true(main.host.first_person, "first person in voxel")
	for d in main.styles:
		if d.get_file() == "pixel_art":
			main._activate(d)
	assert_true(not main.host.first_person, "the 2D style drops it")
	assert_true(not main.hud.notices.is_empty(), "and says so")
	main.free()


func test_w_walks_ahead_whatever_the_pitch() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	main._toggle_fpv()
	frames(main, 0.1)
	var cam: FpvCamera = main.host.pack.fpv
	for pitch in [-60.0, 0.0, 45.0, 70.0]:
		cam.pitch = 0.0
		cam.look(0.0, pitch)
		var ahead: Vector2 = main.fpv_steer(Vector2(0, -1))
		assert_true(ahead.distance_to(cam.forward()) < 0.01, "pitch %d: W is %s, ahead is %s" % [pitch, ahead, cam.forward()])
		var right: Vector2 = main.fpv_steer(Vector2(1, 0))
		assert_true(absf(right.dot(cam.forward())) < 0.01 and right.length() > 0.99, "pitch %d: D steps sideways" % pitch)
	main.free()


func test_a_style_switch_keeps_the_mouse_captured_and_the_view() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	main._toggle_fpv()
	frames(main, 0.1)
	main.host.pack.fpv.captured = true
	main.host.pack.fpv.look(40.0, 25.0)
	var yaw: float = main.host.pack.fpv.yaw
	var pitch: float = main.host.pack.fpv.pitch
	for d in main.styles:
		if d.get_file() == "voxel":
			main._activate(d)
	frames(main, 0.1)
	var cam: FpvCamera = main.host.pack.fpv
	assert_true(cam.captured, "still captured: the mouse still looks around")
	assert_true(absf(cam.pitch - pitch) < 0.01 and absf(cam.yaw - yaw) < 0.01, "the view kept its yaw and pitch: %f, %f" % [cam.yaw, cam.pitch])
	main.free()


## Inside in first person a building stays whole: roof on and every wall
## standing, whatever the camera rule or the overhead rig would open.
func test_in_first_person_a_building_stays_whole_around_you() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	main._toggle_fpv()
	var pack = main.host.pack
	# The eye inside the library, just by its west wall.
	pack.fpv.follow(Vector2(20.0, -2.0))
	main.host.update_cutaway("room:reading", null)
	pack._process(1.0 / 60.0)
	assert_true(not pack.is_open("facility:library"), "the library does not open round you")
	var lib: Dictionary = pack.shells["facility:library"]
	assert_eq(pack.shell_state("facility:library").get("roof"), true, "its roof is on")
	for side in lib["sides"]:
		assert_true(lib["sides"][side]["full"].visible, "its %s wall stands" % side)
	main._toggle_fpv()
	main.host.update_cutaway("room:reading", null)
	assert_true(pack.is_open("facility:library"), "overhead, it opens as before")
	main.free()


## Standing anywhere a person may stand, the first-person eye never sits
## inside a wall: it keeps clear of every wall's surface by more than the
## camera's near plane reaches, in every 3D style.
func test_the_eye_never_sits_inside_a_wall() -> void:
	for style in ["lowpoly_tropical", "voxel"]:
		var main = booted(["--crowd=0", "--style=" + style])
		arrive(main)
		main._toggle_fpv()
		var pack = main.host.pack
		var cam: FpvCamera = pack.fpv
		var fov := deg_to_rad(cam.fov) / 2.0
		var reach := cam.near * sqrt(1.0 + pow(tan(fov), 2) * (1.0 + pow(16.0 / 9.0, 2)))
		var boxes := []
		for id in pack.shells:
			for side in pack.shells[id]["sides"].values():
				for mi in side["full"].find_children("*", "VisualInstance3D", true, false):
					var piece := str(mi.get_parent().name)
					if "door" in piece or "entrance" in piece:
						continue
					var box: AABB = mi.global_transform * mi.get_aabb()
					if box.size.y > 2.0:
						boxes.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))
		var nav: NavQuery = main.nav
		var worst := INF
		var at := Vector2.ZERO
		for room in ["room:workshop", "room:commons", "room:reading"]:
			for j in nav.rows:
				for i in nav.cols:
					var c := Vector2i(i, j)
					if nav.room_at(c) != room:
						continue
					pack.fpv_follow(nav.centre(c))
					var eye := Vector2(cam.position.x, cam.position.z)
					for r in boxes:
						var d := Vector2(maxf(maxf(r.position.x - eye.x, 0.0), eye.x - r.end.x),
							maxf(maxf(r.position.y - eye.y, 0.0), eye.y - r.end.y)).length()
						if d < worst:
							worst = d
							at = nav.centre(c)
		assert_true(worst > reach, style + ": the eye keeps %.2f m from a wall (at %s), past the near plane's %.2f m" % [worst, at, reach])
		main.free()


func test_walking_along_the_library_s_front_the_eye_stays_with_the_walker() -> void:
	# The library's banners hang out over the square far above head height:
	# the eye keeps clear of what stands at its own height, the wall, so
	# someone walking beside the west front sees from where they are.
	for style in ["lowpoly_tropical", "anime_cel"]:
		var main = booted(["--crowd=0", "--style=" + style])
		arrive(main)
		main._toggle_fpv()
		var pack = main.host.pack
		var nav: NavQuery = main.nav
		var library: Dictionary = CityGeometry.buildings(main.manifest, StylePack.kinds()).filter(
			func(b): return b["id"] == "facility:library")[0]
		var fp: Rect2 = library["footprint"]
		var face: float = fp.position.x - library["wall"]
		var walked := 0
		var worst := 0.0
		var at := Vector2.ZERO
		for j in nav.rows:
			for i in nav.cols:
				var c := Vector2i(i, j)
				var p := nav.centre(c) / 100.0
				if p.x < face - 0.3 or p.x > face or p.y < fp.position.y or p.y > fp.end.y or not nav.walkable(c):
					continue
				walked += 1
				pack.fpv_follow(nav.centre(c))
				var off := Vector2(pack.fpv.position.x, pack.fpv.position.z).distance_to(p)
				if off > worst:
					worst = off
					at = p
		assert_true(walked > 30, "%s: cells beside the west front (%d)" % [style, walked])
		assert_true(worst <= 0.15, "%s: the eye stays within %.2f m of the walker (at %s)" % [style, worst, at])
		main.free()


func test_leaving_first_person_restores_the_avatar_as_it_was() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	var body: Node = main.host.pack.nodes[main.player.id]
	var icon_before: bool = body.get_node("Icon").visible
	var glyph_before: bool = body.get_node("Glyph").visible
	main._toggle_fpv()
	frames(main, 0.1)
	main._toggle_fpv()
	frames(main, 0.1)
	assert_eq(body.get_node("Icon").visible, icon_before, "the presence icon as before")
	assert_eq(body.get_node("Glyph").visible, glyph_before, "the glyph as before")
	assert_true(main.host.pack.player_marker().visible, "the you-marker is back")
	main.free()


## Inside in first person, the roof stays overhead: you see the ceiling,
## not the sky. Overhead again, the building opens as before.
func test_in_first_person_a_building_keeps_its_roof() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	var pack = main.host.pack
	main._toggle_fpv()
	pack.set_open("facility:library", true)
	assert_eq(pack.shell_state("facility:library").get("roof"), true, "the roof over the eye stays")
	main._toggle_fpv()
	assert_eq(pack.shell_state("facility:library").get("roof"), false, "overhead, the open library shows its inside")
	main.free()


## C keeps roofs on overhead too, and C again lets them lift.
func test_c_keeps_the_roofs_on() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical", "--dev"])
	arrive(main)
	var pack = main.host.pack
	pack.set_open("facility:library", true)
	main.router.handle(key_c())
	main.router.handle(release(key_c()))
	assert_eq(pack.shell_state("facility:library").get("roof"), true, "C: roofs stay on")
	main._activate("res://styles/pixel_art")
	main.host.pack.set_open("facility:library", true)
	assert_eq(main.host.pack.shell_state("facility:library").get("roof"), true, "in every style")
	main.router.handle(key_c())
	main.router.handle(release(key_c()))
	assert_eq(main.host.pack.shell_state("facility:library").get("roof"), false, "C again: they lift")
	main.free()


func key_c() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_C
	e.physical_keycode = KEY_C
	e.pressed = true
	return e


func start_button(pressed := true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_START
	e.pressed = pressed
	return e


func escape_key() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.physical_keycode = KEY_ESCAPE
	e.pressed = true
	return e


func test_start_on_a_controller_frees_the_mouse_and_opens_the_menu_at_once() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	main._toggle_fpv()
	frames(main, 0.1)
	assert_true(main.host.pack.fpv.captured, "the mouse is held in first person")
	main.router.handle(start_button())
	main.router.handle(start_button(false))
	assert_true(not main.host.pack.fpv.captured, "Start frees the mouse")
	assert_true(main.stack.top() is GameMenu, "and opens the menu on the same press")
	main.stack.back()
	main._capture_mouse(true)
	main.router.handle(escape_key())
	main.router.handle(release(escape_key()))
	assert_true(not main.host.pack.fpv.captured, "Esc frees the mouse")
	assert_eq(main.stack.top(), main.hud, "and only that, on the keyboard")
	main.router.handle(escape_key())
	main.router.handle(release(escape_key()))
	assert_true(main.stack.top() is GameMenu, "a second Esc opens the menu")
	main.free()
