# An open maker city

Vision synthesis · 2026-09-18 · [Design index](../README.md)

**Chosen direction:** an open maker city where SJL and independent projects
share the world. SJL is the founding institution: it builds useful tools,
operates the settlement and contributes projects, while other people bring
their own work, interests and communities.

**Current phase:** develop and resolve the vision before implementation.
Rakesh explicitly asked to build the complete picture first. The existing
mechanic catalogue and planning illustrations remain useful, but do not
constitute agreement on the operating model below. Apart from the chosen
direction and previously recorded user decisions, this document proposes
answers for discussion. No new gameplay implementation is authorized by it.

Rakesh's
[decisions of 2026-09-18](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)
(RD01–RD17) are applied here and cited by ID. Everything not carrying an RD ID
or listed as already chosen is still a proposal. "Agentnagar" is the working
name; the name is open (RD17).

The five planning milestones now have a [complete draft review](../planning/VISION_REVIEW.md):
[people and daily life](PEOPLE_AND_DAILY_LIFE.md), [city plan and facilities](CITY_PLAN.md),
[operating model](OPERATING_MODEL.md), [community charter](COMMUNITY_CHARTER.md)
and [system responsibilities](../architecture/CITY_SYSTEMS.md). They make the
recommendations concrete without treating draft completion as approval.

The city now has a named [founding-agent cast](FOUNDING_AGENTS.md): the
14 existing Guild agents. Personal agents, including Rakesh's own, are private
to the person who added them and nobody else sees them unless the owner shares
them (RD12), so they are not part of the public cast. The Guild agents'
places, public services and city permissions are proposed; existing personal
access is not a public benefit. The [Guild resident designs](GUILD_RESIDENTS.md)
develop every Guild agent's home, encounters, services and relationships,
including their larger city roles.

## The first thing to experience (RD01)

**Walk the city and watch the Guild at work.** A person arrives, moves through
the streets and sees the 14 Guild agents doing their actual current work: one
at the press room drafting a story, one in a studio sorting a board, one at
the observatory reading a chart. What they are doing is true and current, not
an animation loop. This is the first slice of the vision, ahead of the earlier
"square, one workshop and a personal plot" idea. It describes an experience,
not a technical plan; no technology is chosen for it (RD15).

Two rules shape that walk. A public visitor observes only: they can see each
agent's current work state and cannot interact with an agent (RD03). A
registered person can interact, and how far depends on their tier and the
authority they have been granted (RD04). The rest of the city in this document
grows outward from that first walk.

Still open from RD01: which work-state fields are public, how private
repositories and operator data are redacted, and how stale or idle work looks.

## What this place is for

Someone should be able to arrive with curiosity, find people and useful work,
make something they care about, and leave with an outcome they own or helped
create. Someone else should be able to enjoy the city through games, festivals,
learning, gardens and friendships without taking on a software project.

The distinctive promise is that a place has both a social purpose and a useful
activity. A library holds readable project knowledge. A workshop hosts real
collaboration. A school teaches a skill through practice. An exhibition lets
someone explain what they made. The surrounding city supplies homes, public
services, recreation, ecology, transport and shared decisions.

Real making includes software, writing, research, art, music, models, lessons,
physical-project documentation and civic designs. A Git repository is one
possible source of work; it is not the definition of a project.

## Four paths through one world

| Path | What someone does | What they leave with |
| --- | --- | --- |
| Explore and play | Walk the city, watch the Guild agents at work, visit exhibits, play games; with an account, meet people and help with a city event | Understanding, enjoyment, optional saved progress |
| Learn and practise | Follow a trail, study in the library, attend a class, try a profession | A practice artefact, feedback, a skill portfolio |
| Join a project | Find an open request, meet its maintainers, agree a contribution, get review | Accepted work and attributable credit |
| Bring a project | Present an idea or existing work, seek feedback, recruit collaborators, run a studio | A project home, collaborators and a history of releases |

