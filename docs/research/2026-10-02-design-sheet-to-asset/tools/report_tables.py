"""report_tables.py [FOLDER]: the report's tables, written from the result files, so that no figure in the report
is copied by hand. FOLDER holds out/, out-budget/ and bench/ (default: this script's parent's parent, the working
folder; give the record's folder to check the report against the files kept with it).

    python3 report_tables.py            # prints the tables as Markdown
    python3 report_tables.py --check README.md   # exit 1 if a table row is not in README.md as printed
    python3 report_tables.py --fill README.md    # writes each table into README.md, between its two marker lines
                                                 # <!-- table NAME --> and <!-- end table NAME -->; --names lists them
"""
import json
import sys
from pathlib import Path

args = [a for a in sys.argv[1:] if not a.startswith("--")]
check = sys.argv[sys.argv.index("--check") + 1] if "--check" in sys.argv else None
fill = sys.argv[sys.argv.index("--fill") + 1] if "--fill" in sys.argv else None
for given in (check, fill):
    if given in args:
        args.remove(given)
root = Path(args[0]) if args else Path(__file__).resolve().parent.parent
STYLE = {"lowpoly_tropical": "Low-poly", "neon_noir": "Neon", "anime_cel": "Anime", "solarpunk": "Solarpunk", "voxel": "Voxel"}
PIECE = {"bench": "bench", "cafe-chair": "café chair", "reading-chair": "reading chair", "great-tree": "great tree", "perch-seat": "perch seat"}
# The square's props (batch 01a), by family, in the order the report gives them.
FAMILY = [("Street trees and palms", {"street-tree-a": "street tree, large", "street-tree-b": "street tree, small", "palm-tall": "palm, tall", "palm-mid": "palm, middle", "palm-short": "palm, short"}),
          ("Terrace", {"cafe-table": "café table", "umbrella": "umbrella", "planter": "planter"}),
          ("Street fixtures", {"lamp-post": "lamp post", "bollard": "bollard", "railing": "railing", "railing post": "railing post"}),
          ("Low planting", {"shrub-round": "shrub, round", "shrub-leafy": "shrub, leafy", "flowerbed": "flowerbed"}),
          ("Water and shelter", {"fountain": "fountain", "tram-shelter": "tram shelter"})]
rows = []
starts = {}          # a table's name -> where its rows begin in `rows`


def table_named(name):
    """The rows written from here on, up to the next call, are the table NAME (for --fill)."""
    starts[name] = len(rows)


def mb(n):
    return f"{n / 1e3:.0f} kB" if n < 1e5 else f"{n / 1e6:.2f} MB" if n < 1e6 else f"{n / 1e6:.1f} MB"


def shape(rep):
    """How closely the piece keeps the generated shape: for a piece cut down, the distance 95% of its surface lies
    within; for one rebuilt from cubes, the cube."""
    if "cubes" in rep:
        layers = rep["cubes"]["layers"]
        return "cubes of " + " and ".join(f"{layer['grid_m']:g} m" for layer in layers)
    dev = rep["deviation"]
    return f"{dev['p95_mm']:.1f} mm" + (" (of the rebuilt surface)" if dev.get("measured_from") == "the rebuilt surface" else "")


def pieces(folder, last_heading, last):
    results = json.loads((root / folder / "results.json").read_text())
    rows.append(f"| Style | Piece | Triangles | Kit's limit | Kit's piece | Shape kept | Colour off the design | Design colours found | File | {last_heading} |")
    rows.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    for r in results:
        if r["asset"] not in PIECE:
            continue
        rep = json.loads((root / folder / r["style"] / f"{Path(r['file']).stem}.json").read_text())
        colour = rep.get("colour_delta_e")
        reached = rep.get("materials_reached")
        rows.append(f"| {STYLE[r['style']]} | {PIECE[r['asset']]} | {r['triangles']:,} | {r['budget']:,} | {r['kit_triangles']:,} | {shape(rep)} | "
                    f"{colour if colour is not None else 'not matched'} | {f'{reached * 100:.0f}%' if colour is not None else 'not matched'} | {mb(r['bytes'])} | {last(r)} |")
    rows.append("")
    return results


# ---- the pieces, the shape deciding their triangle count
table_named("first set")
results = pieces("out", "Size, parts and footprint as the kit's spec", lambda r: "yes" if not r["problems"] else "no: " + "; ".join(r["problems"]))

# ---- what is built: every piece by style, with its triangle count
table_named("what is built")
rows.append("| Piece | " + " | ".join(STYLE.values()) + " |")
rows.append("| --- |" + " --- |" * len(STYLE))
for names in [PIECE] + [n for _f, n in FAMILY]:
    for name, label in names.items():
        cells = []
        for style in STYLE:
            r = next((x for x in results if x["asset"] == name and x["style"] == style), None)
            cells.append(f"{r['triangles']:,}" if r else "none")
        if any(c != "none" for c in cells):
            rows.append(f"| {label[0].upper() + label[1:]} | " + " | ".join(cells) + " |")
