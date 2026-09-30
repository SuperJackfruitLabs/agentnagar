extends TestSuite

class Probe extends Screen:
	var built := 0
	var backs := 0
	var eat_back := false
	func build() -> void:
		built += 1
		var b := Button.new()
		b.name = "First"
		add_child(b)
		var c := Button.new()
		c.name = "Second"
		add_child(c)
	func on_back() -> bool:
		backs += 1
		return eat_back


## A screen that keeps the world live underneath it, as the play HUD does.
class WorldProbe extends Screen:
	func wants_world_input() -> bool:
		return true


func setup() -> Array:
	var r := InputRouter.new()
	runner.root.add_child(r)
	var s := ScreenStack.new()
	s.router = r
	s.ui = UiTheme.from_style({})
	runner.root.add_child(s)
	return [s, r]


func key(code: int, pressed := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e


func test_push_builds_focuses_and_gates_the_world() -> void:
	var sr := setup()
	var s: ScreenStack = sr[0]
	var r: InputRouter = sr[1]
	var p := Probe.new()
	s.push(p)
	await runner.process_frame
	assert_eq(p.built, 1, "built once")
	assert_eq(p.get_viewport().gui_get_focus_owner(), p.get_node("First"), "first control focused")
	assert_true(not r.world_enabled, "world input off")
	s.pop()
	assert_true(r.world_enabled, "world input back")
	s.free()
	r.free()


func test_a_key_held_when_a_screen_opens_stops_and_stays_stopped() -> void:
	var sr := setup()
	var s: ScreenStack = sr[0]
	var r: InputRouter = sr[1]
	r.handle(key(KEY_W))
	assert_true(r.steering != Vector2.ZERO, "walking")
	s.push(Probe.new())
	assert_eq(r.steering, Vector2.ZERO, "stopped when the menu opened")
	r.handle(key(KEY_W, false))
	s.pop()
	assert_eq(r.steering, Vector2.ZERO, "not walking after the menu closes")
	s.free()
	r.free()


func test_back_asks_the_screen_first() -> void:
	var sr := setup()
	var s: ScreenStack = sr[0]
	var a := Probe.new()
	var b := Probe.new()
	s.push(a)
	s.push(b)
	b.eat_back = true
	s.back()
	assert_eq(s.top(), b, "screen handled back itself")
	b.eat_back = false
	s.back()
	assert_eq(s.top(), a, "popped to the one below")
	s.free()
	sr[1].free()


func test_focus_is_restored_when_a_screen_is_uncovered() -> void:
	var sr := setup()
	var s: ScreenStack = sr[0]
	var a := Probe.new()
	s.push(a)
	await runner.process_frame
	a.get_node("Second").grab_focus()
	s.push(Probe.new())
	s.pop()
	await runner.process_frame
	assert_eq(a.get_viewport().gui_get_focus_owner(), a.get_node("Second"), "focus came back")
	s.free()
	sr[1].free()


func test_a_theme_change_reaches_every_screen() -> void:
	var sr := setup()
	var s: ScreenStack = sr[0]
	var a := Probe.new()
	s.push(a)
	var t := UiTheme.from_style({"ui": {"colours": {"panel": "#000000"}}})
	s.set_theme(t)
	assert_eq(a.theme, t.theme, "reskinned")
	s.free()
	sr[1].free()


func test_back_is_left_to_the_world_under_a_screen_that_keeps_it_live() -> void:
	var sr := setup()
	var s: ScreenStack = sr[0]
	var r: InputRouter = sr[1]
	var hud := WorldProbe.new()
	s.push(hud)
	s._unhandled_input(key(KEY_ESCAPE))
	# A freed screen compares equal to null, so count and check validity.
	assert_true(is_instance_valid(hud) and s.screens.size() == 1,
		"Esc over the play view is the world's (it opens the menu), not a Back")
	s.push(Probe.new())
	s._unhandled_input(key(KEY_ESCAPE))
	assert_true(s.screens.size() == 1 and s.top() == hud, "Esc over a menu closes it")
	s.free()
	r.free()


## Records every unhandled event that reaches it, as a style pack's camera
## would take it. Added to the tree before the stack, as the world is.
class WorldListener extends Node:
	var seen := 0
	func _unhandled_input(_event: InputEvent) -> void:
		seen += 1


func test_nothing_falls_through_a_menu_to_the_world() -> void:
	var world := WorldListener.new()
	runner.root.add_child(world)
	var sr := setup()
	var s: ScreenStack = sr[0]
	var vp := s.get_viewport()
	var hud := WorldProbe.new()
	s.push(hud)
	vp.push_input(key(KEY_O))
	assert_eq(world.seen, 1, "the world takes keys under the play view")
	s.push(Probe.new())
	vp.push_input(key(KEY_O))
	assert_eq(world.seen, 1, "but none under a menu")
	s.free()
	sr[1].free()
	world.free()


func test_a_glow_skin_draws_a_halo_behind_the_focused_control() -> void:
	var sr := setup()
	var s: ScreenStack = sr[0]
	s.ui = UiTheme.from_style({"ui": {"focus": "glow", "colours": {"focus": "#35D6FF"}}})
	var p := Probe.new()
	s.push(p)
	var first: Button = p.get_node("First")
	var halo: Panel = p.focus_halo
	assert_true(halo != null, "a halo exists under a glow skin")
	assert_eq(halo.get_parent(), first, "on the focused control")
	assert_true(halo.show_behind_parent, "drawn behind it")
	assert_true(halo.visible, "shown")
	assert_eq(halo.mouse_filter, Control.MOUSE_FILTER_IGNORE, "never takes a click")
	assert_eq([halo.offset_left, halo.offset_top, halo.offset_right, halo.offset_bottom], [-8.0, -8.0, 8.0, 8.0], "8 px round the control")
	var mat := halo.material as ShaderMaterial
	assert_true(mat != null and mat.shader.resource_path == "res://core/ui/focus_glow.gdshader", "the shared glow shader")
	var colour: Color = mat.get_shader_parameter("glow_colour")
	assert_true(absf(colour.a - 0.6) < 0.001 and colour.b8 == 0xFF, "the focus colour at 60%")
	var second: Button = p.get_node("Second")
	second.grab_focus()
	assert_eq(halo.get_parent(), second, "follows the focus")
	s.free()
	sr[1].free()


func test_a_ring_skin_has_no_halo_and_a_switch_removes_it() -> void:
	var sr := setup()
	var s: ScreenStack = sr[0]
	var p := Probe.new()
	s.push(p)
	assert_true(p.focus_halo == null, "no halo under a ring skin")
	s.set_theme(UiTheme.from_style({"ui": {"focus": "glow"}}))
	assert_true(p.focus_halo != null, "a glow skin adds it")
	assert_eq(p.focus_halo.get_parent(), p.get_viewport().gui_get_focus_owner(), "on the focused control at once")
	var halo: Panel = p.focus_halo
	s.set_theme(UiTheme.from_style({}))
	assert_true(p.focus_halo == null, "and a ring skin takes it away")
	assert_true(not is_instance_valid(halo), "nothing left behind")
	s.free()
	sr[1].free()


func test_the_halo_leaves_a_screen_that_loses_the_focus() -> void:
	var sr := setup()
	var s: ScreenStack = sr[0]
	s.ui = UiTheme.from_style({"ui": {"focus": "glow"}})
	var a := Probe.new()
	s.push(a)
	var b := Probe.new()
	s.push(b)
	assert_true(not a.focus_halo.is_visible_in_tree(), "the covered screen's halo is hidden")
	assert_true(b.focus_halo.is_visible_in_tree(), "the top screen's halo shows")
	s.free()
	sr[1].free()
