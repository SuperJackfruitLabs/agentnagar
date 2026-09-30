## A pure, testable model of the district's places for the map screen:
## which facilities are places, their categories, the projection between
## metres and map pixels, filter and search, arrow-key selection, occupancy
## counted from a projection, non-overlapping label placement, the transit
## lines' routes, and when the next tram comes to a stop; and the displays
## to read in each place, which the List tab lists as text under it.
## Holds no nodes and draws nothing.
extends RefCounted
class_name MapModel

## The four categories, in the order the legend and sort show them. A
## place with none of these sorts after all of them.
const CATEGORIES := ["workshop", "library", "transit", "park"]
const COLOURS := {
	"workshop": Color("#E8731A"), "library": Color("#2F6FD6"),
	"transit": Color("#7A3FC2"), "park": Color("#3E9A4A"),
}

## A pin's size on screen at zoom 1 (`map_view`'s `Pin_<id>` control), so
## label placement can keep clear of it.
const PIN_PX := 40.0
## The gap kept between a label and whatever it is tried clear of: a pin's
## edge, in the below/above/right/left tries, or another label.
const LABEL_GAP := 18.0
## The cone, either side of the given direction, that step() searches.
const STEP_CONE_DEG := 60.0

## The whole district, in metres (CityGeometry.extent of the layout).
var extent := Rect2()
## One Dictionary per facility with a room to draw, sorted by category
## order then by name: {id, name, category, rooms: [{id, name}],
## footprint (Rect2, metres), centre (Vector2, metres)}.
var places: Array = []
## One Dictionary per transit line, drawn in the Transit colour: {id,
## name, points (its centreline, metres)}.
var routes: Array = []
## When the next tram comes to each stop, from the same layout; it takes
## in each projection the map is given.
var trams := TramTimes.new()

## A category to show, or "" for every place.
var filter := ""
## A case-insensitive substring of a place's name; "" shows every place.
## The search is the List tab's: it narrows `visible_places`, never the
## map's own places (`map_places`).
var query := ""
## The selected facility's ID (or on the List tab, a display's placement
## ID), or "" when nothing is selected.
var selected := ""
## "You are here", in metres; where the first arrow press starts from.
var origin := Vector2.ZERO
## The pins' shape (one of MapTheme.PINS), which says where a pin stands
## (see pin_rect), so the labels keep clear of it.
var pin := "badge"

## The displays to read, for the List tab: {id (its placement), name (its
## kind's), title (its panel's, "" when it shows nothing), sample, place
## (the facility it stands in, or the nearest)}, by placement ID.
var things := {}

## Facility ID or room ID -> its place Dictionary.
var _by_id := {}


## Builds the model from a district layout (the manifest, parsed to a
## Dictionary): its extent and its places, `facility:streets` left out.
static func from_layout(layout: Dictionary) -> MapModel:
	var m := MapModel.new()
	m.extent = CityGeometry.extent(layout)
	var built: Array = []
	for d in layout.get("city", {}).get("districts", []):
		for f in d.get("facilities", []):
			if f["id"] == "facility:streets":
				continue
			var rooms: Array = f.get("rooms", [])
			var footprint := Rect2()
			var has_rect := false
			for r in rooms:
				if r.get("rect") != null:
					var rc := CityGeometry.rect_m(r["rect"])
					footprint = rc if not has_rect else footprint.merge(rc)
					has_rect = true
			if not has_rect:
				continue
			built.append({
				"id": f["id"], "name": str(f.get("name", f["id"])),
				"category": str(f.get("category", "")),
				"rooms": rooms.map(func(r): return {"id": r["id"], "name": str(r.get("name", r["id"]))}),
				"footprint": footprint, "centre": footprint.get_center(),
			})
	built.sort_custom(_before)
	m.places = built
	for line in layout.get("lines", []):
		m.routes.append({"id": line["id"], "name": str(line.get("name", line["id"])),
			"points": line.get("points", []).map(func(p): return CityGeometry.pt_m(p))})
	m.trams = TramTimes.from_layout(layout)
	for p in built:
		m._by_id[p["id"]] = p
		for r in p["rooms"]:
			m._by_id[r["id"]] = p
	return m


static func _category_rank(category: String) -> int:
	var i := CATEGORIES.find(category)
	return CATEGORIES.size() if i < 0 else i


