# Guild Hall Expansion — Stage 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enlarge the workshop hall to 12 × 16 m with fourteen bay anchors in two zones, relocate the existing two residents, and translate the courtyard one metre east so it stays outside the building.

**Architecture:** All geometry is procedural in `scripts/shared_workshop.py`; `kit()` builds reusable modules and `layout()` emits `layout.json`, which the Godot scene consumes generically. The roof module's bay width is a single recipe variable. Nothing in the runtime hardcodes a station count except one control-panel loop, which this plan removes.

**Tech Stack:** Blender 5.2.2 LTS (`bpy`), glTF 2.0 / GLB, Python 3 stdlib `unittest`, Node.js pinned Khronos `gltf-validator` 2.0.0-dev.3.10, Godot 4.6.3 `gl_compatibility`.

**Spec:** `docs/superpowers/specs/2026-09-22-guild-hall-expansion-design.md`

## Global Constraints

- **Base branch:** this stage modifies files introduced by PR #19 (`feat/courtyard-environment-kit`). Branch from that, not from `main`. If #19 has merged, branch from `main` after fetching.
- Units are metres, glTF/Godot Y-up, +X east, −Z north, floor top at Y = 0.
- Run every Blender build in a **fresh background process**: `blender --background --factory-startup --python-exit-code 1 --python <script>`.
- All commands run from `prototypes/voxel-work-bay` unless stated.
- The validator gate rejects **errors and warnings**, not just errors.
- Never edit a hash in a manifest to silence a mismatch — regenerate the matching set.
- Do not regenerate the twelve pre-existing `evidence/shared-validation/*.json` reports; if a rebuild rewrites their timestamps, `git checkout --` them.
- Robot and furniture GLBs (`chair`, `desk`, `environment`, `kai`, `lyra`, `terminal`) must stay byte-identical. Verify with hashes captured before starting.
- Manifest revision moves `shared-workshop-r002` → `shared-workshop-r003`.
- Nothing in this stage is "accepted". Tracker rows stay **In progress**; reviews stay **Pending**.

---

### Task 1: Move the scene — widen roof bays, enlarge the hall, shift the courtyard

This is one geometric change. Splitting it leaves the scene spatially inconsistent and unreviewable.

**Files:**
- Modify: `prototypes/voxel-work-bay/scripts/shared_workshop.py` (roof recipe `w`; whole `layout()` body)
- Modify: `prototypes/voxel-work-bay/scripts/build_shared_workshop.py` (revision string)
- Modify: `prototypes/voxel-work-bay/scripts/test_shared_assets.py` (hall, roof, station, doorway assertions)

**Interfaces:**
- Consumes: `kit(materials) -> (assets, solids)` and `layout(solids) -> dict`, both already present.
- Produces: `layout.json` with `stations` = `[{"resident":"kai","origin":[-3,0,0]}, {"resident":"lyra","origin":[-3,0,2]}]`, six `group:"roof"` instances, and the hall spanning x −6…6, z −8…8.

- [ ] **Step 1: Capture baseline hashes for the byte-identity check**

```bash
cd prototypes/voxel-work-bay
sha256sum godot/assets/*.glb > /tmp/hall-baseline.txt
cat /tmp/hall-baseline.txt
```

- [ ] **Step 2: Write the failing tests**

Add this class to `scripts/test_shared_assets.py`, immediately before the final `if __name__=='__main__':unittest.main()` line:

