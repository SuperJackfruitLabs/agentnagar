extends TestSuite

func screen() -> SettingsScreen:
	var s := Settings.new()
	s.path = "user://test_settings_screen.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(s.path))
	s.load_file()
	var sc := SettingsScreen.new()
	sc.settings = s
	sc.ui = UiTheme.from_style({})
	runner.root.add_child(sc)
	sc.build()
	return sc


func test_every_spec_setting_has_a_row() -> void:
	var sc := screen()
	for key in ["display", "vsync", "frame_cap", "quality", "mouse_sensitivity", "stick_sensitivity",
			"invert_y", "names", "text_size", "join_as", "calm", "tools"]:
		assert_true(sc.find_child(key, true, false) != null, "row " + key)
	sc.free()


func test_changing_a_row_saves_it() -> void:
	var sc := screen()
	sc.set_row("quality", "low")
	assert_eq(sc.settings.get_value("graphics", "quality"), "low", "saved")
	sc.free()


func test_a_display_change_reverts_without_an_answer() -> void:
	var sc := screen()
	sc.set_row("display", "fullscreen")
	assert_true(sc.confirming, "asks to keep it")
	sc.tick(10.5)
	assert_eq(sc.settings.get_value("graphics", "display"), "windowed", "reverted")
	sc.free()


func test_rebinding_a_key_and_a_conflict() -> void:
	var s := Settings.new()
	s.path = "user://test_rebind.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(s.path))
	s.load_file()
	RebindScreen.capture_defaults()
	var r := RebindScreen.new()
	r.settings = s
	r.ui = UiTheme.from_style({})
	runner.root.add_child(r)
	r.build()
	r.begin("names", "key")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_K
	k.keycode = KEY_K
	k.pressed = true
	r.capture(k)
	assert_eq(s.get_value("controls", "bindings")["names"]["key"], KEY_K, "saved")
	assert_true(InputMap.action_has_event("names", k), "applied")
	r.begin("cycle_look", "key")
	r.capture(k)
	assert_true(r.conflict != "", "conflict with names")
	r.resolve(true)
	assert_true(InputMap.action_has_event("cycle_look", k), "swapped onto cycle_look")
	RebindScreen.reset(s)
	var n := InputEventKey.new()
	n.physical_keycode = KEY_N
	n.keycode = KEY_N
	n.pressed = true
	assert_true(InputMap.action_has_event("names", n), "defaults back")
	r.free()


func test_low_quality_survives_a_style_switch() -> void:
	var main = load("res://main.gd").new()
	# Its own settings file: Low saved here must not reach the rest of the run.
	main.settings_path = "user://test_low_quality.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.settings_path))
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=lowpoly_tropical"]))
	main.settings.set_value("graphics", "quality", "low")
	assert_true(not main.host.pack.env.ssao_enabled, "no SSAO when low")
	main.host.activate("res://styles/solarpunk", main.manifest, main.model, main.motion, 0.0)
	assert_true(main.host.pack.quality_low, "kept after switching")
	assert_true(not main.host.pack.env.ssao_enabled, "and applied")
	main.free()


# ---- Beyond the brief's tests ----

## A main booted on its own settings file, so what a test changes never
## reaches the rest of the run.
func booted(args: PackedStringArray, styles_root := "res://styles"):
	var main = load("res://main.gd").new()
	main.settings_path = "user://test_settings_screen_main.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.settings_path))
	runner.root.add_child(main)
	main.boot(args, styles_root)
	return main


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


func test_q_e_and_the_shoulder_buttons_switch_pages() -> void:
	var sc := screen()
	assert_eq(sc.page_names(), ["Graphics", "Controls", "Interface", "Accessibility", "Developer", "Station computer"], "the pages, in order")
	assert_eq(sc.tabs.current_tab, 0, "Graphics first")
	sc._unhandled_input(key(KEY_E))
	assert_eq(sc.tabs.current_tab, 1, "E: next")
	sc._unhandled_input(pad(JOY_BUTTON_RIGHT_SHOULDER))
	assert_eq(sc.tabs.current_tab, 2, "RB: next")
	sc._unhandled_input(pad(JOY_BUTTON_LEFT_SHOULDER))
	sc._unhandled_input(key(KEY_Q))
	assert_eq(sc.tabs.current_tab, 0, "Q and LB: back")
	sc._unhandled_input(key(KEY_Q))
	assert_eq(sc.tabs.current_tab, 5, "wraps to the last page")
	assert_true(sc.find_child("live", true, false).is_visible_in_tree(), "the Station computer page shows")
	assert_true(not sc.find_child("display", true, false).is_visible_in_tree(), "and Graphics does not")
	sc.free()


