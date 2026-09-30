## When the next tram comes, for the HUD's countdown and the map's card.
## For a stop and a direction it counts the ticks until a tram stands
## there with its doors open, from the vehicles the viewer sees and the
## line's timetable, the way the core estimates a catch (transit.rs
## `catch_tick`): a tram on its way runs at its timetable speed and stands
## a dwell at each stop between; with none on the way, the next one the
## timetable sends in from the portal. It also finds the stop a platform
## room belongs to, names stops, and says which side of a tram a stop's
## platform is on. Holds no nodes. Positions are centimetres.
extends RefCounted
class_name TramTimes

## Directions by index, as the lines list their tracks and platforms.
const DIRECTIONS := ["east", "west"]
## The core's cell: a timetable's speed is in cells a tick.
const CELL_CM := 25

## Line id -> the line, from the layout.
var lines := {}
## The latest projection's tick and vehicles.
var tick := 0
var vehicles: Array = []
## Ticks a real second: the driver's speed, or 0 while paused.
var speed := 1.0
## Platform room id -> {line, stop, direction (index)}.
var _platforms := {}
## Platform room id -> its rectangle.
var _rects := {}
## Vehicle id -> the tick its doors were first seen open, while they are.
var _opened := {}


## The lines of a district layout (the manifest, parsed), with their stops'
## platform rooms.
static func from_layout(layout: Dictionary) -> TramTimes:
	var t := TramTimes.new()
	for line in layout.get("lines", []):
		t.lines[line["id"]] = line
		for stop in line.get("stops", []):
			var platforms: Array = stop.get("platforms", [])
			for i in platforms.size():
				t._platforms[platforms[i]] = {"line": line["id"], "stop": stop["id"], "direction": i}
	for d in layout.get("city", {}).get("districts", []):
		for f in d.get("facilities", []):
			for r in f.get("rooms", []):
				if t._platforms.has(r["id"]) and r.get("rect") != null:
					var rc: Dictionary = r["rect"]
					t._rects[r["id"]] = Rect2(float(rc["x"]), float(rc["z"]), float(rc["w"]), float(rc["d"]))
	return t


## Takes in a projection: its tick and vehicles, and when each open door
## was first seen open (a tram seen first mid-dwell counts from then).
func observe(p: Dictionary) -> void:
	tick = int(p.get("tick", 0))
	vehicles = p.get("vehicles", [])
	var open := {}
	for v in vehicles:
		if v.get("doors_open", false):
			open[v["id"]] = _opened.get(v["id"], tick)
	_opened = open


## The stop platform room `room` belongs to: {line, stop, direction}, the
## direction (0 east, 1 west) of the trams that stop beside it; {} for any
## other room.
func platform(room: String) -> Dictionary:
	return _platforms.get(room, {})


## The platform room of `stop` on the `direction` side, or "".
func platform_room(line_id: String, stop_id: String, direction: int) -> String:
	var platforms: Array = _stop(line_id, stop_id).get("platforms", [])
	return str(platforms[direction]) if direction < platforms.size() else ""


## The stop whose platforms are among `rooms` (room ids): {line, stop}, or
## {} for a place that is no stop.
func stop_among(rooms: Array) -> Dictionary:
	for room in rooms:
		var at := platform(str(room))
		if not at.is_empty():
			return {"line": at["line"], "stop": at["stop"]}
	return {}


## The line stop `stop_id` is on, or "".
func line_of_stop(stop_id: String) -> String:
	for id in lines:
		if not _stop(id, stop_id).is_empty():
			return id
	return ""


## Whether trams running `direction` from `stop` have a stop still ahead
## to take a rider to: at the last stop a player is never taken on (the
## core refuses a Board there, `NotYourDirection`).
func runs_on(line_id: String, stop_id: String, direction: int) -> bool:
	var here := _stop(line_id, stop_id)
	if here.is_empty():
		return false
	var s := _sign(direction)
	return lines[line_id].get("stops", []).any(func(x): return s * (float(x["at"]) - float(here["at"])) > 0.0)


