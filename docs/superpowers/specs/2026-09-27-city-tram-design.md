# City tram: design

Date: 2026-09-27. This is the second of four follow-on mechanics; the map, the first, shipped in v0.0.2. The tour tram (EXPERIENCES U06, with captions, a camera path, and pause and skip) is a separate, smaller spec that follows this one and reuses the ride.

The user's choices, 2026-09-27:

- **Scope:** core transit first, then the tour.
- **Riders:** the tram carries the city's comings and goings. Arrivals ride in and step off; departures walk to a stop, queue, board and ride out. Players can also ride between the visible stops.

## 1. Goal and success

Today the tram is a picture. Each style pack moves it along one line with a local clock (7 m/s, 12 s at the stop); the core knows only a presentation-only `TramLine` and the stop where players arrive. After this spec the tram is part of the simulation:

- the deterministic core runs the trams to a timetable;
- people board and alight by its rules;
- everyone sees the same trams with the same passengers.

The sources:

- `docs/vision/style-studies/shared/CONSISTENCY-CONTRACT.md` S1: a tram boulevard "running east–west on the ground; two tracks, one stop south of the square; cream tram with a coral stripe".
- The style studies' TRANSIT panels (sheet 02): people boarding through open doors, a rider's view out of the window at the square, and a lit tram with its passengers at night.
- `docs/vision/CITY_PLAN.md`:
  - the Transit Depot's "ride a tram, plan routes, … routes, frequency, vehicle capacity";
  - "walking, direct links and accessible navigation remain free; a fictional fare never gates basic discovery".
- The dynamic-world direction: agents and humans keep coming and going. The tram is how the district fills and empties.

**Success is judged in four ways.**

1. **Determinism and rules.** The same manifest, feed and seed give a byte-identical event log. The core's invariants hold on every tick of both scenario gates:
   - a tram never carries more than its capacity;
   - a rider is never also in a room;
   - boarding and alighting happen only while a tram stands at a stop with its doors open;
   - a tram never enters a cell a walker holds;
   - riders never hold ground cells.
2. **The comings and goings are visible.** In the district fixture over one day:
   - every public arrival steps off a tram;
   - every public departure boards one;
   - no one appears or vanishes on the ground.

   The fixture's scenario test checks this from the event log.
3. **A player can ride.** From the Square stop, a player can wait, board with A (or Space), ride to the Avenue stop and step off. That's at most three presses, with keyboard or controller. First person shows the view out of the windows.
4. **Performance.** The normal-play frame-rate gate, judged style by style from a cool GPU as in the interface notes, holds with two trams in the district carrying 40 riders each.

## 2. The line in the manifest

The presentation-only `Scenery::TramLine { points }` is replaced by a rule-bearing `Line` in the manifest, beside `city` and `scenery`:

```rust
/// A transit line the core runs: vehicles travel its tracks between two
/// portals, stop at its stops and carry riders.
pub struct Line {
    pub id: PlaceId,                 // "line:boulevard"
    pub name: String,                // "Boulevard tram"
    pub mode: LineMode,              // Tram (Bus and Ferry reserved)
    /// The centreline, west to east (cm). Its ends are the portals, where
    /// vehicles enter from and leave to the rest of the city.
    pub points: Vec<Point>,
    /// The two tracks' offsets from the centreline (cm, + = south):
    /// [eastbound, westbound].
    pub tracks: [i32; 2],
    pub stops: Vec<Stop>,
    pub timetable: Timetable,
    pub vehicle: VehicleSpec,
}

pub struct Stop {
    pub id: PlaceId,                 // "stop:square"
    pub name: String,
    /// Where vehicles stand, as a distance along the centreline (cm).
    pub at: i32,
    /// The platform rooms: [eastbound side, westbound side].
    pub platforms: [PlaceId; 2],
}

pub struct Timetable {
    /// A vehicle enters each direction every `headway` ticks, starting
    /// at `offset[direction]`.
    pub headway: u32,                // 30
    pub offset: [u32; 2],            // [0, 15]
    pub speed: u32,                  // cells a tick: 28 (7 m/s at 1×)
    pub dwell: u32,                  // ticks with doors open at a stop: 12
}

pub struct VehicleSpec {
    pub capacity: u32,               // 40
    pub length: i32,                 // cm, from the tram model
    /// Door positions along the vehicle (cm from its front), on the
    /// platform side.
    pub doors: Vec<i32>,
}
```

