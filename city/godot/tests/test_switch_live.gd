## The same running world, switched between style packs at the same tick.
extends TestSuite


func snapshot(main) -> Dictionary:
	var pack: StylePack = main.host.pack
	var ids := pack.nodes.keys()
	ids.sort()
	return {"ids": ids, "poses": pack.poses.duplicate(), "headlines": pack.headlines.duplicate(),
		"minutes": pack.minutes}


func test_switching_styles_keeps_the_same_world() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=20"]))
	assert_true(not main.hud.error_label.visible, "booted: " + main.hud.error_label.text)
	main.driver.advance(50.0)
	var styles: Array = main.styles
	assert_true(styles.size() >= 2, "at least two styles to switch between")
	var expected_ids: Array = main.model.occupants.keys()
	expected_ids.sort()
	var first := snapshot(main)
	assert_eq(first["ids"], expected_ids, "the pack shows exactly the projection")
	assert_true(first["ids"].size() > 5, "a populated district")
	for dir in styles + [styles[0]]:
		main._activate(dir)
		assert_eq(main.host.pack_dir, dir, "switched to " + dir)
		var now := snapshot(main)
		for key in ["ids", "poses", "headlines", "minutes"]:
			assert_eq(now[key], first[key], dir + " keeps " + key)
	main.free()
