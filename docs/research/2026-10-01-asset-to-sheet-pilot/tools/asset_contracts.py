"""asset_contracts.py CONFIG [VIEWS_DIR]: checks each style's built asset against what the kit and the game
hold it to.

  * The kit's own spec for the asset (city/tools/styles/<kit>/specs/*.json), by the kit tests' own rule
    (test_assets.py: each axis within 10% + 2 cm of the spec's size, triangles within its budget, its named
    nodes present).
  * For a piece the pack fits to its catalogue footprint (a style's `fill`), with the config's `footprint`
    ([x0, z0, x1, z1] in metres, Godot axes, about the piece's origin): what the piece draws where people walk,
    by the game's own measure (band.py), against it. A piece that reaches outside its footprint there is
    squeezed whole by the game, which is a failure. One that stays inside is stretched to it; that is
    reported, not failed (the kits' own pieces are stretched a few per cent too, and the game adds a little
    more by where the placement falls on its walking grid).
  * With VIEWS_DIR (asset_try.sh's captures of the built asset): the scale the game really gave it.

It reads built files from out-<asset>/<style>/. It does not run the kits' test suites (those test the files
in the repository) and does not measure frame time. Exits 1 if any piece misses its kit's spec or reaches
outside its footprint.
"""
import json
import os
import sys
from pathlib import Path

import band

W = Path(__file__).resolve().parent
AGENTNAGAR = Path(os.environ["AGENTNAGAR"])
STYLES = AGENTNAGAR / "city" / "tools" / "styles"
sys.path.insert(0, str(STYLES / "shared"))
sys.path.insert(0, str(STYLES / "lowpoly"))
import test_assets as kit_tests  # noqa: E402  (the low-poly kit's: its GLB readers are the ones every kit copies)

KIT = {"lowpoly_tropical": "lowpoly", "anime_cel": "anime", "solarpunk": "solarpunk", "neon_noir": "neon", "voxel": "voxel"}
config = json.load(open(sys.argv[1]))
views = sys.argv[2] if len(sys.argv) > 2 else None
name = config["asset"]
ok = True
for style, st in config["styles"].items():
    path = W / f"out-{name}" / style / os.path.basename(st["asset_file"])
    if style not in KIT or not path.exists():
        continue
    specs = {}
    for f in sorted((STYLES / KIT[style] / "specs").glob("*.json")):
        specs.update(json.loads(f.read_text()))
    spec = specs.get(path.stem)
    size, tris = kit_tests.glb_stats(path)
    problems, notes = [], []
    if spec:
        for axis, got, want in zip("xyz", size, spec["size"]):
            if abs(got - want) > 0.1 * want + 0.02:
                problems.append(f"{axis} {got:.2f} m against the kit spec's {want} m (over its 10%)")
        if tris > spec["tris"]:
            problems.append(f"{tris} triangles over the kit's budget of {spec['tris']}")
        missing = set(spec.get("nodes", [])) - kit_tests.node_names(path)
        if missing:
            problems.append(f"nodes missing: {sorted(missing)}")
    else:
        problems.append("the kit has no spec for it")
    line = f"{style:18s} {size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f} m, {tris} triangles (budget {spec['tris'] if spec else '-'})"
    if config.get("footprint"):
        fp = config["footprint"]
        box, _per = band.band_box(path)
        over = max(fp[0] - box[0], fp[1] - box[1], box[2] - fp[2], box[3] - fp[3])
        sx, sz = (fp[2] - fp[0]) / (box[2] - box[0]), (fp[3] - fp[1]) / (box[3] - box[1])
        line += f"; where people walk x {box[0]:.2f}..{box[2]:.2f}, z {box[1]:.2f}..{box[3]:.2f}"
        if over > 0.011:
            problems.append(f"reaches {over * 100:.0f} cm outside its footprint where people walk: the game will squeeze it to {sx:.2f} by {sz:.2f}")
        else:
            notes.append(f"filled to its footprint it is scaled {sx:.3f} by {sz:.3f}")
    if views and os.path.exists(f"{views}/{style}/asset-views.json"):
        seen = json.load(open(f"{views}/{style}/asset-views.json"))["views"]
        if seen:
            notes.append("the game placed it scaled " + " by ".join(f"{v:.3f}" for v in (seen[0]["scale"][0], seen[0]["scale"][2])))
    print(line + ": " + ("; ".join(problems + notes) if problems else "meets the kit's spec" + ("; " + "; ".join(notes) if notes else "")))
    ok = ok and not problems
sys.exit(0 if ok else 1)
