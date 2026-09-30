## The pixel pack v2 draws the district from the pre-rendered kit
## (city/tools/styles/pixel, conventions in assets/kit.json): façades a
## metre at a time, corners, roofs and the dome, blocks in their lots,
## baked ground with a shimmering river, a sliced tram from the projection,
## and night twins.
extends TestSuite

const DIR := "res://styles/pixel_art"


func manifest() -> Dictionary:
	return JSON.parse_string(CityPaths.district_manifest())


func built(m: Dictionary = {}) -> StyleHost:
	var h := StyleHost.new()
	runner.root.add_child(h)
	var model := SceneModel.new()
	model.apply({"rooms": [], "in_transit": [], "time_of_day": 720})
	h.activate(DIR, manifest() if m.is_empty() else m, model, Motion.new(), 0.0)
	return h


func _paths(nodes: Array) -> Array:
	var out := []
	for n in nodes:
		if n is Sprite2D and n.texture != null:
			out.append(n.texture.resource_path)
	return out


func test_the_kit_covers_every_key_with_no_placeholders() -> void:
	var style: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join("style.json")))
	assert_eq(style.get("declared_placeholders", []), [], "nothing left to declare")
	var h := built()
	assert_eq(h.pack.missing, PackedStringArray(), "every key the district asks for is mapped")
	assert_eq(h.pack.placeholders, 0, "no sprite fell back to a placeholder")
	h.free()


func test_buildings_are_sliced_a_metre_at_a_time_with_low_twins() -> void:
	var h := built()
	for b in CityGeometry.buildings(h.pack.manifest, StylePack.kinds()):
		var fp: Rect2 = b["footprint"]
		var shell: Dictionary = h.pack.shells[b["id"]]
		var near_slices := _paths(shell["near"]).filter(func(p): return "/s_" in p or "/e_" in p)
		assert_eq(near_slices.size(), int(fp.size.x + fp.size.y), str(b["id"]) + " near façade: one slice per metre")
		var openings := _paths(shell["near"]).filter(func(p): return "_door_m" in p)
		assert_eq(shell["low"].size(), shell["near"].size() - openings.size(), str(b["id"]) + " a low twin for every near piece but a doorway's opening")
		for n in shell["low"]:
			assert_true(not n.visible, "low twins hidden while closed")
		assert_true(shell["roof"].get_child_count() > 0, str(b["id"]) + " has a roof")
		var far := _paths(shell["far"])
		assert_eq(far.size(), int(fp.size.x + fp.size.y) + 1, str(b["id"]) + " far walls and the back corner")
	var hall: Dictionary = h.pack.shells["facility:guild-hall"]
	var teeth := _paths(hall["roof"].get_children()).filter(func(p): return "/roof_" in p)
	assert_eq(teeth.size(), 4 * 24, "four sawtooth teeth over 24 m")
	var lib := _paths(h.pack.shells["facility:library"]["roof"].get_children())
	assert_true(lib.any(func(p): return p.ends_with("library/dome.png")), "the library wears its dome")
	h.free()


func test_doors_open_where_the_manifest_has_them() -> void:
	var h := built()
	var hall: Dictionary = h.pack.shells["facility:guild-hall"]
	# The hall's two doors onto the square are on its east face: each a
	# metre of opening a metre of its width, between its two reveals.
	var openings := _paths(hall["near"]).filter(func(p): return "/e_door_m" in p)
	assert_eq(openings.size(), 4, "two 2 m doors on the hall's east face")
	var reveals := _paths(hall["near"]).filter(func(p): return "/e_door_l" in p or "/e_door_r" in p)
	assert_eq(reveals.size(), 4, "their leaves folded in a reveal either side")
	var lib: Dictionary = h.pack.shells["facility:library"]
	var lib_doors := _paths(lib["far"]).filter(func(p): return "/e_door_m" in p)
	assert_eq(lib_doors.size(), 2, "the library's door is on its west face (seen from inside)")
	h.free()


