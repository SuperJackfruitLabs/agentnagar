## Evidence of using things (interactions Part A; needs a display): the
## player sits at each kind of seat and perch in turn, through Use as a
## player would (a Go to the anchor, then Use), and reads the Square's
## noticeboard far away, near it and open. Each is captured with the orbit
## camera turned to face the player (in pixel art, centred on them at the
## closest zoom), lit at 10:30 however long the walks took, the HUD's
## clock set to match, as <out>/interact-<style>-<shot>.png. And the grass
## parting (sway; see _sway).
##
## godot --path city/godot --resolution 1280x800 --script res://tools/probes/capture_interact.gd -- out=$PWD/city/godot/evidence style=anime_cel
##
## `only=<shot>,<shot>` takes some of them: sit-bench, sit-desk,
## sit-cafe-table, sit-reading-chair, sit-steps, sit-low-wall,
## sit-fountain-rim, notice-far, notice-near, notice-open, sway. Two more are
## taken only when named: kiosk-near, the library's kiosk from its stand
## anchor, and kiosk-near-notices, the same with the Square's notices
## (sample content) put on the kiosk's surface for the shot, to show how
## the most text there is fits its narrow face.
## `meadow=<placement id>` takes the sway shot at another meadow.
extends SceneTree

var opts := {"out": "", "style": "anime_cel", "only": ""}
## The perch each perch kind is sat on at, and at which of its anchors.
const PERCHES := [["steps", "placement:library-steps", 1], ["low-wall", "placement:park-wall-1", 2],
	["fountain-rim", "placement:square-fountain", 4]]
## Pixel art's view is fixed, looking north-west, so its perch shots sit at
## anchors that view shows: the steps' west end (the middle one is behind
## a street tree) and the fountain's north-west side (its south side is
## behind the library's roof).
const PIXEL_ANCHORS := {"steps": 2, "fountain-rim": 7}
const SEAT_KINDS := ["bench", "desk", "cafe-table", "reading-chair"]
const NOTICEBOARD := "placement:square-noticeboard"
const KIOSK := "placement:library-kiosk"
const MEADOW := "placement:park-meadow-2"
## Pixel art's fixed view has the second meadow behind a park tree: it
## shows the first.
const PIXEL_MEADOW := "placement:park-meadow-1"
## The time of day every shot is lit at (minutes after midnight).
const SHOT_MINUTES := 630
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
	await _arrive()
	for kind in SEAT_KINDS:
		if _wanted("sit-" + kind):
			var seat := _first_seat(kind)
			await _sit_and_shoot("sit-" + kind, seat, int(seat["anchors"][0]["index"]))
	for p in PERCHES:
		if _wanted("sit-" + p[0]):
			var index: int = PIXEL_ANCHORS.get(p[0], p[2]) if not main.host.pack is Pack3D else p[2]
			await _sit_and_shoot("sit-" + p[0], _thing(p[1]), index)
	await _noticeboard()
	await _kiosk()
	await _sway()
	quit(0)


func _wanted(shot: String) -> bool:
	return opts["only"] == "" or shot in opts["only"].split(",")


## Whether `shot`, taken only when asked for, was.
func _named(shot: String) -> bool:
	return shot in opts["only"].split(",")


func _arrive() -> void:
	for i in 80:
		await _tick()
		if main.player.present and not main.player.view.get("moving", false):
			break


## One tick, and a few frames drawn of it.
func _tick() -> void:
	main.driver.step_once()
	for i in 3:
		await process_frame


func _thing(id: String) -> Dictionary:
	for t in main.interact.things:
		if t["target"] == id:
			return t
	return {}


## The first seat of `kind`, by ID, that the player may sit on now (a
## pod's desk is its agent's).
func _first_seat(kind: String) -> Dictionary:
	var seats: Array = main.interact.things.filter(func(t): return t["type"] == "seat" and t["kind"] == kind)
	seats.sort_custom(func(a, b): return a["target"] < b["target"])
	for seat in seats:
		if "sit" in main.interact.candidate_of(seat, int(seat["anchors"][0]["index"]))["capabilities"]:
			return seat
	return {}


