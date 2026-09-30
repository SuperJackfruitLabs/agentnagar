"""Checks the cel-shaded anime kit: every style.json reference exists, every
GLB is specified and meets its spec in specs/*.json (bounding size within
10% on each axis, in Godot axes x, y up, z; triangle budget; named nodes and
animations), passes the pinned Khronos validator, and the committed kit is
exactly what the generator builds.

python3 -m unittest city/tools/styles/anime/test_assets.py
"""
import hashlib
import importlib.util
import sys
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
PACK = HERE.parents[2] / "godot" / "styles" / "anime_cel"
ASSETS = PACK / "assets"
sys.path.insert(0, str(HERE.parent / "shared"))
import tram_checks  # noqa: E402

# The tram: the line's length, doors that open, an interior with its seats
# under the shared layout's slots (tools/styles/shared/tram_checks.py).
Tram = tram_checks.tram_case(ASSETS / "tram.glb")

_spec = importlib.util.spec_from_file_location("lowpoly_test_assets", HERE.parent / "lowpoly" / "test_assets.py")
low = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(low)
glb_json, glb_stats, node_names = low.glb_json, low.glb_stats, low.node_names


def specs():
    out = {}
    for f in sorted((HERE / "specs").glob("*.json")):
        out.update(json.loads(f.read_text()))
    return out


def references(node):
    """Every asset path a style.json names."""
    if isinstance(node, dict):
        for v in node.values():
            yield from references(v)
    elif isinstance(node, list):
        for v in node:
            yield from references(v)
    elif isinstance(node, str) and node.startswith("assets/"):
        yield node


class AnimeKit(unittest.TestCase):
    def test_every_reference_exists(self):
        style_path = PACK / "style.json"
        if not style_path.exists():
            self.skipTest("the anime pack's style.json is not written yet")
        refs = list(references(json.loads(style_path.read_text())))
        self.assertGreater(len(refs), 20)
        for ref in refs:
            self.assertTrue((PACK / ref).exists(), ref)

    def test_every_asset_meets_its_spec(self):
        self.assertGreater(len(specs()), 0, "the kit specifies its assets")
        for name, spec in specs().items():
            with self.subTest(asset=name):
                path = ASSETS / f"{name}.glb"
                self.assertTrue(path.exists(), f"{name}.glb has not been built")
                size, tris = glb_stats(path)
                for axis, got, want in zip("xyz", size, spec["size"]):
                    self.assertLessEqual(abs(got - want), 0.1 * want + 0.02,
                                         f"{name} {axis}: {got:.2f} m, want {want} m ±10%")
                self.assertLessEqual(tris, spec["tris"], f"{name}: {tris} triangles over budget")
                self.assertTrue(set(spec.get("nodes", [])) <= node_names(path),
                                set(spec.get("nodes", [])) - node_names(path))
                anims = {a.get("name") for a in glb_json(path).get("animations", [])}
                self.assertTrue(set(spec.get("animations", [])) <= anims,
                                set(spec.get("animations", [])) - anims)

    def test_every_glb_is_specified(self):
        known = set(specs())
        for path in ASSETS.glob("*.glb"):
            self.assertIn(path.stem, known, f"{path.name} has no spec in specs/*.json")

    def test_planted_pieces_draw_with_two_materials_at_most(self):
        """The city plants these by the hundred: each material is a draw per
        copy per pass (tools/styles/shared/bake.py)."""
        for name in ["tree_round_a", "tree_round_b", "palm_a", "palm_b", "palm_c", "shrub_round", "shrub_leafy"]:
            with self.subTest(asset=name):
                mats = glb_json(ASSETS / f"{name}.glb").get("materials", [])
                self.assertLessEqual(len(mats), 2, [m.get("name") for m in mats])

    def test_glbs_pass_the_khronos_validator(self):
        if not any(ASSETS.glob("*.glb")):
            self.skipTest("nothing built yet")
        result = subprocess.run(["bash", str(HERE / "validate.sh")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_the_committed_kit_is_what_the_generator_builds(self):
        """Every GLB, rebuilt from the generator in one run, matches the
        committed file byte for byte: the build is reproducible, and no edit
        to a shared module has silently changed or broken another asset."""
        blender = os.environ.get("BLENDER") or shutil.which("blender")
        if not blender or not specs():
            self.skipTest("Blender is not installed, or nothing is specified yet")
        with tempfile.TemporaryDirectory() as out:
            subprocess.run([blender, "--background", "--factory-startup", "--python-exit-code", "1",
                            "--python", str(HERE / "build.py"), "--", "--out", out],
                           check=True, capture_output=True)
            for built in sorted(Path(out).glob("*.glb")):
                with self.subTest(asset=built.stem):
                    self.assertEqual(hashlib.sha256(built.read_bytes()).hexdigest(),
                                     hashlib.sha256((ASSETS / built.name).read_bytes()).hexdigest(),
                                     f"{built.name} is stale or builds differently")


class AnimeFaces(unittest.TestCase):
    """The face atlas: every expression of every face, drawn over
    transparency, and the same bytes every time it is drawn."""

    def test_the_atlas_has_a_cell_per_expression_and_face(self):
        from PIL import Image
        sys.path.insert(0, str(HERE))
        import faces
        atlas = Image.open(ASSETS / "face_atlas.png")
        self.assertEqual(atlas.size, (faces.CELL * len(faces.EXPRESSIONS), faces.CELL * len(faces.VARIANTS)))
        self.assertEqual(atlas.mode, "RGBA")
        for row in range(len(faces.VARIANTS)):
            for col in range(len(faces.EXPRESSIONS)):
                cell = atlas.crop((col * faces.CELL, row * faces.CELL, (col + 1) * faces.CELL, (row + 1) * faces.CELL))
                alpha = cell.getchannel("A")
                self.assertEqual(alpha.getpixel((0, 0)), 0, "skin shows through the corners")
                self.assertGreater(sum(1 for a in alpha.getdata() if a > 128), 400, f"cell {row},{col} draws a face")

    def test_the_atlas_is_drawn_reproducibly(self):
        sys.path.insert(0, str(HERE))
        import faces
        with tempfile.TemporaryDirectory() as out:
            faces.main([str(Path(out) / "a.png")])
            self.assertEqual(hashlib.sha256((Path(out) / "a.png").read_bytes()).hexdigest(),
                             hashlib.sha256((ASSETS / "face_atlas.png").read_bytes()).hexdigest(),
                             "committed atlas matches faces.py")
