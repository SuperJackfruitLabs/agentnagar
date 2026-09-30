## Views of the city from chosen places (needs a display): the orbit
## camera aimed at a point, turned and pitched, as PNGs under `out`, named
## <style>_<view>.png. The placement evidence (evidence/placement-<style>-
## street.png and -diagonal.png) is taken with:
##
## godot --path city/godot --resolution 1600x900 --script res://tools/probes/capture_views.gd -- out=$HOME/captures style=anime_cel crowd=40 ticks=30 "views=street:4,12,-40,-10,16;diagonal:2,8,-35,-38,34"
##
## A view is name:x,z,yaw,pitch,distance (metres and degrees); `roofs=off`
## lifts the roofs, and `open=all` opens every building by the cut-away
## rule (as --open-all does), which is how pixel art shows its interiors.
## A 2D (isometric) style has one fixed angle, so there the view centres
## x,z and takes `distance` as its zoom (1, 2, 3 ...), yaw and pitch unused:
##
## godot --path city/godot --resolution 1280x662 --script res://tools/probes/capture_views.gd -- out=$HOME/captures style=pixel_art crowd=40 ticks=30 "views=street:0,12,0,0,3;diagonal:0,6,0,0,1"
##
## The seated-occupant evidence (evidence/placement-anime_cel-seated-desk.png,
## -seated-bench.png and placement-pixel_art-seated.png) is taken at tick
## 150, when the workshop's desks and the commons' benches are all taken:
##
## godot --path city/godot --resolution 1600x900 --script res://tools/probes/capture_views.gd -- out=$HOME/captures style=anime_cel crowd=60 ticks=150 roofs=off "views=seated-desk:-30.5,-10,-20,-25,3.5;seated-bench:-31,6,70,-20,3.5"
## godot --path city/godot --resolution 1280x662 --script res://tools/probes/capture_views.gd -- out=$HOME/captures style=pixel_art crowd=60 ticks=150 open=all "views=seated:-29,-2,0,0,3"
extends SceneTree

var opts := {"out": "", "style": "anime_cel", "views": "", "crowd": "0", "ticks": "0", "roofs": "on", "open": ""}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			opts[kv[0]] = kv[1]
	await process_frame
	DirAccess.make_dir_recursive_absolute(opts["out"])
	var main = load("res://main.gd").new()
	root.add_child(main)
	var args := PackedStringArray(["--crowd=" + opts["crowd"], "--as=none", "--no-hud", "--style=" + opts["style"]])
	if opts["open"] == "all":
		args.append("--open-all")
	main.boot_for_tool(args)
	for i in int(opts["ticks"]):
		main.driver.step_once()
	for i in 5:
		await process_frame
	var pack = main.host.pack
	if opts["roofs"] == "off":
		main.host.set_roofs_on(false)
	for v in opts["views"].split(";"):
		var parts: PackedStringArray = v.split(":")
		var n := PackedFloat64Array(Array(parts[1].split(",")).map(func(x): return float(x)))
		if pack.get("rig") == null:
			pack.camera.position = pack.iso(n[0], n[1]).round()
			pack.camera.zoom = Vector2(n[4], n[4])
		else:
			var rig: OrbitRig = pack.rig
			rig.position = Vector3(n[0], 0, n[1])
			rig.yaw = n[2]
			rig.pitch = n[3]
			rig.distance = n[4]
			rig.update()
		for i in 15:
			await process_frame
		await RenderingServer.frame_post_draw
		var path: String = opts["out"].path_join("%s_%s.png" % [opts["style"], parts[0]])
		root.get_viewport().get_texture().get_image().save_png(path)
		print("captured ", path)
	quit(0)
