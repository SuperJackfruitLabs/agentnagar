## 08 Pixel art: an isometric 2D district drawn from the pre-rendered kit
## (city/tools/styles/pixel: Blender models rendered orthographically,
## snapped to the 32-colour palette, outlined and dithered; placement
## conventions in assets/kit.json). One metre east is (+16, +8) px, one
## metre south (-16, +8), one metre up 16 px. Every sprite stands on a
## ground point and y-sorts there; every sprite has a night twin.
##
## The ground is 1 m cells baked into 16 x 16 m chunk images (the river in
## two shimmer frames), cropped to what they cover and stored as palette
## indices, one byte a pixel; a palette-swap shader draws them by day or,
## with the night twins' colours, after dark.
extends StylePack

const Townscape = preload("townscape.gd")
const RainOverlay = preload("rain_overlay.gd")

## Seconds between the river's two shimmer frames.
const SHIMMER_S := 0.7
## Ground chunk size in cells.
const CHUNK := 16
## Height of a lamp's lantern above its ground point, in metres.
const LAMP_LIGHT_M := 3.4
## A catenary mast's width in pixels: 4 px is 25 cm (16 px a metre), so
## the mast comes within the clearance of the cells its kind's 15 cm disc
## blocks round it.
const MAST_PX := 4.0
## A pixel chip or label's z-index: above every world sprite (0, ground
## -10, roads and rails -9), so a wall, a roof or a lamp in front of it
## in the y-sort never cuts it. Chips and tags still order among
## themselves by y, since they share this one index.
const LABEL_Z := 10

var world: Node2D
var ground: Node2D
var camera: Camera2D
var anchors := {}
## The kit's sprites' metadata (kit.json `sprites`): a block's band outline.
var kit_sprites := {}
var room_rects := {}
## [CanvasItem, day texture path] for everything that swaps at night.
var swappable := []
var lamps: Array[PointLight2D] = []
var frames := {}
var night := false
var zoom := 1
## Whether a right-drag is panning the view (see end_drag).
var dragging := false
## The district's extent in metres, for the camera presets.
var district := Rect2()
## Everything placed, scenery included, which the widest framing shows.
var whole := Rect2()
var town
## facility id -> {root, roof, near, low, far}
var shells := {}
var footprints := {}
## Surface (placement) id -> the building (_building_at) it stands
## inside; "" outdoors. Set once, when make_surface draws it (a display
## does not move).
var _surface_building := {}
## Occupant id -> the building (_building_at) its ground point stands
## inside now; "" outdoors. Kept current by _track_building as place()
## moves it, so label_visible and pick() can hide or skip it while
## closed without scanning every occupant each frame.
var _in_building := {}
## The base ground: cell (x, z) -> tile path (land, rooms, paths).
var cells := {}
## Baked chunks: {sprite, tiles, origin, day: [textures], night: [textures]}.
var baked := []
## The palette-swap material all ground chunks share, and colour -> index.
var ground_material: ShaderMaterial
var palette_index := {}
var tile_indices := {}
var ground_baked := false
var tile_images := {}
var water_frame := 0
var shimmer_clock := 0.0
## Sprites that fell back to the magenta placeholder.
var placeholders := 0
## The rain overlay, made when it first rains.
var rain_overlay
## Scenery item index -> its ground cells, painted before the nodes.
var _scenery_cells := {}
var _scenery_items := []
## Placement ID -> the ground cell a kind painted into the ground (a path)
## stands on; the baked chunk holding it is tagged once baked.
var _ground_placements := {}


static func iso(x_m: float, z_m: float) -> Vector2:
	return Vector2(round((x_m - z_m) * 16.0), round((x_m + z_m) * 8.0))


## The ground point, in metres, a node stands on (its position in the world).
func ground_of(n: Node2D) -> Vector2:
	var p: Vector2 = world.get_global_transform().affine_inverse() * n.global_position
	return Vector2((p.x / 16.0 + p.y / 8.0) / 2.0, (p.y / 8.0 - p.x / 16.0) / 2.0)


func _tex(path: String, at_night := false) -> Texture2D:
	var p := asset(path)
	if at_night:
		var n := p.get_basename() + "_night.png"
		if ResourceLoader.exists(n):
			p = n
	return load(p) if ResourceLoader.exists(p) else null


func _placeholder_tex() -> Texture2D:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color.MAGENTA)
	return ImageTexture.create_from_image(img)


## A sprite whose generated anchor (its ground point) sits at `at`, drawn
## `lift` metres up (it still sorts at `at`).
func _sprite(path, at: Vector2, parent: Node2D, flip := false, lift := 0.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	var tex: Texture2D = _tex(str(path)) if path != null else null
	if tex == null:
		tex = _placeholder_tex()
		s.offset = Vector2(-6, -12)
		placeholders += 1
	else:
		var a: Array = anchors.get(str(path).trim_prefix("assets/"), [tex.get_width() / 2.0, tex.get_height()])
		s.offset = Vector2(-a[0], -a[1] - round(lift * 16.0))
		if flip:
			s.flip_h = true
			s.offset.x = -(tex.get_width() - a[0])
		swappable.append([s, str(path)])
	s.texture = tex
	s.position = at
	parent.add_child(s)
	return s


# ---- The ground, baked ----

func _tile_image(path: String, at_night: bool) -> Image:
	var key := path + ("#n" if at_night else "")
	if not tile_images.has(key):
		var tex := _tex(path, at_night)
		var img: Image = tex.get_image() if tex != null else null
		if img != null:
			img = img.duplicate()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
		tile_images[key] = img
	return tile_images[key]


## The palette as the shader reads it: index 1 + the position of each
## colour's name in sorted order; 0 is empty.
func _palette_material() -> ShaderMaterial:
	if ground_material != null:
		return ground_material
	var pal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(asset("assets/palette.json")))
	var names: Array = pal.keys()
	names.sort()
	var day := PackedColorArray([Color(0, 0, 0, 0)])
	var dark := PackedColorArray([Color(0, 0, 0, 0)])
	for k in names.size():
		var d := Color.html(pal[names[k]][0])
		day.append(d)
		dark.append(Color.html(pal[names[k]][1]))
		palette_index[d.to_rgba32()] = k + 1
	ground_material = ShaderMaterial.new()
	ground_material.shader = load(asset("palette_swap.gdshader"))
	ground_material.set_shader_parameter("day_c", day)
	ground_material.set_shader_parameter("night_c", dark)
	ground_material.set_shader_parameter("night", night)
	return ground_material


## A tile as palette indices (R8), with its alpha as the mask to blit by.
func _tile_indices(path: String) -> Array:
	if not tile_indices.has(path):
		var src := _tile_image(path, false)
		if src == null:
			tile_indices[path] = []
		else:
			var idx := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_R8)
			for y in src.get_height():
				for x in src.get_width():
					var c := src.get_pixel(x, y)
					if c.a > 0.5:
						var key := Color(c.r, c.g, c.b, 1.0).to_rgba32()
						idx.set_pixel(x, y, Color(float(palette_index.get(key, 0)) / 255.0, 0, 0))
			tile_indices[path] = [idx, src]
	return tile_indices[path]


## Bakes `tiles` (cell -> tile path) into 16 x 16 m chunk sprites under
## `parent`, `lift` metres up, shifted by `offset` px. With two frames, a
## path naming frame 0 ("_0.png") also has a frame 1 (the river).
func bake(tiles: Dictionary, parent: Node2D, name_: String, lift := 0.0, frame_count := 1, offset := Vector2.ZERO) -> Node2D:
	var node := Node2D.new()
	node.name = name_
	parent.add_child(node)
	var material := _palette_material()
	var chunks := {}
	for c in tiles:
		if tiles[c] == null:
			continue
		var k := Vector2i(floori(c.x / float(CHUNK)), floori(c.y / float(CHUNK)))
		if not chunks.has(k):
			chunks[k] = {}
		chunks[k][c] = str(tiles[c])
	var keys := chunks.keys()
	keys.sort()
	for k in keys:
		var origin := Vector2((k.x * CHUNK - k.y * CHUNK - CHUNK) * 16.0, (k.x * CHUNK + k.y * CHUNK) * 8.0)
		# Crop the chunk to the tiles it holds.
		var box := Rect2()
		for c in chunks[k]:
			var r := Rect2(iso(c.x + 0.5, c.y + 0.5) - Vector2(16, 8) - origin, Vector2(32, 16))
			box = r if box.size == Vector2.ZERO else box.merge(r)
		var s := Sprite2D.new()
		s.centered = false
		s.material = material
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = origin + box.position + offset - Vector2(0, round(lift * 16.0))
		var entry := {"sprite": s, "tiles": chunks[k], "origin": origin, "crop": box.position,
			"size": Vector2i(box.size), "day": [], "frames": frame_count}
		for f in frame_count:
			entry["day"].append(_bake_chunk(entry, f))
		s.texture = entry["day"][0]
		node.add_child(s)
		baked.append(entry)
	return node


func _bake_chunk(entry: Dictionary, frame: int) -> ImageTexture:
	var size: Vector2i = entry["size"]
	var img := Image.create(size.x, size.y, false, Image.FORMAT_R8)
	var origin: Vector2 = entry["origin"] + entry["crop"]
	var tiles: Dictionary = entry["tiles"]
	for c in tiles:
		var path: String = tiles[c]
		if frame > 0:
			path = path.replace("_0.png", "_%d.png" % frame)
		var pair := _tile_indices(path)
		if pair.is_empty():
			continue
		var at := iso(c.x + 0.5, c.y + 0.5) - Vector2(16, 8) - origin
		img.blit_rect_mask(pair[0], pair[1], Rect2i(0, 0, 32, 16), Vector2i(at))
	return ImageTexture.create_from_image(img)


func _show_baked() -> void:
	if ground_material != null:
		ground_material.set_shader_parameter("night", night)
	for entry in baked:
		entry["sprite"].texture = entry["day"][water_frame % entry["day"].size()]


func paint(c: Vector2i, path) -> void:
	if path != null:
		cells[c] = str(path)


func _variant(list: Array, key) -> String:
	return str(list[hash(key) % list.size()]) if not list.is_empty() else ""


# ---- The world ----

