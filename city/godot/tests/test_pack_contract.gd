## Every discovered style pack honours the same contract.
extends TestSuite

const KINDS := [
	{"type": "GuildAgent"}, {"type": "CityRoleAgent"},
	{"type": "PersonalAgent", "owner": "person:asha"}, {"type": "SimCitizen"},
	{"type": "Human", "tier": "Registered"},
]
const POSES := ["walking", "sitting", "standing", "queued"]
const HEADLINES := ["Working", "Waiting", "Queued", "Idle", "Done", "Present", "Offline", "Error", "Stale", "Unknown"]


func manifest() -> Dictionary:
	return JSON.parse_string(CityPaths.district_manifest())


func occupants_model() -> SceneModel:
	var views := []
	for k in KINDS.size():
		views.append({"id": "o:%d" % k, "kind": KINDS[k], "display_name": "O%d" % k, "role": "",
			"badge": "Ai" if k < 3 else ("Simulation" if k == 3 else null),
			"appearance": {"palette": str(k), "hair": str(k % 4)}, "seat": null,
			"presence": {"headline": "Working"}, "pos": {"x": 1000 + 60 * k, "z": 1000},
			"task_summary": "a public summary" if k == 0 else null,
			"using": {"target": "placement:square-noticeboard", "capability": "read", "anchor": 0} if k == 1 else null})
	var m := SceneModel.new()
	m.apply({"rooms": [{"id": "room:plaza", "occupants": views, "waiting": []}], "in_transit": [], "time_of_day": 420})
	return m


func test_at_least_one_pack_is_discovered() -> void:
	var h := StyleHost.new()
	assert_true(h.discover().size() >= 1, "a style pack exists under res://styles")
	h.free()


func test_every_pack_honours_the_contract() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	for dir in h.discover():
		var style: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("style.json")))
		assert_eq(StylePack.unmapped(style), [], dir + " maps every required key")
		assert_true(h.activate(dir, manifest(), occupants_model(), Motion.new(), 0.0), dir + " builds: " + h.last_error)
		var pack: StylePack = h.pack
		assert_eq(pack.nodes.size(), KINDS.size(), dir + " spawns every kind")
		for id in pack.nodes:
			for pose in POSES:
				pack.set_pose(id, pose)
			for headline in HEADLINES:
				pack.set_presence(id, headline)
			pack.place(id, Vector2(1200, 1100), Vector2(1, 0))
			pack.place(id, Vector2(1200, 1100), Vector2.ZERO)
		for minutes in [360, 720, 1260]:
			pack.set_time_of_day(minutes)
		for id in pack.nodes:
			assert_true(pack.labels.has(id), dir + " gives %s a name tag" % id)
			assert_true(not pack.labels[id].visible, dir + " hides name tags by default")
		pack.show_names(true)
		for id in pack.nodes:
			assert_true(pack.labels[id].visible, dir + " shows name tags on demand")
		assert_true("a public summary" in pack.labels["o:0"].text, dir + " shows a summary it was given")
		assert_true("reading" in pack.labels["o:1"].text, dir + " shows what someone is using: " + pack.labels["o:1"].text)
		var declared: Array = style.get("declared_placeholders", [])
		for key in pack.missing:
			assert_true(key in declared, dir + " has no mapping for " + key)
		pack.teardown()
		assert_eq(pack.get_child_count(), 0, dir + " tears down cleanly")
	h.free()


