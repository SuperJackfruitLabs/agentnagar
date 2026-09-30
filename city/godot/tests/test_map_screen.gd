## The map screen: pins, labels, the legend, the list and its search, the
## card with Go, zoom and pan, and every control by keyboard and by
## controller; the base picture it asks for, what it does when none comes,
## and the main view it covers.
extends TestSuite

func screen(size := Vector2(1920, 1080)) -> MapScreen:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack", "--as=none"]), "res://tests/fixtures")
	var s := MapScreen.new()
	s.model = MapModel.from_layout(main.manifest)
	s.host = main.host
	s.glyphs = main.glyphs
	s.theme_map = MapTheme.from_style({})
	main.stack.push(s)
	# A screen fills its window; this one is the size asked for instead,
	# whatever the test run's window is.
	s.set_anchors_preset(Control.PRESET_TOP_LEFT)
	s.size = size
	s.set_meta("main", main)
	return s


func done(s: MapScreen) -> void:
	s.get_meta("main").free()


## The node a place's pin or label is found by: a node name cannot hold the
## colon of an ID, so the screen names it as Godot would.
func node(s: MapScreen, prefix: String, id: String) -> Node:
	return s.find_child(MapScreen.node_name(prefix, id), true, false)


func key(code: int, unicode := 0) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.unicode = unicode
	e.pressed = true
	return e


