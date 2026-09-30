# Walk the city in style: sheet-quality art, a player avatar and first-person view

Design specification · 2026-09-24 · the sub-project after style packs and
movement (PR #24)

## Approved direction

PR #24 renders one live district in three swappable style packs. Rakesh
judged that the art does not yet look like the style studies, and asked for
three things:

- the art should look its best, checked properly against the style sheets;
- a player avatar, so he can walk the city himself;
- a first-person view, and controller support.

In the design conversation he decided the following:

| Topic | Decision |
| --- | --- |
| Player identity | **Both, chosen at launch.** The default is a **registered person**: a visible avatar that takes capacity, seats and queue places like anyone else. **`--as=observer`** walks as an **anonymous observer**: an overlay only the player sees, per the RD03 default. |
| Controls | **Click to walk** and **WASD**, plus a **game controller**. |
| First-person view | Required in the 3D packs. |
| Organisation | **One specification, visuals first**, delivered in stages, one PR each. |
| Art | **Richer procedural art, made in-house.** Nothing is bought or downloaded. |
| Design sections | Rakesh approved each one: core, district, art, player, testing and stages. |

Anything not listed above is a proposal in this document, open to change at
review.

## The gap this closes

The three style sheets (`docs/vision/style-studies/styles/11-…`, `08-…` and
`02-…`) and the evidence captures from PR #24 differ in six ways:

| Area | The sheets | PR #24 |
| --- | --- | --- |
| **Composition** | One shared layout on every sheet. See the list below this table. | Workshop to the north, library to the east, café to the south |
| **Buildings** | Whole volumes, with roofs, façades, windows and signs. Interiors appear when you go in. | Roofless floor plans with thin walls |
| **Density** | Palms and planters, flower beds, patterned paving, lamps, bollards, umbrellas and crowds | A large empty plaza |
| **Context** | A river, a bridge, streets, towers, houses and a moving tram | Grass to the edge of the district |
| **People** | Stylised figures with readable proportions; a white-and-yellow robot with a black face and glowing eyes | Stick figures; 16-pixel sprites |
| **Light** | Warm golden light, soft shadows, sky and clouds; deep blue nights with warm windows | Flat lighting and a plain sky |

The shared layout in every sheet places these features:

- a central tree square;
- a sawtooth-roofed workshop to the west;
- a domed library to the east;
- a park to the south-west;
- a tram line along the south;
- the river and bridge beyond the park;
- downtown towers to the north.

## Scope

**In scope:**

- the district re-laid to the sheets' composition;
- presentation-only scenery;
- buildings drawn as whole volumes that cut away on demand;
- the Forward+ renderer;
- camera presets matching the sheet panels;
- the art of all three packs brought to sheet quality;
- player commands, sessions, prediction and replay in the core;
- the avatar, with mouse, keyboard and controller input;
- first-person view.

**Out of scope:**

- other real players, and the network: the multi-room server is next;
- chat and comments;
- talking to agents or giving them tasks;
- saving the avatar between runs;
- audio;
- web and mobile export;
- simulated tram riders.

## Section 1: Core — player commands, sessions, prediction and replay

### Commands

Two new commands join the contract. Each is also a feed command, so fixtures
can script players.

- **`Go { occupant, to }`** walks the occupant to a target. The core plans the
  path, and `to` takes one of three forms:
  - **`Point`**: walk to this cell.
    - Within the current room, the occupant stands there.
    - In another room, the occupant first walks to that room's door and goes
      through admission. Once admitted, it walks to the point instead of a
      standing spot.
    - A point that is a seat, door span, queue place or entrance approach is
      moved to the nearest valid cell.
  - **`Seat`**: walk to this seat and sit. It must be a free hot seat, or the
    occupant's own reserved seat. In another room, admission comes first.
  - **`Room`**: enter this room from anywhere, as `Move` does, but without
    needing a door from the current room.
- **`Steer { occupant, cells }`** is for predicted walking: WASD in first-person
  view, and the controller stick. It carries the cells the client walked this
  tick, at most five, each a step from the last.
  - The core accepts each step only if all of the following hold:
    - it is walkable;
    - it is adjacent to the previous cell;
    - it is not held by a public occupant;
    - it follows the door rules: crossing between rooms only through a door
      span, and entering a room means admission.
  - The core stops at the first refused step and rejects the rest with
    `BlockedStep`.
  - Steering clears any walk in progress.

**New reject reasons** are `SeatTaken`, `NotYourSeat` and `BlockedStep`.
`Unreachable` already exists. A full room is not a refusal: the occupant
queues, as today.

**Observers** (overlays) may `Go` and `Steer` anywhere. They never take a seat,
hold a cell or join a queue.

### Live input

- `World::submit(command)` queues a command for the next tick.
- At Ingest, the feed's entries for that tick run first, then live commands in
  the order they were submitted.
- Every live command is recorded as `{tick, command}` in the world's
  **input log**.
- `World::input_log_feed()` exports the log as a fixture feed.
- Replaying the original feed merged with that export reproduces the session
  byte for byte.

### Sessions

Sessions live in the bridge, the seam the multi-room server will reuse.

| Call | What it does |
| --- | --- |
| `join(as, look)` | Registers the player's profile and returns its city ID. |
| `command(json)` | Accepts `Go`, `Steer` and `Depart` for the session's own occupant only. Anything else is refused with `{"error":{"code":"not-yours"}}`, which is the authority rule. |
| `leave()` | Submits `Depart`. |

For `join`, `as` is `registered` or `observer`. The IDs are:

- `person:you`, a registered person named "You";
- `person:observer-1`, an observer.

On joining, the session submits `Arrive` at the entrance nearest the tram
stop, and the viewer becomes the player's own ID.

### Invariants

All existing invariants and liveness bounds still hold. The property tests add
random live `Go` and `Steer` commands for one registered player and one
observer. Three new checks apply:

- a `Steer` never moves an occupant more than five cells in a tick, through a
  wall, or onto a public occupant;
- a player never holds a seat that is reserved for someone else;
- an observer never appears in any public projection, and never holds a seat,
  cell or queue place.

## Section 2: The district, scenery and whole buildings

### Layout

`city/fixtures/district/generate.py` re-lays the district to the sheets'
composition:

| Place | Where | Template |
| --- | --- | --- |
| Tree square | Centre | `plaza`: the big tree with a ring of benches, planters, lamps and bollards |
| Guild hall | West of the square | Facility `guild-hall`: `workshop` and `commons` inside |
| Café terrace | Beside the hall, facing the square | Outdoor room `cafe-terrace`: umbrellas and café tables |
| Library | East of the square | Facility `library`: `reading-room` inside |
| Park | South-west | Outdoor room `park`: paths, palms and benches |
| Tram stop | Along the south | Outdoor room `tram-stop`: the main entrance |

Further entrances arrive by street from the north, from the west toward the
bridge, and from the east. The scripted story keeps every gate beat, and the
crowd generator gains `park` and `cafe-terrace` among its preferences.

### Scenery

Scenery is presentation-only data. `Manifest.scenery` is an optional list; the
rules never read it.

| Kind | Fields | Purpose |
| --- | --- | --- |
| `water` | `rect` | The river |
| `bridge` | `from`, `to` (points), `width` | A crossing over the water |
| `street` | `points` (polyline), `width` | Roads and footpaths outside the district |
| `tram-line` | `points` | The track; the client runs a tram along it |
| `block` | `rect`, `height_class` (`house`, `shop`, `tower`) | Background buildings |
| `tree-row` | `points`, `spacing` | Street trees |

Validation adds one check, `scenery-over-walkable`: no scenery item may overlap
a room's walkable area. Bridges and streets may meet an entrance's edge.

### Buildings as whole volumes

- A facility's **footprint** is the union of its rooms.
- Its `exterior` template tells a pack how to draw its shell. New optional
  facility fields `roof` (`sawtooth`, `dome`, `vault`, `pitched` or `flat`) and
  `storeys` let a manifest vary it.
- Façades get windows and a door wherever the manifest has a door.
- **Cut-away is a presentation rule every pack implements.** From outside,
  roofs and façades are drawn. A building opens when any of the following is
  true:
  - the player's avatar is inside it;
  - the selected occupant is inside it;
  - the camera is inside or very close to it;
  - "open all" is toggled on, with **X** or the controller's X button.

  Opening means the roof fades and the near walls drop in 3D. In 2D, the roof
  and front-wall sprites hide.

## Section 3: Art at sheet quality

### Shared by all three packs

- **Renderer:** Forward+ for desktop. It provides the following:
  - soft shadows and ambient occlusion;
  - glow on lamps and lit windows;
  - distance fog;
  - a sky with drifting clouds;
  - a golden-hour tone curve by day, and deep-blue nights with warm windows.
- The compatibility renderer remains possible for a later web or mobile
  target, but is not a goal here.
- **Camera presets,** framed like the sheet panels:

  | Key | Preset |
  | --- | --- |
  | T | Top-down |
  | G | Diagonal |
  | Y | Street, at about 1.7 m, looking along the square |
  | F | First-person view on the avatar |

  Each preset captures from the command line for evidence
  (`--camera=topdown|diagonal|street|fpv`).

### Low-poly tropical (11)

New Blender recipes live in `city/tools/styles/lowpoly/`:

- **Guild hall:**
  - terracotta sawtooth roofs over glazed clerestories;
  - a timber-and-brick frame and big windows;
  - pendant lamps and workbenches with tools inside;
  - a sign.
- **Library:**
  - limewash walls with arched windows and columns;
  - a green-copper dome;
  - yellow banners and a lit entrance.
- **Scenery blocks:** limewash houses with terracotta roofs, shops with
  awnings, and a few towers.
- **Vegetation:**
  - a faceted banyan with lanterns in its branches;
  - palms in three sizes;
  - shrubs, planters and flower beds;
  - trees along the streets.
- **Ground:** patterned sandstone paving, water with gentle facets, and a
  stone bridge.
- **Props and vehicles:** bollards, lamps, yellow umbrellas, crates, bookshelves
  and a cream-and-red tram.
- **People:**
  - faceted stylised humans in the sheets' proportions (a larger head and
    readable clothing);
  - variants of skin tone, hair and outfit;
  - skinned animation clips for walk, sit, idle and typing.
