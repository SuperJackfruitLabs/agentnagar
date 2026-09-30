# City map view: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A flat, north-up map of the district in every visual style. It shows category pins, labels, a legend, a compass and "you are here". It has a text list with search, a place card, and **Go**. It opens from M, the game menu and the title's "Map & read".

**Architecture:**

- **Data.** Facilities gain an optional `category` in `city-contracts`.
- **Places.** A pure `MapModel` turns the layout into places, filters them, searches them and moves the selection.
- **Base picture.** Each pack draws its own top-down picture on request. 3D packs render their world with an orthographic camera in a `SubViewport`; pixel art paints a palette plan.
- **Screen.** A `MapScreen` sits on the interface's screen stack and is skinned by the style's `ui` block plus a small `map` block.

**Tech Stack:** Rust (`city-contracts`, serde and schemars), Godot 4.6.3 GDScript, and Python 3 for the fixture generator.

**Spec:** `docs/superpowers/specs/2026-09-26-city-map-view-design.md`. The interface spec, `2026-09-26-city-game-interface-design.md`, is the shell it lives in.

## Global Constraints

- The worktree, branch, commit trailers, test commands and code voice are those of the interface plan (`docs/superpowers/plans/2026-09-26-city-game-interface.md`, Global Constraints). That plan's tasks are complete before this one starts: `ScreenStack`, `Screen`, `UiTheme`, `InputGlyphs`, `Settings`, `PlayHud`, `GameMenu` (with `map_available`), `TitleScreen` (with `map_available`), and `main.stack`, `main.hud`, `main.ui` and `main.settings` all exist.
- Rust checks, from `city/`: `cargo fmt --all --check`, `cargo clippy --workspace --all-targets -- -D warnings` and `cargo test --workspace`.
- **Category colours and icons** are fixed in every style and never taken from a palette:

  | Category | Colour | Icon |
  | --- | --- | --- |
  | Workshop | `#E8731A` | crossed tools |
  | Library | `#2F6FD6` | open book |
  | Transit | `#7A3FC2` | tram |
  | Park | `#3E9A4A` | leaf |

- **The fixture's categories:** `facility:guild-hall` workshop, `facility:library` library, `facility:tram-stop` transit, `facility:park` park. No others.
- **Map coordinates.** A metre point `(x, z)` (x east, z south) maps to pixel `((x - extent.x) / extent.size.x * W, (z - extent.y) / extent.size.y * H)`, so north is up.
- **Zoom** runs from 1× (fit) to 2×. The base picture is rendered at 2× the fitted size, at most 4096 px on its long side.
- **Timings:** the Go camera glide takes 0.6 s (a cut in calm mode).
- **Performance.** With the map open, a style meets the normal-play gate. After the first open in a style, no frame is over 50 ms.
- **Scope.** No teleport and no unstuck (the spec, section 5).

## Review Focus

1. **The base render must leave the world as it was.** Afterwards people, the reticle, rain, clouds, the time of day and the cutaways must be exactly as before, even if the style is switched during the render frame. (Task 3 tests this.)
2. **`--place` with a room ID, a facility ID, and an unknown ID.** (Task 6 tests this.)
3. **Go while seated, in first person, and as a spectator.** (Task 6 tests this.)
4. **Search with mixed case and no results.** An empty list shows "No places match", and Enter does nothing. (Task 2 and Task 5 test this.)
5. **Labels in the narrow layout (800 × 900).** Labels stay inside the base and never overlap. (Task 5 tests this.)

---

### Task 1: The `category` field

**Files:**
- Modify: `city/crates/city-contracts/src/manifest.rs`, adding `Category` and `Facility.category`.
- Modify: `city/crates/city-contracts/tests/contracts.rs`
- Modify: `city/fixtures/district/generate.py`, then regenerate `city/fixtures/district/manifest.json`.
- Test: `city/godot/tests/test_bridge.gd`, which gains a layout-category test.

**Interfaces:**
- Produces:
  ```rust
  /// What a place is on the map: its colour, icon and legend entry.
  #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
  #[serde(rename_all = "lowercase")]
  pub enum Category { Workshop, Library, Transit, Park }
  ```
  `Facility` gets `#[serde(default, skip_serializing_if = "Option::is_none")] pub category: Option<Category>`. Every place that constructs a `Facility { .. }` literal must add `category: None` (`cargo build` finds them).
- In `generate.py`, the four facilities of the Global Constraints get `"category": ...`. Regenerate with `python3 city/fixtures/district/generate.py`, using whatever its usage line or README says. `git diff` must show only the four added keys in `manifest.json`.

- [ ] **Step 1: Write the failing Rust tests** in `contracts.rs`:

