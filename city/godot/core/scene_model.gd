## Turns successive projections into the changes a style pack renders:
## who appeared or left, their pose, where they move, their headline, and
## the time of day; which vehicles run, where, and with their doors open or
## shut; and who boards or steps off them. It holds only what the
## projection gave it.
##
## Riders (the projection's `aboard`) are occupants like any other, in no
## room, whose views carry their `vehicle` and `slot`.
extends RefCounted
class_name SceneModel

## id -> {view: Dictionary, pose: String, room}
var occupants := {}
## id -> the vehicle's latest view.
var vehicles := {}
## Minutes after midnight, or -1 without a clock.
var time := -1
## How hard it rains, 0 to 100 percent (0 without weather).
var rain := 0


static func pose_of(view: Dictionary, waiting: bool) -> String:
	if view.get("moving", false):
		return "walking"
	if waiting:
		return "queued"
	# A perch is sat on through a use, with no seat.
	var using = view.get("using")
	if view.get("seat") != null or using is Dictionary and using.get("capability") == "sit":
		return "sitting"
	return "standing"


static func _flatten(p: Dictionary) -> Dictionary:
	var out := {}
	for room in p.get("rooms", []):
		for v in room.get("occupants", []):
			out[v["id"]] = {"view": v, "pose": pose_of(v, false), "room": room["id"]}
		for v in room.get("waiting", []):
			out[v["id"]] = {"view": v, "pose": pose_of(v, true), "room": room["id"]}
	for v in p.get("in_transit", []):
		out[v["id"]] = {"view": v, "pose": pose_of(v, false), "room": null}
	for v in p.get("aboard", []):
		out[v["id"]] = {"view": v, "pose": pose_of(v, false), "room": null}
	return out


## Where a vehicle is and how it moved: what a moved vehicle is drawn from.
static func _run(v: Dictionary) -> Array:
	return [v.get("pos"), v.get("heading"), v.get("along"), v.get("trail", [])]


static func _motion(v: Dictionary) -> Array:
	return [v.get("pos"), v.get("facing", 0), v.get("trail", [])]


## Applies projection `p` and returns the changes, in this order: left,
## vehicle_appeared, appeared, aboard, pose, moved, vehicle_moved, doors,
## vehicle_left, presence, time, rain. A vehicle appears before anyone
## drawn inside it, and its riders step off before it leaves.
func apply(p: Dictionary) -> Array:
	var next := _flatten(p)
	var left := []
	var appeared := []
	var boarding := []
	var poses := []
	var moves := []
	var presence := []
	var gone := occupants.keys()
	gone.sort()
	for id in gone:
		if not next.has(id):
			left.append({"type": "left", "id": id})
	var ids := next.keys()
	ids.sort()
	for id in ids:
		var now: Dictionary = next[id]
		var v: Dictionary = now["view"]
		if not occupants.has(id):
			appeared.append({"type": "appeared", "occupant": v, "pose": now["pose"], "room": now["room"]})
			continue
		var was: Dictionary = occupants[id]
		var ride = v.get("vehicle")
		if was["view"].get("vehicle") != ride or was["view"].get("slot") != v.get("slot"):
			boarding.append({"type": "aboard", "id": id, "vehicle": ride, "slot": v.get("slot"), "pos": v.get("pos")})
		if was["pose"] != now["pose"]:
			poses.append({"type": "pose", "id": id, "pose": now["pose"]})
		# Movement is replayed from what happened last tick (the trail from
		# where it was), never from the plan, so a held-up walker stands still.
		if _motion(was["view"]) != _motion(v):
			moves.append({"type": "moved", "id": id, "from": was["view"].get("pos"), "pos": v.get("pos"),
				"facing": v.get("facing", 0), "trail": v.get("trail", [])})
		var h_was = was["view"].get("presence", {}).get("headline")
		var h_now = v.get("presence", {}).get("headline")
		if h_was != h_now:
			presence.append({"type": "presence", "id": id, "headline": h_now})
	occupants = next
	var runs := _vehicle_changes(p)
	var changes: Array = left + runs["appeared"] + appeared + boarding + poses + moves + runs["moved"] \
		+ runs["doors"] + runs["left"] + presence
	var minutes = p.get("time_of_day")
	var t: int = -1 if minutes == null else int(minutes)
	if t != time:
		time = t
		if t >= 0:
			changes.append({"type": "time", "minutes": t})
	var r = p.get("rain")
	var percent: int = 0 if r == null else int(r)
	if percent != rain:
		rain = percent
		changes.append({"type": "rain", "percent": percent})
	return changes


## The vehicles of projection `p` against those held, by id: which
## appeared, moved (with `from`, where the front was), opened or shut
## their doors, and left. The held vehicles become `p`'s.
func _vehicle_changes(p: Dictionary) -> Dictionary:
	var out := {"appeared": [], "moved": [], "doors": [], "left": []}
	var next := {}
	for v in p.get("vehicles", []):
		next[v["id"]] = v
	var ids := next.keys()
	ids.sort()
	for id in ids:
		var v: Dictionary = next[id]
		if not vehicles.has(id):
			out["appeared"].append({"type": "vehicle_appeared", "view": v})
			continue
		var was: Dictionary = vehicles[id]
		if _run(was) != _run(v):
			out["moved"].append({"type": "vehicle_moved", "id": id, "view": v, "from": was.get("pos")})
		if bool(was.get("doors_open", false)) != bool(v.get("doors_open", false)):
			out["doors"].append({"type": "doors", "id": id, "open": bool(v.get("doors_open", false))})
	var gone := vehicles.keys()
	gone.sort()
	for id in gone:
		if not next.has(id):
			out["left"].append({"type": "vehicle_left", "id": id})
	vehicles = next
	return out


## Every vehicle running now, as `vehicle_appeared` changes sorted by id;
## used, before `current`, to rebuild a style pack from scratch.
func current_vehicles() -> Array:
	var ids := vehicles.keys()
	ids.sort()
	return ids.map(func(id): return {"type": "vehicle_appeared", "view": vehicles[id]})


## Everyone present now, as `appeared` changes sorted by id; used to rebuild
## a style pack from scratch.
func current() -> Array:
	var ids := occupants.keys()
	ids.sort()
	return ids.map(func(id): return {"type": "appeared", "occupant": occupants[id]["view"],
		"pose": occupants[id]["pose"], "room": occupants[id]["room"]})
