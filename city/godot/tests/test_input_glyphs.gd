extends TestSuite

func key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func pad(button: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e


func test_labels_follow_the_last_device() -> void:
	var g := InputGlyphs.new()
	var seen := []
	g.device_changed.connect(func(d): seen.append(d))
	assert_eq(g.label("toggle_fpv"), "F", "keyboard first")
	g.note(pad(JOY_BUTTON_A))
	assert_eq(g.device, "pad", "pad after a button")
	assert_eq(g.label("toggle_fpv"), "Back", "the pad's button for first person")
	g.note(key(KEY_W))
	assert_eq(seen, ["pad", "keys"], "announced each change once")


func test_small_stick_drift_does_not_switch_device() -> void:
	var g := InputGlyphs.new()
	var m := InputEventJoypadMotion.new()
	m.axis = JOY_AXIS_LEFT_X
	m.axis_value = 0.2
	g.note(m)
	assert_eq(g.device, "keys", "drift ignored")


func test_pad_actions_have_icons_and_keys_do_not() -> void:
	var g := InputGlyphs.new()
	g.note(pad(JOY_BUTTON_B))
	assert_true(g.icon("cancel") is Texture2D, "pad icon")
	g.note(key(KEY_A))
	assert_eq(g.icon("cancel"), null, "no icon for keys")


func test_rebinding_changes_the_label() -> void:
	var g := InputGlyphs.new()
	var old := InputMap.action_get_events("names")
	InputMap.action_erase_events("names")
	InputMap.action_add_event("names", key(KEY_K))
	assert_eq(g.label("names"), "K", "follows the input map")
	InputMap.action_erase_events("names")
	for e in old:
		InputMap.action_add_event("names", e)


func test_keys_have_short_plain_names() -> void:
	var g := InputGlyphs.new()
	assert_eq(g.label("menu"), "Esc", "Esc, not Escape")
	assert_eq(g.label("cancel"), "Backspace", "Backspace")
	assert_eq(g.label("step"), ".", "a symbol key shows its symbol")
	assert_eq(g.label("speed_up"), "=", "and so does = (not Equal)")
