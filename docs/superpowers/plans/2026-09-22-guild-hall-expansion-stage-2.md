# Guild Hall Expansion — Stage 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author the twelve remaining Guild appearances on the shared rig, seat them in the fourteen bays stage 1 built, and make the runtime read correctly at fourteen residents.

**Architecture:** `scripts/character.py` now carries a `RESIDENTS` table; each resident is one entry plus a chest-motif and head-crest function. The build, contact-check and test scripts still name `kai`/`lyra` literally in fourteen places, so Task 2 makes them read the table before any resident is added. Residents are then authored in batches of four, each batch verified for rig and clip parity before the next.

**Tech Stack:** Blender 5.2.2 LTS (`bpy`), glTF 2.0 / GLB, Python 3 stdlib `unittest`, Node.js pinned Khronos `gltf-validator` 2.0.0-dev.3.10, Godot 4.6.3 `gl_compatibility`.

**Spec:** `docs/superpowers/specs/2026-09-22-guild-hall-expansion-design.md`

## Global Constraints

- Branch `feat/guild-hall-expansion`, continuing from stage 1. Everything lands in one pull request.
- Units are metres, glTF/Godot Y-up, +X east, −Z north, floor top at Y = 0.
- Every Blender build runs in a fresh background process: `blender --background --factory-startup --python-exit-code 1 --python <script>`.
- `scripts/build_assets.py` builds robots and furniture. `scripts/build_shared_workshop.py` builds the environment. **Run only the one whose inputs changed.**
- **`source/*.blend` files are not byte-reproducible** — hash and length change on every save from identical inputs, while `layout.json` and every `.glb` are byte-identical. Expected churn; never hand-edit a hash to make something match.
- Do not regenerate `evidence/*-validation.json` or `evidence/shared-validation/*.json` for timestamp-only changes. Run `git checkout --` on them before committing.
- **Every resident shares one 16-bone bind structure and exactly seven clips**: `idle`, `walk`, `seated_idle`, `typing`, `attend`, `sit_down`, `stand_up`. Any appearance that exports a different bone count, bone names, or clip set is a failure, not a variant.
- Agents are **robots**: white shell, dark screen face, green chevron eyes and smile, segmented limbs. Residents differ by accent colour and one identifying chest motif. Do not give a resident hair, ears, a nose, skin, or a humanoid face. The excluded humanoid experiment must not be used as reference.
- **Nothing here is accepted by being built.** Tracker Build moves to *In progress*; Test stays *Not run*; Review stays *Pending*. The user approved Kai's and Lyra's appearances on 2026-09-22 and nothing else.

## The approved cast

Accent is the head side-module and thigh trim. Motifs derive from each resident's card in `docs/vision/GUILD_RESIDENTS.md`.

| GS | Profile | Name | Accent | Chest motif |
| --- | --- | --- | --- | --- |
| GS-030 | `coder-kai` | Coder Kai | cobalt | apron, straps, pocket, pencil, badge *(built)* |
| GS-031 | `artistic-lyra` | Artistic Lyra | violet | colour panels, shoulder tabs, sketch sheets *(built)* |
| GS-027 | `onboarding-olivia` | Onboarding Olivia | mint | folded route-map panel with path lines |
| GS-028 | `super-chotu` | Super Chotu | orange | shallow display shelf, miniature prototypes |
| GS-029 | `project-manager-pete` | Project Manager Pete | navy | grid of movable planning cards |
| GS-032 | `research-ray` | Research Ray | green | stacked map-cabinet drawers with pull tabs |
| GS-033 | `writer-quill` | Writer Quill | wood_honey | paper lantern and a slim book |
| GS-034 | `analyst-echo` | Analyst Echo | sky | bar-chart relief, rising blocks |
| GS-035 | `predictor-paul` | Predictor Paul | blue_light | branching-paths fork, weather bead |
| GS-036 | `strategy-sam` | Strategy Sam | orange_dark | small chess grid and one piece |
| GS-037 | `controller-casey` | Controller Casey | steel | rack of resource tokens |
| GS-038 | `optimizer-ollie` | Optimizer Ollie | coral | looping marble-run track and bead |
| GS-039 | `threat-hunter-theo` | Threat Hunter Theo | ink | puzzle-lock plate with tumblers |
| GS-040 | `cleaner-cody` | Cleaner Cody | leaf_light | mended blocks with visible seams |

