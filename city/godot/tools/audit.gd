extends SceneTree
## Audit captures: the running client (HUD on, a registered player joined,
## a crowd of 60) in every style at every camera preset by day and night,
## cut away, in first person, and close-ups of the player, the square, the
## workshop and the library, and the open city (the bridge, the north edge
## and the quay) — 48 scenes to look through after any change.
##   godot --path godot --resolution 1600x900 --script res://tools/audit.gd
## Written to ~/.cache/agentnagar-audit/ (the Flatpak cannot write /tmp).
var main
var out := OS.get_environment("HOME") + "/.cache/agentnagar-audit/"

func shot(name: String, settle := 20) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + name + ".png")
	print("shot ", name)

func style(s: String) -> void:
	for d in main.styles:
		if d.get_file() == s:
			main._activate(d)

func views(phase: String) -> void:
	for s in ["lowpoly_tropical", "voxel", "pixel_art"]:
		style(s)
		var short: String = s.get_slice("_", 0)
		for preset in ["topdown", "diagonal", "street"]:
			main.host.set_camera(preset)
			main.host.open_all = false
			await shot("%s-%s-%s" % [short, phase, preset])
		main.host.set_camera("diagonal")
		main.host.open_all = true
		await shot("%s-%s-open" % [short, phase])
		main.host.open_all = false
		if s != "pixel_art":
			main._toggle_fpv()
			await shot("%s-%s-fpv" % [short, phase])
			main._toggle_fpv()

func _init():
	await process_frame
	main = load("res://main.gd").new()
	root.add_child(main)
	main.boot_for_tool(PackedStringArray(["--crowd=60"]))
	main.driver.pause()
	DirAccess.make_dir_recursive_absolute(out)
	for i in 120:
		main.driver.step_once()
	# Walk the player out onto the platform, clear of the shelter.
	main.player.go_point(Vector2(-600, 900))
	for i in 15:
		main.driver.step_once()
	await views("day")
	# Close-ups: the player's avatar, and people in the square and at work.
	for s in ["lowpoly_tropical", "voxel"]:
		style(s)
		var rig = main.host.pack.rig
		var at: Vector2 = main.player.shown / 100.0
		rig.position = Vector3(at.x, 0.9, at.y)
		rig.yaw = 200.0
		rig.pitch = -18.0
		rig.distance = 5.0
		rig.update()
		await shot("%s-close-player" % s.get_slice("_", 0))
		rig.position = Vector3(0, 0.8, 2)
		rig.distance = 12.0
		rig.update()
		await shot("%s-close-square" % s.get_slice("_", 0))
		main.host.open_all = true
		rig.position = Vector3(-26, 0.8, -4)
		rig.yaw = 20.0
		rig.pitch = -45.0
		rig.distance = 20.0
		rig.update()
		await shot("%s-close-workshop" % s.get_slice("_", 0), 60)
		rig.position = Vector3(27, 0.8, -2)
		rig.update()
		await shot("%s-close-library" % s.get_slice("_", 0), 60)
		main.host.open_all = false
	style("pixel_art")
	var cam: Camera2D = main.host.pack.camera
	cam.zoom = Vector2(3, 3)
	cam.position = main.host.pack.iso(main.player.shown.x / 100.0, main.player.shown.y / 100.0)
	await shot("pixel-close-player")
	main.host.open_all = true
	cam.position = main.host.pack.iso(-26.0, -6.0)
	await shot("pixel-close-workshop")
	cam.position = main.host.pack.iso(27.0, -2.0)
	await shot("pixel-close-library")
	main.host.open_all = false
	# The open city: the player out on the bridge, the railing at the
	# north edge and along the quay.
	print("go to the bridge: ", main.player.go_point(Vector2(-5600, 2300)))
	for i in 70:
		main.driver.step_once()
	var deck: Vector2 = Motion.point(main.player.view["pos"]) / 100.0
	print("on the bridge at ", deck, " in ", main.nav.room_at(main.player.cell))
	for s in ["lowpoly_tropical", "voxel"]:
		style(s)
		var rig = main.host.pack.rig
		var at: Vector2 = deck
		for spot in [["bridge", Vector3(at.x, 0.9, at.y), 160.0, -22.0, 9.0],
				["edge", Vector3(8.0, 0.8, -63.0), 180.0, -30.0, 16.0],
				["quay", Vector3(-43.0, 0.8, -8.0), 250.0, -28.0, 16.0]]:
			rig.position = spot[1]
			rig.yaw = spot[2]
			rig.pitch = spot[3]
			rig.distance = spot[4]
			rig.update()
			await shot("%s-open-%s" % [s.get_slice("_", 0), spot[0]])
	style("pixel_art")
	cam = main.host.pack.camera
	cam.zoom = Vector2(2, 2)
	for spot in [["bridge", deck], ["edge", Vector2(8.0, -63.0)], ["quay", Vector2(-43.0, -8.0)]]:
		cam.position = main.host.pack.iso(spot[1].x, spot[1].y)
		await shot("pixel-open-%s" % spot[0])
	for i in 195:
		main.driver.step_once()
	await views("night")
	quit()
