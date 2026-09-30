## Interpolates each walker through one tick. A track is where the walker
## was and the cells it actually crossed last tick (its trail), so movement
## is replayed truthfully one tick behind and a held-up walker stands still.
## `sample(t)` is the point a fraction `t` of the way along, by distance.
## Positions are ground-plane centimetres as Vector2(x, z).
##
## A vehicle's track is the stretch of its line's track its front ran last
## tick (its trail of `along` values), bends and all, so it is replayed
## along the rails rather than across a corner.
extends RefCounted
class_name Motion

var _tracks := {}


static func point(p) -> Vector2:
	if p is Dictionary:
		return Vector2(float(p.get("x", 0)), float(p.get("z", 0)))
	return p


func set_track(id, pos, trail: Array) -> void:
	var pts: Array[Vector2] = [point(pos)]
	for p in trail:
		pts.append(point(p))
	_set_points(id, pts)


## Sets vehicle `id`'s track: along `track` (its line's track, in cm) from
## the first `along` of `trail` through each after it, ending exactly at
## `pos`, where the projection has its front. With fewer than two
## `along`s it stands at `pos`.
func set_vehicle_track(id, track: Array, trail: Array, pos) -> void:
	if trail.size() < 2 or track.size() < 2:
		set_track(id, pos, [])
		return
	var pts: Array[Vector2] = [CityGeometry.point_along(track, float(trail[0]))]
	var lengths := [0.0]
	for k in range(1, track.size()):
		lengths.append(lengths[k - 1] + track[k - 1].distance_to(track[k]))
	for k in range(1, trail.size()):
		var a := float(trail[k - 1])
		var b := float(trail[k])
		# The bends passed on the way, in the order they are passed.
		var bends := range(1, track.size() - 1).filter(func(i): return lengths[i] > minf(a, b) and lengths[i] < maxf(a, b))
		if b < a:
			bends.reverse()
		for i in bends:
			pts.append(track[i])
		pts.append(CityGeometry.point_along(track, b))
	pts[-1] = point(pos)
	_set_points(id, pts)


func _set_points(id, pts: Array[Vector2]) -> void:
	var lengths: Array[float] = []
	var total := 0.0
	for k in range(1, pts.size()):
		var d := pts[k - 1].distance_to(pts[k])
		lengths.append(d)
		total += d
	_tracks[id] = {"points": pts, "lengths": lengths, "total": total}


func has(id) -> bool:
	return _tracks.has(id)


func clear(id) -> void:
	_tracks.erase(id)


## The ground `id`'s track covers in its tick, in centimetres (0 when
## still or unknown): someone is shown walking while it is above zero.
func pace(id) -> float:
	return float(_tracks[id]["total"]) if _tracks.has(id) else 0.0


## {pos: Vector2, dir: Vector2} at fraction `t` (0..1) of this tick.
func sample(id, t: float) -> Dictionary:
	if not _tracks.has(id):
		return {"pos": Vector2.ZERO, "dir": Vector2.ZERO}
	var tr: Dictionary = _tracks[id]
	var pts: Array[Vector2] = tr["points"]
	if pts.size() == 1 or tr["total"] <= 0.0:
		return {"pos": pts[0], "dir": Vector2.ZERO}
	var target: float = clampf(t, 0.0, 1.0) * tr["total"]
	var lengths: Array[float] = tr["lengths"]
	for k in lengths.size():
		var seg := lengths[k]
		if target <= seg or k == lengths.size() - 1:
			var f := 0.0 if seg <= 0.0 else minf(target / seg, 1.0)
			var a := pts[k]
			var b := pts[k + 1]
			return {"pos": a.lerp(b, f), "dir": (b - a).normalized()}
		target -= seg
	return {"pos": pts[-1], "dir": Vector2.ZERO}
