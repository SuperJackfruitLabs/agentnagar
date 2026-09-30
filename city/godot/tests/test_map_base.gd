## The map's base picture: every style answers a request with a texture of
## the size asked, a 3D style by drawing its own world once from straight
## above, and the world is exactly as it was afterwards.
extends TestSuite

const STYLES_3D := ["lowpoly_tropical", "voxel", "anime_cel", "solarpunk", "neon_noir"]


func booted(style: String):
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=20", "--style=" + style, "--as=none"]))
	# Long enough for the first trams to bring arrivals in (they step off at
	# the Square from tick 35), so there are people to hide.
	main.driver.advance(40.0)
	return main


## The next frame drawn. Headless nothing is drawn on its own (the main
## loop draws only for a window that can show it), so the frame is drawn
## here: `force_draw` emits `frame_pre_draw` and `frame_post_draw` as a
## drawn frame does. On a display this waits for the next one.
func drawn() -> void:
	if DisplayServer.get_name() == "headless":
		RenderingServer.force_draw()
	else:
		await RenderingServer.frame_post_draw


## Waits out a request: a few frames, the frame drawn, and a couple more.
func settle() -> void:
	for i in 4:
		await runner.process_frame
	await drawn()
	for i in 2:
		await runner.process_frame


## Pixel art's plan of `extent`, at exactly 4 px/m (no further upscale), so
## a world point converts to a pixel with plain arithmetic (pixel_at).
func pixel_map(main, extent: Rect2) -> Image:
	var size := Vector2i(roundi(extent.size.x * 4.0), roundi(extent.size.y * 4.0))
	var got := []
	main.host.map_ready.connect(func(t, _d): got.append(t), CONNECT_ONE_SHOT)
	main.host.request_map(extent, size)
	await runner.process_frame
	await runner.process_frame
	return got[0].get_image()


## The colour, as a lowercase "rrggbb", at a world point (metres) of a
## pixel_map drawn over `extent`.
func pixel_at(img: Image, extent: Rect2, world: Vector2) -> String:
	var p := ((world - extent.position) * 4.0).round()
	return img.get_pixel(int(p.x), int(p.y)).to_html(false)


## The style's kit, name -> its day colour as pixel_at would spell it.
func pixel_kit() -> Dictionary:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://styles/pixel_art/assets/palette.json"))
	var out := {}
	for k in raw:
		out[k] = Color.html(str(raw[k][0])).to_html(false)
	return out


func test_every_style_answers_with_a_texture_of_the_size_asked() -> void:
	for style in ["lowpoly_tropical", "voxel", "anime_cel", "solarpunk", "neon_noir", "pixel_art"]:
		var main = booted(style)
		var got := []
		main.host.map_ready.connect(func(t, _d): got.append(t), CONNECT_ONE_SHOT)
		main.host.request_map(CityGeometry.extent(main.manifest), Vector2i(640, 400))
		for i in 4:
			await runner.process_frame
		await drawn()
		for i in 2:
			await runner.process_frame
		assert_eq(got.size(), 1, style + ": one answer")
		assert_eq(Vector2i(got[0].get_size()), Vector2i(640, 400), style + ": size")
		main.free()


func test_the_world_is_as_it_was_afterwards() -> void:
	var main = booted("anime_cel")
	var pack: Pack3D = main.host.pack
	var minutes: int = pack.minutes
	var shown := {}
	for id in pack.nodes:
		shown[id] = pack.nodes[id].visible
	main.host.request_map(CityGeometry.extent(main.manifest), Vector2i(320, 200))
	for i in 4:
		await runner.process_frame
	await drawn()
	for i in 2:
		await runner.process_frame
	assert_eq(pack.minutes, minutes, "time of day restored")
	for id in shown:
		assert_eq(pack.nodes[id].visible, shown[id], "person %s restored" % id)
	assert_true(not pack.has_node("MapView"), "the render viewport is gone")
	main.free()


func test_a_switch_during_the_render_is_harmless() -> void:
	var main = booted("anime_cel")
	var got := []
	main.host.map_ready.connect(func(t, d): got.append(d))
	var old: Pack3D = main.host.pack
	var hide_handler: Callable = old._hide_for_map
	var take_handler: Callable = old._take_map
	main.host.request_map(CityGeometry.extent(main.manifest), Vector2i(320, 200))
	assert_true(RenderingServer.frame_pre_draw.is_connected(hide_handler), "the old pack waits to draw")
	main.host.activate("res://styles/voxel", main.manifest, main.model, main.motion, 0.0)
	assert_true(not RenderingServer.frame_pre_draw.is_connected(hide_handler), "the old pack's pre-draw handler dropped")
	assert_true(not RenderingServer.frame_post_draw.is_connected(take_handler), "and its post-draw one")
	# The map asks the new style again, as MapScreen.apply_theme does.
	main.host.request_map(CityGeometry.extent(main.manifest), Vector2i(320, 200))
	await settle()
	assert_eq(got, ["res://styles/voxel"], "one answer, from the new pack")
	main.free()


