## Every style draws the catalogue's placements: each kind mapped in its
## style.json, each placement of the district drawn once and tagged with
## its ID, and any scatter a pack adds of its own kept off walkable
## ground.
extends TestSuite


func manifest() -> Dictionary:
	return JSON.parse_string(CityPaths.district_manifest())


## The district as the client gets it from the core: its places, with the
## walkable grid.
func layout() -> Dictionary:
	var w := CityWorld.new()
	var loaded: Dictionary = JSON.parse_string(w.load(CityPaths.district_manifest(), CityPaths.district_feed(), 7, 0))
	assert_true(loaded.get("ok", false), "the district loads")
	return JSON.parse_string(w.layout_json())


func catalogue_ids() -> Array:
	var text := CityPaths.read(CityPaths.fixtures_dir().path_join("../catalogue/catalogue.json"))
	var ids := []
	for k in JSON.parse_string(text)["kinds"]:
		ids.append(str(k["id"]))
	return ids


func test_the_required_props_are_the_catalogues_kinds() -> void:
	var ids := catalogue_ids()
	assert_true(ids.size() > 20, "the catalogue has its kinds (%d)" % ids.size())
	assert_eq(StylePack.required()["props"], ids, "every kind, in the catalogue's order")
	assert_eq(StylePack.kinds().keys(), ids, "the kinds by ID")


## A kind drawn from another section of style.json (a seat's furniture, a
## building's exterior) names an entry that section has.
func test_every_style_maps_every_kind() -> void:
	var h := StyleHost.new()
	for dir in h.discover():
		var style: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("style.json")))
		assert_eq(StylePack.unmapped(style), [], dir + " maps every kind")
		for kind in StylePack.required()["props"]:
			var entry: Dictionary = style["props"].get(kind, {})
			if entry.has("seat"):
				assert_true(style["seats"].has(entry["seat"]), "%s draws %s as seat %s" % [dir, kind, entry["seat"]])
			if entry.has("building"):
				assert_true(style["exteriors"].has(entry["building"]), "%s draws %s as exterior %s" % [dir, kind, entry["building"]])
	h.free()


## The placement IDs a node is tagged with: its own, or those of a
## MultiMesh's instances.
static func tags(n: Node) -> Array:
	if n.has_meta("placement_id"):
		return [str(n.get_meta("placement_id"))]
	if n.has_meta("placement_ids"):
		return Array(n.get_meta("placement_ids"))
	return []


## How many times each placement ID is drawn under `root`: once per
## outermost tagged node (a tagged node's own tagged pieces are part of
## it), a far twin of tiled planting not counted.
static func drawn(root: Node) -> Dictionary:
	var out := {}
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var ids := tags(n)
		if not ids.is_empty():
			if not n.has_meta("far_of"):
				for id in ids:
					out[id] = int(out.get(id, 0)) + 1
			continue
		stack.append_array(n.get_children())
	return out


func test_every_pack_draws_each_placement_once_tagged_with_its_id() -> void:
	var m := manifest()
	var want := CityGeometry.placements(m).map(func(p): return p["id"])
	assert_eq(want.size(), 843, "the district's placements")
	var soft := {}
	for p in CityGeometry.placements(m):
		var kind: Dictionary = StylePack.kinds().get(p["kind"], {})
		if kind.get("footprint", []).is_empty() and not kind.get("soft", []).is_empty():
			soft[p["id"]] = true
	assert_eq(soft.size(), 3, "the district's meadows")
	var h := StyleHost.new()
	runner.root.add_child(h)
	for dir in h.discover():
		assert_true(h.activate(dir, m, SceneModel.new(), Motion.new(), 0.0), dir + " builds: " + h.last_error)
		var pack: StylePack = h.pack
		var seen := drawn(pack)
		var missing := want.filter(func(id): return not seen.has(id))
		# Soft ground (a meadow) is planted clump by clump, each clump an
		# instance carrying its ID; everything else is drawn once.
		var twice := want.filter(func(id): return int(seen.get(id, 0)) > 1 and not soft.has(id))
		assert_eq(missing, [], dir + " draws every placement")
		assert_eq(twice, [], dir + " draws each once")
		var unknown := []
		for id in want:
			var node = pack.placement_nodes.get(id)
			if node == null or not is_instance_valid(node) or not id in tags(node) or not pack.is_ancestor_of(node):
				unknown.append(id)
		assert_eq(unknown, [], dir + " keys each drawn node by its placement's ID")
	h.free()


## What a pack scatters of its own (planting between placements, moored
## boats, clutter) stands where no walkable cell lies within 10 cm, and no
## planting is drawn but the placements'.
func test_a_packs_own_scatter_lies_clear_of_walkable_cells() -> void:
	var l := layout()
	var nav := NavQuery.from_layout(l)
	assert_true(nav.cols > 0, "the layout carries the grid")
	var h := StyleHost.new()
	runner.root.add_child(h)
	for dir in h.discover():
		assert_true(h.activate(dir, l, SceneModel.new(), Motion.new(), 0.0), dir + " builds: " + h.last_error)
		var pack: StylePack = h.pack
		if pack.style.has("boat"):
			assert_true(not pack.decor.is_empty(), dir + " moors its boats as scatter of its own")
		for d in pack.decor:
			assert_true(CityGeometry.clear_of_walkable(nav, d["rect_cm"]), "%s scatters %s at %s clear of walkable cells" % [dir, d["node"].name, d["rect_cm"]])
		var untagged := []
		for n in pack.find_children("Planting*", "", true, false):
			if n is MultiMeshInstance3D and tags(n).size() != n.multimesh.instance_count:
				untagged.append(str(n.name))
		assert_eq(untagged, [], dir + " plants only placements")
		assert_eq(pack.find_children("Grove*", "", true, false).size(), 0, dir + " plants no grove of its own")
	h.free()


## Collects the warnings pushed while it is installed.
class Warnings extends Logger:
	var seen: Array[String] = []

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			seen.append(rationale if rationale != "" else code)


## A building or a vehicle stands as a facility or runs on a line, never as
## a district placement: a pack given one says so, naming the kind and the
## section its art is in, and still marks the spot.
func test_a_building_or_vehicle_placed_as_a_placement_is_warned_of() -> void:
	var m := manifest()
	m["city"]["districts"][0]["placements"] = [
		{"id": "placement:odd-hall", "kind": "guild-hall", "at": {"x": 0, "z": 600}},
		{"id": "placement:odd-tram", "kind": "tram", "at": {"x": 400, "z": 600}},
	]
	var h := StyleHost.new()
	runner.root.add_child(h)
	for dir in h.discover():
		var warnings := Warnings.new()
		OS.add_logger(warnings)
		var built := h.activate(dir, m, SceneModel.new(), Motion.new(), 0.0)
		OS.remove_logger(warnings)
		assert_true(built, dir + " builds: " + h.last_error)
		var said := " | ".join(warnings.seen)
		assert_true("guild-hall" in said and "exteriors" in said, dir + " warns of the placed hall: " + said)
		assert_true("tram" in said and "vehicle" in said, dir + " warns of the placed tram: " + said)
		assert_true(h.pack.placement_nodes.has("placement:odd-hall"), dir + " still marks where it stands")
	h.free()