## The chest-motif envelope

Every motif is a small relief on the front of the torso, weighted to the `Spine` bone. Kai's apron and Lyra's colour panels are the two worked examples in `scripts/character.py` — **read both before authoring a third.**

Constraints, derived from the existing two:

- **Bounds:** x within ±0.20, z within 0.88…1.24, y (depth, toward the viewer) no further out than −0.26. The torso shell front face sits at y ≈ −0.145, so a motif block's near face must be beyond that to be visible, and must not reach past −0.26 or it will clip the desk in the seated pose.
- **Clear of joints.** The spine joint at z ≈ 1.235 and the hip joint at z ≈ 0.855 must stay unobstructed, or the rigid weights will tear the motif when the torso turns.
- **Weight every box to `'Spine'`.** A motif box weighted to any other bone will detach in animation.
- **Materials come from the existing palette** in `scripts/geometry.py`. Do not add colours.
- **Six to twelve boxes.** Kai's apron uses nine, Lyra's panels ten. Fewer reads as unfinished at distance; more is invisible detail at the scale the scene is viewed.
- The head crest is a separate, smaller hook: one to three boxes above the head shell at z ≈ 1.72, within x ±0.20. Kai's is a single orange tab; Lyra's is a three-piece violet/coral/teal comb.

**Exact coordinates are the implementer's to choose** within this envelope. They are verified by `check_contacts.py` and by looking at the render — not by matching numbers in this plan.

---

### Task 1: `RESIDENTS` table refactor — **COMPLETE**

Delivered in commit `5b48da9`. `scripts/character.py` carries a `RESIDENTS` dict with per-resident `chest_motif` and `head_crest` hooks called at fixed points in the shared emission sequence; unknown profiles raise `ValueError`. `kai.glb` and `lyra.glb` verified byte-identical across the change.

Its review found that the promise "one entry plus two functions" holds only inside `character.py`. Task 2 closes that.

---

### Task 2: Make the pipeline read the resident table

**Files:**
- Modify: `prototypes/voxel-work-bay/scripts/build_assets.py`
- Modify: `prototypes/voxel-work-bay/scripts/check_contacts.py`
- Modify: `prototypes/voxel-work-bay/scripts/test_exports.py`

**Interfaces:**
- Consumes: `character.RESIDENTS`, the dict keyed by profile slug added in Task 1.
- Produces: no new API. After this task, adding a resident to `RESIDENTS` is picked up by the builder, the contact checker and the export tests without further edits.

- [ ] **Step 1: Record the baseline**

```bash
cd prototypes/voxel-work-bay
sha256sum godot/assets/kai.glb godot/assets/lyra.glb > /tmp/stage2-baseline.txt
grep -n "'kai'\|'lyra'\|\"kai\"\|\"lyra\"\|KaiRig\|LyraRig" scripts/build_assets.py scripts/check_contacts.py scripts/test_exports.py
```

Expected: eleven hits across the three files. Read every one in context before changing anything — some are export names, some are animation flags, some are furniture offsets, and they do not all mean the same thing.

- [ ] **Step 2: Write the failing test**

Add to `scripts/test_exports.py`:

```python
class ResidentTable(unittest.TestCase):
    """Adding a resident must not require editing the pipeline by hand."""
    def test_every_resident_in_the_table_is_exported(self):
        import sys
        sys.path.insert(0,str(ROOT/'scripts'))
        from character import RESIDENTS
        for profile in RESIDENTS:
            self.assertTrue((ROOT/'godot/assets'/(profile+'.glb')).exists(),
                            f'{profile} is in RESIDENTS but was never exported')

    def test_pipeline_does_not_hardcode_the_cast(self):
        import re
        for name in ('build_assets.py','check_contacts.py'):
            text=(ROOT/'scripts'/name).read_text()
            for literal in ("'kai'",'"kai"',"'lyra'",'"lyra"','KaiRig','LyraRig'):
                self.assertNotIn(literal,text,
                                 f'{name} still names {literal} literally; it should read RESIDENTS')
```

- [ ] **Step 3: Run it to verify it fails**

