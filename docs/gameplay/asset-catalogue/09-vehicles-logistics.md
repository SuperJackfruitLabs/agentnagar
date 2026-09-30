# Vehicles and logistics

[Catalogue](README.md) · [Shared characteristics](CHARACTERISTICS.md) · Proposed asset kinds, 2026-09-18.

Vehicles are persistent entities or scheduled service representations. Passenger rights, driving rights, cargo access and ownership are separate capabilities.

All rows inherit the shared identity, ownership, presentation, accessibility and lifecycle characteristics where applicable. The fields below distinguish this kind. Interactions describe intended behavior, not implemented capabilities.

| ID | Kind and description | Treatment | Distinguishing characteristics | Interactions and states |
| --- | --- | --- | --- | --- |
| VEH-01 | **Bicycle and small personal vehicle.** Resident mobility object that can be parked or stored. | Entity | Rider anchors, dimensions, route compatibility, parking footprint and optional charge. | Mount/ride/park; borrow or own; pocket storage only for an explicit compatible variant. |
| VEH-02 | **Passenger car and service van.** Road vehicle for people or permitted deliveries. | Entity | Seats, doors, route bounds, cargo volume, operator grants and turning clearance. | Board/drive/exit/load; occupied and parked states; ownership does not authorize every route. |
| VEH-03 | **Tram and bus.** Shared transit vehicle connecting stops. | Entity | Route, passenger slots, boarding anchors, doors, schedule and interior views. | Board/ride/exit; preserve riders during interruption; service fare policy separate. |
| VEH-04 | **Ferry and boat.** Water transport with passenger or cargo capacity. | Entity | Berth compatibility, draft/clearance representation, seats, deck bounds and route. | Board/dock/ride/load; water route and recovery rules required. |
| VEH-05 | **Handcart and trolley.** Manual goods carrier for larger movable objects. | Movable | Handle, loading area, accepted loads, clearance and push animation. | Load/push/unload with item rights; no duplication between cart and storage. |
| VEH-06 | **Transit stop and shelter.** Boarding destination with route information and waiting space. | Fixed | Platform edge, boarding anchors, shelter, seats, route links and accessibility. | Inspect service/wait/board; out-of-service state must be visible. |
| VEH-07 | **Parking rack and charging bay.** Reserved resting point for compatible vehicles. | Fixed | Vehicle fit, slots, lock grants, charging connector and occupancy. | Park/lock/retrieve; parking grants do not transfer vehicle ownership. |
| VEH-08 | **Cargo pallet and loading frame.** Attachment platform grouping authorized goods for movement. | Movable | Load footprint, restraints, capacity and contents manifest. | Load/move/unload; movement and sale require rights to the included goods. |
