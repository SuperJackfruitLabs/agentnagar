## Turns input events into intents through the named actions of the
## project's input map, so the keyboard, the mouse and game controllers all
## drive the same code. Presses fire once (a held key's repeats and a held
## trigger fire nothing more); steering and looking are held state, kept
## per device so unplugging a controller stops its steering at once.
extends Node
class_name InputRouter

## Left-click on the world: walk to what is under `screen_pos`.
signal walk_to(screen_pos: Vector2)
## The steering vector changed: x right, y down the screen, length at most 1.
signal steer(direction: Vector2)
## Act on the target with the verb the prompt shows (Space or A, in every
## view).
signal interact
## Show the target's next verb on the prompt (E or Y).
signal interact_alt
## Stop a walk (Backspace or B).
signal cancel
## Open the game menu (Esc or Start).
signal menu
## Open the map (M or the left-stick press).
signal map
## Show or hide the developer panel (F3).
signal dev_panel
signal names
signal open_all
signal style_step(direction: int)
## A number key: the style with that 1-based index.
signal style_pick(index: int)
signal zoom(direction: int)
signal speed(direction: int)
signal viewer_step(direction: int)
signal toggle_fpv
signal pause
signal step
signal camera(preset: String)
signal cycle_look
signal roofs

const MOVES := ["move_forward", "move_back", "move_left", "move_right"]
## Actions that fire once per press: action -> [signal, argument or null].
const PRESSES := {
	"cancel": ["cancel", null], "names": ["names", null], "open_all": ["open_all", null],
	"style_prev": ["style_step", -1], "style_next": ["style_step", 1],
	"style_1": ["style_pick", 1], "style_2": ["style_pick", 2], "style_3": ["style_pick", 3],
	"style_4": ["style_pick", 4], "style_5": ["style_pick", 5], "style_6": ["style_pick", 6],
	"style_7": ["style_pick", 7], "style_8": ["style_pick", 8], "style_9": ["style_pick", 9],
	"zoom_in": ["zoom", 1], "zoom_out": ["zoom", -1],
	"speed_up": ["speed", 1], "speed_down": ["speed", -1],
	"viewer_prev": ["viewer_step", -1], "viewer_next": ["viewer_step", 1],
	"toggle_fpv": ["toggle_fpv", null], "step": ["step", null], "cycle_look": ["cycle_look", null], "roofs": ["roofs", null],
	"cam_topdown": ["camera", "topdown"], "cam_diagonal": ["camera", "diagonal"], "cam_street": ["camera", "street"],
	"interact": ["interact", null], "interact_alt": ["interact_alt", null], "pause": ["pause", null],
	"menu": ["menu", null], "map": ["map", null], "dev_panel": ["dev_panel", null],
}
## The developer panel's intents: emitted only while `dev_shortcuts` is on.
const DEV_INTENTS := ["style_step", "style_pick", "speed", "viewer_step", "pause", "step", "camera", "open_all", "roofs"]
## How far the right stick must move before it looks.
const LOOK_DEAD_ZONE := 0.2

## Whether the developer panel's shortcuts act (number keys, T/G/Y, P, `.`,
## `+`/`-`, X, C and the viewer and style steps): on only with developer
## tools. Off, those keys emit nothing.
var dev_shortcuts := false
## True while the world (walking, the camera, and looking) takes input; a
## `ScreenStack` sets this false while a screen is open. Setting it false
## drops every source's held state at once, zeroing steering and looking
## and emitting `steer(Vector2.ZERO)` if it was not already zero. Held keys
## are not re-read when it is set true again: a key still pressed when the
## world is re-enabled must be pressed again to steer.
## Held false while `computer_focus` is on, whatever sets it.
var world_enabled := true:
	set(value):
		if value and computer_focus:
			return
		if world_enabled == value:
			return
		world_enabled = value
		if not value:
			_forget_every_source()
## Computer mode: true while the station computer is open (ComputerScreen
## sets it as it enters the tree and clears it as it leaves). Every key,
## button and stick is the computer's then, so the router emits nothing at
## all, not even the developer panel's F3, and the world stays shut out
## even if the stack's gate asks otherwise, so no keystroke meant for a
## shell can walk the player, cycle a verb or open the map.
var computer_focus := false:
	set(value):
		computer_focus = value
		if value:
			world_enabled = false
