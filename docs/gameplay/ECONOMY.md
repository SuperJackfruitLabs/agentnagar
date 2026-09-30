# Earning, spending and building a city together

Game economy proposal · 2026-09-18 · [Plan index](../README.md)

**Make money a playable system with visible consequences.** A resident can
earn credits, furnish a home, run a workshop, pay for utilities, contribute to
public projects and decide between private comfort and shared services. The
city needs budgets, employment, production, prices, maintenance and reserves.

Rakesh requested financial simulation and payment mechanics for tier upgrades,
taxes, public services and related gameplay. This brief develops those systems;
it does not set real prices or activate payments. On 2026-09-18 he decided how
credits enter a wallet and what they buy; the
[next section](#decisions-recorded-on-2026-09-18) records those decisions and
the questions they open. Everything else here remains a proposal.

Try the [economy lab](../../prototypes/economy-lab.html): compare a resident's
spending with the treasury, service capacity and a cottage upgrade. All figures
are invented credits; its cash buttons only demonstrate purchase states.

The [operating model](../vision/OPERATING_MODEL.md) developed a recommended
policy package around earned-only JC and separately budgeted compute (OP04,
OP06). RD07/RD08 supersede those two recommendations; the operating model is
being revised along the same lines. Its worked tax-threshold example is still a
proposal. Examples in this brief and the operating model are separate labelled
scenarios.

**Recorded decision, September 16:** Rakesh discarded blockchain-based currency.
Use a conventional server-authoritative JC ledger; no cryptocurrency, NFT or
crypto-wallet integration is part of the vision. Balanced postings,
append-only corrections, transaction histories and aggregate treasury reports
are the proposed transparency mechanisms.

## Decisions recorded on 2026-09-18

These are Rakesh's decisions from the
[decision register](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18),
not recommendations of this brief.

| ID | Decision | Effect on this brief |
| --- | --- | --- |
| RD06 | City credits get a better name. "Moolah" is a candidate, not chosen. | `JC` stays the working label until a name is picked; see [name research](../research/NAMING.md) |
| RD07 | Credits are earned in the game, bought with real money, or included with resident tiers. A tier can be a subscription or a one-time purchase. | Answers "can cash buy JC" with yes. Supersedes the earned-only default and the optional, later-gated credit packs |
| RD08 | Credits buy real things: facility access, in-game items, compute and storage. | Supersedes "allowances are not money" and the separation of fictional JC from funded service allowances (OP04–OP06) |
| RD09 / RD10 | A one-time payment buys a block for a house and residency. Sponsorship funds the lab and is a different thing. | Owned by [Residency](RESIDENCY.md); the payment matrix below follows it |
| RD11 | The product is global. | Razorpay remains the selected provider, but payment coverage, tax/VAT and consumer rules per market are open |

**What this brief recommended before, now superseded by RD07/RD08:** start with
earned JC only; let real money buy named benefits and expiring service
allowances that were explicitly "not money"; keep direct JC pack sales as an
optional alternative behind later delivery gates; never let JC stand in for
compute. That package is kept visible in
[Alternative cash models](#alternative-cash-models-evaluated-before-rd07) as the
record of what was weighed. Its cautions are still useful, because they
describe exactly the risks the decisions now have to manage.

### Open questions the decisions create

Recording RD07/RD08 does not settle these. None has an answer yet. The
[sources and sinks model](../research/ECONOMY_MODEL.md),
[payments and credits research](../research/PAYMENTS_AND_CREDITS.md) and
[legal and compliance research](../research/LEGAL_COMPLIANCE.md) are being
written to inform them.

1. **Legal character of purchased credits in each market.** Once credits are
   sold for money and redeem for compute and storage, they may be treated as
   stored value, a prepaid instrument, a voucher or a digital-content purchase,
   depending on the country (RD11). Registration, consumer-refund, tax/VAT and
   age rules follow from that classification. Nothing here is legal advice;
   see [legal and compliance](../research/LEGAL_COMPLIANCE.md).
2. **Earned versus purchased balances.** Proposal: keep two balances (or one
   balance with per-posting provenance) so that farmed or granted credits
   cannot drain real compute and storage. Open: which sinks accept earned
   credits, whether earned credits reach compute only through a capped, funded
   pool, and which balance is spent first.
3. **No cash-out.** Proposal carried forward: credits cannot be redeemed for
   money, traded on an exchange or turned into a claim on real assets. This
   needs confirming as a decision, because it shapes the legal character above.
4. **Refunds, expiry and transfers.** What happens to purchased credits on a
   refund or chargeback after they are spent; whether purchased or
   tier-included credits expire; whether credits can be gifted or transferred
   at all, and whether purchased credits can.
5. **Cash-ticketed competitions with rewards are the highest legal risk.** The
   [payment matrix](#what-people-pay-for) allows a festival or stadium event to
   sell a cash or JC ticket, and matches can pay rewards. Pay-to-enter plus a
   prize is the pattern gambling and prize-competition law looks at, and it
   becomes sharper once credits are purchasable and buy things with real cost.
   Until this is reviewed per market, treat "paid entry + credit reward" as
   not offered.
6. **Pricing credits against real cost.** RD08 makes a credit a claim on
   compute and storage that cost real money. Open: the price of a credit, the
   credit price of a unit of compute/storage, how provider price changes are
   passed on, metering, caps and what interruption looks like mid-task.
7. **Multi-account farming.** Free accounts, starter grants, a per-account tax
   exemption and tax-exempt gifts/transfers combine badly: many free accounts
   each collect a starter grant and earn under the threshold, then gift the
   proceeds to one wallet. This was tolerable when JC was fictional. It is not
   once credits buy compute. Open: whether starter grants are spend-restricted
   or non-transferable, whether transfers exist at all, identity strength
   for transfers, and per-person rather than per-account limits.
8. **The NPC-tax mint problem.** The treasury that pays human rewards
   ([public contracts](#a-residents-economic-loop) reserve from it) is filled
   by simulated household and business taxes
   ([civic formula](CIVIC_SIMULATION.md#the-simulation-economy)). NPC wages and
   profits are created by the simulation, so NPC tax is in effect new credit
   issuance, and NPC time can run faster than wall time
   ([clocks](CIVIC_SIMULATION.md#technical-shape)). Human bills are protected
   from a simulation speed-up
   ([fiscal period](#taxes-and-a-fiscal-period-people-can-understand));
   treasury income is not. Credit supply therefore depends on the simulation
   clock. Open: whether NPC taxes fund only fictional services, whether
   human-payable rewards come from a separately budgeted issuance account with
   a wall-clock cap, and whether treasury-funded earnings may reach real
   compute at all.

### Unreconciled reward and price fixtures

The example numbers across the gameplay briefs were written separately and do
not agree. They are **unreconciled fixtures**, not a draft balance:

| Fixture | Value | Where |
| --- | --- | --- |
| One completed job | 400 JC gross | [Worked accounting example](#worked-accounting-example); OP05 example |
| A whole reading garden, four milestones | 200 JC (50 each) | [Reading garden](scenarios/READING_GARDEN.md#fixture-and-explicit-rules) |
| Cottage kit, gameplay route | 800 JC | [Lifestyle progression](#lifestyle-progression-qualify-then-build) |
| Workbench | 450 JC | [Economy lab](../../prototypes/economy-lab.html) fixture |
| Starter wallet in the example | 1,200 JC | [Worked accounting example](#worked-accounting-example) |

One job pays twice what an entire cooperative garden pays, and a cottage costs
four entire gardens or two jobs. Nobody has decided how long a job or a garden
should take, so none of these ratios is meaningful. This brief does not invent
a balanced economy to paper over that. Reconciling earn rates, prices and the
real cost behind a credit is the job of the
[economy model](../research/ECONOMY_MODEL.md); until then, treat every number in
these briefs as a test value for arithmetic and conservation only.

## Three balances, with different jobs

| Record | What it represents | How it changes | What it buys |
| --- | --- | --- | --- |
| Real-money purchases/support | Verified provider receipts in their original currency | Explicit purchases, opted-in subscriptions, refunds and corrections | Residency and a block (RD09), resident tiers, credit purchases (RD07), lab sponsorship (RD10) and facility funding |
| City credits (`JC`, working label) | Spendable city currency | Earned in game (starter grants, funded jobs/contracts, trade, approved rewards); bought with real money; included with a resident tier (RD07). Reduced by purchases and bills | Facility access, in-game items, compute and storage (RD08): construction, furnishings, business inputs, utility bills, virtual taxes, fares, bookings, game upgrades and metered services |
| Contribution standing and unlocks | Reviewed milestones and earned permissions; not a spendable wallet | Accepted work, named achievements and reversible grant corrections | Alternate lifestyle unlock paths, craft recipes and project eligibility |

**The name is pending (RD06).** The credits were labelled "Jackfruit Credits";
Rakesh wants a better name and "Moolah" is a candidate, not yet chosen. `JC`
stays the working label throughout these documents so they are not renamed
twice.

Whether the `JC` row is one balance or two — earned and purchased — is
[open question 2](#open-questions-the-decisions-create). The table shows one
row because nothing has been decided.

**Superseded by RD07/RD08:** this brief previously said "service allowances are
an additional entitlement counter, not money", e.g. one tutor booking or a
measured voice allowance for a stated period. Under RD07 a tier includes
credits, and under RD08 credits are what pay for tutoring, voice, compute and
storage. The proposed replacement rule is in [Residency](RESIDENCY.md#what-a-tier-includes-and-for-how-long):
a one-time tier gives a one-time credit grant; a subscription tier gives a
recurring grant for as long as it is paid. What carries forward from the old
wording: show remaining credits and any expiry, and never silently spend real
money when a balance runs out. Credits have no cash redemption (proposal; see
[open question 3](#open-questions-the-decisions-create)).

Visitors may earn a bounded local practice balance. Persistent wallets require
an authenticated account; visitor status can remain free. Do not import local
save balances into the shared economy. Fictional NPC households have separate
accounts from human players and connected AI agents.

## What people pay for

This is the initial **proposed** payment matrix. Rows that cite an RD ID follow
a recorded decision; the rest are proposals. Cash items need a deliverable
benefit and a reviewed offer before checkout can exist. An `OR` choice means
alternative purchase routes; it never means charging both currencies.

| Action | Proposed payment route | What happens / boundary |
| --- | --- | --- |
| Explore, read public library material, use open lessons and park games | Free | No wallet needed; funded by the public budget or a sponsor |
| Become a resident and claim a block for a house | One-time residency purchase (RD09). Lab sponsorship may include residency (RD10). Reviewed contribution entry remains a proposal | One durable home claim. What the price includes, and for how long the home is hosted, is open in [Residency](RESIDENCY.md) |
| Buy credits | Real money (RD07) | Exact amount and price shown before checkout; no cash-out; legal character per market open |
| Resident tier (R2–R4) | Subscription OR one-time purchase (RD07), OR reviewed contribution milestone; earned-JC route proposed below | Grants lasting styles/features and includes credits; no automatic monthly re-purchase of the same unlock |
| Build a terrace, furnish a room, install a greenhouse | JC and/or authored material inventory | Quote before placement; reserve inputs and settle once |
| Income/profit tax | JC | Charged on defined taxable earnings, paid into the city treasury |
| Property/land-use assessment | JC on optional active business/expanded plot use | Starter personal plot exempt; assess published usage rather than speculative resale value |
| Power, water, waste collection | JC for opted-in simulation activity | Basic home allowance; metered business/extra use; separate from actual hosting bills |
| Tram/ferry convenience route | JC fare or funded pass | Walking and accessible navigation remain free |
| Recreation room, study room, hosted club booking | JC, including tier-included credits (RD08) | Reserve an actual slot; credits cannot promise unlimited hosting |
| Tutoring, agent assistance, character speech, compute and storage | JC (RD08); scholarship slots when funded | Quota, availability and a cost ceiling checked before starting; no raw operator access. Whether earned credits may pay is [open question 2](#open-questions-the-decisions-create) |
| Public festival / stadium event | Free admission when funded; otherwise advertised JC OR cash ticket where enabled | One ticket grants the same entry; competition rules do not depend on payment. **Paid entry combined with a reward is not offered until reviewed** ([open question 5](#open-questions-the-decisions-create)) |
| Cosmetic collection | Crafted/earned JC route; optional separate cash collection | Exact contents previewed; no randomized paid reward system in the initial design |
| Fund a park, library wing or station | JC pledge to a construction project OR named real sponsorship | Distinct campaign targets: virtual construction versus actual hosting/content cost |
| Human reporting, basic safety and fire response | Free at point of use | Funded collectively; emergency dispatch does not check a personal payment tier |

Under RD08 credits pay for facility access, compute and storage directly. The
earlier rule — "the service offer must identify who covers the actual cost for
the JC route: public budget, sponsor or a fixed scholarship allocation" — was
written for fictional credits. It still applies to **earned** credits, which
nobody paid real money for: every earned credit spent on compute is a real
cost someone must fund. For purchased and tier-included credits the buyer has
funded it. When a funded allocation is exhausted, offer a queue or a clearly
separate paid option; never convert the player's credits to a cash debit. More
JC does not create more CPU, moderators or seats: capacity is reserved before
credits are taken.

## Lifestyle progression: qualify, then build

Keep **eligibility**, **construction cost** and **included credits** distinct.
The R1–R4 home ladder remains in [Residency](RESIDENCY.md). Add a game route
for existing residents so ordinary play can improve a home as well as support
or real contributions. This is a proposed extension, not a previously agreed
qualification policy.

Example R2 offer, using fictional values only:

- Purchase or contribution route: a verified tier purchase or milestone
  grants the cottage kit, including one placement of its standard shell. Cash
  does not conceal another mandatory JC bill to obtain the advertised home.
- Gameplay route: complete an authored neighbourhood objective and spend 800 JC
  to obtain the same cottage kit. The objective measures an outcome, not logins.
- Further furnishings cost JC regardless of how the kit was unlocked. Existing
  unlock holders never have to buy the same kit again.
- Credits included with the tier follow the tier's payment form (RD07): a
  one-time tier grants credits once; a subscription tier grants them each paid
  period. The cottage itself does not disappear when a subscription ends. See
  [Residency](RESIDENCY.md#what-a-tier-includes-and-for-how-long).

R3 can introduce a workshop and courtyard; R4 a pavilion and shared programme
space. Unlocks can widen creative options while physical plot expansion waits
for reserved capacity. A tier never grants extra votes, operator powers or
competitive damage/speed. If benefits cannot be identical across routes, show
the differences before spending rather than disguising them as the same tier.

The [complete gameplay design](MECHANICS.md) and [larger world systems](WORLD_SYSTEMS.md)
explain the activities behind these rewards, including careers, construction,
research, expeditions and civic participation.

## A resident's economic loop

1. Choose an activity: a garden co-op, repair contract, delivery puzzle, workshop,
   shop, teaching session or community project.
2. Inspect the reward, time/inputs, completion evidence and funding source.
3. Complete it; the authority accepts the result and transfers the reward once.
4. Allocate earnings between an upgrade, operating inputs, savings, tax and
   shared projects. Show the next bill and the effect of each choice.
5. Watch the city respond: a better road reduces delivery time, a school expands
   skilled employment, and maintained parks increase leisure demand.

Public contracts reserve their reward from the treasury before acceptance.
Private contracts reserve the buyer's funds. A scenario grant is an explicit
source of new currency. So, less visibly, is NPC tax revenue flowing into that
treasury: see the [NPC-tax mint problem](#open-questions-the-decisions-create). Repeated placement/deletion, reciprocal fake purchases,
idle logins and raw AI-message volume do not generate income. An AI agent can
carry out authorized work but does not independently create payable rewards.

### Jobs, shops and supply chains

Begin with authored jobs and one NPC-supplied shop. Later let residents run a
bakery, nursery, repair shop, bookshop or makerspace. Businesses pay JC for
inputs, utilities, wages, permits and premises; they receive JC from customers.
Only accepted output can become inventory. NPC demand has a defined budget
and replenishment source, never infinite buyback at a guaranteed profit.

Recipes connect sectors: seeds + water + labour → plants; timber + labour →
furniture; materials + power → maintenance kits. Transport and storage create
real tradeoffs in the simulation. Keep fulfilment bounded and understandable
before enabling player-to-player listings, price negotiation or imports.

## Taxes and a fiscal period people can understand

Start with JC income tax and optional business utility bills. Add business
profit tax, active land-use assessments and event permits only after the first
loop works. Do not stack all possible taxes on the opening village.

| Charge | Proposed base | When it applies | Exclusions |
| --- | --- | --- | --- |
| Player income tax | Eligible settled job/trade earnings, with a published threshold | At settlement, using a recorded rate version | Starter grants, refunds, gifts/transfers of already-taxed funds, sponsorship receipts |
| Business profit tax | Eligible sales minus allowed settled operating costs | At a named fiscal close | Capital purchases are handled by an explicit rule; do not also tax the same business distribution as player job income |
| Active land-use assessment | Fixed area/use schedule | Only while optional commercial space is active | Starter personal home; no tax on donated real money |
| Utilities | Included allowance plus metered excess at a published JC tariff | Activity/service period | Idle base home; no unbounded arrears while offline |
| Permit/booking fee | Explicit event or reservation quote | On accepted booking/permit | Cancellation/refund rules published before purchase |

Use basis-point rates and integer-credit arithmetic with a deterministic
rounding rule. Preview gross reward, tax and net reward together. A policy
change applies prospectively at an announced boundary, never to settled income.
Receipts identify the taxable event so selling and moving its proceeds cannot
accidentally tax the same earnings twice.

The exclusions for starter grants and for gifts/transfers, together with a
per-account threshold, are the ingredients of multi-account farming once
credits buy compute (RD08). They were written for fictional credits and need
revisiting: see [open question 7](#open-questions-the-decisions-create).

Simulation time, personal billing periods and real subscription dates are
different clocks. Player obligations settle on accepted activity or opted-in
business periods; speeding up an NPC simulation does not multiply a person's
bills. Offline businesses can auto-pause at a chosen spending cap. No infinite
offline arrears, compound penalties or real-cash rescue demand for inactivity.

This protects what a person **owes** from a simulation speed-up. It does not
protect what the treasury **receives**: NPC household and business taxes accrue
on the simulation clock, and that treasury pays human rewards. See the
[NPC-tax mint problem](#open-questions-the-decisions-create) and the
[three-clocks question](CIVIC_SIMULATION.md#open-question-three-clocks-and-the-returning-player).

### When a wallet or city runs short

Before a JC purchase, reserve the funds; insufficient balance declines it
without a partial debit. For a business, pause new orders and discretionary
production, return unfulfilled reservations and offer a restart plan. Maintain
the player's blueprint and basic home access. Record unpaid assessments as a
bounded game obligation only if the person opted into that business rule.

For the treasury, apply a published funding order: minimum utilities/emergency
capacity, committed bookings/contracts, maintenance, then new construction and
discretionary events. Reserves and backlog have visible forecasts. Unfunded
staff hours reduce service capacity; a cash sponsorship cannot fix a missing
road or water connection without the corresponding game project.

## Worked accounting example

Illustrative one-period scenario: resident wallet 1,200 JC; treasury 2,000 JC;
NPC employer wallet 1,000 JC; equipment supplier wallet 0 JC. The employer pays
400 JC for a completed job. There is no repeated free job income in this example.

| Transfer | Resident change | Treasury change | Other account |
| --- | --- | --- | --- |
| Job gross earnings | +400 | 0 | Employer −400 |
| 10% income tax withheld | −40 | +40 | None |
| Utility charge | −30 | +30 | None |
| Study-room booking | −50 | +50 | None |
| Cottage gameplay purchase | −800 | 0 | Supplier +800 |
| Public service payroll/upkeep | 0 | −300 | Service staff/suppliers +300 |

The resident ends at **680 JC**; the treasury at **1,820 JC**. The employer has
600 JC, the equipment supplier 800 JC and service recipients 300 JC. Together
they still hold 4,200 JC. Taxes and domestic purchases transfer currency; they
do not destroy it. Explicit external imports or a declared issuance/retirement
account are needed for genuine sources/sinks. Never count the same upgrade
receipt as both supplier revenue and treasury income.

The [economy lab](../../prototypes/economy-lab.html) uses this fixture. A scholar
allowance can cover a booking through the publicly reserved subsidy pool. It
reduces that pool and credits the facility treasury; no JC is minted silently.

## More mechanics to grow into

| Mechanic | Player decision | Technical/design dependency |
| --- | --- | --- |
| Participatory budgets | Choose park maintenance, school seats or a tram extension | Simulated forecast forks; steward approval; one-person policy separate from spending |
| Community construction escrow | Pledge JC to a public project and track milestones | Reserve/return rules, deadline, target, one release per completed milestone |
| Co-op businesses | Pool JC/materials and divide documented earnings | Membership roles, ownership shares in game only, exit and settlement rules |
| Seasonal markets and festivals | Rent a stall, craft stock, set an entry price | Finite demand, permits, event capacity, cancellation and inventory recovery |
| City procurement | Bid to supply plants, furniture or maintenance | Funded reward pool, quality checks, acceptance evidence, bid-abuse controls |
| Maintenance and depreciation | Repair equipment now or accept lower output | Predictable wear, visible cost, no destruction of saved home designs |
| Scholarships and service vouchers | Sponsor access for someone else | Finite funded pool, private eligibility, explicit expiry; no transferable cash value |
| Time bank | Exchange an accepted community-help session for a bounded activity | Reviewed completion, capacity reservation; no equation between volunteer hours and dollars |
| Insurance / disaster reserve | Pool JC for optional commercial incident recovery | Seeded scenarios, capped payouts, funded reserve; no real-money insurance product |
| Credit union / construction loan | Borrow JC for a workshop, repay from simulated sales | Later only: integer schedule, exposure cap, default/restructure model, no cash debt or cash-out |
| Tourism and external trade | Attract NPC customers while managing service demand | Explicit external-demand budgets, imports/exports, congestion and inflation metrics |
| District specialties | Trade orchard produce for workshop materials | Inventory authority, bounded logistics and atomic inter-district transfers |

Avoid launching all of these together. **The first slice is RD01:** a person
walks the city and sees the 14 Guild agents doing their actual current work. It
has no economy in it. The loop this brief proposed as "first" — funded job →
income tax → utility/service choice → cottage upgrade → treasury consequence —
is now a **later candidate** for the first economic loop, alongside the
[reading garden](scenarios/READING_GARDEN.md) and the
[first civic district](CIVIC_SIMULATION.md#first-complete-district-and-acceptance-evidence).
Which comes first after RD01 is undecided. Banking, player markets and
multi-district trade come after conservation and recovery tests pass.

## Alternative cash models evaluated before RD07

This table is the earlier comparison, kept as the record of what was weighed.
RD07 chose the second row; RD08 extends what those credits buy.

| Model | Appeal | Required rules | Status |
| --- | --- | --- | --- |
| Earned JC; real money buys named benefits/services | Clear civic economy and operating-cost boundary | Alternate unlock paths and funded JC service capacity | Earlier recommendation; **superseded by RD07/RD08** |
| Sell JC packs for real money | Players can spend money to accelerate game purchases | Track purchased versus earned provenance, refund consequences, inflation, spend caps, gift/trade abuse and price disclosure | **Decided by RD07.** The "required rules" column is now the [open-question list](#open-questions-the-decisions-create) |
| Every eligible offer has cash OR JC pricing | Broad payment choice and fewer exclusive items | Separate versioned prices, exclusive settlement, cost subsidy and refund route per offer; do not imply a universal exchange rate | Still a proposal; less needed once credits can be bought, because a sold credit already implies an exchange rate |

A tier can be a subscription or a one-time purchase (RD07). Present a
subscription as an explicit subscription, with renewal/cancellation terms. It
is separate from simulated municipal taxes. No in-game budget vote or unpaid JC
bill can opt someone into a cash subscription. Cash-out, exchange trading and
transferable claims on real assets stay outside this design (proposal; see
[open question 3](#open-questions-the-decisions-create)).

## Technical contract and payment lifecycle

Create a city-owned economic authority; do not put financial state in browser
storage, avatar rooms or AgentPod's database. Both native and web clients send
the same authenticated intents and display server-calculated quotes.

| Record | Required facts |
| --- | --- |
| Wallet / ledger account | Owner, unit, available/reserved amounts, earned/purchased/tier-included provenance (form open), revision, permitted issuance/retirement role |
| Journal transaction / postings | Unique operation and business event IDs, balanced signed postings per unit, reason, rule version, actor, references and timestamps |
| Offer / price quote | Offer version, currency route, exact amount, included benefits, eligibility, capacity, expiry and cancellation policy |
| Tax assessment | Taxable event/period, base, exclusions, basis-point rate, rounding, paid/owed state |
| Reservation / booking | Wallet hold, capacity hold, expiry, fulfilment/cancellation state |
| Support/purchase evidence | Provider object/event IDs, verified settlement state, amount/currency and adjustments; private |
| Benefit grant | Target resident, source purchase/contribution/gameplay event, lasting unlock, one-time or recurring credit grant, correction history |
| Project / contract | Funding account, committed amount/materials, acceptance criteria, completion and payout IDs |

Require posting sums of zero **within each currency/unit**. A grant credits a
wallet against an explicit issuance account; real-currency and JC postings
cannot balance each other. Serialize conflicting wallet/capacity updates with
transactional constraints; one city treasury owner starts simpler than sharding.
Keep credit balances within an explicit safe integer range in client contracts.

JC purchase: quote → validate eligibility and capacity → reserve → fulfil and
settle together, or release/compensate. A crash after durable acceptance must
not produce another charge or item on retry. For a long job, reserve the maximum
approved cost and settle measured usage under the displayed cap.

Cash purchase: quote → explicit checkout → pending → verified provider success
→ idempotent grant/booking fulfilment. Failed/expired checkout releases holds;
a delayed successful payment must re-check capacity and use a documented
rebooking/refund path if the hold expired. Do not promise an atomic transaction
across the provider and city database. Persist an inbox/outbox and reconcile.

**Razorpay is the selected provider**, as requested by Rakesh. RD11 makes the
product global, so payment coverage outside India, tax/VAT and per-market
consumer rules are open; see [payments and credits](../research/PAYMENTS_AND_CREDITS.md). The
[Razorpay integration plan](../integrations/payments/RAZORPAY.md) specifies order creation, captured-payment
verification, subscriptions, webhook deduplication and refund recovery. It
supersedes the earlier GitHub Sponsors-first recommendation. Provider-specific
operations stay in that integration document; this brief owns economic rules.

Refunds and reversals append compensating records; never delete history.
Release unused reservations, correct dependent credit grants, and preserve the
home blueprint. Credits can be purchased (RD07): trace their spend and define
non-destructive reversal rules before allowing any transfers. Simulation
replay rebuilds state only; it never repeats a provider charge, refund, reward
dispatch or AgentPod task. Keep payment data out of public city snapshots.

## Delivery gates and evidence

These gates are proposals and sit after the RD01 first slice, which needs no
economy. No technology is chosen by them (RD15).

- **E0: policy lab.** Compare the payment matrix and fixture budgets. The
  currency model is decided (RD07/RD08); settle the
  [open questions](#open-questions-the-decisions-create), starter exemptions,
  fiscal periods and tier qualification, and reconcile the
  [fixtures](#unreconciled-reward-and-price-fixtures).
- **E1: earned credits only.** Authenticated wallets, funded job, one tax,
  utilities, one paid/free activity and one upgrade; no live-money integration
  required.
- **E2: tiers and included credits.** Manual fixture purchase/contribution
  grants, one-time and recurring credit grants, and metered spend on a finite
  service; exercise expiry, pause, booking conflicts and corrections.
- **E3: payment rehearsal.** Verify the Razorpay account capabilities and
  coverage for the intended markets (RD11), define deliverable offers including
  credit purchases, implement verified intake and reconciliation in provider
  test mode. Rehearse delayed success, missed/reordered events, refunds of
  already-spent credits and chargebacks before launch. Purchasable credits do
  not go live before the legal character per market is answered.
- **E4: richer economy.** Markets, co-ops, procurement and optional credit
  mechanisms after supply, concentration, affordability and recovery are measured.

Acceptance evidence must include conservation across all accounts, insufficient
funds, duplicate job claims, concurrent purchases/bookings, exact rounding,
policy changes, already-owned upgrades, credit exhaustion mid-task, cancellation,
restoration and read-only replay. Verify that JC insufficiency never charges
cash, and that an absent resident returns to a preserved home without surprise
arrears. Track the ordinary play needed to afford an upgrade as well as total
currency supply, issuance, transfers, reserves and service queues.

Sources were reviewed on September 16, 2026; the RD06–RD11 decisions were
applied on September 18, 2026. Economic coefficients and gameplay
rules here are original proposals, not real financial forecasts or current
provider/account capabilities. No live checkout, payment or subscription was
created by this documentation work.
