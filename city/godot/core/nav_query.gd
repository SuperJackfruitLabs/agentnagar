## The client's copy of the core's walkable grid (city-core `nav.rs`),
## loaded from the `grid` the bridge's `layout_json` carries, so prediction
## steps only where the core will accept a step. The core derives the cells
## (rooms less placements and building shells), the door spans
## and the seat cells; this copy only reads them, and follows the cells
## placement commands change (`apply_changes`). The step rules are the
## core's:
## - a step goes to one of the eight neighbours, never cuts a corner, and
##   crosses between rooms only within a door's span, except that outdoor
##   rooms (open ground) join along any shared edge;
## - a seat's cell is entered only as a walk's last cell, so a steered step
##   never lands on one.
## It also holds the cells other public occupants stand on, which a
## registered player may not step onto.
extends RefCounted
class_name NavQuery

const CELL := 25

## The grid's minimum corner, in centimetres.
var origin := Vector2i.ZERO
var cols := 0
var rows := 0
## Every room's ID, in the core's order.
var room_ids: Array[String] = []
## Whether each room (by number) is open ground.
var _outdoor := PackedByteArray()
## Each cell's room, as an index into room_ids, or -1 off the floor.
var _room := PackedInt32Array()
## cell -> the door spans (by number) it belongs to.
var _spans := {}
## cell -> true for cells holding a seat's point.
var _seat_cells := {}
## Every seat: {id, pos (centimetres), room}.
var seats: Array = []
## cell -> true for cells other public occupants hold.
var _held := {}
## Rooms a registered player may not step into past their door span: full,
## or queued for (the core's rule for steering).
var _closed := {}


## The grid of a layout from the bridge's `layout_json`: its `grid`, and
## the seats of its rooms. A layout without a grid (no room has a
## rectangle) gives an empty grid.
static func from_layout(layout: Dictionary) -> NavQuery:
	var nav := NavQuery.new()
	nav._load(layout.get("grid", {}))
	for d in layout.get("city", {}).get("districts", []):
		for f in d.get("facilities", []):
			for r in f.get("rooms", []):
				for seat in r.get("seats", []):
					if seat.get("pos") != null:
						nav.seats.append({"id": str(seat["id"]), "pos": Motion.point(seat["pos"]), "room": str(r["id"])})
	return nav


func _load(grid: Dictionary) -> void:
	if grid.is_empty():
		return
	origin = Vector2i(int(grid["origin"]["x"]), int(grid["origin"]["z"]))
	cols = int(grid["cols"])
	rows = int(grid["rows"])
	for id in grid["rooms"]:
		room_ids.append(str(id))
	for open in grid["outdoor"]:
		_outdoor.append(1 if open else 0)
	# Only the ground level exists until rooftops arrive. Cells no run
	# reaches stay off the floor: a short grid never walks anyone onto a
	# room the core does not have there.
	_room.resize(cols * rows)
	_room.fill(-1)
	var k := 0
	for run in grid["levels"][0]["rooms"]:
		var room := int(run[0])
		var n := int(run[1])
		for m in mini(n, _room.size() - k):
			_room[k + m] = room
		k += n
	if k != _room.size():
		push_error("nav: the grid's runs cover %d cells of its %d by %d" % [k, cols, rows])
	var number := 0
	for span in grid["spans"]:
		for c in span["cells"]:
			_spans.get_or_add(Vector2i(int(c[0]), int(c[1])), []).append(number)
		number += 1
	for c in grid["seats"]:
		_seat_cells[Vector2i(int(c[0]), int(c[1]))] = true


## Takes the core's `grid_changes` from a projection: each names a cell
## ({i, j}), whether it is walkable now, and for one that is, its room.
func apply_changes(changes: Array) -> void:
	for change in changes:
		var c := Vector2i(int(change["i"]), int(change["j"]))
		if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
			continue
		_room[c.y * cols + c.x] = int(change.get("room", -1)) if change.get("walkable", false) else -1


