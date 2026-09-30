# From village to city

Conditional delivery gates · updated 2026-09-18 · [Plan index](../README.md)

**Current phase: VISION.** Rakesh has explicitly asked to settle the overall
picture before starting implementation. All game development, engine trials
and deployment gates below wait for vision agreement and an explicit decision
to build. Their technical dependencies do not override that requirement.

**Updated 2026-09-18.** The [recorded decisions](VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)
change two things here. RD01 names the first slice: walking the city and
watching the 14 Guild agents at work, added below as **W1**. RD15 defers every
technology choice until the vision is clear, so D1 is an evaluation the team
keeps repeating for each use case, not the first step after VISION. Engine,
room-server, storage and hosting names in the gates below are candidates.

Ship a useful village, then a small cooperative plot, then a town. Grow the
world when visitors have another reason to enter it. More buildings alone do
not establish progress. No dates, user counts, or publishing commitments are
implied by this roadmap.

The target has expanded to a proper civic simulation. Add **S1** (one functioning
district) and **A1** (people and agents) below; these replace the earlier idea
that a city would be only a collection of small teaching scenarios. Headless
simulation and avatar/role-card work could begin after VISION and VIL-02 alongside V1/V2;
shared operation still depends on proven authority, identity and saves.

## VISION — Agree the open maker city

**Result:** a coherent picture of city life, real projects, SJL integrations,
participation, funding and stewardship. See the
[master plan](../vision/MASTER_PLAN.md) and [decision register](VISION_DECISIONS.md).

- [x] Draft visitor, free creator, resident, contributor, maintainer and
  steward journeys, including private work, disagreement and leaving.
- [x] Propose a labelled city map and facility/service catalogue with activity,
  audience, owner, access, funding and closure behaviour.
- [x] Develop recommended economy, residency, ownership and community policies.
- [x] Map system responsibilities, integration gaps and external tool paths.
- [x] Preserve the full city scope and label later experiments.
- [ ] Review the [five-milestone draft](VISION_REVIEW.md) with Rakesh and record
  the major policy and experience decisions.
- [ ] Obtain the separate decision to begin implementation after vision agreement.

**Gate:** Rakesh agrees the intended experience and major operating tradeoffs,
then explicitly decides to begin implementation. Approving one recommendation
or documenting all mechanics is not completion of this gate.

## Cross-cutting tool and hosting admission

After VISION, each selected workflow must pass the
[CLI and operational MCP checks](../architecture/AGENT_TOOLING.md) before
adoption. A docs-only MCP or server launch command does not satisfy the
requirement. Resolve only the tools needed for that slice; the catalogue is
not a list to install in full. Record the invoked versions, scoped grants,
representative workflow, read-back, failure and recovery evidence.

