## The station computer (interactions spec sections 4 and 5): what using a
## workstation opens. A full-screen screen framed as the style's monitor
## bezel, holding a small desktop for one station and a dock of its apps.
##
## - Which station: a hot desk lists the stations the source can see and
##   opens the one chosen; a bound desk opens its own station, or says
##   "You don't have access to this station". With Sample station, every
##   desk opens it (a hot desk through the chooser, where it is the one
##   choice).
## - The bezel: the style's frame (its `ui.bezel` block), the "Sample" or
##   "Live" badge, "Watching" in watch mode, the station's name and
##   "Stand up".
## - Focus: while it is open the input router is in computer mode, so no
##   game action fires. F10, "Stand up" and B held for half a second
##   always leave; Esc leaves too, except while a terminal or text field
##   has the focus, where the key is the field's.
## - Watch mode: the same computer over someone's shoulder, with input off.
##
## It never talks to the network itself: everything comes through its
## `StationSource`. "Connect your AgentPod" and "Sign in again" only emit
## `sign_in_requested`, which the sign-in code answers.
extends Screen
class_name ComputerScreen

## The player chose to leave: F10, "Stand up", B held, or Esc. The screen
## removes itself after this; whoever opened it sends StopUsing.
signal left
## "Connect your AgentPod" with live mode on, or "Sign in again".
signal sign_in_requested
## "Disconnect", live: the sign-in code revokes the device and forgets it.
signal disconnect_requested
## "Connect your AgentPod" with live mode off: Settings, at `page`.
signal settings_requested(page: String)
## The open station's console session changed status (`starting`, `idle`,
## `working`, `waiting` or `ended`), as the Chat app last saw it: the
## monitor's activity pulse follows it.
signal chat_status_changed(status: String)

## How long B must be held to leave, in seconds.
const LEAVE_HOLD_S := 0.5
## How far in from the window's edges the bezel sits, in pixels, so the
## world shows round it.
const BEZEL_INSET := 12.0
## While an app is open: the height of the bezel's, the dock's and the app
## bar's buttons, and how much smaller their words are than the skin's.
const COMPACT_HEIGHT := 32.0
const COMPACT_TEXT_STEP := 6

## The dock, left to right: each app, the station capability it needs
## ("" for none: Work is Superpipeline's), whether it takes typing, and
## what the dock says when the station lacks that capability.
const APPS := [
	{"id": "terminal", "name": "Terminal", "capability": "terminal", "typing": true,
		"missing": "This station offers no terminal"},
	{"id": "chat", "name": "Chat", "capability": "acp", "typing": true,
		"missing": "This station's agent offers no chat (acp)"},
	{"id": "files", "name": "Files", "capability": "fs.read", "typing": false,
		"missing": "This station does not share its files (fs.read)"},
	{"id": "logs", "name": "Logs", "capability": "logs", "typing": false,
		"missing": "This station does not share its logs"},
	{"id": "health", "name": "Health", "capability": "health", "typing": false,
		"missing": "This station does not report its health"},
	{"id": "changes", "name": "Changes", "capability": "changeset", "typing": false,
		"missing": "This station does not track its changes (changeset)"},
	{"id": "work", "name": "Work", "capability": "", "typing": false, "missing": ""},
]
const APP_IDS := ["terminal", "chat", "files", "logs", "health", "changes", "work"]

const SAMPLE_NAME := "Sample station"
const NO_ACCESS := "You don't have access to this station"
const OFFLINE := "Station offline"
const NO_STATIONS := "There are no stations to open yet"
const SIGNED_OUT := "Your AgentPod sign-in has ended"
const SIGN_IN_AGAIN := "Sign in again"
const RETRY := "Retry"
const CONNECT := "Connect your AgentPod"
const OPEN_CONSOLE := "Open in the AgentPod console"
const OPEN_SUPERPIPELINE := "Open in Superpipeline"
const DISCONNECT := "Disconnect"
const OPEN_CONSOLE_HINT := "Open the AgentPod console"
const LIVE_OFF_NOTE := "Live mode connects this computer to your own AgentPod, and it is off. Turn it on in Settings, under Station computer."
const DESKTOP_ONLY_NOTE := "Sign-in needs the desktop app for now."
const NOT_CONFIGURED := "Set its address in Settings, under Station computer."
const TYPING_NEEDS_KEYBOARD := "Typing needs a keyboard"
## The settings page the station's settings are on.
const SETTINGS_PAGE := "Station computer"
const STATUS_WORDS := {"running": "Running", "stopped": "Stopped", "error": "Error", "unknown": "Unknown"}

