# The game interface against the sheets

`interface-vs-sheets.png` holds one row per style. Each row shows:

- the style's sheet-03 FACILITY and MOBILE panels, at the revision its
  study's README selects (anime r004, solarpunk r003, neon r004, pixel art
  r008, low-poly r004, voxel r003);
- the game menu, the play HUD and the title, captured at 1920 × 1080.

The composite is at three quarters of the sheets' size. Captures are
scaled whole to the panels' height and not cropped, so the interface
reads small beside the sheets' close-ups.

The tools:

- `tools/sheet_views.gd -- <style> interface` captures every screen:
  - the title, the Join screen and its look step, the HUD, the game menu
    and the style picker;
  - the five settings pages, rebinding and the developer panel;
  - each at 1920 × 1080, 1280 × 720 and 800 × 900, into
    `~/.cache/agentnagar-sheets/<style>/ui-*.png`.
- `tools/interface_compare.py` composes the sheet.

The desktop gives the client's window 1280 × 662 in windowed mode,
whatever size is asked for. The tool therefore renders the viewport at each exact size and scales
it into the window: all 234 captures are the size named.

I looked at every capture at full size and at half size.

The sheets draw kiosks and a phone app, not a game's menus. The comparison
is therefore of the skin (panels, buttons, type, colour and focus), not of
the layout. No style yet draws the sheets' action icons (the open book,
calendar and speech bubble) or their map pins: the interface has no Browse,
Book or Ask to put them on.

## Every style

What is common to all six:

- **The HUD.** It is quiet, as specified:
  - the clock with a sun, moon or rain icon, top right;
  - the fixture notice, bottom left;
  - the input hints, which fade after ten seconds, bottom right.
  The chips are the skin's panel colour at 85%. The sheets' MOBILE panels
  show a phone app, so they have no counterpart for the HUD.
- **The developer panel (F3).** It keeps its own fixed dark skin in every
  style, by design.
- **The focus.** The focused control shows its ring in every capture. Neon
  and pixel art add a glow.

## Anime (06)

Matches:

- The MOBILE card: a light rounded panel with a soft shadow.
- Solid blue buttons with white text, like the MOBILE panel's Ask.
- Rounded ExtraBold type (M PLUS Rounded 1c) on the name and headings.
- The picker's current card is filled with the accent blue.

Differs:

- The FACILITY kiosk's buttons are pale cards with blue icons and blue
  lettering. Every game button is solid blue, since one accent serves
  every button.

## Solarpunk (09)

Matches, and this is the closest match to its FACILITY panel:

- A deep-teal field in a brass frame.
- Cream pill buttons lettered in teal.
- Josefin Sans, and a brass focus ring.
- The slider tracks are brass.

Differs:

- The FACILITY panel's teal line icons are missing.
- The MOBILE panel's light card, with its teal Ask button, has no
  counterpart: every screen uses the dark framed panel.

## Neon noir (10)

Matches:

- Dark navy glass panels with a thin cyan edge.
- Light Rajdhani type.
- A soft cyan glow round the focused control.

Differs:

- The sheet's buttons are a brighter, lit blue (the MOBILE Ask most of
  all). The game's are dark `#12324F` with a cyan edge.
- The glow is fainter than the sheet's.
- At 1920 × 1080 the menu panel is small against the dark city.
- The HUD's chips are dark glass and read well only where the city behind
  them is lit.

## Pixel art (08)

Matches:

- Dark navy pixel frames with a blue highlight edge.
- Press Start 2P headings and name, and Pixelify Sans labels, all on
  whole-pixel sizes.
- A glow and a ring on focus.
- The picker's current card is lit blue, like the sheet's selected button.

Differs:

- The FACILITY kiosk fills its selected button with bright blue. The game
  shows the ring and glow, and fills a button only on hover or press.
- Press Start 2P is wide: the menu header "Visitor · walking" spans the
  whole panel.
- The MOBILE panel's light card has no counterpart.

The title's fixture notice was 10 px (14 px snapped down to the pixel
body face's 10 px grid). At half size it could not be read. It is now
20 px, the next whole step of the grid, in pixel fonts only. The other
skins keep 14 px, and `test_narrow_layout.gd` checks both.

## Low-poly tropical (11)

Matches:

- A cream rounded card with an orange edge.
- Chunky 56 px rounded buttons.
- Bold Baloo 2 type.
- A green focus ring.

Differs:

- The sheet's buttons are green, orange and yellow, one colour per
  action. The game's are all one burnt orange, `#B85A10`, which white
  text needs for 4.5:1 contrast; it reads browner than the sheet.
- The sheet's icons are missing.
- This sheet's caption strip is taller than the comparison contract's
  32 px. The crop the tools share therefore keeps the bottom of the
  "FACILITY" and "MOBILE" captions at the top of both panels. It is a
  cropping artefact, not part of the panel.

## Voxel (02)

Matches:

- White square panels with a thick navy edge.
- Square buttons.
- Rounded, blocky Fredoka type.

Differs:

- The sheet's tiles come in several colours (orange, blue, green, purple)
  with large icons. The game's buttons are one blue, with text only.