- **Validation** (`city validate`), each failure named in the error:
  - the centreline is at least two points with no zero-length segment;
  - every stop's `at` lies within the line, and stops are at least one vehicle length apart;
  - both platforms of every stop exist, are outdoor rooms, and adjoin their track: the platform edge lies within 1.5 m of the track at the stop, along the vehicle's length;
  - a track does not cross an indoor room;
  - all numbers are positive, and dwell × 2 < headway;
  - `capacity` ≥ 1.
- **The fixture** (`fixtures/district/generate.py`):
  - The line runs from the west edge of the tram street to the east edge of the district, extended from today's −16 m…50 m to reach the district's extent at both ends.
  - It has two tracks, eastbound on the north side and westbound on the south.
  - **Square stop.** The existing `room:tram-stop` is its north (eastbound) platform. A new south platform room sits across the tracks.
  - **Avenue stop.** New north and south platform rooms at the east end, carved from the avenue and street rooms. The Avenue stop is a new `facility:avenue-stop` with category `transit`.
  - The existing tram-shelter props stay, and each new platform gets one.
  - Rooms that the new platforms displace are resized so no two rooms overlap; the validator's existing overlap check guards this.
- **Arrivals by tram** are opt-in: `city.arrivals = "tram"`, default `"direct"`. With `"direct"`, or with no line, everything behaves exactly as today. That covers the two-room fixture and every existing test.

## 3. The core

**State.** Each vehicle has:

```
VehicleState { id, line, direction, along: i32 (cm), status, riders: Vec<CityId> (boarding order) }
VehicleStatus = Running | Standing { stop, doors_open_until: Tick } | Held
```

Vehicle IDs are `vehicle:<line>:<direction>:<n>`, where `n` counts from the start of the run, so they are deterministic. A vehicle exists from the tick it enters at its portal until it passes the far portal.

Occupants gain two locations:

```
Location::WaitingFor { stop, direction: Option<Direction> }   // on a platform, queued
Location::Aboard { vehicle, slot: u32 }
```

`Walk` gains a purpose, `ToPlatform { stop }`.

**The Vehicles phase.** It runs after Transition and before Depart, so the order becomes Ingest → Expire → Admit → Allocate → Transition → **Vehicles** → Depart → Emit. Each tick, in vehicle-ID order:

1. **Enter.** At a timetable tick, a new vehicle appears just outside its portal. Inbound arrivals are placed aboard it (see Arrivals below).
2. **Move.**
   - A running vehicle advances `speed` cells along its track, stopping exactly at the next stop's `at` if it reaches it this tick.
   - It never moves into a ground cell a public walker holds or has reserved this tick. If its path is blocked it becomes `Held`, logs `VehicleHeld`, and tries again next tick.
   - Walkers treat the cells a vehicle covers as blocked. Their existing replanning takes them round it, and a walker already crossing finishes its step first. Walkers go in city-ID order and vehicles after them, so a tram yields rather than overruns.
3. **Stand.** On reaching a stop the doors open (`DoorsOpened`) for `dwell` ticks.
   - While they are open, riders whose destination is this stop step off (`Alighted`) onto platform cells beside the doors, in slot order. If a platform is full of walkers, the rider waits aboard until a cell frees; if the doors close first, they ride on to the next stop.
   - Then platform waiters for this direction board (`Boarded`), first come, first served, up to capacity. The rest keep waiting (`LeftBehind` names who).
   - The doors close (`DoorsClosed`) and the vehicle runs on.
4. **Leave.** Passing the far portal, the vehicle is removed. Its riders depart the city (`Departed { via: vehicle }`), exactly as a departure does today: seats released, the occupant `Away`.