## The desk: {target, kind, binding}, where `binding` is {} for a hot desk
## or {source: "agentpod", ref: <station ID>} for a station's own.
var desk := {}
var source: StationSource
## Watch mode: looking over a shoulder, with input off.
var watch := false
## The player's settings, for live mode and the configured addresses.
var settings: Settings
## Which device the player last used, for the controller's keyboard note.
var glyphs: InputGlyphs
## Where the Work app keeps which agent works at each station (see
## StationLinks); a test run keeps its own.
var links_path := StationLinks.PATH

## Seams for what differs by device, which tests set: the platform
## ("desktop", "web" or "mobile"), whether the screen is a touch screen,
## how a URL opens in the system browser, and how the system keyboard is
## brought up.
var platform := current_platform()
var touch := DisplayServer.is_touchscreen_available()
var open_url := func(url: String) -> void: SystemBrowser.open(url)
var show_keyboard := func() -> void: DisplayServer.virtual_keyboard_show("")

## What the screen shows: "loading", "chooser", "message", "desktop" or
## "app".
var state := ""
## The open station, a `FleetAgent`; {} before one opens.
var station := {}
## The open app, or null on the desktop.
var app: StationApp
## The bezel's shape as last skinned, for tests.
var bezel_shape := ""
## The open station's console session status, as the Chat app last saw it,
## or "" before it has been seen; see `chat_status_changed`.
var chat_status := ""

var scrim: ColorRect
var bezel: PanelContainer
var badge: Label
var watching_label: Label
var station_label: Label
var stand_up_button: Button
var screen_panel: PanelContainer
var loading_label: Label
var chooser: VBoxContainer
var chooser_list: VBoxContainer
var message: VBoxContainer
var message_label: Label
var message_button: Button
var desktop: VBoxContainer
var desk_name: Label
var desk_purpose: Label
var desk_node: Label
var status_chip: Label
var clock: Label
var app_window: VBoxContainer
var app_title: Label
## While an app is open, the desktop's details in one line over it: the
## station, its status and the time.
var app_header: Label
var typing_note: Label
var desktop_button: Button
var app_host: VBoxContainer
var dock: HFlowContainer
## The focused dock app's reason for being greyed out, if it is.
var dock_hint: Label
var notice: Label
var connect_button: Button
var console_button: Button
var disconnect_button: Button
## Offered with a note about a device not revoked: the console is where
## the player can revoke it.
var console_hint_button: Button
var superpipeline_button: Button
var footer: HBoxContainer

## The stations the last list gave, in order.
var _stations: Array = []
## The station list asked for and not yet answered, else 0.
var _list_call := 0
## Whether B is down, and for how long, for the half-second hold.
var _b_down := false
var _b_held := 0.0
## Set once the screen has begun leaving, so it leaves once.
var _leaving := false
## The message button's action: "sign_in" or "retry".
var _message_action := ""


## "desktop", "web" or "mobile", from the build's features.
static func current_platform() -> String:
	if OS.has_feature("web"):
		return "web"
	if OS.has_feature("mobile"):
		return "mobile"
	return "desktop"


## Whether "Look at screen" may open at `desk_` from `source_`: with the
## sample, where an agent sits (`agent_sits`); live, at a desk bound to a
## station the source may see (see StationSource.may_see; the computer
## then checks it against the stations it lists).
static func may_watch(desk_: Dictionary, source_: StationSource, agent_sits: bool) -> bool:
	if not source_.LIVE:
		return agent_sits
	var ref := _ref_of(desk_)
	return ref != "" and source_.may_see(ref)


## A station's name as the computer shows it: Sample station's own, or the
## station's display name from its row.
static func station_title(row: Dictionary, live: bool) -> String:
	if not live:
		return SAMPLE_NAME
	var name_ = row.get("agentName")
	return str(name_) if name_ != null and str(name_) != "" else str(row.get("stationId", ""))


## What the station is for, as far as its row says: its agent (where the
## title does not already name it), its harness and its workspace.
static func station_purpose(row: Dictionary, live: bool) -> String:
	var parts := []
	var agent := str(row.get("agentName", "")) if row.get("agentName") != null else ""
	if agent != "" and agent != station_title(row, live):
		parts.append(agent)
	if str(row.get("harness", "")) != "":
		parts.append("%s harness" % row["harness"])
	if row.get("workspacePath") != null and str(row["workspacePath"]) != "":
		parts.append(str(row["workspacePath"]))
	return " · ".join(parts)