func test_left_and_right_change_the_focused_row() -> void:
	var sc := screen()
	var frame_cap: OptionButton = sc.value_control("frame_cap")
	var right := key(KEY_RIGHT)
	frame_cap.gui_input.emit(right)
	assert_eq(sc.settings.get_value("graphics", "frame_cap"), 60, "Display rate -> 60")
	frame_cap.gui_input.emit(key(KEY_LEFT))
	frame_cap.gui_input.emit(key(KEY_LEFT))
	assert_eq(sc.settings.get_value("graphics", "frame_cap"), 0, "stops at the first choice")
	var vsync: CheckButton = sc.value_control("vsync")
	vsync.gui_input.emit(key(KEY_RIGHT))
	assert_eq(sc.settings.get_value("graphics", "vsync"), false, "a toggle flips")
	sc.step_row("mouse_sensitivity", 1)
	assert_eq(sc.settings.get_value("controls", "mouse_sensitivity"), 1.25, "a quarter step")
	var slider: HSlider = sc.value_control("mouse_sensitivity")
	assert_eq(slider.min_value, 0.25, "from a quarter")
	assert_eq(slider.max_value, 3.0, "to three times")
	sc.free()


func test_the_rows_hold_their_choices_in_order() -> void:
	var sc := screen()
	var expect := {
		"display": ["Windowed", "Fullscreen"],
		"frame_cap": ["Display rate", "60", "120", "144", "240", "Unlimited"],
		"quality": ["High", "Low"],
		"text_size": ["100%", "125%", "150%"],
		"join_as": ["Visitor", "Observer", "Just watch"],
	}
	for k in expect:
		var o: OptionButton = sc.value_control(k)
		var items := []
		for i in o.item_count:
			items.append(o.get_item_text(i))
		assert_eq(items, expect[k], k)
	sc.set_row("text_size", 1.5)
	assert_eq(sc.settings.get_value("interface", "text_size"), 1.5, "text size saved as a scale")
	sc.set_row("frame_cap", -1)
	assert_eq(sc.value_control("frame_cap").selected, 5, "Unlimited shown")
	assert_true(sc.find_child("look", true, false).visible, "Look opens the Join screen's look step")
	sc.free()


func test_keep_holds_a_display_change_and_revert_undoes_it() -> void:
	var sc := screen()
	sc.set_row("display", "fullscreen")
	sc.answer(true)
	assert_true(not sc.confirming, "answered")
	sc.tick(20.0)
	assert_eq(sc.settings.get_value("graphics", "display"), "fullscreen", "kept")
	sc.set_row("display", "windowed")
	sc.answer(false)
	assert_eq(sc.settings.get_value("graphics", "display"), "fullscreen", "reverted on request")
	assert_eq(sc.value_control("display").selected, 1, "the row shows it")
	sc.free()


func test_the_controls_page_resets_its_rows_and_the_bindings() -> void:
	var sc := screen()
	RebindScreen.capture_defaults()
	sc.set_row("mouse_sensitivity", 2.0)
	sc.set_row("invert_y", true)
	sc.settings.set_value("controls", "bindings", {"names": {"key": KEY_K}})
	RebindScreen.apply_bindings(sc.settings)
	sc.reset_controls()
	assert_eq(sc.settings.get_value("controls", "mouse_sensitivity"), 1.0, "sensitivity back")
	assert_eq(sc.settings.get_value("controls", "invert_y"), false, "invert back")
	assert_eq(sc.settings.get_value("controls", "bindings"), {}, "bindings cleared")
	assert_true(InputMap.action_has_event("names", key(KEY_N)), "N names again")
	assert_true(not InputMap.action_has_event("names", key(KEY_K)), "and K does not")
	sc.free()


