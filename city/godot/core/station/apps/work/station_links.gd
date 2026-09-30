## Which Superpipeline agent works at each station, as the player said, kept
## on this device. No route links an AgentPod station to its Superpipeline
## agent (spec section 10, "found while planning Part B"), so the Work app
## asks once per station and keeps the answer here: station ID to agent ID,
## "" for None. IDs only, nothing else.
class_name StationLinks
extends RefCounted

## Where the links are kept; tests give their own path.
const PATH := "user://station_links.cfg"
const SECTION := "links"


## The agent kept for `station_id` in `path`: its ID, "" for None, or null
## when none was chosen.
static func read_link(path: String, station_id: String) -> Variant:
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section_key(SECTION, station_id):
		return null
	return str(file.get_value(SECTION, station_id))


## Keeps `agent_id` ("" for None) for `station_id` in `path`, beside the
## other stations' links.
static func store_link(path: String, station_id: String, agent_id: String) -> void:
	var file := ConfigFile.new()
	file.load(path)
	file.set_value(SECTION, station_id, agent_id)
	file.save(path)
