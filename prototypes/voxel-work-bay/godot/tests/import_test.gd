extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

const RESIDENTS := ["kai", "lyra", "onboarding-olivia", "super-chotu",
	"project-manager-pete", "research-ray", "writer-quill", "analyst-echo",
	"predictor-paul", "strategy-sam", "controller-casey", "optimizer-ollie",
	"threat-hunter-theo", "cleaner-cody"]
const CLIPS := ["idle", "walk", "seated_idle", "typing", "attend", "sit_down", "stand_up"]

func run_tests() -> void:
	var report := {}
	for asset_name in ["environment", "desk", "chair", "terminal"] + RESIDENTS:
		var packed := load("res://assets/" + asset_name + ".glb") as PackedScene
		if packed == null:
			fail(asset_name + " did not import")
			continue
		var instance := packed.instantiate() as Node3D
		root.add_child(instance)
		var meshes := instance.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() > 0, asset_name + " has visible imported meshes")
		report[asset_name] = {"meshes": meshes.size()}
		if asset_name in RESIDENTS:
			var players := instance.find_children("*", "AnimationPlayer", true, false)
			check(players.size() == 1, asset_name + " has one animation player")
			if not players.is_empty():
				var player := players[0] as AnimationPlayer
				var names: Array[String] = []
				for raw_name in player.get_animation_list():
					var short_name := str(raw_name).get_slice("/", str(raw_name).get_slice_count("/") - 1)
					short_name = short_name.get_slice("|", short_name.get_slice_count("|") - 1).to_lower()
					names.append(short_name)
					if CLIPS.has(short_name):
						var animation := player.get_animation(raw_name)
						check(animation.length > 0.0 and animation.get_track_count() > 0, asset_name + " " + short_name + " has animated tracks")
				for required in CLIPS:
					check(names.has(required), asset_name + " imported " + required)
				report[asset_name]["clips"] = names
		var skeletons := instance.find_children("*", "Skeleton3D", true, false)
		if asset_name in RESIDENTS:
			check(skeletons.size() == 1, asset_name + " has one skeleton")
			report[asset_name]["bones"] = (skeletons[0] as Skeleton3D).get_bone_count() if not skeletons.is_empty() else 0
			if not skeletons.is_empty():
				var bone_names: Array[String] = []
				for bone in range((skeletons[0] as Skeleton3D).get_bone_count()):
					bone_names.append((skeletons[0] as Skeleton3D).get_bone_name(bone))
				report[asset_name]["bone_names"] = bone_names
		instance.queue_free()
	print(JSON.stringify({"test": "import", "failures": failures, "assets": report}))
	quit(0 if failures == 0 else 1)

func check(condition: bool, description: String) -> void:
	if not condition:
		fail(description)

func fail(description: String) -> void:
	failures += 1
	push_error(description)
