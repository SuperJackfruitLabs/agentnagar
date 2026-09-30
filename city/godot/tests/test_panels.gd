## Inspect and Read (interactions spec section 2, integration plan 4.1):
## the overlay for each panel type and for inspecting, "Sample" in every
## view, scrolling and leaving it by controller, leaving it while a tram
## arrives (Review Focus 4), the overlay opening only once the core has the
## player reading, the surfaces' level of detail far, near and open, and
## the map's List tab reading the displays as text.
extends TestSuite

const NOTICEBOARD := "placement:square-noticeboard"
const PLAQUE := "placement:guild-hall-plaque"
const SHELF := "placement:reading-shelf-1"
const KIOSK := "placement:library-kiosk"
const UNBOUND_SHELF := "placement:commons-bookshelf"

const NOTICES := {"type": "Notices", "title": "From the Square", "sample": true, "items": [
	{"date": "2026-09-20", "headline": "v0.0.3 · Trams run", "body": "Trams run the boulevard."},
	{"date": "2026-09-10", "headline": "v0.0.2 · The map", "body": "The map opens with M."},
	{"date": "2026-09-01", "headline": "v0.0.1 · The district", "body": "The district opens."},
	{"date": "2026-08-20", "headline": "v0.0.0 · The plan", "body": "The plan is written."}]}
const SHELF_PANEL := {"type": "Shelf", "title": "The vision", "sample": true, "spines": [
	{"title": "A maker city", "subtitle": "docs/vision/VISION.md"}, {"title": "People", "subtitle": ""}]}
const PLAQUE_PANEL := {"type": "Plaque", "title": "The Guild hall", "text": "Where makers work.", "sample": true}


func kind(id: String) -> Dictionary:
	return StylePack.kinds()[id]


