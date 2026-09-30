# SJL product integration: plan

Planning draft · 2026-09-27 · for Rakesh's review. Nothing in this document is
decided or built by being written.

**Status labels.** Every claim carries one of three labels.

- **Implemented** means it is in code at the revision named below.
- **Designed** means an agentnagar brief or spec, or an internal SJL decision record, describes it, but it is not built.
- **Proposed** means it is new in this plan.

**Evidence read on 2026-09-27.**

- agentnagar `main` at 4d77be5, plus the tram design on `feat/city-tram` at 11992ca (not merged).
- The sibling repositories after a fetch: agentpod `origin/main` dab714ca, superpipeline `origin/main` 91c3ba7, supermd `origin/master` 1cc055c, supermessage `origin/main` f0ea08d, and SJL's internal cross-product decision records at the same date.
- agentnagar paths are relative to that repository. Sibling paths begin with the repository's directory, such as `agentpod/…`.
- This was source and documentation inspection only. No product was run, no live endpoint was called and no credential was used.

---

## 1. Goal, and what "incorporated" means here

**The direction.** Rakesh chose the order of work on 2026-09-26. It is recorded in session notes, not yet in the repository.

- First, the follow-on mechanics in every style: the map (done, v0.0.2), the tram (designed), rooftops and conversations.
- Then, in-world interfaces in each visual style that show the state of each SJL product slated for the city.

**The decisions behind it.**

| Source | What it says | Label |
| --- | --- | --- |
| RD18, `docs/planning/VISION_DECISIONS.md:86` | Level up first; "SJL project integration follows once that level is reached" | Decided |
| `city/README.md`, "What comes next" | "After that level comes SJL integration: a real presence feed" | Designed |
| `docs/superpowers/specs/2026-09-24-city-world-core-design.md:54` | "SJL integration: a real presence feed from AgentPod or Superpipeline" | Designed |
| RD02, `VISION_DECISIONS.md:56` | The city runs on SJL's products. Its opens: "Which facility is backed by which product; what each product must expose first" | Decided |
| RD01, RD03, RD04 (`:55`, `:57`, `:58`), and U09 in `docs/vision/EXPERIENCES.md:32` | The first slice is watching the 14 Guild agents at real work. The public observes only. Interaction starts at a registered account, by tier and authority | Decided |
| RD12 and RD14 (`:66`, `:68`) | Personal agents stay private unless shared. Integration points are still moving, and the verified gaps are facts to design around | Decided |
| `docs/vision/ECOSYSTEM.md`, "Which system decides what" | For work state, the city shows "an authorised projection and route[s] a decision to its actual owner" | Designed |

**What "incorporated" means in this phase (proposed).** A product is incorporated when all five of these hold.

1. **The product stays the authority** for its own records. The city holds only an expiring copy of the fields the product has made public.
2. **The state is visible at the product's place in the city**, in all six styles and as readable text. It carries its freshness, and whether it is fixture, curated or live.
3. **Nothing the city does writes to the product.** Book, Ask, dispatch and comments are out of scope. W1 says: "No agent interaction ships until the untrusted-input model exists" (`docs/planning/ROADMAP.md:63-94`).
4. **The product still works without the city.** An internal SJL principle: "Each product must stand alone". The city is an optional consumer and is never a dependency.
5. **The W1 gate holds** (`ROADMAP.md`, W1 gate). A stranger can say what each place shows, and finds nothing private. A stale feed shows as stale.

---

## 2. The products, their places, and the state each should show

### 2.1 Where each product lives (designed)

The facility catalogue is `docs/vision/CITY_PLAN.md:117-141`. The product mapping is `ECOSYSTEM.md:82`. Every mapping is proposed under RD02, and none is decided.

| Product | First places | Later places |
| --- | --- | --- |
| **AgentPod** | F02 AgentPod Workshop (D02). F19 Agent observatory (D02), for runtime status | F04 studio sessions; F07 experiment runs |
| **Superpipeline** | F02 Superpipeline Yard (D02). F19, for task and run state | F04 task boards; F09 civic contract board; F13 public works; F14 moderators' real report queue; F22 editorial queue; F23 review queue |
| **SuperMD** | F02 SuperMD Reading Room (D02) | F05 library; F01 guides; F03 project pages; F06 lessons; F13 minutes; F20 archive; F22 stories |
| **Supermessage** | F25 Post Office (D02) | F03, F04, F06, F11, F12 and F13 rooms |
| **All four** | F24 Night Market (D03): the CLI and MCP surfaces, shown as exhibits with **fixture data only** | — |

