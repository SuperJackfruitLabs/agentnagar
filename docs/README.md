# Agentnagar — Village → City

Design and engineering brief · 2026-09-15, updated 2026-09-18 · internal planning

**Decisions of 2026-09-18.** After a [gap review](planning/GAP_REVIEW_2026-09-18.md)
of the complete draft, Rakesh recorded seventeen decisions
([RD01–RD17](planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)).
The first slice is walking the city and watching the 14 Guild agents at their
real work. The public observes; registered users interact by tier and
authority. Comments, messages and assemblies are core. Credits (name pending)
are earned, bought or included with a tier and buy facility access, items,
compute and storage. A one-time payment buys a block and residency;
sponsoring the lab is separate. The product is global. Personal agents are
private unless shared. Forgejo will run on the lab server. Technology choices wait
for a clear vision. Nine [research briefs](#documentation-map) were added and
the stale briefs corrected. The project name remains open; Agentnagar is the
working name.

**Build a place people can explore, learn from, and make together.** The public
settlement tells the real story of Super Jackfruit Labs. A growing city
simulation connects homes, public services, budgets, and useful activities.
People and agents share the place; personal and multiplayer plots let people
help shape it.

Rakesh chose a **hybrid** direction and added **multiplayer** to the scope.
He also proposed **visitors and residents**: sponsors receive a plot, and
further support or contributions improve their lifestyle in the village. The
expanded target includes public facilities, games, reading, education, civic
services, avatars/personality, resident voices, and deeper resident access to
agent roles. Rakesh also proposed a downloadable game alongside the browser
experience; Godot is the recommended first candidate to evaluate, with Bevy
as an alternative. See the linked briefs for this larger scope.
SJL's self-hosted lab server may support compute-heavy work. Its capabilities
were inspected read-only; the proposed services have not been installed.
Everything described as a new feature here is a proposal, not a shipped claim.

## Current planning phase

Rakesh chose an **open maker city where SJL and independent projects share the
world**, and asked to resolve the vision before building. Start with the
[master plan](vision/MASTER_PLAN.md), [projects and collaboration](vision/PROJECTS_AND_COLLABORATION.md),
[ecosystem map](vision/ECOSYSTEM.md) and [decision register](planning/VISION_DECISIONS.md).
The five next planning milestones now have a connected draft. Start with the
[review guide](planning/VISION_REVIEW.md) for the journeys, labelled city map,
facility catalogue, operating model, community charter and complete system map.
The project/access policies remain proposals for discussion, not implied
approval. Implementation gates below wait for an explicit decision to begin.

The tools discussion is now captured in the [tool strategy](architecture/TOOLS.md),
[agent tooling contract](architecture/AGENT_TOOLING.md),
[CLI/MCP evidence catalogue](research/TOOL_AUTOMATION.md) and
[Forgejo/Superpipeline integration proposal](integrations/development/FORGEJO_SUPERPIPELINE.md).
Blockchain has been discarded. MCP and CLI access are required for tooling
adoption; product choices and missing adapters remain explicit proposals/gaps.
The [September 16 product refresh](research/SJL_PRODUCT_REFRESH_2026-09-16.md)
records Kaambaan's rename to Superpipeline and the related AgentPod,
Supermessage and related naming changes, including remaining integration gaps.

The [world-model research](research/WORLD_MODELS.md) extends this with spatial
generation, learned agent behaviour and experimental neural multiplayer. It
records versioned CLI/MCP evidence, costs, licence limits, hosting implications
and larger creative ideas. Authoritative city rules remain separate from
learned predictions; no model integration or experiment has started.

The [repository consistency review](planning/REPOSITORY_REVIEW.md) records
the September 16 audit, corrected conflicts, validation scope and remaining
decisions. It is a dated review, not a deployment or launch-readiness claim.

The [founding-agent plan](vision/FOUNDING_AGENTS.md) adds the actual Guild
cohort to the vision: 14 founding residents, with proposed roles, places and
explicit onboarding gates, and keeps personal agents private (RD12).
The [Guild resident designs](vision/GUILD_RESIDENTS.md) develop all fourteen
Guild agents into proposed neighbours, public guides and bounded collaborators.

## Documentation map

For the next design discussions, use the [mechanics agenda](planning/MECHANICS_AGENDA.md):
fourteen topics, their unresolved choices, existing source briefs, and a suggested
discussion order following the asset catalogue. This is planning, not a release plan.

| Directory | Responsibility | Start here |
| --- | --- | --- |
| `vision/` | City purpose, participation, project ecosystem and creative experience | [Master plan](vision/MASTER_PLAN.md), [projects](vision/PROJECTS_AND_COLLABORATION.md), [ecosystem](vision/ECOSYSTEM.md), [atmosphere](vision/VISION.md), [experiences](vision/EXPERIENCES.md) |
| `gameplay/` | Complete mechanic inventory, scenarios, civic simulation, money, residency and agent roles | [Mechanics](gameplay/MECHANICS.md), [full world systems](gameplay/WORLD_SYSTEMS.md), [reading garden](gameplay/scenarios/READING_GARDEN.md), [economy](gameplay/ECONOMY.md), [civic systems](gameplay/CIVIC_SIMULATION.md), [residency](gameplay/RESIDENCY.md), [people and agents](gameplay/AGENT_CITY.md) |
| `architecture/` | System responsibilities, clients, authority, multiplayer, storage and authoring tools | [City systems](architecture/CITY_SYSTEMS.md), [architecture](architecture/ARCHITECTURE.md), [platforms](architecture/PLATFORMS.md), [multiplayer](architecture/MULTIPLAYER.md), [storage](architecture/STORAGE.md), [tools](architecture/TOOLS.md) |
| `integrations/` | Provider/product-specific contracts and lifecycle behavior | [Razorpay payments](integrations/payments/RAZORPAY.md), [Forgejo and Superpipeline](integrations/development/FORGEJO_SUPERPIPELINE.md) |
| `planning/` | Vision decisions, conditional delivery gates, ownership, migration, glossary | [Planning review](planning/VISION_REVIEW.md), [vision decisions](planning/VISION_DECISIONS.md), [gap review](planning/GAP_REVIEW_2026-09-18.md), [roadmap](planning/ROADMAP.md), [glossary](planning/GLOSSARY.md), [repositories](planning/REPOSITORIES.md) |
| `research/` | Dated evidence, inspiration and inspection limits | [Research](research/RESEARCH.md), [gameplay evidence](research/GAMEPLAY_MECHANICS.md), [MCP/CLI evidence](research/TOOL_AUTOMATION.md), [AI world models](research/WORLD_MODELS.md), [comparable worlds](research/COMPARABLE_WORLDS.md), [legal and compliance](research/LEGAL_COMPLIANCE.md), [payments and credits](research/PAYMENTS_AND_CREDITS.md), [economy model](research/ECONOMY_MODEL.md), [agent runtime costs](research/AGENT_RUNTIME_COSTS.md), [audience, devices and accessibility](research/AUDIENCE_DEVICES_ACCESSIBILITY.md), [identity and moderation](research/IDENTITY_AND_MODERATION.md), [hosting and agent git](research/HOSTING_AND_AGENT_GIT.md), [naming](research/NAMING.md) |
| `references/` | Reproducible asset and tooling examples, with verification limits | [Reference workflows](references/README.md), [Blender humanoid and animation](references/blender-humanoid/README.md) |

Put new documents with their owning subject. Game rules belong in gameplay;
provider-specific payment details belong under integrations/payments. Root
`docs/` contains this index only. Operational secrets and detailed private
service configuration stay outside version control.

The full gameplay inventory includes all thirteen discussed mechanics and their
larger city forms. First-prototype scope does not remove later ideas; see the
[full world systems](gameplay/WORLD_SYSTEMS.md) and their dependencies.

## Interactive planning prototypes

The [asset and prop catalogue](gameplay/asset-catalogue/README.md) describes 108
proposed asset kinds across twelve families, with shared characteristics,
ownership and storage rules, style/device requirements, and a proposed starter
collection. It records the direction of broadly portable small objects,
ownership preventing unauthorized taking, and owner-authorized coin trading.
It is a design catalogue, not an implemented inventory or a change to RD01.

The [first Guild scene asset tracker](gameplay/asset-catalogue/FIRST_GUILD_SCENE.md) defines 60 proposed production deliverables with individual specifications, build/test/review status and attention items. Its [style reference index](gameplay/asset-catalogue/FIRST_GUILD_STYLE_REFERENCES.md) pins the existing concept-art revisions used for design.

The [Voxel work-bay pilot](../prototypes/voxel-work-bay/README.md), authorised on
2026-09-22, starts that pipeline with two robot appearances and a shared workstation,
editable Blender source, GLB exports and a local Godot sample-data preview.
Kai’s robot appearance has user approval. Lyra’s appearance and full-cast
production acceptance remain pending; both share tested walk/sit/stand clips.

- [City visual style studies](vision/style-studies/README.md): thirty illustrated art directions, four initial city viewpoints per style, and three additional experience sheets per style; styles 11 to 30 came from a set of candidate briefs and four of them still lack a city-perspectives sheet. Generated concept art, not gameplay or performance evidence.

- [Village atlas](../prototypes/atlas.html): village/town/city, districts,
  residency routes, a fictional "Guild at work" view of the first slice
  (RD01) with public/registered/resident visibility, and a tiny local
  building sketch.
- [City systems lab](../prototypes/city-lab.html): budget, access, facilities,
  utility failures and fire response.
- [Economy lab](../prototypes/economy-lab.html): wallet/treasury transfers,
  the threshold tax model, tier grants, separate earned and purchased
  balances, and a cash-fixture purchase route.

All three HTML pages are standalone planning illustrations with invented geography
and local state. They have no multiplayer connection, product integration,
accounts, billing, or server persistence. The city lab demonstrates a few causal
rules; it does not implement the full simulation described in the briefs.

This repository is the canonical city/game planning home. Site-specific work
lives in the [website plan](https://github.com/SuperJackfruitLabs/super-jackfruit-website/blob/master/docs/VILLAGE_WEBSITE_PLAN.md); marketing retains evidence,
campaigns and a migration index. See [ownership and provenance](planning/REPOSITORIES.md).

## Candidate release sequence after vision agreement

This earlier sequence is retained for later evaluation. Resolve the open-city
journeys, service catalogue, economy and community rules first, then revisit
the sequence with the agreed vision. It is not the current action plan.
Since 2026-09-18 the first slice is [W1](planning/ROADMAP.md#w1--walk-the-city-and-watch-the-guild-at-work):
walk the city and watch the Guild at work (RD01). The steps below follow it.

1. Repair the catalogue and give every important destination a readable page,
   direct link, and map entry. Preserve the existing driving experience.
2. Build Jackfruit Square, one useful AgentPod exhibit, and a tiny personal
   building plot. Visitors should understand something and make something.
   Alongside this, compare one Godot district on desktop and web before growing
   a large engine-specific gameplay codebase.
3. Add an invite-only cooperative plot for 2–8 people, with authoritative
   placement, undo, reconnect, and saved buildings. Test it on the lab server.
4. Pilot resident accounts, one persistent home per resident, and verified
   lifestyle grants once shared saves work. Start with benefits we can deliver.
5. Build one complete civic district: homes, park, library, school, utilities,
   budget, and fire response. Add one verified public AgentPod role/status
   projection, then bounded resident interactions. Core simulation work can
   begin alongside the plot prototype once stable world IDs exist.
6. Grow into a town and city with recreation centres, police, stadium events,
   transport, and a deeper economy after capacity and recovery are measured.

This puts multiplayer in the first development arc. A public, permanently
editable city requires the later publishing and moderation workflow.

## Decisions and assumptions

| Item | Status |
| --- | --- |
| First slice: walk the city and watch the 14 Guild agents at work | Decided by Rakesh on September 18 (RD01) |
| Public observes only; registered users interact by tier and authority | Decided September 18 (RD03/RD04) |
| Comments, messages and assemblies are core | Decided September 18 (RD05) |
| Credits earned, bought or included with tiers; they buy access, items, compute and storage | Decided September 18 (RD07/RD08); name pending (RD06); legal and economic consequences open |
| One-time block purchase gives residency; sponsoring the lab is separate | Decided September 18 (RD09/RD10) |
| Global product | Decided September 18 (RD11) |
| Personal agents private to their owner unless shared | Decided September 18 (RD12) |
| Forgejo on the lab server; agents get a dedicated git system | Decided September 18 (RD13); integration shape later |
| Integration points and technology choices | Deferred until the vision is clear (RD14/RD15) |
| Agentic Space | Knowledge bank only (RD16) |
| Project name | Open; Agentnagar is the working name (RD17) |
| Open maker city with SJL and independent projects | Chosen by Rakesh on September 16 |
| Resolve the full vision before implementation | Requested by Rakesh; current phase |
| Free project listings and contribution, separate residency and compute permissions | Recommended in the participation brief; policies pending |
| Hybrid exploration + building + simulation | Chosen by Rakesh |
| Multiplayer in the design | Requested by Rakesh |
| Sponsors become residents with plots; support/contributions upgrade lifestyle | Proposed by Rakesh; now developed in the residency brief |
| Proper city simulation with public facilities and mixed free/paid access | Requested by Rakesh; replaces the earlier teaching-toys-only target |
| Visitors, residents, and real agents coexist; residents explore deeper roles | Requested by Rakesh; adapter and permissions remain implementation work |
| Avatar and personality choice; resident voice choice | Requested by Rakesh; modular assets and bounded voice service proposed |
| Financial simulation, tier upgrades, taxes and paid public-service mechanics | Requested by Rakesh; payment matrix and credit loop proposed |
| Razorpay for real-money payments | Selected by Rakesh; account, integration and global coverage unverified (RD11) |
| Blockchain currency | Discarded by Rakesh; conventional JC ledger direction |
| MCP and CLI for tools | Required by Rakesh; per-operation coverage and adoption checks in the tooling contract |
| Superpipeline for work and Forgejo for software collaboration | Recommended SJL allocation; overlap acknowledged, ownership decision and integration pending |
| Separate real-money and JC ledgers | Proposed default; direct credit purchases are now in scope (RD07), prices remain open |
| Non-financial contributions can also earn initial residency | Recommended option alongside purchase (RD09); Rakesh's preference remains open |
| Earned homes/cosmetics survive an ordinary sponsorship pause | Recommended policy; retention and service terms remain open |
| Inspect the lab server for hosting/compute | Requested; read-only inspection completed |
| Native game alongside the web experience | Proposed by Rakesh; documented as a direction to evaluate |
| Godot, Bevy and others as engine candidates | Under continuing evaluation per use case; nothing chosen before the vision is clear (RD15) |
| Preserve Astro + the working Three.js village during evaluation | Recommendation; long-term game renderer remains open |
| Colyseus rooms on the lab server | Candidate among others; no room server chosen (RD15) |
| Separate city/game repo; website owns site integration; marketing owns campaigns/evidence | Approved by Rakesh; migrated September 15, 2026 |
| Tropical maker village, four product workshops, personal plots | Creative proposals |
| 2–8 people per initial room | Test target, not measured capacity |
| GPU inference, human live voice chat, public asset uploads | Optional later work; separate from requested resident character voices |
| Publication, deployment, and invitations | Not performed as part of this documentation work |

The website does not need to become a whole city before SJL can tell its
lab stories. Product claims still need fresh public evidence. Playing a
simulation is not trying the product.
