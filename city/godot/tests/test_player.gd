## The local player: its client-side walkable grid, predicted steering that
## the real core accepts cell for cell, and corrections that ease.
extends TestSuite

const FPS := 60.0
const EAST := Vector2(1, 0)


func layout(w) -> Dictionary:
	return JSON.parse_string(w.layout_json())


func loaded(crowd := 0):
	var w = ClassDB.instantiate("CityWorld")
	var r: Dictionary = JSON.parse_string(w.load(CityPaths.district_manifest(), CityPaths.district_feed(), 7, crowd))
	assert_eq(r.get("ok"), true, "the district loads")
	return w


## A joined player standing still at the tram stop, and the world and grid
## it walks: {world, nav, player, clock}. It rides in on east:1, the tram
## that reaches the Square first, and steps off onto the tram stop.
func joined(as_: String, crowd := 0) -> Dictionary:
	var w = loaded(crowd)
	var nav := NavQuery.from_layout(layout(w))
	var p := Player.new()
	assert_eq(p.join(w, as_, "1,2").get("ok"), true, "joins as " + as_)
	for i in 80:
		w.step()
		p.observe(JSON.parse_string(w.project_json(p.id)), nav)
		if p.present and not p.view.get("moving", false):
			break
	assert_true(p.present and not p.view.get("moving", false), "it has arrived and stands still")
	# It rode in and stepped off at the Square among the tram's other
	# riders, who walk on past it: the tests start once no tram is by the
	# Square and they have gone, with it standing alone and the tracks
	# clear, as it used to arrive.
	for i in 40:
		if not tram_by_the_square(w):
			break
		w.step()
	assert_true(not tram_by_the_square(w), "the trams have left the Square")
	p.observe(JSON.parse_string(w.project_json(p.id)), nav)
	# No trail replay runs here: let the display settle where it stands.
	p.predict(Player.EASE_S, Vector2.ZERO, nav)
	return {"world": w, "nav": nav, "player": p, "clock": 0.0, "sent": [], "accepted": []}


## Runs `seconds` of frames at 1x, steering `steer` (a ground direction),
## as the client does: every frame, predict, showing a Go walk from its
## trail; on each tick boundary send the tick's cells, step the world,
## observe the result and replay the new trail. `each_frame` sees the
## session after every frame.
func play(s: Dictionary, seconds: float, steer: Vector2, each_frame := Callable()) -> void:
	var p: Player = s["player"]
	var trail: Motion = s.get_or_add("trail", Motion.new())
	for f in int(round(seconds * FPS)):
		var replay = trail.sample(p.id, s["clock"])["pos"] if trail.has(p.id) else null
		p.predict(1.0 / FPS, steer, s["nav"], replay)
		s["clock"] += 1.0 / FPS
		if s["clock"] >= 1.0 - 1e-6:
			s["clock"] = 0.0
			var was = p.view.get("pos")
			var sent := p.submit_tick()
			s["world"].step()
			var own: Dictionary = JSON.parse_string(s["world"].project_json(p.id))
			p.observe(own, s["nav"])
			var moved: Array = p.view.get("trail", [])
			trail.set_track(p.id, was if was != null and not moved.is_empty() else p.view.get("pos", {}), moved)
			s["sent"].append(sent.map(func(c): return s["nav"].centre(c)))
			s["accepted"].append(moved.map(func(t): return Motion.point(t)))
		if each_frame.is_valid():
			each_frame.call(s)