func build_world(manifest_: Dictionary) -> bool:
	if not manifest_.has("city"):
		return false
	var anchors_text := FileAccess.get_file_as_string(asset("assets/anchors.json"))
	anchors = JSON.parse_string(anchors_text) if anchors_text != "" else {}
	var kit_text := FileAccess.get_file_as_string(asset("assets/kit.json"))
	kit_sprites = JSON.parse_string(kit_text).get("sprites", {}) if kit_text != "" else {}
	ground = Node2D.new()
	ground.name = "Ground"
	ground.z_index = -10
	add_child(ground)
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)
	town = Townscape.new(self)
	for d in manifest_["city"].get("districts", []):
		for f in d.get("facilities", []):
			for r in f.get("rooms", []):
				if r.get("rect") == null:
					return false
				room_rects[r["id"]] = r
	var rooms := CityGeometry.drawn_rooms(manifest_)
	var bounds := Rect2()
	for r in CityGeometry.framed_rooms(manifest_):
		var rr := CityGeometry.rect_m(r["rect"])
		bounds = rr if bounds.size == Vector2.ZERO else bounds.merge(rr)
	var buildings := CityGeometry.buildings(manifest_, StylePack.kinds())
	for b in buildings:
		for r in b["rooms"]:
			footprints[r["id"]] = b
	# Land: lawn everywhere but the water, then the rooms over it.
	var grass: Array = style.get("ground", {}).get("grass", [])
	for g in CityGeometry.ground(manifest_, 10.0):
		for z in range(floori(g.position.y), ceili(g.end.y)):
			for x in range(floori(g.position.x), ceili(g.end.x)):
				paint(Vector2i(x, z), _variant(grass, Vector2i(x, z)))
	for r in rooms:
		_room(r, rooms)
	for b in buildings:
		shells[b["id"]] = town.building(world, b)
		shells[b["id"]]["root"].set_meta("building", str(b["id"]))
	_placements(manifest_)
	district = bounds
	whole = CityGeometry.extent(manifest_)
	camera = Camera2D.new()
	camera.position = iso(bounds.get_center().x, bounds.get_center().y).round()
	camera.zoom = Vector2.ONE
	add_child(camera)
	# An enabled Camera2D becomes current when it enters the tree; only ask
	# explicitly when it already has.
	if camera.is_inside_tree():
		camera.make_current()
	RenderingServer.set_default_clear_color(Color(0.62, 0.8, 0.93))
	return true


func _outdoor(id: String) -> bool:
	var r = room_rects.get(id)
	return r != null and (r.get("outdoor", false) or str(r.get("template", "")) in ["plaza", "outdoor"])


## The room id (room_rects) whose rect holds ground point `at_m`
## (metres); "" outdoors or between rooms.
func _room_at(at_m: Vector2) -> String:
	for id in room_rects:
		if CityGeometry.rect_m(room_rects[id]["rect"]).has_point(at_m):
			return str(id)
	return ""


## The building (footprints) whose room holds ground point `at_m`
## (metres); "" outdoors, in a room with no shell (such as a plaza), or
## between rooms. A closed building hides what stands inside it: a
## surface's plate (make_surface, apply_open) and an occupant's name tag
## (_track_building, label_visible) now that LABEL_Z draws both above the
## world, where the y-sort no longer hides them behind a closed roof the
## way it still hides the bodies themselves; pick() will not select
## someone there either.
func _building_at(at_m: Vector2) -> String:
	var b = footprints.get(_room_at(at_m))
	return str(b["id"]) if b != null else ""


func _room(r: Dictionary, rooms: Array) -> void:
	var entry := resolve("rooms", str(r.get("template", "")))
	var area := CityGeometry.rect_m(r["rect"])
	var tiles: Array = entry.get("tiles", [entry["tile"]] if entry.has("tile") else [])
	for z in range(floori(area.position.y), ceili(area.end.y)):
		for x in range(floori(area.position.x), ceili(area.end.x)):
			if tiles.is_empty():
				_sprite(null, iso(x + 0.5, z + 0.5), world)
			else:
				paint(Vector2i(x, z), _variant(tiles, Vector2i(x, z)))
	if entry.has("paths"):
		_paths(r, area, str(entry["paths"]))
	if not entry.get("outdoor", false):
		_partitions(r, rooms)
		_lamp(iso(area.get_center().x, area.get_center().y) + Vector2(0, -20), 2.2)
	for s in r.get("seats", []):
		var seat_entry := resolve("seats", str(s.get("kind", "desk")))
		var seat := _seat(seat_entry, float(s.get("facing", 0)), CityGeometry.pt_m(s["pos"]), world)
		# A seat is a placement of its furniture (its kind), so it is
		# tagged as one, under the seat's own ID.
		tag_placement(seat, str(s["id"]))
		if str(s.get("kind", "")) == "workstation":
			_add_screen(str(s["id"]), seat, seat_entry)


## A seat's sprite at ground point `at` (metres) facing `facing`: the one
## rendered at its facing (to the degree) where the kit has it, else the
## nearest of its facings 45 degrees apart, or its front or back sprite,
## mirrored for the facings between.
func _seat(entry: Dictionary, facing: float, at: Vector2, parent: Node2D) -> Sprite2D:
	var f := fposmod(facing, 360.0)
	var facings: Dictionary = entry.get("facings", {})
	if not facings.is_empty():
		var own := str(posmod(roundi(f), 360))
		var path = facings.get(own, facings.get(str(posmod(roundi(f / 45.0) * 45, 360)), entry.get("sprite")))
		return _sprite(path, iso(at.x, at.y), parent)
	var back := f < 45.0 or f >= 225.0
	return _sprite(entry.get("back" if back else "sprite"), iso(at.x, at.y), parent, f >= 135.0 and f < 315.0)


# ---- Placements ----

## Draws every placement of the layout (CityGeometry.placements) in the
## style's skin for its kind (style.json's `props`), standing on its point
## and tagged with its ID. A kind painted into the ground (a path) paints
## its cell, or a sized one every cell whose centre its lot holds, and the
## baked chunk holding its point is tagged (see _bake_ground). A meadow
## (a skin's `meadow`) is planted clump by clump over its lot.
func _placements(m: Dictionary) -> void:
	_perch_seats.clear()
	_soft_meadows.clear()
	for p in CityGeometry.placements(m):
		var id := str(p["id"])
		var entry := resolve("props", str(p["kind"]))
		if entry.has("meadow"):
			tag_placement(_meadow(p, entry["meadow"]), id)
			continue
		if entry.has("ground"):
			var at: Vector2 = p["pos"]
			var c := Vector2i(floori(at.x), floori(at.y))
			paint(c, entry["ground"])
			if p["size"] != Vector2.ZERO:
				var lot := CityGeometry.lot(p)
				for x in range(floori(lot.position.x), ceili(lot.end.x)):
					for z in range(floori(lot.position.y), ceili(lot.end.y)):
						if lot.has_point(Vector2(x + 0.5, z + 0.5)):
							paint(Vector2i(x, z), entry["ground"])
			_ground_placements[id] = c
			continue
		var node := _placement(p, entry)
		tag_placement(node, id)
		if str(p["kind"]) == "workstation" and node is Sprite2D:
			_add_screen(id, node, resolve("seats", str(entry.get("seat", "workstation"))))


## One placement's node in the world: a block's lot of buildings in its
## garden wall, a catenary pole, a run of sprites along its footprint (a
## skin that `fit`s one), or its sprite at its facing (with what stands
## under it, the great tree's roots, in a y-sorted node of its own); a
## lamp's light beside it.
func _placement(p: Dictionary, entry: Dictionary) -> Node2D:
	var at: Vector2 = p["pos"]
	var kind := str(p["kind"])
	if entry.has("block"):
		var lot := CityGeometry.lot(p)
		var block: Node2D = town.block(lot, str(entry["block"]), "%d,%d" % [lot.position.x, lot.position.y],
			CityGeometry.nearest_street(manifest, lot.get_center()))
		world.add_child(block)
		return block
	if entry.has("pole"):
		return _pole(at, entry)
	if entry.has("fit"):
		var rects := CityGeometry.footprint_rects(StylePack.kinds().get(kind, {}), p)
		if not rects.is_empty():
			var run: Node2D = town.container(kind.capitalize().replace(" ", ""))
			world.add_child(run)
			_fit(entry, rects[0], run)
			return run
	if entry.has("seat"):
		return _seat(resolve("seats", str(entry["seat"])), float(p["facing"]), at, world)
	if warn_drawn_elsewhere(str(p["id"]), kind, entry):
		return _sprite(null, iso(at.x, at.y), world)
	var list: Array = entry.get("sprites", [])
	var path = entry.get("sprite") if list.is_empty() else _variant(list, Vector2i(roundi(at.x * 10), roundi(at.y * 10)))
	if entry.has("facings"):
		# Rendered at the nearest of its facings, 90 degrees apart.
		var f := posmod(roundi(float(p["facing"]) / 90.0) * 90, 360)
		path = entry["facings"].get(str(f), path)
	if entry.has("light"):
		_lamp(iso(at.x, at.y) + Vector2(0, -round(float(entry["light"]) * 16.0)))
	if entry.has("perch"):
		return _perch(p, entry.get("pieces", [path]), resolve("seats", str(entry["perch"])))
	if not entry.has("under"):
		return _sprite(path, iso(at.x, at.y), world)
	var bed: Node2D = town.container(kind.capitalize().replace(" ", ""))
	world.add_child(bed)
	_sprite(entry["under"], iso(at.x, at.y), bed)
	_sprite(path, iso(at.x, at.y), bed)
	return bed


## A sub-pixel nudge, back in the sort order, for a multi-piece perch's
## piece drawn at the placement's own point (the fountain's front half):
## it would otherwise sort level with a sitter whose anchor lands at the
## same x + z (depth 0), leaving the order to fall to tree order. The
## nudge is far under a pixel, so it does not move the piece on screen.
const FRONT_HALF_SORT_NUDGE_PX := 0.01

## A perch (placement `p`, its body the sprites `pieces`) with a seat
## stone, the skin `seat` (a `seats` entry drawn at its facings), at each
## of its kind's sit anchors, turned the way its sitter faces, in a
## y-sorted node of its own. Each piece stands at its own origin (kit.json
## `origin`, about the placement's point), where it sorts: the fountain's
## back rim behind its far-side sitters, the rest at its middle, nudged
## back (FRONT_HALF_SORT_NUDGE_PX) so a depth-0 sitter always sorts after
## it (a skin's `pieces`; else its one sprite). A perch's sit anchors lie
## just outside its body, and a sitter's hips rest over the anchor, so
## each stone reaches from there back into the body: it stands in the
## square round the sitter that the collision audit leaves to a seat's
## own furniture.
func _perch(p: Dictionary, pieces: Array, seat: Dictionary) -> Node2D:
	var at: Vector2 = p["pos"]
	var kind := str(p["kind"])
	var node: Node2D = town.container(kind.capitalize().replace(" ", ""))
	world.add_child(node)
	for piece in pieces:
		var origin: Array = kit_sprites.get(str(piece).trim_prefix("assets/"), {}).get("origin", [0, 0, 0])
		var o := at + Vector2(float(origin[0]), float(origin[1]))
		var pos := iso(o.x, o.y)
		if pieces.size() > 1 and float(origin[0]) == 0.0 and float(origin[1]) == 0.0:
			pos.y -= FRONT_HALF_SORT_NUDGE_PX
		_sprite(piece, pos, node)
	var facing := float(p["facing"])
	var turn := Transform2D(deg_to_rad(facing), at)
	var anchors: Array = StylePack.kinds().get(kind, {}).get("anchors", [])
	var seats := {}
	for index in anchors.size():
		var a: Dictionary = anchors[index]
		if a.get("type") != "sit":
			continue
		var place: Vector2 = turn * (Vector2(a["at"]["x"], a["at"]["z"]) / 100.0)
		var turned := fposmod(facing + float(a.get("facing", 0)), 360.0)
		_seat(seat, turned, place, node)
		seats[index] = {"pos": place, "facing": turned}
	_perch_seats[str(p["id"])] = seats
	return node


