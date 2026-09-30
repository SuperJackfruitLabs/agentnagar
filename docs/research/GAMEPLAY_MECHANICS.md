# Gameplay mechanics: evidence and adaptations

Research pass · 2026-09-16 · [Design](../gameplay/MECHANICS.md)

Findings below are unchanged since 2026-09-16. A companion pass on
2026-09-18, [comparable worlds](COMPARABLE_WORLDS.md), looks at agent-watching
products, shared worlds and maker platforms against the first slice (RD01:
walk the city and watch the Guild at work) and the core role of comments,
messages and assemblies (RD05).

This pass researches the thirteen mechanics discussed with Rakesh: professions,
cooperative construction, neighbourhood character, NPC needs, relationships,
ecology, expeditions, invention, automation, charters, agent apprenticeships,
a newspaper and travelling community projects.

Developer articles and release notes establish what their authors described
at a particular date. They do not establish current balance, SJL performance,
player retention or the success of our proposed adaptations. No referenced
game was installed or playtested in this pass. The agent paper's abstract was
reviewed; this is not a reproduction or full-paper evaluation.

## Sources and scope

| ID | Source | Evidence used | Limit |
| --- | --- | --- | --- |
| S01 | Strange Loop Games, [Eco: Developer Blog—Work Parties](https://store.steampowered.com/news/posts/?appids=382310&enddate=1584894578&feed=steam_community_announcements), 2020 development series | Funded work orders, specialist participation, offline-owner collaboration and knowledge rewards | Historical design; not a current Eco API or balance contract |
| S02 | Strange Loop Games, [Eco government development series: election processes and elected titles](https://store.steampowered.com/news/posts/?appids=382310&enddate=1585598009&feed=steam_community_announcements), 2020 | Configurable offices and privileges distribute civic responsibility | Historical articles in an official announcement feed; does not validate a voting system for SJL |
| S03 | Colossal Order, [Citizen Simulation & Lifepath](https://www.paradoxinteractive.com/games/cities-skylines-ii/features/citizen-simulation-lifepath), 2023-08-28 | Activity choices, service effects, life-event journals and event-related citizen messages | Design diary; no assumption that every described behavior is unchanged today |
| S04 | Colossal Order, [Zones & Signature Buildings](https://www.paradoxinteractive.com/games/cities-skylines-ii/features/zones-signature-buildings), 2023 series | Different land uses and building types shape a city | Supports differentiated districts; our shade/quietness scoring is original |
| S05 | ConcernedApe, [Stardew Valley 1.6 full changelog](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/), named 1.6 release | Dialogue reacting to events, festivals, visiting bookseller and mastery content | Named-release evidence, not a claim about the latest version or retention |
| S06 | Mechanistry, [Two Days to Launch: Building the Beaver Way](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1773310684&feed=steam_community_announcements), 2026-03-10 | Water storage, irrigation, contamination, terrain and player-directed flow | Developer's 1.0 preview; does not establish our ability to run 3D water physics |
| S07 | Mobius Digital, [Filling Out The Toolbox!](https://www.mobiusdigitalgames.com/news/filling-out-the-toolbox), 2016-05-27 | Tools with useful exploration roles; optional learning activities replace a rigid tutorial sequence | Historical design account; not an experiment proving one onboarding method always wins |
| S08 | Wube, [Friday Facts #392: Parametrised blueprints](https://factorio.com/blog/post/fff-392), 2024-01-05 | Reusable designs with selected parameters and dependent values | Reuse/authoring lesson; not permission to execute arbitrary uploaded code |
| S09 | Wube, [Friday Facts #384: Combinators 2.0](https://factorio.com/blog/post/fff-384), 2023-11-10 | Visible signal values, clearer controls and configurable logic | Interface/design lesson; performance and usability need our own tests |
| S10 | Park et al., [Generative Agents: Interactive Simulacra of Human Behavior](https://arxiv.org/abs/2304.03442v2), 2023 | Abstract describes memory, reflection, planning and coordinated social behavior in a research setting | No SJL capacity/cost estimate; believable behavior is not factual or operational reliability |
| S11 | [Existing AgentPod source/integration audit](../gameplay/AGENT_CITY.md), source snapshot `ed10da5` | Authenticated operations, public projections, freshness and role boundaries | Prior source/deployment inspection; no new live fleet or task test in this pass |

Steam feed links retain their historical cursor and article title so readers
can locate the referenced announcement. They contain multiple posts; claims
above refer only to the named developer material. Sources were accessed on
September 16, 2026, rather than being presented as newly published that day.

## Findings that change the design

### Specialization must still work with a small population

Eco's work-party article connects specialist labour, collaboration and rewards
(S01). Our inference: roles can make cooperation useful, but requiring a rare
person online can stall a small village. SJL should begin with freely switchable
roles, asynchronous handoff and an explicit solo fallback. Paid residency must
not be a prerequisite for learning the basic role interaction.

### Reward an accepted outcome, not visible activity

The same article allows defined work and rewards (S01). SJL should post a
funded objective before accepting participants and reward distinct accepted
milestones. Chat volume, repeated placement and AI-generated prose are not
completion evidence. The economic ledger owns payment; the project tracks
which contribution earned it. This is our implementation proposal.

### Explain requests through simulated causes

The citizen diary links routines, services, wellbeing and event reporting
(S03). SJL can turn an unmet need into a request with an evidence panel: e.g.
reading demand exceeds usable seats. A request must close when the need is
resolved, not continue emitting infinite reward quests. NPC demand and human
activity remain separate counts.

### Make a place distinctive through interactions

Land-use variety (S04), event-reactive dialogue and visiting activities (S05)
suggest more than a collection of purchased buildings. Our proposed neighbourhood
character uses shade, sound, walking routes and venue schedules, each with a
visible cause. No single score labels residents or cultures as better people.

### Start ecology with a small inspectable model

Timberborn's water systems connect player construction and environmental
outcomes (S06). SJL does not need that full fluid engine for the first lesson.
A bounded rainfall/storage/soil-moisture model can make irrigation decisions
meaningful, provided its simplifications are stated and its water budget is
conserved. Couple only the systems needed by the first scenario.

### Teach a tool where it solves a problem

Mobius describes moving away from a compulsory sequence toward optional
practice activities on the way to a meaningful destination (S07). We should
test short, discoverable practice stations and contextual hints. This source
supports a design hypothesis, not a promise that players will understand it.

### Reusable automation needs visible execution

Wube's blueprint and circuit articles separate repeated configuration from
runtime logic and improve feedback (S08/S09). SJL should provide authored
condition/action cards, dependency previews, current values and an execution
trace. A stalled rule needs an explanation and a stop control. Credentials and
open-ended script execution are not part of the beginner mechanic.

### Keep civic authority and agent believability bounded

Eco's division of office privileges (S02) suggests separating proposal,
budget and execution roles. Start SJL with reviewable charter templates and
steward approval; elections are a later experiment. The agent paper (S10)
provides an architectural idea for memory-informed interaction, not grounds
for delegating treasury or public-history authority to a language model.
Use authored dialogue and verified events first; optional generated wording
must not invent completion, consent, payment or real agent activity.

## Coverage and proposed priority

| Mechanics | Evidence | SJL design priority |
| --- | --- | --- |
| GM01 Professions; GM02 cooperative construction | S01, S07 | First loop: roles with short accepted contributions |
| GM03 Neighbourhood character; GM04 NPC needs | S03, S04 | One request and one environmental consequence initially |
| GM05 Relationships and memory | S05; S10 as an optional later architecture | Named NPC acknowledgement; explicit, limited event memory |
| GM06 Ecology | S06 | Small garden water/shade model, then district expansion |
| GM07 Expeditions | S07 | Later bounded discovery trip; no large open world prerequisite |
| GM08 Research and invention | S01, S08 | Later compare two designs and publish an accepted recipe |
| GM09 Automation | S08, S09 | Later bounded condition/action rules with replayable traces |
| GM10 Charters | S02 | Template proposal and preview first; elections later |
| GM11 Agent apprenticeship | S10, S11 | Fixture exercise first; one authorized real task only after adapter validation |
| GM12 City newspaper | S03, S05 | A factual completion notice from accepted events |
| GM13 Travelling projects | S05, S07 | Later mobile library/repair café with bookings and handoff |

Travelling projects, the school garden sequence and the specific agent
apprenticeship are our combinations of these ideas. No source establishes
those exact features or their desirability for SJL users.

## Questions for actual playtests

Can someone understand a useful role without selecting a permanent class?
Can two people contribute without one waiting for the other's full session?
Can a visitor explain why the garden's usable capacity changed? Does a factual
acknowledgement make the result memorable? Does the activity remain worthwhile
without a currency reward? Which step feels like a chore?

The [reading garden scenario](../gameplay/scenarios/READING_GARDEN.md) turns
these questions into a bounded evaluation. We have not recruited participants
or measured any outcomes. Further research should follow failures in that
prototype rather than continuously expanding the feature list.
