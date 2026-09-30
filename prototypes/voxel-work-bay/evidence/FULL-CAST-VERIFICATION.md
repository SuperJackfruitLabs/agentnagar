# Full-cast verification — 2026-09-23

Revision: **shared-workshop-r004**. Local sample data only. **Only Kai's and
Lyra's robot appearances are user-approved** (Kai on 2026-09-22, movement
extension subject to technical verification; Lyra's own appearance on
2026-09-22). **The twelve new appearances — Olivia, Chotu, Pete, Ray, Quill,
Echo, Paul, Sam, Casey, Ollie, Theo, Cody — are not user-approved.**
`character.py`'s `RESIDENTS[*]['review']` carries "operator review pending"
for all twelve, and `asset-manifest.json`'s `appearance_review` mirrors that
verbatim. The environment palette and the hall itself also remain unreviewed
(carried from [r003](HALL-EXPANSION-VERIFICATION.md)). **Nothing in this
milestone is accepted.**

This milestone authors the twelve remaining Guild appearances on the shared
16-bone rig, seats all fourteen residents in the bays r003 reserved, and
scales the runtime (controls panel, all-leave/all-return labels, scene text)
to fourteen. The [r001](SHARED-VERIFICATION.md), [r002](COURTYARD-KIT-VERIFICATION.md)
and [r003](HALL-EXPANSION-VERIFICATION.md) reports are preserved unchanged.

## The fourteen, in roster order

Roster order is `character.RESIDENTS[*]['roster']`, which is also the order
`scripts/shared_workshop.py` zips onto the fourteen `BAYS` anchors: GR01–07
west zone (`x=-3`) north to south, GR08–14 east zone (`x=3`) north to south.
Kai (roster 4) sits at `[-3,0,0]` and Lyra (roster 5) at `[-3,0,2]`, unchanged
from stage 1. Accent is `head_accent`/`thigh_accent` from `RESIDENTS`; where
the two differ (Lyra only), both are given.

| Roster | Bay | GS id | Name | Accent | Chest motif | Review |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | `[-3,0,-6]` | GS-027 / GS-041 pilot subset | Onboarding Olivia | mint | Folded route-map quilt: crossing `cobalt`/`orange` stepped diagonals on a `paper` ground with a `mint` location pip | Pending |
| 2 | `[-3,0,-4]` | GS-028 / GS-041 pilot subset | Super Chotu | orange | Shallow `wood_honey` display shelf, dark `ink` shadow-box back, three miniature prototypes (`steel`/`cobalt`/`orange`) standing proud | Pending |
| 3 | `[-3,0,-2]` | GS-029 / GS-041 pilot subset | Project Manager Pete | navy | `navy` planning board with a grid of `paper` cards, one offset as just-moved | Pending |
| 4 | `[-3,0,0]` | GS-030 / GS-041 pilot subset | Coder Kai | cobalt | Apron, straps, pocket, pencil, badge | **Approved 2026-09-22** |
| 5 | `[-3,0,2]` | GS-031 / GS-041 pilot subset | Artistic Lyra | violet / teal | Colour panels, shoulder tabs, sketch sheets | **Approved 2026-09-22** |
| 6 | `[-3,0,4]` | GS-032 / GS-041 pilot subset | Research Ray | green | Three stacked `wood_dark` drawers with `steel` pull tabs, bottom drawer ajar | Pending |
| 7 | `[-3,0,6]` | GS-033 / GS-041 pilot subset | Writer Quill | wood_honey | Paper lantern (`paper` body, `wood_dark` caps, `orange` glow window) beside a slim `wood_dark`/`ivory` book | Pending |
| 8 | `[3,0,-6]` | GS-034 / GS-041 pilot subset | Analyst Echo | **teal** (fix round) | Bar-chart relief: five rising `sky`/`led_green` blocks on an `ink` baseline | Pending |
| 9 | `[3,0,-4]` | GS-035 / GS-041 pilot subset | Predictor Paul | blue_light | Branching fork (`blue_light` on `navy`) with a hanging `sky` weather bead | Pending |
| 10 | `[3,0,-2]` | GS-036 / GS-041 pilot subset | Strategy Sam | orange_dark | 2×2 `ivory`/`ink` chequered board on a `wood_dark` frame, one `orange_dark` piece off-centre | Pending |
| 11 | `[3,0,0]` | GS-037 / GS-041 pilot subset | Controller Casey | steel | Rack of resource tokens: two rows of `orange`/`cobalt`/`mint` discs in a `steel` frame | Pending |
| 12 | `[3,0,2]` | GS-038 / GS-041 pilot subset | Optimizer Ollie | coral | Two connected loops (`coral` outer, `wood_honey` inner) with a `sky` travelling bead | Pending |
| 13 | `[3,0,4]` | GS-039 / GS-041 pilot subset | Threat Hunter Theo | **led_green** (fix round) | Puzzle-lock plate: `ink` disc on a `steel` back plate, three `led_green` tumbler pips, `steel` keyhole | Pending |
| 14 | `[3,0,6]` | GS-040 / GS-041 pilot subset | Cleaner Cody | leaf_light | Three mismatched mended blocks (`wood_dark`/`sand`/`cream`) with `leaf_light` seams and `steel` rivets | Pending |

