# Tools for building and operating the city

Tool strategy and researched options · updated 2026-09-18 · [Plan index](../README.md)

**Status, 2026-09-18.** Two decisions reframe this brief. RD15: technology
choices wait for a clear vision, the evaluation of the best available
technology for each use case continues, and nothing below is chosen unless a
decision ID says so. RD13: Forgejo will run on the lab server as the agents'
dedicated git system. RD02 adds a preference: the city should run on SJL
products in active development wherever one fits. Rows that said "first",
"recommended" or "leading" record the September research ranking, not a
selection. See the [evaluation stance](PLATFORMS.md#evaluation-stance).

**Agents must be able to use the tools that build and operate this city.**
Rakesh requires MCP and CLI access as prerequisites. The
[automation evidence catalogue](../research/TOOL_AUTOMATION.md) checks both
surfaces for each discussed product, including the alternatives below. The
[agent tooling contract](AGENT_TOOLING.md) defines the acceptance rule and the
city-specific editors, command interfaces and operating tools still to design.

All tool candidates below are subject to that requirement. A UI-only
workflow, documentation-only MCP or missing CLI keeps a candidate conditional;
a proposed adapter is additional work, not an existing capability. The project
remains in vision planning. These documents do not authorise implementation,
installation, a hosting change or repository migration.

## The complete tool picture

The city needs tools to create its world, tools to run real maker projects, and
tools to operate its institutions. It also needs its own domain tools: an engine,
forge or dashboard does not already implement a public library, tax policy,
resident service allowance or project exhibition workflow.

| Responsibility | Candidate tools / existing products | What the city still owns |
| --- | --- | --- |
| Visual direction, UI and accessible pages | Penpot, plain HTML/SVG; Astro and existing Three.js | Design system, readable direct-entry views, responsive account/project flows |
| Game client and simulation | Candidates: Godot, Bevy and the existing Three.js renderer; none chosen (RD15) | Authoritative civic rules, world IDs, client/server contracts, device budgets and native/web comparison |
| Models, textures, avatars and animation | Blender; optional Blockbench and Krita; curated asset packs | Tropical modular kit, shared rig, plot constraints, asset review and publication |
| Optional AI world models | Marble asset pipeline; conditional HY-World; later learned-agent and neural-world research | Reviewed place packages, object semantics, budgets, model evaluation and city authority; see [research](../research/WORLD_MODELS.md) |
| Sound, dialogue and activity content | Audacity, Ink/inklecate, optional Piper and whisper.cpp | NPC routines, lessons, quests, accessibility text/captions, approved voice/personality choices |
| Multiplayer and persistent services | Candidates: Colyseus, Nakama, headless Godot and Durable Objects for rooms; PostgreSQL for durable state; Redis only if needed; none chosen (RD15) | Permissions, bookings, grants, city ledger, persistence/recovery and integration adapters |
| Real maker work | Superpipeline and AgentPod (preferred under RD02); Forgejo on the lab server (RD13); existing GitHub | Project directory, participation and tool mappings, consented exhibits and contribution recognition |
| Conversation and knowledge | Supermessage/Matrix; SuperMD and file-based content; Pagefind | Audience control, comments, messages and assemblies (core under RD05), library publication, office hours and learning programmes |
| Money and progression | Razorpay (Rakesh's selected provider; global coverage unverified, RD11), conventional city ledger, separate entitlement/recognition records | Offers, verified grants, JC rules, purchasable credits that meter real compute and storage (RD07, RD08), funding allocations, reconciliation and economic scenarios |
| Optional live voice | LiveKit, separately budgeted speech services | Room permissions, capacity, device fallbacks and actual service costs |
| Service operation | Docker Compose, Ansible, Caddy; SJL's private operations own runbooks | Deployment/recovery policy, capacity planning, operator roles and support |
| Observability and recovery | Grafana, Prometheus, Loki, OpenTelemetry; pgBackRest and Restic | Service objectives, useful alerts, audit access, off-host recovery and rehearsed restores |
| Delivery and verification | Selected forge's CI, Playwright, engine CLI tests, asset validators; evaluate gVisor for participant execution | Reviewable releases, visual evidence, reproducible builds, isolated jobs and rollback |

The matrix describes complementary responsibilities and explicit alternatives,
not a shopping list to install in full. Existing products remain independently
usable; the city connects selected capabilities. Outside projects can retain
their own forge, task system, editor and communication tools.

## Forgejo and Superpipeline

**Decided 2026-09-18 (RD13):** Forgejo will run on the lab server, and agents get a
dedicated git system as part of the stack. How it integrates is a later
discussion. Placement details, capacity, isolation, backup, agent accounts and
the [lab/production boundary](STORAGE.md#hosting-role)
remain open. RD13 does not decide who owns task records, so the allocation
below is still a proposal.

Their project-management overlap needs an explicit choice. The current
recommendation is **Superpipeline as the work-management product, Forgejo as the
software collaboration platform, and the city as their shared public
environment**. Superpipeline would own tasks, assignments, runs and acceptance;
Forgejo would own Git, PR review, builds, releases and packages. Verify the
required Superpipeline capabilities before committing to that division.

Forgejo's boards need not be enabled for a project whose work lives in Superpipeline.
An outside project can choose Forgejo alone or keep its existing tools. One
selected authority owns each work record; links and approved projections connect
it to the city. See the [integration proposal](../integrations/development/FORGEJO_SUPERPIPELINE.md)
for all three ownership options, issue intake, CI, mirroring and remaining
decisions. No repository migration or final product allocation is approved yet.

Two verified facts bound the integration work (checked 2026-09-18).
Superpipeline's reference parsing recognises only `github.com` URLs; a Forgejo
URL is stored as a generic link with no provider, type or durable external ID.
AgentPod's run contract lists `forgejo` as a delivery-adapter enum value, and
no Forgejo delivery implementation was found in its source. Forgejo's presence
is decided; its integrations are unbuilt.

## City-specific tools to build later

The proposed product surfaces are **City Studio, Facility Designer, Activity
and Scenario Editor, Character Studio, Creator Portal, Economy Lab, City Control
Room, Community Desk and Resident Dashboard**. Shared Asset Workshop, Build and
Release Desk, and Knowledge Publisher operations support them.

Each needs a human interface plus scoped CLI and MCP operations over the same
domain contract. For example, Facility Designer should let a person or agent
define a school's programme, staff, capacity, funding and closure behaviour;
placing its mesh alone does not create a working school. Economy Lab should
compare taxes and public-service subsidies using fictional scenarios without
access to live balances. The [full tool catalogue](AGENT_TOOLING.md#city-tools-to-design)
records responsibilities, operations and review boundaries.

## AI world models

World models add three possible tool families: spatial generation for reusable
places, learned dynamics/perception for bounded agent experiments, and neural
worlds for temporary destinations. The [research brief](../research/WORLD_MODELS.md)
compares nine model candidates, records CLI/MCP paths and licence/compute limits,
and preserves ideas such as library portals, a Future City Observatory, agent
practice districts and cooperative dream expeditions.

Prioritise an asset-workflow comparison after the vision gate: Marble has
exported assets, official CLI examples and a community MCP candidate. HY-World
is a conditional alternative with material licence and hardware questions.
Learned policies and neural multiplayer remain larger research tracks.
Generated places still require collision, navigation, semantic objects,
accessible alternatives and facility rules; predictions cannot settle money,
change plot ownership or certify real project work. All interfaces remain
subject to the existing adoption rule and end-to-end verification.

## Economy tooling decision

**Blockchain has been discarded by Rakesh.** JC is a conventional city-ledger
design; no cryptocurrency token, NFT or crypto-wallet dependency belongs in the tool stack.
Keep real-money receipts, spendable JC, reviewed contribution standing and
entitlements distinct.

**Updated 2026-09-18.** Real money can purchase credits (RD07), and credits
buy facility access, in-game items, compute and storage (RD08). The ledger is
therefore coupled to usage metering and quota enforcement, and purchased
credits raise legal and tax questions in each market of a global product
(RD11). See [payments and credits](../research/PAYMENTS_AND_CREDITS.md) and
[legal compliance](../research/LEGAL_COMPLIANCE.md). The credit name is open
(RD06); `JC` stays as the working label.

Use balanced postings, append-only corrections, transaction histories and
aggregate treasury reporting to make the economy understandable and auditable.
An economic simulation, tax system, business or resident-to-resident service
does not need a blockchain. See the [economy](../gameplay/ECONOMY.md) and
[Razorpay plan](../integrations/payments/RAZORPAY.md) for the owning rules.

## Proposed execution and hosting

No host is chosen for city services (RD15). The one placement decided is
Forgejo on the lab server (RD13).

Use local workstations for interactive design/editor sessions and measured
previews. The lab server is the proposed home for bounded asset jobs, CI, simulation
and city services; its SSD suits active state and scratch work, while HDD suits
appropriate archives and backup copies. The [storage plan](STORAGE.md) records
the actual earlier inspection and its limits. Heavy CPU jobs must not starve
transactions or multiplayer rooms. GPU generation is conditional on suitable
hardware or a separately funded provider, not presumed lab-server capacity.

AgentPod's existing installation remains a distinct
system. This proposal does not relocate it. Forgejo's host is now
decided as the lab server (RD13); its sizing and isolation are not. Optional
Cloudflare site/API/storage services are alternatives for
specific responsibilities, not an automatic second copy of the entire backend.
The original tooling pass performed no new host inspection. The later
[repository review](../planning/REPOSITORY_REVIEW.md) identified the [lab-server hosting-role decision](STORAGE.md#hosting-role).
Neither pass reserved capacity or approved product hosting there.

Build recipes, schemas, exported manifests and accepted source should be
versioned. Human/agent review controls promotion from draft to public content.
Operator credentials, raw fleet data and payment secrets stay outside clients
and asset repositories. Free software still requires hosting, maintenance,
content review and operator time; MCP wrappers also have an ownership cost.

## Asset and platform baseline

The asset/platform notes below retain the September 15 research, supplemented
by the new automation catalogue. Recheck provider pricing, export rights and
hardware requirements when selecting a workflow; no new asset benchmark was run.

Preserve the working Astro/Three.js site while the client candidates are
evaluated for the expanded city. A small consistent asset kit and the lab server for
bounded CPU work remain the proposal. Any first prototype could use free
software and the existing server. That still costs development time and server
operation; free software does not imply unlimited free hosted compute.

## Candidate starting toolbox

This was the "recommended starting toolbox" of September 15–16. Under RD15 it
is a list of candidates, each with the job it is a candidate for. The last
column says what evidence or event would bring it in, not a schedule.

| Job | Tool | Why it fits | Add it when |
| --- | --- | --- | --- |
| Pages and content | [Astro](https://docs.astro.build/en/guides/content-collections/) | Already used; readable HTML can coexist with an optional world | Keep now; validate content and add document routes |
| Current browser world | [Three.js](https://threejs.org/docs/) | Already drives the village; preserves custom art and interactions | Keep during platform evaluation |
| Native/web game comparison | [Godot](https://godotengine.org/features/) | Integrated scene, animation and UI tooling; candidate for shared game authoring | Only if an authorised comparison includes it; see [platforms](PLATFORMS.md) |
| Modelling and cleanup | [Blender](https://github.com/blender/blender) | Free complete 3D suite; author landmarks, adjust geometry, export assets | First custom asset |
| Simple low-poly props | [Blockbench](https://blockbench.net/) | Free editor for modelling, texturing, and animation | Compare with Blender for the modular kit |
| Base environment kit | [Kenney](https://kenney.nl/assets/city-kit-industrial) | The linked city kit is CC0; a good starting point for coherent low-poly scenery | Reuse existing compatible assets first |
| Asset optimization | [glTF Transform](https://gltf-transform.dev/) + Meshopt | Already used; repeatable transforms and compact geometry | Extend with measured simplification and texture processing |
| Asset validation | [Khronos glTF Validator](https://github.com/KhronosGroup/glTF-Validator) | Detect malformed exports before the browser | Every imported asset |
| UI sketches | [Penpot](https://penpot.app/) or direct HTML/SVG | Open design workflow; useful for the map, cards, and builder controls | Before polishing the 3D interaction |
| Shared rooms | [Colyseus](https://docs.colyseus.io/) | Authoritative state synchronization and room lifecycle | Candidate; an official Godot SDK now exists in beta ([docs](https://docs.colyseus.io/getting-started/godot), checked 2026-09-18); verify native/web client compatibility before selection |
| Real payments and support evidence | [Razorpay plan](../integrations/payments/RAZORPAY.md) | Selected by Rakesh for purchases and recurring benefits | Verify account capabilities, global coverage and its policy on purchasable credits (RD07, RD11); a second provider or merchant of record may be needed |
| Browser verification | [Playwright](https://playwright.dev/docs/accessibility-testing) | Exercise real navigation, controls, reconnect paths, and basic accessibility checks | Each usable slice |

Keep versions pinned when implementation begins. A tool in this table is a
candidate dependency, not a declaration that it is installed in the website
or on the lab server.

## Alternatives and their tradeoffs

| Option | Useful for | Decision for this project |
| --- | --- | --- |
| [React Three Fiber](https://github.com/pmndrs/react-three-fiber) | A React component model around Three.js | Consider if a substantial React application emerges; it does not inherently make an existing scene faster |
| [Threlte](https://threlte.xyz/) | A Svelte/Three.js authoring model | Similar choice if Svelte is deliberately adopted; no reason to add both |
| [Babylon.js](https://www.babylonjs.com/) | A broader browser engine and tooling ecosystem | Evaluate only if editor/engine needs outweigh migration of the current scene |
| [PlayCanvas](https://developer.playcanvas.com/user-manual/engine/) | Browser-oriented engine and visual authoring workflow | Candidate for an editor-led workflow; compare engine and hosted editor terms separately |
| [Godot web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) | Reuse the native game project for a lighter browser build | Candidate against Three.js; single-threaded by default since 4.3, no WebGPU and no C# web export (checked 2026-09-18); Safari WebGL 2, memory and download size are the risks to measure |
| [Bevy](https://bevy.org/) | Rust ECS and a custom simulation workflow | Alternative if its simulation/tooling benefits justify the authoring effort; see [platform comparison](PLATFORMS.md) |
| [Rapier](https://rapier.rs/docs/) | More demanding collision and physics | Current driving can keep custom physics; add only when an interaction needs it |
| [Tiled](https://www.mapeditor.org/) / [LDtk](https://ldtk.io/) | Authoring map footprints, routes, spawn points, and tags | Optional 2D authoring tools that export data; convert coordinates into the 3D manifest |
| [GSAP](https://gsap.com/pricing/) / [Motion](https://motion.dev/) | UI and camera choreography | Start with CSS and existing interpolation; choose one if complexity grows. GSAP currently offers its library free under its own terms |
| [Spline](https://spline.design/pricing) | Fast interactive visual concepts | Useful for mockups; free web exports carry a watermark and code/self-hosted exports are currently listed under Enterprise |
| [Howler](https://howlerjs.com/) | A larger audio playback abstraction | Existing audio code may be sufficient; preserve explicit mute and user-started playback |
| [Pagefind](https://pagefind.app/) | Search across generated documents | Add once product pages and lab notes justify a search index |
| [Cloudflare Workers/static assets](https://developers.cloudflare.com/workers/static-assets/) | A unified static site and lightweight API deployment | Current Pages hosting can stay initially; migrate only for a concrete need |
| [Durable Objects](https://developers.cloudflare.com/durable-objects/best-practices/websockets/) | Shared room coordination with durable state | Alternative to lab-server room hosting, especially for infrequent edits |
| [R2](https://developers.cloudflare.com/r2/pricing/) / [D1](https://developers.cloudflare.com/d1/) | An expanding asset library / application metadata | Optional storage services; static assets and a simple lab-server save store suffice for the pilot |

Use the same small district and device budgets for any platform comparison.
Keep the site working during an experiment. The client and a compatible server
contract are decided after the vision is clear (RD15), and before any large
gameplay implementation.

## City simulation and voices

For the expanded city, use a headless, deterministic simulation core alongside
the renderer and rooms; a language model should not calculate each traffic or
treasury tick. AgentPod is the preferred source of approved agent state and
interactions (RD02), not a replacement city engine. It does not expose a
public work-state feed today; see the
[known gaps](CITY_SYSTEMS.md#known-integration-gaps-verified-2026-09-18). See its version/API findings in
[People and agents](../gameplay/AGENT_CITY.md).

Avatar parts can use the existing Blender/Blockbench workflow and a shared
rig. Resident character voices can trial [Piper](https://github.com/OHF-Voice/piper1-gpl)
on the lab server, subject to engine and voice licenses and CPU benchmarks. Browser
read-aloud is a separate device-specific fallback. Optional human voice rooms
could use [LiveKit](https://docs.livekit.io/transport/self-hosting/); transport,
TURN and operating cost are separate from synthetic speech.

## Free and inexpensive assets

Use the existing kit as the visual baseline. [Quaternius](https://quaternius.com/)
offers additional model packs; inspect the specific pack's license and art
fit. [Poly Haven's assets are CC0](https://polyhaven.com/license), useful for
selected materials or lighting references, but high-resolution realism is
usually a poor default for this low-poly world. Its website/services have
separate terms from the assets.

Store provenance with every imported asset. “Free to download”, permissively
licensed code, licensed model weights, and permission to distribute the output
are different questions. Preserve existing car/audio attribution; the current
village already includes CC-BY material alongside other assets.

| Workflow | Cost and hardware reality | Best role here |
| --- | --- | --- |
| Existing CC0 kit + authored Blender/Blockbench model | No generation API fee; manual design/cleanup time | Default for houses, roads, trees, modular pieces |
| [TRELLIS.2 hosted demo](https://huggingface.co/spaces/microsoft/TRELLIS.2) | Free shared GPU access subject to queue/quota and availability | Trial a distinctive landmark, then simplify heavily |
| [TRELLIS.2 locally](https://github.com/microsoft/TRELLIS.2) | Official setup requires Linux and an NVIDIA GPU with at least 24 GB memory; code/model MIT, dependencies have their own licenses | Not a fit for the CPU-only lab server or the M1 laptop |
| [TripoSR](https://github.com/VAST-AI-Research/TripoSR) | MIT code/weights; older reconstruction model; compute and setup still required | Cheap coarse geometry experiment if output quality is sufficient |
| [Stable Fast 3D](https://github.com/Stability-AI/stable-fast-3d) | Textured mesh workflow; experimental MPS support, with CPU recommended below 32 GB unified memory in its instructions | Hosted trial is preferable to assuming good performance on the 16 GB M1 |
| [Apple Object Capture](https://developer.apple.com/videos/play/wwdc2021/10076/) | Multiple overlapping photographs, a supported Mac, and reconstruction setup; no per-generation API charge | Scan a real physical object, then convert/clean/export for the web |
| [Camera-to-Blender](https://github.com/ahujasid/camera-to-blender) | MIT orchestration code; its Tripo backend is a separate paid API, with optional Gemini image preprocessing | Convenient phone capture and Blender import, if the generation backend earns its cost |

The [Stable Fast 3D license](https://github.com/Stability-AI/stable-fast-3d/blob/main/LICENSE.md)
has conditional commercial terms, including registration and the stated
revenue threshold; it is not an unrestricted MIT alternative. Check those
conditions for the actual intended use. Hosted demo quotas can change;
[Hugging Face documents ZeroGPU allocation](https://huggingface.co/docs/hub/spaces-zerogpu).
Do not make a public website feature depend on free demo availability.

The inspected camera-to-Blender pipeline imports a generated model into
Blender. Its higher-detail generation step does not impose the same explicit
face limit as its preview step. Its output is not automatically ready for the
village. A future adapter could replace the paid generation backend, but that
would be additional implementation, not an existing feature of the repo.

## A reproducible asset pipeline

```text
brief / silhouette / palette
    → choose kit, author, photograph, or generate
    → retain raw source and provenance
    → Blender/Blockbench cleanup and scale/pivot setup
    → simplify, repair topology, reduce materials, make collider and LODs
    → export GLB
    → glTF validation + budget report
    → glTF Transform cleanup / texture processing / Meshopt
    → daylight, night, mobile-tier visual check in the real loader
    → approved content-hashed asset + manifest entry
```

Use one agreed world-unit convention, ground-level pivots, standard entrances,
and known bounding boxes. Prefer single-material primitives or explicitly
support multi-material meshes: the current instancing path selects the first
material from a material array. The loader also makes materials matte, so a
generated PBR model can look different from its generation preview.

Compression reduces transferred bytes; it does not remove the need to reduce
triangles, draw calls, large textures, or overdraw. Keep the raw file, a working
source, and a reproducible output recipe. The lab server can execute the CPU stages
as a single bounded job, but its tools must first be packaged and benchmarked.

## First asset bake-off

Choose one recognisable jackfruit landmark and one modular workshop. Produce
small trials using (a) kit plus manual modelling, (b) a hosted free generator,
and (c) capture of a physical object if one is available. Record:

- Active creation/cleanup minutes and any API spend.
- Style consistency and silhouette at the actual camera distance.
- Triangles, materials, texture dimensions, transferred bytes, and draw calls.
- Import problems, collision setup, and licence/attribution requirements.
- Device performance and whether the asset improves recognition or delight.

No generation or comparative benchmark was run during this documentation
pass. Choose the workflow from total delivered cost and quality, not the time
shown in an AI generation demo.