## Placement ID -> {anchor index -> {pos (metres), facing (degrees)}}: the
## seat stone drawn at each sit anchor of every perch, where its sitters
## are drawn (_perched).
var _perch_seats := {}
## Occupant ID -> the perch seat its body was last placed on (null off one).
var _on_perch := {}


## The seat occupant `id` is drawn on, when its view says it sits on a
## perch (its `using` a sit at one of a placement's sit anchors); else
## null. The core keeps a perch's sitter at the middle of the anchor's
## 25 cm cell, up to 15 cm from the anchor, while its seat stone stands at
## the anchor itself, so the body is drawn on the stone instead.
func _perched(id: String):
	var using = views.get(id, {}).get("using")
	if not using is Dictionary or using.get("capability") != "sit":
		return null
	return _perch_seats.get(str(using.get("target", "")), {}).get(int(using.get("anchor", -1)))


## A meadow (placement `p`, its skin `spec`): a clump every `spacing`
## metres across its lot, each nudged by a hash of its place, grass of one
## of the skin's cuts or, `flowering` of the time, a flowering one, in a
## y-sorted node of its own. Each clump is drawn wholly inside the lot:
## the clumps' roots keep inside it by as far as the farthest of their
## frames reaches in the walking band (the kit's `band_shapes`), so people
## walk through the meadow as through grass. Each sprite carries its three
## rustle frames (meta `rustle`: at rest, pushed, swinging back) for the
## sway to play.
func _meadow(p: Dictionary, spec: Dictionary) -> Node2D:
	var node: Node2D = town.container("Meadow")
	world.add_child(node)
	var grass: Array = spec.get("grass", [])
	var flowers: Array = spec.get("flowers", [])
	var reach := 0.0
	for variant in grass + flowers:
		for path in variant:
			reach = maxf(reach, clump_reach(str(path)))
	var lot := CityGeometry.lot(p).grow(-reach)
	if lot.size.x <= 0.0 or lot.size.y <= 0.0 or grass.is_empty():
		return node
	var spacing := float(spec.get("spacing", 0.25))
	var nx := maxi(1, floori(lot.size.x / spacing))
	var nz := maxi(1, floori(lot.size.y / spacing))
	var step := Vector2(lot.size.x / nx, lot.size.y / nz)
	var flowering := int(round(float(spec.get("flowering", 0.0)) * 100.0))
	var sprites := []
	var points := PackedVector2Array()
	for i in nx:
		for j in nz:
			var h := hash("%s:%d:%d" % [p["id"], i, j])
			var nudge := Vector2(float(h % 61) / 60.0 - 0.5, float((h / 61) % 61) / 60.0 - 0.5) * 0.4
			var at := lot.position + (Vector2(i, j) + Vector2(0.5, 0.5) + nudge) * step
			var list: Array = flowers if not flowers.is_empty() and (h / 3721) % 100 < flowering else grass
			var frames_: Array = list[(h / 372100) % list.size()]
			var s := _sprite(frames_[0], iso(at.x, at.y), node)
			s.set_meta("rustle", frames_)
			s.set_meta("rustle_look", _rustle_look(frames_))
			# Its entry among the night swaps, which follows its rustle (a
			# placeholder has none).
			if not swappable.is_empty() and swappable[-1][0] == s:
				s.set_meta("swap", swappable.size() - 1)
			sprites.append(s)
			points.append(at)
	_soft_meadows.append({"sprites": sprites, "points": points, "id": str(p["id"]), "reach": reach,
		"rustle": show_rustle})
	return node


## How a clump of rustle frames `frames_` draws each: [day textures, night
## textures, offsets (its root on that frame's anchor)], one per frame.
## Made when the meadow is planted, so a frame change loads nothing.
func _rustle_look(frames_: Array) -> Array:
	var key := "|".join(frames_)
	if not _rustle_looks.has(key):
		var day := []
		var night_ := []
		var offsets := []
		for path in frames_:
			var tex := _tex(str(path))
			day.append(tex)
			night_.append(_tex(str(path), true))
			var a: Array = anchors.get(str(path).trim_prefix("assets/"), [tex.get_width() / 2.0, tex.get_height()] if tex != null else [0, 0])
			offsets.append(Vector2(-a[0], -a[1]))
		_rustle_looks[key] = [day, night_, offsets]
	return _rustle_looks[key]


# ---- Plants that sway ----

## Every meadow's clumps, which rustle (soft_instances): {sprites, points
## (their roots, metres), id, reach, rustle}.
var _soft_meadows := []
## A clump's three rustle frames (their paths) -> how it draws them, made
## once and shared by every clump of that cut (see _rustle_look).
var _rustle_looks := {}


func soft_instances() -> Array:
	return _soft_meadows.filter(func(m): return m["sprites"].all(func(s): return is_instance_valid(s)))


## Where occupant `id` stands: its node's point in the world, back from
## iso (occupants are the world's children).
func drawn_ground(id: String) -> Vector2:
	var p: Vector2 = nodes[id].position
	return Vector2((p.x / 16.0 + p.y / 8.0) / 2.0, (p.y / 8.0 - p.x / 16.0) / 2.0)


## The ground point under the middle of the view.
func sway_centre():
	return ground_of(camera) if camera != null and world != null else null


## Shows meadow clump `sprite` at rustle frame `frame` (0 at rest, 1
## pushed over, 2 swinging back; its meta `rustle`), in the time of day's
## colours, standing on its root as that frame's anchor has it. The night
## swap follows the frame shown.
func show_rustle(sprite: Sprite2D, frame: int) -> void:
	var look: Array = sprite.get_meta(&"rustle_look")
	sprite.texture = look[1 if night else 0][frame]
	sprite.offset = look[2][frame]
	if sprite.has_meta(&"swap"):
		swappable[sprite.get_meta(&"swap")][1] = sprite.get_meta(&"rustle")[frame]


## How far a kit sprite's clump reaches from its root in the walking band
## (its first `band_shapes` disc), metres; 0 for a sprite with none.
func clump_reach(path: String) -> float:
	var shapes: Array = kit_sprites.get(path.trim_prefix("assets/"), {}).get("band_shapes", [])
	return float(shapes[0][1]) if not shapes.is_empty() and shapes[0][0] == "disc" else 0.0


# ---- Displays' surfaces ----

## The pixels between a label's lines.
const SURFACE_LINE_GAP_PX := 2
## The widest line a display's label holds, in pixels: 22 of the pixel
## font's 8 px letters, a title such as "Notices from the city".
const LABEL_MAX_PX := 176.0
## The plate's border round its label, and the gap under it, over the face.
const SURFACE_MARGIN_PX := 4
const SURFACE_GAP_PX := 2


## Where placement `id`'s sprite draws its display's face (the kit's
## `display`, turned to the sprite's facing): {at (its middle's ground
## point, metres), y (metres up), size (width and height, metres), facing
## (the way it looks out, degrees clockwise from north)}; null when it
## draws none.
func display_face(id: String):
	var node = placement_nodes.get(id)
	if not node is Sprite2D or node.texture == null:
		return null
	var path: String = node.texture.resource_path.trim_prefix(pack_dir + "/").trim_prefix("assets/").replace("_night.png", ".png")
	var info: Dictionary = kit_sprites.get(path, {})
	if not info.has("display"):
		return null
	var d: Dictionary = info["display"]
	var t := deg_to_rad(float(info.get("facing", 0)))
	var local := Vector2(float(d["at"][0]), float(d["at"][1]))
	var turned := Vector2(local.x * cos(t) - local.y * sin(t), local.x * sin(t) + local.y * cos(t))
	return {"at": ground_of(node) + turned, "y": float(d["at"][2]), "size": Vector2(float(d["size"][0]), float(d["size"][1])),
		"facing": float(info.get("facing", 0)) + float(d.get("facing", 0))}


# ---- Workstation screens ----

## How far the glow goes toward white at the top of the activity pulse.
const SCREEN_PULSE_LIGHT := 0.6
## How tall the glow over the top of a screen seen from behind is, in
## pixels: the light it spills.
const SCREEN_SPILL_PX := 1.5

## Workstation ID -> the Polygon2D lit over its screen.
var _screen_faces := {}


## Where the view looks from, along the ground: the south-east (+x, +z),
## which is why a face turned that way is seen and one turned away is not.
const VIEW_FROM := Vector2(1, 1)


## Gives workstation `id` (its sprite `sprite`, skinned `entry`) a lit face
## over the screen its sprite draws (the kit's `display`): hidden while
## idle, where the sprite's own dark screen shows, and the style's glow
## (`screen.glow`) otherwise, lighter at the top of the activity pulse. A
## screen the view sees from behind glows as a strip of light spilling
## over its top instead. The screen is a handful of pixels, so it never
## shows the computer itself (screen_feed_size is zero): the player's own
## desk glows and pulses.
func _add_screen(id: String, sprite: Sprite2D, entry: Dictionary) -> void:
	var face = display_face(id)
	if not face is Dictionary:
		return
	var out := Vector2(sin(deg_to_rad(face["facing"])), -cos(deg_to_rad(face["facing"])))
	# Left to right as one faces the screen.
	var across := Vector2(out.y, -out.x)
	var seen := out.dot(VIEW_FROM) > 0.0
	var half: Vector2 = face["size"] / 2.0
	var mid: Vector2 = face["at"]
	var y: float = face["y"]
	var corners := [[-half.x, half.y], [half.x, half.y], [half.x, -half.y], [-half.x, -half.y]]
	var points := PackedVector2Array()
	for c in corners:
		var ground: Vector2 = mid + across * c[0]
		points.append(_iso_exact(ground) - Vector2(0, (y + c[1]) * 16.0) - sprite.position)
	if not seen:
		# The top edge, and a strip of light over it.
		points = PackedVector2Array([points[0] - Vector2(0, SCREEN_SPILL_PX), points[1] - Vector2(0, SCREEN_SPILL_PX), points[1], points[0]])
	var glow := Polygon2D.new()
	glow.name = "ScreenFace"
	glow.polygon = points
	glow.color = Color(str(entry.get("screen", {}).get("glow", "#78B4DC")))
	glow.set_meta("glow", glow.color)
	glow.visible = false
	sprite.add_child(glow)
	_screen_faces[id] = glow
	add_screen(id)


## Ground point `p` (metres) on the screen, unrounded.
static func _iso_exact(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * 16.0, (p.x + p.y) * 8.0)


