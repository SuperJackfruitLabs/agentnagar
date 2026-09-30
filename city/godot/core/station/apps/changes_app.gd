## The Changes app: the station's changeset (the console's changes tab),
## read only. The branch, head and base, then each side's files, the
## uncommitted and the committed, with their insertions and deletions, and
## the chosen file's diff, its added and removed lines coloured from the
## style's palette. A long diff is placed a slice a frame (`place_text`).
class_name ChangesApp
extends StationApp

## Why the base is the base, as the changeset says.
const REASONS := {
	"explicit": "as chosen", "upstream": "its upstream", "default-branch": "the default branch", "head": "the head",
}
const SIDES := [["uncommitted", "Uncommitted"], ["committed", "Committed"]]
const NO_CHANGES := "No changes"
const SOME_FILES := "Only some files are listed."
const BINARY := "Binary file"
const TRUNCATED := "Truncated"
## The added and removed colours where a style names none: a green and a
## red, then darkened or lightened until they read on the style's panel.
const ADDED := "#2DA44E"
const REMOVED := "#CF222E"
## The contrast those colours reach against the panel, at least.
const LEGIBLE := 3.0
## The failure line's keys for the changeset and the diff.
const STATUS := "status"
const DIFF := "diff"

var summary: Label
var tree: Tree
## What the diff shows: the file, and a note when it was cut short or is
## not text.
var note: Label
var diff: TextEdit
## The last `ChangesetStatus`.
var status := {}

var _highlighter: DiffHighlighter
## The diff asked for last; an older answer is dropped.
var _diff_call := 0


func build() -> void:
	summary = Label.new()
	summary.name = "Summary"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(summary)
	var split := HSplitContainer.new()
	split.name = "Split"
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree = Tree.new()
	tree.name = "Files"
	tree.hide_root = true
	tree.custom_minimum_size = Vector2(320, 0)
	tree.focus_mode = Control.FOCUS_ALL
	tree.item_selected.connect(_on_item_selected)
	split.add_child(tree)
	var right := VBoxContainer.new()
	right.name = "Diff"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note = Label.new()
	note.name = "Note"
	note.clip_text = true
	right.add_child(note)
	diff = TextEdit.new()
	diff.name = "Text"
	diff.editable = false
	diff.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_highlighter = DiffHighlighter.new()
	diff.syntax_highlighter = _highlighter
	right.add_child(diff)
	split.add_child(right)
	add_child(split)
	load_status()


func restyle() -> void:
	super()
	if ui == null:
		return
	for l in [summary, note]:
		l.add_theme_font_override("font", ui.body_font)
		l.add_theme_font_size_override("font_size", ui.font_size(text_size()))
	summary.add_theme_color_override("font_color", ui.colour("ink"))
	note.add_theme_color_override("font_color", ui.colour("ink_muted"))
	var well := well_box()
	diff.add_theme_font_override("font", mono_font())
	diff.add_theme_font_size_override("font_size", ui.font_size(maxi(10, text_size() - 4)))
	diff.add_theme_color_override("font_readonly_color", ui.colour("ink"))
	diff.add_theme_stylebox_override("read_only", well)
	tree.add_theme_font_override("font", ui.body_font)
	tree.add_theme_font_size_override("font_size", ui.font_size(maxi(10, text_size() - 2)))
	tree.add_theme_color_override("font_color", ui.colour("ink"))
	tree.add_theme_stylebox_override("panel", well.duplicate())
	var colours := diff_colours(ui)
	_highlighter.added = colours["added"]
	_highlighter.removed = colours["removed"]
	# The accent is a button colour in some styles (dark on a dark panel),
	# so the hunk headers take it only as far as it reads.
	_highlighter.hunk = legible(ui.colour("accent"), well.bg_color, LEGIBLE)
	_highlighter.header = ui.colour("ink_muted")
	_highlighter.ink = ui.colour("ink")
	_highlighter.clear_highlighting_cache()
	diff.queue_redraw()


## The diff's added and removed colours: the style's own `added` and
## `removed` where its palette names them, else a green and a red made to
## read on its panel.
static func diff_colours(skin: UiTheme) -> Dictionary:
	var named: Dictionary = skin.spec.get("colours", {})
	var panel := Color(skin.colour("panel"), 1.0)
	var out := {}
	for pair in [["added", ADDED], ["removed", REMOVED]]:
		if named.has(pair[0]):
			out[pair[0]] = skin.colour(pair[0])
			continue
		out[pair[0]] = legible(Color(pair[1]), panel, LEGIBLE)
	return out


## The colour diff line `index` is drawn in.
func line_colour(index: int) -> Color:
	return _highlighter.colour_for(diff.get_line(index))


# ---- The changeset ----

## Asks for the changeset against the station's default base.
func load_status() -> void:
	request(source.changeset_status(station_id(), ""), _on_status)


