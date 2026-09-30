## The map: a full-window screen on the interface's stack with two tabs and
## a card. The Map tab shows the style's own top-down picture of the
## district (asked of the pack through `StyleHost.request_map`), a pin for
## each place with a category, a label plate for every place, a legend that
## filters, a compass, a scale bar where the style asks for one, and a
## pulsing "you are here", over the tram's route in the Transit colour.
## The List tab shows the same places as rows under a search field, each
## followed by the displays in it to read, as text (the Read overlay opens
## on one with Enter or A). The card names the selected place, its rooms
## and how many people are inside, with Go; a tram stop's card also says
## when the next tram comes each way.
##
## Every control works from the keyboard and from a controller: arrows or
## the d-pad move the selection, Enter or A goes, Tab or Y switches tabs,
## 1-4 or X filter, `+`/`-`, the wheel or the triggers zoom, a drag or the
## left stick pans, and M, Esc or B close. The panels, buttons and fonts
## come from the style's `ui` skin; the pins' shape, the plates and the
## colour round the picture from its `map` block (MapTheme). While the map
## is open it covers the whole window, and the main view draws no 3D.
extends Screen
class_name MapScreen

## The four category icons and "you are here", white shapes on nothing
## (you.svg has its own colours).
const ICONS_DIR := "res://core/map/icons/"
## The words for the four categories, as the legend, rows and card show
## them; a place with none is a "Place".
const CATEGORY_WORDS := {
	"workshop": "Workshop", "library": "Library", "transit": "Transit", "park": "Park",
}
const NO_CATEGORY_WORD := "Place"

## Room kept round the edges of the window, and between its parts.
const MARGIN := 24.0
const GAP := 16.0
## The card's width beside the map, at least and at most (wide enough for
## the longest line of rooms in the skin's font); in the narrow layout it
## takes the whole width, under the map.
const CARD_WIDTH := 360.0
const CARD_MAX_WIDTH := 480.0
## The List tab's width, centred, outside the narrow layout.
const LIST_WIDTH := 720.0
## The rows the List tab keeps room for: with fewer under it, the card goes
## beside the list where the window is wide enough.
const LIST_MIN_ROWS := 4
## The label plates' text size, before the player's text scale, and the
## small print's (the compass, the scale bar, the card's fixture note).
const PLATE_TEXT_SIZE := 16
const SMALL_TEXT_SIZE := 16
## The card's name, in the display font.
const CARD_NAME_SIZE := 26
## The gap between the card's lines.
const CARD_SEPARATION := 8
## A tram stop's line as long as it gets, held by the hidden line so it
## keeps its height (see _layout).
const TRAMS_SAMPLE := "East in 00 s · West in 00 s"
## A List row's category icon, the plate round it, and the room either
## side of the plate.
const ROW_ICON_PX := 24.0
const ROW_PLATE_PADDING := 4.0
const ROW_PADDING := 12.0

## Zoom runs from the fitted picture to twice it.
const ZOOM_MIN := 1.0
const ZOOM_MAX := 2.0
## One `+` or `-` press, and one notch of the wheel.
const ZOOM_STEP := 0.25
const WHEEL_STEP := 0.1
## Zoom a second with a trigger held all the way.
const ZOOM_RATE := 1.0
## Pixels a second the left stick pans, held all the way.
const PAN_SPEED := 900.0
## Below these the stick and triggers are at rest.
const STICK_DEAD_ZONE := 0.2
const TRIGGER_DEAD_ZONE := 0.1
## Places kept this far inside the map's edge when the selection moves
## while zoomed in.
const KEEP_IN_VIEW := 60.0
## Room kept round the places when the map opens framed on them.
const FRAME_MARGIN := 32.0
## How much the opening zoom is eased back at a time until every place,
## pin and label is in view.
const FRAME_STEP := 0.05

## The base picture is asked for at twice its fitted size, so 2x zoom
## stays sharp, and never more than this on its long side.
const BASE_MAX_PX := 4096
## How long to wait for the base before asking once more.
const BASE_TIMEOUT_S := 2.0

## How long a notice stays up on the map, the last half second fading.
const NOTICE_S := 4.0
const NOTICE_FADE_S := 0.5

## "You are here": its size, and its pulse (1 to PULSE_SCALE over
## PULSE_S, and back).
const YOU_PX := 40.0
const PULSE_S := 1.0
const PULSE_SCALE := 1.15
## The compass, and the scale bar's length in metres.
const COMPASS_SIZE := Vector2(48, 68)
const SCALE_BAR_M := 50.0
## Room left between the picture's edge and the compass or scale bar.
const INSET := 12.0

## Go was chosen for this place (a facility ID). The map does not close
## itself: whoever opened it decides what Go does.
signal go(place_id: String)
## A display's row was chosen on the List tab: read it (its placement ID).
signal read(placement_id: String)

var model: MapModel
var host: StyleHost
var glyphs: InputGlyphs
var theme_map: MapTheme
## The viewer's latest projection, for the counts of people inside. One
## lands every tick: the rows' and the card's counts change in place, so a
## row being clicked is never taken away between the press and the release.
var projection := {}:
	set(value):
		projection = value
		if model != null:
			model.trams.observe(value)
		if _built:
			_refresh_counts()
			_refresh_card()
## "You are here", in metres (x east, y south), or null for no one.
var you = null
## Which way you face, in the same axes; zero for no particular way.
var you_facing := Vector2.ZERO
## "map" or "list".
var tab := "map"
## From ZOOM_MIN to ZOOM_MAX.
var zoom := 1.0
## How far the zoomed picture's centre is moved from the fitted picture's,
## in screen pixels; clamped so the picture always covers its fitted place.
var pan := Vector2.ZERO
## The size of the base picture last asked for.
var base_asked := Vector2i.ZERO

## The colour round the picture, behind everything, over the whole window.
var backdrop: ColorRect
var tabs: TabBar
var legend: HBoxContainer
## The Map tab: its picture and what is drawn on it, clipped to the area.
var map_area: Control
var base: TextureRect
## The transit lines' routes, over the picture and under the labels and pins.
var route_layer: MapRoute
var labels_layer: Control
var pins_layer: Control
var you_marker: TextureRect
var compass: MapCompass
var scale_bar: MapScaleBar
## The List tab.
var list_panel: PanelContainer
var search: LineEdit
var rows_scroll: ScrollContainer
var rows: VBoxContainer
var no_match: Label
## The card and its lines.
var card: PanelContainer
var card_name: Label
var card_icon: TextureRect
var card_word: Label
var card_rooms: Label
var card_inside: Label
## When the next tram comes each way; shown on a tram stop's card only.
var card_trams: Label
var card_fixture: Label
var go_button: Button
var hints_chip: PanelContainer
var hints: Label
## A short notice over the map (an unknown --place), shown on the map
## itself: the HUD's notices are under the map's backdrop, and hidden on
## the title.
var notice_chip: PanelContainer
var notice_label: Label

## The picture's place at zoom 1, in `map_area`'s coordinates: the
## district's extent fitted to the area, centred.
var _fit := Rect2()
## The card's width beside the map, for this skin.
var _card_width := CARD_WIDTH
## Facility ID -> its pin, its label plate, its row.
var _pins := {}
var _labels := {}
var _rows := {}
## The label rectangles last laid out, and the picture size they were for.
var _label_rects := {}
var _labels_for := Vector2(-1, -1)
## Whether open() has run.
var _opened := false
## The pack folder the waiting or shown picture was asked of.
var _asked_dir := ""
## Waiting for a picture, how long so far, and whether it was asked again.
var _waiting := false
var _waited := 0.0
var _retried := false
## The viewport whose 3D is off while the map is open, and how it was.
var _held_viewport: Viewport
var _held_3d := false
## The left stick and the two triggers, as held now.
var _stick := Vector2.ZERO
var _trigger_in := 0.0
var _trigger_out := 0.0
## Time for the pulse.
var _pulse_t := 0.0
## The selection the pins, rows and card last showed.
var _shown_selected := "\n"
## Frames left in which the list scrolls to the selected row: its rows and
## their scroll are laid out a frame after they change, so the scroll is
## made again once they have been.
var _scroll_frames := 0
## The hints for this tab and device, joined on one or two lines to fit.
var _hint_parts: Array = []
## Seconds the notice has left up.
var _notice_left := 0.0
## Whether the rows no longer match the filter and search: they are built
## again when the List tab next shows, never while it is hidden.
var _rows_stale := true
## Whether the view is still as the map opened it, framed on the places:
## a new window size frames them again, until the player zooms or pans.
var _keep_framing := false


