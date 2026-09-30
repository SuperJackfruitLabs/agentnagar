extends TestSuite

func titled():
	var main = load("res://main.gd").new()
	main.settings_path = "user://test_title.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.settings_path))
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--title"]), "res://tests/fixtures")
	return main


func test_title_first_with_no_player() -> void:
	var main = titled()
	assert_true(main.stack.top() is TitleScreen, "title")
	assert_eq(main.player.id, "", "nobody joined")
	assert_true(main.hud.fixture.visible or main.stack.top().find_child("Fixture", true, false) != null, "fixture notice on the title")
	main.free()


func test_explore_on_first_launch_asks_and_joins() -> void:
	var main = titled()
	main.stack.top().explore.emit()
	var j: JoinScreen = main.stack.top()
	assert_true(j is JoinScreen, "asks how to enter")
	j.done.emit("registered", "3,1")
	assert_true(main.player.id != "", "joined")
	assert_eq(main.stack.top(), main.hud, "in play")
	assert_eq(main.settings.get_value("interface", "join_as"), "registered", "remembered")
	main.free()


func test_just_watch_joins_nobody() -> void:
	var main = titled()
	main.stack.top().explore.emit()
	main.stack.top().done.emit("none", "0,0")
	assert_eq(main.player.id, "", "watching")
	assert_eq(main.stack.top(), main.hud, "in play")
	main.free()


func test_a_later_launch_skips_the_question() -> void:
	var main = titled()
	main.settings.set_value("interface", "join_as", "observer")
	main.stack.top().explore.emit()
	assert_true(main.player.id != "", "joined straight away")
	assert_true(main.player.observer, "as an observer")
	main.free()


func test_quit_to_title_leaves_and_explore_joins_again() -> void:
	var main = titled()
	main.settings.set_value("interface", "join_as", "registered")
	main.stack.top().explore.emit()
	var first: String = main.player.id
	main.quit_to_title()
	assert_true(main.stack.top() is TitleScreen, "title again")
	assert_eq(main.player.id, "", "left")
	main.stack.top().explore.emit()
	assert_true(main.player.id != "", "joined again")
	main.free()


func test_play_arguments_skip_the_title() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack", "--as=none"]), "res://tests/fixtures")
	assert_eq(main.stack.top(), main.hud, "straight to play")
	main.free()


# ---- Beyond the brief's six ----

func test_the_title_card_and_its_menu() -> void:
	var main = titled()
	var t: TitleScreen = main.stack.top()
	assert_eq(main.stack.screens.size(), 2, "the HUD under the title, and nothing else")
	assert_eq(main.stack.screens[0], main.hud, "the HUD at the bottom")
	assert_true(not main.hud.visible, "hidden on the title")
	assert_eq(t.name_label.text, "AGENTNAGAR", "the name, upper case")
	# The headless window is 64 px wide, the narrow layout; the full size
	# is checked in test_narrow_layout.gd.
	assert_eq(t.name_label.get_theme_font_size("font_size"), main.ui.display_size(TitleScreen.NARROW_NAME_SIZE), "large")
	assert_eq(t.name_label.get_theme_font("font"), main.ui.display_font, "in the display font")
	var names := []
	for b in t.buttons:
		names.append(str(b.name))
	assert_eq(names, ["Explore", "Map & read", "Settings", "About", "Quit"], "the five actions, in order")
	assert_true(t.action_button("Map & read").visible, "the map is there to read")
	assert_eq(t.action_button("Quit").visible, not OS.has_feature("web"), "Quit only off the web")
	assert_eq(t.get_viewport().gui_get_focus_owner(), t.action_button("Explore"), "Explore has the focus")
	var fixture: Label = t.find_child("Fixture", true, false)
	assert_true(fixture != null and fixture.text == PlayHud.BANNER, "the fixture line on the title")
	assert_true(not main.router.world_enabled, "no walking, no camera on the title")
	main.free()


