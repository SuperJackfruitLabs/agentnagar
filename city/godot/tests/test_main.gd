extends TestSuite


func test_error_screen_when_extension_missing() -> void:
	var main = load("res://main.gd").new()
	main.class_exists = func(_n): return false
	runner.root.add_child(main)
	main.boot(PackedStringArray())
	assert_true(main.hud.error_label.visible, "error shown")
	assert_true("build-godot.sh" in main.hud.error_label.text, "with the build command")
	assert_true(main.hud.fixture.is_visible_in_tree(), "the fixture notice still shown")
	main.free()


func test_boots_the_district_with_the_first_style() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack"]), "res://tests/fixtures")
	assert_true(not main.hud.error_label.visible, "no error: " + main.hud.error_label.text)
	assert_eq(main.host.pack_dir, "res://tests/fixtures/fake_pack", "chosen style")
	# The district's arrivals ride in by tram: the first step off at the
	# Square at 35 (east:1) and 38 (west:1), so no one is drawn before.
	main.driver.advance(40.0)
	assert_true(main.host.pack.nodes.size() > 0, "occupants drawn")
	assert_true(not main.host.pack.names_on, "names hidden by default")
	main.free()


## A projection's grid changes (placement commands) reach the client's
## grid as it lands, so prediction steps where the core now allows.
func test_a_projection_s_grid_changes_reach_the_client_s_grid() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack"]), "res://tests/fixtures")
	main.driver.advance(2.0)
	var c: Vector2i = main.nav.cell_of(Vector2(0, 0))
	for i in 400:
		if main.nav.room_at(c) == "room:plaza":
			break
		c += Vector2i(1, 0)
	assert_eq(main.nav.room_at(c), "room:plaza", "a plaza cell to close")
	var p: Dictionary = main._last_projection.duplicate(true)
	assert_true(not p.is_empty(), "a projection has landed")
	p["grid_changes"] = [{"i": c.x, "j": c.y, "walkable": false}]
	main._on_projected(p)
	assert_true(not main.nav.walkable(c), "the closed cell is off the client's grid")
	var plaza: int = main.nav.room_ids.find("room:plaza")
	p["grid_changes"] = [{"i": c.x, "j": c.y, "walkable": true, "room": plaza}]
	main._on_projected(p)
	assert_eq(main.nav.room_at(c), "room:plaza", "and the reopened cell is the plaza's again")
	main.free()


func test_packs_are_given_places_not_people() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack"]), "res://tests/fixtures")
	assert_true(not main.manifest.has("occupants"), "no occupant roster reaches a pack")
	assert_true(not "agent:" in JSON.stringify(main.manifest), "no occupant IDs reach a pack")
	main.free()


func test_launch_options_open_every_building_and_choose_the_camera() -> void:
	var o := CityArgs.parse(PackedStringArray(["--open-all", "--camera=street"]))
	assert_eq(o["open_all"], true, "--open-all")
	assert_eq(o["camera"], "street", "--camera")
	assert_eq(CityArgs.parse(PackedStringArray())["open_all"], false, "closed by default")
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack", "--open-all"]), "res://tests/fixtures")
	assert_true(main.host.open_all, "the host opens every building")
	assert_true(main.dev.open_all, "and the developer panel shows it")
	main.free()


func test_no_hud_hides_the_controls_but_keeps_the_fixture_banner() -> void:
	assert_eq(CityArgs.parse(PackedStringArray(["--no-hud"]))["no_hud"], true, "--no-hud")
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack", "--no-hud", "--dev"]), "res://tests/fixtures")
	assert_true(not main.hud.clock.is_visible_in_tree() and not main.hud.hints.is_visible_in_tree(), "controls hidden")
	assert_true(not main.dev.visible, "the developer panel and its status hidden")
	assert_true(main.hud.fixture.is_visible_in_tree(), "the fixture banner always shows")
	main.free()


## Presses and releases through the client's own router.
func tap(main, e: InputEvent) -> void:
	var down = e.duplicate()
	down.set("pressed", true)
	main.router.handle(down)
	var up = e.duplicate()
	up.set("pressed", false)
	main.router.handle(up)


func test_keys_and_pad_buttons_reach_the_client_through_the_router() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack", "--dev"]), "res://tests/fixtures")
	var key := InputEventKey.new()
	key.keycode = KEY_N
	tap(main, key)
	assert_true(main.host.names_on, "N shows name tags")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_X
	tap(main, pad)
	assert_true(not main.host.names_on, "X on the pad hides them")
	key.keycode = KEY_X
	tap(main, key)
	assert_true(main.host.open_all, "X opens every building")
	key.keycode = KEY_T
	tap(main, key)
	assert_eq(main.host.camera_preset, "topdown", "T picks the top-down camera")
	key.keycode = KEY_P
	tap(main, key)
	assert_true(main.driver.paused, "P pauses")
	key.keycode = KEY_PERIOD
	var tick: int = main.driver.world.tick()
	tap(main, key)
	assert_eq(main.driver.world.tick(), tick + 1, ". steps one tick")
	pad.button_index = JOY_BUTTON_DPAD_UP
	tap(main, pad)
	assert_eq(main.driver.speed, 2, "D-pad up speeds up")
	main.free()