Every chest motif is 6–12 boxes weighted to `Spine`, inside the envelope (x
±0.20, z 0.88–1.24, y no further than −0.26); every head crest is 1–3 boxes
weighted to `Head`. Materials are existing `geometry.py` palette entries only
— no new colours were added. Three motifs were reworked mid-task after they
did not read on first render (Chotu's shelf, which fused into a single
same-hue slab; Ollie's marble run, which read as a picture frame; Sam's
chess grid, which read as a vertical stripe aligned with the shared neck
trim) — see `.stage2/task-3-report.md`, `.stage2/task-5-report.md` for the
before/after geometry and the renders that found each problem.

## The two accent departures from the approved cast table

The plan's cast table gives Echo `sky` and Theo `ink`. Both were changed
during Task 5's post-review fix round; neither is a silent substitution —
both are recorded here plainly.

- **Echo: `sky` → `teal`.** `sky` pixel-sampled to within a few RGB points
  of the white shell it's mounted on (a reviewer found it on a zoomed crop
  across all fourteen residents); it disappeared as an accent regardless of
  neighbours. `teal` samples as a clearly visible cyan-green
  (~RGB 75–81,143–149,139–145), strongly separated from both the white shell
  and Paul's neighbouring `blue_light`. Echo's chest motif (the `sky`/
  `led_green` bar chart) was **not** touched — `sky` still appears there, on
  the motif, just not as the shared head/thigh accent colour.
- **Theo: `ink` → `led_green`.** `ink` pixel-sampled to near-black
  (~RGB 25,33,33), visually indistinguishable from the ambient-occlusion
  shadow every resident carries in the same head-module recess — it read as
  absence, not as an accent. `led_green` (emissive, the only unused palette
  colour with strong presence against white) samples ~RGB 158–161,208–211,
  171–174 — bright and clearly present. **Provisional, awaiting the user's
  decision:** `led_green` also matches the shared chevron-eye
  material, so Theo's accent now reads the same colour as his eyes. This was
  the only available fix that made the accent visible at all without adding
  a new palette colour or restructuring the shared accent geometry (both out
  of scope for this task); it is flagged here awaiting the user's explicit
  call rather than treated as settled.

Both changes are data-only (`RESIDENTS['analyst-echo']`/`['threat-hunter-theo']`
`head_accent`/`thigh_accent`); neither resident's chest motif or crest
function changed. The eleven other residents' GLBs are byte-identical
before and after both fixes (verified in `.stage2/task-5-report.md`).

## Shared rig and clip parity

