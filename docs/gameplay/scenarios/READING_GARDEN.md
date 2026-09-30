# Scenario: build the school's reading garden

Later-loop candidate · 2026-09-18 · [Mechanics](../MECHANICS.md)

**Not the first slice.** RD01 in the
[decision register](../../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)
defines the first slice as walking the city and seeing the 14 Guild agents at
their actual work. This scenario was written as the "first loop"; it is now a
candidate for the first **building** loop after RD01, alongside the
[economy loop](../ECONOMY.md#more-mechanics-to-grow-into) and the
[first civic district](../CIVIC_SIMULATION.md#first-complete-district-and-acceptance-evidence).

This scenario tests a small connected part of the
[full world vision](../WORLD_SYSTEMS.md). It does not replace the larger
careers, ecology, government, expedition or automation systems. No playable
version or user test of this scenario exists yet.

## Situation and player choice

A fictional teacher reports that the school needs four additional usable
reading seats during the afternoon. The current school offers four seats for
a demand of eight. Players inspect the evidence and propose a small garden
beside the school, connected to its path and water supply.

One person can complete the roles sequentially; two people can divide the work
or contribute in different sessions. Three-to-ten-minute contributions are a
playtest target, not a measured duration. The scenario does not require real
money, a paid tier, a live agent or an elected government.

## Fixture and explicit rules

All values below are invented for this prototype. They are
[unreconciled fixtures](../ECONOMY.md#unreconciled-reward-and-price-fixtures):
the whole garden pays 200 JC while a single job elsewhere pays 400 JC and a
cottage costs 800 JC. Do not read a balance into them.

| Item | Initial fixture / completion rule |
| --- | --- |
| Site | One bounded 8×8 plot, two candidate layouts, existing school path and water connection |
| Demand | Eight fictional reading-seat requests in the afternoon interval |
| Existing capacity | Four school seats, already funded and usable |
| Garden capacity | Four additional seats, usable only while the garden is open, funded and connected, with the required shade/plant condition |
| Project funding | Treasury has 1,000 JC; reserve 300 JC for material procurement and four milestone rewards |
| Materials | 12 timber units, four plant units, two irrigation parts; finite supplier inventory |
| Procurement | 100 JC for the complete material kit, with the fictional supplier explicitly holding it |
| Rewards | Four accepted milestones at 50 JC each; no extra payment for repeat submissions |
| Operations | 20 JC per simulated service period, opted in by the project steward |
| Recognition | One personal recipe grant per qualifying contributor and one public completion event; public attribution optional |

The 100 JC material purchase transfers money to the supplier and inventory into
project custody. The remaining 200 JC is reserved for milestone rewards. All
credits use the existing economy authority; no standalone quest wallet exists.
Tax treatment is a fixture policy set to zero for this scenario and recorded
with the reward offer. The general tax design is not silently overridden.

## Known limitation: no source of new money

The fixture has no income. The treasury starts at 1,000 JC and falls to 700 JC
once the kit and the four milestones are paid. Operations then cost 20 JC per
service period, and with tax set to zero nothing comes back. 700 ÷ 20 = 35:
the garden can stay open for 35 periods and then closes under the
"insufficient operating budget" rule below. If the simulation keeps running
while nobody is online, players return to a garden that closed in their
absence, through no choice of theirs.

This is acceptable for a conservation test and wrong for a place people are
meant to care about. Open design questions, none answered:

- **Where does upkeep money come from?** Candidates: a share of tax once tax is
  non-zero, a visible per-period civic grant (explicit issuance), usage fees
  from fictional readers, or resident pledges. Each is a credit source, so it
  belongs in the [economy model](../../research/ECONOMY_MODEL.md) and runs
  into the [NPC-tax mint problem](../ECONOMY.md#open-questions-the-decisions-create).
- **Should upkeep pause when nobody is present?** See the
  [three-clocks question](../CIVIC_SIMULATION.md#open-question-three-clocks-and-the-returning-player).
- **What does closing cost?** The rule below keeps the design and the school's
  original seats, so closing is recoverable; whether reopening needs a new
  funding decision is undefined.

## Play sequence

1. **Investigate.** Open the teacher's request and inspect demand, capacity,
   path and opening hours. A contextual hint teaches the overlay if needed.
2. **Design.** Compare two layouts. One has a short path but needs additional
   shade; the other reuses shade but needs a longer accessible connection.
   Choose or adjust a layout within the same budget and plot bounds.
3. **Approve and fund.** The scenario steward approves a blueprint revision
   and reserves the 300 JC pool. Private practice can skip the shared authority
   step; public application cannot. **Open:** who the steward is. If it is a
   person, and that person is a solo operator, the loop waits on them. Which
   approvals can be deterministic (the blueprint passes the published bounds,
   budget and dependency checks) or automated is an
   [open question](../MECHANICS.md#open-question-which-approvals-need-a-person).
4. **Supply.** Procure the finite kit and deliver it to project custody. The
   worker can carry it or choose an accessible interaction with the same result.
5. **Build and plant.** Place the accepted structures and planting. A gardener
   completes the irrigation connection and checks the declared plant conditions.
6. **Inspect.** Verify the approved revision, inventory consumption, four seats,
   path access, shade/plant predicate and water connection. Explain each failure.
7. **Open.** With the operations budget approved, enable four garden seats.
   The request closes when total usable capacity reaches eight for the interval.
8. **Remember.** Display a factual before/after panel and an optional completion
   notice. The visitor can return to the garden and inspect what changed.

The four reward milestones are accepted design (50), accepted delivery (50),
accepted construction/planting (50) and accepted inspection (50). One person
may earn more than one milestone, but each milestone has one reward allocation
in this fixture. Shared/subcontracted allocation is a later explicit rule.

## Authority, persistence and handoff

```text
proposed → approved_and_funded → supplied → built → inspected → open
                  ↘ paused / cancelled (recorded compensation)
```

A project records `project_id`, `scenario_version`, `blueprint_revision`,
`funding_reservation_id`, milestone evidence, material custody, actor/role,
lease expiry and accepted event IDs. Every mutation carries a command ID and
expected project revision. The server validates permissions at acceptance time.

A claim lease lets another worker continue after abandonment. It does not
invalidate work already accepted. A design change after procurement produces
a reviewed change order, new material requirements and compensation where
needed; it cannot silently consume a second kit or pay the same milestone twice.

Inspection atomically records the result and queues its one reward. Opening
uses an idempotent world-change event tied to the inspected blueprint revision;
retrying does not add four more seats. A stale inspection must not open a
subsequently altered design. Client previews never directly update the treasury.

## Resource and failure behavior

- Missing road or irrigation: explain the failed dependency; more money alone
  does not satisfy it. The accepted blueprint remains available for repair.
- Low water: pause the relevant plant/garden contribution to capacity according
  to the declared rule. Preserve the saved design; restoration is possible.
- Insufficient initial funding: do not accept the paid project. Offer practice
  mode, an explicit smaller design or a funded wait state.
- Insufficient operating budget: reduce garden availability; retain the
  school's original four seats. Announce the capacity change without charging
  an absent player's real account or accumulating personal surprise debt.
- Worker disconnect: preserve accepted inventory/work and expose a handoff.
- Cancellation: release unspent reward reservations, preserve already earned
  rewards and return unused materials under the offer's rules. Consumed work
  is not an automatic refundable purchase; record any deconstruction separately.
- Public recognition opt-out: omit identity from the story while retaining
  private reward evidence. A world reset cannot resend a payment or publish
  another completion notice for the same public event.

## Evaluation and acceptance cases

| Case | Required evidence |
| --- | --- |
| Solo and two-person completion | Each understands one useful action; a sequential role switch works |
| Asynchronous handoff | Second person can resume without the first person's credentials |
| Duplicate/concurrent submissions | One material consumption and one reward per milestone; no negative funds |
| Stale blueprint | Inspection/opening rejects the wrong revision |
| Missing utility/path | Failure names the dependency and recovery action |
| Budget conservation | After all milestones, treasury 700 JC; supplier +100 and workers +200; total JC unchanged |
| Operating period | 20 JC moves from treasury to service recipients; it is not silently destroyed |
| Treasury exhaustion | After 35 unfunded periods the garden closes by the published rule, keeps its design and announces the change; reopening is possible once funded |
| Capacity accounting | Opening adds four seats once; the eight requests are allocated once, not counted at both facilities |
| Restart and replay | Same project, inventory, rewards and seats; no repeated grant or publication |
| Accessibility | Essential actions and causes available through keyboard and readable controls, without a timed traversal requirement |
| Privacy | Public story omits unapproved identities and contains no private agent/payment data |

Observe whether the participant can explain the need, choose a layout for a
reason, complete a contribution and understand the outcome. Ask which step
felt worthwhile and which felt like a chore. Compare local practice without
JC rewards with the funded project; neither variant has been tested yet.

Later extensions can add a real approved agent design review, a dry-season
experiment, a reusable watering rule, a neighbourhood charter and a reading
cart visit. Those ideas remain fully described in [World systems](../WORLD_SYSTEMS.md)
rather than being discarded if the first scenario omits them.
