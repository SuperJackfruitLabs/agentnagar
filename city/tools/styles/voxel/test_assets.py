"""Checks the voxel builder and the voxel kit v2.

- The builder: only exposed faces are meshed, coplanar faces of one colour
  merge into rectangles, faces wind outward, and the GLB is well formed.
- The kit: every asset meets its spec in specs/*.json (bounding size within
  10% on each Godot axis, triangle budget, named nodes, animations), every
  committed GLB is exactly what the generator builds today (in a separate
  process with a different hash seed, so the build is reproducible across
  runs), every GLB passes the pinned Khronos validator, every GLB has an
  import sidecar with LOD generation off, the palette agrees with the pack's
  style.json, and the human recipe has a part for every bone of the shared
  rig.

python3 -m unittest city/tools/styles/voxel/test_assets.py
"""
import filecmp
import json
import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
PACK = HERE.parents[2] / "godot" / "styles" / "voxel"
ASSETS = PACK / "assets" / "v2"
sys.path.insert(0, str(HERE.parent / "shared"))
import tram_checks  # noqa: E402

# The tram: the line's length, doors that open, an interior with its seats
# under the shared layout's slots (tools/styles/shared/tram_checks.py).
Tram = tram_checks.tram_case(ASSETS / "tram.glb")

import voxel  # noqa: E402


def glb_json(data):
    length = struct.unpack("<I", data[12:16])[0]
    return json.loads(data[20:20 + length])


def _mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def _local(node):
    if "matrix" in node:
        m = node["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    tx, ty, tz = node.get("translation", [0, 0, 0])
    qx, qy, qz, qw = node.get("rotation", [0, 0, 0, 1])
    sx, sy, sz = node.get("scale", [1, 1, 1])
    r = [[1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw)],
         [2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw)],
         [2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy)]]
    return [[r[0][0] * sx, r[0][1] * sy, r[0][2] * sz, tx],
            [r[1][0] * sx, r[1][1] * sy, r[1][2] * sz, ty],
            [r[2][0] * sx, r[2][1] * sy, r[2][2] * sz, tz],
            [0, 0, 0, 1]]


def glb_stats(data):
    """(bounding size [x, y, z], triangle count, node names, animation
    names) of a GLB's meshes in their rest pose."""
    g = glb_json(data)
    nodes = g["nodes"]
    lo, hi = [float("inf")] * 3, [float("-inf")] * 3
    tris = 0

    def visit(i, parent):
        nonlocal tris
        node = nodes[i]
        world = _mat_mul(parent, _local(node))
        if "mesh" in node:
            for prim in g["meshes"][node["mesh"]]["primitives"]:
                acc = g["accessors"][prim["attributes"]["POSITION"]]
                tris += g["accessors"][prim["indices"]]["count"] // 3
                a, b = acc["min"], acc["max"]
                for cx in (a[0], b[0]):
                    for cy in (a[1], b[1]):
                        for cz in (a[2], b[2]):
                            p = [sum(world[r][c] * v for c, v in enumerate((cx, cy, cz, 1))) for r in range(3)]
                            for k in range(3):
                                lo[k] = min(lo[k], p[k])
                                hi[k] = max(hi[k], p[k])
        for c in node.get("children", []):
            visit(c, world)

    identity = [[1 if r == c else 0 for c in range(4)] for r in range(4)]
    for i in g["scenes"][g.get("scene", 0)]["nodes"]:
        visit(i, identity)
    names = {n.get("name") for n in nodes}
    anims = {a.get("name") for a in g.get("animations", [])}
    return [hi[a] - lo[a] for a in range(3)], tris, names, anims


def specs():
    out = {}
    for path in sorted((HERE / "specs").glob("*.json")):
        out.update(json.loads(path.read_text()))
    return out


