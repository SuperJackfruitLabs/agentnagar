## The Terminal app: a real shell on the station (the console's terminal
## tab), drawn from `TermGrid` in the style's monospace face.
##
## - Size: at least 80×24, filling the app area; where 80×24 does not fit,
##   the face shrinks until it does. The hub opens every shell at 80×24, so
##   the size is sent as soon as the stream opens, and again on every
##   change.
## - Drawing: one canvas item a row, each redrawn only when `TermGrid` says
##   its row changed, so an unchanged row costs nothing a frame. Output is
##   gathered as it arrives and fed to the grid once a frame, so a burst of
##   small writes is parsed in one pass.
## - Keys: encoded as xterm does (`encode_key`), in the grid's cursor mode.
##   Ctrl-Shift-V and the middle button paste, bracketed when the shell
##   asks. The wheel scrolls back.
## - Watching, it shows the shell and sends it nothing, not even a resize.
class_name TerminalApp
extends StationApp

## The smallest terminal, in cells: the hub's own size, and spec §5's floor.
const MIN_COLUMNS := 80
const MIN_ROWS := 24
## Lines a wheel notch scrolls.
const WHEEL_LINES := 3
## The smallest face the terminal shrinks to, to fit 80×24.
const SMALLEST_FONT_SIZE := 6
const SESSION_ENDED := "Session ended"
## Typing that could not reach the shell: never kept for later, since a
## keystroke replayed minutes on into a shell could do harm.
const NOT_SENT := "Not sent: the station is not connected"
## The failure line's key for typing not sent.
const UNSENT := "unsent"
const RECONNECT := "Reconnect"
const REAL_SHELL := "This is a real shell on %s: what you type runs there."
const NO_EXTENSION := "The terminal needs the city's extension, which did not load."
const PASTE_START := "\u001b[200~"
const PASTE_END := "\u001b[201~"
## The failure line's key for the shell's stream.
const STREAM := "stream"
## How many glyphs a cell's width is measured over.
const CELL_SAMPLE := 64
## The least contrast a run's text keeps against its background; a colour
## the shell asks for that would read worse on the skin's paper (ANSI blue
## on a dark panel, yellow on a light one) is lightened or darkened to it.
const LEGIBLE := 3.0

## The grid: a `TermGrid`, made through ClassDB so this script still loads
## where the extension does not.
var grid
var stream: StationStream.Terminal
## How many times the app has said typing was not sent.
var not_sent_shown := 0
## The drawing area: its background, the rows and the cursor.
var view: Control
## The rows' drawings, top to bottom, one a grid row.
var row_views: Array = []
var cursor_view: CursorView
## The one-line real-shell notice.
var notice: Label
## The grid's size in cells.
var columns := MIN_COLUMNS
var rows := MIN_ROWS
## One cell, in pixels, at `font_size`.
var cell_size := Vector2(8, 16)
var font_size := 14
## How far back the view is scrolled, in lines; 0 is the live screen.
var scrollback := 0
## How many rows have been redrawn, for tests: a row counts each time its
## drawing is rebuilt.
var rows_redrawn := 0
## Reads the clipboard: the selection (`primary`, for the middle button)
## or the clipboard (Ctrl-Shift-V). A seam for tests.
var read_clipboard := func(primary: bool) -> String:
	if primary and DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD_PRIMARY):
		return DisplayServer.clipboard_get_primary()
	return DisplayServer.clipboard_get()

## Whether this run of the game has shown the real-shell notice.
static var real_shell_notice_shown := false

## Output not yet fed to the grid.
var _pending_bytes := PackedByteArray()
## The faces the rows draw with: regular, bold, italic and both.
var _faces := {}
var _ink := Color.BLACK
var _paper := Color.WHITE


func build() -> void:
	notice = Label.new()
	notice.name = "Notice"
	notice.visible = false
	notice.clip_text = true
	add_child(notice)
	view = Control.new()
	view.name = "Terminal"
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.clip_contents = true
	view.set_meta("takes_typing", true)
	view.focus_mode = Control.FOCUS_NONE if read_only else Control.FOCUS_ALL
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.gui_input.connect(_on_view_input)
	view.resized.connect(fit)
	view.draw.connect(func() -> void: view.draw_rect(Rect2(Vector2.ZERO, view.size), _paper))
	view.focus_entered.connect(_place_cursor)
	view.focus_exited.connect(_place_cursor)
	add_child(view)
	typing_target = view
	cursor_view = CursorView.new()
	cursor_view.name = "Cursor"
	cursor_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(cursor_view)
	grid = ClassDB.instantiate("TermGrid") if ClassDB.class_exists("TermGrid") else null
	if grid == null:
		show_line(NO_EXTENSION, "", Callable())
		return
	grid.setup(columns, rows)
	_build_rows()
	_show_real_shell_notice()
	_open_stream()


