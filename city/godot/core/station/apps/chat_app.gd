## The Chat app: the station agent's console session (the console's chat
## tab; AgentPod's ACP session, protocol section 5a). The transcript shows
## the session's events in `seq` order, each once:
##
## - the player's prompt as a bubble;
## - the agent's text and thoughts, consecutive chunks joined into one
##   bubble;
## - a tool call as one collapsible row, which its updates change in place;
## - a plan as a checklist;
## - a permission request as a card with its options (one the mode answered
##   by itself shows as answered);
## - an error as a notice built from its kind;
## - any update it does not know as a quiet "(update)".
##
## The session's state is the status chip, which the computer passes on for
## the monitor's activity pulse (`status_changed`). The player can send a
## prompt, cancel while the agent works, switch the mode (full auto asks
## first) and start a new session.
##
## The session's events are kept by `ChatTranscript` and drawn by
## `ChatRows`, a few rows a frame, so a long session stays responsive.
##
## Watching, it attaches to the station's session (`watch_chat`) and never
## starts one; with none, it says so quietly.
class_name ChatApp
extends StationApp

## The session's status changed: `starting`, `idle`, `working`, `waiting`
## or `ended`.
signal status_changed(status: String)

const STATUS_WORDS := {
	"starting": "Starting", "idle": "Idle", "working": "Working", "waiting": "Waiting", "ended": "Ended",
}
const MODES := ["ask", "accept-edits", "full-auto"]
const MODE_NAMES := {"ask": "Ask", "accept-edits": "Accept edits", "full-auto": "Full auto"}
const CONNECTING := "Connecting…"
const RECONNECTING := "Reconnecting…"
const ENDED := "This session has ended."
## The session ended because its station's node stayed offline.
const ENDED_NODE_LOST := "The station went offline, so this session ended."
## What the hub says of a session whose node dropped: it parks it at
## `waiting` with this reason, and ends it with NODE_LOST_REASON if the node
## is not back within its grace (agentpod@9bc1997:
## apps/hub/src/services/acp-sessions.ts `handleWireClosed`). It never
## reattaches it.
const NODE_OFFLINE_REASON := "node offline"
const NODE_LOST_REASON := "Couldn't reach the node."
## The failure line's key for a session parked while its node is offline.
const NODE := "node"
const NEW_SESSION := "New session"
const UPDATE := "(update)"
const ANSWERED := "Answered"
const ANSWERED_AUTOMATICALLY := "Answered automatically"
const CANCELLED := "Cancelled"
const COULD_NOT_OPEN := "The chat could not open"
## Watching a station with no session open.
const NO_SESSION := "No session"
const PROMPT_HINT := "Ask the agent something"
## What an error says, by its `TurnErrorKind`; its message is the
## provider's and is not shown.
const ERROR_NOTICES := {
	"quota": "The model's quota is used up.",
	"rate_limit": "The model's provider is limiting requests. Try again shortly.",
	"auth": "The agent could not sign in to its model's provider.",
	"bad_request": "The model's provider refused the request.",
	"context_exhausted": "The conversation is too long for the model.",
	"timeout": "The model took too long to answer.",
	"provider_unavailable": "The model's provider is unavailable.",
	"refusal": "The model declined to answer.",
	"max_tokens": "The reply reached the model's length limit.",
	"cancelled": "The turn was cancelled.",
	"node_offline": "The station's node went offline.",
	"harness_exited": "The agent's process exited.",
	"unknown": "The agent's turn failed.",
}
## A plan entry's mark, by its status.
const PLAN_MARKS := {"completed": "☑", "in_progress": "◐", "pending": "☐"}
## How long making rows may take in one frame, in microseconds; the rest
## waits. Laying the new rows out in the same frame costs about twice as
## much again, so a replay's worst frame stays near 8 ms on the bench
## machine (it was 11 ms at 3 ms).
const DRAW_BUDGET_USEC := 2000
## The failure line's keys: the stream, and ending a session.
const STREAM := "stream"
## The failure line's key, and its words, for a message the chat could not
## keep while it reconnected.
const UNSENT := "unsent"
const NOT_SENT := "Not sent: too many messages were waiting"
const ENDING := "ending"

## The open console session's stream.
var stream: StationStream.Chat
## The session's `AcpSessionRow`, as it last came.
var session_row := {}
## The session's status, "" until known.
var status := ""
## The session's mode, as last chosen or reported.
var mode := "ask"

var status_chip: Label
var mode_picker: OptionButton
var menu: MenuButton
var scroll: ScrollContainer
## Where the rows are drawn.
var transcript_box: VBoxContainer
## "This session has ended", with a new one.
var ended_bar: HBoxContainer
var ended_label: Label
var new_session_button: Button
var prompt_field: TextEdit
var send_button: Button
var cancel_turn_button: Button
var prompt_bar: HBoxContainer