func _init() -> void:
	super._init()
	focus_mode = Control.FOCUS_ALL


## The node name a place's pin, label or row is given: a node name cannot
## hold an ID's colon, so this is the name Godot would make of it.
static func node_name(prefix: String, id: String) -> String:
	return (prefix + id).validate_node_name()


## The size of the base picture to ask for when it is shown at `fitted`:
## twice that, so 2x zoom stays sharp, scaled down to BASE_MAX_PX on its
## long side, keeping its aspect.
static func size_px_for(fitted: Vector2) -> Vector2i:
	var want := fitted * 2.0
	var long := maxf(want.x, want.y)
	if long > BASE_MAX_PX:
		want *= BASE_MAX_PX / long
	return Vector2i(maxi(1, roundi(want.x)), maxi(1, roundi(want.y)))


static func icon(category: String) -> Texture2D:
	var path := ICONS_DIR + category + ".svg"
	return load(path) if category != "" and ResourceLoader.exists(path) else null


static func category_word(category: String) -> String:
	return CATEGORY_WORDS.get(category, NO_CATEGORY_WORD)


# ---- Building ----

func build() -> void:
	if theme_map == null:
		theme_map = MapTheme.from_style({})
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_build_map_area()
	_build_top()
	_build_list()
	_build_card()
	_build_hints()
	_build_notice()
	if model != null:
		for p in model.places:
			_build_place(p)
		if not model.places.is_empty():
			_fill_card(model.places[0])
	card.visible = false
	if glyphs != null:
		glyphs.device_changed.connect(_update_hints.unbind(1))
	_show_tab()


func _build_map_area() -> void:
	map_area = Control.new()
	map_area.name = "MapArea"
	map_area.clip_contents = true
	map_area.mouse_filter = Control.MOUSE_FILTER_STOP
	map_area.gui_input.connect(_on_area_input)
	add_child(map_area)
	base = TextureRect.new()
	base.name = "Base"
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_SCALE
	base.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_area.add_child(base)
	route_layer = MapRoute.new()
	route_layer.name = "Route"
	route_layer.colour = MapModel.COLOURS["transit"]
	route_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_area.add_child(route_layer)
	labels_layer = _layer("Labels")
	pins_layer = _layer("Pins")
	you_marker = TextureRect.new()
	you_marker.name = "You"
	you_marker.texture = icon("you")
	you_marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	you_marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	you_marker.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	you_marker.size = Vector2.ONE * YOU_PX
	you_marker.pivot_offset = you_marker.size / 2.0
	you_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	you_marker.visible = false
	map_area.add_child(you_marker)
	compass = MapCompass.new()
	compass.name = "Compass"
	compass.size = COMPASS_SIZE
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_area.add_child(compass)
	scale_bar = MapScaleBar.new()
	scale_bar.name = "ScaleBar"
	scale_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_area.add_child(scale_bar)


## A see-through layer over the whole map area, for pins or labels.
func _layer(layer_name: String) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_area.add_child(layer)
	return layer


## The Map and List tabs, and the legend's four categories.
func _build_top() -> void:
	tabs = TabBar.new()
	tabs.name = "Tabs"
	tabs.focus_mode = Control.FOCUS_NONE
	tabs.clip_tabs = false
	tabs.add_tab("Map")
	tabs.add_tab("List")
	tabs.tab_changed.connect(func(i): set_tab("map" if i == 0 else "list"))
	add_child(tabs)
	legend = HBoxContainer.new()
	legend.name = "Legend"
	legend.add_theme_constant_override("separation", 8)
	add_child(legend)
	for category in MapModel.CATEGORIES:
		var b := Button.new()
		b.name = category
		b.text = category_word(category)
		b.icon = icon(category)
		b.expand_icon = false
		b.focus_mode = Control.FOCUS_NONE
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		b.pressed.connect(toggle_filter.bind(category))
		legend.add_child(b)


func _build_list() -> void:
	list_panel = PanelContainer.new()
	list_panel.name = "ListPanel"
	add_child(list_panel)
	var margin := _margin(16)
	list_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	search = LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "Search places"
	search.clear_button_enabled = true
	search.text_changed.connect(set_query)
	search.gui_input.connect(_on_search_input)
	box.add_child(search)
	no_match = Label.new()
	no_match.name = "NoMatch"
	no_match.text = "No places match"
	no_match.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_match.visible = false
	box.add_child(no_match)
	rows_scroll = ScrollContainer.new()
	rows_scroll.name = "RowsScroll"
	rows_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(rows_scroll)
	rows = VBoxContainer.new()
	rows.name = "Rows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	rows_scroll.add_child(rows)


func _build_card() -> void:
	card = PanelContainer.new()
	card.name = "Card"
	card.set_meta("summary", "")
	add_child(card)
	var margin := _margin(16)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", CARD_SEPARATION)
	margin.add_child(box)
	card_name = _card_line(box, "Name")
	var kind := HBoxContainer.new()
	kind.name = "Kind"
	kind.add_theme_constant_override("separation", 8)
	box.add_child(kind)
	card_icon = TextureRect.new()
	card_icon.name = "Icon"
	card_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	card_icon.custom_minimum_size = Vector2(24, 24)
	kind.add_child(card_icon)
	card_word = _card_line(kind, "Word")
	card_rooms = _card_line(box, "Rooms")
	card_inside = _card_line(box, "Inside")
	card_trams = _card_line(box, "Trams")
	card_trams.text = TRAMS_SAMPLE
	card_trams.visible = false
	card_fixture = _card_line(box, "Fixture")
	card_fixture.text = PlayHud.BANNER
	go_button = Button.new()
	go_button.name = "Go"
	go_button.text = "Go"
	go_button.focus_mode = Control.FOCUS_NONE
	go_button.pressed.connect(press_go)
	box.add_child(go_button)


## One line of the card: a single line, cut short with an ellipsis rather
## than widening the card.
func _card_line(parent: Control, line_name: String) -> Label:
	var l := Label.new()
	l.name = line_name
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


func _build_hints() -> void:
	hints_chip = PanelContainer.new()
	hints_chip.name = "HintsChip"
	hints_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hints_chip)
	var margin := _margin(6)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints_chip.add_child(margin)
	hints = Label.new()
	hints.name = "Hints"
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	margin.add_child(hints)


## The notice chip, over the map (added after it, so drawn over it).
func _build_notice() -> void:
	notice_chip = PanelContainer.new()
	notice_chip.name = "NoticeChip"
	notice_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_chip.visible = false
	add_child(notice_chip)
	var margin := _margin(8)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_chip.add_child(margin)
	notice_label = Label.new()
	notice_label.name = "Notice"
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	margin.add_child(notice_label)


func _margin(px: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, px)
	return m


## A place's label plate, and its pin when it has a category. A click on
## either selects the place; the rest of a press (a drag, the wheel) goes
## on to the map under them.
func _build_place(p: Dictionary) -> void:
	var id: String = p["id"]
	var plate := PanelContainer.new()
	plate.name = node_name("Label_", id)
	plate.mouse_filter = Control.MOUSE_FILTER_PASS
	plate.set_meta("place_name", p["name"])
	plate.gui_input.connect(_on_place_input.bind(id))
	var text := Label.new()
	text.name = "Text"
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(text)
	labels_layer.add_child(plate)
	_labels[id] = plate
	if p["category"] == "":
		return
	var pin := MapPin.new()
	pin.name = node_name("Pin_", id)
	pin.colour = MapModel.COLOURS[p["category"]]
	pin.icon = icon(p["category"])
	pin.size = Vector2.ONE * MapModel.PIN_PX
	pin.mouse_filter = Control.MOUSE_FILTER_PASS
	pin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pin.gui_input.connect(_on_place_input.bind(id))
	pins_layer.add_child(pin)
	_pins[id] = pin