func restyle() -> void:
	super()
	if ui == null:
		return
	_ink = ui.colour("ink")
	_paper = Color(ui.colour("panel"), 1.0)
	cursor_view.colour = _ink
	notice.add_theme_font_override("font", ui.body_font)
	notice.add_theme_font_size_override("font_size", ui.font_size(text_size()))
	notice.add_theme_color_override("font_color", ui.colour("accent"))
	_faces = {}
	fit(true)


func closing() -> void:
	_close_stream()
	super()


## Everything the terminal shows, a line a row, for tests.
func screen_text() -> String:
	var lines := []
	for row in rows:
		lines.append(row_text(row))
	return "\n".join(lines)


## The text of grid row `row` as it shows now.
func row_text(row: int) -> String:
	if grid == null:
		return ""
	var line := ""
	for run in grid.row_runs(row):
		line += run["text"]
	return line


# ---- The stream ----

func _open_stream() -> void:
	stream = source.open_terminal(station_id())
	if stream == null:
		return
	stream.data.connect(_on_data)
	stream.exited.connect(_on_exited)
	stream.failed.connect(_on_failed)
	stream.state_changed.connect(_on_state)
	stream.unsent.connect(_not_sent)
	# A stream already open will not say so again, and the hub still holds
	# its shell at 80x24.
	if stream.state == "open":
		_send_size()