func _anchor(thing: Dictionary, index: int) -> Dictionary:
	for a in thing["anchors"]:
		if a["index"] == index:
			return a
	return {}


## Sits the player at `thing`'s anchor `index` through Use (a Go there,
## then the Use), shoots it from in front, and stands up again.
func _sit_and_shoot(shot: String, thing: Dictionary, index: int) -> void:
	if thing.is_empty():
		push_error("capture_interact: nothing to sit on for " + shot)
		return
	var candidate: Dictionary = main.interact.candidate_of(thing, index)
	var verb: int = candidate["capabilities"].find("sit")
	if verb < 0:
		push_error("capture_interact: %s cannot be sat on now" % shot)
		return
	main._act(candidate, verb)
	for i in 120:
		await _tick()
		var using = main.player.view.get("using")
		if using is Dictionary and using.get("capability") == "sit":
			break
	var using = main.player.view.get("using")
	if not (using is Dictionary and using.get("capability") == "sit"):
		push_error("capture_interact: the player did not sit for %s (%s)" % [shot, main.player.status()])
		return
	# A room seat is taken on the tick the walk there ends: a few more let
	# the walk's last step play out.
	for i in 3:
		await _tick()
	var facing := float(_anchor(thing, index).get("facing", main.player.view.get("facing", 0)))
	# From in front and to one side, low, so the seat and the sitter's
	# height on it show.
	await _shoot(shot, facing + 50.0, -10.0, 3.2)
	main.player.stop_using()
	for i in 4:
		await _tick()


## The noticeboard far away (the player 12 m off), near (at its stand
## anchor) and open (reading it, the overlay over the world).
func _noticeboard() -> void:
	var board := _thing(NOTICEBOARD)
	var stand: Dictionary = board["anchors"].filter(func(a): return a["type"] == "stand")[0]
	var out: Vector2 = (stand["pos"] - board["pos"]).normalized()
	var facing := rad_to_deg(atan2(out.x, -out.y))
	var face := Vector3(board["pos"].x / 100.0, 1.2, board["pos"].y / 100.0)
	if _wanted("notice-far"):
		# The player 12 m out, the camera over their shoulder: the board
		# far off shows only its chip.
		await _walk(stand["pos"] + out * 1200.0)
		# Pixel art's fixed view is centred between the player and the board.
		var between = null if main.host.pack is Pack3D else Vector3((board["pos"].x + stand["pos"].x + out.x * 1200.0) / 200.0, 1.2,
			(board["pos"].y + stand["pos"].y + out.y * 1200.0) / 200.0)
		await _shoot("notice-far", facing + 15.0, -10.0, 4.0, between)
	if _wanted("notice-near") or _wanted("notice-open"):
		await _walk(stand["pos"])
		if _wanted("notice-near"):
			await _shoot("notice-near", facing + 35.0, -8.0, 3.2, face)
		if _wanted("notice-open"):
			main._act(main.interact.candidate_of(board, int(board["anchors"].filter(func(a): return a["type"] == "display")[0]["index"])), 0)
			for i in 20:
				await _tick()
				if main._panel_open():
					break
			await _shoot("notice-open", facing + 35.0, -8.0, 3.2, face)


## The library's kiosk from its stand anchor: as the district has it, and
## with the Square's notices on it (kiosk-near-notices).
func _kiosk() -> void:
	if not (_named("kiosk-near") or _named("kiosk-near-notices")):
		return
	var kiosk := _thing(KIOSK)
	var stand: Dictionary = kiosk["anchors"].filter(func(a): return a["type"] == "stand")[0]
	var out: Vector2 = (stand["pos"] - kiosk["pos"]).normalized()
	var facing := rad_to_deg(atan2(out.x, -out.y))
	var face := Vector3(kiosk["pos"].x / 100.0, 1.3, kiosk["pos"].y / 100.0)
	await _walk(stand["pos"])
	if _named("kiosk-near"):
		await _shoot("kiosk-near", facing - 45.0, -6.0, 2.0, face)
	if _named("kiosk-near-notices"):
		var pack = main.host.pack
		pack.surfaces[KIOSK]["panel"] = pack.surfaces[NOTICEBOARD]["panel"]
		pack.show_surface(KIOSK, pack.surfaces[KIOSK]["level"])
		await _shoot("kiosk-near-notices", facing - 45.0, -6.0, 2.0, face)


