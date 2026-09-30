# City interactions: design

Date: 2026-09-27. This spec follows the placement grid (`2026-09-27-city-placement-grid-design.md`), which gives every kind anchors, capabilities and state, and every placement an optional binding. That spec fixes the data's shape. This one gives it behaviour.

The user's direction, 2026-09-27:

- Things in the city should be usable, not only solid:
  - chairs to sit on;
  - noticeboards whose content is published by other SJL products;
  - plants that move when someone walks through them;
  - desks with computers.
- **The workstation** "should be like an actual computer running a station from AgentPod". What it shows is decided from the APIs AgentPod and Superpipeline really have (§5.1).

The sources:

- `docs/gameplay/asset-catalogue/CHARACTERISTICS.md`: definitions, instances and presentations, connection points, the reusable capabilities (Inspect, Sit/rest, Read/write/display, Equip/use, Operate/board) and the three activity levels (scenery, on-demand interaction, ongoing activity).
- `docs/planning/2026-09-28-sjl-integration-plan.md` §4: the in-world surfaces (noticeboard, kiosk, Yard board, shelves). There are three layers for each: drawn in the world, an overlay, and plain text. Content comes from typed panels.
- The research on 2026-09-27, read-only, at AgentPod `d4dc301e` and Superpipeline `91c3ba7`. It is summarised in §5.1 with the citations that matter.

The work splits into two parts that ship separately:

- **Part A, the interaction model and the first capabilities:** sit, inspect, read, and plants that sway. It is city-only, with no outside dependency.
- **Part B, the workstation:** it starts in sample mode, with no account, and goes live once the one internal SJL decision in §5.6 is accepted.

Each part gets its own plan.

## 1. Goal and success

Today the only things a player can act on are hard-wired in `main.gd`:

- sitting at a room's seats;
- "Go in";
- "Walk here";
- boarding and leaving the tram.

After this spec, **any placement whose kind offers a capability can be used** the same way, in every style, with keyboard, controller or touch. The workstation opens a real computer onto a real AgentPod station.

**Success is judged in six ways.**

