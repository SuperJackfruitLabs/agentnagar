"""make_record.py RECORD_DIR [--dry]: writes the research record's files from the working folder.

The working folder (this script's parent's parent) holds everything the work made; the record keeps the part of
it a reader needs: the tools, the built pieces and their reports, the result files, the frame-time runs, the
notes and the pictures. This copies each of those into RECORD_DIR, replacing what is there, and leaves alone
what the record alone holds (its README.md, WORKFLOW.md and REUSE notes are written from record-draft/, its
`inputs/` and the two notes written only there stay as they are).

    venv/bin/python work/make_record.py /path/to/agentnagar/docs/research/2026-10-02-design-sheet-to-asset

Pictures are written as JPEG (quality 86, at most 2,800 pixels wide). Notes are copied with the laptop's own
paths taken out. Tables in README.md are filled from the result files (report_tables.py --fill), and the page is
then checked against them (--check).
"""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

W = Path(__file__).resolve().parent.parent
args = [a for a in sys.argv[1:] if not a.startswith("--")]
if not args:
    sys.exit(__doc__)
R = Path(args[0]).resolve()
DRY = "--dry" in sys.argv
STYLES = ("lowpoly_tropical", "neon_noir", "anime_cel", "solarpunk", "voxel")
FAMILIES = ("trees", "terrace", "fixtures", "planting", "water")
done = []


def note(text):
    done.append(text)


def fresh(folder):
    """An empty folder of that name in the record."""
    if not DRY:
        shutil.rmtree(R / folder, ignore_errors=True)
        (R / folder).mkdir(parents=True)


def copy(src, dst):
    if not DRY:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)


def jpeg(src, dst, widest=2800):
    if not src.exists():
        return False
    if not DRY:
        dst.parent.mkdir(parents=True, exist_ok=True)
        im = Image.open(src)
        if im.mode in ("RGBA", "LA", "P"):
            back = Image.new("RGB", im.size, (255, 255, 255))
            back.paste(im.convert("RGBA"), mask=im.convert("RGBA").split()[3])
            im = back
        im = im.convert("RGB")
        if im.width > widest:
            im = im.resize((widest, round(im.height * widest / im.width)), Image.LANCZOS)
        im.save(dst, quality=86, optimize=True)
    return True


def stack(sources, dst):
    """Several sheets one under another, as one picture."""
    ims = [Image.open(s).convert("RGB") for s in sources if s.exists()]
    if not ims:
        return False
    if not DRY:
        sheet = Image.new("RGB", (max(i.width for i in ims), sum(i.height for i in ims) + 8 * (len(ims) - 1)), (245, 244, 238))
        y = 0
        for i in ims:
            sheet.paste(i, (0, y))
            y += i.height + 8
        tmp = dst.with_suffix(".stack.png")
        dst.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(tmp)
        jpeg(tmp, dst)
        tmp.unlink()
    return True


OWN = "/" + "home/"          # written apart, so that this file does not hold what it looks for
HOME = re.compile(OWN + r"[A-Za-z0-9_.-]+/Projects/superjackfruit/agentnagar")
HOME_ANY = re.compile(OWN + r"[A-Za-z0-9_.-]+/Projects/superjackfruit")
A_PATH = re.compile(OWN + r"[A-Za-z0-9_.-]+/")          # a path under someone's home, not the word in a sentence


def scrub(text):
    """A note without the laptop's own paths: the checkout is `agentnagar`, the workspace beside it `..`."""
    text = HOME.sub("agentnagar", text)
    return HOME_ANY.sub("..", text)


# ---- tools (not the night's one-off queue, which names its files by this laptop's paths, nor two throwaway probes)
LEFT_OUT = ("queue1.sh", "try_decimate.py", "show_bright.py")
fresh("tools")
n = 0
for f in sorted((W / "work").iterdir()):
    if f.is_file() and f.suffix in (".py", ".sh", ".gd", ".cjs", ".json", ".txt") and f.name not in LEFT_OUT:
        copy(f, R / "tools" / f.name)
        n += 1
note(f"tools/: {n} files")

