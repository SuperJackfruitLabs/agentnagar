## Sample station's board channel: the board's snapshot, then each change
## `SampleWork` makes to it.
class_name SampleBoardStream
extends StationStream.Board

var board_id: String
var _source: SampleSource
var _work: SampleWork


func _init(source: SampleSource, work: SampleWork, id: String) -> void:
	_source = source
	_work = work
	board_id = id
	_work.watch(self)
	_source.after(0.0, _open)


func close() -> void:
	_set_state("closed")


func _open() -> void:
	if state == "closed":
		return
	if not _work.has_board(board_id):
		failed.emit(StationSource.make_error("not_found", "board not found"))
		_set_state("closed")
		return
	_set_state("open")
	snapshot.emit(_work.snapshot(board_id))
