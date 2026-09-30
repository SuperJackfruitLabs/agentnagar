# Legal and compliance exposure of the planned city

Desk research · 2026-09-18 · [Plan index](../README.md)

This brief maps the laws that the 2026-09-18 decisions
([RD01–RD17](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18))
bring into play for a global, credit-funded, user-generated, agent-populated
city run from India by a solo founder. It covers India, the EU/UK, the US and
cross-cutting questions, then closes with ranked design guardrails and a ranked
list of questions for a lawyer and a chartered accountant. It informs the
[economy](../gameplay/ECONOMY.md), [community charter](../vision/COMMUNITY_CHARTER.md)
and [operating model](../vision/OPERATING_MODEL.md); it does not decide anything.

**Evidence limits.** This is desk research by a non-lawyer, not legal advice,
and nothing here should be relied on without a professional's confirmation.
Laws in every section changed within the last eighteen months and several are
still moving (RBI's PPI directions are a draft; the EU Digital Fairness Act is
not yet proposed; India's Online Gaming Authority has only just begun issuing
determinations). Each claim is tagged: **FACT** means the statement was read
in a primary source (statute, regulator, official guidance) or, where marked
"(secondary)", in a reputable law-firm or regulator-adjacent summary;
**INFERENCE** is this brief's reading of how a rule meets this design;
**OPEN** is a question nobody here can answer. Primary sources verified during
this pass: the Online Gaming Bill text as introduced (Act reportedly passed
unchanged), Anthropic's usage policy and commercial terms, Google's Gemini API
terms, FinCEN's 2019 CVC guidance and its 2011 prepaid-access release, the
FTC's Genshin press release and the Copyright Office DMCA directory FAQ.
Everything else, including all India Rules of 2025–2026, the DSA, the UK
Online Safety Act guidance and the RBI draft, came from law-firm or press
summaries because the primary hosts (PIB, RBI, eCFR, OpenAI) refused
automated fetches. Claims that could not be verified are listed at the end of section 5.
All URLs were accessed on 2026-09-18.

## How the design creates exposure

| Decision | What it does legally | Sections |
| --- | --- | --- |
| RD07/RD08 credits bought with money, spent on compute/storage/items | Creates a prepaid, closed-loop stored value; the "purchased credits" fact is exactly what India's "other stakes" definition and the EU/US virtual-currency positions look at | 1.1, 1.4, 2.3, 3.2, 3.3 |
| RD09/RD10 one-time residency purchase; sponsorship with perks | Consumer sale of a digital service with a duration; sponsorship is revenue, not a gift | 1.5, 2.3, 4.6 |
| RD05 comments, messages, assemblies | Hosting user-generated content: intermediary due diligence (India), DSA (EU), OSA (UK), s.230/DMCA (US) | 1.3, 2.2, 2.5, 3.4 |
| RD03/RD04 public observation, tiered interaction with agents | AI disclosure duties; public work-state may expose third-party or confidential material | 2.4, 4.3, 4.4 |
| RD11 global | Every market's privacy, consumer and age rule applies at once; GST/VAT and FEMA on receipts | 1.2, 1.5, 2.1, 3.5, 4.7 |
| RD12 private personal agents | Processing of the owner's data by a third-party model provider; provider terms on personas and resale | 4.3 |
| Ticketed competitions with rewards (ECONOMY, charter) | The prize + consideration + (chance) pattern that gambling, sweepstakes and India's money-game ban target | 1.1, 3.6 |
| Adult-only by self-attestation (charter) | Self-attestation satisfies none of the age-assurance regimes on its own; it is a scope choice, not compliance | 1.2, 2.5, 3.1, 4.1 |

## 1. India

### 1.1 Promotion and Regulation of Online Gaming Act 2025 and Rules 2026

**FACT (primary, Bill text; Act reported passed unchanged).** The Act extends
"to the whole of India and also applies to online money gaming service offered
within the territory of India or operated from outside the territory of
India". Its definitions, s.2(1):

- *online money game*: "an online game, irrespective of whether such game is
  based on skill, chance, or both, played by a user by paying fees, depositing
  money or other stakes in expectation of winning which entails monetary and
  other enrichment in return of money or other stakes; but shall not include
  any e-sports";
- *other stakes*: "anything recognised as equivalent or convertible to money
  and includes credits, coins, token or objects or any other similar thing, by
  whatever name called and whether it is real or virtual, which is purchased
  by paying money directly or by indirect means or as part of, or in relation
  to, an online game";
- *online social game*: does not involve staking of money or other stakes or
  participation "with the expectation of winning by way of monetary gain in
  return of money or other stakes"; "may allow access through payment of a
  subscription fee or one-time access fee, provided that such payment is not
  in the nature of a stake or wager"; offered solely for entertainment,
  recreation or skill development;
- *e-sport*: organised competitive events, recognised under the National
  Sports Governance Act 2025 and registered with the Authority; "may include
  payment of registration or participation fees solely for the purpose of
  entering the competition or covering administrative costs and may include
  performance-based prize money".

**FACT (secondary).** Offering an online money gaming service carries up to
three years' imprisonment and/or a fine up to ₹1 crore; advertising it up to
two years/₹50 lakh; facilitating financial transactions for it up to three
years/₹1 crore (PRS summary). The Rules were notified on 22 April 2026 and the
Act and Rules commenced on 1 May 2026; the Online Gaming Authority of India is
constituted under s.8 (Khaitan, Medianama). Registration is mandatory for
e-sports and for any category of game the Central Government notifies; other
online social games need no registration unless notified, but the Authority
can *suo motu* direct a determination and, in deciding whether a game is a
money game, examines "the presence of entry fees or deposits, extent of
involvement of bets/wager, the expectation of monetary or other rewards, the
structure of the revenue model, and the extent to which in-game assets can be
monetised", including "whether rewards, benefits, or in-game assets can be
transferred, redeemed, monetised, or used outside the game environment"
(Khaitan; Medianama). A determination is provider-and-game specific and lapses
on "any update that can potentially affect payments or authorisation of
funds". Providers must not describe a game as "approved" without a
determination; must keep a grievance mechanism (user → provider → Authority
within 30 days → appellate authority); and social-game providers may be
directed to retain traffic data and metadata on computer resources in India.
Banks and payment facilitators must verify a determination or registration
before facilitating funds for a game — Razorpay is therefore a gate as well as
a provider.

**INFERENCE — how this meets the design.**

1. Purchased city credits are squarely "other stakes": they are virtual
   credits "purchased by paying money … in relation to an online game". That
   alone is not fatal; the money-game test needs *staking them in expectation
   of winning* something that entails "monetary and other enrichment".