# ---- the pieces and their reports (textures are inside the files)
# Result files of earlier hours that a later run replaced under another name, and that no page speaks of.
SUPERSEDED = ("check-all.txt", "check-budget.txt", "game-tests-collision-pack-plant-frame_cost.txt")
for folder in ("out", "out-budget", "out-first-sheet", "out-worn", "out-kit-green", "out-leaves"):
    if not (W / folder).exists():
        continue
    fresh(folder)
    n = 0
    for style in STYLES:
        for f in sorted((W / folder / style).glob("*")) if (W / folder / style).is_dir() else []:
            if f.suffix == ".glb" or (f.suffix == ".json" and not f.name.endswith(".cubes.json")):
                copy(f, R / folder / style / f.name)
                n += f.suffix == ".glb"
    for f in sorted((W / folder).glob("*.json")) + sorted((W / folder).glob("*.txt")):
        if f.name not in SUPERSEDED:
            copy(f, R / folder / f.name)
    note(f"{folder}/: {n} pieces")
# the game's audit: each run's report, by style
for run in ("audit-kit", "audit", "audit-props"):
    for style in STYLES:
        f = W / "out" / run / style / "report.json"
        if f.exists():
            copy(f, R / "out" / run / style / "report.json")

# ---- the frame-time runs
fresh("bench")
RUNS = ("evening", "trees-only", "trees-far-swap", "trees-as-far-twins", "afternoon", "trees-only-disturbed", "noon", "night", "five-in-one-run")          # not the night's three early sets
for run in sorted(p for p in (W / "bench").iterdir() if p.is_dir() and p.name in RUNS):
    kept = 0
    for f in sorted(run.iterdir()):
        if f.suffix in (".json", ".txt", ".md"):
            copy(f, R / "bench" / run.name / f.name)
            kept += 1
    note(f"bench/{run.name}/: {kept} files")

# ---- notes: the working folder's, with the two the record alone holds left where they are
(R / "notes").mkdir(exist_ok=True)
for f in sorted((W / "notes").glob("*.md")):
    if not DRY:
        (R / "notes" / f.name).write_text(scrub(f.read_text()))
if not DRY:
    shutil.rmtree(R / "notes" / "contracts", ignore_errors=True)
    (R / "notes" / "contracts").mkdir()
for f in sorted((W / "notes" / "contracts").glob("*.md")):
    text = scrub(f.read_text())
    head, _, rest = text.partition("\n")
    by = "\nWritten by Claude (an AI agent) from the game's code; nothing was run and nothing changed. It was the brief for the build of this family. Paths beginning `work/` are the record's `tools/`.\n"
    if not DRY:
        (R / "notes" / "contracts" / f.name).write_text(head + "\n" + by + rest)
note(f"notes/: {len(list((W / 'notes').glob('*.md')))} notes and {len(list((W / 'notes' / 'contracts').glob('*.md')))} contract notes")

# ---- the families' pages: the coordinating session's own, and each build agent's report with what the game
# showed of its pieces afterwards and the agent's follow-up report under it
fresh("families")
for f in sorted((W / "record-draft" / "families").glob("*.md")):
    if not DRY:
        (R / "families" / f.name).write_text(scrub(f.read_text()))
AGENTS = {          # page: (the agent's folder, its previews in the record, its later reports)
    "terrace.md": ("terrace", "terrace", ["agents/terrace2/REPORT.md"]),
    "fountain-and-shelter.md": ("fountain-shelter", "fountain-shelter", ["agents/fountain-shelter/REPORT-2.md"]),
    "street-fixtures.md": ("fixtures", "fixtures", []),
    "low-planting.md": ("planting", "planting", ["agents/planting/REPORT-2.md"]),
}
pages = len(list((W / "record-draft" / "families").glob("*.md")))
for page, (folder, shown, later) in AGENTS.items():
    report = W / "agents" / folder / "REPORT.md"
    if not report.exists():
        continue
    title, _, body = report.read_text().partition("\n")
    where = (f"\n> In this record the pieces are in `out/<style>/`, the agent's own preview sheets are in `previews/{shown}/` (as JPEG) and its tools are merged into `tools/`. "
             f"Where the report names `work/`, `base/`, `logs/`, `scratch/`, `out/` or `previews/`, it means the agent's own folder in the working folder (`agents/{folder}/`), "
             "of which only the pieces and the previews are kept here. The report is as the agent gave it; what happened afterwards is at the end.\n")
    text = title + "\n" + where + body.rstrip() + "\n"
    addendum = W / "record-draft" / "addenda" / page
    if addendum.exists():
        text += "\n" + addendum.read_text().rstrip() + "\n"
    for extra in later:
        if (W / extra).exists():
            follow = (W / extra).read_text().rstrip()
            follow = "\n".join(("#" + line) if line.startswith("#") else line for line in follow.splitlines())      # one level down
            text += "\n" + follow + "\n"
    last = W / "record-draft" / "addenda" / (Path(page).stem + "-after.md")          # what the game showed of the follow-up
    if last.exists():
        text += "\n" + last.read_text().rstrip() + "\n"
    if not DRY:
        (R / "families" / page).write_text(scrub(text))
    pages += 1
