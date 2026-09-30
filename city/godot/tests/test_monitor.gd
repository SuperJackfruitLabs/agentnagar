## The workstation in every style (interactions spec sections 4 and 5.3,
## Part B's Task 11): each style draws the desk, the chair and the monitor
## from its own kit, the display anchor at the monitor's face; the in-world
## monitor (StationMonitor) shows "idle" or "in use" at every desk, in use
## where its seat is occupied, and a live feed of the station computer only
## for the player's own desk while seated or while watching within 4 m, at
## 10 Hz and at no other time; the activity pulse only in those views; and
## every style frames its station computer in its own bezel, pixel art in
## its pixel font at whole-number scales.
extends TestSuite

const SETTINGS_FILE := "user://test_monitor.cfg"
const STYLES_3D := ["lowpoly_tropical", "anime_cel", "solarpunk", "neon_noir", "voxel"]
const ALL_STYLES := ["lowpoly_tropical", "anime_cel", "solarpunk", "neon_noir", "voxel", "pixel_art"]
## Each style's bezel shape (the plan's Task 11).
const BEZELS := {"pixel_art": "crt", "neon_noir": "glass", "solarpunk": "wood", "voxel": "chunky",
	"lowpoly_tropical": "flat", "anime_cel": "inked"}
## A desk the sitter faces north at (the workshop's), and one facing south
## (the reading room's).
const NORTH_DESK := "seat:w1"
const SOUTH_DESK := "seat:rw1"


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


func booted(style: String, as_player := false):
	var main = load("res://main.gd").new()
	main.settings_path = SETTINGS_FILE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_FILE))
	runner.root.add_child(main)
	var args := ["--crowd=0", "--style=" + style]
	if not as_player:
		args.append("--as=none")
	main.boot(PackedStringArray(args))
	assert_true(not main.hud.error_label.visible, "booted: " + main.hud.error_label.text)
	return main


func thing(main, id: String) -> Dictionary:
	for t in main.interact.things:
		if t["target"] == id:
			return t
	return {}


## `seconds` of frames at 60 a second, the world running.
func frames(main, seconds: float) -> void:
	for f in int(round(seconds * 60.0)):
		main._process(1.0 / 60.0)
		main.driver.advance(1.0 / 60.0)


func tick(main) -> void:
	main.driver.step_once()
	frames(main, 0.05)


func until_ticks(main, done: Callable, most: int) -> bool:
	for i in most:
		if done.call():
			return true
		tick(main)
	return done.call()


## Boots `style` with a player, lets it arrive and has it use the reading
## room's first hot desk, as "Use computer" does: {main, sent}.
func at_the_computer(style := "lowpoly_tropical") -> Dictionary:
	var main = booted(style, true)
	for i in 80:
		main.driver.step_once()
		if main.player.present and not main.player.view.get("moving", false):
			break
	assert_true(main.player.present, "arrived")
	var sent := []
	main.player.world = Recorder.new(main.player.world, sent)
	var desk := thing(main, SOUTH_DESK)
	main.interact.taken = {}
	main.interaction._act(main.interact.candidate_of(desk, 1), 0)
	for i in 300:
		tick(main)
		var using = main.player.view.get("using")
		if using is Dictionary and using.get("capability") == "use":
			break
	frames(main, 0.05)
	assert_true(main._computer_open(), "the computer is open")
	return {"main": main, "sent": sent}


## The desks someone is sat at or using in `projection`, read here from its
## rooms and transit as the core writes them (its `using`: a seat once sat
## in, not while walked to), apart from the client's own reading.
static func seated_at(projection: Dictionary) -> Dictionary:
	var out := {}
	var views: Array = projection.get("in_transit", []).duplicate()
	for room in projection.get("rooms", []):
		views.append_array(room.get("occupants", []))
	for v in views:
		var using = v.get("using")
		if using is Dictionary:
			out[str(using["target"])] = str(v["id"])
	return out


