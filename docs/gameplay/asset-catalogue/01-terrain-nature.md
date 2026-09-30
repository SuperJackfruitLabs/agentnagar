# Terrain and nature

[Catalogue](README.md) · [Shared characteristics](CHARACTERISTICS.md) · Proposed asset kinds, 2026-09-18.

Natural assets establish the city's geography and character. Ownership usually belongs to a plot or civic area; editing land does not imply unrestricted harvesting. Growth and ecology are later simulation options, not required for the first visual scene.

All rows inherit the shared identity, ownership, presentation, accessibility and lifecycle characteristics where applicable. The fields below distinguish this kind. Interactions describe intended behavior, not implemented capabilities.

| ID | Kind and description | Treatment | Distinguishing characteristics | Interactions and states |
| --- | --- | --- | --- | --- |
| NAT-01 | **Ground and terrain patch.** Walkable land shaping a plot or district. | Fixed | Elevation, slope, surface material, traversability, region boundary and drainage representation. | Authorized sculpt/paint; preserve navigation and placed-object support. |
| NAT-02 | **River, canal and pond.** Water body providing identity, views and possible transport routes. | Fixed | Shoreline, depth classification, crossing/boarding edges, current appearance and water level. | Inspect; swimming, flow simulation and flooding are later options. |
| NAT-03 | **Rock and natural landmark.** Distinctive boulder, cliff or outcrop used for orientation. | Fixed | Scale, silhouette, collision, climbable surfaces and landmark visibility. | Inspect; climbing only when explicitly authored. |
| NAT-04 | **Tree.** Canopy and trunk providing shade and street or park identity. | Fixed | Species/style, mature bounds, root footprint, season variant, wind motion and clearance. | Inspect; planting/removal needs landscape authority; growth and harvest deferred. |
| NAT-05 | **Shrub and hedge.** Low planting or a soft visual boundary. | Fixed | Height, density, trim profile, collision policy and modular joins. | Authorized planting and trimming; visual seasonal states. |
| NAT-06 | **Flowers and ground cover.** Small vegetation giving gardens and paths variety. | Fixed | Patch bounds, density, palette, seasonal variants and whether individual plants exist. | Initially patch scenery; picking requires an explicit harvestable variant. |
| NAT-07 | **Potted plant.** A resident-owned natural prop for homes and workspaces. | Portable | Pot dimensions, support surface, carry class, species and optional care state. | Pick up, place, store or sell with permission; care need not be simulated. |
| NAT-08 | **Garden bed and crop plot.** Cultivation area containing deliberately planted species. | Fixed | Plot slots, crop type, access, growth stages and harvest ownership. | Plant/water/harvest as later capabilities; ownership of harvested outputs explicit. |