func test_the_pad_zooms_orbits_and_switches_styles() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=lowpoly_tropical", "--dev"]))
	var rig: OrbitRig = main.host.pack.rig
	var distance := rig.distance
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	main.router.handle(trigger)
	assert_true(rig.distance < distance, "RT zooms in, as the wheel does")
	var yaw := rig.yaw
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 1.0
	main.router.handle(stick)
	main._process(0.5)
	assert_true(not is_equal_approx(rig.yaw, yaw), "the right stick orbits")
	stick.axis_value = 0.0
	main.router.handle(stick)
	var styles: Array = main.styles
	var shoulder := InputEventJoypadButton.new()
	shoulder.button_index = JOY_BUTTON_RIGHT_SHOULDER
	tap(main, shoulder)
	assert_eq(main.host.pack_dir, styles[1], "RB: the next style")
	assert_eq(main.host.pack.style.get("dimension"), "2d", "the next style is the 2D one")
	var camera2d: Camera2D = main.host.pack.camera
	var at := camera2d.position
	stick.axis_value = 1.0
	main.router.handle(stick)
	main._process(0.5)
	assert_true(camera2d.position.x > at.x, "the right stick pans a 2D view")
	shoulder.button_index = JOY_BUTTON_LEFT_SHOULDER
	tap(main, shoulder)
	tap(main, shoulder)
	assert_eq(main.host.pack_dir, styles[-1], "LB twice: back round to the last")
	main.free()


func test_the_status_line_names_the_style_shown_at_once() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--as=none"]))
	main.driver.step_once()
	main.driver.pause()
	for d in main.styles:
		main._activate(d)
		var name_: String = main.host.style_name(d)
		assert_true(name_ in main.dev.status.text, "after switching to %s the status says so: %s" % [name_, main.dev.status.text])
	main.free()


func test_in_play_a_tick_lands_over_several_frames_without_a_jump_back() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=20", "--style=fake_pack", "--as=none"]), "res://tests/fixtures")
	main.set_process(false)
	main.driver.set_process(false)
	var time_was: int = main.model.time
	while main.driver.world.tick() < 1:
		main.driver.frame(0.004)
	main._process(0.004)
	assert_eq(main.shown_time(), 1.0, "stepped, not yet shown: walkers hold at the end of their steps")
	main.driver.frame(0.004)
	assert_eq(main.model.time, time_was, "projected, but the scene takes it on the next frame")
	assert_eq(main.shown_time(), 1.0, "still holding")
	main._process(0.004)
	assert_true(main.model.time != time_was, "the model has the new tick")
	assert_eq(main.shown_time(), 1.0, "still holding until the scene has it")
	main._process(0.004)
	assert_true(main.shown_time() < 0.5, "the scene has it, and time runs on from it")
	main.free()



## A model that records the ticks it is given, in order.
class Recorder extends SceneModel:
	var ticks := []

	func apply(p: Dictionary) -> Array:
		ticks.append(int(p.get("tick", -1)))
		return super(p)


func _staged_main():
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=20", "--style=fake_pack", "--as=none"]), "res://tests/fixtures")
	main.set_process(false)
	main.driver.set_process(false)
	var rec := Recorder.new()
	rec.occupants = main.model.occupants
	rec.time = main.model.time
	main.model = rec
	return main


## Short frames until a tick is stepped (and its projection on its way).
func _to_next_tick(main) -> void:
	var t: int = main.driver.world.tick()
	while main.driver.world.tick() == t:
		main.driver.frame(0.004)


func test_a_step_while_a_tick_lands_never_goes_back() -> void:
	var main = _staged_main()
	_to_next_tick(main)
	main.driver.frame(0.004)
	main.driver.step_once()
	for f in 6:
		main._process(0.004)
		main.driver.frame(0.004)
	var ticks: Array = main.model.ticks
	for k in range(1, ticks.size()):
		assert_true(ticks[k] > ticks[k - 1], "each tick once, in order: %s" % str(ticks))
	main.free()


