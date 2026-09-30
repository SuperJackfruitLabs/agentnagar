## What the 3D style packs share: the world built from the layout (floors,
## partitions and seats, the placements of the catalogue's kinds, whole
## buildings from a KitTown, and the scenery), an orbit camera with
## presets, the cut-away with a fading roof, the transit lines' rails and
## the trams the projection runs on them with their riders inside, a keyed
## sky and day, and animated, recoloured characters. A pack supplies its
## town (_make_town) and its style.json; everything else follows the
## style's keys.
extends StylePack
class_name Pack3D

const WALL_HEIGHT := 2.4
const LOW_WALL := 0.45
const WALL_THICK := 0.15
## The kit's walk covers 1.1 m a cycle; people walk 1.25 m a second.
const WALK_SPEED_SCALE := 1.25 / 1.1
## A floor tile laid from a kit piece (a floor given as a .glb path).
const FLOOR_TILE := 2.0
## Crossfade between a character's clips.
const BLEND_S := 0.2
## Where the rig settles behind a workstation's chair while its computer is
## open: this far from the chair, in metres, looking this far down.
const COMPUTER_DISTANCE := 2.6
const COMPUTER_PITCH := -24.0

var world: Node3D
var rig: OrbitRig
var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_material: ProceduralSkyMaterial
var lamps: Array[OmniLight3D] = []
var room_rects := {}
## The pack's KitTown: whole buildings and scenery from its kit.
var town
## facility id -> {root, roof, sides: {side: {full, low, normal}}, centre}
var shells := {}
## Footprints (metres) of buildings drawn as shells, for skipping room walls.
var footprints := {}
## Room ID -> the facility it belongs to, whose shell its walls are part of.
var _facility_of := {}
## Room ID -> its building's wall thickness (metres), its partitions'.
var _wall_of := {}
## Seconds the pack has been shown, for the boats' bobbing.
var _bob_clock := 0.0
var clouds: Array[Node3D] = []
var boats: Array[Node3D] = []
## Where clouds drift, in metres: they wrap around this box.
var sky_box := Rect2()
## Everyone's AnimationPlayer, advanced by the pack by how large they are
## on screen (see _advance_people): id -> player; and time owed to those
## advanced a few frames at a time.
var _mixers := {}
var _owed := {}
## The players _advance_people looks at every frame: everyone's but the
## riders', who are posed once (_pose_once) and hold it.
var _live := {}
var _anim_frame := 0
## On-screen heights, in pixels, above which a person animates every frame
## and every second frame; below the second, every fourth.
const ANIM_FULL_PX := 90.0
const ANIM_HALF_PX := 30.0
## However fast the frames come, a skeleton is posed at most this often:
## past it, more poses are work nobody sees.
const ANIM_MAX_HZ := 120.0
## Who was in view when people were last animated (is_seen), and every
## how many frames each is animated and moved (move_every).
var _seen := {}
var _step := {}
## Riders cost only what can be seen of them (tram spec §1, criterion 4:
## two full trams in view): aboard, they cast no shadow (they sit in the
## tram's), they hold their pose, seated or standing (posed once as they
## board, their skeletons never updated again and never looked at per
## frame), in a tram further off than RIDER_FAR_M they are drawn by their
## far body alone, without its ink outline (a kit with one; one with none
## sheds their small parts, FAR_SHED), and
## with the roof on they are hidden where they cannot be seen: from a
## camera further off than RIDER_SEEN_M that looks down on the roof from
## RIDER_ROOF_DEG or more above the horizontal (no side window in sight),
## or from further off than RIDER_TINY_M. Up close, in first person,
## through the windows from the diagonal and street views, and overhead
## with the roof faded they show as ever.
const RIDER_FAR_M := 25.0
const RIDER_SEEN_M := 45.0
const RIDER_ROOF_DEG := 60.0
const RIDER_TINY_M := 150.0
## Each person's umbrella, found once.
var _umbrellas := {}
## The indoor rooms' rectangles (metres), made once.
var _indoor_rects: Array[Rect2] = []
## Whether umbrellas were last shown open, so easing rain re-checks them
## only when it crosses the threshold (the clock in _process follows
## people in and out).
var _umbrellas_open := false
## Falling rain round the view, built when it first rains.
var rain_node: GPUParticles3D
## The rain the sky was last greyed for.
var _sky_rain := 0.0
## How many streaks fall at full rain.
const RAIN_STREAKS := 6000
var _eye_at_refresh := Vector2.INF
## Beyond this, people switch to their merged far body (a kit with one).
const FAR_M := 45.0
## Beyond this, planting with a far version (the kit's `<piece>_far`: its
## crown as solid lobes, no leaf cards) draws that instead.
const FAR_TREE_M := 90.0
## Reflection streaks under the lamps on wet ground (a style's
## "rain_streaks"), made when it first rains.
var _streaks: Array[MeshInstance3D] = []
var _streak_material: StandardMaterial3D
var _umbrella_clock := 0.0
## A style's "wet_ground": its paving and street materials, with their dry
## roughness and colour, which rain turns glossy and dark.
var _wet := {}
const WET_MATERIALS := ["paving", "asphalt", "kerb", "road", "path", "street"]
const SHADOWLESS_PARTS := ["face", "details", "eyes", "badge"]
## The planting's MultiMeshes, and where their shadows were last fitted.
var _planting: Array[MultiMeshInstance3D] = []
## Kit piece path -> the node its tiled planting is drawn as.
var _planted := {}
var _plant_shadow_at := Vector3(INF, 0, INF)


func _colour(hex: String) -> Color:
	return Color.html(hex)


