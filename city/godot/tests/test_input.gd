## The input router: keyboard, mouse and controller events become the same
## intents through the named actions of the input map.
extends TestSuite

## Every action the input map must define.
const ACTIONS := ["walk_target", "move_forward", "move_back", "move_left", "move_right", "look_x", "look_y",
	"interact", "interact_alt", "cancel", "names", "open_all", "style_prev", "style_next", "zoom_in", "zoom_out",
	"speed_up", "speed_down", "viewer_prev", "viewer_next", "toggle_fpv", "pause", "step",
	"cam_topdown", "cam_diagonal", "cam_street", "cycle_look", "roofs", "menu", "map", "dev_panel"]


func router() -> InputRouter:
	var r := InputRouter.new()
	runner.root.add_child(r)
	return r


## Records every intent the router emits as [name, argument].
func record(r: InputRouter) -> Array:
	var log := []
	for s in r.get_script().get_script_signal_list():
		var sig: String = s["name"]
		if s["args"].is_empty():
			r.connect(sig, func(): log.append([sig, null]))
		else:
			r.connect(sig, func(arg): log.append([sig, arg]))
	return log


static func key(code: int, pressed := true, echo := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	e.echo = echo
	return e


static func button(index: int, pressed := true, device := 0) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = index
	e.pressed = pressed
	return e


static func axis(which: int, value: float, device := 0) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = device
	e.axis = which
	e.axis_value = value
	return e


static func click(at: Vector2, index := MOUSE_BUTTON_LEFT, pressed := true) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = index
	e.position = at
	e.pressed = pressed
	return e


## Taps each key or button: a press, then a release.
func tap_all(r: InputRouter, events: Array) -> void:
	for e in events:
		r.handle(e)
		var up = e.duplicate()
		up.pressed = false
		r.handle(up)


func test_the_input_map_defines_every_action() -> void:
	for a in ACTIONS:
		assert_true(InputMap.has_action(a), "the input map defines " + a)
	for k in 9:
		assert_true(InputMap.has_action("style_%d" % (k + 1)), "a key picks style %d" % (k + 1))


func test_keyboard_and_controller_give_identical_intents() -> void:
	var keys := router()
	var pad := router()
	keys.dev_shortcuts = true
	pad.dev_shortcuts = true
	var from_keys := record(keys)
	var from_pad := record(pad)
	tap_all(keys, [key(KEY_N), key(KEY_E), key(KEY_EQUAL), key(KEY_MINUS), key(KEY_V), key(KEY_BACKSPACE),
		key(KEY_F), key(KEY_ESCAPE), key(KEY_M), key(KEY_C)])
	tap_all(pad, [button(JOY_BUTTON_X), button(JOY_BUTTON_Y), button(JOY_BUTTON_DPAD_UP),
		button(JOY_BUTTON_DPAD_DOWN), button(JOY_BUTTON_DPAD_RIGHT), button(JOY_BUTTON_B),
		button(JOY_BUTTON_BACK), button(JOY_BUTTON_START), button(JOY_BUTTON_LEFT_STICK), button(JOY_BUTTON_RIGHT_STICK)])
	assert_eq(from_keys, [["names", null], ["interact_alt", null], ["speed", 1], ["speed", -1], ["viewer_step", 1],
		["cancel", null], ["toggle_fpv", null], ["menu", null], ["map", null], ["roofs", null]], "the keyboard's intents")
	assert_eq(from_pad, from_keys, "the controller's are the same")
	keys.free()
	pad.free()


func test_wasd_and_the_left_stick_steer_alike() -> void:
	var keys := router()
	var pad := router()
	var from_keys := record(keys)
	var from_pad := record(pad)
	keys.handle(key(KEY_W))
	keys.handle(key(KEY_W, true, true))
	keys.handle(key(KEY_W, false))
	keys.handle(key(KEY_D))
	keys.handle(key(KEY_D, false))
	pad.handle(axis(JOY_AXIS_LEFT_Y, -1.0))
	pad.handle(axis(JOY_AXIS_LEFT_Y, 0.0))
	pad.handle(axis(JOY_AXIS_LEFT_X, 1.0))
	pad.handle(axis(JOY_AXIS_LEFT_X, 0.0))
	var want := [["steer", Vector2(0, -1)], ["steer", Vector2.ZERO], ["steer", Vector2(1, 0)], ["steer", Vector2.ZERO]]
	assert_eq(from_keys, want, "W then D, each held and released; a held key's repeats change nothing")
	assert_eq(from_pad, want, "the stick pushed up, then right")
	keys.handle(key(KEY_W))
	keys.handle(key(KEY_D))
	assert_true(keys.steering.is_equal_approx(Vector2(1, -1).normalized()), "two keys steer diagonally at walking pace")
	keys.free()
	pad.free()


func test_a_resting_stick_does_not_steer() -> void:
	var r := router()
	var log := record(r)
	r.handle(axis(JOY_AXIS_LEFT_X, 0.1))
	r.handle(axis(JOY_AXIS_LEFT_Y, -0.15))
	assert_eq(log, [], "inside the dead zone")
	assert_eq(r.steering, Vector2.ZERO, "no steering")
	r.free()


func test_hot_plug_mid_steer_zeroes_steering_at_once() -> void:
	var r := router()
	var log := record(r)
	r.handle(axis(JOY_AXIS_LEFT_X, 1.0, 1))
	r.handle(axis(JOY_AXIS_RIGHT_X, 1.0, 1))
	assert_eq(r.steering, Vector2(1, 0), "pad 1 steers east")
	assert_true(r.looking.x > 0.9, "and looks")
	Input.joy_connection_changed.emit(1, false)
	assert_eq(r.steering, Vector2.ZERO, "unplugged: it stops at once")
	assert_eq(r.looking, Vector2.ZERO, "and stops looking")
	assert_eq(log, [["steer", Vector2(1, 0)], ["steer", Vector2.ZERO]], "the stop is an intent")
	r.handle(key(KEY_W))
	r.handle(axis(JOY_AXIS_LEFT_X, 1.0, 0))
	Input.joy_connection_changed.emit(0, false)
	assert_eq(r.steering, Vector2(0, -1), "another device's steering stays")
	Input.joy_connection_changed.emit(0, true)
	assert_eq(r.steering, Vector2(0, -1), "plugging a pad in changes nothing")
	r.free()


func test_a_click_walks_and_a_on_the_pad_interacts() -> void:
	var r := router()
	var log := record(r)
	r.handle(click(Vector2(320, 200)))
	r.handle(click(Vector2(320, 200), MOUSE_BUTTON_LEFT, false))
	r.handle(click(Vector2(10, 10), MOUSE_BUTTON_RIGHT))
	tap_all(r, [button(JOY_BUTTON_A)])
	assert_eq(log, [["walk_to", Vector2(320, 200)], ["interact", null]], "left-click walks; A interacts")
	r.free()


func test_space_always_interacts_and_p_pauses() -> void:
	var r := router()
	r.dev_shortcuts = true
	var log := record(r)
	tap_all(r, [key(KEY_SPACE), key(KEY_P), button(JOY_BUTTON_START)])
	assert_eq(log, [["interact", null], ["pause", null], ["menu", null]], "Space acts, P pauses, Start opens the menu")
	r.free()


func test_developer_shortcuts_are_silent_while_off() -> void:
	var r := router()
	var log := record(r)
	tap_all(r, [key(KEY_2), key(KEY_T), key(KEY_P), key(KEY_PERIOD), key(KEY_EQUAL), key(KEY_MINUS),
		key(KEY_X), key(KEY_C), key(KEY_V), button(JOY_BUTTON_RIGHT_SHOULDER)])
	assert_eq(log, [], "number keys, cameras, pause, step, speed, open all, roofs, viewers and styles: nothing")
	tap_all(r, [key(KEY_N), key(KEY_SPACE), key(KEY_L), key(KEY_ESCAPE), key(KEY_F3)])
	assert_eq(log, [["names", null], ["interact", null], ["cycle_look", null], ["menu", null], ["dev_panel", null]],
		"the player's keys still act, and F3 still asks for the panel")
	r.free()


func test_styles_zoom_cameras_and_steps() -> void:
	var r := router()
	r.dev_shortcuts = true
	var log := record(r)
	tap_all(r, [key(KEY_2), key(KEY_9), button(JOY_BUTTON_LEFT_SHOULDER), button(JOY_BUTTON_RIGHT_SHOULDER),
		key(KEY_T), key(KEY_G), key(KEY_Y), key(KEY_PERIOD), key(KEY_L), button(JOY_BUTTON_DPAD_LEFT)])
	# A trigger pulled and held zooms once; released and pulled again, once more.
	for v in [0.3, 0.8, 1.0, 0.9, 0.0, 1.0]:
		r.handle(axis(JOY_AXIS_TRIGGER_RIGHT, v))
	r.handle(axis(JOY_AXIS_TRIGGER_LEFT, 1.0))
	assert_eq(log, [["style_pick", 2], ["style_pick", 9], ["style_step", -1], ["style_step", 1],
		["camera", "topdown"], ["camera", "diagonal"], ["camera", "street"], ["step", null], ["cycle_look", null],
		["viewer_step", -1], ["zoom", 1], ["zoom", 1], ["zoom", -1]], "every other action")
	r.free()


func test_a_held_key_fires_once() -> void:
	var r := router()
	var log := record(r)
	r.handle(key(KEY_N))
	r.handle(key(KEY_N, true, true))
	r.handle(key(KEY_N, true, true))
	r.handle(key(KEY_N, false))
	assert_eq(log, [["names", null]], "repeats are ignored")
	r.free()
