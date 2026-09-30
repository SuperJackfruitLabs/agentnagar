# Mechanics discussion agenda

Recorded 2026-09-18 · Discussion inventory, not an approved implementation plan.

The asset catalogue describes what can exist. This agenda records the mechanics we still need to discuss: what residents do with those assets, what changes as a result, and why they return. It complements the existing [gameplay proposals](../gameplay/MECHANICS.md) and [larger world systems](../gameplay/WORLD_SYSTEMS.md); it does not replace their GM01–GM13 identifiers or treat their recommendations as accepted decisions.

## Starting position

- Ten [visual directions](../vision/style-studies/README.md) have been explored. A first production style is not selected; owner-selectable styles are the intended longer-term direction.
- The [asset catalogue](../gameplay/asset-catalogue/README.md) documents 108 proposed kinds and their characteristics. Catalogue entries are not finished assets or implemented capabilities.
- Residents should eventually be able to pick up, move, own and store most small objects. Selected meaningful objects may come first.
- Ownership should prevent unauthorized taking by default. Owners should be able to exchange goods using in-game coins. Detailed storage, borrowing and transaction rules remain proposals.
- Presentation should adapt across ordinary PCs, gaming PCs, handhelds, mobile, browser and future VR/AR. Mobile/browser may prioritize exploration, communication, agent interaction and lightweight edits. No supported device matrix or performance guarantee is established.
- Existing [RD01–RD17 decisions](VISION_DECISIONS.md) remain in force. In particular, the first slice is walking the city and observing the fourteen Guild agents at real work; public visitors observe, registered users interact according to tier and authority, and comments/messages/assemblies are core.
- Credits can already be earned, bought or included with tiers and spent on items and services under RD07/RD08. Coin naming, pricing and transfer consequences remain open. This agenda does not reopen purchased credits as an undecided feature or introduce a second currency.

## Discussion map

MA identifiers are agenda references, not new approved mechanics. Every topic below needs decisions about its detailed rules, even when its broad direction is already chosen.

| ID | Topic | Decisions to discuss | Existing starting point |
| --- | --- | --- | --- |
| MA01 | Movement and exploration | First/third-person control; transitions between map, top, diagonal and street views; entering buildings; fast travel; vehicles; visiting other cities | [Experiences](../vision/EXPERIENCES.md), [platforms](../architecture/PLATFORMS.md) |
| MA02 | Building and decorating | Finished buildings, modular pieces or freeform geometry; placement and snapping; terrain editing; cooperative construction; undo; publishing changes | GM02/GM03 in [mechanics](../gameplay/MECHANICS.md); [asset catalogue](../gameplay/asset-catalogue/README.md) |
| MA03 | Inventory and storage | Carry limits; bags and containers; shared storage; borrowing; delivery; disconnected residents; moving containers with other owners' items | [Shared asset characteristics](../gameplay/asset-catalogue/CHARACTERISTICS.md) |
| MA04 | Crafting and production | Recipes versus open-ended creation; materials and tools; production time; quality; repair; ownership of outputs | GM06/GM08 in [world systems](../gameplay/WORLD_SYSTEMS.md); [tools](../gameplay/asset-catalogue/06-tools-equipment.md) |
| MA05 | Trade and businesses | Direct sales, shops, commissions, rentals, stock, prices, delivery, refunds and agent-operated businesses | [Economy](../gameplay/ECONOMY.md), [market facility F09](../vision/CITY_PLAN.md) |
| MA06 | Work and rewards | Activities earning coins; funding sources; job acceptance; linking real contributions to world rewards; rejection and reversal | [Operating model](../vision/OPERATING_MODEL.md), GM01/GM11/GM12 in [mechanics](../gameplay/MECHANICS.md) |
| MA07 | Skills and progression | Professions; apprenticeships; unlocks; reputation; whether progression changes abilities, expression or both | GM01 in [world systems](../gameplay/WORLD_SYSTEMS.md), [residency](../gameplay/RESIDENCY.md) |
| MA08 | Agent behavior and delegation | Routines; conversation and memory; autonomous purchases; task assignment; spending limits; approval boundaries; relation of visible behavior to real work | [Guild residents](../vision/GUILD_RESIDENTS.md), [agent city](../gameplay/AGENT_CITY.md), GM11 |
| MA09 | Social life | Friends, clubs, proximity conversation, invitations, assemblies, shared activities, privacy and personal boundaries | GM05 in [world systems](../gameplay/WORLD_SYSTEMS.md), [community charter](../vision/COMMUNITY_CHARTER.md) |
| MA10 | City simulation | Population needs; transport; utilities; ecology; maintenance; disasters; how much these affect residents and their belongings | [Civic simulation](../gameplay/CIVIC_SIMULATION.md), GM03/GM04/GM06 in [world systems](../gameplay/WORLD_SYSTEMS.md) |
| MA11 | Governance and shared spaces | Who edits public areas, approves buildings, allocates budgets, resolves disputes and reverses harmful changes; scope of elections | [Community charter](../vision/COMMUNITY_CHARTER.md), GM10 in [world systems](../gameplay/WORLD_SYSTEMS.md) |
| MA12 | Time and persistence | Day/night; offline progress; scheduled activities; inactive homes; abandoned projects; returning after an absence | [People and daily life](../vision/PEOPLE_AND_DAILY_LIFE.md), [residency](../gameplay/RESIDENCY.md), [storage](../architecture/STORAGE.md) |
| MA13 | Discovery and community activities | Expeditions, festivals, games, exhibitions, research, inventions and meaningful solo/asynchronous activities | GM07/GM08/GM12/GM13 in [world systems](../gameplay/WORLD_SYSTEMS.md), [city facilities](../vision/CITY_PLAN.md) |
| MA14 | Creator publishing and automation | Custom assets, reusable building kits, scripted behaviors, inter-city sharing, compatibility, updates and rollback | GM09/GM13 in [mechanics](../gameplay/MECHANICS.md), [tools](../architecture/TOOLS.md), [community charter](../vision/COMMUNITY_CHARTER.md) |