## Sorted by category order (the four, then ""), then by name.
static func _before(a: Dictionary, b: Dictionary) -> bool:
	var ra := _category_rank(a["category"])
	var rb := _category_rank(b["category"])
	if ra != rb:
		return ra < rb
	return a["name"] < b["name"]


func _scale(size_px: Vector2) -> float:
	if extent.size.x <= 0.0 or extent.size.y <= 0.0:
		return 1.0
	return minf(size_px.x / extent.size.x, size_px.y / extent.size.y)


## The base picture is fitted to `size_px` keeping the extent's aspect,
## letterboxed evenly on whichever axis has room left over.
func _letterbox(size_px: Vector2) -> Vector2:
	var scale := _scale(size_px)
	return (size_px - extent.size * scale) * 0.5


## Metres to map pixels: north up, since the world's own z-south axis
## already runs the way pixel y does.
func to_map(p_m: Vector2, size_px: Vector2) -> Vector2:
	return (p_m - extent.position) * _scale(size_px) + _letterbox(size_px)


func from_map(px: Vector2, size_px: Vector2) -> Vector2:
	var scale := _scale(size_px)
	return (px - _letterbox(size_px)) / scale + extent.position


## A place by its own facility ID or any of its rooms' IDs, or a display's
## by its placement ID; `{}` if unknown.
func place(id: String) -> Dictionary:
	if things.has(id):
		return _by_id.get(things[id]["place"], {})
	return _by_id.get(id, {})


## Adds the displays to read (`surfaces`: Surfaces.of_layout with panels),
## each in the place whose rooms it stands in, else the nearest place.
func add_things(surfaces: Array) -> void:
	for s in surfaces:
		var at: Vector2 = s["pos"] / 100.0
		var best := ""
		var best_distance := INF
		for p in places:
			var r: Rect2 = p["footprint"]
			var distance: float = 0.0 if r.has_point(at) else (p["centre"] - at).length()
			if distance < best_distance:
				best_distance = distance
				best = p["id"]
		var panel: Dictionary = s.get("panel", {})
		things[s["id"]] = {"id": s["id"], "name": str(s["name"]), "title": str(panel.get("title", "")),
			"sample": panel.get("sample", false), "place": best}


## The displays in place `place_id`, by placement ID.
func things_in(place_id: String) -> Array:
	var ids := things.keys().filter(func(id): return things[id]["place"] == place_id)
	ids.sort()
	return ids.map(func(id): return things[id])


## The List tab's rows, top to bottom: each place shown (see
## visible_places), then the displays in it.
func list_rows() -> Array:
	var out := []
	for p in visible_places():
		out.append(p)
		out.append_array(things_in(p["id"]))
	return out


## The places the Map tab shows: `places`, honouring `filter`.
func map_places() -> Array:
	return places.filter(func(p): return filter == "" or p["category"] == filter)


## The List tab's rows: `places`, honouring `filter` and `query`.
func visible_places() -> Array:
	var q := query.to_lower()
	return map_places().filter(func(p): return q == "" or q in p["name"].to_lower())


## Selects `id`, if it names a known place, one of its rooms or a display;
## otherwise leaves the selection as it was.
func select(id: String) -> void:
	if things.has(id):
		selected = id
		return
	var p := place(id)
	if not p.is_empty():
		selected = p["id"]