Hidden occupants (personal agents, observers) ride without a slot. They never count against capacity or boarding order, and they never draw on shared state, following the existing overlay rule.

**Arrivals** (`arrivals = "tram"`):

- An `Arrive` enqueues the occupant for the next vehicle entering in either direction. The two portals take turns, alternating by arrival order.
- The occupant rides aboard it to the stop nearest their target room, measured by walking distance from each platform (a precomputed field), and steps off.
- They then walk to the room as an ordinary `Go`: admission, overflow, waitlist and seat unchanged.
- **Players** (`Session::join`) arrive the same way. The first thing a new player sees is stepping off the tram at the Square stop.

**Departures:**

- A `Depart` for a public occupant on the ground becomes a walk (`ToPlatform`) to the nearest stop's platform. The platform is the one for whichever direction's next vehicle arrives first there, and ties go eastbound.
- The occupant waits there, boards, and leaves at the portal.
- An occupant already `WaitingFor` or `Aboard` departs with the vehicle.
- Hidden occupants still depart at once, as today: no one sees them, so no one sees them leave.

**Player commands.** Two join `Go`, `Steer` and `Depart` under the authority rule, where a session commands only its own occupant:

- **`Board`.** Valid while the player stands in a platform room of a stop where a vehicle in that platform's direction stands with its doors open and room aboard. The player boards at once.

  If no vehicle is there yet, `Board` means "wait for the next one": the player becomes `WaitingFor` and boards when it opens.

  Rejections: `NotOnPlatform`, `VehicleFull`, `NotYourDirection`. The last one never applies to `WaitingFor`, which takes the next vehicle that stands at that platform.
- **`Alight`.** Valid aboard a vehicle standing at a stop with its doors open. Rejection: `NotStanding`.
- **Players never ride out.** Aboard, a player's destination defaults to the last stop in the district in that direction. They are let off there, and `Depart` is how they leave.

**Events.** New `EventKind`s: `VehicleEntered`, `VehicleHeld`, `DoorsOpened`, `DoorsClosed`, `VehicleLeft`, `Boarded { vehicle }`, `Alighted { vehicle, stop }`, `LeftBehind { stop }`. New `RejectReason`s as listed above.

**Invariants.** The property tests gain these, checked every tick:

- a vehicle's public riders never exceed its capacity;
- an occupant is in exactly one of: a room, `WaitingFor`, `Aboard`, `InTransit`, or away;
- `Boarded` and `Alighted` events happen only on ticks when that vehicle is `Standing` with open doors;
- no vehicle's footprint cell is held by a public walker;
- riders hold no ground cells;
- the event log is byte-identical on replay, as for everything else.

The existing "no two public occupants share a cell" invariant excludes riders, who are not on the ground.

## 4. What viewers receive

`Projection` gains `vehicles: Vec<VehicleView>`:

```
VehicleView { id, line, direction, pos (cm point, front centre), heading, along, trail: [along…] (last tick),
              status: "running" | "standing" | "held", doors_open: bool, stop: Option<PlaceId> }
```

- Vehicles carry no rider count. Like `RoomView`, a count would reveal riders this viewer may not see.
- Riders are ordinary `OccupantView`s, in a new `aboard` list, carrying `vehicle` and `slot`. Their `pos` is the vehicle's position plus the slot's offset. Visibility follows the existing rules.
- `city inspect` prints vehicles, and `--vehicle <id>` shows one with its visible riders. MCP's `inspect` takes the same argument. `city schema` exports the new contracts, and the JSON Schemas are regenerated. This satisfies the admission rule in `docs/architecture/AGENT_TOOLING.md`: one contract, for both the CLI and MCP.

## 5. The client

- **Drawing trams from the projection.**
  - The local `tram_clock` and `CityGeometry.tram_at` animation are removed from every pack.
  - `SceneModel` diffs `vehicles` into `vehicle_appeared`, `vehicle_moved` and `vehicle_left` changes. `StyleHost` forwards them to the pack as `spawn_vehicle`, `place_vehicle`, `set_doors` and `despawn_vehicle`.
  - `Motion` interpolates each vehicle along its `trail` over the tick, as it does for walkers. Movement stays smooth at every speed and at the benchmark's frame rates.