func _centre_i(c: Vector2i) -> Vector2i:
	return origin + c * CELL + Vector2i(CELL / 2, CELL / 2)


func _room_index(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
		return -1
	return _room[c.y * cols + c.x]


## The cell holding a point in centimetres.
func cell_of(pos_cm: Vector2) -> Vector2i:
	return Vector2i(floori((pos_cm.x - origin.x) / CELL), floori((pos_cm.y - origin.y) / CELL))


## A cell's centre in centimetres: whole centimetres, as the core's.
func centre(c: Vector2i) -> Vector2:
	return Vector2(_centre_i(c))


func walkable(c: Vector2i) -> bool:
	return _room_index(c) >= 0


## The room a cell is floor of, or "".
func room_at(c: Vector2i) -> String:
	var n := _room_index(c)
	return room_ids[n] if n >= 0 else ""


func in_door_span(c: Vector2i) -> bool:
	return _spans.has(c)


func is_seat_cell(c: Vector2i) -> bool:
	return _seat_cells.has(c)


## Whether one step from `a` to its neighbour `b` is one the core allows.
## A seat's cell is stepped onto only as the walk's `destination`; a steered
## step onto one the core refuses.
func can_step(a: Vector2i, b: Vector2i, destination := false) -> bool:
	var d := b - a
	if d == Vector2i.ZERO or absi(d.x) > 1 or absi(d.y) > 1:
		return false
	if not destination and _seat_cells.has(b):
		return false
	var ra := _room_index(a)
	var rb := _room_index(b)
	if ra < 0 or rb < 0:
		return false
	if d.x != 0 and d.y != 0:
		var s1 := _room_index(Vector2i(b.x, a.y))
		var s2 := _room_index(Vector2i(a.x, b.y))
		if ra == rb and s1 == ra and s2 == ra:
			return true
		return s1 >= 0 and s2 >= 0 and _outdoor[ra] == 1 and _outdoor[rb] == 1 and _outdoor[s1] == 1 and _outdoor[s2] == 1
	if ra == rb or (_outdoor[ra] == 1 and _outdoor[rb] == 1):
		return true
	for k in _spans.get(a, []):
		if k in _spans.get(b, []):
			return true
	return false


## The walkable cell nearest `pos_cm` on the floor of one of `rooms`
## (IDs), within `reach` cells of it, other than a seat's; null for none.
func nearest_floor(pos_cm: Vector2, rooms: Array, reach := 16):
	var around := cell_of(pos_cm)
	var best = null
	var best_d := INF
	for dj in range(-reach, reach + 1):
		for di in range(-reach, reach + 1):
			var c := around + Vector2i(di, dj)
			if not _seat_cells.has(c) and room_at(c) in rooms:
				var d := centre(c).distance_squared_to(pos_cm)
				if d < best_d:
					best_d = d
					best = c
	return best


## The cells other public occupants hold now.
func set_held(cells: Array) -> void:
	_held.clear()
	for c in cells:
		_held[c] = true


func is_held(c: Vector2i) -> bool:
	return _held.has(c)


## Which rooms are closed to steering now, by ID.
func set_closed(rooms: Array) -> void:
	_closed.clear()
	for r in rooms:
		_closed[r] = true


## Whether a step from `from` may end on `c`, as the core decides a
## steer: anywhere in a room that is not closed; in a closed room only on
## its door span, and only from its own floor. A step from outside onto a
## closed room's span is refused (`RoomFull`): a steered entry never
## queues, so the player stays at the threshold.
func enterable(from: Vector2i, c: Vector2i) -> bool:
	var room := room_at(c)
	if not _closed.has(room):
		return true
	return in_door_span(c) and room_at(from) == room


## Whether `room` is closed to steering now: full, or queued for.
func is_closed(room: String) -> bool:
	return _closed.has(room)
