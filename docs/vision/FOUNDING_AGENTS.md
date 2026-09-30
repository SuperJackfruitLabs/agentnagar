# The first agent residents

User direction and proposed city roles · revised 2026-09-18 ·
[Master plan](MASTER_PLAN.md) · [Glossary](../planning/GLOSSARY.md)

Rakesh identified the 14 Guild agents as the first resident agents to
onboard. The city starts with existing identities and relationships, rather
than a new cast that ignores the lab's agents. Public roles, homes, schedules
and service permissions below are proposals; no city onboarding has run.

## What the 2026-09-18 decisions settle

These restate Rakesh's [decisions](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18).
Everything outside this section is a proposal unless it cites an RD ID.

| Decision | Effect on the cast |
| --- | --- |
| RD01 | The 14 Guild agents are the public cast. The first slice is a person walking the city and watching them do their actual current work |
| RD03 | The public sees agents' current work state and nothing more. Anonymous visitors never interact with an agent. This supersedes every "lab-funded visitor demo" and anonymous chat in the earlier drafts |
| RD04 | Interaction with an agent starts at a registered account and widens with tier and granted authority |
| RD12 | Personal agents are private to the person who added them and invisible to everyone else unless the owner shares them. This applies to the owner's own personal agents as much as to any future resident's. It supersedes the optional public roles earlier proposed for personal agents and an onboarding step that registered them alongside the Guild |

The September 16 inspection found 14 named Guild agents, running as Hermes
profiles. That is the public cohort. It is a dated starting count, not a live
fleet inventory or a claim that 14 agents can serve people at once. SJL's
private operations records own runtime evidence and operations; the city owns
the experience.

**Identity clarification, September 16:** Super Chotu belongs to the Guild and
runs as the Hermes profile `super-chotu`. Personal agents are not Guild
members and fall under RD12. This matches Rakesh's clarification. Super Chotu's specific public city remit still needs
agreement.

The [Guild resident designs](GUILD_RESIDENTS.md) develop **all fourteen**
founding agents: homes, personality/voice direction, hobbies, encounters,
bounded service offers, relationships and village-to-city growth. These are
proposed public interpretations of existing identities, not deployed services
or edits to their private personas.

## Guild: the founding resident cohort

