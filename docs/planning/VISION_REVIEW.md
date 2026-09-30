# Review the complete planning draft

Five planning milestones developed · 2026-09-16, updated 2026-09-18 · [Master plan](../vision/MASTER_PLAN.md)

The next planning milestones are now documented as a connected proposal.
**Draft completion is not vision approval or implementation readiness.** The
open maker-city direction is chosen; the policy defaults below still need
Rakesh's judgement. No game, payment flow, account service or deployment was
implemented in this pass.

**Update 2026-09-18.** A [gap review](GAP_REVIEW_2026-09-18.md) of this draft
led to seventeen [recorded decisions](VISION_DECISIONS.md#decisions-recorded-on-2026-09-18).
They settle the first slice (watch the Guild at work), access levels (public
observes, registered users interact), credits (earned, bought or included with
a tier; they buy real services), residency purchase, sponsorship as a separate
thing, a global market, private personal agents, Forgejo on the lab server and a
deferral of every technology choice. The bundles below are read against those
decisions: bundle A's "sponsor-only" alternative and bundle B's cash-credit
tradeoff are now decided (RD09/RD10, RD07); bundle F's "no automatic top-up"
stance meets RD08, under which credits buy compute and storage. What remains
open is listed in the gap review.

## Read in this order

The [mechanics discussion agenda](MECHANICS_AGENDA.md) records fourteen topics
to resolve after the visual and asset-catalogue exploration, with links to
existing proposals and cross-cutting questions about permissions, consequences,
devices and persistence. Its suggested discussion order does not change RD01.

| Milestone | What is now concrete | Design document |
| --- | --- | --- |
| 1. People's journeys | Nine end-to-end stories: visitor, creator, resident, SJL contributor, private team, steward, nontechnical maker, exit and festival | [People and daily life](../vision/PEOPLE_AND_DAILY_LIFE.md) |
| 2. City and institutions | Ten districts, labelled vector map, village/town/city forms, 25 facilities (F24 Night Market and F25 Post Office added 2026-09-18) with access, owners, capacity units, funding and closure | [City plan](../vision/CITY_PLAN.md), [map](../vision/assets/open-maker-city.svg) |
| 3. Ownership, access and funding | Twelve proposed operating policies, alternatives and worked accounting examples | [Operating model](../vision/OPERATING_MODEL.md) |
| 4. Community rules | Ten proposed policies covering participation, discovery, rights, moderation, appeals, government and staffing | [Community charter](../vision/COMMUNITY_CHARTER.md) |
| 5. Complete system map | Fifteen logical responsibilities, SJL product contracts, shared records, end-to-end flows and failure behaviour | [City systems](../architecture/CITY_SYSTEMS.md) |

## The proposed city in one visit

Enter through a project page or the Square. Choose to explore, play, learn,
contribute or bring your own work. Useful public activities remain free.
A free creator can own an independent project and recruit collaborators. A
resident also has a home and lifestyle progression. Teams choose tools and
request separately funded compute when useful. Reviewed work can become an
exhibit, lesson or city event with permission. Public services give the city
shared needs, budgets, recreation and a reason to grow.

SJL is the founding institution and an active maker within this world. Its
products power useful work without determining who may belong. Real projects,
fictional civic systems and personal progress reinforce each other through
explicit reviewed connections, while each keeps its own authority and records.

## Cross-system scenario review

These are analytical walkthroughs of the draft, not executed software tests or
observed user sessions. They show whether each case has a defined outcome.

| Case | Situation | Draft's outcome and accountable rule |
| --- | --- | --- |
| C01 | Free maker requests an exhibit | Account creates a draft; curator checks public fields/licences; free listing and rotation remain available. OP01, CC03, SYS02/03 |
| C02 | Non-resident wants to improve SuperMD | Ordinary contribution path or scoped city task; maintainer review decides acceptance. J04, OP09, SYS12 |
| C03 | Sponsor stops paying | Lasting home/unlocks remain; period service allowances expire without a surprise charge. J03, OP03, SYS07 |
| C04 | Team exhausts agent allowance | No new dispatch; running task stops/checkpoints under its cap, preserves permitted results and reconciles unused reservation. J05, OP06, SYS08 |
| C05 | Maintainer rejects a contribution | Task remains unaccepted with a reason; no forced merge or automatic promised reward; unrelated residency is unchanged. J04, CC02 |
| C06 | Public exhibit fronts a private project | Only approved revisions appear publicly; membership checks apply to each backing service. OP09, SYS01/02/10 |
| C07 | Project owner leaves | Export, transfer or archive with separate service cancellation; no automatic SJL ownership. J08, OP10 |
| C08 | Facility sponsor disappears | Stop new unfunded capacity; honour/compensate commitments; retain public material and creations. OP07, facility catalogue |
| C09 | Festival draws more people than expected | Actual capacity controls admission; overflow/waitlist/reschedule, distinct from NPC crowds. J09, SYS09 |
| C10 | Fictional fire/power failure occurs | Simulated consequences and recovery; no tier-gated emergency response or deletion of real work. F14–F17, SYS05 |
| C11 | Paid sponsor violates conduct rules | Same moderation and appeal process; sponsorship grants no exemption. CC02/05/06 |
| C12 | Small community cannot staff every institution | Shared facilities, capped submissions/events, honest review queues and fewer commitments. J06, CC08 |
| C13 | Duplicate payment/task/publication event arrives | Business-event deduplication or reconciliation; no duplicate home, job or public story. SYS07/08/12/13 |
| C14 | City vote affects budgets | Only scoped prospective game policy; no real charges, repository authority or private-data access. CC07, SYS06/11 |

Arithmetic checks cover the draft tax example (400 gross, 30 tax, 370 net),
conservation across the three accounts (3,500 JC), and the normalised operating
allocation (100 units and its 80-unit constrained case). These confirm the
examples are internally consistent; they do not validate an economy or price.

## How the earlier questions are answered

The original VD IDs remain the decision register. This table locates developed
answers rather than treating the recommendations as user approvals.

| Decision | Developed answer |
| --- | --- |
| VD01 Audience | J01/J02/J07 and CC01 include makers, learners, players and nontechnical work |
| VD02 Outside exhibits | J02, OP01 and CC03 define free drafting, review and fair discovery |
| VD03 Free contribution | J04 and OP02 separate project access from contribution-earned residency |
| VD04 SJL participation | J04 and SYS12 preserve maintainer/source authority |
| VD05 Independent teams | J02/J05 and SYS02/08 define membership, private work and execution |
| VD06 Ownership | OP09, CC04 and J08 separate display, project rights and exit |
| VD07 Private projects | OP09 and SYS10 support public fronts and private rooms/material |
| VD08 Tool choice | SYS12 and the ecosystem map preserve external tools and direct links |
| VD09 Hosting | OP06/11 and SYS08 distinguish a project address from managed execution |
| VD10 Agent access | J05 and OP06 define demo, learning, project-funded and approved external-runner modes |
| VD11 Residency value | J03 and OP02/03 define entry, lasting creative benefits and expiring services |
| VD12 Money and authority | CC06/07 keep project, operator and civic powers separate |
| VD13 Real work and world | OP12 and SYS13 connect accepted results to consented recognition |
| VD14 Leisure | J01/J03/J09, F10–F12 and CC10 support life without required lab work |
| VD15 Growth | District growth forms and facility approval require purpose, operators and both budgets |
| VD16 World shape | City plan and SYS04 propose shared public geography with scoped instances |
| VD17 Discovery | F01/F03, OP08 and CC03 define directory, rotation, curation and sponsorship labels |
| VD18 Government | CC05–CC08 define operator responsibility, stewards, appeals and later bounded elections |
| VD19 Leaving | J08 and OP10 provide export, transfer, archiving and proposed retention periods |
| VD20 Recognition | OP12 and CC08 require accepted evidence and avoid activity-count incentives |
| VD21 Funding | OP04–OP07/11 distinguish JC, actual operating money and optional commercial services |
| VD22 Creator extensions | F23, CC04 and SYS14 define drafts, review, rights, versions and rollback |
| VD23 Quiet periods | J01/J03, daily rhythm and CC10 provide solo value and asynchronous participation |
| VD24 Accessibility | Direct-entry routes, calm mode, captions and keyboard paths throughout journeys and city plan |

## Decisions to review together

| Bundle | Recommended package | Material alternative/tradeoff |
| --- | --- | --- |
| A — Belonging | Free creation/contribution; sponsorship or reviewed contribution grants residency | Sponsor-only residency simplifies funding but narrows the route to a home |
| B — Progress and money | Lasting lifestyle unlocks; earned JC; separate bounded service allowances | Cash JC packs or monthly lifestyle rental introduce different balance, refund and retention rules |
| C — Homes and continuity | Stable addresses and instanced plots; no speculative land; inactivity archives rather than confiscates | Scarce fully contiguous housing requires explicit land supply and relocation rules |
| D — Community scope | Adult hosted participation initially; transparent moderation coverage and curated publication | A youth/family city requires a separately staffed and designed participation model |
| E — Civic power | Consultative village, later one-person civic franchise with non-financial qualification | Immediate elections add identity, staffing and small-population governance problems |
| F — Useful compute | Bounded demos, funded learning sessions and explicit project budgets; no automatic top-up | General hosting/creator commerce would add a separately operated service business |
| G — World character | Tropical mixed-use maker settlement with useful quiet periods and optional scheduled gatherings | A primarily event-driven campus or simulation-first world would change daily journeys |

Draft numerical constants—tax example, fiscal period, voting eligibility/quorum,
term lengths and archive/deletion windows—are review inputs. Actual prices,
resource quotas, server capacity and recovery objectives need later operational
evidence; they have not been guessed into live promises.

## Subsequent tools and world-model planning

The five milestones are planning drafts, not a frozen scope or approval.
Review TD01–TD08 in the [decision register](VISION_DECISIONS.md) alongside
the packages above: conventional currency, mandatory CLI/MCP coverage,
Forgejo/Superpipeline authority, external tools, city authoring tools, hosting,
readiness evidence and optional AI world models. See the
[tool strategy](../architecture/TOOLS.md), [world-model research](../research/WORLD_MODELS.md)
and [consistency review](REPOSITORY_REVIEW.md).

Additional review cases:

- A free project founder buys their first qualifying residency offer. Account
  binding precedes checkout; verified fulfilment adds residency once.
- A free contributor receives a project task grant and a funded budget.
  Residency is not required, and revocation ends the permitted work.
- A promising tool has only a documentation MCP. It remains a candidate until
  its required operational CLI/MCP workflow passes admission.
- A generated dream district proposes a beautiful new library. It remains a
  draft; city review must separately accept geometry, services and funding.
- The lab server is rebuilt from scratch, as a lab may be. Production city data
  must not be placed there until the hosting-role and recovery decision is
  resolved.

These are consistency walkthroughs for discussion, not executed integration tests.

## What is complete and what remains

The [Guild resident design pass](../vision/GUILD_RESIDENTS.md) now covers all
fourteen founding agents, with proposed homes, public roles, encounters,
permissions, funding and collaboration scenarios. Review its character and
service choices alongside bundles A, F and G; a completed roster draft is
neither role approval nor live service capacity.

**Complete as planning drafts:** all five milestones, the labelled concept map,
the service catalogue, recommendation packages and scenario walkthroughs. The
full thirteen-mechanic vision and larger experiments remain in the source briefs.

**Remaining planning work:** the [open items](GAP_REVIEW_2026-09-18.md#still-open-after-the-decisions)
after the 2026-09-18 decisions, in particular success and stop signals, the
public work-state contract, the relation between public characters and the
working agents, untrusted input, the legal and economic character of
purchasable credits, the selling entity and licence, and the name. Further visual alternatives or story detail can be developed within
planning as needed. Product terms and operational measurements are separate
readiness work, not claims of an already-running service.

**Implementation remains unstarted.** The VISION gate stays open until the
intended experience and major tradeoffs are agreed, followed by an explicit
decision to build. A completed draft does not advance that gate automatically.