```python
class HallEnvelope(unittest.TestCase):
    def setUp(self):
        self.d=json.loads((OUT/'layout.json').read_text())

    def test_hall_is_twelve_by_sixteen_metres(self):
        floors=[i['position'] for i in self.d['instances'] if i['asset']=='workshop/floor.glb']
        self.assertEqual(len(floors),48)
        xs=sorted({p[0] for p in floors}); zs=sorted({p[2] for p in floors})
        self.assertEqual(xs,[-5,-3,-1,1,3,5])
        self.assertEqual(zs,[-7,-5,-3,-1,1,3,5,7])

    def test_three_sawtooth_bays_cover_the_wider_hall(self):
        roof=[i for i in self.d['instances'] if i['group']=='roof']
        self.assertEqual(len(roof),6,'three bays, two 8 m modules deep each')
        self.assertEqual(sorted({i['position'][0] for i in roof}),[-4,0,4])
        self.assertEqual(sorted({i['position'][2] for i in roof}),[-4,4])

    def test_residents_sit_on_their_roster_bay_anchors(self):
        self.assertEqual(self.d['stations'],[
            {'resident':'kai','origin':[-3,0,0]},
            {'resident':'lyra','origin':[-3,0,2]}])

    def test_doorway_moved_east_with_the_wall(self):
        doors=[i for i in self.d['instances'] if i['asset']=='workshop/door.glb']
        self.assertEqual(len(doors),1)
        self.assertEqual(doors[0]['position'],[6,0,1])
```

- [ ] **Step 3: Update the assertions that encode the old hall**

In `scripts/test_shared_assets.py`, make exactly these four replacements.

The station equality inside `test_layout_and_clearance` — delete this line entirely, since `HallEnvelope.test_residents_sit_on_their_roster_bay_anchors` now covers it:

```python
        self.assertEqual(d['stations'],[{'resident':'kai','origin':[-2,0,-.8]},{'resident':'lyra','origin':[2,0,-.8]}])
```

The roof instance count in `test_layout_and_clearance`:

```python
        self.assertEqual(len([i for i in d['instances'] if i['group']=='roof']),3)
```
becomes
```python
        self.assertEqual(len([i for i in d['instances'] if i['group']=='roof']),6)
```

The doorway corridor sweep in `test_layout_and_clearance` — the corridor moves 1 m east with the wall:

```python
            self.assertFalse(x-sx/2<5.15 and x+sx/2>4.85 and y+sy/2>.05 and y-sy/2<2.19 and z+sz/2>.31 and z-sz/2<1.69,c['id'])
```
becomes
```python
            self.assertFalse(x-sx/2<6.15 and x+sx/2>5.85 and y+sy/2>.05 and y-sy/2<2.19 and z+sz/2>.31 and z-sz/2<1.69,c['id'])
```

The paved landing check in `test_layout_and_clearance`:

```python
        self.assertTrue(any(Path(i['asset']).stem in PAVED and i['position']==[6,0,1] for i in d['instances']),'no paved landing outside the east doorway')
```
becomes
```python
        self.assertTrue(any(Path(i['asset']).stem in PAVED and i['position']==[7,0,1] for i in d['instances']),'no paved landing outside the east doorway')
```

The roof width in the module-width loop of `test_manifest_and_geometry`:

```python
        for name,width in [('floor',2),('wall',2),('window',2),('door',2),('roof',10/3),('path_corner',2),('path_t',2),('railing',2),('awning',2)]:
```
becomes
```python
        for name,width in [('floor',2),('wall',2),('window',2),('door',2),('roof',4.0),('path_corner',2),('path_t',2),('railing',2),('awning',2)]:
```

And the courtyard doorway constant near the top of the `CourtyardKit` block:

```python
DOORWAY=(5.0,1.0)   # hall threshold; a west arm may terminate here instead of on a tile.
```
becomes
```python
DOORWAY=(6.0,1.0)   # hall threshold; a west arm may terminate here instead of on a tile.
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `python3 scripts/test_shared_assets.py`
Expected: FAIL. `HallEnvelope` reports 20 floor tiles rather than 48 and 3 roof instances rather than 6; `CourtyardKit` reports an arm reaching nothing, because the doorway constant moved before the geometry did.

- [ ] **Step 5: Widen the roof bay**

In `scripts/shared_workshop.py`, inside `kit()`:

```python
    begin('roof')
    w=10/3
```
becomes
```python
    begin('roof')
    # Three sawtooth bays are preserved in count; the wider hall widens each bay.
    w=4.0
