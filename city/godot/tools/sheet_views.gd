extends SceneTree
## Captures the views a style's concept sheets show, for comparison with
## them (tools/sheet_compare.py composes the pairs):
##   godot --path godot --resolution 1920x1080 --script res://tools/sheet_views.gd -- STYLE_DIR_NAME
## Writes ~/.cache/agentnagar-sheets/<style>/<view>.png: topdown, diagonal,
## street (13:00, or 21:48 for a style with "sheet_night"), night-rain (20:12 in the evening shower), park (the
## waterfront path), workshop (inside, at eye level), gathering (the tree
## square at dusk) and a1 (City Agent A1 close up).
##
## With `interface` after the style, it captures the game's screens instead
## (tools/interface_compare.py sets them beside the sheet-03 panels):
##   godot --path godot --script res://tools/sheet_views.gd -- STYLE_DIR_NAME interface
## Writes ui-<screen>.png at 1920 x 1080, ui-<screen>-720.png at 1280 x 720
## and ui-<screen>-narrow.png at 800 x 900, for the screens title, join (how
## to enter), join-look, hud (in play, after Explore's flight), menu, about, styles
## (the picker), settings-graphics, settings-controls, settings-interface,
## settings-accessibility, settings-developer, rebind and dev (the F3
## panel). Each is rendered at its exact size whatever size the desktop
## gives the window.
##
## With `map` after the style, it captures the map over the city at 13:00,
## watching, with the Workshop selected (tools/sheet_compare.py sets it
## beside the sheet-00 MAP panel):
##   godot --path godot --script res://tools/sheet_views.gd -- STYLE_DIR_NAME map
## Writes map.png at 1920 x 1080, and map-720.png, map-narrow.png and the
## List tab as list.png, list-720.png and list-narrow.png at the other
## INTERFACE_SIZES, each at its exact size.
##
## With `tram` after the style, it captures the tram as the sheet-02
## TRANSIT panels show it (tools/tram_compare.py sets them beside the
## panel), with the bench's riders (Bench.TRAM_LOAD) and a second load at
## night (NIGHT_LOAD), so the trams are full:
##   godot --path godot --script res://tools/sheet_views.gd -- STYLE_DIR_NAME tram
## Writes, each at exactly 1920 x 1080:
## - tram-ride.png: a player who joined at 12:14 rides in on the full
##   eastbound tram; first person at its seat as the tram pulls in to the
##   Square (13:09), looking out on the platform side (in a style without
##   first person, the close view over its tram);
## - tram-overhead.png: the diagonal view, closer, over the eastbound tram
##   and its riders between the stops (13:48), its roof faded;
## - tram-board.png: the Square stop at 14:31 at eye height from the east
##   end of its south platform, looking along it, the westbound tram
##   standing with its doors open as its riders step off onto the platform
##   (the close view in a 2D style);
## - tram-night.png: the lit eastbound tram, full, standing at the Square
##   at 21:43, at eye height from the south platform across the tracks
##   (the close view in a 2D style).
var main
var out := ""

## The interface captures' sizes, each with its file-name suffix.
const INTERFACE_SIZES := [["", Vector2i(1920, 1080)], ["-720", Vector2i(1280, 720)], ["-narrow", Vector2i(800, 900)]]


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var style: String = args[0] if not args.is_empty() else "anime_cel"
	out = OS.get_environment("HOME") + "/.cache/agentnagar-sheets/%s/" % style
	DirAccess.make_dir_recursive_absolute(out)
	if args.size() > 1 and args[1] == "interface":
		await _interface(style)
		quit()
		return
	if args.size() > 1 and args[1] == "map":
		await _map(style)
		quit()
		return
	if args.size() > 1 and args[1] == "tram":
		await _tram(style)
		quit()
		return
	main = load("res://main.gd").new()
	root.add_child(main)
	main.boot_for_tool(PackedStringArray(["--crowd=60", "--style=" + style, "--as=none"]))
	main.driver.pause()
	main.hud.visible = false
	await _to_tick(150)
	# A night-first style's sheets show the city after dark: those views
	# come later, from a dry night (21:48).
	var night_first: bool = main.host.pack.style.get("sheet_night", false)
	if not night_first:
		for preset in ["topdown", "diagonal", "street"]:
			main.host.set_camera(preset)
			await _shot(preset)
	await _eye("park", Vector3(-41.5, 1.7, 33.0), 14.0, -3.0, 58.0)
	await _eye("workshop", Vector3(-19.5, 1.65, -3.0), 65.0, -12.0, 60.0)
	# A1 works in the reading room until the evening (the fixture's
	# librarian departs at tick 184).
	await _a1()
	await _to_tick(285)
	main.host.set_camera("street")
	await _shot("gathering")
	await _to_tick(330)
	main.host.set_camera("street")
	await _shot("night-rain", 120)
	if night_first:
		await _to_tick(370)
		for preset in ["topdown", "diagonal", "street"]:
			main.host.set_camera(preset)
			await _shot(preset)
	quit()


