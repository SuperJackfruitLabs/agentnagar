## The map in the game: M in play, Map in the game menu, Map & read on the
## title, Go (a player walks there by the core's rules; a spectator's view
## glides there), the --map and --place arguments, and every step of it by
## a controller alone.
extends TestSuite

## A settings file of these tests' own, emptied before and after each test
## that uses it: the title's first launch asks how to enter, and a setting
## changed here never reaches the tests after.
const TITLE_SETTINGS := "user://test_map_flow.cfg"


func booted(extra: Array = []):
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack"] + extra), "res://tests/fixtures")
	return main


func titled(style := "fake_pack", root := "res://tests/fixtures", extra: Array = []):
	var main = load("res://main.gd").new()
	main.settings_path = TITLE_SETTINGS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TITLE_SETTINGS))
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--title", "--style=" + style] + extra), root)
	return main


func done_titled(main) -> void:
	main.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TITLE_SETTINGS))


func key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func pad(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e


## Presses `e` and lets it go again, through the window as real input.
func press_and_release(viewport: Viewport, e: InputEvent) -> void:
	var down = e.duplicate()
	down.set("pressed", true)
	viewport.push_input(down)
	var up = e.duplicate()
	up.set("pressed", false)
	viewport.push_input(up)


## Steps the world until `check` holds or `ticks` run out; true if it held.
func step_until(main, check: Callable, ticks := 120) -> bool:
	for i in ticks:
		if check.call():
			return true
		main.driver.step_once()
	return check.call()


# ---- The brief's tests ----

func test_m_opens_the_map_and_m_closes_it() -> void:
	var main = booted()
	main.router.handle(key(KEY_M))
	assert_true(main.stack.top() is MapScreen, "open")
	main.stack.top().handle_key(key(KEY_M))
	assert_eq(main.stack.top(), main.hud, "closed")
	main.free()


func test_go_walks_a_player_to_the_first_room() -> void:
	var main = booted()
	main.open_map("facility:library")
	main.stack.top().press_go()
	assert_eq(main.stack.top(), main.hud, "map closed")
	assert_eq(main.player.last_go_room, "room:reading", "Go sent for the reading room")
	main.free()


func test_go_as_a_spectator_moves_the_camera() -> void:
	var main = booted(["--as=none"])
	var flights := []
	main.host.pack.set_meta("fly_log", flights)
	main.open_map("facility:library")
	main.stack.top().press_go()
	assert_eq(flights.size(), 1, "the camera flew")
	main.free()


func test_place_argument_selects_by_room_or_facility_and_warns_when_unknown() -> void:
	for pair in [["room:reading", "facility:library"], ["facility:park", "facility:park"]]:
		var main = booted(["--place=" + pair[0]])
		assert_true(main.stack.top() is MapScreen, "map open")
		assert_eq(main.stack.top().model.selected, pair[1], "selected " + pair[1])
		main.free()
	var bad = booted(["--place=room:nowhere"])
	assert_eq(bad.stack.top().model.selected, "", "nothing selected")
	var chip = bad.stack.top().find_child("NoticeChip", true, false)
	assert_true(chip != null and chip.is_visible_in_tree(), "a notice on the map says so")
	bad.free()


## On the title the HUD is hidden, so an unknown --place is told on the
## map, which shows over the title.
func test_an_unknown_place_from_the_title_is_told_on_the_map() -> void:
	var main = titled("fake_pack", "res://tests/fixtures", ["--place=room:nowhere"])
	assert_true(main.stack.top() is MapScreen, "the map over the title")
	var chip = main.stack.top().find_child("NoticeChip", true, false)
	assert_true(chip != null and chip.is_visible_in_tree(), "the notice shows")
	assert_true(not main.hud.visible, "where the HUD's would not")
	done_titled(main)


func test_the_menu_and_the_title_offer_the_map() -> void:
	var main = booted()
	main.router.handle(key(KEY_ESCAPE))
	var menu = main.stack.top()
	assert_true(menu.find_child("Map", true, false).visible, "menu has Map")
	menu.open_map.emit()
	assert_true(main.stack.top() is MapScreen, "opened from the menu")
	main.free()


# ---- The arguments ----

func test_map_and_place_arguments() -> void:
	var o := CityArgs.parse(PackedStringArray())
	assert_eq([o["map"], o["place"]], [false, ""], "off by default")
	o = CityArgs.parse(PackedStringArray(["--map"]))
	assert_eq([o["map"], o["place"], o["play"], o["title"]], [true, "", false, false], "--map alone is not a play argument")
	o = CityArgs.parse(PackedStringArray(["--place=room:reading"]))
	assert_eq([o["map"], o["place"], o["play"]], [true, "room:reading", false], "--place implies --map")
	var main = booted(["--map"])
	assert_true(main.stack.top() is MapScreen, "--map opens the map after boot")
	assert_eq(main.stack.top().model.selected, "", "with nothing selected")
	main.free()


# ---- Go ----

func test_go_closes_the_map_and_the_menu_under_it() -> void:
	var main = booted()
	main.router.handle(key(KEY_ESCAPE))
	main.stack.top().open_map.emit()
	var map: MapScreen = main.stack.top()
	map.select("facility:park")
	map.press_go()
	assert_eq(main.stack.top(), main.hud, "back in play, the menu closed too")
	assert_true(main.router.world_enabled, "the world takes input again")
	main.free()


func test_a_refused_go_is_the_huds_notice() -> void:
	var main = booted()
	# The player's session is gone, so the bridge refuses the command.
	main.player.id = "person:nobody"
	main.open_map("facility:park")
	main.stack.top().press_go()
	assert_eq(main.hud.notices.size(), 1, "one notice")
	var text: String = main.hud.notices[0].get_meta("text")
	assert_true(text.begins_with("Can't go there: "), "it says why: " + text)
	main.free()


func test_a_seated_player_stands_and_walks_there() -> void:
	var main = booted()
	assert_true(step_until(main, func(): return main.player.present), "the player arrives")
	# It steps off a tram at the Square among its other riders: the seat is
	# chosen once no tram is by the Square and they have walked on.
	assert_true(step_until(main, func(): return not tram_by_the_square(main.driver.world), 40),
		"the trams have left the Square")
	# The nearest free seat the player can sit at.
	var taken: Dictionary = main.player.unavailable_seats()
	var best := ""
	var best_d := INF
	for s in main.nav.seats:
		var d: float = (s["pos"] as Vector2).distance_to(main.player.shown)
		if not taken.has(s["id"]) and d < best_d:
			best = s["id"]
			best_d = d
	main.player.go_seat(best)
	assert_true(step_until(main, func(): return main.player.view.get("seat") != null and not main.player.view.get("moving", false), 300), "seated")
	var room: String = str(main.player.view.get("room"))
	var target := "facility:park" if room != "room:park" else "facility:library"
	main.open_map(target)
	main.stack.top().press_go()
	main.driver.step_once()
	main.driver.step_once()
	assert_eq(main.player.view.get("seat"), null, "stood up")
	assert_true(main.player.view.get("moving", false) or str(main.player.view.get("room")) != room,
		"and walks on towards " + target + ", the Go not cancelled by standing: " + str(main.player.view))
	main.free()


func test_go_from_first_person_stays_in_first_person() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=lowpoly_tropical"]))
	assert_true(step_until(main, func(): return main.player.present), "the player arrives")
	main._toggle_fpv()
	assert_true(main.host.first_person, "in first person")
	main.open_map("facility:park")
	main.stack.top().press_go()
	assert_true(main.host.first_person, "still in first person")
	assert_eq(main.player.last_go_room, "room:park", "walking to the park")
	main.free()


func test_go_as_a_spectator_keeps_the_view_heading_and_zoom() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=lowpoly_tropical", "--as=none"]))
	var rig: OrbitRig = main.host.pack.rig
	rig.yaw = 100.0
	rig.distance = rig.preset_distance() * 0.5
	rig.update()
	var from := rig.position
	var distance := rig.distance
	main.open_map("facility:park")
	main.stack.top().press_go()
	for i in 10:
		rig.advance(0.1)
	assert_true(is_equal_approx(rig.yaw, 100.0), "the heading is kept: %f" % rig.yaw)
	assert_true(is_equal_approx(rig.distance, distance), "and the zoom: %f" % rig.distance)
	var park: Vector2 = MapModel.from_layout(main.manifest).place("facility:park")["centre"]
	assert_true(rig.position.distance_to(from) > 1.0, "the view moved")
	assert_true(Vector2(rig.position.x, rig.position.z).distance_to(park) < 0.01, "to the park")
	main.free()


func test_a_spectators_flight_takes_six_tenths_of_a_second_and_calm_cuts() -> void:
	# Its own settings file: calm mode must not stay on for the tests after.
	var main = load("res://main.gd").new()
	main.settings_path = TITLE_SETTINGS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TITLE_SETTINGS))
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack", "--as=none"]), "res://tests/fixtures")
	main.open_map("facility:park")
	main.stack.top().press_go()
	assert_eq(main.host.pack.flights[-1][1], 0.6, "0.6 s")
	main.settings.set_value("accessibility", "calm", true)
	main.open_map("facility:library")
	main.stack.top().press_go()
	assert_eq(main.host.pack.flights[-1][1], 0.0, "calm cuts")
	done_titled(main)


