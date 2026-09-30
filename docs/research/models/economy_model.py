#!/usr/bin/env python3
"""Agentnagar city-credit model - toy simulation behind docs/research/ECONOMY_MODEL.md.

Standard library only.  Run with:

    python3 docs/research/models/economy_model.py

Every number printed here is produced from the parameters in this file.  They
are PLACEHOLDERS chosen to expose structure and sensitivity.  None of them is a
proposed live price, reward, tax rate or cost.  There is no playtest data and no
measured provider cost behind any of them.

WHAT IS MODELLED
----------------
A weekly ledger for 52 weeks.  Accounts hold integer city credits (`JC`, the
working label under RD06).  Real money is a separate unit and never balances
against credits: a credit sold for money is an ISSUANCE against a receipt, and a
credit spent on compute or storage is a RETIREMENT that also books a real cost in
the operator's cost-of-goods account.  Conservation is checked every week by
carrying explicit `issuance` and `retirement` accounts, so the signed sum over
all credit accounts never moves.

KEY PARAMETERS (all placeholders)
---------------------------------
Params.jc_per_hour           earn rate implied by today's reward fixtures
Params.starter_grant         one-time faucet per NEW ACCOUNT (farming surface)
Params.tax_exemption         OP05 per-account per-period exemption
Params.tax_rate_bps          OP05 rate above the exemption, in basis points
Params.npc_tax_per_week      treasury income minted by the NPC sector at clock x1
Params.clock                 simulation clock multiplier: scales the NPC mint
Params.credit_price_usd      real-money price of one credit (placeholder)
Params.cogs_usd_per_service_credit  operator cost of one credit redeemed for
                             compute/storage (placeholder)
Params.earned_service_cap    option (iii) monthly earned-credit conversion cap
Params.faucet_budget_credits option (iv) city-wide monthly faucet issuance cap

FOUR OPTIONS COMPARED (deliverable B)
-------------------------------------
(i)   single fungible balance
(ii)  dual balances, earned credits buy only zero-marginal-cost things
(iii) dual balances plus a capped, operator-funded conversion window
(iv)  earned credits fungible, but faucets budgeted from a real-money pool

The simulation runs once with option (i) semantics - that is what today's
fixtures describe - and records per-account monthly demand.  The four options are
then applied to that recorded demand, so the comparison holds player behaviour
constant and varies only the settlement rule.
"""

from __future__ import annotations

import random
import sys
from dataclasses import dataclass, field, replace
from typing import Dict, List, Tuple

SEED = 20260918


# --------------------------------------------------------------------------
# Formatting helpers
# --------------------------------------------------------------------------

def jc(n: float) -> str:
    return f"{int(round(n)):,}"


def usd(n: float) -> str:
    return f"${n:,.2f}"


def usd4(n: float) -> str:
    return f"${n:,.4f}"


def table(title: str, headers: List[str], rows: List[List[str]], note: str = "") -> None:
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(cell))
    print()
    print(title)
    print("-" * len(title))
    line = "  ".join(h.ljust(widths[i]) for i, h in enumerate(headers))
    print(line.rstrip())
    print("  ".join("-" * w for w in widths))
    for row in rows:
        cells = []
        for i, cell in enumerate(row):
            cells.append(cell.ljust(widths[i]) if i == 0 else cell.rjust(widths[i]))
        print("  ".join(cells).rstrip())
    if note:
        print(note)


# --------------------------------------------------------------------------
# OP05 tax rule - reproduced exactly
# --------------------------------------------------------------------------

@dataclass(frozen=True)
class TaxRule:
    """OP05: exempt the first `exemption` of eligible gross income per period,
    then apply `rate_bps` above it, on a CUMULATIVE liability with integer
    arithmetic so splitting a reward cannot round the tax away."""

    exemption: int = 1000
    rate_bps: int = 1000

    def liability(self, cumulative_eligible: int) -> int:
        return (max(0, cumulative_eligible - self.exemption) * self.rate_bps) // 10000

    def assess(self, already_eligible: int, already_assessed: int, gross: int):
        after = already_eligible + gross
        total = self.liability(after)
        tax = total - already_assessed
        return {
            "before": already_eligible,
            "gross": gross,
            "after": after,
            "liability": total,
            "already": already_assessed,
            "tax": tax,
            "net": gross - tax,
        }


# --------------------------------------------------------------------------
# Ledger - explicit issuance and retirement, so conservation is checkable
# --------------------------------------------------------------------------

