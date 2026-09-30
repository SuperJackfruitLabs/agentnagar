# Forgejo, Superpipeline and the city's project workshops

Integration proposal · 2026-09-16 · decision applied 2026-09-18 ·
[Tools](../../architecture/TOOLS.md)

## What RD13 decided, and what it left open

On 2026-09-18 Rakesh decided that **Forgejo will run on the lab server, and agents
get a dedicated git system as part of the stack**
([RD13](../../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18)).
How it integrates is a later discussion (RD13, RD14).

| Settled by RD13 | Still open |
| --- | --- |
| Forgejo is part of the stack | Who owns task records: the three allocations below remain a proposal (TD03) |
| It runs on the lab server | Storage tier, quotas and capacity reservations on that host |
| Agents get a dedicated git system | Agent accounts, permissions and how they map to each agent's principal |
| | Isolation between the forge, CI runners, city services and the host |
| | Backup, off-host copy and a rehearsed restore |
| | The [lab/production boundary](../../architecture/STORAGE.md#hosting-role): the lab server is run as a lab, not as production |
| | Every integration: references, webhooks, delivery, mirroring, CI and recognition |

**Verified 2026-09-18 against the sibling repositories** (`origin/main` plus
the checked-out branch):

- Superpipeline's reference parsing is GitHub-only. `recognizeReference` in
  `apps/api/src/references/github-url.ts` returns the generic `url` provider
  for any host other than `github.com`; the neighbouring files handle GitHub
  webhook events and signatures only. A Forgejo pull request can be attached
  as a link, but it gets no provider, source type or durable external ID, and
  no webhook path updates it.
- AgentPod knows `forgejo` as an enum value. `DeliveryAdapter` in
  `packages/contract/src/run.ts` lists `git-remote`, `github`, `gitlab`,
  `forgejo` and `patch`. A search of the hub, node agent and packages found an
  unused `ForgejoApiError` class and leftover test and configuration values,
  and no Forgejo delivery implementation.

So Forgejo's presence is decided and its integrations are unbuilt. The flows
in this brief describe a target, not something either product does today.

Superpipeline is the current name of the product previously called Kaambaan.
The [September 16 source refresh](../../research/SJL_PRODUCT_REFRESH_2026-09-16.md)
records the merged rename and interface changes. The allocation below remains
a proposal; a new name does not approve a Forgejo migration.

Rakesh proposed Forgejo for Git and project management, then identified its
overlap with Superpipeline's purpose-built agentic task/project management. The
overlap is real: both can occupy project planning, task assignment and progress
tracking. They should not become two independent authoritative boards for the
same work. The allocation below is a recommendation to discuss, not an accepted
migration or a deployed integration. RD13 has since settled that Forgejo will
be present; it does not settle which product owns tasks.

## Three possible allocations

| Model | Task authority | Forgejo role | Superpipeline role | Trade-off |
| --- | --- | --- | --- | --- |
| Forgejo leads | Forgejo issues/projects | Code plus everyday project management | Optional agent-run coordination against referenced issues | Smaller conventional workflow; narrows Superpipeline's product role |
| Superpipeline leads | Superpipeline cards, stages and gates | Git, PRs, code review, builds, releases and packages | Shared work-management product for humans and agents | Stronger fit to agentic and non-code work; requires integration and coverage validation |
| Project chooses | Explicit selection per project | Used when selected for code or tasks | Used when selected for work or execution coordination | Welcomes outside teams; more adapters and clearer capability reporting needed |

**Recommended SJL default:** Superpipeline leads work management; Forgejo supplies
software collaboration. **Recommended open-city policy:** independent projects
can retain an external forge and task system. An ordinary team may choose
Forgejo alone. A project can be exhibited without moving its repository or
granting the city write access.

Forgejo includes issue/PR collaboration, wikis, releases and package hosting;
its project boards organise issues as Kanban cards. Their availability does not
require us to expose them alongside Superpipeline for the same project.
Sources: [Forgejo user guide](https://forgejo.org/docs/latest/user/),
[project boards](https://forgejo.org/docs/latest/user/collaboration/project/).

## Proposed ownership

| Record | Authority under the recommended SJL default |
| --- | --- |
| Objective, task, dependency, assignment, stage and work acceptance | Superpipeline, subject to verifying the required capabilities |
| Agent run, lease and human work gate | Superpipeline; runtime facts referenced from AgentPod |
| Workspace, station, runtime lifecycle and permitted execution | AgentPod and host policy |
| Git commit, branch, pull request, review and merge | Project's selected forge and maintainers |
| Build/check result, release and package | Chosen CI/artifact service with project release policy |
| Conversation and room history | Selected Matrix service; Supermessage is a client |
| Project exhibit, residence, civic booking, recognition and JC | The corresponding city authority |

Superpipeline's role is conditional on the intended human-and-agent workflow. Assess
planning, dependencies, handovers, context, budgets, gates and acceptance rather
than assuming every proposed responsibility is already shipped. Its current
wire interfaces and limitations are recorded in the
[automation catalogue](../../research/TOOL_AUTOMATION.md).

## Avoid two boards for one task

For an SJL project using Superpipeline as authority, create and manage work there.
Forgejo's boards can remain unused. A Forgejo issue may serve as an incoming
bug report; triage either links it to existing work or creates one explicitly
linked Superpipeline card. Issue closure and card acceptance have different meanings
and an explicit mapping. Do not mirror all labels, assignments and states both
ways or interpret every comment as an instruction.

Store external references as `(provider, instance, repository, object type,
object ID)` with the original URL and audience. Keep an explicit source of
truth for task state. One task may produce several PRs; one release may satisfy
several tasks. A merged PR supplies evidence, not automatic task acceptance.
Research, education, moderation and design work may finish without a PR.

## The workshop in the city

A project's building can expose an exhibition of demos/releases, a workshop
link to its source, a noticeboard of approved work, a team room and an attributed
history of accepted contributions. These are permission-filtered views of real
records. The game does not own an independent copy of private project history.

The creator portal would let an authorised maintainer link an existing project
or request a new workspace with a chosen template, repository, work board and
conversation room. Each provisioned resource needs its own consent, ownership
mapping, quota and failure handling. A plot is neither a repository permission
nor a promise of unlimited hosting or CI minutes.

## A contribution through the proposed integration

1. A person discovers a permitted task and sees its acceptance criteria.
2. Superpipeline assigns/leases eligible work; a separate grant permits the relevant
   AgentPod workspace and resource budget.
3. The contributor or agent produces a branch and PR in the authoritative forge.
4. CI reports results; maintainers review and decide whether to merge.
5. Superpipeline records work acceptance against its criteria and referenced evidence.
6. City recognition checks eligibility, reviewer authority, uniqueness and the
   funded reward policy. Publication of a story or exhibit requires its own consent.

There is no reward for raw commit counts or automatically opened issues.
Retries must not award twice. Reverted work can trigger a reviewed correction;
deleting a PR notification does not reverse an economic transaction.

## CLI and MCP candidates

| Product | CLI | MCP | Important coverage boundary |
| --- | --- | --- | --- |
| Forgejo collaboration | Git for source; third-party [`fj`](https://cli.fjord.sh/cli) for forge operations; the community MCP below also documents a direct `--cli` mode | Community [`goern/forgejo-mcp` README](https://github.com/goern/forgejo-mcp/blob/main/README.md) | Candidate, not an official Forgejo MCP service; pin and verify against the selected server version |
| Forgejo administration | Official [`forgejo` CLI](https://forgejo.org/docs/latest/admin/command-line/) | Separate privileged integration if required | Administration CLI is not a substitute for the collaboration CLI or a resident tool |
| Superpipeline work | Repository-local `supi` or `superpipeline` (same CLI), private `@superpipeline/cli`, with JSON output | Product `/mcp`, eleven `superpipeline_*` agent tools | Human/member CLI and agent MCP have different authority; MCP lacks run-read/elicitation-answer retrieval, so a full approval loop still needs verified MCP coverage |
| AgentPod runtime | `apn` node and host commands; fleet verbs shipped as `apn fleet` in v0.1.33 (2026-09-17) and are planned to move to a separate `agentpod-fleet` binary (spec and feature branch dated 2026-09-18; not merged or released) | Product `/mcp` with self-scoped read-only station/session/transcript tools | Current MCP is not fleet administration or a city-wide agent browser |
| Existing GitHub projects | Official [`gh`](https://cli.github.com/manual/) and Git | Official [`github/github-mcp-server`](https://github.com/github/github-mcp-server) | Keep per-project repository permissions; no migration required for city membership |

The Forgejo MCP maintainer's README reports that current development moved to
[agentic-forges/forgejo-mcp](https://git.b4mad.industries/agentic-forges/forgejo-mcp).
That upstream URL could not be fetched by the research browser; only the
maintainer's GitHub README was inspected. Confirm the actual release source
before adoption.

**Note, 2026-09-18.** A reviewer's web spot-check confirmed that forgejo-mcp
development moved to
<https://git.b4mad.industries/agentic-forges/forgejo-mcp>. Treat that forge as
the upstream to evaluate and the GitHub repository as a pointer. This pass
tried the URL again and received a bot-protection page, so the move is
reported, not re-verified here, and releases and licence are still unread.
`fj` above is a separate third-party CLI, not Forgejo's admin
binary. No candidate was installed or connected during this pass.

## Integration, CI and operational obligations

Use repository/organisation webhooks as events with verified origin, event IDs,
revision references and a durable retry/reconciliation path. Fetch authoritative
state with a scoped identity before acting on consequential events. Missing
events and revoked access must yield stale/unavailable status, not invented
progress. [Forgejo webhooks](https://forgejo.org/docs/latest/user/repository/webhooks/)

Community CI executes contributor-controlled code. Its runners need isolated
workspaces, bounded compute, controlled secrets and a separation from live
city data and privileged AgentPod/host management. A CI job and an AgentPod
agent run can be linked but are different execution records.
[Forgejo runner security](https://forgejo.org/docs/latest/admin/actions/security/)

Forgejo Actions has similarities to GitHub Actions but is not a guaranteed
drop-in replacement. Review workflows, actions, token permissions, runner
behaviour, caches, artefacts and release steps individually.
[Actions differences](https://forgejo.org/docs/latest/user/actions/github-actions/)

Operating the forge includes upgrades, repository/package/LFS storage quotas,
account recovery, backups/restores, email and abuse handling. Self-hosted
software removes neither that work nor infrastructure costs. The host is
decided: Forgejo will run on the lab server (RD13). Prior host inspections are still
not spare-capacity reservations, and capacity, isolation and backup are open.
SJL's private infrastructure operations own the eventual operational configuration.

## Adoption without forced migration

Keep existing GitHub repositories authoritative until their owners choose a
migration. RD13 gives agents a dedicated git system; it does not order any
existing repository to move. New city-native projects can use Forgejo once it
exists. If a read-only mirror
helps discovery or continuity, declare its direction and label the authority.
Git mirroring covers Git history, branches and tags; issues and PR workflows
need separate migration/synchronisation design. Push mirrors can overwrite
remote Git changes, so do not create two independently writable authorities.
[Forgejo mirroring](https://forgejo.org/docs/latest/user/repo-mirror/)

## Decisions still required

- Decided (RD13): Forgejo runs on the lab server as the agents' git system. The
  items below remain open.
- Accept or revise the SJL default and outside-project choice policy.
- Verify Superpipeline's human/agent task coverage and decide where authorised
  automation needs additional product interfaces; preserve intentional role limits.
- Select and evaluate the Forgejo CLI/MCP implementation, including the moved
  upstream, credentials, maintenance and licences.
- Decide storage placement, capacity, isolation, CI budgets, agent accounts,
  identity linking, backup/recovery, support and the lab/production
  boundary. The host itself is decided.
- Decide whether Superpipeline gains Forgejo reference and webhook support,
  and whether AgentPod gains a Forgejo delivery adapter; both are product
  changes owned by those repositories.
- Specify issue intake, task/PR references, events, reconciliation and reward
  review before implementing any connection.

This brief does not migrate repositories, install tools, create accounts,
issue credentials or grant implementation approval. The hosting machine for
Forgejo was selected by RD13, not by this brief.
