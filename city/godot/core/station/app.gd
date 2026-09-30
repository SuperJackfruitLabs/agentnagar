## One app on the station computer's dock: the city-styled counterpart of
## one of the AgentPod console's tabs (spec section 5.2). The computer makes
## an app when the player opens it from the dock, sets it up with the open
## station and its source, and frees it when the player goes back to the
## desktop or leaves, calling `closing` first so the app can close its
## streams.
##
## This base draws a placeholder that names the app, for the apps not yet
## built. It also holds what every app shares: answering calls through
## `request`, one line for a failure (`show_error`), a question before a
## real operation (`ask_first`), long text placed a slice a frame
## (`place_text`), and the style's monospace face. The Terminal, Logs and
## the other apps subclass it and draw their own bodies.
class_name StationApp
extends VBoxContainer

## "Sign in again" was pressed; the computer passes it on as its own
## `sign_in_requested`.
signal sign_in_requested

const OFFLINE := "Station offline"
const NO_ACCESS := "You don't have access to this station"
const SIGNED_OUT := "Your AgentPod sign-in has ended"
const SIGN_IN_AGAIN := "Sign in again"
const RETRY := "Retry"
## What a failure says when its message is empty.
const SOMETHING_WENT_WRONG := "Something went wrong"

## The app's name, on the dock and over its window.
var app_name := ""
## Whether the app takes typing (the terminal and the chat). On a desktop
## with only a controller, the computer says typing needs a keyboard, and
## on a touch screen it brings up the system keyboard for `typing_target`.
var takes_typing := false
## Where the app's station and its work come from.
var source: StationSource
## The open station, a `FleetAgent`.
var station := {}
## Watch mode: the app shows the station but sends it nothing, and takes
## no typing.
var read_only := false
## The skin, from the computer's `apply_theme`.
var ui: UiTheme
## The player's settings, for an app with something to keep on the
## device. Null in a test that gives none.
var settings: Settings
## Set by `closing`: the app answers nothing and asks nothing after it.
var closed := false

## The control that takes the player's keys, or null for an app without
## typing. The computer asks `StationApp.is_typing_target` of whatever has
## the focus, so Esc goes to this control instead of leaving.
var typing_target: Control
## The placeholder's text.
var placeholder: Label

## The failure line: what went wrong, and the one thing to do about it.
var error_bar: HBoxContainer
var error_label: Label
var error_button: Button

## The question before a real operation (`ask_first`): what it asks, the
## button that does it, and Cancel.
var confirm_box: VBoxContainer
var confirm_label: Label
var confirm_button: Button
var cancel_button: Button

## The calls asked for and not yet answered: call ID to the Callable that
## takes (ok, body, status).
var _pending := {}
## Each request's failure, by the key its app gives it, oldest first: [line,
## button text, action]. The line shows the newest, so one request's
## success clears only its own failure and never hides another's.
var _failures := {}
## What the failure line's button does.
var _error_action := Callable()
## What the question's button does, and what Cancel does besides hiding it.
var _confirm_action := Callable()
var _cancel_action := Callable()
## Long texts still being placed a slice a frame: the TextEdit, then [the
## whole text, how much is placed].
var _placing := {}


## Sets the app up for `station_` from `source_`, read-only in watch mode,
## and builds it.
func setup(source_: StationSource, station_: Dictionary, read_only_: bool) -> void:
	source = source_
	station = station_
	read_only = read_only_
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not source.result.is_connected(_on_result):
		source.result.connect(_on_result)
	build()


## Builds the app's body. This base shows its name, and for an app that
## takes typing a stand-in field that keeps every key it is given; the
## apps replace both.
func build() -> void:
	placeholder = Label.new()
	placeholder.name = "Placeholder"
	placeholder.text = app_name
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(placeholder)
	if takes_typing:
		var field := PanelContainer.new()
		field.name = "Typing"
		field.custom_minimum_size = Vector2(0, 48)
		field.set_meta("takes_typing", true)
		field.focus_mode = Control.FOCUS_NONE if read_only else Control.FOCUS_ALL
		field.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventKey:
				field.accept_event())
		add_child(field)
		typing_target = field


