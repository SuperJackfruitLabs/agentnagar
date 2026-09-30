## Doors let you in from any reasonable approach (spec §6, §1 success 2):
## the library form of tools/probes/door_probe.gd. For every building door
## in every style it boots the client headless under the door study's
## conditions (seed 7, no crowd, from tick 300, when the rooms are open),
## turns real input into the client's steering (the router, as a stick or
## as keys, then the pack's ground direction), and walks the steering
## prediction in pure logic on the client's own grid. The core accepts
## every step the prediction takes (test_player.gd walks the rule against
## it), so an approach the prediction walks in is one the player walks in.
## First-person "Go in" is played out against the core itself.
##
## Families, each asserted at 100% and printed as a table:
## - straight in, starting across the drawn opening (−100…+100 cm for an
##   exterior door, the door's own width for an interior one), with the
##   stick;
## - the angled sweep, −80°…+80° off the door's normal in 5° steps, each
##   line crossing the door's plane at points no more than
##   CROSSING_SPACING_CM apart across its opening, with the stick;
## - in pixel art, every movement key that heads into the door (each at
##   exactly 45° to it), on the same crossing lines;
## - in the 3D styles, first person: facing the door from 3 m out, A acts
##   on the crosshair ("Go in", or "Walk here" from inside the building).
extends TestSuite

## Every style, each checked by a test below.
const STYLES := ["anime_cel", "lowpoly_tropical", "neon_noir", "pixel_art", "solarpunk", "voxel"]
const SWEEP_STEP_DEG := 5
## Lines of the sweep and the keys cross each door's plane at points this
## far apart at most, evenly spread across its opening from
## CROSSING_INSET_CM in from one jamb to as far in from the other.
const CROSSING_SPACING_CM := 15.0
const CROSSING_INSET_CM := 5.0
## Each walk starts up to this far back along its line from the door.
const RUN_UP_CM := 300.0
## A walk's line may pass through the door's own wall within this depth
## of the door; beyond it, furniture in the way shortens the run-up (a
## player stands in front of the desk, not inside it).
const WALL_BAND_CM := 50.0
## A walk still outside after this many steps has slid past.
const MAX_STEPS := 80
const START_TICK := 300


func booted(style: String):
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--seed=7", "--style=" + style, "--ticks=%d" % START_TICK]))
	assert_true(not main.hud.error_label.visible, "booted %s: %s" % [style, main.hud.error_label.text])
	land(main)
	return main


## Plays the frames that land the last projection in the client (the
## player observes it on the fourth).
func land(main) -> void:
	for f in 6:
		main._process(1.0 / 60.0)


func test_every_door_lets_you_in_in_lowpoly_tropical() -> void:
	check_style("lowpoly_tropical")


func test_every_door_lets_you_in_in_anime_cel() -> void:
	check_style("anime_cel")


func test_every_door_lets_you_in_in_neon_noir() -> void:
	check_style("neon_noir")


func test_every_door_lets_you_in_in_solarpunk() -> void:
	check_style("solarpunk")


func test_every_door_lets_you_in_in_voxel() -> void:
	check_style("voxel")


func test_every_door_lets_you_in_in_pixel_art() -> void:
	check_style("pixel_art")


func check_style(style: String) -> void:
	var started := Time.get_ticks_msec()
	var main = booted(style)
	var found: Array = main.styles.map(func(d): return d.get_file())
	found.sort()
	assert_eq(found, STYLES, "every style is checked")
	assert_true(main.player.present, "%s: the player is in the city" % style)
	var doors := building_doors(main)
	assert_eq(doors.size(), 5, "%s: the guild hall's and the library's doors, outside and in" % style)
	for room in ["room:workshop", "room:commons", "room:reading"]:
		assert_true(not main.nav.is_closed(room), "%s: %s is open at tick %d" % [style, room, main.driver.world.tick()])
	var three_d: bool = main.host.pack.supports_fpv()
	print("door entry, %s (tick %d): entries that ended inside / attempts" % [style, main.driver.world.tick()])
	print("  %-24s %-12s %-12s %-12s %s" % ["door", "straight in", "sweep", "keys 45°", "first person"])
	for d in doors:
		var straight := family(main, d, straight_in(main, d), style + " straight in")
		var sweep := family(main, d, swept(main, d), style + " sweep")
		var keys := family(main, d, keyed(main, d), style + " keys") if not three_d else [0, 0]
		var first := go_in(main, d, style) if three_d else [0, 0]
		print("  %-24s %-12s %-12s %-12s %s" % [d["door"], cell(straight), cell(sweep), cell(keys) if not three_d else "—",
			cell(first) if three_d else "—"])
		if not three_d:
			assert_true(keys[1] > 0, "%s: some key heads into %s" % [style, d["door"]])
	print("  (%d ms)" % (Time.get_ticks_msec() - started))
	main.free()


