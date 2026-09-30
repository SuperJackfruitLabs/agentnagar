## The interface every style pack implements, and the bookkeeping they share.
## A pack is a folder under res://styles/ holding style.json, its assets and
## a pack.gd that extends this class. It draws only what it is given: the
## client passes it the viewer's projection, never the world.
extends Node
class_name StylePack

## Every semantic key the district can emit but the catalogue's kinds (see
## required()); style.json maps each to an asset or treatment, or lists it
## under declared_placeholders.
const REQUIRED := {
	"occupants": ["GuildAgent", "CityRoleAgent", "PersonalAgent", "SimCitizen", "Human"],
	"seats": ["desk", "workstation", "bench", "cafe-table", "reading-chair"],
	"rooms": ["workshop", "commons", "reading-room", "cafe", "cafe-terrace", "plaza", "park", "tram-stop"],
	"exteriors": ["guild-hall", "library", "cafe"],
	"headlines": ["Working", "Waiting", "Queued", "Idle", "Done", "Present", "Offline", "Error", "Stale", "Unknown"],
	"badges": ["Ai", "Simulation"],
	# How displays draw their panels at each level of detail (Surfaces):
	# `far` its `icon_key` (`chip`: the kind's name), `near` its headlines'
	# `colour`, `font_scale` and `max_lines`, and `open` the overlay.
	"surfaces": ["far", "near", "open"],
}
## How far a right stick held over drags the view, in pixels a second.
const STICK_DRAG_PX_PER_S := 400.0
## The name of the "you" marker under the local player's occupant node.
const PLAYER_MARKER := "YouMarker"
## How fast a right stick held over turns the first-person view.
const FPV_TURN_DEG_PER_S := 140.0

var style := {}
## The places this pack was built from (the manifest without its people).
var manifest := {}
## Buildings currently shown open.
var open_ids := {}
## When true, an open building keeps its roof and only its near walls drop.
var keep_roofs := false
## Nodes drawn for scenery items.
var scenery_nodes: Array = []
## Placement ID -> the node drawn for it: its own, or for a kind drawn many
## at a time, the MultiMesh holding it (whose `placement_ids` meta lists
## its instances' placements in order). See tag_placement.
var placement_nodes := {}
## What the pack scatters of its own beyond the placements (moored boats,
## clutter): [{node, rect_cm}], each rect the ground it stands on. None may
## lie within 10 cm of a walkable cell (CityGeometry.clear_of_walkable).
var decor: Array = []
## The walkable grid the layout carries, made when first asked for (null
## for a manifest without one).
var _walkable = null
## The pack's folder, for resolving its asset paths.
var pack_dir := ""
## id -> the occupant's name tag (a Label or Label3D); refresh_label keeps
## its text and visibility current.
var labels := {}
## Keys this pack was asked for but has no mapping for, as "section/key".
var missing := PackedStringArray()
## id -> the occupant's root node.
var nodes := {}
## id -> the occupant's latest view from the projection.
var views := {}
var names_on := false
var selected := ""
var hovered := ""
## The viewer the projection was made for: "public" or a person's city ID.
var viewer := "public"
## The local player's occupant, which gets the "you" marker; "" for none.
var player_id := ""
## What the pack was last told, recorded the same way by every pack (packs
## call super in their overrides).
var poses := {}
## id -> the pace someone is shown walking at, in cm a second.
var strides := {}
var headlines := {}
var minutes := -1
## The player's Low graphics quality: a pack that can draw more cheaply
## does so while this is on. Set by the host before `on_shown`, which
## applies it (and applies it again when the setting changes).
var quality_low := false
## Calm mode: rain drawn at a quarter of its particles with no streaks, and
## the view cut rather than eased when it follows the avatar. Set by the
## host before the pack is built.
var calm := false
## The player's look settings: mouse sensitivity (`look_scale`), stick
## sensitivity (`stick_scale`), both multiples of the usual speed, and
## whether look Y is inverted. Set by the host; `apply_look` hands them to
## the cameras.
var look_scale := 1.0
var stick_scale := 1.0
var invert_y := false


func setup(s: Dictionary) -> void:
	style = s


## The mapping for `key` in `section`, or {"placeholder": true} after noting
## the gap. A pack never borrows another pack's art.
func resolve(section: String, key: String) -> Dictionary:
	var entry = style.get(section, {}).get(key)
	if entry is Dictionary:
		return entry
	var name := section + "/" + key
	if not name in missing:
		missing.append(name)
	return {"placeholder": true}


## Required keys neither mapped nor declared as placeholders.
static func unmapped(s: Dictionary) -> Array:
	var declared: Array = s.get("declared_placeholders", [])
	var out := []
	var keys := required()
	for section in keys:
		for key in keys[section]:
			var name: String = section + "/" + key
			if not s.get(section, {}).has(key) and not name in declared:
				out.append(name)
	return out


## The catalogue's kinds by ID, in its order, as the core carries them
## (the bridge's catalogue_json): read once.
static var _kinds := {}


static func kinds() -> Dictionary:
	if _kinds.is_empty():
		var parsed = JSON.parse_string(CityWorld.new().catalogue_json())
		for k in parsed.get("kinds", []) if parsed is Dictionary else []:
			_kinds[str(k["id"])] = k
	return _kinds


## Every key style.json maps: REQUIRED, and under "props" every kind of the
## catalogue, which a style skins as a placement of it. A kind drawn from
## another section says which: {"seat": key} (the seats section's art),
## {"building": key} (the exteriors'), {"block": height class} (the
## townscape's lots) or {"vehicle": true} (the trams the projection runs).
static func required() -> Dictionary:
	var out := REQUIRED.duplicate()
	out["props"] = kinds().keys()
	return out