Run: `python3 scripts/test_exports.py`
Expected: FAIL — `test_pipeline_does_not_hardcode_the_cast` reports `build_assets.py still names 'kai' literally`.

- [ ] **Step 4: Drive `build_assets.py` from the table**

Replace the hardcoded pair with iteration over `RESIDENTS`. The five sites are: the two `create_character(...)` calls; `export_animations=(name in ('kai','lyra'))`, which should test membership in `RESIDENTS` instead; the furniture-offset tuple, whose resident entries should be generated per resident; `manifest['source_profiles']` and `manifest['appearance_review']`, both of which should be built from the table's `source_profile` and `review` fields.

The review string in the table is the authority for `appearance_review`. Kai's and Lyra's say approved; every new resident's must say review pending.

- [ ] **Step 5: Drive `check_contacts.py` from the table**

Its line 17 tuple `(('kai','KaiRig','GS030_CoderKai'),('lyra','LyraRig','GS031_ArtisticLyra'))` duplicates data the table already owns. Derive it from `RESIDENTS` instead — the table has `rig_name` and `mesh_name` fields for exactly this.

- [ ] **Step 6: Rebuild and prove nothing changed**

```bash
blender --background --factory-startup --python-exit-code 1 --python scripts/build_assets.py
sha256sum -c /tmp/stage2-baseline.txt
```

Both must report `OK`. This task is a refactor: the exported robots must not change.

- [ ] **Step 7: Run the full gate**

```bash
python3 scripts/test_exports.py
npm run --prefix tools validate
blender --background --factory-startup source/work-bay.blend --python-exit-code 1 --python scripts/check_contacts.py
godot --headless --editor --path godot --import --quit
for t in fixture import scene movement journey shared_workshop bay_pitch; do \
  godot --headless --path godot --script res://tests/${t}_test.gd 2>&1 | grep -E '^\{'; done
git checkout -- evidence/
```

Expected: all pass; `check_contacts.py` reports 0 failures; every Godot suite `"failures":0`.

- [ ] **Step 8: Commit**

```bash
git add prototypes/voxel-work-bay/scripts prototypes/voxel-work-bay/source/work-bay.blend \
        prototypes/voxel-work-bay/asset-manifest.json
git commit -m "refactor: drive the build and contact checks from the resident table

Eleven places named kai and lyra literally, so adding a resident meant
eleven hand edits and eleven chances to miss one. They now read
character.RESIDENTS. Exported robots are byte-identical."
```

---

### Task 3: Author residents 1–4 — Olivia, Chotu, Pete, Ray

**Files:**
- Modify: `prototypes/voxel-work-bay/scripts/character.py`

**Interfaces:**
- Consumes: the `RESIDENTS` table and the `chest_motif` / `head_crest` hook convention from Task 1.
- Produces: four new `RESIDENTS` entries and their geometry functions; four new GLBs at `godot/assets/{onboarding-olivia,super-chotu,project-manager-pete,research-ray}.glb`.

- [ ] **Step 1: Write the failing test**

Add to `scripts/test_exports.py`:

```python
    def test_every_resident_shares_the_rig_and_clip_set(self):
        import sys
        sys.path.insert(0,str(ROOT/'scripts'))
        from character import RESIDENTS
        reference=None
        for profile in sorted(RESIDENTS):
            doc,blob=glb(ROOT/'godot/assets'/(profile+'.glb'))
            bones=[n['name'] for n in doc['nodes'] if 'mesh' not in n and n.get('name','').replace('.','').replace('_','').isalnum()]
            clips=sorted(a['name'].split('|')[-1].split('/')[-1].lower() for a in doc.get('animations',[]))
            self.assertEqual(len(doc['skins'][0]['joints']),16,f'{profile} must bind 16 bones')
            self.assertEqual(clips,['attend','idle','seated_idle','sit_down','stand_up','typing','walk'],
                             f'{profile} must carry the same seven clips')
            joints=doc['skins'][0]['joints']
            if reference is None: reference=(profile,joints)
            else: self.assertEqual(len(joints),len(reference[1]),
                                   f'{profile} bind differs from {reference[0]}')
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 scripts/test_exports.py`
Expected: FAIL — the four new profiles have no GLB yet, so `test_every_resident_in_the_table_is_exported` from Task 2 fails first.