func test_rebinding_waits_and_esc_cancels_except_for_the_menu() -> void:
	var s := Settings.new()
	s.path = "user://test_rebind.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(s.path))
	s.load_file()
	RebindScreen.capture_defaults()
	var r := RebindScreen.new()
	r.settings = s
	r.ui = UiTheme.from_style({})
	runner.root.add_child(r)
	r.build()
	assert_eq(r.find_child("names", true, false).get_child_count(), 3, "label, key and pad")
	r.begin("interact", "key")
	assert_true(r.waiting(), "waits")
	r.capture(key(KEY_ESCAPE))
	assert_true(not r.waiting(), "Esc cancels")
	assert_true(InputMap.action_has_event("interact", key(KEY_SPACE)), "unchanged")
	r.begin("menu", "key")
	r.capture(key(KEY_ESCAPE))
	assert_true(not r.waiting(), "bound")
	assert_eq(s.get_value("controls", "bindings")["menu"]["key"], KEY_ESCAPE, "Esc bound to the menu")
	r.begin("names", "pad")
	r.capture(pad(JOY_BUTTON_DPAD_UP))
	assert_eq(s.get_value("controls", "bindings")["names"]["pad"], JOY_BUTTON_DPAD_UP, "a pad button saved")
	assert_true(InputMap.action_has_event("names", pad(JOY_BUTTON_DPAD_UP)), "and applied")
	assert_true(not InputMap.action_has_event("names", pad(JOY_BUTTON_X)), "replacing X")
	r.begin("toggle_fpv", "pad")
	r.capture(pad(JOY_BUTTON_DPAD_UP))
	assert_eq(r.conflict, "names", "conflict named")
	r.resolve(false)
	assert_true(not InputMap.action_has_event("toggle_fpv", pad(JOY_BUTTON_DPAD_UP)), "cancel leaves it")
	assert_true(not r.waiting(), "and stops waiting")
	RebindScreen.reset(s)
	# Bindings saved earlier are applied at boot, over the project's map.
	s.set_value("controls", "bindings", {"cycle_look": {"key": KEY_J, "pad": JOY_BUTTON_X}})
	RebindScreen.apply_bindings(s)
	assert_true(InputMap.action_has_event("cycle_look", key(KEY_J)), "key applied")
	assert_true(not InputMap.action_has_event("cycle_look", key(KEY_L)), "replacing L")
	assert_true(InputMap.action_has_event("cycle_look", pad(JOY_BUTTON_X)), "pad applied")
	# X was name tags' by default: the saved binding wins, and name tags
	# lose it, as a rebind on the screen would take it; nothing answers to
	# X twice.
	assert_true(not InputMap.action_has_event("names", pad(JOY_BUTTON_X)), "name tags lose pad X")
	assert_true(InputMap.action_has_event("names", key(KEY_N)), "and keep N")
	for action in RebindScreen.ACTIONS:
		if action != "cycle_look":
			assert_true(not InputMap.action_has_event(action, pad(JOY_BUTTON_X)), action + " is not on X too")
	RebindScreen.reset(s)
	assert_true(InputMap.action_has_event("names", pad(JOY_BUTTON_X)), "reset gives it back")
	r.free()


func test_settings_apply_live_in_main() -> void:
	var main = booted(PackedStringArray(["--crowd=0", "--style=fake_pack"]), "res://tests/fixtures")
	main.settings.set_value("interface", "text_size", 1.5)
	assert_eq(main.ui.font_size(20), 30, "text rescaled")
	assert_eq(main.stack.ui, main.ui, "and every screen reskinned")
	main.settings.set_value("interface", "names", true)
	assert_true(main.host.names_on, "name tags on")
	main.settings.set_value("developer", "tools", true)
	assert_true(main.dev.enabled and main.router.dev_shortcuts, "developer tools on")
	main.settings.set_value("developer", "tools", false)
	assert_true(not main.dev.enabled and not main.router.dev_shortcuts, "and off")
	main.settings.set_value("accessibility", "calm", true)
	assert_true(main.host.calm and main.host.pack.calm, "calm reaches the pack")
	main.settings.set_value("controls", "mouse_sensitivity", 2.0)
	main.settings.set_value("controls", "stick_sensitivity", 0.5)
	main.settings.set_value("controls", "invert_y", true)
	assert_eq(main.host.pack.look_scale, 2.0, "mouse")
	assert_eq(main.host.pack.stick_scale, 0.5, "stick")
	assert_true(main.host.pack.invert_y, "invert")
	main.settings.set_value("graphics", "frame_cap", 120)
	assert_eq(Engine.max_fps, 120, "frame cap")
	main.settings.set_value("graphics", "frame_cap", 0)
	assert_eq(Engine.max_fps, 0, "display rate")
	main.free()


