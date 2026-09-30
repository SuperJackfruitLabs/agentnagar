# Visitors, residents, and life in the village

Proposed design · 2026-09-18 · [Plan index](../README.md)

**A one-time payment buys a block for a house and makes the buyer a resident
(RD09). Tiers, credits and useful contributions help that home, and the life
around it, grow.** This extends the hybrid multiplayer concept with a reason to
belong and return.

Rakesh proposed visitor/resident identities, a plot for residents, and
lifestyle tiers that improve through payment or contribution. On 2026-09-18 he
decided the entry route and separated it from sponsorship; see
[the decisions](#decisions-recorded-on-2026-09-18). The remaining rules below
develop that direction. Names, prices, thresholds, retention terms, and billing
integration are proposals. No residency sale, sponsorship programme or paid
benefit has been launched.

The [operating-model draft](../vision/OPERATING_MODEL.md) develops contributor
entry, lasting lifestyle grants and proposed inactivity/archive rules; it is
being revised for the same decisions. [Daily-life journeys](../vision/PEOPLE_AND_DAILY_LIFE.md)
show payment pauses and leaving in context. Those recommendations still need
Rakesh's decision; the constants are not current account terms.

## Decisions recorded on 2026-09-18

From the [decision register](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18).
These are Rakesh's decisions, not recommendations of this brief.

| ID | Decision | Effect on this brief |
| --- | --- | --- |
| RD09 | A one-time payment buys a block for a house and makes the buyer a resident. | Replaces "sponsor entry" as the purchase route. Contribution-earned residency remains a proposal alongside it |
| RD10 | Sponsorship and residency purchase are different things. Sponsorship funds the lab and its product development and may come with residency and other perks. Someone who only wants a home simply buys residency. | This brief now uses "sponsor" and "sponsorship" only for funding the lab. Earlier text used the word for any payment |
| RD07 | Credits are earned, bought, or included with resident tiers. A tier can be a subscription or a one-time purchase. | Tiers include credits; see [what a tier includes](#what-a-tier-includes-and-for-how-long) |
| RD08 | Credits buy facility access, in-game items, compute and storage. | The separate "service allowance" entitlement is replaced by credits |
| RD11 | The product is global. | Prices, tax treatment and consumer terms are per market and open |

**Still open after RD09/RD10:** what the one-time block price includes (the
land claim only, a starter house, a first credit grant?); for how long the home
is hosted for that one payment, and what happens after; land supply; the tax
treatment of a residency purchase versus a sponsorship; the sponsor perk list;
and refund terms for each.

## Two human identities, several ways to participate

The open maker-city proposal also allows **free signed-in visitors** to submit
project exhibits, contribute to SJL or independent projects and hold project
membership. A project founder need not be a resident. This is an account and
permission model, not a third paid lifestyle tier. See
[Projects and collaboration](../vision/PROJECTS_AND_COLLABORATION.md); the detailed
access and contribution policies remain proposed.

| Identity | What they can do | What they have |
| --- | --- | --- |
| Visitor | Choose an avatar/personality, explore, read, play public games, see published agent work state (anonymous visitors observe only, RD03; a registered account interacts according to tier and authority, RD04), sketch locally, collaborate when invited | Anonymous local blueprints/preferences; a free account adds a saved profile, project records and participation history under the proposed access policy |
| Resident | Everything above, plus claim a saved home on their block, choose a character voice, interact with agents according to tier and authority (RD04), and progress through lifestyle tiers | One persistent block, a saved profile, earned unlocks and the credits their tier includes |

AI agents and simulated citizens also inhabit the city; they are distinct
entity kinds, not additional paid human tiers. See [People and agents](AGENT_CITY.md).

## Public services and resident benefits

The [civic brief](CIVIC_SIMULATION.md) defines parks, recreation centres,
stadiums, library, school, police/fire services, utilities, and their funding.
Public access, resident access, and operating capacity are separate decisions.
Proposed free basics include public reading, park games, open lessons, and basic
safety. Reserved rooms, tutoring, voice generation, and hosted events are paid
for in credits (RD08); a funder may cover admission for everyone.

Keep enduring avatar/home cosmetics separate from things with a recurring real
cost: compute, storage, bookings and voice. The former are lasting unlocks; the
latter are paid in credits as they are used. An R1 resident can choose from a
starter voice set; higher tiers can offer more licensed choices. Personality
choice is available to visitors too. A role walkthrough or a paid tutor session
does not confer private-project or fleet-administration permissions. A higher
tier can improve lifestyle without buying civic office.

Real payments and JC postings use separate ledgers. [Economy](ECONOMY.md)
defines the proposed payment matrix, tax bases, exemptions and game-upgrade
path. Razorpay is selected; credits can be bought (RD07), while prices, tax
rates, quotas and the [questions that opens](ECONOMY.md#open-questions-the-decisions-create)
remain open. No charge of any kind has been activated.

## Entry and qualification

A visitor's local practice plot is different from a resident's persistent home
and village address. The early cooperative prototype remains available for
testing; residency is not a prerequisite for finishing that prototype.

**Purchase entry (RD09):** a verified one-time payment buys a block for a house
and makes the buyer a resident. One purchase qualifies one account for one
block. Open: what the price includes and for how long the home is hosted.

**Sponsorship is a different thing (RD10).** A sponsor funds the lab and its
product development. A sponsorship may come with residency and other perks, but
nobody has to sponsor the lab to get a home, and buying a home is not
sponsoring the lab. Define which sponsorship forms include residency before
publishing either offer. The earlier text here, "every verified qualifying lab
sponsorship grants the starter residency benefit", is superseded by RD09/RD10.

**Contributor entry is a proposal alongside purchase.** Recommended: allow a
documented, reviewed contribution milestone to earn the same starter residency.
The alternative is purchase-only entry, with contributions improving the
lifestyle of existing residents. The former gives people who cannot pay a way
to become neighbours. This recommendation is not a recorded decision from
Rakesh. It carries the same hosting cost as a purchased home with no payment
behind it, so it needs a funded capacity allocation.

## What upgrading a lifestyle could mean

The following is a design ladder, with benefits to prototype before offering
them. A resident can keep a small aesthetic even after unlocking larger homes.

| Stage | Home and plot | Life around the home | Shared possibilities |
| --- | --- | --- | --- |
| Visitor | Local practice sketch | Public walking, driving, exhibits, and events | Visit residents and help on invited plots |
| R1 · Starter home | A small house, a tree, a mailbox, and an address | Choose colours, clothes, a door sign, and starter furnishings | Invite friends into the tested small-room limit |
| R2 · Cottage life | Veranda, richer interiors, garden beds, a workbench | Bicycle/scooter appearances, a pet companion, new furniture sets | Host an open house; display a project or build |
| R3 · Courtyard life | Several rooms around a courtyard, rooftop garden, studio | Custom cart appearance, a greenhouse, more architectural styles | Build with a neighbourhood group; display a reviewed creation |
| R4 · Garden house | A garden pavilion, library/workshop wing, courtyard pond | Elaborate decor, a cinematic arrival, seasonal furnishing collections | Propose a public amenity or host a programme within published capacity limits |

Initial releases should use one bounded plot footprint. Upgrade architecture,
interiors, and furnishing variety first. Later footprint expansion can use
reserved space or a larger plot instance with a preview and explicit move;
it must not overwrite a neighbour's buildings or invalidate saved coordinates.

Vehicle upgrades change appearance and feel within the shared movement budget.
Rooms, pedestrians, building permissions, moderation, product access, and
queue priority follow their own rules. A high lifestyle tier does not grant
control over another person's home or the lab's roadmap.

## Make belonging visible

- **A moving-in moment:** the resident picks a neighbourhood theme, places a
  starter house, and sees a moving cart deliver their first furnishing set.
- **An evolving home:** a tier purchase or accepted contribution adds a
  terrace, a new roof style, a workshop room, or a garden collection. Show the
  unlock and the reason.
- **A passport with a history:** record milestones such as a first accepted
  bug report, a documented build, or a period of verified membership. Display is
  optional and need not reveal money or the funding route.
- **Craft collections:** a contributed tree model unlocks a gardener's set;
  a documentation milestone can unlock a reading nook. Use authored, reviewable
  rewards rather than promising a bespoke asset for every contribution.
- **Neighbourhood projects:** residents and visitors help build a public park,
  tram stop, or library exhibit through scoped community tasks. Publish a
  dated milestone only when the stated funding/work condition is verified.
- **A visitable showcase:** someone can leave a project link or a build story
  in their home. The public version passes the same publication review as
  other visitor-created content.
- **Seasonal open houses:** chosen residents host walks or building sessions.
  These become actual events only when a host and date are confirmed.

Use mixed neighbourhoods where people choose a style or interest. Keep the
square, useful exhibits, public transport, and discovery routes open to
visitors. Residency should add a home and creative expression to that experience.

## How payment and contribution turn into progression

Two workable models:

| Model | Rule | Tradeoff |
| --- | --- | --- |
| Current membership level | Current subscription band plus approved contribution standing selects the lifestyle package | Simple to explain commercially, but a pause needs careful handling of existing homes |
| Earned lifestyle, with credits that follow the payment form | Verified tier purchases and reviewed contributions unlock lasting home/decor choices; anything with a recurring real cost is paid in credits | Better continuity for residents; needs a small grant ledger and explicit rules |

**Recommend the second model.** Keep three separate records:

1. **Residency:** the person has bought (RD09) or earned a block and accepted
   its account/storage terms.
2. **Earned lifestyle:** tier purchases, contribution milestones, and any
   approved mixed milestones produce recorded unlock grants. Both routes can
   advance the same home ladder.
3. **Credit grants:** the credits a tier includes (RD07), recorded with their
   source, amount, period and any expiry, and spent on things with a real cost
   (RD08).

### What a tier includes, and for how long

The briefs disagreed about where service allowances attach. The
[economy payment matrix](ECONOMY.md#what-people-pay-for) said "tier allowance",
this brief's earlier benefits text tied voice and usage limits to R-tiers,
and [People and agents](AGENT_CITY.md#who-sees-and-does-what) gave residents
an "included allowance"; all three attach a recurring benefit to a **lasting**
tier. Elsewhere [Economy](ECONOMY.md#three-balances-with-different-jobs) and
operating-model OP03 made the allowance a **separate expiring plan**. RD07
says credits "come with tier levels" and that a tier is a subscription or a
one-time purchase. Proposed reading, which removes the contradiction:

| Tier form | Lasting part | Credits included |
| --- | --- | --- |
| One-time purchase | The tier's unlocks: styles, kits, features | **One** credit grant, at purchase |
| Subscription | The same unlocks, kept after cancelling | A **recurring** credit grant each paid period, for as long as it is paid |
| Contribution milestone (proposal) | The same unlocks | A one-time grant only if a funded allocation exists |

**Avoid, or decide knowingly:** a lasting tier that carries a recurring credit
grant with no recurring payment. Because credits buy compute and storage
(RD08), that combination is a perpetual real-cost liability funded by one past
payment. The same trap applies to the one-time block under RD09: hosting a home
costs something every month. Open: the hosting period a one-time price covers,
what happens at its end (archive and restore on demand is the current
proposal), whether unused recurring credits roll over or expire, and whether a
one-time tier's credits expire.

Use a versioned milestone table before automating rewards. Each rule names
eligible evidence, the unlock, whether it can repeat, its effective date, and
any combined purchase/contribution requirement. Examples are a verified tier
purchase, a paid subscription period, or completion of an accepted asset
brief. A resident should be able to see their progress and why a grant happened.

Do not price a pull request as a fixed number of dollars. The first version
can issue milestone grants manually, with reasons. A unified point scale is
an optional later presentation, not necessary infrastructure. Playing for
hours, producing commits, or sending more messages does not by itself earn
contribution credit.

No prices or numeric progression thresholds are set here. First estimate
storage/support cost per resident and the founder's contribution-review load.
Publish bounded benefits that the village can already deliver. Paying more can
accelerate the published purchase route without requiring a spending
leaderboard or displaying someone's payment amount.

### Contribution review

| Contribution | Evidence that could earn a milestone | What to avoid |
| --- | --- | --- |
| Code or bug diagnosis | Accepted fix, reproducible useful report, or reviewed investigation | Counting commits, lines of code, or unverified reports |
| Art and buildings | Accepted asset/blueprint meeting style, licence, and performance criteria | Rewarding every raw upload or claiming rights to someone else's asset |
| Writing and localisation | Accepted guide, accessibility improvement, or maintained translation | Word count and unchecked machine-generated submissions |
| Community help | Documented useful onboarding, event facilitation, or approved shared project work | Votes, message volume, referrals, or performative daily activity |
| Village improvements | A scoped task with completion criteria and a reviewed result | Unlimited points for repeatedly placing or deleting scenery |

Offer a small task board with scope and reward stated in advance. One outcome
gets one record, even if it spans many commits. A maintainer accepts or declines
with a reason; larger or ambiguous rewards get a second review when reviewers
are available. Batch reviews to keep the programme feasible for a solo lab.
Routine issue handling stays separate from optional reward claims.

**Open question — which approvals need a person.** Batching keeps the founder's
load bounded, but it makes a solo operator the latency of every reward: a
contributor may wait days for a grant. The same pattern appears where a steward
approves a [blueprint](scenarios/READING_GARDEN.md#play-sequence) or a
[charter](MECHANICS.md#gm10--neighbourhood-charters). Decide which acceptances
can be deterministic (an upstream merge by a project's own maintainer, a
passing automated check against published criteria), which can be delegated to
other maintainers or stewards, and which genuinely need Rakesh. Nothing is
chosen; an automated acceptance that pays credits is also a farming surface
(see [Economy](ECONOMY.md#open-questions-the-decisions-create)).

## Payment pauses and corrections

Recommended policy: preserve earned identity, ordinary home access, buildings,
and cosmetic unlocks when a subscription tier or a sponsorship ends. Stop only
the recurring credit grant, at the end of the paid period and after a clearly
stated grace policy. Credits already granted follow their own expiry rule
(open). Ordinary cancellation is different from a refund or an invalid grant.

For a refund, chargeback, duplicate grant, or reversed contribution decision,
append a correction, show the reason privately, and recompute affected grants.
Preserve the blueprint and offer export. Do not destroy a build to enforce a
benefit change; if an item becomes unavailable, preserve it in the saved design
and provide a reversible display/edit policy.

Inactive neighbourhoods may be archived and restored on demand. Define the
retention window and account-deletion/export behaviour before launch. A saved
home is a service feature; avoid promising perpetual hosting, a unique piece
of scarce real estate, or transferable financial ownership.

## Payment and sponsorship integration

**Razorpay is the selected provider**, confirmed by Rakesh on September 16.
This supersedes the earlier GitHub Sponsors-first proposal. See the
[Razorpay integration plan](../integrations/payments/RAZORPAY.md) for one-time
payments, recurring plans, order verification, subscriptions, refunds and
reconciliation. GitHub identity can still link an account without being the
payment provider. The product is global (RD11); whether Razorpay alone covers
the intended markets is open, see
[payments and credits](../research/PAYMENTS_AND_CREDITS.md).

The city grants residency from verified qualifying payment evidence or an
approved contribution rule; a typed username or checkout-return page is not
proof. Keep one personal home per resident using transactional unique claims.
Organization-funded benefits need a designated beneficiary policy rather than
creating a home for every member. Public sponsor recognition stays optional.

The [economy design](ECONOMY.md) adds an earned-JC upgrade route for existing
residents, alongside tier purchases and contribution milestones. Qualification,
included construction and included credits remain distinct. Prices, thresholds
and contributor entry are still open; no real checkout is active.

Payment receipts, private identity links and reviewer notes remain server-side.
Current grants derive from effective periods and captured payments; correction
records handle refunds and invalid grants without destroying saved designs.

## Data and hosting

Add records for `resident_accounts`, `provider_links`, `support_events`,
`contribution_reviews`, `milestone_rules`, `unlock_grants`,
`service_entitlements`, and `plot_claims`. Use immutable IDs, effective/event
timestamps, grant corrections, and rule versions. Stored provider financial
values use currency plus integer minor units; do not combine currencies without
an explicit conversion policy.

The grant ledger is separate from ephemeral room movement. Keep it in the
chosen durable city store with explicit transaction boundaries, backups and a
restore test; [persistence](../architecture/MULTIPLAYER.md#persistence-and-operations)
distinguishes the full-city database candidate from an isolated room
experiment; no database is chosen (RD15). Load personal plots and interiors on
demand. Empty houses do
not need a continuously running simulation, dedicated container, or GPU.
Lifetime residents are a count of accounts, not simultaneous room capacity.

A public neighbourhood lists only opted-in homes through a paginated directory
or bounded district manifest. Room edit roles remain independent of lifestyle.
Choose a capacity policy before offering hosted gatherings; the previous
2–8-person room target remains a test target, not a paid promise.

## Delivery and validation

1. **Design now:** add the residency preview, benefit ladder, contribution
   alternatives, and pause policy. Keep exact prices/thresholds open.
2. **After the RD01 first slice and a later building slice:** test one
   resident identity, one persistent plot claim, and a reversible manually
   issued starter grant. Simulate tier changes with test
   records before connecting payment data.
3. **Limited pilot:** verify the payment account, link identities,
   implement reconciliation, test pauses/corrections/private purchases,
   and review actual storage and support cost. Start with deliverable benefits.
4. **Expand:** add contribution-grant automation, more lifestyle kits, shared
   amenities, and subscription tiers with recurring credits only after the
   pilot works.

Acceptance cases include duplicate and out-of-order events, missed webhooks,
existing payers linking later, a one-time residency purchase, a sponsorship
that includes residency, effective-dated changes, refunds, contributor-only
eligibility if selected, mixed milestones, two concurrent block claims, private
purchases, organisation sponsorship, revoked room roles, a lapsed subscriber
returning, and restoration from backup.

Open decisions: what the one-time block price includes and the hosting period
it covers; land supply; the sponsor perk list and which sponsorships include
residency; contributor entry route; initial benefit ladder and milestone
thresholds; one-time versus recurring credit grants and their expiry; which
approvals need a person; privacy defaults; retention and grace periods; tax and
refund treatment per market (RD11); Razorpay account capabilities; and which
benefits can be delivered before asking anyone to pay for them.
