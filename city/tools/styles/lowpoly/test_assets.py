"""Checks the low-poly tropical kit: every style.json reference exists, the
characters have every part the pack animates, every GLB passes the pinned
Khronos validator, and every v2 asset meets its spec in specs/*.json: its
bounding size within 10% of the target on each axis (Godot axes: x, y up,
z), its triangle budget, and its named nodes and animations. The skinned v2
characters are also posed from their animation data: one shared skeleton,
seamless loops, heights, feet on the floor and the seated conventions the
pack relies on.

python3 -m unittest city/tools/styles/lowpoly/test_assets.py
"""
import json
import sys
import math
import struct
import subprocess
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
PACK = HERE.parents[2] / "godot" / "styles" / "lowpoly_tropical"
# The catalogue the core carries: StylePack.required() takes its "props"
# keys from the same file, one per kind.
CATALOGUE = HERE.parents[2] / "catalogue" / "catalogue.json"
ASSETS = PACK / "assets"
sys.path.insert(0, str(HERE.parent / "shared"))
import tram_checks  # noqa: E402

# The tram: the line's length, doors that open, an interior with its seats
# under the shared layout's slots (tools/styles/shared/tram_checks.py).
Tram = tram_checks.tram_case(ASSETS / "tram.glb")


def glb_json(path):
    data = path.read_bytes()
    length = struct.unpack("<I", data[12:16])[0]
    return json.loads(data[20:20 + length])


def node_names(path):
    return {n.get("name") for n in glb_json(path).get("nodes", [])}


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


def glb_stats(path):
    """(bounding size [x, y, z], triangle count) of a GLB's meshes in their
    rest pose."""
    g = glb_json(path)
    nodes = g.get("nodes", [])
    lo = [math.inf] * 3
    hi = [-math.inf] * 3
    tris = 0

    def visit(i, parent):
        nonlocal tris
        node = nodes[i]
        world = _mat_mul(parent, _local(node))
        if "mesh" in node:
            for prim in g["meshes"][node["mesh"]]["primitives"]:
                acc = g["accessors"][prim["attributes"]["POSITION"]]
                count = g["accessors"][prim["indices"]]["count"] if "indices" in prim else acc["count"]
                tris += count // 3
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
    scene = g["scenes"][g.get("scene", 0)]
    for i in scene["nodes"]:
        visit(i, identity)
    return [hi[k] - lo[k] for k in range(3)], tris


def glb_accessor(path, index):
    """The float values of accessor `index` in a GLB, as tuples."""
    data = path.read_bytes()
    jlen = struct.unpack("<I", data[12:16])[0]
    g = json.loads(data[20:20 + jlen])
    blob = data[20 + jlen + 8:]
    acc = g["accessors"][index]
    assert acc["componentType"] == 5126, "expected float accessor"
    view = g["bufferViews"][acc["bufferView"]]
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[acc["type"]]
    stride = view.get("byteStride", 4 * width)
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    return [struct.unpack_from(f"<{width}f", blob, start + k * stride) for k in range(acc["count"])]


def _sample(times, values, t, rotation):
    if t <= times[0]:
        return values[0]
    if t >= times[-1]:
        return values[-1]
    k = next(i for i in range(1, len(times)) if times[i] >= t)
    f = (t - times[k - 1]) / (times[k] - times[k - 1])
    a, b = values[k - 1], values[k]
    if rotation and sum(x * y for x, y in zip(a, b)) < 0:
        b = [-x for x in b]
    v = [x + (y - x) * f for x, y in zip(a, b)]
    if rotation:
        n = math.sqrt(sum(x * x for x in v))
        v = [x / n for x in v]
    return v


