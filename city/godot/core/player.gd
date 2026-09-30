## The local player. It joins the world as a registered person or an
## anonymous observer, and walks in two ways:
## - **Steering** (WASD, the left stick) is predicted. The avatar steps at
##   once, cell by cell, at the core's pace of five cells a tick, and only
##   where the core will accept the step: the same grid (NavQuery), and for
##   a registered player no cell another public occupant holds. Each tick's
##   cells go to the core as one `Steer` on the tick boundary.
## - **A click** sends `Go` and is not predicted: the avatar follows its
##   trail one tick behind, like everyone else.
## It rides the tram too: on a platform `board` waits for the next tram
## there, or boards one standing with its doors open, and aboard `alight`
## steps off at a stop. Aboard it is in the city but not on the ground.
## It uses things with one command, `Use` (see Interact): at once where it
## stands, or after a Go to the thing's anchor (`go_then_use`), sent when
## that walk ends; `stop_using` ends a use.
## Every projection confirms or corrects the prediction. On a correction the
## prediction rebases on the core's cell and the display eases there over
## EASE_S, never jumping. Positions are ground-plane centimetres (x, z).
extends RefCounted
class_name Player

## The core's pace: a walker takes at most five cells a tick.
const STEPS_PER_TICK := 5
## A correction eases out over this many seconds.
const EASE_S := 0.25
## How far off the steered line a step may slide round something in the
## way: up to about 84°, so a walk slides along a wall or round a post it
## meets at an angle, but one steered straight into a wall stops.
const SLIDE_COS := 0.1
## Steering that turns by more than 10° starts a new line.
const TURN_COS := 0.985
## How long the drawn avatar takes to follow a sideways shift of its cells
## while walking (the staircase is shorter-lived, so it is smoothed out).
const SIDE_TAU_S := 0.3
## How fast it settles sideways onto its cell at rest, in cm a second.
const SIDE_SETTLE_CM_S := 60.0
## A steered walk waits at each tick boundary for the core to take its
## steps; it stays in its walk that long rather than flickering to a stand.
const WALK_HOLD_S := 0.2
## Looks cycle through the crowd's eight outfits and four hair styles.
const OUTFITS := 8
const HAIRS := 4
const NEIGHBOURS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]

## A Use sent as the Go walking to its anchor ended (see `go_then_use`).
signal used(use: Dictionary)

## The CityWorld joined.
var world
## Our occupant's city ID once joined, else "".
var id := ""
## "registered" or "observer".
var as_ := "registered"
## "OUTFIT,HAIR".
var look := ""
## Ticks per real second: the driver's speed, or 0 while paused.
var speed := 1.0
## The fewest cells a press of a steering key walks, so a tap is a 1 m
## nudge in the overhead views; 0 for none.
var nudge_cells := 4
## The grid prediction walks on.
var nav: NavQuery
## Our occupant's latest view in our own projection, or {} when absent.
var view := {}
## True while the core has us in the city with a position on the ground.
var present := false
## True while we ride a tram (the projection's `aboard`): still in the
## city, but not on the ground.
var aboard := false
## True while we wait on a platform for a tram (our view's `waiting_for`).
var waiting := false
## The room the last `go_room` asked for, for tests; "" before any.
var last_go_room := ""
## The cell the prediction stands on, or is stepping to.
var cell := Vector2i.ZERO
## The room the last steered step would have gone into but for the room
## being closed to the player (full, or queued for by others), as the core
## refuses it (`RoomFull`); "" when the step ahead was not that.
var turned_away := ""
## Following a Go walk's trail rather than predicting.
var following := false
## Where the avatar is shown now.
var shown := Vector2.ZERO

