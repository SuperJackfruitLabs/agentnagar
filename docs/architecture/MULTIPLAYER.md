# Multiplayer and hosting

Design proposal + read-only server inspection · 2026-09-15 · updated
2026-09-18 · [Plan index](../README.md)

**Status, 2026-09-18 (RD15):** no room server, database or host is chosen, and
none is the next step. Colyseus, headless Godot, Durable Objects, Nakama,
PostgreSQL and SQLite below are candidates under continuing evaluation. See
the [evaluation stance](PLATFORMS.md#evaluation-stance). The lab-server check
below is dated evidence, not an allocation.

The initial recommendation was a **small authoritative Colyseus service on
SJL's self-hosted lab server** for a browser courtyard. With native clients in scope, treat this as
a candidate and verify the candidate clients' compatibility alongside a
headless Godot alternative. Keep the
published site and assets on their static host. The lab server has enough CPU
and memory for prototyping, but room capacity and visitor latency have not
been measured.

## Candidates and the evidence each still needs

| Candidate | Use case it is a candidate for | Evidence still needed |
| --- | --- | --- |
| Colyseus (self-hosted) | Small authoritative real-time rooms shared by browser and native clients | Browser and Godot clients on one pinned version (the Godot SDK is beta); durable save semantics; reconnect; load on the candidate host |
| Headless Godot | Sharing game rules between a Godot client and its server | A browser-compatible transport; persistence, accounts and operations built around it; cost of tying the server to one engine |
| Cloudflare Durable Objects | Discrete cooperative edits and presence, one object per room | Cost and behaviour under a continuous simulation loop; recovery model; a global audience's latency (RD11) |
| Nakama | A fuller game backend (accounts, storage, matchmaking) | Whether its account model conflicts with the suite's issuer; operating weight for a solo founder |
| Colyseus managed hosting | Rooms without operating the server | Current plans and price; data location for a global product (RD11) |
| PostgreSQL | Durable city state and a balanced ledger that now meters real compute and storage (RD08) | Backup and restore drill; CLI/MCP adoption checks; commit latency under room load |
| SQLite | An isolated single-process experiment | Nothing further unless such an experiment is authorised; not a production path |

The first slice (RD01) is walking the city and watching the Guild at work. It
may need presence and a read-only work-state feed before it needs shared
editing. Which of the use cases above comes first is therefore open.

## What was checked on the lab server

A read-only inspection on September 15 and 16 looked at the candidate lab
server's CPU, memory, storage, graphics hardware and available runtimes. No
installations, configuration changes, restarts, deployments, load tests,
credential reads or workload jobs were performed. The machine inventory is
kept privately by SJL's infrastructure operators and is deliberately not
reproduced here; the conclusions that matter for the city are:

| Observation | Design implication |
| --- | --- |
| A multi-core x86-64 Linux CPU with ample memory for a bounded prototype | Good candidate for room logic, queues, compilation, mesh processing and small simulations; not a reservation or a capacity benchmark |
| A fast SSD tier and a larger HDD tier | Active state and bounded scratch on SSD; bulk archives, assets and backups on HDD; see the [storage plan](STORAGE.md) |
| No supported GPU | Do not plan CUDA inference on this server |
| Container runtime available | Package new runtimes in isolated containers if the prototype proceeds |
| Existing services already run there | Shared server; protect existing work with resource limits and monitoring |

Existing backup tooling does not establish that any future village data is
covered or restorable. The [storage plan](STORAGE.md) records recovery
requirements.

## What should run where

| Work | Preferred location | Reason |
| --- | --- | --- |
| WebGL drawing, camera, local input | Visitor browser | Lowest interaction latency; no video-streaming service needed |
| Native drawing, camera, local input | Player's desktop | Local rendering with its own quality and asset budgets |
| Solo building and small toy simulation | Browser; Web Worker if profiling warrants it | Works without a server or account |
| Room membership, edit authority, shared scenario | Lab-server room process | One authority per plot/session |
| Saved shared plots and operation history | Lab-server SSD-backed state; HDD archives/backups and tested restore | Reconnect and restart must preserve accepted edits |
| GLB optimization, mesh validation, asset packaging | Bounded lab-server jobs | CPU-friendly batch work away from the founder's laptop |
| Procedural layout searches or precomputed scenarios | Lab-server job worker when measurements justify it | Asynchronous jobs, not part of frame or edit latency |
| Image-to-3D models requiring large NVIDIA VRAM | Hosted demo or separately provisioned GPU | The lab server's RAM is not GPU VRAM |
| Final approved site and assets | Existing static host/CDN | A room outage should not hide product pages |

Blender CPU rendering is possible with an appropriate installation, but can
consume the whole machine for long periods. Benchmark a small job and queue it
behind interactive workloads. Do not expose general shell execution as a
visitor feature.

## Hosting alternatives

| Option | Best fit | Tradeoff | Recommendation |
| --- | --- | --- | --- |
| Colyseus on the lab server | Small real-time rooms, shared simulations, eventual avatar movement | Operate TLS ingress, durable saves and recovery; validate candidate web/native clients | Candidate; an official beta Godot SDK now exists (2026-09-18 note below) |
| Headless Godot on the lab server | Shared game rules if Godot clients were selected | Implement persistence, account integration, operations and compatible web transport | Candidate; compare in any native/web evaluation |
| Cloudflare Durable Objects | Event-driven cooperative editing/presence with one object per room | Different runtime and persistence model; continuous simulation remains active/billable | Strong alternative if room behaviour is mostly discrete edits |
| Colyseus managed hosting | Same room framework with less server operation | Recurring service expense; check current plans when needed | Consider if operating the lab server costs too much founder time |
| Custom WebSocket service | Very small bespoke protocol | Must build synchronization, room lifecycle, reconnect, and operational tooling | Least attractive on current evidence; still a candidate if the frameworks fit poorly |

The last column records the September 15 assessment. Under RD15 none of these
is selected and the evaluation continues.

[Colyseus](https://docs.colyseus.io/) provides authoritative rooms, matchmaking,
and state synchronization, and supports self-hosting. Its synchronized state
does not automatically provide our required durable save/operation semantics.
Use its [room APIs](https://docs.colyseus.io/room),
[deployment guidance](https://docs.colyseus.io/deployment), and
[load-testing tools](https://docs.colyseus.io/tools/loadtest) when implementing;
pin compatible server/client versions before writing SDK code.

**Note, 2026-09-18.** Colyseus now documents an official Godot SDK: a
GDExtension, labelled beta, covering desktop, iOS, Android and web, with
breaking changes still expected
([Colyseus Godot SDK](https://docs.colyseus.io/getting-started/godot)). The
earlier concern that a Godot client had no maintained path is out of date. A
beta SDK still needs the join, edit, retry and reconnect rehearsal described
in the [platform brief](PLATFORMS.md#shared-authority-identity-and-saves).

Cloudflare's [WebSocket hibernation](https://developers.cloudflare.com/durable-objects/best-practices/websockets/)
keeps idle connections without an always-running object. Timers and incoming
events prevent hibernation: an active simulation loop does not become free
because this API exists. If chosen, use one object per room, durable state
recovery, and no global city object. Do not run two competing authorities for
the same plot.

## First multiplayer experience

**Superseded in part, 2026-09-18.** RD01 makes the first slice "walk the city
and watch the Guild at work", not the courtyard below. RD05 makes comments,
messages and assemblies a core part of the experience, so the line below that
defers public rooms and chat no longer sets the order; moderation capacity,
reporting, retention and legal duties are the open questions instead. The
courtyard remains a proposed cooperative-building experience.

- Invite room with a target of **2–8 people**; benchmark before increasing it.
- One 8×8 courtyard, an approved kit, and a modest configurable piece limit.
- Guest, editor, and host roles. The room creator can invite editors, revoke
  editing, remove a disruptive guest, and close the room.
- Shared placement and simple avatars/cursors; optional pings or preset emotes.
- No player-to-player vehicle collisions in the first room.
- Personal plot can be copied into a shared plot. Leaving a room offers a
  local export; it does not silently publish the result into the main city.
- A shared plot survives an empty room and service restart. Presence does not.

Rooms begin as private invitations. Public rooms, chat, voice, and public
blueprint galleries need the matching host/moderation and removal features.
The first cooperative courtyard can establish persistence before a currency or
economy exists. The expanded target now includes the [civic simulation](../gameplay/CIVIC_SIMULATION.md),
with a shared treasury, utilities, service allocation and city growth. These
belong to a city authority; activity rooms must not maintain competing budgets.

AgentPod inspection and the public/resident integration boundary are documented
in [People and agents](../gameplay/AGENT_CITY.md). No existing AgentPod deployment was found
in the lab-server locations checked. Proposed city services, a simulation process,
and bounded voice/asset jobs would be separately operated workloads. Keep the
existing hub independent and benchmark contention before enabling agent or
voice jobs alongside multiplayer.

## Residency and shared rooms

The later [residency pilot](../gameplay/RESIDENCY.md) adds a persistent home for a verified
sponsor and lifestyle grants for further support or accepted contributions.
A visitor can still practise locally and join an invited session. Pilot rooms
can use test accounts and grants before a sponsorship programme exists.

**Updated 2026-09-18.** A one-time residency purchase buys a block for a house
(RD09), and sponsorship is a separate thing that may include residency (RD10).
Read "verified sponsor" above as "verified resident, by purchase or another
accepted route". Public visitors observe agents' work state only (RD03);
interaction with agents starts at a registered account and widens with tier
and authority (RD04). What an anonymous visitor may do in a room beyond
observing is still open.

Visitor/resident identity, room guest/editor/host roles, and lifestyle tier
are separate. Funding a garden house grants its defined appearance and home
features; it does not grant editing rights in another plot or moderation powers.
The room service checks current roles and effective benefits on each relevant
action, including after a grant or role changes during a live session.

Claim a single personal home transactionally, then stream it and its interior
on demand. Store empty homes without an active simulation. Paid gathering
capacity must stay within measured limits; lifetime resident totals are not
concurrent-player capacity. Preserve normal home access and earned creations
after an ordinary sponsorship pause under the proposed policy; expire only
explicitly recurring service extras.

## Authority and synchronization

1. A join flow issues a short-lived session scoped to a room and role. Validate
   origin, payload size, command rate, and permissions on the server.
2. The server returns the compatible world/kit version, current plot snapshot,
   durable revision, and session state. Incompatible clients receive a clear
   update/export path rather than corrupting a save.
3. A placement sends a unique command ID and expected revision. Validate kit
   membership, coordinates, occupancy, rotation, bounds, and edit permission.
4. Persist the accepted operation and new revision atomically. Only then
   acknowledge durable acceptance and expose the new committed state.
5. Duplicate command IDs return their existing result. A stale revision gets
   the latest state and a re-preview; start conservative before adding rebasing.
6. Undo is a new server-validated command. It can reverse an accepted edit only
   when the targeted pieces still have the expected state and dependencies.
7. On disconnect, show reconnecting and stop submitting edits. After a bounded
   retry period, offer a local copy. Rejoining receives a snapshot plus any
   necessary changes; it must not replay an unbounded queue of stale actions.

Separate durable build commands from disposable movement updates. Client
movement is constrained by the server; render other visitors using a short
interpolation buffer. Start around 10 updates/sec and measure. Neither room
editing nor room simulation requires streaming every decorative NPC position.

Use bounded outgoing queues and drop/coalesce obsolete movement updates for
slow clients. Preserve build results and resynchronize from a snapshot when
needed. Subscribe a client only to the current room/district. A future city
uses portals or explicit handoff between rooms, not a single world broadcast.

## Persistence and operations

PostgreSQL is a candidate for the full-city durable store in the
[tool strategy](TOOLS.md), covering plots, memberships, grants, bookings and
balanced ledger transactions. It was the leading candidate in the September
research; under RD15 no database is chosen. Selection would require the
CLI/MCP adoption checks and recovery evidence. It is not deployed by this
plan.

Credits now buy real compute and storage (RD08). The durable store therefore
holds money-like balances coupled to metering and quota records, which raises
the bar for transaction integrity, audit and restore. See the
[storage consequence](STORAGE.md#credits-meter-real-storage-and-compute).

SQLite remains an optional, isolated single-process courtyard experiment,
with one writer, a dedicated volume and explicit transaction boundaries. It
is not an agreed production starting point or a required migration step. Do
not share a raw SQLite file across hosts, split authoritative balances between
room databases, or import fixture state as real ownership or money.

Keep ephemeral presence outside the durable build log. Compact old operations
into versioned snapshots while retaining the history needed for permitted undo.
Define backup retention, export/deletion, and a restoration drill before public
saves are relied upon. The command is “saved” only after its durable commit;
backup durability is a separate promise.

Candidate pilot limits, to tune from measurement:

| Service | Initial limit | Rationale |
| --- | --- | --- |
| Room service | 2 logical CPU units, 2 GiB RAM | Small isolated pilot with explicit admission limits |
| Asset/job worker | One job at a time, 2 logical CPU units, 4 GiB RAM | Prevent background work from overwhelming the shared server |
| Job scratch data | Per-job byte/time limits and automatic expiry | Avoid accumulating raw uploads and failed outputs |

These are proposed container limits, not applied settings or throughput
estimates. A Node room loop does not automatically use every CPU thread.
Add processes only after profiling, with explicit room routing and compatible
storage. Keep public ingress separate from private administration, use service
credentials with bounded scope, and never mount the host Docker socket into
an upload-processing worker.

For asset jobs, start with founder-submitted files. If visitor uploads are
added, accept a constrained format/size set into isolated scratch storage,
validate resources, cap execution, and require approval before publishing an
asset. Generation APIs and arbitrary URL importers do not belong directly in
an unauthenticated public room.

## What must be measured before launch

Test 2, 8, 16, and 32 synthetic clients as load steps, not promised room sizes.
Include placement bursts, idle presence, reconnect storms, a slow consumer,
malformed commands, and a concurrent asset job. Measure CPU, RSS, event-loop
delay, bandwidth, database commit time, and end-to-end accepted-edit latency.

Placeholder target: typical edits acknowledged within 250 ms on the chosen
test connection, with p95 recorded. **The 250 ms figure has no stated basis.**
It was not derived from a user study, a latency budget or a measurement; treat
it as a placeholder to replace once a connection and a candidate stack exist.
The product is global (RD11): test from India and from several other regions
where visitors are likely. The lab server's network path and latency were not
inspected. A
placement preview should remain immediate even when the acknowledgement is
slower, with its pending state clearly visible.

Kill/restart the process after a saved edit, restore a backup, replay duplicate
commands, and attempt simultaneous edits to the same cell. Verify that private
room state is inaccessible to another room and that losing the lab server leaves the
published site and solo plot usable. A single lab server has no automatic
high availability; document that limitation for the pilot.