class Ledger:
    def __init__(self, opening: Dict[str, int]):
        self.acc: Dict[str, int] = dict(opening)
        self.acc.setdefault("issuance", 0)
        self.acc.setdefault("retirement", 0)
        self.invariant = sum(self.acc.values())
        self.minted = 0
        self.retired = 0

    def transfer(self, src: str, dst: str, amount: int) -> None:
        assert amount >= 0 and isinstance(amount, int), (src, dst, amount)
        assert self.acc[src] >= amount, f"overdraw {src} {self.acc[src]} < {amount}"
        self.acc[src] -= amount
        self.acc[dst] += amount

    def mint(self, dst: str, amount: int) -> None:
        """Creation.  `issuance` goes negative by the same amount."""
        assert amount >= 0
        self.acc["issuance"] -= amount
        self.acc[dst] += amount
        self.minted += amount

    def retire(self, src: str, amount: int) -> None:
        """Destruction.  Credits leave circulation into `retirement`."""
        assert amount >= 0
        assert self.acc[src] >= amount, f"overdraw {src}"
        self.acc[src] -= amount
        self.acc["retirement"] += amount
        self.retired += amount

    def check(self) -> None:
        total = sum(self.acc.values())
        assert total == self.invariant, f"conservation broken: {total} != {self.invariant}"


# --------------------------------------------------------------------------
# Parameters
# --------------------------------------------------------------------------

@dataclass
class Params:
    weeks: int = 52
    # Earning.  460 JC/hour is the reading-garden anchor: 50 JC per accepted
    # milestone at the scenario's 3-10 minute playtest target, midpoint 6.5 min.
    jc_per_hour: int = 460
    starter_grant: int = 500
    tax: TaxRule = field(default_factory=TaxRule)
    use_exemption: bool = True
    # NPC sector.  city-lab.html coefficients: 40 households x 100 income per
    # day = 4,000/day, i.e. 28,000 per week at clock x1, taxed at 10%.  The
    # INCOME is created by the simulation; that is the mint, and it scales with
    # the clock.  The tax on it is an ordinary transfer to the treasury.
    npc_income_per_week: int = 28000
    npc_tax_rate_bps: int = 1000
    npc_sector_open: int = 200000
    clock: int = 1
    public_contract_share: float = 0.25
    treasury_open: int = 20000
    treasury_floor: int = 2000
    weekly_upkeep: int = 1500
    # Real-money boundary (placeholders, not prices).
    credit_price_usd: float = 0.010
    cogs_usd_per_service_credit: float = 0.008
    subscription_jc_per_month: int = 500
    pack_jc: int = 1000                    # one-time credit pack (placeholder)
    pack_buyer_share: float = 0.20         # share of casual residents who buy one
    # Option knobs.
    earned_service_cap: int = 200          # option (iii), per account per month
    review_pass_rate: float = 0.60         # option (iii), reviewed contribution
    faucet_budget_credits: int = 120000    # option (iv), city-wide per month
    # Population.
    n_visitors: int = 60
    n_casual: int = 30
    n_builders: int = 9
    farmer_alts: int = 10
    label: str = "baseline"


ARCHETYPES = {
    # hours/week, share of income spent on items, share spent on real-cost
    # services, subscription?
    "visitor":  dict(hours=0.5, item_share=0.30, service_share=0.05, subscribed=False),
    "casual":   dict(hours=2.5, item_share=0.55, service_share=0.10, subscribed=False),
    "builder":  dict(hours=8.0, item_share=0.25, service_share=0.60, subscribed=True),
    "farmer":   dict(hours=0.6, item_share=0.00, service_share=1.00, subscribed=False),
}


@dataclass
class Account:
    aid: str
    kind: str
    hours: float
    earned: int = 0
    purchased: int = 0
    tier: int = 0
    eligible: int = 0
    assessed: int = 0
    owner: str = ""
    first_cottage_week: int = 0
    net_earned_cum: int = 0
    # monthly records: (earned_in, funded_in, service_demand)
    monthly: List[List[int]] = field(default_factory=list)

    @property
    def balance(self) -> int:
        return self.earned + self.purchased + self.tier


# --------------------------------------------------------------------------
# Simulation
# --------------------------------------------------------------------------

@dataclass
class RunResult:
    label: str
    params: Params
    accounts: List[Account]
    weekly_supply: List[int]
    weekly_treasury: List[int]
    weekly_funded_ratio: List[float]
    tax_collected: int
    npc_minted: int
    npc_tax_to_treasury: int
    grants_minted: int
    sold_minted: int
    service_retired: int
    item_flow: int
    revenue_usd: float
    cogs_usd: float
    runway_week: int
    ledger: Ledger


