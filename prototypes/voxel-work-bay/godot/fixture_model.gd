extends RefCounted

const STATES: Array[String] = ["working", "idle", "stale", "unavailable", "unknown"]
const CLIPS: Array[String] = ["idle", "walk", "seated_idle", "typing", "attend", "sit_down", "stand_up"]

var state := "working"
var reduced_motion := false
var inspection := ""

func set_state(next_state: String) -> bool:
	if not STATES.has(next_state):
		return false
	state = next_state
	return true

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled

func set_inspection(clip: String) -> bool:
	if clip != "" and not CLIPS.has(clip):
		return false
	inspection = clip
	return true

func is_inspecting() -> bool:
	return inspection != ""

func clip_for(available: Array[String]) -> String:
	if reduced_motion:
		return ""
	var wanted := inspection if is_inspecting() else ("typing" if state == "working" else "seated_idle")
	return wanted if available.has(wanted) else ""