def joint_positions(path, animation=None, t=0.0):
    """World positions (Godot axes) of every named node, in the rest pose or
    posed by `animation` at time `t`."""
    g = glb_json(path)
    nodes = [dict(n) for n in g.get("nodes", [])]
    if animation is not None:
        anim = next(a for a in g["animations"] if a["name"] == animation)
        for ch in anim["channels"]:
            s = anim["samplers"][ch["sampler"]]
            times = [x[0] for x in glb_accessor(path, s["input"])]
            values = glb_accessor(path, s["output"])
            path_ = ch["target"]["path"]
            nodes[ch["target"]["node"]][path_] = _sample(times, values, t, path_ == "rotation")
    out = {}

    def visit(i, parent):
        world = _mat_mul(parent, _local(nodes[i]))
        out[nodes[i].get("name")] = [world[r][3] for r in range(3)]
        for c in nodes[i].get("children", []):
            visit(c, world)

    identity = [[1 if r == c else 0 for c in range(4)] for r in range(4)]
    for i in g["scenes"][g.get("scene", 0)]["nodes"]:
        visit(i, identity)
    return out


def animation_times(path, animation):
    g = glb_json(path)
    anim = next(a for a in g["animations"] if a["name"] == animation)
    return sorted({x[0] for s in anim["samplers"] for x in glb_accessor(path, s["input"])})


def specs():
    out = {}
    for f in sorted((HERE / "specs").glob("*.json")):
        out.update(json.loads(f.read_text()))
    return out


def references(style):
    for section, entries in style.items():
        if isinstance(entries, dict):
            for entry in entries.values():
                if isinstance(entry, dict):
                    for key in ("scene", "icon", "texture", "obstacle_scene"):
                        if key in entry:
                            yield entry[key]