def build_population(p: Params, rng: random.Random) -> List[Account]:
    accounts: List[Account] = []
    for i in range(p.n_visitors):
        accounts.append(Account(f"v{i:03d}", "visitor", ARCHETYPES["visitor"]["hours"]))
    for i in range(p.n_casual):
        accounts.append(Account(f"c{i:03d}", "casual", ARCHETYPES["casual"]["hours"]))
    for i in range(p.n_builders):
        accounts.append(Account(f"b{i:03d}", "builder", ARCHETYPES["builder"]["hours"]))
    accounts.append(Account("farm-main", "farmer", ARCHETYPES["farmer"]["hours"], owner="farmer"))
    for i in range(p.farmer_alts):
        accounts.append(Account(f"farm-alt{i:02d}", "farmer", ARCHETYPES["farmer"]["hours"],
                                owner="farmer"))
    for a in accounts:
        # +/-20% deterministic jitter on play time
        a.hours = round(a.hours * (0.8 + 0.4 * rng.random()), 3)
    return accounts


def simulate(p: Params) -> RunResult:
    rng = random.Random(SEED)
    accounts = build_population(p, rng)
    tax = p.tax if p.use_exemption else replace(p.tax, exemption=0)

    led = Ledger({
        "players_earned": 0,
        "players_purchased": 0,
        "players_tier": 0,
        "treasury": p.treasury_open,
        "operators": 0,
        "npc_sector": p.npc_sector_open,
    })

    weekly_supply: List[int] = []
    weekly_treasury: List[int] = []
    weekly_funded: List[float] = []
    tax_collected = npc_minted = grants_minted = sold_minted = 0
    npc_tax_to_treasury = 0
    service_retired = item_flow = 0
    revenue_usd = cogs_usd = 0.0
    runway_week = 0

    # Faucet: one-time starter grant per ACCOUNT (not per person).
    for a in accounts:
        led.mint("players_earned", p.starter_grant)
        a.earned += p.starter_grant
        grants_minted += p.starter_grant
    led.check()

    for week in range(1, p.weeks + 1):
        month = (week - 1) // 4
        for a in accounts:
            while len(a.monthly) <= month:
                a.monthly.append([0, 0, 0])
            a.eligible = 0
            a.assessed = 0

        # 1. The simulation CREATES NPC wages and profits on the simulation
        #    clock.  This is the unacknowledged mint.  The tax on that income is
        #    then an ordinary transfer into the treasury that pays human rewards,
        #    so treasury income tracks the clock even though nobody calls it
        #    issuance.
        npc_in = p.npc_income_per_week * p.clock
        led.mint("npc_sector", npc_in)
        npc_minted += npc_in
        npc_tax = (npc_in * p.npc_tax_rate_bps) // 10000
        led.transfer("npc_sector", "treasury", npc_tax)
        npc_tax_to_treasury += npc_tax

        # 1b. Operators (staff, suppliers) spend their receipts back into the
        #     NPC sector.  A transfer, as in the prototypes' recirculation path.
        led.transfer("operators", "npc_sector", led.acc["operators"])

        # 2. Subscription tiers: real money buys credits (issuance vs receipt).
        if week % 4 == 1:
            for a in accounts:
                if ARCHETYPES[a.kind]["subscribed"]:
                    g = p.subscription_jc_per_month
                    led.mint("players_tier", g)
                    a.tier += g
                    sold_minted += g
                    revenue_usd += g * p.credit_price_usd
                    a.monthly[month][1] += g

        # 2b. A one-time credit pack, bought with money in week 6 by a fixed
        #     share of casual residents.  Also an issuance against a receipt.
        if week == 6:
            casuals = [a for a in accounts if a.kind == "casual"]
            for a in casuals[:int(len(casuals) * p.pack_buyer_share)]:
                led.mint("players_purchased", p.pack_jc)
                a.purchased += p.pack_jc
                sold_minted += p.pack_jc
                revenue_usd += p.pack_jc * p.credit_price_usd
                a.monthly[month][1] += p.pack_jc

        # 3. Contract rewards are reserved before acceptance: public contracts
        #    from the treasury, the rest from NPC employer budgets.  If neither
        #    can fund the work the contract is declined, never minted.
        desired = {a.aid: int(a.hours * p.jc_per_hour) for a in accounts}
        total_desired = sum(desired.values())
        pub_want = total_desired * p.public_contract_share
        npc_want = total_desired - pub_want
        pub_budget = max(0, led.acc["treasury"] - p.treasury_floor)
        npc_budget = max(0, led.acc["npc_sector"])
        pub_ratio = 1.0 if pub_want == 0 else min(1.0, pub_budget / pub_want)
        npc_ratio = 1.0 if npc_want == 0 else min(1.0, npc_budget / npc_want)
        ratio = (pub_ratio * p.public_contract_share
                 + npc_ratio * (1 - p.public_contract_share))
        weekly_funded.append(ratio)
        for a in accounts:
            from_pub = int(desired[a.aid] * p.public_contract_share * pub_ratio)
            from_npc = int(desired[a.aid] * (1 - p.public_contract_share) * npc_ratio)
            gross = from_pub + from_npc
            if gross <= 0:
                continue
            led.transfer("treasury", "players_earned", from_pub)
            led.transfer("npc_sector", "players_earned", from_npc)
            a.earned += gross
            a.monthly[month][0] += gross
            assessment = tax.assess(a.eligible, a.assessed, gross)
            a.eligible = assessment["after"]
            a.assessed = assessment["liability"]
            t = assessment["tax"]
            if t > 0:
                led.transfer("players_earned", "treasury", t)
                a.earned -= t
                tax_collected += t
            # Progress towards a first upgrade counts EARNED income only; the
            # starter grant is a faucet, not play time.
            a.net_earned_cum += gross - t
            if a.kind == "casual" and a.first_cottage_week == 0 and a.net_earned_cum >= 800:
                a.first_cottage_week = week

        # 4. Spending.  Items are transfers to NPC operators (zero marginal cost
        #    to the operator).  Compute/storage RETIRES credits and books a real
        #    cost.  Under option (i) semantics any balance may pay for either.
        for a in accounts:
            arch = ARCHETYPES[a.kind]
            spendable = a.balance
            want_item = int(spendable * arch["item_share"] * 0.35)
            want_service = int(spendable * arch["service_share"] * 0.35)
            a.monthly[month][2] += want_service

            pay_item = min(want_item, a.balance)
            if pay_item:
                _drain(led, a, pay_item, "operators", retire=False)
                item_flow += pay_item
            pay_service = min(want_service, a.balance)
            if pay_service:
                _drain(led, a, pay_service, None, retire=True)
                service_retired += pay_service
                cogs_usd += pay_service * p.cogs_usd_per_service_credit

        # 5. City upkeep pays service staff and suppliers.
        up = min(p.weekly_upkeep, led.acc["treasury"])
        led.transfer("treasury", "operators", up)

        led.check()
        supply = led.acc["players_earned"] + led.acc["players_purchased"] + led.acc["players_tier"]
        weekly_supply.append(supply)
        weekly_treasury.append(led.acc["treasury"])
        if runway_week == 0 and led.acc["treasury"] <= p.treasury_floor:
            runway_week = week

    return RunResult(
        label=p.label, params=p, accounts=accounts,
        weekly_supply=weekly_supply, weekly_treasury=weekly_treasury,
        weekly_funded_ratio=weekly_funded, tax_collected=tax_collected,
        npc_minted=npc_minted, npc_tax_to_treasury=npc_tax_to_treasury,
        grants_minted=grants_minted, sold_minted=sold_minted,
        service_retired=service_retired, item_flow=item_flow,
        revenue_usd=revenue_usd, cogs_usd=cogs_usd,
        runway_week=runway_week or p.weeks + 1, ledger=led,
    )