## The centre of the cell the current step leaves, and how far along it is.
var _from := Vector2.ZERO
var _progress := 1.0
## Cells stepped since the last tick boundary, not yet sent.
var _pending: Array[Vector2i] = []
## A Go (or a Board) asked for while steered steps were unsent: it goes
## once they have been walked, so it starts where the avatar is shown.
var _go_later := {}
## Seconds the prediction has stood between steps.
var _still_s := 0.0
## A correction still being eased out, and how fast (cm a second).
var _offset := Vector2.ZERO
var _ease_rate := 0.0
## Steering follows a line from where it began, so any angle is walked
## faithfully on the grid of eight directions.
var _anchor := Vector2.ZERO
var _anchor_dir := Vector2.ZERO
var _steering := false
var _nudge_dir := Vector2.ZERO
var _side := Vector2.ZERO
var _side_q := 0.0
var _last_drawn := Vector2.ZERO
var _drawn_once := false
var _nudge_left := 0
## The look to join again with once the avatar has left, or "".
var _next_look := ""
## Seats someone holds or that are reserved, from the last projection.
var _unavailable := {}
## Anchors others use, as {"<target>#<anchor>": true}, from the last
## projection.
var _held_anchors := {}
## The Use to send once the Go to its anchor has walked there: {use,
## arrived (whether a cell is where the anchor asks), walked (whether the
## walk has been seen under way)}, or {}.
var _use_on_arrival := {}
## The capability of the last Use sent, for a refusal's notice.
var last_use := ""
## Whether the last Use was sent from short of its anchor because someone
## else holds it: the core, checking where the player stands before who
## holds the anchor, refuses it as NotAtAnchor, and the notice says the
## anchor is taken.
var last_use_held := false


var observer: bool:
	get:
		return as_ == "observer"

## Whether the avatar is walking now, predicted or on a trail.
var walking: bool:
	get:
		return _on_trail() if following else _progress < 1.0 or _steering and _still_s < WALK_HOLD_S

## The way the avatar walks now, or zero at rest: the way it is steered
## (the grid's staircase of steps would turn it 45° at every step).
var heading: Vector2:
	get:
		if following or not walking:
			return Vector2.ZERO
		if _nudge_dir != Vector2.ZERO:
			return _nudge_dir
		return (nav.centre(cell) - _from).normalized()


## Joins `world_` as `as__` ("registered" or "observer") with `look_`
## ("OUTFIT,HAIR"). Returns the bridge's answer: {"ok", "id"} or {"error"}.
func join(world_, as__: String, look_: String) -> Dictionary:
	world = world_
	as_ = as__
	look = look_
	var r = JSON.parse_string(world.join(as_, look))
	if not r is Dictionary:
		return {"error": {"code": "bad-reply", "message": "the bridge did not answer in JSON"}}
	if r.get("ok", false):
		id = str(r["id"])
	return r


## Takes in our own projection: where the core has us, and (for a
## registered player) which cells other public occupants hold.
func observe(p: Dictionary, nav_: NavQuery) -> void:
	nav = nav_
	view = own_view(p, id)
	aboard = is_aboard(p, id)
	waiting = view.get("waiting_for") != null
	_unavailable.clear()
	for room in p.get("rooms", []):
		for seat in room.get("seats", []):
			if seat.get("reserved", false):
				_unavailable[seat["id"]] = true
	_held_anchors.clear()
	for v in views_of(p):
		if v.get("seat") != null and v["id"] != id:
			_unavailable[v["seat"]] = true
		var using = v.get("using")
		if using is Dictionary and v["id"] != id and holds_cells(v):
			_held_anchors["%s#%d" % [using["target"], int(using["anchor"])]] = true
	if _next_look != "" and view.is_empty():
		_join_again()
	var held := []
	if not observer:
		for v in views_of(p):
			if v["id"] != id and v.get("pos") != null and holds_cells(v):
				held.append(nav.cell_of(Motion.point(v["pos"])))
	nav.set_held(held)
	nav.set_closed([] if observer else closed_rooms(p, id))
	if view.is_empty() or view.get("pos") == null or aboard:
		present = false
		_pending.clear()
		_go_later = {}
		_use_on_arrival = {}
		return
	var was_following := following
	# The steps that end a Go walk are still replayed over the next tick: it
	# follows them to the end rather than gliding on without steps.
	following = (bool(view.get("moving", false)) or was_following and _on_trail()) and not _steering
	reconcile(Motion.point(view["pos"]))
	if was_following and not following:
		_take_over()
	_use_if_arrived()


