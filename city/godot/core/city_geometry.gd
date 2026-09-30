## Geometry every style pack draws the same city from, in metres on the
## ground plane (x east, y = the world's z, south): building footprints and
## their sides with the doors that open onto them, the placements of the
## catalogue's kinds with their footprints and lots, the ground around the
## water, and polylines for streets and fences.
extends RefCounted
class_name CityGeometry

const SIDES := {
	"north": Vector2(0, -1), "south": Vector2(0, 1), "east": Vector2(1, 0), "west": Vector2(-1, 0),
}


static func rect_m(rc: Dictionary) -> Rect2:
	return Rect2(rc["x"] / 100.0, rc["z"] / 100.0, rc["w"] / 100.0, rc["d"] / 100.0)


static func pt_m(p: Dictionary) -> Vector2:
	return Vector2(p["x"] / 100.0, p["z"] / 100.0)


static func _merge(rects: Array) -> Rect2:
	var out := Rect2()
	for r in rects:
		out = r if out.size == Vector2.ZERO else out.merge(r)
	return out


## The building kind a facility is drawn as (its `kind`, a building-class
## kind of the catalogue), or "" for a facility that is no building.
static func building_kind(facility: Dictionary) -> String:
	var kind = facility.get("kind")
	return str(kind) if kind != null else ""


## An interior door's width when it gives none, metres (spec §3).
const INTERIOR_DOOR_WIDTH := 1.0


## Facilities drawn as whole buildings (those with a building kind), each
## with {id, kind, roof, storeys, footprint, rooms, sides, wall}. A side is
## {side, a, b, normal, openings, widths}: a and b run clockwise seen from
## above, openings are the distances from a of doors leading out of the
## building, and widths each one's width. `wall` is the kind's wall
## thickness: the shell stands that far outside the rooms (spec §3).
## `kinds` is the catalogue's kinds by ID (StylePack.kinds()), which give
## each building kind's wall and door width.
static func buildings(manifest: Dictionary, kinds: Dictionary) -> Array:
	var out := []
	for d in manifest.get("city", {}).get("districts", []):
		for f in d.get("facilities", []):
			var kind := building_kind(f)
			if kind == "":
				continue
			var rooms: Array = f.get("rooms", [])
			var ids := rooms.map(func(r): return r["id"])
			var fp := _merge(rooms.filter(func(r): return r.get("rect") != null).map(func(r): return rect_m(r["rect"])))
			var doors := []
			var widths := []
			for r in rooms:
				for door in r.get("doors", []):
					if door.get("pos") != null and not (door["to"] in ids):
						doors.append(pt_m(door["pos"]))
						widths.append(door_width(door, kinds.get(kind, {}), true))
			out.append({
				"id": f["id"], "kind": kind,
				"roof": str(f.get("roof")) if f.get("roof") != null else "flat",
				"storeys": int(f.get("storeys")) if f.get("storeys") != null else 1,
				"footprint": fp, "rooms": rooms, "sides": sides_of(fp, doors, widths),
				"wall": float(kinds.get(kind, {}).get("wall", 25)) / 100.0,
			})
	return out


## A door's walkable width in metres, as the core cuts it (spec §3): its
## own `width`, else the building kind's `door_width` for a door out of
## the building (`exterior`, its catalogue `kind`), else a metre.
static func door_width(door: Dictionary, kind: Dictionary, exterior: bool) -> float:
	if door.get("width") != null:
		return float(door["width"]) / 100.0
	if exterior:
		return float(kind.get("door_width", 200)) / 100.0
	return INTERIOR_DOOR_WIDTH


## The footprint's four sides with the doors (`doors`, points in metres,
## each `widths[k]` wide) that open onto each.
static func sides_of(fp: Rect2, doors: Array, widths: Array) -> Array:
	var x0 := fp.position.x
	var z0 := fp.position.y
	var x1 := fp.end.x
	var z1 := fp.end.y
	var raw := [
		["north", Vector2(x0, z0), Vector2(x1, z0)],
		["east", Vector2(x1, z0), Vector2(x1, z1)],
		["south", Vector2(x1, z1), Vector2(x0, z1)],
		["west", Vector2(x0, z1), Vector2(x0, z0)],
	]
	var out := []
	for s in raw:
		var a: Vector2 = s[1]
		var b: Vector2 = s[2]
		var along := (b - a).normalized()
		var found := []
		for k in doors.size():
			var p: Vector2 = doors[k]
			var t: float = (p - a).dot(along)
			if (p - (a + along * t)).length() < 0.05 and t > 0.0 and t < a.distance_to(b):
				found.append([t, float(widths[k])])
		found.sort()
		out.append({"side": s[0], "a": a, "b": b, "normal": SIDES[s[0]],
			"openings": found.map(func(o): return o[0]), "widths": found.map(func(o): return o[1])})
	return out