def _drain(led: Ledger, a: Account, amount: int, dst, retire: bool) -> None:
    """Spend order: tier -> earned -> purchased (the economy-lab order)."""
    left = amount
    for bucket, acct in (("tier", "players_tier"), ("earned", "players_earned"),
                         ("purchased", "players_purchased")):
        if left <= 0:
            break
        part = min(getattr(a, bucket), left)
        if part <= 0:
            continue
        setattr(a, bucket, getattr(a, bucket) - part)
        if retire:
            led.retire(acct, part)
        else:
            led.transfer(acct, dst, part)
        left -= part
    assert left == 0


# --------------------------------------------------------------------------
# Options (i)-(iv): settlement rules applied to the recorded demand
# --------------------------------------------------------------------------

def option_costs(run: RunResult) -> Dict[str, Dict[str, float]]:
    p = run.params
    months = max(len(a.monthly) for a in run.accounts)
    out: Dict[str, Dict[str, float]] = {}

    def blank():
        return {"service_credits": 0, "liability_usd": 0.0, "revenue_usd": 0.0,
                "farmer_credits": 0, "farmer_usd": 0.0}

    for name in ("i", "ii", "iii", "iv"):
        out[name] = blank()

    for m in range(months):
        earned_total = sum(a.monthly[m][0] for a in run.accounts if m < len(a.monthly))
        scale_iv = 1.0
        if earned_total > p.faucet_budget_credits:
            scale_iv = p.faucet_budget_credits / earned_total
        for a in run.accounts:
            if m >= len(a.monthly):
                continue
            earned_in, funded_in, demand = a.monthly[m]
            is_farmer = a.kind == "farmer"

            # (i) single fungible balance: any credit buys compute.
            served = min(demand, earned_in + funded_in)
            _book(out["i"], p, served, funded_in, is_farmer,
                  earned_part=max(0, served - funded_in))

            # (ii) dual: only purchased/tier credits reach real-cost services.
            served = min(demand, funded_in)
            _book(out["ii"], p, served, funded_in, is_farmer, earned_part=0)

            # (iii) dual + capped, reviewed conversion window.
            window = int(p.earned_service_cap * p.review_pass_rate)
            earned_part = min(max(0, demand - funded_in), window, earned_in)
            served = min(demand, funded_in) + earned_part
            _book(out["iii"], p, served, funded_in, is_farmer, earned_part=earned_part)

            # (iv) fungible, but faucet issuance capped city-wide per month.
            budgeted_earned = int(earned_in * scale_iv)
            served = min(demand, budgeted_earned + funded_in)
            _book(out["iv"], p, served, funded_in, is_farmer,
                  earned_part=max(0, served - funded_in))
    return out