func test_a_viewer_switch_while_a_tick_lands_leaves_no_ghosts() -> void:
	var main = _staged_main()
	_to_next_tick(main)
	main.driver.frame(0.004)
	main._process(0.004)
	_to_next_tick(main)
	main.driver.frame(0.004)
	main._set_viewer("person:asha")
	for f in 6:
		main._process(0.004)
		main.driver.frame(0.004)
	var shown: Array = main.host.pack.nodes.keys()
	var known: Array = main.model.occupants.keys()
	shown.sort()
	known.sort()
	assert_eq(shown, known, "the scene shows exactly the new viewer's world")
	main.free()


func test_ticks_due_together_all_reach_the_model() -> void:
	var main = _staged_main()
	var start: int = main.driver.world.tick()
	main.driver.frame(3.2)
	for f in 8:
		main._process(0.001)
		main.driver.frame(0.001)
	assert_eq(main.model.ticks, range(start + 1, start + 4), "each of the three ticks, in order")
	main.free()


func test_esc_opens_the_menu_and_holds_the_world_still() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack"]), "res://tests/fixtures")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	main.router.handle(esc)
	assert_true(main.stack.top() != main.hud, "a menu is open")
	assert_true(not main.router.world_enabled, "the world takes no input")
	main.free()


func test_developer_shortcuts_are_off_by_default_and_on_with_dev() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack"]), "res://tests/fixtures")
	assert_true(not main.router.dev_shortcuts, "off")
	assert_true(not main.dev.visible, "panel hidden")
	main.free()
	var dev = load("res://main.gd").new()
	runner.root.add_child(dev)
	dev.boot(PackedStringArray(["--crowd=0", "--style=fake_pack", "--dev"]), "res://tests/fixtures")
	assert_true(dev.router.dev_shortcuts, "on with --dev")
	dev.free()


func test_space_acts_and_never_pauses() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack", "--dev"]), "res://tests/fixtures")
	var sp := InputEventKey.new()
	sp.keycode = KEY_SPACE
	sp.physical_keycode = KEY_SPACE
	sp.pressed = true
	main.router.handle(sp)
	assert_true(not main.driver.paused, "Space does not pause")
	main.free()


func test_esc_through_the_window_opens_the_menu_and_esc_again_closes_it() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack"]), "res://tests/fixtures")
	for pressed in [true, false]:
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.physical_keycode = KEY_ESCAPE
		esc.pressed = pressed
		runner.root.push_input(esc)
	assert_eq(main.stack.screens.size(), 2, "one press opens the menu, and the same press does not close it")
	for pressed in [true, false]:
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.physical_keycode = KEY_ESCAPE
		esc.pressed = pressed
		runner.root.push_input(esc)
	assert_eq(main.stack.screens.size(), 1, "Esc again closes it")
	assert_true(main.router.world_enabled, "and the world takes input again")
	main.free()


func test_dev_title_and_play_flags() -> void:
	var o := CityArgs.parse(PackedStringArray())
	assert_eq([o["dev"], o["title"], o["play"]], [false, false, false], "all off by default")
	o = CityArgs.parse(PackedStringArray(["--dev", "--title", "--crowd=0", "--no-hud"]))
	assert_eq([o["dev"], o["title"], o["play"]], [true, true, false], "--dev and --title; the others are not play arguments")
	for a in ["--as=observer", "--look=1,2", "--style=voxel", "--camera=street", "--fpv", "--capture=/x.png", "--viewer=public"]:
		assert_true(CityArgs.parse(PackedStringArray([a]))["play"], a + " goes straight to play")


func test_open_menu_is_neither_a_play_nor_a_title_argument() -> void:
	assert_eq(CityArgs.parse(PackedStringArray())["open_menu"], false, "off by default")
	var o := CityArgs.parse(PackedStringArray(["--open-menu"]))
	assert_eq([o["open_menu"], o["play"], o["title"]], [true, false, false], "--open-menu alone")


func test_a_tool_boot_ignores_the_players_saved_settings() -> void:
	# A leftover tool file with name tags on, as a player's own file might be.
	var leftover := ConfigFile.new()
	leftover.set_value("interface", "names", true)
	leftover.save("user://settings_tool.cfg")
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot_for_tool(PackedStringArray(["--crowd=0", "--style=fake_pack"]), "res://tests/fixtures")
	assert_eq(main.settings.path, "user://settings_tool.cfg", "a throwaway file, never the player's")
	assert_true(not main.host.names_on, "the defaults: name tags off")
	main.free()


func test_every_tool_that_boots_the_client_boots_it_for_a_tool() -> void:
	for f in DirAccess.get_files_at("res://tools"):
		if not f.ends_with(".gd"):
			continue
		var source := FileAccess.get_file_as_string("res://tools/" + f)
		if "main.gd" in source:
			assert_true("boot_for_tool(" in source and not ".boot(" in source, f + " boots on throwaway settings")