# ---- The title ----

func test_map_and_read_from_the_title_flies_the_title_camera_and_stays() -> void:
	var main = titled()
	var title = main.stack.top()
	assert_true(title is TitleScreen, "the title")
	assert_true(title.action_button("Map & read").visible, "Map & read shown")
	title.map_and_read.emit()
	var map = main.stack.top()
	assert_true(map is MapScreen, "the map over the title")
	assert_eq(map.you, null, "nobody is here")
	var flights: int = main.host.pack.flights.size()
	map.select("facility:park")
	map.press_go()
	assert_eq(main.stack.top(), title, "still on the title")
	assert_eq(main.player.id, "", "nobody joined")
	assert_eq(main.host.pack.flights.size(), flights + 1, "the title camera flew")
	assert_true(not main.host.pack.drift, "and stopped drifting")
	done_titled(main)


# ---- Opening ----

func test_the_map_holds_the_main_views_3d_while_open() -> void:
	var main = booted()
	var viewport: Viewport = main.get_viewport()
	var was := viewport.disable_3d
	main.open_map()
	assert_true(viewport.disable_3d, "no 3D under the map")
	main.stack.top().handle_key(key(KEY_M))
	await runner.process_frame
	assert_eq(viewport.disable_3d, was, "back as it was")
	main.free()