func _material(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.9
	return m


func _box(size: Vector3, at: Vector3, colour: Color, parent: Node3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(colour)
	mi.position = at
	parent.add_child(mi)
	return mi


## Kit scenes the pack asked for and did not find (drawn as placeholders).
var missing_scenes := PackedStringArray()


func _scene(path: String) -> Node3D:
	var packed = load(asset(path)) if ResourceLoader.exists(asset(path)) else null
	if packed == null:
		if not path in missing_scenes:
			missing_scenes.append(path)
		return _placeholder()
	return packed.instantiate()


func _placeholder() -> Node3D:
	var n := Node3D.new()
	_box(Vector3(0.6, 0.6, 0.6), Vector3(0, 0.3, 0), Color.MAGENTA, n)
	return n


static func _m(p: Dictionary) -> Vector3:
	return Vector3(float(p["x"]) / 100.0, 0.0, float(p["z"]) / 100.0)


func _facing_rotation(degrees: float) -> float:
	return -deg_to_rad(degrees)


# ---- What each 3D pack supplies ----

## The pack's KitTown (see styles/kit_town.gd).
func _make_town():
	return null


# ---- World ----

func build_world(manifest: Dictionary) -> bool:
	if not manifest.has("city"):
		return false
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	town = _make_town()
	_environment()
	for d in manifest["city"].get("districts", []):
		for f in d.get("facilities", []):
			for r in f.get("rooms", []):
				if r.get("rect") == null:
					return false
				room_rects[r["id"]] = r
				_facility_of[r["id"]] = str(f["id"])
	var rooms := CityGeometry.drawn_rooms(manifest)
	var bounds := Rect2()
	for r in CityGeometry.framed_rooms(manifest):
		var rr := CityGeometry.rect_m(r["rect"])
		bounds = rr if bounds.size == Vector2.ZERO else bounds.merge(rr)
	for b in CityGeometry.buildings(manifest, StylePack.kinds()):
		for r in b["rooms"]:
			footprints[r["id"]] = b["footprint"]
			_wall_of[r["id"]] = b["wall"]
	var floors := rooms.map(func(r): return CityGeometry.rect_m(r["rect"]))
	world.add_child(town.ground(CityGeometry.ground(manifest, 400.0), floors, CityGeometry.extent(manifest).grow(24.0)))
	for r in rooms:
		_room(r, rooms)
	for b in CityGeometry.buildings(manifest, StylePack.kinds()):
		var shell: Dictionary = town.building(b)
		shell["root"].set_meta("building", str(b["id"]))
		world.add_child(shell["root"])
		shells[b["id"]] = shell
		_shell_walls(b, shell)
	_placements(manifest)
	_camera(bounds, CityGeometry.extent(manifest))
	_clouds(CityGeometry.extent(manifest).grow(60.0))
	_boats(manifest)
	_style_node(world)
	_sway_materials()
	_warm_people()
	return true


## Builds and dresses one of each kind of occupant and throws it away, so
## their scenes are loaded and their materials made while the style is
## built, not on the frame someone first arrives.
func _warm_people() -> void:
	for key in style.get("occupants", {}):
		var id := "warm:" + str(key)
		var view := {"id": id, "kind": {"type": key}, "display_name": "", "role": "", "badge": null,
			"appearance": {"palette": "0", "hair": "0"}, "seat": null, "presence": {}, "pos": {"x": 0, "z": 0}}
		make_occupant(view).free()
		_forget(id)


## A dressed person's parts that stay hidden for good (the hair styles not
## chosen, a hat, backpack or extra not worn): let go, since every part a
## walker carries is moved with it each frame. The umbrella stays: rain
## shows it.
const TRIMMED_PARTS := ["hair_0", "hair_1", "hair_2", "hair_3", "hat_sun", "backpack", "apron", "jacket", "hood", "scarf"]


func _trim(node: Node) -> void:
	var model = node.get_node_or_null("Model")
	if model == null:
		return
	for part in TRIMMED_PARTS:
		var n = model.find_child(part, true, false)
		if n is Node3D and not n.visible:
			n.get_parent().remove_child(n)
			n.free()


## Drops what the pack keeps about `id`.
func _forget(id: String) -> void:
	_mixers.erase(id)
	_live.erase(id)
	_owed.erase(id)
	_seen.erase(id)
	_step.erase(id)
	_umbrellas.erase(id)
	_on_perch.erase(id)
	labels.erase(id)


## Draws every placement of the layout (CityGeometry.placements) in the
## style's skin for its kind (style.json's `props`), where it stands and as
## it faces, each tagged with its ID. Kinds skinned `tiled` (the planting,
## by the hundred) are drawn a kit piece at a time as MultiMeshes: each
## plant turned and sized a little by its ID, so no two rows repeat. So is
## a meadow's grass (a skin's `meadow`), clump by clump over its lot.
func _placements(m: Dictionary) -> void:
	_perch_seats.clear()
	var tiled := {}
	var meadows := {}
	for p in CityGeometry.placements(m):
		var id := str(p["id"])
		var entry := resolve("props", str(p["kind"]))
		var at := Vector3(p["pos"].x, 0, p["pos"].y)
		if entry.has("meadow"):
			_meadow(p, entry, meadows)
			continue
		if entry.get("tiled", false):
			var path := _variant(entry, at)
			if not tiled.has(path):
				tiled[path] = {"xforms": [], "ids": PackedStringArray(), "kind": str(p["kind"])}
			var h := absi(hash(id))
			var turn := _facing_rotation(float(p["facing"])) + float(h % 628) / 100.0
			var size := 0.85 + float((h / 11) % 35) / 100.0
			var across := size
			if entry.get("fill", false):
				across = _planted_across(path, str(p["kind"]), size, entry["fill"])
			tiled[path]["xforms"].append(Transform3D(Basis(Vector3.UP, turn).scaled(Vector3(across, size, across)), at))
			tiled[path]["ids"].append(id)
			continue
		var node := _placement(p, entry)
		world.add_child(node)
		tag_placement(node, id)
		_light(node, id)
		if str(p["kind"]) == "workstation":
			_add_screen(id, node, resolve("seats", str(entry.get("seat", "workstation"))))
	var paths := tiled.keys()
	paths.sort()
	for path in paths:
		_plant(path, tiled[path]["xforms"], tiled[path]["ids"])
	paths = meadows.keys()
	paths.sort()
	_soft_chunks.clear()
	for path in paths:
		var node: Node3D = town.tiles(path, meadows[path]["xforms"], "Meadow", false, meadows[path]["ids"], true)
		world.add_child(node)
		var reach := _reach(path) * MEADOW_SIZES.y
		for n in _chunks(node):
			tag_placements(n, n.get_meta("placement_ids"))
			n.visibility_range_end = MEADOW_RANGE_M
			n.visibility_range_end_margin = 4.0
			_soft_chunks.append({"multimesh": n, "reach": reach})


## How far apart a meadow's clumps are planted, metres, unless its skin
## says (`spacing`), and what share of them flower (`flowers`, percent).
const MEADOW_SPACING := 0.25
const MEADOW_FLOWERS := 30
## The smallest and largest a meadow's clump is grown.
const MEADOW_SIZES := Vector2(0.8, 1.15)
## Beyond this a meadow's chunk is not drawn: grass under a metre tall is a
## few pixels there, and its cost stays with the meadows near the camera.
const MEADOW_RANGE_M := 60.0


## The meadows' chunks, which sway (soft_instances): [{multimesh, reach}].
var _soft_chunks := []


## Plants sized soft ground `p` (a meadow) with its skin's `meadow` clumps
## (kit pieces [grass, flowers]) into `into` (path -> {xforms, ids}): a
## clump every `spacing` metres across its lot, each nudged, turned and
## sized by a hash of where it is, and flowering by the same hash, every
## one kept wholly inside the lot (its bounds' reach from its root, as
## grown, whichever way it turns), where people walk through it and it
## sways (Task 8 reads its bend weight, UV2.x). The clumps are counted
## over the whole lot but planted over it less the largest clump's reach,
## so the rows along its edges stand as far apart as the rest rather than
## piling up where they were pushed back inside.
func _meadow(p: Dictionary, entry: Dictionary, into: Dictionary) -> void:
	var pieces: Array = entry["meadow"]
	var lot := CityGeometry.lot(p)
	var spacing := float(entry.get("spacing", MEADOW_SPACING))
	var share := int(entry.get("flowers", MEADOW_FLOWERS))
	var nx := maxi(1, floori(lot.size.x / spacing))
	var nz := maxi(1, floori(lot.size.y / spacing))
	var margin := 0.0
	for piece in pieces:
		margin = maxf(margin, _reach(str(piece)) * MEADOW_SIZES.y)
	var inner := Rect2(lot.position + Vector2(margin, margin), (lot.size - Vector2(margin, margin) * 2.0).max(Vector2.ZERO))
	var step := Vector2(inner.size.x / nx, inner.size.y / nz)
	for j in nz:
		for i in nx:
			var h := absi(hash("%s:%d:%d" % [p["id"], i, j]))
			var path := str(pieces[1 if pieces.size() > 1 and h % 100 < share else 0])
			var size := MEADOW_SIZES.x + float((h / 100) % 36) / 100.0
			# Nudged less than half a step: it stays inside the inset.
			var nudge := Vector2(float((h / 3600) % 21) - 10.0, float((h / 75600) % 21) - 10.0) / 10.0 * step * 0.3
			var at := inner.position + step * Vector2(i + 0.5, j + 0.5) + nudge
			var turn := float((h / 1587600) % 628) / 100.0
			if not into.has(path):
				into[path] = {"xforms": [], "ids": PackedStringArray()}
			into[path]["xforms"].append(Transform3D(Basis(Vector3.UP, turn).scaled(Vector3(size, size, size)), Vector3(at.x, 0, at.y)))
			into[path]["ids"].append(str(p["id"]))


## How far kit piece `path`'s bounds reach from its origin across the
## ground: a copy turned any way stays within that of its root.
func _reach(path: String) -> float:
	var box: AABB = town.mesh_of(path).get_aabb()
	var x := maxf(absf(box.position.x), absf(box.end.x))
	var z := maxf(absf(box.position.z), absf(box.end.z))
	return Vector2(x, z).length()


## How much planted piece `path` of `kind` is widened, grown to `size`: to
## its footprint's disc, where people walk, when that is its footprint (a
## style's `fill`: "trunk" for a tree, whose leaves are left out, or true
## for a bush), so a trunk or a bush is as wide as the ground it takes
## whatever height it grows to; else as it grows.
func _planted_across(path: String, kind: String, size: float, fill) -> float:
	var shapes: Array = StylePack.kinds().get(kind, {}).get("footprint", [])
	var reach: float = town.band_reach(path, str(fill) == "trunk")
	if shapes.size() != 1 or not shapes[0].has("r") or reach < 1e-3:
		return size
	return float(shapes[0]["r"]) / 100.0 / reach


## One placement's node, in world space: a block's lot of buildings, a
## catenary pole, a run of modules along its footprint (a skin that `fit`s
## one), a seat's furniture, or its kit piece (with a seat at each sit
## anchor for a skin's `perch`).
func _placement(p: Dictionary, entry: Dictionary) -> Node3D:
	var at := Vector3(p["pos"].x, 0, p["pos"].y)
	var facing := float(p["facing"])
	if entry.has("block"):
		var lot := CityGeometry.lot(p)
		return town.block(lot, str(entry["block"]), "%d,%d" % [lot.position.x, lot.position.y], _heart(),
			CityGeometry.nearest_street(manifest, lot.get_center()))
	if entry.has("pole"):
		return _pole(Vector2(at.x, at.z), entry)
	if entry.has("fit"):
		var rects := CityGeometry.footprint_rects(StylePack.kinds().get(str(p["kind"]), {}), p)
		if not rects.is_empty():
			var run := Node3D.new()
			run.name = str(p["kind"]).capitalize().replace(" ", "")
			var ob := rects[0]
			if fmod(facing, 90.0) == 0.0 and walkable_grid().cols > 0:
				ob = CityGeometry.drawn_rect(walkable_grid(), ob)
			_fit_prop(run, str(entry.get("scene", "")), ob, entry["fit"], _facing_rotation(facing))
			return run
	var path := str(resolve("seats", str(entry["seat"])).get("scene", "")) if entry.has("seat") else _variant(entry, at)
	var piece := _placeholder() if warn_drawn_elsewhere(str(p["id"]), str(p["kind"]), entry) else _scene(path)
	piece.position = at
	piece.rotation.y = _facing_rotation(facing + float(entry.get("turn", 0.0)))
	if entry.get("fill", false):
		_fill_footprint(piece, path, p, float(entry.get("turn", 0.0)))
	town._collect(piece)
	if entry.has("perch"):
		return _perch(p, piece, str(entry["perch"]))
	return piece


## A perch (placement `p`, its body drawn as `body`) with a seat, kit
## piece `seat`, at each of its kind's sit anchors, turned the way its
## sitter faces. A perch's sit anchors lie just outside its body, and a
## sitter's hips rest over the anchor, so each seat reaches from there back
## into the body: it stands in the square round the sitter that the
## collision audit leaves to a seat's own furniture.
func _perch(p: Dictionary, body: Node3D, seat: String) -> Node3D:
	var node := Node3D.new()
	node.name = str(p["kind"]).capitalize().replace(" ", "")
	node.add_child(body)
	var kind: Dictionary = StylePack.kinds().get(str(p["kind"]), {})
	var facing := float(p["facing"])
	var turn := Transform2D(deg_to_rad(facing), p["pos"])
	var anchors: Array = kind.get("anchors", [])
	var seats := {}
	for index in anchors.size():
		var a: Dictionary = anchors[index]
		if a.get("type") != "sit":
			continue
		var place: Vector2 = turn * (Vector2(a["at"]["x"], a["at"]["z"]) / 100.0)
		var piece := _scene(seat)
		piece.position = Vector3(place.x, 0, place.y)
		piece.rotation.y = _facing_rotation(facing + float(a.get("facing", 0)))
		node.add_child(piece)
		town._collect(piece)
		seats[index] = piece
	_perch_seats[str(p["id"])] = seats
	return node


## Placement ID -> {anchor index -> the seat drawn at that sit anchor}, for
## every perch: where its sitters are drawn (_perched).
var _perch_seats := {}
## Occupant ID -> the perch seat its body was last placed on (null off one).
var _on_perch := {}


## The seat occupant `id` is drawn on, when its view says it sits on a
## perch (its `using` a sit at one of a placement's sit anchors); else
## null. The core keeps a perch's sitter at the middle of the anchor's
## 25 cm cell, up to 15 cm from the anchor, while its seat stands at the
## anchor itself, so the body is drawn on the seat instead.
func _perched(id: String):
	var using = views.get(id, {}).get("using")
	if not using is Dictionary or using.get("capability") != "sit":
		return null
	var seat = _perch_seats.get(str(using.get("target", "")), {}).get(int(using.get("anchor", -1)))
	return seat if seat is Node3D and is_instance_valid(seat) else null


# ---- Plants that sway ----

## The sway shader the 3D styles' soft clumps draw with (see SoftContacts).
const SWAY_SHADER := preload("res://styles/shaders/sway.gdshader")
## Its variants for kit materials drawn culled or toon-shaded: a render
## mode is the shader's own, not a uniform (render modes -> Shader).
static var _sway_variants := {}


## The meadows' clumps, which sway: each chunk, with how far its clumps
## reach across the ground (see SoftContacts.bind).
func soft_instances() -> Array:
	return _soft_chunks.filter(func(c): return is_instance_valid(c["multimesh"]))


func drawn_ground(id: String) -> Vector2:
	var n: Node3D = nodes[id]
	return Vector2(n.position.x, n.position.z)


## In first person, the eye; else the ground point the orbit camera looks
## at, the middle of the view (the camera itself stands back from it, 17 m
## in the street view and farther above).
func sway_centre():
	if fpv != null:
		return Vector2(fpv.position.x, fpv.position.z)
	return Vector2(rig.position.x, rig.position.z) if rig != null else null


## Every soft chunk draws its clumps with the sway shader in place of their
## kit materials (after _style_node, so a toon style's materials are
## already toon), the same look with the style's `sway` block: one copy of
## each clump mesh, whose surfaces take the sway materials, so the kit's
## own mesh and materials stay as they are for anything else drawing them.
func _sway_materials() -> void:
	var sway: Dictionary = style.get("sway", {})
	var copies := {}
	for c in _soft_chunks:
		var mm: MultiMesh = c["multimesh"].multimesh
		var key := mm.mesh.get_instance_id()
		if not copies.has(key):
			copies[key] = _swaying(mm.mesh, sway)
		mm.mesh = copies[key]


## A copy of `mesh` whose surfaces draw with sway materials standing in
## for their kit materials.
static func _swaying(mesh: Mesh, sway: Dictionary) -> ArrayMesh:
	# Rebuilt from its arrays, the copy drops any LODs the import made: a
	# clump is a few hundred vertices, drawn only within MEADOW_RANGE_M.
	var out := ArrayMesh.new()
	out.resource_name = mesh.resource_name
	for s in mesh.get_surface_count():
		var primitive: Mesh.PrimitiveType = mesh.surface_get_primitive_type(s) if mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
		out.add_surface_from_arrays(primitive, mesh.surface_get_arrays(s))
		var kit := mesh.surface_get_material(s)
		out.surface_set_material(s, sway_material(kit, sway) if kit is BaseMaterial3D else kit)
	return out


## The sway material standing in for kit material `kit`: its colour,
## vertex colours, roughness, metal, specular and rim, its culling and toon
## shading (a variant of the shader), and the style's `sway` block: how
## stiff its plants are (`stiffness`, 1 by default) and the colour a bent
## blade shows (`tint`, none by default). It keeps the kit material's name
## (the collision audit tells leaves by it) and the kit material itself as
## meta `sway`.
static func sway_material(kit: BaseMaterial3D, sway: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.resource_name = kit.resource_name
	m.shader = _sway_shader(kit)
	m.set_meta("sway", kit)
	m.set_shader_parameter("albedo", kit.albedo_color)
	m.set_shader_parameter("use_vertex_colour", kit.vertex_color_use_as_albedo)
	m.set_shader_parameter("roughness", kit.roughness)
	m.set_shader_parameter("metallic", kit.metallic)
	m.set_shader_parameter("specular", kit.metallic_specular)
	m.set_shader_parameter("rim", kit.rim if kit.rim_enabled else 0.0)
	m.set_shader_parameter("rim_tint", kit.rim_tint)
	m.set_shader_parameter("stiffness", float(sway.get("stiffness", 1.0)))
	m.set_shader_parameter("tint", Color(str(sway["tint"])) if sway.has("tint") else kit.albedo_color)
	m.set_shader_parameter("attack_s", SoftContacts.ATTACK_S)
	m.set_shader_parameter("hold_s", SoftContacts.HOLD_S)
	m.set_shader_parameter("spring_end_s", SoftContacts.SPRING_END_S)
	m.set_shader_parameter("spring_decay", SoftContacts.SPRING_DECAY)
	m.set_shader_parameter("spring_rate", SoftContacts.SPRING_RATE)
	m.set_shader_parameter("spring_fade_s", SoftContacts.SPRING_FADE_S)
	return m


## The sway shader as kit material `kit` is drawn: both faces unless it is
## culled, toon-shaded where it is.
static func _sway_shader(kit: BaseMaterial3D) -> Shader:
	var modes := PackedStringArray()
	match kit.cull_mode:
		BaseMaterial3D.CULL_BACK:
			modes.append("cull_back")
		BaseMaterial3D.CULL_FRONT:
			modes.append("cull_front")
		_:
			modes.append("cull_disabled")
	if kit.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON:
		modes.append("diffuse_toon")
	if kit.specular_mode == BaseMaterial3D.SPECULAR_TOON:
		modes.append("specular_toon")
	var mode := ", ".join(modes)
	if mode == "cull_disabled":
		return SWAY_SHADER
	if not _sway_variants.has(mode):
		var variant := Shader.new()
		variant.code = SWAY_SHADER.code.replace("render_mode cull_disabled;", "render_mode %s;" % mode)
		_sway_variants[mode] = variant
	return _sway_variants[mode]


# ---- Displays' surfaces ----

## A surface's text, in metres a pixel of its font: 32 px lines are 6.4 cm
## tall, for someone standing at the display to read. Text too tall for its
## face is shrunk, down to 20 px (4 cm lines, still read from its stand
## anchor), then loses its last headlines.
const SURFACE_PIXEL_M := 0.002
const SURFACE_FONT_PX := 32
const SURFACE_MIN_FONT_PX := 20
## How Label3D wraps a surface's text (AUTOWRAP_WORD_SMART), for measuring.
const SURFACE_WRAP := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
## Far away, the chip is drawn twice as large.
const SURFACE_FAR_SCALE := 2
## How far the text stands out from the display anchor, so it is drawn in
## front of the board rather than inside it.
const SURFACE_LIFT_M := 0.03


## A display's text as a Label3D on its display anchor: at the top of the
## surface, facing the way the surface faces (the anchor's facing, its
## outward normal), wrapped to its width, in the style's `surfaces.near`
## colour over the overlay's body face. Where the style's piece carries a
## `display` node (the middle of its drawn face, its -Z the face's
## outward normal, its scale the face's size), the text mounts there
## instead, so it lies on the face the style draws, wherever the piece was
## fitted, within that face and the anchor's size both. The text's top is
## 5% of the face below its top edge, and show_surface keeps the text
## within the 90% below that (`text_height`, metres).
func make_surface(surface: Dictionary) -> Node:
	var near := resolve("surfaces", "near")
	var label := Label3D.new()
	label.name = "Surface_" + str(surface["id"]).replace(":", "_")
	label.set_meta("placement_id", surface["id"])
	if _surface_font == null:
		_surface_font = UiTheme.from_style(style).body_font
	label.font = _surface_font
	label.modulate = Color(str(near.get("colour", "#FFFFFF")))
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.outline_size = 8
	label.pixel_size = SURFACE_PIXEL_M
	label.double_sided = false
	label.shaded = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var size: Dictionary = surface["size"]
	var width := float(size["w"]) / 100.0
	var height := float(size["d"]) / 100.0
	var facing := deg_to_rad(float(surface["facing"]))
	var at: Vector2 = surface["pos"] / 100.0
	var middle := Vector3(at.x, float(surface["height"]) / 100.0 + height / 2.0, at.y)
	var drawn = display_face(str(surface["id"]))
	if drawn != null:
		var face: Transform3D = drawn
		var out := -face.basis.z
		facing = atan2(out.x, -out.z)
		middle = face.origin
		width = minf(width, face.basis.x.length())
		height = minf(height, face.basis.y.length())
	label.width = width * 0.9 / SURFACE_PIXEL_M
	label.set_meta("text_height", height * 0.9)
	var mount := middle + Vector3.UP * height * 0.45
	var normal := Vector3(sin(facing), 0.0, -cos(facing))
	label.position = mount + normal * SURFACE_LIFT_M
	# A Label3D reads from its +Z side: turned to face the normal.
	label.rotation.y = PI - facing
	world.add_child(label)
	return label


## Where placement `id`'s piece draws its display's face (its `display`
## node), in world space; null when it draws none.
func display_face(id: String):
	var node = placement_nodes.get(id)
	if not node is Node3D:
		return null
	var face = node.find_child("display", true, false)
	if not face is Node3D:
		return null
	return _to_world(face)


## The display's font, loaded once for all of its surfaces.
var _surface_font: Font


## Shows surface `id`'s text at `level`, as large as it is drawn at that
## level when it fits its face (make_surface's `text_height`), else
## shrunk to fit, down to SURFACE_MIN_FONT_PX; text still too tall drops
## its last headlines, one at a time. "Sample" and the title stay.
func show_surface(id: String, level: String) -> void:
	var label = surfaces[id]["node"]
	if not label is Label3D:
		return
	var near := resolve("surfaces", "near")
	var scale := maxi(1, int(near.get("font_scale", 1)))
	var largest := SURFACE_FONT_PX * scale * (SURFACE_FAR_SCALE if level == Surfaces.FAR else 1)
	var least := SURFACE_MIN_FONT_PX * scale
	var room := float(label.get_meta("text_height", INF)) / SURFACE_PIXEL_M
	var lines := int(near.get("max_lines", 3))
	while true:
		var text := surface_text(id, lines)
		var font_size := largest
		while font_size > least and _text_size(label, text, font_size).y > room:
			font_size -= 1
		if lines <= 0 or _text_size(label, text, font_size).y <= room:
			label.font_size = font_size
			label.text = text
			return
		lines -= 1


## The size, in `label`'s pixels, of `text` at `font_size` as the label
## wraps it.
static func _text_size(label: Label3D, text: String, font_size: int) -> Vector2:
	return label.font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, label.width, font_size, -1, SURFACE_WRAP)


## Stretches `piece` (kit piece `path`, turned `turn` degrees within its
## kind's frame, a right angle, for placement `p`) so its walking-band
## slice fills what the grid blocks for its footprint exactly (drawn_rect)
## and `also` (a rectangle in the kind's frame, metres, such as a seat's
## protected square): nothing walkable comes within the body clearance of
## it, and nothing blocked stands clear of it (a style's `fill`).
func _fill_footprint(piece: Node3D, path: String, p: Dictionary, turn: float, also := Rect2()) -> void:
	var box: Rect2 = town.band_box(path)
	var fp := _drawn_local(p)
	if also.has_area():
		fp = fp.merge(also) if fp.has_area() else also
	if fp.size == Vector2.ZERO or box.size.x < 1e-3 or box.size.y < 1e-3:
		return
	var quarter := posmod(roundi(turn), 360) / 90
	assert(posmod(roundi(turn), 90) == 0, "a filled piece turns by right angles within its kind's frame")
	# The slice in the kind's frame, turned as the piece turns in it (a
	# quarter turn swaps its sides).
	box = Transform2D(deg_to_rad(90.0 * quarter), Vector2.ZERO) * box
	var s := fp.size / box.size
	var off := fp.get_center() - box.get_center() * s
	piece.scale = Vector3(s.y, 1.0, s.x) if quarter % 2 == 1 else Vector3(s.x, 1.0, s.y)
	piece.position += Basis(Vector3.UP, _facing_rotation(float(p["facing"]))) * Vector3(off.x, 0.0, off.y)


## The square round a sitter (metres, in its seat's frame) that its own
## seat or chair may fill: the collision audit's protected square.
const SEAT_SQUARE := Rect2(-0.25, -0.25, 0.5, 0.5)


## What placement `p`'s footprint's bounds become when drawn to the grid's
## cells (CityGeometry.drawn_rect), in its kind's frame (metres); its
## bounds as they are when it is not turned by a right angle, and an empty
## rectangle for a kind with no footprint.
func _drawn_local(p: Dictionary) -> Rect2:
	var kind: Dictionary = StylePack.kinds().get(str(p["kind"]), {})
	var local := Rect2()
	var first := true
	for sh in kind.get("footprint", []):
		var r := Rect2(sh["x"] - sh.get("r", 0.0), sh["z"] - sh.get("r", 0.0), sh.get("w", 2.0 * sh.get("r", 0.0)), sh.get("d", 2.0 * sh.get("r", 0.0)))
		local = r if first else local.merge(r)
		first = false
	if first:
		return Rect2()
	local = Rect2(local.position / 100.0, local.size / 100.0)
	var facing := float(p["facing"])
	if fmod(facing, 90.0) != 0.0 or walkable_grid().cols == 0:
		return local
	var turn := Transform2D(deg_to_rad(facing), p["pos"])
	var world := CityGeometry.drawn_rect(walkable_grid(), turn * local)
	return turn.affine_inverse() * world


## Lights placement `id` when its kit piece has a `light` part (a lamp
## post): a warm lamp there, lit from dusk.
func _light(node: Node3D, id: String) -> void:
	var light_node = node.find_child("light", true, false)
	if light_node == null:
		return
	var lamp := OmniLight3D.new()
	lamp.set_meta("lamp_of", id)
	lamp.omni_range = 8.0
	lamp.light_color = Color(1.0, 0.85, 0.55)
	lamp.position = KitTown.light_point(node)
	world.add_child(lamp)
	lamps.append(lamp)


## A catenary pole: a mast of the style's `height` (6 m unless it says) in
## its palette colour `pole` (round, or square where the style's kit is),
## and an arm at the top reaching `arm` metres (2 unless it says) out over
## the nearest track, where the tram line's wire runs.
func _pole(at: Vector2, entry: Dictionary) -> Node3D:
	var bt := MeshBatch.new()
	var colour = style.get("palette", {}).get(str(entry["pole"]), str(entry["pole"]))
	var material := MeshBatch.material(_colour(str(colour)), 0.6)
	var height := float(entry.get("height", 6.0))
	if entry.get("square", false):
		bt.box(Vector3(0.2, height, 0.2), Transform3D(Basis(), Vector3(at.x, height / 2.0, at.y)), material)
	else:
		bt.cylinder(0.12, height, Vector3(at.x, 0, at.y), material, 8)
	var toward := CityGeometry.toward_track(manifest, at * 100.0)
	if toward != Vector2.ZERO:
		var arm := float(entry.get("arm", 2.0))
		var mid := at + toward * arm / 2.0
		var basis := Basis(Vector3(toward.x, 0, toward.y), Vector3.UP, Vector3(-toward.y, 0, toward.x))
		bt.box(Vector3(arm, 0.1, 0.1), Transform3D(basis, Vector3(mid.x, height - 0.2, mid.y)), material)
	return bt.build("CatenaryPole")


## Plants `xforms` of kit piece `path` as one MultiMesh (or its chunks),
## each instance tagged with its placement from `ids`; a piece with a far
## version (`<piece>_far`: its crown as solid lobes, no leaf cards) swaps to
## it beyond FAR_TREE_M.
func _plant(path: String, xforms: Array, ids: PackedStringArray) -> void:
	var node: Node3D = town.tiles(path, xforms, "Planting", true, ids)
	world.add_child(node)
	_planted[path] = node
	var far_path := path.get_basename() + "_far." + path.get_extension()
	var far_node: Node3D = null
	if ResourceLoader.exists(asset(far_path)):
		far_node = town.tiles(far_path, xforms, "Planting", false, ids)
		world.add_child(far_node)
	for n in _chunks(node):
		_planting.append(n)
		tag_placements(n, n.get_meta("placement_ids"))
		if far_node != null:
			n.visibility_range_end = FAR_TREE_M
			n.visibility_range_end_margin = 4.0
	if far_node != null:
		for n in _chunks(far_node):
			n.set_meta("far_of", path.get_file().get_basename())
			n.visibility_range_begin = FAR_TREE_M
			n.visibility_range_begin_margin = 4.0


const ATLAS_SETTING := "rendering/lights_and_shadows/directional_shadow/size"
const FILTER_SETTING := "rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"
const FILTERS := {"hard": RenderingServer.SHADOW_QUALITY_HARD, "very_low": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
	"low": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "medium": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM}
var _shadows := {}
## The shadow atlas size and filter last given to the renderer (they are
## the renderer's, shared by every pack), for tests and tools to check.
static var renderer_shadows := {}


static func _set_renderer_shadows(atlas: int, filter: int) -> void:
	RenderingServer.directional_shadow_atlas_set_size(atlas, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(filter)
	renderer_shadows = {"atlas": atlas, "filter": filter}


## The sun's shadow quality a style asks for: "shadow_atlas" (the shadow
## map's size), "shadow_filter" (hard, very_low, low, medium),
## "shadow_splits" (1 or 2) and "shadow_distance" (metres). The atlas and
## filter are the renderer's, so a style without them gets the project's,
## and teardown gives them back.
##
## Low quality (`quality_low`) halves the atlas and the shadows' reach, and
## turns off SSAO and screen-space reflections; High puts back what the
## style's look set. MSAA follows `msaa_level`, which the packs that set
## their own apply after this.
func _shadow_quality() -> void:
	var atlas := int(style.get("shadow_atlas", ProjectSettings.get_setting(ATLAS_SETTING, 4096)))
	if quality_low:
		atlas /= 2
	var filter := int(FILTERS.get(str(style.get("shadow_filter", "")), ProjectSettings.get_setting(FILTER_SETTING, 2)))
	_set_renderer_shadows(atlas, filter)
	_shadows = {"atlas": atlas, "filter": filter}
	if sun != null:
		if _full_reach < 0.0:
			_full_reach = sun.directional_shadow_max_distance
		match int(style.get("shadow_splits", 0)):
			1:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			2:
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = shadow_reach()
	if env != null:
		if _full_effects.is_empty():
			_full_effects = {"ssao": bool(style.get("ssao", env.ssao_enabled)), "ssr": env.ssr_enabled}
		env.ssao_enabled = _full_effects["ssao"] and not quality_low
		env.ssr_enabled = _full_effects["ssr"] and not quality_low


## The sun's reach as the style's look set it, before any quality change
## (-1 until first shown); and SSAO and screen-space reflections likewise.
var _full_reach := -1.0
var _full_effects := {}


## How far the sun's shadows reach, in metres: the style's
## "shadow_distance", or its look's own reach, halved at Low quality. The
## view may stretch it further when it pulls back (see _process), so the
## shadows still reach the ground from a distant camera.
func shadow_reach() -> float:
	var reach := float(style.get("shadow_distance", _full_reach if _full_reach >= 0.0 else 0.0))
	return reach / 2.0 if quality_low else reach


func on_shown() -> void:
	_shadow_quality()
	# A pack without antialiasing of its own draws at the project's, which
	# Low quality may lower further; a pack with its own sets it after this.
	if is_inside_tree():
		var vp := get_viewport()
		Pack3D.restore_project_aa(vp)
		if quality_low and vp.msaa_3d > msaa_level():
			vp.msaa_3d = msaa_level()
	apply_look()


## Hands the look settings to the orbit rig too (see StylePack.apply_look).
func apply_look() -> void:
	super()
	if rig != null:
		rig.look_scale = look_scale
		rig.invert_y = invert_y


## The right stick turns the orbit rig directly, at the stick's own
## sensitivity, where a drag of the mouse goes at the mouse's.
func orbit(v: Vector2, delta: float) -> void:
	if fpv != null or rig == null or v == Vector2.ZERO:
		super(v, delta)
		return
	rig.turn(v * STICK_DRAG_PX_PER_S * delta * stick_scale)
	_refresh_open()


## Whether the style smooths its edges with FXAA as well as MSAA; Low
## quality then drops MSAA altogether.
func uses_fxaa() -> bool:
	return false


## The project's own viewport antialiasing, which a pack that sets its
## own puts back when it goes.
static func restore_project_aa(vp: Viewport) -> void:
	vp.msaa_3d = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0))
	vp.screen_space_aa = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa", 0))


## The renderer's shadow atlas and filter as this style set them.
func shadow_settings() -> Dictionary:
	return _shadows


## The viewport MSAA a style asks for ("msaa": 2 or 4; 4 by default). At
## Low quality it is 2x, or none where the style asks for none ("msaa": 0)
## or also uses FXAA.
func msaa_level() -> Viewport.MSAA:
	var asked := int(style.get("msaa", 4))
	if quality_low:
		return Viewport.MSAA_DISABLED if asked == 0 or uses_fxaa() else Viewport.MSAA_2X
	return Viewport.MSAA_2X if asked == 2 else Viewport.MSAA_4X


## Casts shadows only from the planting chunks within the style's
## "plant_shadow_m" of `eye` (a ground point): far trees' shadows cannot be
## seen, and each costs its share of the shadow pass.
func update_plant_shadows(eye: Vector3) -> void:
	var reach := float(style.get("plant_shadow_m", 0.0))
	if reach <= 0.0 or world == null:
		return
	_plant_shadow_at = eye
	for n in _planting:
		if not is_instance_valid(n):
			continue
		var c: Vector3 = n.global_transform * Vector3(n.get_meta("centre", Vector3.ZERO))
		var near := Vector2(c.x - eye.x, c.z - eye.z).length() <= reach
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if near else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The MultiMeshInstance3Ds of a tiles() result (one, or a node of chunks).
static func _chunks(node: Node3D) -> Array:
	return [node] if node is MultiMeshInstance3D else node.find_children("*", "MultiMeshInstance3D", true, false)


## The river surface's height: the town's, or the kit default.
func _water_y() -> float:
	return float(town.water_y) if town != null and "water_y" in town else -0.55


## A few of the style's `boat` moored along the river, bobbing: scatter of
## the pack's own, so only where no one walks (see place_decor).
func _boats(m: Dictionary) -> void:
	var boat_path = style.get("boat")
	if boat_path == null:
		return
	for item in m.get("scenery", []):
		if item.get("kind") != "water":
			continue
		var r := CityGeometry.rect_m(item["rect"])
		# Moorings keep clear of the bridges that cross the river.
		var crossings := []
		for s in m.get("scenery", []):
			if s.get("kind") == "bridge":
				var ends := CityGeometry.scenery_points(s)
				crossings.append([(ends[0].y + ends[1].y) / 2.0, float(s.get("width", 400)) / 200.0 + 5.0])
		for k in 5:
			var boat := _scene(str(boat_path))
			var h := absi(hash("boat%d" % k))
			var z := r.position.y + r.size.y * (k + 0.5) / 5.0
			for c in crossings:
				if absf(z - c[0]) < c[1]:
					z = c[0] + c[1] * (1.0 if z >= c[0] else -1.0)
			boat.position = Vector3(r.position.x + r.size.x * (0.25 + float(h % 50) / 100.0), _water_y(), z)
			boat.rotation.y = PI * float(h % 2) + float(h % 30) / 100.0 - 0.15
			var hull := _bounds(boat, Transform3D.IDENTITY)
			if not place_decor(boat, Rect2(hull.position.x, hull.position.z, hull.size.x, hull.size.z)):
				boat.free()
				continue
			boat.set_meta("scenery", "boat")
			world.add_child(boat)
			boats.append(boat)


## The style's `clouds` drifting slowly east over the district.
func _clouds(box: Rect2) -> void:
	sky_box = box
	var kinds: Array = style.get("clouds", [])
	if kinds.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 12:
		var cloud := _scene(str(kinds[k % kinds.size()]))
		cloud.position = Vector3(rng.randf_range(box.position.x, box.end.x), rng.randf_range(48.0, 72.0), rng.randf_range(box.position.y, box.end.y))
		cloud.rotation.y = rng.randf_range(-0.4, 0.4)
		cloud.scale = Vector3.ONE * rng.randf_range(2.2, 3.6)
		for g in cloud.find_children("*", "GeometryInstance3D", true, false):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(cloud)
		clouds.append(cloud)


func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sun_angle_max = 20.0
	sky_material.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.8
	env.ssao_power = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	# Aerial haze, so the towers and the far bank sit back.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 60.0
	env.fog_depth_end = 320.0
	env.fog_density = 0.35
	env.fog_sky_affect = 0.0
	we.environment = env
	world.add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = 1.4
	sun.light_angular_distance = 0.6
	world.add_child(sun)
	set_time_of_day(720)


## The day's colours at minute `m`, blended between the style's keys.
func _key_at(m: float) -> Dictionary:
	var keys: Array = style.get("day_night", {}).get("keys", [])
	if keys.size() < 2:
		return {}
	for k in range(1, keys.size()):
		var a: Dictionary = keys[k - 1]
		var b: Dictionary = keys[k]
		if m <= float(b["m"]):
			var t := inverse_lerp(float(a["m"]), float(b["m"]), m)
			var out := {}
			for f in a:
				if f == "m":
					continue
				if a[f] is String:
					out[f] = _colour(a[f]).lerp(_colour(b[f]), t)
				else:
					out[f] = lerpf(float(a[f]), float(b[f]), t)
			return out
	return {}


func _room(r: Dictionary, rooms: Array) -> void:
	var entry := resolve("rooms", str(r.get("template", "")))
	var rect: Dictionary = r["rect"]
	var x0: float = rect["x"] / 100.0
	var z0: float = rect["z"] / 100.0
	var w: float = rect["w"] / 100.0
	var d: float = rect["d"] / 100.0
	var area := Rect2(x0, z0, w, d)
	var floor_ = str(entry.get("floor", "#D9CBB0"))
	if entry.get("paving", false):
		_paving(area)
	elif entry.get("lawn", false):
		var lawn = style.get("lawn")
		if lawn is Dictionary:
			_lay(area, str(lawn["tile"]), float(lawn.get("size", 2.0)), -0.02)
		else:
			_box(Vector3(w, 0.1, d), Vector3(x0 + w / 2, -0.07, z0 + d / 2), _colour(str(style["palette"].get("grass", "#6FA24A"))), world)
		_paths(r, area)
	elif floor_.ends_with(".glb"):
		_lay(area, floor_, FLOOR_TILE, 0.0)
	else:
		var floor_colour := _colour(floor_) if not entry.get("placeholder", false) else Color.MAGENTA
		# Indoor floors are timber boards unless the style lays them plain.
		var boards: bool = not entry.get("outdoor", false) and style.get("floorboards", true)
		# Under boards the floor is their dark gaps; plain, it is the floor,
		# its top at ground level, clear of the lawn below (at -0.02).
		var floor_box := _box(Vector3(w, 0.1, d), Vector3(x0 + w / 2, -0.07 if boards else -0.05, z0 + d / 2),
			floor_colour.darkened(0.25) if boards else floor_colour, world)
		floor_box.name = "Floor_" + str(r["id"]).replace(":", "_")
		if boards:
			_planks(area, floor_colour)
	if not entry.get("outdoor", false):
		_walls(r, rooms)
		# Interiors glow at night, as lit windows would.
		var glow := OmniLight3D.new()
		glow.omni_range = maxf(w, d) * 0.8
		glow.light_color = Color(1.0, 0.82, 0.55)
		glow.position = Vector3(x0 + w / 2, 2.2, z0 + d / 2)
		world.add_child(glow)
		lamps.append(glow)
	for s in r.get("seats", []):
		var seat_entry := resolve("seats", str(s.get("kind", "desk")))
		var seat := _scene(str(seat_entry.get("scene", "")))
		var facing := float(s.get("facing", 0))
		seat.position = _m(s["pos"])
		seat.rotation.y = _facing_rotation(facing + float(seat_entry.get("turn", 0.0)))
		var placed := {"kind": str(s.get("kind", "desk")), "pos": CityGeometry.pt_m(s["pos"]), "facing": facing}
		if seat_entry.get("fill", false) and not seat_entry.has("desk"):
			# The seat stands whole, fitted to its footprint: a bench or a
			# café chair is measured round its sitter, so it keeps its own
			# size; a desk's footprint is its top ahead, so its chair
			# stands in the square round the sitter.
			var around := _drawn_local(placed)
			var square := Rect2() if around.has_point(Vector2.ZERO) else SEAT_SQUARE
			_fill_footprint(seat, str(seat_entry.get("scene", "")), placed, float(seat_entry.get("turn", 0.0)), square)
		world.add_child(seat)
		town._collect(seat)
		# A seat is a placement of its furniture (its kind), so it is
		# tagged as one, under the seat's own ID.
		tag_placement(seat, str(s["id"]))
		if str(s.get("kind", "")) == "workstation":
			_add_screen(str(s["id"]), seat, seat_entry)
		if seat_entry.has("desk"):
			# A seat drawn as separate pieces: a desk ahead, a terminal on it.
			var ahead := Vector3(sin(deg_to_rad(facing)), 0, -cos(deg_to_rad(facing))) * 0.65
			var desk := _scene(str(seat_entry["desk"]))
			desk.position = seat.position + ahead
			desk.rotation.y = _facing_rotation(facing)
			if seat_entry.get("fill", false):
				# The desk fills the seat's footprint; its chair stands as
				# it is in the square round the sitter.
				desk.position = seat.position
				_fill_footprint(desk, str(seat_entry["desk"]), placed, 0.0)
			desk.set_meta("placement_id", str(s["id"]))
			world.add_child(desk)
			var terminal := _scene(str(seat_entry.get("terminal", "")))
			var mount = desk.find_child("terminal_mount", true, false)
			if mount != null:
				mount.add_child(terminal)
				# A stretched desk carries its terminal at its own size.
				terminal.scale = Vector3.ONE / desk.scale
			else:
				terminal.position = desk.position + Vector3(0, 0.74, 0)
				terminal.rotation.y = desk.rotation.y
				terminal.set_meta("placement_id", str(s["id"]))
				world.add_child(terminal)


# ---- Workstation screens ----

## The size of a workstation screen's live feed, in pixels.
const SCREEN_FEED_SIZE := Vector2i(256, 160)
## How far the lit face stands out from the screen the kit draws, metres.
const SCREEN_LIFT_M := 0.003
## How bright the glow shines, and how much brighter the feed is drawn at
## the top of the activity pulse.
const SCREEN_GLOW_ENERGY := 0.6
const SCREEN_PULSE_GAIN := 0.35

## Workstation ID -> the face lit over its screen (a quad on its `display`
## node), hidden while idle.
var _screen_faces := {}
## The style's dark screen and its glow, shared by every screen idle or in
## use, and the one live feed's material, made when first shown.
var _screen_idle: StandardMaterial3D
var _screen_glow: StandardMaterial3D
var _screen_live: StandardMaterial3D


## Gives workstation `id` (its piece `piece`, skinned `entry`) its screen:
## the kit's `screen` drawn in the style's idle colour (`screen.idle`), and
## a face on its `display` node, the drawn face's size, that shows the glow
## (`screen.glow`) or the live feed. A piece without both is left as drawn.
func _add_screen(id: String, piece: Node3D, entry: Dictionary) -> void:
	var screen = piece.find_child("screen", true, false)
	var display = piece.find_child("display", true, false)
	if not screen is MeshInstance3D or not display is Node3D:
		return
	var look: Dictionary = entry.get("screen", {})
	if _screen_idle == null:
		_screen_idle = StandardMaterial3D.new()
		_screen_idle.albedo_color = _colour(str(look.get("idle", "#10161D")))
		_screen_idle.roughness = 0.2
		# Drawn as the kit draws its own: the low-poly kits' materials are
		# double-sided, and their screen's near face is wound away from the
		# sitter, so a culled override hides it and shows the monitor's case
		# behind (solarpunk's timber read as an orange screen).
		var kit_material := (screen as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
		if kit_material != null:
			_screen_idle.cull_mode = kit_material.cull_mode
	(screen as MeshInstance3D).material_override = _screen_idle
	var face := MeshInstance3D.new()
	face.name = "ScreenFace"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	face.mesh = quad
	# The quad faces +Z; the display node's face looks out along -Z.
	face.rotation.y = PI
	face.position = Vector3(0, 0, -SCREEN_LIFT_M)
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.visible = false
	display.add_child(face)
	_screen_faces[id] = face
	if _screen_glow == null:
		var glow := _colour(str(look.get("glow", "#8FE8F0")))
		_screen_glow = StandardMaterial3D.new()
		_screen_glow.albedo_color = glow
		_screen_glow.emission_enabled = true
		_screen_glow.emission = glow
		_screen_glow.emission_energy_multiplier = SCREEN_GLOW_ENERGY
	add_screen(id)


func _draw_screen(id: String, shown: Dictionary) -> void:
	var face: MeshInstance3D = _screen_faces.get(id)
	if face == null or not is_instance_valid(face):
		return
	face.visible = shown["state"] != "idle"
	if shown["state"] == "live" and shown["feed"] != null:
		if _screen_live == null:
			# The computer's own pixels, as they are: unlit, so neither the
			# sun nor the night changes them.
			_screen_live = StandardMaterial3D.new()
			_screen_live.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_screen_live.albedo_texture = shown["feed"]
		var bright := 1.0 + SCREEN_PULSE_GAIN * float(shown["pulse"])
		_screen_live.albedo_color = Color(bright, bright, bright)
		face.material_override = _screen_live
	else:
		face.material_override = _screen_glow


func screen_feed_size(id: String) -> Vector2i:
	return SCREEN_FEED_SIZE if _screen_faces.has(id) else Vector2i.ZERO


func screen_point(id: String):
	if not _screen_faces.has(id):
		return null
	var face = display_face(id)
	return Vector2(face.origin.x, face.origin.z) if face is Transform3D else null


## The face lit over workstation `id`'s screen, or null.
func screen_overlay(id: String) -> Node:
	return _screen_faces.get(id)


## One of an entry's `scenes`, chosen by where it stands, or its `scene`.
func _variant(entry: Dictionary, at: Vector3) -> String:
	var list: Array = entry.get("scenes", [])
	if list.is_empty():
		return str(entry.get("scene", ""))
	return str(list[hash(Vector2i(roundi(at.x * 10), roundi(at.z * 10))) % list.size()])


## Lays copies of a module (`fit`: its length and depth) under `parent`
## along a footprint's long side, each stretched so its walking-band slice
## fills its share of the footprint exactly (three workbenches along the
## 10 m bench), turned to `facing`, the way the placement faces.
func _fit_prop(parent: Node3D, path: String, ob: Rect2, fit: Array, facing: float) -> void:
	var along_x := ob.size.x >= ob.size.y
	var length := ob.size.x if along_x else ob.size.y
	var depth := ob.size.y if along_x else ob.size.x
	var n := maxi(1, int(round(length / float(fit[0]))))
	var box: Rect2 = town.band_box(path)
	if box.size.x < 1e-3 or box.size.y < 1e-3:
		box = Rect2(-float(fit[0]) / 2.0, -float(fit[1]) / 2.0, float(fit[0]), float(fit[1]))
	var sl := length / n / box.size.x
	var sd := depth / box.size.y
	var turn := Basis(Vector3.UP, facing)
	for k in n:
		var t := (k + 0.5) * length / n
		var at := Vector3(ob.position.x + t, 0, ob.get_center().y) if along_x else Vector3(ob.get_center().x, 0, ob.position.y + t)
		var piece := _scene(path)
		piece.position = at - turn * Vector3(box.get_center().x * sl, 0.0, box.get_center().y * sd)
		piece.rotation.y = facing
		piece.scale = Vector3(sl, 1, sd)
		parent.add_child(piece)
		town._collect(piece)


## Timber boards over an indoor floor: rows of planks of a few lengths in
## two tones of the room's floor colour, staggered from row to row.
func _planks(area: Rect2, base: Color) -> void:
	var bt := MeshBatch.new()
	var tones := [MeshBatch.material(base, 0.75), MeshBatch.material(base.darkened(0.08), 0.75), MeshBatch.material(base.lightened(0.06), 0.75)]
	var board := 0.24
	var z := area.position.y
	var row := 0
	while z < area.end.y - 0.01:
		var x := area.position.x - float(hash(row) % 100) / 100.0 * 1.2
		var k := 0
		while x < area.end.x - 0.01:
			var length := 1.2 + float(hash(Vector2i(row, k)) % 3) * 0.6
			var a := maxf(x, area.position.x)
			var b := minf(x + length, area.end.x)
			if b - a > 0.05:
				bt.box(Vector3(b - a - 0.02, 0.04, board - 0.02), Transform3D(Basis(), Vector3((a + b) / 2.0, -0.0, z + board / 2.0)), tones[hash(Vector2i(k, row)) % 3])
			x += length
			k += 1
		z += board
		row += 1
	world.add_child(bt.build("Floorboards", false))


## Paving over an outdoor room from the style's `paving` tiles, each cell's
## pattern chosen and turned by its hash, so the square never visibly
## repeats.
func _paving(area: Rect2) -> void:
	var paving: Dictionary = style.get("paving", {})
	var names: Array = paving.get("tiles", [])
	if names.is_empty():
		return
	var size := float(paving.get("size", 1.0))
	var by_variant := {}
	for n in names:
		by_variant[n] = []
	var nx := maxi(1, int(round(area.size.x / size)))
	var nz := maxi(1, int(round(area.size.y / size)))
	for zi in nz:
		for xi in nx:
			var at := area.position + Vector2((xi + 0.5) * area.size.x / nx, (zi + 0.5) * area.size.y / nz)
			var h := absi(hash(Vector2i(roundi(at.x * 2), roundi(at.y * 2))))
			var turn := Basis(Vector3.UP, PI / 2.0 * (h % 4)).scaled(Vector3(area.size.x / nx / size, 1, area.size.y / nz / size))
			by_variant[names[(h / 4) % names.size()]].append(Transform3D(turn, Vector3(at.x, float(paving.get("y", -0.062)), at.y)))
	for name_ in names:
		world.add_child(town.tiles(name_, by_variant[name_], "Paving"))
	_box(Vector3(area.size.x, 0.1, area.size.y), Vector3(area.get_center().x, -0.12, area.get_center().y),
		_colour(str(style["palette"].get("paving_dark", "#CDB78F"))), world)


## Garden paths from each of a lawn room's doors to its centre, a metre
## of path at a time, first across then along.
func _paths(r: Dictionary, area: Rect2) -> void:
	var path: Dictionary = style.get("paths", {"tile": "path", "size": 1.0})
	var size := float(path.get("size", 1.0))
	var xf := []
	var centre := Vector2(floor(area.get_center().x / size) + 0.5, floor(area.get_center().y / size) + 0.5) * size
	var cells := {}
	for door in r.get("doors", []):
		if door.get("pos") == null:
			continue
		var p := CityGeometry.pt_m(door["pos"])
		var start := Vector2(clampf((floor(p.x / size) + 0.5) * size, area.position.x + size / 2.0, area.end.x - size / 2.0),
			clampf((floor(p.y / size) + 0.5) * size, area.position.y + size / 2.0, area.end.y - size / 2.0))
		var on_x_edge := absf(p.y - area.position.y) < 0.05 or absf(p.y - area.end.y) < 0.05
		var corner := Vector2(start.x, centre.y) if on_x_edge else Vector2(centre.x, start.y)
		for leg in [[start, corner], [corner, centre]]:
			var a: Vector2 = leg[0]
			var b: Vector2 = leg[1]
			var steps := int(round(a.distance_to(b) / size))
			for k in steps + 1:
				var c: Vector2 = a.lerp(b, float(k) / maxf(steps, 1))
				var key := Vector2i(roundi(c.x * 2 / size), roundi(c.y * 2 / size))
				if cells.has(key):
					continue
				cells[key] = true
				var runs_z := absf(b.x - a.x) < 0.01
				xf.append(Transform3D(Basis(Vector3.UP, 0.0 if runs_z else PI / 2.0), Vector3(c.x, float(path.get("y", -0.05)), c.y)))
	if not xf.is_empty():
		world.add_child(town.tiles(str(path["tile"]), xf, "Paths"))


## Tiles a floor area with a kit piece of `size` metres, stretched a little
## to fit exactly.
func _lay(area: Rect2, piece: String, size: float, y: float) -> void:
	var nx := maxi(1, int(round(area.size.x / size)))
	var nz := maxi(1, int(round(area.size.y / size)))
	var sx := area.size.x / (nx * size)
	var sz := area.size.y / (nz * size)
	var xf := []
	for zi in nz:
		for xi in nx:
			xf.append(Transform3D(Basis().scaled(Vector3(sx, 1, sz)), Vector3(area.position.x + (xi + 0.5) * size * sx, y, area.position.y + (zi + 0.5) * size * sz)))
	world.add_child(town.tiles(piece, xf, "Floor"))


func _outdoor(id: String) -> bool:
	var r = room_rects.get(id)
	return r != null and (r.get("outdoor", false) or str(r.get("template", "")) in ["plaza", "outdoor"])


## Cut-away walls: full height on a room's north and west edges, low on its
## south and east, with a gap as wide as every door. An edge two indoor
## rooms share is drawn once, by the room with the lower ID, centred on
## it and as thick as its building's wall (the core's partition, spec
## §3); a building's outline is its shell's (town.building).
func _walls(r: Dictionary, rooms: Array) -> void:
	var rect: Dictionary = r["rect"]
	var x0: float = rect["x"] / 100.0
	var z0: float = rect["z"] / 100.0
	var x1: float = x0 + rect["w"] / 100.0
	var z1: float = z0 + rect["d"] / 100.0
	var doors := []
	for door in r.get("doors", []):
		if door.get("pos") != null:
			doors.append({"pos": _m(door["pos"]), "width": CityGeometry.door_width(door, {}, false)})
	var edges := [
		["north", Vector3(x0, 0, z0), Vector3(x1, 0, z0), WALL_HEIGHT],
		["west", Vector3(x0, 0, z0), Vector3(x0, 0, z1), WALL_HEIGHT],
		["south", Vector3(x0, 0, z1), Vector3(x1, 0, z1), LOW_WALL],
		["east", Vector3(x1, 0, z0), Vector3(x1, 0, z1), LOW_WALL],
	]
	var colour := _colour(str(style.get("palette", {}).get("limewash", "#EFE6D2")))
	var fp = footprints.get(r["id"])
	for e in edges:
		if not _draws_edge(r, e[1], e[2], rooms):
			continue
		if fp != null and CityGeometry.on_perimeter(Vector2(e[1].x, e[1].z), Vector2(e[2].x, e[2].z), fp):
			continue
		_wall_segment(e[1], e[2], e[3], doors, colour, str(_facility_of.get(r["id"], "")), float(_wall_of.get(r["id"], WALL_THICK)))


## The heights (metres) at which a wall is measured for the first-person
## eye: from a seated eye to a little over a standing one. What a façade
## carries above them (banners, cornices, eaves) or below them (plinths,
## steps) is not in the eye's way.
const EYE_BAND := Vector2(FpvCamera.SEATED_EYE, FpvCamera.EYE_HEIGHT + 0.4)


## The walls of building `b` the first-person eye keeps clear of: each
## side's solid runs between its doors, as deep as its pieces reach across
## the side's line at the eye's height (outside the rooms, in the shell's
## ring, where a town fits them there); door pieces, with their frames and
## leaves, are left to the door's opening.
func _shell_walls(b: Dictionary, shell: Dictionary) -> void:
	for s in b["sides"]:
		var a: Vector2 = s["a"]
		var end: Vector2 = s["b"]
		var run := a.distance_to(end)
		var along := (end - a) / run
		var normal: Vector2 = s["normal"]
		var lo := INF
		var hi := -INF
		for mi in shell["sides"][s["side"]]["full"].find_children("*", "MeshInstance3D", true, false):
			var piece := str(mi.get_parent().name)
			if "door" in piece or "entrance" in piece or mi.mesh == null:
				continue
			var xf := _to_world(mi)
			for k in mi.mesh.get_surface_count():
				for p in KitTown._band_points(xf * KitTown._surface_triangles(mi.mesh, k), EYE_BAND):
					var out: float = (p - a).dot(normal)
					lo = minf(lo, out)
					hi = maxf(hi, out)
		if lo > hi:
			lo = -0.3
			hi = 0.3
		var line := a + normal * (lo + hi) / 2.0
		var start := 0.0
		var cuts := []
		for k in s["openings"].size():
			cuts.append([s["openings"][k] - s["widths"][k] / 2.0, s["openings"][k] + s["widths"][k] / 2.0])
		cuts.append([run, run])
		for c in cuts:
			if c[0] - start > 0.05:
				walls.append({"a": line + along * start, "b": line + along * c[0], "half": (hi - lo) / 2.0})
			start = c[1]


## A node's transform in world space, whether or not it is in the tree.
static func _to_world(n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p is Node3D:
		t = p.transform * t
		p = p.get_parent()
	return t


func _draws_edge(r: Dictionary, a: Vector3, b: Vector3, rooms: Array) -> bool:
	for other in rooms:
		if other["id"] == r["id"] or _outdoor(other["id"]):
			continue
		var o: Dictionary = other["rect"]
		var ox0: float = o["x"] / 100.0
		var oz0: float = o["z"] / 100.0
		var ox1: float = ox0 + o["w"] / 100.0
		var oz1: float = oz0 + o["d"] / 100.0
		var shared := false
		if is_equal_approx(a.z, b.z):
			shared = (is_equal_approx(a.z, oz0) or is_equal_approx(a.z, oz1)) and minf(b.x, ox1) - maxf(a.x, ox0) > 0.01
		else:
			shared = (is_equal_approx(a.x, ox0) or is_equal_approx(a.x, ox1)) and minf(b.z, oz1) - maxf(a.z, oz0) > 0.01
		if shared and str(other["id"]) < str(r["id"]):
			return false
	return true


func _wall_segment(a: Vector3, b: Vector3, height: float, doors: Array, colour: Color, facility: String, thick := WALL_THICK) -> void:
	var along := (b - a).normalized()
	var length := a.distance_to(b)
	var cuts := []
	for door in doors:
		var p: Vector3 = door["pos"]
		var t: float = (p - a).dot(along)
		var off: float = (p - (a + along * t)).length()
		if off < 0.05 and t > 0 and t < length:
			cuts.append([t - door["width"] / 2.0, t + door["width"] / 2.0])
	cuts.sort()
	cuts.append([length, length])
	var start := 0.0
	for c in cuts:
		var end: float = minf(c[0], length)
		if end - start > 0.05:
			var mid := a + along * ((start + end) / 2.0)
			walls.append({"a": Vector2(a.x, a.z) + Vector2(along.x, along.z) * start,
				"b": Vector2(a.x, a.z) + Vector2(along.x, along.z) * end, "half": thick / 2.0})
			var size := Vector3(end - start, height, thick) if is_equal_approx(a.z, b.z) else Vector3(thick, height, end - start)
			_box(size, mid + Vector3(0, height / 2.0, 0), colour, world).set_meta("building", facility)
		start = c[1]


# ---- Camera ----

func _camera(bounds: Rect2, whole: Rect2) -> void:
	rig = OrbitRig.new()
	world.add_child(rig)
	camera = rig.camera
	var plaza = room_rects.get("room:plaza")
	var street := Vector3(bounds.get_center().x, 0, bounds.get_center().y)
	if plaza != null:
		var rc: Dictionary = plaza["rect"]
		street = Vector3((rc["x"] + rc["w"] / 2.0) / 100.0, 0, (rc["z"] + rc["d"] / 2.0) / 100.0)
	rig.frame(bounds, street, whole)


func camera_presets() -> Array:
	return OrbitRig.PRESETS.duplicate()


func set_camera_preset(name_: String) -> bool:
	var ok := rig != null and rig.apply_preset(name_)
	_refresh_open()
	return ok


## The viewer's position over the ground, in centimetres: the eye in first
## person, else the orbit camera.
func camera_ground_pos():
	if fpv != null:
		return Vector2(fpv.position.x, fpv.position.z) * 100.0
	return rig.ground_pos() if rig != null else null


func end_drag() -> void:
	if rig != null:
		rig.dragging = false


## Overhead, the rig looks at the chair from close behind it, low, the way
## its sitter faces (the rig's yaw is the negated compass bearing: at 0 it
## looks north); in first person the eye turns (see StylePack).
func settle_view(chair_cm: Vector2, facing: int) -> Variant:
	if fpv != null or rig == null:
		return super.settle_view(chair_cm, facing)
	var saved := {"rig": [rig.position, rig.yaw, rig.pitch, rig.distance]}
	rig.pitch = COMPUTER_PITCH
	rig.fly_to(Vector3(chair_cm.x, 0, chair_cm.y) / 100.0, COMPUTER_DISTANCE, float(-facing), 0.0)
	_refresh_open()
	return saved


func restore_view(saved: Variant) -> void:
	if not (saved is Dictionary and saved.has("rig")) or rig == null:
		super.restore_view(saved)
		return
	var was: Array = saved["rig"]
	rig.pitch = was[2]
	rig.fly_to(was[0], was[3], was[1], 0.0)
	_refresh_open()


func _unhandled_input(event: InputEvent) -> void:
	if rig != null:
		rig.handle(event)
		_refresh_open()


func pick(screen_pos: Vector2) -> String:
	if camera == null:
		return ""
	var hit = rig.ground_hit(screen_pos)
	if hit == null:
		return ""
	var best := ""
	var best_d := 0.8
	for id in nodes:
		var at: Vector3 = nodes[id].global_position if nodes[id].is_inside_tree() else nodes[id].position
		var d: float = Vector2(at.x, at.z).distance_to(Vector2(hit.x, hit.z))
		if d < best_d:
			best = id
			best_d = d
	return best


# ---- Occupants ----

func _is_agent(view: Dictionary) -> bool:
	return occupant_key(view) in ["GuildAgent", "CityRoleAgent", "PersonalAgent"]


func _pick_colour(list: Array, key, fallback: String) -> Color:
	if list.is_empty():
		return _colour(fallback)
	return _colour(str(list[int(str(key)) % list.size() if str(key).is_valid_int() else hash(str(key)) % list.size()]))


func make_occupant(view: Dictionary) -> Node:
	var id: String = view["id"]
	var entry := resolve("occupants", occupant_key(view))
	var root := Node3D.new()
	root.name = id.replace(":", "_")
	var model: Node3D = _scene(str(entry.get("by_id", {}).get(id, entry.get("scene", "")))) if not entry.get("placeholder", false) else _placeholder()
	model.name = "Model"
	root.add_child(model)
	var appearance: Dictionary = view.get("appearance", {})
	var h := absi(hash(id))
	model.scale = Vector3.ONE * float(entry.get("scale", 1.0))
	if _is_agent(view):
		# The kit robot's shell and panels carry the agent's kind (guild
		# yellow, city teal, a smaller lavender personal agent); a pack's
		# own robots come ready-painted.
		if entry.has("body"):
			_paint(model, "shell", _colour(str(entry["body"])))
		if entry.has("accent"):
			_paint(model, "panel", _colour(str(entry["accent"])))
	else:
		# Outfit k sets the whole look — top, trousers bottoms[(k + k/4) % 4],
		# skin[k % 4], hair colour hair_colours[(k + 1) % 4] — as the pixel
		# style draws it, so a person looks the same in every style.
		var palette_key = appearance.get("palette", id)
		var k := int(str(palette_key)) if str(palette_key).is_valid_int() else absi(hash(str(palette_key)))
		var outfit := _pick_colour(style.get("outfits", []), k, "#2F8C8C")
		var bottom := _pick_colour(style.get("bottoms", []), k + k / 4, "#3E5C7A")
		var skin := _pick_colour(style.get("skin", []), k, "#C98E6B")
		var hair_colour := _pick_colour(style.get("hair_colours", []), k + 1, "#3A2A1E")
		if entry.get("muted", false):
			outfit = outfit.lerp(Color(0.62, 0.62, 0.6), 0.55)
			bottom = bottom.lerp(Color(0.5, 0.5, 0.5), 0.4)
		_paint(model, "top", outfit)
		_paint(model, "bottom", bottom)
		_paint(model, "skin", skin)
		var hair := int(str(appearance.get("hair", "0"))) if str(appearance.get("hair", "0")).is_valid_int() else 0
		for style_ in 4:
			var node = model.find_child("hair_%d" % style_, true, false)
			if node != null:
				node.visible = style_ == hair % 4
				_paint(model, "hair_%d" % style_, hair_colour)
		# A backpack goes with outfits 1, 5 and 6 in every style; sun hats
		# only on the background crowd, since pixel art has no room for one.
		_show(model, "hat_sun", entry.get("muted", false) and h % 4 == 0)
		_show(model, "backpack", posmod(k, 8) in [1, 5, 6])
	# A person's small parts (the face plate, soles, eyes, badge) cast
	# shadows nobody sees.
	for part in SHADOWLESS_PARTS:
		var small = model.find_child(part, true, false)
		if small is GeometryInstance3D:
			small.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# An umbrella, if the kit has one, stays furled until it rains outdoors.
	var umbrella = model.find_child("umbrella", true, false)
	if umbrella != null:
		_umbrellas[id] = umbrella
		umbrella.visible = false
		_paint(model, "umbrella", _pick_colour(style.get("umbrellas", []), h, "#E4513B"))
	var player := _player_of(model)
	if player != null:
		for clip in player.get_animation_list():
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_mixers[id] = player
		_live[id] = player
		# A phase of its own, so a crowd's poses fall on different frames.
		_owed[id] = float(absi(hash(id)) % 97) / 97.0 / ANIM_MAX_HZ
	# Presence shows as an icon, or as a glyph where a style has no icons.
	var icon := Sprite3D.new()
	icon.name = "Icon"
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.pixel_size = 0.006
	icon.position = Vector3(0, 2.25, 0)
	icon.no_depth_test = true
	icon.visible = false
	root.add_child(icon)
	var glyph := Label3D.new()
	glyph.name = "Glyph"
	glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glyph.no_depth_test = true
	glyph.font_size = 64
	glyph.outline_size = 14
	glyph.pixel_size = 0.006
	glyph.position = Vector3(0, 2.25, 0)
	glyph.visible = false
	root.add_child(glyph)
	var label := Label3D.new()
	label.name = "Label"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 40
	label.outline_size = 10
	label.pixel_size = 0.006
	label.position = Vector3(0, 2.0, 0)
	label.visible = false
	root.add_child(label)
	labels[id] = label
	return root


func _paint(model: Node, part: String, colour: Color) -> void:
	var n = model.find_child(part, true, false)
	var m := MeshBatch.material(colour, 0.85)
	if n is MeshInstance3D:
		n.material_override = m
	elif n != null:
		for c in n.find_children("*", "MeshInstance3D", true, false):
			c.material_override = m
	if n != null:
		_style_node(n)


func _show(model: Node, part: String, on: bool) -> void:
	var n = model.find_child(part, true, false)
	if n != null:
		n.visible = on


static func _player_of(model: Node) -> AnimationPlayer:
	var found := model.find_children("*", "AnimationPlayer", true, false)
	return found[0] if not found.is_empty() else null


## The far body takes the colours the near parts were painted, surface by
## surface (its surfaces are named by role), and shows only beyond FAR_M,
## where the near parts give way. Returns whether the model has one.
func _dress_far(model: Node3D) -> bool:
	var far = model.find_child("far", true, false)
	if not (far is MeshInstance3D):
		return false
	far.visibility_range_begin = FAR_M
	far.visibility_range_begin_margin = 2.0
	var hair := ""
	for k in 4:
		var node = model.find_child("hair_%d" % k, true, false)
		if node != null and node.visible:
			hair = "hair_%d" % k
	for s in far.mesh.get_surface_count():
		var role := str(far.mesh.surface_get_material(s).resource_name)
		var source = model.find_child(hair if role == "hair" else role, true, false)
		if source is GeometryInstance3D and source.material_override != null:
			far.set_surface_override_material(s, source.material_override)
	return true


## Near parts give way to the far body at FAR_M.
func _near_parts_end(model: Node3D) -> void:
	for mi in model.find_children("*", "GeometryInstance3D", true, false):
		if mi.name != "far":
			mi.visibility_range_end = FAR_M
			mi.visibility_range_end_margin = 2.0


## Shows the umbrellas of people outdoors while it rains.
func _update_umbrellas() -> void:
	_umbrellas_open = rain > 0.15
	for id in _umbrellas:
		var umbrella: Node3D = _umbrellas[id]
		if not is_instance_valid(umbrella) or not nodes.has(id):
			continue
		var p: Vector3 = nodes[id].position
		umbrella.visible = rain > 0.15 and not _indoors(Vector2(p.x, p.z)) and poses.get(id) != "sitting" \
			and not riders.has(id)


func _indoors(p_m: Vector2) -> bool:
	if _indoor_rects.is_empty() and not room_rects.is_empty():
		for id in room_rects:
			if not _outdoor(id):
				_indoor_rects.append(CityGeometry.rect_m(room_rects[id]["rect"]))
	for r in _indoor_rects:
		if r.has_point(p_m):
			return true
	return false


func place(id: String, pos_cm: Vector2, dir: Vector2) -> void:
	if not nodes.has(id):
		return
	var root: Node3D = nodes[id]
	var seat = _perched(id)
	_on_perch[id] = seat
	if seat != null:
		var on := _to_world(seat)
		var front := -on.basis.z
		root.position = Vector3(on.origin.x, deck_at(Vector2(on.origin.x, on.origin.z)), on.origin.z)
		root.rotation.y = atan2(-front.x, -front.z)
		return
	root.position.x = pos_cm.x / 100.0
	root.position.z = pos_cm.y / 100.0
	root.position.y = deck_at(pos_cm / 100.0)
	if dir != Vector2.ZERO:
		root.rotation.y = atan2(-dir.x, -dir.y)
	else:
		root.rotation.y = _facing_rotation(float(views.get(id, {}).get("facing", 0)))


func set_pose(id: String, pose: String) -> void:
	super(id, pose)
	_animate(id)


## A view that starts or ends a sit on a perch moves its body on or off
## the seat (_perched) at once: a sitter comes to rest before its use
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


func set_presence(id: String, headline: String) -> void:
	super(id, headline)
	if not nodes.has(id):
		return
	var entry := resolve("headlines", headline)
	var icon: Sprite3D = nodes[id].get_node("Icon")
	var glyph: Label3D = nodes[id].get_node("Glyph")
	var view: Dictionary = views.get(id, {})
	var shows := _is_agent(view) or id == selected
	icon.visible = shows and entry.has("icon")
	glyph.visible = shows and not entry.has("icon") and entry.has("glyph")
	if icon.visible:
		icon.texture = load(asset(str(entry["icon"])))
	if glyph.visible:
		glyph.text = str(entry["glyph"])
	var model: Node3D = nodes[id].get_node("Model")
	model.visible = true
	# Offline people fade: per instance, so shared materials are untouched.
	for g in model.find_children("*", "GeometryInstance3D", true, false):
		g.transparency = 0.55 if headline == "Offline" else 0.0
	# Riders show no icon, and fade with their tram.
	if riders.has(id):
		_hide_status(id)
		_fade_rider(id, maxf(0.0, float(_trams.get(riders[id], {}).get("opacity", 1.0))))
	_animate(id)


func set_selected(id: String) -> void:
	super.set_selected(id)
	for x in nodes:
		set_presence(x, headlines.get(x, "Unknown"))


## Plays the clip for a person's pose: walk while moving, typing when
## seated at work, sit when seated, idle otherwise; clips crossfade.
func _animate(id: String) -> void:
	if not nodes.has(id):
		return
	var player := _player_of(nodes[id].get_node("Model"))
	if player == null:
		return
	var pose: String = poses.get(id, "standing")
	var clip := "idle"
	match pose:
		"walking":
			clip = "walk"
		"sitting":
			clip = "typing" if headlines.get(id, "") == "Working" else "sit"
	# A model may name its clips differently (the entry's `clips` maps the
	# kit's names to its own) and walk at its own pace.
	var entry := resolve("occupants", occupant_key(views.get(id, {})))
	player.speed_scale = _walk_scale(entry) * stride_scale(id) if clip == "walk" else 1.0
	clip = str(entry.get("clips", {}).get(clip, clip))
	if not player.has_animation(clip):
		return
	if player.current_animation == clip:
		return
	var first := player.current_animation == ""
	player.play(clip, 0.0 if first else BLEND_S)
	if first:
		# People nearby should not breathe in step.
		player.seek(float(absi(hash(id)) % 1000) / 1000.0 * player.current_animation_length, true)
	if riders.has(id):
		_pose_once(id)


func shift_view(ground_cm: Vector2) -> void:
	if rig != null:
		rig.position += Vector3(ground_cm.x, 0, ground_cm.y) / 100.0


## Behind the title the camera circles the square's centre, a turn every
## three minutes, at the diagonal preset's pitch and distance.
func title_drift(on: bool) -> void:
	if rig == null or fpv != null:
		return
	if on:
		var heart := _heart()
		rig.drift(Vector3(heart.x, 0, heart.y))
		_refresh_open()
	else:
		rig.stop_drift()


## Flies the camera to look at `ground_cm` from the current preset's
## distance and heading (the diagonal's, from the south-east), turning the
## short way from wherever the drift had got to; at 0 seconds it cuts.
## With `keep_view` it keeps the heading and distance it has, and only
## slides.
func fly_to(ground_cm: Vector2, seconds: float, keep_view := false) -> void:
	if rig == null:
		return
	var yaw := rig.yaw if keep_view else rig.preset_yaw()
	var distance := rig.distance if keep_view else rig.preset_distance()
	rig.fly_to(Vector3(ground_cm.x, 0, ground_cm.y) / 100.0, distance, yaw, seconds)
	_refresh_open()


static func _walk_scale(entry: Dictionary) -> float:
	return float(entry.get("walk_scale", WALK_SPEED_SCALE))


func _restride(id: String) -> void:
	if poses.get(id) != "walking" or not nodes.has(id):
		return
	var player := _player_of(nodes[id].get_node("Model"))
	if player != null:
		player.speed_scale = _walk_scale(resolve("occupants", occupant_key(views.get(id, {})))) * stride_scale(id)


func _process(delta: float) -> void:
	# The title's drift, or Explore's flight down into play.
	if rig != null and (rig.drifting or rig.flying()):
		rig.advance(delta)
		_refresh_open()
	# In first person the walls that drop follow the eye as it moves.
	if fpv != null and not open_ids.is_empty():
		var eye := Vector2(fpv.position.x, fpv.position.z)
		if eye.distance_to(_eye_at_refresh) > 0.5:
			_eye_at_refresh = eye
			_refresh_open()
	# The sun's shadows reach the ground from the camera: the style's reach
	# up close, further when the view is further off (the top-down view).
	if sun != null and rig != null and style.has("shadow_distance"):
		var reach := shadow_reach()
		if fpv == null:
			reach = maxf(reach, rig.distance * 1.3)
		if absf(sun.directional_shadow_max_distance - reach) > 1.0:
			sun.directional_shadow_max_distance = reach
	# Haze starts beyond what the camera frames, so only the far city fades.
	if env != null and rig != null:
		var reach := rig.distance if fpv == null else 0.0
		env.fog_depth_begin = reach + 40.0
		env.fog_depth_end = reach + 280.0
	_bob_clock += delta
	var view_cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if view_cam != null and _planting.size() > 0:
		var eye := view_cam.global_position
		if Vector2(eye.x - _plant_shadow_at.x, eye.z - _plant_shadow_at.z).length() > 4.0:
			update_plant_shadows(Vector3(eye.x, 0, eye.z))
	_advance_people(delta)
	animate_vehicles(delta)
	_follow_rain()
	if rain > 0.1 and not _streaks.is_empty() and not calm:
		_turn_streaks()
	_umbrella_clock += delta
	if rain > 0.0 and _umbrella_clock > 0.25:
		_umbrella_clock = 0.0
		_update_umbrellas()
	# Clouds would hide the city from a camera looking straight down.
	var sky_shown := rig == null or rig.pitch > -62.0
	for k in boats.size():
		boats[k].position.y = _water_y() + sin(_bob_clock * 1.3 + k * 1.7) * 0.05
	for cloud in clouds:
		cloud.visible = sky_shown
		cloud.position.x += delta * 0.9
		if cloud.position.x > sky_box.end.x:
			cloud.position.x = sky_box.position.x


# ---- Time ----

func set_time_of_day(m: int) -> void:
	super(m)
	if sun == null:
		return
	var k := _key_at(float(m))
	if k.is_empty():
		return
	var day := clampf(sin((m - 360.0) / 720.0 * PI), 0.0, 1.0)
	set_daylight(float(m))
	# Rain greys the sky and the haze toward the style's overcast.
	var overcast := _colour(str(style.get("palette", {}).get("overcast", "#8A95A0")))
	var grey := _sky_rain * 0.65
	sky_material.sky_top_color = k["sky_top"].lerp(overcast.darkened(0.25), grey)
	sky_material.sky_horizon_color = k["horizon"].lerp(overcast, grey)
	sky_material.ground_horizon_color = k["horizon"].lerp(overcast, grey)
	sky_material.ground_bottom_color = k["ambient"].darkened(0.4)
	env.ambient_light_color = k["ambient"]
	env.ambient_light_energy = k["ambient_energy"] * (1.0 - 0.2 * _sky_rain)
	env.fog_light_color = k["fog"].lerp(overcast, grey)
	var dn: Dictionary = style.get("day_night", {})
	var lit := m >= int(dn.get("lamps_on_from", 1110)) or m < int(dn.get("lamps_off_at", 390))
	if not _streaks.is_empty():
		_shade_streaks()
	# A style whose glow is only for lit things (lamps, windows, neon) draws
	# the glow pass only while they are lit.
	if style.get("glow_night_only", false):
		env.glow_enabled = lit
	var lamp_energy := float(style.get("lamp_energy", 2.4))
	for lamp in lamps:
		lamp.light_energy = lamp_energy * float(lamp.get_meta("energy_scale", 1.0)) if lit else 0.0
		# A dark lamp still costs the frame its light's culling and shading.
		lamp.visible = lit
	if town != null:
		var window_energy := float(style.get("window_energy", 2.5))
		# Glass glows warm after dark, unless the style lights only its
		# window panes (so lit and dark windows mix).
		var glass_glow := 1.5 if style.get("glass_glow", true) else 0.0
		for glass in town.glass_materials:
			glass.emission_energy_multiplier = lerpf(glass_glow, 0.0, clampf(day * 3.0, 0.0, 1.0))
		for lamp_mat in town.lamp_materials:
			lamp_mat.emission_energy_multiplier = window_energy if lit else 0.35
	# The trams' insides light up with the lamps.
	for t in _trams.values():
		_light_tram(t)


## The sun at `m` minutes past midnight, fractions included: its angle,
## colour and strength. Called every frame so shadows sweep rather than step;
## the sky, ambient light and lamps follow the whole minutes of each tick.
func set_daylight(m: float) -> void:
	if sun == null:
		return
	var k := _key_at(m)
	if k.is_empty():
		return
	var day := clampf(sin((m - 360.0) / 720.0 * PI), 0.0, 1.0)
	sun.light_color = k["sun"]
	sun.light_energy = k["sun_energy"]
	# East at sunrise, south at noon, west at sunset; the moon keeps a
	# shallow light from the south-west at night.
	# Cloud under rain dims the sun.
	sun.light_energy *= 1.0 - 0.6 * rain
	# A style may drop the sun's shadows when it is only a dim moon (or a
	# sun behind rain cloud): they are all but invisible, and cost a whole
	# shadow pass.
	var min_sun := float(style.get("shadow_min_sun", 0.0))
	if min_sun > 0.0:
		sun.shadow_enabled = sun.light_energy >= min_sun
	var yaw := 90.0 - 180.0 * clampf((m - 360.0) / 720.0, 0.0, 1.0) if day > 0.0 else -35.0
	sun.rotation_degrees = Vector3(-lerpf(16.0, 58.0, day) if day > 0.0 else -40.0, yaw, 0)


# ---- Animation by how much it shows ----

## Advances each person's animation as closely as they are seen: every
## frame when tall on screen, every second or fourth frame (by the time
## owed, so the same speed) when small, not at all out of view. Staggered
## by id so the small ones never all update on one frame.
func _advance_people(delta: float) -> void:
	_anim_frame += 1
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var px_per_m := get_viewport().get_visible_rect().size.y / (2.0 * tan(deg_to_rad(cam.fov) / 2.0))
	for id in _live:
		var player: AnimationPlayer = _live[id]
		var node: Node3D = nodes.get(id)
		if node == null or not node.visible:
			continue
		var head := node.global_position + Vector3(0, 1.0, 0)
		# Seen if any of feet, waist or head is in view: close up, one of
		# them alone can fill the screen.
		var at := node.global_position
		_seen[id] = cam.is_position_in_frustum(at + Vector3(0, 0.1, 0)) or cam.is_position_in_frustum(head) \
			or cam.is_position_in_frustum(at + Vector3(0, 1.8, 0))
		if not _seen[id]:
			continue
		var tall := 1.8 * px_per_m / maxf(cam.global_position.distance_to(head), 0.1)
		var step := 1 if tall >= ANIM_FULL_PX else (2 if tall >= ANIM_HALF_PX else 4)
		_step[id] = step
		_owed[id] += delta
		if (step == 1 or (_anim_frame + absi(hash(id))) % step == 0) and _owed[id] >= 1.0 / ANIM_MAX_HZ:
			player.advance(_owed[id])
			_owed[id] = 0.0


## Whether `id` was in view when people were last animated (unknown: yes).
func is_seen(id: String) -> bool:
	return _seen.get(id, true)


## Every how many frames `id` need be moved: as often as it is animated.
func move_every(id: String) -> int:
	return int(_step.get(id, 1))


func despawn(id: String) -> void:
	_forget(id)
	super(id)


# ---- Rain ----

func set_rain(amount: float) -> void:
	super(amount)
	if amount > 0.001 and rain_node == null:
		rain_node = _make_rain()
	if rain_node != null:
		if rain_node.amount != rain_particles():
			rain_node.amount = rain_particles()
		rain_node.amount_ratio = clampf(amount, 0.0, 1.0)
		rain_node.visible = amount > 0.001
		rain_node.emitting = rain_node.visible
	# The sky greys in whole steps, so easing rain never re-lights it each
	# frame.
	if absf(amount - _sky_rain) > 0.02 or (amount == 0.0 and _sky_rain != 0.0):
		_sky_rain = amount
		if minutes >= 0:
			set_time_of_day(minutes)
	if style.get("rain_streaks", false):
		if amount > 0.001 and _streaks.is_empty() and not calm:
			_make_streaks()
		_shade_streaks()
	if style.get("wet_ground", false):
		_wet_ground(amount)
	if (amount > 0.15) != _umbrellas_open:
		_update_umbrellas()


## Paving and streets darken and turn glossy as they wet.
func _wet_ground(amount: float) -> void:
	if _wet.is_empty() and world != null and amount > 0.001:
		for n in world.find_children("*", "GeometryInstance3D", true, false):
			for m in Toon.materials_of(n):
				if m is BaseMaterial3D and not _wet.has(m) and WET_MATERIALS.any(func(w): return str(m.resource_name).begins_with(w)):
					_wet[m] = [StylePack.original(m, "roughness", m.roughness), StylePack.original(m, "albedo", m.albedo_color)]
	var k := clampf(amount, 0.0, 1.0)
	for m in _wet:
		m.roughness = lerpf(_wet[m][0], 0.1, k)
		m.albedo_color = _wet[m][1].darkened(0.3 * k)


## The streaks as strong as the rain, and stronger after dark.
func _shade_streaks() -> void:
	var night := minutes >= 0 and (minutes >= 1080 or minutes < 390)
	for st in _streaks:
		st.visible = rain > 0.1 and not calm
		st.transparency = 1.0 - clampf(rain, 0.0, 1.0) * (0.85 if night else 0.35)


## A stretched glow on the ground under each lamp: the long reflection wet
## paving throws, turned toward the camera every frame.
func _make_streaks() -> void:
	_streak_material = StandardMaterial3D.new()
	_streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_streak_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_streak_material.albedo_color = Color(str(style.get("palette", {}).get("lamp_glow", "#FFE3A6")))
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1.0, 0.5)
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(1, 1, 1, 0.9))
	grad.gradient.set_color(1, Color(1, 1, 1, 0.0))
	_streak_material.albedo_texture = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 3.0)
	quad.orientation = PlaneMesh.FACE_Y
	for lamp in lamps:
		var st := MeshInstance3D.new()
		st.mesh = quad
		st.material_override = _streak_material
		st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(st)
		st.set_meta("base", Vector3(lamp.global_position.x, 0.03, lamp.global_position.z))
		st.global_position = st.get_meta("base")
		_streaks.append(st)