func test_the_card_steps_aside_for_a_screen_over_it() -> void:
	var main = titled()
	var t: TitleScreen = main.stack.top()
	t.explore.emit()
	assert_true(not t.panel.visible, "hidden under the Join screen")
	assert_true(t.fixture.is_visible_in_tree(), "the fixture line stays")
	main.stack.back()
	assert_true(t.panel.visible, "back again")
	main.free()


func test_back_does_nothing_on_the_title() -> void:
	var main = titled()
	var t = main.stack.top()
	main.stack.back()
	assert_eq(main.stack.top(), t, "still the title")
	main.router.menu.emit()
	assert_eq(main.stack.top(), t, "Esc opens no game menu over it")
	main.free()


func test_the_d_pad_runs_round_the_title_menu() -> void:
	var main = titled()
	var t: TitleScreen = main.stack.top()
	var explore := t.action_button("Explore")
	var map := t.action_button("Map & read")
	var quit := t.action_button("Quit")
	assert_eq(explore.get_node(explore.focus_neighbor_bottom), map, "down to Map & read")
	assert_eq(explore.get_node(explore.focus_neighbor_top), quit if quit.visible else t.action_button("Settings"), "up wraps to the last")
	main.free()


func test_settings_from_the_title_and_back() -> void:
	var main = titled()
	var t = main.stack.top()
	t.open_settings.emit()
	assert_true(main.stack.top() is SettingsScreen, "settings open over the title")
	main.stack.back()
	assert_eq(main.stack.top(), t, "back to the title")
	main.free()


func test_the_title_starts_in_the_last_used_style() -> void:
	var path := "user://test_title_style.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var saved := Settings.new()
	saved.path = path
	saved.set_value("interface", "style", "pixel_art")
	var main = load("res://main.gd").new()
	main.settings_path = path
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--title"]))
	assert_eq(main.host.pack_dir.get_file(), "pixel_art", "the style last chosen")
	main.free()


func test_a_first_launch_starts_in_the_first_style_by_order() -> void:
	var main = titled()
	assert_eq(main.host.pack_dir.get_file(), "fake_pack", "order 1")
	main.free()
	var path := "user://test_title_style.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var saved := Settings.new()
	saved.path = path
	saved.set_value("interface", "style", "no_such_style")
	main = load("res://main.gd").new()
	main.settings_path = path
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--title"]), "res://tests/fixtures")
	assert_eq(main.host.pack_dir.get_file(), "fake_pack", "a style that is gone falls back to the first")
	main.free()


func test_style_on_the_command_line_wins_over_the_saved_one() -> void:
	var path := "user://test_title_style.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var saved := Settings.new()
	saved.path = path
	saved.set_value("interface", "style", "broken_pack")
	var main = load("res://main.gd").new()
	main.settings_path = path
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack", "--as=none"]), "res://tests/fixtures")
	assert_eq(main.host.pack_dir.get_file(), "fake_pack", "--style chosen")
	main.free()


func test_who_gets_the_title() -> void:
	var o := CityArgs.parse(PackedStringArray([]))
	assert_true(CityArgs.shows_title(o, false), "a plain launch")
	assert_true(not CityArgs.shows_title(o, true), "not a test or a tool")
	o = CityArgs.parse(PackedStringArray(["--as=observer"]))
	assert_true(not CityArgs.shows_title(o, false), "play arguments go straight to play")
	o = CityArgs.parse(PackedStringArray(["--title", "--style=voxel"]))
	assert_true(CityArgs.shows_title(o, true), "--title forces it")


func test_tools_boot_straight_to_play() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot_for_tool(PackedStringArray(["--crowd=0"]), "res://tests/fixtures")
	assert_eq(main.stack.top(), main.hud, "the bench and the audit are unchanged")
	main.free()