static func occupant_key(view: Dictionary) -> String:
	return str(view.get("kind", {}).get("type", "Unknown"))


## What someone using a thing is doing, on their name tag, by capability.
const USING_WORDS := {"sit": "sitting", "read": "reading", "use": "at a workstation"}


## The text of an occupant's name tag: name, badge, what it is using
## ("reading", "sitting"), and the task summary only when the projection
## carries one.
func label_text(id: String) -> String:
	var v: Dictionary = views.get(id, {})
	var parts := [str(v.get("display_name", id))]
	var kind: Dictionary = v.get("kind", {})
	if kind.get("type") == "PersonalAgent" and kind.get("owner") == viewer:
		parts.append("· your agent")
	elif v.get("badge") == "Ai":
		parts.append("· AI")
	elif v.get("badge") == "Simulation":
		parts.append("· simulation")
	var using = v.get("using")
	if using is Dictionary:
		var capability := str(using.get("capability", ""))
		parts.append("· " + USING_WORDS.get(capability, capability))
	var text := " ".join(parts)
	if v.get("task_summary") != null:
		text += "\n" + str(v["task_summary"])
	return text


func label_visible(id: String) -> bool:
	return names_on or id == selected or id == hovered


# ---- Scenery, buildings and cameras (shared bookkeeping) ----

## Draws every scenery item (packs implement make_scenery()), then the
## rails of every transit line in the manifest, a node a track (packs
## implement make_track()).
func build_scenery(items: Array) -> void:
	for item in items:
		var kind := str(item.get("kind", ""))
		if kind == "bridge":
			var ends := CityGeometry.scenery_points(item)
			bridges.append({"a": ends[0], "b": ends[1], "width": float(item.get("width", 400)) / 100.0})
		var node := make_scenery(item)
		if node != null:
			_style_node(node)
			node.set_meta("kind", kind)
			node.set_meta("scenery", kind)
			scenery_parent().add_child(node)
			scenery_nodes.append(node)
	for line in manifest.get("lines", []):
		for index in line.get("tracks", []).size():
			var node := make_track(line, index)
			if node != null:
				_style_node(node)
				node.name = "Track_%s_%d" % [str(line["id"]).replace(":", "_"), index]
				node.set_meta("line", str(line["id"]))
				node.set_meta("scenery", "track")
				scenery_parent().add_child(node)
				track_nodes.append(node)


## Warns of a placement whose kind is drawn from elsewhere, naming the
## kind and the section its art is in: a building stands as a facility and
## a vehicle runs on a line, never as a district placement. True when it
## is one (the pack then marks its spot with a placeholder).
func warn_drawn_elsewhere(id: String, kind: String, entry: Dictionary) -> bool:
	var section := ""
	if entry.has("building"):
		section = "the exteriors section (%s), drawn for a facility" % entry["building"]
	elif entry.has("vehicle"):
		section = "the vehicle a line's projection runs"
	if section == "":
		return false
	push_warning("%s is a %s placement, but a %s's art is %s; a placeholder marks it" % [id, kind, kind, section])
	return true


## Records `node` as what was drawn for placement `id`, tagged with its ID
## (meta `placement_id`) so tools can tell whose it is.
func tag_placement(node: Node, id: String) -> void:
	node.set_meta("placement_id", id)
	placement_nodes[id] = node


## Records a MultiMesh drawing several placements, one an instance, tagged
## with their IDs in instance order (meta `placement_ids`).
func tag_placements(node: MultiMeshInstance3D, ids: PackedStringArray) -> void:
	node.set_meta("placement_ids", ids)
	for id in ids:
		placement_nodes[id] = node


# ---- Workstation screens ----

## Every workstation drawn with a screen the in-world monitor lights
## (StationMonitor): its seat's or placement's ID -> {state, feed, pulse}
## as last shown. `state` is "idle" (the style's dark screen), "in_use"
## (its glow) or "live" (`feed`, a texture of the station computer); a
## `pulse` from 0 to 1 brightens it while the station's chat works.
var screens := {}


## Records the screen drawn for workstation `id`, idle, for the monitor.
func add_screen(id: String) -> void:
	screens[id] = {"state": "idle", "feed": null, "pulse": 0.0}


## Shows workstation `id`'s screen as `state`, with `feed` when live and
## `pulse`; nothing for a desk drawn without a screen, and nothing drawn
## again when nothing changed.
func show_screen(id: String, state: String, feed: Texture2D = null, pulse := 0.0) -> void:
	if not screens.has(id):
		return
	var shown := {"state": state, "feed": feed if state == "live" else null, "pulse": pulse}
	if shown == screens[id]:
		return
	screens[id] = shown
	_draw_screen(id, shown)


## Draws what show_screen recorded for `id`; the pack's own.
func _draw_screen(_id: String, _shown: Dictionary) -> void:
	pass


## The size of the feed workstation `id`'s screen shows, in pixels; zero
## where it can show none (no screen, or a face the view never sees).
func screen_feed_size(_id: String) -> Vector2i:
	return Vector2i.ZERO


## Where workstation `id`'s screen stands on the ground, metres; null for
## a desk drawn with none.
func screen_point(_id: String):
	return null


## What the pack lights over workstation `id`'s screen, or null.
func screen_overlay(_id: String) -> Node:
	return null


## The walkable grid the layout carries (see NavQuery.from_layout), for
## keeping the pack's own scatter off walkable ground; an empty grid when
## the manifest has none.
func walkable_grid() -> NavQuery:
	if _walkable == null:
		_walkable = NavQuery.from_layout(manifest)
	return _walkable


