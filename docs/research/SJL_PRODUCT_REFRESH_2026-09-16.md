# Superpipeline and the September 16 SJL product changes

Source and commit review · 2026-09-16 · [Ecosystem](../vision/ECOSYSTEM.md)

> **Superseded on 2026-09-18.** This is a dated survey; its findings below are
> unchanged. Four things moved after it was written, each checked in the
> sibling repositories on 2026-09-18:
>
> 1. **Agent-token prefix.** The `kbn_` prefix did *not* survive. Superpipeline
>    agent tokens have started `spa_` since 2026-09-17 with no fallback: a
>    `kbn_` token is no longer recognised as an agent credential at all
>    (`superpipeline` `origin/main`, `apps/api/src/auth/agent-token.ts`;
>    and an internal SJL decision record). The "deliberately retained" and
>    "do not re-mint" statements below are therefore out of date; any agent
>    identity minted under the old prefix needs re-minting.
> 2. **AgentPod CLI.** `apn fleet` shipped in AgentPod v0.1.33 on 2026-09-17,
>    the latest tag. A spec dated 2026-09-18 plans to split the fleet client
>    into its own `agentpod-fleet` binary (alias `fleet`) and remove
>    `apn fleet`; that work is on a feature branch and is not merged or
>    released
>    (`agentpod/docs/superpowers/specs/2026-09-18-apn-fleet-split-design.md`).
> 3. **The `member` role is a default, not a guardrail.** Superpipeline's
>    `apps/api/src/auth/resolve.ts` resolves `role: local ?? 'member'`; a
>    membership row can name any role for the same token. See the
>    [automation catalogue](TOOL_AUTOMATION.md).
>    **Corrected 2026-09-20:** true of the code, unreachable in practice — on
>    the day this was written nothing could write a membership row keyed on a
>    hub principal, so `local` was always null and every hub token was `member`.
>    superpipeline added subject→user mapping on 2026-09-20 and the lever now
>    exists; a mapped principal resolves its real role, verified as `owner`
>    against production. The finding as stated described a configuration lever
>    two days before one existed.
> 4. **Place-ID rename on the website.** The website renamed the place slug
>    `kaambaan` to `superpipeline` and migrates saved visits with a shim
>    (`super-jackfruit-website/src/scripts/village/visits.mjs`), while this
>    repository's atlas kept `kaambaan` as its stable key. Lesson 1 below
>    still describes the intended rule; the two repositories now disagree and
>    nobody owns the ID registry.
>
> Paths are relative to the workspace holding the sibling repositories. Later
> decisions (RD02, RD13, RD14) are in the
> [decision register](../planning/VISION_DECISIONS.md#decisions-recorded-on-2026-09-18).

Rakesh confirmed that Kaambaan has been renamed **Superpipeline** and asked
for recent SJL commits to be checked. This pass read the GitHub inventory, the four most recent default-branch
commits for the relevant repositories, selected local source and the internal
SJL rename decision.
It did not deploy products, run their test suites, exercise authenticated MCP
or verify production workflows. Commit authors' test/deployment reports remain
reported evidence, not tests executed by the city planning project.

**Subsequent CLI update:** after the initial review below, Rakesh pointed out
the executable rename. GitHub `main` and the local checkout now match
[21604e3, PR #72](https://github.com/SuperJackfruitLabs/superpipeline/commit/21604e354c49b3dc3e1951bd72037b4f74886cc1).
The manifest installs **`supi` and `superpipeline` as the same program**;
examples use `supi`. It no longer declares a `kbn` executable. The `kbn_`
agent-token prefix is unchanged. The interface table below incorporates this
follow-up; the earlier revision inventory still records the initial inspection.

## Checked revisions and what they establish

| Project | Revision / observed branch state | Relevant finding |
| --- | --- | --- |
| Superpipeline | Default branch [6ef467a](https://github.com/SuperJackfruitLabs/superpipeline/commit/6ef467ae15fc923299b9e1d709937220c82e7611), including rename merge [db8926e](https://github.com/SuperJackfruitLabs/superpipeline/commit/db8926ea723ac7bb001aac46d97f1b2f1db7c60d) | New repository/product/package names, app/docs/public hostnames and MCP vocabulary; subsequent logout-cookie fix merged |
| AgentPod | Default branch [4da2c62](https://github.com/SuperJackfruitLabs/agentpod/commit/4da2c623a166ac96062ac31b26dd9ec8f06043f8) | Bridge/configuration/identity vocabulary and Matrix gate events follow Superpipeline; adds forward database migration 0066 |
| Supermessage | Default branch [24a571a](https://github.com/SuperJackfruitLabs/supermessage/commit/24a571ae1c123f48ddabe57e0827544631965c57) | Gate event vocabulary follows the rename; generated mobile bindings and visual fixtures updated |
| Internal SJL decisions | Rename decision recorded on 2026-09-16 | Records naming decision, old-domain retirement, preserved history/token prefix and operational lessons |
| SuperMD | GitHub default branch remained [ec53bce](https://github.com/SuperJackfruitLabs/supermd/commit/ec53bce15a2bac22cd845a3058d5688de95ae183); local HEAD was `b3519a1` | Local appearance/theme-contrast work is newer than the published default branch. Useful design direction, not a new released city capability; local untracked work was left untouched |
| Website | Default branch [af6bf54](https://github.com/SuperJackfruitLabs/super-jackfruit-website/commit/af6bf544738beeb29360464401f94758deef2feb) | Website/city planning handoff is merged; the older local checkout does not reflect that merge |

The locally inspected Superpipeline `09b7461` tree equals remote `6ef467a`'s
tree, and AgentPod `2d6c4301` equals remote `4da2c62`'s tree. Tree equality was
checked against GitHub, rather than assuming a local commit and a merge SHA
contain the same source. The remote revisions above pin the findings below.
This is a bounded review, not an audit of every file in every SJL project.

## Names and interfaces for new work

| Surface | Current finding | City implication |
| --- | --- | --- |
| Product/repository | Superpipeline / `SuperJackfruitLabs/superpipeline` | Use the new name in current plans, workshop labels and links |
| Public/app/docs | `superpipeline.dev`, `app.superpipeline.dev`, `docs.superpipeline.dev` in current product configuration/docs | Use the app origin for supported application/API integrations; verify the chosen deployed surface before use |
| Packages | `@superpipeline/*`; inspected CLI package remains `private: true` | Do not prescribe installing a public npm package that was not established |
| CLI | `supi` and `superpipeline` point to the same entry point at 21604e3 [SP04]; `SUPERPIPELINE_URL` and `SUPERPIPELINE_TOKEN`; default app origin | Use `supi` in new examples; the full command is equivalent. Human/member authority remains distinct from an agent credential |
| MCP | Streamable HTTP at `/mcp`, eleven registered `superpipeline_*` agent tools | New tool manifests must use the new names; server startup or docs access is not workflow coverage |
| Agent credential | `kbn_` prefix deliberately retained | Do not replace or re-mint working credentials merely to match branding |
| Matrix gates | `dev.superpipeline.gate.v1` and `dev.superpipeline.gate.decision.v1` | Pin the producer/consumer contract and preserve event IDs/audiences; an old message is not a new approval |
| Historical records | Old names remain in dated decisions, source revisions, migrations and room history | Add supersession/context; do not falsify prior evidence or replay history as new work |

Sources: **SP01**, the [CLI manifest](https://github.com/SuperJackfruitLabs/superpipeline/blob/6ef467ae15fc923299b9e1d709937220c82e7611/packages/cli/package.json),
[CLI README](https://github.com/SuperJackfruitLabs/superpipeline/blob/6ef467ae15fc923299b9e1d709937220c82e7611/packages/cli/README.md)
and [credential/configuration source](https://github.com/SuperJackfruitLabs/superpipeline/blob/6ef467ae15fc923299b9e1d709937220c82e7611/packages/cli/src/credential.ts);
**SP02**, [MCP tool registration](https://github.com/SuperJackfruitLabs/superpipeline/blob/6ef467ae15fc923299b9e1d709937220c82e7611/apps/api/src/mcp/tools.ts)
and [integration surfaces](https://github.com/SuperJackfruitLabs/superpipeline/blob/6ef467ae15fc923299b9e1d709937220c82e7611/docs/05-integration-surfaces.md);
**SP03**, the internal SJL decision "Kaambaan is now Superpipeline" (2026-09-16).

**SP04**, CLI follow-up at 21604e3: [manifest](https://github.com/SuperJackfruitLabs/superpipeline/blob/21604e354c49b3dc3e1951bd72037b4f74886cc1/packages/cli/package.json),
[README](https://github.com/SuperJackfruitLabs/superpipeline/blob/21604e354c49b3dc3e1951bd72037b4f74886cc1/packages/cli/README.md)
and [entry point](https://github.com/SuperJackfruitLabs/superpipeline/blob/21604e354c49b3dc3e1951bd72037b4f74886cc1/packages/cli/src/index.ts).
Both executable names map to `./src/index.ts`; the package is still private.
This confirms source registration, not installation on each city host. SP01
retains the earlier CLI evidence and is superseded for executable naming.

The rename decision records retirement of the old product domain, rather than a
permanent redirect promise. It also records that historic custom gate events
lose their interactive rendering in the renamed clients, while companion
ordinary messages remain readable. Do not promise actionable old gate cards
or rely on the old domain. This pass did not probe retired hosts or replay gates.

## CLI and MCP still have different capabilities

The CLI acts using a hub-issued member identity and does not gain workspace
administration from that token. Agent MCP/REST uses the agent's own identity;
no gateway should relabel a human's command as an agent action to bypass this
distinction. Both interfaces exist, but their permitted operations differ.

The current integration document explicitly identifies a gap: **MCP has no
run-read tool**, so an MCP-only agent cannot retrieve an elicitation answer
from its run. Native MCP `elicitation/create` is also documented as open.
The REST run-read path is a documented alternative for an appropriately
authenticated agent, but it does not by itself satisfy the city's requirement
for operational MCP coverage of that workflow. A narrow reviewed adapter or
product extension, with CLI/MCP read-back, is required before adopting that
complete approval loop. No authority widening or implied exception is approved.

The rename leaves the proposed allocation intact: Superpipeline owns selected
work records and gates, the chosen forge owns code/reviews/releases, AgentPod
owns permitted runtime operations, and the city owns homes, service offers
and approved projections. See [the integration proposal](../integrations/development/FORGEJO_SUPERPIPELINE.md).

## A migration-order concern to resolve in AgentPod

Source inspection found a specific upgrade case needing review. The preceding
[0056 migration](https://github.com/SuperJackfruitLabs/agentpod/blob/4da2c623a166ac96062ac31b26dd9ec8f06043f8/apps/hub/src/db/drizzle-migrations/0056_left_darwin.sql)
allows `kaambaan` in the `principal_identities_system_known` CHECK, but not
`superpipeline`. [0066](https://github.com/SuperJackfruitLabs/agentpod/blob/4da2c623a166ac96062ac31b26dd9ec8f06043f8/apps/hub/src/db/drizzle-migrations/0066_kaambaan_is_now_superpipeline.sql)
updates existing rows to `superpipeline` **before** dropping that old CHECK.
For a database with old-name rows and that constraint still applied, the UPDATE
would violate it. A fresh/empty table or an already manually adjusted database
would not exercise the same case.

This is a source-level finding, not a claim that the live hub is broken; no
database was inspected or migrated here. The product owner should reproduce
the populated upgrade path and establish the correct forward repair for the
actual applied migration history. The city must not copy this sequence into
its own runbook or rewrite applied migrations to match a product label.

## Lessons for the Guild and city

1. **Identity survives a product rename.** Keep city resident/project/place IDs
   independent of product display names. The atlas's existing `kaambaan` place
   key remains stable while its visible label becomes Superpipeline Yard.
2. **An approval needs a working return path.** Pete's plan, Kai's task or
   Theo's review needs a verified scope, human gate and result read-back;
   identifying eleven MCP tools is not proof of the complete encounter.
3. **Version the whole conversation contract.** Source, producer, client,
   generated bindings, event vocabulary and fallback rendering must agree.
   Reconnecting an agent does not convert historic chat into new instructions.
4. **Check real workflows after a migration.** The rename decision reports configuration,
   secrets, storage and registered-client issues that a health endpoint did not
   reveal. Future city admission needs sign-in, scoped task/gate/result and
   recovery evidence as well as process health. Details belong with the owner.
5. **Keep local work distinct from published evidence.** SuperMD and an
   internal repository had newer local work; the website had a newer remote merge. The city should
   identify exactly which revision and deployment a service claim describes.

Current city plans and labels have been updated. Earlier research evidence
retains its original names with a pointer here. No SJL product, server,
credential, applied migration or historical room message was changed in this
city planning pass. Vision decisions and the separate build gate remain open.