## Every workstation the pack draws shows "in use" exactly where its seat is
## occupied in `projection`, else "idle", except `live` (shown live).
func assert_screens_follow_the_seats(main, live := "") -> void:
	var pack: StylePack = main.host.pack
	assert_true(pack.screens.size() >= 10, "the district's ten workstations have screens: %d" % pack.screens.size())
	for id in pack.screens:
		var shown: Dictionary = pack.screens[id]
		if id == live:
			assert_eq(shown["state"], StationMonitor.LIVE, "%s: the player's own, live" % id)
			continue
		var occupied := seated_at(main._last_projection).has(id)
		assert_eq(shown["state"], StationMonitor.IN_USE if occupied else StationMonitor.IDLE,
			"%s: %s" % [id, "occupied, in use" if occupied else "free, idle"])
		assert_eq(shown["feed"], null, "%s: no feed" % id)
		assert_eq(shown["pulse"], 0.0, "%s: no pulse" % id)


# ---- The monitor ----

## Using a desk's computer, its monitor shows the computer's screen through
## a 256 x 160 feed updated ten times a second, counted by the renders the
## monitor asks for; every other desk shows only idle or in use. Standing
## up ends the feed, and nothing renders after it.
func test_the_monitor_updates_at_10_hz_for_the_players_own_desk_only() -> void:
	var run := at_the_computer()
	var main = run["main"]
	var monitor: StationMonitor = main.monitor
	var pack: StylePack = main.host.pack
	assert_eq(monitor.own_desk, SOUTH_DESK, "the feed is the player's own desk's")
	assert_true(monitor.feed is SubViewport, "through a SubViewport")
	if monitor.feed == null:
		main.free()
		return
	assert_eq(monitor.feed.size, Vector2i(256, 160), "at 256 x 160 in 3D")
	assert_eq(pack.screens[SOUTH_DESK]["feed"], monitor.feed.get_texture(), "the desk's screen shows the feed")
	assert_screens_follow_the_seats(main, SOUTH_DESK)
	var before := monitor.renders
	frames(main, 1.0)
	assert_eq(monitor.renders - before, 10, "ten renders in a second of frames")
	before = monitor.renders
	frames(main, 0.5)
	assert_eq(monitor.renders - before, 5, "five in half a second")
	# A long frame renders once, not to catch up.
	before = monitor.renders
	main._process(0.35)
	assert_eq(monitor.renders - before, 1, "one render for a long frame")
	assert_eq(monitor.feed.render_target_update_mode, SubViewport.UPDATE_ONCE, "each render is one frame's")

	main.computer.leave()
	tick(main)
	assert_eq(monitor.feed, null, "standing up ends the feed")
	assert_eq(monitor.own_desk, "", "for every desk")
	before = monitor.renders
	frames(main, 1.0)
	assert_eq(monitor.renders - before, 0, "and nothing renders after it")
	tick(main)
	assert_screens_follow_the_seats(main)
	main.free()


## Every other desk shows the style's idle screen or its glow: in use where
## its seat is occupied, by an agent at its desk or anyone sitting, and
## idle again once they leave. No feed and no pulse without the computer.
func test_other_desks_show_idle_or_in_use() -> void:
	var main = booted("lowpoly_tropical")
	var pack: StylePack = main.host.pack
	for id in pack.screens:
		assert_eq(pack.screens[id]["state"], StationMonitor.IDLE, "%s: idle before anyone arrives" % id)
	assert_true(until_ticks(main, func(): return seated_at(main._last_projection).has(NORTH_DESK), 300),
		"someone sits at %s" % NORTH_DESK)
	frames(main, 0.1)
	assert_eq(pack.screens[NORTH_DESK]["state"], StationMonitor.IN_USE, "an occupied desk is in use")
	assert_screens_follow_the_seats(main)
	assert_eq(main.monitor.feed, null, "no feed with no computer open")
	var renders: int = main.monitor.renders
	frames(main, 1.0)
	assert_eq(main.monitor.renders, renders, "nothing renders")
	main.free()