func test_the_title_drifts_and_explore_flies_down() -> void:
	var main = titled()
	var pack = main.host.pack
	assert_true(pack.drift, "the camera drifts behind the title")
	main.settings.set_value("interface", "join_as", "none")
	main.stack.top().explore.emit()
	assert_true(not pack.drift, "the drift stops")
	assert_eq(pack.flights, [[main.square_centre(), 1.2]], "Just watch flies to the square")
	assert_true(main.hud.visible, "the HUD shows")
	main.free()


func test_calm_mode_neither_drifts_nor_flies() -> void:
	var path := "user://test_title_calm.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var saved := Settings.new()
	saved.path = path
	saved.set_value("accessibility", "calm", true)
	saved.set_value("interface", "join_as", "none")
	var main = load("res://main.gd").new()
	main.settings_path = path
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--title"]), "res://tests/fixtures")
	var pack = main.host.pack
	assert_true(not pack.drift, "no drift")
	main.stack.top().explore.emit()
	assert_eq(pack.flights, [[main.square_centre(), 0.0]], "a cut")
	main.free()


func test_calm_mode_turned_on_at_the_title_stops_the_drift() -> void:
	var main = titled()
	main.settings.set_value("accessibility", "calm", true)
	assert_true(not main.host.pack.drift, "stopped")
	main.settings.set_value("accessibility", "calm", false)
	assert_true(main.host.pack.drift, "drifting again")
	main.free()


## The prompt the HUD shows now, or "" with none.
func prompt(main) -> String:
	return main.hud.prompt_label.text if main.hud.prompt.visible else ""


## Joining by tram, Explore flies the view to the Square's stop at once,
## where the player will step off, and while the player waits to ride in
## the HUD counts down to its tram reaching the Square: the true count,
## tick by tick. Once the player is on the ground no second flight comes.
func test_explore_frames_the_square_stop_and_counts_down_to_the_tram() -> void:
	var main = titled()
	main.set_process(false)
	main.driver.set_process(false)
	# Joining at 5, east:1 (entering at 1) has gone by: the next to reach
	# the Square is east:2, entering at 31.
	for i in 5:
		main.driver.step_once()
	main.settings.set_value("interface", "join_as", "registered")
	main.stack.top().explore.emit()
	var pack = main.host.pack
	var stop := CityGeometry.rect_m(CityGeometry.room_of(main.manifest, "room:tram-stop")["rect"]).get_center() * 100.0
	assert_eq(pack.flights, [[stop, 1.2]], "down to the Square's stop, where the player steps off, at once")
	var shown := {}
	var off := -1
	for i in 60:
		main._process(0.0)
		if main.player.present:
			off = main.driver.world.tick()
			break
		if not main.player.aboard:
			var m := RegEx.create_from_string("^Your tram reaches the Square in (\\d+) s$").search(prompt(main))
			assert_true(m != null, "waiting to ride in: " + prompt(main))
			if m != null:
				shown[main.driver.world.tick()] = int(m.get_string(1))
		main.driver.step_once()
	assert_true(off > 0, "rode in and stepped off")
	assert_true(shown.size() > 20, "counted down while it waited: %d ticks" % shown.size())
	for t in shown:
		assert_eq(shown[t], off - t, "at tick %d the countdown is the ticks to the Square" % t)
	assert_eq(pack.flights.size(), 1, "no second flight")
	main.free()


func test_quit_to_title_puts_the_title_back_as_it_was() -> void:
	var main = titled()
	main.settings.set_value("interface", "join_as", "registered")
	main.stack.top().explore.emit()
	main.router.menu.emit()
	var menu: GameMenu = main.stack.top()
	assert_true(menu is GameMenu, "the game menu")
	assert_true(menu.action_button("Quit to title").visible, "Quit to title is offered")
	menu.quit_to_title.emit()
	assert_true(main.stack.top() is TitleScreen, "the title")
	assert_eq(main.stack.screens.size(), 2, "the HUD under the title, and nothing else")
	assert_true(not main.hud.visible, "the HUD hidden")
	assert_true(main.host.pack.drift, "drifting again")
	assert_eq(main.host.avatar_id, "", "no avatar")
	assert_eq(main.driver.viewer, "public", "the public view")
	assert_true(not main.router.world_enabled, "no walking")
	main.free()


