## Using things: the one way the player acts on anything in the city (spec
## section 2). It knows every placement's and room seat's anchors and
## capabilities from the layout and the catalogue, chooses the one target
## the player acts on in each view, names that target's verbs (the first on
## the act button, the others a press of E or Y away, Inspect always last),
## and says what acting does: a `Use` sent at once, or a `Go` to the anchor
## first when it is out of reach and the `Use` on arrival; "Go in" and
## boarding as a `Use` too; a walk for the ground; and the overlay for
## Inspect and Read.
##
## A target is {type, target, kind, anchor, capabilities, pos}:
## - `type`: "placement", "seat", "building", "ground" or "person";
## - `target`: what a `Use` names (a placement or seat ID, the room behind
##   a building's door), or a person's ID, "" for the ground;
## - `kind`: the catalogue kind's ID, or "ground" or "person";
## - `anchor`: the index of the anchor among its kind's, -1 for none;
## - `capabilities`: the capability names it offers now, `inspect` last;
## - `pos`: where it is, in ground centimetres (a walk's end for the
##   ground).
## One in use carries `using`, the capability under way.
extends RefCounted
class_name Interact

## First person: the crosshair targets a placement whose anchor lies within
## this many metres of the eye.
const FIRST_PERSON_REACH_M := 3.0
## Overhead and in pixel art: the nearest anchor within this many metres...
const OVERHEAD_REACH_M := 1.5
## ...and within this many degrees of the way the player faces.
const OVERHEAD_HALF_ANGLE := 60.0
## A tap this near a sit or use anchor targets it, in centimetres (a tap
## elsewhere targets a placement only on its solid footprint, so a tap on
## open ground still walks).
const TAP_PICK_CM := 35.0
## "Go in" enters the room behind a door whose span lies within this many
## metres of the crosshair's hit on the building.
const GO_IN_REACH_M := 3.0
## The spatial hash's bucket, in centimetres: every reach above fits in
## the bucket round the player and its eight neighbours.
const BUCKET_CM := 400.0

## Each capability's verb.
const VERBS := {"sit": "Sit", "read": "Read", "use": "Use", "board": "Board", "enter": "Go in", "inspect": "Inspect",
	"watch": "Look at screen"}
## Where a kind names a capability its own way: a kiosk is browsed, and a
## workstation's computer used.
const KIND_VERBS := {"kiosk": {"read": "Browse"}, "workstation": {"use": "Use computer"}}
## What ends a use under way, by its capability. A workstation's `use` is
## its seat, so leaving the computer is standing up.
const STOP_VERBS := {"sit": "Stand up", "read": "Stop reading", "use": "Stand up"}
const WALK_HERE := "Walk here"
## Capabilities the core keeps with a `Use`; anything else (inspect, and
## watch, looking over a workstation user's shoulder) changes nothing, and
## the client does it alone.
const KEPT := ["sit", "read", "use", "board", "enter"]

## The catalogue's kinds by ID.
var kinds := {}
var nav: NavQuery
## Everything a player can act on in the world: every placement whose kind
## offers a capability, and every room seat. Each is {type, target, kind,
## pos (cm), anchors: [{index, type, pos (cm), facing}], capabilities,
## boxes: [{rect (metres), solid}], height (metres)}.
var things: Array = []
## The buildings, each {id, kind, footprint (metres), rooms (IDs), height,
## doors: [{room, a, b}] (metres)}, for "Go in".
var buildings: Array = []
## Anchors someone else holds, and seats taken or reserved, as of the last
## projection: {"<target>#<anchor>": true} and {seat ID: true}.
var taken := {}

## bucket -> the things reaching into it.
var _buckets := {}
## The target whose verbs are being cycled ("<type>|<target>|<verbs>"),
## and which of them is shown.
var _shown := ""
var _index := 0


