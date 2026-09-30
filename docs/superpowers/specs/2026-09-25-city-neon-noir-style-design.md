# Neon noir style: design

Date: 2026-09-25. This is the third of three independent style specs, after the [anime](2026-09-25-city-anime-style-design.md) and [solarpunk](2026-09-25-city-solarpunk-style-design.md) styles. It builds on their shared pieces:

- weather;
- the benchmark gate;
- the sheet-view tools;
- animation level of detail;
- the semi-realistic character path;
- robot agents.

## 1. Goal and success

A sixth style pack, **Neon noir** (style study 10), after its four sheets under `docs/vision/style-studies/styles/10-neon-noir/sheets/`:

- city perspectives r006;
- living community r002;
- creating and exploring r003;
- interfaces r004.

The look is night-first:

- dark slate and navy architecture;
- selective pools of warm amber light, and lit windows;
- cyan, amber and magenta accents, with magenta neon crowning the towers;
- wet, reflective paving that mirrors every light;
- occupied interiors that glow warm and inviting.

It is dramatic without being dystopian: there are no combat or grim props.

**Day.** The brief asks for a deliberate daytime interpretation, which the sheets do not show. By day it is a cool, clean city:

- slate and glass under an overcast-blue sky;
- neon off, but the signs still read as dark glass tubes;
- the same palette at lower saturation.

Dusk turns it on.

**Success** is measured as for the other styles:

- sheet match, in `neon-vs-sheet.png` and `neon-notes.md`;
- the same frame budget.

## 2. Rendering

- **Night light.**
  - A deep navy sky, with a moon-cool directional light and low energy.
  - Many warm OmniLights at lamps. They cast no shadows, and far ones fade out by distance.
  - Emissive windows and neon strips with glow (bloom threshold at emissive levels only).
- **Wet ground.** Screen-space reflections on the paving and streets while wet: at night always a little (dew), strongly in rain. If SSR breaks the budget, the fallback is the anime style's lamp reflection streaks plus a glossy ground.
- **Atmosphere.** Light volumetric fog in rain, only if it fits the budget. Otherwise, depth fog tinted navy.
- **Anti-aliasing.** 4× MSAA.

## 3. The neon noir kit

A generator at `city/tools/styles/neon/`, with the same module names and conventions as the other kits.

- **Workshop:** dark metal and glass sawtooth bays with warm interior light and tall glazed gables.
- **Library:** a glowing drum with a lit dome ring.
- **Towers:** dark glass towers with warm lit windows and magenta neon edge strips at their crowns.
- **Houses and shops:** slate and charcoal, with neon shop signs as abstract glyph shapes, no text.
- **Streets:** streets, stone paving, the tram and the bridge, with its lamps.
- **Plants:** palms and trees.
- **Props:** lamps (warm globes), bollard lights, benches, and planters with uplights.
- **Interiors:** as in the other kits.

## 4. Characters

- **People.** People reuse the semi-realistic body and face path (solarpunk spec), in night-appropriate clothing: dark jackets, hoodies and scarves.
- **Agents.** Agents are robots:
  - a glossy black-and-white helmet with a cyan ring eye;
  - a dark hoodie over white limb plates;
  - the ID card.
- **A1.** City Agent A1 is that robot, as in the conversation sheet.

## 5. Testing

- **Contract:** the pack contract.
- **Pack tests:**
  - night lights and neon on;
  - day neon off;
  - wet reflections in rain;
  - the robot agents and A1.
- **Kit:** the kit tests.
- **Performance:** the benchmark budgets.
- **Visual:** sheet views and the audit.

## 6. Not in this spec

Map view, conversations, tram riding and rooftops.
