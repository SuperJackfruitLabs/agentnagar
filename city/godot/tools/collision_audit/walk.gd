## The collision audit's recorded day: every public walker's cells tick by
## tick (what the client draws them crossing), the trams, and the player
## walked along every street and into every building. The core decides
## all of it, so the day is the same in every style.
extends RefCounted

## A waypoint along a street every this many metres.
const STREET_STEP_M := 8.0
## The most ticks the player spends reaching one waypoint.
const LEG_TICKS := 80
## Ticks standing still before a leg counts as stuck.
const STUCK_TICKS := 4
## The most ticks the whole run takes, the player's walk included.
const MAX_TICKS := 2400


## A day's record: visits are flat [tick, occupant, i, j, end] records
## (end 1 for the cell a walker ends the tick on); seated [tick, occupant,
## i, j] where the seated sit; vehicles [tick, vehicle, x, z, heading]
## (centimetres, degrees), each vehicle's line in vehicle_lines; the
## player's visits [tick, i, j, end].

## The cells a view crossed last tick (0) and stands on now (1): cell ->
## whether it is where the view ends the tick.
static func _cells(nav: NavQuery, v: Dictionary) -> Dictionary:
	var out := {}
	for p in v.get("trail", []):
		out[nav.cell_of(Motion.point(p))] = 0
	if v.get("pos") != null:
		out[nav.cell_of(Motion.point(v["pos"]))] = 1
	return out


## The player's route: points every STREET_STEP_M along every street and
## the bridge (snapped to the nearest walkable cell), then every indoor
## room by `go_room`.
static func route(main) -> Array:
	var nav: NavQuery = main.nav
	var legs := []
	for item in main.manifest.get("scenery", []):
		var kind := str(item.get("kind", ""))
		if kind != "street" and kind != "bridge":
			continue
		var pts := CityGeometry.scenery_points(item)
		for k in range(1, pts.size()):
			var a: Vector2 = pts[k - 1]
			var b: Vector2 = pts[k]
			var n := maxi(1, int(ceil(a.distance_to(b) / STREET_STEP_M)))
			for s in n + 1:
				var c = _snap(nav, a.lerp(b, float(s) / n) * 100.0)
				if c != null:
					legs.append({"kind": "point", "street": kind, "cell": c, "at": nav.centre(c)})
	for id in nav.room_ids:
		var r := CityGeometry.room_of(main.manifest, id)
		var indoor: bool = nav._outdoor[nav.room_ids.find(id)] == 0 and str(r.get("template", "")) != "ground"
		if indoor:
			legs.append({"kind": "room", "room": id})
			# And back out to the square (south of its tree) before the next.
			var out = _snap(nav, main.square_centre() + Vector2(0, 600))
			if out != null:
				legs.append({"kind": "point", "street": "exit", "cell": out, "at": nav.centre(out)})
	return legs


## The walkable cell nearest `p_cm` within 6 m, or null.
static func _snap(nav: NavQuery, p_cm: Vector2):
	var c0 := nav.cell_of(p_cm)
	for r in range(0, 25):
		var best = null
		var best_d := INF
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				if maxi(absi(di), absi(dj)) != r:
					continue
				var c := c0 + Vector2i(di, dj)
				if nav.walkable(c):
					var d := nav.centre(c).distance_to(p_cm)
					if d < best_d:
						best = c
						best_d = d
		if best != null:
			return best
	return null