## Re-applies `ui`. Virtual: the base sizes its placeholder's text and the
## failure line; an app that overrides it calls it too.
func restyle() -> void:
	if ui == null:
		return
	if placeholder != null:
		placeholder.add_theme_font_override("font", ui.body_font)
		placeholder.add_theme_font_size_override("font_size", ui.font_size(text_size()))
		placeholder.add_theme_color_override("font_color", ui.colour("ink_muted"))
	for l in [error_label, confirm_label]:
		if l != null:
			l.add_theme_font_override("font", ui.body_font)
			l.add_theme_font_size_override("font_size", ui.font_size(text_size()))
			l.add_theme_color_override("font_color", ui.colour("ink"))
	for b in find_children("*", "Button", true, false):
		b.custom_minimum_size.y = float(ui.spec.get("button", {}).get("height", 48))
		if b.flat:
			ink_button(b)


## Gives a flat button (a row's title, a menu) the panel's ink: the skin's
## button words are for its filled buttons, and would not read on the
## panel. The focused or hovered one takes the accent.
func ink_button(b: Button) -> void:
	if ui == null:
		return
	var ink := ui.colour("ink")
	var accent := legible(ui.colour("accent"), Color(ui.colour("panel"), 1.0))
	for state in ["font_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(state, ink)
	for state in ["font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, accent)


## Called just before the computer frees the app. Virtual: an app closes
## the streams it opened here, and calls this too, so no answer arrives
## after it has gone.
func closing() -> void:
	closed = true
	_pending.clear()
	_placing.clear()
	if source != null and source.result.is_connected(_on_result):
		source.result.disconnect(_on_result)


## Everything the app says, for tests: the text of every label and button
## showing, top to bottom.
func text() -> String:
	var parts := []
	for node in find_children("*", "", true, false):
		if (node is Label or node is Button) and node.is_visible_in_tree() and node.text != "":
			parts.append(node.text)
	if parts.is_empty() and placeholder != null:
		return placeholder.text
	return "\n".join(parts)


## Whether `control` takes typing: a text field the player can type into,
## or an app's own typing control (its `takes_typing` meta), such as the
## terminal's grid. A read-only text box, such as a file's preview, takes
## no typing, so Esc still leaves from it.
static func is_typing_target(control: Control) -> bool:
	if control == null:
		return false
	if control is LineEdit or control is TextEdit:
		return bool(control.get("editable"))
	return bool(control.get_meta("takes_typing", false))


# ---- What every app shares ----

## Places what is still waiting, a slice a frame. An app that has its own
## `_process` calls this too.
func _process(_delta: float) -> void:
	if not _placing.is_empty():
		fill_step()


## The skin's body text size.
func text_size() -> int:
	return int(ui.spec.get("text_size", 20)) if ui != null else 20


## The open station's ID, as the routes take it.
func station_id() -> String:
	return str(station.get("stationId", ""))


## A button every device can reach: the d-pad and Tab as well as the
## pointer.
func make_button(node_name: String, label: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = label
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(action)
	return b


## A sunken panel for a tree, a preview or a diff: the skin's panel, a
## shade off it, edged in its edge colour.
func well_box() -> StyleBoxFlat:
	var panel := Color(ui.colour("panel"), 1.0)
	var box := StyleBoxFlat.new()
	box.bg_color = panel.darkened(0.04) if panel.get_luminance() > 0.5 else panel.lightened(0.06)
	box.border_color = ui.colour("panel_edge")
	box.set_border_width_all(1)
	box.set_content_margin_all(6)
	return box


## The station's name as the computer shows it.
func station_name() -> String:
	return ComputerScreen.station_title(station, source != null and source.LIVE)


## The style's monospace face: its `ui` block's `font_mono`, or the
## engine's own monospace where the style names none (or names one that
## does not load).
func mono_font() -> Font:
	var path = ui.spec.get("font_mono") if ui != null else null
	if path is String and not path.is_empty() and ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Font:
			return loaded
	return engine_mono_font()


static var _engine_mono: Font


## The engine's monospace: the system's, by the usual names, which the
## engine falls back from to its own face where there is none.
static func engine_mono_font() -> Font:
	if _engine_mono == null:
		var system := SystemFont.new()
		system.font_names = PackedStringArray(["monospace", "DejaVu Sans Mono", "Menlo", "Consolas", "Courier New"])
		_engine_mono = system
	return _engine_mono


## A size in bytes as people read it: bytes, then KiB, MiB and GiB to one
## decimal place.
static func format_bytes(size_bytes: int) -> String:
	if size_bytes < 1024:
		return "%d B" % size_bytes
	var units := ["KiB", "MiB", "GiB", "TiB"]
	var value := size_bytes / 1024.0
	var unit := 0
	while value >= 1024.0 and unit < units.size() - 1:
		value /= 1024.0
		unit += 1
	return "%.1f %s" % [value, units[unit]]


## `colour`, darkened on a light `background` or lightened on a dark one
## until the two reach `least` contrast, so a colour the station or the
## palette gives still reads.
static func legible(colour: Color, background: Color, least := 3.0) -> Color:
	var steps := 0
	var darken := background.get_luminance() > 0.5
	while UiTheme.contrast(colour, background) < least and steps < 12:
		colour = colour.darkened(0.2) if darken else colour.lightened(0.2)
		steps += 1
	return colour


## How much of a long text is placed in one frame, in characters: a
## TextEdit shapes every line it is given, about 6 ms for 16 KiB of source
## on the bench machine, so a 1 MiB file placed at once held one frame for a
## third of a second.
const TEXT_SLICE := 16 * 1024
## The longest line shown whole, in characters. A TextEdit shapes a line as
## one piece, so a minified file's single 1 MiB line would hold a frame
## however it was sliced; the shown text is read-only, so a longer line is
## cut, and says so.
const LONGEST_LINE := 4000
const LINE_CUT := "… (line cut)"


## Shows `text` in `edit`: the first slice now, and the rest a slice a
## frame, each ending at a line's end, with any line longer than
## LONGEST_LINE cut. Replaces whatever `edit` was still being given.
func place_text(edit: TextEdit, text: String) -> void:
	var first := _next_slice(text, 0)
	edit.text = first[0]
	edit.clear_undo_history()
	if first[1] < text.length():
		_placing[edit] = [text, first[1]]
	else:
		_placing.erase(edit)


## Whether any text is still being placed.
func filling() -> bool:
	return not _placing.is_empty()


## Places the next slice of each text still waiting.
func fill_step() -> void:
	for edit: TextEdit in _placing.keys():
		var entry: Array = _placing[edit]
		var text: String = entry[0]
		var next := _next_slice(text, entry[1])
		var last := edit.get_line_count() - 1
		edit.insert_text(next[0], last, edit.get_line(last).length())
		if next[1] >= text.length():
			_placing.erase(edit)
			edit.clear_undo_history()
		else:
			entry[1] = next[1]


## The slice of `text` from `at` as shown, and where the next begins:
## whole lines, about TEXT_SLICE characters of them (at least one line),
## with a line longer than LONGEST_LINE cut to it and LINE_CUT.
static func _next_slice(text: String, at: int) -> Array:
	var length := text.length()
	var pieces := PackedStringArray()
	# Lines of fitting length are taken as one run, cut from `text` once.
	var run_start := at
	var cursor := at
	var placed := 0
	while cursor < length and placed < TEXT_SLICE:
		var newline := text.find("\n", cursor)
		var line_end := length if newline == -1 else newline
		var next := length if newline == -1 else newline + 1
		if line_end - cursor > LONGEST_LINE:
			if cursor > run_start:
				pieces.append(text.substr(run_start, cursor - run_start))
			pieces.append(text.substr(cursor, LONGEST_LINE) + LINE_CUT + text.substr(line_end, next - line_end))
			placed += LONGEST_LINE
			run_start = next
		elif placed > 0 and placed + next - cursor > TEXT_SLICE:
			break
		else:
			placed += next - cursor
		cursor = next
	if cursor > run_start:
		pieces.append(text.substr(run_start, cursor - run_start))
	return ["".join(pieces), cursor]


## Asks `question` before a real operation, with a button saying `verb`
## that does `action`, and Cancel, which does `on_cancel` too. The focus
## goes to Cancel, so a stray press does nothing. Asking again replaces the
## question.
func ask_first(question: String, verb: String, action: Callable, on_cancel := Callable()) -> void:
	_ensure_confirm_box()
	if _cancel_action.is_valid():
		_cancel_action.call()
	_confirm_action = action
	_cancel_action = on_cancel
	confirm_label.text = question
	confirm_button.text = verb
	confirm_box.visible = true
	if cancel_button.is_inside_tree():
		cancel_button.grab_focus()


## Whether a question is showing.
func asking() -> bool:
	return confirm_box != null and confirm_box.visible


## Does what the question asked about.
func confirm() -> void:
	if not asking():
		return
	var action := _confirm_action
	_confirm_action = Callable()
	_cancel_action = Callable()
	confirm_box.visible = false
	if action.is_valid():
		action.call()


## Puts the question away without doing it.
func cancel_confirm() -> void:
	if not asking():
		return
	var on_cancel := _cancel_action
	_confirm_action = Callable()
	_cancel_action = Callable()
	confirm_box.visible = false
	if on_cancel.is_valid():
		on_cancel.call()


## The question, built the first time an app asks one: at the top of the
## app, under the failure line, where it shows whatever the app scrolled
## to.
func _ensure_confirm_box() -> void:
	if confirm_box != null:
		return
	confirm_box = VBoxContainer.new()
	confirm_box.name = "Confirm"
	confirm_box.visible = false
	confirm_label = Label.new()
	confirm_label.name = "Question"
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_box.add_child(confirm_label)
	var answers := HBoxContainer.new()
	answers.add_theme_constant_override("separation", 12)
	confirm_button = make_button("Yes", "", confirm)
	cancel_button = make_button("Cancel", "Cancel", cancel_confirm)
	answers.add_child(confirm_button)
	answers.add_child(cancel_button)
	confirm_box.add_child(answers)
	add_child(confirm_box)
	move_child(confirm_box, 1 if error_bar != null else 0)
	restyle()


## Waits for call `call_id`'s answer, which `on_answer` takes as (ok, body,
## status). An answer after `closing` goes nowhere.
func request(call_id: int, on_answer: Callable) -> void:
	_pending[call_id] = on_answer


func _on_result(call_id: int, ok: bool, body: Variant, status: int) -> void:
	if closed or not _pending.has(call_id):
		return
	var on_answer: Callable = _pending[call_id]
	_pending.erase(call_id)
	on_answer.call(ok, body, status)


## The failure line, built the first time an app needs it: at the top of
## the app, above its body.
func _ensure_error_bar() -> void:
	if error_bar != null:
		return
	error_bar = HBoxContainer.new()
	error_bar.name = "ErrorBar"
	error_bar.add_theme_constant_override("separation", 12)
	error_label = Label.new()
	error_label.name = "Error"
	error_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	error_label.clip_text = true
	error_bar.add_child(error_label)
	error_button = Button.new()
	error_button.name = "ErrorAction"
	error_button.focus_mode = Control.FOCUS_ALL
	error_button.pressed.connect(func() -> void:
		if _error_action.is_valid():
			_error_action.call())
	error_bar.add_child(error_button)
	error_bar.visible = false
	add_child(error_bar)
	move_child(error_bar, 0)
	restyle()


## Shows a failure as the player reads it, whatever the app: offline with
## Retry, no access, signed out with "Sign in again", or the error's own
## one line (never a response body) with Retry. `retry` is what Retry does;
## `key` names the request that failed, whose success clears it.
func show_error(error: Dictionary, retry: Callable, key := "") -> void:
	match str(error.get("kind", "failed")):
		"offline":
			show_line(OFFLINE, RETRY, retry, key)
		"no_access":
			show_line(NO_ACCESS, "", Callable(), key)
		"signed_out":
			show_line(SIGNED_OUT, SIGN_IN_AGAIN, sign_in_requested.emit, key)
		_:
			var message := str(error.get("message", "")).strip_edges().get_slice("\n", 0)
			show_line(message if message != "" else SOMETHING_WENT_WRONG, RETRY, retry, key)


## Shows `line` on the failure line for request `key`, with a button saying
## `button_text` that does `action`, or no button when `button_text` is
## empty.
func show_line(line: String, button_text: String, action: Callable, key := "") -> void:
	_failures.erase(key)
	_failures[key] = [line, button_text, action]
	_show_failure()


## Clears request `key`'s failure; the line then shows the newest failure
## still standing, or goes.
func clear_error(key := "") -> void:
	_failures.erase(key)
	_show_failure()


func _show_failure() -> void:
	if _failures.is_empty():
		if error_bar != null:
			error_bar.visible = false
		_error_action = Callable()
		return
	_ensure_error_bar()
	var failure: Array = _failures[_failures.keys().back()]
	error_label.text = failure[0]
	error_button.text = failure[1]
	error_button.visible = failure[1] != ""
	_error_action = failure[2]
	error_bar.visible = true


## What the failure line says, or "" when none shows.
func error_text() -> String:
	return error_label.text if error_bar != null and error_bar.visible else ""


## Presses the failure line's button, as the player would.
func press_error_button() -> void:
	if error_bar != null and error_bar.visible and error_button.visible:
		error_button.pressed.emit()