## Reads every thing to act on from `layout` (the core's layout) and
## `kinds_` (StylePack.kinds()).
static func from_layout(layout: Dictionary, kinds_: Dictionary, nav_: NavQuery) -> Interact:
	var it := Interact.new()
	it.kinds = kinds_
	it.nav = nav_
	for d in layout.get("city", {}).get("districts", []):
		for p in d.get("placements", []):
			var kind: Dictionary = kinds_.get(str(p["kind"]), {})
			if kind.get("capabilities", []).is_empty():
				continue
			var facing := int(p["facing"]) if p.get("facing") != null else 0
			it._add(it._thing("placement", str(p["id"]), kind, Motion.point(p["at"]), facing, p.get("size")))
		for f in d.get("facilities", []):
			for r in f.get("rooms", []):
				for s in r.get("seats", []):
					if s.get("pos") != null:
						it._add(it._seat(s))
	for b in CityGeometry.buildings(layout, kinds_):
		it.buildings.append({"id": b["id"], "kind": b["kind"], "footprint": b["footprint"],
			"rooms": b["rooms"].map(func(r): return r["id"]),
			"height": 5.2 if b["roof"] == "sawtooth" else 4.0 * b["storeys"], "doors": door_spans(b, kinds_)})
	return it


## A thing of `kind` at `at` (cm) turned to `facing`: its anchors placed in
## the world as the core places them (city-core footprint.rs), and its
## solid footprint (a sized kind with no solid part, a meadow, gives its
## lot as a soft box).
func _thing(type: String, id: String, kind: Dictionary, at: Vector2, facing: int, size = null) -> Dictionary:
	var anchors := []
	var list: Array = kind.get("anchors", [])
	for k in list.size():
		var a: Dictionary = list[k]
		anchors.append({"index": k, "type": str(a["type"]), "pos": world_point(at, facing, Motion.point(a["at"])),
			"facing": posmod(facing + int(a.get("facing", 0)), 360)})
	var boxes := []
	for shape in kind.get("footprint", []):
		if shape.has("r"):
			var c := world_point(at, facing, Vector2(shape["x"], shape["z"])) / 100.0
			var r := float(shape["r"]) / 100.0
			boxes.append({"rect": Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), "solid": true})
	for rect in CityGeometry.footprint_rects(kind, {"pos": at / 100.0, "facing": float(facing)}):
		boxes.append({"rect": rect, "solid": true})
	if boxes.is_empty() and size is Dictionary and not kind.get("soft", []).is_empty():
		var lot := Vector2(size["w"], size["d"]) / 100.0
		boxes.append({"rect": Rect2(at / 100.0 - lot / 2.0, lot), "solid": false})
	return {"type": type, "target": id, "kind": str(kind.get("id", "")), "pos": at, "anchors": anchors,
		"capabilities": capabilities_of(kind), "boxes": boxes, "height": float(kind.get("height", 100)) / 100.0}


## A room seat: its furniture's kind, placed at the seat, with the seat as
## its first anchor (the one the seat names, else the kind's first sit
## anchor). A workstation's chair is also where its computer is used, and
## one may stand behind it to look on, so the seat carries its furniture's
## `use` anchors at the seat's own point and its `stand` anchors too (its
## display is no place to stand). A seat with no furniture offers only
## sitting.
func _seat(s: Dictionary) -> Dictionary:
	var kind: Dictionary = kinds.get(str(s.get("kind", "")), {})
	var at := Motion.point(s["pos"])
	var thing := _thing("seat", str(s["id"]), kind, at, int(s.get("facing", 0)))
	var list: Array = kind.get("anchors", [])
	var index := int(s["anchor"]) if s.get("anchor") != null else -1
	if index < 0:
		index = 0
		for k in list.size():
			if list[k]["type"] == "sit":
				index = k
				break
	var anchors := [{"index": index, "type": "sit", "pos": at, "facing": int(s.get("facing", 0))}]
	for a in thing["anchors"]:
		var own_point: bool = index < list.size() and list[a["index"]]["at"] == list[index]["at"]
		if a["type"] == "use" and own_point:
			anchors.append({"index": a["index"], "type": "use", "pos": at, "facing": a["facing"]})
		elif a["type"] == "stand":
			anchors.append(a)
	thing["anchors"] = anchors
	if kind.is_empty():
		thing["kind"] = "seat"
		thing["capabilities"] = ["sit"]
	return thing