## A desk taken by someone still walking to it (its seat set, as the core
## sets it the moment the seat is taken) stays idle until they sit there,
## as the core shows them using it only then.
func test_a_desk_someone_walks_to_stays_idle_until_they_sit() -> void:
	var main = booted("lowpoly_tropical")
	var pack: StylePack = main.host.pack
	var walking := {}
	var sat := {}
	for i in 300:
		tick(main)
		var seated := seated_at(main._last_projection)
		for room in main._last_projection.get("rooms", []):
			for v in room.get("occupants", []):
				var seat = v.get("seat")
				if seat == null or not pack.screens.has(str(seat)):
					continue
				if not seated.has(str(seat)):
					walking[seat] = true
					assert_eq(pack.screens[seat]["state"], StationMonitor.IDLE, "%s: %s walks to it, still idle" % [seat, v["id"]])
				elif walking.has(seat):
					sat[seat] = true
					assert_eq(pack.screens[seat]["state"], StationMonitor.IN_USE, "%s: sat at, in use" % seat)
		if not sat.is_empty():
			break
	assert_true(not walking.is_empty(), "someone was seen walking to a workstation it had taken")
	assert_true(not sat.is_empty(), "and sitting down at it: %s" % [walking.keys()])
	main.free()


## The monitor's rule for a live feed: the player's own desk while seated
## at it (using, not watching), or a watched desk within 4 m; nothing
## otherwise.
func test_a_watched_desk_feeds_only_within_4_m() -> void:
	var screen := Vector2(10, 10)
	assert_true(StationMonitor.feeds(false, null, screen), "seated at it: always")
	assert_true(StationMonitor.feeds(true, screen + Vector2(0, 0.6), screen), "watching from behind the chair")
	assert_true(StationMonitor.feeds(true, screen + Vector2(4.0, 0), screen), "watching from 4 m")
	assert_true(not StationMonitor.feeds(true, screen + Vector2(4.01, 0), screen), "not from farther")
	assert_true(not StationMonitor.feeds(true, null, screen), "nor from nowhere")
	assert_true(not StationMonitor.feeds(true, screen, null), "nor at a desk drawn with no screen")


## The coarse activity pulse follows the station's chat while it works, in
## the player's own view of their desk and in a watcher's, and nowhere
## else: no other desk pulses, occupied or not, and it stops when the chat
## does. Watching Kai at his desk from behind his chair feeds his screen,
## and the pulse shows there too.
func test_the_pulse_appears_only_in_the_owners_and_the_watchers_views() -> void:
	var run := at_the_computer()
	var main = run["main"]
	var pack: StylePack = main.host.pack
	var monitor: StationMonitor = main.monitor
	frames(main, 0.5)
	assert_eq(pack.screens[SOUTH_DESK]["pulse"], 0.0, "no pulse before the chat is seen working")
	main.computer._on_chat_status("working")
	var pulses := []
	for f in 60:
		frames(main, 1.0 / 60.0)
		pulses.append(pack.screens[SOUTH_DESK]["pulse"])
	assert_true(pulses.max() > 0.9 and pulses.min() < 0.1, "the pulse rises and falls over a second: %.2f to %.2f" % [pulses.min(), pulses.max()])
	for id in pack.screens:
		if id != SOUTH_DESK:
			assert_eq(pack.screens[id]["pulse"], 0.0, "%s does not pulse" % id)
	main.computer._on_chat_status("idle")
	frames(main, 0.2)
	assert_eq(pack.screens[SOUTH_DESK]["pulse"], 0.0, "the chat idle: no pulse")
	main.computer.leave()
	tick(main)

	# Watching Kai at his desk.
	assert_true(until_ticks(main, func(): return main.player.taken_anchors().has("seat:w1#0"), 300), "Kai sits at his desk")
	var desk := thing(main, NORTH_DESK)
	var stand: Vector2 = desk["anchors"][2]["pos"]
	main.player.go_point(stand)
	assert_true(until_ticks(main, func(): return main.player.shown.distance_to(stand) < 30.0, 200), "at the stand anchor behind Kai's chair")
	main._on_watch_requested(main.interact.candidate_of(desk, 3))
	assert_true(main._computer_open() and main.computer.watch, "watching")
	frames(main, 0.1)
	assert_eq(monitor.own_desk, NORTH_DESK, "a watched desk within 4 m is fed")
	assert_eq(pack.screens[NORTH_DESK]["state"], StationMonitor.LIVE, "and shown live")
	assert_eq(pack.screens[SOUTH_DESK]["state"], StationMonitor.IDLE, "the desk the player left is idle")
	main.computer._on_chat_status("working")
	pulses = []
	for f in 60:
		frames(main, 1.0 / 60.0)
		pulses.append(pack.screens[NORTH_DESK]["pulse"])
	assert_true(pulses.max() > 0.9, "the watcher sees the pulse")
	main.computer.leave()
	frames(main, 0.1)
	assert_eq(pack.screens[NORTH_DESK]["pulse"], 0.0, "no pulse once the watcher looks away")
	assert_eq(pack.screens[NORTH_DESK]["state"], StationMonitor.IN_USE, "Kai's screen is in use again")
	main.free()