## The grass parting. In 3D, the park's second meadow from the south, the
## player first standing just west of it (the grass at rest), then walked
## in toward its middle (the grass parted round them), the two frames side
## by side, without the reticle and the "you" ring on the grass. In pixel
## art, whose fixed view has the meadows under the park's trees, a strip:
## the player walks north to south down the middle of the first meadow,
## a frame every 0.25 s, the view round the meadow enlarged pixel
## for pixel (clumps rest, push over, swing back and rest again).
func _sway() -> void:
	if not _wanted("sway"):
		return
	var lot := Rect2()
	var meadow: String = opts.get("meadow", MEADOW if main.host.pack is Pack3D else PIXEL_MEADOW)
	for p in CityGeometry.placements(main.manifest):
		if p["id"] == meadow:
			lot = CityGeometry.lot(p)
	var image: Image
	if main.host.pack is Pack3D:
		image = await _sway_3d(lot)
	else:
		image = await _sway_strip_2d(lot)
	var path: String = opts["out"].path_join("interact-%s-sway.png" % opts["style"])
	image.save_png(path)
	print("captured ", path)


func _sway_3d(lot: Rect2) -> Image:
	var middle := Vector3(lot.get_center().x, 0.4, lot.get_center().y)
	await _walk(Vector2(lot.position.x - 0.8, lot.get_center().y) * 100.0)
	# Long enough for any grass the walk there brushed to come to rest.
	for i in 90:
		await process_frame
	var before := await _capture(180.0, -32.0, 4.5, middle, true)
	await _walk(lot.get_center() * 100.0)
	# The walk's last steps play out where it is drawn.
	for i in 4:
		await _tick()
	print("sway: the player is drawn at %s, the meadow's middle %s" % [main.host.pack.drawn_ground(main.player.id), lot.get_center()])
	var after := await _capture(180.0, -32.0, 4.5, middle, true)
	return _side_by_side([before, after], 2)


## The strip: 12 frames, 4 across.
func _sway_strip_2d(lot: Rect2) -> Image:
	var pack = main.host.pack
	var x := lot.get_center().x
	await _walk(Vector2(x, lot.position.y - 0.7) * 100.0)
	for i in 90:
		await process_frame
	print("sway strip: starts at ", pack.drawn_ground(main.player.id))
	var frames: Array[Image] = []
	main.player.go_point(Vector2(x, lot.end.y + 0.9) * 100.0)
	var ticked := Time.get_ticks_msec()
	main.driver.step_once()
	for k in 12:
		# A frame of the strip every quarter of a second, a tick every
		# second, as the client runs at speed 1 (by the wall clock: the
		# tool's frames come faster than the screen's).
		var due := Time.get_ticks_msec() + 250
		while Time.get_ticks_msec() < due:
			if Time.get_ticks_msec() - ticked >= 1000:
				ticked += 1000
				main.driver.step_once()
			main.hud.set_clock(SHOT_MINUTES, 0.0)
			pack.set_time_of_day(SHOT_MINUTES)
			pack.camera.zoom = Vector2(3, 3)
			pack.camera.position = (pack.iso(lot.get_center().x, lot.get_center().y) + Vector2(0, -8)).round()
			await process_frame
		await RenderingServer.frame_post_draw
		print("sway strip: the player is drawn at ", pack.drawn_ground(main.player.id))
		frames.append(_enlarged_middle(root.get_viewport().get_texture().get_image(), 5))
	return _side_by_side(frames, 4)