func _on_status(ok: bool, body: Variant, _status: int) -> void:
	if not ok:
		show_error(body if body is Dictionary else {}, load_status, STATUS)
		return
	clear_error(STATUS)
	status = body if body is Dictionary else {}
	summary.text = describe(status)
	_fill_tree()
	# The first changed file's diff, so the app opens onto something.
	for pair in SIDES:
		var files: Array = status.get(pair[0], {}).get("files", [])
		if not files.is_empty():
			select_file(pair[0], str(files[0]["path"]))
			return
	note.text = NO_CHANGES
	place_text(diff, "")


## The branch, head and base in one line: "Branch count-tabs · head
## 48b0821 · base origin/main at c305097, its upstream".
static func describe(changeset: Dictionary) -> String:
	var repo: Dictionary = changeset.get("repo", {})
	var base: Dictionary = changeset.get("base", {})
	var head := str(repo.get("head", "")).left(7)
	var parts := []
	if repo.get("detached", false):
		parts.append("Detached at %s" % head)
	else:
		parts.append("Branch %s" % str(repo.get("branch", "")))
		parts.append("head %s" % head)
	var reason := str(REASONS.get(str(base.get("reason", "")), base.get("reason", "")))
	parts.append("base %s at %s, %s" % [str(base.get("ref", "")), str(base.get("sha", "")).left(7), reason])
	var line := " · ".join(parts)
	if changeset.get("truncatedFiles", false):
		line += ". " + SOME_FILES
	return line


## Two sections, the uncommitted and the committed, each file under its
## side with its insertions and deletions.
func _fill_tree() -> void:
	tree.clear()
	var root := tree.create_item()
	for pair in SIDES:
		var side: Dictionary = status.get(pair[0], {})
		var files: Array = side.get("files", [])
		var heading := "%s · %d %s · +%d −%d" % [pair[1], files.size(), "file" if files.size() == 1 else "files",
			int(side.get("insertions", 0)), int(side.get("deletions", 0))]
		var commits: Array = side.get("commits", [])
		if not commits.is_empty():
			heading += " · %d %s" % [commits.size(), "commit" if commits.size() == 1 else "commits"]
		var section := tree.create_item(root)
		section.set_text(0, heading)
		section.set_selectable(0, false)
		section.set_meta("side", pair[0])
		for changed in files:
			var item := tree.create_item(section)
			item.set_text(0, file_line(changed))
			item.set_meta("side", pair[0])
			item.set_meta("path", str(changed["path"]))


## One file as listed: its path (from its old one, when renamed), and its
## insertions and deletions, or that it is binary.
static func file_line(changed: Dictionary) -> String:
	var path := str(changed["path"])
	if changed.get("oldPath") != null and str(changed["oldPath"]) != path:
		path = "%s → %s" % [changed["oldPath"], path]
	if changed.get("binary", false):
		return "%s  binary" % path
	return "%s  +%d −%d" % [path, int(changed.get("insertions", 0)), int(changed.get("deletions", 0))]


## The files listed on `side` ("uncommitted" or "committed"), as shown.
func listed(side: String) -> Array:
	var root := tree.get_root()
	if root == null:
		return []
	for section in root.get_children():
		if section.get_meta("side", "") == side:
			return section.get_children().map(func(item: TreeItem) -> String: return item.get_text(0))
	return []


func _on_item_selected() -> void:
	var item := tree.get_selected()
	if item != null and item.has_meta("path"):
		select_file(str(item.get_meta("side")), str(item.get_meta("path")))


# ---- The diff ----

## Shows the diff of `path` on `side`.
func select_file(side: String, path: String) -> void:
	note.text = path
	_diff_call = source.changeset_diff(station_id(), side, path)
	request(_diff_call, _on_diff.bind(side, path, _diff_call))


func _on_diff(ok: bool, body: Variant, _status: int, side: String, path: String, call_id: int) -> void:
	if call_id != _diff_call:
		return
	if not ok:
		show_error(body if body is Dictionary else {}, select_file.bind(side, path), DIFF)
		return
	clear_error(DIFF)
	var answer: Dictionary = body if body is Dictionary else {}
	if answer.get("binary", false):
		diff.visible = false
		place_text(diff, "")
		note.text = "%s · %s" % [path, BINARY]
		return
	diff.visible = true
	place_text(diff, str(answer.get("content", "")))
	note.text = path + (" · " + TRUNCATED if answer.get("truncated", false) else "")



## Colours a unified diff a line at a time: added and removed lines, hunk
## headers, and the file headers muted.
class DiffHighlighter extends SyntaxHighlighter:
	var added := Color.GREEN
	var removed := Color.RED
	var hunk := Color.BLUE
	var header := Color.GRAY
	var ink := Color.BLACK

	func colour_for(line: String) -> Color:
		if line.begins_with("+++") or line.begins_with("---") or line.begins_with("diff ") or line.begins_with("index "):
			return header
		if line.begins_with("@@"):
			return hunk
		if line.begins_with("+"):
			return added
		if line.begins_with("-"):
			return removed
		return ink

	func _get_line_syntax_highlighting(line: int) -> Dictionary:
		return {0: {"color": colour_for(get_text_edit().get_line(line))}}
