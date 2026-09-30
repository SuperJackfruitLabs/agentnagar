"""The build driver every style kit shares (solarpunk, neon noir): runs
under Blender, builds each module's ASSETS into the style pack's assets
directory, then each characters module's EXTRAS (atlases).

A kit's build.py puts its own directory and this one on sys.path,
registers its lib as `lib`, and calls main(). See the anime kit's build.py,
which this generalises.
"""
import importlib
import sys
from pathlib import Path

MODULES = ["buildings", "scenery", "vegetation", "props", "characters"]


def main(here, default_out, label):
    import lib
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(default_out)
    if "--out" in argv:
        k = argv.index("--out")
        out = Path(argv[k + 1])
        argv = argv[:k] + argv[k + 2:]
    out.mkdir(parents=True, exist_ok=True)
    built = 0
    for name in MODULES:
        if not (Path(here) / f"{name}.py").exists():
            continue
        module = importlib.import_module(name)
        animated = set(getattr(module, "ANIMATED", ()))
        for asset, build in module.ASSETS.items():
            if argv and name not in argv and not any(asset.startswith(a) for a in argv):
                continue
            lib.reset()
            build()
            if asset not in animated:
                import bake
                bake.bake_scene()
            lib.export(out / f"{asset}.glb", animations=asset in animated)
            built += 1
            print(f"{label}: wrote {asset}.glb ({lib.triangles()} triangles)")
        for extra in getattr(module, "EXTRAS", []):
            if not argv or name in argv or any(extra.__name__.startswith(a) for a in argv):
                extra(out)
    print(f"{label}: built {built} assets")
