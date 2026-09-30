## When a building opens (roof faded, near walls dropped) so you can see in:
## when your avatar is inside, when the selected person is inside, when the
## camera is inside (with hysteresis, so it never flickers at the edge), or
## when "open all" is on. The same rule for every style pack.
extends RefCounted
class_name CutawayRule

## How far outside a building the camera must go before it closes again.
const HYSTERESIS_CM := 150.0

var _camera_open := {}


## Buildings of a manifest (facilities with a building kind): id -> {rooms,
## rects}.
static func facilities_of(manifest: Dictionary) -> Dictionary:
	var out := {}
	for d in manifest.get("city", {}).get("districts", []):
		for f in d.get("facilities", []):
			if CityGeometry.building_kind(f) == "":
				continue
			var rooms := []
			var rects := []
			for r in f.get("rooms", []):
				rooms.append(r["id"])
				var rc = r.get("rect")
				if rc != null:
					rects.append(Rect2(rc["x"], rc["z"], rc["w"], rc["d"]))
			out[f["id"]] = {"rooms": rooms, "rects": rects}
	return out


static func _distance_outside(p: Vector2, rects: Array) -> float:
	var best := INF
	for r in rects:
		var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
		var dz := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
		best = minf(best, Vector2(dx, dz).length())
	return best


## The set of buildings to show open now, as {facility_id: true}.
## `camera_pos` is the camera's ground position in centimetres, or null.
func update(avatar_room, selected_room, camera_pos, open_all: bool, facilities: Dictionary) -> Dictionary:
	var open := {}
	for id in facilities:
		var f: Dictionary = facilities[id]
		var inside_room: bool = (avatar_room != null and avatar_room in f["rooms"]) \
			or (selected_room != null and selected_room in f["rooms"])
		var camera := false
		if camera_pos != null:
			var d := _distance_outside(camera_pos, f["rects"])
			if d <= 0.0:
				_camera_open[id] = true
			elif d > HYSTERESIS_CM:
				_camera_open.erase(id)
			camera = _camera_open.has(id)
		else:
			_camera_open.erase(id)
		if open_all or inside_room or camera:
			open[id] = true
	return open