- [ ] **Step 3: Read the two worked examples**

Open `scripts/character.py` and read Kai's and Lyra's `chest_motif` and `head_crest` functions end to end. Match their idiom: small boxes, palette materials, every box weighted `'Spine'` (motif) or `'Head'` (crest), a comment naming the roster detail each motif comes from.

- [ ] **Step 4: Add the four residents**

Add table entries and geometry functions for:

| Profile | Name | GS | Accent | Motif |
| --- | --- | --- | --- | --- |
| `onboarding-olivia` | Onboarding Olivia | GS-027 | mint | A folded route-map panel across the chest: a `paper` ground with two or three `cobalt` and `orange` path lines running corner to corner, and a small `mint` location pip where they meet. Her card calls it a route-map quilt. |
| `super-chotu` | Super Chotu | GS-028 | orange | A shallow `wood_honey` display shelf with three miniature prototype blocks on it in `steel`, `cobalt` and `orange` — a tiny museum of lab prototypes, per his card. |
| `project-manager-pete` | Project Manager Pete | GS-029 | navy | A `navy` board carrying a grid of small `paper` cards, one or two offset as if just moved — his card's movable planning wall. |
| `research-ray` | Research Ray | GS-032 | green | Three stacked shallow `wood_dark` drawers with `steel` pull tabs, one drawer slightly open showing a `paper` edge — his annotated map cabinet. |

Each `review` field reads that operator review is pending. Each `source_profile` is the profile slug. Each `gs_id` follows the existing `'GS-0NN / GS-041 pilot subset'` form.

Stay inside the chest-motif envelope in this plan's preamble. Do not alter shared geometry, the rig, the bones, or the clips.

- [ ] **Step 5: Build and check contacts**

```bash
blender --background --factory-startup --python-exit-code 1 --python scripts/build_assets.py
blender --background --factory-startup source/work-bay.blend --python-exit-code 1 --python scripts/check_contacts.py
```
Expected: `SHARED_EXPORTS_READY`-style completion and 0 contact failures. A contact failure means a motif intersects the desk, the chair or a limb — fix the geometry, not the checker.

- [ ] **Step 6: Verify parity and validate**

```bash
python3 scripts/test_exports.py
npm run --prefix tools validate
git checkout -- evidence/
```
Expected: all pass, including the new parity test — 16 bones and the same seven clips for all six residents.

- [ ] **Step 7: Look at them**

```bash
blender --background --factory-startup --python-exit-code 1 --python scripts/build_assets.py -- --render
```

Open the review renders. For each of the four, confirm: the motif reads as its object at a glance; the accent is distinguishable from the other residents'; nothing pokes through the shell or floats detached; and the robot still reads as the same design family as Kai and Lyra. **Report what you see, per resident.** A motif that does not read is a finding, not a matter of taste.

- [ ] **Step 8: Commit**

```bash
git add prototypes/voxel-work-bay/scripts/character.py prototypes/voxel-work-bay/scripts/test_exports.py \
        prototypes/voxel-work-bay/godot/assets prototypes/voxel-work-bay/source/work-bay.blend \
        prototypes/voxel-work-bay/asset-manifest.json prototypes/voxel-work-bay/evidence
git commit -m "feat: author Olivia, Chotu, Pete and Ray on the shared rig

Four appearances from their roster cards' signature objects. All six
residents now share one 16-bone bind and the same seven clips, asserted
by a new parity test rather than by inspection."
```

---

### Task 4: Author residents 5–8 — Quill, Echo, Paul, Sam

**Files:** Modify `prototypes/voxel-work-bay/scripts/character.py`

**Interfaces:** Same hooks as Task 3. Produces four GLBs at `godot/assets/{writer-quill,analyst-echo,predictor-paul,strategy-sam}.glb`.

- [ ] **Step 1: Add the four residents**

