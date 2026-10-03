"""far_swap.py STYLE [--remove]: puts each street tree's and palm's far twin (`<piece>_far.glb`, built beside every
planted piece outside voxel) into the working copy of the game next to the piece, so that the game draws the full
piece within 90 m and the twin beyond (Pack3D._plant swaps to a `_far` file wherever one exists, in any pack;
build.py place copies a twin only where the kit has one, and the low-poly kit has none). With --remove the twins
are taken out again. The engine's cached imports of the twins go either way."""
import hashlib
import json
import sys
from pathlib import Path

W = Path(__file__).resolve().parent.parent
style, remove = sys.argv[1], "--remove" in sys.argv
assets = json.loads((W / "work" / "assets.json").read_text())["assets"]
for key in ("street-tree-a", "street-tree-b", "palm-tall", "palm-mid", "palm-short"):
    a = assets[key]
    file = a.get("style", {}).get(style, {}).get("file", a["file"])
    far_file = str(Path(file).with_name(Path(file).stem + "_far.glb"))
    target = W / "game" / "city" / "godot" / "styles" / style / far_file
    source = W / "out" / style / Path(far_file).name
    cache_name = hashlib.md5(f"res://styles/{style}/{far_file}".encode()).hexdigest()
    for cached in (W / "game" / "city" / "godot" / ".godot" / "imported").glob(f"{target.name}-{cache_name}.*"):
        cached.unlink()
    for pulled in target.parent.glob(f"{target.stem}_*"):                         # textures the engine pulled out of it
        pulled.unlink()                                                           # (.webp or .png, and their .import)
    if remove:
        # The twin's .import file goes too: left alone, it makes the game believe the twin is there, fail to load
        # it, and draw the piece's copies only within 90 m (seen in a kit run of the first far-swap bench).
        for gone in (target, target.with_name(target.name + ".import")):
            if gone.exists():
                gone.unlink()
        print(f"{style} {key}: {target.name} taken out")
    else:
        target.write_bytes(source.read_bytes())
        print(f"{style} {key}: {source.name} ({source.stat().st_size} bytes) placed beside {Path(file).name}")
