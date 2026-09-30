## Evidence of the workstation (interactions Part B, Task 11; needs a
## display): the Guild hall workshop's desks with every screen idle, every
## screen in use (by day and at night), the player's own desk live (its
## monitor showing the station computer, Sample station's terminal, through
## the feed; in pixel art, the glow), and at night a mix: the player's own
## desk live, the desk to its left and two behind it in use, the rest (the
## one to its right among them) idle. For the
## live shots the computer's screen stack is moved off the window, which
## moves nothing the feed draws, so the world shows round the desk. Saved
## as <out>/workstation-<style>-<shot>.png.
##
## godot --path city/godot --resolution 1280x800 --script res://tools/probes/capture_workstation.gd -- out=$HOME/.cache/agentnagar-t11 style=anime_cel
extends SceneTree

var opts := {"out": "", "style": "anime_cel", "desk": "seat:w3"}
## The desks shown in use in the mixed shot (the player's is seat:w3).
const MIXED_IN_USE := ["seat:w2", "seat:w6", "seat:w7"]
## Day and night, minutes after midnight.
const DAY := 630
const NIGHT := 1290
var main


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			opts[kv[0]] = kv[1]
	await process_frame
	DirAccess.make_dir_recursive_absolute(opts["out"])
	main = load("res://main.gd").new()
	root.add_child(main)
	main.boot_for_tool(PackedStringArray(["--crowd=0", "--style=" + opts["style"]]))
	for i in 80:
		await _tick()
		if main.player.present and not main.player.view.get("moving", false):
			break
	var desk := _thing(opts["desk"])
	await _live(desk)
	# The rest with the world held still, every screen set as the shot says.
	for i in 10:
		await process_frame
	var pack = main.host.pack
	for state in ["idle", "in_use"]:
		for id in pack.screens:
			pack.show_screen(id, state)
		await _shoot(state.replace("_", "-"), desk, DAY, 4.2)
	await _shoot("in-use-night", desk, NIGHT, 4.2)
	quit(0)


func _tick() -> void:
	main.driver.step_once()
	for i in 3:
		await process_frame


func _thing(id: String) -> Dictionary:
	for t in main.interact.things:
		if t["target"] == id:
			return t
	return {}


## Uses `desk`'s computer, opens Sample station's terminal, and shoots the
## desk with the computer's stack moved off the window.
func _live(desk: Dictionary) -> void:
	var candidate: Dictionary = main.interact.candidate_of(desk, 1)
	var verb: int = candidate["capabilities"].find("use")
	main.interaction._act(candidate, verb)
	for i in 200:
		await _tick()
		if main._computer_open():
			break
	if not main._computer_open():
		push_error("capture_workstation: the computer did not open at %s (%s)" % [desk["target"], main.player.status()])
		return
	for i in 10:
		await process_frame
	var c: ComputerScreen = main.computer
	if c.state == "chooser":
		c.choose(0)
	c.open_app("terminal")
	for i in 120:
		await process_frame
	main.stack.offset = Vector2(100000, 0)
	await _shoot("live", desk, DAY, 2.0)
	# The mix: in use to the left of the player's own desk and behind it,
	# idle to its right and elsewhere.
	var pack = main.host.pack
	for id in pack.screens:
		if id != desk["target"]:
			pack.show_screen(id, "in_use" if id in MIXED_IN_USE else "idle")
	await _shoot("mixed-night", desk, NIGHT, 5.5)
	if main.monitor.feed != null:
		var feed: Image = main.monitor.feed.get_texture().get_image()
		feed.resize(feed.get_width() * 4, feed.get_height() * 4, Image.INTERPOLATE_NEAREST)
		feed.save_png(opts["out"].path_join("workstation-%s-feed.png" % opts["style"]))
	main.stack.offset = Vector2.ZERO
	c.leave()
	for i in 4:
		await _tick()


## The desk's monitor from behind its chair and to one side (in pixel art,
## centred on the desk at the closest zoom), lit at `minutes`, saved.
func _shoot(shot: String, desk: Dictionary, minutes: int, distance: float) -> void:
	var pack = main.host.pack
	main.host._day_to = -1
	main.host._rain_target = 0.0
	main.host.rain = 0.0
	pack.set_rain(0.0)
	var id: String = desk["target"]
	var at: Vector2 = pack.screen_point(id) if pack.screen_point(id) != null else desk["pos"] / 100.0
	var facing := 0.0
	for a in desk["anchors"]:
		if a["type"] == "sit":
			facing = float(a["facing"])
	for i in 30:
		pack.set_time_of_day(minutes)
		main.hud.set_clock(minutes, 0.0)
		if pack is Pack3D:
			pack.set_daylight(minutes)
			var rig: OrbitRig = pack.rig
			rig.position = Vector3(at.x, 1.0, at.y)
			# Behind the chair, a little to the right: the rig's camera
			# stands at its +Z turned by its yaw, south at 0.
			rig.yaw = 180.0 - (facing + 180.0 + 25.0)
			rig.pitch = -14.0
			rig.distance = distance
			rig.update()
		else:
			pack.camera.zoom = Vector2(3, 3)
			pack.camera.position = (pack.iso(at.x, at.y) + Vector2(0, -16.0)).round()
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = opts["out"].path_join("workstation-%s-%s.png" % [opts["style"], shot])
	root.get_viewport().get_texture().get_image().save_png(path)
	print("captured ", path, " ", pack.screens.get(id, {}).get("state", "?"))