## Once the walk to a waiting Use's anchor is over (seen under way and
## now stopped, or never needed), sends the Use when the player stands
## where the anchor asks. Stopped short, it is dropped, unless someone
## else holds the anchor: then it goes, for the core's refusal to tell the
## player why.
func _use_if_arrived() -> void:
	if _use_on_arrival.is_empty() or not _go_later.is_empty():
		return
	if _on_trail():
		_use_on_arrival["walked"] = true
		return
	var arrived: Callable = _use_on_arrival["arrived"]
	var there: bool = arrived.call(cell)
	if not there and not _use_on_arrival["walked"]:
		return
	var use: Dictionary = _use_on_arrival["use"]
	_use_on_arrival = {}
	# Held: another's use of the anchor, or a seat taken or reserved.
	var held := not there and taken_anchors().has("%s#%d" % [use["target"], int(use["anchor"])]) \
		or not there and taken_anchors().has(use["target"])
	if there or held:
		self.use(use["target"], use["capability"], int(use["anchor"]))
		last_use_held = held
		if there:
			used.emit(use)


## Confirms or corrects the prediction with the core's position.
func reconcile(core_pos: Vector2) -> void:
	var c := nav.cell_of(core_pos)
	if not present:
		present = true
		_rest_on(c)
		shown = nav.centre(c)
		return
	if c == cell:
		return
	_rest_on(c)
	if not following:
		# The core disagreed: whatever the last press still owed is dropped.
		_nudge_left = 0
		_take_over()


## Moves the prediction on by `delta` real seconds, steering along the
## ground direction `steer` (zero for none), and returns where to show the
## avatar. While following a Go walk it shows `trail_pos`, where the trail
## replay has the avatar now, when given.
func predict(delta: float, steer: Vector2, nav_: NavQuery, trail_pos = null) -> Vector2:
	nav = nav_
	if not present:
		return shown
	var steering := steer != Vector2.ZERO and _next_look == ""
	if not steering:
		steer = Vector2.ZERO
	if steering and not _steering:
		_nudge_left = nudge_cells
		# Steering again takes over from a Go still waiting to be sent, and
		# from a use waiting on a walk.
		_go_later = {}
		_use_on_arrival = {}
	if steering:
		_nudge_dir = steer.normalized()
	_steering = steering
	if following:
		if not steering:
			if trail_pos != null:
				shown = trail_pos
			return shown
		following = false
		_take_over()
	var was_progress := _progress
	_walk(delta * speed, steer.normalized())
	_still_s = 0.0 if _progress < 1.0 or _progress != was_progress else _still_s + delta
	_offset = _offset.move_toward(Vector2.ZERO, _ease_rate * delta)
	shown = _on_line(_from.lerp(nav.centre(cell), _progress), delta) + _offset
	return shown


## A steered walk is drawn smoothly across the line it follows: the grid
## walks an off-axis line as a staircase of straight and diagonal steps, so
## the drawn avatar keeps its place along the walk exactly but eases its
## sideways position, which irons out the staircase and glides round
## anything it slides past; at rest it settles onto its cell.
func _on_line(raw: Vector2, delta: float) -> Vector2:
	var along := _anchor_dir.normalized()
	if along != Vector2.ZERO:
		var n := Vector2(-along.y, along.x)
		if not n.is_equal_approx(_side):
			# A new heading starts from where the avatar is drawn.
			_side = n
			_side_q = (_last_drawn if _drawn_once else raw).dot(n)
	else:
		_side = Vector2.ZERO
	if _side == Vector2.ZERO:
		_last_drawn = raw
		_drawn_once = true
		return raw
	var q := raw.dot(_side)
	if _steering or _nudge_left > 0 or _progress < 1.0:
		_side_q = lerpf(_side_q, q, 1.0 - exp(-delta / SIDE_TAU_S))
	else:
		_side_q = move_toward(_side_q, q, SIDE_SETTLE_CM_S * delta)
	_last_drawn = raw + _side * (_side_q - q)
	_drawn_once = true
	return _last_drawn


## Drops the sideways smoothing when the prediction is re-based.
func _forget_side() -> void:
	_side = Vector2.ZERO
	_drawn_once = false


## The cells stepped since the last tick boundary; clears them.
func cells_this_tick() -> Array[Vector2i]:
	var out := _pending.duplicate()
	_pending.clear()
	return out


## On a tick boundary: sends this tick's cells as one Steer, and returns
## them.
func submit_tick() -> Array[Vector2i]:
	var cells := cells_this_tick()
	if not cells.is_empty() and id != "" and _next_look == "":
		_command({"type": "Steer", "occupant": id, "cells": cells.map(func(c): return _point(nav.centre(c)))})
	elif not _go_later.is_empty():
		var go := _go_later
		_go_later = {}
		_command(go)
	return cells