1. **One path for every interaction.** Every action on a placement goes through one prompt and one core command, `Use` (§2): the four existing actions, and every new capability here. `main.gd` no longer special-cases a kind.
2. **You can sit anywhere that looks sittable.** Every `sit` anchor in the district can be sat on: room seats, bench seats, tram-shelter benches, café chairs, library reading chairs, and new perches (plaza steps, the fountain's rim, low walls). This works overhead, in first person and in pixel art.
3. **Reading works and says where it came from.**
   - Every noticeboard, plaque and bookshelf opens its content in an overlay.
   - Its drawn surface shows the same content at a distance-appropriate level of detail.
   - Content is labelled with its source and freshness ("Sample", or "Superpipeline · updated 2 min ago").
4. **Plants respond.** Soft shapes (grass, flowers, low shrubs, curtains) bend when anyone passes through them and settle within a second. This works in every style and costs 0.3 ms or less a frame on the bench scene.
5. **The workstation is a real computer.**
   - **Sample mode,** with no account, shows a recorded station clearly labelled "Sample". Its terminal, chat, files, logs and health behave like the live ones.
   - **Live mode,** signed in, opens the player's own AgentPod stations. It has a working terminal, the agent's chat with permission answers, files, logs, health, changes and lifecycle, plus that station's Superpipeline work: its cards, pending gates to approve or reject, and questions to answer.
   - Everything the player can do matches what the AgentPod console and the Superpipeline web app allow the same person.
6. **Private stays private.** The station's content never enters the city core, its input log, replays, projections, the network server, logs or crash reports. Other people see only that someone is at the desk and the screen is in use. The recorded tests check each channel (§7).

## 2. The interaction model (Part A)

### Anchors, reach and the prompt

The placement grid gives each kind typed anchors (`enter`, `sit`, `use`, `display` and `stand`) and a list of capabilities, each naming the anchor type it happens at. **The anchor defines where an action happens.** To sit, you are on the sit anchor's cell. To use or read, you stand on the anchor's cell, or on a neighbouring cell facing it.

**Choosing the target.** The client offers one target at a time:

- **First person:** the placement under the crosshair, when its anchor is within 3 m.
- **Overhead and pixel art:** the nearest anchor within 1.5 m, in front of the player (within 60° of facing). A soft reticle marks it, as today's seat reticle does.
- **Touch:** tapping a placement targets it.

**The prompt** shows the target's first capability verb on the act button. A second button (Y on a controller, E on a keyboard) cycles through the others. **Inspect** is always last.

**Acting from a distance.** When the target is out of reach, act sends a Go to the anchor and then the Use, which is what "Sit here" does today.

### The core command

`Use { placement, capability, anchor }` is a player command, and the same shape serves agents. The core accepts it when all of these hold:

- the kind offers the capability at that anchor type;
- the occupant stands where the anchor requires;
- the anchor is free: `sit` and `use` anchors hold one person; `stand` anchors hold one each, with their neighbours as overflow;
- the capability's own rule allows it.

**While it lasts,** the occupant carries `using: { placement, capability, anchor }` in its projection, which everyone sees ("sitting", "reading", "at a workstation"). Moving, a Go, leaving, or `StopUsing` releases it, and so does disconnecting, as seats release today.

**The existing actions become capabilities.**

| Today | Becomes |
| --- | --- |
| A room seat | Its furniture's `sit` anchor. The seat's rules (pods, reservations, capacity) still apply inside `sit`'s own rule. |
| Boarding the tram | `board` on the vehicle |
| "Go in" | `enter` on the building's door span |

Their events and invariants are unchanged.

**No Use changes the grid,** and no Use changes another person. Capabilities that move or change things (`carry`, `store`, `open`, and setting state) are later work (§8).

### The first capabilities

| Capability | Kinds | Rule | What the player gets |
| --- | --- | --- | --- |
| `sit` | Every seat kind; new perch kinds: `steps`, `low-wall`, `fountain-rim` | Room seats keep their rules. A perch is open to anyone and does not count against room capacity. | Sit pose, view, "Stand up". Agents never pick perches; the seat policy chooses only seats. |
| `inspect` | Every kind | None | The overlay card: the kind's name and description (new catalogue fields `name` and `description`), its capabilities, and for a bound display, its source. It is also the accessible text for every object. |
| `read` | `noticeboard`, `plaque`, `bookshelf`, `kiosk` (Browse only) | None | The display's content in an overlay. Near the display, the in-world surface draws a summary. |
| `use` | `workstation` (Part B) | §5 | The computer. |

### Content for displays

A display shows its placement's `binding`, which is `{ source, ref }`.

- **Part A** ships one source, `sample`: text and item lists bundled with the district fixture in `fixtures/district/panels/`, each marked "Sample". Examples:
  - the Square's noticeboard carries dated notices for the city's own releases (v0.0.1–v0.0.3);
  - the library shelves carry spines titled from the vision documents.
- **Later sources** are the integration plan's typed panels (`Notices`, `Board`, `Catalogue`, `Roster`), delivered by its `ObservePlace` command. There the panel is keyed by the placement's ID, not only by the facility, so two boards in one room can differ. The overlay and the in-world surface render any panel type the same way whatever its source, so switching a board from sample to live is a data change.

**Levels of detail,** as the integration plan sets them:

- **far:** only the board's icon or chip;
- **within 8 m:** headlines;
- **open:** everything.

In-world text never carries anything the overlay lacks. The overlay is the screen stack's `PanelScreen`, skinned by the style's `ui` block, and the text layer is the map's List tab.

### Plants that sway

A `soft` shape from the catalogue responds to anyone whose body passes through it: players, residents and agents alike.

- **Client-side only.** Nothing is simulated in the core, since nothing depends on it. Each style draws the response in its own way:
  - 3D styles bend a vertex-shader uniform per instance, with an impulse from the direction of contact that springs back within a second;
  - pixel art plays a three-frame rustle on the sprite.
- **Budget.** Contacts are computed only for people within 15 m of the camera, against a per-district spatial hash of soft shapes. All of it costs 0.3 ms or less a frame on the bench scene.
- **Scope.** Solid footprints never sway: trees keep solid trunks. Their foliage above 1.9 m may stir in the wind as it does today.

## 3. Structure (Part A)

- **Contracts:**
  - the catalogue's `name` and `description`;
  - `Use` and `StopUsing` commands;
  - `using` on occupant projections;
  - the `sample` panel format (`Notices`, `Shelf` and `Plaque`).
- **The core:**
  - `interact.rs`: the Use rules, anchor occupancy, and releasing on move, leave and disconnect;
  - `world.rs`: seats, board and enter reached through Use;
  - invariants: an anchor holds at most its capacity, and `using` always names a placement the occupant stands at.
- **The client:**
  - `core/interact.gd`: targeting, the prompt, cycling capabilities, and Go-then-Use;
  - `core/ui/panel_screen.gd`;
  - `core/soft_contacts.gd`;
  - `main.gd` loses its per-kind cases.
- **Style packs:**
  - the new kinds (noticeboard, plaque, kiosk, perches, workstation) drawn in every style;
  - a `surfaces` block that says how each draws a display's far, near and open layers;
  - the sway response.
- **Evidence,** under `city/godot/evidence/interact-*`, per style:
  - sitting on each kind of seat;
  - a noticeboard far, near and open;
  - a before-and-after of grass parting.

## 4. The workstation: what it is (Part B)

A `workstation` is a `seat`-class desk kind, so a workstation in a room is also that room's seat, with its pod and reservation rules. It has three anchors:

- a `sit` anchor, the chair;
- a `use` anchor at the same point;
- a `display` anchor, the monitor.

It may also have a `stand` anchor behind the chair, for looking over a shoulder. Its placement's `binding` is either empty, which makes it a hot desk, or `{ source: "agentpod", ref: "<station key>" }`, which makes it a station's own desk.

**Sitting and using it** turns the desk into a computer:

- The camera settles behind the chair, and the monitor's content fills the screen as the **station computer**: a full-screen overlay framed as that style's monitor.
- It has a small desktop and a dock of apps (§5.2).
- Everything typed goes to the computer. **F10**, the bezel's "Stand up", or controller B held for half a second always leaves. Esc leaves too, except while the terminal has focus, where the shell needs Esc.
- Controller-only players can use every app except typing into the terminal and chat. On phones and tablets, the system keyboard appears for those.

**Which station it opens:**

- **A hot desk** lists the stations the signed-in player can see and opens the one chosen.
- **A station's own desk** opens that station, if the player's credential can see it. Otherwise it says "You don't have access to this station". **The city never decides access:** AgentPod does, with the player's own token.
- **When a Guild agent sits at its own desk,** anyone can see that the screen is in use. A player whose credential can see that station may stand at the `stand` anchor and choose "Look at screen". That opens the same computer in watch mode, where input is off and the agent is not interrupted.

**What everyone else sees:**

- the person sitting, with `using` set to "at a workstation";
- a monitor drawn "in use": the style's screen glow, and a coarse activity pulse while the station's session is working. Watch mode and the player's own view get the pulse from the hub; other viewers see only the glow.

No other viewer receives any station content, in any mode.

## 5. The workstation: the station computer (Part B)

### 5.1 What the products really offer

Research on 2026-09-27; the full notes are git-excluded working files.

**AgentPod** (`d4dc301e`):
- **What a station is:** "a single place where an agent works" (`docs-site/src/content/docs/use/stations.md:6`). It is a runtime on a node with capabilities such as `terminal`, `logs`, `fs.read`, `fs.write`, `lifecycle`, `acp`, `changeset` and `skills.inventory` (`packages/contract/src/station.ts:2,11-17`).
- **Its console** shows one station as tabs: chat, health, logs, files, terminal, skills, changes, cleanup, activity and identity (`apps/console/src/routes/nodes/[id]/stations/[stationId]/+page.svelte:60-80`).
- **Every surface is a documented hub route:**
  - a PTY over WebSocket (`GET /api/stations/:id/terminal`: `{t:"input"}` and `{t:"resize"}` in; base64 `{t:"data"}` and `{t:"exit"}` out; `apps/hub/src/routes/station-terminal.ts`);
  - ACP chat sessions over WebSocket, carrying prompt, cancel, permission answers and mode (`station-acp.ts`), with states `starting`, `idle`, `working`, `waiting` and `ended` (`packages/contract/src/acp-session.ts:5-8`);
  - files, logs and health (running, cpu, memory, disk, uptime);
  - changeset status and diff;
  - start, stop and restart;
  - `GET /api/fleet/agents`, which lists the viewer's stations.
- **Only a human principal** may use these routes: agent and service tokens are refused (`apps/hub/src/auth/middleware.ts:190-199`).
- **There is no desktop, VNC or screenshot surface.** The old ones belonged to the retired pre-pivot product (`docs/archive/README.md:3-10`). There is also no public projection of status, and no route accepts a `service` principal.

**Superpipeline** (`91c3ba7`):
- **Links to AgentPod:** a card's `delegateAgentId` and a run's `agentId` name a Superpipeline `Agent`. That agent's `externalId` optionally names an AgentPod principal (`packages/contract/src/entities.ts:115-131,153-169,228-239`).
- **Human REST routes:**
  - read a board snapshot with its stages, cards, gates, elicitations and references (`GET /v1/boards/:id`), plus a live WebSocket (`/ws`);
  - card activity and attempts;
  - move and create cards;
  - resolve a gate (`POST …/gates/:id/resolve`, human-only);
  - answer an elicitation (`POST …/elicitations/:id/answer`, human-only).
- **A hub-issued human token** is verified offline and accepted, which is how `supi` authenticates (`apps/api/src/auth/resolve.ts:172-224`, `packages/cli/src/credential.ts`).
- **There is no embeddable UI, no per-board publish flag, no service credential, and no run read for humans** (`GET …/runs/:runId` is agent-only).

**What follows:**
- A **real computer onto a station** is possible today for **the person whose stations they are**: the city client acts as that human's own client, as the console and `supi` do.
- A computer showing the screen **pixel for pixel is not possible,** because no product streams pixels. Instead, the station computer renders what the console renders, from the same APIs, in the city's style. For a coding agent, those are the true surfaces: its terminal, its conversation and its files.
- **Showing anything to people who are not signed in as the owner** needs the integration plan's public projections, which are unbuilt. So bystanders see no content (§4).

### 5.2 The apps

Each app is the city-styled counterpart of a console tab, calling the same route. None of them invents data.

| App | Shows | Can do | Route (AgentPod hub unless marked) |
| --- | --- | --- | --- |
| **Terminal** | A real shell on the station, as an 80×24 or larger grid, resized to fit | Type, paste, resize | The PTY WebSocket |
| **Chat** | The agent's session: prompts, replies, tool calls, and permission requests | Send a prompt, cancel, answer a permission request (allow or deny), switch the mode (`ask`, `accept-edits`, `full-auto`), open a new session | The ACP session routes and WebSocket |
| **Files** | The workspace tree, with a preview of text files | Read only in this spec | Files and file |
| **Logs** | A live tail | Pause, search | Logs |
| **Health** | Running, cpu, memory, disk, uptime, node online or offline | Start, stop and restart, each confirmed | Health and lifecycle |
| **Changes** | Changeset status and a diff viewer | Read only | Changeset status and diff |
| **Work** | This station's agent's Superpipeline cards (through `Agent.externalId`), each card's stage, status chip and activity, pending gates on those boards, and open questions | Approve or reject a gate, with a comment; answer a question; move a card the player may move | **Superpipeline** board snapshot and WebSocket, activities, gate resolve, elicitation answer, card move |

The **desktop** shows the station's name, purpose, node, status chip and the time. Its dock opens each app, and apps whose station capability is missing are greyed out, with the reason.

Actions not in the table are left to the console and the web app: file writes, skills, cleanup, identity, and board administration. Each such action is offered as "Open in the AgentPod console" or "Open in Superpipeline", which opens the system browser. Nothing is hidden, and nothing is reimplemented twice.

### 5.3 Rendering

- **Where the code lives.** The station computer is a `Screen` on the screen stack, drawn with the style's `ui` block inside a monitor bezel the style provides: a CRT for pixel art, a glass panel for neon, and so on.
- **The terminal.** Its grid comes from a VT parser in Rust: the `vt100` crate, exposed through `city-godot` as `TermGrid` (feed bytes, read changed rows, colours and the cursor). GDScript draws the rows with the style's monospace face.
- **Networking** stays in GDScript (`HTTPRequest`, `WebSocketPeer`), so the web and mobile exports work.
- **The in-world monitor** shows the same screen through a `SubViewport` at a low resolution, updated at 10 Hz. It updates only for the player's own desk, while they sit there or watch within 4 m. Every other monitor is a static "in use" or "idle" texture.
- **Pixel art** draws the desk and monitor as sprites. Its station computer uses the pixel font at whole-number scales, falling back to the overlay face for small text, as the integration plan requires.

### 5.4 Sample mode

Without a sign-in, every workstation opens **Sample station**: a recording bundled with the client under `city/godot/sample_station/`. It holds:

- a terminal session (an asciicast of a short build and test run);
- an ACP chat transcript, with tool calls and one permission request;
- a file tree;
- a log tail;
- a health series;
- a diff;
- a Work tab with one board, one pending gate and one question.

It is synthetic, written for the purpose, and contains no real data from any station. Actions work against the recording: answering the sample's gate plays its recorded result. Every screen carries the "Sample" label, and the desktop offers "Connect your AgentPod".

### 5.5 Live mode: signing in and trust

- **Signing in.** It goes through the suite's issuer, not the city. The client uses the issuer's device-authorization flow as `apn fleet login` does. It holds a device credential and exchanges it for five-minute human tokens (an internal SJL decision, accepted 2026-09-20: "A human at a terminal has nothing to exchange"). The issuer's URL is configurable, following a draft internal SJL decision ("Signing in is not a product's verb"), so the city names no product's paths as if they were the issuer's identity. "Connect your AgentPod" and "Disconnect" live in Settings and on the desktop.
- **Storing the credential.** It sits in the client's user data with owner-only file permissions, and the tokens stay in memory. Neither is written to any log, and neither is sent to the city core or any city server. Disconnecting deletes the credential and revokes the device with the issuer.
- **One token for both products.** The same hub-issued human token calls AgentPod's routes and Superpipeline's, which already verify it offline. If an audience check refuses that, the Work tab asks for its own sign-in, in the same flow.
- **Which station counts as "yours"** is only what the token can see. The city holds no list of who owns which station.
- **Real operations are marked as real.**
  - Live mode shows a "Live" badge and the station's name on the bezel.
  - Stop, restart, gate rejection, and a chat mode switch to `full-auto` each ask for confirmation, with the station or board named.
  - The terminal is a real shell, and the first time a session opens it the desktop says so.

### 5.6 Before live mode ships

**An internal SJL decision:** *"The city client is a first-party human client of the suite issuer."* It records:

- that the city client may hold a human device credential;
- that it calls AgentPod's and Superpipeline's human routes on its own user's behalf;
- that it never forwards their content to the city's servers.

It traces the producers (the hub, Superpipeline's API) and the consumer (the client), following the workspace's rule for cross-product contracts.

- **Sample mode** needs no decision and ships with Part B.
- **Live mode** stays behind a setting that is off by default until the decision is accepted.
- **New product work** is not required for the owner's own computer. The design uses only routes that exist today. Two things the research found missing wait for the integration plan: showing station content to anyone else, and a run read for humans.

## 6. Structure (Part B)

- **Kinds:** `workstation`, in the catalogue.
- **Placements:**
  - the Guild hall workshop's desks become workstations, each bound to nothing (hot desks) in the fixture;
  - the library gains two public hot desks.
- **The client:**
  - `core/station/`: `client.gd` (HTTP and WebSocket, the token lifecycle), `credential.gd` (device flow and storage), `sample.gd` (the recording player behind the same interface), `apps/*.gd` (one per app), and `computer_screen.gd` (the desktop, dock, bezel and focus rules);
  - `core/interact.gd` gets the `use` capability's hand-off to the computer.
- **`city-godot`:** `TermGrid`, wrapping `vt100`.
- **Style packs:** the workstation, the monitor bezel, and "in use" and "idle" screens, in every style.
- **Internal SJL decision:** the decision in §5.6, recorded separately by SJL.

## 7. Testing

**Part A.**
- **Core:**
  - Use accepted and refused for each rule;
  - anchor capacity;
  - release on move, Go, leave and disconnect;
  - the existing seat, board and enter scenarios unchanged through Use;
  - determinism: a replay with Use commands is byte-identical;
  - new invariants on every tick of the scenario gates.
- **Client:**
  - targeting in each view (first person, overhead, pixel art, touch);
  - prompt cycling;
  - Go-then-Use;
  - panels at far, near and open, and their source labels;
  - sway contacts against a scripted walker, and its frame cost within budget on the bench scene.

**Part B.**
- **Against a fake hub.**
  - A test server in the Godot suite speaks the recorded protocols: the PTY frames, ACP events, fleet and health JSON, and Superpipeline's snapshot, gate and elicitation calls. It mirrors the named hub and board handlers at the cited commits (the routes changed in the final fix wave name the handler they mirror); it is not generated from the contract packages. (Corrected in the final fix wave.)
  - Each app is tested against it: output rendering, input sent, confirmations, errors (401 prompts a sign-in, 403 shows "no access", offline shows "Station offline"), and reconnection.
- **`TermGrid`:** Rust tests with VT sequences covering colour, cursor moves, clear, the alternate screen, and wide characters.
- **Sample mode:** every app plays the recording, and every screen carries the Sample label.
- **Privacy, checked by recording every channel during a scripted live session against the fake hub:**
  - the core input log, projections and replay;
  - the client's log file and error watch;
  - bridge calls;
  - what the network layer would send to a city server.

  The test fails if a marker string planted in the fake station's terminal, chat, files and board appears in any of them. Other viewers' projections carry `using` and nothing more.
- **Live, manual and authorized:** one session against the operator's own development hub and board, recorded in the evidence notes. Live infrastructure is not used in automated tests.

## 8. Not in this spec

- Capabilities that change things: `carry`, `store`, `open` for doors and drawers, `write`, and player-set instance state.
- Showing station or board content to anyone but its owner: public projections, as in the integration plan's items I5 and I6.
- File writes, skills, cleanup and identity on the station computer (use the console), and board administration (use the web app).
- A pixel stream of a station's screen. No product provides one.
- Conversation close-ups with agents: their own follow-on spec. The chat app is the station's ACP session, not an in-world conversation.
- Kiosk Book and Ask. There is nothing to book yet, and Ask belongs to the conversation spec.

## 9. Risks

- **A real shell inside a game.** A player may do something irreversible. Mitigations:
  - the "Live" badge;
  - the first-open notice;
  - confirmations on lifecycle, gate rejection and `full-auto`;
  - the same access as the console, with no escalation.
- **Leaking private content through the city.** Station traffic never touches the core or any city server, and the planted-marker test checks every channel on every run.
- **Protocol drift in AgentPod or Superpipeline.** The recordings are pinned to cited commits, and the fake hub fails on unknown message types. A drift check against a live development hub is a manual step before each release that ships live mode.
- **Identity decisions still in draft.** Sample mode ships regardless. Live mode waits for the §5.6 decision, and the issuer URL is configuration, so moving the issuer is a settings change.
- **Typing on controllers and phones.** Controller-only play covers everything except typing. Phones and tablets use the system keyboard, and desktop controller players are told a keyboard is needed for the terminal and chat.

## 10. Amendments

### 2026-09-29: decided during the build (Part A)

The build settled these points, which the sections above leave open or say
differently. Where they differ, these hold.

**The core.**

- **`inspect` never reaches the core.** An anchorless `inspect` targets the
  placement at its point (the nearest walkable cell within reach counts as
  "at" it). Only the stateful capabilities — `sit`, `read`, `use`, `board`,
  `enter` — go to the core as a `Use`; `inspect` changes nothing, needs no
  `using`, and the client handles it alone, per §2's "No Use changes the
  grid".
- **`StoppedUsing` fires only for uses a `Use` began.** A seat taken by `Go`
  or the seat policy releases with `SeatReleased` alone, so an agent's event
  log is unchanged by whether a seat is reached by walking in or by `Use`.
- **Anchor facing.** A `sit`, `use` or `stand` anchor's facing is its user's
  own facing; a `display` anchor's facing is the surface's outward normal.
  `read` is valid standing on the display's own `stand` anchor, or on a
  walkable neighbour of the display within 45° of its normal; `use` is valid
  only on the anchor's own cell. On success the occupant turns to face what
  it reads or uses.
- **Any new `Use` first ends the one under way** — a seated reader releases
  its seat before taking the new use — so `using` always names exactly one
  thing.
- **Stand-anchor overflow applies only to a new `Use`.** A stand use already
  under way stays valid on any walkable neighbour of the anchor; only a
  fresh `Use` needs the anchor's own cell held by someone else before it may
  land on a neighbour.
- **`Capability.at` is `Option<AnchorType>`,** skipped when `None`. Only
  `inspect` may omit it; every other capability names the anchor type it
  happens at.
- **`low-wall` is an unsized, fixed 3 m module** with five `sit` anchors
  (x = −120…120 cm, step 60), all facing out. A longer wall is several
  modules; anchors are fixed per kind, and the spec never asked for a
  size-dependent count.
- **Tram-shelter benches are perches.** §1 criterion 2 names them, so the
  `tram-shelter` kind has three `sit` anchors along the front of its bench
  (x = −25, 55, 135 cm; z = 15 cm, 30 cm clear of the bench's face so the
  anchor's cell stays walkable however a shelter is turned), sat facing the
  platform, and offers `sit` there. Like the steps, they are open to
  anyone, hold no room capacity, and agents never pick them; each style
  draws a perch seat at each anchor and its sitters on it.
- **Sized soft ground.** A sized kind that declares `soft` shapes and no
  `footprint` — the meadow — takes its placement's size as soft ground: it
  blocks nothing, and the client fills that size with soft shapes. A block,
  which declares neither, keeps its solid lot.

**The client.**

- **Controller rebinding.** Y cycles the prompt's other actions (the second
  button beside the act button); name tags move to controller X, since Y
  was the only free-able face button. The developer-only "Open all" keeps
  keyboard X and its F3 panel button.
- **A tap acts, not only targets.** Tapping a seat or a placement's solid
  footprint acts at once, with its first verb — this keeps "tap a free seat
  and sit there", and a tap on a noticeboard reads it. A tap on open ground,
  meadows included, walks there instead.
- **A tap on an inspect-only target walks there.** Trees, palms, lamps and
  block lots offer only `inspect`; a click or tap on one walks the player
  there, as on open ground, since a click to walk past a tree must walk.
  Inspect stays reachable through the prompt on the target ahead (or under
  the crosshair) and by cycling with E or Y.
- **Board outranks a passive use while the doors are open.** With a tram
  standing at the player's platform with its doors open, "Board" comes
  before a passive use of a placement, under way or offered — a perch sit
  (a shelter's bench) or a read — so a sitter at a shelter can board with
  one press; boarding already ends any use. A room seat keeps "Stand up"
  first (a seated player is offered no tram). With the doors shut, the use
  comes first, as before.
- **Overhead ranking puts usable targets first.** A target offering more
  than `inspect` outranks an inspect-only one at the same distance, then the
  nearer of two wins; an inspect-only target also yields the prompt to the
  tram, so a street tree or a lamp never takes the prompt from a bench
  beside it.
- **Go-then-Use.** The first-person 3 m reach applies to placements' and
  seats' anchors; "Go in" and "Walk here" keep the crosshair's own full
  reach, since they are not anchor-gated. A room seat out of reach is
  reached by `Go {Seat}` then `Use sit` on arrival, exactly as sitting down
  works today.
- **The Read overlay opens only once the core confirms the use.** Opening it
  on the `Use` command alone, before the core accepts it, could show a
  reading screen for a use that gets refused; the overlay now waits for
  `using` to appear in the player's own projection.
- **The map's List tab reads without a `Use`.** Reading a display from the
  map is remote — the player is not standing at it — so it opens the same
  overlay straight from the panel's text, for accessibility, and sends no
  `Use`. Reading a display in the world still goes through `Use`, as normal.

**Pixel art (a deviation).**

- **In-world text is a compact label, not headlines.** Within 8 m, pixel art
  shows only a ≤2-line label ("Sample" and the title, or the first
  headline) for the one targeted or nearest display; a bookshelf shows only
  its far chip. The full content is in the overlay. Drawing every display's
  headlines at 128 px plates within 8 m, as the general "near: headlines"
  rule asks, cluttered the view and hid players standing near a board; this
  narrows it to pixel art, justified by its resolution.
- **`LABEL_Z` and closed buildings.** Pixel chips and name tags draw above
  the rest of the world (their own `LABEL_Z`), so walls and lamps do not cut
  them off mid-sentence. Inside a closed building, both are hidden along
  with the building's own contents, and `pick()` does not select them
  either — otherwise a chip or a name tag would float visibly over a closed
  roof, and a click could reach through a closed wall. An open building
  whose roof is kept on (roofs on) hides its chips and name tags too.

**Evidence and the collision audit.**

- **A perch sitter is drawn on its anchor's world point,** a render-only
  placement, not the core's cell centre. The core still holds the sitter at
  the cell; the drawn offset from the cell centre to the seat is at most
  about 18 cm.
- **The collision audit's perch rule.** A perch (a placement of a kind with
  `sit` anchors: `steps`, `low-wall`, `fountain-rim`, `tram-shelter`) gets the same
  protected square a room seat's own furniture gets, centred on each `sit`
  anchor rather than on a seat's point: 25 cm either way, where a sitter's
  hips rest and the seat's own drawn geometry may stand without counting as
  a collision. Soft ground (a meadow) is walked through outright: whatever
  a style draws inside its lot is not a solid the audit counts at all.
- **Sway's 15 m is measured from the view's focus,** not the camera's own
  position: the orbit rig's ground focus, the first-person eye, or the
  ground point under `Camera2D`. The overhead and diagonal presets stand the
  camera itself 17 m or more back, so measuring from the camera would leave
  grass swaying nowhere in those views.
- **Contacts are checked every other frame, alternating by body,** to stay
  within budget with a full crowd standing in grass. A push can therefore
  start up to one frame late, which the 0.1 s hold before a clump eases in
  covers.
- **Body radius is 0.25 m.** The core carries no body radius; a clump is
  touched when its root lies within 0.25 m plus the clump's own reach of a
  body's ground point.

### 2026-09-29: found while planning Part B

The protocols were read again on 2026-09-29, at AgentPod `9bc1997` and Superpipeline `d53992f`. Where they differ from §5.1, these amendments win.

- **Signing in is not a device-authorization flow.** `apn fleet login` uses the authorization-code flow with PKCE, through a loopback listener on `127.0.0.1` and the system browser (`/api/auth/authorize`, then `/api/auth/token/exchange`). It then mints a 90-day device credential (`POST /api/auth/devices`). Each command exchanges that credential for a five-minute token (`POST /api/auth/devices/token?client=…`). The city does the same, as its own registered client, `agentnagar`.
  - **What the operator must do.** The hub knows clients only from its `HUB_OAUTH_CLIENTS` configuration. So live mode needs that hub's operator to register `agentnagar`, with a loopback redirect and audiences naming both the hub and Superpipeline. This is configuration, not product work, and it is a real operation on a real hub.
  - **Desktop only for now.** A loopback listener is not available to the web and mobile exports, so live mode is desktop-only in Part B. Elsewhere, "Connect your AgentPod" says sign-in needs the desktop app, and the computer stays on Sample station.
- **One token serves both products only through the client's audiences.** Superpipeline checks a token's audience against its own origin. A plain hub token is refused there. A token exchanged with `?client=agentnagar` carries every audience the registration names. §5.5's fallback, a separate sign-in for the Work app, is dropped: a missing audience is a registration mistake, and the Work app shows "Superpipeline did not accept this sign-in".
- **No route links a station to its Superpipeline agent.** `Agent.externalId` is the agent's AgentPod principal (`prn_…`). A station's occupying principal is stored in the hub but not returned to a human by any fleet or station route. So the Work app asks once per station which Superpipeline agent works there, and remembers the answer on the device. It stores IDs only. If a future `principalId` field is added to `FleetAgent`, it would remove that question. That field is not part of this spec.
- **Gate decisions are three:** approve, request changes and reject (`GateDecision`). The Work app offers all three. Request changes and reject ask for confirmation.
- **Offline is reported two ways.** Health, files, file and logs answer 502 with an error naming the node. Lifecycle, changeset and file writes answer 409. The client maps both to "Station offline".
- **Protocol details the apps rely on:**
  - the terminal opens at 80×24 and expects a resize at once;
  - logs are Server-Sent Events;
  - a file read returns a raw body, with truncation in `X-Truncated`;
  - the chat's text is inside `agent-update`'s ACP `sessionUpdate` payload;
  - the board WebSocket is push-only.
- **Watch mode in sample mode.** With no sign-in, "Look at screen" is offered at desks where a Guild agent sits, and it opens Sample station read-only, labelled Sample. In live mode, it needs a bound desk whose station the player's token can see. The fixture's desks are all hot desks, so live watch mode is tested with a test fixture binding.
- **The workstation's `use` is a seat.** `Use {capability: "use"}` at a workstation takes the seat under the seat rules. Switching between sitting and using on the same seat does not release it. `watch` at the `stand` anchor is client-only, like `inspect`.

### 2026-09-30: decided during the build (Part B)

Tasks 1–11 settled further points the sections above leave open or say
differently. Where they differ, these hold.

**Sessions, sign-in and disconnecting.**

- **Disconnect revokes with a human token, not the device token it is
  revoking.** The hub's caller resolution refuses a device token on both
  `DELETE /api/auth/devices/:id` and `POST /api/auth/devices`, so revoking
  with the device's own token cannot work and a fresh sign-in would fail
  the same way. Disconnect instead: (1) forgets the credential locally at
  once; (2) opens a browser sign-in (the authorization-code flow, no
  device mint) to get a human token, and revokes with that; (3) reports
  honestly — "Revoked", or "Not revoked: revoke '<name>' in the AgentPod
  console" with a button that opens it — on cancel, failure, timeout, or a
  404 (the hub scopes the revoke by account, so a different account
  signing in for it gets one while the device stays live). Signing in
  again at the same hub revokes the previous device with the new
  sign-in's own human token first. Changing the hub's address does not:
  a token for one hub is never sent to another, so the old hub's device
  is named, with the console offered. Disconnect is offered wherever
  a credential file exists, live mode on or off, so a player is never left
  holding a device they cannot revoke.

**Watching.**

- **`watch_chat(station_id)` is attach-only.** It lists a station's chat
  sessions and subscribes to the newest one still open, or reports "no
  session" — it never starts one. The ordinary chat route POSTs a session
  when none is open, which would make watching someone else's station
  start a session as the watcher; `watch_chat` is the contract's own
  read-only path, so Look at screen never creates state on a station that
  is not the player's own.
- **Opening the chat lists first; a 409 is only a fallback.** (Corrected
  in the final fix wave; the build first read a 409 as "reuse", and so
  POSTed on every open.) A current hub keeps several sessions a station,
  each its own agent process, and answers every
  `POST /api/stations/:id/acp/sessions` with a new one (201). So the chat
  lists the player's sessions first and attaches to the newest one not
  ended; it POSTs only when none is open, or when the player chooses New
  session (which ends the open one first). A 409 "already exists" comes
  only from an older node that keeps one session a station: the chat then
  lists again and attaches to the newest open one.

**The terminal.**

- **Keystrokes typed while the terminal is offline are refused, not
  queued.** Only input typed before the shell has attached within the
  current connection is held and sent once it attaches; anything typed
  during an outage is shown "Not sent" rather than replayed minutes later
  into a shell that has since done something else.
- **`vt100` is pinned at 0.16.2,** not the spec's 0.15.x guess. 0.15.2
  panics on a one-row grid and, worked around during the build, clamped
  scrollback to a single screen; 0.16.2 keeps the one-row panic (so
  `TermGrid`'s row floor stays 2, `MIN_ROWS`) but reads its full
  scrollback offset without panicking, which the 0.15.x clamp had been
  hiding a real limit behind.

**Boards and Work.**

- **The board snapshot arrives on the board WebSocket's first frame**
  (`kind: "snapshot"`), on first connect and on every reconnect; the
  client never calls `GET /v1/boards/:id` separately, since the socket
  already sends the whole state and a REST fetch would only duplicate it.
- **The Work app's cards for a station's agent** are the cards whose
  `delegateAgentId` is the linked agent, or whose pending gate's
  `producedBy` is, or whose pending question's `agentId` is — a card with
  a gate open on it has `delegateAgentId` null on the real board, so the
  delegate field alone would miss it. A card shown in Work stays visible,
  marked with its new state, until Work is reopened, even once the gate or
  question that linked it there is resolved; a card vanishing the moment
  it is approved reads as a failure.

**Desks and binding.**

- **A station's own desk is a placed workstation carrying a binding**
  (`{source: "agentpod", ref: <station ID>}`); room seats carry none
  (`city-contracts`' `Seat` has no binding field). The district fixture's
  desks stay hot desks, as §6 says; bound desks and live watch are
  exercised by a small test fixture that places one bound workstation, not
  by the city's own fixture.

**Rendering (§5.3 amended).**

- **Pixel art's monitor carries no live feed.** §5.3 says the in-world
  monitor updates through a `SubViewport` for the player's own desk; in
  pixel art that viewport would be 9×5 pixels, which shows nothing
  legible and, worse, reads no differently from "idle" — hiding the one
  signal a player has that their own desk is live. Pixel art instead
  shows the same in-use glow, brightened by the activity pulse, for the
  player's own desk; the 3D styles keep the `SubViewport` feed as
  specified.
