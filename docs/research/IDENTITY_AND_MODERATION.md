# Identity, conversation and moderation for a public city

Desk research · 2026-09-18 · [Plan index](../README.md)

**Evidence limits.** This is desk research for
[RD03/RD04](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)
(observe-only public, tiered registered interaction),
[RD05](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)
(comments, messages and assemblies are core),
[RD11](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)
(global) and
[RD12](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)
(private personal agents), under
[RD15](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18):
**no technology is chosen here and nothing below is a recommendation
phrased as a decision.** Nothing was installed, deployed, benchmarked or
signed up for. No account was created with any vendor; no paid API was
called; no homeserver, identity provider or moderation service was
exercised. Versions, prices, free-tier limits and legal positions are as
read on 2026-09-18 and change without notice — re-check every one before
it carries a choice. Each claim is marked **[verified]** (this pass
fetched the primary project, vendor or regulator page and read the
wording), **[secondary]** (a reputable third party, or a primary page
whose relevant section did not render), or **[unverified]** (not
established in this pass; absence of evidence here is not evidence that
no implementation exists). Nothing in this document is legal advice, and
the legal sections identify duties to take advice on rather than
settling them. Private infrastructure detail is
deliberately absent.

## 1. What SJL's internal decisions already fix, and what they do not

These are facts about the suite as it stands today, re-read in the
sibling repositories and SJL's internal cross-product decisions on
2026-09-18. They are the constraints any option
below has to meet, argue against, or amend.

| Fact | Source | Consequence for a public city |
| --- | --- | --- |
| **One issuer for the suite; every other plane verifies a signed token offline against a published JWKS and fails closed.** The issuer is Better Auth, deployed inside the AgentPod hub | Internal SJL decision "One issuer and offline verification" [verified, local] | A city that mints its own session cookies is a fifth identity silo unless it is either the issuer, a resource server, or explicitly mapped |
| **The valuable part is not running an IdP product; it is one issuer plus offline verification** | same decision [verified, local] | The rule constrains *shape*, not vendor. A different issuer product can satisfy it; two unmapped issuers cannot |
| **An agent is a principal in its own right**, `principals(id, kind, org_id, handle, …)`, `kind ∈ human \| agent \| service`; not a `user` row | Internal SJL decision "An agent is a principal" [verified, local] | A city "account" for a human and a city presence for an agent are different records, already |
| **An agent's Matrix ID is minted from an immutable `handle`**, not from where it runs; `display_name` stays mutable | same decision [verified, local] | Agent chat identity is stable across moves — usable as the anchor for public attribution |
| **Agents exchange, they do not hold. No refresh tokens.** A long-lived credential is exchanged for a short-lived token; re-exchange on expiry; suspending the principal stops every exchange | same decision [verified, local] | Gives revocation a lever; also makes the issuer an availability dependency for new work |
| **Grants name one principal and have no wildcards** | same decision [verified, local] | "All Guild agents may comment in the plaza" is an enumeration, not a pattern |
| **mxid-to-principal links are explicit** (`principal_identities`, `system` + `external_id`) | Internal SJL decision "Ecosystem identity" [verified, local] | A city identity for a stranger can be a further mapped identity rather than a new principal kind |
| **MAS is not part of this suite, now or later.** The suite runs tuwunel, not Synapse; Synapse is AGPLv3 and the operator required Apache/MIT | Internal SJL decision "Matrix identity without MAS" [verified, local] | Any "use MAS as the anchor" option is an amendment to an internal SJL decision, not a configuration |
| **The Matrix identity silo is the last one standing and is unsolved.** Humans sign in to tuwunel with `m.login.password`; whether tuwunel's `m.login.token` can be driven by an external issuer was recorded as unverified | same decision [verified, local] | See §4.2 — the ground under this has moved since it was written |
| **Keycloak was already tried and abandoned here.** `KEYCLOAK_*` was dead configuration found in the 2026-08-14 docs audit; the AgentPod redesign lists "Keycloak overhead for simple auth needs" and "complex infrastructure (4+ services to manage)" among the problems it removed, and Phase 3 is literally "Replace Keycloak with Better Auth" | Internal SJL decision "One issuer and offline verification"; `agentpod/docs/archive/architecture/redesign-plan.md` [verified, local] | Re-proposing Keycloak is re-proposing something this operator removed for operational weight, not for a missing feature |
| **The hub closes public signup after the first user.** `drizzle-auth.ts` assigns admin to the first signup and then calls `disableSignup`; `signupCheckMiddleware` blocks `/api/auth/sign-up/email` thereafter | `agentpod/apps/hub/src/auth/` [verified, local] | The issuer today is a single-operator issuer *by construction*. Public signup is a deliberate reversal |
| **The hub has a single bootstrap tenant.** `BOOTSTRAP_ORG_ID` is the org id principals are created under; Better Auth's `organization` plugin is deliberately disabled | `agentpod/apps/hub/src/services/principals.ts`; the principal decision [verified, local] | There is no multi-tenancy to switch on. Thousands of strangers need an org model that does not exist |
| **The hub's own login is GitHub OAuth plus email/password**, with `requireEmailVerification: false` and plugins `bearer`, `admin`, `jwt` | `agentpod/apps/hub/src/auth/drizzle-auth.ts` [verified, local] | Unverified email is survivable for one operator and is an abuse vector at city scale (§5) |
| **Superpipeline accepts a GitHub-OAuth session cookie or a hub JWT**, and `role: local ?? 'member'` is a *default*, not a ceiling — **though `local` was unreachable for a hub token until subject→user mapping landed on 2026-09-20; before that every hub token was `member` with no way to be otherwise** | `superpipeline/apps/api/src/auth/`; [TOOL_AUTOMATION](TOOL_AUTOMATION.md) [verified, local] | A second, unrelated public login path already exists in the suite |
| **No internal cross-product decision mentions Agentnagar.** | Review of SJL's internal decisions [verified, local] | Whatever the city does with identity is currently unagreed, in both directions |