def _book(bucket, p: Params, served: int, funded_in: int, is_farmer: bool,
          earned_part: int) -> None:
    bucket["service_credits"] += served
    bucket["liability_usd"] += served * p.cogs_usd_per_service_credit
    bucket["revenue_usd"] += funded_in * p.credit_price_usd
    if is_farmer:
        bucket["farmer_credits"] += earned_part
        bucket["farmer_usd"] += earned_part * p.cogs_usd_per_service_credit


# --------------------------------------------------------------------------
# Reading garden (scenarios/READING_GARDEN.md fixture)
# --------------------------------------------------------------------------

GARDEN_HORIZON = 200


def reading_garden(upkeep_income: int) -> Tuple[int, int, Ledger]:
    """Replays scenarios/READING_GARDEN.md: treasury 1,000, a 100 JC kit, four
    50 JC milestones, then 20 JC upkeep per service period with tax at zero."""
    led = Ledger({"treasury": 1000, "supplier": 0, "workers": 0, "services": 0})
    led.transfer("treasury", "supplier", 100)          # material kit
    for _ in range(4):
        led.transfer("treasury", "workers", 50)        # four accepted milestones
    after_build = led.acc["treasury"]
    periods = 0
    while led.acc["treasury"] >= 20 and periods < GARDEN_HORIZON:
        if upkeep_income:
            led.mint("treasury", upkeep_income)        # explicit issuance, labelled
        led.transfer("treasury", "services", 20)
        periods += 1
        led.check()
    return after_build, periods, led


# --------------------------------------------------------------------------
# Fixture ladders (deliverable D)
# --------------------------------------------------------------------------

@dataclass
class Ladder:
    name: str
    jc_per_minute: int
    session_minutes: int
    sessions_to_upgrade: int
    milestone_minutes: int
    job_minutes: int
    weekly_target_minutes: int

    def numbers(self) -> Dict[str, int]:
        m = self.jc_per_minute
        milestone = self.milestone_minutes * m
        cottage = self.sessions_to_upgrade * self.session_minutes * m
        return {
            "milestone": milestone,
            "garden": 4 * milestone,
            "job": self.job_minutes * m,
            "cottage": cottage,
            "workbench": int(round(cottage * 0.35 / 10) * 10),
            "weekly_exemption": self.weekly_target_minutes * m,
            "minutes_to_cottage": self.sessions_to_upgrade * self.session_minutes,
        }


LADDERS = [
    Ladder("L1 short evening", 10, 20, 6, 5, 40, 60),
    Ladder("L2 weekend build", 5, 40, 8, 10, 60, 120),
    Ladder("L3 slow homestead", 2, 30, 16, 15, 90, 90),
]


# --------------------------------------------------------------------------
# One-time block price vs perpetual hosting (deliverable E)
# --------------------------------------------------------------------------

def hosting_pv(monthly_usd: float, years: int, annual_rate: float = 0.08) -> float:
    r = (1 + annual_rate) ** (1 / 12) - 1
    return sum(monthly_usd / (1 + r) ** m for m in range(1, years * 12 + 1))


def years_covered(price_usd: float, monthly_usd: float, annual_rate: float = 0.08) -> float:
    r = (1 + annual_rate) ** (1 / 12) - 1
    acc = 0.0
    for m in range(1, 1201):
        acc += monthly_usd / (1 + r) ** m
        if acc >= price_usd:
            return m / 12
    return float("inf")


# --------------------------------------------------------------------------
# Assertions
# --------------------------------------------------------------------------