```rust
#[test]
fn a_facility_category_round_trips_and_is_optional() {
    let with: Facility = serde_json::from_str(
        r#"{"id":"facility:w","name":"W","rooms":[],"category":"workshop"}"#,
    )
    .unwrap();
    assert_eq!(with.category, Some(Category::Workshop));
    let back = serde_json::to_value(&with).unwrap();
    assert_eq!(back["category"], "workshop");
    let without: Facility =
        serde_json::from_str(r#"{"id":"facility:w","name":"W","rooms":[]}"#).unwrap();
    assert_eq!(without.category, None);
    assert!(serde_json::to_value(&without).unwrap().get("category").is_none());
}

#[test]
fn the_manifest_schema_names_the_four_categories() {
    let s = serde_json::to_string(&all_schemas()["manifest"]).unwrap();
    for c in ["workshop", "library", "transit", "park"] {
        assert!(s.contains(c), "{c} missing from the schema");
    }
}
```

  Check the schema map's key for the manifest by reading `all_schemas` in `lib.rs`, and use that key.

  Add this to `test_bridge.gd`:

```gdscript
func test_the_layout_carries_facility_categories() -> void:
	var w = ClassDB.instantiate("CityWorld")
	var m := FileAccess.get_file_as_string(CityPaths.district_manifest_path())
	w.start(m, FileAccess.get_file_as_string(CityPaths.district_feed_path()), 7, 0, false)
	var layout: Dictionary = JSON.parse_string(w.layout_json())
	var cats := {}
	for d in layout["city"]["districts"]:
		for f in d["facilities"]:
			if f.has("category"):
				cats[f["id"]] = f["category"]
	assert_eq(cats, {"facility:guild-hall": "workshop", "facility:library": "library",
		"facility:tram-stop": "transit", "facility:park": "park"}, "the four categories")
```

  Adapt the world construction to how `test_bridge.gd`'s existing tests build a `CityWorld`, using the same helpers and arguments. The assertion is the contract.

- [ ] **Step 2: Run them and see them fail.** Run `cargo test -p city-contracts`, and the Godot suite with `-- test_bridge`.
- [ ] **Step 3: Implement the field, update the fixture, and rebuild the extension** with `city/scripts/build-godot.sh`.
- [ ] **Step 4: Run all the Rust checks and the whole Godot suite.**
- [ ] **Step 5: Commit** with `feat(city): facilities carry a map category`.

---

### Task 2: MapModel

**Files:**
- Create: `city/godot/core/map/map_model.gd`
- Test: `city/godot/tests/test_map_model.gd`

**Interfaces:**
- Produces: `class_name MapModel extends RefCounted`.
  - `const CATEGORIES := ["workshop", "library", "transit", "park"]` and `const COLOURS := {"workshop": Color("#E8731A"), "library": Color("#2F6FD6"), "transit": Color("#7A3FC2"), "park": Color("#3E9A4A")}`.
  - `static func from_layout(layout: Dictionary) -> MapModel`
  - `var extent: Rect2`: metres, the whole of `CityGeometry.extent(layout)`.
  - `var places: Array`: one Dictionary per facility that is not `facility:streets`, and has at least one room with a `rect`:
    ```
    {id, name, category (String or ""), rooms: [{id, name}], footprint: Rect2 (metres, merged room rects), centre: Vector2 (metres)}
    ```
    Sorted by category order (the four, then ""), then by name.
  - `func to_map(p_m: Vector2, size_px: Vector2) -> Vector2` and `func from_map(px: Vector2, size_px: Vector2) -> Vector2`
  - `func place(id: String) -> Dictionary`: accepts a facility ID or any of its rooms' IDs; `{}` if unknown.
  - `var filter := ""`: a category, or "" for all. `func visible_places() -> Array`: honours `filter` and `query`.
  - `var query := ""`: a case-insensitive substring match on name.
  - `var selected := ""`: a facility ID.
    - `func select(id: String) -> void` selects that place, or nothing if unknown.
    - `func step(dir: Vector2) -> void`: from the selected place's centre (or `origin` when there is none), selects the nearest visible place whose direction from it is within 60° of `dir` (`dir` is a screen direction: +y is south). Nothing changes if there is none.
    - `var origin := Vector2.ZERO`: "you are here", in metres.
  - `func step_row(delta: int) -> void`: the next or previous place in `visible_places()` order, clamped.
  - `static func occupancy(projection: Dictionary, place: Dictionary) -> int`: the number of occupants in the projection's rooms whose IDs are among `place.rooms`. It counts `projection["rooms"][i]["occupants"]` only, never `waiting`. Look up the projection's room list shape in `city-contracts/src/projection.rs` (`RoomView`) and in how `SceneModel.apply` reads it.
  - `func layout_labels(size_px: Vector2, measure: Callable) -> Dictionary`: `id -> Rect2` (px), or no entry when the label is hidden.
    - `measure(text) -> Vector2` gives each label's size.
    - Each label starts centred 18 px below its pin (at `to_map(centre)`); a place with no category has no pin, and its label is centred on the place.
    - In order of footprint area, largest first, a label that overlaps an earlier label or a pin tries below, then above, then right, then left; if all four overlap, it is hidden.
    - Labels are clamped inside `size_px`.