These are paths, not paid castes. People can switch between them. Residency
adds a persistent home and lifestyle benefits; project participation has its
own membership and permission rules. A non-resident can be a project founder.
A resident can simply enjoy living here. The first path can be walked without
an account, as an observer (RD03). The other three start at a registered
account (RD04).

The [creative direction](VISION.md) describes the same four paths from the
visitor's side, with build-and-experiment activities folded into them.

## The city's places and institutions

The [city plan](CITY_PLAN.md) is the canonical list: 10 districts (D01–D10)
and 25 facilities (F01–F25). The thirteen rows below group those same places
by purpose; they are not a second list.

| Place | City-plan home | Real activity | Simulation and social purpose |
| --- | --- | --- | --- |
| Arrival square and visitor centre | D01 · F01, F18, F22 | Directory, introductions, public schedule, guided routes, news | Orient yourself, discover a district; registered people meet each other here |
| SJL quarter | D02 · F02 | AgentPod Workshop, Superpipeline Yard and SuperMD Reading Room: product exhibits, public roadmaps, contribution requests, lab office hours | Founding workshops with recognisable identities, where Guild agents can be seen at work |
| Post office and assembly places | D02 · F25, with D01 and F13 | Messages, comments, project rooms and notices of assemblies, all critical to the experience (RD05) | The Supermessage Post Office; gatherings in the Square and the town hall |
| Observatory and dispatch centre | D02 · F19 | Current work state of each Guild agent, open to all to watch (RD01, RD03); task requests and help for registered people (RD04) | Explain how useful work happens without exposing fleet administration |
| Exhibition commons and Night Market | D03 · F03, F24 | Independent project pages, demos, feedback sessions, rotating showcases, evening tool-interface stalls | Free stalls, discovery routes, launch events |
| Project studios and maker yards | D03 · F04, F23 | Team discussions, tasks, documents, reviews, approved tool sessions, the asset forge | A place for a team to gather and express its identity |
| Library and archive | D04 · F05, F20 | Project handbooks, source-linked research, tutorials, accessible records | Reading circles, travelling collections, civic memory |
| School and research campus | D04 · F06, F07 | Courses, mentorship, experiments, apprenticeships | Progression, shared discoveries, public learning programmes |
| Homes and neighbourhoods | D05 · F08 | Personal identity, decorating, invitations, clubs | Belonging, local character and lifestyle progression |
| Market and cooperative hall | D07 · F09 | Discover services, request work, arrange approved exchanges | Crafting, supply chains and the JC economy; not the Night Market |
| Parks, recreation centres and stadium | D08, D10 · F10, F11, F12 | Table games, puzzles, sports-like activities, performances | Leisure, festivals and reasons to return without working |
| Town hall and public services | D06 · F13–F17 | Service bookings, published budgets, proposals, moderated assemblies | Utilities, fire response and the civic simulation |
| Harbour, field station and greenbelt | D09, D10 · F18, F21 | Authored expeditions, logistics puzzles, restoration work | Transit, ecology and eventual links beyond the city |

The city prefers to run on SJL's products in active development: facilities
can be powered by Superpipeline, AgentPod, SuperMD and Supermessage (RD02).
The city plan proposes a product for each facility. Nobody else is required to
use them; independent projects choose their own tools (VD08).

A location can host several activities. Avoid needing a permanent building for
every new project. A shared studio, book, market stall or timed exhibition is
a valid presence. A city's visual size should follow useful activity and
operational capacity; creating accounts alone does not justify urban growth.

## People, agents and fictional citizens

A person has separate dimensions: account, residency, project memberships,
civic responsibilities and selected game professions. Money, a game level or
a costume does not silently grant repository access or operational authority.

Public visitors observe only. They can see what agents are doing and cannot
interact with them (RD03). Interaction with agents starts at a registered
account and widens with tier and granted authority (RD04). The tier and
authority matrix, who funds each interaction and the abuse limits are open.
Whether anonymous visitors can see each other is also open (RD03 opens).

Comments, messages and assemblies between registered people are a critical
part of the experience, not an optional extra (RD05). The moderation capacity,
reporting, retention, age scope and legal duties of hosting people's text are
open consequences that the city has to carry.

