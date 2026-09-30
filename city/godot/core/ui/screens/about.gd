## The About screen, opened from the title and the game menu: the version,
## the licence (Agentnagar is free software under the GNU AGPL v3, so every
## player is offered its source: GNU AGPL section 13), a link to the
## source, and two long texts in one scrolling view, the third-party
## notices and the licence itself, switched by Q and E (LB and RB) or their
## tabs.
##
## Up and down move from the link to the text and on to Back, wrapping.
## On the text, up and down scroll it a line, and leave it only at its top
## or its end; left and right, and Page Up and Page Down, scroll it a page.
## The texts are read from the package's copies, or from the repository's
## when run from a checkout (see `CityPaths.licence_paths`); with neither,
## the view shows the engine's own notices, which Godot carries in every
## build, and says where the full ones are.
extends Screen
class_name AboutScreen

## The source repository: AGPL section 13 asks that everyone who uses the
## program is offered its source.
const REPOSITORY := "https://github.com/SuperJackfruitLabs/agentnagar"
const FREE_SOFTWARE := "Agentnagar is free software under the GNU AGPL v3."
const COPYRIGHT := "Copyright © 2026 Super Jackfruit Labs (OPC) Private Limited and contributors."
const WARRANTY := "It comes with no warranty. You may share and change it under the licence's terms, shown below. Its source:"
## The two texts the view shows, in tab order.
const VIEWS := ["Third-party notices", "Licence"]
## The staged name of each view's text (a key of CityPaths.LICENSE_FILES).
const VIEW_FILES := ["THIRD-PARTY-NOTICES.txt", "LICENSE.txt"]
## What a view shows when its file is found nowhere.
const LICENCE_MISSING := "The GNU Affero General Public License, version 3, is in the LICENSE file beside the game and in its source, and at https://www.gnu.org/licenses/agpl-3.0.html."
const NOTICES_MISSING := "The full third-party notices ship beside the game in THIRD-PARTY-NOTICES.txt and are in its source. The engine's own notices follow.\n\n"
## The panel's width, and the least room the text view keeps.
const WIDTH := 880.0
const TEXT_MIN_HEIGHT := 64.0
## The text's size, before the text-size setting.
const TEXT_SIZE := 16

var panel: PanelContainer
var title: Label
var version_label: Label
var licence_label: Label
var copyright_label: Label
var warranty_label: Label
## The repository's address, as text, for where a link cannot open.
var url_label: Label
## Opens the repository in the browser.
var source_button: Button
var tabs: TabBar
## The current view's text, scrolled by the keys and the d-pad.
var text: RichTextLabel
var hint: Label
var back_button: Button

## Where each view's text is read from, in order; tests point them at
## files of their own.
var view_paths: Array = [CityPaths.licence_paths(VIEW_FILES[0]), CityPaths.licence_paths(VIEW_FILES[1])]
## Opens a URL; tests record it instead.
var opener: Callable = func(url: String): OS.shell_open(url)
## The texts once read, per view.
var _texts := {}


func build() -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	# The panel is centred across and takes the window's height, so the
	# text gets whatever room the window has.
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size.x = WIDTH
	row.add_child(panel)
	var inner := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(inner)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	inner.add_child(box)

	title = _label(box, "Title", "About Agentnagar")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label = _label(box, "Version", version_text())
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	licence_label = _label(box, "Licence", FREE_SOFTWARE)
	copyright_label = _label(box, "Copyright", COPYRIGHT)
	warranty_label = _label(box, "Warranty", WARRANTY)
	url_label = _label(box, "Repository", source_url())
	# A long address in a wide pixel face breaks anywhere rather than
	# running off a narrow window.
	url_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY

	source_button = Button.new()
	source_button.name = "Open the source"
	source_button.text = "Open the source"
	source_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	source_button.pressed.connect(open_source)
	box.add_child(source_button)

	tabs = TabBar.new()
	tabs.name = "Views"
	tabs.focus_mode = Control.FOCUS_NONE
	tabs.tab_alignment = TabBar.ALIGNMENT_CENTER
	tabs.clip_tabs = false
	for v in VIEWS:
		tabs.add_tab(v)
	box.add_child(tabs)

	text = RichTextLabel.new()
	text.name = "Text"
	text.bbcode_enabled = false
	text.selection_enabled = false
	text.scroll_active = true
	# Laid out off the main thread: the notices run to thousands of lines.
	text.threaded = true
	text.focus_mode = Control.FOCUS_ALL
	text.custom_minimum_size.y = TEXT_MIN_HEIGHT
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.gui_input.connect(_on_text_input)
	box.add_child(text)

	hint = _label(box, "Hint", "↑ ↓ scroll · ← → a page · Q · E or LB · RB: notices or licence")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = "Back"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func(): _close.call_deferred())
	box.add_child(back_button)

	_link_focus()
	tabs.tab_changed.connect(show_view)
	show_view(0)