- [ ] **Step 1: Write the failing tests.**

```gdscript
extends TestSuite

func layout() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://../fixtures/district/manifest.json"))
```

  Use the same way other tests load the district. Search the tests for `district_manifest` and copy that. The tests:

```gdscript
func test_places_have_their_categories_and_the_streets_are_left_out() -> void:
	var m := MapModel.from_layout(layout())
	var ids := m.places.map(func(p): return p["id"])
	assert_true(not "facility:streets" in ids, "streets are not a place")
	assert_eq(m.place("facility:library")["category"], "library", "library")
	assert_eq(m.place("room:reading")["id"], "facility:library", "a room finds its facility")
	assert_eq(m.places[0]["category"], "workshop", "workshop sorts first")


func test_north_is_up_and_the_river_is_west() -> void:
	var m := MapModel.from_layout(layout())
	var size := Vector2(1000, 800)
	var lib := m.to_map(m.place("facility:library")["centre"], size)
	var ws := m.to_map(m.place("facility:guild-hall")["centre"], size)
	assert_true(lib.x > ws.x, "the library is east of the workshop")
	var stop := m.to_map(m.place("facility:tram-stop")["centre"], size)
	assert_true(stop.y > ws.y, "the tram stop is south, lower on the map")
	var back := m.from_map(lib, size)
	assert_true(back.distance_to(m.place("facility:library")["centre"]) < 0.01, "round trip")


func test_filter_and_search() -> void:
	var m := MapModel.from_layout(layout())
	m.filter = "park"
	assert_eq(m.visible_places().map(func(p): return p["id"]), ["facility:park"], "only parks")
	m.filter = ""
	m.query = "LIB"
	assert_eq(m.visible_places().map(func(p): return p["id"]), ["facility:library"], "case-insensitive")
	m.query = "zzz"
	assert_eq(m.visible_places(), [], "no match")


func test_arrows_move_to_the_nearest_place_that_way() -> void:
	var m := MapModel.from_layout(layout())
	m.select("facility:guild-hall")
	m.step(Vector2.RIGHT)
	assert_true(m.selected != "facility:guild-hall", "moved east")
	m.select("facility:library")
	var before := m.selected
	m.step(Vector2.RIGHT)
	assert_eq(m.selected, before, "nothing further east: unchanged")


func test_first_arrow_starts_from_you_are_here() -> void:
	var m := MapModel.from_layout(layout())
	m.origin = m.place("facility:tram-stop")["centre"] + Vector2(0, 5)
	m.step(Vector2.UP)
	assert_eq(m.selected, "facility:tram-stop", "the nearest place north of you")


func test_occupancy_counts_visible_occupants_of_the_place_rooms() -> void:
	var m := MapModel.from_layout(layout())
	var proj := {"rooms": [
		{"id": "room:workshop", "occupants": [{"id": "a"}, {"id": "b"}], "waiting": [{"id": "c"}]},
		{"id": "room:commons", "occupants": [{"id": "d"}], "waiting": []},
		{"id": "room:reading", "occupants": [{"id": "e"}], "waiting": []}]}
	assert_eq(MapModel.occupancy(proj, m.place("facility:guild-hall")), 3, "two rooms, waiting not counted")


func test_labels_never_overlap_and_stay_inside() -> void:
	var m := MapModel.from_layout(layout())
	for size in [Vector2(1920, 1080), Vector2(800, 900)]:
		var rects := m.layout_labels(size, func(t): return Vector2(t.length() * 11.0 + 16.0, 28.0))
		var list := rects.values()
		for i in list.size():
			assert_true(Rect2(Vector2.ZERO, size).encloses(list[i]), "inside at %s" % size)
			for j in range(i + 1, list.size()):
				assert_true(not list[i].intersects(list[j]), "no overlap at %s" % size)
```

  Match the projection's real shape before writing `test_occupancy_…`. If `rooms` is keyed differently in a real projection, write the test against the real shape, and note that in the report.

- [ ] **Step 2: Run them and see them fail** with `-- test_map_model`.
- [ ] **Step 3: Implement `map_model.gd`.**
- [ ] **Step 4: Run them: PASS.** Then the whole suite.
- [ ] **Step 5: Commit** with `feat(city): map model of the district's places`.

---

