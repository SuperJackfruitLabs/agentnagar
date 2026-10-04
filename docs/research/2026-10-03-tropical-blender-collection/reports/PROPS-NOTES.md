# Tropical props completion

24 original procedural Blender models, authored from directly inspected A-work-furniture, A-civic-v2, A-perch-seat, A-ground-and-track, A-low-planting and A-terrace concept sheets. Existing Claude construction scripts and old model meshes were not read or copied. Shared original assetkit provides primitive, palette, and export functions only.

Source repository stayed clean at detached 0795960. Read lowpoly props/scenery/vegetation specifications, runtime pack_3d.gd, and shared tram layout for interface contracts. Parent coordinated rail centres at Blender Y ±0.72 m with tram wheel tread centres; shared tram layout itself has passenger locations, not a rail gauge.

Authoring Z-up metres, origin at furniture ground/contact centre; ground modules extend down from walking top zero. Export Y-up. Steel members are 30 mm at desks, 25 mm stool members, 50 mm workbench maximum. Ref top height .75 m desk/.90 m bench, with added blank monitor equipment for required historical screen nodes. Notice, plaque, kiosk and workstation GLBs have separate display empties: centre of actual face, scale as face width/height, local -Z as outward normal. Plaque tilt retained. No letters or panels baked into blank faces.

Deliverables: editable original-component .blend; GLB grouped by runtime mesh node; per-asset measured triangle/bounds JSON; combined reports/props-complete.json; structural verification reports/props-structure-check.json. All 24 GLB headers, lengths, mesh names and presence of editable source confirmed; live face empties checked non-mesh with scale. Parent owns GPU renders and Godot review.

Geometry budgets intentionally exceeded where original constructed detail warrants it: desk aliases/workstation 3000 triangles (keys, four-legged desk and stool), workbench2784, bookshelf5676 (60 individual books, fine spine bands, frame), pegboard7640 (231 dark hole surfaces, original tools), meadow_flowers640; tile B276, street188, track336, water212. Compare measured per-asset JSON to repository historical budgets; no false claim of budget conformance. All are still modest individual models, but crowd/instancing performance must be measured in an adoption phase.

Commands executed:

- blender -b -t 2 --python scripts/build_props_complete.py (from artifact workspace; CPU export only, completed24).
- Python standard-library GLB structural checks on all24 exports; succeeded.
- Read-only git status, remote, worktree inventory on agentnagar; clean detached source.

Known small differences to old specs: meadow grass has naturally slender .251 x .248 m footprint rather than full .33 x .31 envelope; meadow flowers .27 x .189 footprint, tallest petal .905 m versus .89; screen-equipped workstation1.20m versus1.19 old upper envelope. Notice roof .6373m versus .63 old depth. These are review candidates rather than production replacements.
