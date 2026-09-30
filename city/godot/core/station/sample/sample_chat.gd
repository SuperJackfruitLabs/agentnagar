## Sample station's chat: a view onto the console session the source keeps
## (`SampleChatState`). Opening replays the session as the hub's socket
## does; the messages it sends are handled on a later frame, and only while
## it is open.
class_name SampleChatStream
extends StationStream.Chat

var _source: SampleSource
var _session: SampleChatState
var _station_id: String
## Watch mode's stream (`watch_chat`): an ended session is not one to
## attach to.
var _attach_only := false


func _init(source: SampleSource, session_state: SampleChatState, station_id: String, attach_only := false) -> void:
	_source = source
	_session = session_state
	_station_id = station_id
	_attach_only = attach_only
	_session.watch(self)
	_source.after(0.0, _open)


func prompt(text: String) -> void:
	_later(_session.prompt.bind(self, text))


func cancel() -> void:
	_later(_session.cancel)


func answer(request_seq: int, option_id: String) -> void:
	_later(_session.answer.bind(self, request_seq, option_id))


func set_mode(mode: String) -> void:
	_later(_session.set_mode.bind(self, mode))


func close() -> void:
	_set_state("closed")


## Sends a message to the session, as a socket would.
func _later(message: Callable) -> void:
	_source.after(0.0, func() -> void:
		if state == "open":
			message.call())


func _open() -> void:
	if state == "closed":
		return
	if not _source.has_station(_station_id):
		failed.emit(StationSource.make_error("not_found", "Not Found"))
		_set_state("closed")
		return
	if _attach_only and _session.session["status"] == "ended":
		failed.emit(StationSource.make_error("not_found", StationSource.NO_SESSION))
		_set_state("closed")
		return
	_set_state("open")
	session.emit(_session.session.duplicate(true))
	for recorded in _session.events:
		event.emit(recorded.duplicate(true))
	replay_done.emit(_session.session["lastSeq"])