- **Riders.**
  - Riders are drawn inside the tram: seated in the seat slots, standing in the standee slots. They are placed in the tram's local space, so they move with it without per-frame work.
  - The tram's windows stay see-through and, at night, lit from inside, as on the neon and anime sheets.
  - Doors animate open and shut on `DoorsOpened` and `DoorsClosed`.
- **Every style** draws its own tram and riders: anime, solarpunk, neon, low-poly and voxel have 3D trams, and pixel art draws the tram sprite with riders as sprites in its windows. Each style's tram gains doors that open, a clear interior and slots, from the style kits.
- **The player:**
  - **On a platform with no tram,** the HUD prompt reads "Wait for the tram" (A or Space) and sends `Board`.
  - **While waiting,** it reads "Waiting — tram in N s", with N from the timetable.
  - **With the doors open,** it reads "Board" (A or Space).
  - **Aboard:**
    - The overhead view follows the tram.
    - First person sits at a window seat looking out on the platform side, with the mouse or right stick free to look around. This is the anime TRANSIT view.
    - At a stop the prompt reads "Get off here" (A or Space) and sends `Alight`.
    - Menus and the map still open, and the world still takes no input while they're open.
  - A ride can't be cancelled between stops.
- **The map:**
  - The route is drawn in the Transit colour.
  - Both stops get Transit pins and cards. The card shows the next tram each way ("East in 12 s · West in 27 s"), from the timetable and the viewer's vehicles.
  - Go to a stop walks there (or glides, for a spectator), as for any place.
- **Notices.** A `LeftBehind` for the player shows "The tram is full — next one in N s", and each rejection reason gets its own notice.

## 6. Structure

| Area | Files |
| --- | --- |
| Contracts | `crates/city-contracts/src/manifest.rs` (`Line`, `Stop`, `Timetable`, `VehicleSpec`, `LineMode`, `City.arrivals`; `Scenery::TramLine` removed), `feed.rs` (`Board`, `Alight`), `snapshot.rs` (`VehicleState`, `Location::WaitingFor`, `Location::Aboard`, `WalkPurpose::ToPlatform`), `event.rs`, `projection.rs` (`VehicleView`, `aboard`) |
| Core | `crates/city-core/src/transit.rs`: the Vehicles phase, arrivals and departures by tram, and the platform fields. Also `world.rs` (phase order, departures, player commands), `index.rs` (line validation), `project.rs` (vehicles, aboard) |
| Tools | `crates/city-cli` (`inspect --vehicle`), `crates/city-mcp` (the same), and regenerated schemas |
| Bridge | `crates/city-godot/src/bridge.rs` (`board`, `alight`; arrival by tram) |
| Fixture | `fixtures/district/generate.py` → `manifest.json` (the line, platforms, Avenue stop, `arrivals: "tram"`) |
| Client | `core/scene_model.gd`, `core/motion.gd`, `core/style_host.gd`, `core/player.gd` (`board`, `alight`, waiting state), `main.gd` (prompts, notices), `styles/style_pack.gd` (vehicle hooks), each pack and its townscape (trams from the projection), `core/map/*` (route, stops, next tram) |
| Kits | each style's tram model gains doors, an interior and rider slots (`tools/styles/*`) |

## 7. Testing

- **Rust unit tests:**
  - line validation, with one test per failure message;
  - the timetable: entry ticks, the positions reached, and stopping exactly at `at`;
  - boarding order and capacity, and `LeftBehind`;
  - alighting onto free platform cells, and riding on when the doors close first;
  - holding for a walker;
  - departures walking to the right platform;
  - arrivals stepping off at the stop nearest their target;
  - players never riding out;
  - hidden riders taking no slot;
  - `Board` and `Alight` rejections;
  - both arrival modes, including `"direct"` unchanged.
