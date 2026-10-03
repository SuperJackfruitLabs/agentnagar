#!/usr/bin/env python3
"""Files generated images with their records, and reports what is done.

    python3 tools/intake.py add JOB IMAGE [--correction TEXT] [--prompt-file FILE] [--generator TEXT] [--source TEXT]
    python3 tools/intake.py folder DIR            # add every DIR/<job>.png (for images made by hand in ChatGPT)
    python3 tools/intake.py status [BATCH]
    python3 tools/intake.py check [BATCH]
    uv run --with pillow python3 tools/intake.py contact BATCH

add       copies IMAGE to sheets/<style>/<item>/rNNN/image.png, taking the next free revision (nothing is ever
          overwritten), and writes beside it the prompt (prompt.txt: the job's own; with --correction, the job's
          own followed by the correction asked for after looking at a first result; or FILE's text if a wholly
          different prompt was submitted), the record (generation.json: hashes, size, references, generator) and
          a review sheet with the job's checks to fill in (review.md). A record's `is_the_jobs` says the prompt
          was the job's on the day it was filed; a job revised later differs from it.
status    one line a job: its latest revision, or "to do".
check     verifies every record: the image and prompt match their hashes, the image has the job's shape, the
          references it names exist, and its review names no file by a path under a home directory. Exits 1 on
          a fault.
contact   lays a batch's latest images out on one sheet a style, for looking through: sheets/contact-<batch>-<style>.jpg.

Everything except `contact` needs only the standard library.
"""
import hashlib
import json
import re
import shutil
import struct
import sys
from datetime import date
from pathlib import Path

HERE = Path(__file__).resolve().parent
PACK = HERE.parent
GENERATOR = "OpenAI image generation through ChatGPT or Codex (built-in image_gen); model not recorded"
# These records are meant for a public repository: no path that names a person's machine.
LOCAL_PATH = re.compile(r"(/home/|/Users/|[A-Za-z]:\\\\Users)")


def jobs():
    path = PACK / "jobs" / "jobs.json"
    if not path.exists():
        sys.exit("jobs/jobs.json is missing: run python3 tools/build_jobs.py")
    return {j["id"]: j for j in json.loads(path.read_text())["jobs"]}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", head[16:24])


def revisions(job):
    folder = PACK / job["out"]
    return sorted(p for p in folder.glob("r[0-9][0-9][0-9]") if (p / "image.png").exists()) if folder.exists() else []


def shape_fault(size, wanted):
    """Why an image of `size` does not suit a job that asked for `wanted`, or None. The generator chooses
    its own pixel size, so only the shape is held to: the aspect within 4%."""
    aspect, want = size[0] / size[1], wanted[0] / wanted[1]
    if abs(aspect / want - 1) > 0.04:
        return f"it is {size[0]} x {size[1]} (aspect {aspect:.2f}); the job asks for {wanted[0]} x {wanted[1]} (aspect {want:.2f})"
    return None


def resolved(path):
    """A reference path with LATEST in it, pointed at the newest revision there is (unchanged if there is none)."""
    if "/LATEST/" not in path:
        return path
    folder = (PACK / path).parents[1]
    revs = sorted(p for p in folder.glob("r[0-9][0-9][0-9]") if (p / "image.png").exists())
    return path.replace("LATEST", revs[-1].name) if revs else path


def add(job_id, image, prompt_file=None, generator=GENERATOR, source=None, correction=None):
    table = jobs()
    if job_id not in table:
        sys.exit(f"no such job: {job_id} (see JOBS.md)")
    job = table[job_id]
    image = Path(image)
    if not image.exists():
        sys.exit(f"no such file: {image}")
    size = png_size(image)
    if size is None:
        sys.exit(f"{image} is not a PNG. Save or convert it to PNG first.")
    done = revisions(job)
    number = int(done[-1].name[1:]) + 1 if done else 1
    folder = PACK / job["out"] / f"r{number:03d}"
    folder.mkdir(parents=True)
    shutil.copyfile(image, folder / "image.png")
    submitted = Path(prompt_file).read_text() if prompt_file else job["prompt"]
    if correction:
        submitted = submitted.rstrip("\n") + "\n\nCorrection asked for after looking at the first result:\n" + correction.strip() + "\n"
    (folder / "prompt.txt").write_text(submitted)
    up = "../" * len((Path(job["out"]) / "r001").parts)
    record = {
        "schema_version": 1,
        "job": job_id,
        "created": date.today().isoformat(),
        "generator": generator,
        "sha256": sha(folder / "image.png"),
        "width": size[0],
        "height": size[1],
        "prompt": {"status": "saved", "path": "prompt.txt", "sha256": sha(folder / "prompt.txt"),
                   "is_the_jobs": submitted == job["prompt"], "correction": correction},
        "source_paths": [source or image.name],
        "reference_images": [up + resolved(path) for path, _ in job["refs"]],
        "edit_of": up + job["refs"][0][0] if job["edit"] else None,
    }
    (folder / "generation.json").write_text(json.dumps(record, indent=2) + "\n")
    fault = shape_fault(size, job["size"])
    review = ["# Revision review", "", "AI-generated image. Filed, not approved: a filed image is a candidate until the owner accepts it.", "",
              f"Job: `{job_id}` ({job['title']}; {job['kind']}).", "",
              "## The job's checks", "", "Tick what holds in this image, and say under Findings what does not.", ""]
    review += [f"- [ ] {c}" for c in job["checks"]]
    review += ["", "## Findings", "", ("- Shape: " + fault + "." if fault else "- (none written yet)"), ""]
    (folder / "review.md").write_text("\n".join(review))
    print(f"{job_id}: filed as {folder.relative_to(PACK)}/image.png ({size[0]} x {size[1]})" + (f"; NOTE: {fault}" if fault else ""))
    print(f"  now look at it and fill in {folder.relative_to(PACK)}/review.md")
    return folder


