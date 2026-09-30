## Finds style packs, switches between them live, and forwards the scene
## model's changes to whichever pack is active: people, and the vehicles
## they ride, each vehicle eased along its line's track over the tick with
## its riders drawn inside it.
extends Node
class_name StyleHost

var pack: StylePack
var pack_dir := ""
var last_error := ""
var names_on := false
var viewer := "public"
var open_all := false
## Roofs stay on when buildings open (C); they always do in first person.
var roofs_on := false
var camera_preset := ""
var cutaway := CutawayRule.new()
## The local player's occupant: marked in every pack, and placed where the
## player's prediction shows it rather than from its trail.
var avatar_id := ""
## Whether the view is first person; kept across style switches that can
## show it.
var first_person := false
## The player's Low graphics quality and calm mode, given to every pack
## activated before it is built and shown (see StylePack).
var quality_low := false
var calm := false
## The player's look settings, given to every pack activated (see
## StylePack.apply_look).
var look_scale := 1.0
var stick_scale := 1.0
var invert_y := false
## The first-person view carried across a style switch.
var _fpv_yaw := 0.0
var _fpv_pitch := -8.0
var _fpv_captured := false
var _facilities := {}
## The minutes daylight eases between over the current tick (-1 before the
## first).
var _day_from := -1.0
var _day_to := -1.0
const DAY_EASE_MAX := 30.0
## How hard it rains now, 0 to 1, eased toward the world's rain so it
## never jumps; and where it is heading.
var rain := 0.0
var _rain_target := 0.0
## How fast shown rain follows the world's, per second.
const RAIN_EASE := 0.5
## id -> the pose the core gives (people are shown walking only while their
## replayed steps move them, and in this pose otherwise).
var _rest := {}
## Ticks a second, for the pace walkers are shown at.
var _rate := 1.0
## People placed at rest on their current track: not placed again until a
## new track arrives, so a standing crowd costs nothing between ticks.
var _settled := {}
## Frames drawn, to spread the moves of walkers out of view.
var _frame := 0
## Each transit line's tracks, by line id: [east, west], in centimetres
## (see CityGeometry.track_points), and its vehicle spec; from the manifest
## the active pack was built from.
var _tracks := {}
var _vehicle_specs := {}
## The displays' surfaces with their panels (see Surfaces.of_layout), given
## to every pack activated, which draws them.
var surfaces: Array = []
## The plants that sway round people in the pack shown (see sway), and
## where people are drawn this frame, kept between frames so gathering
## them allocates nothing.
var soft: SoftContacts
var _bodies := PackedVector2Array()


## A host going away takes its pack's settings with it (the viewport and
## renderer back as the project has them).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and pack != null and is_instance_valid(pack):
		pack.teardown()


## Folders under `root` that hold a style.json, ordered by its "order" and
## then by name.
func discover(root := "res://styles") -> Array:
	var found := []
	var dir := DirAccess.open(root)
	if dir == null:
		return found
	for sub in dir.get_directories():
		var path := root.path_join(sub)
		var style = _read_style(path)
		if style is Dictionary:
			found.append([int(style.get("order", 99)), sub, path])
	found.sort()
	return found.map(func(e): return e[2])


