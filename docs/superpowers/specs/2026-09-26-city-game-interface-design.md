# City game interface: design

Date: 2026-09-26. This comes before the four follow-on mechanics (map, tram, rooftops, conversations), because each of them is a screen or a prompt inside it. The map spec (`2026-09-26-city-map-view-design.md`) is revised to sit inside this shell.

## 1. Goal and success

The client today is a test harness on screen. At 1920 × 1080 it shows:

- a status line of tick, time, style, viewer and speed;
- a row of more than twenty buttons that runs off the right edge: six styles, a viewer menu, names, pause, step, speed, camera presets, open all and roofs;
- a "You (local player)" line.

This spec replaces that with a game's interface:

- a live title screen;
- a quiet in-play HUD;
- one game menu that reaches everything a player needs;
- settings that persist;
- the developer controls kept, but behind an opt-in F3 panel.

Every screen is skinned by the current visual style, and every screen works with the keyboard alone, the mouse, or a controller.

The user's choices, 2026-09-26:

- **Skins:** themed per style, with one layout and one behaviour.
- **First screen:** a live title screen.
- **Developer controls:** an F3 overlay, off by default.

The sources:

- `docs/vision/VISION.md`, interaction principles:
  - "Map & read" is an entrance equal to Explore (principle 1);
  - calm mode is "still camera, reduced motion, muted audio, no compulsory weather effects" (principle 6).
- `docs/vision/EXPERIENCES.md` U05: keyboard controls, still camera, reduced effects, focus management.
- `docs/vision/style-studies/shared/CONSISTENCY-CONTRACT.md` section 2, whose conventions are not recoloured by a style's palette:
  - the action icons: Browse is an open book, Book a calendar, Ask a speech bubble;
  - the semantic colours.
- Each style's interface panels (sheet 03: FACILITY and MOBILE), which show how that style draws a panel, a button and a label. The reference revisions are in the table below.

| Style | Pack | Sheet 03 | What its panels show |
| --- | --- | --- | --- |
| 06 Cel-shaded anime | `anime_cel` | r004 | light rounded cards, blue buttons with white text, soft shadow |
| 09 Solarpunk | `solarpunk` | r003 | deep-teal panel in a brass frame, cream rounded buttons with teal line icons |
| 10 Neon noir | `neon_noir` | r004 | dark navy glass, cyan-edged buttons with a soft glow, light text |
| 08 Pixel art | `pixel_art` | r008 | dark navy pixel frames, blue-lit pixel buttons, pixel type |
| 11 Low-poly tropical | `lowpoly_tropical` | r004 | cream panels, chunky rounded buttons in green, orange and yellow, bold type |
| 02 Voxel | `voxel` | r003 | white panels, square colour tiles with large icons, blocky type |

**Success is judged in four ways.**

1. **Nothing of the harness in play.** With default settings, the in-play screen shows only the HUD elements of section 4. The developer panel appears only after Developer is enabled in Settings, or with `--dev`.
2. **Sheet match.** Each screen is captured in each style at 1920 × 1080. The composer tool lays the captures out beside each style's sheet-03 panels in `city/godot/evidence/interface-vs-sheets.png`, and `interface-notes.md` records the differences.
3. **Every path by keyboard and by controller.** An automated test drives both through title → Explore → play → menu → each settings page → style change → quit to title, with no mouse. Every focused control shows a focus ring that meets the contrast check in section 8.
4. **Performance.** With any menu open, every style stays within the normal-play gate: within 3% of the empty scene's frame rate at vsync, and at most one point more of missed refreshes. The title screen meets the same gate.

## 2. Structure

The screens are built in code, as `hud.gd` builds its controls now, so they can be tested headless. They live in a new module, `city/godot/core/ui/`.

- **`ScreenStack`.** It holds the open screens. The top screen receives all input; the ones below are drawn but inert.
  - Back (Esc or B) closes the top screen. At the bottom of the stack, Back opens the game menu in play, and does nothing on the title.
  - Opening a screen gives focus to its first control, or to the one it had when last open.
  - While any screen other than the HUD is open, the `InputRouter` stops forwarding intents to the world. Movement keys already held stop at once, as a lost window focus does now.
- **`Screen`.** The base class of each screen. It has `build(theme)`, `focus_first()`, `on_back() -> bool` (true when handled) and `apply_theme(theme)`.
- **`UiTheme`.** Builds a Godot `Theme` from a style's `ui` block (section 7) and holds the extras a `Theme` has no slot for: the focus effect, the panel shape and the glyph set.
- **`InputGlyphs`.** Tracks which device was touched last, and gives each action's label as the key or button to press: "Esc", or the controller's B. Hints change on the next frame after the device changes.
- **`Settings`.** Reads and writes `user://settings.cfg` (`ConfigFile`), applies settings, and emits `changed(section, key)`.