## True when the segment a-b lies along the footprint's outline.
static func on_perimeter(a: Vector2, b: Vector2, fp: Rect2) -> bool:
	const E := 0.01
	if absf(a.y - b.y) < E:
		return absf(a.y - fp.position.y) < E or absf(a.y - fp.end.y) < E
	if absf(a.x - b.x) < E:
		return absf(a.x - fp.position.x) < E or absf(a.x - fp.end.x) < E
	return false


## Every placement of the manifest's districts, in ID order (the order the
## core applies them in): {id, kind, pos (metres), facing (degrees
## clockwise from north), size (a sized kind's lot, in metres; ZERO for
## any other), level}.
static func placements(manifest: Dictionary) -> Array:
	var out := []
	for d in manifest.get("city", {}).get("districts", []):
		for p in d.get("placements", []):
			var size = p.get("size")
			out.append({
				"id": str(p["id"]), "kind": str(p["kind"]), "pos": pt_m(p["at"]),
				"facing": float(p["facing"]) if p.get("facing") != null else 0.0,
				"size": Vector2(size["w"] / 100.0, size["d"] / 100.0) if size is Dictionary else Vector2.ZERO,
				"level": int(p["level"]) if p.get("level") != null else 0,
			})
	out.sort_custom(func(a, b): return a["id"] < b["id"])
	return out


## A sized placement's lot, in metres: its size centred on its point.
static func lot(placement: Dictionary) -> Rect2:
	var size: Vector2 = placement["size"]
	return Rect2(placement["pos"] - size / 2.0, size)


