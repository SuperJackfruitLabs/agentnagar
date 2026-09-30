## The Logs app: the station's live log tail (the console's logs tab).
##
## - The newest 5,000 lines are kept in a ring; older ones fall off.
## - The view follows the newest line until the player pauses it. Paused, it
##   holds still while lines still arrive into the ring; Resume goes back to
##   the newest. Scrolling back, or jumping to a match, pauses it too, so the
##   line the player is reading stays put.
## - Search matches without regard to case, highlights every match in view,
##   and jumps between them, round from either end.
##
## Only the lines in view are drawn, so a full ring costs no more a frame
## than a short one.
class_name LogsApp
extends StationApp

## How many lines the ring keeps.
const RING_LINES := 5000
## Lines a wheel notch scrolls.
const WHEEL_LINES := 3
const PAUSE := "Pause"
const RESUME := "Resume"
const PREVIOUS := "Previous"
const NEXT := "Next"
const NO_MATCHES := "No matches"
## The failure line's key for the tail's stream.
const STREAM := "stream"
## Room at the left of each line, in pixels.
const MARGIN := 6.0

var stream: StationStream.Logs
var pause_button: Button
var search_field: LineEdit
var previous_button: Button
var next_button: Button
var match_label: Label
var log_view: Control
var scroll_bar: VScrollBar
## Whether the view holds still instead of following the newest line.
var paused := false
## Whether this stream has opened before: its next `open` is a reconnection.
var _opened_before := false

## The ring: line number `n` (counting every line ever received) is kept at
## `n % RING_LINES` while it is among the newest RING_LINES.
var _ring := PackedStringArray()
## How many lines have arrived in all.
var _total := 0
## The line number at the top of the view.
var _top := 0
## The search, lower-cased; "" for none.
var _query := ""
## Every match found, oldest first: [line number, column]. Those before
## `_first_match` belong to lines the ring has let go; they are dropped in
## bulk now and then, so a full ring costs each new line the same however
## many matches there are.
var _matches: Array = []
var _first_match := 0
## Which match is current, counting from the oldest kept, or -1.
var _current := -1
## Set while the scroll bar is being moved to match the view, so its own
## signal does not move the view back.
var _syncing := false
var _font_size := 14
var _line_height := 18.0


func build() -> void:
	_ring.resize(RING_LINES)
	var bar := HBoxContainer.new()
	bar.name = "Toolbar"
	bar.add_theme_constant_override("separation", 8)
	pause_button = make_button("Pause", PAUSE, toggle_pause)
	bar.add_child(pause_button)
	search_field = LineEdit.new()
	search_field.name = "Search"
	search_field.placeholder_text = "Search"
	search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_field.text_changed.connect(search)
	search_field.text_submitted.connect(func(_text: String) -> void: next_match())
	bar.add_child(search_field)
	previous_button = make_button("Previous", PREVIOUS, previous_match)
	bar.add_child(previous_button)
	next_button = make_button("Next", NEXT, next_match)
	bar.add_child(next_button)
	match_label = Label.new()
	match_label.name = "Matches"
	bar.add_child(match_label)
	add_child(bar)
	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view = Control.new()
	log_view.name = "Lines"
	log_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view.clip_contents = true
	log_view.mouse_filter = Control.MOUSE_FILTER_STOP
	log_view.draw.connect(_draw_lines)
	log_view.resized.connect(_show)
	log_view.gui_input.connect(_on_view_input)
	body.add_child(log_view)
	scroll_bar = VScrollBar.new()
	scroll_bar.name = "Scroll"
	scroll_bar.step = 1.0
	scroll_bar.value_changed.connect(_on_scrolled)
	body.add_child(scroll_bar)
	add_child(body)
	_refresh_matches_label()
	_open_stream()


func restyle() -> void:
	super()
	if ui == null:
		return
	_font_size = ui.font_size(maxi(10, text_size() - 4))
	_line_height = ceilf(mono_font().get_height(_font_size)) + 2.0
	match_label.add_theme_font_override("font", ui.body_font)
	match_label.add_theme_font_size_override("font_size", ui.font_size(text_size()))
	match_label.add_theme_color_override("font_color", ui.colour("ink_muted"))
	_show()