## Where the held movement keys and sticks steer: x right, y down the screen.
var steering := Vector2.ZERO
## Where the right sticks look or orbit, each axis -1 to 1.
var looking := Vector2.ZERO
## Where the event being handled came from: "keys", "pointer", or
## "joy:N" for controller N. Read by an intent's handler that treats a
## controller differently (see main's `_on_menu`).
var last_source := ""
## source -> {move action: strength}
var _moves := {}
## source -> Vector2
var _looks := {}
## "source|action" -> whether that action is held on that source.
var _held := {}


func _init() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _unhandled_input(event: InputEvent) -> void:
	handle(event)


func _notification(what: int) -> void:
	# Keys released while the window is away never arrive: let go of them.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_forget("keys")


func handle(event: InputEvent) -> void:
	if computer_focus or not world_enabled:
		return
	var source := _source(event)
	last_source = source
	_track_moves(event, source)
	_track_look(event, source)
	if event is InputEventMouseButton and event.is_action_pressed("walk_target"):
		walk_to.emit(event.position)
	for action in PRESSES:
		if _pressed(event, source, action):
			var fire: Array = PRESSES[action]
			if not dev_shortcuts and fire[0] in DEV_INTENTS:
				continue
			if fire[1] == null:
				emit_signal(fire[0])
			else:
				emit_signal(fire[0], fire[1])


## Keys share one source; each controller is its own, so it can be unplugged.
static func _source(event: InputEvent) -> String:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return "joy:%d" % event.device
	if event is InputEventKey:
		return "keys"
	return "pointer"


## True on the event that starts a press of `action` from `source`.
func _pressed(event: InputEvent, source: String, action: String) -> bool:
	if not event.is_action(action):
		return false
	var key := source + "|" + action
	var down := event.is_action_pressed(action, true)
	var was: bool = _held.get(key, false)
	_held[key] = down
	return down and not was


func _track_moves(event: InputEvent, source: String) -> void:
	var changed := false
	for action in MOVES:
		if event.is_action(action):
			if not _moves.has(source):
				_moves[source] = {}
			# The action's dead zone applies; a released key is 0.
			_moves[source][action] = event.get_action_strength(action)
			changed = true
	if changed:
		_update_steering()


func _track_look(event: InputEvent, source: String) -> void:
	if not event is InputEventJoypadMotion:
		return
	var v: Vector2 = _looks.get(source, Vector2.ZERO)
	if event.is_action("look_x"):
		v.x = _dead_zone(event.axis_value)
	elif event.is_action("look_y"):
		v.y = _dead_zone(event.axis_value)
	else:
		return
	_looks[source] = v
	_update_looking()


static func _dead_zone(value: float) -> float:
	if absf(value) < LOOK_DEAD_ZONE:
		return 0.0
	return signf(value) * inverse_lerp(LOOK_DEAD_ZONE, 1.0, minf(absf(value), 1.0))


func _update_steering() -> void:
	var v := Vector2.ZERO
	for source in _moves:
		var s: Dictionary = _moves[source]
		v += Vector2(s.get("move_right", 0.0) - s.get("move_left", 0.0), s.get("move_back", 0.0) - s.get("move_forward", 0.0))
	v = v.limit_length(1.0)
	if v != steering:
		steering = v
		steer.emit(v)


func _update_looking() -> void:
	var v := Vector2.ZERO
	for source in _looks:
		v += _looks[source]
	looking = v.limit_length(1.0)


## Drops everything every known source was holding, for `world_enabled`'s
## setter: a plain `_forget` only knows one source at a time.
func _forget_every_source() -> void:
	var sources := {}
	for source in _moves:
		sources[source] = true
	for source in _looks:
		sources[source] = true
	for key in _held:
		sources[key.get_slice("|", 0)] = true
	for source in sources:
		_forget(source)


## Drops everything `source` was holding.
func _forget(source: String) -> void:
	_moves.erase(source)
	_looks.erase(source)
	for key in _held.keys():
		if key.begins_with(source + "|"):
			_held.erase(key)
	_update_steering()
	_update_looking()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected:
		_forget("joy:%d" % device)
