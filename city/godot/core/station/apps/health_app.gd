## The Health app: whether the station's agent is running, its cpu, memory,
## disk and uptime, and whether its node is online (the console's health
## tab), read every 5 s while the app shows.
##
## Start, Stop and Restart each ask first, naming the station; live, each
## also says that it is real. After a refusal that asking again cannot
## mend (signed out, no access), it stops reading. The answer is the health after
## the action, which shows at once. Watching offers none of them.
class_name HealthApp
extends StationApp

## How often the reading refreshes while the app shows, in seconds.
const REFRESH_SECONDS := 5.0
## Each reading's key and its name, top to bottom.
const FIELDS := [
	["status", "Agent"], ["cpu", "CPU"], ["memory", "Memory"], ["disk", "Disk"], ["uptime", "Uptime"],
	["node", "Node"],
]
const NONE := "—"
## The failure line's keys for the reading and the lifecycle actions.
const READING := "reading"
const LIFECYCLE := "lifecycle"
## From this width, in pixels, the readings go two a row.
const WIDE := 1000.0
const NO_LIFECYCLE := "This station does not let its agent be started or stopped (lifecycle)"
const VERBS := {"start": "Start", "stop": "Stop", "restart": "Restart"}
## What live Stop and Restart add to their question.
const REAL := {
	"start": "This is real: the agent on it starts.",
	"stop": "This is real: the agent on it stops.",
	"restart": "This is real: the agent on it restarts.",
}

## The last reading, a `StationHealth`.
var health := {}
## Whether it reads every REFRESH_SECONDS: off after a refusal that asking
## again cannot mend, on again after any reading that works.
var polling := true
var start_button: Button
var stop_button: Button
var restart_button: Button
## The station's note, when its reading carries one.
var note_label: Label

## Each reading's value label, by key.
var _values := {}
var _names: Array[Label] = []
## Seconds since the last refresh.
var _since := 0.0
## The reading asked for and not yet answered, else 0.
var _health_call := 0
## The action asked for and not yet answered, else "".
var _acting := ""


func build() -> void:
	var readings := GridContainer.new()
	readings.name = "Readings"
	readings.columns = 2
	readings.add_theme_constant_override("h_separation", 24)
	readings.add_theme_constant_override("v_separation", 8)
	for field in FIELDS:
		var name_label := Label.new()
		name_label.text = field[1]
		readings.add_child(name_label)
		_names.append(name_label)
		var value_label := Label.new()
		value_label.name = str(field[0]).capitalize()
		value_label.text = NONE
		readings.add_child(value_label)
		_values[field[0]] = value_label
	add_child(readings)
	# Two readings a row where the app is wide, so it stays short enough for
	# a short window; one a row where it is narrow.
	resized.connect(func() -> void: readings.columns = 4 if size.x >= WIDE else 2)
	note_label = Label.new()
	note_label.name = "Note"
	note_label.visible = false
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note_label)
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 12)
	start_button = make_button("Start", VERBS["start"], ask.bind("start"))
	stop_button = make_button("Stop", VERBS["stop"], ask.bind("stop"))
	restart_button = make_button("Restart", VERBS["restart"], ask.bind("restart"))
	for b in [start_button, stop_button, restart_button]:
		actions.add_child(b)
	actions.visible = not read_only
	add_child(actions)
	source.stations.connect(_on_stations)
	_show_node(station)
	# Until the first reading, the station's row says whether it runs.
	health = {"running": str(station.get("status", "")) == "running"}
	_refresh_buttons()
	refresh()


func restyle() -> void:
	super()
	if ui == null:
		return
	for l in _names:
		l.add_theme_font_override("font", ui.body_font)
		l.add_theme_font_size_override("font_size", ui.font_size(text_size()))
		l.add_theme_color_override("font_color", ui.colour("ink_muted"))
	for key in _values:
		var l: Label = _values[key]
		l.add_theme_font_override("font", ui.heading_font(text_size()))
		l.add_theme_font_size_override("font_size", ui.heading_size(text_size()))
		l.add_theme_color_override("font_color", ui.colour("ink"))
	note_label.add_theme_font_override("font", ui.body_font)
	note_label.add_theme_font_size_override("font_size", ui.font_size(text_size()))
	note_label.add_theme_color_override("font_color", ui.colour("ink"))


func closing() -> void:
	if source != null and source.stations.is_connected(_on_stations):
		source.stations.disconnect(_on_stations)
	super()


