# Asset and prop catalogue

Design catalogue · 2026-09-18 · proposed content, not implemented inventory.

This catalogue describes the reusable kinds of things needed to populate Agentnagar. It separates an object's purpose and rules from its visual style. A clay book and a voxel book may express the same readable, portable object; changing a city's style must not change ownership, contents, or permissions.

## Direction and scope

Confirmed in the design conversation: residents should eventually be able to pick up, move, own, and store most small objects. Selected meaningful objects may come first. Ownership prevents unauthorized taking by default. Owners should be able to exchange goods using in-game coins.

The individual asset definitions, capability rules, and production priorities below are proposals for review. They do not approve an implementation or change [RD01's first slice](../../planning/VISION_DECISIONS.md): walking the city and observing the Guild at work. Registered interaction remains subject to tier and authority; scenery is not automatically usable by anonymous visitors.

“Coins” here means the existing city-credit concept. The name remains open. [RD07/RD08](../../planning/VISION_DECISIONS.md) already allow earned, purchased, and tier-included credits and spending on items and services. This catalogue does not introduce a second currency, set prices, resolve transfer restrictions, or adopt the earlier conversational suggestion of internal-only currency. See the [economy brief](../ECONOMY.md).

## Browse the catalogue

| Family | What it covers |
| --- | --- |
| [Terrain and nature](01-terrain-nature.md) | Ground, water, vegetation, natural landmarks |
| [Routes and infrastructure](02-routes-infrastructure.md) | Streets, paths, bridges, utilities, civic equipment |
| [Buildings and rooms](03-buildings-rooms.md) | Reusable premises and spaces for city facilities |
| [Architectural components](04-architectural-components.md) | Walls, floors, doors, windows, stairs and access |
| [Furniture and storage](05-furniture-storage.md) | Seating, work surfaces, domestic furniture and containers |
| [Tools and equipment](06-tools-equipment.md) | Hand tools, machines, devices and workshop equipment |
| [Small objects and goods](07-small-objects-goods.md) | Books, artifacts, materials, personal and everyday props |
| [Residents and appearance](08-residents-appearance.md) | People, agent representations, clothing and expression |
| [Vehicles and logistics](09-vehicles-logistics.md) | Personal mobility, transit and goods handling |
| [Information and services](10-information-services.md) | Signs, boards, kiosks and spatial access to services |
| [Leisure and community](11-leisure-community.md) | Games, gardening, exhibitions and public gatherings |
| [Atmosphere and effects](12-atmosphere-effects.md) | Lighting, sound, weather and feedback |

Read the [shared characteristics](CHARACTERISTICS.md) before interpreting a family table. Each entry inherits those characteristics and adds its own. [Starter collection](STARTER_COLLECTION.md) identifies a bounded representative set and the scenarios it should eventually support. [Authoring template](ASSET_TEMPLATE.md) provides a Markdown specification for individual assets.

For a concrete production breakdown, use the [first Guild scene asset sheet and tracker](FIRST_GUILD_SCENE.md): 60 proposed deliverables with numbered specifications, separate build/test/review statuses, attention items and evidence slots. Its [pinned concept-art reference index](FIRST_GUILD_STYLE_REFERENCES.md) covers all thirty existing styles. Production follows those styles; the humanoid experiment is excluded as a reference for this scene.

## Reading an entry

Each row has a stable catalogue ID, a description, distinguishing characteristics, and proposed interactions/states. A row describes an **asset kind**, not a finished mesh, a quantity to produce, or a complete implementation schema. Specific sizes, prices, capacities, animation timings, and device budgets must be established for individual assets and validated in a representative scene.

Treatment codes describe the default, not a permanent limitation:

- **Fixed:** placed or modified through authorized world editing; not pocket inventory.
- **Movable:** repositioned through an authorized placement action; generally furniture or equipment.
- **Portable:** may move between world placement, hands, equipment slots, and storage if permissions and capacity allow.
- **Entity:** a resident or moving vehicle with identity and activity; not ordinary scenery.
- **Effect:** presentation attached to a place, event, or entity; not an owned item.

All families are in the long-term catalogue. “Portable” does not promise that its interactions ship in the first slice. An initial scenery representation must not imply that its ownership or contents are already simulated.

## How this fits the city

The [facility catalogue](../../vision/CITY_PLAN.md) defines operators, admission, funding, and services. These asset families supply the physical places and objects used by those facilities; a library service can occupy a room before it has its own building. A building asset is not a service entitlement.

The [thirty visual studies](../../vision/style-studies/README.md) guide presentation. Asset definitions should support a selected first style and later variants without requiring thirty complete asset libraries immediately. Model geometry, authored animation, accessible interaction, service permissions, and device performance still need separate validation.