**D02 in its village form** is "a shared workshop with four product corners and a post counter" (`CITY_PLAN.md:57`). VISION gives the character of each place (`docs/vision/VISION.md:111-114`):

- the AgentPod Workshop has labelled instrument panels, and F19 next door;
- the Yard has loading bays, moving cards and a review gate;
- the Reading Room has an "orchard of connected notes";
- the Post Office has lanterns and sorting shelves, and shows "only verified product capabilities".

**Gap in the implementation (implemented fact).** The walkable district `city/fixtures/district/manifest.json` has none of these places.

- It has a guild hall, a library, a café, a square, a park, a tram stop and streets, with IDs such as `facility:guild-hall`, and no F or D IDs.
- The map's `Category` has only Workshop, Library, Transit and Park (`city/crates/city-contracts/src/manifest.rs:204`).
- Five Guild agents are in the fixture: Kai, Lyra, Theo, Quill and Echo. There is also one city-role librarian.
- Nobody owns place IDs yet (`docs/architecture/CITY_SYSTEMS.md`, known gap 6).

### 2.2 What each product exposes today

This table records verified facts at the revisions above. They supersede the 2026-09-18 tables where the two differ.

| Product | Read surfaces that exist (implemented) | What they cannot give the city |
| --- | --- | --- |
| **AgentPod** | **Fleet contract** (`agentpod/packages/contract/src/fleet.ts:9-49`): node `online/offline`; station `running/stopped/error/unknown`; cpu, memory and uptime; `workspacePath`. **Operator REST** `/api/fleet/*`, humans only (`apps/hub/src/auth/middleware.ts:184-199`). **CLI** `agentpod-fleet` (`fleet nodes/agents/stats/activity`, `apps/node-agent/cmd/agentpod-fleet/help.go`): renamed from `apn fleet` since 2026-09-18. **Hub MCP**: three self-scoped agent tools, `agentpod_my_station/my_sessions/my_transcript` (`apps/hub/src/mcp/tools.ts:64,103,127`). **Run states**, A2A-exact (`packages/contract/src/run.ts:20-37`). **Matrix turn and thought streams** (`packages/contract/src/matrix-events.ts`) | **No current-task, last-active or observation timestamp** in the fleet contract. **No city credential will work.** A `service` principal kind exists (`apps/hub/src/db/schema/organization.ts:17`; `mcp/auth.ts:35`), but no route that serves fleet data accepts it. **No outbound status event.** **The Matrix streams are private live content** and must never reach the city |
| **Superpipeline** | **Board DO WebSocket** broadcasting every state change to authorised UI clients (`superpipeline/docs/07-realtime-and-ui.md:9-13`). **Status chips**: Ready, Working, Needs input, Needs auth, Review/Gate, Went dark, Done, Rejected, Failed (`docs/07…:63-82`). **CLI `supi`**: reads boards, cards and pending gates; moves cards; creates boards; human principal via a fleet device credential (`packages/cli/README.md`). **Eleven agent-scoped MCP tools** (`apps/api/src/mcp/tools.ts`). **HMAC-signed outbound push**: `work.available` and `gate.pending` only (`docs/05-integration-surfaces.md:283,322`) | **No board read over MCP**, and "MCP cannot read a run" (`docs/05…:101`). **No per-board visibility.** Human routes refuse non-human tokens (`apps/api/src/auth/resolve.ts:202`), so there is **no service credential**. **No run-state push.** `Idempotency-Key` is ignored (`docs/05…:181`). A card's title and activity can carry private text |
| **SuperMD** | A native editor over plain Markdown. An `html-export` plugin (`supermd/plugins/html-export/`), `examples/build_docs.rs`, and WIT plugin interfaces | **No headless export command.** `src/main.rs:372` takes only a file path. There is **no service to query**: its state is files in a vault |
| **Supermessage** | A Matrix *client*: desktop release v0.0.11 (`supermessage/README.md:88`), plus iOS and Android. It renders `dev.agentpod.turn/permission/turn_error` and `dev.superpipeline.gate(.decision)` events (`crates/supermessage-core/src`) | **No server of its own.** Room state belongs to the homeserver. **No station-status, card or run event exists.** An internal SJL decision says those three event types were "deliberately not designed" |