## Every style declares how displays draw their panels (`surfaces`: far,
## near, open), and draws a surface on each display that shows its chip
## far away and its headlines near.
func test_every_pack_declares_and_draws_surfaces() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	var m := manifest()
	var displays := Surfaces.of_layout(m, StylePack.kinds())
	assert_true(displays.size() >= 7, "the district has its displays (%d)" % displays.size())
	var notices := {"type": "Notices", "title": "Notices", "sample": true, "items": [{"date": "2026-09-01", "headline": "First", "body": "B"}]}
	for d in displays:
		d["panel"] = notices if d["id"] == "placement:square-noticeboard" else {}
	h.surfaces = displays
	for dir in h.discover():
		var style: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("style.json")))
		var surfaces: Dictionary = style.get("surfaces", {})
		assert_eq(surfaces.keys(), ["far", "near", "open"], dir + " declares surfaces far, near and open")
		assert_eq(str(surfaces.get("far", {}).get("icon_key", "")), "chip", dir + ": far draws the chip")
		var near: Dictionary = surfaces.get("near", {})
		assert_true(near.has("colour") and int(near.get("font_scale", 0)) >= 1 and int(near.get("max_lines", 0)) == 3,
			dir + ": near has a colour, a whole font scale and three lines: " + str(near))
		assert_true(h.activate(dir, m, occupants_model(), Motion.new(), 0.0), dir + " builds: " + h.last_error)
		var pack: StylePack = h.pack
		assert_eq(pack.surfaces.size(), displays.size(), dir + " knows every display")
		for id in pack.surfaces:
			assert_true(pack.surfaces[id]["node"] != null, dir + " draws " + id)
		h.update_surfaces(null)
		assert_eq(pack.surface_text("placement:square-noticeboard"), "Noticeboard · Sample", dir + ": the chip far away")
		h.update_surfaces(pack.surfaces["placement:square-noticeboard"]["pos"])
		assert_eq(pack.surface_text("placement:square-noticeboard"), "Sample\nNotices\n2026-09-01 · First", dir + ": the headlines near")
		assert_true(not pack.missing.has("surfaces/near"), dir + " maps surfaces/near")
	h.free()


func test_2d_occupants_are_depth_sorted_with_the_scenery() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	for dir in h.discover():
		var style: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("style.json")))
		if style.get("dimension") != "2d":
			continue
		h.activate(dir, manifest(), occupants_model(), Motion.new(), 0.0)
		for id in h.pack.nodes:
			var parent: Node = h.pack.nodes[id].get_parent()
			assert_true(parent is Node2D and parent.y_sort_enabled, dir + " sorts %s with walls and furniture" % id)
	h.free()


func test_every_pack_draws_scenery_buildings_cutaway_and_cameras() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	var m := manifest()
	var buildings := CutawayRule.facilities_of(m).keys()
	buildings.sort()
	for dir in h.discover():
		assert_true(h.activate(dir, m, occupants_model(), Motion.new(), 0.0), dir + " builds: " + h.last_error)
		var pack: StylePack = h.pack
		var ids := pack.facility_ids()
		ids.sort()
		assert_eq(ids, buildings, dir + " knows the buildings")
		assert_true(pack.scenery_count() >= m["scenery"].size(), dir + " draws every scenery item")
		var fences := pack.scenery_nodes.filter(func(n): return n.get_meta("kind", "") == "fence")
		assert_eq(fences.size(), m["scenery"].filter(func(i): return i["kind"] == "fence").size(), dir + " draws every fence")
		var total := 0
		for f in fences:
			# Railing is drawn as tiled pieces (MultiMeshes, perhaps chunked)
			# or as single pieces: count every piece.
			var parts := 0
			for c in f.get_children():
				var tiled: Array = [c] if c is MultiMeshInstance3D else c.find_children("*", "MultiMeshInstance3D", true, false)
				if tiled.is_empty():
					parts += 1
				for t in tiled:
					parts += t.multimesh.instance_count
			assert_true(parts >= 2, dir + " lays railing along each fence: %d pieces" % parts)
			total += parts
		assert_true(total > 100, dir + " lays railing all round the city: %d pieces" % total)
		for node in pack.scenery_nodes:
			assert_true(node.get_child_count() > 0, dir + " draws something for " + str(node.name))
		for id in buildings:
			assert_eq(pack.shell_state(id).get("roof"), true, dir + " roofs " + id)
			pack.set_open(id, true)
			assert_true(pack.is_open(id), dir + " opens " + id)
			assert_eq(pack.shell_state(id).get("roof"), false, dir + " lifts the roof off " + id)
			pack.set_open(id, false)
			assert_true(not pack.is_open(id), dir + " closes " + id)
			assert_eq(pack.shell_state(id).get("roof"), true, dir + " puts the roof back on " + id)
			# With roofs kept on, opening drops the near walls under the roof.
			pack.set_keep_roofs(true)
			pack.set_open(id, true)
			assert_eq(pack.shell_state(id).get("roof"), true, dir + " keeps the roof on " + id)
			pack.set_keep_roofs(false)
			assert_eq(pack.shell_state(id).get("roof"), false, dir + " lifts it when roofs may come off " + id)
			pack.set_open(id, false)
		# Open ground is walked, not drawn: the scenery is its floor, and
		# the district framing stays on the district's own rooms.
		var framed: Rect2 = pack.rig.bounds if pack.get("rig") != null else pack.district
		# The line's platforms are left out of it (the Avenue stop's, at
		# x = 52..68 m, would widen it by half): see test_vehicles.
		assert_eq(framed, Rect2(-34, -14, 70, 44), dir + " frames the district, not the whole city")
		var presets: Array = pack.camera_presets()
		for want in ["topdown", "diagonal", "street"]:
			assert_true(want in presets, dir + " offers " + want)
		for preset in presets:
			if preset != "fpv":
				assert_true(pack.set_camera_preset(preset), dir + " applies " + preset)
	h.free()


