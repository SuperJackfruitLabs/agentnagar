## Owns the city world and steps it in real time: one tick per second at 1x,
## faster at 2x, 4x or 8x. Emits the viewer's projection after every tick.
extends Node
class_name WorldDriver

signal projected(p: Dictionary)
## Just before each tick is stepped: the moment live input for it is sent.
signal about_to_step

const SPEEDS := [1, 2, 4, 8]

var world
var viewer := "public"
var operator := false
var speed := 1
var paused := false
## How far through the current tick we are, 0 to 1; motion uses it.
var tick_time := 0.0
## In play (frame), a tick is stepped on the frame it falls due and
## projected on the next, so no one frame carries both: the stepped tick's
## projection waits here, and `staged` is true while it is handed on.
var _due_json := ""
var _pending := false
var staged := false
## Overridable for tests.
var class_exists := func(n: String) -> bool: return ClassDB.class_exists(n)


func start(manifest_json: String, feed_jsonl: String, seed: int, crowd: int, allow_operator: bool) -> Dictionary:
	if not class_exists.call("CityWorld"):
		return {"ok": false, "error": "extension-missing"}
	world = ClassDB.instantiate("CityWorld")
	operator = allow_operator
	world.set_operator(allow_operator)
	var r = JSON.parse_string(world.load(manifest_json, feed_jsonl, seed, crowd))
	if not r is Dictionary or not r.get("ok", false):
		world = null
		return r if r is Dictionary else {"ok": false, "error": "load failed"}
	tick_time = 0.0
	project()
	return {"ok": true}


func viewers() -> Array:
	return ["public", "person:asha"] + (["operator"] if operator else [])


func project() -> void:
	if world == null:
		return
	var p = JSON.parse_string(world.project_json(viewer))
	if p is Dictionary and not p.has("error"):
		projected.emit(p)


func set_viewer(v: String) -> bool:
	if v == "operator" and not operator:
		return false
	# The old viewer's projection still on its way is no longer wanted: the
	# new viewer's, projected now, has the same tick.
	_pending = false
	viewer = v
	project()
	return true


func set_speed(x: int) -> void:
	if x in SPEEDS:
		speed = x


func pause() -> void:
	paused = true


func resume() -> void:
	paused = false


func step_once() -> void:
	if world == null:
		return
	if _pending:
		_flush()
	about_to_step.emit()
	world.step()
	tick_time = 0.0
	project()


## Advances real time by `delta` seconds, stepping whole ticks as they pass.
func advance(delta: float) -> void:
	if paused or world == null:
		return
	tick_time += delta * speed
	while tick_time >= 1.0:
		tick_time -= 1.0
		about_to_step.emit()
		world.step()
		project()


## Frames shorter than this share of a tick land a tick over several of
## them (walkers hold for those frames); longer ones land it at once, since
## holding would stutter them and a whole tick then fits a frame's budget.
const STAGE_BELOW := 0.005


## A frame of play: projects the tick stepped last frame, then steps any
## tick now due (each earlier one of several due at once projected first).
func frame(delta: float) -> void:
	if _pending:
		_flush()
	if paused or world == null:
		return
	tick_time += delta * speed
	var stage := delta * speed < STAGE_BELOW
	while tick_time >= 1.0:
		tick_time -= 1.0
		if _pending:
			_flush()
		about_to_step.emit()
		world.step()
		if stage:
			_due_json = world.project_json(viewer)
			_pending = true
		else:
			project()


func _flush() -> void:
	_pending = false
	var p = JSON.parse_string(_due_json)
	if p is Dictionary and not p.has("error"):
		staged = true
		projected.emit(p)
		staged = false


## Where in the tick the scene is shown: its end while a stepped tick's
## projection is still on its way, so walkers hold rather than jump back.
func shown_time() -> float:
	return 1.0 if _pending else tick_time


func _process(delta: float) -> void:
	frame(delta)