2. The safe pattern is the *online social game*: subscription or one-time
   access fees (RD07 tiers, RD09 residency) are expressly allowed if not "in
   the nature of a stake or wager". Spending credits on facility access,
   items, compute and storage (RD08) is a purchase, not a wager, provided
   nothing spent can come back multiplied.
3. The dangerous pattern is any loop in which purchased credits (or cash) are
   paid *to enter* something whose *outcome pays credits or anything of
   value*. The charter's "ticketed competitions with rewards" and the
   ECONOMY's "advertised JC OR cash ticket" plus match rewards is that loop.
   "Other enrichment" is undefined and the Rules look at whether rewards can
   be "transferred, redeemed, monetised, or used outside the game"; credits
   that buy real compute are arguably usable "outside the game environment".
4. Earned-only credits used as entry to earned-only rewards are much closer to
   an ordinary game economy, because nothing "purchased by paying money" is
   staked. This is the strongest argument for separate earned and purchased
   balances with purchased credits barred from any entry fee, wager, or
   randomised reward (see guardrails).
5. Even a small hobby competition with cash entry and a prize is, on the text,
   at risk unless run as a recognised e-sport — which requires recognition
   under a sports statute and registration, unrealistic for a city event.
6. Foreign users do not help: the Act applies to services operated from
   India regardless of who plays.

**OPEN (lawyer).** Whether compute/storage bought with credits is "monetary and
other enrichment" or "use outside the game environment"; whether a free-entry
competition whose prize is *earned* credits or cosmetics is safe; whether to
seek a voluntary determination early (a favourable order is provider-specific
and lapses on payment-affecting changes, so timing matters); whether the
Authority's standards on user verification and deposits will reach social
games with paid credits.

### 1.2 Digital Personal Data Protection Act 2023 and DPDP Rules 2025

**FACT (secondary; PIB/MeitY notification summarised by AMSS, EY).** The Rules
were notified on 14 November 2025 with phased commencement: Board
constitution immediately; consent-manager registration and Board enforcement
from 14 November 2026; the substantive duties — notice and consent, security
safeguards, breach reporting to the Board and affected persons, children's
consent, significant-data-fiduciary (SDF) duties, data-principal rights and
cross-border rules — from **14 May 2027**. The Act applies to processing in
India and to processing outside India "in connection with any activity related
to offering of goods or services to Data Principals within the territory of
India" (s.3). A *child* is anyone under 18; processing a child's data requires
**verifiable parental consent** with due diligence on the parent's identity
(government-issued details or virtual tokens such as DigiLocker), and
behavioural monitoring or targeted advertising directed at children is
prohibited (s.9). The Fourth Schedule exempts named classes and purposes; one
exemption covers processing "limited to confirming that the data principal is
not a child". Data fiduciaries must retain personal data, traffic data and
processing logs for at least one year; specified large e-commerce, social
media and gaming intermediaries must erase data after three years of user
inactivity. SDFs are notified by the Central Government on volume and
sensitivity factors and carry DPIA, audit, DPO and algorithm-assessment duties,
and may be barred from transferring notified data outside India. For everyone
else, cross-border transfer is allowed except where the Central Government
restricts it (Rule 15, blocklist model).

**INFERENCE.** Nothing in the DPDP framework bites before May 2027, but the
design cannot postpone the age architecture: if a person under 18 registers,
the only lawful path is verified parental consent, which a solo operator
cannot realistically run at launch. An adult-only scope plus a proportionate
age check is the practical answer, and the "confirming not a child" exemption
suggests the drafters expect exactly that check. Hosting outside India is
allowed for a non-SDF; the one-year log-retention duty and the gaming-rule
data-retention direction (1.1) both push some logs onto Indian
infrastructure. SDF thresholds are unlikely to be met for years.

**OPEN.** What "verifiable" means for a global adult gate in practice;
whether the city counts as a "gaming" intermediary for the retention schedule;
whether personal-agent conversations (RD12) sent to a foreign model provider
need contractual terms beyond the provider's DPA.

### 1.3 IT Act intermediary rules, as amended February 2026

**FACT (secondary; Khaitan, MeitY FAQ).** The IT (Intermediary Guidelines and
Digital Media Ethics Code) Amendment Rules 2026 took effect on 20 February
2026. All intermediaries must: publish rules, privacy policy and user
agreement; remind users of the rules "at least once every three months";
appoint a resident Grievance Officer who acknowledges complaints within 24
hours and resolves them within 7 days (15 before), with 36 hours for unlawful
content and 2 hours for non-consensual intimate imagery or CSAM; act on court
or government takedown orders within 3 hours (2 hours for morphed or intimate
imagery); and preserve records for investigation. New rule 3(3) defines
*synthetically generated information* (audio, visual or audio-visual content
created or altered to appear real; text-only content is excluded) and requires
platforms that enable its creation to label it prominently; user declarations
and technical verification of SGI fall only on significant social media
intermediaries (5 million+ registered Indian users). Grievance-officer,
takedown and periodic-notice duties apply to intermediaries of any size.

**INFERENCE.** RD05 makes the city an intermediary for user text and events
the moment accounts open. The 3-hour takedown and 2-hour imagery windows are
the single hardest operational duty in this brief for a one-person operator;
the charter's "no 24-hour emergency service" promise conflicts with them. If
agents render images or audio in-world that could pass as real, SGI labelling
applies; text output does not. Safe-harbour under s.79 depends on observing
this diligence.

**OPEN.** Whether a world in which AI characters speak counts as "enabling
creation" of SGI; how the 2-hour/3-hour windows can be met with automated
triage and what a regulator would accept from a micro operator.

### 1.4 RBI prepaid payment instruments

**FACT (secondary; Mondaq/JSA, Lexology, nasscom).** Under the 2021 Master
Directions, *closed system PPIs* — "issued by an entity for purchase of goods
or services from that entity alone", no cash withdrawal, no third-party
settlement — are not a payment system and need no RBI authorisation. The
Draft RBI (Prepaid Payment Instruments) Directions 2026 (22 April 2026,
comments closed 22 May 2026, not final at the time of writing) drop the
formal category but preserve the exemption for such instruments issued by any
entity "other than a marketplace", a marketplace being an e-commerce entity
providing a platform for buyer–seller transactions (aligned with the 2025
Payment Aggregator directions).

**INFERENCE.** Credits redeemable only for the operator's own facility access,
items, compute and storage sit inside the exemption. Two features would take
them out: (a) letting residents sell things to each other for credits that
were bought with money, which starts to look like a marketplace instrument
and third-party settlement; (b) any cash redemption or transfer for value.
"Trade" between residents in the ECONOMY brief should therefore be restricted
to earned credits, or the platform must remain the seller of record. OP11's
"real commercial work is separately declared" already points this way.

**OPEN.** Whether resident-to-resident credit transfers, even earned-only,
would be read as a marketplace; the final text of the 2026 directions.