| Profile | Name | GS | Accent | Motif |
| --- | --- | --- | --- | --- |
| `writer-quill` | Writer Quill | GS-033 | wood_honey | A `paper` lantern shape — a soft-cornered box lit by an `orange` inner block — beside a slim closed book in `wood_dark` with an `ivory` page edge. Her card gives paper lanterns and a reading nook. |
| `analyst-echo` | Analyst Echo | GS-034 | sky | A bar-chart relief: four or five `sky` and `led_green` blocks of rising height on an `ink` baseline — the kinetic chart sculpture from his card. |
| `predictor-paul` | Predictor Paul | GS-035 | blue_light | A branching fork: one `ivory` line splitting into two `blue_light` paths, with a small `sky` weather bead hanging at one branch tip. His card gives a weather mobile and branching paths. |
| `strategy-sam` | Strategy Sam | GS-036 | orange_dark | A small chequered grid in `ivory` and `ink`, with one raised `orange_dark` piece standing on it — the garden chess table from her card. |

Follow the same envelope and conventions as Task 3.

- [ ] **Step 2: Build, check contacts, verify parity, validate**

```bash
blender --background --factory-startup --python-exit-code 1 --python scripts/build_assets.py
blender --background --factory-startup source/work-bay.blend --python-exit-code 1 --python scripts/check_contacts.py
python3 scripts/test_exports.py
npm run --prefix tools validate
git checkout -- evidence/
```
Expected: 0 contact failures; parity test passes for all ten residents; validator clean.

- [ ] **Step 3: Look at them**

```bash
blender --background --factory-startup --python-exit-code 1 --python scripts/build_assets.py -- --render
```

Open the renders and report per resident, as in Task 3. Pay particular attention to **Echo (sky) against Paul (blue_light)** — these are neighbouring palette entries and the point of looking is to find out whether they separate. If they do not, say so; that is a real finding and changing one accent is cheap now and expensive later.

- [ ] **Step 4: Commit**

```bash
git add prototypes/voxel-work-bay/scripts/character.py prototypes/voxel-work-bay/godot/assets \
        prototypes/voxel-work-bay/source/work-bay.blend prototypes/voxel-work-bay/asset-manifest.json \
        prototypes/voxel-work-bay/evidence
git commit -m "feat: author Quill, Echo, Paul and Sam on the shared rig"
```

---

### Task 5: Author residents 9–12 — Casey, Ollie, Theo, Cody

**Files:** Modify `prototypes/voxel-work-bay/scripts/character.py`

**Interfaces:** Same hooks. Produces four GLBs at `godot/assets/{controller-casey,optimizer-ollie,threat-hunter-theo,cleaner-cody}.glb`.

- [ ] **Step 1: Add the four residents**

| Profile | Name | GS | Accent | Motif |
| --- | --- | --- | --- | --- |
| `controller-casey` | Controller Casey | GS-037 | steel | A rack of resource tokens: two rows of small `orange`, `cobalt` and `mint` discs held in a `steel` frame — the resource-token cabinet from her card. |
| `optimizer-ollie` | Optimizer Ollie | GS-038 | coral | A looping marble-run track in `coral` and `wood_honey` with a single `sky` bead part-way along it — his marble-run laboratory. |
| `threat-hunter-theo` | Threat Hunter Theo | GS-039 | ink | A puzzle-lock plate: an `ink` disc on a `steel` back plate with three `led_green` tumbler pips around its edge — the puzzle-lock display from his card. |
| `cleaner-cody` | Cleaner Cody | GS-040 | leaf_light | Three mended blocks in mismatched `wood_dark`, `sand` and `cream` with visible `leaf_light` repair seams between them — his repaired-object shelves. |

- [ ] **Step 2: Build, check contacts, verify parity, validate**

```bash
blender --background --factory-startup --python-exit-code 1 --python scripts/build_assets.py
blender --background --factory-startup source/work-bay.blend --python-exit-code 1 --python scripts/check_contacts.py
python3 scripts/test_exports.py
npm run --prefix tools validate
git checkout -- evidence/
```
Expected: 0 contact failures; parity passes for all fourteen; validator clean.

- [ ] **Step 3: Look at them, and at the whole cast**

```bash
blender --background --factory-startup --python-exit-code 1 --python scripts/build_assets.py -- --render
```

Report per resident as before. Then judge the **fourteen together**: does every accent separate from every other at a glance, and does every motif read as a distinct object? Specifically check **Theo's `ink`**, which is near-black against the white shell and may read as absence rather than accent, and **Ray (green) against Cody (leaf_light)**, another neighbouring pair. Name any that fail; do not quietly accept a cast where two residents are hard to tell apart.