**The gap in one sentence.** The suite's identity design is correct and
coherent *for one operator and fourteen agents*, and every property that
makes it good at that — closed signup, one bootstrap tenant, no
self-service recovery, enumerated grants, unverified email — is a
property a city of strangers cannot have.

## 2. Five shapes for public city accounts

Not five products; five *shapes*, each of which several products could
fill. Costs marked "solo" are the operational load on one founder.

| # | Shape | Fit with one-issuer rule | Solo burden | Main risk |
| --- | --- | --- | --- | --- |
| O1 | **Open the hub issuer to public signup**, add multi-tenancy | Perfect by definition — the issuer stays the issuer | Highest blast radius: the thing that mints operator and agent authority now faces the internet | One auth bug on a public endpoint reaches production agent authority |
| O2 | **A separate city issuer**, explicitly linked to hub principals | Needs an amendment: two issuers, or one issuer per audience with a mapping | Two systems to run, patch and rotate keys for | Divergence; "which issuer said this?" in every log |
| O3 | **An external IdP both hub and city trust** | Satisfies the shape; changes *who* the issuer is | Depends entirely on product (§3) | Re-runs the Keycloak experience if the product is heavy |
| O4 | **Matrix/MAS as the identity anchor** | Contradicts the stated layering (comms plane must not own org membership) *and* the "no MAS" decision | Low marginal if the homeserver is run anyway | The one plane a human looks at becomes the one that can lock everyone out |
| O5 | **Social/forge login only** (+ passkeys, magic links), no city password store | Compatible: the city is still a resource server | Lowest to start | Every account depends on a third party's ToS and ban decisions |

These are combinable. O5 is a *credential* choice that can sit inside
O1, O2 or O3. O4 is the only one that conflicts with a written decision
outright.

### 2.1 O1 — open the hub issuer