rows.append("")

# ---- the same held to the kit's limit, where that differs
if (root / "out-budget" / "results.json").exists():
    table_named("held to the limit")
    pieces("out-budget", "Inside the kit's limit", lambda r: "yes" if not r["over_limit"] else "no")

# ---- the square's props, a table a family
def against_spec(r):
    if r["problems"]:
        return "no: " + "; ".join(r["problems"])
    off = [f"{axis} {v['got']:.2f} m for the spec's {v['spec']:.2f} m" for axis, v in (r.get("off_spec") or {}).items()]
    off += [d_.split(":")[0] for d_ in r.get("departures") or []]
    drawn = (r.get("planted") or {}).get("width_scale_in_game")
    if drawn and abs(drawn - 1.0) > 0.005:
        off.append(f"drawn {drawn:.2f} times as wide as built")
    return "yes" if not off else "yes, but " + "; ".join(off)


for family, names in FAMILY:
    mine = [r for r in results if r["asset"] in names]
    if not mine:
        continue
    table_named(family.lower())
    rows.append("| Style | Piece | Size (m) | Triangles | Kit's limit | Kit's piece | Colour off the design | File | Rules of the kit's spec met |")
    rows.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    for name in names:
        for r in mine:
            if r["asset"] != name:
                continue
            report_file = root / "out" / r["style"] / f"{Path(r['file']).stem}.json"
            rep = json.loads(report_file.read_text()) if report_file.exists() else {}
            colour = rep.get("colour_delta_e")
            rows.append(f"| {STYLE[r['style']]} | {names[name]} | {' by '.join(f'{v:.2f}' for v in r['size_m'])} | {r['triangles']:,} | {r['budget']:,} | {r['kit_triangles']:,} | "
                        f"{colour if colour is not None else ('as its panel' if not rep else 'not matched')} | {mb(r['bytes'])} | {against_spec(r)} |")
    rows.append("")

# ---- colour: where a piece's colours were changed on purpose after the match, the figure before that
changed = []
for r in results:
    if r["asset"] not in PIECE:
        continue
    rep = json.loads((root / "out" / r["style"] / f"{Path(r['file']).stem}.json").read_text())
    was = rep.get("colour_as_matched")
    if was:
        changed.append(f"| {STYLE[r['style']]} | {PIECE[r['asset']]} | {was['colour_delta_e']} | {was['materials_reached'] * 100:.0f}% | {rep['colour_delta_e']} | {rep['materials_reached'] * 100:.0f}% | {was['share_of_texels_changed_since'] * 100:.0f}% |")
if changed:
    table_named("colour as matched")
    rows.append("| Style | Piece | As matched: colour off the design | As matched: design colours found | Finished | Finished: found | Texels changed after the match |")
    rows.append("| --- | --- | --- | --- | --- | --- | --- |")
    rows += changed
    rows.append("")

# ---- the game's own collision audit, with the kit's pieces and with the new ones in place
audits = {}
for label, folder in (("kit", "audit-kit"), ("new", "audit"), ("all", "audit-props")):
    for style in STYLE:
        f = root / "out" / folder / style / "report.json"
        if f.exists():
            rep = json.loads(f.read_text())
            audits.setdefault(style, {})[label] = [rep[g]["count"] for g in ("through", "within_10cm", "reverse_blocked")]
if audits:
    table_named("audit")
    rows.append("| Style | Kit's pieces: through, within 10 cm, blocked and bare | The seats and great tree new | Every built piece in place |")
    rows.append("| --- | --- | --- | --- |")
    for style, v in audits.items():
        rows.append(f"| {STYLE[style]} | " + " | ".join(", ".join(str(n) for n in v[label]) if label in v else "not run" for label in ("kit", "new", "all")) + " |")
    rows.append("")

# ---- how the game placed them
table_named("scales")
rows.append("| Style | Piece | Scale the game gave it (width, depth) |")
rows.append("| --- | --- | --- |")
for r in results:
    if "game_scale" in r and r["asset"] in PIECE:
        rows.append(f"| {STYLE[r['style']]} | {PIECE[r['asset']]} | {r['game_scale'][0]:.3f}, {r['game_scale'][1]:.3f} |")
rows.append("")

# ---- the seats' heights
seats = root / "out" / "seat-heights.txt"
if seats.exists():
    found = {}
    for line in seats.read_text().splitlines():
        if not line.startswith("SEAT "):
            continue
        label, rest = line[5:].split(": ", 1)
        which, style, key = label.split("+")
        found.setdefault((style, key), {})[which] = rest.split(" m,")[0].replace("top of the seat ", "")
    table_named("seat tops")
    rows.append("| Style | Seat | Kit's seat top | New seat top |")
    rows.append("| --- | --- | --- | --- |")
    for (style, key), v in found.items():
        rows.append(f"| {STYLE[style]} | {PIECE[key]} | {v.get('kit')} m | {v.get('new')} m |")
    rows.append("")