func test_the_map_shows_the_player_and_the_latest_projection() -> void:
	var main = booted()
	assert_true(step_until(main, func(): return main.player.present), "the player arrives")
	main.open_map()
	var map: MapScreen = main.stack.top()
	assert_true(map.you is Vector2, "you are here")
	assert_true((map.you as Vector2).distance_to(main.player.shown / 100.0) < 0.01, "at the player, in metres")
	assert_true(not map.projection.is_empty(), "the latest projection, for the counts")
	main.free()


# ---- A controller alone ----

func test_ui_accept_and_ui_cancel_answer_the_controller() -> void:
	assert_true(InputMap.action_has_event("ui_accept", pad(JOY_BUTTON_A)), "A accepts")
	assert_true(InputMap.action_has_event("ui_cancel", pad(JOY_BUTTON_B)), "B goes back")
	for k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		assert_true(InputMap.action_has_event("ui_accept", key(k)), "still " + OS.get_keycode_string(k))
	assert_true(InputMap.action_has_event("ui_cancel", key(KEY_ESCAPE)), "still Esc")


func test_the_whole_way_round_by_controller_alone() -> void:
	var main = titled()
	var viewport: Viewport = main.get_viewport()
	var title = main.stack.top()
	assert_true(title is TitleScreen, "the title")
	assert_eq(viewport.gui_get_focus_owner(), title.action_button("Explore"), "Explore focused")
	press_and_release(viewport, pad(JOY_BUTTON_A))
	var join = main.stack.top()
	assert_true(join is JoinScreen, "A on Explore asks how to enter")
	assert_eq(viewport.gui_get_focus_owner(), join.choices[0], "Visitor focused")
	press_and_release(viewport, pad(JOY_BUTTON_A))
	assert_eq(join.step, 2, "A on Visitor goes on to the look")
	press_and_release(viewport, pad(JOY_BUTTON_DPAD_UP))
	assert_eq(viewport.gui_get_focus_owner(), join.start_button, "up wraps round to Start")
	press_and_release(viewport, pad(JOY_BUTTON_A))
	assert_eq(main.stack.top(), main.hud, "A on Start: in play")
	assert_true(main.player.id != "", "joined")
	assert_eq(viewport.gui_get_focus_owner(), null, "the HUD holds no focus")
	var acts := [0]
	var stops := [0]
	main.router.interact.connect(func(): acts[0] += 1)
	main.router.cancel.connect(func(): stops[0] += 1)
	press_and_release(viewport, pad(JOY_BUTTON_A))
	assert_eq(acts[0], 1, "A in play acts, once")
	press_and_release(viewport, pad(JOY_BUTTON_START))
	var menu = main.stack.top()
	assert_true(menu is GameMenu, "Start opens the menu")
	for i in 4:
		if viewport.gui_get_focus_owner() == menu.action_button("Settings"):
			break
		press_and_release(viewport, pad(JOY_BUTTON_DPAD_DOWN))
	assert_eq(viewport.gui_get_focus_owner(), menu.action_button("Settings"), "down to Settings")
	press_and_release(viewport, pad(JOY_BUTTON_A))
	assert_true(main.stack.top() is SettingsScreen, "A opens the settings")
	press_and_release(viewport, pad(JOY_BUTTON_B))
	assert_eq(main.stack.top(), menu, "B goes back to the menu")
	press_and_release(viewport, pad(JOY_BUTTON_B))
	assert_eq(main.stack.top(), main.hud, "B again: back in play")
	assert_eq(stops[0], 0, "and neither B reached the world")
	press_and_release(viewport, pad(JOY_BUTTON_B))
	assert_eq(main.stack.top(), main.hud, "B in play closes nothing")
	assert_eq(stops[0], 1, "it stops a walk, once")
	press_and_release(viewport, pad(JOY_BUTTON_LEFT_STICK))
	assert_true(main.stack.top() is MapScreen, "the left-stick press opens the map")
	press_and_release(viewport, pad(JOY_BUTTON_B))
	await runner.process_frame
	assert_eq(main.stack.top(), main.hud, "B closes it")
	assert_eq(stops[0], 1, "without reaching the world")
	done_titled(main)


