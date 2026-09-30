extends TestSuite

func hud() -> PlayHud:
	var h := PlayHud.new()
	h.glyphs = InputGlyphs.new()
	h.ui = UiTheme.from_style({})
	runner.root.add_child(h)
	h.build()
	h.apply_theme(h.ui)
	return h


func test_the_fixture_notice_is_always_shown() -> void:
	var h := hud()
	assert_eq(h.fixture.text, "Fixture data — not real agent state", "exact text")
	h.show_error("boom")
	h.show_controls(false)
	assert_true(h.fixture.visible, "still visible over an error and with controls hidden")
	h.free()


func test_notices_fade_and_at_most_two_show() -> void:
	var h := hud()
	h.notify("one")
	h.notify("two")
	h.notify("three")
	assert_eq(h.notices.size(), 2, "two at most")
	assert_eq(h.notices[0].get_meta("text"), "two", "the oldest went")
	h.tick(4.1)
	assert_eq(h.notices.size(), 0, "faded after 4 s")
	h.free()


func test_a_notice_with_a_button_waits_for_it() -> void:
	var h := hud()
	var hit := []
	h.notify("First person is 3D only", "Switch to low-poly", func(): hit.append(1))
	h.tick(10.0)
	assert_eq(h.notices.size(), 1, "kept")
	h.notices[0].find_child("Action", true, false).pressed.emit()
	assert_eq(hit, [1], "ran the action")
	assert_eq(h.notices.size(), 0, "and closed")
	h.free()


func test_the_prompt_shows_the_action_and_hides_when_empty() -> void:
	var h := hud()
	h.set_prompt("interact", "Sit")
	assert_true(h.prompt.visible, "shown")
	assert_eq(h.prompt_label.text, "Sit", "text")
	h.set_prompt("interact", "")
	assert_true(not h.prompt.visible, "hidden")
	h.free()


## With other verbs to show, the prompt says which button shows the next:
## E on the keyboard, Y's glyph on a controller.
func test_the_prompt_hints_at_more_verbs() -> void:
	var h := hud()
	h.set_prompt("interact", "Read", true)
	assert_true(h.prompt_more.visible, "the hint shows")
	assert_eq(h._more_key.text, "E", "E on the keyboard")
	var y := InputEventJoypadButton.new()
	y.button_index = JOY_BUTTON_Y
	y.pressed = true
	h.glyphs.note(y)
	h.set_prompt("interact", "Read", true)
	assert_true(h._more_icon.visible and h._more_icon.texture != null, "Y's glyph on a controller")
	h.set_prompt("interact", "Sit")
	assert_true(not h.prompt_more.visible, "one verb: no hint")
	h.set_prompt("", "Waiting — tram in 12 s", true)
	assert_true(not h.prompt_more.visible, "nothing to press: no hint")
	h.free()


func test_clock_and_weather() -> void:
	var h := hud()
	h.set_clock(516, 0.0)
	assert_eq(h.clock.text, "08:36", "clock")
	assert_eq(h.weather_icon.get_meta("kind"), "sun", "day")
	h.set_clock(1300, 0.0)
	assert_eq(h.weather_icon.get_meta("kind"), "moon", "night")
	h.set_clock(1300, 0.5)
	assert_eq(h.weather_icon.get_meta("kind"), "rain", "rain")
	h.free()


func test_hints_fade_after_ten_seconds_and_return_on_a_device_change() -> void:
	var h := hud()
	h.tick(10.5)
	assert_true(h.hints.modulate.a < 0.05, "faded")
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_A
	e.pressed = true
	h.glyphs.note(e)
	assert_true(h.hints.modulate.a > 0.95, "back after the device changed")
	h.free()


func test_errors_are_logged_for_headless_runs() -> void:
	var h := hud()
	h.show_error("The world did not load")
	assert_true(h.error_label.visible, "shown")
	h.free()


func test_every_chip_stays_on_screen_as_its_text_grows() -> void:
	# A screen-sized viewport: the headless root is only 64 px square.
	var screen_viewport := SubViewport.new()
	screen_viewport.size = Vector2i(1280, 720)
	runner.root.add_child(screen_viewport)
	var h := PlayHud.new()
	h.glyphs = InputGlyphs.new()
	screen_viewport.add_child(h)
	h.build()
	h.apply_theme(UiTheme.from_style({}))
	h.set_clock(8 * 60 + 36, 0.0)
	h.set_prompt("interact", "Walk to the library and sit on the long bench")
	h.show_hints()
	await runner.process_frame
	var screen := h.get_viewport_rect()
	for c in [h._fixture_chip, h._clock_chip, h._hints_chip, h.prompt]:
		var r: Rect2 = c.get_global_rect()
		assert_true(r.size.x > 0.0 and screen.encloses(r), "%s inside the screen: %s in %s" % [c.get_class(), r, screen])
	screen_viewport.free()
