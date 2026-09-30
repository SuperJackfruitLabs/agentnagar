## The cel-shaded anime style: toon everywhere, ink on people, faces from
## the atlas, the far crowd drawn simply, A1 as the sheets draw it, glass
## lit at night, rain on the streets and umbrellas outdoors only.
extends TestSuite

const DIR := "res://styles/anime_cel"


func manifest() -> Dictionary:
	return JSON.parse_string(CityPaths.district_manifest())


func person(id: String, kind: Dictionary, x: int, z: int) -> Dictionary:
	return {"id": id, "kind": kind, "display_name": id, "role": "", "badge": null,
		"appearance": {"palette": "3", "hair": "2"}, "seat": null, "presence": {"headline": "Present"},
		"pos": {"x": x, "z": z}}


func model_with(views: Array, minutes := 720) -> SceneModel:
	var m := SceneModel.new()
	m.apply({"rooms": [{"id": "room:plaza", "occupants": views, "waiting": []}], "in_transit": [], "time_of_day": minutes})
	return m


func host(views := [], minutes := 720, dir := DIR) -> StyleHost:
	var h := StyleHost.new()
	runner.root.add_child(h)
	assert_true(h.activate(dir, manifest(), model_with(views, minutes), Motion.new(), 0.0), "%s builds: %s" % [dir.get_file(), h.last_error])
	return h


func test_every_lit_material_is_toon() -> void:
	var h := host()
	var plain := 0
	var seen := 0
	for n in [h.pack.world] + h.pack.world.find_children("*", "", true, false):
		for m in Toon.materials_of(n):
			if m is BaseMaterial3D and m.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
				seen += 1
				if m.diffuse_mode != BaseMaterial3D.DIFFUSE_TOON:
					plain += 1
	assert_true(seen > 50, "the city has materials (%d)" % seen)
	assert_eq(plain, 0, "none left un-toon")
	assert_true(h.pack.rig.camera.get_node_or_null("InkLines") != null, "the overhead camera inks the city")
	h.free()


func test_people_are_inked_faced_and_drawn_simply_from_afar() -> void:
	var h := host([person("person:a", {"type": "Human", "tier": "Registered"}, 0, 0)])
	var model: Node = h.pack.nodes["person:a"].get_node("Model")
	var top: GeometryInstance3D = model.find_child("top", true, false)
	assert_true(top.material_override.next_pass is ShaderMaterial, "an ink outline on the shirt")
	assert_eq(top.visibility_range_end, 45.0, "near parts give way at 45 m")
	var far: GeometryInstance3D = model.find_child("far", true, false)
	assert_eq(far.visibility_range_begin, 45.0, "the far body takes over there")
	assert_true(far.get_surface_override_material(0) != null, "painted as the near body")
	var face: GeometryInstance3D = model.find_child("face", true, false)
	assert_true(face.material_override == AnimeFace.material(), "the shared face material")
	var v: float = face.get_instance_shader_parameter("variant")
	assert_true(v >= 1.0 and v <= 3.0, "a resident's face is not A1's: %s" % v)
	h.free()


func test_a1_looks_as_the_sheets_draw_it() -> void:
	var h := host([person("city:librarian", {"type": "CityRoleAgent"}, 0, 0)])
	var model: Node = h.pack.nodes["city:librarian"].get_node("Model")
	assert_true(model.find_child("hair_0", true, false).visible, "hair tied up")
	for k in [1, 2, 3]:
		var other = model.find_child("hair_%d" % k, true, false)
		assert_true(other == null or not other.visible, "no other hair")
	assert_eq(model.find_child("hair_0", true, false).material_override.albedo_color.to_html(false), "2b2e6a", "navy")
	assert_eq(model.find_child("face", true, false).get_instance_shader_parameter("variant"), 0.0, "A1's face")
	assert_true(model.find_child("jacket", true, false) != null and model.find_child("badge", true, false) != null, "the uniform and the leaf badge")
	h.free()


func test_glass_lights_up_at_night() -> void:
	var h := host([], 1320)
	var lit: Array = h.pack.town.glass_materials.filter(func(g): return g.emission_energy_multiplier > 0.5)
	assert_true(not lit.is_empty(), "glass glows after dark")
	assert_eq(lit[0].diffuse_mode, BaseMaterial3D.DIFFUSE_TOON, "and it is still toon")
	h.free()


func test_rain_wets_the_streets_and_opens_umbrellas_outdoors_only() -> void:
	var h := host([person("person:out", {"type": "Human", "tier": "Registered"}, 0, 800),
		person("person:in", {"type": "Human", "tier": "Registered"}, -2600, -800)], 1250)
	h.pack.set_rain(0.8)
	var out_umbrella: Node3D = h.pack.nodes["person:out"].get_node("Model").find_child("umbrella", true, false)
	var in_umbrella: Node3D = h.pack.nodes["person:in"].get_node("Model").find_child("umbrella", true, false)
	assert_true(out_umbrella.visible, "an umbrella in the square")
	assert_true(not in_umbrella.visible, "none in the workshop")
	assert_true(h.pack._streaks.any(func(s): return s.visible), "lamps streak on the wet ground")
	h.pack.set_rain(0.0)
	assert_true(not out_umbrella.visible, "furled when it stops")
	h.free()