static func cell(tally: Array) -> String:
	return "%d/%d" % tally


# ---- Doors ----

## Every door into a building's room, from outside or from another of its
## rooms: {door, room, from, pos (cm), inward, tangent, width (cm)}.
func building_doors(main) -> Array:
	var out := []
	for dist in main.manifest["city"]["districts"]:
		for f in dist["facilities"]:
			var kind := CityGeometry.building_kind(f)
			if kind == "":
				continue
			var ids: Array = f["rooms"].map(func(r): return r["id"])
			for r in f["rooms"]:
				if r.get("rect") == null:
					continue
				for door in r.get("doors", []):
					if door.get("pos") == null:
						continue
					var rc: Dictionary = r["rect"]
					var p := Vector2(door["pos"]["x"], door["pos"]["z"])
					var inward := Vector2.ZERO
					if int(p.x) == int(rc["x"]):
						inward = Vector2(1, 0)
					elif int(p.x) == int(rc["x"]) + int(rc["w"]):
						inward = Vector2(-1, 0)
					elif int(p.y) == int(rc["z"]):
						inward = Vector2(0, 1)
					else:
						inward = Vector2(0, -1)
					var exterior: bool = not door["to"] in ids
					var width := CityGeometry.door_width(door, StylePack.kinds().get(kind, {}), exterior) * 100.0
					out.append({"door": door["id"], "room": r["id"], "from": door["to"], "pos": p, "inward": inward,
						"tangent": Vector2(-inward.y, inward.x), "width": width})
	return out


# ---- Approaches ----

## Straight in with the stick, from starts every 25 cm across the drawn
## opening: [{dir, cross, label}].
func straight_in(main, d: Dictionary) -> Array:
	var out := []
	var dir := stick_steer(main, d["inward"])
	var half: float = d["width"] / 2.0
	var off := -half
	while off <= half + 0.01:
		out.append({"dir": dir, "along": off, "label": "straight in at %+d cm" % int(off), "straight": true})
		off += 25.0
	return out


## The angled sweep with the stick.
func swept(main, d: Dictionary) -> Array:
	var out := []
	for ang in range(-80, 81, SWEEP_STEP_DEG):
		var dir := stick_steer(main, d["inward"].rotated(deg_to_rad(ang)))
		for cross in crossings(d):
			out.append({"dir": dir, "along": cross, "label": "%+d° crossing at %+d cm" % [ang, int(cross)]})
	return out


## Every movement key that heads into the door, alone, as the router
## turns it into steering.
func keyed(main, d: Dictionary) -> Array:
	var out := []
	for code in [KEY_W, KEY_A, KEY_S, KEY_D]:
		var dir := key_steer(main, code)
		if dir.dot(d["inward"]) < 0.2:
			continue
		var ang := rad_to_deg(d["inward"].angle_to(dir))
		assert_true(absf(absf(ang) - 45.0) < 0.5, "%s is 45° to %s: %.2f°" % [OS.get_keycode_string(code), d["door"], ang])
		for cross in crossings(d):
			out.append({"dir": dir, "along": cross, "label": "%s (%+.0f°) crossing at %+d cm" % [OS.get_keycode_string(code), ang, int(cross)]})
	return out


