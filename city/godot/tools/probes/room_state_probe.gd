## Room-state probe (spike, not production): boots the client headless,
## joins the player, and samples each building room's admission state every
## tick from the player's own projection: capacity, public occupants,
## reserved seats not yet claimed, the waitlist, and whether the room is
## closed to the player's steering (Player.closed_rooms, the client's copy
## of the core's rule).
##
## godot --headless --path city/godot --script res://tools/probes/room_state_probe.gd -- crowd=60 ticks=900 every=60
extends SceneTree

var opts := {"crowd": "0", "ticks": "600", "every": "30", "seed": "7"}
const ROOMS := ["room:workshop", "room:commons", "room:reading", "room:cafe-terrace"]


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			opts[kv[0]] = kv[1]
	await process_frame
	var main = load("res://main.gd").new()
	root.add_child(main)
	main.boot_for_tool(PackedStringArray(["--crowd=" + opts["crowd"], "--seed=" + opts["seed"], "--style=lowpoly_tropical"]))
	var closed_ticks := {}
	var full_ticks := {}
	var waiting_ticks := {}
	for r in ROOMS:
		closed_ticks[r] = 0
		full_ticks[r] = 0
		waiting_ticks[r] = 0
	var n := int(opts["ticks"])
	for t in n:
		main.driver.step_once()
		var p = JSON.parse_string(main.driver.world.project_json(main.player.id))
		var closed: Array = Player.closed_rooms(p, main.player.id)
		var line := "tick %d:" % int(p.get("tick", 0))
		for room in p.get("rooms", []):
			if not (room["id"] in ROOMS):
				continue
			var occ: Array = room.get("occupants", [])
			var present: int = occ.filter(func(v): return Player.holds_cells(v)).size()
			var hidden: int = occ.size() - present
			var sat := {}
			for v in occ:
				if v.get("seat") != null:
					sat[v["seat"]] = true
			var unclaimed: int = room.get("seats", []).filter(func(s): return s.get("reserved", false) and not sat.has(s["id"])).size()
			var waiting: int = room.get("waiting", []).size()
			var cap := int(room.get("capacity", 0))
			var is_closed: bool = room["id"] in closed
			if is_closed:
				closed_ticks[room["id"]] += 1
			if present + unclaimed >= cap:
				full_ticks[room["id"]] += 1
			if waiting > 0:
				waiting_ticks[room["id"]] += 1
			line += " %s cap=%d public=%d hidden=%d unclaimed_reserved=%d waiting=%d closed=%s |" % [
				str(room["id"]).trim_prefix("room:"), cap, present, hidden, unclaimed, waiting, is_closed]
		if t % int(opts["every"]) == 0:
			print(line)
	for r in ROOMS:
		print("SUM crowd=%s %s closed %d/%d ticks (full %d, queue %d)" % [opts["crowd"], r, closed_ticks[r], n, full_ticks[r], waiting_ticks[r]])
	quit(0)