func _close_stream() -> void:
	if stream == null:
		return
	for pair in [[stream.data, _on_data], [stream.exited, _on_exited], [stream.failed, _on_failed],
			[stream.state_changed, _on_state], [stream.unsent, _not_sent]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	stream.close()
	stream = null


## Opens a new shell on a fresh grid, after it ended or failed.
func reconnect() -> void:
	_close_stream()
	clear_error(STREAM)
	_pending_bytes = PackedByteArray()
	scrollback = 0
	grid.setup(columns, rows)
	_open_stream()
	refresh()


func _on_state(state: String) -> void:
	match state:
		"open":
			clear_error(STREAM)
			clear_error(UNSENT)
			_send_size()
		"offline":
			show_error(StationSource.make_error("offline", OFFLINE), reconnect, STREAM)


func _on_failed(reason: Dictionary) -> void:
	show_error(reason, reconnect, STREAM)


func _on_exited() -> void:
	show_line(SESSION_ENDED, RECONNECT, reconnect, STREAM)


## Output is gathered here and fed to the grid once a frame, in `refresh`.
func _on_data(bytes: PackedByteArray) -> void:
	_pending_bytes.append_array(bytes)


func _process(delta: float) -> void:
	super(delta)
	if not _pending_bytes.is_empty():
		refresh()


## Feeds the gathered output to the grid and redraws the rows it changed.
func refresh() -> void:
	if grid == null:
		return
	if not _pending_bytes.is_empty():
		grid.feed(_pending_bytes)
		_pending_bytes = PackedByteArray()
	for row in grid.changed_rows():
		if row < row_views.size():
			var drawn: RowView = row_views[row]
			drawn.runs = _resolve(grid.row_runs(row))
			drawn.queue_redraw()
			rows_redrawn += 1
	scrollback = grid.scrollback_offset()
	_place_cursor()


# ---- Size ----

## Fits the grid to the view: the largest face, up to the skin's, at which
## 80×24 fits, and as many cells as then fit. Sends the size when it
## changes; watching keeps the shell's 80×24.
func fit(force := false) -> void:
	if ui == null or grid == null or view == null:
		return
	var face := mono_font()
	var available := view.size
	# A view not laid out yet (no width or no height) has nothing to fit.
	if available.x <= 0.0 or available.y <= 0.0:
		return
	var preferred := ui.font_size(maxi(10, text_size() - 4))
	var chosen := preferred
	var cell := _cell_of(face, chosen)
	while chosen > SMALLEST_FONT_SIZE and (cell.x * MIN_COLUMNS > available.x or cell.y * MIN_ROWS > available.y):
		chosen -= 1
		cell = _cell_of(face, chosen)
	var cols := MIN_COLUMNS
	var lines := MIN_ROWS
	if not read_only:
		cols = maxi(MIN_COLUMNS, int(available.x / cell.x))
		lines = maxi(MIN_ROWS, int(available.y / cell.y))
	var face_changed := chosen != font_size or cell != cell_size
	font_size = chosen
	cell_size = cell
	if cols != columns or lines != rows:
		columns = cols
		rows = lines
		grid.resize(columns, rows)
		_build_rows()
		_send_size()
	elif face_changed or force:
		_build_rows()
		for row in rows:
			row_views[row].runs = _resolve(grid.row_runs(row))
	refresh()


## One cell at `size_px`: a glyph's true advance, measured over a long
## line because one glyph's width comes back rounded up (7 px where the
## advance is 6.06), which would open a gap after every run.
static func _cell_of(face: Font, size_px: int) -> Vector2:
	var width := face.get_string_size("M".repeat(CELL_SAMPLE), HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x / CELL_SAMPLE
	if width <= 0.0:
		width = size_px * 0.6
	return Vector2(width, ceilf(face.get_height(size_px)))


## One drawing a row, placed at its line.
func _build_rows() -> void:
	while row_views.size() > rows:
		row_views.pop_back().free()
	while row_views.size() < rows:
		var drawn := RowView.new()
		drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.add_child(drawn)
		row_views.append(drawn)
	view.move_child(cursor_view, -1)
	var faces := _face_set()
	for row in rows:
		var drawn: RowView = row_views[row]
		drawn.name = "Row%d" % row
		drawn.position = Vector2(0, row * cell_size.y)
		drawn.size = Vector2(columns * cell_size.x, cell_size.y)
		drawn.faces = faces
		drawn.font_size = font_size
		drawn.cell_size = cell_size
		drawn.paper = _paper
		drawn.queue_redraw()
	view.queue_redraw()


func _send_size() -> void:
	if read_only or stream == null or stream.state != "open":
		return
	stream.send_resize(columns, rows)


# ---- Drawing ----

## The regular, bold, italic and bold italic faces, made once a style.
func _face_set() -> Dictionary:
	if _faces.is_empty():
		var face := mono_font()
		var bold := FontVariation.new()
		bold.base_font = face
		bold.variation_embolden = 0.8
		var italic := FontVariation.new()
		italic.base_font = face
		italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
		var both := FontVariation.new()
		both.base_font = face
		both.variation_embolden = 0.8
		both.variation_transform = italic.variation_transform
		_faces = {"regular": face, "bold": bold, "italic": italic, "bold_italic": both}
	return _faces


## A grid run's colours as drawn: [foreground, background]. A default
## colour (transparent) is the skin's ink or paper; inverse swaps the two,
## since the grid reports it without applying it.
static func run_colours(run: Dictionary, ink: Color, paper: Color) -> Array:
	var fg: Color = run["fg"]
	var bg: Color = run["bg"]
	if fg.a == 0.0:
		fg = ink
	if bg.a == 0.0:
		bg = paper
	return [bg, fg] if run["inverse"] else [fg, bg]


## A row's runs as drawn: each at the column and over the cells the grid
## gives it (vt100's own widths: an emoji or an ideograph covers two), its
## colours resolved and its face chosen.
func _resolve(runs: Array) -> Array:
	var out := []
	for run in runs:
		var colours := run_colours(run, _ink, _paper)
		colours[0] = legible(colours[0], colours[1], LEGIBLE)
		var text: String = run["text"]
		var face := "regular"
		if run["bold"] and run["italic"]:
			face = "bold_italic"
		elif run["bold"]:
			face = "bold"
		elif run["italic"]:
			face = "italic"
		out.append({"text": text, "col": int(run["col"]), "cells": int(run["cells"]), "fg": colours[0],
			"bg": colours[1], "face": face, "underline": run["underline"]})
	return out


## Puts the cursor on its cell: filled while the terminal has the focus,
## an outline while it does not, and hidden while the shell hides it or
## the view is scrolled back.
func _place_cursor() -> void:
	if grid == null or cursor_view == null:
		return
	cursor_view.visible = grid.cursor_visible()
	var at: Vector2i = grid.cursor()
	cursor_view.position = Vector2(at.x * cell_size.x, at.y * cell_size.y)
	cursor_view.size = cell_size
	cursor_view.focused = view.has_focus()
	cursor_view.queue_redraw()


# ---- Input ----

func _on_view_input(event: InputEvent) -> void:
	if event is InputEventKey:
		view.accept_event()
		if not event.pressed or read_only or grid == null:
			return
		if event.ctrl_pressed and event.shift_pressed and _code_of(event) == KEY_V:
			paste(read_clipboard.call(false))
			return
		if is_nul_key(event):
			send_bytes(PackedByteArray([0]))
			return
		var encoded := encode_key(event, grid.application_cursor())
		if encoded != "":
			send(encoded)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				view.accept_event()
				scroll_lines(WHEEL_LINES)
			MOUSE_BUTTON_WHEEL_DOWN:
				view.accept_event()
				scroll_lines(-WHEEL_LINES)
			MOUSE_BUTTON_MIDDLE:
				view.accept_event()
				if not read_only:
					paste(read_clipboard.call(true))
			MOUSE_BUTTON_LEFT:
				if view.focus_mode != Control.FOCUS_NONE:
					view.grab_focus()


## Says that typing did not reach the shell; the line goes when the
## stream opens again.
func _not_sent() -> void:
	not_sent_shown += 1
	show_line(NOT_SENT, "", Callable(), UNSENT)


## Sends keystrokes to the shell, back on the live screen. The stream
## decides what it can take: it holds what is typed while its connection
## waits for the shell, and refuses the rest with `unsent`, which the app
## shows as "Not sent". Only a closed stream is refused here.
func send(text: String) -> void:
	if read_only or stream == null:
		return
	if stream.state == "closed":
		_not_sent()
		return
	if scrollback != 0:
		scroll_lines(-scrollback)
	stream.send_input(text)


## Sends raw bytes to the shell (a NUL), back on the live screen, as `send`
## does. A refusal is reported by the stream's `unsent`, once.
func send_bytes(bytes: PackedByteArray) -> void:
	if read_only or stream == null:
		return
	if stream.state == "closed":
		_not_sent()
		return
	if scrollback != 0:
		scroll_lines(-scrollback)
	stream.send_bytes(bytes)


## Pastes `text`: newlines as Enter, and wrapped in bracketed paste when
## the shell asks for it. Every Esc inside a bracketed paste is taken out,
## as kitty and foot do: taking out only the end marker lets a crafted text
## rebuild one from the pieces round it, ending the bracket early and
## running what follows.
func paste(text: String) -> void:
	if read_only or text == "" or grid == null:
		return
	var body := text.replace("\r\n", "\r").replace("\n", "\r")
	if grid.bracketed_paste():
		body = PASTE_START + body.replace("\u001b", "") + PASTE_END
	send(body)


## Scrolls the view `lines` back into history (forward when negative), no
## further than the history the grid keeps.
func scroll_lines(lines: int) -> void:
	if grid == null:
		return
	grid.scrollback(maxi(0, scrollback + lines))
	refresh()


## Whether `event` is Ctrl-Space or Ctrl-@, which send NUL. `encode_key`
## cannot return it: Godot's strings cannot hold a NUL.
static func is_nul_key(event: InputEventKey) -> bool:
	if not event.ctrl_pressed:
		return false
	var code := _code_of(event)
	return code == KEY_SPACE or code == KEY_AT or (code == KEY_2 and event.shift_pressed)


static func _code_of(event: InputEventKey) -> int:
	return event.keycode if event.keycode != KEY_NONE else event.physical_keycode


## What a key sends to the shell, as xterm encodes it; "" for a key that
## sends nothing (a modifier alone). `application_cursor` is the grid's
## cursor-key mode: the arrows, Home and End then send SS3 sequences.
static func encode_key(event: InputEventKey, application_cursor: bool) -> String:
	var code := _code_of(event)
	var ctrl := event.ctrl_pressed
	var alt := event.alt_pressed
	var shift := event.shift_pressed
	var esc := "\u001b"
	# xterm's modifier parameter: 1, plus 1 for Shift, 2 for Alt, 4 for Ctrl.
	var modifier := 1 + (1 if shift else 0) + (2 if alt else 0) + (4 if ctrl else 0)
	var cursor_keys := {KEY_UP: "A", KEY_DOWN: "B", KEY_RIGHT: "C", KEY_LEFT: "D", KEY_HOME: "H", KEY_END: "F"}
	if cursor_keys.has(code):
		if modifier > 1:
			return esc + "[1;%d%s" % [modifier, cursor_keys[code]]
		return esc + ("O" if application_cursor else "[") + cursor_keys[code]
	var function_keys := {KEY_F1: "P", KEY_F2: "Q", KEY_F3: "R", KEY_F4: "S"}
	if function_keys.has(code):
		return esc + ("[1;%d%s" % [modifier, function_keys[code]] if modifier > 1 else "O" + function_keys[code])
	var tilde_keys := {
		KEY_INSERT: 2, KEY_DELETE: 3, KEY_PAGEUP: 5, KEY_PAGEDOWN: 6, KEY_F5: 15, KEY_F6: 17, KEY_F7: 18,
		KEY_F8: 19, KEY_F9: 20, KEY_F10: 21, KEY_F11: 23, KEY_F12: 24,
	}
	if tilde_keys.has(code):
		return esc + "[%d%s~" % [tilde_keys[code], ";%d" % modifier if modifier > 1 else ""]
	# Alt sends Esc first, as xterm's metaSendsEscape does.
	var prefix := esc if alt else ""
	match code:
		KEY_ENTER, KEY_KP_ENTER:
			return prefix + "\r"
		KEY_BACKSPACE:
			return prefix + ("\b" if ctrl else "\u007f")
		KEY_TAB:
			return esc + "[Z" if shift else prefix + "\t"
		KEY_ESCAPE:
			return prefix + esc
	if ctrl:
		if code >= KEY_A and code <= KEY_Z:
			return prefix + char(code - KEY_A + 1)
		var control_keys := {KEY_BRACKETLEFT: esc, KEY_BACKSLASH: "\u001c", KEY_BRACKETRIGHT: "\u001d",
			KEY_6: "\u001e", KEY_MINUS: "\u001f"}
		if control_keys.has(code):
			return prefix + control_keys[code]
	if event.unicode >= 0x20 and event.unicode != 0x7F:
		return prefix + char(event.unicode)
	return ""


# ---- The real-shell notice ----

## The first terminal opened while live in a run of the game says, on one
## line, that it is a real shell on the station. Kept in memory only, so
## every run warns again.
func _show_real_shell_notice() -> void:
	if read_only or not source.LIVE or real_shell_notice_shown:
		return
	real_shell_notice_shown = true
	notice.text = REAL_SHELL % station_name()
	notice.visible = true


## One row of the grid, drawn from its runs: backgrounds that differ from
## the paper, then the text, then underlines. Redrawn only when its row
## changes, so the engine keeps its drawing between frames.
##
## Every run is drawn at its own column. The grid makes each cell holding
## anything beyond one ASCII character a run of its own, so such a glyph
## lands on its cell whatever a fallback font's advance is; a bold or
## italic run is drawn a glyph a cell too, since emboldening and slanting
## widen the advance. Only a plain run of ASCII in the regular face, whose
## advance is the cell's, is drawn in one piece.
class RowView extends Control:
	var runs: Array = []
	var faces := {}
	var font_size := 14
	var cell_size := Vector2(8, 16)
	var paper := Color.WHITE

	## What `_draw` places, for tests: {run (its index), x, text, face, fg}.
	var layout: Array:
		get:
			return _lay_out()

	func _lay_out() -> Array:
		var out := []
		for index in runs.size():
			var run: Dictionary = runs[index]
			var text: String = run["text"]
			if text.strip_edges().is_empty():
				continue
			var x: float = run["col"] * cell_size.x
			var ascii := true
			for i in text.length():
				ascii = ascii and text.unicode_at(i) <= 0x7E
			if (ascii and run["face"] == "regular") or not ascii:
				# One plain ASCII piece, or one cell's glyph (with any marks
				# combined into it).
				out.append({"run": index, "x": x, "text": text, "face": run["face"], "fg": run["fg"]})
				continue
			for i in text.length():
				if text[i] != " ":
					out.append({"run": index, "x": x + i * cell_size.x, "text": text[i], "face": run["face"],
						"fg": run["fg"]})
		return out

	func _draw() -> void:
		if faces.is_empty():
			return
		var ascent: float = faces["regular"].get_ascent(font_size)
		for run in runs:
			if run["bg"] != paper:
				draw_rect(Rect2(run["col"] * cell_size.x, 0, run["cells"] * cell_size.x, cell_size.y), run["bg"])
		for glyph in _lay_out():
			draw_string(faces[glyph["face"]], Vector2(glyph["x"], ascent), glyph["text"], HORIZONTAL_ALIGNMENT_LEFT,
				-1, font_size, glyph["fg"])
		for run in runs:
			if run["underline"]:
				var x: float = run["col"] * cell_size.x
				draw_line(Vector2(x, ascent + 2), Vector2(x + run["cells"] * cell_size.x, ascent + 2), run["fg"])


## The cursor: a block while the terminal has the focus, an outline while
## it does not.
class CursorView extends Control:
	var colour := Color.BLACK
	var focused := false

	func _draw() -> void:
		if focused:
			draw_rect(Rect2(Vector2.ZERO, size), Color(colour, 0.6))
		else:
			draw_rect(Rect2(Vector2.ZERO, size), colour, false, 1.0)
