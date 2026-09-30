# Proposed starter collection

[Catalogue](README.md) · Planning recommendation, not an approved release sequence.

The full catalogue contains 108 kinds across twelve families. A kind is not a promise to build every possible variation. Begin with a coherent style and a small set of reusable assets; add variants after their characteristics and interactions are established.

The [first Guild scene asset sheet and tracker](FIRST_GUILD_SCENE.md) turns the first-scene candidates into a proposed 60-deliverable baseline, with per-item specifications, style references, build/test/review status and unresolved work. It is a bounded courtyard/workshop crop, so water and the larger city remain outside that baseline. Follow the existing concept-art styles; do not use the humanoid experiment for this scene.

## Separate the first city scene from object interaction

The approved first slice remains walking the city and watching the fourteen Guild agents at real work. It needs a visible environment and trustworthy work-state presentation; it does not require an inventory, market or simulated tool use first.

| Collection | Representative kinds | Purpose and limits |
| --- | --- | --- |
| First-scene art candidates | NAT-01 ground, NAT-02 water, NAT-04 tree, INF-02 path, BLD-02 workshop, ARC-01/02/03/04/07/08 building kit, FUR-01 chair, FUR-03 desk, TOOL-04 terminal, RES-01/02 avatars, INFO-01/03 signs and work boards, FX-01/04/05 environment and feedback | Support RD01 with readable places and approved work projections; fourteen distinct Guild appearances may share rigs and modular parts |
| First meaningful-object candidates | OBJ-01 book, OBJ-02 notebook, OBJ-03 artifact, TOOL-01 hand tool, FUR-04 workbench, FUR-06 shelf, FUR-08 box, FUR-09 bag | Exercise portable ownership, storage, borrowing and authorized use; proposed after approval of interaction scope |
| First trade candidates | Owned OBJ-01 books and OBJ-03 artifacts, with INFO-05 sale displays | Exercise fixed-price listings and transfer after inventory and the relevant economy rules exist; no numeric price commitments |
| Later interaction expansion | Everyday OBJ-05/06/07/08/12 props, additional furniture, machines, vehicles, gardening and leisure | Extend proven capabilities to most small objects; physics, crafting and civic simulations have independent scope |

These are membership suggestions, not quantities, dates, asset budgets or a new roadmap. Some natural and interior assets can initially be scenery. A library corner inside a workshop is enough to exercise shelving and borrowing; it need not wait for an entire library building.

## Five representative asset descriptions

### A resident's field notebook — OBJ-02

A recognizable personal notebook with a customizable cover and an optional project reference. Its definition provides a readable page view, carry grip and shelf-compatible size. Its instance stores owner, location and document reference. Writing requires document permission even when the notebook is borrowed. It can move between a desk, hand, bag and shelf without copying the document. A sale is blocked until the seller explicitly defines which physical object and content rights, if any, are included. Empty notebooks can be traded independently of private records.

### A shared workshop screwdriver — TOOL-01

A reusable tool with one grip and a defined set of compatible tasks. The workshop owns the instance; a borrowing grant lets a resident carry and use it without selling it. Its state separates location, loan status and active use. A working position at a compatible bench supplies the use animation. When the resident disconnects, the item remains in their durable inventory and the temporary work position is released. Detailed wear and breakage are optional later characteristics.

### A resident backpack — FUR-09

A wearable container with a declared capacity unit, accepted item classes and an equipment slot. The bag's exterior has style variants, but its contained instance IDs and access rules remain the same. It cannot contain itself or an ancestor container. An attempted pickup into a full bag leaves the object where it was. A bag containing a borrowed tool cannot be sold or handed to another resident without resolving that tool's ownership and loan permissions.

### A workshop project shelf — FUR-06

A movable storage unit with visible compartments, placement bounds and item-support slots. Its public-facing compartments can display approved artifacts while private compartments require access. Objects on the shelf keep their owners and content permissions. Moving the shelf is a distinct authorized edit, not a way to bypass restrictions on its contents. Its voxel, clay or paper variants preserve compatible compartment anchors or require an explicit layout migration.

### A resident-made model bridge — OBJ-03

A portable prototype with creator, project/version reference, material description, footprint and display anchors. Inspection reveals the model and any approved description, not private project files. An eligible owner may offer this exact instance for coins. Listing freezes the promised item and contents against conflicting transfer; purchase transfers the agreed object and payment together to an accessible destination. The physical model can change visual style while retaining creator provenance and ownership history subject to privacy rules.

## Review scenarios for a future prototype

| Scenario | Expected rule to demonstrate |
| --- | --- |
| Another resident tries to take a notebook | Denied unless the owner granted the specific action; ownership unchanged |
| Borrow a tool, carry it, use it, store it and return it | Same instance throughout; workshop stays owner; work and storage permissions checked |
| Two residents pick up the same object | At most one succeeds; the other sees the current accepted location |
| Put a box inside itself or its descendant | Rejected without changing contents |
| Put an object into full storage | Rejected without losing or duplicating the object |
| Move a shelf holding another owner's possessions | Require the necessary contents authority or keep the shelf in place |
| Sell a bag containing borrowed goods | Block until rights and contents are resolved; no indirect unauthorized transfer |
| Two buyers purchase one listed artifact | At most one purchase completes; unsuccessful buyer loses no coins |
| Payment, delivery or connection fails | No half-completed trade; reconnect reveals a single authoritative outcome |
| Remove a home or container with belongings inside | Explicitly resolve and relocate contents before removal |
| View the object on mobile or in a different style | Identity, ownership, contents and accepted location remain unchanged |
| Sell a computer or project notebook | New physical owner receives no implicit account session or private service rights |

These are acceptance scenarios to refine, not tests claimed to have passed.

## Decisions still needed before authoring or implementation

- Pick the first visual style and representative scene; select actual asset variants from the catalogue.
- Establish dimensions, modular increments, avatar rigs and compatible interaction anchors.
- Choose the initial capacity abstraction and limits for nested containers; detailed mass simulation is optional.
- Define first-slice avatar controls and permitted registered-user interactions separately from the full object model.
- Resolve coin-transfer eligibility, listing cancellation, fees, disputes and delivery rules in the economy design. Do not assume every credit balance is transferable.
- Decide how owner-selected city style interacts with imported objects and personal appearance.
- Measure memory, download size, visual readability and responsiveness on representative devices before setting production budgets.