## The session's events, each once, in order.
var transcript := ChatTranscript.new()
## The transcript as drawn.
var chat_rows: ChatRows
## Watching a station with no session open.
var _no_session := false
## Why the session ended, as the hub said it ("" until then).
var _ended_reason := ""
## Whether the transcript follows new rows: until the player scrolls up.
var _follow := true


func build() -> void:
	var top := HBoxContainer.new()
	top.name = "Top"
	top.add_theme_constant_override("separation", 12)
	status_chip = Label.new()
	status_chip.name = "Status"
	status_chip.text = CONNECTING
	status_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(status_chip)
	mode_picker = OptionButton.new()
	mode_picker.name = "Mode"
	mode_picker.focus_mode = Control.FOCUS_ALL
	for m in MODES:
		mode_picker.add_item(MODE_NAMES[m])
	mode_picker.item_selected.connect(func(index: int) -> void: pick_mode(MODES[index]))
	mode_picker.visible = not read_only
	top.add_child(mode_picker)
	menu = MenuButton.new()
	menu.name = "Menu"
	menu.text = "Session"
	menu.focus_mode = Control.FOCUS_ALL
	menu.get_popup().add_item(NEW_SESSION, 0)
	menu.get_popup().id_pressed.connect(func(_id: int) -> void: menu_new_session())
	menu.visible = not read_only
	top.add_child(menu)
	add_child(top)

	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	transcript_box = VBoxContainer.new()
	transcript_box.name = "Transcript"
	transcript_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transcript_box.add_theme_constant_override("separation", 8)
	scroll.add_child(transcript_box)
	chat_rows = ChatRows.new(self, transcript_box)
	add_child(scroll)
	var bar := scroll.get_v_scroll_bar()
	bar.changed.connect(func() -> void:
		if _follow:
			scroll.scroll_vertical = int(bar.max_value))
	bar.value_changed.connect(func(value: float) -> void:
		_follow = value >= bar.max_value - bar.page - 4.0)

	ended_bar = HBoxContainer.new()
	ended_bar.name = "Ended"
	ended_bar.add_theme_constant_override("separation", 12)
	ended_label = Label.new()
	ended_label.text = ENDED
	ended_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ended_bar.add_child(ended_label)
	new_session_button = make_button("NewSession", NEW_SESSION, _open_new_session)
	new_session_button.visible = not read_only
	ended_bar.add_child(new_session_button)
	ended_bar.visible = false
	add_child(ended_bar)

	prompt_bar = HBoxContainer.new()
	prompt_bar.name = "Prompt"
	prompt_bar.add_theme_constant_override("separation", 12)
	prompt_field = TextEdit.new()
	prompt_field.name = "Field"
	prompt_field.placeholder_text = PROMPT_HINT
	prompt_field.custom_minimum_size = Vector2(0, 64)
	prompt_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_field.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	prompt_field.editable = not read_only
	prompt_field.focus_mode = Control.FOCUS_NONE if read_only else Control.FOCUS_ALL
	prompt_field.gui_input.connect(_on_prompt_key)
	prompt_bar.add_child(prompt_field)
	send_button = make_button("Send", "Send", send_prompt)
	cancel_turn_button = make_button("CancelTurn", "Cancel", cancel_turn)
	for b in [send_button, cancel_turn_button]:
		b.visible = not read_only
		prompt_bar.add_child(b)
	add_child(prompt_bar)
	typing_target = prompt_field
	_refresh_controls()
	_open_stream()


func restyle() -> void:
	super()
	if ui == null:
		return
	for l in [status_chip, ended_label]:
		l.add_theme_font_override("font", ui.body_font)
		l.add_theme_font_size_override("font_size", ui.font_size(text_size()))
		l.add_theme_color_override("font_color", ui.colour("ink"))
	prompt_field.add_theme_font_override("font", ui.body_font)
	prompt_field.add_theme_font_size_override("font_size", ui.font_size(text_size()))
	prompt_field.add_theme_stylebox_override("normal", well_box())
	prompt_field.add_theme_stylebox_override("read_only", well_box())
	prompt_field.add_theme_color_override("font_color", ui.colour("ink"))
	prompt_field.add_theme_color_override("font_readonly_color", ui.colour("ink_muted"))
	prompt_field.add_theme_color_override("font_placeholder_color", ui.colour("ink_muted"))
	prompt_field.add_theme_color_override("caret_color", ui.colour("ink"))
	chat_rows.restyle()


func closing() -> void:
	_let_go_of_stream()
	super()


# ---- The stream ----