func test_the_menu_opens_settings() -> void:
	var main = booted(PackedStringArray(["--crowd=0", "--style=fake_pack"]), "res://tests/fixtures")
	main.router.handle(key(KEY_ESCAPE))
	var menu: GameMenu = main.stack.top()
	assert_true(menu.action_button("Settings").visible, "Settings shown")
	menu.open_settings.emit()
	var sc = main.stack.top()
	assert_true(sc is SettingsScreen, "settings open")
	assert_eq(sc.settings, main.settings, "on the player's settings")
	sc.open_rebind()
	assert_true(main.stack.top() is RebindScreen, "Rebind… opens the rebinding screen")
	main.free()


func test_low_quality_lowers_shadows_msaa_and_reflections_and_high_restores_them() -> void:
	var main = booted(PackedStringArray(["--crowd=0", "--style=solarpunk"]))
	var pack = main.host.pack
	var atlas: int = Pack3D.renderer_shadows["atlas"]
	var msaa: int = main.get_viewport().msaa_3d
	var reach: float = pack.shadow_reach()
	assert_eq(msaa, Viewport.MSAA_2X, "solarpunk's own MSAA")
	main.settings.set_value("graphics", "quality", "low")
	assert_eq(Pack3D.renderer_shadows["atlas"], atlas / 2, "atlas halved")
	assert_eq(pack.shadow_reach(), reach / 2.0, "reach halved")
	assert_eq(main.get_viewport().msaa_3d, Viewport.MSAA_DISABLED, "none under FXAA")
	assert_true(not pack.env.ssr_enabled and not pack.env.ssao_enabled, "no SSR or SSAO")
	pack.set_rain(1.0)
	assert_true(not pack.env.ssr_enabled, "not even in rain")
	main.settings.set_value("graphics", "quality", "high")
	assert_eq(Pack3D.renderer_shadows["atlas"], atlas, "atlas back")
	assert_eq(pack.shadow_reach(), reach, "reach back")
	assert_eq(main.get_viewport().msaa_3d, msaa, "MSAA back")
	assert_true(pack.env.ssao_enabled, "SSAO back")
	main.free()


func test_calm_rain_is_a_quarter_without_streaks() -> void:
	var main = booted(PackedStringArray(["--crowd=0", "--style=solarpunk"]))
	var pack = main.host.pack
	pack.set_rain(1.0)
	assert_eq(pack.rain_node.amount, Pack3D.RAIN_STREAKS, "full rain")
	assert_true(pack._streaks.any(func(s): return s.visible), "streaks under the lamps")
	main.settings.set_value("accessibility", "calm", true)
	assert_eq(pack.rain_node.amount, Pack3D.RAIN_STREAKS / 4, "a quarter")
	assert_true(not pack._streaks.any(func(s): return s.visible), "no streaks")
	main.host.activate("res://styles/solarpunk", main.manifest, main.model, main.motion, 0.0)
	main.host.pack.set_rain(1.0)
	assert_eq(main.host.pack.rain_node.amount, Pack3D.RAIN_STREAKS / 4, "kept after a switch")
	main.free()


