# MCP and CLI evidence catalogue

Research snapshot · 2026-09-16 · updated 2026-09-18 ·
[Tool strategy](../architecture/TOOLS.md) ·
[Adoption requirement](../architecture/AGENT_TOOLING.md)

**Reading note, 2026-09-18 (RD15).** Every "leading", "first" or "candidate"
below is a research ranking. No tool, engine, room server, database or host
is chosen, and the evaluation continues; see the
[evaluation stance](../architecture/PLATFORMS.md#evaluation-stance). Forgejo's
presence on the lab server is decided (RD13); its tooling is not.

Rakesh requires MCP and CLI access for tools considered for an agent-built and
agent-operated city. This catalogue covers the discussed products and the
earlier alternatives retained in the toolbox. It records what was found in
primary documentation, maintainer repositories and selected local SJL source.
It is a shortlist and gap analysis, not an installed-tool manifest.

**No external package was installed, MCP connection exercised, paid API called
or server deployment inspected during this pass.** A documented interface is
evidence of a candidate, not proof that the required workflow works on our
machines. “Not verified” means the bounded research did not establish a
suitable path; it does not prove that no implementation exists anywhere.

**Later September 16 update:** Kaambaan was renamed **Superpipeline**.
The product row below uses current naming and the separately inspected
[SP02/SP04 source evidence](SJL_PRODUCT_REFRESH_2026-09-16.md), including the
subsequent CLI rename to `supi` and `superpipeline`. Historical
S01/S02 references retain their original revisions and names. The rename does
not resolve interface gaps or make the CLI an agent execution client.

**2026-09-18 update — two Superpipeline findings, one of them a correction.**
Unlike the pass above, these come from running the tools on a workstation rather
than from reading source, and they change the Superpipeline row.

- **The CLI is no longer repository-local.** `packages/cli/install.sh` links
  `supi` and `superpipeline` onto a PATH from a checkout
  ([superpipeline#77](https://github.com/SuperJackfruitLabs/superpipeline/pull/77)).
  It is still not a published artifact — every package in that repository is
  `private: true` — so "install from a checkout" is the whole of what changed.
- **"Member authority" is a default, not a property of the CLI.** This catalogue
  read the member role as a ceiling the CLI imposes. It is the fallback in
  `apps/api/src/auth/resolve.ts`, which resolves
  `role: local ?? 'member'` — a hub token carries whatever role a membership row
  names for its principal, and only falls back to `member` when no row does.
  **The distinction matters for adoption:** the constraint this catalogue relied
  on is a default rather than a guardrail, so "without widening roles" is a thing
  to enforce deliberately rather than something the credential does for us. A
  single membership row changes what the same token may do.

  **Correction, 2026-09-20.** The paragraph above was right about the code and
  wrong about the world, and the gap between those was the whole point of the
  entry. `resolve.ts` did resolve `role: local ?? 'member'` — but on 2026-09-18
  **no code path could write a membership row keyed on a hub principal.** There
  was no mapping from an issuer subject to a local user, so `local` was always
  null, so every hub token was `member` and nothing could make it anything else.
  "A single membership row changes what the same token may do" described a lever
  that did not exist. The advice to *enforce* the constraint deliberately was
  therefore advice to enforce something already true by accident, and it read as
  a warning about a risk rather than a report of a missing feature.

  **It is true now, by a mechanism invented two days after this was written.**
  superpipeline's `apps/api/src/auth/hub-oauth.ts` maps an issuer subject onto a local
  user — on a verified email, once, with guards — and `resolve.ts` then reads that
  user's real membership. Confirmed against production on 2026-09-20: a mapped
  principal resolved `owner` and created boards from the CLI, where the same
  token had been refused with 403 the day before.

  So the correction is not "the claim was false". It is that the claim was
  **unreachable when made**, and the reason it is reachable today is a feature
  nobody had built yet. What a catalogue like this should record is which of its
  statements are about code it read and which are about behaviour it observed —
  this one was the first, presented as the second.

A third fact moved in the same window and affects the MCP side of that row:
Superpipeline agent tokens have started `spa_` rather than `kbn_` since
2026-09-17, with no fallback, and AgentPod's bridge requires the new prefix.
Any agent identity configured from the earlier evidence needs re-minting.

## How to read the tables

- **Official:** the product owner documents or publishes the interface.
- **Community:** a third-party maintainer supplies it; evaluate source, releases,
  licence, compatibility and actual access controls before use.
- **Docs:** MCP supplies documentation/context, not product operations.
- **Gap:** a required interface or part of the workflow is not established.
- **Proposed adapter:** SJL would have to build and maintain it. It does not
  count as satisfying the prerequisite today.

“Both found” below means useful CLI and operational MCP candidates were located,
not feature parity or an adoption approval. A server's `npx`, Python or Docker
startup command is not automatically a CLI for its underlying product.
Frameworks and assets share a workflow only where the table says so; they do
not inherit a blanket pass from a generic shell or browser tool.

## Projects, source, agents and knowledge

| Product / purpose | CLI evidence | MCP evidence | Assessment and next verification |
| --- | --- | --- | --- |
| **Superpipeline** — work management | `supi` or `superpipeline` with `--json`, installed from a checkout by `packages/cli/install.sh`; private `@superpipeline/cli`, no published artifact [SP04](SJL_PRODUCT_REFRESH_2026-09-16.md), 2026-09-18 update | Product `/mcp`; eleven `superpipeline_*` agent work tools [SP02](SJL_PRODUCT_REFRESH_2026-09-16.md); agent tokens now `spa_` | **Both found, different roles and an approval-loop gap.** The CLI resolves as `member` by *default*, not by design — a membership row names the role, so roles widen by configuration rather than by credential. **(2026-09-20: that lever was unreachable when written — nothing could key a membership on a hub principal until superpipeline added subject→user mapping. See the correction above.)** MCP uses an agent identity. MCP cannot read a run/elicitation answer; the documented REST alternative is not full MCP coverage. Extend the workflow without widening roles, and treat "member" as a thing to enforce rather than to rely on. |
| **AgentPod** — execution/workspaces | `apn` node and fleet command families [S03]; executable found on this machine's PATH. 2026-09-18: `apn fleet` shipped in v0.1.33 (2026-09-17, latest tag); a spec and feature branch of 2026-09-18 move fleet verbs to a separate `agentpod-fleet` binary, not merged or released | Product `/mcp`: self station, sessions and transcript [S04] | **Both found, limited MCP.** The three MCP tools are read-only and self-scoped; no MCP fleet enumeration/administration. Dispatch and broader city projections require separately verified contracts. No live endpoint tested. |
| **Forgejo** — code collaboration; decided to run on the lab server (RD13) | Git; community [`fj`](https://cli.fjord.sh/cli); official [admin CLI](https://forgejo.org/docs/latest/admin/command-line/) has a different purpose | Community [`goern/forgejo-mcp`](https://github.com/goern/forgejo-mcp/blob/main/README.md), also documents direct `--cli` invocation. 2026-09-18: a reviewer's spot-check confirmed development moved to <https://git.b4mad.industries/agentic-forges/forgejo-mcp>; this pass met a bot-protection page there, so releases and licence are still unread | **Both found; upstream to evaluate is the moved forge.** Review/pin before adoption. Use the [ownership proposal](../integrations/development/FORGEJO_SUPERPIPELINE.md). |
| **GitHub** — existing/external projects | Official [`gh`](https://cli.github.com/manual/) plus Git | Official [`github/github-mcp-server`](https://github.com/github/github-mcp-server) | **Both found.** Verify chosen toolsets, organisation policy, token scopes and PR/Actions coverage. Existing repositories can retain their authoritative home. |
| **Supermessage** — human/agent conversation client | `pnpm`/Cargo build and test scripts; no task-oriented messaging CLI verified [S05] | Opt-in Tauri development MCP bridge; debug-only in inspected source [S05] | **Operational gap.** A developer UI bridge is not a production messaging/gate service. Use separate Matrix/product APIs for service integration; verify custom event and approval behaviour. |
| **Matrix** — messaging protocol/service | Community [`matrix-commander`](https://github.com/8go/matrix-commander) | Community [`matrix-mcp-server`](https://github.com/mjknowles/matrix-mcp-server) | **Both candidates found for ordinary messaging.** Verify homeserver compatibility, encryption/device requirements, room membership and custom SJL events. Sending a chat message is not authorising a Superpipeline gate. |
| **SuperMD** — native Markdown authoring | File/folder launch argument and Cargo workflow [S06]; no headless editing/publishing CLI verified | No product MCP found in inspected source; ordinary file access is a separate interface | **Gap for product automation.** Agents can author Markdown through scoped workspace tools; SuperMD remains a human editor. A library publication CLI/MCP must be designed separately. |
| **SJL's internal agreement, operations, marketing and concept repositories** | Git and repository-specific scripts; eventual operations use the selected infrastructure tools | Selected forge MCP for repository material; no standalone product server assumed | **Content/workflow sources.** These repositories are agreements, runbooks, evidence or concepts, not city services. Only authorised material enters an agent's workspace or a public exhibit. |

### Local SJL source evidence

This pass read local checkouts rather than fetching their remotes. Revisions
below identify inspected source, not the version installed on any server.
SuperMD had unrelated working-tree changes; this pass read its committed
README, manifest and entry-point surfaces and did not touch those changes.

- **S01:** Kaambaan at `35af1fdc59d82426fbf663aaa4d1ffabc0f1883e`:
  [CLI README](https://github.com/SuperJackfruitLabs/kaambaan/blob/35af1fdc59d82426fbf663aaa4d1ffabc0f1883e/packages/cli/README.md),
  [CLI entry point](https://github.com/SuperJackfruitLabs/kaambaan/blob/35af1fdc59d82426fbf663aaa4d1ffabc0f1883e/packages/cli/src/index.ts),
  [private package manifest](https://github.com/SuperJackfruitLabs/kaambaan/blob/35af1fdc59d82426fbf663aaa4d1ffabc0f1883e/packages/cli/package.json).
  `kbn` was not found on this machine's PATH. Do not describe it as a public
  npm package or claim that CLI gate listing can approve a gate.
- **S02:** Same Kaambaan revision:
  [MCP docs](https://github.com/SuperJackfruitLabs/kaambaan/blob/35af1fdc59d82426fbf663aaa4d1ffabc0f1883e/docs-site/src/content/docs/build/mcp.md),
  [tool registration](https://github.com/SuperJackfruitLabs/kaambaan/blob/35af1fdc59d82426fbf663aaa4d1ffabc0f1883e/apps/api/src/mcp/tools.ts).
  The agent tools cover work discovery, claim/read/reference, heartbeat,
  activity, submit-for-review, completion, block/fail/release. A proposal must
  not treat the member CLI credential as a `kbn_` agent token or vice versa.
  (Correction, 2026-09-18: the agent-token prefix is now `spa_`; `kbn_` is
  the historical name at this revision and is no longer accepted.)
- **S03:** AgentPod at `ed10da546e15c85950e33c95271ca461efeea192`:
  [CLI docs](https://github.com/SuperJackfruitLabs/agentpod/blob/ed10da546e15c85950e33c95271ca461efeea192/docs-site/src/content/docs/use/cli.md).
  Node credentials and principal/fleet credentials have separate authority.
- **S04:** Same AgentPod revision:
  [MCP docs](https://github.com/SuperJackfruitLabs/agentpod/blob/ed10da546e15c85950e33c95271ca461efeea192/docs-site/src/content/docs/build/mcp.md),
  [tool registration](https://github.com/SuperJackfruitLabs/agentpod/blob/ed10da546e15c85950e33c95271ca461efeea192/apps/hub/src/mcp/tools.ts).
- **S05:** Supermessage at `59abd49ddb9e4c14afc33dedf04519c6eacfba9d`:
  [package scripts](https://github.com/SuperJackfruitLabs/supermessage/blob/59abd49ddb9e4c14afc33dedf04519c6eacfba9d/package.json),
  [conditional bridge registration](https://github.com/SuperJackfruitLabs/supermessage/blob/59abd49ddb9e4c14afc33dedf04519c6eacfba9d/src-tauri/src/lib.rs),
  [optional feature](https://github.com/SuperJackfruitLabs/supermessage/blob/59abd49ddb9e4c14afc33dedf04519c6eacfba9d/src-tauri/Cargo.toml).
- **S06:** SuperMD at `e4009d346595b76ea38dfe2a81b9a836e84db061`:
  [README](https://github.com/SuperJackfruitLabs/supermd/blob/e4009d346595b76ea38dfe2a81b9a836e84db061/README.md),
  [entry point](https://github.com/SuperJackfruitLabs/supermd/blob/e4009d346595b76ea38dfe2a81b9a836e84db061/src/main.rs).

## Website, engines and runtime libraries

| Product / purpose | CLI evidence | MCP evidence | Assessment and next verification |
| --- | --- | --- | --- |
| **Godot** — web/native candidate (not chosen, RD15) | Official [`godot` CLI](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html): headless/script/import/export paths. 2026-09-18 web spot-check: web export is single-threaded by default since 4.3; no WebGPU; no C# web export ([docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)) | Community [`Coding-Solo/godot-mcp`](https://github.com/Coding-Solo/godot-mcp); additional community implementations exist | **Both found.** Evaluate a specific engine/server pair for scene work, debug evidence and exports. Editor/runtime inspection can need a running process; headless success does not prove visual correctness. |
| **Bevy** — Rust alternative | Cargo build/test/run; application-owned headless scenario runner would be additional work | Community [`natepiano/bevy_brp`](https://github.com/natepiano/bevy_brp), with MCP in its workspace | **Both paths identified, custom integration.** Requires application instrumentation/BRP compatibility. The older standalone `bevy_brp_mcp` repository is archived; evaluate the current workspace. |
| **Astro** — website/content | Official [`astro` CLI](https://docs.astro.build/en/reference/cli-reference/) | Official [Astro Docs MCP](https://mcp.docs.astro.build/) is **Docs**; Playwright MCP can inspect the resulting website | **Operational authoring gap.** Source editing/building uses the project workflow; any shared build MCP needs a defined, tested contract. Keep the existing site during engine evaluation. |
| **Three.js** — existing browser village | Project's Node/package-manager build and test recipes; no standalone game-authoring CLI implied | Community [`threejs-devtools-mcp`](https://github.com/DmitriyGolub/threejs-devtools-mcp) for a running browser scene | **Component workflow.** Browser bridge needed; verify asset/scene inspection and persistence of edits. Keep development bridges out of public builds. |
| **React Three Fiber** — optional React scene authoring | Project build/test CLI; source is React code | Community [`r3f-mcp`](https://github.com/r3f-mcp/r3f-mcp), or the Three.js bridge above | **Component alternative.** Requires runtime integration; adopting React just for MCP is not justified. Test scene inspection and source persistence. |
| **Threlte** — optional Svelte scene authoring | Project build/test CLI; source is Svelte/TypeScript | No Threlte-specific operational server verified; evaluate the Three.js bridge against its scene | **MCP compatibility gap.** A shared underlying renderer does not prove bridge compatibility. |
| **Babylon.js** — browser engine alternative | Editor repository contains [`babylonjs-editor-cli`](https://github.com/BabylonJS/Editor/blob/master/CLAUDE.md) for project assets/builds | Official [authoring MCP documentation](https://github.com/BabylonJS/Documentation/blob/master/content/toolsAndResources/mcpServers.md); editor-specific MCP also described in the editor repo | **Both found for named editor workflows.** Graph authoring tools and whole-scene editing are distinct; evaluate the required suite and its desktop/browser dependencies. |
| **PlayCanvas** — browser engine/editor alternative | Official [`create-playcanvas`](https://github.com/playcanvas/create-playcanvas) scaffolder and generated project build recipes | Official [`editor-mcp-server`](https://github.com/playcanvas/editor-mcp-server) | **Partial coverage.** Editor MCP requires the editor connection; a scaffolding CLI does not establish CLI parity for hosted editor management/export. Verify that boundary before selection. |
| **Rapier** — optional physics | Rust/JS library in the project's tests and scenario CLI | [`IBM/chuk-mcp-physics`](https://github.com/IBM/chuk-mcp-physics) wraps a Rapier service; not a native Rapier city integration | **Component/experimental.** Its separate physics service does not control our game automatically. Prefer deterministic application tests and specify any required bridge. |
| **GSAP** — optional choreography | Project build/test recipes; JS library | Community [`glorynguyen/gsap-mcp`](https://github.com/glorynguyen/gsap-mcp) describes a knowledge/context surface | **Context candidate, operational gap.** Verify actual tools; do not treat generated examples as live timeline control. Choose at most the animation tooling actually needed. |
| **Motion** — optional animation | Project build/test recipes; `motion-ai` installs tooling rather than serving as a general animation CLI | Official [Motion AI Kit](https://motion.dev/docs/ai-kit-install): free docs/context; additional tools depend on Motion+ | **Partial.** Separate docs, paid tools and reproducible project builds; no paid account or workflow verified. |
| **Howler** — optional audio playback | JS library exercised through the application's CLI tests/builds | No product-specific operational MCP verified | **Component gap.** Define application audio test/inspection operations if selected; similarly named agent products are unrelated to Howler.js. |
| **Pagefind** — searchable published knowledge | Official [indexing CLI](https://pagefind.app/docs/) | Community [`tkellogg/pagefind-mcp`](https://github.com/tkellogg/pagefind-mcp) searches indexed sites | **Both paths found for different jobs.** CLI builds indexes, MCP retrieves published knowledge. Publishing/reindexing over MCP needs the build/publishing adapter. Keep private material out of public indexes. |

## Design, models, maps, audio and narrative

| Product / purpose | CLI evidence | MCP evidence | Assessment and next verification |
| --- | --- | --- | --- |
| **Penpot** — UI, design tokens, maps | No complete task-oriented design CLI verified; `npx @penpot/mcp` starts a server | Official [Penpot MCP](https://help.penpot.dev/mcp/) reads/edits design data | **CLI gap.** Current documented flow connects a design file/plugin and active page. A supported CLI client/adapter and unattended workflow need evaluation. |
| **Blender** — modelling, rigging, cleanup | Official [background Python execution](https://developer.blender.org/docs/handbook/building_blender/python_module/) | Community [`ahujasid/blender-mcp`](https://github.com/ahujasid/blender-mcp) plus an in-app addon | **Both found; separate modes.** Use batch scripts for repeatable bakes. The interactive MCP addon is not automatically a headless service; [timer issue](https://github.com/ahujasid/blender-mcp/issues/251) documents that limitation. |
| **Blockbench** — low-poly props | No general headless author/export CLI verified | Community [`blockbench-mcp-plugin`](https://github.com/jasonjgardner/blockbench-mcp-plugin), desktop plugin | **CLI/headless gap.** Evaluate desktop operation and export reproducibility; prefer Blender batch processing where the gap would block the asset pipeline. |
| **Krita** — textures, illustration | Official [export/launch CLI](https://docs.krita.org/en/reference_manual/linux_command_line.html); community [`krita-cli`](https://github.com/edithatogo/krita-cli) for deeper actions | The same community package exposes MCP through a Krita plugin | **Both candidates found, app dependency.** CLI export is narrower than painting automation; validate OS support, plugin availability, visual read-back and exact versions. |
| **Audacity** — sound editing | Official [script-pipe interface](https://manual.audacityteam.org/man/scripting.html) can be driven by scripts; no complete headless editing CLI verified | Community [`tachyonshuggy/audacity-mcp`](https://github.com/tachyonshuggy/audacity-mcp) targets Audacity 3.x with `mod-script-pipe` | **Partial, version-sensitive.** Running Audacity and scripting support are prerequisites. Do not assume this works in another major version; a task CLI/recipe wrapper remains work. |
| **Ink / inklecate** — branching dialogue and lessons | Official [`inklecate`](https://github.com/inkle/ink) compiler/play workflow | No suitable operational MCP verified in this pass | **MCP gap.** Proposed narrative tools would wrap compile, validate and scenario traversal, preserving authorable `.ink` sources. |
| **Tiled** — district footprints, routes, tags | Official [CLI map/tileset export](https://doc.mapeditor.org/en/stable/manual/export/) | Community [`rpgjs/tiled-ai`](https://github.com/rpgjs/tiled-ai/blob/main/docs/advanced.md) with editor extension | **Both found.** Check desktop bridge and scripted exports; translate 2D coordinates into the city's agreed world manifest. |
| **LDtk** — alternative map authoring | Documented [JSON data](https://ldtk.io/docs/); complete headless author/export CLI not verified | No suitable product editor MCP verified; a Godot importer is not an LDtk editor server | **Both workflow gaps remain.** Keep as an alternative, not the default automated path, unless scoped data tooling closes them. |
| **glTF Transform** — asset processing | Official [`gltf-transform` CLI](https://gltf-transform.dev/cli) | Community [`GeoLibra/3d-asset-processing-mcp`](https://github.com/GeoLibra/3d-asset-processing-mcp) advertises glTF Transform operations | **Both candidates found.** Verify the specific transforms and output reports; wrapper validation claims do not prove full Khronos validation. |
| **Meshoptimizer / gltfpack** — geometry compression | Official [`gltfpack`](https://github.com/zeux/meshoptimizer/blob/master/gltf/README.md) | Meshopt support through the glTF processing MCP candidate; direct `gltfpack` MCP not verified | **Partial.** Library compression and exact CLI recipe parity differ. A scoped asset adapter can own the pinned recipe if needed. |
| **Khronos glTF Validator** — asset validation | Official [`gltf_validator`](https://github.com/KhronosGroup/glTF-Validator/blob/main/README.md), JSON reports and error exit status | No independently verified dedicated integration selected; proposed asset MCP operation should call the actual validator | **MCP gap.** Generic “validate model” tools are insufficient evidence of Khronos validation. Retain validation reports beside outputs. |
| **Kenney assets** — coherent base kit | No vendor CLI established; proposed manifest-driven import/download recipe | Community [`ASSETMCP`](https://github.com/evonar543/ASSETMCP) lists Kenney discovery/import | **CLI workflow gap.** Catalogue is an asset source, not an installed game tool; retain pack version, source URL, licence and checksums. |
| **Quaternius assets** — additional modular models | Same proposed import recipe; no vendor CLI established | Community [`ASSETMCP`](https://github.com/evonar543/ASSETMCP) lists Quaternius | **CLI workflow gap.** Verify each pack's actual licence and style; a search result is not blanket permission to redistribute. |
| **Poly Haven assets** — materials and lighting | API-backed import recipe possible; no complete vendor CLI verified | Community [`RN0000/polyhaven-mcp`](https://github.com/RN0000/polyhaven-mcp/blob/master/README.md); Blender MCP also offers related integration | **Partial.** Verify API/service terms, attribution records and download budgets separately from asset licences. |
| **Spline** — interactive concepts | No general unattended scene/export CLI verified | Official [Spline MCP](https://docs.spline.design/generate/spline-mcp-server), requires desktop app | **CLI gap.** Keep optional for concepts; verify export entitlements and recurring cost. MCP does not establish an unattended build pipeline. |

Plain HTML/SVG and code-generated diagrams remain possible design artefacts.
Their agent workflow is source editing, deterministic rendering, browser/image
inspection and checked-in files. A human-facing design editor is useful, but
cannot be the sole owner of otherwise inaccessible product specifications.

## Capture and generative 3D experiments

These are optional asset inputs, not dependencies for residents to enter or
play. Preserve the free/manual modular-kit path and the full
[cleanup/validation pipeline](../architecture/TOOLS.md#a-reproducible-asset-pipeline).

| Product / purpose | CLI or programmable path | MCP evidence | Assessment and next verification |
| --- | --- | --- | --- |
| **Tripo** — hosted generation | API-backed job CLI would need selection/verification | Official [`VAST-AI-Research/tripo-mcp`](https://github.com/VAST-AI-Research/tripo-mcp) | **CLI/cost gap.** Paid-backend candidate; MCP availability does not make generation free. Verify allowed operations, job status, cancellation and delivered asset cost. |
| **Camera-to-Blender** — phone capture/import | [`uvicorn` relay startup](https://github.com/ahujasid/camera-to-blender); that is server startup, not a full capture/generate CLI | No MCP documented in the inspected repository; Blender MCP is a separate project | **Both workflow gaps.** Phone capture and Tripo backend remain dependencies. Optional image preprocessing is separate. An automated adapter is future work. |
| **TripoSR** — local reconstruction | Upstream [Python inference workflow](https://github.com/VAST-AI-Research/TripoSR) | No directly suitable MCP verified; proposed job wrapper | **MCP gap.** Keep as a coarse-geometry experiment; verify hardware, model/output licences and cleanup cost. |
| **TRELLIS.2** — higher-detail generation | Upstream [Python inference](https://github.com/microsoft/TRELLIS.2); a city job CLI is additional work | Community [`FishWoWater/trellis_blender`](https://github.com/FishWoWater/trellis_blender/blob/master/README.md) documents TRELLIS/TRELLIS.2 and an MCP integration | **Experimental.** Verify the exact MCP path/backend pair. Existing hardware inspection did not establish suitable NVIDIA GPU capacity; hosted demos are not a service guarantee. |
| **Stable Fast 3D** — reconstruction | Upstream [local inference workflow](https://github.com/Stability-AI/stable-fast-3d) | Community [`rikturnbull/mcp-stable-fast-3d`](https://github.com/rikturnbull/mcp-stable-fast-3d) calls the hosted Stability API | **Different backends.** This MCP is not evidence of local inference control or free generation. Evaluate licences, hardware and an owned local job adapter separately. |
| **Apple Object Capture** — photogrammetry | Official [sample command-line app](https://developer.apple.com/documentation/RealityKit/creating-a-photogrammetry-command-line-app) | No suitable dedicated MCP verified; proposed job wrapper | **MCP gap and platform dependency.** Needs supported Apple hardware/OS, overlapping photographs and conversion into the chosen asset pipeline. |

## Multiplayer, persistence, voice and payments

| Product / purpose | CLI evidence | MCP evidence | Assessment and next verification |
| --- | --- | --- | --- |
| **Colyseus** — authoritative rooms | Official [project scaffolding/start commands](https://docs.colyseus.io/getting-started), including non-interactive flags | No suitable operational product MCP verified | **MCP/operations gap.** Proposed room inspection, test and lifecycle adapter; scaffold generation is not live room management. Verify browser/native clients before selection; an official Godot SDK now exists as a beta GDExtension for desktop, mobile and web ([docs](https://docs.colyseus.io/getting-started/godot), checked 2026-09-18). |
| **Nakama** — multiplayer backend alternative | Server executable/configuration and application scripts; a full client/admin task CLI not established | Community [`mlger/nakama-mcp`](https://github.com/mlger/nakama-mcp) wraps client and console APIs | **CLI and scope gap.** Player APIs and console administration require different grants. Compare with Colyseus/headless Godot; do not deploy all by default. |
| **PostgreSQL** — durable city state/ledger | Official [`psql`](https://www.postgresql.org/docs/current/app-psql.html), backup utilities and versioned migration recipes | Community [`crystaldba/postgres-mcp`](https://github.com/crystaldba/postgres-mcp) | **Both found for database work.** Restricted diagnostic access first; raw SQL access never substitutes for city payment, wallet, booking or membership operations. |
| **Redis** — optional cache/queues | `redis-cli`; optional official [`redisctl`](https://github.com/redis/redisctl) has a separate management scope | Official [`redis/mcp-redis`](https://github.com/redis/mcp-redis) | **Both found.** Decide whether needed at all. Authoritative balances stay durable; sandbox data and credentials differ from production. |
| **Piper** — local resident character speech | Official [Piper CLI](https://github.com/OHF-Voice/piper1-gpl) | Community [`Alma-media/piper-api`](https://github.com/Alma-media/piper-api) documents an MCP service | **Both candidates found.** Verify compatibility with current Piper, voice licences, latency and quotas. Pre-generate/cache common lines; no assumption of unlimited live speech. |
| **whisper.cpp** — optional speech recognition | Official [`whisper-cli`/server](https://github.com/ggml-org/whisper.cpp) | Community [`nizovtsevnv/whisper-mcp-server`](https://github.com/nizovtsevnv/whisper-mcp-server) | **Both candidates found.** Optional input feature; verify models, supported audio formats, CPU latency and recording retention. Text remains a first-class interface. |
| **LiveKit** — optional human/agent live voice | Official [`lk`](https://github.com/livekit/livekit-cli) covers service/testing operations | Official [Docs MCP](https://docs.livekit.io/reference/developer-tools/docs-mcp/) is **Docs**; Agents can also act as MCP clients | **Operational MCP gap.** Documentation and consuming other servers do not expose room administration. Specify a scoped adapter if room actions must be agent-operated. |
| **Razorpay** — selected real payments | Official [`razorpay` CLI](https://github.com/razorpay/razorpay-cli), including orders and payment inspection | Official [`razorpay-mcp-server`](https://github.com/razorpay/razorpay-mcp-server), with toolset/read-only controls | **Both found; account/workflows untested.** Start evaluation in test mode. Provider tools do not replace the city's verified receipt, grant, reconciliation and audit logic. |

## Hosting, operations, delivery and verification

| Product / purpose | CLI evidence | MCP evidence | Assessment and next verification |
| --- | --- | --- | --- |
| **Docker / Compose** — service packaging | `docker` and `docker compose` | Official [MCP Gateway/Toolkit](https://docs.docker.com/ai/mcp-catalog-and-toolkit/mcp-gateway/) manages MCP servers; it is not proof of a scoped Docker service-management MCP | **Operational bridge gap.** Gateway adoption is optional; define restricted job/service operations. Never give resident jobs the host Docker socket. |
| **Ansible** — repeatable infrastructure | `ansible-playbook`, inventory/lint/test recipes | Official [Ansible Development Tools MCP](https://docs.ansible.com/projects/vscode-ansible/mcp/); separate [AAP MCP](https://github.com/ansible/aap-mcp-server) targets Automation Platform | **Both candidates found, different products/scopes.** Evaluate open development tools for infrastructure workflows; do not assume AAP is deployed or required. |
| **Caddy** — ingress/TLS | Official [Caddy CLI](https://caddyserver.com/docs/command-line) for configuration/validation/runtime commands | Community [`YawLabs/caddy-mcp`](https://github.com/YawLabs/caddy-mcp) wraps the admin API | **Both found.** Review/pin the bridge and scope allowed changes. Keep reviewed configuration and live state reconcilable; admin access is privileged. |
| **Grafana** — dashboards and operations | Official [`gcx`](https://github.com/grafana/gcx); predecessor `grafanactl` is deprecated | Official [`grafana/mcp-grafana`](https://github.com/grafana/mcp-grafana) | **Both found.** Verify OSS/version compatibility and which commands require cloud features; read-only investigation precedes mutation. |
| **Prometheus** — metrics | `promtool` and HTTP query API | Selected Grafana MCP can query a configured Prometheus data source | **Shared read path.** Collector/configuration operations need the reviewed ops workflow; query access does not prove lifecycle management. |
| **Loki** — logs | `logcli` and service/configuration workflow | Selected Grafana MCP can query a configured Loki data source | **Shared read path.** Redact secrets and restrict tenant/time scope; deployment/retention operations remain separate. |
| **OpenTelemetry** — instrumentation | Collector executable/configuration and application build/test recipes | No operational collector MCP selected; downstream observability tools consume telemetry | **Component gap.** Instrumentation/export is not an MCP product-control surface. A scoped diagnostic/configuration adapter would be additional work. |
| **pgBackRest** — PostgreSQL recovery | Official [command reference](https://pgbackrest.org/command.html), including backup, check, info and restore | No suitable dedicated MCP verified | **MCP gap.** Proposed recovery adapter should expose inspection and isolated restore exercises before privileged production recovery. |
| **Restic** — file/asset/off-host backups | Official [Restic CLI](https://restic.readthedocs.io/en/stable/) | Community [`restic-defensive-mcp`](https://github.com/ThomasCrouzet/restic-defensive-mcp) provides read-only inspection | **Partial by design.** Snapshot inspection does not perform backup/restore. Use a separately authorised recovery workflow; no promise of protection until restore tests succeed. |
| **gVisor** — candidate execution isolation | Official [`runsc`/Docker integration](https://gvisor.dev/docs/user_guide/quick_start/docker/) | No native gVisor administration MCP selected; community sandbox products exist but are not an AgentPod integration | **Runtime component.** Proposed bounded execution adapter; verify host/workload compatibility. Isolation is not guaranteed by the mere presence of a runtime. |
| **GitHub Actions** — existing CI | `gh run`, `gh workflow` and Git/repository workflows | GitHub MCP toolsets include Actions-related access | **Both found.** Confirm dispatch/log/artefact coverage and permissions in the selected version; isolate untrusted jobs. |
| **Forgejo Actions** — candidate CI | Runner executable; `fj` documents run/log operations | Community Forgejo MCP candidate documents workflow access | **Partial until tested.** Runner administration, workflow dispatch and log retrieval are separate operations; GitHub workflow compatibility needs review. |
| **Cloudflare Workers / Pages** — site/light services | Official [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/commands/) | Official [Cloudflare API MCP](https://github.com/cloudflare/mcp/blob/main/README.md) | **Both found at platform level.** Verify exact deployment/rollback scopes; adopting Cloudflare does not move the authoritative city simulation automatically. |
| **Cloudflare Durable Objects** — alternative room coordination | Wrangler deploy/build plus application-owned inspection/test commands | Cloudflare API MCP covers platform APIs, not arbitrary domain operations inside our objects | **Domain MCP gap.** City room operations still need their own explicit contract. Keep this as an alternative to lab-server room hosting. |
| **Cloudflare R2** — optional object storage | Wrangler R2 and compatible S3 tooling | Cloudflare API MCP includes R2-related management | **Partial.** Bucket management, actual object transfer, access grants and content publication are different capabilities; verify the needed data path. |
| **Cloudflare D1** — optional lightweight metadata | Wrangler D1 commands | Cloudflare API MCP includes D1-related APIs | **Both platform paths found.** Verify query/migration scope; PostgreSQL remains the leading durable city-state candidate, not an automatic duplicate database. |
| **Playwright** — browser verification | Official [Playwright CLI](https://github.com/microsoft/playwright-cli) and test runner | Official [`microsoft/playwright-mcp`](https://github.com/microsoft/playwright-mcp) | **Both found.** Keep durable tests and artefacts. Browser accessibility snapshots alone cannot judge a WebGL scene; include screenshots and application-level checks. |

Prometheus, Loki and OpenTelemetry are complementary observability components,
not three interchangeable dashboard products. Sources for their own command
surfaces: [promtool](https://prometheus.io/docs/prometheus/latest/command-line/promtool/),
[LogCLI](https://grafana.com/docs/loki/latest/query/logcli/),
[OpenTelemetry Collector](https://opentelemetry.io/docs/collector/).

## AI world models and supporting interfaces

The [world-model evidence matrix](WORLD_MODELS.md#cli-and-mcp-admission-checks)
adds Marble, HY-World 2.0, Project Genie, HY-WorldPlay, Cosmos 3, DreamerV3,
Dreamer 4 research, V-JEPA and MultiWorld, plus the supporting `wm-mcp` bridge
and Spark renderer. That matrix owns the versioned interface evidence rather
than duplicating it here. It distinguishes asset generation, video worlds,
learned dynamics and perception.

Marble has official task scripts and a community MCP candidate. V-JEPA has a
narrow community video-analysis CLI/MCP bridge, with version and capability
limits. Most other candidates still need an operational MCP adapter; Genie
has no qualifying task CLI or MCP established in this review. A documented
interface does not resolve model/output licensing, commercial eligibility,
GPU budgets or city acceptance. None is installed or selected by this research.

## What changes in the shortlist

1. **Keep as leading candidates with useful existing automation:** Godot,
   Blender, Superpipeline, AgentPod, Forgejo, GitHub, Razorpay, PostgreSQL, Grafana and
   Playwright. This is a research priority, not a declaration that all pass
   and not a selection (RD15): product scopes, community bridges and actual
   workflows still need evaluation. Superpipeline and AgentPod carry the RD02
   preference for SJL products; Forgejo is decided as present (RD13).
2. **Keep conditional on explicit gaps:** Penpot and Blockbench need a credible
   task CLI path; Supermessage and SuperMD need clearer product-operation or
   publication paths; Colyseus needs room tooling; LiveKit needs operational MCP
   if room management is in scope. Do not substitute a launch command or docs
   server for these missing operations.
3. **Preserve alternatives:** Bevy, Babylon.js, PlayCanvas, Tiled/LDtk, optional
   renderer/UI libraries, local speech and asset generators remain available
   for the later comparison. Their existence does not justify adopting all of them.
4. **Build city-specific interfaces deliberately:** the
   [authoring and operating tools](../architecture/AGENT_TOOLING.md#city-tools-to-design)
   need a shared domain contract with CLI and MCP entry points from the outset.
   These are future implementation obligations, not existing integrations.

## Remaining research and verification

- Validate and pin each selected server's source/release; inspect permissions,
  dependency licences and supply chain. “Official” describes provenance, not
  suitability for every role or environment.
- Exercise one representative end-to-end workflow through both interfaces,
  including output read-back, failure and recovery, after approval to build.
- Record desktop/session requirements and actual server capacity; no
  new host inspection or GPU capability claim is made by this catalogue.
- Decide ownership and support cost for each custom adapter. A small number of
  maintainable integrations is preferable to an unowned collection of wrappers.
- Update this dated record when a version, account entitlement or interface
  changes. Operational verification belongs in SJL's private operations records; public city projections
  must not expose credentials, raw fleet inventories or private project data.

The currency discussion is resolved separately: blockchain has been discarded.
No cryptocurrency token, crypto wallet, NFT or crypto-payment dependency is part of this tooling plan.
Real payments remain Razorpay; JC remains a conventional city-ledger design.