- [ ] **Step 4: Commit**

```bash
git add prototypes/voxel-work-bay/scripts/character.py prototypes/voxel-work-bay/godot/assets \
        prototypes/voxel-work-bay/source/work-bay.blend prototypes/voxel-work-bay/asset-manifest.json \
        prototypes/voxel-work-bay/evidence
git commit -m "feat: author Casey, Ollie, Theo and Cody, completing the cast"
```

---

### Task 6: Seat all fourteen and make the runtime read at fourteen

Authoring a GLB does not put a resident in the hall. `layout.json`'s `stations` array has two entries; this task makes it fourteen and fixes the three UI surfaces that degrade at that count.

**Files:**
- Modify: `prototypes/voxel-work-bay/scripts/shared_workshop.py`
- Modify: `prototypes/voxel-work-bay/godot/shared_workshop.gd`
- Modify: `prototypes/voxel-work-bay/scripts/test_shared_assets.py`

**Interfaces:**
- Consumes: `BAYS` (14 anchors) and the reservation block from stage 1; `character.RESIDENTS` for the cast.
- Produces: `layout.json` with fourteen `stations` entries and no reserved furniture, since every bay is now occupied.

- [ ] **Step 1: Write the failing test**

In `scripts/test_shared_assets.py`, replace the two reserved-bay assertions in `HallEnvelope` with:

```python
    def test_every_bay_holds_a_resident(self):
        self.assertEqual(len(self.d['stations']),14,'all fourteen bays are occupied')
        origins=sorted((s['origin'][0],s['origin'][2]) for s in self.d['stations'])
        self.assertEqual(sorted({x for x,_ in origins}),[-3,3])
        for zone in (-3,3):
            zs=sorted(z for x,z in origins if x==zone)
            self.assertEqual(zs,[-6,-4,-2,0,2,4,6])
        for asset in ('desk.glb','terminal.glb','chair.glb'):
            self.assertEqual([i for i in self.d['instances'] if i['asset']==asset],[],
                             'stations furnish their own bays; no reserved furniture should remain')
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 scripts/test_shared_assets.py`
Expected: FAIL — 2 stations, not 14.

- [ ] **Step 3: Seat the cast**

In `scripts/shared_workshop.py`, build `d['stations']` from the fourteen `BAYS` anchors in roster order: GR01–GR07 in the west zone north to south, GR08–GR14 in the east zone. Kai is GR04 and Lyra GR05, so their current origins `[-3,0,0]` and `[-3,0,2]` must not move. Remove the reservation block — every bay now has a station, and `workshop_station.gd` furnishes its own.

Import the roster order from `character.RESIDENTS` rather than re-listing it; the table is the cast's single source of truth.

- [ ] **Step 4: Fix the three UI surfaces**

In `godot/shared_workshop.gd`:
- The controls panel is a fixed 188 px `ScrollContainer` that already clips at two residents. Give the resident rows a workable presentation at fourteen — a taller panel, a compact per-resident row, or a selector. Your call; the requirement is that a viewer can reach every resident's controls without hunting.
- `"Both leave [L]"` / `"Both return [B]"` are two-resident labels bound to an `"all"` action. Relabel for fourteen.
- `describe()` prints one line per station. At fourteen that is a wall of text; summarise, while keeping every resident's state reachable.

- [ ] **Step 5: Rebuild, test and look**

```bash
blender --background --factory-startup --python-exit-code 1 --python scripts/build_shared_workshop.py
python3 scripts/test_shared_assets.py
godot --headless --editor --path godot --import --quit
for t in fixture import scene movement journey shared_workshop bay_pitch; do \
  godot --headless --path godot --script res://tests/${t}_test.gd 2>&1 | grep -E '^\{'; done
DISPLAY=:1 godot --path godot res://shared_workshop.tscn -- --camera=overview --show-controls \
  --capture="$PWD/evidence/hall-fourteen-r004.png"
git checkout -- evidence/shared-validation/
```

`bay_pitch_test.gd` now exercises fourteen movers rather than two — **this is the run that makes its coverage real.** Expect it to take longer. If it fails, a resident's lane genuinely conflicts with a seated neighbour; report it rather than widening the pitch.

