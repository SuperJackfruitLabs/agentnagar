#!/usr/bin/env python3
"""preview.py STYLE PIECE [PIECE ...]: a built piece set beside its design image and the kit's piece.

One sheet a piece, previews/<piece>-<style>.png: the design cut-out, then the kit's piece and the built piece
from the same cameras, shaded and in their own colours (look.py --lit), and the built piece once more in flat
colours, to judge them against the design. The cameras are the piece's own (`VIEWS` below): a tram shelter is
also seen from its open front at a standing eye's height, a fountain from straight above. No game is started;
these are Blender's workbench renders, not the game's light, toon shading or ink lines.

The working folder is this script's parent; the checkout comes from AGENTNAGAR.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

W = Path(__file__).resolve().parent.parent
AGENTNAGAR = Path(os.environ["AGENTNAGAR"])
CONFIG = json.loads((W / "work" / "assets.json").read_text())
# camera x,y,z, target x,y,z, lens: the piece's frame as the game has it (y up, -z its front), metres
VIEWS = {
    "tram-shelter": [("three-quarter", "4.6,3.2,-5.4,0,1.3,0,40"), ("from the open front, at eye height", "0,1.6,-6.6,0,1.35,0,40"), ("from behind", "-4.2,2.6,5.2,0,1.3,0,40")],
    "fountain": [("three-quarter", "3.5,2.7,-3.5,0,0.65,0,35"), ("at eye height", "0,1.6,-5.6,0,0.75,0,35"), ("from straight above", "0,7.6,0.001,0,0,0,35")],
}
DEFAULT_VIEWS = [("three-quarter", "2.2,1.8,-2.6,0,0.5,0,40"), ("front", "0,1.2,-3.6,0,0.5,0,40"), ("from above", "0,4.5,0.001,0,0,0,35")]


def look(model, stem, views, lit):
    cmd = ["blender", "--background", "--factory-startup", "--python", str(W / "work" / "look.py"), "--", str(model), str(stem) + ".png", "--size", "560"]
    if lit:
        cmd.append("--lit")
    for k, (_, numbers) in enumerate(views):
        cmd += ["--view", f"v{k}={numbers}"]
    subprocess.run(cmd, capture_output=True, text=True, check=True)
    return [f"{stem}-v{k}.png" for k in range(len(views))]


def main(style, pieces):
    for key in pieces:
        a = CONFIG["assets"][key]
        own = a.get("style", {}).get(style, {})
        file = own.get("file", a.get("file"))
        built = W / "out" / style / Path(file).name
        if not built.exists():
            print(f"{style} {key}: nothing built")
            continue
        kit = AGENTNAGAR / "city" / "godot" / "styles" / style / file
        # the cut-out the model was generated from: a style's own (`raw`), and the pre-matted one where it was used (`crop`)
        design = W / "raw" / style / f"{own.get('raw', a.get('raw', key))}{'~matte' if own.get('crop', a.get('crop')) == 'matte' else ''}_cutout.png"
        views = VIEWS.get(key, DEFAULT_VIEWS)
        scratch = W / "scratch" / "previews" / style
        scratch.mkdir(parents=True, exist_ok=True)
        kit_shots = look(kit, scratch / f"{key}-kit", views, True)
        new_shots = look(built, scratch / f"{key}-new", views, True)
        flat_shot = look(built, scratch / f"{key}-flat", views[:1], False)
        tiles = [f"design cut-out={design}"] + [f"kit, {label}={shot}" for (label, _), shot in zip(views, kit_shots)]
        tiles += [f"built, flat colours={flat_shot[0]}"] + [f"built, {label}={shot}" for (label, _), shot in zip(views, new_shots)]
        out = W / "previews" / f"{key}-{style}.png"
        r = subprocess.run([str(W / "venv" / "bin" / "python"), str(W / "work" / "strip.py"), str(out), *tiles, "--cols", str(len(views) + 1), "--height", "440"], capture_output=True, text=True)
        print(r.stdout.strip() or r.stderr.strip()[-300:])


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2:])
