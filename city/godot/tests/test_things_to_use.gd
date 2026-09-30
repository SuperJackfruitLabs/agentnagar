## The things to use drawn in every style (interactions Part A, Tasks 6
## and 7): each style draws the noticeboard, plaque, kiosk, steps, low
## wall, fountain and meadow from its own kit; a display's text lies on
## (in pixel art, over) the face it draws and fits it; a perch has a seat
## at each sit anchor, and its sitters are drawn on them; and a meadow is
## planted inside its lot, in 3D as instances whose bend weight (UV2.x)
## rises from root to tip, in pixel art as clumps carrying their three
## rustle frames. Their fit to their footprints is the collision audit's
## (test_collision_audit.gd); in pixel art the audit's table is the kit's.
extends TestSuite

const Solids2D = preload("res://tools/collision_audit/solids_2d.gd")
const PixelPack = preload("res://styles/pixel_art/pack.gd")

const STYLES := ["lowpoly_tropical", "anime_cel", "solarpunk", "neon_noir", "voxel"]
const DISPLAYS := ["placement:square-noticeboard", "placement:guild-hall-plaque", "placement:library-kiosk"]
const PERCHES := ["placement:library-steps", "placement:park-wall-1", "placement:park-wall-2", "placement:square-fountain"]
## The tram shelters, whose benches are perches too (spec section 1,
## criterion 2): one on each platform.
const SHELTERS := ["placement:shelter-square-north-1", "placement:shelter-square-north-2", "placement:shelter-square-south-1",
	"placement:shelter-avenue-north-1", "placement:shelter-avenue-south-1"]
const MEADOWS := ["placement:park-meadow-1", "placement:park-meadow-2", "placement:park-meadow-3"]
const NEW_KINDS := ["noticeboard", "plaque", "kiosk", "steps", "low-wall", "fountain-rim", "meadow"]


func booted(style: String):
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--as=none", "--style=" + style]))
	assert_true(not main.hud.error_label.visible, "booted: " + main.hud.error_label.text)
	return main


func _placement(main, id: String) -> Dictionary:
	for p in CityGeometry.placements(main.manifest):
		if p["id"] == id:
			return p
	return {}


## Anchor `a` of placement `p` (CityGeometry.placements) in the world:
## [place (metres), facing (degrees)].
static func _anchor_at(p: Dictionary, a: Dictionary) -> Array:
	var turn := Transform2D(deg_to_rad(float(p["facing"])), p["pos"])
	return [turn * (Vector2(a["at"]["x"], a["at"]["z"]) / 100.0), float(p["facing"]) + float(a.get("facing", 0))]


func test_every_3d_style_draws_the_new_kinds_from_its_kit() -> void:
	for style in STYLES:
		var main = booted(style)
		var pack = main.host.pack
		for kind in NEW_KINDS:
			var skin: Dictionary = pack.resolve("props", kind)
			assert_true(not skin.has("box"), "%s: %s is drawn from its kit, not a placeholder box" % [style, kind])
		for path in pack.missing_scenes:
			assert_true(false, "%s: no kit piece missing (%s)" % [style, path])
		for id in DISPLAYS + PERCHES + MEADOWS:
			assert_true(pack.placement_nodes.has(id), "%s: %s is drawn" % [style, id])
		main.free()


func test_a_display_mounts_its_text_on_the_face_it_draws() -> void:
	for style in STYLES:
		var main = booted(style)
		var pack = main.host.pack
		for id in DISPLAYS:
			var s: Dictionary = pack.surfaces[id]
			var face = pack.display_face(id)
			assert_true(face is Transform3D, "%s: %s's piece carries its `display` node" % [style, id])
			if not face is Transform3D:
				continue
			var normal := Vector2(sin(deg_to_rad(float(s["facing"]))), -cos(deg_to_rad(float(s["facing"]))))
			var out := -(face as Transform3D).basis.z
			assert_true(Vector2(out.x, out.z).normalized().dot(normal) > 0.99, "%s: %s's face looks out along its anchor" % [style, id])
			var at := Vector2(face.origin.x, face.origin.z)
			assert_true(at.distance_to(s["pos"] / 100.0) < 0.1, "%s: %s's face is by its display anchor (%s)" % [style, id, at])
			var bottom := float(s["height"]) / 100.0
			var top := bottom + float(s["size"]["d"]) / 100.0
			assert_true(face.origin.y > bottom and face.origin.y < top, "%s: %s's face is %.2f m up, in its anchor's span" % [style, id, face.origin.y])
			var label: Label3D = s["node"]
			assert_true(Vector2(label.position.x, label.position.z).distance_to(at + normal * Pack3D.SURFACE_LIFT_M) < 0.01,
				"%s: %s's text is mounted on its face" % [style, id])
		main.free()


func test_a_perch_has_a_seat_at_each_sit_anchor() -> void:
	for style in STYLES:
		var main = booted(style)
		var pack = main.host.pack
		for id in PERCHES + SHELTERS:
			var p := _placement(main, id)
			var node: Node3D = pack.placement_nodes[id]
			var sits: Array = StylePack.kinds()[p["kind"]]["anchors"].filter(func(a): return a["type"] == "sit")
			assert_true(not sits.is_empty(), "%s: %s has sit anchors" % [style, id])
			# The body, then a seat per anchor, in the anchors' order.
			assert_eq(node.get_child_count(), 1 + sits.size(), "%s: %s has its body and a seat per sit anchor" % [style, id])
			for k in sits.size():
				var seat: Node3D = node.get_child(1 + k)
				var want: Array = _anchor_at(p, sits[k])
				assert_true(Vector2(seat.position.x, seat.position.z).distance_to(want[0]) < 0.005, "%s: %s's seat %d is at its anchor" % [style, id, k])
				var front := seat.basis * Vector3(0, 0, -1)
				var facing := deg_to_rad(want[1])
				assert_true(Vector2(front.x, front.z).dot(Vector2(sin(facing), -cos(facing))) > 0.99, "%s: %s's seat %d faces its sitter's way" % [style, id, k])
		main.free()


