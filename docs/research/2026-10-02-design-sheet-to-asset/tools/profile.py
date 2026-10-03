"""profile.py RAW.glb: prints a generated model's width, depth and area share by height (40 slices), to see
where a bed ends, a trunk runs and a crown begins."""
import sys
import bpy, numpy as np
raw = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=raw)
o = [x for x in bpy.data.objects if x.type == "MESH"][0]
m = np.empty(len(o.data.vertices) * 3); o.data.vertices.foreach_get("co", m); m = m.reshape(-1, 3)
w = np.array(o.matrix_world); p = m @ w[:3, :3].T + w[:3, 3]
lo, hi = p.min(axis=0), p.max(axis=0)
print("PROFILE box", np.round(lo, 3), np.round(hi, 3), "size", np.round(hi - lo, 3))
n = 40
for k in range(n):
    z0, z1 = lo[2] + (hi[2] - lo[2]) * k / n, lo[2] + (hi[2] - lo[2]) * (k + 1) / n
    s = p[(p[:, 2] >= z0) & (p[:, 2] < z1)]
    if len(s) == 0:
        print(f"PROFILE {k:2d} z {z0:.3f}: empty"); continue
    print(f"PROFILE {k:2d} z {(z0 - lo[2]) / (hi[2] - lo[2]):.3f}  x {s[:, 0].min():+.3f}..{s[:, 0].max():+.3f} ({s[:, 0].max() - s[:, 0].min():.3f})  y {s[:, 1].min():+.3f}..{s[:, 1].max():+.3f} ({s[:, 1].max() - s[:, 1].min():.3f})  verts {len(s)}")