func _turn_streaks() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for st in _streaks:
		var base: Vector3 = st.get_meta("base")
		var to_cam := Vector2(cam.global_position.x - base.x, cam.global_position.z - base.z).normalized()
		st.rotation.y = atan2(to_cam.x, to_cam.y)
		# The streak runs from under the lamp toward the viewer.
		st.global_position = base + Vector3(to_cam.x, 0, to_cam.y) * 1.5


## How many streaks fall at full rain: RAIN_STREAKS, or a quarter of them
## in calm mode.
func rain_particles() -> int:
	return maxi(1, RAIN_STREAKS / 4) if calm else RAIN_STREAKS


## Streaks falling through a box round the view: thin vertical quads that
## face the camera, lit by nothing, pale against dark and dark against sky.
func _make_rain() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Rain"
	p.amount = rain_particles()
	p.lifetime = 1.4
	p.preprocess = 1.4
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-80, -40, -80), Vector3(160, 80, 160))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(30, 1, 30)
	pm.direction = Vector3(0.08, -1, 0.03)
	pm.spread = 2.0
	pm.initial_velocity_min = 16.0
	pm.initial_velocity_max = 20.0
	pm.gravity = Vector3(0, -4, 0)
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.018, 0.55)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.albedo_color = _colour(str(style.get("palette", {}).get("rain", "#C8D6E4")))
	m.albedo_color.a = 0.38
	quad.material = m
	p.draw_pass_1 = quad
	add_child(p)
	_follow_rain(p)
	return p


