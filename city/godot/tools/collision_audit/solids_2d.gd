## The collision audit's reading of a 2D (isometric) pack: every visible
## kit sprite, as the footprint at walking height of the model it was
## rendered from (city/tools/styles/pixel/models.py: the parts between
## 0.25 m and 1.9 m above the ground), placed at the sprite's ground point;
## a sprite's screen rectangle is never used. Each is named by whose it is,
## as its nearest tagged ancestor says. A kit sprite this table does not
## know is listed as unmeasured, so a new sprite cannot pass unseen.
##
## When a sprite is re-rendered from a changed model, its entry here
## changes with it.
##
## Soft ground (a meadow's grass) is walked through, as in 3D: a clump
## drawn wholly inside its meadow's lot is no solid, one reaching past it
## counts (Solids3D.walked_through).
extends RefCounted

const Solid = preload("res://tools/collision_audit/solid.gd")
const Solids3D = preload("res://tools/collision_audit/solids_3d.gd")

## Sprite (under the pack's assets) -> its shapes, in metres from its
## ground point before any turn: ["disc", r, x, z] or ["rect", x0, x1,
## z0, z1]. An empty list is a sprite with nothing in the band (a roof, a
## tower's upper storeys).
const FOOT := {
	"scenery/lamp.png": [["disc", 0.125, 0.0, 0.0]],
	"scenery/bollard.png": [["disc", 0.105, 0.0, 0.0]],
	"scenery/cafe_table.png": [["disc", 0.5, 0.0, 0.0]],
	"scenery/cafe_set.png": [["disc", 0.42, 0.0, 0.0], ["rect", -0.9, 0.9, -0.2, 0.2]],
	# The pole; the canopy is above the band.
	"scenery/umbrella.png": [["disc", 0.035, 0.0, 0.0]],
	"scenery/railing_x.png": [["rect", -0.5, 0.5, -0.04, 0.04]],
	"scenery/railing_z.png": [["rect", -0.04, 0.04, -0.5, 0.5]],
	"scenery/railing_post.png": [["rect", -0.055, 0.055, -0.055, 0.055]],
	# Its rim, on the kind's drawn rectangle (models.py PLANTER).
	"scenery/planter.png": [["rect", -0.655, 0.65, -0.655, 0.65]],
	"scenery/planter_pot.png": [["disc", 0.44, 0.0, 0.0]],
	# Two metres of bench, as deep as the kind's drawn rectangle.
	"scenery/workbench.png": [["rect", -1.0, 1.0, -0.655, 0.645]],
	# The clipped bush mass, a 32-sided drum 1.06 m round (its flats a
	# hair inside), its lobes inside it.
	"scenery/shrub.png": [["disc", 1.06, 0.0, 0.0]],
	# Trees count at the trunk; the crowns are leaves.
	"scenery/tree_round_a.png": [["disc", 0.2, 0.0, 0.0]],
	"scenery/tree_round_b.png": [["disc", 0.2, 0.0, 0.0]],
	# A palm's trunk stands upright to 2.4 m before it leans: its
	# segments in the band, the widest at its foot.
	"scenery/palm_tall.png": [["disc", 0.2, 0.0, 0.0]],
	"scenery/palm_short.png": [["disc", 0.2, 0.0, 0.0]],
	# The banyan's trunk and its buttress roots.
	"scenery/tree_square.png": [["disc", 1.1, 0.0, 0.0]],
	# Its surface roots, arching at knee height out to every quarter
	# metre of its drawn square's edge (models.py ROOTS), where they dive.
	"scenery/tree_roots.png": [["rect", -2.655, 2.645, -2.655, 2.645]],
	# A block's garden wall, a metre about its middle, and its closed gate
	# (two metres: posts either side of a shut leaf, in the wall's line,
	# each post's cap 2 cm wider all round at 1.35–1.41 m).
	"scenery/garden_wall_x.png": [["rect", -0.5, 0.5, -0.1, 0.1]],
	"scenery/garden_wall_z.png": [["rect", -0.1, 0.1, -0.5, 0.5]],
	"scenery/garden_gate_x.png": [["rect", -1.0, -0.6, -0.1, 0.1], ["rect", 0.6, 1.0, -0.1, 0.1],
		["rect", -0.92, -0.58, -0.12, 0.12], ["rect", 0.58, 0.92, -0.12, 0.12], ["rect", -0.6, 0.6, -0.03, 0.03]],
	"scenery/garden_gate_z.png": [["rect", -0.1, 0.1, -1.0, -0.6], ["rect", -0.1, 0.1, 0.6, 1.0],
		["rect", -0.12, 0.12, -0.92, -0.58], ["rect", -0.12, 0.12, 0.58, 0.92], ["rect", -0.03, 0.03, -0.6, 0.6]],
	# The things to use (things.py), each as its model declares it in the
	# band (its `band_shapes`, turned to its facing), which render.py holds
	# the model to and test_things_to_use.gd holds this table to: a
	# fixture's footing on its kind's drawn rectangle at its facing, the
	# fountain's basin on its disc (each of its two halves read as the
	# whole, about its own origin), and a meadow clump's blades, at rest,
	# pushed and swinging back, within their reach of its root.
	"scenery/fountain_back.png": [["disc", 1.5, 1.5, 1.5]],
	"scenery/fountain_front.png": [["disc", 1.5, 0.0, 0.0]],
	"scenery/kiosk_0.png": [["rect", -0.405, 0.4, -0.25, 0.25]],
	"scenery/kiosk_180.png": [["rect", -0.405, 0.4, -0.25, 0.25]],
	"scenery/kiosk_270.png": [["rect", -0.25, 0.25, -0.405, 0.4]],
	"scenery/kiosk_90.png": [["rect", -0.25, 0.25, -0.405, 0.4]],
	"scenery/low_wall_0.png": [["rect", -1.5, 1.5, -0.155, 0.15]],
	"scenery/low_wall_180.png": [["rect", -1.5, 1.5, -0.155, 0.15]],
	"scenery/low_wall_270.png": [["rect", -0.155, 0.15, -1.5, 1.5]],
	"scenery/low_wall_90.png": [["rect", -0.155, 0.15, -1.5, 1.5]],
	"scenery/meadow/flowers_0.png": [["disc", 0.1695, 0.0, 0.0]],
	"scenery/meadow/flowers_1.png": [["disc", 0.2432, 0.0, 0.0]],
	"scenery/meadow/flowers_2.png": [["disc", 0.2084, 0.0, 0.0]],
	"scenery/meadow/grass_a_0.png": [["disc", 0.1767, 0.0, 0.0]],
	"scenery/meadow/grass_a_1.png": [["disc", 0.2474, 0.0, 0.0]],
	"scenery/meadow/grass_a_2.png": [["disc", 0.2118, 0.0, 0.0]],
	"scenery/meadow/grass_b_0.png": [["disc", 0.1834, 0.0, 0.0]],
	"scenery/meadow/grass_b_1.png": [["disc", 0.2823, 0.0, 0.0]],
	"scenery/meadow/grass_b_2.png": [["disc", 0.212, 0.0, 0.0]],
	"scenery/noticeboard_0.png": [["rect", -0.655, 0.645, -0.155, 0.145]],
	"scenery/noticeboard_180.png": [["rect", -0.655, 0.645, -0.155, 0.145]],
	"scenery/noticeboard_270.png": [["rect", -0.155, 0.145, -0.655, 0.645]],
	"scenery/noticeboard_90.png": [["rect", -0.155, 0.145, -0.655, 0.645]],
	"scenery/plaque_0.png": [["rect", -0.405, 0.395, -0.155, 0.15]],
	"scenery/plaque_180.png": [["rect", -0.405, 0.395, -0.155, 0.15]],
	"scenery/plaque_270.png": [["rect", -0.155, 0.15, -0.405, 0.395]],
	"scenery/plaque_90.png": [["rect", -0.155, 0.15, -0.405, 0.395]],
	"scenery/steps_0.png": [["rect", -1.5, 1.5, 0.0, 1.0]],
	"scenery/steps_180.png": [["rect", -1.5, 1.5, -1.0, 0.0]],
	"scenery/steps_270.png": [["rect", 0.0, 1.0, -1.5, 1.5]],
	"scenery/steps_90.png": [["rect", -1.0, 0.0, -1.5, 1.5]],
	"buildings/blocks/tower_mid.png": [],
	"buildings/blocks/tower_top.png": [],
	"buildings/hall/roof_mid.png": [],
	"buildings/hall/roof_n.png": [],
	"buildings/hall/roof_s.png": [],
	"buildings/library/dome.png": [],
	"buildings/library/roof.png": [],
}