```

- [ ] **Step 6: Rebuild the hall and courtyard in `layout()`**

In `scripts/shared_workshop.py`, replace the `d={...}` initialiser and everything from `for x in (-4,-2,0,2,4):` down to and including the `put('sign',...)` line. Keep the nested `put()` helper exactly as it is, and keep the final shelf/bench line and `return d`.

The initialiser:

```python
    d={'version':1,'bounds':{'min':[-5.3,0,-4.5],'max':[12.5,4,4.5]},'stations':[{'resident':'kai','origin':[-2,0,-.8]},{'resident':'lyra','origin':[2,0,-.8]}],'instances':[],'collisions':[]}
```
becomes
```python
    # Roster order seats GR01-GR07 in the west zone north to south; Kai is GR04
    # and Lyra GR05, so they take the fourth and fifth bays.
    d={'version':1,'bounds':{'min':[-6.3,0,-8.5],'max':[12.5,4,8.5]},
       'stations':[{'resident':'kai','origin':[-3,0,0]},{'resident':'lyra','origin':[-3,0,2]}],
       'instances':[],'collisions':[]}
```

The hall and courtyard body:

```python
    # Hall is 12 x 16 m on the 2 m grid, with the doorway on the east wall.
    HALL_X=(-5,-3,-1,1,3,5); HALL_Z=(-7,-5,-3,-1,1,3,5,7)
    for x in HALL_X:
        for z in HALL_Z:put('floor',(x,0,z))
        put('window' if abs(x)<4 else 'wall',(x,0,-8))
        put('window' if abs(x)<4 else 'wall',(x,0,8),'front',180)
    for z in HALL_Z:
        put('window' if abs(z)<4 else 'wall',(-6,0,z),rot=90)
        put('door' if z==1 else 'window' if abs(z)<4 else 'wall',(6,0,z),'front',90)
    for x in (-4,0,4):
        for z in (-4,4):put('roof',(x,0,z),'roof')
    # Closed public loop around a central planted island, translated one metre
    # east so it stays clear of the enlarged hall. Geometry is unchanged.
    loop={(7,1):('path_t',270),(7,-1):('path_corner',270),(9,-1):('path',0),
          (11,-1):('path_corner',180),(11,1):('path',90),(11,3):('path_corner',90),
          (9,3):('path',0),(7,3):('path_corner',0)}
    for x in (7,9,11):
        for z in (-3,-1,1,3):
            name,rot=loop.get((x,z),('lawn',0))
            put(name,(x,0,z),'courtyard',rot)
    put('tree',(9.2,0,1),'courtyard')
    for p in ((7,0,-3),(9,0,-3),(11,0,-3)):put('planter',p,'courtyard')
    put('awning',(6,0,1),'front')
    for z in (-3,-1,1,3):put('railing',(12,0,z),'courtyard',90)
    for x in (7,9,11):
        put('railing',(x,0,-4),'courtyard')
        put('railing',(x,0,4),'courtyard',180)
    put('sign',(6.5,0,2.9),'decor',90)
```

The final decor line moves to the new walls — shelves against the north wall and benches against the south, both clear of the bay run at x = ±3:

```python
    for x in (-2,2):put('shelf',(x,0,-3.55),'decor');put('bench',(x,0,3.1),'decor')
```
becomes
```python
    for x in (-1,1):put('shelf',(x,0,-7.55),'decor');put('bench',(x,0,7.1),'decor')
```

- [ ] **Step 7: Bump the manifest revision**

In `scripts/build_shared_workshop.py`:

```python
'revision':'shared-workshop-r002'
```
becomes
```python
'revision':'shared-workshop-r003'
```

- [ ] **Step 8: Rebuild in a fresh Blender process**

Run: `blender --background --factory-startup --python-exit-code 1 --python scripts/build_shared_workshop.py`
Expected: a final line `SHARED_EXPORTS_READY 16 <bytes>` and no `Error`.

- [ ] **Step 9: Run the tests to verify they pass**

Run: `python3 scripts/test_shared_assets.py`
Expected: PASS, 12 tests.

If `CourtyardKit.test_every_arm_reaches_paving_or_the_doorway` fails, the loop dictionary and the `for x in (7,9,11)` range disagree — every key in `loop` must appear in that product of x and z values.

- [ ] **Step 10: Validate the exports and confirm nothing else moved**

```bash
node scripts/validate_shared_exports.cjs
python3 scripts/test_exports.py
sha256sum -c /tmp/hall-baseline.txt
git checkout -- evidence/shared-validation/
```
Expected: every GLB `0 errors, 0 warnings`; 6 export tests pass; all six robot/furniture GLBs report `OK`.

- [ ] **Step 11: Import into Godot and run the scene suites**

```bash
godot --headless --editor --path godot --import --quit
for t in fixture import scene movement journey shared_workshop; do \
  godot --headless --path godot --script res://tests/${t}_test.gd 2>&1 | grep -E '^\{'; done
