## Minimal reproduction (spike, not production): the steering prediction's
## own choice of cells (Player._next_cell on the client's NavQuery, which
## the core accepts cell for cell) for a walk held in one direction at a
## building door, printed as a trace. No crowd, no rendering, no core
## stepping: just the grid rule and the line follower.
##
## godot --headless --path city/godot --script res://tools/probes/steer_trace.gd
extends SceneTree


func _init() -> void:
	var world = ClassDB.instantiate("CityWorld")
	var ok = JSON.parse_string(world.load(CityPaths.district_manifest(), CityPaths.district_feed(), 7, 0))
	if not ok.get("ok", false):
		print("load failed ", ok)
		quit(1)
		return
	var nav := NavQuery.from_layout(JSON.parse_string(world.layout_json()))
	# The guild hall's workshop door: position (-1800, -600) on the hall's
	# east wall; walking in is walking west, (-1, 0).
	var door := Vector2(-1800, -600)
	var inward := Vector2(-1, 0)
	for case in [
		["straight in, on the door's centre line", 0.0, 0.0],
		["straight in, 75 cm off centre (inside the drawn 2.3 m opening)", 0.0, 75.0],
		["45 deg (pixel art's W or A), line through the door centre", 45.0, 0.0],
		["-45 deg, line through the door centre", -45.0, 0.0],
		["30 deg, line through the door centre", 30.0, 0.0],
		["50 deg, line through the door centre", 50.0, 0.0],
		["60 deg, line through the door centre", 60.0, 0.0],
	]:
		var dir := inward.rotated(deg_to_rad(case[1]))
		var tangent := Vector2(-inward.y, inward.x)
		var start: Vector2 = door - dir * 250.0 + tangent * case[2]
		var p := Player.new()
		p.nav = nav
		p.cell = nav.cell_of(start)
		var cells := [p.cell]
		var result := "stopped"
		for k in 60:
			var next = p._next_cell(dir)
			if next == null:
				break
			p.cell = next
			cells.append(next)
			if nav.room_at(next) == "room:workshop" and not nav.in_door_span(next):
				result = "INSIDE"
				break
		var last: Vector2i = cells[-1]
		var rel := nav.centre(last) - door
		if result != "INSIDE" and cells.size() > 55:
			result = "still walking"
		print("%-72s -> %s after %d steps; ends %d cm along the wall, %d cm in; room %s" % [
			case[0], result, cells.size() - 1, int(rel.dot(tangent)), int(rel.dot(inward)), nav.room_at(last)])
		var trail := []
		for c in cells.slice(0, 16):
			var q: Vector2 = nav.centre(c) - door
			trail.append("(%d,%d)%s" % [int(q.dot(tangent)), int(q.dot(inward)), "*" if nav.in_door_span(c) else ""])
		print("    first cells (along, in; * = door span): ", " ".join(trail))
	quit(0)