## The station's status chip: "Offline" when its node is, else its status.
static func status_word(row: Dictionary) -> String:
	if str(row.get("nodeStatus", "online")) == "offline":
		return "Offline"
	return STATUS_WORDS.get(str(row.get("status", "unknown")), "Unknown")


## The station a desk is bound to, or "" for a hot desk.
static func _ref_of(desk_: Dictionary) -> String:
	var binding = desk_.get("binding")
	if binding is Dictionary and str(binding.get("source", "")) == "agentpod":
		return str(binding.get("ref", ""))
	return ""


## The app `id` opens, as its own class; an unknown one is a placeholder
## that names itself.
static func make_app(id: String) -> StationApp:
	var spec := _app_spec(id)
	var made: StationApp
	match id:
		"terminal":
			made = TerminalApp.new()
		"chat":
			made = ChatApp.new()
		"work":
			made = WorkApp.new()
		"files":
			made = FilesApp.new()
		"logs":
			made = LogsApp.new()
		"health":
			made = HealthApp.new()
		"changes":
			made = ChangesApp.new()
		_:
			made = StationApp.new()
	made.name = str(spec["name"])
	made.app_name = str(spec["name"])
	made.takes_typing = bool(spec["typing"])
	return made


static func _app_spec(id: String) -> Dictionary:
	for spec in APPS:
		if spec["id"] == id:
			return spec
	return {}


## Opens the computer at `desk_` onto `source_`, watching when `watch_`.
## Call after pushing. Called again with another source (signing in, or
## disconnecting), it starts over on that one.
func open(desk_: Dictionary, source_: StationSource, watch_ := false) -> void:
	if source != null and source != source_ and source.result.is_connected(_on_result):
		source.result.disconnect(_on_result)
	desk = desk_
	source = source_
	watch = watch_
	if stand_up_button != null:
		_start()


# ---- Building ----

func build() -> void:
	scrim = ColorRect.new()
	scrim.name = "Scrim"
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	bezel = PanelContainer.new()
	bezel.name = "Bezel"
	bezel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bezel.offset_left = BEZEL_INSET
	bezel.offset_top = BEZEL_INSET
	bezel.offset_right = -BEZEL_INSET
	bezel.offset_bottom = -BEZEL_INSET
	add_child(bezel)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 10)
	bezel.add_child(frame)
	frame.add_child(_build_top_edge())
	screen_panel = PanelContainer.new()
	screen_panel.name = "Screen"
	screen_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(screen_panel)
	var inside := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inside.add_theme_constant_override("margin_" + side, 16)
	screen_panel.add_child(inside)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	inside.add_child(body)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(content)
	loading_label = _label("Loading", "Starting…")
	content.add_child(loading_label)
	content.add_child(_build_chooser())
	content.add_child(_build_message())
	content.add_child(_build_desktop())
	content.add_child(_build_app_window())
	body.add_child(_build_dock())
	body.add_child(_build_footer())
	if source != null:
		_start()


## The bezel's top edge: the badge, "Watching", the station's name and
## Stand up.
func _build_top_edge() -> HBoxContainer:
	var top := HBoxContainer.new()
	top.name = "TopEdge"
	top.add_theme_constant_override("separation", 12)
	badge = _label("Badge", "Sample")
	top.add_child(badge)
	watching_label = _label("Watching", "Watching")
	watching_label.visible = false
	top.add_child(watching_label)
	station_label = _label("StationName", "")
	station_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	station_label.clip_text = true
	top.add_child(station_label)
	stand_up_button = _button("StandUp", "Stand up", leave)
	top.add_child(stand_up_button)
	return top


func _build_chooser() -> VBoxContainer:
	chooser = VBoxContainer.new()
	chooser.name = "Chooser"
	chooser.add_theme_constant_override("separation", 12)
	chooser.add_child(_label("Heading", "Choose a station"))
	chooser_list = VBoxContainer.new()
	chooser_list.name = "Stations"
	chooser_list.add_theme_constant_override("separation", 8)
	chooser.add_child(chooser_list)
	return chooser


func _build_message() -> VBoxContainer:
	message = VBoxContainer.new()
	message.name = "Message"
	message.add_theme_constant_override("separation", 12)
	message_label = _label("Text", "")
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_child(message_label)
	message_button = _button("Action", RETRY, _on_message_button)
	message_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	message.add_child(message_button)
	return message


