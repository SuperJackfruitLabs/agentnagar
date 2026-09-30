## The first-person camera: at eye height over the avatar, turned by the
## mouse (while captured) or the right stick, pitch clamped to ±80° and yaw
## free; its crosshair resolves to what the act button acts on (see
## Interact). Aboard a tram it sits at the rider's seat instead (`sit`),
## turning with the tram so a look out of a window stays one, and walks
## nowhere.
extends Camera3D
class_name FpvCamera

const EYE_HEIGHT := 1.6
## Eye height over the floor for someone seated.
const SEATED_EYE := 1.2
const PITCH_LIMIT := 80.0
## Degrees per pixel of mouse motion.
const MOUSE_SENSITIVITY := 0.15
## How near the crosshair's ground point must fall to an anchor on the
## floor (a seat, a perch's place) to pick it.
const ANCHOR_PICK := 0.8
## How near the line of sight a person must stand to be looked at.
const PERSON_PICK := 0.5
## How far the crosshair reaches.
const REACH := 40.0

var yaw := 0.0
var pitch := 0.0
## Whether the mouse is captured (Esc releases it).
var captured := false
## Whether the eye sits at a seat aboard a vehicle (see `sit`), rather
## than standing over the avatar on the ground.
var seated := false
## The heading of the vehicle sat in, as of the last `sit`.
var _seat_heading := 0.0
## The player's mouse look sensitivity, a multiple of MOUSE_SENSITIVITY.
var look_scale := 1.0
## Whether moving the mouse up looks down (invert look Y).
var invert_y := false


func _init() -> void:
	name = "FpvCamera"
	fov = 70.0
	near = 0.05
	far = 600.0
	_apply()


## Stands the eye over ground position `p` (metres).
func follow(p: Vector2) -> void:
	seated = false
	position = Vector3(p.x, EYE_HEIGHT, p.y)


## Seat mode: puts the eye at `eye` (metres, already at eye height) aboard
## a vehicle heading `heading_deg` (clockwise from north). While seated
## the view turns as the vehicle does, so where the rider looks stays the
## same way from the seat; the mouse and the stick still look around.
func sit(eye: Vector3, heading_deg: float) -> void:
	if seated:
		var turn := fposmod(heading_deg - _seat_heading + 180.0, 360.0) - 180.0
		if turn != 0.0:
			look(-turn, 0.0)
	seated = true
	_seat_heading = heading_deg
	position = eye


## The yaw that looks along ground direction `dir` (x east, y south).
static func yaw_along(dir: Vector2) -> float:
	return rad_to_deg(atan2(-dir.x, -dir.y))


## Turns the view by the given degrees (positive yaw turns left, positive
## pitch looks up).
func look(d_yaw: float, d_pitch: float) -> void:
	yaw = fposmod(yaw + d_yaw + 180.0, 360.0) - 180.0
	pitch = clampf(pitch + d_pitch, -PITCH_LIMIT, PITCH_LIMIT)
	_apply()


func _apply() -> void:
	rotation_degrees = Vector3(pitch, yaw, 0)


## The way the view faces, flat on the ground, as a unit vector (x, z).
func forward() -> Vector2:
	var r := deg_to_rad(yaw)
	return Vector2(-sin(r), -cos(r))


func handle(event: InputEvent) -> void:
	if captured and event is InputEventMouseMotion:
		var turn: Vector2 = event.relative * MOUSE_SENSITIVITY * look_scale
		look(-turn.x, turn.y if invert_y else -turn.y)


## What the crosshair rests on: {"kind": "anchor" | "building" | "person"
## | "ground" | "none", "id", "point"}; an anchor's also has "index", its
## entry's place in `anchors`. `anchors` are {id, pos: Vector2}, a spot on
## the floor, picked when the crosshair's ground point falls within
## ANCHOR_PICK of it, or {id, boxes: Array[AABB]}, picked where the line of
## sight meets one of its boxes; `people` are {id, pos: Vector2};
## `buildings` are {id, footprint: Rect2, height?}. The nearest along the
## view wins. From inside a building the view reaches no further than its
## walls: ground beyond them is aimed at where the wall stands, and ground
## carries `inside`, the building's ID.
func aim(anchors: Array, buildings: Array, people: Array = []) -> Dictionary:
	var origin := position
	var dir := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0)) * Vector3.FORWARD
	var best := {"kind": "none", "id": "", "point": Vector2.ZERO}
	var best_t := REACH
	var eye := Vector2(origin.x, origin.z)
	var inside := ""
	var walls_t := REACH
	for b in buildings:
		var fp: Rect2 = b["footprint"]
		if fp.has_point(eye):
			inside = b["id"]
			walls_t = minf(walls_t, _exit_t(fp, origin, dir))
	if dir.y < -0.0001:
		var t := minf(-origin.y / dir.y, walls_t)
		if t < best_t:
			var g := origin + dir * t
			var point := Vector2(g.x, g.z)
			best = {"kind": "ground", "id": "", "point": point}
			if inside != "":
				best["inside"] = inside
			best_t = t
			var nearest := ANCHOR_PICK
			for k in anchors.size():
				var a: Dictionary = anchors[k]
				if not a.has("pos"):
					continue
				var d: float = point.distance_to(a["pos"])
				if d < nearest:
					nearest = d
					best = {"kind": "anchor", "id": a["id"], "point": a["pos"], "index": k}
	best_t = minf(best_t, walls_t)
	for b in buildings:
		var fp: Rect2 = b["footprint"]
		# From inside a building its walls are all around: aim at the seats
		# and floor within.
		if fp.has_point(eye):
			continue
		var box := AABB(Vector3(fp.position.x, 0, fp.position.y), Vector3(fp.size.x, float(b.get("height", 6.0)), fp.size.y))
		var hit = box.intersects_ray(origin, dir)
		if hit != null:
			var t: float = (hit - origin).length()
			if t < best_t:
				best_t = t
				best = {"kind": "building", "id": b["id"], "point": Vector2(hit.x, hit.z)}
	# Things standing in the way: the nearest box the line of sight meets.
	for k in anchors.size():
		for box in anchors[k].get("boxes", []):
			var hit = (box as AABB).intersects_ray(origin, dir)
			if hit == null:
				continue
			var t: float = (hit - origin).length()
			if t < best_t:
				best_t = t
				best = {"kind": "anchor", "id": anchors[k]["id"], "point": Vector2(hit.x, hit.z), "index": k}
	# People: whoever stands nearest the line of sight, within a body's
	# width of it, at chest height.
	for person in people:
		var p: Vector2 = person["pos"]
		var chest := Vector3(p.x, 1.2, p.y)
		var t := (chest - origin).dot(dir)
		if t <= 0.0 or t >= best_t:
			continue
		var miss := (origin + dir * t).distance_to(chest)
		if miss < PERSON_PICK * maxf(1.0, t / 8.0):
			best_t = t
			best = {"kind": "person", "id": person["id"], "point": p}
	return best


## How far along the ray from `origin` (inside footprint `fp`) along `dir`
## it leaves the footprint, seen from above.
static func _exit_t(fp: Rect2, origin: Vector3, dir: Vector3) -> float:
	var t := INF
	if dir.x > 0.0:
		t = minf(t, (fp.end.x - origin.x) / dir.x)
	elif dir.x < 0.0:
		t = minf(t, (fp.position.x - origin.x) / dir.x)
	if dir.z > 0.0:
		t = minf(t, (fp.end.y - origin.z) / dir.z)
	elif dir.z < 0.0:
		t = minf(t, (fp.position.y - origin.z) / dir.z)
	return t