## Each doorway's opening is exactly as wide as its door and centred on
## it: the metres a doorway's plan opens run from the door less half its
## width to the door plus half, and a 3 m door opens three.
func test_a_doorways_opening_is_as_wide_as_its_door() -> void:
	var T = load("res://styles/pixel_art/townscape.gd")
	var fp := Rect2(0, 0, 12, 8)
	var side := {"side": "north", "openings": [6.0], "widths": [2.0]}
	var plan: Array = T.facade_plan(12, T.door_starts(side, fp), false)
	assert_eq(plan.slice(4, 8), ["door_l", "door_m", "door_m", "door_r"], "a 2 m door opens metres 5 and 6: %s" % str(plan))
	side = {"side": "south", "openings": [4.0], "widths": [3.0]}
	plan = T.facade_plan(12, T.door_starts(side, fp), false)
	# South runs from its far end: 4 m from x = 12 is x = 8, so metres 6.5 to 9.5 round to 7..9.
	assert_eq(plan.count("door_m"), 3, "a 3 m door opens three metres: %s" % str(plan))


## Partitions leave each interior door open exactly its width (1 m), the
## walls either side running up to it.
func test_a_partition_leaves_its_door_open_as_wide_as_the_door() -> void:
	var h := built()
	var pack = h.pack
	var parent := Node2D.new()
	pack.world.add_child(parent)
	pack.town.partition(parent, "assets/buildings/hall", Vector2(-34, 2), Vector2(-18, 2), [[Vector2(-26, 2), 1.0]], "x")
	var spans := []
	for s in parent.get_children():
		var g: Vector2 = pack.ground_of(s)
		assert_true(is_equal_approx(g.y, 2.125), "a slice straddles the shared edge: its outer line at %s" % g.y)
		spans.append([g.x - 1.0, g.x])
	var open := func(x: float) -> bool: return spans.all(func(sp): return x <= sp[0] + 1e-3 or x >= sp[1] - 1e-3)
	assert_true(open.call(-26.45) and open.call(-25.55), "the doorway is open")
	assert_true(not open.call(-26.55) and not open.call(-25.45), "and walled right up to its width")
	assert_true(not open.call(-33.9) and not open.call(-18.1), "the wall runs to both ends")
	h.free()


func test_cutaway_hides_roof_and_dome_and_drops_the_near_walls() -> void:
	var h := built()
	var pack = h.pack
	for id in pack.shells:
		var shell: Dictionary = pack.shells[id]
		pack.set_open(id, true)
		assert_true(not shell["roof"].visible, id + " roof off")
		assert_true(shell["near"].all(func(n): return not n.visible), id + " near walls down")
		assert_true(shell["low"].all(func(n): return n.visible), id + " low twins up")
		assert_true(shell["far"].all(func(n): return n.visible), id + " far walls stay")
		pack.set_open(id, false)
		assert_true(shell["roof"].visible and shell["near"].all(func(n): return n.visible), id + " closed again")
		assert_true(shell["low"].all(func(n): return not n.visible), id + " low twins hidden again")
	h.free()


func test_night_swaps_every_sprite_and_the_ground_to_its_twin_and_lights_lamps() -> void:
	var h := built()
	var pack = h.pack
	pack.set_time_of_day(1260)
	var day_left := 0
	for pair in pack.swappable:
		var s = pair[0]
		if is_instance_valid(s) and s.texture != null and ResourceLoader.exists(pack.asset(str(pair[1])).get_basename() + "_night.png"):
			if not s.texture.resource_path.ends_with("_night.png"):
				day_left += 1
	assert_eq(day_left, 0, "every sprite with a night twin shows it")
	for b in pack.baked:
		assert_eq(b["sprite"].material.get_shader_parameter("night"), true, "baked ground is at night")
	assert_true(pack.lamps.size() >= 6 and pack.lamps.all(func(l): return l.energy > 0.0), "lamps glow")
	pack.set_time_of_day(720)
	for b in pack.baked:
		assert_eq(b["sprite"].material.get_shader_parameter("night"), false, "and back by day")
	h.free()


func test_the_river_shimmers_in_two_frames() -> void:
	var h := built()
	var pack = h.pack
	var water: Array = pack.baked.filter(func(b): return b["day"].size() == 2)
	assert_true(water.size() > 0, "the river is baked in two frames")
	var before = water[0]["sprite"].texture
	pack._process(pack.SHIMMER_S + 0.01)
	assert_true(water[0]["sprite"].texture != before, "and flips between them")
	h.free()


