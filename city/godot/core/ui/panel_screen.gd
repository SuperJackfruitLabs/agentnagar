## The overlay for Inspect and Read (interactions spec section 2): what a
## thing is, and what a display shows, over play or over the map. It is
## skinned by the style's `ui` block, as every screen is.
## - Inspect: the kind's name and description, what it can be used for,
##   and for a display bound to a panel, where its content comes from.
## - Read: the display's panel (Notices, Shelf or Plaque), or "Nothing to
##   read here yet" for a display that shows nothing.
## Sample content says "Sample" in both. The text scrolls: by the wheel, by
## the arrows, Page Up and Down or the d-pad, and by either stick. B, Esc
## or Close leave it.
extends Screen
class_name PanelScreen

## The panel's width, in pixels, where the window has room for it.
const WIDTH := 560.0
## The most of the window's height the text takes before it scrolls.
const MAX_HEIGHT_SHARE := 0.6
## How far a press of an arrow or the d-pad scrolls, in pixels.
const SCROLL_STEP := 48.0
## How fast a stick held over scrolls, in pixels a second.
const STICK_SCROLL_PX_S := 900.0
const STICK_DEAD_ZONE := 0.2
const NOTHING_TO_READ := "Nothing to read here yet"

## The placement or seat shown.
var target := ""
## The panel it shows (a `Panel`: Notices, Shelf or Plaque), or {}.
var panel := {}
## Its catalogue kind.
var kind := {}
## Read (the panel), rather than Inspect (the card).
var reading := false
## Where a bound display's content comes from (its binding's `source`),
## "" for none.
var source := ""

var scrim: ColorRect
var frame: PanelContainer
var scroll: ScrollContainer
## The lines shown, top to bottom, each a Label with its role as meta
## `role` (see lines_of).
var content: VBoxContainer
var close_button: Button
## The stick's hold, for scrolling while it is held.
var _stick := 0.0


## Shows `target_` (a placement or seat ID) of catalogue kind `kind_`, with
## `panel_`, the content it displays ({} for none): read when `reading_`,
## else inspected; `source_` is its binding's source. Call after pushing.
func open(target_: String, panel_: Dictionary, kind_: Dictionary, reading_ := false, source_ := "") -> void:
	target = target_
	panel = panel_
	kind = kind_
	reading = reading_
	source = source_
	if content != null:
		_fill()


func build() -> void:
	scrim = ColorRect.new()
	scrim.name = "Scrim"
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	frame = PanelContainer.new()
	frame.name = "Frame"
	centre.add_child(frame)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	frame.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	content = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	# Wrapped lines settle their height once laid out at their width: the
	# text's height follows them.
	content.minimum_size_changed.connect(func():
		if ui != null:
			_fit_height())
	scroll.add_child(content)
	close_button = Button.new()
	close_button.name = "Close"
	close_button.text = "Close"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(_close)
	# The close button holds the focus, so the scrolling keys reach it
	# first.
	close_button.gui_input.connect(_on_close_input)
	box.add_child(close_button)
	_fill()


## The overlay's lines, top to bottom, as {role, text}. Roles: `name`,
## `sample`, `description`, `verbs`, `source` (inspect); `title`,
## `headline`, `body`, `empty` (read).
static func lines_of(panel_: Dictionary, kind_: Dictionary, reading_: bool, source_ := "") -> Array:
	var out := [{"role": "name", "text": str(kind_.get("name", kind_.get("id", "")))}]
	if panel_.get("sample", false):
		out.append({"role": "sample", "text": Surfaces.SAMPLE})
	if not reading_:
		if str(kind_.get("description", "")) != "":
			out.append({"role": "description", "text": str(kind_["description"])})
		var verbs := Interact.capabilities_of(kind_).map(func(c): return Interact.verb(str(kind_.get("id", "")), c))
		if not verbs.is_empty():
			out.append({"role": "verbs", "text": "You can: " + ", ".join(verbs)})
		if source_ != "":
			var shows := str(panel_.get("title", ""))
			out.append({"role": "source", "text": "Shows: %sfrom the %s source" % [shows + ", " if shows != "" else "", source_]})
		return out
	if panel_.is_empty():
		out.append({"role": "empty", "text": NOTHING_TO_READ})
		return out
	out.append({"role": "title", "text": str(panel_.get("title", ""))})
	match str(panel_.get("type", "")):
		"Notices":
			var headlines := Surfaces.headlines(panel_)
			var items: Array = panel_.get("items", [])
			for i in items.size():
				out.append({"role": "headline", "text": headlines[i]})
				out.append({"role": "body", "text": str(items[i].get("body", ""))})
		"Shelf":
			for spine in panel_.get("spines", []):
				out.append({"role": "headline", "text": str(spine.get("title", ""))})
				if str(spine.get("subtitle", "")) != "":
					out.append({"role": "body", "text": str(spine["subtitle"])})
		"Plaque":
			out.append({"role": "body", "text": str(panel_.get("text", ""))})
	return out


