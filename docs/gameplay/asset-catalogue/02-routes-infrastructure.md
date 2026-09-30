# Routes and infrastructure

[Catalogue](README.md) · [Shared characteristics](CHARACTERISTICS.md) · Proposed asset kinds, 2026-09-18.

Infrastructure connects places and supplies civic services. Its operator and network connections matter more than portable-item ownership. Network simulation can be introduced independently of its visible representation.

All rows inherit the shared identity, ownership, presentation, accessibility and lifecycle characteristics where applicable. The fields below distinguish this kind. Interactions describe intended behavior, not implemented capabilities.

| ID | Kind and description | Treatment | Distinguishing characteristics | Interactions and states |
| --- | --- | --- | --- | --- |
| INF-01 | **Road segment and junction.** Street space for vehicles and crossings. | Fixed | Width, lanes, endpoints, direction, speed class, turn permissions and curb profile. | Edit/connect with civic authority; open/closed states. |
| INF-02 | **Footpath, promenade and cycleway.** Routes for walking and lightweight mobility. | Fixed | Width, slope, connectivity, surface, allowed movement modes and accessible clearance. | Traverse; authorized reroute/closure without stranding placed entrances. |
| INF-03 | **Bridge and footbridge.** Connection crossing water, roads or terrain gaps. | Fixed | Span, endpoints, deck width, clearance below, load class and railings. | Traverse; open/closed; structural failure is optional later simulation. |
| INF-04 | **Crossing and traffic signal.** Coordinated pedestrian and vehicle movement point. | Fixed | Crossing bounds, signal phases, timing, tactile/visual cues and connected junction. | Wait/cross; signal state changes; audible cues need visual alternatives. |
| INF-05 | **Streetlight.** Public lighting attached to a route or square. | Fixed | Mount, illumination area, color, switching schedule and network reference. | On/off/fault; maintenance authority; simplified lower-tier light representation. |
| INF-06 | **Utility line and connection.** Water, power or waste-network link. | Fixed | Network type, connector compatibility, capacity unit and isolation points. | Connect/isolate/inspect; flow and outage behavior are separate simulation work. |
| INF-07 | **Utility plant and substation.** Visible facility equipment serving a district. | Fixed | Service area, connections, operating capacity, maintenance access and status. | Inspect/operate under civic authority; unavailable/service-restored states. |
| INF-08 | **Waste and recycling station.** Public receptacle for selected discarded items. | Fixed | Accepted categories, compartments, capacity and collection point. | Deposit only owned/authorized goods; disposal needs an explicit recovery policy. |
| INF-09 | **Mooring and loading dock.** Transition between land transport, watercraft and goods storage. | Fixed | Berths, vehicle compatibility, loading zone, edge protection and access. | Reserve/board/load with permissions; available/occupied/closed. |
