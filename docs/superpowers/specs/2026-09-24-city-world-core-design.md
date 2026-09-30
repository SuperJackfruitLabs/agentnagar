# City world core — a style-agnostic, dynamic simulation

Design specification · 2026-09-24 · sub-project 1 of the "next level"

## Approved direction

Rakesh reviewed the voxel work-bay and hall pilot (PRs #17–#21) and judged that
it proved the basic mechanics: agents at desks, moving on fixed paths. He asked
to level it up into **proper game mechanics that work with any visual style**,
for **a dynamic world where agents and humans keep coming and going**, and to
integrate SJL Labs projects into the city only **after** that level is reached.

In the same conversation he decided:

- The simulation core is written in **Rust**.
- Real-time rooms are served by **our own Rust server**, not Colyseus,
  SpacetimeDB or Nakama.
- The style-agnostic proof uses **11 low-poly tropical diorama** (3D) and
  **08 pixel art** (2D).
- This sub-project comes first, and this document is its specification.

These are recorded as RD18 in the decision register. Anything not listed above
is a proposal in this document, open to change at review.

## Why the pilot cannot simply be extended

The merged hall is a fixed diorama. Its layout is baked in Blender, fourteen
seats are hard-coded and the hall deliberately fails on a fifteenth resident.
Movement is hand-placed waypoints, appearance is bespoke per resident, and
mechanics and voxel meshes are one thing.

The vision describes something else: ten districts and twenty-five facilities;
Guild agents working across eleven of them; personal agents that any registered
person can add, private to their owner (RD12); city-role agents; simulated
citizens; anonymous observers who only watch (RD03); registered people and
residents who come and go. The architecture briefs already call for a headless,
deterministic simulation core separate from any renderer
(`architecture/TOOLS.md`, `gameplay/MECHANICS.md`). This sub-project builds it.

## Scope

**In scope:** a Rust workspace containing the pure simulation core, its
versioned contracts, a headless runner and inspector on the command line, and
the same operations exposed over MCP.

**Out of scope for this sub-project**, each its own later sub-project:

| Later sub-project | What it adds |
| --- | --- |
| 2. Occupancy and movement | Real paths inside rooms, navigation meshes and crowd avoidance |
| 3. Style packs | Presentation adapters, the low-poly and pixel-art packs and a text/map view — the proof |
| 4. Multi-room city | `city-server`, rooms over WebSocket, portals and streaming |
| 5. Humans | A modular avatar kit and observer visibility (needs an RD03 decision) |
| After this level | SJL integration: a real presence feed from AgentPod or Superpipeline |

Nothing in this sub-project renders anything, opens a network socket or reads
a clock. That is deliberate: it is what lets the same core run on a server,
compiled to WebAssembly, or inside a test.

## Workspace

A Cargo workspace at `agentnagar/city/`, beside rather than inside
`prototypes/`, because this is the core rather than a pilot.

| Crate | Responsibility | Depends on |
| --- | --- | --- |
| `city-contracts` | Versioned data types: place manifest, presence feed, commands, events, viewer projections. JSON Schema export. | `serde`, `schemars` |
| `city-core` | The simulation rules. No file, network, clock or thread use. | `city-contracts`, a seeded RNG |
| `city-cli` | The `city` binary: run, inspect, snapshot, diff, validate, schema. | `city-core`, `clap` |
| `city-mcp` | An MCP server exposing the CLI's operations as tools. | `city-core`, `rmcp` |

`city-core` must build for `wasm32-unknown-unknown`. A CI-equivalent check
compiles it for that target so a stray dependency on the operating system is
caught immediately.

## Data model

### Identity

Every entity has a stable **city ID**: an opaque string such as
`agent:coder-kai` or `person:0f3a…`. A city ID never changes when the entity's
underlying runtime changes; a Guild agent migrating to a new AgentPod station
keeps its city ID. Runtime identifiers are never part of a city ID and never
appear in a public projection.

### Occupants

An occupant is anything that can be present in a place.

| Kind | Examples | Default visibility |
| --- | --- | --- |
| `GuildAgent` | The fourteen Guild agents, the first public cohort | Public |
| `CityRoleAgent` | Librarian, tutor, dispatcher | Public, badged as AI |
| `PersonalAgent` | An agent a registered person added | **Owner only**, unless shared (RD12) |
| `SimCitizen` | Scenery and routines | Public, badged as simulation, never counted as attendance |
| `Human` | Observer, registered, resident | Per the viewer rules below |

Each occupant carries: city ID, kind, display name, an optional owner (for a
personal agent), a sharing grant list, a role, and an optional **home place**
and **work place**. Appearance is **not** part of the core. A style pack maps
an occupant's kind, role and appearance parameters to assets; the core stores
only opaque appearance parameters it never interprets.

### Places

Places form a strict tree: **city → district → facility → room → seat**. Every
node has a stable place ID.

- A **room** has a capacity, a set of seats, an optional overflow room, and
  a list of adjacent rooms joined by named **doors**.
- A **seat** belongs to exactly one room, may belong to a **pod**, and is either
  `Hot` (anyone permitted may take it) or `Reserved` (for one named occupant).
- A **pod** is a group of seats with an optional **department** tag, such as
  `making` or `knowledge`. Departments are data, not code.

The place manifest supplies all of this. The fourteen-seat hall becomes one
manifest; a different facility is a different manifest, not a code change.

### Presence

Presence follows the honest-presence model in `gameplay/AGENT_CITY.md`. Each
occupant has three independent dimensions:

| Dimension | Values |
| --- | --- |
| Connection | `Connected`, `Disconnected`, `Unknown` |
| Process health | `Running`, `Stopped`, `Error`, `Unknown` |
| Task state | `Working`, `Waiting`, `Queued`, `Idle`, `Done`, `Unknown` |

Every observation carries `observedAt`, `fetchedAt` and `expiresAt` in
simulation time, plus the source and its version. The core derives what is
**shown**:

- An observation past `expiresAt` makes that dimension `Stale`, never its last
  value.
- A running process with no task observation shows task state `Unknown`, never
  `Working`.
- `Idle`, `Stale`, `Offline` and `Unknown` are distinct shown states.

For a public viewer, a redacted task and a genuinely idle one must be
indistinguishable if distinguishing them would itself leak something. The
default is closed: a task summary is public only when explicitly marked public.

## Rules

The core advances in fixed ticks. Each tick applies, in order:

1. **Ingest** presence-feed events due at or before this tick.
2. **Expire** observations whose `expiresAt` has passed.
3. **Admit**: occupants who have arrived request entry to a room.
4. **Allocate** seats to admitted occupants who need one.
5. **Transition** occupants moving between rooms. At this level a transition is
   a timed move through a door; geometry comes in sub-project 2.
6. **Depart** occupants who have left, releasing their seats.
7. **Emit** events for everything that changed.

### Seat allocation

- A reserved seat goes only to its named occupant. If they are absent it stays
  empty; it is not given away.
- A hot seat is assigned by a deterministic policy: prefer the occupant's
  department pod, then the pod with most free seats, then the lowest seat ID.
  The policy is a named, replaceable rule.
- When a room is full, the occupant tries its overflow room, then that room's
  overflow, along the chain. Chains may not form a cycle. If every room in the
  chain is full, the occupant joins the **original** room's **waitlist**,
  served first-in first-out.
- A room never holds more occupants than its capacity.

### Departure

Departure releases the seat and emits an event. A departed occupant keeps its
city ID and history; re-arrival is a new presence, not a resurrection.

## Views, not state

The core never hands out raw world state. It produces a **projection for a
viewer**:

| Viewer | Sees |
| --- | --- |
| Public observer | Public occupants, their public fields and shown presence; no personal agents |
| Registered person | As public, plus any personal agents whose owners have shared them with this person |
| Owner | As registered, plus their own personal agents |
| Operator (diagnostics) | Full state, only through the CLI or MCP with an explicit operator flag; never through a player-facing path |

A private personal agent does not exist in any view but its owner's and those
it is shared with. This is RD12 enforced by construction: no renderer, style
pack or client can leak what it was never given.

## Determinism

- Fixed tick; simulation time is a tick count, never the host clock.
- All randomness comes from one seeded ChaCha RNG owned by the world.
- All iteration is in stable-ID order. Stores are ordered maps keyed by ID; no
  hash-map iteration order reaches the rules.
- No floating-point value affects a rule decision in this sub-project. Timings
  are integer ticks.

**No ECS framework in this sub-project.** Plain ordered data structures make
determinism trivially true. `bevy_ecs` would add parallel scheduling, which
brings ordering hazards and solves no problem at this scale. If profiling ever
demands an ECS, the pure core can adopt one behind the same contracts.

## Contracts

All contract types live in `city-contracts`, derive `serde` and `schemars`,
and carry a schema version.

| Contract | Format | Purpose |
| --- | --- | --- |
| Place manifest | JSON, versioned | Describes the tree of places, capacities, seats, pods, doors |
| Presence feed | JSON Lines, one event per line, versioned | Arrivals, departures and observations over time |
| Command | JSON | A request from a client or tool to the world |
| Event | JSON | What changed; the world's output |
| Projection | JSON | A viewer's view of the world |

`city schema` exports JSON Schema for each, so the Godot and web clients can
validate what they receive.

The presence feed begins as **labelled fixture files**. Every fixture feed
declares itself as a fixture and every event from one is tagged, so a fixture
can never be mistaken for real agent state. A future real feed (W1) must
satisfy the same contract.

## Command line

The `city` binary returns JSON on standard output and a meaningful exit status.

| Command | Does |
| --- | --- |
| `city validate <manifest>` | Checks a manifest against its schema and structural rules |
| `city run --manifest M --feed F --seed S --ticks N [--snapshot-every K] --out DIR` | Runs headless; writes the event log, the final snapshot and, if asked, a snapshot every K ticks |
| `city inspect <snapshot> [--room R \| --occupant O \| --viewer V]` | Reads a room, an occupant or a viewer's projection |
| `city diff A B` | Compares two snapshots and reports what changed |
| `city schema [--out DIR]` | Exports JSON Schema for every contract |

Structural validation in `city validate` includes: every seat belongs to one
room; reserved seats name a real occupant; doors connect real rooms; overflow
rooms exist and do not form a cycle.

## MCP

`city-mcp` exposes the same operations as MCP tools through `rmcp`: `validate`,
`run`, `inspect`, `diff` and `schema`. They call the same library
functions as the CLI, so the two can never disagree. This meets the admission
rule in `architecture/AGENT_TOOLING.md`: a CLI and an MCP interface over one
domain contract.

Read operations are safe by default. `run` writes only inside a caller-named
output directory. The operator projection requires an explicit flag on both
interfaces.

## Testing

### Invariants, as property tests

Generated manifests and feeds, checked after every tick:

1. No room ever holds more occupants than its capacity.
2. A reserved seat is only ever held by its named occupant.
3. A personal agent never appears in a projection for a viewer who is neither
   its owner nor a grantee.
4. An observation past its `expiresAt` is never shown as its last value.
5. A running process with no task observation is never shown as `Working`.
6. The same manifest, feed and seed produce a byte-identical event log.
7. Every departure releases exactly the seat that was held.

### Scenario tests

Hand-written fixture feeds for named situations: a room filling to overflow and
draining; a waitlist being served in order; a reserved seat staying empty while
its owner is away; a stale feed; a personal agent visible to its owner only.

### Scale

Synthetic runs at 100, 1,000 and 10,000 occupants, on the benchmark ladder in
`architecture/PLATFORMS.md`, recording tick time. These establish where the
core stands; they are not capacity promises.

### Portability

`city-core` compiles for `wasm32-unknown-unknown`.

## Gate

This sub-project is complete when a scripted run across two rooms shows agents
and humans arriving, being seated by capacity, going idle and stale,
overflowing and leaving; when it is deterministic from its seed; when all seven
invariants hold under property testing; and when an agent can run and inspect
it through both the CLI and MCP.

## Acceptance boundary

Nothing here is a player-facing feature and nothing is accepted by being built.
Fixture feeds are labelled as fixtures. No agent's real work state is read.
The core makes no claim about any real agent, human or service.

## Open questions this sub-project does not settle

- **RD03:** whether anonymous observers are visible to each other. The model
  supports either; the default projection hides observers from each other until
  decided.
- **RD12:** what "share" grants for a personal agent. The core supports a grant
  list with a minimal "can see presence" grant; richer grants wait for a
  decision.
- **Crate choices for later sub-projects**, including navigation (`landmass`
  is the leading candidate; it must pass a determinism test before it is used)
  and networking. Those are decided in their own specifications.

## Settled during implementation (2026-09-24)

These were settled while building the core and after its final review. They
refine this specification, and each is open to Rakesh's review.

- **Hidden occupants take no shared capacity.** Private personal agents and
  anonymous observers are present in rooms as overlays: they take no seat, do
  not count toward capacity, and never overflow or wait. Otherwise a public
  view reveals them by inference, through a room that looks full or a seat
  that looks taken. This supports RD12 and the RD03 default; if RD03 makes
  observers visible, they would take capacity again.
- **Waitlists stay first-in, first-out across the overflow chain.** The head
  of a room's waitlist takes the first room in that room's chain that opens.
  A newcomer never overtakes a waitlist, except the owner of a reserved seat
  in that room, whose capacity is held for them.
- **Door arrivals are admitted on the tick they arrive**, in the Admit phase,
  so an occupant is always in a room, a queue or transit when a tick ends.
- **`diff` is an operator view.** Snapshots hold full state, so comparing them
  needs the same explicit operator flag as the operator projection.
- **Task summaries disappear once stale**, even where they were public.
- **Door transits are limited to 1–1,000,000 ticks**, so manifest input cannot
  overflow simulation time.