## Props rendered at their facings (models.py), before the turn.
const TURNED_FOOT := {
	# The stop's posts along its glass back (and the kick rail under
	# it), its bench, its timetable board and its end screen with its
	# post; the canopy is above.
	"tram_shelter": [["rect", -2.15, -2.05, -0.75, -0.55], ["rect", -0.05, 0.05, -0.75, -0.55],
		["rect", 2.05, 2.15, -0.75, -0.55], ["rect", -2.15, 2.15, -0.7, -0.6], ["rect", -0.65, 1.75, -0.55, -0.15],
		["rect", -1.9, -1.2, -0.55, -0.5], ["rect", 2.05, 2.1, -0.55, 0.3], ["rect", 2.0, 2.15, 0.3, 0.4]],
	# The kerb (0.3 m) on the kind's drawn rectangle; the flowers inside.
	"flowerbed": [["rect", -1.655, 1.645, -0.655, 0.645]],
	# A perch's seat stone (things.py perch_seat): its timber seat over the
	# stone block, from 14 cm in front of the sitter to 40 cm behind.
	"perch_seat": [["rect", -0.14, 0.14, -0.14, 0.4]],
}

## Seat furniture (models.py seat_model), before the turn to its facing;
## the sitter sits on the origin facing north. Its own chair or seat stands
## in the square 25 cm about the origin.
const SEAT_FOOT := {
	# The slats, the back boards and the end frames.
	"bench": [["rect", -0.8, 0.8, -0.25, 0.185], ["rect", -0.8, 0.8, 0.27, 0.35], ["rect", -0.8, -0.72, -0.25, 0.35],
		["rect", 0.72, 0.8, -0.25, 0.35]],
	# The chair, and the desk's top in front.
	"desk": [["rect", -0.22, 0.22, -0.2, 0.24], ["rect", -0.655, 0.65, -0.95, -0.25]],
	# The chair, and the desk's top in front: its monitor, stand and
	# keyboard stand on the top, inside it.
	"workstation": [["rect", -0.22, 0.22, -0.2, 0.24], ["rect", -0.655, 0.65, -0.95, -0.25]],
	# The seat, the legs under it and the back.
	"cafe-table": [["rect", -0.22, 0.22, -0.21, 0.26]],
	# The cushion, the arms and the back.
	"reading-chair": [["rect", -0.25, 0.25, -0.24, 0.25], ["rect", -0.45, -0.25, -0.4, 0.5], ["rect", 0.25, 0.45, -0.4, 0.5],
		["rect", -0.25, 0.25, 0.25, 0.5]],
}