## A stop's name, as the line gives it.
func stop_name(line_id: String, stop_id: String) -> String:
	return str(_stop(line_id, stop_id).get("name", stop_id))


## Vehicle `id`'s latest view, or {}.
func vehicle(id) -> Dictionary:
	for v in vehicles:
		if v["id"] == id:
			return v
	return {}


## The tram standing at `stop` with its doors open that runs `direction`,
## or {}.
func standing_open(line_id: String, stop_id: String, direction: int) -> Dictionary:
	for v in vehicles:
		if v.get("line") == line_id and _direction(v) == direction and v.get("doors_open", false) and v.get("stop") == stop_id:
			return v
	return {}


## The stop vehicle view `v` stands at, or else the next it will stand at:
## {id, name, at}, or {} past the last.
func next_stop(v: Dictionary) -> Dictionary:
	var line: Dictionary = lines.get(v.get("line"), {})
	if v.get("stop") != null:
		var here := _stop(v["line"], v["stop"])
		if not here.is_empty():
			return here
	var s := _sign(_direction(v))
	var centre := _centre(line, float(v.get("along", 0)), _direction(v))
	var best := {}
	for stop in line.get("stops", []):
		if s * (float(stop["at"]) - centre) > 0.0 and (best.is_empty() or s * float(stop["at"]) < s * float(best["at"])):
			best = stop
	return best


## Which way from a tram running along ground direction `dir` (x east, y
## south) the platform of `stop` on its side lies: 1 for its left, -1 for
## its right (CityGeometry.side_of); left when the platform is unknown or
## straight ahead. `from` is where the tram is.
func platform_side(line_id: String, stop_id: String, direction: int, from: Vector2, dir: Vector2) -> int:
	var room := platform_room(line_id, stop_id, direction)
	if not _rects.has(room) or dir == Vector2.ZERO:
		return 1
	return -1 if CityGeometry.side_of((_rects[room] as Rect2).get_center(), from, dir) < 0 else 1


## Ticks from now until a tram running `direction` (0 east, 1 west) stands
## at `stop` with its doors open: 0 while one does, -1 on a line or stop
## not known.
func ticks_until(line_id: String, stop_id: String, direction: int) -> int:
	var line: Dictionary = lines.get(line_id, {})
	var stop := _stop(line_id, stop_id)
	if line.is_empty() or stop.is_empty():
		return -1
	var timetable: Dictionary = line.get("timetable", {})
	var dwell := int(timetable.get("dwell", 0))
	var s := _sign(direction)
	var best := -1
	for v in vehicles:
		if v.get("line") != line_id or _direction(v) != direction:
			continue
		if v.get("stop") == stop_id:
			# Standing there with its doors open it takes riders now (whether
			# it has room is not shown: a full one leaves them behind). With
			# its doors shut it takes no one more: the next one will.
			if v.get("doors_open", false):
				return 0
			continue
		var front := float(v.get("along", 0))
		if s * (float(stop["at"]) - _centre(line, front, direction)) <= 0.0:
			continue
		var standing := 0
		if v.get("status") == "standing":
			standing = maxi(0, int(_opened.get(v["id"], tick)) + dwell - tick) if v.get("doors_open", false) else 0
		var arrives := standing + _run(line, stop, direction, front)
		best = arrives if best < 0 else mini(best, arrives)
	if best >= 0:
		return best
	# None on the way: the next the timetable sends in from the portal.
	return _by_timetable(line, stop, direction)


## Ticks from now until the next tram the timetable sends in running
## `direction` (the first to enter after this tick) stands at `stop`.
func _by_timetable(line: Dictionary, stop: Dictionary, direction: int) -> int:
	var timetable: Dictionary = line.get("timetable", {})
	var headway := maxi(int(timetable.get("headway", 1)), 1)
	var offsets: Array = timetable.get("offset", [0, 0])
	var offset := int(offsets[direction]) if direction < offsets.size() else 0
	var entry := maxi(offset, 1) if tick < offset else offset + ((tick - offset) / headway + 1) * headway
	return entry - tick + _run(line, stop, direction, _portal(line, direction))