## The render's own viewport and camera: sharing the world, drawn once,
## orthographic over the extent from 200 m up, north at the top.
func test_the_render_looks_straight_down_over_the_extent() -> void:
	var main = booted("voxel")
	var pack: Pack3D = main.host.pack
	var extent := CityGeometry.extent(main.manifest)
	var main_camera: Camera3D = main.get_viewport().get_camera_3d()
	main.host.request_map(extent, Vector2i(320, 200))
	var view: SubViewport = pack.get_node_or_null("MapView")
	assert_true(view != null, "a MapView under the pack")
	if view == null:
		main.free()
		return
	assert_eq(view.size, Vector2i(320, 200), "its size")
	assert_true(not view.own_world_3d and not view.transparent_bg, "the pack's world, opaque")
	assert_eq(view.msaa_3d, pack.msaa_level(), "the pack's MSAA")
	assert_eq(view.render_target_update_mode, SubViewport.UPDATE_ONCE, "drawn once")
	var cam: Camera3D = view.get_camera_3d()
	assert_true(cam != null and cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "orthographic")
	assert_eq(cam.size, extent.size.y, "as tall as the extent")
	assert_eq(cam.keep_aspect, Camera3D.KEEP_HEIGHT, "keeping its height")
	assert_eq(cam.position, Vector3(extent.get_center().x, 200, extent.get_center().y), "over its centre")
	assert_eq(cam.rotation_degrees, Vector3(-90, 0, 0), "looking straight down, north up")
	assert_eq(main.get_viewport().get_camera_3d(), main_camera, "the main camera untouched")
	await settle()
	main.free()


## Everything the render hides or changes is back afterwards, in the very
## frame it was drawn: the rain and its streaks, the clouds, the player's
## marker and the reticle, the roofs of open buildings, the sun, the fog
## and the time. The world is read just before the request's own handlers
## run (a handler connected before them) and just after (one connected
## after them), so nothing the host does between frames can mask a miss.
func test_rain_clouds_marker_reticle_roofs_and_sun_come_back() -> void:
	var main = booted("neon_noir")
	var pack: Pack3D = main.host.pack
	var anyone: String = pack.nodes.keys()[0]
	pack.set_player(anyone)
	pack.show_reticle(Vector2(300, 400))
	pack.set_rain(0.8)
	pack.set_time_of_day(1300)
	pack.set_daylight(1300.5)
	var some_building: String = pack.shells.keys()[0]
	pack.set_open(some_building, true)
	await runner.process_frame
	var read := func() -> Dictionary:
		return {
			"minutes": pack.minutes, "rain": pack.rain, "keep_roofs": pack.keep_roofs,
			"rain_shown": pack.rain_node.visible, "marker": pack.player_marker().visible,
			"reticle": pack.reticle.visible, "open": pack.open_ids.duplicate(),
			"roof": pack.shells[some_building]["roof"].visible,
			"walls": pack.shells[some_building]["sides"].values().map(func(s): return [s["full"].visible, s["low"].visible]),
			"clouds": pack.clouds.map(func(c): return c.visible),
			"sun": pack.sun.transform, "sun_energy": pack.sun.light_energy, "sun_colour": pack.sun.light_color,
			"shadow_reach": pack.sun.directional_shadow_max_distance, "shadow_mode": pack.sun.directional_shadow_mode,
			"fog": pack.env.fog_enabled, "streaks": pack._streaks.map(func(s): return s.visible),
			"lamps": pack.lamps.map(func(l): return l.visible),
			"exposure": pack.env.tonemap_exposure,
		}
	var before := {}
	var after := {}
	RenderingServer.frame_pre_draw.connect(func(): before.merge(read.call()), CONNECT_ONE_SHOT)
	main.host.request_map(CityGeometry.extent(main.manifest), Vector2i(320, 200))
	RenderingServer.frame_post_draw.connect(func(): after.merge(read.call()), CONNECT_ONE_SHOT)
	await settle()
	assert_true(not before.is_empty() and not after.is_empty(), "the world read either side of the render")
	for key in before:
		assert_eq(after.get(key), before[key], key + " restored")
	main.free()