**What it would take.** Re-enable signup (a two-line reversal of
`disableSignup`, plus deleting `signupCheckMiddleware`'s effect);
introduce an org model beyond `BOOTSTRAP_ORG_ID`; enable or replace
Better Auth's `organization` plugin — which the principal decision
disabled *on purpose*, calling a second org model beside `principals`
"MT-1's mistake relocated" [verified, local]; add email verification,
recovery, rate limits and captcha; write a public privacy notice for a
service that currently has one user.

**What it buys.** Exactly one place where "who is this" is answered.
Every existing offline-verification consumer keeps working unchanged. A
city comment and an agent dispatch carry claims minted by the same code.

**What it costs.** The hub is already a critical service [verified,
local]. Adding thousands of strangers adds a public attack
surface, a support queue, a deletion/export duty and a legal-basis
question to a service whose availability agents' work already depends
on. The one-issuer decision's own note that "an issuer is an availability
dependency" becomes much sharper when a signup form is also a DoS
target.

**Evidence still needed.** Better Auth's throughput and rate-limit
behaviour under public load; whether the `organization` plugin and
`principals` can coexist without two org models; whether the hub's
database and hosting can carry a user table that grows by strangers.

### 2.2 O2 — a separate city issuer with explicit links

**What it would take.** A second Better Auth (or other) deployment whose
JWKS the city's own services verify, plus a `principal_identities`-style
mapping when a city account needs to touch a suite plane at all.

**The important observation:** most city accounts never need to. A
visitor who registers to leave a comment, hold a plot and attend an
assembly touches no AgentPod station, no Superpipeline board and no
Forgejo repository. The one-issuer rule exists so that *cross-plane*
calls carry a verifiable claim; a city-only account makes no cross-plane
call. The population that genuinely needs a hub-verifiable token is the
operator, the Guild agents, and any resident who is granted authority
over real compute — which
[RD04](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)
makes a tier, not a default.

**What it costs.** Two issuers is two key rotations, two revocation
stories, two upgrade paths and one honest question: what happens when
the same human holds both. The mapping must be explicit and
uni-directional in the way 2026-08-13 already requires; "same email"
must never be the join.

**Evidence still needed.** Whether a city account can ever be *promoted*
to a hub principal without the two becoming one system by accident; what
the audit trail looks like when a city identity acts on a plane.

### 2.3 O3 — an external IdP both trust

Facts on the candidates are in §3. The structural points:

- SJL's internal platform strategy already names this family neutrally:
  "OIDC provider such as Better Auth/Keycloak/Zitadel for human sign-in;
  do not invent human authentication" [verified, local]. So an external
  IdP is *within* that strategy's existing language; the one-issuer
  decision narrowed it to Better Auth for reasons of "no new deployable".
- Adopting one means the hub also becomes a relying party, or keeps
  issuing and the external IdP becomes an upstream — those are different
  designs with different failure modes.
- The Keycloak history is the relevant prior. The recorded objection was
  operational weight and local-testability, not capability.

### 2.4 O4 — Matrix/MAS as the anchor

Two independent facts now bear on this, and they point in opposite
directions.

- **SJL's internal decisions forbid it**, twice: MAS "is not part of this suite, now
  or later", and putting the communication plane in charge of identity
  "inverts the layering" the suite exists to hold [verified,
  local].
- **tuwunel has moved.** v1.8.3 (5 August 2026) ships "native OIDC
  account registration and login", described as the server "serving
  account login for the device authorization grant and account
  management **with no identity provider configured at all**"; v1.9.1
  (12 September 2026) adds native OIDC browser callbacks and
  `oidc_require_client_approval` (default `true`) before authorization
  codes are released to unvetted dynamic clients [verified]. v1.8.0 (27
  June 2026) additionally implemented MAS provisioning API endpoints,
  synced email bindings and SSO redirect-action forwarding (MSC3824)
  [verified], and v1.9.1 can reload MAS secrets without restart
  [verified].

So the premise that tuwunel cannot speak MAS is **out of date as of
mid-2026**, and separately tuwunel can now act as its own OIDC
*provider* and consume upstream OIDC providers. That is a fact the
internal decision could not have known, and the decision that recorded
"whether tuwunel's `m.login.token` can be driven by an external issuer
is unverified" now has a better-shaped question available: whether
tuwunel can be pointed at an existing issuer as an upstream OIDC
provider. **This is the single highest-value spike in this document**
and it is cheap. It does not make O4 correct — a homeserver that is its
own IdP is still the comms plane owning identity — but it removes the
"impossible" from the option and turns it into a layering argument.

### 2.5 O5 — social/forge login, passkeys, magic links

- **GitHub OAuth** is already in use in two SJL products, which makes it
  the lowest-friction addition and concentrates the dependency further.
  It also selects for developers, which suits a maker city and excludes
  the learners and players
  [VD01](../planning/VISION_DECISIONS.md#recommended-answers-for-discussion)
  also names.
- **Google OAuth** reaches everyone but requires app verification for
  public use, with brand review; timelines are variable [unverified this
  pass].
- **Forgejo can act as an OAuth2/OIDC provider**: authorisation code
  grant with PKCE (`code_verifier` 43–128 chars), discovery at
  `/.well-known/openid-configuration`, userinfo at
  `/login/oauth/userinfo`, JWKS at `/login/oauth/keys` [verified]. **But
  the docs state plainly that "OAuth2 scopes are not yet implemented"**,
  so third-party applications "will have administrative rights" and a
  token "can be used to execute any actions on behalf of the user"
  [verified]. That makes Forgejo-as-IdP unsuitable for delegating narrow
  authority today, and it is the same finding that matters in
  [HOSTING_AND_AGENT_GIT](HOSTING_AND_AGENT_GIT.md) §B.
- **Passkeys** are supported by every product in §3 and by Better Auth
  via a plugin [secondary]. The recovery problem is the real design
  work: a passkey-only account whose device is lost needs a fallback,
  and the fallback is what an attacker will target.
- **Magic links** remove the password store but not the email
  dependency, and corporate link-scanners consuming one-time links is a
  known failure mode [secondary, not re-verified this pass].

## 3. Product facts for the identity options

Versions and dates verified at the projects' own release pages on
2026-09-18 unless marked otherwise. Footprints, licences and
feature-completeness marked [unverified] were not established in this
pass and must not be treated as absent.

### 3.1 Self-hosted

| Product | Latest seen | Licence | Footprint | Passkeys | Public self-registration | Multi-tenant | RFC 8693 exchange |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Better Auth** (incumbent) | in-repo hub runs 1.6.26, console 1.4.6 (as recorded 2026-08-15) [verified, local] | MIT [secondary] | A library inside an existing app — no new deployable; that was the stated reason it won | Plugin [secondary] | Yes, but currently disabled after first user [verified, local] | `organization` plugin exists and is **deliberately disabled** [verified, local] | Not established [unverified] |
| **Authentik** | 2026.8 current, 2026.9 pre-release [verified] | Open core; enterprise features gated [secondary] | Server + worker + Postgres + Redis [secondary] | Yes [secondary] | Yes, with flows | Yes (brands/tenants) [secondary] | [unverified] |
| **Zitadel** | v4.17.3, 4 Sep 2026 [verified] | Named in SJL's internal platform strategy as a fallback alongside Ory Hydra, "both Apache-2.0" [verified, local]; **a later licence change to AGPL has been reported and is [unverified] here — check before relying on it** | Go binary + Postgres [secondary] | Yes [secondary] | Yes | Yes, orgs are first-class | Documented [secondary] |
| **Keycloak** | 26.7.4, 16 Sep 2026 [verified] | Apache-2.0 [secondary] | JVM; the heaviest here, and the recorded local objection | Yes | Yes | Realms | Yes (standard token-exchange) [secondary] |
| **Kanidm** | v1.11.2, 11 Sep 2026 [verified] | [unverified] | Rust, single binary, own database — the lightest credible option | Yes; WebAuthn-first design, `.well-known/passkey-endpoints` [verified] | Present but opinionated [unverified] | Limited [unverified] | [unverified] |
| **Ory Kratos + Hydra** | [unverified] | Apache-2.0 [secondary] | Two services plus database; identity and OAuth deliberately separate | Yes [secondary] | Yes | Via projects [secondary] | Hydra supports token exchange [unverified] |
| **Authelia** | [unverified] | Apache-2.0 [secondary] | Very light, but built as a *gateway* for your own services, not an IdP for strangers | Yes [secondary] | No self-registration by design [secondary] | No | No |
| **Logto** | [unverified] | Open core (MPL) [secondary] | Node + Postgres [secondary] | Yes [secondary] | Yes | Organisations, partly paid [secondary] | [unverified] |
| **SuperTokens** | [unverified] | Open core [secondary] | Core service + your backend SDK | Yes [secondary] | Yes | Paid tier [secondary] | [unverified] |

**Better Auth's provider story has moved.** The plugin the 2026-08-15
decision spiked on — `oidc-provider`, "newer than the rest of Better
Auth and nobody here has run it" — no longer resolves at
`/docs/plugins/oidc-provider` (404 on 2026-09-18). What is documented
now is an **OAuth 2.1 Provider plugin**: authorisation code with
mandatory S256 PKCE, refresh via `offline_access`, **client credentials
(machine-to-machine)**, **device code**, RFC 7591 dynamic client
registration (optionally unauthenticated), RFC 9207 `iss`, ID tokens,
UserInfo, RP-initiated logout, discovery at both
`.well-known/openid-configuration` and
`.well-known/oauth-authorization-server`, signing keys served through
the JWT plugin's `/jwks`, and consent required for all non-trusted
clients [verified]. That the old path 404s while this exists is strong
evidence of a rename or replacement, but the *relationship* between the
two plugins is **[unverified]** and matters, because the internal decision's
recorded reservation attaches to a plugin name that may no longer exist.

Two consequences worth naming without deciding anything: **client
credentials and device code are exactly the two grants a fleet of agents
and a set of CLIs need**, and a separate internal SJL draft decision, "signing in
is not a product's verb", is about CLIs lacking a sign-in path
[verified, local]. And **the key-rotation spike still gates the plane**
[verified, local] — a public user base makes that gate heavier, not
lighter, because revocation with no refresh tokens *is* the expiry.

### 3.2 Hosted

All figures [unverified] except where noted; none was checked against a
live pricing page in this pass, and hosted-IdP pricing changes often.
The structural facts matter more than the numbers:

- **Clerk, Auth0, WorkOS AuthKit, Stytch, Supabase Auth, Firebase /
  Identity Platform** all offer a free MAU band and charge per MAU
  above it. For a city with free accounts and starter grants, **MAU
  pricing and multi-accounting pull in opposite directions**: the
  cheapest user to the platform is the one the abuse model most wants to
  stop.
- Several now market agent-specific authorisation (Auth0 for AI Agents,
  Stytch Connected Apps, WorkOS and Clerk MCP-oriented offerings)
  [unverified]. If any of these is evaluated, the question to ask is
  whether it issues tokens a *self-hosted* resource server can verify
  offline against a JWKS — because that, not the feature list, is what
  the one-issuer rule requires.
- **Data residency** is a live question under RD11 and India's DPDP
  regime; a hosted IdP holding global user records is a processor
  relationship with contract and transfer terms to review.
- The dependency is the point: a hosted IdP outage or account
  termination is a total outage of city identity, with no local
  fallback and no ability to patch.

## 4. Communication and assemblies (RD05)

### 4.1 The four families

| Family | Data ownership | Observe-only public | Moderation tooling | Cost shape | Assemblies |
| --- | --- | --- | --- | --- | --- |
| **Matrix on the existing tuwunel** | Total | `world_readable` history + guest access or a read-only projection | Draupnir/meowlnir + policy lists; admin-room commands | Server cost only | Element Call / LiveKit, or text-only |
| **Purpose-built comment/chat service** | Total | Trivial — it is our schema | Everything is ours to build | Build + run | Ours to build |
| **Forum (Discourse et al.)** | Total if self-hosted | Native: public topics are public | Mature: trust levels, flags, queues | $0 self-host, or from $0/mo hosted | Not live; long-form |
| **Hosted chat API** (Stream, Sendbird, Ably) | Vendor holds messages | Depends on product | Vendor-supplied, often AI-assisted | Per-MAU/per-message | Varies |

### 4.2 Matrix on tuwunel — what is established

tuwunel is Apache-2.0, "the official successor to conduwuit", written in
Rust, and states it is "primarily sponsored by the government of
Switzerland 🇨🇭 where it is currently deployed for citizens" — which is
the strongest maintenance signal available for a conduit-family server
and confirms the sponsorship claim [verified]. Recent releases
[verified]:

| Version | Date | Relevant content |
| --- | --- | --- |
| v1.8.0 | 27 Jun 2026 | MAS provisioning API endpoints, synced provisioned email bindings, SSO redirect-action forwarding (MSC3824); room v12 referenced |
| v1.8.3 | 5 Aug 2026 | **Native OIDC account registration and login**, server usable as its own IdP with no provider configured; device authorisation grant; QR login for Element X; rendezvous sessions with rate limiting and TTL; **sliding sync v5**; MAS provider guide |
| v1.9.0 | 18 Aug 2026 | **Room version 12** with refined create-event handling across federation; MAS scope-default fix (`openid email profile` was rejected by MAS's allowlist); appservice users get OAuth fallback |
| v1.9.1 | 12 Sep 2026 | Native OIDC browser callbacks across origins; `oidc_require_client_approval` (default true) for unvetted dynamic clients; sliding-sync immediacy fixes; MAS secret reload without restart |

**What this does not tell us**, and each is a spike rather than a search:
whether tuwunel implements guest access and `world_readable` peeking to
the degree an observe-only public needs; whether its moderation surface
(admin-room commands rather than Synapse's admin API) is enough for
Draupnir — Draupnir v3.1.0 (7 May 2026) is current and its release notes
reference V12 rooms, but Synapse remains its primarily-tested homeserver
[verified]; whether policy servers (MSC4284) and policy lists work;
media retention and purge; and any scale figure at all — **tuwunel
publishes no concurrency or user-count benchmark this pass could find**
[verified absence on the README; [unverified] elsewhere].

**Synapse as the comparison**: dual-licensed AGPLv3+ or a paid Element
Commercial License, by Element Creations Ltd [verified]. The AGPL
licence is precisely why this suite left it [verified, local], so
"switch to Synapse for the moderation APIs" reopens a settled licence
question and is worth naming as a cost, not smuggling in as a detail.

### 4.3 The shape that fits the city, if Matrix is used

Spaces as districts, rooms per district/project, threads as comments,
`world_readable` history so an observer sees without an account, guest
access off or on separately from history visibility, federation
explicitly on or off, E2EE **off** for public rooms (encrypted rooms
cannot be moderated by a bot that is not in them, cannot be archived for
transparency, and cannot be scanned). Each of those is a decision with a
consequence, and none is made here.

The recurring failure mode to design against is **presentation coupling**:
if the city's comment UI is a Matrix client, then Matrix's availability
is the comment feature's availability, and every Matrix upgrade is a
product release. The alternative — the city owns comment records and
projects them into Matrix — doubles the storage and creates a
reconciliation problem that
[CITY_SYSTEMS](../architecture/CITY_SYSTEMS.md) already describes in
general terms.

### 4.4 The alternatives, briefly

- **Discourse**: 100% free and open source to self-host; hosted plans on
  its own pricing page today are **Free** ($0: 500k monthly pageviews, 2
  staff seats, 5 GB storage), **Pro** ($100/mo: 500k pageviews, 5 staff,
  20 GB), **Business** ($500/mo: 500k pageviews, 15 staff, 100 GB) and
  Enterprise (custom, 1M+ pageviews) [verified]. Its trust-level system
  is the most-copied staged-friction design in the industry and is worth
  studying whatever is chosen (§6.4).
- **Hosted chat APIs** (Stream, Sendbird, Ably Chat, PubNub, TalkJS):
  fastest to working, weakest on ownership. Ably's published pricing is
  in [HOSTING_AND_AGENT_GIT](HOSTING_AND_AGENT_GIT.md) §C. Pricing for
  the chat-specific vendors was **not verified** in this pass. The
  ownership question is not sentimental: RD05 makes conversation core,
  and a core feature on a per-MAU meter is a core feature with someone
  else's hand on the price.
- **Self-hosted comment widgets** (Remark42, Isso, Comentario, Giscus,
  Cusdis): right size for page comments, wrong shape for assemblies and
  for agent participation [unverified in detail].
- **Zulip** has a "web-public streams" feature allowing logged-out
  read-only viewing, which is unusually close to the observe-only
  requirement [secondary, not re-verified].

## 5. Abuse resistance, and the starter-grant problem

RD07/RD08 make credits buy real compute and storage, and free accounts
get starter grants. That converts **multi-accounting from a nuisance
into a direct financial attack**, and it is the single most
consequential interaction between the identity choice and the economy.
The honest framing: no identity mechanism below *prevents*
multi-accounting; each raises the cost per fake account, and the design
question is whether the starter grant is worth less than that cost.

| Control | What it actually stops | What it costs | Note |
| --- | --- | --- | --- |
| Email verification | Typos and the laziest bots | Deliverability work, bounce handling | The hub runs with `requireEmailVerification: false` today [verified, local] |
| Disposable-domain blocklists | Known throwaway providers | Constant list churn; false positives on legitimate niche domains | Public lists exist; effectiveness is a moving target [unverified] |
| CAPTCHA (Turnstile, hCaptcha, Friendly Captcha, self-hosted ALTCHA) | Cheap automation | Accessibility, and a third-party script on a signup page | Solver services price around the problem [unverified] |
| Phone verification | Bulk accounts, substantially | Real per-verification cost, global coverage problems, and it excludes people | Cost per verification varies hugely by country [unverified] |
| Payment-instrument binding | Nearly all of it | Excludes exactly the free tier the city wants | Directly contradicts free accounts |
| **Grant shaping** | Removes the motive instead of the method | Design work | Earn the grant through activity; delay it; make it non-transferable; cap what it can buy in real resources |

The last row is the one that does not depend on any product choice. It
belongs in the economy discussion as much as here.

## 6. Agents, delegation and moderation

### 6.1 Representing agents and private personal agents

SJL's internal decisions already give the city its answer for *Guild* agents: each
is a principal with a stable handle-derived mxid, and the city can
attribute a comment to `prn_…` without inventing anything.
**RD12's private personal agents are the genuinely new case.** Options,
with no choice made:

1. **The owner's principal acts, the agent is an attribute.** Simplest;
   the city sees one actor. Loses the ability to say "an agent did this"
   and so collides with §6.3's labelling duties.
2. **A principal of `kind = agent` owned by a resident**, invisible to
   everyone but the owner unless shared. Matches RD12's wording and the
   existing schema, and is the option that costs the most to build:
   visibility rules, sharing semantics, quota inheritance, what "share"
   grants.
3. **A scoped credential with no identity of its own** (an API key bound
   to the owner). Cheapest; makes revocation easy and attribution
   impossible.

### 6.2 Delegation standards, as they stand today

**The MCP authorization specification is now a substantial OAuth
profile**, and this is the most decision-relevant standards fact in this
document [all verified at the spec draft]:

- MCP servers act as **OAuth 2.1 resource servers**; authorisation is
  OPTIONAL overall but **SHOULD** be followed for HTTP transports, and
  **SHOULD NOT** for stdio, which retrieves credentials from the
  environment.
- MCP servers **MUST** implement **RFC 9728** Protected Resource
  Metadata; clients **MUST** use it for authorisation-server discovery.
- Clients **MUST** implement **RFC 8707** resource indicators, sending
  `resource` in both authorisation and token requests, "regardless of
  whether authorization servers support it".
- Servers **MUST** validate that tokens were issued for them as intended
  audience, **MUST only** accept tokens valid for their own resources,
  and **MUST NOT** accept or transit any other tokens.
- **Dynamic Client Registration (RFC 7591) is deprecated** in this spec
  and retained for backwards compatibility; **Client ID Metadata
  Documents** (`draft-ietf-oauth-client-id-metadata-document-00`) are
  the **SHOULD**.
- RFC 9207 `iss` validation is specified in detail, with a stated
  expectation that a future revision upgrades it from SHOULD to MUST.
- Step-up authorisation via `WWW-Authenticate: Bearer
  error="insufficient_scope", scope="…"` is specified, with the client
  required to request the *union* of previously granted and newly
  challenged scopes.

Read against SJL's internal decisions, three things line up and one does not. Offline
verification, audience-bound tokens and fail-closed are the same design
the suite already chose. Short-lived tokens with re-exchange match
"agents exchange, they do not hold". **What does not line up is scopes**:
the suite's authority model is enumerated grants naming principals,
while MCP assumes scope strings on tokens, and nothing has reconciled
the two.

**RFC 8693 token exchange** is the standard mechanism for the
on-behalf-of case a private personal agent needs (owner delegates to
agent, agent acts, audit shows both). Whether the incumbent issuer
supports it is **[unverified]** and is a concrete thing to check. The
IETF work specifically on agent on-behalf-of, identity chaining and
WIMSE was **not verified in this pass** and should be re-checked rather
than assumed stable — this area is moving monthly.

### 6.3 Agents as participants — four distinct problems

1. **Agent output is content.** It needs the same moderation path as
   human text, and it fails differently: fluent, high-volume, and
   plausible when wrong.
2. **Prompt injection through city text.** Comments, messages and
   assembly transcripts are untrusted input that will reach agents. The
   city's own architecture already states the principle — "imported
   documents, chat text and agent outputs are untrusted content; they
   cannot grant access, spend money or publish themselves"
   [verified, local] — and RD04's opens list "untrusted-input handling"
   explicitly. Public write-ups of agents hijacked through issues, PR
   comments and messages exist and were **not re-verified in this
   pass**; the defensive framings commonly cited (isolating the
   combination of private data, untrusted content and exfiltration
   paths; constraining an agent to at most two of those) are
   [unverified] here and worth citing properly before they are relied
   on.
3. **Impersonation, both directions.** A human posing as a Guild agent,
   or an agent posing as a human. The stable handle-derived mxid is the
   asset here: identity is minted, not chosen.
4. **Labelling.** The **EU AI Act Article 50(2)** transparency
   obligations for AI systems generating synthetic audio, image, video
   or text apply from **2 August 2026**; systems placed on the market
   before that date must comply by **2 December 2026** [verified]. Both
   dates are in the past relative to a city that launches later. India's
   IT Rules have been reported amended in 2026 to require labelling of
   synthetically generated information with a shortened takedown window
   — **this pass could not verify it** (the MeitY page returned 403 and
   the encyclopaedia article documents no post-2021 amendment) and it
   must be verified directly before any launch. California's bot
   disclosure law and companion-chatbot statute, Utah's disclosure
   requirement and China's 2025 labelling measures were **not verified**.

The practical reading: **a city where agents talk to the public will
have a labelling duty in at least one major market, and probably several
with inconsistent wording.** Designing the label in from the start —
visible provenance on every utterance, not a profile badge — is cheaper
than retrofitting it.

### 6.4 Moderation tooling, as it stands

| Tool | Status today | Note |
| --- | --- | --- |
| **OpenAI Moderation endpoint** | `omni-moderation-latest`, text **and** image, images up to 20 MB, **free to use**, 13 categories (harassment, hate, illicit, self-harm, sexual, sexual/minors, violence and sub-categories); some categories are text-only [verified] | The cheapest credible first-pass classifier available; sends user content to a third party, which is a privacy-notice fact |
| **Perspective API** | **Sunsetting.** "Perspective API is sunsetting and service is officially ending after 2026"; service active until **31 December 2026**; new usage/quota requests were accepted only until **February 2026**; **no migration support** [verified] | Do not design on it. This is the clearest "fact that changed" in this document |
| **Llama Guard / ShieldGemma / other open guard models** | Exist; versions, sizes and licences **[unverified]** this pass | Self-hosted classification keeps content local; costs GPU the main server does not have ([MULTIPLAYER](../architecture/MULTIPLAYER.md) records no GPU detected) |
| **Hive, Tremau, Cinder, Checkstep** | Commercial T&S platforms; self-serve availability for a solo operator **[unverified]** | Mostly enterprise-shaped; price discovery requires sales contact |
| **Draupnir** | v3.1.0, 7 May 2026; references V12 rooms; Synapse primarily tested [verified] | Matrix-specific; compatibility with tuwunel's admin-room model is the open question |
| **Mjolnir / meowlnir** | **[unverified]** | Mjolnir is Draupnir's predecessor; meowlnir is a separate implementation |
| **Cloudflare CSAM Scanning Tool** | Compares "content served for your website through the Cloudflare cache to known lists of CSAM"; enabled per zone under **Caching → Configuration**; requires a notification email; sends daily emails naming matched paths and attempts to block; lists sourced from NCMEC and similar; operators report via NCMEC's CyberTipline [verified] | **Critical limitation:** it scans what is served *through the cache*. It is not an upload-time scanner and does not cover private or non-cached paths |

### 6.5 CSAM and legal duties — what is established and what is not

This pass verified less here than elsewhere, and the gaps are the
important part.

- **Verified:** Cloudflare's tool and its cache-scoped limitation
  (above). EU AI Act Art. 50 dates (above).
- **Not verified this pass and required before any public launch:**
  whether US reporting duties under 18 U.S.C. §2258A reach a non-US
  provider and how a small Indian provider registers with the NCMEC
  CyberTipline; PhotoDNA Cloud eligibility and cost; IWF membership fees
  at small scale; India's POCSO §19/§21 reporting duty as it applies to
  an intermediary; the status of the EU's temporary derogation for
  voluntary scanning after April 2026 and of the CSAR proposal; the UK
  Online Safety Act's application to a small non-UK service (Ofcom's own
  in-force announcement sets the illegal-harms risk-assessment deadline
  at **16 March 2025**, with duties from 17 March 2025, and points to
  separate guidance for scope [verified], but **does not state** whether
  small or non-UK services are in scope — that is the question, and it
  is unanswered here); DSA obligations that survive the micro/small
  enterprise exemption; India's IT Rules grievance-officer timelines and
  the 2026 synthetic-content amendment; DPDP Act and Rules commencement
  and parental-consent mechanics; COPPA's 2025 amendments; Australia's
  under-16 restrictions.
- **The load-bearing consequence regardless:** the moment the city
  accepts image uploads, its obligations change category. Text-only is
  materially cheaper to operate, and RD05 does not require images.
  Deferring uploads is an available and reversible choice.

## 7. A staged model: 20, 200, 2,000 registered users

| | 20 users | 200 users | 2,000 users |
| --- | --- | --- | --- |
| Identity | Invite codes; any option works; recovery can be manual (the operator) | Self-service recovery becomes mandatory; email verification; captcha on signup | Abuse review is a standing task; device/IP signals; grant shaping matters financially |
| Conversation | One or two rooms; everything read by the operator | Per-district rooms; unread is normal; search matters | Nobody reads everything; queues and sampling replace reading |
| Moderation | Operator reads everything; no tooling needed | Report queue, automated first-pass classifier, rate limits, new-account friction | Community moderators with scoped powers, appeals, transparency log, an on-call expectation |
| Legal | Terms, privacy notice, contact point | Age gate decided and enforced; retention policy written; data-export path | Named grievance contact; jurisdiction review; transparency reporting |
| Agent participation | Guild agents only; all outputs reviewable | Labelling visible; injection isolation enforced | Private personal agents at scale; per-agent rate limits and quotas |
| The failing point | Nothing | The operator's evenings | The operator entirely |

**The weekly time cost is the number that should drive this, and this
pass did not verify it.** Published surveys of fediverse administrators
and Reddit moderator-time studies exist and are frequently cited for
figures in the several-hours-per-week range per moderator, but **none
was verified in this pass** and none should be quoted until it is. What
*is* established locally is that
[COMMUNITY_CHARTER](../vision/COMMUNITY_CHARTER.md) already records "no
moderator other than the operator; coverage hours unset" [verified,
local]. The city's own charter has already identified the constraint;
what it lacks is a measured number to plan against.

## 8. Open questions for the owner

1. **Does a city account have to be a hub principal?** This is the
   fork. Everything else follows from it.
2. **If not, what is the join** when a city resident is granted real
   compute authority — a mapped identity, a promotion, or a second
   account they manage themselves?
3. **Is the hub's signup closure reversible in principle**, or is
   "the issuer is single-operator" a property worth keeping?
4. **Text-only, or images too, and from when?** The obligations differ
   in kind, not degree.
5. **Age floor: adults only, 16+, or 13+ with parental consent?** Each
   picks a different set of laws and a different verification cost.
6. **Federation on or off** if Matrix is used — it changes who can reach
   the city's rooms and what arrives uninvited.
7. **Who moderates at 200 users**, and what is the budget — time or
   money — for that?
8. **What does a private personal agent (RD12) look like to the rest of
   the city when it acts?** Invisible, attributed to the owner, or
   labelled as an agent with a hidden owner?
9. **What is the starter grant worth in real compute**, and is that less
   than the cost of a fake account?

## 9. The cross-product decision that would need writing

If the city goes ahead, SJL needs an internal cross-product decision it does
not have. Its shape, from the pattern of the existing decisions:

- **Title:** something in the form of the existing ones — e.g. "a
  visitor is not a principal", or "the city is a resource server".
- **It must settle:** whether public human identity is a new kind of
  principal, a mapped external identity, or a separate issuer; whether
  the one-issuer rule means one issuer *per suite* or one issuer *per
  audience*; whether a city identity may ever act on a suite plane, and
  through what mapping.
- **It must record the cost:** an issuer facing the public is a
  different operational object from an issuer facing one operator, and
  key rotation — still ungated and untested [verified, local] — becomes
  the revocation SLA for thousands of people.
- **It must supersede explicitly, or explicitly not:** the "no MAS"
  decision's premise about tuwunel has been overtaken by tuwunel's own
  releases (§2.4). Whether that changes the *decision* or only its
  *reasoning* is the owner's call, but the decisions' own stated failure
  mode — "a claim kept somewhere the thing it describes cannot
  contradict it" — applies here exactly.

## Sources

Accessed 2026-09-18 unless otherwise stated. Local repository paths are
SJL working copies read on 2026-09-18.

**Internal SJL decisions and sibling repositories (local, verified this pass)**
- Internal SJL decision: "One issuer and offline verification"
- Internal SJL decision: "An agent is a principal"
- Internal SJL decision: "Matrix identity without MAS"
- Internal SJL decision: "Ecosystem identity"
- Internal SJL decision: "Tenancy is local and mapped"
- Internal SJL decision: "Signing in is not a product's verb" (draft, not accepted)
- Internal SJL platform strategy
- `agentpod/apps/hub/src/auth/drizzle-auth.ts`, `admin-middleware.ts`
- `agentpod/apps/hub/src/services/principals.ts`
- `agentpod/docs/archive/architecture/redesign-plan.md`
- `superpipeline/apps/api/src/auth/resolve.ts`, `github.ts`

**Identity products**
- Better Auth OAuth 2.1 Provider plugin — https://www.better-auth.com/docs/plugins/oauth-provider [verified]
- Better Auth `oidc-provider` path — https://www.better-auth.com/docs/plugins/oidc-provider (HTTP 404 on 2026-09-18) [verified absence]
- Keycloak releases — https://github.com/keycloak/keycloak/releases [verified]
- Zitadel releases — https://github.com/zitadel/zitadel/releases [verified]
- Kanidm releases — https://github.com/kanidm/kanidm/releases [verified]
- Authentik releases — https://docs.goauthentik.io/releases [verified]
- Forgejo OAuth2 provider — https://forgejo.org/docs/latest/user/oauth2-provider/ [verified]

**Standards**
- MCP Authorization specification (draft) — https://modelcontextprotocol.io/specification/draft/basic/authorization [verified]
- RFC 9728, RFC 8707, RFC 9207, RFC 7591, OAuth 2.1 draft — as cited within the MCP specification above

**Matrix**
- tuwunel repository — https://github.com/matrix-construct/tuwunel [verified]
- tuwunel releases — https://github.com/matrix-construct/tuwunel/releases [verified]
- tuwunel v1.8.0 — https://github.com/matrix-construct/tuwunel/releases/tag/v1.8.0 [verified]
- tuwunel v1.8.3 — https://github.com/matrix-construct/tuwunel/releases/tag/v1.8.3 [verified]
- Synapse — https://github.com/element-hq/synapse [verified, licence]
- Matrix Client-Server API — https://spec.matrix.org/latest/client-server-api/ [verified index; guest-access and history-visibility sections did not render]
- Draupnir releases — https://github.com/the-draupnir-project/Draupnir/releases [verified]

**Conversation alternatives**
- Discourse pricing — https://www.discourse.org/pricing [verified]

**Moderation and duties**
- OpenAI moderation guide — https://developers.openai.com/api/docs/guides/moderation [verified]
- Perspective API — https://perspectiveapi.com/ [verified, sunset notice]
- Cloudflare CSAM Scanning Tool — https://developers.cloudflare.com/cache/reference/csam-scanning/ [verified]
- EU AI Act implementation timeline — https://artificialintelligenceact.eu/implementation-timeline/ [verified, Art. 50 dates]
- Ofcom, UK Online Safety regulation in force — https://www.ofcom.org.uk/online-safety/illegal-and-harmful-content/time-for-tech-firms-to-act-uk-online-safety-regulation-comes-into-force/ [verified, deadlines; scope for small/non-UK services not stated]
- MeitY IT Rules 2021 page — https://www.meity.gov.in/content/information-technology-intermediary-guidelines-and-digital-media-ethics-code-rules-2021 (HTTP 403 on 2026-09-18) [not verified]

**City documents**
- [VISION_DECISIONS](../planning/VISION_DECISIONS.md) · [CITY_SYSTEMS](../architecture/CITY_SYSTEMS.md) · [COMMUNITY_CHARTER](../vision/COMMUNITY_CHARTER.md) · [MULTIPLAYER](../architecture/MULTIPLAYER.md) · [TOOL_AUTOMATION](TOOL_AUTOMATION.md) · [HOSTING_AND_AGENT_GIT](HOSTING_AND_AGENT_GIT.md)