## Ticks from now until a player joining now (or waiting at a portal to
## ride in) stands at `stop`: it rides the next tram to enter that reaches
## the stop first, either way (as the core's `soonest_entry` picks it), so
## the trams already on the line do not count. -1 on a line or stop not
## known.
func ticks_to_ride_in(line_id: String, stop_id: String) -> int:
	var line: Dictionary = lines.get(line_id, {})
	var stop := _stop(line_id, stop_id)
	if line.is_empty() or stop.is_empty():
		return -1
	return mini(_by_timetable(line, stop, 0), _by_timetable(line, stop, 1))


## ticks_to_ride_in in real seconds, as seconds_until counts them.
func seconds_to_ride_in(line_id: String, stop_id: String, fraction := 0.0) -> int:
	var ticks := ticks_to_ride_in(line_id, stop_id)
	if ticks < 0:
		return -1
	var rate := speed if speed > 0.0 else 1.0
	return ceili(maxf(0.0, float(ticks) - fraction) / rate)


## Real seconds until then, `fraction` of the current tick already gone:
## ticks over the speed (a tick a second at 1×), rounded up; the ticks
## themselves while paused. -1 when unknown.
func seconds_until(line_id: String, stop_id: String, direction: int, fraction := 0.0) -> int:
	var ticks := ticks_until(line_id, stop_id, direction)
	if ticks < 0:
		return -1
	var rate := speed if speed > 0.0 else 1.0
	return ceili(maxf(0.0, float(ticks) - fraction) / rate)


## The map card's line for `stop`: "East in 12 s · West in 27 s", each way
## that has a tram coming.
func card_line(line_id: String, stop_id: String, fraction := 0.0) -> String:
	var parts: Array = []
	for i in DIRECTIONS.size():
		var n := seconds_until(line_id, stop_id, i, fraction)
		if n >= 0:
			parts.append("%s in %d s" % [DIRECTIONS[i].capitalize(), n])
	return " · ".join(parts)


# ---- The line's geometry, as the core measures it ----

func _stop(line_id, stop_id) -> Dictionary:
	for stop in lines.get(line_id, {}).get("stops", []):
		if stop["id"] == stop_id:
			return stop
	return {}


static func _direction(v: Dictionary) -> int:
	return 1 if v.get("direction") == "west" else 0


## +1 east, -1 west: which way along the track a direction runs.
static func _sign(direction: int) -> float:
	return -1.0 if direction == 1 else 1.0


static func _length(line: Dictionary) -> float:
	return float(line.get("vehicle", {}).get("length", 0))


## Where a vehicle's centre is when its front is at `front`.
static func _centre(line: Dictionary, front: float, direction: int) -> float:
	return front - _sign(direction) * floorf(_length(line) / 2.0)


## Where its front enters: the west end of the eastbound track, the east
## end of the westbound one.
static func _portal(line: Dictionary, direction: int) -> float:
	if direction == 0:
		return 0.0
	return roundf(CityGeometry.length(CityGeometry.track_points(line, 1)))


## Ticks a tram with its front at `front` takes to stand at `stop`, at its
## timetable speed, standing a dwell at each stop between.
static func _run(line: Dictionary, stop: Dictionary, direction: int, front: float) -> int:
	var timetable: Dictionary = line.get("timetable", {})
	var per_tick := maxf(float(timetable.get("speed", 1)) * CELL_CM, 1.0)
	var s := _sign(direction)
	var centre := _centre(line, front, direction)
	var at := float(stop["at"])
	var between := 0
	for x in line.get("stops", []):
		if s * (float(x["at"]) - centre) > 0.0 and s * (at - float(x["at"])) > 0.0:
			between += 1
	var stop_front := at + s * floorf(_length(line) / 2.0)
	return ceili(maxf(0.0, s * (stop_front - front)) / per_tick) + between * int(timetable.get("dwell", 0))
