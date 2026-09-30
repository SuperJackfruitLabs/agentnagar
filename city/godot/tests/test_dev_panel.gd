extends TestSuite


func panel(operator := false) -> DevPanel:
	var d := DevPanel.new()
	runner.root.add_child(d)
	d.setup([{"dir": "res://a", "name": "A"}, {"dir": "res://b", "name": "B"}],
		["public", "person:asha"] + (["operator"] if operator else []))
	return d


func test_hidden_until_enabled_and_toggled() -> void:
	var d := DevPanel.new()
	runner.root.add_child(d)
	d.setup([{"dir": "res://a", "name": "A"}], ["public"])
	assert_true(not d.visible, "hidden by default")
	d.toggle()
	assert_true(not d.visible, "F3 does nothing while developer tools are off")
	d.enabled = true
	d.toggle()
	assert_true(d.visible, "shown when enabled")
	d.free()


func test_intents_request_styles_speed_and_pause() -> void:
	var d := panel()
	var styles := []
	var speeds := []
	var pauses := []
	d.style_requested.connect(func(dir): styles.append(dir))
	d.speed_changed.connect(func(x): speeds.append(x))
	d.pause_toggled.connect(func(p): pauses.append(p))
	d.pick_style(2)
	d.pick_style(9)
	d.change_speed(1)
	d.change_speed(1)
	d.change_speed(-1)
	d.toggle_pause()
	assert_eq(styles, ["res://b"], "2 picks the second style; 9 is ignored")
	assert_eq(speeds, [2, 4, 2], "speed steps")
	assert_eq(pauses, [true], "pauses")
	d.free()


func test_styles_and_viewers_cycle_both_ways() -> void:
	var d := panel(true)
	var styles := []
	var viewers := []
	d.style_requested.connect(func(dir): styles.append(dir))
	d.viewer_requested.connect(func(v): viewers.append(v))
	d.show_style("res://a")
	d.step_style(1)
	d.step_style(1)
	d.step_style(-1)
	d.step_viewer(1)
	d.step_viewer(-1)
	d.step_viewer(-1)
	assert_eq(styles, ["res://b", "res://a", "res://b"], "next wraps round; previous goes back")
	assert_eq(viewers, ["person:asha", "public", "operator"], "viewers cycle both ways")
	d.free()


func test_operator_offered_only_with_flag() -> void:
	var d := panel()
	assert_true(not "operator" in d.viewer_ids, "no operator")
	d.free()
	var o := panel(true)
	assert_true("operator" in o.viewer_ids, "operator with the flag")
	o.free()


func test_open_all_and_roofs_toggle_and_note() -> void:
	var d := panel()
	var opens := []
	var roofs := []
	var notes := []
	d.open_all_toggled.connect(func(on): opens.append(on))
	d.roofs_toggled.connect(func(on): roofs.append(on))
	d.note.connect(func(text): notes.append(text))
	d.toggle_open_all()
	d.toggle_open_all()
	d.toggle_roofs()
	assert_eq(opens, [true, false], "open all toggles")
	assert_eq(roofs, [true], "roofs toggles")
	assert_eq(notes.size(), 1, "one note on the roofs toggle")
	assert_true("Roofs stay on" in notes[0], "notes the roofs behaviour, not shown through show_note")
	d.free()


func test_camera_requests_forwarded() -> void:
	var d := panel()
	var presets := []
	d.camera_requested.connect(func(p): presets.append(p))
	d.request_camera("topdown")
	d.request_camera("street")
	assert_eq(presets, ["topdown", "street"], "forwards the preset asked for")
	d.free()
