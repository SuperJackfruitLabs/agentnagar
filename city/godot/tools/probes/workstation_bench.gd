## The workstation's frame spot check (interactions Part B, Task 11; needs
## a display): one style, fullscreen at the display's native size, a crowd
## of 60 at 13:00, the diagonal view over the Guild hall workshop, its
## eight desks' screens in use (where the build draws screens: an older
## build without them draws its stand-ins), the world held still. Samples
## uncapped frame times for Bench.SAMPLE_S after a warm-up and the game's
## own GPU time per frame, and writes {style, build, p50, p99, gpu_p99,
## width, height} to `out`. Runs the same on an older build, for an A/B in
## one session.
##
## godot --path city/godot --script res://tools/probes/workstation_bench.gd -- style=voxel build=head out=$HOME/.cache/agentnagar-t11/bench-voxel-head.json
extends SceneTree

var opts := {"style": "lowpoly_tropical", "build": "head", "out": ""}
## The workshop's middle, cm, and its eight desks.
const WORKSHOP := Vector2(-2600, -750)
const DESKS := ["seat:w1", "seat:w2", "seat:w3", "seat:w4", "seat:w5", "seat:w6", "seat:w7", "seat:w8"]


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			opts[kv[0]] = kv[1]
	await process_frame
	var native := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var main = load("res://main.gd").new()
	root.add_child(main)
	main.boot_for_tool(PackedStringArray(["--crowd=60", "--fps=1000", "--style=" + opts["style"]]))
	main.settings.set_value("graphics", "display", "fullscreen")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	var since := Time.get_ticks_msec()
	while root.size != native and Time.get_ticks_msec() - since < 3000:
		await process_frame
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	while main.driver.world.tick() < 150:
		main.driver.step_once()
	main.driver.pause()
	main.host.set_camera("diagonal")
	for i in 5:
		await process_frame
	Bench.aim(main.host.pack, {"centre": WORKSHOP})
	var pack = main.host.pack
	var lit := 0
	for f in Bench.WARMUP_FRAMES:
		if "screens" in pack:
			for id in DESKS:
				if pack.screens.has(id):
					pack.show_screen(id, "in_use")
					lit += 1 if f == 0 else 0
		await process_frame
	var frames := []
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
	var s := Bench.summary(opts["style"], "workshop", frames)
	s["build"] = opts["build"]
	s["gpu_p99"] = Bench.percentile(gpu, 99.0)
	s["gpu_p50"] = Bench.percentile(gpu, 50.0)
	s["width"] = root.size.x
	s["height"] = root.size.y
	s["screens_lit"] = lit
	print("workstation bench %-18s %-5s %dx%d p50 %5.2f ms  p99 %5.2f ms  gpu p50 %5.2f ms  gpu p99 %5.2f ms  (%d frames, %d screens lit)" % [
		opts["style"], opts["build"], root.size.x, root.size.y, s["p50"], s["p99"], s["gpu_p50"], s["gpu_p99"], s["frames"], lit])
	if opts["out"] != "":
		var f := FileAccess.open(opts["out"], FileAccess.WRITE)
		f.store_string(JSON.stringify(s))
		f.close()
	main.free()
	quit(0)