func test_a_person_looks_the_same_in_the_3d_styles() -> void:
	# Skin is skin[k % 4], hair colour hair_colours[(k + 1) % 4] and
	# trousers bottoms[(k + k / 4) % 4] for outfit k, as the pixel sheets
	# draw them, so no style reshuffles who
	# someone is.
	var h := StyleHost.new()
	runner.root.add_child(h)
	for dir in h.discover():
		if not dir.get_file() in ["lowpoly_tropical", "voxel"]:
			continue
		assert_true(h.activate(dir, manifest(), SceneModel.new(), Motion.new(), 0.0), dir)
		var pack = h.pack
		for k in [0, 2, 5, 7]:
			var id := "person:look-%d" % k
			pack.spawn({"id": id, "kind": {"type": "Human", "tier": "Registered"}, "display_name": id,
				"appearance": {"palette": str(k), "hair": "1"}, "pos": {"x": 0, "z": 0}}, "standing")
			var model: Node = pack.nodes[id].get_node("Model")
			var skin: Color = model.find_child("skin", true, false).material_override.albedo_color
			var hair: Color = model.find_child("hair_1", true, false).material_override.albedo_color
			var want_skin := Color.html(pack.style["skin"][k % 4])
			var want_hair := Color.html(pack.style["hair_colours"][(k + 1) % 4])
			var bottom: Color = model.find_child("bottom", true, false).material_override.albedo_color
			var want_bottom := Color.html(pack.style["bottoms"][(k + k / 4) % 4])
			assert_true(bottom.is_equal_approx(want_bottom), "%s outfit %d: trousers %s, want %s" % [dir.get_file(), k, bottom, want_bottom])
			assert_true(skin.is_equal_approx(want_skin), "%s outfit %d: skin %s, want %s" % [dir.get_file(), k, skin, want_skin])
			assert_true(hair.is_equal_approx(want_hair), "%s outfit %d: hair %s, want %s" % [dir.get_file(), k, hair, want_hair])
	h.free()


## Where seat `node` draws between heights `band` (metres), as points in
## its seat's frame: the sitter on the origin, facing -z.
func seat_points(node: Node3D, seat: Dictionary, band: Vector2) -> PackedVector2Array:
	var holder := Node3D.new()
	var copy: Node3D = node.duplicate()
	copy.transform = node.transform
	holder.add_child(copy)
	var to_seat := Transform2D(deg_to_rad(float(seat.get("facing", 0))), CityGeometry.pt_m(seat["pos"])).affine_inverse()
	var out := PackedVector2Array()
	for q in KitTown.band_points_of(holder, band):
		out.append(to_seat * q)
	holder.free()
	return out


func bounds(points: PackedVector2Array) -> Rect2:
	var box := Rect2(points[0], Vector2.ZERO)
	for q in points:
		box = box.expand(q)
	return box


