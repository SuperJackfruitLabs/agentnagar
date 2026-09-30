"""Builds the low-poly tropical kit into the Godot style pack.

blender --background --factory-startup --python-exit-code 1 \\
    --python city/tools/styles/lowpoly/build.py -- [--out DIR] [MODULE_OR_PREFIX ...]

Each module (buildings, scenery, vegetation, props, characters) holds an
ASSETS dict of name -> builder; a module listing ANIMATED names exports
those with their skins and actions. With arguments, only the modules named,
or the assets whose names start with a given prefix, are built.
"""
import importlib
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import lib  # noqa: E402

MODULES = ["buildings", "scenery", "vegetation", "props", "characters"]
DEFAULT_OUT = HERE.parents[2] / "godot" / "styles" / "lowpoly_tropical" / "assets"


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = DEFAULT_OUT
    if "--out" in argv:
        k = argv.index("--out")
        out = Path(argv[k + 1])
        argv = argv[:k] + argv[k + 2:]
    out.mkdir(parents=True, exist_ok=True)
    built = 0
    for name in MODULES:
        if not (HERE / f"{name}.py").exists():
            continue
        module = importlib.import_module(name)
        animated = set(getattr(module, "ANIMATED", ()))
        for asset, build in module.ASSETS.items():
            if argv and name not in argv and not any(asset.startswith(a) for a in argv):
                continue
            lib.reset()
            build()
            lib.export(out / f"{asset}.glb", animations=asset in animated)
            built += 1
            print(f"lowpoly: wrote {asset}.glb ({lib.triangles()} triangles)")
    print(f"lowpoly: built {built} assets")


main()
