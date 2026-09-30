## Door-entry probe (spike, not production). Boots the real client
## headless, taps the world boundary (world_tap.gd), stands the player
## outside each building door, then drives real input through the router
## (keys, stick, first person, click, first-person "Go in") and reports,
## per attempt, whether the avatar ended inside the room, the ticks taken,
## the core's refusals and admissions, and the cells the prediction would
## not step to (and why).
##
## godot --headless --path city/godot --script res://tools/probes/door_probe.gd -- \
##     style=lowpoly_tropical crowd=0 controls=stick,keys,keys_aligned,fpv,click,go_in \
##     families=perp,angled doors=all
extends SceneTree

const Tap := preload("res://tools/probes/world_tap.gd")
const DT := 1.0 / 60.0
## Give up an attempt after this many simulated seconds of held input.
const HOLD_S := 14.0
## An attempt has stalled when neither the prediction nor the core has
## moved for this long while input is held.
const STALL_S := 3.0
const START_CM := 300.0

var opts := {"style": "lowpoly_tropical", "crowd": "0", "controls": "stick,keys,keys_aligned,fpv,click,go_in",
	"families": "perp,angled", "doors": "all", "seed": "7", "start_tick": "300", "passes": "1", "offsets": "", "angles": ""}
var main
var tap
var rows: Array = []


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			opts[kv[0]] = kv[1]
	await process_frame
	main = load("res://main.gd").new()
	root.add_child(main)
	main.boot_for_tool(PackedStringArray(["--crowd=" + opts["crowd"], "--seed=" + opts["seed"], "--style=" + opts["style"]]))
	if main.hud.error_label.visible:
		print("BOOT ERROR ", main.hud.error_label.text)
		quit(1)
		return
	tap = Tap.new(main.driver.world)
	tap.player_id = main.player.id
	main.driver.world = tap
	main.player.world = tap
	_arrive()
	while main.driver.world.tick() < int(opts["start_tick"]):
		main.driver.step_once()
	_frames(0.5)
	var doors := _doors()
	print("# style=%s crowd=%s seed=%s player=%s" % [opts["style"], opts["crowd"], opts["seed"], main.player.id])
	for d in doors:
		print("# door %s room=%s pos=%s inward=%s from=%s span_cells=%s" % [d["door"], d["room"], d["pos"], d["inward"], d["from_room"], d["span"]])
	var controls: Array = opts["controls"].split(",")
	var fams: Array = opts["families"].split(",")
	for pass_ in int(opts["passes"]):
		_pass(doors, controls, fams)
	_summary()
	quit(0)


func _pass(doors: Array, controls: Array, fams: Array) -> void:
	for d in doors:
		if opts["doors"] != "all" and not (d["door"] in opts["doors"].split(",")):
			continue
		for control in controls:
			if control in ["fpv", "go_in", "keys_aligned"] and _is_2d():
				continue
			if control in ["click", "go_in"]:
				_attempt(d, control, "aim", 0.0, 0.0)
				continue
			if "perp" in fams:
				var offs := [-100, -75, -50, -37, -25, 0, 25, 37, 50, 75, 100]
				if opts["offsets"] != "":
					offs = Array(opts["offsets"].split(",")).map(func(x): return int(x))
				for off in offs:
					_attempt(d, control, "perp", float(off), 0.0)
			if "angled" in fams:
				var angs := [-60, -45, -30, -15, 15, 30, 45, 60]
				if opts["angles"] != "":
					angs = Array(opts["angles"].split(",")).map(func(x): return int(x))
				for ang in angs:
					_attempt(d, control, "angled", 0.0, float(ang))
			if "sweep" in fams and control != "keys":
				# Every approach angle, the line crossing the door's plane
				# at several points within its span.
				for ang in range(-80, 85, 5):
					for cross in [-45, -30, -15, 0, 15, 30, 45]:
						_attempt(d, control, "sweep", float(cross), float(ang))
			if "keyline" in fams and control == "keys":
				# Each key (or pair) that heads into the door, from a start
				# on its own line through the door, as a player lines up.
				var inward: Vector2 = d["inward"]
				for combo in KEY_COMBOS:
					var g: Vector2 = main.host.pack.ground_direction(_combo_screen(combo))
					if g.dot(inward) < 0.2:
						continue
					for cross in [-37, -12, 12, 37]:
						_attempt(d, control, "keyline", float(cross), rad_to_deg(inward.angle_to(g)))


