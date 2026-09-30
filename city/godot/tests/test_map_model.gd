## The map screen's model: places, projection, filter, search, selection
## and label placement.
extends TestSuite


func layout() -> Dictionary:
	return JSON.parse_string(CityPaths.district_manifest())


func test_places_have_their_categories_and_the_streets_are_left_out() -> void:
	var m := MapModel.from_layout(layout())
	var ids := m.places.map(func(p): return p["id"])
	assert_true(not "facility:streets" in ids, "streets are not a place")
	assert_eq(m.place("facility:library")["category"], "library", "library")
	assert_eq(m.place("room:reading")["id"], "facility:library", "a room finds its facility")
	assert_eq(m.places[0]["category"], "workshop", "workshop sorts first")


func test_north_is_up_and_the_river_is_west() -> void:
	var m := MapModel.from_layout(layout())
	var size := Vector2(1000, 800)
	var lib := m.to_map(m.place("facility:library")["centre"], size)
	var ws := m.to_map(m.place("facility:guild-hall")["centre"], size)
	assert_true(lib.x > ws.x, "the library is east of the workshop")
	var stop := m.to_map(m.place("facility:tram-stop")["centre"], size)
	assert_true(stop.y > ws.y, "the tram stop is south, lower on the map")
	var back := m.from_map(lib, size)
	assert_true(back.distance_to(m.place("facility:library")["centre"]) < 0.01, "round trip")


func test_filter_and_search() -> void:
	var m := MapModel.from_layout(layout())
	m.filter = "park"
	assert_eq(m.visible_places().map(func(p): return p["id"]), ["facility:park"], "only parks")
	m.filter = ""
	m.query = "LIB"
	assert_eq(m.visible_places().map(func(p): return p["id"]), ["facility:library"], "case-insensitive")
	m.query = "zzz"
	assert_eq(m.visible_places(), [], "no match")


func test_arrows_move_to_the_nearest_place_that_way() -> void:
	var m := MapModel.from_layout(layout())
	m.select("facility:guild-hall")
	m.step(Vector2.RIGHT)
	assert_true(m.selected != "facility:guild-hall", "moved east")
	# East of the library, the boulevard tram's Avenue stop, and nothing
	# beyond it.
	m.select("facility:library")
	m.step(Vector2.RIGHT)
	assert_eq(m.selected, "facility:avenue-stop", "moved east again, to the Avenue stop")
	var before := m.selected
	m.step(Vector2.RIGHT)
	assert_eq(m.selected, before, "nothing further east: unchanged")


func test_first_arrow_starts_from_you_are_here() -> void:
	var m := MapModel.from_layout(layout())
	m.origin = m.place("facility:tram-stop")["centre"] + Vector2(0, 5)
	m.step(Vector2.UP)
	assert_eq(m.selected, "facility:tram-stop", "the nearest place north of you")


func test_occupancy_counts_visible_occupants_of_the_place_rooms() -> void:
	var m := MapModel.from_layout(layout())
	var proj := {"rooms": [
		{"id": "room:workshop", "occupants": [{"id": "a"}, {"id": "b"}], "waiting": [{"id": "c"}]},
		{"id": "room:commons", "occupants": [{"id": "d"}], "waiting": []},
		{"id": "room:reading", "occupants": [{"id": "e"}], "waiting": []}]}
	assert_eq(MapModel.occupancy(proj, m.place("facility:guild-hall")), 3, "two rooms, waiting not counted")


func test_labels_never_overlap_and_stay_inside() -> void:
	var m := MapModel.from_layout(layout())
	for size in [Vector2(1920, 1080), Vector2(800, 900)]:
		var rects := m.layout_labels(size, func(t): return Vector2(t.length() * 11.0 + 16.0, 28.0))
		var list := rects.values()
		for i in list.size():
			assert_true(Rect2(Vector2.ZERO, size).encloses(list[i]), "inside at %s" % size)
			for j in range(i + 1, list.size()):
				assert_true(not list[i].intersects(list[j]), "no overlap at %s" % size)