### Task 3: The 3D packs draw their map base

**Files:**
- Modify: `city/godot/styles/style_pack.gd`, which gains the base API.
- Modify: `city/godot/styles/pack_3d.gd`, for the render.
- Modify: `city/godot/core/style_host.gd`, which gains `request_map` and the `map_ready` forwarding.
- Test: `city/godot/tests/test_map_base.gd`

**Interfaces:**
- Produces, on `StylePack`:
  - `signal map_ready(texture: Texture2D)`
  - `func request_map(extent_m: Rect2, size_px: Vector2i) -> void`. By default it emits a plain texture of `size_px` filled with `style.map.letterbox` (default `#F4F1EA`), deferred.
  - `func map_minutes() -> int`: returns `int(style.get("map", {}).get("minutes", 720))`.
- On `Pack3D`, `request_map`:
  1. Creates a `SubViewport` of `size_px` with `own_world_3d = false`, added under the pack so it shares the `World3D`, with `transparent_bg = false`, `msaa_3d` = the pack's MSAA level and `render_target_update_mode = UPDATE_ONCE`.
  2. Adds a `Camera3D` with `projection = PROJECTION_ORTHOGONAL` and `size = extent_m.size.y` (keep aspect: `keep_aspect = KEEP_HEIGHT`), at `(centre.x, 200, centre.y)`, looking straight down with -Z towards north: `rotation_degrees = Vector3(-90, 0, 0)`. Set `current = true` in the `SubViewport`; the main camera is untouched.
  3. Saves, then hides for the render:
     - every person node (`nodes`) and far-crowd node;
     - the player marker and reticle;
     - `rain_node` and the streaks;
     - `clouds`.

     It saves and sets `set_time_of_day(map_minutes())` and `set_rain(0.0)`, and turns the roofs on (`set_keep_roofs(true)`; restore the previous value and the open set). Sun shadows stay.
  4. Awaits `RenderingServer.frame_post_draw` once, copies `get_texture().get_image()` into an `ImageTexture`, then restores everything saved, frees the `SubViewport`, and emits `map_ready`.
  5. If the pack is torn down while waiting (`is_queued_for_deletion()` or not inside the tree), it emits nothing and restores nothing, since the pack is gone.

  The restore must run in the same frame as the `post_draw` await returns, before any other `_process`.
- On `StyleHost`:
  - `signal map_ready(texture: Texture2D, pack_dir: String)`
  - `func request_map(extent_m: Rect2, size_px: Vector2i)`: forwards to the current pack. Connecting to the pack's signal must not leak across switches; use `CONNECT_ONE_SHOT` per request.

- [ ] **Step 1: Write the failing tests.** They need a display for real pixels, so the pixel-content test skips headless (`DisplayServer.get_name() == "headless"`). The skip must still make an assertion, `assert_true(true, "skipped headless")`; say so in the test's doc comment.

```gdscript
extends TestSuite

func booted(style: String):
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=20", "--style=" + style, "--as=none"]))
	main.driver.advance(30.0)
	return main


func test_every_style_answers_with_a_texture_of_the_size_asked() -> void:
	for style in ["lowpoly_tropical", "voxel", "anime_cel", "solarpunk", "neon_noir", "pixel_art"]:
		var main = booted(style)
		var got := []
		main.host.map_ready.connect(func(t, _d): got.append(t), CONNECT_ONE_SHOT)
		main.host.request_map(CityGeometry.extent(main.manifest), Vector2i(640, 400))
		for i in 4:
			await runner.process_frame
		await RenderingServer.frame_post_draw
		for i in 2:
			await runner.process_frame
		assert_eq(got.size(), 1, style + ": one answer")
		assert_eq(Vector2i(got[0].get_size()), Vector2i(640, 400), style + ": size")
		main.free()


func test_the_world_is_as_it_was_afterwards() -> void:
	var main = booted("anime_cel")
	var pack: Pack3D = main.host.pack
	var minutes: int = pack.minutes
	var shown := {}
	for id in pack.nodes:
		shown[id] = pack.nodes[id].visible
	main.host.request_map(CityGeometry.extent(main.manifest), Vector2i(320, 200))
	for i in 4:
		await runner.process_frame
	await RenderingServer.frame_post_draw
	for i in 2:
		await runner.process_frame
	assert_eq(pack.minutes, minutes, "time of day restored")
	for id in shown:
		assert_eq(pack.nodes[id].visible, shown[id], "person %s restored" % id)
	assert_true(not pack.has_node("MapView"), "the render viewport is gone")
	main.free()


func test_a_switch_during_the_render_is_harmless() -> void:
	var main = booted("anime_cel")
	var got := []
	main.host.map_ready.connect(func(t, d): got.append(d))
	main.host.request_map(CityGeometry.extent(main.manifest), Vector2i(320, 200))
	main.host.activate("res://styles/voxel", main.manifest, main.model, main.motion, 0.0)
	for i in 6:
		await runner.process_frame
	assert_true(got.all(func(d): return d == "res://styles/voxel") , "no stale answer from the old pack")
	main.free()
```

  Name the `SubViewport` "MapView". Pixel art answers with the base default until Task 4, which is fine for the first test.