## Keeps the rain over what the camera sees: round the eye in first person,
## and round the rig's focus (wider as it pulls back) overhead.
func _follow_rain(p: GPUParticles3D = rain_node) -> void:
	if p == null or not p.visible:
		return
	var pm: ParticleProcessMaterial = p.process_material
	if fpv != null:
		p.global_position = fpv.global_position + Vector3(0, 12, 0) if fpv.is_inside_tree() else fpv.position + Vector3(0, 12, 0)
		pm.emission_box_extents = Vector3(18, 1, 18)
	elif rig != null:
		var reach := clampf(rig.distance * 0.7, 20.0, 80.0)
		p.position = rig.position + Vector3(0, 18, 0)
		pm.emission_box_extents = Vector3(reach, 1, reach)


# ---- The map's base picture ----

## How high over the ground the map's camera stands, in metres: above
## every roof, looking straight down.
const MAP_EYE_M := 200.0
## How far past the ground the sun's shadows reach while the map is drawn,
## so they fall on the river below the camera too.
const MAP_SHADOW_BELOW_M := 40.0
## The size of the map picture asked for and not yet drawn, or null.
var _map_asked = null
## What the render changed, as it was, to put back in the frame it is
## drawn (see _hide_for_map).
var _map_saved := {}


## Draws the district from straight above (see StylePack.request_map): a
## SubViewport sharing this world, drawn once by an orthographic camera
## over `extent_m`. For that one frame the people, the player's marker, the
## reticle, the rain, the clouds and the cut-aways go, the roofs are on,
## and the light is the style's map time without rain, at its map
## exposure; in the same frame
## the world is put back as it was. A request made while one waits
## replaces it; one answer comes.
func request_map(extent_m: Rect2, size_px: Vector2i) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or world == null:
		return
	var old := get_node_or_null("MapView")
	if old != null:
		old.free()
	var view := SubViewport.new()
	view.name = "MapView"
	view.own_world_3d = false
	view.transparent_bg = false
	view.size = Vector2i(maxi(size_px.x, 1), maxi(size_px.y, 1))
	view.msaa_3d = msaa_level()
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cam := Camera3D.new()
	cam.name = "MapCamera"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = extent_m.size.y
	cam.far = MAP_EYE_M + MAP_SHADOW_BELOW_M
	cam.position = Vector3(extent_m.get_center().x, MAP_EYE_M, extent_m.get_center().y)
	# Straight down, with -Z (north) at the top of the picture.
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.current = true
	view.add_child(cam)
	add_child(view)
	if _map_asked == null:
		# Hidden as late as can be, after every _process of the frame (which
		# eases the sun, the rain and the clouds), and put back as soon as
		# it is drawn, before any _process of the next.
		RenderingServer.frame_pre_draw.connect(_hide_for_map, CONNECT_ONE_SHOT)
		RenderingServer.frame_post_draw.connect(_take_map, CONNECT_ONE_SHOT)
	_map_asked = view.size