func test_leaving_the_style_restores_the_viewport() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	h.activate(DIR, manifest(), SceneModel.new(), Motion.new(), 0.0)
	assert_eq(runner.root.msaa_3d, h.pack.msaa_level(), "the style's MSAA while anime")
	h.activate("res://styles/lowpoly_tropical", manifest(), SceneModel.new(), Motion.new(), 0.0)
	assert_eq(runner.root.msaa_3d, int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0)), "the project's own for the next style")
	h.free()


func test_the_river_runs_low_enough_for_the_bridge_arches() -> void:
	var h := host()
	assert_eq(h.pack.town.water_y, -2.0, "the anime river surface")
	var boat := false
	for b in h.pack.boats:
		boat = true
		assert_true(absf(b.position.y - -2.0) < 0.1, "boats float on it: %s" % b.position.y)
	assert_true(boat, "boats are moored")
	h.free()


func test_only_glass_with_rooms_behind_it_is_see_through() -> void:
	var hall := StandardMaterial3D.new()
	hall.resource_name = "glass"
	hall.resource_path = "res://styles/anime_cel/assets/hall_window_wall.glb::mat_glass_test"
	var tower := StandardMaterial3D.new()
	tower.resource_name = "glass_tower"
	tower.resource_path = "res://styles/anime_cel/assets/tower_a.glb::mat_glass_test"
	Toon.to_toon(hall)
	Toon.to_toon(tower)
	assert_eq(hall.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "the workshop's windows show its room")
	assert_true(hall.albedo_color.a < 0.5, "mostly clear")
	assert_eq(tower.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "a tower's glass stays opaque: no room behind")


func test_floors_are_laid_plain_not_in_boards() -> void:
	var h := host()
	assert_true(h.pack.world.find_child("Floorboards", true, false) == null, "no inked plank gaps indoors")
	h.free()


func test_every_piece_the_city_places_is_in_the_kit() -> void:
	var h := host()
	assert_eq(Array(h.pack.missing_scenes), [], "no placeholders in the city")
	h.free()


func test_planting_fills_its_footprint_where_people_walk() -> void:
	# Palms, street trees and shrubs are drawn as wide as their footprint's
	# disc in the walking band, whatever height each grows to, so nothing
	# the grid blocks round them stands clear of them.
	var h := host()
	var kinds := StylePack.kinds()
	var kind_of := {}
	for p in CityGeometry.placements(manifest()):
		kind_of[p["id"]] = p["kind"]
	var seen := {}
	for path in h.pack._planted:
		var reach: float = h.pack.town.band_reach(path, not "shrub" in path)
		for mmi in h.pack._chunks(h.pack._planted[path]):
			var ids: PackedStringArray = mmi.get_meta("placement_ids")
			var xforms: Array = mmi.get_meta("instance_xforms")
			for k in ids.size():
				var kind := str(kind_of.get(ids[k], ""))
				if not kind in ["palm", "street-tree", "shrub"]:
					continue
				var basis: Basis = xforms[k].basis
				var r: float = kinds[kind]["footprint"][0]["r"] / 100.0
				var drawn := Vector2(basis.x.x, basis.x.z).length() * reach
				assert_true(absf(drawn - r) < 1e-3, "%s is drawn %f m round where people walk, its footprint %f" % [ids[k], drawn, r])
				seen.get_or_add(kind, {})[snappedf(basis.y.length(), 0.01)] = true
	for kind in ["palm", "street-tree", "shrub"]:
		assert_true(seen.get(kind, {}).size() > 5, "%s grow to many heights (%s)" % [kind, seen.get(kind, {}).keys()])
	h.free()


func test_every_block_s_garden_wall_has_a_closed_gate_toward_its_nearest_street() -> void:
	# The voxel style builds its blocks itself, with the same walls.
	for dir in [DIR, "res://styles/voxel"]:
		_gates_face_their_streets(dir)


func _gates_face_their_streets(dir: String) -> void:
	var h := host([], 720, dir)
	var blocks := 0
	for p in CityGeometry.placements(manifest()):
		if not str(p["kind"]).begins_with("block-"):
			continue
		blocks += 1
		var lot := CityGeometry.lot(p)
		var street := CityGeometry.nearest_street(manifest(), lot.get_center())
		var node: Node3D = h.pack.placement_nodes[p["id"]]
		var gates := node.find_children("GardenGate", "", true, false)
		assert_eq(gates.size(), 1, "%s has one gate" % p["id"])
		if gates.size() != 1:
			continue
		var gate := KitTown.band_box_of(gates[0])
		# Which side of the lot the gate stands on, and which faces the street.
		var sides := {"north": absf(gate.get_center().y - lot.position.y), "south": absf(gate.get_center().y - lot.end.y),
			"west": absf(gate.get_center().x - lot.position.x), "east": absf(gate.get_center().x - lot.end.x)}
		var facing := {"north": lot.position.y - street.y, "south": street.y - lot.end.y,
			"west": lot.position.x - street.x, "east": street.x - lot.end.x}
		var on: String = sides.keys().reduce(func(a, b): return a if sides[a] < sides[b] else b)
		# The side the street lies farthest beyond.
		var toward: String = facing.keys().reduce(func(a, b): return a if facing[a] > facing[b] else b)
		assert_eq(on, toward, "%s's gate faces its nearest street" % p["id"])
		assert_true(lot.grow(0.001).encloses(gate), "%s's gate stands on its lot: %s in %s" % [p["id"], gate, lot])
		var across := gate.size.x if on in ["north", "south"] else gate.size.y
		assert_true(across >= 1.2, "%s's gate is a gateway wide (%f m)" % [p["id"], across])
	assert_true(blocks > 20, "the district's blocks (%d)" % blocks)
	h.free()