## Narrow layout (800 × 900) and 1280 × 720

Every screen fits 1280 × 720 in every style. At 800 × 900, four problems
showed in the first captures:

- The style picker's three columns ran off the right edge, in every
  style.
- Pixel art's title name (72 px Press Start 2P) ran off the card.
- Pixel art's settings page names (30 px) ran off the panel.
- Pixel art's HUD fixture notice ran into the hints.

Below 900 px of width, screens now take a narrow layout (`Screen.narrow`):

- The style picker shows two cards to a row, with 240 × 135 previews.
- The title's name drops to 48 px.
- The settings page names drop to 16 px. This happens only when they
  would not fit, so in practice only in pixel art.
- The HUD's hints stack above the fixture notice.

`test_narrow_layout.gd` shows each screen in each style in a viewport of
each size and checks that every control lies inside it. A rebinding
list's rows are left out of the check, since they scroll.

Two smaller fixes came from the captures:

- **The settings panel now steps aside under rebinding,** as the game
  menu's does. Neon's glass had shown the page names through the
  rebinding panel, and pixel art's wider settings panel showed at its
  sides at 1280 × 720.
- **The picker covers the HUD.** In the narrow picker, the edge of the
  hints chip still shows beside the panel. It is harmless and left as it
  is.

## Performance

Measured by `scripts/bench.sh` on the development laptop: RTX 3070 Ti
Laptop GPU, 1920 × 1080 panel at 360 Hz, COSMIC. The laptop was on
`system76-power profile performance`, with vsync at the display's rate.

- **Native resolution.** The bench now runs fullscreen at the display's
  native resolution, as players see it. Every scene below rendered at
  1920 × 1080. A scene rendered at any other size fails the run.
- **Earlier numbers were at 1280 × 662.** Before this, the desktop gave
  the bench's window 1280 × 662 while the bench claimed 1920 × 1080. The
  figures in the earlier style notes were measured at that size.
- **The baseline.** An empty scene, measured the same way, gives
  342.0–343.0 fps and misses 1.75–2.43% of refreshes. So the gate for
  normal play is about 332 fps, with at most about 3% of refreshes
  missed.
- **Heat is recorded.** Every half second the bench samples the GPU's
  temperature and graphics clock (`nvidia-smi`). For each scene it
  reports the peak temperature and the lowest and median clock
  (`tools/bench_heat.py`), so heat can be told apart from cost.

### Each style alone from a cool GPU

Each style was run alone (`BENCH_STYLES=<style>`), starting below 60 °C.
Each scene lasts about 10 s: 5 s uncapped, then 5 s at vsync. The table
gives, for each scene:

- the frame rate at vsync and the share of refreshes missed;
- the uncapped median frame time;
- the scene's peak GPU temperature and median graphics clock.

| Style | topdown | diagonal | street | fpv | menu | title | heavy (300, night, rain) | Over |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| anime_cel | 340.8, 1.88%, 2.25 ms, 75 °C, 1620 MHz | 341.0, 2.05%, 2.43 ms, 81 °C, 1590 | 341.0, 1.94%, 2.08 ms, 84 °C, 1605 | 341.0, 1.94%, 2.24 ms, 87 °C, 1545 | 332.4, 1.99%, 2.68 ms, 87 °C, 1320 | **322.8**, 2.11%, 2.81 ms, 87 °C, 1215 | 303.6, 2.77%, 88 °C, 1208 | title |
| solarpunk | 341.0, 1.82%, 2.69 ms, 80 °C, 1538 | **317.0**, 1.96%, 3.02 ms, 86 °C, 1508 | 340.6, 1.88%, 2.43 ms, 87 °C, 1500 | 334.4, 1.97%, 2.76 ms, 87 °C, 1290 | **253.4**, 3.24%, 3.78 ms, 87 °C, 1155 | **241.0**, 23.98%, 4.03 ms, 87 °C, 1080 | 283.0, 2.61%, 88 °C, 1125 | diagonal, menu, title |
| neon_noir | 341.0, 1.94%, 2.35 ms, 79 °C, 1620 | 340.8, 1.88%, 2.57 ms, 85 °C, 1590 | 341.4, 1.82%, 2.09 ms, 87 °C, 1598 | 340.6, 1.82%, 2.38 ms, 87 °C, 1380 | **296.6**, 2.16%, 3.17 ms, 87 °C, 1215 | **282.4**, 2.34%, 3.49 ms, 87 °C, 1125 | **233.2**, 20.07%, 89 °C, 1095 | menu, title, heavy |
| pixel_art (no budget) | 342.2, 1.93%, 0.94 ms, 55 °C, 1635 | 341.8, 1.99%, 0.82 ms, 58 °C | 342.4, 1.87%, 0.77 ms, 61 °C | (no first person) | 342.4, 1.93%, 0.82 ms, 62 °C | 342.4, 2.04%, 0.83 ms, 64 °C | 341.8, 2.05%, 64 °C | ungated |
| lowpoly_tropical (no budget) | 290.2, 5.03%, 3.11 ms, 78 °C, 1635 | 278.8, 4.30%, 3.34 ms, 85 °C, 1620 | 324.8, 2.28%, 2.77 ms, 87 °C, 1545 | 269.6, 6.08%, 3.42 ms, 87 °C, 1425 | 242.0, 12.56%, 3.97 ms, 87 °C, 1260 | 231.2, 35.12%, 4.10 ms, 87 °C, 1170 | 204.0, 95.59%, 87 °C, 1365 | ungated |
| voxel (no budget) | 288.8, 5.47%, 3.08 ms, 79 °C, 1635 | 285.6, 3.99%, 3.28 ms, 85 °C, 1620 | 337.0, 2.26%, 2.56 ms, 87 °C, 1612 | 285.8, 4.76%, 3.21 ms, 87 °C, 1492 | 243.6, 10.18%, 3.82 ms, 87 °C, 1282 | 234.2, 32.71%, 3.90 ms, 87 °C, 1200 | 212.4, 78.72%, 87 °C, 1440 | ungated |