**One precedent worth reusing.** AgentPod's hub already accepts a signed push from Superpipeline: `POST /public/bridge/superpipeline/push`, HMAC over the exact bytes, which fails closed when no secret is set (`agentpod/apps/hub/src/routes/superpipeline-push.ts:1-20`). That is a product pushing a narrow projection to a consumer with no shared credential.

### 2.3 What each place should show (proposed)

| Place | Public state (proposed) | Source (proposed) | Never shown |
| --- | --- | --- | --- |
| F19 observatory, and every Guild agent's tag | One line per published agent, with three dimensions (`docs/gameplay/AGENT_CITY.md:252-271`). **Connection** and **process** come from AgentPod. **Task** comes from Superpipeline runs, with a coarse headline and an optional approved one-liner. Also "last checked N min ago" and an AI badge | AgentPod public status export; Superpipeline public run projection | Hostnames, node IDs, workspace paths, cpu, memory, prompts, tool calls, transcripts, requesters, costs (`AGENT_CITY.md:288-292`; `FOUNDING_AGENTS.md:90-94`) |
| F02 AgentPod Workshop | "Instrument panels": the published cast's runtime health; an exhibit of how node, station and harness fit together; the current `fleet` release | AgentPod export, plus public release metadata | Fleet totals that include unpublished or private agents |
| F02 Superpipeline Yard | For each **explicitly published** board: stages as loading bays, cards as crates with status chips, work limits, and "awaiting review" at the gate | Superpipeline public board projection | Card titles unless approved; activity text; the gate approver's identity; costs |
| F02 Reading Room | A catalogue of **published document revisions**: title, revision date and licence. The link graph is drawn as the note orchard, and Browse opens the text | A SuperMD publication manifest built from an approved vault revision | Unpublished files; the vault path |
| F25 Post Office | A capability and release exhibit ("verified capabilities only"). Later, dated notices from designated public rooms | Public release metadata; later, a read-only Matrix reader (needs the RD05 homeserver decision) | Message content from any non-public room; membership lists |
| F24 Night Market | The CLI and MCP surfaces of all four products, as fixture exhibits | Authored fixtures | Any live credential (`CITY_PLAN.md:186`) |

---

## 3. Getting product state into the core, and to viewers, safely

### 3.1 What the city already has (implemented)

**In the core** (`city/crates/city-contracts/src/{feed,presence,event,projection}.rs`; `city/README.md`):

- the **`Observe` command**, with three dimensions: `Connection`, `Process` and `Task`;
- a **`Stamp`** holding `observed_at`, `fetched_at`, an exclusive `expires_at`, `source` and `source_version`;
- **events**: `ObservationExpired` and `PresenceChanged { shown }`, carrying a `Headline`;
- the **invariants** "stale is never shown as current" (4) and "running with no task is never `Working`" (5), checked every tick (`city/crates/city-core/src/invariants.rs:237,270`);
- the rule that an older observation never replaces a newer one;
- **three viewers**: `Public`, `Person` and `Operator`, the last only with an explicit flag. `task_summary` is withheld unless `summary_public`, and withheld looks the same as absent (`projection.rs`);
- **overlays for hidden occupants**, so that nothing counts them.

**The fixture feed** carries `fixture: true` in its header and in every entry (`feed.rs:9-16`).

**What is missing.**