## Walks to a ground point (Go, not predicted).
func go_point(pos_cm: Vector2) -> Dictionary:
	return _go({"type": "Point", "pos": _point(pos_cm)})


## Walks to a seat and sits (Go, not predicted).
func go_seat(seat: String) -> Dictionary:
	return _go({"type": "Seat", "seat": seat})


## Walks into a room, through its admission (Go, not predicted).
func go_room(room: String) -> Dictionary:
	last_go_room = room
	return _go({"type": "Room", "room": room})


## Stops a Go walk where it has got to.
func cancel() -> void:
	_nudge_left = 0
	_go_later = {}
	_use_on_arrival = {}
	if following and view.get("moving", false):
		_command({"type": "Steer", "occupant": id, "cells": []})


## A on a tram platform: waits there for the next tram, or boards the one
## standing there with its doors open (the core decides which). Steps not
## yet sent go first, so the core boards the player where it is shown.
## Returns the bridge's answer.
func board() -> Dictionary:
	if world == null or id == "":
		return {"error": {"code": "not-joined", "message": "join first"}}
	_nudge_left = 0
	_use_on_arrival = {}
	if not _pending.is_empty():
		_go_later = {"type": "Board", "occupant": id}
		return {"ok": true, "deferred": true}
	_go_later = {}
	return _reply(world.board())


## A aboard a tram standing at a stop with its doors open: steps off there.
## Returns the bridge's answer.
func alight() -> Dictionary:
	if world == null or id == "":
		return {"error": {"code": "not-joined", "message": "join first"}}
	return _reply(world.alight())


## Uses `capability` at anchor `anchor` of `target` (a placement, seat,
## room or line ID) now: the core checks the player stands where the
## anchor asks. Steps not yet sent go first, as for a Go, so the use
## begins where the avatar is shown. Returns the bridge's answer.
func use(target: String, capability: String, anchor: int) -> Dictionary:
	if world == null or id == "":
		return {"error": {"code": "not-joined", "message": "join first"}}
	_nudge_left = 0
	_use_on_arrival = {}
	last_use = capability
	last_use_held = false
	if capability == "enter":
		last_go_room = target
	var command := {"type": "Use", "occupant": id, "target": target, "capability": capability, "anchor": anchor}
	if not _pending.is_empty():
		# A Steer after it in the same tick would move the player off.
		_go_later = command
		return {"ok": true, "deferred": true}
	_go_later = {}
	return _command(command)


## Walks to `go` (a Go target: a seat, or an anchor's point) and, once the
## walk ends where the anchor asks, sends `use` ({target, capability,
## anchor}): acting on something out of reach. `arrived` says whether a
## cell is where the anchor asks (Interact.at_anchor); by default, the
## Go's own cell. Steering, cancelling, another Go or Use, a refused Go,
## changing look and leaving the ground drop it.
func go_then_use(go: Dictionary, use_: Dictionary, arrived := Callable()) -> Dictionary:
	var r := _go(go)
	var goal: Vector2 = Motion.point(go["pos"]) if go.has("pos") else Vector2.ZERO
	if go.get("type") == "Seat":
		for s in nav.seats:
			if s["id"] == go["seat"]:
				goal = s["pos"]
	var goal_cell := nav.cell_of(goal)
	if not arrived.is_valid():
		arrived = func(c: Vector2i) -> bool: return c == goal_cell
	_use_on_arrival = {"use": use_, "arrived": arrived, "walked": false}
	return r


## Drops a Use still waiting on a walk (its Go was refused).
func forget_use() -> void:
	_use_on_arrival = {}


## Whether a Use waits on a walk to its anchor.
func use_waiting() -> bool:
	return not _use_on_arrival.is_empty()


## Ends what the player uses: stands up from a seat, stops reading.
func stop_using() -> Dictionary:
	# Seated or using, it is sent even while the player is not shown
	# present for a moment: held back, it would strand them at the desk.
	var engaged: bool = view.get("seat") != null or view.get("using") is Dictionary
	if id == "" or not (present or engaged) or _next_look != "":
		return {}
	_use_on_arrival = {}
	return _command({"type": "StopUsing", "occupant": id})


## Seats taken or reserved as of the last projection, as {seat id: true}.
func unavailable_seats() -> Dictionary:
	return _unavailable


