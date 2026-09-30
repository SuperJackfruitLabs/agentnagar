## Plants that sway (interactions spec section 2): a soft shape's clumps
## part as people pass. SoftContacts finds, for the people within 15 m of
## the camera, the clumps their body circle overlaps; in 3D it writes a
## bend impulse (direction and strength) into each clump's instance data,
## which the sway shader springs back within a second; in pixel art the
## clump plays its three rustle frames and returns to rest.
extends TestSuite

const STYLES := ["lowpoly_tropical", "anime_cel", "solarpunk", "neon_noir", "voxel"]
const PIXEL := "pixel_art"
const MEADOW := "placement:park-meadow-2"
const FRAME_S := 1.0 / 60.0
## A walker's pace, metres a second (StylePack.WALK_CM_S).
const WALK_M_S := 1.25


func booted(style: String):
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--as=none", "--style=" + style]))
	assert_true(not main.hud.error_label.visible, "booted: " + main.hud.error_label.text)
	return main


func _lot(main, id: String) -> Rect2:
	for p in CityGeometry.placements(main.manifest):
		if p["id"] == id:
			return CityGeometry.lot(p)
	return Rect2()


## Walks one body from `from` to `to` (metres) at a walker's pace, the
## camera at `centre`, one frame at a time; returns, per clump, the most
## it was bent on the way.
func _walk(soft: SoftContacts, centre: Vector2, from: Vector2, to: Vector2) -> PackedFloat32Array:
	var most := PackedFloat32Array()
	most.resize(soft.instance_count())
	var bodies := PackedVector2Array([from])
	var steps := ceili(from.distance_to(to) / (WALK_M_S * FRAME_S))
	for k in steps + 1:
		bodies[0] = from.lerp(to, float(k) / steps)
		soft.update(centre, bodies, 1, FRAME_S)
		for i in soft.instance_count():
			most[i] = maxf(most[i], soft.bend_of(i))
	return most


## Lets `seconds` pass with nobody near.
func _idle(soft: SoftContacts, seconds: float) -> void:
	for k in roundi(seconds / FRAME_S):
		soft.update(Vector2.ZERO, PackedVector2Array(), 0, FRAME_S)


