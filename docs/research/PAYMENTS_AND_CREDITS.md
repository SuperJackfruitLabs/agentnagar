# Selling credits and residency from India to the world

Desk research · 2026-09-18 · [Plan index](../README.md)

**Evidence limits.** Desk research read from provider documentation, terms,
pricing pages and primary regulation on 18 September 2026. No account was
opened, no provider contacted, no transaction made and no adviser engaged.
Prices, acceptable-use lists and tax rules change without notice, and several
pages cited are marketing pages rather than contracts. Nothing here is legal,
tax or accounting advice; every Indian tax statement needs a chartered
accountant's confirmation against current law and the actual entity. Claims are
marked **[V]** verified at source (the official page was fetched and its
wording read), **[S]** secondary (a third party or a reproduction of an
official text), or **[U]** unverified — a lead, not a fact. Web search quota
was exhausted mid-pass, so some gaps are gaps in the search rather than
evidence of absence. **No provider is chosen here** (RD15).

This serves
[RD07–RD11](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18):
credits are earned, bought or included with a tier; they buy facility access,
items, compute and storage; a one-time payment buys a block and residency;
sponsorship is separate; the product is global. The
[economy brief](../gameplay/ECONOMY.md#open-questions-the-decisions-create)
lists the eight open questions those decisions create; this supplies evidence
for most and settles none.

## 1. Selling globally from India

### 1.1 The clause that matters most

Razorpay's Payments Terms, Part A, carry this wording twice — as a
representation and warranty, and as an item in the `PROHIBITED PRODUCTS AND
SERVICES` list that the terms make a ground for immediate suspension of service
and of settlement of monies **[V]** (`razorpay.com/terms/`, fetched
2026-09-18):

> You do not, and shall not, engage in any activity related to virtual
> currency, cryptocurrency and other crypto products (like non-fungible tokens
> or NFTs), prohibited investments for commercial gain or credits that can be
> monetized, re-sold or converted to physical or digital goods or services or
> otherwise exit the virtual world.

Read literally, "credits that can be … converted to … digital goods or
services" describes the JC design under RD07 plus RD08 exactly. Three readings
are possible and **only Razorpay can say which applies**: that the clause
targets crypto and cash-out ("otherwise exit the virtual world") and a
closed-loop credit is outside it; that it bars any purchasable in-world credit;
or that it turns on what the credit redeems for, which is the awkward part of
RD08, because compute and storage are real services. This is the
highest-value question to put to Razorpay in writing before any integration
work ([section 8](#8-questions-to-send)). The
[Razorpay integration brief](../integrations/payments/RAZORPAY.md) already
treats "cash-to-JC pack sales" as an open policy; this clause is why.

Two neighbouring items matter as well. Gaming/gambling is prohibited as
"lottery tickets, sports bets, memberships/enrolment in online gambling sites,
and related content", and the terms carry an express covenant not to use the
services for "any form of real money online gaming or an online money game …
as defined under the Promotion and Regulation of Online Gaming Act,
2025" **[V]**. That is aimed at real-money gaming, not a builder sandbox, but
it is another reason the
[cash-ticketed competition risk](../gameplay/ECONOMY.md#open-questions-the-decisions-create)
(open question 5) should stay closed until reviewed. The list also makes
dealing in "intangible goods/services (eg. software download…)" subject to the
partner or acquiring bank's opinion of what is "detrimental to the image and
interests" of the bank **[V]** — an Indian gateway relationship is always
revocable at the acquirer's discretion.

### 1.2 What Razorpay supports internationally

| Item | Evidence | Mark |
| --- | --- | --- |
| International cards, 160+ presentment currencies; settlement "in the bank accounts of Indian businesses in INR" | `razorpay.com/docs/payments/international-payments/` | [V] |
| Products that support international payments: Payment Gateway, Invoices, Payment Links, Payment Pages, **Subscriptions**. Route, Smart Collect, RazorpayX do not | same page | [V] |
| International card availability regions: India, Malaysia, Singapore, United States | `.../international-debit-credit-cards` | [V] |
| Activation: active KYC'd account; website must carry Terms, Privacy, Refund/Cancellation and Shipping policies; Import/Export code for tangible products; bank statements or settlement records evidencing prior international transactions; "business categories not supported by Razorpay" excluded | same page | [V] |
| PayPal: shown only when the purchase currency is not INR; funds land in the merchant's PayPal wallet, and "PayPal makes the settlements in INR"; PayPal sets the rates, Razorpay adds none | `.../payment-methods/wallets/paypal` | [V] |
| International Bank Transfer: local-currency virtual accounts (ACH, FPS, SEPA, NPP, EFT, SWIFT), "1% with Zero Forex Markup", settled in INR, "Receive your FIRC within minutes"; restricted to listed export purpose codes (software services P0802 among 40+) | `.../international-bank-transfer` | [V] |
| Pricing: 2% domestic per successful transaction; "Up to 3%" international cards; Subscriptions on cards 0.9% + platform fee; 18% GST on fees; ₹0 setup/AMC; T+1 settlement; custom pricing above ₹5,00,000/month | `razorpay.com/pricing` | [V] |
| Whether Subscriptions authenticate and recur reliably on **foreign-issued** cards; whether the Malaysia/Singapore/US group entities are a route for a non-Indian seller | neither stated on any page fetched | [U] |

The practical shape: **international cards through Razorpay are an activation,
not a default.** It asks for evidence of prior international transactions,
which a pre-revenue project does not have, and for four named website policy
pages the city does not yet have — a sequencing fact, not a blocker, since
nothing is built (RD15). Subscriptions are listed as internationally supported,
but the supported-methods page names only Visa, Mastercard and RuPay and reads
as written around Indian mandates **[V]**; recurring on foreign cards is the
specific thing to verify.

### 1.3 Stripe, PayPal and the other Indian gateways

- **Stripe India remains gated.** `stripe.com/en-in` offers "Request an invite"
  rather than a sign-up **[V]**. Pricing is published: 2% domestic, 3%
  international, 3.5% Amex international, 4.3% where presentment is USD or
  another currency, +2% where conversion is required, Billing 0.7% **[V]**.
  Possible but not self-serve; invitation criteria **[U]**.
- **PayPal India is export-only** — "For India users, we only support
  international payments" **[V]** — at 4.40% plus a fixed fee for senders
  outside India, 3.0% above base rate when converting received payments (4.00%
  otherwise), and no fee for a standard withdrawal without conversion **[V]**.
  FIRC is not mentioned on the fee page **[U]**.
- **PayU** publishes 2% domestic and 3% for "Diners, American Express, EMI,
  International transactions", 18% GST, T+2 settlement **[V]**. **Cashfree**
  could not be read (HTTP 403), so its international coverage, subscriptions
  and restricted categories are all **[U]**.

None of the Indian gateways is a merchant of record. With any of them the city
is the seller to every customer worldwide, and every consumption-tax obligation
in every market is the city's own.

## 2. Merchants of record

An MoR resells the product: it becomes the seller to the end customer, collects
and remits VAT/GST/sales tax in its own name, owns the chargeback, and pays the
developer a net amount. Dodo's terms put it plainly — "You appoint Dodo
Payments as your non-exclusive reseller of the Product across all territories …
This structure allows Dodo Payments to handle all Sales Tax collection,
reporting and remittance" **[V]**. For an Indian seller that converts a
worldwide B2C tax problem into one B2B export of services to one company.

### 2.1 Comparison

| Provider | Indian sellers | Headline fee | Payout to India | Subs / one-off / usage-credits | Virtual-currency or credits policy | Mark |
| --- | --- | --- | --- | --- | --- | --- |
| **Paddle** | not confirmed on any page read | 5% + 50¢; sub-$10 products need custom pricing | not published on pricing page | subs + one-off; metered billing not confirmed | **Prohibits** "Virtual currency or stored value, including but not limited to store credit, gift cards, vouchers"; also bans competitions/contests/games of chance and digital marketplaces | [V] policy, [U] India |
| **Lemon Squeezy** | payouts to "more than 200 countries" by bank wire or PayPal, twice monthly | 5% + 50¢, extra fees outside the US | wire or PayPal | subs + one-off; usage-based [U] | Prohibits services of any kind, physical goods, NFT/crypto, marketplaces, donations without product value; no explicit virtual-currency line found | [V] |
| **Polar** | **Yes, India is listed**, and the docs answer the India case directly | 5% + 50¢ (Starter) down to 3.4% + 30¢; **+1.5% international cards**; +0.5% subscriptions on one plan; payout 0.25% + $0.25 and $2/month | Stripe Connect Express; 7-day settlement delay for orgs created on/after 2026-05-12; minimum balance $10 USD (INR/BTN tier $40) | subs, one-off, usage meters, **a Credits benefit** | Prohibits "Donations, crowdfunding, community access, advertising, and sponsorship", human services, marketplaces, gambling incl. loot boxes, and "Trading and Financial Services, including (a) services facilitating transactions, investments, or **balances for customers**"; AI content generation and VPN/VPS/VDS need enhanced review | [V] |
| **Dodo Payments** | India-founded; payment currency "typically in USD, EUR, INR or GBP"; India domestic pricing published | 4% + 40¢ US domestic; **+1.5%** non-US; **+0.5%** subscriptions/add-ons/usage; India domestic cards and **UPI 4% + 15¢**; $1 per refund; $30 per dispute; standard payouts free, USD SWIFT $25; FX 2–4% charged to the customer | paid "on or before the 20th of the following month"; a reserve may be held per risk profile; set-off against the seller account | subs, one-off, **credit-based billing with rollover, overage and expiration controls**; documented "billing deconstructions" of OpenAI prepaid credits, Cursor, Lovable, Replicate | prohibited-business list not found at any URL tried | [V] fees/terms, [U] policy |
| **FastSpring**, **Creem** | — | Creem claims "190+ countries" in its docs index | — | — | acceptable-use and prohibited-product pages 404 at the URLs tried | [U] |

Cross-cutting notes:

- **Polar's India answer is explicit**: "any individual or company operating in
  our supported countries can receive payouts from Polar even if Stripe
  standalone is invite-only there … all payments from customers are made to
  Polar (US)" **[V]** — the cleanest documented route for an Indian solo founder
  to global checkout without a Stripe India account or a foreign entity.
- **But Polar bans the sponsorship lane** — "Donations, crowdfunding, community
  access, advertising, and sponsorship" is prohibited **[V]**, so RD10 needs a
  separate rail ([section 2.2](#22-the-sponsorship-lane-rd10)). And its
  **"balances for customers"** clause, in the financial-services ban, is the
  MoR analogue of the Razorpay clause; since Polar ships a Credits benefit and
  usage meters, the intent is presumably stored value as a financial product
  rather than metered prepay — an inference to check, not a policy
  statement **[U]**.
- **Paddle's virtual-currency ban is unambiguous** and reads directly onto a JC
  pack. Paddle looks closed unless Paddle says otherwise in writing.
- **Dodo is the only provider found that documents a prepaid-credit product**
  as a first-class feature, with rollover, overage and expiry controls and
  worked models of OpenAI-style prepaid credits **[V]**, and it supports Indian
  customers natively including UPI — the thing an MoR-only architecture
  otherwise breaks. Its restricted-business list was not found and its
  reserve/set-off clauses are broad; ask about both.
- **Every MoR reserves discretion.** Polar "reserves the right to refuse
  Services … in its sole discretion"; Dodo may "hold a certain percentage of
  the payments … as reserve" **[V]**. Review, freeze and reserve risk is real
  for a solo founder with one revenue stream.

### 2.2 The sponsorship lane (RD10)

| Platform | For an Indian recipient | Mark |
| --- | --- | --- |
| **GitHub Sponsors** | India appears in the supported-regions list on the About page. No fee on sponsorships from personal accounts ("100% … go to the sponsored developer"); "up to 6%" from organisation accounts, split 3% card processing + 3% GitHub service fee. Payouts to a bank account in a supported region "or via a fiscal host"; region of residence and of the bank account must match; W-8BEN for non-US recipients; up to 10 one-time and 10 monthly tiers, maximum US$12,000/month per tier, and a published tier's price cannot be edited | [V] |
| **Open Collective**, **Ko-fi**, **Patreon** | not reached: the post-2024 fiscal-host landscape and a for-profit Indian lab's eligibility; Ko-fi's fee tiers and whether Stripe/PayPal payout works from India; Patreon's Indian payout route, 2025 fee changes and VAT handling | [U] |

GitHub Sponsors is the one sponsorship rail **verified** as open to India today,
it is free at the personal tier, and its one-time plus monthly tiers map onto
RD10 without inventing anything. Two cautions: published tier prices are
immutable, forcing a versioned offer catalogue from day one; and perks make a
sponsorship consideration for a supply rather than a gift
([section 3](#3-tax-mechanics-for-an-indian-seller)).

## 3. Tax mechanics for an Indian seller

*Every item in this section is for a chartered accountant to confirm.*

### 3.1 Domestic and export

- **Registration.** Notification 10/2017-Integrated Tax (as amended by 3/2019)
  exempts persons "making inter-State supplies of taxable services and having
  an aggregate turnover … not exceeding … twenty lakh rupees in a financial
  year", ten lakh for special category states **[S]** (ICAI reproduction, not
  the CBIC site) — so selling across state lines does not by itself force
  registration. The 18% rate on digital services is **[U]** here.
- **Export of services** is zero-rated where the IGST s.2(6) conditions are met
  (supplier in India, recipient outside India, place of supply outside India,
  payment in convertible foreign exchange, not two establishments of one
  person); the mechanics are a letter of undertaking (Form RFD-11) or paying
  IGST and claiming a refund. Well established, but **not fetched [U]**.
- **Inward remittance evidence.** Razorpay's International Bank Transfer issues
  an FIRC "within minutes of the amount being credited" and is restricted to
  listed export purpose codes, software services being P0802 **[V]** — the
  cleanest documented FIRC path found. PayPal's Indian fee page does not
  mention FIRC **[U]**; eBRC/DGFT, IEC, s.194-O and GST TCS s.52 were **not
  reached [U]**. Paying an overseas model, cloud or MoR provider is an import
  of service, so **reverse-charge GST** is the usual answer and a live cost
  line once credits fund real compute **[U]**.

### 3.2 What an MoR changes

The Indian seller's customer becomes one foreign company: instead of many B2C
supplies in many countries, one B2B export of services per payout period, with
the MoR's remittance and the gateway's FIRC as evidence, while the MoR collects
and remits consumer tax worldwide in its own name. Two wrinkles are specific to
this project. **Indian customers would be buying from an Indian lab through a
foreign reseller** — Indian GST on that sale becomes the MoR's OIDAR problem,
and recurring mandates on Indian cards for a foreign merchant are exactly where
recurring fails most often; Dodo's INR/UPI support is the mitigation found
**[V]**, though whether it removes the problem is **[U]**. And **MoR fees
netted off a payout** may need treating as an import of service under reverse
charge even though no money moves outward — flag to the CA.

### 3.3 Selling direct, without an MoR

- **EU.** The non-Union OSS scheme covers "supplies of services to non-taxable
  persons taking place in the EU" by traders established outside the EU; the
  page describing it states no threshold for that scheme (it names a €150
  threshold only for the import scheme) **[V]**. A non-EU seller is therefore
  liable from the first euro and must register in one member state.
- **UK.** HMRC tells a business "based outside the UK" to register for UK VAT
  where its supplies are liable, defines digital services as those
  "automatically delivered over the internet … where there's minimal or no
  human intervention", and requires "2 pieces of information as evidence of
  where a consumer normally lives" **[V]**. No small-seller threshold is
  offered to an overseas supplier.
- **US.** Post-*Wayfair* economic nexus, state by state, with SaaS and digital
  goods taxable in many states **[U]**. Australia, Canada, Japan, Singapore,
  Norway and Switzerland all operate non-resident registrations **[U]**.

Selling direct globally therefore means a registration-and-filing programme in
several jurisdictions — for a solo founder, the decisive argument for an MoR,
independent of fees.

### 3.4 Are purchasable credits a voucher?

This is the sharpest Indian question RD07 opens, and there is a primary source.
**CBIC Circular 243/37/2024-GST, 31 December 2024** clarifies **[V]**:

> …the voucher is just an instrument which creates an obligation on the
> supplier to accept it as consideration or part consideration and the
> transactions in voucher themselves cannot be considered either as a supply of
> goods or as a supply of services. However, supply of underlying goods and/or
> services, for which vouchers are used as consideration or part consideration,
> may be taxable under GST.

On breakage it is equally direct: because there is no underlying supply when a
voucher is not redeemed, "such amount attributable to unredeemed vouchers
(breakage) would not be taxable" **[V]**. The circular reaches this by two
routes — an RBI-recognised prepaid instrument is "money" and so outside goods
and services; anything else is an actionable claim other than a *specified*
actionable claim and falls in Schedule III entry 6 **[V]**. The specified
carve-out covers "betting, casinos, gambling, horse racing, lottery or online
money gaming", another reason to keep paid-entry-plus-prize out of the design.

Separately, RBI's Master Directions on Prepaid Payment Instruments define a
closed system PPI as one "issued by an entity for facilitating the purchase of
goods and services from that entity only and do not permit cash withdrawal",
and state that issuing or operating such an instrument "is not classified as a
payment system requiring approval / authorisation by RBI and are, therefore,
not regulated or supervised by RBI" **[V]**. A no-cash-out, own-services-only
JC looks like a closed system PPI on that definition — which supports the
"no-cash-out" proposal in
[open question 3](../gameplay/ECONOMY.md#open-questions-the-decisions-create)
as a load-bearing design constraint, not a nicety.

**The open point for the CA:** whether a JC pack is a *voucher* (tax at
redemption, breakage untaxed) or an *advance for a service* (GST on receipt).
It turns on whether the underlying supply is determinable at sale. The answer
changes the cash-flow shape of every pack sale and must not be assumed.

On revenue recognition, IFRS 15 / Ind AS 115 treats a credit sale as a contract
liability until redemption, with breakage recognised in proportion to the
pattern of rights exercised **[U]** — cite a standard source before relying on
it. The consequence for a solo founder is real: **money received for credits is
not income yet, and it is already committed to future compute bills.**

## 4. How comparable products structure purchasable credits

### 4.1 Developer platforms selling prepaid usage

| Platform | Model | Expiry | Refund | Zero balance | Mark |
| --- | --- | --- | --- | --- | --- |
| Anthropic | prepaid credits, auto-reload on threshold | "Credits expire one year from the purchase date, and the expiration date can't be extended" | "All credit purchases are non-refundable"; credits "are not legal tender … have no cash value"; non-transferable | API calls stop; no debt | [V] |
| OpenAI | prepaid billing, auto-recharge | ~12 months | non-refundable | calls fail | [S] |
| OpenRouter | prepaid USD credits | "We reserve the right to expire unused credits after one year of purchase" | refund of unused credits only within 24 hours | stops | [V] |
| RunPod | prepaid only | none stated | "non-refundable and cannot be withdrawn once deposited" | **pods with a network volume are stopped and data preserved; pods without are terminated** | [V] |
| Fly.io | postpaid, optional prepaid credits, minimum $25; a prepaid card may buy credits but cannot be a saved payment method | — | — | — | [V] |
| Railway | post-paid card required ("helps us mitigate risk and fraud"); $5 one-time trial grant | — | — | "your subscription will be cancelled … we will stop all of your workloads" | [V] |
| Modal / Render / Vercel | monthly included allowance; caps and pauses rather than debt (Vercel pauses production deployments at a spend cap) | monthly | — | pause | [V] |

Note the shape: **prepaid means no debt**, and at zero balance the good designs
**stop compute but preserve storage** (RunPod's network-volume split).

### 4.2 Game and virtual-world currencies

| System | Pattern | Mark |
| --- | --- | --- |
| **Steam Wallet** | "funds have no cash value and are not exchangeable for cash"; "non-refundable and non-transferable"; funds "do not constitute a personal property right" | [V] |
| **Second Life** | virtual tender is a "limited, non-exclusive, revocable, non-assignable, personal, and non-transferable license"; users have "no property, proprietary, intellectual property, ownership, economic, or monetary interest" in it; the Lab may "modify, revalue" virtual goods. Cash-out exists only through a licensed money-transmitter subsidiary | [V] ToS, [S] Tilia |
| **Roblox** | Developer Exchange pays out only **Earned** Robux, minimum 30,000, "10,000 Robux = $38 USD", creators 13+ | [V] |
| **Fortnite / FTC 2022** | US$245m refund order over dark patterns and billing; Epic had "locked the accounts of customers who disputed unauthorized charges" | [V] |
| **Japan's Payment Services Act** | paid currency is a regulated prepaid instrument (deposit obligations, six-month expiry exemption); free/earned currency is not — the origin of the industry's dual paid/free balances and spend order | [S] |
| **EU CPC key principles on in-game virtual currencies, March 2025** | "clear and transparent pricing and pre-contractual information"; "avoiding practices hiding the costs of in-game digital content and services, as well as practices forcing consumers to purchase virtual currency"; "respect of consumers' right of withdrawal"; "respecting consumer vulnerabilities, in particular when it comes to children" | [V] |
| **Lovable, Cursor** (credits that buy real compute) | included monthly credits roll over only while subscribed and expire (Lovable: monthly grants expire two months after issue, top-ups twelve months); spend order is usage-specific grants first, then "the general credits closest to expiry first"; included usage before overage | [V] |

### 4.3 The design patterns to carry into the city

1. **Two balances, or one ledger with provenance.** Every mature system
   separates paid from free value, because legal treatment (Japan's PSA),
   cash-out eligibility (Roblox pays out only *Earned* Robux) and refunds all
   differ.
   [Open question 2](../gameplay/ECONOMY.md#open-questions-the-decisions-create)
   should be answered "two"; the harder half is which balance buys compute.
2. **Spend order: shortest-dated first**, as Lovable publishes — expiring
   grants before purchased top-ups.
3. **Only funded balances buy real-cost services.** Nothing in the precedent
   set lets a farmed balance draw on the operator's cloud bill. Earned JC
   reaching compute needs a separately capped, funded pool; the
   [NPC-tax mint problem](../gameplay/ECONOMY.md#open-questions-the-decisions-create)
   is the same hazard seen from the issuance side.
4. **Disclose expiry at purchase; do not expire purchased credits sooner than
   a year.** Anthropic and OpenRouter both use one year, and the EU principles
   require price and terms to be clear before contracting.
5. **No cash value, no transfer, no cash-out** — the Steam and Linden wording
   is the standard, and it is what keeps JC a closed system PPI outside RBI
   authorisation and (per [section 3.4](#34-are-purchasable-credits-a-voucher))
   taxed at redemption rather than at sale.
6. **Chargeback response must be proportionate.** Claw back unspent credits and
   suspend further purchases, but do not lock the customer out of what they
   lawfully bought — the FTC order against Epic is the caution.

### 4.4 Fraud: stolen cards become compute

Selling credits that redeem for GPU time is a known attack surface. Sourced
mitigations from operators who have been attacked:

- **Card verification before free compute.** GitLab, responding to crypto
  mining on shared runners, required new free users to supply a card validated
  by "a one-dollar authorization transaction. No charge will be made" **[V]**.
  Heroku ended free plans citing "an extraordinary amount of effort to manage
  fraud and abuse of the Heroku free product plans" **[V]**; Railway requires a
  post-paid card and grants $5 of trial **[V]**; Fly.io allows a prepaid card
  to buy credits but not to be a saved payment method **[V]**.
- **Ramps tied to payment history.** OpenAI's tiers unlock on cumulative paid
  amounts; Anthropic places new organisations in an Evaluation tier with
  below-standard limits, "part of how Anthropic prevents fraud and abuse", and
  throttles sharp usage increases **[V]**. Replicate charges early the first
  time usage crosses certain limits because it "helps us catch fraud before it
  becomes a problem" **[V]**.
- **Card testing on top-up forms.** Stripe documents that "card testers create
  small amount payments, which cardholders are less likely to notice", and
  recommends requiring "login or session validation before they can make a
  payment", IP velocity limits, CAPTCHA, Radar rules limiting cards per
  account, and proactively refunding suspicious payments **[V]**. A JC pack
  page is exactly the small-value form these attacks target. Stripe also
  describes 3DS as shifting liability for fraudulent payments **[V]**.

Posture to consider later: credits purchasable at any tier, but **compute and
storage redemption gated** — a hold between first payment and first high-cost
job, a low per-day compute ceiling for new payers, no GPU-class work until a
payment has aged past the chargeback window, per-person rather than per-account
limits, and storage preserved but compute halted at zero.

## 5. One-time purchase versus perpetual hosting cost

RD09 sells a block and residency once; hosting it costs money every month.
[Residency](../gameplay/RESIDENCY.md#what-a-tier-includes-and-for-how-long)
already names this trap. The precedents that bound the liability:

- **Define the term in the contract.** pCloud's lifetime plan runs "for the
  duration of the lifetime of the account owner or 99 years, whichever is
  shorter" **[V]** — a "lifetime" that is really a defined term.
- **Charge upkeep in the in-world currency.** Second Life sells land, then
  charges a monthly USD tier — 512 m² $4, 1,024 m² $7, 4,096 m² $22, a full
  region $166, with Premium including 1,024 m² **[V]**. The city's equivalent
  is upkeep in JC, which stops a one-time purchase from implying unlimited
  real-money hosting.
- **Cap resources per unit.** Render's free tier is capped (750 instance hours
  a month; free Postgres "expire 30 days after creation") **[V]**; Modal grants
  a fixed monthly compute allowance **[V]**.
- **Archive, do not delete.** RunPod preserves data on network volumes at zero
  balance and terminates only ephemeral pods **[V]**; pCloud deletes free
  accounts only after a stated 12 months of inactivity **[V]**. Vercel pauses
  deployments at a spend cap rather than billing on **[V]**.
- **Reserve the right to revalue.** Linden's ToS reserves the right to "modify,
  revalue, or make the Virtual Goods and Services more or less common,
  valuable, effective, or functional" **[V]**.

Not verified **[U]**: AppSumo's lifetime-deal definition and refund window,
documented LTD failures, MMO lifetime subscriptions and founder packs, and MMO
housing upkeep specifics (FFXIV's 45-day auto-demolition, Ultima Online decay).
Cite these from official pages before using them in a design argument.

The shape that follows from the evidence: **the one-time price buys the claim
and a defined hosting term; continuation is bought with upkeep in credits; on
lapse the home is archived with an export, not deleted; per-block resources are
capped; and the terms say what happens if the city sunsets.**

## 6. Subscriptions across regions

A subscription tier (RD07) is the hardest instrument to run globally, because
recurring authorisation is regulated differently in each market.

- **India — RBI e-mandates.** Recurring card payments need a registered
  e-mandate with additional-factor authentication. RBI circular
  RBI/2023-2024/88 of 12 December 2023 "decided to increase the limit from
  ₹15,000/- to ₹1,00,000/- per transaction for … (a) subscription to mutual
  funds, (b) payment of insurance premiums, and (c) credit card bill
  payments" **[V]**. A city subscription is in none of them, so ₹15,000 per
  frictionless debit is the ceiling — far above any plausible tier price. The
  friction is mandate registration and pre-debit notification, not the cap.
- **Razorpay's implementation** offers cards (Visa, Mastercard, RuPay), UPI
  AutoPay "Up to ₹1,00,000 (mandate creation)" with "Frictionless debits:
  ₹15,000 (all) / ₹1,00,000 (BFSI only)", and eNACH up to ₹1,00,00,000 **[V]**.
  UPI AutoPay is what Indian consumers actually complete, and a foreign MoR
  generally cannot offer it — the strongest argument for an Indian rail.
- **EU/UK — SCA.** Per Stripe, card payments need 3D Secure to meet SCA; the
  customer authenticates once on-session and later charges run as
  merchant-initiated transactions under a recorded mandate covering "the
  customer's permission …, the anticipated frequency of payments … [and] how
  you determine the payment amount" **[V]**. Exemptions "aren't guaranteed, and
  off-session payments might still require authentication".
- **Dunning, pause, proration, downgrade** were not researched provider by
  provider **[U]**, beyond Dodo advertising pause/resume, scheduled plan changes
  and a "DoNotBill" proration mode **[V]**, and Polar and Paddle bundling churn
  recovery into their fee. The rule this project needs is already in the
  [Razorpay brief](../integrations/payments/RAZORPAY.md#recurring-allowances):
  one confirmed charge grants exactly one period, and a failed renewal must
  never re-grant a period on every retry.

One further rule follows from
[section 4](#43-the-design-patterns-to-carry-into-the-city): a recurring credit
grant must stop when the subscription stops, and a lasting one-time tier must
not carry a recurring grant — otherwise one past payment funds a perpetual real
compute bill.

## 7. Architectures

| | A. Razorpay only | B. Razorpay (India) + MoR (rest of world) | C. MoR only | D. Stripe via a foreign entity | E. Sponsorship rail, alongside any of A–D |
| --- | --- | --- | --- | --- | --- |
| Fees | 2% domestic, up to 3% international, +0.9% subscriptions, +18% GST | as A for India; 4–5% + fixed for the rest | 4–5% + fixed, +1.5% international, +0.5% subs | ~2.9% + 30¢ plus entity costs | 0% personal / up to 6% org on GitHub Sponsors |
| Consumption tax | **the city's own problem in every market**: EU OSS, UK VAT, US nexus, others | Indian GST in-house; the MoR covers the rest | MoR covers everything | still the city's problem unless an MoR sits on top | GitHub handles its own; the receipt is still the lab's income |
| Credits / virtual-currency policy risk | **High and specific** — the prohibited-list clause quoted in §1.1 | High for the India leg, plus the MoR's own list | Paddle: closed on its face. Polar: "balances for customers" needs asking. Dodo: documents credit billing but its list is unread | Stripe's restricted list not read in this pass [U] | Perks make it consideration; tier prices immutable |
| Effort for one founder | one integration, one entity, many tax registrations | two integrations, two reconciliations, still Indian GST | one integration, one tax relationship, one payout stream | entity formation, foreign banking, transfer pricing, ongoing compliance | trivial to start |
| Indian customers | native (UPI, cards, e-mandate) | native | only if the MoR supports INR/UPI — Dodo does [V], others unverified | poor: foreign-merchant recurring on Indian cards | fine |
| Biggest open item | will Razorpay allow credit packs at all? | double the policy surface for the same product | is a credit pack an allowed product? | does a foreign entity make sense at zero revenue? | sponsorship's tax character |

Evidence still needed before any of these can be chosen is the list in
[section 8](#8-questions-to-send): A and B turn on Razorpay's answer, C on the
MoR's, and E on the perk rules in GitHub Sponsors' terms. **D was not
researched here at all [U]** and is likely premature at zero revenue.

## 8. Questions to send

**To Razorpay (support ticket, in writing, keep the reply):**

1. We sell in-game credits for real money. They are spendable only inside our
   product, cannot be cashed out, transferred or traded, and redeem for in-game
   items and for metered compute and storage we provide. Does the
   prohibited-products entry beginning "Virtual currency, cryptocurrency and
   other crypto products … or credits that can be monetized, re-sold or
   converted to … digital goods or services" prohibit this? If not, will you
   confirm in writing before we integrate?
2. Do Subscriptions support recurring charges on cards issued outside India,
   and which networks and geographies actually authenticate?
3. What are the international-card activation requirements for a merchant with
   no prior international transaction history, and what evidences inward
   remittance for international **card** receipts (FIRC/FIRA)?
4. Is our category — an online world selling subscriptions, one-time purchases
   and credit packs — acceptable to the partner and acquiring banks?

**To one merchant of record (Polar or Dodo first — both document India):**

1. Is a prepaid credit pack, redeemable only inside our product for digital
   items and for metered compute/storage, acceptable? Point to the clause.
2. Polar specifically: does "Trading and Financial Services … services
   facilitating … balances for customers" cover a usage-credit balance, given
   that you ship a Credits benefit and usage meters?
3. Can an Indian sole proprietorship or private limited company onboard, with
   what KYC? Payouts to India: method, currency, minimum, frequency,
   settlement delay, and what documentation an Indian exporter can use as
   remittance evidence.
4. Do you collect Indian GST from Indian consumers, and do Indian card
   recurring mandates work?
5. Reserve policy, chargeback fee, and what triggers review or freeze. May we
   run a second payment rail for the same product in one market?

**For Rakesh:**

1. Is "no cash-out, ever" a decision? It is what keeps JC a closed system
   outside RBI authorisation, and it shapes every other answer.
2. One balance or two, and may earned credits ever reach compute?
3. What hosting term does the one-time block price buy, and is upkeep in
   credits acceptable?
4. Is an MoR acceptable, given it becomes the seller of record? And which
   entity sells — sole proprietorship or private limited company? Several
   answers above depend on that.

## Sources

All accessed 2026-09-18.

**Razorpay** — `razorpay.com/terms/` (terms and prohibited products),
`razorpay.com/pricing/`, and under `razorpay.com/docs/payments/`:
`international-payments/`, `.../international-debit-credit-cards`,
`.../international-bank-transfer`, `payment-methods/wallets/paypal/`,
`subscriptions/` and `subscriptions/supported-payment-methods/`.

**Stripe** — `stripe.com/en-in` and `/en-in/pricing`; and under
`docs.stripe.com/`: `strong-customer-authentication`,
`disputes/prevention/card-testing`, `payments/3d-secure`.

**Other gateways** — `paypal.com/in/webapps/mpp/merchant-fees`;
`payu.in/pricing/`; `cashfree.com/pricing/` (403, unread).

**Merchants of record** — `paddle.com/pricing` and
`paddle.com/help/start/intro-to-paddle/what-am-i-not-allowed-to-sell-on-paddle`;
`lemonsqueezy.com/pricing` and
`docs.lemonsqueezy.com/help/getting-started/prohibited-products`;
`polar.sh/docs/merchant-of-record/` (`fees`, `supported-countries`,
`acceptable-use`), `polar.sh/docs/features/finance/payouts` and
`.../benefits/credits`; `dodopayments.com/pricing`,
`dodopayments.com/legal/terms-of-use` and
`docs.dodopayments.com/developer-resources/billing-deconstructions/openai`.
**Sponsorship** — `docs.github.com/en/sponsors/` under
`getting-started-with-github-sponsors/about-github-sponsors` and
`receiving-sponsorships-through-github-sponsors/`.

**Regulation and tax** — RBI Master Directions on Prepaid Payment Instruments,
`rbi.org.in/Scripts/BS_ViewMasDirections.aspx?id=12156`; RBI e-mandate circular
RBI/2023-2024/88 of 12 December 2023,
`rbi.org.in/Scripts/NotificationUser.aspx?Id=12570`; CBIC Circular
243/37/2024-GST of 31 December 2024,
`gstcouncil.gov.in/sites/default/files/2025-01/circular-no-243-2024.pdf`;
Notification 10/2017-Integrated Tax as amended, ICAI reproduction at
`d23z1tp9il9etb.cloudfront.net/download/gstlaw/`; HMRC,
`gov.uk/guidance/the-vat-rules-if-you-supply-digital-services-to-private-consumers`;
`vat-one-stop-shop.ec.europa.eu/one-stop-shop/declare-and-pay-oss_en`; EU CPC
key principles on in-game virtual currencies (March 2025), PDF
`8af13e88-6540-436c-b137-9853e7fe866a_en` under
`commission.europa.eu/document/download/`.

**Credits, compute and fraud** — `support.claude.com/en/articles/8977456`,
`anthropic.com/legal/credit-terms`, `platform.claude.com/docs/en/api/rate-limits`;
`developers.openai.com/api/docs/guides/rate-limits`; `openrouter.ai/docs/faq`;
`docs.runpod.io/get-started/billing-information`;
`replicate.com/docs/topics/billing`; `fly.io/docs/about/billing/`;
`docs.railway.com/reference/pricing/plans`; `render.com/docs/free`;
`modal.com/pricing`; `vercel.com/docs/spend-management`;
`docs.lovable.dev/user-guides/messaging-limits`; `cursor.com/docs/account/billing`;
`heroku.com/blog/next-chapter`;
`about.gitlab.com/blog/2021/05/17/prevent-crypto-mining-abuse/`.

**Virtual currencies and lifetime terms** —
`store.steampowered.com/subscriber_agreement/`; `lindenlab.com/tos`;
`secondlife.com/land/pricing`;
`create.roblox.com/docs/production/earning-on-roblox`; FTC v. Epic Games press
release of 19 December 2022 at `ftc.gov/news-events/news/press-releases/2022/12/`;
`pcloud.com/terms_and_conditions.html`.

**Not verified in this pass:** Cashfree; FastSpring and Creem policies and India
availability; Paddle's supported seller countries; Patreon, Ko-fi and Open
Collective for Indian recipients; Stripe's restricted-business list; US state
sales-tax exposure and the Australian, Canadian, Japanese and Singaporean
regimes; IGST s.2(6)/s.16 and LUT mechanics from a primary source; eBRC, IEC,
s.194-O and GST TCS; reverse charge on MoR fees; Ind AS 115 breakage; OpenAI's
prepaid terms at source; AppSumo lifetime-deal terms; MMO housing upkeep and
lifetime subscriptions; Japan's Payment Services Act; and, above all, whether
any MoR will accept a credit pack redeemable for compute.