## The rects of `kind`'s footprint (a catalogue kind; its discs left out)
## where `placement` stands, in metres: each turned by the placement's
## facing about its point, as the core turns them (city-core
## footprint.rs), and bounded. Exact at right angles, which is how every
## rect-footed kind is placed today.
static func footprint_rects(kind: Dictionary, placement: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var turn := deg_to_rad(float(placement.get("facing", 0.0)))
	var sin_t := snappedf(sin(turn), 1e-9)
	var cos_t := snappedf(cos(turn), 1e-9)
	var at: Vector2 = placement["pos"]
	for shape in kind.get("footprint", []):
		if not shape.has("w"):
			continue
		var box := Rect2()
		var first := true
		for corner in [Vector2(shape["x"], shape["z"]), Vector2(shape["x"] + shape["w"], shape["z"]),
				Vector2(shape["x"], shape["z"] + shape["d"]), Vector2(shape["x"] + shape["w"], shape["z"] + shape["d"])]:
			var p: Vector2 = at + Vector2(corner.x * cos_t - corner.y * sin_t, corner.x * sin_t + corner.y * cos_t) / 100.0
			box = Rect2(p, Vector2.ZERO) if first else box.expand(p)
			first = false
		out.append(box)
	return out


## The rectangle (metres) that something filling the axis-aligned
## footprint rectangle `r` (metres) draws in the walking band so that it
## comes within the body clearance of every cell the grid blocks round it
## and of none it leaves walkable: an edge the centres of `grid`'s blocked
## cells lie beyond (the core blocks a cell whose centre is 10 cm or less
## outside a footprint) moves out to 2.5 cm past them. A footprint's edges
## fall anywhere across the 25 cm cells, so a thing drawn exactly on its
## footprint can leave a blocked cell at a corner, 8 cm beyond both edges,
## more than 10 cm from it; the next cells out lie 25 cm further, so the
## grown edge stays clear of them.
static func drawn_rect(grid: NavQuery, r: Rect2) -> Rect2:
	var lo := Vector2.ZERO
	var hi := Vector2.ZERO
	for axis in 2:
		var o := float(grid.origin[axis]) + NavQuery.CELL / 2
		var a: float = r.position[axis] * 100.0
		var b: float = r.end[axis] * 100.0
		var first := o + NavQuery.CELL * ceilf((a - 10.0 - o) / NavQuery.CELL - 1e-6)
		var last := o + NavQuery.CELL * floorf((b + 10.0 - o) / NavQuery.CELL + 1e-6)
		lo[axis] = minf(a, first - 2.5) / 100.0
		hi[axis] = maxf(b, last + 2.5) / 100.0
	return Rect2(lo, hi - lo)


## A scenery item's points in metres (a bridge's two ends, a street's line).
static func scenery_points(item: Dictionary) -> Array:
	match str(item.get("kind", "")):
		"bridge":
			return [pt_m(item["from"]), pt_m(item["to"])]
		"street", "fence":
			return item.get("points", []).map(func(p): return pt_m(p))
	return []


## The point on a street's centre line (the manifest's `street` scenery)
## nearest `p` (metres); Vector2.INF with no street.
static func nearest_street(manifest: Dictionary, p: Vector2) -> Vector2:
	var best := Vector2.INF
	for item in manifest.get("scenery", []):
		if str(item.get("kind", "")) != "street":
			continue
		var pts := scenery_points(item)
		for k in range(1, pts.size()):
			var q := Geometry2D.get_closest_point_to_segment(p, pts[k - 1], pts[k])
			if best == Vector2.INF or p.distance_squared_to(q) < p.distance_squared_to(best):
				best = q
	return best


## The ground area an item covers, in metres.
static func scenery_bounds(item: Dictionary) -> Rect2:
	if item.has("rect"):
		return rect_m(item["rect"])
	var pts := scenery_points(item)
	if pts.is_empty():
		return Rect2()
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r.grow(float(item.get("width", 0)) / 200.0)


## The rooms a pack draws: every room with a floor but open ground (the
## "ground" template), which is walked but not drawn, since the scenery
## beneath it is its floor.
static func drawn_rooms(manifest: Dictionary) -> Array:
	var out := []
	for d in manifest.get("city", {}).get("districts", []):
		for f in d.get("facilities", []):
			for r in f.get("rooms", []):
				if r.get("rect") != null and str(r.get("template", "")) != "ground":
					out.append(r)
	return out


## The rooms the opening views frame: the drawn rooms but the transit
## lines' platforms, so a stop out along a line never widens them (the
## top-down view still frames everything, through `extent`).
static func framed_rooms(manifest: Dictionary) -> Array:
	var platforms := {}
	for line in manifest.get("lines", []):
		for stop in line.get("stops", []):
			for room in stop.get("platforms", []):
				platforms[room] = true
	return drawn_rooms(manifest).filter(func(r): return not platforms.has(r["id"]))


## Everything the manifest lays out: rooms, the surfaces and edges of the
## scenery (water, streets, bridges, fences) and the block lots. Planting
## and street furniture stand within it or on the lawns beyond, which
## never widen it.
static func extent(manifest: Dictionary) -> Rect2:
	var rects := []
	for d in manifest.get("city", {}).get("districts", []):
		for f in d.get("facilities", []):
			for r in f.get("rooms", []):
				if r.get("rect") != null:
					rects.append(rect_m(r["rect"]))
	for s in manifest.get("scenery", []):
		var b := scenery_bounds(s)
		if b.size != Vector2.ZERO or b.position != Vector2.ZERO:
			rects.append(b)
	for p in placements(manifest):
		if p["size"] != Vector2.ZERO:
			rects.append(lot(p))
	return _merge(rects)


## `r` without `hole`, as up to four rectangles.
static func subtract(r: Rect2, hole: Rect2) -> Array:
	if not r.intersects(hole):
		return [r]
	var h := r.intersection(hole)
	var out := []
	if h.position.y > r.position.y:
		out.append(Rect2(r.position.x, r.position.y, r.size.x, h.position.y - r.position.y))
	if h.end.y < r.end.y:
		out.append(Rect2(r.position.x, h.end.y, r.size.x, r.end.y - h.end.y))
	if h.position.x > r.position.x:
		out.append(Rect2(r.position.x, h.position.y, h.position.x - r.position.x, h.size.y))
	if h.end.x < r.end.x:
		out.append(Rect2(h.end.x, h.position.y, r.end.x - h.end.x, h.size.y))
	return out


## Land: the extent grown by `margin`, less every body of water.
static func ground(manifest: Dictionary, margin: float) -> Array:
	var parts := [extent(manifest).grow(margin)]
	for s in manifest.get("scenery", []):
		if s.get("kind") == "water":
			var hole := rect_m(s["rect"])
			var next := []
			for p in parts:
				next.append_array(subtract(p, hole))
			parts = next
	return parts


static func length(points: Array) -> float:
	var total := 0.0
	for k in range(1, points.size()):
		total += points[k - 1].distance_to(points[k])
	return total


## The point `d` metres along a polyline, clamped to it: {pos, dir}.
static func point_at(points: Array, d: float) -> Dictionary:
	if points.size() < 2:
		return {"pos": points[0] if points.size() == 1 else Vector2.ZERO, "dir": Vector2.RIGHT}
	var left := maxf(d, 0.0)
	for k in range(1, points.size()):
		var a: Vector2 = points[k - 1]
		var b: Vector2 = points[k]
		var seg := a.distance_to(b)
		if left <= seg or k == points.size() - 1:
			var t := clampf(left / seg, 0.0, 1.0) if seg > 0.0 else 0.0
			return {"pos": a.lerp(b, t), "dir": (b - a).normalized()}
		left -= seg
	return {"pos": points[-1], "dir": Vector2.RIGHT}


## Points every `spacing` metres along a polyline, from its start to its end.
static func along(points: Array, spacing: float) -> Array:
	var out := []
	var total := length(points)
	var n := int(floor(total / spacing + 0.001))
	for k in n + 1:
		out.append(point_at(points, k * spacing))
	return out


## A fence along `points` (metres) laid as modules of about `module`
## metres: {modules: [{centre, dir, length}], posts: [Vector2]}. Each run
## gets a whole number of modules, stretched to fit it exactly; a module's
## own post stands at its start (toward the run's start), so corners need
## nothing more, and a post closes each open end of the fence.
static func fence(points: Array, module: float) -> Dictionary:
	var modules := []
	for k in range(1, points.size()):
		var a: Vector2 = points[k - 1]
		var b: Vector2 = points[k]
		var run := a.distance_to(b)
		if run <= 0.0:
			continue
		var n := maxi(1, roundi(run / module))
		var dir := (b - a) / run
		for i in n:
			modules.append({"centre": a + dir * run * (i + 0.5) / n, "dir": dir, "length": run / n})
	var posts := []
	if points.size() >= 2 and points[0] != points[-1]:
		posts = [points[0], points[-1]]
	return {"modules": modules, "posts": posts}


## How high a bridge's deck lifts a point `p` (metres) that stands on
## one of `bridges` ({a, b, width}): `deck` metres, eased up over `ramp`
## metres from each end (at once for no ramp); 0 off every bridge.
static func deck_height(bridges: Array, p: Vector2, deck: float, ramp: float) -> float:
	for br in bridges:
		var a: Vector2 = br["a"]
		var run := a.distance_to(br["b"])
		if run <= 0.0:
			continue
		var dir: Vector2 = (br["b"] - a) / run
		var t := (p - a).dot(dir)
		if t < 0.0 or t > run or absf((p - a).dot(Vector2(-dir.y, dir.x))) > br["width"] / 2.0:
			continue
		return deck if ramp <= 0.0 else deck * clampf(minf(t, run - t) / ramp, 0.0, 1.0)
	return 0.0


## The way from `p_cm` (centimetres) to the nearest point of any transit
## line's tracks, as a unit ground direction; ZERO with no track.
static func toward_track(manifest: Dictionary, p_cm: Vector2) -> Vector2:
	var best := INF
	var out := Vector2.ZERO
	for line in manifest.get("lines", []):
		for index in line.get("tracks", []).size():
			var track := track_points(line, index)
			for k in range(1, track.size()):
				var q := Geometry2D.get_closest_point_to_segment(p_cm, track[k - 1], track[k])
				var d := p_cm.distance_to(q)
				if d < best and d > 0.0:
					best = d
					out = (q - p_cm) / d
	return out


## `p` (metres) moved just far enough to keep `clear` metres from every
## wall in `walls` ({a, b, half}: a solid run from a to b, `half` metres
## thick either side): pushed straight out from the nearest point of each
## run it is too close to. A few passes settle corners and door jambs.
static func clear_of_walls(p: Vector2, walls: Array, clear: float) -> Vector2:
	for pass_ in 3:
		var moved := false
		for w in walls:
			var a: Vector2 = w["a"]
			var ab: Vector2 = w["b"] - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
			var q := a + ab * t
			var need: float = w["half"] + clear
			var d := p.distance_to(q)
			if d >= need:
				continue
			var out := (p - q) / d if d > 1e-6 else Vector2(-ab.y, ab.x).normalized()
			p = q + out * need
			moved = true
		if not moved:
			break
	return p


## Whether `rect_cm` (centimetres), grown by `margin_cm`, holds no walkable
## cell's centre on `nav`: ground a thing may stand on without anyone
## walking through it. The rectangle holds its minimum edges and not its
## maximum, as the core's footprints do.
static func clear_of_walkable(nav: NavQuery, rect_cm: Rect2i, margin_cm := 10) -> bool:
	var grown := rect_cm.grow(margin_cm)
	var first := nav.cell_of(Vector2(grown.position))
	var last := nav.cell_of(Vector2(grown.end))
	for j in range(maxi(0, first.y), mini(nav.rows, last.y + 1)):
		for i in range(maxi(0, first.x), mini(nav.cols, last.x + 1)):
			var c := Vector2i(i, j)
			if nav.walkable(c) and grown.has_point(Vector2i(nav.centre(c))):
				return false
	return true


## A block split along its longer side into lots about `target` metres wide.
static func lots(r: Rect2, target: float) -> Array:
	var long_x := r.size.x >= r.size.y
	var span := r.size.x if long_x else r.size.y
	var n := maxi(1, int(round(span / target)))
	var out := []
	for k in n:
		if long_x:
			out.append(Rect2(r.position.x + span / n * k, r.position.y, span / n, r.size.y))
		else:
			out.append(Rect2(r.position.x, r.position.y + span / n * k, r.size.x, span / n))
	return out


# ---- Transit lines ----
# A line's tracks, vehicles and rider slots, laid as the core lays them
# (city-core index.rs and project.rs), in centimetres: the core's integer
# rounding aside, a vehicle drawn here stands where the projection says.

## Rows of slots a rider may stand in rather than sit, within this many
## centimetres of a door.
const DOOR_ROW_CM := 65


## The line `id` in the manifest, or an empty dictionary.
static func line_of(manifest: Dictionary, id: String) -> Dictionary:
	for line in manifest.get("lines", []):
		if str(line.get("id", "")) == id:
			return line
	return {}


## The track of `line` for direction `index` (0 east, 1 west): its
## centreline offset by `tracks[index]` centimetres, south-positive, each
## end along its own segment's perpendicular and each bend mitred (capped
## at four times the offset from the vertex, as the core caps it).
static func track_points(line: Dictionary, index: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for p in line.get("points", []):
		points.append(Vector2(float(p["x"]), float(p["z"])))
	var tracks: Array = line.get("tracks", [])
	var offset := float(tracks[index]) if index < tracks.size() else 0.0
	var n := points.size()
	if n < 2 or offset == 0.0:
		return points
	var perp := func(a: Vector2, b: Vector2) -> Vector2:
		var d := b - a
		return Vector2(-d.y, d.x).normalized() * offset if d != Vector2.ZERO else Vector2.ZERO
	var out: Array[Vector2] = []
	for i in n:
		var shift: Vector2
		if i == 0:
			shift = perp.call(points[0], points[1])
		elif i == n - 1:
			shift = perp.call(points[i - 1], points[i])
		else:
			var in_off: Vector2 = perp.call(points[i - 1], points[i])
			var out_off: Vector2 = perp.call(points[i], points[i + 1])
			var d_in := points[i] - points[i - 1]
			var d_out := points[i + 1] - points[i]
			var denom := d_in.cross(d_out)
			if denom == 0.0:
				shift = in_off
			else:
				shift = in_off + d_in * ((out_off - in_off).cross(d_out) / denom)
				var cap := 4.0 * absf(offset)
				if shift.length() > cap:
					shift = shift.normalized() * cap
		out.append(points[i] + shift)
	return out


## The point `along` centimetres from a track's first point, carried
## straight on past either end along its end segment (a vehicle part way
## through a portal is drawn where it is).
static func point_along(track: Array, along: float) -> Vector2:
	var n := track.size()
	if n == 0:
		return Vector2.ZERO
	if n == 1:
		return track[0]
	if along < 0.0:
		return track[0] + (track[1] - track[0]).normalized() * along
	var left := along
	for k in range(1, n):
		var seg: float = track[k - 1].distance_to(track[k])
		if left <= seg or k == n - 1:
			return track[k - 1] + (track[k] - track[k - 1]).normalized() * left if seg > 0.0 else track[k]
		left -= seg
	return track[n - 1]


## How far `point` (cm) lies inside the nearer end (portal) of `track`,
## measured along the track's end segments (negative beyond the portal):
## the trams fade out as their middles near a portal.
static func inside_portals(track: Array, point: Vector2) -> float:
	var n := track.size()
	if n < 2:
		return INF
	var into_start: Vector2 = (track[1] - track[0]).normalized()
	var into_end: Vector2 = (track[n - 2] - track[n - 1]).normalized()
	return minf((point - track[0]).dot(into_start), (point - track[n - 1]).dot(into_end))


## Which side of a vehicle at `from` running along `travel` (ground
## directions, x east and y south) the point `at` lies: 1 on its left, -1
## on its right, 0 straight ahead or behind. The one measure of a
## platform's side, for the doors (platform_side) and for the first
## person's view out (TramTimes.platform_side).
static func side_of(at: Vector2, from: Vector2, travel: Vector2) -> int:
	var left := Vector2(travel.y, -travel.x)
	var side := (at - from).dot(left)
	return 1 if side > 0.0 else (-1 if side < 0.0 else 0)


## Which side of vehicle `view` its stop's platform lies on: 1 on its left
## (the way it runs), -1 on its right, 0 when it stands at no stop or the
## side can't be told.
static func platform_side(manifest: Dictionary, view: Dictionary) -> int:
	var line := line_of(manifest, str(view.get("line", "")))
	var stop_id = view.get("stop")
	if line.is_empty() or stop_id == null:
		return 0
	var index := 0 if str(view.get("direction", "east")) == "east" else 1
	for stop in line.get("stops", []):
		if str(stop.get("id", "")) != str(stop_id):
			continue
		var platforms: Array = stop.get("platforms", [])
		if index >= platforms.size():
			return 0
		var room := room_of(manifest, str(platforms[index]))
		if room.is_empty() or room.get("rect") == null:
			return 0
		var r: Dictionary = room["rect"]
		var centre := Vector2(float(r["x"]) + float(r["w"]) / 2.0, float(r["z"]) + float(r["d"]) / 2.0)
		var heading := deg_to_rad(float(view.get("heading", 90)))
		var travel := Vector2(sin(heading), -cos(heading))
		var front := Vector2(float(view.get("pos", {}).get("x", 0)), float(view.get("pos", {}).get("z", 0)))
		return side_of(centre, front, travel)
	return 0


## The room `id` of the manifest's districts, or an empty dictionary.
static func room_of(manifest: Dictionary, id: String) -> Dictionary:
	for d in manifest.get("city", {}).get("districts", []):
		for f in d.get("facilities", []):
			for r in f.get("rooms", []):
				if str(r.get("id", "")) == id:
					return r
	return {}


## Where slot `slot` sits along a vehicle, in centimetres behind its front:
## the middle of its row, two slots a row and `capacity / 2` rows (rounded
## up), front row first; a rider with no slot (null) rides in the middle.
static func slot_along(vehicle: Dictionary, slot) -> int:
	var length := int(vehicle.get("length", 0))
	if slot == null:
		return length / 2
	var rows := maxi((int(vehicle.get("capacity", 0)) + 1) / 2, 1)
	var row := mini(int(slot) / 2, rows - 1)
	return (2 * row + 1) * length / (2 * rows)


## Slot `slot`'s place in a vehicle's own frame, in centimetres: x ahead
## of its front (so negative), y to the left of the way it runs. Even
## slots sit 50 cm left of the middle, odd ones 50 cm right, as the core
## draws them; a rider with no slot rides in the middle.
static func slot_local(vehicle: Dictionary, slot) -> Vector2:
	var across := 0.0 if slot == null else (50.0 if int(slot) % 2 == 0 else -50.0)
	return Vector2(-slot_along(vehicle, slot), across)


## Whether a rider in `slot` is seated: every row but those beside a door,
## where riders stand (and one with no slot stands in the aisle).
static func slot_seated(vehicle: Dictionary, slot) -> bool:
	if slot == null:
		return false
	var along := slot_along(vehicle, slot)
	for door in vehicle.get("doors", []):
		if absi(along - int(door)) <= DOOR_ROW_CM:
			return false
	return true
