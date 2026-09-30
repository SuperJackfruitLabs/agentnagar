## What only the map needs from a style, read from its `style.json`'s `map`
## block: the time its base picture is drawn at, the colour round that
## picture, the pins' shape, the label plates' colours and case, whether a
## scale bar shows, whether pins and plates glow, and the exposure the
## picture is drawn at (StylePack.map_exposure reads it). Any key a style leaves
## out takes its value from `DEFAULT`. The panels, buttons and fonts round
## the map come from the style's `ui` skin (UiTheme), not from here, and the
## four category colours and icons never change with a style.
extends RefCounted
class_name MapTheme

## The pin shapes a style may ask for: a round badge, a teardrop, or a
## pixel-grid square (pixel art's).
const PINS := ["badge", "drop", "square"]

## The map block a style without one gets (spec section 6's example).
const DEFAULT := {
	"minutes": 720,
	"letterbox": "#F4F1EA",
	"pin": "badge",
	"plate": {"fill": "#FFFFFF", "ink": "#2B2B33", "case": "upper", "radius": 4},
	"scale_bar": false,
	"glow": false,
	"exposure": 1.0,
}

## The style's block, merged over `DEFAULT`.
var spec: Dictionary
## The minute of the day the base picture is drawn at.
var minutes := 720
## The colour round the base picture, and behind it while none has come.
var letterbox := Color("#F4F1EA")
## One of `PINS`.
var pin := "badge"
## The label plates' merged block: fill, ink, case and radius as written.
var plate: Dictionary
var plate_fill := Color.WHITE
var plate_ink := Color("#2B2B33")
## `upper`, `lower` or `title`; anything else leaves a name as it is.
var plate_case := "upper"
## The plates' corner radius, in pixels.
var plate_radius := 4
## Whether a 50 m scale bar shows.
var scale_bar := false
## Whether pins and plates have a soft halo (neon's).
var glow := false
## How much brighter than the world the base picture is drawn (a 3D
## pack's tonemap exposure is scaled by it for the render).
var exposure := 1.0


## The theme from a style's whole `style.json` (its `map` block, if any).
static func from_style(style: Dictionary) -> MapTheme:
	var t := MapTheme.new()
	t.spec = DEFAULT.duplicate(true)
	var block: Dictionary = style.get("map", {})
	for key in block:
		if key == "plate" and block[key] is Dictionary:
			t.spec["plate"].merge(block[key], true)
		else:
			t.spec[key] = block[key]
	t.minutes = int(t.spec["minutes"])
	t.letterbox = Color(str(t.spec["letterbox"]))
	t.pin = str(t.spec["pin"]) if str(t.spec["pin"]) in PINS else "badge"
	t.plate = t.spec["plate"]
	t.plate_fill = Color(str(t.plate["fill"]))
	t.plate_ink = Color(str(t.plate["ink"]))
	t.plate_case = str(t.plate["case"])
	t.plate_radius = int(t.plate["radius"])
	t.scale_bar = bool(t.spec["scale_bar"])
	t.glow = bool(t.spec["glow"])
	t.exposure = float(t.spec["exposure"])
	return t


## A place's name as the plates letter it.
func plate_text(text: String) -> String:
	match plate_case:
		"upper":
			return text.to_upper()
		"lower":
			return text.to_lower()
		"title":
			return text.capitalize()
	return text