## Moves the selection to the nearest place on the map whose direction from
## the selected place's centre (or `origin`, with nothing selected) is
## within 60 degrees of the screen direction `dir` (+y is south). Nothing
## changes when there is no such place.
func step(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	var from := origin
	var current := place(selected)
	if not current.is_empty():
		from = current["centre"]
	var wanted := dir.normalized()
	var cone := deg_to_rad(STEP_CONE_DEG)
	var best = null
	var best_dist := INF
	for p in map_places():
		if p["id"] == selected:
			continue
		var to: Vector2 = p["centre"] - from
		var dist := to.length()
		if dist < 0.0001:
			continue
		if absf(to.normalized().angle_to(wanted)) > cone:
			continue
		if dist < best_dist:
			best_dist = dist
			best = p
	if best != null:
		selected = best["id"]


## The next (`delta` 1) or previous (`delta` -1) row in `list_rows()`
## order (a place or a display), clamped to its ends.
func step_row(delta: int) -> void:
	var list := list_rows()
	if list.is_empty():
		return
	var idx := 0
	for i in list.size():
		if list[i]["id"] == selected:
			idx = i
			break
	selected = list[clampi(idx + delta, 0, list.size() - 1)]["id"]


## The stop `place` is, {line, stop}, or {} for a place that is none.
func stop_of(place: Dictionary) -> Dictionary:
	if place.get("category") != "transit":
		return {}
	return trams.stop_among(place.get("rooms", []).map(func(r): return r["id"]))


## A stop's card line, "East in 12 s · West in 27 s", or "" for a place
## that is no stop.
func next_trams(place: Dictionary) -> String:
	var at := stop_of(place)
	return "" if at.is_empty() else trams.card_line(at["line"], at["stop"])


## How many occupants are in `place`'s rooms, in the viewer's own
## projection. Never counts `waiting`: those are outside the room's door.
static func occupancy(projection: Dictionary, place: Dictionary) -> int:
	var room_ids := {}
	for r in place.get("rooms", []):
		room_ids[r["id"]] = true
	var total := 0
	for room in projection.get("rooms", []):
		if room_ids.has(room.get("id")):
			total += room.get("occupants", []).size()
	return total


static func _area(r: Rect2) -> float:
	return r.size.x * r.size.y


static func _clamped(r: Rect2, bounds: Vector2) -> Rect2:
	var pos := r.position
	pos.x = clampf(pos.x, 0.0, maxf(0.0, bounds.x - r.size.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, bounds.y - r.size.y))
	return Rect2(pos, r.size)


## A pin's rectangle, `PIN_PX` square, for a place at `anchor` (map
## pixels). A `drop` pin stands on its place: the middle of its foot, where
## its point is, is on the place, and the pin rises above it. A badge or a
## square is centred on the place.
static func pin_rect(anchor: Vector2, shape := "badge") -> Rect2:
	var side := Vector2.ONE * PIN_PX
	if shape == "drop":
		return Rect2(anchor - Vector2(PIN_PX / 2.0, PIN_PX), side)
	return Rect2(anchor - side / 2.0, side)


static func _blocked(r: Rect2, placed: Array, pins: Array) -> bool:
	for pr in placed:
		if r.intersects(pr):
			return true
	for pr in pins:
		if r.intersects(pr):
			return true
	return false


## The centres of the below/above/right/left tries for a label `half` its
## size, each kept `LABEL_GAP` clear of `box`: the place's own pin, or, for
## a place with no pin, the empty rectangle at its spot.
static func _side_tries(box: Rect2, half: Vector2) -> Array:
	var middle := box.get_center()
	return [
		Vector2(middle.x, box.end.y + LABEL_GAP + half.y),
		Vector2(middle.x, box.position.y - LABEL_GAP - half.y),
		Vector2(box.end.x + LABEL_GAP + half.x, middle.y),
		Vector2(box.position.x - LABEL_GAP - half.x, middle.y),
	]


## The label rectangle of every place on the map (`map_places`, so the
## places a filter hides neither take a spot nor block one), in pixels,
## keyed by facility ID; a place whose label cannot be placed without
## overlap is left out. `measure(text)` gives a label's size for its text.
func layout_labels(size_px: Vector2, measure: Callable) -> Dictionary:
	var shown := map_places()
	var pins: Array = []
	for p in shown:
		if p["category"] != "":
			pins.append(pin_rect(to_map(p["centre"], size_px), pin))
	var ordered := shown.duplicate()
	ordered.sort_custom(func(a, b): return _area(a["footprint"]) > _area(b["footprint"]))
	var placed: Array = []
	var out := {}
	for p in ordered:
		var anchor := to_map(p["centre"], size_px)
		var text_size: Vector2 = measure.call(p["name"])
		var half := text_size / 2.0
		var has_pin: bool = p["category"] != ""
		# A place with its own pin starts below it, then tries the other
		# three sides; a place with no pin starts centred on itself, then
		# tries the same four sides (clearing only other places' pins).
		var tries: Array = _side_tries(pin_rect(anchor, pin) if has_pin else Rect2(anchor, Vector2.ZERO), half)
		if not has_pin:
			tries = [anchor] + tries
		for centre in tries:
			var r := _clamped(Rect2(centre - half, text_size), size_px)
			if not _blocked(r, placed, pins):
				placed.append(r)
				out[p["id"]] = r
				break
	return out