func _label(parent: Node, label_name: String, value: String) -> Label:
	var l := Label.new()
	l.name = label_name
	l.text = value
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


## "Version 0.0.4", from the project's `application/config/version`, which
## scripts/package.sh sets for a package; "Development build" otherwise.
static func version_text() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", ""))
	return "Version " + v if v != "" else "Development build"


## Up and down run through the link, the text and Back, wrapping; left
## and right stay put (on the text they scroll a page).
func _link_focus() -> void:
	var list: Array[Control] = [source_button, text, back_button]
	for i in list.size():
		var c := list[i]
		c.focus_neighbor_top = c.get_path_to(list[i - 1])
		c.focus_neighbor_bottom = c.get_path_to(list[(i + 1) % list.size()])
		c.focus_neighbor_left = c.get_path_to(c)
		c.focus_neighbor_right = c.get_path_to(c)
		c.focus_previous = c.focus_neighbor_top
		c.focus_next = c.focus_neighbor_bottom


## Opens this build's source in the browser.
func open_source() -> void:
	opener.call(source_url())


## Where this build's source is: the tag for a released version ("v0.0.4"
## or "0.0.4"), the commit for a version `git describe` wrote from a clean
## checkout ("v0.0.3-77-g24a43a1" or "24a43a1"), and the repository itself
## otherwise (a development build, or one made from uncommitted changes).
static func source_url(version: String = "") -> String:
	if version == "":
		version = str(ProjectSettings.get_setting("application/config/version", ""))
	var release := RegEx.create_from_string("^v?(\\d+\\.\\d+\\.\\d+)$").search(version)
	if release:
		return REPOSITORY + "/tree/v" + release.get_string(1)
	var commit := RegEx.create_from_string("^(?:.*-g)?([0-9a-f]{7,40})$").search(version)
	if commit:
		return REPOSITORY + "/tree/" + commit.get_string(1)
	return REPOSITORY


# ---- The texts ----

## Shows view `index` (0 the notices, 1 the licence) from its top.
func show_view(index: int) -> void:
	if tabs.current_tab != index:
		tabs.current_tab = index
	text.text = view_text(index)
	text.scroll_to_line(0)


## Steps to the other view, wrapping round.
func view_step(direction: int) -> void:
	show_view(posmod(tabs.current_tab + direction, VIEWS.size()))


## View `index`'s text, read once: the first of its files found, or, with
## none, what stands in for it.
func view_text(index: int) -> String:
	if not _texts.has(index):
		var found := CityPaths.read_first(view_paths[index])
		if found == "":
			found = engine_notices(NOTICES_MISSING) if index == 0 else LICENCE_MISSING
		_texts[index] = found
	return _texts[index]


## The engine's licence and its components' notices, as Godot carries them
## in every build, after `lead`.
static func engine_notices(lead := "") -> String:
	var out := lead + "Godot Engine\n\n" + Engine.get_license_text() + "\n"
	for component in Engine.get_copyright_info():
		out += "\n%s\n" % component["name"]
		for part in component["parts"]:
			for line in part["copyright"]:
				out += "  Copyright %s\n" % line
			out += "  License: %s\n" % part["license"]
	var licences := Engine.get_license_info()
	for name in licences:
		out += "\n\n---- %s ----\n\n%s\n" % [name, licences[name]]
	return out


# ---- Input ----

## Whether the text is scrolled to its top, or to its end. Asking for the
## content's height first brings the scroll bar up to date with the text
## laid out so far.
func at_top() -> bool:
	text.get_content_height()
	return text.get_v_scroll_bar().value <= 0.5


