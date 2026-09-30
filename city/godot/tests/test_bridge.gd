extends TestSuite


func test_extension_loads() -> void:
	assert_true(ClassDB.class_exists("CityWorld"), "CityWorld is registered; run city/scripts/build-godot.sh")


func test_load_and_project() -> void:
	var w = ClassDB.instantiate("CityWorld")
	var result: Dictionary = JSON.parse_string(w.load(CityPaths.district_manifest(), CityPaths.district_feed(), 7, 0))
	assert_eq(result.get("ok"), true, "district loads")
	for i in 5:
		w.step()
	assert_eq(w.tick(), 5, "ticks advance")
	var p: Dictionary = JSON.parse_string(w.project_json("public"))
	assert_true(p.has("rooms") and p.has("time_of_day"), "projection has rooms and time")


func test_a_display_shows_its_sample_panel_read_beside_the_manifest() -> void:
	var w = ClassDB.instantiate("CityWorld")
	w.load(CityPaths.district_manifest(), CityPaths.district_feed(), 7, 0)
	w.set_fixture_dir(CityPaths.district_dir())
	var notices: Dictionary = JSON.parse_string(w.panel_json("placement:square-noticeboard"))
	assert_eq(notices.get("type"), "Notices", "the Square's noticeboard: %s" % notices)
	assert_eq(notices.get("sample"), true, "marked Sample")
	assert_eq(notices.get("items", []).size(), 3, "three releases")
	var unbound: Dictionary = JSON.parse_string(w.panel_json("placement:commons-bookshelf"))
	assert_eq(unbound.get("error", {}).get("code"), "unbound", "an unbound shelf shows nothing")


func test_operator_is_refused_without_the_flag() -> void:
	var w = ClassDB.instantiate("CityWorld")
	w.load(CityPaths.district_manifest(), CityPaths.district_feed(), 7, 0)
	var p: Dictionary = JSON.parse_string(w.project_json("operator"))
	assert_eq(p.get("error", {}).get("code"), "operator-flag-required", "operator refused")


func test_the_layout_carries_facility_categories() -> void:
	var w = ClassDB.instantiate("CityWorld")
	w.load(CityPaths.district_manifest(), CityPaths.district_feed(), 7, 0)
	var layout: Dictionary = JSON.parse_string(w.layout_json())
	var cats := {}
	for d in layout["city"]["districts"]:
		for f in d["facilities"]:
			if f.has("category"):
				cats[f["id"]] = f["category"]
	# The boulevard tram's Avenue stop is a second transit place.
	assert_eq(cats, {"facility:guild-hall": "workshop", "facility:library": "library",
		"facility:tram-stop": "transit", "facility:avenue-stop": "transit", "facility:park": "park"},
		"the four categories")


func test_the_layout_carries_the_cores_grid_and_the_catalogue_is_exposed() -> void:
	var w = ClassDB.instantiate("CityWorld")
	w.load(CityPaths.district_manifest(), CityPaths.district_feed(), 7, 0)
	var grid: Dictionary = JSON.parse_string(w.layout_json()).get("grid", {})
	assert_true(grid.has("origin") and grid["cols"] > 0 and grid["rows"] > 0, "the grid's origin and size")
	assert_eq(grid["levels"].size(), 1, "the ground level only")
	assert_eq(grid["levels"][0]["level"], 0.0, "level 0")
	var cells := 0
	for run in grid["levels"][0]["rooms"]:
		cells += int(run[1])
	assert_eq(cells, int(grid["cols"]) * int(grid["rows"]), "the runs cover every cell")
	assert_true(grid["rooms"].size() == grid["outdoor"].size() and not grid["spans"].is_empty() and not grid["seats"].is_empty(),
		"rooms, open ground, door spans and seats")
	var catalogue: Dictionary = JSON.parse_string(w.catalogue_json())
	assert_eq(catalogue.get("version"), 1.0, "catalogue version 1")
	assert_true(catalogue["kinds"].any(func(k): return k["id"] == "planter"), "its kinds")