## A new style while the computer is open moves the feed to its pack.
func test_the_feed_follows_a_change_of_style() -> void:
	var run := at_the_computer()
	var main = run["main"]
	var old: StylePack = main.host.pack
	for dir in main.styles:
		if String(dir).get_file() == "anime_cel":
			main._activate(dir)
	assert_true(main.host.pack != old, "another pack")
	frames(main, 0.2)
	assert_eq(main.monitor.pack, main.host.pack, "the monitor draws on the new pack")
	assert_eq(main.monitor.own_desk, SOUTH_DESK, "fed there")
	assert_eq(main.host.pack.screens[SOUTH_DESK]["state"], StationMonitor.LIVE, "live in the new style")
	main.free()


# ---- The art ----

## Anchor `a` of seat or placement `p` in the world: [place (metres),
## facing (degrees)].
static func _anchor_at(p: Dictionary, a: Dictionary) -> Array:
	var turn := Transform2D(deg_to_rad(float(p["facing"])), p["pos"])
	return [turn * (Vector2(a["at"]["x"], a["at"]["z"]) / 100.0), float(p["facing"]) + float(a.get("facing", 0))]


static func _display_anchor() -> Dictionary:
	for a in StylePack.kinds()["workstation"]["anchors"]:
		if a["type"] == "display":
			return a
	return {}


## Each workstation seat of the district: {id: {pos (metres), facing}}.
static func _seats(main) -> Dictionary:
	var out := {}
	for f in main.manifest["city"]["districts"][0]["facilities"]:
		for r in f.get("rooms", []):
			for s in r.get("seats", []):
				if s.get("kind") == "workstation":
					out[str(s["id"])] = {"pos": CityGeometry.pt_m(s["pos"]), "facing": float(s.get("facing", 0))}
	return out


## Every 3D style draws the workstation from its kit: desk, chair and a
## monitor whose `screen` the in-world monitor lights, its `display` node
## at the monitor's face, by the display anchor, at its height and facing
## the chair; no stand-in box. Its feed is 256 x 160.
func test_every_3d_style_draws_the_workstation_from_its_kit() -> void:
	var anchor := _display_anchor()
	for style in STYLES_3D:
		var main = booted(style)
		var pack = main.host.pack
		var skin: Dictionary = pack.resolve("seats", "workstation")
		assert_true(not skin.has("monitor") and not skin.has("desk"), "%s: one piece of its own, no stand-in" % style)
		assert_true(skin.has("screen") and skin["screen"].has("idle") and skin["screen"].has("glow"), "%s: its idle screen and its glow" % style)
		var seats := _seats(main)
		assert_eq(seats.size(), 10, "%s: the district's ten workstations" % style)
		for id in seats:
			var node: Node3D = pack.placement_nodes.get(id)
			assert_true(node != null and node.find_child("screen", true, false) is MeshInstance3D, "%s: %s has its screen" % [style, id])
			assert_true(pack.screens.has(id), "%s: %s's screen is the monitor's to light" % [style, id])
			var screen_mesh: MeshInstance3D = node.find_child("screen", true, false)
			var dark = screen_mesh.material_override
			var kit_material: BaseMaterial3D = screen_mesh.mesh.surface_get_material(0)
			# Culled where the kit's own is not, the screen's near face
			# (wound away from the sitter in the double-sided kits) is lost
			# and the case behind it shows.
			assert_true(dark is BaseMaterial3D and dark.albedo_color == Color(str(skin["screen"]["idle"]))
				and dark.cull_mode == kit_material.cull_mode,
				"%s: %s's idle screen is its dark colour, drawn from both sides as its kit's is" % [style, id])
			assert_eq(pack.screen_feed_size(id), Vector2i(256, 160), "%s: %s feeds at 256 x 160" % [style, id])
			var face = pack.display_face(id)
			assert_true(face is Transform3D, "%s: %s draws its display node" % [style, id])
			if not face is Transform3D:
				continue
			var want: Array = _anchor_at(seats[id], anchor)
			var at := Vector2(face.origin.x, face.origin.z)
			assert_true(at.distance_to(want[0]) < 0.1, "%s: %s's face is by its display anchor (%.3f m off)" % [style, id, at.distance_to(want[0])])
			var bottom := float(anchor["height"]) / 100.0
			var top := bottom + float(anchor["size"]["d"]) / 100.0
			assert_true(face.origin.y > bottom and face.origin.y < top, "%s: %s's face is %.2f m up, in its anchor's span" % [style, id, face.origin.y])
			var out := -(face as Transform3D).basis.z
			var normal := Vector2(sin(deg_to_rad(want[1])), -cos(deg_to_rad(want[1])))
			assert_true(Vector2(out.x, out.z).normalized().dot(normal) > 0.99, "%s: %s's face looks at the chair" % [style, id])
		assert_eq(Array(pack.missing_scenes), [], "%s: no kit piece missing" % style)
		main.free()