func _to_tick(t: int) -> void:
	while main.driver.world.tick() < t:
		main.driver.step_once()
	for f in 5:
		main._process(1.0 / 60.0)
		await process_frame


func _shot(name: String, settle := 40) -> void:
	for f in settle:
		main._process(1.0 / 60.0)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + name + ".png")
	print("sheet view ", name)


## A view from an eye at `at` (metres), turned `yaw` degrees (0 north,
## positive to the west) and `pitch`, with a field of view.
func _eye(name: String, at: Vector3, yaw: float, pitch: float, fov: float) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	cam.position = at
	cam.rotation_degrees = Vector3(pitch, yaw, 0)
	main.host.pack.add_child(cam)
	if main.host.pack.has_method("_style_node") and main.host.pack.get_script().resource_path.contains("anime"):
		Toon.line_pass(cam)
	var was := root.get_viewport().get_camera_3d()
	cam.make_current()
	await _shot(name)
	if was != null:
		was.make_current()
	cam.queue_free()


## City Agent A1 close up, facing the camera, at eye level.
func _a1() -> void:
	var a1_id := str(main.host.pack.style.get("a1", "city:librarian"))
	var node: Node3D = main.host.pack.nodes.get(a1_id)
	if node == null:
		print("sheet view a1: A1 is not present")
		return
	# Frame the face (a robot's eyes), standing or seated.
	var plate = node.find_child("face", true, false)
	if plate == null:
		plate = node.find_child("eyes", true, false)
	var face := node.global_position + Vector3(0, 1.5, 0)
	if plate is GeometryInstance3D:
		face = (plate.global_transform * plate.get_aabb()).get_center()
	# A skinned face's bounds keep the rest pose: follow the head bone.
	var skels := node.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		var sk: Skeleton3D = skels[0]
		var head := sk.find_bone("head")
		if head >= 0:
			face = sk.global_transform * (sk.get_bone_global_pose(head).origin + Vector3(0, 0.1, 0))
	var fwd := -node.global_transform.basis.z
	var cam := Camera3D.new()
	cam.fov = 30.0
	main.host.pack.add_child(cam)
	cam.global_position = face + Vector3(fwd.x, 0, fwd.z).normalized() * 1.6 + Vector3(0, 0.05, 0)
	cam.look_at(face)
	if main.host.pack.get_script().resource_path.contains("anime"):
		Toon.line_pass(cam)
	cam.make_current()
	await _shot("a1")
	cam.queue_free()


# ---- The interface ----

## The game's screens, as a first launch meets them: the title over the
## city at 13:00, the Join screen, play after Explore's flight, the game
## menu, About, the style picker, every settings page, rebinding and the
## developer panel, each at every size in INTERFACE_SIZES.
func _interface(style: String) -> void:
	main = load("res://main.gd").new()
	root.add_child(main)
	main.boot_for_tool(PackedStringArray(["--crowd=60", "--style=" + style, "--title", "--dev"]))
	main.driver.pause()
	while main.driver.world.tick() < 150:
		main.driver.step_once()
	await _ui_shots("title", 90)
	main._explore()
	var join: JoinScreen = main.stack.top()
	await _ui_shots("join")
	join.choose("registered")
	await _ui_shots("join-look")
	join.start()
	# The player takes a place at the next tick; the camera flies down.
	for t in 3:
		main.driver.step_once()
	await _seconds(StylePack.FLIGHT_S + 0.5)
	await _ui_shots("hud")
	main._open_menu()
	await _ui_shots("menu")
	main.open_about()
	await _ui_shots("about")
	main.stack.pop()
	main._open_style_picker()
	await _ui_shots("styles")
	main.stack.pop()
	main._open_settings()
	var settings: SettingsScreen = main.stack.top()
	for page in SettingsScreen.PAGES:
		await _ui_shots("settings-" + page.to_lower())
		settings.page_step(1)
	settings.page_step(1)
	settings.open_rebind()
	await _ui_shots("rebind")
	while main.stack.top() != main.hud:
		main.stack.pop()
	main.dev.toggle()
	await _ui_shots("dev")
	main.dev.toggle()