- **Agents:** the white-and-yellow robot with a black face, glowing eyes, ear
  discs and a leaf badge. Personal agents get a lavender variant.

### Pixel art (08): sprites pre-rendered from 3D

- **Models.** A Blender pipeline in `city/tools/styles/pixel/` builds 3D models
  for this pack alone:
  - a brick workshop with navy sawtooth roofs and tall windows;
  - a domed library with blue banners;
  - dense trees, flower beds and lamps;
  - a red-and-cream tram;
  - people and robots.
- **Rendering.** An orthographic isometric camera renders each model at pixel
  scale. Each render is then:
  - snapped to the 32-colour palette;
  - outlined with a dark pass;
  - dithered selectively.

  Night twins come from the same palette map.
- **Characters** are 32 px tall, with 8 directions and walk, sit and idle
  cycles.
- **In Godot the pack stays true 2D:** sprites, Y-sorted, integer zoom only,
  as in PR #24.

### Voxel (02)

- **New voxel recipes** in `city/tools/styles/voxel/` follow the pilot's voxel
  grammar and the voxel sheet:
  - a yellow workshop with a sawtooth roof;
  - an orange barrel-vault library;
  - blocky trees, a tram and town blocks;
  - voxel humans.
- **The pilot's assets** stay as they are: the robots, furniture and workshop
  kit.
