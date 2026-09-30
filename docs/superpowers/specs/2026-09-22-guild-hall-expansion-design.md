# Guild hall expansion — fourteen residents

Approved direction: expand the ground so the remaining Guild agents have
somewhere to live and work. The user chose the full scope — work zones, home
frontages and a scaled path network — then chose hall option B from a greybox
comparison, then directed that all fourteen appearances be authored rather than
placeholdered, on the grounds that appearance can be revised later.

The user approved **Artistic Lyra's appearance** on 2026-09-22. With Coder Kai
already approved, two instances of the shared design grammar are now reviewed,
which satisfies A01's precondition for scaling the cast. The user's approval was
of Lyra specifically; the environment palette review remains open.

This spec covers the workshop hall and the fourteen residents. The F08
residential site, the shared-life courtyard props and the path network between
them are deliberately deferred to their own specs; see *Deferred* below.

## Measured constraints

These came from a throwaway spike, since A05 requires measuring a representative
scene before fixing budgets. All figures are one machine — Intel Iris Xe,
`gl_compatibility`, 1060 × 660 viewport — and establish no target-device budget.

**Fourteen agents cost no measurable frame time.**

| Agents | Draw calls | Primitives | Memory | p50 | p95 |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 2 | 325 | 11,562 | 36.4 MB | 2.77 ms | 3.17 ms |
| 6 | 473 | 19,114 | 37.8 MB | 2.77 ms | 3.12 ms |
| 14 | 769 | 34,302 | 40.7 MB | 2.77 ms | 3.30 ms |

Draw calls rose 2.4×, primitives 3×, and p50 moved 0.006 ms. Sample counts
(4297 / 4313 / 4304) and third-decimal p50 variation confirm this is a real
measurement and not a frame cap. Memory costs roughly 0.36 MB per resident.
**Consequence: the character specification needs no LOD tier on this evidence.**

**Bay pitch depends on which axis the bays run, because the walk lane travels
+1.45 m in X.** `blocked()` rejects any movement bringing a resident within
1.14 m of another resident's body, including seated ones.

| Bay axis | Pitch tested | Result |
| --- | --- | --- |
| Z (lane runs away from neighbours) | 1.8, 2.0, 2.2, 2.5 m | all clear |
| Z | 1.5 m | departing residents block on seated neighbours |
| Z | 1.0 m | total deadlock, all fourteen waiting |
| X (lane runs toward neighbours) | 2.0, 2.4 m | six of eight movers permanently stuck |
| X | 2.6, 2.8, 3.0, 3.5 m | all clear |

The binding case is a mover passing a *stationary* neighbour. When every
resident departs in lockstep their relative distances are preserved and nothing
blocks at any pitch, so a naive test passes and hides the constraint. Mid-journey
reversal is rejected by `request_journey`, which removes the other convergence
case.

**Consequence: bays run along Z at 2.0 m pitch.** An X-spaced arrangement would
need ≥ 2.6 m and a hall roughly 18 m wide to hold seven bays.

## Hall

Twelve by sixteen metres, `x −6…6`, `z −8…8`, on the existing 2 m grid.

- Floor: 48 tiles, `x ∈ {−5,−3,−1,1,3,5}`, `z ∈ {−7,−5,−3,−1,1,3,5,7}`.
- Walls: `x = ±6` each z; `z = ±8` each x. Doorway on the east wall at `(6,0,1)`.
- Roof: **bay width widens from 10/3 m to 4.0 m**, three bays at `x ∈ {−4,0,4}`,
  two 8 m modules deep each at `z ∈ {−4,4}` — six instances. The three sawtooth
  bays the concept art pins are preserved in count; only their width changes.

`roof.glb` is the one already-merged asset this alters. Its recipe already
parameterises on bay width, so the change is small, but its manifest entry and
change history must be restaked rather than silently overwritten.

The whole grid shifts by 1 m: hall tile centres become odd rather than even.

## Zones and bays

