# The tram against the sheets

`tram-vs-sheets.png` holds one row per style. Each row shows:

- the style's sheet-02 TRANSIT panel (top right of "Creating and
  exploring"), at the revision its study's README selects: anime r002,
  solarpunk r003, neon r003, pixel art r004, low-poly r002 and voxel r002;
- four captures at 1920 × 1080, scaled whole to the panel's height and not
  cropped:
  - **riding**, in first person, as the tram pulls in to the Square;
  - **at the Square stop**;
  - **at night**, with the tram lit;
  - **overhead**, with passengers.

The composite is at half the sheets' size.

The tools:

- `tools/sheet_views.gd -- <style> tram` writes `tram-ride.png`,
  `tram-board.png`, `tram-night.png` and `tram-overhead.png` into
  `~/.cache/agentnagar-sheets/<style>/`. Each is rendered at exactly
  1920 × 1080 whatever window the desktop gives, and all 24 are that size.
- `tools/tram_compare.py` composes the sheet.

The trams are full because the captures script their riders:

- **By day,** the bench's load (`Bench.TRAM_LOAD`): 80 citizens arriving
  at tick 136. Half ride the eastbound tram that enters at 150, and half
  the westbound one that enters at 165.
- **At night,** a second load of 80 at tick 346. The eastbound tram that
  enters at 360 carries 40 of them.
- **The player** joins between two parts of the day's load. It rides the
  full eastbound tram in slot 22, the free window seat nearest the
  tram's middle, beside the middle door.

The overhead and night captures' trams each reported 40 riders aboard.
The player's tram had 39 others with it.

The ticks here are the captures' own. Since the final review the first
eastbound tram enters on tick 1, not 30, so every tram enters a tick
later than below; `tools/sheet_views.gd` and `Bench.TRAM_LOAD` wait one
tick more to match.

The four captures, in the game's terms:

- **Riding.** First person at the player's seat at tick 154 (13:09), as
  the tram pulls in to the Square, facing the platform side (north), as
  the ride starts it. Pixel art has no first person, so it shows its
  close view over the tram.
- **At the Square stop.** Tick 188 (14:31). The westbound tram stands with
  its doors open, and its 40 riders have just stepped off onto the south
  platform. The view is at eye height from the platform's east end,
  looking along it. Pixel art shows its close view over the stop.
- **At night.** Tick 368 (21:43). The full eastbound tram stands at the
  Square with its doors open and its lamps lit. The view is at eye height
  from the south platform, across the tracks. Pixel art shows its close
  view.
- **Overhead.** Tick 170 (13:48). The diagonal view, 30 m out, is centred
  on the fullest tram: the westbound one, standing at the Avenue with 40
  aboard. Up close, the roof fades.

I looked at every capture at full size and at the composite.

## Every style

Matches:

- **The livery.** A cream three-section articulated tram with a red (or,
  in voxel, orange) band, dark-framed windows and glazed doors, on two
  tracks under overhead wires. It stands at a shelter on the Square's
  platform. This is the consistency contract's tram.
- **Riders show through the windows.**
  - By day, from the platform, riders show through the open doors and the
    glass.
  - At night the interior is lit warm, and seated and standing
    silhouettes fill the windows. In the 3D styles this reads close to
    neon's panel.
  - Overhead, with the roof faded, the 40 riders show in their two rows
    of seats and the standing room by the doors — except in pixel art,
    whose overhead is far and steep enough to cross the kit's distance
    cull, so its tram's windows are dark there (see below).
- **The ride's view.** It looks out on the square, as anime's panel does.
  Through a big dark-framed window the rider sees the plaza's paving,
  bollards and lamps, the tree, the workshop on the left and the library
  on the right.

Differs:

- **Boarding is a jump, not a walk.** The core moves a rider on or off on
  the tick the doors open, and the client sets it down at once. The
  captures therefore show people on the platform by the open doors, just
  off. No capture shows anyone mid-step through a doorway, as solarpunk's
  and pixel art's panels do.
