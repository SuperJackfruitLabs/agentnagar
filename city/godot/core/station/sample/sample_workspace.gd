## Sample station's workspace: the recorded listings, files, changeset and
## diff, answered as AgentPod's file and changeset routes answer. Each
## method returns [ok, body, status]; `SampleSource` checks the station
## first. It is read-only, as the routes the apps use are.
class_name SampleWorkspace
extends RefCounted

## The node's own file-read limit, used when a read asks for none, and the
## hub's cap on any read.
const NODE_READ_LIMIT := 1 << 20
const HUB_READ_LIMIT := 8 << 20

var _listings: Dictionary
var _changeset: Dictionary
## Each file's section of the patch, by path.
var _diff_sections := {}
## Where the recorded files are, ending in "/".
var _files_root: String


func _init(listings: Dictionary, changeset: Dictionary, patch: String, files_root: String) -> void:
	_listings = listings
	_changeset = changeset
	_diff_sections = _split_diff(patch)
	_files_root = files_root


func files(path: String) -> Array:
	var listing = _listings.get(_clean_path(path))
	if listing == null:
		return _node_failed("no such directory")
	return SampleSource.success(listing.duplicate(true))


func file(path: String, max_bytes: int) -> Array:
	var clean := _clean_path(path)
	# Only a file the recording lists is read, so no path can reach outside
	# the recorded workspace.
	if not _is_listed_file(clean):
		return _node_failed("no such file")
	var content := FileAccess.get_file_as_bytes(_files_root + clean)
	var limit := NODE_READ_LIMIT if max_bytes <= 0 else mini(max_bytes, HUB_READ_LIMIT)
	var truncated := content.size() > limit
	if not StationSource.is_utf8(content):
		return SampleSource.success({"bytes": content.slice(0, limit), "truncated": truncated})
	# Cut at a character's start, so a truncated text is still text.
	var end := mini(limit, content.size())
	while truncated and end > 0 and content[end] & 0xC0 == 0x80:
		end -= 1
	return SampleSource.success({"text": content.slice(0, end).get_string_from_utf8(), "truncated": truncated})


func changeset_status(base: String) -> Array:
	var body := _changeset.duplicate(true)
	if base == "":
		return SampleSource.success(body)
	if base != body["base"]["ref"]:
		return _node_failed("unknown base ref")
	body["base"]["reason"] = "explicit"
	return SampleSource.success(body)


func changeset_diff(side: String, path: String) -> Array:
	if not side in ["uncommitted", "committed"]:
		return SampleSource.failure("failed", "Invalid side.", 400)
	var content := ""
	for changed in _changeset[side]["files"]:
		if path == "" or changed["path"] == path:
			content += _diff_sections.get(changed["path"], "")
	return SampleSource.success({"content": content, "truncated": false, "binary": false})


## A failure the node reports: the hub answers any of them with 502.
func _node_failed(message: String) -> Array:
	return SampleSource.failure("failed", message, 502)


## `path` as the recording's listings name it: no leading "./", no
## trailing "/", and "." for the workspace itself.
func _clean_path(path: String) -> String:
	var clean := path.strip_edges()
	while clean.begins_with("./"):
		clean = clean.substr(2)
	while clean.ends_with("/"):
		clean = clean.left(-1)
	return "." if clean == "" else clean


func _is_listed_file(path: String) -> bool:
	var parent := path.get_base_dir()
	for entry in _listings.get("." if parent == "" else parent, []):
		if entry["path"] == path and entry["type"] == "file":
			return true
	return false


## Splits a patch into each file's section, keyed by its new path.
func _split_diff(patch: String) -> Dictionary:
	var sections := {}
	var path := ""
	for line in patch.split("\n"):
		if line.begins_with("diff --git "):
			path = line.get_slice(" b/", 1)
			sections[path] = ""
		if path != "":
			sections[path] += line + "\n"
	# The split added a newline after the patch's own last one.
	if path != "":
		sections[path] = sections[path].trim_suffix("\n")
	return sections