- **No live ingestion path.** The Godot client loads the whole feed at start (`city/godot/core/world_driver.gd:29`), and the bridge accepts commands only for the player's own occupant.
- **No server.** `city-server` is a later sub-project (`city/README.md`, "What comes next", item 1).
- **Observations attach only to occupants.** There is no place-level state.
- **Ticks are world time, not wall time.** At 1× one tick is one second, and the district day is 600 ticks (`world_driver.gd:1-2`; the manifest's `clock`), so a city day is ten real minutes.

### 3.2 Options

| Option | How it works | Credentials | Where privacy is enforced | Determinism and replay | Verdict |
| --- | --- | --- | --- | --- | --- |
| **A. Client fetches from the products** | Each Godot client calls the product APIs | A token in every client, which AGENT_CITY forbids (`:300-301`) | In the client, which is untrusted | Each client sees different state; no replay | Reject |
| **B. Adapters inside `city-server`** | The room server polls the products | A service credential that no product accepts | In the server only | Replay works if inputs are logged | Couples product failures and secrets to the world server |
| **C. City feed relay pulling** | A city service reads the products, then normalises, redacts, stamps and logs | Needs a city service principal on every product | In the city relay | The logged input feed replays | Needs a new authority in every product. The product can't vouch for what it considers public |
| **D. Product-owned public projections, pushed** | Each product publishes an **opt-in** public projection, as a signed push or public read. It is built in the owning repository and agreed as an internal SJL decision | None held by the city. The product signs; the relay verifies | **At the source**, where the product knows its own private data, and again in the relay | Same as C | Recommended, together with C's relay |

**Recommendation (proposed): D plus a thin city relay.**

**Who does what.**

- **Each product decides what is public**, and emits it as a versioned, opt-in "public projection". AgentPod does it for the published cast's connection and process state. Superpipeline does it for published boards and runs. SuperMD does it as a published revision manifest.
- **A city-owned relay**:
  - verifies each push;
  - re-applies the city's own field allowlist, as a second, fail-closed filter;
  - binds each product ID to a city ID through an explicit registry;
  - converts timestamps to ticks;
  - appends ordinary feed records to the world's durable input log.
- **`city-server`** ingests the log at tick boundaries.
- **Clients** only ever receive their viewer's projection.

**Until products publish,** two backends fill the same contract:

- **authored fixtures**, which exist today;
- **curated snapshots**. An operator runs the products' own CLIs (`fleet agents`, `supi`), the relay redacts the output, and the file is labelled `curated` with a short expiry.

**Trade-offs.**

- **Cost:** D needs work in three product repositories and an internal SJL decision before anything goes live.
- **Benefits:**
  - no city credential exists to leak;
  - the owner, who knows what is private, filters first;
  - it follows the existing push precedent (§2.2);
  - it is the natural moment to design the `agent.status`, `card` and `run` events the internal decisions left open;
  - Supermessage's positioning also wants station status (`supermessage/AGENTS.md`, overview).
- **Why not the alternatives:**
  - C alone is faster to prototype, but it puts the judgement of what is private in the wrong repository.
  - B is C with worse fault isolation.

### 3.3 Identity and authority (internal SJL decisions)

- **One issuer; everyone else verifies offline** (internal SJL decision "One issuer and offline verification"). The relay verifies a product's signature or token, and mints nothing.
- **A human's short-lived token or device credential must never run a city service.**
  - An internal SJL decision accepted the device credential for humans at a terminal on 2026-09-20 ("A human at a terminal has nothing to exchange").
  - AGENT_CITY forbids a human operator's token in a city service (`AGENT_CITY.md:110`, `:300`).
  - A curated snapshot is an operator exporting data by hand. It is not a service holding a credential.
- **Each agent is one principal, named per plane, and bindings are explicit** (internal SJL decisions "An agent is a principal" and "A grant names an agent per plane"). The relay's registry maps a city occupant ID to an AgentPod principal or station and to a Superpipeline agent ID. It never matches by name.
- **Matrix IDs link to principals explicitly** (internal SJL decision "Ecosystem identity").
- **Who sees what.** Every product field enters as public or not-public. Nothing enters for `Person` beyond public until city sign-in exists; W1's first registered layer is designed but has no issuer (`CITY_SYSTEMS.md`, gap 1). `Operator` diagnostics stay behind the flag.
- **Personal agents (RD12)** are excluded at the product export and again at the relay. Facility aggregates count only the published cast, so a count never reveals a hidden occupant. This is the capacity-overlay principle, applied to panels.

### 3.4 Freshness and staleness

- **Expiry is the only safety net.** Each dimension gets a real-time expiry, converted to ticks at ingestion. The product re-emits to renew. When the relay loses contact, it emits nothing, and the core's expiry shows `Stale`.
  - AgentPod's own rule already marks health `unknown` after 75 s without a report (`AGENT_CITY.md:124`).
  - Proposed expiries: about 2 min for process, and one Superpipeline heartbeat interval plus margin for task.
- **Wall-clock stamps are display-only (proposed).** Add `observed_wall` and `fetched_wall` to `Stamp`, which rules never read, like props. The interface can then say "last checked 2 min ago" in real time, while the rules stay in ticks.
- **Live mode pins the tick rate.** The server owns time and runs at 1×. The developer panel's 2–8× speed-ups (`world_driver.gd:1-2`) apply only to fixture runs, because fast-forwarding a live feed would expire real state early.
- **Provenance becomes a three-way label (proposed contract change).** `fixture: bool` becomes `provenance: fixture | curated | live` in the header, in every entry and in every projection. The interface shows it: the HUD's fixture notice already exists.

### 3.5 Determinism and replay

The relay's appended records are the world's input, like the client's `Go` and `Steer` log (`city-godot` `input_log_jsonl`).

- The same manifest, seed and input log give a byte-identical event log, as invariant 6 requires today.
- A replay never fetches, pushes or retries anything upstream (`CITY_SYSTEMS.md`, "Event and side-effect rules").
- Ingestion order is by arrival tick, and then by a stable key (source and sequence). Two relays can never feed one world.

### 3.6 The CLI and MCP admission rule

The rule is in `docs/architecture/AGENT_TOOLING.md:24-49`.

**City-owned tools.** The relay is a city tool, so its operations get both interfaces over one contract, like `city-cli` and `city-mcp` today:

- `city feed validate | record | inspect | replay`;
- `city bind list | check`.

**Product dependencies.** Each needs a CLI and an MCP path for the operation the city relies on.

| Operation | CLI today | MCP today |
| --- | --- | --- |
| AgentPod status read | Yes, `fleet agents` | **No** |
| Superpipeline board read | Yes, `supi` | **No** |
| SuperMD export | **No** | **No** |

Each gap is closed in the owning repository, or recorded as a user-approved exception. The public-projection exports should ship with both interfaces.

---

## 4. The in-world interfaces

### 4.1 The surfaces, independent of style (proposed unless marked)

| Surface | Where | Public sees | Built from |
| --- | --- | --- | --- |
| **Agent tag and card** | Every agent (occupant) | The name, AI badge, headline chip and approved one-liner; freshness on the card. Stale shows "Stale – last checked N min ago", never the old value | **Implemented in part:** the tag text with the task summary (`city/godot/styles/style_pack.gd:110-124`); a headline per style under `REQUIRED.headlines` (`:10-18`); typing when `Working` (`styles/pack_3d.gd:1211`); the tag toggled with N |
| **Observatory roster** | F19 | One row per published agent: place, headline, freshness. The same data appears as a list in the map's List tab | Occupant projections, with no new data |
| **Facility kiosk**: the FACILITY panel of sheet 03 | Each product place | **Browse** only. Book and Ask are absent until they exist, following the map card's rule that "nothing on the card promises one" (`docs/superpowers/specs/2026-09-26-city-map-view-design.md:92`) | Place panels |
| **Yard board** | Superpipeline Yard | Stages, crates carrying status chips, counts, and the review gate lit or dark | Place panel: board projection |
| **Shelves and reader** | Reading Room | Spines titled from published revisions; the orchard of links; Browse opens an accessible reader overlay | Place panel: publication manifest |
| **Noticeboard and exhibit** | Post Office; later the Square | Dated notices; a release and capability plaque | Place panel |
| **Map card status** | Map screen | One status line per place, and "Updated N min ago" | Place panels, and the list rows |

**Three layers for every surface.**

1. **Diegetic.** A style pack draws it. A new `surfaces` section joins `StylePack.REQUIRED`, so each style maps it or declares a placeholder, as today (`style_pack.gd:96-99`).
2. **Overlay.** A screen-stack panel skinned by the style's `ui` block, as the map card is (`docs/superpowers/specs/2026-09-26-city-game-interface-design.md:149-193`). In first person, act on the crosshair to open it. Otherwise select it and press act.
3. **Text.** The List tab and a readable page (U05; the W1 "readable without 3D" item).

**Level of detail.** Far away, a surface shows only its chip or icon. Near, it shows short text. Opening it shows everything. In-world text never carries information the overlay lacks.

**Where panel data comes from (proposed contract).** An `ObservePlace { place, panel, observation }` command. Its value is a typed panel: `Roster`, `Board`, `Catalogue` or `Notices`. It carries the same `Stamp`, expiry and `public` flag. It is projected on each `RoomView` or facility view, and invariant 4 is extended to panels. No rule reads a panel: it rides with the world only so that visibility, staleness and replay live in one audited place.

### 4.2 Mapping task states (proposed)

This follows `AGENT_CITY.md:256-258`: queued, working, waiting-for-input, done; otherwise unknown. `TaskState` in `presence.rs:23-30` already has every target except a failure outcome.

| Superpipeline chip (A2A state) | City `TaskState` | Public label |
| --- | --- | --- |
| Ready (`submitted`) | `Queued` | Queued |
| Working (`working` plus a recent heartbeat) | `Working` | Working |
| Needs input, Needs auth, or Review/Gate (`input-required`, `auth-required`) | `Waiting` | Waiting for a person |
| Done (`completed`) | `Done` | Finished |
| Rejected, Failed, Canceled | `Done` | Finished (outcome private: decision 8) |
| Went dark / reclaimed (heartbeat lost) | None emitted, so it expires | Stale |
| No run for a published agent | `Idle`, only if the source asserts it; otherwise nothing | Idle or task unavailable |

**One agent, several runs.** The headline takes the first of Working, Waiting, Queued, Done and Idle. If AgentPod reports `running` and there is no task observation, the core shows `Unknown` ("Process running; task status unavailable"), as invariant 5 requires.

### 4.3 How each style draws them

These are the six packs in `city/godot/styles/`, with their sheet-03 references from `2026-09-26-city-game-interface-design.md:40-47`.

**The FACILITY panel.** The concept panels show a person at a freestanding kiosk with three stacked buttons: Browse (open book), Book (calendar) and Ask (speech bubble). This was observed on low-poly r004. The contract fixes the icons across styles: "Do not reuse one icon for different actions" (`docs/vision/style-studies/shared/CONSISTENCY-CONTRACT.md:34`).

**What is proposed for every style.** Fixed headline semantics: a chip shape, icon, label and colour per headline that no palette recolours, as the map categories already are.

| Style (pack, sheet 03) | Overlay skin (designed, `ui` block) | Diegetic treatment (proposed) |
| --- | --- | --- |
| 06 Cel-shaded anime (`anime_cel`, r004) | Light rounded cards, blue buttons, soft shadow | A painted wooden kiosk with a paper card inset. The Yard board is a cork board with cel-outlined crates. Headline chips are rounded pastilles over heads. Shelves are soft-shaded spines |
| 09 Solarpunk (`solarpunk`, r003) | Deep teal in a brass frame (`nine`), cream buttons | A brass-framed kiosk with a planted cap. The Yard is a timber loading dock under a solar canopy. The observatory is a brass roster with teal enamel plates |
| 10 Neon noir (`neon_noir`, r004) | Dark navy glass, cyan edges, `glow` | A glass totem with a cyan edge light. The Yard board is an emissive sign wall, and the Night Market is its home. Stale states desaturate and stop glowing, so colour is never the only cue |
| 08 Pixel art (`pixel_art`, r008) | Navy pixel frames (`nine`), pixel font at whole-number scales, `glow` | Tile-sprite kiosks and noticeboards. The pixel font is drawn only at whole-number scales, so near text uses the overlay. Chips are 2-colour sprite icons |
| 11 Low-poly tropical (`lowpoly_tropical`, r004) | Cream panels; chunky green, orange and yellow buttons | Exactly the FACILITY panel: a cream totem with chunky buttons. The Yard has faceted crates on a veranda dock. The observatory is a painted plank roster |
| 02 Voxel (`voxel`, r003) | White panels, square colour tiles, blocky type | A block kiosk with square icon tiles. The Yard has voxel crates in bay grids. Chips are block badges above the robots' display heads. The existing voxel robots already carry display eyes |

**Rules for every style.**

- A style may change materials and frames, but never the meanings.
- Every surface must meet the normal-play performance gate: within 3% of the empty scene's frame rate at vsync (game-interface spec, section 1).
- Diegetic text rebuilds only on change (`scene_model.gd` already emits a headline only when it changes).

---

## 5. Sequencing

Each phase is its own sub-project, with its own spec, plan and implementation cycle, and PRs in its owning repository. The tram, rooftops and conversations come first, as Rakesh ordered. I1 and I2 can be specified in parallel with them.

| Phase | Scope | Owning repo | Depends on | Ships as |
| --- | --- | --- | --- | --- |
| **I0. Decisions** | Settle §6's items 1–4, 6 and 7. Record them as RDs | agentnagar | Rakesh | Decision records |
| **I1. Contracts and core** | `provenance`; the wall-clock display stamps; `ObservePlace` and its panel types; a place registry with F and D aliases; new map categories if chosen; invariants and property tests for panels; `city feed` CLI and MCP | agentnagar `city/` | I0 | Fixture-backed, headless |
| **I2. SJL workshop in the district** | The D02 village form: one shared workshop with four product corners, a post counter and an F19 roster wall, in the district fixture and in all six packs | agentnagar | I1; after rooftops, for building shells | Fixture scene |
| **I3. Interfaces in style** | Tag and card freshness; the kiosk (Browse only); the Yard board; shelves and reader; the noticeboard; the roster; the map-card status; list and text equivalents. Six skins, with sheet-match evidence and a performance gate | agentnagar | I1, I2; conversations, for Ask later | **First shippable slice: fixture-labelled** |
| **I4. Relay and curated mode** | The `city-feed` relay (verify, bind, allowlist, stamp, log); curated snapshots from the products' CLIs; live mode pinned to 1× | agentnagar | I1; `city-server` (sub-project 4) for multi-client live, but a recorded curated file can load in the client before that | **Curated slice**, real but hand-refreshed |
| **I5. Internal SJL decision: public projections** | A decision record covering the opt-in public-projection contract, push signing, the `agent.status`, `card` and `run` event shapes, and the city as a consumer. Trace producers (hub, Board DO) and consumers (relay, Supermessage) | SJL (internal decision) | I0 | Accepted decision |
| **I6a. AgentPod export** | An opt-in published-cast allowlist; connection and process with an observation timestamp; signed push; CLI and MCP | agentpod | I5 | Product release |
| **I6b. Superpipeline projection** | A per-board publish opt-in; run-state push events (beyond `work.available` and `gate.pending`); an MCP board read (closing the run-read gap) | superpipeline | I5 | Product release |
| **I6c. SuperMD publishing** | A headless export of an approved vault revision: HTML plus a catalogue manifest, reusing `html-export`, with CLI and MCP | supermd | I0 (which vault, licence) | Product release |
| **I7. Live: one agent, then the Guild** | Connect one opted-in agent end to end. Disconnect it and watch it expire. Then all 14. Then one published board and one vault | agentnagar plus products | I4, I6a, I6b, `city-server` | **Live slice**; the W1 gate |
| **I8. Post Office notices** | A read-only reader for designated public rooms | agentnagar, homeserver | The RD05 homeserver decision; the internal Matrix identity decision | Later |
| **Out of scope** | Book, Ask, dispatch, comments, sign-in, credits | — | The untrusted-input model (`ROADMAP.md`, W1); city accounts (`CITY_SYSTEMS.md`, gap 1); RD04's matrix | Later plans |

**The critical path to live** is I0, then I5, then I6a and I6b, then I4 with `city-server`, then I7. It runs through three repositories and one unbuilt server.

**What ships first** needs none of that:

- I3 on fixtures (all six styles);
- then I4 curated snapshots.

Both are honest about being fixture or curated, and both exercise the whole visibility and staleness path.

---

## 6. Open decisions

1. **Where each Guild agent's task state comes from.**
   - The options:
     - (a) Superpipeline runs;
     - (b) an AgentPod work exporter;
     - (c) a self-report by the Hermes profile;
     - (d) git activity.
   - **Recommendation:** (a) for task, and AgentPod for connection and process, matching the plane split in SJL's internal decisions. An agent whose work does not go through a board shows "task status unavailable", never a guess.
   - **Check first:** whether Guild work actually runs through Superpipeline boards today. This was not verified.
2. **Which work-state fields are public, and how redaction works** (RD01's opens; `AGENT_CITY.md:194-202`).
   - The options:
     - (a) public projects only;
     - (b) private work shown as "working" with no detail;
     - (c) operator approval per project.
   - **Recommendation:**
     - headline and freshness for every published agent;
     - a project name and one-liner only for projects on an allowlist, with `summary_public` set per source;
     - "idle" and "redacted" rendered identically;
     - failing closed.
3. **How product state reaches the city.**
   - The options:
     - (a) product-owned opt-in public projections, pushed and signed;
     - (b) a city service principal that pulls;
     - (c) curated snapshots only.
   - **Recommendation:** (a), with (c) as the interim. It needs an internal SJL decision record (I5).
4. **Who owns place IDs, and where the SJL Quarter sits.**
   - The options:
     - (a) agentnagar owns a place registry with F and D aliases, which the website consumes;
     - (b) the website owns it;
     - (c) none.
   - **Recommendation:** (a).
   - **Build D02 in its village form first.** That is one workshop with four corners, a post counter and an F19 wall, rather than four buildings. Decide whether the map gains categories such as Lab or Post, which changes the consistency contract's four categories.
5. **Product state inside the core or beside it.**
   - The options:
     - (a) `ObservePlace` in the core;
     - (b) a separate display channel from the server.
   - **Recommendation:** (a). It gives one visibility and staleness engine, property-tested and replayable.
6. **World clock or wall clock in live mode.**
   - The options:
     - (a) keep the simulated day, with wall stamps for display only;
     - (b) tie the city clock to real time.
   - **Recommendation:** (a). RD11 already treats world time as mood. Speed-ups are for fixtures only.
7. **The relay's runtime.** RD18 lifted RD15 only for the core and the room server.
   - **Recommendation:** Rust, in the `city/` workspace, sharing `city-contracts`. It needs an explicit choice.
8. **The public outcome of a failed, rejected or cancelled run.**
   - The options:
     - (a) "Finished" for every terminal state;
     - (b) show the failure publicly.
   - **Recommendation:** (a). The outcome goes to project members and operators later.
9. **What the public sees of Book and Ask on kiosks.**
   - The options:
     - (a) hidden until they exist;
     - (b) visible but locked, with an explanation.
   - **Recommendation:** (a) now, and (b) once sign-in exists, to meet W1's "notice of what higher tiers would allow".
10. **Fixed headline semantics across styles.**
    - **Recommendation:** yes. Fix the icon, shape, label and colour of each headline, with colour never the only cue.
11. **Supermessage's place.**
    - The options:
      - (a) a release and capability exhibit only, until RD05 settles the homeserver;
      - (b) public-room notices now.
    - **Recommendation:** (a).
12. **How the city's character maps to the agent's principal** (the open conflict in `AGENT_TOOLING.md`, "Agent roles and credentials").
    - **Recommendation for display:** the same principal, with a narrower city projection grant, as SJL's internal decisions model it. Revisit before any interaction.

---

## 7. Risks

| Risk | Consequence | Mitigation |
| --- | --- | --- |
| **A status line leaks private work**: a title, a branch, a customer, or the *timing* of work | Private SJL or operator data goes public | Owner-side allowlist plus a relay allowlist; no free text by default; property tests that no non-public field reaches `Public`; a W1 stranger test before any live exposure |
| **Aggregates reveal hidden occupants**: "7 running" counts private agents | An RD12 breach by inference | Counts over the published cast only; extend the inference invariant to panels |
| **Fixture or curated data is mistaken for live**, or a snapshot goes stale silently | False claims about real agents | Provenance on every record and projection; short expiry on curated data; a HUD notice |
| **A human token ends up in a service** "just to prototype" | Breaks SJL's internal identity decisions and AGENT_CITY | The relay has no credential store for product APIs; curated mode is an operator's manual export |
| **Product surfaces churn**: `apn fleet` became `agentpod-fleet`, and the `supi` auth changed in the past week | The adapter breaks | Bind to versioned contracts and schemas, not command names; the relay checks versions and marks panels stale on mismatch |
| **A live feed breaks determinism** | Replays diverge; bugs can't be reproduced | Only logged inputs drive the core; a replay test in CI; no upstream calls on replay |
| **The relay's push endpoint becomes a public write surface** | Injected fake state | HMAC over exact bytes, failing closed; per-product secrets; a schema allowlist; rate limits. Reuse the hub's push design |
| **Scope creep across four repositories and SJL's internal decisions** | The city stalls on product work, or a product comes to depend on the city | Ship fixture and curated slices first; exports are opt-in and standalone-safe; one PR per owning repository |
| **The cost of art and text in six styles** | Frame drops; unreadable text, especially at pixel scale | The performance gate per surface; level of detail; overlay text for detail; a placeholder mechanism per style |
| **Post Office content duties** (RD05) | Moderation and legal load | Exhibit only until the homeserver, retention and moderation are decided |
| **Proposals read as shipped** | Contradicts the evidence rules | Every claim in this plan and its specs carries the three labels |