func _draw_screen(id: String, shown: Dictionary) -> void:
	var glow = _screen_faces.get(id)
	if not glow is Polygon2D or not is_instance_valid(glow):
		return
	glow.visible = shown["state"] != "idle"
	var base: Color = glow.get_meta("glow")
	glow.color = base.lerp(Color.WHITE, SCREEN_PULSE_LIGHT * float(shown["pulse"]))


func screen_point(id: String):
	var face = display_face(id) if _screen_faces.has(id) else null
	return face["at"] if face is Dictionary else null


func screen_overlay(id: String) -> Node:
	return _screen_faces.get(id)


## A display's text as a compact label on a plate standing over the face
## its sprite draws (display_face; else over the display anchor's top):
## a Label in the style's pixel font at a whole-number scale of its grid
## (`surfaces.near.font` on `surfaces.near.grid`, which is `ui.pixel_base`
## for the display face; else the overlay's body face, `ui.font_body`, on
## `ui.pixel_base_body`), so every glyph is whole pixels, on a panel of the
## interface's colours. At 16 px a metre a display's face is a handful of
## pixels, with no room for headlines in the world, so show_surface draws
## at most two lines, and those only for the display in focus; the overlay
## and the map's List tab carry the rest. A display whose sprite draws no
## face (a bookshelf) shows only its chip. Its root stands at LABEL_Z,
## above every world sprite, so a wall, a roof or a lamp the y-sort would
## otherwise draw over its face never cuts it; it still y-sorts among
## other chips and labels, which share that index.
func make_surface(surface: Dictionary) -> Node:
	var near := resolve("surfaces", "near")
	var ui: Dictionary = style.get("ui", {})
	var colours: Dictionary = ui.get("colours", {})
	var root := Node2D.new()
	root.name = "Surface_" + str(surface["id"]).replace(":", "_")
	root.set_meta("placement_id", surface["id"])
	root.z_index = LABEL_Z
	var at: Vector2 = surface["pos"] / 100.0
	var building := _building_at(at)
	_surface_building[str(surface["id"])] = building
	# A display inside a closed (or roofed) building starts hidden:
	# apply_open shows it again once the cutaway opens that building and
	# lifts its roof. Outdoors it is always shown, as LABEL_Z alone now
	# guarantees.
	root.visible = _labels_show_in(building)
	var top := (float(surface["height"]) + float(surface["size"]["d"])) / 100.0
	var face = display_face(str(surface["id"]))
	if face != null:
		at = face["at"]
		top = face["y"] + face["size"].y / 2.0
	root.set_meta("chip_only", face == null)
	root.position = iso(at.x, at.y)
	# The face's top, in pixels above its ground point (16 a metre).
	root.set_meta("top_px", roundf(top * 16.0))
	var plate := Panel.new()
	plate.name = "Plate"
	var box := StyleBoxFlat.new()
	box.bg_color = Color(str(colours.get("panel", "#141B33")))
	box.border_color = Color(str(colours.get("panel_edge", "#3E5AA8")))
	box.set_border_width_all(1)
	box.anti_aliasing = false
	plate.add_theme_stylebox_override("panel", box)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(plate)
	var label := Label.new()
	label.name = "Text"
	var path := str(near.get("font", ui.get("font_body", "")))
	var font = load(path) if path != "" and ResourceLoader.exists(path) else null
	if font is Font:
		label.add_theme_font_override("font", font)
	var body_grid := int(ui.get("pixel_base_body", ui.get("pixel_base", 10)))
	var grid := int(near.get("grid", ui.get("pixel_base", 8) if path == str(ui.get("font_display", "")) else body_grid))
	root.set_meta("grid", grid)
	label.add_theme_color_override("font_color", Color(str(near.get("colour", "#FFFFFF"))))
	label.add_theme_color_override("font_outline_color", Color(0.09, 0.11, 0.19))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_constant_override("line_spacing", SURFACE_LINE_GAP_PX)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	world.add_child(root)
	return root


## Shows surface `id` at `level` on its plate: for the display in focus
## (surface_focus) near or open, its label (label_lines); for every other,
## and far, its chip. The largest whole-number scale of the grid, up to
## `surfaces.near.font_scale`, whose lines each fit LABEL_MAX_PX; the
## plate hugs them, centred over the face and standing on its top.
func show_surface(id: String, level: String) -> void:
	var root = surfaces[id]["node"]
	if not root is Node2D:
		return
	var label: Label = root.get_node("Text")
	var lines := label_lines(id, level, label)
	var grid := int(root.get_meta("grid"))
	var scale := maxi(1, int(resolve("surfaces", "near").get("font_scale", 1)))
	while scale > 1 and _widest(label, lines, grid * scale) > LABEL_MAX_PX:
		scale -= 1
	label.add_theme_font_size_override("font_size", grid * scale)
	label.text = "\n".join(lines)
	var font := label.get_theme_font("font")
	var need := Vector2(ceilf(minf(_widest(label, lines, grid * scale), LABEL_MAX_PX)),
		ceilf(lines.size() * font.get_height(grid * scale) + (lines.size() - 1) * SURFACE_LINE_GAP_PX))
	label.size = need
	label.position = Vector2(-need.x / 2.0, -float(root.get_meta("top_px")) - SURFACE_GAP_PX - SURFACE_MARGIN_PX - need.y).round()
	var plate: Panel = root.get_node("Plate")
	plate.size = need + Vector2.ONE * SURFACE_MARGIN_PX * 2
	plate.position = (label.position - Vector2.ONE * SURFACE_MARGIN_PX).round()


## What surface `id` says at `level` in pixel art (a deviation from "within
## 8 m: headlines", for the style's resolution): far, not in focus, or
## with no drawn face, its chip; else at most two lines: "Sample" and the
## title for sample content, or the title and its first headline where
## that fits on a line of `label`'s font at the grid's size.
func label_lines(id: String, level: String, label: Label) -> PackedStringArray:
	var s: Dictionary = surfaces[id]
	var root = s["node"]
	if level == Surfaces.FAR or id != surface_focus or root.get_meta("chip_only", false):
		return PackedStringArray([Surfaces.text(s, Surfaces.FAR, 0)])
	var lines := Surfaces.text(s, Surfaces.NEAR, 1).split("\n")
	var headline := lines.size() > 2 or lines.size() == 2 and lines[0] != Surfaces.SAMPLE
	var out := lines.slice(0, lines.size() - (1 if headline else 0))
	if headline and out.size() < 2 and _widest(label, [lines[-1]], int(root.get_meta("grid"))) <= LABEL_MAX_PX:
		out.append(lines[-1])
	return out.slice(0, 2)


## The widest of `lines` in `label`'s font at `font_size`, in pixels.
static func _widest(label: Label, lines, font_size: int) -> float:
	var font := label.get_theme_font("font")
	var widest := 0.0
	for line in lines:
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return widest


## A catenary pole standing on `at` (metres): a mast of the style's
## `height` (6 m unless it says) drawn a line of the palette's `pole`
## colour, MAST_PX wide, and an arm from its top reaching `arm` metres
## (2 unless it says) out over the nearest track.
func _pole(at: Vector2, entry: Dictionary) -> Node2D:
	var pole := Node2D.new()
	pole.name = "CatenaryPole"
	pole.position = iso(at.x, at.y)
	world.add_child(pole)
	var colour := _kit_colour(str(entry["pole"]))
	var top := Vector2(0, -round(float(entry.get("height", 6.0)) * 16.0))
	var mast := Line2D.new()
	mast.points = PackedVector2Array([Vector2.ZERO, top])
	mast.width = MAST_PX
	mast.default_color = colour
	mast.antialiased = false
	pole.add_child(mast)
	var toward := CityGeometry.toward_track(manifest, at * 100.0)
	if toward != Vector2.ZERO:
		var reach := toward * float(entry.get("arm", 2.0))
		var arm := Line2D.new()
		arm.points = PackedVector2Array([top + Vector2(0, 3), top + Vector2(0, 3) + iso(reach.x, reach.y)])
		arm.width = 1.0
		arm.default_color = colour
		arm.antialiased = false
		pole.add_child(arm)
	return pole


## Copies of a prop under `parent` laid along a footprint's long side, as
## many as fit (five workbenches along the workshop's 10 m bench).
func _fit(prop: Dictionary, ob: Rect2, parent: Node2D) -> void:
	var along_x := ob.size.x >= ob.size.y
	var length := ob.size.x if along_x else ob.size.y
	var n := maxi(1, int(round(length / float(prop["fit"][0]))))
	for k in n:
		var t := (k + 0.5) * length / n
		var at := Vector2(ob.position.x + t, ob.get_center().y) if along_x else Vector2(ob.get_center().x, ob.position.y + t)
		_sprite(prop.get("sprite"), iso(at.x, at.y), parent)


## Garden paths from each of a lawn room's doors to its centre, a metre at
## a time, first across then along.
func _paths(r: Dictionary, area: Rect2, tile: String) -> void:
	var centre := Vector2(floor(area.get_center().x) + 0.5, floor(area.get_center().y) + 0.5)
	for door in r.get("doors", []):
		if door.get("pos") == null:
			continue
		var p := CityGeometry.pt_m(door["pos"])
		var start := Vector2(clampf(floor(p.x) + 0.5, area.position.x + 0.5, area.end.x - 0.5), clampf(floor(p.y) + 0.5, area.position.y + 0.5, area.end.y - 0.5))
		var on_x_edge := absf(p.y - area.position.y) < 0.05 or absf(p.y - area.end.y) < 0.05
		var corner := Vector2(start.x, centre.y) if on_x_edge else Vector2(centre.x, start.y)
		for leg in [[start, corner], [corner, centre]]:
			var a: Vector2 = leg[0]
			var b: Vector2 = leg[1]
			var steps := int(round(a.distance_to(b)))
			for k in steps + 1:
				var c: Vector2 = a.lerp(b, float(k) / maxf(steps, 1))
				paint(Vector2i(floori(c.x), floori(c.y)), tile)


func _lamp(at: Vector2, scale_factor := 1.0) -> void:
	var light := PointLight2D.new()
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1.0, 0.5)
	grad.width = 128
	grad.height = 64
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.66, 0.26, 1.0))
	g.set_color(1, Color(1.0, 0.66, 0.26, 0.0))
	grad.gradient = g
	light.texture = grad
	light.texture_scale = 1.5 * scale_factor
	light.position = at
	light.energy = 0.0
	light.blend_mode = Light2D.BLEND_MODE_ADD
	world.add_child(light)
	lamps.append(light)


func _draws_edge(r: Dictionary, a: Vector2, b: Vector2, rooms: Array) -> bool:
	for other in rooms:
		if other["id"] == r["id"] or _outdoor(other["id"]):
			continue
		var o := CityGeometry.rect_m(other["rect"])
		var shared := false
		if is_equal_approx(a.y, b.y):
			shared = (is_equal_approx(a.y, o.position.y) or is_equal_approx(a.y, o.end.y)) and minf(b.x, o.end.x) - maxf(a.x, o.position.x) > 0.01
		else:
			shared = (is_equal_approx(a.x, o.position.x) or is_equal_approx(a.x, o.end.x)) and minf(b.y, o.end.y) - maxf(a.y, o.position.y) > 0.01
		if shared and str(other["id"]) < str(r["id"]):
			return false
	return true


