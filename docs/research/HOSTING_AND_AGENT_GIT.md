# Forgejo, a git system for agents, and global hosting

Desk research · 2026-09-18 · [Plan index](../README.md)

**Evidence limits.** This is desk research for
[RD13](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)
(Forgejo will run on the lab server; agents get a dedicated git system; the
integration shape is a later discussion) and
[RD11](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)
(the product is global), under
[RD15](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18):
**nothing here is chosen, and no sentence should be read as a
recommendation in decision form.** Nothing was installed, deployed,
measured or benchmarked. No server was contacted, no remote session opened,
no account created, no price quoted from a logged-in console. Versions,
prices and release dates are as read on 2026-09-18 and move constantly.
Each claim is marked **[verified]** (this pass fetched the primary
project or vendor page and read the wording), **[secondary]**, or
**[unverified]** (not established in this pass — absence here is not
proof of absence in the world). Capacity language stays at the level
already published in this repository's own
[storage plan](../architecture/STORAGE.md) and
[multiplayer notes](../architecture/MULTIPLAYER.md): a fast and a bulk
storage tier, a multi-core CPU, ample memory headroom at inspection, no GPU
detected. **No operational identifier, address, hostname or
configuration detail of SJL's infrastructure appears in this public
document**, and none should be added to it.

## Part A — Forgejo on a single self-hosted server

### A1. Versions, cadence and support

Read from the project's own release pages [verified]:

| Track | Version | Released | Support ends |
| --- | --- | --- | --- |
| Stable | **v16.0.5** | 17 September 2026 | 29 October 2026 |
| LTS | **v15.0.9** | 17 September 2026 | 15 July 2027 |

"Forgejo stable releases are published on a fixed schedule, every
quarter" [verified]. Standard releases carry roughly three months of
support; LTS releases are annual and carry roughly three years. The
published LTS ladder is 7.0 → July 2025, 11.0 → July 2026, **15.0 → July
2027**, 19.0 → July 2028 [verified].

**The operationally significant number is 29 October 2026.** A stable
release is supported for about six weeks beyond the next one. For a solo
operator, that is an upgrade every quarter on the stable track, or one a
year on LTS with a larger jump each time. LTS is the only track whose
cadence a single person can plausibly ignore for months at a stretch.

Licence, hard-fork status relative to Gitea, and the last Gitea version
supported for migration were **not verified in this pass** and should be
confirmed before anything depends on them.

### A2. Database, resources and scale

Forgejo supports SQLite, PostgreSQL and MySQL/MariaDB [secondary; the
upgrade documentation names all three when describing backups,
[verified]]. Documented minimum resource requirements and any published
Codeberg scale figures were **not verified** in this pass.

What can be said at the level this repository publishes: the host has a
multi-core CPU, an SSD and an HDD tier, ample memory at inspection, and
existing services already running on it. A forge is not a heavy service at
small scale; **its CI runners are**, and that is the whole of §A3.

### A3. Forgejo Actions and the untrusted-code problem

This is the part that matters most, because **agents will author the
code that CI runs**.

The administration documentation states it plainly: **"Forgejo Runner
performs remote code execution. That poses significant security threats
for the host and network that it operates upon."** [verified] Actions has
been enabled by default since v1.21 [verified].

The detailed security guidance page, the fork-pull-request approval
behaviour, whether secrets are exposed to fork PRs, ephemeral/one-job
runner support, and the exact set of execution backends (Docker, Podman,
LXC, host) were **not verified in this pass** — the linked security page
was not retrieved. They are not optional details; they are the
difference between a contained runner and a compromised host.

The isolation ladder, as general engineering facts rather than Forgejo
facts:

| Approach | Isolation boundary | Cost | Note for this machine |
| --- | --- | --- | --- |
| Runner on the host | None meaningful | Zero | Shares a host with other services — the case the docs warn about |
| Docker/rootless Podman | Kernel namespaces | Low | Kernel is shared; a container escape reaches the host |
| gVisor (`runsc`) | User-space kernel | Low-moderate; some syscall incompatibility | Already catalogued as a candidate in [TOOL_AUTOMATION](TOOL_AUTOMATION.md), with the caveat that "isolation is not guaranteed by the mere presence of a runtime" |
| Kata / microVM (Firecracker) | Hardware virtualisation | Higher startup latency and memory | Strongest boundary short of a separate machine |
| Separate physical machine | Physical | A second machine | The only one that survives a full escape |

**The question RD13 leaves open is not "which sandbox" but "does
untrusted CI belong on this host at all".** The
[storage plan](../architecture/STORAGE.md) already records the adjacent
unresolved boundary: the lab server is run as a lab, and product
availability should not depend on it without an explicit decision. A forge
holding the city's source, running agent-authored CI, on a host run as a lab, is that boundary question in its
sharpest form.

Woodpecker CI as a paired alternative was **not researched** in this
pass.

### A4. Registries, LFS and quotas