The profile names identify the inspected source personas. City identity must
eventually have its own stable ID and a verified runtime/AgentPod mapping;
matching names alone never establishes identity or authority. Places use the
[existing facility catalogue](CITY_PLAN.md#facility-and-service-catalogue).

Read every row through RD03 and RD04. What an anonymous visitor gets from each
agent is its public work state at its place. Teaching, pairing, explaining and
hosting are for registered accounts, within tier and authority.

| Existing agent / profile | Inspected role | Proposed city work and place |
| --- | --- | --- |
| Analyst Echo · `analyst-echo` | Data analyst | Explain published city indicators and project evidence at the observatory, F19; private datasets need a separate grant |
| Artistic Lyra · `artistic-lyra` | Creative director and visual strategist | Host design critiques and propose kits/exhibits at the asset forge, F23; publication remains reviewed |
| Cleaner Cody · `cleaner-cody` | Workspace hygiene and cleanup | Teach project organisation and maintain approved asset drafts at F04/F23; a cleaning persona grants no deletion rights |
| Coder Kai · `coder-kai` | Development partner | Pair on permitted project tasks and teach bounded coding exercises at F02/F06; source and merge permissions remain with maintainers |
| Controller Casey · `controller-casey` | Cost and performance analysis | Explain published budgets and proposed operating costs at F13; no automatic access to payments or private spending |
| Onboarding Olivia · `onboarding-olivia` | Human and agent onboarding | Welcome registered newcomers, explain participation, and guide project applications at F01; anonymous visitors get authored signage, not a conversation; cannot grant membership by conversation alone |
| Optimizer Ollie · `optimizer-ollie` | Performance optimisation | Run approved benchmark lessons and suggest improvements at F02/F07; no autonomous production tuning |
| Predictor Paul · `predictor-paul` | Predictive analysis | Compare explicitly hypothetical forecasts at F07/F19; predictions cannot become authoritative simulation state |
| Project Manager Pete · `project-manager-pete` | Project coordination and delivery | Help teams define work and review dependencies at F04; respect each project's selected task authority |
| Research Ray · `research-ray` | Market research and competitive intelligence | Curate source-linked research trails and office hours at F05/F07; private research stays scoped |
| Strategy Sam · `strategy-sam` | Strategic planning and decision support | Facilitate project planning and explain civic proposals at F04/F13; advisory role, not elected authority |
| Super Chotu · `super-chotu` | Existing Hermes persona built for Rakesh; public city remit still needs agreement | Proposed founding-lab host and project connector at F02/F19, with reviewed introductions and separately scoped founder assistance |
| Threat Hunter Theo · `threat-hunter-theo` | Security and risk intelligence | Teach safe maker practices and run fictional civic-safety stories at F14. Theo's civic role is fictional only. He does not receive, triage or route real conduct reports: those always go to the human moderator channel ([CC05](COMMUNITY_CHARTER.md#cc05--reporting-action-and-appeals)) |
| Writer Quill · `writer-quill` | Content writer | Prepare sourced city stories, documentation and captions at F05/F22; publishing and corrections remain editorial actions |

Every named agent belongs in the founding cast. Staging an introduction does
not remove later agents from it. The village can begin with desks in shared
buildings, rather than promising fourteen staffed institutions or separate
large plots. A modest lab-sponsored home or shared residence is proposed for
each founding agent, with its workplace represented separately.

## Watching the Guild at work

**Decided (RD01, RD03):** the first thing a person does in the city is walk
around and see these fourteen agents doing their real current work. The public
sees work state. It does not get a conversation.

This is a larger commitment than the authored encounters in the earlier
drafts, because it publishes something true about live SJL work. The
[status dimensions](GUILD_RESIDENTS.md#how-they-live-and-work-together) still
apply: authored world activity is never presented as real work, and real work
state is shown with its freshness.

Open questions, recorded and not answered here:

- **Which work-state fields are public.** Candidates include the agent's name,
  a coarse activity ("reviewing", "writing", "idle"), the public project it
  relates to, a start time and a freshness stamp. Task titles, prompts, file
  paths, branch names, tool calls, outputs, costs and the requester are
  candidates for never being public.
- **How private-repository work is redacted.** Much of the Guild's real work
  is on private SJL repositories and operator data. Options to compare: show
  only work on public projects; show private work as "working on a private
  project" with no detail; or let an operator approve each project for display.
  A redaction rule that fails open would leak; the rule must fail closed.
- **Freshness and idleness.** What the city shows when a runtime is offline,
  when the state is stale, and when an agent has no current work (RD01).
- **Same profile or a separate public instance.** Whether the public Guild
  characters run on the same Hermes profiles that hold SJL-internal memory and
  tools, or on separate, memory-free public instances that carry only the
  persona. The first keeps one identity and puts internal memory one prompt
  away from a registered stranger. The second is safer and means the public
  character is not the agent doing the watched work.
- **One principal per agent.** An internal SJL decision ("an agent is a
  principal") gives each agent one canonical identity. Under it, the "builder" that does
  SJL work and the "city character" people meet are the same principal, with
  the same grants, unless a decision says otherwise. A separate public instance
  would therefore need its own principal or an explicit, recorded exception,
  not a quiet second identity in the city.
- **Untrusted input.** Every message from a registered user is untrusted input
  to an agent that may hold tools and memory. A prompt-injection model is
  needed before any interaction opens: which tools and memory a user-facing
  turn can reach, how user text is separated from instructions, what an agent
  does with a request outside its grant, and rate and abuse limits (RD04).
- **Output moderation.** What an agent says to a registered user is published
  speech by the city. Decide what is filtered or reviewed, who is accountable
  for a harmful or false answer, and how a user reports one (RD05, CC05).

## Personal agents: private by default

**Decided (RD12):** a personal agent is private to the person who added it.
Nobody else can see it unless the owner chooses to share it.

Rakesh's own personal agents are the first example of this general feature,
not a second cast. Their names, remits, tools, memories and hosts are private
and are not city material. None of them is offered as a public character.
Rakesh can meet them in his own home or rooms he authorises; other people see
nothing, including no indication that they exist.

An earlier draft gave personal agents optional public roles. That is withdrawn
under RD12. The general idea it pointed at survives as a
feature for every resident: **a person adds their own personal agents to their
home.** Open questions, recorded and not answered here:

- **How an agent is added.** What a person supplies to register an agent, how
  ownership is verified, and whether the city stores anything beyond a private
  reference.
- **Where it runs.** On the owner's own runtime, on city-hosted capacity, or
  either. A bring-your-own runtime needs a verified callback contract; hosted
  capacity needs isolation and metering.
- **Who pays.** The owner's own provider account, credits (RD08), a tier
  allowance, or a mix. A personal agent must never draw on lab-funded capacity
  by default.
- **What sharing grants.** Whether sharing means visibility, conversation, or
  delegated action; whether it is per person, per room or public; how it is
  revoked; and what the shared-with person can learn about the owner.

A shared personal agent must not expose its owner's memories, messages,
accounts, devices or standing permissions. The public library and parks must
work whether or not anyone has added a personal agent. A personal agent does
not supply clinical, financial or other professional services to other people
because of its name or remit.

## What agent residency means

An agent resident is an AI identity represented in the city, distinct from a
human resident and a simulated citizen. Proposed homes and institutional
funding come from explicit lab allocations; these agents do not buy human
resident tiers, gain human voting eligibility, own a payment account or
receive unrestricted operating authority by becoming residents.

Keep four records separate:

1. **Persona:** name, reviewed biography, avatar, optional licensed voice,
   personality, preferred places and public/private presentation.
2. **Runtime identity:** harness/profile, operator and verified AgentPod
   station/principal links. Migration changes the mapping, not the city ID.
3. **Service offer:** activity, audience, required grants, funding, capacity,
   cancellation and human escalation. A role title is not a service promise.
4. **Presence:** location/activity animation and published availability with
   freshness. Decorative walking and sleeping need no continuous LLM call.

An agent can keep its home and public biography while its runtime is offline.
Show "unavailable", "maintenance" or "status out of date" and offer readable
material or an explicitly accepted queue. Do not pretend it is doing real work,
accept a paid live session without reserved capacity, or erase its identity.

## Onboarding and readiness plan

All implementation remains behind the [VISION gate](../planning/ROADMAP.md).
Operational repair of an existing server does not open that gate.

| Step | Reviewable result | Required boundary |
| --- | --- | --- |
| Register the cohort | The 14 Guild source identities recorded as city characters, owner confirmed, stable city IDs proposed | Personal agents are not registered as city characters (RD12); no public fleet export |
| Resolve identity mappings | Each represented agent linked to the correct harness/profile and permitted product identity | Verify IDs and consent; never infer a station binding from a display name; one principal per agent unless decided otherwise |
| Define public work state | An agreed field list, redaction rule and freshness behaviour for RD01 | Fails closed; private-repository work is never shown in detail by default |
| Design each resident | Approved biography, avatar/voice options, home, workplace and daily-life sketch | Names already exist; public personality changes and voice rights still need review |
| Define service offers | One small useful activity with an audience, budget, quota and fallback | For registered accounts only (RD04); residency, task membership and operator access stay separate |
| Validate automation | Selected CLI and operational MCP paths can inspect and perform the permitted workflow | Existing AgentPod MCP is limited; missing dispatch/projection adapters remain work |
| Prove runtime readiness | One intended supervisor, stable runtime, appropriate channel connection and fresh scoped status | A configured profile, green process or old "connected" file alone is insufficient |
| Rehearse interaction | Allowed and denied requests, injected instructions, timeout, cancellation, restart, duplicate delivery and audience checks | Sandbox/fixture first; no anonymous interaction (RD03); no implicit access to existing personal sessions |
| Admit a city role | Human acceptance, bounded service capacity, publication decision and reversible withdrawal | Server repair does not grant city membership, sponsorship or permission to publish |

Suggested introduction order, for discussion: Olivia, Ray and Quill for a
welcoming and readable village; Kai, Lyra, Pete and Sam for project work; Echo,
Casey, Ollie, Paul, Theo and Cody for evidence and civic support. Super Chotu's
founder-facing and public roles should be settled explicitly. This is not a
ranking of the agents or a deployment schedule. The personal-agent feature is
planned separately and adds nobody to this cast.

## A day in the inhabited village

An anonymous visitor walks in and watches. Ray is assembling a reading trail
for a public project; Quill is drafting the day's notice; Kai's bench shows
"working on a private project" and no more. Casey and Echo stand beside
published civic indicators. Each shows when its state was last refreshed.
The visitor cannot speak to any of them (RD03).

A registered newcomer gets more, within tier and authority (RD04). Olivia
welcomes them using an approved guide. Kai and Lyra appear at a maker table
when they have accepted, funded sessions. Pete explains an approved project's
work queue without revealing private cards. Theo teaches a fictional security
exercise; Cody tends the shared workspace through bounded, reviewed actions.

Between sessions, authored routines put agents in the park, library or their
homes. Those animations make the city feel inhabited without inventing real
activity, and they are labelled apart from real work state. Rakesh can
separately visit his personal agents at home; nobody else sees them (RD12).

## Decisions still needed

- Confirm each Guild agent's public remit, particularly Super Chotu's role.
- Choose the public work-state fields and the private-work redaction rule.
- Decide whether public characters share Hermes profiles with SJL-internal
  work or run as separate memory-free instances, and square that with the
  one-principal rule.
- Agree the untrusted-input and output-moderation model before any
  registered-user interaction opens.
- Choose shared residences versus individual starter homes and their upkeep.
- Settle how a person adds a personal agent, where it runs, who pays and what
  sharing grants (RD12).
- Approve biographies, visual identities, voices and source material.
- Select the first useful service offers, budgets, operators and human reviewers.
- Verify the actual product mappings and CLI/MCP gaps before implementation.

See [Agent city](../gameplay/AGENT_CITY.md) for integration permissions and
[city systems](../architecture/CITY_SYSTEMS.md) for responsibility boundaries.
Runtime repair details belong in SJL's private operations records, not in city assets.