## Quit to title and then Explore joins again straight away: the last
## visit leaves on the next tick (a player's leave is at once, never a walk
## to a platform and a ride out), the HUD meanwhile shows the wait, and
## the new visit rides in on the soonest tram as a first one does.
func test_quit_to_title_then_explore_joins_within_a_tick() -> void:
	var main = titled()
	main.set_process(false)
	main.driver.set_process(false)
	main.settings.set_value("interface", "join_as", "registered")
	main.stack.top().explore.emit()
	for i in 45:
		if main.player.present:
			break
		main.driver.step_once()
	assert_true(main.player.present, "the first visit rode in")
	main.quit_to_title()
	main.stack.top().explore.emit()
	assert_eq(main.player.id, "", "the core refuses a second arrival until the first has gone")
	main._process(0.0)
	assert_true(prompt(main).begins_with("Your tram reaches the Square in "), "the wait is shown: " + prompt(main))
	main.driver.step_once()
	main._process(0.0)
	assert_true(main.player.id != "", "joined on the next tick")
	var arrived := -1
	for i in 45:
		if main.player.present:
			arrived = i
			break
		main.driver.step_once()
	assert_true(arrived >= 0, "and rode in, as a first visit does")
	main.free()


func test_settings_look_row_changes_the_look_only() -> void:
	var main = titled()
	main.settings.set_value("interface", "join_as", "observer")
	main.stack.top().open_settings.emit()
	var s: SettingsScreen = main.stack.top()
	assert_true(s.find_child("look", true, false).visible, "the Look row shows")
	s.open_look.emit()
	var j: JoinScreen = main.stack.top()
	assert_true(j is JoinScreen and j.look_only, "the look step alone")
	assert_eq(j.join_as, "observer", "as saved")
	j.done.emit("observer", "5,2")
	assert_eq(main.settings.get_value("interface", "look"), "5,2", "saved")
	assert_eq(main.settings.get_value("interface", "join_as"), "observer", "unchanged")
	assert_eq(main.stack.top(), s, "back to the settings")
	main.free()


# ---- The Join screen ----

func join_screen(look_only := false) -> JoinScreen:
	var j := JoinScreen.new()
	j.look_only = look_only
	j.join_as = "observer"
	var stack := ScreenStack.new()
	runner.root.add_child(stack)
	stack.set_theme(UiTheme.from_style({}))
	stack.push(j)
	return j


func test_join_asks_how_to_enter_then_for_a_look() -> void:
	var j := join_screen()
	assert_eq(j.step, 1, "how to enter first")
	var names := []
	for b in j.choices:
		names.append(str(b.name))
	assert_eq(names, ["Visitor", "Observer", "Just watch"], "three ways in")
	assert_eq(j.get_viewport().gui_get_focus_owner(), j.choices[0], "Visitor focused")
	var got := []
	j.done.connect(func(a, l): got.append([a, l]))
	j.choose("registered")
	assert_eq(j.step, 2, "then the look")
	assert_true(j.look_box.visible and not j.choice_box.visible, "only the look step shows")
	j.step_outfit(-1)
	assert_eq(j.outfit, 7, "outfits wrap round")
	j.step_hair(1)
	j.step_hair(1)
	assert_eq(j.hair, 2, "hair steps")
	assert_eq(j.look_text(), "7,2", "the look as the core takes it")
	j.start()
	assert_eq(got, [["registered", "7,2"]], "Start says how and in what look")
	j.stack.free()


func test_just_watch_asks_no_look() -> void:
	var j := join_screen()
	var got := []
	j.done.connect(func(a, l): got.append([a, l]))
	j.choose("none")
	assert_eq(got, [["none", "0,0"]], "done at once")
	j.stack.free()