- [ ] **Step 2: Run them and see them fail** with `-- test_map_base`.
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run them: PASS**, headless. Then run them on the display: `godot --path city/godot --script res://tests/run_all.gd -- test_map_base`, without `--headless`. Save one texture per 3D style to the scratchpad and look at them. Each must be a clear top-down picture with no people. Then run the whole suite.
- [ ] **Step 5: Commit** with `feat(city): 3D styles render their own map base`.

---

### Task 4: Pixel art paints its map base

**Files:**
- Modify: `city/godot/styles/pixel_art/pack.gd`
- Test: `city/godot/tests/test_map_base.gd`, adding a test.

**Interfaces:**
- `PixelPack.request_map(extent_m, size_px)` paints an `Image` at 4 px per metre (1 px = 25 cm) over `extent_m`, then scales it by nearest-neighbour to the smallest whole-number multiple covering `size_px`, crops it to `size_px`, and emits deferred. The picture is made from the layout (`manifest`) and scenery, not from the sprites. It uses only colours from the style's 32-colour palette: find it in `styles/pixel_art/assets/kit.json` or `style.json`, and use what the pack's `palette_index` is built from.
  - water, with a one-pixel lighter bank line;
  - streets, with a darker kerb pixel line, and the tram line as two parallel dark rows;
  - building footprints (`CityGeometry.buildings`) in their roof colour, with a one-pixel dark outline;
  - scenery blocks, a mid colour with an outline;
  - lawn and park areas in green;
  - tree rows as round 7 px crowns, two greens dithered in a checker, with a dark outline;
  - the bridge deck.

- [ ] **Step 1: Write the failing test.**

```gdscript
func test_pixel_art_paints_its_plan_in_its_palette() -> void:
	var main = booted("pixel_art")
	var got := []
	main.host.map_ready.connect(func(t, _d): got.append(t), CONNECT_ONE_SHOT)
	main.host.request_map(CityGeometry.extent(main.manifest), Vector2i(800, 500))
	await runner.process_frame
	await runner.process_frame
	var img: Image = got[0].get_image()
	var colours := {}
	for y in range(0, 500, 7):
		for x in range(0, 800, 7):
			colours[img.get_pixel(x, y).to_html(false)] = true
	assert_true(colours.size() >= 5, "a real plan, not a flat fill")
	var allowed: Dictionary = main.host.pack.palette_hexes()
	for c in colours:
		assert_true(allowed.has(c), "palette colour " + c)
	main.free()
```

  Add `func palette_hexes() -> Dictionary` to the pixel pack: its 32 colours as lowercase `rrggbb` keys.

- [ ] **Step 2: Run it and see it fail.**
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run it: PASS.** Save a capture on the display and compare it with the pixel study's MAP panel (sheet 00, r005). Then run the whole suite.
- [ ] **Step 5: Commit** with `feat(city): pixel art paints its map base`.

---

### Task 5: MapScreen

**Files:**
- Create: `city/godot/core/map/map_screen.gd` and `city/godot/core/map/map_theme.gd`
- Create: `city/godot/core/map/icons/workshop.svg`, `library.svg`, `transit.svg`, `park.svg` and `you.svg`
- Test: `city/godot/tests/test_map_screen.gd`

