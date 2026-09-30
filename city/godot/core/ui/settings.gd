## The player's saved settings: graphics, controls, interface, accessibility,
## developer options, and the station computer's. Backed by a `ConfigFile`
## at `user://settings.cfg`, kept whole on load so that a newer version's
## keys survive a save from an older one. A missing or corrupt file loads
## as empty, and every read falls back to `DEFAULTS`.
extends RefCounted
class_name Settings

const PATH := "user://settings.cfg"

## `frame_cap` of 0 tracks the display's own rate, -1 is unlimited (vsync
## off), and any N > 0 caps the frame rate to N with vsync left as set.
## `station` is the station computer's: `live` stays off until the internal SJL
## decision is accepted (spec section 5.6), and with it off no code path
## opens a connection; the addresses are the player's own hub, Superpipeline
## and AgentPod console; `client_id` is the city's registration with the
## hub.
const DEFAULTS := {
	"graphics": {"display": "windowed", "vsync": true, "frame_cap": 0, "quality": "high"},
	"controls": {"mouse_sensitivity": 1.0, "stick_sensitivity": 1.0, "invert_y": false, "bindings": {}},
	"interface": {"names": false, "text_size": 1.0, "join_as": "", "look": "0,0", "style": ""},
	"accessibility": {"calm": false},
	"developer": {"tools": false},
	"station": {
		"live": false, "hub_url": "", "superpipeline_url": "", "console_url": "",
		"client_id": "agentnagar",
	},
}

## Overridable by tests, so each test writes its own file.
var path := PATH

signal changed(section: String, key: String)

var _cf := ConfigFile.new()


## Reads `path`. A missing or corrupt file leaves an empty configuration, so
## every value falls back to `DEFAULTS`; unknown sections and keys already in
## the file are kept, so a later save writes them back untouched.
func load_file() -> void:
	var cf := ConfigFile.new()
	# A missing or malformed file is an expected, handled case here, not a
	# bug to surface; the engine still logs a parse error at the default
	# verbosity, so it is muted for the one call that might raise it.
	var was_printing := Engine.print_error_messages
	Engine.print_error_messages = false
	var err := cf.load(path)
	Engine.print_error_messages = was_printing
	if err != OK:
		cf = ConfigFile.new()
	_cf = cf


func save() -> void:
	_cf.save(path)


## Returns the stored value, or `DEFAULTS[section][key]` when it is unset
## or of another type than the default (a hand-edited "125%" for a text
## size, say), so a wrong value never reaches the code that reads it. A
## whole number and a fractional one stand in for each other, and come
## back as the default's type. A key with no default is returned as stored.
func get_value(section: String, key: String):
	var fallback = DEFAULTS.get(section, {}).get(key)
	var stored = _cf.get_value(section, key, fallback)
	if fallback == null or typeof(stored) == typeof(fallback):
		return stored
	var numbers := [TYPE_INT, TYPE_FLOAT]
	if typeof(stored) in numbers and typeof(fallback) in numbers:
		return int(stored) if typeof(fallback) == TYPE_INT else float(stored)
	return fallback


## Sets, saves to disk, and announces the change.
func set_value(section: String, key: String, value) -> void:
	_cf.set_value(section, key, value)
	save()
	changed.emit(section, key)


## `{vsync, max_fps}` for the main window. `cmd_fps` is the `--fps`
## command-line argument (-1 unset); when given, it wins and comes from
## `FramePacing.policy`. Otherwise the settings' `graphics/vsync` and
## `graphics/frame_cap` decide: a cap of -1 turns vsync off, 0 keeps the
## display's own rate, and N > 0 caps at N with vsync as set.
static func frame_policy(settings: Settings, refresh_hz: float, cmd_fps: int) -> Dictionary:
	if cmd_fps != -1:
		return FramePacing.policy(refresh_hz, cmd_fps)
	var vsync: bool = settings.get_value("graphics", "vsync")
	var frame_cap: int = settings.get_value("graphics", "frame_cap")
	if frame_cap == -1:
		return {"vsync": false, "max_fps": 0}
	return {"vsync": vsync, "max_fps": frame_cap}


func text_scale() -> float:
	return get_value("interface", "text_size")


func developer() -> bool:
	return get_value("developer", "tools")


func calm() -> bool:
	return get_value("accessibility", "calm")
