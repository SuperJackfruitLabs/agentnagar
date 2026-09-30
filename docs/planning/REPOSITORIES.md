# Repository ownership and migration

Approved by Rakesh · 2026-09-15

The city/game was originally created as **SuperJackfruitLabs/super-jackfruit-world**,
with private access to match the internal SJL repository its design documents
came from. Godot remains the first candidate for evaluation, not a final
engine choice. This migration changes documentation ownership, not gameplay.

| Repository | Canonical responsibilities |
| --- | --- |
| [agentnagar](../../README.md) | Game design, civic/residency rules, avatars, activities, client/platform decisions, simulation, assets, contracts and game service releases |
| [super-jackfruit-website](https://github.com/SuperJackfruitLabs/super-jackfruit-website) | Astro site, public pages, catalogue, navigation, accessibility, web/game entry and downloads |
| SJL's internal marketing workspace | Campaigns and public product claims |
| [agentpod](https://github.com/SuperJackfruitLabs/agentpod) | Agent runtime/fleet management and supported identity/interaction contracts |
| SJL's private infrastructure workspace | Host administration and operations |

City services and clients share one repository until stable boundaries justify
a split. Add `game/`, `server/`, `contracts/` and authored `assets/` as actual
implementation arrives. Current contents are `docs/` and `prototypes/` only.
Keep internal plans out of website `public/`, automatic content imports and
client exports. Release artifacts need a versioned distribution workflow.

## Agentnagar rename — September 17, 2026

Rakesh chose **Agentnagar** as the project name and registered `agentnagar.com`.
The repository is now **SuperJackfruitLabs/agentnagar** (formerly
`SuperJackfruitLabs/super-jackfruit-world`). Repository history and the ownership boundaries above are retained. This rename does not deploy
a website or change the project’s implementation status.

## Provenance and migration map

The design documents started in an internal SJL repository, under
`website/village/`. The original planning history remains there; this
repository's initial commit imports that snapshot with the ownership split and
updated relative links. Infrastructure configuration findings stay private;
this repository records only the hosting boundary relevant to city design.

| Former path under `website/village/` | Maintained destination |
| --- | --- |
| README and core city briefs | Topic directories under this repository `docs/`; see [index](../README.md) |
| ARCHITECTURE website-route section | Website `docs/VILLAGE_WEBSITE_PLAN.md` |
| RESEARCH existing-village baseline and source map | Website `docs/VILLAGE_WEBSITE_PLAN.md` |
| ROADMAP V0 and VIL-01–04 | Website `docs/VILLAGE_WEBSITE_PLAN.md` |
| Remaining architecture/research/roadmap sections | Topic directories under this repository `docs/` |
| atlas.html and city-lab.html | This repository `prototypes/` |
| Marketing material | Stays in SJL's internal marketing workspace |

Website requirements are now in the
[website plan on master](https://github.com/SuperJackfruitLabs/super-jackfruit-website/blob/master/docs/VILLAGE_WEBSITE_PLAN.md),
merged through [PR #1](https://github.com/SuperJackfruitLabs/super-jackfruit-website/pull/1).
Existing website plans remain historical. This handoff changed documentation
only; no deployment command was run, and downstream deployment status was not
checked.

The source repository retains short pointers to the moved documents and no
longer holds another editable copy of the city requirements.

## Completion and follow-up

Validate local Markdown/HTML links and prototype behavior at the destination,
make city and website destination commits available, then commit the source
repository's handoff. Keep each repository change logical and reviewable. This record's
migration concerns document ownership only: all unimplemented gameplay and
website tickets remain open. The website documentation PR is merged; no server deployment or website
deployment command was performed by this work.

## Subject-based documentation layout — September 16

The flat documents were reorganized into `vision/`, `gameplay/`,
`architecture/`, `integrations/`, `planning/` and `research/`. The root docs
index is the maintained entry point. Razorpay lives under
`integrations/payments/`; it does not sit beside high-level game design.
README, prototype and website links are updated to these owners.
Earlier commit-pinned evidence remains at its historical location.