**Interfaces:**
- Consumes: `MapModel` (Task 2), `StyleHost.request_map` and `map_ready` (Task 3), `Screen`, `UiTheme` and `InputGlyphs`.
- Produces:
  - `class_name MapTheme extends RefCounted`, from the style's `map` block with defaults:
    - `minutes` 720;
    - `letterbox` `#F4F1EA`;
    - `pin` `"badge"`, `"drop"` or `"square"`;
    - `plate` `{fill "#FFFFFF", ink "#2B2B33", case "upper", radius 4}`;
    - `scale_bar` false;
    - `glow` false.

    `static func from_style(style: Dictionary) -> MapTheme`.
  - `class_name MapScreen extends Screen`:
    - `var model: MapModel`, `var host: StyleHost`, `var glyphs: InputGlyphs`, `var theme_map: MapTheme` and `var projection := {}`, the viewer's latest.
    - `var you = null`: a `Vector2` in metres, or null.
    - `var you_facing := Vector2.ZERO`
    - signals: `signal go(place_id: String)` and `signal notice(text: String)`.
    - `var tab := "map"`: `"map"` or `"list"`. `func set_tab(t)`.
    - `var zoom := 1.0`, from 1.0 to 2.0, and `var pan := Vector2.ZERO`, in px of the fitted base.
    - **Map tab:**
      - a `TextureRect` "Base", with a letterbox fill in the `letterbox` colour;
      - per place with a category, a pin `Control` named `"Pin_" + id`: a badge in `MapModel.COLOURS` with its SVG icon, the shape per `theme_map.pin`, 40 px at zoom 1;
      - per place, a label `PanelContainer` `"Label_" + id` with the plate style, placed from `model.layout_labels`, and hidden when absent;
      - a legend `HBoxContainer` "Legend" with four `Button`s named after the categories. Each toggles `model.filter`, and hides pins and labels outside the filter;
      - a compass `Control` "Compass" (N arrow) at the top right;
      - "ScaleBar" when `scale_bar` is true: 50 m, with its label;
      - "You", a marker at `to_map(you)` that pulses (scale 1 to 1.15 over 1 s) and turns with `you_facing`.
    - **List tab:**
      - a `LineEdit` "Search". Typing sets `model.query`, and the list rebuilds.
      - an `ItemList`, or a `VBoxContainer` of `Button` rows, "Rows": icon, name, category word, and "N inside". With no rows it shows a `Label` "No places match".
    - **Card:** a `PanelContainer` "Card", at the right on the Map tab and below the list on the List tab (and at the bottom when `size.x < 900`). It holds:
      - the name;
      - the category icon and word;
      - "Rooms: …" (room names joined with ", ");
      - "N people inside" (`MapModel.occupancy(projection, place)`);
      - a "Go" button.

      It is hidden when nothing is selected.
    - **Input** (`_gui_input` and `_unhandled_input` while it is the top screen):
      - the arrows or d-pad: `model.step(dir)` on the Map tab, `step_row(±1)` on the List tab;
      - Enter or A: `go.emit(selected)`, if any;
      - Tab or Y: switch tab;
      - 1–4: filter by category (again clears); X cycles the filters;
      - `+`/`-`, the wheel, or the triggers: zoom, clamped to 1–2;
      - drag, or the left stick: pan, clamped to the base;
      - M: `stack.back()`. Back (Esc or B) pops as usual.
    - `func open(place_id := "") -> void`:
      - sets `model.origin` from `you`;
      - requests the base (`host.request_map(model.extent, size_px)`, where `size_px` is 2× the fitted size, capped at 4096 on the long side);
      - selects `place_id` if known. If `place_id != ""` and it is unknown, it emits `notice("No place called " + place_id)`.
    - When `host` switches style while open, it re-requests the base and re-reads `MapTheme` (on `apply_theme`).
  - `func size_px_for(window: Vector2) -> Vector2i`: static-friendly, and tested.

- [ ] **Step 1: Write the failing tests.**

```gdscript
extends TestSuite

func screen(size := Vector2(1920, 1080)) -> MapScreen:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack", "--as=none"]), "res://tests/fixtures")
	var s := MapScreen.new()
	s.model = MapModel.from_layout(main.manifest)
	s.host = main.host
	s.glyphs = main.glyphs
	s.theme_map = MapTheme.from_style({})
	s.size = size
	main.stack.push(s)
	s.set_meta("main", main)
	return s


func done(s: MapScreen) -> void:
	s.get_meta("main").free()


func test_pins_for_categories_and_labels_for_all_places() -> void:
	var s := screen()
	s.open()
	for id in ["facility:guild-hall", "facility:library", "facility:tram-stop", "facility:park"]:
		assert_true(s.find_child("Pin_" + id, true, false) != null, "pin " + id)
	assert_true(s.find_child("Pin_facility:square", true, false) == null, "no pin without a category")
	assert_true(s.find_child("Label_facility:square", true, false) != null, "but a label")
	done(s)


func test_the_mobile_task_in_five_presses() -> void:
	var s := screen()
	s.you = s.model.place("facility:tram-stop")["centre"]
	s.open()
	var goes := []
	s.go.connect(func(id): goes.append(id))
	for dir in [Vector2.UP, Vector2.LEFT, Vector2.UP]:
		if s.model.selected != "facility:guild-hall":
			s.model.step(dir)
	assert_eq(s.model.selected, "facility:guild-hall", "reached the workshop by arrows")
	s.press_go()
	assert_eq(goes, ["facility:guild-hall"], "Go sent")
	done(s)


func test_search_with_no_match_shows_so_and_enter_does_nothing() -> void:
	var s := screen()
	s.open()
	s.set_tab("list")
	s.set_query("zzz")
	assert_true(s.find_child("NoMatch", true, false).visible, "No places match")
	var goes := []
	s.go.connect(func(id): goes.append(id))
	s.press_go()
	assert_eq(goes, [], "nothing to go to")
	done(s)


func test_an_unknown_place_opens_with_a_notice() -> void:
	var s := screen()
	var notes := []
	s.notice.connect(func(t): notes.append(t))
	s.open("facility:nowhere")
	assert_eq(s.model.selected, "", "nothing selected")
	assert_eq(notes.size(), 1, "one notice")
	done(s)


func test_the_card_counts_people_inside() -> void:
	var s := screen()
	s.projection = {"rooms": [{"id": "room:reading", "occupants": [{"id": "a"}, {"id": "b"}], "waiting": []}]}
	s.open("facility:library")
	assert_true("2 people inside" in s.find_child("Card", true, false).get_meta("summary"), "count shown")
	done(s)


func test_base_size_is_twice_the_fit_and_capped() -> void:
	assert_eq(MapScreen.size_px_for(Vector2(1920, 1080)).x <= 4096, true, "capped")
	assert_true(MapScreen.size_px_for(Vector2(800, 600)).x >= 1200, "twice a small window")


func test_narrow_layout_keeps_labels_apart() -> void:
	var s := screen(Vector2(800, 900))
	s.open()
	var rects := []
	for c in s.find_children("Label_*", "", true, false):
		if c.visible:
			rects.append(Rect2(c.position, c.size))
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			assert_true(not rects[i].intersects(rects[j]), "labels apart")
	done(s)
```

  `press_go()` and `set_query(text)` are the same paths as Enter and typing. Give the Card a `summary` meta holding its text, for tests.
