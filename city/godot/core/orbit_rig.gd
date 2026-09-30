## The 3D packs' camera: orbits a target on the ground, with named presets
## (top-down, the sheets' diagonal, and a low street view), mouse orbit and
## zoom, and double-click to re-centre. Behind the title it drifts, circling
## the square; Explore flies it down to where play begins (see `advance`).
extends Node3D
class_name OrbitRig

const PRESETS := ["topdown", "diagonal", "street"]

var camera: Camera3D
var yaw := 32.0
var pitch := -36.0
var distance := 55.0
## The district's rooms in metres, which the diagonal frames.
var bounds := Rect2()
## Everything placed, scenery included, which the top-down frames.
var whole := Rect2()
## Where the street view stands, in metres (the square's centre).
var street_target := Vector3.ZERO
var preset := "diagonal"
## Whether a right-drag is turning the view; `StylePack.end_drag` clears
## it when a screen takes the mouse mid-drag.
var dragging := false
## The player's mouse look sensitivity: how far a right-drag turns the
## view, as a multiple of the usual 0.3 degrees a pixel.
var look_scale := 1.0
## Whether dragging up tilts the view down instead of up (invert look Y).
var invert_y := false

## Degrees the view turns for each pixel of a right-drag, at a look scale
## of one.
const DRAG_DEGREES_PER_PX := 0.3
## The title's drift: one full turn round the square every three minutes.
const DRIFT_DEG_PER_S := 360.0 / 180.0

## Whether the view is circling the square behind the title.
var drifting := false
## A flight under way: where from and to, the distances at either end, and
## how far through its seconds it is. Empty when there is none.
var _flight := {}


func _init() -> void:
	name = "CameraRig"
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 45
	camera.near = 0.1
	camera.far = 600.0
	camera.current = true
	add_child(camera)


## Frames `district` (metres, the rooms) and `all` (with the scenery); the
## street view looks north across `street`.
func frame(district: Rect2, street: Vector3, all := Rect2()) -> void:
	bounds = district
	whole = all if all.size != Vector2.ZERO else district
	street_target = street
	apply_preset(preset)


static func _fit(r: Rect2) -> float:
	# 45° vertical field of view at 16:9: visible height is 0.83 d and width 1.47 d.
	return maxf(r.size.x / 1.47, r.size.y / 0.83)


func apply_preset(name_: String) -> bool:
	match name_:
		"topdown":
			position = Vector3(whole.get_center().x, 0, whole.get_center().y)
			yaw = preset_yaw(name_)
			pitch = -89.0
			distance = preset_distance(name_)
		"diagonal":
			# The sheets' diagonal: from the south-east, looking north-west.
			position = Vector3(bounds.get_center().x, 0, bounds.get_center().y + 2.0)
			yaw = preset_yaw(name_)
			pitch = -36.0
			distance = preset_distance(name_)
		"street":
			# Eye height (1.7 m) on the tram-stop platform, 17 m south of the
			# square's centre, looking north and a little up at the tree.
			position = street_target + Vector3(0, 3.0, 0)
			yaw = preset_yaw(name_)
			pitch = 4.4
			distance = preset_distance(name_)
		_:
			return false
	preset = name_
	camera.fov = 55.0 if name_ == "street" else 45.0
	update()
	return true


func update() -> void:
	rotation_degrees = Vector3(pitch, yaw, 0)
	camera.position = Vector3(0, 0, distance)


## The camera's position over the ground, in centimetres.
func ground_pos() -> Vector2:
	var p := transform * camera.position
	return Vector2(p.x * 100.0, p.z * 100.0)


func ground_hit(screen: Vector2):
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return null
	var t := -origin.y / dir.y
	return origin + dir * t if t > 0 else null


func handle(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = maxf(4.0, distance * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = minf(200.0, distance * 1.1)
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
			var hit = ground_hit(event.position)
			if hit != null:
				position = Vector3(hit.x, 0, hit.z)
		update()
	elif event is InputEventMouseMotion and dragging:
		turn(event.relative * look_scale)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_O:
		apply_preset("diagonal")


## Circles `centre` (metres, on the ground) from now on, at the diagonal
## preset's pitch and distance, as the title's backdrop.
func drift(centre: Vector3) -> void:
	apply_preset("diagonal")
	position = centre
	_flight = {}
	drifting = true
	update()


## Stops the drift where it has got to.
func stop_drift() -> void:
	drifting = false


## Moves the view to look at `target` (metres) from `to_distance`, facing
## `to_yaw` degrees, easing in and out over `seconds`; at 0 it cuts there at
## once. The yaw turns the short way round; the pitch stays.
func fly_to(target: Vector3, to_distance: float, to_yaw: float, seconds: float) -> void:
	drifting = false
	if seconds <= 0.0:
		_flight = {}
		position = target
		distance = to_distance
		yaw = to_yaw
		update()
		return
	_flight = {"from": position, "to": target, "from_distance": distance, "to_distance": to_distance,
		"from_yaw": yaw, "turn": wrapf(to_yaw - yaw, -180.0, 180.0), "seconds": seconds, "elapsed": 0.0}


## Whether a flight is under way.
func flying() -> bool:
	return not _flight.is_empty()


## The distance `preset` frames the district from (the diagonal's by
## default), without moving the view.
## The yaw `preset` looks from (the diagonal's by default): the sheets'
## south-east, straight north from above, or north along the street.
func preset_yaw(name_ := preset) -> float:
	match name_:
		"topdown":
			return 0.0
		"street":
			return -10.0
	return 32.0


func preset_distance(name_ := preset) -> float:
	match name_:
		"topdown":
			return _fit(whole) * 0.98
		"street":
			return 17.0
	return _fit(bounds) * 1.25


## Moves the drift or the flight on by `delta` seconds; the pack calls it
## every frame.
func advance(delta: float) -> void:
	if drifting:
		yaw = fmod(yaw + DRIFT_DEG_PER_S * delta, 360.0)
		update()
	if _flight.is_empty():
		return
	_flight["elapsed"] = minf(_flight["elapsed"] + delta, _flight["seconds"])
	var t: float = smoothstep(0.0, 1.0, _flight["elapsed"] / _flight["seconds"])
	position = (_flight["from"] as Vector3).lerp(_flight["to"], t)
	distance = lerpf(_flight["from_distance"], _flight["to_distance"], t)
	yaw = _flight["from_yaw"] + _flight["turn"] * t
	if _flight["elapsed"] >= _flight["seconds"]:
		_flight = {}
	update()


## Turns and tilts the view as a right-drag of `relative` pixels would,
## before any sensitivity: the mouse scales its drag by `look_scale`, the
## stick by its own sensitivity. `invert_y` flips the tilt either way.
func turn(relative: Vector2) -> void:
	yaw -= relative.x * DRAG_DEGREES_PER_PX
	var tilt := -relative.y if invert_y else relative.y
	pitch = clampf(pitch - tilt * DRAG_DEGREES_PER_PX, -89.0, -3.0)
	update()