Two zones side by side, each 6 × 16 m, against the 12 × 8 m draft in GS-015. The
draft anticipates this — "resize after fitting both zones to the style's W1 hall".

- West zone origin `x = −3`; East zone origin `x = +3`.
- Seven bays per zone along Z at 2.0 m pitch: `z ∈ {−6,−4,−2,0,2,4,6}`.
- Station origins are therefore `(±3, 0, z)` for those seven z values.
- Bay assignment is recorded in `layout.json` and follows roster order: GR01–GR07
  in the West zone north to south, GR08–GR14 in the East zone. Assignment is a
  presentation choice, not an identity claim, and does not encode the thirteen
  facility assignments discussed under *Acceptance boundary*.

**All fourteen stations keep the same orientation.** `workshop_station.gd`
applies no per-station rotation, and identical lane shape is exactly what makes
lockstep movement collision-free. Mirroring the two zones to face each other
would require per-station lane transforms and would invalidate the measurements
above. It is deferred, not forgotten.

## Courtyard

The hall's east wall moves from `x = 5` to `x = 6`, so the merged courtyard
would otherwise sit inside the building. It translates **+1 m in X**; nothing is
re-authored, every module is reused, and the grid stays aligned.

| Element | From | To |
| --- | --- | --- |
| Doorway | (5, 0, 1) | (6, 0, 1) |
| Loop tiles | x ∈ {6, 8, 10} | x ∈ {7, 9, 11} |
| Tree island | (8.2, 0, 1) | (9.2, 0, 1) |
| Awning | (5, 0, 1) | (6, 0, 1) |
| East railing | x = 11 | x = 12 |
| Sign | (5.5, 0, 2.9) | (6.5, 0, 2.9) |

The courtyard depth stays at 8 m. It is re-staked at a new revision because its
placements change, even though its geometry does not.

## Residents

Fourteen appearances on the existing shared 16-bone rig and seven clips.

`character.py` currently branches on `is_lyra = profile == 'lyra'` — a binary,
not a specification. It is refactored to a resident table carrying accent
colour, secondary colour, identifying motif, GS ID and source profile. This is
the enabling change; twelve new residents are then data entries plus a motif
function each.

Designs derive from the documented roster in `GUILD_RESIDENTS.md`, which gives
every resident a role and a signature object — Olivia's route map, Pete's
planning wall, Ray's map cabinet, Quill's paper lanterns, Echo's kinetic chart,
Theo's puzzle lock, Cody's repaired-object shelves. Residents differentiate on
those motifs, not on fourteen recolours of one silhouette. The tracker is
explicit that City Agent A1 is a design grammar and must not be cloned fourteen
times, and that each appearance still needs its own style-consistent pass.

Every appearance must export the identical 16-bone bind structure and the same
seven animation channels, which the existing export contract tests already check
for Kai and Lyra and which extend to all fourteen.

Twelve appearance designs are twelve judgement calls, not a parameter sweep.
Where a resident's roster card does not determine a silhouette, accent or motif,
that choice is brought back for a decision rather than guessed at. Expect stage 2
to pause for review more than once; a batch of twelve authored in one pass
without review would be the failure mode this spec is trying to avoid.

## Contract changes

These are documented interfaces, so they change deliberately and visibly.

| Where | From | To |
| --- | --- | --- |
| `ASSET_WORKFLOW.md` §2 | hall 10 × 8 m; two named station origins | hall 12 × 16 m; fourteen bay anchors at 2.0 m Z pitch |
| `shared_workshop.gd` | `for key in ["kai","lyra"]` | iterate `stations`; control panel handles a variable count |
| scene text view | enumerates every station inline | summarises fourteen residents readably |
| `test_shared_assets.py` | asserts exactly two stations | asserts fourteen bays, pitch and zone separation |
| door corridor check | x 4.85–5.15 | x 5.85–6.15 |
| `CourtyardKit.DOORWAY` | (5.0, 1.0) | (6.0, 1.0) |
| roof assertions | 3 instances, width 10/3 | 6 instances, width 4.0 |

