# City map view: design

Date: 2026-09-26. This is the first of four follow-on mechanics after the three styles (PR #26); the other three are the tram, rooftops and conversations. Each works in every style. The order is map first, because the other three use it to find places.

*Revised 2026-09-26:* the map is a screen of the game interface (`2026-09-26-city-game-interface-design.md`). It opens from the game menu, the title's **Map & read**, and M. It uses that shell's screen stack, input glyphs and the style's `ui` skin, and keeps only its map-specific keys in a `map` block.

## 1. Goal and success

A visitor presses **M** and sees the district as a flat map with north up, drawn in the current style. They find a place, select it, read its card and choose **Go**. A joined player then walks there; a spectator's camera moves there. The same places are also available as a text list that works with the keyboard alone.

The sources:

- `docs/vision/style-studies/shared/CONSISTENCY-CONTRACT.md`:
  - the MAP panel: "flat cartography with north up";
  - the map categories: **Workshop** orange with crossed tools, **Library** blue with an open book, **Transit** purple with a tram, **Park** green with a leaf. "Labels and distinct shapes accompany colour", and "decorative style palettes do not recolour semantic controls";
  - the mobile task: locate W1, select it, and see its card with Ask.
- `docs/vision/VISION.md` interaction principles 1 and 2: "Map & read" is an entrance equal to Explore, and the city offers "a quick map, destination search, teleport, an unstuck action, and shareable destination URLs".
- `docs/vision/EXPERIENCES.md` U01 (map, search, teleport, unstuck) and U05 (keyboard map controls).
- `docs/planning/ROADMAP.md`: "a text and map view of the same work state, keyboard navigation".

The reference panels are the MAP panel (top left of sheet 00) and the MOBILE panel (sheet 03) of each style study:

| Style | Pack | Sheet 00 | Sheet 03 |
| --- | --- | --- | --- |
| 06 Cel-shaded anime | `anime_cel` | r008 | r004 |
| 09 Solarpunk | `solarpunk` | r005 | r003 |
| 10 Neon noir | `neon_noir` | r006 | r004 |
| 08 Pixel art | `pixel_art` | r005 | r008 |
| 11 Low-poly tropical | `lowpoly_tropical` | r002 | r004 |
| 02 Voxel | `voxel` | r004 | r003 |

Every MAP panel is the style's own art seen from straight above, with the places named on label plates in the style's manner:

- anime: round category badges over white captions;
- solarpunk: white plates with upper-case names;
- neon: dark plates, glowing pins and a scale bar;
- pixel: dark plates in pixel type;
- voxel: white plates;
- low-poly: plain captions.

**Success is judged in three ways.**

1. **Sheet match.** The game captures each style's map at 1920 × 1080. A composer tool, extended from the one the styles use, places each capture beside its MAP panel in `city/godot/evidence/map-vs-sheets.png`. The remaining differences are written up in `city/godot/evidence/map-notes.md`.
2. **The mobile task, on the desktop.** Starting from the street view, a keyboard-only visitor can open the map, select the Workshop, and start a walk there in at most five key presses. A controller user can do the same. An automated test drives both.
3. **Performance.** With the map open, every style meets the normal-play gate of the style specs: within 3% of the empty scene's frame rate at vsync, and at most one point more of missed refreshes. Opening the map adds no frame above 50 ms after the first time in a style.

## 2. The data: a place's category

`Facility` in `city-contracts` (`manifest.rs`) gets an optional field:

```rust
/// What the place is on the map: its colour, icon and legend entry.
#[serde(default, skip_serializing_if = "Option::is_none")]
pub category: Option<Category>,

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "lowercase")]
pub enum Category { Workshop, Library, Transit, Park }
```

- **Why in the contract.** A place's category is a fact about the place, like its name, and the same record should serve the map, the card and later the signs (EXPERIENCES U02). The CLI, `city-mcp` and the Godot bridge pass the manifest through, so each gains the field with no new code. `layout_json` already copies facilities whole.
- **The fixture** (`city/fixtures/district/manifest.json`, via `generate.py`):
  - `facility:guild-hall` is a workshop;
  - `facility:library` is a library;
  - `facility:tram-stop` is transit;
  - `facility:park` is a park.
  - Tree square, the café terrace and the streets have no category.
- **The schema.** The exported JSON Schema and its snapshot test gain the enum. Older manifests without the field stay valid.

## 3. The map screen

The map is a full-window screen on the interface's screen stack, drawn by one shared, style-independent client module, `city/godot/core/map/`. It has two tabs, **Map** and **List**, and a card. Its panels, buttons, tabs, plates and fonts come from the style's `ui` skin.

**The Map tab.**

- **Base.** The style's own picture of the district, from straight above, with north up (section 4). It is fitted to the window with a margin and letterboxed in the style's panel colour. The map opens framed on the places, their pins and labels (within the 1–2× zoom), as the MAP panels crop them; zooming out to 1× shows the whole district. Pan by dragging or with the left stick. Zoom from fit to 2× with the wheel, `+` and `-`, or the triggers. Double-click or A zooms in on a spot.
- **Pins.** One per facility with a category, at the centre of its footprint. A pin is the category's badge: its colour and icon, fixed across styles, on a shape the style chooses.
- **Labels.** Each facility, with or without a category, is named on a label plate: the plate's colours, case and font come from the style. Labels avoid each other and the pins: when two overlap, the smaller place's label moves below its pin, then is hidden until zoomed in.
- **Legend.** A row of the four categories: icon, colour and name. Clicking an entry, or pressing its key, filters the pins to that category; again clears the filter.
- **Compass.** An N arrow at the top right, as the sheets draw it.
- **Scale bar.** Metres, where the style asks for one (neon).
- **You are here.** The local player, or the viewer being followed, as a pulsing marker with a facing arrow. It moves live while the map is open.

**The List tab.** The same places as rows, sorted by category and then by name: icon, name, category, and how many people are inside. A search field at the top filters the rows by name as you type; it leaves the Map tab's pins and labels as they are. It is the whole map in text, for anyone who prefers reading to looking.

**The card.** Selecting a place, by clicking its pin or label, moving the selection with the arrows, or choosing a row, opens its card at the side of the Map tab and under the List:

- name and category (icon and word);
- what it is: the facility's rooms, by name;
- **N people inside**, counted from the viewer's own projection. It counts public occupants only, as the projection does, and sits under the existing "Fixture data — not real agent state" banner;
- **Go** (section 5);
- room for **Ask**, which the conversations spec adds. Until then there is no Ask button; nothing on the card promises one.

**Keys and buttons.** While the map is open it is the top screen and takes all input, as every screen does. The hints at the bottom show these in the current glyphs.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Open or close the map | M, or Map in the game menu; Esc (Back) closes | left stick press to toggle; B to close |
| Switch tab | Tab | Y |
| Move the selection | arrow keys: to the nearest place in that direction on the Map tab, or the next row on the List tab | d-pad |
| Go | Enter | A |
| Filter by category | 1–4 | X cycles through them |
| Search (List tab) | typing, with Backspace | — |
| Pan and zoom | drag, wheel, `+`/`-` | left stick, triggers |

The HUD's input hints name M. With no selection, the first arrow press selects the place nearest to "you are here".

**Arguments.**

- `--map` opens the map at start, for captures and tests.
- `--place <id>` opens it with that facility or room selected (a room selects its facility). This is the shareable destination: the web build can later map a URL fragment onto it. An unknown ID opens the map with no selection and a short notice.

## 4. The base picture, per style

A new pack method, called by the map through `StyleHost`:

```gdscript
## The district from straight above, north up, over `extent_m` (metres,
## x east and y south), `size_px` pixels. Emits `map_ready(texture)`; the
## texture is the pack's to cache.
func request_map(extent_m: Rect2, size_px: Vector2i) -> void
signal map_ready(texture: Texture2D)
```

**3D packs (`Pack3D`; anime, solarpunk, neon, low-poly, voxel).**

- **Camera.** A `SubViewport` shares the pack's `World3D` and renders it once with an orthographic `Camera3D` looking straight down over the extent.
- **Hidden for that frame:** people, the player marker and reticle, rain, clouds and cutaways. Roofs are on. The window shows the map overlay throughout, so none of this is visible.
- **Light.** The picture is drawn at the style's `map.minutes` (by default 720, noon; neon 1260, lit night, as its sheet shows), with no rain. The world's own time and weather are restored in the same frame.
- **Shadows.** The sun keeps its angle, so the buildings cast the short shadows the sheets show.
- **Cache.** The picture is kept until the style changes or the window grows past the resolution it was drawn at. The resolution is twice the fitted size, at most 4096 px on the long side, so 2× zoom stays sharp.

**Pixel art (`pixel_art`).** Its world is isometric sprites, which have no top view. The pack draws a top-down plan instead, in its own 32-colour palette, one pixel for every 25 cm, scaled up by whole numbers with nearest filtering. The plan has:

- water with a lighter bank line;
- streets with kerbs, and the tram track;
- the building footprints in their roof colours, and the blocks;
- trees as dithered round crowns with a dark outline;
- the bridge.

This follows its MAP panel.

**While the map is open.**

- The main view stops drawing 3D (`Viewport.disable_3d`), so an open map costs less than the city.
- The simulation keeps running.
- Closing the map restores the view exactly as it was: camera, first person, cutaways, and the cursor mode (first person captures the mouse).

## 5. Go

- **A joined player** (registered or observer). Go sends the core's existing `Go` to the facility's first room, through `Player.go_room`, the same command a click on a door sends. The map closes and the avatar walks there by the core's rules: doors, capacity and queues.
  - If the core refuses, for example because the room is full, the refusal shows as the HUD's notice.
  - If the player is seated, Go stands them up first, as a click does now.
- **A spectator** (`--as none`). Go moves the camera: the overhead rig glides to the place over 0.6 s and keeps its preset. The pixel pack shifts its view. In first person, Go first returns to the overhead view.
- **Teleport and unstuck.** Not in this spec. Each needs a new core intent with admission rules, so that a jump cannot skip a queue or a closed door. They get their own spec and a CLI and MCP tool, by the admission rule in `docs/architecture/AGENT_TOOLING.md`.

## 6. The style's map theme

Panels, plates, fonts, colours and focus come from the style's `ui` skin. Each `style.json` also gains a small `map` block for what only the map needs. The shared module reads it; missing keys fall back to defaults.

```json
"map": {
  "minutes": 720,
  "letterbox": "#F4F1EA",
  "pin": "badge",
  "plate": { "fill": "#FFFFFF", "ink": "#2B2B33", "case": "upper", "radius": 4 },
  "scale_bar": false,
  "glow": false
}
```

- **`pin`:** `badge` (a round badge), `drop` (a teardrop pin) or `square` (a pixel-grid badge for pixel art).
- **`glow`:** a soft halo round pins and plates, for neon.
- **`exposure`** (default 1.0): how much brighter than the world the base picture is drawn; a 3D pack scales its tonemap exposure by it for the render's frame only. Neon's is 2.2, so its lit night reads as its sheet's does.
- **What stays fixed.** The category colours and icons (section 1) never change. The icons are four shared SVGs under `core/map/icons/`, drawn once to read clearly at 20–48 px.
- **`plate`:** the label plates' own colours and case, since a map's plates often differ from its panels (neon's dark plates, solarpunk's white ones). Their font is the skin's body font.
- **`letterbox`:** the colour round the base picture.

## 7. Structure

| File | Responsibility |
| --- | --- |
| `crates/city-contracts/src/manifest.rs` | `Category` and `Facility.category` |
| `fixtures/district/generate.py`, `manifest.json` | the four categories |
| `godot/core/map/map_model.gd` | Pure and testable. Holds the places from the layout (id, name, category, footprint, rooms, centre), and projects metres to map pixels. Also: filter, search, selection, the nearest place in a direction, occupancy from a projection, and label placement. |
| `godot/core/map/map_view.gd` | The overlay: base, pins, labels, legend, compass, scale bar, marker, tabs, card, and input while open |
| `godot/core/map/map_theme.gd` | Reads a style's `map` block, with defaults |
| `godot/core/map/icons/*.svg` | the four category icons |
| `godot/styles/style_pack.gd`, `pack_3d.gd`, `pixel_art/pack.gd` | `request_map` and `map_ready` |
| `godot/core/style_host.gd`, `main.gd`, `core/ui/screens/game_menu.gd`, `core/ui/screens/title.gd`, `args.gd` | opening from M, the game menu and the title; `--map` and `--place`; Go |
| `godot/styles/*/style.json` | each style's `map` block |
| `godot/tools/capture` and the sheet composer | map captures and `map-vs-sheets.png` |

## 8. Testing

- **Rust.** `category` round-trips through the manifest and the schema. A manifest without it still loads. The Godot bridge's layout carries it.
- **GDScript, `map_model`:**
  - places and categories from the fixture's layout;
  - metres to pixels, north up, including the river on the west edge;
  - filter and search, with case and partial matches;
  - the nearest place in each direction;
  - occupancy from a projection, where invisible occupants do not count;
  - labels that never overlap.
- **GDScript, `map_view`, driven by input events:**
  - M opens and closes the map, and Esc closes it;
  - the underlying keys are ignored while it is open;
  - the five-press task on both the keyboard and the controller;
  - Go sends `go_room` for a player and moves the rig for a spectator;
  - a refusal shows its notice;
  - `--place`, with a known and an unknown ID;
  - closing restores the camera, first person and cursor mode.
- **Per style.** `request_map` returns a texture of the requested size in all six styles. The texture is not blank: at least 90% of its pixels differ from the render's clear colour.
  - People are absent from it: a test places an occupant in the square in a contrasting test colour, then checks that colour is missing.
  - The world's time and weather are unchanged afterwards.
  - Switching styles with the map open redraws it in the new style.
- **Captures.** Each style's map at 1920 × 1080, and the composite beside the sheets, inspected panel by panel.
- **Performance.** The bench gains a "map open" scene per style, under the normal-play gate. It also reports the first-open time per style.

## 9. Not in this spec

- **Teleport and unstuck:** a core intent and their own spec (section 5).
- **Ask, and the conversation it opens:** the conversations spec.
- **The tram's stops and routes on the map:** the tram spec adds them to this module.
- **Rooftop terraces as places:** the rooftop spec.
- **A mini-map in the corner:** not planned. The full map is one key away, and the sheets show none.
- **Touch controls and the phone layout:** the platform work. The card and tabs are laid out so that a narrow window stacks them.

## 10. Risks

- **The sheet look from a straight-down render.** The sheets are illustrations: their trees read as round crowns and their roofs as clean shapes. The live world seen from above may read busier. *Mitigation:* the render uses the pack's far-LOD trees and roof materials, and the evidence notes record what differs. A style may override `request_map` if its top view needs its own treatment, as pixel art does.
- **One-frame hiding.** Hiding people and effects for the render frame must never show on screen, and must never leave anything hidden. *Mitigation:* the overlay is drawn before the request, and the restore runs in the same frame. The per-style test checks both.
- **Text in six fonts.** Labels must fit and stay readable at half size, where the contract's acceptance check 5 asks for it. *Mitigation:* label placement measures each text in its font, and the capture review checks it at half size.
