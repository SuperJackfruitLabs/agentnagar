## Every screen fits the window in every style: at 1280 x 720, and in the
## narrow layout at 800 x 900, where screens stack vertically (spec
## section 11). Each screen is shown in a SubViewport of that size, skinned
## by each real style.
extends TestSuite

const STYLES := ["anime_cel", "solarpunk", "neon_noir", "pixel_art", "lowpoly_tropical", "voxel"]
const SIZES := [Vector2i(1280, 720), Vector2i(800, 900)]


## A viewport of `size` holding a stack skinned by `style`, in the tree.
func stage(size: Vector2i, style: String) -> ScreenStack:
	var viewport := SubViewport.new()
	viewport.size = size
	runner.root.add_child(viewport)
	var stack := ScreenStack.new()
	stack.ui = UiTheme.from_style(style_json(style))
	viewport.add_child(stack)
	return stack


func style_json(style: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://styles/%s/style.json" % style))


func all_styles() -> Array:
	return STYLES.map(func(s): return {"dir": "res://styles/" + s, "name": s})


func fresh_settings() -> Settings:
	var s := Settings.new()
	s.path = "user://settings_narrow_test.cfg"
	return s


## Each screen as a player meets it, ready to push.
func screens() -> Dictionary:
	var title := TitleScreen.new()
	var join := JoinScreen.new()
	var look := JoinScreen.new()
	look.look_only = true
	var menu := GameMenu.new()
	menu.settings_available = true
	menu.title_available = true
	var picker := StylePicker.new()
	picker.styles = all_styles()
	picker.current = "res://styles/anime_cel"
	var settings := SettingsScreen.new()
	settings.settings = fresh_settings()
	var rebind := RebindScreen.new()
	rebind.settings = settings.settings
	var hud := PlayHud.new()
	hud.glyphs = InputGlyphs.new()
	var about := AboutScreen.new()
	return {"title": title, "join": join, "join-look": look, "menu": menu, "styles": picker,
		"settings": settings, "rebind": rebind, "hud": hud, "about": about}


## The shown controls of `node` that lie outside `bounds`, as names; a
## scrolling list's rows are left out, since they scroll into view.
func outside(node: Node, bounds: Rect2) -> Array:
	var out := []
	for child in node.get_children():
		if child is CanvasItem and not child.visible:
			continue
		if child is Control:
			var r: Rect2 = child.get_global_rect()
			if r.size.x > 0 and r.size.y > 0 and not bounds.grow(1.0).encloses(r):
				out.append("%s %s" % [child.name, r])
		if not (child is ScrollContainer):
			out.append_array(outside(child, bounds))
	return out


func settle(n := 3) -> void:
	for f in n:
		await runner.process_frame


func test_every_screen_fits_the_window_in_every_style() -> void:
	for size in SIZES:
		for style in STYLES:
			var all := screens()
			for key in all:
				var stack := stage(size, style)
				var screen: Screen = all[key]
				stack.push(screen)
				if key == "join-look":
					screen.choose("registered")
				if key == "menu":
					screen.header.text = "Visitor · walking"
				await settle()
				var bounds := Rect2(Vector2.ZERO, Vector2(size))
				var off := outside(screen, bounds)
				assert_true(off.is_empty(), "%s %s at %s: every control on screen, not %s" % [style, key, size, str(off.slice(0, 3))])
				stack.get_parent().free()


func test_the_picker_has_two_columns_below_900_pixels() -> void:
	var stack := stage(Vector2i(800, 900), "anime_cel")
	var picker := StylePicker.new()
	picker.styles = all_styles()
	stack.push(picker)
	await settle()
	assert_eq(picker.grid.columns, 2, "two columns at 800 wide")
	var vp: Viewport = picker.get_viewport()
	picker.cards[0].grab_focus()
	vp.push_input(pad(JOY_BUTTON_DPAD_DOWN))
	assert_eq(vp.gui_get_focus_owner(), picker.cards[2], "down a row of two")
	stack.get_parent().free()
	stack = stage(Vector2i(1280, 720), "anime_cel")
	picker = StylePicker.new()
	picker.styles = all_styles()
	stack.push(picker)
	await settle()
	assert_eq(picker.grid.columns, 3, "three columns at 1280 wide")
	stack.get_parent().free()


func test_the_hud_chips_stack_rather_than_overlap_when_narrow() -> void:
	for style in STYLES:
		var stack := stage(Vector2i(800, 900), style)
		var hud := PlayHud.new()
		hud.glyphs = InputGlyphs.new()
		stack.push(hud)
		await settle()
		var fixture: Rect2 = hud.fixture.get_parent().get_global_rect()
		var hints: Rect2 = hud.hints.get_parent().get_global_rect()
		assert_true(not fixture.intersects(hints), "%s: the fixture notice %s clear of the hints %s" % [style, fixture, hints])
		stack.get_parent().free()


func test_the_title_fixture_notice_is_legible_in_a_pixel_font() -> void:
	# A 10 px pixel face cannot be read at half size: the notice takes the
	# next whole step of its grid, and other faces keep their 14 px.
	for style in ["pixel_art", "anime_cel"]:
		var stack := stage(Vector2i(1920, 1080), style)
		var title := TitleScreen.new()
		stack.push(title)
		var size := title.fixture.get_theme_font_size("font_size")
		assert_eq(size, 20 if style == "pixel_art" else 14, style + " fixture notice size")
		stack.get_parent().free()


func test_the_title_name_is_smaller_only_in_the_narrow_layout() -> void:
	for size in [Vector2i(1280, 720), Vector2i(800, 900)]:
		var stack := stage(size, "pixel_art")
		var title := TitleScreen.new()
		stack.push(title)
		var want := TitleScreen.NAME_SIZE if size.x >= 900 else TitleScreen.NARROW_NAME_SIZE
		assert_eq(title.name_label.get_theme_font_size("font_size"), stack.ui.display_size(want), "the name at %s" % size)
		stack.get_parent().free()


func pad(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e


## At 880 px, still the narrow layout: neon's six page names fit as they
## are (with the Station computer page, they no longer do at 800).
func test_page_names_shrink_only_when_they_would_not_fit() -> void:
	var sizes := {}
	for style in ["pixel_art", "neon_noir"]:
		var stack := stage(Vector2i(880, 900), style)
		var settings := SettingsScreen.new()
		settings.settings = fresh_settings()
		stack.push(settings)
		await settle()
		sizes[style] = settings.tabs.has_theme_font_size_override("font_size")
		stack.get_parent().free()
	assert_eq(sizes, {"pixel_art": true, "neon_noir": false}, "pixel art's wide names shrink; neon's fit as they are")