- **Placeholders:** the pack's declared placeholders drop to none.

### The quality bar

- `city/godot/evidence/` holds the **Top-down**, **Diagonal** and **Street**
  captures, plus **first-person** captures in the 3D packs. For each style they
  sit beside the matching sheet panels, so like is compared with like.
- **Rakesh judges the art;** tests do not. Each art stage ends with those
  comparisons for his review before the next stage begins.
- **Asset tests still apply:**
  - GLBs pass the Khronos validator;
  - pixel sprites use only palette colours and sit on the grid;
  - every generator is reproducible;
  - every `style.json` reference exists.

## Section 4: The player in the client

### Launch

| Option | Effect |
| --- | --- |
| `--as=registered` | The default |
| `--as=observer` | Join as an anonymous observer |
| `--look=OUTFIT,HAIR` | Choose the avatar's look; L cycles it in the game |

The HUD reads "You (local player)" with your state: walking, queued at
position N, or sitting.

### Controls

Every input goes through named actions in Godot's input map, so the keyboard,
mouse and controller drive the same code.

| Action | Keyboard and mouse | Controller (Xbox layout) |
| --- | --- | --- |
| Walk to the target (click or reticle) | Left-click | A |
| Continuous walk (predicted) | WASD. In overhead views, 1 m nudges. | Left stick |
| Look (FPV) or orbit (overhead) | Mouse: captured in FPV, right-drag overhead | Right stick |
| Sit or stand at the targeted seat | Space in FPV | A on a seat |
| Cancel the current walk | Esc (also releases the mouse) | B |
| Name tags | N | Y |
| Open all buildings | X | X |
| Previous / next style | 1–9 | LB / RB |
| Zoom | Wheel | LT / RT |
| Speed | + / − | D-pad up / down |
| Viewer | V | D-pad left / right |
| First-person view on or off | F | View / Select |
| Pause | P, or Space overhead | Menu / Start |
| Camera presets | T / G / Y | — |