## Runs the day: `ticks` ticks recorded for every public walker (seated and
## aboard people are not walking), the player walking its route meanwhile
## and on until it is done. Returns the record.
static func day(main, ticks: int, tree: SceneTree) -> Dictionary:
	var nav: NavQuery = main.nav
	var ids := {}
	var id_list := []
	var visits := PackedInt32Array()
	var seated := PackedInt32Array()
	var vehicles := PackedFloat64Array()
	var vid := {}
	var vehicle_lines := []
	var player_visits := PackedInt32Array()
	var legs := route(main)
	var log := []
	var leg := -1
	var leg_start := 0
	var still := 0
	var last_cell := Vector2i(-1, -1)
	var pid: String = main.player.id
	var tick := 0
	var started := false
	while tick < MAX_TICKS:
		main.driver.step_once()
		tick += 1
		var p = JSON.parse_string(main.driver.world.project_json(main.driver.viewer))
		if not p is Dictionary:
			continue
		var flat := SceneModel._flatten(p)
		if tick <= ticks:
			for id in flat:
				var v: Dictionary = flat[id]["view"]
				if id == pid or v.get("vehicle") != null or v.get("pos") == null:
					continue
				if not ids.has(id):
					ids[id] = id_list.size()
					id_list.append(id)
				if v.get("seat") != null:
					# Seated: where, so walking to and from a seat can be told
					# apart from walking through furniture.
					var at := nav.cell_of(Motion.point(v["pos"]))
					seated.append_array([tick, ids[id], at.x, at.y])
					continue
				var cells := _cells(nav, v)
				for c in cells:
					visits.append_array([tick, ids[id], c.x, c.y, cells[c]])
			for v in p.get("vehicles", []):
				if not vid.has(v["id"]):
					vid[v["id"]] = vid.size()
					vehicle_lines.append(str(v.get("line", "")))
				vehicles.append_array([tick, vid[v["id"]], v["pos"]["x"], v["pos"]["z"], v["heading"]])
		# The player.
		var me: Dictionary = flat.get(pid, {}).get("view", {})
		var on_ground: bool = not me.is_empty() and me.get("vehicle") == null and me.get("pos") != null
		if on_ground:
			var cells := _cells(nav, me)
			for c in cells:
				player_visits.append_array([tick, c.x, c.y, cells[c]])
		if not started:
			if on_ground:
				started = true
				leg = -1
				still = STUCK_TICKS
			elif tick > ticks:
				break
		if started and leg < legs.size():
			var here: Vector2i = nav.cell_of(Motion.point(me["pos"])) if on_ground else last_cell
			still = still + 1 if here == last_cell and not me.get("moving", false) else 0
			last_cell = here
			var arrived := false
			if leg >= 0:
				var L: Dictionary = legs[leg]
				if L["kind"] == "point":
					arrived = here == L["cell"] or (here - L["cell"]).length() <= 1.5
				else:
					arrived = nav.room_at(here) == L["room"] and still >= 2
			if leg < 0 or arrived or still >= STUCK_TICKS + 2 or tick - leg_start > LEG_TICKS:
				if leg >= 0:
					log.append({"leg": leg, "ended": tick, "how": "arrived" if arrived else ("stuck" if still >= STUCK_TICKS + 2 else "timeout"),
						"at": [here.x, here.y]})
				leg += 1
				while leg < legs.size():
					var L: Dictionary = legs[leg]
					var r: Dictionary = main.player.go_point(L["at"]) if L["kind"] == "point" else main.player.go_room(L["room"])
					leg_start = tick
					still = 0
					if r.get("ok", false):
						break
					log.append({"leg": leg, "ended": tick, "how": "refused", "reply": r})
					leg += 1
		if tick >= ticks and (not started or leg >= legs.size()):
			break
		if tick % 50 == 0:
			await tree.process_frame
	var wp := []
	for L in legs:
		wp.append(L.duplicate() if L["kind"] == "room" else {"kind": "point", "street": L["street"], "cell": [L["cell"].x, L["cell"].y]})
	return {"day_ticks": ticks, "ticks_run": tick, "occupants": id_list, "visits": visits,
		"seated": seated, "vehicles": vehicles, "vehicle_ids": vid.keys(), "vehicle_lines": vehicle_lines,
		"player": {"id": pid, "visits": player_visits, "waypoints": wp, "log": log}}