def run_assertions() -> None:
    rule = TaxRule()

    # OP05 worked example, reproduced exactly.
    a = rule.assess(already_eligible=900, already_assessed=0, gross=400)
    assert a["after"] == 1300, a
    assert a["liability"] == 30, a
    assert a["tax"] == 30, a
    assert a["net"] == 370, a
    player, employer, treasury = 500, 1000, 2000
    player += a["gross"]
    employer -= a["gross"]
    player -= a["tax"]
    treasury += a["tax"]
    assert (player, employer, treasury) == (870, 600, 2030), (player, employer, treasury)
    assert player + employer + treasury == 3500

    # Splitting one reward into small receipts cannot round the tax away.
    e, s, total = 900, 0, 0
    for _ in range(400):
        step = rule.assess(e, s, 1)
        e, s = step["after"], step["liability"]
        total += step["tax"]
    assert total == 30, total

    # ECONOMY.md worked accounting example conserves.
    led = Ledger({"resident": 1200, "treasury": 2000, "employer": 1000,
                  "supplier": 0, "services": 0})
    led.transfer("employer", "resident", 400)
    led.transfer("resident", "treasury", 40)
    led.transfer("resident", "treasury", 30)
    led.transfer("resident", "treasury", 50)
    led.transfer("resident", "supplier", 800)
    led.transfer("treasury", "services", 300)
    assert led.acc["resident"] == 680, led.acc
    assert led.acc["treasury"] == 1820, led.acc
    assert sum(led.acc.values()) == 4200
    led.check()

    # Reading garden fixture: 1,000 -> 700, then 35 periods at 20 JC.
    after, periods, garden = reading_garden(0)
    assert after == 700, after
    assert periods == 35, periods
    garden.check()

    # A 20 JC/period funded garden never closes within the horizon.
    _, funded_periods, _ = reading_garden(20)
    assert funded_periods == GARDEN_HORIZON, funded_periods

    # Option (ii) can never cost the operator more than the credits sold.
    run = simulate(Params(label="assert"))
    opts = option_costs(run)
    assert opts["ii"]["liability_usd"] <= opts["ii"]["revenue_usd"] + 1e-9
    assert opts["ii"]["farmer_usd"] == 0.0
    assert opts["i"]["farmer_usd"] > opts["iii"]["farmer_usd"] > 0

    # Ledger and per-account balances agree.
    total_players = sum(a.balance for a in run.accounts)
    ledger_players = (run.ledger.acc["players_earned"] + run.ledger.acc["players_purchased"]
                      + run.ledger.acc["players_tier"])
    assert total_players == ledger_players, (total_players, ledger_players)
    run.ledger.check()
    print("Assertions: OP05 example, split-receipt rounding, ECONOMY.md worked")
    print("example, reading-garden fixture, option (ii) bound and ledger/account")
    print("reconciliation all pass.")


# --------------------------------------------------------------------------
# Reporting
# --------------------------------------------------------------------------

def report_supply(runs: List[RunResult]) -> None:
    marks = [4, 13, 26, 39, 52]
    rows = []
    for r in runs:
        n = len(r.accounts)
        row = [r.label]
        for w in marks:
            row.append(jc(r.weekly_supply[w - 1] / n))
        avg_supply = sum(r.weekly_supply) / len(r.weekly_supply)
        flow = r.item_flow + r.service_retired
        row.append(f"{flow / avg_supply:.2f}")
        rows.append(row)
    table("Credit supply per account (JC) and velocity proxy",
          ["run"] + [f"wk{w}" for w in marks] + ["velocity"], rows,
          note="velocity proxy = year's spend flows / average player credit supply")


def report_treasury(runs: List[RunResult]) -> None:
    rows = []
    for r in runs:
        funded = sum(r.weekly_funded_ratio) / len(r.weekly_funded_ratio)
        runway = "> 52" if r.runway_week > r.params.weeks else str(r.runway_week)
        rows.append([
            r.label, jc(r.npc_minted), jc(r.npc_tax_to_treasury), jc(r.tax_collected),
            jc(r.grants_minted), jc(r.weekly_treasury[-1]), runway,
            f"{funded * 100:.0f}%",
        ])
    table("Treasury: faucets, runway and how much of the contract demand is funded",
          ["run", "NPC income mint", "NPC tax in", "player tax", "starter grants",
           "wk52 treasury", "runway wk", "rewards funded"], rows,
          note="NPC income mint is credit CREATION on the simulation clock; the NPC\n"
               "tax that reaches the treasury is a transfer of freshly minted money.\n"
               "runway = first week the treasury reaches its reserve floor")


def report_options(run: RunResult) -> None:
    p = run.params
    active = len(run.accounts)
    months = 13
    rows = []
    names = {
        "i": "(i) single fungible balance",
        "ii": "(ii) dual, earned buys only free things",
        "iii": "(iii) dual + capped reviewed window",
        "iv": "(iv) fungible, faucets budgeted",
    }
    opts = option_costs(run)
    for key in ("i", "ii", "iii", "iv"):
        o = opts[key]
        per_user_month = o["liability_usd"] / active / months
        rows.append([
            names[key], jc(o["service_credits"]), usd(o["liability_usd"]),
            usd(o["revenue_usd"]), usd(o["liability_usd"] - o["revenue_usd"]),
            usd(per_user_month), usd(o["farmer_usd"]),
        ])
    table(f"Operator liability under the four options ({run.label})",
          ["option", "service JC", "cost/yr", "credit revenue/yr", "net exposure/yr",
           "cost per acct/mo", "farmer take/yr"], rows,
          note=(f"placeholders: credit price {usd4(p.credit_price_usd)}, service cost "
                f"{usd4(p.cogs_usd_per_service_credit)}/credit, "
                f"{active} accounts incl. {p.farmer_alts} alts"))