Before VIL-09 or any durable public workload, resolve the
[lab/production boundary](../architecture/STORAGE.md#hosting-role)
with SJL's infrastructure operators, or choose separate production hosting.
Host access and free disk space are not deployment approval or reserved
capacity.

## W1 — Walk the city and watch the Guild at work

**Result:** a person moves around the city and sees the 14 Guild agents doing
their actual current work (RD01). The public observes only; a registered
account is where interaction begins (RD03/RD04). This is the first slice; the
earlier V1 square, workshop and plot become later candidates.

- [ ] Agree the public work-state contract: which fields are shown (role,
  place, task title, state, last change), how private repository and operator
  material is redacted, how staleness and idleness appear, and who reviews the
  field list before anything is public.
- [ ] Define the projection path from the agents' real runtime to the city,
  with freshness, expiry and a labelled fixture mode. Today this needs work
  inside AgentPod; see the [verified gaps](GAP_REVIEW_2026-09-18.md#integration-gaps-verified-against-sibling-repositories).
  The integration shape is a later discussion (RD14).
- [ ] Place each agent at a home and workplace from the
  [Guild designs](../vision/GUILD_RESIDENTS.md); map facilities to the SJL
  product that powers them (RD02) and mark the rest as proposals.
- [ ] Make the observed city readable without 3D: a text and map view of the
  same work state, keyboard navigation, captions for any voice.
- [ ] Add the first registered-account layer: sign-in, a comment pinned to a
  place or piece of work, and a notice of what higher tiers would allow. No
  agent interaction ships until the untrusted-input model exists.
- [ ] Decide what happens in quiet hours: replays or highlights of recent work,
  a daily summary, and a reason to return tomorrow.
- [ ] Record the success and stop signals for the slice before it is public.

**Gate:** a stranger can watch the agents for ten minutes, say what each one
is doing, and find nothing private. A stale feed shows as stale. Registered
users can comment; nobody can reach an agent without a granted authority.
Measurements of cost, attention and return visits exist. This gate waits for
VISION, the public work-state contract and an explicit decision to build.

## O1 — Free maker participation

**Result:** someone can bring or join an SJL or independent project without
buying residency, under the proposed [participation policy](../vision/PROJECTS_AND_COLLABORATION.md).
This adds the open-maker scope to the earlier game-first delivery slices.

- [ ] Establish a free city account and saved profile independently of residency.
- [ ] Draft, review, publish, update, withdraw and export a project listing;
  provide a readable directory and an accessible exhibit entrance.
- [ ] Separate project membership, task grants, budgets and public display
  permission. Verify invitation, revocation and private/public boundaries.
- [ ] Link each project's chosen forge/task system; preserve external tools
  and one authority per record. No mandatory Forgejo migration.
- [ ] Trace a proposed contribution through maintainer acceptance and optional
  recognition/publication without making a merge an automatic JC grant.

**Gate:** a free account can present a project and accept an authorised
collaborator; an unrelated visitor sees only its published material. Revocation,
withdrawal and export work. This gate waits for VISION, the access/curation
policy decisions and the selected tools' admission checks.

VIL-30 supplies accounts for residency and permitted agent work. VIL-31
covers the project journey. These may be evaluated alongside the early
world slices; they are not replaced by decorating a paid resident plot.

## V0 — Website foundation dependency

Owned by the website repository: [V0 and VIL-01–04](https://github.com/SuperJackfruitLabs/super-jackfruit-website/blob/master/docs/VILLAGE_WEBSITE_PLAN.md).
Accurate readable pages, stable place IDs, recovery and device measurements
remain prerequisites; migration does not complete those implementation tasks.

## D1 — Compare web and native clients

**Result:** a documented engine/client decision from one district, as described
in [Platforms](../architecture/PLATFORMS.md). Godot and Bevy are candidates
among others; under RD15 the comparison is repeated as better options appear,
and nothing here is chosen before the vision is clear. Whether the first slice
needs a 3D or native client at all is itself an open evaluation.

- [ ] Reuse stable content/world IDs and a reviewed asset subset to build a
  Godot scene with homes, library, school, avatar movement and the fire drill.
- [ ] Export optimised native and web builds. Measure loading, memory, frame
  times, controls and background/resume behaviour on named hardware.
- [ ] Profile simulation tick cost separately from rendering, with clearly
  labelled synthetic populations. Record limits instead of guessing capacity.
- [ ] Compare Godot web reuse against retaining the existing Three.js village.
  Document the cost of maintaining two presentation implementations if chosen.
- [ ] Verify a browser/native room join and shared command/reconnect path;
  choose between a compatible Colyseus path and headless Godot from that evidence.
- [ ] Record the selected engine, language, renderer/quality profiles, supported
  prototype targets and protocol versions. Revisit Bevy only for a stated gap.

**Gate:** one browser client and one native client can observe the same accepted
world change, recover from disconnect, and reject an unauthorised edit. Device
measurements and authoring effort support the choice. This is an evaluation,
not a release promise for all desktop/mobile platforms.

After VISION, D1 could run alongside W1 and V1. It does not block V0's accurate
public pages or the first marketing cycle. Choose the client/network contract
before growing a large engine-specific implementation of the courtyard/city.

## V1 — The first hybrid slice

**Result:** Jackfruit Square, one useful workshop, and a personal plot. Since
2026-09-18 this follows W1 rather than opening the arc (RD01).

- [ ] Produce two landmark/kit art trials and choose a coherent style.
- [ ] Build U01–U05 and one U03 exhibit; start with the AgentPod inspection
  problem from SJL's first AgentPod early-user cycle.
- [ ] Rehearse and name the real product workflow/build used by the guide.
  A toy exhibit may ship earlier if it is explicitly labelled and makes no
  unverified integration claim.
- [ ] Implement P01 as an 8×8 personal plot with preview, rotate, place, remove,
  undo, versioned save, export, reset, and a usable keyboard/map interface.
- [ ] Separate placement rules and simulation from rendering so the room
  service can reuse the same rules.
- [ ] Build a bounded P02 review-yard scenario if it improves the explanation;
  avoid making it a dependency for simply reading the product guide.

**Gate:** on a laptop and a modest physical phone, someone can find a product,
explain the exhibit's idea, and make/save a small plot. Storage failures and
reduced-motion mode have usable outcomes. The plot remains useful alone.

## V2 — Build with a friend

**Result:** first multiplayer courtyard on a lab-server staging service.

- [ ] Implement M01 with the authoritative room stack verified in D1,
  compatible manifests, guest/editor/host roles, room limits and presence.
  Colyseus remains a candidate; Godot native/web compatibility must be demonstrated.
- [ ] Add atomic accepted-edit persistence, deduplication, conflict feedback,
  constrained undo, reconnect, and a private local export path.
- [ ] Package the service and save store in bounded containers. Prepare TLS
  ingress, health checks, logs with credential redaction, and a restart/restore
  procedure before deployment.
- [ ] Run the [multiplayer test matrix](../architecture/MULTIPLAYER.md), including an asset job
  competing for server resources and connections from relevant regions.
- [ ] Test with invited participants only after the scenario and support path
  are ready. Record observations; do not fabricate completed sessions.

**Gate:** two people build successfully; an eight-client test meets the chosen
budget; accepted edits survive restart; conflicting edits are clear; an
unauthorised client cannot edit another room. Publish the pilot's actual limits.

V0–V2 form the first development arc. Multiplayer is not deferred until the
city stage. Public open-ended construction comes after the small shared
experience has proved maintainable.

## R1 — Move in and grow a home

**Result:** a limited resident pilot with a persistent home and understandable
lifestyle grants. See [the residency brief](../gameplay/RESIDENCY.md).

- [ ] Settle contributor entry, initial benefits, one-time/recurring support
  rules, retention, privacy defaults, and milestone thresholds.
- [ ] Add linked resident identities, one-home claims, and a reversible manual
  grant/review flow. Keep local practice and visitor participation available.
- [ ] Build the starter home and one upgrade kit before offering those benefits.
- [ ] Test the progression preview and pause/return experience using labelled
  test records; no live payments are needed to rehearse the flow.
- [ ] Verify the selected sponsor account and supported data access before
  implementing signed intake, reconciliation, effective dates, and corrections.
- [ ] Test private sponsorship, existing sponsors joining later, refunds,
  duplicate/concurrent plot claims, contribution review, and backup restoration.

**Gate:** a qualifying resident can claim exactly one home, understand an
upgrade, and return to preserved work after a pause. Actual operating/support
cost is recorded. Public benefit descriptions match the implemented service.
The residency programme needs accounts; ordinary visitors do not.

## S1 — One functioning civic district

**Result:** homes, park, library, school, water/power and fire response share
roads, service demand and a budget. [Civic design](../gameplay/CIVIC_SIMULATION.md).

- [ ] Define the simulation clock, seeded events, versioned facility/road/
  household records, accepted-command log and snapshot/replay format.
- [ ] Add connected utilities, route-based reach, capacity allocation, upkeep,
  virtual taxes and a treasury with atomic reservations and settlement.
- [ ] Build public reading and an authored learning activity, then map their
  free/resident access and booking allowances separately from simulated demand.
- [ ] Add service overlays, explanation panels, budget comparison and a seeded
  fire drill with route, crew, water and response-time consequences.
- [ ] Verify tax/funding policy before offering real civic subscriptions; use
  explicit game grants and fixture support records for the prototype.
- [ ] Run city logic on lab-server staging only after resource limits and restore
  procedures exist. Record interference with existing services and room latency.

**Gate:** route/utility failures and insufficient capacity have visible causes;
extra funding cannot fix a missing connection; commands cannot double-spend;
restart/replay preserves the city; ordinary reading works without 3D. Repeat
on the target physical phone and with two clients making conflicting changes.

## A1 — People and agents as neighbours

**Result:** visitors choose avatars/personality; free accounts save them.
Residents explore deeper roles, while authorised project participants can
access their separately granted work. [Integration brief](../gameplay/AGENT_CITY.md).

- [ ] Review the [named founding cohort](../vision/FOUNDING_AGENTS.md): Guild's
  14 agents are the public cast. Personal agents are private to
  their owner unless shared (RD12) and get no public roles; they are the first
  case of the general "add your own personal agent" feature, which is
  unwritten. Agree homes, workplaces, service offers and private/public
  boundaries before designing generic staff. The
  [fourteen Guild designs](../vision/GUILD_RESIDENTS.md) supply the proposed
  cast, service contracts and scenarios for that review; approval remains open.
- [ ] Verify each admitted agent's stable identity, product mapping, one intended
  supervisor, runtime/channel health and freshness. Never infer readiness from
  a process flag or grant city access merely because an operational repair passed.
- [ ] Author a small modular avatar kit, emotes and explicit personality choices.
- [ ] Implement public role/status cards using labelled fixtures, with a stale
  state and clear distinctions between AI agents and simulated citizens.
- [ ] Verify a narrowly scoped AgentPod exporter and deployed API version;
  connect one opted-in station. Verify the invoked CLI and endpoint against
  [dated evidence](../research/TOOL_AUTOMATION.md); source commands and installed
  binaries are not interchangeable capability claims.
- [ ] Add authenticated extended role views and one allowance-limited task;
  verify project grants, quota reservation, retry, revocation and result audience.
- [ ] Benchmark a few licensed resident character voices on the lab server with text
  fallback and captions. Publish usage limits only after measuring cost/latency.

**Gate:** a real process status is never inferred to mean active work; a failed
feed expires; visitors receive only public fields; a resident cannot reach
another project's data or operator tools; retries do not duplicate tasks.
Avatar preferences persist correctly and voice-off mode remains complete.

## E1 — A resident economy with visible consequences

**Result:** one funded job, a JC wallet, tax, utility payment, study booking,
cottage upgrade and a balanced public budget. See [Economy](../gameplay/ECONOMY.md).

- [ ] Apply RD07/RD08: credits are earned, bought or included with a tier and
  buy facility access, items, compute and storage. Settle earned versus
  purchased balances, expiry, refunds and no cash-out from the
  [economy model](../research/ECONOMY_MODEL.md) and
  [legal research](../research/LEGAL_COMPLIANCE.md); keep prices provisional.
- [ ] Implement balanced postings, holds, reward acceptance and tax assessments.
- [ ] Add one funded allowance and refund-to-original-source booking flow.
- [ ] Rehearse recurring entitlements with fixtures, then the selected payment
  provider's test mode; global coverage is unverified (RD11).
- [ ] Keep lending and player markets behind later gates. Direct credit sales
  are now in scope (RD07) but ship only after the legal review.

**Gate:** complete the loop without cash; verify conservation, duplicate and
concurrent commands, insufficient funds, allowance expiry, refunds and recovery.
A JC shortfall cannot invoke a real payment. Homes survive ordinary inactivity.
Real purchases require the separate [Razorpay validation](../integrations/payments/RAZORPAY.md) gate.

## G1 — A useful cooperative project

**Result:** the [reading garden](../gameplay/scenarios/READING_GARDEN.md) joins
GM01 professions, GM02 construction and GM04 requests, with small environmental
and acknowledgement consequences. Its numerical fixture is not a measured game.

- [ ] Implement one request, two role practices, a funded milestone project,
  finite materials, inspection and a public capacity change.
- [ ] Preserve asynchronous handoff, accessible actions, grant deduplication
  and return/cancellation behavior.
- [ ] Observe whether people understand the need and enjoy a contribution,
  including a practice variant without currency rewards.

**Gate:** complete solo and with two people; prove conserved money/materials,
exact-once rewards/capacity, stale-revision rejection, restart and privacy.
G1 builds on VIL-08/14/21; it does not require live payments or real agents.

### Full mechanic backlog remains in scope

The [thirteen mechanic contracts](../gameplay/MECHANICS.md) and
[World systems](../gameplay/WORLD_SYSTEMS.md) preserve the larger careers, public
works, district character, population, relationships, ecology, expeditions,
research, automation, government, agents, news and travelling-project ideas.
Later gates schedule implementation; they do not discard these systems.

## T1 — A town with reasons to return

**Result:** several useful districts and dependable small-group activities.

- [ ] Give all four current products an accurate passport and a distinct place;
  add an exhibit only when it teaches something useful.
- [ ] Add a dated field-note board, the Archive Garden, and direct/searchable
  routes for the growing content library.
- [ ] Stream districts with resource disposal and quality tiers. Re-test the
  phone budget before increasing scene density.
- [ ] Add one social activity beyond decorating: guided walk M02 or review-yard
  co-op M03, with clear host controls.
- [ ] Add a recreation centre with a deterministic multiplayer board/puzzle
  game, spectators, reconnect, reservations and a finished-match record.
- [ ] Extend S1 with police/traffic incidents, waste, maintenance, a transit
  route, and visible household/business demand and education progression.
- [ ] Extend resident accounts for cross-device saves, recurring groups, and
  submission ownership as needed; keep ordinary exploration anonymous.
- [ ] Add blueprint review, consent, attribution, takedown, and rollback before
  an exhibition. A private room is never automatically a public submission.

**Gate:** people can describe a reason to return; updates are maintainable by
the founder; product-task success does not deteriorate as the world grows;
moderation and restoration have been rehearsed where applicable.

## C1 — A city assembled from neighbourhoods

**Result:** connected, independently loadable and operable districts.

- [ ] Introduce district manifests, portals/room handoff, and capacity-based
  routing without broadcasting the entire city to every visitor.
- [ ] Curate creator plots into exhibitions or neighbourhoods with clear
  ownership, compatibility, and removal rules.
- [ ] Extend the causal city economy with trade, supply chains, transport,
  district budgets, growth demand and resource reservations across districts.
- [ ] Build stadium/festival events with booking, transport/cleanup demand,
  free/sponsored/ticketed entry rules, and independently tested game capacity.
- [ ] Add isolated budget/scenario forks and incident replay before residents
  can propose complex public changes. Approval remains an explicit city role.
- [ ] Decide whether room processes need another host/region, shared database,
  managed hosting, or a different engine based on recorded bottlenecks.
- [ ] Consider the harbour, monsoon puzzle, time machine, and midnight train
  as independent experiments, not prerequisites for “city” branding.

**Gate:** the city is a collection of useful places with stable navigation,
content, saves, performance, and operating cost. Population or map area is not
the release criterion.

## Candidate implementation tickets after VISION

Effort is relative: **S** is a narrow change, **M** spans a few components,
**L** crosses a system boundary or requires experimental work. These are not
day estimates. Roles describe work, not an assumed team; SJL is currently solo.

| Ticket | Deliverable | Effort | Depends on | Evidence of completion |
| --- | --- | --- | --- | --- |
| VIL-05 | Landmark and kit comparison | M | Visual brief | Same-scene asset cost/quality comparison |
| VIL-06 | One explanatory workshop | M | VIL-02, real workflow evidence | A visitor understands the named problem and finds a next step |
| VIL-07 | Local courtyard domain + UI | L | VIL-02, VIL-05 | Save/undo/migration and accessible placement work |
| VIL-08 | Room authority and persistent saves | L | VIL-07, D1 client/protocol decision | Conflicts, duplicates, restart, and permissions tested |
| VIL-09 | Lab-server staging and resource tests | M–L | VIL-08 | Capacity/latency and recovery report; existing services unaffected |
| VIL-10 | Pilot review and next-slice decision | S | VIL-03/06/07/09 | Real observations and explicit keep/change/drop decisions |
| VIL-11 | Residency rules and starter/upgrade kit | M | VIL-05/07, residency decisions | Reviewable benefits, progression, pause policy, and cost assumptions |
| VIL-12 | Residency grants and unique home claim over city accounts | L | VIL-08/11/30 | Identity/permissions, duplicate claims, grants, and restore tested |
| VIL-13 | Sponsor reconciliation and contribution review pilot | M–L | VIL-09/12, provider verification | Private/one-time/recurring support and corrections produce correct benefits |
| VIL-14 | Headless civic engine and first district | L | VIL-02; VIL-08/09 for shared hosting | Routing, utilities, capacity, budget and fire drill obey tested causal rules |
| VIL-15 | Public facilities and activity access | L | VIL-03/12/14 | Reading, learning, games and bookings match access and funding policies |
| VIL-16 | AgentPod projection and scoped participant task gateway | L | VIL-02/30; VIL-12 for resident allowances; verified exporter/deployed API | Freshness, field filtering, grants, quota and retry behaviour verified |
| VIL-17 | Avatar/personality kit and resident voice trial | M–L | VIL-05; VIL-30 for profiles; VIL-12 for resident allowances | Saved identity choices, bounded asset cost and measured voice prototype |
| VIL-18 | Town economy, transit and civic expansion | L | VIL-14/15 | Growth, education, upkeep, incidents and services interact with explainable outcomes |
| VIL-19 | Native/web district comparison and shared protocol | L | VIL-02/05 | D1 measurements, cross-client change/reconnect test and recorded engine decision |
| VIL-20 | Move plans to their implementation owners | Complete | Approved repository split | City docs and prototypes migrated; website plan merged in PR #1; marketing pointers. See [migration record](REPOSITORIES.md) |
| VIL-21 | Wallet, tax and service economy | L | VIL-08/12/14; economy policy | Funded earnings, conserved balances, quotes, taxes, bookings and upgrades survive retries/restart |
| VIL-22 | Razorpay payments and recurring entitlements | L | VIL-12/21; verified merchant capabilities | Test-mode capture, renewal, webhook, refund and compensation evidence |
| VIL-23 | SSD/HDD storage and recovery | M–L | VIL-09; storage policy | Contention measurement, capacity alerts and isolated wallet/world restore |
| VIL-24 | Reading-garden cooperative loop | L | VIL-08/14/21; G1 fixture | Roles, funded milestones, handoff, inspection and capacity change verified |
| VIL-25 | District life, ecology and memory | L | VIL-14/24 | GM03–06 models, event acknowledgement and bounded request behavior; expand toward full world systems |
| VIL-26 | Expeditions and shared invention | L | VIL-07/24; authored scenario tools | GM07/08 clue checkpoints, reproducible experiments and validated knowledge grants |
| VIL-27 | Programmable services and agent apprenticeship | L | VIL-16/21/24 | GM09/11 bounded rules, traces, grants and fixture-to-real integration gates |
| VIL-28 | Charters and eventual government | L | VIL-14/21; civic policy decisions | GM10 templates and previews first; electoral identity, roles, quorum and recovery before elections |
| VIL-29 | City media and travelling programmes | L | VIL-15/24; publication/booking rules | GM12/13 sourced notices, corrections, itinerary and exact-once custody handoff |
| VIL-30 | Free city accounts and independent permission dimensions | L | VIL-02; approved account/access policy | Free profile, scoped membership, revocation and stable account binding verified |
| VIL-31 | Project directory, exhibits and contribution journey | L | VIL-30; curation policy and chosen tool contracts | Free project listing, review, participation, withdrawal/export and private/public boundaries verified |
| VIL-32 | Public work-state projection of the Guild (W1) | L | Public field contract; AgentPod-side exporter (RD14); VIL-02 stable IDs | Fourteen agents observable with fresh, redacted, labelled state; stale feeds expire; nothing private visible |
| VIL-33 | Registered accounts, comments and tier notice (W1) | L | VIL-32; identity decision; moderation plan | Sign-in, a pinned comment, report path and tier notice work; no agent reachable without authority |

The logical [city systems](../architecture/CITY_SYSTEMS.md) and
[authoring/operating tools](../architecture/AGENT_TOOLING.md) remain the full
responsibility map. Tickets above are candidate slices, not a complete backlog
for every institution. Optional [world-model experiments](../research/WORLD_MODELS.md)
retain their separate admission, rights, cost and evaluation gates; no model
installation or experiment is scheduled by this roadmap.

## Evaluation and cost

Recruit a small initial set, for example five people with a mix of technical
backgrounds and devices. This is a suggested research sample, not a claim that
participants exist. Ask them to find a product, explain an exhibit, build a
plot, and collaborate. Observe confusion and failures as well as completion.

Record product understanding and actual workflow attempts separately from
world enjoyment, saved plots, and session duration. Use SJL's existing
early-user cycle review for product learning. Maintain a
separate technical log for room latency, server use, asset budgets, and defects.

Cost starts with the existing site/server and free authoring tools. Add paid
generation, hosted multiplayer, GPU rental, or extra storage only when a
specific test shows their value. Agree a spending cap before a paid experiment;
do not make model API calls part of an unbounded public interaction.

The earlier delivery recommendation began with **VIL-01 through VIL-04 in the website repository**:
an accurate catalogue, stable content model, readable destinations, a usable
map, and reliable loading. VIL-05/06/07 can then turn that foundation into the
first distinctive hybrid experience. VIL-14's headless district model and
VIL-16's public-role fixtures could follow VISION and VIL-02's stable contracts.
VIL-19 tests the native/web direction alongside these early slices; use its
decision to place implementation in the city repository. Site-specific
VIL-01–04 stay with the website code, as mapped in [Repository ownership](REPOSITORIES.md).
The immediate next work is still **VISION review**. The project journeys,
revised city map, policy proposals and system map are drafted in the
[five-milestone review](VISION_REVIEW.md). The [2026-09-18 decisions](VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)
settle the first slice, access levels, credits, residency purchase and the
global market; the [gap review](GAP_REVIEW_2026-09-18.md) lists what remains
open. Later, a functioning district remains a candidate simulation
evaluation. Preparing this plan has not changed the production website or
deployed anything to the lab server.