func style_json(style: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://styles/%s/style.json" % style))


## A stack in the window, skinned by `style`, with an overlay pushed and
## opened: [stack, screen].
func overlay(panel: Dictionary, kind_id: String, reading: bool, style := "lowpoly_tropical", source := "") -> Array:
	var stack := ScreenStack.new()
	runner.root.add_child(stack)
	stack.set_theme(UiTheme.from_style(style_json(style)))
	var screen := PanelScreen.new()
	stack.push(screen)
	screen.open("placement:x", panel, kind(kind_id), reading, source)
	return [stack, screen]


func roles(screen: PanelScreen) -> Array:
	return screen.content.get_children().map(func(l): return l.get_meta("role"))


func texts(screen: PanelScreen, role: String) -> Array:
	return screen.content.get_children().filter(func(l): return l.get_meta("role") == role).map(func(l): return l.text)


# ---- The overlay ----

## Read renders each panel type in full; Inspect shows the kind's name,
## description and verbs, and a bound display's source, never the panel's
## items; a display bound to nothing reads "Nothing to read here yet".
func test_the_overlay_shows_each_panel_type_and_the_inspect_card() -> void:
	var o := overlay(NOTICES, "noticeboard", true)
	var s: PanelScreen = o[1]
	assert_eq(texts(s, "name"), ["Noticeboard"], "notices: the kind's name")
	assert_eq(texts(s, "title"), ["From the Square"], "notices: the title")
	assert_eq(texts(s, "headline"), ["2026-09-20 · v0.0.3 · Trams run", "2026-09-10 · v0.0.2 · The map",
		"2026-09-01 · v0.0.1 · The district", "2026-08-20 · v0.0.0 · The plan"], "notices: every item's date and headline")
	assert_eq(texts(s, "body"), ["Trams run the boulevard.", "The map opens with M.", "The district opens.", "The plan is written."],
		"notices: every item's body")
	o[0].free()
	o = overlay(SHELF_PANEL, "bookshelf", true)
	s = o[1]
	assert_eq(texts(s, "headline"), ["A maker city", "People"], "shelf: every spine")
	assert_eq(texts(s, "body"), ["docs/vision/VISION.md"], "shelf: the subtitles it has")
	o[0].free()
	o = overlay(PLAQUE_PANEL, "plaque", true)
	s = o[1]
	assert_eq([texts(s, "title"), texts(s, "body")], [["The Guild hall"], ["Where makers work."]], "plaque: title and text")
	o[0].free()
	o = overlay({}, "kiosk", true)
	s = o[1]
	assert_eq(texts(s, "empty"), [PanelScreen.NOTHING_TO_READ], "unbound: nothing to read yet")
	assert_true(not "Sample" in s.text(), "unbound: no Sample")
	o[0].free()
	# Inspect: what it is, what it is for, and where its content comes from.
	o = overlay(NOTICES, "noticeboard", false, "lowpoly_tropical", "sample")
	s = o[1]
	assert_eq(texts(s, "description"), [str(kind("noticeboard")["description"])], "inspect: the description")
	assert_eq(texts(s, "verbs"), ["You can: Read, Inspect"], "inspect: its verbs, Inspect last")
	assert_eq(texts(s, "source"), ["Shows: From the Square, from the sample source"], "inspect: the source when bound")
	assert_true(texts(s, "headline").is_empty() and texts(s, "body").is_empty(), "inspect: none of the items")
	o[0].free()
	o = overlay({}, "kiosk", false)
	s = o[1]
	assert_eq(texts(s, "verbs"), ["You can: Browse, Inspect"], "a kiosk is browsed")
	assert_true(texts(s, "source").is_empty(), "unbound: no source")
	o[0].free()


## "Sample" shows on sample content in every view: the overlay read and
## inspected, the surface far and near, and the map's List row. Content
## that is not sample never says it.
func test_sample_shows_in_every_view() -> void:
	for reading in [true, false]:
		var o := overlay(NOTICES, "noticeboard", reading)
		var s: PanelScreen = o[1]
		var mark: Label = s.line("sample")
		assert_true(mark != null and mark.text == "Sample" and mark.is_visible_in_tree(), "the overlay says Sample (read %s)" % reading)
		assert_eq(roles(s).slice(0, 2), ["name", "sample"], "under the name (read %s)" % reading)
		o[0].free()
	var live := NOTICES.duplicate(true)
	live["sample"] = false
	var o := overlay(live, "noticeboard", true)
	assert_true(o[1].line("sample") == null, "live content is not marked")
	o[0].free()
	var surface := {"id": NOTICEBOARD, "name": "Noticeboard", "panel": NOTICES}
	assert_eq(Surfaces.text(surface, Surfaces.FAR, 3), "Noticeboard · Sample", "the surface far: its chip, marked")
	assert_true(Surfaces.text(surface, Surfaces.NEAR, 3).begins_with("Sample\n"), "the surface near: marked")
	var model := MapModel.new()
	model.add_things([{"id": NOTICEBOARD, "name": "Noticeboard", "pos": Vector2.ZERO, "panel": NOTICES}])
	assert_true("Sample" in MapScreen._thing_row_text(model.things[NOTICEBOARD]), "the List row: marked")


## The overlay scrolls by the d-pad, the arrows and a stick held over, and
## B or Esc leaves it.
func test_the_overlay_scrolls_and_closes_by_controller() -> void:
	var long := NOTICES.duplicate(true)
	for i in 40:
		long["items"].append({"date": "2026-01-%02d" % (i % 28 + 1), "headline": "Notice %d" % i, "body": "A body long enough to wrap onto a second line in the overlay's width."})
	for close in [pad(JOY_BUTTON_B), key(KEY_ESCAPE)]:
		var o := overlay(long, "noticeboard", true)
		var stack: ScreenStack = o[0]
		var s: PanelScreen = o[1]
		for f in 3:
			await runner.process_frame
		assert_true(s.scroll.get_v_scroll_bar().max_value > s.scroll.size.y, "a long panel is taller than its window")
		assert_eq(s.scrolled(), 0, "it opens at the top")
		assert_true(s.close_button.has_focus(), "Close holds the focus")
		send(s, pad(JOY_BUTTON_DPAD_DOWN))
		send(s, pad(JOY_BUTTON_DPAD_DOWN))
		assert_eq(s.scrolled(), int(PanelScreen.SCROLL_STEP * 2), "the d-pad scrolls down")
		send(s, key(KEY_UP))
		assert_eq(s.scrolled(), int(PanelScreen.SCROLL_STEP), "the arrows scroll up")
		send(s, axis(JOY_AXIS_RIGHT_Y, 1.0))
		s._process(0.1)
		assert_true(s.scrolled() > int(PanelScreen.SCROLL_STEP), "a stick held down scrolls on")
		send(s, axis(JOY_AXIS_RIGHT_Y, 0.0))
		var at := s.scrolled()
		s._process(0.1)
		assert_eq(s.scrolled(), at, "and stops when let go")
		assert_eq(stack.top(), s, "still open")
		send(s, close)
		assert_true(stack.screens.is_empty(), "%s leaves it" % close.as_text())
		stack.free()


# ---- In play ----

func booted(style: String):
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=" + style]), "res://tests/fixtures" if style == "fake_pack" else "res://styles")
	assert_true(not main.hud.error_label.visible, "booted: " + main.hud.error_label.text)
	return main


## Steps until the player has ridden in and stands on the Square's
## platform, then until the trams have left the Square; with `settle`, it
## then stands there long enough for the platform to offer the tram.
func arrive(main, settle := false) -> void:
	for i in 80:
		tick(main)
		if main.player.present and not main.player.view.get("moving", false):
			break
	for i in 40:
		if not tram_by_the_square(main.driver.world):
			break
		tick(main)
	assert_true(main.player.present, "arrived")
	if settle:
		frames(main, main.OFFER_AFTER_S + 0.2)


func tick(main) -> void:
	main.driver.step_once()
	for f in 3:
		main._process(1.0 / 60.0)


func frames(main, seconds: float) -> void:
	for f in int(round(seconds * 60.0)):
		main._process(1.0 / 60.0)
		main.driver.advance(1.0 / 60.0)


func until(main, done: Callable, most := 120) -> bool:
	for i in most:
		if done.call():
			return true
		tick(main)
	return done.call()


func walk_to(main, pos: Vector2) -> void:
	main.player.go_point(pos)
	for i in 80:
		tick(main)
		if not main.player.view.get("moving", false) and not main.player.following:
			break


func thing(main, id: String) -> Dictionary:
	for t in main.interact.things:
		if t["target"] == id:
			return t
	return {}


func stand_of(main, id: String) -> Vector2:
	return thing(main, id)["anchors"].filter(func(a): return a["type"] == "stand")[0]["pos"]


func prompt(main) -> String:
	return main.hud.prompt_label.text if main.hud.prompt.visible else ""


func key(code: int, pressed := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e


func pad(button: JoyButton, pressed := true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


func axis(which: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = which
	e.axis_value = value
	return e


## Sends `event` through the window, as a player's press arrives, and lets
## it go again.
func send(node: Node, event: InputEvent) -> void:
	# The press may close the node: the window is kept for the release.
	var window := node.get_viewport()
	window.push_input(event)
	if event is InputEventKey or event is InputEventJoypadButton:
		var up = event.duplicate()
		up.pressed = false
		window.push_input(up)


## Passes a world's calls through, noting each command sent; with
## `unknown`, a Use names a target no one knows, so the core refuses it.
class Recorder:
	var world
	var sent: Array
	var unknown := false

	func _init(world_, sent_: Array) -> void:
		world = world_
		sent = sent_

	func command(json: String) -> String:
		var c = JSON.parse_string(json)
		if unknown and c["type"] == "Use":
			json = json.replace(JSON.stringify(c["target"]), "\"placement:nowhere\"")
			c["target"] = "placement:nowhere"
		sent.append(c)
		return world.command(json)

	func leave() -> String:
		return world.leave()


## Review Focus 4: the noticeboard's overlay is open over the Square's
## platform while a tram arrives. B or Esc leaves it: the world takes input
## again, the prompt is the tram's, and A boards.
func test_leaving_the_overlay_while_a_tram_arrives_gives_the_world_back() -> void:
	var main = booted("fake_pack")
	arrive(main, true)
	assert_eq(prompt(main), "Wait for the tram", "on the platform")
	var board: Dictionary = main.interact.candidate_of(thing(main, NOTICEBOARD), 0)
	assert_eq(main.interact.verbs(board), ["Read", "Inspect"], "the noticeboard's verbs")
	main.interaction._act(board, 1)
	assert_true(main.stack.top() is PanelScreen, "its overlay is open")
	var card: String = main.stack.top().text()
	assert_true("Noticeboard" in card and "from the sample source" in card and not "v0.0.3" in card,
		"inspected: what it is and its source, not its notices: " + card)
	assert_true(not main.router.world_enabled, "the world takes no input")
	var at: Dictionary = main.trams.platform(main.nav.room_at(main.player.cell))
	var arrived := func(): return not main.trams.standing_open(at["line"], at["stop"], at["direction"]).is_empty()
	assert_true(until(main, arrived, 200), "a tram arrives with its doors open")
	assert_true(main.stack.top() is PanelScreen, "behind the overlay")
	for close in [key(KEY_ESCAPE), pad(JOY_BUTTON_B)]:
		if not main.stack.top() is PanelScreen:
			main.interaction._act(board, 1)
		send(main, close)
		frames(main, 0.05)
		assert_eq(main.stack.top(), main.hud, "%s: back in play" % close.as_text())
		assert_true(main.router.world_enabled, "%s: the world takes input" % close.as_text())
		assert_eq(prompt(main), "Board", "%s: the tram's prompt" % close.as_text())
		assert_true(not main._menu is GameMenu or not main.stack.screens.has(main._menu), "%s: and no game menu opened" % close.as_text())
	send(main, key(KEY_SPACE))
	assert_true(until(main, func(): return main.player.aboard, 10), "A boards")
	main.free()


## Read sends the Use; the overlay opens only once the core has the player
## reading. A read refused never opens it, and it closes when the reading
## ends.
func test_the_overlay_opens_once_the_core_has_the_player_reading() -> void:
	var main = booted("lowpoly_tropical")
	arrive(main)
	walk_to(main, stand_of(main, NOTICEBOARD))
	var sent := []
	var recorder := Recorder.new(main.player.world, sent)
	main.player.world = recorder
	var board: Dictionary = main.interact.candidate_of(thing(main, NOTICEBOARD), 0)
	main.interaction._act(board, 0)
	assert_eq(sent.map(func(c): return c["type"]), ["Use"], "at the board: the Use alone")
	assert_eq(main.stack.top(), main.hud, "no overlay before the core says so")
	assert_true(until(main, func(): return main.stack.top() is PanelScreen, 5), "the overlay opens once reading")
	assert_eq(main.player.view.get("using", {}).get("capability"), "read", "and the core has it reading")
	var s: PanelScreen = main.stack.top()
	assert_true(s.reading and "v0.0.3" in s.text(), "the notices, read: " + s.text())
	# The reading ends (here by StopUsing, as stepping away would): the
	# overlay goes with it.
	main.player.stop_using()
	assert_true(until(main, func(): return main.stack.top() == main.hud, 5), "the overlay closes when the reading ends")
	# Refused: nothing opens.
	recorder.unknown = true
	main.interaction._act(main.interact.candidate_of(thing(main, NOTICEBOARD), 0), 0)
	for i in 5:
		tick(main)
	assert_eq(sent[-1]["type"], "Use", "the Use was sent")
	assert_eq(main.stack.top(), main.hud, "a refused read opens nothing")
	assert_eq(main.interaction._awaited_read, {}, "and waits for nothing")
	# Read again while reading: the overlay opens with nothing sent.
	recorder.unknown = false
	main.interaction._act(main.interact.candidate_of(thing(main, NOTICEBOARD), 0), 0)
	assert_true(until(main, func(): return main.stack.top() is PanelScreen, 5), "reading again")
	main.stack.back()
	frames(main, 0.05)
	sent.clear()
	var reading: Dictionary = main.interaction.current_target()
	assert_eq(main.interact.verbs(reading), ["Stop reading", "Read", "Inspect"], "reading, B left the overlay, not the reading")
	main.interaction._act(reading, 1)
	assert_eq(sent, [], "Read reopens the overlay with nothing sent")
	assert_true(main.stack.top() is PanelScreen, "and it opens at once")
	main.free()


## A display's surface far away shows its chip; within 8 m its headlines,
## the first three items; open, the overlay shows everything. In 3D the
## text stands on the board's drawn face, by its display anchor, facing
## out; pixel art draws only a compact label, "Sample" and the title, and
## only for the display in focus (its resolution's deviation from "within
## 8 m: headlines"; the overlay carries them), in its pixel font at a
## whole-number scale of its grid.
func test_a_surface_is_a_chip_far_headlines_near_and_everything_open() -> void:
	var main = booted("lowpoly_tropical")
	arrive(main)
	var s: Dictionary = main.host.pack.surfaces[NOTICEBOARD]
	var facing := deg_to_rad(float(s["facing"]))
	var normal := Vector2(sin(facing), -cos(facing))
	var panel: Dictionary = s["panel"]
	assert_eq(panel.get("type"), "Notices", "the board's panel")
	var headlines: Array = Surfaces.headlines(panel)
	for style in ["lowpoly_tropical", "pixel_art"]:
		if style != "lowpoly_tropical":
			main._activate("res://styles/" + style)
			s = main.host.pack.surfaces[NOTICEBOARD]
		# 20 m out in front: the chip.
		main.host.update_surfaces(s["pos"] + normal * 2000.0, "")
		assert_eq(s["level"], Surfaces.FAR, style + ": 20 m is far")
		assert_eq(main.host.pack.surface_text(NOTICEBOARD), "Noticeboard · Sample", style + ": the chip")
		# 6 m: the headlines, the first three, and nothing more.
		main.host.update_surfaces(s["pos"] + normal * 600.0, "")
		assert_eq(s["level"], Surfaces.NEAR, style + ": 6 m is near")
		var near: String = main.host.pack.surface_text(NOTICEBOARD)
		assert_eq(near.split("\n"), PackedStringArray(["Sample", str(panel["title"])] + headlines.slice(0, 3)), style + ": the headlines")
		for item in panel["items"]:
			assert_true(not str(item["body"]) in near, style + ": no body near")
		var drawn := text_drawn(s["node"])
		if style == "lowpoly_tropical":
			assert_eq(drawn, near, style + ": drawn")
		else:
			# Pixel art has no room for headlines in the world (the overlay
			# and the List tab carry them): near but no one's focus, the
			# chip; the board targeted, a compact label, "Sample" and the
			# title (test_things_to_use.gd).
			assert_eq(drawn, "Noticeboard · Sample", style + ": drawn near, not the focus: the chip")
			main.host.update_surfaces(s["pos"] + normal * 600.0, "", NOTICEBOARD)
			assert_eq(text_drawn(s["node"]), "Sample\n" + str(panel["title"]), style + ": drawn as the focus: Sample and the title")
		# Open: the overlay, with everything.
		main.interaction._open_panel(main.interact.candidate_of(thing(main, NOTICEBOARD), 0), true)
		frames(main, 0.05)
		assert_eq(s["level"], Surfaces.OPEN, style + ": open while its overlay is")
		var overlay: PanelScreen = main.stack.top()
		for item in panel["items"]:
			assert_true(str(item["body"]) in overlay.text(), style + ": the overlay has every body")
		for line in near.split("\n"):
			assert_true(line in overlay.text(), style + ": the surface says nothing the overlay lacks: " + line)
		main.stack.back()
		if style == "lowpoly_tropical":
			var label: Label3D = s["node"]
			var out := label.global_transform.basis.z
			assert_true(Vector2(out.x, out.z).normalized().dot(normal) > 0.99, "3D: the text faces out of the board")
			# On the board's drawn face (its kit piece's `display` node),
			# which the fit leaves within a few centimetres of the anchor.
			var face = main.host.pack.display_face(NOTICEBOARD)
			assert_true(face is Transform3D, "3D: the kit's noticeboard draws its face")
			var mount := Vector2(face.origin.x, face.origin.z) + normal * Pack3D.SURFACE_LIFT_M
			assert_true(Vector2(label.position.x, label.position.z).distance_to(mount) < 0.01, "3D: on its drawn face")
			assert_true(mount.distance_to(s["pos"] / 100.0) < 0.1, "3D: by its display anchor")
		else:
			var text: Label = s["node"].get_node("Text")
			var ui: Dictionary = style_json(style)["ui"]
			# The style's pixel font (its display face) on its own grid.
			assert_eq(text.get_theme_font_size("font_size") % int(ui["pixel_base"]), 0, "pixel art: a whole-number scale of the grid")
			assert_eq(text.get_theme_font("font").resource_path, str(ui["font_display"]), "pixel art: the pixel font")
	# Through play: the player within 8 m of the board sees its headlines.
	walk_to(main, stand_of(main, NOTICEBOARD))
	frames(main, 0.05)
	assert_eq(main.host.pack.surfaces[NOTICEBOARD]["level"], Surfaces.NEAR, "the player at the board: near")
	# In pixel art the board the player stands at is the focus: its label.
	assert_eq(main.host.pack.surface_focus, NOTICEBOARD, "pixel art: the board the player is at is the focus")
	assert_eq(text_drawn(main.host.pack.surfaces[NOTICEBOARD]["node"]), "Sample\n" + str(panel["title"]), "pixel art: its label through play")
	main.free()


func text_drawn(node: Node) -> String:
	if node is Label3D:
		return node.text
	return node.get_node("Text").text


## Someone reading shows it on their name tag.
func test_the_name_tag_says_what_someone_is_using() -> void:
	var pack := StylePack.new()
	pack.views["o:1"] = {"id": "o:1", "display_name": "Asha", "using": {"target": NOTICEBOARD, "capability": "read", "anchor": 0}}
	pack.views["o:2"] = {"id": "o:2", "display_name": "Ravi", "using": {"target": "placement:square-fountain", "capability": "sit", "anchor": 1}}
	pack.views["o:3"] = {"id": "o:3", "display_name": "Mira"}
	pack.views["o:4"] = {"id": "o:4", "display_name": "Kai", "using": {"target": "seat:w1", "capability": "use", "anchor": 1}}
	pack.views["o:5"] = {"id": "o:5", "display_name": "Lyra", "using": {"target": "seat:w2", "capability": "sit", "anchor": 0}}
	assert_eq(pack.label_text("o:1"), "Asha · reading", "reading")
	assert_eq(pack.label_text("o:2"), "Ravi · sitting", "sitting")
	assert_eq(pack.label_text("o:3"), "Mira", "nothing used")
	# Nothing more of a workstation than that it is in use.
	assert_eq(pack.label_text("o:4"), "Kai · at a workstation", "using a workstation")
	assert_eq(pack.label_text("o:5"), "Lyra · sitting", "sitting at one")
	pack.free()


# ---- The text layer ----

## The List tab lists each place's displays under it, as text; choosing
## one reads it over the map, and B goes back to the map.
func test_the_map_list_reads_the_displays_as_text() -> void:
	var main = booted("fake_pack")
	arrive(main)
	main.open_map()
	var map: MapScreen = main._map
	map.set_tab("list")
	var row: Button = map.find_child(MapScreen.node_name("Row_", NOTICEBOARD), true, false)
	assert_true(row != null, "the noticeboard has a row")
	if row == null:
		main.free()
		return
	assert_eq(row.text, "Noticeboard   ·   %s   ·   Sample" % main.interaction.panel_of(NOTICEBOARD)["title"], "its row: name, title, Sample")
	var unbound: Button = map.find_child(MapScreen.node_name("Row_", UNBOUND_SHELF), true, false)
	assert_true(unbound != null and PanelScreen.NOTHING_TO_READ in unbound.text and not "Sample" in unbound.text, "an unbound shelf says so")
	var rows: Array = map.model.list_rows()
	var index := rows.find(map.model.things[NOTICEBOARD])
	var place: Dictionary = map.model.place(NOTICEBOARD)
	assert_true(index > 0 and rows.slice(0, index).any(func(r): return r["id"] == place["id"]), "listed under its place, " + str(place.get("name")))
	# Down the list to it, and A reads it.
	map.select(place["id"])
	for i in index - rows.find(place):
		send(map, pad(JOY_BUTTON_DPAD_DOWN))
	assert_eq(map.model.selected, NOTICEBOARD, "the d-pad reaches its row")
	send(map, pad(JOY_BUTTON_A))
	assert_true(main.stack.top() is PanelScreen, "A reads it")
	var s: PanelScreen = main.stack.top()
	assert_true(s.reading and "v0.0.3" in s.text() and "Sample" in s.text(), "its notices: " + s.text())
	send(s, pad(JOY_BUTTON_B))
	assert_eq(main.stack.top(), map, "B goes back to the map")
	main.free()