```
Expected: every suite reports `"failures":0`, and `scene` reports `"missing_assets":[]`.

- [ ] **Step 12: Commit**

```bash
git add scripts/shared_workshop.py scripts/build_shared_workshop.py scripts/test_shared_assets.py \
        godot/assets/workshop/layout.json godot/assets/workshop/roof.glb \
        shared-workshop-manifest.json source/shared-workshop.blend
git commit -m "feat: enlarge the hall to 12 x 16 m and shift the courtyard east

Three sawtooth bays are preserved in count and widened from 3.33 m to 4.0 m
to span the wider hall. Kai and Lyra move to their roster bay anchors. The
courtyard translates one metre east so it stays outside the building; every
module is reused and no courtyard geometry is re-authored."
```

---

### Task 2: Reserve the twelve empty bay anchors

**Files:**
- Modify: `prototypes/voxel-work-bay/scripts/shared_workshop.py` (`layout()`)
- Modify: `prototypes/voxel-work-bay/scripts/test_shared_assets.py` (`HallEnvelope`)

**Interfaces:**
- Consumes: `layout()`'s `d` dict and its `put()` helper from Task 1.
- Produces: `BAYS`, a module-level list of 14 `(x, z)` tuples in roster order, importable by tests; and `layout.json` carrying desk, terminal and chair instances plus desk and chair collision boxes at each unoccupied bay.

- [ ] **Step 1: Write the failing test**

Add these two methods to the `HallEnvelope` class in `scripts/test_shared_assets.py`:

```python
    def test_fourteen_bays_in_two_zones_at_two_metre_pitch(self):
        desks=sorted((i['position'][0],i['position'][2]) for i in self.d['instances'] if i['asset']=='desk.glb')
        occupied=sorted((s['origin'][0],s['origin'][2]) for s in self.d['stations'])
        bays=sorted(desks+occupied)
        self.assertEqual(len(bays),14,'seven bays in each of two zones')
        self.assertEqual(sorted({x for x,_ in bays}),[-3,3],'two zones, west and east')
        for zone in (-3,3):
            zs=sorted(z for x,z in bays if x==zone)
            self.assertEqual(zs,[-6,-4,-2,0,2,4,6])
            for a,b in zip(zs,zs[1:]):
                self.assertAlmostEqual(b-a,2.0,places=6,msg='bay pitch must stay at the verified 2.0 m')

    def test_reserved_bays_are_furnished_but_unoccupied(self):
        occupied={(s['origin'][0],s['origin'][2]) for s in self.d['stations']}
        for asset in ('desk.glb','terminal.glb','chair.glb'):
            placed=[i for i in self.d['instances'] if i['asset']==asset]
            self.assertEqual(len(placed),12,f'{asset} at each of the twelve reserved bays')
        for i in self.d['instances']:
            if i['asset']=='desk.glb':
                self.assertNotIn((i['position'][0],i['position'][2]),occupied,
                                 'a station already furnishes its own bay')
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python3 scripts/test_shared_assets.py -k HallEnvelope`
Expected: FAIL — `test_fourteen_bays_in_two_zones_at_two_metre_pitch` finds 2 bays, not 14.

- [ ] **Step 3: Add the bay table and the reservation helper**

In `scripts/shared_workshop.py`, add this immediately above `def layout(solids):`:

```python
# Roster order: GR01-GR07 west zone north to south, GR08-GR14 east zone.
BAYS=[(-3,z) for z in (-6,-4,-2,0,2,4,6)]+[(3,z) for z in (-6,-4,-2,0,2,4,6)]
```

Then inside `layout()`, directly after the `put('sign',...)` line, add:

```python
    # Bays without a resident yet are furnished and reserved. Station-owned bays
    # get their furniture from workshop_station.gd instead, so skip those.
    taken={(s['origin'][0],s['origin'][2]) for s in d['stations']}
    for x,z in BAYS:
        if (x,z) in taken:continue
        for asset,off in (('desk',(0,0,0)),('terminal',(0,.78,.12)),('chair',(0,0,-.65))):
            d['instances'].append({'id':f'bay_{asset}_{len(d["instances"]):03}','asset':f'{asset}.glb',
                                   'position':[x+off[0],off[1],z+off[2]],'rotation_y':0,'group':'decor'})
        for name,p,s in (('desk',(0,.4,0),(1.75,.8,.78)),('chair',(0,.45,-.68),(.65,.9,.65))):
            d['collisions'].append({'id':f'bay_{name}_{len(d["collisions"]):03}',
                                    'position':[x+p[0],p[1],z+p[2]],'size':list(s),'rotation_y':0})
