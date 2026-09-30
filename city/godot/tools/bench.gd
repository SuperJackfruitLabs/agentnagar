extends SceneTree
## Frame-time benchmark: every style through Bench.SCENES (normal play, the
## game menu, the title and the map at a crowd of 60, two full trams, and
## the heaviest),
## uncapped, each sampled for Bench.SAMPLE_S seconds after a warm-up, the world
## running at 1x as in play (BENCH_STYLES=a,b limits it to those styles,
## and BENCH_SCENES=x,y to those scenes, so one scene can be measured from
## a cool GPU).
## It runs fullscreen at the display's native resolution, as players see
## it, and every scene is checked to render at that size: a desktop that
## will not give the window those pixels fails the run (Bench.size_breach).
## Normal play is held to what the display gives an empty scene (measured
## first, the same way). Each scene also reports the game's own GPU time
## per frame (99th percentile), which a stall in the desktop's presentation
## does not inflate, and, with vsync at the display's rate as players run
## it, the frames per second and the share of refreshes missed (what a
## style's frame-rate budget gates), with the Unix times it started and
## ended, so scripts/bench.sh can put the GPU's heat beside it. The map
## scene also times opening the map, the first time in the style and
## again: how long until its picture shows, and the longest frame on the
## way. Writes ~/.cache/agentnagar-bench/bench.json and exits 1 when a
## style that declares a budget breaks it, when opening the map again takes
## a frame over Bench.REOPEN_MAX_MS in any style, or when a scene rendered
## at any other size.
##   godot --path godot --script res://tools/bench.gd
var out := OS.get_environment("HOME") + "/.cache/agentnagar-bench/"