## Whether a waiting render can still be drawn: the pack is shown and
## staying, with its world and the render's viewport.
func _map_live() -> bool:
	return _map_asked != null and is_inside_tree() and not is_queued_for_deletion() \
		and world != null and has_node("MapView")


## Lets go of a waiting render without drawing it or answering.
func _drop_map() -> void:
	for handler in [[RenderingServer.frame_pre_draw, _hide_for_map], [RenderingServer.frame_post_draw, _take_map]]:
		if handler[0].is_connected(handler[1]):
			handler[0].disconnect(handler[1])
	_map_asked = null
	_map_saved = {}


## Just before the frame is drawn: records what the render changes and sets
## the world up for the map.
func _hide_for_map() -> void:
	if not _map_live():
		# The pack is going: nothing to draw, answer or put back. Its view
		# goes after the frame, never in the middle of drawing it.
		var view := get_node_or_null("MapView")
		if view != null and not view.is_queued_for_deletion():
			view.queue_free()
		_drop_map()
		return
	var shown := {}
	var to_hide: Array = nodes.values() + clouds + _streaks
	for extra in [player_marker(), reticle, rain_node]:
		if extra != null and is_instance_valid(extra):
			to_hide.append(extra)
	for id in _umbrellas:
		if is_instance_valid(_umbrellas[id]):
			shown[_umbrellas[id]] = _umbrellas[id].visible
	for n in to_hide:
		shown[n] = n.visible
	var roofs := []
	for id in shells:
		var shell: Dictionary = shells[id]
		var fading: bool = shell.has("tween") and shell["tween"].is_valid()
		if not (open_ids.has(id) or fading):
			continue
		var parts := {}
		for p in shell["roof"].find_children("*", "GeometryInstance3D", true, false):
			parts[p] = p.transparency
		var sides := []
		for side in shell["sides"].values():
			sides.append([side["full"], side["full"].visible, side["low"], side["low"].visible])
		roofs.append({"roof": shell["roof"], "shown": shell["roof"].visible, "parts": parts, "sides": sides})
	var fades := {}
	for lamp in lamps:
		fades[lamp] = lamp.distance_fade_enabled
	_map_saved = {
		"shown": shown, "roofs": roofs, "lamp_fades": fades,
		"minutes": minutes, "rain": rain, "sky_rain": _sky_rain,
		"sun": [sun.transform, sun.light_color, sun.light_energy, sun.shadow_enabled,
			sun.directional_shadow_mode, sun.directional_shadow_max_distance],
		"fog": env.fog_enabled, "exposure": env.tonemap_exposure,
	}
	# The light first: the rain it would be dimmed by goes, then the time.
	set_rain(0.0)
	set_time_of_day(map_minutes())
	for n in to_hide:
		n.visible = false
	for r in roofs:
		r["roof"].visible = true
		for p in r["parts"]:
			p.transparency = 0.0
		for s in r["sides"]:
			s[0].visible = true
			s[2].visible = false
	# The camera is far above: every lamp lights the picture, the haze that
	# sets the far city back would veil it all, and the sun's shadows reach
	# the ground in one cascade over the whole district.
	for lamp in lamps:
		lamp.distance_fade_enabled = false
	env.fog_enabled = false
	# The style may draw its map brighter than its world (neon's lit night).
	env.tonemap_exposure *= map_exposure()
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = MAP_EYE_M + MAP_SHADOW_BELOW_M
	_push_sun()