func crossings(d: Dictionary) -> Array:
	var out := []
	var half: float = d["width"] / 2.0 - CROSSING_INSET_CM
	var gaps := ceili(2.0 * half / CROSSING_SPACING_CM)
	for k in gaps + 1:
		out.append(-half + 2.0 * half * k / gaps)
	return out


## Walks each approach in pure logic and tallies the entries: [inside,
## attempts]. Every miss is a failure, with its trace.
func family(main, d: Dictionary, approaches: Array, what: String) -> Array:
	var tally := [0, 0]
	var misses := []
	for a in approaches:
		var start := run_up_start(main.nav, d, a)
		var walk := walk_in(main.nav, start, a["dir"], d["room"])
		tally[1] += 1
		if walk["inside"]:
			tally[0] += 1
		else:
			misses.append("%s: %s after %d steps, cells (along, in; * = door span) %s" % [
				a["label"], walk["why"], walk["cells"].size() - 1, trace(main.nav, d, walk["cells"])])
	assert_true(tally[1] > 0, "%s: %s has approaches" % [what, d["door"]])
	assert_eq(tally[0], tally[1], "%s: %s lets every approach in; missed:\n    %s\n  " % [what, d["door"], "\n    ".join(misses.slice(0, 6))])
	return tally


## Where a walk along `a` begins: on its line (straight in, the line
## `along` off the door's centre; angled, the line crossing the door's
## plane at `along`), up to RUN_UP_CM back, but never beyond the first
## thing in the way outside the door's wall.
func run_up_start(nav: NavQuery, d: Dictionary, a: Dictionary) -> Vector2:
	var dir: Vector2 = a["dir"]
	var cross: Vector2 = d["pos"] + d["tangent"] * a["along"]
	var start := cross
	var s := 0.0
	while s <= RUN_UP_CM:
		var back: Vector2 = d["inward"] if a.get("straight", false) else dir
		var at: Vector2 = cross - back * s
		var depth: float = (at - d["pos"]).dot(d["inward"])
		if depth < -WALL_BAND_CM:
			if not nav.walkable(nav.cell_of(at)):
				break
			start = at
		s += 5.0
	return start


## The steering prediction's walk from `start` along `dir`, as the client
## predicts it frame by frame: {inside, why, cells}. Inside is on the
## room's floor past its door span.
func walk_in(nav: NavQuery, start: Vector2, dir: Vector2, room: String) -> Dictionary:
	var p := Player.new()
	p.nav = nav
	p.reconcile(nav.centre(nav.cell_of(start)))
	var cells: Array = [p.cell]
	while cells.size() <= MAX_STEPS:
		# A step's worth of walking, then the cells a tick boundary sends.
		p.predict(1.0 / Player.STEPS_PER_TICK, dir, nav)
		var stepped := p.cells_this_tick()
		if stepped.is_empty():
			return {"inside": false, "why": "stopped", "cells": cells}
		for c in stepped:
			cells.append(c)
			if nav.room_at(c) == room and not nav.in_door_span(c):
				return {"inside": true, "why": "", "cells": cells}
	return {"inside": false, "why": "slid past", "cells": cells}


static func trace(nav: NavQuery, d: Dictionary, cells: Array) -> String:
	var out := []
	for c in cells:
		var q: Vector2 = nav.centre(c) - d["pos"]
		out.append("(%d,%d)%s" % [int(q.dot(d["tangent"])), int(q.dot(d["inward"])), "*" if nav.in_door_span(c) else ""])
	return " ".join(out)


# ---- Input ----

