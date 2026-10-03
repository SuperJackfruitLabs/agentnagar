"""far_as_near.py STYLE: in the working copy of the game, puts each street tree's and palm's far twin (about 775
triangles, textures a quarter the size) in the place of the piece itself, so that every copy is drawn as its far
twin at every distance. For a frame-time trial only: `build.py restore STYLE` or `place STYLE @trees` undoes it."""
import hashlib
import json
import shutil
import sys
from pathlib import Path

W = Path(__file__).resolve().parent.parent
style = sys.argv[1]
assets = json.loads((W / "work" / "assets.json").read_text())["assets"]
for key in ("street-tree-a", "street-tree-b", "palm-tall", "palm-mid", "palm-short"):
    a = assets[key]
    file = a.get("style", {}).get(style, {}).get("file", a["file"])
    target = W / "game" / "city" / "godot" / "styles" / style / file
    source = W / "out" / style / (Path(file).stem + "_far.glb")
    for mine in target.parent.glob(f"{target.stem}_{target.stem}*.png*"):      # textures the engine pulled out of the full piece
        mine.unlink()
    shutil.copyfile(source, target)
    cache_name = hashlib.md5(f"res://styles/{style}/{file}".encode()).hexdigest()
    for cached in (W / "game" / "city" / "godot" / ".godot" / "imported").glob(f"{target.name}-{cache_name}.*"):
        cached.unlink()
    print(f"{style} {key}: {source.name} ({source.stat().st_size} bytes) in the place of {target.name}")