## Whether scatter of the pack's own may stand on `rect_m` (metres): no
## walkable cell's centre within 10 cm of it. Recorded in `decor` when it
## may.
func place_decor(node: Node, rect_m: Rect2) -> bool:
	var rect_cm := Rect2i(Vector2i((rect_m.position * 100.0).floor()), Vector2i((rect_m.size * 100.0).ceil()))
	if not CityGeometry.clear_of_walkable(walkable_grid(), rect_cm):
		return false
	decor.append({"node": node, "rect_cm": rect_cm})
	return true


## Nodes drawn for the transit lines' tracks, in the manifest's order.
var track_nodes: Array = []


## Bridges walkers cross: {a, b, width} in metres.
var bridges := []


## How high the ground a walker stands on is at `p_m` (metres): a bridge's
## deck, by the style's `bridge_deck` and `bridge_ramp`; 0 elsewhere.
func deck_at(p_m: Vector2) -> float:
	return CityGeometry.deck_height(bridges, p_m, float(style.get("bridge_deck", 0.0)), float(style.get("bridge_ramp", 0.0)))


## A style's finishing touch on everything it builds (the world, each
## scenery item, each person, each repaint); none by default.
func _style_node(_node: Node) -> void:
	pass


## Where scenery nodes go (a 2D pack sorts them with its world).
func scenery_parent() -> Node:
	return self


func scenery_count() -> int:
	return scenery_nodes.size()


## Buildings this pack draws as whole volumes.
func facility_ids() -> Array:
	return CutawayRule.facilities_of(manifest).keys()


func set_open(id: String, open: bool) -> void:
	if open:
		open_ids[id] = true
	else:
		open_ids.erase(id)
	apply_open(id, open)


## Keeps roofs on open buildings (or lets them lift), re-showing those open.
func set_keep_roofs(on: bool) -> void:
	if keep_roofs == on:
		return
	keep_roofs = on
	for id in open_ids:
		apply_open(id, true)


func is_open(id: String) -> bool:
	return open_ids.has(id)


## Where the camera is over the ground, in centimetres, or null (2D packs).
func camera_ground_pos():
	return null


# ---- Plants that sway (see SoftContacts) ----

## The clumps the pack drew on soft ground, as SoftContacts.bind takes them;
## packs that draw any say.
func soft_instances() -> Array:
	return []


## Where occupant `id` (one of `nodes`) is drawn on the ground now, in
## metres; Vector2.INF when the pack cannot say.
func drawn_ground(_id: String) -> Vector2:
	return Vector2.INF


## The ground point, in metres, that plants sway round (people farther
## than SoftContacts.REACH_M from it part nothing): the middle of the
## camera's view, or null with none. Packs say where theirs is.
func sway_centre():
	return null


func camera_presets() -> Array:
	return []


## How a building is drawn now: {"roof": shown}. Empty if it has no shell.
func shell_state(_id: String) -> Dictionary:
	return {}


func set_camera_preset(_name: String) -> bool:
	return false


## Zooms one notch in (1) or out (-1). The controller's triggers reach the
## pack as the wheel notch it already handles, so both zoom the same way.
func zoom_step(direction: int) -> void:
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP if direction > 0 else MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	_camera_input(wheel)


## Orbits a 3D view or pans a 2D one by the right stick's `v` over `delta`
## seconds, as a right-drag of the mouse does: the stick pushed right turns
## or pans the view to the right.
func orbit(v: Vector2, delta: float) -> void:
	if v == Vector2.ZERO:
		return
	if fpv != null:
		var turn := v * FPV_TURN_DEG_PER_S * delta * stick_scale
		fpv.look(-turn.x, turn.y if invert_y else -turn.y)
		return
	var flat: bool = style.get("dimension") == "2d"
	var drag := InputEventMouseMotion.new()
	drag.relative = v * STICK_DRAG_PX_PER_S * delta * stick_scale * (-1.0 if flat else 1.0)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	for e in [press, drag, release]:
		_camera_input(e)


## How far into the screen a walking avatar may go before the view
## follows, as a fraction of its size from each edge.
const VIEW_MARGIN := 0.25
## How quickly the view catches up, per second.
const VIEW_FOLLOW_RATE := 4.0


## Overhead, eases the view after a walking avatar at `pos_cm` once it
## leaves the middle of the screen, so it never walks off it; it moves
## the view only as far as brings the avatar back to that middle's edge.
func keep_in_view(pos_cm: Vector2, delta: float) -> void:
	if fpv != null or not is_inside_tree():
		return
	var s = screen_at(pos_cm)
	if s == null:
		return
	var rect := get_viewport().get_visible_rect()
	var inner := rect.grow_individual(-rect.size.x * VIEW_MARGIN, -rect.size.y * VIEW_MARGIN,
		-rect.size.x * VIEW_MARGIN, -rect.size.y * VIEW_MARGIN)
	if inner.has_point(s):
		return
	# Calm mode never swings the view: it cuts once, putting the avatar
	# back in the middle of the screen.
	if calm:
		var middle = ground_at(rect.get_center())
		if middle != null:
			shift_view(pos_cm - middle)
		return
	var edge = ground_at(s.clamp(inner.position, inner.end))
	if edge == null:
		return
	shift_view((pos_cm - edge) * (1.0 - exp(-VIEW_FOLLOW_RATE * delta)))


## Moves the overhead view by `ground_cm` over the ground.
func shift_view(_ground_cm: Vector2) -> void:
	pass


# ---- The title's camera ----

## How long Explore's flight from the title down into play takes; calm
## mode cuts instead.
const FLIGHT_S := 1.2


## Behind the title the view drifts slowly (on), or holds where it is
## (off). None by default.
func title_drift(_on: bool) -> void:
	pass


## Moves the view to `ground_cm` over `seconds`, as Explore does from the
## title down into play; at 0 it cuts. With `keep_view` the view only
## slides there, keeping the heading and the distance it has (the map's
## Go: a jump must neither spin the view nor undo its zoom), rather than
## taking its preset's. None by default.
func fly_to(_ground_cm: Vector2, _seconds: float, _keep_view := false) -> void:
	pass