- **The ride's interior is bare.**
  - The sheets' interiors are busy: riders beside and in front of the
    viewer, grab poles, hanging straps and a "next stop" sign in voxel.
  - The game's first person now sees mostly window: seated at the free
    seat nearest the tram's middle (slot 22, the fix described below),
    the view is dominated by the side glass, split into two panes by a
    dark mullion, with only a sliver of the car's own wall at the edges
    and a glimpse of a seat cushion at the bottom. The other riders are
    behind the eye, or ahead of it and out of frame, and there are no
    straps or sign.
  - The window now fills nearly the whole frame, not about half of it as
    it did from the nose seat the earlier captures used.
- **No wet reflections.** Neon's panel is a rainy night, with the tram's
  light reflected in the street. The night capture is dry (21:43, after
  the evening shower), so nothing is reflected.
- **The night figures are dark.** The waiting figures in the foreground
  are silhouetted against the lit tram, darker than the sheets draw
  people at night. The voxel capture is the darkest.

## Anime (06)

The ride is the closest match to its panel: the square, the tree and the
library through the window, and paving and bollards in the foreground.
The panel also has another tram at the stop and riders in the seats
round the viewer, which the capture does not.

The inside wall is a flat lavender; the sheet's is warm cream.

## Solarpunk (09)

The panel shows the tram side-on at the platform, people walking in
through its doors, and the domed library behind.

The captures have the same tram: cream, red band, dark-tinted glass. The
platform view looks along the tram rather than straight at it, so it
shows the people just off at the far door but not the side-on
composition. At night the lamps and the gold shelter posts glow.

## Neon noir (10)

Its night capture is the closest match in the set. It shows:

- the tram lit warm from inside, with every window lit;
- riders' silhouettes seated and standing;
- the red skirt;
- the market hall and the lit towers behind.

It lacks the panel's wet street and reflections, as noted above.

## Pixel art (08)

The panel is a platform-level view of people boarding. Pixel art has no
eye-level view, so its four captures are all its isometric close view:

- over the tram at the Square (riding);
- over the stop (boarding);
- at night;
- the diagonal overhead.

In the riding and boarding captures the riders show as small figures in
the tram's windows, and the player is marked by its arrow. The overhead
capture's isometric camera is far and steep enough to cross the kit's
distance cull, so its tram's windows are dark and empty there — unlike
the other five styles' overhead captures, which still show riders. At
night the tram's platform side faces away from the camera and its
riders are hard to make out. The sheet's close platform perspective,
with its sign and people at the doors, has no counterpart.

## Low-poly tropical (11)

The panel is an inside view: riders on green seats, grab poles, and the
square through large low windows.

- **The windows were too high.** The first captures found the low-poly
  tram's windows starting 1.6 m above the rail, which is exactly a seated
  rider's eye (40 cm of floor plus 1.2 m). The first-person view out was
  cut in half by the sill.
- **The fix.** The kit now puts the sills at 1.25 m, as in the anime
  tram, and the red skirt runs up to them. A shared kit check
  (`tram_checks.py`) holds every style's windows to at least 20 cm below
  that eye and 50 cm above it. The ride now looks out over the square.
- **What still differs.** The game's seats are teal, as on the kit, and
  there are no grab poles in view.

## Voxel (02)

The panel is also an inside view: blocky riders, A1 in the foreground, and
a "Next stop: Tree Square" sign.

The ride looks out on the workshop, the tree and the library, as the
panel does, with the window's orange frame. The panel's riders, sign and
A1 are not in the capture. The night capture is dark: the interior lights
are warm but weaker than in the other styles, and the foreground figures
are black shapes.

## The seated eye