func test_fences_stand_just_off_the_floor_they_edge() -> void:
	# Each railing module and post is set off its fence's line, away from
	# the floor, by its own depth where people walk and a centimetre: none
	# of it stands on a room's floor across the run, and it stands within
	# 2 cm of it.
	var h := host()
	var pack = h.pack
	var checked := 0
	for fence in pack.scenery_nodes.filter(func(n): return str(n.get_meta("scenery", "")) == "fence"):
		for part in [["Railing", "railing"], ["Posts", "railing-post"]]:
			var box: Rect2 = pack.town.band_box(str(pack.resolve("props", part[1]).get("scene", "")))
			for holder in fence.find_children(part[0] + "*", "", false, false):
				for mmi in pack._chunks(holder):
					for x in mmi.get_meta("instance_xforms"):
						# A railing's two faces across the run, at its middle (a
						# module is turned along its run); a post's corners.
						var points := [Vector2(box.get_center().x, box.position.y), Vector2(box.get_center().x, box.end.y)]
						if part[1] == "railing-post":
							points = [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]
						var gap := INF
						for q in points:
							var w: Vector3 = x * Vector3(q.x, 0, q.y)
							var c := Vector2(w.x, w.z)
							assert_true(not pack._room_under(c).has_area(), "a %s at %s stands off the floor (%s)" % [part[1], x.origin, c])
							for r in pack.room_rects.values():
								var rr := CityGeometry.rect_m(r["rect"])
								gap = minf(gap, Vector2(maxf(maxf(rr.position.x - c.x, 0.0), c.x - rr.end.x),
									maxf(maxf(rr.position.y - c.y, 0.0), c.y - rr.end.y)).length())
						assert_true(gap < 0.02, "a %s at %s stands within 2 cm of the floor (%f)" % [part[1], x.origin, gap])
						checked += 1
	assert_true(checked > 20, "the district's fences (%d pieces)" % checked)
	h.free()


func test_a_filled_piece_fills_its_footprint_at_any_right_angle_turn() -> void:
	# The shelter (4.3 m by 1.2 m where people walk) filling a flower bed's
	# 3.1 m by 1.1 m footprint, turned within it by each right angle: its
	# band slice is the footprint wherever it stands turned.
	var h := host()
	var pack = h.pack
	var path := "assets/tram_shelter.glb"
	var p := {"kind": "flowerbed", "pos": Vector2(0, -1000), "facing": 0.0}
	var fp: Rect2 = pack._drawn_local(p)
	for turn in [0.0, 90.0, 180.0, 270.0]:
		var holder := Node3D.new()
		var piece: Node3D = pack._scene(path)
		holder.add_child(piece)
		piece.position = Vector3(p["pos"].x, 0, p["pos"].y)
		piece.rotation.y = pack._facing_rotation(turn)
		pack._fill_footprint(piece, path, p, turn)
		var drawn := KitTown.band_box_of(holder)
		var want := Rect2(fp.position + p["pos"], fp.size)
		assert_true(drawn.position.distance_to(want.position) < 1e-3 and drawn.end.distance_to(want.end) < 1e-3,
			"turned %d, it fills %s: %s" % [turn, want, drawn])
		holder.free()
	h.free()


func test_lamp_lights_shine_from_the_lanterns() -> void:
	var h := host([], 1320)
	assert_true(h.pack.lamps.size() > 3, "the district has lamps")
	for lamp in h.pack.lamps:
		assert_true(lamp.position.y > 1.5, "a light up in its lantern, not on the ground: %s" % lamp.position)
	h.free()


func test_a_plain_floor_lies_above_the_lawn() -> void:
	var h := host()
	var floor_node: MeshInstance3D = h.pack.world.find_child("Floor_room_workshop", true, false)
	assert_true(floor_node != null, "the workshop's floor is drawn")
	var top := floor_node.position.y + (floor_node.mesh as BoxMesh).size.y / 2.0
	assert_true(top >= -0.001, "its top at or above the ground's (-0.02), not level with it: %.3f" % top)
	h.free()


func test_the_sun_casts_no_shadow_when_it_is_only_a_dim_moon() -> void:
	var h := host([], 1320)
	assert_true(not h.pack.sun.shadow_enabled, "no moon shadows at night")
	h.pack.set_daylight(720.0)
	assert_true(h.pack.sun.shadow_enabled, "the sun casts shadows by day")
	h.free()