## What reading `key` shows ("status", "cpu", "memory", "disk", "uptime"
## or "node").
func value(key: String) -> String:
	return _values[key].text


# ---- Reading ----

## Asks for a reading, unless one is already on its way.
func refresh() -> void:
	if _health_call != 0:
		return
	_since = 0.0
	_health_call = source.health(station_id())
	request(_health_call, _on_health)


func _on_health(ok: bool, body: Variant, _status: int) -> void:
	_health_call = 0
	if not ok:
		show_error(body if body is Dictionary else {}, refresh, READING)
		# Signed out or refused, asking every 5 s only asks to be refused.
		if str(body.get("kind", "") if body is Dictionary else "") in ["signed_out", "no_access"]:
			polling = false
		return
	polling = true
	clear_error(READING)
	show_health(body)


## Every REFRESH_SECONDS while the app shows, until it closes or a refusal
## stops it.
func _process(delta: float) -> void:
	super(delta)
	if closed or not polling or not is_visible_in_tree():
		return
	_since += delta
	if _since >= REFRESH_SECONDS:
		_since = 0.0
		refresh()


## Shows reading `reading`, a `StationHealth`.
func show_health(reading: Variant) -> void:
	if not reading is Dictionary:
		return
	health = reading
	value_label("status").text = "Running" if health.get("running", false) else "Stopped"
	var cpu = health.get("cpuPct")
	value_label("cpu").text = NONE if cpu == null else "%.1f%%" % float(cpu)
	value_label("memory").text = _size_or_none(health.get("memBytes"))
	value_label("disk").text = _size_or_none(health.get("diskBytes"))
	value_label("uptime").text = format_uptime(health.get("uptimeSec"))
	var note = health.get("note")
	note_label.visible = note != null and str(note) != ""
	note_label.text = str(note) if note_label.visible else ""
	_refresh_buttons()


func value_label(key: String) -> Label:
	return _values[key]


static func _size_or_none(size_bytes: Variant) -> String:
	return NONE if size_bytes == null else format_bytes(int(size_bytes))


## Uptime as people read it: seconds, minutes, hours and minutes, or days
## and hours.
static func format_uptime(seconds: Variant) -> String:
	if seconds == null:
		return NONE
	var s := int(seconds)
	if s < 60:
		return "%d s" % s
	if s < 3600:
		return "%d min" % (s / 60)
	if s < 86400:
		return "%d h %d min" % [s / 3600, (s % 3600) / 60]
	return "%d d %d h" % [s / 86400, (s % 86400) / 3600]


## The node's state, from the station list.
func _show_node(row: Dictionary) -> void:
	value_label("node").text = "Offline" if str(row.get("nodeStatus", "online")) == "offline" else "Online"


func _on_stations(rows: Array) -> void:
	for row in rows:
		if row is Dictionary and str(row.get("stationId", "")) == station_id():
			_show_node(row)


# ---- Start, Stop and Restart ----

## Start only while stopped, Stop only while running, and none of them
## while one is under way, or where the station does not offer lifecycle.
func _refresh_buttons() -> void:
	var offered: bool = station.get("capabilities", []).has("lifecycle")
	var running: bool = health.get("running", false)
	var busy := _acting != ""
	start_button.disabled = not offered or busy or running
	stop_button.disabled = not offered or busy or not running
	restart_button.disabled = not offered or busy
	for b in [start_button, stop_button, restart_button]:
		b.tooltip_text = NO_LIFECYCLE if not offered else ""


## Asks before `action` ("start", "stop" or "restart"), naming the station;
## live, each says it is real.
func ask(action: String) -> void:
	if read_only or not VERBS.has(action):
		return
	var question := "%s %s?" % [VERBS[action], station_name()]
	if source.LIVE and REAL.has(action):
		question += " " + REAL[action]
	ask_first(question, VERBS[action], _act.bind(action))


## Does the action asked about.
func _act(action: String) -> void:
	_acting = action
	_refresh_buttons()
	request(source.lifecycle(station_id(), action), _on_lifecycle.bind(action))


## The answer is the health after the action.
func _on_lifecycle(ok: bool, body: Variant, _status: int, action: String) -> void:
	_acting = ""
	if not ok:
		_refresh_buttons()
		show_error(body if body is Dictionary else {}, ask.bind(action), LIFECYCLE)
		return
	clear_error(LIFECYCLE)
	show_health(body)