The riders now stand on the tram's floor, 40 cm up. So first person
aboard puts a seated rider's eye at 1.6 m over the rail: 120 cm over the
floor (`FpvCamera.SEATED_EYE`, the layout's `seated_eye_cm`).

- **Anime, solarpunk and neon.** Their windows run from 1.25 m to 2.55 m,
  so the eye is 35 cm above the sill.
- **Voxel.** Its windows run from 1.3 m to 2.5 m over the rail, and the
  tram stands 10 cm up in its node, so the eye is about 30 cm above the
  sill.
- **Low-poly.** The eye was at its sill, and was fixed as above.

`test_fpv.gd` checks that the client's seated eye is the layout's, and the
kit check holds every tram's windows to it.

One thing the captures showed was fixed after them, in the final
review's fix wave:

- **The front row sat in the tram's nose.** The slot layout spreads its
  rows over the whole 20.5 m, so row 0 is 51 cm behind the front. That is
  in the cab's rounded nose, whose side is solid wall except for a sliver
  of window, and a boarder took the lowest free slot, so a player who
  joined at launch, or boarded a near-empty tram, sat there and looked at
  a wall in first person.
- **The fix.** The layout is unchanged (every kit's seats stay where they
  are), but a player now takes the free seat nearest the tram's middle,
  the left one of a pair first: slot 22, 11.78 m behind the front, in the
  middle car, beside the middle door. `test_ride.gd` checks that a lone
  player's seat has the tram's side glass beside it at a seated eye, and
  that the front row's has none. The crowd keeps the lowest free slot.
- **The captures now show it.** The retake needs no scripted seat: the
  capture tool joins the player normally, and every style's log reports
  `the player rides ... in slot 22`, the free seat nearest the middle,
  beside the middle door. The ride captures above are the first to show
  that seat, replacing the earlier ones that placed the player in slot 16
  by scripting the load round its join.

## Performance

### Method

As in `interface-notes.md`:

- **The setup.** The development laptop (RTX 3070 Ti Laptop GPU,
  1920 × 1080 panel at 360 Hz, COSMIC) on
  `system76-power profile performance`, fullscreen at native
  resolution. Every scene rendered at 1920 × 1080.
- **Each style alone,** from a GPU below 60 °C: its diagonal view, then
  the tram scene. The scripts were `scripts/bench.sh` with
  `BENCH_STYLES=<style>` and `BENCH_SCENES=diagonal`, then `tram`. Each
  run started at 48–59 °C.
- **Temperatures and clocks** were sampled every half second
  (`nvidia-smi`). Every run peaked at 63–76 °C, well below the 86–87 °C
  where this GPU throttles. Every scene's median graphics clock was
  1575–1635 MHz, so each pair compares equal clocks.

**The tram scene** (`Bench.SCENES` "tram"):

- It is the diagonal view at 13:38, at the same angle and distance, but
  moved to the middle of the boulevard (x 35 m) so that both trams are in
  view. The world runs at 1× with a crowd of 60.
- `Bench.TRAM_LOAD`'s 80 riders fill the two trams, and the bench reports
  them in every run:
  - 40 and 40 as sampling starts, and after the uncapped half;
  - 1 and 40 at the end, since the eastbound tram lets its riders off at
    the Avenue at tick 175, about 9 s into the sample.
- The scene boots its own world in each style. `test_bench.gd` checks
  that both trams are full and in the view as the scene starts, and eight
  ticks on.

### The desktop was degraded

Every figure below must be read with this. This session's empty scene
gave 286–292 fps and missed about 1.9% of refreshes, against 342–343 fps
in the interface notes.

- **An empty-scene probe** (`~/.cache/agentnagar-perf/empty.gd`) stalled
  for about 42 ms every 191 ms. That is the degraded-desktop pattern the
  README describes, which a restart of the session has cleared before.
- **The uncapped 99th percentiles** of the 3D styles are 32–43 ms for the
  same reason, so they measure the desktop, not the game.
- **What can still be judged.** The comparisons below are between scenes
  measured in the same session at equal clocks. The absolute gate should
  be judged again after a restart.

### Results

Figures are frame rates in fps at vsync (360 Hz), the share of refreshes
missed, the uncapped median frame time, the game's GPU time (99th
percentile), and the peak temperature. Bold marks a scene under the
normal-play gate, which is 97% of that run's empty scene.