## The distance from `p` to the segment from `a` to `b`.
static func _off_path(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


func test_a_walker_through_a_meadow_parts_the_grass_and_it_settles_within_a_second() -> void:
	for style in STYLES:
		var main = booted(style)
		var soft: SoftContacts = main.host.soft
		assert_true(soft != null and soft.instance_count() > 0, "%s: the meadows' clumps are soft" % style)
		if soft == null:
			main.free()
			continue
		var lot := _lot(main, MEADOW)
		# From outside the meadow to its middle, where the walker stops.
		var from := Vector2(lot.get_center().x, lot.position.y - 1.0)
		var to := lot.get_center()
		var most := _walk(soft, lot.get_center(), from, to)
		var near := 0
		var far := 0
		for i in soft.instance_count():
			var off := _off_path(soft.instance_point(i), from, to)
			if off < 0.15:
				near += 1
				assert_true(most[i] > 0.5, "%s: the clump at %s, on the walker's path, bent (%.2f)" % [style, soft.instance_point(i), most[i]])
			elif off > 1.0:
				far += 1
				assert_eq(most[i], 0.0, "%s: the clump at %s, a metre off the path, stays still" % [style, soft.instance_point(i)])
		assert_true(near > 5 and far > 5, "%s: clumps on and off the path (%d, %d)" % [style, near, far])
		# The walker goes (out of view): half a second on, the grass is still
		# swinging; a second on, all of it stands still again.
		_idle(soft, 0.5)
		var moving := 0
		for i in soft.instance_count():
			if soft.bend_of(i) != 0.0:
				moving += 1
		assert_true(moving > 0, "%s: the grass springs back rather than snapping (%d still moving)" % [style, moving])
		_idle(soft, 0.5)
		for i in soft.instance_count():
			assert_eq(soft.bend_of(i), 0.0, "%s: clump %d settled within a second" % [style, i])
		main.free()


func test_a_clump_bends_away_from_whoever_brushes_it() -> void:
	var main = booted("lowpoly_tropical")
	var soft: SoftContacts = main.host.soft
	var lot := _lot(main, MEADOW)
	var body := lot.get_center()
	# Past the push's ease-in.
	for k in 6:
		soft.update(body, PackedVector2Array([body]), 1, FRAME_S)
	var touched := 0
	for i in soft.instance_count():
		var at := soft.instance_point(i)
		if soft.bend_of(i) <= 0.0:
			continue
		touched += 1
		assert_true(soft.push_direction(i).dot(at - body) > 0.0, "the clump at %s leans away from the body" % at)
		assert_true(at.distance_to(body) < SoftContacts.BODY_RADIUS_M + soft.reach_of(i) + 1e-3, "only clumps the body circle overlaps")
	assert_true(touched > 2, "a body stood in the grass touches the clumps round it (%d)" % touched)
	main.free()


func test_clumps_beyond_15_m_of_the_camera_are_untouched() -> void:
	var main = booted("anime_cel")
	var soft: SoftContacts = main.host.soft
	var near := _lot(main, "placement:park-meadow-1")
	var beyond := _lot(main, "placement:park-meadow-3")
	# The camera west of the park: the first meadow within 15 m, the third
	# beyond it.
	var centre := Vector2(near.get_center().x - 7.0, near.get_center().y)
	assert_true(centre.distance_to(near.get_center()) < SoftContacts.REACH_M - 1.0, "the first meadow is within reach")
	assert_true(centre.distance_to(beyond.position) > SoftContacts.REACH_M + 1.0, "the third is beyond it")
	var bodies := PackedVector2Array([near.get_center(), beyond.get_center()])
	for k in 10:
		soft.update(centre, bodies, 2, FRAME_S)
	var bent_near := 0
	for i in soft.instance_count():
		var at := soft.instance_point(i)
		if beyond.has_point(at):
			assert_eq(soft.bend_of(i), 0.0, "the clump at %s, beyond 15 m, is untouched" % at)
		elif near.has_point(at) and soft.bend_of(i) > 0.0:
			bent_near += 1
	assert_true(bent_near > 0, "the walker within reach parts the grass")
	main.free()


## Each 3D style's meadow clumps carry per-instance data for the push, and
## draw with the sway shader standing in for their kit material: the same
## colour, with the style's stiffness and tint. Only soft kinds' MultiMeshes
## carry the data.
func test_meadow_clumps_draw_with_the_sway_shader() -> void:
	for style in STYLES:
		var main = booted(style)
		var pack = main.host.pack
		var sway: Dictionary = pack.style.get("sway", {})
		assert_true(sway.has("stiffness") and sway.has("tint"), "%s: style.json has a sway block" % style)
		var chunks: Array = pack.world.find_children("*Meadow*", "MultiMeshInstance3D", true, false)
		assert_true(not chunks.is_empty(), "%s: meadow chunks" % style)
		for n in chunks:
			assert_true(n.multimesh.use_custom_data, "%s: a meadow's clumps carry their push" % style)
			var mesh: Mesh = n.multimesh.mesh
			for s in mesh.get_surface_count():
				var m = mesh.surface_get_material(s)
				assert_true(m is ShaderMaterial and m.has_meta("sway") and m.shader.code.contains("INSTANCE_CUSTOM"),
					"%s: surface %d draws with the sway shader" % [style, s])
				if not m is ShaderMaterial:
					continue
				assert_true(m.get_shader_parameter("stiffness") == float(sway.get("stiffness", 1.0)), "%s: the style's stiffness" % style)
				assert_true(m.get_shader_parameter("tint") == Color(str(sway.get("tint", "#FFFFFF"))), "%s: the style's tint" % style)
				var kit: BaseMaterial3D = m.get_meta("sway")
				assert_true(m.get_shader_parameter("albedo") == kit.albedo_color, "%s: the kit's own colour" % style)
				assert_eq(m.get_shader_parameter("use_vertex_colour"), kit.vertex_color_use_as_albedo, "%s: its vertex colours as the kit's" % style)
				assert_eq(m.shader.code.contains("diffuse_toon"), kit.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON, "%s: toon where the kit's material is" % style)
		for n in pack.world.find_children("*", "MultiMeshInstance3D", true, false):
			if not "Meadow" in str(n.name) and n.multimesh != null:
				assert_true(not n.multimesh.use_custom_data, "%s: %s (not soft) carries no push" % [style, n.name])
		main.free()


## The host sways the grass round people where they are drawn: someone the
## pack draws in the meadow, near the camera, parts it; a rider, inside a
## vehicle, never does.
func test_the_host_parts_the_grass_round_people_where_they_are_drawn() -> void:
	for style in ["solarpunk", PIXEL]:
		var main = booted(style)
		var host: StyleHost = main.host
		var pack = host.pack
		var lot := _lot(main, MEADOW)
		var view := {"id": "person:walker", "kind": {"type": "Human", "tier": "Registered"}, "display_name": "w", "role": "",
			"badge": null, "appearance": {"palette": "3", "hair": "2"}, "seat": null, "presence": {"headline": "Present"},
			"pos": {"x": lot.get_center().x * 100.0, "z": lot.get_center().y * 100.0}}
		pack.spawn(view, "walking")
		pack.place("person:walker", lot.get_center() * 100.0, Vector2(1, 0))
		pack.fly_to(lot.get_center() * 100.0, 0.0)
		if pack is Pack3D:
			pack.rig.position = Vector3(lot.get_center().x, 0.0, lot.get_center().y)
		for k in 3:
			host.sway(FRAME_S)
		var bent := 0
		for i in host.soft.instance_count():
			if host.soft.bend_of(i) > 0.0:
				bent += 1
		assert_true(bent > 0, "%s: the person drawn in the meadow parts it (%d clumps)" % [style, bent])
		main.free()


func test_pixel_art_rustles_over_three_frames_and_returns() -> void:
	var main = booted(PIXEL)
	var pack = main.host.pack
	var soft: SoftContacts = main.host.soft
	var lot := _lot(main, MEADOW)
	var clumps: Array = pack.placement_nodes[MEADOW].get_children()
	pack.set_time_of_day(720)
	var body := lot.get_center()
	var seen := {}
	# Stood in the grass, then gone: the clumps round the body push over,
	# swing back, and come to rest.
	for k in 90:
		var here := 1 if k < 10 else 0
		soft.update(body, PackedVector2Array([body]), here, FRAME_S)
		for c in clumps:
			var frames_: Array = c.get_meta("rustle")
			for f in 3:
				if c.texture.resource_path.get_file().get_basename() == str(frames_[f]).get_file().get_basename():
					seen[f] = seen.get(f, 0) + 1
	assert_true(seen.get(1, 0) > 0, "pixel art: a clump pushed over")
	assert_true(seen.get(2, 0) > 0, "pixel art: and swinging back")
	for c in clumps:
		var frames_: Array = c.get_meta("rustle")
		assert_eq(c.texture.resource_path.get_file(), str(frames_[0]).get_file(), "pixel art: the clump at %s is back at rest" % pack.ground_of(c))
		var a: Array = pack.anchors.get(str(frames_[0]).trim_prefix("assets/"), [0, 0])
		assert_eq(c.offset, Vector2(-a[0], -a[1]), "pixel art: standing on its root again")
	main.free()


func test_a_pixel_rustle_keeps_to_the_time_of_day() -> void:
	var main = booted(PIXEL)
	var pack = main.host.pack
	var soft: SoftContacts = main.host.soft
	var lot := _lot(main, MEADOW)
	pack.set_time_of_day(1320)
	var body := lot.get_center()
	# A body is looked at every other frame.
	for k in 2:
		soft.update(body, PackedVector2Array([body]), 1, FRAME_S)
	var pushed := 0
	for c in pack.placement_nodes[MEADOW].get_children():
		if c.texture.resource_path.get_file().ends_with("_1_night.png"):
			pushed += 1
		assert_true(c.texture.resource_path.ends_with("_night.png"), "pixel art: a clump at night draws its night twin")
	assert_true(pushed > 0, "pixel art: pushed over at night in its night colours")
	# Day breaks while the grass still stands pushed: the frame it shows
	# keeps its place in the rustle.
	pack.set_time_of_day(720)
	var still := 0
	for c in pack.placement_nodes[MEADOW].get_children():
		if c.texture.resource_path.get_file().contains("_1.png"):
			still += 1
	assert_eq(still, pushed, "pixel art: daybreak keeps each clump's frame")
	main.free()


## The 3D clumps' sway material, whose `now` is the contacts' clock.
func _sway_material(main) -> ShaderMaterial:
	var chunk = main.host.pack.world.find_children("*Meadow*", "MultiMeshInstance3D", true, false)[0]
	return chunk.multimesh.mesh.surface_get_material(0)


## The clock starts over every CLOCK_WRAP_S (so a shader's times stay
## exact): grass touched just before it goes on springing back across it,
## its contact time moved back with the clock, and comes to rest within a
## second of the touch.
func test_grass_touched_just_before_the_clock_starts_over_springs_back_across_it() -> void:
	var main = booted("lowpoly_tropical")
	var soft: SoftContacts = main.host.soft
	var body := _lot(main, MEADOW).get_center()
	soft.clock = SoftContacts.CLOCK_WRAP_S - 0.05 - 6.0 * FRAME_S
	for k in 6:
		soft.update(body, PackedVector2Array([body]), 1, FRAME_S)
	var touched := []
	var times := {}
	for i in soft.instance_count():
		if soft.bend_of(i) > 0.0:
			touched.append(i)
			times[i] = soft.custom_data_of(i).a
	assert_true(not touched.is_empty(), "the body in the grass pushes it")
	var at: float = soft.clock
	assert_true(absf(at - (SoftContacts.CLOCK_WRAP_S - 0.05)) < 1e-6, "touched 0.05 s before the clock starts over")
	var wrapped := false
	var elapsed := 0.0
	while elapsed < 1.0:
		soft.update(body, PackedVector2Array(), 0, FRAME_S)
		elapsed += FRAME_S
		if not wrapped and soft.clock < 1.0:
			wrapped = true
			assert_true(absf(_sway_material(main).get_shader_parameter("now") - soft.clock) < 1e-6,
				"the shader's clock starts over with it (%s, %s)" % [_sway_material(main).get_shader_parameter("now"), soft.clock])
			for i in touched:
				var custom: Color = soft.custom_data_of(i)
				assert_true(absf(custom.a - (times[i] - SoftContacts.CLOCK_WRAP_S)) < 1e-4 and custom.a < 0.0,
					"clump %d's contact time moved back with the clock (%.4f, was %.4f)" % [i, custom.a, times[i]])
		if elapsed > 0.2 and elapsed < 0.25:
			var moving := touched.filter(func(i): return soft.bend_of(i) > 0.0)
			assert_true(not moving.is_empty(), "the grass is still springing back after the clock starts over")
	assert_true(wrapped, "the clock started over")
	for i in touched:
		assert_eq(soft.bend_of(i), 0.0, "clump %d is upright within a second of the touch" % i)
	main.free()


## The sway shader's own defaults are SoftContacts' curve, as the packs
## set it (Pack3D sets each at runtime; a material made without them still
## draws the same spring).
func test_the_sway_shaders_defaults_are_soft_contacts_curve() -> void:
	var code: String = Pack3D.SWAY_SHADER.code
	var want := {"attack_s": SoftContacts.ATTACK_S, "hold_s": SoftContacts.HOLD_S, "spring_end_s": SoftContacts.SPRING_END_S,
		"spring_decay": SoftContacts.SPRING_DECAY, "spring_rate": SoftContacts.SPRING_RATE, "spring_fade_s": SoftContacts.SPRING_FADE_S}
	for name in want:
		var m := RegEx.create_from_string("uniform float %s = ([0-9.]+);" % name).search(code)
		assert_true(m != null, "the shader declares %s with a default" % name)
		if m != null:
			assert_eq(float(m.get_string(1)), float(want[name]), "%s's default" % name)


## Grass touched long before the clock starts over, and long since
## still, stays still after it: the shader's `now` restarts from 0, so a
## clump left with its old contact time and push would bend again as that
## time comes round. At the wrap every touched clump's custom data is
## written again, a settled clump's with no push. (The MultiMesh's own
## custom data is not readable headless: SoftContacts keeps what it wrote.)
func test_grass_long_settled_when_the_clock_starts_over_is_given_no_push() -> void:
	var main = booted("lowpoly_tropical")
	var soft: SoftContacts = main.host.soft
	soft.record_writes = true
	var body := _lot(main, MEADOW).get_center()
	soft.clock = SoftContacts.CLOCK_WRAP_S - 30.0
	for k in 6:
		soft.update(body, PackedVector2Array([body]), 1, FRAME_S)
	var settled: Array = soft.written.keys()
	assert_true(not settled.is_empty(), "the body in the grass pushes it")
	_idle(soft, 2.0)
	for i in settled:
		assert_eq(soft.bend_of(i), 0.0, "clump %d has settled" % i)
	soft.clock = SoftContacts.CLOCK_WRAP_S - FRAME_S * 0.5
	soft.update(body, PackedVector2Array(), 0, FRAME_S)
	assert_true(soft.clock < 1.0, "the clock started over")
	for i in settled:
		var custom: Color = soft.written[i]
		assert_true(custom.a <= soft.clock,
			"clump %d's contact time moved back with the clock (%.4f, now %.4f)" % [i, custom.a, soft.clock])
		assert_eq(Vector2(custom.r, custom.g), Vector2.ZERO, "clump %d is given no push" % i)
	main.free()


## A clump someone brushes again while it swings back never jumps: the
## new push takes it on from where it is drawn, toward the new push (a lean
## across it, which a clump has only when the push comes from a new side,
## is let go). The clock is held still over the push, so any change is the
## push's alone.
func test_a_clump_pushed_again_mid_swing_moves_on_from_where_it_is() -> void:
	var main = booted("lowpoly_tropical")
	var soft: SoftContacts = main.host.soft
	var body := _lot(main, MEADOW).get_center()
	for k in 10:
		soft.update(body, PackedVector2Array([body]), 1, FRAME_S)
	var near := []
	for i in soft.instance_count():
		if soft.bend_of(i) > 0.3:
			near.append(i)
	assert_true(not near.is_empty(), "clumps pushed over")
	# Let the clumps swing back, then brush them again from a little
	# farther along, at each stage of the swing.
	var pushed_again := 0
	for wait in [0.1, 0.2, 0.25, 0.3, 0.4, 0.5]:
		for k in 10:
			soft.update(body, PackedVector2Array([body]), 1, FRAME_S)
		for k in roundi(wait / FRAME_S):
			soft.update(body, PackedVector2Array(), 0, FRAME_S)
		var before := {}
		var custom := {}
		for i in near:
			before[i] = soft.push_direction(i) * soft.signed_bend_of(i, soft.push_direction(i))
			custom[i] = soft.custom_data_of(i)
		# Twice, so the body is looked at (every other frame).
		for k in 2:
			soft.update(body, PackedVector2Array([body + Vector2(0.05, 0.0)]), 1, 0.0)
		for i in near:
			if soft.custom_data_of(i) == custom[i]:
				continue
			pushed_again += 1
			var toward: Vector2 = soft.push_direction(i)
			var was: float = before[i].dot(toward)
			var now: float = soft.signed_bend_of(i, toward)
			assert_true(absf(now - was) < 0.01, "%.2f s into its swing, clump %d moves on from %.2f, not jumping to %.2f" % [wait, i, was, now])
	assert_true(pushed_again > 10, "clumps were pushed again mid-swing (%d)" % pushed_again)
	main.free()


## Grass eases into a push: someone already standing in it as it comes
## within reach bends it over a few frames, not in one.
func test_grass_eases_into_a_push() -> void:
	var main = booted("lowpoly_tropical")
	var soft: SoftContacts = main.host.soft
	var body := _lot(main, MEADOW).get_center()
	var far := body + Vector2(SoftContacts.REACH_M + 5.0, 0.0)
	soft.update(far, PackedVector2Array([body]), 1, FRAME_S)
	for i in soft.instance_count():
		assert_eq(soft.bend_of(i), 0.0, "beyond reach, clump %d stands" % i)
	var most := 0.0
	var steps := []
	for k in 8:
		soft.update(body, PackedVector2Array([body]), 1, FRAME_S)
		var frame_most := 0.0
		for i in soft.instance_count():
			frame_most = maxf(frame_most, soft.bend_of(i))
		steps.append(frame_most)
	assert_true(steps[0] < 0.2, "the first frame in reach barely bends it (%.2f)" % steps[0])
	for k in range(1, steps.size()):
		assert_true(steps[k] - steps[k - 1] < 0.35, "no frame jumps (%s)" % [steps])
	assert_true(steps[-1] > 0.8, "and it is bent right over by %d frames (%.2f)" % [steps.size(), steps[-1]])
	assert_true(SoftContacts.spring(0.0) == 0.0 and SoftContacts.spring(SoftContacts.ATTACK_S) == 1.0, "the spring eases in from upright")
	assert_eq(SoftContacts.spring(SoftContacts.SETTLE_S - 0.01), 0.0, "and is upright again within a second")
	main.free()


## A rustle frame shows its textures and anchor as they were made when the
## meadow was planted: changing frames loads and builds nothing.
func test_a_pixel_rustle_frame_uses_textures_made_at_planting() -> void:
	var main = booted(PIXEL)
	var pack = main.host.pack
	var clump: Sprite2D = pack.placement_nodes[MEADOW].get_children()[0]
	var look: Array = clump.get_meta("rustle_look")
	assert_eq(look.size(), 3, "day textures, night textures, offsets")
	for f in 3:
		pack.show_rustle(clump, f)
		assert_true(clump.texture == look[0][f], "frame %d's day texture, made at planting" % f)
		assert_eq(clump.offset, look[2][f], "frame %d's anchor" % f)
	pack.set_time_of_day(1320)
	pack.show_rustle(clump, 1)
	assert_true(clump.texture == look[1][1], "and its night twin")
	main.free()