`test_exports.py::test_every_resident_shares_the_rig_and_clip_set` computes,
for every profile in `RESIDENTS`, the **ordered bone-name list** read from
the skin's own joint indices (not a bare bone count) and the sorted clip-name
set, and compares both against a reference resident. This assertion itself
was strengthened mid-stage: the original version only checked
`len(joints)`, which could not have caught a renamed or reordered bone
(proven by temporarily renaming a bone and confirming the old assertion
would have passed while the new one fails — see `.stage2/task-4-report.md`).

All fourteen residents bind the same ordered 16-bone list —
`Root, Hips, Spine, Head, UpperArm.L, Forearm.L, Hand.L, UpperArm.R,
Forearm.R, Hand.R, Thigh.L, Shin.L, Foot.L, Thigh.R, Shin.R, Foot.R` — and
carry the same seven clips: `attend, idle, seated_idle, sit_down, stand_up,
typing, walk`. Confirmed in this record's own gate run
(`test_exports.py`, 9/9 pass) and independently by the Godot `import_test.gd`
suite, which reads `kai`/`lyra`'s bind and clip contract directly from the
imported GLBs at runtime.

## Contact check

```
CONTACT_CHECK {"failures": [], "failure_count": 0, "samples": 6146}
```

0 failures across all fourteen residents, all seven clips each, run from
`source/work-bay.blend` (the same one-bay pilot review composition used
throughout stage 2 — see *Non-reproducible `.blend` build* in r003 for why
this file's own hash cannot be reproduced by rebuilding). The checker's
`method` string now reads "...every resident in RESIDENTS checked in turn,
each at the same inspection bay" — accurate at any cast size, a prose-only
fix from Task 3, no logic change. Sample count grew from 878 (Kai/Lyra only,
r003 baseline) to 2634 (six residents, Task 3) to 4390 (ten, Task 4) to 6146
(fourteen, Task 5), tracking the cast size throughout.

## Khronos validation — all 18 robot/furniture GLBs and 16 workshop modules

```
$ npm run --prefix tools validate
analyst-echo.glb: 0 errors, 0 warnings
chair.glb: 0 errors, 0 warnings
cleaner-cody.glb: 0 errors, 0 warnings
controller-casey.glb: 0 errors, 0 warnings
desk.glb: 0 errors, 0 warnings
environment.glb: 0 errors, 0 warnings
kai.glb: 0 errors, 0 warnings
lyra.glb: 0 errors, 0 warnings
onboarding-olivia.glb: 0 errors, 0 warnings
optimizer-ollie.glb: 0 errors, 0 warnings
predictor-paul.glb: 0 errors, 0 warnings
project-manager-pete.glb: 0 errors, 0 warnings
research-ray.glb: 0 errors, 0 warnings
strategy-sam.glb: 0 errors, 0 warnings
super-chotu.glb: 0 errors, 0 warnings
terminal.glb: 0 errors, 0 warnings
threat-hunter-theo.glb: 0 errors, 0 warnings
writer-quill.glb: 0 errors, 0 warnings

$ node scripts/validate_shared_exports.cjs
awning.glb, bench.glb, door.glb, floor.glb, lawn.glb, path.glb, path_corner.glb,
path_t.glb, planter.glb, railing.glb, roof.glb, shelf.glb, sign.glb, tree.glb,
wall.glb, window.glb: all 0 errors, 0 warnings
```

**All 34 GLBs (18 + 16), 0 errors / 0 warnings**, pinned gltf-validator
2.0.0-dev.3.10. `scripts/validate_exports.cjs` (`npm run --prefix tools
validate`) hardcoded a six-name list through Task 2; Task 3's fix round
(commit `2a8fdc0`) made it read the `godot/assets` directory instead, the
same table-driven contract Task 2 established for `build_assets.py` and
`check_contacts.py`. Every new resident's GLB has now gone through Khronos
validation at least once (first pass at authoring, re-validated at each
subsequent gate run); none has ever turned up an error or a warning.

## Byte sizes

| Asset | Bytes |
| --- | ---: |
| chair.glb | 10,348 |
| desk.glb | 22,868 |
| environment.glb | 229,444 |
| terminal.glb | 37,040 |
| kai.glb | 158,412 |
| lyra.glb | 159,484 |
| onboarding-olivia.glb | 158,896 |
| super-chotu.glb | 154,928 |
| project-manager-pete.glb | 152,100 |
| research-ray.glb | 153,608 |
| writer-quill.glb | 154,384 |
| analyst-echo.glb | 150,832 |
| predictor-paul.glb | 155,756 |
| strategy-sam.glb | 151,396 |
| controller-casey.glb | 156,616 |
| optimizer-ollie.glb | 156,336 |
| threat-hunter-theo.glb | 150,532 |
| cleaner-cody.glb | 156,072 |
| **Total (all 18)** | **2,469,052** |

Workshop modules (unchanged from r003, no geometry touched this milestone):
16 modules, **288,248 bytes total** — see r003's report for the per-module
breakdown; `roof.glb` remains the only module whose geometry ever changed
(in r003, for the wider sawtooth bays).

`layout.json`: **14 stations**, **114** modular instances (down from 150 at
r003 — the twelve reserved-bay desk/terminal/chair instances are gone, since
every bay now furnishes itself via `workshop_station.gd`), **418** static
collision boxes (down from 442, same reason). No `desk.glb`/`terminal.glb`/
`chair.glb` instances remain in `layout.json['instances']` — confirmed by
direct inspection, matching `test_shared_assets.py::test_every_bay_holds_a_resident`'s
assertion.

`asset-manifest.json`'s `source_sha256` (for `source/work-bay.blend`) and
`shared-workshop-manifest.json`'s `source_sha256` (for
`source/shared-workshop.blend`) both changed across stage 2's commits, as
expected — **`.blend` files are not byte-reproducible** (see r003's
*Non-reproducible `.blend` build* section, carried forward unchanged as a
known, pre-existing limitation). Every `.glb` and every `layout.json` stayed
byte-identical wherever its own recipe did not change; each task report in
`.stage2/` records the specific `sha256sum -c` baseline checks run before
committing.

