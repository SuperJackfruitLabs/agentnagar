# Gap review of the planning draft

Dated review · 2026-09-18 · [Plan index](../README.md) ·
[Decision register](VISION_DECISIONS.md)

This review asked what the five-milestone draft still needed: discussion,
research, integration design or anything else. It read every brief and all
three prototypes, and checked integration assumptions against the sibling
repositories after fetching each one on 2026-09-18. It is a dated record.
Later changes belong in the owning briefs, not here.

**Evidence limits.** The review read documents and source code. It ran no
product, called no live service and tested nothing with people. Sibling
repositories were read at `origin/main` plus the feature branches checked out
that day (several had unmerged work), plus internal SJL cross-product decisions. Legal
and tax points are flags for professional advice, not conclusions.

## What happened next

Rakesh answered the largest questions the same day. Those answers are
**RD01–RD17** in the [decision register](VISION_DECISIONS.md#decisions-recorded-on-2026-09-18).
The table below maps each headline finding to its outcome.

| Finding | Outcome |
| --- | --- |
| Four competing "first loops" and no single first slice | **Decided, RD01:** walk the city and watch the 14 Guild agents at work |
| Text communication undecided (emotes first versus comments and assemblies) | **Decided, RD05:** comments, messages and assemblies are critical |
| Anonymous visitors versus adult-only hosted sessions; anonymous agent demos | **Decided, RD03/RD04:** the public observes only; interaction starts at a registered account and widens by tier and authority |
| Whether cash can buy credits; what credits buy | **Decided, RD07/RD08:** earned, bought or included with a tier; they buy facility access, items, compute and storage |
| "Sponsor" used with four meanings | **Decided, RD09/RD10:** buying a block and residency is one thing, sponsoring the lab is another |
| India-first or global | **Decided, RD11:** global |
| Public roles proposed for personal agents | **Decided, RD12:** personal agents are private to their owner unless shared |
| Forgejo placement | **Decided, RD13:** Forgejo on the lab server; agents get a dedicated git system |
| Relationship to Agentic Space undefined | **Decided, RD16:** knowledge bank only |
| Engine trial framed as the next step | **Decided, RD15:** technology waits for the vision |
| Integration gaps with sibling products | **Deferred, RD14:** recorded [below](#integration-gaps-verified-against-sibling-repositories) as facts |
| Name and trademark never checked | **Open, RD17:** [name research](../research/NAMING.md) |
| Missing research | **Started:** see [research added](#research-added-on-2026-09-18) |
| Stale and contradictory documents | **Corrected** in the owning briefs on 2026-09-18 |

## Still open after the decisions

These need Rakesh's judgement. Each decision above also lists what it opens.

1. **Success signals, stop signals and a founder budget.** No brief states
   what would count as working, what would justify stopping, or how many
   hours and how much money per month the city may consume. The community
   charter names seven operating roles; SJL is one person. Several core loops
   wait on a human approval, which makes the founder the loop's latency.
2. **How public Guild characters relate to the working agents.** An internal
   SJL decision gives each agent one principal. The same 14 agents do SJL's internal work.
   Decide whether the public sees the same runtime through a filtered
   projection, or a separate memory-free public instance answers registered
   users. RD01 needs only the projection; RD04 needs this answer.
3. **What work state is public.** Task titles, repositories, reasoning,
   failures and idleness can all leak private or third-party material. RD01
   needs a field list and a redaction rule before anything is shown.
4. **Untrusted input.** Registered users will write to agents, and comments
   may reach agents that read the city. No brief has a prompt-injection,
   output-moderation or transcript-retention model.
5. **Purchased credits that buy real compute.** This changes the legal
   character of the currency in each market, makes every earned credit a
   possible real cost, and makes stolen cards and alternate accounts
   profitable. See the [legal](../research/LEGAL_COMPLIANCE.md),
   [payments](../research/PAYMENTS_AND_CREDITS.md) and
   [economy model](../research/ECONOMY_MODEL.md) research.
6. **A one-time price against an open-ended hosting cost.** Decide what the
   block purchase includes and for how long a home is hosted.
7. **Selling entity, terms and licence.** Which entity sells globally, under
   what terms and privacy policy, and under what licence this repository and
   later code are published. Residency earned by contribution also needs a
   contributor agreement and a tax view.
8. **Adding personal agents (RD12) is a new feature area.** How a person adds
   an agent, where it runs, who pays and what sharing grants are all unwritten.
9. **Cultural direction and languages.** The Guild cast has Western names in
   a city with a Hindi name, and no brief plans for Hindi or any other
   language. RD11 makes this a global question.
10. **Cold start.** No brief says why a maker would choose the city over the
    places they already use, or how the first hundred registered users arrive.
    See [comparable worlds](../research/COMPARABLE_WORLDS.md).

## Integration gaps verified against sibling repositories

Facts as of 2026-09-18, recorded to design around (RD14). None is a decision.
Paths are relative to the workspace that holds the sibling repositories.

| Area | The city briefs assume | What exists today | Evidence |
| --- | --- | --- | --- |
| Identity | A new "city account" with no assumed SJL account platform, and no sign-in design | An internal SJL decision mandates one issuer, the AgentPod hub, with other planes verifying offline. Hub signup closes after the first admin. No internal cross-product decision mentions Agentnagar | Internal SJL decision (one issuer, offline verification); `agentpod/README.md` |
| AgentPod status | A city-side adapter publishes opted-in role and status | `/api/*` refuses non-human hub tokens by design. No service accounts or outbound events. The fleet contract has no current-task or last-active field. Human hub tokens are short-lived | `agentpod/apps/hub/src/auth/middleware.ts`; `agentpod/packages/contract/src/fleet.ts` |
| Agent dispatch | A city gateway sends scoped task requests | Production parks a card that lacks a matching `mayDispatch` grant | `superpipeline/apps/api/src/board/board-do.ts` |
| Superpipeline | Create and read cards, receive run and gate events, map project membership | One personal tenant per user, per-tenant roles, no per-board access control, no service credential, no idempotency key. Only `work.available` and `gate.pending` are pushed. The MCP server cannot create cards or read a board. The `member` role is a default, not a guardrail | `superpipeline/docs/05-integration-surfaces.md`; `apps/api/src/db/catalog.ts`; `apps/api/src/auth/resolve.ts` |
| Agent tokens | `kbn_` prefix retained | The prefix is `spa_`, with no fallback | `superpipeline` `origin/main` `apps/api/src/auth/agent-token.ts` |
| Matrix and Supermessage | "Project rooms" through an adapter, no homeserver named | Supermessage is a client with no web build. The 14 agents already have Matrix identities. An internal SJL decision requires explicit, never inferred, links from a Matrix ID to a principal | `supermessage/AGENTS.md`; internal SJL decision (ecosystem identity) |
| Forgejo | Superpipeline for work, Forgejo for code | Superpipeline parses GitHub references only. AgentPod knows `forgejo` as an enum value | `superpipeline/apps/api/src/references/github-url.ts`; `agentpod/packages/contract/src/run.ts` |
| SuperMD | File authoring; publishing is a new city job | An `html-export` plugin, a static-site example and a plugin interface exist. There is no headless CLI | `supermd/plugins/html-export/`; `supermd/examples/build_docs.rs` |
| Website | Shared place IDs and an account handoff | The website renamed the place `kaambaan` to `superpipeline` with a migration shim. Its plan puts `/home`, `/residents`, `/city`, `/agents` and `/profile` on the SJL site and predates a separate project domain. Nobody owns the ID registry | `super-jackfruit-website/src/scripts/village/visits.mjs`; `super-jackfruit-website/docs/VILLAGE_WEBSITE_PLAN.md` |
| Builder versus character | "Builders and city characters are different principals" | An internal SJL decision gives each agent exactly one principal | Internal SJL decision (an agent is a principal) |

## What the research found that changes the plan

Six findings from the briefs below bear directly on decisions already taken.
Each is sourced in its brief; none is a decision.

1. **Razorpay's terms may prohibit the credit model.** Its prohibited list
   covers "credits that can be monetized, re-sold or converted to physical or
   digital goods or services". Read literally that describes RD07 plus RD08.
   Three readings are possible and only Razorpay can say which applies; the
   [payments brief](../research/PAYMENTS_AND_CREDITS.md) drafts the question
   to send. Paddle and Polar ban stored-value credits outright, so provider
   choice is now coupled to the credit design.
2. **Purchased credits plus prize competitions is the regulated pattern.**
   India's Online Gaming Act 2025 defines "other stakes" to include virtual
   credits bought with money. Earned-only competitions and separate balances
   are the design that stays clear of it. See the
   [legal brief](../research/LEGAL_COMPLIANCE.md).
3. **Only separated balances bound the liability.** With one fungible balance
   a farmer running ten alternate accounts extracts real compute worth about
   a thousand dollars a year; with earned credits barred from real-cost
   services that falls to zero. A capped reviewed conversion window keeps
   RD08's promise at a bounded price. See the
   [economy model](../research/ECONOMY_MODEL.md).
4. **The closest prior art warns about attention, not feasibility.** AI
   Village has run agents at work publicly since 2025 at roughly ten thousand
   dollars a month, and its audience fell as the agents got better. It opened
   human-to-agent chat and closed it again. That is direct support for RD03
   and RD04, and a caution for W1's "reason to return". See
   [comparable worlds](../research/COMPARABLE_WORLDS.md).
5. **Self-attested adulthood satisfies no market.** The community charter
   relies on it. For a global product (RD11) it meets neither the UK's
   "highly effective" test, nor verifiable parental consent under India's
   rules, nor a neutral age screen under COPPA. RD05 also makes the city an
   intermediary with short statutory takedown windows.
6. **Forgejo's OAuth2 provider scopes are not implemented**, so a provider
   token carries full account authority. That matters for RD13's dedicated
   git system for agents. See
   [hosting and agent git](../research/HOSTING_AND_AGENT_GIT.md).
7. **The name search favours keeping Agentnagar (RD17).** Agentnagar and
   Agentganj are both clear, with no trade-mark records found in the searched
   databases. "Agent City" is crowded and descriptive, so it is not ownable;
   "ganj" carries a cannabis association in English search and trade-mark
   records. "Moolah" (RD06) collides with slot and lottery brands and reads
   as cash, which is the opposite of what the credit should look like to a
   regulator. See [naming](../research/NAMING.md).

## Research added on 2026-09-18

All desk research, with its limits stated in each file.

| Question | Brief |
| --- | --- |
| Law and compliance for a global product with purchasable credits, user text and AI agents | [Legal and compliance](../research/LEGAL_COMPLIANCE.md) |
| Selling globally from India; credit and tier payment patterns | [Payments and credits](../research/PAYMENTS_AND_CREDITS.md) |
| What agent interaction, observation, voice, compute and storage cost | [Agent runtime costs](../research/AGENT_RUNTIME_COSTS.md) |
| Sources, sinks and liability of credits that buy real services | [Economy model](../research/ECONOMY_MODEL.md) |
| Comparable worlds, agent-watching products and maker platforms | [Comparable worlds](../research/COMPARABLE_WORLDS.md) |
| Audience, device baseline, accessibility standards and languages | [Audience, devices and accessibility](../research/AUDIENCE_DEVICES_ACCESSIBILITY.md) |
| Public accounts, comments and assemblies, moderation for a solo operator | [Identity and moderation](../research/IDENTITY_AND_MODERATION.md) |
| Forgejo on the lab server, git for agents, hosting a global product | [Hosting and agent git](../research/HOSTING_AND_AGENT_GIT.md) |
| City name and credit name | [Naming](../research/NAMING.md) |

## Documents corrected on 2026-09-18

- Token prefix, AgentPod CLI release facts and the organisation-plane status in
  the ecosystem, agent-city and architecture briefs. The dated
  [product refresh](../research/SJL_PRODUCT_REFRESH_2026-09-16.md) keeps its
  findings and carries a superseding note.
- VISION and EXPERIENCES brought in line with the open maker city. Place,
  district and facility names reconciled against the city plan.
- A [glossary](GLOSSARY.md) for overloaded terms: sponsor, tier,
  village/town/city, the ID prefixes and the agent cohorts.
- Reward fixtures, the reading garden's missing funding source and the NPC-tax
  mint are now labelled as unreconciled in the economy brief.
- The three prototypes: the atlas follows the open maker city and shows the
  RD01 view with fictional data; the economy lab uses the threshold tax model
  and separate earned and purchased balances; the city lab no longer charges
  full upkeep for closed services and no longer has a tax setting that always
  wins.