## Files `thing` under every bucket its anchors, point and boxes reach.
func _add(thing: Dictionary) -> void:
	things.append(thing)
	var area := Rect2(thing["pos"], Vector2.ZERO)
	for a in thing["anchors"]:
		area = area.expand(a["pos"])
	for b in thing["boxes"]:
		area = area.merge(Rect2(b["rect"].position * 100.0, b["rect"].size * 100.0))
	var lo := Vector2i((area.position / BUCKET_CM).floor())
	var hi := Vector2i((area.end / BUCKET_CM).floor())
	for j in range(lo.y, hi.y + 1):
		for i in range(lo.x, hi.x + 1):
			var key := Vector2i(i, j)
			if not _buckets.has(key):
				_buckets[key] = []
			_buckets[key].append(thing)


## The things filed near `at` (cm), each once.
func _near(at: Vector2) -> Array:
	var out := []
	var seen := {}
	var c := Vector2i((at / BUCKET_CM).floor())
	for dj in range(-1, 2):
		for di in range(-1, 2):
			for thing in _buckets.get(c + Vector2i(di, dj), []):
				if not seen.has(thing["target"]):
					seen[thing["target"]] = true
					out.append(thing)
	return out


## A kind's capability names in catalogue order, `inspect` moved last.
static func capabilities_of(kind: Dictionary) -> Array:
	var out := []
	var inspect := false
	for c in kind.get("capabilities", []):
		if c["name"] == "inspect":
			inspect = true
		else:
			out.append(str(c["name"]))
	if inspect:
		out.append("inspect")
	return out


## Where a point in a placement's own frame (cm) lies in the world, as the
## core rotates it (city-core footprint::world_point): by `facing` with
## its sine and cosine fixed to 2^16, rounding down.
static func world_point(at: Vector2, facing: int, local: Vector2) -> Vector2:
	var t := deg_to_rad(float(posmod(facing, 360)))
	var s := roundi(sin(t) * 65536.0)
	var c := roundi(cos(t) * 65536.0)
	var lx := int(local.x)
	var lz := int(local.y)
	return Vector2(int(at.x) + ((lx * c - lz * s) >> 16), int(at.y) + ((lx * s + lz * c) >> 16))


# ---- Targeting ----

## The candidate targets in reach, the one to act on first. `view_state`:
## - "view": "first_person", "overhead" (pixel art too) or "touch";
## - overhead: "at", where the player stands (cm), and "facing", the way it
##   faces (a unit ground direction): the anchors within 1.5 m and 60° of
##   it, nearest first, those the player can use now before those it can
##   only inspect, one per thing;
## - first person: "camera" (FpvCamera) and "people" ({id, pos (metres)}):
##   whatever the crosshair rests on, a placement or seat only with an
##   anchor within 3 m (buildings and the ground as far as it reaches);
## - touch: "tap", the ground point tapped (cm): the sit or use anchor
##   within TAP_PICK_CM of it, else the placement whose solid footprint it
##   falls on.
func targets(view_state: Dictionary) -> Array:
	match str(view_state.get("view", "")):
		"first_person":
			return _first_person(view_state["camera"], view_state.get("people", []))
		"touch":
			return _touched(view_state["tap"])
		_:
			return _overhead(view_state["at"], view_state.get("facing", Vector2.ZERO))