Package and container registry support, and LFS storage backends
(local, S3-compatible), were **not verified** in this pass.

**Quotas were.** Forgejo has a *soft-quota* feature limiting
`size:repos:all` (git repositories), `size:git:lfs`, `size:assets:all`
(packages and attachments) and `size:assets:artifacts` (Actions
artefacts), settable instance-wide in `app.ini` under `[quota]` /
`[quota.default]` or per user via quota groups and the admin API
[verified]. Two caveats from the documentation itself:

- **"The feature is still in development."** The docs ask for feedback
  via discussion or Matrix [verified].
- **"Forgejo checks the quota usage only before an action is executed,
  but it will allow a started action to complete"** [verified] — so a
  quota is a brake, not a wall. A single large push can overshoot.

For a city where residents and their agents might each get storage, that
second caveat is the one to design around: quotas bound the steady state
and do not bound a single event.

### A5. Backup, restore and upgrades

From the upgrade documentation [all verified]:

- **`forgejo dump` is not the recommended backup.** The zip it creates
  includes a database copy, but that path **"has serious long standing
  open bugs"**, and separate SQL dumps via `psql`/`mysqldump` are
  recommended instead.
- **"The reliable way to perform a backup is with a synchronized
  point-in-time snapshot of all the storage used by Forgejo"** —
  database, repositories, `app.ini`, attachments and LFS together.
- With distributed storage (S3, remote filesystems, Redis), **"the only
  way to ensure a consistent state is to shutdown Forgejo during the
  backup."**
- Run `forgejo manager flush-queues` before upgrading, because "queues
  contain serialized data that is not guaranteed to be backward
  compatible between versions".
- **You may upgrade straight to the latest release** rather than through
  each major in turn; if that fails, step through the latest of each
  series to find the offending transition.
- **Downgrade is not supported and is actively prevented** — the schema
  version is stored in the database specifically to block it.

That last pair is the asymmetry a solo operator should plan for: **the
upgrade is easy and the only way back is the backup.** The storage
plan's existing requirement — a rehearsed restore, not merely available
disks — applies here verbatim.

### A6. Federation, auth and tokens

**Federation (ForgeFed/ActivityPub)**: the current documentation page
was **not retrieved** (404 at the path tried). Status **[unverified]**.
Nothing should be planned on federated issues or pull requests.

**Forgejo as an OAuth2/OIDC provider** [verified]: authorisation code
grant, PKCE (`code_verifier` 43–128 characters), OIDC discovery at
`/.well-known/openid-configuration`, authorisation at
`/login/oauth/authorize`, token at `/login/oauth/access_token`, JWKS at
`/login/oauth/keys`, UserInfo at `/login/oauth/userinfo`. **And the
blocking caveat, in the docs' own words: "OAuth2 scopes are not yet
implemented"**, so tokens "can be used to execute any actions on behalf
of the user" and third-party applications "will have administrative
rights" [verified]. For the city that means: usable as a login source,
**not** usable to delegate narrow authority to an agent or a service.

**Access token scopes** [verified] — these exist and are usable, and are
a different mechanism from OAuth scopes above:

`activitypub`, `admin`, `issue`, `misc`, `notification`, `organization`,
`package`, `repository`, `user` — each with `read:` and `write:`
variants.

**Repository-scoped tokens exist** [verified]. A token's repository
access is one of: all (public, private and limited), public only, or
**specific repositories** — but a token limited to specific repositories
**"is limited to `read:repository`, `write:repository`, `read:issue` and
`write:issue`"** only. That is a real and useful constraint for an agent
that should touch one repository, with a real limitation: an agent so
scoped cannot manage packages, organisations or notifications.

Token expiry was **not addressed** in the documentation read. OIDC login
sources, auto-registration, group-to-team mapping, WebAuthn/passkeys, a
bot user type, the admin API for creating users and tokens, and the
`Sudo` header were **not verified** in this pass.

### A7. Branch protection, signing, mirrors, webhooks, abuse

The following were **not verified in this pass** and are listed so the
gaps are explicit rather than assumed:

- Branch protection option list (the page read stated only that
  protected branches "enforce restrictions such as force pushing or
  merging unless a given number of approvals are obtained on a pull
  request" [verified] and did not enumerate options). CODEOWNERS
  support: **[unverified]**.
- Commit signature verification: GPG and SSH signing support in the
  forge UI, instance signing keys, and whether Sigstore/gitsign x509
  identities are recognised: **[unverified]** (gitsign's keyless,
  short-lived certificates typically display as unverified in forge UIs
  that expect long-lived keys, but this was not confirmed for Forgejo).
- Pull and push mirrors to and from GitHub, sync intervals, and what is
  *not* mirrored (issues and pull requests are generally not carried by
  git mirroring): **[unverified]**.
- Webhook event coverage, Actions API endpoints for runs/jobs/logs and
  workflow dispatch, audit log existence, Prometheus metrics:
  **[unverified]**. [TOOL_AUTOMATION](TOOL_AUTOMATION.md) already
  records Forgejo Actions as "partial until tested" and treats runner
  administration, workflow dispatch and log retrieval as separate
  operations — that assessment stands unchanged.
- Registration abuse controls (email allow/blocklists, captcha types,
  manual approval, `MAX_CREATION_LIMIT`) and any built-in API rate
  limiting: **[unverified]**.

**One abuse fact did surface, from an unexpected direction.** Attempting
to read the forgejo-mcp project on its new self-hosted Forgejo home
returned an **Access Denied page generated by Anubis v1.26.2** — the
proof-of-work challenge that forge operators adopted during 2025 against
AI crawler load [verified by observation]. Two things follow for the
city, and they are in tension: a self-hosted forge exposed to the open
internet **will** attract crawler load heavy enough that operators
deploy proof-of-work in front of it; and **the same defence blocks
legitimate agents**, including ours, from reading other people's forges.
Any plan in which agents fetch from arbitrary forges has to survive
this.

### A8. The comparisons, briefly and as facts

- **Gitea**: latest version, MIT licence, CommitGo's open-core
  enterprise features and Actions status were **not verified** in this
  pass. [TOOL_AUTOMATION](TOOL_AUTOMATION.md) already treats the two as
  a live comparison.
- **GitHub only**: the existing SJL repositories live there;
  [CITY_SYSTEMS](../architecture/CITY_SYSTEMS.md) already states that
  "existing repositories can retain their authoritative home". GitHub's
  terms on machine accounts, Actions minutes on the free plan, GitHub
  Apps as agent identities, and the hosted agent-PR products were **not
  verified** in this pass. The structural trade is unchanged and does
  not need verification: GitHub costs no operations and grants no
  control; a self-hosted forge grants total control and costs all of the
  operations.
- **RD13 has settled that Forgejo will be present.** It has not settled
  that GitHub goes away, and
  [FORGEJO_SUPERPIPELINE](../integrations/development/FORGEJO_SUPERPIPELINE.md)
  already records that Superpipeline's reference parsing is GitHub-only
  and AgentPod has a `forgejo` enum value with no implementation behind
  it [verified, local]. Keeping GitHub as the public face and Forgejo as
  the working forge is a *pattern*, not a decision, and it is the one
  the existing integrations currently favour by default.

## Part B — A git system for agents

### B1. Account model options

| Model | Maps to SJL's principal model? | Attribution | Blast radius | Note |
| --- | --- | --- | --- | --- |
| **One Forgejo user per agent principal** | Directly — an internal SJL decision already says an agent is a principal with an immutable handle | Clean: commits, PRs and reviews carry the agent's name | One compromised agent = one account | Costs a user row and a credential per agent; 14 Guild agents today |
| **One shared bot account** | Poorly — collapses many principals into one | Lost: every agent is "the bot" | One credential compromises everything | The long-standing pattern (Renovate-style) and the wrong shape for a city that projects agent work publicly |
| **Scoped tokens against a human's account** | No — actions appear as the human | Misleading in exactly the way that matters | Full account authority unless repository-scoped | Repository-scoped tokens (§A6) narrow it but still say "the human did this" |
| **Deploy keys per repository** | N/A | None (key, not identity) | Per repository | Right for a delivery step, wrong for authoring |

**SJL's internal principal decision resolves this more than Forgejo does.** "An
agent is exactly one principal", minted from an immutable handle, with
no wildcard grants [verified, local]. A design that merges agents into a
shared forge account contradicts a written decision; a design that gives
each agent its own forge user is the direct translation of one. What
Forgejo can express — a user, scoped tokens, repository-limited tokens —
is compatible with that. Whether Forgejo has a first-class bot/service
account type is **[unverified]**.

The open question RD13 names explicitly, and which this pass cannot
answer, is **what links a Forgejo user to a `prn_…` principal**. The
mechanism already exists in the suite: `principal_identities` with
`system` and `external_id`, and an internal SJL decision requires those links to be
explicit rather than inferred [verified, local]. "Same username" must
not be the join, for the same reason
[CITY_SYSTEMS](../architecture/CITY_SYSTEMS.md) already states that
"changing a GitHub name must not transfer a home".

### B2. Review, protection and quotas for agent-authored code

The controls that exist in principle: required approvals before merge,
protected branches, CODEOWNERS routing, required status checks, signed
commits, and quotas (§A4). Their exact availability in Forgejo today is
**[unverified]** per §A7 and is a concrete verification list rather than
a design question.

The design question that is *not* about Forgejo: **which agent actions
require a human, and does that scale?** RD01's first slice is watching
agents work. If every agent commit needs human review, the city's
throughput is the founder's reading speed. If none does, agent-authored
code reaches production unreviewed on a host that also holds the city's
accounts and ledger. The middle — review required on some paths,
protected file patterns, agents merging their own work only in
designated repositories — is where the real policy lives, and it is
unwritten.

### B3. Commit signing and attribution for non-humans

- **SSH signing** (`gpg.format=ssh` with an `allowed_signers` file) is
  the least-friction way to give an agent a verifiable signature,
  because the agent already needs an SSH key [secondary; not re-verified
  this pass, and Forgejo's display of SSH signatures is
  **[unverified]**].
- **Sigstore/gitsign** offers keyless signing bound to an OIDC identity
  with short-lived certificates — conceptually a very good fit for
  principals that exchange rather than hold. It needs Fulcio and Rekor,
  and forge UIs that expect long-lived keys typically show such commits
  as unverified. Both points are **[unverified]** for Forgejo.
- **Attribution trailers** (`Co-authored-by:`, and the
  assisted/generated conventions several open-source projects adopted
  during 2025–2026 for AI contributions) are the cheap, portable half of
  this. Specific project policies were **not verified** in this pass and
  should not be cited until they are. The city's own need is narrower
  and clearer: **a public projection that says "an agent wrote this" has
  to be able to prove it**, and a trailer anyone can type is not proof
  while a signature is.

### B4. Agent-operable interfaces

[TOOL_AUTOMATION](TOOL_AUTOMATION.md) recorded Forgejo as "both found;
upstream verification pending", with the maintainer reporting a move to
another forge that the research browser could not fetch. **That move is
now confirmed at source, and the destination is now partly readable.**

From the GitHub repository's README [verified]: it is marked **"MIRROR
ONLY!!"**, and **"Development, issues, releases, and container images
now live at https://git.b4mad.industries/agentic-forges/forgejo-mcp"**;
the Codeberg copy "remains only as a read-only mirror". The project is
**GPL-3.0**; it exposes **100+ tools** across users, repositories,
branches, webhooks, files, commits, issues, comments, pull requests,
packages, Actions, organisations, teams, time tracking, attachments,
releases and wiki; transports are **stdio, SSE and HTTP** (streamable
and multi-tenant); and authentication supports **Forgejo personal access
tokens, OAuth bearer tokens, an OAuth 2.0 resource-server mode with JWT
validation for Forgejo 16+, and per-request authorisation headers in
multi-tenant HTTP mode** [verified]. `v3.1.0` appears in examples and
`v3.0.0` is named as the module-path change [verified]; the current
release tag was **not confirmed**.

Two observations without a recommendation. First, **the OAuth 2.0
resource-server mode with JWT validation is the shape SJL's internal
one-issuer rule wants** — a resource server verifying a token rather
than holding a PAT — and "Forgejo 16+" matches the current stable line
(§A1). Second, **the canonical repository is behind Anubis** (§A7), so
the authoritative source of this dependency is not readable by an agent
or by an automated supply-chain check without solving a proof-of-work
challenge. For a dependency that would hold write credentials to the
city's forge, [TOOL_AUTOMATION](TOOL_AUTOMATION.md)'s existing rule —
"validate and pin each selected server's source/release; inspect
permissions, dependency licences and supply chain" — is harder to
satisfy here than usual, and that is a fact about this candidate.

Other interfaces: `fj` (community CLI), `tea` (Gitea CLI) and `berg`
were **not re-verified** in this pass beyond what
[TOOL_AUTOMATION](TOOL_AUTOMATION.md) already records; Gitea's official
`gitea-mcp` and other Forgejo MCP servers were **not verified**.

**AGit flow is verified and is more relevant to agents than it first
appears** [all verified]. An author pushes to
`refs/for/<branch>/<topic>` (or `refs/draft/…`, `refs/for-review/…`),
optionally with `-o topic=…`, and "this workflow provides a way of
submitting changes to repositories hosted on Forgejo instances using the
`git push` command alone, **without having to create forks or feature
branches**". Forgejo "relies on the `topic` parameter and a linear
commit history in order to associate new commits with an existing open
pull request". Limitations: multi-line descriptions need base64
encoding, Gerrit `Change-Id`s are unsupported, rebasing or amending
requires `force-push=true`, and a topic cannot be reused once its pull
request is merged or closed.

Why that matters for RD13: **an agent with push-to-`refs/for` rights and
nothing else can propose changes without holding fork-creation or
branch-creation authority**, which is a narrower grant than the usual
bot pattern and composes well with repository-scoped tokens (§A6). It is
an option worth measuring, not a design.

Published accounts of teams running coding agents against self-hosted
forges, and Codeberg's or Forgejo's own policies on AI-generated
contributions, were **not verified** in this pass and are a real gap —
they are where the permission patterns would come from empirically
rather than by reasoning.

### B5. What a public "watch the agents work" projection can safely draw

RD01 makes this the first slice, and RD12 makes private personal agents
invisible by default, so the boundary has to be explicit.

| Signal | Safe in public? | Why |
| --- | --- | --- |
| "Agent X is working" / idle | Yes | No repository content |
| Repository **name** | Only for public repositories | A private repository's name is often the whole secret |
| Commit message | Only for public repositories | Frequently contains the substance |
| Diff / file contents | Only for public repositories | Obvious |
| PR open/merged **counts** | Yes, aggregated | Aggregates still leak timing; acceptable coarsely |
| CI pass/fail | Public repositories only | Failure text leaks paths and secrets in logs |
| Activity heatmap | **Check first** | Contribution heatmaps in forge software have historically counted private activity; whether Forgejo's does, and whether a `KEEP_ACTIVITY_PRIVATE`-style setting exists, is **[unverified]** |
| Status badges | **Check first** | Badge endpoints for private repositories are a classic leak; **[unverified]** for Forgejo |

**The safe default that needs no verification**: the city does not read
the forge for its public projection. The forge emits a webhook; a city
service decides, against a declared per-repository audience, what
becomes a public event; the public surface reads only the city's own
records. That is exactly the "approved event projections" and "declared
audience" shape [CITY_SYSTEMS](../architecture/CITY_SYSTEMS.md) already
specifies, and it converts an unbounded leakage question into one
reviewable mapping. It also means the projection keeps working when the
forge is down, showing honest stale state — the behaviour the failure
table in that document already requires.

## Part C — Serving a global product from one machine

### C1. The uplink question

Indian ISP facts — CGNAT prevalence on major consumer fibre providers,
static IP availability and price, typical upstream bandwidth, terms of
service on running servers, IPv6 availability — were **not verified in
this pass** and are the most basic unknown in this section. They are
also the cheapest to establish, since they are facts about one specific
connection rather than about the market.

The design consequence is independent of the numbers, though: **a
residential or office uplink is asymmetric, shared with the household or
office, and has no availability commitment.** Anything that saturates
upstream — a popular asset download, a large clone, a crawler wave —
degrades everything else on the line, including the operator's own
ability to fix it.

### C2. Tunnels and fronting, with their actual terms

| Option | Verified facts | Consequence |
| --- | --- | --- |
| **Cloudflare Tunnel** | Connects "HTTP web servers, SSH servers, remote desktops, and other protocols"; the page carries **no pricing and no stated limits** [verified absence]. The CDN service-specific terms state: **"Cloudflare offers specific Paid Services (e.g., the Developer Platform, Images, and Stream) that you must use in order to serve video and other large files via the CDN"**, and Cloudflare "reserves the right to disable or limit your access to or use of the CDN … if you use or are suspected of using the CDN without such Paid Services to serve video or a disproportionate percentage of pictures, audio files, or other large files" [verified] | Fine for HTML, API and WebSocket traffic. **A 3D world's assets are "large files" and a git/LFS/registry endpoint is large-file traffic** — this clause is the one that matters most to this project and it is not a grey area. Whether SSH-based git through a tunnel requires client-side software, and per-plan upload size limits, were **not verified** |
| **Tailscale Funnel** | "Funnel can only listen on ports `443`, `8443`, and `10000`"; "Traffic sent over a Funnel is subject to non-configurable bandwidth limits"; only tailnet `*.ts.net` DNS names — **no custom domains**; "available for all plans"; TLS terminated on the device [verified] | Excellent for private or demo access. **The no-custom-domain fact alone disqualifies it as the public face of a product** |
| **Small VPS + WireGuard + reverse proxy** | — | Full control, your own domain and TLS, no third-party content terms. Costs a VPS, an extra hop of latency, and the operator's own DDoS exposure |
| **frp / rathole / Pangolin / ngrok / zrok** | **[unverified]** | Self-hosted tunnel software occupying the same slot as the VPS pattern with less assembly |

### C3. Latency from India to the world

This is the fact that global ambition (RD11) collides with hosting
location. From Microsoft's published Azure round-trip statistics —
**P50 medians, data dated 30 July 2026 on a page last updated 20 August
2026, refreshed every 6–9 months** [verified]:

| From Central India to | P50 RTT (ms) |
| --- | --- |
| South India | 20 |
| UAE North | 32 |
| Qatar Central | 43 |
| Southeast Asia (Singapore) | 53 |
| Malaysia West | 59 |
| Indonesia Central | 67 |
| East Asia (Hong Kong) | 87 |
| Korea South | 114 |
| Switzerland West | 115 |
| France South | 118 |
| Japan East | 122 |
| South Africa North | 131 |
| Italy North | 134 |
| Spain Central / France Central / Germany North | 135 |
| West Europe | 139 |
| **UK South** | **141** |
| Australia East | 145 |
| North Europe | 146 |
| Israel Central | 150 |
| **East US** | **201** |
| Canada Central | 201 |
| East US 2 | 204 |
| **West US 2** | **211** |
| West US | 217 |
| Central US | 220 |
| South Central US | 234 |
| Mexico Central | 253 |
| **Brazil South** | **303** |

These are **datacentre-to-datacentre medians**. A residential last mile
adds to both ends, and TLS and application time sit on top. The widely
cited interactive-response thresholds (roughly 100 ms for "instant",
with several hundred milliseconds being noticeably laggy) were **not
verified from a primary source** in this pass.

**The reading, without a decision:** India-hosted services are good for
India, the Gulf and South-East Asia; acceptable for Europe; and
structurally poor for the Americas, where a US visitor pays 200–300 ms
before anything else happens. A city whose shared world is authoritative
in India will feel different in São Paulo than in Pune, and no amount of
client optimisation removes 300 ms of physics. The available responses
are architectural — optimistic local presentation, regional edge for
static and read-only content, tolerance for latency in the interaction
design — and each belongs to the engine and multiplayer discussion, not
to this one.

### C4. Fanning out live state to thousands of observers

RD01 implies many observers watching agent work state. The mechanisms
and their verified economics:

**Cloudflare Durable Objects** [verified]:

- Free plan: 100,000 requests/day, 13,000 GB-s/day, SQLite backend only
  (key-value requires paid); 5 million SQLite row reads/day, 100,000
  writes/day.
- Paid: 1 million requests/month included, then **$0.15/million**;
  400,000 GB-s/month included, then **$12.50/million GB-s**.
- **WebSocket incoming messages bill at 20:1** — "100 WebSocket incoming
  messages would be charged as 5 requests".
- SQLite storage: $0.20/GB-month after 5 GB-month; reads $0.001/million
  rows after 25 billion; writes $1.00/million rows after 50 million.
- **"An individual Object has a soft limit of 1,000 requests per
  second"**, and each object is single-threaded; scaling is horizontal
  across many objects, and an overloaded object returns an error to the
  caller. The maximum number of hibernatable WebSockets per object was
  **not stated** on the limits page read [verified absence].

**Ably** [verified]: free tier 6M messages/month, 200 concurrent
connections, 200 channels, 500 messages/second. Pay-as-you-go
$2.50/million messages, $1.00/million connection-minutes, $1.00/million
channel-minutes, $0.25/GiB transfer. Standard $29/month (10k
connections, 2.5k msg/s); Pro $399/month (50k connections, 10k msg/s).

**The arithmetic that decides the shape.** Connection-minutes are the
quiet cost: 1,000 observers connected for an hour is 60,000
connection-minutes — trivial. But a *broadcast* multiplies: one state
change fanned to 1,000 observers is 1,000 messages. At one update per
second per watched agent, fourteen agents and a thousand observers is
14,000 messages/second, which exceeds every tier above without
aggregation. **The design lever is not the vendor; it is the update
rate and the fan-out topology** — batching, diffing, per-district
channels, and accepting that "live" can mean every few seconds.

Centrifugo's published single-node benchmarks, NATS WebSocket and leaf
nodes, Mercure, Soketi, Pusher, Supabase Realtime and Momento were
**not verified** in this pass. The SSE-versus-WebSocket trade (SSE is
simpler, one-directional, reconnects with `Last-Event-ID`, and suffers
the HTTP/1.1 six-connection limit without HTTP/2) is **[unverified]**
here as a set of citable facts, though it is well-established
engineering.

**One local note.** [MULTIPLAYER](../architecture/MULTIPLAYER.md)
already lists Cloudflare Durable Objects as an alternative room
coordination substrate, with the caution to use one object per room and
"no global city object". The 1,000 requests/second soft limit per object
is the quantitative form of that same caution [verified].

### C5. Static assets and the CDN question

- **Cloudflare R2** [verified]: $0.015/GB-month storage, Class A
  $4.50/million, Class B $0.36/million, free tier 10 GB-month, 1M Class
  A and 10M Class B operations per month, **egress free**.
- **Backblaze B2** [verified]: $6.95/TB/month; first 10 GB free; free
  egress up to 3× average monthly storage, then $0.01/GB; free Class A/B
  API calls; no minimum file size or storage duration fee.

Both are cheaper and more appropriate for world assets than serving them
from a home uplink, and both sidestep the CDN terms quoted in §C2
because object storage with its own egress terms is not the same product
as the CDN. Bunny, CloudFront and the per-file limits of static-hosting
platforms were **not verified**.

### C6. VPS and managed database pricing

Only two data points were verified in this pass, and the section is
explicitly incomplete:

- **DigitalOcean Managed PostgreSQL** [verified]: cheapest Standard plan
  **$15.15/month** ($0.02254/hour), 1 GiB RAM, 1 vCPU; storage 10–30 GiB
  at $0.215/GiB/month in 10 GiB increments. **Region availability,
  including Bangalore, was not stated** on the page read.
- **Hetzner Cloud** locations: Germany (Falkenstein, Nuremberg), Finland
  (Helsinki), USA (Hillsboro OR, Ashburn VA) and **Singapore**; **no
  India region** [verified]. Specific plan prices and per-region traffic
  allowances were not shown on the page read [verified absence].

Vultr's pricing page returned HTTP 403 and Akamai/Linode redirected;
AWS Lightsail, OVHcloud, Oracle's always-free tier and Indian providers
were **not checked**. Managed Postgres pricing beyond DigitalOcean —
Neon, Supabase, Crunchy Bridge, Aiven, Fly.io, Railway, Render — was
**not verified**. RBI payment-data localisation, which may bear on where
payment-adjacent records live, was **not verified** and is a question
for the payments work rather than this document.

**The one structural fact that needs no price**: a managed database in a
cloud region and an authoritative simulation on a home server are on
opposite ends of a link whose latency and reliability are exactly what
§C1 leaves unknown. Splitting state across that link is a much bigger
decision than its price suggests.

### C7. DDoS, crawlers and uptime

- **Origin exposure**: if the origin address of a home connection
  becomes known, an attack bypasses any proxy and lands on the domestic
  line. There is no mitigation at that point that the operator controls.
  A tunnel that never exposes an origin address is structurally better
  here than a DNS proxy that can be bypassed.
- **Crawler load is not hypothetical.** §A7's Anubis observation is
  direct evidence that forge operators consider proof-of-work necessary
  in front of public git hosting [verified by observation]. The 2025
  reports from other open-source hosts were **not verified** in this
  pass.
- **Uptime arithmetic**, which needs no source: 99% is about 3 days 15
  hours of downtime a year; 99.5% about 1 day 20 hours; 99.9% about 8
  hours 45 minutes. A solo operator who sleeps, travels and has a power
  grid cannot commit to 99.9% on one machine, and **RD07–RD09 sell paid
  residency and paid services**, which turns an uptime expectation into
  a commercial promise. The [storage plan](../architecture/STORAGE.md)
  already requires recovery objectives to be defined and tested before
  paid storage is offered; the same logic applies to availability.
- **Status pages**: self-hosted (Uptime Kuma, Gatus, OpenStatus) and
  hosted free tiers (Instatus, Better Stack, Statuspage, UptimeRobot)
  were **not verified** for current terms. The one rule that needs no
  verification: **the status page must not be hosted on the machine
  whose status it reports.**

### C8. Off-site backups

3-2-1 (three copies, two media, one off-site) applied here means an HDD
tier on the same host is **not** a second copy in the sense that matters —
the [storage plan](../architecture/STORAGE.md) already says so:
"Mirroring and snapshots do not replace an independent backup and a
rehearsed restore" [verified, local].

Verified prices for an off-site copy are §C5's: R2 at $0.015/GB-month
with free egress, B2 at $6.95/TB/month with 3× free egress. Wasabi's
minimum storage duration, Hetzner Storage Box, rsync.net, Glacier Deep
Archive, iDrive e2 and Storj were **not verified**, nor was object-lock
/ immutability availability — which is the feature that matters most
against ransomware and against an agent with too much authority.

### C9. The split pattern, and the boundary it touches

The common shape is: public edge in a cloud region (static assets, TLS
termination, WebSocket fan-out, status page, off-site backups), heavy
and stateful work at home (the forge, CI, asset processing, bulk
storage), joined by a tunnel or a private network. Published write-ups
of specific implementations were **not verified** in this pass.

Reported failure modes, as engineering expectations rather than cited
facts: uplink saturation from one popular asset; power interruption and
the UPS runtime that determines whether a database survives it; dynamic
address changes; ISP maintenance windows with no notice; and the single
disk controller that mirroring does not protect against.

**This lands directly on the boundary
[STORAGE](../architecture/STORAGE.md) leaves open**: the lab server is
run as a lab, and product availability should not depend on it without an
explicit decision, and durable city accounts, wallets
and paid services would cross that boundary [verified, local]. The split
pattern is interesting precisely because it offers a third answer to
that question — not "promote the lab to production" and not "buy
production hosting for everything", but "the lab stays a lab and
nothing whose loss matters lives only there". **That is a decision for
the owner and SJL's infrastructure operators, and this document does not
make it.**

## Part D — Evidence still needed

### D1. Measurements to run later, with the operators' permission

1. **Forgejo footprint on this host** under a realistic repository and
   CI load, alongside the services already running there, including
   sustained I/O contention against the city's transaction path — the
   test [STORAGE](../architecture/STORAGE.md) already specifies.
2. **A runner escape exercise**: agent-authored code in the chosen
   isolation mode, attempting to reach the host, other containers and
   the network. Isolation claimed is not isolation observed.
3. **Backup and restore, end to end**: SQL dump plus repositories plus
   LFS plus `app.ini`, restored into an isolated environment, with
   `flush-queues` first, verified by cloning and pushing afterwards.
4. **An upgrade rehearsal**, including the case where it fails and the
   only path is the backup (§A5).
5. **Uplink characterisation**: sustained upstream throughput, address
   stability over weeks, CGNAT status, and behaviour under a large
   concurrent asset download.
6. **Real-world latency** from a handful of regions to whatever the
   public entry point turns out to be, compared against §C3's
   datacentre medians.
7. **Fan-out cost at a realistic update rate**, measured rather than
   estimated, before a substrate is chosen.
8. **Leakage audit** of every forge surface that could expose a private
   repository (§B5), by creating a private repository and inspecting
   what a logged-out visitor can see.

### D2. Open questions for the owner

1. **Does untrusted, agent-authored CI run on the same host as the city's
   accounts and ledger?** This is the RD13 question that everything else
   in Part A depends on.
2. **One forge account per agent principal, or something narrower?** SJL's
   internal principal decision points one way; the operational cost points another.
3. **Which agent actions require a human before they take effect**, and
   what happens to throughput when they do?
4. **Does GitHub remain the public face** while Forgejo is the working
   forge, or does the city move?
5. **Stable track or LTS track**, given a quarterly cadence and a
   six-week overlap (§A1)?
6. **Is the public entry point ever the home machine directly**, or
   always something else?
7. **What availability is promised to paying residents**, and what
   happens when it is missed?
8. **Where does the off-site backup live**, who can delete it, and has a
   restore been rehearsed?
9. **Does the lab/production boundary get resolved, deferred, or
   sidestepped** by a split where nothing irreplaceable lives only on
   the lab?

## Sources

Accessed 2026-09-18 unless otherwise stated. Local repository paths are
SJL working copies read on 2026-09-18.

**Forgejo**
- Releases — https://forgejo.org/releases/ [verified]
- Release schedule — https://forgejo.org/docs/latest/admin/release-schedule/ [verified]
- Actions (admin) — https://forgejo.org/docs/latest/admin/actions/ [verified]
- Quota — https://forgejo.org/docs/latest/admin/quota/ [verified]
- Upgrade and backup — https://forgejo.org/docs/latest/admin/upgrade/ [verified]
- Access token scopes — https://forgejo.org/docs/latest/user/token-scope/ [verified]
- OAuth2 provider — https://forgejo.org/docs/latest/user/oauth2-provider/ [verified]
- AGit support — https://forgejo.org/docs/latest/user/agit-support/ [verified]
- Branch protection — https://forgejo.org/docs/latest/user/protection/ [verified, but the option list did not render]
- Federation — https://forgejo.org/docs/latest/user/federation/ (HTTP 404 on 2026-09-18) [not verified]
- User guide and project boards — https://forgejo.org/docs/latest/user/ · https://forgejo.org/docs/latest/user/collaboration/project/ [previously cited in [FORGEJO_SUPERPIPELINE](../integrations/development/FORGEJO_SUPERPIPELINE.md)]

**Agent interfaces**
- forgejo-mcp (mirror, with the move notice) — https://github.com/goern/forgejo-mcp [verified]
- forgejo-mcp (canonical) — https://git.b4mad.industries/agentic-forges/forgejo-mcp — returned an Anubis v1.26.2 Access Denied challenge on 2026-09-18 [verified by observation; contents not read]

**Hosting, networking and pricing**
- Cloudflare Tunnel — https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/ [verified]
- Cloudflare service-specific terms (Application Services, CDN section) — https://www.cloudflare.com/service-specific-terms-application-services/ [verified]
- Tailscale Funnel — https://tailscale.com/kb/1223/funnel [verified]
- Azure network round-trip latency statistics (P50; data dated 30 July 2026) — https://learn.microsoft.com/en-us/azure/networking/azure-network-latency [verified]
- Durable Objects pricing — https://developers.cloudflare.com/durable-objects/platform/pricing/ [verified]
- Durable Objects limits — https://developers.cloudflare.com/durable-objects/platform/limits/ [verified]
- Ably pricing — https://ably.com/pricing [verified]
- Cloudflare R2 pricing — https://developers.cloudflare.com/r2/pricing/ [verified]
- Backblaze B2 pricing — https://www.backblaze.com/cloud-storage/pricing [verified]
- DigitalOcean managed databases — https://www.digitalocean.com/pricing/managed-databases [verified]
- Hetzner Cloud — https://www.hetzner.com/cloud/ [verified for locations only]
- Vultr pricing — https://www.vultr.com/pricing/ (HTTP 403 on 2026-09-18) [not verified]
- Linode/Akamai pricing — https://www.linode.com/pricing/ (redirects to https://www.akamai.com/cloud/pricing) [not verified]

**City and sibling documents**
- [VISION_DECISIONS](../planning/VISION_DECISIONS.md) · [STORAGE](../architecture/STORAGE.md) · [MULTIPLAYER](../architecture/MULTIPLAYER.md) · [CITY_SYSTEMS](../architecture/CITY_SYSTEMS.md) · [TOOL_AUTOMATION](TOOL_AUTOMATION.md) · [FORGEJO_SUPERPIPELINE](../integrations/development/FORGEJO_SUPERPIPELINE.md) · [IDENTITY_AND_MODERATION](IDENTITY_AND_MODERATION.md)
- Internal SJL decisions "An agent is a principal" and "Ecosystem identity" (read locally)
