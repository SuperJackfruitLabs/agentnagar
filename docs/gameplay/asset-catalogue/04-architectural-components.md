# Architectural components

[Catalogue](README.md) · [Shared characteristics](CHARACTERISTICS.md) · Proposed asset kinds, 2026-09-18.

Components form compatible building kits. Their connectors, usable dimensions and navigation behavior should remain stable across style variants.

All rows inherit the shared identity, ownership, presentation, accessibility and lifecycle characteristics where applicable. The fields below distinguish this kind. Interactions describe intended behavior, not implemented capabilities.

| ID | Kind and description | Treatment | Distinguishing characteristics | Interactions and states |
| --- | --- | --- | --- | --- |
| ARC-01 | **Floor, ceiling and foundation.** Structural surfaces that support spaces and placed objects. | Fixed | Module dimensions, thickness, support plane, openings, snap connectors and material. | Place/replace by authorized editing; resolve supported objects before removal. |
| ARC-02 | **Wall and partition.** Solid or partial boundary between spaces. | Fixed | Length, height, thickness, openings, corner joins and visibility/acoustic treatment. | Place/resize/edit; no silent enclosure of occupied spaces. |
| ARC-03 | **Door, gate and lock.** Permission-aware passage between spaces. | Fixed | Opening bounds, hinge/slide motion, handle/interaction anchors, clearance and lock policy. | Open/close/lock; access checked separately from animation; occupied threshold handling. |
| ARC-04 | **Window and skylight.** Light and sight opening in a building envelope. | Fixed | Opening dimensions, transparency, frame, operability and view/occlusion behavior. | Inspect; open/close only on operable variants. |
| ARC-05 | **Stair and ramp.** Vertical connection for movement. | Fixed | Rise, run, width, landings, handrails, headroom and navigation connectors. | Traverse; validate approach and exit; accessible alternate route where needed. |
| ARC-06 | **Lift.** Controlled moving connection between floors. | Fixed | Stops, cabin bounds, passenger slots, doors and call controls. | Call/board/select/exit; unavailable state and recovery destination. |
| ARC-07 | **Roof, balcony and railing.** Upper envelope and protected outdoor edges. | Fixed | Pitch, overhang, walkable area, joins, edge collision and supported mounts. | Authorized editing; distinguish decorative roofs from accessible terraces. |
| ARC-08 | **Facade, awning and surface finish.** Appearance layer for buildings and shade structures. | Fixed | Mount surface, palette/material, projection bounds, signage areas and weather variants. | Customize within owner rights; finish changes do not alter ownership or room geometry. |
