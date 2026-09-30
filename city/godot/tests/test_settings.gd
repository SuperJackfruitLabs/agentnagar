extends TestSuite

func fresh(name: String) -> Settings:
	var s := Settings.new()
	s.path = "user://test_settings_%s.cfg" % name
	DirAccess.remove_absolute(ProjectSettings.globalize_path(s.path))
	return s


func test_missing_file_gives_defaults() -> void:
	var s := fresh("missing")
	s.load_file()
	assert_eq(s.get_value("graphics", "quality"), "high", "quality")
	assert_eq(s.get_value("accessibility", "calm"), false, "calm")
	assert_eq(s.text_scale(), 1.0, "text scale")
	assert_true(not s.developer(), "developer tools off")


func test_values_round_trip_through_the_file() -> void:
	var s := fresh("round")
	s.load_file()
	s.set_value("interface", "text_size", 1.25)
	s.set_value("controls", "bindings", {"interact": {"key": 69}})
	var t := Settings.new()
	t.path = s.path
	t.load_file()
	assert_eq(t.text_scale(), 1.25, "text size kept")
	assert_eq(t.get_value("controls", "bindings"), {"interact": {"key": 69}}, "bindings kept")


func test_a_corrupt_file_gives_defaults_without_error() -> void:
	var s := fresh("corrupt")
	var f := FileAccess.open(s.path, FileAccess.WRITE)
	f.store_string("[graphics\nquality = = ")
	f.close()
	s.load_file()
	assert_eq(s.get_value("graphics", "quality"), "high", "default after a corrupt file")


func test_unknown_keys_survive_a_save() -> void:
	var s := fresh("unknown")
	var cf := ConfigFile.new()
	cf.set_value("future", "thing", 3)
	cf.save(s.path)
	s.load_file()
	s.set_value("graphics", "quality", "low")
	var back := ConfigFile.new()
	back.load(s.path)
	assert_eq(back.get_value("future", "thing", 0), 3, "a newer version's key is kept")


func test_set_value_announces_the_change() -> void:
	var s := fresh("signal")
	s.load_file()
	var seen := []
	s.changed.connect(func(sec, key): seen.append([sec, key]))
	s.set_value("accessibility", "calm", true)
	assert_eq(seen, [["accessibility", "calm"]], "changed")
	assert_true(s.calm(), "calm on")


func test_frame_policy_follows_settings_unless_fps_is_given() -> void:
	var s := fresh("fps")
	s.load_file()
	assert_eq(Settings.frame_policy(s, 360.0, -1), {"vsync": true, "max_fps": 0}, "display rate by default")
	s.set_value("graphics", "frame_cap", 120)
	assert_eq(Settings.frame_policy(s, 360.0, -1), {"vsync": true, "max_fps": 120}, "a cap with vsync")
	s.set_value("graphics", "frame_cap", -1)
	assert_eq(Settings.frame_policy(s, 360.0, -1), {"vsync": false, "max_fps": 0}, "unlimited")
	assert_eq(Settings.frame_policy(s, 360.0, 90), {"vsync": false, "max_fps": 90}, "--fps wins")


func test_a_value_of_the_wrong_type_reads_as_its_default() -> void:
	var s := fresh("wrong_type")
	var cf := ConfigFile.new()
	cf.set_value("graphics", "frame_cap", "display")
	cf.set_value("graphics", "vsync", "yes")
	cf.set_value("interface", "text_size", "125%")
	cf.set_value("interface", "names", 1)
	cf.set_value("controls", "mouse_sensitivity", 2)
	cf.set_value("controls", "stick_sensitivity", 0.5)
	cf.set_value("controls", "bindings", "none")
	cf.save(s.path)
	s.load_file()
	assert_eq(s.get_value("graphics", "frame_cap"), 0, "a word for the frame cap reads as the display rate")
	assert_eq(s.get_value("graphics", "vsync"), true, "a word for vsync reads as on")
	assert_eq(Settings.frame_policy(s, 60.0, -1), {"vsync": true, "max_fps": 0}, "the frame policy is the default one")
	assert_eq(s.text_scale(), 1.0, "a text size in words reads as 100%")
	assert_eq(s.get_value("interface", "names"), false, "a number for a switch reads as off")
	var mouse = s.get_value("controls", "mouse_sensitivity")
	assert_eq(typeof(mouse), TYPE_FLOAT, "a whole number for a sensitivity is still a number")
	assert_eq(mouse, 2.0, "and kept")
	assert_eq(s.get_value("controls", "stick_sensitivity"), 0.5, "a right value is kept")
	assert_eq(s.get_value("controls", "bindings"), {}, "bindings that are not a table read as none")
	# Stored as a float, a frame cap reads as the whole number it is.
	s.set_value("graphics", "frame_cap", 120.0)
	var cap = s.get_value("graphics", "frame_cap")
	assert_eq(typeof(cap), TYPE_INT, "a frame cap is a whole number")
	assert_eq(cap, 120, "and kept")


func test_the_client_boots_and_reskins_on_wrongly_typed_settings() -> void:
	var path := "user://test_settings_wrong_type_main.cfg"
	var cf := ConfigFile.new()
	cf.set_value("graphics", "frame_cap", "display")
	cf.set_value("interface", "text_size", "125%")
	cf.set_value("accessibility", "calm", "no")
	cf.set_value("developer", "tools", "maybe")
	cf.save(path)
	var main = load("res://main.gd").new()
	main.settings_path = path
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack"]), "res://tests/fixtures")
	assert_eq(main.ui.font_size(20), 20, "text at 100%")
	main._apply_skin()
	assert_true(not main.hud.error_label.visible, "booted: " + main.hud.error_label.text)
	main.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