## For the one frame the picture is drawn, the people, the marker, the
## reticle, the rain and the clouds are hidden, the roofs are on and the
## time is the style's map time. Watched from a handler connected after
## the request's own, so it runs after the render state is set.
func test_the_drawn_frame_has_no_people_weather_or_cutaways() -> void:
	var main = booted("anime_cel")
	var pack: Pack3D = main.host.pack
	var anyone: String = pack.nodes.keys()[0]
	pack.set_player(anyone)
	pack.show_reticle(Vector2(300, 400))
	pack.set_rain(0.8)
	var some_building: String = pack.shells.keys()[0]
	pack.set_open(some_building, true)
	await runner.process_frame
	var seen := {}
	main.host.request_map(CityGeometry.extent(main.manifest), Vector2i(320, 200))
	RenderingServer.frame_pre_draw.connect(func():
		seen["people"] = pack.nodes.values().any(func(n): return n.visible)
		seen["reticle"] = pack.reticle.visible
		seen["rain"] = pack.rain_node.visible
		seen["clouds"] = pack.clouds.any(func(c): return c.visible)
		seen["minutes"] = pack.minutes
		seen["roof"] = pack.shells[some_building]["roof"].visible
		seen["walls"] = pack.shells[some_building]["sides"].values().all(func(s): return s["full"].visible and not s["low"].visible)
	, CONNECT_ONE_SHOT)
	await settle()
	assert_eq(seen.get("people"), false, "no people")
	assert_eq(seen.get("reticle"), false, "no reticle")
	assert_eq(seen.get("rain"), false, "no rain")
	assert_eq(seen.get("clouds"), false, "no clouds")
	assert_eq(seen.get("minutes"), pack.map_minutes(), "the map's time")
	assert_eq(seen.get("roof"), true, "the open building's roof on")
	assert_eq(seen.get("walls"), true, "its walls whole")
	main.free()


## The style's `map.exposure` brightens (or darkens) the one frame the
## picture is drawn, and only that frame: the tonemap's exposure is
## scaled by it for the render and is back afterwards.
func test_the_map_exposure_is_applied_for_the_render_and_restored() -> void:
	var main = booted("anime_cel")
	var pack: Pack3D = main.host.pack
	pack.style["map"]["exposure"] = 2.0
	var before: float = pack.env.tonemap_exposure
	var seen := {}
	main.host.request_map(CityGeometry.extent(main.manifest), Vector2i(320, 200))
	RenderingServer.frame_pre_draw.connect(func(): seen["exposure"] = pack.env.tonemap_exposure, CONNECT_ONE_SHOT)
	await settle()
	assert_eq(seen.get("exposure"), before * 2.0, "twice as bright for the render")
	assert_eq(pack.env.tonemap_exposure, before, "as it was afterwards")
	var plain := StylePack.new()
	assert_eq(plain.map_exposure(), 1.0, "1 unless the style says")
	plain.free()
	main.free()


## A 3D pack given no picture to copy (headless, or an empty image)
## answers with a stand-in the host does not keep.
func test_a_picture_not_drawn_is_a_stand_in() -> void:
	var main = booted("voxel")
	var got := []
	main.host.map_ready.connect(func(t, _d): got.append(t), CONNECT_ONE_SHOT)
	main.host.request_map(CityGeometry.extent(main.manifest), Vector2i(64, 40))
	await settle()
	assert_eq(got.size(), 1, "answered")
	if DisplayServer.get_name() == "headless" and got.size() == 1:
		assert_true(StylePack.is_stand_in(got[0]), "headless: a stand-in")
	main.free()


## A style without a picture of its own answers, a frame later, with a
## plain texture of the size asked.
func test_the_default_answer_is_a_plain_texture() -> void:
	var pack := StylePack.new()
	runner.root.add_child(pack)
	var got := []
	pack.map_ready.connect(func(t): got.append(t))
	pack.request_map(Rect2(0, 0, 100, 60), Vector2i(50, 30))
	assert_eq(got.size(), 0, "not at once")
	await runner.process_frame
	assert_eq(got.size(), 1, "an answer")
	assert_eq(Vector2i(got[0].get_size()), Vector2i(50, 30), "of the size asked")
	assert_eq(pack.map_minutes(), 720, "noon unless the style says")
	pack.style = {"map": {"minutes": 1260}}
	assert_eq(pack.map_minutes(), 1260, "the style's map time")
	pack.free()


