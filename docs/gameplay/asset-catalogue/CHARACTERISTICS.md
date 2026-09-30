# Shared asset characteristics

[Catalogue](README.md) · Design proposal, 2026-09-18.

## Definition, instance, and presentation

An **asset definition** describes a reusable kind: its permitted capabilities, physical requirements, and available variants. An **instance** is one particular object with a stable identity, owner, location, contents, and current state. A **presentation variant** gives that definition a visual style and device-appropriate representation.

Changing presentation must not create another owned object or reset its state. A template or blueprint may create new instances only through an authorized creation process; copying visual files does not duplicate inventory or coins. Authorship and asset licensing are separate from ownership of an in-world instance.

## Common record

| Group | Characteristics to specify | Meaning |
| --- | --- | --- |
| Identity | Definition ID, instance ID, version, name, family, tags | Stable identity survives movement, storage, style changes and reconnects |
| Description | Purpose, appearance, use instructions, distinguishing features | Human-readable description and accessible inspection text |
| Origin | Creator, source, rights, attribution, provenance | Who made the asset and which reuse is permitted; no assumed repository-wide licence |
| Geometry | Dimensions, footprint, bounds, pivot, orientation, collision shape | Placement and usable space; decorative geometry may differ from collision |
| Connections | Entry points, grip points, seats, mounts, surface slots, network connectors | Where residents and other objects connect |
| Handling | Fixed/movable/portable/entity/effect, carry size, optional weight, supported grips | How the object can move; numeric weight need not imply a physics simulation |
| Placement | Floor/wall/ceiling/table/water support, clearance, allowed rotation, snapping | Where placement is valid, including exit and access clearance |
| Capabilities | Named actions, prerequisites, permission, result, cancellation behavior | What a person or authorized agent can do |
| State | Applicable state fields and legal transitions | No universal “health” or “charge” field on objects that do not need it |
| Ownership | Owner, custodian, shared-use grants, transfer policy | Possession does not imply ownership; public use does not imply free taking |
| Containers | Accepted types, capacity unit, compartments, visibility, access | Store and retrieve exact instances or explicitly fungible quantities |
| Trade | Eligibility, included contents, listing state, seller, delivery destination | Does not set a default price or allow sale of borrowed property |
| Persistence | Saved fields, temporary fields, recovery behavior, history visibility | Durable arrangement and ownership separated from transient animation |
| Presentation | Style, palette, materials, icons, animation, sound, readable cues | Includes relevant map, distant, interior and close-up representations |
| Accessibility | Labels, contrast, non-color cues, text alternatives, input alternatives | Dragging, precise pointing, sound and gestures must not be the only action path |
| Device profile | Visual detail variants, fallback, streaming group, resource budget | Proposed budgets established by measurement; no arbitrary universal polygon target |
| Service binding | Reference, source authority, visibility, freshness, allowed actions | A screen or notebook can reference an external record without owning it |
| Lifecycle | Creation, placement, migration, retirement, deletion and recovery | Avoid deleting occupied containers or stranding possessions during removal |

Not every field applies to every family. Natural terrain has no pocket-storage capacity; a sound effect has no seller. Inapplicable characteristics should be explicit rather than filled with fictional values.

## Reusable capabilities

| Capability | Applies to | Contract to describe |
| --- | --- | --- |
| Inspect | Objects and places | Public description versus owner-only contents or metadata |
| Pick up / carry / place | Portable goods | Authorized actor, free hand or inventory space, valid destination |
| Reposition / mount | Furniture and installed objects | Edit rights, occupancy, attachment compatibility, clearance |
| Store / retrieve | Containers and their contents | Item rights plus container access; capacity checked before moving |
| Sit / rest | Seats and beds | Slot occupancy, pose, entry/exit positions and release on disconnect |
| Open / close / lock | Doors, drawers, containers | Independent access rights, occupied doorway behavior, animation state |
| Read / write / display | Books, notebooks, boards, screens | Content access separate from ownership of the physical object |
| Equip / use | Tools and wearables | Compatible slot, prerequisites, active task, safe cancellation |
| Reserve / borrow / return | Shared tools, equipment, books | Owner approval, borrower, return destination, end-of-loan behavior |
| Consume / replenish | Selected supplies | Authorized quantity change; distinguish reusable vessel from contents |
| Sell / gift / transfer | Eligible owned goods | Seller authority, exact sale contents, ownership transfer and delivery |
| Operate / board / exit | Vehicles and machines | Operator authority, passenger or job slots, interruption behavior |

## Ownership, storage, and trading rules

**Confirmed direction:** ownership prevents unauthorized taking. The following are proposed defaults implementing that direction:

- Default deny for pickup, relocation, storage access, sale, and destruction of another owner's property. An explicit grant can allow one action without granting all of them. Agent actions use the same rules and delegated authority.
- Permission to enter a room is not permission to take its contents. Permission to use a chair is not permission to sell it. World-edit permission alone should not silently override someone else's item ownership.
- A world object, carried object, equipped object, and stored object are locations of the same instance. An instance has one location at a time. Reconnect or repeated commands must not duplicate it.
- Capacity and destination access are checked before movement. Full inventory leaves the object at its previous location. A disconnected resident's possessions remain recoverable rather than dropping into public ownership.
- Containers cannot contain themselves or form cycles. Ownership of a container does not automatically change ownership of items inside it. Moving a mixed-ownership container needs authority over the contents; otherwise movement is blocked.
- Listing a container must declare whether it is empty or includes a specific eligible contents set. Objects may be transferred in place only where the new owner has the necessary access and occupancy rights.
- Sale eligibility excludes borrowed, reserved-for-another-purpose, non-transferable, or unauthorized objects. Listings need rules preventing simultaneous transfer or modification of the promised contents.
- A completed purchase must couple the authorized payment with ownership and delivery. A failed purchase changes neither. The currency ledger, transfer eligibility, fees, refunds and disputes remain economy design work, not decisions made by this catalogue.
- Deleting a building or storage container should first relocate or explicitly resolve its contents. Selling a visual proxy for a project or machine does not transfer repository membership, compute allowance, secrets, or service ownership.

## Activity and simulation

Use **scenery**, **on-demand interaction**, or **ongoing activity** as separate activity levels. Portable objects can remain dormant when nobody is handling them. Do not assign every leaf, cup, or window an independently running agent. Storage retains item records without requiring their meshes to remain loaded.

For an initial interaction collection, use deliberate pickup, inventory, placement previews and attachment points. Free throwing, breakage, liquids, detailed weight balance, fire spread and material processing are later candidates. Describe relevant characteristics now without implying those simulations exist.

## Styles, devices, and views

Keep identity, permissions, contents, usable anchors and accepted placement consistent across style variants. If a variant changes a footprint or entrance, it requires compatibility validation or an explicit migration, not a silent swap. Owner-selected city style is the direction; rules for imported objects retaining their source appearance remain open.

Low visual quality should reduce texture/detail/effects, not grant different ownership or inventory rules. Mobile and browser may prioritize inspection, communication, agent interaction and lightweight edits. Desktop and handhelds need equivalent actions through their own controls. Future VR/AR needs comfortable scale and alternative selection methods; the concept sheets are not proof of support.

Map symbols, top views, diagonal views, street views, interiors, conversation framing, public gatherings, build mode, transit, night/rain, waterfront, facility interaction, mobile, rooftops and AR tabletop all use the same underlying objects. Not every prop needs a map icon, but important destinations and interactive objects must remain identifiable at the relevant scale.