# ---- The mouse in first person ----

## In first person, whatever frees the mouse to use a screen takes it back
## when play resumes: the map closed with M, Esc or B, Go as a player
## (who stays in first person), and Resume on the game menu. Map spec
## section 4: closing "restores ... the cursor mode (first person captures
## the mouse)".
func test_play_resumed_in_first_person_takes_the_mouse_back() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=lowpoly_tropical"]))
	assert_true(step_until(main, func(): return main.player.present), "the player arrives")
	main._toggle_fpv()
	var eye: FpvCamera = main.host.pack.fpv
	assert_true(eye.captured, "first person holds the mouse")
	var closers := {"M": key(KEY_M), "B": pad(JOY_BUTTON_B)}
	for name in closers:
		main.open_map()
		assert_true(not eye.captured, "the map frees the mouse")
		main.stack.top().handle_key(closers[name])
		assert_eq(main.stack.top(), main.hud, name + " closes the map")
		assert_true(eye.captured, name + ": the mouse is held again")
	main.open_map()
	var escape := key(KEY_ESCAPE)
	press_and_release(main.get_viewport(), escape)
	assert_eq(main.stack.top(), main.hud, "Esc closes the map")
	assert_true(eye.captured, "Esc: the mouse is held again")
	main.open_map("facility:park")
	main.stack.top().press_go()
	assert_true(main.host.first_person, "Go keeps first person")
	assert_true(eye.captured, "Go: the mouse is held again")
	main._capture_mouse(false)
	main._open_menu()
	var menu: GameMenu = main.stack.top()
	menu.resume.emit()
	await runner.process_frame
	assert_eq(main.stack.top(), main.hud, "resumed")
	assert_true(eye.captured, "Resume: the mouse is held again")
	main.free()
