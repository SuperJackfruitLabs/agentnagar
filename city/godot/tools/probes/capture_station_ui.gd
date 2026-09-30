## Evidence of the station computer's own screen (interactions Part B,
## Task 12; needs a display): opens a workshop desk's computer in Sample
## mode and shoots its desktop (the bezel, undocked: the badge, the
## station name, the dock, "Stand up" — nothing else drawn over it), and
## with `mode=apps`, each of the seven apps in turn. With `mode=watch`, it
## instead crowds the district, waits for an agent to sit at a workshop
## desk, stands the player behind their chair, and opens "Look at screen"
## there, shooting the Chat app it opens onto behind that agent's
## shoulder (Terminal needs Enter played, which watch mode's read-only
## input never sends). Saved as <out>/station-<style>-<shot>.png.
##
## godot --path city/godot --resolution 1280x800 --script res://tools/probes/capture_station_ui.gd -- out=$HOME/.cache/agentnagar-t12 style=lowpoly_tropical mode=apps
## godot --path city/godot --resolution 1280x800 --script res://tools/probes/capture_station_ui.gd -- out=$HOME/.cache/agentnagar-t12 style=lowpoly_tropical mode=watch
extends SceneTree

var opts := {"out": "", "style": "lowpoly_tropical", "mode": "bezel", "desk": "seat:w3"}
const APP_IDS := ["terminal", "chat", "files", "logs", "health", "changes", "work"]
const WORKSHOP_DESKS := ["seat:w1", "seat:w2", "seat:w3", "seat:w4", "seat:w5", "seat:w6", "seat:w7", "seat:w8"]
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
	if opts["mode"] == "watch":
		main.boot_for_tool(PackedStringArray(["--crowd=60", "--fps=1000", "--style=" + opts["style"]]))
		await _watch()
	else:
		main.boot_for_tool(PackedStringArray(["--crowd=0", "--style=" + opts["style"]]))
		await _arrive()
		await _use_and_shoot()
	quit(0)


func _tick() -> void:
	main.driver.step_once()
	for i in 3:
		await process_frame


func _arrive() -> void:
	for i in 80:
		await _tick()
		if main.player.present and not main.player.view.get("moving", false):
			break


func _thing(id: String) -> Dictionary:
	for t in main.interact.things:
		if t["target"] == id:
			return t
	return {}


func _anchor_index(thing: Dictionary, type: String) -> int:
	for a in thing["anchors"]:
		if a["type"] == type:
			return int(a["index"])
	return -1


## Uses `opts["desk"]`'s computer in Sample mode, shoots the desktop, then
## (mode=apps) each app in turn, over the same desk.
func _use_and_shoot() -> void:
	var desk := _thing(opts["desk"])
	if desk.is_empty():
		push_error("capture_station_ui: no such desk " + opts["desk"])
		return
	var use_index := _anchor_index(desk, "use")
	var candidate: Dictionary = main.interact.candidate_of(desk, use_index)
	var verb: int = candidate["capabilities"].find("use")
	main.interaction._act(candidate, verb)
	for i in 200:
		await _tick()
		if main._computer_open():
			break
	if not main._computer_open():
		push_error("capture_station_ui: the computer did not open at %s (%s)" % [desk["target"], main.player.status()])
		return
	for i in 10:
		await process_frame
	var c: ComputerScreen = main.computer
	if c.state == "chooser":
		c.choose(0)
	for i in 10:
		await process_frame
	if c.source is SampleSource:
		# Plays the recording fast, as the app tests do, so a few Enters
		# reach real output within a handful of frames.
		c.source.speed = 200.0
	await _shoot("desktop")
	if opts["mode"] == "apps":
		for id in APP_IDS:
			c.open_app(id)
			for i in 30:
				await process_frame
			if id == "terminal":
				# Plays a little of the recording, rather than shooting
				# its unplayed "press Enter" banner.
				for k in 5:
					c.app.send("\r")
					for i in 60:
						await process_frame
			elif id == "files":
				# A file selected, so the preview shows text rather than
				# "Choose a file to preview it."
				c.app.open_file("Cargo.toml")
				for i in 20:
					await process_frame
			await _shoot("app-" + id)
	c.leave()
	for i in 4:
		await _tick()


## Crowds the district, waits for an agent to sit at a workshop desk, and
## opens "Look at screen" there (the interaction never needs the player
## in reach: see InteractionController._act's "watch" branch).
func _watch() -> void:
	for i in 30:
		await _tick()
	var found := {}
	for i in 400:
		await _tick()
		for id in WORKSHOP_DESKS:
			var desk := _thing(id)
			if desk.is_empty():
				continue
			var stand_index := _anchor_index(desk, "stand")
			if stand_index < 0:
				continue
			var candidate: Dictionary = main.interact.candidate_of(desk, stand_index)
			if candidate["capabilities"].has("watch"):
				found = candidate
				break
		if not found.is_empty():
			break
	if found.is_empty():
		push_error("capture_station_ui: no occupied workstation to watch after 400 ticks")
		return
	var verb: int = found["capabilities"].find("watch")
	main.interaction._act(found, verb)
	for i in 40:
		await _tick()
		if main._computer_open() and main.computer.watch:
			break
	if not (main._computer_open() and main.computer.watch):
		push_error("capture_station_ui: watch mode did not open (%s)" % main.player.status())
		return
	for i in 10:
		await process_frame
	var c: ComputerScreen = main.computer
	# Chat, not Terminal: the terminal needs Enter pressed to play its
	# recording, which watch mode's read-only input can never do, so it
	# would shoot the unplayed banner. Chat's transcript is there already.
	c.open_app("chat")
	for i in 30:
		await process_frame
	await _shoot("watch")
	c.leave()
	for i in 4:
		await _tick()


func _shoot(shot: String) -> void:
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = opts["out"].path_join("station-%s-%s.png" % [opts["style"], shot])
	root.get_viewport().get_texture().get_image().save_png(path)
	print("captured ", path)