func _overhead(at: Vector2, facing: Vector2) -> Array:
	var reach := OVERHEAD_REACH_M * 100.0
	var ranked := []
	for thing in _near(at):
		var best := {}
		for spot in _spots(thing, at):
			var d: float = spot["point"].distance_to(at)
			# Standing on an anchor's cell counts as ahead, whichever way
			# one faces: `at` is the cell's centre, and the anchor (behind a
			# workstation's chair, say) may lie a few centimetres off it.
			var on_it: bool = nav != null and nav.cell_of(spot["point"]) == nav.cell_of(at)
			if d > reach or not (on_it or _ahead(spot["point"] - at, facing)):
				continue
			var candidate := candidate_of(thing, spot["anchor"])
			var rank := {"usable": usable(candidate), "d": d, "candidate": candidate}
			if best.is_empty() or _before(rank, best):
				best = rank
		if not best.is_empty():
			ranked.append(best)
	ranked.sort_custom(_before)
	return ranked.map(func(r): return r["candidate"])


## The order of overhead targets: one the player can use (sit, read) before
## one it can only inspect, so a street tree or a lamp never takes the
## prompt from a bench beside it; then the nearest.
static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a["usable"] != b["usable"]:
		return a["usable"]
	return a["d"] < b["d"]


## Where `thing` can be reached from `from` (cm): each anchor, or, with
## none, the nearest point of its footprint (its own point when it has
## none), as {anchor, point}.
func _spots(thing: Dictionary, from: Vector2) -> Array:
	if not thing["anchors"].is_empty():
		return thing["anchors"].map(func(a): return {"anchor": a["index"], "point": a["pos"]})
	var point: Vector2 = thing["pos"]
	var best := INF
	for b in thing["boxes"]:
		var r: Rect2 = b["rect"]
		var p := (from / 100.0).clamp(r.position, r.end) * 100.0
		if p.distance_to(from) < best:
			best = p.distance_to(from)
			point = p
	return [{"anchor": -1, "point": point}]


## Whether `to` lies within OVERHEAD_HALF_ANGLE of `facing`; standing on it
## counts.
static func _ahead(to: Vector2, facing: Vector2) -> bool:
	if to.length() < 1.0 or facing == Vector2.ZERO:
		return true
	return rad_to_deg(absf(facing.angle_to(to))) <= OVERHEAD_HALF_ANGLE + 0.01


## Whether acting on `candidate` would do more than inspect it.
static func usable(candidate: Dictionary) -> bool:
	return not candidate["capabilities"].is_empty() and candidate["capabilities"][0] != "inspect"


func _first_person(camera: FpvCamera, people: Array) -> Array:
	var eye := Vector2(camera.position.x, camera.position.z) * 100.0
	var reach := FIRST_PERSON_REACH_M * 100.0
	# What the crosshair may rest on: sit and use anchors on the floor, and
	# the solid shapes (and a meadow's lot) of whatever is in reach. Things
	# further along the line of sight still stand in its way: resting on
	# one offers a walk to it.
	var aimed := []
	var entries := []
	for thing in _along(eye, camera):
		var in_reach := false
		for spot in _spots(thing, eye):
			if spot["point"].distance_to(eye) <= reach:
				in_reach = true
		if in_reach:
			for a in thing["anchors"]:
				if a["type"] in ["sit", "use"] and a["pos"].distance_to(eye) <= reach:
					entries.append({"id": thing["target"], "pos": a["pos"] / 100.0})
					aimed.append([thing, a["index"], true])
		var boxes := []
		for b in thing["boxes"]:
			var r: Rect2 = b["rect"]
			boxes.append(AABB(Vector3(r.position.x, 0.0, r.position.y), Vector3(r.size.x, thing["height"], r.size.y)))
		if not boxes.is_empty():
			entries.append({"id": thing["target"], "boxes": boxes})
			aimed.append([thing, null, in_reach])
	var hit := camera.aim(entries, buildings, people)
	var point: Vector2 = hit.get("point", Vector2.ZERO) * 100.0
	match str(hit["kind"]):
		"anchor":
			var pair: Array = aimed[hit["index"]]
			var anchor = pair[1]
			if anchor == null:
				anchor = _nearest_anchor(pair[0], eye)
			if not pair[2]:
				# Beyond reach: a walk to it, to its nearest anchor.
				var to := point
				for a in pair[0]["anchors"]:
					if a["index"] == anchor:
						to = a["pos"]
				return [{"type": "ground", "target": "", "kind": "ground", "anchor": -1, "capabilities": [], "pos": to}]
			return [candidate_of(pair[0], anchor)]
		"building":
			var room := go_in_room(hit)
			var building := {}
			for b in buildings:
				if b["id"] == hit["id"]:
					building = b
			if room == "":
				return []
			return [{"type": "building", "target": room, "kind": str(building.get("kind", "")), "anchor": 0,
				"capabilities": ["enter", "inspect"], "pos": point, "building": hit["id"]}]
		"ground":
			return [{"type": "ground", "target": "", "kind": "ground", "anchor": -1, "capabilities": [],
				"pos": walk_here(hit)}]
		"person":
			return [{"type": "person", "target": hit["id"], "kind": "person", "anchor": -1, "capabilities": [], "pos": point}]
	return []


