extends TestSuite

func booted(args := PackedStringArray(["--crowd=0", "--style=fake_pack"])):
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(args, "res://tests/fixtures")
	return main


func esc() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.physical_keycode = KEY_ESCAPE
	e.pressed = true
	return e


func key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


## A d-pad press, as a controller sends it.
func pad(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e


## Records every unhandled event that reaches it, as a pack's camera would
## take it.
class InputProbe extends Node:
	var seen := []
	func _unhandled_input(event: InputEvent) -> void:
		seen.append(event)


func test_esc_opens_the_menu_and_back_resumes() -> void:
	var main = booted()
	main.router.handle(esc())
	assert_true(main.stack.top() is GameMenu, "menu open")
	main.stack.back()
	assert_eq(main.stack.top(), main.hud, "back to play")
	assert_true(main.router.world_enabled, "world input back")
	main.free()


func test_the_menu_lists_its_actions_in_order() -> void:
	var main = booted()
	main.router.handle(esc())
	var m: GameMenu = main.stack.top()
	var names := []
	for b in m.find_children("*", "Button", true, false):
		if b.visible:
			names.append(str(b.name))
	assert_eq(names.slice(0, 1), ["Resume"], "Resume first")
	assert_true("Visual style" in names, "style picker reachable")
	main.free()


func test_choosing_a_style_reskins_and_keeps_focus() -> void:
	var main = booted()
	main.router.handle(esc())
	main.stack.top().open_style.emit()
	var picker: StylePicker = main.stack.top()
	assert_true(picker is StylePicker, "picker open")
	var before = main.stack.ui
	picker.chosen.emit(picker.styles[0]["dir"])
	assert_true(main.stack.top() == picker, "picker stays open")
	assert_true(main.stack.ui != before, "theme rebuilt for the new pack")
	main.free()


func test_the_menu_holds_every_action_in_order_and_hides_the_unbuilt_ones() -> void:
	var main = booted()
	main.router.handle(esc())
	var m: GameMenu = main.stack.top()
	var names := []
	for b in m.find_children("*", "Button", true, false):
		names.append(str(b.name))
	assert_eq(names, ["Resume", "Map", "Visual style", "Settings", "About", "Quit to title", "Quit"], "all seven, in order")
	assert_true(m.find_child("Map", true, false).visible, "the map is there")
	assert_true(m.find_child("Settings", true, false).visible, "the settings screen is built")
	assert_true(m.find_child("Quit to title", true, false).visible, "the title screen is built")
	assert_eq(m.find_child("Quit", true, false).visible, not OS.has_feature("web"), "Quit only off the web")
	assert_eq(m.find_child("Visual style", true, false).text, main.ui.case("Visual style"), "text through the skin's case")
	main.free()


func test_the_menu_dims_the_world_with_the_scrim_and_centres_its_panel() -> void:
	var main = booted()
	main.router.handle(esc())
	var m: GameMenu = main.stack.top()
	var scrim: ColorRect = m.find_children("*", "ColorRect", true, false)[0]
	assert_eq(scrim.color, main.ui.colour("scrim"), "the skin's scrim colour")
	assert_eq(scrim.anchor_right, 1.0, "full width")
	assert_eq(scrim.anchor_bottom, 1.0, "full height")
	assert_eq(m.panel.custom_minimum_size.x, 420.0, "420 px wide")
	assert_true(m.panel.get_parent() is CenterContainer, "centred")
	main.free()


func test_the_header_says_who_you_are() -> void:
	var main = booted()
	main.router.handle(esc())
	assert_eq(main.stack.top().header.text, main.hud.status_text, "the player's status")
	assert_true(main.hud.status_text.begins_with("Visitor"), "a visitor")
	main.free()
	main = booted(PackedStringArray(["--crowd=0", "--style=fake_pack", "--as=none"]))
	main.router.handle(esc())
	assert_eq(main.stack.top().header.text, "Watching", "without a player")
	main.free()


func test_resume_closes_the_menu() -> void:
	var main = booted()
	main.router.handle(esc())
	main.stack.top().find_child("Resume", true, false).pressed.emit()
	await runner.process_frame
	assert_eq(main.stack.top(), main.hud, "back to play")
	assert_true(main.router.world_enabled, "world input back")
	main.free()


func test_the_menu_is_driven_by_the_d_pad() -> void:
	var main = booted()
	main.router.handle(esc())
	var m: GameMenu = main.stack.top()
	var vp: Viewport = m.get_viewport()
	assert_eq(vp.gui_get_focus_owner(), m.find_child("Resume", true, false), "Resume focused")
	vp.push_input(pad(JOY_BUTTON_DPAD_DOWN))
	assert_eq(vp.gui_get_focus_owner(), m.find_child("Map", true, false), "down to the map")
	vp.push_input(pad(JOY_BUTTON_DPAD_UP))
	assert_eq(vp.gui_get_focus_owner(), m.find_child("Resume", true, false), "and back up")
	main.free()


## A window-sized viewport in the tree: the headless root is 64 x 64,
## which is the narrow layout.
func wide() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	runner.root.add_child(viewport)
	return viewport


func test_the_picker_shows_a_card_per_style_in_three_columns() -> void:
	var viewport := wide()
	var main = load("res://main.gd").new()
	viewport.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack"]), "res://tests/fixtures")
	main.router.handle(esc())
	main.stack.top().open_style.emit()
	var picker: StylePicker = main.stack.top()
	assert_eq(picker.styles.map(func(s): return s["dir"]), main.styles, "every style, in order")
	assert_eq(picker.styles[0]["name"], "Fake", "with its name")
	assert_eq(picker.current, main.host.pack_dir, "shows the current style")
	assert_eq(picker.grid.columns, 3, "three columns")
	var card: Button = picker.grid.get_node("fake_pack")
	assert_true(card != null, "a card named after the directory")
	assert_true(card.button_pressed, "the current style's card is marked")
	# The fixture has no preview: its name is shown on the accent colour.
	var slot: ColorRect = card.find_child("NoPreview", true, false)
	assert_true(slot != null and slot.visible, "a placeholder in place of the preview")
	assert_eq(slot.color, main.ui.colour("accent"), "on the accent colour")
	assert_eq(card.get_viewport().gui_get_focus_owner(), card, "the current card is focused")
	viewport.free()


func test_a_card_shows_its_preview_at_320_by_180() -> void:
	var picker := StylePicker.new()
	picker.styles = [{"dir": "res://styles/anime_cel", "name": "Cel-shaded anime"}]
	var stack := ScreenStack.new()
	stack.ui = UiTheme.from_style({})
	var viewport := wide()
	viewport.add_child(stack)
	stack.push(picker)
	var shown: TextureRect = picker.grid.get_node("anime_cel").find_child("Preview", true, false)
	assert_true(shown != null and shown.texture != null, "the pack's preview.png")
	assert_eq(shown.texture.get_size(), Vector2(480, 270), "480 x 270")
	assert_eq(shown.custom_minimum_size, Vector2(320, 180), "shown at 320 x 180")
	viewport.free()


func test_the_d_pad_reaches_every_card() -> void:
	var picker := StylePicker.new()
	picker.styles = []
	for i in 6:
		picker.styles.append({"dir": "res://nowhere/style_%d" % i, "name": "Style %d" % i})
	var stack := ScreenStack.new()
	stack.ui = UiTheme.from_style({})
	var viewport := wide()
	viewport.add_child(stack)
	stack.push(picker)
	var vp: Viewport = picker.get_viewport()
	var reached := {}
	# Right along the rows, wrapping from the end of one to the next.
	for i in 6:
		reached[vp.gui_get_focus_owner().name] = true
		vp.push_input(pad(JOY_BUTTON_DPAD_RIGHT))
	assert_eq(reached.size(), 6, "right alone reaches all six")
	var first: Button = picker.grid.get_node("style_0")
	first.grab_focus()
	vp.push_input(pad(JOY_BUTTON_DPAD_DOWN))
	assert_eq(vp.gui_get_focus_owner().name, "style_3", "down a row")
	vp.push_input(pad(JOY_BUTTON_DPAD_UP))
	assert_eq(vp.gui_get_focus_owner().name, "style_0", "and up again")
	vp.push_input(pad(JOY_BUTTON_DPAD_LEFT))
	assert_eq(vp.gui_get_focus_owner().name, "style_5", "left wraps to the last card")
	viewport.free()


func test_a_style_switch_keeps_the_picker_open_focused_and_in_charge_of_input() -> void:
	var main = booted()
	main.router.handle(esc())
	main.stack.top().open_style.emit()
	var picker: StylePicker = main.stack.top()
	var card: Button = picker.grid.get_node("fake_pack")
	card.grab_focus()
	card.pressed.emit()
	assert_true(main.stack.top() == picker, "picker stays open")
	assert_eq(picker.get_viewport().gui_get_focus_owner(), card, "focus stays on the chosen card")
	assert_eq(picker.last_focus, card, "and is remembered")
	assert_true(not main.router.world_enabled, "the world still takes no input")
	assert_eq(main.settings.get_value("interface", "style"), "fake_pack", "the choice is saved")
	# The new pack's camera must not take keys meant for the menu.
	var probe := InputProbe.new()
	main.host.pack.add_child(probe)
	picker.get_viewport().push_input(key(KEY_O))
	assert_eq(probe.seen.size(), 0, "no key reaches the pack under the picker")
	main.stack.back()
	assert_true(main.stack.top() is GameMenu, "Back returns to the menu")
	main.free()


func test_open_menu_opens_the_game_menu_after_boot() -> void:
	var main = booted(PackedStringArray(["--crowd=0", "--style=fake_pack", "--open-menu"]))
	assert_true(main.stack.top() is GameMenu, "the menu is open")
	assert_eq(main.stack.top().header.text, main.hud.status_text, "with its header")
	main.free()


func test_the_menu_panel_steps_aside_under_another_screen() -> void:
	# A see-through skin (neon's glass) would show the menu's buttons
	# through the settings panel.
	var main = booted()
	main.router.handle(esc())
	var m: GameMenu = main.stack.top()
	m.open_settings.emit()
	assert_true(not m.panel.visible, "hidden under the settings")
	main.stack.back()
	assert_true(main.stack.top() == m and m.panel.visible, "back on top, shown again")
	main.free()


func test_the_settings_panel_steps_aside_under_rebinding() -> void:
	# Neon's glass showed the settings' page names through the rebinding
	# screen's panel in the captures.
	var main = booted()
	main.router.handle(esc())
	main.stack.top().open_settings.emit()
	var settings: SettingsScreen = main.stack.top()
	settings.open_rebind()
	assert_true(main.stack.top() is RebindScreen, "rebinding is open")
	assert_true(settings.panel != null and not settings.panel.visible, "the settings panel is hidden under it")
	main.stack.back()
	assert_true(main.stack.top() == settings and settings.panel.visible, "back on top, shown again")
	main.free()


# ---- The final review's fixes ----

## Presses `e` and lets it go again, through the viewport as real input.
func press_and_release(viewport: Viewport, e: InputEvent) -> void:
	var down = e.duplicate()
	down.set("pressed", true)
	viewport.push_input(down)
	var up = e.duplicate()
	up.set("pressed", false)
	viewport.push_input(up)


func test_resuming_gives_a_hud_notice_button_no_focus_and_the_act_key_to_the_world() -> void:
	# First person, Esc, Esc, Visual style, pixel art: the "Switch to
	# low-poly" notice is up when the menu closes again.
	var main = booted()
	var switched := [0]
	main.hud.notify("First-person view is available in the 3D styles.", "Switch to low-poly", func(): switched[0] += 1)
	var button: Button = main.hud.notices[-1].find_child("Action", true, false)
	main.router.handle(esc())
	assert_true(main.stack.top() is GameMenu, "the menu is open")
	main.stack.back()
	var viewport: Viewport = main.get_viewport()
	assert_eq(viewport.gui_get_focus_owner(), null, "nothing on the HUD holds the focus")
	assert_eq(button.focus_mode, Control.FOCUS_NONE, "a notice's button never takes it")
	assert_eq(button.mouse_filter, Control.MOUSE_FILTER_STOP, "though the mouse still presses it")
	var acted := [0]
	main.router.interact.connect(func(): acted[0] += 1)
	press_and_release(viewport, key(KEY_SPACE))
	assert_eq(switched[0], 0, "Space does not press the notice's button")
	assert_eq(acted[0], 1, "it acts in the world")
	main.hud.focus_first()
	assert_eq(viewport.gui_get_focus_owner(), null, "the HUD never takes the focus")
	main.free()


func test_start_closes_the_menu_and_steps_back_from_a_deeper_screen() -> void:
	var main = booted()
	var viewport: Viewport = main.get_viewport()
	press_and_release(viewport, pad(JOY_BUTTON_START))
	var menu = main.stack.top()
	assert_true(menu is GameMenu, "Start opens the menu")
	menu.open_settings.emit()
	assert_true(main.stack.top() is SettingsScreen, "the settings over it")
	press_and_release(viewport, pad(JOY_BUTTON_START))
	assert_eq(main.stack.top(), menu, "Start steps back one level, as B does")
	press_and_release(viewport, pad(JOY_BUTTON_START))
	assert_eq(main.stack.top(), main.hud, "Start on the menu closes it")
	assert_true(main.router.world_enabled, "back in play")
	press_and_release(viewport, esc())
	assert_true(main.stack.top() is GameMenu, "Esc opens it")
	press_and_release(viewport, esc())
	assert_eq(main.stack.top(), main.hud, "and Esc closes it, once")
	main.free()


func test_a_drag_held_as_a_screen_opens_ends_with_it() -> void:
	for style in ["lowpoly_tropical", "pixel_art"]:
		var main = load("res://main.gd").new()
		runner.root.add_child(main)
		main.boot(PackedStringArray(["--crowd=0", "--style=" + style, "--as=none"]))
		var viewport: Viewport = main.get_viewport()
		var pack = main.host.pack
		var right := InputEventMouseButton.new()
		right.button_index = MOUSE_BUTTON_RIGHT
		right.position = Vector2(32, 32)
		right.pressed = true
		viewport.push_input(right)
		var dragger = pack.rig if style == "lowpoly_tropical" else pack
		assert_true(dragger.dragging, style + ": the right button drags")
		main.router.handle(esc())
		assert_true(main.stack.top() is GameMenu, style + ": the menu opens mid-drag")
		assert_true(not dragger.dragging, style + ": the drag ends as the menu opens")
		# The release lands on the menu, which keeps it from the world.
		var up: InputEventMouseButton = right.duplicate()
		up.pressed = false
		viewport.push_input(up)
		main.stack.back()
		var before = [pack.rig.yaw, pack.rig.pitch] if style == "lowpoly_tropical" else pack.camera.position
		var move := InputEventMouseMotion.new()
		move.position = Vector2(40, 32)
		move.relative = Vector2(40, 0)
		viewport.push_input(move)
		var after = [pack.rig.yaw, pack.rig.pitch] if style == "lowpoly_tropical" else pack.camera.position
		assert_eq(after, before, style + ": moving the mouse after the menu turns nothing")
		main.free()