## One perch of each kind, a tram shelter's bench among them.
const PERCH_KINDS := ["placement:library-steps", "placement:park-wall-1", "placement:square-fountain",
	"placement:shelter-square-south-1"]


## A perch's sitter is drawn on its seat, whatever its style: the core
## keeps a sitter at the middle of the anchor's 25 cm cell, while the seat
## stands at the anchor itself (up to 12 cm away, and on the fountain's
## diagonals past the seat's front edge). Sitting after its last move,
## moved again while it sits, and standing up where the core has it.
func test_a_perch_sitter_is_drawn_on_its_seat() -> void:
	for style in STYLES:
		var main = booted(style)
		var pack = main.host.pack
		for id in PERCH_KINDS:
			var p := _placement(main, id)
			var node: Node3D = pack.placement_nodes[id]
			var anchors: Array = StylePack.kinds()[p["kind"]]["anchors"]
			var k := 0
			for index in anchors.size():
				if anchors[index]["type"] != "sit":
					continue
				var seat: Node3D = node.get_child(1 + k)
				k += 1
				var want: Array = _anchor_at(p, anchors[index])
				var core: Vector2 = main.nav.centre(main.nav.cell_of(want[0] * 100.0))
				var who := "o:sitter"
				var view := {"id": who, "kind": {"type": "Human", "tier": "Registered"}, "display_name": "Sitter",
					"appearance": {"palette": "1", "hair": "1"}, "seat": null, "presence": {"headline": "Present"},
					"pos": {"x": core.x, "z": core.y}, "facing": posmod(int(want[1]), 360), "using": null}
				pack.spawn(view, "standing")
				pack.place(who, core, Vector2.ZERO)
				view["using"] = {"target": id, "capability": "sit", "anchor": index}
				pack.update_view(view)
				pack.set_pose(who, "sitting")
				var body: Node3D = pack.nodes[who]
				var on := Pack3D._to_world(seat)
				var at := Vector2(body.position.x, body.position.z)
				assert_true(at.distance_to(Vector2(on.origin.x, on.origin.z)) < 0.03,
					"%s: %s's sitter %d is drawn on its seat (%.3f m off; the core's place is %.3f m off)"
					% [style, id, index, at.distance_to(Vector2(on.origin.x, on.origin.z)), (core / 100.0).distance_to(Vector2(on.origin.x, on.origin.z))])
				var front := body.basis * Vector3(0, 0, -1)
				var seat_front := on.basis * Vector3(0, 0, -1)
				assert_true(Vector2(front.x, front.z).normalized().dot(Vector2(seat_front.x, seat_front.z).normalized()) > 0.99,
					"%s: %s's sitter %d faces as its seat" % [style, id, index])
				pack.place(who, core, Vector2.ZERO)
				assert_true(Vector2(body.position.x, body.position.z).distance_to(Vector2(on.origin.x, on.origin.z)) < 0.03,
					"%s: %s's sitter %d stays on its seat as it is placed again" % [style, id, index])
				view["using"] = null
				pack.update_view(view)
				assert_true(Vector2(body.position.x, body.position.z).distance_to(core / 100.0) < 0.001,
					"%s: %s's sitter %d stands up where the core has it" % [style, id, index])
				pack.despawn(who)
			assert_true(k > 0, "%s: %s has a sitter drawn" % [style, id])
		main.free()


## How Label3D wraps AUTOWRAP_WORD_SMART text.
const SMART_WRAP := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE


## A display's text fits the face it lies on: the display node carries
## the drawn face's size, the text wraps to that face's width (the kiosk's
## at 0.54 m), and, shrunk or short of its last headlines when it must, it
## stays within the face below its top, near and far. "Sample" stays.
func test_a_displays_text_fits_its_face() -> void:
	for style in STYLES:
		var main = booted(style)
		var pack = main.host.pack
		var notices: Dictionary = pack.surfaces["placement:square-noticeboard"]["panel"]
		assert_eq(notices.get("type"), "Notices", "%s: the noticeboard's panel" % style)
		for id in DISPLAYS:
			var s: Dictionary = pack.surfaces[id]
			var face = pack.display_face(id)
			if not face is Transform3D:
				assert_true(false, "%s: %s draws its face" % [style, id])
				continue
			var face_w: float = face.basis.x.length()
			var face_h: float = face.basis.y.length()
			var anchor_w := float(s["size"]["w"]) / 100.0
			var anchor_h := float(s["size"]["d"]) / 100.0
			# Its height is the kit's; its width as the fit stretches the piece.
			assert_true(face_w > anchor_w * 0.5 and face_w < anchor_w * 1.5 and face_h > anchor_h * 0.5 and face_h <= anchor_h + 0.01,
				"%s: %s's display node carries its drawn face's size (%.2f x %.2f m; the anchor's %.2f x %.2f)"
				% [style, id, face_w, face_h, anchor_w, anchor_h])
			# Its own panel, then the notices (the most text there is) on
			# every face: the narrow kiosk and the small plaque too.
			var own: Dictionary = s["panel"]
			for case in [[Surfaces.NEAR, own], [Surfaces.FAR, own], [Surfaces.NEAR, notices]]:
				var level: String = case[0]
				s["panel"] = case[1]
				s["level"] = level
				pack.show_surface(id, level)
				var label: Label3D = s["node"]
				var size: Vector2 = label.font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, label.width,
					label.font_size, -1, SMART_WRAP) * label.pixel_size
				var wrap := label.width * label.pixel_size
				assert_true(wrap <= face_w * 0.9 + 0.001, "%s: %s's text wraps within its face (%.3f of %.3f m)" % [style, id, wrap, face_w])
				assert_true(size.x <= minf(face_w, anchor_w) * 0.9 + 0.001 and size.y <= minf(face_h, anchor_h) * 0.9 + 0.001,
					"%s: %s's %s text (%s), %.2f x %.2f m, fits its face" % [style, id, level, s["panel"].get("type"), size.x, size.y])
				var bottom: float = face.origin.y - face_h / 2.0
				assert_true(label.position.y - size.y >= bottom - 0.001 and label.position.y <= face.origin.y + face_h / 2.0,
					"%s: %s's %s text runs from %.2f to %.2f m, on its face (%.2f to %.2f)"
					% [style, id, level, label.position.y, label.position.y - size.y, bottom, bottom + face_h])
				if s["panel"].get("sample", false):
					assert_true(("Sample" in label.text), "%s: %s's %s text says Sample" % [style, id, level])
				if level == Surfaces.NEAR:
					assert_true(label.text.begins_with("Sample\n") or not s["panel"].get("sample", false), "%s: %s's near text starts Sample" % [style, id])
			s["panel"] = own
			if id == "placement:library-kiosk":
				assert_true(absf(pack.surfaces[id]["node"].width * Pack3D.SURFACE_PIXEL_M - 0.54) < 0.01, "%s: the kiosk wraps at 0.54 m" % style)
		main.free()


## How close a meadow's clumps may stand: a planting grid's neighbours,
## each nudged up to 30% of a step toward the other, stay 40% of a step
## apart, and a step is 12 cm or more on the district's lots, so 4.8 cm.
## Clumps pushed back inside the lot along its edges came closer (3 cm).
const MEADOW_APART_M := 0.045


func test_a_meadow_is_planted_inside_its_lot_with_bend_weights() -> void:
	for style in STYLES:
		var main = booted(style)
		var pack = main.host.pack
		var planted := {}
		var roots_of := {}
		var meshes := []
		for n in pack.world.find_children("*Meadow*", "MultiMeshInstance3D", true, false):
			var ids: PackedStringArray = n.get_meta("placement_ids")
			var xforms: Array = n.get_meta("instance_xforms")
			var reach := _reach(n.multimesh.mesh)
			assert_eq(n.visibility_range_end, Pack3D.MEADOW_RANGE_M, "%s: a meadow's chunk is drawn only within %d m" % [style, Pack3D.MEADOW_RANGE_M])
			if not n.multimesh.mesh in meshes:
				meshes.append(n.multimesh.mesh)
			for k in ids.size():
				planted[ids[k]] = planted.get(ids[k], 0) + 1
				if not roots_of.has(ids[k]):
					roots_of[ids[k]] = []
				roots_of[ids[k]].append(Vector2(xforms[k].origin.x, xforms[k].origin.z))
				var lot := CityGeometry.lot(_placement(main, ids[k]))
				var x: Transform3D = xforms[k]
				var grown := reach * x.basis.get_scale().x
				assert_true(lot.grow(-grown + 1e-4).has_point(Vector2(x.origin.x, x.origin.z)),
					"%s: %s's clump %d stands wholly inside its lot" % [style, ids[k], k])
		for id in MEADOWS:
			# A clump every 25 cm or so across the lot.
			var lot := CityGeometry.lot(_placement(main, id))
			assert_true(planted.get(id, 0) >= int(lot.get_area() / 0.0625 * 0.9), "%s: %s is planted (%d clumps)" % [style, id, planted.get(id, 0)])
			# Spread over it, none piled on another along the lot's edges.
			var roots: Array = roots_of.get(id, [])
			var closest := INF
			for a in roots.size():
				for b in range(a + 1, roots.size()):
					closest = minf(closest, roots[a].distance_to(roots[b]))
			assert_true(closest >= MEADOW_APART_M, "%s: %s's clumps stand %.3f m apart at the closest" % [style, id, closest])
		assert_eq(meshes.size(), 2, "%s: grass and flower clumps" % style)
		for mesh in meshes:
			var lo := INF
			var hi := -INF
			var root := INF
			var tip := -INF
			for s in mesh.get_surface_count():
				var arrays: Array = mesh.surface_get_arrays(s)
				assert_true(arrays[Mesh.ARRAY_TEX_UV2] != null, "%s: a clump carries UV2" % style)
				if arrays[Mesh.ARRAY_TEX_UV2] == null:
					continue
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
				for v in verts.size():
					lo = minf(lo, uv2[v].x)
					hi = maxf(hi, uv2[v].x)
					if verts[v].y < 0.01:
						root = minf(root, uv2[v].x)
					if verts[v].y > 0.4:
						tip = maxf(tip, uv2[v].x)
			assert_true(absf(lo) < 0.01 and absf(hi - 1.0) < 0.01, "%s: bend weights run 0 to 1 (%.2f..%.2f)" % [style, lo, hi])
			assert_true(root < 0.01 and tip > 0.99, "%s: 0 at the roots, 1 at the tips" % style)
		main.free()