```

- [ ] **Step 4: Rebuild and run the tests to verify they pass**

```bash
blender --background --factory-startup --python-exit-code 1 --python scripts/build_shared_workshop.py
python3 scripts/test_shared_assets.py
```
Expected: `SHARED_EXPORTS_READY 16 <bytes>`, then PASS, 14 tests.

- [ ] **Step 5: Confirm Godot loads every reserved asset**

```bash
godot --headless --editor --path godot --import --quit
godot --headless --path godot --script res://tests/scene_test.gd 2>&1 | grep -E '^\{'
godot --headless --path godot --script res://tests/shared_workshop_test.gd 2>&1 | grep -E '^\{'
```
Expected: `"missing_assets":[]` and `"failures":0` from both.

A `missing_assets` entry like `workshop/desk.glb.glb` means an asset path was written as `workshop/desk.glb`; reserved furniture lives at `godot/assets/`, so its `asset` value is bare `desk.glb`.

- [ ] **Step 6: Commit**

```bash
git add scripts/shared_workshop.py scripts/test_shared_assets.py \
        godot/assets/workshop/layout.json shared-workshop-manifest.json source/shared-workshop.blend
git commit -m "feat: reserve twelve furnished bay anchors for the remaining cast

Fourteen bays across two zones at the 2.0 m pitch the movement spike verified.
Kai and Lyra occupy two; the rest carry desk, terminal and chair with matching
collision proxies and no resident, so the hall reads as built-out without
implying a cast that has not been designed."
```

---

### Task 3: Remove the hardcoded resident list from the runtime

**Files:**
- Modify: `prototypes/voxel-work-bay/godot/shared_workshop.gd:321` and the scene-text builder near line 212

**Interfaces:**
- Consumes: `stations`, the Dictionary built by `build_layout()`.
- Produces: no new API. The control panel and text view both derive from `stations` and stay correct at any station count.

- [ ] **Step 1: Replace the hardcoded loop**

In `godot/shared_workshop.gd`:

```gdscript
	for key in ["kai","lyra"]:
```
becomes
```gdscript
	for key in stations:
```

- [ ] **Step 2: Report reserved bays in the scene text**

In `godot/shared_workshop.gd`, the text view opens with a fixed sentence. Replace:

```gdscript
	var result := "SAMPLE DATA — shared voxel workshop and courtyard. Three sawtooth roof bays; east doorway connects a flush courtyard path to two independent robot workstations.\n"
```
with
```gdscript
	var result := "SAMPLE DATA — shared voxel workshop and courtyard. Three sawtooth roof bays; east doorway connects a flush courtyard path to fourteen work bays, %d of them currently occupied by independent robot residents.\n" % stations.size()