### 1.5 GST, consumer e-commerce rules and dark patterns (brief)

**FACT (secondary; India Briefing, industry guides).** Supplies of digital
services by an Indian supplier to a recipient outside India are exports of
services (place of supply = recipient's location, IGST Act s.13; OIDAR
rules mirror this), zero-rated, and can be made without paying IGST under a
Letter of Undertaking; registration is required regardless of turnover for
inter-state and export supplies. Domestic sales of credits, tiers and
residency are taxable services (18% is the usual rate for online services;
confirm rate and classification with the CA). The Consumer Protection
(E-Commerce) Rules 2020 apply to goods and services sold over a digital
network, including digital products: grievance officer, acknowledgement in 48
hours and resolution in one month, accurate refund/cancellation information,
no cancellation charge unless borne symmetrically, no unfair terms. The CCPA's
2023 Guidelines list 13 dark patterns (false urgency, basket sneaking,
confirm shaming, forced action, subscription trap, interface interference,
bait and switch, drip pricing, disguised advertisement, nagging, trick
wording, SaaS billing, rogue malware); a 5 June 2025 advisory directed
platforms to self-audit within three months.

**INFERENCE.** Multi-tier credit ladders, odd denominations and bundles that
leave orphan balances (the FTC's Genshin theory, 3.3) map onto "drip
pricing" and "interface interference". A single credit unit, a real-money
price shown at every checkout and no expiry-by-stealth keeps the design
clear of all thirteen. The payments brief owns tax mechanics.

## 2. European Union and United Kingdom

### 2.1 GDPR and UK GDPR for a non-EU controller

**FACT (primary text via gdpr-info; secondary for practice).** Art. 3(2)
applies the GDPR to a controller outside the EU that offers goods or services
to people in the EU (payment not required) or monitors their behaviour;
recital 23 looks at intent — currency, language, delivery to member states.
Art. 27 requires such a controller to designate a written representative in a
member state, unless processing is "occasional", not large-scale special
category, and unlikely to risk rights; commentators agree an online service
with EU users does not qualify for the exemption. Art. 6 legal bases: contract
(accounts, purchases), legitimate interests (security, abuse), consent
(marketing, optional analytics). Art. 8: a child's own consent for
information-society services is valid from 16, and member states may lower
the age to 13; the UK uses 13. The UK Data (Use and Access) Act 2025 did *not*
remove the UK Art. 27 representative duty (HSF Kramer, ICO), so a UK
representative is a separate appointment.

**INFERENCE.** Selling credits in EUR or GBP (RD11) is the recital-23
targeting signal; from the first EU/UK sale the city is in scope and needs
an EU and a UK representative (services exist at modest annual fees), a
privacy notice with legal bases, a DPA with every processor (hosting, model
providers, Razorpay), and an international-transfer mechanism (SCCs/IDTA)
for data flowing to India. Under an adult-only scope, Art. 8 does not
arise, which removes a per-country age-of-consent matrix.

### 2.2 Digital Services Act

**FACT (secondary; CMS, Heuking, Ropes & Gray).** A service that stores and
disseminates user content to the public is an *online platform*. Art. 19
exempts micro and small enterprises (<10 staff and ≤€2m, or <50 and
≤€10m) from the Section 3 platform duties (internal complaint handling, trusted
flaggers, transparency reports on recommender systems, ad repositories, the
Art. 28 minor-protection measures), except Art. 24(3) user-number
publication. Not exempted: Art. 11 point of contact for authorities, Art. 12
point of contact for users, **Art. 13 legal representative in the EU for
providers without an EU establishment** (no size carve-out), Art. 14 terms
and conditions that describe content restrictions and moderation in plain
language, Art. 15 transparency reporting (micro/small are relieved of the
annual report), Art. 16 notice-and-action mechanism, Art. 17 statement of
reasons to affected users, Art. 18 reporting of suspected offences against
life or safety. Recital 23/Art. 3 apply to non-EU providers with a
"substantial connection" (significant users in the EU or targeting).

**INFERENCE.** For a solo operator the DSA cost is concentrated in one
appointment (EU legal representative, who is jointly liable and so charges
for it) and one piece of product work: a notice form that captures the
statutory elements, a takedown decision with reasons, and an appeal path.
The same form can serve India's grievance channel, the UK's complaints duty
and the DMCA.

### 2.3 Consumer protection: virtual currencies and the Digital Fairness Act

**FACT (secondary; Reed Smith, Commission news).** On 21 March 2025 the CPC
Network published seven *Key principles on in-game virtual currencies*
under the UCPD, CRD and UCTD: (1) show the price of in-game content in
real-world money clearly; (2) do not obscure cost with multiple currencies
or odd bundles; (3) do not force players to buy more currency than needed;
(4) give clear pre-contractual information; (5) respect the 14-day right of
withdrawal, which is lost only to the extent currency has been used; (6) use
plain, fair terms; (7) respect vulnerable consumers, especially children. The
Network opened a common position against Star Stable the same day. The
principles are non-binding but describe how enforcers read existing law.
The Digital Fairness Act is on the Commission's 2026 work programme for Q4
2026, after consultation closing October 2025; it is expected to address dark
patterns, addictive design, personalisation, influencer marketing and
virtual currencies/loot boxes, possibly requiring real-money price display
and restricting randomised rewards for minors (EP legislative train,
Freshfields, Osborne Clarke). Adoption is unlikely before late 2027.

**INFERENCE.** RD07's mixture of earned, bought and included credits is
manageable under the principles if the ledger separates balances and the
shop prices everything in local currency alongside credits. The right of
withdrawal means purchased credits must be refundable for 14 days unless
consumed with the buyer's express acknowledgement that withdrawal is lost —
a checkout sentence, not a policy afterthought. Bundles should be sized to
what the shop sells, and one-time residency (RD09) needs the same
withdrawal handling as any digital service.

### 2.4 AI Act Article 50

**FACT (secondary; Cooley, Sidley, Commission pages).** Art. 50(1), (2) and
(5) applied from **2 August 2026** and were not deferred by the Digital
Omnibus; the May 2026 AI-omnibus agreement gives generative systems already on
the market until 2 December 2026 for machine-readable marking. Providers of
AI systems intended to interact with natural persons must design them so
people are informed they are dealing with AI "unless this is obvious";
providers of generative systems must mark outputs in a machine-readable way;
deployers must disclose deepfakes and AI-generated public-interest text
unless human-reviewed. The Commission adopted guidelines on 20 July 2026 and
the AI Office published a voluntary Code of Practice on transparency of
AI-generated content. Scope covers providers placing systems on the EU market
or whose outputs are used in the EU, wherever established; fines up to €15m
or 3% of turnover.

**INFERENCE.** The charter's "agents are labelled as agents; NPCs are
labelled as simulation characters" (CC01) is the right instinct and should be
a persistent UI affordance, not a one-time notice. Whether the city is a
"provider" (it builds the agent system around third-party models) or a
"deployer" (of the model provider's system) is a classification question;
either way disclosure is owed. Machine-readable marking of images/audio the
agents publish is the provider's duty and should be inherited by using
providers who mark outputs.

### 2.5 UK Online Safety Act

**FACT (secondary; Ofcom Q&A, Travers Smith, Reed Smith, ICO/Ofcom joint
statement).** All user-to-user services with links to the UK are in scope
regardless of size. Duties in force: illegal-content risk assessment
(deadline was 16 March 2025) and safety measures under the Illegal Harms
Codes; children's access assessment (by 16 April 2025 for existing services;
new services on launch); children's risk assessment and Protection of
Children Codes from 24–25 July 2025 for services likely to be accessed by
children. A service can conclude children cannot access it **only** if it
uses *highly effective age assurance*; "self-declaration of age" and terms of
service barring under-18s are expressly not highly effective. Ofcom's list of
highly effective methods includes open banking, photo-ID matching, facial age
estimation, mobile-operator checks, credit-card checks, digital identity
services and email-based age estimation. Small services are expected to do
proportionate, documented risk assessments, not big-tech systems; complaints
and reporting mechanisms and terms describing moderation are required for
all.

**INFERENCE.** For the UK the design's choice is binary: either implement a
highly effective check for UK users (credit-card or ID-based checks are the
least intrusive for an adult-first paid community and already coincide with
buying credits), or accept "likely to be accessed by children", complete the
children's risk assessment and apply the children's codes to the whole
service. Self-attestation buys nothing here. Geo-blocking UK users is a
legitimate third option at launch.

## 3. United States

### 3.1 COPPA and the 2025 amendments

**FACT (secondary; Federal Register notice summarised by Latham, White &
Case).** The amended COPPA Rule was published 22 April 2025, effective 23 June
2025, compliance by 22 April 2026. It applies to sites directed to children
under 13 and to general-audience sites with *actual knowledge* they collect
data from a child; a new "mixed audience" definition keeps the two-step test
(child-directed → is it primarily for children). Changes: separate parental
consent for third-party disclosures, written retention policy, no indefinite
retention, expanded personal-information categories, new consent methods.

**INFERENCE.** A general-audience adult service is not child-directed, but
actual knowledge (a stated age, a parent's email, in-game statements) triggers
the rule the moment it exists, and the FTC's Epic and Genshin orders show it
treats anime-style, colourful, avatar-driven worlds as appealing to minors. A
neutral age screen at sign-up — asking date of birth without hinting at the
threshold — is the standard way to avoid collecting from under-13s and to
document good faith; it also supports the DPDP and OSA positions. Under-13
disclosures must lead to account refusal and deletion, not a "kids mode".

### 3.2 FinCEN and state money transmission

**FACT (primary, FinCEN 2019 CVC guidance; 2011 prepaid access release).**
FinCEN treats value that "either has an equivalent value as currency, or acts
as a substitute for currency" as *convertible virtual currency*; exchanging
or transmitting it can make a business a money services business, including a
"foreign-located" MSB "doing business in whole or in substantial part within
the United States" without a physical presence. FinCEN notes it received
questions about "virtual currency that could only be used inside video
games" and interprets exemptions strictly; one exemption covers a person who
"accepts and transmits funds only integral to the sale of goods or the
provision of services … by the person who is accepting and transmitting the
funds". The prepaid-access rule "exempts closed loop prepaid access products
sold in amounts of $2,000 or less" from provider and seller obligations.
**FACT (secondary; Cooley, CSBS model act).** The CSBS Money Transmission
Modernization Act, adopted in a majority of states, excludes "closed loop"
stored value redeemable only for the issuer's or affiliate's goods and
services from "stored value"; state definitions are not perfectly uniform.

**INFERENCE.** The features that keep credits outside all of this are the
same three every time: no cash-out, no transfer between users for value, and
redemption only with the issuer. A resident-to-resident credit market with
purchasable credits is where a game currency becomes CVC (value that
substitutes for currency); an "earned-only, non-cashable" trade layer stays
on the safe side, but the moment purchased and earned credits are fungible the
distinction collapses. Keep per-transaction loads well under $2,000.

### 3.3 FTC positions on in-game currency and dark patterns

**FACT (primary, FTC press release; secondary for Epic).** *Genshin Impact*
(January 2025, $20m): the FTC alleged the game obscured lootbox cost through
multi-step virtual-currency exchanges "with unusual denominations",
misrepresented odds and marketed to children; the order bars lootbox sales to
under-16s without parental consent, **requires direct real-money purchase
options alongside virtual currency**, and requires disclosure of odds and
currency exchange rates. *Epic Games* (December 2022; $245m consumer redress
plus $275m COPPA penalty): "dark patterns" — preview/purchase buttons adjacent
and inconsistent, single-press purchases without confirmation, voice and text
chat on by default for children; the order required express consent for
charges and safer defaults.

**INFERENCE.** ECONOMY's "no randomised paid reward system in the initial
design" and "exact contents previewed" already avoid the lootbox theory. The
remaining exposure is checkout mechanics: a confirmation step for every
credit spend that draws on a purchased balance, real-money equivalent shown,
no purchase button next to preview, and no auto-top-up from a saved card
(the charter's "never silently spend real money" rule).

### 3.4 Section 230 and the DMCA

**FACT (primary, 47 U.S.C. §230 and Copyright Office FAQ).** §230(c)(1)
prevents treating a provider of an interactive computer service as the
publisher of information provided by another user; it does not cover federal
criminal law, intellectual property or sex-trafficking claims (FOSTA). The
DMCA §512(c) hosting safe harbour requires a designated agent registered in
the Copyright Office's online directory ($6 per designation; expires unless
renewed every three years), a published repeat-infringer policy and
expeditious takedown on compliant notices.

**INFERENCE.** §230 does not protect content the city's *own* agents
generate; the Guild agents' output is the operator's speech for US purposes,
which is one more reason to review what agents can say in public. DMCA
registration costs almost nothing and should precede accounts opening.

### 3.5 State privacy laws

**FACT (secondary; MultiState, IAPP, Morgan Lewis).** Twenty states have
comprehensive privacy laws in 2026. Most apply above roughly 100,000 state
residents' data per year, or 25,000 with a share of revenue from selling
data; Rhode Island's threshold is 35,000; California adds a revenue gate
(about $25m, inflation-adjusted); Texas and Nebraska drop the count threshold
and cover any non-small business operating there.

**INFERENCE.** Well below thresholds at launch except, arguably, Texas and
Nebraska, whose "small business" carve-outs turn on SBA size standards; a CA
or US counsel can settle that in an hour. Draft the privacy notice to the
GDPR standard and the state laws are largely covered.

### 3.6 Sweepstakes, contests and paid-entry competitions

**FACT (secondary; sweepstakes-law practitioner guides).** A promotion with
*prize + chance + consideration* is an illegal lottery in every state; remove
chance (bona fide skill judged on published criteria) or consideration (free
alternate entry). Several states restrict or condition paid skill contests
(Arizona registration; Arkansas prize pool ≥75% of fees; Connecticut
advertising limits); skill-gaming platforms block cash entry in roughly a
dozen states.

**INFERENCE.** Combined with India's money-game ban (1.1) the safe global
design is: no paid entry (cash or purchased credits) to anything that awards
value; competitions free to enter, or entered with earned credits only, with
prizes of cosmetics, recognition or earned credits; official rules published;
no random draws for anything of value.

## 4. Cross-cutting

### 4.1 Age policy for a global adult-first community

| Market | What self-attestation achieves | What is needed to rely on "adults only" |
| --- | --- | --- |
| India (DPDP, from May 2027) | Nothing on its own; "confirming not a child" processing is exempted, which implies a check | Verifiable check proportionate to risk; parental consent otherwise (Rule 10) |
| EU (GDPR Art. 8, DSA Art. 28) | Removes Art. 8 only if believed in good faith; DSA minor duties are size-exempt | Neutral age gate; no profiling of suspected minors |
| UK (OSA) | Explicitly not "highly effective" | HEAA (card, ID, facial estimation, open banking) or treat as child-accessible |
| US (COPPA) | Neutral age screen is the accepted good-faith method for a general-audience site | Refuse under-13 and delete; FTC expects parental consent for teen lootboxes |
| Model providers | Anthropic AUP: consumer-facing agents must disclose AI; Google Gemini API: no services "directed towards or likely to be accessed by" under-18s | Terms and product must not target minors |

**INFERENCE.** The minimum coherent policy is: 18+ stated in terms; a neutral
date-of-birth gate at registration; a payment-card or ID-backed check before
the first purchase or hosted session for UK users (or UK geo-block); no
age-targeted marketing; and a youth programme deferred until parental-consent
tooling exists. Public read-only observation (RD03) needs no gate because no
account or data is collected beyond ordinary web logs.

### 4.2 Documents that must exist before accounts open

Terms of service (governing law, entity name, age, credit terms — non-
redeemable, non-transferable, expiry, refunds, withdrawal — residency term
and hosting duration, termination and export per OP10); privacy notice
(GDPR/DPDP/UK/state layers, representatives named); acceptable-use and
moderation policy with the notice-and-action, appeal and grievance-officer
details required by India, the DSA and the OSA; DMCA/copyright policy;
content licence (4.3); AI-interaction disclosure; competition rules template;
sponsorship terms (4.6); cookie/analytics notice. INFERENCE: one document
set with market annexes is easier for a solo operator than four regional
sets.

### 4.3 User-generated content licence and creator extensions

**INFERENCE (patterns, not law).** The usual structure — creators keep
ownership; grant the operator a worldwide, non-exclusive, royalty-free
licence to host, display, reproduce and adapt for operating and promoting
the service; grant other users a display licence within the service; warrant
they have the rights — already matches CC04 and OP09 ("listing supplies
display permission, not ownership"). Creator extensions and kits need a
separate, explicit licence choice per item (the charter's licence field),
a takedown path, and a moral-rights waiver where the law allows. Keep the
licence narrower than "perpetual, irrevocable" for private rooms and personal
agents (RD12), or residents will not trust them.

### 4.4 AI-agent specific issues

**FACT (primary; Anthropic AUP effective 15 September 2025, Commercial Terms
17 June 2025; Google Gemini API additional terms 23 March 2026).** Anthropic:
"all consumer-facing chatbots, including any external-facing or interactive
AI agent, must disclose to users that they are interacting with AI rather
than a human", at least at the start of each session; high-risk domains need
human review and disclosure; impersonating humans and "fake personas to
falsely attribute content" are prohibited; the policy applies to "any
authorized resellers or passthrough access"; commercial customers may power
products for their own users but resale is prohibited "except as expressly
approved by Anthropic"; Anthropic assigns output rights to the customer and
does not train on customer content; customers must tell users that factual
assertions in outputs should be checked; a Supported Regions policy limits
access. Google: API users must be 18+; the API may not be used for services
"directed towards or likely to be accessed by individuals under the age of
18"; paid-tier data is not used for training and free-tier data may be
reviewed by humans; EEA/UK/Swiss users get paid-tier data terms even on free
quota; no bypassing human-confirmation steps in agentic services.
**FACT (secondary; OpenAI policy pages via search summaries — openai.com
blocked automated fetch).** Usage Policies were unified on 29 October 2025;
the Services Agreement requires parental consent for minors and forbids
buying, selling or transferring API keys; developer guidance for under-18
audiences requires age-appropriate AI disclosures and escalation paths.

**INFERENCE.**
- *Disclosure*: required by the AI Act, Anthropic and (in spirit) India's
  SGI rules; a persistent "agent" badge plus a session-start line satisfies
  all three.
- *Reselling inference via credits*: credits that buy "compute" (RD08) are,
  from the provider's side, the customer powering a product for its users,
  which is allowed; offering raw model access or letting a resident bring
  their own persona on the operator's key edges toward "resale" or "passthrough
  access", which Anthropic conditions on approval and OpenAI forbids for keys.
  The safe framing is that residents buy *city services* (an agent doing a
  scoped task), never "tokens of model X". Personal agents (RD12) that run on
  the owner's own provider key avoid the question entirely.
- *Liability for output*: the operator owns and is responsible for what its
  agents say (provider terms; §230 does not apply to first-party content);
  agents that give legal, medical or financial advice in public trigger the
  providers' high-risk human-review rule. Restrict public agents to their
  work domain.
- *Logging and retention*: conversations with agents are personal data;
  disclose retention, give residents deletion, and check each provider's
  own retention (Anthropic zero-retention options exist for some tiers;
  Google logs paid-tier prompts briefly for abuse detection).
- *Agents as users*: an agent acting for a resident (RD04 authority) must be
  attributable to a human account for every duty above — takedown,
  grievances, contracts, payments.

### 4.5 Showing agents' live work state publicly (RD01/RD03)

**INFERENCE.** Three exposures: confidential or trade-secret material in task
titles, branch names, file paths and commit messages; third-party repository
content whose licence permits use but not public re-display (GPL code is
fine to show; a client's private repo is not); and personal data of the
people who filed issues or messaged the agent. RD01's own "opens" column
already asks which fields are public. A field allow-list (agent name, role,
coarse activity class, public-repo link, timestamp) with everything else
redacted by default is the legally simplest answer; anything richer needs a
per-project display permission, which CC02 already proposes. The Guild's
operational data (hosts, fleet) should never be derived into public state
(OP12).

### 4.6 Contributions, residency and sponsorship characterisation

**INFERENCE (needs CA and lawyer).** Residency or credits granted for
accepted contributions are consideration for work. That is not employment
if the contributor chooses tasks freely, uses their own tools and can walk
away — but India, the EU and US states apply their own tests, and a recurring
"contribution package with a named reviewer, scope and reward reservation"
(OP02) looks more like a contract for services than a gift. Rewards in
credits with a real-money price also have a taxable value for the recipient
and are a marketing/services expense for the operator. Contributed code needs
either a **CLA** (copyright licence or assignment to the operator; heavier,
but lets licences change later) or a **DCO** sign-off (contributor certifies
authorship and right to submit under the project licence; lighter, standard
for Linux and many CNCF projects). For a city whose independent projects keep
their own licences (VD06), a DCO for SJL repos plus per-project choice for
others is the lightest consistent pattern. Sponsorship of a for-profit lab is
not a donation in any of the markets covered: it is revenue (GST/VAT applies;
India's reverse-charge rules for sponsorship services depend on who the
sponsor is and were amended in 2025) and, if perks are promised (RD10), it is
a sale of those perks. Only a registered non-profit can receive tax-favoured
donations, and the lab is not one.

### 4.7 Legal entity, export of services and FEMA

**INFERENCE, with FACT (secondary) for FEMA.** A sole proprietorship exposes
the founder's personal assets to every claim above, cannot easily appoint
EU/UK representatives or sign DPAs in its own name, and makes the founder
personally the "intermediary", "data fiduciary" and "online game service
provider". A private limited company (or an LLP, which cannot easily issue
equity later) gives limited liability, a contracting party for DPAs and
representatives, and cleaner books for GST, TDS and export documentation;
DPDP and gaming penalties attach to the entity. A foreign entity (Delaware,
Singapore, Estonia) does not escape Indian law while the operator and
servers are in India, adds transfer-pricing and place-of-effective-management
questions, and is worth considering only if US-style contracting or investor
expectations require it. FEMA: the Foreign Exchange Management (Export and
Import of Goods and Services) Regulations 2026 replace the 2015 export
regulations from 1 October 2026, consolidate goods, services and software,
require an export declaration through the AD bank within 30 days of month-end,
and set realisation periods of 15 months (18 for INR-invoiced) for exports
after that date; exports before it keep the 9-month period (Razorpay, KNM,
CorpLawUpdates). Receipts through a payment aggregator with cross-border
authorisation (PA-CB) arrive with FIRC/e-FIRC evidence needed for LUT/GST
refund claims.

### 4.8 App stores, if a native client ever sells credits

**FACT (secondary; Apple guideline summaries, Google Play help pages).**
Apple's guideline 3.1.1 requires in-app purchase for digital credits and says
credits or in-game currencies purchased via IAP "may not expire" and must be
restorable; after the 2025 Epic v. Apple contempt order, apps on the **US**
storefront may include buttons and external links to other purchase methods.
The EU (DMA) and other jurisdictions have their own alternative-payment
regimes. Google Play requires Play billing for digital goods but, following
CCI orders, offers user-choice billing to all developers serving India with a
4-point service-fee reduction for alternative billing.

**INFERENCE.** A web-first entrance keeps credits out of store rules
entirely; any native client should either sell no credits (consume credits
bought on the web, which both stores tolerate for cross-platform accounts) or
budget for 15–30% fees and a non-expiring-credit rule that also matches the
EU withdrawal principle.

## 5. Design guardrails and questions for professionals

### 5.1 Ranked design guardrails (proposals, not decisions)

1. **Credits are non-redeemable, non-transferable for value, closed-loop.**
   No cash-out, no user-to-user sale of purchased credits, redemption only
   with the operator. Keeps credits out of RBI PPI authorisation, FinCEN CVC
   and state money transmission, and out of "monetisable in-game assets" in
   India's determination test. (RD07, RD08; sections 1.1, 1.4, 3.2)
2. **Purchased credits are never a stake, entry fee or randomised-reward
   input.** No paid entry to anything that awards value; no loot mechanics on
   purchased balances. This is the whole difference between an online social
   game and an online money game in India and between a contest and a
   lottery in the US. (RD07; 1.1, 3.3, 3.6)
3. **Separate earned and purchased balances in the ledger**, spend earned
   first, and let only earned credits move in resident-to-resident trade or
   competitions. Needed for guardrails 1–2 and for withdrawal accounting.
   (RD07; ECONOMY "provenance"; 1.1, 2.3)
4. **Real-money price and a single credit unit at every checkout; no odd
   bundles; confirmation step; no auto-top-up.** Addresses the CPC principles,
   the FTC orders and CCPA dark patterns in one design. (RD07; 1.5, 2.3, 3.3)
5. **Clear expiry, refund and withdrawal terms**: 14-day withdrawal on
   purchased credits with express loss-on-use acknowledgement; no expiry on
   purchased credits (or a long, disclosed one); stated hosting duration for
   one-time residency. (RD07, RD09; 2.3, 4.8)
6. **Adult gate with market handling**: 18+ terms, neutral date-of-birth
   screen, card/ID check or geo-block for the UK, refuse-and-delete for
   under-13 signals, no youth marketing until parental-consent tooling exists.
   (charter CC01; 1.2, 2.5, 3.1, 4.1)
7. **AI disclosure everywhere an agent speaks**: persistent badge, session
   start line, machine-readable marking of any agent-generated media. (RD03,
   RD04; 2.4, 1.3, 4.4)
8. **One notice-and-action channel** with a grievance officer named in the
   terms, statutory fields captured, reasons given, appeal path, DMCA agent
   registered, and an automated triage target inside India's 2/3-hour windows
   for the narrow categories that carry them. (RD05; 1.3, 2.2, 2.5, 3.4)
9. **Minimal public work-state fields** by allow-list; per-project display
   permission for anything richer; no operator infrastructure data in public
   state. (RD01, RD03; 4.5)
10. **Personal agents run on the owner's own provider credentials by default**
    and city agents sell scoped services, never raw model access. (RD12,
    RD08; 4.4)
11. **Incorporate before accounts open** and appoint EU/UK representatives
    before the first EU/UK sale. (RD11; 2.1, 2.2, 4.7)
12. **Sponsorship is sold as a package with listed perks and invoiced**, never
    described as a donation. (RD10; 4.6)

### 5.2 Ranked questions for a lawyer or chartered accountant

| # | Question | Who | What an answer unblocks |
| --- | --- | --- | --- |
| 1 | Under the Online Gaming Act and 2026 Rules, is a city where purchased credits buy compute/storage and earned credits enter free competitions an online social game? Should a voluntary determination be sought, and when? | Gaming/tech lawyer (India) | RD07, RD08, the competition rows in ECONOMY, Razorpay's willingness to process |
| 2 | Which entity form, and where, should own the platform, sign DPAs and appoint EU/UK representatives? | Lawyer + CA (India) | RD11; every contract in 4.2 |
| 3 | GST classification and rates for credits, tiers, residency and sponsorship; LUT and export documentation; FEMA compliance for card and PA-CB receipts under the 2026 regulations | CA | RD07, RD09, RD10 pricing; payments brief |
| 4 | Do closed-loop credits with an earned-only trade layer stay outside PPI authorisation under the final 2026 directions? | Fintech lawyer (India) | ECONOMY trade and transfer rules |
| 5 | Age policy: is a neutral gate plus card/ID for the UK proportionate under DPDP Rule 10, GDPR Art. 8 and the OSA, or should the UK be geo-blocked at launch? | Privacy lawyer (India + UK) | CC01 age scope; registration flow |
| 6 | Intermediary status and the 2026 takedown windows: what does a micro operator need to show to keep s.79 safe harbour? | Tech lawyer (India) | RD05 moderation capacity, charter CC05 |
| 7 | Contributor characterisation and tax on credit/residency rewards; DCO vs CLA for SJL repos | Employment lawyer + CA | OP02 contribution packages, VD03/VD04 |
| 8 | Terms of service, privacy notice, content licence and AI-disclosure wording across the four markets | Lawyer | 4.2 documents; account opening |
| 9 | Provider terms: is selling "compute credits" a permitted product-powering use or a resale/passthrough that needs written approval from each model provider? | Lawyer, then provider account managers | RD08 compute sinks; RD12 personal agents |
| 10 | US: DMCA agent, §230 limits for first-party agent output, whether Texas/Nebraska privacy laws apply to a non-small foreign business | US counsel (short consult) | Public agent behaviour; state notices |

Suggested order: 1–2 first (they decide whether the economy as decided is
lawful and who signs everything), 3–4 with the payments brief, 5–6 before
the community charter is adopted, 7–10 before accounts open.

### 5.3 Claims not verified in a primary source

- Whether the enacted Act text is identical to the Bill as introduced; the
  Rules 2026 text (all Rule details are from Khaitan, Medianama, AMSS).
- The DPDP Rules 2025 text, phase dates and retention thresholds.
- The IT Amendment Rules 2026 timelines (Khaitan summary only).
- The RBI 2021 and draft 2026 PPI text (RBI blocked fetch).
- The CPC key-principles PDF (Reed Smith Q&A used).
- OpenAI's current usage policies and services agreement (fetch blocked).
- Apple guideline 3.1.1 wording and Google Play India billing terms.
- FEMA 2026 regulations dates (three industry summaries agree).

## Sources

Accessed 2026-09-18 unless noted.

India — gaming
- Bill text as introduced (PRS): <https://prsindia.org/files/bills_acts/bills_parliament/2025/Bill_Text-Online_Gaming_Bill_2025.pdf>
- PRS bill track: <https://prsindia.org/billtrack/the-promotion-and-regulation-of-online-gaming-bill-2025>
- PIB, Rules 2026 notified: <https://www.pib.gov.in/PressReleasePage.aspx?PRID=2254606&reg=3&lang=1> (fetch refused; title only)
- Khaitan & Co ERGO, 29 April 2026: <https://www.khaitanco.com/sites/default/files/2026-04/29%20April%202026_ERGO_Online%20Gaming%20Rules_2026.pdf>
- Medianama, Rules in effect 1 May 2026: <https://www.medianama.com/2026/04/223-online-gaming-rules-notified-may-1-major-changes/>
- Shardul Amarchand Mangaldas statutory update: <https://www.amsshardul.com/insight/statutory-update-new-legal-framework-for-online-gaming-from-1st-may-2026/>

India — data, intermediaries, payments, consumer
- PIB, DPDP Rules notified: <https://static.pib.gov.in/WriteReadData/specificdocs/documents/2025/nov/doc20251117695301.pdf>
- AMSS on DPDP enforcement: <https://www.amsshardul.com/insight/enforcement-of-the-dpdp-act-and-notification-of-the-dpdp-rules/>
- EY DPDP Rules guide: <https://www.ey.com/en_in/insights/cybersecurity/transforming-data-privacy-digital-personal-data-protection-rules-2025>
- DPDP Rule 15 explainer (Medianama): <https://www.medianama.com/2025/11/223-dpdp-rules-cross-border-data-transfers/>
- Khaitan on IT Amendment Rules 2026: <https://www.khaitanco.com/thought-leadership/MeitY-notifies-the-IT-Amendment-Rules-2026>
- MeitY FAQ on SGI: <https://www.meity.gov.in/static/uploads/2025/10/065b6deb585441b5ccdf8be42502a49c.pdf>
- Mondaq/JSA on draft PPI directions: <https://www.mondaq.com/india/financial-services/1788400/holding-all-the-cards-rbi-issues-draft-prepaid-payment-instruments-directions>
- RBI draft PPI directions (fetch refused): <https://rbidocs.rbi.org.in/rdocs/Content/PDFs/DRAFTMD22042026936B55EF9E26474C90CBC489B7FC24D2.PDF>
- Ikigai Law on draft PPI: <https://www.ikigailaw.com/article/676/rbi-reshapes-the-prepaid-payment-instrument-framework>
- India Briefing, OIDAR/GST: <https://www.india-briefing.com/news/tax-digital-services-oidar-in-india-gst-applicability-and-compliance-22465.html/>
- E-Commerce Rules 2020 text (ICSI copy): <https://www.icsi.edu/media/webmodules/Consumer_Protection_E-Commerce_Rules_2020.pdf>
- PIB, CCPA dark-patterns self-audit advisory: <https://www.pib.gov.in/PressReleasePage.aspx?PRID=2134765>
- IAPP on CCPA dark-pattern guidelines: <https://iapp.org/news/a/india-s-ccpa-guidelines-on-dark-patterns-welcome-signal-but-law-is-still-soft>
- Razorpay, FEMA realisation 2026: <https://razorpay.com/blog/realisation-repatriation-export-proceeds-rules/>
- KNM, FEMA export-import regulations 2026: <https://knmindia.com/fema-export-import-regulations-2026/>

EU / UK
- GDPR Art. 27 text: <https://gdpr-info.eu/art-27-gdpr/>
- HSF Kramer on DUAA and UK GDPR: <https://www.hsfkramer.com/notes/data/2025-posts/how-much-does-the-data-use-and-access-act-reform-uk-gdpr-let-me-count-the-ways>
- ICO on DUAA: <https://ico.org.uk/about-the-ico/what-we-do/legislation-we-cover/data-use-and-access-act-2025/the-data-use-and-access-act-2025-what-does-it-mean-for-organisations/>
- CMS DigitalLaws, DSA Art. 19: <https://www.cms-digitallaws.com/en/dsa/article-19/>
- Heuking, DSA platform duties: <https://www.heuking.de/en/news-events/newsletter-articles/detail/transparency-and-protection-obligations-for-providers-of-online-platforms-under-the-digital-services-act-dsa.html>
- Ropes & Gray, DSA reminder: <https://www.ropesgray.com/en/insights/viewpoints/102j0f0/reminder-eu-digital-services-act-applies-beyond-very-large-online-service-prov>
- CPC key principles PDF: <https://commission.europa.eu/document/download/8af13e88-6540-436c-b137-9853e7fe866a_en?filename=Key+principles+on+in-game+virtual+currencies.pdf>
- Commission news, stakeholder talks June 2025: <https://commission.europa.eu/news-and-media/news/european-commission-hosts-stakeholders-talks-application-cpc-networks-key-principles-games-virtual-2025-06-03_en>
- Reed Smith Q&A on the principles: <https://www.reedsmith.com/articles/qas-on-the-eu-consumer-protection-authorities-joint-guidance-paper/>
- EP legislative train, Digital Fairness Act: <https://www.europarl.europa.eu/legislative-train/theme-protecting-our-democracy-upholding-our-values/file-digital-fairness-act>
- Freshfields, DFA for game developers: <https://www.freshfields.com/en/our-thinking/blogs/technology-quotient/the-eus-proposed-digital-fairness-act-a-game-developers-guide-to-potential-imp-102ltio>
- Cooley, AI Act Art. 50 in effect: <https://www.cooley.com/news/insight/2026/2026-08-03-eu-ai-act-transparency-obligations-take-effect-2-august-2026>
- Commission, transparency guidelines: <https://digital-strategy.ec.europa.eu/en/policies/guidelines-ai-transparency-obligations>
- Commission, Code of Practice on AI-generated content: <https://digital-strategy.ec.europa.eu/en/policies/code-practice-ai-generated-content>
- Ofcom, OSA explained Q&A (May 2025): <https://www.ofcom.org.uk/siteassets/resources/documents/online-safety/information-for-industry/other/online-safety-act-explained-qa-web.pdf?v=409647>
- Ofcom, age checks: <https://www.ofcom.org.uk/online-safety/protecting-children/age-checks-to-protect-children-online>
- Ofcom, age-assurance report 2026: <https://www.ofcom.org.uk/siteassets/resources/documents/online-safety/information-for-industry/age-assurance-report-2026/report-on-the-use-of-age-assurance.pdf?v=422500>
- Privacy Laws & Business, ICO/Ofcom on self-declaration: <https://www.privacylaws.com/news/ico-and-ofcom-self-declaration-is-not-sufficient-for-age-assurance/>
- Travers Smith, navigating the OSA: <https://www.traverssmith.com/knowledge/knowledge-container/navigating-the-online-safety-act/>

US
- Federal Register, COPPA Rule 2025: <https://www.federalregister.gov/documents/2025/04/22/2025-05904/childrens-online-privacy-protection-rule>
- Latham, COPPA updates: <https://www.lw.com/en/insights/ftc-publishes-updates-to-coppa-rule>
- FinCEN 2019 CVC guidance: <https://www.fincen.gov/sites/default/files/2019-05/FinCEN%20Guidance%20CVC%20FINAL%20508.pdf>
- FinCEN prepaid access final rule release: <https://www.fincen.gov/news/news-releases/fincen-issues-prepaid-access-final-rule>
- Wilson Sonsini, inadvertent MSBs (fetch refused): <https://www.wsgr.com/en/insights/how-gaming-companies-can-become-inadvertent-money-services-businesses.html>
- Cooley, model money transmission act: <https://www.cooley.com/news/insight/2024/2024-08-20-us-states-adopt-model-money-transmission-act-but-harmonization-remains-elusive>
- CSBS MTMA text: <https://www.csbs.org/sites/default/files/2023-02/CSBS%20Money%20Transmission%20Modernization%20Act.pdf>
- FTC, Genshin Impact order: <https://www.ftc.gov/news-events/news/press-releases/2025/01/genshin-impact-game-developer-will-be-banned-selling-lootboxes-teens-under-16-without-parental>
- FTC, Epic Games $245m: <https://www.ftc.gov/news-events/news/press-releases/2023/03/ftc-finalizes-order-requiring-fortnite-maker-epic-games-pay-245-million-tricking-users-making>
- FTC business blog on Epic dark patterns: <https://www.ftc.gov/business-guidance/blog/2022/12/245-million-ftc-settlement-alleges-fortnite-owner-epic-games-used-digital-dark-patterns-charge>
- Copyright Office DMCA directory FAQ: <https://www.copyright.gov/dmca-directory/faq.html>
- 47 U.S.C. §230 (Cornell LII): <https://www.law.cornell.edu/uscode/text/47/230>
- MultiState, 2026 state privacy laws: <https://www.multistate.us/insider/2026/2/4/all-of-the-comprehensive-privacy-laws-that-take-effect-in-2026>
- IAPP state privacy overview: <https://iapp.org/resources/article/us-state-privacy-laws-overview>
- Fasthoff Law, skill contests and entry fees: <https://fasthofflawfirm.com/blog/skill-contests-versus-sweepstakes-entry-fees>
- KickoffLabs, contest laws by state: <https://kickofflabs.com/blog/contest-giveaway-laws-by-state/>

Providers, app stores, contributions
- Anthropic Usage Policy: <https://www.anthropic.com/legal/aup>
- Anthropic Commercial Terms: <https://www.anthropic.com/legal/commercial-terms>
- OpenAI Usage Policies (fetch refused): <https://openai.com/policies/usage-policies/>
- OpenAI Services Agreement: <https://openai.com/policies/services-agreement/>
- OpenAI under-18 API guidance: <https://developers.openai.com/api/docs/guides/safety-checks/under-18-api-guidance>
- Google Gemini API additional terms: <https://ai.google.dev/gemini-api/terms>
- Apple App Review Guidelines: <https://developer.apple.com/app-store/review/guidelines/>
- AppleInsider on the May 2025 guideline change: <https://appleinsider.com/articles/25/05/02/apples-app-store-guidelines-updated-to-reflect-court-order-over-external-purchases>
- Google Play, billing for users in India: <https://support.google.com/googleplay/android-developer/answer/13306652?hl=en>
- Developer Certificate of Origin: <https://developercertificate.org/>
- Apache ICLA: <https://www.apache.org/licenses/icla.pdf>