## Pixel art draws the desk and its monitor as sprites at eight facings,
## each declaring its screen's face; the pack lights that face as the
## monitor says, over the sprite: the glow in use, lighter at the top of the
## pulse. Its screen is a handful of pixels, so it takes no feed (the
## ruling for Task 11). A screen the view sees from behind glows along its
## top.
func test_pixel_art_draws_the_workstation_and_its_screen_states() -> void:
	var main = booted("pixel_art")
	var pack = main.host.pack
	var skin: Dictionary = pack.resolve("seats", "workstation")
	for f in [0, 45, 90, 135, 180, 225, 270, 315]:
		var path := str(skin["facings"][str(f)])
		assert_true(path.ends_with("workstation_%d.png" % f), "its own sprite at %d: %s" % [f, path])
		var info: Dictionary = pack.kit_sprites.get(path.trim_prefix("assets/"), {})
		assert_true(info.has("display"), "the %d sprite declares its screen's face" % f)
	var anchor := _display_anchor()
	var seats := _seats(main)
	for id in seats:
		var face = pack.display_face(id)
		assert_true(face is Dictionary, "%s: its sprite draws a face" % id)
		if face is Dictionary:
			var want: Array = _anchor_at(seats[id], anchor)
			assert_true((face["at"] as Vector2).distance_to(want[0]) < 0.1, "%s: its face is by its display anchor (%.3f m off)" % [id, (face["at"] as Vector2).distance_to(want[0])])
		assert_eq(pack.screen_feed_size(id), Vector2i.ZERO, "%s: no feed" % id)
	var glow: Node = pack.screen_overlay(NORTH_DESK)
	assert_true(glow is Polygon2D, "an overlay on the screen's face")
	if glow is Polygon2D:
		var colour := Color(str(skin["screen"]["glow"]))
		assert_true(not glow.visible, "idle: the sprite's own dark screen")
		pack.show_screen(NORTH_DESK, StationMonitor.IN_USE)
		assert_true(glow.visible and glow.texture == null, "in use: the glow")
		assert_eq(glow.color, colour, "in the style's glow colour")
		pack.show_screen(NORTH_DESK, StationMonitor.IN_USE, null, 1.0)
		assert_true(glow.color.get_luminance() > colour.get_luminance() + 0.1, "lighter at the top of the pulse")
		pack.show_screen(NORTH_DESK, StationMonitor.IDLE)
		assert_true(not glow.visible, "idle again")
	var back: Node = pack.screen_overlay(SOUTH_DESK)
	pack.show_screen(SOUTH_DESK, StationMonitor.IN_USE)
	assert_true(back is CanvasItem and back.visible, "a screen seen from behind shows its glow too")
	main.free()