## The things filed along the crosshair's line of sight seen from above,
## from the eye (`eye`, cm) as far as it reaches: to where it meets the
## ground, or the camera's reach.
func _along(eye: Vector2, camera: FpvCamera) -> Array:
	var ahead := camera.forward()
	var length := FpvCamera.REACH * cos(deg_to_rad(camera.pitch))
	if camera.pitch < -0.01:
		length = minf(length, camera.position.y / tan(deg_to_rad(-camera.pitch)))
	var out := []
	var seen := {}
	var step := BUCKET_CM / 2.0
	for k in int(ceilf(length * 100.0 / step)) + 1:
		for thing in _near(eye + ahead * minf(k * step, length * 100.0)):
			if not seen.has(thing["target"]):
				seen[thing["target"]] = true
				out.append(thing)
	return out


## The anchor of `thing` nearest `from` (cm), or -1 when it has none.
static func _nearest_anchor(thing: Dictionary, from: Vector2) -> int:
	var best := -1
	var best_d := INF
	for a in thing["anchors"]:
		var d: float = a["pos"].distance_to(from)
		if d < best_d:
			best_d = d
			best = a["index"]
	return best


func _touched(tap: Vector2) -> Array:
	var best := {}
	var best_d := TAP_PICK_CM
	for thing in _near(tap):
		for a in thing["anchors"]:
			var d: float = a["pos"].distance_to(tap)
			if a["type"] in ["sit", "use"] and d <= best_d:
				best_d = d
				best = candidate_of(thing, a["index"])
	if not best.is_empty():
		return [best]
	for thing in _near(tap):
		for b in thing["boxes"]:
			if b["solid"] and b["rect"].has_point(tap / 100.0):
				return [candidate_of(thing, _nearest_anchor(thing, tap))]
	return []


## `thing` as a target at anchor `anchor`: its capabilities less sitting
## or using where someone else holds the anchor it would happen at. A room
## seat's sit and use anchors are one place (a workstation's chair), so a
## seat taken, reserved or held by another offers neither, from any of its
## anchors; so are a placement's sit and use anchors at one point (a
## placed workstation's chair), from any anchor, its stand anchor behind
## the chair too. Looking at the screen (`watch`) is offered only from a
## stand anchor, and only while someone sits there.
func candidate_of(thing: Dictionary, anchor: int) -> Dictionary:
	var caps: Array = thing["capabilities"].duplicate()
	var type := _anchor_type(thing, anchor)
	var pos: Vector2 = thing["pos"]
	for a in thing["anchors"]:
		if a["index"] == anchor:
			pos = a["pos"]
	if thing["type"] == "seat":
		if taken.has(thing["target"]) or _occupied(thing):
			caps.erase("sit")
			caps.erase("use")
	else:
		for capability in ["sit", "use"]:
			if caps.has(capability) and _held_by_another(thing, anchor_for(thing, capability, anchor, pos)):
				caps.erase(capability)
	if caps.has("watch") and not (type == "stand" and _occupied(thing)):
		caps.erase("watch")
	return {"type": thing["type"], "target": thing["target"], "kind": thing["kind"], "anchor": anchor,
		"capabilities": caps, "pos": pos, "thing": thing}


