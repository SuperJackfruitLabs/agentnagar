# First Guild scene — numbered asset sheet and tracker

Proposed production baseline · created 2026-09-22 · [Asset catalogue](README.md) · [Starter collection](STARTER_COLLECTION.md) · [Guild cast](../../vision/GUILD_RESIDENTS.md) · [W1 scope](../../planning/ROADMAP.md#w1--walk-the-city-and-watch-the-guild-at-work)

## How many?

**60 uniquely numbered production deliverables** for the proposed first Guild scene:

| Category | IDs | Deliverables |
| --- | --- | ---: |
| Environment, architecture and props | GS-001–026 | 26 |
| Individual Guild appearances | GS-027–040 | 14 |
| Shared rig and material library | GS-041–042 | 2 |
| Reusable animation clips | GS-043–047 | 5 |
| Interface presentation packages | GS-048–057 | 10 |
| Lighting, ambience and integrated scene | GS-058–060 | 3 |
| **Total** | | **60** |

This is a bounded **proposed build list**, not a claim that precisely 60 meshes are universally required. Forty entries are environment/prop/character deliverables; twenty are shared production, animation, interface or scene deliverables. A rig, material library, assembly and UI state set are explicitly counted as packages. Child meshes, texture files, repeated instances and material/text variants are included within their parent package unless separately numbered. The two architectural assemblies reuse the numbered kit; they do not require remodelling it. Character clothing and integral accessories belong to each dressed appearance; no separate wearable inventory is included. Split a package into child tickets later if needed, without silently changing this baseline count.

**Scene assumption:** one compact courtyard, two shared work zones inside the reference workshop, with seven bays each, fourteen home frontages, one selected visual style, first-person visitor navigation, and a map/text alternative. The internal work-zone layout and draft dimensions are planning proposals. Fit this bounded scene to the documented W1 workshop and T1 Tree Square; preserve the workshop’s three sawtooth roof bays and east-facing entrance, and one central living shade tree. GS-015 counts two interior zone instances within that one hall, not two replacement landmark buildings. Home frontages occupy a proposed adjoining area requiring layout review. The river, library, transit and downtown remain outside this initial crop; do not render a contradictory district backdrop. Expanding the crop to show those landmarks requires explicit additional assets. Preserve each agent's longer-term facility assignments in the Guild brief; this scene does not build every facility. Instance counts below are layout targets, not quantities already placed. Water/bridges, furnished homes, vehicles, weather simulation, visible visitor avatar, spoken dialogue, crafting, inventory and trading are outside this baseline. A changed camera or approved layout can add/remove numbered entries explicitly.

The full W1 also needs live public-state export, identity, permissions, comment persistence/moderation, privacy and operational verification. These are **software/service dependencies outside the asset count**. Completing all 60 assets alone does not complete W1.

## Current snapshot

Updated 2026-09-23: **41/60 deliverables in progress and 1/60 blocked through the one-bay, shared-workshop, courtyard-kit, hall-expansion and full-cast pilots; 0/60 declared fully built, fully tested or reviewed and accepted against the complete production specifications.** The [Voxel work-bay pilot](../../../prototypes/voxel-work-bay/README.md) contains real editable source, GLBs and a local sample-data client. Its technical checks now cover all fourteen residents' shared rig, geometry and animation-data export parity; walking and seat-transition movement capture evidence (desk-cycle videos, live-preview review) remains Kai- and Lyra-only. Kai's and Lyra's robot appearances have user approval; this does not establish full-cast compatibility or production acceptance. The [shared workshop](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md) adds twelve partial environment/assembly entries and a courtyard crop. Its generic shade tree does not establish the mature jackfruit specification, and planter vegetation is not yet a separate shrub export. The [courtyard kit](../../../prototypes/voxel-work-bay/evidence/COURTYARD-KIT-VERIFICATION.md) adds the corner, junction, awning and railing modules and turns the courtyard into a closed public loop around a central planted island; GS-014 is Blocked because the hall and courtyard measure flush at Y=0, leaving no rise for a ramp until a raised entry exists. The [hall expansion](../../../prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md) enlarged the hall to **12 × 16 m**, widened the roof to six 4.0 m-wide bay instances, and reserved **fourteen bay anchors in two zones at a measured 2.0 m pitch**. The [full-cast milestone](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md) authored the remaining twelve Guild appearances (GS-027–029, 032–040) on the shared 16-bone rig, moving them from Not started to In progress alongside GS-030/031, and seated all fourteen residents in those bay anchors — **only Kai's and Lyra's appearances carry user approval; the other twelve do not.** A seated resident's chest motif — the cast's primary differentiator — is not visible from any hall camera position found, not only the overview's: each one's own terminal sits directly between the resident and any viewer while seated, which is every resident's normal resting state; name tags do the identifying at any distance while seated, and the motif is visible only once a resident stands and walks. The courtyard translated +1 m east to clear the wider hall; no courtyard geometry was re-authored. Remaining rows stay at their initial baseline.

Existing [thirty style studies](../../vision/style-studies/README.md) are the visual authority, together with their briefs, exact selected sheet revisions and review limitations. The [pinned style reference index](FIRST_GUILD_STYLE_REFERENCES.md) links them directly. **The humanoid experiment is excluded from this production plan and must not be used as a character, rig, proportion or animation reference.** Rakesh selected **02-voxel** for first production on 2026-09-22. Exact panels and character-specific designs still require review; the choice does not accept every reference sheet. No concept-art review is promoted into a built/tested asset status.

### Follow the documented styles

- Use the chosen style’s city perspectives for architecture, terrain, vegetation, scale relationships and silhouette; living-community panels for interiors, furniture and character appearance; creating/exploring panels for material close-ups and environmental treatment; interfaces/perspectives for map, signs and UI language. Select relevant panels, not an unrelated generic art reference.
- Record exact style ID, sheet/revision, panel and image/review links on every asset sheet. These links are pinned references, not claims that all source images have passed review or were visually inspected during this tracker-writing task. Inspect the actual selected panels before authoring.
- Derive rig topology and proportions from the chosen style’s characters. Styles include human-presenting, robotic, leaf-like and other representations; do not force a generic humanoid model or common cross-style rig onto them. Share a rig within a style only where its fourteen designed characters are compatible.
- City Agent A1 in the concept sheets is a recurring reference role, not an identified Guild member. Use its documented within-style design grammar without silently making it one of the fourteen or cloning it fourteen times. Individual Guild appearances still need a style-consistent design pass.
- Follow the [comparison contract](../../vision/style-studies/shared/CONSISTENCY-CONTRACT.md) where its landmarks, camera views, labels and semantic colors apply. Decorative palettes do not change control meanings. Example Ask controls in concept sheets do not grant anonymous visitors agent access.
- The numerical fit targets below are provisional blockout aids. Style-authentic proportions and landmark masses take priority; reconcile clearances and anchors in the blockout rather than altering the style to fit these draft numbers. Some styles may require sprite, shader or illustrative presentation rather than a conventional textured-mesh pipeline.
- Keep each finished scene visually coherent. A later style variant gets its own build/test/review row and evidence. Passing one style never marks another style complete. The baseline is **60 logical deliverables for one first style**, not an instruction to produce 1,800 variants across all thirty styles.


## Tracker rules

- **Build:** Not started → In progress → Built. Use Blocked when a named issue actually prevents progress. Built requires linked editable source/export or client-native artifact and an artifact revision.
- **Test:** Not run → Pass / Fail; use Stale when the tested artifact changes. Pass requires a test record naming artifact revision, client/tool version, device, exercised checks, results and evidence.
- **Review:** Pending → Accepted / Changes requested; use Stale when the reviewed artifact changes. Accepted requires a named reviewer, date, artifact revision and visual/content review evidence. Test pass and review acceptance are independent.
- **Attention:** retain issue IDs and a concrete next action. “Needs spec” means the sheet is a draft, not that a failed model exists. Clear an issue only with its resolution link. Add asset-specific issue IDs as failures are discovered.
- The Style column identifies the variant under test. Replace Unassigned with an existing style ID when authoring begins. For an additional style, add another row for the same GS ID with that style ID and separate evidence in the sheet. Report unique logical deliverables and completed style variants separately.
- Set owner and source/evidence links in the individual sheet when work starts. Never mark Built from a prompt, concept image or unverified export. A reference may be adopted only after it meets the asset's acceptance checks.
- On a revised artifact, preserve prior evidence with its revision, change Test/Review to Stale, and rerun affected checks. No default reviewer or acceptance is inferred. Update the snapshot date/counts when reporting progress.
- Keep GS IDs stable. Mark removed items Retired with reason; do not renumber later assets. New variants that require independent delivery get new IDs and a revised scope count. Counts are unique active deliverables, not instances.

## Shared attention register

| Issue | Open decision / action | Affected work | Who should resolve it |
| --- | --- | --- | --- |
| A01 | 02-voxel selected on 2026-09-22. Review the pilot silhouettes, palette and material treatment before scaling the cast. | All assets except that greybox work may begin with explicit placeholder treatment. | Product/design reviewer, unassigned |
| A02 | Validate draft metre scale, 2 m architectural grid, style-derived reference rig, anchors, first-person controls and final courtyard blockout. No numeric device budget is assumed. | Geometry, rig, animation and layout. | Scene/character technical owner, unassigned |
| A03 | Review fourteen public appearances/biographies, two shared workplaces, home labels and correct source-profile mapping. Proposed local labels are not a new ecosystem identity contract. | Cast, nameplates, assemblies, map/roster. | Product reviewer and Guild operator, unassigned |
| A04 | Agree public-state fields, freshness/expiry, decorative activity labelling, quiet-hours policy and registered comment/access behavior. Keep fixture previews labelled. | Screens, activity animation and interface. Live backend integration is separate. | Product and runtime/interface owners, unassigned |
| A05 | Choose authoring/export/client workflow and target devices; measure a representative scene before fixing download, memory, frame-time and detail budgets. | All scene-ready deliverables. | Technical owner, unassigned |
| A06 | Record each source's creator, provenance and usage rights, including derived art, characters, fonts and audio. Existing repository-wide rights are not assumed. | All delivery packages. | Asset owner/reviewer, unassigned |

No issue in this table invents an approval request. This document is the requested planning/tracking work; unresolved decisions are kept visible for subsequent authoring.

## Numbered tracker

Click an ID for its specification and evidence slots. Every row starts at the evidence-supported baseline.

| ID | Asset | Style | Build | Test | Review | Needs attention |
| --- | --- | --- | --- | --- | --- | --- |
| [GS-001](#gs-001) | Courtyard ground surface | 02-voxel | In progress | Not run | Pending | [Shared pilot evidence](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-002](#gs-002) | Straight path module | 02-voxel | In progress | Not run | Pending | [Shared pilot evidence](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-003](#gs-003) | Corner path module | 02-voxel | In progress | Not run | Pending | [Courtyard kit evidence](../../../prototypes/voxel-work-bay/evidence/COURTYARD-KIT-VERIFICATION.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-004](#gs-004) | Path junction module | 02-voxel | In progress | Not run | Pending | [Courtyard kit evidence](../../../prototypes/voxel-work-bay/evidence/COURTYARD-KIT-VERIFICATION.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-005](#gs-005) | Mature jackfruit tree | Unassigned | Not started | Not run | Pending | Needs spec: A01, A02, A05, A06 |
| [GS-006](#gs-006) | Low tropical shrub | Unassigned | Not started | Not run | Pending | Needs spec: A01, A02, A05, A06 |
| [GS-007](#gs-007) | Courtyard planter | 02-voxel | In progress | Not run | Pending | [Shared pilot evidence](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-008](#gs-008) | Floor and foundation module | 02-voxel | In progress | Not run | Pending | [Shared pilot evidence](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-009](#gs-009) | Solid wall module | 02-voxel | In progress | Not run | Pending | [Shared pilot evidence](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-010](#gs-010) | Doorway and door module | 02-voxel | In progress | Not run | Pending | [Shared pilot evidence](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-011](#gs-011) | Window wall module | 02-voxel | In progress | Not run | Pending | [Shared pilot evidence](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-012](#gs-012) | Roof module | 02-voxel | In progress | Not run | Pending | [Shared pilot evidence](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-013](#gs-013) | Entrance awning | 02-voxel | In progress | Not run | Pending | [Courtyard kit evidence](../../../prototypes/voxel-work-bay/evidence/COURTYARD-KIT-VERIFICATION.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-014](#gs-014) | Threshold ramp | 02-voxel | Blocked | Not run | Pending | GS-014-01: hall and courtyard are flush at Y=0, so there is no rise to ramp. [Measured evidence](../../../prototypes/voxel-work-bay/evidence/COURTYARD-KIT-VERIFICATION.md). Also A01, A02, A05, A06 |
| [GS-015](#gs-015) | Shared workshop assembly | 02-voxel | In progress | Not run | Pending | [Shared pilot evidence](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md); full acceptance pending: A01, A02, A03, A05, A06 |
| [GS-016](#gs-016) | Private room frontage assembly | Unassigned | Not started | Not run | Pending | Needs spec: A01, A02, A03, A05, A06 |
| [GS-017](#gs-017) | Courtyard edge railing | 02-voxel | In progress | Not run | Pending | [Courtyard kit evidence](../../../prototypes/voxel-work-bay/evidence/COURTYARD-KIT-VERIFICATION.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-018](#gs-018) | Work chair | 02-voxel | In progress | Not run | Pending | [Pilot evidence](../../../prototypes/voxel-work-bay/README.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-019](#gs-019) | Work desk | 02-voxel | In progress | Not run | Pending | [Pilot evidence](../../../prototypes/voxel-work-bay/README.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-020](#gs-020) | Shared workbench | 02-voxel | In progress | Not run | Pending | [Shared pilot evidence](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-021](#gs-021) | Project shelf | 02-voxel | In progress | Not run | Pending | [Shared pilot evidence](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-022](#gs-022) | Computer terminal assembly | 02-voxel | In progress | Not run | Pending | [Pilot evidence](../../../prototypes/voxel-work-bay/README.md); full acceptance pending: A01, A02, A04, A05, A06 |
| [GS-023](#gs-023) | Courtyard wayfinding sign | 02-voxel | In progress | Not run | Pending | [Shared pilot evidence](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-024](#gs-024) | Home and work nameplate | Unassigned | Not started | Not run | Pending | Needs spec: A01, A02, A03, A05, A06 |
| [GS-025](#gs-025) | Public work-board housing | Unassigned | Not started | Not run | Pending | Needs spec: A01, A02, A04, A05, A06 |
| [GS-026](#gs-026) | Field notebook | Unassigned | Not started | Not run | Pending | Needs spec: A01, A02, A05, A06 |
| [GS-027](#gs-027) | Onboarding Olivia | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A03, A05, A06 |
| [GS-028](#gs-028) | Super Chotu | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A03, A05, A06 |
| [GS-029](#gs-029) | Project Manager Pete | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A03, A05, A06 |
| [GS-030](#gs-030) | Coder Kai | 02-voxel | In progress | Not run | Pending | [Pilot evidence](../../../prototypes/voxel-work-bay/README.md); full acceptance pending: A01, A02, A03, A05, A06 |
| [GS-031](#gs-031) | Artistic Lyra | 02-voxel | In progress | Not run | Pending | [Pilot evidence](../../../prototypes/voxel-work-bay/README.md); full acceptance pending: A01, A02, A03, A05, A06 |
| [GS-032](#gs-032) | Research Ray | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A03, A05, A06 |
| [GS-033](#gs-033) | Writer Quill | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A03, A05, A06 |
| [GS-034](#gs-034) | Analyst Echo | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A03, A05, A06 |
| [GS-035](#gs-035) | Predictor Paul | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A03, A05, A06 |
| [GS-036](#gs-036) | Strategy Sam | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A03, A05, A06 |
| [GS-037](#gs-037) | Controller Casey | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A03, A05, A06 |
| [GS-038](#gs-038) | Optimizer Ollie | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A03, A05, A06 |
| [GS-039](#gs-039) | Threat Hunter Theo | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A03, A05, A06 |
| [GS-040](#gs-040) | Cleaner Cody | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A03, A05, A06 |
| [GS-041](#gs-041) | Shared style-specific character rig | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-042](#gs-042) | Scene material and palette library | 02-voxel | In progress | Not run | Pending | [Pilot evidence](../../../prototypes/voxel-work-bay/README.md); full acceptance pending: A01, A05, A06 |
| [GS-043](#gs-043) | Standing idle clip | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-044](#gs-044) | Walking clip | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-045](#gs-045) | Seated idle clip | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-046](#gs-046) | Seated typing clip | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A04, A05, A06 |
| [GS-047](#gs-047) | Look-and-attend clip | 02-voxel | In progress | Not run | Pending | [Full-cast evidence](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md); full acceptance pending: A01, A02, A05, A06 |
| [GS-048](#gs-048) | Courtyard map and text route view | Unassigned | Not started | Not run | Pending | Needs spec: A01, A03, A04, A05, A06 |
| [GS-049](#gs-049) | Guild roster and biography view | Unassigned | Not started | Not run | Pending | Needs spec: A01, A03, A04, A05, A06 |
| [GS-050](#gs-050) | Public work-state card | Unassigned | Not started | Not run | Pending | Needs spec: A01, A03, A04, A05, A06 |
| [GS-051](#gs-051) | Work-state badge set | Unassigned | Not started | Not run | Pending | Needs spec: A01, A03, A04, A05, A06 |
| [GS-052](#gs-052) | Fixture and freshness notice | Unassigned | Not started | Not run | Pending | Needs spec: A01, A03, A04, A05, A06 |
| [GS-053](#gs-053) | Navigation and focus cues | Unassigned | Not started | Not run | Pending | Needs spec: A01, A03, A04, A05, A06 |
| [GS-054](#gs-054) | Access and tier notice | Unassigned | Not started | Not run | Pending | Needs spec: A01, A03, A04, A05, A06 |
| [GS-055](#gs-055) | Sign-in presentation | Unassigned | Not started | Not run | Pending | Needs spec: A01, A03, A04, A05, A06 |
| [GS-056](#gs-056) | Pinned comment and report presentation | Unassigned | Not started | Not run | Pending | Needs spec: A01, A03, A04, A05, A06 |
| [GS-057](#gs-057) | Quiet-hours and recent-work view | Unassigned | Not started | Not run | Pending | Needs spec: A01, A03, A04, A05, A06 |
| [GS-058](#gs-058) | Daylight and sky setup | Unassigned | Not started | Not run | Pending | Needs spec: A01, A05, A06 |
| [GS-059](#gs-059) | Courtyard ambience loop | Unassigned | Not started | Not run | Pending | Needs spec: A01, A05, A06 |
| [GS-060](#gs-060) | Integrated Guild scene | 02-voxel | In progress | Not run | Pending | [Pilot evidence](../../../prototypes/voxel-work-bay/README.md); full acceptance pending: A01, A02, A03, A04, A05, A06 |

## Shared production and verification requirements

Every sheet inherits [shared characteristics](CHARACTERISTICS.md) and the [authoring template](ASSET_TEMPLATE.md). Dimensions below are proposed blockout targets, not measured or accepted assets. Fix style, units, orientation, pivot, connections and relevant rights before final authoring. N/A is appropriate for fields that do not apply (for example collision for an ambience loop).

**Geometry deliveries:** editable source, scene-ready export in the selected format, material dependencies, pivot/collision/anchor documentation, and close/distant/scene views. Test import, dimensions, connections, camera/navigation clearance and any intended animation. Initially all furniture and small goods are scenery; no physical ownership/storage/trade capability is implied.

**Character deliveries:** complete dressed appearance, shared rig binding, integral accessories and material assignments; front/side/back and fourteen-character lineup views. Test shared clips and anchors on each character. Operator review checks the public portrayal independently of technical import.

**Animation deliveries:** editable clip and scene-ready animation, skeleton revision, loop/root/blend/cancel settings, and playback evidence on all fourteen appearances. Authored movements express presentation only; they cannot establish a live runtime's work state.

**Interface deliveries:** editable design plus reusable client-native layout/state fixtures, readable text/icons, keyboard/focus and narrow-layout evidence. Fixture UI acceptance does not claim working authentication, live feeds or moderation. Record service integration evidence separately before W1 acceptance.

**Scene deliveries:** editable reproducible scene/preset and required dependencies, run instructions, labelled fixture data, device/tool versions, and captured measurements. Low-detail and text modes preserve identities and status semantics. All production formats and budgets remain A05 until decided.

For any asset, test Pass must cover its applicable checks here and its item-specific checks below. Review checks the selected visual reference, readability in context, provenance and intended behavior. Art quality does not substitute for runtime testing, and a technical pass does not imply art acceptance.

## Suggested work order

1. Resolve/record A01–A03 and the pilot client/device path in A05 sufficiently for a greybox: layout, rig fitting body, structural kit and one work bay using the chosen style’s character design. Start with simple placeholders and keep them labelled.
2. Validate one desk/chair/terminal with a candidate rig and five clips. Record this as pilot acceptance, measure representative runtime cost, then author the two assemblies and repeat the home/work stations. Full animation acceptance still waits for all fourteen appearances; pilot evidence does not need to wait for full-cast acceptance.
3. Develop and review all fourteen appearances against the same rig/material library. Prepare map, roster and labelled status fixtures alongside this work.
4. Integrate the 60 deliverables, check the full lineup and navigation, then measure target-device performance and review the scene.
5. Track live exporter, account and moderation work separately; do not promote fixture acceptance into W1 completion.

Dependency lists below describe accepted-production inputs, not a ban on parallel sketches or placeholder previews. Range notation includes both ends.

## Individual asset sheets

<a id="gs-001"></a>

### GS-001 — Courtyard ground surface

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · NAT-01 |
| Counted deliverable / scene quantity | One production entry; 1 composed ground. |
| Purpose and included content | A compact tropical courtyard with a continuous walkable public loop. Boundary scenery must make the edge understandable. |
| Scale, fit and anchors | Draft envelope 32 × 32 m; final footprint follows layout review. Ground pivot and navigation surface at grade. |
| Accepted-production dependencies | No other completed asset required; shared decisions above still apply. |
| Required test / review checks | Walk the entire public route without gaps, falls or an invisible exit; inspect distant and close surface tiling. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | 02-voxel city r004 and living r002; [shared reference record](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md#layout-and-movement) |
| Owner | Codex pilot authoring; production owner unassigned |
| Editable source / export / artifact revision | [Shared source](../../../prototypes/voxel-work-bay/source/shared-workshop.blend) · [manifest](../../../prototypes/voxel-work-bay/shared-workshop-manifest.json) · shared-workshop-r003; partial pilot scope |
| Test evidence / tested revision / date | [Shared verification](../../../prototypes/voxel-work-bay/evidence/SHARED-VERIFICATION.md), 2026-09-22; full production checks remain Not run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: partial shared-workshop prototype; exact production dimensions, variants and acceptance remain pending.  2026-09-22: hall enlarged to 12 × 16 m and the courtyard translated +1 m in X at shared-workshop-r003; this module's own geometry is unchanged, only its placement moved. See [hall expansion verification](../../../prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md). |

<a id="gs-002"></a>

### GS-002 — Straight path module

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · INF-02 |
| Counted deliverable / scene quantity | One production entry; 12–20 repeats. |
| Purpose and included content | One reusable paved pedestrian segment connecting work bays and homes. |
| Scale, fit and anchors | Draft 2 × 2 m tile; level connectors and ground-aligned pivot. |
| Accepted-production dependencies | No other completed asset required; shared decisions above still apply. |
| Required test / review checks | Adjacent repeats have no visible seam, collision step or navigation break. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | 02-voxel city r004 and living r002; [shared reference record](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md#layout-and-movement) |
| Owner | Codex pilot authoring; production owner unassigned |
| Editable source / export / artifact revision | [Shared source](../../../prototypes/voxel-work-bay/source/shared-workshop.blend) · [manifest](../../../prototypes/voxel-work-bay/shared-workshop-manifest.json) · shared-workshop-r003; partial pilot scope |
| Test evidence / tested revision / date | [Shared verification](../../../prototypes/voxel-work-bay/evidence/SHARED-VERIFICATION.md), 2026-09-22; full production checks remain Not run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: partial shared-workshop prototype; exact production dimensions, variants and acceptance remain pending.  2026-09-22: hall enlarged to 12 × 16 m and the courtyard translated +1 m in X at shared-workshop-r003; this module's own geometry is unchanged, only its placement moved. See [hall expansion verification](../../../prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md). |

<a id="gs-003"></a>

### GS-003 — Corner path module

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · INF-02 |
| Counted deliverable / scene quantity | One production entry; 4–8 repeats. |
| Purpose and included content | A quarter-turn compatible with the straight path. |
| Scale, fit and anchors | Same 2 m width and connector convention as GS-002. |
| Accepted-production dependencies | GS-002 |
| Required test / review checks | Walk and turn through inside and outside edges without snagging. Plus applicable shared verification above. |
| Next action / attention | Pilot module authored and technically checked. Needs user visual review against the pinned 02-voxel panels, then production dimensions and variants. A01, A02, A05 and A06 remain open. |
| Style / exact reference panels | 02-voxel city r004 and living r002; [courtyard kit record](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md#layout-and-movement) |
| Owner | Codex pilot authoring; production owner unassigned |
| Editable source / export / artifact revision | [Shared source](../../../prototypes/voxel-work-bay/source/shared-workshop.blend) · [manifest](../../../prototypes/voxel-work-bay/shared-workshop-manifest.json) · shared-workshop-r003; partial pilot scope |
| Test evidence / tested revision / date | [Courtyard kit verification](../../../prototypes/voxel-work-bay/evidence/COURTYARD-KIT-VERIFICATION.md), shared-workshop-r002, 2026-09-22; full production checks remain Not run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: `path_corner` added at pilot scope, 4 instances. Arms authored north and east; all four orientations come from `rotation_y`, so no orientation-specific mesh was exported. Production dimensions, variants and acceptance pending.  2026-09-22: hall enlarged to 12 × 16 m and the courtyard translated +1 m in X at shared-workshop-r003; this module's own geometry is unchanged, only its placement moved. See [hall expansion verification](../../../prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md). |

<a id="gs-004"></a>

### GS-004 — Path junction module

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · INF-02 |
| Counted deliverable / scene quantity | One production entry; 2–4 repeats. |
| Purpose and included content | A T junction connecting the public loop to workroom entries. |
| Scale, fit and anchors | Draft 6 × 6 m envelope assembled on the 2 m grid. |
| Accepted-production dependencies | GS-002 |
| Required test / review checks | All three approaches connect; signs and plants leave the junction clear. Plus applicable shared verification above. |
| Next action / attention | Pilot module authored and technically checked. Needs user visual review against the pinned 02-voxel panels, then production dimensions and variants. A01, A02, A05 and A06 remain open. |
| Style / exact reference panels | 02-voxel city r004 and living r002; [courtyard kit record](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md#layout-and-movement) |
| Owner | Codex pilot authoring; production owner unassigned |
| Editable source / export / artifact revision | [Shared source](../../../prototypes/voxel-work-bay/source/shared-workshop.blend) · [manifest](../../../prototypes/voxel-work-bay/shared-workshop-manifest.json) · shared-workshop-r003; partial pilot scope |
| Test evidence / tested revision / date | [Courtyard kit verification](../../../prototypes/voxel-work-bay/evidence/COURTYARD-KIT-VERIFICATION.md), shared-workshop-r002, 2026-09-22; full production checks remain Not run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: `path_t` added at pilot scope, 1 instance. Built as a 2 m kit tile on the shared grid rather than a single 6 m mesh; the drafted 6 × 6 m envelope is the composed footprint. One T is placed because the hall has exactly one courtyard entrance, which is a layout outcome rather than an unbuilt variant.  2026-09-22: hall enlarged to 12 × 16 m and the courtyard translated +1 m in X at shared-workshop-r003; this module's own geometry is unchanged, only its placement moved. See [hall expansion verification](../../../prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md). |

<a id="gs-005"></a>

### GS-005 — Mature jackfruit tree

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · NAT-04 |
| Counted deliverable / scene quantity | One production entry; 1 central tree. |
| Purpose and included content | One living central shade tree at T1, with jackfruit identity expressed only where compatible with the selected style; do not replace the tree with a fountain or monument. |
| Scale, fit and anchors | Draft 6 m high, 5 m canopy; trunk collision only where appropriate. |
| Accepted-production dependencies | No other completed asset required; shared decisions above still apply. |
| Required test / review checks | Canopy does not hide names, camera or work boards; trunk leaves a clear route. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-006"></a>

### GS-006 — Low tropical shrub

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · NAT-05 |
| Counted deliverable / scene quantity | One production entry; 6–10 repeats. |
| Purpose and included content | One low planting asset to soften courtyard edges. |
| Scale, fit and anchors | Draft 0.6 m high, 0.8 m footprint; not independently simulated. |
| Accepted-production dependencies | No other completed asset required; shared decisions above still apply. |
| Required test / review checks | Ground contact reads correctly; repetition is acceptable and no doorway is obscured. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-007"></a>

### GS-007 — Courtyard planter

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · NAT-07 (container component) |
| Counted deliverable / scene quantity | One production entry; 4–6 repeats. |
| Purpose and included content | One low rectangular container for the shrub, kept distinct from vegetation for reuse. |
| Scale, fit and anchors | Draft 1.2 × 0.6 × 0.45 m; ground pivot, shrub mount. |
| Accepted-production dependencies | GS-006 |
| Required test / review checks | Shrub fits; planter collision matches its footprint and leaves the route usable. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | 02-voxel city r004 and living r002; [shared reference record](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md#layout-and-movement) |
| Owner | Codex pilot authoring; production owner unassigned |
| Editable source / export / artifact revision | [Shared source](../../../prototypes/voxel-work-bay/source/shared-workshop.blend) · [manifest](../../../prototypes/voxel-work-bay/shared-workshop-manifest.json) · shared-workshop-r003; partial pilot scope |
| Test evidence / tested revision / date | [Shared verification](../../../prototypes/voxel-work-bay/evidence/SHARED-VERIFICATION.md), 2026-09-22; full production checks remain Not run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: partial shared-workshop prototype; exact production dimensions, variants and acceptance remain pending. Pilot vegetation is integrated; separate shrub/container exports remain pending.  2026-09-22: hall enlarged to 12 × 16 m and the courtyard translated +1 m in X at shared-workshop-r003; this module's own geometry is unchanged, only its placement moved. See [hall expansion verification](../../../prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md). |

<a id="gs-008"></a>

### GS-008 — Floor and foundation module

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · ARC-01 |
| Counted deliverable / scene quantity | One production entry; As required by two assemblies. |
| Purpose and included content | One flat foundation/floor slab shared by workrooms and homes. |
| Scale, fit and anchors | Draft 2 × 2 m, 0.2 m thick; top surface defines floor level. |
| Accepted-production dependencies | No other completed asset required; shared decisions above still apply. |
| Required test / review checks | Repeat without cracks; furniture rests on the surface; transitions meet ramp cleanly. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | 02-voxel city r004 and living r002; [shared reference record](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md#layout-and-movement) |
| Owner | Codex pilot authoring; production owner unassigned |
| Editable source / export / artifact revision | [Shared source](../../../prototypes/voxel-work-bay/source/shared-workshop.blend) · [manifest](../../../prototypes/voxel-work-bay/shared-workshop-manifest.json) · shared-workshop-r003; partial pilot scope |
| Test evidence / tested revision / date | [Shared verification](../../../prototypes/voxel-work-bay/evidence/SHARED-VERIFICATION.md), 2026-09-22; full production checks remain Not run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: partial shared-workshop prototype; exact production dimensions, variants and acceptance remain pending.  2026-09-22: hall enlarged to 12 × 16 m and the courtyard translated +1 m in X at shared-workshop-r003; this module's own geometry is unchanged, only its placement moved. See [hall expansion verification](../../../prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md). |

<a id="gs-009"></a>

### GS-009 — Solid wall module

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · ARC-02 |
| Counted deliverable / scene quantity | One production entry; As required by two assemblies. |
| Purpose and included content | One opaque wall panel with a consistent inside and outside treatment. |
| Scale, fit and anchors | Draft 2 m wide × 3 m high; 0.2 m thick; shared corner join. |
| Accepted-production dependencies | GS-008 |
| Required test / review checks | Straight and corner joins close; camera does not expose unintended backfaces. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | 02-voxel city r004 and living r002; [shared reference record](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md#layout-and-movement) |
| Owner | Codex pilot authoring; production owner unassigned |
| Editable source / export / artifact revision | [Shared source](../../../prototypes/voxel-work-bay/source/shared-workshop.blend) · [manifest](../../../prototypes/voxel-work-bay/shared-workshop-manifest.json) · shared-workshop-r003; partial pilot scope |
| Test evidence / tested revision / date | [Shared verification](../../../prototypes/voxel-work-bay/evidence/SHARED-VERIFICATION.md), 2026-09-22; full production checks remain Not run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: partial shared-workshop prototype; exact production dimensions, variants and acceptance remain pending.  2026-09-22: hall enlarged to 12 × 16 m and the courtyard translated +1 m in X at shared-workshop-r003; this module's own geometry is unchanged, only its placement moved. See [hall expansion verification](../../../prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md). |

<a id="gs-010"></a>

### GS-010 — Doorway and door module

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · ARC-03 |
| Counted deliverable / scene quantity | One production entry; 14 homes plus workroom entries. |
| Purpose and included content | One authored assembly containing frame and separately pivoted leaf; closed home door and open public passage variants. |
| Scale, fit and anchors | Draft 1.2 m clear opening in a 2 × 3 m panel; hinge and threshold defined. |
| Accepted-production dependencies | GS-008, GS-009 |
| Required test / review checks | Open state clears the route; closed home has no implied public access; animation is deferred unless needed. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | 02-voxel city r004 and living r002; [shared reference record](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md#layout-and-movement) |
| Owner | Codex pilot authoring; production owner unassigned |
| Editable source / export / artifact revision | [Shared source](../../../prototypes/voxel-work-bay/source/shared-workshop.blend) · [manifest](../../../prototypes/voxel-work-bay/shared-workshop-manifest.json) · shared-workshop-r003; partial pilot scope |
| Test evidence / tested revision / date | [Shared verification](../../../prototypes/voxel-work-bay/evidence/SHARED-VERIFICATION.md), 2026-09-22; full production checks remain Not run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: partial shared-workshop prototype; exact production dimensions, variants and acceptance remain pending. The pilot has an open frame without a door leaf.  2026-09-22: hall enlarged to 12 × 16 m and the courtyard translated +1 m in X at shared-workshop-r003; this module's own geometry is unchanged, only its placement moved. See [hall expansion verification](../../../prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md). |

<a id="gs-011"></a>

### GS-011 — Window wall module

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · ARC-04 |
| Counted deliverable / scene quantity | One production entry; As required by layout. |
| Purpose and included content | One framed window integrated into the common wall grid. |
| Scale, fit and anchors | Draft 2 × 3 m wall envelope; sill and glass policy specified during style selection. |
| Accepted-production dependencies | GS-009 |
| Required test / review checks | Interior and exterior views render correctly; transparent surfaces do not expose private contents. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | 02-voxel city r004 and living r002; [shared reference record](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md#layout-and-movement) |
| Owner | Codex pilot authoring; production owner unassigned |
| Editable source / export / artifact revision | [Shared source](../../../prototypes/voxel-work-bay/source/shared-workshop.blend) · [manifest](../../../prototypes/voxel-work-bay/shared-workshop-manifest.json) · shared-workshop-r003; partial pilot scope |
| Test evidence / tested revision / date | [Shared verification](../../../prototypes/voxel-work-bay/evidence/SHARED-VERIFICATION.md), 2026-09-22; full production checks remain Not run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: partial shared-workshop prototype; exact production dimensions, variants and acceptance remain pending.  2026-09-22: hall enlarged to 12 × 16 m and the courtyard translated +1 m in X at shared-workshop-r003; this module's own geometry is unchanged, only its placement moved. See [hall expansion verification](../../../prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md). |

<a id="gs-012"></a>

### GS-012 — Roof module

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · ARC-07 |
| Counted deliverable / scene quantity | One production entry; As required by layout. |
| Purpose and included content | One repeatable sawtooth roof bay with end-cap treatment; the W1 landmark retains three bays. Translate material and ornament through the selected style. |
| Scale, fit and anchors | Draft 2 m bay; pitch and overhang set with style; no roof traversal. |
| Accepted-production dependencies | GS-009 |
| Required test / review checks | No gaps or rain-of-light artifacts at joins; overhang does not obscure public boards. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | 02-voxel city r004 and living r002; [shared reference record](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md#layout-and-movement) |
| Owner | Codex pilot authoring; production owner unassigned |
| Editable source / export / artifact revision | [Shared source](../../../prototypes/voxel-work-bay/source/shared-workshop.blend) · [manifest](../../../prototypes/voxel-work-bay/shared-workshop-manifest.json) · shared-workshop-r003; partial pilot scope |
| Test evidence / tested revision / date | [Hall expansion verification](../../../prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md), shared-workshop-r003, 2026-09-22; full production checks remain Not run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: partial shared-workshop prototype; exact production dimensions, variants and acceptance remain pending. 2026-09-22: bay width widened from 10/3 m to **4.0 m** at shared-workshop-r003; three bays now export as **6 instances** (two 8 m-deep modules per bay) instead of 3. `roof.glb` is the only pre-existing exported module whose own geometry changed in this milestone; every other module's own geometry is unchanged. Build stays In progress, Test stays Not run, Review stays Pending. |

<a id="gs-013"></a>

### GS-013 — Entrance awning

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · ARC-08 |
| Counted deliverable / scene quantity | One production entry; 2 workroom entrances. |
| Purpose and included content | One shaded entrance canopy mounted independently from signage. |
| Scale, fit and anchors | Draft 4 × 2 m projection; mounting height at least 2.4 m in the draft blockout. |
| Accepted-production dependencies | GS-009 |
| Required test / review checks | No head/camera collision; the entrance remains identifiable from the courtyard. Plus applicable shared verification above. |
| Next action / attention | Pilot module authored and technically checked. Needs user visual review against the pinned 02-voxel panels, then production dimensions and variants. A01, A02, A05 and A06 remain open. |
| Style / exact reference panels | 02-voxel city r004 and living r002; [courtyard kit record](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md#layout-and-movement) |
| Owner | Codex pilot authoring; production owner unassigned |
| Editable source / export / artifact revision | [Shared source](../../../prototypes/voxel-work-bay/source/shared-workshop.blend) · [manifest](../../../prototypes/voxel-work-bay/shared-workshop-manifest.json) · shared-workshop-r003; partial pilot scope |
| Test evidence / tested revision / date | [Courtyard kit verification](../../../prototypes/voxel-work-bay/evidence/COURTYARD-KIT-VERIFICATION.md), shared-workshop-r002, 2026-09-22; full production checks remain Not run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: `awning` added at pilot scope, 1 instance, cantilevered 2 m over 4 m of frontage with no post in the walkway. Underside stays at or above 2.44 m and the collision slab at 2.45 m, asserted clear of the 2.19 m doorway corridor. A first bracket iteration hung as low as 2.03 m and was replaced after first-person inspection.  2026-09-22: hall enlarged to 12 × 16 m and the courtyard translated +1 m in X at shared-workshop-r003; this module's own geometry is unchanged, only its placement moved. See [hall expansion verification](../../../prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md). |

<a id="gs-014"></a>

### GS-014 — Threshold ramp

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · ARC-05 |
| Counted deliverable / scene quantity | One production entry; At each raised public entry. |
| Purpose and included content | One ramp providing step-free connection between path and raised floor. |
| Scale, fit and anchors | Draft 2 m wide, 2.4 m long for 0.2 m rise; adjust to actual floor height. |
| Accepted-production dependencies | GS-002, GS-008 |
| Required test / review checks | Movement crosses both ends cleanly; walking and text/map entry routes reach the same destination. Plus applicable shared verification above. |
| Next action / attention | Blocked by GS-014-01. Re-specify against a real rise when a raised public entry exists, for example the GS-016 home frontages. Do not author zero-rise geometry to clear the row. |
| Style / exact reference panels | 02-voxel city r004 and living r002; [courtyard kit record](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md#layout-and-movement) |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable; blocked before authoring |
| Test evidence / tested revision / date | None. The blocking measurement is recorded in [courtyard kit verification](../../../prototypes/voxel-work-bay/evidence/COURTYARD-KIT-VERIFICATION.md), 2026-09-22 |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: GS-014-01 opened. Measured from the actual exports, the hall floor and the courtyard path both top out at Y=0, so the drafted 0.2 m rise does not exist and no ramp geometry is meaningful. Raising the hall to match the draft would move both station origins, every collision proxy and the door-corridor clearance, disturbing the approved PR17 pilot, so it was rejected as out of scope for an environment milestone. `CourtyardKit.test_hall_and_courtyard_remain_flush` asserts the zero rise so this reason cannot drift out of date silently. |

<a id="gs-015"></a>

### GS-015 — Shared workshop assembly

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · BLD-02 |
| Counted deliverable / scene quantity | One production entry; 2 interior work zones in one W1 hall. |
| Purpose and included content | A reusable interior work-zone assembly using GS-008–014; two zones hold seven bays each inside the single reference W1 workshop. The outer hall follows the concept art’s mass, three sawtooth roof bays and east-facing entrance. This consolidates workplaces for scene planning without replacing long-term facility assignments. |
| Scale, fit and anchors | Draft 12 × 8 m per internal zone; seven seated stations, public aisle and exit. Resize after fitting both zones to the style’s W1 hall. |
| Accepted-production dependencies | GS-008, GS-009, GS-010, GS-011, GS-012, GS-013, GS-014 |
| Required test / review checks | All seven characters and their boards can be seen without entering their desk space; source parts remain reusable. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A03, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | 02-voxel city r004 and living r002; [shared reference record](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md#layout-and-movement) |
| Owner | Codex pilot authoring; production owner unassigned |
| Editable source / export / artifact revision | [Shared source](../../../prototypes/voxel-work-bay/source/shared-workshop.blend) · [manifest](../../../prototypes/voxel-work-bay/shared-workshop-manifest.json) · shared-workshop-r003; partial pilot scope |
| Test evidence / tested revision / date | [Hall expansion verification](../../../prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md), shared-workshop-r003, 2026-09-22; full production checks remain Not run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: partial shared-workshop prototype; exact production dimensions, variants and acceptance remain pending. 2026-09-22: hall enlarged to 12 × 16 m at shared-workshop-r003; **both zones and all fourteen bay anchors now exist** (west zone `x=-3`, east zone `x=+3`, seven bays each along Z at a measured 2.0 m pitch). Kai and Lyra occupy two anchors; **the other twelve are furnished but unoccupied**, reserved for the rest of the Guild cast in a later stage. Consolidating fourteen residents into this one hall is a W1 scene-planning simplification and does not replace the long-term facility assignments in `GUILD_RESIDENTS.md`. Stays In progress; Test stays Not run; Review stays Pending. |

<a id="gs-016"></a>

### GS-016 — Private room frontage assembly

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · BLD-01 |
| Counted deliverable / scene quantity | One production entry; 14 repeats. |
| Purpose and included content | One modest home frontage/room shell assembled from the same kit; unique nameplates supply addresses. Furnished private interiors are deferred. |
| Scale, fit and anchors | Draft 4 × 4 m footprint per room; closed doorway and nameplate anchor. |
| Accepted-production dependencies | GS-008, GS-009, GS-010, GS-011, GS-012, GS-024 |
| Required test / review checks | Fourteen distinct home addresses resolve to the correct characters; repeated shell has no duplicate identity. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A03, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-017"></a>

### GS-017 — Courtyard edge railing

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · ARC-07 |
| Counted deliverable / scene quantity | One production entry; Only along any exposed edge. |
| Purpose and included content | One repeated protective edge panel; omit via recorded scope change if the approved scene is entirely flat and enclosed. |
| Scale, fit and anchors | Draft 2 m long × 1.1 m high; continuous collision at joins. |
| Accepted-production dependencies | GS-008 |
| Required test / review checks | No pass-through or trapping at ends; railings do not interrupt a public route. Plus applicable shared verification above. |
| Next action / attention | Pilot module authored and technically checked. Needs user visual review against the pinned 02-voxel panels, then production dimensions and variants. A01, A02, A05 and A06 remain open. |
| Style / exact reference panels | 02-voxel city r004 and living r002; [courtyard kit record](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md#layout-and-movement) |
| Owner | Codex pilot authoring; production owner unassigned |
| Editable source / export / artifact revision | [Shared source](../../../prototypes/voxel-work-bay/source/shared-workshop.blend) · [manifest](../../../prototypes/voxel-work-bay/shared-workshop-manifest.json) · shared-workshop-r003; partial pilot scope |
| Test evidence / tested revision / date | [Courtyard kit verification](../../../prototypes/voxel-work-bay/evidence/COURTYARD-KIT-VERIFICATION.md), shared-workshop-r002, 2026-09-22; full production checks remain Not run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: `railing` added at pilot scope, 10 instances on the north, east and south courtyard boundary, one continuous 2 × 1.1 × 0.14 m collision proxy per panel so joins cannot be squeezed through. Scope reinterpreted from raised-edge fall protection, which this flat crop has none of, to the boundary legibility GS-001 requires.  2026-09-22: hall enlarged to 12 × 16 m and the courtyard translated +1 m in X at shared-workshop-r003; this module's own geometry is unchanged, only its placement moved. See [hall expansion verification](../../../prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md). |

<a id="gs-018"></a>

### GS-018 — Work chair

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · FUR-01 |
| Counted deliverable / scene quantity | One production entry; 14 repeats. |
| Purpose and included content | One shared seated-work chair with a readable silhouette. |
| Scale, fit and anchors | Draft 0.55 × 0.55 m footprint, seat height 0.45 m; seat and approach anchors. |
| Accepted-production dependencies | GS-041 |
| Required test / review checks | All character outfits fit the seat; hands can reach the desk and exit pose is clear. Plus applicable shared verification above. |
| Next action / attention | Review the linked pilot and resolve the remaining attention items for full production; extend compatibility beyond Kai before final acceptance. |
| Style / exact reference panels | 02-voxel; [pilot reference record](../../../prototypes/voxel-work-bay/README.md#visual-references-and-provenance): living r002 WORKSHOP and CONVERSATION panels, with linked image/review; new Kai design pending review |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Pilot verification](../../../prototypes/voxel-work-bay/evidence/VERIFICATION.md), 2026-09-22; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-019"></a>

### GS-019 — Work desk

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · FUR-03 |
| Counted deliverable / scene quantity | One production entry; 14 repeats. |
| Purpose and included content | One reusable desk for a terminal, notebook and public-state display. |
| Scale, fit and anchors | Draft 1.4 × 0.7 × 0.75 m; chair, terminal and notebook anchors. |
| Accepted-production dependencies | GS-018 |
| Required test / review checks | Knees, chair and terminal fit together without clipping; surface props stay supported. Plus applicable shared verification above. |
| Next action / attention | Review the linked pilot and resolve the remaining attention items for full production; extend compatibility beyond Kai before final acceptance. |
| Style / exact reference panels | 02-voxel; [pilot reference record](../../../prototypes/voxel-work-bay/README.md#visual-references-and-provenance): living r002 WORKSHOP and CONVERSATION panels, with linked image/review; new Kai design pending review |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Pilot verification](../../../prototypes/voxel-work-bay/evidence/VERIFICATION.md), 2026-09-22; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-020"></a>

### GS-020 — Shared workbench

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · FUR-04 |
| Counted deliverable / scene quantity | One production entry; 1 repeat. |
| Purpose and included content | A communal maker bench that conveys workshop purpose; no crafting implementation implied. |
| Scale, fit and anchors | Draft 2 × 0.8 × 0.9 m; ground pivot and display surface. |
| Accepted-production dependencies | No other completed asset required; shared decisions above still apply. |
| Required test / review checks | Workbench is readable scenery and leaves the viewing aisle clear. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | 02-voxel city r004 and living r002; [shared reference record](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md#layout-and-movement) |
| Owner | Codex pilot authoring; production owner unassigned |
| Editable source / export / artifact revision | [Shared source](../../../prototypes/voxel-work-bay/source/shared-workshop.blend) · [manifest](../../../prototypes/voxel-work-bay/shared-workshop-manifest.json) · shared-workshop-r003; partial pilot scope |
| Test evidence / tested revision / date | [Shared verification](../../../prototypes/voxel-work-bay/evidence/SHARED-VERIFICATION.md), 2026-09-22; full production checks remain Not run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: partial shared-workshop prototype; exact production dimensions, variants and acceptance remain pending.  2026-09-22: bench relocated from `(±2,0,3.1)` to `(±1,0,7.1)` at shared-workshop-r003 to suit the enlarged hall's new walls; this module's own geometry is unchanged, only its placement moved. See [hall expansion verification](../../../prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md). |

<a id="gs-021"></a>

### GS-021 — Project shelf

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · FUR-06 |
| Counted deliverable / scene quantity | One production entry; 2–4 repeats. |
| Purpose and included content | One open shelf for approved display props, initially scenery with no storage simulation. |
| Scale, fit and anchors | Draft 1.2 × 0.4 × 1.8 m; shelf support anchors. |
| Accepted-production dependencies | GS-026 |
| Required test / review checks | No floating notebook props; shelves do not accidentally present private content. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | 02-voxel city r004 and living r002; [shared reference record](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md#layout-and-movement) |
| Owner | Codex pilot authoring; production owner unassigned |
| Editable source / export / artifact revision | [Shared source](../../../prototypes/voxel-work-bay/source/shared-workshop.blend) · [manifest](../../../prototypes/voxel-work-bay/shared-workshop-manifest.json) · shared-workshop-r003; partial pilot scope |
| Test evidence / tested revision / date | [Shared verification](../../../prototypes/voxel-work-bay/evidence/SHARED-VERIFICATION.md), 2026-09-22; full production checks remain Not run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: partial shared-workshop prototype; exact production dimensions, variants and acceptance remain pending.  2026-09-22: shelf relocated from `(±2,0,-3.55)` to `(±1,0,-7.55)` at shared-workshop-r003 to suit the enlarged hall's new walls; this module's own geometry is unchanged, only its placement moved. See [hall expansion verification](../../../prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md). |

<a id="gs-022"></a>

### GS-022 — Computer terminal assembly

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · TOOL-04 |
| Counted deliverable / scene quantity | One production entry; 14 repeats. |
| Purpose and included content | One terminal package comprising screen, keyboard and stand; display uses approved or labelled fixture content only. |
| Scale, fit and anchors | Draft screen width 0.5 m; desk pivot, screen plane and keyboard/hand anchors. |
| Accepted-production dependencies | GS-019 |
| Required test / review checks | Screen remains readable in inspection view; no private session or raw desktop capture is used. Plus applicable shared verification above. |
| Next action / attention | Review the linked pilot and resolve the remaining attention items for full production; extend compatibility beyond Kai before final acceptance. |
| Style / exact reference panels | 02-voxel; [pilot reference record](../../../prototypes/voxel-work-bay/README.md#visual-references-and-provenance): living r002 WORKSHOP and CONVERSATION panels, with linked image/review; new Kai design pending review |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Pilot verification](../../../prototypes/voxel-work-bay/evidence/VERIFICATION.md), 2026-09-22; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-023"></a>

### GS-023 — Courtyard wayfinding sign

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · INFO-01 |
| Counted deliverable / scene quantity | One production entry; 3–4 repeats. |
| Purpose and included content | One directional sign structure with editable destination labels. |
| Scale, fit and anchors | Draft 1.8 m tall; label plane faces approach; text stored separately from the mesh. |
| Accepted-production dependencies | No other completed asset required; shared decisions above still apply. |
| Required test / review checks | Every sign resolves to the same destination as map/text routes; labels survive distance and narrow layouts. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | 02-voxel city r004 and living r002; [shared reference record](../../../prototypes/voxel-work-bay/SHARED_WORKSHOP.md#layout-and-movement) |
| Owner | Codex pilot authoring; production owner unassigned |
| Editable source / export / artifact revision | [Shared source](../../../prototypes/voxel-work-bay/source/shared-workshop.blend) · [manifest](../../../prototypes/voxel-work-bay/shared-workshop-manifest.json) · shared-workshop-r003; partial pilot scope |
| Test evidence / tested revision / date | [Shared verification](../../../prototypes/voxel-work-bay/evidence/SHARED-VERIFICATION.md), 2026-09-22; full production checks remain Not run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: partial shared-workshop prototype; exact production dimensions, variants and acceptance remain pending.  2026-09-22: hall enlarged to 12 × 16 m and the courtyard translated +1 m in X at shared-workshop-r003; this module's own geometry is unchanged, only its placement moved. See [hall expansion verification](../../../prototypes/voxel-work-bay/evidence/HALL-EXPANSION-VERIFICATION.md). |

<a id="gs-024"></a>

### GS-024 — Home and work nameplate

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · INFO-01 |
| Counted deliverable / scene quantity | One production entry; 28 labelled repeats. |
| Purpose and included content | One plate model with fourteen text variants used once at home and once at work; variants are not fourteen new meshes. |
| Scale, fit and anchors | Draft 0.45 × 0.18 m; wall mount and editable text area. |
| Accepted-production dependencies | No other completed asset required; shared decisions above still apply. |
| Required test / review checks | Correct spelling/profile mapping at all 28 positions; readable close view and text equivalent. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A03, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-025"></a>

### GS-025 — Public work-board housing

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · INFO-03 |
| Counted deliverable / scene quantity | One production entry; 14 repeats. |
| Purpose and included content | One physical display frame for each agent’s public work card; character identity survives absent or stale runtime data. |
| Scale, fit and anchors | Draft 0.8 × 0.6 m; wall/desk mount and unobstructed viewing position. |
| Accepted-production dependencies | GS-050, GS-051, GS-052 |
| Required test / review checks | Card fits without clipping; fixture/offline/stale notices remain visible from inspection view. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A04, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-026"></a>

### GS-026 — Field notebook

| Field | Specification |
| --- | --- |
| Family / catalogue link | Environment and props · OBJ-02 |
| Counted deliverable / scene quantity | One production entry; 14 desk copies; optional hand copies. |
| Purpose and included content | One notebook mesh with cover/material variants; approved decorative pages only. No inventory or editing in this slice. |
| Scale, fit and anchors | Draft 0.15 × 0.21 × 0.02 m; spine pivot, desk contact and optional grip anchor. |
| Accepted-production dependencies | No other completed asset required; shared decisions above still apply. |
| Required test / review checks | Closed/open presentation, if authored, stays supported; no actual private agent notes appear. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A02, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-027"></a>

### GS-027 — Onboarding Olivia

| Field | Specification |
| --- | --- |
| Family / catalogue link | Guild characters · RES-02 / GR01 |
| Counted deliverable / scene quantity | One production entry; 1 character. |
| Purpose and included content | Welcome guide; source profile `onboarding-olivia`. Sunhat and route-card motif. Deliver one complete dressed appearance including its integral accessories; separate portable versions are deferred. Home `guild-home-01`, work bay `guild-work-01` are proposed local scene labels, not accepted cross-product IDs. |
| Scale, fit and anchors | Style-derived body envelope and topology; ground pivot and appropriate name/seat/work anchors. Proportions follow the selected concept art; individual Guild designs await review. |
| Accepted-production dependencies | GS-041, GS-042, GS-043, GS-044, GS-045, GS-046, GS-047 |
| Required test / review checks | Recognizable in a fourteen-character lineup without relying only on color; operator approves public portrayal; shared idle/walk/seated clips show no severe clipping. Correct home/work/profile association. Plus applicable shared verification above. |
| Next action / attention | Operator review of the appearance and shared-rig movement before acceptance; resolve applicable A01, A02, A03, A05, A06. |
| Style / exact reference panels | 02-voxel; see [full-cast reference record](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md#the-fourteen-in-roster-order). Mint accent; folded route-map quilt chest motif (crossing cobalt/orange stepped diagonals on a paper ground with a mint location pip). New appearance, not yet reviewed. |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: authored on the shared 16-bone rig — mint accent, route-map-quilt chest motif. Operator review pending. |

<a id="gs-028"></a>

### GS-028 — Super Chotu

| Field | Specification |
| --- | --- |
| Family / catalogue link | Guild characters · RES-02 / GR02 |
| Counted deliverable / scene quantity | One production entry; 1 character. |
| Purpose and included content | Founding-lab host; source profile `super-chotu`. Project-patch jacket and notebook motif. Deliver one complete dressed appearance including its integral accessories; separate portable versions are deferred. Home `guild-home-02`, work bay `guild-work-02` are proposed local scene labels, not accepted cross-product IDs. |
| Scale, fit and anchors | Style-derived body envelope and topology; ground pivot and appropriate name/seat/work anchors. Proportions follow the selected concept art; individual Guild designs await review. |
| Accepted-production dependencies | GS-041, GS-042, GS-043, GS-044, GS-045, GS-046, GS-047 |
| Required test / review checks | Recognizable in a fourteen-character lineup without relying only on color; operator approves public portrayal; shared idle/walk/seated clips show no severe clipping. Correct home/work/profile association. Plus applicable shared verification above. |
| Next action / attention | Operator review of the appearance and shared-rig movement before acceptance; resolve applicable A01, A02, A03, A05, A06. |
| Style / exact reference panels | 02-voxel; see [full-cast reference record](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md#the-fourteen-in-roster-order). Orange accent; shallow display-shelf chest motif with three miniature prototypes (steel/cobalt/orange) on an ink shadow-box back. New appearance, not yet reviewed. |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: authored on the shared 16-bone rig — orange accent, prototype-shelf chest motif (reworked mid-task for value contrast; see full-cast evidence). Operator review pending. |

<a id="gs-029"></a>

### GS-029 — Project Manager Pete

| Field | Specification |
| --- | --- |
| Family / catalogue link | Guild characters · RES-02 / GR03 |
| Counted deliverable / scene quantity | One production entry; 1 character. |
| Purpose and included content | Project coordinator; source profile `project-manager-pete`. Rolled-plan and wooden-tile motifs. Deliver one complete dressed appearance including its integral accessories; separate portable versions are deferred. Home `guild-home-03`, work bay `guild-work-03` are proposed local scene labels, not accepted cross-product IDs. |
| Scale, fit and anchors | Style-derived body envelope and topology; ground pivot and appropriate name/seat/work anchors. Proportions follow the selected concept art; individual Guild designs await review. |
| Accepted-production dependencies | GS-041, GS-042, GS-043, GS-044, GS-045, GS-046, GS-047 |
| Required test / review checks | Recognizable in a fourteen-character lineup without relying only on color; operator approves public portrayal; shared idle/walk/seated clips show no severe clipping. Correct home/work/profile association. Plus applicable shared verification above. |
| Next action / attention | Operator review of the appearance and shared-rig movement before acceptance; resolve applicable A01, A02, A03, A05, A06. |
| Style / exact reference panels | 02-voxel; see [full-cast reference record](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md#the-fourteen-in-roster-order). Navy accent; movable planning-card grid chest motif (navy board, five paper cards, one offset as just-moved). New appearance, not yet reviewed. |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: authored on the shared 16-bone rig — navy accent, planning-card-grid chest motif. Operator review pending. |

<a id="gs-030"></a>

### GS-030 — Coder Kai

| Field | Specification |
| --- | --- |
| Family / catalogue link | Guild characters · RES-02 / GR04 |
| Counted deliverable / scene quantity | One production entry; 1 character. |
| Purpose and included content | Workshop engineer; source profile `coder-kai`. Tool apron and mechanism motif. Deliver one complete dressed appearance including its integral accessories; separate portable versions are deferred. Home `guild-home-04`, work bay `guild-work-04` are proposed local scene labels, not accepted cross-product IDs. |
| Scale, fit and anchors | Style-derived body envelope and topology; ground pivot and appropriate name/seat/work anchors. Proportions follow the selected concept art; individual Guild designs await review. |
| Accepted-production dependencies | GS-041, GS-042, GS-043, GS-044, GS-045, GS-046, GS-047 |
| Required test / review checks | Recognizable in a fourteen-character lineup without relying only on color; operator approves public portrayal; shared idle/walk/seated clips show no severe clipping. Correct home/work/profile association. Plus applicable shared verification above. |
| Next action / attention | Review the linked pilot and resolve the remaining attention items for full production; extend compatibility beyond Kai before final acceptance. |
| Style / exact reference panels | 02-voxel; [pilot reference record](../../../prototypes/voxel-work-bay/README.md#visual-references-and-provenance): living r002 WORKSHOP and CONVERSATION panels, with linked image/review; new Kai design pending review |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Pilot verification](../../../prototypes/voxel-work-bay/evidence/VERIFICATION.md), 2026-09-22; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | User approved Kai robot appearance on 2026-09-22 (pilot-r002-robot); this does not accept the movement extension or full production deliverable. |
| Asset-specific issues / change history | 2026-09-22: user confirmed robotic agents; human-presenting pilot superseded by white-shell Kai with green screen expression, mechanical limbs and tool apron (pilot-r002-robot). 2026-09-23: `character.py`'s `RESIDENTS` table refactor (stage 2) removed the last hardcoded `'kai'`/`'lyra'` literals from `build_assets.py`/`check_contacts.py`; Kai's exported GLB verified byte-identical across the refactor (`sha256sum -c`). Kai now sits at roster position 4, bay `[-3,0,0]`, alongside thirteen other residents built the same way; see [full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md). |

<a id="gs-031"></a>

### GS-031 — Artistic Lyra

| Field | Specification |
| --- | --- |
| Family / catalogue link | Guild characters · RES-02 / GR05 |
| Counted deliverable / scene quantity | One production entry; 1 character. |
| Purpose and included content | Art director; source profile `artistic-lyra`. Reversible color panels and sketch-sheet motif. Deliver one complete dressed appearance including its integral accessories; separate portable versions are deferred. Home `guild-home-05`, work bay `guild-work-05` are proposed local scene labels, not accepted cross-product IDs. |
| Scale, fit and anchors | Style-derived body envelope and topology; ground pivot and appropriate name/seat/work anchors. Proportions follow the selected concept art; individual Guild designs await review. |
| Accepted-production dependencies | GS-041, GS-042, GS-043, GS-044, GS-045, GS-046, GS-047 |
| Required test / review checks | Recognizable in a fourteen-character lineup without relying only on color; operator approves public portrayal; shared idle/walk/seated clips show no severe clipping. Correct home/work/profile association. Plus applicable shared verification above. |
| Next action / attention | Review second robot appearance, shared-rig movement and production scope before full-cast acceptance. |
| Style / exact reference panels | 02-voxel; living-community r002 CONVERSATION robot grammar; GR05 reversible panels and sketch sheets. See [pilot references](../../../prototypes/voxel-work-bay/README.md#visual-references-and-provenance). |
| Owner | Unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Pilot verification](../../../prototypes/voxel-work-bay/evidence/VERIFICATION.md), 2026-09-22; full-cast acceptance not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-22: second robot trial added with colour panels and sketch pouch, same 16-bone rig and seven shared clips as Kai. 2026-09-23: `character.py`'s `RESIDENTS` table refactor (stage 2) removed the last hardcoded `'kai'`/`'lyra'` literals from `build_assets.py`/`check_contacts.py`; Lyra's exported GLB verified byte-identical across the refactor (`sha256sum -c`). Lyra now sits at roster position 5, bay `[-3,0,2]`, alongside thirteen other residents built the same way; her own appearance-acceptance record (GS-031's Review row) is still needed and is separate from this refactor — see the spec's *Carried out of stage 2* note and [full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md). |

<a id="gs-032"></a>

### GS-032 — Research Ray

| Field | Specification |
| --- | --- |
| Family / catalogue link | Guild characters · RES-02 / GR06 |
| Counted deliverable / scene quantity | One production entry; 1 character. |
| Purpose and included content | Research librarian; source profile `research-ray`. Field-notebook and specimen-card motifs. Deliver one complete dressed appearance including its integral accessories; separate portable versions are deferred. Home `guild-home-06`, work bay `guild-work-06` are proposed local scene labels, not accepted cross-product IDs. |
| Scale, fit and anchors | Style-derived body envelope and topology; ground pivot and appropriate name/seat/work anchors. Proportions follow the selected concept art; individual Guild designs await review. |
| Accepted-production dependencies | GS-041, GS-042, GS-043, GS-044, GS-045, GS-046, GS-047 |
| Required test / review checks | Recognizable in a fourteen-character lineup without relying only on color; operator approves public portrayal; shared idle/walk/seated clips show no severe clipping. Correct home/work/profile association. Plus applicable shared verification above. |
| Next action / attention | Operator review of the appearance and shared-rig movement before acceptance; resolve applicable A01, A02, A03, A05, A06. |
| Style / exact reference panels | 02-voxel; see [full-cast reference record](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md#the-fourteen-in-roster-order). Green accent; annotated map-cabinet chest motif (three stacked wood_dark drawers with steel pull tabs, bottom drawer ajar). New appearance, not yet reviewed. |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: authored on the shared 16-bone rig — green accent, map-cabinet chest motif. Operator review pending. |

<a id="gs-033"></a>

### GS-033 — Writer Quill

| Field | Specification |
| --- | --- |
| Family / catalogue link | Guild characters · RES-02 / GR07 |
| Counted deliverable / scene quantity | One production entry; 1 character. |
| Purpose and included content | Story editor; source profile `writer-quill`. Ink-notebook and paper-lantern motifs. Deliver one complete dressed appearance including its integral accessories; separate portable versions are deferred. Home `guild-home-07`, work bay `guild-work-07` are proposed local scene labels, not accepted cross-product IDs. |
| Scale, fit and anchors | Style-derived body envelope and topology; ground pivot and appropriate name/seat/work anchors. Proportions follow the selected concept art; individual Guild designs await review. |
| Accepted-production dependencies | GS-041, GS-042, GS-043, GS-044, GS-045, GS-046, GS-047 |
| Required test / review checks | Recognizable in a fourteen-character lineup without relying only on color; operator approves public portrayal; shared idle/walk/seated clips show no severe clipping. Correct home/work/profile association. Plus applicable shared verification above. |
| Next action / attention | Operator review of the appearance and shared-rig movement before acceptance; resolve applicable A01, A02, A03, A05, A06. |
| Style / exact reference panels | 02-voxel; see [full-cast reference record](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md#the-fourteen-in-roster-order). Wood_honey accent; paper lantern beside a slim book chest motif (paper body, wood_dark caps, orange glow window; wood_dark/ivory book). New appearance, not yet reviewed. |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: authored on the shared 16-bone rig — wood_honey accent, paper-lantern-and-book chest motif. Operator review pending. |

<a id="gs-034"></a>

### GS-034 — Analyst Echo

| Field | Specification |
| --- | --- |
| Family / catalogue link | Guild characters · RES-02 / GR08 |
| Counted deliverable / scene quantity | One production entry; 1 character. |
| Purpose and included content | Data interpreter; source profile `analyst-echo`. Chart motif; exact costume pending character review. Deliver one complete dressed appearance including its integral accessories; separate portable versions are deferred. Home `guild-home-08`, work bay `guild-work-08` are proposed local scene labels, not accepted cross-product IDs. |
| Scale, fit and anchors | Style-derived body envelope and topology; ground pivot and appropriate name/seat/work anchors. Proportions follow the selected concept art; individual Guild designs await review. |
| Accepted-production dependencies | GS-041, GS-042, GS-043, GS-044, GS-045, GS-046, GS-047 |
| Required test / review checks | Recognizable in a fourteen-character lineup without relying only on color; operator approves public portrayal; shared idle/walk/seated clips show no severe clipping. Correct home/work/profile association. Plus applicable shared verification above. |
| Next action / attention | Operator review of the appearance and shared-rig movement before acceptance; resolve applicable A01, A02, A03, A05, A06. Explicit user call still needed on the accent change (see change history). |
| Style / exact reference panels | 02-voxel; see [full-cast reference record](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md#the-fourteen-in-roster-order). **Teal** head/thigh accent (changed from the plan's original `sky`; see change history); bar-chart-relief chest motif (five rising sky/led_green blocks on an ink baseline — `sky` is retained here, on the motif, unchanged). New appearance, not yet reviewed. |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: authored on the shared 16-bone rig with the plan's `sky` head/thigh accent and a bar-chart chest motif. Found on review to disappear against the white shell (`sky` pixel-sampled within a few RGB points of white); accent changed to **`teal`** the same day. Chest motif (which still uses `sky` as one of its two block colours) was not touched. Operator review pending. |

<a id="gs-035"></a>

### GS-035 — Predictor Paul

| Field | Specification |
| --- | --- |
| Family / catalogue link | Guild characters · RES-02 / GR09 |
| Counted deliverable / scene quantity | One production entry; 1 character. |
| Purpose and included content | Scenario modeller; source profile `predictor-paul`. Weather/branching-path motif; exact costume pending review. Deliver one complete dressed appearance including its integral accessories; separate portable versions are deferred. Home `guild-home-09`, work bay `guild-work-09` are proposed local scene labels, not accepted cross-product IDs. |
| Scale, fit and anchors | Style-derived body envelope and topology; ground pivot and appropriate name/seat/work anchors. Proportions follow the selected concept art; individual Guild designs await review. |
| Accepted-production dependencies | GS-041, GS-042, GS-043, GS-044, GS-045, GS-046, GS-047 |
| Required test / review checks | Recognizable in a fourteen-character lineup without relying only on color; operator approves public portrayal; shared idle/walk/seated clips show no severe clipping. Correct home/work/profile association. Plus applicable shared verification above. |
| Next action / attention | Operator review of the appearance and shared-rig movement before acceptance; resolve applicable A01, A02, A03, A05, A06. |
| Style / exact reference panels | 02-voxel; see [full-cast reference record](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md#the-fourteen-in-roster-order). Blue_light accent; branching-fork chest motif with a hanging sky weather bead (blue_light path on a navy back). New appearance, not yet reviewed. |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: authored on the shared 16-bone rig — blue_light accent, branching-fork chest motif. Operator review pending. |

<a id="gs-036"></a>

### GS-036 — Strategy Sam

| Field | Specification |
| --- | --- |
| Family / catalogue link | Guild characters · RES-02 / GR10 |
| Counted deliverable / scene quantity | One production entry; 1 character. |
| Purpose and included content | Strategy facilitator; source profile `strategy-sam`. Chess/choices motif; exact costume pending review. Deliver one complete dressed appearance including its integral accessories; separate portable versions are deferred. Home `guild-home-10`, work bay `guild-work-10` are proposed local scene labels, not accepted cross-product IDs. |
| Scale, fit and anchors | Style-derived body envelope and topology; ground pivot and appropriate name/seat/work anchors. Proportions follow the selected concept art; individual Guild designs await review. |
| Accepted-production dependencies | GS-041, GS-042, GS-043, GS-044, GS-045, GS-046, GS-047 |
| Required test / review checks | Recognizable in a fourteen-character lineup without relying only on color; operator approves public portrayal; shared idle/walk/seated clips show no severe clipping. Correct home/work/profile association. Plus applicable shared verification above. |
| Next action / attention | Operator review of the appearance and shared-rig movement before acceptance; resolve applicable A01, A02, A03, A05, A06. |
| Style / exact reference panels | 02-voxel; see [full-cast reference record](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md#the-fourteen-in-roster-order). Orange_dark accent; 2×2 chequered board chest motif with one raised piece (ivory/ink squares on a wood_dark frame, orange_dark piece off-centre). New appearance, not yet reviewed. |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: authored on the shared 16-bone rig — orange_dark accent, chequered-board chest motif. Reworked mid-task: a first 3×3 grid did not resolve into a board at distance and read as a vertical stripe aligned with the shared neck trim; replaced with a smaller 2×2 grid on a visible board frame, piece moved off-centre. Operator review pending. |

<a id="gs-037"></a>

### GS-037 — Controller Casey

| Field | Specification |
| --- | --- |
| Family / catalogue link | Guild characters · RES-02 / GR11 |
| Counted deliverable / scene quantity | One production entry; 1 character. |
| Purpose and included content | Resource adviser; source profile `controller-casey`. Resource-token motif; exact costume pending review. Deliver one complete dressed appearance including its integral accessories; separate portable versions are deferred. Home `guild-home-11`, work bay `guild-work-11` are proposed local scene labels, not accepted cross-product IDs. |
| Scale, fit and anchors | Style-derived body envelope and topology; ground pivot and appropriate name/seat/work anchors. Proportions follow the selected concept art; individual Guild designs await review. |
| Accepted-production dependencies | GS-041, GS-042, GS-043, GS-044, GS-045, GS-046, GS-047 |
| Required test / review checks | Recognizable in a fourteen-character lineup without relying only on color; operator approves public portrayal; shared idle/walk/seated clips show no severe clipping. Correct home/work/profile association. Plus applicable shared verification above. |
| Next action / attention | Operator review of the appearance and shared-rig movement before acceptance; resolve applicable A01, A02, A03, A05, A06. |
| Style / exact reference panels | 02-voxel; see [full-cast reference record](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md#the-fourteen-in-roster-order). Steel accent; resource-token-rack chest motif (two rows of orange/cobalt/mint discs in a steel frame). New appearance, not yet reviewed. |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: authored on the shared 16-bone rig — steel accent, resource-token-rack chest motif. Operator review pending. |

<a id="gs-038"></a>

### GS-038 — Optimizer Ollie

| Field | Specification |
| --- | --- |
| Family / catalogue link | Guild characters · RES-02 / GR12 |
| Counted deliverable / scene quantity | One production entry; 1 character. |
| Purpose and included content | Performance coach; source profile `optimizer-ollie`. Marble-run motif; exact costume pending review. Deliver one complete dressed appearance including its integral accessories; separate portable versions are deferred. Home `guild-home-12`, work bay `guild-work-12` are proposed local scene labels, not accepted cross-product IDs. |
| Scale, fit and anchors | Style-derived body envelope and topology; ground pivot and appropriate name/seat/work anchors. Proportions follow the selected concept art; individual Guild designs await review. |
| Accepted-production dependencies | GS-041, GS-042, GS-043, GS-044, GS-045, GS-046, GS-047 |
| Required test / review checks | Recognizable in a fourteen-character lineup without relying only on color; operator approves public portrayal; shared idle/walk/seated clips show no severe clipping. Correct home/work/profile association. Plus applicable shared verification above. |
| Next action / attention | Operator review of the appearance and shared-rig movement before acceptance; resolve applicable A01, A02, A03, A05, A06. |
| Style / exact reference panels | 02-voxel; see [full-cast reference record](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md#the-fourteen-in-roster-order). Coral accent; looping marble-run chest motif with a travelling sky bead (coral outer loop, wood_honey inner loop). New appearance, not yet reviewed. |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: authored on the shared 16-bone rig — coral accent, marble-run chest motif. Reworked mid-task: a first pass (a solid fill plate behind one loop) read as a plain picture frame, not a track; fixed by opening the loop's centre and nesting a second smaller loop. Remains the weakest-reading motif of the fourteen even after the fix; the travelling bead sits at the motif envelope's depth limit. Operator review pending. |

<a id="gs-039"></a>

### GS-039 — Threat Hunter Theo

| Field | Specification |
| --- | --- |
| Family / catalogue link | Guild characters · RES-02 / GR13 |
| Counted deliverable / scene quantity | One production entry; 1 character. |
| Purpose and included content | Digital safety educator; source profile `threat-hunter-theo`. Puzzle-lock motif; exact costume pending review. Deliver one complete dressed appearance including its integral accessories; separate portable versions are deferred. Home `guild-home-13`, work bay `guild-work-13` are proposed local scene labels, not accepted cross-product IDs. |
| Scale, fit and anchors | Style-derived body envelope and topology; ground pivot and appropriate name/seat/work anchors. Proportions follow the selected concept art; individual Guild designs await review. |
| Accepted-production dependencies | GS-041, GS-042, GS-043, GS-044, GS-045, GS-046, GS-047 |
| Required test / review checks | Recognizable in a fourteen-character lineup without relying only on color; operator approves public portrayal; shared idle/walk/seated clips show no severe clipping. Correct home/work/profile association. Plus applicable shared verification above. |
| Next action / attention | Operator review of the appearance and shared-rig movement before acceptance; resolve applicable A01, A02, A03, A05, A06. Explicit user call still needed on the accent trade-off (see change history). |
| Style / exact reference panels | 02-voxel; see [full-cast reference record](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md#the-fourteen-in-roster-order). **`led_green`** head/thigh accent (changed from the plan's original `ink`; see change history); puzzle-lock-plate chest motif (ink disc on a steel back plate, three led_green tumbler pips, steel keyhole — `ink` is retained here, on the motif, unchanged). New appearance, not yet reviewed. |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: authored on the shared 16-bone rig with the plan's `ink` head/thigh accent and a puzzle-lock-plate chest motif. Found on review to read as absence rather than accent (`ink` pixel-sampled near-black, indistinguishable from the shared head-module's own ambient-occlusion shadow); accent changed to **`led_green`** the same day — the only unused palette colour with strong presence against white, and already used on the motif's tumbler pips. **Provisional, awaiting the user's decision:** `led_green` also matches Theo's eye colour (the shared chevron-eye material), so his accent and his eyes now read the same colour. Chest motif (which still uses `ink` for the disc) was not touched. Operator review, including this trade-off, pending. |

<a id="gs-040"></a>

### GS-040 — Cleaner Cody

| Field | Specification |
| --- | --- |
| Family / catalogue link | Guild characters · RES-02 / GR14 |
| Counted deliverable / scene quantity | One production entry; 1 character. |
| Purpose and included content | Reuse steward; source profile `cleaner-cody`. Repaired patchwork satchel motif. Deliver one complete dressed appearance including its integral accessories; separate portable versions are deferred. Home `guild-home-14`, work bay `guild-work-14` are proposed local scene labels, not accepted cross-product IDs. |
| Scale, fit and anchors | Style-derived body envelope and topology; ground pivot and appropriate name/seat/work anchors. Proportions follow the selected concept art; individual Guild designs await review. |
| Accepted-production dependencies | GS-041, GS-042, GS-043, GS-044, GS-045, GS-046, GS-047 |
| Required test / review checks | Recognizable in a fourteen-character lineup without relying only on color; operator approves public portrayal; shared idle/walk/seated clips show no severe clipping. Correct home/work/profile association. Plus applicable shared verification above. |
| Next action / attention | Operator review of the appearance and shared-rig movement before acceptance; resolve applicable A01, A02, A03, A05, A06. |
| Style / exact reference panels | 02-voxel; see [full-cast reference record](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md#the-fourteen-in-roster-order). Leaf_light accent; mended-blocks chest motif with visible repair seams (mismatched wood_dark/sand/cream blocks, leaf_light seams, steel rivets). New appearance, not yet reviewed. |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: authored on the shared 16-bone rig — leaf_light accent, mended-blocks chest motif. Ray (green accent) and Cody (leaf_light accent) separate when compared directly (~38 luminance points), though both remain subject to the thin-sliver legibility problem shared across the whole cast's head/thigh accent geometry. Operator review pending. |

<a id="gs-041"></a>

### GS-041 — Shared style-specific character rig

| Field | Specification |
| --- | --- |
| Family / catalogue link | Shared production · RES-01/02/07 |
| Counted deliverable / scene quantity | One production entry; 1 reusable rig. |
| Purpose and included content | A style-derived rig and fitting body for compatible Guild appearances, authored from the selected style’s living-community and interface character references. If the cast needs incompatible skeletons, split this package into explicit child deliverables and revise counts before authoring. A visible visitor avatar is deferred; default scene assumption is first-person navigation. |
| Scale, fit and anchors | Height and body topology derived from the selected concept panels; skeleton naming, root motion policy, hand/seat/name anchors and export convention to be recorded. |
| Accepted-production dependencies | No other completed asset required; shared decisions above still apply. |
| Required test / review checks | Import into the selected client, verify scale, skin weights and shared clips; seat and hand anchors match furniture. Plus applicable shared verification above. |
| Next action / attention | Rig now covers all fourteen residents; review the linked pilot and resolve the remaining attention items (A01, A02, A05, A06) for full production acceptance. |
| Style / exact reference panels | 02-voxel; [pilot reference record](../../../prototypes/voxel-work-bay/README.md#visual-references-and-provenance): living r002 WORKSHOP and CONVERSATION panels, with linked image/review; new Kai design pending review |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Pilot verification](../../../prototypes/voxel-work-bay/evidence/VERIFICATION.md), 2026-09-22, extended by [full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: extended from Kai and Lyra to all fourteen Guild residents. `test_exports.py::test_every_resident_shares_the_rig_and_clip_set` now compares the full ordered 16-bone name list (not just a bone count) and the seven-clip set across every resident — 0 mismatches. See [full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md). |

<a id="gs-042"></a>

### GS-042 — Scene material and palette library

| Field | Specification |
| --- | --- |
| Family / catalogue link | Shared production · Shared presentation |
| Counted deliverable / scene quantity | One production entry; 1 reusable library. |
| Purpose and included content | One selected-style library covering ground, walls, roof, foliage, wood, metal, fabric, skin and interface accents; enumerated material slots inside the library. |
| Scale, fit and anchors | Document palette, texture conventions and material assignments; no arbitrary polygon or texture budget before measurement. |
| Accepted-production dependencies | No other completed asset required; shared decisions above still apply. |
| Required test / review checks | Representative assets match in one lighting setup; text/non-color cues remain legible; record device cost. Plus applicable shared verification above. |
| Next action / attention | Review the linked pilot and resolve the remaining attention items for full production; extend compatibility beyond Kai before final acceptance. |
| Style / exact reference panels | 02-voxel; [pilot reference record](../../../prototypes/voxel-work-bay/README.md#visual-references-and-provenance): living r002 WORKSHOP and CONVERSATION panels, with linked image/review; new Kai design pending review |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Pilot verification](../../../prototypes/voxel-work-bay/evidence/VERIFICATION.md), 2026-09-22; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-043"></a>

### GS-043 — Standing idle clip

| Field | Specification |
| --- | --- |
| Family / catalogue link | Animation · RES-07 |
| Counted deliverable / scene quantity | One production entry; 1 reusable clip. |
| Purpose and included content | Subtle neutral standing loop; no implied busy state. |
| Scale, fit and anchors | Same skeleton as GS-041; loop, interruption, blending and root motion declared. |
| Accepted-production dependencies | GS-041 |
| Required test / review checks | Clean loop with stable feet and reduced-motion still pose. Check on every character appearance. Plus applicable shared verification above. |
| Next action / attention | Review the linked pilot and resolve the remaining attention items for full production; extend compatibility beyond Kai before final acceptance. |
| Style / exact reference panels | 02-voxel; [pilot reference record](../../../prototypes/voxel-work-bay/README.md#visual-references-and-provenance): living r002 WORKSHOP and CONVERSATION panels, with linked image/review; new Kai design pending review |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Pilot verification](../../../prototypes/voxel-work-bay/evidence/VERIFICATION.md), 2026-09-22, extended by [full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: clip now carried by all fourteen Guild residents, not just Kai and Lyra; verified identical across the cast by the shared-rig parity test (GS-041). See [full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md). |

<a id="gs-044"></a>

### GS-044 — Walking clip

| Field | Specification |
| --- | --- |
| Family / catalogue link | Animation · RES-07 |
| Counted deliverable / scene quantity | One production entry; 1 reusable clip. |
| Purpose and included content | One reusable walk cycle; agent repositioning is authored presentation, not proof of work. |
| Scale, fit and anchors | Same skeleton as GS-041; loop, interruption, blending and root motion declared. |
| Accepted-production dependencies | GS-041 |
| Required test / review checks | No foot sliding at agreed movement speed; start/stop blending and ground contact checked. Check on every character appearance. Plus applicable shared verification above. |
| Next action / attention | Review the linked pilot and resolve the remaining attention items for full production; extend compatibility beyond Kai before final acceptance. |
| Style / exact reference panels | 02-voxel; [pilot reference record](../../../prototypes/voxel-work-bay/README.md#visual-references-and-provenance): living r002 WORKSHOP and CONVERSATION panels, with linked image/review; new Kai design pending review |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Pilot verification](../../../prototypes/voxel-work-bay/evidence/VERIFICATION.md), 2026-09-22, extended by [full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: clip now carried by all fourteen Guild residents, not just Kai and Lyra; verified identical across the cast by the shared-rig parity test (GS-041). See [full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md). |

<a id="gs-045"></a>

### GS-045 — Seated idle clip

| Field | Specification |
| --- | --- |
| Family / catalogue link | Animation · RES-07 |
| Counted deliverable / scene quantity | One production entry; 1 reusable clip. |
| Purpose and included content | One seated rest loop compatible with work chair and desk. |
| Scale, fit and anchors | Same skeleton as GS-041; loop, interruption, blending and root motion declared. |
| Accepted-production dependencies | GS-041 |
| Required test / review checks | Hips align with seat; feet and knees fit all fourteen appearances. Check on every character appearance. Plus applicable shared verification above. |
| Next action / attention | Review the linked pilot and resolve the remaining attention items for full production; extend compatibility beyond Kai before final acceptance. |
| Style / exact reference panels | 02-voxel; [pilot reference record](../../../prototypes/voxel-work-bay/README.md#visual-references-and-provenance): living r002 WORKSHOP and CONVERSATION panels, with linked image/review; new Kai design pending review |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Pilot verification](../../../prototypes/voxel-work-bay/evidence/VERIFICATION.md), 2026-09-22, extended by [full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: clip now carried by all fourteen Guild residents, not just Kai and Lyra; verified identical across the cast by the shared-rig parity test (GS-041). See [full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md). |

<a id="gs-046"></a>

### GS-046 — Seated typing clip

| Field | Specification |
| --- | --- |
| Family / catalogue link | Animation · RES-07 |
| Counted deliverable / scene quantity | One production entry; 1 reusable clip. |
| Purpose and included content | One low-intensity keyboard activity loop; fixture/decorative activity must be labelled and never manufacture live status. |
| Scale, fit and anchors | Same skeleton as GS-041; loop, interruption, blending and root motion declared. |
| Accepted-production dependencies | GS-041 |
| Required test / review checks | Hands reach keyboard; cancellation returns to rest; unavailable or stale feed cannot silently show verified activity. Check on every character appearance. Plus applicable shared verification above. |
| Next action / attention | Review the linked pilot and resolve the remaining attention items for full production; extend compatibility beyond Kai before final acceptance. |
| Style / exact reference panels | 02-voxel; [pilot reference record](../../../prototypes/voxel-work-bay/README.md#visual-references-and-provenance): living r002 WORKSHOP and CONVERSATION panels, with linked image/review; new Kai design pending review |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Pilot verification](../../../prototypes/voxel-work-bay/evidence/VERIFICATION.md), 2026-09-22, extended by [full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: clip now carried by all fourteen Guild residents, not just Kai and Lyra; verified identical across the cast by the shared-rig parity test (GS-041). See [full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md). |

<a id="gs-047"></a>

### GS-047 — Look-and-attend clip

| Field | Specification |
| --- | --- |
| Family / catalogue link | Animation · RES-07 |
| Counted deliverable / scene quantity | One production entry; 1 reusable clip. |
| Purpose and included content | One head/upper-body attention movement for observing a board or nearby work; no implied conversation. |
| Scale, fit and anchors | Same skeleton as GS-041; loop, interruption, blending and root motion declared. |
| Accepted-production dependencies | GS-041 |
| Required test / review checks | Neck/shoulders stay within limits; blend does not break seated or standing pose. Check on every character appearance. Plus applicable shared verification above. |
| Next action / attention | Review the linked pilot and resolve the remaining attention items for full production; extend compatibility beyond Kai before final acceptance. |
| Style / exact reference panels | 02-voxel; [pilot reference record](../../../prototypes/voxel-work-bay/README.md#visual-references-and-provenance): living r002 WORKSHOP and CONVERSATION panels, with linked image/review; new Kai design pending review |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Pilot verification](../../../prototypes/voxel-work-bay/evidence/VERIFICATION.md), 2026-09-22, extended by [full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md), 2026-09-23; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | 2026-09-23: clip now carried by all fourteen Guild residents, not just Kai and Lyra; verified identical across the cast by the shared-rig parity test (GS-041). See [full-cast verification](../../../prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md). |

<a id="gs-048"></a>

### GS-048 — Courtyard map and text route view

| Field | Specification |
| --- | --- |
| Family / catalogue link | Interface · INFO-07 |
| Counted deliverable / scene quantity | One production entry; 1 reusable presentation package. |
| Purpose and included content | One map layout and equivalent text destination list for fourteen homes/workplaces. |
| Scale, fit and anchors | Responsive layout; inspect at draft 360 px narrow width and desktop size, plus enlarged text. Target devices/input methods remain A05. |
| Accepted-production dependencies | GS-015, GS-016 |
| Required test / review checks | Every place has the same identity in scene and text view; keyboard navigation and narrow-screen layout work. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A03, A04, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-049"></a>

### GS-049 — Guild roster and biography view

| Field | Specification |
| --- | --- |
| Family / catalogue link | Interface · RES-02 / INFO-07 |
| Counted deliverable / scene quantity | One production entry; 1 reusable presentation package. |
| Purpose and included content | One reusable profile layout plus fourteen approved biography records and appearance thumbnails derived from the character assets. |
| Scale, fit and anchors | Responsive layout; inspect at draft 360 px narrow width and desktop size, plus enlarged text. Target devices/input methods remain A05. |
| Accepted-production dependencies | GS-027–040 |
| Required test / review checks | All fourteen names/profile mappings are correct; roster works with no live feed; text view needs no 3D. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A03, A04, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-050"></a>

### GS-050 — Public work-state card

| Field | Specification |
| --- | --- |
| Family / catalogue link | Interface · INFO-03 |
| Counted deliverable / scene quantity | One production entry; 1 reusable presentation package. |
| Purpose and included content | One reusable card showing only the agreed public fields, with explicit source/freshness treatment. Actual fields remain A04. |
| Scale, fit and anchors | Responsive layout; inspect at draft 360 px narrow width and desktop size, plus enlarged text. Target devices/input methods remain A05. |
| Accepted-production dependencies | No other completed asset required; shared decisions above still apply. |
| Required test / review checks | Exercise approved fixture cases and missing values; no private fields, prompts, paths or credentials rendered. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A03, A04, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-051"></a>

### GS-051 — Work-state badge set

| Field | Specification |
| --- | --- |
| Family / catalogue link | Interface · FX-05 / INFO-03 |
| Counted deliverable / scene quantity | One production entry; 1 reusable presentation package. |
| Purpose and included content | One coordinated set of five draft labels/icons: working, idle, unavailable, stale and unknown. Final semantics follow A04. |
| Scale, fit and anchors | Responsive layout; inspect at draft 360 px narrow width and desktop size, plus enlarged text. Target devices/input methods remain A05. |
| Accepted-production dependencies | GS-050 |
| Required test / review checks | Text and shape distinguish states without color; unknown cannot default to working; stale takes precedence over old working state. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A03, A04, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-052"></a>

### GS-052 — Fixture and freshness notice

| Field | Specification |
| --- | --- |
| Family / catalogue link | Interface · INFO-03 / FX-05 |
| Counted deliverable / scene quantity | One production entry; 1 reusable presentation package. |
| Purpose and included content | One persistent notice component with labelled-fixture, stale and unavailable variants. |
| Scale, fit and anchors | Responsive layout; inspect at draft 360 px narrow width and desktop size, plus enlarged text. Target devices/input methods remain A05. |
| Accepted-production dependencies | GS-050, GS-051 |
| Required test / review checks | Fixture mode is unmistakable; expiry stays visible at every view size; decorative animation never removes notice. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A03, A04, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-053"></a>

### GS-053 — Navigation and focus cues

| Field | Specification |
| --- | --- |
| Family / catalogue link | Interface · INFO-09 |
| Counted deliverable / scene quantity | One production entry; 1 reusable presentation package. |
| Purpose and included content | One coordinated focus/selection and movement-help set for the agreed first-person navigation and keyboard/text alternatives. |
| Scale, fit and anchors | Responsive layout; inspect at draft 360 px narrow width and desktop size, plus enlarged text. Target devices/input methods remain A05. |
| Accepted-production dependencies | No other completed asset required; shared decisions above still apply. |
| Required test / review checks | Visible focus, discoverable controls, reduced-motion option and no keyboard trap; observing never invokes agent dispatch. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A03, A04, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-054"></a>

### GS-054 — Access and tier notice

| Field | Specification |
| --- | --- |
| Family / catalogue link | Interface · INFO-04 |
| Counted deliverable / scene quantity | One production entry; 1 reusable presentation package. |
| Purpose and included content | One observation-only/access notice with registered and insufficient-authority variants; tier wording remains draft. |
| Scale, fit and anchors | Responsive layout; inspect at draft 360 px narrow width and desktop size, plus enlarged text. Target devices/input methods remain A05. |
| Accepted-production dependencies | No other completed asset required; shared decisions above still apply. |
| Required test / review checks | Anonymous user sees no agent-input path; funded tier is never described as authority; textual alternative is accessible. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A03, A04, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-055"></a>

### GS-055 — Sign-in presentation

| Field | Specification |
| --- | --- |
| Family / catalogue link | Interface · INFO-04 / W1 interface |
| Counted deliverable / scene quantity | One production entry; 1 reusable presentation package. |
| Purpose and included content | One sign-in/account-state layout with signed-out, pending, error and signed-in states. This is an interface asset, not an identity backend. |
| Scale, fit and anchors | Responsive layout; inspect at draft 360 px narrow width and desktop size, plus enlarged text. Target devices/input methods remain A05. |
| Accepted-production dependencies | GS-054 |
| Required test / review checks | Keyboard focus and error recovery work in fixture preview; credentials never go into scene assets; live integration separately evidenced. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A03, A04, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-056"></a>

### GS-056 — Pinned comment and report presentation

| Field | Specification |
| --- | --- |
| Family / catalogue link | Interface · INFO-02 |
| Counted deliverable / scene quantity | One production entry; 1 reusable presentation package. |
| Purpose and included content | One comment composer/thread layout with place/work reference, pending/denied/error states, report control and moderation notice. |
| Scale, fit and anchors | Responsive layout; inspect at draft 360 px narrow width and desktop size, plus enlarged text. Target devices/input methods remain A05. |
| Accepted-production dependencies | GS-055 |
| Required test / review checks | Anonymous posting denied in fixture flow; keyboard access, failed-submit recovery and report route visible. Live auth/moderation remain external gates. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A03, A04, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-057"></a>

### GS-057 — Quiet-hours and recent-work view

| Field | Specification |
| --- | --- |
| Family / catalogue link | Interface · INFO-03 |
| Counted deliverable / scene quantity | One production entry; 1 reusable presentation package. |
| Purpose and included content | One empty/quiet-hours panel with timestamped approved highlights; history is explicitly distinguished from current activity. |
| Scale, fit and anchors | Responsive layout; inspect at draft 360 px narrow width and desktop size, plus enlarged text. Target devices/input methods remain A05. |
| Accepted-production dependencies | GS-050, GS-052 |
| Required test / review checks | No-history and unavailable-history cases readable; old highlights never look like live work; text access works. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A03, A04, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-058"></a>

### GS-058 — Daylight and sky setup

| Field | Specification |
| --- | --- |
| Family / catalogue link | Scene finishing · FX-01 |
| Counted deliverable / scene quantity | One production entry; 1 reusable environment preset. |
| Purpose and included content | One calm daytime lighting/sky setup for the courtyard and both work zones. Weather and day/night simulation are deferred. |
| Scale, fit and anchors | Record exposure, shadow and ambient settings with selected client version; include lower-cost fallback. |
| Accepted-production dependencies | GS-042 |
| Required test / review checks | Faces, entrances, labels and screens readable together; low-quality mode preserves meaningful information. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-059"></a>

### GS-059 — Courtyard ambience loop

| Field | Specification |
| --- | --- |
| Family / catalogue link | Scene finishing · FX-04 |
| Counted deliverable / scene quantity | One production entry; 1 sound loop reused by zone. |
| Purpose and included content | One licensed quiet outdoor ambience; per-zone attenuation may reuse the same sound. No character voice or music pack. |
| Scale, fit and anchors | Record duration, seamless loop points, source rights, volume and mute control. |
| Accepted-production dependencies | No other completed asset required; shared decisions above still apply. |
| Required test / review checks | No audible loop click; mute works; no essential status is conveyed only through sound. Plus applicable shared verification above. |
| Next action / attention | Draft specification: resolve applicable A01, A05, A06; assign owner, confirm item spec and create first version. |
| Style / exact reference panels | Unassigned; use [pinned style index](FIRST_GUILD_STYLE_REFERENCES.md). Record style ID, sheet revision, panel and image/review links before authoring. |
| Owner | Unassigned |
| Editable source / export / artifact revision | None for this numbered deliverable |
| Test evidence / tested revision / date | None; see tracker for status |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

<a id="gs-060"></a>

### GS-060 — Integrated Guild scene

| Field | Specification |
| --- | --- |
| Family / catalogue link | Scene finishing · W1 / BLD / RES / INFO |
| Counted deliverable / scene quantity | One production entry; 1 representative scene. |
| Purpose and included content | Assemble the courtyard, two seven-bay work zones in W1, fourteen home frontages and all fourteen characters. Deliver a reproducible fixture preview first; real runtime observation remains a separate integration gate. |
| Scale, fit and anchors | One chosen-style scene with first-person visitor navigation, map/text view, home/work assignments and recorded instance counts. Layout dimensions reconciled after blockout. |
| Accepted-production dependencies | GS-001–059 |
| Required test / review checks | Walk to and identify all fourteen agents; check maps, addresses, stale/offline/fixture states and quiet hours. Record build revision, target device, loading/memory/frame measurements and review evidence. Live W1 acceptance still requires real-feed and account/moderation evidence. Plus applicable shared verification above. |
| Next action / attention | Review the linked pilot and resolve the remaining attention items for full production; extend compatibility beyond Kai before final acceptance. |
| Style / exact reference panels | 02-voxel; [pilot reference record](../../../prototypes/voxel-work-bay/README.md#visual-references-and-provenance): living r002 WORKSHOP and CONVERSATION panels, with linked image/review; new Kai design pending review |
| Owner | Codex pilot authoring; production owner and operator reviewer unassigned |
| Editable source / export / artifact revision | [Voxel pilot source](../../../prototypes/voxel-work-bay/source/work-bay.blend) · [manifest](../../../prototypes/voxel-work-bay/asset-manifest.json) · pilot-r004-full-cast; partial production scope |
| Test evidence / tested revision / date | [Pilot verification](../../../prototypes/voxel-work-bay/evidence/VERIFICATION.md), 2026-09-22; full asset acceptance checks not yet run |
| Review evidence / reviewer / reviewed revision / date | None; see tracker for status |
| Asset-specific issues / change history | None recorded yet; preserve dated changes here |

## Scope revision log

| Date | Change | Evidence |
| --- | --- | --- |
| 2026-09-22 | User selected Voxel and authorised the one-bay pipeline pilot. Twelve production entries moved to In progress with partial evidence; none promoted to full acceptance. Added early measurement and separate pilot acceptance. | [Pilot](../../../prototypes/voxel-work-bay/README.md); [decision record](../../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-22). |
| 2026-09-22 | User directed existing visual styles as references and excluded the humanoid experiment. Added pinned references, per-style tracking, style-derived rigs and reference-district constraints. | User direction in this task. |
| 2026-09-22 | Created proposed 60-deliverable first-scene baseline, separate build/test/review tracker and evidence slots. Existing references retained without asserting production acceptance. | Starter collection, Guild roster and W1 roadmap linked above; local asset inventory inspection. |
| 2026-09-22 | Shared workshop and courtyard pilot: twelve additional rows In progress (25 total), simultaneous Kai/Lyra, modular environment and partial technical evidence; no full production acceptance. | [Shared verification](../../../prototypes/voxel-work-bay/evidence/SHARED-VERIFICATION.md). |
