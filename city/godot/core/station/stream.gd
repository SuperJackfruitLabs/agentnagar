## A stream from a station or a board: the log tail, the terminal, the
## agent's chat or the board's push channel. A `StationSource` opens one and
## the app that asked holds it, listens to its signals and closes it when it
## is done. Every kind shares the connection's state and its failure; each
## kind below adds what it carries.
##
## A stream starts `connecting`. It never emits inside the call that opened
## it, so the app can connect its signals first, as it must for a live one.
@abstract
class_name StationStream
extends RefCounted

## The connection's state changed: `connecting`, `open`, `offline` (lost,
## and trying again) or `closed` (for good).
signal state_changed(state: String)

## The stream could not open or was refused. `reason` is a normalised
## error, `{kind, message}`, as `StationSource.make_error` builds.
signal failed(reason: Dictionary)

## Something the player sent could not be sent or kept (the connection is
## down, or too much already waits), so it was dropped; the app says so.
## Emitted inside the call that sent it.
signal unsent()

const STATES := ["connecting", "open", "offline", "closed"]

## The connection's current state; see `state_changed`.
var state := "connecting"


## Stops the stream for good. No signal but `state_changed("closed")` is
## emitted after it.
@abstract func close() -> void


## Moves to `next` and says so, once.
func _set_state(next: String) -> void:
	if next == state:
		return
	state = next
	state_changed.emit(next)


## The station's log tail (AgentPod's SSE route), a line at a time. The
## node starts every tail with its last lines, so after a reconnection
## (`offline`, then `open` again) the tail repeats lines it already sent;
## an app starts its view afresh on each `open`.
@abstract
class Logs extends StationStream:
	## One log line, without its newline.
	signal line(text: String)


## The station's shell (AgentPod's terminal WebSocket). Its output is raw
## terminal bytes, for `TermGrid.feed`.
@abstract
class Terminal extends StationStream:
	## Output from the shell, as the bytes it wrote.
	signal data(bytes: PackedByteArray)
	## The shell ended; the stream closes after this.
	signal exited()

	## Sends keystrokes, already encoded as the terminal expects.
	@abstract func send_input(text: String) -> void

	## Sends keystrokes as raw bytes, for what a String cannot carry: NUL
	## (Ctrl-Space), which Godot's strings replace. A live source sends it in
	## the same `input` frame, escaped in its JSON (`\u0000`). False when
	## they cannot be sent, and `unsent` says so: the terminal protocol
	## carries text, so bytes that are not UTF-8 (apart from their NULs) are
	## refused, as is anything a live source cannot send or hold.
	@abstract func send_bytes(bytes: PackedByteArray) -> bool

	## Tells the shell its window's size in cells.
	@abstract func send_resize(cols: int, rows: int) -> void


## The agent's console session (AgentPod's ACP session WebSocket, §5a).
## On opening it replays the session: `session`, then every `event` in
## `seq` order, then `replay_done`, then live events.
@abstract
class Chat extends StationStream:
	## An `AcpEvent`: `{sessionId, seq, type, payload, createdAt}`. An event
	## whose `seq` is 0 is outside the transcript (a refused message).
	signal event(acp_event: Dictionary)
	## The session's `AcpSessionRow`.
	signal session(row: Dictionary)
	## The replay has caught up; `last_seq` is the last event it sent.
	signal replay_done(last_seq: int)

	## Asks the agent something.
	@abstract func prompt(text: String) -> void

	## Stops the agent's turn, answering any waiting request as cancelled.
	@abstract func cancel() -> void

	## Answers the permission request whose event had `request_seq`.
	@abstract func answer(request_seq: int, option_id: String) -> void

	## Switches the session to `ask`, `accept-edits` or `full-auto`.
	@abstract func set_mode(mode: String) -> void


## A Superpipeline board's push channel. It opens with the whole board, then
## sends each change; nothing is ever sent the other way.
@abstract
class Board extends StationStream:
	## The whole board: a `BoardSnapshot`.
	signal snapshot(board_state: Dictionary)
	## One change: `{seq, type, payload, ts}`.
	signal board_event(change: Dictionary)