## The ground direction the client steers by for a stick held toward
## `want` (a ground direction): the stick's screen direction is found by
## search, pushed through the router as joypad motion (its dead zone made
## up for), and turned into ground terms as the client does.
func stick_steer(main, want: Vector2) -> Vector2:
	var pack = main.host.pack
	var best := 0.0
	var best_miss := INF
	for k in 360:
		var phi := deg_to_rad(k)
		var miss := absf(pack.ground_direction(Vector2.from_angle(phi)).angle_to(want))
		if miss < best_miss:
			best_miss = miss
			best = phi
	# Then to a hundredth of a degree either side.
	var around := best
	for k in range(-100, 101):
		var phi := around + deg_to_rad(k / 100.0)
		var miss := absf(pack.ground_direction(Vector2.from_angle(phi)).angle_to(want))
		if miss < best_miss:
			best_miss = miss
			best = phi
	var screen := Vector2.from_angle(best)
	const DEAD_ZONE := 0.2
	var released := []
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var part: float = screen.x if axis == JOY_AXIS_LEFT_X else screen.y
		var e := InputEventJoypadMotion.new()
		e.device = 0
		e.axis = axis
		e.axis_value = 0.0 if absf(part) < 0.001 else signf(part) * (DEAD_ZONE + (1.0 - DEAD_ZONE) * absf(part))
		main.router.handle(e)
		var up := InputEventJoypadMotion.new()
		up.device = 0
		up.axis = axis
		released.append(up)
	var dir: Vector2 = pack.ground_direction(main.router.steering)
	for e in released:
		main.router.handle(e)
	assert_true(absf(dir.angle_to(want)) < deg_to_rad(0.5), "the stick steers within half a degree of %s: %s" % [want, dir])
	return dir


## The ground direction the client steers by while `code` is held.
func key_steer(main, code: int) -> Vector2:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	main.router.handle(down)
	var dir: Vector2 = main.host.pack.ground_direction(main.router.steering)
	var up: InputEventKey = down.duplicate()
	up.pressed = false
	main.router.handle(up)
	return dir


# ---- First person ----

## First person, 3 m out from the door on its centre line and facing it
## a little downward (as tools/probes/door_probe.gd's go_in): A acts on
## the crosshair, and the core walks the player into the door's room.
func go_in(main, d: Dictionary, style: String) -> Array:
	var start: Vector2 = d["pos"] - d["inward"] * RUN_UP_CM
	var p: Player = main.player
	assert_true(stand_at(main, start), "%s: stood 3 m out from %s: %s" % [style, d["door"], main.nav.centre(p.cell)])
	main._toggle_fpv()
	var cam: FpvCamera = main.host.pack.fpv
	cam.yaw = FpvCamera.yaw_along(d["inward"])
	cam.pitch = 0.0
	cam.look(0.0, -5.0)
	land(main)
	var hit: Dictionary = main.interaction.fpv_target()
	var prompt: String = main.interaction.choice()["text"]
	main._interact()
	main._toggle_fpv()
	var inside := false
	for i in 60:
		main.driver.step_once()
		land(main)
		var at = core_cell(main)
		if admitted(main, d["room"]) and at != null and main.nav.room_at(at) == d["room"] and not main.nav.in_door_span(at):
			inside = true
			break
	assert_true(inside, "%s: first person at %s, \"%s\" (%s %s) takes the player into %s; it is at %s in %s" % [
		style, d["door"], prompt, hit.get("type"), hit.get("target"), d["room"], core_cell(main), main.nav.room_at(core_cell(main)) if core_cell(main) != null else "?"])
	return [1 if inside else 0, 1]


## Walks the player (Go, as a click would) to `pos` and waits there,
## standing up first if the last attempt sat it down.
func stand_at(main, pos: Vector2) -> bool:
	var p: Player = main.player
	if p.view.get("seat") != null:
		p.stop_using()
		main.driver.step_once()
		land(main)
	p.go_point(pos)
	for i in 80:
		main.driver.step_once()
		land(main)
		if not p.view.get("moving", false) and not p.following:
			break
	land(main)
	return main.nav.centre(p.cell).distance_to(pos) < 40.0


func core_cell(main):
	var v: Dictionary = main.player.view
	if v.is_empty() or v.get("pos") == null:
		return null
	return main.nav.cell_of(Motion.point(v["pos"]))


func admitted(main, room: String) -> bool:
	var proj: Dictionary = JSON.parse_string(main.driver.world.project_json(main.player.id))
	for r in proj.get("rooms", []):
		if r["id"] == room:
			return r.get("occupants", []).any(func(v): return v["id"] == main.player.id)
	return false