func closing() -> void:
	_close_stream()
	super()


# ---- The stream ----

func _open_stream() -> void:
	stream = source.open_logs(station_id())
	if stream == null:
		return
	stream.line.connect(_on_line)
	stream.failed.connect(_on_failed)
	stream.state_changed.connect(_on_state)


func _close_stream() -> void:
	if stream == null:
		return
	for pair in [[stream.line, _on_line], [stream.failed, _on_failed], [stream.state_changed, _on_state]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	stream.close()
	stream = null


## Opens the tail again, from its backlog, on an empty ring (the backlog
## would repeat what the ring holds).
func reopen() -> void:
	_close_stream()
	clear_error(STREAM)
	_clear_ring()
	_open_stream()
	_show()


## Empties the ring and what was found in it.
func _clear_ring() -> void:
	_total = 0
	_top = 0
	_matches.clear()
	_first_match = 0
	_current = -1
	_opened_before = false
	_refresh_matches_label()


func _on_state(state: String) -> void:
	match state:
		"open":
			clear_error(STREAM)
			# The tail reconnected, and starts again with lines already here.
			if _opened_before:
				_clear_ring()
				_show()
			_opened_before = true
		"offline":
			show_error(StationSource.make_error("offline", OFFLINE), reopen, STREAM)


func _on_failed(reason: Dictionary) -> void:
	show_error(reason, reopen, STREAM)


## A new line: into the ring, and among the matches if it matches; the
## oldest falls off when the ring is full.
func _on_line(text: String) -> void:
	var number := _total
	_ring[number % RING_LINES] = text
	_total += 1
	if _query != "":
		_append_matches(number, text)
	var first := first_line()
	var dropped := 0
	while _first_match < _matches.size() and _matches[_first_match][0] < first:
		_first_match += 1
		dropped += 1
	if dropped > 0:
		# A current match that fell off gives way to the oldest one left.
		_current -= dropped
		if _current < 0:
			_current = 0 if match_count() > 0 else -1
		if _first_match > 4096 and _first_match * 2 > _matches.size():
			_matches = _matches.slice(_first_match)
			_first_match = 0
		_refresh_matches_label()
	_show()


# ---- The ring ----

## How many lines the ring holds.
func line_count() -> int:
	return mini(_total, RING_LINES)


## The line number of the oldest line kept.
func first_line() -> int:
	return maxi(0, _total - RING_LINES)


## Kept line `index`, 0 being the oldest.
func line(index: int) -> String:
	return _ring[(first_line() + index) % RING_LINES]


## How many lines the view shows at once.
func visible_count() -> int:
	return maxi(1, int(log_view.size.y / _line_height))


## The lines in view, top to bottom.
func lines_in_view() -> Array:
	var out := []
	for number in range(_top, mini(_top + visible_count(), _total)):
		out.append(_ring[number % RING_LINES])
	return out


# ---- Following and pausing ----

## Pause or Resume.
func toggle_pause() -> void:
	set_paused(not paused)


func set_paused(value: bool) -> void:
	paused = value
	pause_button.text = RESUME if paused else PAUSE
	_show()


## Places the view: at the newest line while following, else where it was,
## as far as the ring still holds it.
func _show() -> void:
	if log_view == null:
		return
	var bottom := maxi(first_line(), _total - visible_count())
	_top = bottom if not paused else clampi(_top, first_line(), bottom)
	_syncing = true
	scroll_bar.max_value = maxf(1.0, float(line_count()))
	scroll_bar.page = float(visible_count())
	scroll_bar.value = float(_top - first_line())
	_syncing = false
	log_view.queue_redraw()


func _on_scrolled(value: float) -> void:
	if _syncing:
		return
	_top = first_line() + int(value)
	if not paused:
		set_paused(true)
	else:
		_show()


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			log_view.accept_event()
			_top -= WHEEL_LINES
			set_paused(true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			log_view.accept_event()
			_top += WHEEL_LINES
			_show()


# ---- Search ----

## Searches the kept lines for `text`, without regard to case, and shows
## the newest match.
func search(text: String) -> void:
	_query = text.to_lower()
	_matches.clear()
	_first_match = 0
	_current = -1
	if _query != "":
		for index in line_count():
			_append_matches(first_line() + index, line(index))
	if match_count() > 0:
		_current = match_count() - 1
		_reveal(false)
	_refresh_matches_label()
	log_view.queue_redraw()


func _append_matches(number: int, text: String) -> void:
	var at := text.findn(_query)
	while at >= 0:
		_matches.append([number, at])
		at = text.findn(_query, at + maxi(1, _query.length()))


## How many matches the kept lines hold.
func match_count() -> int:
	return _matches.size() - _first_match


## Match `index`, counting from the oldest kept: [line number, column].
func _match(index: int) -> Array:
	return _matches[_first_match + index]


## The next match, round to the first after the last.
func next_match() -> void:
	if match_count() == 0:
		return
	_current = (_current + 1) % match_count()
	_reveal(true)
	_refresh_matches_label()


## The match before, round to the last before the first.
func previous_match() -> void:
	if match_count() == 0:
		return
	_current = (_current - 1 + match_count()) % match_count()
	_reveal(true)
	_refresh_matches_label()


## Brings the current match into view, centred if it was out of it. A jump
## (`hold`) pauses the view, so the match stays put as lines arrive;
## otherwise it pauses only if the view had to move.
func _reveal(hold: bool) -> void:
	var number: int = _match(_current)[0]
	var shown := visible_count()
	var in_view := number >= _top and number < _top + shown
	if not in_view:
		_top = number - shown / 2
	if hold or not in_view:
		set_paused(true)
	else:
		_show()


func _refresh_matches_label() -> void:
	if _query == "":
		match_label.text = ""
	elif match_count() == 0:
		match_label.text = NO_MATCHES
	else:
		match_label.text = "%d of %d" % [_current + 1, match_count()]
	previous_button.disabled = match_count() == 0
	next_button.disabled = match_count() == 0


## The matches in view, as drawn: {line, col, length, current}.
func highlights() -> Array:
	var out := []
	if _query == "":
		return out
	var current: Array = _match(_current) if _current >= 0 else []
	for number in range(_top, mini(_top + visible_count(), _total)):
		var text := _ring[number % RING_LINES]
		var at := text.findn(_query)
		while at >= 0:
			out.append({"line": text, "col": at, "length": _query.length(), "number": number,
				"current": not current.is_empty() and current[0] == number and current[1] == at})
			at = text.findn(_query, at + maxi(1, _query.length()))
	return out


# ---- Drawing ----

## Draws the lines in view, each match's highlight behind its text: the
## current one in the accent, the rest fainter in the focus colour; both
## see-through, so the ink stays legible over them.
func _draw_lines() -> void:
	if ui == null:
		return
	var face := mono_font()
	var ascent := face.get_ascent(_font_size)
	var ink := ui.colour("ink")
	var marks := {}
	for mark in highlights():
		marks.get_or_add(mark["number"], []).append(mark)
	var row := 0
	for number in range(_top, mini(_top + visible_count(), _total)):
		var text := _ring[number % RING_LINES]
		var y := row * _line_height
		for mark in marks.get(number, []):
			var x := MARGIN + face.get_string_size(text.substr(0, mark["col"]), HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
			var width := face.get_string_size(text.substr(mark["col"], mark["length"]), HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
			var colour := Color(ui.colour("accent"), 0.5) if mark["current"] else Color(ui.colour("focus"), 0.25)
			log_view.draw_rect(Rect2(x, y, width, _line_height), colour)
		log_view.draw_string(face, Vector2(MARGIN, y + 1.0 + ascent), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, ink)
		row += 1
