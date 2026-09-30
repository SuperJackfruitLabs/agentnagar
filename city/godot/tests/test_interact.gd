## The one interaction path (interactions spec section 2): targeting in
## each view (first person within 3 m, overhead and pixel art within 1.5 m
## and 60° of facing, touch), the verbs and their order with Inspect last,
## cycling them with E or Y, Go-then-Use out of reach, and the overlay for
## Inspect and Read.
extends TestSuite

const NOTICEBOARD := "placement:square-noticeboard"
const FOUNTAIN := "placement:square-fountain"


func booted(args: Array):
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(args))
	assert_true(not main.hud.error_label.visible, "booted: " + main.hud.error_label.text)
	return main


## Steps until the player stands still in the city and no tram is by the
## Square (see test_first_person.gd).
func arrive(main) -> void:
	for i in 80:
		main.driver.step_once()
		if main.player.present and not main.player.view.get("moving", false):
			break
	for i in 40:
		if not tram_by_the_square(main.driver.world):
			break
		main.driver.step_once()
	assert_true(main.player.present, "arrived")


func frames(main, seconds: float) -> void:
	for f in int(round(seconds * 60.0)):
		main._process(1.0 / 60.0)
		main.driver.advance(1.0 / 60.0)


## One tick, and a few frames drawn of it.
func tick(main) -> void:
	main.driver.step_once()
	frames(main, 0.05)


## Walks the player (Go) to `pos` (cm) and waits for it to stand there.
func walk_to(main, pos: Vector2) -> void:
	main.player.go_point(pos)
	for i in 80:
		tick(main)
		if not main.player.view.get("moving", false) and not main.player.following:
			break