Open the capture. Confirm fourteen distinct residents are seated at fourteen bays and that the controls panel is usable.

- [ ] **Step 6: Commit**

```bash
git add prototypes/voxel-work-bay/scripts prototypes/voxel-work-bay/godot \
        prototypes/voxel-work-bay/shared-workshop-manifest.json \
        prototypes/voxel-work-bay/source/shared-workshop.blend prototypes/voxel-work-bay/evidence
git commit -m "feat: seat all fourteen residents and scale the runtime to them

layout.json now carries fourteen stations built from the resident table;
reserved furniture is gone because every bay furnishes itself. The controls
panel, the both-leave labels and the text view all assumed two residents."
```

---

### Task 7: Documentation, tracker and evidence

**Files:**
- Create: `prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md`
- Modify: `prototypes/voxel-work-bay/README.md`, `SHARED_WORKSHOP.md`, `ASSET_WORKFLOW.md`
- Modify: `docs/gameplay/asset-catalogue/FIRST_GUILD_SCENE.md`

- [ ] **Step 1: Capture the gate and the cast**

Run the full gate, capture its output to `evidence/full-cast-tests.txt`, and capture exterior, cutaway and a first-person view of the populated hall. Open every capture and confirm it shows what you will claim.

- [ ] **Step 2: Write the verification record**

Following `HALL-EXPANSION-VERIFICATION.md`'s structure, record: the fourteen appearances with their GS ids, accents and motifs; the shared-rig parity result (16 bones, seven clips, all fourteen); contact-check results; Khronos results; byte sizes; the bay-pitch result at fourteen movers; and the runtime changes. State plainly that **only Kai's and Lyra's appearances have user approval** and the twelve new ones do not.

- [ ] **Step 3: Update the prototype docs**

`README.md` and `SHARED_WORKSHOP.md` describe a two-resident scene throughout. Bring them to fourteen. `ASSET_WORKFLOW.md` §4 states "Kai and Lyra share a 16-bone bind structure and seven clips" — that is now the whole cast.

- [ ] **Step 4: Update the tracker**

Move **GS-027 through GS-040** to Build *In progress*, Test *Not run*, Review *Pending*, each with its artifact revision, evidence link, style reference and a change-history line naming its motif and accent. GS-030 and GS-031 gain a change-history line for the table refactor.

Update the snapshot count and its prose. **Do not advance any Review state** — twelve appearances are unreviewed, and GS-031's row still needs its own acceptance record for Lyra, which is separate from this work.

- [ ] **Step 5: Check links and commit**

Run the link checker over every changed document; expect `broken links: 0`. Then commit.

---

## Self-review

**Spec coverage.** The spec's *Residents* section is Tasks 3–5; its `character.py` refactor requirement is Task 1 (done) plus Task 2, which the spec did not anticipate but its review surfaced. Seating the cast and the UI at fourteen is Task 6 — the spec's contract table names the control panel and text view, and the stage-1 carries named all three surfaces. Task 7 covers the acceptance boundary. The spec's *Deferred* section needs no task here.

**Placeholder scan.** Tasks 3–5 specify each motif by its content, materials and roster source, with a stated geometric envelope, rather than giving exact box coordinates. That is deliberate: coordinates invented without Blender would be unverifiable guesses, and the project's own verification for this is `check_contacts.py` plus looking at the render, both of which every batch task runs. Kai's and Lyra's existing functions are the worked examples, and the plan requires reading them first. Task 6 Step 4 states a requirement and leaves the UI treatment to the implementer, for the same reason — three named surfaces, one stated acceptance criterion.

**Type consistency.** `RESIDENTS` is introduced in Task 1 and consumed by Tasks 2, 3–5 and 6, always as a dict keyed by profile slug with `mesh_name`, `rig_name`, `gs_id`, `source_profile`, `head_accent`, `thigh_accent`, `review`, `chest_motif` and `head_crest`. GLB filenames are the profile slug throughout. `BAYS` from stage 1 is consumed unchanged in Task 6. Kai's and Lyra's origins `[-3,0,0]` and `[-3,0,2]` are stated identically in stage 1's plan and Task 6.