## What others hold as of the last projection, for Interact.taken: the
## seats taken or reserved ({seat ID: true}) and the anchors others use
## ({"<target>#<anchor>": true}).
func taken_anchors() -> Dictionary:
	return _unavailable.merged(_held_anchors)


## What the player is doing, for the HUD: joining, aboard (a tram),
## waiting for the tram, walking, queued at N, sitting, reading, standing,
## or changing look.
func status() -> String:
	if _next_look != "":
		return "changing look"
	if view.is_empty():
		return "joining"
	if aboard:
		return "aboard"
	if waiting:
		return "waiting for the tram"
	var queue = view.get("queue")
	if queue != null:
		return "queued at %d" % int(queue["position"])
	var using = view.get("using")
	if view.get("seat") != null or using is Dictionary and using.get("capability") == "sit":
		return "sitting"
	if using is Dictionary and using.get("capability") == "read":
		return "reading"
	return "walking" if walking else "standing"


## L: joins again with the next look. The core cannot restyle an occupant
## who is present, so the avatar leaves, and joins again once it is gone.
func cycle_look() -> void:
	if id == "" or _next_look != "":
		return
	var r = JSON.parse_string(world.leave())
	if r is Dictionary and r.get("ok", false):
		_next_look = next_look(look)
		_pending.clear()
		_go_later = {}
		_use_on_arrival = {}
		_nudge_left = 0


## The look after `current` ("OUTFIT,HAIR"): the next hair, then the next
## outfit.
static func next_look(current: String) -> String:
	var parts := current.split(",")
	var outfit := int(parts[0]) if parts.size() > 0 and parts[0].is_valid_int() else 0
	var hair := int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else 0
	hair += 1
	if hair >= HAIRS:
		hair = 0
		outfit = (outfit + 1) % OUTFITS
	return "%d,%d" % [outfit, hair]


func _join_again() -> void:
	var r = JSON.parse_string(world.join(as_, _next_look))
	if r is Dictionary and r.get("ok", false):
		look = _next_look
	else:
		push_warning("player: could not join again: %s" % str(r))
	_next_look = ""
	present = false


# ---- Projections ----

## Every occupant view in a projection.
## Who sits at or uses each thing in `p`: its target (a seat's or a
## placement's ID) -> their view. A view's `using` says it, as the core
## shows it: a seat counts once its occupant is sat there, not while they
## walk to it (`seat` is set from the moment the seat is taken).
static func users_by_target(p: Dictionary) -> Dictionary:
	var out := {}
	for v in views_of(p):
		var using = v.get("using")
		if using is Dictionary and str(using.get("target", "")) != "" and not out.has(str(using["target"])):
			out[str(using["target"])] = v
	return out


static func views_of(p: Dictionary) -> Array:
	var out: Array = p.get("in_transit", []).duplicate()
	for room in p.get("rooms", []):
		out.append_array(room.get("occupants", []))
		out.append_array(room.get("waiting", []))
	return out


## `who`'s own view: on the ground, queued at a door, walking between
## rooms, or aboard a tram (the projection's `aboard`). Empty once it has
## left the city, or while it waits beyond the city for its tram in.
static func own_view(p: Dictionary, who: String) -> Dictionary:
	var all := views_of(p)
	all.append_array(p.get("aboard", []))
	for v in all:
		if v["id"] == who:
			return v
	return {}


## Whether `who` is aboard a tram in `p`: still in the city, but not on
## the ground. Riders are listed apart from every room (`aboard`).
static func is_aboard(p: Dictionary, who: String) -> bool:
	return p.get("aboard", []).any(func(v): return v["id"] == who)


## Whether an occupant holds its cell: everyone public does; private
## personal agents and anonymous observers are overlays and hold nothing.
static func holds_cells(v: Dictionary) -> bool:
	var kind: Dictionary = v.get("kind", {})
	return kind.get("type") != "PersonalAgent" and not (kind.get("type") == "Human" and kind.get("tier") == "Observer")


# ---- Stepping ----

