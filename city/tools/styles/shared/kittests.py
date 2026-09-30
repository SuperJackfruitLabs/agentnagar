"""The checks every style kit runs (solarpunk, neon noir), after the
anime kit's test_assets.py: every style.json reference exists, every GLB is
specified and meets its spec (bounding size within 10% per axis in Godot
axes, triangle budget, named nodes, animations), the pinned Khronos
validator passes, and the committed kit is exactly what the generator
builds.

A kit's test_assets.py: `Kit = kittests.kit_case(HERE, PACK)`.
"""
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

_LOW_TESTS = Path(__file__).resolve().parents[1] / "lowpoly" / "test_assets.py"
_spec = importlib.util.spec_from_file_location("lowpoly_test_assets", _LOW_TESTS)
low = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(low)
glb_json, glb_stats, node_names = low.glb_json, low.glb_stats, low.node_names
REPO = Path(__file__).resolve().parents[4]
# The pieces the city plants by the hundred (every kit's vegetation BAKED).
PLANTED = ["tree_round_a", "tree_round_b", "palm_a", "palm_b", "palm_c", "shrub_round", "shrub_leafy"]


def specs(here):
    out = {}
    for f in sorted((Path(here) / "specs").glob("*.json")):
        out.update(json.loads(f.read_text()))
    return out


def references(node):
    if isinstance(node, dict):
        for v in node.values():
            yield from references(v)
    elif isinstance(node, list):
        for v in node:
            yield from references(v)
    elif isinstance(node, str) and node.startswith("assets/"):
        yield node


VALIDATE = r"""
const fs = require('node:fs');
const path = require('node:path');
const validator = require(require.resolve('gltf-validator', {paths: [path.join(process.env.REPO, 'prototypes/voxel-work-bay/tools')]}));
const dir = process.argv[2];
(async () => {
  const files = fs.readdirSync(dir).filter(n => n.endsWith('.glb')).sort();
  if (!files.length) throw new Error('no GLBs in ' + dir);
  let bad = 0;
  for (const name of files) {
    const report = await validator.validateBytes(new Uint8Array(fs.readFileSync(path.join(dir, name))), {uri: name});
    const {numErrors, numWarnings} = report.issues;
    if (numErrors || numWarnings) {
      bad += 1;
      console.log(`${name}: ${numErrors} errors, ${numWarnings} warnings`);
      for (const m of report.issues.messages.slice(0, 5)) console.log('  ', m.code, m.message);
    }
  }
  console.log(`${files.length} GLBs checked, ${bad} with issues`);
  process.exitCode = bad ? 1 : 0;
})().catch(e => { console.error(e); process.exitCode = 1; });
"""


def validate(assets):
    """Runs the pinned Khronos validator over every GLB in `assets`."""
    return subprocess.run(["node", "-", str(assets)], input=VALIDATE, capture_output=True, text=True,
                          env={**os.environ, "REPO": str(REPO)})


def kit_case(here, pack):
    here, pack = Path(here), Path(pack)
    assets = pack / "assets"

    class Kit(unittest.TestCase):
        def test_every_reference_exists(self):
            style_path = pack / "style.json"
            if not style_path.exists():
                self.skipTest("the pack's style.json is not written yet")
            refs = list(references(json.loads(style_path.read_text())))
            self.assertGreater(len(refs), 20)
            for ref in refs:
                self.assertTrue((pack / ref).exists(), ref)

        def test_every_asset_meets_its_spec(self):
            self.assertGreater(len(specs(here)), 0, "the kit specifies its assets")
            for name, spec in specs(here).items():
                with self.subTest(asset=name):
                    path = assets / f"{name}.glb"
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
            known = set(specs(here))
            for path in assets.glob("*.glb"):
                self.assertIn(path.stem, known, f"{path.name} has no spec in specs/*.json")

        def test_planted_pieces_draw_with_two_materials_at_most(self):
            """The city plants these by the hundred: each material is a draw
            per copy per pass (tools/styles/shared/bake.py)."""
            for name in PLANTED:
                with self.subTest(asset=name):
                    mats = glb_json(assets / f"{name}.glb").get("materials", [])
                    self.assertLessEqual(len(mats), 2, [m.get("name") for m in mats])

        def test_glbs_pass_the_khronos_validator(self):
            if not any(assets.glob("*.glb")):
                self.skipTest("nothing built yet")
            result = validate(assets)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

        def test_the_committed_kit_is_what_the_generator_builds(self):
            """Every GLB, rebuilt from the generator in one run, matches the
            committed file byte for byte: the build is reproducible, and no
            edit to a shared module has silently changed or broken another
            asset."""
            blender = os.environ.get("BLENDER") or shutil.which("blender")
            if not blender or not specs(here):
                self.skipTest("Blender is not installed, or nothing is specified yet")
            with tempfile.TemporaryDirectory() as out:
                subprocess.run([blender, "--background", "--factory-startup", "--python-exit-code", "1",
                                "--python", str(here / "build.py"), "--", "--out", out],
                               check=True, capture_output=True)
                for built in sorted(Path(out).glob("*.glb")):
                    with self.subTest(asset=built.stem):
                        self.assertEqual(hashlib.sha256(built.read_bytes()).hexdigest(),
                                         hashlib.sha256((assets / built.name).read_bytes()).hexdigest(),
                                         f"{built.name} is stale or builds differently")

    return Kit