## The grid the core derives from `rooms`, in one facility of one
## district, and the district's `placements`, as the client loads it. Rooms
## need only an ID and a rect, and doors an ID, a room and a position. The city's entrance lies on open
## ground, so a patch of it is laid a metre east of every room, touching
## none, for the core to accept the layout.
func core_nav(rooms: Array, placements: Array = []) -> NavQuery:
	var laid := rooms.map(func(r):
		var room: Dictionary = {"name": r["id"], "capacity": 50}.merged(r, true)
		room["doors"] = r.get("doors", []).map(func(d): return {"transit": {"min": 1, "max": 1}}.merged(d, true))
		return room)
	var east := 0
	for r in rooms:
		east = maxi(east, r["rect"]["x"] + r["rect"]["w"])
	var way_in := {"x": east + 100, "z": rooms[0]["rect"]["z"], "w": 100, "d": 100}
	laid.append({"id": "room:way-in", "name": "Way in", "capacity": 50, "outdoor": true, "rect": way_in})
	var m := {"schema_version": 2, "catalogue": 1, "city": {"id": "city:t", "name": "T",
		"entrances": [{"x": way_in["x"] + 50, "z": way_in["z"] + 50}],
		"districts": [{"id": "district:t", "name": "T", "placements": placements,
			"facilities": [{"id": "facility:t", "name": "T", "rooms": laid}]}]}}
	var feed := JSON.stringify({"record": "header", "schema_version": 1, "source": "fixture:test", "fixture": true}) + "\n"
	var w = ClassDB.instantiate("CityWorld")
	var r: Dictionary = JSON.parse_string(w.load(JSON.stringify(m), feed, 1, 0))
	assert_eq(r.get("ok"), true, "the rooms load: %s" % r)
	return NavQuery.from_layout(layout(w))


