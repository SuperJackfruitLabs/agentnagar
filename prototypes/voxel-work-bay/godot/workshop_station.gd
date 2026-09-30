extends RefCounted
## One resident owns its fixture, route, imported rig, animation and chair.
const Movement = preload("res://movement_controller.gd")
const Fixture = preload("res://fixture_model.gd")
var movement = Movement.new()
var fixture = Fixture.new()
var origin := Vector3.ZERO
var resident := ""
var actor: Node3D
var chair: Node3D
var player: AnimationPlayer
var clips := {}
var current_clip := ""
var chair_body: StaticBody3D
var actor_body: StaticBody3D
var skeleton: Skeleton3D
var label: Label3D
var waiting := false
var missing: Array[String] = []

func build(world: Node3D, identity: String, point: Vector3) -> void:
	resident = identity
	origin = point
	for entry in [["desk", Vector3.ZERO], ["terminal", Vector3(0,0.78,0.12)], ["chair", Movement.SEAT], [resident, Movement.SEAT]]:
		var node: Node3D = world.load_asset(entry[0] + ".glb", origin + entry[1])
		if node == null:
			missing.append(entry[0])
			continue
		if entry[0] == "chair": chair = node
		if entry[0] == resident: actor = node
	chair_body = world.add_box(resident + "Chair", origin + Movement.SEAT + Vector3(0,0.45,-0.03), Vector3(0.65,0.9,0.65))
	world.add_box(resident + "Desk", origin + Vector3(0,0.4,0), Vector3(1.75,0.8,0.78))
	actor_body = world.add_box(resident + "Actor", origin + Movement.SEAT + Vector3(0,0.75,0), Vector3(0.8,1.5,0.8))
	if actor != null:
		var skeletons := actor.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty(): skeleton = skeletons[0]
		var players := actor.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			player = players[0]
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			for imported in player.get_animation_list():
				var short_name := str(imported).get_slice("/", str(imported).get_slice_count("/") - 1)
				short_name = short_name.get_slice("|", short_name.get_slice_count("|") - 1).to_lower()
				if Fixture.CLIPS.has(short_name):
					clips[short_name] = imported
					player.get_animation(imported).loop_mode = Animation.LOOP_NONE if short_name in ["sit_down", "stand_up"] else Animation.LOOP_LINEAR
	label = Label3D.new()
	label.font_size = 32
	label.pixel_size = 0.008
	label.modulate = Color("22314b")
	label.outline_modulate = Color("fffaf0")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	world.add_child(label)
	validate()
	refresh()

func validate() -> bool:
	movement.available = actor != null and chair != null and player != null
	if actor != null and actor.find_children("*", "MeshInstance3D", true, false).is_empty(): movement.available = false
	if chair != null and chair.find_children("*", "MeshInstance3D", true, false).is_empty(): movement.available = false
	for clip in Fixture.CLIPS:
		if not clips.has(clip): movement.available = false
	return movement.available

func snapshot() -> Dictionary:
	var result := {}
	for key in ["phase", "elapsed", "actor_position", "chair_position", "yaw", "destination", "_steps", "_start", "_chair_start", "_yaw_start"]:
		var value = movement.get(key)
		result[key] = value.duplicate(true) if value is Array else value
	return result

func restore(saved: Dictionary) -> void:
	for key in saved: movement.set(key, saved[key])

func refresh(delta: float = 0) -> void:
	if actor != null:
		actor.position = origin + movement.actor_position
		actor.rotation.y = movement.yaw
	if chair != null: chair.position = origin + movement.chair_position
	chair_body.position = origin + movement.chair_position + Vector3(0,0.45,-0.03)
	actor_body.position = origin + movement.actor_position + Vector3(0,0.75,0)
	label.position = origin + movement.actor_position + Vector3(0,2.0,0)
	label.text = resident.capitalize() + " · " + fixture.state + ("\nWaiting for visitor" if waiting else "\n" + movement.phase)
	var wanted: String = "typing" if fixture.state == "working" else "seated_idle"
	if movement.phase != "seated": wanted = movement.clip()
	if player != null and clips.has(wanted):
		if wanted != current_clip or not player.is_playing():
			var blend := 0.12 if current_clip != "" and current_clip not in ["stand_up", "sit_down"] and wanted not in ["stand_up", "sit_down"] else 0.0
			player.play(clips[wanted], blend)
			player.advance(0)
		if not waiting and not fixture.reduced_motion:
			player.advance(delta)
			if movement.busy():
				var animation := player.get_animation(clips[wanted])
				player.seek(fposmod(movement.elapsed, animation.length) if animation.loop_mode != Animation.LOOP_NONE else minf(movement.elapsed, animation.length), true)
		if fixture.reduced_motion:
			player.seek(0, true)
			player.pause()
	if skeleton != null:
		var root_index := skeleton.find_bone("Root")
		if root_index >= 0:
			var root_world := skeleton.global_transform * skeleton.get_bone_global_pose(root_index).origin
			actor_body.position = Vector3(root_world.x,origin.y+0.75,root_world.z)
	current_clip = wanted
