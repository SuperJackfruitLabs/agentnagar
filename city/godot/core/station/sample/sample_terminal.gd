## Sample station's terminal: plays the recording's opening, then a command
## each time Enter is pressed, looping back to the first after the last.
## Typing is echoed and Backspace rubs out, as a shell's line editor would;
## input that arrives while a command plays waits until it has finished.
## Ctrl-D on an empty line logs out.
class_name SampleTerminalStream
extends StationStream.Terminal

## The window's size in cells, as last sent; the recording is 80×24
## whatever it is.
var columns := 80
var rows := 24

var _source: SampleSource
var _station_id: String
var _next_command := 1
var _playing := true
## What the player has typed on the prompt's line.
var _typed := ""
## Input not yet handled, because a command was playing.
var _pending := ""


## Reads an asciicast v2 recording into segments: the output before the
## first marker, which opens the terminal, then one per marker, the command
## the next Enter plays. Each segment is a list of [gap, text], the gap in
## recorded seconds and cut to SampleSource.MAX_GAP.
static func read_cast(cast: String) -> Array:
	var segments: Array = [[]]
	var last := 0.0
	var lines := cast.split("\n", false)
	for i in range(1, lines.size()):
		var event = JSON.parse_string(lines[i])
		var at := float(event[0])
		var gap := minf(at - last, SampleSource.MAX_GAP)
		last = at
		if event[1] == "m":
			segments.append([])
		elif event[1] == "o":
			# A segment's first gap counts from its marker, not from the
			# end of the one before, which waited for Enter.
			segments.back().append([gap, event[2]])
	return segments


func _init(source: SampleSource, station_id: String) -> void:
	_source = source
	_station_id = station_id
	_source.after(0.0, _open)


func send_input(text: String) -> void:
	if state == "closed":
		return
	_pending += text
	_source.after(0.0, _handle_input)


## The recording has no use for a NUL, the only thing sent this way.
func send_bytes(_bytes: PackedByteArray) -> bool:
	return true


func send_resize(cols: int, rows_: int) -> void:
	columns = cols
	rows = rows_


func close() -> void:
	_set_state("closed")


func _open() -> void:
	if state == "closed":
		return
	if not _source.has_station(_station_id):
		failed.emit(StationSource.make_error("not_found", "Not Found"))
		_set_state("closed")
		return
	_set_state("open")
	_play(_source.terminal_segments[0])


func _play(segment: Array) -> void:
	_playing = true
	if segment.is_empty():
		_finish()
		return
	_source.after(segment[0][0], _step.bind(segment, 0))


## Sends the event at `index`, with any that follow too closely to be
## worth a frame of their own, then waits for the next.
func _step(segment: Array, index: int) -> void:
	if state == "closed":
		return
	var bytes: PackedByteArray = segment[index][1].to_utf8_buffer()
	index += 1
	while index < segment.size() and segment[index][0] / maxf(_source.speed, 0.001) < 0.001:
		bytes.append_array(segment[index][1].to_utf8_buffer())
		index += 1
	data.emit(bytes)
	if index < segment.size():
		_source.after(segment[index][0], _step.bind(segment, index))
	else:
		_finish()


func _finish() -> void:
	_playing = false
	_handle_input()


func _handle_input() -> void:
	if state == "closed" or _playing:
		return
	var echo := ""
	while not _pending.is_empty():
		var key := _pending[0]
		_pending = _pending.substr(1)
		if key == "\r" or key == "\n":
			# The recorded command replaces whatever was typed.
			echo += "\b \b".repeat(_typed.length())
			_typed = ""
			if not echo.is_empty():
				data.emit(echo.to_utf8_buffer())
			var segments: Array = _source.terminal_segments
			var segment: Array = segments[_next_command]
			_next_command = _next_command + 1 if _next_command + 1 < segments.size() else 1
			_play(segment)
			return
		elif key == "\u007f" or key == "\b":
			if not _typed.is_empty():
				_typed = _typed.left(-1)
				echo += "\b \b"
		elif key == "\u0004":
			if _typed.is_empty():
				data.emit((echo + "logout\r\n").to_utf8_buffer())
				exited.emit()
				_set_state("closed")
				return
		elif key == "\u001b":
			_skip_escape()
		elif key.unicode_at(0) >= 0x20:
			_typed += key
			echo += key
	if not echo.is_empty():
		data.emit(echo.to_utf8_buffer())


## Drops the rest of an escape sequence (an arrow, a function key), which
## the recording has no use for.
func _skip_escape() -> void:
	if _pending.is_empty() or not _pending[0] in ["[", "O"]:
		return
	var i := 1
	while i < _pending.length() and not (_pending.unicode_at(i) >= 0x40 and _pending.unicode_at(i) <= 0x7E):
		i += 1
	_pending = _pending.substr(i + 1)