func _init() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(out)
	var results := []
	var budgets := {}
	# Every scene that rendered at other than the native size.
	var wrong_size := []
	var native := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var only_scenes := OS.get_environment("BENCH_SCENES").split(",", false)
	await _fullscreen(native)
	var baseline := await _baseline()
	print("bench baseline: an empty scene with vsync at %.0f Hz: %.1f fps, missed %.2f%% (rendering %dx%d; the display's native size is %dx%d)" % [baseline["hz"], baseline["fps"], baseline["missed_pct"], root.size.x, root.size.y, native.x, native.y])
	if Bench.size_breach(root.size, native) != "":
		wrong_size.append("baseline: " + Bench.size_breach(root.size, native))
	var only := OS.get_environment("BENCH_STYLES").split(",", false)
	for crowd in [60, 300]:
		var scenes := Bench.SCENES.filter(func(s): return s["crowd"] == crowd and not s.has("riders") and (only_scenes.is_empty() or s["name"] in only_scenes))
		if scenes.is_empty():
			continue
		var main = await _boot(native, crowd, "", "")
		var at := 0
		for dir in main.styles:
			var style := String(dir).get_file()
			if not only.is_empty() and not (style in only):
				continue
			main._activate(dir)
			if main.host.pack.style.has("budget"):
				budgets[style] = main.host.pack.style["budget"]
			for scene in scenes:
				while at < int(scene["tick"]):
					main.driver.step_once()
					at += 1
				var s := await _measure(main, style, scene, native, wrong_size)
				if not s.is_empty():
					results.append(s)
			if main.host.first_person:
				main._toggle_fpv()
		main.free()
		await process_frame
	# The tram scene boots its own world in each style, with its riders in
	# the feed, so that its trams are full at its tick in every style.
	var tram_scenes := Bench.SCENES.filter(func(s): return s.has("riders") and (only_scenes.is_empty() or s["name"] in only_scenes))
	for scene in tram_scenes:
		var feed := Bench.tram_feed(CityPaths.district_manifest(), CityPaths.district_feed(), 7, int(scene["crowd"]))
		var finder := StyleHost.new()
		var styles: Array = finder.discover("res://styles")
		finder.free()
		for dir in styles:
			var style := String(dir).get_file()
			if not only.is_empty() and not (style in only):
				continue
			var main = await _boot(native, int(scene["crowd"]), feed, style)
			if main.host.pack.style.has("budget"):
				budgets[style] = main.host.pack.style["budget"]
			while main.driver.world.tick() < int(scene["tick"]):
				main.driver.step_once()
			var s := await _measure(main, style, scene, native, wrong_size)
			if not s.is_empty():
				results.append(s)
			main.free()
			await process_frame
	var f := FileAccess.open(out + "bench.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"results": results, "budgets": budgets, "baseline": baseline}, "  "))
	f.close()
	var breaches := Bench.breaches(results, budgets, baseline) + Bench.reopen_breaches(results)
	for b in breaches:
		if b.has("reopen_worst_ms"):
			print("bench: OVER BUDGET %s %s opening again took a %.1f ms frame > %.1f ms" % [b["style"], b["scene"], b["reopen_worst_ms"], b["budget"]])
		elif b.has("fps"):
			print("bench: OVER BUDGET %s %s %.1f fps < %.1f fps" % [b["style"], b["scene"], b["fps"], b["budget"]])
		elif b.has("missed_pct"):
			print("bench: OVER BUDGET %s %s missed %.2f%% of refreshes > %.2f%%" % [b["style"], b["scene"], b["missed_pct"], b["budget"]])
		else:
			print("bench: OVER BUDGET %s %s p99 %.2f ms > %.2f ms" % [b["style"], b["scene"], b["p99"], b["budget"]])
	for w in wrong_size:
		print("bench: WRONG SIZE " + w)
	print("bench: %d scenes, %d over budget, %d at the wrong size" % [results.size(), breaches.size(), wrong_size.size()])
	quit(1 if not (breaches.is_empty() and wrong_size.is_empty()) else 0)


## A client booted for the bench: fullscreen at `native`, a crowd of
## `crowd`, uncapped, the world paused; starting from `feed` (the
## district's own when "") and in `style` (the first when "").
func _boot(native: Vector2i, crowd: int, feed: String, style: String):
	var main = load("res://main.gd").new()
	main.feed_jsonl = feed
	root.add_child(main)
	var args := ["--crowd=%d" % crowd, "--fps=1000"]
	if style != "":
		args.append("--style=" + style)
	main.boot_for_tool(PackedStringArray(args))
	# A tool boots on default settings, which are windowed.
	main.settings.set_value("graphics", "display", "fullscreen")
	await _fullscreen(native)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	main.driver.pause()
	return main


## Samples `scene` in `style` from the world as it stands: its view (and
## its `centre`) and its screen, the world running at 1x, uncapped and
## then with vsync. Returns its summary, or {} for a first-person scene in
## a style without first person; a size other than `native` goes into
## `wrong_size`. A scene with riders also reports how many each tram
## carried as sampling started, after its uncapped half and at its end
## ("riders_aboard").
func _measure(main, style: String, scene: Dictionary, native: Vector2i, wrong_size: Array) -> Dictionary:
	if scene["view"] == "fpv":
		if not main.host.pack.supports_fpv():
			return {}
		if not main.host.first_person:
			main._toggle_fpv()
	else:
		if main.host.first_person:
			main._toggle_fpv()
		main.host.set_camera(scene["view"])
		Bench.aim(main.host.pack, scene)
	var opens := await _open_screen(main, scene.get("screen", ""))
	var aboard := [_aboard(main)]
	var started := Time.get_unix_time_from_system()
	main.driver.resume()
	for f in Bench.WARMUP_FRAMES:
		await process_frame
	var frames := []
	# The game's own GPU cost per frame, apart from waiting on the
	# display.
	var gpu := []
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var last := Time.get_ticks_usec()
	var t0 := last
	while Time.get_ticks_usec() - t0 < int(Bench.SAMPLE_S * 1e6):
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		last = now
	aboard.append(_aboard(main))
	# Then as a player sees it: vsync at the display's rate, the frames
	# per second and the refreshes missed.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	var hz := DisplayServer.screen_get_refresh_rate()
	hz = hz if hz > 0.0 else 60.0
	for f in 30:
		await process_frame
	var shown := 0
	var missed := 0
	last = Time.get_ticks_usec()
	t0 = last
	while Time.get_ticks_usec() - t0 < int(Bench.SAMPLE_S * 1e6):
		await process_frame
		var now := Time.get_ticks_usec()
		if (now - last) / 1000.0 > 1500.0 / hz:
			missed += 1
		shown += 1
		last = now
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	main.driver.pause()
	aboard.append(_aboard(main))
	var rendered := root.size
	_close_screen(main, scene.get("screen", ""))
	var s := Bench.summary(style, scene["name"], frames)
	s["t0"] = started
	s["t1"] = Time.get_unix_time_from_system()
	s["width"] = rendered.x
	s["height"] = rendered.y
	if Bench.size_breach(rendered, native) != "":
		wrong_size.append("%s %s: %s" % [style, scene["name"], Bench.size_breach(rendered, native)])
	s["heavy"] = scene["heavy"]
	s["gpu_p99"] = Bench.percentile(gpu, 99.0)
	s["hz"] = hz
	s["fps"] = shown / Bench.SAMPLE_S
	s["missed_pct"] = 100.0 * missed / maxf(1.0, shown)
	s.merge(opens)
	if scene.has("riders"):
		s["riders_aboard"] = aboard
		print("bench %-18s %-24s riders aboard each tram: at the start %s, after the uncapped half %s, at the end %s" % [style, scene["name"], str(aboard[0].values()), str(aboard[1].values()), str(aboard[2].values())])
	if not opens.is_empty():
		print("bench %-18s map opening: first %6.1f ms to its picture, worst frame %6.1f ms  |  again %6.1f ms, worst frame %6.1f ms" % [style, opens["open_ms"], opens["open_worst_ms"], opens["reopen_ms"], opens["reopen_worst_ms"]])
	print("bench %-18s %-24s %dx%d p50 %5.2f ms  p99 %5.2f ms  max %6.2f ms  (%d frames)  gpu p99 %5.2f ms  |  vsync %.0f Hz: %5.1f fps, missed %.2f%%" % [style, scene["name"], rendered.x, rendered.y, s["p50"], s["p99"], s["max"], s["frames"], s["gpu_p99"], s["hz"], s["fps"], s["missed_pct"]])
	return s


## How many riders the viewer sees aboard each vehicle now.
func _aboard(main) -> Dictionary:
	return Bench.riders_aboard(JSON.parse_string(main.driver.world.project_json(main.driver.viewer)))


## Fullscreen, and waits (up to three seconds a mode) for the window to
## reach `native`; exclusive fullscreen is tried when plain fullscreen does
## not give it. The caller checks the size it got.
func _fullscreen(native: Vector2i) -> void:
	for mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		var since := Time.get_ticks_msec()
		while root.size != native and Time.get_ticks_msec() - since < 3000:
			await process_frame
		if root.size == native:
			return


## Opens the scene's `screen` over play: the game menu, the title with its
## drifting camera, or the map. The title goes over the running world as a
## launch shows it, but with the bench's player still joined: a Quit to
## title would walk them out, and joining again waits for that. The map is
## opened, closed and opened again, each opening timed (see _time_map);
## returns {open_ms, open_worst_ms, reopen_ms, reopen_worst_ms} for it, and
## nothing for the others.
func _open_screen(main, screen: String) -> Dictionary:
	if screen == "menu":
		main._open_menu()
	elif screen == "title":
		main._show_title()
	elif screen == "map":
		var first := await _time_map(main)
		main.stack.remove(main._map)
		for f in 30:
			await process_frame
		var again := await _time_map(main)
		return {"open_ms": first[0], "open_worst_ms": first[1], "reopen_ms": again[0], "reopen_worst_ms": again[1]}
	return {}


## Opens the map and waits for its picture: [ms until the picture shows,
## the longest frame from the opening until two frames after it shows].
func _time_map(main) -> Array:
	var t0 := Time.get_ticks_usec()
	var last := t0
	main.open_map()
	var map: MapScreen = main._map
	var worst := 0.0
	var shown_ms := -1.0
	var after := 0
	while after < 3 and Time.get_ticks_usec() - t0 < 5000000:
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		if shown_ms < 0.0 and map.base.texture != null:
			shown_ms = (now - t0) / 1000.0
		if shown_ms >= 0.0:
			after += 1
	return [shown_ms, worst]


## Closes what `_open_screen` opened, back to play with the HUD.
func _close_screen(main, screen: String) -> void:
	if screen == "menu":
		main.stack.remove(main._menu)
	elif screen == "title":
		main.host.pack.title_drift(false)
		main.stack.remove(main._title)
		main._title = null
		main.hud.visible = true
	elif screen == "map":
		main.stack.remove(main._map)


## What the display gives an empty scene with vsync: {hz, fps, missed_pct},
## the better of two samples (a desktop hiccup can spoil one).
func _baseline() -> Dictionary:
	var cam := Camera3D.new()
	root.add_child(cam)
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	box.position = Vector3(0, 0, -3)
	root.add_child(box)
	cam.make_current()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	var hz := DisplayServer.screen_get_refresh_rate()
	hz = hz if hz > 0.0 else 60.0
	var best := {}
	for sample in 2:
		for f in 60:
			await process_frame
		var shown := 0
		var missed := 0
		var last := Time.get_ticks_usec()
		var t0 := last
		while Time.get_ticks_usec() - t0 < 3000000:
			await process_frame
			var now := Time.get_ticks_usec()
			if (now - last) / 1000.0 > 1500.0 / hz:
				missed += 1
			shown += 1
			last = now
		var got := {"hz": hz, "fps": shown / 3.0, "missed_pct": 100.0 * missed / maxf(1.0, shown)}
		if best.is_empty() or got["fps"] > best["fps"]:
			best = got
	cam.queue_free()
	box.queue_free()
	await process_frame
	return best