static func _reach(mesh: Mesh) -> float:
	var box := mesh.get_aabb()
	return Vector2(maxf(absf(box.position.x), absf(box.end.x)), maxf(absf(box.position.z), absf(box.end.z))).length()


# ---- Pixel art (Task 7) ----

const PIXEL := "pixel_art"


## The kit sprite a pixel node draws (its path under the pack's assets).
static func _kit_path(pack, node: Sprite2D) -> String:
	return node.texture.resource_path.trim_prefix(pack.pack_dir + "/").trim_prefix("assets/").replace("_night.png", ".png")


func test_pixel_art_draws_the_new_kinds_from_its_kit() -> void:
	var main = booted(PIXEL)
	var pack = main.host.pack
	assert_eq(pack.placeholders, 0, "pixel art: no sprite falls back to the magenta placeholder")
	for kind in NEW_KINDS:
		var skin: Dictionary = pack.resolve("props", kind)
		assert_true(not skin.has("ground"), "pixel art: %s is drawn from the kit, not painted" % kind)
		assert_true(not "placeholders/" in JSON.stringify(skin), "pixel art: %s is no placeholder" % kind)
	for id in DISPLAYS + PERCHES + MEADOWS:
		var node = pack.placement_nodes.get(id)
		assert_true(node is Node2D and pack.is_ancestor_of(node), "pixel art: %s is drawn" % id)
		for sprite in node.find_children("*", "Sprite2D", true, false) + ([node] if node is Sprite2D else []):
			var path := _kit_path(pack, sprite)
			assert_true(pack.kit_sprites.has(path), "pixel art: %s's %s is a kit sprite" % [id, path])
			assert_true(pack.kit_sprites.get(path, {}).has("band_shapes"), "pixel art: %s's %s declares its band" % [id, path])
	main.free()


## A surface's plate and an occupant's name tag y-sort with the world
## (PixelPack.LABEL_Z), so a wall, a roof or a lamp in front of one in the
## sort never draws over it and clips its "Sample" or its name.
func test_a_pixel_chip_or_label_sorts_above_every_world_sprite() -> void:
	var main = booted(PIXEL)
	var pack = main.host.pack
	var who := "o:labelled"
	var view := {"id": who, "kind": {"type": "Human", "tier": "Registered"}, "display_name": "Labelled",
		"appearance": {"palette": "1", "hair": "1"}, "seat": null, "presence": {"headline": "Present"},
		"pos": {"x": 0.0, "z": 0.0}, "facing": 0}
	pack.spawn(view, "standing")
	pack.update_view(view)
	pack.place(who, Vector2.ZERO, Vector2.ZERO)
	var highest := 0
	for n in pack.world.find_children("*", "Sprite2D", true, false):
		highest = maxi(highest, n.z_index)
	assert_true(pack.surfaces.size() > 0, "pixel art: at least one surface to check")
	for id in pack.surfaces:
		var root: Node2D = pack.surfaces[id]["node"]
		assert_true(root.z_index > highest, "pixel art: %s's plate sorts above every world sprite (%d > %d)" % [id, root.z_index, highest])
	assert_true(pack.labels.has(who), "pixel art: the occupant's name tag exists")
	assert_true(pack.labels[who].z_index > highest, "pixel art: an occupant's name tag sorts above every world sprite (%d > %d)" % [pack.labels[who].z_index, highest])
	pack.despawn(who)
	main.free()


## A surface inside a closed building is hidden, not merely sorted behind
## its roof: LABEL_Z draws it above the world now, so the y-sort can no
## longer hide it the way it hides the room itself. Hidden until the
## library opens, hidden again once it closes.
func test_a_pixel_surface_inside_a_closed_building_is_hidden_until_it_opens() -> void:
	var main = booted(PIXEL)
	var pack = main.host.pack
	var id := "placement:reading-shelf-1"
	assert_true(pack.surfaces.has(id), "pixel art: the reading room's shelf is a surface")
	assert_true(not pack.is_open("facility:library"), "pixel art: the library starts closed")
	assert_true(not pack.surfaces[id]["node"].visible, "pixel art: its chip is hidden while the library is closed")
	pack.set_open("facility:library", true)
	assert_true(pack.surfaces[id]["node"].visible, "pixel art: its chip shows once the library opens")
	pack.set_open("facility:library", false)
	assert_true(not pack.surfaces[id]["node"].visible, "pixel art: hidden again once it closes")
	main.free()


## An occupant's name tag inside a closed building is hidden the same
## way, and refreshed (not scanned every frame) as apply_open toggles
## the building it stands in.
func test_a_pixel_name_tag_inside_a_closed_building_is_hidden_until_it_opens() -> void:
	var main = booted(PIXEL)
	var pack = main.host.pack
	pack.show_names(true)
	var who := "o:reader"
	var view := {"id": who, "kind": {"type": "Human", "tier": "Registered"}, "display_name": "Reader",
		"appearance": {"palette": "1", "hair": "1"}, "seat": null, "presence": {"headline": "Present"},
		"pos": {"x": 2300.0, "z": -800.0}, "facing": 90}
	pack.spawn(view, "sitting")
	pack.update_view(view)
	pack.place(who, Vector2(2300, -800), Vector2.ZERO)
	assert_true(not pack.is_open("facility:library"), "pixel art: the library starts closed")
	assert_true(not pack.labels[who].visible, "pixel art: the reader's name tag is hidden while the library is closed")
	pack.set_open("facility:library", true)
	assert_true(pack.labels[who].visible, "pixel art: it shows once the library opens")
	pack.set_open("facility:library", false)
	assert_true(not pack.labels[who].visible, "pixel art: hidden again once it closes")
	pack.despawn(who)
	main.free()