func test_back_from_the_look_returns_to_the_question() -> void:
	var j := join_screen()
	var stack := j.stack
	j.choose("registered")
	stack.back()
	assert_eq(stack.top(), j, "still open")
	assert_eq(j.step, 1, "the question again")
	stack.back()
	assert_eq(stack.top(), null, "and then closed")
	stack.free()


func test_look_only_skips_the_question_and_keeps_join_as() -> void:
	var j := join_screen(true)
	assert_eq(j.step, 2, "the look at once")
	var got := []
	j.done.connect(func(a, l): got.append([a, l]))
	j.start()
	assert_eq(got, [["observer", "0,0"]], "join_as carried through")
	j.stack.free()


func test_the_look_rows_step_with_left_and_right() -> void:
	var j := join_screen(true)
	var left := InputEventAction.new()
	left.action = "ui_left"
	left.pressed = true
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	j.outfit_row.get_node("Value").gui_input.emit(right)
	assert_eq(j.outfit, 1, "right, the next outfit")
	j.hair_row.get_node("Value").gui_input.emit(left)
	assert_eq(j.hair, 3, "left, the hair before, wrapping")
	var outfit_value: Control = j.outfit_row.get_node("Value")
	var hair_value: Control = j.hair_row.get_node("Value")
	assert_eq(outfit_value.get_node(outfit_value.focus_neighbor_bottom), hair_value, "down to the hair")
	assert_eq(hair_value.get_node(hair_value.focus_neighbor_bottom), j.start_button, "down to Start")
	j.stack.free()


func test_a_pack_without_figures_shows_the_numbers_only() -> void:
	var j := JoinScreen.new()
	j.look_only = true
	j.pack = load("res://tests/fixtures/fake_pack/pack.gd").new()
	var stack := ScreenStack.new()
	runner.root.add_child(stack)
	stack.set_theme(UiTheme.from_style({}))
	stack.push(j)
	assert_true(j.preview == null or not j.preview.visible, "no preview")
	assert_true("1" in j.outfit_row.get_node("Value").text, "the number shows: " + j.outfit_row.get_node("Value").text)
	j.pack.free()
	stack.free()


func _built(dir: String) -> StyleHost:
	var h := StyleHost.new()
	runner.root.add_child(h)
	h.activate(dir, JSON.parse_string(CityPaths.district_manifest()), SceneModel.new(), Motion.new(), 0.0)
	return h


func test_a_3d_pack_shows_a_lit_turning_figure() -> void:
	var h := _built("res://styles/lowpoly_tropical")
	var j := JoinScreen.new()
	j.look_only = true
	j.pack = h.pack
	var stack := ScreenStack.new()
	runner.root.add_child(stack)
	stack.set_theme(UiTheme.from_style({}))
	stack.push(j)
	assert_true(j.preview is SubViewportContainer and j.preview.visible, "a preview")
	var vp: SubViewport = j.preview.get_child(0)
	assert_true(vp.own_world_3d, "a world of its own")
	assert_true(vp.find_children("*", "DirectionalLight3D", true, false).size() > 0, "lit")
	assert_true(vp.find_children("*", "Camera3D", true, false).size() > 0, "a camera")
	var figure: Node3D = j.figure
	assert_true(figure != null and figure.get_node_or_null("Model") != null, "a person")
	var before := figure.rotation.y
	j.turn(1.0)
	assert_true(is_equal_approx(figure.rotation.y - before, 0.5), "turning at 0.5 rad/s")
	assert_true(not h.pack.labels.has("person:preview"), "the pack keeps nothing of it")
	j.step_outfit(1)
	assert_true(j.figure != figure and is_instance_valid(j.figure), "a new look, a new figure")
	stack.free()
	h.free()


