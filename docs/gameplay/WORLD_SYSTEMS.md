# The full village-to-city gameplay vision

Complete idea inventory · 2026-09-18 · [Mechanics](MECHANICS.md)

Rakesh asked to preserve **all** the ideas, including larger systems initially
identified as later experiments. This document develops those extensions.
Release order is a dependency decision, not a reduction of the intended vision.
Nothing here is a shipped feature, funded commitment or approved real-money price.
The first slice is RD01, observing the Guild at work
([decision register](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18));
every system here comes after it. Comments, messages and assemblies are core
(RD05), so the clubs, hearings and gatherings below assume text communication
from the start rather than deferring it.

The thirteen GM IDs match [the mechanic contracts](MECHANICS.md). Evidence and
inspiration live in [the research record](../research/GAMEPLAY_MECHANICS.md).
The extensions below are SJL design proposals; cited games do not establish
that these exact combinations exist or will work for our community.

## GM01 — Careers, mastery and apprenticeships

A gardener can progress from arranging a small bed to planning an orchard's
irrigation. A builder can specialize in verandas, public structures or reuse of
old buildings. A courier can learn routing, fragile cargo handling and festival
logistics. A librarian can curate collections, run reading circles and mentor
research; a mechanic can diagnose pumps and maintain transit equipment.

Build branching knowledge through completed projects and practical challenges.
Allow multiple careers and reversible specialization choices. Mastery gives
new methods, recipes and creative expression, with bounded efficiency effects
only after balance testing. A late-arriving player must still have useful work.

Mentorship can pair people, a fictional instructor or a permitted agent. A
learner sees a worked example, attempts a task and gets evidence-based feedback.
A guild or school can publish a course path and recognize a completed project.
These are game achievements, not accredited qualifications or assertions about
someone's real competence. Paid tiers do not buy professional certification.

**Large-system dependencies:** versioned skill/recipe graphs, challenge evidence,
mentor permissions, accessible assessment variants and reward-abuse review.

## GM02 — Public works from drawing board to opening day

Grow from a garden into a library wing, footbridge, fire station, tram route or
stadium. Projects combine design alternatives, site surveys, funding, procurement,
deliveries, construction, inspection, opening and ongoing maintenance.

Blueprint competitions can produce several previews against the same brief.
Residents compare cost, access and environmental effects before a steward
accepts a design. A selected blueprint becomes a bill of materials and staged
work packages. Contributors choose a short task or a sustained role; async
handoffs let different time zones share ownership of progress.

Support subcontracting, approved change orders, phase budgets, temporary
closures, emergency access and staged public use. A delayed roof should not
block a completed safe path. Retrofitting a building preserves its history and
contributors while recording the new design and maintenance responsibility.

**Large-system dependencies:** project graph scheduling, versioned cost quotes,
escrow and inventory custody, bounded work permissions, change approval,
inspection rules and compensation when a project is cancelled. Contractor
absence must be recoverable without losing accepted work.

## GM03 — Districts with character and competing needs

An orchard quarter can emphasize shade, quiet routes and garden workshops.
A maker street can have deliveries, repair shops, shared equipment and evening
activity. A waterfront can combine ferry access, markets and flood management.
A learning district can connect schools, libraries and public research spaces.

Character emerges from land use, opening hours, building form, terrain, shade,
noise, transport and actual programmes. Show the components rather than hiding
everything in a prestige number. Residents can choose different aesthetics
without buying the city's objectively best neighbourhood.

Enable mixed-use buildings, public courtyards, temporary pedestrian streets,
heritage restoration and accessibility upgrades. Redevelopment proposals show
who loses a route, service or booked venue before approval. Do not force a
resident's saved home to move because someone else purchased a larger plot.

**Large-system dependencies:** district overlays, routing and service coverage,
prospective planning permissions, public/private plot boundaries, relocation
consent and versioned neighbourhood manifests.

## GM04 — A functioning fictional population