func _build_desktop() -> VBoxContainer:
	desktop = VBoxContainer.new()
	desktop.name = "Desktop"
	desktop.add_theme_constant_override("separation", 8)
	desk_name = _label("Name", "")
	desktop.add_child(desk_name)
	desk_purpose = _label("Purpose", "")
	desk_purpose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desktop.add_child(desk_purpose)
	desk_node = _label("Node", "")
	desktop.add_child(desk_node)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 16)
	status_chip = _label("Status", "")
	chips.add_child(status_chip)
	clock = _label("Clock", _clock_text())
	chips.add_child(clock)
	desktop.add_child(chips)
	return desktop


## An open app's window: its name, the keyboard note, the way back to the
## desktop, and the app.
func _build_app_window() -> VBoxContainer:
	app_window = VBoxContainer.new()
	app_window.name = "AppWindow"
	app_window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app_window.add_theme_constant_override("separation", 8)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	app_title = _label("Title", "")
	app_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(app_title)
	app_header = _label("Header", "")
	bar.add_child(app_header)
	typing_note = _label("TypingNote", TYPING_NEEDS_KEYBOARD)
	typing_note.visible = false
	bar.add_child(typing_note)
	desktop_button = _button("Desktop", "Desktop", show_desktop)
	bar.add_child(desktop_button)
	app_window.add_child(bar)
	app_host = VBoxContainer.new()
	app_host.name = "App"
	app_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app_window.add_child(app_host)
	return app_window


## The dock: one button per app, and under it why the focused one is
## greyed out. A flow, so a narrow window wraps it.
func _build_dock() -> VBoxContainer:
	var holder := VBoxContainer.new()
	holder.name = "DockArea"
	holder.add_theme_constant_override("separation", 4)
	dock = HFlowContainer.new()
	dock.name = "Dock"
	dock.add_theme_constant_override("h_separation", 8)
	dock.add_theme_constant_override("v_separation", 8)
	for spec in APPS:
		var id := str(spec["id"])
		var b := _button(str(spec["name"]), str(spec["name"]), open_app.bind(id))
		b.set_meta("app_id", id)
		dock.add_child(b)
	# Left and right walk the dock, round from either end, however the
	# flow has wrapped it.
	var items := dock.get_children()
	for i in items.size():
		var b: Button = items[i]
		b.focus_neighbor_left = b.get_path_to(items[i - 1])
		b.focus_neighbor_right = b.get_path_to(items[(i + 1) % items.size()])
	holder.add_child(dock)
	dock_hint = _label("DockHint", "")
	holder.add_child(dock_hint)
	return holder


## The footer: a notice, and "Connect your AgentPod" (the sample) or the
## products' own apps (live).
func _build_footer() -> HBoxContainer:
	footer = HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 12)
	notice = _label("Notice", "")
	notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(notice)
	connect_button = _button("Connect", CONNECT, _on_connect)
	footer.add_child(connect_button)
	console_button = _button("Console", OPEN_CONSOLE, _open_console)
	footer.add_child(console_button)
	superpipeline_button = _button("Superpipeline", OPEN_SUPERPIPELINE, _open_superpipeline)
	footer.add_child(superpipeline_button)
	disconnect_button = _button("Disconnect", DISCONNECT, disconnect_requested.emit)
	footer.add_child(disconnect_button)
	console_hint_button = _button("ConsoleHint", OPEN_CONSOLE_HINT, _open_console_home)
	console_hint_button.visible = false
	footer.add_child(console_hint_button)
	return footer


func _label(node_name: String, text: String) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	return l


