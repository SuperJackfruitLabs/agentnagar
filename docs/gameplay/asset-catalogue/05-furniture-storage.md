# Furniture and storage

[Catalogue](README.md) · [Shared characteristics](CHARACTERISTICS.md) · Proposed asset kinds, 2026-09-18.

Furniture provides useful positions and surfaces. Storage is a capability shared by shelves, bags and boxes; it requires explicit capacity and permissions rather than visual guesses.

All rows inherit the shared identity, ownership, presentation, accessibility and lifecycle characteristics where applicable. The fields below distinguish this kind. Interactions describe intended behavior, not implemented capabilities.

| ID | Kind and description | Treatment | Distinguishing characteristics | Interactions and states |
| --- | --- | --- | --- | --- |
| FUR-01 | **Chair and stool.** Single-person seat for work or leisure. | Movable | Seat and entry anchors, occupant size, pose, footprint and stackability if supported. | Sit/stand/reposition; occupied furniture cannot be moved without resolving use. |
| FUR-02 | **Bench and sofa.** Shared seating with individually usable positions. | Movable | Seat count/anchors, spacing, approach, upholstery and social arrangement. | Sit/leave per slot; shared use does not allow removal. |
| FUR-03 | **Table and desk.** Surface for work, dining or display. | Movable | Height, usable surface slots, knee clearance, capacity and cable/tool mounts. | Place authorized objects on surface; moving with contents needs a declared rule. |
| FUR-04 | **Workbench.** Task surface with compatible tool and project positions. | Movable | Working anchors, tool mounts, supported activities, surface slots and reservation policy. | Reserve/use/release; idle/reserved/occupied; does not grant project access. |
| FUR-05 | **Bed and resting furniture.** Private or shared place for resting poses. | Movable | Rest positions, entry side, occupancy, bedding variants and privacy. | Rest/leave; sleep needs are optional simulation, not required by the asset. |
| FUR-06 | **Shelf and bookcase.** Visible storage organized into reachable compartments. | Movable | Compartments, accepted sizes, capacity, display arrangement and access. | Store/retrieve/rearrange; contents preserve individual owners. |
| FUR-07 | **Cabinet, drawer and locker.** Enclosed storage with private access. | Movable | Compartments, door motion, capacity, lock grants and contents visibility. | Open/lock/store/retrieve; private contents never exposed solely by visual proximity. |
| FUR-08 | **Box and crate.** Portable container for goods and projects. | Portable | Outer carry class, inner capacity, accepted items, lid and label. | Pack/carry/unpack; no cyclic nesting; content rights constrain sale and movement. |
| FUR-09 | **Bag and backpack.** Resident-carried storage with equipment attachment. | Portable | Wear slot, carry capacity, compartments, contents access and silhouette. | Equip/store/retrieve/unequip; bag ownership does not override contents ownership. |
| FUR-10 | **Lamp and decorative light.** Resident-owned light for a room or surface. | Portable | Support/mount, light color, switching, illumination range and power representation. | Place/switch/store; lit/unlit; quality tiers may simplify light rendering. |
| FUR-11 | **Rug, curtain and room divider.** Soft decoration and spatial separation. | Movable | Surface/mount, coverage, pattern, clearance and opening motion if applicable. | Place/customize/open curtain; do not conceal blocked navigation in placement preview. |
