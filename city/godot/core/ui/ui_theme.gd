## Turns a visual style's `ui` block into a Godot `Theme`. A style's
## `style.json` may leave the block out, or name only the keys it wants to
## change; `from_style` fills every gap from `DEFAULT`, so a new style has a
## usable, legible skin from day one.
extends RefCounted
class_name UiTheme

## The neutral skin, used whenever a style's `ui` block is missing a key.
## These are the values given in spec section 7's example block.
const DEFAULT := {
	"pixel_font": false,
	"pixel_base": 10,
	"text_size": 20,
	"colours": {
		"panel": "#F7F8FB", "panel_edge": "#D5DAE6",
		"ink": "#1F2433", "ink_muted": "#5A6275",
		"accent": "#2F6FD6", "accent_ink": "#FFFFFF",
		"focus": "#2F6FD6", "scrim": "#0B0F1A99",
	},
	"panel": {"shape": "rounded", "radius": 14, "border": 1, "shadow": 8},
	"button": {"shape": "rounded", "radius": 10, "case": "title", "height": 48},
	"focus": "ring",
	"frame": null,
	# The station computer's monitor bezel: its `shape` (`plain`, `crt`,
	# `glass`, or a style's own, drawn plain), frame `colour`, corner
	# `radius` and the `margin` between the frame's edge and the screen.
	"bezel": {"shape": "plain", "colour": "#2B303B", "radius": 12, "margin": 20},
}

## How far the `glow` focus halo reaches beyond the focused control, in
## pixels.
const GLOW_SPREAD := 8
## The halo's strength: the `focus` colour at this alpha.
const GLOW_ALPHA := 0.6
## Room between a frame button's text and its frame, left and right, beyond
## the frame's own margin.
const FRAME_BUTTON_PADDING := 10

## The style's `ui` block, deep-merged over `DEFAULT`.
var spec: Dictionary

## The built theme, ready to assign to a screen's `theme` property.
var theme: Theme

## Loaded from `font_display`, or `ThemeDB.fallback_font` when that resource
## is absent.
var display_font: Font

## Loaded from `font_body`, or `ThemeDB.fallback_font` when that resource is
## absent.
var body_font: Font

## The interface text-size scale (from `Settings.text_scale`), applied by
## `font_size`.
var _text_scale := 1.0


## Deep-merges `style.get("ui", {})` over `DEFAULT` and builds the theme.
static func from_style(style: Dictionary, text_scale := 1.0) -> UiTheme:
	var t := UiTheme.new()
	t._text_scale = text_scale
	t.spec = _merge(DEFAULT, style.get("ui", {}))
	t.display_font = t._load_font(t.spec.get("font_display"))
	t.body_font = t._load_font(t.spec.get("font_body"))
	t.theme = t._build_theme()
	return t