## Walls between rooms inside a building (the building's own shell draws
## its outside walls): low slices of its family, with a gap as wide as
## each door on it (an interior door's width, 1 m unless it says).
func _partitions(r: Dictionary, rooms: Array) -> void:
	var b = footprints.get(r["id"])
	if b == null:
		return
	var folder := "assets/" + str(resolve("exteriors", str(b["kind"])).get("folder", "buildings/hall"))
	var area := CityGeometry.rect_m(r["rect"])
	var kind: Dictionary = StylePack.kinds().get(str(b["kind"]), {})
	var doors := []
	for door in r.get("doors", []):
		if door.get("pos") != null:
			doors.append([CityGeometry.pt_m(door["pos"]), CityGeometry.door_width(door, kind, false)])
	var x0 := area.position.x
	var z0 := area.position.y
	var x1 := area.end.x
	var z1 := area.end.y
	for e in [[Vector2(x0, z0), Vector2(x1, z0)], [Vector2(x0, z0), Vector2(x0, z1)],
			[Vector2(x0, z1), Vector2(x1, z1)], [Vector2(x1, z0), Vector2(x1, z1)]]:
		if not _draws_edge(r, e[0], e[1], rooms) or CityGeometry.on_perimeter(e[0], e[1], b["footprint"]):
			continue
		var gaps := doors.filter(func(d): return Geometry2D.get_closest_point_to_segment(d[0], e[0], e[1]).distance_to(d[0]) < 0.05)
		town.partition(world, folder, e[0], e[1], gaps, str(b["id"]), float(b.get("wall", town.WALL)))


# ---- Occupants ----

func occupant_parent() -> Node:
	return world if world != null else self


func _is_agent(view: Dictionary) -> bool:
	return occupant_key(view) in ["GuildAgent", "CityRoleAgent", "PersonalAgent"]


func _sheet_path(view: Dictionary) -> String:
	var entry := resolve("occupants", occupant_key(view))
	var outfits: Array = entry.get("outfits", [])
	if not outfits.is_empty():
		# Sheets run outfit by outfit, four hair styles each.
		var looks: Dictionary = view.get("appearance", {})
		var p := str(looks.get("palette", ""))
		var k := int(p) if p.is_valid_int() else absi(hash(view["id"]))
		var hs := str(looks.get("hair", "0"))
		var hair := int(hs) % 4 if hs.is_valid_int() else 0
		var styles := 4 if outfits.size() % 4 == 0 else 1
		return str(outfits[(posmod(k, outfits.size() / styles) * styles + (hair if styles == 4 else 0))])
	return str(entry.get("sheet", ""))


## Character sheets (city/tools/styles/pixel/figures.py): one row per
## facing (0, 45, ... 315 clockwise from north), one column per frame, 32 x
## 40 px: walk x6, sit, idle x2, typing x2.
const FRAME := Vector2(32, 40)
const DIRECTIONS := 8
const ANIMS := {"walk": [0, 6, 7.0], "sit": [6, 1, 1.0], "idle": [7, 2, 1.2], "typing": [9, 2, 5.0]}
## Where the ground point is in a frame: the feet standing, the seat seated;
## as an offset from the frame's centre.
const STAND_OFFSET := Vector2(0, -14)
const SEAT_OFFSET := Vector2(0, -12)


func _frames(path: String, at_night: bool) -> SpriteFrames:
	var key := path + ("#night" if at_night else "")
	if frames.has(key):
		return frames[key]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex := _tex(path, at_night)
	if tex == null:
		tex = _placeholder_tex()
	var grid := tex.get_width() >= FRAME.x * 11 and tex.get_height() >= FRAME.y * DIRECTIONS
	for row in DIRECTIONS:
		for anim in ANIMS:
			var spec: Array = ANIMS[anim]
			var name: String = "%s_%d" % [anim, row]
			sf.add_animation(name)
			sf.set_animation_speed(name, spec[2])
			for f in spec[1]:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(Vector2(spec[0] + f, row) * FRAME, FRAME) if grid else Rect2(Vector2.ZERO, tex.get_size())
				sf.add_frame(name, at)
	frames[key] = sf
	return sf


func make_occupant(view: Dictionary) -> Node:
	var id: String = view["id"]
	var root := Node2D.new()
	root.name = id.replace(":", "_")
	var body := AnimatedSprite2D.new()
	body.name = "Body"
	body.sprite_frames = _frames(_sheet_path(view), night)
	body.offset = STAND_OFFSET
	body.set_meta("sheet", _sheet_path(view))
	root.add_child(body)
	body.play("idle_3")
	var icon := Sprite2D.new()
	icon.name = "Icon"
	icon.position = Vector2(0, -44)
	icon.visible = false
	root.add_child(icon)
	var label := Label.new()
	label.name = "Label"
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_outline_color", Color(0.09, 0.11, 0.19))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(120, 24)
	label.position = Vector2(-60, -64)
	label.visible = false
	# LABEL_Z, as a chip or a surface's plate: a wall, a roof or a lamp
	# the y-sort would otherwise draw in front of the name tag never cuts
	# it, and it still y-sorts among the other tags and chips, which
	# share that index.
	label.z_index = LABEL_Z
	root.add_child(label)
	labels[id] = label
	return root


func place(id: String, pos_cm: Vector2, dir: Vector2) -> void:
	if not nodes.has(id):
		return
	var root: Node2D = nodes[id]
	var seat = _perched(id)
	_on_perch[id] = seat
	if seat != null:
		# On its perch's seat stone, facing as the stone does.
		_track_building(id, seat["pos"])
		root.position = iso(seat["pos"].x, seat["pos"].y)
		_lift(root, 0.0)
		root.set_meta("facing", float(seat["facing"]))
		_animate(id)
		return
	_track_building(id, pos_cm / 100.0)
	root.position = iso(pos_cm.x / 100.0, pos_cm.y / 100.0)
	# On a bridge's deck the figure (not its ground point, which sorts it)
	# rises 16 px a metre.
	_lift(root, roundf(-16.0 * deck_at(pos_cm / 100.0)))
	var facing: float
	if dir != Vector2.ZERO:
		facing = fposmod(rad_to_deg(atan2(dir.x, -dir.y)), 360.0)
	else:
		facing = fposmod(float(views.get(id, {}).get("facing", 0)), 360.0)
	root.set_meta("facing", facing)
	_animate(id)


## Notes which building (_building_at) `id`'s ground point `at_m`
## (metres) now stands inside, and refreshes its name tag only when that
## changed (it entered, left, or crossed into another building's room):
## place() calls this as it moves an occupant, so a closed building's
## tag is kept hidden without a separate pass over every occupant.
func _track_building(id: String, at_m: Vector2) -> void:
	var b := _building_at(at_m)
	if _in_building.get(id, "") == b:
		return
	_in_building[id] = b
	refresh_label(id)


## As StylePack.label_visible, but hidden while its building is closed or
## roofed (_labels_show_in): LABEL_Z now draws a name tag above the world,
## so the y-sort no longer hides it behind a roof or wall the way it still
## hides the body.
func label_visible(id: String) -> bool:
	return super(id) and _labels_show_in(_in_building.get(id, ""))


## Whether chips and name tags inside `building` ("" outdoors) show: only
## once it is open with its roof off. A roof kept on (keep_roofs) covers
## the rooms as a closed building's does, and LABEL_Z would draw them
## over it.
func _labels_show_in(building: String) -> bool:
	return building == "" or is_open(building) and not keep_roofs


func set_pose(id: String, pose: String) -> void:
	super(id, pose)
	_animate(id)


## A view that starts or ends a sit on a perch moves its body on or off
## the seat stone (_perched) at once: a sitter comes to rest before its use
## lands, and nothing places it again while it rests.
func update_view(view: Dictionary) -> void:
	super(view)
	var id := str(view["id"])
	var now = _perched(id)
	if now == _on_perch.get(id) or not nodes.has(id) or riders.has(id):
		return
	if now != null:
		place(id, Vector2.ZERO, Vector2.ZERO)
	elif view.get("pos") != null:
		place(id, Motion.point(view["pos"]), Vector2.ZERO)


func despawn(id: String) -> void:
	_on_perch.erase(id)
	_in_building.erase(id)
	super(id)


## The sheet row for the occupant's facing and the clip for its pose:
## walk while moving, typing when seated at work, sit when seated, idle
## otherwise.
func _animate(id: String) -> void:
	if not nodes.has(id):
		return
	var body: AnimatedSprite2D = nodes[id].get_node("Body")
	var f: float = nodes[id].get_meta("facing", 135.0)
	var row := posmod(roundi(f / 45.0), DIRECTIONS)
	var pose: String = poses.get(id, "standing")
	var anim := "idle"
	if pose == "walking":
		anim = "walk"
	elif pose == "sitting":
		anim = "typing" if headlines.get(id, "") == "Working" else "sit"
	body.flip_h = false
	body.offset = SEAT_OFFSET if anim in ["sit", "typing"] else STAND_OFFSET
	var name := "%s_%d" % [anim, row]
	body.speed_scale = stride_scale(id) if anim == "walk" else 1.0
	if body.animation != name:
		body.play(name)


func _restride(id: String) -> void:
	if poses.get(id) == "walking" and nodes.has(id):
		nodes[id].get_node("Body").speed_scale = stride_scale(id)


func set_presence(id: String, headline: String) -> void:
	super(id, headline)
	if not nodes.has(id):
		return
	_animate(id)
	var entry := resolve("headlines", headline)
	var icon: Sprite2D = nodes[id].get_node("Icon")
	var shows := (_is_agent(views.get(id, {})) or id == selected) and not riders.has(id)
	icon.visible = shows and entry.has("icon")
	if icon.visible:
		icon.texture = _tex(str(entry["icon"]))
	nodes[id].modulate = Color(1, 1, 1, 0.5) if headline == "Offline" else Color.WHITE


func set_selected(id: String) -> void:
	super.set_selected(id)
	for x in nodes:
		set_presence(x, headlines.get(x, "Unknown"))


func pick(screen_pos: Vector2) -> String:
	if world == null:
		return ""
	var p: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var best := ""
	var best_d := 16.0
	for id in nodes:
		var building: String = _in_building.get(id, "")
		if building != "" and not is_open(building):
			# Behind a closed wall: a click or a tap cannot reach them.
			continue
		var d: float = (nodes[id].global_position + Vector2(0, -16)).distance_to(p)
		if d < best_d:
			best = id
			best_d = d
	return best


# ---- Time ----