func test_pixel_art_shows_its_sprite_in_a_2d_preview() -> void:
	var h := _built("res://styles/pixel_art")
	var j := JoinScreen.new()
	j.look_only = true
	j.pack = h.pack
	var stack := ScreenStack.new()
	runner.root.add_child(stack)
	stack.set_theme(UiTheme.from_style({}))
	stack.push(j)
	var vp: SubViewport = j.preview.get_child(0)
	assert_true(not vp.own_world_3d, "2D")
	assert_true(j.figure is Node2D and j.figure.get_node_or_null("Body") is AnimatedSprite2D, "the sprite")
	var was: String = j.figure.get_node("Body").animation
	j.turn(PI / 4.0 / 0.5 + 0.1)
	assert_true(j.figure.get_node("Body").animation != was, "turning, a facing at a time")
	stack.free()
	h.free()


# ---- The camera hooks ----

func test_the_orbit_rig_circles_the_square_at_the_diagonal() -> void:
	var rig := OrbitRig.new()
	rig.frame(Rect2(0, 0, 40, 30), Vector3(20, 0, 15))
	rig.apply_preset("diagonal")
	var distance := rig.distance
	var pitch := rig.pitch
	rig.drift(Vector3(10, 0, 5))
	assert_eq(rig.position, Vector3(10, 0, 5), "round the square's centre")
	assert_eq([rig.pitch, rig.distance], [pitch, distance], "at the diagonal's pitch and distance")
	var yaw := rig.yaw
	rig.advance(90.0)
	assert_true(is_equal_approx(rig.yaw - yaw, 180.0), "half a turn in 90 s: %f" % (rig.yaw - yaw))
	rig.stop_drift()
	rig.advance(10.0)
	assert_true(is_equal_approx(rig.yaw - yaw, 180.0), "stopped")
	rig.free()


func test_the_orbit_rig_flies_and_cuts() -> void:
	var rig := OrbitRig.new()
	rig.frame(Rect2(0, 0, 40, 30), Vector3(20, 0, 15))
	rig.drift(Vector3(10, 0, 5))
	rig.distance = 80.0
	rig.yaw = 350.0
	rig.fly_to(Vector3(30, 0, 25), 40.0, 32.0, 1.2)
	rig.advance(0.6)
	assert_true(rig.position.x > 10.0 and rig.position.x < 30.0, "on its way")
	assert_true(rig.yaw > 350.0 and rig.yaw < 32.0 + 360.0, "turning the short way, through north: %f" % rig.yaw)
	rig.advance(0.6)
	assert_eq(rig.position, Vector3(30, 0, 25), "arrived")
	assert_eq(rig.distance, 40.0, "at the distance asked")
	assert_true(is_equal_approx(fposmod(rig.yaw, 360.0), 32.0), "at the yaw asked: %f" % rig.yaw)
	rig.fly_to(Vector3(0, 0, 0), 30.0, -10.0, 0.0)
	assert_eq([rig.position, rig.distance, rig.yaw], [Vector3.ZERO, 30.0, -10.0], "a cut")
	rig.free()


func test_pack_3d_drifts_round_the_square_and_flies_to_the_diagonal_distance() -> void:
	var h := _built("res://styles/lowpoly_tropical")
	var pack = h.pack
	pack.title_drift(true)
	var heart: Vector3 = pack.rig.position
	assert_true(is_equal_approx(heart.x, pack._heart().x) and is_equal_approx(heart.z, pack._heart().y), "round the square")
	pack._process(1.0)
	assert_true(pack.rig.drifting, "drifting")
	pack.title_drift(false)
	pack.fly_to(Vector2(1000, 2000), 0.0)
	assert_eq(pack.rig.position, Vector3(10, 0, 20), "cut to the point")
	var preset_distance: float = pack.rig.distance
	var preset_yaw: float = pack.rig.yaw
	pack.rig.apply_preset("diagonal")
	assert_eq(preset_distance, pack.rig.distance, "at the preset's distance")
	assert_eq(preset_yaw, pack.rig.yaw, "facing as the preset does")
	h.free()