## The sun's turn reaches the renderer with the scene's other transforms,
## after _process; drawn now, it is handed over at once.
func _push_sun() -> void:
	RenderingServer.instance_set_transform(sun.get_instance(), sun.global_transform)


## Just after the frame is drawn: copies the picture, puts the world back as
## it was, and answers.
func _take_map() -> void:
	var view: SubViewport = get_node_or_null("MapView")
	if not _map_live() or _map_saved.is_empty():
		_drop_map()
		return
	var size_px: Vector2i = _map_asked
	# Without a display nothing is drawn (the renderer holds no picture to
	# copy), and a renderer may give back an empty image: the answer is
	# then a plain stand-in of the size, which the host does not keep, so
	# the next opening asks again.
	var image: Image = null if DisplayServer.get_name() == "headless" else view.get_texture().get_image()
	var texture: Texture2D
	if image == null or image.is_empty():
		image = Image.create(size_px.x, size_px.y, false, Image.FORMAT_RGBA8)
		image.fill(Color.html(str(style.get("map", {}).get("letterbox", MAP_LETTERBOX))))
		texture = StylePack.stand_in(ImageTexture.create_from_image(image))
	else:
		texture = ImageTexture.create_from_image(image)
	_restore_after_map()
	view.free()
	_drop_map()
	map_ready.emit(texture)