## Pixel art: the player's own desk shows the glow, pulsing while the chat
## works, with no feed rendered.
func test_pixel_art_the_players_own_desk_glows_and_pulses_without_a_feed() -> void:
	var main = booted("pixel_art", true)
	for i in 80:
		main.driver.step_once()
		if main.player.present and not main.player.view.get("moving", false):
			break
	var pack = main.host.pack
	main.computer = ComputerScreen.new()
	main.computer.settings = main.settings
	main.stack.push(main.computer)
	main.computer.open({"target": NORTH_DESK, "kind": "workstation", "binding": {}}, main._station_source(), false)
	main.monitor.computer = main.computer
	frames(main, 0.1)
	var monitor: StationMonitor = main.monitor
	assert_eq(monitor.own_desk, NORTH_DESK, "the player's own desk")
	assert_eq(monitor.feed, null, "no feed")
	assert_eq(pack.screens[NORTH_DESK]["state"], StationMonitor.IN_USE, "it glows")
	var renders := monitor.renders
	main.computer._on_chat_status("working")
	var pulses := []
	for f in 60:
		frames(main, 1.0 / 60.0)
		pulses.append(pack.screens[NORTH_DESK]["pulse"])
	assert_true(pulses.max() > 0.9 and pulses.min() < 0.1, "and pulses while the chat works")
	assert_eq(monitor.renders, renders, "with nothing rendered")
	main.free()


## A pack that counts how often the monitor asks it for a feed's size, and
## has none to give: a desk whose pack takes no feed is asked once.
class NoFeedPack extends StylePack:
	var asked := 0

	func screen_feed_size(_id: String) -> Vector2i:
		asked += 1
		return Vector2i.ZERO

	func screen_point(_id: String):
		return Vector2.ZERO


func test_a_desk_that_takes_no_feed_is_asked_once() -> void:
	var pack := NoFeedPack.new()
	pack.add_screen("seat:a")
	var monitor := StationMonitor.new()
	runner.root.add_child(monitor)
	var c := ComputerScreen.new()
	c.desk = {"target": "seat:a", "kind": "workstation", "binding": {}}
	runner.root.add_child(c)
	monitor.set_pack(pack)
	monitor.computer = c
	for f in 30:
		monitor.advance(1.0 / 60.0)
	assert_eq(monitor.own_desk, "seat:a", "the player's own desk")
	assert_eq(pack.asked, 1, "asked for a feed once in 30 frames")
	assert_eq(pack.screens["seat:a"]["state"], StationMonitor.IN_USE, "and glowing")
	c.free()
	monitor.advance(1.0 / 60.0)
	assert_eq(monitor.own_desk, "", "the computer gone, no own desk")
	assert_eq(pack.screens["seat:a"]["state"], StationMonitor.IDLE, "idle again")
	monitor.free()
	pack.free()


## While a screen the computer opened covers it (Settings, from "Connect
## your AgentPod"), the feed holds its last frame and renders nothing;
## uncovered, it renders again.
func test_the_feed_pauses_while_the_computer_is_covered() -> void:
	var run := at_the_computer()
	var main = run["main"]
	var monitor: StationMonitor = main.monitor
	var over := Screen.new()
	main.stack.push(over)
	var before := monitor.renders
	frames(main, 1.0)
	assert_eq(monitor.renders, before, "nothing renders while covered")
	assert_eq(main.host.pack.screens[SOUTH_DESK]["state"], StationMonitor.LIVE, "the screen keeps its last frame")
	main.stack.remove(over)
	before = monitor.renders
	frames(main, 1.0)
	assert_eq(monitor.renders - before, 10, "ten a second again once uncovered")
	main.free()


# ---- The bezels ----