note(f"families/: {pages} pages")

# ---- pictures
fresh("compare")
P = W / "previews"
made = 0
for style in STYLES:
    made += jpeg(P / f"town-{style}-before-after.png", R / "compare" / f"town-{style}.jpg")
    for family in FAMILIES:
        made += jpeg(P / f"compare-{style}-{family}.png", R / "compare" / f"{family}-{style}.jpg")
    made += jpeg(P / f"compare-{style}-seats.png", R / "compare" / f"seats-{style}.jpg")
    made += jpeg(P / f"compare-{style}-tree.png", R / "compare" / f"tree-{style}.jpg")
    made += jpeg(P / f"street-{style}.png", R / "compare" / f"street-{style}.jpg")
    made += jpeg(P / f"views-{style}.png", R / "compare" / f"views-{style}.jpg")
made += stack([P / f"compare-{s}-perch.png" for s in ("anime_cel", "solarpunk", "voxel")], R / "compare" / "perch-seats.jpg")
made += jpeg(P / "sitters.png", R / "compare" / "sitters.jpg")
made += jpeg(P / "limit.png", R / "compare" / "limit.jpg")
note(f"compare/: {made} sheets")

# previews: the record's earlier ones stay; these are added or replaced
extra = {
    "seats-normals-before-after.jpg": W / "scratch/normals-round/seats-normals.png",
    "neon-seats-neutral-light.jpg": P / "neon-seats-neutral-light.png",
    "voxel-street-trees.jpg": W / "scratch/regen/vx-trees.png",
    "planted-anime_cel-lift.jpg": P / "planted-anime_cel-lift.png",
    "planted-solarpunk-lift.jpg": W / "scratch/blossom/town-solarpunk-lift.png",
    "planted-neon_noir-lift.jpg": W / "scratch/blossom/town-neon-lift.png",
    "street-tree-blossoms.jpg": W / "scratch/blossom/blossoms.png",
    "neon-leaf-roughness.jpg": W / "scratch/final-look/neon-leaf-roughness.png",
    "lowpoly-trees-full-and-far.jpg": P / "lowpoly-trees-full-and-far.png",
    "lowpoly-far-twins-close.jpg": W / "scratch/final-look/lowpoly-far-twins-close.png",
    "solarpunk-cafe-chair-seat.jpg": W / "scratch/final-look/solarpunk-cafe-chair-seat.png",
    "solarpunk-tree-foot-before-after.jpg": W / "scratch/final-look/solarpunk-tree-foot-before-after.png",
    "audit-reading-chair-kit-and-first.jpg": W / "scratch/audit/cells/kit-chair-bench.png",
    "audit-first-seats.jpg": W / "scratch/audit/cells/lowpoly-seats.png",
}
for style in STYLES:
    extra[f"planted-{style}-three-ways.jpg"] = P / f"planted-{style}-three-ways.png"