## Settles the view behind a chair at `chair_cm`, whose sitter faces
## `facing` degrees clockwise from north: the backdrop of the station
## computer. Returns what `restore_view` needs to put the view back. In
## first person the eye turns to face the desk; a pack with no camera to
## move (the 2D styles) keeps its view and returns null.
func settle_view(_chair_cm: Vector2, facing: int) -> Variant:
	if fpv == null:
		return null
	var saved := {"fpv": [fpv.yaw, fpv.pitch]}
	var ahead := Vector2(sin(deg_to_rad(facing)), -cos(deg_to_rad(facing)))
	fpv.look(FpvCamera.yaw_along(ahead) - fpv.yaw, -fpv.pitch)
	return saved


## Puts back the view `settle_view` saved.
func restore_view(saved: Variant) -> void:
	if saved is Dictionary and saved.has("fpv") and fpv != null:
		fpv.look(saved["fpv"][0] - fpv.yaw, saved["fpv"][1] - fpv.pitch)


## Lets go of a mouse drag of the view, as if its button had been released:
## a screen opened mid-drag keeps the release from the pack, which would
## otherwise go on turning the view with every mouse move after it closes.
## Nothing to let go of by default.
func end_drag() -> void:
	pass


func _camera_input(event: InputEvent) -> void:
	if has_method("_unhandled_input"):
		call("_unhandled_input", event)


# ---- Between the screen and the ground ----
# A 3D pack is read through the viewport's camera. A 2D pack draws the
# ground through a projection it exposes as iso(x_m, z_m) -> Vector2, the
# position in its occupant layer of a ground point in metres.

## The ground point, in centimetres, under a screen position, or null.
func ground_at(screen_pos: Vector2):
	if not is_inside_tree():
		return null
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var origin := cam.project_ray_origin(screen_pos)
		var ray := cam.project_ray_normal(screen_pos)
		if ray.y > -0.0001:
			return null
		var hit := origin + ray * (-origin.y / ray.y)
		return Vector2(hit.x, hit.z) * 100.0
	var iso = _iso()
	if iso == null:
		return null
	var layer := _layer_to_screen().affine_inverse() * screen_pos
	return (iso.affine_inverse() * layer) * 100.0


## Where a ground point, in centimetres, is on screen, or null.
func screen_at(ground_cm: Vector2):
	if not is_inside_tree():
		return null
	var at := ground_cm / 100.0
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var p := Vector3(at.x, 0.0, at.y)
		return null if cam.is_position_behind(p) else cam.unproject_position(p)
	var iso = _iso()
	return null if iso == null else _layer_to_screen() * (iso * at)


## A direction on screen (x right, y down) as a unit direction on the
## ground (x east, y south): up the screen is away from a 3D camera, and
## along the 2D projection's up. Without a view, screen up is north.
func ground_direction(screen_dir: Vector2) -> Vector2:
	if screen_dir == Vector2.ZERO:
		return Vector2.ZERO
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var b := cam.global_basis
		var right := Vector2(b.x.x, b.x.z)
		# Away from the camera: its view direction and its up, each laid
		# flat, never both vanish.
		var ahead := Vector2(-b.z.x, -b.z.z) + Vector2(b.y.x, b.y.z)
		return (right.normalized() * screen_dir.x - ahead.normalized() * screen_dir.y).normalized()
	var iso = _iso() if is_inside_tree() else null
	if iso != null:
		var to_ground: Transform2D = iso.affine_inverse() * _layer_to_screen().affine_inverse()
		return to_ground.basis_xform(screen_dir).normalized()
	return screen_dir.normalized()


## The 2D pack's ground projection in metres, or null in 3D.
func _iso():
	if not has_method("iso"):
		return null
	var o: Vector2 = call("iso", 0.0, 0.0)
	return Transform2D(call("iso", 1.0, 0.0) - o, call("iso", 0.0, 1.0) - o, o)


func _layer_to_screen() -> Transform2D:
	var layer := occupant_parent()
	return layer.get_global_transform_with_canvas() if layer is CanvasItem else Transform2D.IDENTITY


# ---- The map's base picture ----

## A request's answer: the district from straight above, its texture the
## pack's to cache.
signal map_ready(texture: Texture2D)

## The colour round the district on the map, and the plain picture a style
## without its own draws.
const MAP_LETTERBOX := "#F4F1EA"


## The size of the plain picture asked for and not yet given, or null.
var _plain_map_asked = null


## Draws the district from straight above, north up, over `extent_m`
## (metres, x east and y south) at `size_px` pixels, and emits `map_ready`
## with it. Requests made before the answer share one answer, drawn as the
## latest asks. By default the picture is plain: the style's
## `map.letterbox` colour all over, a frame later, as a drawn one would
## come.
func request_map(_extent_m: Rect2, size_px: Vector2i) -> void:
	if _plain_map_asked == null:
		_answer_plain_map.call_deferred()
	_plain_map_asked = size_px


func _answer_plain_map() -> void:
	var size_px: Vector2i = _plain_map_asked
	_plain_map_asked = null
	var image := Image.create(maxi(size_px.x, 1), maxi(size_px.y, 1), false, Image.FORMAT_RGBA8)
	image.fill(Color.html(str(style.get("map", {}).get("letterbox", MAP_LETTERBOX))))
	map_ready.emit(ImageTexture.create_from_image(image))


## The time of day the map is drawn at: the style's `map.minutes`, else noon.
func map_minutes() -> int:
	return int(style.get("map", {}).get("minutes", 720))