func set_time_of_day(m: int) -> void:
	super(m)
	var dn: Dictionary = style.get("day_night", {})
	var is_night := m >= int(dn.get("night_from", 1140)) or m < int(dn.get("day_from", 360))
	for lamp in lamps:
		lamp.energy = 0.85 if is_night else 0.0
	RenderingServer.set_default_clear_color(Color(0.09, 0.11, 0.22) if is_night else Color(0.62, 0.8, 0.93))
	if is_night == night:
		return
	night = is_night
	_show_baked()
	for pair in swappable:
		if is_instance_valid(pair[0]):
			pair[0].texture = _tex(pair[1], night)
	for id in nodes:
		var body: AnimatedSprite2D = nodes[id].get_node("Body")
		var anim := body.animation
		body.sprite_frames = _frames(str(body.get_meta("sheet")), night)
		body.play(anim)


# ---- Camera ----

## A fixed isometric view has no top-down or street angle; the presets are
## framings instead: the whole city at half scale (the one framing that is
## not pixel-exact), the sheets' framing of the district at 1:1, and the
## square close up at 2:1.
func camera_presets() -> Array:
	return ["topdown", "diagonal", "street"]


func set_camera_preset(name_: String) -> bool:
	if camera == null:
		return false
	var at := district.get_center()
	var z := 1.0
	match name_:
		"topdown":
			z = 0.5
			at = whole.get_center()
		"diagonal":
			z = 1.0
		"street":
			z = 2.0
			var plaza = room_rects.get("room:plaza")
			if plaza != null:
				var rc: Dictionary = plaza["rect"]
				at = Vector2((rc["x"] + rc["w"] / 2.0) / 100.0, (rc["z"] + rc["d"] * 0.6) / 100.0)
		_:
			return false
	zoom = maxi(1, int(z))
	camera.zoom = Vector2(z, z)
	camera.position = iso(at.x, at.y).round()
	return true


## The pixel camera sits on whole pixels; what a shift leaves over is
## kept for the next.
var _view_rest := Vector2.ZERO


func shift_view(ground_cm: Vector2) -> void:
	if camera == null:
		return
	var move := iso(ground_cm.x / 100.0, ground_cm.y / 100.0) - iso(0, 0) + _view_rest
	var whole := move.round()
	_view_rest = move - whole
	camera.position += whole
	camera.force_update_scroll()


## The title's pan along the district, in screen pixels a second.
const DRIFT_PX_S := 8.0
## Whether the view is panning behind the title, which way (1 or -1), and
## where it has got to, in pixels (the camera itself sits on whole ones).
var drifting := false
var _drift_dir := 1.0
var _drift_x := 0.0
## A flight under way: the camera's position at either end, in pixels, and
## how far through its seconds it is. Empty when there is none.
var _flight := {}


## Behind the title the view pans slowly along the district and back, at
## the diagonal framing.
func title_drift(on: bool) -> void:
	if camera == null:
		return
	drifting = on
	if on:
		_flight = {}
		set_camera_preset("diagonal")
		_drift_x = camera.position.x
		_drift_dir = 1.0


## The camera's x range for the title's pan: the district's width on
## screen, less the half of the view either side of the camera.
func drift_span() -> Vector2:
	var xs := []
	for corner in [district.position, district.end, Vector2(district.position.x, district.end.y), Vector2(district.end.x, district.position.y)]:
		xs.append(iso(corner.x, corner.y).x)
	var half := (get_viewport().get_visible_rect().size.x / 2.0 / camera.zoom.x) if is_inside_tree() else 0.0
	var left: float = xs.min() + half
	var right: float = xs.max() - half
	if left > right:
		var mid := (left + right) / 2.0
		return Vector2(mid - 64.0, mid + 64.0)
	return Vector2(left, right)


## Moves the view to centre `ground_cm`, a whole pixel at a time through
## `shift_view`, easing over `seconds`; at 0 it cuts. The view neither
## turns nor zooms in a flight, so `keep_view` changes nothing.
func fly_to(ground_cm: Vector2, seconds: float, _keep_view := false) -> void:
	if camera == null:
		return
	drifting = false
	_view_rest = Vector2.ZERO
	var to := iso(ground_cm.x / 100.0, ground_cm.y / 100.0)
	_flight = {"from": camera.position, "to": to, "seconds": maxf(seconds, 0.0), "elapsed": 0.0}
	_advance_camera(0.0)


## Moves the title's pan or a flight on by `delta` seconds.
func _advance_camera(delta: float) -> void:
	if drifting:
		var span := drift_span()
		_drift_x += _drift_dir * DRIFT_PX_S * delta
		if _drift_x > span.y or _drift_x < span.x:
			_drift_dir = -_drift_dir
			_drift_x = clampf(_drift_x, span.x, span.y)
		camera.position.x = roundf(_drift_x)
	if _flight.is_empty():
		return
	_flight["elapsed"] = minf(_flight["elapsed"] + delta, _flight["seconds"])
	var t := 1.0 if _flight["seconds"] <= 0.0 else smoothstep(0.0, 1.0, _flight["elapsed"] / _flight["seconds"])
	var want: Vector2 = (_flight["from"] as Vector2).lerp(_flight["to"], t).round()
	if t >= 1.0:
		_flight = {}
	var step := want - camera.position
	if step != Vector2.ZERO:
		# The screen step back to the ground, where shift_view takes it.
		shift_view(Vector2(step.x / 16.0 + step.y / 8.0, step.y / 8.0 - step.x / 16.0) / 2.0 * 100.0)


func end_drag() -> void:
	dragging = false