def report_first_upgrade(run: RunResult) -> None:
    p = run.params
    weeks = [a.first_cottage_week for a in run.accounts
             if a.kind == "casual" and a.first_cottage_week]
    hours = [w * a.hours for w, a in
             zip(weeks, [a for a in run.accounts if a.kind == "casual" and a.first_cottage_week])]
    rows = [[
        "simulated casual resident",
        f"{min(weeks)}-{max(weeks)}",
        f"{min(hours):.1f}-{max(hours):.1f}",
        jc(p.jc_per_hour),
    ]]
    # Analytic: what each fixture implies if you pin a duration to it.
    anchors = [
        ("garden milestone at 3 min", 50 / 3 * 60),
        ("garden milestone at 6.5 min", 50 / 6.5 * 60),
        ("garden milestone at 10 min", 50 / 10 * 60),
        ("whole garden in 30 min", 200 / 30 * 60),
        ("one job in 20 min", 400 / 20 * 60),
        ("one job in 60 min", 400 / 60 * 60),
        ("one job in 3 hours", 400 / 180 * 60),
    ]
    for name, rate in anchors:
        rows.append([name, "-", f"{800 / rate:.1f}", jc(rate)])
    table("Time to the 800 JC cottage under today's unreconciled fixtures",
          ["anchor", "weeks", "hours of play", "implied JC/hour"], rows,
          note="the same fixture set implies 0.7 to 6.0 hours depending only on an\n"
               "undecided duration; nobody has decided how long a job or garden takes")


def report_ladders() -> None:
    rows = []
    for lad in LADDERS:
        n = lad.numbers()
        rows.append([
            lad.name, jc(n["milestone"]), jc(n["garden"]), jc(n["job"]),
            jc(n["cottage"]), jc(n["workbench"]), jc(n["weekly_exemption"]),
            f"{n['minutes_to_cottage']}",
            f"{lad.sessions_to_upgrade}x{lad.session_minutes}m",
        ])
    rows.append(["today's fixtures", "50", "200", "400", "800", "450", "1,000",
                 "undecided", "undecided"])
    table("Internally consistent placeholder reward ladders",
          ["ladder", "milestone", "garden", "job", "cottage", "workbench",
           "wk exemption", "min to cottage", "sessions"], rows,
          note="each ladder derives every price from JC/minute x minutes of ordinary\n"
               "play; placeholders for playtesting, not proposed rewards or prices")


def report_hosting() -> None:
    r = (1.08) ** (1 / 12) - 1
    rows = []
    for monthly in (0.35, 0.75, 1.50):
        row = [usd(monthly) + "/mo"]
        for years in (1, 3, 5, 10):
            row.append(usd(hosting_pv(monthly, years)))
        row.append(usd(monthly / r))          # perpetuity: C / monthly rate
        rows.append(row)
    table("Net present cost of hosting one home (8% annual discount)",
          ["placeholder hosting cost", "1 yr", "3 yr", "5 yr", "10 yr", "for ever"],
          rows,
          note="placeholder costs; no measured per-home storage or compute figure\n"
               "exists. 'for ever' is the perpetuity C/r at a flat cost - the whole\n"
               "infinite promise, which only holds if the cost never grows")

    rows = []
    for price in (5.0, 15.0, 30.0, 60.0):
        row = [usd(price)]
        for monthly in (0.35, 0.75, 1.50):
            y = years_covered(price, monthly)
            row.append("> 100" if y == float("inf") else f"{y:.1f} yr")
        rows.append(row)
    table("Years of hosting a one-time payment covers (break-even)",
          ["placeholder net proceeds", "at $0.35/mo", "at $0.75/mo", "at $1.50/mo"], rows,
          note="axis of a sensitivity table, NOT a proposed price; net proceeds are\n"
               "after payment fees and any consumer tax, which differ by market (RD11)")