## Questions that cross every mechanic

### Consequences and recovery

Can objects break, projects fail or goods be lost? Which consequences are reversible, who can undo them, and what compensation or recovery exists? Separate fictional damage from deletion of real work and service data. Free physics, wear and disasters are not implicit requirements just because an asset has material or condition characteristics.

### Permissions and authority

Which actions are personal, shared, delegated, or reserved for city operators? Specify permission separately for viewing, using, moving, editing, borrowing, spending, selling and deleting. Entering a room should not imply access to its contents. A resident's agent needs explicit delegated authority; city governance does not automatically grant repository or infrastructure authority.

### Device interaction and accessibility

How does the same action work with touch, keyboard/mouse, controller and eventually spatial input? Decide which experiences have lightweight equivalents and which may be unavailable on a particular client. Ownership and accepted state must remain consistent even when fidelity differs. Include readable labels, non-color cues, captions, reduced motion and alternatives to precise dragging or gestures.

### World continuity

What travels with a resident between cities: belongings, currency, reputation, identity and appearance? Do cities share rules, merely compatible asset definitions, or separate economies? Decide how a receiving city's style and permissions affect imported items without silently changing ownership or duplicating goods. Multiple-city travel and federation remain discussion topics, not an implemented world structure.

### Shared state and interruption

For each mechanic, define what happens if two residents act at once, a connection drops, an agent's budget runs out, or a backing service is unavailable. Distinguish pending local feedback from accepted durable state. Identify which activity continues offline and what the returning resident sees.

## Suggested discussion order

This is an order for resolving design dependencies, not a release schedule. It does not supersede RD01.

1. **Building/decorating and movement (MA02/MA01):** settle the primary creation model, spatial scale, camera/control transitions, entries and usable geometry. These shape the asset production requirements.
2. **Inventory and crafting (MA03/MA04):** define possession, storage, material use and how new objects come into existence.
3. **Trade, rewards and progression (MA05/MA06/MA07):** connect the creation and ownership rules to funded earning, spending and lasting progress.
4. **Agent delegation and social life (MA08/MA09):** decide what agents may do for people and how residents share places and activities.
5. **Simulation, governance and persistence (MA10/MA11/MA12):** establish world consequences, shared authority, time and long-term continuity. Their basic recovery and permission constraints must already inform earlier topics.
6. **Discovery and creator extensions (MA13/MA14):** expand the established rules into activities, reusable creations and bounded automation.

For the approved first slice, movement, public work-state presentation and observation/access boundaries still take implementation priority after approval. No inventory or economy completion is required merely to let someone walk and observe.

The recommended next discussion is **MA02: do residents primarily build with finished buildings, modular architectural pieces, freeform geometry, or a deliberately chosen combination?** That choice has not yet been made.

## What to record for each discussion

For every topic, capture:

1. The resident's purpose and a short end-to-end example.
2. Available actions, prerequisites and resulting state changes.
3. Who owns the objects or records and who may perform each action.
4. Time, resource, storage and coin costs where applicable, with unresolved values clearly identified.
5. Failure, cancellation, concurrency, undo and reconnect outcomes.
6. Device and accessibility variants, plus relevant visual-style constraints.
7. A proposed initial scope and explicitly retained later possibilities.
8. The user's decisions, remaining questions and the owning documents to update.

Record accepted decisions in the [decision register](VISION_DECISIONS.md) and update the owning gameplay/architecture briefs. Keep this agenda as the navigation and status record. Draft prose, catalogue completeness and attractive concept images do not constitute approval to implement.