## The façades' wall thickness (models.py WALL), the building kinds' `wall`.
const WALL := 0.25

## The drawn tram's half width (models.py TRAM_HW): the tram kind's.
const TRAM_HALF_WIDTH := 1.25

## The tags that name whose a node is, nearest first.
const TAGS := ["placement_id", "building", "scenery", "vehicle", "occupant"]

var _seat := RegEx.create_from_string("^scenery/seats/(.+)_(\\d+)\\.png$")
var _shelf := RegEx.create_from_string("^scenery/bookshelf_(\\d+)\\.png$")
var _turned_prop := RegEx.create_from_string("^scenery/(tram_shelter|flowerbed|perch_seat)_(\\d+)\\.png$")
var _slice := RegEx.create_from_string("^buildings/(hall|library)/(s|e)_(\\w+)\\.png$")
var _corner := RegEx.create_from_string("^buildings/(hall|library)/corner(_low)?\\.png$")
var _block := RegEx.create_from_string("^buildings/blocks/\\w+\\.png$")
var _bridge := RegEx.create_from_string("^scenery/bridge/(\\w+)_(back|front)\\.png$")
## Placement or seat ID -> its kind.
var kinds := {}
## Soft ground's placement ID -> its lot, metres (CollisionAudit.soft_ground).
var soft := {}
## Kit sprites (by path) the table does not know, and how many were drawn.
var unmeasured := {}
var _kit := {}