class LowPolyKit(unittest.TestCase):
    def setUp(self):
        self.style = json.loads((PACK / "style.json").read_text())

    def test_every_reference_exists(self):
        refs = list(references(self.style))
        self.assertGreater(len(refs), 20)
        for ref in refs:
            self.assertTrue((PACK / ref.removeprefix("./")).exists(), ref)

    def test_every_required_key_is_mapped(self):
        required = {
            "occupants": ["GuildAgent", "CityRoleAgent", "PersonalAgent", "SimCitizen", "Human"],
            "seats": ["desk", "workstation", "bench", "cafe-table", "reading-chair"],
            "rooms": ["workshop", "commons", "reading-room", "cafe", "plaza", "cafe-terrace", "park", "tram-stop"],
            "exteriors": ["guild-hall", "library", "cafe"],
            # Every catalogue kind, as the pack contract requires, and the
            # railing pieces the pack fences with.
            "props": [k["id"] for k in json.loads(CATALOGUE.read_text())["kinds"]]
                     + ["railing", "railing-post"],
            "headlines": ["Working", "Waiting", "Queued", "Idle", "Done", "Present",
                          "Offline", "Error", "Stale", "Unknown"],
            "badges": ["Ai", "Simulation"],
        }
        for section, keys in required.items():
            for key in keys:
                self.assertIn(key, self.style[section], f"{section}/{key}")
        self.assertEqual(self.style["declared_placeholders"], [])

    def test_icons_are_square_pngs(self):
        for name in self.style["headlines"].values():
            png = PACK / name["icon"]
            self.assertEqual(png.read_bytes()[:8], b"\x89PNG\r\n\x1a\n")
            w, h = struct.unpack(">II", png.read_bytes()[16:24])
            self.assertEqual((w, h), (64, 64))

    def test_every_v2_asset_meets_its_spec(self):
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

    def test_glbs_pass_the_khronos_validator(self):
        result = subprocess.run(["bash", str(HERE / "validate.sh")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


BONES = {"hips", "spine", "chest", "neck", "head"} | {
    f"{b}_{side}" for b in ("upper_arm", "forearm", "hand", "thigh", "shin", "foot") for side in "lr"}
ACTIONS = {"walk", "sit", "idle", "typing"}
CHARACTERS = {"character_human": (1.65, 1.8), "character_robot": (1.55, 1.7)}
SEAT_HEIGHT = 0.45


class CharactersV2(unittest.TestCase):
    """The skinned characters (task 2.3): one bone set for every kind, the
    four actions as seamless loops, and the poses the pack relies on. Godot
    axes: y up, the character faces -z."""

    def each(self):
        return [(name, ASSETS / f"{name}.glb", lo, hi) for name, (lo, hi) in CHARACTERS.items()]

    def setUp(self):
        for name, path, _, _ in self.each():
            self.assertTrue(path.exists(), f"{name}.glb has not been built")

    def test_one_skin_with_the_shared_bones(self):
        for name, path, _, _ in self.each():
            with self.subTest(character=name):
                g = glb_json(path)
                skins = g.get("skins", [])
                self.assertEqual(len(skins), 1, "one armature per character")
                joints = {g["nodes"][j]["name"] for j in skins[0]["joints"]}
                self.assertEqual(joints, BONES)
                skinned = [n["name"] for n in g["nodes"] if "mesh" in n]
                self.assertTrue(all("skin" in n for n in g["nodes"] if "mesh" in n), skinned)

    def test_height_in_range(self):
        for name, path, lo, hi in self.each():
            with self.subTest(character=name):
                height = glb_stats(path)[0][1]
                self.assertTrue(lo <= height <= hi, f"{name}: {height:.3f} m, want {lo}-{hi} m")

    def test_actions_are_named_and_loop_seamlessly(self):
        for name, path, _, _ in self.each():
            with self.subTest(character=name):
                g = glb_json(path)
                self.assertEqual({a["name"] for a in g.get("animations", [])}, ACTIONS)
                for anim in g["animations"]:
                    for ch in anim["channels"]:
                        s = anim["samplers"][ch["sampler"]]
                        values = glb_accessor(path, s["output"])
                        first, last = values[0], values[-1]
                        if ch["target"]["path"] == "rotation" and sum(a * b for a, b in zip(first, last)) < 0:
                            last = [-x for x in last]
                        self.assertTrue(all(abs(a - b) < 1e-4 for a, b in zip(first, last)),
                                        f"{anim['name']}: {g['nodes'][ch['target']['node']]['name']} jumps at the loop")
                self.assertAlmostEqual(animation_times(path, "walk")[-1], 1.0, places=3)
                self.assertAlmostEqual(animation_times(path, "typing")[-1], 1.0, places=3)

    def test_walk_swings_the_legs_and_keeps_a_foot_down(self):
        for name, path, _, _ in self.each():
            with self.subTest(character=name):
                rest = joint_positions(path)
                ankle = rest["foot_l"][1]
                reach = []
                for t in animation_times(path, "walk"):
                    p = joint_positions(path, "walk", t)
                    low = min(p["foot_l"][1], p["foot_r"][1])
                    self.assertGreater(low, ankle - 0.02, f"t={t:.2f}: a foot sinks into the floor")
                    self.assertLess(low, ankle + 0.06, f"t={t:.2f}: both feet in the air")
                    reach.append(p["foot_l"][2] - p["foot_r"][2])
                self.assertGreater(max(reach) - min(reach), 0.5, "the stride is too short")

    def test_sit_and_typing_sit_on_the_seat_with_feet_on_the_floor(self):
        for name, path, _, _ in self.each():
            with self.subTest(character=name):
                rest = joint_positions(path)
                for action in ("sit", "typing"):
                    p = joint_positions(path, action, 0.0)
                    for side in "lr":
                        hip, knee, ankle = p[f"thigh_{side}"], p[f"shin_{side}"], p[f"foot_{side}"]
                        self.assertTrue(SEAT_HEIGHT < hip[1] < SEAT_HEIGHT + 0.15, f"{action}: hip at {hip[1]:.2f} m")
                        self.assertLess(abs(knee[1] - hip[1]), 0.08, f"{action}: thigh not level")
                        self.assertLess(knee[2], hip[2] - 0.3, f"{action}: knee not forward")
                        self.assertLess(abs(ankle[1] - rest[f"foot_{side}"][1]), 0.02, f"{action}: foot off the floor")
                        self.assertLess(abs(hip[2]), 0.12, f"{action}: seat not over the origin")
                p = joint_positions(path, "typing", 0.0)
                for side in "lr":
                    hand = p[f"hand_{side}"]
                    self.assertLess(hand[2], p["chest"][2] - 0.2, "typing: hands not forward")
                    self.assertTrue(0.6 < hand[1] < 0.9, f"typing: hands at {hand[1]:.2f} m, want desk height")


if __name__ == "__main__":
    unittest.main()