## Everything the overlay says, a line each, for tests and for reading it
## out.
func text() -> String:
	return "\n".join(lines_of(panel, kind, reading, source).map(func(l): return l["text"]))


## The label of the first line of `role`, or null.
func line(role: String) -> Label:
	if content == null:
		return null
	for l in content.get_children():
		if l.get_meta("role", "") == role:
			return l
	return null


func _fill() -> void:
	for child in content.get_children():
		child.free()
	for l in lines_of(panel, kind, reading, source):
		var label := Label.new()
		label.name = str(l["role"]).capitalize()
		label.set_meta("role", l["role"])
		label.text = l["text"]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(label)
	scroll.scroll_vertical = 0
	if ui != null:
		restyle()


func restyle() -> void:
	scrim.color = ui.colour("scrim")
	var width := minf(WIDTH, maxf(size.x - 32.0, 240.0)) if size.x > 0.0 else WIDTH
	frame.custom_minimum_size.x = width
	var inner := width - 48.0
	var text_size := int(ui.spec.get("text_size", 20))
	for l in content.get_children():
		var label := l as Label
		label.custom_minimum_size.x = inner
		var role := str(label.get_meta("role", ""))
		var heading := role in ["name", "title", "headline"]
		label.add_theme_font_override("font", ui.display_font if heading else ui.body_font)
		match role:
			"name":
				label.add_theme_font_size_override("font_size", ui.display_size(text_size + 8))
			"title":
				label.add_theme_font_size_override("font_size", ui.display_size(text_size + 4))
			"headline":
				label.add_theme_font_size_override("font_size", ui.display_size(text_size))
			_:
				label.add_theme_font_size_override("font_size", ui.font_size(text_size))
		var muted := role in ["verbs", "source", "empty"]
		label.add_theme_color_override("font_color", ui.colour("accent") if role == "sample" else ui.colour("ink_muted" if muted else "ink"))
	close_button.text = ui.case("Close")
	close_button.custom_minimum_size.y = float(ui.spec.get("button", {}).get("height", 48))
	_fit_height()


## The text takes the height it needs, up to MAX_HEIGHT_SHARE of the
## window; beyond that it scrolls.
func _fit_height() -> void:
	var window := size.y if size.y > 0.0 else 720.0
	var wanted := content.get_combined_minimum_size().y
	scroll.custom_minimum_size = Vector2(frame.custom_minimum_size.x - 48.0, minf(wanted, window * MAX_HEIGHT_SHARE))


## How far down the text is scrolled, in pixels.
func scrolled() -> int:
	return scroll.scroll_vertical


## Scrolls the text by `pixels` (down when positive).
func scroll_by(pixels: float) -> void:
	scroll.scroll_vertical = int(scroll.scroll_vertical + pixels)


## The keys and buttons that scroll: the arrows, Page Up and Down and the
## d-pad; the sticks are held (see _process). True when used.
func handle_key(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		if event.axis in [JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_Y]:
			_stick = event.axis_value if absf(event.axis_value) > STICK_DEAD_ZONE else 0.0
			return true
		return false
	if not event.is_pressed():
		return false
	var page := scroll.size.y if scroll.size.y > 0.0 else SCROLL_STEP * 4.0
	if _is_key(event, [KEY_DOWN]) or _is_button(event, JOY_BUTTON_DPAD_DOWN):
		scroll_by(SCROLL_STEP)
	elif _is_key(event, [KEY_UP]) or _is_button(event, JOY_BUTTON_DPAD_UP):
		scroll_by(-SCROLL_STEP)
	elif _is_key(event, [KEY_PAGEDOWN]):
		scroll_by(page)
	elif _is_key(event, [KEY_PAGEUP]):
		scroll_by(-page)
	else:
		return false
	return true


func _process(delta: float) -> void:
	if _stick != 0.0 and scroll != null:
		scroll_by(_stick * STICK_SCROLL_PX_S * delta)


func _on_close_input(event: InputEvent) -> void:
	if handle_key(event):
		close_button.accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if stack == null or stack.top() != self:
		return
	if handle_key(event):
		get_viewport().set_input_as_handled()


## Refitted to every new window size (Screen's own notification runs too).
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _built and ui != null:
		restyle()


func _close() -> void:
	if stack != null and stack.top() == self:
		stack.remove(self)


static func _is_key(event: InputEvent, codes: Array) -> bool:
	return event is InputEventKey and (event.keycode in codes or event.physical_keycode in codes)


static func _is_button(event: InputEvent, button: JoyButton) -> bool:
	return event is InputEventJoypadButton and event.button_index == button