## A tram from the projection: its back and front halves in 1 m slices
## (21 of each for the line's 20.5 m tram) that sort one by one with the
## world and keep their metre as it runs along its track, and a leaf for
## each half of each door on both sides.
func test_the_tram_is_sliced_and_moves_as_one_along_its_line() -> void:
	var h := built()
	var pack = h.pack
	var model := SceneModel.new()
	var motion := Motion.new()
	var at := func(along: int, trail: Array) -> Dictionary:
		return {"rooms": [], "in_transit": [], "aboard": [], "vehicles": [{"id": "vehicle:boulevard:east:1",
			"line": "line:boulevard", "direction": "east", "pos": {"x": -1800 + along, "z": 1900}, "heading": 90,
			"along": along, "trail": trail, "status": "running", "doors_open": false}]}
	h.apply_changes(model.apply(at.call(3000, [])), motion)
	assert_eq(pack.vehicle_nodes.size(), 1, "one tram")
	var tram: Node2D = pack.vehicle_nodes["vehicle:boulevard:east:1"]
	var halves := {"Back": [], "Front": []}
	for c in tram.get_children():
		for half in halves:
			if str(c.name).begins_with(half + "_"):
				halves[half].append(c)
	for half in halves:
		assert_eq(halves[half].size(), 21, "21 1 m slices in the %s half" % half)
	assert_eq(pack.door_leaves("vehicle:boulevard:east:1").size(), 12, "two leaves a door, three doors a side")
	assert_true(tram.y_sort_enabled, "slices sort with the world one by one")
	for step in 3:
		h.apply_changes(model.apply(at.call(3700 + 700 * step, [3000 + 700 * step, 3700 + 700 * step])), motion)
		h.tick_frame(0.5, motion)
		for half in halves:
			var slices: Array = halves[half]
			for i in slices.size():
				var d: Vector2 = slices[i].global_position - slices[0].global_position
				assert_eq(d, Vector2(16, 8) * i, "%s slice %d keeps its metre" % [half, i])
	h.free()


func test_blocks_fill_their_lots_with_houses_shops_and_towers() -> void:
	var h := built()
	var pack = h.pack
	# Blocks are the sized block placements, each drawn on its lot.
	var blocks := []
	var lots := []
	for p in CityGeometry.placements(pack.manifest):
		if str(p["kind"]).begins_with("block-"):
			blocks.append(pack.placement_nodes[p["id"]])
			lots.append(CityGeometry.lot(p))
	# 27: the house across the avenue where the boulevard tram runs out of
	# the district is gone.
	assert_eq(blocks.size(), 27, "every block drawn")
	var kinds := {}
	for k in blocks.size():
		var r: Rect2 = lots[k].grow(0.01)
		assert_true(blocks[k].get_child_count() > 0, "block %d has buildings" % k)
		for s in blocks[k].get_children():
			var ground: Vector2 = pack.ground_of(s)
			assert_true(r.has_point(ground), "block %d: %s stands inside its rect" % [k, s.texture.resource_path])
			kinds[s.texture.resource_path.get_file().get_slice("_", 0)] = true
	for want in ["house", "shop", "tower"]:
		assert_true(kinds.has(want), "the city has " + want + "s")
	h.free()


func test_outdoor_rooms_are_paved_and_the_park_has_lawn_and_paths() -> void:
	var h := built()
	var pack = h.pack
	var plaza := CityGeometry.rect_m(pack.room_rects["room:plaza"]["rect"])
	var park := CityGeometry.rect_m(pack.room_rects["room:park"]["rect"])
	var paved := 0
	var paths := 0
	var lawn := 0
	for c in pack.cells:
		var p := Vector2(c.x + 0.5, c.y + 0.5)
		var tile: String = pack.cells[c]
		if plaza.has_point(p):
			assert_true("paving" in tile, "the square is paved: " + tile)
			paved += 1
		elif park.has_point(p):
			if "path" in tile:
				paths += 1
			elif "grass" in tile:
				lawn += 1
	assert_eq(paved, int(plaza.size.x * plaza.size.y), "every metre of the square")
	assert_true(paths >= 10 and lawn > paths, "a lawn with paths from its doors")
	h.free()