## A kept roof (roofs on) covers an open building as a closed one's does:
## the chips and name tags inside stay hidden under it, and show when the
## roof lifts, whichever of the two changes last.
func test_a_pixel_chip_and_name_tag_inside_stay_hidden_under_a_kept_roof() -> void:
	var main = booted(PIXEL)
	var pack = main.host.pack
	pack.show_names(true)
	var id := "placement:reading-shelf-1"
	var who := "o:reader"
	var view := {"id": who, "kind": {"type": "Human", "tier": "Registered"}, "display_name": "Reader",
		"appearance": {"palette": "1", "hair": "1"}, "seat": null, "presence": {"headline": "Present"},
		"pos": {"x": 2300.0, "z": -800.0}, "facing": 90}
	pack.spawn(view, "sitting")
	pack.update_view(view)
	pack.place(who, Vector2(2300, -800), Vector2.ZERO)
	pack.set_keep_roofs(true)
	pack.set_open("facility:library", true)
	assert_true(pack.shell_state("facility:library")["roof"], "pixel art: open with roofs on, the library keeps its roof")
	assert_true(not pack.surfaces[id]["node"].visible, "pixel art: the shelf's chip stays hidden under the kept roof")
	assert_true(not pack.labels[who].visible, "pixel art: the reader's name tag stays hidden under the kept roof")
	pack.set_keep_roofs(false)
	assert_true(pack.surfaces[id]["node"].visible, "pixel art: the roof lifts: the chip shows")
	assert_true(pack.labels[who].visible, "pixel art: the roof lifts: the name tag shows")
	pack.set_keep_roofs(true)
	assert_true(not pack.surfaces[id]["node"].visible and not pack.labels[who].visible, "pixel art: roofs on again: both hidden")
	pack.despawn(who)
	main.free()


## pick() (a click or a tap) does not reach an occupant behind a closed
## wall, the same as it never could reach one hidden inside the shell
## before LABEL_Z; open, the same screen position reaches them.
func test_pick_ignores_an_occupant_inside_a_closed_building() -> void:
	var main = booted(PIXEL)
	var pack = main.host.pack
	var who := "o:reader"
	var view := {"id": who, "kind": {"type": "Human", "tier": "Registered"}, "display_name": "Reader",
		"appearance": {"palette": "1", "hair": "1"}, "seat": null, "presence": {"headline": "Present"},
		"pos": {"x": 2300.0, "z": -800.0}, "facing": 90}
	pack.spawn(view, "sitting")
	pack.update_view(view)
	pack.place(who, Vector2(2300, -800), Vector2.ZERO)
	var screen_pos: Vector2 = pack.get_viewport().get_canvas_transform() * (pack.nodes[who].global_position + Vector2(0, -16))
	assert_true(not pack.is_open("facility:library"), "pixel art: the library starts closed")
	assert_eq(pack.pick(screen_pos), "", "pixel art: a closed wall blocks the pick")
	pack.set_open("facility:library", true)
	assert_eq(pack.pick(screen_pos), who, "pixel art: open, the same screen position reaches them")
	pack.despawn(who)
	main.free()


## An outdoor chip and name tag are unaffected by any building's state:
## they show before anything opens, with every building open, and with
## every building closed again.
func test_an_outdoor_pixel_chip_and_name_tag_stay_visible_regardless_of_any_buildings_state() -> void:
	var main = booted(PIXEL)
	var pack = main.host.pack
	pack.show_names(true)
	var surface_id := "placement:square-noticeboard"
	var who := "o:outdoor"
	var view := {"id": who, "kind": {"type": "Human", "tier": "Registered"}, "display_name": "Outdoor",
		"appearance": {"palette": "1", "hair": "1"}, "seat": null, "presence": {"headline": "Present"},
		"pos": {"x": -1100.0, "z": 1000.0}, "facing": 0}
	pack.spawn(view, "standing")
	pack.update_view(view)
	pack.place(who, Vector2(-1100, 1000), Vector2.ZERO)
	assert_true(pack.surfaces[surface_id]["node"].visible, "pixel art: an outdoor chip shows before anything opens")
	assert_true(pack.labels[who].visible, "pixel art: an outdoor name tag shows before anything opens")
	for id in pack.shells:
		pack.set_open(id, true)
	assert_true(pack.surfaces[surface_id]["node"].visible, "pixel art: still visible with every building open")
	assert_true(pack.labels[who].visible, "pixel art: still visible with every building open")
	for id in pack.shells:
		pack.set_open(id, false)
	assert_true(pack.surfaces[surface_id]["node"].visible, "pixel art: still visible with every building closed")
	assert_true(pack.labels[who].visible, "pixel art: still visible with every building closed")
	pack.despawn(who)
	main.free()


## The collision audit's table (solids_2d.gd FOOT, TURNED_FOOT) holds each
## new kit sprite as its model declares it in the band (kit.json
## `band_shapes`, turned to its `facing`), which render.py holds the model
## to: so the table cannot go stale when a model changes.
func test_the_audit_reads_each_new_pixel_sprite_as_the_kit_renders_it() -> void:
	var kit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://styles/pixel_art/assets/kit.json"))["sprites"]
	var reader = Solids2D.new()
	var tied := 0
	for path in kit:
		var info: Dictionary = kit[path]
		if not info.has("band_shapes"):
			continue
		tied += 1
		var read = reader._shapes(path)
		assert_true(read != null, "the audit knows %s" % path)
		if read == null:
			continue
		var want := _outlines(Solids2D._turned(info["band_shapes"], float(info.get("facing", 0))))
		var got := _outlines(read)
		assert_eq(got.size(), want.size(), "%s: one audit shape per band shape" % path)
		for k in mini(got.size(), want.size()):
			assert_true(_same(got[k], want[k]), "%s: shape %d is read as rendered (%s against %s)" % [path, k, got[k], want[k]])
	# 12 displays (three kinds at four facings), 8 steps and walls, the
	# fountain's two halves, 8 seat stones and 9 clumps (three kinds in
	# three frames).
	assert_eq(tied, 39, "every new sprite declares its band")