## Recursively merges `override` onto a duplicate of `base`; a dictionary
## value merges key by key, anything else replaces the default outright.
static func _merge(base: Dictionary, override: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key in override.keys():
		var value = override[key]
		if value is Dictionary and result.get(key) is Dictionary:
			result[key] = _merge(result[key], value)
		else:
			result[key] = value
	return result


func _load_font(path) -> Font:
	if path is String and not path.is_empty() and ResourceLoader.exists(path):
		var res := load(path)
		if res is Font:
			return res
	return ThemeDB.fallback_font


## A named colour from the merged `colours` block. Hex strings may carry
## alpha (`#RRGGBBAA`); `Color(hex)` accepts that directly.
func colour(name: String) -> Color:
	var v = spec.get("colours", {}).get(name)
	if v is Color:
		return v
	return Color(String(v))


## The WCAG contrast ratio between two colours: `(L1 + 0.05) / (L2 + 0.05)`,
## with L1 the lighter relative luminance and L2 the darker, both computed
## with sRGB linearisation.
static func contrast(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	var lighter := maxf(la, lb)
	var darker := minf(la, lb)
	return (lighter + 0.05) / (darker + 0.05)


static func _relative_luminance(c: Color) -> float:
	var r := _linearise(c.r)
	var g := _linearise(c.g)
	var b := _linearise(c.b)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b


static func _linearise(channel: float) -> float:
	if channel <= 0.03928:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)


## The size for body text (the body font): `round(base * text_scale)`,
## except for a pixel font, which only takes whole-number multiples of its
## grid, `pixel_base_body` (default `pixel_base`, itself default 10):
## rounding half down, so 125% of a 20 px face on a 10 px grid is still one
## step (20 px), and 150% is two steps (30 px).
func font_size(base: int) -> int:
	var grid := int(spec.get("pixel_base_body", spec.get("pixel_base", 10)))
	return _snap(base, grid)


## The size for display text (the display font: names and headings), as
## `font_size`, but a pixel font snaps to `pixel_base`, the display face's
## grid. Two pixel faces rarely share a grid.
func display_size(base: int) -> int:
	return _snap(base, int(spec.get("pixel_base", 10)))


## The face display text at `base` is drawn in: the display face, except
## in a pixel-font style where that face would come out at a single step
## of its grid, too small to read, and the overlay's body face takes it
## (the integration plan's "whole-number scales, falling back to the
## overlay face for small text").
func heading_font(base: int) -> Font:
	return body_font if _heading_falls_back(base) else display_font


## The size display text at `base` is drawn at, in heading_font's face: on
## the display face's grid, or the body face's where it falls back.
func heading_size(base: int) -> int:
	return font_size(base) if _heading_falls_back(base) else display_size(base)


func _heading_falls_back(base: int) -> bool:
	return spec.get("pixel_font", false) and display_size(base) < 2 * int(spec.get("pixel_base", 10))


func _snap(base: int, grid: int) -> int:
	if spec.get("pixel_font", false):
		var steps := maxi(1, int(floor(base * _text_scale / float(grid) + 0.49)))
		return grid * steps
	return int(round(base * _text_scale))


## Applies `button.case`: `upper` shouts the text, anything else (`title`)
## letters it the way the sheets do, one capital per word.
func case(text: String) -> String:
	var mode: String = spec.get("button", {}).get("case", "title")
	if mode == "upper":
		return text.to_upper()
	return text.capitalize()


## The station computer's bezel, as `DEFAULT`'s `bezel` merged under the
## style's: {shape, colour, radius, margin}.
func bezel() -> Dictionary:
	return spec.get("bezel", DEFAULT["bezel"])


## `ring`, `glow` or `underline`, from the style's `focus` key.
func focus_mode() -> String:
	return spec.get("focus", "ring")


## The `glow` halo's colour: `focus` at `GLOW_ALPHA`.
func glow_colour() -> Color:
	var c := colour("focus")
	return Color(c.r, c.g, c.b, GLOW_ALPHA)


## The corner radius a button is drawn with, so the halo can follow it:
## `button.radius` for a rounded button, otherwise square.
func button_radius() -> int:
	var cfg: Dictionary = spec.get("button", {})
	if cfg.get("shape", "rounded") == "rounded":
		return int(cfg.get("radius", 0))
	return 0


func _build_theme() -> Theme:
	var th := Theme.new()

	th.default_font = body_font
	th.default_font_size = font_size(int(spec.get("text_size", 20)))

	var panel_sb := _shape_stylebox(spec.get("panel", {}), colour("panel"), colour("panel_edge"))
	th.set_stylebox("panel", "PanelContainer", panel_sb)
	th.set_stylebox("panel", "Panel", panel_sb)

	_apply_button_theme(th)
	_apply_label_theme(th)
	_apply_line_edit_theme(th)
	_apply_option_button_theme(th)
	_apply_check_button_theme(th)
	_apply_h_slider_theme(th)
	_apply_tab_theme(th)

	return th


## Builds a stylebox for a `panel`- or `button`-shaped config: `rounded` and
## `square` are flat boxes, `nine` is a nine-slice texture from `frame` (with
## a flat fallback when no frame is configured).
func _shape_stylebox(cfg: Dictionary, bg: Color, border: Color) -> StyleBox:
	var shape: String = cfg.get("shape", "rounded")
	if shape == "nine":
		var nine := _nine_stylebox()
		if nine != null:
			return nine
		shape = "square"

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	var radius := 0
	if shape == "rounded":
		radius = int(cfg.get("radius", 0))
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius

	var border_width := int(cfg.get("border", 0))
	if border_width > 0:
		sb.border_width_left = border_width
		sb.border_width_top = border_width
		sb.border_width_right = border_width
		sb.border_width_bottom = border_width
		sb.border_color = border

	var shadow := int(cfg.get("shadow", 0))
	if shadow > 0:
		sb.shadow_size = shadow
		sb.shadow_color = colour("scrim")

	return sb


## A `StyleBoxTexture` nine-slice from `frame.texture`, with `frame.margin`
## on all four sides. `null` when no frame is configured, or its texture is
## missing, so the caller can fall back to a flat box instead. A stylebox
## has no filter of its own: the frame is drawn with the canvas's, which the
## project sets to nearest, so a pixel frame stays crisp.
func _nine_stylebox() -> StyleBoxTexture:
	var frame = spec.get("frame")
	if frame == null or not (frame is Dictionary):
		return null
	var path = frame.get("texture")
	if not (path is String) or path.is_empty() or not ResourceLoader.exists(path):
		return null
	var tex := load(path)
	if not (tex is Texture2D):
		return null

	var sbt := StyleBoxTexture.new()
	sbt.texture = tex
	var margin := int(frame.get("margin", 0))
	sbt.texture_margin_left = margin
	sbt.texture_margin_top = margin
	sbt.texture_margin_right = margin
	sbt.texture_margin_bottom = margin
	return sbt


## The tint that turns a nine-slice frame's field (the `panel` colour) into
## `accent`, channel by channel: a frame button lit up. Over 1 is allowed,
## since a modulate brightens as well as darkens.
func _lit_modulate() -> Color:
	var field := colour("panel")
	var accent := colour("accent")
	return Color(
		accent.r / maxf(field.r, 0.01),
		accent.g / maxf(field.g, 0.01),
		accent.b / maxf(field.b, 0.01))


## The shared focus stylebox: a transparent `StyleBoxFlat` with a 3 px
## border in `focus`, expanded 2 px outside the control, its corners
## following a rounded button's. `underline` draws only the bottom border.
func _focus_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	var radius := button_radius()
	if radius > 0:
		sb.set_corner_radius_all(radius + 2)
	sb.expand_margin_left = 2
	sb.expand_margin_top = 2
	sb.expand_margin_right = 2
	sb.expand_margin_bottom = 2
	sb.border_color = colour("focus")
	if focus_mode() == "underline":
		sb.border_width_bottom = 3
	else:
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
		sb.border_width_bottom = 3
	return sb


func _apply_button_theme(th: Theme) -> void:
	var cfg: Dictionary = spec.get("button", {})
	var accent := colour("accent")
	var accent_ink := colour("accent_ink")
	var ink_muted := colour("ink_muted")

	var normal := _shape_stylebox(cfg, accent, colour("panel_edge"))
	var hover := _shape_stylebox(cfg, accent.lightened(0.12), colour("panel_edge"))
	var pressed := _shape_stylebox(cfg, accent.darkened(0.12), colour("panel_edge"))
	var disabled := _shape_stylebox(cfg, colour("panel_edge"), colour("panel_edge"))
	# A frame button is one texture in every state: hover lights it halfway
	# to the accent, a press all the way, and disabled dims it. Its text
	# keeps clear of the frame.
	if normal is StyleBoxTexture:
		var lit := _lit_modulate()
		(hover as StyleBoxTexture).modulate_color = Color.WHITE.lerp(lit, 0.5)
		(pressed as StyleBoxTexture).modulate_color = lit
		(disabled as StyleBoxTexture).modulate_color = Color(0.6, 0.6, 0.6)
		for box: StyleBoxTexture in [normal, hover, pressed, disabled]:
			box.content_margin_left = box.texture_margin_left + FRAME_BUTTON_PADDING
			box.content_margin_right = box.texture_margin_right + FRAME_BUTTON_PADDING

	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", disabled)
	th.set_stylebox("focus", "Button", _focus_stylebox())

	th.set_font("font", "Button", body_font)
	th.set_font_size("font_size", "Button", font_size(int(spec.get("text_size", 20))))
	# Every state, or a state left unset takes the engine's light text and
	# vanishes on a light button.
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		th.set_color(state, "Button", accent_ink)
	th.set_color("font_disabled_color", "Button", ink_muted)
	# `button.height` (in `spec`) is a layout figure for the screen that
	# places the control, e.g. `custom_minimum_size.y`; it is not a Theme
	# property, so it is not applied here.


func _apply_label_theme(th: Theme) -> void:
	th.set_font("font", "Label", body_font)
	th.set_font_size("font_size", "Label", font_size(int(spec.get("text_size", 20))))
	th.set_color("font_color", "Label", colour("ink"))


func _apply_line_edit_theme(th: Theme) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = colour("panel")
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = colour("panel_edge")
	th.set_stylebox("normal", "LineEdit", normal)
	th.set_stylebox("focus", "LineEdit", _focus_stylebox())
	th.set_font("font", "LineEdit", body_font)
	th.set_font_size("font_size", "LineEdit", font_size(int(spec.get("text_size", 20))))
	th.set_color("font_color", "LineEdit", colour("ink"))


func _apply_option_button_theme(th: Theme) -> void:
	var cfg: Dictionary = spec.get("button", {})
	th.set_stylebox("normal", "OptionButton", _shape_stylebox(cfg, colour("panel"), colour("panel_edge")))
	th.set_stylebox("hover", "OptionButton", _shape_stylebox(cfg, colour("panel").darkened(0.05), colour("panel_edge")))
	th.set_stylebox("pressed", "OptionButton", _shape_stylebox(cfg, colour("panel").darkened(0.1), colour("panel_edge")))
	th.set_stylebox("disabled", "OptionButton", _shape_stylebox(cfg, colour("panel_edge"), colour("panel_edge")))
	th.set_stylebox("focus", "OptionButton", _focus_stylebox())
	th.set_font("font", "OptionButton", body_font)
	th.set_font_size("font_size", "OptionButton", font_size(int(spec.get("text_size", 20))))
	# Every state, or a state left unset takes the accent button's light
	# text from Button and vanishes on the panel.
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		th.set_color(state, "OptionButton", colour("ink"))


## A switch is drawn bare on the panel: without its own boxes it would
## take the accent button's fill from Button.
func _apply_check_button_theme(th: Theme) -> void:
	th.set_font("font", "CheckButton", body_font)
	th.set_font_size("font_size", "CheckButton", font_size(int(spec.get("text_size", 20))))
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		th.set_color(state, "CheckButton", colour("ink"))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		th.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	th.set_stylebox("focus", "CheckButton", _focus_stylebox())
	# The engine's switches are drawn for a dark panel: pale on a light one
	# they vanish. These are the skin's: the accent track when on.
	var on := _switch_icon(true)
	var off := _switch_icon(false)
	for icon in ["checked", "checked_mirrored", "checked_disabled", "checked_disabled_mirrored"]:
		th.set_icon(icon, "CheckButton", on)
	for icon in ["unchecked", "unchecked_mirrored", "unchecked_disabled", "unchecked_disabled_mirrored"]:
		th.set_icon(icon, "CheckButton", off)


## A switch: a rounded track (the accent when on, the muted ink faintly
## when off) with a knob in the panel's colour at the end it is set to.
## Drawn 4x4 supersampled, so its edges are smooth.
func _switch_icon(on: bool) -> ImageTexture:
	var width := 44
	var height := 24
	var track := colour("accent") if on else colour("ink_muted").lerp(colour("panel"), 0.45)
	var knob := colour("panel")
	var radius := height / 2.0
	var knob_radius := radius - 3.0
	var knob_at := Vector2(width - radius if on else radius, radius)
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var track_cover := 0.0
			var knob_cover := 0.0
			for sy in 4:
				for sx in 4:
					var p := Vector2(x + (sx + 0.5) / 4.0, y + (sy + 0.5) / 4.0)
					# The track: a capsule between its two end circles' centres.
					var nearest := Vector2(clampf(p.x, radius, width - radius), radius)
					if p.distance_to(nearest) <= radius:
						track_cover += 1.0 / 16.0
					if p.distance_to(knob_at) <= knob_radius:
						knob_cover += 1.0 / 16.0
			var c := track
			c.a = track_cover
			if knob_cover > 0.0:
				c = Color(track.lerp(knob, knob_cover), maxf(track_cover, knob_cover))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _apply_h_slider_theme(th: Theme) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = colour("panel_edge")
	track.corner_radius_top_left = 4
	track.corner_radius_top_right = 4
	track.corner_radius_bottom_left = 4
	track.corner_radius_bottom_right = 4
	# A slider draws its track as tall as the box's margins: without them
	# it is not drawn at all.
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	th.set_stylebox("slider", "HSlider", track)

	var grabber_area := StyleBoxFlat.new()
	grabber_area.bg_color = colour("accent")
	grabber_area.corner_radius_top_left = 4
	grabber_area.corner_radius_top_right = 4
	grabber_area.corner_radius_bottom_left = 4
	grabber_area.corner_radius_bottom_right = 4
	grabber_area.content_margin_top = 3
	grabber_area.content_margin_bottom = 3
	th.set_stylebox("grabber_area", "HSlider", grabber_area)
	th.set_stylebox("grabber_area_highlight", "HSlider", grabber_area)
	th.set_stylebox("focus", "HSlider", _focus_stylebox())


func _apply_tab_theme(th: Theme) -> void:
	var selected := StyleBoxFlat.new()
	selected.bg_color = colour("panel")
	selected.border_width_bottom = 3
	selected.border_color = colour("accent")

	var unselected := StyleBoxFlat.new()
	unselected.bg_color = colour("panel").darkened(0.03)
	# Room round each tab's name, so neighbours never run together.
	for box in [selected, unselected]:
		box.content_margin_left = 14
		box.content_margin_right = 14
		box.content_margin_top = 6
		box.content_margin_bottom = 6

	for kind in ["TabBar", "TabContainer"]:
		th.set_stylebox("tab_selected", kind, selected)
		th.set_stylebox("tab_unselected", kind, unselected)
		th.set_stylebox("tab_hovered", kind, unselected)
		th.set_font("font", kind, body_font)
		th.set_font_size("font_size", kind, font_size(int(spec.get("text_size", 20))))
		th.set_color("font_selected_color", kind, colour("ink"))
		th.set_color("font_unselected_color", kind, colour("ink_muted"))