## Whether someone else holds `thing`'s sit or use anchor `anchor`, or a
## sit or use anchor at its point: the core holds anchors at one point as
## one place.
func _held_by_another(thing: Dictionary, anchor: int) -> bool:
	var at = null
	for a in thing["anchors"]:
		if a["index"] == anchor and a["type"] in ["sit", "use"]:
			at = a["pos"]
	if at == null:
		return false
	for a in thing["anchors"]:
		if a["type"] in ["sit", "use"] and a["pos"] == at and taken.has("%s#%d" % [thing["target"], a["index"]]):
			return true
	return false


## What the player is using now (`using`, the projection's {target,
## capability, anchor}), as a target that carries it.
func in_use(using: Dictionary) -> Dictionary:
	var target := str(using.get("target", ""))
	var capability := str(using.get("capability", ""))
	for thing in things:
		if thing["target"] == target:
			# A seat is its own one anchor, whatever the use names.
			var anchor := int(thing["anchors"][0]["index"]) if thing["type"] == "seat" else int(using.get("anchor", 0))
			var candidate := candidate_of(thing, anchor)
			candidate["using"] = capability
			return candidate
	# Something not in the layout (moved or removed since): it can still be
	# stopped.
	return {"type": "placement", "target": target, "kind": "", "anchor": int(using.get("anchor", 0)),
		"capabilities": [], "pos": Vector2.ZERO, "using": capability}


## Whether someone else sits at `thing` or uses it: holds one of its sit
## or use anchors, as of the last projection (not a seat only reserved, or
## walked to).
func _occupied(thing: Dictionary) -> bool:
	for a in thing["anchors"]:
		if a["type"] in ["sit", "use"] and taken.has("%s#%d" % [thing["target"], a["index"]]):
			return true
	return false


func _anchor_type(thing: Dictionary, anchor: int) -> String:
	for a in thing["anchors"]:
		if a["index"] == anchor:
			return a["type"]
	return ""


# ---- Verbs ----

