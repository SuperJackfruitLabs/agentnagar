## The style picker, opened from the game menu: a grid of cards, one per
## visual style, each with its preview image and its name, three to a row
## (two, smaller, in the narrow layout). Choosing a card
## emits `chosen` and leaves the picker open; main switches the style live,
## the stack reskins every screen, and focus stays on the chosen card. It
## draws no scrim of its own: it opens over the game menu, whose scrim
## already dims the world, and a second one would hide the city the player
## is choosing a look for.
extends Screen
class_name StylePicker

const COLUMNS := 3
## Previews are generated at 480 x 270 (tools/style_previews.gd) and shown
## at two thirds of that.
const PREVIEW_SIZE := Vector2(320, 180)
## In the narrow layout the cards stack two to a row, their previews at
## half size, so all six fit an 800 x 900 window.
const NARROW_COLUMNS := 2
const NARROW_PREVIEW_SIZE := Vector2(240, 135)
## Space between a card's edge and what it shows.
const CARD_PADDING := 8
## How far outside a card its focus ring sits; less than half the grid's
## 16 px gaps, so rings never touch a neighbour.
const FOCUS_GAP := 6

## Fired when a card is chosen, with that style's directory.
signal chosen(dir: String)

## `[{dir, name}]`, in the styles' `order`. Set before the picker is pushed.
var styles: Array = []

## The directory of the style shown now; its card is marked, and focused
## when the picker opens.
var current := "":
	set(value):
		current = value
		_mark_current()

var grid: GridContainer
var cards: Array[Button] = []
var title: Label
var back_button: Button
## Keeps one card marked at a time.
var _group := ButtonGroup.new()


func build() -> void:
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var panel := PanelContainer.new()
	centre.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	title = Label.new()
	title.name = "Title"
	title.text = "Visual style"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	grid = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	box.add_child(grid)
	for style in styles:
		var card := _card(style)
		grid.add_child(card)
		cards.append(card)

	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = "Back"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func(): _close.call_deferred())
	box.add_child(back_button)

	_link_focus()
	_mark_current()
	for card in cards:
		if card.button_pressed:
			last_focus = card


## A card: the style's preview, or its name on the accent colour when the
## pack has none, and its name below.
func _card(style: Dictionary) -> Button:
	var dir: String = style["dir"]
	var card := Button.new()
	card.name = dir.get_file()
	card.toggle_mode = true
	card.button_group = _group
	card.pressed.connect(_choose.bind(card, dir))

	var content := VBoxContainer.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, CARD_PADDING)
	content.add_theme_constant_override("separation", CARD_PADDING)
	card.add_child(content)

	var preview_path := dir.path_join("assets/preview.png")
	if ResourceLoader.exists(preview_path):
		var preview := TextureRect.new()
		preview.name = "Preview"
		preview.texture = load(preview_path)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		preview.custom_minimum_size = PREVIEW_SIZE
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(preview)
	else:
		var slot := ColorRect.new()
		slot.name = "NoPreview"
		slot.custom_minimum_size = PREVIEW_SIZE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(slot)
		var name_on_slot := Label.new()
		name_on_slot.name = "SlotName"
		name_on_slot.text = style["name"]
		name_on_slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		name_on_slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_on_slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_on_slot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_child(name_on_slot)

	var caption := Label.new()
	caption.name = "Caption"
	caption.text = style["name"]
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(caption)
	return card


## Remembers the card, so the reskin that follows puts focus back on it,
## and asks for its style.
func _choose(card: Button, dir: String) -> void:
	last_focus = card
	chosen.emit(dir)


## Closes the picker from its own Back button, once the press is over (the
## button is freed with the screen).
func _close() -> void:
	if stack != null and stack.top() == self:
		stack.pop()


## Marks the current style's card, without firing its press: it is filled
## with the accent colour, so it never reads as the focus ring, which may
## sit on another card in the same colour.
func _mark_current() -> void:
	for i in cards.size():
		var marked: bool = styles[i]["dir"] == current
		cards[i].set_pressed_no_signal(marked)
		if ui != null:
			var caption: Label = cards[i].find_child("Caption", true, false)
			caption.add_theme_color_override("font_color", ui.colour("accent_ink" if marked else "ink"))