## `images` (all one size) in rows of `across`.
static func _side_by_side(images: Array[Image], across: int) -> Image:
	var size := images[0].get_size()
	var rows := ceili(images.size() / float(across))
	var out := Image.create(size.x * mini(across, images.size()), size.y * rows, false, images[0].get_format())
	for k in images.size():
		out.blit_rect(images[k], Rect2i(Vector2i.ZERO, size), Vector2i(size.x * (k % across), size.y * (k / across)))
	return out


## The middle of `image`, a `times`-th of it each way, scaled back up by
## `times` with no smoothing.
static func _enlarged_middle(image: Image, times: int) -> Image:
	var size := image.get_size() / times
	var out := image.get_region(Rect2i((image.get_size() - size) / 2, size))
	out.resize(size.x * times, size.y * times, Image.INTERPOLATE_NEAREST)
	return out


func _walk(pos: Vector2) -> void:
	main.player.go_point(pos)
	for i in 120:
		await _tick()
		if not main.player.view.get("moving", false) and not main.player.following:
			break


## Stands the orbit camera `distance` metres from `target` (the player's
## chest when null), toward compass `bearing` (degrees clockwise from
## north) and `pitch` (degrees) down, lets it settle, and saves the frame.
func _shoot(shot: String, bearing: float, pitch: float, distance: float, target = null) -> void:
	var image: Image = await _capture(bearing, pitch, distance, target)
	var path: String = opts["out"].path_join("interact-%s-%s.png" % [opts["style"], shot])
	image.save_png(path)
	print("captured ", path)


## The frame _shoot saves: lit, dry and settled, as it describes.
## `unmarked`: the reticle and the "you" ring are left out of it (the
## pack is given a stand-in reticle, out of the scene, to show meanwhile).
func _capture(bearing: float, pitch: float, distance: float, target = null, unmarked := false) -> Image:
	var pack = main.host.pack
	# Every shot in the same late-morning light and dry, however many
	# ticks the walks took.
	main.host._day_to = -1
	main.host._rain_target = 0.0
	main.host.rain = 0.0
	pack.set_rain(0.0)
	pack.set_time_of_day(SHOT_MINUTES)
	if not pack is Pack3D:
		return await _capture_2d(target)
	var rig: OrbitRig = pack.rig
	var reticle = pack.reticle
	var ring = pack.player_marker()
	if unmarked:
		if reticle != null:
			reticle.visible = false
		pack.reticle = Node3D.new()
		if ring != null:
			ring.visible = false
	for i in 30:
		pack.set_daylight(SHOT_MINUTES)
		main.hud.set_clock(SHOT_MINUTES, 0.0)
		var body = pack.nodes.get(main.player.id)
		if target is Vector3:
			rig.position = target
		elif body is Node3D:
			rig.position = Vector3(body.global_position.x, 0.8, body.global_position.z)
		# The rig's camera stands at its +Z turned by its yaw: south at 0.
		rig.yaw = 180.0 - bearing
		rig.pitch = pitch
		rig.distance = distance
		rig.update()
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	if unmarked:
		pack.reticle.free()
		pack.reticle = reticle
		if ring != null:
			ring.visible = true
	return image


## Pixel art's view is fixed, looking north-west: the camera is centred a
## little above the player (or above `target`: well above a display, whose
## text stands over it, just above the ground below 1 m) at the closest
## zoom, three screen pixels a pixel.
func _capture_2d(target) -> Image:
	var pack = main.host.pack
	for i in 30:
		main.hud.set_clock(SHOT_MINUTES, 0.0)
		var at := Vector2.ZERO
		var lift := 0.8
		if target is Vector3:
			at = Vector2(target.x, target.z)
			# A display's text stands on a plate over it.
			lift = 3.5 if target.y >= 1.0 else 0.8
		else:
			var body = pack.nodes.get(main.player.id)
			if body is Node2D:
				at = pack.ground_of(body)
		pack.camera.zoom = Vector2(3, 3)
		pack.camera.position = (pack.iso(at.x, at.y) + Vector2(0, -lift * 16.0)).round()
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()