## How much brighter the map is drawn than the world is shown: the style's
## `map.exposure`, else 1. A 3D pack scales its tonemap's exposure by it
## for the one frame the picture is drawn.
func map_exposure() -> float:
	return float(style.get("map", {}).get("exposure", 1.0))


## The meta a stand-in picture carries: one given when nothing could be
## drawn (no display, or the renderer gave back no image), which the host
## does not keep, so the next opening asks again.
const STAND_IN_META := "map_stand_in"


## Marks `texture` as a stand-in, and gives it back.
static func stand_in(texture: Texture2D) -> Texture2D:
	texture.set_meta(STAND_IN_META, true)
	return texture


static func is_stand_in(texture: Texture2D) -> bool:
	return texture != null and texture.get_meta(STAND_IN_META, false)


# ---- The soft reticle: what A would act on (overhead views) ----

## The reticle node while one has been shown, and where it stands (cm).
var reticle: Node
var _reticle_at := Vector2.ZERO


## Shows the reticle on ground point `pos_cm`, or hides it for null.
func show_reticle(pos_cm) -> void:
	if pos_cm == null:
		if reticle != null:
			reticle.visible = false
		return
	if reticle == null or not is_instance_valid(reticle):
		reticle = make_reticle()
		reticle.name = "Reticle"
		occupant_parent().add_child(reticle)
	_reticle_at = pos_cm
	var at: Vector2 = pos_cm / 100.0
	if reticle is Node3D:
		reticle.position = Vector3(at.x, 0.0, at.y)
	elif _iso() != null:
		reticle.position = call("iso", at.x, at.y)
	reticle.visible = true


func reticle_ground_pos() -> Vector2:
	return _reticle_at


func reticle_screen_pos():
	return screen_at(_reticle_at) if reticle != null and reticle.visible else null


## A soft white ring (3D) or a small outlined diamond (2D); a pack may
## draw its own.
func make_reticle() -> Node:
	if style.get("dimension") == "3d":
		return PlayerMarker.ring(Color(1, 1, 1, 0.75), 0.35)
	var n := Polygon2D.new()
	n.polygon = PackedVector2Array([Vector2(0, -6), Vector2(12, 0), Vector2(0, 6), Vector2(-12, 0)])
	n.color = Color(1, 1, 1, 0.35)
	var edge := Line2D.new()
	edge.points = n.polygon
	edge.closed = true
	edge.width = 1.0
	edge.default_color = Color(1, 0.82, 0.43)
	edge.antialiased = false
	n.add_child(edge)
	return n


# ---- The local player ----

## Makes the local player's "you" marker, a child of its occupant's node
## so it goes where the avatar goes: a ring decal in 3D, an arrow in 2D
## (see PlayerMarker). Null for none.
func make_player_marker() -> Node:
	return null


## Marks `id` as the local player's occupant, moving the marker to it; ""
## marks nobody.
func set_player(id: String) -> void:
	var marker := player_marker()
	if marker != null:
		marker.free()
	player_id = id
	_mark_player()


## The marker on the local player's occupant, or null.
func player_marker() -> Node:
	return nodes[player_id].get_node_or_null(PLAYER_MARKER) if nodes.has(player_id) else null


func _mark_player() -> void:
	if not nodes.has(player_id) or player_marker() != null:
		return
	var marker := make_player_marker()
	if marker != null:
		marker.name = PLAYER_MARKER
		nodes[player_id].add_child(marker)


## The bridge records a look's outfit as `outfit`; packs choose clothes by
## `palette`, as the crowd's profiles give it. An outfit stands in for a
## missing palette.
static func _dressed(view: Dictionary) -> Dictionary:
	var looks: Dictionary = view.get("appearance", {})
	if not looks.has("outfit") or looks.has("palette"):
		return view
	var out := view.duplicate()
	out["appearance"] = looks.merged({"palette": looks["outfit"]})
	return out


# ---- First-person view (3D packs) ----

## The first-person camera while the view is on, else null.
var fpv: FpvCamera
var _overhead: Camera3D
var _fpv_hidden: Node


func supports_fpv() -> bool:
	return style.get("dimension") == "3d"


## Turns the first-person view on (facing `yaw_deg`) or off; true while on.
func set_fpv(on: bool, yaw_deg := 0.0) -> bool:
	if on == (fpv != null):
		return on
	if on:
		if not supports_fpv() or not is_inside_tree():
			return false
		_overhead = get_viewport().get_camera_3d()
		fpv = FpvCamera.new()
		add_child(fpv)
		apply_look()
		fpv.look(yaw_deg, -8.0)
		fpv.make_current()
		return true
	_fpv_body(true)
	if is_instance_valid(_overhead):
		_overhead.make_current()
	fpv.free()
	fpv = null
	return false


## Stands the eye over the avatar at `pos_cm`, its body hidden but for its
## shadow.
## Wall runs the first-person eye keeps clear of: {a, b, half} in metres.
var walls := []
## How far the eye keeps from a wall's surface: past the near plane's
## reach, so it never looks through one.
const EYE_CLEAR := 0.12


func fpv_follow(pos_cm: Vector2) -> void:
	if fpv == null:
		return
	fpv.follow(CityGeometry.clear_of_walls(pos_cm / 100.0, walls, EYE_CLEAR))
	fpv.position.y += deck_at(pos_cm / 100.0)
	_fpv_body(false)


## Aboard a tram, sits the first-person eye at `eye_m` (metres, at eye
## height over the rider's seat) in a vehicle heading `heading_deg`, the
## avatar's body hidden but for its shadow (see FpvCamera.sit).
func fpv_seat(eye_m: Vector3, heading_deg: float) -> void:
	if fpv == null:
		return
	fpv.sit(eye_m, heading_deg)
	_fpv_body(false)