## Testing

The spike's staggered-departure probe becomes a **permanent regression**: half
the bays depart while the bays between them stay seated, and every mover must
reach `away` with nothing left waiting. This is what found the pitch constraint,
and without it a future pitch change would silently reintroduce the deadlock.

Added alongside: bay count and pitch, zone separation, roof bay count and width,
courtyard connectivity at the shifted doorway. The existing `CourtyardKit`
assertions carry over unchanged apart from the doorway constant. The existing
export contract tests extend from two residents to fourteen.

The full gate stays as `ASSET_WORKFLOW.md` §5 defines it: Khronos validation
rejecting errors and warnings, the Python asset and export suites, headless
Godot import, and all Godot scene suites, plus the contact checker for character
changes.

## Stages

Delivered as two pull requests so the hall is reviewable before fourteen robots
arrive in it.

1. **Hall, zones and courtyard shift.** Roof module widened; fourteen bay
   anchors; courtyard translated; runtime de-hardcoded; contracts and tests
   updated. Kai and Lyra occupy two bays; the other twelve anchors are reserved
   and empty.
2. **Fourteen appearances.** `character.py` refactor, twelve new designs,
   fourteen exports verified for bind-pose and clip parity, contacts and
   validation. Moves GS-027 through GS-040 off Not started.

## Acceptance boundary

Nothing here is accepted by being built. Stage 1 advances GS-008 through GS-015
and the courtyard rows at a new revision; stage 2 advances GS-027 through
GS-040. All remain In progress pending test records and review evidence.

Kai's and Lyra's appearances are user-approved. The twelve new appearances are
not, and authoring them does not accept them. A02, A05 and A06 remain open, as
does the environment half of A01. The performance figures above feed A05; they
do not settle it.

Consolidating fourteen residents into two work zones is a W1 scene-planning
simplification. `GUILD_RESIDENTS.md` assigns the cast across thirteen distinct
facilities, and GS-015 states the consolidation "does not replace long-term
facility assignments". The scene must not be read as the world model.

## Deferred

- **F08 residential site** (GS-016, GS-024): fourteen home frontages at 4 × 4 m
  on a new adjoining site. Depends on A03 for identity and address mapping.
- **Shared-life courtyard props**: the tea table, mural wall, seed library and
  evening game table named in `GUILD_RESIDENTS.md` have no GS IDs. Adding them
  is a scope change requiring new IDs and a revised baseline count.
- **Zone mirroring**: per-station lane transforms so the two zones can face each
  other across an aisle.
- **Ambience** (GS-059): needs an audio pipeline and licensing that do not exist,
  and A06 is unresolved.

## Carried out of stage 1

Stage 1 shipped with these known and deliberately deferred. Stage 2 owns them.

- **The fourteen-resident UI is one job, not three.** The controls panel is a
  188 px `ScrollContainer` that already clips at two residents; the
  "Both leave / Both return" buttons are two-resident labels bound to an "all"
  action; and the scene text still prints one line per station. At fourteen each
  of these degrades, and they are all in the same UI block.
- **The bay-pitch guard must stay honest as bays fill.** It now loops every
  resident as mover, so it scales automatically — but it only compares each
  mover against residents that exist. Occupying the remaining twelve bays is
  what makes its coverage real; do not weaken the loop.
- **No static collision box is ever swept.** `blocked()` sweeps only the visitor
  and other stations' `actor_body`, so neither the reserved bays' proxies nor
  Kai's and Lyra's own desk and chair can obstruct a walk. Lanes are authored to
  avoid static geometry. Extending the sweep to the reserved proxies alone would
  not be the whole job.
- **`source/shared-workshop.blend` is not byte-reproducible.** Rebuilds of an
  unmodified tree differ in hash and length, while `layout.json` and every `.glb`
  are byte-identical. It has no tracker issue ID, unlike GS-014-01; giving it one
  would stop each contributor rediscovering it.