class VoxelBuilder(unittest.TestCase):
    def test_a_lone_voxel_has_six_outward_faces(self):
        g = voxel.Grid(0.1)
        g.put(0, 0, 0, "white")
        m = voxel.mesh(g)
        pos, nor, idx = m["white"]
        self.assertEqual(len(idx) // 3, 12)
        # Every triangle winds counter-clockwise seen from its normal.
        for t in range(0, len(idx), 3):
            a, b, c = (pos[i] for i in idx[t:t + 3])
            n = nor[idx[t]]
            e1 = [b[x] - a[x] for x in range(3)]
            e2 = [c[x] - a[x] for x in range(3)]
            cross = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]]
            self.assertGreater(sum(cross[x] * n[x] for x in range(3)), 0)

    def test_hidden_faces_are_dropped_and_flat_faces_merge(self):
        g = voxel.Grid(0.1)
        g.box(0, 0, 0, 10, 4, 3, "yellow")
        m = voxel.mesh(g)
        # A solid box of one colour is six rectangles, whatever its size.
        self.assertEqual(voxel.triangles(m), 12)
        pos = m["yellow"][0]
        self.assertEqual(min(p[0] for p in pos), 0.0)
        self.assertAlmostEqual(max(p[0] for p in pos), 1.0)
        self.assertAlmostEqual(max(p[1] for p in pos), 0.4)

    def test_colours_split_faces_but_not_hidden_ones(self):
        g = voxel.Grid(0.1)
        g.box(0, 0, 0, 2, 1, 1, "yellow")
        g.put(1, 0, 0, "glass")
        m = voxel.mesh(g)
        self.assertEqual(set(m), {"yellow", "glass"})
        # Each cube keeps its five outer faces; the shared face is gone.
        self.assertEqual(voxel.triangles(m), 20)

    def test_greedy_covers_every_square_exactly_once(self):
        pts = {(u, v) for u in range(7) for v in range(5) if (u * 3 + v) % 4}
        covered = []
        for (u, v, w, h) in voxel.greedy(pts):
            covered += [(u + x, v + y) for x in range(w) for y in range(h)]
        self.assertEqual(sorted(covered), sorted(pts))

    def test_shade_variation_is_stable_and_blocky(self):
        a, b = voxel.Grid(), voxel.Grid()
        for g in (a, b):
            g.box(0, 0, 0, 20, 20, 1, "orange")
            g.vary({"orange"}, block=(5, 5, 5), seed="t")
        self.assertEqual(a.cells, b.cells)
        keys = set(a.cells.values())
        self.assertTrue({"orange", "orange+", "orange-"} >= keys and len(keys) >= 2, keys)
        # Every 5 x 5 block is one shade.
        for bi in range(4):
            for bj in range(4):
                block = {a.cells[(i, j, 0)] for i in range(bi * 5, bi * 5 + 5) for j in range(bj * 5, bj * 5 + 5)}
                self.assertEqual(len(block), 1)

    def test_a_drum_follows_its_circle_and_winds_outward(self):
        m = voxel.drum(32, 1.05, 0.0, 0.4, "leaf_dark", "leaf", seed="t")
        pos = [p for key in m for p in m[key][0]]
        # Every corner off the axis lies on the circle, none beyond it.
        rims = [math.hypot(p[0], p[2]) for p in pos if abs(p[0]) + abs(p[2]) > 1e-9]
        self.assertTrue(all(abs(r - 1.05) < 1e-5 for r in rims), (min(rims), max(rims)))
        self.assertAlmostEqual(max(p[1] for p in pos), 0.4)
        # 32 sides and a 32-slice cap.
        self.assertEqual(voxel.triangles(m), 96)
        for key, (pos, nor, idx) in m.items():
            for t in range(0, len(idx), 3):
                a, b, c = (pos[i] for i in idx[t:t + 3])
                n = nor[idx[t]]
                e1 = [b[x] - a[x] for x in range(3)]
                e2 = [c[x] - a[x] for x in range(3)]
                cross = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]]
                self.assertGreater(sum(cross[x] * n[x] for x in range(3)), 0)

    def test_glb_is_well_formed(self):
        g = voxel.Grid(0.1)
        g.box(-5, 0, 0, 5, 3, 2, "white")
        g.put(0, 3, 0, "lamp_glow")
        asset = voxel.Asset("probe")
        asset.part("body", g)
        data = asset.glb({"white": "#F4F1EA", "lamp_glow": "#FFE3A0"}, {"lamp_glow": {"emissive": 1.0}})
        self.assertEqual(data[:4], b"glTF")
        self.assertEqual(struct.unpack("<I", data[8:12])[0], len(data))
        doc = glb_json(data)
        self.assertEqual([m["name"] for m in doc["materials"]], ["lamp_glow", "white"])
        self.assertIn("emissiveFactor", doc["materials"][0])
        size, tris, names, _ = glb_stats(data)
        self.assertEqual(names, {"probe", "body"})
        for got, want in zip(size, (1.0, 0.4, 0.2)):
            self.assertAlmostEqual(got, want, places=5)
        self.assertEqual(asset.glb({"white": "#F4F1EA", "lamp_glow": "#FFE3A0"}, {"lamp_glow": {"emissive": 1.0}}), data)


