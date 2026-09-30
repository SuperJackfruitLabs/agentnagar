# City game interface: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the client's test-harness HUD with a game interface: a live title screen, a quiet in-play HUD, a game menu with a live style picker, persistent settings with rebinding and calm mode, and the developer controls behind an opt-in F3 panel. Every screen is skinned per visual style.

**Architecture:** A new module, `city/godot/core/ui/`, holds:

- a `ScreenStack` of code-built `Screen`s, which takes input from the world while a screen is open;
- a `UiTheme` that builds a Godot `Theme` from each style's `ui` block;
- `InputGlyphs`, for keyboard and controller hints;
- `Settings`, persisted in `user://settings.cfg`;
- the screens.

`main.gd` stays the composition root. `core/hud.gd` is split into `ui/play_hud.gd` (the player's HUD and the error panel) and `ui/dev_panel.gd` (the developer controls).

**Tech Stack:** Godot 4.6.3 (GDScript, Forward+), the Rust gdext extension `city-godot` (unchanged here), and Python 3 with Pillow for the frame and font tools.

**Spec:** `docs/superpowers/specs/2026-09-26-city-game-interface-design.md`. Read it before any task; it is the binding authority.

## Global Constraints

- Work only in a dedicated git worktree, on branch `feat/city-interface`. Never use a bare `git stash`.
- Commit messages end with these two lines:
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01JKP5riujFNbo1iL4Yjv4qQ
  ```
- **The Godot test suite** runs from `city/godot`: `godot --headless --path . --script res://tests/run_all.gd`. Arguments after `--` narrow it to files whose names contain them, e.g. `-- test_settings`. The whole suite must stay green; the baseline is 252/252.
  - After adding new `class_name` scripts, run `godot --headless --path . --import --quit` once, so the class cache knows them.
- Tests are `extends TestSuite` files named `tests/test_*.gd`, with `test_*` methods. They use `assert_true(cond, msg)` and `assert_eq(a, b, msg)`, and `runner.root` for the scene tree. A test that makes no assertion fails.
- The `city-godot` library must be built: `city/scripts/build-godot.sh`. It already is in this worktree.
- **Match the code's voice:** `##` doc comments that say what a thing is for, in plain sentences; tabs for indentation in GDScript; names spelled out.
- **Fixed notice:** "Fixture data — not real agent state" is always visible in play and on the title.
- **Contrast floors**, WCAG relative luminance: `ink` on `panel` ≥ 4.5; `accent_ink` on `accent` ≥ 4.5; `focus` against `panel` ≥ 3.0.
- **Timings:**
  - notices fade after 4 s, and at most two show at once;
  - input hints fade after 10 s of play;
  - the title drift makes one turn in 180 s;
  - the Explore flight takes 1.2 s;
  - a display-change confirmation reverts after 10 s.
- **Text size scales:** 1.0, 1.25 and 1.5. Pixel fonts render only at whole-number scales of their base size.
- **Launch arguments.** Any of `--as`, `--look`, `--style`, `--camera`, `--fpv` or `--capture` skips the title and goes straight to play, exactly as today. `--title` forces the title. `--dev` enables the developer tools for the session.
- **Frame-rate gate.** Measured with `city/scripts/bench.sh` on a display: within 3% of the empty scene's fps at vsync, and at most 1 point more of missed refreshes.

## Review Focus

1. **Keys held when a screen opens.** Holding W while pressing Esc must stop the avatar at once, and releasing W inside the menu must not leave it walking when the menu closes. (Task 4 tests this.)
2. **A style switch while a screen is open.** The screen reskins, keeps its focus and stays open, and the new pack does not steal input. (Task 8 tests this.)
3. **A missing or corrupt `settings.cfg`, or one from a newer version with unknown keys.** Defaults load, unknown keys are kept, and nothing errors. (Task 1 tests this.)
4. **Launch arguments.** Every existing script and capture path (`--as=none`, `--style=…`, `--capture=…`) must still boot straight to play, with no title in the way. (Task 7 tests this.)
5. **Controller only.** Every screen must be reachable and usable with the d-pad and A/B alone; no control may be focusable only with the mouse. (Tasks 8–10 test this.)

---

### Task 1: Settings

**Files:**
- Create: `city/godot/core/ui/settings.gd`
- Test: `city/godot/tests/test_settings.gd`

**Interfaces:**
- Produces: `class_name Settings extends RefCounted`.
  - `const PATH := "user://settings.cfg"` and `const DEFAULTS := {...}`.
  - `var path := PATH`, overridable by tests.
  - `func load_file() -> void`: reads `path`. A missing or corrupt file gives the defaults. Unknown sections and keys are kept, so that they are written back.
  - `func save() -> void`
  - `func get_value(section: String, key: String)`: returns the default when unset.
  - `func set_value(section: String, key: String, value) -> void`: saves and emits `changed(section, key)`.
  - `signal changed(section: String, key: String)`
  - `static func frame_policy(settings: Settings, refresh_hz: float, cmd_fps: int) -> Dictionary`: returns `{vsync, max_fps}`. A `cmd_fps` other than -1 (the `--fps` argument) wins and comes from `FramePacing.policy`. Otherwise it maps the settings' `graphics/vsync` and `graphics/frame_cap`.
  - `func text_scale() -> float`
  - `func developer() -> bool`
  - `func calm() -> bool`

- [ ] **Step 1: Write the failing test.** `DEFAULTS`, exactly:

```gdscript
const DEFAULTS := {
	"graphics": {"display": "windowed", "vsync": true, "frame_cap": 0, "quality": "high"},
	"controls": {"mouse_sensitivity": 1.0, "stick_sensitivity": 1.0, "invert_y": false, "bindings": {}},
	"interface": {"names": false, "text_size": 1.0, "join_as": "", "look": "0,0", "style": ""},
	"accessibility": {"calm": false},
	"developer": {"tools": false},
}
```

A `frame_cap` of 0 means the display's rate. -1 means unlimited, with vsync off. Any N > 0 is a cap of N.

`city/godot/tests/test_settings.gd`:

```gdscript
extends TestSuite

func fresh(name: String) -> Settings:
	var s := Settings.new()
	s.path = "user://test_settings_%s.cfg" % name
	DirAccess.remove_absolute(ProjectSettings.globalize_path(s.path))
	return s


func test_missing_file_gives_defaults() -> void:
	var s := fresh("missing")
	s.load_file()
	assert_eq(s.get_value("graphics", "quality"), "high", "quality")
	assert_eq(s.get_value("accessibility", "calm"), false, "calm")
	assert_eq(s.text_scale(), 1.0, "text scale")
	assert_true(not s.developer(), "developer tools off")


func test_values_round_trip_through_the_file() -> void:
	var s := fresh("round")
	s.load_file()
	s.set_value("interface", "text_size", 1.25)
	s.set_value("controls", "bindings", {"interact": {"key": 69}})
	var t := Settings.new()
	t.path = s.path
	t.load_file()
	assert_eq(t.text_scale(), 1.25, "text size kept")
	assert_eq(t.get_value("controls", "bindings"), {"interact": {"key": 69}}, "bindings kept")


func test_a_corrupt_file_gives_defaults_without_error() -> void:
	var s := fresh("corrupt")
	var f := FileAccess.open(s.path, FileAccess.WRITE)
	f.store_string("[graphics\nquality = = ")
	f.close()
	s.load_file()
	assert_eq(s.get_value("graphics", "quality"), "high", "default after a corrupt file")


func test_unknown_keys_survive_a_save() -> void:
	var s := fresh("unknown")
	var cf := ConfigFile.new()
	cf.set_value("future", "thing", 3)
	cf.save(s.path)
	s.load_file()
	s.set_value("graphics", "quality", "low")
	var back := ConfigFile.new()
	back.load(s.path)
	assert_eq(back.get_value("future", "thing", 0), 3, "a newer version's key is kept")


func test_set_value_announces_the_change() -> void:
	var s := fresh("signal")
	s.load_file()
	var seen := []
	s.changed.connect(func(sec, key): seen.append([sec, key]))
	s.set_value("accessibility", "calm", true)
	assert_eq(seen, [["accessibility", "calm"]], "changed")
	assert_true(s.calm(), "calm on")


func test_frame_policy_follows_settings_unless_fps_is_given() -> void:
	var s := fresh("fps")
	s.load_file()
	assert_eq(Settings.frame_policy(s, 360.0, -1), {"vsync": true, "max_fps": 0}, "display rate by default")
	s.set_value("graphics", "frame_cap", 120)
	assert_eq(Settings.frame_policy(s, 360.0, -1), {"vsync": true, "max_fps": 120}, "a cap with vsync")
	s.set_value("graphics", "frame_cap", -1)
	assert_eq(Settings.frame_policy(s, 360.0, -1), {"vsync": false, "max_fps": 0}, "unlimited")
	assert_eq(Settings.frame_policy(s, 360.0, 90), {"vsync": false, "max_fps": 90}, "--fps wins")
```

- [ ] **Step 2: Run it and see it fail.** `godot --headless --path city/godot --script res://tests/run_all.gd -- test_settings`. Expected: FAIL, because `settings.gd` does not compile.
- [ ] **Step 3: Implement `settings.gd`.** Use `ConfigFile`, and keep the loaded `ConfigFile` whole so that unknown keys survive. On a `load()` error, start from an empty `ConfigFile`. `get_value` falls back to `DEFAULTS[section][key]`. Doc comments follow the code's voice.
- [ ] **Step 4: Run the test (PASS), then the whole suite (all green).**
- [ ] **Step 5: Commit** with `feat(city): settings file with defaults and frame policy`.

---

### Task 2: UiTheme

**Files:**
- Create: `city/godot/core/ui/ui_theme.gd`
- Test: `city/godot/tests/test_ui_theme.gd`

**Interfaces:**
- Produces: `class_name UiTheme extends RefCounted`.
  - `const DEFAULT := {...}`: the neutral skin. Its values are the spec's section 7 example block: colours as given, `panel` rounded with radius 14, border 1 and shadow 8, `button` rounded with radius 10, case `title` and height 48, `focus` `ring`, `text_size` 20, `pixel_font` false, `frame` null, and no fonts.
  - `static func from_style(style: Dictionary, text_scale := 1.0) -> UiTheme`: deep-merges `style.get("ui", {})` over `DEFAULT`.
  - `var spec: Dictionary`: the merged block.
  - `var theme: Theme`: a built Godot theme. It sets:
    - `PanelContainer` and `Panel` `panel` styleboxes;
    - `Button` `normal`, `hover`, `pressed`, `focus` and `disabled` styleboxes, with font colours;
    - `Label` font and colour;
    - `LineEdit`, `OptionButton`, `CheckButton`, `HSlider`, `TabBar` and `TabContainer` basics;
    - `default_font` and `default_font_size`.
  - `var display_font: Font` and `var body_font: Font`: loaded from `font_display` and `font_body` when those resources exist, else `ThemeDB.fallback_font`.
  - `func font_size(base: int) -> int`: `round(base * text_scale)`. For a pixel font (`pixel_font` true) it is `pixel_base * max(1, floor(base * text_scale / pixel_base + 0.49))`, where `pixel_base` (in the `ui` block) defaults to 10, so pixel type only takes whole-number steps.
  - `func colour(name: String) -> Color`
  - `static func contrast(a: Color, b: Color) -> float`: the WCAG ratio, `(L1 + 0.05) / (L2 + 0.05)` with sRGB linearisation.
  - `func case(text: String) -> String`: applies `button.case`, `upper` or `title`.
  - `func focus_mode() -> String`: `ring`, `glow` or `underline`.
  - Styleboxes: `rounded` builds a `StyleBoxFlat` with that corner radius; `square` uses radius 0; `nine` builds a `StyleBoxTexture` from `frame.texture`, with `frame.margin` on all four sides, and sets `texture_filter` to nearest when `pixel_font` is on.
  - Focus: the `focus` stylebox is a `StyleBoxFlat` with a transparent fill, `border_width` 3, `border_color` = `focus` and `expand_margin` 2. `underline` sets only the bottom border, 3 px.

- [ ] **Step 1: Write the failing test.**

```gdscript
extends TestSuite

func style(ui: Dictionary) -> Dictionary:
	return {"name": "T", "ui": ui}


func test_defaults_fill_a_style_without_a_ui_block() -> void:
	var t := UiTheme.from_style({"name": "Plain"})
	assert_eq(t.colour("panel"), Color("#F7F8FB"), "default panel")
	assert_eq(t.focus_mode(), "ring", "default focus")
	assert_true(t.theme.has_stylebox("panel", "PanelContainer"), "panel stylebox")
	assert_true(t.theme.has_stylebox("focus", "Button"), "focus stylebox")


func test_a_style_overrides_only_what_it_names() -> void:
	var t := UiTheme.from_style(style({"colours": {"accent": "#FF0000"}, "button": {"case": "upper"}}))
	assert_eq(t.colour("accent"), Color("#FF0000"), "accent overridden")
	assert_eq(t.colour("ink"), Color("#1F2433"), "ink kept from default")
	assert_eq(t.case("resume game"), "RESUME GAME", "upper case")
	assert_eq(int(t.spec["button"]["radius"]), 10, "nested default kept")


func test_contrast_matches_known_ratios() -> void:
	assert_true(absf(UiTheme.contrast(Color.BLACK, Color.WHITE) - 21.0) < 0.01, "black on white is 21")
	assert_true(absf(UiTheme.contrast(Color("#777777"), Color.WHITE) - 4.48) < 0.02, "#777 on white is 4.48")


func test_text_size_scales_and_pixel_fonts_snap() -> void:
	assert_eq(UiTheme.from_style({}, 1.25).font_size(20), 25, "scaled")
	var px := UiTheme.from_style(style({"pixel_font": true, "pixel_base": 10}), 1.25)
	assert_eq(px.font_size(20), 20, "pixel font snaps to a whole multiple of 10")
	var px2 := UiTheme.from_style(style({"pixel_font": true, "pixel_base": 10}), 1.5)
	assert_eq(px2.font_size(20), 30, "1.5x of 20 is 30, a whole multiple")


func test_every_style_meets_the_contrast_floors() -> void:
	for dir in ["anime_cel", "solarpunk", "neon_noir", "pixel_art", "lowpoly_tropical", "voxel"]:
		var f := FileAccess.open("res://styles/%s/style.json" % dir, FileAccess.READ)
		var t := UiTheme.from_style(JSON.parse_string(f.get_as_text()))
		assert_true(UiTheme.contrast(t.colour("ink"), t.colour("panel")) >= 4.5, dir + ": ink on panel")
		assert_true(UiTheme.contrast(t.colour("accent_ink"), t.colour("accent")) >= 4.5, dir + ": accent ink")
		assert_true(UiTheme.contrast(t.colour("focus"), t.colour("panel")) >= 3.0, dir + ": focus")
```

The pixel rule rounds half down on purpose: 1.25 × 20 / 10 = 2.5 gives 2 (20 px), and 1.5 gives 3 (30 px). A pixel face has only whole steps, so 125% is the same as 100% for it.

- [ ] **Step 2: Run it and see it fail** with `-- test_ui_theme`.
- [ ] **Step 3: Implement `ui_theme.gd`.** Do the deep merge by hand, recursing into dictionaries. Colours may carry alpha (`#RRGGBBAA`); `Color(hex)` accepts that.
- [ ] **Step 4: Run it: PASS.** The last test passes on defaults, since no style has a `ui` block yet. Then run the whole suite.
- [ ] **Step 5: Commit** with `feat(city): UiTheme builds a Godot theme from a style's ui block`.

---

### Task 3: InputGlyphs

**Files:**
- Create: `city/godot/core/ui/input_glyphs.gd`
- Create: `city/godot/core/ui/glyphs/` with one SVG per face button (`a.svg`, `b.svg`, `x.svg`, `y.svg`), plus `lb.svg`, `rb.svg`, `lt.svg`, `rt.svg`, `ls.svg`, `rs.svg`, `start.svg`, `back.svg`, `dpad.svg`, `dpad_up.svg`, `dpad_down.svg`, `dpad_left.svg` and `dpad_right.svg`. Each is 64×64: a dark rounded shape with a light letter or symbol.
- Test: `city/godot/tests/test_input_glyphs.gd`

**Interfaces:**
- Produces: `class_name InputGlyphs extends RefCounted`.
  - `var device := "keys"`: `"keys"` or `"pad"`.
  - `signal device_changed(device: String)`
  - `func note(event: InputEvent) -> void`:
    - keys, the mouse, and mouse motion over 4 px set `"keys"`;
    - joypad buttons, and joypad motion over 0.5, set `"pad"`;
    - it emits only on a change.
  - `func label(action: String) -> String`: the first event of that action in the `InputMap` for the current device. For keys it is `OS.get_keycode_string` of the physical keycode or keycode, e.g. "Esc", "M" or "Space". For pad it is the button's name: A, B, X, Y, LB, RB, LT, RT, LS, RS, Start, Back, or "D-pad Up" and the other three directions. An action with no event for that device gives "".
  - `func icon(action: String) -> Texture2D`: for pad, the SVG of the button; for keys, null (keys are drawn as text in a keycap).
  - `static func button_name(index: int) -> String`: Godot's `JoyButton` indices 0–14 map to A, B, X, Y, Back, Guide, Start, LS, RS, LB, RB, and the four d-pad directions.

- [ ] **Step 1: Write the failing test.**

```gdscript
extends TestSuite

func key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func pad(button: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e


func test_labels_follow_the_last_device() -> void:
	var g := InputGlyphs.new()
	var seen := []
	g.device_changed.connect(func(d): seen.append(d))
	assert_eq(g.label("toggle_fpv"), "F", "keyboard first")
	g.note(pad(JOY_BUTTON_A))
	assert_eq(g.device, "pad", "pad after a button")
	assert_eq(g.label("toggle_fpv"), "Back", "the pad's button for first person")
	g.note(key(KEY_W))
	assert_eq(seen, ["pad", "keys"], "announced each change once")


func test_small_stick_drift_does_not_switch_device() -> void:
	var g := InputGlyphs.new()
	var m := InputEventJoypadMotion.new()
	m.axis = JOY_AXIS_LEFT_X
	m.axis_value = 0.2
	g.note(m)
	assert_eq(g.device, "keys", "drift ignored")


func test_pad_actions_have_icons_and_keys_do_not() -> void:
	var g := InputGlyphs.new()
	g.note(pad(JOY_BUTTON_B))
	assert_true(g.icon("cancel") is Texture2D, "pad icon")
	g.note(key(KEY_A))
	assert_eq(g.icon("cancel"), null, "no icon for keys")


func test_rebinding_changes_the_label() -> void:
	var g := InputGlyphs.new()
	var old := InputMap.action_get_events("names")
	InputMap.action_erase_events("names")
	InputMap.action_add_event("names", key(KEY_K))
	assert_eq(g.label("names"), "K", "follows the input map")
	InputMap.action_erase_events("names")
	for e in old:
		InputMap.action_add_event("names", e)
```

- [ ] **Step 2: Run it and see it fail** with `-- test_input_glyphs`.
- [ ] **Step 3: Implement it, and write the SVGs** (simple, legible, the same shape family).
- [ ] **Step 4: Run it: PASS.** Then run the import and the whole suite.
- [ ] **Step 5: Commit** with `feat(city): input glyphs follow the last device`.

---

### Task 4: ScreenStack, Screen, and the router gate

**Files:**
- Create: `city/godot/core/ui/screen.gd` and `city/godot/core/ui/screen_stack.gd`
- Modify: `city/godot/core/input_router.gd`
- Test: `city/godot/tests/test_screen_stack.gd`

**Interfaces:**
- Produces:
  - `class_name Screen extends Control`:
    - `var stack: ScreenStack`
    - `var ui: UiTheme`
    - `var last_focus: Control`
    - `func build() -> void`: virtual; builds the children.
    - `func apply_theme(t: UiTheme) -> void`: sets `theme = t.theme` and calls `restyle()`.
    - `func restyle() -> void`: virtual.
    - `func focus_first() -> void`: focuses `last_focus` when it is valid and visible, else the first focusable descendant.
    - `func on_back() -> bool`: virtual. It returns false by default; the stack then pops the screen.
    - `func wants_world_input() -> bool`: false by default. The play HUD overrides it to true.

    The anchors are full rect, and `mouse_filter` is STOP.
  - `class_name ScreenStack extends CanvasLayer`, on layer 20:
    - `var screens: Array[Screen]`
    - `var ui: UiTheme`
    - `var router: InputRouter`
    - `signal changed(top: Screen)`
    - `func push(s: Screen) -> void`: adds the screen, applies `ui`, calls `build()` if it hasn't been built, focuses it, and updates the gate.
    - `func pop() -> void`: frees the top screen and refocuses the new top.
    - `func top() -> Screen`
    - `func clear() -> void`
    - `func set_theme(t: UiTheme) -> void`: re-applies to every screen and keeps each screen's focus.
    - `func back() -> void`: `if not top().on_back(): pop()`.
    - `_unhandled_input`: `ui_cancel` while a screen is open calls `back()` and marks the event handled.
    - The gate: `router.world_enabled = screens.is_empty() or top().wants_world_input()`.
  - `InputRouter` gains `var world_enabled := true` with a setter:
    - Setting it false calls `_forget` for every source, which zeroes steering and looking and clears held state, and emits `steer(Vector2.ZERO)` if steering was non-zero.
    - While it is false, `handle()` emits no intents, so movement is not tracked; walk_to, presses and interact are all skipped.
    - `_track_moves` does not run while it is false, so a W released inside a menu leaves nothing held. On re-enabling, the actions currently pressed are *not* re-read: a key still held must be pressed again. This is the Review Focus 1 behaviour.

- [ ] **Step 1: Write the failing test.**

```gdscript
extends TestSuite

class Probe extends Screen:
	var built := 0
	var backs := 0
	var eat_back := false
	func build() -> void:
		built += 1
		var b := Button.new()
		b.name = "First"
		add_child(b)
		var c := Button.new()
		c.name = "Second"
		add_child(c)
	func on_back() -> bool:
		backs += 1
		return eat_back


func setup() -> Array:
	var r := InputRouter.new()
	runner.root.add_child(r)
	var s := ScreenStack.new()
	s.router = r
	s.ui = UiTheme.from_style({})
	runner.root.add_child(s)
	return [s, r]


func key(code: int, pressed := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e


func test_push_builds_focuses_and_gates_the_world() -> void:
	var sr := setup()
	var s: ScreenStack = sr[0]
	var r: InputRouter = sr[1]
	var p := Probe.new()
	s.push(p)
	await runner.process_frame
	assert_eq(p.built, 1, "built once")
	assert_eq(p.get_viewport().gui_get_focus_owner(), p.get_node("First"), "first control focused")
	assert_true(not r.world_enabled, "world input off")
	s.pop()
	assert_true(r.world_enabled, "world input back")
	s.free()
	r.free()


func test_a_key_held_when_a_screen_opens_stops_and_stays_stopped() -> void:
	var sr := setup()
	var s: ScreenStack = sr[0]
	var r: InputRouter = sr[1]
	r.handle(key(KEY_W))
	assert_true(r.steering != Vector2.ZERO, "walking")
	s.push(Probe.new())
	assert_eq(r.steering, Vector2.ZERO, "stopped when the menu opened")
	r.handle(key(KEY_W, false))
	s.pop()
	assert_eq(r.steering, Vector2.ZERO, "not walking after the menu closes")
	s.free()
	r.free()


func test_back_asks_the_screen_first() -> void:
	var sr := setup()
	var s: ScreenStack = sr[0]
	var a := Probe.new()
	var b := Probe.new()
	s.push(a)
	s.push(b)
	b.eat_back = true
	s.back()
	assert_eq(s.top(), b, "screen handled back itself")
	b.eat_back = false
	s.back()
	assert_eq(s.top(), a, "popped to the one below")
	s.free()
	sr[1].free()


func test_focus_is_restored_when_a_screen_is_uncovered() -> void:
	var sr := setup()
	var s: ScreenStack = sr[0]
	var a := Probe.new()
	s.push(a)
	await runner.process_frame
	a.get_node("Second").grab_focus()
	s.push(Probe.new())
	s.pop()
	await runner.process_frame
	assert_eq(a.get_viewport().gui_get_focus_owner(), a.get_node("Second"), "focus came back")
	s.free()
	sr[1].free()


func test_a_theme_change_reaches_every_screen() -> void:
	var sr := setup()
	var s: ScreenStack = sr[0]
	var a := Probe.new()
	s.push(a)
	var t := UiTheme.from_style({"ui": {"colours": {"panel": "#000000"}}})
	s.set_theme(t)
	assert_eq(a.theme, t.theme, "reskinned")
	s.free()
	sr[1].free()
```

- [ ] **Step 2: Run it and see it fail** with `-- test_screen_stack`.
- [ ] **Step 3: Implement the stack and the gate.** When a screen is pushed, the stack records the current focus owner into the covered screen's `last_focus`.
- [ ] **Step 4: Run it: PASS.** Then the whole suite, including `test_input`, which must stay green.
- [ ] **Step 5: Commit** with `feat(city): screen stack takes input from the world while a screen is open`.

---

### Task 5: The play HUD

**Files:**
- Create: `city/godot/core/ui/play_hud.gd`
- Test: `city/godot/tests/test_play_hud.gd`

**Interfaces:**
- Consumes: `UiTheme`, `InputGlyphs` and `Screen` (Tasks 2–4).
- Produces: `class_name PlayHud extends Screen`. It overrides `wants_world_input()` to return true. It is pushed as the stack's bottom screen in play; on the title it is hidden.
  - `var fixture: Label`: text exactly `"Fixture data — not real agent state"`, at the bottom left, always visible, including while `error_label` shows.
  - `var prompt: Control`: at bottom centre, holding a glyph (key or icon) and a label.
    - `func set_prompt(action: String, text: String) -> void`: an empty `text` hides it.
    - `var prompt_label: Label`
  - `var crosshair: Label`: "+" at the centre. `func show_crosshair(on: bool)`.
  - `var clock: Label` and `var weather_icon: TextureRect`: at the top right. `func set_clock(minutes: int, rain: float)`:
    - the text is `"%02d:%02d"`;
    - the icon is rain when `rain > 0.05`, else a sun from 06:30 to 18:30, else a moon;
    - the icons are drawn as small SVGs under `core/ui/glyphs/` (`sun.svg`, `moon.svg` and `rain.svg`);
    - it is hidden when `minutes < 0`.
  - Notices:
    - `func notify(text: String, button := "", action := Callable()) -> void`: adds a notice at the top centre. At most two show; a third drops the oldest.
    - Each fades after `NOTICE_S := 4.0` seconds, unless it has a button, which keeps it until pressed or `dismiss_notices()`.
    - `var notices: Array[Control]`
    - `func tick(delta: float)` advances the timers, and `_process` calls it.
  - Hints:
    - `var hints: Label`, at the bottom right: `"%s Menu · %s Map" % [glyphs.label("menu"), glyphs.label("map")]`.
    - It fades (modulate a → 0) after `HINTS_S := 10.0` seconds of play, and comes back on `glyphs.device_changed` or `show_hints()`.
  - Errors:
    - `var error_label: Label`
    - `func show_error(text: String)`: shows it and `printerr("city: " + text.replace("\n", " "))`, exactly as `Hud.show_error` does. The smoke test depends on the `city: ` line.
  - `var status_text := ""` and `func set_player(state: String, observer: bool)`: stores "Visitor · walking" or "Observer · …" for the game menu's header. Nothing is shown in the HUD.
  - `func show_controls(on: bool)`: hides everything but `fixture` (for `--no-hud` captures).
  - `var glyphs: InputGlyphs`: set by main before `build()`.

- [ ] **Step 1: Write the failing test.**

```gdscript
extends TestSuite

func hud() -> PlayHud:
	var h := PlayHud.new()
	h.glyphs = InputGlyphs.new()
	h.ui = UiTheme.from_style({})
	runner.root.add_child(h)
	h.build()
	h.apply_theme(h.ui)
	return h


func test_the_fixture_notice_is_always_shown() -> void:
	var h := hud()
	assert_eq(h.fixture.text, "Fixture data — not real agent state", "exact text")
	h.show_error("boom")
	h.show_controls(false)
	assert_true(h.fixture.visible, "still visible over an error and with controls hidden")
	h.free()


func test_notices_fade_and_at_most_two_show() -> void:
	var h := hud()
	h.notify("one")
	h.notify("two")
	h.notify("three")
	assert_eq(h.notices.size(), 2, "two at most")
	assert_eq(h.notices[0].get_meta("text"), "two", "the oldest went")
	h.tick(4.1)
	assert_eq(h.notices.size(), 0, "faded after 4 s")
	h.free()


func test_a_notice_with_a_button_waits_for_it() -> void:
	var h := hud()
	var hit := []
	h.notify("First person is 3D only", "Switch to low-poly", func(): hit.append(1))
	h.tick(10.0)
	assert_eq(h.notices.size(), 1, "kept")
	h.notices[0].find_child("Action", true, false).pressed.emit()
	assert_eq(hit, [1], "ran the action")
	assert_eq(h.notices.size(), 0, "and closed")
	h.free()


func test_the_prompt_shows_the_action_and_hides_when_empty() -> void:
	var h := hud()
	h.set_prompt("interact", "Sit")
	assert_true(h.prompt.visible, "shown")
	assert_eq(h.prompt_label.text, "Sit", "text")
	h.set_prompt("interact", "")
	assert_true(not h.prompt.visible, "hidden")
	h.free()


func test_clock_and_weather() -> void:
	var h := hud()
	h.set_clock(516, 0.0)
	assert_eq(h.clock.text, "08:36", "clock")
	assert_eq(h.weather_icon.get_meta("kind"), "sun", "day")
	h.set_clock(1300, 0.0)
	assert_eq(h.weather_icon.get_meta("kind"), "moon", "night")
	h.set_clock(1300, 0.5)
	assert_eq(h.weather_icon.get_meta("kind"), "rain", "rain")
	h.free()


func test_hints_fade_after_ten_seconds_and_return_on_a_device_change() -> void:
	var h := hud()
	h.tick(10.5)
	assert_true(h.hints.modulate.a < 0.05, "faded")
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_A
	e.pressed = true
	h.glyphs.note(e)
	assert_true(h.hints.modulate.a > 0.95, "back after the device changed")
	h.free()


func test_errors_are_logged_for_headless_runs() -> void:
	var h := hud()
	h.show_error("The world did not load")
	assert_true(h.error_label.visible, "shown")
	h.free()
```

- [ ] **Step 2: Run it and see it fail** with `-- test_play_hud`.
- [ ] **Step 3: Implement `play_hud.gd`** and the three weather SVGs. Style every text from `ui` (`body_font`, `font_size(20)`, `ink`). Put `fixture`, `prompt`, `clock` and `hints` on small translucent panel chips in the skin's `panel` colour at 85% alpha, so they read over any scene. The crosshair and prompt keep a 4 px black outline, as today.
- [ ] **Step 4: Run it: PASS.** Then the whole suite.
- [ ] **Step 5: Commit** with `feat(city): the in-play HUD`.

---

### Task 6: The developer panel

**Files:**
- Create: `city/godot/core/ui/dev_panel.gd`
- Test: `city/godot/tests/test_dev_panel.gd`, which replaces `tests/test_hud.gd` in Task 7. Port every behaviour `test_hud.gd` checks that the panel now owns: names excluded, since names move to settings and the N key.

**Interfaces:**
- Produces: `class_name DevPanel extends CanvasLayer`, on layer 30, with the same intent signals and methods as `Hud`'s developer half, so main's wiring moves across unchanged:
  - signals: `style_requested(dir)`, `viewer_requested(viewer)`, `pause_toggled(paused)`, `step_requested`, `speed_changed(speed)`, `open_all_toggled(on)`, `roofs_toggled(on)` and `camera_requested(preset)`;
  - methods: `setup(styles: Array, viewers: Array)`, `set_status(tick, minutes, viewer, style)`, `toggle_open_all()`, `toggle_roofs()`, `request_camera(preset)`, `toggle_pause()`, `request_step()`, `change_speed(direction)`, `pick_style(index)`, `step_style(direction)`, `show_style(dir)`, `show_viewer(viewer)` and `step_viewer(direction)`;
  - vars: `SPEEDS := [1, 2, 4, 8]`, `speed`, `paused`, `open_all`, `roofs_on`, `style_dirs`, `style_index` and `viewer_ids`.
  - `var enabled := false`: whether the developer tools are on, from the settings or `--dev`. `func toggle()` shows or hides the panel, but only when `enabled`. It starts hidden.
  - `toggle_roofs` emits its note through `signal note(text)`, not `show_note`: main forwards it to `PlayHud.notify`.
  - The skin is fixed: a dark translucent panel, a monospace `SystemFont` ("monospace"), 14 px text. Its controls are a single compact `VBoxContainer`:
    - a status label;
    - a row of ⏯ ⏭ − + buttons;
    - the viewer `OptionButton`;
    - Open all and Roofs as `CheckButton`s;
    - Top-down, Diagonal and Street buttons;
    - a style `OptionButton` listing the styles.
  - `func shortcuts_active() -> bool`: `enabled`.

- [ ] **Step 1: Write the failing tests.** Port `test_hud.gd`'s `test_intents_request_styles_speed_and_pause` and its viewer and camera tests to `DevPanel`, then add:

```gdscript
func test_hidden_until_enabled_and_toggled() -> void:
	var d := DevPanel.new()
	runner.root.add_child(d)
	d.setup([{"dir": "res://a", "name": "A"}], ["public"])
	assert_true(not d.visible, "hidden by default")
	d.toggle()
	assert_true(not d.visible, "F3 does nothing while developer tools are off")
	d.enabled = true
	d.toggle()
	assert_true(d.visible, "shown when enabled")
	d.free()
```

- [ ] **Step 2: Run them and see them fail** with `-- test_dev_panel`.
- [ ] **Step 3: Implement `dev_panel.gd`,** moving the logic from `hud.gd`'s intent section.
- [ ] **Step 4: Run them: PASS.**
- [ ] **Step 5: Commit** with `feat(city): the developer panel`.

---

### Task 7: Wire the new HUD, developer panel and stack into the client

**Files:**
- Modify: `city/godot/main.gd`, `city/godot/core/input_router.gd`, `city/godot/core/args.gd` and `city/godot/project.godot`
- Delete: `city/godot/core/hud.gd` (and its `.uid`) and `city/godot/tests/test_hud.gd`
- Modify tests that use `main.hud`:
  - `tests/test_main.gd`, `test_first_person.gd`, `test_switch_live.gd`, `test_gate.gd`, `test_avatar.gd`, `test_gate_player.gd`, `test_spec_controls.gd` and `test_input.gd`;
  - `tools/sheet_views.gd`, `tools/bench.gd` and `tools/audit.gd`, if they touch `hud`.

**Interfaces:**
- Consumes: Tasks 1–6.
- Produces, in `main.gd`:
  - `var settings := Settings.new()` (loaded in `boot`), `var glyphs := InputGlyphs.new()`, `var stack := ScreenStack.new()`, `var hud := PlayHud.new()` and `var dev := DevPanel.new()`.
  - `var ui: UiTheme`: rebuilt on every style activation from `host.pack.style` and `settings.text_scale()`, then applied with `stack.set_theme(ui)`.
  - `boot(args, styles_root)` keeps its signature and its existing behaviour, including `--as`, `--capture` and the error paths. It pushes `hud` as the stack's first screen.
- Behaviour:
  - **Input map** (`project.godot`):
    - new actions: `menu` (Esc and joypad Start, 6), `map` (M and joypad left-stick press, 7) and `dev_panel` (F3);
    - `pause` loses Space and joypad Start, and keeps P;
    - `cancel` loses Esc and gains Backspace, and keeps joypad B;
    - `interact` keeps Space and joypad A.
  - **`InputRouter`:**
    - new signals: `menu`, `map` and `dev_panel`;
    - `var dev_shortcuts := false`: when false, these intents are not emitted: `style_step`, `style_pick`, `speed`, `viewer_step`, `pause`, `step`, `camera`, `open_all` and `roofs`;
    - Space is always `interact`, and never pause: remove the `first_person` / Space special case;
    - `cycle_look` (L) stays a player key.
  - **Esc (`menu`):**
    - in first person with the mouse captured, it frees the mouse and does nothing else;
    - otherwise it opens the game menu. Task 8 adds the game menu; in this task, `menu` pushes a placeholder, `Screen` subclass `MenuStub`, with a single "Resume" button. Task 8 replaces it.
  - `dev_panel` toggles `dev`. `dev.enabled = settings.developer() or options["dev"]`, and `router.dev_shortcuts = dev.enabled`.
  - Every `hud.` call in `main.gd` for developer state goes to `dev`, and player-facing notes go to `hud.notify`:
    - `set_status` feeds `dev.set_status`, and also `hud.set_clock(model.time, host.rain)`;
    - `_caption` feeds `hud.set_prompt("interact", text)` in first person;
    - overhead, the prompt shows "Sit here" when the reticle is on a seat, "Stand up" when seated, and nothing otherwise.
  - Names (N) go through `host.set_names` and are saved to `settings interface/names`.
  - `FramePacing.apply(options["fps"])` becomes `Settings.frame_policy(settings, refresh, options["fps"])`, applied the same way. Add `static func apply_policy(p: Dictionary)` to `FramePacing`, and have `FramePacing.apply` call it.
  - **`args.gd`:** add `"dev": false` and `"title": false` (flags `--dev` and `--title`), and `"play"`: true when any of `--as=`, `--look=`, `--style=`, `--camera=`, `--fpv`, `--capture=` or `--viewer=` was given. Task 10 uses `play`. In this task the client always goes straight to play, as today.
  - The `test_*` files that reach into `main.hud`:
    - `hud.error_label` stays on `PlayHud`;
    - `hud.banner` becomes `hud.fixture`;
    - `hud.controls` and `hud.status` are gone, and `--no-hud` hides the HUD's controls and the developer panel;
    - `hud.open_all` becomes `dev.open_all`;
    - `hud.show_note` becomes `hud.notify`.

    Update each test's assertion to the new owner, keeping what it checks. Add these tests to `tests/test_main.gd`:

```gdscript
func test_esc_opens_the_menu_and_holds_the_world_still() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack"]), "res://tests/fixtures")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	main.router.handle(esc)
	assert_true(main.stack.top() != main.hud, "a menu is open")
	assert_true(not main.router.world_enabled, "the world takes no input")
	main.free()


func test_developer_shortcuts_are_off_by_default_and_on_with_dev() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack"]), "res://tests/fixtures")
	assert_true(not main.router.dev_shortcuts, "off")
	assert_true(not main.dev.visible, "panel hidden")
	main.free()
	var dev = load("res://main.gd").new()
	runner.root.add_child(dev)
	dev.boot(PackedStringArray(["--crowd=0", "--style=fake_pack", "--dev"]), "res://tests/fixtures")
	assert_true(dev.router.dev_shortcuts, "on with --dev")
	dev.free()


func test_space_acts_and_never_pauses() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack", "--dev"]), "res://tests/fixtures")
	var sp := InputEventKey.new()
	sp.keycode = KEY_SPACE
	sp.physical_keycode = KEY_SPACE
	sp.pressed = true
	main.router.handle(sp)
	assert_true(not main.driver.paused, "Space does not pause")
	main.free()
```

  The tests' `boot` must not read or write the real `user://settings.cfg`. `main` gains `var settings_path := Settings.PATH`, which tests may set before `boot`. Test boots that don't set it use a per-run temp path: when `OS.get_cmdline_args()` contains `res://tests/run_all.gd`, `main` uses `user://settings_test.cfg`, deleted at the suite's start by `run_all.gd`. Add that deletion to `run_all.gd`'s `_init`.

- [ ] **Step 1: Write the new `test_main.gd` tests** above, and update `test_input.gd`'s `ACTIONS` to add `"menu"`, `"map"` and `"dev_panel"`. Run them and see them fail.
- [ ] **Step 2: Make the changes above.**
- [ ] **Step 3: Run the whole suite until it is green.** Every previously passing behaviour must still pass under its new owner. No test may be deleted except `test_hud.gd`, whose content Task 6 moved.
- [ ] **Step 4: Check it on screen.**
  ```
  godot --path city/godot --resolution 1920x1080 -- --style=anime_cel --ticks=40 --capture=/tmp/hud-after.png
  ```
  Look at the capture. Only the fixture notice, the clock chip and the hints may show; the old button row must be gone.
- [ ] **Step 5: Commit** with `feat(city): the game HUD replaces the harness controls; developer tools behind F3`.

---

### Task 8: The game menu and the style picker

**Files:**
- Create: `city/godot/core/ui/screens/game_menu.gd` and `city/godot/core/ui/screens/style_picker.gd`
- Create: `city/godot/tools/style_previews.gd`, and `city/godot/styles/<pack>/assets/preview.png` for all six styles
- Modify: `city/godot/main.gd`, which replaces `MenuStub`
- Test: `city/godot/tests/test_game_menu.gd`

**Interfaces:**
- Produces:
  - `class_name GameMenu extends Screen`:
    - `signal resume`, `signal open_map`, `signal open_style`, `signal open_settings`, `signal quit_to_title` and `signal quit_game`;
    - `var header: Label`, set by main to `hud.status_text`, or "Watching" without a player;
    - buttons named, in order: "Resume", "Map", "Visual style", "Settings", "Quit to title" and "Quit", each with its text through `ui.case()`;
    - "Quit" is hidden when `OS.has_feature("web")`;
    - the panel is centred, 420 px wide, over a full-rect `ColorRect` in the skin's `scrim` colour;
    - `on_back()` returns false, so Back pops it and resumes.
  - `class_name StylePicker extends Screen`:
    - `var styles: Array`, of `[{dir, name}]` in `order`;
    - `var current := ""`;
    - `signal chosen(dir: String)`;
    - a `GridContainer` with 3 columns of cards. Each card is a `Button` named after the style's directory name, showing its `preview.png` (a `TextureRect`, 480×270, shown at 320×180) and its name. When a pack has no preview, the card shows the name on the accent colour.
    - Choosing a card emits `chosen`, and the screen stays open. Main activates the style, re-themes the stack, and the picker keeps focus on the chosen card (`last_focus`).
    - The focus neighbours must let the d-pad reach every card.
  - `main.gd`:
    - `menu` pushes a `GameMenu`;
    - `resume` pops it;
    - `open_style` pushes a `StylePicker` that shows the current style;
    - `chosen(dir)` calls `_activate(dir)`, which rebuilds `ui` and calls `stack.set_theme`, then saves `interface/style`;
    - `open_map` is connected in the map plan; until then, the "Map" button is hidden (`visible = false`) behind a `var map_available := false` in `GameMenu`;
    - `open_settings` is connected in Task 9; until then, it is hidden the same way;
    - `quit_to_title` is connected in Task 10; hidden until then;
    - `quit_game` calls `get_tree().quit()`.
- `tools/style_previews.gd` (a `SceneTree` script, run on a display):
  - For each style it boots `main` with `--crowd=60 --style=<dir> --as=none`, pauses at tick 150 (10:00), sets the diagonal camera and hides the HUD.
  - It captures the viewport, scales it to 480×270 (Lanczos) and saves `res://styles/<dir>/assets/preview.png`.
  - Run: `godot --path city/godot --resolution 1920x1080 --script res://tools/style_previews.gd`.

- [ ] **Step 1: Write the failing tests.**

```gdscript
extends TestSuite

func booted():
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack"]), "res://tests/fixtures")
	return main


func esc() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.physical_keycode = KEY_ESCAPE
	e.pressed = true
	return e


func test_esc_opens_the_menu_and_back_resumes() -> void:
	var main = booted()
	main.router.handle(esc())
	assert_true(main.stack.top() is GameMenu, "menu open")
	main.stack.back()
	assert_eq(main.stack.top(), main.hud, "back to play")
	assert_true(main.router.world_enabled, "world input back")
	main.free()


func test_the_menu_lists_its_actions_in_order() -> void:
	var main = booted()
	main.router.handle(esc())
	var m: GameMenu = main.stack.top()
	var names := []
	for b in m.find_children("*", "Button", true, false):
		if b.visible:
			names.append(b.name)
	assert_eq(names.slice(0, 1), ["Resume"], "Resume first")
	assert_true("Visual style" in names, "style picker reachable")
	main.free()


func test_choosing_a_style_reskins_and_keeps_focus() -> void:
	var main = booted()
	main.router.handle(esc())
	main.stack.top().open_style.emit()
	var picker: StylePicker = main.stack.top()
	assert_true(picker is StylePicker, "picker open")
	var before = main.stack.ui
	picker.chosen.emit(picker.styles[0]["dir"])
	assert_true(main.stack.top() == picker, "picker stays open")
	assert_true(main.stack.ui != before, "theme rebuilt for the new pack")
	main.free()
```

- [ ] **Step 2: Run them and see them fail** with `-- test_game_menu`.
- [ ] **Step 3: Implement the menu and the picker, and wire them in `main.gd`.**
- [ ] **Step 4: Run them: PASS.** Then the whole suite.
- [ ] **Step 5: Generate the previews** with the tool, on the display. Look at all six.
- [ ] **Step 6: Commit** with `feat(city): game menu and live style picker, with previews`.

---

### Task 9: Settings and rebinding screens, and applying the settings

**Files:**
- Create: `city/godot/core/ui/screens/settings_screen.gd` and `city/godot/core/ui/screens/rebind.gd`
- Modify:
  - `main.gd`: connects settings changes;
  - `core/frame_pacing.gd`;
  - `styles/pack_3d.gd`: quality;
  - `styles/style_pack.gd`: the `quality_low` and `calm` vars;
  - `core/style_host.gd`: passes them on;
  - `core/orbit_rig.gd`: calm cuts, only if needed here;
  - `styles/pack_3d.gd` rain: a quarter of the particles when calm.
- Test: `city/godot/tests/test_settings_screen.gd`

**Interfaces:**
- Produces:
  - `class_name SettingsScreen extends Screen`:
    - `var settings: Settings`;
    - a `TabBar` of pages: Graphics, Controls, Interface, Accessibility and Developer. Q and E, or LB and RB, switch pages; left and right on a focused row change its value;
    - each row is an `HBoxContainer` named after its key (e.g. `frame_cap`), with a `Label` and a value control: an `OptionButton` for choices, a `CheckButton` for On/Off, or an `HSlider` for sensitivities (0.25–3.0, step 0.25);
    - the choices, in order:
      - `display`: Windowed, Fullscreen;
      - `frame_cap`: Display rate (0), 60, 120, 144, 240, Unlimited (-1);
      - `quality`: High, Low;
      - `text_size`: 100% (1.0), 125% (1.25), 150% (1.5);
      - `join_as`: Visitor (`registered`), Observer (`observer`), Just watch (`none`);
    - the Interface page's Look row is a button that pushes the Join screen's look step (Task 10). Until Task 10 lands it is hidden.
    - The Controls page has a "Rebind…" button, which pushes `RebindScreen`, and "Reset to defaults".
    - A `display` change pushes a small confirm dialog: "Keep this display setting?" with Keep and Revert. It reverts after `CONFIRM_S := 10.0` s without an answer. `func tick(delta)` drives it, for tests.
  - `class_name RebindScreen extends Screen`:
    - `const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "interact", "cancel", "menu", "map", "toggle_fpv", "zoom_in", "zoom_out", "names", "cycle_look"]`;
    - one row per action: its label, the key button and the pad button;
    - pressing a button waits for the next key or joypad button. Esc cancels the wait, unless the action being bound is `menu`;
    - `func capture(event: InputEvent)` is callable by tests. A conflict shows "Also used by <action>. Swap?" with Swap and Cancel; `func resolve(swap: bool)`;
    - bindings are saved to `settings controls/bindings` as `{action: {"key": physical_keycode, "pad": button_index}}` and applied to the `InputMap`;
    - `static func apply_bindings(settings: Settings)` runs at boot, and `static func reset(settings: Settings)` restores the `project.godot` input map. The defaults are captured once at boot with `InputMap.action_get_events` before any binding is applied.
  - Applying settings in `main.gd`, on `settings.changed`:
    - `graphics/display`: `DisplayServer.window_set_mode`, fullscreen or windowed;
    - `graphics/vsync` and `frame_cap`: `FramePacing.apply_policy(Settings.frame_policy(...))`;
    - `graphics/quality`: `host.quality_low = (value == "low")`, then `host.pack.on_shown()` to re-apply;
    - `interface/text_size`: rebuild `ui` and `stack.set_theme`;
    - `interface/names`: `host.set_names`;
    - `accessibility/calm`: `host.calm = value`;
    - `developer/tools`: `dev.enabled`, and `router.dev_shortcuts`;
    - `controls/*`: sensitivities go to `OrbitRig` and `FpvCamera` through a `look_scale` var each, and invert Y through `invert_y`. Add those vars, used where each handles mouse and stick motion.
  - `Pack3D`:
    - `var quality_low := false`, which `StyleHost` sets before `on_shown`.
    - When true, `_shadow_quality()`:
      - sets `env.ssao_enabled = false` and `env.ssr_enabled = false`;
      - halves `shadow_distance` and the shadow atlas size;
      - sets MSAA to 2× (`Viewport.MSAA_2X`), or to disabled when the style's `msaa` is 0 or it uses FXAA.
    - `var calm := false`: rain particles `amount` becomes `max(1, amount / 4)`, and streaks are off.
    - `StyleHost` sets both vars on every pack it activates.

- [ ] **Step 1: Write the failing tests.**

```gdscript
extends TestSuite

func screen() -> SettingsScreen:
	var s := Settings.new()
	s.path = "user://test_settings_screen.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(s.path))
	s.load_file()
	var sc := SettingsScreen.new()
	sc.settings = s
	sc.ui = UiTheme.from_style({})
	runner.root.add_child(sc)
	sc.build()
	return sc


func test_every_spec_setting_has_a_row() -> void:
	var sc := screen()
	for key in ["display", "vsync", "frame_cap", "quality", "mouse_sensitivity", "stick_sensitivity",
			"invert_y", "names", "text_size", "join_as", "calm", "tools"]:
		assert_true(sc.find_child(key, true, false) != null, "row " + key)
	sc.free()


func test_changing_a_row_saves_it() -> void:
	var sc := screen()
	sc.set_row("quality", "low")
	assert_eq(sc.settings.get_value("graphics", "quality"), "low", "saved")
	sc.free()


func test_a_display_change_reverts_without_an_answer() -> void:
	var sc := screen()
	sc.set_row("display", "fullscreen")
	assert_true(sc.confirming, "asks to keep it")
	sc.tick(10.5)
	assert_eq(sc.settings.get_value("graphics", "display"), "windowed", "reverted")
	sc.free()


func test_rebinding_a_key_and_a_conflict() -> void:
	var s := Settings.new()
	s.path = "user://test_rebind.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(s.path))
	s.load_file()
	RebindScreen.capture_defaults()
	var r := RebindScreen.new()
	r.settings = s
	r.ui = UiTheme.from_style({})
	runner.root.add_child(r)
	r.build()
	r.begin("names", "key")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_K
	k.keycode = KEY_K
	k.pressed = true
	r.capture(k)
	assert_eq(s.get_value("controls", "bindings")["names"]["key"], KEY_K, "saved")
	assert_true(InputMap.action_has_event("names", k), "applied")
	r.begin("cycle_look", "key")
	r.capture(k)
	assert_true(r.conflict != "", "conflict with names")
	r.resolve(true)
	assert_true(InputMap.action_has_event("cycle_look", k), "swapped onto cycle_look")
	RebindScreen.reset(s)
	var n := InputEventKey.new()
	n.physical_keycode = KEY_N
	n.keycode = KEY_N
	n.pressed = true
	assert_true(InputMap.action_has_event("names", n), "defaults back")
	r.free()


func test_low_quality_survives_a_style_switch() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=lowpoly_tropical"]))
	main.settings.set_value("graphics", "quality", "low")
	assert_true(not main.host.pack.env.ssao_enabled, "no SSAO when low")
	main.host.activate("res://styles/solarpunk", main.manifest, main.model, main.motion, 0.0)
	assert_true(main.host.pack.quality_low, "kept after switching")
	assert_true(not main.host.pack.env.ssao_enabled, "and applied")
	main.free()
```

`SettingsScreen` needs `func set_row(key: String, value)` (the same path as a UI change), `var confirming: bool` and `func tick(delta)`. `RebindScreen` needs `static func capture_defaults()`, `func begin(action, kind)` and `var conflict: String`.

- [ ] **Step 2: Run them and see them fail** with `-- test_settings_screen`.
- [ ] **Step 3: Implement the screens and apply the settings.** Show the "Settings" button in `GameMenu`.
- [ ] **Step 4: Run them: PASS.** Then the whole suite.
- [ ] **Step 5: Commit** with `feat(city): settings, rebinding, quality and calm mode`.

---

### Task 10: The title and join screens

**Files:**
- Create: `city/godot/core/ui/screens/title.gd` and `city/godot/core/ui/screens/join.gd`
- Modify: `main.gd`, `core/orbit_rig.gd` (drift and flight), `styles/style_pack.gd` (`title_drift` and `fly_to` hooks, with `Pack3D` and pixel implementations) and `core/player.gd`, only if a leave helper is needed.
- Test: `city/godot/tests/test_title.gd`

**Interfaces:**
- Produces:
  - `class_name TitleScreen extends Screen`:
    - `signal explore`, `signal map_and_read`, `signal open_settings` and `signal quit_game`;
    - a large `Label` "AGENTNAGAR" in `display_font` at `font_size(72)`, case upper;
    - buttons: "Explore", "Map & read", "Settings" and "Quit" (hidden on web). "Map & read" is hidden until the map plan sets `map_available`;
    - `on_back()` returns true: Back does nothing on the title;
    - the fixture notice is shown on the title too.
  - `class_name JoinScreen extends Screen`:
    - `signal done(as_: String, look: String)`;
    - step 1: three buttons, "Visitor", "Observer" and "Just watch";
    - step 2, skipped for Just watch: a look chooser with outfit left and right (0–7) and hair left and right (0–3). The preview is a `SubViewportContainer` with a `SubViewport` holding a lit, turning figure: the current pack's `make_occupant({"id": "person:preview", "kind": {"type": "Person"}, "appearance": {"palette": outfit, "hair": hair}})`, turning at 0.5 rad/s. Pixel art, a 2D pack, uses its sprite node in a 2D `SubViewport`. If `make_occupant` can't produce a preview for a pack, the step shows the numbers only.
    - a "Start" button emits `done`.
    - `var look_only := false`: when true, as from settings, step 1 is skipped and `done` carries the current `join_as`.
  - The camera hooks on `StylePack`:
    - `func title_drift(on: bool) -> void`, a no-op by default. `Pack3D` circles `rig.yaw` around the square's centre, 360° per 180 s, at the diagonal preset's pitch and distance. Pixel art pans slowly along the district, 8 px/s, back and forth.
    - `func fly_to(ground_cm: Vector2, seconds: float) -> void`: `Pack3D` tweens the rig's position, and the distance to the preset's; pixel art tweens the view with `shift_view`. At `seconds == 0` both cut.
  - `main.gd`:
    - `boot` shows the title when `options["title"]`, or when `not options["play"]` and the run is not a test (test boots always pass `--style`, so they get play). It shows play otherwise, as Task 7 left it.
    - On the title: the world steps as usual; there is no player; `stack` holds `[hud (hidden), TitleScreen]`; `host.pack.title_drift(not settings.calm())`.
    - `explore`: if `settings interface/join_as` is empty, push `JoinScreen`. When it's done, save `join_as` and `look`, then join (`options["as"]` and `options["look"]`, then `_join()` for `registered` and `observer`; nothing for `none`). Then pop the title, show the HUD, stop the drift, and call `fly_to(player position or the square's centre, 0.0 if calm else 1.2)`.
    - `quit_to_title` (from the game menu): `driver.world.leave()` when a player is present, reset `player`, clear the stack to `[hud (hidden)]`, and push the title again.
    - `open_settings` from the title pushes `SettingsScreen`. The Interface page's Look row now pushes a `JoinScreen` with `look_only`.

- [ ] **Step 1: Write the failing tests.**

```gdscript
extends TestSuite