## The verbs for `target`, the act button's first and Inspect last: in use,
## what ends the use first (reading can open again what is read, and a
## room seat's chair switches between sitting and using without getting
## up); the ground's "Walk here"; nothing for a person.
func verbs(target: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if target.is_empty():
		return out
	if target["type"] == "ground":
		out.append(WALK_HERE)
		return out
	var using := str(target.get("using", ""))
	if using != "":
		out.append(STOP_VERBS.get(using, "Stop"))
	for c in target["capabilities"]:
		var switch: bool = target["type"] == "seat" and using in ["sit", "use"] and c != using
		# A computer left while the core still has the player at it is
		# offered again (see InteractionController.offer_reopen).
		var reopen: bool = c == using and target.get("reopen", false)
		if using != "" and c in ["sit", "use"] and not switch and not reopen:
			continue
		out.append(verb(target["kind"], c))
	return out


## Capability `capability`'s verb on a thing of kind `kind`.
static func verb(kind: String, capability: String) -> String:
	return KIND_VERBS.get(kind, {}).get(capability, VERBS.get(capability, capability.capitalize()))


## Which of `target`'s verbs the prompt shows: the first, until E or Y
## cycles; a new target, or new verbs for it, start again at the first.
func shown_verb(target: Dictionary) -> int:
	# The verbs are part of the key: starting to use the target (or someone
	# taking its anchor) changes them, and the prompt starts again at the
	# first.
	var key := "%s|%s|%s" % [target.get("type", ""), target.get("target", ""), ",".join(verbs(target))]
	if key != _shown:
		_shown = key
		_index = 0
	var n := verbs(target).size()
	return _index % n if n > 0 else 0


## E or Y: the prompt moves on to the next verb.
func cycle() -> void:
	_index += 1


## The prompt's text for `verb` on `target`: "Go in" says "Full" beside it
## at a room closed to the player (full, or queued for by others), where
## Go in queues.
func prompt_text(target: Dictionary, verb_: String) -> String:
	if verb_ == VERBS["enter"] and nav != null and nav.is_closed(str(target.get("target", ""))):
		return verb_ + " · Full"
	return verb_


# ---- Acting ----

## What acting on `target` with its verb `index` does, for a player
## standing on `cell`:
## - {do: "walk", pos}: walk to a ground point (cm);
## - {do: "stop"}: end the use under way;
## - {do: "inspect"}: open the overlay;
## - {do: "watch"}: look at a workstation's screen from behind its chair
##   (the client's alone: nothing is sent);
## - {do: "use", use: {target, capability, anchor}, go, overlay}: send a
##   Use, after `go` (a Go target: the seat, or the anchor's point) when
##   the player is not yet where the anchor asks; `overlay` for reading.
func action(target: Dictionary, index: int, cell: Vector2i) -> Dictionary:
	var names := verbs(target)
	if names.is_empty():
		return {}
	var verb_: String = names[index % names.size()]
	if target["type"] == "ground":
		return {"do": "walk", "pos": target["pos"]}
	if STOP_VERBS.values().has(verb_) and target.has("using"):
		return {"do": "stop"}
	var capability := ""
	for c in target["capabilities"]:
		if verb(target["kind"], c) == verb_:
			capability = c
	if capability == "watch":
		return {"do": "watch"}
	if capability == "" or not capability in KEPT:
		return {"do": "inspect"}
	var use := {"target": target["target"], "capability": capability, "anchor": target["anchor"]}
	var out := {"do": "use", "use": use, "go": null, "overlay": capability == "read"}
	if not target["type"] in ["placement", "seat"]:
		return out
	var thing: Dictionary = target["thing"]
	# From the place aimed at, as `candidate_of` chose what to offer, so
	# acting uses the anchor offered, not one nearer the player.
	var anchor := anchor_for(thing, capability, target["anchor"], target["pos"])
	use["anchor"] = anchor
	if target.get("using", "") == capability or at_anchor(thing, anchor, cell):
		return out
	if thing["type"] == "seat":
		out["go"] = {"type": "Seat", "seat": thing["target"]}
	else:
		out["go"] = {"type": "Point", "pos": _point(go_to(thing, anchor, nav.centre(cell)))}
	return out


## The anchor where `capability` happens on `thing`: `preferred` when it is
## of the capability's anchor type and no one else holds it, else the
## nearest to `from` (cm) that is and is free (a fountain rim's free
## place); with none free, `preferred` or the nearest of the type, which
## `candidate_of` then does not offer. A room seat is sat on at its own
## anchor (the seat rules decide who may), and a workstation's computer
## used at its use anchor, at the same point.
func anchor_for(thing: Dictionary, capability: String, preferred: int, from: Vector2) -> int:
	var type := ""
	for c in kinds.get(thing["kind"], {}).get("capabilities", []):
		if c["name"] == capability and c.get("at") != null:
			type = str(c["at"])
	if thing["type"] == "seat":
		for a in thing["anchors"]:
			if a["type"] == type:
				return a["index"]
		return thing["anchors"][0]["index"]
	if _anchor_type(thing, preferred) == type and not _held_by_another(thing, preferred):
		return preferred
	var nearest := -1
	var nearest_d := INF
	var free := -1
	var free_d := INF
	for a in thing["anchors"]:
		if a["type"] != type:
			continue
		var d: float = a["pos"].distance_to(from)
		if d < nearest_d:
			nearest_d = d
			nearest = a["index"]
		if d < free_d and not _held_by_another(thing, a["index"]):
			free_d = d
			free = a["index"]
	if free >= 0:
		return free
	if _anchor_type(thing, preferred) == type or nearest < 0:
		return preferred
	return nearest


## Where the player walks to use `thing`'s anchor `anchor` (cm): a
## display's nearest stand anchor, else the anchor itself.
func go_to(thing: Dictionary, anchor: int, from: Vector2) -> Vector2:
	var at: Vector2 = thing["pos"]
	for a in thing["anchors"]:
		if a["index"] == anchor:
			at = a["pos"]
	if _anchor_type(thing, anchor) != "display":
		return at
	var best := INF
	var stand := at
	for a in thing["anchors"]:
		if a["type"] == "stand" and a["pos"].distance_to(from) < best:
			best = a["pos"].distance_to(from)
			stand = a["pos"]
	return stand


## Whether a player on `cell` is where `thing`'s anchor `anchor` asks, as
## the core decides (city-core interact::at_anchor): on a sit or use
## anchor's own cell; for a display, on one of its stand anchors or a
## walkable neighbour of it within 45° of its outward normal; on a stand
## anchor's cell.
func at_anchor(thing: Dictionary, anchor: int, cell: Vector2i) -> bool:
	for a in thing["anchors"]:
		if a["index"] != anchor:
			continue
		var at := nav.cell_of(a["pos"])
		match a["type"]:
			"display":
				for s in thing["anchors"]:
					if s["type"] == "stand" and nav.cell_of(s["pos"]) == cell:
						return true
				var d := cell - at
				if maxi(absi(d.x), absi(d.y)) != 1 or not nav.walkable(cell):
					return false
				var off := posmod(roundi(rad_to_deg(atan2(d.x, -d.y))) - int(a["facing"]), 360)
				return mini(off, 360 - off) <= 45
			_:
				return cell == at
	return false


static func _point(p: Vector2) -> Dictionary:
	return {"x": int(round(p.x)), "z": int(round(p.y))}


# ---- Buildings and the ground ----

## A building's doors out of it (CityGeometry.buildings), each as its room
## and the ends of its span along the wall, in metres.
static func door_spans(b: Dictionary, kinds_: Dictionary) -> Array:
	var fp: Rect2 = b["footprint"]
	var ids: Array = b["rooms"].map(func(r): return r["id"])
	var out := []
	for r in b["rooms"]:
		for door in r.get("doors", []):
			if door.get("pos") == null or door["to"] in ids:
				continue
			var at := CityGeometry.pt_m(door["pos"])
			var half := CityGeometry.door_width(door, kinds_.get(b["kind"], {}), true) / 2.0
			# A door on the footprint's west or east side runs north to south.
			var along := Vector2(0, 1) if absf(at.x - fp.position.x) < 0.01 or absf(at.x - fp.end.x) < 0.01 else Vector2(1, 0)
			out.append({"room": str(r["id"]), "a": at - along * half, "b": at + along * half})
	return out


## The room "Go in" enters for a building `hit` (FpvCamera.aim's): the room
## behind the door whose span is nearest the hit's point, within
## GO_IN_REACH_M; with no door that near, the building's first room; ""
## for none.
func go_in_room(hit: Dictionary) -> String:
	for b in buildings:
		if b["id"] != hit.get("id") or b["rooms"].is_empty():
			continue
		var room := str(b["rooms"][0])
		var point = hit.get("point")
		if point is Vector2:
			var nearest := INF
			for door in b["doors"]:
				var d: float = point.distance_to(Geometry2D.get_closest_point_to_segment(point, door["a"], door["b"]))
				if d <= GO_IN_REACH_M and d < nearest:
					nearest = d
					room = door["room"]
		return room
	return ""


## Where "Walk here" walks for a ground `hit`: its point, or from inside a
## building the nearest cell of that building's own floor, never ground
## beyond its walls. Centimetres.
func walk_here(hit: Dictionary) -> Vector2:
	var at: Vector2 = hit["point"] * 100.0
	for b in buildings:
		if b["id"] == hit.get("inside"):
			var c = nav.nearest_floor(at, b["rooms"])
			if c != null:
				return nav.centre(c)
	return at