func _read_style(dir: String):
	var f := FileAccess.open(dir.path_join("style.json"), FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


func style_name(dir: String) -> String:
	var s = _read_style(dir)
	return str(s.get("name", dir.get_file())) if s is Dictionary else dir.get_file()


func _fail(message: String) -> bool:
	last_error = message
	push_warning("style pack: " + message)
	return false


## Builds the pack in `dir` and, only if that works, replaces the active one
## and rebuilds the scene from `model`, placing walkers where `motion` has
## them at fraction `t` of the tick.
func activate(dir: String, manifest: Dictionary, model: SceneModel, motion: Motion, t: float) -> bool:
	_settled.clear()
	var style = _read_style(dir)
	if not style is Dictionary:
		return _fail("%s has no readable style.json" % dir)
	var script = load(dir.path_join("pack.gd")) if ResourceLoader.exists(dir.path_join("pack.gd")) else null
	if script == null or not script.can_instantiate():
		return _fail("%s/pack.gd does not load" % dir)
	var next = script.new()
	if not next is StylePack:
		if next is Node:
			next.free()
		return _fail("%s/pack.gd is not a StylePack" % dir)
	next.pack_dir = dir
	next.manifest = manifest
	next.setup(style)
	next.quality_low = quality_low
	next.calm = calm
	next.look_scale = look_scale
	next.stick_scale = stick_scale
	next.invert_y = invert_y
	next.viewer = viewer
	next.player_id = avatar_id
	next.name = dir.get_file()
	add_child(next)
	if not next.build_world(manifest):
		next.free()
		return _fail("%s could not build the world" % dir)
	next.build_scenery(manifest.get("scenery", []))
	next.set_surfaces(surfaces)
	# The avatar's pose is drawn by the client each frame: carry it over.
	var avatar_pose = pack.poses.get(avatar_id) if pack != null else null
	if pack != null:
		if pack.fpv != null:
			_fpv_yaw = pack.fpv.yaw
			_fpv_pitch = pack.fpv.pitch
			_fpv_captured = pack.fpv.captured
		pack.teardown()
		pack.free()
	pack = next
	pack_dir = dir
	last_error = ""
	_map_kept = {}
	pack.on_shown()
	pack.apply_look()
	_read_lines(manifest)
	soft = SoftContacts.from_layout(manifest, StylePack.kinds())
	soft.bind(pack.soft_instances())
	# Vehicles first, so riders have them to ride in.
	for c in model.current_vehicles():
		var v: Dictionary = c["view"]
		if not motion.has(v["id"]):
			_track_vehicle(v, motion)
		pack.spawn_vehicle(v)
		_place_vehicle(v["id"], motion, t)
	for c in model.current():
		var view: Dictionary = c["occupant"]
		pack.spawn(view, avatar_pose if view["id"] == avatar_id and avatar_pose != null else c["pose"])
		_rest[view["id"]] = _rest_pose(view, c["pose"])
		if view.get("vehicle") != null:
			_board(view)
			continue
		_place(view["id"], view, motion, t)
		_show_pose(view["id"], motion, t)
	# The time first, then the rain as it stands (how rain looks depends on
	# whether it is night).
	if model.time >= 0:
		_day_from = model.time
		_day_to = model.time
		pack.set_time_of_day(model.time)
	_rain_target = clampf(float(model.rain) / 100.0, 0.0, 1.0)
	pack.set_rain(rain)
	pack.show_names(names_on)
	_apply_roofs()
	_facilities = CutawayRule.facilities_of(manifest)
	cutaway = CutawayRule.new()
	if camera_preset != "":
		pack.set_camera_preset(camera_preset)
	if first_person:
		first_person = pack.set_fpv(true, _fpv_yaw)
		if first_person:
			pack.fpv.look(0.0, _fpv_pitch - pack.fpv.pitch)
			pack.fpv.captured = _fpv_captured
	return true


## Low quality on or off, now and for every pack activated later. The
## pack shown re-applies its quality, and its rain (which may draw
## reflections only at High).
func set_quality_low(on: bool) -> void:
	quality_low = on
	_map_kept = {}
	if pack != null:
		pack.quality_low = on
		pack.on_shown()
		pack.set_rain(pack.rain)


## Calm mode on or off, now and for every pack activated later; the rain
## shown is redrawn to match.
func set_calm(on: bool) -> void:
	calm = on
	if pack != null:
		pack.calm = on
		pack.set_rain(pack.rain)


## The mouse and stick look sensitivities and invert look Y, now and for
## every pack activated later.
func set_look(mouse_scale: float, stick: float, invert: bool) -> void:
	look_scale = mouse_scale
	stick_scale = stick
	invert_y = invert
	if pack != null:
		pack.look_scale = mouse_scale
		pack.stick_scale = stick
		pack.invert_y = invert
		pack.apply_look()


## First person on (facing `yaw_deg`) or off; true while on.
func set_fpv(on: bool, yaw_deg := 0.0) -> bool:
	first_person = pack != null and pack.set_fpv(on, yaw_deg)
	_apply_roofs()
	return first_person


func set_roofs_on(on: bool) -> void:
	roofs_on = on
	_apply_roofs()


## Inside in first person the ceiling is overhead, so roofs stay; overhead
## they lift unless C keeps them.
func _apply_roofs() -> void:
	if pack != null:
		pack.set_keep_roofs(roofs_on or first_person)


## Opens and closes buildings by the cut-away rule; call once a frame.
func update_cutaway(avatar_room, selected_room) -> void:
	if pack == null:
		return
	var eye = Vector2(pack.fpv.position.x, pack.fpv.position.z) * 100.0 if pack.fpv != null else pack.camera_ground_pos()
	# In first person a building stays whole round you: roof and walls.
	var want := {} if first_person and not open_all else cutaway.update(avatar_room, selected_room, eye, open_all, _facilities)
	for id in _facilities:
		var open := want.has(id)
		if open != pack.is_open(id):
			pack.set_open(id, open)


func set_avatar(id: String) -> void:
	avatar_id = id
	if pack:
		pack.set_player(id)


## Draws the local player's avatar at `pos`, stepping along `dir` (zero at
## rest), in `pose`.
func place_avatar(pos: Vector2, dir: Vector2, pose: String, stride := StylePack.WALK_CM_S) -> void:
	if pack == null or not pack.nodes.has(avatar_id) or pack.riders.has(avatar_id):
		return
	if pack.poses.get(avatar_id) != pose:
		pack.set_pose(avatar_id, pose)
	if pose == "walking":
		pack.set_stride(avatar_id, stride)
	pack.place(avatar_id, pos, dir)


func set_camera(preset: String) -> bool:
	camera_preset = preset
	return pack != null and pack.set_camera_preset(preset)


func _place(id: String, view: Dictionary, motion: Motion, t: float) -> void:
	if pack.riders.has(id):
		return
	if motion.has(id):
		var s := motion.sample(id, t)
		pack.place(id, s["pos"], s["dir"])
	elif view.get("pos") != null:
		pack.place(id, Motion.point(view["pos"]), Vector2.ZERO)


## Forwards scene-model changes to the active pack and keeps `motion` in step.
func apply_changes(changes: Array, motion: Motion) -> void:
	var restyled := {}
	for c in changes:
		match c["type"]:
			"left":
				_settled.erase(c["id"])
				_rest.erase(c["id"])
				motion.clear(c["id"])
				if pack:
					pack.despawn(c["id"])
			"appeared":
				var v: Dictionary = c["occupant"]
				_settled.erase(v["id"])
				if v.get("pos") != null:
					motion.set_track(v["id"], v["pos"], [])
				_rest[v["id"]] = _rest_pose(v, c["pose"])
				restyled[v["id"]] = true
				if pack:
					pack.spawn(v, c["pose"])
					if v.get("vehicle") != null:
						_board(v)
					else:
						_place(v["id"], v, motion, 0.0)
			"aboard":
				_settled.erase(c["id"])
				restyled[c["id"]] = true
				if pack and pack.views.has(c["id"]):
					var v: Dictionary = pack.views[c["id"]].merged({"vehicle": c["vehicle"], "slot": c["slot"], "pos": c["pos"]}, true)
					pack.update_view(v)
					if c["vehicle"] != null:
						_board(v)
					else:
						# Off at the doors: the same node, set down where it
						# stepped off.
						_rest[c["id"]] = "standing"
						pack.step_off(c["id"])
						if c["pos"] != null:
							motion.set_track(c["id"], c["pos"], [])
						_place(c["id"], v, motion, 0.0)
			"pose":
				var riding = pack.views.get(c["id"], {}) if pack else {}
				_rest[c["id"]] = _rest_pose(riding, c["pose"])
				restyled[c["id"]] = true
			"moved":
				_settled.erase(c["id"])
				restyled[c["id"]] = true
				if c.get("pos") != null:
					var trail: Array = c.get("trail", [])
					var start = c.get("from") if c.get("from") != null and not trail.is_empty() else c["pos"]
					motion.set_track(c["id"], start, trail)
			"vehicle_appeared":
				var v: Dictionary = c["view"]
				_settled.erase(v["id"])
				_track_vehicle(v, motion)
				if pack:
					pack.spawn_vehicle(v)
					_place_vehicle(v["id"], motion, 0.0)
			"vehicle_moved":
				_settled.erase(c["id"])
				var v: Dictionary = c["view"]
				_track_vehicle(v, motion)
				if pack:
					pack.update_vehicle(v)
			"doors":
				if pack:
					pack.set_doors(c["id"], c["open"])
			"vehicle_left":
				_settled.erase(c["id"])
				motion.clear(c["id"])
				if pack:
					pack.despawn_vehicle(c["id"])
			"presence":
				if pack:
					pack.set_presence(c["id"], c["headline"])
			"rain":
				_rain_target = clampf(float(c["percent"]) / 100.0, 0.0, 1.0)
			"time":
				_ease_day_to(c["minutes"])
				if pack:
					pack.set_time_of_day(c["minutes"])
					# The sun eases from the last tick's minute: this
					# frame shows it there, not a tick ahead.
					pack.set_daylight(_day_from)
	# Poses follow the steps now being replayed, from the start of the tick.
	for id in restyled:
		_show_pose(id, motion, 0.0)


## The lines' tracks and vehicle specs, from `manifest`.
func _read_lines(manifest: Dictionary) -> void:
	_tracks.clear()
	_vehicle_specs.clear()
	for line in manifest.get("lines", []):
		_tracks[line["id"]] = [CityGeometry.track_points(line, 0), CityGeometry.track_points(line, 1)]
		_vehicle_specs[line["id"]] = line.get("vehicle", {})


## Sets the track vehicle view `v` is eased along this tick: its line's
## track for its direction, over its trail. Without the line it stands at
## its front.
func _track_vehicle(v: Dictionary, motion: Motion) -> void:
	var tracks: Array = _tracks.get(v.get("line"), [])
	var index := 1 if v.get("direction") == "west" else 0
	var track: Array = tracks[index] if index < tracks.size() else []
	motion.set_vehicle_track(v["id"], track, v.get("trail", []), v.get("pos"))


## Stands vehicle `id` where `motion` has it at fraction `t` of the tick,
## facing the way it runs (its view's heading while it stands).
func _place_vehicle(id: String, motion: Motion, t: float) -> void:
	var s := motion.sample(id, t)
	var dir: Vector2 = s["dir"]
	var heading := fposmod(rad_to_deg(atan2(dir.x, -dir.y)), 360.0) if dir != Vector2.ZERO \
		else float(pack.vehicle_views.get(id, {}).get("heading", 90))
	pack.place_vehicle(id, s["pos"], heading)


## The pose `view` rests in: a rider sits in a seat row and stands by the
## doors (CityGeometry.slot_seated); anyone else takes the core's pose.
func _rest_pose(view: Dictionary, pose: String) -> String:
	if view.get("vehicle") == null:
		return pose
	var line = pack.vehicle_views.get(view["vehicle"], {}).get("line") if pack else null
	return "sitting" if CityGeometry.slot_seated(_vehicle_specs.get(line, {}), view.get("slot")) else "standing"


## Draws rider `view` inside its vehicle at its slot, in the pose its slot
## gives (the local player's too: nothing else poses it while it rides).
## A rider whose vehicle is not drawn stands where its view says.
func _board(view: Dictionary) -> void:
	var id: String = view["id"]
	var vehicle_id: String = view["vehicle"]
	if not pack.vehicle_nodes.has(vehicle_id):
		pack.step_off(id)
		if view.get("pos") != null:
			pack.place(id, Motion.point(view["pos"]), Vector2.ZERO)
		return
	var spec: Dictionary = _vehicle_specs.get(pack.vehicle_views[vehicle_id].get("line"), {})
	pack.board(id, vehicle_id, CityGeometry.slot_local(spec, view.get("slot")))
	var pose := _rest_pose(view, "standing")
	_rest[id] = pose
	if pack.poses.get(id) != pose:
		pack.set_pose(id, pose)


## Daylight eases from the last tick's minute to this one's over the tick,
## a tick behind the clock but never jumping. A leap longer than half an
## hour (a restart, a jump in time) is taken at once.
func _ease_day_to(minutes: int) -> void:
	_day_from = minutes if _day_to < 0 or absf(_wrapped(minutes - _day_to)) > DAY_EASE_MAX else _day_to
	_day_to = minutes


func _day_span() -> float:
	return _wrapped(_day_to - _day_from)


## A difference of minutes taken the short way round midnight.
static func _wrapped(d: float) -> float:
	return fposmod(d + 720.0, 1440.0) - 720.0


## Refreshes the views behind name tags (summaries can change without any
## other change).
func refresh_views(model: SceneModel) -> void:
	if pack == null:
		return
	for id in model.occupants:
		if pack.nodes.has(id):
			pack.update_view(model.occupants[id]["view"])


## Each display's level of detail, for someone at `focus_cm` (ground cm,
## or null), with the overlay open on `open_id` and the player targeting
## `target_id` (see StylePack.update_surfaces).
func update_surfaces(focus_cm, open_id := "", target_id := "") -> void:
	if pack != null:
		pack.update_surfaces(focus_cm, open_id, target_id)


## Places every walker but the avatar for fraction `t` of the current tick,
## `rate` ticks a second (0 while paused), walking while shown moving.
func tick_frame(t: float, motion: Motion, rate := 1.0, delta := 0.0) -> void:
	if pack == null:
		return
	_rate = rate
	if rain != _rain_target:
		rain = move_toward(rain, _rain_target, RAIN_EASE * delta)
		pack.set_rain(rain)
	if _day_to >= 0:
		pack.set_daylight(fposmod(_day_from + _day_span() * clampf(t, 0.0, 1.0), 1440.0))
	_frame += 1
	# Vehicles are few: each is eased along its track every frame it runs,
	# carrying its riders, who are never placed themselves.
	for id in pack.vehicle_nodes:
		if not motion.has(id):
			continue
		if motion.pace(id) == 0.0:
			if _settled.has(id):
				continue
			_settled[id] = true
		_place_vehicle(id, motion, t)
	for id in pack.nodes:
		if pack.riders.has(id):
			continue
		if motion.has(id) and id != avatar_id:
			if motion.pace(id) == 0.0:
				if _settled.has(id):
					continue
				_settled[id] = true
			# Out of view, a walker is moved every fourth frame; small on
			# screen, as often as it is animated (each on its own frame).
			else:
				var every := 4 if not pack.is_seen(id) else pack.move_every(id)
				if every > 1 and (_frame + absi(hash(id))) % every != 0:
					continue
			var s := motion.sample(id, t)
			pack.place(id, s["pos"], s["dir"])
			_show_pose(id, motion, t)


## Sways the plants round people (see SoftContacts) where the pack draws
## them this frame: everyone on the ground (riders are inside their
## vehicles), near the camera. Called every frame, once everyone,
## the player too, is placed.
func sway(delta: float) -> void:
	if pack == null or soft == null or soft.instance_count() == 0:
		return
	var centre = pack.sway_centre()
	var count := 0
	if centre is Vector2:
		if _bodies.size() < pack.nodes.size():
			_bodies.resize(pack.nodes.size() + 32)
		for id in pack.nodes:
			if pack.riders.has(id):
				continue
			var at: Vector2 = pack.drawn_ground(id)
			if at.x != INF:
				_bodies[count] = at
				count += 1
	soft.update(centre if centre is Vector2 else Vector2.ZERO, _bodies, count, delta)


## Shows `id` walking, at the pace of its replayed steps, exactly while they
## move it; otherwise in the core's pose, standing where that says walking
## (held up, or its last steps already shown).
func _show_pose(id: String, motion: Motion, t: float) -> void:
	if pack == null or id == avatar_id or not pack.nodes.has(id):
		return
	var pace := motion.pace(id)
	var moving := pace > 0.0 and t < 1.0
	var rest: String = _rest.get(id, "standing")
	var pose := "walking" if moving else ("standing" if rest == "walking" else rest)
	if pack.poses.get(id) != pose:
		pack.set_pose(id, pose)
	if moving:
		pack.set_stride(id, pace * _rate)


## The map's base picture from the pack shown, with the folder of the pack
## that drew it.
signal map_ready(texture: Texture2D, pack_dir: String)


## The last picture the pack shown drew, and what it was asked for:
## {dir, extent, size, texture}, or empty. Kept until another pack is shown
## (a style switch, or the same style shown anew) or the quality changes.
## A stand-in (StylePack.stand_in: nothing could be drawn) is never kept.
var _map_kept := {}
## What the waiting request asks for: {extent, size}.
var _map_wanted := {}


## Asks the pack shown for the district from straight above (see
## StylePack.request_map); its answer comes as `map_ready`. The pack's
## signal is listened to once per request, so a pack switched away never
## answers for the one after it (it is freed, and its answer with it).
## The picture is kept (map spec section 4): the same extent again, at
## the size it was drawn at or smaller, is answered with it, later in the
## same frame, and the pack draws nothing. A larger size (the window grew
## past it) is drawn anew.
func request_map(extent_m: Rect2, size_px: Vector2i) -> void:
	if pack == null:
		return
	if not _map_kept.is_empty() and _map_kept["dir"] == pack_dir and _map_kept["extent"] == extent_m \
			and _map_kept["size"].x >= size_px.x and _map_kept["size"].y >= size_px.y:
		map_ready.emit.call_deferred(_map_kept["texture"], pack_dir)
		return
	var forward := _forward_map.bind(pack_dir)
	# Requests still waiting share the one answer the pack gives them all.
	if not pack.map_ready.is_connected(forward):
		pack.map_ready.connect(forward, CONNECT_ONE_SHOT)
	_map_wanted = {"extent": extent_m, "size": size_px}
	pack.request_map(extent_m, size_px)


func _forward_map(texture: Texture2D, dir: String) -> void:
	# The pack draws the latest request; its answer is kept for it.
	if dir == pack_dir and not _map_wanted.is_empty() and not StylePack.is_stand_in(texture):
		_map_kept = {"dir": dir, "extent": _map_wanted["extent"], "size": _map_wanted["size"], "texture": texture}
	map_ready.emit(texture, dir)


func set_names(on: bool) -> void:
	names_on = on
	if pack:
		pack.show_names(on)


func set_selected(id: String) -> void:
	if pack:
		pack.set_selected(id)