## Every style frames its station computer in its own bezel: a CRT for
## pixel art, glass for neon noir, a wooden frame for solarpunk, a chunky
## frame for voxel, a clean flat one for low-poly and an inked one for
## anime; each shape is drawn as it says.
func test_each_style_has_its_own_bezel() -> void:
	for style in ALL_STYLES:
		var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://styles/%s/style.json" % style))
		assert_true(json.get("ui", {}).has("bezel"), "%s declares its bezel" % style)
		var spec := UiTheme.from_style(json).bezel()
		assert_eq(spec["shape"], BEZELS[style], "%s's bezel" % style)
		var box := ComputerScreen.bezel_box(spec)
		var colour := Color(str(spec["colour"]))
		match BEZELS[style]:
			"crt":
				assert_true(box.border_width_left >= 6 and box.shadow_size > 0, "%s: a deep lip and a shadow" % style)
				assert_true(box.corner_radius_top_left >= 16, "%s: a CRT's round corners" % style)
			"glass":
				assert_true(box.bg_color.a < colour.a, "%s: see-through" % style)
				assert_true(box.border_color.get_luminance() > colour.get_luminance(), "%s: a bright edge" % style)
			"wood":
				assert_true(box.border_width_left >= 6, "%s: a broad frame" % style)
				assert_true(box.border_color.get_luminance() < colour.get_luminance(), "%s: its darker grain at the edge" % style)
				assert_true(colour.r > colour.b, "%s: a timber colour" % style)
			"chunky":
				assert_true(box.border_width_left >= 10, "%s: a thick frame" % style)
				assert_eq(box.corner_radius_top_left, 0, "%s: square" % style)
				assert_true(box.shadow_offset != Vector2.ZERO, "%s: a blocky shadow" % style)
			"flat":
				assert_eq(box.border_width_left, 0, "%s: no border" % style)
				assert_eq(box.shadow_size, 0, "%s: no shadow" % style)
			"inked":
				assert_true(box.border_width_left >= 3, "%s: an ink line" % style)
				assert_true(box.border_color.get_luminance() < 0.2 and colour.get_luminance() > 0.5, "%s: dark ink round a light frame" % style)


# ---- Pixel art's type ----

## A Label's or Button's face and size as drawn.
static func _face(c: Control) -> Array:
	return [c.get_theme_font("font"), c.get_theme_font_size("font_size")]


## In pixel art the station computer draws its pixel faces at whole-number
## scales only: the display face on its 8 px grid, the overlay's body face
## on its 10 px one, on the desktop and in every app; display text too
## small for two steps of the display face's grid falls back to the body
## face.
func test_pixel_art_draws_the_computer_in_its_pixel_font_at_whole_number_scales() -> void:
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://styles/pixel_art/style.json"))
	var ui := UiTheme.from_style(json)
	var display_grid := int(ui.spec["pixel_base"])
	var body_grid := int(ui.spec["pixel_base_body"])
	var router := InputRouter.new()
	runner.root.add_child(router)
	var stack := ScreenStack.new()
	stack.router = router
	stack.ui = ui
	runner.root.add_child(stack)
	var c := ComputerScreen.new()
	c.settings = Settings.new()
	c.settings.path = SETTINGS_FILE
	c.glyphs = InputGlyphs.new()
	c.platform = "desktop"
	c.touch = false
	stack.push(c)
	c.open({"target": NORTH_DESK, "kind": "workstation", "binding": {"source": "agentpod", "ref": "sample"}}, SampleSource.new())
	for f in 5:
		await runner.process_frame
	var checked := 0
	for view in ["desktop"] + ComputerScreen.APP_IDS:
		if view != "desktop":
			c.open_app(view)
			for f in 3:
				await runner.process_frame
		for node in c.find_children("*", "Control", true, false):
			if not (node is Label or node is Button) or not node.is_visible_in_tree():
				continue
			var drawn := _face(node)
			if drawn[0] == ui.display_font:
				assert_true(drawn[1] % display_grid == 0 and drawn[1] >= 2 * display_grid,
					"%s %s: the display face at %d px" % [view, node.name, drawn[1]])
				checked += 1
			elif drawn[0] == ui.body_font:
				assert_true(drawn[1] % body_grid == 0, "%s %s: the body face at %d px" % [view, node.name, drawn[1]])
				checked += 1
	assert_true(checked > 30, "every label and button checked: %d" % checked)
	stack.free()
	router.free()
	# Display text below two steps of its grid takes the overlay's face.
	var small := UiTheme.from_style(json)
	assert_eq(small.heading_font(24), small.display_font, "24 px: the display face")
	assert_eq(small.heading_size(24), 24, "at three steps")
	assert_eq(small.heading_font(12), small.body_font, "12 px: the overlay's body face")
	assert_eq(small.heading_size(12) % body_grid, 0, "on its own grid")
	var smooth := UiTheme.from_style({})
	assert_eq(smooth.heading_font(8), smooth.display_font, "a style without a pixel font keeps its display face")