- **Property tests.** The invariants of §3, over generated manifests that include a line (the `layout_world_strategy` gains lines and platforms).
- **Scenario gates.** The two-room fixture is unchanged (direct). The district fixture over one day meets success criterion 2, checked from the log. The log is byte-identical on replay.
- **Contracts.** Round-trip tests for the new types, the schema export, and a manifest without a line.
- **The bridge.** Joining by tram, then `board` and `alight` from a session, and the authority rule for both.
- **GDScript:**
  - `SceneModel` vehicle diffs;
  - `Motion` interpolation of a vehicle;
  - each pack spawns, moves and despawns a tram, and places riders inside;
  - the player's prompts through wait, board, ride and alight, with keyboard and controller;
  - the map's route, stops and next-tram line;
  - no local tram clock remains.
- **Evidence.** For each style, captures of:
  - boarding at the Square stop;
  - riding in first person (compared with the anime TRANSIT panel);
  - the lit tram at night;
  - overhead with passengers.

  These are laid out beside the sheets' TRANSIT panels in `city/godot/evidence/tram-vs-sheets.png`, with notes.
- **Benchmark.** A "tram" scene per style with two trams carrying 40 riders each, at crowd 60, measured style by style from a cool GPU.

## 8. Not in this spec

- **The tour tram (U06),** which comes next: captions, a camera path, pause and skip.
- **Fares** and sponsored routes. Riding is free, as the city plan says.
- **More lines,** more districts, buses and ferries (`LineMode` leaves room for them), and a depot.
- **Timetable changes at runtime,** and disruptions.
- **Routing people by tram inside the district** for ordinary trips. The district is small, so only arrivals, departures and players ride.

## 9. Risks

- **The fixture's timing changes.** Guild agents now arrive a little later: the ride plus the walk. Tests that expect an agent in its room at a given tick need updating, or they can run with `"direct"`. *Mitigation:* the district gate's checks read the log's own events rather than fixed ticks, and any fixed-tick expectations move with a stated reason.
- **Trams and walkers on the same cells.** Crowds crossing the tram street could hold a tram for a long time. *Mitigation:* a held tram's footprint blocks new walkers from stepping onto the track (they replan round it), so it clears as walkers finish their steps. A test holds a tram with a walker and checks it moves within a bounded number of ticks.
- **Riders' cost in the client.** Eighty riders inside two trams are more people models. *Mitigation:* the animation level-of-detail already in the packs applies. Riders are children of the tram, so they need no per-frame placement, and the benchmark scene measures it.
- **Kit work for six trams.** Doors, interiors and slots for every style's tram is real art work. *Mitigation:* one shared tram layout (door positions, slot grid) comes from the kit scripts, and each style skins it.

## 10. Amendments

### 2026-09-27: decided during the build

The build settled these points, which the sections above leave open or
say differently. Where they differ, these hold.

**The core.**

- **A standing vehicle is centred on its stop's `at`,** not fronted on
  it. `VehicleView.pos` is still the front's centre, so a standing
  vehicle's front is half its length past `at`. Validation checks the
  platforms along that centred body.
- **A blocked portal makes a vehicle wait.** A vehicle due to enter while
  the one before it is still in the portal waits there, and enters as
  soon as the portal clears. It keeps its timetable number `n`, and
  `VehicleEntered` is logged on the tick it actually enters. A further
  invariant holds on every tick: vehicles on one track never overlap.
- **The slot layout** is two across and `ceil(capacity / 2)` rows. Row
  `r`'s middle lies `(2r + 1) × length / (2 × rows)` cm behind the front.
  Even slots sit half a metre left of the way the vehicle runs, and odd
  slots half a metre right. A row whose middle is within 65 cm of a door
  is standing room, and every other row is a pair of seats. The core
  (`transit::slot_along`, `project::slot_point`), the client
  (`CityGeometry`) and the kits (`tools/styles/shared/tram_layout.py`)
  share it. A boarder takes the lowest free slot.
- **Hidden riders** are `Aboard` with `slot = u32::MAX`. They are never
  given a projected slot, and are drawn at the vehicle's centre.