## Shows the avatar's body, or keeps only its shadow (and hides its marker
## and name tag), so the eye does not look out through its own head.
func _fpv_body(show: bool) -> void:
	var node = nodes.get(player_id)
	if not show and (node == null or node == _fpv_hidden):
		return
	var target = node if not show else _fpv_hidden
	if target == null or not is_instance_valid(target):
		_fpv_hidden = null
		return
	for g in target.find_children("*", "GeometryInstance3D", true, false):
		if g is MeshInstance3D:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if show else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		elif not show:
			g.visible = false
	var marker = target.get_node_or_null(PLAYER_MARKER)
	if marker != null:
		marker.visible = show
	_fpv_hidden = null if show else target
	if show:
		# The tag and presence icon follow their own rules again.
		refresh_label(player_id)
		set_presence(player_id, headlines.get(player_id, "Unknown"))


# ---- What each pack implements ----

## Makes the node for one scenery item (water, bridge, street or fence).
func make_scenery(_item: Dictionary) -> Node:
	return null


## Makes the rails of track `index` (0 east, 1 west) of transit line
## `line` (see CityGeometry.track_points), or null to draw none.
func make_track(_line: Dictionary, _index: int) -> Node:
	return null


## Makes the node for one vehicle from its view: its front at the node's
## origin, running along the node's own x (3D) or drawn about its middle
## (2D). A pack draws its own tram; by default there is nothing to see.
func make_vehicle(_view: Dictionary) -> Node:
	return Node.new()


## Where vehicle nodes go; by default with the people.
func vehicle_parent() -> Node:
	return occupant_parent()


## Stands vehicle `id`'s node with its front at `pos_cm`, heading
## `heading` degrees clockwise from north. Packs call super.
func place_vehicle(id: String, pos_cm: Vector2, heading: float) -> void:
	vehicle_places[id] = [pos_cm, heading]


## Puts rider `id`'s node, now a child of its vehicle's node, at `local_cm`
## in the vehicle's own frame (x ahead of its front, y to the left of the
## way it runs), facing the way it runs.
func seat_rider(_id: String, _local_cm: Vector2) -> void:
	pass


## Shows a building open (roof faded, near walls down) or closed.
func apply_open(_id: String, _open: bool) -> void:
	pass


## Builds the static world from the manifest; false if it cannot.
func build_world(_manifest: Dictionary) -> bool:
	return true


## Makes the node for one occupant.
func make_occupant(_view: Dictionary) -> Node:
	return Node.new()


## The id the Join screen's figure is made under.
const PREVIEW_ID := "person:preview"


## The Join screen's figure: a person in outfit `outfit` (0-7) and hair
## `hair` (0-3), made by `make_occupant` and finished as the crowd is, but
## kept out of what the pack records about who is shown. Null when the
## pack makes no figure it can show (a bare Node).
func preview_figure(outfit: int, hair: int) -> Node:
	var node := make_occupant({"id": PREVIEW_ID, "kind": {"type": "Human", "tier": "Registered"},
		"appearance": {"palette": str(outfit), "hair": str(hair)}})
	_forget(PREVIEW_ID)
	if not (node is Node3D or node is Node2D):
		node.free()
		return null
	_trim(node)
	_style_node(node)
	return node


## Drops what the pack keeps about `id` beyond its node.
func _forget(id: String) -> void:
	labels.erase(id)


## Where occupant nodes go; a 2D pack returns its depth-sorted layer so
## people pass behind walls and furniture.
func occupant_parent() -> Node:
	return self


func place(_id: String, _pos_cm: Vector2, _dir: Vector2) -> void:
	pass


func set_pose(id: String, pose: String) -> void:
	poses[id] = pose


## The walk clips are timed for this pace, in cm a second.
const WALK_CM_S := 125.0


## Sets the pace `id` is shown walking at, so feet keep to the ground: a
## short tick's steps or a faster clock quicken or slow the walk cycle.
func set_stride(id: String, cm_s: float) -> void:
	if strides.has(id) and absf(float(strides[id]) - cm_s) < 0.5:
		return
	strides[id] = cm_s
	_restride(id)


## How fast `id`'s walk cycle plays, as a multiple of its timed pace.
func stride_scale(id: String) -> float:
	return maxf(0.0, float(strides.get(id, WALK_CM_S))) / WALK_CM_S


## Applies a changed stride to `id`'s walk cycle.
func _restride(_id: String) -> void:
	pass


func set_presence(id: String, headline: String) -> void:
	headlines[id] = headline


func set_time_of_day(m: int) -> void:
	minutes = m


## How hard it rains, 0 to 1, as the host eases it; a pack draws it.
var rain := 0.0


func set_rain(amount: float) -> void:
	rain = amount


## Whether `id` is in view (a pack that knows may say not, and is then
## moved less often).
func is_seen(_id: String) -> bool:
	return true


## Every how many frames `id` need be moved: 1 when it shows large, more
## when it is small on screen (a pack that knows says).
func move_every(_id: String) -> int:
	return 1


## The light at `m` minutes past midnight, fractions included, eased every
## frame between ticks. Packs whose light only switches at dusk and dawn
## leave it alone.
func set_daylight(_m: float) -> void:
	pass


## Shows or hides one occupant's name tag, per label_visible().
func refresh_label(id: String) -> void:
	if labels.has(id) and is_instance_valid(labels[id]):
		labels[id].text = label_text(id)
		labels[id].visible = label_visible(id)


## A path inside this pack's folder.
func asset(path: String) -> String:
	return pack_dir.path_join(path)


## The occupant under a screen position, or "".
func pick(_screen_pos: Vector2) -> String:
	return ""


# ---- Displays' surfaces ----

## The displays' surfaces by placement ID (see Surfaces.of_layout), each
## with its `panel` ({} when unbound), the `level` it shows and the `node`
## the pack drew it with (null for a pack that draws none).
var surfaces := {}