func _walk(ticks: float, steer: Vector2) -> void:
	var left := ticks
	while left > 0.0:
		if _progress < 1.0:
			var rest := (1.0 - _progress) / STEPS_PER_TICK
			if left < rest:
				_progress += left * STEPS_PER_TICK
				return
			left -= rest
			_progress = 1.0
		var dir := steer if steer != Vector2.ZERO else (_nudge_dir if _nudge_left > 0 else Vector2.ZERO)
		if dir == Vector2.ZERO or _pending.size() >= STEPS_PER_TICK:
			return
		var next = _next_cell(dir)
		if next == null:
			_nudge_left = 0
			return
		_from = nav.centre(cell)
		cell = next
		_pending.append(next)
		_progress = 0.0
		_nudge_left = maxi(0, _nudge_left - 1)


## The neighbour to step to along `dir`, or null. It keeps to the line the
## steering began on. When that step is not allowed it takes, in this
## order, and starts the line again from there:
## - a step into a doorway: through the door into the next room, or onto
##   its threshold from where walking straight on goes through. So a walk
##   that meets a doorway at an angle, or at its very jamb, goes in rather
##   than sliding along the threshold or the wall and on past it (a
##   diagonal between rooms is never allowed);
## - pushed straight into the wall one cell beside a doorway, a side step
##   in front of it, as the jamb would guide in a body that wide;
## - a slide up to about 84° off, round what is in the way.
func _next_cell(dir: Vector2):
	# A new direction, or one that has left the line by more than a cell,
	# starts a new line here; a stick's small wobbles only turn the line.
	if _anchor_dir == Vector2.ZERO or _anchor_dir.dot(dir) < TURN_COS \
			or absf(dir.cross(nav.centre(cell) - _anchor)) > NavQuery.CELL:
		_anchor = nav.centre(cell)
	_anchor_dir = dir
	var ranked := []
	for k in NEIGHBOURS.size():
		var off: Vector2i = NEIGHBOURS[k]
		var ahead := Vector2(off).normalized().dot(dir)
		if ahead < SLIDE_COS:
			continue
		var away := absf(dir.cross(nav.centre(cell + off) - _anchor))
		ranked.append([snappedf(away, 0.01), -ahead, k])
	ranked.sort()
	# The prediction refuses a step into a closed room itself, so the core
	# never sends back why: the room is kept here for the notice whenever a
	# step the walk would have taken instead is refused only because the
	# room is closed. That is any step ranked ahead of every allowed slide,
	# and any step through a doorway, which goes before a slide.
	turned_away = ""
	var slide = null
	for n in ranked.size():
		var step: Vector2i = NEIGHBOURS[ranked[n][2]]
		var c: Vector2i = cell + step
		var allowed := _may_step(cell, c)
		if allowed and n == 0:
			return c
		var closed := _closed_through_door(cell, step)
		if closed == "" and slide == null and _refused_as_closed(cell, c):
			closed = nav.room_at(c)
		if closed != "":
			turned_away = closed
		if not allowed:
			continue
		if _leads_through_door(cell, step):
			_anchor = nav.centre(c)
			return c
		if slide == null:
			slide = c
	var beside = _beside_doorway(dir)
	if beside != null:
		_anchor = nav.centre(beside)
		return beside
	if slide != null:
		_anchor = nav.centre(slide)
	return slide


## Whether a steered step from `a` to its neighbour `b` is one the core
## takes: on the grid, onto no cell someone holds, and into no room
## closed to the player past its door span.
func _may_step(a: Vector2i, b: Vector2i) -> bool:
	return nav.can_step(a, b) and not nav.is_held(b) and nav.enterable(a, b)


## Whether the step from `a` to its neighbour `b` is refused only because
## `b` lies in a room closed to the player (see `NavQuery.enterable`).
func _refused_as_closed(a: Vector2i, b: Vector2i) -> bool:
	return nav.can_step(a, b) and not nav.is_held(b) and not nav.enterable(a, b)


## The closed room that walking straight on from `from` by `step` would go
## into through a door, were it open; else "".
func _closed_through_door(from: Vector2i, step: Vector2i) -> String:
	var at := from
	# A span reaches two cells either side of its door.
	for k in 4:
		var next := at + step
		if not nav.in_door_span(next) or not nav.can_step(at, next) or nav.is_held(next):
			return ""
		if not nav.enterable(at, next):
			return nav.room_at(next)
		if nav.room_at(next) != nav.room_at(at):
			return ""
		at = next
	return ""


