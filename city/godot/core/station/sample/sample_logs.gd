## Sample station's log tail: the recorded tail at once, then the rest a
## line at a time.
class_name SampleLogStream
extends StationStream.Logs

## The tail sends this many lines at once, as a tail does, and then the
## rest one at a time, FOLLOW_SECONDS apart.
const BACKLOG_LINES := 40
const FOLLOW_SECONDS := 1.5

var _source: SampleSource
var _station_id: String


func _init(source: SampleSource, station_id: String) -> void:
	_source = source
	_station_id = station_id
	_source.after(0.0, _open)


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
	var backlog := mini(BACKLOG_LINES, _source.log_lines.size())
	for i in backlog:
		line.emit(_source.log_lines[i])
	_follow(backlog)


func _follow(index: int) -> void:
	if state == "closed" or index >= _source.log_lines.size():
		return
	_source.after(FOLLOW_SECONDS, func() -> void:
		if state == "closed":
			return
		line.emit(_source.log_lines[index])
		_follow(index + 1))