- **Minor, safe to leave:** the exporter re-imports and re-hashes a reused GLB
  once per instance rather than caching per asset name (build-time only,
  idempotent); `layout()`'s `bounds.max[0]` was not translated with the courtyard
  (nothing reads `bounds`, and fixing it forces a non-reproducible rebuild); and
  GS-015's draft "12 × 8 m per zone" reads as a swapped pair against the
  delivered 6 × 16 m, which tracker convention leaves in place.

## Carried out of stage 2

Stage 2 authored the twelve remaining appearances, seated all fourteen
residents in the bays stage 1 reserved, and scaled the runtime to them. It
shipped with these known and deliberately deferred. Whoever next touches this
scene owns them.

- **Name-tag crowding at fourteen.** `workshop_station.gd`'s `Label3D` tags,
  one per resident, sit above bays at 2.0 m Z pitch. At the overview camera's
  distance and angle, adjacent tags visibly overlap — visible in
  `evidence/full-cast-overview-r004.png`. Not fixed this stage; a layout or
  sizing change to the label layer is the likely next step.
- **The controls panel still covers a meaningful share of the viewport.**
  Stage 2 resized it from a fixed 188 px to `clampf(size.y*0.45, 188, 320)` —
  it no longer clips at two residents, but at a 660 px viewport that is up to
  ~45% of the vertical space, and a viewer must scroll within it to reach all
  fourteen resident rows. This is a real improvement over the two-resident
  original, not a finished treatment.
- **A seated resident's chest motif is not visible in the hall at all, from
  any camera position found — this is a larger problem than hall-distance
  legibility, which it subsumes.** Every resident's own terminal (0.548 m
  wide) is wider than the chest-motif envelope (0.40 m max width) and sits
  directly between a seated resident and any viewer, seated being every
  resident's normal resting state; no camera position tried — close, far,
  elevated, offset — gets past it. Head/thigh accent colours separately blur
  to a few pixels at hall-viewing scale. The `Label3D` name tags do the
  identification work at any distance while residents are seated. The motif
  becomes visible only once a resident stands and walks; standing close
  enough to see it clearly places the visitor inside a neighbouring
  resident's approach lane, which the runtime resolves as "waiting for
  visitor" rather than a calm pose. An offline, isolated Blender render
  (`evidence/full-cast-lineup-r004.png`) confirms every motif reads on its
  own — the problem is not the motif designs, it is that the scene has no
  angle that reveals them while seated. Whether this needs a different
  motif placement (visible while seated), a different identification
  mechanism entirely, a redesigned overview camera, or is accepted as-is for
  this sample-data interior scene is an **open question for the user**, not
  resolved here. See `prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md`.
- **Theo's accent colour is provisional, awaiting the user's decision.**
  The plan's cast table gives Theo `ink`, which rendered
  near-black and indistinguishable from the shared head-module's own
  ambient-occlusion shadow — it read as absence, not as an accent. It was
  changed to `led_green` (the only unused palette colour with strong presence
  against white) so the accent is visible at all — see
  `prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md`. `led_green`
  also matches the shared chevron-eye material, so Theo's accent now reads
  the same colour as his eyes. This was the best fix available without
  adding a new
  palette colour or restructuring the shared accent geometry — both out of
  this stage's scope — but it was not itself reviewed or approved; the user's
  explicit call is still needed. Echo's `sky` → `teal` accent change is the
  same category of fix (an invisible accent made visible) but has no
  comparable side effect worth flagging.
- **GS-031's Review row still needs its own acceptance record for Lyra.**
  The spec's *Acceptance boundary* states Lyra's appearance is user-approved
  (2026-09-22), and the tracker's Review column for GS-031 has read Pending
  throughout stage 1 and stage 2 — no row was ever marked Accepted with a
  reviewer, date and reviewed revision, per the tracker's own rules. Stage 2
  did not create or resolve this gap; it is carried forward as-is, distinct
  from the twelve new appearances' Review rows (which correctly read Pending
  because they are, in fact, unreviewed).