func titled():
	var main = load("res://main.gd").new()
	main.settings_path = "user://test_title.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.settings_path))
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--title"]), "res://tests/fixtures")
	return main


func test_title_first_with_no_player() -> void:
	var main = titled()
	assert_true(main.stack.top() is TitleScreen, "title")
	assert_eq(main.player.id, "", "nobody joined")
	assert_true(main.hud.fixture.visible or main.stack.top().find_child("Fixture", true, false) != null, "fixture notice on the title")
	main.free()


func test_explore_on_first_launch_asks_and_joins() -> void:
	var main = titled()
	main.stack.top().explore.emit()
	var j: JoinScreen = main.stack.top()
	assert_true(j is JoinScreen, "asks how to enter")
	j.done.emit("registered", "3,1")
	assert_true(main.player.id != "", "joined")
	assert_eq(main.stack.top(), main.hud, "in play")
	assert_eq(main.settings.get_value("interface", "join_as"), "registered", "remembered")
	main.free()


func test_just_watch_joins_nobody() -> void:
	var main = titled()
	main.stack.top().explore.emit()
	main.stack.top().done.emit("none", "0,0")
	assert_eq(main.player.id, "", "watching")
	assert_eq(main.stack.top(), main.hud, "in play")
	main.free()


func test_a_later_launch_skips_the_question() -> void:
	var main = titled()
	main.settings.set_value("interface", "join_as", "observer")
	main.stack.top().explore.emit()
	assert_true(main.player.id != "", "joined straight away")
	assert_true(main.player.observer, "as an observer")
	main.free()


