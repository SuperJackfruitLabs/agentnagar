## Probe helper (spike, not production): stands in for the CityWorld the
## client talks to, forwarding every call and recording what crossed the
## boundary — the commands the client sent (Steer cells, Go targets), the
## player's own events (Rejected/BlockedStep, Admitted, Waitlisted), and
## the player's latest projection. main.gd and Player talk to it exactly as
## to the bridge, so the probe sees real client traffic.
extends RefCounted

var real
## Every command sent: {tick, cmd (Dictionary), reply (Dictionary)}.
var commands: Array = []
## Every player event taken, oldest first: {tick, event}.
var events: Array = []
## Steps taken through the tap.
var steps := 0
## The last projection for `player_id`, parsed.
var last_proj := {}
var player_id := ""


func _init(world) -> void:
	real = world


func step() -> int:
	steps += 1
	return real.step()


func tick() -> int:
	return real.tick()


func set_operator(on: bool) -> void:
	real.set_operator(on)


func project_json(viewer) -> String:
	var s: String = real.project_json(viewer)
	if player_id != "" and str(viewer) == player_id:
		var p = JSON.parse_string(s)
		if p is Dictionary:
			last_proj = p
	return s


func layout_json() -> String:
	return real.layout_json()


func join(as_, look) -> String:
	var s: String = real.join(as_, look)
	var r = JSON.parse_string(s)
	if r is Dictionary and r.get("ok", false):
		player_id = str(r["id"])
	return s


func command(json) -> String:
	var s: String = real.command(json)
	commands.append({"tick": real.tick(), "cmd": JSON.parse_string(str(json)), "reply": JSON.parse_string(s)})
	return s


func board() -> String:
	var s: String = real.board()
	commands.append({"tick": real.tick(), "cmd": {"type": "Board"}, "reply": JSON.parse_string(s)})
	return s


func alight() -> String:
	return real.alight()


func take_player_events() -> String:
	var s: String = real.take_player_events()
	var arr = JSON.parse_string(s)
	if arr is Array:
		for e in arr:
			events.append({"tick": real.tick(), "event": e})
	return s


func leave() -> String:
	return real.leave()


func input_log_jsonl() -> String:
	return real.input_log_jsonl()


func viewer() -> String:
	return real.viewer()


func set_checking(on: bool) -> void:
	real.set_checking(on)


func violations_json() -> String:
	return real.violations_json()


func replay_json() -> String:
	return real.replay_json()
