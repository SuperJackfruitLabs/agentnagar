## Pixel-art rain: short slanted streaks (four pixels) on the style's pixel grid (one
## world pixel wide, at the camera's whole-number zoom), falling over a
## light darkening of the scene, drawn over the world and under the HUD.
extends CanvasLayer

## Streaks on screen at full rain, per million screen pixels.
const DENSITY := 700.0
## How far a streak falls per second, in world pixels.
const FALL := 420.0

var amount := 0.0
## The share of DENSITY drawn: a quarter in calm mode.
var density := 1.0
var zoom := 1
var colour := Color("#B8C8DC")
var _drops := []
var _shade: ColorRect
var _canvas: Node2D


func _init() -> void:
	name = "Rain"
	layer = 5
	visible = false
	_shade = ColorRect.new()
	_shade.color = Color(0.1, 0.12, 0.2, 0.0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_drops)
	add_child(_canvas)


func set_amount(a: float) -> void:
	amount = clampf(a, 0.0, 1.0)
	visible = amount > 0.001
	_shade.color.a = 0.25 * amount


func _process(delta: float) -> void:
	if not visible:
		return
	var size := get_viewport().get_visible_rect().size
	var want := int(DENSITY * density * amount * size.x * size.y / 1e6)
	while _drops.size() < want:
		_drops.append(Vector2(randf() * size.x, randf() * size.y))
	if _drops.size() > want:
		_drops.resize(want)
	var step := FALL * zoom * delta
	for k in _drops.size():
		var d: Vector2 = _drops[k] + Vector2(step * 0.25, step)
		if d.y > size.y:
			d = Vector2(randf() * size.x, -8.0 * zoom)
		_drops[k] = d
	_canvas.queue_redraw()


## A streak's pixels, slanting down and a little east.
const STREAK: Array[Vector2] = [Vector2(0, 0), Vector2(0, 1), Vector2(1, 2), Vector2(1, 3)]


func _draw_drops() -> void:
	var z := float(zoom)
	for d: Vector2 in _drops:
		# Snapped to the world's pixel grid.
		var p: Vector2 = (d / z).floor() * z
		for o in STREAK:
			_canvas.draw_rect(Rect2(p + o * z, Vector2(z, z)), colour)
