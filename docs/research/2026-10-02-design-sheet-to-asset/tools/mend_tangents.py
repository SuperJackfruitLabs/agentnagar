"""mend_tangents.py FILE.glb [...]: replaces the zero tangents in written GLB files.

A relief map needs a tangent at every corner, and the exporter writes a zero one where a triangle has no area in
the texture's layout. The kits' pinned glTF validator counts each as an error (ACCESSOR_VECTOR3_NON_UNIT), and
the kit tests fail a file on any. A zero tangent is replaced by a unit vector square to its normal; nothing else
in the file is touched, and a file with none is not written again. `build.py fit` does this to every piece it
builds; this is the same step for files already built. (fit_generated.py --mend-tangents is the same code, kept
there for a piece's second file.)

    python3 work/mend_tangents.py out/*/*.glb
"""
import json
import math
import struct
import sys
from pathlib import Path


def mend(path):
    """Mends the file in place; returns how many tangents were replaced."""
    data = bytearray(Path(path).read_bytes())
    n_json = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(bytes(data[20:20 + n_json]))
    base = 20 + n_json + 8

    def place(index):
        a = doc["accessors"][index]
        view = doc["bufferViews"][a["bufferView"]]
        width = {"VEC3": 3, "VEC4": 4}[a["type"]]
        return base + view.get("byteOffset", 0) + a.get("byteOffset", 0), view.get("byteStride", 4 * width), a["count"]
    mended = 0
    for mesh in doc.get("meshes", []):
        for prim in mesh["primitives"]:
            at = prim["attributes"]
            if "TANGENT" not in at or "NORMAL" not in at:
                continue
            (t_at, t_step, count), (n_at, n_step, _) = place(at["TANGENT"]), place(at["NORMAL"])
            for k in range(count):
                tx, ty, tz, _w = struct.unpack_from("<4f", data, t_at + k * t_step)
                if tx * tx + ty * ty + tz * tz > 0.25:
                    continue
                nx, ny, nz = struct.unpack_from("<3f", data, n_at + k * n_step)
                ax = (0.0, 1.0, 0.0) if abs(ny) < 0.9 else (1.0, 0.0, 0.0)
                cx, cy, cz = ax[1] * nz - ax[2] * ny, ax[2] * nx - ax[0] * nz, ax[0] * ny - ax[1] * nx
                length = math.sqrt(cx * cx + cy * cy + cz * cz) or 1.0
                struct.pack_into("<4f", data, t_at + k * t_step, cx / length, cy / length, cz / length, 1.0)
                mended += 1
    if mended:
        Path(path).write_bytes(bytes(data))
    return mended


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    total = 0
    for name in sys.argv[1:]:
        n = mend(name)
        total += n
        if n:
            print(f"{name}: {n} zero tangents replaced")
    print(f"{len(sys.argv) - 1} files, {total} tangents replaced")
