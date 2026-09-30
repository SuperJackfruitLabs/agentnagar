# Features and experiments

Proposal catalogue · 2026-09-15 · updated 2026-09-18 · [Plan index](../README.md)

**Village** means the first useful development arc, which now opens with the
[first slice](#the-first-slice-walk-the-city-and-watch-the-guild-at-work-rd01)
(RD01) and includes a small multiplayer prototype. **Town** means deeper workshops and dependable shared
sessions and a working civic district. **City** means connected districts,
public services, an interacting economy, agents, and community creation.
These are release horizons, not dates or promises. The [roadmap](../planning/ROADMAP.md)
sets the actual gates. In this catalogue village, town and city always mean
release horizon. The same words mean spatial form in the
[city plan](CITY_PLAN.md), a governance stage in the community charter and an
agent-housing stage in the Guild designs; the
[glossary](../planning/GLOSSARY.md) keeps them apart.

This catalogue serves the **open maker city**: SJL's work and independent
makers' work appear in the same places, and "product" below includes an
independent project wherever the feature is not specific to the lab. The
"technical shape" and "what must exist first" columns sketch the kind of thing
needed. They choose no engine, server, database or other technology (RD15).

## The first slice: walk the city and watch the Guild at work (RD01)

Rakesh decided on 2026-09-18 that the first experience is this: a person moves
around a city and sees the 14 Guild agents doing their actual current work.
It comes before every other row in this catalogue, including the earlier idea
of a square, one workshop and a personal plot as the first thing to build.

| ID | Feature | Visitor value | Shape of what is needed | Horizon |
| --- | --- | --- | --- | --- |
| U09 | The Guild at work | Walk the streets and see what each of the 14 Guild agents is really doing now, where, and since when | A public work-state record per agent with agreed public fields, redaction of private repositories and operator data, a freshness time and an honest idle state | First slice (RD01) |

Public visitors observe this and cannot interact with the agents (RD03).
Registered people interact according to tier and granted authority (RD04).
The public fields, the redaction rules and how "idle" is presented are open.

The [researched mechanic contracts](../gameplay/MECHANICS.md) and
[full world systems](../gameplay/WORLD_SYSTEMS.md) develop all thirteen additional
ideas: careers, cooperative construction, neighbourhood character, needs,
relationships, ecology, expeditions, invention, automation, government, agent
apprenticeships, city news and travelling projects. Their GM IDs complement
the U/P/M/R catalogue below; a later horizon does not remove an idea.

## Useful everyday features

The larger facility catalogue and simulation mechanics now live in
[Civic simulation](../gameplay/CIVIC_SIMULATION.md); agent roles, avatars/personality and
resident voices are developed in [People and agents](../gameplay/AGENT_CITY.md).

| ID | Feature | Visitor value | Technical shape | Horizon |
| --- | --- | --- | --- | --- |
| U01 | Map, search, teleport, unstuck | Find a product quickly or recover from driving trouble | Stable place IDs; URL destinations; HTML directory; camera transition | Village |
| U02 | Project and product passports | Know what exists, who owns it, what is early, and where to try it | One validated content record powers a page, map card, and workshop sign | Village |
| U03 | Open-roof workshops | Understand one idea through a small exhibit | Lazy-loaded scene plus DOM controls, examples, and a readable equivalent | Village: one exhibit |
| U04 | Field-note board | See real recent work from the lab and from independent projects | Curated public notes with date, source, RSS, and related destination | Village |
| U05 | Calm and accessible modes | Use the site without driving, sound, or camera motion | Keyboard map/build controls, still camera, reduced effects, focus management | Village |
| U06 | Tour tram | Follow a short explanation without learning controls | Scripted stops, captions, pause/skip, optional camera path | Town |
| U07 | Blueprints and postcards | Keep or share something made here | Versioned JSON export/import; local image download; explicit publish action later | Village → Town |
| U08 | Archive Garden | Distinguish history from current work | Retired/archived labels, dated snapshots, preserved links where valid | Town |

## Playable ideas

| ID | Idea | The satisfying moment | Smallest useful implementation | Horizon |
| --- | --- | --- | --- | --- |
| P01 | Tiny workshop builder | A veranda and roof adapt as blocks meet | 8×8 plot; a small authored kit; rotate, place, remove, undo, save | Village |
| P02 | Delivery and review yard | Adding workers moves the bottleneck to the review gate | Seeded task arrivals, service queues, reviewer control, a plain chart | Village |
| P03 | Knowledge orchard | Linked notes become paths between trees | A fixed sample corpus, selectable connections, actual Markdown examples | Town |
| P04 | Release time machine | Slide between dated versions of a workshop | Hand-curated public snapshots and a readable change comparison | Town |
| P05 | Repair café / failure museum | Reproduce a bug, then see the fix | One verified bug story, isolated toy reproduction, link to the change | Town |
| P06 | Night Market (city plan F24; earlier “MCP night market”) | Connect a mock tool to a stall and see the request path | Read-only sample inputs and recorded/fixture outputs; no visitor credentials | Town |
| P07 | Build a bridge challenge | A path becomes connected after one clever placement | Tile adjacency, route validation, three short authored scenarios | Town |
| P08 | Bottleneck glasses | Toggle an overlay and understand a busy district | Queue length / latency / dependencies from simulation state, labelled units | Town |
| P09 | Monsoon afternoon | Gutters fill, umbrellas open, puddles reflect the lamps | Cosmetic weather first; optional drainage puzzle on a bounded grid later | Town → City |
| P10 | Paper-to-village workshop | A photographed cardboard object becomes a landmark | Founder-operated capture, offline cleanup, reviewed asset import | Town |
| P11 | A city of little explanations | Walk from one concept into a connected scenario | Shared toy scenario contracts; independently loadable exhibits | City |
| P12 | The midnight debugging train | Follow a broken delivery through several stations | Scripted cooperative scenario with checkpoints and an explanation at each stop | City |

The release time machine requires an actual archive. The failure museum
requires a real story. Neither should be filled with invented founder anecdotes.

## Multiplayer that gives people something to do

| ID | Activity | Shared action | What must exist first | Horizon |
| --- | --- | --- | --- | --- |
| M01 | Build a courtyard together | 2–8 registered people place a small kit on one plot | Room authority, edit permissions, conflict handling, reconnect, persistence | Village prototype |
| M02 | Guided city walk | A host selects a stop; people can follow or explore | Room presence, destination sync, captions, independent camera opt-out | Town |
| M03 | Review-yard co-op | One person routes deliveries; another handles the gate | Authoritative shared scenario, role handoff, a reset everyone understands | Town |
| M04 | Community build day | Several small rooms design neighbourhood blueprints | Room limits, hosts, moderation controls, durable exports; real scheduled event | Town |
| M05 | Blueprint exhibition | Creators submit finished plots for a public showcase | Consent, review queue, attribution, rollback, removal and retention rules | Town → City |
| M06 | Connected neighbourhoods | Travel between independently hosted districts | Interest management, room handoff, compatible manifests, capacity evidence | City |

Comments, messages and assemblies are a critical part of the experience
(RD05). Text between people is therefore core to this catalogue, not something
to add after emotes and invite rooms have proved themselves, which is what an
earlier draft of this paragraph recommended. A registered person can comment
on an exhibit, message another person or a project room, and take a seat in an
assembly. Public visitors observe and do not take part (RD03); what a
registered person may say to an agent follows tier and granted authority
(RD04). The proposed civic home for messages is the Supermessage Post Office
(city plan F25), and for assemblies the Square and the town hall (F13).

| ID | Activity | Shared action | What must exist first | Horizon |
| --- | --- | --- | --- | --- |
| M07 | Comments | Leave an attributable comment on an exhibit, story or proposal | Registered identity, reporting, moderation queue, edit/removal and retention rules | Village |
| M08 | Messages | Write to a person, a project room or a club | Consent and blocking, room membership, reporting, retention and export | Village |
| M09 | Assemblies | Gather to discuss a proposal, a project review or a festival plan | Host and moderator roles, agenda, speaking order, captions or text-first format, a record of outcomes | Village → Town |

Hosting people's text carries a load that is an open consequence of RD05 and
has to be answered, not a reason to defer the feature: moderation capacity
for a solo-founder lab, reporting and appeals, retention, the age scope of
participants, and the legal duties of hosting user text in each market of a
global product (RD11). The [community charter](COMMUNITY_CHARTER.md) holds the
current proposals. Voice and arbitrary uploads remain separate additions with
their own burden. Emotes, pings and invite rooms are still useful; they
accompany text and do not replace it. Presence must distinguish actual
connected people from decorative NPCs.

## Residency and lifestyle

These extend Rakesh's resident idea. A one-time payment buys a block for a
house and makes the buyer a resident (RD09). Sponsorship is separate: a
sponsor funds the lab and its product development and may receive residency
among the perks (RD10). Resident tiers can be a subscription or a one-time
purchase and can include credits; credits can also be earned or bought, and
they pay for facility access, items, compute and storage (RD07, RD08). The
[residency brief](../gameplay/RESIDENCY.md) contains the proposed rules; exact
prices, thresholds, and contributor entry remain open.

**Two numbering schemes look alike.** R01–R05 below are feature IDs in this
catalogue. R1–R4, without the zero, are the rungs of the residency ladder in
the residency brief (starter home, cottage life, courtyard life, garden
house). R01 is not rung R1. Neither set is renumbered, because other documents
refer to both.

| ID | Feature | Visitor/resident value | Technical requirement | Horizon |
| --- | --- | --- | --- | --- |
| R01 | Move into the village | Someone who buys residency (RD09), or a sponsor whose perks include it (RD10), receives a block, a starter home and a persistent address | Linked identity, verified purchase or qualification, unique plot claim, privacy choice | Residency pilot; timing open |
| R02 | Evolving lifestyle | Cottage, courtyard, and garden-house styles; interiors, pets, furnishings, vehicle appearances | Versioned milestone rules and unlock grants; bounded asset kits | Pilot → Town |
| R03 | Contribution task board | Help through code, art, writing, accessibility, or community work and receive recognition | Scoped tasks, evidence, review, deduplication, clear reward | Pilot → Town |
| R04 | Open houses and neighbourhood projects | Visit a resident's creation or help complete a shared amenity | Host permissions, opt-in directory, publication review, verified milestones | Town |
| R05 | Welcome back | Resume a saved home after a subscription tier lapses or a long absence | Separate earned unlocks from expiring service allowances; tested restore/export | Residency pilot |

Optional [world-model ideas](../research/WORLD_MODELS.md) extend this catalogue
with dream districts, library portals, project pitch worlds and learned-agent
experiments. They remain research possibilities behind the same vision and
tooling gates; they do not add an adopted engine or production service.

## Three proposed experience prototypes

These are future experience concepts. The repository's existing
[atlas](../../prototypes/atlas.html), [city systems lab](../../prototypes/city-lab.html)
and [economy lab](../../prototypes/economy-lab.html) are narrower local planning
illustrations, not implemented versions of the three experiences below.

### A. Jackfruit Courtyard

An 8×8 plot offers path, lawn, tree, bench, workshop, and veranda pieces. The
first experiment uses a snapped grid; buildings can later add procedural edge
details inspired by Townscaper and Tiny Glade. People should enjoy the feedback
before we invest in a large procedural architecture system.

In multiplayer, a guest proposes a placement and sees a translucent preview.
The server checks the plot, edit role, occupancy, and expected revision. It
accepts one result and broadcasts it. A conflicting placement gets a friendly
explanation and a refreshed preview. Undo targets the author's accepted edit
and succeeds only if it will not overwrite a later dependent edit.

**Learn:** can two people make something they want to keep in ten minutes?

### B. Delivery and Review Yard

Tasks arrive at a configurable rate and move through queued → working → review
→ done. Separate controls change worker count, work duration, review capacity,
and rework. Tokens pause at the gate; a DOM chart shows the queue and completed
tasks. These are invented scenario values, never live product telemetry.

A first version could be a discrete simulation at 5–10 updates per second,
with seeded randomness and interpolated visuals. In solo mode it would run
locally; in co-op the room would own it. This is a sketch of behaviour, not a
technology choice (RD15). A simple reproducible example should expose the
bottleneck without pretending to benchmark SJL's tools.

**Learn:** can a visitor explain why adding workers eventually stops helping?

### C. A Workshop from the Real World

Rakesh photographs a small cardboard workshop or jackfruit ornament. Try an
existing free kit, authored modelling, photogrammetry, and hosted image-to-3D
against the same visual brief. Compare total cleanup time and final web cost.
Import the chosen result as a single reviewed landmark; retain its provenance.

The camera-to-Blender repository can accelerate capture/import. It does not
replace retopology, material cleanup, collision geometry, export, or validation.
See [the asset pipeline and free options](../architecture/TOOLS.md).

**Learn:** which workflow produces a recognisable, stylistically consistent
asset most cheaply, including the founder's time?

## How these features help makers build

This applies to any project in the city. For an SJL product the maintainer is
the lab; for an independent project it is that project's own maintainer, who
decides whether to take part at all.

An exhibit begins with a real problem from a project's current work. Its
explanation links to a rehearsed real workflow. A registered person can report
where they got stuck or which capability they need. That observation goes to
the project's maintainers and may become a change to the project, a clearer
guide, or a different experiment. For the lab's own products it feeds the
active marketing/product cycle review. Because the city prefers to run on SJL's
products (RD02), daily use of the city's facilities is itself a source of
such observations for AgentPod, Superpipeline, SuperMD and Supermessage.

Track these separately: exhibit opened, simulation used, source visited,
real workflow attempted, and feedback received. Time spent decorating
a plot is not evidence that anyone adopted a product or a project. Collect the smallest useful set
of events, and provide a way to use the village without analytics.