- **Waiters stand on their platform.** A `WaitingFor` occupant holds its
  cell and is shown as an occupant of the platform room, marked
  `waiting_for` (its stop and direction). A waiter always has a direction,
  and every waiter has a `waiting_since` entry. Waiters count toward
  their platform's capacity.
  - Stepping or `Go`ing off the platform cancels waiting.
  - A `Depart` while waiting or aboard means riding out.
- **Stepping off ignores capacity.** Riders bound for a stop are players
  and arrivals, who are there in person once off. They step off even when
  the platform room is at capacity, onto a free cell within reach of a
  door, so a platform may briefly hold more than its capacity. Capacity
  gates walkers entering a platform from the street.
- **The terminal hold is bounded.** At the last stop in its direction, a
  vehicle with riders still bound there holds its doors open. While held,
  they may step off anywhere on the platform. The hold lasts at most one
  dwell past the doors' closing time. Then the remaining riders step off
  onto the nearest free standing cell a walk from the doors reaches,
  whatever its room's load, and the doors close.
  - Every platform must have somewhere off the track to stand. Building
    the world checks this, but `city validate` does not yet.
- **Arrivals take turns by their own counts.** Public arrivals and hidden
  arrivals each alternate portals, east first, by their own count. A
  hidden arrival never shifts a public one's portal.
- **A joining player takes the vehicle that reaches the Square soonest.**
  That is the vehicle that stands at its platform's stop first, counting
  its entry, its run and the stops before it; ties go east. It is not the
  one that enters first, and not the arrivals' turn. A player joining for
  a platform steps off at that stop and stays on the platform on its
  vehicle's side. Agents and the crowd keep taking turns.
- **`Arrive` gains `player`,** which is omitted when false. It marks a
  joining player, since an occupant's kind cannot tell a crowd human from
  a player.
- **`LeftBehind` names the vehicle** as well as the stop.
- **Queued arrivals are not projected** until they are aboard. No one
  sees a portal.
- **`VehicleView.trail`** is the vehicle's `along` at the start of the
  last tick and now, when it moved. The core keeps each vehicle's
  previous `along` for it.

**The fixture.**

- **The tracks are 3 m apart,** at ±150 cm from the centreline. The tram
  street is 6 m wide. The 3D trams keep their modelled width; they are
  not squeezed to fit.

**The client.**

- **The opening views keep their framing.** The diagonal and street views
  frame the district without the transit platform rooms, as before the
  tram. The top-down view still frames everything.
- **The roof fades.** In the overhead views, close up, a tram's roof fades
  like a building's cut-away, so its riders show.
- **Trams fade at the portals.** A tram fades in and out over the last
  10 m at each portal. The fence and the park's edge leave a gap where
  the tracks run out of the district.
- **The prompts wait their turn.** On a platform the player has just
  stepped onto, whether joining or getting off, the tram is not offered
  ("Wait for the tram" or "Board") until the player moves or has stood
  there for 5 s. So a player is never offered the tram they just left.
  First-person targets off the platform take priority over the tram.
  While the player waits, A does nothing.
- **The bridge has `take_player_events`.** It returns the player's own
  events since they were last taken: refusals, boarding, stepping off and
  being left behind. It drives the notices, and it strips each event's
  sequence number.
- **"Tram in 0 s" can mean a full tram.** Vehicles carry no rider count,
  so the prompt cannot know that a standing tram is full.
- **The seated eye is part of the layout.** First person aboard sits
  120 cm over the tram's floor, and the floor is 40 cm over the rail. The
  shared layout now records this as `seated_eye_cm`, and a check in
  `tram_checks.py` requires every kit's side windows to run from at least
  20 cm below that eye to at least 50 cm above it. The low-poly tram's
  sills were at the eye (1.6 m over the rail), so a seated rider saw
  mostly wall. They are now at 1.25 m, as in the anime tram.

**Evidence and the benchmark (§7).**

- **The tram scene** (`core/bench.gd`) is the diagonal view at 13:38. It
  is moved at the same angle and distance to the middle of the boulevard
  (`centre`), so that both trams are in view.
