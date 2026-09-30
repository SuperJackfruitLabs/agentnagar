# Lab-server storage for the city

Storage requirements · 2026-09-16 · decisions applied 2026-09-18 ·
[Architecture](ARCHITECTURE.md)

**Status, 2026-09-18.** RD13 decides that Forgejo will run on SJL's
self-hosted lab server as the agents' dedicated git system. RD15 leaves every
other host, database and backup tool unchosen: the uses proposed below are
candidates for a self-hosted server, not allocations.

A candidate lab server has two kinds of storage: a fast SSD tier and a larger
bulk HDD tier. The city's proposed use of each is below. Machine inventory,
device layout, capacities and service configuration are deliberately kept out
of this repository; they are not needed to state the city's requirements.

| Storage tier | Proposed city use |
| --- | --- |
| Fast (SSD) | Active city database, accepted-command journal, wallet/booking transactions, current snapshots and bounded job scratch |
| Bulk (HDD) | Versioned asset sources, cold plot archives, completed job outputs, backups and longer-term simulation history |

Neither tier is reserved capacity, sustained throughput, a disk-health
assessment or a successful restore test.

## Hosting role

The September 16 repository review found a prerequisite beyond disk capacity:
the lab server is operated as a lab, and product availability should not
depend on it without an explicit decision. Durable city accounts, wallets and
paid services would cross that boundary. Either agree and document a
protected production role with isolation, recovery ownership and resource
reservations, or select separate production hosting and keep the lab server
for staging and bounded jobs. No host-role change is approved by this city
plan.

**Forgejo on the lab server (RD13, 2026-09-18).** Rakesh decided that Forgejo
will run on the lab server and that agents get a dedicated git system as part
of the stack. That settles Forgejo's presence and its host. It sharpens the
question above without answering it: a forge holding agents' repositories is
durable data on a machine run as a lab. Still open, and owned by SJL's
infrastructure operators once decided:

- **Placement:** which storage tier holds repositories, LFS objects, packages
  and CI caches, and with what quotas.
- **Capacity:** CPU, memory and I/O reservations for the forge and any CI
  runners, measured against the other proposed lab-server workloads.
- **Isolation:** separation between the forge, contributor-controlled CI jobs,
  city services and the host; agent accounts and their permissions.
- **Backup:** a consistent forge backup (database plus repositories), an
  off-host copy and a rehearsed restore.
- **Lab/production boundary:** whether Forgejo is an explicit exception to
  the lab role, or the reason to change the server's role.

How Forgejo integrates with Superpipeline, AgentPod and the city is a later
discussion (RD13, RD14). Nothing was installed or reserved by this update.

Operational inventory and runbooks are kept privately by SJL's infrastructure
operators. Available disks and existing backup services do not establish city
backup coverage, reserved capacity or a recoverable city deployment. This
document records only the city's requirements and decision gap.

## Credits meter real storage and compute

Credits can be bought with real money (RD07) and they buy real things,
including compute and storage (RD08). This changes what the storage plan is
for. The earlier briefs kept a fictional currency apart from funded service
allowances; that separation no longer holds. Design consequences, recorded
here as requirements and not as a chosen design:

- **Three coupled systems.** The credit ledger, usage metering and quota
  enforcement must agree. A reservation in the ledger, a measured byte-month
  or CPU-second, and the quota that stops further use describe one
  transaction seen three ways.
- **Storage becomes a priced product.** Bytes on the SSD and HDD tiers have a
  real cost that some credit price must cover. Capacity figures in the table
  above are an inventory, not a sellable pool; selling storage needs measured
  cost per unit and headroom for backups and restores.
- **Metering must be durable and auditable.** A lost usage record is either a
  lost charge or a wrongly charged resident. Usage records belong with the
  ledger in the consistent backup set, not in disposable logs.
- **Exhaustion has defined behaviour.** When credits or quota run out, the
  city needs a stated order: warn, stop new writes, keep reads, retain for a
  grace period, export, then delete. Earned homes and paid storage may need
  different rules.
- **Earned credits reach real cost.** Credits earned in play (RD07) can be
  spent on real compute and storage (RD08), so farming is a cost-control
  problem and not only a game-balance one.
- **Restore reconciles all three.** After a restore, ledger balances, metered
  usage and provider payments must be reconciled together before writes
  resume.

Pricing, legal character and refunds are researched in
[payments and credits](../research/PAYMENTS_AND_CREDITS.md). The credit name
is still open (RD06); `JC` remains the working label.

## Separate fast writes from bulk retention

The placements below are proposals for a candidate host (RD15). Keep the
authoritative city database and recent journal on SSD first. Wallet
settlement, public treasury reservations and accepted building edits should not
wait behind a large archive copy. Run large asset jobs through bounded queues,
with separate scratch/output quotas and monitored I/O contention.

Write archived plots and immutable asset versions to HDD through a checked
manifest. Record schema/version, checksum, size, source revision and creation
time. A cold home is restored into the active tier on request; the UI shows
restoration progress. Never delete the active copy until the destination is
verified and the retention policy allows it.

Back up databases using the selected database's consistent backup procedure,
including the journal needed for the intended recovery point. Merely copying
live files or taking unrelated filesystem snapshots does not prove economic
transactions and world state can be restored together. Keep payment evidence
and private account records separate from public world/asset exports.

HDD backups on the same host protect against some application mistakes but
do not cover loss of the whole host. Mirroring and snapshots do not replace
an independent backup and a rehearsed restore. Choose retention, encryption,
access rules and an off-host copy when implementing; no backup service or
coverage is assumed from the available disks.

## Implementation evidence

1. Measure SSD write latency during room edits and wallet settlement; repeat
   while an HDD archive transfer and bounded asset job run.
2. Enforce volume, scratch, archive and log-retention budgets with alerts before
   exhaustion. Low space should reject new paid work before taking payment.
3. Restore a city snapshot plus accepted journal into an isolated environment;
   verify wallet conservation, grants, bookings and home ownership together.
4. Restore a cold plot and verify asset hashes/schema migrations without
   touching a live player's copy. Preserve a recoverable export on failure.
5. Define and test recovery-time and recovery-point objectives before promising
   paid storage. Provider reconciliation must not recreate already-granted
   benefits after restore; simulation replay must issue no cash operations.

This plan does not move existing AgentPod or infrastructure data. City
storage is a separate proposed lab-server workload, and Forgejo (RD13) is a
further workload whose storage needs are not yet sized.