func key(code: int, pressed := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e


func pad(button: int, pressed := true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


func thing(main, id: String) -> Dictionary:
	for t in main.interact.things:
		if t["target"] == id:
			return t
	return {}


func prompt(main) -> String:
	return main.hud.prompt_label.text if main.hud.prompt.visible else ""


## Passes a world's calls through, noting each command sent.
class Recorder:
	var world
	var sent: Array

	func _init(world_, sent_: Array) -> void:
		world = world_
		sent = sent_

	func command(json: String) -> String:
		sent.append(JSON.parse_string(json))
		return world.command(json)

	func leave() -> String:
		return world.leave()


# ---- Verbs ----

func test_verbs_follow_the_catalogue_with_inspect_last() -> void:
	var main = booted(["--crowd=0", "--as=none"])
	var it: Interact = main.interact
	var cases := [[NOTICEBOARD, ["Read", "Inspect"]], ["placement:library-kiosk", ["Browse", "Inspect"]],
		["placement:guild-hall-plaque", ["Read", "Inspect"]], ["placement:reading-shelf-1", ["Read", "Inspect"]],
		[FOUNTAIN, ["Sit", "Inspect"]], ["placement:library-steps", ["Sit", "Inspect"]],
		["placement:park-wall-1", ["Sit", "Inspect"]], ["placement:park-meadow-1", ["Inspect"]], ["seat:p1", ["Sit", "Inspect"]]]
	for c in cases:
		var t := thing(main, c[0])
		assert_true(not t.is_empty(), c[0] + " is something to act on")
		if not t.is_empty():
			assert_eq(it.verbs(it.candidate_of(t, t["anchors"][0]["index"] if not t["anchors"].is_empty() else -1)), c[1], c[0])
	assert_eq(it.verbs({"type": "ground", "target": "", "kind": "ground", "anchor": -1, "capabilities": [], "pos": Vector2.ZERO}),
		["Walk here"], "the ground")
	assert_eq(it.verbs({"type": "building", "target": "room:workshop", "kind": "guild-hall", "anchor": 0,
		"capabilities": ["enter", "inspect"], "pos": Vector2.ZERO}), ["Go in", "Inspect"], "a building")
	assert_eq(it.verbs(it.in_use({"target": "seat:p1", "capability": "sit", "anchor": 0})), ["Stand up", "Inspect"], "seated")
	assert_eq(it.verbs(it.in_use({"target": NOTICEBOARD, "capability": "read", "anchor": 0})), ["Stop reading", "Read", "Inspect"],
		"reading: stop, open again, inspect")
	# Someone else on a seat: only inspecting is left. A taken place on a
	# rim offers its free neighbour (see test_a_held_anchor_is_skipped_for_a_free_one).
	it.taken = {"seat:p1": true, FOUNTAIN + "#2": true}
	assert_eq(it.verbs(it.candidate_of(thing(main, "seat:p1"), 0)), ["Inspect"], "a taken seat")
	assert_eq(it.verbs(it.candidate_of(thing(main, FOUNTAIN), 2)), ["Sit", "Inspect"], "a taken place on the rim: a free one near")
	assert_eq(it.verbs(it.candidate_of(thing(main, FOUNTAIN), 3)), ["Sit", "Inspect"], "its free neighbour")
	main.free()


func test_cycling_shows_each_verb_in_turn_and_a_new_target_starts_again() -> void:
	var main = booted(["--crowd=0", "--as=none"])
	var it: Interact = main.interact
	var board := it.candidate_of(thing(main, NOTICEBOARD), 0)
	var names := it.verbs(board)
	assert_eq(names[it.shown_verb(board)], "Read", "first, Read")
	it.cycle()
	assert_eq(names[it.shown_verb(board)], "Inspect", "then Inspect")
	it.cycle()
	assert_eq(names[it.shown_verb(board)], "Read", "and round again")
	it.cycle()
	var bench := it.candidate_of(thing(main, "seat:p1"), 0)
	assert_eq(it.verbs(bench)[it.shown_verb(bench)], "Sit", "a new target starts at its first verb")
	main.free()


func test_e_and_y_cycle_and_have_a_glyph() -> void:
	var r := InputRouter.new()
	var log := []
	r.interact_alt.connect(func(): log.append("alt"))
	for e in [key(KEY_E), key(KEY_E, false), pad(JOY_BUTTON_Y), pad(JOY_BUTTON_Y, false)]:
		r.handle(e)
	assert_eq(log, ["alt", "alt"], "E and Y cycle")
	var g := InputGlyphs.new()
	assert_eq(g.label("interact_alt"), "E", "the keyboard's key")
	g.note(pad(JOY_BUTTON_A))
	assert_eq(g.label("interact_alt"), "Y", "the controller's button")
	assert_true(g.icon("interact_alt") != null, "with its glyph")
	r.free()


# ---- Targeting ----

func test_overhead_targets_the_nearest_anchor_within_1_5_m_ahead() -> void:
	var main = booted(["--crowd=0", "--as=none"])
	var it: Interact = main.interact
	var rim := thing(main, FOUNTAIN)
	# The rim's west place, (-180, 0) from the fountain, where a sitter faces west.
	var west: Dictionary = rim["anchors"].filter(func(a): return a["facing"] == 270)[0]
	var at: Vector2 = west["pos"] + Vector2(-120, 0)
	var ahead := it.targets({"view": "overhead", "at": at, "facing": Vector2.RIGHT})
	assert_true(not ahead.is_empty() and ahead[0]["target"] == FOUNTAIN, "facing it 1.2 m off: the rim: %s" % [ahead.map(func(c): return c["target"])])
	if not ahead.is_empty():
		assert_eq(ahead[0]["anchor"], west["index"], "at its nearest place")
		assert_eq(ahead[0]["pos"], west["pos"], "the reticle's point is that place")
	assert_true(not it.targets({"view": "overhead", "at": at, "facing": Vector2.LEFT}).any(func(c): return c["target"] == FOUNTAIN),
		"facing away: not the rim")
	# 70° off facing is outside 60°.
	var off := Vector2.RIGHT.rotated(deg_to_rad(70.0))
	assert_true(not it.targets({"view": "overhead", "at": at, "facing": off}).any(func(c): return c["target"] == FOUNTAIN),
		"70° off: not the rim")
	var far: Vector2 = west["pos"] + Vector2(-160, 0)
	assert_true(not it.targets({"view": "overhead", "at": far, "facing": Vector2.RIGHT}).any(func(c): return c["target"] == FOUNTAIN),
		"1.6 m off: out of reach")
	main.free()


## Standing on an anchor's own cell counts as ahead whichever way one
## faces (for a perch as for a workstation's stand anchor): on the rim's
## west place, facing away from the fountain, the rim is still the target,
## at that place. Off that cell the 1.5 m and 60° rule is unchanged: one
## cell further west, facing away, the rim is not offered; facing it, it
## is, at its nearest place.
func test_standing_on_an_anchors_cell_targets_it_facing_any_way() -> void:
	var main = booted(["--crowd=0", "--as=none"])
	var it: Interact = main.interact
	var rim := thing(main, FOUNTAIN)
	var west: Dictionary = rim["anchors"].filter(func(a): return a["facing"] == 270)[0]
	var cell: Vector2i = main.nav.cell_of(west["pos"])
	var on: Vector2 = main.nav.centre(cell)
	assert_true(on.distance_to(west["pos"]) >= 1.0, "the place lies off its cell's centre: %s" % on.distance_to(west["pos"]))
	for facing in [Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2.RIGHT]:
		var ahead := it.targets({"view": "overhead", "at": on, "facing": facing})
		assert_true(not ahead.is_empty() and ahead[0]["target"] == FOUNTAIN, "on the place facing %s: the rim: %s" % [facing, ahead.map(func(c): return c["target"])])
		if not ahead.is_empty() and ahead[0]["target"] == FOUNTAIN:
			assert_eq(ahead[0]["anchor"], west["index"], "facing %s: at the place stood on" % facing)
			assert_eq(it.verbs(ahead[0]), ["Sit", "Inspect"], "facing %s: sit there" % facing)
	var beside: Vector2 = main.nav.centre(cell + Vector2i(-1, 0))
	assert_true(not it.targets({"view": "overhead", "at": beside, "facing": Vector2.LEFT}).any(func(c): return c["target"] == FOUNTAIN),
		"a cell off it, facing away: not the rim")
	var facing_it := it.targets({"view": "overhead", "at": beside, "facing": Vector2.RIGHT})
	assert_true(not facing_it.is_empty() and facing_it[0]["target"] == FOUNTAIN and facing_it[0]["anchor"] == west["index"],
		"a cell off it, facing it: the rim at its nearest place")
	main.free()


## Review Focus 3: in the crowded plaza, with several anchors in reach,
## the prompt names the target the reticle marks, and cycling moves only
## through that target's verbs, never to an anchor out of reach.
func test_in_a_crowded_plaza_the_prompt_names_the_marked_target_and_cycling_stays_in_reach() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	var it: Interact = main.interact
	var nav: NavQuery = main.nav
	# The walkable plaza cell and facing with the most anchors in reach (an
	# anchorless thing, a tree or a lamp, counts as one): by the fountain's
	# rim, between two of its places.
	var best := {"n": 0}
	for j in nav.rows:
		for i in nav.cols:
			var c := Vector2i(i, j)
			if nav.room_at(c) != "room:plaza" or not nav.walkable(c) or nav.is_seat_cell(c):
				continue
			for k in 8:
				var facing := Vector2.UP.rotated(deg_to_rad(45.0 * k))
				var n := 0
				for t in it.targets({"view": "overhead", "at": nav.centre(c), "facing": facing}):
					n += maxi(1, in_reach(t["thing"], nav.centre(c), facing).size())
				if n > best["n"]:
					best = {"n": n, "cell": c, "facing": facing}
	assert_true(best["n"] >= 2, "a spot with %d anchors in reach" % best["n"])
	var at: Vector2 = nav.centre(best["cell"])
	var list := it.targets({"view": "overhead", "at": at, "facing": best["facing"]})
	for c in list:
		assert_true(c["pos"].distance_to(at) <= Interact.OVERHEAD_REACH_M * 100.0 + 0.5 or c["anchor"] < 0, "%s within reach" % c["target"])
	# In the client: stand there, face that way, and the prompt and reticle agree.
	walk_to(main, at)
	assert_eq(main.player.cell, best["cell"], "standing there")
	main.player.view["facing"] = roundi(rad_to_deg(atan2(best["facing"].x, -best["facing"].y)))
	frames(main, 0.05)
	var now: Dictionary = main.interaction.choice()
	assert_true(now.has("target"), "a target: " + str(now))
	var target: Dictionary = now["target"]
	assert_eq(target["target"], list[0]["target"], "the first in reach")
	var anchors := in_reach(target["thing"], at, best["facing"])
	if not anchors.is_empty():
		var nearest: Dictionary = anchors[0]
		for a in anchors:
			if a["pos"].distance_to(at) < nearest["pos"].distance_to(at):
				nearest = a
		assert_eq(target["anchor"], nearest["index"], "its nearest anchor of the %d in reach" % anchors.size())
	assert_true(main.host.pack.reticle.visible, "marked")
	assert_true(main.host.pack.reticle_ground_pos().distance_to(target["pos"]) < 1.0, "the reticle on the target the prompt names")
	var seen := {}
	for n in 4:
		now = main.interaction.choice()
		assert_eq([now["target"]["target"], now["target"]["anchor"]], [target["target"], target["anchor"]], "cycling keeps the target and its anchor")
		assert_true(now["text"] in main.interact.verbs(target), "a verb of that target: " + now["text"])
		seen[now["text"]] = true
		assert_eq(prompt(main), now["text"], "the prompt says it")
		main.router.handle(key(KEY_E))
		main.router.handle(key(KEY_E, false))
		frames(main, 1.0 / 60.0)
	assert_eq(seen.size(), main.interact.verbs(target).size(), "every verb shown in turn: " + str(seen.keys()))
	main.free()


## A crowd of things packed closer than the district's: a noticeboard,
## steps, a low wall, a bench seat and a street tree within a few metres.
## From every cell round them and every facing, each target offered is in
## reach and ahead, offered once, and the first is one the player can use
## whenever any is; its verbs are its own.
func test_among_many_anchors_only_those_in_reach_are_offered() -> void:
	var layout := {"city": {"districts": [{"id": "district:test", "facilities": [{"id": "facility:yard", "rooms": [
		{"id": "room:yard", "rect": {"x": -600, "z": -600, "w": 1200, "d": 1200},
			"seats": [{"id": "seat:b", "kind": "bench", "pos": {"x": -100, "z": -80}, "facing": 0}]}]}],
		"placements": [
			{"id": "placement:board", "kind": "noticeboard", "at": {"x": 0, "z": -120}},
			{"id": "placement:steps", "kind": "steps", "at": {"x": -200, "z": 0}, "facing": 90},
			{"id": "placement:wall", "kind": "low-wall", "at": {"x": 150, "z": 0}, "facing": 270},
			{"id": "placement:tree", "kind": "street-tree", "at": {"x": 100, "z": -100}}]}]}}
	var it := Interact.from_layout(layout, StylePack.kinds(), null)
	assert_eq(it.things.size(), 5, "five things")
	var reach := Interact.OVERHEAD_REACH_M * 100.0
	var crowded := 0
	for z in range(-400, 425, 25):
		for x in range(-400, 425, 25):
			var at := Vector2(x, z)
			for k in 8:
				var facing := Vector2.UP.rotated(deg_to_rad(45.0 * k))
				var list := it.targets({"view": "overhead", "at": at, "facing": facing})
				var ids := list.map(func(c): return c["target"])
				if list.size() >= 3:
					crowded += 1
				for id in ids:
					assert_eq(ids.count(id), 1, "offered once")
				for c in list:
					var spot: Vector2 = c["pos"]
					if c["anchor"] < 0:
						var r: Rect2 = c["thing"]["boxes"][0]["rect"]
						spot = (at / 100.0).clamp(r.position, r.end) * 100.0
					var to := spot - at
					assert_true(to.length() <= reach + 0.5 and (to.length() < 1.0 or rad_to_deg(absf(facing.angle_to(to))) <= Interact.OVERHEAD_HALF_ANGLE + 0.01),
						"%s offered from %s facing %s is in reach and ahead" % [c["target"], at, facing])
					assert_true(it.verbs(c).all(func(v): return v in ["Sit", "Read", "Inspect"]), "its own verbs")
				if list.any(Interact.usable):
					assert_true(Interact.usable(list[0]), "one to use first, at %s" % at)
	assert_true(crowded > 20, "often three or more at once (%d)" % crowded)


## The anchors of `thing` within overhead reach of `at` (cm), ahead of
## `facing`.
func in_reach(thing: Dictionary, at: Vector2, facing: Vector2) -> Array:
	return thing["anchors"].filter(func(a):
		var to: Vector2 = a["pos"] - at
		return to.length() <= Interact.OVERHEAD_REACH_M * 100.0 and (to.length() < 1.0 or rad_to_deg(absf(facing.angle_to(to))) <= Interact.OVERHEAD_HALF_ANGLE + 0.01))


func test_first_person_targets_what_the_crosshair_rests_on_within_3_m() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	var board := thing(main, NOTICEBOARD)
	var stand: Dictionary = board["anchors"].filter(func(a): return a["type"] == "stand")[0]
	var display: Dictionary = board["anchors"].filter(func(a): return a["type"] == "display")[0]
	for case in [[stand["pos"] + Vector2(0, -100), true], [stand["pos"] + Vector2(0, -400), false]]:
		walk_to(main, case[0])
		main._toggle_fpv()
		var cam: FpvCamera = main.host.pack.fpv
		var eye := Vector2(cam.position.x, cam.position.z)
		var to: Vector2 = display["pos"] / 100.0 - eye
		cam.yaw = FpvCamera.yaw_along(to)
		cam.pitch = -rad_to_deg(atan2(FpvCamera.EYE_HEIGHT - 1.3, to.length()))
		cam.look(0, 0)
		frames(main, 1.0 / 60.0)
		var hit: Dictionary = main.interaction.fpv_target()
		if case[1]:
			assert_eq(hit.get("target"), NOTICEBOARD, "%.1f m away: the noticeboard: %s" % [to.length(), hit.get("target")])
			assert_eq(prompt(main), "Read", "Read")
			assert_true(main.hud.prompt_more.visible, "and the hint that E shows more")
		else:
			assert_true(hit.get("target") != NOTICEBOARD, "%.1f m away: out of reach: %s" % [to.length(), hit.get("target")])
		main._toggle_fpv()
	main.free()


func test_pixel_art_marks_the_seat_ahead_and_offers_it() -> void:
	var main = booted(["--crowd=0", "--style=pixel_art"])
	arrive(main)
	var seat: Dictionary = main.nav.seats.filter(func(s): return s["id"] == "seat:p6")[0]
	walk_to(main, seat["pos"] + Vector2(0, 90))
	main.player.view["facing"] = 0
	frames(main, 0.05)
	var now: Dictionary = main.interaction.choice()
	assert_eq(now.get("target", {}).get("target"), "seat:p6", "the bench ahead: " + str(now.get("target", {}).get("target")))
	assert_eq(prompt(main), "Sit", "Sit")
	assert_true(main.host.pack.reticle.visible and main.host.pack.reticle_ground_pos().distance_to(seat["pos"]) < 1.0, "the reticle on it")
	main.free()


func test_a_tap_targets_a_placement_or_seat_and_open_ground_walks() -> void:
	var main = booted(["--crowd=0", "--as=none"])
	var it: Interact = main.interact
	var rim := thing(main, FOUNTAIN)
	var place: Dictionary = rim["anchors"][3]
	var tapped := it.targets({"view": "touch", "tap": place["pos"] + Vector2(20, 0)})
	assert_true(tapped.size() == 1 and tapped[0]["target"] == FOUNTAIN and tapped[0]["anchor"] == place["index"], "a place on the rim")
	tapped = it.targets({"view": "touch", "tap": Vector2(1000, -500)})
	assert_true(tapped.size() == 1 and tapped[0]["target"] == FOUNTAIN, "the fountain itself")
	tapped = it.targets({"view": "touch", "tap": main.nav.seats[0]["pos"]})
	assert_true(tapped.size() == 1 and tapped[0]["target"] == main.nav.seats[0]["id"], "a seat")
	var meadow := thing(main, "placement:park-meadow-1")
	assert_eq(it.targets({"view": "touch", "tap": meadow["pos"]}), [], "a meadow is walked through, not tapped")
	main.free()


# ---- Acting ----

## Out of reach, A walks to the anchor and uses it on arrival; there, A
## uses it at once; Stand up ends it.
func test_sitting_on_the_fountain_walks_there_then_sits() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	var rim := thing(main, FOUNTAIN)
	var west: Dictionary = rim["anchors"].filter(func(a): return a["facing"] == 270)[0]
	walk_to(main, west["pos"] + Vector2(-300, 0))
	var sent := []
	main.player.world = Recorder.new(main.player.world, sent)
	main.interaction._act(main.interact.candidate_of(rim, west["index"]), 0)
	assert_eq(sent.size(), 1, "one command now")
	assert_eq(sent[0]["type"], "Go", "a Go to the rim")
	assert_eq(main.nav.cell_of(Motion.point(sent[0]["to"]["pos"])), main.nav.cell_of(west["pos"]), "to its place")
	for i in 40:
		tick(main)
		if main.player.view.get("using") != null:
			break
	assert_eq(sent.map(func(c): return c["type"]), ["Go", "Use"], "then the Use, on arrival")
	assert_eq([sent[-1]["target"], sent[-1]["capability"], int(sent[-1]["anchor"])], [FOUNTAIN, "sit", west["index"]], "sitting there")
	var using = main.player.view.get("using")
	assert_true(using is Dictionary and [using["target"], using["capability"], int(using["anchor"])] == [FOUNTAIN, "sit", west["index"]],
		"the core has it sitting: %s" % using)
	frames(main, 0.1)
	assert_eq(prompt(main), "Stand up", "the prompt: Stand up")
	assert_eq(main.player.status(), "sitting", "sitting")
	assert_eq(main.model.occupants[main.player.id]["pose"], "sitting", "drawn sitting")
	main._interact()
	tick(main)
	assert_eq(sent[-1]["type"], "StopUsing", "A stands up")
	assert_true(main.player.view.get("using") == null, "no longer sitting")
	# On the place already: A sits at once, with no walk.
	sent.clear()
	frames(main, 0.1)
	main.interaction._act(main.interact.candidate_of(rim, west["index"]), 0)
	assert_eq(sent.map(func(c): return c["type"]), ["Use"], "at the anchor: the Use alone")
	main.free()


## A room seat is sat on through Use too: a Go to the seat, then Use sit.
func test_a_room_seat_is_sat_on_through_use() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	var seat: Dictionary = main.nav.seats.filter(func(s): return s["id"] == "seat:p6")[0]
	walk_to(main, seat["pos"] + Vector2(0, 90))
	main.player.view["facing"] = 0
	frames(main, 0.05)
	assert_eq(prompt(main), "Sit", "Sit, at the bench ahead")
	var sent := []
	main.player.world = Recorder.new(main.player.world, sent)
	main._interact()
	for i in 20:
		tick(main)
		if main.player.view.get("using") != null and sent.size() >= 2:
			break
	assert_eq(sent.map(func(c): return c["type"]), ["Go", "Use"], "Go to the seat, then Use")
	assert_eq(sent[0]["to"], {"type": "Seat", "seat": "seat:p6"}, "the Go takes the seat's rules")
	assert_eq(main.player.view.get("seat"), "seat:p6", "seated")
	assert_eq(main.player.view.get("using", {}).get("capability"), "sit", "using it")
	main.free()


## Read at the noticeboard: a Use read and the overlay, with its sample
## content; out of reach, the walk first and the overlay on arrival.
## Inspect sends nothing and opens the overlay.
func test_reading_and_inspecting_open_the_overlay() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	var board := thing(main, NOTICEBOARD)
	var stand: Dictionary = board["anchors"].filter(func(a): return a["type"] == "stand")[0]
	walk_to(main, stand["pos"] + Vector2(0, -300))
	var sent := []
	main.player.world = Recorder.new(main.player.world, sent)
	main.interaction._act(main.interact.candidate_of(board, 0), 0)
	assert_eq(sent.map(func(c): return c["type"]), ["Go"], "out of reach: the walk first")
	assert_eq(main.stack.top(), main.hud, "no overlay yet")
	for i in 40:
		tick(main)
		if main.stack.top() is PanelScreen:
			break
	assert_eq(sent.map(func(c): return c["type"]), ["Go", "Use"], "then Use")
	assert_eq(sent[-1]["capability"], "read", "reading")
	assert_true(main.stack.top() is PanelScreen, "the overlay opens on arrival")
	if main.stack.top() is PanelScreen:
		var text: String = main.stack.top().text()
		assert_true("Sample" in text and "v0.0.3" in text and "Noticeboard" in text, "its sample notices: " + text)
		main.stack.pop()
	tick(main)
	assert_eq(main.player.view.get("using", {}).get("capability"), "read", "the core has it reading")
	frames(main, 0.05)
	assert_eq(prompt(main), "Stop reading", "the prompt: Stop reading")
	# Inspect: the overlay, and nothing sent.
	sent.clear()
	var tree: Dictionary = main.interact.things.filter(func(t): return t["kind"] == "street-tree")[0]
	main.interaction._act(main.interact.candidate_of(tree, -1), 0)
	assert_eq(sent, [], "inspecting sends nothing")
	var name := str(StylePack.kinds()["street-tree"]["name"])
	assert_true(main.stack.top() is PanelScreen and name in main.stack.top().text(), "the overlay names it")
	main.free()


# ---- Review round 1 ----

## A world that notes every command and accepts it, for driving a Player
## by hand-made projections.
class FakeWorld:
	var sent := []

	func command(json: String) -> String:
		sent.append(JSON.parse_string(json))
		return "{\"ok\": true}"

	func leave() -> String:
		return "{\"ok\": true}"


const ME := "person:you"


## Our own view on `cell` of `nav`, walking or not.
func me_on(nav: NavQuery, cell: Vector2i, moving: bool) -> Dictionary:
	var at := nav.centre(cell)
	return {"id": ME, "kind": {"type": "Human", "tier": "Registered"}, "pos": {"x": int(at.x), "z": int(at.y)},
		"moving": moving, "trail": [], "seat": null}


## A projection with `views` in the plaza.
func plaza(views: Array) -> Dictionary:
	return {"rooms": [{"id": "room:plaza", "capacity": 100, "seats": [], "occupants": views, "waiting": []}]}


## A player on the fountain's west side, 3 m off its place, with a Go
## there and the Use sit waiting: [player, world, the place's cell, the
## Use]. The Go ends wherever the test's projections put it.
func waiting_player(main) -> Array:
	var nav: NavQuery = main.nav
	var rim := thing(main, FOUNTAIN)
	var west: Dictionary = rim["anchors"].filter(func(a): return a["facing"] == 270)[0]
	var place := nav.cell_of(west["pos"])
	var world := FakeWorld.new()
	var p := Player.new()
	p.world = world
	p.id = ME
	p.observe(plaza([me_on(nav, place + Vector2i(-12, 0), false)]), nav)
	var use := {"target": FOUNTAIN, "capability": "sit", "anchor": west["index"]}
	p.go_then_use({"type": "Point", "pos": {"x": int(west["pos"].x), "z": int(west["pos"].y)}}, use,
		func(c): return main.interact.at_anchor(rim, west["index"], c))
	assert_eq(world.sent.map(func(c): return c["type"]), ["Go"], "the Go is sent")
	assert_true(p.use_waiting(), "and the Use waits")
	return [p, world, place, use]


func uses(world) -> Array:
	return world.sent.filter(func(c): return c["type"] == "Use")


## The waiting Use goes when the walk reaches the anchor, and only then:
## a walk that ends short drops it, unless the anchor is held by someone
## else, where the core's refusal says so.
func test_the_waiting_use_fires_only_at_the_anchor() -> void:
	var main = booted(["--crowd=0", "--as=none"])
	var nav: NavQuery = main.nav
	# Arriving on the place: the Use.
	var w := waiting_player(main)
	w[0].observe(plaza([me_on(nav, w[2] + Vector2i(-6, 0), true)]), nav)
	assert_eq(uses(w[1]), [], "not while walking")
	w[0].observe(plaza([me_on(nav, w[2], false)]), nav)
	assert_eq(uses(w[1]).size(), 1, "arrived: the Use")
	# A walk that stops short, the place free: nothing.
	w = waiting_player(main)
	w[0].observe(plaza([me_on(nav, w[2] + Vector2i(-6, 0), true)]), nav)
	w[0].observe(plaza([me_on(nav, w[2] + Vector2i(-3, 0), false)]), nav)
	assert_eq(uses(w[1]), [], "stopped short: no Use")
	assert_true(not w[0].use_waiting(), "and none waits")
	# Stopped short because someone sits there: the Use goes, for the
	# core's refusal to tell the player.
	w = waiting_player(main)
	var sitter := me_on(nav, w[2], false)
	sitter["id"] = "person:someone"
	sitter["using"] = w[3]
	w[0].observe(plaza([me_on(nav, w[2] + Vector2i(-6, 0), true), sitter]), nav)
	w[0].observe(plaza([me_on(nav, w[2] + Vector2i(-1, 0), false), sitter]), nav)
	assert_eq(uses(w[1]).size(), 1, "held: the Use goes to be refused")
	assert_true(w[0].last_use_held, "known to be held")
	main.hud.dismiss_notices()
	main.player.last_use_held = true
	main.player.last_use = "sit"
	main._notice_events([{"occupant": main.player.id, "kind": {"type": "Rejected", "command": "Use", "reason": "NotAtAnchor"}}])
	assert_eq(main.hud.notices.size(), 1, "a notice")
	if main.hud.notices.size() == 1:
		assert_eq(main.hud.notices[0].get_meta("text"), main.use_notice("AnchorTaken"), "someone is already there")
	main.free()


## Every way the waiting Use is dropped: steering, cancelling, another
## Go, a refused Go, changing look (L), and leaving the ground.
func test_the_waiting_use_is_dropped_by_anything_else() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	var nav: NavQuery = main.nav
	var w := waiting_player(main)
	w[0].predict(0.1, Vector2.RIGHT, nav)
	assert_true(not w[0].use_waiting(), "steering drops it")
	w = waiting_player(main)
	w[0].cancel()
	assert_true(not w[0].use_waiting(), "cancelling drops it")
	w = waiting_player(main)
	w[0].go_point(nav.centre(w[2] + Vector2i(-20, 0)))
	assert_true(not w[0].use_waiting(), "another Go drops it")
	w = waiting_player(main)
	w[0].cycle_look()
	assert_true(not w[0].use_waiting(), "L drops it")
	w = waiting_player(main)
	w[0].observe({"aboard": [me_on(nav, w[2], false)]}, nav)
	assert_true(not w[0].use_waiting(), "leaving the ground drops it")
	# A refused Go, through the client's notices.
	w = waiting_player(main)
	main.player = w[0]
	main._notice_events([{"occupant": ME, "kind": {"type": "Rejected", "command": "Go", "reason": "Unreachable"}}])
	assert_true(not w[0].use_waiting(), "a refused Go drops it")
	for i in 3:
		w[0].observe(plaza([me_on(nav, w[2], false)]), nav)
	assert_eq(uses(w[1]), [], "and it never fires")
	main.free()


## A room seat is reached by Go {Seat} and then Use: the loser of a race
## for it has its Go refused, and is told why when a use was waiting on
## that walk; a plain Go refused so tells nothing of a use.
func test_losing_a_race_for_a_room_seat_says_why() -> void:
	var main = booted(["--crowd=0", "--as=none"])
	for reason in ["SeatTaken", "NotYourSeat"]:
		var w := waiting_player(main)
		main.player = w[0]
		main.hud.dismiss_notices()
		main._notice_events([{"occupant": ME, "kind": {"type": "Rejected", "command": "Go", "reason": reason}}])
		assert_true(not w[0].use_waiting(), "%s: the waiting use is dropped" % reason)
		assert_eq(main.hud.notices.size(), 1, "%s: a notice" % reason)
		if main.hud.notices.size() == 1:
			var want: String = main.use_notice("AnchorTaken" if reason == "SeatTaken" else "NotYourSeat")
			assert_eq(main.hud.notices[0].get_meta("text"), want, "%s: it says why" % reason)
		# A plain Go, with no use waiting: no notice of a use.
		main.hud.dismiss_notices()
		main._notice_events([{"occupant": ME, "kind": {"type": "Rejected", "command": "Go", "reason": reason}}])
		assert_eq(main.hud.notices.size(), 0, "%s: a plain Go refused tells of no use" % reason)
	main.free()


## A street tree standing alone: one with a walkable cell a metre south of
## it and nothing else within 3 m of that cell. [the tree, the cell's
## centre (cm)].
func lone_tree(main) -> Array:
	for t in main.interact.things:
		if t["kind"] != "street-tree":
			continue
		var spot: Vector2 = main.nav.centre(main.nav.cell_of(t["pos"] + Vector2(0, 100)))
		if not main.nav.walkable(main.nav.cell_of(spot)):
			continue
		var alone := true
		for other in main.interact.things:
			if other != t and (other["pos"].distance_to(spot) < 300.0 or other["anchors"].any(func(a): return a["pos"].distance_to(spot) < 300.0)):
				alone = false
				break
		if alone:
			return [t, spot]
	return []


## A tap or click on something that offers only Inspect (a tree, a lamp, a
## block's lot) walks there, as on open ground: a click to walk past a
## tree must walk. Inspect stays reachable: the act button on the tree
## ahead, and E cycling to it on something usable.
func test_a_tap_on_an_inspect_only_thing_walks_and_inspect_stays_reachable() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	var lone := lone_tree(main)
	assert_true(not lone.is_empty(), "a street tree stands alone")
	if lone.is_empty():
		main.free()
		return
	var tree: Dictionary = lone[0]
	walk_to(main, lone[1] + Vector2(0, 250))
	frames(main, 0.1)
	var sent := []
	main.player.world = Recorder.new(main.player.world, sent)
	var tapped: Array = main.interact.targets({"view": "touch", "tap": tree["pos"]})
	assert_true(tapped.size() == 1 and tapped[0]["target"] == tree["target"], "the tap lands on the tree")
	main._on_walk_to(main.host.pack.screen_at(tree["pos"]))
	assert_true(not main.stack.top() is PanelScreen, "a tap on the tree opens no overlay")
	assert_eq(sent.map(func(c): return c["type"]), ["Go"], "it walks there")
	for i in 40:
		tick(main)
		if not main.player.view.get("moving", false) and not main.player.following:
			break
	# At the tree, facing it: the act button inspects it.
	walk_to(main, lone[1])
	main.player.view["facing"] = 0
	frames(main, 0.05)
	assert_eq(prompt(main), "Inspect", "the tree ahead: Inspect")
	sent.clear()
	main._interact()
	var name := str(StylePack.kinds()["street-tree"]["name"])
	assert_true(main.stack.top() is PanelScreen and name in main.stack.top().text(), "A inspects the tree")
	assert_eq(sent, [], "inspecting sends nothing")
	if main.stack.top() is PanelScreen:
		main.stack.pop()
	# On something usable, E steps round to Inspect.
	var board := thing(main, NOTICEBOARD)
	var stand: Dictionary = board["anchors"].filter(func(a): return a["type"] == "stand")[0]
	walk_to(main, stand["pos"])
	main.player.view["facing"] = posmod(int(stand["facing"]), 360)
	frames(main, 0.05)
	assert_eq(prompt(main), "Read", "at the noticeboard: Read")
	for i in 4:
		if prompt(main) == "Inspect":
			break
		main.router.handle(key(KEY_E))
		main.router.handle(key(KEY_E, false))
		frames(main, 0.05)
	assert_eq(prompt(main), "Inspect", "E steps round to Inspect")
	main._interact()
	assert_true(main.stack.top() is PanelScreen and "Noticeboard" in main.stack.top().text(), "A inspects the noticeboard")
	main.free()


## Starting to read changes the verbs: the prompt starts again at the
## first, "Stop reading", however far E had cycled.
func test_starting_to_read_shows_stop_reading_first() -> void:
	var main = booted(["--crowd=0", "--as=none"])
	var it: Interact = main.interact
	var board := it.candidate_of(thing(main, NOTICEBOARD), 0)
	it.shown_verb(board)
	it.cycle()
	it.cycle()
	assert_eq(it.verbs(board)[it.shown_verb(board)], "Read", "cycled twice: round to Read")
	var reading := it.in_use({"target": NOTICEBOARD, "capability": "read", "anchor": 0})
	assert_eq(it.verbs(reading)[it.shown_verb(reading)], "Stop reading", "reading: Stop reading first")
	main.free()


## Something beyond reach still stands in the way: the crosshair on it
## offers a walk to its nearest anchor, never the ground behind it.
func test_a_thing_out_of_reach_blocks_the_crosshair_and_offers_a_walk_to_it() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	var board := thing(main, NOTICEBOARD)
	var stand: Dictionary = board["anchors"].filter(func(a): return a["type"] == "stand")[0]
	var display: Dictionary = board["anchors"].filter(func(a): return a["type"] == "display")[0]
	walk_to(main, stand["pos"] + Vector2(0, -500))
	main._toggle_fpv()
	var cam: FpvCamera = main.host.pack.fpv
	var eye := Vector2(cam.position.x, cam.position.z)
	var to: Vector2 = display["pos"] / 100.0 - eye
	assert_true(to.length() > Interact.FIRST_PERSON_REACH_M, "beyond reach: %.1f m" % to.length())
	cam.yaw = FpvCamera.yaw_along(to)
	cam.pitch = -rad_to_deg(atan2(FpvCamera.EYE_HEIGHT - 1.3, to.length()))
	cam.look(0, 0)
	frames(main, 1.0 / 60.0)
	var hit: Dictionary = main.interaction.fpv_target()
	assert_eq(hit.get("type"), "ground", "a walk: %s" % hit.get("type"))
	var nearest: Vector2 = stand["pos"] if stand["pos"].distance_to(eye * 100.0) < display["pos"].distance_to(eye * 100.0) else display["pos"]
	assert_true(hit.get("pos", Vector2.INF).distance_to(nearest) < 1.0, "to its nearest anchor, not the ground behind: %s" % hit.get("pos"))
	assert_eq(main.interaction.choice()["text"], "Walk here", "Walk here")
	main.free()


# ---- Workstations ----

## A workstation (the workshop's desks, two in the reading room) is a room
## seat whose chair is also where its computer is used, with a place behind
## the chair to look over a shoulder: "Use computer", then "Sit", then
## Inspect; while in use, Stand up first, and the chair's other verb to
## switch without getting up; "Look at screen" only from behind the chair
## of a desk someone sits at.
func test_a_workstation_offers_use_computer_sit_and_from_behind_look_at_screen() -> void:
	var main = booted(["--crowd=0", "--as=none"])
	var it: Interact = main.interact
	var desk := thing(main, "seat:w2")
	assert_eq(desk.get("kind"), "workstation", "the workshop's desks are workstations")
	assert_eq(desk["anchors"].map(func(a): return [a["index"], a["type"]]), [[0, "sit"], [1, "use"], [3, "stand"]],
		"its chair (sit and use at one point) and the place behind it")
	var chair: Dictionary = desk["anchors"][0]
	var behind: Dictionary = desk["anchors"][2]
	assert_eq(desk["anchors"][1]["pos"], chair["pos"], "sitting and using are one place")
	assert_true(behind["pos"].distance_to(chair["pos"] + Vector2(0, 60)) < 1.0, "60 cm behind the chair: %s" % behind["pos"])
	for ws in ["seat:rw1", "seat:rw2"]:
		assert_eq(thing(main, ws).get("kind"), "workstation", ws + " in the reading room")
	it.taken = {}
	assert_eq(it.verbs(it.candidate_of(desk, 0)), ["Use computer", "Sit", "Inspect"], "a free desk")
	assert_eq(it.verbs(it.candidate_of(desk, 1)), ["Use computer", "Sit", "Inspect"], "at its use anchor too")
	assert_eq(it.verbs(it.candidate_of(desk, 3)), ["Use computer", "Sit", "Inspect"], "from behind, no one there to watch")
	# Someone sits at it (or uses it): only looking on, from behind.
	for held in [0, 1]:
		it.taken = {"seat:w2": true, "seat:w2#%d" % held: true}
		assert_eq(it.verbs(it.candidate_of(desk, 0)), ["Inspect"], "held at %d: nothing to take at the chair" % held)
		assert_eq(it.verbs(it.candidate_of(desk, 3)), ["Look at screen", "Inspect"], "held at %d: look on from behind" % held)
	# Reserved, or walked to, but no one sits there yet: nothing to watch.
	it.taken = {"seat:w2": true}
	assert_eq(it.verbs(it.candidate_of(desk, 3)), ["Inspect"], "a desk reserved but empty")
	it.taken = {}
	assert_eq(it.verbs(it.in_use({"target": "seat:w2", "capability": "use", "anchor": 1})), ["Stand up", "Sit", "Inspect"],
		"using: Stand up, or just sit")
	assert_eq(it.verbs(it.in_use({"target": "seat:w2", "capability": "sit", "anchor": 0})), ["Stand up", "Use computer", "Inspect"],
		"sitting: Stand up, or use the computer")
	# What acting does: a Go to the seat and a Use at its use anchor; the
	# switch, at once; looking on sends nothing.
	var far: Vector2i = main.nav.cell_of(chair["pos"] + Vector2(0, 300))
	var act := it.action(it.candidate_of(desk, 3), 0, far)
	assert_eq(act.get("do"), "use", "Use computer: a use")
	assert_eq(act.get("use"), {"target": "seat:w2", "capability": "use", "anchor": 1}, "at the use anchor")
	assert_eq(act.get("go"), {"type": "Seat", "seat": "seat:w2"}, "after a Go to the seat")
	act = it.action(it.candidate_of(desk, 0), 1, far)
	assert_eq(act.get("use"), {"target": "seat:w2", "capability": "sit", "anchor": 0}, "Sit: at the sit anchor")
	var seated: Vector2i = main.nav.cell_of(chair["pos"])
	act = it.action(it.in_use({"target": "seat:w2", "capability": "use", "anchor": 1}), 1, seated)
	assert_eq([act.get("do"), act.get("use"), act.get("go")], ["use", {"target": "seat:w2", "capability": "sit", "anchor": 0}, null],
		"using, Sit switches where it sits")
	assert_eq(it.action(it.in_use({"target": "seat:w2", "capability": "use", "anchor": 1}), 0, seated), {"do": "stop"}, "Stand up")
	it.taken = {"seat:w2": true, "seat:w2#0": true}
	assert_eq(it.action(it.candidate_of(desk, 3), 0, far), {"do": "watch"}, "Look at screen: the client's alone")
	main.free()


## A placed workstation (a station's own desk, bound to it) is sat at and
## used at one point, as a room seat's chair is, and the core holds the two
## anchors as one place: someone at either leaves neither to take, at the
## chair or from behind it, where "Look at screen" is offered instead of a
## Use the core would refuse. A placement whose anchors stand apart (the
## fountain's rim) still offers its free ones.
func test_a_placed_workstation_held_at_either_anchor_offers_neither_use_nor_sit() -> void:
	var main = booted(["--crowd=0", "--as=none"])
	var it: Interact = main.interact
	var desk := it._thing("placement", "placement:station-desk", StylePack.kinds()["workstation"], Vector2(3100, 300), 90)
	assert_eq(desk["anchors"].map(func(a): return a["type"]), ["sit", "use", "display", "stand"], "its anchors")
	it.taken = {}
	for anchor in [0, 1, 3]:
		assert_eq(it.verbs(it.candidate_of(desk, anchor)), ["Use computer", "Sit", "Inspect"], "free, at %d" % anchor)
	for held in [0, 1]:
		it.taken = {"placement:station-desk#%d" % held: true}
		assert_eq(it.verbs(it.candidate_of(desk, 0)), ["Inspect"], "held at %d: nothing to take at the chair" % held)
		assert_eq(it.verbs(it.candidate_of(desk, 1)), ["Inspect"], "held at %d: nor at its use anchor" % held)
		assert_eq(it.verbs(it.candidate_of(desk, 3)), ["Look at screen", "Inspect"], "held at %d: look on from behind" % held)
	it.taken = {FOUNTAIN + "#2": true}
	assert_eq(it.verbs(it.candidate_of(thing(main, FOUNTAIN), 3)), ["Sit", "Inspect"], "the fountain's free place")
	main.free()


## Ruling (final review): the anchor a use happens at skips anchors
## someone else holds, so a free place is chosen: at the fountain's rim,
## aimed at a place taken, the free one nearest it is offered and sat at.
## What is offered (candidate_of) and what acting does (action) measure
## from the same point, the place aimed at, not where the player stands,
## so the two never pick different anchors. A room seat is sat on at its
## own anchor, held or not (the seat rules decide), and a placed
## workstation held at its chair has no other chair to offer.
func test_a_held_anchor_is_skipped_for_a_free_one() -> void:
	var main = booted(["--crowd=0", "--as=none"])
	var it: Interact = main.interact
	var rim := thing(main, FOUNTAIN)
	var sits: Array = rim["anchors"].filter(func(a): return a["type"] == "sit")
	assert_true(sits.size() >= 3, "the rim has places: %d" % sits.size())
	var aimed: Dictionary = sits[0]
	var nearest_free := {}
	for a in sits.slice(1):
		if nearest_free.is_empty() or a["pos"].distance_to(aimed["pos"]) < nearest_free["pos"].distance_to(aimed["pos"]):
			nearest_free = a
	var farthest: Dictionary = sits.slice(1).reduce(func(best, a): return a if best == null \
		or a["pos"].distance_to(aimed["pos"]) > best["pos"].distance_to(aimed["pos"]) else best, null)
	it.taken = {"%s#%d" % [FOUNTAIN, aimed["index"]]: true}
	var target := it.candidate_of(rim, aimed["index"])
	assert_eq(it.verbs(target), ["Sit", "Inspect"], "aimed at a place taken: the rim still offers a seat")
	assert_eq(it.anchor_for(rim, "sit", aimed["index"], aimed["pos"]), nearest_free["index"], "the free place nearest it")
	# Standing by the far side of the rim, acting on that target sits at the
	# place offered, nearest the one aimed at, not nearest the player.
	var far_cell: Vector2i = main.nav.cell_of(farthest["pos"])
	var act := it.action(target, 0, far_cell)
	assert_eq(act.get("use", {}).get("anchor"), nearest_free["index"], "acting sits where it was offered")
	# Every place held: nothing to sit on.
	var all := {}
	for a in sits:
		all["%s#%d" % [FOUNTAIN, a["index"]]] = true
	it.taken = all
	assert_eq(it.verbs(it.candidate_of(rim, aimed["index"])), ["Inspect"], "the rim full: no Sit")
	# A room seat: its own anchor, whatever is held.
	var desk := thing(main, "seat:w2")
	it.taken = {"seat:w2": true, "seat:w2#0": true}
	assert_eq(it.anchor_for(desk, "sit", 0, desk["anchors"][0]["pos"]), 0, "a room seat's own anchor")
	assert_eq(it.verbs(it.candidate_of(desk, 0)), ["Inspect"], "held: not offered")
	# A placed workstation held at its chair: no other chair.
	var station := it._thing("placement", "placement:station-desk", StylePack.kinds()["workstation"], Vector2(3100, 300), 90)
	it.taken = {"placement:station-desk#0": true}
	assert_eq(it.verbs(it.candidate_of(station, 0)), ["Inspect"], "a workstation held: nothing to take")
	assert_eq(it.anchor_for(station, "use", 0, station["anchors"][0]["pos"]), 1, "its use anchor, held with the chair")
	main.free()


## Through play: behind the desk Kai sits at (his own, w1), "Look at
## screen", which sends nothing; once the workshop empties, behind a free
## desk A walks to the chair and uses the computer, taking the seat (a Go,
## then a Use at its use anchor); the controller fires use_began; Stand up
## leaves.
func test_a_workstation_is_looked_on_and_used_through_play() -> void:
	var main = booted(["--crowd=0", "--style=lowpoly_tropical"])
	arrive(main)
	assert_true(until_ticks(main, func(): return main.player.taken_anchors().has("seat:w1#0"), 200), "Kai sits at his desk")
	var sat_at := "seat:w1"
	var began := []
	main.interaction.use_began.connect(func(t, c): began.append([t["target"], c]))
	var watched := []
	main.interaction.watch_requested.connect(func(t): watched.append(t["target"]))
	var sent := []
	main.player.world = Recorder.new(main.player.world, sent)

	# Behind the agent's desk: Look at screen, and nothing sent.
	var occupied := thing(main, sat_at)
	walk_to(main, occupied["anchors"][2]["pos"])
	main.player.view["facing"] = 0
	frames(main, 0.05)
	assert_eq(prompt(main), "Look at screen", "behind the desk Kai sits at")
	sent.clear()
	main._interact()
	assert_eq(sent, [], "looking on sends nothing")
	assert_eq(watched, [sat_at], "the controller asks for watch mode")

	# Later the workshop empties, Kai too: behind a free desk, Use computer.
	assert_true(until_ticks(main, func(): return not main.player.taken_anchors().has("seat:w1#0"), 300), "Kai leaves")
	var free_desk := "seat:w2"
	assert_true(not main.player.taken_anchors().has(free_desk), free_desk + " is free")
	var desk := thing(main, free_desk)
	walk_to(main, desk["anchors"][2]["pos"])
	main.player.view["facing"] = 0
	frames(main, 0.05)
	assert_eq(prompt(main), "Use computer", "behind a free desk")
	sent.clear()
	main._interact()
	# Seated by the Go, it is shown sitting until the Use lands.
	for i in 30:
		tick(main)
		var now = main.player.view.get("using")
		if now is Dictionary and now.get("capability") == "use" and sent.size() >= 2:
			break
	assert_eq(sent.map(func(c): return c["type"]), ["Go", "Use"], "Go to the seat, then Use")
	if sent.size() == 2:
		assert_eq(sent[0]["to"], {"type": "Seat", "seat": free_desk}, "the Go takes the seat's rules")
		assert_eq([sent[1]["target"], sent[1]["capability"], int(sent[1]["anchor"])], [free_desk, "use", 1], "use, at its use anchor")
	assert_eq(main.player.view.get("seat"), free_desk, "seated")
	var using = main.player.view.get("using")
	assert_true(using is Dictionary and [using["capability"], int(using["anchor"])] == ["use", 1], "the core has it using: %s" % [using])
	frames(main, 0.05)
	assert_eq(began, [[free_desk, "use"]], "use_began, once")
	assert_eq(prompt(main), "Stand up", "Stand up first")
	main._interact()
	tick(main)
	assert_eq(sent[-1]["type"], "StopUsing", "A stands up")
	assert_true(main.player.view.get("using") == null and main.player.view.get("seat") == null, "up, and the seat free")
	main.free()


## Ticks until `done` holds, within `most` ticks; whether it did.
func until_ticks(main, done: Callable, most: int) -> bool:
	for i in most:
		if done.call():
			return true
		tick(main)
	return done.call()