func _is_2d() -> bool:
	return not main.host.pack.supports_fpv()


# ---- Setup ----

func _arrive() -> void:
	for i in 80:
		main.driver.step_once()
		if main.player.present and not main.player.view.get("moving", false):
			break
	for i in 60:
		if not TestSuite.tram_by_the_square(main.driver.world.real):
			break
		main.driver.step_once()
	_frames(0.5)


## Every door from open ground into an indoor room, and the doors between
## indoor rooms, each with its inward normal.
func _doors() -> Array:
	var out := []
	var rooms := {}
	for dist in main.manifest["city"]["districts"]:
		for f in dist["facilities"]:
			for r in f["rooms"]:
				rooms[r["id"]] = r
	for id in rooms:
		var r: Dictionary = rooms[id]
		if r.get("rect") == null:
			continue
		for door in r.get("doors", []):
			if door.get("pos") == null:
				continue
			var from: Dictionary = rooms.get(door["to"], {})
			var indoor: bool = not (r.get("outdoor", false))
			# Doors into indoor rooms (from outdoors or from another room),
			# plus the café terrace as an outdoor control.
			if not indoor and id != "room:cafe-terrace":
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
			elif int(p.y) == int(rc["z"]) + int(rc["d"]):
				inward = Vector2(0, -1)
			var span := []
			for c in _span_cells(p):
				span.append(c)
			out.append({"door": door["id"], "room": id, "from_room": door["to"], "pos": p, "inward": inward, "span": span.size()})
	return out


func _span_cells(p: Vector2) -> Array:
	var nav: NavQuery = main.nav
	var out := []
	var c0 := nav.cell_of(p)
	for dj in range(-3, 4):
		for di in range(-3, 4):
			var c := c0 + Vector2i(di, dj)
			if nav.in_door_span(c) and nav.centre(c).distance_to(p) < 80:
				out.append(c)
	return out


func _frames(seconds: float) -> void:
	for f in int(round(seconds / DT)):
		main._process(DT)
		main.driver.frame(DT)


## Walks the player (Go, as a click would) to `pos_cm` and waits there.
func _stand_at(pos_cm: Vector2) -> bool:
	_release_all()
	main.player.cancel()
	# A Steer [] (the cancel) applies after a Go in the same tick and would
	# drop it: let the tick pass first.
	_frames(1.1)
	if main.player.view.get("seat") != null:
		main.player.stop_using()
		_frames(1.1)
	var r: Dictionary = main.player.go_point(pos_cm)
	if r.has("error") or r.get("deferred", false):
		print("# stand_at go_point ", pos_cm, " -> ", r)
	var stable := 0
	var prev = null
	for i in 60:
		_frames(1.0)
		var cc = _core_cell()
		if cc != null and cc == prev and main.player.present and not main.player.following and not main.player.view.get("moving", false):
			stable += 1
			if stable >= 2:
				break
		else:
			stable = 0
		prev = cc
	_frames(0.5)
	if main.player.view.get("seat") != null or main.nav.centre(main.player.cell).distance_to(pos_cm) >= 40:
		var cmds := []
		for k in range(maxi(0, tap.commands.size() - 4), tap.commands.size()):
			cmds.append(tap.commands[k])
		print("# stand_at %s missed: at %s seat=%s loc=%s last commands %s" % [pos_cm, main.nav.centre(main.player.cell), main.player.view.get("seat"), _location(), JSON.stringify(cmds)])
	return main.player.cell == main.nav.cell_of(pos_cm) or main.nav.centre(main.player.cell).distance_to(pos_cm) < 40


# ---- Input ----

var _held_events: Array = []