func _unhandled_input(event: InputEvent) -> void:
	if camera == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = mini(3, zoom + 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = maxi(1, zoom - 1)
		camera.zoom = Vector2(zoom, zoom)
	elif event is InputEventMouseMotion and dragging:
		camera.position = (camera.position - event.relative / zoom).round()


func set_rain(amount: float) -> void:
	super(amount)
	if amount > 0.001 and rain_overlay == null:
		rain_overlay = RainOverlay.new()
		rain_overlay.colour = Color(str(style.get("palette", {}).get("rain", "#B8C8DC")))
		add_child(rain_overlay)
	if rain_overlay != null:
		rain_overlay.zoom = zoom
		rain_overlay.density = 0.25 if calm else 1.0
		rain_overlay.set_amount(amount)


func teardown() -> void:
	super.teardown()
	rain_overlay = null
	_screen_faces.clear()
	swappable.clear()
	_soft_meadows.clear()
	_rustle_looks.clear()
	lamps.clear()
	room_rects.clear()
	kit_sprites.clear()
	frames.clear()
	camera = null
	world = null
	ground = null
	shells.clear()
	footprints.clear()
	baked.clear()
	ground_material = null
	palette_index.clear()
	tile_indices.clear()
	cells.clear()
	tile_images.clear()
	ground_baked = false
	_ground_placements.clear()


# ---- Scenery and buildings ----

func scenery_parent() -> Node:
	return world if world != null else self


## Paints every item's ground cells and the lines' tracks first, so
## streets see their junctions and the track lies over its street; then
## draws the items and the tracks; then bakes the base ground under them.
func build_scenery(items: Array) -> void:
	_scenery_items = items
	_scenery_cells = town.paint_scenery(items, _tracks()) if town != null else {}
	super.build_scenery(items)
	for i in _scenery_cells:
		for c in _scenery_cells[i]:
			cells[c] = _scenery_cells[i][c]
	_bake_ground()


func _bake_ground() -> void:
	if ground_baked or ground == null:
		return
	ground_baked = true
	var base := {}
	for c in cells:
		var owned := false
		for i in _scenery_cells:
			if _scenery_cells[i].has(c):
				owned = true
				break
		if not owned:
			base[c] = cells[c]
	var land := bake(base, ground, "Land")
	# A kind painted into the ground is drawn by the chunk holding its cell.
	for chunk in land.get_children():
		for entry in baked:
			if entry["sprite"] != chunk:
				continue
			var ids := PackedStringArray()
			for id in _ground_placements:
				if entry["tiles"].has(_ground_placements[id]):
					ids.append(id)
			if not ids.is_empty():
				chunk.set_meta("placement_ids", ids)
				for id in ids:
					placement_nodes[id] = chunk
	if night:
		_show_baked()


func make_scenery(item: Dictionary) -> Node:
	var pts := CityGeometry.scenery_points(item)
	var index := _scenery_items.find(item)
	var own: Dictionary = _scenery_cells.get(index, {})
	var node: Node2D
	match str(item.get("kind", "")):
		"water":
			node = town.container("Water")
			var flat := bake(own, node, "River", 0.0, 2)
			flat.z_index = -9
		"bridge":
			node = town.bridge(pts[0], pts[1], float(item.get("width", 400)) / 100.0)
		"street":
			node = town.container("Street")
			bake(own, node, "Asphalt").z_index = -9
		"fence":
			node = town.fence(pts)
		_:
			return null
	node.name = "Scenery_" + str(item.get("kind", ""))
	return node


# ---- Transit: tracks and trams ----

## Every track of every line, as paint_scenery takes them: {key, points}
## with points in metres.
func _tracks() -> Array:
	var out := []
	for line in manifest.get("lines", []):
		for index in line.get("tracks", []).size():
			out.append({"key": "track:%s:%d" % [line["id"], index],
				"points": CityGeometry.track_points(line, index).map(func(p): return p / 100.0)})
	return out


## A track's ground cells, painted with the scenery, baked flat.
func make_track(line: Dictionary, index: int) -> Node:
	var own: Dictionary = _scenery_cells.get("track:%s:%d" % [line["id"], index], {})
	var node: Node2D = town.container("Track")
	bake(own, node, "Rails").z_index = -9
	return node


## The tram in its back and front halves' slices and its door leaves,
## drawn about its middle.
func make_vehicle(view: Dictionary) -> Node:
	var n: Node2D = town.tram()
	var leaves := []
	for c in n.get_children():
		var name_ := str(c.name)
		if name_.contains("Door_"):
			leaves.append({"node": c, "rest": c.position, "near": name_.begins_with("Front"),
				"plus_x": name_.ends_with("fore")})
	_trams[str(view["id"])] = {"leaves": leaves, "door": -1.0, "door_to": 0.0, "side": 0}
	return n


## id -> a tram's door leaves ({node, rest, near: on the camera's side,
## plus_x: the leaf toward +x}) and its doors' state.
var _trams := {}


func vehicle_parent() -> Node:
	return world if world != null else self


## The vehicle's length in metres, from its line.
func _vehicle_length_m(id: String) -> float:
	var line := str(vehicle_views.get(id, {}).get("line", ""))
	return float(CityGeometry.line_of(manifest, line).get("vehicle", {}).get("length", 2000)) / 100.0


## The unit ground direction of `heading` (degrees clockwise from north).
static func _heading_dir(heading: float) -> Vector2:
	return Vector2(sin(deg_to_rad(heading)), -cos(deg_to_rad(heading)))


## The sprite runs east-west and is drawn about its middle, half its length
## behind the front, faded by the portals. A turn re-seats its riders.
func place_vehicle(id: String, pos_cm: Vector2, heading: float) -> void:
	super(id, pos_cm, heading)
	var node: Node2D = vehicle_nodes.get(id)
	if node == null:
		return
	var centre := pos_cm / 100.0 - _heading_dir(heading) * _vehicle_length_m(id) / 2.0
	node.position = iso(centre.x, centre.y)
	if absf(float(node.get_meta("heading", heading)) - heading) > 0.5:
		for rider in riders:
			if riders[rider] == id:
				seat_rider(rider, rider_offsets[rider])
	node.set_meta("heading", heading)
	var opacity := vehicle_opacity(id)
	node.modulate.a = opacity
	node.visible = opacity > 0.001


## A rider sorts among the tram's slices at its own ground point (between
## its back and front halves, so it shows in the windows), facing the way
## the tram runs, drawn up on the tram's floor, with no status icon.
func seat_rider(id: String, local_cm: Vector2) -> void:
	var node: Node2D = nodes.get(id)
	var vehicle_id = riders.get(id)
	if node == null or vehicle_id == null:
		return
	var heading := float(vehicle_places.get(vehicle_id, [Vector2.ZERO, 90.0])[1])
	var dir := _heading_dir(heading)
	var left := Vector2(dir.y, -dir.x)
	var from_middle := dir * (local_cm.x / 100.0 + _vehicle_length_m(vehicle_id) / 2.0) + left * (local_cm.y / 100.0)
	node.position = iso(from_middle.x, from_middle.y)
	node.set_meta("facing", heading)
	_lift(node, -roundf(16.0 * float(tram_layout().get("floor_cm", 40)) / 100.0))
	node.get_node("Icon").visible = false
	_animate(id)


## Raises everything drawn for `root` (not its ground point, which sorts
## it) by `lift` pixels (negative is up).
func _lift(root: Node2D, lift: float) -> void:
	var was := float(root.get_meta("lift", 0.0))
	if lift == was:
		return
	for c in root.get_children():
		if c is Node2D:
			c.position.y += lift - was
	root.set_meta("lift", lift)


func step_off(id: String) -> void:
	super(id)
	if nodes.has(id):
		_lift(nodes[id], 0.0)
		set_presence(id, headlines.get(id, "Unknown"))


func set_doors(id: String, open: bool) -> void:
	super(id, open)
	var t: Dictionary = _trams.get(id, {})
	if t.is_empty():
		return
	t["door_to"] = 1.0 if open else 0.0
	if open or float(t["door"]) < 0.0:
		t["side"] = door_side(id)
	if float(t["door"]) < 0.0:
		t["door"] = t["door_to"]
		_place_leaves(id)


## The leaves as the base class names them: the near (south) side is the
## right of an eastbound tram and the left of a westbound one, and "fore"
## is the leaf toward the way it runs.
func door_leaves(id: String) -> Array:
	var out := []
	var east := _heading_dir(float(vehicle_places.get(id, [Vector2.ZERO, 90.0])[1])).x >= 0.0
	for leaf in _trams.get(id, {}).get("leaves", []):
		out.append({"node": leaf["node"], "side": "right" if leaf["near"] == east else "left",
			"leaf": "fore" if leaf["plus_x"] == east else "aft"})
	return out


func door_amount(id: String) -> float:
	return maxf(0.0, float(_trams.get(id, {}).get("door", 0.0)))


func animate_vehicles(delta: float) -> void:
	for id in _trams:
		var t: Dictionary = _trams[id]
		var door := float(t["door"])
		if door >= 0.0 and door != float(t["door_to"]):
			t["door"] = move_toward(door, float(t["door_to"]), delta / DOOR_S if delta > 0.0 else 0.0)
			_place_leaves(id)
		var node: Node2D = vehicle_nodes.get(id)
		if node != null:
			var opacity := vehicle_opacity(id)
			node.modulate.a = opacity
			node.visible = opacity > 0.001


## Slides tram `id`'s leaves on its platform side as far open as its doors
## are: each along the tram, away from its door's middle.
func _place_leaves(id: String) -> void:
	var t: Dictionary = _trams.get(id, {})
	var amount := maxf(0.0, float(t.get("door", 0.0)))
	var side := int(t.get("side", 0))
	var slide := float(tram_layout().get("door_slide_cm", 60)) / 100.0
	for leaf in door_leaves(id):
		var own: Dictionary = {}
		for l in t["leaves"]:
			if l["node"] == leaf["node"]:
				own = l
		var opens: bool = side == 0 or (side > 0) == (leaf["side"] == "left")
		var dx := slide * amount * (1.0 if own["plus_x"] else -1.0) if opens else 0.0
		leaf["node"].position = own["rest"] + iso(dx, 0.0)


func despawn_vehicle(id: String) -> void:
	super(id)
	_trams.erase(id)


func _process(delta: float) -> void:
	if camera != null and (drifting or not _flight.is_empty()):
		_advance_camera(delta)
	animate_vehicles(delta)
	if not ground_baked and ground != null:
		_bake_ground()
	shimmer_clock += delta
	if shimmer_clock >= SHIMMER_S:
		shimmer_clock = fmod(shimmer_clock, SHIMMER_S)
		water_frame = (water_frame + 1) % 2
		for entry in baked:
			if entry["frames"] > 1:
				var list: Array = entry["day"]
				if list.size() > 1:
					entry["sprite"].texture = list[water_frame % list.size()]


## Open: the roof and dome come off and the south and east façades (and
## the corners on them) drop to their low twins; the far walls stay.
func apply_open(id: String, open: bool) -> void:
	var shell = shells.get(id)
	if shell == null:
		return
	shell["roof"].visible = not open or keep_roofs
	for n in shell["near"]:
		n.visible = not open
	for n in shell["low"]:
		n.visible = open
	# A surface or a name tag inside this building now draws at LABEL_Z,
	# above the world, so the y-sort no longer hides it behind the roof
	# or the near walls just toggled: show or hide it here instead (hidden
	# under a kept roof too).
	for sid in _surface_building:
		if _surface_building[sid] != id:
			continue
		var node = surfaces.get(sid, {}).get("node")
		if node != null:
			node.visible = open and not keep_roofs
	for occ in _in_building:
		if _in_building[occ] == id:
			refresh_label(occ)


func shell_state(id: String) -> Dictionary:
	var shell = shells.get(id)
	if shell == null:
		return {}
	return {"roof": shell["roof"].visible}


# ---- The map's base picture ----
# The isometric world has no top view, so the map is a fresh top-down plan
# of the district, drawn straight from the layout and scenery (never the
# sprites) in nothing but the style's 32-colour kit.

## Pixels a metre the plan is drawn at before it is scaled up: 4 (1 px is
## 25 cm).
const MAP_PX_PER_M := 4.0
## Palette name, by the plan's own vocabulary for what it paints.
const MAP_PALETTE := {
	"lawn": "leaf_light", "water": "water", "water_bank": "water_light",
	"street": "grey", "kerb": "dark", "tram_rail": "outline",
	"bridge_deck": "sand_light", "block": "stone", "outline": "outline",
	"tree_a": "leaf", "tree_b": "leaf_dark",
	"plaza": "sand_light", "park": "leaf", "path": "sand",
	"planks": "wood", "planks_seam": "wood_dark",
}
## A building's roof colour on the plan, by its kind; one without an
## entry here reads as stone, the same as a generic block, so a kind worth
## telling apart (the library's navy slate, next to the guild-hall's
## brick) needs its own entry. Chosen distinct from every
## other thing the plan paints (the street and block's greys, the lawn
## and plaza's greens and tans, the guild-hall's brick).
const MAP_ROOF := {"guild-hall": "brick", "library": "night_blue2"}
const MAP_DEFAULT_ROOF := "stone"
## How far from its centre, in pixels, a tree's round crown reaches (a
## diameter of about 7 px), regardless of the plan's scale.
const MAP_TREE_RADIUS_PX := 3
## The kinds the plan shows as a tree's dot: the round trees and the
## palms, the rows among them. Shrubs are too low to show; a great tree
## draws its whole crown (MAP_ROOM_TREE_RADIUS_M).
const MAP_TREE_KINDS := ["street-tree", "palm"]
## A great tree (the plaza's central tree, above all) draws at its real
## crown radius, not a tree's small dot: the great tree's
## model (city/tools/styles/pixel/models.py, tree_square()'s
## crown(..., radius=4.6, ...)) has a 4.6 m crown, so it fills a good part
## of the square, as the sheet's MAP panel draws it.
const MAP_ROOM_TREE_RADIUS_M := 4.6

## The style's 32 colours, name -> its day Color (assets/palette.json, the
## file the ground chunks and every sprite are baked from too).
var _map_kit := {}
## What request_map was last asked, while its deferred paint is still
## pending; empty once answered.
var _map_asked := {}


func _kit() -> Dictionary:
	if _map_kit.is_empty():
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(asset("assets/palette.json")))
		for k in raw:
			_map_kit[k] = Color.html(str(raw[k][0]))
	return _map_kit


## The 32 colours request_map paints the plan in, as lowercase "rrggbb"
## keys.
func palette_hexes() -> Dictionary:
	var out := {}
	for c in _kit().values():
		out[c.to_html(false)] = true
	return out


func _kit_colour(name_: String) -> Color:
	return _kit().get(name_, Color.MAGENTA)


func _map_colour(key: String) -> Color:
	return _kit_colour(str(MAP_PALETTE[key]))


## Paints the district's plan at MAP_PX_PER_M over `extent_m`, scales it up by
## nearest-neighbour to the smallest whole multiple that covers `size_px`,
## brings it to exactly `size_px` (see _map_scaled), and emits `map_ready`
## (a frame later; requests made before then share the one answer, drawn
## as the latest asks).
func request_map(extent_m: Rect2, size_px: Vector2i) -> void:
	if _map_asked.is_empty():
		_paint_map.call_deferred()
	_map_asked = {"extent": extent_m, "size": size_px}


func _paint_map() -> void:
	var extent_m: Rect2 = _map_asked["extent"]
	var size_px: Vector2i = _map_asked["size"]
	_map_asked = {}
	var image := _map_paint(extent_m)
	map_ready.emit(ImageTexture.create_from_image(_map_scaled(image, size_px)))


func _map_px(p: Vector2, extent_m: Rect2) -> Vector2i:
	return Vector2i(((p - extent_m.position) * MAP_PX_PER_M).round())


func _map_px_rect(r: Rect2, extent_m: Rect2) -> Rect2i:
	var a := _map_px(r.position, extent_m)
	var b := _map_px(r.end, extent_m)
	return Rect2i(a, b - a)


func _map_set_px(img: Image, p: Vector2i, colour: Color) -> void:
	if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
		img.set_pixelv(p, colour)


func _map_fill_rect(img: Image, r: Rect2i, colour: Color) -> void:
	var clipped := r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if clipped.size.x > 0 and clipped.size.y > 0:
		img.fill_rect(clipped, colour)