## Puts back everything _hide_for_map changed, as it was saved.
func _restore_after_map() -> void:
	var saved := _map_saved
	set_rain(saved["rain"])
	_sky_rain = saved["sky_rain"]
	set_time_of_day(saved["minutes"])
	var s: Array = saved["sun"]
	sun.transform = s[0]
	sun.light_color = s[1]
	sun.light_energy = s[2]
	sun.shadow_enabled = s[3]
	sun.directional_shadow_mode = s[4]
	sun.directional_shadow_max_distance = s[5]
	_push_sun()
	env.fog_enabled = saved["fog"]
	env.tonemap_exposure = saved["exposure"]
	for lamp in saved["lamp_fades"]:
		if is_instance_valid(lamp):
			lamp.distance_fade_enabled = saved["lamp_fades"][lamp]
	for r in saved["roofs"]:
		r["roof"].visible = r["shown"]
		for p in r["parts"]:
			p.transparency = r["parts"][p]
		for side in r["sides"]:
			side[0].visible = side[1]
			side[2].visible = side[3]
	for n in saved["shown"]:
		if is_instance_valid(n):
			n.visible = saved["shown"][n]


func teardown() -> void:
	_drop_map()
	super.teardown()
	_screen_faces.clear()
	_screen_idle = null
	_screen_glow = null
	_screen_live = null
	_soft_chunks.clear()
	_surface_font = null
	_mixers.clear()
	_live.clear()
	_uninked.clear()
	_owed.clear()
	rain_node = null
	_sky_rain = 0.0
	_streaks.clear()
	_planting.clear()
	_planted.clear()
	_umbrellas.clear()
	_indoor_rects.clear()
	_umbrellas_open = false
	_set_renderer_shadows(int(ProjectSettings.get_setting(ATLAS_SETTING, 4096)), int(ProjectSettings.get_setting(FILTER_SETTING, 2)))
	_plant_shadow_at = Vector3(INF, 0, INF)
	for m in _wet:
		m.roughness = _wet[m][0]
		m.albedo_color = _wet[m][1]
	_wet.clear()
	lamps.clear()
	room_rects.clear()
	shells.clear()
	footprints.clear()
	_facility_of.clear()
	_wall_of.clear()
	clouds.clear()
	boats.clear()
	camera = null
	rig = null
	sun = null
	world = null


# ---- Scenery and buildings ----

func make_scenery(item: Dictionary) -> Node:
	var node: Node3D
	var pts := CityGeometry.scenery_points(item)
	match str(item.get("kind", "")):
		"water":
			node = town.water(CityGeometry.rect_m(item["rect"]))
		"bridge":
			node = town.bridge(pts[0], pts[1], {"width": float(item.get("width", 400)) / 100.0,
				"height": float(style.get("bridge_deck", 0.0)), "deck": _room_under((pts[0] + pts[1]) / 2.0)})
		"street":
			node = town.street(pts, float(item.get("width", 400)) / 100.0)
		"fence":
			node = _fence(pts)
		_:
			return null
	node.name = "Scenery_" + str(item.get("kind", ""))
	return node


## The rectangle (metres) of the room whose floor holds `p`, or an empty
## one.
func _room_under(p: Vector2) -> Rect2:
	var ids := room_rects.keys()
	ids.sort()
	for id in ids:
		var r := CityGeometry.rect_m(room_rects[id]["rect"])
		if r.has_point(p):
			return r
	return Rect2()


## A railing along `pts` from the style's `railing` (two metres a module,
## its post at the -x end) and `railing-post` props, batched. A fence runs
## along the edge of the walkable ground, so it stands just off it, on the
## side no room covers: its pieces' walking-band slice then keeps clear of
## the floor's cells (spec §1).
func _fence(pts: Array) -> Node3D:
	var node := Node3D.new()
	var f := CityGeometry.fence(pts, 2.0)
	var rail := str(resolve("props", "railing").get("scene", ""))
	var post := str(resolve("props", "railing-post").get("scene", ""))
	var depth := 0.0
	for piece in [rail, post]:
		var box: Rect2 = town.band_box(piece)
		depth = maxf(depth, maxf(box.end.y, -box.position.y))
	var rails := []
	var outs := []
	for m in f["modules"]:
		var out := _off_the_floor(m["centre"], m["dir"]) * (depth + FENCE_CLEAR)
		outs.append(out)
		var at: Vector2 = m["centre"] + out
		var basis := Basis(Vector3.UP, atan2(-m["dir"].y, m["dir"].x)).scaled(Vector3(m["length"] / 2.0, 1, 1))
		rails.append(Transform3D(basis, Vector3(at.x, deck_at(at), at.y)))
	# The end posts stand just inside the run's ends too, where its line
	# meets the floor it edges.
	var posts := []
	for k in f["posts"].size():
		var m: Dictionary = f["modules"][0 if k == 0 else -1]
		var inward: Vector2 = m["dir"] * (depth + FENCE_CLEAR) * (1.0 if k == 0 else -1.0)
		var p: Vector2 = f["posts"][k] + (outs[0] if k == 0 else outs[-1]) + inward
		posts.append(Transform3D(Basis(), Vector3(p.x, deck_at(p), p.y)))
	if not rails.is_empty():
		node.add_child(town.tiles(rail, rails, "Railing", true))
	if not posts.is_empty():
		node.add_child(town.tiles(post, posts, "Posts", true))
	return node


## How far outside the walkable ground a fence's inner face stands.
const FENCE_CLEAR := 0.01


## The unit way across a fence run through `p` along `dir` toward the side
## no room's floor covers; zero when rooms (or none) lie either side.
func _off_the_floor(p: Vector2, dir: Vector2) -> Vector2:
	var across := Vector2(-dir.y, dir.x)
	var left := not _room_under(p + across * 0.3).has_area()
	var right := not _room_under(p - across * 0.3).has_area()
	if left == right:
		return Vector2.ZERO
	return across if left else -across


## The district's heart (the square's centre), which blocks face.
func _heart() -> Vector2:
	var plaza = room_rects.get("room:plaza")
	return CityGeometry.rect_m(plaza["rect"]).get_center() if plaza != null else Vector2.ZERO


# ---- Transit: rails and trams ----

## How near (metres) an overhead camera must come before the trams' roofs
## fade away, so their riders show from above.
const ROOF_CUT_M := 45.0
## How steeply (degrees; negative looks down) a view must look to count as
## overhead: the diagonal and top-down do, the street view does not.
const ROOF_CUT_PITCH := -20.0
## How long a tram's roof takes to fade out or back in, in seconds.
const ROOF_FADE_S := 0.25
## How opaque a tram's glass is: enough to read as glass, clear enough
## that its riders show.
const TRAM_GLASS_ALPHA := 0.3
## The lights inside a tram at night: how far each reaches (metres) and
## how bright it is, as a share of the style's lamp energy.
const TRAM_GLOW_RANGE_M := 4.5
const TRAM_GLOW_SHARE := 0.35

## id -> a tram's parts and how they are shown: its body (the kit piece),
## floor height, door leaves [{node, side, leaf, rest, dir}], roof and
## ceiling-light parts, every other part, the lights inside it, the box its
## body fills (local), and the doors' and roof's state.
var _trams := {}


## A track's rails (and catenary, where the town draws one), laid the way
## its trams run, so the westbound track's poles stand south of it and the
## eastbound's north: both outside the pair.
func make_track(line: Dictionary, index: int) -> Node:
	var points := CityGeometry.track_points(line, index).map(func(p): return p / 100.0)
	if points.size() < 2:
		return null
	if index == 1:
		points.reverse()
	return town.tram_line(points)


## The kit's tram behind the node's origin (its front), running along the
## node's x, fitted to the line's vehicle length at the kit's own width,
## with its glass see-through, its doors, roof and lights found, and three
## lights inside it for the night.
func make_vehicle(view: Dictionary) -> Node:
	var id: String = view["id"]
	var root := Node3D.new()
	var body: Node3D = town.tram()
	var length := float(CityGeometry.line_of(manifest, str(view.get("line", ""))).get("vehicle", {}).get("length", 2050)) / 100.0
	var box := _bounds(body, Transform3D.IDENTITY)
	if box.size.x > 0.0:
		body.scale.x *= length / box.size.x
	body.position.x = -length / 2.0
	root.add_child(body)
	# The kit piece may stand a little up in its node (the voxel tram does).
	var lift := 0.0
	for c in body.get_children():
		if c is Node3D:
			lift = c.position.y
			break
	var floor_m := float(tram_layout().get("floor_cm", 40)) / 100.0 + lift
	root.set_meta("floor_m", floor_m)
	var t := {"body": body, "floor": floor_m, "leaves": [], "roof": [], "parts": [], "glows": [],
		"door": -1.0, "door_to": 0.0, "side": 0, "roof_shown": 1.0, "opacity": -1.0}
	var slide := float(tram_layout().get("door_slide_cm", 60)) / 100.0
	for g in body.find_children("*", "GeometryInstance3D", true, false):
		var name_ := str(g.name)
		if name_ == "roof" or name_ == "lights":
			t["roof"].append(g)
		else:
			t["parts"].append(g)
		if name_.begins_with("door_"):
			var bits := name_.split("_")
			t["leaves"].append({"node": g, "side": bits[1], "leaf": bits[3], "rest": g.position,
				"dir": Vector3(slide if bits[3] == "fore" else -slide, 0, 0)})
		if g is MeshInstance3D and g.mesh != null:
			for s in g.mesh.get_surface_count():
				_see_through(g.mesh.surface_get_material(s))
	var inside := AABB()
	for g in t["parts"]:
		if not str(g.name).begins_with("door_") and g is MeshInstance3D and g.mesh != null:
			var at: AABB = (body.transform * _local_xform(g, body)) * g.mesh.get_aabb()
			inside = at if inside.size == Vector3.ZERO else inside.merge(at)
	t["inside"] = inside
	for k in 3:
		var glow := OmniLight3D.new()
		glow.name = "Glow_%d" % k
		glow.light_color = Color(1.0, 0.86, 0.64)
		glow.omni_range = TRAM_GLOW_RANGE_M
		glow.shadow_enabled = false
		glow.position = Vector3(-length * (1.0 + 2.0 * k) / 6.0, floor_m + 1.9, 0)
		root.add_child(glow)
		t["glows"].append(glow)
	_trams[id] = t
	_light_tram(t)
	return root


## `node`'s transform in `top`'s frame.
static func _local_xform(node: Node3D, top: Node3D) -> Transform3D:
	var x := node.transform
	var p := node.get_parent()
	while p != null and p != top:
		if p is Node3D:
			x = p.transform * x
		p = p.get_parent()
	return x