static func steps_apart(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


# ---- The walkable grid ----

func test_the_grid_follows_rooms_shells_and_doors() -> void:
	var nav := NavQuery.from_layout(layout(loaded()))
	var plaza := nav.cell_of(Vector2(0, 1390))
	var tram := nav.cell_of(Vector2(0, 1410))
	assert_eq(nav.room_at(plaza), "room:plaza", "north of the line is the plaza")
	assert_eq(nav.room_at(tram), "room:tram-stop", "south of it is the tram stop")
	assert_true(nav.can_step(tram, plaza), "open ground joins open ground anywhere along the edge")
	# The guild hall's shell stands outside its rooms, on the square's
	# edge column.
	var hall := nav.cell_of(Vector2(-1810, -1200))
	var wall := nav.cell_of(Vector2(-1790, -1200))
	var paving := nav.cell_of(Vector2(-1765, -1200))
	assert_true(nav.walkable(hall) and nav.walkable(paving), "the workshop and the square are both floor")
	assert_true(not nav.walkable(wall), "but the hall's wall stands between them")
	assert_true(nav.can_step(nav.cell_of(Vector2(-1790, -600)), nav.cell_of(Vector2(-1810, -600))), "except at its door")
	assert_eq(nav.room_at(nav.cell_of(Vector2(0, 1810))), "room:tram-street", "the tram street lies south of the stop")
	assert_true(not nav.walkable(nav.cell_of(Vector2(0, -6660))), "nothing past the city's edge")
	assert_true(not nav.can_step(tram, tram + Vector2i(2, 0)), "one cell at a time")
	var centre := nav.centre(tram)
	assert_eq(nav.cell_of(centre), tram, "a cell's centre is in the cell")
	assert_eq(fposmod(centre.x - nav.origin.x, 25.0), 12.0, "centres round down to whole centimetres, as the core's do")


func test_outdoor_rooms_join_along_their_shared_edge_as_the_core_says() -> void:
	# A hall (indoor) and a yard (outdoor) side by side, and a street
	# (outdoor) below both: no doors anywhere.
	var nav := core_nav([
		{"id": "room:hall", "rect": {"x": 0, "z": 0, "w": 100, "d": 100}, "doors": []},
		{"id": "room:yard", "outdoor": true, "rect": {"x": 100, "z": 0, "w": 100, "d": 100}, "doors": []},
		{"id": "room:street", "template": "plaza", "rect": {"x": 0, "z": 100, "w": 200, "d": 100}, "doors": []},
	])
	assert_true(nav.can_step(Vector2i(5, 2), Vector2i(5, 4)) == false, "two cells is never one step")
	assert_true(nav.can_step(Vector2i(5, 3), Vector2i(5, 4)), "yard to street, no door")
	assert_true(nav.can_step(Vector2i(4, 3), Vector2i(5, 4)), "diagonally, all open ground")
	assert_true(not nav.can_step(Vector2i(3, 3), Vector2i(3, 4)), "the hall's wall to the street")
	assert_true(not nav.can_step(Vector2i(3, 2), Vector2i(4, 2)), "the hall's wall to the yard")
	assert_true(not nav.can_step(Vector2i(3, 3), Vector2i(4, 4)), "no diagonal past the hall's corner")


func test_the_grid_leaves_out_placements_and_never_cuts_a_corner() -> void:
	# Two rooms side by side, 1 m by 2 m, with a door 50 cm down their shared
	# wall, and a bollard on the wall at x 50 (where schema 1 had a 25 cm
	# obstacle in cell (2, 0)): with the clearance it takes cells (1, 0) and
	# (2, 0).
	var nav := core_nav([
		{"id": "room:a", "capacity": 4, "rect": {"x": 0, "z": 0, "w": 100, "d": 200},
			"doors": [{"id": "door:a-b", "to": "room:b", "pos": {"x": 100, "z": 50}}]},
		{"id": "room:b", "capacity": 4, "rect": {"x": 100, "z": 0, "w": 100, "d": 200}, "doors": []},
	], [{"id": "placement:bollard", "kind": "bollard", "at": {"x": 50, "z": 0}}])
	assert_true(not nav.walkable(Vector2i(2, 0)) and not nav.walkable(Vector2i(1, 0)), "a placement's cells are not floor")
	assert_true(nav.walkable(Vector2i(0, 0)) and nav.walkable(Vector2i(3, 0)), "but its neighbours are")
	assert_true(not nav.can_step(Vector2i(1, 1), Vector2i(2, 0)), "no step diagonally past the placement's corner")
	assert_true(nav.can_step(Vector2i(3, 2), Vector2i(4, 2)), "through the door span")
	assert_true(nav.can_step(Vector2i(3, 0), Vector2i(4, 0)), "the span reaches 50 cm along the wall")
	assert_true(not nav.can_step(Vector2i(3, 5), Vector2i(4, 5)), "but not through the wall beyond it")
	assert_true(not nav.can_step(Vector2i(3, 1), Vector2i(4, 2)), "never diagonally between rooms")
	nav.set_held([Vector2i(1, 1)])
	assert_true(nav.is_held(Vector2i(1, 1)) and not nav.is_held(Vector2i(1, 2)), "held cells are known")


# ---- Prediction against the real core ----

func test_predicted_cells_for_a_straight_walk_equal_what_the_core_accepts() -> void:
	var s := joined("registered")
	var p: Player = s["player"]
	var start := p.cell
	play(s, 4.0, EAST)
	for k in s["sent"].size():
		assert_eq(s["sent"][k].size(), 5, "tick %d: five cells, 125 cm" % k)
		assert_eq(s["accepted"][k], s["sent"][k], "tick %d: the core accepts every predicted cell" % k)
	assert_eq(p.cell, start + Vector2i(20, 0), "four ticks of walking east")
	assert_eq(s["nav"].cell_of(Motion.point(p.view["pos"])), p.cell, "the core stands where the prediction does")


func test_an_observer_wandering_everywhere_is_never_corrected() -> void:
	var s := joined("observer", 60)
	var p: Player = s["player"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var rooms := {}
	for leg in 30:
		var heading := Vector2.from_angle(rng.randf() * TAU)
		play(s, 2.0, heading, func(x): rooms[x["nav"].room_at(x["player"].cell)] = true)
	for k in s["sent"].size():
		assert_eq(s["accepted"][k], s["sent"][k], "tick %d: every predicted step is one the core allows" % k)
	assert_true(rooms.size() >= 2, "the walk crossed between rooms: %s" % str(rooms.keys()))


func test_walking_into_a_wall_does_not_move() -> void:
	var s := joined("registered")
	var p: Player = s["player"]
	# South from the tram stop, across the tracks and the lane, between the
	# houses and on to the fence at the city's southern edge: the player
	# steps off east:1 at x = 6.4 m, in line with the gap between two
	# houses, so the first wall that way is the fence, 33 m on.
	play(s, 40.0, Vector2(0, 1))
	var against := p.cell
	assert_true(not s["nav"].walkable(against + Vector2i(0, 1)), "it walked up to the wall")
	play(s, 2.0, Vector2(0, 1))
	assert_eq(p.cell, against, "pressing on does not move it")
	assert_eq(s["sent"][-1], [], "and sends no steps")
	assert_eq(s["nav"].cell_of(Motion.point(p.view["pos"])), against, "the core agrees")


func test_a_tap_walks_one_metre() -> void:
	var s := joined("registered")
	var p: Player = s["player"]
	var start := p.cell
	p.predict(1.0 / FPS, EAST, s["nav"])
	play(s, 2.0, Vector2.ZERO)
	assert_eq(p.cell, start + Vector2i(4, 0), "four cells for one press")
	assert_eq(s["nav"].cell_of(Motion.point(p.view["pos"])), p.cell, "and the core took them")


func test_a_correction_eases_and_never_jumps_more_than_a_frame() -> void:
	var s := joined("registered")
	var p: Player = s["player"]
	var nav: NavQuery = s["nav"]
	play(s, 0.5, EAST)
	var before := p.shown
	# The core puts the player a metre away from where it predicted.
	var elsewhere := p.cell + Vector2i(-4, 0)
	p.reconcile(nav.centre(elsewhere))
	assert_eq(p.cell, elsewhere, "the prediction rebases on the core")
	assert_true(p.shown.is_equal_approx(before), "the display has not jumped")
	var offset := before.distance_to(nav.centre(elsewhere))
	var last := p.shown
	for f in int(FPS * 0.25) + 2:
		p.predict(1.0 / FPS, Vector2.ZERO, nav)
		var moved := p.shown.distance_to(last)
		assert_true(moved <= offset / (0.25 * FPS) + 0.01, "frame %d: moves %.2f cm, one frame's worth of easing" % [f, moved])
		last = p.shown
	assert_true(p.shown.is_equal_approx(nav.centre(elsewhere)), "after 0.25 s it is where the core says")


func test_steering_through_a_crowd_is_never_corrected() -> void:
	var s := joined("registered", 60)
	var p: Player = s["player"]
	# Into the busy square, along its wall, and back out over the tram stop.
	var rooms := {}
	for heading in [Vector2(0, -1), Vector2(-1, -1).normalized(), Vector2(-1, 0), Vector2(0, 1), Vector2(1, 1).normalized()]:
		play(s, 6.0, heading, func(x): rooms[x["nav"].room_at(x["player"].cell)] = true)
	for k in s["sent"].size():
		assert_eq(s["accepted"][k], s["sent"][k], "tick %d: the prediction steps round the people the core would refuse" % k)
	assert_true(rooms.has("room:plaza"), "it got into the square: " + str(rooms.keys()))


func test_drift_against_a_crowd_stays_within_one_tick_of_walking() -> void:
	var s := joined("registered", 60)
	var p: Player = s["player"]
	var nav: NavQuery = s["nav"]
	play(s, 60.0, Vector2.ZERO)
	# Someone seated and settled, and a click that walks up beside them.
	var seated := {}
	for v in Player.views_of(JSON.parse_string(s["world"].project_json(p.id))):
		var c := nav.cell_of(Motion.point(v["pos"])) if v.get("pos") != null else Vector2i.ZERO
		if v.get("seat") != null and not v.get("moving", false) and Player.holds_cells(v) \
				and (seated.is_empty() or steps_apart(c, p.cell) < steps_apart(seated["cell"], p.cell)):
			seated = {"cell": c, "id": v["id"]}
	assert_true(not seated.is_empty(), "someone is sitting")
	assert_eq(p.go_point(nav.centre(seated["cell"])).get("ok"), true, "Go to them")
	for i in 60:
		play(s, 1.0, Vector2.ZERO)
		if i > 1 and not p.following:
			break
	assert_true(steps_apart(p.cell, seated["cell"]) <= 2, "the walk ends beside them")
	# Now steer into them with a prediction that cannot see people, nor
	# the seat they sit on, so the core refuses what the client predicted.
	nav._seat_cells.clear()
	var first: int = s["sent"].size()
	var worst := {"drift": 0, "jump": 0.0}
	var last := [p.shown]
	var check := func(x):
		nav.set_held([])
		var core: Vector2i = nav.cell_of(Motion.point(p.view["pos"]))
		worst["drift"] = maxi(worst["drift"], steps_apart(p.cell, core))
		worst["jump"] = maxf(worst["jump"], p.shown.distance_to(last[0]))
		last[0] = p.shown
	for leg in 4:
		nav.set_held([])
		play(s, 1.0, (nav.centre(seated["cell"]) - nav.centre(p.cell)).normalized(), check)
	var corrected := 0
	for k in range(first, s["sent"].size()):
		assert_true(s["sent"][k].size() <= Player.STEPS_PER_TICK, "at most five cells a tick")
		if s["accepted"][k] != s["sent"][k]:
			corrected += 1
	assert_true(corrected >= 1, "the core refused steps into the seated person")
	assert_true(worst["drift"] <= Player.STEPS_PER_TICK, "never more than one tick of walking from the core: %d cells" % worst["drift"])
	# One frame of walking diagonally, plus easing a whole tick's correction.
	var tick_cm := 25.0 * sqrt(2.0) * Player.STEPS_PER_TICK
	var bound := tick_cm / FPS + tick_cm / (Player.EASE_S * FPS)
	assert_true(worst["jump"] <= bound, "it eases back, never teleports: %.1f cm in a frame" % worst["jump"])
	assert_eq(nav.cell_of(Motion.point(p.view["pos"])) , p.cell, "and ends where the core has it")


func test_off_grid_steering_draws_a_straight_walk_facing_the_steer() -> void:
	# On an open floor the grid walks a line 20° off an axis as a staircase
	# of straight and diagonal steps; the avatar is drawn along a straight
	# line facing the way it is steered, and settles onto its cell at rest.
	var nav := core_nav([{"id": "room:open", "rect": {"x": 0, "z": 0, "w": 3000, "d": 3000}}])
	var p := Player.new()
	p.nav = nav
	p.present = true
	p.cell = nav.cell_of(Vector2(400, 1500))
	p._rest_on(p.cell)
	p.predict(0.1, Vector2.ZERO, nav)
	var dir := Vector2(cos(deg_to_rad(20.0)), -sin(deg_to_rad(20.0)))
	var start := p.shown
	var worst_off := 0.0
	var worst_turn := 0.0
	var worst_jump := 0.0
	var last := p.shown
	for f in 90:
		p.predict(1.0 / 60.0, dir, nav)
		if f % 60 == 59:
			p.cells_this_tick()
		worst_off = maxf(worst_off, absf((p.shown - start).cross(dir)))
		var side := absf((p.shown - last).cross(dir))
		worst_jump = maxf(worst_jump, side)
		last = p.shown
		if p.heading != Vector2.ZERO:
			worst_turn = maxf(worst_turn, rad_to_deg(absf(p.heading.angle_to(dir))))
	assert_true((p.shown - start).dot(dir) > 150.0, "it walked on: %.0f cm" % (p.shown - start).dot(dir))
	assert_true(worst_off < 6.0, "along a straight line (worst %.1f cm off it)" % worst_off)
	assert_true(worst_jump < 1.5, "never shifting sideways by more than a hair a frame (%.1f cm)" % worst_jump)
	assert_true(worst_turn < 1.0, "facing the steer, not each step (worst %.1f°)" % worst_turn)
	for f in 40:
		p.predict(1.0 / 60.0, Vector2.ZERO, nav)
	assert_true(p.shown.distance_to(nav.centre(p.cell)) < 1.0, "at rest, on its cell")


func test_sliding_round_a_placement_never_jumps_sideways() -> void:
	# A flowerbed end-on in the way (x 620–730, z 1320–1630, where schema 1
	# had a 50 by 150 cm post) makes the walk slide round it and start a new
	# line; the drawn avatar glides across, never jumping. (A kind with no
	# anchors: this room has no way in, so an anchor in it is unreachable.)
	var nav := core_nav([{"id": "room:open", "rect": {"x": 0, "z": 0, "w": 3000, "d": 3000}}],
		[{"id": "placement:bed", "kind": "flowerbed", "at": {"x": 675, "z": 1475}, "facing": 90}])
	var p := Player.new()
	p.nav = nav
	p.present = true
	p._rest_on(nav.cell_of(Vector2(400, 1490)))
	p.predict(0.1, Vector2.ZERO, nav)
	var dir := Vector2(cos(deg_to_rad(8.0)), -sin(deg_to_rad(8.0)))
	var last := p.shown
	var worst_jump := 0.0
	for f in 300:
		p.predict(1.0 / 60.0, dir, nav)
		if f % 60 == 59:
			p.cells_this_tick()
		worst_jump = maxf(worst_jump, last.distance_to(p.shown))
		last = p.shown
	assert_true(p.shown.x > 850.0, "it got round the post: %s" % p.shown)
	assert_true(worst_jump < 4.0, "no frame moves it more than walking and a glide would (%.1f cm)" % worst_jump)


## A full room is closed to steering past its door span, as the core says:
## the prediction never walks into a full open-ground room along its edge
## (only to be pulled back every tick).
func test_steering_stops_at_the_edge_of_a_full_open_room() -> void:
	var s := joined("registered")
	var p: Player = s["player"]
	var nav: NavQuery = s["nav"]
	var proj: Dictionary = JSON.parse_string(s["world"].project_json(p.id))
	var full := {"id": "crowd:9999", "kind": {"type": "SimCitizen"}, "display_name": "Someone", "role": "",
		"badge": "Simulation", "appearance": {}, "seat": null, "presence": {"headline": "Present"},
		"pos": {"x": 1500, "z": 1825}}
	var found := false
	for room in proj["rooms"]:
		if room["id"] == "room:tram-street":
			room["capacity"] = 1
			room["occupants"] = [full]
			found = true
	assert_true(found, "the projection lists the tram street")
	p.observe(proj, nav)
	for f in int(3.0 * FPS):
		p.predict(1.0 / FPS, Vector2(0, 1), nav)
		if f % int(FPS) == int(FPS) - 1:
			p.cells_this_tick()
		assert_true(nav.room_at(p.cell) != "room:tram-street", "frame %d: not into the full tram street" % f)
	assert_eq(nav.room_at(p.cell + Vector2i(0, 1)), "room:tram-street", "it stopped at its edge")
	assert_eq(p.turned_away, "room:tram-street", "and says the tram street is full, as the core would")


## A room that is full, or queued for by others, is closed at its door: in
## the district at the tick the workshop is at capacity with others queued,
## steering in from the plaza stops on the threshold, the plaza's side of
## the door span. The core refuses the step onto the workshop's span
## (`RoomFull`), so the prediction never takes it, and nothing admits,
## queues or overflows the player: a steered entry tries only that room.
func test_steering_into_a_full_room_s_door_stops_at_the_threshold() -> void:
	var s := joined("registered")
	var w = s["world"]
	var p: Player = s["player"]
	var nav: NavQuery = s["nav"]
	# A step outside the workshop's plaza door, in its east wall, level
	# with the door's southern half (the queue forms from its north end).
	p.go_point(Vector2(-1738, -563))
	var own := {}
	for i in 200:
		w.step()
		own = JSON.parse_string(w.project_json(p.id))
		p.observe(own, nav)
		if w.tick() > 60 and not p.view.get("moving", false) and nav.is_closed("room:workshop"):
			break
	assert_true(nav.is_closed("room:workshop"), "the workshop is full or queued for by tick %d" % w.tick())
	assert_true(not p.view.get("moving", false), "standing by its door")
	var start := p.cell
	var span_row := false
	for di in range(1, 5):
		var c := start + Vector2i(-di, 0)
		if nav.room_at(c) == "room:workshop":
			span_row = nav.in_door_span(c)
			break
	assert_true(span_row, "west of it lies the workshop's door span: %s" % start)
	w.take_player_events()
	var events := []
	play(s, 3.0, Vector2(-1, 0), func(s_):
		assert_true(nav.room_at(p.cell) != "room:workshop", "the prediction stays out: %s" % p.cell)
		var taken = JSON.parse_string(w.take_player_events())
		if taken is Array:
			events.append_array(taken))
	var at := nav.cell_of(Motion.point(p.view["pos"]))
	assert_eq(nav.room_at(at), "room:plaza", "the core has it on the plaza")
	assert_true(nav.in_door_span(at), "at the threshold, on the door span: %s" % at)
	assert_eq(nav.room_at(at + Vector2i(-1, 0)), "room:workshop", "the workshop's span beyond it")
	assert_eq(p.cell, at, "and the prediction agrees")
	assert_eq(p.turned_away, "room:workshop", "turned away at the workshop's door, as the core would")
	var kinds := events.map(func(e): return str(e["kind"]["type"]))
	for kind in ["Rejected", "Waitlisted", "Overflowed", "Admitted"]:
		assert_true(not kind in kinds, "no %s: %s" % [kind, kinds])


# ---- Doors ----

## A hall and a lobby, each 6 by 12 m, sharing a wall with no shell in
## it, and a metre-wide door in its middle at (600, 600): the hall lies on
## the `inward` side of the wall. Walking in is walking along `inward`.
func door_nav(inward: Vector2i) -> NavQuery:
	var halves := [{"x": 0, "z": 0, "w": 600, "d": 1200}, {"x": 600, "z": 0, "w": 600, "d": 1200}] if inward.x != 0 \
		else [{"x": 0, "z": 0, "w": 1200, "d": 600}, {"x": 0, "z": 600, "w": 1200, "d": 600}]
	var hall: Dictionary = halves[1] if inward.x + inward.y > 0 else halves[0]
	var lobby: Dictionary = halves[0] if inward.x + inward.y > 0 else halves[1]
	return core_nav([
		{"id": "room:hall", "rect": hall, "doors": [{"id": "door:hall-lobby", "to": "room:lobby", "pos": {"x": 600, "z": 600}}]},
		{"id": "room:lobby", "rect": lobby, "doors": []},
	])


## The cells a steered walk from `start` along `dir` predicts, frame by
## frame, until it is on the hall's floor past the door span, stops, or
## has taken `most` steps.
func steered_walk(nav: NavQuery, start: Vector2, dir: Vector2, most := 60) -> Array:
	var p := Player.new()
	p.nav = nav
	p.reconcile(nav.centre(nav.cell_of(start)))
	var cells := [p.cell]
	while cells.size() <= most:
		p.predict(1.0 / Player.STEPS_PER_TICK, dir, nav)
		var stepped := p.cells_this_tick()
		if stepped.is_empty():
			break
		for c in stepped:
			assert_true(nav.can_step(cells[-1], c), "every step is one the core allows: %s to %s" % [cells[-1], c])
			cells.append(c)
			if inside_hall(nav, c):
				return cells
	return cells


func inside_hall(nav: NavQuery, c: Vector2i) -> bool:
	return nav.room_at(c) == "room:hall" and not nav.in_door_span(c)


## Walking into a door at an angle goes in. A step between rooms must be
## straight across the door span, never diagonal, so the walk's preferred
## diagonal is refused at the threshold; the step through the door goes
## before a slide along the wall, whichever way the door faces.
func test_at_every_door_orientation_the_45_50_and_60_degree_approaches_get_in() -> void:
	for inward in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nav := door_nav(inward)
		for ang in [-60, -50, -45, 45, 50, 60]:
			var dir := Vector2(inward).rotated(deg_to_rad(ang))
			var cells := steered_walk(nav, Vector2(600, 600) - dir * 250.0, dir)
			var threshold := cells.filter(func(c): return nav.room_at(c) == "room:lobby" and nav.in_door_span(c)).size()
			assert_true(inside_hall(nav, cells[-1]), "facing %s, %+d°: in the hall, not at %s" % [inward, ang, cells[-1]])
			assert_true(threshold <= 2, "facing %s, %+d°: through the door, not along its threshold (%d span cells)" % [inward, ang, threshold])


## Walking at an angle into the door of a room that is closed (full, or
## queued for), the walk's diagonal is refused by the grid and the step
## onto the span by the closed room: it stays out, and says why rather
## than sliding silently along the threshold.
func test_an_angled_walk_into_a_closed_room_s_door_says_it_is_full() -> void:
	for inward in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nav := door_nav(inward)
		nav.set_closed(["room:hall"])
		for ang in [-50, -45, 45, 50]:
			var dir := Vector2(inward).rotated(deg_to_rad(ang))
			var p := Player.new()
			p.nav = nav
			p.reconcile(nav.centre(nav.cell_of(Vector2(600, 600) - dir * 250.0)))
			var told := false
			for f in 40:
				p.predict(1.0 / Player.STEPS_PER_TICK, dir, nav)
				p.cells_this_tick()
				told = told or p.turned_away == "room:hall"
				assert_true(nav.room_at(p.cell) != "room:hall", "facing %s, %+d°: kept out of the hall" % [inward, ang])
			assert_true(told, "facing %s, %+d°: told the hall is full" % [inward, ang])


## Walking along a façade past a door, one or two cells out from the
## wall, keeps to the lobby: a door ranks before a slide only for a walk
## that heads through it, never for one going past. With `held`, someone
## stands on the walk's line level with the doorway, so the walk slides
## round them there, and still not in.
func walk_past_door(nav: NavQuery, inward: Vector2i, out_cells: int, along_sign: int, held: bool) -> void:
	var wall := Vector2(600, 600)
	var into := Vector2(inward)
	var along := Vector2(-into.y, into.x) * along_sign
	var line := wall - into * (NavQuery.CELL * out_cells - NavQuery.CELL * 0.5)
	nav.set_held([nav.cell_of(line)] if held else [])
	var p := Player.new()
	p.nav = nav
	p.reconcile(nav.centre(nav.cell_of(line - along * 300.0)))
	var label := "facing %s, %d out, along %s%s" % [inward, out_cells, along, ", held" if held else ""]
	for f in 60:
		p.predict(1.0 / Player.STEPS_PER_TICK, along, nav)
		p.cells_this_tick()
		assert_eq(nav.room_at(p.cell), "room:lobby", "%s: in the lobby at %s" % [label, p.cell])
		assert_eq(p.turned_away, "", "%s: nothing turned it away" % label)
	assert_true((nav.centre(p.cell) - wall).dot(along) > 150.0, "%s: it walked on past the door to %s" % [label, p.cell])


func test_walking_along_a_facade_past_a_door_never_goes_in() -> void:
	for inward in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		for out_cells in [1, 2]:
			for along_sign in [-1, 1]:
				walk_past_door(door_nav(inward), inward, out_cells, along_sign, false)


func test_sliding_round_someone_level_with_a_doorway_never_goes_in() -> void:
	for inward in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		for out_cells in [1, 2]:
			for along_sign in [-1, 1]:
				walk_past_door(door_nav(inward), inward, out_cells, along_sign, true)


## Pushed straight into the wall with the doorway one cell to the side,
## the walk steps across to it and goes in, as the jamb would guide a body
## that wide; two cells off, it stays against the wall.
func test_a_walk_pushed_into_the_wall_beside_a_doorway_is_guided_in() -> void:
	for inward in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nav := door_nav(inward)
		var dir := Vector2(inward)
		var along := Vector2(-dir.y, dir.x)
		for off in [-62.0, 62.0]:
			var cells := steered_walk(nav, Vector2(600, 600) - dir * 250.0 + along * off, dir)
			assert_true(inside_hall(nav, cells[-1]), "facing %s, %+d cm off: in the hall, not at %s" % [inward, int(off), cells[-1]])
		for off in [-87.0, 87.0]:
			var cells := steered_walk(nav, Vector2(600, 600) - dir * 250.0 + along * off, dir)
			assert_eq(nav.room_at(cells[-1]), "room:lobby", "facing %s, %+d cm off: it stays in the lobby" % [inward, int(off)])
			assert_true(not nav.can_step(cells[-1], cells[-1] + inward), "against the wall")


## In the district, a steered walk at 45° into the workshop's plaza door
## (pixel art's W) goes straight through it: the core accepts every
## predicted cell and admits the player, which never walked along the
## threshold.
func test_a_steered_walk_at_45_degrees_goes_through_the_workshop_door() -> void:
	var s := joined("registered")
	var w = s["world"]
	var p: Player = s["player"]
	var nav: NavQuery = s["nav"]
	var door := Vector2(-1800, -600)
	var dir := Vector2(-1, 0).rotated(deg_to_rad(45.0))
	p.go_point(door - dir * 300.0)
	for i in 80:
		w.step()
		p.observe(JSON.parse_string(w.project_json(p.id)), nav)
		if not p.view.get("moving", false) and not p.following:
			break
	assert_true(not nav.is_closed("room:workshop"), "the workshop is open at tick %d" % w.tick())
	var first: int = s["sent"].size()
	var cells := []
	play(s, 5.0, dir, func(x): if cells.is_empty() or cells[-1] != p.cell: cells.append(p.cell))
	for k in range(first, s["sent"].size()):
		assert_eq(s["accepted"][k], s["sent"][k], "tick %d: the core accepts every predicted cell" % k)
	var own: Dictionary = JSON.parse_string(w.project_json(p.id))
	var admitted := false
	for room in own["rooms"]:
		if room["id"] == "room:workshop":
			admitted = room["occupants"].any(func(v): return v["id"] == p.id)
	assert_true(admitted, "the core admitted it to the workshop: %s" % str(cells))
	var threshold := cells.filter(func(c): return nav.room_at(c) == "room:plaza" and nav.in_door_span(c)).size()
	assert_true(threshold <= 2, "it went through the door, not along its threshold: %s" % str(cells))