## The 1 px border of `r` (clipped to the image), so a filled area reads
## as a bank line or an outline.
func _map_outline_rect(img: Image, r: Rect2i, colour: Color) -> void:
	if r.size.x <= 0 or r.size.y <= 0:
		return
	for x in range(r.position.x, r.end.x):
		_map_set_px(img, Vector2i(x, r.position.y), colour)
		_map_set_px(img, Vector2i(x, r.end.y - 1), colour)
	for y in range(r.position.y, r.end.y):
		_map_set_px(img, Vector2i(r.position.x, y), colour)
		_map_set_px(img, Vector2i(r.end.x - 1, y), colour)


## A street's segment as a band across its width, with a darker kerb line
## down each of its long edges (never its ends, which meet a junction or
## the plaza beyond).
func _map_street(img: Image, extent_m: Rect2, a: Vector2, b: Vector2, width_m: float) -> void:
	var along_x := absf(b.x - a.x) >= absf(b.y - a.y)
	var rect_m: Rect2
	if along_x:
		rect_m = Rect2(minf(a.x, b.x), a.y - width_m / 2.0, absf(b.x - a.x), width_m)
	else:
		rect_m = Rect2(a.x - width_m / 2.0, minf(a.y, b.y), width_m, absf(b.y - a.y))
	var r := _map_px_rect(rect_m, extent_m)
	_map_fill_rect(img, r, _map_colour("street"))
	var kerb := _map_colour("kerb")
	if along_x:
		for x in range(r.position.x, r.end.x):
			_map_set_px(img, Vector2i(x, r.position.y), kerb)
			_map_set_px(img, Vector2i(x, r.end.y - 1), kerb)
	else:
		for y in range(r.position.y, r.end.y):
			_map_set_px(img, Vector2i(r.position.x, y), kerb)
			_map_set_px(img, Vector2i(r.end.x - 1, y), kerb)


## A track's segment as two parallel dark rows (its rails), a pixel off
## either side of its centre.
func _map_tram(img: Image, extent_m: Rect2, a: Vector2, b: Vector2) -> void:
	var along_x := absf(b.x - a.x) >= absf(b.y - a.y)
	var pa := _map_px(a, extent_m)
	var pb := _map_px(b, extent_m)
	var rail := _map_colour("tram_rail")
	if along_x:
		var y := pa.y
		for x in range(mini(pa.x, pb.x), maxi(pa.x, pb.x)):
			_map_set_px(img, Vector2i(x, y - 1), rail)
			_map_set_px(img, Vector2i(x, y + 1), rail)
	else:
		var x := pa.x
		for y in range(mini(pa.y, pb.y), maxi(pa.y, pb.y)):
			_map_set_px(img, Vector2i(x - 1, y), rail)
			_map_set_px(img, Vector2i(x + 1, y), rail)


## A tree's crown: a round blob `radius` px out from its centre, its two
## greens dithered in a checker, with a dark outline. A tree's or palm's
## dot uses MAP_TREE_RADIUS_PX; a great tree (the plaza's) draws much bigger,
## at its real crown radius (MAP_ROOM_TREE_RADIUS_M).
func _map_tree(img: Image, extent_m: Rect2, at: Vector2, radius: int) -> void:
	var c := _map_px(at, extent_m)
	var crown_a := _map_colour("tree_a")
	var crown_b := _map_colour("tree_b")
	var outline := _map_colour("outline")
	var filled := {}
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius + 3:
				filled[Vector2i(dx, dy)] = true
	for off in filled:
		_map_set_px(img, c + off, crown_a if posmod(off.x + off.y, 2) == 0 else crown_b)
	for off in filled:
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not filled.has(off + n):
				_map_set_px(img, c + off + n, outline)


## A room's floor, by its template, so each reads as its place: the plaza
## paved light stone, the café terrace in planks, the park a different
## green than the lawn with its doors' paths across it. A "ground"
## template room (the library's garden, the quay) stays lawn, which is
## already how the pack itself draws its bare, floorless ground.
func _map_room_floor(img: Image, extent_m: Rect2) -> void:
	for r in CityGeometry.drawn_rooms(manifest):
		var area := CityGeometry.rect_m(r["rect"])
		match str(r.get("template", "")):
			"plaza":
				_map_fill_rect(img, _map_px_rect(area, extent_m), _map_colour("plaza"))
			"cafe-terrace":
				_map_planks(img, extent_m, area)
			"park":
				_map_fill_rect(img, _map_px_rect(area, extent_m), _map_colour("park"))
				_map_park_paths(img, extent_m, r, area)


## The café terrace's floor: a plank colour with a 1 px seam every metre
## across it, so it reads as decking rather than a flat paved rectangle.
func _map_planks(img: Image, extent_m: Rect2, area: Rect2) -> void:
	var r := _map_px_rect(area, extent_m)
	_map_fill_rect(img, r, _map_colour("planks"))
	var seam := _map_colour("planks_seam")
	var x := ceili(area.position.x)
	while x < area.end.x:
		var px := _map_px(Vector2(x, area.position.y), extent_m).x
		for y in range(r.position.y, r.end.y):
			_map_set_px(img, Vector2i(px, y), seam)
		x += 1


## The park's paths, exactly as the pack itself lays them out for the
## world (_paths, above): from each door, across then along, to the
## room's centre, a metre at a time.
func _map_park_paths(img: Image, extent_m: Rect2, r: Dictionary, area: Rect2) -> void:
	var path := _map_colour("path")
	var centre := Vector2(floor(area.get_center().x) + 0.5, floor(area.get_center().y) + 0.5)
	for door in r.get("doors", []):
		if door.get("pos") == null:
			continue
		var p := CityGeometry.pt_m(door["pos"])
		var start := Vector2(clampf(floor(p.x) + 0.5, area.position.x + 0.5, area.end.x - 0.5), clampf(floor(p.y) + 0.5, area.position.y + 0.5, area.end.y - 0.5))
		var on_x_edge := absf(p.y - area.position.y) < 0.05 or absf(p.y - area.end.y) < 0.05
		var corner := Vector2(start.x, centre.y) if on_x_edge else Vector2(centre.x, start.y)
		for leg in [[start, corner], [corner, centre]]:
			var a: Vector2 = leg[0]
			var b: Vector2 = leg[1]
			var steps := int(round(a.distance_to(b)))
			for k in steps + 1:
				var c: Vector2 = a.lerp(b, float(k) / maxf(steps, 1))
				_map_fill_rect(img, _map_px_rect(Rect2(floor(c.x), floor(c.y), 1, 1), extent_m), path)


## Every great tree (the plaza's, above all), at its real crown radius,
## not a tree's dot.
func _map_great_trees(img: Image, extent_m: Rect2) -> void:
	var radius := int(round(MAP_ROOM_TREE_RADIUS_M * MAP_PX_PER_M))
	for p in CityGeometry.placements(manifest):
		if str(p["kind"]) == "great-tree":
			_map_tree(img, extent_m, p["pos"], radius)


## The plan itself, at MAP_PX_PER_M: lawn everywhere but the water, each
## room's own floor over that (the plaza, the café terrace, the park and
## its paths), streets with their kerbs and tram rows, the water with its
## bank line, the bridge deck, the manifest's buildings in their roof
## colour, the block lots, the trees and palms, and every great tree on
## top of all of it.
func _map_paint(extent_m: Rect2) -> Image:
	var w := maxi(1, int(round(extent_m.size.x * MAP_PX_PER_M)))
	var h := maxi(1, int(round(extent_m.size.y * MAP_PX_PER_M)))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.html(MAP_LETTERBOX))
	for land in CityGeometry.ground(manifest, 0.0):
		_map_fill_rect(img, _map_px_rect(land, extent_m), _map_colour("lawn"))
	_map_room_floor(img, extent_m)
	var scenery: Array = manifest.get("scenery", [])
	for item in scenery:
		if str(item.get("kind", "")) == "street":
			var pts := CityGeometry.scenery_points(item)
			var width_m := float(item.get("width", 400)) / 100.0
			for k in range(1, pts.size()):
				_map_street(img, extent_m, pts[k - 1], pts[k], width_m)
	for track in _tracks():
		var pts: Array = track["points"]
		for k in range(1, pts.size()):
			_map_tram(img, extent_m, pts[k - 1], pts[k])
	for item in scenery:
		if str(item.get("kind", "")) == "water":
			var r := _map_px_rect(CityGeometry.rect_m(item["rect"]), extent_m)
			_map_fill_rect(img, r, _map_colour("water"))
			_map_outline_rect(img, r, _map_colour("water_bank"))
	for item in scenery:
		if str(item.get("kind", "")) == "bridge":
			_map_fill_rect(img, _map_px_rect(CityGeometry.scenery_bounds(item), extent_m), _map_colour("bridge_deck"))
	for b in CityGeometry.buildings(manifest, StylePack.kinds()):
		var r := _map_px_rect(b["footprint"], extent_m)
		_map_fill_rect(img, r, _kit_colour(str(MAP_ROOF.get(b["kind"], MAP_DEFAULT_ROOF))))
		_map_outline_rect(img, r, _map_colour("outline"))
	var placed := CityGeometry.placements(manifest)
	for p in placed:
		if resolve("props", str(p["kind"])).has("block"):
			var r := _map_px_rect(CityGeometry.lot(p), extent_m)
			_map_fill_rect(img, r, _map_colour("block"))
			_map_outline_rect(img, r, _map_colour("outline"))
	for p in placed:
		if str(p["kind"]) in MAP_TREE_KINDS:
			_map_tree(img, extent_m, p["pos"], MAP_TREE_RADIUS_PX)
	_map_great_trees(img, extent_m)
	return img


## `image` scaled by nearest-neighbour to the smallest whole multiple that
## covers `size_px`, then down to exactly `size_px`, still by nearest: the
## whole extent over the whole picture, as the map's pins expect, and never
## a colour outside the plan's. Cropping instead would drop the east and
## south of the district and set every pin off its place.
func _map_scaled(image: Image, size_px: Vector2i) -> Image:
	var want := Vector2i(maxi(size_px.x, 1), maxi(size_px.y, 1))
	var w0 := image.get_width()
	var h0 := image.get_height()
	var k := maxi(1, maxi(ceili(float(want.x) / w0), ceili(float(want.y) / h0)))
	var scaled: Image = image.duplicate()
	scaled.resize(w0 * k, h0 * k, Image.INTERPOLATE_NEAREST)
	if scaled.get_size() != want:
		scaled.resize(want.x, want.y, Image.INTERPOLATE_NEAREST)
	return scaled


# ---- Player marker ----

## A lamp-yellow arrow over the local player's head (the figures are 32 px
## to the top of the hair), outlined like the sprites; both colours are the
## palette's, the same by day and night.
func make_player_marker() -> Node:
	return PlayerMarker.arrow(Color("#ffd26e"), Color("#181c30"), -35)