func test_sensitivity_and_invert_scale_the_mouse_and_stick_look() -> void:
	var rig := OrbitRig.new()
	var drag := InputEventMouseButton.new()
	drag.button_index = MOUSE_BUTTON_RIGHT
	drag.pressed = true
	rig.handle(drag)
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(10, 10)
	var yaw := rig.yaw
	var pitch := rig.pitch
	rig.look_scale = 2.0
	rig.handle(move)
	assert_true(is_equal_approx(rig.yaw, yaw - 6.0), "twice the turn")
	assert_true(is_equal_approx(rig.pitch, pitch - 6.0), "and the tilt")
	rig.invert_y = true
	rig.handle(move)
	assert_true(is_equal_approx(rig.pitch, pitch), "inverted, it tilts back")
	rig.free()
	var eye := FpvCamera.new()
	eye.captured = true
	eye.look_scale = 2.0
	eye.invert_y = true
	eye.handle(move)
	assert_true(is_equal_approx(eye.yaw, -10 * FpvCamera.MOUSE_SENSITIVITY * 2.0), "first-person turn scaled")
	assert_true(is_equal_approx(eye.pitch, 10 * FpvCamera.MOUSE_SENSITIVITY * 2.0), "and its pitch inverted")
	eye.free()
	var main = booted(PackedStringArray(["--crowd=0", "--style=lowpoly_tropical"]))
	main.settings.set_value("controls", "mouse_sensitivity", 3.0)
	main.settings.set_value("controls", "stick_sensitivity", 0.5)
	var pack = main.host.pack
	assert_eq(pack.rig.look_scale, 3.0, "the rig takes the mouse sensitivity")
	var before: float = pack.rig.yaw
	pack.orbit(Vector2(1, 0), 0.1)
	var turned: float = before - pack.rig.yaw
	assert_true(is_equal_approx(turned, StylePack.STICK_DRAG_PX_PER_S * 0.1 * 0.3 * 0.5), "the stick turns at its own sensitivity")
	main.free()


# ---- The final review's fixes ----

func rebind_screen() -> RebindScreen:
	var s := Settings.new()
	s.path = "user://test_rebind_b.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(s.path))
	s.load_file()
	RebindScreen.capture_defaults()
	var r := RebindScreen.new()
	r.settings = s
	r.ui = UiTheme.from_style({})
	runner.root.add_child(r)
	r.build()
	return r


func test_b_cancels_a_controller_wait_except_for_stop() -> void:
	var r := rebind_screen()
	r.begin("interact", "pad")
	assert_true("B" in r.hint.text and "Esc" in r.hint.text, "the hint names B and Esc: " + r.hint.text)
	r.capture(pad(JOY_BUTTON_B))
	assert_true(not r.waiting(), "B cancels")
	assert_true(InputMap.action_has_event("interact", pad(JOY_BUTTON_A)), "Act keeps A")
	assert_true(not InputMap.action_has_event("interact", pad(JOY_BUTTON_B)), "and is not given B")
	assert_true(not r.settings.get_value("controls", "bindings").has("interact"), "nothing saved")
	r.begin("cancel", "pad")
	assert_true("Esc cancels" in r.hint.text and not "B " in r.hint.text, "for Stop only Esc cancels: " + r.hint.text)
	r.capture(pad(JOY_BUTTON_B))
	assert_true(not r.waiting(), "B is taken as Stop's button")
	assert_eq(r.settings.get_value("controls", "bindings")["cancel"]["pad"], JOY_BUTTON_B, "and saved")
	r.begin("interact", "key")
	assert_true("Esc" in r.hint.text and "B" in r.hint.text, "waiting for a key, Esc or B cancels: " + r.hint.text)
	r.begin("menu", "key")
	assert_true("B cancels" in r.hint.text and not "Esc" in r.hint.text, "for the menu's key only B does: " + r.hint.text)
	r.capture(pad(JOY_BUTTON_B))
	assert_true(not r.waiting(), "and it does")
	RebindScreen.reset(r.settings)
	r.free()


func test_an_unlimited_frame_cap_shows_vsync_off_and_fixed() -> void:
	var sc := screen()
	var vsync: CheckButton = sc.value_control("vsync")
	assert_true(vsync.button_pressed and not vsync.disabled, "vsync on by default, and changeable")
	sc.set_row("frame_cap", -1)
	assert_true(not vsync.button_pressed, "unlimited: vsync shows off, as it is")
	assert_true(vsync.disabled, "and cannot be changed")
	assert_true("unlimited" in vsync.text.to_lower(), "saying why: " + vsync.text)
	sc.step_row("vsync", 1)
	assert_eq(sc.settings.get_value("graphics", "vsync"), true, "the choice underneath is kept")
	sc.set_row("frame_cap", 60)
	assert_true(vsync.button_pressed and not vsync.disabled, "a cap again: vsync as chosen")
	assert_eq(vsync.text, "", "with nothing to explain")
	sc.free()