Connected agents are identified assistants with bounded roles. Fictional NPCs
supply city routines and authored interactions. Both can be characters, but
only the former execute approved real tasks. A gardener NPC can explain a
water shortage; a connected tutor can help with an authorised lesson. Neither
is represented as an actual human resident.

A personal agent that a person adds is private to that person. Nobody else can
see it unless its owner chooses to share it (RD12). How someone adds an agent,
where it runs, who pays and what sharing grants are open.

The recommended permission and project model is in
[Projects and collaboration](PROJECTS_AND_COLLABORATION.md). Its free-account
creator path expands the earlier visitor/resident description without adding
a mandatory paid identity for contributors.

## The relationship between real work and the game

Three kinds of progress coexist:

1. **Personal:** a home, friendships, creative collections and practiced skills.
2. **Project:** questions resolved, contributions reviewed, releases published,
   lessons taught and artefacts produced.
3. **Civic:** services open, public works finish, neighbourhoods develop and
   budgets support more shared life.

Connections between these tracks must be deliberate. A reviewed release can
become an exhibit; teaching an approved class can earn contribution credit;
a cooperative can fund a new workshop; a civic design can become an accepted
blueprint. Raw commit counts, time online and AI output volume are poor proxies
for useful contribution. A project release does not automatically mint JC,
construct a building or give its author control of a district.

Simulation stays enjoyable during a quiet week in the real lab. Useful work
stays accessible without walking to a building, completing a quest or winning
a game. Every important activity also has a readable direct-entry view.

## A complete project journey

Imagine an independent maker brings an orchard-monitoring project. They create
a free account, describe the idea, declare what they own and choose what is
public. After exhibit review, a stall explains the sensor and links to a demo.
Anyone can read and watch; registered people can comment, join an open session
or offer to contribute (RD03–RD05).

A contributor proposes an accessible dashboard. The maker accepts the scope
and gives project membership. A task enters the chosen board, discussion stays
in the chosen room, and design notes stay in the chosen document store. If the
team requests an agent, a separately authorised budget and workspace limit
what it can do. A human reviews the result before merging or publishing.

The maker chooses to exhibit the new release. An optional city story celebrates
it with consent and source evidence. A separately reviewed simulation adapter
could let a fictional orchard illustrate the sensor's purpose. The external
project keeps its ownership and can leave with its artefacts. Its residence,
project listing, hosted resources and code each have distinct lifecycles.

This same path works for improving SuperMD, documenting AgentPod, composing
music for a festival or building a community course. Review and ownership
follow the project, rather than a resident tier, a purchase or a sponsorship.

## What the city must operate

| System | Required vision-level answer | Owning brief |
| --- | --- | --- |
| World and navigation | Shared public settlement to walk, visible agent work (RD01), districts, direct links, private project rooms | [Experiences](EXPERIENCES.md), [multiplayer](../architecture/MULTIPLAYER.md) |
| Identity and belonging | Observing visitors, registered accounts, tiers and granted authority, resident benefits, project roles, civic roles (RD03, RD04) | [Participation](PROJECTS_AND_COLLABORATION.md), [residency](../gameplay/RESIDENCY.md) |
| Making and discovery | Project directory, exhibitions, contributions, studios, review, archives | [Participation](PROJECTS_AND_COLLABORATION.md) |
| Learning and play | School, library, mentors, professions, games, quests, festivals | [Mechanics](../gameplay/MECHANICS.md), [full systems](../gameplay/WORLD_SYSTEMS.md) |
| City simulation | Population, land use, utilities, transport, ecology, services and incidents | [Civic simulation](../gameplay/CIVIC_SIMULATION.md) |
| Progress and funding | Credits (working label JC), tiers, residency purchase, sponsorship of the lab, public budgets, grants, service allowances (RD06–RD10) | [Economy](../gameplay/ECONOMY.md), [Razorpay](../integrations/payments/RAZORPAY.md); payment coverage beyond India is open (RD11) |
| Real project tools | Work, communication, documents, runtimes and external tool connections | [SJL ecosystem](ECOSYSTEM.md) |
| Community stewardship | Comments, messages and assemblies (RD05), conduct, discovery curation, project disputes, appeals, events, content rights | [Participation](PROJECTS_AND_COLLABORATION.md), [decisions](../planning/VISION_DECISIONS.md) |
| Operation and continuity | Device access, persistence, privacy, recovery, costs, inactivity and exit | [Architecture](../architecture/ARCHITECTURE.md), [storage](../architecture/STORAGE.md), [decisions](../planning/VISION_DECISIONS.md) |