class VoxelKit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import palette
        cls.palette = palette
        cls.specs = specs()

    def test_every_asset_has_a_spec_and_every_spec_an_asset(self):
        import recipes
        self.assertEqual(set(recipes.ASSETS) | set(recipes.BLENDER), set(self.specs))
        self.assertGreaterEqual(len(self.specs), 40)

    def test_every_asset_meets_its_spec(self):
        for name, spec in sorted(self.specs.items()):
            with self.subTest(asset=name):
                path = ASSETS / f"{name}.glb"
                self.assertTrue(path.exists(), f"{name}.glb has not been built")
                size, tris, names, anims = glb_stats(path.read_bytes())
                for axis, got, want in zip("xyz", size, spec["size"]):
                    self.assertLessEqual(abs(got - want), 0.1 * want + 0.02,
                                         f"{name} {axis}: {got:.2f} m, want {want} m ±10%")
                self.assertLessEqual(tris, spec["tris"], f"{name}: {tris} triangles over budget")
                self.assertTrue(set(spec.get("nodes", [])) <= names, set(spec.get("nodes", [])) - names)
                # Godot renames a part that shares its asset's (root's) name.
                roots = glb_json(path.read_bytes())["scenes"][0]["nodes"]
                parts = [n["name"] for k, n in enumerate(glb_json(path.read_bytes())["nodes"]) if k not in roots]
                self.assertNotIn(name, parts)
                self.assertTrue(set(spec.get("animations", [])) <= anims, set(spec.get("animations", [])) - anims)

    def test_no_stray_glbs(self):
        for path in ASSETS.glob("*.glb"):
            self.assertIn(path.stem, self.specs, f"{path.name} has no spec in specs/*.json")

    def test_committed_glbs_are_what_the_generator_builds(self):
        import recipes
        with tempfile.TemporaryDirectory() as out:
            env = dict(os.environ, PYTHONHASHSEED="12345")
            result = subprocess.run([sys.executable, str(HERE / "build.py"), "--out", out],
                                    capture_output=True, text=True, env=env)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            built = sorted(p.name for p in Path(out).glob("*.glb"))
            committed = sorted(p.name for p in ASSETS.glob("*.glb") if p.stem not in recipes.BLENDER)
            self.assertEqual(built, committed)
            _, mismatch, errors = filecmp.cmpfiles(out, ASSETS, built, shallow=False)
            self.assertEqual(mismatch + errors, [], "rebuild differs from the committed GLBs")

    def test_glbs_pass_the_khronos_validator(self):
        result = subprocess.run(["bash", str(HERE / "validate.sh")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_every_glb_has_an_import_sidecar_without_lods(self):
        for path in ASSETS.glob("*.glb"):
            sidecar = path.with_name(path.name + ".import")
            self.assertTrue(sidecar.exists(), f"{sidecar.name} missing")
            self.assertIn("meshes/generate_lods=false", sidecar.read_text(), sidecar.name)

    def test_palette_agrees_with_the_pack(self):
        style = json.loads((PACK / "style.json").read_text())
        for key, colour in self.palette.PALETTE.items():
            if key in style["palette"]:
                self.assertEqual(colour.upper(), style["palette"][key].upper(), key)

    def test_the_lamp_light_is_emissive(self):
        doc = glb_json((ASSETS / "lamp.glb").read_bytes())
        light = next(n for n in doc["nodes"] if n.get("name") == "light")
        mats = {p["material"] for p in doc["meshes"][light["mesh"]]["primitives"]}
        for m in mats:
            self.assertGreater(sum(doc["materials"][m].get("emissiveFactor", [0, 0, 0])), 0)

    def test_vault_cap_covers_the_segments_open_section(self):
        # lib_vault leaves out its section faces at z = 0 and z = 2 m; the
        # end cap's last row must fill that whole section, or the roof has
        # holes where they meet.
        import buildings
        cap = buildings.lib_vault_end().parts[0][1]
        for i in range(-buildings.VAULT_HALF, buildings.VAULT_HALF):
            for j in range(buildings.vault_low(i), buildings.vault_top(i)):
                self.assertIsNotNone(cap.get(i, j, buildings.CAP - 1), (i, j))

    def test_human_parts_cover_the_shared_rig(self):
        import humans
        rig = {"hips", "spine", "chest", "neck", "head"}
        for side in ("l", "r"):
            rig |= {f"upper_arm_{side}", f"forearm_{side}", f"hand_{side}",
                    f"thigh_{side}", f"shin_{side}", f"foot_{side}"}
        parts = humans.parts()
        self.assertEqual(set(parts), rig)
        for bone, grids in parts.items():
            self.assertTrue(any(len(g) for g in grids.values()), f"{bone} has no voxels")
        body = [g for grids in parts.values() for name, g in grids.items() if name != "hat_sun" and len(g)]
        height = max(g.bounds()[1][1] for g in body) * humans.HUMAN_VOXEL
        self.assertTrue(1.65 <= height <= 1.8, f"{height:.2f} m")

    def test_the_human_is_skinned_to_the_shared_rig(self):
        doc = glb_json((ASSETS / "human.glb").read_bytes())
        self.assertEqual(len(doc["skins"]), 1)
        import humans
        joints = {doc["nodes"][j]["name"] for j in doc["skins"][0]["joints"]}
        self.assertEqual(joints, set(humans.BONES))
        skinned = {n["name"] for n in doc["nodes"] if "skin" in n}
        self.assertEqual(skinned, set(humans.OBJECTS))
        self.assertEqual({a["name"] for a in doc["animations"]}, {"walk", "sit", "idle", "typing"})

    @unittest.skipUnless(shutil.which("blender"), "Blender is not installed")
    def test_the_human_rebuilds_byte_identical(self):
        with tempfile.TemporaryDirectory() as out:
            result = subprocess.run(["blender", "--background", "--factory-startup", "--python-exit-code", "1",
                                     "--python", str(HERE / "build_humans.py"), "--", "--out", out],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout[-2000:] + result.stderr[-2000:])
            self.assertEqual((Path(out) / "human.glb").read_bytes(), (ASSETS / "human.glb").read_bytes())

if __name__ == "__main__":
    unittest.main()