# ---- frame time: each style on its own, in the order kit, new, new, kit; one table a run
order = ("kit-1", "new-1", "new-2", "kit-2")
for folder in ("evening", "trees-only", "trees-far-swap", "noon"):   # the afternoon's run has its table in its own README
    table = {}
    for style in STYLE:
        files = {run: root / "bench" / folder / f"{run.split('-')[0]}-{style}-{run.split('-')[1]}.json" for run in order}
        if not all(f.exists() for f in files.values()):
            continue
        for run, f in files.items():
            for r in json.loads(f.read_text())["results"]:
                table.setdefault((style, r["scene"]), {})[run] = r["p50"]
    if table:
        table_named(f"frame time {folder}")
        rows.append("| Scene | Kit, first | New, first | New, second | Kit, second | New less kit |")
        rows.append("| --- | --- | --- | --- | --- | --- |")
        for (style, scene), v in table.items():
            diff = (v["new-1"] + v["new-2"]) / 2 - (v["kit-1"] + v["kit-2"]) / 2
            rows.append(f"| {STYLE[style]}, {scene} | {v['kit-1']:.2f} | {v['new-1']:.2f} | {v['new-2']:.2f} | {v['kit-2']:.2f} | {diff:+.2f} ms |")
        rows.append("")

# ---- the first batch's runs: the card cooler, two styles, kit and new in turn
morning = root / "bench" / "night"                       # the first batch's runs, taken in the night
labels = ("today-1", "today-2", "new-1", "new-2")
if all((morning / f"{label}.json").exists() for label in labels):
    table = {}
    for label in labels:
        for r in json.loads((morning / f"{label}.json").read_text())["results"]:
            table.setdefault((r["style"], r["scene"]), {})[label] = r["p50"]
    table_named("frame time night")
    rows.append("| Scene | Kit, run 1 | Kit, run 2 | New, run 1 | New, run 2 |")
    rows.append("| --- | --- | --- | --- | --- |")
    for (style, scene), v in table.items():
        rows.append(f"| {STYLE[style]}, {scene} | {v['today-1']:.2f} | {v['today-2']:.2f} | {v['new-1']:.2f} | {v['new-2']:.2f} |")
    temps = [(morning / f"{label}.temperature.txt") for label in ("today-1", "new-1", "today-2", "new-2")]
    if all(t.exists() for t in temps):
        rows.append("")
        rows.append("Graphics card after each of those runs, in the order they ran (kit, new, kit, new): " + ", ".join(t.read_text().strip() + " °C" for t in temps) + ".")
    rows.append("")

# ---- the great tree against its concept sheet
metrics = root / "out" / "tree-metrics.txt"
if metrics.exists():
    values, style = {}, None
    for line in metrics.read_text().splitlines():
        if not line.startswith(" "):
            style = line.strip()
        elif "distance from the sheet" in line:
            values.setdefault(style, {})[line.split("contrast")[0].strip()] = line.rsplit(" ", 1)[1]
    table_named("tree measures")
    rows.append("| Style | Kit's tree | Pilot round 2 | From the first sheet | Held to the kit's limit | New |")
    rows.append("| --- | --- | --- | --- | --- | --- |")
    for style, v in values.items():
        rows.append(f"| {STYLE[style]} | {v.get('today', 'not captured')} | {v.get('round 2', 'not captured')} | {v.get('first sheet', 'none')} | {v.get('at the limit', 'none')} | {v.get('new', 'not captured')} |")
    rows.append("")

order = sorted(starts, key=starts.get)
blocks = {}
for i, name in enumerate(order):
    end = starts[order[i + 1]] if i + 1 < len(order) else len(rows)
    block = rows[starts[name]:end]
    while block and not block[-1]:
        block.pop()
    blocks[name] = block
if "--names" in sys.argv:
    print("\n".join(order))
    sys.exit(0)
if fill:
    text = Path(fill).read_text()
    missing = []
    for name, block in blocks.items():
        a, b = f"<!-- table {name} -->", f"<!-- end table {name} -->"
        if a not in text or b not in text:
            missing.append(name)
            continue
        head, rest = text.split(a, 1)
        _old, tail = rest.split(b, 1)
        text = head + a + "\n" + "\n".join(block) + "\n" + b + tail
    Path(fill).write_text(text)
    print(f"{len(blocks) - len(missing)} tables written into {fill}" + (f"; no markers for: {', '.join(missing)}" if missing else ""))
    sys.exit(0)
if check:
    text = Path(check).read_text()
    missing = [row for row in rows if row and row not in text]
    for row in missing:
        print("not in the report as the files give it:", row)
    print(f"{len([r for r in rows if r]) - len(missing)} of {len([r for r in rows if r])} table rows agree with the files")
    sys.exit(1 if missing else 0)
print("\n".join(rows))
