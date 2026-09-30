## The style-pack gate: one district, live, switched through every style
## pack across a whole day.
extends TestSuite

func public_ids(main) -> Array:
	var p: Dictionary = JSON.parse_string(main.driver.world.project_json("public"))
	var ids := []
	for room in p["rooms"]:
		for v in room["occupants"] + room["waiting"]:
			ids.append(v["id"])
	for v in p["in_transit"]:
		ids.append(v["id"])
	# Riders are drawn too, inside their trams.
	for v in p.get("aboard", []):
		ids.append(v["id"])
	ids.sort()
	return ids


func public_vehicles(main) -> Array:
	var p: Dictionary = JSON.parse_string(main.driver.world.project_json("public"))
	var ids: Array = p.get("vehicles", []).map(func(v): return v["id"])
	ids.sort()
	return ids


func test_one_day_through_every_style() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=60"]))
	assert_true(not main.hud.error_label.visible, "booted: " + main.hud.error_label.text)
	var styles: Array = main.styles
	assert_true(styles.size() >= 4, "every style pack: %d" % styles.size())
	var hours := {}
	for tick in range(1, 601):
		main.driver.step_once()
		hours[main.model.time / 60] = true
		if tick in [100, 300, 500]:
			var reference: Array = main.model.occupants.keys()
			reference.sort()
			assert_eq(reference, public_ids(main), "tick %d: the model holds exactly the public projection" % tick)
			for id in reference:
				var kind: Dictionary = main.model.occupants[id]["view"]["kind"]
				assert_true(kind.get("type") != "PersonalAgent", "tick %d: no private agent in public (%s)" % [tick, id])
				assert_true(not (kind.get("type") == "Human" and kind.get("tier") == "Observer"), "tick %d: no observer in public (%s)" % [tick, id])
			for dir in styles:
				main._activate(dir)
				var ids: Array = main.host.pack.nodes.keys()
				ids.sort()
				assert_eq(ids, reference, "tick %d: %s shows the same occupants" % [tick, dir])
				var trams: Array = main.host.pack.vehicle_nodes.keys()
				trams.sort()
				assert_eq(trams, public_vehicles(main), "tick %d: %s shows the same trams" % [tick, dir])
				assert_eq(main.host.pack.minutes, main.model.time, "tick %d: %s shows the same time" % [tick, dir])
				for id in main.host.pack.labels:
					assert_true(not main.host.pack.labels[id].visible, "names hidden by default in " + dir)
				assert_true(main.hud.fixture.is_visible_in_tree(), "the fixture banner stays visible")
	assert_true(hours.has(12) and hours.has(20), "the day passes noon and evening")
	main.free()
