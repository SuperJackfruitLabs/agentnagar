## Tracks whether the player last touched the keyboard and mouse or a game
## controller, and labels input actions for whichever device is current.
## The HUD asks it for a key's name or a controller icon rather than hard
## coding either; call `note` with every input event the client sees, and
## its `device` (and the events it later reports through `label` and
## `icon`) follow along.
extends RefCounted
class_name InputGlyphs

## "keys" or "pad".
var device := "keys"

## Fires once, after `device` changes, naming the new value.
signal device_changed(device: String)

## A path swipe or stick tilt this small is noise, not a device switch.
const MOUSE_MOTION_PIXELS := 4.0
const STICK_MOTION_THRESHOLD := 0.5

## Shorter or plainer names for keys whose `OS.get_keycode_string` name is
## long or spelled out: "Esc", not "Escape"; ".", not "Period".
const KEY_SHORT_NAMES := {
	"Escape": "Esc", "PageUp": "Page Up", "PageDown": "Page Down",
	"Period": ".", "Comma": ",", "Equal": "=", "Minus": "-", "Slash": "/",
	"BracketLeft": "[", "BracketRight": "]", "QuoteLeft": "`",
}

## Godot's `JoyButton` indices 0-14, in order.
const BUTTON_NAMES := [
	"A", "B", "X", "Y", "Back", "Guide", "Start", "LS", "RS", "LB", "RB",
	"D-pad Up", "D-pad Down", "D-pad Left", "D-pad Right",
]

## The glyph file (under `glyphs/`, without the extension) for each of the
## same indices. Index 5 (Guide) has no glyph; the button is not bound to
## anything in this game.
const BUTTON_GLYPHS := [
	"a", "b", "x", "y", "back", "", "start", "ls", "rs", "lb", "rb",
	"dpad_up", "dpad_down", "dpad_left", "dpad_right",
]


## Reads one input event and updates `device` when it clearly comes from a
## keyboard/mouse or a controller. A key press, a mouse click, or a mouse
## move past `MOUSE_MOTION_PIXELS` means "keys"; a joypad button, or joypad
## motion past `STICK_MOTION_THRESHOLD`, means "pad". Anything smaller (a
## twitch of stick drift) or unrecognised is left alone.
func note(event: InputEvent) -> void:
	var target := _device_for(event)
	if target != "" and target != device:
		device = target
		device_changed.emit(device)


func _device_for(event: InputEvent) -> String:
	if event is InputEventKey or event is InputEventMouseButton:
		return "keys"
	if event is InputEventMouseMotion:
		if event.relative.length() > MOUSE_MOTION_PIXELS:
			return "keys"
		return ""
	if event is InputEventJoypadButton:
		return "pad"
	if event is InputEventJoypadMotion:
		if absf(event.axis_value) > STICK_MOTION_THRESHOLD:
			return "pad"
		return ""
	return ""


## The name of `action`'s first event for the current device: a key's
## printable name (`OS.get_keycode_string` of its physical keycode, or its
## keycode when no physical one is set, shortened by `KEY_SHORT_NAMES`) for
## "keys", or the pressed button's name for "pad". "" when the action has
## no matching event.
func label(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if device == "pad":
		return _pad_label(events)
	return _keys_label(events)


func _keys_label(events: Array) -> String:
	for e in events:
		if e is InputEventKey:
			var code: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
			if code != 0:
				var key_name := OS.get_keycode_string(code)
				return KEY_SHORT_NAMES.get(key_name, key_name)
		elif e is InputEventMouseButton:
			return _mouse_button_label(e.button_index)
	return ""


func _mouse_button_label(button_index: int) -> String:
	match button_index:
		MOUSE_BUTTON_LEFT:
			return "Click"
		MOUSE_BUTTON_RIGHT:
			return "Right Click"
		MOUSE_BUTTON_MIDDLE:
			return "Middle Click"
		MOUSE_BUTTON_WHEEL_UP:
			return "Scroll Up"
		MOUSE_BUTTON_WHEEL_DOWN:
			return "Scroll Down"
		_:
			return "Mouse %d" % button_index


func _pad_label(events: Array) -> String:
	for e in events:
		if e is InputEventJoypadButton:
			var name := button_name(e.button_index)
			if name != "":
				return name
		elif e is InputEventJoypadMotion:
			var trigger := _trigger_name(e.axis)
			if trigger != "":
				return trigger
	return ""


func _trigger_name(axis: int) -> String:
	if axis == JOY_AXIS_TRIGGER_LEFT:
		return "LT"
	if axis == JOY_AXIS_TRIGGER_RIGHT:
		return "RT"
	return ""


## The glyph for `action`'s first pad-shaped event, or `null` on the
## keyboard/mouse (those are drawn as a keycap of `label`'s text instead)
## or when the action has no such event.
func icon(action: String) -> Texture2D:
	if device != "pad":
		return null
	var events := InputMap.action_get_events(action)
	for e in events:
		if e is InputEventJoypadButton:
			var tex := _load_glyph_for_button(e.button_index)
			if tex != null:
				return tex
		elif e is InputEventJoypadMotion:
			var file := _trigger_glyph(e.axis)
			if file != "":
				var tex := _load_glyph(file)
				if tex != null:
					return tex
	return null


func _trigger_glyph(axis: int) -> String:
	if axis == JOY_AXIS_TRIGGER_LEFT:
		return "lt"
	if axis == JOY_AXIS_TRIGGER_RIGHT:
		return "rt"
	return ""


func _load_glyph_for_button(index: int) -> Texture2D:
	if index < 0 or index >= BUTTON_GLYPHS.size():
		return null
	var file: String = BUTTON_GLYPHS[index]
	if file == "":
		return null
	return _load_glyph(file)


func _load_glyph(file_name: String) -> Texture2D:
	var path := "res://core/ui/glyphs/%s.svg" % file_name
	if not ResourceLoader.exists(path):
		return null
	var res := load(path)
	if res is Texture2D:
		return res
	return null


## The name of `JoyButton` index `index`: A, B, X, Y, Back, Guide, Start,
## LS, RS, LB, RB, or "D-pad Up" and the other three directions. "" when
## `index` is out of range.
static func button_name(index: int) -> String:
	if index < 0 or index >= BUTTON_NAMES.size():
		return ""
	return BUTTON_NAMES[index]
