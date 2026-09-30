# Repository consistency review

Dated review · 2026-09-16 · [Design index](../README.md)

Subsequent work: the [Guild resident designs](../vision/GUILD_RESIDENTS.md)
develop all fourteen founding agents, and the [SJL product refresh](../research/SJL_PRODUCT_REFRESH_2026-09-16.md)
records Kaambaan's rename to Superpipeline. The audit findings and file counts
below describe their original scope, not those later additions.

## Scope and evidence

Reviewed the 40 tracked files at `35874d7`, spanning the vision, gameplay,
architecture, integrations, planning, research, three local HTML prototypes,
and the concept-map SVG. This review reconciles the earlier village briefs
with the open maker-city direction, tools requirement and world-model research.
It does not adopt undecided policies or authorise game implementation.

## Conflicts corrected

| Area | Correction |
| --- | --- |
| Free participation | Older residency, facility and agent briefs now distinguish anonymous visitors, free accounts, residency and independent project permissions; saved profiles and civic proposals are not implicitly paid benefits |
| First residency purchase | Razorpay purchase intents bind to a city account; a visitor need not already be a resident to buy the first qualifying offer |
| Project delivery scope | O1 and VIL-30/31 preserve free project creation, collaboration, curation, external tools, withdrawal and export alongside the game slices |
| Database recommendation | PostgreSQL is the full-city candidate; SQLite is only an optional isolated courtyard experiment, not an adopted production starting point |
| Money, clocks and bookings | NPC time, human JC accounting and real billing are distinct; rooms consume centrally accepted bookings rather than owning competing reservations |
| Tools and models | CLI/MCP adoption checks and optional world-model review are carried into planning; streamed experiments remain separate from local city rendering |
| Existing versus proposed | The city-to-AgentPod adapter is proposed, dated CLI/source evidence is distinguished, and website code references name their owning repository |
| Prototype scope | The atlas is labelled as an earlier subset of the ten-district vision; its visitor and facility descriptions reflect the free-account proposal; missing accessible heading IDs were restored |
| Lab-server placement | Existing lab policy and proposed production dependence require an explicit hosting decision; available capacity alone does not settle it |

## Which documents own decisions

- [Decision register](VISION_DECISIONS.md): chosen directions, proposals and
  unresolved choices. The [review guide](VISION_REVIEW.md) gathers discussion;
  the [roadmap](ROADMAP.md) remains conditional on VISION.
- [Project participation](../vision/PROJECTS_AND_COLLABORATION.md),
  [operating model](../vision/OPERATING_MODEL.md) and
  [community charter](../vision/COMMUNITY_CHARTER.md): recommended access,
  funding, ownership and civic policy, still pending acceptance.
- [City systems](../architecture/CITY_SYSTEMS.md): logical authority boundaries.
  [Tooling contract](../architecture/AGENT_TOOLING.md): adoption prerequisites.
  Research catalogues record dated evidence, not installed capabilities.
- Prototypes illustrate bounded fictional scenarios. They neither implement
  the full policy matrix nor supersede the owning briefs.
- SJL's private infrastructure records own machine inventory, operational
  findings and runbooks. Product plans describe requirements and unresolved
  placement.

## Infrastructure cross-check

On September 16 SJL's private infrastructure records and a candidate lab
server were checked read-only, without editing records, running provisioning
scripts or changing remote configuration. Machine inventory, access and
operational output are deliberately not reproduced here. Access to a host does
not prove service health, backups, capacity reservation or permission to
deploy. The material city planning issue is the
[lab/production boundary](../architecture/STORAGE.md#hosting-role).

## Validation and limits

- All local Markdown/HTML/SVG references, document anchors and accessible
  label targets resolve. HTML/SVG IDs are unique, SVG XML parses, and Markdown
  code fences balance.
- All three extracted prototype scripts pass Node syntax checks.
- Browser checks passed for atlas phases, destination selection, placement,
  undo and lifestyle previews; city daily budget, bridge detour and water-dependent
  fire dispatch; and economy transfers, protected booking refunds, scholarship
  restoration, pending cash fixtures and one-time benefit fulfilment.
- The economy example ended at 680 JC in the wallet, 1,820 JC in the treasury
  and 4,400 JC total including the separate scholarship pool, as intended.
- No browser console errors were observed during those interactions. This
  pass did not repeat the earlier mobile, no-JavaScript or physical-device tests.
- Git whitespace validation passed. No game runtime, paid API or live ledger
  was involved in these local prototype checks.

External research remains dated evidence. This review did not refresh every
provider page, licence, price, API, model weight or tool package, and did not
install tools, contact payment APIs, deploy the game or run multiplayer tests.

## Intentionally unresolved

Contributor-earned entry residency, cash-to-JC conversion, exact prices,
retention constants, governance rules, engine selection, Forgejo/Kaambaan
allocation, host placement and world-model adoption still need decisions or
later operational evidence. Keeping them labelled as proposals is consistent;
marking them approved would not be.
