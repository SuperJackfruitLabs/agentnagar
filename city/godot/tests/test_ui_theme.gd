extends TestSuite

func style(ui: Dictionary) -> Dictionary:
	return {"name": "T", "ui": ui}


func test_defaults_fill_a_style_without_a_ui_block() -> void:
	var t := UiTheme.from_style({"name": "Plain"})
	assert_eq(t.colour("panel"), Color("#F7F8FB"), "default panel")
	assert_eq(t.focus_mode(), "ring", "default focus")
	assert_true(t.theme.has_stylebox("panel", "PanelContainer"), "panel stylebox")
	assert_true(t.theme.has_stylebox("focus", "Button"), "focus stylebox")


func test_a_style_overrides_only_what_it_names() -> void:
	var t := UiTheme.from_style(style({"colours": {"accent": "#FF0000"}, "button": {"case": "upper"}}))
	assert_eq(t.colour("accent"), Color("#FF0000"), "accent overridden")
	assert_eq(t.colour("ink"), Color("#1F2433"), "ink kept from default")
	assert_eq(t.case("resume game"), "RESUME GAME", "upper case")
	assert_eq(int(t.spec["button"]["radius"]), 10, "nested default kept")


func test_contrast_matches_known_ratios() -> void:
	assert_true(absf(UiTheme.contrast(Color.BLACK, Color.WHITE) - 21.0) < 0.01, "black on white is 21")
	assert_true(absf(UiTheme.contrast(Color("#777777"), Color.WHITE) - 4.48) < 0.02, "#777 on white is 4.48")


func test_text_size_scales_and_pixel_fonts_snap() -> void:
	assert_eq(UiTheme.from_style({}, 1.25).font_size(20), 25, "scaled")
	var px := UiTheme.from_style(style({"pixel_font": true, "pixel_base": 10}), 1.25)
	assert_eq(px.font_size(20), 20, "pixel font snaps to a whole multiple of 10")
	var px2 := UiTheme.from_style(style({"pixel_font": true, "pixel_base": 10}), 1.5)
	assert_eq(px2.font_size(20), 30, "1.5x of 20 is 30, a whole multiple")


func test_every_style_meets_the_contrast_floors() -> void:
	for dir in ["anime_cel", "solarpunk", "neon_noir", "pixel_art", "lowpoly_tropical", "voxel"]:
		var f := FileAccess.open("res://styles/%s/style.json" % dir, FileAccess.READ)
		var t := UiTheme.from_style(JSON.parse_string(f.get_as_text()))
		assert_true(UiTheme.contrast(t.colour("ink"), t.colour("panel")) >= 4.5, dir + ": ink on panel")
		assert_true(UiTheme.contrast(t.colour("accent_ink"), t.colour("accent")) >= 4.5, dir + ": accent ink")
		assert_true(UiTheme.contrast(t.colour("focus"), t.colour("panel")) >= 3.0, dir + ": focus")


func test_every_style_has_its_own_ui_block() -> void:
	for dir in ["anime_cel", "solarpunk", "neon_noir", "pixel_art", "lowpoly_tropical", "voxel"]:
		var f := FileAccess.open("res://styles/%s/style.json" % dir, FileAccess.READ)
		var st: Dictionary = JSON.parse_string(f.get_as_text())
		assert_true(st.get("ui") is Dictionary, dir + " has a ui block")


func test_every_style_font_loads() -> void:
	for dir in ["anime_cel", "solarpunk", "neon_noir", "pixel_art", "lowpoly_tropical", "voxel"]:
		var f := FileAccess.open("res://styles/%s/style.json" % dir, FileAccess.READ)
		var st: Dictionary = JSON.parse_string(f.get_as_text())
		for k in ["font_display", "font_body"]:
			assert_true(ResourceLoader.exists(st["ui"][k]), "%s %s exists" % [dir, k])


func test_every_style_font_is_its_own_not_the_fallback() -> void:
	for dir in ["anime_cel", "solarpunk", "neon_noir", "pixel_art", "lowpoly_tropical", "voxel"]:
		var f := FileAccess.open("res://styles/%s/style.json" % dir, FileAccess.READ)
		var t := UiTheme.from_style(JSON.parse_string(f.get_as_text()))
		assert_true(t.display_font != ThemeDB.fallback_font, dir + ": display font loaded")
		assert_true(t.body_font != ThemeDB.fallback_font, dir + ": body font loaded")
		assert_true(t.display_font != t.body_font, dir + ": two faces, display and body")


