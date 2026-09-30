# Resolve the vision before implementation

Decision register · 2026-09-16 · [Master plan](../vision/MASTER_PLAN.md)

Rakesh asked to establish the full picture before building and chose an
**open maker city where SJL and independent projects share the world**.
The implementation roadmap is conditional on completing this planning phase
and an explicit decision to start building. A scenario or suggested engine
comparison is not that decision.

**Planning update:** all five requested milestones now have developed drafts.
The [review guide](VISION_REVIEW.md) maps every VD question to its detailed answer,
records cross-system scenario outcomes and groups the remaining choices. Drafts
are complete; user agreement and implementation authorisation remain pending.

## What is already chosen

- Hybrid exploration, building and civic simulation, including multiplayer.
- Village-to-city growth, public facilities, games, learning and useful services.
- Visitors, residents, real agents and simulated citizens coexist.
- The Guild's existing agents are the first resident-agent cohort; plan
  around personal agents too. Their public roles and access remain
  proposed in the [founding-agent plan](../vision/FOUNDING_AGENTS.md).
- Super Chotu belongs to the Guild cohort; personal agents are not part of
  it. Agent identity follows the current runtime mapping.
- Sponsorship gives residency with a plot; support and accepted contributions
  can improve lifestyle. Exact benefit and contribution policies remain open.
- Avatar/personality choice, with resident character voices in the design.
- Financial simulation, game credits, tier upgrades, taxes and paid services.
- Razorpay for real payments; the provider choice does not settle the economy.
- Blockchain discarded; design JC around a conventional city ledger.
- MCP and CLI access are prerequisites for tooling adoption; missing interfaces
  remain explicit gaps, including for city-owned tools.
- Kaambaan has been renamed Superpipeline. Current plans use the new name;
  the [product refresh](../research/SJL_PRODUCT_REFRESH_2026-09-16.md) records
  interface changes and preserves the meaning of earlier evidence.
- A web entrance and the direction of a downloadable native client; engine
  choice remains provisional.
- City planning belongs in this repository, with website, marketing and
  operational ownership kept in their respective repositories.
- Preserve the full larger mechanic vision, including later experiments.
- Open maker-city identity, with SJL as its founding institution.
- Vision first; no new game implementation until the direction is agreed.

## Decisions recorded on 2026-09-18

Rakesh gave these answers after the [2026-09-18 gap review](GAP_REVIEW_2026-09-18.md).
They are his decisions, not recommendations. Where one supersedes an earlier
recommendation, the owning brief follows this record. The "opens" column lists
consequences that still need an answer; recording a decision does not settle them.