func test_quit_to_title_leaves_and_explore_joins_again() -> void:
	var main = titled()
	main.settings.set_value("interface", "join_as", "registered")
	main.stack.top().explore.emit()
	var first: String = main.player.id
	main.quit_to_title()
	assert_true(main.stack.top() is TitleScreen, "title again")
	assert_eq(main.player.id, "", "left")
	main.stack.top().explore.emit()
	assert_true(main.player.id != "", "joined again")
	main.free()


func test_play_arguments_skip_the_title() -> void:
	var main = load("res://main.gd").new()
	runner.root.add_child(main)
	main.boot(PackedStringArray(["--crowd=0", "--style=fake_pack", "--as=none"]), "res://tests/fixtures")
	assert_eq(main.stack.top(), main.hud, "straight to play")
	main.free()
```

`fake_pack` must accept `title_drift` and `fly_to`. The `StylePack` base no-ops cover it.

- [ ] **Step 2: Run them and see them fail** with `-- test_title`.
- [ ] **Step 3: Implement everything above.** The flight and drift run in `_process` through the pack hooks. Calm mode cuts.
- [ ] **Step 4: Run them: PASS.** Then the whole suite.
- [ ] **Step 5: Check it on screen.** Run `godot --path city/godot -- --title` and walk the flow with the keyboard: title, Explore, Visitor, a look, Start, play, Esc, Quit to title. Do it again with a controller if one is connected. Otherwise, write in the report that the controller path is covered by the tests only.
- [ ] **Step 6: Commit** with `feat(city): live title screen and join flow`.

---

### Task 11: The six skins: fonts, frames and focus effects

**Files:**
- Create: `city/tools/styles/shared/ui_frames.py`, which writes the nine-slice frames with PIL, and its test `city/tools/styles/shared/test_ui_frames.py`.
- Create, per pack: `styles/<pack>/assets/fonts/*.ttf`, `styles/<pack>/assets/ui/*.png` (frames, where used), and a `ui` block in each `style.json`.
- Create: `city/godot/core/ui/focus_glow.gdshader`
- Modify:
  - the pack sources files (`styles/voxel/SOURCES.md`, and a `SOURCES.md` in each other pack; create them where missing), recording each font's name, URL, licence (OFL 1.1) and version;
  - `ui_theme.gd`, for `glow`.
- Test: `test_ui_theme.gd`'s `test_every_style_meets_the_contrast_floors`, now over real blocks. Add:

```gdscript
func test_every_style_font_loads() -> void:
	for dir in ["anime_cel", "solarpunk", "neon_noir", "pixel_art", "lowpoly_tropical", "voxel"]:
		var f := FileAccess.open("res://styles/%s/style.json" % dir, FileAccess.READ)
		var st: Dictionary = JSON.parse_string(f.get_as_text())
		for k in ["font_display", "font_body"]:
			assert_true(ResourceLoader.exists(st["ui"][k]), "%s %s exists" % [dir, k])
```

**The skins.** Each follows its sheet-03 panels; the spec's section 1 table gives the reference.

| Pack | Display, body font (OFL, from github.com/google/fonts) | Panel, ink | Accent, accent ink | Focus | Shape |
| --- | --- | --- | --- | --- | --- |
| anime_cel | M PLUS Rounded 1c ExtraBold, Regular | `#F7F9FD`, `#1E2A44` | `#2F6FD6`, `#FFFFFF` | ring `#2F6FD6` | rounded 16 / 12 |
| solarpunk | Josefin Sans Bold, Regular | `#F3EEDF`, `#123C3A` | `#1F6F68`, `#FFFFFF` | ring `#B8862F` | nine `brass_frame.png` / rounded 22 |
| neon_noir | Rajdhani Bold, Medium | `#0E1A2E` at 92% alpha, `#E6F1FF` | `#12324F`, `#E6F1FF` | glow `#35D6FF` | rounded 6 / 4 |
| pixel_art | Press Start 2P, Pixelify Sans | `#141B33`, `#E8ECFF` | `#2F5FD0`, `#FFFFFF` | glow `#7FB2FF` | nine `pixel_frame.png` (both) |
| lowpoly_tropical | Baloo 2 ExtraBold, Medium | `#FFF8EA`, `#2E2A24` | `#E57A1F`, `#FFFFFF`\* | ring `#2E7D4F` | rounded 20 / 16 |
| voxel | Fredoka Bold, Medium | `#FFFFFF`, `#1F2433` | `#2F6FD6`, `#FFFFFF` | ring `#1F2433` | square 0 / 0 |

\* White on `#E57A1F` measures about 2.9:1, under the floor. **Ruling in the plan:** use accent `#B85A10` instead (white on it is about 4.6:1), and keep the sheet's brighter orange for decorative edges only (`panel_edge`). Every row must pass the contrast test. Where a value fails, darken the accent or ink until it passes, and note the change in the sources file.

- `ui_frames.py` writes:
  - `solarpunk/assets/ui/brass_frame.png`: 96×96, a 12 px brass bevel (`#B8862F` to `#E4C27A`) around a teal field (`#123C3A`). Margin 16.
  - `pixel_art/assets/ui/pixel_frame.png`: 48×48 at 1 px per pixel, with a 3 px outline of `#0A0F22`, a 1 px highlight of `#3E5AA8` and the `#141B33` field. Margin 6. It is used with nearest filtering.

  Its test checks each file's size and margin pixels.
- Fonts are downloaded from `https://github.com/google/fonts` raw paths (`ofl/<family>/...`). If a download fails, record it in the report, leave `font_*` absent for that pack (the defaults apply), and do not fail the task.
- The `glow` focus: `focus_glow.gdshader`, on a `Panel` drawn behind the focused control by `Screen`, a soft 8 px halo in `focus` at 60% alpha. `Screen` watches `gui_focus_changed` and moves the halo. It exists only when `ui.focus_mode() == "glow"`.

- [ ] **Step 1: Write `test_ui_frames.py` and the font test. Run them and see them fail.**
- [ ] **Step 2: Write the tool, generate the frames, download the fonts, and add the six `ui` blocks.**
- [ ] **Step 3: Run the Python test, the UiTheme tests and the whole suite: green.**
- [ ] **Step 4: Check it on screen.** Capture the game menu in each style:
  ```
  godot --path city/godot --resolution 1920x1080 -- --style=<dir> --ticks=40 --capture=<scratchpad>/menu-<dir>.png --open-menu
  ```
  Add a `--open-menu` flag to `args.gd` for captures: it pushes the game menu after boot. Look at all six against the sheets' panels, and adjust the values until each reads as its style.
- [ ] **Step 5: Commit** with `feat(city): six interface skins with their fonts and frames`.

---

### Task 12: Evidence, benchmark scenes and docs

**Files:**
- Modify: `city/godot/tools/sheet_views.gd`, which gains an `interface` mode: `-- <style> interface`.
- Create: `city/godot/tools/interface_compare.py`
- Create: `city/godot/evidence/interface-vs-sheets.png` and `city/godot/evidence/interface-notes.md`
- Modify: `city/godot/core/bench.gd` (`Bench.SCENES`) and `city/godot/tools/bench.gd`, which gain the "menu" and "title" scenes; `city/README.md` (the Godot client section: controls, menus, settings, `--dev`, `--title`); `city/godot/README.md` (if it lists controls).

**Interfaces:**
- The interface capture mode writes, to `~/.cache/agentnagar-sheets/<style>/`:
  - `ui-title.png`, `ui-join.png`, `ui-hud.png`, `ui-menu.png` and `ui-styles.png`;
  - `ui-settings-graphics.png` and `ui-settings-controls.png`;
  - `ui-dev.png`;
  - all at 1920×1080. It also writes `ui-menu-720.png` at 1280×720 and `ui-menu-narrow.png` at 800×900.
- `interface_compare.py <out_png>` lays out, for each of the six styles, its sheet-03 FACILITY and MOBILE panels (top row of the sheet) beside `ui-menu.png`, `ui-hud.png` and `ui-title.png`, one style per row. It uses the same selection logic as `sheet_compare.py` (import its `selected()`).
- The bench scenes: "menu" is the diagonal view at crowd 60 with the game menu open; "title" is the title with its drift, at crowd 60. Both are for each style, under the normal-play gate: `normal_fps` and `missed_pct`, from each style's `budget`.

- [ ] **Step 1: Add a test to `test_bench.gd`** that `Bench.SCENES` contains `menu` and `title` entries for crowd 60. Run it and see it fail.
- [ ] **Step 2: Implement the scenes, the capture mode and the compare tool.**
- [ ] **Step 3: Run the suite: green.**
- [ ] **Step 4: Capture all six styles, compose the evidence, and write the notes.** List what matches and what differs, per style, without overstating.
- [ ] **Step 5: Run `city/scripts/bench.sh` on the display with the performance profile set.** First check the GPU is below 60 °C:
  ```
  nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader
  system76-power profile performance
  ```
  Every scene must pass the gate. Record the results in `interface-notes.md` under "Performance".
- [ ] **Step 6: Update the READMEs.**
- [ ] **Step 7: Run `city/scripts/check.sh` in full.** It includes cargo, the Python tests, the packaging tests, the Godot suite and the bench.
- [ ] **Step 8: Commit** with `docs(city): interface evidence, benchmark scenes and controls`.
