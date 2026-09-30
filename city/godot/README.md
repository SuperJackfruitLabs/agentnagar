# City client (Godot)

One live district, simulated by the Rust world core and drawn by whichever
style pack is active, inside a game's interface: a live title screen, a
quiet in-play HUD, one game menu, settings that persist, and the developer
controls behind an opt-in F3 panel. **Every feed is a fixture, and nothing
here is player-facing or accepted.** The fixture notice says so on every
screen.

## Run it

Godot 4.6 with the Forward+ renderer (Vulkan) is used. The client loads the core as a native
extension, so build that first, from `city/`:

```sh
scripts/build-godot.sh                          # cargo build -p city-godot, copied to godot/bin/
godot --headless --path godot --import --quit   # first time, and after asset changes
godot --path godot                              # run: opens on the title
```

`scripts/package.sh` builds the extension for other systems and exports
packages to `city/dist/`; see [Packaging](../README.md#packaging). A packaged
build takes the same options.

A plain launch opens on the title screen, with the city running behind it
and nobody joined. Any play argument (`--as`, `--look`, `--style`,
`--camera`, `--fpv`, `--capture` or `--viewer`) skips the title and joins
at once; `--map` and `--place` are not play arguments, and open the map
over whatever the launch shows. Options go after `--`:

```sh
godot --path godot -- --title --style=neon_noir     # the title, even with a play argument
godot --path godot -- --dev                         # developer tools on for this session (F3)
godot --path godot -- --style=solarpunk --open-menu # straight to play with the game menu open
godot --path godot -- --style=pixel_art --viewer=person:asha --crowd=60 --speed=2
godot --path godot -- --operator            # also offer the operator viewer
godot --path godot -- --style=voxel --ticks=330 --capture=$PWD/godot/evidence/voxel-night.png
godot --path godot -- --camera=street --open-all   # a camera preset, every building open
godot --path godot -- --no-hud --capture=$HOME/x.png  # only the fixture banner over the view
godot --path godot -- --as=observer --look=3,1     # join as an observer, in outfit 3 with hair 1
godot --path godot -- --as=none                    # watch without a player (the public view)
godot --path godot -- --style=voxel --ticks=60 --fpv  # start in first person
godot --path godot -- --style=anime_cel --map         # open the map at start
godot --path godot -- --place=room:reading            # the map with the Library selected
```

`--place=ID` takes a facility's ID or one of its rooms' (a room selects its
facility) and implies `--map`: it is the shareable destination. An unknown
ID opens the map with nothing selected and a notice.

`--as` is who you join as: `registered` (the default), `observer` or
`none`. `--look=OUTFIT,HAIR` picks your look (outfits 0–7, hair 0–3).
`--viewer` defaults to your own view (the public one without a player).

By default the client presents with vsync at the display's own rate, high
refresh included. `scripts/bench.sh` measures every style fullscreen at the
display's native resolution. It was run on the development laptop (RTX
3070 Ti Laptop GPU, 1920 × 1080 at 360 Hz), one style at a time from a
cool GPU. An empty scene there gives 342–343 fps, and the results were:

- **Anime, neon and pixel art** hold 341–342 fps in every normal view.
- **Solarpunk** holds 341 fps in top-down and street, but 317–320 fps in
  its diagonal view.
- **Low-poly and voxel,** which declare no frame budget, reach 270–337
  fps.

The bench's `tram` scene is the diagonal view moved to the middle of the
boulevard, with two trams in view carrying 40 riders each at a crowd of
60 (see `evidence/tram-notes.md`). `BENCH_SCENES=diagonal` and then
`BENCH_SCENES=tram`, each for one style from a cool GPU, compare them at
equal clocks. Riders are drawn only as they can be seen (no shadows
aboard, a still pose, the far body from 25 m, hidden under the roof from
afar), so the 80 of them cost the styles with far bodies (anime, neon,
solarpunk) under 0.05 ms a frame, down from 0.3–1.0 ms. On a degraded
desktop neon's tram scene then held 98.5% of its diagonal view's frame
rate and anime's and solarpunk's 95–96%; low-poly and voxel, whose kits
have no far body, still pay 0.6–0.8 ms for their riders. Pixel art is
unaffected.

Once the GPU passes about 85 °C its clock falls from about 1600 to
1100–1300 MHz, and every 3D style slows (see
`evidence/interface-notes.md`). With the map open every style runs at the
empty scene's rate, since the main view draws no 3D under it. The first
opening of the map in a style takes one long frame (100–237 ms from a
fresh start) to draw its picture; opening it again takes 9–11 ms (see
`evidence/map-notes.md`).