NPC households have schedules, employment, shopping, education and leisure
preferences. A few named citizens provide readable stories; distant populations
can remain cohorts. A teacher's after-school timetable, a shop's delivery window
and an elder's short walking route can reveal different planning problems.

Needs generate bounded requests: a missed tram connection, a recurring queue,
an inaccessible route or a shortage of repair capacity. Requests can combine
into civic programmes instead of repeating the same quest forever. Citizens
change routines when a service closes or another route becomes available.

Later, fictional households can move, graduate, change jobs and form authored
family stories. Those records are world entities, not profiles inferred from
real visitors. Growth depends on service capacity, housing and resources, with
clearly labelled fictional population. Do not equate NPC growth with SJL users.

**Large-system dependencies:** household/cohort state, activity selection,
finite demand budgets, migration rules, request arbitration and observable
explanations. Begin with authored state machines; larger LLM populations need
a separate measured experiment and are not the baseline simulation engine.

## GM05 — Relationships, clubs and shared memory

Develop NPC acquaintances through named shared experiences: restoring a garden,
helping at a festival or finding a missing catalogue entry. Dialogue can recall
the place and event rather than merely count gifts. NPC relationships can open
story branches and invitations without making absence a punishment.

Human neighbours can create reading clubs, building circles, sports teams and
co-ops. Shared calendars, guest permissions, postcards, commemorative furniture
and opt-in project plaques make those relationships visible. Housewarmings,
opening ceremonies and seasonal reunions provide occasions to gather. Comments
on shared work, direct messages and assemblies are core to all of this (RD05);
moderation, reporting, retention and age scope are open in the
[community charter](../vision/COMMUNITY_CHARTER.md).

A resident's passport can retain project milestones, discovered places and
chosen mementos. The city archive can show how a square changed across years.
Players choose what becomes public, and corrections propagate to later views.
Do not turn private conversation histories into automatic public biographies.

**Large-system dependencies:** identity/consent, group roles, invitation and
blocking controls, bounded memory references, publication policy, archive
retention and account-deletion behavior.

## GM06 — Ecology, weather and a circular resource economy

Extend the garden model into connected water storage, drainage, irrigation,
soil health, tree canopy, compost, crop seasons, waste sorting and pollution.
A workshop can consume power and materials while producing useful goods and
waste. A recycling cooperative can return approved materials to production.

Monsoon rehearsals test drains, bridges and retention ponds. Dry-season
scenarios test reserves and irrigation choices. Trees shade paths and gardens;
impermeable surfaces change runoff. Compare immediate output against future
maintenance and environmental recovery, with visible delays and units.

Add seed collections, orchards, community farms, habitat corridors and authored
wildlife encounters. Ecological diversity can create interesting choices rather
than a single optimal crop. More complex fluids, terrain deformation and
watershed models remain possible extensions after the simple rules are proven.

**Large-system dependencies:** conservation budgets, bounded spatial simulation,
season clocks, material provenance, predictable degradation and scenario
restoration. Public-city setbacks should reduce simulated performance or offer
repair work; destructive survival worlds require explicit opt-in rules.

## GM07 — Expeditions, mysteries and discovery

Create a ring of explorable places: an abandoned tram line, a disused pumping
station, an orchard island, a hill observatory and a workshop archive. Each
expedition has a question and tools that help answer it—surveying routes,
tracing signals, reading diagrams or identifying plant conditions.

Cooperative roles can split observation, navigation and repair. Small authored
puzzles lead to a route, seed variety, architectural style, music fragment or
recipe. A field notebook records clues and connections; hints remain available
without purchase. Secrets can change with scenario weather or a restored link.

Eventually assemble replayable trips from reviewed scenario modules, with
seeded variants and compatibility checks. Knowledge unlocks new possibilities;
returning should not require farming identical loot. A travelling museum can
show discoveries without claiming fictional ruins are real SJL history.

**Large-system dependencies:** clue/quest graphs, content tools, instances,
checkpoints, accessible puzzle variants, reward provenance and safe return of
validated discoveries to the main city. No arbitrary offline inventory import.