The documents cover the full intended system, including larger experiments.
They are not a commitment to implement all subsystems simultaneously or a
claim that unanswered policies have been settled.

## Decided on 2026-09-18

These are Rakesh's decisions, summarised from the
[decision register](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18).
Each leaves consequences open; the register lists them.

- **First experience (RD01):** walk the city and watch the 14 Guild agents do
  their actual current work.
- **Built on SJL products (RD02):** the city prefers to use every SJL product
  in active development. Independent projects are not required to (VD08).
- **Who may interact (RD03, RD04):** public visitors observe only. Registered
  people interact with agents according to tier and granted authority.
- **Talking to each other (RD05):** comments, messages and assemblies are a
  critical part of the experience.
- **Credits (RD06–RD08):** credits can be earned in the game, bought with real
  money or included with a resident tier. A tier can be a subscription or a
  one-time purchase. Credits buy facility access, in-game items, compute and
  storage. The credit's name is open; `JC` is the working label.
- **Homes (RD09):** a one-time payment buys a block for a house and makes the
  buyer a resident. Residency earned by contribution remains a proposal
  alongside purchase.
- **Sponsorship (RD10):** a sponsor funds the lab and its product development,
  and may receive residency and other perks. Someone who only wants a home
  buys residency. In these documents "sponsor" means only this; a person who
  pays for a facility or an event is called a funder.
- **Global (RD11):** the product is global. Payment coverage beyond India,
  tax, privacy and age rules per market, time zones and languages are open.
- **Personal agents (RD12):** private to their owner unless shared.
- **Technology (RD15):** no engine, room server, database, identity provider
  or host is chosen, and none is the next step.
- **Name (RD17):** open. Agentnagar is the working name.

## Defaults proposed for the complete picture

- A registered account is free and can present projects and contribute. Paid
  residency buys a home and defined benefits, not the right to participate or
  guaranteed reach.
- SJL projects, independent projects and civic projects have visible ownership
  and affiliation labels. Listing is not endorsement or incorporation into SJL.
- Public exhibits can link to private team work. Privacy is explicit at the
  project, artefact, event and room boundaries.
- Existing external tools remain valid. The SJL suite is a preferred integrated
  route with independently useful products, not an obligatory installation bundle.
- Hosted compute has its own permission and quota. Credits can pay for compute
  and storage (RD08), but a project listing alone includes neither unlimited
  inference nor a general hosting service, and paying does not replace the
  project permission a task needs.
- Start the shared world with one coherent public geography and separately
  scoped rooms. Event instances are acceptable; regional worlds, federated
  cities and inter-city trade remain larger design questions. A global
  audience (RD11) makes regions and time zones an earlier question than before.
- Civic politics can govern fictional budgets and policies. SJL retains its
  real responsibilities for platform operation; project maintainers retain
  merge and release authority. Elections do not appoint server administrators.

## What happens next in planning

Review the [completed planning drafts](../planning/VISION_REVIEW.md) and resolve
the [foundational decisions](../planning/VISION_DECISIONS.md). The journeys,
labelled map, service catalogue, funding model, charter and system map are now
developed. Their scenario walkthroughs expose the consequences of the proposed
choices. Preserve alternatives until the choices are explicit.

The next milestone is a coherent, reviewable vision that Rakesh recognises as
the intended city. Implementation follows a separate explicit decision to
start. Technology choices wait for that clear vision (RD15): the reading
garden and any engine comparison are candidate evaluations, not the next step.