func test_after_explore_the_3d_view_lands_at_the_diagonal_heading() -> void:
	var main = load("res://main.gd").new()
	main.settings_path = "user://test_title.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.settings_path))
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--title", "--dev"]))
	main.set_process(false)
	main.driver.set_process(false)
	for d in main.styles:
		if d.get_file() == "lowpoly_tropical":
			main._activate(d)
	var rig: OrbitRig = main.host.pack.rig
	assert_true(rig.drifting, "drifting behind the title")
	main.host.pack._process(70.0)
	var turned := fposmod(rig.yaw - rig.preset_yaw("diagonal"), 360.0)
	assert_true(turned > 100.0 and turned < 260.0, "the drift has turned well away: %f" % turned)
	main.settings.set_value("interface", "join_as", "none")
	main.stack.top().explore.emit()
	assert_true(rig.flying(), "flying, not cutting")
	for i in 20:
		main.host.pack._process(0.1)
	assert_true(not rig.flying(), "landed")
	var off := absf(wrapf(rig.yaw - rig.preset_yaw("diagonal"), -180.0, 180.0))
	assert_true(off < 0.01, "at the diagonal's yaw, as a calm cut or a play launch would be: %f off" % off)
	main.free()


func test_pixel_art_pans_back_and_forth_and_flies_with_shift_view() -> void:
	var h := _built("res://styles/pixel_art")
	var pack = h.pack
	pack.title_drift(true)
	var x0: float = pack.camera.position.x
	pack._process(1.0)
	assert_true(absf(pack.camera.position.x - x0) >= 7.0 and absf(pack.camera.position.x - x0) <= 9.0, "8 px a second: %f" % (pack.camera.position.x - x0))
	for i in 2000:
		pack._process(1.0)
	var span: Vector2 = pack.drift_span()
	assert_true(pack.camera.position.x >= span.x - 1.0 and pack.camera.position.x <= span.y + 1.0, "stays along the district")
	pack.title_drift(false)
	pack.fly_to(Vector2(1000, 2000), 0.0)
	assert_eq(pack.camera.position, pack.iso(10.0, 20.0), "cut to the point")
	pack.fly_to(Vector2(0, 0), 1.0)
	pack._process(0.5)
	assert_true(pack.camera.position != pack.iso(0.0, 0.0), "on its way")
	pack._process(0.5)
	assert_eq(pack.camera.position, pack.iso(0.0, 0.0), "there")
	h.free()


# ---- The final review's fixes ----

func test_a_style_that_fails_on_the_title_path_shows_its_error_over_the_title() -> void:
	var path := "user://test_title_broken.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var saved := Settings.new()
	saved.path = path
	saved.set_value("interface", "style", "broken_pack")
	var main = load("res://main.gd").new()
	main.settings_path = path
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--title"]), "res://tests/fixtures")
	assert_true(main.stack.top() is TitleScreen, "the title")
	assert_true("could not be shown" in main.hud.error_label.text, "the error: " + main.hud.error_label.text)
	assert_true(main.hud.error_label.is_visible_in_tree(), "shown on the title")
	var layer: Node = main.hud.error_label.get_parent()
	while layer != null and not layer is CanvasLayer:
		layer = layer.get_parent()
	assert_true(layer != null and layer.layer > ScreenStack.LAYER, "over every screen")
	main.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_the_join_screen_follows_a_style_switch() -> void:
	var main = load("res://main.gd").new()
	main.settings_path = "user://test_title_join_switch.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.settings_path))
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--title", "--style=lowpoly_tropical"]))
	main.stack.top().explore.emit()
	var j: JoinScreen = main.stack.top()
	j.choose("registered")
	assert_true(j.figure is Node3D, "a 3D figure")
	for d in main.styles:
		if d.get_file() == "pixel_art":
			main._activate(d)
	assert_eq(j.pack, main.host.pack, "the Join screen has the style shown now")
	j.step_outfit(1)
	assert_true(j.figure is Node2D and is_instance_valid(j.figure), "dressed by it: the sprite")
	assert_eq(j.look_box.get_child(0), j.preview, "the preview in its place")
	main.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_title_join_switch.cfg"))