- [ ] **Step 2: Run them and see them fail** with `-- test_map_screen`.
- [ ] **Step 3: Implement the screen, the theme and the icons.** Match the icons to the contract: crossed tools, an open book, a tram and a leaf, as simple filled shapes readable at 20 px.
- [ ] **Step 4: Run them: PASS.** Then the whole suite.
- [ ] **Step 5: Commit** with `feat(city): the map screen`.

---

### Task 6: Opening the map, Go, and the arguments

**Files:**
- Modify: `city/godot/main.gd`, `core/args.gd`, `core/ui/screens/game_menu.gd` (`map_available = true`), `core/ui/screens/title.gd` (`map_available = true`), `styles/style_pack.gd` and `styles/pack_3d.gd` (the `fly_to` glide already exists from the interface plan; reuse it for Go), and `core/ui/play_hud.gd`, if the hint text needs it.
- Test: `city/godot/tests/test_map_flow.gd`

**Interfaces:**
- `main.gd`:
  - `func open_map(place_id := "") -> void`: pushes a `MapScreen` wired to `host`, `glyphs`, the latest projection of the current viewer (`_last_projection`, kept by `_on_projected`), `you` (the player's shown position in metres, or null) and `you_facing`. It then calls `open(place_id)`.
  - The `map` intent (M) opens it in play; the game menu's "Map" opens it over the menu; the title's "Map & read" opens it over the title.
  - `go(place_id)`:
    - pops the map screen, and the game menu if it is under it;
    - **a player** (`player.present`): if first person, stays in first person; if seated, `player.interact()` stands them up first. Then `player.go_room(first room id)`. A refusal `{"ok": false, "error": ...}` becomes `hud.notify("Can't go there: " + reason)`;
    - **no player:** leaves first person if in it, then calls `host.pack.fly_to(centre_cm, 0.0 if settings.calm() else 0.6)`;
    - **from the title** (Map & read): Go does not join. It flies the title camera to the place, stays on the title, and stops the drift.
  - `--map` and `--place=<id>`: after boot, `open_map(options["place"])`.
- `args.gd`: `"map": false` (`--map`) and `"place": ""` (`--place=`). `--place` implies `--map`. Neither counts as a play argument.

- [ ] **Step 1: Write the failing tests.**

```gdscript
extends TestSuite

func booted(extra: Array = []):
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack"] + extra), "res://tests/fixtures")
	return main


func key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func test_m_opens_the_map_and_m_closes_it() -> void:
	var main = booted()
	main.router.handle(key(KEY_M))
	assert_true(main.stack.top() is MapScreen, "open")
	main.stack.top().handle_key(key(KEY_M))
	assert_eq(main.stack.top(), main.hud, "closed")
	main.free()


func test_go_walks_a_player_to_the_first_room() -> void:
	var main = booted()
	main.open_map("facility:library")
	main.stack.top().press_go()
	assert_eq(main.stack.top(), main.hud, "map closed")
	assert_eq(main.player.last_go_room, "room:reading", "Go sent for the reading room")
	main.free()


func test_go_as_a_spectator_moves_the_camera() -> void:
	var main = booted(["--as=none"])
	var flights := []
	main.host.pack.set_meta("fly_log", flights)
	main.open_map("facility:library")
	main.stack.top().press_go()
	assert_eq(flights.size(), 1, "the camera flew")
	main.free()


func test_place_argument_selects_by_room_or_facility_and_warns_when_unknown() -> void:
	for pair in [["room:reading", "facility:library"], ["facility:park", "facility:park"]]:
		var main = booted(["--place=" + pair[0]])
		assert_true(main.stack.top() is MapScreen, "map open")
		assert_eq(main.stack.top().model.selected, pair[1], "selected " + pair[1])
		main.free()
	var bad = booted(["--place=room:nowhere"])
	assert_eq(bad.stack.top().model.selected, "", "nothing selected")
	assert_true(bad.hud.notices.size() == 1, "a notice says so")
	bad.free()


func test_the_menu_and_the_title_offer_the_map() -> void:
	var main = booted()
	main.router.handle(key(KEY_ESCAPE))
	var menu = main.stack.top()
	assert_true(menu.find_child("Map", true, false).visible, "menu has Map")
	menu.open_map.emit()
	assert_true(main.stack.top() is MapScreen, "opened from the menu")
	main.free()
```

  `Player` gains `var last_go_room := ""`, set in `go_room`, for tests; it is harmless. `fake_pack` records `fly_to` calls into its `fly_log` meta when set. Put that in `tests/fixtures/fake_pack/pack.gd`, not in production code. `PlayHud.notices` is from the interface plan. `MapScreen.handle_key(event)` is the path its input handler uses.

- [ ] **Step 2: Run them and see them fail** with `-- test_map_flow`.
- [ ] **Step 3: Implement everything above.**
- [ ] **Step 4: Run them: PASS.** Then the whole suite.
- [ ] **Step 5: Commit** with `feat(city): open the map from anywhere, go to a place, --map and --place`.

---

### Task 7: Per-style map themes, evidence, benchmark and docs

**Files:**
- Modify: `city/godot/styles/*/style.json`, adding a `map` block to all six.
- Modify: `city/godot/tools/sheet_views.gd`, which gains a `map` mode (`-- <style> map`) writing `map.png` at 1920×1080 with the Workshop selected.
- Modify: `city/godot/tools/sheet_compare.py`, adding the pair `("map", "00-city-perspectives", 0, 0)`.
- Create: `city/godot/evidence/map-vs-sheets.png` and `city/godot/evidence/map-notes.md`
- Modify: `city/godot/core/bench.gd`, adding a "map" scene per style (map open, crowd 60), plus the first-open time printed per style; `city/README.md` (the map, `--map`, `--place`).

**Map blocks.** Each follows its sheet's MAP panel:

| Pack | minutes | letterbox | pin | plate fill / ink / case | scale_bar | glow |
| --- | --- | --- | --- | --- | --- | --- |
| anime_cel | 720 | `#F4F6FA` | badge | `#FFFFFF` / `#1E2A44` / title | false | false |
| solarpunk | 720 | `#EFE8D6` | drop | `#FFFFFF` / `#123C3A` / upper | false | false |
| neon_noir | 1260 | `#0B1220` | drop | `#0E1A2E` / `#E6F1FF` / upper | true | true |
| pixel_art | 720 | `#141B33` | square | `#141B33` / `#E8ECFF` / upper | false | false |
| lowpoly_tropical | 720 | `#F6EBD2` | badge | `#FFF8EA` / `#2E2A24` / upper | false | false |
| voxel | 720 | `#DDE8F2` | badge | `#FFFFFF` / `#1F2433` / upper | false | false |

- [ ] **Step 1: Add a `test_bench.gd` assertion** that `Bench.SCENES` has a `map` scene at crowd 60, and a `test_map_screen.gd` test that every style's `map` block's plate ink on plate fill is ≥ 4.5:1 (`UiTheme.contrast`). Run them and see them fail.
- [ ] **Step 2: Add the blocks, the capture mode, the compare pair and the bench scene.**
- [ ] **Step 3: Run the suite: green.**
- [ ] **Step 4: Capture all six maps, compose `map-vs-sheets.png`, and write the notes.** Record what matches and what differs, per style.
- [ ] **Step 5: Run `city/scripts/bench.sh`** with the performance profile, starting from a GPU below 60 °C. Every scene passes. Record the results, including the first-open time per style (the spec: no frame over 50 ms after the first open), in `map-notes.md` under "Performance".
- [ ] **Step 6: Update the README, then run `city/scripts/check.sh` in full.**
- [ ] **Step 7: Commit** with `docs(city): map themes, evidence, benchmark scene and docs`.