## Bay-pitch at fourteen movers

```
{"failures":0,"test":"bay_pitch"}
```

`bay_pitch_test.gd` departs **every one of the fourteen residents in turn**
as mover, with the other thirteen seated, and asserts every mover reaches
`away` with nothing left waiting — the permanent regression promoted from
r003's spike probe, now exercised at its full designed scale for the first
time (r003 shipped it with only Kai and Lyra to run against). Wall time in
this record's own run: **~10.6 seconds**, 0 failures — comfortably fast, so
the shipped 900-step count was not shortened and the test itself was not
modified. At the shipped 2.0 m Z pitch, no resident's lane conflicts with a
seated neighbour on either ordered pair, for all fourteen.

## Runtime changes (the three surfaces r003 named as stage 2's job)

All three in `godot/shared_workshop.gd`, per `.stage2/task-6-report.md`:

- **Controls panel.** Was a fixed 188 px `ScrollContainer` that already
  clipped at two residents. `layout_ui()` now sizes it to
  `clampf(size.y*0.45, 188, 320)` — taller, capped well short of the full
  viewport so the hall stays visible above it. Each resident row is now
  compact (26 px vs. the previous 34 px buttons) and carries a per-resident
  phase label next to the name.
- **"Both leave [L]" / "Both return [B]"** relabelled **"All leave [L]" /
  "All return [B]"**; the bound `request_leave.bind("all")` /
  `request_return.bind("all")` actions and the `L`/`B` shortcuts are
  unchanged.
- **`describe()` and the status line** now lead with a short phase tally
  (e.g. "1 seated, 13 pulling chair; 2 waiting for the visitor") instead of
  one full sentence per resident; `describe()` still prints one line per
  resident for detail, and per-resident state moved into the new per-row
  phase labels in the controls panel. Every resident's state stays
  reachable.