func _key(code: int, down: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	return e


const KEY_COMBOS := [[KEY_W], [KEY_S], [KEY_A], [KEY_D], [KEY_W, KEY_D], [KEY_W, KEY_A], [KEY_S, KEY_D], [KEY_S, KEY_A]]


func _combo_screen(combo: Array) -> Vector2:
	var v := Vector2.ZERO
	for k in combo:
		match k:
			KEY_W: v.y -= 1
			KEY_S: v.y += 1
			KEY_A: v.x -= 1
			KEY_D: v.x += 1
	return v.limit_length(1.0)


func _press_keys(combo: Array) -> void:
	for k in combo:
		var e := _key(k, true)
		main.router.handle(e)
		_held_events.append(_key(k, false))


func _stick(screen: Vector2) -> void:
	# A player's stick at `screen`; the per-axis dead zone (0.2) is made up
	# for, so the router's steering is `screen` itself.
	const DZ := 0.2
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var comp: float = screen.x if axis == JOY_AXIS_LEFT_X else screen.y
		var e := InputEventJoypadMotion.new()
		e.device = 0
		e.axis = axis
		e.axis_value = 0.0 if absf(comp) < 0.001 else signf(comp) * (DZ + (1.0 - DZ) * absf(comp))
		main.router.handle(e)
		var up := InputEventJoypadMotion.new()
		up.device = 0
		up.axis = axis
		up.axis_value = 0.0
		_held_events.append(up)


func _release_all() -> void:
	for e in _held_events:
		main.router.handle(e)
	_held_events.clear()


## The screen direction (overhead) whose ground direction is nearest `dir`.
func _screen_for(dir: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_a := INF
	for k in 3600:
		var phi := TAU * k / 3600.0
		var s := Vector2(cos(phi), sin(phi))
		var g: Vector2 = main.host.pack.ground_direction(s)
		var a := absf(g.angle_to(dir))
		if a < best_a:
			best_a = a
			best = s
	return best


# ---- Attempts ----

func _attempt(d: Dictionary, control: String, family: String, offset_cm: float, angle_deg: float) -> void:
	var inward: Vector2 = d["inward"]
	var tangent := Vector2(-inward.y, inward.x)
	var dir := inward.rotated(deg_to_rad(angle_deg))
	var start: Vector2 = d["pos"] - dir * START_CM + tangent * offset_cm
	if family == "aim":
		start = d["pos"] - inward * START_CM
	if d["from_room"] != "room:plaza" and not main.nav.room_at(main.nav.cell_of(start)) in [d["from_room"]]:
		pass
	var placed := _stand_at(start)
	var row := {"style": opts["style"], "crowd": opts["crowd"], "door": d["door"], "room": d["room"], "control": control,
		"family": family, "offset": offset_cm, "angle": angle_deg, "placed": placed,
		"start_cell": main.player.cell, "start_room": main.nav.room_at(main.player.cell)}
	row["tick0"] = main.driver.world.tick()
	row["room_state"] = _room_state(d["room"])
	var ev0: int = tap.events.size()
	var cmd0: int = tap.commands.size()
	var steps0: int = tap.steps
	var ground_dir := dir
	var yaw0 := 0.0
	var fpv_on := false
	# Drive the input.
	match control:
		"stick":
			var s := _screen_for(dir)
			ground_dir = main.host.pack.ground_direction(s)
			_stick(s)
		"keys":
			var best: Array = KEY_COMBOS[0]
			var best_a := INF
			for combo in KEY_COMBOS:
				var g: Vector2 = main.host.pack.ground_direction(_combo_screen(combo))
				var a := absf(g.angle_to(dir))
				if a < best_a:
					best_a = a
					best = combo
			ground_dir = main.host.pack.ground_direction(_combo_screen(best))
			row["keys"] = best.map(func(k): return OS.get_keycode_string(k))
			_press_keys(best)
		"keys_aligned":
			var rig = main.host.pack.rig
			yaw0 = rig.yaw
			rig.yaw = FpvCamera.yaw_along(dir)
			rig.update()
			ground_dir = main.host.pack.ground_direction(Vector2(0, -1))
			_press_keys([KEY_W])
		"fpv":
			main._toggle_fpv()
			fpv_on = true
			var cam: FpvCamera = main.host.pack.fpv
			cam.pitch = 0.0
			cam.yaw = FpvCamera.yaw_along(dir)
			cam.look(0.0, -5.0)
			_frames(0.1)
			ground_dir = main.fpv_steer(Vector2(0, -1))
			_press_keys([KEY_W])
		"click":
			var target: Vector2 = d["pos"] + inward * 150.0
			var sp = main.host.pack.screen_at(target)
			row["click_screen"] = sp
			if sp != null:
				main._on_walk_to(sp)
		"go_in":
			main._toggle_fpv()
			fpv_on = true
			var cam: FpvCamera = main.host.pack.fpv
			cam.pitch = 0.0
			cam.yaw = FpvCamera.yaw_along(inward)
			cam.look(0.0, -5.0)
			_frames(0.1)
			var hit: Dictionary = main.fpv_target()
			row["aim"] = "%s:%s" % [hit.get("type"), hit.get("target")]
			row["prompt"] = main.choice()["text"]
			main._interact()
			row["go_room"] = main.player.last_go_room
	row["ground_dir_deg"] = snappedf(rad_to_deg(ground_dir.angle_to(inward)), 0.1)
	# Run until inside, stalled or out of time.
	var last_cell: Vector2i = main.player.cell
	var last_core = _core_cell()
	var still := 0.0
	var t := 0.0
	var mism := 0
	var mism_detail := []
	var last_steps: int = tap.steps
	var inside_at := -1.0
	var max_depth := -INF
	var hold := HOLD_S if control not in ["click", "go_in"] else 25.0
	while t < hold:
		_frames(DT * 6)
		t += DT * 6
		if tap.steps != last_steps:
			last_steps = tap.steps
			# Compare the core's cell after the tick with the last cell the
			# client sent in it.
			var sent = _last_steer_since(cmd0)
			if sent != null and _core_cell() != null and sent["tick"] == main.driver.world.tick() - 1:
				var cells: Array = sent["cmd"]["cells"]
				if not cells.is_empty():
					var want: Vector2i = main.nav.cell_of(Vector2(cells[-1]["x"], cells[-1]["z"]))
					if want != _core_cell():
						mism += 1
						if mism_detail.size() < 3:
							mism_detail.append("%s->core %s" % [want, _core_cell()])
		var cc = _core_cell()
		if cc != null:
			var depth: float = (main.nav.centre(cc) - d["pos"]).dot(inward)
			max_depth = maxf(max_depth, depth)
		if _admitted_in(d["room"]) and cc != null and main.nav.room_at(cc) == d["room"] and not main.nav.in_door_span(cc):
			inside_at = t
			break
		if main.player.cell == last_cell and cc == last_core:
			still += DT * 6
			if still >= STALL_S and control not in ["click", "go_in"]:
				break
			if still >= 8.0:
				break
		else:
			still = 0.0
			last_cell = main.player.cell
			last_core = cc
	# Why the prediction would not go on (steered controls).
	if inside_at < 0.0 and control not in ["click", "go_in"]:
		row["why"] = _why_not(ground_dir)
	_release_all()
	if control == "keys_aligned":
		main.host.pack.rig.yaw = yaw0
		main.host.pack.rig.update()
	if fpv_on:
		main._toggle_fpv()
	var cc = _core_cell()
	row["inside"] = inside_at >= 0.0
	row["seconds"] = snappedf(inside_at if inside_at >= 0.0 else t, 0.1)
	row["ticks"] = tap.steps - steps0
	row["end_cell"] = cc
	if cc != null:
		var rel: Vector2 = main.nav.centre(cc) - d["pos"]
		row["end_along"] = int(rel.dot(Vector2(-inward.y, inward.x)))
		row["end_depth"] = int(rel.dot(inward))
		row["end_room"] = main.nav.room_at(cc)
		row["end_in_span"] = main.nav.in_door_span(cc)
	row["max_depth"] = max_depth
	row["loc"] = _location()
	var evs := {}
	for k in range(ev0, tap.events.size()):
		var kind: Dictionary = tap.events[k]["event"].get("kind", {})
		var key := str(kind.get("type"))
		if key == "Rejected":
			key += "/" + str(kind.get("command")) + "/" + str(kind.get("reason"))
		elif key in ["Admitted", "Waitlisted", "Overflowed"]:
			key += "/" + str(kind.get("room", kind.get("to", "")))
		evs[key] = evs.get(key, 0) + 1
	row["events"] = evs
	var steers := 0
	var gos := []
	for k in range(cmd0, tap.commands.size()):
		var c: Dictionary = tap.commands[k]["cmd"]
		if c.get("type") == "Steer":
			steers += 1
		elif c.get("type") == "Go":
			gos.append("%s->%s" % [JSON.stringify(c["to"]), JSON.stringify(tap.commands[k]["reply"])])
	row["steers"] = steers
	row["gos"] = gos
	row["mismatch"] = mism
	row["mismatch_detail"] = mism_detail
	rows.append(row)
	print("ROW ", JSON.stringify(row))


func _room_state(id: String) -> String:
	for room in tap.last_proj.get("rooms", []):
		if room["id"] != id:
			continue
		var occ: Array = room.get("occupants", [])
		var present: int = occ.filter(func(v): return Player.holds_cells(v)).size()
		var sat := {}
		for v in occ:
			if v.get("seat") != null:
				sat[v["seat"]] = true
		var unclaimed: int = room.get("seats", []).filter(func(s): return s.get("reserved", false) and not sat.has(s["id"])).size()
		var closed: bool = id in Player.closed_rooms(tap.last_proj, main.player.id)
		return "cap=%d public=%d unclaimed=%d waiting=%d closed=%s" % [int(room.get("capacity", 0)), present, unclaimed, room.get("waiting", []).size(), closed]
	return "?"


func _last_steer_since(k0: int):
	for k in range(tap.commands.size() - 1, k0 - 1, -1):
		if tap.commands[k]["cmd"].get("type") == "Steer":
			return tap.commands[k]
	return null


func _core_cell():
	var v: Dictionary = Player.own_view(tap.last_proj, main.player.id) if not tap.last_proj.is_empty() else {}
	if v.is_empty() or v.get("pos") == null:
		return null
	return main.nav.cell_of(Motion.point(v["pos"]))


func _admitted_in(room: String) -> bool:
	for r in tap.last_proj.get("rooms", []):
		if r["id"] == room:
			return r.get("occupants", []).any(func(v): return v["id"] == main.player.id)
	return false


func _location() -> String:
	for r in tap.last_proj.get("rooms", []):
		if r.get("occupants", []).any(func(v): return v["id"] == main.player.id):
			return "in " + str(r["id"])
		if r.get("waiting", []).any(func(v): return v["id"] == main.player.id):
			return "waiting " + str(r["id"])
	if tap.last_proj.get("in_transit", []).any(func(v): return v["id"] == main.player.id):
		return "in_transit"
	return "?"


## The prediction's candidate steps from where it stands along `dir`, in
## its order, each with why it is refused (as Player._next_cell decides).
func _why_not(dir: Vector2) -> Array:
	var p: Player = main.player
	var nav: NavQuery = main.nav
	var out := []
	var ranked := []
	for k in Player.NEIGHBOURS.size():
		var off: Vector2i = Player.NEIGHBOURS[k]
		var ahead := Vector2(off).normalized().dot(dir)
		if ahead < Player.SLIDE_COS:
			continue
		var away := absf(dir.cross(nav.centre(p.cell + off) - p._anchor))
		ranked.append([snappedf(away, 0.01), -ahead, k])
	ranked.sort()
	for r in ranked:
		var off: Vector2i = Player.NEIGHBOURS[r[2]]
		var c: Vector2i = p.cell + off
		var why := "ok"
		if not nav.walkable(c):
			why = "not-floor"
		elif not nav.can_step(p.cell, c):
			if off.x != 0 and off.y != 0:
				why = "diagonal-across-rooms/corner"
			else:
				why = "wall(no shared span)"
		elif nav.is_held(c):
			why = "held"
		elif not nav.enterable(p.cell, c):
			why = "closed-room"
		out.append("%s:%s" % [off, why])
	return out


func _summary() -> void:
	var by := {}
	for r in rows:
		var key := "%s|%s|%s" % [r["door"], r["control"], r["family"]]
		if not by.has(key):
			by[key] = [0, 0]
		by[key][1] += 1
		if r["inside"]:
			by[key][0] += 1
	for k in by:
		print("SUM %s %d/%d" % [k, by[k][0], by[k][1]])