| Style | Diagonal | Tram (2 × 40 riders) | Change in median frame |
| --- | --- | --- | --- |
| anime_cel | 286.6, 2.09%, 2.46 ms, GPU 2.39 ms, 65 °C | **213.2**, 19.98%, 3.97 ms, GPU 2.68 ms, 67 °C | +1.51 ms |
| solarpunk | **263.2**, 2.20%, 3.03 ms, GPU 3.03 ms, 73 °C | **221.8**, 15.51%, 3.74 ms, GPU 3.10 ms, 74 °C | +0.71 ms |
| neon_noir | 286.0, 1.96%, 2.62 ms, GPU 2.56 ms, 74 °C | **228.4**, 12.43%, 3.80 ms, GPU 2.67 ms, 72 °C | +1.18 ms |
| pixel_art (no budget) | 288.4, 1.87%, 0.89 ms, GPU 0.26 ms, 64 °C | 287.4, 2.09%, 0.88 ms, GPU 0.28 ms, 63 °C | none |
| lowpoly_tropical (no budget) | 211.2, 17.80%, 3.60 ms, GPU 3.37 ms, 74 °C | 119.8, 100%, 6.73 ms, GPU 3.75 ms, 71 °C | +3.13 ms |
| voxel (no budget) | 232.0, 7.41%, 3.41 ms, GPU 3.92 ms, 76 °C | 126.8, 100%, 6.41 ms, GPU 3.56 ms, 70 °C | +3.00 ms |

**Success criterion 4 is not met.** With two full trams in view:

- Anime and neon drop from their diagonal views' 286 fps to 213–228 fps.
  Their diagonal views pass the gate; the tram scene misses it.
- Solarpunk, already below the gate in its diagonal view (pre-existing),
  drops further, from 263 to 222 fps.
- Low-poly and voxel, which declare no budget, fall to 120–127 fps, which
  is every third refresh.
- Pixel art is unaffected.

**The cost is tram-caused, and it is on the CPU.** The GPU time barely
moves (−0.4 to +0.4 ms), while the median frame time rises by 0.7–3.1 ms.

### Where the cost goes

A probe (not committed) sampled the tram scene at tick 169 with the world
paused, in four ways: as it is, with the riders hidden, with the riders'
shadows off, and with their animation stopped. In low-poly, hiding the
trams' bodies instead left the frame time unchanged.

| Style | As is | Riders hidden | Riders' shadows off | Riders not animated | Draw calls, as is and hidden |
| --- | --- | --- | --- | --- | --- |
| anime_cel | 3.53 ms | 2.39 ms | 3.23 ms | 2.89 ms | 3,258 and 1,815 |
| lowpoly_tropical | 6.59–6.73 ms | 4.08 ms | 5.85 ms | 5.74 ms | 8,750 and 6,156 |

So the tram's cost is drawing 80 more people:

- **Anime** pays 1.1 ms for them. About 0.6 ms of that is their animation
  and 0.3 ms their shadows.
- **Low-poly** pays 2.5 ms. About 0.9 ms of that is animation and
  0.75 ms shadows. Its people have about 32 draw calls each, shadows
  included.

The animation level of detail already applies to riders. At this
distance it advances each of them every fourth frame, about 70 Hz at
these frame rates.

Possible remedies, none of them made here (the final review's fixes made
them; see "After the fixes" below):

- **Riders cast no shadow while aboard.** They sit under the tram's roof,
  inside its shadow. This saves 0.3–0.75 ms.
- **Riders animate at a low rate,** or hold a still pose while aboard.
  This saves 0.6–0.9 ms.
- **Riders are drawn simpler at a distance.**

Together the first two would bring anime and neon close to their
diagonal views, but not low-poly or voxel. Whether to accept the cost,
reduce it, or relax criterion 4 for trams full to capacity is left for a
decision.

### After the fixes

The final review's fix wave made riders cost what can be seen of them
(`Pack3D`, tram spec amendment "the final review's fixes"):

- **No shadows aboard.** Riders sit in the tram's own shadow.
- **A still pose.** Seated or standing, a rider is posed once as it
  boards and holds that pose. It is never looked at again per frame.
- **The far body, from 25 m.** In a tram further off than 25 m, a kit's
  far body alone is drawn, without its ink outline. The near parts are
  hidden outright, so a moving tram carries nothing nobody sees. A kit
  with no far body (low-poly, voxel) sheds the riders' shoes and
  backpacks instead.
- **Hidden where they cannot be seen.** With the roof on, riders are
  hidden from more than 45 m off looking down on the roof from 60° or
  more, or from more than 150 m. From the diagonal and street views they
  still show through the windows.

