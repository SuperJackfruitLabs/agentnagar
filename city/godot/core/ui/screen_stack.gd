## The stack of open menu screens. The top screen owns all input; while any
## screen is open, the world (walking, the camera, and looking, driven by
## `InputRouter`'s intents) takes none, unless the top screen opts back in
## with `wants_world_input()`.
extends CanvasLayer
class_name ScreenStack

## Above the game world and the HUD, below nothing: a screen is always the
## topmost thing on screen.
const LAYER := 20

## Bottom to top; `screens[-1]` is what the player sees and interacts with.
var screens: Array[Screen] = []

## Applied to every screen pushed, and reapplied to all of them by
## `set_theme`.
var ui: UiTheme

## Gated by the stack: enabled only when no screen is open, or the top
## screen asks to keep the world live.
var router: InputRouter

## Fires whenever the top screen changes, including to `null` when the
## stack empties.
signal changed(top: Screen)


func _init() -> void:
	layer = LAYER


## Adds `s` above whatever is currently on top, builds it the first time it
## is pushed, applies the current theme, focuses it, and updates the gate.
## The screen it covers, if any, keeps its current focus so it can be
## restored when it is uncovered again.
func push(s: Screen) -> void:
	var covered := top()
	if covered != null:
		var owner := covered.get_viewport().gui_get_focus_owner()
		if owner != null:
			covered.last_focus = owner
	s.stack = self
	screens.append(s)
	add_child(s)
	if not s._built:
		s.build()
		s._built = true
	if ui != null:
		s.apply_theme(ui)
	s.focus_first()
	_update_gate()
	changed.emit(top())


## Frees the top screen and refocuses the screen it uncovers, if any.
func pop() -> void:
	if screens.is_empty():
		return
	var s: Screen = screens.pop_back()
	s.free()
	var t := top()
	if t != null:
		t.focus_first()
	_update_gate()
	changed.emit(t)


## Takes `s` off the stack wherever it sits, refocusing the new top, and
## frees it once the current call is over: a screen may close itself from
## one of its own signals, which cannot free it at once.
func remove(s: Screen) -> void:
	var i := screens.find(s)
	if i < 0:
		return
	screens.remove_at(i)
	remove_child(s)
	s.queue_free()
	var t := top()
	if t != null:
		t.focus_first()
	_update_gate()
	changed.emit(t)


## The screen the player sees, or `null` when the stack is empty.
func top() -> Screen:
	return screens[-1] if not screens.is_empty() else null


## Frees every screen and empties the stack.
func clear() -> void:
	for s in screens:
		s.free()
	screens.clear()
	_update_gate()
	changed.emit(null)


## Re-applies `t` to every screen on the stack, keeping each one's current
## focus.
func set_theme(t: UiTheme) -> void:
	ui = t
	for s in screens:
		var owner := s.get_viewport().gui_get_focus_owner()
		s.apply_theme(t)
		if is_instance_valid(owner):
			owner.grab_focus()


## Asks the top screen to handle the back gesture itself; pops it when it
## declines.
func back() -> void:
	var t := top()
	if t == null:
		return
	if not t.on_back():
		pop()


## Back (`ui_cancel`) closes the top screen, and so does the `menu` action
## (Start, which opened the game menu, closes it again; deeper in, it steps
## back one level as B does). A top screen that keeps the world live (the
## play HUD) leaves the keys to the world instead, where Esc opens the game
## menu and B stops a walk. Under any other screen nothing else the screen
## left unhandled reaches the world either: a style pack's camera, which
## reads keys and the mouse on its own, must not move while a menu is open,
## whichever pack was switched in under it.
func _unhandled_input(event: InputEvent) -> void:
	if screens.is_empty() or top().wants_world_input():
		return
	# Esc is both: it steps back once.
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		back()
	get_viewport().set_input_as_handled()


## The world takes input only when no screen is open, or the top screen
## says it wants the world to keep moving underneath it (the play HUD).
func _update_gate() -> void:
	if router != null:
		router.world_enabled = screens.is_empty() or top().wants_world_input()
