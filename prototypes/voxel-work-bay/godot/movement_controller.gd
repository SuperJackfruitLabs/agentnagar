extends RefCounted
## Deterministic demonstration route. Fixture state never requests travel.
const SEAT := Vector3(0, 0, -0.65)
const PULLED := Vector3(0, 0, -1.30)
const STANDING := Vector3(0, 0, -0.9636965656)
const CORNER := Vector3(1.45, 0, -0.9636965656)
const FLOOR := Vector3(1.45, 0, 1.15)
const SLIDE_SECONDS := 0.65
const TRANSITION_SECONDS := 32.0 / 24.0
# .72 m full stride / (32 frames / 24 fps), authored planted stance.
const WALK_SPEED := 0.54
const TURN_SECONDS := 0.35
var available := true
var reduced_motion := false
var phase := "seated"
var elapsed := 0.0
var actor_position := SEAT
var chair_position := SEAT
var yaw := 0.0
var destination := "seated"
var _steps: Array[Dictionary] = []
var _start := SEAT
var _chair_start := SEAT
var _yaw_start := 0.0

func reset() -> void:
	_steps.clear()
	phase = "seated"
	destination = "seated"
	elapsed = 0
	actor_position = SEAT
	chair_position = SEAT
	yaw = 0

func request_leave() -> bool:
	if not available or phase != "seated": return false
	destination = "away"
	if reduced_motion:
		_snap()
		return true
	_steps = [
		step("pulling chair", SLIDE_SECONDS, PULLED, 0, PULLED),
		step("standing up", TRANSITION_SECONDS, PULLED, 0, PULLED),
		step("turning", TURN_SECONDS, STANDING, PI/2, PULLED),
		step("walking", STANDING.distance_to(CORNER)/WALK_SPEED, CORNER, PI/2, PULLED),
		step("turning", TURN_SECONDS, CORNER, 0, PULLED),
		step("walking", CORNER.distance_to(FLOOR)/WALK_SPEED, FLOOR, 0, PULLED)]
	_next()
	return true

func request_return() -> bool:
	if not available or phase != "away": return false
	destination = "seated"
	if reduced_motion:
		_snap()
		return true
	_steps = [
		step("turning", TURN_SECONDS, FLOOR, PI, PULLED),
		step("walking", FLOOR.distance_to(CORNER)/WALK_SPEED, CORNER, PI, PULLED),
		step("turning", TURN_SECONDS, CORNER, -PI/2, PULLED),
		step("walking", CORNER.distance_to(STANDING)/WALK_SPEED, STANDING, -PI/2, PULLED),
		step("turning", TURN_SECONDS, STANDING, 0, PULLED),
		step("sitting down", TRANSITION_SECONDS, PULLED, 0, PULLED),
		step("pushing chair", SLIDE_SECONDS, SEAT, 0, SEAT)]
	_next()
	return true

func step(label: String, duration: float, point: Vector3, facing: float, chair: Vector3) -> Dictionary:
	return {"phase":label, "duration":duration, "point":point, "yaw":facing, "chair":chair}

func _next() -> void:
	elapsed = 0
	if _steps.is_empty():
		_snap()
		return
	phase = _steps[0].phase
	if phase == "sitting down": actor_position = PULLED
	_start = actor_position
	_chair_start = chair_position
	_yaw_start = yaw

func _snap() -> void:
	_steps.clear()
	phase = destination
	elapsed = 0
	actor_position = SEAT if phase == "seated" else FLOOR
	chair_position = SEAT if phase == "seated" else PULLED
	yaw = 0

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if enabled: _snap()

func advance(delta: float) -> void:
	var remaining := maxf(delta, 0)
	while not _steps.is_empty() and remaining > 0:
		var current := _steps[0]
		var taken := minf(remaining, current.duration - elapsed)
		elapsed += taken
		remaining -= taken
		var fraction: float = clampf(elapsed/current.duration, 0, 1)
		actor_position = _start.lerp(current.point, fraction)
		chair_position = _chair_start.lerp(current.chair, fraction)
		yaw = lerp_angle(_yaw_start, current.yaw, fraction)
		if elapsed >= current.duration - 0.0000001:
			if phase == "standing up": actor_position = STANDING
			_steps.pop_front()
			_next()

func clip() -> String:
	match phase:
		"standing up": return "stand_up"
		"sitting down": return "sit_down"
		"walking": return "walk"
		"away", "turning": return "idle"
		_: return "seated_idle"

func busy() -> bool:
	return not _steps.is_empty()