## A button every device can reach: the d-pad and Tab as well as the
## pointer.
func _button(node_name: String, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(action)
	return b


# ---- Opening a station ----

## Asks the source for the stations, to choose from or to find the desk's.
func _start() -> void:
	_leaving = false
	_close_app()
	if not source.result.is_connected(_on_result):
		source.result.connect(_on_result)
	station = {}
	_refresh_bezel()
	_refresh_footer()
	_show_view("loading")
	_list_call = source.list_stations()


func _on_result(call_id: int, ok: bool, body: Variant, _status: int) -> void:
	if call_id != _list_call:
		return
	_list_call = 0
	if not ok:
		_show_error(body if body is Dictionary else {})
		return
	_stations = body.get("agents", []) if body is Dictionary else []
	var ref := _ref_of(desk)
	if not source.LIVE and (ref != "" or watch):
		# With the sample, every desk opens Sample station.
		if _stations.is_empty():
			_show_message(NO_STATIONS, "retry")
		else:
			open_station(_stations[0])
	elif ref != "":
		for row in _stations:
			if str(row.get("stationId", "")) == ref:
				open_station(row)
				return
		_show_message(NO_ACCESS, "")
	elif watch:
		# Live watch mode needs a bound desk; a hot desk has no station.
		_show_message(NO_ACCESS, "")
	else:
		_show_chooser()


## A failure as the player reads it: signed out, no access, offline, or
## the error's one line; never a response body.
func _show_error(error: Dictionary) -> void:
	match str(error.get("kind", "failed")):
		"signed_out":
			_show_message(SIGNED_OUT, "sign_in")
		"no_access":
			_show_message(NO_ACCESS, "")
		"offline":
			_show_message(OFFLINE, "retry")
		_:
			_show_message(str(error.get("message", "Something went wrong")), "retry")


func _show_message(text: String, action: String) -> void:
	message_label.text = text
	_message_action = action
	message_button.visible = action != ""
	message_button.text = SIGN_IN_AGAIN if action == "sign_in" else RETRY
	_show_view("message")
	if message_button.visible:
		message_button.grab_focus()
	else:
		stand_up_button.grab_focus()


func _on_message_button() -> void:
	if _message_action == "sign_in":
		sign_in_requested.emit()
	elif _message_action == "retry" and source != null:
		_start()


func _show_chooser() -> void:
	for child in chooser_list.get_children():
		child.free()
	if _stations.is_empty():
		_show_message(NO_STATIONS, "retry")
		return
	for i in _stations.size():
		chooser_list.add_child(_button("Station%d" % i, station_title(_stations[i], source.LIVE), choose.bind(i)))
	_show_view("chooser")
	restyle_buttons(chooser_list)
	chooser_button(0).grab_focus()


## What the message says ("You don't have access to this station", say).
func message_text() -> String:
	return message_label.text


## The chooser's station names, top to bottom.
func chooser_names() -> Array:
	return chooser_list.get_children().map(func(b): return b.text)


func chooser_button(index: int) -> Button:
	return chooser_list.get_child(index) as Button


## Opens the chooser's station `index`.
func choose(index: int) -> void:
	if state == "chooser" and index >= 0 and index < _stations.size():
		open_station(_stations[index])


## Opens `row`'s desktop.
func open_station(row: Dictionary) -> void:
	if str(row.get("stationId", "")) != str(station.get("stationId", "")):
		# Another station's session: unknown until its chat says.
		_on_chat_status("")
	station = row
	var live := source.LIVE
	desk_name.text = station_title(row, live)
	desk_purpose.text = station_purpose(row, live)
	desk_node.text = "Node: %s (%s)" % [str(row.get("nodeName", "")), str(row.get("nodeStatus", "unknown"))]
	status_chip.text = status_word(row)
	_refresh_dock()
	_refresh_bezel()
	_refresh_footer()
	show_desktop()


# ---- The desktop, the dock and the apps ----

## Back to the desktop, closing the open app.
func show_desktop() -> void:
	if station.is_empty():
		return
	_close_app()
	_show_view("desktop")
	for b in dock.get_children():
		if not b.disabled:
			b.grab_focus()
			break


## Greys out each app whose station capability is missing, with why.
func _refresh_dock() -> void:
	var capabilities: Array = station.get("capabilities", [])
	for spec in APPS:
		var b := dock_button(str(spec["id"]))
		var missing: bool = spec["capability"] != "" and not capabilities.has(spec["capability"])
		b.disabled = missing
		b.tooltip_text = str(spec["missing"]) if missing else ""
		b.set_meta("reason", b.tooltip_text)


func dock_button(id: String) -> Button:
	for b in dock.get_children():
		if b.get_meta("app_id", "") == id:
			return b
	return null


## Why app `id` is greyed out, or "" when it is not.
func dock_reason(id: String) -> String:
	return str(dock_button(id).get_meta("reason", ""))


## The dock's app names, left to right.
func dock_names() -> Array:
	return dock.get_children().map(func(b): return b.text)


## Opens app `id` in the window, when the station has what it needs.
func open_app(id: String) -> void:
	var b := dock_button(id)
	if b == null or b.disabled or not state in ["desktop", "app"]:
		return
	_close_app()
	app = make_app(id)
	app.ui = ui
	app.settings = settings
	app.sign_in_requested.connect(sign_in_requested.emit)
	if app is ChatApp:
		app.status_changed.connect(_on_chat_status)
	elif app is WorkApp:
		app.links_path = links_path
	app.setup(source, station, watch)
	app_host.add_child(app)
	app.restyle()
	app_title.text = app.app_name
	_fill_app_header()
	_show_view("app")
	_refresh_typing_note()
	if app.typing_target != null and app.typing_target.focus_mode != Control.FOCUS_NONE:
		app.typing_target.grab_focus()
	else:
		b.grab_focus()


func _on_chat_status(status: String) -> void:
	if status == chat_status:
		return
	chat_status = status
	chat_status_changed.emit(status)


func _close_app() -> void:
	if app == null:
		return
	app.closing()
	app_host.remove_child(app)
	app.queue_free()
	app = null
	typing_note.visible = false


func _show_view(view: String) -> void:
	state = view
	loading_label.visible = view == "loading"
	chooser.visible = view == "chooser"
	message.visible = view == "message"
	desktop.visible = view == "desktop"
	app_window.visible = view == "app"
	dock.get_parent().visible = view in ["desktop", "app"]
	_apply_compact()


# ---- The bezel and the footer ----

func _refresh_bezel() -> void:
	badge.text = source.label() if source != null else "Sample"
	watching_label.visible = watch
	station_label.text = station_title(station, source.LIVE) if not station.is_empty() else "Station computer"
	stand_up_button.text = "Stop watching" if watch else "Stand up"


## The sample always offers "Connect your AgentPod"; live, the footer opens
## the station in the AgentPod console and Superpipeline instead, and
## offers "Disconnect".
func _refresh_footer() -> void:
	var live := source != null and source.LIVE
	connect_button.visible = not live
	console_button.visible = live and not station.is_empty()
	superpipeline_button.visible = live and not station.is_empty()
	disconnect_button.visible = live and not watch
	console_button.disabled = _setting("console_url") == ""
	superpipeline_button.disabled = _setting("superpipeline_url") == ""
	console_button.tooltip_text = NOT_CONFIGURED if console_button.disabled else ""
	superpipeline_button.tooltip_text = NOT_CONFIGURED if superpipeline_button.disabled else ""


func _setting(key: String) -> Variant:
	if settings == null:
		return Settings.DEFAULTS["station"][key]
	return settings.get_value("station", key)


## "Connect your AgentPod": on a desktop build with live mode on, signing
## in starts; with it off, the notice says what live mode is and Settings
## opens at its page; on the web and phones, sign-in waits for a desktop.
func _on_connect() -> void:
	if platform != "desktop":
		notice.text = DESKTOP_ONLY_NOTE
		return
	if bool(_setting("live")):
		notice.text = ""
		sign_in_requested.emit()
		return
	notice.text = LIVE_OFF_NOTE
	settings_requested.emit(SETTINGS_PAGE)


## Shows the sign-in's news in the footer's notice: signing in, a
## Disconnect under way, "Revoked.", or a device not revoked, with the
## console offered where the player can revoke it (`console_hint`).
func show_station_note(message: String, console_hint := false) -> void:
	notice.text = message
	console_hint_button.visible = console_hint
	console_hint_button.disabled = _setting("console_url") == ""
	console_hint_button.tooltip_text = NOT_CONFIGURED if console_hint_button.disabled else ""


func _open_console_home() -> void:
	var base := str(_setting("console_url")).rstrip("/")
	if base != "":
		open_url.call(base)


func _open_console() -> void:
	var base := str(_setting("console_url")).rstrip("/")
	if base == "" or station.is_empty():
		return
	open_url.call("%s/nodes/%s/stations/%s" % [base, str(station.get("nodeId", "")).uri_encode(),
		str(station.get("stationId", "")).uri_encode()])


func _open_superpipeline() -> void:
	var url := str(_setting("superpipeline_url"))
	if url != "":
		open_url.call(url)


# ---- Focus, typing and leaving ----

## Whether the player's input reaches the station: off in watch mode.
func input_enabled() -> bool:
	return not watch


## Whether the player has only a controller on a desktop, where typing
## into the terminal or chat needs a keyboard.
func typing_needs_keyboard() -> bool:
	return platform == "desktop" and not touch and glyphs != null and glyphs.device == "pad"


func _refresh_typing_note() -> void:
	typing_note.visible = app != null and app.takes_typing and not watch and typing_needs_keyboard()


## Leaves: says so, once, and takes the screen off the stack.
func leave() -> void:
	if _leaving:
		return
	_leaving = true
	_b_down = false
	left.emit()
	if stack != null and stack.screens.has(self):
		# The screens the computer opened over itself go with it.
		while stack.top() != self:
			stack.remove(stack.top())
		stack.remove(self)


## The computer decides leaving itself (see _input): what reaches the
## stack's Back here is Start, or an Esc a typing field let pass, and
## neither leaves.
func on_back() -> bool:
	return true


## F10, B and Esc are read before any control sees them, so the rules
## hold wherever the focus is: F10 leaves; B held LEAVE_HOLD_S leaves, and
## a shorter press goes back to the desktop; Esc leaves unless a typing
## field has the focus, which then gets it.
##
## F10 and the B hold work even while a screen the computer opened
## (Settings, from "Connect your AgentPod") covers it, and leaving takes
## that screen too: with the router off, only the computer opens screens
## over itself. Covered, B is watched but left to that screen, where a
## press is its Back; Esc is always the top screen's.
func _input(event: InputEvent) -> void:
	if stack == null or not stack.screens.has(self) or _leaving:
		return
	var covered := stack.top() != self
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B:
		if event.pressed and not _b_down:
			_b_down = true
			_b_held = 0.0
		elif not event.pressed and _b_down:
			_b_down = false
			if _b_held < LEAVE_HOLD_S and app != null and not covered:
				show_desktop()
		if not covered:
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if code == KEY_F10:
		get_viewport().set_input_as_handled()
		leave()
	elif code == KEY_ESCAPE and not covered and not StationApp.is_typing_target(get_viewport().gui_get_focus_owner()):
		get_viewport().set_input_as_handled()
		leave()


func _process(delta: float) -> void:
	if _b_down and not _leaving:
		_b_held += delta
		if _b_held >= LEAVE_HOLD_S:
			leave()
	if clock != null and (desktop.visible or app_window.visible):
		var now := _clock_text()
		if clock.text != now:
			clock.text = now
			_fill_app_header()


static func _clock_text() -> String:
	return Time.get_time_string_from_system().substr(0, 5)


## Computer mode for the router while the screen is in the tree, and the
## focus and device watched for the keyboard.
func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		if stack != null and stack.router != null:
			stack.router.computer_focus = true
		if stack != null and not stack.changed.is_connected(_on_stack_changed):
			stack.changed.connect(_on_stack_changed)
		var viewport := get_viewport()
		if not viewport.gui_focus_changed.is_connected(_on_focus_moved):
			viewport.gui_focus_changed.connect(_on_focus_moved)
		if glyphs != null and not glyphs.device_changed.is_connected(_on_device_changed):
			glyphs.device_changed.connect(_on_device_changed)
	elif what == NOTIFICATION_EXIT_TREE:
		if stack != null and stack.router != null:
			stack.router.computer_focus = false
		if stack != null and stack.changed.is_connected(_on_stack_changed):
			stack.changed.disconnect(_on_stack_changed)
		var viewport := get_viewport()
		if viewport != null and viewport.gui_focus_changed.is_connected(_on_focus_moved):
			viewport.gui_focus_changed.disconnect(_on_focus_moved)
		if glyphs != null and glyphs.device_changed.is_connected(_on_device_changed):
			glyphs.device_changed.disconnect(_on_device_changed)
		if source != null and source.result.is_connected(_on_result):
			source.result.disconnect(_on_result)
		if app != null:
			app.closing()


## Covered, a B hold begun on the computer stops counting (its release may
## never reach it); uncovered again, the footer takes whatever the screen
## over it changed, such as the addresses set in Settings.
func _on_stack_changed(top: Screen) -> void:
	if top != self:
		_b_down = false
		_b_held = 0.0
	elif _built:
		_refresh_footer()


## On a touch screen, a typing field brings up the system keyboard; on the
## dock, the focused app's reason for being greyed out shows under it.
func _on_focus_moved(control: Control) -> void:
	if control == null or not is_ancestor_of(control):
		return
	if touch and not watch and StationApp.is_typing_target(control):
		show_keyboard.call()
	if control.has_meta("app_id"):
		dock_hint.text = str(control.get_meta("reason", ""))


func _on_device_changed(_device: String) -> void:
	_refresh_typing_note()


# ---- The skin ----

## The bezel, from the style's `ui.bezel`: a frame in its colour, corner
## radius and margin, drawn as its `shape` says (its `edge`, where it has
## one, the colour of its border):
## - `crt`, a deep darker lip and a shadow, as a tube's plastic case;
## - `glass`, see-through with a bright edge;
## - `wood`, a broad frame of darker grain;
## - `chunky`, a thick square frame with a hard blocky shadow;
## - `inked`, a dark ink line round a light frame;
## - `flat` and `plain` (or a shape a style names for itself), the colour
##   alone, clean.
static func bezel_box(spec: Dictionary) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var colour := Color(str(spec.get("colour", UiTheme.DEFAULT["bezel"]["colour"])))
	var edge = spec.get("edge")
	box.bg_color = colour
	box.set_corner_radius_all(int(spec.get("radius", 0)))
	box.set_content_margin_all(float(spec.get("margin", 0)))
	match str(spec.get("shape", "plain")):
		"crt":
			box.set_border_width_all(6)
			box.border_color = Color(str(edge)) if edge != null else colour.darkened(0.35)
			box.shadow_size = 12
			box.shadow_color = Color(0, 0, 0, 0.45)
		"glass":
			box.bg_color = Color(colour, colour.a * 0.6)
			box.set_border_width_all(2)
			box.border_color = Color(str(edge)) if edge != null else colour.lightened(0.45)
		"wood":
			box.set_border_width_all(8)
			box.border_color = Color(str(edge)) if edge != null else colour.darkened(0.3)
			box.shadow_size = 6
			box.shadow_color = Color(0, 0, 0, 0.3)
		"chunky":
			box.set_border_width_all(10)
			box.set_corner_radius_all(0)
			box.border_color = Color(str(edge)) if edge != null else colour.darkened(0.35)
			# A hard shadow a block down and across, not a soft one.
			box.shadow_size = 1
			box.shadow_offset = Vector2(8, 8)
			box.shadow_color = Color(0, 0, 0, 0.35)
		"inked":
			box.set_border_width_all(4)
			box.border_color = Color(str(edge)) if edge != null else Color("#1E2A44")
	return box


func restyle() -> void:
	scrim.color = ui.colour("scrim")
	var spec := ui.bezel()
	bezel_shape = str(spec.get("shape", "plain"))
	bezel.add_theme_stylebox_override("panel", bezel_box(spec))
	var text_size := int(ui.spec.get("text_size", 20))
	# The bezel's words sit on its frame, not on the panel: light on a dark
	# frame, dark on a light one, whatever colour the style gives it.
	var on_frame := Color.WHITE if Color(str(spec.get("colour", "#000000"))).get_luminance() < 0.5 else Color("#1F2433")
	for l in [badge, watching_label, station_label]:
		l.add_theme_color_override("font_color", on_frame)
	_heading(desk_name, text_size + 8)
	for l in [desk_purpose, desk_node, clock, dock_hint, notice, typing_note, loading_label]:
		l.add_theme_color_override("font_color", ui.colour("ink_muted"))
	status_chip.add_theme_color_override("font_color", ui.colour("accent"))
	app_header.add_theme_color_override("font_color", ui.colour("ink_muted"))
	restyle_buttons(self)
	_apply_compact()
	if app != null:
		app.ui = ui
		app.restyle()


## While an app is open it takes the bezel, so the terminal's 80 x 24 reads
## at 1280 x 720: the desktop gives way to one line of its details over the
## app, the dock and the bezel's edge turn slim, and the desktop's footer
## steps aside. Back on the desktop, everything is full size again.
func _apply_compact() -> void:
	if ui == null or dock == null:
		return
	var compact := state == "app"
	var text_size := int(ui.spec.get("text_size", 20))
	var height := COMPACT_HEIGHT if compact else float(ui.spec.get("button", {}).get("height", 48))
	for b in dock.get_children() + [stand_up_button, desktop_button]:
		b.custom_minimum_size.y = height
		if compact:
			b.add_theme_font_size_override("font_size", ui.font_size(text_size - COMPACT_TEXT_STEP))
		else:
			b.remove_theme_font_size_override("font_size")
	for l in [badge, watching_label, station_label]:
		_heading(l, text_size - COMPACT_TEXT_STEP if compact else text_size)
	for l in [app_title, app_header, typing_note]:
		l.add_theme_font_size_override("font_size", ui.font_size(text_size - COMPACT_TEXT_STEP))
	dock_hint.visible = not compact or dock_hint.text != ""
	footer.visible = not compact


## `label` in the display face at `size`, or the body face where a pixel
## face would be too small (UiTheme.heading_font).
func _heading(label: Label, size: int) -> void:
	label.add_theme_font_override("font", ui.heading_font(size))
	label.add_theme_font_size_override("font_size", ui.heading_size(size))


func _fill_app_header() -> void:
	if app_header != null and not station.is_empty():
		app_header.text = "%s · %s · %s" % [desk_name.text, status_chip.text, clock.text]


## Every button under `node` at the skin's button height.
func restyle_buttons(node: Node) -> void:
	if ui == null:
		return
	var height := float(ui.spec.get("button", {}).get("height", 48))
	for b in node.find_children("*", "Button", true, false):
		b.custom_minimum_size.y = height
