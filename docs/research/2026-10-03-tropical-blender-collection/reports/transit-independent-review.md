# Independent review of transit, sky and aliases

Read-only review of `scripts/build_transit_sky.py` and its exported GLBs by the character builder. No transit/sky source or assets were edited.

## Actionable findings on reviewed exports

1. **Reading-chair alias includes a studio floor.** `aliases()` opens the original editable `.blend` and passes every mesh to `finish`. The reading-chair blend includes a studio floor. The resulting `reading_chair_v2` metadata has bounds `[-100,-100,-0.085]` to `[100,100,0.93139]`, 24 editable meshes and 1,112 triangles; the approved `seat_reading-chair_v2` has the intended chair bounds, 23 meshes and 1,100 triangles. Exclude the studio object, or create a byte-preserving/geometry-preserving alias from the approved GLB.
2. **Café assembly loses its approved colours.** Imported approved GLBs contain vertex colours; `finish` overwrites them using the imported palette material's diffuse colour. The exported `cafe_table_set` has one uniform grey vertex colour `(0.799103,0.799103,0.799103)`; the source table has six colours and source chairs five. Preserve imported `COLOR_0` or assemble the original editable colour-material components.
3. **Tram has 928 zero-area triangles.** The measured GLB contains 896 in `interior` and 32 in `body`. Thin beveled boxes with bevel widths clamped to half their thickness produce coincident corners. Weld/dissolve degenerate geometry before export, or keep bevel widths below that limit. This can be repaired without changing visible design.

Parent was notified of these findings and owns fixes/revalidation; the measurements above describe the reviewed versions rather than a claim about subsequent exports.

## Checks without actionable defects

- `bench_park` is exactly equal to approved `seat_bench_v2` in its triangle multiset, including coordinates and vertex colours (1,060 triangles).
- The sailboat's cedar hull has 56 original vertices, zero boundary edges and zero nonmanifold edges. Bow/stern end caps are present. The hull GLB has no zero-area triangles.
- Main sail and foresail have only their expected exterior boundaries (five and four edges respectively), with no interior missing panels. These are intentionally thin cloth surfaces, not closed volumes, and the exported material explicitly sets `doubleSided: true`.
- Both clouds are closed manifold meshes after their remesh/decimation/underside cleanup: cloud A has 215 original vertices, cloud B 147; neither has boundary/nonmanifold edges or zero-area faces. Their GLBs have 426 and 290 triangles and no zero-area triangles.
- Café chair assembly orientations point the two approved chairs toward the centre table; source geometry is reused, although its export colours need the repair above.

Topology check output is retained in `reports/transit-topology-review.log`.

## Follow-up verification after parent fixes

The fresh `aliases-final.log` completed `cafe_table_set`, then the exports were checked again:

- Café assembly: 4,208 triangles, zero zero-area triangles, six vertex colours matching the exact union of the approved table/chair palettes.
- Reading-chair alias: 1,100 triangles, zero zero-area triangles, fifteen matching colours, studio floor absent. The approved GLB has a translated `body` node whereas the alias bakes that translation; after applying it, the maximum nearest world-space vertex discrepancy is only `3.42e-8 m` (floating-point rounding).
- Bench alias remains exactly equal in triangle coordinates and colours.
- Tram: 18,112 triangles, **zero zero-area triangles** after cleanup.

All three actionable findings from this bounded review are resolved in the rechecked exports.
