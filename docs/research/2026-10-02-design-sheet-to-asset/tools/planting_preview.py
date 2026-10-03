#!/usr/bin/env python3
"""planting_preview.py STYLE [ASSET ...] [--only-drawn]: for each planting piece built in out/<style>/, one sheet in
previews/<style>/<asset>.png: the design cut-out, then the kit's piece and the new piece from the same three
places (a walker's eye, a quarter above, straight above), shaded and in colour, first as their files have them
and then as the game draws them (drawn.py: a shrub scaled across to its footprint's disc by the game's own rule,
a bed stretched to its footprint; the red line on the lawn is the footprint the walking grid blocks).

Run from the working folder with AGENTNAGAR set; one Blender at a time. The pieces it knows how the game draws
are the ones whose entry in assets.json has `--shrub` (a shrub) or `--bed` (a bed) among its flags.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

W = Path(__file__).resolve().parent.parent
AGENTNAGAR = Path(os.environ["AGENTNAGAR"])
CONFIG = json.loads((W / "work" / "assets.json").read_text())
STYLES = AGENTNAGAR / "city" / "godot" / "styles"
BED = {"voxel": "3.3,1.3,2.0"}          # the voxel skin fits two 2 m modules to a bed


def blender(script, *args):
    r = subprocess.run(["blender", "--background", "--factory-startup", "--python", str(W / "work" / script), "--", *[str(a) for a in args]], text=True, capture_output=True)
    lines = [l for l in r.stdout.splitlines() if l.startswith(("DRAWN", "SCALE", "LOOK"))]
    if not any(l.startswith(("DRAWN", "LOOK")) for l in lines):
        sys.exit(f"{script} failed:\n{r.stdout[-1500:]}\n{r.stderr[-600:]}")
    return next((l for l in lines if l.startswith("SCALE")), "")


def main(argv):
    style, names = argv[0], [a for a in argv[1:] if not a.startswith("--")]
    out = W / "previews" / style
    out.mkdir(parents=True, exist_ok=True)
    for key, a in CONFIG["assets"].items():
        if names and key not in names:
            continue
        flags = a.get("flags", [])
        how = ["--shrub"] if "--shrub" in flags else (["--bed", BED.get(style, "3.3,1.3")] if "--bed" in flags else None)
        if how is None or style not in a.get("only", [style]):
            continue
        own = a.get("style", {}).get(style, {})
        file = own.get("file", a.get("file"))
        new = W / "out" / style / Path(file).name
        kit = STYLES / style / file
        if not new.exists():
            if names:
                print(f"{style} {key}: nothing built")
            continue
        tiles = []
        design = W / "raw" / style / f"{key}_cutout.png"
        flat = out / f"{key}-design.png"
        subprocess.run([str(W / "venv/bin/python"), "-c",
                        "import sys; from PIL import Image; im = Image.open(sys.argv[1]).convert('RGBA'); bg = Image.new('RGBA', im.size, (176, 198, 168, 255)); "
                        "bg.alpha_composite(im); box = im.getbbox(); bg.crop(box).convert('RGB').save(sys.argv[2])", str(design), str(flat)], check=True)
        scales = {}
        for who, path in (("kit", kit), ("new", new)):
            if "--only-drawn" not in argv:
                blender("drawn.py", path, out / f"{key}-{who}-file.png", "--size", "360")
            scales[who] = blender("drawn.py", path, out / f"{key}-{who}-drawn.png", "--size", "360", *how)
        tiles.append(f"the design={flat}")
        rows = [("as its file has it", "file"), ("as the game draws it", "drawn")]
        if "--only-drawn" in argv:
            rows = rows[1:]
        for label, kind in rows:
            for who, name in (("kit", "the kit's"), ("new", "new")):
                for view in ("eye", "quarter", "above"):
                    tiles.append(f"{name}, {label}: {view}={out / f'{key}-{who}-{kind}-{view}.png'}")
        sheet = out / f"{key}.png"
        subprocess.run([str(W / "venv/bin/python"), str(W / "work/strip.py"), str(sheet), tiles[0], "--height", "300"], check=True, capture_output=True)
        subprocess.run([str(W / "venv/bin/python"), str(W / "work/strip.py"), str(out / f"{key}-views.png"), *tiles[1:], "--cols", "3", "--height", "300"], check=True, capture_output=True)
        # the design above the views, in one sheet
        subprocess.run([str(W / "venv/bin/python"), "-c",
                        "import sys; from PIL import Image; a = Image.open(sys.argv[1]); b = Image.open(sys.argv[2]); s = Image.new('RGB', (max(a.width, b.width), a.height + b.height), (246, 244, 239)); "
                        "s.paste(a, (0, 0)); s.paste(b, (0, a.height)); s.save(sys.argv[1])", str(sheet), str(out / f"{key}-views.png")], check=True)
        (out / f"{key}-views.png").unlink()
        print(f"{style} {key}: {sheet.relative_to(W)}; the kit's piece: {scales['kit'][6:]}; the new piece: {scales['new'][6:]}")


if __name__ == "__main__":
    main(sys.argv[1:])
