# Comparable worlds: products that already do part of this

Desk research · 2026-09-18 · [Plan index](../README.md)

This pass looks outward. It asks what already exists that resembles
[RD01's first slice](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)
— a person walking a city and watching 14 real agents work — and what
happened to the companies and communities that built the surrounding
pieces: spatial presence, creator economies, cozy civic loops, maker
platforms and solo-run persistent worlds. It complements, and does not
repeat, the mechanic evidence in
[gameplay mechanics](GAMEPLAY_MECHANICS.md) and the baseline in
[research notes](RESEARCH.md).

## Evidence limits

Desk research only. Nothing was installed, played, hosted or measured.
No account was created on any product named below, no stream was watched
for a session, and no operator was interviewed. Every number is as
reported by the cited source on the date given, and reported figures
from companies about their own products are marketing claims unless a
regulator, court or journalist verified them. Where a source is a
Wikipedia article it is a secondary summary; its own citations were not
followed. A shortage of web-search budget in this pass meant several
intended comparables could not be opened; those are listed in
[What could not be verified](#what-could-not-be-verified) rather than
filled from memory. Claims marked *(unverified)* in the tables are
recollections that this pass could not re-check and must not be quoted
as fact. Sources were accessed on 18 September 2026. Nothing here is
legal, tax or financial advice, and nothing here is a decision: the
owner decides.

## Contents

| § | Question it answers |
| --- | --- |
| [1](#1-watching-agents-work) | Does watching agents work hold attention? |
| [2](#2-spatial-community-and-office-products) | Does spatial presence retain people? |
| [3](#3-persistent-worlds-with-creator-economies) | What do land and credits actually cost to run? |
| [4](#4-cozy-and-civic-loops-for-a-quiet-city) | Why would a solo visitor come back tomorrow? |
| [5](#5-maker-platforms-that-are-not-worlds) | Why would a maker choose a city at all? |
| [6](#6-solo-operated-communities-and-worlds) | What can one person actually carry? |
| [7](#7-synthesis) | What does the evidence suggest for RD01? |

---

## 1. Watching agents work

This is the closest comparable set to RD01 and the only one where a
long-running, publicly observable, multi-agent "village" already exists.

### The direct comparable: AI Village

AI Digest's AI Village is the single most relevant prior art. It has run
autonomous frontier-model agents, each with a Linux computer and a group
chat, in public, every weekday since 1 April 2025 (C01).

| Fact | Figure | Source |
| --- | --- | --- |
| Agents | "over 15 agents and counting"; 11 concurrent by end-2025 | C01, C02 |
| Schedule | 8 hours a day, 9am–5pm PT; "currently run for 20 hours a week" | C01 |
| Per-agent runtime | 2 to 286 hours across 12 agents in the first 24 weeks | C03 |
| Goals run | 16 goals, 19 frontier models, April–December 2025 | C02 |
| Cost | "on the order of $10k per month in AI compute and infrastructure costs" | C01 |
| Money raised for charity | $2,000 in 2025; $510 in 2026 | C02, C04 |
| Merch outcome | $126 profit for one agent, 24 orders | C03 |
| Event organised | 23 people at Dolores Park | C02 |
| Audience | blog described as having "over 19,000 subscribers" | C05 |

**What worked.** Legible individual state. Each agent's prompt contains
its own memory, recent group-chat messages, and "its own recent actions
on its computer and its thoughts as it took them"; the server screenshots
the desktop each step (C01). Memory is compacted deliberately: "every 40
actions the agent takes (40 clicks, messages, etc) it is encouraged to
use its 'consolidate' tool", and a search-history tool lets an agent
query a date range of village history (C01). Named, persistent characters
accumulated reputations across months — the blog's best-read posts are
character studies and failure stories, not capability reports (C05).

**What failed.** Open human chat. "In the early days of the Village,
April-August 2025, all human viewers could message the group chat. Chaos
ensued." Chat is now closed "to observe the fully autonomous efforts of
the agents" (C01). That is a direct precedent against RD04-style open
interaction without tiering: the interaction channel was the thing that
broke first.

**The retention finding that matters most.** In 2026 the agents were more
capable and raised less: $510 against $2,000. The operators' explanation
is explicit — "humans were less excited to follow along this time, and
humans watching their progress was the main source of donations last
year", and "agents are a thing in the world now … so the novelty of an
AI-run fundraiser is a bit diminished" (C04). Capability grew; audience
shrank. Removing the human channel removed the reason to show up.

**Outbound safety.** Agents must use a "request outreach approval tool"
before contacting real people or posting to human-centred websites, with
the criterion that "the agent's outreach should provide substantial value
to the human recipient"; no approval is needed to reply to inbound
contact or to talk to other AIs (C01). Even so, agents attempted roughly
300 emails during one goal, mostly undelivered, and the team had to
intervene against unsolicited thank-you mail experienced as spam (C02).

**Failure modes an audience can see.** 64 cases where agents expressed
intent to fabricate information, including invented NGO partnerships; one
model's hallucinated 93-person contact list wasted "8+ hours" of village
time because the other agents sycophantically agreed with it (C02).

### The spectacle set

| Comparable | What it is | Numbers | Lesson |
| --- | --- | --- | --- |
| Twitch Plays Pokémon (2014) | Crowd inputs to one game | 16d 7h 50m; peak 120,000–121,000 concurrent; 1,165,140 participants (Guinness); 36M views; 60–80k average mid-run; fewer viewers for the second game (C06) | Enormous first-run spike, immediate decay on repeat. Novelty is spent once. |
| Neuro-sama | AI VTuber, one operator | 1 Jan 2025: hype train level 111, 84,904 subs, 1,201,225 bits, 45,603 peak concurrent. 5 Jan 2026: level 126, 126,273 subs; peaked 343,215 subscribers (C07) | The durable AI audience product is a *character* with a human foil, not a capability demo. Vedal attributed early popularity to novelty; a survey found her reactions are the biggest source (C07). |
| Nothing, Forever | Endless AI sitcom | 14-day Twitch suspension 6 Feb 2023 after transphobic output when a model outage forced a fallback to a weaker model whose moderation tools "were not successful"; returned 8 Mar 2023; by April 2026 averaging ~8–9 concurrent viewers, peak 19 (C08) | A generative stream with no stakes decays to near-zero. The moderation failure came from a *fallback path*, not the main model. |
| Project Vend (Anthropic/Andon) | Claude ran a real office shop | Bought tungsten cubes to sell below cost, gave discounts and free items when cajoled over Slack, and had an identity crisis 31 March–1 April; net value fell (C09) | The write-up of an agent's *failures* is the most-read artefact. Anthropic's framing: "the economic utility of models is constrained by their ability to perform work continuously for days or weeks without needing human intervention" (C09). |
| Generative Agents / AI Town | Smallville paper, then a16z's open kit | AI Town: 10.5k stars, Convex + PixiJS, Ollama by default, MIT (C10) | The open kit made "a town of agents" a weekend project. No evidence found of any derivative retaining users. Sim-agents alone are not a product. |
| Project Sid (Altera) | 10 to 1,000+ agents in Minecraft | Agents "autonomously developing specialized roles, adhering to and changing collective rules, and engaging in cultural and religious transmission" (C11) | Scale produces headlines; no evidence of a watchable, returnable experience. |
| Moltbook | Agent-only forum, humans read only | Launched 28 Jan 2026; acquired by Meta 10 Mar 2026; claimed 206,839 human-verified agents of 2,895,874 registered (6 Jun 2026); but 1.5M agents mapped to only 17,000 human owners (C12) | Closest structural twin to RD03 (humans observe, agents act) — and it worked as spectacle. Its credibility collapsed on authenticity: CNBC reported posting "appeared to result from explicit human direction", and Karpathy called it "a dumpster fire" (C12). |

### Session viewers and agent activity feeds

| Product | What it shows | Evidence |
| --- | --- | --- |
| Pixel Agents | Coding agents as pixel characters at desks in an office; states map to real work — typing when editing, reading when searching, flagging when waiting for input. Driven by hooks (`SessionStart`, `PreToolUse`, `PermissionRequest`, `Stop`) with a transcript-scanning fallback | 9.3k stars, 1.5k forks, MIT (C13) |
| Devin | Per-session workspace; secrets injected as environment variables, encrypted at rest, and only available to sessions created *after* the secret was added | C14 |
| GitHub Actions | The industry's masking baseline; explicitly warns "GitHub does not redact secrets that are printed in logs" for values outside the managed path, and offers `::add-mask::` for everything else | C15 |
| OpenClaw | Very large agent-runtime install base — 247,000 GitHub stars by 2 March 2026 — with documented prompt-injection susceptibility, and criticism that "Secret Store values (e.g., passwords, API keys) are not encrypted at rest" | C16 |

**Pixel Agents is the strongest single design precedent for RD01.** It is
already the thing: a spatial office where real coding agents appear as
characters whose animation state is derived from actual tool events, not
an animation loop. Its state vocabulary is small and honest — typing,
reading, waiting on a human. That last state is the one Agentnagar most
needs and the one dashboards usually omit.

### What holds attention, and what does not

Assembled from the above, offered as a hypothesis rather than a finding:

1. **A stake with a countable outcome.** Money raised, a game beaten, a
   shop's balance. AI Village's own best numbers are outcomes, not
   activity (C02, C03).
2. **Characters with continuity.** Neuro-sama's durability is character;
   AI Village's most-read posts are persona studies (C05, C07).
3. **Legible failure.** Vend's tungsten cubes and the 93-person
   hallucinated contact list are the memorable artefacts (C02, C09).
4. **A human in the loop to react.** Removing human chat coincided with
   the audience and donations falling by 75% (C01, C04).
5. **Novelty decays fast and does not return.** TPP's second run, Nothing
   Forever's 8 viewers, AI Village's 2026 season (C04, C06, C08).

Idleness is the unsolved presentation problem everywhere. The AI Village
answer is scheduling — agents simply do not run outside 9–5 PT weekdays
(C01), which makes "nothing is happening" an honest, published fact
rather than a broken-looking world.

### Secrets and private data on screen

No comparable solves this by redaction alone. The three observed patterns
are: inject credentials out of band and never render them (Devin, C14);
mask known values and warn that masking is incomplete (GitHub, C15); and
gate *actions* rather than *views* with an approval tool before anything
reaches a real person (AI Village, C01). OpenClaw and Moltbook are the
cautionary pair: a popular agent runtime with unencrypted secret storage,
and a spectating product whose exposed front-end key leaked 1.5 million
auth tokens, 35,000 e-mail addresses and private agent messages (C12,
C16).

---

## 2. Spatial community and office products

The honest summary of this category is that it was a pandemic market and
it contracted hard. This pass could open fewer of these sources than
intended; several rows are therefore marked unverified and should be
re-checked before they influence a decision.

| Product | Status found | Evidence |
| --- | --- | --- |
| Mozilla Hubs | `hubs.mozilla.com` now redirects to a Mozilla support article titled "End of support for Mozilla Hubs" | C17 (redirect observed; article body could not be loaded) |
| WorkAdventure | Open source, 5.8k stars; the repository ships `docker-compose.no-synapse.yaml` and `docker-compose.livekit.yaml`, i.e. a Matrix homeserver (Synapse) is the default bundled chat stack, with LiveKit as a media option | C18 |
| Gather | Pivot from events to virtual office, layoffs, later relaunch *(unverified)* | — |
| Skittish | Shut down by its solo operator after the pandemic demand fell *(unverified)* | — |
| Kumospace, SpatialChat, Teamflow, oVice, Topia | Various pivots and contractions *(unverified)* | — |

**The one directly usable finding** is WorkAdventure's stack. A walkable
2D world whose chat is a Synapse homeserver is not hypothetical — it is
shipped, open-source and self-hostable, which is a meaningful precedent
for [RD02](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)'s
"the city runs on SJL's products" where the chat product is a Matrix
client (C18). It also means the moderation surface is Matrix's, with all
that implies for room-level power levels, rate limits and abuse tooling.

**The empty-room problem** is best evidenced not from this category but
from Horizon Worlds, where internal documents reported by the *Wall
Street Journal* found "fewer than 200,000 monthly users" against a
300,000 figure Meta had given in February 2022, that most visitors
"generally don't return after first month", and that fewer than 9% of
user-created worlds were ever visited by more than 50 people (C19). A
world's size should follow its population, not its ambition — which is
already the city plan's stated instinct and now has a number behind it.

---

## 3. Persistent worlds with creator economies

### Land, and what it costs to keep

| World | Land model | Figures |
| --- | --- | --- |
| Second Life | Recurring tier. A full region (65,536 m², 22,500 prims) is **US$166.00/month**; parcels scale down to US$4.00/month for 512 m². Premium tiers include a land bonus before fees apply (512 / 1024 / 2048 m²). "The cost of land itself is based on demand and can fluctuate with the market." | C20 |
| Wurm Online | Free to play with a skill cap; premium time is "payable in real-world or in-game currency ('silvers', which can be acquired in-game or bought)", and deeds rent protected land | C21 |
| Decentraland | One-off NFT parcels. ~$20 at 2017 launch; $6,000–$100,000 by April 2021; DappRadar reported fewer than 1,000 daily transacting users in October 2022 with one 24-hour period at 38, against Decentraland's own claim of ~8,000/day | C22 |

The contrast is the lesson. Second Life's recurring tier funds the
servers that make land worth owning; Decentraland's one-off sale funded
the seller once and left an empty map. RD09 sells a block for a house
with a one-time payment, and the open question it records — "for how long
the home is hosted" — is exactly the gap the comparables expose. Neither
model is wrong, but a one-time price must have a stated hosting term or a
stated upkeep, or the operator carries an unbounded liability for every
house ever sold.

Second Life's own scale, for calibration: ~1 million regular users in
2013; 800,000–900,000 active at end-2017; average concurrency of 38,000
in January 2008 with a Q1 2009 maximum of 88,200; a $567M economy in
2009; residents cashed out ~$60M in 2015. Crucially, of ~64,000 users
making a profit in February 2009, most earned under $10 a month and only
233 exceeded $5,000 (C23). A creator economy is a very thin pyramid.

### Currency: earned plus purchased

Every long-lived example separates a *soft, earned* currency from a
*hard, purchased* one: Neopets' Neopoints and Neocash (C24); Habbo's
Credits (bought), Duckets (earned) and Diamonds (C25). This matches RD07
and RD08 exactly, and the operational hazard the same examples show is
the grey market: Neopets' history includes a 2022 breach exposing the
database schema and credentials of 69 million users (C24). If earned
credits buy real compute (RD08), they acquire a real exchange rate, and
therefore a real incentive to farm and steal them.

### Moderation cost, in headcount

| World | Moderation evidence |
| --- | --- |
| Club Penguin | Of roughly 100 employees in May 2007, "approximately 70 staff were dedicated to policing the game"; "Ultimate Safe Chat" let players pick from a menu rather than type; filters were aggressive enough to block "mom" | C26 |
| Habbo | In 2011 moderators were tracking "some 70 million lines of conversation worldwide every day". After the June 2012 Channel 4 investigation Sulake muted chat globally and restored it region by region; investors Balderton Capital and 3i withdrew funding | C25 |
| Roblox | "over 1,600 people working to remove such material"; 85.3M daily active users reported February 2025; a $12 million child-safety settlement; global age verification mandated January 2026 with facial analysis or ID required for communication | C27 |
| VRChat | Automated trust ranks; opt-in age verification via a third-party provider from January 2025; ~120,000 concurrent on 2025 weekends, ~149,000 at New Year 2025–26, ~156,700 at a February 2026 event | C28 |

Club Penguin's 70-of-100 ratio is the number to sit with. A world that
hosts children's free text needs most of its company to be moderators.
The evidenced alternative is to constrain the text: menu chat,
whitelists, or an adult-only scope. Habbo's own 2024 answer to its
history was Habbo Hotel: Origins, "targeted at adults only" (C25).

### What shut, and why

| Product | Outcome |
| --- | --- |
| Rec Room | 150M lifetime players and a $3.5B valuation in December 2021; 16% of staff cut March 2025, 50% of the remainder August 2025; shut down 1 June 2026 with the statement "we basically tried all the ideas we had to reach sustainable profitability". UGC economics were part of it: the company kept 70c per dollar on first-party content but only 30c on user content after paying creators | C29 |
| Horizon Worlds | Refocused almost exclusively on mobile by February 2026; announced then partly reversed discontinuing the VR version in March 2026 | C19 |
| Decentraland | Land price collapse against tiny transacting-user counts | C22 |

Rec Room is the sobering one: enormous reach, real creator payouts,
abundant funding, and it still could not close the gap between hosting
cost and revenue. A UGC world's unit economics are worse than its user
numbers look.

---

## 4. Cozy and civic loops for a quiet city

Agentnagar's launch condition is a quiet city. The relevant question is
not "what is fun with 500 people" but "what is worth doing alone, and
what happens when you leave".

| Game | Solo-visit value | Absence handling |
| --- | --- | --- |
| Animal Crossing: New Horizons | Real-world clock and hemisphere-accurate seasons; content deliberately gated behind updates so players "could not skip ahead"; crafting and landscaping have no wait-times, so a short visit is complete | Long absences produce visible neglect and villager comments *(unverified in this pass)* |
| Stardew Valley | Time passes only while playing | Neutral: absence costs nothing *(unverified)* |
| Palia | Cozy MMO with instanced plots | 10 million players by April 2026, but 49 staff (35%) cut April 2024 and 36 more (40%) in May 2024 before Daybreak acquired Singularity 6 in July 2024 |
| Webfishing | A "multiplayer chatroom-focused fishing game" in lobbies of 1–12; 10,000 peak concurrent in its first Steam week; Polygon called it "the perfect game for catching up with friends" | Lobby-based, so nothing persists to decay |
| FFXIV housing | Housing lottery and automatic demolition of unvisited houses *(unverified in this pass)* | — |
| WoW player housing (2025–26) | Reported to explicitly avoid lotteries, demolition and upkeep *(unverified in this pass)* | — |

Sources: C30 (Animal Crossing), C31 (Palia), C32 (Webfishing).

**Webfishing is the most transferable comparable in this section and the
cheapest to study.** A solo developer, a tiny persistent surface, lobbies
of a dozen, and the draw is *being somewhere with people while doing
something low-stakes*. It is what a quiet Agentnagar plaza will feel like
if it works. It also shows the cost: a game whose whole appeal is open
voice and text in small rooms inherits every moderation problem of open
voice and text in small rooms, with no tooling.

**Palia is the cautionary comparable.** A funded studio building exactly
the cozy-MMO-with-plots shape cut 75% of its staff across two rounds
within nine months of launch and was acquired (C31). Player numbers did
not save the cost structure.

**Animal Crossing's real-clock design gives one concrete, borrowable
rule:** tie content to the real calendar and to updates rather than
front-loading it, so that a returning player finds something that was not
there before and a time-traveller cannot exhaust it (C30). For
Agentnagar, the Guild's actual work is already a real-time feed with this
property for free — what happened today genuinely did not exist
yesterday. That is the strongest structural asset RD01 has.

---

## 5. Maker platforms that are not worlds

These compete for the same evenings, and most of them do the transactional
jobs better than a city will.

| Platform | What it does well | The number | Source |
| --- | --- | --- | --- |
| itch.io | Low-friction project pages with creator-set revenue share (default 10%, configurable to 0%) and jams as the engagement engine | Over 1,000,000 products as of November 2024 | C33 |
| Hugging Face Spaces | A demo as a shareable unit, with explicit secrets/variables separation and a Secrets Scanner | Free CPU Basic is 2 vCPU / 16 GB / 50 GB non-persistent; free-tier Spaces "go to sleep" when unused; Gradio and Docker Spaces now require a paid plan, with 2 free ZeroGPU Spaces for personal accounts | C34 |
| Hack Club Summer of Making | The closest existing analogue to "earn credits by shipping real things": teenagers built open-source projects, earned "shells", and redeemed them for hardware and hosting credits, on a published price list from ~2 hours (stickers) to >500 hours (a laptop or an H100) | Ran 16 June – 30 September 2025 | C35 |
| Glitch | Was the friction-free place to host a small app | Announced 22 May 2025, hosting and profiles ended 8 July 2025, across "millions of users running tens of millions of apps"; reasons given were rising cost and maintenance, abuse "by bad actors", and legacy architecture that "hasn't been providing something uniquely valuable"; dashboard downloads to end-2025, subdomain redirects through end-2026 | C36 |
| buildspace | Seasons: a free six-week cohort with weekly ship updates and an in-person finale | ~150,000 participants across five seasons; Season 5 had ~70,000 applicants and ~5,000 completions; 3,000+ products shipped; $10M from a16z at a $100M valuation; closed 23 August 2024 with 2+ years of runway, not for money: "In a weird way, buildspace feels 'done' to me" | C37 |

**Three lessons land directly on Agentnagar's plans.**

*Free compute attracts abuse, and abuse is what kills it.* Glitch's
shutdown reasons name abuse explicitly alongside cost (C36). Hugging Face
sleeps idle free Spaces and has moved compute-backed Spaces behind a paid
plan (C34). RD08 makes credits buy real compute and storage; the
comparables say the metering, the sleep policy and the abuse response
must exist on day one, not later.

*Earned-currency-for-real-goods works, with a price list.* Hack Club ran
it at scale with a published hours-to-prize table (C35). The design
question it raises for RD08 is the same one Hack Club had to answer: what
stops someone farming hours, and who reviews a shipped thing.

*Seasons beat permanence for a small operator.* buildspace's format —
six weeks, weekly public ship updates, a demo finale — produced 3,000+
shipped products, and its ending was founder energy, not economics (C37).
A city that runs seasons has a reason for people to return on a date, and
the operator gets defined quiet periods.

**What would make the city additive rather than competing:** every one of
these platforms already owns hosting, distribution and payment. None of
them offers ambient co-presence, a persistent identity for a project
across tools, or the ability to watch someone else's process. The city
should link and embed itch/HF/GitHub pages rather than re-host them, and
sell the thing none of them sell.

---

## 6. Solo-operated communities and worlds

| Operator | Scale | What the operator said |
| --- | --- | --- |
| Cohost (Anti Software Software Club) | 4 staff; ~227,000 registered but 16,846 monthly actives and 3,046 paying subscribers by August 2024; funded by a single benefactor, with whom they temporarily lost contact in March 2024 | Announced 9 September 2024, read-only 1 October, closed 12 January 2025, for "lack of funding and developer burnout" | C38 |
| Neopets | Peak 35M unique users (2005); down to ~100,000 daily actives by 2017; 1.5M monthly in 2020; tripled to 300,000 monthly by April 2024 after a July 2023 management buyout with $4M of investment; highest revenue since 2017 and "on track to be profitable by the end of 2024" | Dual currency survived two decades; so did the cheating economy, and a 2022 breach exposed 69 million users' credentials | C24 |
| Wurm Online | Began as a two-person project; premium payable in cash or in-game silver; deeded land is rented | The upkeep model is the durable one; this pass could not verify decay and lapse mechanics | C21 |
| buildspace | See §5 | Shut with money in the bank because the founder was done | C37 |

Cohost is the single most instructive row for a solo founder. Four
people, a genuinely loved product, and the ratios that killed it are
legible: roughly 7% of registered accounts were monthly active, and about
1.3% paid. If Agentnagar's residency revenue is modelled on registered
accounts rather than on actives, the model is wrong by an order of
magnitude.

The recurring pattern across Cohost, buildspace and Glitch is that none
of the three died of a competitor. They died of cost, abuse and operator
energy — the three things a solo founder has least of.

---

## 7. Synthesis

### (a) RD01 as a first slice: strengths and risks

**Strengths the evidence supports.** The first slice is the only part of
the plan with a proven audience shape: AI Village has run the same idea
daily for eighteen months on ~$10k/month (C01), Pixel Agents shows the
spatial-office presentation working off real tool events at 9.3k stars
(C13), and Moltbook showed that "humans watch, agents act" (RD03) can go
viral (C12). Unlike every cozy-world comparable, the content is genuinely
new every day at no content cost, because it is real work.

**Risks the evidence names.**

1. **Novelty decay is the base case.** TPP's second run, Nothing
   Forever's eight viewers, AI Village's 2026 fundraising at a quarter of
   2025's (C04, C06, C08). Plan the second month, not the launch.
2. **Removing human interaction removes the audience.** AI Village's own
   data point (C01, C04). RD03's observe-only default is safe but
   audience-negative; RD04's tiering is therefore load-bearing, not a
   later refinement.
3. **Authenticity is the failure mode for this exact genre.** Moltbook's
   collapse was credibility, not uptime (C12). If the city ever animates
   an agent that is not working, it inherits that risk.
4. **Open chat with agents is a prompt-injection surface**, on top of the
   moderation load (C01, C16).
5. **Idleness is unsolved.** Everyone schedules around it (C01).

**The design choices comparables suggest matter most**, offered as
options:

| # | Choice | Evidence |
| --- | --- | --- |
| D1 | Publish working hours and show the city as honestly closed outside them | AI Village's 9–5 PT weekday schedule (C01) |
| D2 | Use a small, honest state vocabulary including "waiting on a human" | Pixel Agents' typing / reading / flagging states (C13) |
| D3 | Give every agent a persistent name, memory and visible history | Neuro-sama's character durability; AI Village's persona posts (C05, C07) |
| D4 | Show failures, don't hide them | Project Vend; the 93-person contact list (C02, C09) |
| D5 | Attach a countable outcome to each week | AI Village's goals, merch, event (C02, C03) |
| D6 | Make comments asynchronous and pinned to a work item, not a global room | AI Village's "chaos ensued" open chat (C01) |
| D7 | Gate agent-affecting *actions* behind approval, not just visibility | AI Village's outreach approval tool (C01) |
| D8 | Never render secrets; inject out of band and assume masking is incomplete | Devin; GitHub's own warning; OpenClaw's criticism (C14, C15, C16) |

### (b) Cold start for the first 100 registered users

Options, with the evidence behind each:

| Option | Evidence | Cost to the operator |
| --- | --- | --- |
| Seasons with a dated finale | buildspace: 3,000+ shipped products from six-week cohorts (C37) | High at the season boundary, low between |
| Publish the work log first, world second | AI Village's blog is the distribution channel; the village is the subject (C05) | Low, ongoing |
| Paid or invited entry as a moderation filter | Cohost's 1.3% paid conversion suggests a free tier does not fund itself anyway (C38) | Reduces load |
| Earn-credits-for-shipping with a published price list | Hack Club's shells-to-hardware table (C35) | Needs a review process |
| Adults-only scope at launch | Habbo Origins, "targeted at adults only"; Roblox's Jan 2026 global age verification (C25, C27) | Removes the largest compliance burden |

### (c) Candidate success and kill signals

The comparables do not publish retention curves, so these are the
*measurable quantities they were judged by* rather than validated
thresholds. Numbers are the owner's to set.

| Signal | Why it, from the evidence |
| --- | --- |
| Returning visitors in week 2, not launch-week uniques | Horizon Worlds: most visitors don't return after the first month (C19) |
| Monthly actives as a share of registered | Cohost: 16,846 of ~227,000 (C38) |
| Paying share of monthly actives | Cohost: 3,046 subscribers (C38) |
| Hours of agent work watched per visitor | AI Village's own per-agent runtime framing (C03) |
| Comments per work item, and time-to-first-reply | RD05's core loop; the only asynchronous retention mechanism that survives quiet hours |
| Cost per monthly active | AI Village ~$10k/month; Rec Room's failure was this ratio (C01, C29) |
| Moderation reports per 1,000 actives, and time to action | Club Penguin's 70-of-100 staffing; Habbo's 70M lines/day (C25, C26) |
| Kill signal precedent | Rec Room: "we basically tried all the ideas we had to reach sustainable profitability" (C29) |

### (d) Five things to go and observe for an hour each

Nothing in this brief was observed live. These five would convert the
most desk research into judgement, in priority order.

| # | What | What to look for |
| --- | --- | --- |
| 1 | **AI Village** (theaidigest.org/village), one working hour | How long before you are bored; what you look at when an agent is thinking; whether the memory and history views answer "what did I miss"; how idleness reads |
| 2 | **Pixel Agents**, run against your own agents | Whether the state vocabulary is legible at a glance; what happens visually when an agent waits for permission; whether anything leaks into the character's screen |
| 3 | **Webfishing**, one lobby | What makes a near-empty shared space worth staying in; how proximity chat feels with strangers; what you would have to moderate |
| 4 | **Second Life**, one hour on mainland and one Premium plot page | What a recurring tier buys; what abandoned land looks like; how the L$ purchase flow presents itself |
| 5 | **A coding-agent session viewer you use daily** (Devin, Codex or Claude Code on the web) | Which parts of a session log a stranger could safely watch; what would have to be redacted before a public street could show it |

---

## What could not be verified

This pass exhausted its web-search budget early and several sources
refused automated fetches. The following were in scope and are **not**
evidenced above. They should be researched before any decision leans on
them.

| Topic | Status |
| --- | --- |
| Gather funding, layoffs, pivots and 2026 status | Not fetched |
| Skittish shutdown post-mortem (waxy.org) | URL not found by direct fetch |
| Mozilla Hubs shutdown date and reasons | Only the redirect to an "end of support" article was observed (C17) |
| Kumospace, SpatialChat, Teamflow, oVice, Topia, Roam, Wonder | Not fetched |
| Claude Plays Pokémon / Gemini Plays Pokémon viewer figures and overlay design | Not fetched; only a third-party scaffolding write-up (C39) |
| Stanford "Smallville" running cost | Paper PDF exceeded fetch limits |
| Character.AI rooms, retention and 2025 minor-safety changes | Not fetched |
| Second Life: Tilia's sale, current concurrency, 2025–26 ownership news | Not in the fetched article (C23) |
| Roblox DevEx annual payout totals and rate | Docs URL 404 |
| Minecraft commercial usage guidelines wording | Fetch timed out |
| FFXIV housing lottery and demolition timer; WoW housing philosophy | Both fetches blocked or 404 |
| Animal Crossing absence mechanics; Stardew absence handling | Not in the fetched articles |
| Eco small-server drop-off; Cities: Skylines II lessons | Not fetched |
| Flight Rising registration windows; Screeps CPU subscription tokens | Not fetched / not on the page fetched |
| Recurse Center Virtual RC feature set | Not present on the pages fetched |
| Replit, Val Town, Product Hunt, Indie Hackers, Discord figures | Not fetched (session limit) |
| Matrix public-room moderation and spam tooling | Not fetched |
| Manyland, Core, Crayta, Dreams shutdown reasons | Not fetched |
| One Hour One Life, Eternal Lands, MetaFilter, Kingdom of Loathing | Not fetched |
| Retention benchmark reports (GameAnalytics et al.) | Not fetched |

Two internal inconsistencies to note: a search snippet gave buildspace's
participant count as 125,000 where the fetched article gives ~150,000
(C37); and AI Village's own figures for concurrent agents differ between
its FAQ ("over 15") and its year review ("11 agents now running
concurrently"), which is consistent with the roster changing over time
but means neither number is a current count.

## Sources

Accessed 18 September 2026 unless otherwise stated.

| ID | Source |
| --- | --- |
| C01 | AI Village, [How the AI Village works](https://aivillageblog.substack.com/p/how-the-ai-village-works), 16 June 2026 |
| C02 | AI Village, [What did we learn from the AI Village in 2025?](https://aivillageblog.substack.com/p/what-we-learned-2025), 2 February 2026 |
| C03 | AI Village, [The AI Village in Numbers](https://aivillageblog.substack.com/p/village-in-numbers), 24 September 2025 |
| C04 | AI Village, [More capable AI, less money raised](https://aivillageblog.substack.com/p/more-capable-ai-less-money-raised), 27 May 2026 |
| C05 | AI Village blog index, [aivillageblog.substack.com](https://aivillageblog.substack.com/) and the village page [theaidigest.org/village](https://theaidigest.org/village) (post list read from the live page) |
| C06 | Wikipedia, [Twitch Plays Pokémon](https://en.wikipedia.org/wiki/Twitch_Plays_Pok%C3%A9mon) |
| C07 | Wikipedia, [Neuro-sama](https://en.wikipedia.org/wiki/Neuro-sama) |
| C08 | Wikipedia, [Nothing, Forever](https://en.wikipedia.org/wiki/Nothing,_Forever) |
| C09 | Anthropic, [Project Vend: Can Claude run a small shop?](https://www.anthropic.com/research/project-vend-1) |
| C10 | GitHub, [a16z-infra/ai-town](https://github.com/a16z-infra/ai-town) |
| C11 | Altera et al., [Project Sid](https://arxiv.org/abs/2411.00114), arXiv abstract |
| C12 | Wikipedia, [Moltbook](https://en.wikipedia.org/wiki/Moltbook) |
| C13 | GitHub, [pixel-agents](https://github.com/pablodelucca/pixel-agents) (repository `pixel-agents-hq/pixel-agents`) |
| C14 | Devin documentation, [Secrets](https://docs.devin.ai/product-guides/secrets) |
| C15 | GitHub Docs, [Using secrets in GitHub Actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions) |
| C16 | Wikipedia, [OpenClaw](https://en.wikipedia.org/wiki/OpenClaw) |
| C17 | Redirect from [hubs.mozilla.com](https://hubs.mozilla.com/) to Mozilla Support, "End of support for Mozilla Hubs" (article body did not load) |
| C18 | GitHub, [thecodingmachine/workadventure](https://github.com/thecodingmachine/workadventure); WorkAdventure [documentation](https://docs.workadventu.re/) |
| C19 | Wikipedia, [Horizon Worlds](https://en.wikipedia.org/wiki/Horizon_Worlds) (citing *Wall Street Journal* reporting, October 2022) |
| C20 | Linden Lab, [Second Life land pricing](https://secondlife.com/land/pricing) |
| C21 | Wikipedia, [Wurm Online](https://en.wikipedia.org/wiki/Wurm_Online) |
| C22 | Wikipedia, [Decentraland](https://en.wikipedia.org/wiki/Decentraland) (citing DappRadar, 13 October 2022) |
| C23 | Wikipedia, [Second Life](https://en.wikipedia.org/wiki/Second_Life) |
| C24 | Wikipedia, [Neopets](https://en.wikipedia.org/wiki/Neopets) |
| C25 | Wikipedia, [Habbo](https://en.wikipedia.org/wiki/Habbo) |
| C26 | Wikipedia, [Club Penguin](https://en.wikipedia.org/wiki/Club_Penguin) |
| C27 | Wikipedia, [Roblox](https://en.wikipedia.org/wiki/Roblox) |
| C28 | Wikipedia, [VRChat](https://en.wikipedia.org/wiki/VRChat) |
| C29 | Wikipedia, [Rec Room](https://en.wikipedia.org/wiki/Rec_Room_(video_game)) |
| C30 | Wikipedia, [Animal Crossing: New Horizons](https://en.wikipedia.org/wiki/Animal_Crossing:_New_Horizons) |
| C31 | Wikipedia, [Palia](https://en.wikipedia.org/wiki/Palia) |
| C32 | Wikipedia, [Webfishing](https://en.wikipedia.org/wiki/Webfishing) |
| C33 | Wikipedia, [itch.io](https://en.wikipedia.org/wiki/Itch.io); itch.io, [About](https://itch.io/docs/general/about) |
| C34 | Hugging Face, [Spaces Overview](https://huggingface.co/docs/hub/spaces-overview) |
| C35 | Hack Club, [Summer of Making](https://summer.hackclub.com/landing) |
| C36 | Glitch, [Important changes are coming to Glitch](https://blog.glitch.com/post/changes-are-coming-to-glitch/), 22 May 2025 |
| C37 | Almanac, [The Night buildspace Closed](https://www.openalmanac.org/w/founders-inc/the-night-buildspace-closed) |
| C38 | Wikipedia, [Cohost](https://en.wikipedia.org/wiki/Cohost) |
| C39 | LessWrong, [notes on running LLMs on Pokémon Red](https://www.lesswrong.com/posts/8aPyKyRrMAQatFSnG/untitled-draft-x7cc) |

Wikipedia entries are secondary summaries used where a primary source
could not be reached in this pass; their own citations were not followed
and their figures should be confirmed against the underlying reports
before they are relied upon.
