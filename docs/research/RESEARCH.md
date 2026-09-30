# Baseline and inspiration

Research notes · 2026-09-15 · updated 2026-09-18 · [Plan index](../README.md)

Reading note, 2026-09-18: engines, room servers, hosts and databases named
below are candidates under continuing evaluation, not choices (RD15). The
[2026-09-18 decisions](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)
and the research added that day, including
[comparable worlds](COMPARABLE_WORLDS.md), are indexed in the
[gap review](../planning/GAP_REVIEW_2026-09-18.md).

Later naming update: Kaambaan is now Superpipeline. Historical findings below
retain their inspected names; see the [September 16 product refresh](SJL_PRODUCT_REFRESH_2026-09-16.md)
for current interfaces and related SJL changes.

Sources here informed a design proposal. Reviewing a developer page or source
repository is not the same as playing a game, benchmarking a framework, or
running a generation model. Tool and hosted-plan details should be rechecked
when selecting and pinning dependencies.

## Existing website baseline

The baseline, source map and website repairs now live in the
[website implementation plan](https://github.com/SuperJackfruitLabs/super-jackfruit-website/blob/master/docs/VILLAGE_WEBSITE_PLAN.md).

## City-building and simulation references

The middle column describes the referenced work. The last column is our
proposed adaptation, not a claim of matching that game's full system.

| Reference | Relevant mechanism | Adaptation for SJL |
| --- | --- | --- |
| [Townscaper](https://store.steampowered.com/app/1291340/Townscaper/) | Small block placements produce contextual buildings, arches, and details | Make a few pieces combine satisfyingly; immediate previews and forgiving undo |
| [Tiny Glade](https://store.steampowered.com/app/2198150/Tiny_Glade/) | Cozy diorama construction with procedural responses to edits | Let fences, roofs, and paths adapt; preserve a relaxed creative mode |
| [Dorfromantik](https://www.toukana.com/dorfromantik/presskit) | Tile landscape building, light goals, and creative play | A compact tile kit with optional connection challenges |
| [Mini Motorways](https://dinopoloclub.com/press/mini-motorways/) | Drawing roads exposes capacity and routing problems | Show queues and bottlenecks in a bounded teaching scenario |
| [Cities: Skylines II](https://www.paradoxinteractive.com/games/cities-skylines-ii/about) | Connected city systems, citizen simulation, and environmental variation | Causal economy, service coverage, utilities and growth, delivered district by district |
| [Factorio](https://www.factorio.com/) | Production systems, automation, and cooperative construction | Trace tasks through a review yard; give friends complementary actions |
| [OpenTTD](https://www.openttd.org/about) | Transport networks and established multiplayer/company/spectator modes | Bounded shared districts, visitors who can observe, and transport as a readable connection |

SimCity is a useful broad reference for a legible settlement with interacting
services. Rakesh subsequently requested a proper city simulation, superseding
the earlier recommendation to avoid a full city economy. Its
[official page](https://www.ea.com/games/simcity/simcity)
was reviewed as contextual inspiration. No commercial game art, sound, code,
or distinctive interface is proposed for reuse.

### Civic and agent expansion — September 15

- The [Economy 2.0 diary](https://www.paradoxinteractive.com/zh-CN/games/cities-skylines-ii/news/dev-diary-economy-part-one)
  informs visible funding, upkeep and imported-service tradeoffs; the
  [Traffic AI diary](https://www.paradoxinteractive.com/games/cities-skylines-ii/features/traffic-ai)
  informs route cost and service dispatch. These historical design descriptions
  are inspiration, not an audit of the game's current behaviour.
- [AgentPod source and runtime findings](../gameplay/AGENT_CITY.md) distinguish current
  source, released/installed binaries, the hub connection and a candidate lab
  server. Detailed configuration findings stay private.
  Fleet-wide inventory remains unverified; private operational details do not
  belong in public city data.
- Selected concepts from The Agentic Space, an earlier internal SJL concept
  collection, were read after surveying its index. The adaptation table in [People and agents](../gameplay/AGENT_CITY.md)
  records the files and limits; concept capacities are not deployed
  capabilities. Agentic Space is a knowledge bank of older concepts and ideas
  to draw on, not a product, dependency or sibling client (RD16).
- Browser read-aloud, Piper and LiveKit were checked through their primary
  documentation for possible voice approaches. No TTS model, voice server or
  city backend was installed or benchmarked.

The [city systems lab](../../prototypes/city-lab.html) uses invented coefficients and fixtures.
Its budget and pathfinding demonstrate design questions, not forecasts, real
resident data, payment integration, or measurements of the production village.

Local validation passed for the new city lab: daily settlement and depleted
reserves, the main/alternate fire route, water/power failures, funding thresholds,
visitor/R1/R3 access previews, keyboard interaction, and 390/320 px layouts with
no horizontal overflow. An isolated Chrome run reported no page errors or
external requests; desktop/mobile screenshots were visually reviewed. The
atlas link and city-phase text were checked, along with local document links,
embedded JavaScript syntax, whitespace, and the repository content checker.
These checks do not establish real device performance, a working AgentPod
integration, or production multiplayer/city capacity.

## Web/native platforms and repository ownership — September 15

Reviewed [Godot's feature overview](https://godotengine.org/features/),
[web-export constraints](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html),
[renderer comparison](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
and [dedicated-server export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html).
Reviewed [Bevy's engine architecture](https://bevy.org/),
[setup/optimisation guidance](https://bevy.org/learn/quick-start/getting-started/setup/)
and its [August 2026 development update](https://bevy.org/news/bevys-sixth-birthday/).
These support the [platform comparison](../architecture/PLATFORMS.md); no native build or
comparative engine benchmark was run. Godot was a September 15 recommendation
to evaluate; under RD15 it is one candidate and no trial is scheduled. A
2026-09-18 spot-check of the Godot web-export page and the Colyseus Godot
SDK page is recorded in the platform brief.

Rechecked the local website tree: Astro/Three.js implementation, a starter
README and historical plans in `docs/superpowers/`. That informs the
[repository ownership recommendation](../planning/REPOSITORIES.md). The subsequent approved migration created this dedicated city repository;
see [repository ownership and provenance](../planning/REPOSITORIES.md).

## Websites and explorable explanations

| Reference | Lesson for the village | Proposed use |
| --- | --- | --- |
| [Bruno Simon](https://bruno-simon.com/) | Driving can make a portfolio memorable and enjoyable to navigate | Keep the existing car, then invest in navigation, recovery, and destinations worth reaching |
| [Bartosz Ciechanowski's Mechanical Watch](https://ciechanow.ski/mechanical-watch/) | Interactive models and explanatory writing can reinforce each other | A workshop should teach one idea through controls plus readable text |
| [Explorable Explanations](https://explorabl.es/) | Interaction can help readers reason through a system | Give each simulation a question, a manipulation, and a visible consequence |
| [Takuya Matsuyama's portfolio](https://www.craftz.dog/) | A visual scene can sit alongside practical portfolio information | Keep quick reading and product discovery available around the world |

The resulting SJL idea is a public lab with explorable explanations and
cooperative creative space. Its purpose is broader than a collection of
animated project links, while remaining usable as a website.

## Engineering and creation sources

Detailed source links sit beside the relevant recommendations in
[Architecture](../architecture/ARCHITECTURE.md), [Multiplayer](../architecture/MULTIPLAYER.md), and
[Tools](../architecture/TOOLS.md). The research covered:

- Browser engines and authoring approaches: Astro/Three.js, React Three Fiber,
  Threlte, Babylon.js, PlayCanvas, Godot, and Spline.
- Asset workflows: Blender, Blockbench, Kenney, Quaternius, Poly Haven,
  glTF Transform, Meshopt, Khronos validation, camera-to-Blender,
  TRELLIS.2, TripoSR, Stable Fast 3D, and Apple Object Capture.
- Interaction and world tools: Rapier, Tiled, LDtk, Penpot, GSAP, Motion, audio,
  and static search.
- Hosting and shared state: an existing self-hosted lab server, Colyseus, Workers static
  assets, Durable Objects, R2, and D1.
- Residency: earlier GitHub Sponsors research is historical and superseded by
  Rakesh's Razorpay selection. Current provider references live in the
  [payment integration plan](../integrations/payments/RAZORPAY.md); no account was inspected.
- Verification: browser interaction checks, Playwright accessibility guidance,
  Core Web Vitals guidance, and proposed multiplayer load/recovery tests.

This is a selected tool landscape, not an exhaustive inventory of every
website/game creation product. Some source pages could not be retrieved
directly; Blender's official source mirror was used for its general capability
description. No installations or model-generation calls were needed to make
the recommendations.

## Earlier delivery recommendation

This September 15 recommendation is retained as a conditional delivery idea.
The later [VISION gate](../planning/ROADMAP.md#vision--agree-the-open-maker-city)
requires vision agreement and explicit build authorisation before any of it begins.

Preserve the current scene's strengths. Fix evidence and navigation first.
Build one memorable teaching interaction and one satisfying courtyard. Measure
multiplayer on the actual lab server. Expand only after those experiences
work for the people who will use them.

## Economy, payment provider and storage — September 16

Rakesh requested an explicit financial simulation and chose Razorpay. The
[economy brief](../gameplay/ECONOMY.md) contains original game rules and invented examples;
[Razorpay](../integrations/payments/RAZORPAY.md) cites the provider sources for orders/capture, webhook
verification, subscription states and refunds. No payment account was inspected
or API transaction created. Earlier GitHub Sponsors-first guidance is superseded.

An early lab-server storage figure was corrected after a fuller read-only
check. The [storage plan](../architecture/STORAGE.md) records the storage
tiers, limitations and proposed workload placement.
No storage configuration or data was changed.

The new economy lab passed isolated Chrome checks for the worked example,
conserved supply, one-time reward/upgrade grants, funded booking/refund,
insufficient JC, pending/fulfilled cash fixtures, tax changes, keyboard input,
no-JavaScript explanation and 390/320px layouts. Desktop and mobile screenshots
were reviewed. All three prototypes loaded without page errors or external
requests. These are local fixture checks, not payment or shared-server tests.

## Gameplay mechanics and the full world vision — September 16

The [gameplay research record](GAMEPLAY_MECHANICS.md) documents dated developer
materials from Eco, Cities: Skylines II, Stardew Valley, Timberborn, Outer Wilds
and Factorio, plus the Generative Agents abstract and the existing AgentPod
audit. It maps those sources to all thirteen mechanics, with explicit limits.

[Mechanic contracts](../gameplay/MECHANICS.md) define actions, rules, technical
state and first tests; [World systems](../gameplay/WORLD_SYSTEMS.md) retains the
full larger ideas at Rakesh's request. The
[reading garden](../gameplay/scenarios/READING_GARDEN.md) specifies a bounded
cooperative scenario without narrowing the eventual city vision. No new game
prototype, user study, agent dispatch, payment or server service was run here.

## Open maker-city synthesis — September 16

Rakesh selected a city shared by SJL and independent projects, and asked to
resolve the full picture before implementation. The
[master plan](../vision/MASTER_PLAN.md),
[participation proposal](../vision/PROJECTS_AND_COLLABORATION.md) and
[decision register](../planning/VISION_DECISIONS.md) address that operating model.

The SJL organization's repositories were listed again. Four current
product READMEs, Kaambaan integration documentation, Supermessage's newer
product description and selected internal SJL cross-product decisions were read; revisions and
limits are in the [ecosystem evidence record](../vision/ECOSYSTEM.md). Other
repository roles reuse the earlier inventory. No current builds, live
integrations, new server inspections or game implementation were performed.

## Five planning milestones — September 16

The [planning review](../planning/VISION_REVIEW.md) records nine fictional user
journeys, a ten-district vector map, facility contracts (23 on September 16;
25 after F24 Night Market and F25 Supermessage Post Office were added on
2026-09-18), operating/community policy proposals and fifteen logical system
responsibilities. The examples
are authored design scenarios, not observed users or measured demand.

This pass reuses the pinned product evidence in the ecosystem brief; it adds
no new claim of API, payment, server or client availability. Diagram rendering,
local document links, ID coverage and illustrative arithmetic were checked.
Cross-system walkthroughs are analytical planning checks, not software tests.
No gameplay implementation, account/purchase operation or deployment was made.