func at_end() -> bool:
	text.get_content_height()
	var bar := text.get_v_scroll_bar()
	return bar.value >= bar.max_value - bar.page - 0.5


## Scrolls the text by `pages` of its own height.
func scroll_pages(pages: float) -> void:
	scroll_by(pages * text.size.y * 0.9)


## Scrolls the text by `lines` of its face's height.
func scroll_lines(lines: float) -> void:
	var face := text.get_theme_font("normal_font")
	var step := face.get_height(text.get_theme_font_size("normal_font_size")) if face != null else 20.0
	scroll_by(lines * step)


func scroll_by(pixels: float) -> void:
	text.get_content_height()
	var bar := text.get_v_scroll_bar()
	bar.value = clampf(bar.value + pixels, 0.0, maxf(0.0, bar.max_value - bar.page))


## On the text, up and down scroll it a line (the label scrolls only for
## keys, and the d-pad must too), except that up at its top and down at
## its end move on as they do elsewhere; left and right, and Page Up and
## Page Down, scroll a page.
func _on_text_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up", true):
		if at_top():
			source_button.grab_focus()
		else:
			scroll_lines(-1.0)
	elif event.is_action_pressed("ui_down", true):
		if at_end():
			back_button.grab_focus()
		else:
			scroll_lines(1.0)
	elif event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_page_up", true):
		scroll_pages(-1.0)
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_page_down", true):
		scroll_pages(1.0)
	else:
		return
	text.accept_event()


## Q and E, or LB and RB, switch views while this screen is on top.
func _unhandled_input(event: InputEvent) -> void:
	if (stack != null and stack.top() != self) or not event.is_pressed() or event.is_echo():
		return
	var direction := 0
	if event is InputEventKey:
		match event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode:
			KEY_Q:
				direction = -1
			KEY_E:
				direction = 1
	elif event is InputEventJoypadButton:
		match event.button_index:
			JOY_BUTTON_LEFT_SHOULDER:
				direction = -1
			JOY_BUTTON_RIGHT_SHOULDER:
				direction = 1
	if direction != 0:
		view_step(direction)
		get_viewport().set_input_as_handled()


## Closes the screen from its own Back button, once the press is over (the
## stack frees it after this call: a screen cannot free itself).
func _close() -> void:
	if stack != null and stack.top() == self:
		stack.remove(self)


func restyle() -> void:
	panel.custom_minimum_size.x = minf(WIDTH, maxf(size.x - 32.0, 0.0)) if narrow else WIDTH
	title.text = ui.case("About Agentnagar")
	title.add_theme_font_override("font", ui.display_font)
	title.add_theme_font_size_override("font_size", ui.display_size(28))
	for l in [version_label, hint]:
		l.add_theme_color_override("font_color", ui.colour("ink_muted"))
	url_label.add_theme_color_override("font_color", ui.colour("accent"))
	var height := float(ui.spec.get("button", {}).get("height", 48))
	for b in [source_button, back_button]:
		b.text = ui.case(str(b.name))
		b.custom_minimum_size = Vector2(200, height)
	# Legal text reads best in a plain face: a pixel skin's face would make
	# thousands of lines hard going, so it takes the engine's own.
	var pixel: bool = ui.spec.get("pixel_font", false)
	var face: Font = ThemeDB.fallback_font if pixel else ui.body_font
	var text_size := roundi(TEXT_SIZE * ui._text_scale) if pixel else ui.font_size(TEXT_SIZE)
	for slot in ["normal_font", "mono_font"]:
		text.add_theme_font_override(slot, face)
	for slot in ["normal_font_size", "mono_font_size"]:
		text.add_theme_font_size_override(slot, text_size)
	text.add_theme_color_override("default_color", ui.colour("ink"))
	var well := StyleBoxFlat.new()
	well.bg_color = ui.colour("panel")
	well.border_color = ui.colour("panel_edge")
	well.set_border_width_all(1)
	well.set_content_margin_all(8)
	text.add_theme_stylebox_override("normal", well)
	var focused := well.duplicate()
	focused.border_color = ui.colour("focus")
	focused.set_border_width_all(2)
	text.add_theme_stylebox_override("focus", focused)
