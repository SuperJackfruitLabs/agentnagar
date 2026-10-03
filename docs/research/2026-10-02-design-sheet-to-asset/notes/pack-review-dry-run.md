# Review of the image pack by a second agent (dry run, 2026-10-02 about 03:45)

Saved from the reviewer's report so it survives a context loss. It read the pack and watched the pilot batch as it ran. To act on when the pack is revised, after the batch is finished.

## Stops or misleads the agent

1. Seen: corrections wasted on the backdrop. The check "The backdrop is one flat grey…" failed on the first three design sheets (a faint gradient, and the contact shadows the prompt itself asks for). 2, 1 and 1 corrections spent, nothing changed. Later reviews accept the gradient "under the owner's instruction". The files still say otherwise.
2. Seen: a corrected image loses its prompt. In B-atlas-leaves/r001 and D-street/r001, prompt.txt holds only the last edit instruction (is_the_jobs false). Cause: INSTRUCTIONS.md "save the text you finally submitted". "Write only inside sheets/" leaves nowhere to save that file.
3. Seen: corrections undo a D job. The first D-street repaint kept the layout but added clouds, a palm and a terracotta roof on the library. Two corrections removed them and pulled the tree crown back towards the capture's; the filed image is close to the capture. Step 4 does not say whether to correct from the result or from Image 1.
4. Tested without harm: one session holds every image. "Image 1" was taken correctly at job 7, and the first neon job shows no low-poly carry-over. Untested: neutral.C-*, which have no references of their own.
5. "skip a job with a contradiction": many prompts have one; the agent skipped none. Narrow the rule to missing references and refusals.
6. "File it" (wrong shape) conflicts with the correction step. $CODEX_HOME is unset here. Pixel sizes are not honoured (1024 asked, 1254 returned), which undoes "5 canvas pixels".

## Prompts

- Neon, seen: A-great-tree has the layout, a grey backdrop and no text, but is near-photoreal, every leaf drawn, with heavy glow. The references are near-photoreal night scenes and Avoid never mentions photorealism; lamps "glowing" sits against Avoid "bloom". The atlas key, magenta, is the style's accent colour.
- D jobs: the additions trace to the prompt: Lighting asks for "a few faceted white clouds", and the palette lists every group (terracotta roofs, tram, water, umbrellas) whether or not the capture has it.
- E-bench, seen: it differs from the bench in A-seating; nothing ties an E sheet to its A sheet. Stage 1 "flat on the ground" also conflicts with "same footprint, main form".
- Pixel: "a soft contact shadow" against "blur, gradients"; "as large as its cell allows" against "read at a sprite's small size"; "night version… darkened towards navy" against "same parts and colours"; the references are eye-level paintings in fine pixels, not 2:1 dimetric; "a navy outline… round every sprite" also reaches 12 textures and boards that forbid borders.
- Signs: "Leave a plain band… for the game's own sign" (18 jobs) lacks the word "blank", so no blank rule or check is added. E jobs drop the rules, leaving the tram shelter's sign panel unguarded. Voxel references show "WORKSHOP" and "LIBRARY".
- Surfaces: "no shadows and no highlights" against "slight sheen" and "warm glints"; neon B-tex-wall-library "Pale smooth stone" against "a matte dark surface".
- Others: A-resident and A-agent-a1 (12 jobs): the backdrop line says "…sky or people" though the subject is one. A-low-planting: "exactly 4 objects" with "Two meadow clumps". Voxel C: "one grid" with 20 cm and 70 cm cubes.

## Fact and language

- README says "no caption comes along", but text does: low-poly topdown (W1, T1, L1, P1, S1, compass), street and diagonal (compass), conversation ("City Agent A1"); pixel gathering ("LIBRARY").
- Blocks of 5 pixels divide neither 1536 nor 1024.
- Pixel checks say "a simple game model could reproduce" (21 jobs).
- Pixel atlases: "four equal quarters Every sprite pixel" lacks a full stop.
- Tram: "in every style" cream with a coral stripe, against pixel "red and cream".

## Rewordings it proposed

1. Check: "The backdrop is plain grey with no scenery, floor line or people. A soft gradient or contact shadow is fine: do not spend a correction on it."
2. Step 4: "If the image you file came from a correction, the prompt file is the job's prompt followed by each correction in order. Save it outside the repository."
3. Step 4: "Correct a D- job by running it again from Image 1 with one added line, never by editing the result."
4. D palette: "Colours for what Image 1 already shows, and for nothing else: …"
5. Neon Avoid on design sheets: "photorealism, individually drawn leaves, glow spreading beyond a lamp, night surroundings, rain, wet reflections".

## What it found sound

`--check` passes; the README's counts add up; intake.py's commands and paths match INSTRUCTIONS.md; the tool saves PNG; every prompt carries the no-text clause.
