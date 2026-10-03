# Instructions for the image agent

You are making concept images for Agentnagar, a city game with six art styles. Each image is one **job**. A job file tells you which reference images to load, the exact prompt to submit, and what to look for before you save. Your work is to run the jobs of one batch faithfully, look at every result, file it, and report. You do not design anything: the prompts are already written.

These instructions are for an agent that can read files, load images into its context and generate images with its built-in image tool, such as Codex with the `imagegen` skill. If you are a person using ChatGPT in a browser, see [By hand in ChatGPT](#by-hand-in-chatgpt).

Work from this folder. Every path below is relative to it:

```sh
cd docs/vision/asset-studies
```

## Before you start

1. Read this file to the end.
2. Check that the pack is whole:

   ```sh
   python3 tools/build_jobs.py --check
   ```

   It must end with "every reference image present". If it does not, stop and report what it printed.
3. Know which batch you were asked to do. If nobody named one, do the first batch in [JOBS.md](JOBS.md) that still has jobs to do, and nothing else. To see what is left in a batch:

   ```sh
   python3 tools/intake.py status <batch>
   ```

## One job, step by step

Do the jobs one at a time, in the order `status` lists them. For each job:

1. **Open its file**: `jobs/<batch>/<job>.md`.
2. **Load its reference images** with `view_image`, in the order the file lists them, immediately before generating. The prompt calls them Image 1, Image 2 and so on, so the order matters. A job that lists none has none.
   - A life-cycle job (`.E-`) also lists its object's design sheet, with `LATEST` in the path: load the newest revision of that sheet (the highest `rNNN` folder). If the sheet has no image yet, skip the job and say so.
   - A job file with an "Asked for again" section has an image already. Make a new one all the same: it becomes the next revision.
3. **Generate one image** with the built-in image tool, using the text in the job's "Prompt" block exactly as it is written.
   - Most jobs are new images made with style references. The job file says so.
   - Jobs whose id has `.D-` are edits: Image 1 is the edit target, and the result must keep its layout.
4. **Look at the result** and go through the job's "Before saving" list honestly.
   - If a check fails, make one correction and look again. Say only what must change, and repeat what must stay. At most two corrections for a job.
   - A soft gradient in a grey backdrop is fine. Do not spend a correction on making a backdrop flatter.
   - To correct a `.D-` job, do not edit your own result: generate again from Image 1 (the capture) with the job's prompt and one added sentence that says what must change.
   - File a corrected image with `--correction "<what you asked for>"` in step 5. The record then keeps the job's prompt and your correction together. Use `--prompt-file` only if you submitted a wholly different text.
   - If it still fails after two corrections, file the best attempt anyway and write down what is wrong. A filed image with an honest fault list is more use than a missing one.
5. **File it.** Find the generated file (the built-in tool saves under `$CODEX_HOME/generated_images/`) and run the command at the end of the job file:

   ```sh
   python3 tools/intake.py add <job> <path-to-the-generated-image> [--correction "<text>"] [--prompt-file <file>] [--generator "<tool and model, if you know them>"]
   ```

   It copies the image to `sheets/<style>/<item>/rNNN/image.png` and writes the prompt and the record beside it. It never overwrites: a second image for the same job becomes the next revision.
6. **Fill in the review** that step 5 created (`sheets/.../rNNN/review.md`): tick each check that holds, and under Findings write plainly what does not hold and anything else you noticed. Do not write that an image is approved. Only the owner approves.

## Rules

- **Use the built-in image tool only.** Do not use an API key, the skill's CLI fallback or any paid service. If the built-in tool is not available, stop and say so.
- **Do not rewrite the prompts.** Do not shorten them, add ideas of your own, or merge two jobs into one image. They are already detailed, so pass them through as they are.
- **One image for each job**, and the references every time. Do not reuse the references of an earlier job from memory.
- **No text in the images.** Every prompt asks for none. If letters, numbers or labels appear, that is a failed check: correct it or note it.
- **Write only inside `sheets/`**, and only through `tools/intake.py` and the `review.md` files. Do not edit job files, `data/`, `tools/` or `refs/`. If a job looks wrong (a contradiction, a missing reference), skip it and report it; do not repair it.
- **No paths from your machine in what you write.** In a review, name a generated file by its file name (`exec-….png`), not by its full path: these records go into a public repository, and `check` reports a path under a home directory as a fault.
- **Leave the rest of the repository alone.** Do not commit, push, build or run the game.
- **Stop at the end of the batch.** Do not start another batch unasked.

## When the batch is done

```sh
python3 tools/intake.py status <batch>      # every job done, or the reason it is not
python3 tools/intake.py check <batch>       # must report 0 faults, apart from shapes you have already noted
uv run --with pillow python3 tools/intake.py contact <batch>     # one sheet a style, for looking through
```

The last command needs the Pillow library. If it cannot be had, skip it and say so.

Then report, briefly:

- how many jobs were filed, and which were skipped or needed corrections, with the reason;
- the faults you wrote in the reviews, grouped by kind (text appeared, wrong layout, style drifted, layout of an edit moved, and so on);
- where the contact sheets are (`sheets/contact-<batch>-<style>.jpg`);
- which tool and model made the images, if you know.

## What the kinds of job are for

Knowing the purpose helps you judge a result.

| Id | Kind | What it is for | The check that matters most |
| --- | --- | --- | --- |
| `A-` | Design sheet | The image a 3D model is made from (its large three-quarter view goes through an image-to-3D model) and the source its colours are measured from | The object alone on a plain backdrop, whole and clear of its neighbours, in the style of the references; in the night style, in neutral light |
| `B-materials-` | Material board | Six flat samples of surfaces, to read colours and surface treatment from | Six flat tiles, no objects |
| `B-tex-` | Tiling texture | A surface that repeats without a seam | Edges that would meet without a join |
| `B-atlas-` | Cut-out atlas | Leaf and plant pieces to cut out and use on foliage | Four separate pieces on one flat key colour |
| `C-` | Shape | The input of an image-to-3D model, which needs one plain object | One whole object, plain, like a 3D model in a viewer |
| `D-` | Frame | A capture of the game repainted in the style: a like-for-like picture of where the game should get to | Nothing moved: buildings, tree, lamps and benches where the capture has them |
| `E-` | Life-cycle sheet | One asset at three stages, for showing construction and age in the game | The same object three times, the middle one the object on its design sheet |

## By hand in ChatGPT

Without file access the same jobs can be run by a person:

1. Open the job file and upload its reference images to the chat, in the listed order.
2. Paste the job's prompt as the message.
3. Check the result against the job's list, ask for a correction if needed, and download the image as a PNG named after the job, for example `lowpoly_tropical.A-great-tree.png`.
4. Put the downloads in one folder and run `python3 tools/intake.py folder <that folder>`. It files every image whose name is a job id. Then fill in each `review.md`.

## If something goes wrong

- **The tool refuses a prompt.** Do not reword it to get round the refusal. Skip the job and report the refusal's wording.
- **The image comes back a different shape** (square where the job asks for landscape). File it; `intake.py` notes the shape in the review. Mention it in your report.
- **The tool will not take all the references.** Use them in the listed order as far as it allows, and say in the review which were left out.
- **You run out of usage partway.** Stop. `status` shows what remains, and the batch can be resumed later from there.