**Method.** As above, in one session on 2026-09-27, the desktop degraded
as before: the empty-scene probe stalled 48–51 ms every 198 ms, and the
bench's empty scene gave 275–281 fps with 1.8–2.3% of refreshes missed.

- **Each style alone,** every run from a GPU below 60 °C (each started at
  57–59 °C and peaked at 65–78 °C; every scene's median clock was
  1552–1635 MHz): its diagonal view, then the tram scene before the fixes
  (`styles/pack_3d.gd` as at 7b83ac5, everything else as now), then the
  tram scene after.
- **The riders' own cost** is measured as the first notes measured it: a
  probe (not committed) boots the tram scene, stops the world at tick 170
  with both trams full and in view, and times frames uncapped as they
  are and with every rider hidden. The difference is what the riders
  cost a frame.

The same session's diagonal views, and the tram scene before and after:

| Style | Diagonal | Tram before | Tram after | After, share of diagonal | Riders' cost a frame, before → after |
| --- | --- | --- | --- | --- | --- |
| anime_cel | 274.2 fps, 2.12%, 2.42 ms | 197.2 fps, 26.98%, 3.75 ms | 264.2 fps, 2.88%, 2.67 ms | 96.4% | 1.010 → 0.035 ms |
| neon_noir | 275.0 fps, 1.96%, 2.57 ms | 217.8 fps, 12.58%, 3.44 ms | 270.8 fps, 2.81%, 2.72 ms | 98.5% | 0.740 → 0.029 ms |
| solarpunk | 252.2 fps, 2.14%, 3.03 ms | 215.4 fps, 13.83%, 3.46 ms | 240.4 fps, 3.99%, 3.09 ms | 95.3% | 0.269 → 0.014 ms |
| pixel_art (no budget) | 276.6 fps, 1.95%, 0.86 ms | 276.8 fps, 2.02%, 0.85 ms | 275.6 fps, 2.03%, 0.86 ms | 99.6% | 0.017 → 0.020 ms |
| lowpoly_tropical (no budget) | 205.8 fps, 14.58%, 3.50 ms | 119.8 fps, 100%, 6.42 ms | 151.4 fps, 100%, 4.89 ms | 73.6% | 2.116 → 0.604 ms |
| voxel (no budget) | 218.4 fps, 9.43%, 3.32 ms | 122.4 fps, 100%, 6.30 ms | 156.0 fps, 100%, 4.81 ms | 71.4% | 2.147 → 0.756 ms |

Each cell is the frame rate at vsync (360 Hz), the share of refreshes
missed and the uncapped median frame. The anime row's diagonal and
"after" are a second pair taken once its far riders dropped their ink
outline; its first pair gave 278.2 and 263.0 fps (riders 0.139 ms).

What this shows:

- **The riders' cost is gone from the 3D styles with far bodies.** In
  anime, neon and solarpunk they cost 0.01–0.04 ms a frame, down from
  0.27–1.01 ms. Hiding them altogether gains nothing measurable.
- **Neon passes** the normal-play gate relative to its diagonal view
  (97%), and is above the 240 fps floor.
- **Anime and solarpunk are just short of 97%** of their diagonal views
  (96.4% and 95.3%), and above 240 fps. What is left is not the riders:
  the same scene with every rider hidden gave 275.8 fps in anime. It is
  the two trams and the 40 riders who step off at the Avenue during the
  sample and walk. Two anime runs of the same code differed by 4 fps
  (263.0 and 266.8 fps), so on this desktop the anime figure is within
  the noise of the gate; solarpunk's diagonal view is itself below the
  absolute gate, as before.
- **Low-poly and voxel improve by a quarter** (120–122 to 151–156 fps)
  but stay far below their diagonal views. Their kits have no far body,
  so each of their 80 riders is still six parts drawn (four once shed),
  0.6–0.76 ms a frame; and the scene without riders is itself 0.3–0.5 ms
  slower than their diagonal views. A far body in those kits, as the lit
  kits have, is the remedy left; neither declares a budget.
- **The absolute gate should be judged again after a restart.** The
  desktop was degraded throughout, as in the first measurement.


The concept-sheet panels in `tram-vs-sheets.png` are crops of AI-generated concept art
(CC0 1.0); see [the evidence README](README.md).
