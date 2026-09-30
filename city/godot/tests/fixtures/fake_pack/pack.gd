## A pack that draws nothing and records what it was asked to show.
extends StylePack

var built := false
var presence := {}
var places := {}
## Ids a test says are out of view (StylePack.is_seen).
var unseen := {}


func is_seen(id: String) -> bool:
	return not unseen.has(id)


## Frames between moves a test sets for an id (StylePack.move_every).
var steps := {}


func move_every(id: String) -> int:
	return int(steps.get(id, 1))



func build_world(manifest: Dictionary) -> bool:
	built = manifest.has("city")
	return built


func teardown() -> void:
	super.teardown()
	built = false


func make_occupant(view: Dictionary) -> Node:
	resolve("occupants", occupant_key(view))
	return Node.new()


func set_pose(id: String, pose: String) -> void:
	super(id, pose)


func set_presence(id: String, headline: String) -> void:
	super(id, headline)
	resolve("headlines", headline)
	presence[id] = headline


func place(id: String, pos_cm: Vector2, _dir: Vector2) -> void:
	places[id] = pos_cm


func set_time_of_day(m: int) -> void:
	super(m)


func make_player_marker() -> Node:
	return Node.new()


## Whether the title's drift is on, and every flight asked for, as
## [ground_cm, seconds].
var drift := false
var flights := []


func title_drift(on: bool) -> void:
	drift = on


## Records the flight. A test that sets an Array as this pack's `fly_log`
## meta also gets it there, as [ground_cm, seconds, keep_view].
func fly_to(ground_cm: Vector2, seconds: float, keep_view := false) -> void:
	flights.append([ground_cm, seconds])
	if has_meta("fly_log"):
		(get_meta("fly_log") as Array).append([ground_cm, seconds, keep_view])


## Where a test puts the camera over the ground, in centimetres; null, as
## a 2D pack's, until it does.
var ground = null


func camera_ground_pos():
	return ground


## How many map pictures were asked of this pack, and whether it answers
## them with a stand-in (as a 3D pack does when the renderer gives it no
## picture to copy).
var map_asks := 0
var map_stand_in := false


func request_map(extent_m: Rect2, size_px: Vector2i) -> void:
	map_asks += 1
	if not map_stand_in:
		super(extent_m, size_px)
		return
	var image := Image.create(maxi(size_px.x, 1), maxi(size_px.y, 1), false, Image.FORMAT_RGBA8)
	map_ready.emit.call_deferred(StylePack.stand_in(ImageTexture.create_from_image(image)))