def report_exemption_arbitrage() -> None:
    """The per-account exemption is an arithmetic invitation to split income."""
    rule = TaxRule()
    gross = 11000
    rows = []
    for accounts in (1, 2, 5, 11, 22):
        per = gross // accounts
        tax = rule.liability(per) * accounts
        grants = accounts * 500
        rows.append([
            str(accounts), jc(per), jc(tax), f"{tax / gross * 100:.1f}%",
            jc(grants), jc(gross - tax + grants),
        ])
    table("Per-account exemption and starter grant: splitting the same income",
          ["accounts", "gross each", "total tax", "effective rate",
           "starter grants", "kept + granted"], rows,
          note="OP05 placeholders: 1,000 JC exempt per account per period, 10% above.\n"
               "the same 11,000 JC of work pays 1,000 JC of tax on one account and\n"
               "nothing at all on eleven, and each account also collects a grant")


def report_garden() -> None:
    rows = []
    for income, name in ((0, "no upkeep source (today's fixture)"),
                         (10, "civic grant 10 JC/period"),
                         (20, "civic grant 20 JC/period"),
                         (25, "civic grant 25 JC/period")):
        after, periods, led = reading_garden(income)
        closes = f"open at {GARDEN_HORIZON}" if periods >= GARDEN_HORIZON else str(periods)
        rows.append([name, jc(after), jc(income), closes, jc(-led.acc["issuance"])])
    table("Reading garden: periods open before the insufficient-budget rule fires",
          ["upkeep funding", "treasury after build", "income/period",
           "periods open", "credits minted"], rows,
          note=f"horizon {GARDEN_HORIZON} periods. every non-zero upkeep source is an\n"
               "explicit mint; a labelled issuance account is the only honest way to\n"
               "record it, and under RD08 those credits can reach real compute")


def report_farming(runs: Dict[str, RunResult]) -> None:
    rows = []
    for label in ("exemption on, 10 alts", "exemption off, 10 alts",
                  "exemption on, 0 alts"):
        r = runs[label]
        farm = [a for a in r.accounts if a.kind == "farmer"]
        grants = len(farm) * r.params.starter_grant
        earned = sum(a.monthly[m][0] for a in farm for m in range(len(a.monthly)))
        opts = option_costs(r)
        rows.append([
            label, str(len(farm)), jc(grants), jc(earned),
            usd(opts["i"]["farmer_usd"]), usd(opts["ii"]["farmer_usd"]),
            usd(opts["iii"]["farmer_usd"]), usd(opts["iv"]["farmer_usd"]),
        ])
    table("Farmer: what alternate accounts extract per year under each option",
          ["run", "accts", "starter grants", "earned JC",
           "(i)", "(ii)", "(iii)", "(iv)"], rows,
          note="value extracted = operator real cost of the compute/storage the\n"
               "farmer's EARNED credits redeem; free accounts cost the farmer nothing")


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------

def main() -> int:
    print("=" * 78)
    print("Agentnagar economy model - toy simulation, placeholder parameters")
    print(f"seed {SEED} - all figures are structure and sensitivity, not forecasts")
    print("=" * 78)

    run_assertions()

    baseline = simulate(Params(label="baseline, clock x1"))
    clock10 = simulate(Params(label="NPC clock x10", clock=10))
    no_exempt = simulate(Params(label="no weekly exemption", use_exemption=False))
    no_alts = simulate(Params(label="farmer with 0 alts", farmer_alts=0))
    slow = simulate(Params(label="job-anchored earn rate", jc_per_hour=200))

    runs = [baseline, clock10, no_exempt, no_alts, slow]
    report_supply(runs)
    report_treasury(runs)
    report_first_upgrade(baseline)
    report_options(baseline)
    report_options(clock10)

    farm_runs = {
        "exemption on, 10 alts": baseline,
        "exemption off, 10 alts": no_exempt,
        "exemption on, 0 alts": no_alts,
    }
    report_farming(farm_runs)
    report_exemption_arbitrage()
    report_garden()
    report_ladders()
    report_hosting()

    print()
    print("Faucets in the baseline run (credits created, not transferred):")
    print(f"  NPC income created       {jc(baseline.npc_minted):>12} JC"
          f"   (x{baseline.params.clock} clock)")
    print(f"    of which taxed to city {jc(baseline.npc_tax_to_treasury):>12} JC"
          "   (transfer of minted money)")
    print(f"  starter grants           {jc(baseline.grants_minted):>12} JC"
          f"   ({len(baseline.accounts)} accounts)")
    print(f"  credits sold for money   {jc(baseline.sold_minted):>12} JC"
          f"   ({usd(baseline.revenue_usd)})")
    print("Sinks (credits destroyed):")
    print(f"  compute/storage retired  {jc(baseline.service_retired):>12} JC"
          f"   ({usd(baseline.cogs_usd)} real cost)")
    print(f"  ledger invariant         {jc(baseline.ledger.invariant):>12} JC"
          "   (signed sum across all accounts, unchanged)")
    print()
    print("Every figure above comes from the placeholder parameters at the top of")
    print("this file.  No price, rate, reward or cost here is a proposal.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