func test_streets_have_kerbs_dashes_crossings_and_the_track() -> void:
	var h := built()
	var tiles := {}
	for c in h.pack.cells:
		tiles[h.pack.cells[c].get_file().get_basename()] = true
	for want in ["street", "kerb_n", "kerb_s", "kerb_e", "kerb_w", "street_dash_x", "street_dash_z", "crossing_x",
			"crossing_z", "track_x_n", "track_x_s", "water_0", "quay_w", "quay_e"]:
		# The district's tracks run along cell edges (z 19 and 22 m), so
		# they are laid in halves either side (they were whole tiles).
		assert_true(tiles.has(want), "the ground has " + want)
	h.free()


func with_people() -> StyleHost:
	var h := StyleHost.new()
	runner.root.add_child(h)
	var views := []
	for k in 3:
		views.append({"id": "p:%d" % k, "kind": {"type": ["Human", "GuildAgent", "SimCitizen"][k], "tier": "Registered"},
			"display_name": "P%d" % k, "role": "", "badge": null, "appearance": {"palette": str(k)}, "seat": null,
			"presence": {"headline": "Working"}, "pos": {"x": 0, "z": 600}, "task_summary": null})
	var model := SceneModel.new()
	model.apply({"rooms": [{"id": "room:plaza", "occupants": views, "waiting": []}], "in_transit": [], "time_of_day": 720})
	h.activate(DIR, manifest(), model, Motion.new(), 0.0)
	return h


func test_people_walk_in_eight_directions_from_the_rendered_sheets() -> void:
	var h := with_people()
	var pack = h.pack
	var body: AnimatedSprite2D = pack.nodes["p:0"].get_node("Body")
	var frame: AtlasTexture = body.sprite_frames.get_frame_texture("walk_0", 0)
	assert_eq(frame.region.size, Vector2(32, 40), "32 x 40 frames")
	assert_eq(body.sprite_frames.get_frame_count("walk_0"), 6, "six walking frames")
	for anim in ["sit_0", "idle_0", "typing_0"]:
		assert_true(body.sprite_frames.has_animation(anim), "has " + anim)
	pack.set_pose("p:0", "walking")
	# Facing is measured clockwise from north; rows go 0, 45, ... 315.
	for case in [[Vector2(0, -1), 0], [Vector2(1, 0), 2], [Vector2(1, 1), 3], [Vector2(0, 1), 4], [Vector2(-1, 1), 5],
			[Vector2(-1, 0), 6], [Vector2(-1, -1), 7]]:
		pack.place("p:0", Vector2(0, 600), case[0])
		assert_eq(body.animation, "walk_%d" % case[1], "walking toward %s" % str(case[0]))
		assert_true(not body.flip_h, "directions are drawn, never mirrored")
	assert_eq(body.offset, Vector2(0, -14), "standing frames put the feet on the ground point")
	h.free()


func test_seated_people_type_while_working_and_sit_otherwise() -> void:
	var h := with_people()
	var pack = h.pack
	var body: AnimatedSprite2D = pack.nodes["p:0"].get_node("Body")
	pack.place("p:0", Vector2(0, 600), Vector2(1, 0))
	pack.set_pose("p:0", "sitting")
	pack.set_presence("p:0", "Working")
	assert_eq(body.animation, "typing_2", "working at a seat types")
	pack.set_presence("p:0", "Idle")
	assert_eq(body.animation, "sit_2", "otherwise sits")
	assert_eq(body.offset, Vector2(0, -12), "seated frames put the seat on the ground point")
	h.free()


func test_the_you_marker_points_down_at_the_head() -> void:
	var h := with_people()
	var pack = h.pack
	pack.set_player("p:0")
	var marker: Node2D = pack.player_marker()
	assert_true(marker != null, "the player is marked")
	var lowest := -INF
	for poly in marker.get_children():
		for v in poly.polygon:
			lowest = maxf(lowest, v.y)
	assert_true(lowest <= -33.0 and lowest >= -40.0, "the arrow's tip is just over the 32 px figure: %s" % lowest)
	h.free()