def folder(directory, generator):
    table = jobs()
    found = 0
    for path in sorted(Path(directory).glob("*.png")):
        if path.stem in table:
            add(path.stem, path, generator=generator, source=path.name)
            found += 1
        else:
            print(f"skipped {path.name}: its name is not a job id")
    print(f"{found} images filed from {directory}")


def selected(table, batch):
    return [j for j in table.values() if batch is None or j["batch"] == batch]


def status(batch):
    table = jobs()
    mine = selected(table, batch)
    done = 0
    for job in mine:
        revs = revisions(job)
        if revs and job.get("redo") and len(revs) == 1:
            print(f"{job['batch']}  {job['id']:44s} to do again (it has {revs[-1].name}): {job['redo']}")
        elif revs:
            done += 1
            size = png_size(revs[-1] / "image.png")
            print(f"{job['batch']}  {job['id']:44s} {revs[-1].name}  {size[0]} x {size[1]}" + (f"  ({len(revs)} revisions)" if len(revs) > 1 else ""))
        else:
            print(f"{job['batch']}  {job['id']:44s} to do")
    print(f"{done} of {len(mine)} done")


def check(batch):
    table = jobs()
    faults = 0
    seen = 0
    for job in selected(table, batch):
        for rev in revisions(job):
            seen += 1
            where = f"{rev.relative_to(PACK)}"
            try:
                record = json.loads((rev / "generation.json").read_text())
            except (OSError, ValueError) as error:
                print(f"{where}: no readable record ({error})"); faults += 1
                continue
            problems = []
            if record.get("sha256") != sha(rev / "image.png"):
                problems.append("the image does not match its recorded hash")
            if not (rev / "prompt.txt").exists() or record.get("prompt", {}).get("sha256") != sha(rev / "prompt.txt"):
                problems.append("the prompt is missing or does not match its recorded hash")
            size = png_size(rev / "image.png")
            if size is None:
                problems.append("the image is not a PNG")
            else:
                if [record.get("width"), record.get("height")] != list(size):
                    problems.append("the recorded size is not the image's")
                fault = shape_fault(size, job["size"])
                if fault:
                    problems.append(fault)
            if not (rev / "review.md").exists():
                problems.append("no review.md")
            elif LOCAL_PATH.search((rev / "review.md").read_text()):
                problems.append("review.md names a file by a path under someone's home directory: give the file name only")
            for ref in record.get("reference_images", []):
                if not (rev / ref).exists():
                    problems.append(f"reference missing: {ref}")
            for problem in problems:
                print(f"{where}: {problem}")
            faults += len(problems)
    print(f"checked {seen} revisions: {faults} faults")
    sys.exit(1 if faults else 0)


def contact(batch):
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        sys.exit("contact sheets need Pillow: uv run --with pillow python3 tools/intake.py contact BATCH")
    table = jobs()
    by_style = {}
    for job in selected(table, batch):
        revs = revisions(job)
        if revs:
            by_style.setdefault(job["style"], []).append((job, revs[-1]))
    for style, items in by_style.items():
        cell_w, cell_h, label, cols = 512, 352, 20, 3
        rows = -(-len(items) // cols)
        sheet = Image.new("RGB", (cols * cell_w, rows * (cell_h + label)), (40, 40, 44))
        draw = ImageDraw.Draw(sheet)
        for k, (job, rev) in enumerate(items):
            image = Image.open(rev / "image.png").convert("RGB")
            image.thumbnail((cell_w - 8, cell_h - 8))
            x, y = (k % cols) * cell_w, (k // cols) * (cell_h + label)
            draw.text((x + 4, y + 4), f"{job['item']}  {rev.name}", fill=(230, 230, 230))
            sheet.paste(image, (x + 4, y + label + 4))
        out = PACK / "sheets" / f"contact-{batch}-{style}.jpg"
        sheet.save(out, quality=88)
        print(f"contact: {out.relative_to(PACK)} ({len(items)} images)")
    if not by_style:
        print(f"contact: nothing filed yet in {batch}")


def option(argv, name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default


def main(argv):
    if not argv:
        sys.exit(__doc__)
    command = argv[0]
    if command == "add" and len(argv) >= 3:
        add(argv[1], argv[2], option(argv, "--prompt-file"), option(argv, "--generator", GENERATOR), option(argv, "--source"), option(argv, "--correction"))
    elif command == "folder" and len(argv) >= 2:
        folder(argv[1], option(argv, "--generator", GENERATOR))
    elif command == "status":
        status(argv[1] if len(argv) > 1 else None)
    elif command == "check":
        check(argv[1] if len(argv) > 1 else None)
    elif command == "contact" and len(argv) >= 2:
        contact(argv[1])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
