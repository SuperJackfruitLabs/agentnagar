## What a display's surface says in the world at each level of detail
## (interactions spec section 2; integration plan section 4.1):
## - far: only its chip, the kind's name, and "Sample" for sample content;
## - within NEAR_M metres: its headlines, the first few items;
## - open: the overlay (PanelScreen) shows everything, and the surface keeps
##   its headlines.
## A surface never says anything the overlay lacks: every line here is one
## PanelScreen shows too. Packs draw the text; this says what it is.
extends RefCounted
class_name Surfaces

## Within this many metres of the player (or the camera, with no player) a
## surface draws its headlines.
const NEAR_M := 8.0
const FAR := "far"
const NEAR := "near"
const OPEN := "open"
## The mark sample content carries in every view.
const SAMPLE := "Sample"


## The level of detail for a surface `distance_m` metres away, `open` while
## its overlay is shown.
static func level(distance_m: float, open: bool) -> String:
	if open:
		return OPEN
	return NEAR if distance_m <= NEAR_M else FAR


## Every display in `layout` (the core's layout): the placements whose
## catalogue kind (`kinds`, StylePack.kinds()) has a display anchor, each
## {id, kind, name (the kind's), pos (the display anchor, ground cm),
## facing (the way its text faces, the surface's outward normal, degrees),
## height (cm above the ground), size ({w, d}: its width and height, cm)},
## in placement ID order. Their panels are added by the caller.
static func of_layout(layout: Dictionary, kinds: Dictionary) -> Array:
	var out := []
	for d in layout.get("city", {}).get("districts", []):
		for p in d.get("placements", []):
			var kind: Dictionary = kinds.get(str(p["kind"]), {})
			for a in kind.get("anchors", []):
				if a.get("type") != "display":
					continue
				var facing := int(p["facing"]) if p.get("facing") != null else 0
				var size: Dictionary = a.get("size", {"w": 100, "d": 100})
				out.append({"id": str(p["id"]), "kind": str(kind["id"]), "name": str(kind.get("name", kind["id"])),
					"pos": Interact.world_point(Motion.point(p["at"]), facing, Motion.point(a["at"])),
					"facing": posmod(facing + int(a.get("facing", 0)), 360), "height": int(a.get("height", 0)),
					"size": {"w": int(size["w"]), "d": int(size["d"])}})
				break
	out.sort_custom(func(a, b): return a["id"] < b["id"])
	return out


## What `surface` (see of_layout, with its `panel`, {} when unbound) says
## at `level`: far, its chip; near or open, "Sample" for sample content,
## its title (the kind's name when it shows nothing) and at most
## `max_lines` headlines. A plaque's headline is its title alone; its text
## is for the overlay.
static func text(surface: Dictionary, level_: String, max_lines: int) -> String:
	var panel: Dictionary = surface.get("panel", {})
	var sample: bool = panel.get("sample", false)
	var name := str(surface.get("name", ""))
	if level_ == FAR:
		return name + (" · " + SAMPLE if sample else "")
	var lines := []
	if sample:
		lines.append(SAMPLE)
	lines.append(str(panel.get("title", name)) if not panel.is_empty() else name)
	lines.append_array(headlines(panel).slice(0, max_lines))
	return "\n".join(lines)


## A panel's headlines, one an item, as the overlay heads them: a notice's
## date and headline, a spine's title; none for a plaque.
static func headlines(panel: Dictionary) -> Array:
	match str(panel.get("type", "")):
		"Notices":
			return panel.get("items", []).map(func(n): return "%s · %s" % [n.get("date", ""), n.get("headline", "")])
		"Shelf":
			return panel.get("spines", []).map(func(s): return str(s.get("title", "")))
	return []