func test_the_ground_is_palette_indices_and_night_needs_no_second_bake() -> void:
	var h := built()
	var pack = h.pack
	var bytes := 0
	for b in pack.baked:
		for tex in b["day"]:
			var img: Image = tex.get_image()
			assert_eq(img.get_format(), Image.FORMAT_R8, "one byte a pixel")
			bytes += img.get_data().size()
	assert_true(bytes < 32 * 1024 * 1024, "the ground fits in %d MB" % (bytes / 1048576))
	var textures: Array = pack.baked.map(func(b): return b["sprite"].texture)
	var t0 := Time.get_ticks_msec()
	pack.set_time_of_day(1260)
	var nightfall_ms := Time.get_ticks_msec() - t0
	var stall_budget := 50.0 * machine_factor()
	assert_true(nightfall_ms < stall_budget, "nightfall does not stall: %d ms (budget %.0f ms)" % [nightfall_ms, stall_budget])
	assert_eq(pack.baked.map(func(b): return b["sprite"].texture), textures, "night bakes nothing new")
	# An index decodes to the tile's own colour, by day and by night.
	var pal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pack.asset("assets/palette.json")))
	var names: Array = pal.keys()
	names.sort()
	var entry: Dictionary = pack.baked[0]
	var c: Vector2i = entry["tiles"].keys()[0]
	var at: Vector2 = pack.iso(c.x + 0.5, c.y + 0.5) - entry["origin"] - entry["crop"]
	var idx: int = roundi(entry["day"][0].get_image().get_pixelv(Vector2i(at)).r * 255.0)
	var tile: Image = pack._tile_image(str(entry["tiles"][c]), false)
	var want := tile.get_pixel(16, 8)
	assert_true(idx > 0, "an opaque pixel")
	assert_true(Color.html(pal[names[idx - 1]][0]).is_equal_approx(Color(want.r, want.g, want.b)), "index %d is the tile's colour" % idx)
	var night_tile: Image = pack._tile_image(str(entry["tiles"][c]), true)
	var nw := night_tile.get_pixel(16, 8)
	assert_true(Color.html(pal[names[idx - 1]][1]).is_equal_approx(Color(nw.r, nw.g, nw.b)), "and its night twin")
	h.free()


func test_bookshelves_are_pre_rendered_and_face_the_room() -> void:
	var style: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://styles/pixel_art/style.json"))
	var entry: Dictionary = style["props"]["bookshelf"]
	assert_true(entry.has("facings"), "a sprite per facing")
	for f in ["0", "90", "180", "270"]:
		assert_true(str(entry["facings"][f]).begins_with("assets/scenery/"), "facing %s is from the kit" % f)
		assert_true(ResourceLoader.exists("res://styles/pixel_art/" + entry["facings"][f]), f)
	var h := built()
	var pack = h.pack
	var drawn := []
	for pair in pack.swappable:
		if is_instance_valid(pair[0]) and "bookshelf" in str(pair[1]):
			drawn.append(str(pair[1]))
	assert_true(drawn.has(entry["facings"]["270"]), "the reading room's shelves face west: %s" % str(drawn))
	assert_true(drawn.has(entry["facings"]["90"]), "the commons' shelf faces east: %s" % str(drawn))
	h.free()


## A fence runs along the edge of the walkable ground, so each railing
## slice and post stands off it on the side no room covers, on the pixel
## lattice where its ground point is exact.
func test_railings_stand_just_off_the_floor_they_edge() -> void:
	var h := built()
	var pack = h.pack
	var rails := 0
	for s in pack.world.find_children("*", "Sprite2D", true, false):
		if not "railing" in str(s.texture.resource_path):
			continue
		rails += 1
		var g: Vector2 = pack.ground_of(s)
		assert_true(not pack.town._on_a_floor(g), "a railing at %s stands off every floor" % g)
		assert_eq(g, g.snapped(Vector2(0.125, 0.125)), "on the lattice")
	assert_true(rails > 100, "the district is fenced: %d" % rails)
	h.free()