```

- [ ] **Step 3: Verify the scene still builds and behaves**

```bash
godot --headless --path godot --script res://tests/shared_workshop_test.gd 2>&1 | grep -E '^\{'
godot --headless --path godot --script res://tests/journey_test.gd 2>&1 | grep -E '^\{'
```
Expected: `"failures":0` from both.

- [ ] **Step 4: Confirm the control panel renders at the real station count**

```bash
DISPLAY=:1 godot --path godot res://shared_workshop.tscn -- --camera=overview --show-controls \
  --capture="$PWD/evidence/hall-controls-r003.png"
```
Expected: `"error":0` and `"missing_assets":[]` in the printed report. Open the PNG and confirm one leave/return row per occupied resident, with the panel fitting the viewport.

- [ ] **Step 5: Commit**

```bash
git add godot/shared_workshop.gd evidence/hall-controls-r003.png evidence/hall-controls-r003.json
git commit -m "fix: derive resident controls and scene text from the station list

The control panel iterated a literal [\"kai\",\"lyra\"], so any additional
resident would have been built into the scene but unreachable from the UI."
```

---

### Task 4: Make the bay-pitch constraint a permanent regression

The spike found that a lockstep departure passes at every pitch, including a deadlocking one. Only a mover passing a *stationary* neighbour exposes the constraint. Without this test a future pitch change silently reintroduces the deadlock.

**Files:**
- Create: `prototypes/voxel-work-bay/godot/tests/bay_pitch_test.gd`

**Interfaces:**
- Consumes: `shared_workshop.tscn`, its `stations` Dictionary, `request_leave(String)` and `advance_demo(float)`.
- Produces: a suite printing `{"test":"bay_pitch","failures":N}`, matching the convention of the existing suites.

- [ ] **Step 1: Write the failing test**

Create `godot/tests/bay_pitch_test.gd`:

```gdscript
extends SceneTree
## A resident departing past a SEATED neighbour is the case bay pitch has to
## clear. When every resident leaves in lockstep their relative distances never
## change and nothing blocks at any pitch, so that test cannot catch a bad pitch.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run_tests")
func run_tests() -> void:
	var scene = load("res://shared_workshop.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	await physics_frame
	check(scene.missing_assets().is_empty(), "all workshop assets import")
	var keys := []
	for k in scene.stations: keys.append(k)
	keys.sort()
	check(keys.size() >= 2, "at least two residents to test against each other")
	# Depart one resident while every other stays seated in its own bay.
	var mover: String = keys[0]
	scene.request_leave(mover)
	for i in range(900): scene.advance_demo(0.1)
	var m = scene.stations[mover]
	check(m.movement.phase == "away", "departing resident cleared its seated neighbours, got: " + m.movement.phase)
	check(not m.waiting, "departing resident must not be left waiting on a seated neighbour")
	for k in keys:
		if k == mover: continue
		check(scene.stations[k].movement.phase == "seated", k + " must stay seated")
	scene.request_return(mover)
	for i in range(900): scene.advance_demo(0.1)
	check(scene.stations[mover].movement.phase == "seated", "returning resident reached its bay")
	print(JSON.stringify({"test": "bay_pitch", "failures": failures}))
	quit(0 if failures == 0 else 1)
```

- [ ] **Step 2: Run it and confirm it passes at the shipped pitch**

Run: `godot --headless --path godot --script res://tests/bay_pitch_test.gd 2>&1 | grep -E '^\{'`
Expected: `{"test":"bay_pitch","failures":0}`

- [ ] **Step 3: Prove the test actually detects a bad pitch**

Temporarily narrow the pitch, rebuild, and confirm the suite fails. In `scripts/shared_workshop.py`:

```python
BAYS=[(-3,z) for z in (-6,-4,-2,0,2,4,6)]+[(3,z) for z in (-6,-4,-2,0,2,4,6)]
```
temporarily becomes
```python
BAYS=[(-3,z) for z in (-1.5,-1.0,-0.5,0,0.5,1.0,1.5)]+[(3,z) for z in (-1.5,-1.0,-0.5,0,0.5,1.0,1.5)]
```

Then also set the two station origins in `layout()` to `[-3,0,0]` and `[-3,0,0.5]` so they land on that narrowed run, and run:

```bash
blender --background --factory-startup --python-exit-code 1 --python scripts/build_shared_workshop.py
godot --headless --editor --path godot --import --quit
godot --headless --path godot --script res://tests/bay_pitch_test.gd 2>&1 | grep -E '^\{'
```
Expected: `"failures"` greater than 0, with a pushed error naming a resident left waiting. **Then revert both edits**, rebuild, and confirm `"failures":0` again. Do not commit the narrowed pitch.

- [ ] **Step 4: Commit**

```bash
git add godot/tests/bay_pitch_test.gd
git commit -m "test: guard the verified 2.0 m bay pitch against silent regression

A departing resident must clear its seated neighbours. Lockstep departure
preserves relative distance and passes at any pitch, including a deadlocking
one, so it cannot guard this."
```

---

### Task 5: Documentation, tracker and evidence

**Files:**
- Create: `prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md`
- Modify: `prototypes/voxel-work-bay/SHARED_WORKSHOP.md`
- Modify: `prototypes/voxel-work-bay/ASSET_WORKFLOW.md` (§2 interface contract, and the delivery boundaries)
- Modify: `docs/gameplay/asset-catalogue/FIRST_GUILD_SCENE.md` (GS-012, GS-015, courtyard rows, snapshot)

**Interfaces:**
- Consumes: the measured figures printed by the suites in Tasks 1–4.
- Produces: no code.

- [ ] **Step 1: Capture the full gate output as evidence**

```bash
cd prototypes/voxel-work-bay
{ echo "# Hall expansion r003 — local test output, 2026-09-22"; echo
  echo "\$ node scripts/validate_shared_exports.cjs"; node scripts/validate_shared_exports.cjs 2>&1
  echo; echo "\$ python3 scripts/test_shared_assets.py"; python3 scripts/test_shared_assets.py 2>&1 | tail -4
  echo; echo "\$ python3 scripts/test_exports.py"; python3 scripts/test_exports.py 2>&1 | tail -4
  echo; for t in fixture import scene movement journey shared_workshop bay_pitch; do
    echo "\$ godot --headless --path godot --script res://tests/${t}_test.gd"
    godot --headless --path godot --script res://tests/${t}_test.gd 2>&1 | grep -E '^\{' | cut -c1-200
  done; } > evidence/hall-expansion-tests.txt 2>&1
git checkout -- evidence/shared-validation/
tail -20 evidence/hall-expansion-tests.txt
```

- [ ] **Step 2: Capture viewport evidence**

```bash
P=$PWD
for c in exterior overview; do
  DISPLAY=:1 godot --path godot res://shared_workshop.tscn -- --camera=$c \
    --capture="$P/evidence/hall-$c-r003.png" 2>&1 | grep -oE '"error":[0-9.]+'
done
```
Expected: `"error":0` twice. Open both PNGs. Confirm three sawtooth bays span the wider hall, fourteen bays read as two rows, and the courtyard sits outside the east wall with its loop intact.

- [ ] **Step 3: Write the verification record**

Create `evidence/HALL-EXPANSION-VERIFICATION.md` covering, with the real numbers from Step 1:

- Revision `shared-workshop-r003`; local sample data; nothing accepted.
- What changed: hall 10 × 8 → 12 × 16 m, roof bay 3.33 → 4.0 m at six instances, fourteen bay anchors at 2.0 m pitch, courtyard translated +1 m east.
- The measured pitch constraint from the spec's *Measured constraints* section, and that `bay_pitch_test.gd` now guards it.
- Module byte sizes and Khronos results for all 16 GLBs; total; `.blend` size; instance and collision counts.
- Confirmation that robot and furniture GLBs are byte-identical and that courtyard module geometry is unchanged — only placements moved.
- The contract changes listed in the spec, marked done.
- Review still needed: the twelve reserved bays hold no residents; A01's environment half, A02, A05 and A06 remain open.

- [ ] **Step 4: Update the prototype docs**

In `SHARED_WORKSHOP.md`: hall dimensions and station origins under *Layout and movement*; add that fourteen bays sit in two zones at 2.0 m pitch with twelve reserved; link the new verification record.

In `ASSET_WORKFLOW.md`: update the §2 interface bullet from `Hall 10 × 8 m; station origins Kai (-2,0,-0.8), Lyra (2,0,-0.8)` to the 12 × 16 m hall and the fourteen bay anchors; add to *Current delivery boundaries* that twelve bays are furnished but unoccupied pending the cast.

- [ ] **Step 5: Update the tracker**

In `docs/gameplay/asset-catalogue/FIRST_GUILD_SCENE.md`:

- GS-012 roof module: add a 2026-09-22 change-history line recording the bay widening to 4.0 m and the new revision. Build stays **In progress**; Test stays **Not run**; Review stays **Pending**.
- GS-015 shared workshop assembly: update evidence links to the new verification record and revision; record that both zones and all fourteen bay anchors now exist with twelve unoccupied. Stays **In progress**.
- Courtyard rows GS-001–004, GS-007–013, GS-017, GS-023: update the artifact revision to `shared-workshop-r003` and note the +1 m translation in change history. Geometry is unchanged, so no Test or Review state moves.
- Snapshot line: keep the counts unless a row actually changed state, and update the date and the prose describing the hall.

- [ ] **Step 6: Check every relative link resolves**

```bash
cd ../..
python3 - <<'EOF'
import re
from pathlib import Path
bad=0
for f in ['docs/gameplay/asset-catalogue/FIRST_GUILD_SCENE.md',
          'prototypes/voxel-work-bay/SHARED_WORKSHOP.md',
          'prototypes/voxel-work-bay/ASSET_WORKFLOW.md',
          'prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md']:
    base=Path(f).parent
    for link in re.findall(r'\]\(([^)#]+?)(?:#[^)]*)?\)',Path(f).read_text()):
        if link.startswith(('http','mailto')):continue
        if not (base/link).resolve().exists():
            print('MISSING',f,'->',link);bad+=1
print('broken links:',bad)
EOF
```
Expected: `broken links: 0`

- [ ] **Step 7: Commit**

```bash
git add prototypes/voxel-work-bay/evidence prototypes/voxel-work-bay/SHARED_WORKSHOP.md \
        prototypes/voxel-work-bay/ASSET_WORKFLOW.md docs/gameplay/asset-catalogue/FIRST_GUILD_SCENE.md
git commit -m "docs: record the hall expansion, its evidence and the moved contracts

Hall 12 x 16 m with fourteen bay anchors at the verified 2.0 m pitch, twelve
of them reserved and unoccupied. Station origins and hall dimensions were a
documented interface, so the workflow contract moves with them."
```

- [ ] **Step 8: Open the pull request**

```bash
git push -u origin <branch>
gh pr create --base <base> --title "Enlarge the Guild hall to fourteen bays" --body "..."
```

The body should state the measured pitch constraint and why an X-spaced arrangement was rejected, that twelve bays are furnished but unoccupied, that courtyard geometry is unchanged and only its placement moved, and that nothing is accepted. Do not merge without authorization.

---

## Self-review

**Spec coverage.** Hall envelope and roof → Task 1. Zones, bays and roster-order assignment → Tasks 1 and 2. Courtyard translation → Task 1. Contract changes table → Tasks 1, 3 and 5. Testing, including promoting the spike probe → Task 4. Stage 1 acceptance boundary → Task 5. The spec's *Residents* section and stage 2 are deliberately out of scope for this plan. The spec's *Deferred* section needs no task.

**Placeholder scan.** Step 3 of Task 5 describes a document by its required contents rather than supplying prose, because the numbers it must carry are produced by Step 1 of the same task and cannot be known while writing this plan. Every code step carries real code.

**Type consistency.** `BAYS` is defined in Task 2 Step 3 and consumed only there. `stations` is the existing Dictionary keyed by resident name, used consistently in Tasks 3 and 4. Station origins `[-3,0,0]` and `[-3,0,2]` appear identically in Task 1 Steps 2 and 6. The `DOORWAY` constant, corridor bounds and paved-landing position all shift by the same +1 m and agree across Task 1 Step 3.