## Opens the session: the player's open one, or a new one in `mode`
## (always a new one with `new_session`, the player's "New session").
## Watching, it only attaches: it never starts a session as the watcher.
func _open_stream(new_session := false) -> void:
	_no_session = false
	stream = source.watch_chat(station_id()) if read_only else source.open_chat(station_id(), mode, new_session)
	if stream == null:
		show_line(COULD_NOT_OPEN, RETRY, _reopen, STREAM)
		return
	stream.event.connect(_on_event)
	stream.session.connect(_on_session)
	stream.state_changed.connect(_on_stream_state)
	stream.failed.connect(_on_failed)
	stream.unsent.connect(_on_unsent)
	_refresh_controls()


## Stops listening to the stream and closes it.
func _let_go_of_stream() -> void:
	if stream == null:
		return
	var old := stream
	stream = null
	old.event.disconnect(_on_event)
	old.session.disconnect(_on_session)
	old.state_changed.disconnect(_on_stream_state)
	old.failed.disconnect(_on_failed)
	old.unsent.disconnect(_on_unsent)
	old.close()


## Opens the stream again after a failure: the same session, whose events
## the transcript already has are not drawn twice.
func _reopen() -> void:
	clear_error(STREAM)
	_let_go_of_stream()
	_open_stream()


func _on_failed(reason: Dictionary) -> void:
	if read_only and str(reason.get("kind", "")) == "not_found":
		# Nothing to watch: a state, not a failure to retry.
		_no_session = true
		clear_error(STREAM)
		_refresh_controls()
		return
	show_error(reason, _reopen, STREAM)


func _on_unsent() -> void:
	show_line(NOT_SENT, "", Callable(), UNSENT)


func _on_stream_state(_state: String) -> void:
	if stream != null and stream.state == "open":
		clear_error(STREAM)
		clear_error(UNSENT)
		chat_rows.reopen_options()
	_refresh_controls()


func _on_session(row: Dictionary) -> void:
	if not session_row.is_empty() and str(row.get("id", "")) != str(session_row.get("id", "")):
		_clear_transcript()
	session_row = row
	if row.get("endedReason") is String:
		_ended_reason = row["endedReason"]
	# A row does not say why a session waits; one not waiting is not parked
	# for its node (the end may come as a row alone, its events lost with
	# the close).
	if str(row.get("status", "")) != "waiting":
		clear_error(NODE)
	var reported := str(row.get("mode", mode))
	if reported in MODES and not asking():
		mode = reported
		_show_mode(mode)
	_set_status(str(row.get("status", status)))


## Takes one event: once, in `seq` order (see `ChatTranscript`), and
## queues it to be drawn.
func _on_event(acp_event: Dictionary) -> void:
	if closed:
		return
	var taken := transcript.take(acp_event)
	if taken == ChatTranscript.Taken.REPEAT:
		return
	if taken == ChatTranscript.Taken.LATE:
		# Out of order, which is rare: the transcript is drawn again.
		chat_rows.redraw(transcript.events)
		return
	var payload: Dictionary = acp_event.get("payload", {}) if acp_event.get("payload") is Dictionary else {}
	match str(acp_event.get("type", "")):
		"state":
			if taken == ChatTranscript.Taken.NEWEST:
				_show_node(payload)
				_set_status(str(payload.get("status", status)))
		"permission-answer":
			chat_rows.show_answer(int(payload.get("requestSeq", 0)))
	chat_rows.queue(acp_event)


## The session's newest state says whether its node is offline: parked at
## `waiting` for it shows "Station offline" (there is nothing to retry: the
## hub keeps the session while it waits); any other state clears it. An
## end remembers why, to say so beside New session.
func _show_node(state_payload: Dictionary) -> void:
	if state_payload.get("status") == "waiting" and state_payload.get("reason") == NODE_OFFLINE_REASON:
		show_line(OFFLINE, "", Callable(), NODE)
	else:
		clear_error(NODE)
	if state_payload.get("status") == "ended" and state_payload.get("reason") is String:
		_ended_reason = state_payload["reason"]


func _set_status(next: String) -> void:
	if not next in STATUS_WORDS or next == status:
		_refresh_controls()
		return
	status = next
	_refresh_controls()
	status_changed.emit(status)


func _refresh_controls() -> void:
	if status_chip == null:
		return
	var open := stream != null and stream.state == "open"
	if _no_session:
		status_chip.text = NO_SESSION
	elif stream != null and stream.state == "offline":
		status_chip.text = RECONNECTING
	elif status == "":
		status_chip.text = CONNECTING
	else:
		status_chip.text = STATUS_WORDS[status]
	send_button.disabled = read_only or not open or status != "idle"
	cancel_turn_button.disabled = read_only or not open or not status in ["working", "waiting"]
	mode_picker.disabled = read_only or not open or status == "ended"
	ended_bar.visible = status == "ended"
	ended_label.text = ENDED_NODE_LOST if _ended_reason == NODE_LOST_REASON else ENDED


# ---- What the player does ----