## Shapes as comparable outlines: a disc as [r, x, z], a rectangle or
## polygon as its corners, sorted.
static func _outlines(shapes: Array) -> Array:
	var out := []
	for sh in shapes:
		match sh[0]:
			"disc":
				out.append([sh[1], sh[2], sh[3]])
			"rect":
				out.append(_sorted([Vector2(sh[1], sh[3]), Vector2(sh[2], sh[3]), Vector2(sh[2], sh[4]), Vector2(sh[1], sh[4])]))
			_:
				out.append(_sorted(Array(sh[1])))
	return out


static func _sorted(points: Array) -> Array:
	var rounded := points.map(func(p): return Vector2(snappedf(p.x, 0.001), snappedf(p.y, 0.001)))
	rounded.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	return rounded


static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for k in a.size():
		var d: float = (a[k] - b[k]).length() if a[k] is Vector2 else absf(float(a[k]) - float(b[k]))
		if d > 0.0015:
			return false
	return true


## A pixel perch has a seat stone at each sit anchor, turned its sitter's
## way, and its sitter is drawn on it: the core keeps a sitter at the
## middle of the anchor's 25 cm cell, up to 15 cm off; sitting after its
## last move, placed again while it sits, and standing up where the core
## has it.
func test_a_pixel_perch_sitter_is_drawn_on_its_seat_stone() -> void:
	var main = booted(PIXEL)
	var pack = main.host.pack
	for id in PERCHES + SHELTERS:
		var p := _placement(main, id)
		var node: Node2D = pack.placement_nodes[id]
		var anchors: Array = StylePack.kinds()[p["kind"]]["anchors"]
		var stones: Array = node.get_children().filter(func(c): return _kit_path(pack, c).begins_with("scenery/perch_seat_"))
		var sits := anchors.filter(func(a): return a["type"] == "sit")
		assert_true(not sits.is_empty(), "pixel art: %s has sit anchors" % id)
		assert_eq(stones.size(), sits.size(), "pixel art: %s has a seat stone per sit anchor" % id)
		var k := 0
		for index in anchors.size():
			if anchors[index]["type"] != "sit":
				continue
			var want: Array = _anchor_at(p, anchors[index])
			var stone: Sprite2D = stones[k]
			k += 1
			var at: Vector2 = pack.ground_of(stone)
			assert_true(at.distance_to(want[0]) < 0.05, "pixel art: %s's stone %d is at its anchor (%.3f m off; a pixel's rounding)" % [id, index, at.distance_to(want[0])])
			var turned := posmod(roundi(want[1] / 45.0) * 45, 360)
			assert_eq(_kit_path(pack, stone), "scenery/perch_seat_%d.png" % turned, "pixel art: %s's stone %d faces its sitter's way" % [id, index])
			var core: Vector2 = main.nav.centre(main.nav.cell_of(want[0] * 100.0))
			var who := "o:sitter"
			var view := {"id": who, "kind": {"type": "Human", "tier": "Registered"}, "display_name": "Sitter",
				"appearance": {"palette": "1", "hair": "1"}, "seat": null, "presence": {"headline": "Present"},
				"pos": {"x": core.x, "z": core.y}, "facing": posmod(int(want[1]), 360), "using": null}
			pack.spawn(view, "standing")
			pack.place(who, core, Vector2.ZERO)
			view["using"] = {"target": id, "capability": "sit", "anchor": index}
			pack.update_view(view)
			pack.set_pose(who, "sitting")
			var body: Node2D = pack.nodes[who]
			var seat: Vector2 = pack.ground_of(stone)
			assert_true(pack.ground_of(body).distance_to(seat) < 0.03,
				"pixel art: %s's sitter %d is drawn on its stone (%.3f m off; the core's place is %.3f m off)"
				% [id, index, pack.ground_of(body).distance_to(seat), (core / 100.0).distance_to(seat)])
			assert_eq(posmod(roundi(float(body.get_meta("facing")) / 45.0) * 45, 360), turned, "pixel art: %s's sitter %d faces as its stone" % [id, index])
			assert_eq(str(body.get_node("Body").animation), "sit_%d" % (turned / 45), "pixel art: %s's sitter %d sits, facing its way" % [id, index])
			pack.place(who, core, Vector2.ZERO)
			assert_true(pack.ground_of(body).distance_to(seat) < 0.03, "pixel art: %s's sitter %d stays on its stone as it is placed again" % [id, index])
			view["using"] = null
			pack.update_view(view)
			assert_true(pack.ground_of(body).distance_to(core / 100.0) < 0.05, "pixel art: %s's sitter %d stands up where the core has it" % [id, index])
			pack.despawn(who)
	main.free()


## The ground point (cm) of a display's stand anchor, where its reader
## stands: within reach of it.
static func _stand_of(main, id: String) -> Vector2:
	for t in main.interact.things:
		if t["target"] == id:
			for a in t["anchors"]:
				if a["type"] == "stand":
					return a["pos"]
	return Vector2.ZERO