# ---- Opening, and the base picture ----

## Starts the map: "you are here" (or, watching with no one to be, the
## point the view is over) becomes where arrows start from, the base
## picture is asked for, the main view stops drawing 3D, and the Map tab
## opens framed on the places. `place_id` (a facility or one of its rooms)
## is selected and centred when known; an unknown ID leaves nothing
## selected and says so on the map. The map must be on the stack (in the
## tree) first: out of it there is no view to stop drawing 3D in, and none
## would be stopped.
func open(place_id := "") -> void:
	assert(is_inside_tree(), "MapScreen.open: push the map on the stack before opening it")
	model.origin = you if you != null else _view_ground()
	_hold_3d()
	if host != null and not host.map_ready.is_connected(_on_map_ready):
		host.map_ready.connect(_on_map_ready)
	_layout()
	_opened = true
	_request_base()
	if place_id != "":
		if model.place(place_id).is_empty():
			show_notice("No place called " + place_id)
		else:
			model.select(place_id)
	_frame_places()
	_on_selection_changed()


## The point the main view is over, in metres, for a spectator's first
## arrow; the district's middle for a view with none (a 2D pack's).
func _view_ground() -> Vector2:
	var at = host.pack.camera_ground_pos() if host != null and host.pack != null else null
	return at / 100.0 if at is Vector2 else model.extent.get_center()


## Shows `text` on the map for NOTICE_S seconds, fading at the end.
func show_notice(text: String) -> void:
	notice_label.text = text
	notice_chip.visible = true
	notice_chip.modulate.a = 1.0
	_notice_left = NOTICE_S
	_layout()


## Counts the notice's time down, fading it over its last NOTICE_FADE_S.
func _tick_notice(delta: float) -> void:
	if _notice_left <= 0.0:
		return
	_notice_left -= delta
	notice_chip.modulate.a = clampf(_notice_left / NOTICE_FADE_S, 0.0, 1.0)
	if _notice_left <= 0.0:
		notice_chip.visible = false


## Asks the pack shown for the base picture at twice its fitted size; the
## letterbox colour shows until it comes.
func _request_base() -> void:
	if host == null or model == null or _fit.size.x <= 0.0 or _fit.size.y <= 0.0:
		return
	base_asked = size_px_for(_fit.size)
	_asked_dir = host.pack_dir
	_waiting = true
	_waited = 0.0
	_retried = false
	host.request_map(model.extent, base_asked)


## A picture from the host: shown if it is the current style's.
func _on_map_ready(texture: Texture2D, pack_dir: String) -> void:
	if host == null or pack_dir != host.pack_dir:
		return
	base.texture = texture
	_waiting = false


## Waiting too long for a picture (the pack left, or never answers), asks
## once more; after that the letterbox stays until the style changes.
func _tick_base(delta: float) -> void:
	if not _waiting:
		return
	_waited += delta
	if _waited < BASE_TIMEOUT_S:
		return
	if _retried or host == null:
		_waiting = false
		return
	_retried = true
	_waited = 0.0
	host.request_map(model.extent, base_asked)


## The window grew past the picture asked for: a sharper one is asked for.
func _regrow_base() -> void:
	if not _opened:
		return
	var want := size_px_for(_fit.size)
	if want.x > base_asked.x or want.y > base_asked.y:
		_request_base()


## The main view draws no 3D while the map covers it (spec section 4).
func _hold_3d() -> void:
	if _held_viewport != null or not is_inside_tree():
		return
	_held_viewport = get_viewport()
	_held_3d = _held_viewport.disable_3d
	_held_viewport.disable_3d = true


## Puts the main view's 3D back exactly as the map found it.
func _release_3d() -> void:
	if _held_viewport != null and is_instance_valid(_held_viewport):
		_held_viewport.disable_3d = _held_3d
	_held_viewport = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_PREDELETE:
		_release_3d()
	elif what == NOTIFICATION_RESIZED and _built and ui != null:
		_layout()


## The style's `map` block is read again on every reskin (a style switch
## among them), and a switch asks the new style for its picture.
func apply_theme(t: UiTheme) -> void:
	if host != null and host.pack != null:
		theme_map = MapTheme.from_style(host.pack.style)
	elif theme_map == null:
		theme_map = MapTheme.from_style({})
	super.apply_theme(t)
	if _opened and host != null and host.pack_dir != _asked_dir:
		base.texture = null
		_request_base()


# ---- Tabs, filter, search, selection and Go ----

## Shows the Map tab ("map") or the List tab ("list").
func set_tab(t: String) -> void:
	if t != "map" and t != "list" or t == tab:
		return
	tab = t
	_show_tab()
	focus_first()


func _show_tab() -> void:
	var index := 0 if tab == "map" else 1
	if tabs.current_tab != index:
		tabs.current_tab = index
	map_area.visible = tab == "map"
	list_panel.visible = tab == "list"
	if tab == "list" and _rows_stale:
		_rebuild_rows()
	_layout()
	_update_hints()
	if tab == "list":
		_follow_selected_row()


## The Map tab keys go to the screen itself; the List tab's to its search
## field, which passes the map's own keys on (see _on_search_input).
func focus_first() -> void:
	if not is_inside_tree():
		return
	if tab == "list" and search.is_visible_in_tree():
		search.grab_focus()
		if search.has_method("edit"):
			search.edit()
	elif is_visible_in_tree():
		grab_focus()


## Shows only `category`'s places, or every place when it is already the
## filter.
func toggle_filter(category: String) -> void:
	model.filter = "" if model.filter == category else category
	_on_places_changed()


## The next filter in turn: each category, then every place again.
func cycle_filter() -> void:
	var order := [""] + MapModel.CATEGORIES
	model.filter = order[(order.find(model.filter) + 1) % order.size()]
	_on_places_changed()


## Searches the places' names, as typing in the search field does.
func set_query(text: String) -> void:
	if search.text != text:
		search.text = text
		search.caret_column = text.length()
	model.query = text
	_on_places_changed()


## Selects a place by its ID or a room's.
func select(id: String) -> void:
	model.select(id)
	_on_selection_changed()


## Go, as Enter, A and the card's button do: sent for the selected place
## while the tab shown shows it; nothing happens with nothing to go to. A
## display selected on the List tab is read instead.
func press_go() -> void:
	var id := model.selected
	if id == "" or not _is_shown(id):
		return
	if model.things.has(id):
		read.emit(id)
	else:
		go.emit(id)


## Whether the tab shown shows the place: the Map tab by the filter, the
## List tab by the filter and the search.
func _is_shown(id: String) -> bool:
	if model.things.has(id):
		return tab == "list" and _is_shown(model.things[id]["place"])
	for p in (model.map_places() if tab == "map" else model.visible_places()):
		if p["id"] == id:
			return true
	return false


## The filter or search changed: a selection they hide is let go, and the
## pins, labels and legend follow; the rows now, on the List tab, or when
## it next shows.
func _on_places_changed() -> void:
	if model.selected != "" and not _is_shown(model.selected):
		model.selected = ""
	_labels_for = Vector2(-1, -1)
	if ui != null:
		_style_legend()
	_rows_stale = true
	if tab == "list":
		_rebuild_rows()
	_place_overlay()
	_on_selection_changed()


func _on_selection_changed() -> void:
	_shown_selected = model.selected
	for id in _pins:
		var pin: MapPin = _pins[id]
		pin.selected = id == model.selected
		pin.queue_redraw()
	if ui != null:
		for id in _labels:
			_style_plate(id)
	for id in _rows:
		(_rows[id] as Button).set_pressed_no_signal(id == model.selected)
	_follow_selected_row()
	_keep_in_view(model.selected)
	_refresh_card()


## Scrolls the list to the selected row at the end of this frame and again
## in the next two, by when its rows and the scroll round them are laid out.
func _follow_selected_row() -> void:
	_scroll_frames = 2
	_scroll_to_selected.call_deferred()