## When the walk along `dir` is pushed straight into a wall, the side step
## that brings it in front of a doorway one cell away, from where walking
## on along `dir` goes through the door; else null.
func _beside_doorway(dir: Vector2):
	var into := Vector2i(Vector2(dir.x, 0).sign()) if absf(dir.x) >= absf(dir.y) else Vector2i(Vector2(0, dir.y).sign())
	if nav.can_step(cell, cell + into):
		return null
	for k in 4:
		var side: Vector2i = NEIGHBOURS[k]
		# Only a sideways step: never back from where the walk heads.
		if absf(Vector2(side).dot(dir)) >= SLIDE_COS:
			continue
		var front := cell + side
		if nav.room_at(front) != nav.room_at(cell) or not _may_step(cell, front):
			continue
		if _leads_through_door(front, into):
			return front
		var closed := _closed_through_door(front, into)
		if closed != "":
			turned_away = closed
	return null


## Whether walking straight on from `from` by `step` goes through a door
## into another room, every cell of the way on its span and allowed.
func _leads_through_door(from: Vector2i, step: Vector2i) -> bool:
	var at := from
	# A span reaches two cells either side of its door.
	for k in 4:
		var next := at + step
		if not nav.in_door_span(next) or not _may_step(at, next):
			return false
		if nav.room_at(next) != nav.room_at(at):
			return true
		at = next
	return false


## The rooms `me` may not steer into, from outside onto their door span
## or past it, as the core decides a steer: every room it is not admitted
## to that it queues for, or that has no space for it (its visible public
## occupants and unclaimed reserved seats fill its capacity) or a queue it
## would overtake. The prompt shows these as "Full".
static func closed_rooms(p: Dictionary, me: String) -> Array:
	var out := []
	for room in p.get("rooms", []):
		var ids: Array = room.get("occupants", []).map(func(v): return v["id"])
		if me in ids:
			continue
		var waiting: Array = room.get("waiting", [])
		var queued := waiting.any(func(v): return v["id"] == me)
		var present: int = room.get("occupants", []).filter(func(v): return holds_cells(v)).size()
		var sat := {}
		for v in room.get("occupants", []):
			if v.get("seat") != null:
				sat[v["seat"]] = true
		var unclaimed: int = room.get("seats", []).filter(func(s): return s.get("reserved", false) and not sat.has(s["id"])).size()
		if queued or not waiting.is_empty() or present + unclaimed >= int(room.get("capacity", 0)):
			out.append(str(room["id"]))
	return out


## Whether the core walked it last tick or is walking it on.
func _on_trail() -> bool:
	return bool(view.get("moving", false)) or not view.get("trail", []).is_empty()


## Stands the prediction on `c`, with nothing in flight.
func _rest_on(c: Vector2i) -> void:
	_forget_side()
	cell = c
	_from = nav.centre(c)
	_progress = 1.0
	_pending.clear()
	_anchor_dir = Vector2.ZERO


## Makes the prediction the display from here on, easing from where the
## avatar is shown now.
func _take_over() -> void:
	_forget_side()
	_offset = shown - _from.lerp(nav.centre(cell), _progress)
	_ease_rate = _offset.length() / EASE_S


# ---- Commands ----

func _go(target: Dictionary) -> Dictionary:
	_nudge_left = 0
	_use_on_arrival = {}
	var go := {"type": "Go", "occupant": id, "to": target}
	if not _pending.is_empty():
		# A Steer applies after a Go in the same tick and would cancel it:
		# the steps already walked are sent at the boundary, and the Go
		# the tick after, from where the avatar stands.
		if world == null or id == "":
			return {"error": {"code": "not-joined", "message": "join first"}}
		_go_later = go
		return {"ok": true, "deferred": true}
	_go_later = {}
	return _command(go)


func _command(c: Dictionary) -> Dictionary:
	if world == null or id == "":
		return {"error": {"code": "not-joined", "message": "join first"}}
	var r = JSON.parse_string(world.command(JSON.stringify(c)))
	if not r is Dictionary or r.has("error"):
		push_warning("player: %s refused: %s" % [c.get("type"), str(r)])
		return r if r is Dictionary else {}
	return r


static func _reply(json: String) -> Dictionary:
	var r = JSON.parse_string(json)
	return r if r is Dictionary else {"error": {"code": "bad-reply", "message": "the bridge did not answer in JSON"}}


static func _point(p: Vector2) -> Dictionary:
	return {"x": int(round(p.x)), "z": int(round(p.y))}