## One screen at each of INTERFACE_SIZES, as ui-<screen><suffix>.png.
func _ui_shots(screen: String, settle := 30) -> void:
	for size in INTERFACE_SIZES:
		_render_at(size[1])
		await _frames(settle)
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png(out + "ui-%s%s.png" % [screen, size[0]])
		print("interface %s%s %dx%d" % [screen, size[0], image.get_width(), image.get_height()])


## Renders the game at exactly `size`, scaled into whatever window the
## desktop gave (it may ignore a requested window size), so the screens
## lay out at `size` as they would in a window that size.
func _render_at(size: Vector2i) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = size


func _frames(n: int) -> void:
	for f in n:
		await process_frame


func _seconds(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


# ---- The map ----

## The map as a spectator opens it at 13:00 (no "you are here"), the
## Workshop selected, on its Map and List tabs at each of INTERFACE_SIZES.
func _map(style: String) -> void:
	main = load("res://main.gd").new()
	root.add_child(main)
	main.boot_for_tool(PackedStringArray(["--crowd=60", "--style=" + style, "--as=none"]))
	main.driver.pause()
	while main.driver.world.tick() < 150:
		main.driver.step_once()
	for f in 5:
		main._process(1.0 / 60.0)
		await process_frame
	main.open_map("facility:guild-hall")
	var map: MapScreen = main._map
	for size in INTERFACE_SIZES:
		_render_at(size[1])
		map.set_tab("map")
		await _frames(10)
		# The picture comes a frame or two after it is asked for.
		var until := Time.get_ticks_msec() + 5000
		while (map.base.texture == null or map._waiting) and Time.get_ticks_msec() < until:
			await process_frame
		await _frames(20)
		await _save("map" + size[0])
		map.set_tab("list")
		await _frames(20)
		await _save("list" + size[0])


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(out + name + ".png")
	print("map %s %dx%d" % [name, image.get_width(), image.get_height()])


# ---- The tram ----

## The night captures' riders: 80 arriving at tick 347, all bound for the
## Avenue, so the 40 on the eastbound tram entering at 361 ride past the
## Square (standing there from 366 to 378) to the Avenue.
const NIGHT_LOAD := {"at": 347, "riders": 80, "rooms": ["room:avenue"]}
## The player joins for the ride between the first RIDE_SPLIT of the day's
## riders (Bench.TRAM_LOAD) and the rest, which come RIDE_LATER ticks
## after them (a join arrives on the tick after it is made, after that
## tick's feed). A player takes the free seat nearest the tram's middle
## wherever it boards, so this only makes its tram a full one. Both parts
## arrive after the westbound tram at 136 has entered and before the
## eastbound one at 151, so they ride the same two trams as the bench's
## riders.
const RIDE_SPLIT := 28
const RIDE_LATER := 3


## The tram's four captures (see the header), in `style`.
func _tram(style: String) -> void:
	var join_at := int(Bench.TRAM_LOAD["at"]) + 1
	main = load("res://main.gd").new()
	main.feed_jsonl = _ride_feed(join_at)
	root.add_child(main)
	main.boot_for_tool(PackedStringArray(["--crowd=60", "--style=" + style, "--as=none"]))
	main.driver.pause()
	main.hud.visible = false
	_render_at(Vector2i(1920, 1080))
	var three_d: bool = main.host.pack.supports_fpv()
	await _to_tick(join_at)
	main.options["as"] = "registered"
	main._join()
	await _to_tick(151)
	print("tram capture: the player rides %s in slot %s" % [main.player.view.get("vehicle", "nothing"), str(main.player.view.get("slot"))])
	if three_d:
		main._toggle_fpv()
	await _to_tick(155)
	if not three_d:
		await _close_over(_ridden(), "street")
	await _shot("tram-ride", 60)
	if main.host.first_person:
		main._toggle_fpv()
	await _to_tick(171)
	await _close_over(_fullest(), "diagonal")
	await _shot("tram-overhead", 60)
	await _to_tick(189)
	if three_d:
		await _eye("tram-board", Vector3(13.0, 1.7, 25.2), 76.0, -5.0, 60.0)
	else:
		await _close_over_point(_square_m(), "street")
		await _shot("tram-board", 20)
	await _to_tick(369)
	var night := _fullest()
	if three_d and not night.is_empty():
		var middle := _middle_m(night)
		await _eye("tram-night", Vector3(middle.x, 1.7, middle.y + 9.0), 0.0, 4.0, 60.0)
	else:
		await _close_over(night, "street")
		await _shot("tram-night", 20)


## The district feed with the day's riders (Bench.TRAM_LOAD, all but its
## first RIDE_SPLIT RIDE_LATER ticks late) and the night's (NIGHT_LOAD).
## Arrivals take turns at the portals, and the district's own may come
## between the two parts, so each part's rooms are tried in both orders,
## on a world of its own with a player joining at `join_at`, and the
## first that fills both trams at the tram scene's tick is kept (the
## eastbound one less the player, who steps off at the Square).
func _ride_feed(join_at: int) -> String:
	var at := int(Bench.TRAM_LOAD["at"])
	var count := int(Bench.TRAM_LOAD["riders"])
	var rooms: Array = Bench.TRAM_LOAD["rooms"]
	var reversed := rooms.duplicate()
	reversed.reverse()
	var night := Bench.rider_entries(int(NIGHT_LOAD["at"]), int(NIGHT_LOAD["riders"]), NIGHT_LOAD["rooms"], count)
	var feed := ""
	for first in [rooms, reversed]:
		for rest in [rooms, reversed]:
			var day := Bench.rider_entries(at, RIDE_SPLIT, first) + Bench.rider_entries(at + RIDE_LATER, count - RIDE_SPLIT, rest, RIDE_SPLIT)
			feed = Bench.with_entries(CityPaths.district_feed(), day + night)
			var world = ClassDB.instantiate("CityWorld")
			world.load(CityPaths.district_manifest(), feed, 7, 60)
			while world.tick() < join_at:
				world.step()
			world.join("registered", "0,0")
			while world.tick() < 166:
				world.step()
			if Bench.full_trams(JSON.parse_string(world.project_json("public")), 39) >= 2:
				return feed
	print("tram capture: no order of the riders' rooms fills both trams")
	return feed


## The vehicle carrying the most riders the viewer sees, else {}; with
## `standing`, only one standing at a stop.
func _fullest(standing := false) -> Dictionary:
	var p: Dictionary = JSON.parse_string(main.driver.world.project_json(main.driver.viewer))
	var counts := Bench.riders_aboard(p)
	var best := {}
	for v in p.get("vehicles", []):
		if standing and v.get("status") != "standing":
			continue
		if best.is_empty() or int(counts.get(v["id"], 0)) > int(counts.get(best["id"], 0)):
			best = v
	print("tram capture: %s carrying %d" % [best.get("id", "none"), int(counts.get(best.get("id", ""), 0))])
	return best


## The vehicle the player rides, else {}.
func _ridden() -> Dictionary:
	var id := str(main.player.view.get("vehicle", ""))
	for v in JSON.parse_string(main.driver.world.project_json(main.driver.viewer)).get("vehicles", []):
		if v["id"] == id:
			return v
	return {}


## Vehicle `v`'s middle over the ground (metres): its front, less half its
## length back along its heading.
func _middle_m(v: Dictionary) -> Vector2:
	var length := float(main.trams.lines.get(v.get("line"), {}).get("vehicle", {}).get("length", 2050))
	var h := deg_to_rad(float(v.get("heading", 90)))
	var front := Vector2(float(v["pos"]["x"]), float(v["pos"]["z"]))
	return (front - Vector2(sin(h), -cos(h)) * length / 2.0) / 100.0


## The overhead view in `preset`, closer in a 3D style (30 m from the
## ground), its middle over vehicle `v`'s.
func _close_over(v: Dictionary, preset: String) -> void:
	await _close_over_point(_middle_m(v) if not v.is_empty() else Vector2.INF, preset)


## The overhead view in `preset`, closer in a 3D style, its middle over
## `at` (metres) unless that is Vector2.INF.
func _close_over_point(at: Vector2, preset: String) -> void:
	main.host.set_camera(preset)
	var pack = main.host.pack
	if pack.get("rig") != null:
		pack.rig.distance = 30.0
		pack.rig.update()
	if at == Vector2.INF:
		return
	for f in 2:
		await process_frame
	var middle = pack.ground_at(pack.get_viewport().get_visible_rect().get_center())
	if middle != null:
		pack.shift_view(at * 100.0 - middle)


## Where the Square stop's trams stand, between its tracks (metres).
func _square_m() -> Vector2:
	for line in main.trams.lines.values():
		var points := []
		for p in line.get("points", []):
			points.append(CityGeometry.pt_m(p))
		for stop in line.get("stops", []):
			if stop.get("id") == "stop:square":
				return CityGeometry.point_at(points, float(stop["at"]) / 100.0)["pos"]
	return Vector2.ZERO