| ID | Decision | Supersedes / affects | Opens |
| --- | --- | --- | --- |
| RD01 | **First slice: walk the city and watch the Guild at work.** A person moves around a city and sees the 14 Guild agents doing their actual current work. | The earlier V1 "square + workshop + personal plot" as the first thing to build; [roadmap W1](ROADMAP.md) | Which work-state fields are public; redaction for private repositories and operator data; freshness and "idle" presentation |
| RD02 | **The city runs on SJL's products.** Prefer that the city uses every SJL product in active development; facilities can be powered by Superpipeline, AgentPod, SuperMD or Supermessage. | VD08 still holds for independent projects: nobody else is required to use SJL tools | Which facility is backed by which product; what each product must expose first |
| RD03 | **Public visitors observe only.** The public can see agents' current work state and what they are doing. They cannot interact with agents. | VD10's "curated bounded demos" for anonymous visitors; lab-funded visitor demos in the Guild designs | Whether anonymous visitors are visible to each other; what a visitor can do besides observe |
| RD04 | **Registered users interact according to tier and authority.** Interaction with agents starts at a registered account and widens with tier and granted authority. | VD10, VD12; AGENT_CITY access matrix | The tier/authority matrix; who funds each interaction; abuse limits and untrusted-input handling |
| RD05 | **Comments, messages and assemblies are a critical part of the experience.** | EXPERIENCES' "start with emotes and invite rooms; public chat is a separate burden" | Moderation capacity, reporting, retention, age scope and the legal duties of hosting user text |
| RD06 | **City credits get a better name.** "Moolah" is a candidate, not yet chosen. `JC` remains the working label in these documents until a name is picked, to avoid renaming twice. | The "Jackfruit Credits / JC" label | [Name research](../research/NAMING.md) |
| RD07 | **Credits can be earned in the game, bought with real money, or included with resident tiers.** A tier can be a subscription or a one-time purchase. | TD01's open "can cash buy JC" (answer: yes); bundle B's "earned JC only" recommendation | Legal character of purchased credits in each market; earned versus purchased balances; refunds, expiry, transfers and no cash-out |
| RD08 | **Credits buy real things.** They pay for facility access, in-game items, compute and storage, because this is the city where residents build products. | OP04–OP06's separation of fictional JC from funded service allowances | Pricing against real cost; farming of earned credits into real compute; metering, caps and interruption |
| RD09 | **A one-time payment buys a block for a house and makes the buyer a resident.** | Bundle A; RESIDENCY entry routes (contribution-earned residency remains a proposal alongside purchase) | What the one-time price includes and for how long the home is hosted; land supply |
| RD10 | **Sponsorship and residency purchase are different things.** Sponsorship funds the lab and its product development and may come with residency and other perks. Someone who only wants a home can simply buy residency. | The overloaded word "sponsor" across the briefs | Tax treatment of each; perk list; refund terms |
| RD11 | **The product is global.** | India-first assumptions in payments, fiscal periods and privacy wording | Payment coverage beyond India, tax/VAT, privacy and age rules per market, time zones, languages |
| RD12 | **Personal agents are private to the person who added them.** Nobody else can see them unless the owner chooses to share them. This applies to the owner's own personal agents as much as to any future resident's. | FOUNDING_AGENTS' optional public roles for personal agents; registering them alongside the Guild | How a person adds an agent, where it runs, who pays, and what "share" grants |
| RD13 | **Forgejo will run on the lab server, and agents get a dedicated git system as part of the stack.** How it integrates is a later discussion. | TD03, TD06 | Capacity, isolation, backup and the lab/production boundary; agent accounts and permissions |
| RD14 | **Integration points are still moving and will be discussed later.** The [verified gaps](GAP_REVIEW_2026-09-18.md#integration-gaps-verified-against-sibling-repositories) are recorded as facts to design around, not as decisions. | — | — |
| RD15 | **Technology choices wait for a clear vision.** Keep evaluating the best available technology for each use case. No engine, room server, database, identity provider or host is chosen, and none is the "next step". | README/ROADMAP wording that made a Godot trial the first step after VISION | — |
| RD16 | **Agentic Space is a knowledge bank.** It is an older collection of concepts and ideas to draw on. It is not a product, a dependency or a sibling client. | ECOSYSTEM's "inspiration" entry | — |
| RD17 | **The name is still open.** Agentnagar is the working name. Agentganj and Agent City (`agentcity.studio`) are the alternatives Rakesh is weighing. | README project domain | [Name research](../research/NAMING.md) |

## Decisions recorded on 2026-09-22

Rakesh selected **Voxel (`02-voxel`)** for building the first scene assets and
said “Begin” after the proposed one-character Blender → GLB → validation →
Godot work-bay experiment. The [pilot](../../prototypes/voxel-work-bay/README.md)
records implementation and evidence. This is authorisation for that local
experiment; full W1 integration, publication, final engine selection and
acceptance of all fourteen character designs remain separate decisions.

## Decisions recorded on 2026-09-24

| ID | Decision | Supersedes / affects | Opens |
| --- | --- | --- | --- |
| RD18 | **Level up before integrating.** The voxel pilot proved the basic mechanics. Next, build game mechanics that work with any visual style, for a dynamic world where agents and humans come and go. SJL project integration follows once that level is reached. The simulation core is written in **Rust**, and real-time rooms are served by **our own Rust server**. The style-agnostic proof uses **11 low-poly tropical diorama** and **08 pixel art**. | Partly lifts RD15 for the simulation core and room server only; no engine, database, identity provider or host is chosen by this. The fixed fourteen-seat hall becomes one place manifest among many. | Crate selection per sub-project; the Godot client's role; persistence; observer visibility (RD03); what sharing a personal agent grants (RD12). See the [world-core specification](../superpowers/specs/2026-09-24-city-world-core-design.md). |

## Recommended answers for discussion

Read these with the [2026-09-18 decisions](#decisions-recorded-on-2026-09-18)
above: RD03/RD04 now answer VD10, RD07/RD08 answer the cash-for-credits part of
VD11/VD21, and RD11 sets the market for every row.

These are concrete proposed defaults, not decisions attributed to Rakesh.
The IDs make disagreements and future changes easy to record.

| ID | Question | Recommended answer | Still to settle |
| --- | --- | --- | --- |
| VD01 | Who is the city for? | Makers, learners, players and communities; software is one medium | Audience priorities and first example communities |
| VD02 | May outsiders show their projects? | Yes, a free account can submit a page and shared-space exhibit | Review criteria, identity checks and content limits |
| VD03 | Must contributors pay? | No; project contribution and basic discovery are free | Funded access and residency-by-contribution rules |
| VD04 | Can people improve SJL products? | Yes, through scoped tasks and maintainers' existing contribution processes | Participating repositories and maintainer capacity |
| VD05 | Can independent teams work here? | Yes, with optional project membership, studios and tool connections | Private-workspace service levels and team management |
| VD06 | Who owns outside projects? | Their creators under declared licences and agreements; listing transfers no project ownership | Platform display/export terms and collaborator agreements |
| VD07 | Must everything be open source? | No; public exhibits may front private projects, and wholly private rooms are possible | Eligibility for grants, public plots and subsidised compute |
| VD08 | Must people use all SJL tools? | No; provide useful native integrations and external links | Supported adapters and responsibility for each |
| VD09 | Is a studio a hosted server? | No; project presence, collaboration and managed execution are distinct services | Whether managed hosting is part of the eventual offering |
| VD10 | Can visitors use agents? | Curated bounded demos; ongoing tasks need identity, project access and budget | Free allowances, pricing, sponsored access and limits |
| VD11 | What is residency worth? | A persistent home, expression, continuity and defined service benefits | Exact ladder, retention, tier prices and earning paths |
| VD12 | Does money buy authority? | No automatic project, civic, review or fleet authority | Civic eligibility and responsibilities of each role |
| VD13 | How do real projects affect the world? | Consented exhibits, teaching, reviewed contributions and curated city events | Which outcomes earn funded game rewards and under whose review |
| VD14 | Does play require real work? | No; recreation, simulation and community life stand on their own | Balance between making, leisure and civic duties |
| VD15 | How does the city grow? | New useful institutions and funded capacity, with contributions and resident demand | Growth thresholds, land allocation and operator workload |
| VD16 | One world or several? | Shared public geography plus scoped private/team/event rooms | Regions, shards, federation, time zones and event capacity |
| VD17 | How are projects discovered? | Searchable directory, tags, rotating exhibits, trails and public events | Curation, fair rotation and clearly labelled sponsorship |
| VD18 | Who governs what? | Operator runs platform; maintainers own projects; civic roles manage specified game policies | Charter, elections, appeals and separation of duties |
| VD19 | What if someone leaves? | Export and archive; separate home, listing, project rights and paid allowance lifecycles | Retention periods, transfer and inactive-team recovery |
| VD20 | How are achievements recognised? | Evidence of accepted outcomes, with attribution and optional privacy | Reward budgets, disputes, reversal and abuse handling |
| VD21 | How does the city fund itself? | Residency and explicit service sponsorship/usage, with visible fictional civic budgets | Cost model, sustainable free access and possible future creator commerce |
| VD22 | What can creators add to the world? | Reviewed exhibits, lessons, kits, activities and eventually bounded extensions | Publishing rights, compatibility, execution boundaries and content tools |
| VD23 | What does a quiet city feel like? | Complete solo activities, authored NPC life and asynchronous collaboration | Day/week calendars, event cadence and community operations |
| VD24 | What does accessibility require? | Text/direct-entry equivalents, keyboard navigation, captions and reduced motion | Full interaction and device support baseline |

## Tool decisions and proposals

The [tools overview](../architecture/TOOLS.md),
[automation requirement](../architecture/AGENT_TOOLING.md),
[MCP/CLI evidence](../research/TOOL_AUTOMATION.md) and
[Forgejo/Superpipeline proposal](../integrations/development/FORGEJO_SUPERPIPELINE.md)
develop the subsequent tools discussion without starting implementation.

| ID | Topic | Status / direction | Still to settle |
| --- | --- | --- | --- |
| TD01 | Blockchain currency | Discarded by Rakesh | Ordinary economy policies remain open; rejecting blockchain does not decide whether cash can buy JC |
| TD02 | Agent-operable tooling | MCP and CLI prerequisites requested by Rakesh | Required operations, role coverage, maintained implementations and workflow verification per tool |
| TD03 | Forgejo and Superpipeline overlap | Real overlap identified; recommended SJL default is Superpipeline for work, Forgejo for software collaboration | Accept the ownership model, verify Superpipeline coverage and define integration contracts |
| TD04 | Independent projects' tools | Recommend per-project choice and one authority per record | Supported adapters and service commitments; no mandatory migration proposed |
| TD05 | City authoring and operating tools | Full tool responsibilities documented as proposals | Domain schemas, ownership, human review and eventual CLI/MCP contracts |
| TD06 | Host/service placement | The lab server for proposed city/heavy jobs; existing AgentPod hub unchanged | Capacity, isolation, costs, recovery and Forgejo placement; [lab/production role](../architecture/STORAGE.md#hosting-role) unresolved; a read-only review is not a deployment approval |
| TD07 | Tool readiness | Dated research catalogue with official/community/docs-only distinctions | End-to-end evaluation after permission to build; missing adapters are not existing capabilities |
| TD08 | AI world models | Exploration requested; [proposal](../research/WORLD_MODELS.md) prioritises reusable assets and preserves learned-agent/neural-multiplayer experiments | First useful workflow, rights, CLI/MCP ownership, compute and cost limits, and evaluation after the vision gate; no model or runtime adopted |

## Policy areas developed for review

1. **Economy:** whether cash can purchase JC; what is earned versus rented;
   tax bases and rates; progression balance; loans/insurance; real creator
   commerce and payout responsibilities. No real prices are selected here.
2. **Residency:** initial contribution-based residency, plot permanence,
   abandonment, tier downgrades, scarcity, public versus private homes.
3. **Community:** age eligibility and interaction model, conduct rules,
   moderation staffing, reporting, appeals, privacy and participant safety.
4. **Projects:** team recovery, ownership disputes, public/closed-source mix,
   exhibit suitability, maintainer responsiveness and contribution recognition.
5. **City government:** eligible electorate, representation, tenure, quorum,
   conflicts of interest, steward powers and the limits of fictional policing.
6. **Compute:** hosted versus bring-your-own execution, which actions are
   available, quotas, interruption, funded access, metering and service support.
7. **World operation:** persistent time, away-player effects, seasons,
   disasters, loss/recovery, shared geography, regional access and growth rules.
8. **Creative direction:** labelled world map, size/scale, visual language,
   interior experience, avatar variety and what daily life feels like.

The [operating model](../vision/OPERATING_MODEL.md),
[community charter](../vision/COMMUNITY_CHARTER.md),
[city plan](../vision/CITY_PLAN.md) and [system map](../architecture/CITY_SYSTEMS.md)
now provide recommended answers and consequences for these areas. The review
package preserves alternatives and identifies numerical/operational parameters
that need confirmation or later evidence. A recorded choice is still required
for adoption; developing the draft does not discard the bigger ideas.

## Planning deliverables and completion criteria

| Deliverable | What makes it reviewable | Current state |
| --- | --- | --- |
| Coherent city concept | Purpose, audiences, institutions, growth, role of SJL and independent makers | Connected synthesis in the [master plan](../vision/MASTER_PLAN.md) and [review guide](VISION_REVIEW.md) |
| Participation and project lifecycle | Visitor, free creator, resident, contributor, maintainer and steward journeys, including exit | Nine developed [journeys](../vision/PEOPLE_AND_DAILY_LIFE.md), including private work, disagreement and exit |
| Ecosystem responsibility map | What each product supplies, what remains missing and what happens on failure | [Ecosystem evidence](../vision/ECOSYSTEM.md) expanded into fifteen [system responsibilities](../architecture/CITY_SYSTEMS.md) |
| Illustrated city and daily life | Labelled districts, homes, studios, public routes; a visit, a working day and a festival | Ten-district [concept map](../vision/assets/open-maker-city.svg), growth forms and daily/festival narratives drafted |
| Facility and service catalogue | For every place: activity, audience, owner, capacity, funding, upkeep and failure/closure behaviour | 25 facilities (F01–F25, since 2026-09-18) mapped to operators, access, capacity, funding, closure and the SJL product that could power them in the [city plan](../vision/CITY_PLAN.md) |
| Economy and residency policy | Free/paid access, rewards, taxes, budgets, ownership and retention fit together | Twelve [operating-policy proposals](../vision/OPERATING_MODEL.md), alternatives and arithmetic examples; choices pending |
| Creator and community charter | Rights, review, disputes, moderation, private work and contribution recognition | Ten [community-charter policies](../vision/COMMUNITY_CHARTER.md) drafted, including review, discovery, appeals and civic government |
| Scope and dependency map | Full city vision retained, foundational versus experimental decisions labelled | Full mechanics retained; [system dependencies](../architecture/CITY_SYSTEMS.md) and scenario review recorded; implementation waits for agreement |
| Vision agreement | Rakesh can explain the intended experience and accepts the major tradeoffs | Pending; agreement must not be inferred from approving one document or a single option |

## How to work through it

Begin with the people and project journeys, because those reveal whether the
world has a coherent purpose. Then draw the places needed to support them and
trace the services, tools and money underneath. Reconcile the economy and
community rules with those journeys. Revisit architecture choices using that
agreed experience, rather than allowing a selected engine to define the city.

Use examples to expose consequences: a free creator asks for a stall; a resident
stops paying; a private team wants an agent; an SJL maintainer rejects a patch;
an exhibition becomes popular; a civic service cannot afford its upkeep.
Record decisions here and update the owning brief. No automatic progression to
implementation follows from finishing this document.

## 2026-09-22 — Voxel agent appearance correction

The user confirmed that agents should use the selected Voxel robot appearance.
The pilot’s first human-presenting Kai misread the human residents in the living
sheet as the agent reference. Revision `pilot-r002-robot` supersedes that design:
white mechanical shell, dark display with green chevron eyes and smile, and
segmented limbs. Individual Guild roles retain distinct accessories and accents;
Kai keeps the tool apron and engineering motif. This corrects agent appearance
without changing the concept sheet’s human residents or identifying Kai as A1.