`main.gd` keeps its role as the composition root. The current `Hud` is split three ways:

- the player-facing parts go to the new HUD (section 4);
- the developer parts go to the developer panel (section 6);
- the error panel stays, shown over everything.

## 3. The title screen

The client boots the world as now, but does not join. The city runs behind the title, and a slow drifting camera circles the square: one full turn in about three minutes, at the diagonal preset's height. The style is the one last used, or the first by `order` on a first launch.

The title card shows the name **AGENTNAGAR** in the style's display font, and a menu:

- **Explore.** On a first launch, a short **Join** screen asks how to enter:
  - **Visitor**: a registered player who takes a place like anyone else;
  - **Observer**: an anonymous player who takes no seat;
  - **Just watch**: no player; the camera is yours.

  It then asks for your look, one of the eight outfits and four hair styles, shown on a turning figure. Later launches remember both, and Settings → Interface can change them.

  Choosing Explore joins the world with those choices (`Player.join`), then flies the camera from the drift down to the player over 1.2 s, or to the square for Just watch, and shows the HUD.
- **Map & read.** Opens the map screen (the map spec) as a spectator. Back returns to the title.
- **Settings**
- **Quit.** Not shown in the web build.

The "Fixture data — not real agent state" line stays on the title, small, at the bottom left.

In calm mode the camera does not drift, and Explore cuts to the view instead of flying.

The existing arguments still apply:

- `--as`, `--look`, `--style`, `--camera` and `--fpv` skip the title and go straight to play, as today, so scripts, captures and the bench are unchanged.
- `--title` forces the title.

## 4. The in-play HUD

Only these, placed so they stay clear of the view's centre:

| Element | Where | What |
| --- | --- | --- |
| Context prompt | bottom centre | What the act button does now, with its glyph: "Ⓐ Sit", "Space Stand", "Enter Walk here". Hidden when there is nothing to do. It replaces today's crosshair caption. |
| Crosshair | centre | First person only, as now. |
| Clock and weather | top right | "08:36", with a sun, moon or rain icon. |
| Notices | top centre | Short messages that fade out after 4 s, at most two at once: a room is full, the core refused a step, and today's first-person-in-2D offer, with its button. |
| Input hints | bottom right | "Esc Menu · M Map", in the current glyphs. They fade after 10 s of play and come back when the device changes. |
| Fixture notice | bottom left | "Fixture data — not real agent state", small and always shown. |

The "You (local player)" status line becomes part of the prompt ("Walking to the library") and of the game menu's header.

Name tags keep working as now, switched in Settings → Interface. N stays as their shortcut.

## 5. The game menu

Esc or Start opens it over the play view.

- The simulation keeps running: in a shared city one visitor cannot stop time. Pause is a developer control (section 6).
- The view behind the menu is dimmed by the skin's scrim colour, not blurred, because a blur pass costs frame time.

The header shows who you are ("Visitor · walking", or "Watching"). Below it:

- **Resume**
- **Map**: the map screen.
- **Visual style**: a grid of six cards, one per style, each with the style's name and a preview image. Choosing one switches the style live, as the number keys do now. The menu reskins at once and keeps its focus on the chosen card. The previews are 480 × 270 images, generated by a capture tool into each pack's `assets/preview.png`, from the diagonal preset at 10:00.
- **Settings**
- **Quit to title**: leaves the world (the bridge's `leave`) and returns to the drifting title.
- **Quit**: not shown in the web build.

## 6. The developer panel

- **Turning it on.** Settings → Developer → "Developer tools", off by default, or `--dev` for the session.
- **Opening it.** When on, F3 toggles a compact panel at the top left. It does not take focus from play until it is clicked or focused with Tab.
- **What it holds** (everything the current HUD has that a player does not need):
  - tick, time, speed and the style's key;
  - pause, step, and speed down and up;
  - the viewer menu;
  - open all and roofs;
  - the camera presets.
- **Shortcuts.** With the panel on, today's shortcuts work as now: the number keys pick styles, T, G and Y pick camera presets, P pauses, `.` steps, and `+` and `-` change speed. With it off they do nothing, except `+` and `-`, which zoom the map when the map is open.
- **Look.** The panel uses a plain monospace skin in every style, so it never reads as part of the game.
- **Space.** Space no longer pauses in the overhead views: it is the act key in every view, and pause is P, with the panel on.

## 7. The style's interface skin

Each `style.json` gains a `ui` block. `UiTheme` fills any missing key from a neutral default, so a new style works before it has its own skin.

```json
"ui": {
  "font_display": "res://styles/<pack>/assets/fonts/<display>.ttf",
  "font_body": "res://styles/<pack>/assets/fonts/<body>.ttf",
  "pixel_font": false,
  "text_size": 20,
  "colours": {
    "panel": "#F7F8FB", "panel_edge": "#D5DAE6",
    "ink": "#1F2433", "ink_muted": "#5A6275",
    "accent": "#2F6FD6", "accent_ink": "#FFFFFF",
    "focus": "#2F6FD6", "scrim": "#0B0F1A99"
  },
  "panel": { "shape": "rounded", "radius": 14, "border": 1, "shadow": 8 },
  "button": { "shape": "rounded", "radius": 10, "case": "title", "height": 48 },
  "focus": "ring",
  "frame": null
}
```

- **`panel.shape` and `button.shape`:**
  - `rounded`: a `StyleBoxFlat` with that radius;
  - `square`;
  - `nine`: a nine-slice texture from `frame`, a PNG with its margins, drawn with nearest filtering when `pixel_font` is true.
- **`focus`:**
  - `ring`: a 3 px outline in `focus`, 2 px outside the control;
  - `glow`: the ring plus a soft halo drawn with a shared shader, for neon and pixel art;
  - `underline`: a 3 px bar under the control.
- **`button.case`:** `title` or `upper`, as the sheets letter them.
- **Fonts.** Each style has a display font and a body font chosen to match its sheets, under the SIL Open Font License. They are bundled in the pack's `assets/fonts/` and recorded, with source and licence, in the pack's sources file. With none, Godot's default font is used. Pixel art uses a pixel font drawn at whole-number scales only.
- **Planned skins** (the section 1 table gives each one's reference):
  - anime: light rounded;
  - solarpunk: teal in a brass frame (`nine`);
  - neon: dark glass with `glow`;
  - pixel: navy pixel frames (`nine`, pixel font, `glow`);
  - low-poly: cream, with chunky warm buttons;
  - voxel: white, with square tiles.
- **What stays fixed across styles:**
  - the contract's semantic colours and action icons;
  - the developer panel's skin;
  - the error panel's legibility: plain dark text on a light panel.

## 8. Settings

Settings are saved to `user://settings.cfg` and applied at start. Each page is a list of rows; each row is a label and a control. The keyboard or a controller moves through the rows, left and right change a value, and a change applies at once. Display changes are the exception, see below.

| Page | Setting | Values | Default |
| --- | --- | --- | --- |
| Graphics | Display | Windowed, Fullscreen | Windowed |
| | Vsync | On, Off | On |
| | Frame cap | Display rate, 60, 120, 144, 240, Unlimited (vsync off) | Display rate |
| | Quality | High, Low | High |
| Controls | Rebind | every player action: move ×4, act, back, menu, map, first person, zoom in and out, name tags. One key and one controller button each. | project input map |
| | Mouse look sensitivity | 0.25×–3× | 1× |
| | Stick look sensitivity | 0.25×–3× | 1× |
| | Invert look Y | On, Off | Off |
| Interface | Name tags | On, Off | Off |
| | Text size | 100%, 125%, 150% | 100% |
| | Join as, look | as on the Join screen | first-launch choice |
| Accessibility | Calm mode | On, Off | Off |
| Developer | Developer tools | On, Off | Off |

- **Frame pacing.** Frame cap and vsync reuse `FramePacing.policy`. `--fps` on the command line overrides them for that session and is not saved.
- **Quality Low:**
  - turns off SSAO and screen-space reflections;
  - halves the shadow distance and the shadow atlas;
  - lowers MSAA to 2×, and to none where the style uses FXAA.

  The style's `on_shown` applies it through the same settings path it already uses, so a style switch keeps it.
- **Rebinding.** Waits for the next key or button, and shows a conflict with another action for the player to confirm or cancel. "Reset to defaults" restores the project's input map.
- **Display changes.** Switching to fullscreen asks "Keep this display setting?" and reverts after 10 s without an answer.
- **Calm mode:**
  - no title drift, and cuts instead of camera flights;
  - no automatic camera swings; `keep_in_view` still re-centres, with one cut;
  - rain drawn at a quarter of its particles, with no streaks.

## 9. Structure of files

| File | Responsibility |
| --- | --- |
| `godot/core/ui/screen_stack.gd`, `screen.gd` | the stack, focus and Back; the base class |
| `godot/core/ui/ui_theme.gd` | `ui` block → `Theme` and extras; defaults |
| `godot/core/ui/input_glyphs.gd`, `glyphs/*.svg` | last-device tracking; key and button glyphs (keyboard keycaps and the four face buttons, bumpers, triggers, sticks, Start and Back) |
| `godot/core/ui/settings.gd` | the settings file, applying settings, defaults |
| `godot/core/ui/screens/title.gd`, `join.gd`, `game_menu.gd`, `style_picker.gd`, `settings_screen.gd`, `rebind.gd` | the screens |
| `godot/core/ui/play_hud.gd` | the in-play HUD (section 4) |
| `godot/core/ui/dev_panel.gd` | the developer panel (section 6) |
| `godot/core/hud.gd` | removed. Its error panel moves into `play_hud.gd`, and its developer controls into `dev_panel.gd`. |
| `godot/main.gd`, `core/input_router.gd`, `core/args.gd`, `project.godot` | title boot, `--title` and `--dev`, the new actions `menu`, `map` and `dev_panel`, and input routing while a screen is open |
| `godot/styles/*/style.json`, `assets/fonts/`, `assets/ui/`, `assets/preview.png` | each style's skin, fonts, frames and preview |
| `godot/tools/style_previews.gd` | writes the six preview images |
| `godot/tools/sheet_views.gd`, `sheet_compare.py` | interface captures and their composite |

## 10. Testing

- **`ScreenStack`.**
  - Opening and closing screens, and Back at every depth.
  - Focus on opening, and focus restored when a screen is reopened.
  - Intents never reach the world while a screen is open, and keys held when it opens stop.
- **`UiTheme`.**
  - Every style's `ui` block gives a complete theme.
  - Missing keys take defaults.
  - Contrast, measured with the WCAG relative-luminance formula:
    - `ink` on `panel`, and `accent_ink` on `accent`: at least 4.5:1;
    - `focus` against `panel`: at least 3:1.

    This is a measured check of colours, not an accessibility claim.
- **`Settings`.**
  - Round trip through the file.
  - A corrupt or missing file gives defaults.
  - Each setting is applied: the window mode, the `FramePacing` policy, the Low-quality changes (and that they survive a style switch), text size and calm mode.
  - `--fps` overrides for the session only.
- **Rebinding.**
  - Binding a key and a button.
  - A conflict prompt that can be confirmed or cancelled.
  - Reset to defaults.
  - The new binding drives the `InputRouter`.
- **`InputGlyphs`.** The last device switches the labels. Rebinding changes a hint's glyph.
- **Flows, driven by input events:**
  - title → Explore for each of Visitor, Observer and Just watch, on a first launch and on a later one;
  - Map & read from the title;
  - Quit to title, then Explore again;
  - a style change from the game menu, which reskins the menu and keeps focus;
  - `--as` and the other play arguments skip the title.
- **Developer panel.**
  - It is hidden and F3 does nothing by default.
  - With it on, every control and shortcut does what the old HUD's did. The old HUD's tests move here.
- **Captures.** Title, Join, HUD in play, game menu, style picker, each settings page and the developer panel, in all six styles at 1920 × 1080 and at 1280 × 720. The narrow layout is also checked at 800 × 900. All are composed beside the sheets and inspected at full size and half size.
- **Performance.** The bench gains a "menu open" scene and a "title" scene per style, under the normal-play gate.

## 11. Not in this spec

- **Audio,** and the audio settings page.
- **Touch controls and phone layouts:** the platform work. Screens stack vertically below 900 px of width.
- **Sign-in and accounts:** the registered-account layer in the roadmap. "Visitor" is today's local registered player.
- **The map screen:** its own spec, revised to use this shell.
- **Ask and the conversation panel:** the conversations spec.
- **Localisation:** English only, as the contract says; strings are kept in one table so that they can be translated later.

## 12. Risks

- **Six skins done well.** Fonts, nine-slice frames and focus effects for six styles are real design work. *Mitigation:* the `ui` block works with defaults from day one, and skins are finished one style at a time against their sheets, anime first. The captures and notes record what is left.
- **Input taken from the world.** A screen must never leave a movement key "held", and the world must never react to a key meant for a menu. *Mitigation:* one gate in the `InputRouter`, with tests for held keys at the moment a screen opens and closes.
- **Pixel-art type.** A pixel font blurs at fractional scales. *Mitigation:* the 125% and 150% text sizes round pixel fonts to whole-number scales (2× and 3× of a 10 px face), and the capture review checks them.
- **The title's cost.** The live city behind the title must not load slower than today's straight-to-play start. *Mitigation:* the title appears as soon as the style's scene is built, which is the same moment play starts today. The bench's title scene holds it to the gate.