## Pixel art has no top view of its isometric sprites, so it paints its own
## top-down plan of the district from the layout and scenery, in nothing
## but its 32-colour kit.
func test_pixel_art_paints_its_plan_in_its_palette() -> void:
	var main = booted("pixel_art")
	var got := []
	main.host.map_ready.connect(func(t, _d): got.append(t), CONNECT_ONE_SHOT)
	main.host.request_map(CityGeometry.extent(main.manifest), Vector2i(800, 500))
	await runner.process_frame
	await runner.process_frame
	var img: Image = got[0].get_image()
	var colours := {}
	for y in range(0, 500, 7):
		for x in range(0, 800, 7):
			colours[img.get_pixel(x, y).to_html(false)] = true
	assert_true(colours.size() >= 5, "a real plan, not a flat fill")
	var allowed: Dictionary = main.host.pack.palette_hexes()
	for c in colours:
		assert_true(allowed.has(c), "palette colour " + c)
	main.free()


## Each room reads as its place, not the flat lawn all around it: the
## plaza paved, the café terrace in planks (not paved like the plaza), and
## the park a different green, its doors' paths crossing it.
func test_pixel_art_paints_room_floors_by_place() -> void:
	var main = booted("pixel_art")
	var extent := CityGeometry.extent(main.manifest)
	var img: Image = await pixel_map(main, extent)
	var lawn := pixel_at(img, extent, Vector2(-60.0, -55.0))
	var plaza := pixel_at(img, extent, Vector2(-15.0, -12.0))
	var cafe := pixel_at(img, extent, Vector2(-33.5, 10.5))
	var park := pixel_at(img, extent, Vector2(-31.0, 29.0))
	assert_eq(plaza, pixel_at(img, extent, Vector2(14.0, -12.0)), "the plaza floor is one colour")
	assert_true(plaza != lawn, "the plaza reads as paved, not lawn")
	assert_true(cafe != lawn, "the café terrace reads as its own floor, not lawn")
	assert_true(cafe != plaza, "the café terrace is planks, not paved like the plaza")
	assert_true(park != lawn, "the park reads as a different green, not the lawn")
	var park_colours := {}
	for gx in range(-33, -19):
		for gz in range(17, 30):
			park_colours[pixel_at(img, extent, Vector2(float(gx) + 0.5, float(gz) + 0.5))] = true
	assert_true(park_colours.size() >= 2, "the park's doors' paths break its green")
	main.free()


## The rows of palms along the streets are on the plan as tree dots, as
## the tree rows always were: a row palm's point is painted a crown green.
func test_pixel_art_draws_the_row_palms() -> void:
	var main = booted("pixel_art")
	var extent := CityGeometry.extent(main.manifest)
	var img: Image = await pixel_map(main, extent)
	var kit := pixel_kit()
	var palm := {}
	for p in CityGeometry.placements(main.manifest):
		if p["id"] == "placement:row-01-02":
			palm = p
	assert_eq(palm.get("kind"), "palm", "the square's north row is palms")
	assert_true(pixel_at(img, extent, palm["pos"]) in [kit["leaf"], kit["leaf_dark"]], "its palm is painted as a tree")
	main.free()


## A great tree, above all the plaza's central one, draws a crown at its
## real size (the great tree model's 4.6 m radius,
## city/tools/styles/pixel/models.py's tree_square()), not a street tree's
## small dot: it still reaches at least 4 m out from its centre.
func test_pixel_art_draws_a_room_tree_as_a_big_crown() -> void:
	var main = booted("pixel_art")
	var extent := CityGeometry.extent(main.manifest)
	var img: Image = await pixel_map(main, extent)
	var kit := pixel_kit()
	var crown := [kit["leaf"], kit["leaf_dark"]]
	assert_true(pixel_at(img, extent, Vector2.ZERO) in crown, "the plaza's tree is painted at its centre")
	assert_true(pixel_at(img, extent, Vector2(4.0, 0.0)) in crown, "its crown reaches at least 4 m out")
	assert_true(pixel_at(img, extent, Vector2(0.0, -4.0)) in crown, "in every direction, not just one")
	main.free()


