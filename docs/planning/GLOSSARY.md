# Glossary

Working definitions · 2026-09-18 · [Decision register](VISION_DECISIONS.md)

Short definitions of the terms the planning documents use, with a link to the
brief that owns each one. Where the briefs disagree or a term has never been
defined, this page says so rather than inventing an answer. Decisions are
attributed to their RD IDs; everything else is the current proposal.

## Money and entitlements

### City credits (`JC`)

The city's spendable credits. `JC` ("Jackfruit Credits") is the working label
only; a better name is pending and "Moolah" is a candidate, not a choice (RD06).
Credits can be earned in the game, bought with real money or included with a
resident tier (RD07), and they buy facility access, in-game items, compute and
storage (RD08). Whether credits can ever be cashed out is **open**: no
cash-out is the proposed guardrail throughout the briefs, and RD07 lists it
among the consequences still to settle. Owner: [operating model OP04](../vision/OPERATING_MODEL.md#op04--credits-earned-bought-or-included)
and the [economy brief](../gameplay/ECONOMY.md).

### Service allowance

An entitlement counter, not money: for example one tutor booking or a measured
voice quota for a stated period, with visible remaining units and expiry.
Allowances predate RD08; how they coexist with credits that now buy the same
services is open. Owner: [economy brief](../gameplay/ECONOMY.md#three-balances-with-different-jobs).

### Funded capacity allocation

Real operating capacity (compute, storage, staff hours, budget) reserved before
a promise is made, so that accepting work or selling a service cannot create an
unfunded hosting obligation. Used in OP02 and OP07 but never precisely
defined; a definition with units is needed. Owner: [operating model OP07](../vision/OPERATING_MODEL.md#op07--two-budgets-keep-a-facility-open).

## Homes and people

### Resident and residency

A resident is a registered person with a persistent home in the city.
Residency is the status. A one-time payment buys a block for a house and makes
the buyer a resident (RD09); sponsorship may include residency (RD10); a
reviewed contribution package earning residency remains a proposal. Founding
agents are agent residents, a distinct kind. Owner: [residency brief](../gameplay/RESIDENCY.md)
and [OP02](../vision/OPERATING_MODEL.md#op02--routes-into-residency).

### Block, plot and home

*Block* is the thing a one-time payment buys (RD09). *Plot* is the bounded
piece of ground a home stands on, proposed to be instanced rather than scarce
land. *Home* is the building and interior on it, with a stable address. The
briefs have used plot and block interchangeably; the proposal is that a block
is a licence to a hosted home, not a transferable title, which is open. Owner:
[OP08](../vision/OPERATING_MODEL.md#op08--blocks-homes-and-visibility-are-not-speculative-assets).

### Tier and the R1–R4 ladder

A resident tier is what a resident has bought or earned; it can be a
subscription or a one-time purchase and can include credits (RD07). R1–R4 name
the creative lifestyle ladder: starter home, cottage, courtyard and garden
house. Do not confuse them with the [experience-plan](../vision/EXPERIENCES.md)
feature IDs R01–R05 or the [roadmap gate](ROADMAP.md) R1, which are unrelated.
Owner: [residency brief](../gameplay/RESIDENCY.md) and [OP03](../vision/OPERATING_MODEL.md#op03--tiers-lasting-unlocks-and-optional-services).

### Sponsor, residency buyer, facility funder, lab-sponsored

Four things the word "sponsor" used to cover. A **sponsor** (RD10) funds the
lab and its product development and may receive residency and perks. A
**residency buyer** (RD09) pays once for a block and a home and sponsors
nothing. A **facility funder** pays for a named facility's real operation or
a programme in it, with a clearly labelled presence and no editorial or civic
authority. **Lab-sponsored** describes a home or capacity paid for from the
lab's own allocation, as proposed for the founding agents. Owners: [OP02](../vision/OPERATING_MODEL.md#op02--routes-into-residency),
[OP07](../vision/OPERATING_MODEL.md#op07--two-budgets-keep-a-facility-open), [CC03](../vision/COMMUNITY_CHARTER.md#cc03--exhibits-and-fair-discovery).

### Visitor, registered user, resident

An anonymous **visitor** observes only: public places and the Guild agents'
work state, never an agent interaction (RD03). A **registered user** holds a
free account and can comment, message, join assemblies and interact with
agents as tier and authority allow (RD04). A **resident** is a registered user
with a home. Owner: [community charter CC01](../vision/COMMUNITY_CHARTER.md#cc01--belonging-and-the-participation-boundary).

### Reviewed participation record

Proposed voting-roll requirement in CC07 alongside account age and civic
orientation. Undefined — needs a decision on what is recorded, who reviews it
and what disqualifies. Owner: [CC07](../vision/COMMUNITY_CHARTER.md#cc07--civic-participation-and-later-elections).

### Civic orientation

Proposed voting-roll requirement in CC07: something a person completes before
voting. Undefined — needs a decision on its content, length and whether it is
a test. Owner: [CC07](../vision/COMMUNITY_CHARTER.md#cc07--civic-participation-and-later-elections).

## Roles

### Operator

The platform operator: runs the service, access controls, actual operating
allocation and incident response. Today this is Rakesh. Owner: [CC06](../vision/COMMUNITY_CHARTER.md#cc06--four-distinct-kinds-of-authority).

### Maintainer

A project maintainer: decides membership, contribution scope, technical review
and releases for one project, SJL or independent. A maintainer gains no civic
or platform authority from the role. Owner: [CC06](../vision/COMMUNITY_CHARTER.md#cc06--four-distinct-kinds-of-authority).

### Steward

Used in two senses. A **civic steward** (or council) decides specified
simulation budgets, zoning and game policies within a published mandate. A
**facility steward** (library, park, utility, transit) operates one facility
under the city plan. Neither controls billing, platform administration or a
project's source. Owners: [CC06](../vision/COMMUNITY_CHARTER.md#cc06--four-distinct-kinds-of-authority)
and the [city plan](../vision/CITY_PLAN.md#facility-and-service-catalogue).

## Agents and machines

### Founding agent, personal agent, simulated citizen (NPC)

A **founding agent** is one of the 14 Guild Hermes agents, the public cast
(RD01). A **personal agent** is one a person adds for themselves; it is private
to its owner and invisible to others unless shared (RD12). A **simulated
citizen (NPC)** is an authored fictional character with no runtime behind it,
labelled as simulation. Owner: [the first agent residents](../vision/FOUNDING_AGENTS.md).

### Guild

The cohort of 14 named SJL agents that runs on the Hermes harness: the
founding cast. Also the shorthand for those agents as a group ("the Guild at
work"). Owner: [Guild residents](../vision/GUILD_RESIDENTS.md).

### Hermes

The agent harness that runs the Guild profiles. A Hermes profile is a runtime
identity, not a city identity; the city keeps its own stable ID and a verified
mapping. Whether public characters share these profiles with SJL-internal
memory is open. Owner: [the first agent residents](../vision/FOUNDING_AGENTS.md#watching-the-guild-at-work).

### OpenClaw

An agent harness used for personal agents. AgentPod detects it as one of
several harnesses. Owner:
[the first agent residents](../vision/FOUNDING_AGENTS.md) and [agent city](../gameplay/AGENT_CITY.md).

### Super Chotu

A Guild Hermes profile (`super-chotu`), an existing persona built for Rakesh.
Proposed founding-lab host and project connector; its public remit still needs
Rakesh's agreement. It belongs to the Guild, not to any personal set of agents. Owner: [Guild residents GR02](../vision/GUILD_RESIDENTS.md#gr02--super-chotu).

### Lab server

SJL's self-hosted lab machine, with an SSD tier and an HDD tier, proposed for
city simulation and bounded heavy jobs, and the decided host for Forgejo (RD13). Its lab versus
production role is unresolved. No addresses or configuration belong in this
repository. Owner: [storage brief](../architecture/STORAGE.md).

## Growth words

### Village, town and city

Four meanings are in use; say which one you mean.

1. **World growth form.** The village, town and city forms of each district
   and facility in the [city plan](../vision/CITY_PLAN.md#districts-and-growth),
   which refuses numeric population thresholds. Also the stage table in
   [Guild residents](../vision/GUILD_RESIDENTS.md#village-town-and-larger-experiments)
   and the [master plan](../vision/MASTER_PLAN.md).
2. **Delivery arc.** The [experience plan](../vision/EXPERIENCES.md) defines
   village as the first useful development arc and town as deeper workshops;
   the [roadmap](ROADMAP.md) gates T1 "a town" and C1 "a city" and prefixes
   its tickets `VIL-`.
3. **Governance stage.** [CC07](../vision/COMMUNITY_CHARTER.md#cc07--civic-participation-and-later-elections)
   proposes a consultative village and a voting town; its 30-participant
   figure is a draft review input, not a threshold.
4. **The existing place and the whole product.** "The village" is also the
   current Three.js website village that the [vision](../vision/VISION.md)
   grows from, and "the city" is the whole product, whose name is still open
   (RD17: Agentnagar, Agentganj or Agent City).

## ID prefixes

| Prefix | Range today | What it identifies | Owner |
| --- | --- | --- | --- |
| VD | VD01–VD24 | Vision questions with recommended answers | [Decision register](VISION_DECISIONS.md#recommended-answers-for-discussion) |
| TD | TD01–TD08 | Tool decisions and proposals | [Decision register](VISION_DECISIONS.md#tool-decisions-and-proposals) |
| RD | RD01–RD17 | Rakesh's decisions recorded on 2026-09-18 | [Decision register](VISION_DECISIONS.md#decisions-recorded-on-2026-09-18) |
| OP | OP01–OP12 | Operating-model policies | [Operating model](../vision/OPERATING_MODEL.md) |
| CC | CC01–CC10 | Community-charter policies | [Community charter](../vision/COMMUNITY_CHARTER.md) |
| J | J01–J09 | People and daily-life journeys | [People and daily life](../vision/PEOPLE_AND_DAILY_LIFE.md) |
| F | F01–F25 | Facilities in the catalogue | [City plan](../vision/CITY_PLAN.md#facility-and-service-catalogue) |
| D | D01–D10 | Districts | [City plan](../vision/CITY_PLAN.md#districts-and-growth) |
| SYS | SYS01–SYS15 | System responsibilities | [City systems](../architecture/CITY_SYSTEMS.md) |
| GM | GM01–GM13 | Game mechanics | [Mechanics](../gameplay/MECHANICS.md) and [world systems](../gameplay/WORLD_SYSTEMS.md) |
| GR | GR01–GR14 | Guild resident character cards | [Guild residents](../vision/GUILD_RESIDENTS.md) |
| VIL | VIL-01–VIL-33 | Candidate implementation tickets after VISION | [Roadmap](ROADMAP.md#candidate-implementation-tickets-after-vision) |
| U, P, M, R | U01–U08, P01–P10, M01–M05, R01–R05 | Experience-plan features: utility, playable, multiplayer, residency. R01–R05 are unrelated to tiers R1–R4 | [Experience plan](../vision/EXPERIENCES.md) |
| E, SP | E01–E11, SP01–SP04 | Dated product evidence | [Ecosystem](../vision/ECOSYSTEM.md#evidence-record), [product refresh](../research/SJL_PRODUCT_REFRESH_2026-09-16.md) |
| C, bundles A–G | C01–, A–G | Cross-system scenarios and decision bundles | [Review guide](VISION_REVIEW.md) |
| S | S01– | Research sources | [Gameplay mechanics research](../research/GAMEPLAY_MECHANICS.md) |

### Roadmap gates

VISION (agree the city), O1 (free maker participation), V0 (website
foundation), D1 (compare web and native clients), V1 (first hybrid slice, now
RD01's walk-and-watch), V2 (build with a friend), R1 (move in and grow a home),
S1 (civic district), A1 (people and agents as neighbours), E1 (resident
economy), G1 (cooperative project), T1 (town), C1 (city). All are conditional
on VISION and none is "the next step" (RD15). Owner: [roadmap](ROADMAP.md).