## Benches and café chairs are drawn at their kits' own size, not stretched
## round the sitter: a bench's sitter sits in the middle of its length with
## the backrest close behind, and a café chair is its sitter's width.
func test_the_3d_styles_seat_people_on_benches_and_chairs_of_their_own_size() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	# The layout the core gives, grid and all, so each seat is fitted to the
	# cells as it is in the city.
	var w = ClassDB.instantiate("CityWorld")
	assert_eq(JSON.parse_string(w.load(CityPaths.district_manifest(), CityPaths.district_feed(), 7, 0)).get("ok"), true, "the district loads")
	var layout: Dictionary = JSON.parse_string(w.layout_json())
	var seats := {}
	for f in layout["city"]["districts"][0]["facilities"]:
		for r in f["rooms"]:
			for s in r.get("seats", []):
				seats[s["id"]] = s
	for dir in h.discover():
		assert_true(h.activate(dir, layout, SceneModel.new(), Motion.new(), 0.0), dir)
		var pack = h.pack
		if pack.get("rig") == null:
			continue
		var style: String = dir.get_file()
		assert_true(pack.walkable_grid().cols > 0, "%s: fitted to the core's grid" % style)
		var benches := 0
		for id in seats:
			var seat: Dictionary = seats[id]
			var node = pack.placement_nodes.get(id)
			if not node is Node3D or fmod(float(seat.get("facing", 0)), 90.0) != 0.0:
				continue
			if seat.get("kind") == "bench":
				benches += 1
				var whole := bounds(seat_points(node, seat, Vector2(0.25, 1.9)))
				var pad := bounds(seat_points(node, seat, Vector2(0.38, 0.5)))
				# The back, above the armrests.
				var back := seat_points(node, seat, Vector2(0.7, 0.9))
				var behind := INF
				for q in back:
					if q.y > 0.05:
						behind = minf(behind, q.y)
				assert_true(whole.size.x <= 1.65 and whole.size.y <= 0.63, "%s %s: a bench of its own size, %s" % [style, id, whole.size])
				assert_true(absf(pad.get_center().x) < 0.02, "%s %s: the sitter in the middle of the seat (%.2f off)" % [style, id, pad.get_center().x])
				assert_true(pad.position.y <= -0.2 and pad.end.y >= 0.12, "%s %s: the sitter on the seat, %s" % [style, id, pad])
				assert_true(behind <= 0.3, "%s %s: the backrest close behind the sitter (%.2f m)" % [style, id, behind])
			elif seat.get("kind") == "cafe-table":
				var chair := bounds(seat_points(node, seat, Vector2(0.25, 1.9)))
				# Its sitter's own width (the kind's sides, 25 cm either side,
				# where the grid's cells allow), no wider.
				assert_true(chair.size.x <= 0.51 and chair.size.y <= 0.5, "%s %s: a chair of its own size, %s" % [style, id, chair.size])
		assert_true(benches >= 8, "%s: the district's benches at right angles (%d)" % [style, benches])
	h.free()


## Someone on the bridge stands on its deck, not in it: every pack lifts
## walkers by its style's `bridge_deck` (eased up its `bridge_ramp` at
## each end), and sets them down again on land.
func test_walkers_on_the_bridge_stand_on_its_deck() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	for dir in h.discover():
		assert_true(h.activate(dir, manifest(), occupants_model(), Motion.new(), 0.0), dir + " builds")
		var pack: StylePack = h.pack
		var deck := float(pack.style.get("bridge_deck", 0.0))
		var lift := func() -> float:
			var n: Node = pack.nodes["o:0"]
			return n.position.y if n is Node3D else -n.get_node("Body").position.y / 16.0
		pack.place("o:0", Vector2(-4000, 0), Vector2.ZERO)
		var land: float = lift.call()
		pack.place("o:0", Vector2(-5800, 2300), Vector2.ZERO)
		assert_true(absf(lift.call() - land - deck) < 0.07, dir + " lifts a walker mid-bridge (to the pixel) by its deck (%.2f m): %.2f" % [deck, lift.call() - land])
		pack.place("o:0", Vector2(-4000, 0), Vector2.ZERO)
		assert_true(absf(lift.call() - land) < 0.01, dir + " and sets them down on land")
	h.free()


## Boats moor clear of the bridge, never through it.
func test_no_boat_is_moored_through_the_bridge() -> void:
	var h := StyleHost.new()
	runner.root.add_child(h)
	for dir in h.discover():
		assert_true(h.activate(dir, manifest(), occupants_model(), Motion.new(), 0.0), dir + " builds")
		var pack: StylePack = h.pack
		for boat in pack.get("boats") if pack.get("boats") != null else []:
			for br in pack.bridges:
				var d: float = absf(boat.position.z - br["a"].y)
				assert_true(d > br["width"] / 2.0 + 4.0, dir + " moors a boat %.1f m from the bridge" % d)
	h.free()