Frame rates are in fps; bold marks a scene over the gate.

**The menu and the title run fifth and sixth.** By then the GPU is at
87 °C and its clock has fallen from about 1600 MHz to 1100–1300 MHz. So in
these runs the menu and title are measured on a slower GPU than the views
before them.

### The menu and the title against the view beneath them, each from a cool GPU

To separate what a screen costs from what heat costs, the diagonal view,
the menu and the title were each run alone (`BENCH_SCENES=<scene>`). Each
started below 60 °C, peaked at 78–81 °C and ran at a median clock of
1515–1620 MHz.

| Style | diagonal | menu | title |
| --- | --- | --- | --- |
| anime_cel | 341.0 fps, 1.82%; p50 2.41 ms, GPU p99 2.34 ms | 341.2 fps, 2.23%; p50 2.45 ms, GPU p99 2.40 ms | 340.8 fps, 1.94%; p50 2.41 ms, GPU p99 2.34 ms |
| solarpunk | **320.4** fps, 1.94%; p50 2.97 ms, GPU p99 3.03 ms | **314.8** fps, 2.03%; p50 3.02 ms, GPU p99 3.13 ms | **315.8** fps, 2.22%; p50 3.00 ms, GPU p99 3.02 ms |
| neon_noir | 341.0 fps, 1.94%; p50 2.52 ms, GPU p99 2.48 ms | 341.2 fps, 1.93%; p50 2.56 ms, GPU p99 2.51 ms | 341.2 fps, 1.88%; p50 2.55 ms, GPU p99 2.49 ms |

At the same clock, the interface costs very little.

- **Uncapped cost.** The median frame time rises by 0.00–0.05 ms, or at
  most 1.7%. GPU time rises by at most 0.10 ms (3%).
- **At vsync.** Anime's and neon's frame rates are unchanged within
  0.4 fps. Solarpunk's menu and title run 4.6–5.6 fps (at most 1.7%)
  below its diagonal view. At most 0.4 points more of the refreshes are
  missed.
- **Anime and neon** pass the gate with the menu or the title open.
- **Solarpunk** misses it by the same margin with or without a screen:
  its diagonal view already runs at about 320 fps at native resolution.

The larger rises in the per-style runs are heat. There the uncapped
median rose 10–36% over each style's diagonal view: the menu 10–25%, the
title 16–36%. Those scenes ran at 1100–1300 MHz rather than about
1600 MHz.

Where a screen's scene failed in the per-style runs, I looked for a cost
of the screen itself: the scrim, neon's see-through glass, the glow halo
and the title's drift. None showed at equal clocks. Nothing was reduced,
because there was nothing to reduce.

Neon's heavy scene, run alone from a cool GPU, gave 316.6 fps and 2.53%
missed. That clears its 240 fps floor. The 233.2 fps in its per-style run
came at 89 °C and 1095 MHz.

### Pre-existing, and not fixed by this plan

- **Solarpunk's normal play is below the gate at native resolution.**
  From a cool GPU, its diagonal view gives 317.0–320.4 fps and its first
  person 334.4 fps (at 1290 MHz), against about 332. At 1280 × 662 it
  passed.
- **Sustained heat fails every 3D style.** Low-poly, voxel, anime, neon
  and solarpunk all slow once the GPU reaches 86–87 °C, which takes about
  30–40 s at native resolution. So a full `scripts/bench.sh` over six
  styles, or even one style's seven scenes, cannot pass on this laptop
  as it stands.
- **Low-poly, voxel and pixel art declare no budget,** so spec §1
  criterion 4 ("every style") is not checked for them. They were
  ungated, or below the gate, before this branch. From a cool GPU:
  - Low-poly and voxel reach 270–337 fps in normal play and miss up to
    6% of refreshes. Their menu and title (231–244 fps) ran hot, at
    1170–1282 MHz.
  - Pixel art holds 341.8–342.4 fps in every scene. It would pass the
    gate if it had a budget.

  A budget for these three, and the work to meet it, is a follow-up.

The concept-sheet panels in `interface-vs-sheets.png` are crops of AI-generated concept art
(CC0 1.0); see [the evidence README](README.md).
