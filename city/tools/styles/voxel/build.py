"""Builds the voxel kit v2 into the Godot pack (plain Python, no Blender).

python3 city/tools/styles/voxel/build.py [--out DIR] [NAME_PREFIX ...]

Writes <out>/<name>.glb for every asset in recipes.ASSETS (or those whose
names start with a given prefix) and prints each one's triangle count.
The default output is city/godot/styles/voxel/assets/v2/.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import palette  # noqa: E402
import recipes  # noqa: E402
import voxel  # noqa: E402

DEFAULT_OUT = HERE.parents[2] / "godot" / "styles" / "voxel" / "assets" / "v2"


def main(argv):
    out = DEFAULT_OUT
    if "--out" in argv:
        k = argv.index("--out")
        out = Path(argv[k + 1])
        argv = argv[:k] + argv[k + 2:]
    out.mkdir(parents=True, exist_ok=True)
    built = 0
    for name in sorted(recipes.ASSETS):
        if argv and not any(name.startswith(a) for a in argv):
            continue
        asset = recipes.ASSETS[name]()
        assert asset.name == name, (asset.name, name)
        meshes = asset.meshes()
        data = voxel.glb_bytes(name, meshes, palette.PALETTE, palette.PROPS)
        (out / f"{name}.glb").write_bytes(data)
        tris = sum(voxel.triangles(part[1]) for part in meshes)
        print(f"voxel: wrote {name}.glb ({tris} triangles, {len(data) // 1024} KiB)")
        built += 1
    print(f"voxel: built {built} assets")


if __name__ == "__main__":
    main(sys.argv[1:])