func pad(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e


func axis(which: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = which
	e.axis_value = value
	return e


## Sends `event` through the window, as a player's press arrives.
func send(s: MapScreen, event: InputEvent) -> void:
	s.get_viewport().push_input(event)


## A host whose pack never answers: it counts the pictures asked for.
class SilentHost extends StyleHost:
	var asked := 0
	func request_map(_extent_m: Rect2, _size_px: Vector2i) -> void:
		asked += 1


func test_pins_for_categories_and_labels_for_all_places() -> void:
	var s := screen()
	s.open()
	for id in ["facility:guild-hall", "facility:library", "facility:tram-stop", "facility:park"]:
		assert_true(node(s, "Pin_", id) != null, "pin " + id)
	assert_true(node(s, "Pin_", "facility:square") == null, "no pin without a category")
	assert_true(node(s, "Label_", "facility:square") != null, "but a label")
	done(s)


## Map spec success 2: from the street view, by keyboard alone and by
## controller alone, the map opens, the Workshop is selected and Go starts
## there in at most five presses, each a real press through the window. A
## spectator standing over the tram stop: the first arrow starts from where
## the view is.
func test_the_mobile_task_in_five_presses() -> void:
	for device in ["keys", "pad"]:
		var main = load("res://main.gd").new()
		runner.root.add_child(main)
		main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack", "--as=none"]), "res://tests/fixtures")
		var tram: Vector2 = MapModel.from_layout(main.manifest).place("facility:tram-stop")["centre"]
		main.host.pack.ground = tram * 100.0
		var flights := []
		main.host.pack.set_meta("fly_log", flights)
		var viewport: Viewport = main.get_viewport()
		var presses: Array = [key(KEY_M), key(KEY_UP), key(KEY_LEFT), key(KEY_ENTER)] if device == "keys" \
			else [pad(JOY_BUTTON_LEFT_STICK), pad(JOY_BUTTON_DPAD_UP), pad(JOY_BUTTON_DPAD_LEFT), pad(JOY_BUTTON_A)]
		assert_true(presses.size() <= 5, "at most five presses")
		for e in presses:
			viewport.push_input(e)
			var up = e.duplicate()
			up.set("pressed", false)
			viewport.push_input(up)
		assert_eq(flights.size(), 1, device + ": Go was chosen")
		var workshop: Vector2 = MapModel.from_layout(main.manifest).place("facility:guild-hall")["centre"]
		if flights.size() == 1:
			assert_eq(flights[0][0], workshop * 100.0, device + ": to the Workshop")
		assert_eq(main.stack.top(), main.hud, device + ": the map closed on Go")
		main.free()


func test_search_with_no_match_shows_so_and_enter_does_nothing() -> void:
	var s := screen()
	s.open()
	s.set_tab("list")
	s.set_query("zzz")
	assert_true(s.find_child("NoMatch", true, false).visible, "No places match")
	var goes := []
	s.go.connect(func(id): goes.append(id))
	s.press_go()
	assert_eq(goes, [], "nothing to go to")
	done(s)


## An unknown place is told on the map itself, over the map, where the
## HUD's notices (under the map's backdrop) would not show; it goes after
## a few seconds.
func test_an_unknown_place_opens_with_a_notice() -> void:
	var s := screen()
	s.open("facility:nowhere")
	assert_eq(s.model.selected, "", "nothing selected")
	var chip: Control = s.find_child("NoticeChip", true, false)
	assert_true(chip != null, "a notice on the map")
	if chip == null:
		done(s)
		return
	assert_true(chip.is_visible_in_tree(), "shown")
	assert_true("No place called facility:nowhere" in (chip.find_child("Notice", true, false) as Label).text, "saying so")
	var area: Control = s.find_child("MapArea", true, false)
	assert_true(area.get_global_rect().encloses(chip.get_global_rect()), "over the map")
	assert_true(chip.get_index() > area.get_index() and chip.get_index() > s.find_child("Backdrop", true, false).get_index(),
		"drawn over the map and its backdrop")
	s.tick(2.0)
	assert_true(chip.is_visible_in_tree(), "still up after two seconds")
	s.tick(MapScreen.NOTICE_S)
	assert_true(not chip.is_visible_in_tree(), "gone after a few")
	done(s)


func test_the_card_counts_people_inside() -> void:
	var s := screen()
	s.projection = {"rooms": [{"id": "room:reading", "occupants": [{"id": "a"}, {"id": "b"}], "waiting": []}]}
	s.open("facility:library")
	assert_true("2 people inside" in s.find_child("Card", true, false).get_meta("summary"), "count shown")
	done(s)


func test_base_size_is_twice_the_fit_and_capped() -> void:
	assert_eq(MapScreen.size_px_for(Vector2(1920, 1080)).x <= 4096, true, "capped")
	assert_true(MapScreen.size_px_for(Vector2(800, 600)).x >= 1200, "twice a small window")


func test_narrow_layout_keeps_labels_apart() -> void:
	var s := screen(Vector2(800, 900))
	s.open()
	var rects := []
	var base: Control = s.find_child("Base", true, false)
	var pins := []
	for p in s.find_children("Pin_*", "", true, false):
		if p.visible:
			pins.append(p.get_global_rect())
	for c in s.find_children("Label_*", "", true, false):
		if c.visible:
			rects.append(c.get_global_rect())
			assert_true(base.get_global_rect().grow(0.5).encloses(c.get_global_rect()), "%s inside the base" % c.name)
			for r in pins:
				assert_true(not c.get_global_rect().intersects(r), "%s clear of the pin at %s" % [c.name, r])
	assert_true(rects.size() >= 4, "labels shown")
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			assert_true(not rects[i].intersects(rects[j]), "labels apart")
	done(s)


# ---- Beyond the brief's seven ----

func test_the_base_size_keeps_its_aspect_and_its_cap() -> void:
	assert_eq(MapScreen.size_px_for(Vector2(1000, 500)), Vector2i(2000, 1000), "twice")
	assert_eq(MapScreen.size_px_for(Vector2(3000, 1500)), Vector2i(4096, 2048), "long side capped, aspect kept")
	assert_eq(MapScreen.size_px_for(Vector2(1000, 3000)), Vector2i(1365, 4096), "tall too")


func test_the_map_is_narrow_below_900_and_the_card_goes_to_the_bottom() -> void:
	var wide := screen()
	wide.open("facility:library")
	var card: Control = wide.find_child("Card", true, false)
	assert_true(card.visible, "card shown when selected")
	assert_true(card.position.x > wide.size.x / 2.0, "at the right")
	done(wide)
	var tall := screen(Vector2(800, 900))
	tall.open("facility:library")
	card = tall.find_child("Card", true, false)
	assert_true(tall.narrow, "narrow")
	assert_true(card.position.y > tall.size.y / 2.0, "at the bottom")
	assert_true(Rect2(Vector2.ZERO, tall.size).encloses(card.get_rect()), "inside the window")
	var area: Control = tall.find_child("MapArea", true, false)
	assert_true(not area.get_global_rect().intersects(card.get_global_rect()), "clear of the map")
	done(tall)


func test_the_card_is_hidden_without_a_selection_and_names_its_rooms() -> void:
	var s := screen()
	s.open()
	var card: Control = s.find_child("Card", true, false)
	assert_true(not card.visible, "hidden")
	s.select("facility:guild-hall")
	assert_true(card.visible, "shown")
	var summary: String = card.get_meta("summary")
	assert_true("Rooms: Workshop, Commons" in summary, "rooms joined: " + summary)
	assert_true("Workshop" in summary, "category word")
	assert_true("0 people inside" in summary, "nobody inside")
	done(s)


func test_pins_are_pin_px_at_zoom_one_and_sit_on_their_place() -> void:
	var s := screen()
	s.open()
	var pin: Control = node(s, "Pin_", "facility:library")
	assert_eq(pin.size, Vector2.ONE * MapModel.PIN_PX, "40 px")
	var base: Control = s.find_child("Base", true, false)
	var at: Vector2 = s.model.to_map(s.model.place("facility:library")["centre"], base.size)
	var centre := pin.get_global_rect().get_center()
	assert_true(centre.distance_to(base.get_global_rect().position + at) < 1.0, "on the library")
	done(s)


func test_the_legend_filters_pins_and_labels() -> void:
	var s := screen()
	s.open()
	var legend: Control = s.find_child("Legend", true, false)
	assert_eq(legend.get_children().filter(func(c): return c is Button).map(func(c): return str(c.name)),
		["workshop", "library", "transit", "park"], "four entries")
	(legend.get_node("library") as Button).pressed.emit()
	assert_eq(s.model.filter, "library", "filtered")
	assert_true(not node(s, "Pin_", "facility:park").visible, "park pin hidden")
	assert_true(not node(s, "Label_", "facility:park").visible, "park label hidden")
	assert_true(node(s, "Pin_", "facility:library").visible, "library pin shown")
	(legend.get_node("library") as Button).pressed.emit()
	assert_eq(s.model.filter, "", "again clears")
	assert_true(node(s, "Pin_", "facility:park").visible, "park back")
	done(s)


func test_keys_select_go_filter_zoom_switch_and_close() -> void:
	var s := screen()
	var main = s.get_meta("main")
	s.you = s.model.place("facility:tram-stop")["centre"]
	s.open()
	var goes := []
	s.go.connect(func(id): goes.append(id))
	send(s, key(KEY_UP))
	send(s, key(KEY_LEFT))
	assert_eq(s.model.selected, "facility:guild-hall", "arrows")
	send(s, key(KEY_ENTER))
	assert_eq(goes, ["facility:guild-hall"], "Enter goes")
	send(s, key(KEY_3))
	assert_eq(s.model.filter, "transit", "3 filters transit")
	send(s, key(KEY_3))
	assert_eq(s.model.filter, "", "again clears")
	for i in 6:
		send(s, key(KEY_EQUAL))
	assert_eq(s.zoom, 2.0, "zoom clamped at 2")
	for i in 6:
		send(s, key(KEY_MINUS))
	assert_eq(s.zoom, 1.0, "and at 1")
	send(s, key(KEY_TAB))
	assert_eq(s.tab, "list", "Tab to the list")
	send(s, key(KEY_DOWN))
	assert_eq(s.model.selected, s.model.visible_places()[s.model.visible_places().find(s.model.place("facility:guild-hall")) + 1]["id"], "down a row")
	send(s, key(KEY_TAB))
	assert_eq(s.tab, "map", "and back")
	send(s, key(KEY_M))
	assert_eq(main.stack.top(), main.hud, "M closes")
	done(s)


func test_typing_on_the_list_searches() -> void:
	var s := screen()
	s.open()
	send(s, key(KEY_TAB))
	for c in "lib":
		send(s, key(OS.find_keycode_from_string(c.to_upper()), c.unicode_at(0)))
	# A line edit tells of a change once the frame's typing is done.
	await runner.process_frame
	assert_eq(s.model.query, "lib", "typed")
	var rows: Control = s.find_child("Rows", true, false)
	assert_eq(rows.get_children().filter(func(r): return r.visible).size(), 1, "one row")
	send(s, key(KEY_DOWN))
	assert_eq(s.model.selected, "facility:library", "down selects it")
	var goes := []
	s.go.connect(func(id): goes.append(id))
	send(s, key(KEY_ENTER))
	assert_eq(goes, ["facility:library"], "Enter goes from the list")
	done(s)


func test_a_controller_does_it_all() -> void:
	var s := screen()
	var main = s.get_meta("main")
	s.you = s.model.place("facility:tram-stop")["centre"]
	s.open()
	var goes := []
	s.go.connect(func(id): goes.append(id))
	send(s, pad(JOY_BUTTON_DPAD_UP))
	send(s, pad(JOY_BUTTON_DPAD_LEFT))
	assert_eq(s.model.selected, "facility:guild-hall", "d-pad")
	send(s, pad(JOY_BUTTON_A))
	assert_eq(goes, ["facility:guild-hall"], "A goes")
	send(s, pad(JOY_BUTTON_X))
	assert_eq(s.model.filter, "workshop", "X cycles")
	send(s, pad(JOY_BUTTON_X))
	assert_eq(s.model.filter, "library", "and on")
	for i in 3:
		send(s, pad(JOY_BUTTON_X))
	assert_eq(s.model.filter, "", "round to all")
	send(s, axis(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	s.tick(5.0)
	send(s, axis(JOY_AXIS_TRIGGER_RIGHT, 0.0))
	assert_eq(s.zoom, 2.0, "RT zooms in, to 2")
	send(s, axis(JOY_AXIS_LEFT_X, 1.0))
	s.tick(10.0)
	send(s, axis(JOY_AXIS_LEFT_X, 0.0))
	var base: Control = s.find_child("Base", true, false)
	assert_true(s.pan.x < 0.0, "the stick pans east")
	assert_true(absf(s.pan.x) <= base.size.x / 2.0 * (s.zoom - 1.0) / s.zoom + 0.01, "clamped to the base")
	send(s, axis(JOY_AXIS_TRIGGER_LEFT, 1.0))
	s.tick(5.0)
	send(s, axis(JOY_AXIS_TRIGGER_LEFT, 0.0))
	assert_eq(s.zoom, 1.0, "LT zooms out, to 1")
	assert_eq(s.pan, Vector2.ZERO, "no pan at fit")
	send(s, pad(JOY_BUTTON_Y))
	assert_eq(s.tab, "list", "Y to the list")
	send(s, pad(JOY_BUTTON_DPAD_DOWN))
	send(s, pad(JOY_BUTTON_Y))
	assert_eq(s.tab, "map", "and back")
	send(s, pad(JOY_BUTTON_B))
	assert_eq(main.stack.top(), main.hud, "B closes")
	done(s)


func test_the_wheel_zooms_and_a_drag_pans() -> void:
	var s := screen()
	s.open()
	var base: Control = s.find_child("Base", true, false)
	var centre := base.get_global_rect().get_center()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = centre
	for i in 20:
		send(s, wheel)
	assert_eq(s.zoom, 2.0, "wheel in, clamped")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = centre
	send(s, press)
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.position = centre + Vector2(5000, 0)
	drag.relative = Vector2(5000, 0)
	send(s, drag)
	var release := press.duplicate()
	release.pressed = false
	release.position = drag.position
	send(s, release)
	assert_true(s.pan.x > 0.0, "dragged east")
	assert_true(s.pan.x <= base.size.x / 2.0 * (s.zoom - 1.0) / s.zoom + 0.01, "clamped")
	done(s)


func test_the_overlay_covers_the_view_and_3d_stops_while_open() -> void:
	var viewport: Viewport = runner.root
	viewport.disable_3d = false
	var s := screen()
	s.open()
	var backdrop: ColorRect = s.find_child("Backdrop", true, false)
	assert_true(backdrop.visible and backdrop.color.a == 1.0, "opaque")
	assert_true(backdrop.get_global_rect().encloses(Rect2(Vector2.ZERO, s.size)), "the whole screen")
	assert_eq(backdrop.color, s.theme_map.letterbox, "in the letterbox colour")
	assert_true(viewport.disable_3d, "no 3D drawn under the map")
	var main = s.get_meta("main")
	main.stack.back()
	assert_true(not viewport.disable_3d, "restored on close")
	main.free()
	# A view that had 3D off keeps it off.
	viewport.disable_3d = true
	s = screen()
	main = s.get_meta("main")
	s.open()
	main.stack.back()
	assert_true(viewport.disable_3d, "restored exactly")
	viewport.disable_3d = false
	main.free()


func test_the_base_arrives_from_the_pack() -> void:
	var s := screen()
	s.open()
	var base: TextureRect = s.find_child("Base", true, false)
	await runner.process_frame
	assert_true(base.texture != null, "a picture")
	assert_eq(Vector2i(base.texture.get_size()), s.base_asked, "of the size asked")
	assert_eq(s.base_asked, MapScreen.size_px_for(base.size / s.zoom), "twice the fit")
	done(s)


func test_an_unanswered_base_is_asked_again_once() -> void:
	var s := screen()
	var main = s.get_meta("main")
	var silent := SilentHost.new()
	silent.pack_dir = main.host.pack_dir
	main.add_child(silent)
	s.host = silent
	s.open()
	assert_eq(silent.asked, 1, "asked")
	s.tick(1.0)
	assert_eq(silent.asked, 1, "waits")
	s.tick(1.5)
	assert_eq(silent.asked, 2, "asked again after 2 s")
	s.tick(10.0)
	assert_eq(silent.asked, 2, "but only once")
	var base: TextureRect = s.find_child("Base", true, false)
	assert_true(base.texture == null, "the letterbox shows meanwhile")
	silent.pack_dir = "res://styles/elsewhere"
	s.apply_theme(s.ui)
	assert_eq(silent.asked, 3, "a style change asks again")
	done(s)


func test_a_style_change_rereads_the_map_theme() -> void:
	var s := screen()
	s.open()
	s.host.pack.style["map"] = {"letterbox": "#101820", "pin": "square", "scale_bar": true}
	s.apply_theme(s.ui)
	assert_eq(s.theme_map.pin, "square", "re-read")
	assert_eq((s.find_child("Backdrop", true, false) as ColorRect).color, Color("#101820"), "letterbox")
	assert_true(s.find_child("ScaleBar", true, false).visible, "the style asks for a scale bar")
	s.host.pack.style.erase("map")
	done(s)


func test_you_are_here_follows_and_turns() -> void:
	var s := screen()
	s.you = s.model.place("facility:park")["centre"]
	s.you_facing = Vector2.RIGHT
	s.open()
	s.tick(0.0)
	var marker: Control = s.find_child("You", true, false)
	var base: Control = s.find_child("Base", true, false)
	var at: Vector2 = base.position + s.model.to_map(s.you, base.size)
	assert_true(marker.visible, "shown")
	assert_true((marker.position + marker.pivot_offset).distance_to(at) < 1.0, "at you, turning about its middle")
	assert_true(is_equal_approx(marker.rotation, PI / 2.0), "facing east")
	s.tick(0.5)
	assert_true(marker.scale.x > 1.0 and marker.scale.x <= 1.15, "pulses")
	s.you = null
	s.tick(0.0)
	assert_true(not marker.visible, "no one to show")
	done(s)


func test_the_compass_and_no_scale_bar_by_default() -> void:
	var s := screen()
	s.open()
	var compass: Control = s.find_child("Compass", true, false)
	var base: Control = s.find_child("Base", true, false)
	assert_true(compass.visible, "compass")
	assert_true(compass.get_global_rect().get_center().x > base.get_global_rect().get_center().x, "on the right")
	assert_true(compass.get_global_rect().get_center().y < base.get_global_rect().get_center().y, "at the top")
	var bar = s.find_child("ScaleBar", true, false)
	assert_true(bar == null or not bar.visible, "no scale bar")
	done(s)


func test_map_theme_defaults_and_overrides() -> void:
	var d := MapTheme.from_style({})
	assert_eq([d.minutes, d.letterbox, d.pin, d.scale_bar, d.glow, d.exposure], [720, Color("#F4F1EA"), "badge", false, false, 1.0], "defaults")
	assert_eq([d.plate_fill, d.plate_ink, d.plate_case, d.plate_radius], [Color("#FFFFFF"), Color("#2B2B33"), "upper", 4], "plate")
	var n := MapTheme.from_style({"map": {"minutes": 1260, "pin": "drop", "plate": {"fill": "#0E1A2E"}, "glow": true}})
	assert_eq([n.minutes, n.pin, n.plate_fill, n.plate_ink, n.glow], [1260, "drop", Color("#0E1A2E"), Color("#2B2B33"), true], "merged")
	assert_eq(MapTheme.from_style({"map": {"pin": "star"}}).pin, "badge", "an unknown pin is a badge")
	assert_eq(d.plate_text("Tree square"), "TREE SQUARE", "upper")
	assert_eq(MapTheme.from_style({"map": {"plate": {"case": "title"}}}).plate_text("tree square"), "Tree Square", "title")


func test_a_selected_row_keeps_its_category_colour() -> void:
	var s := screen()
	s.open()
	s.set_tab("list")
	s.select("facility:library")
	var colour: Color = MapModel.COLOURS["library"]
	for id in ["facility:library", "facility:park"]:
		var row: Button = node(s, "Row_", id)
		var mark: TextureRect = row.find_child("Icon", true, false)
		var category: String = s.model.place(id)["category"]
		assert_true(mark != null and mark.texture != null, id + ": an icon")
		assert_eq(mark.self_modulate, MapModel.COLOURS[category], id + ": in its category's colour")
		var plate: PanelContainer = row.find_child("IconPlate", true, false)
		var box := plate.get_theme_stylebox("panel") as StyleBoxFlat
		assert_eq(box.bg_color, s.ui.colour("panel"), id + ": on a plate of the panel colour, whatever the row's")
	assert_true((node(s, "Row_", "facility:library") as Button).button_pressed, "the library's row is marked")
	assert_eq((node(s, "Row_", "facility:library").find_child("Icon", true, false) as TextureRect).self_modulate, colour,
		"its icon is still the library's colour")
	done(s)


func test_a_rebound_zoom_key_zooms_the_map() -> void:
	# Zoom in and out are triggers by default, which the map reads as held
	# axes; a player may also give them a key or a button (Settings,
	# Controls), and the map answers to that too.
	var s := screen()
	# Booting puts the project's own bindings back, so these go on after.
	var z := key(KEY_Z)
	var x := key(KEY_X)
	InputMap.action_add_event("zoom_in", z)
	InputMap.action_add_event("zoom_out", x)
	s.open()
	s.set_zoom(1.0)
	send(s, key(KEY_Z))
	assert_eq(s.zoom, 1.0 + MapScreen.ZOOM_STEP, "a rebound zoom-in key zooms in")
	send(s, key(KEY_X))
	assert_eq(s.zoom, 1.0, "and the zoom-out key out")
	InputMap.action_erase_event("zoom_in", z)
	InputMap.action_erase_event("zoom_out", x)
	done(s)


# ---- The styles' own map blocks, and what the captures showed ----

const STYLES := ["anime_cel", "solarpunk", "neon_noir", "pixel_art", "lowpoly_tropical", "voxel"]


func style_json(style: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://styles/%s/style.json" % style))


## Each style's map block, as its sheet's MAP panel draws the map: [minutes,
## letterbox, pin, plate fill, plate ink, plate case, scale bar, glow].
func test_every_style_has_its_map_block() -> void:
	var want := {
		"anime_cel": [720, "#F4F6FA", "badge", "#FFFFFF", "#1E2A44", "title", false, false],
		"solarpunk": [720, "#EFE8D6", "drop", "#FFFFFF", "#123C3A", "upper", false, false],
		"neon_noir": [1260, "#0B1220", "drop", "#0E1A2E", "#E6F1FF", "upper", true, true],
		"pixel_art": [720, "#141B33", "square", "#141B33", "#E8ECFF", "upper", false, false],
		"lowpoly_tropical": [720, "#F6EBD2", "badge", "#FFF8EA", "#2E2A24", "upper", false, false],
		"voxel": [720, "#DDE8F2", "badge", "#FFFFFF", "#1F2433", "upper", false, false],
	}
	for style in STYLES:
		var json := style_json(style)
		assert_true(json.has("map"), style + " has a map block")
		var t := MapTheme.from_style(json)
		var w: Array = want[style]
		assert_eq([t.minutes, t.letterbox, t.pin, t.plate_fill, t.plate_ink, t.plate_case, t.scale_bar, t.glow],
			[w[0], Color(w[1]), w[2], Color(w[3]), Color(w[4]), w[5], w[6], w[7]], style)
		# Neon's lit night is drawn brighter than its world, as its sheet's
		# map reads; the others at their world's own exposure.
		assert_eq(t.exposure, 2.2 if style == "neon_noir" else 1.0, style + ": exposure")


func test_every_style_s_plates_are_readable() -> void:
	for style in STYLES:
		var t := MapTheme.from_style(style_json(style))
		var ratio := UiTheme.contrast(t.plate_ink, t.plate_fill)
		assert_true(ratio >= 4.5, "%s: plate ink on plate fill %.2f:1, at least 4.5:1" % [style, ratio])


## A drop pin marks its place with its point: the tip, at the pin's foot,
## is on the place, and the labels keep clear of the pin above it.
func test_a_drop_pin_s_point_is_on_its_place() -> void:
	var s := screen()
	s.host.pack.style["map"] = {"pin": "drop"}
	s.apply_theme(s.ui)
	s.open()
	var base: Control = s.find_child("Base", true, false)
	var pins := []
	for id in ["facility:library", "facility:park", "facility:guild-hall", "facility:tram-stop"]:
		var pin: Control = node(s, "Pin_", id)
		var at: Vector2 = base.get_global_rect().position + s.model.to_map(s.model.place(id)["centre"], base.size)
		var tip := pin.get_global_rect().position + Vector2(pin.size.x / 2.0, pin.size.y)
		assert_true(tip.distance_to(at) < 1.0, "%s: the tip %s on the place %s" % [id, tip, at])
		pins.append(pin.get_global_rect())
	for c in s.find_children("Label_*", "", true, false):
		if not c.visible:
			continue
		for r in pins:
			assert_true(not c.get_global_rect().intersects(r), "%s clear of the pin at %s" % [c.name, r])
	s.host.pack.style.erase("map")
	done(s)


## Pixel art's base is a plan of whole pixels: it is shown with nearest
## filtering, not smoothed; the other skins smooth theirs.
func test_a_pixel_skin_shows_its_base_unsmoothed() -> void:
	var s := screen()
	s.open()
	var base: TextureRect = s.find_child("Base", true, false)
	s.get_meta("main").stack.set_theme(UiTheme.from_style(style_json("pixel_art")))
	assert_eq(base.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "pixel art: nearest")
	s.get_meta("main").stack.set_theme(UiTheme.from_style(style_json("anime_cel")))
	assert_eq(base.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "anime: smoothed")
	done(s)


## The List tab shows several rows in every skin at 1280 x 720 and at
## 800 x 900, and the selected row, the last, scrolls wholly into view
## when the List tab opens on it.
func test_the_list_shows_several_rows_and_the_selected_one_whole() -> void:
	for style in STYLES:
		for size in [Vector2(1280, 720), Vector2(800, 900)]:
			var s := screen(size)
			s.get_meta("main").stack.set_theme(UiTheme.from_style(style_json(style)))
			# Selected on the Map tab, then the List: as --place and Tab do.
			var last: Dictionary = s.model.visible_places()[-1]
			s.open(last["id"])
			for f in 2:
				await runner.process_frame
			s.set_tab("list")
			for f in 3:
				await runner.process_frame
			var scroll: Control = s.find_child("RowsScroll", true, false)
			var view := scroll.get_global_rect().grow(0.5)
			var whole := 0
			for row in s.find_children("Row_*", "Button", true, false):
				if view.encloses(row.get_global_rect()):
					whole += 1
			var want := mini(4, s.model.visible_places().size())
			assert_true(whole >= want, "%s at %s: %d whole rows, at least %d" % [style, size, whole, want])
			var selected: Control = node(s, "Row_", last["id"])
			assert_true(view.encloses(selected.get_global_rect()), "%s at %s: the selected row wholly shown: %s in %s" % [style, size, selected.get_global_rect(), view])
			var card: Control = s.find_child("Card", true, false)
			assert_true(Rect2(s.get_global_rect()).grow(0.5).encloses(card.get_global_rect()), "%s at %s: the card inside the window" % [style, size])
			assert_true(not card.get_global_rect().intersects(s.find_child("ListPanel", true, false).get_global_rect()), "%s at %s: the card clear of the list" % [style, size])
			done(s)


# ---- The final review's fixes ----

## A projection lands every tick while the map is open. A click on a row
## is a press and a release: a projection between them must not take the
## row away, so the click selects its place, and the row's count follows
## the projection in place.
func test_a_click_on_a_row_survives_a_projection() -> void:
	var s := screen()
	s.open()
	s.set_tab("list")
	for f in 2:
		await runner.process_frame
	var row: Button = node(s, "Row_", "facility:library")
	var at := row.get_global_rect().get_center()
	# The pointer comes over the row first, as a player's does (the test
	# window is too small to hover it by a motion event, so the row is told).
	row.notification(Control.NOTIFICATION_MOUSE_ENTER)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	press.global_position = at
	send(s, press)
	s.projection = {"rooms": [{"id": "room:reading", "occupants": [{"id": "a"}, {"id": "b"}], "waiting": []}]}
	var release := press.duplicate()
	release.pressed = false
	send(s, release)
	assert_eq(s.model.selected, "facility:library", "the click selected the library")
	assert_true(is_instance_valid(row) and node(s, "Row_", "facility:library") == row, "the same row")
	assert_true(is_instance_valid(row) and "2 inside" in row.text, "its count followed the projection")
	assert_true("2 people inside" in s.find_child("Card", true, false).get_meta("summary"), "and the card's")
	done(s)


## On the Map tab a projection leaves the List's rows alone.
func test_a_projection_on_the_map_tab_rebuilds_no_rows() -> void:
	var s := screen()
	s.open()
	s.set_tab("list")
	s.set_tab("map")
	var row: Button = node(s, "Row_", "facility:park")
	s.projection = {"rooms": []}
	assert_true(is_instance_valid(row) and node(s, "Row_", "facility:park") == row, "the rows kept")
	done(s)


## The search is the List tab's: the Map tab still shows every place the
## legend's filter lets through, and its arrows reach them.
func test_a_search_on_the_list_leaves_the_map_whole() -> void:
	var s := screen()
	s.open()
	s.set_tab("list")
	s.set_query("lib")
	assert_eq(s.find_children("Row_*", "Button", true, false).size(), 1, "the list searched")
	s.set_tab("map")
	for id in ["facility:park", "facility:guild-hall", "facility:tram-stop"]:
		assert_true(node(s, "Pin_", id).visible, id + ": pin shown")
		assert_true(node(s, "Label_", id).visible, id + ": label shown")
	s.select("facility:park")
	assert_eq(s.model.selected, "facility:park", "selectable")
	var goes := []
	s.go.connect(func(id): goes.append(id))
	s.press_go()
	assert_eq(goes, ["facility:park"], "and Go goes")
	done(s)


## Filtered to one category, the labels are laid out over the places
## shown, so a label the others crowded out comes back: pixel art at
## 800 x 900, filtered to Transit, names the tram stop.
func test_a_filter_lays_the_labels_out_again_for_the_places_shown() -> void:
	var s := screen(Vector2(800, 900))
	s.get_meta("main").stack.set_theme(UiTheme.from_style(style_json("pixel_art")))
	s.host.pack.style["map"] = style_json("pixel_art")["map"]
	s.apply_theme(s.ui)
	s.open()
	s.set_zoom(1.0)
	s.toggle_filter("transit")
	assert_true(node(s, "Label_", "facility:tram-stop").visible, "the tram stop is named")
	s.host.pack.style.erase("map")
	done(s)


## Watching, with no one to be, the first arrow starts from where the view
## is over the ground; a view with no ground point starts from the
## district's middle, not the Tree square's corner at (0, 0).
func test_a_spectator_s_first_arrow_starts_from_the_view() -> void:
	var s := screen()
	s.open()
	assert_eq(s.model.origin, s.model.extent.get_center(), "no view point: the middle")
	done(s)
	s = screen()
	var park: Vector2 = s.model.place("facility:park")["centre"]
	s.host.pack.ground = park * 100.0
	s.open()
	assert_eq(s.model.origin, park, "the view's ground point, in metres")
	done(s)


## The Map tab opens framed on the places the sheets name, filling most of
## the view, within the 1-2x zoom; zooming out shows the whole district.
func test_the_map_opens_framed_on_its_places() -> void:
	for size in [Vector2(1920, 1080), Vector2(800, 900)]:
		var s := screen(size)
		s.open()
		var view: Rect2 = s.find_child("MapArea", true, false).get_global_rect().grow(0.5)
		assert_true(s.zoom > 1.0, "%s: opened zoomed in (%.2f)" % [size, s.zoom])
		var base: Control = s.find_child("Base", true, false)
		var covered := Rect2()
		var compass: Rect2 = s.find_child("Compass", true, false).get_global_rect()
		for p in s.model.places:
			var footprint: Rect2 = p["footprint"]
			var r := Rect2(base.get_global_rect().position + s.model.to_map(footprint.position, base.size),
				footprint.size * base.size.x / s.model.extent.size.x)
			assert_true(view.encloses(r), "%s: %s inside the view" % [size, p["id"]])
			covered = r if covered.size == Vector2.ZERO else covered.merge(r)
			var label: Control = node(s, "Label_", p["id"])
			if label.visible:
				assert_true(view.encloses(label.get_global_rect()), "%s: %s's label inside the view" % [size, p["id"]])
				assert_true(not label.get_global_rect().intersects(compass), "%s: %s's label clear of the compass" % [size, p["id"]])
				covered = covered.merge(label.get_global_rect())
			var pin: Control = node(s, "Pin_", p["id"])
			if pin != null:
				assert_true(view.encloses(pin.get_global_rect()), "%s: %s's pin inside the view" % [size, p["id"]])
		var fill := maxf(covered.size.x / view.size.x, covered.size.y / view.size.y)
		assert_true(fill > 0.5 or is_equal_approx(s.zoom, MapScreen.ZOOM_MAX), "%s: the places fill most of the view (%.2f)" % [size, fill])
		s.set_zoom(1.0)
		assert_true(view.encloses(base.get_global_rect()), "%s: at 1x the whole district shows" % size)
		done(s)
	# With a place asked for, the same zoom, moved toward it as far as
	# keeps every place in view.
	var framed := screen()
	framed.open()
	var zoom := framed.zoom
	var base: Control = framed.find_child("Base", true, false)
	var middle: Vector2 = framed.find_child("MapArea", true, false).get_global_rect().get_center()
	var library: Vector2 = framed.model.place("facility:library")["centre"]
	var was := (base.get_global_rect().position + framed.model.to_map(library, base.size)).distance_to(middle)
	done(framed)
	var s := screen()
	s.open("facility:library")
	base = s.find_child("Base", true, false)
	var view: Rect2 = s.find_child("MapArea", true, false).get_global_rect().grow(0.5)
	var now := (base.get_global_rect().position + s.model.to_map(library, base.size)).distance_to(middle)
	assert_eq(s.zoom, zoom, "the same zoom")
	assert_true(now < was, "the library nearer the middle: %.1f px from it, %.1f unselected" % [now, was])
	for p in s.model.places:
		var label: Control = node(s, "Label_", p["id"])
		assert_true(not label.visible or view.encloses(label.get_global_rect()), p["id"] + ": every place still in view")
	done(s)


# ---- The tram (tram spec section 5) ----

## The route is drawn over the picture in the Transit colour, under the
## pins and labels, along the line's centreline.
func test_the_tram_route_is_drawn_in_the_transit_colour_under_the_pins() -> void:
	var s := screen()
	s.open()
	assert_eq(s.model.routes.size(), 1, "one route, the boulevard")
	var route_m: Dictionary = s.model.routes[0]
	assert_eq(route_m["id"], "line:boulevard", "the line")
	var line: Dictionary = CityGeometry.line_of(s.get_meta("main").manifest, "line:boulevard")
	assert_eq(route_m["points"].size(), line["points"].size(), "its centreline's points")
	var route = s.find_child("Route", true, false)
	assert_true(route != null, "a route layer")
	assert_eq(route.colour, MapModel.COLOURS["transit"], "in the Transit colour")
	var base: Control = s.find_child("Base", true, false)
	var pins: Control = s.find_child("Pins", true, false)
	var labels: Control = s.find_child("Labels", true, false)
	assert_true(route.get_index() > base.get_index() and route.get_index() < pins.get_index() and route.get_index() < labels.get_index(),
		"over the picture, under the pins and labels")
	assert_eq(route.position, base.position, "laid over the picture")
	assert_eq(route.size, base.size, "the picture's size")
	var drawn: Array = route.lines[0]
	for i in drawn.size():
		var want := s.model.to_map(CityGeometry.pt_m(line["points"][i]), base.size)
		assert_true((drawn[i] as Vector2).distance_to(want) < 0.01, "point %d where the line runs" % i)
	# Zoomed in, it follows the picture.
	s.set_zoom(2.0)
	assert_eq(route.size, base.size, "zoomed with the picture")
	done(s)


## Both stops are Transit places, with pins, from the Square's and the
## Avenue's stop facilities.
func test_both_tram_stops_are_transit_places_with_pins() -> void:
	var s := screen()
	s.open()
	for id in ["facility:tram-stop", "facility:avenue-stop"]:
		assert_eq(s.model.place(id).get("category"), "transit", id + " is a Transit place")
		assert_true(node(s, "Pin_", id) != null, id + " has a pin")
	done(s)


## A stop's card says when the next tram comes each way, from the
## timetable and the trams the viewer sees; no other place's card does.
func test_a_stops_card_shows_the_next_tram_each_way_and_no_other_card_does() -> void:
	var s := screen()
	s.projection = {"tick": 3, "rooms": [], "vehicles": [
		{"id": "vehicle:boulevard:east:1", "line": "line:boulevard", "direction": "east", "along": 725, "status": "running", "doors_open": false}]}
	s.open("facility:tram-stop")
	var card: Control = s.find_child("Card", true, false)
	var trams: Label = card.find_child("Trams", true, false)
	assert_true(trams != null and trams.visible, "the next-tram line shows")
	assert_true(RegEx.create_from_string("^East in \\d+ s · West in \\d+ s$").search(trams.text) != null, "each way: " + trams.text)
	assert_eq(trams.text, s.model.trams.card_line("line:boulevard", "stop:square"), "from the timetable and the trams seen")
	assert_true(trams.text.begins_with("East in 3 s"), "the tram on its way, 2100 cm off: " + trams.text)
	assert_true(trams.text in card.get_meta("summary"), "in the card's summary")
	var height := card.size.y
	s.select("facility:avenue-stop")
	assert_true(trams.visible and trams.text == s.model.trams.card_line("line:boulevard", "stop:avenue"), "the Avenue's too: " + trams.text)
	s.select("facility:library")
	assert_true(not trams.visible, "not on a library")
	assert_true(not ("East in" in card.get_meta("summary")), "nor in its summary")
	assert_eq(card.size.y, height, "the card keeps its size")
	# A projection a tick later counts down.
	s.select("facility:tram-stop")
	s.projection = {"tick": 4, "rooms": [], "vehicles": [
		{"id": "vehicle:boulevard:east:1", "line": "line:boulevard", "direction": "east", "along": 1425, "status": "running", "doors_open": false}]}
	assert_true(trams.text.begins_with("East in 2 s"), "a tick later: " + trams.text)
	done(s)
