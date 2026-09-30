## The local player's "you" marker, made for any style pack: a ring decal
## on the ground round the avatar's feet in 3D, and an outlined arrow over
## its head in 2D. A pack picks the colours and size that suit its art.
extends RefCounted
class_name PlayerMarker

## The ring's textures, drawn once: an anti-aliased band near the edge,
## as colour with alpha, and as light that is dark off the band.
static var _ring_albedo: ImageTexture
static var _ring_glow: ImageTexture


## A ring `radius_m` metres out from the feet, projected onto whatever
## floor lies within a quarter metre of them (so it sits on raised floors
## too), glowing faintly at night.
static func ring(colour: Color, radius_m := 0.45) -> Node3D:
	_draw_ring()
	var decal := Decal.new()
	decal.size = Vector3(radius_m * 2.0, 0.5, radius_m * 2.0)
	decal.texture_albedo = _ring_albedo
	decal.texture_emission = _ring_glow
	decal.emission_energy = 0.6
	decal.modulate = colour
	decal.upper_fade = 0.5
	decal.lower_fade = 0.3
	return decal


## An arrow pointing down at the head, its tip `tip_y` pixels above the
## feet, filled with `fill` and outlined in `outline`, on whole pixels.
static func arrow(fill: Color, outline: Color, tip_y := -28) -> Node2D:
	var root := Node2D.new()
	var edge := Polygon2D.new()
	edge.polygon = PackedVector2Array([Vector2(-5, tip_y - 7), Vector2(5, tip_y - 7), Vector2(0, tip_y + 1)])
	edge.color = outline
	root.add_child(edge)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-3, tip_y - 6), Vector2(3, tip_y - 6), Vector2(0, tip_y - 1)])
	body.color = fill
	root.add_child(body)
	return root


static func _draw_ring() -> void:
	if _ring_albedo != null:
		return
	const SIZE := 64
	var albedo := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var glow := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var r := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(SIZE, SIZE) / 2.0) / (SIZE / 2.0)
			# A band from 0.72 to 0.96 of the radius, softened over a pixel.
			var a := clampf(minf((r - 0.72) * SIZE / 2.0, (0.96 - r) * SIZE / 2.0), 0.0, 1.0)
			albedo.set_pixel(x, y, Color(1, 1, 1, a))
			glow.set_pixel(x, y, Color(a, a, a, 1))
	_ring_albedo = ImageTexture.create_from_image(albedo)
	_ring_glow = ImageTexture.create_from_image(glow)