func test_a_nine_shape_draws_the_frame_texture() -> void:
	for pair in [["solarpunk", "panel"], ["pixel_art", "panel"], ["pixel_art", "button"]]:
		var f := FileAccess.open("res://styles/%s/style.json" % pair[0], FileAccess.READ)
		var t := UiTheme.from_style(JSON.parse_string(f.get_as_text()))
		var sb: StyleBox
		if pair[1] == "panel":
			sb = t.theme.get_stylebox("panel", "PanelContainer")
		else:
			sb = t.theme.get_stylebox("normal", "Button")
		assert_true(sb is StyleBoxTexture, "%s %s is a nine-slice" % pair)
		assert_true((sb as StyleBoxTexture).texture != null, "%s %s has its frame" % pair)
		assert_eq(int((sb as StyleBoxTexture).texture_margin_left), int(t.spec["frame"]["margin"]), "%s %s margin" % pair)


func test_nine_buttons_show_hover_and_press() -> void:
	var f := FileAccess.open("res://styles/pixel_art/style.json", FileAccess.READ)
	var t := UiTheme.from_style(JSON.parse_string(f.get_as_text()))
	var normal: StyleBoxTexture = t.theme.get_stylebox("normal", "Button")
	var hover: StyleBoxTexture = t.theme.get_stylebox("hover", "Button")
	var pressed: StyleBoxTexture = t.theme.get_stylebox("pressed", "Button")
	assert_true(hover.modulate_color != normal.modulate_color, "hover differs from normal")
	assert_true(pressed.modulate_color != normal.modulate_color, "pressed differs from normal")
	for box in [normal, hover, pressed]:
		assert_true(box.content_margin_left >= box.texture_margin_left + 10, "text clear of the frame at the left")
		assert_true(box.content_margin_right >= box.texture_margin_right + 10, "and at the right")


func test_neon_and_pixel_art_glow() -> void:
	var modes := {}
	for dir in ["anime_cel", "solarpunk", "neon_noir", "pixel_art", "lowpoly_tropical", "voxel"]:
		var f := FileAccess.open("res://styles/%s/style.json" % dir, FileAccess.READ)
		modes[dir] = UiTheme.from_style(JSON.parse_string(f.get_as_text())).focus_mode()
	assert_eq(modes["neon_noir"], "glow", "neon glows")
	assert_eq(modes["pixel_art"], "glow", "pixel art glows")
	assert_eq(modes["voxel"], "ring", "voxel rings")


func test_the_glow_colour_is_the_focus_colour_at_sixty_percent() -> void:
	var t := UiTheme.from_style(style({"focus": "glow", "colours": {"focus": "#35D6FF"}}))
	var c: Color = t.glow_colour()
	assert_true(absf(c.a - 0.6) < 0.001, "60% alpha")
	assert_true(c.r8 == 0x35 and c.g8 == 0xD6 and c.b8 == 0xFF, "the focus colour")


func test_a_button_keeps_its_ink_in_every_state() -> void:
	# A state left unset takes the engine's light text, which vanishes on
	# a light button (solarpunk's cream).
	var t := UiTheme.from_style(style({"colours": {"accent": "#F3EEDF", "accent_ink": "#123C3A"}}))
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		assert_true(t.theme.has_color(state, "Button"), state + " set")
		assert_eq(t.theme.get_color(state, "Button"), Color("#123C3A"), state + " is the accent ink")


func test_each_pixel_font_snaps_to_its_own_grid() -> void:
	var t := UiTheme.from_style(style({"pixel_font": true, "pixel_base": 8, "pixel_base_body": 10}))
	assert_eq(t.display_size(24), 24, "display text on the display face's 8 px grid")
	assert_eq(t.display_size(72), 72, "72 is nine steps of 8")
	assert_eq(t.font_size(24), 20, "body text on the body face's 10 px grid")
	assert_eq(t.font_size(30), 30, "30 is three steps of 10")
	assert_eq(t.theme.default_font_size, t.font_size(20), "the theme's body text on the body grid")
	var shared := UiTheme.from_style(style({"pixel_font": true, "pixel_base": 8}))
	assert_eq(shared.font_size(24), 24, "the body grid defaults to pixel_base")
	assert_eq(UiTheme.from_style({}, 1.25).display_size(20), 25, "a smooth font scales the same either way")


func test_pixel_art_draws_each_face_on_its_grid() -> void:
	var f := FileAccess.open("res://styles/pixel_art/style.json", FileAccess.READ)
	var t := UiTheme.from_style(JSON.parse_string(f.get_as_text()))
	for base in [14, 20, 24, 28, 30, 72]:
		assert_eq(t.display_size(base) % 8, 0, "Press Start 2P at %d px" % t.display_size(base))
		assert_eq(t.font_size(base) % 10, 0, "Pixelify Sans at %d px" % t.font_size(base))