made = sum(jpeg(src, R / "previews" / name) for name, src in extra.items())
# the build agents' own sheets, a folder a family: the sheets, not the single tiles they are composed from
for family in ("terrace", "fountain-shelter", "fixtures", "planting"):
    if not (P / family).is_dir():
        continue
    if not DRY:
        shutil.rmtree(R / "previews" / family, ignore_errors=True)
    for f in sorted((P / family).rglob("*.png")):
        if any(mark in f.stem for mark in ("-kit-", "-new-")) or f.stem.endswith("-design"):
            continue
        made += jpeg(f, R / "previews" / family / f.relative_to(P / family).with_suffix(".jpg"), widest=2400)
    for f in sorted((P / family).rglob("*.txt")):
        if not DRY:
            dst = R / "previews" / family / f.relative_to(P / family)
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_text(scrub(f.read_text()))
note(f"previews/: {made} pictures added or replaced")

# ---- the timing log of the image-to-3D runs
if (W / "logs" / "gen3d-times.tsv").exists() and not DRY:
    # a line a run: when it ended, the model it wrote, seconds, exit code. The working folder's own path is taken off.
    (R / "notes" / "gen3d-times.tsv").write_text(scrub((W / "logs" / "gen3d-times.tsv").read_text().replace(str(W) + "/", "")))


# ---- figures the report quotes in its sentences, counted from the files ({{name}} in the draft)
def facts():
    f = {}
    results = json.loads((W / "out" / "results.json").read_text())
    first = ("bench", "cafe-chair", "reading-chair", "great-tree", "perch-seat")
    f["first_set_pieces"] = sum(1 for r in results if r["asset"] in first)
    f["prop_pieces"] = sum(1 for r in results if r["asset"] not in first and r["asset"] != "railing post")
    f["pieces"] = f["first_set_pieces"] + f["prop_pieces"]
    f["files"] = len(list((W / "out").glob("*/*.glb")))
    f["over_limit_first_set"] = sum(1 for r in results if r["asset"] in first and r["over_limit"])
    f["out_mb"] = f"{sum(p.stat().st_size for p in (W / 'out').glob('*/*.glb')) / 1e6:.0f}"
    f["kit_mb"] = f"{sum(r['kit_bytes'] for r in results) / 1e6:.1f}"
    f["new_mb"] = f"{sum(r['bytes'] for r in results) / 1e6:.0f}"                     # the same files as the kit's figure counts
    def span(rows, key="bytes"):
        v = [r[key] for r in rows]
        mb = lambda n: f"{n / 1e3:.0f} kB" if n < 1e5 else f"{n / 1e6:.2f} MB" if n < 1e6 else f"{n / 1e6:.1f} MB"
        return f"{mb(min(v))} to {mb(max(v))}" if v else "none"
    seats = [r for r in results if r["asset"] in ("bench", "cafe-chair", "reading-chair")]
    f["seat_size"] = span([r for r in seats if r["style"] != "voxel"])
    f["kit_seat_size"] = span([r for r in seats if r["style"] != "voxel"], "kit_bytes")
    f["tree_size"] = span([r for r in results if r["asset"] == "great-tree" and r["style"] != "voxel"])
    f["kit_tree_size"] = span([r for r in results if r["asset"] == "great-tree" and r["style"] != "voxel"], "kit_bytes")
    f["voxel_seat_size"] = span([r for r in seats if r["style"] == "voxel"])
    f["voxel_size"] = span([r for r in results if r["style"] == "voxel"])
    f["kit_voxel_size"] = span([r for r in results if r["style"] == "voxel"], "kit_bytes")
    f["prop_size"] = span([r for r in results if r["asset"] not in first and r["style"] != "voxel"])
    f["planted_triangles"] = "{:,} to {:,}".format(*(lambda v: (min(v), max(v)))([r["triangles"] for r in results if r.get("planted") and r["style"] != "voxel"]))
    validator = (W / "out" / "validator.txt")
    if validator.exists():
        lines = [l for l in validator.read_text().splitlines() if " errors, " in l]
        f["validated_files"] = len(lines)
        f["validated_clean"] = sum(1 for l in lines if " 0 errors, 0 warnings" in l)
    tests = W / "out" / "game-tests.txt"
    if tests.exists():
        m = re.search(r"PASS (\d+), FAIL (\d+)", tests.read_text())
        if m:
            f["tests_pass"], f["tests_fail"] = int(m.group(1)), int(m.group(2))
    audits = [json.loads(p.read_text()) for p in sorted((W / "out" / "audit-props").glob("*/report.json"))]
    f["audit_styles"] = len(audits)
    f["audit_all_zero"] = "zero" if audits and all(a[k]["count"] == 0 for a in audits for k in ("through", "within_10cm", "reverse_blocked")) else "NOT ZERO"
    times = W / "logs" / "gen3d-times.tsv"
    if times.exists():
        secs = sorted(float(l.split("\t")[2]) for l in times.read_text().splitlines() if len(l.split("\t")) > 2)
        f["gen_runs"], f["gen_min"], f["gen_max"] = len(secs), f"{secs[0]:.0f}", f"{secs[-1]:.0f}"
        f["gen_median"], f["gen_hours"] = f"{secs[len(secs) // 2]:.0f}", f"{sum(secs) / 3600:.1f}"
        f["gen_models"] = len({l.split("\t")[1] for l in times.read_text().splitlines() if len(l.split("\t")) > 2})
    f["models"] = len([p for p in (W / "raw").glob("*/*.glb")])
    # the design images made, and those a kept piece is built from
    config = json.loads((W / "work" / "assets.json").read_text())["assets"]
    sheets = Path(__import__("os").environ.get("AGENTNAGAR", str(W.parent.parent / "agentnagar"))) / "docs/vision/asset-studies/sheets"
    f["images_made"] = len(list(sheets.glob("*/*/r*/image.png")))
    used = set()
    for folder in ("out", "out-first-sheet", "out-worn"):
        for style in STYLES:
            names = {p.name for p in (W / folder / style).glob("*.glb")} if (W / folder / style).is_dir() else set()
            for a in config.values():
                own = a.get("style", {}).get(style, {})
                file = own.get("file", a.get("file"))
                variant = a.get("variant")
                if not file or style not in a.get("only", [style]) or (folder == "out") != (variant is None) or (variant and folder != "out-" + variant):
                    continue
                if Path(file).name in names:
                    used.add((style, a["sheet"], a.get("rev", {}).get(style, "r001")))
    f["images_used"] = len(used)
    return f