## Sends what the prompt field holds, when the agent is idle.
func send_prompt() -> void:
	if read_only or send_button.disabled:
		return
	var text := prompt_field.text.strip_edges()
	if text == "":
		return
	stream.prompt(text)
	prompt_field.text = ""


## Enter sends; Shift-Enter is a new line.
func _on_prompt_key(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.shift_pressed:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		prompt_field.accept_event()
		send_prompt()


## Stops the agent's turn.
func cancel_turn() -> void:
	if read_only or cancel_turn_button.disabled:
		return
	stream.cancel()


## Switches the session to `next`: at once, except full auto, which asks
## first, naming the station.
func pick_mode(next: String) -> void:
	# A question still showing (full auto, a new session) is put away.
	cancel_confirm()
	if read_only or stream == null or not next in MODES or next == mode:
		_show_mode(mode)
		return
	if next != "full-auto":
		_switch_mode(next)
		return
	var question := "Let %s's agent act without asking? In full auto it answers every permission request itself." \
			% station_name()
	if source.LIVE:
		question += " This is real: the agent acts on the station at once."
	_show_mode(next)
	ask_first(question, MODE_NAMES[next], _switch_mode.bind(next), _show_mode.bind(mode))


## The hub sends no reply to a mode switch, so it is taken as done; a later
## session row says otherwise if it was not.
func _switch_mode(next: String) -> void:
	if stream == null:
		return
	stream.set_mode(next)
	mode = next
	_show_mode(next)


func _show_mode(shown: String) -> void:
	mode_picker.select(MODES.find(shown))


## "New session" from the menu: asks first while the session is open, then
## ends it and opens a new one.
func menu_new_session() -> void:
	if read_only:
		return
	if status == "ended" or session_row.is_empty():
		_open_new_session()
		return
	ask_first("End this session with %s's agent and start a new one?" % station_name(), NEW_SESSION,
		_end_then_open)


func _end_then_open() -> void:
	request(source.end_chat(str(session_row.get("id", ""))), func(ok: bool, body: Variant, _status: int) -> void:
		var error: Dictionary = body if body is Dictionary else {}
		if not ok and str(error.get("kind", "")) != "not_found":
			show_error(error, _end_then_open, ENDING)
			return
		clear_error(ENDING)
		_open_new_session())


## Closes the session's stream and opens a new session on an empty
## transcript.
func _open_new_session() -> void:
	if read_only:
		return
	_let_go_of_stream()
	clear_error(STREAM)
	_clear_transcript()
	session_row = {}
	status = ""
	_open_stream(true)


func _clear_transcript() -> void:
	transcript.clear()
	chat_rows.clear()
	_follow = true
	_ended_reason = ""
	clear_error(NODE)


# ---- Drawing ----

## Whether events or text are still waiting to be drawn.
func drawing() -> bool:
	return chat_rows.drawing()


## Draws everything waiting, at once.
func flush() -> void:
	chat_rows.flush()


func _process(delta: float) -> void:
	super(delta)
	if closed:
		return
	chat_rows.draw_queued(DRAW_BUDGET_USEC)
	chat_rows.set_text()


## The text of an ACP content block: its text, or what kind of thing it is.
static func content_text(content: Variant) -> String:
	if not content is Dictionary:
		return ""
	match str(content.get("type", "")):
		"text":
			return str(content.get("text", ""))
		"resource_link":
			return "[%s]" % str(content.get("name", content.get("uri", "link")))
		var other:
			return "[%s]" % other if other != "" else ""


## A plan as a checklist, an entry a line.
static func plan_text(entries: Variant) -> String:
	var lines := PackedStringArray()
	if entries is Array:
		for entry in entries:
			if entry is Dictionary:
				lines.append("%s %s" % [PLAN_MARKS.get(str(entry.get("status", "")), "☐"), str(entry.get("content", ""))])
	return "\n".join(lines)


## What an error event says: from its kind; one without a kind (a message
## the hub refused) says the hub's one line.
static func notice_for(payload: Dictionary) -> String:
	var kind = payload.get("kind")
	if kind is String and kind != "":
		return ERROR_NOTICES.get(kind, ERROR_NOTICES["unknown"])
	var message := str(payload.get("message", "")).strip_edges().get_slice("\n", 0)
	return message if message != "" else SOMETHING_WENT_WRONG


## Sends the chosen option for request `seq`; its options wait for the
## hub to record the answer.
func choose_option(seq: int, option_id: String) -> void:
	if read_only or stream == null:
		return
	stream.answer(seq, option_id)
	chat_rows.hold_options(seq)


## The card for the permission request at `seq`, or null.
func permission_card(seq: int) -> Control:
	flush()
	return chat_rows.permission_card(seq)


## The transcript as shown, for tests: each row's kind and its words.
func rows() -> Array:
	flush()
	return chat_rows.rows()
