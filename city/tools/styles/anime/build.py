"""Builds the cel-shaded anime kit into the Godot style pack.

blender --background --factory-startup --python-exit-code 1 \\
    --python city/tools/styles/anime/build.py -- [--out DIR] [MODULE_OR_PREFIX ...]

Each module (buildings, scenery, vegetation, props, characters) holds an
ASSETS dict of name -> builder; a module listing ANIMATED names exports
those with their skins and actions. With arguments, only the modules named,
or the assets whose names start with a given prefix, are built. Runs the
low-poly kit's shared code (lib, the character rig) on the anime palette.
"""
import importlib
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import lib  # noqa: E402  (the anime lib: the low-poly API on the anime palette)

sys.modules["lib"] = lib
MODULES = ["buildings", "scenery", "vegetation", "props", "characters"]
DEFAULT_OUT = HERE.parents[2] / "godot" / "styles" / "anime_cel" / "assets"


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
            if asset not in animated:
                sys.path.insert(0, str(HERE.parent / "shared"))
                import bake
                bake.bake_scene()
            lib.export(out / f"{asset}.glb", animations=asset in animated)
            built += 1
            print(f"anime: wrote {asset}.glb ({lib.triangles()} triangles)")
    for extra in getattr(importlib.import_module("characters"), "EXTRAS", []) if (HERE / "characters.py").exists() else []:
        if not argv or "characters" in argv or any(extra.__name__.startswith(a) for a in argv):
            extra(out)
    print(f"anime: built {built} assets")


main()