Settings → Graphics changes that (vsync, a frame cap, Low quality), and
`--fps=N` caps the frame rate for one session instead (vsync off), without
touching the saved setting. If frames start
hitching about five times a second whatever the style, even with the
scene hidden, the desktop session has degraded (compositor or driver
state), not the game: restarting the session cleared it.

Captures must be written under your home directory: the Flatpak Godot
cannot write to `/tmp`.

If the extension is missing, the client says how to build it instead of
opening a blank window.

## Keys and controller

Every input goes through a named action in the input map (`project.godot`),
and `core/input_router.gd` turns those actions into intents, so the
keyboard, the mouse and a game controller drive the same code. Controllers
may be plugged in or out while the client runs; unplugging one stops its
steering at once. Settings → Controls → Rebind… changes any play binding,
for the keyboard and the controller separately, and the HUD's hints follow
the device used last.

### In play

| Action | Keyboard and mouse | Controller (Xbox layout) |
| --- | --- | --- |
| Walk to a point, or act on the seat or thing clicked (sit, read, inspect) | Left-click on the ground, a seat or a thing | — |
| Walk, predicted (in the overhead views a tap walks 1 m) | WASD | Left stick |
| Act on what is ahead (a soft reticle marks it), as the prompt says: sit, read, go in, inspect; stand up or stop reading; on a tram platform, wait for the tram or board it; aboard, get off at a stop | Space | A |
| Show the next thing to do with it (the prompt's "more"; Inspect is always last) | E | Y |
| Stop the current walk | Backspace | B |
| Game menu | Esc | Start |
| Map (see [The map](#the-map)) | M | Left-stick press |
| First-person view (3D styles), or back overhead | F | View / Select |
| Name tags (hidden by default; hover or click shows one) | N | X |
| Next look (you leave, and join again in it) | L | — |
| Orbit (3D) or pan (2D) | Right-drag | Right stick |
| Zoom (2D: whole-number zoom only) | Wheel | LT / RT |
| Re-centre the 3D camera on a point | Double-click | — |
| Back to the diagonal view (3D) | O | — |
| First person: look around | Mouse (captured; click to capture again) | Right stick |
| First person: act on the crosshair within 3 m (sit, read, inspect, go in, walk there; stand up) | Space | A |
| First person: free the mouse | Esc or Backspace | B |

**Reading and inspecting.** Read (Browse at a kiosk) stands the player at
the display and opens its overlay once the core has it reading; Inspect
opens the overlay at once and sends nothing. The overlay is skinned by the
style: Inspect shows what the thing is, what it is for and, for a bound
display, where its content comes from; Read shows the panel (dated
notices, a shelf's spines, a plaque's text), or "Nothing to read here yet".
Sample content says "Sample" everywhere it appears. The arrows, the d-pad
or either stick scroll it, and B or Esc leave it (reading goes on until the
player stops or steps away, and the overlay closes when it ends). In the
world each display draws its panel on its surface: far away only its chip,
within 8 m its first three headlines. The map's List tab lists each
place's displays as text under it; Enter or A reads one.

The triggers and the right stick reach a pack as the
wheel notch and the right-drag it already handles, so every pack zooms and
orbits the same way whichever device is used. WASD and the stick steer
relative to the view: up the screen is away from the camera (in first
person, straight ahead). In first person, Esc frees a captured mouse first;
the next Esc opens the menu. Start frees the mouse and opens the menu in
one press. Back in play from the map or the game menu, first person takes
the mouse again.

### In menus

The arrow keys or the d-pad move between controls, Enter or A chooses, and
Esc or B goes back; Start does too, so Start closes the game menu it opened. Left and right change the focused setting. Q and E, or
LB and RB, switch settings pages (and About's two texts). Every screen is reachable without the
mouse, and the focused control always shows its focus ring (a glow as well
in the neon and pixel skins).

### Developer panel (F3)

The harness controls are off by default. With Settings → Developer →
Developer tools on, or `--dev` for one session, F3 shows a panel at the top left with the
tick, clock, style, viewer and speed; pause, step and speed buttons; a
viewer menu; Open all and Roofs; the camera presets; and a style menu.
These shortcuts act too (off, they do nothing):

| Action | Keyboard | Controller |
| --- | --- | --- |
| Switch style pack live | 1, 2, 3… | LB / RB: previous / next |
| Open every building (roofs off, near walls down), or close them | X | — |
| Keep roofs on: a building you are in opens by its near walls only (first person always keeps them) | C | Right-stick click |
| Next viewer: public, Asha, operator (only with `--operator`) | V | D-pad left / right |
| Pause and resume | P | — |
| Step one tick | `.` | — |
| Speed: 1×, 2×, 4× or 8× (1× is one tick per second) | `+`, `-` | D-pad up / down |
| Camera preset: top-down, diagonal (the sheets' view), street (leaves first person) | T, G, Y | — |

In first person the eye rides your avatar at 160 cm; your body is hidden
but still casts its shadow, the walls beside you drop as you step inside
(the roof stays overhead), and the prompt at the bottom says what Space / A
will do; the name tag of whoever you look at shows while you look at them.
The pixel style has no first-person view: F there offers to switch to
low-poly, or with `--fpv-in-2d=stay` just says so and stays overhead.
`--fpv` (or `--camera=fpv`) starts in first person (after `--ticks`). In the
overhead views a soft reticle marks what A acts on: the nearest seat, perch,
display or other thing within 1.5 m, in front of you (see `core/interact.gd`).

## Screens

Every screen is built in code under `core/ui/`, skinned by the current
style's `ui` block in its `style.json` (fonts, colours, panel and button
shapes, the focus effect), and reskinned live when the style changes.

- **Title.** The city drifts past behind a card with the name, Explore,
  Map & read, Settings, About and Quit. Calm mode holds the camera still. Map &
  read opens the map without joining; Go there moves the title's camera.
- **Join.** Explore asks, the first time, how you enter: Visitor (a
  registered person who takes a place like anyone else), Observer (unseen,
  taking no seat) or Just watch (no player). Then your look: one of eight
  outfits and four hair styles on a turning figure. The answer is
  remembered; the camera flies down into play.
- **HUD.** Only the clock and weather (top right), the fixture notice
  (bottom left), input hints that fade after ten seconds (bottom right),
  what Space / A will do (bottom centre), short notices and, in first
  person, a crosshair.
- **Game menu (Esc / Start).** It says who you are ("Visitor · walking",
  "Observer · sitting", or "Watching") over Resume, Map, Visual style,
  Settings, About, Quit to title and Quit. The world keeps running behind it.
- **About.** From the title and the game menu: the version, "Agentnagar is
  free software under the GNU AGPL v3", the copyright and no-warranty
  lines, the source's address with a button that opens it, and the
  third-party notices and the licence in one scrolling view (Q and E, or
  LB and RB, switch between them). A package reads both texts from
  `res://licenses/`, which `scripts/package.sh` stages from the
  repository's `THIRD-PARTY-NOTICES.txt` and `LICENSE`; run from a
  checkout it reads the repository's own, and with neither it shows the
  engine's notices. On the text, up and down scroll a line and leave it at
  either end, and left and right scroll a page.
- **Visual style.** A card per style with its preview; choosing one
  switches the style live and keeps the picker open.
- **Settings.** Five pages, saved to `user://settings.cfg` as they change:
  Graphics (display, vsync, frame cap, quality), Controls (look
  sensitivities, invert look Y, Rebind…, Reset to defaults), Interface
  (name tags, text size 100–150%, how to join, your look), Accessibility
  (calm mode: a still camera and reduced motion) and Developer (developer
  tools).

### The map

M, the left-stick press, Map in the game menu or Map & read on the title
opens the map (`core/map/`), a full-window screen with two tabs and a card:

- **Map.** The style's own picture of the district from straight above,
  north up: a 3D style renders its world once with an orthographic camera
  (people, weather and cutaways hidden for that frame, at the style's
  `map.minutes`), and pixel art paints a plan in its palette. It is kept
  until the style, the size or the quality changes, so opening the map
  again costs little. Over it: a pin for each place with a category
  (Workshop orange, Library blue, Transit purple, Park green, the same in
  every style), the tram's route in the Transit colour under them, a
  label plate for every place (labels that would overlap
  move, then hide until zoomed in), a legend that filters, a compass, a
  50 m scale bar where the style asks for one, and a pulsing "you are
  here". Zoom from fit to 2× with the wheel, `+`/`-` or the triggers; pan
  by dragging or with the left stick.
- **List.** The same places as rows (icon, name, category, how many are
  inside) under a search field; typing searches.
- **Card.** The selected place's name, category, rooms and people inside,
  with Go. A tram stop's card also says when the next tram comes each way
  ("East in 12 s · West in 27 s"). A player walks to its first room by the core's rules (a refusal
  shows as a notice); a spectator's view glides there, keeping its
  heading and zoom.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move the selection | Arrows (Map: the nearest place that way; List: the next row) | D-pad |
| Go | Enter | A |
| Switch tab | Tab | Y |
| Filter by category | 1–4 | X cycles |
| Zoom | `+`, `-`, wheel | LT / RT |
| Pan | Drag | Left stick |
| Close | Esc, or M on the Map tab | B, left-stick press |

From play, opening the map, selecting the Workshop and starting the walk
takes at most five presses on either device: M, up to three arrows (the
first starts from "you are here"), Enter. Each style's
`map` block in its `style.json` gives the picture's time of day, the
colour round it, the pins' shape (a round badge, a teardrop or a pixel
square), the plates' fill, ink and case, the scale bar and a glow
(`core/map/map_theme.gd`); everything else comes from the style's `ui`
skin.

Below 900 px of width the screens take a narrow layout: the style picker
shows two smaller cards to a row, the title's name is smaller, wide page
names shrink, and the HUD's hints sit above the fixture notice.

## The player

You join from the title's Explore, or at launch with a play argument, as a
registered person unless `--as` (or the Join screen) says otherwise:

- **Registered** (`person:you`): visible to everyone, and takes places,
  seats and queue places like anyone else.
- **Observer** (`person:observer-1`): an overlay only you see. It takes
  nothing and never appears in a public view.

The game menu's header says what you are doing: walking, queued at N,
sitting or standing. Every pack marks you: a ring round your feet in 3D, an
arrow over your head in 2D. Quit to title takes you out of the city at
once, so Explore joins again straight away.

- **Steering is predicted.** Your avatar steps at once, at the core's pace
  of five 25 cm cells a tick, and only where the core will accept the step
  (`core/nav_query.gd` is the client's copy of its walkable grid). Each
  tick's cells go to the core as one `Steer`.
- **Full rooms are closed at the door.** Steering stops at the threshold
  of a room that is full or queued for by others, with the notice "The
  Workshop is full — choose Go in to queue."; in first person the prompt
  reads "Go in · Full". Go in queues ("You're next in line for the
  Workshop.") or lets you into the next room of the overflow chain ("The
  Workshop is full; you've been let into the Commons.").
- **Clicks are not predicted.** A click sends `Go`, and your avatar follows
  its trail like everyone else's. A click made while steered steps are still
  unsent waits a tick for them, so the walk starts where you are shown.
- **The whole city is walkable.** Streets, lawns and the bridge are open
  ground out to a railing at the city's edge. Overhead, the view follows
  you once you walk out of the middle of the screen.
- **Walking is shown as it happens.** Everyone (you included) plays the
  walk exactly while shown moving, at the pace shown, so nobody glides; the
  sun moves every frame, so shadows sweep rather than step.
- **Corrections ease.** When a projection puts you elsewhere, the avatar
  glides there over a quarter of a second rather than jumping.
- **Changing look re-joins.** The core cannot restyle someone who is
  present, so L takes you out of the city, at once, and you ride in again
  to the tram stop in the next look.
- **You ride the tram.** On a platform the prompt reads "Wait for the
  tram", and A waits there; waiting, it counts down ("Waiting — tram in
  12 s", from the timetable and the trams on their way); with a tram's
  doors open it reads "Board". Aboard, it names the next stop, and at a
  stop A gets you off ("Get off here"); at the last stop you step off
  anyway. Overhead the view follows the tram. First person sits you at
  your seat, the free one nearest the tram's middle, 120 cm over its
  floor, looking out on the platform side and free to look round. Every style's side windows run
  from below that eye to well above it. Menus and the map still open
  while you wait or ride. A full tram, and anything the core refuses,
  shows a notice. Stand on the rails in a tram's way for five ticks and
  the world steps you off them ("You stepped off the tracks for the
  tram"). At a line's last stop the prompt says which platform the trams
  back leave from, and the map's Go to a stop takes you to the platform
  with trams going on.
- **Joining rides you in.** Explore flies the view to the Square's tram
  stop, and until your tram has brought you there the prompt counts down
  ("Your tram reaches the Square in 5 s"). Once you are aboard, the view
  follows the tram in from the edge of the city.
- **The prompts wait their turn.** Just off a tram, whether you arrived
  or got off, the platform does not offer the tram again until you move
  or have stood there for five seconds. While you wait, A does nothing.

## How it fits together

| Component | What it does |
| --- | --- |
| `city-godot` (`CityWorld`) | Wraps the Rust core. It hands out only JSON projections: the same contract the CLI and MCP use. |
| `core/world_driver.gd` | Steps the world in real time |
| `core/scene_model.gd` | Turns successive projections into changes: appeared, left, pose, moved, presence, time; vehicles appearing, moving, opening their doors and leaving; riders boarding and stepping off |
| `core/motion.gd` | Interpolates walkers along the last tick's trail, and vehicles along their track |
| `core/style_host.gd` | Discovers packs under `styles/`, switches them live, and keeps the previous pack if a new one fails to build; draws riders inside their vehicle's node |
| `core/player.gd` | The local player: joins, predicts its own steered walk cell by cell as the core will check it, sends each tick's cells as `Steer`, and eases to the core's position when corrected; boards, waits for and steps off the tram |
| `core/tram_times.gd` | When the next tram comes to a stop each way, from the timetable and the trams seen; which stop a platform belongs to, and which side of a tram it is on |
| `core/nav_query.gd` | The client's copy of the core's walkable grid, loaded from the layout's `grid` and kept current with each projection's `grid_changes`, that prediction steps on |
| `core/input_router.gd` | Turns keyboard, mouse and controller input into intents through the input map's actions |
| `core/ui/screen_stack.gd`, `core/ui/screen.gd` | The open screens: the top one takes the input, the world takes none under a menu, and every screen is reskinned together |
| `core/ui/play_hud.gd`, `core/ui/screens/` | The HUD, and the title, Join, game menu, About, style picker, settings and rebinding screens |
| `core/ui/ui_theme.gd` | Turns a style's `ui` block into a Godot theme, with defaults for any key it leaves out |
| `core/ui/settings.gd` | The saved settings, with their defaults |
| `core/ui/input_glyphs.gd` | The key or button names and icons for the device used last |
| `core/ui/dev_panel.gd` | The developer panel (F3) |
| `core/cutaway.gd` | When a building opens: your avatar or the selected person is inside, the camera is inside (with hysteresis), or everything is open |
| `core/city_geometry.gd` | Building footprints and sides with their doors, the placements of the catalogue's kinds with their footprints and lots, the ground around the water, polylines, and the transit lines' tracks, rider slots, portals and platform sides as the core lays them, shared by every pack |
| `core/orbit_rig.gd` | The 3D packs' camera and its presets |
| `core/mesh_batch.gd`, `core/voxel_grid.gd` | Faceted meshes and voxel grids built as one surface per material |
| `core/fpv_camera.gd` | The first-person camera: eye height, look, and the crosshair's target; seated aboard a tram, turning with it |
| `styles/pack_3d.gd` (`Pack3D`) | What the 3D packs share: floors and seats from the layout, every placement in the style's skin for its kind (the planting tiled), whole buildings and scenery from the pack's kit, the orbit camera and first person, the cut-away with a fading roof, the lines' rails and the trams the projection runs with their riders inside (see-through glass, doors that slide open on the platform side, a roof that fades in the overhead views up close, lit inside at night, fading out at the portals), sky and day, animated characters |
| `styles/tram_layout.json` | The tram layout every kit builds to (`tools/styles/shared/tram_layout.py`): length, doors, floor and the rider slots, which agree with the core's |
| `styles/kit_town.gd` (`KitTown`) | Assembles a pack's GLB kit: pieces turned to a side, tiled multimeshes, bays with door bays, night-lit glass and lamps |

A **style pack** is a folder under `styles/` holding three things:

- a `style.json`, which maps every semantic key to art:
  - occupant kinds and seat kinds;
  - room templates and building exteriors;
  - under `props`, every kind of the catalogue (`city/catalogue/catalogue.json`),
    the skin each placement of it is drawn in. A kind drawn from another
    section names it: `{"seat": …}`, `{"building": …}`, `{"block": <height
    class>}` or `{"vehicle": true}`;
  - headlines and badges;
  - day and night;
- its assets;
- a `pack.gd` extending `StylePack`.

The client finds packs by scanning that folder. A missing mapping shows a
magenta placeholder and is logged. A pack may declare placeholders for art
that does not exist yet.

| Pack | Built from | Notes |
| --- | --- | --- |
| `lowpoly_tropical` | `city/tools/styles/lowpoly` (Blender): modular buildings, scenery, vegetation, props and skinned characters on a shared rig | A `Pack3D`; golden-hour sky, lit windows and lanterns at night, clouds and boats |
| `pixel_art` | `city/tools/styles/pixel` (Blender pre-renders quantised to a 32-colour palette, and Pillow) | 2:1 isometric sprites with night twins; buildings sliced a metre at a time so people sort against them |
| `voxel` | `city/tools/styles/voxel` (a 10 cm voxel builder; people on the shared rig), plus the voxel pilot's robots, desks, chairs and terminals | A `Pack3D`; the yellow sawtooth workshop and the orange vaulted library |

## Privacy on screen

The client is given only the viewer's projection, so a private agent or an
anonymous observer never gets a node in a view that may not see it. A test
checks this through the real extension. You command only your own
occupant: the bridge refuses a command for anyone else.

## Tests

`godot --headless --path godot --script res://tests/run_all.gd` must exit 0.
`city/scripts/check.sh` runs it. The suite covers:

- the scene model, motion, style discovery and switching, the driver and the HUD;
- the screens: the stack's input gate, every path by keyboard and by
  controller, settings that persist and apply, rebinding, the six skins'
  contrast, and every screen fitting a 1280 × 720 window and the narrow
  800 × 900 layout in every style;
- input: the keyboard, mouse and controller give the same intents, and
  unplugging a pad stops its steering;
- the player against the real core: predicted cells are the cells it
  accepts, corrections ease, the HUD follows a queue, and an observer never
  appears in public;
- a contract every pack must honour;
- a live switch across all packs;
- first person: F in and out, eye height, the body's shadow, the crosshair's
  seat, and the pixel style's note;
- the gate: one simulated day switched through every pack;
- the tram: vehicles appearing, moving and leaving; doors; riders seated
  inside every pack, and no ghost trams after a switch; the prompts
  through waiting, boarding, riding and getting off, by keyboard and
  controller; the menu while waiting; the notices; first person at the
  seat; the overhead view following the tram; the map's route, stops and
  next tram;
- the bench's tram scene: its riders fill two trams, and both are in the
  diagonal view as the scene starts and eight ticks on;
- the player gate (`test_gate_player.gd`): a registered player click-walks
  from the tram stop to the full Guild hall, queues, gets in and sits at a
  free desk, stands and steers in first person with WASD and a stick,
  crosses into the library and switches styles at both — with every core
  invariant checked on every tick and the input log replaying the session
  byte for byte — and an observer's walk never reaches a public projection;
- the collision audit (`test_collision_audit.gd`): in every style, what is
  drawn in the walking band (0.25–1.9 m) against the core's walkable grid,
  counted six ways — cells through a solid, cells a solid comes within
  10 cm of, walkers' and the player's steps through solids over a day,
  walkers inside a drawn tram but outside the core's, and blocked cells in
  a room with nothing drawn near them — each held to its count in
  `evidence/placement-budget.json`. A count over its budget fails and
  names every offender (the placement, seat, building or scenery it was
  drawn for, the cell, and how far it reaches into the 10 cm clearance);
  a count under it fails too, so a budget is lowered in the commit that
  earns it.

## Evidence

`evidence/` holds, for each style, captures at the top-down, diagonal and
street presets (tick 120, 11:48), by night (tick 330, 20:12), in first person
and cut away, beside the concept sheets in `<style>-vs-sheet.png`, with the
remaining differences in `<style>-notes.md`; `stage1/` keeps the stage-one
captures. They are for judging the styles; none of them is a style decision.
Make the side-by-side sheets with `city/tools/evidence/compare.py`.

`evidence/map-vs-sheets.png` sets each style's map, at 1920 × 1080 with
the Workshop selected, beside its sheet-00 MAP panel, and
`evidence/map-notes.md` records what matches, what differs and the map's
frame rates and opening times. To capture a style's map (and its List
tab, also at 1280 × 720 and 800 × 900) and compose the sheet:

```sh
godot --path godot --script res://tools/sheet_views.gd -- STYLE_DIR_NAME map
python3 godot/tools/sheet_compare.py --maps godot/evidence/map-vs-sheets.png
```

`evidence/tram-vs-sheets.png` sets each style's tram beside its sheet-02
TRANSIT panel:

- the ride in first person, as the tram pulls in to the Square;
- the Square stop, with the westbound tram's doors open and its riders
  stepping off;
- the full tram lit at night;
- the overhead view over a full tram.

`evidence/tram-notes.md` records what matches, what differs and the tram
scene's frame rates. The trams are filled with scripted riders
(`Bench.TRAM_LOAD`), so they are full. To capture a style and compose the
sheet:

```sh
godot --path godot --script res://tools/sheet_views.gd -- STYLE_DIR_NAME tram
python3 godot/tools/tram_compare.py godot/evidence/tram-vs-sheets.png
```

`evidence/interface-vs-sheets.png` sets each style's game menu, HUD and
title beside its sheet-03 FACILITY and MOBILE panels, and
`evidence/interface-notes.md` records what matches, what differs and the
menu and title scenes' frame rates. To capture every screen of a style at
1920 × 1080, 1280 × 720 and 800 × 900 (whatever size the desktop gives
the window) and compose the sheet:

```sh
godot --path godot --script res://tools/sheet_views.gd -- STYLE_DIR_NAME interface
python3 godot/tools/interface_compare.py godot/evidence/interface-vs-sheets.png
```

`evidence/placement-budget.json` holds each style's collision-audit counts,
and `evidence/placement-kind-sizes.json` each catalogue kind's walking-band
silhouette as every style draws it (centimetres in the kind's frame,
rounded out to 5 cm), from which the catalogue's footprints are set. The
audit writes each style's report and a picture of its grid (4 px a cell) to
`~/.cache/agentnagar-collision/<style>/`:

```sh
godot --headless --path godot --script res://tools/collision_audit.gd -- [--audit-style=STYLE_DIR_NAME]
godot --headless --path godot --script res://tools/collision_audit.gd -- --measure-kinds
godot --headless --path godot --script res://tools/collision_audit.gd -- --write-budget
```

The low-poly, anime, solarpunk, neon noir and voxel styles draw everything
inside its footprint where people walk, and their budgets are all zero:

- building walls stand in the shell's ring outside the rooms, each door bay
  as wide as its door, with the leaves folded into the reveals (voxel's
  door pieces are stretched so their 2 m opening is the door's width);
- palms, street trees and shrubs are drawn as wide as their footprint's
  disc where people walk (a style's `fill`: "trunk" for a tree, whose
  leaves are left out, as the audit leaves them out), each growing to its
  own height; shrubs are clipped round bush masses (voxel's a 32-sided
  hedge drum under bush blocks, since a 10 cm voxel edge cannot follow a
  disc closely enough), and the great tree's roots run out to the edges of
  its square;
- pieces a style marks `fill` (and fitted runs) stretch to what the grid
  blocks for their footprint (`CityGeometry.drawn_rect`);
- seats stand whole: the chair or seat fills the square 25 cm either way
  of the sitter, which the audit exempts for the seat's own furniture, and
  the rest stretches to the seat's footprint (`fill`; a seat drawn with a
  separate `desk` stretches the desk to it, the chair left as it is);
- the things to use are the same objects in every style, each fitted to
  its footprint (`fill`): the noticeboard a board on two posts under a
  roof above the band, the plaque on a plinth, the kiosk a standing
  screen, each carrying a `display` node on the face it draws, scaled to
  that face's size, where the surface's text mounts: wrapped to the face
  (and the display anchor's width), shrunk to fit its height down to
  20 px, then short of its last headlines, never of "Sample"; the steps,
  the low wall and the fountain's basin (drawn to its 1.5 m disc). A
  perch's sit anchors lie just outside its body, so the pack sets a seat
  (the skin's `perch` piece, its top at the kit's seat height, reaching
  15 cm out under the thighs) at each anchor, reaching back into the body,
  and draws a sitter's body on that seat, its hips over the anchor, where
  the core keeps it at its cell's middle: the audit gives each of a
  perch's sit anchors the square a seat's own furniture has;
- a meadow is soft ground people walk through: its tall grass and flower
  clumps (the skin's `meadow` pieces) are planted as MultiMesh instances
  every 25 cm across its lot, each kept wholly inside it, and drawn within
  60 m of the camera; the audit
  reads nothing a meadow draws inside its lot as solid. Each clump's bend
  weight is its UV2's x, 0 at a blade's root and 1 at its tip, for the
  sway;
- blocks are walled on their lots, each wall with a closed gate facing
  its nearest street;
- tram shelters stand open to their stands, their posts, back glass, bench
  and end screen laid out to the shelter's footprint; the bench is a perch,
  with a seat at each of its sit anchors along its front;
- the bridge's parapets and the fences stand off the walkable floor.

Pixel art's sprites are rendered from models fitted the same way
(`city/tools/styles/pixel/models.py`), and the audit reads each sprite as
the walking-band outline of the model it was rendered from
(`tools/collision_audit/solids_2d.gd`), placed where its pixels land: walls
25 cm deep in the ring outside the rooms, a doorway a metre of opening
(`door_m`) at a time between two reveals where its leaves stand folded;
partitions straddling the shared edge with 1 m gaps; props, planting and
the great tree's roots on their drawn footprints; shelters, flowerbeds and
seats rendered at their own facings (benches at every 36 degrees for the
square's ring); garden walls with gates on the block lots; railings and
bridge parapets off the floor; the tram 2.5 m wide. A sprite stands on a
whole pixel, so a thing placed off the 12.5 cm lattice (whole centimetres:
the 25 cm points) is drawn up to 5 cm from its point; everything placed at
a right angle is on the 25 cm snap, and the square's ring of benches, off
the right angles, stands where the cells round each bench agree with its
outline both on its point and on its pixel (the fixture generator's
`ring_point`). Its budget, like the others', is zero.

Pixel art draws the things to use from the same kit
(`city/tools/styles/pixel/things.py`): the same objects as the 3D styles,
each at its facings with a night twin. A fixture stands on a footing that
fills its drawn footprint where people walk. Each of these sprites
declares its shapes in the band (kit.json `band_shapes`); `render.py`
holds the model to them, and `tests/test_things_to_use.gd` holds the
audit's table to them, so the table cannot drift from the art. A perch
has a seat stone sprite at each sit anchor (the `perch` seat entry, at the
eight facings), 28 cm wide and reaching 14 cm out, a centimetre inside
the 3D seats, since a stone off the lattice is drawn on its nearest pixel;
its sitters are drawn on it. A meadow is clumps of tall grass (and some
flowering) every 25 cm across its lot, each kept inside the lot by the
farthest reach of its three rustle frames (at rest, pushed, swinging
back; each sprite's meta `rustle`), which the audit, as in 3D, reads as
walked through. The fountain is one render cut in two sprites sorted
apart: the back of its rim behind every far-side sitter, the rest (front
rim, water, pedestal) at its middle. A display's text, at 16 px a metre,
has no room for headlines in the world, which is pixel art's deviation
from "within 8 m: headlines" (the overlay and the map's List tab carry
them): only the display in focus (the one the player targets, else the
nearest within reach) shows a compact label on a plate over its drawn
face, at most two lines ("Sample" and the title, or the title and a
first headline that fits a line), in the style's pixel font (Press
Start 2P on its 8 px grid); every other display, and a bookshelf, shows
its chip. The plate y-sorts with the world at the face, lifted above
every world sprite (LABEL_Z) so a wall, a roof or a lamp in front of it
in the sort never cuts it; an occupant's name tag carries the same lift.

`evidence/placement-<style>-overlay-before.png` and `-overlay-after.png`
are the audit's grid pictures before and after that work. The
`-door-<door>.png` captures show each building door with its walkable span
marked, from `tools/probes/capture_doors.gd`:

```sh
godot --path godot --script res://tools/probes/capture_doors.gd -- out=$HOME/captures styles=anime_cel
```

`evidence/placement-<style>-street.png` and `-diagonal.png` show the
square from the north platform, at street level and from above: the great
tree's roots, the benches round it, lamps, bollards, planters, palms,
street trees and the open tram shelters. They are taken with
`tools/probes/capture_views.gd` (its header gives the views).

`evidence/interact-<style>-*.png` show the things to use in each style,
from `tools/probes/capture_interact.gd` (it needs a display): the player
sitting, through Use, at a bench, a desk, a café chair, a reading chair,
the library steps, a park wall and the fountain's rim (`sit-<kind>`), and
the Square's noticeboard from 12 m (`notice-far`: its chip), from its
stand (`notice-near`: its headlines) and read (`notice-open`: the
overlay). `only=kiosk-near,kiosk-near-notices` adds the library's kiosk
from its stand, as it is and with the Square's notices put on it. In pixel
art the view is fixed, looking north-west, so the camera centres on the
player at the closest zoom, and the steps and fountain shots sit at the
anchors that view shows (the steps' west end, the fountain's north-west):

```sh
godot --path godot --resolution 1280x800 --script res://tools/probes/capture_interact.gd -- out=$PWD/godot/evidence style=anime_cel
```

After any visual change, sweep the whole client and look at every frame:
`godot --path godot --resolution 1600x900 --script res://tools/audit.gd`
writes 39 scenes (each style at each preset, day and night, cut away, first
person, and close-ups) to `~/.cache/agentnagar-audit/`.