## Draws each display's surface (`list`, see Surfaces.of_layout, with
## panels): packs implement make_surface and show_surface. Each starts
## at no level; update_surfaces sets it.
func set_surfaces(list: Array) -> void:
	for s in list:
		var entry: Dictionary = s.duplicate()
		entry["level"] = ""
		entry["node"] = null
		surfaces[entry["id"]] = entry
		entry["node"] = make_surface(entry)


## The display in focus: the one the player targets (update_surfaces'
## `target_id`), else the nearest within Interact.OVERHEAD_REACH_M of
## someone; "" for none. A pack with little room for text (pixel art)
## draws more for it than for the rest.
var surface_focus := ""


## Sets each surface's level of detail for someone at `focus_cm` (ground
## cm; null for no one, when every surface is far), with the overlay open
## on `open_id` ("" for none) and the player targeting `target_id` (""
## for nothing, or something not a display), and the display in focus
## (surface_focus). A surface is drawn again only when its level or the
## focus changes, so this is cheap to call every frame.
func update_surfaces(focus_cm, open_id := "", target_id := "") -> void:
	var focus := ""
	var nearest := Interact.OVERHEAD_REACH_M
	for id in surfaces:
		var s: Dictionary = surfaces[id]
		var distance: float = INF if focus_cm == null else (focus_cm - s["pos"]).length() / 100.0
		if distance <= nearest:
			nearest = distance
			focus = id
		var now: String = Surfaces.level(distance, id == open_id)
		if now != s["level"]:
			s["level"] = now
			show_surface(id, now)
	if surfaces.has(target_id):
		focus = target_id
	if focus != surface_focus:
		var was := surface_focus
		surface_focus = focus
		for id in [was, focus]:
			if surfaces.has(id) and surfaces[id]["level"] != "":
				show_surface(id, surfaces[id]["level"])


## The text surface `id` shows now, in the style's `surfaces` block, with
## at most `max_lines` headlines when given (a pack whose face has no room
## for them all).
func surface_text(id: String, max_lines := -1) -> String:
	var s: Dictionary = surfaces.get(id, {})
	if s.is_empty() or s["level"] == "":
		return ""
	var most := int(resolve("surfaces", "near").get("max_lines", 3))
	return Surfaces.text(s, s["level"], most if max_lines < 0 else mini(max_lines, most))


## Draws one display's surface at the display anchor, facing the way its
## text faces; returns the node, or null for a pack that draws none.
func make_surface(_surface: Dictionary) -> Node:
	return null


## Shows surface `id` at `level` (Surfaces.FAR, NEAR or OPEN).
func show_surface(_id: String, _level: String) -> void:
	pass


# ---- Shared bookkeeping ----

func spawn(view: Dictionary, pose: String) -> void:
	var id: String = view["id"]
	if nodes.has(id):
		despawn(id)
	view = _dressed(view)
	views[id] = view
	var node := make_occupant(view)
	node.set_meta("occupant", id)
	_trim(node)
	_style_node(node)
	occupant_parent().add_child(node)
	nodes[id] = node
	set_pose(id, pose)
	set_presence(id, str(view.get("presence", {}).get("headline", "Unknown")))
	refresh_label(id)
	if id == player_id:
		_mark_player()


## Hands `look_scale` and `invert_y` to the cameras that turn with the
## mouse: the first-person eye here, and a 3D pack's orbit rig. The stick's
## own sensitivity is applied in `orbit`.
func apply_look() -> void:
	if fpv != null:
		fpv.look_scale = look_scale
		fpv.invert_y = invert_y


## Called once the pack is the one shown: after the pack before it has
## been torn down (which puts the viewport and renderer back as the project
## has them), so settings made here are not undone by the one going.
func on_shown() -> void:
	pass


## A shared resource's value before any pack changed it: recorded on the
## resource the first time a pack asks, so a pack built while another still
## holds the resource changed never takes that change for the original.
static func original(res: Resource, key: String, current: Variant) -> Variant:
	var meta := "original_" + key
	if not res.has_meta(meta):
		res.set_meta(meta, current)
	return res.get_meta(meta)


## Drops what a dressed occupant will never show (a pack that builds
## people from kits says what).
func _trim(_node: Node) -> void:
	pass


func update_view(view: Dictionary) -> void:
	views[view["id"]] = _dressed(view)
	refresh_label(view["id"])


func despawn(id: String) -> void:
	riders.erase(id)
	rider_offsets.erase(id)
	if nodes.has(id):
		nodes[id].free()
		nodes.erase(id)
	views.erase(id)
	labels.erase(id)
	poses.erase(id)
	strides.erase(id)
	headlines.erase(id)


# ---- Vehicles and their riders ----

## id -> a vehicle's root node, drawn from the projection's vehicles.
var vehicle_nodes := {}
## id -> the vehicle's latest view.
var vehicle_views := {}
## id -> [front (cm), heading (degrees)] it was last stood at.
var vehicle_places := {}
## id -> whether its doors are shown open.
var doors := {}
## Occupant id -> the vehicle it rides inside, and its place there (cm,
## in the vehicle's frame; see seat_rider).
var riders := {}
var rider_offsets := {}


## Draws a vehicle from its view, standing where the view has it.
func spawn_vehicle(view: Dictionary) -> void:
	var id: String = view["id"]
	if vehicle_nodes.has(id):
		despawn_vehicle(id)
	vehicle_views[id] = view
	var node := make_vehicle(view)
	node.name = "Vehicle_" + id.replace(":", "_")
	node.set_meta("vehicle", id)
	_style_node(node)
	vehicle_parent().add_child(node)
	vehicle_nodes[id] = node
	set_doors(id, bool(view.get("doors_open", false)))
	place_vehicle(id, Motion.point(view.get("pos", {})), float(view.get("heading", 90)))