## Every solid the pack's sprites stand for that `wanted(bounds)` (a world
## rectangle, grown by the clearance) says may matter.
func collect(pack, wanted: Callable) -> Array:
	var text := FileAccess.get_file_as_string(pack.pack_dir + "/assets/kit.json")
	_kit = JSON.parse_string(text).get("sprites", {}) if text != "" else {}
	var out := []
	for s in pack.find_children("*", "Sprite2D", true, false):
		if not s.is_visible_in_tree() or s.texture == null:
			continue
		var tagged := _tagged(s, pack)
		if tagged.is_empty():
			continue
		var path: String = s.texture.resource_path
		if path == "":
			# Baked ground and drawn stand-ins are no kit sprites.
			continue
		path = path.trim_prefix(pack.pack_dir + "/").trim_prefix("assets/").replace("_night.png", ".png")
		var shapes = _shapes(path)
		if shapes == null:
			unmeasured[path] = unmeasured.get(path, 0) + 1
			continue
		if shapes.is_empty():
			continue
		if s.flip_h:
			shapes = _mirrored(shapes)
		var solid := _solid(shapes, pack.ground_of(s), _owner(tagged, s, pack))
		if Solids3D.walked_through(soft, solid.owner, solid.bounds):
			continue
		if wanted.call(solid.bounds):
			out.append(solid)
	# A placement drawn as lines, not sprites (a catenary pole): its first
	# line is the mast, standing on the node's point, half its stroke round
	# (16 px a metre).
	for id in pack.placement_nodes:
		var node = pack.placement_nodes[id]
		if not node is Node2D or not node.find_children("*", "Sprite2D", true, false).is_empty():
			continue
		var lines: Array = node.find_children("*", "Line2D", true, false)
		if not lines.is_empty():
			var mast: Line2D = lines[0]
			var solid := _solid([["disc", mast.width / 2.0 / 16.0, 0.0, 0.0]], pack.ground_of(node), {"kind": kinds.get(id, "placement"), "placement_id": id})
			if wanted.call(solid.bounds):
				out.append(solid)
	return out


func _tagged(n: Node, pack: Node) -> Dictionary:
	while n != null and n != pack:
		for tag in TAGS:
			if n.has_meta(tag):
				return {} if tag in ["vehicle", "occupant"] else {"node": n, "tag": tag}
		n = n.get_parent()
	return {"tag": ""}


func _owner(tagged: Dictionary, s: Node, pack: Node) -> Dictionary:
	var path := str(pack.get_path_to(s))
	match tagged["tag"]:
		"placement_id":
			var id := str(tagged["node"].get_meta("placement_id"))
			return {"kind": kinds.get(id, "placement"), "placement_id": id}
		"building":
			return {"kind": "building", "building": str(tagged["node"].get_meta("building")), "mesh": path}
		"scenery":
			return {"kind": "scenery:" + str(tagged["node"].get_meta("scenery")), "mesh": path}
	return {"kind": "untagged", "mesh": path}