## GM08 — A school and laboratory that invent things

Public research can combine a question, shared materials, experiments, measured
results and a reusable recipe. Try shade layouts, irrigation controls, delivery
schedules, seating arrangements or materials with different maintenance costs.

A research programme can have branches: one team improves water efficiency,
another access, another construction cost. Publish the tradeoff, simulation
version and conditions, then let others reproduce or challenge the result.
Failed experiments produce useful explanation, not automatic failure debt.

Allow collaborative textbooks, reviewed lesson kits and reusable blueprints.
Researchers receive attribution and optional funded work rewards; a public
recipe benefits later visitors. In-world learning can point to real SJL
software, but passing a fictional experiment is not evidence of product use.

**Large-system dependencies:** controlled scenario forks, reproducible seeds,
metric definitions, recipe compatibility, knowledge grants, review workflow
and a catalogue that separates fictional experiments from real technical guides.

## GM09 — Programmable civic services

Grow condition/action cards into reusable bounded workflows: request supplies,
schedule a garden watering cycle, prepare a room for a reading group, or open
an overflow desk when staffed capacity and budget permit.

Provide sensor panels, visual rules, parameters, dry runs, trace inspection,
version history and a pause control. People can share templates with examples
and a manifest of the permissions, quotas and resources they require. A broken
workflow becomes a useful repair challenge in the failure museum.

Advanced workshops can teach queues, retries, idempotency and human review
through these systems. A real AgentPod action is a separately permissioned
extension: a game rule cannot acquire an operator credential by being installed
in a public building. Arbitrary executable mods need an independent design.

**Large-system dependencies:** validated rule language, execution/fan-out bounds,
loop detection or bounded cycles, trigger deduplication, runtime capability
checks, cost reservations and replay that never repeats external effects.

## GM10 — Government, elections and civic responsibility

Begin with reviewable charters, but preserve the larger possibility: district
councils, elected offices, a public treasury, participatory budgets, hearings,
policy terms and accountable project stewards.

A transport steward proposes a route, an environmental steward reviews runoff,
and a budget steward allocates a reserved project fund. Responsibilities can
be divided so one absent person cannot stall the whole city. Roles have scopes,
terms, delegates and recorded decisions. Citizens can compare policy scenarios
before a proposal takes effect.

Election experiments must specify eligibility, identity, nominations, quorum,
voting method, term length, conflicts of interest, inactive-office handling,
appeals and rollback. None is silently selected by this document. A quiet-hours
charter should have an expiry/review date and a defined relationship to other
rules. A proposal cannot retrospectively rewrite settled taxes or purchases.

**Large-system dependencies:** auditable roles and policy versions, overlap
resolution, budget authority, public explanations and abuse-resistant voting.
Game government controls simulated civic policy; human moderation, real
payments, legal obligations and lab administration remain separate authority.
A higher tier or a lab sponsorship (RD10) does not purchase votes or civic
office.

## GM11 — Work beside real agents

Expand the fixture apprenticeship into a place where a resident can inspect
an approved agent role, understand its current verified state, propose a task,
review a plan, give bounded approval and inspect the result.

Possible activities include comparing a garden proposal, curating permitted
public notes, explaining a code example or drafting a festival programme.
Multi-step work can require a researcher, designer and reviewer, with explicit
handoffs and a human stop point. The city can show a permitted outcome in a
workshop or library only after publication review.

A tutoring mode can compare the resident's reasoning with a worked example.
A debugging lab can replay recorded failures without executing them. Personality
and licensed voices add expression but cannot change what the agent may do.
An AI memory experiment is optional and must keep privacy, cost and factual
reliability visible; the research paper is not evidence of deployment readiness.

Anonymous visitors only observe (RD03); the resident activities here start at a
registered account and widen by tier and authority (RD04), paid in credits
(RD08). A resident's own personal agents stay private unless shared (RD12).