## Keeps vehicle `id`'s latest view; the host eases it along its track.
func update_vehicle(view: Dictionary) -> void:
	vehicle_views[view["id"]] = view


## Shows vehicle `id`'s doors open or shut. Packs call super.
func set_doors(id: String, open: bool) -> void:
	doors[id] = open


## Removes vehicle `id`. Anyone still drawn inside it is set down among the
## people first, never freed with it.
func despawn_vehicle(id: String) -> void:
	for rider in riders.keys():
		if riders[rider] == id:
			step_off(rider)
	if vehicle_nodes.has(id):
		vehicle_nodes[id].free()
	vehicle_nodes.erase(id)
	vehicle_views.erase(id)
	vehicle_places.erase(id)
	doors.erase(id)


## Draws occupant `id` inside vehicle `vehicle_id` at `local_cm` (see
## seat_rider): its node becomes a child of the vehicle's, so it rides
## along with no placing of its own.
func board(id: String, vehicle_id: String, local_cm: Vector2) -> void:
	if not nodes.has(id) or not vehicle_nodes.has(vehicle_id):
		return
	var node: Node = nodes[id]
	var vehicle: Node = vehicle_nodes[vehicle_id]
	if node.get_parent() != vehicle:
		node.reparent(vehicle, false)
	riders[id] = vehicle_id
	rider_offsets[id] = local_cm
	seat_rider(id, local_cm)


## Sets occupant `id` down among the people where it is shown, the same
## node, out of the vehicle it rode; the host then places it.
func step_off(id: String) -> void:
	riders.erase(id)
	rider_offsets.erase(id)
	if nodes.has(id) and nodes[id].get_parent() != occupant_parent():
		nodes[id].reparent(occupant_parent(), true)


# ---- Tram doors and portals ----

## How long a tram's doors take to open or shut, in seconds.
const DOOR_S := 0.4
## Trams fade over this last stretch before each portal (cm): gone with
## their middle at the portal, whole this far inside.
const PORTAL_FADE_CM := 1000.0
## The shared tram layout the kits build to (tools/styles/shared/
## tram_layout.py): length, doors, floor and slots.
const TRAM_LAYOUT := "res://styles/tram_layout.json"

static var _tram_layout := {}


static func tram_layout() -> Dictionary:
	if _tram_layout.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(TRAM_LAYOUT))
		_tram_layout = parsed if parsed is Dictionary else {"floor_cm": 40, "door_slide_cm": 60}
	return _tram_layout


## Each line's tracks as vehicle_opacity measures them, made once:
## "<line id>:<direction index>" -> {track (cm points), length (cm)}, or {}
## for a line the manifest does not have.
var _opacity_tracks := {}


## Track `index` (0 east, 1 west) of line `line_id` and its vehicles'
## length, from the manifest the first time they are asked for.
func _opacity_track(line_id: String, index: int) -> Dictionary:
	var key := "%s:%d" % [line_id, index]
	if not _opacity_tracks.has(key):
		var line := CityGeometry.line_of(manifest, line_id)
		_opacity_tracks[key] = {} if line.is_empty() else {"track": CityGeometry.track_points(line, index),
			"length": float(line.get("vehicle", {}).get("length", 2050))}
	return _opacity_tracks[key]


## How visible vehicle `id` is where it was last stood: 1 inside the line,
## fading to 0 as its middle reaches a portal (PORTAL_FADE_CM). Called for
## every tram every frame, so the track comes from _opacity_track.
func vehicle_opacity(id: String) -> float:
	var view: Dictionary = vehicle_views.get(id, {})
	var place = vehicle_places.get(id)
	var index := 0 if str(view.get("direction", "east")) == "east" else 1
	var line := _opacity_track(str(view.get("line", "")), index)
	if place == null or line.is_empty():
		return 1.0
	var heading := deg_to_rad(float(place[1]))
	var middle: Vector2 = place[0] - Vector2(sin(heading), -cos(heading)) * float(line["length"]) / 2.0
	return clampf(CityGeometry.inside_portals(line["track"], middle) / PORTAL_FADE_CM, 0.0, 1.0)


## Which side vehicle `id`'s doors open on: 1 its left, -1 its right, 0
## both (it stands at no stop the manifest names).
func door_side(id: String) -> int:
	return CityGeometry.platform_side(manifest, vehicle_views.get(id, {}))


## Vehicle `id`'s door leaves as the pack draws them: [{node, side: "left"
## or "right", leaf: "fore" or "aft"}]. Packs with doors say.
func door_leaves(_id: String) -> Array:
	return []


## How far open vehicle `id`'s doors are shown, 0 shut to 1 open.
func door_amount(id: String) -> float:
	return 1.0 if doors.get(id, false) else 0.0


## Moves vehicles' doors, roofs and fades on by `delta` seconds; packs that
## animate them say. Called every frame.
func animate_vehicles(_delta: float) -> void:
	pass


func show_names(on: bool) -> void:
	names_on = on
	for id in nodes:
		refresh_label(id)


func set_selected(id: String) -> void:
	var previous := selected
	selected = id
	for x in [previous, id]:
		if nodes.has(x):
			refresh_label(x)


func teardown() -> void:
	_opacity_tracks.clear()
	walls.clear()
	bridges.clear()
	reticle = null
	scenery_nodes.clear()
	placement_nodes.clear()
	screens.clear()
	surfaces.clear()
	decor.clear()
	_walkable = null
	track_nodes.clear()
	open_ids.clear()
	fpv = null
	_fpv_hidden = null
	for id in nodes.keys():
		despawn(id)
	for id in vehicle_nodes.keys():
		despawn_vehicle(id)
	for child in get_children():
		child.free()