## The library's roof colour is its own: not the "stone" every generic
## scenery block reads in, not the guild-hall's brick, and not any of the
## plan's other colours either (the street and block's greys, the lawn
## and plaza's greens and tans), so a player can pick the library out
## instead of reading it as another road or block.
func test_pixel_art_gives_the_library_its_own_roof_colour() -> void:
	var main = booted("pixel_art")
	var extent := CityGeometry.extent(main.manifest)
	var img: Image = await pixel_map(main, extent)
	var library
	for b in CityGeometry.buildings(main.manifest, StylePack.kinds()):
		if str(b["kind"]) == "library":
			library = b
	assert_true(library != null, "the fixture has a library")
	var library_colour := pixel_at(img, extent, (library["footprint"] as Rect2).get_center())
	var block
	for p in CityGeometry.placements(main.manifest):
		if str(p["kind"]).begins_with("block-"):
			block = p
			break
	assert_true(block != null, "the fixture has a generic block")
	var block_colour := pixel_at(img, extent, CityGeometry.lot(block).get_center())
	var street_colour := pixel_at(img, extent, Vector2(0.0, -19.0))
	var kit := pixel_kit()
	assert_eq(library_colour, kit["night_blue2"], "the library reads as its own navy slate")
	assert_eq(block_colour, kit["stone"], "a generic block still reads as stone")
	assert_true(library_colour != street_colour, "the library differs from the street, not another road")
	assert_true(library_colour != block_colour, "the library differs from a generic block")
	assert_true(library_colour != kit["leaf_light"], "the library differs from the lawn")
	assert_true(library_colour != kit["sand_light"], "the library differs from the plaza")
	assert_true(library_colour != kit["brick"], "the library differs from the guild-hall's brick")
	main.free()


## The river fills every edge of a request framed exactly on the layout's
## water rect: it is not clipped short of where the water itself reaches.
func test_pixel_art_does_not_clip_the_river_where_it_fills_the_extent() -> void:
	var main = booted("pixel_art")
	var water
	for s in main.manifest.get("scenery", []):
		if str(s.get("kind", "")) == "water":
			water = s
	assert_true(water != null, "the fixture has a river")
	var extent := CityGeometry.rect_m(water["rect"])
	var img: Image = await pixel_map(main, extent)
	var kit := pixel_kit()
	var wet := [kit["water"], kit["water_light"]]
	for corner in [Vector2(0, 0), Vector2(img.get_width() - 1, 0), Vector2(0, img.get_height() - 1), Vector2(img.get_width() - 1, img.get_height() - 1)]:
		assert_true(img.get_pixel(int(corner.x), int(corner.y)).to_html(false) in wet, "the river reaches corner " + str(corner))
	main.free()


## Real pixels need a display, so headless this test only records that it
## was skipped (`assert_true(true, "skipped headless")`, since a test must
## assert). On a display every 3D style's picture must have content, not
## one flat colour; with CITY_MAP_CAPTURES set to a folder, each is saved
## there as <style>.png to be looked at.
func test_every_3d_style_draws_a_picture() -> void:
	if DisplayServer.get_name() == "headless":
		assert_true(true, "skipped headless")
		return
	var out := OS.get_environment("CITY_MAP_CAPTURES")
	for style in STYLES_3D:
		var main = booted(style)
		var got := []
		main.host.map_ready.connect(func(t, _d): got.append(t), CONNECT_ONE_SHOT)
		main.host.request_map(CityGeometry.extent(main.manifest), Vector2i(1280, 800))
		await settle()
		assert_eq(got.size(), 1, style + ": one answer")
		if got.is_empty():
			main.free()
			continue
		var image: Image = got[0].get_image()
		var colours := {}
		for y in range(0, image.get_height(), 40):
			for x in range(0, image.get_width(), 40):
				colours[image.get_pixel(x, y).to_html(false)] = true
		assert_true(colours.size() > 20, "%s: a picture, not a flat fill (%d colours)" % [style, colours.size()])
		if out != "":
			DirAccess.make_dir_recursive_absolute(out)
			image.save_png(out.path_join(style + ".png"))
		main.free()


## Asked for a size that is no whole multiple of its plan (the map screen
## asks for twice its fitted size), pixel art still draws the whole
## extent over the whole picture, so the map's pins land on their places:
## each place's middle is the colour the plan has there.
func test_pixel_art_covers_the_extent_at_any_size() -> void:
	var main = booted("pixel_art")
	var extent := CityGeometry.extent(main.manifest)
	var plan: Image = await pixel_map(main, extent)
	var size := Vector2i(1000, 852)
	var got := []
	main.host.map_ready.connect(func(t, _d): got.append(t), CONNECT_ONE_SHOT)
	main.host.request_map(extent, size)
	await runner.process_frame
	await runner.process_frame
	var img: Image = got[0].get_image()
	assert_eq(img.get_size(), size, "of the size asked")
	var scale := Vector2(size) / extent.size
	# The far south-east corner is sampled on open lawn, clear of the street
	# trees' dithered crowns, where nearest-neighbour scaling may land on
	# either green.
	for world: Vector2 in [Vector2(27, -2), Vector2(-26, -2), Vector2(-26, 23), Vector2(-15, -12), Vector2(62, 45)]:
		var p := ((world - extent.position) * scale).floor()
		assert_eq(img.get_pixel(int(p.x), int(p.y)).to_html(false), pixel_at(plan, extent, world), "at %s" % world)
	main.free()
