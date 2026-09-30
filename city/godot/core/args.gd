## Command-line options after `--`, e.g.
## godot --path city/godot -- --style=pixel_art --viewer=person:asha --crowd=60
## `--as` is who joins: `registered` (the default), `observer`, or `none`
## to watch without a player; `--look=OUTFIT,HAIR` is the player's look.
## `--viewer` defaults to the player's own view (public without a player).
## `--dev` turns developer tools on for the session; `--title` asks for the
## title screen; `--open-menu` opens the game menu once play has booted,
## for captures of the skins, and is neither a play nor a title argument.
## `--map` opens the map once booted, and `--place=<id>` opens it with that
## facility or room selected (so it implies `--map`); neither is a play
## argument, so on their own they open the map over the title.
## `play` is true when any of `--as`, `--look`, `--style`, `--camera`,
## `--fpv`, `--capture` or `--viewer` was given, which skips the title and
## goes straight to play.
extends RefCounted
class_name CityArgs


## Whether a launch with `options` opens on the title: `--title` forces
## it; otherwise any play argument goes straight to play, and so do test
## runs and tools (`test_or_tool`), whatever they pass.
static func shows_title(options: Dictionary, test_or_tool: bool) -> bool:
	return options["title"] or not (options["play"] or test_or_tool)


static func parse(args: PackedStringArray) -> Dictionary:
	var o := {"style": "", "viewer": "", "operator": false, "seed": 7, "crowd": 60,
		"ticks": 0, "capture": "", "speed": 1, "camera": "", "open_all": false, "no_hud": false, "fpv": false, "fps": -1, "fpv_in_2d": "offer",
		"as": "registered", "look": "0,0", "dev": false, "title": false, "play": false, "open_menu": false,
		"map": false, "place": ""}
	for a in args:
		if a == "--operator":
			o["operator"] = true
		elif a == "--open-all":
			o["open_all"] = true
		elif a == "--no-hud":
			o["no_hud"] = true
		elif a == "--fpv":
			o["fpv"] = true
			o["play"] = true
		elif a == "--dev":
			o["dev"] = true
		elif a == "--title":
			o["title"] = true
		elif a == "--open-menu":
			o["open_menu"] = true
		elif a == "--map":
			o["map"] = true
		elif a.begins_with("--") and "=" in a:
			var k := a.substr(2, a.find("=") - 2)
			var v := a.substr(a.find("=") + 1)
			if k in ["seed", "crowd", "ticks", "speed", "fps"]:
				o[k] = int(v)
			elif k in ["style", "viewer", "capture", "camera", "as", "look"]:
				o[k] = v
				o["play"] = true
			elif k == "fpv-in-2d":
				o["fpv_in_2d"] = v
			elif k == "place":
				o["place"] = v
				o["map"] = true
	if o["camera"] == "fpv":
		o["camera"] = ""
		o["fpv"] = true
	return o