## Makes a tram's glass see-through (once: the kit's material is shared).
## At night it shows the lit inside rather than glowing itself, as a
## building's windows do.
func _see_through(m: Material) -> void:
	if not (m is BaseMaterial3D) or not str(m.resource_name).begins_with("glass"):
		return
	# Each new tram's kit piece hands its glass to the night's list again.
	if town != null:
		town.glass_materials.erase(m)
	m.emission_energy_multiplier = 0.0
	if m.has_meta("tram_glass"):
		return
	m.set_meta("tram_glass", true)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = TRAM_GLASS_ALPHA


## The box round every mesh under `node`, in the frame `node` sits in
## transformed by `xform`.
static func _bounds(node: Node, xform: Transform3D) -> AABB:
	var here: Transform3D = xform * node.transform if node is Node3D else xform
	var box := AABB()
	var found := false
	if node is MeshInstance3D and node.mesh != null:
		box = here * node.mesh.get_aabb()
		found = true
	for child in node.get_children():
		var inner := _bounds(child, here)
		if inner.size != Vector3.ZERO:
			box = inner if not found else box.merge(inner)
			found = true
	return box


func vehicle_parent() -> Node:
	return world if world != null else self


func place_vehicle(id: String, pos_cm: Vector2, heading: float) -> void:
	super(id, pos_cm, heading)
	var node: Node3D = vehicle_nodes.get(id)
	if node == null:
		return
	node.position = Vector3(pos_cm.x / 100.0, deck_at(pos_cm / 100.0), pos_cm.y / 100.0)
	# Heading is clockwise from north; the node runs along its own x.
	node.rotation.y = deg_to_rad(90.0 - heading)
	_fade_tram(id)


func seat_rider(id: String, local_cm: Vector2) -> void:
	var node: Node3D = nodes.get(id)
	if node == null:
		return
	# The vehicle's left is its -z; a person faces its own -z, so a quarter
	# turn faces them along the vehicle's x, the way it runs. They stand on
	# its floor.
	var floor_m := float(_trams.get(riders.get(id, ""), {}).get("floor", tram_layout().get("floor_cm", 40) / 100.0))
	node.position = Vector3(local_cm.x / 100.0, floor_m, -local_cm.y / 100.0)
	node.rotation = Vector3(0, -PI / 2.0, 0)
	# Nobody holds an umbrella up inside.
	var umbrella = _umbrellas.get(id)
	if umbrella is Node3D and is_instance_valid(umbrella):
		umbrella.visible = false
	_hide_status(id)
	_ride_cheaply(id, true)
	_pose_once(id)
	var t: Dictionary = _trams.get(riders.get(id, ""), {})
	if not t.is_empty():
		_fade_rider(id, maxf(0.0, float(t["opacity"])))
		node.visible = bool(t.get("riders_shown", true))
		_rider_lod(id, bool(t.get("riders_far", false)))


func step_off(id: String) -> void:
	var was_aboard := riders.has(id)
	super(id)
	if nodes.has(id):
		if was_aboard:
			_ride_cheaply(id, false)
			_rider_lod(id, null)
			nodes[id].visible = true
			if _mixers.has(id):
				_live[id] = _mixers[id]
				_owed[id] = 0.0
		set_presence(id, headlines.get(id, "Unknown"))


## Poses rider `id` in its clip now, the clip's blend run out, and takes it
## off the per-frame list: aboard it holds that pose (see _advance_people).
func _pose_once(id: String) -> void:
	var player = _mixers.get(id)
	if player == null:
		return
	_live.erase(id)
	player.advance(BLEND_S + float(_owed.get(id, 0.0)))
	_owed[id] = 0.0


## Draws rider `id` with no shadow aboard (`on`), or casting shadows as a
## walker again. A part the first-person view keeps as a shadow alone is
## left so.
func _ride_cheaply(id: String, on: bool) -> void:
	var model = nodes[id].get_node_or_null("Model") if nodes.has(id) else null
	if model == null:
		return
	for g in model.find_children("*", "GeometryInstance3D", true, false):
		if on and not g.has_meta("cast_before") and g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			g.set_meta("cast_before", g.cast_shadow)
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif not on and g.has_meta("cast_before"):
			if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				g.cast_shadow = g.get_meta("cast_before")
			g.remove_meta("cast_before")


## The parts of a rider a kit with no far body drops in a far tram: seen
## through the tram's glass from further off than RIDER_FAR_M they are a
## few pixels at most, and each is a draw.
const FAR_SHED := ["shoes", "backpack"]


## Hides (`shed`) or shows again the small parts FAR_SHED of rider model
## `model`, as they were before.
func _shed_small_parts(model: Node, shed: bool) -> void:
	for part in FAR_SHED:
		var g = model.find_child(part, true, false)
		if not (g is GeometryInstance3D):
			continue
		if shed and not g.has_meta("shown_near"):
			g.set_meta("shown_near", g.visible)
			g.visible = false
		elif not shed and g.has_meta("shown_near"):
			g.visible = bool(g.get_meta("shown_near"))
			g.remove_meta("shown_near")


## Materials without their ink outline pass, made once each: the material
## -> its copy with no next pass.
var _uninked := {}


## `mat` drawn without its next pass (the ink outline), shared by every
## rider wearing it.
func _without_ink(mat: Material) -> Material:
	if not _uninked.has(mat):
		var plain: Material = mat.duplicate()
		plain.next_pass = null
		_uninked[mat] = plain
	return _uninked[mat]


## Shows rider `id`, where its kit has a far body, by that body alone when
## its tram is further off than RIDER_FAR_M (`far` true) or by its near
## parts (`far` false), as animate_vehicles finds the tram: the parts not
## shown are hidden outright, so a moving tram carries nothing nobody
## sees. With `far` null (off the tram) it takes the walkers' rule again:
## its near parts up to FAR_M, its far body beyond.
func _rider_lod(id: String, far) -> void:
	var model = nodes[id].get_node_or_null("Model") if nodes.has(id) else null
	var far_body = model.find_child("far", true, false) if model != null else null
	if far_body == null:
		if model != null:
			_shed_small_parts(model, far == true)
		return
	var aboard: bool = far != null
	far_body.visibility_range_begin = 0.0 if aboard else FAR_M
	far_body.visible = far == true or not aboard
	# In a far tram, behind its glass, the far body's ink outline (a style
	# whose far body shares its inked parts' materials) is a line nobody
	# sees: drawn without it, the body costs half the draws.
	for k in far_body.mesh.get_surface_count():
		var mat: Material = far_body.get_surface_override_material(k)
		if far == true and mat != null and mat.next_pass != null:
			far_body.set_meta("inked_%d" % k, mat)
			far_body.set_surface_override_material(k, _without_ink(mat))
		elif far != true and far_body.has_meta("inked_%d" % k):
			far_body.set_surface_override_material(k, far_body.get_meta("inked_%d" % k))
			far_body.remove_meta("inked_%d" % k)
	for g in model.find_children("*", "GeometryInstance3D", true, false):
		if g == far_body:
			continue
		if aboard:
			if not g.has_meta("shown_near"):
				g.set_meta("shown_near", g.visible)
			g.visible = bool(g.get_meta("shown_near")) and far == false
		elif g.has_meta("shown_near"):
			g.visible = bool(g.get_meta("shown_near"))
			g.remove_meta("shown_near")


## A rider's status icon is drawn over everything, so it would show through
## the tram's roof: it is hidden while it rides.
func _hide_status(id: String) -> void:
	if not nodes.has(id):
		return
	for part in ["Icon", "Glyph"]:
		var n = nodes[id].get_node_or_null(part)
		if n != null:
			n.visible = false


func set_doors(id: String, open: bool) -> void:
	super(id, open)
	var t: Dictionary = _trams.get(id, {})
	if t.is_empty():
		return
	t["door_to"] = 1.0 if open else 0.0
	if open or float(t["door"]) < 0.0:
		t["side"] = door_side(id)
	# A tram drawn with its doors already open or shut shows them so at once.
	if float(t["door"]) < 0.0:
		t["door"] = t["door_to"]
		_place_leaves(t)


func door_leaves(id: String) -> Array:
	return _trams.get(id, {}).get("leaves", [])


func door_amount(id: String) -> float:
	return maxf(0.0, float(_trams.get(id, {}).get("door", 0.0)))


## How much of tram `id`'s roof is shown, 0 faded away to 1 whole.
func roof_shown(id: String) -> float:
	return float(_trams.get(id, {}).get("roof_shown", 1.0))


## Whether a tram's roof is cut away: in an overhead view (pitched down past
## ROOF_CUT_PITCH) within ROOF_CUT_M, or with the camera inside the tram,
## unless roofs are kept on.
static func roof_cut(pitch: float, distance: float, camera_inside: bool, keep: bool) -> bool:
	if keep:
		return false
	return camera_inside or (pitch <= ROOF_CUT_PITCH and distance <= ROOF_CUT_M)


func animate_vehicles(delta: float) -> void:
	var cam = null
	if rig != null and fpv == null:
		cam = rig.camera.global_position if rig.camera.is_inside_tree() else rig.transform * rig.camera.position
	# Where the picture is seen from, for hiding riders nobody could see.
	var eye = cam
	if fpv != null:
		eye = fpv.global_position if fpv.is_inside_tree() else fpv.position
	for id in _trams:
		var t: Dictionary = _trams[id]
		var door := float(t["door"])
		if door >= 0.0 and door != float(t["door_to"]):
			t["door"] = move_toward(door, float(t["door_to"]), delta / DOOR_S if delta > 0.0 else 0.0)
			_place_leaves(t)
		var inside := false
		var node: Node3D = vehicle_nodes.get(id)
		if cam != null and node != null:
			var local: Vector3 = (node.global_transform if node.is_inside_tree() else node.transform).affine_inverse() * cam
			inside = (t["inside"] as AABB).grow(0.1).has_point(local)
		var cut := rig != null and roof_cut(rig.pitch, rig.distance, inside, keep_roofs or fpv != null)
		var want := 0.0 if cut else 1.0
		var shown := float(t["roof_shown"])
		if shown != want:
			t["roof_shown"] = move_toward(shown, want, delta / ROOF_FADE_S if delta > 0.0 else 0.0)
			t["opacity"] = -1.0
		_fade_tram(id)
		if eye != null and node != null:
			var seen_from := _seen_from(node, t["inside"], eye)
			_show_riders(id, t, riders_seen(float(t["roof_shown"]), seen_from.x, seen_from.y))
			var far := seen_from.x > RIDER_FAR_M
			if t.get("riders_far") != far:
				t["riders_far"] = far
				for rider in riders:
					if riders[rider] == id:
						_rider_lod(rider, far)


## Whether a tram's riders can be seen, `roof` being how much of its roof
## is shown (0 to 1), from `distance_m` off, `elevation_deg` above the
## horizontal: with the roof faded at all; within RIDER_SEEN_M (inside it,
## or near enough to see in anyhow); or through its side windows, from
## below RIDER_ROOF_DEG and within RIDER_TINY_M.
static func riders_seen(roof: float, distance_m: float, elevation_deg: float) -> bool:
	if roof < 1.0 or distance_m <= RIDER_SEEN_M:
		return true
	return elevation_deg < RIDER_ROOF_DEG and distance_m <= RIDER_TINY_M


## Where `eye` (world, metres) sees the box `inside` (the tram's, in
## `node`'s frame) from: x its distance from the box (0 inside it), y its
## elevation above the horizontal from the box's middle, in degrees.
static func _seen_from(node: Node3D, inside: AABB, eye: Vector3) -> Vector2:
	var local: Vector3 = (node.global_transform if node.is_inside_tree() else node.transform).affine_inverse() * eye
	var to_eye := local - inside.get_center()
	var level := Vector2(to_eye.x, to_eye.z).length()
	return Vector2(local.distance_to(local.clamp(inside.position, inside.end)), rad_to_deg(atan2(to_eye.y, level)))


## Shows or hides the riders of tram `id` (`t`, its parts) as `seen` says,
## when that changes.
func _show_riders(id: String, t: Dictionary, seen: bool) -> void:
	if bool(t.get("riders_shown", true)) == seen:
		return
	t["riders_shown"] = seen
	for rider in riders:
		if riders[rider] == id and nodes.has(rider):
			nodes[rider].visible = seen


## Stands tram `t`'s door leaves as far open as its doors are, on the side
## its platform is (both, at no known stop).
func _place_leaves(t: Dictionary) -> void:
	var amount := maxf(0.0, float(t["door"]))
	var side := int(t["side"])
	for leaf in t["leaves"]:
		var opens: bool = side == 0 or (side > 0) == (leaf["side"] == "left")
		leaf["node"].position = leaf["rest"] + (leaf["dir"] * amount if opens else Vector3.ZERO)


## Shows tram `id` as faded as its place by the portals asks, and its roof
## as far as it is shown; its riders fade with it.
func _fade_tram(id: String) -> void:
	var t: Dictionary = _trams.get(id, {})
	var node: Node3D = vehicle_nodes.get(id)
	if t.is_empty() or node == null:
		return
	var opacity := vehicle_opacity(id)
	var key := opacity * 2.0 + float(t["roof_shown"])
	if float(t["opacity"]) == opacity and float(t.get("key", -1.0)) == key:
		return
	t["opacity"] = opacity
	t["key"] = key
	node.visible = opacity > 0.001
	for g in t["parts"]:
		g.transparency = 1.0 - opacity
	var roof := opacity * float(t["roof_shown"])
	for g in t["roof"]:
		g.transparency = 1.0 - roof
		g.visible = roof > 0.001
	for rider in riders:
		if riders[rider] == id:
			_fade_rider(rider, opacity)


func _fade_rider(id: String, opacity: float) -> void:
	if not nodes.has(id):
		return
	var own := 0.55 if headlines.get(id, "") == "Offline" else 0.0
	var model = nodes[id].get_node_or_null("Model")
	if model == null:
		return
	for g in model.find_children("*", "GeometryInstance3D", true, false):
		g.transparency = maxf(own, 1.0 - opacity)


## Lights tram `t`'s inside at night, as the lamps are lit.
func _light_tram(t: Dictionary) -> void:
	var lit := _lamps_lit()
	var energy := float(style.get("lamp_energy", 2.4)) * TRAM_GLOW_SHARE
	for glow in t["glows"]:
		glow.visible = lit
		glow.light_energy = energy if lit else 0.0


func _lamps_lit() -> bool:
	if minutes < 0:
		return false
	var dn: Dictionary = style.get("day_night", {})
	return minutes >= int(dn.get("lamps_on_from", 1110)) or minutes < int(dn.get("lamps_off_at", 390))


func despawn_vehicle(id: String) -> void:
	super(id)
	_trams.erase(id)


## Open: the roof fades away and the façades facing the camera drop to low
## walls. Closed: the whole building stands.
func apply_open(id: String, open: bool) -> void:
	var shell = shells.get(id)
	if shell == null:
		return
	var roof_on := not open or keep_roofs
	var was_shown: bool = shell.get("roof_shown", true)
	shell["roof_shown"] = roof_on
	if was_shown != roof_on:
		_fade_roof(shell, not roof_on)
	var cam = camera_ground_pos()
	for side in shell["sides"].values():
		var near := false
		if open and cam != null:
			var to_cam: Vector2 = cam / 100.0 - shell["centre"]
			near = side["normal"].dot(to_cam) > 0.0
		side["full"].visible = not near
		side["low"].visible = near


## Fades a roof out (then hides it) or back in over a quarter second.
func _fade_roof(shell: Dictionary, out: bool) -> void:
	var roof: Node3D = shell["roof"]
	if shell.has("tween") and shell["tween"].is_valid():
		shell["tween"].kill()
	var parts := roof.find_children("*", "GeometryInstance3D", true, false)
	if not is_inside_tree():
		roof.visible = not out
		for p in parts:
			p.transparency = 0.0
		return
	roof.visible = true
	var tw := create_tween().set_parallel(true)
	for p in parts:
		tw.tween_property(p, "transparency", 1.0 if out else 0.0, 0.25)
	if out:
		tw.chain().tween_callback(func(): roof.visible = false)
	shell["tween"] = tw


func _refresh_open() -> void:
	for id in open_ids:
		apply_open(id, true)


func shell_state(id: String) -> Dictionary:
	var shell = shells.get(id)
	if shell == null:
		return {}
	return {"roof": shell.get("roof_shown", true)}