## The d-pad reaches every card. Left and right run along the rows and wrap
## from the end of one row to the start of the next (and from the last card
## to the first). Up and down move a row, stopping at the top; down from
## the bottom row, or from a card with nothing under it, goes to the card
## below it if any, else to Back. Up from Back returns to the first card
## of the bottom row.
func _link_focus() -> void:
	var n := cards.size()
	if n == 0:
		return
	var columns := grid.columns
	var last_row := floori((n - 1) / float(columns))
	for i in n:
		var card := cards[i]
		var row := floori(i / float(columns))
		card.focus_neighbor_left = card.get_path_to(cards[(i - 1 + n) % n])
		card.focus_neighbor_right = card.get_path_to(cards[(i + 1) % n])
		card.focus_previous = card.focus_neighbor_left
		card.focus_next = card.focus_neighbor_right
		card.focus_neighbor_top = card.get_path_to(cards[i - columns] if row > 0 else card)
		var below: Control = back_button
		if i + columns < n:
			below = cards[i + columns]
		elif row < last_row:
			below = cards[n - 1]
		card.focus_neighbor_bottom = card.get_path_to(below)
	back_button.focus_neighbor_top = back_button.get_path_to(cards[last_row * columns])
	back_button.focus_neighbor_bottom = back_button.get_path_to(back_button)
	back_button.focus_neighbor_left = back_button.get_path_to(back_button)
	back_button.focus_neighbor_right = back_button.get_path_to(back_button)
	back_button.focus_previous = back_button.focus_neighbor_top
	back_button.focus_next = back_button.get_path_to(cards[0])


func restyle() -> void:
	_fit_columns()
	title.text = ui.case("Visual style")
	title.add_theme_font_override("font", ui.display_font)
	title.add_theme_font_size_override("font_size", ui.display_size(28))
	back_button.text = ui.case("Back")
	back_button.custom_minimum_size = Vector2(160, float(ui.spec.get("button", {}).get("height", 48)))
	var normal := _card_box(ui.colour("panel"), ui.colour("panel_edge"), 1)
	var hover := _card_box(ui.colour("panel").darkened(0.06), ui.colour("panel_edge"), 1)
	var marked := _card_box(ui.colour("accent"), ui.colour("accent"), 1)
	# The skin's ring, held clear of the card's edge, so it still shows on
	# the accent-filled current card.
	var ring: StyleBox = ui.theme.get_stylebox("focus", "Button").duplicate()
	if ring is StyleBoxFlat:
		ring.set_expand_margin_all(FOCUS_GAP)
	for card in cards:
		card.add_theme_stylebox_override("normal", normal)
		card.add_theme_stylebox_override("hover", hover)
		card.add_theme_stylebox_override("pressed", marked)
		card.add_theme_stylebox_override("hover_pressed", marked)
		card.add_theme_stylebox_override("focus", ring)
		var slot = card.find_child("NoPreview", true, false)
		if slot != null:
			slot.color = ui.colour("accent")
			var name_on_slot: Label = slot.get_node("SlotName")
			name_on_slot.add_theme_color_override("font_color", ui.colour("accent_ink"))
		var content: Control = card.get_node("Content")
		card.custom_minimum_size = content.get_combined_minimum_size() + Vector2.ONE * CARD_PADDING * 2
	_mark_current()


## Three columns, or two with smaller previews in the narrow layout; the
## d-pad's links follow the grid.
func _fit_columns() -> void:
	var columns := NARROW_COLUMNS if narrow else COLUMNS
	var preview_size := NARROW_PREVIEW_SIZE if narrow else PREVIEW_SIZE
	for card in cards:
		var shown: Control = card.find_child("Preview", true, false)
		if shown == null:
			shown = card.find_child("NoPreview", true, false)
		shown.custom_minimum_size = preview_size
	if grid.columns != columns:
		grid.columns = columns
		_link_focus()


## A card's box in the skin's panel shape: rounded when the skin's panels
## are, square otherwise.
func _card_box(fill: Color, edge: Color, border: int) -> StyleBoxFlat:
	var cfg: Dictionary = ui.spec.get("panel", {})
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border)
	box.set_corner_radius_all(int(cfg.get("radius", 0)) if cfg.get("shape", "rounded") == "rounded" else 0)
	return box