- **How its trams fill.** Eighty public citizens arrive at tick 136
  (`TRAM_LOAD`). Half ride in on the eastbound tram entering at 150, bound
  for the Avenue, and half on the westbound tram entering at 165, bound
  for the Square.
  - From tick 166 to 174 both trams carry 40 in view, and the scene
    starts at tick 166.
  - At 175 the eastbound tram lets its riders off at the Avenue.
  - Arrivals take turns at the portals, so the rooms' order is chosen on
    a throwaway world, whichever order fills both trams.
  - The scene boots its own world in each style.
- **The captures** (`tools/sheet_views.gd`'s `tram` mode) use the same
  load, and a second load at night. The player joins between two parts of
  the day's load, so that it rides in a window seat in the middle car.

### 2026-09-27: the final review's fixes

The final review and the evidence found these; where they differ from
the sections and amendments above, these hold.

**The core.**

- **The district's first eastbound tram enters on tick 1** (offsets
  `[1, 16]`; ticks run from 1, so an offset of 0 entered a headway late).
  A player joining at launch boards at once and steps off at the Square
  on tick 6.
- **No one holds a tram for long.** A vehicle held five ticks in a row
  (`transit::STEP_ASIDE_AFTER`) has each public walker in its way stepped
  aside, within that walker's steps left in the tick, to the nearest good
  place to stand off the track (`SteppedAside { from, to }`). A walk that
  led onto the track ends; one going elsewhere plans afresh. The vehicle
  moves the tick after.
- **A player's leave is at once.** `Depart` gains `player`, omitted when
  false, which only a session's `leave` sets. Such a departure leaves at
  once from wherever the player is: on the ground, waiting, aboard or
  queued at a portal. It is the one exception to departures walking or
  riding out; players never ride out, and Quit to title then Explore
  must not wait for the last visit to walk away.
- **`Board` on a full standing tram waits** for the next one, as the
  notice says; the full tram leaves the player behind (`LeftBehind`) as
  its doors close. `VehicleFull` stays in the contract, unused.
- **Players sit mid-car.** The slot grid's first and last rows lie in the
  cabs' walled noses, so a player (one that joined with `player`, or
  asked to `Board`) takes the free seated slot whose row is nearest the
  vehicle's middle, the lower (left) slot first. Everyone else keeps the
  lowest free slot. The shared layout is unchanged.
- **A player walks only where it is told.** Carried past its stop (every
  cell there taken), a joining player stays where it stepped off; it is
  not walked back.
- **Hidden riders never hold the doors** at the last stop; with only
  hidden riders still aboard they step off wherever there is room, and
  the doors close on time.
- **Validation** also refuses tracks closer than a vehicle's width
  (`line-tracks-too-close`) and doors outside the vehicle's length
  (`line-door-outside-vehicle`).
- **Queues keep off the tracks.** No queue place lies on a track or runs
  across one.

**The client.**

- **Joining by tram,** Explore flies the view to the Square's stop, the
  HUD counts down ("Your tram reaches the Square in N s", by the
  timetable) while the player waits at the portal or the last visit
  leaves, and once aboard the view follows the tram in.
- **At a line's last stop** the platform says where the trams back leave
  from ("Trams west leave from the other platform"), and the map's Go to
  a stop walks to the platform with trams going on.
- **Stepped aside,** the player is told: "You stepped off the tracks for
  the tram".
- **Riders cost what can be seen of them** (criterion 4). Aboard, they
  cast no shadow (they are in the tram's); seated or standing, each is
  posed once as it boards and holds that pose, never looked at again per
  frame; in a tram further off than 25 m a kit's far body alone is drawn,
  the near parts hidden outright and the body without its ink outline (a
  kit with no far body sheds the riders' shoes and backpacks instead);
  and with the roof on they are hidden
  where they cannot be seen: from more than 45 m off looking down on the
  roof from 60° or more above the horizontal, or from more than 150 m.
  Through the windows from the diagonal and street views, up close, in
  first person and overhead with the roof faded they show as before.