## What pixel art's surface `id` draws, as lines.
static func _drawn_lines(pack, id: String) -> PackedStringArray:
	return pack.surfaces[id]["node"].get_node("Text").text.split("\n")


## Pixel art draws a display's text only as a compact label (its
## resolution has no room for headlines in the world: the overlay and the
## map's List tab carry them): at most two lines, "Sample" and the title,
## or for other content the title and the first headline where it fits on
## a line, in the pixel font on its grid, on a plate over the drawn face.
## Only the display the player targets, or else the nearest within reach,
## shows it; every other display, near or far, shows its chip. Bookshelves
## (no drawn face) show only their chip.
func test_a_pixel_display_shows_a_compact_label_only_when_it_is_the_focus() -> void:
	var main = booted(PIXEL)
	var pack = main.host.pack
	var ui: Dictionary = pack.style["ui"]
	for id in DISPLAYS:
		var s: Dictionary = pack.surfaces[id]
		var chip := Surfaces.text(s, Surfaces.FAR, 0)
		var normal := Vector2(sin(deg_to_rad(float(s["facing"]))), -cos(deg_to_rad(float(s["facing"]))))
		# 6 m out: near, but no one's focus: the chip.
		pack.update_surfaces(s["pos"] + normal * 600.0)
		assert_eq(s["level"], Surfaces.NEAR, "pixel art: %s at 6 m is near" % id)
		assert_eq(_drawn_lines(pack, id), PackedStringArray([chip]), "pixel art: %s near but not the focus shows its chip" % id)
		# At its stand: the nearest display within reach, the focus.
		pack.update_surfaces(_stand_of(main, id))
		assert_eq(pack.surface_focus, id, "pixel art: %s is the nearest display within reach of its stand" % id)
		_assert_compact(pack, id, ui)
		# Targeted from 6 m away: the focus too.
		pack.update_surfaces(s["pos"] + normal * 600.0, "", id)
		assert_eq(pack.surface_focus, id, "pixel art: the targeted display is the focus")
		_assert_compact(pack, id, ui)
		# The most text there is, on every face: still two lines at most.
		var own: Dictionary = s["panel"]
		s["panel"] = pack.surfaces["placement:square-noticeboard"]["panel"]
		pack.show_surface(id, s["level"])
		_assert_compact(pack, id, ui)
		assert_eq(_drawn_lines(pack, id), PackedStringArray(["Sample", "Notices from the city"]), "pixel art: %s shows Sample and the title" % id)
		# Other content: the title and its first headline, where it fits.
		s["panel"] = {"type": "Notices", "title": "Board", "items": [{"date": "09-27", "headline": "Tram"}]}
		pack.show_surface(id, s["level"])
		assert_eq(_drawn_lines(pack, id), PackedStringArray(["Board", "09-27 · Tram"]), "pixel art: %s shows the title and a short headline" % id)
		s["panel"] = {"type": "Notices", "title": "Board", "items": [{"date": "2026-09-27", "headline": "The boulevard tram runs to the Avenue"}]}
		pack.show_surface(id, s["level"])
		assert_eq(_drawn_lines(pack, id), PackedStringArray(["Board"]), "pixel art: %s leaves out a headline too long for a line" % id)
		s["panel"] = own
		pack.show_surface(id, s["level"])
	# A bookshelf shows its chip, even as the focus.
	var shelf := "placement:reading-shelf-1"
	var chip := Surfaces.text(pack.surfaces[shelf], Surfaces.FAR, 0)
	pack.update_surfaces(pack.surfaces[shelf]["pos"], "", shelf)
	assert_eq(pack.surface_focus, shelf, "pixel art: the shelf is the focus")
	assert_eq(_drawn_lines(pack, shelf), PackedStringArray([chip]), "pixel art: a bookshelf shows only its chip")
	# No one: every display far, its chip.
	pack.update_surfaces(null)
	assert_eq(pack.surface_focus, "", "pixel art: no focus with no one")
	for id in DISPLAYS:
		assert_eq(_drawn_lines(pack, id), PackedStringArray([Surfaces.text(pack.surfaces[id], Surfaces.FAR, 0)]), "pixel art: %s far shows its chip" % id)
	main.free()


## The compact label of pixel art's surface `id`: at most two lines, each
## on one row within the label's width at a whole-number scale of the
## pixel font's grid, "Sample" first for sample content, on a plate that
## holds it, centred over the drawn face and standing over its top.
func _assert_compact(pack, id: String, ui: Dictionary) -> void:
	var s: Dictionary = pack.surfaces[id]
	var label: Label = s["node"].get_node("Text")
	var lines := label.text.split("\n")
	assert_true(lines.size() <= 2, "pixel art: %s's label is two lines at most (%s)" % [id, label.text])
	if s["panel"].get("sample", false):
		assert_eq(lines[0], "Sample", "pixel art: %s's label says Sample first" % id)
	var font := label.get_theme_font("font")
	var size: int = label.get_theme_font_size("font_size")
	assert_eq(label.get_theme_font("font").resource_path, str(ui["font_display"]), "pixel art: %s's label is in the pixel font" % id)
	assert_eq(size % int(ui["pixel_base"]), 0, "pixel art: %s's label is a whole-number scale of its grid" % id)
	for line in lines:
		var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		assert_true(w <= PixelPack.LABEL_MAX_PX, "pixel art: %s's line '%s' fits on one row (%.0f px)" % [id, line, w])
		assert_true(w <= label.size.x + 0.5, "pixel art: %s's line '%s' is within the label" % [id, line])
	var face = pack.display_face(id)
	var plate: Control = s["node"].get_node("Plate")
	assert_true(plate.get_rect().encloses(label.get_rect()), "pixel art: %s's plate holds its label" % id)
	assert_true(plate.position.y + plate.size.y <= -roundf((face["y"] + face["size"].y / 2.0) * 16.0),
		"pixel art: %s's plate stands over the face's top" % id)
	assert_true(absf(plate.position.x + plate.size.x / 2.0) <= 1.0, "pixel art: %s's plate is centred over its face" % id)


