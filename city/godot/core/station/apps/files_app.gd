## The Files app: the station's workspace (the console's files tab), read
## only. A tree of the workspace, each folder listed only when it is first
## opened, and a preview of the chosen file: up to 1 MiB of text, noting
## when it was cut short, or, for a file that is not text, its size. A long
## text is placed a slice a frame (`place_text`), so a 1 MiB file never
## holds up a frame.
class_name FilesApp
extends StationApp

## How much of a file the preview reads: the node's own limit.
const PREVIEW_BYTES := 1 << 20
const TRUNCATED := "Truncated: the first 1 MiB"
const BINARY := "Binary file"
const LOADING := "Loading…"
const CHOOSE := "Choose a file to preview it."
## The failure line's key for the preview; a listing's is "listing <path>".
const PREVIEW := "preview"

var tree: Tree
## What the preview shows: the file's path, and a note when it was cut
## short or is not text.
var note: Label
var preview: TextEdit

## Each listed entry's item, by path; "." is the workspace itself.
var _items := {}
## The preview's read, the latest asked for; an older answer is dropped.
var _preview_call := 0


func build() -> void:
	var split := HSplitContainer.new()
	split.name = "Split"
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree = Tree.new()
	tree.name = "Tree"
	tree.hide_root = true
	tree.custom_minimum_size = Vector2(280, 0)
	tree.focus_mode = Control.FOCUS_ALL
	tree.item_collapsed.connect(_on_item_collapsed)
	tree.item_selected.connect(_on_item_selected)
	tree.item_activated.connect(_on_item_activated)
	split.add_child(tree)
	var right := VBoxContainer.new()
	right.name = "Preview"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note = Label.new()
	note.name = "Note"
	note.text = CHOOSE
	note.clip_text = true
	right.add_child(note)
	preview = TextEdit.new()
	preview.name = "Text"
	preview.editable = false
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(preview)
	split.add_child(right)
	add_child(split)
	var root := tree.create_item()
	root.set_meta("path", ".")
	root.set_meta("type", "dir")
	_items["."] = root
	_list(".")


func restyle() -> void:
	super()
	if ui == null:
		return
	note.add_theme_font_override("font", ui.body_font)
	note.add_theme_font_size_override("font_size", ui.font_size(text_size()))
	note.add_theme_color_override("font_color", ui.colour("ink_muted"))
	preview.add_theme_font_override("font", mono_font())
	preview.add_theme_font_size_override("font_size", ui.font_size(maxi(10, text_size() - 4)))
	preview.add_theme_color_override("font_readonly_color", ui.colour("ink"))
	preview.add_theme_stylebox_override("read_only", well_box())
	tree.add_theme_font_override("font", ui.body_font)
	tree.add_theme_font_size_override("font_size", ui.font_size(maxi(10, text_size() - 2)))
	tree.add_theme_color_override("font_color", ui.colour("ink"))
	tree.add_theme_stylebox_override("panel", well_box())


# ---- The tree ----

## The item listing `path`, or null.
func item_for(path: String) -> TreeItem:
	return _items.get(path)


## The names listed under `path`, as shown; empty until it is listed.
func listed(path: String) -> Array:
	var item := item_for(path)
	if item == null or not item.get_meta("loaded", false):
		return []
	return item.get_children().map(func(child: TreeItem) -> String: return child.get_text(0))


## Opens the folder at `path`, which lists it the first time.
func expand(path: String) -> void:
	var item := item_for(path)
	if item != null:
		item.collapsed = false


func _list(path: String) -> void:
	var item := item_for(path)
	item.set_meta("loading", true)
	request(source.files(station_id(), path), _on_listing.bind(path))


func _on_listing(ok: bool, body: Variant, _status: int, path: String) -> void:
	var item := item_for(path)
	if item == null:
		return
	item.set_meta("loading", false)
	if not ok:
		show_error(body if body is Dictionary else {}, _list.bind(path), "listing " + path)
		return
	clear_error("listing " + path)
	for child in item.get_children():
		item.remove_child(child)
		child.free()
	var entries: Array = body if body is Array else []
	# Folders first, then files, each by name, as the console lists them.
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_dir: bool = a["type"] == "dir"
		var b_dir: bool = b["type"] == "dir"
		if a_dir != b_dir:
			return a_dir
		return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0)
	for entry in entries:
		var child := tree.create_item(item)
		child.set_text(0, str(entry["name"]))
		child.set_meta("path", str(entry["path"]))
		child.set_meta("type", str(entry["type"]))
		child.set_meta("size", entry.get("size"))
		_items[str(entry["path"])] = child
		if entry["type"] == "dir":
			# A stand-in child, so the folder can be opened before it is listed.
			tree.create_item(child).set_text(0, LOADING)
			child.collapsed = true
	item.set_meta("loaded", true)


func _on_item_collapsed(item: TreeItem) -> void:
	if item.collapsed or item.get_meta("type", "") != "dir":
		return
	if not item.get_meta("loaded", false) and not item.get_meta("loading", false):
		_list(str(item.get_meta("path")))


func _on_item_selected() -> void:
	var item := tree.get_selected()
	if item != null and item.has_meta("path") and item.get_meta("type") != "dir":
		open_file(str(item.get_meta("path")))


## Enter or A on a folder opens or closes it.
func _on_item_activated() -> void:
	var item := tree.get_selected()
	if item != null and item.get_meta("type", "") == "dir":
		item.collapsed = not item.collapsed


# ---- The preview ----

## Reads the file at `path` into the preview, up to PREVIEW_BYTES.
func open_file(path: String) -> void:
	note.text = "%s · %s" % [path, LOADING]
	_preview_call = source.file(station_id(), path, PREVIEW_BYTES)
	request(_preview_call, _on_file.bind(path, _preview_call))


func _on_file(ok: bool, body: Variant, _status: int, path: String, call_id: int) -> void:
	if call_id != _preview_call:
		return
	if not ok:
		note.text = path
		show_error(body if body is Dictionary else {}, open_file.bind(path), PREVIEW)
		return
	clear_error(PREVIEW)
	var answer: Dictionary = body if body is Dictionary else {}
	if answer.has("text"):
		preview.visible = true
		place_text(preview, str(answer["text"]))
		note.text = path + (" · " + TRUNCATED if answer.get("truncated", false) else "")
		return
	# Not text: its size, as listed, since a read may have been cut short.
	preview.visible = false
	place_text(preview, "")
	var listed_size = item_for(path).get_meta("size") if item_for(path) != null else null
	var size_bytes: int = int(listed_size) if listed_size != null else (answer.get("bytes", PackedByteArray()) as PackedByteArray).size()
	note.text = "%s · %s · %s" % [path, BINARY, format_bytes(size_bytes)]