`godot/tests/shared_workshop_test.gd` was updated for 14 stations and a
latent bug this task's own brief predicted was fixed in the same commit: a
positional index into the flat OptionButton list (`[1]` for "Lyra's
selector") would have silently pointed at Super Chotu's selector once a
third resident existed; replaced with a direct `scene.selectors["lyra"]`
lookup.

## Capture harness change: `--seated`

`godot/shared_workshop.gd`'s `capture()` always called `request_leave("all")`
before snapping a still. `request_journey()` sets each station's
`movement.phase` to `"pulling chair"` immediately and calls
`refresh_status()`, which reads `movement.phase` directly into the 2D
controls panel (the phase tally line and each per-resident row) — so that
panel text flips to "pulling chair" at once. It does **not** call each
station's own `refresh()`, which is what updates the 3D world-space
`Label3D` name tags and drives pose advancement; that only happens inside
`advance_demo()`'s per-1/60s-step loop, and a zero-length `advance_demo(0)`
call runs that loop zero times. So every prior capture (including
[`hall-fourteen-r004.png`](hall-fourteen-r004.png), captured for Task 6) is
internally inconsistent: the 3D robots and their name tags are stale and
still show **"seated"** (unchanged since no time ever advanced), while the
2D panel — the tally line and every per-resident row — reads
**"pulling chair"**, the phase set instantly by `request_leave("all")` and
never reconciled with the unrefreshed 3D state. Neither half is a
representative "room at rest" capture; the panel text does not reflect what
the panel's own robots are shown doing. This milestone adds a `--seated`
flag that skips the `request_leave("all")` call entirely; every other
caller (`capture-walkthrough`, and `capture()` without `--seated`) is
unchanged. Verified: all seven Godot suites still pass
(`fixture, import, scene, movement, journey, shared_workshop, bay_pitch`,
each `"failures":0`) after the change, committed on its own
(`5941ebc`, before any resident or capture work in this record).

**[`hall-fourteen-r004.png`](hall-fourteen-r004.png) is kept — do not delete
committed evidence — but is captioned here accurately: the robots and their
3D name tags visibly show "seated"; only the 2D panel text (tally line and
every per-resident row) reads "14 pulling chair", because the capture
harness never refreshed each station's 3D label before `request_leave("all")`
took the still. It is not a representative state of the populated hall.**
The three captures below, taken with
`--seated`, are the room at rest and are what this record's overview/exterior/
close-range claims are based on.

## Captures

Godot 4.6.3, `gl_compatibility`, Mesa Intel Iris Xe Graphics, 1060 × 660
viewport. Every capture below was opened and visually confirmed against the
claim made for it, not just checked for `"error":0`.

- [`full-cast-overview-r004.png`](full-cast-overview-r004.png)
  (`full-cast-overview-r004.json`, `"error":0`, `"missing_assets":[]`) —
  `--camera=overview --seated`. Shows all fourteen residents seated at their
  labelled bays, each name tag reading "· working / seated" (not "pulling
  chair"), in the roster-order layout: west zone north-to-south reads
  Onboarding Olivia, Super Chotu, Project Manager Pete, Kai, Lyra, Research
  Ray, Writer Quill; east zone reads Analyst Echo, Predictor Paul, Strategy
  Sam, Controller Casey, Optimizer Ollie, Threat Hunter Theo, Cleaner Cody.
- [`full-cast-exterior-r004.png`](full-cast-exterior-r004.png)
  (`full-cast-exterior-r004.json`, `"error":0`, `"missing_assets":[]`) —
  `--camera=exterior --seated`. Shows the full hall exterior, the three-bay
  sawtooth roof at its r003 width, and the translated courtyard (doorway,
  railed perimeter, tree island) — unchanged from r003 since no geometry was
  touched this milestone. No residents are visible in this camera mode by
  design (roof and front wall are opaque).
- [`full-cast-first-person-r004.png`](full-cast-first-person-r004.png)
  (`full-cast-first-person-r004.json`, `"error":0`, `"missing_assets":[]`) —
  `--camera=first_person --motion-time=15 --visitor-position=-1.55,0,1.45
  --visitor-yaw=0` (residents **standing**, not `--seated`: this frame needs
  them mid-departure, in the open aisle, away from their desks). **Kai's
  chest motif is fully visible and legible, dead centre: the cream apron
  backing, the wood_honey shoulder strap with its orange buckle, the sand
  pocket, the orange pencil with its steel tip, and the steel/metal badge —
  every element named in `_chest_motif_kai` is identifiable in the frame.**
  Kai's own status label reads "Kai · working" and the on-screen phase text
  reads **"Waiting for visitor"**: the visitor's own position, close enough
  for this framing, blocks Kai's final approach to his standing spot, so he
  is paused mid-journey rather than freely idling. Lyra is also "Waiting for
  visitor" in this same frame — her billboard label, at the left edge and
  very close to the camera, renders oversized as the huge "…VISITOR" text
  overlapping the top of the frame; it is the same obstruction state as
  Kai's, not a separate artifact. That is a real, designed
  runtime state (`shared_workshop.gd`'s visitor-obstruction handling), not a
  glitch, and is stated here so the capture is not mistaken for a calm
  "away" resting pose. See *Seated appearance is not visible in the hall*
  below for what this replaces and why a seated capture could not be made to
  show a chest motif.

Fixing this capture took real work, documented in full below: an earlier,
committed version of this file (identified as wrong by review) showed the
**back of Kai's head and the back of Lyra's head**, misread as their chest
motifs. That capture used `--seated` at a position level with — in one case,
slightly behind — the seat itself, on the character's back side, not its
front. This replacement first required correcting that directional error
(confirmed against `scripts/character.py`'s own coordinates: the chest
motif and the head's display/eyes are both built at the most-negative-Y
"front" of the mesh, which the Blender→glTF axis conversion places at
positive Z in Godot; the character's default, unrotated orientation faces
+Z, confirmed independently by the walk-cycle geometry in
`movement_controller.gd`), then finding that **no seated position or angle
tried actually shows the chest**, and only succeeding once residents were
standing.

## Seated appearance is not visible in the hall — this is the important finding

**While seated — which is every resident's resting and default state — no
camera position or angle found shows a resident's chest motif.** This is a
more significant finding than "the overview is too far away": the desk and
terminal that sit directly in front of a seated resident's own chest (the
terminal casing is 0.548 m wide; the chest-motif envelope is at most 0.40 m
wide, so the terminal is wider than the motif it would need to reveal) block
the view from every angle tried, not just the overview's.

**What was tried, seated, and what each actually showed** (full detail,
every position/yaw pair, in `.stage2/task-7-report.md`'s fix-round section):

- Positions level with or behind the seat (the error in the first, wrong
  capture): show the back of the head and the head's side accent module —
  never the chest, because they are on the character's back side.
- Positions directly in front, close to the desk, at standing eye height
  (1.52 m): show the desktop itself filling most of the frame — the desk's
  own near edge sits close enough to the seated character's chest that a
  standing-height eye looks down into the desk surface, not over it.
- Positions in front, elevated and offset to the side, aimed to look past
  the monitor: show the character's face and the top of the terminal
  monitor's back (blank, undecorated — confirming it is the monitor's back,
  not its screen), with the chest still hidden below the monitor's lower
  edge or behind its casing.
- A final close, offset, elevated attempt from beside the desk: still showed
  the head's side accent module, not the chest.

No seated attempt showed genuine chest-motif geometry, verified against the
actual box lists in `scripts/character.py` — every "motif" identified in
earlier (wrong) attempts turned out, on correction, to be head geometry.

**Consequence for the hall-distance legibility question below:** this is not
a distance problem that a closer overview camera would fix. A resident's
chest motif — the cast's primary differentiator per the plan — is
essentially unobservable by anyone in the hall while that resident is
seated, which is most residents, most of the time, in this scene's normal
resting state. The motif only becomes visible once a resident stands and
walks, and even then, standing close enough to see it clearly places the
visitor inside a neighbouring resident's approach lane, triggering
"waiting" (as it did in the capture above). **This is a materially larger
design question than hall-distance legibility, and the user needs it
accurately to decide whether the chest motif is a viable differentiator for
this scene at all**, or whether identification needs to rely on the head
accent, the name tags, or a redesign of where a motif lives on the body.

For a view of all fourteen motifs at once, unaffected by seating or
in-scene occlusion, see the offline render below — it is not evidence that
the hall itself shows them; it isolates the geometry to show what each motif
looks like on its own.

- [`full-cast-lineup-r004.png`](full-cast-lineup-r004.png) — **an offline
  Blender render, not a runtime Godot capture.** Fourteen isolated GLBs,
  each imported into a fresh scene with the same lighting recipe used for
  the per-resident review renders in Tasks 3–5, arranged left to right in
  `RESIDENTS` table order (not roster/bay order): Kai, Lyra, Olivia, Chotu,
  Pete, Ray, Quill, Echo, Paul, Sam, Casey, Ollie, Theo, Cody — with no
  desk, terminal, chair, name tag or hall geometry. Every motif is legible
  at this scale and reads as its described object (Kai's apron, Lyra's
  colour panels, Olivia's crossing paths, Chotu's shelf, Pete's card grid,
  Ray's drawers, Quill's lantern and book, Echo's bar chart, Paul's fork,
  Sam's board and piece, Casey's token rack, Ollie's loops, Theo's dark
  disc, Cody's mended blocks). This is legitimate evidence that **the motif
  designs themselves read at close range**; it is not evidence that a
  visitor in the actual hall scene can ever see them this clearly, which
  the finding above establishes they generally cannot while a resident is
  seated.

## Hall-distance legibility — open design question, unresolved

**From the hall overview, residents cannot reliably be told apart by
appearance**, for two compounding reasons, one of them the seated-occlusion
finding above and now confirmed to be the dominant one:

1. Every resident sits facing their own desk/terminal, and — per the finding
   above — the terminal occludes the chest motif from every angle tried, not
   only the overview's. This is not primarily a distance effect.
2. At the overview's native rendered scale, the head-accent module is only a
   few pixels wide; colour differences that are clear in isolated review
   renders blur into a similar light/dark pattern at hall distance, and nor
   are hue-adjacent pairs (Echo/Paul before the teal fix, Ray/Cody, Theo's
   former near-black ink) reliably separable at this scale.

**In the overview capture, the `Label3D` name tags are doing essentially all
of the identification work, not the robots' appearance.** Unlike the record
this replaces, this is **not** offset by "but they read fine up close" — up
close, seated, they still do not read; only standing, close enough to
trigger visitor-obstruction waiting, does a motif become visible. Whether
that is acceptable for this "SAMPLE DATA" interior scene, or requires a
redesigned motif placement (visible while seated), a different
identification mechanism, or is simply accepted as-is, is an **open call for
the user**, informed by the stronger finding above rather than a distance
problem alone.

## Known limitations carried forward (not introduced by this milestone)

- **Label3D name tags overlap at fourteen** (`workshop_station.gd`). Visible
  in every capture above — tags for adjacent bays (2.0 m pitch) crowd and
  partially overlap at the overview camera's distance and angle. Not fixed
  this milestone; flagged as a UI polish item for whoever next touches the
  label layer.
- **The controls panel covers roughly half the viewport at 660 px** of
  height even after Task 6's resize (`clampf(size.y*0.45, 188, 320)` — at
  660 px viewport height that is up to 297 px, ~45%). It no longer clips at
  two residents, but it is not a small overlay either; a viewer must scroll
  within it to reach every one of the fourteen resident rows.
- **Ollie's motif is the weakest read of the fourteen.** Even after the fix
  round (removing the solid fill, adding a second nested loop), the looping
  marble-run track reads less immediately as "a track" than most of the
  other thirteen's motifs, which read unambiguously on first render. Not
  reworked a second time; flagged as the weakest of the batch, not a
  failure.
- **Ollie's marble sits exactly at the depth envelope limit.** The travelling
  `sky` bead was enlarged and pulled forward during the fix round to make it
  legible; its near face sits at the −0.26 m depth bound with no margin.
  Any future adjustment to Ollie's motif should re-check this against
  `check_contacts.py` rather than assume the existing geometry has headroom.
- **`.blend` files are not byte-reproducible** — both `source/work-bay.blend`
  and `source/shared-workshop.blend`. Carried from r003; not investigated or
  fixed here. Every `.glb` and `layout.json` remain byte-identical wherever
  their own recipe did not change; only the `.blend` save hash varies
  build-to-build for unmodified inputs.

## Checks

Run from `prototypes/voxel-work-bay`. Full, untruncated output:
[full-cast-tests.txt](full-cast-tests.txt).

```sh
python3 scripts/test_shared_assets.py
python3 scripts/test_exports.py
npm run --prefix tools validate
node scripts/validate_shared_exports.cjs
blender --background --factory-startup source/work-bay.blend --python-exit-code 1 \
  --python scripts/check_contacts.py
godot --headless --editor --path godot --import --quit
for t in fixture import scene movement journey shared_workshop bay_pitch; do
  godot --headless --path godot --script res://tests/${t}_test.gd
done
```

- `test_shared_assets.py`: **13 tests, OK** — includes
  `test_every_bay_holds_a_resident` (14 stations, zones at `x=±3`, seven `z`
  anchors each, no reserved furniture) and
  `test_stations_are_seated_in_roster_order` (roster order matches
  `character.RESIDENTS`, Kai/Lyra origins unchanged), replacing r003's
  reserved-bay assertions.
- `test_exports.py`: **9 tests, OK** — the original six export-contract
  tests plus `ResidentTable`'s three: every resident in the table is
  exported, the pipeline does not hardcode `'kai'`/`'lyra'`/`KaiRig`/
  `LyraRig` in `build_assets.py`/`check_contacts.py`, and every resident
  shares the ordered 16-bone list and seven-clip set.
- Khronos validation: **34/34 GLBs, 0 errors / 0 warnings** (18 robot/
  furniture, 16 workshop modules).
- `check_contacts.py`: **0 failures, 6146 samples**, all fourteen residents.
- Godot import: clean, no missing or failed-import assets.
- All seven Godot suites pass with `"failures":0`: `fixture`, `import`,
  `scene` (`"missing_assets":[]`), `movement`, `journey`, `shared_workshop`,
  `bay_pitch` (fourteen movers, ~10.6 s).

## Link check

Every relative link in the documents changed for this record (this file,
`README.md`, `SHARED_WORKSHOP.md`, `ASSET_WORKFLOW.md`,
`docs/gameplay/asset-catalogue/FIRST_GUILD_SCENE.md`, and the spec's
*Carried out of stage 2* addendum) was checked with the stage-1 plan's link
script. **Result: 0 broken links.**

## Review still needed

Nothing here is accepted. **Only Kai's and Lyra's appearances carry user
approval; the twelve new appearances do not**, regardless of how clean their
gate results are. The environment palette, the hall itself, and GS-031's own
acceptance record (see the spec's *Carried out of stage 2* addendum) remain
open. **Seated chest-motif visibility is a real, unresolved design
question** — no camera position in the hall shows a seated resident's chest
motif, which is every resident's normal resting state — and it is a more
consequential open question than hall-distance legibility, which it
subsumes. Neither is resolved by this milestone; both are recorded here for
the user's decision. A02, A05 and A06 remain open, as does the environment
half of A01.