Controllers may be connected and disconnected while the client runs. In
overhead views, a soft reticle shows what A would act on.

### Prediction

- **Your avatar:** the client moves it at walking speed at once, and sends each
  tick's cells as `Steer`, or a `Go` for clicks.
- **Confirmation:** the next projection either confirms the position or
  corrects it. A correction eases over 0.25 s rather than snapping.
- **Everyone else** is still replayed from their trail, one tick behind.

### First-person view

- The camera sits at eye height, 1.6 m, on the avatar in the low-poly and
  voxel packs.
- The avatar's own body is hidden, except for its shadow.
- Buildings open as you walk in.
- The name tag of whoever you look at appears on demand.
- The pixel pack is 2D. Pressing F there offers to switch to the nearest 3D
  pack, or stays overhead, per a setting.

## Section 5: Testing, gate and delivery

### Tests

**Rust:**

- scenarios for `Go` and `Steer`: walk, sit, queue, blocked steps and every
  refusal;
- the observer as an overlay;
- session authority;
- byte-identical input-log replay;
- scenery validation;
- property tests with random live commands, covering every invariant and the
  liveness bounds.

**Godot (headless):**

- **Prediction:** the avatar moves at once, is confirmed or smoothly corrected,
  and never moves more than five cells a tick.
- **Input actions:** the same sequence through the keyboard, mouse and
  synthesised controller events produces identical commands.
- **Cut-away:** a building opens when you are inside, when the selected
  occupant is inside, and on X; it is closed otherwise.
- **Cameras:** the presets, and entering and leaving first-person view.
- **Pack contract,** extended to roofs, scenery and cut-away, for all three
  packs.
- **Script errors:** any script error fails a test.

**Assets:** as in Section 3.

### Gate

A scripted headless test, with graphical captures, walks this route:

1. The player joins and walks by clicking from the tram stop to the Guild
   hall.
2. The hall is full, so the player queues, then gets in and sits at a free
   desk.
3. The player stands and walks out in first-person view, with WASD and then
   with a synthesised controller stick.
4. The player crosses the square and enters the library, switching styles
   along the way.

Throughout the route, every invariant holds and the session replays
byte-identically. In observer mode, no public projection ever contains the
player.

### Delivery

| Stage | Delivers | Review |
| --- | --- | --- |
| 1 | District re-layout, scenery, whole buildings, cut-away, Forward+, camera presets. The current art is adjusted only as far as the new layout needs to stay coherent. | Captures |
| 2 | Low-poly tropical at sheet quality | Sheet comparison |
| 3 | Pixel art at sheet quality, through the pre-render pipeline | Sheet comparison |
| 4 | Voxel extended to the city; placeholders removed | Sheet comparison |
| 5 | Player core: `Go`, `Steer`, live input, sessions, replay, authority | Tests |
| 6 | Avatar and controls: click, WASD, controller, prediction, HUD | Play-test |
| 7 | First-person view and the final gate | Play-test and captures |

## Acceptance boundary

- Every feed remains a labelled fixture.
- The local player is labelled as such.
- Nothing reads real agent state.
- The art is generated for this project, and none of it is a production style
  decision.
- Captures are evidence for Rakesh's judgement, not approval.

## Open questions this sub-project does not settle

- **RD03:** whether observers are visible to each other. Here, an observer is
  visible only to itself.
- **Whether the default registered player** eventually becomes a real account,
  through identity and tiers. That is out of scope.
- **Audio, web and mobile export:** these wait for the platform sub-project.
- **The multi-room server:** it will carry the same sessions and commands.
