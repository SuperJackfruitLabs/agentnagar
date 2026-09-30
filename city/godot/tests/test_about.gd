## The About screen (GNU AGPL section 13): reached from the game menu and
## the title, it shows the version, the licence line, the source's address
## with a button that opens it, and the third-party notices and the licence
## in a scrolling view, all driven by keys and the d-pad.
extends TestSuite

const TEMP := "user://about_test"


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


func pad(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e


## A window-sized viewport holding a stack, in the tree.
func stage() -> ScreenStack:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	runner.root.add_child(viewport)
	var stack := ScreenStack.new()
	stack.ui = UiTheme.from_style({})
	viewport.add_child(stack)
	return stack


## Writes `text` to a file of its own under TEMP, and returns its path.
func temp_file(file_name: String, text: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP))
	var path := TEMP.path_join(file_name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	return path


## An About screen reading `notices` and `licence` from files of its own.
func about_with(notices: String, licence: String) -> AboutScreen:
	var about := AboutScreen.new()
	about.view_paths = [
		["user://about_test/none.txt", temp_file("notices.txt", notices)],
		[temp_file("licence.txt", licence)],
	]
	return about


## Waits until the threaded text view has laid its text out.
func laid_out(about: AboutScreen) -> void:
	for i in 600:
		if about.text.is_finished():
			break
		await runner.process_frame
	await runner.process_frame
	await runner.process_frame


func test_the_game_menu_opens_about() -> void:
	var main = booted()
	main.router.handle(esc())
	var menu: GameMenu = main.stack.top()
	var button: Button = menu.action_button("About")
	assert_true(button.visible, "About is on the menu")
	button.pressed.emit()
	assert_true(main.stack.top() is AboutScreen, "About opens")
	assert_true(not menu.panel.visible, "the menu steps aside under it")
	main.stack.back()
	assert_eq(main.stack.top(), menu, "Back returns to the menu")
	assert_true(menu.panel.visible, "shown again")
	main.free()


func test_the_title_opens_about() -> void:
	var main = load("res://main.gd").new()
	main.settings_path = "user://test_about_title.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.settings_path))
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--title"]), "res://tests/fixtures")
	var title: TitleScreen = main.stack.top()
	assert_true(title.action_button("About").visible, "About is on the title")
	title.action_button("About").pressed.emit()
	assert_true(main.stack.top() is AboutScreen, "About opens over the title")
	main.stack.back()
	assert_eq(main.stack.top(), title, "Back returns to the title")
	main.free()


func test_it_shows_the_version_the_licence_and_the_source() -> void:
	var stack := stage()
	var about := AboutScreen.new()
	stack.push(about)
	assert_eq(about.licence_label.text, "Agentnagar is free software under the GNU AGPL v3.", "the licence line")
	assert_true("Super Jackfruit Labs (OPC) Private Limited" in about.copyright_label.text, "the copyright holder")
	assert_true("no warranty" in about.warranty_label.text, "no warranty")
	assert_eq(about.url_label.text, AboutScreen.source_url(), "the source's address, as text")
	assert_true(about.url_label.text.begins_with("https://github.com/SuperJackfruitLabs/agentnagar"), "the repository")
	assert_eq(about.version_label.text, AboutScreen.version_text(), "the version")
	stack.get_parent().free()


func test_the_version_comes_from_the_project_setting() -> void:
	var key := "application/config/version"
	var had := ProjectSettings.has_setting(key)
	var before = ProjectSettings.get_setting(key, "")
	ProjectSettings.set_setting(key, "9.9.9")
	assert_eq(AboutScreen.version_text(), "Version 9.9.9", "a package's version")
	ProjectSettings.set_setting(key, "")
	assert_eq(AboutScreen.version_text(), "Development build", "none set")
	if had:
		ProjectSettings.set_setting(key, before)
	else:
		ProjectSettings.set_setting(key, null)


func test_the_link_points_at_the_source_of_this_version() -> void:
	var repo := "https://github.com/SuperJackfruitLabs/agentnagar"
	assert_eq(AboutScreen.source_url("v0.0.4"), repo + "/tree/v0.0.4", "a release: its tag")
	assert_eq(AboutScreen.source_url("0.0.4"), repo + "/tree/v0.0.4", "a release without the v: its tag")
	assert_eq(AboutScreen.source_url("v0.0.3-77-g24a43a1"), repo + "/tree/24a43a1", "git describe: its commit")
	assert_eq(AboutScreen.source_url("24a43a1"), repo + "/tree/24a43a1", "a bare commit")
	assert_eq(AboutScreen.source_url("v0.0.3-77-g24a43a1-dirty"), repo, "uncommitted changes: the repository")
	var key := "application/config/version"
	var had := ProjectSettings.has_setting(key)
	var before = ProjectSettings.get_setting(key, "")
	ProjectSettings.set_setting(key, "")
	assert_eq(AboutScreen.source_url(), repo, "a development build: the repository")
	ProjectSettings.set_setting(key, "v1.2.3")
	assert_eq(AboutScreen.source_url(), repo + "/tree/v1.2.3", "the project's version")
	if had:
		ProjectSettings.set_setting(key, before)
	else:
		ProjectSettings.set_setting(key, null)


func test_the_source_button_opens_the_repository() -> void:
	var stack := stage()
	var about := AboutScreen.new()
	var opened := []
	about.opener = func(url): opened.append(url)
	stack.push(about)
	assert_eq(about.get_viewport().gui_get_focus_owner(), about.source_button, "the link has the focus first")
	about.source_button.pressed.emit()
	assert_eq(opened, [AboutScreen.source_url()], "it opens this build's source")
	stack.get_parent().free()


func test_the_texts_come_from_their_files() -> void:
	var stack := stage()
	var about := about_with("NOTICES: Godot Engine, godot-rust, the fonts", "GNU AFFERO GENERAL PUBLIC LICENSE")
	stack.push(about)
	assert_eq(about.tabs.current_tab, 0, "the notices first")
	assert_true(about.text.text.begins_with("NOTICES:"), "from the first file found")
	about.view_step(1)
	assert_eq(about.tabs.current_tab, 1, "then the licence")
	assert_eq(about.text.text, "GNU AFFERO GENERAL PUBLIC LICENSE", "from its file")
	about.view_step(1)
	assert_eq(about.tabs.current_tab, 0, "wrapping round")
	stack.get_parent().free()


func test_without_the_files_it_shows_the_engines_notices() -> void:
	var stack := stage()
	var about := AboutScreen.new()
	about.view_paths = [["user://about_test/none.txt"], ["user://about_test/none.txt"]]
	stack.push(about)
	var shown := about.text.text
	assert_true(shown.begins_with(AboutScreen.NOTICES_MISSING), "says where the full notices are")
	assert_true("Godot Engine" in shown and Engine.get_license_text() in shown, "the engine's licence")
	assert_true("FreeType" in shown, "and its components'")
	about.view_step(1)
	assert_eq(about.text.text, AboutScreen.LICENCE_MISSING, "the licence's place")
	stack.get_parent().free()


func test_the_texts_are_looked_for_in_the_package_then_the_repository() -> void:
	var notices := CityPaths.licence_paths("THIRD-PARTY-NOTICES.txt")
	assert_eq(notices[0], "res://licenses/THIRD-PARTY-NOTICES.txt", "the package's copy first")
	assert_eq(notices.size(), 2, "and, from a checkout, the repository's")
	assert_eq(notices[1], CityPaths.repo_root().path_join("THIRD-PARTY-NOTICES.txt"), "at its root")
	assert_eq(CityPaths.licence_paths("LICENSE.txt")[1], CityPaths.repo_root().path_join("LICENSE"), "LICENSE, without an extension")
	assert_true(FileAccess.file_exists(CityPaths.repo_root().path_join("city/README.md")), "the root is the repository's")


func test_back_and_its_button_close_it() -> void:
	var stack := stage()
	var below := AboutScreen.new()
	stack.push(below)
	var about := AboutScreen.new()
	stack.push(about)
	about.get_viewport().push_input(esc())
	assert_eq(stack.top(), below, "Esc closes it")
	below.back_button.pressed.emit()
	await runner.process_frame
	assert_eq(stack.top(), null, "and so does its Back button")
	stack.get_parent().free()


func test_the_d_pad_reaches_the_link_the_text_and_back_and_scrolls_the_text() -> void:
	var stack := stage()
	var long := ""
	for i in 400:
		long += "Line %d of the notices\n" % i
	var about := about_with(long, "licence")
	stack.push(about)
	await laid_out(about)
	var vp: Viewport = about.get_viewport()
	assert_eq(vp.gui_get_focus_owner(), about.source_button, "the link first")
	vp.push_input(pad(JOY_BUTTON_DPAD_DOWN))
	assert_eq(vp.gui_get_focus_owner(), about.text, "down to the text")
	assert_true(about.at_top(), "at its top")
	vp.push_input(pad(JOY_BUTTON_DPAD_DOWN))
	assert_eq(vp.gui_get_focus_owner(), about.text, "down again stays on the text")
	assert_true(not about.at_top(), "and scrolls it")
	var line := about.text.get_v_scroll_bar().value
	vp.push_input(pad(JOY_BUTTON_DPAD_RIGHT))
	assert_true(about.text.get_v_scroll_bar().value > line + about.text.size.y * 0.5, "right scrolls a page")
	vp.push_input(key(KEY_PAGEDOWN))
	var paged := about.text.get_v_scroll_bar().value
	assert_true(paged > line + about.text.size.y, "Page Down too")
	vp.push_input(pad(JOY_BUTTON_DPAD_LEFT))
	assert_true(about.text.get_v_scroll_bar().value < paged, "left scrolls back")
	# Down runs to the end and then on to Back.
	for i in 2000:
		if vp.gui_get_focus_owner() != about.text:
			break
		vp.push_input(pad(JOY_BUTTON_DPAD_RIGHT) if not about.at_end() else pad(JOY_BUTTON_DPAD_DOWN))
	assert_eq(vp.gui_get_focus_owner(), about.back_button, "down at the end reaches Back")
	vp.push_input(pad(JOY_BUTTON_DPAD_DOWN))
	assert_eq(vp.gui_get_focus_owner(), about.source_button, "and wraps to the link")
	vp.push_input(pad(JOY_BUTTON_DPAD_UP))
	assert_eq(vp.gui_get_focus_owner(), about.back_button, "up wraps to Back")
	stack.get_parent().free()


func test_up_at_the_top_of_the_text_returns_to_the_link() -> void:
	var stack := stage()
	var about := about_with("short", "licence")
	stack.push(about)
	await laid_out(about)
	about.text.grab_focus()
	var vp: Viewport = about.get_viewport()
	vp.push_input(pad(JOY_BUTTON_DPAD_UP))
	assert_eq(vp.gui_get_focus_owner(), about.source_button, "up at the top")
	stack.get_parent().free()


func test_q_e_and_the_shoulders_switch_the_view() -> void:
	var stack := stage()
	var about := about_with("notices", "licence")
	stack.push(about)
	var vp: Viewport = about.get_viewport()
	vp.push_input(key(KEY_E))
	assert_eq(about.text.text, "licence", "E: the licence")
	vp.push_input(key(KEY_Q))
	assert_eq(about.text.text, "notices", "Q: the notices")
	vp.push_input(pad(JOY_BUTTON_RIGHT_SHOULDER))
	assert_eq(about.tabs.current_tab, 1, "RB")
	vp.push_input(pad(JOY_BUTTON_LEFT_SHOULDER))
	assert_eq(about.tabs.current_tab, 0, "LB")
	stack.get_parent().free()


func test_the_text_is_legible_in_every_skin() -> void:
	for style in ["anime_cel", "pixel_art", "neon_noir"]:
		var stack := stage()
		stack.ui = UiTheme.from_style(JSON.parse_string(FileAccess.get_file_as_string("res://styles/%s/style.json" % style)))
		var about := about_with("notices", "licence")
		stack.push(about)
		var ink: Color = about.text.get_theme_color("default_color")
		assert_eq(ink, stack.ui.colour("ink"), style + ": the skin's ink")
		assert_true(UiTheme.contrast(ink, stack.ui.colour("panel")) >= 4.5, style + ": readable on the panel")
		var face: Font = about.text.get_theme_font("normal_font")
		assert_eq(face, ThemeDB.fallback_font if style == "pixel_art" else stack.ui.body_font, style + ": the face")
		stack.get_parent().free()