## The fountain is drawn in two halves sorted apart: the back of its basin
## behind every far-side sitter, so they sit in front of it, and the front
## (with the pedestal) at its middle, behind its near-side sitters, who sit
## on its rim facing out, in front of it, and before its far-side ones.
func test_a_pixel_fountain_sorts_its_back_half_behind_its_far_sitters() -> void:
	var main = booted(PIXEL)
	var pack = main.host.pack
	var id := "placement:square-fountain"
	var node: Node2D = pack.placement_nodes[id]
	var halves := {}
	for c in node.get_children():
		if c is Sprite2D and _kit_path(pack, c).begins_with("scenery/fountain_"):
			halves[_kit_path(pack, c)] = c
	assert_eq(halves.keys().size(), 2, "pixel art: the fountain is two sprites")
	var back: Sprite2D = halves.get("scenery/fountain_back.png")
	var front: Sprite2D = halves.get("scenery/fountain_front.png")
	if back == null or front == null:
		main.free()
		return
	var p := _placement(main, id)
	var anchors: Array = StylePack.kinds()[p["kind"]]["anchors"]
	for index in anchors.size():
		var want: Array = _anchor_at(p, anchors[index])
		var who := "o:sitter"
		var view := {"id": who, "kind": {"type": "Human", "tier": "Registered"}, "display_name": "Sitter",
			"appearance": {"palette": "1", "hair": "1"}, "seat": null, "presence": {"headline": "Present"},
			"pos": {"x": want[0].x * 100.0, "z": want[0].y * 100.0}, "facing": 0,
			"using": {"target": id, "capability": "sit", "anchor": index}}
		pack.spawn(view, "sitting")
		pack.update_view(view)
		pack.place(who, want[0] * 100.0, Vector2.ZERO)
		var key: float = pack.nodes[who].global_position.y
		var depth: float = (want[0] - p["pos"]).x + (want[0] - p["pos"]).y
		if depth < -0.01:
			assert_true(key > back.global_position.y, "pixel art: far-side sitter %d sorts ahead of the back half (%.0f, %.0f)" % [index, key, back.global_position.y])
			assert_true(key < front.global_position.y, "pixel art: far-side sitter %d sorts behind the front half" % index)
		else:
			# depth <= 0.01: the front half's own anchors (near-side, or
			# on its edge at depth 0, such as anchors 1 and 5) share its
			# origin's x + z; FRONT_HALF_SORT_NUDGE_PX breaks that tie so
			# the sitter sorts after the front half every time.
			assert_true(key > front.global_position.y, "pixel art: front-half sitter %d sorts ahead of the front half (%.4f, %.4f)" % [index, key, front.global_position.y])
		pack.despawn(who)
	main.free()


## A pixel meadow is planted clump by clump inside its lot, each clump
## wholly inside it however it rustles (its farthest frame's reach in the
## band), each carrying its three rustle frames, all kit sprites.
func test_a_pixel_meadow_is_planted_inside_its_lot_with_rustle_frames() -> void:
	var main = booted(PIXEL)
	var pack = main.host.pack
	for id in MEADOWS:
		var p := _placement(main, id)
		var lot := CityGeometry.lot(p)
		var node: Node2D = pack.placement_nodes[id]
		var clumps: Array = node.get_children()
		# The same bound _meadow plants by: the reach-inset lot's grid of
		# nx * nz cells, not area / spacing^2, which is looser (the lot
		# is rarely a whole number of steps across).
		var spec: Dictionary = pack.resolve("props", str(p["kind"])).get("meadow", {})
		var plant_reach := 0.0
		for variant in spec.get("grass", []) + spec.get("flowers", []):
			for path in variant:
				plant_reach = maxf(plant_reach, pack.clump_reach(str(path)))
		var inset := lot.grow(-plant_reach)
		var spacing := float(spec.get("spacing", 0.25))
		var nx := maxi(1, floori(inset.size.x / spacing))
		var nz := maxi(1, floori(inset.size.y / spacing))
		assert_true(clumps.size() >= nx * nz, "pixel art: %s is planted (%d clumps)" % [id, clumps.size()])
		for c in clumps:
			assert_true(c is Sprite2D and c.has_meta("rustle"), "pixel art: %s's clumps are sprites with their rustle" % id)
			if not (c is Sprite2D and c.has_meta("rustle")):
				continue
			var frames_: Array = c.get_meta("rustle")
			assert_eq(frames_.size(), 3, "pixel art: three rustle frames")
			assert_eq("assets/" + _kit_path(pack, c), str(frames_[0]), "pixel art: a clump rests on its first frame")
			var at: Vector2 = pack.ground_of(c)
			for f in frames_:
				var reach: float = pack.clump_reach(str(f))
				assert_true(reach > 0.1, "pixel art: %s declares its reach" % f)
				assert_true(lot.grow(-reach + 1e-4).has_point(at), "pixel art: %s's clump at %s stands wholly inside its lot as %s" % [id, at, f])
	main.free()