## Props whose footprint turns (tram shelters, flowerbeds) are drawn from
## the sprite rendered at their facing, so a shelter opens toward its
## stand whichever way it is placed. (A shelter's bench is a perch: its
## node holds its body, first, and a seat stone per sit anchor.)
func test_shelters_and_beds_are_drawn_at_their_facing() -> void:
	var h := built()
	var pack = h.pack
	var seen := 0
	for p in CityGeometry.placements(pack.manifest):
		if not str(p["kind"]) in ["tram-shelter", "flowerbed"]:
			continue
		seen += 1
		var drawn: Node2D = pack.placement_nodes[p["id"]]
		var node: Sprite2D = drawn if drawn is Sprite2D else drawn.get_child(0)
		var f := posmod(roundi(float(p["facing"]) / 90.0) * 90, 360)
		if p["kind"] == "flowerbed":
			f = f % 180
		assert_true(node.texture.resource_path.ends_with("_%d.png" % f), "%s at %d: %s" % [p["id"], f, node.texture.resource_path])
	assert_true(seen >= 8, "the district's shelters and beds: %d" % seen)
	h.free()


## Every block's lot is walled along the inside of its edges, with one
## closed gate in the side facing its nearest street, and its buildings
## stand inside the wall.
func test_every_block_is_walled_with_a_gate_toward_its_street() -> void:
	var h := built()
	var pack = h.pack
	var seen := 0
	for p in CityGeometry.placements(pack.manifest):
		if not str(p["kind"]).begins_with("block-"):
			continue
		seen += 1
		var lot := CityGeometry.lot(p)
		var street := CityGeometry.nearest_street(pack.manifest, lot.get_center())
		var gates := []
		var walls := 0
		for s in pack.placement_nodes[p["id"]].get_children():
			var path: String = s.texture.resource_path
			var g: Vector2 = pack.ground_of(s)
			if "garden_gate" in path:
				gates.append(g)
			elif "garden_wall" in path:
				walls += 1
				assert_true(lot.has_point(g) and not lot.grow(-0.25).has_point(g), "%s: a wall slice runs along the lot's edge at %s" % [p["id"], g])
			else:
				assert_true(lot.grow(-0.2).has_point(g), "%s: %s stands inside the wall" % [p["id"], path.get_file()])
		assert_eq(gates.size(), 1, "%s has one gate: %s in %s" % [p["id"], str(gates), str(lot)])
		assert_eq(walls, int(2 * (lot.size.x + lot.size.y)) - 2, "%s is walled all round but its gate" % p["id"])
		if gates.size() == 1:
			var side := KitTown.side_toward(lot, street)
			var edge: float = [lot.position.y, lot.end.y, lot.position.x, lot.end.x][side]
			var across: float = gates[0].y if side < 2 else gates[0].x
			assert_true(absf(across - edge) < 0.2, "%s: the gate is in the side facing its street" % p["id"])
	assert_true(seen >= 20, "the district's blocks: %d" % seen)
	h.free()


## A seat is drawn from the sprite rendered at its own facing where the kit
## has one (the square's ring of benches, 36 degrees apart), else the
## nearest eighth.
func test_seats_are_drawn_at_their_own_facing() -> void:
	var h := built()
	var pack = h.pack
	var checked := 0
	for d in pack.manifest["city"]["districts"]:
		for f in d["facilities"]:
			for r in f["rooms"]:
				for s in r.get("seats", []):
					var node: Sprite2D = pack.placement_nodes[str(s["id"])]
					var facing := posmod(roundi(float(s.get("facing", 0))), 360)
					var want := facing if s["kind"] == "bench" else posmod(roundi(facing / 45.0) * 45, 360)
					# The sprite the style maps to the kind at that facing: a
					# workstation reuses the desk's until its own art.
					var sprite := str(pack.style["seats"][s["kind"]]["facings"][str(want)])
					assert_true(sprite.ends_with("_%d.png" % want), "%s: its %d sprite is a %d one: %s" % [s["id"], want, want, sprite])
					assert_true(node.texture.resource_path.ends_with(sprite), "%s at %d: %s" % [s["id"], facing, node.texture.resource_path])
					checked += 1
	assert_true(checked >= 40, "the district's seats: %d" % checked)
	h.free()