**Large-system dependencies:** the proposed city-to-AgentPod adapter and verified product grants,
source freshness, private/public audience boundaries, task/usage reservations,
approval scope, cancellation, reconciliation and evidence-based completion.
No simulation population count implies that many real agents are connected.

## GM12 — Newspaper, radio and the city archive

Start with one factual completion notice. Grow into district editions, service
bulletins, project timelines, resident-submitted photographs, event listings
and a searchable history of public decisions.

A local radio presentation could read approved notices with captions and
voice-off parity. A city timeline can compare historical layouts and trace a
bridge's repairs. An exhibit can show predicted policy effects alongside later
observations. Editorial games might ask players to verify a simulation claim
against its underlying events before publishing a story.

Every factual item needs provenance and a correction path. Keep fictional NPC
news, opted-in human achievements and real lab releases distinct. A language
model may assist draft wording, but it must not manufacture attendance, agent
work, founder anecdotes or a payment. Publication is an explicit action.

**Large-system dependencies:** event projections, source/rule versions,
editorial permissions, consent, deduplication, corrections, retention and
accessible text/audio delivery. These systems do not authorize external posts.

## GM13 — A world connected by travelling projects

A reading cart can grow into a mobile library, repair café, theatre, maker
exhibition, seed exchange or festival circuit. Districts prepare venues, offer
local work, contribute a chapter or exhibit and hand the programme onward.

Route choice affects travel cost, access and preparation time. Hosts reserve
space, power and staff; participants can help before or after the main event.
A delayed stop can reschedule or use an alternate host without losing the
vehicle, collection or later bookings. A travelling collection carries a
history of additions, with attribution and reviewed content rights.

Seasonal circuits can connect expeditions, professions and research: bring an
orchard discovery to the school, build its exhibit in a workshop, then share
it at a neighbourhood festival. Keep ordinary public access available and
avoid requiring attendance in a single timezone to earn core progression.

**Large-system dependencies:** itinerary planning, bookings, capacity, inventory
custody, transport, host permissions, fallback routing and exact-once handoff.
Real ticketing or funded access follows the existing Razorpay/economy rules;
paid entry with a reward is not offered until reviewed
([Economy](ECONOMY.md#open-questions-the-decisions-create)).

## Connected larger loops

| Long-form loop | Mechanics combined | Outcome to preserve |
| --- | --- | --- |
| Restore the old tram line | Careers, public works, expeditions, charters, newspaper | A working accessible connection with an attributable history |
| Prepare for monsoon season | Ecology, research, automation, public works | Tested drainage and response plans; observable causes when they fail |
| Open a learning district | Professions, NPC needs, schools/labs, agents, clubs | Useful activities and fictional education capacity that can be inspected |
| Run a festival circuit | Travelling projects, logistics, businesses, civic funding | Several neighbourhoods share a programme with recoverable bookings |
| Renew a neighbourhood | Character, resident consent, government, construction | Improved services while preserving homes and community memory |

The economic extensions already captured in [Economy](ECONOMY.md)—shops,
supply chains, procurement, co-ops, escrow, time banks, scholarships, optional
insurance/JC loans, trade and district specialties—remain part of this vision.
They are not discarded because the first building loop uses only a small
reward pool. Credits can now be bought and buy real things (RD07/RD08), which
changes the stakes of every economic extension here; the consequences are
listed as open questions in [Economy](ECONOMY.md#open-questions-the-decisions-create).

## From full vision to implementation

The first slice (RD01) is observation, not a mechanic; the first building
scenario after it is a test of the underlying contracts, not a cap on scope.
Use its findings to choose the next connected loop. No engine, room server or
database is chosen by any of this (RD15). Each larger system needs
an explicit owner, content-authoring path, authority model, persistence and
recovery story, and observed player value before its implementation expands.

Keep the [mechanic contracts](MECHANICS.md), [economy](ECONOMY.md),
[civic simulation](CIVIC_SIMULATION.md) and [roadmap](../planning/ROADMAP.md)
consistent. Prices, elections, destructive scenarios and paid compute are
policy choices still to be made; recording the ideas does not activate them.