## A pin is a PIN_PX badge, not a point: a label 18 px below its centre
## would still cover most of it. No placed label may intersect any pin.
func test_labels_never_overlap_the_pins() -> void:
	var m := MapModel.from_layout(layout())
	for size in [Vector2(1920, 1080), Vector2(800, 900)]:
		var rects := m.layout_labels(size, func(t): return Vector2(t.length() * 11.0 + 16.0, 28.0))
		for p in m.places:
			if p["category"] == "":
				continue
			var centre := m.to_map(p["centre"], size)
			var pin := Rect2(centre - Vector2.ONE * (MapModel.PIN_PX / 2.0), Vector2.ONE * MapModel.PIN_PX)
			for id in rects:
				assert_true(not rects[id].intersects(pin), "label %s clear of %s's pin at %s" % [id, p["id"], size])


## A place with no category still tries below, above, right and left of
## its centred spot before it is hidden, the same as a place with a pin.
func test_a_place_without_a_category_also_tries_the_four_sides() -> void:
	var m := MapModel.new()
	m.extent = Rect2(-10, -10, 20, 20)
	m.places = [
		{"id": "facility:a", "name": "A", "category": "workshop", "footprint": Rect2(-1, -1, 2, 2), "centre": Vector2(0, 0)},
		{"id": "facility:b", "name": "B", "category": "", "footprint": Rect2(0, 0, 0.2, 0.2), "centre": Vector2(0.2, 0)},
	]
	var size := Vector2(400, 400)
	var rects: Dictionary = m.layout_labels(size, func(t): return Vector2(28.0, 28.0))
	assert_true(rects.has("facility:b"), "b's centred spot is blocked by a's pin, but a side is free")
	var anchor := m.to_map(Vector2(0.2, 0), size)
	assert_true(rects["facility:b"].get_center().distance_to(anchor) > 10.0, "b moved off its centred spot")


## A drop pin stands on its place: its rectangle is PIN_PX square with its
## foot's middle, the point, on the place; a badge is centred on it.
func test_a_drop_pin_stands_on_its_place_and_labels_clear_it() -> void:
	var anchor := Vector2(300, 200)
	var drop := MapModel.pin_rect(anchor, "drop")
	assert_eq(drop.size, Vector2.ONE * MapModel.PIN_PX, "40 px")
	assert_eq(Vector2(drop.get_center().x, drop.end.y), anchor, "the point on the place")
	assert_eq(MapModel.pin_rect(anchor, "badge").get_center(), anchor, "a badge centred")
	assert_eq(MapModel.pin_rect(anchor, "square").get_center(), anchor, "a square centred")
	var m := MapModel.from_layout(layout())
	var measure := func(t): return Vector2(t.length() * 11.0 + 16.0, 28.0)
	for size in [Vector2(1920, 1080), Vector2(800, 900)]:
		m.pin = "badge"
		var with_badges := m.layout_labels(size, measure).size()
		m.pin = "drop"
		var rects := m.layout_labels(size, measure)
		assert_true(rects.size() >= with_badges, "as many labels placed as with badges at %s: %d, %d" % [size, rects.size(), with_badges])
		for p in m.places:
			if p["category"] == "":
				continue
			var pin := MapModel.pin_rect(m.to_map(p["centre"], size), "drop")
			for id in rects:
				assert_true(not rects[id].intersects(pin), "label %s clear of %s's drop pin at %s" % [id, p["id"], size])


## Labels are laid out for the places the map shows: filtered to one
## category, only its places are labelled, and the hidden places' pins
## and labels no longer crowd them. The search is the List's alone: it
## leaves the map's places, and the arrows over them, as they were.
func test_labels_and_arrows_follow_the_map_s_places() -> void:
	var m := MapModel.from_layout(layout())
	var measure := func(t): return Vector2(t.length() * 11.0 + 16.0, 28.0)
	m.filter = "transit"
	var rects := m.layout_labels(Vector2(800, 900), measure)
	# The boulevard tram's two stops are the transit places.
	assert_eq(rects.keys(), ["facility:tram-stop", "facility:avenue-stop"], "only the transit places laid out")
	m.filter = ""
	m.query = "lib"
	assert_eq(m.map_places().size(), m.places.size(), "the search leaves the map whole")
	assert_eq(m.visible_places().map(func(p): return p["id"]), ["facility:library"], "the List searched")
	assert_true(m.layout_labels(Vector2(1920, 1080), measure).has("facility:park"), "the park still labelled")
	m.origin = m.place("facility:tram-stop")["centre"]
	m.step(Vector2.UP)
	m.step(Vector2.LEFT)
	assert_eq(m.selected, "facility:guild-hall", "the arrows reach places the search does not match")