## A sprite's shapes about its ground point, or null for one the table
## does not know.
func _shapes(path: String):
	if FOOT.has(path):
		return FOOT[path]
	var m := _seat.search(path)
	if m != null and SEAT_FOOT.has(m.get_string(1)):
		return _turned(SEAT_FOOT[m.get_string(1)], float(m.get_string(2)))
	m = _shelf.search(path)
	if m != null:
		return _turned([["rect", -1.0, 1.0, -0.3, 0.3]], float(m.get_string(1)))
	m = _turned_prop.search(path)
	if m != null:
		return _turned(TURNED_FOOT[m.get_string(1)], float(m.get_string(2)))
	m = _slice.search(path)
	if m != null:
		return _facade(m.get_string(2), m.get_string(3))
	m = _corner.search(path)
	if m != null:
		# The WALL-square where two walls meet.
		return [["rect", -WALL / 2.0, WALL / 2.0, -WALL / 2.0, WALL / 2.0]]
	m = _block.search(path)
	if m != null and _kit.get(path, {}).has("band"):
		# A house, shop or tower's base: where it stands in the band about
		# its south-east corner (its plinth, sills and lobby columns).
		var band: Array = _kit[path]["band"]
		return [["rect", float(band[0]), float(band[1]), float(band[2]), float(band[3])]]
	m = _bridge.search(path)
	if m != null:
		# A metre of parapet, 0.25 m thick, its inner face a centimetre
		# outside the deck's edge (models.py PARAPET_OFF); the ramps at the
		# ends have none.
		if m.get_string(1).begins_with("end_"):
			return []
		return [["rect", -1.0, 0.0, -0.26, -0.01]] if m.get_string(2) == "back" else [["rect", -1.0, 0.0, 0.01, 0.26]]
	return null


## A façade slice's solid parts (models.py hall_strip, lib_strip): its
## metre of wall, WALL deep behind the outer face, with nothing standing
## proud of it in the band; a doorway's reveals (`door_l`, `door_r`) hold
## its leaves folded across that depth, and its opening (`door_m`) is
## clear.
static func _facade(side: String, piece: String) -> Array:
	if piece == "door_m":
		return []
	# Along x (a south face) or z (an east face), the metre before the
	# slice's origin.
	if side == "s":
		return [["rect", -1.0, 0.0, -WALL, 0.0]]
	return [["rect", -WALL, 0.0, -1.0, 0.0]]


## Shapes turned to `facing` (degrees clockwise from north) about the
## ground point, rects as polygons.
static func _turned(shapes: Array, facing: float) -> Array:
	var t := deg_to_rad(facing)
	var c := cos(t)
	var s := sin(t)
	var out := []
	for sh in shapes:
		if sh[0] == "disc":
			out.append(["disc", sh[1], sh[2] * c - sh[3] * s, sh[2] * s + sh[3] * c])
		else:
			var poly := []
			for p in [Vector2(sh[1], sh[3]), Vector2(sh[2], sh[3]), Vector2(sh[2], sh[4]), Vector2(sh[1], sh[4])]:
				poly.append(Vector2(p.x * c - p.y * s, p.x * s + p.y * c))
			out.append(["poly", poly])
	return out


## Shapes of a sprite drawn mirrored: the screen's left and right swap, so
## east and south do.
static func _mirrored(shapes: Array) -> Array:
	var out := []
	for sh in shapes:
		match sh[0]:
			"disc":
				out.append(["disc", sh[1], sh[3], sh[2]])
			"rect":
				out.append(["rect", sh[3], sh[4], sh[1], sh[2]])
			_:
				out.append(["poly", sh[1].map(func(p): return Vector2(p.y, p.x))])
	return out


static func _solid(shapes: Array, at: Vector2, owner: Dictionary) -> Solid:
	var solid := Solid.new()
	solid.owner = owner
	solid.pixel = 0.001
	for sh in shapes:
		match sh[0]:
			"disc":
				solid.discs.append(Vector3(at.x + sh[2], at.y + sh[3], sh[1]))
			"rect":
				var poly := PackedVector2Array([at + Vector2(sh[1], sh[3]), at + Vector2(sh[2], sh[3]),
					at + Vector2(sh[2], sh[4]), at + Vector2(sh[1], sh[4])])
				solid.pieces.append(poly)
				solid.contours.append(poly)
			_:
				var poly := PackedVector2Array()
				for p in sh[1]:
					poly.append(at + p)
				solid.pieces.append(poly)
				solid.contours.append(poly)
	solid.place(Transform2D.IDENTITY)
	return solid