## Scrolls the list to the selected row, as far as the rows are laid out.
func _scroll_to_selected() -> void:
	var row: Button = _rows.get(model.selected) if model != null else null
	if row != null and is_instance_valid(row) and row.is_visible_in_tree():
		rows_scroll.ensure_control_visible(row)


# ---- Input ----

## The path every key and controller input takes, from the screen or from
## its search field; true when the map used it.
func handle_key(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		return _held_axis(event)
	if not (event is InputEventKey or event is InputEventJoypadButton) or not event.is_pressed():
		return false
	var dir := _direction(event)
	if dir != Vector2.ZERO:
		if tab == "map":
			model.step(dir)
		elif dir.y != 0.0:
			model.step_row(1 if dir.y > 0.0 else -1)
		_on_selection_changed()
		return true
	# A held key repeats only for moving the selection.
	if event.is_echo():
		return _is_key(event, [KEY_ENTER, KEY_KP_ENTER, KEY_TAB])
	if event.is_action_pressed("map") or _is_button(event, JOY_BUTTON_B):
		_close()
	elif _is_key(event, [KEY_ENTER, KEY_KP_ENTER]) or _is_button(event, JOY_BUTTON_A):
		press_go()
	elif _is_key(event, [KEY_TAB]) or _is_button(event, JOY_BUTTON_Y):
		set_tab("list" if tab == "map" else "map")
	elif _is_button(event, JOY_BUTTON_X):
		cycle_filter()
	elif _digit(event) >= 1:
		toggle_filter(MapModel.CATEGORIES[_digit(event) - 1])
	# Zoom in and out are the triggers by default, held axes taken above;
	# a key or button a player binds to them in the settings comes here.
	elif event.is_action_pressed("zoom_in") or _is_key(event, [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD]):
		set_zoom(zoom + ZOOM_STEP)
	elif event.is_action_pressed("zoom_out") or _is_key(event, [KEY_MINUS, KEY_KP_SUBTRACT]):
		set_zoom(zoom - ZOOM_STEP)
	else:
		return false
	return true


## The screen itself holds the focus on the Map tab, so its keys come here
## before the focus could move.
func _gui_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if handle_key(event):
		viewport.set_input_as_handled()


## Whatever the focus missed, while the map is the top screen.
func _unhandled_input(event: InputEvent) -> void:
	if stack == null or stack.top() != self:
		return
	var viewport := get_viewport()
	if handle_key(event):
		viewport.set_input_as_handled()


## Typing goes to the search; moving, Enter, Tab, Esc and the controller
## go to the map.
func _on_search_input(event: InputEvent) -> void:
	var viewport := search.get_viewport()
	if event is InputEventKey and event.pressed:
		if event.is_action_pressed("ui_cancel"):
			viewport.set_input_as_handled()
			_close()
		elif _is_key(event, [KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER, KEY_TAB]) and handle_key(event):
			viewport.set_input_as_handled()
	elif (event is InputEventJoypadButton or event is InputEventJoypadMotion) and handle_key(event):
		viewport.set_input_as_handled()


## Closes the map, as Back does, from within its own input: it leaves the
## stack at once and is freed once the input is over.
func _close() -> void:
	if stack == null or stack.top() != self or on_back():
		return
	stack.remove(self)


## The arrows and the d-pad, as a screen direction (+y south).
func _direction(event: InputEvent) -> Vector2:
	var pairs := [
		[KEY_UP, JOY_BUTTON_DPAD_UP, Vector2.UP], [KEY_DOWN, JOY_BUTTON_DPAD_DOWN, Vector2.DOWN],
		[KEY_LEFT, JOY_BUTTON_DPAD_LEFT, Vector2.LEFT], [KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT, Vector2.RIGHT],
	]
	for p in pairs:
		if _is_key(event, [p[0]]) or _is_button(event, p[1]):
			return p[2]
	return Vector2.ZERO


## 1 to 4 on the keyboard's top row or keypad; 0 for anything else.
func _digit(event: InputEvent) -> int:
	for i in 4:
		if _is_key(event, [KEY_1 + i, KEY_KP_1 + i]):
			return i + 1
	return 0


static func _is_key(event: InputEvent, codes: Array) -> bool:
	return event is InputEventKey and (event.keycode in codes or event.physical_keycode in codes)


static func _is_button(event: InputEvent, button: JoyButton) -> bool:
	return event is InputEventJoypadButton and event.button_index == button


## The left stick and the triggers are held, not pressed: they are kept,
## and `tick` pans and zooms by them.
func _held_axis(event: InputEventJoypadMotion) -> bool:
	var v := event.axis_value
	match event.axis:
		JOY_AXIS_LEFT_X:
			_stick.x = v if absf(v) > STICK_DEAD_ZONE else 0.0
		JOY_AXIS_LEFT_Y:
			_stick.y = v if absf(v) > STICK_DEAD_ZONE else 0.0
		JOY_AXIS_TRIGGER_RIGHT:
			_trigger_in = v if v > TRIGGER_DEAD_ZONE else 0.0
		JOY_AXIS_TRIGGER_LEFT:
			_trigger_out = v if v > TRIGGER_DEAD_ZONE else 0.0
		_:
			return false
	return true


## The wheel zooms about the pointer, a double click zooms all the way in
## there, and a drag pans.
func _on_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				set_zoom(zoom + WHEEL_STEP, event.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				set_zoom(zoom - WHEEL_STEP, event.position)
			MOUSE_BUTTON_LEFT:
				if event.double_click:
					set_zoom(ZOOM_MAX, event.position)
			_:
				return
		map_area.accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_keep_framing = false
		set_pan(pan + event.relative)
		map_area.accept_event()


## A click on a pin or a label selects its place.
func _on_place_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select(id)


# ---- Zoom and pan ----

## Zooms to `z` (clamped to 1-2), keeping the point `about` (in the map
## area's coordinates) where it is, or else the middle of the view.
func set_zoom(z: float, about = null) -> void:
	_keep_framing = false
	z = clampf(z, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(z, zoom):
		zoom = z
		return
	var fixed: Vector2 = about if about != null else _fit.get_center()
	var shown := _fit.size * zoom
	var top_left := _top_left()
	var along := (fixed - top_left) / shown if shown.x > 0.0 and shown.y > 0.0 else Vector2.ONE * 0.5
	zoom = z
	var new_top_left := fixed - along * _fit.size * zoom
	set_pan(new_top_left + _fit.size * zoom / 2.0 - _fit.get_center())


## Moves the picture by `p` (screen pixels from the fitted centre), no
## further than keeps it covering its fitted place.
func set_pan(p: Vector2) -> void:
	var reach := _fit.size * (zoom - 1.0) / 2.0
	pan = Vector2(clampf(p.x, -reach.x, reach.x), clampf(p.y, -reach.y, reach.y))
	_place_overlay()


## The zoomed picture's top-left corner, in the map area's coordinates.
func _top_left() -> Vector2:
	return _fit.get_center() + pan - _fit.size * zoom / 2.0


## Zoomed in, a newly selected place off the view is brought into it.
func _keep_in_view(id: String) -> void:
	var p := model.place(id) if model != null else {}
	if p.is_empty() or zoom <= ZOOM_MIN or _fit.size.x <= 0.0:
		return
	var at := _top_left() + model.to_map(p["centre"], _fit.size * zoom)
	var view := Rect2(Vector2.ZERO, map_area.size).grow(-KEEP_IN_VIEW)
	if not view.has_point(at):
		set_pan(pan + view.get_center() - at)


## Frames the view on the places, as the map opens: the zoom (within 1-2x)
## and pan that fit every place's footprint, pin and label, with a margin,
## into the map, clear of the compass and the scale bar, so the places the
## sheets name fill most of it. With a place selected, the view moves
## toward it, as far as keeps every place in view, so it is centred when
## there is room. Zooming out to 1x still shows the whole district. The
## framing holds, a new window size framing again, until the player zooms
## or pans.
func _frame_places() -> void:
	if model == null or model.places.is_empty() or _fit.size.x <= 0.0 or map_area.size.x <= 0.0:
		return
	var view := Rect2(Vector2.ZERO, map_area.size)
	var room := view.grow(-FRAME_MARGIN)
	# Labels keep their size as the picture grows, so the fit is found in
	# a few passes, each laying the labels out at the zoom it tries.
	var z := ZOOM_MIN
	for i in 3:
		var box := _box_of(_place_parts(z))
		if box.size.x <= 0.0 or box.size.y <= 0.0:
			break
		z = clampf(z * minf(room.size.x / box.size.x, room.size.y / box.size.y), ZOOM_MIN, ZOOM_MAX)
	# Eased back until the pan's clamp, the labels, the compass and the
	# scale bar leave every place in view.
	while true:
		zoom = z
		pan = Vector2.ZERO
		_pan_toward(_box_of(_place_parts(z)).get_center())
		if z <= ZOOM_MIN or _framed_clear(view):
			break
		z = maxf(ZOOM_MIN, z - FRAME_STEP)
	var p := model.place(model.selected)
	if not p.is_empty() and _framed_clear(view):
		var before := pan
		_pan_toward(model.to_map(p["centre"], _fit.size * z), view)
		if not _framed_clear(view):
			set_pan(before)
	_keep_framing = true


## Whether every place's footprint, pin and label is inside `view` and
## clear of the compass and the scale bar, as the view is now.
func _framed_clear(view: Rect2) -> bool:
	var overlays: Array = [compass.get_rect()]
	if scale_bar.visible:
		overlays.append(scale_bar.get_rect())
	for r in _place_parts(zoom, _top_left()):
		if not view.encloses(r):
			return false
		for o in overlays:
			if r.intersects(o):
				return false
	return true


## Pans the point `target` of the zoomed picture toward the middle of the
## map: with `keep`, no further than keeps the places' box inside it (when
## it is already); always no further than the pan's own clamp allows.
func _pan_toward(target: Vector2, keep := Rect2()) -> void:
	var shift := map_area.size / 2.0 - (_top_left() + target)
	var box := _box_of(_place_parts(zoom, _top_left()))
	if keep.has_area() and keep.encloses(box):
		shift.x = clampf(shift.x, keep.position.x - box.position.x, keep.end.x - box.end.x)
		shift.y = clampf(shift.y, keep.position.y - box.position.y, keep.end.y - box.end.y)
	set_pan(pan + shift)


## Every place on the map's footprint, pin and label at zoom `z`, in the
## zoomed picture's pixels, moved by `offset`.
func _place_parts(z: float, offset := Vector2.ZERO) -> Array:
	var shown := _fit.size * z
	if _labels_for != shown:
		_label_rects = model.layout_labels(shown, _measure_plate)
		_labels_for = shown
	var parts: Array = []
	for p in model.map_places():
		var footprint: Rect2 = p["footprint"]
		var top_left := model.to_map(footprint.position, shown)
		parts.append(Rect2(top_left + offset, model.to_map(footprint.end, shown) - top_left))
		if p["category"] != "":
			var pin := MapModel.pin_rect(model.to_map(p["centre"], shown), theme_map.pin)
			parts.append(Rect2(pin.position + offset, pin.size))
		if _label_rects.has(p["id"]):
			var label: Rect2 = _label_rects[p["id"]]
			parts.append(Rect2(label.position + offset, label.size))
	return parts


## The box round `rects`.
static func _box_of(rects: Array) -> Rect2:
	var box := Rect2()
	for i in rects.size():
		box = rects[i] if i == 0 else box.merge(rects[i])
	return box


# ---- Every frame ----

func _process(delta: float) -> void:
	tick(delta)


## Advances the map by `delta` seconds: the wait for a picture, the held
## stick and triggers, the pulse, and "you are here".
func tick(delta: float) -> void:
	if not _built:
		return
	_tick_base(delta)
	_tick_notice(delta)
	var zooming := _trigger_in - _trigger_out
	if zooming != 0.0:
		set_zoom(zoom + zooming * ZOOM_RATE * delta)
	if _stick != Vector2.ZERO:
		_keep_framing = false
		set_pan(pan - _stick * PAN_SPEED * delta)
	_pulse_t += delta
	_place_you()
	if model != null and model.selected != _shown_selected:
		_on_selection_changed()
	if _scroll_frames > 0:
		_scroll_frames -= 1
		_scroll_to_selected()


func _place_you() -> void:
	if you == null or model == null or _fit.size.x <= 0.0:
		you_marker.visible = false
		return
	you_marker.visible = true
	var at := _top_left() + model.to_map(you, _fit.size * zoom)
	you_marker.position = at - you_marker.size / 2.0
	you_marker.rotation = Vector2.UP.angle_to(you_facing) if you_facing != Vector2.ZERO else 0.0
	var calm := host != null and host.calm
	var pulse := 0.0 if calm else pingpong(_pulse_t, PULSE_S) / PULSE_S
	you_marker.scale = Vector2.ONE * (1.0 + (PULSE_SCALE - 1.0) * pulse)


# ---- Layout ----

## Lays the window out: the tabs and legend along the top (the legend on a
## row of its own when narrow), the hints along the bottom, and between
## them the map with the card at its right, or, when narrow, under it; on
## the List tab, the list with the card under it. The card's place is kept
## whether or not it shows, so nothing moves when a place is selected.
func _layout() -> void:
	if not _built or ui == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var width := size.x
	var tabs_size := tabs.get_combined_minimum_size()
	var legend_size := legend.get_combined_minimum_size()
	var top := MARGIN
	var bottom_of_top: float
	if narrow:
		tabs.position = Vector2(MARGIN, top)
		legend.position = Vector2(MARGIN, top + tabs_size.y + 8.0)
		bottom_of_top = legend.position.y + legend_size.y
	else:
		var bar := maxf(tabs_size.y, legend_size.y)
		tabs.position = Vector2(MARGIN, top + (bar - tabs_size.y) / 2.0)
		legend.position = Vector2(width - MARGIN - legend_size.x, top + (bar - legend_size.y) / 2.0)
		bottom_of_top = top + bar
	tabs.size = tabs_size
	legend.size = legend_size

	_fit_hints(width - 2.0 * MARGIN - _chip_padding())
	var hints_size := hints_chip.get_combined_minimum_size()
	hints_chip.size = hints_size
	hints_chip.position = Vector2((width - hints_size.x) / 2.0, size.y - MARGIN - hints_size.y)

	var content := Rect2(MARGIN, bottom_of_top + GAP, width - 2.0 * MARGIN,
		hints_chip.position.y - GAP - (bottom_of_top + GAP))
	var card_height := card.get_combined_minimum_size().y
	if not card_trams.visible and tab == "map":
		# On the map, room is kept for a tram stop's line, so the map never
		# moves when one is selected. The list keeps its rows instead, and
		# makes room when a stop's card needs it (see _fill_card).
		card_height += card_trams.get_combined_minimum_size().y + CARD_SEPARATION
	var area := content
	if tab == "map":
		if narrow:
			area.size.y -= card_height + GAP
			card.position = Vector2(content.position.x, area.end.y + GAP)
			card.size = Vector2(content.size.x, card_height)
		else:
			area.size.x -= _card_width + GAP
			card.position = Vector2(area.end.x + GAP, content.position.y)
			card.size = Vector2(_card_width, card_height)
		map_area.position = area.position
		map_area.size = area.size
		if _fit_base(area.size) and _keep_framing:
			_frame_places()
	else:
		var list_width := content.size.x if narrow else minf(LIST_WIDTH, content.size.x)
		var list := Rect2(content.position.x + (content.size.x - list_width) / 2.0, content.position.y,
			list_width, content.size.y - card_height - GAP)
		if narrow or _rows_room(list.size.y) >= LIST_MIN_ROWS:
			card.position = Vector2(list.position.x, list.end.y + GAP)
			card.size = Vector2(list_width, card_height)
		else:
			# Too short for the card under the list (a large skin at 720 px):
			# the card goes beside it, both centred, and the list takes the
			# whole height.
			list_width = minf(LIST_WIDTH, content.size.x - _card_width - GAP)
			var left := content.position.x + (content.size.x - list_width - GAP - _card_width) / 2.0
			list = Rect2(left, content.position.y, list_width, content.size.y)
			card.position = Vector2(list.end.x + GAP, content.position.y)
			card.size = Vector2(_card_width, card_height)
		list_panel.position = list.position
		list_panel.size = list.size
		area = list
	# The notice at the top of the map, or of the list.
	if notice_chip.visible:
		var chip_size := notice_chip.get_combined_minimum_size()
		chip_size.x = minf(chip_size.x, area.size.x - 2.0 * INSET)
		notice_chip.size = chip_size
		notice_chip.position = Vector2(area.position.x + (area.size.x - chip_size.x) / 2.0, area.position.y + INSET)
	_place_overlay()
	_regrow_base()


## How many rows a list panel `height` pixels tall shows whole: its height
## less the panel's own (its edges, margins and search field), over a row
## and the gap after it.
func _rows_room(height: float) -> int:
	var separation := float(rows.get_theme_constant("separation"))
	var row_height := 44.0
	if rows.get_child_count() > 0:
		row_height = (rows.get_child(0) as Control).get_combined_minimum_size().y
	var room := height - list_panel.get_combined_minimum_size().y
	return floori((room + separation) / (row_height + separation))


## The hints on one line when they fit in `room` pixels, else on two.
func _fit_hints(room: float) -> void:
	var one := "  ·  ".join(_hint_parts)
	var font := hints.get_theme_font("font")
	var font_size := hints.get_theme_font_size("font_size")
	if font.get_string_size(one, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= room:
		hints.text = one
		return
	var half := ceili(_hint_parts.size() / 2.0)
	hints.text = "  ·  ".join(_hint_parts.slice(0, half)) + "\n" + "  ·  ".join(_hint_parts.slice(half))


## What the hints chip adds round its text, left and right: its panel's
## margins and its own.
func _chip_padding() -> float:
	var box := hints_chip.get_theme_stylebox("panel")
	return (box.get_minimum_size().x if box != null else 0.0) + 28.0


## Fits the district's extent into the map area, centred, keeping its
## aspect: the picture's place at zoom 1. True when that place's size
## changed.
func _fit_base(area: Vector2) -> bool:
	if model == null or model.extent.size.x <= 0.0 or model.extent.size.y <= 0.0:
		_fit = Rect2(Vector2.ZERO, area)
		return false
	var k := minf(area.x / model.extent.size.x, area.y / model.extent.size.y)
	var fitted := model.extent.size * maxf(k, 0.0)
	var old := _fit.size
	_fit = Rect2((area - fitted) / 2.0, fitted)
	if old != _fit.size:
		_labels_for = Vector2(-1, -1)
		set_pan(pan)
		return true
	return false


## Places the picture, the pins, the labels, "you are here", the compass
## and the scale bar for the zoom and pan now.
func _place_overlay() -> void:
	if not _built or model == null or _fit.size.x <= 0.0:
		return
	var shown := _fit.size * zoom
	var top_left := _top_left()
	base.position = top_left
	base.size = shown
	route_layer.position = top_left
	route_layer.size = shown
	route_layer.lines = model.routes.map(func(r): return r["points"].map(func(p): return model.to_map(p, shown)))
	route_layer.queue_redraw()
	var visible_ids := {}
	for p in model.map_places():
		visible_ids[p["id"]] = true
	for id in _pins:
		var pin: MapPin = _pins[id]
		pin.position = top_left + MapModel.pin_rect(model.to_map(model.place(id)["centre"], shown), theme_map.pin).position
		pin.visible = visible_ids.has(id)
	if _labels_for != shown:
		_label_rects = model.layout_labels(shown, _measure_plate)
		_labels_for = shown
	for id in _labels:
		var plate: PanelContainer = _labels[id]
		var r = _label_rects.get(id)
		plate.visible = r != null and visible_ids.has(id)
		if plate.visible:
			plate.position = top_left + r.position
			plate.size = r.size
	_place_you()
	compass.position = Vector2(_fit.end.x - COMPASS_SIZE.x - INSET, _fit.position.y + INSET)
	scale_bar.visible = theme_map.scale_bar
	if scale_bar.visible:
		scale_bar.length_px = SCALE_BAR_M * shown.x / model.extent.size.x
		scale_bar.update_minimum_size()
		scale_bar.size = scale_bar.get_combined_minimum_size()
		scale_bar.position = Vector2(_fit.position.x + INSET, _fit.end.y - scale_bar.size.y - INSET)
		scale_bar.queue_redraw()


## A label plate's size for a place's name: the plate as built, so the
## layout and the plates drawn always agree.
func _measure_plate(text: String) -> Vector2:
	for id in _labels:
		var plate: PanelContainer = _labels[id]
		if plate.get_meta("place_name") == text:
			return plate.get_combined_minimum_size()
	return Vector2.ZERO


# ---- The card, the list and the hints ----

func _refresh_card() -> void:
	if not _built or model == null:
		return
	var p := model.place(model.selected)
	card.visible = not p.is_empty()
	if p.is_empty():
		card.set_meta("summary", "")
		return
	_fill_card(p)
	# A display selected is read, not gone to.
	if ui != null:
		go_button.text = ui.case("Read" if model.things.has(model.selected) else "Go")


## Fills the card's lines for `p`; also run once at build, so the card's
## height (which the layout keeps room for) is known from the start.
func _fill_card(p: Dictionary) -> void:
	var category: String = p["category"]
	card_name.text = p["name"]
	card_icon.texture = icon(category)
	card_icon.visible = category != ""
	card_icon.modulate = MapModel.COLOURS.get(category, Color.WHITE)
	card_word.text = category_word(category)
	card_rooms.text = "Rooms: " + ", ".join(p["rooms"].map(func(r): return r["name"]))
	card_inside.text = inside_text(MapModel.occupancy(projection, p))
	var trams := model.next_trams(p) if model != null else ""
	var was_shown := card_trams.visible
	card_trams.visible = trams != ""
	card_trams.text = trams if trams != "" else TRAMS_SAMPLE
	var lines := [card_name.text, card_word.text, card_rooms.text, card_inside.text]
	if trams != "":
		lines.append(trams)
	card.set_meta("summary", "\n".join(lines))
	if _opened and tab == "list" and was_shown != card_trams.visible:
		_layout()


## Wide enough for every place's name and rooms in the skin's fonts,
## within CARD_WIDTH and CARD_MAX_WIDTH.
func _fit_card_width() -> float:
	if model == null:
		return CARD_WIDTH
	var body := ui.body_font
	var body_size := ui.font_size(int(ui.spec.get("text_size", 20)))
	var widest := 0.0
	for p in model.places:
		var rooms := "Rooms: " + ", ".join(p["rooms"].map(func(r): return r["name"]))
		widest = maxf(widest, body.get_string_size(rooms, HORIZONTAL_ALIGNMENT_LEFT, -1, body_size).x)
		widest = maxf(widest, ui.display_font.get_string_size(p["name"], HORIZONTAL_ALIGNMENT_LEFT, -1,
			ui.display_size(CARD_NAME_SIZE)).x)
	var box := card.get_theme_stylebox("panel")
	var padding := 32.0 + (box.get_minimum_size().x if box != null else 0.0)
	return clampf(ceilf(widest + padding), CARD_WIDTH, CARD_MAX_WIDTH)


## "2 people inside", or "1 person inside".
static func inside_text(n: int) -> String:
	return "%d %s inside" % [n, "person" if n == 1 else "people"]


## The List tab's rows, one per place shown (by filter and search), in the
## model's order: icon, name, category and how many are inside; under each,
## a row per display in it to read (see _thing_row_text). With none, "No
## places match". Built again only when the filter or search changed,
## while the List tab shows (a projection changes the counts in place).
func _rebuild_rows() -> void:
	if not _built or model == null:
		return
	_rows_stale = false
	for row in rows.get_children():
		row.free()
	_rows.clear()
	var shown := model.visible_places()
	no_match.visible = shown.is_empty()
	rows_scroll.visible = not shown.is_empty()
	for p in model.list_rows():
		var id: String = p["id"]
		var thing := model.things.has(id)
		var row := Button.new()
		row.name = node_name("Row_", id)
		row.toggle_mode = true
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = _thing_row_text(p) if thing else _row_text(p)
		row.add_child(_row_mark("" if thing else p["category"]))
		if thing:
			row.set_meta("thing", true)
			row.get_node("IconPlate").visible = false
		row.set_pressed_no_signal(id == model.selected)
		row.pressed.connect(_on_row_pressed.bind(id))
		if ui != null:
			_style_row(row, model.place(id)["category"])
		rows.add_child(row)
		_rows[id] = row


## A click on a row selects its place or display; a click on a display's
## row already selected reads it.
func _on_row_pressed(id: String) -> void:
	if model.things.has(id) and model.selected == id:
		_on_selection_changed()
		press_go()
		return
	select(id)


## A display's row, the text layer of what it shows: its kind's name, its
## panel's title (or that it shows nothing yet), and "Sample" for sample
## content.
static func _thing_row_text(t: Dictionary) -> String:
	var shows := str(t["title"]) if str(t["title"]) != "" else PanelScreen.NOTHING_TO_READ
	return "%s   ·   %s%s" % [t["name"], shows, "   ·   " + Surfaces.SAMPLE if t["sample"] else ""]


## A row's text: its name, category and how many are inside.
func _row_text(p: Dictionary) -> String:
	return "%s   ·   %s   ·   %d inside" % [p["name"], category_word(p["category"]), MapModel.occupancy(projection, p)]


## The rows' counts, from the latest projection, on the rows there are.
func _refresh_counts() -> void:
	for id in _rows:
		var row: Button = _rows[id]
		if is_instance_valid(row) and not model.things.has(id):
			row.text = _row_text(model.place(id))


## A row's category mark: its icon in the category's colour on a small
## plate of the panel's colour at the row's left, so it keeps that colour
## on a row marked with the accent. A place with no category has an empty
## plate, keeping the names in line.
func _row_mark(category: String) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.name = "IconPlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := TextureRect.new()
	mark.name = "Icon"
	mark.texture = icon(category)
	mark.self_modulate = MapModel.COLOURS.get(category, Color.WHITE)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2.ONE * ROW_ICON_PX
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(mark)
	plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, ROW_PADDING)
	return plate


## The keys and buttons for this tab, in the device's glyphs.
func _update_hints() -> void:
	if hints == null:
		return
	var pad := glyphs != null and glyphs.device == "pad"
	var close := glyphs.label("map") if glyphs != null and glyphs.label("map") != "" else ("LS" if pad else "M")
	var parts: Array
	if pad:
		parts = ["D-pad Select", "A Go", "Y " + ("List" if tab == "map" else "Map"), "X Filter"]
		if tab == "map":
			parts += ["LT RT Zoom", "Left stick Pan"]
		parts += [close + " Close", "B Back"]
	elif tab == "map":
		parts = ["Arrows Select", "Enter Go", "Tab List", "1–4 Filter", "+ − Zoom", "Drag Pan", close + " Close", "Esc Back"]
	else:
		parts = ["↑ ↓ Select", "Enter Go", "Tab Map", "Type to search", "Esc Back"]
	_hint_parts = parts
	hints.text = "  ·  ".join(parts)
	if _built and ui != null:
		_layout()


# ---- The skin ----

func restyle() -> void:
	backdrop.color = theme_map.letterbox
	if model != null:
		model.pin = theme_map.pin
	# Pixel art's base is a plan of whole pixels, kept sharp; the others'
	# are renders, smoothed as they scale.
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if ui.spec.get("pixel_font", false) else CanvasItem.TEXTURE_FILTER_LINEAR
	var height := float(ui.spec.get("button", {}).get("height", 48))
	tabs.set_tab_title(0, ui.case("Map"))
	tabs.set_tab_title(1, ui.case("List"))
	_style_legend()
	for id in _labels:
		var plate: PanelContainer = _labels[id]
		var text: Label = plate.get_node("Text")
		text.text = theme_map.plate_text(plate.get_meta("place_name"))
		text.add_theme_font_override("font", ui.body_font)
		text.add_theme_font_size_override("font_size", ui.font_size(PLATE_TEXT_SIZE))
		text.add_theme_color_override("font_color", theme_map.plate_ink)
		_style_plate(id)
	_labels_for = Vector2(-1, -1)
	for id in _pins:
		var pin: MapPin = _pins[id]
		pin.shape = theme_map.pin
		pin.glow = theme_map.glow
		pin.ring = ui.colour("focus")
		pin.queue_redraw()
	compass.fill = theme_map.plate_fill
	compass.ink = theme_map.plate_ink
	compass.font = ui.body_font
	compass.font_size = ui.font_size(SMALL_TEXT_SIZE)
	compass.queue_redraw()
	scale_bar.fill = theme_map.plate_fill
	scale_bar.ink = theme_map.plate_ink
	scale_bar.font = ui.body_font
	scale_bar.font_size = ui.font_size(SMALL_TEXT_SIZE)
	scale_bar.label = "%d m" % int(SCALE_BAR_M)
	card_name.add_theme_font_override("font", ui.display_font)
	card_name.add_theme_font_size_override("font_size", ui.display_size(CARD_NAME_SIZE))
	card_fixture.add_theme_color_override("font_color", ui.colour("ink_muted"))
	card_fixture.add_theme_font_size_override("font_size", ui.font_size(SMALL_TEXT_SIZE))
	_card_width = _fit_card_width()
	go_button.text = ui.case("Go")
	go_button.custom_minimum_size = Vector2(160, height)
	go_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	search.placeholder_text = "Search places"
	search.custom_minimum_size.y = height
	# The skin's field has no room inside its edge; the text keeps clear of
	# the focus ring.
	for state in ["normal", "focus"]:
		var box: StyleBox = ui.theme.get_stylebox(state, "LineEdit").duplicate()
		box.content_margin_left = 12
		box.content_margin_right = 12
		search.add_theme_stylebox_override(state, box)
	no_match.add_theme_color_override("font_color", ui.colour("ink_muted"))
	hints.add_theme_color_override("font_color", ui.colour("ink_muted"))
	hints.add_theme_font_size_override("font_size", ui.font_size(16))
	notice_label.add_theme_color_override("font_color", ui.colour("ink"))
	notice_label.add_theme_font_size_override("font_size", ui.font_size(18))
	for id in _rows:
		_style_row(_rows[id], model.place(id)["category"])
	_update_hints()
	_layout()
	_on_selection_changed()


## A legend entry: the category's icon in its colour on a panel-coloured
## button; the entry filtered to is tinted with its colour and edged in it.
func _style_legend() -> void:
	var radius := ui.button_radius()
	for b in legend.get_children():
		var category := str(b.name)
		var colour: Color = MapModel.COLOURS[category]
		var on := model != null and model.filter == category
		var fill := ui.colour("panel").lerp(colour, 0.25) if on else ui.colour("panel")
		var normal := _flat_box(fill, colour if on else ui.colour("panel_edge"), 3 if on else 1, radius, Vector2(12, 6))
		var hover := _flat_box(fill.lerp(colour, 0.12), colour if on else ui.colour("panel_edge"), 3 if on else 1, radius, Vector2(12, 6))
		for state in ["normal", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("hover_pressed", hover)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(state, ui.colour("ink"))
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(state, colour)
		b.add_theme_constant_override("icon_max_width", 24)
		b.text = ui.case(category_word(category))
		b.custom_minimum_size.y = float(ui.spec.get("button", {}).get("height", 48))


## A row: on the panel, marked with the accent and edged in the focus
## colour when selected (a dark skin's accent is close to its panel). Its
## category mark stays on its panel-coloured plate either way, so the
## category's colour never changes.
func _style_row(row: Button, _category: String) -> void:
	var radius := ui.button_radius()
	# The text starts after the mark's plate.
	var padding := Vector2(ROW_PADDING, 8)
	var normal := _flat_box(ui.colour("panel"), ui.colour("panel_edge"), 1, radius, padding)
	var hover := _flat_box(ui.colour("panel").darkened(0.05), ui.colour("panel_edge"), 1, radius, padding)
	var marked := _flat_box(ui.colour("accent"), ui.colour("focus"), 2, radius, padding)
	var text_left := ROW_PADDING + ROW_ICON_PX + 2.0 * ROW_PLATE_PADDING + ROW_PADDING
	# A display's row is set in under its place's name.
	if row.has_meta("thing"):
		text_left += ROW_ICON_PX
	for box in [normal, hover, marked]:
		box.content_margin_left = text_left
	row.add_theme_stylebox_override("normal", normal)
	row.add_theme_stylebox_override("hover", hover)
	row.add_theme_stylebox_override("pressed", marked)
	row.add_theme_stylebox_override("hover_pressed", marked)
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		row.add_theme_color_override(state, ui.colour("ink"))
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		row.add_theme_color_override(state, ui.colour("accent_ink"))
	var plate: PanelContainer = row.get_node("IconPlate")
	plate.add_theme_stylebox_override("panel", _flat_box(ui.colour("panel"), ui.colour("panel"), 0,
		mini(radius, int(ROW_PLATE_PADDING) + 2), Vector2.ONE * ROW_PLATE_PADDING))
	row.custom_minimum_size.y = 44


## A place's label plate in the style's plate colours, edged in the focus
## colour when its place is selected, with a halo when the style glows.
func _style_plate(id: String) -> void:
	var plate: PanelContainer = _labels[id]
	var selected := model != null and id == model.selected
	var box := _flat_box(theme_map.plate_fill, ui.colour("focus"), 2 if selected else 0, theme_map.plate_radius, Vector2(8, 3))
	if theme_map.glow:
		box.shadow_color = Color(theme_map.plate_ink, 0.35)
		box.shadow_size = 8
	plate.add_theme_stylebox_override("panel", box)


static func _flat_box(fill: Color, edge: Color, border: int, radius: int, padding: Vector2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding.x
	box.content_margin_right = padding.x
	box.content_margin_top = padding.y
	box.content_margin_bottom = padding.y
	return box


# ---- What is drawn on the map ----

## A place's pin: its category's badge, in the category's fixed colour with
## its white icon, on the shape the style chooses: a round `badge`, a
## teardrop `drop` whose tip is at the foot of the pin (placed on the place,
## MapModel.pin_rect), or a pixel-grid `square`. The selected place's pin is
## ringed in the skin's focus colour.
class MapPin extends Control:
	var colour := Color.WHITE
	var icon: Texture2D
	var shape := "badge"
	var glow := false
	var selected := false
	var ring := Color.WHITE

	func _draw() -> void:
		var centre := size / 2.0
		var radius := size.x / 2.0
		match shape:
			"drop":
				_draw_drop(radius)
			"square":
				_draw_square()
			_:
				if glow:
					for i in 4:
						draw_circle(centre, radius + 2.0 + i * 3.0, Color(colour, 0.12))
				if selected:
					draw_circle(centre, radius + 5.0, ring)
				draw_circle(centre, radius, Color.WHITE)
				draw_circle(centre, radius - 3.0, colour)
				_draw_icon(centre, radius * 1.1)

	## A teardrop: a round head over a point at the pin's foot.
	func _draw_drop(radius: float) -> void:
		var head_radius := radius * 0.7
		var head := Vector2(size.x / 2.0, head_radius + 1.0)
		var tip := Vector2(size.x / 2.0, size.y)
		if glow:
			for i in 4:
				draw_circle(head, head_radius + 3.0 + i * 3.0, Color(colour, 0.12))
		if selected:
			draw_colored_polygon(_drop_points(head, tip, head_radius + 5.0), ring)
		draw_colored_polygon(_drop_points(head, tip, head_radius + 2.5), Color.WHITE)
		draw_colored_polygon(_drop_points(head, tip - Vector2(0, 3), head_radius), colour)
		_draw_icon(head, head_radius * 1.3)

	func _drop_points(head: Vector2, tip: Vector2, r: float) -> PackedVector2Array:
		var d := head.distance_to(tip)
		var spread := acos(clampf(r / d, -1.0, 1.0))
		var points := PackedVector2Array([tip])
		var start := PI / 2.0 - spread
		var finish := PI / 2.0 + spread - TAU
		for i in 25:
			var a := lerpf(start, finish, i / 24.0)
			points.append(head + Vector2(cos(a), sin(a)) * r)
		return points

	## A square badge with its corners stepped off, as a pixel sprite's are.
	func _draw_square() -> void:
		var w := size.x
		var h := size.y
		var edge := Color(0.05, 0.06, 0.12)
		if glow or selected:
			var halo := ring if selected else Color(colour, 0.3)
			draw_rect(Rect2(-4, -2, w + 8, h + 4), halo)
			draw_rect(Rect2(-2, -4, w + 4, h + 8), halo)
		draw_rect(Rect2(2, 0, w - 4, h), edge)
		draw_rect(Rect2(0, 2, w, h - 4), edge)
		draw_rect(Rect2(4, 2, w - 8, h - 4), colour)
		draw_rect(Rect2(2, 4, w - 4, h - 8), colour)
		draw_rect(Rect2(4, 2, w - 8, 2), colour.lightened(0.3))
		_draw_icon(size / 2.0, w * 0.55)

	func _draw_icon(centre: Vector2, side: float) -> void:
		if icon != null:
			draw_texture_rect(icon, Rect2(centre - Vector2.ONE * side / 2.0, Vector2.ONE * side), false)


## The transit lines' routes: each a polyline of map points (in this
## control's own frame, which is the picture's), drawn in the Transit
## colour on a pale casing so it reads over any style's picture.
class MapRoute extends Control:
	var colour := Color.WHITE
	var lines: Array = []
	const WIDTH := 6.0
	const CASING := 3.0

	func _draw() -> void:
		for line in lines:
			if line.size() < 2:
				continue
			var points := PackedVector2Array(line)
			draw_polyline(points, Color(1, 1, 1, 0.85), WIDTH + 2.0 * CASING, true)
			draw_polyline(points, colour, WIDTH, true)


## North, as the sheets draw it: an N over a round plate whose arrow points
## up the map.
class MapCompass extends Control:
	var fill := Color.WHITE
	var ink := Color.BLACK
	var font: Font
	var font_size := 14

	func _draw() -> void:
		var w := size.x
		var centre := Vector2(w / 2.0, size.y - w / 2.0)
		var radius := w / 2.0 - 1.0
		draw_circle(centre, radius, fill)
		draw_arc(centre, radius, 0.0, TAU, 48, Color(ink, 0.35), 1.5, true)
		var half := radius * 0.4
		var north := PackedVector2Array([centre + Vector2(0, -radius + 4), centre + Vector2(half, 0), centre + Vector2(-half, 0)])
		var south := PackedVector2Array([centre + Vector2(0, radius - 4), centre + Vector2(-half, 0), centre + Vector2(half, 0)])
		draw_colored_polygon(north, ink)
		draw_colored_polygon(south, Color(ink, 0.3))
		if font != null:
			var text_size := font.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var plate := Rect2(Vector2((w - text_size.x) / 2.0 - 4.0, 0), Vector2(text_size.x + 8.0, text_size.y))
			draw_rect(plate, fill)
			draw_string(font, Vector2(plate.position.x + 4.0, font.get_ascent(font_size)), "N",
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## A bar `length_px` long for SCALE_BAR_M metres, with its label, on a plate.
class MapScaleBar extends Control:
	var fill := Color.WHITE
	var ink := Color.BLACK
	var font: Font
	var font_size := 14
	var label := ""
	var length_px := 100.0
	const PAD := 8.0

	func _get_minimum_size() -> Vector2:
		var text_h := font.get_height(font_size) if font != null else 16.0
		return Vector2(length_px + 2.0 * PAD, text_h + 2.0 * PAD + 8.0)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(fill, 0.9))
		var y := size.y - PAD - 3.0
		draw_rect(Rect2(PAD, y, length_px, 3.0), ink)
		draw_rect(Rect2(PAD, y - 6.0, 2.0, 9.0), ink)
		draw_rect(Rect2(PAD + length_px - 2.0, y - 6.0, 2.0, 9.0), ink)
		if font != null:
			draw_string(font, Vector2(PAD, PAD + font.get_ascent(font_size)), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