# ---- the report and the workflow
for name in ("README.md", "WORKFLOW.md"):
    src = W / "record-draft" / name
    if src.exists() and not DRY:
        text = scrub(src.read_text())
        known = facts()
        for token in sorted(set(re.findall(r"\{\{([a-z_]+)\}\}", text))):
            if token in known:
                text = text.replace("{{" + token + "}}", str(known[token]))
            elif token != "record_mb":
                note(f"{name}: no figure for {{{{{token}}}}}")
        (R / name).write_text(text)
if not DRY:
    r = subprocess.run([sys.executable, str(W / "work/report_tables.py"), str(R), "--fill", str(R / "README.md")], capture_output=True, text=True)
    note("README.md: " + (r.stdout.strip() or r.stderr.strip()[-300:]))
    r = subprocess.run([sys.executable, str(W / "work/report_tables.py"), str(R), "--check", str(R / "README.md")], capture_output=True, text=True)
    note("README.md checked against the record's own files: " + r.stdout.strip().splitlines()[-1])
    left = sorted(set(re.findall(r"\b[A-Z][A-Z_]{5,}\b", (R / "README.md").read_text())) - {"AGENTNAGAR", "STYLES", "PIECES", "CIELAB", "TRELLIS", "README", "WORKFLOW", "REUSE", "NVIDIA"})
    if left:
        note("README.md still has unfilled places: " + ", ".join(left))
    stray = [str(f.relative_to(R)) for f in R.rglob("*") if f.is_file() and f.suffix in (".md", ".json", ".txt", ".tsv", ".py", ".sh", ".gd", ".cjs", ".toml") and A_PATH.search(f.read_text(errors="ignore"))]
    if stray:
        note("files that still hold a path of this laptop's own: " + ", ".join(stray[:12]) + (" ..." if len(stray) > 12 else ""))
size = sum(f.stat().st_size for f in R.rglob("*") if f.is_file())
if not DRY and (R / "README.md").exists():
    (R / "README.md").write_text((R / "README.md").read_text().replace("{{record_mb}}", f"{size / 1e6:.0f}"))
note(f"the record is {size / 1e6:.0f} MB")
print("\n".join(done))
