"""The checks every 3D kit's tram meets (city tram spec §5), read from its
GLB in Godot axes (x along the tram, front at +x; y up; z to its right):

- the line's length (tram_layout.LENGTH_CM), at the kit's own width;
- a `roof` node the client fades in overhead views, an `interior` with a
  floor at tram_layout.FLOOR_CM and a seat under every seated slot, a
  `lights` node that lights it, and the `body`;
- a door on both sides at each of the layout's doors, each two leaves
  (`door_<left|right>_<k>_<fore|aft>`, k from the front) that slide apart;
- side windows in the body that a seated rider looks out of: their glass
  runs from at least WINDOW_BELOW_EYE below a seated rider's eyes
  (tram_layout.FLOOR_CM + SEATED_EYE_CM) to at least WINDOW_ABOVE_EYE
  above them.

A kit's test_assets.py: `Tram = tram_checks.tram_case(ASSETS / "tram.glb")`.
Standard library only.
"""
import json
import struct
import unittest
from pathlib import Path

import tram_layout

SIDES = ("left", "right")
LEAVES = ("fore", "aft")
# How far a side window's glass reaches below and above a seated rider's
# eyes (metres), so the view out takes in the platform and the street.
WINDOW_BELOW_EYE = 0.2
WINDOW_ABOVE_EYE = 0.5


def door_nodes():
    return [f"door_{side}_{k}_{leaf}" for side in SIDES for k in range(len(tram_layout.DOOR_TENTHS))
            for leaf in LEAVES]


def _chunks(path):
    data = Path(path).read_bytes()
    length = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + length])
    rest = data[20 + length:]
    blob = rest[8:8 + struct.unpack("<I", rest[:4])[0]] if rest else b""
    return doc, blob


def _matrix(node):
    if "matrix" in node:
        m = node["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    tx, ty, tz = node.get("translation", [0, 0, 0])
    qx, qy, qz, qw = node.get("rotation", [0, 0, 0, 1])
    sx, sy, sz = node.get("scale", [1, 1, 1])
    r = [[1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw)],
         [2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw)],
         [2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy)]]
    return [[r[i][0] * sx, r[i][1] * sy, r[i][2] * sz, t] for i, t in enumerate((tx, ty, tz))] + [[0, 0, 0, 1]]


def _mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def points(path):
    """Every mesh node's vertices in the GLB's frame (Godot axes), by the
    node's name: {name: [(x, y, z), ...]}."""
    doc, blob = _chunks(path)
    nodes = doc.get("nodes", [])
    out = {}

    def visit(i, parent):
        node = nodes[i]
        world = _mul(parent, _matrix(node))
        if "mesh" in node:
            pts = out.setdefault(node.get("name", str(i)), [])
            for prim in doc["meshes"][node["mesh"]]["primitives"]:
                acc = doc["accessors"][prim["attributes"]["POSITION"]]
                view = doc["bufferViews"][acc["bufferView"]]
                start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
                stride = view.get("byteStride", 12)
                for k in range(acc["count"]):
                    x, y, z = struct.unpack_from("<3f", blob, start + k * stride)
                    pts.append(tuple(sum(world[r][c] * v for c, v in enumerate((x, y, z, 1))) for r in range(3)))
        for c in node.get("children", []):
            visit(c, world)

    identity = [[1 if r == c else 0 for c in range(4)] for r in range(4)]
    for scene in doc.get("scenes", [{"nodes": list(range(len(nodes)))}]):
        for i in scene["nodes"]:
            visit(i, identity)
    return out


def material_points(path, node_name):
    """Node `node_name`'s vertices in the GLB's frame (Godot axes), by the
    name of each primitive's material: {material: [(x, y, z), ...]}."""
    doc, blob = _chunks(path)
    nodes = doc.get("nodes", [])
    materials = [m.get("name", str(i)) for i, m in enumerate(doc.get("materials", []))]
    out = {}

    def visit(i, parent):
        node = nodes[i]
        world = _mul(parent, _matrix(node))
        if "mesh" in node and node.get("name") == node_name:
            for prim in doc["meshes"][node["mesh"]]["primitives"]:
                name = materials[prim["material"]] if "material" in prim else ""
                pts = out.setdefault(name, [])
                acc = doc["accessors"][prim["attributes"]["POSITION"]]
                view = doc["bufferViews"][acc["bufferView"]]
                start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
                stride = view.get("byteStride", 12)
                for k in range(acc["count"]):
                    x, y, z = struct.unpack_from("<3f", blob, start + k * stride)
                    pts.append(tuple(sum(world[r][c] * v for c, v in enumerate((x, y, z, 1))) for r in range(3)))
        for c in node.get("children", []):
            visit(c, world)

    identity = [[1 if r == c else 0 for c in range(4)] for r in range(4)]
    for scene in doc.get("scenes", [{"nodes": list(range(len(nodes)))}]):
        for i in scene["nodes"]:
            visit(i, identity)
    return out


def bounds(pts):
    return [min(p[k] for p in pts) for k in range(3)], [max(p[k] for p in pts) for k in range(3)]


def tram_case(path):
    path = Path(path)

    class Tram(unittest.TestCase):
        @classmethod
        def setUpClass(cls):
            cls.parts = points(path) if path.exists() else {}

        def setUp(self):
            if not self.parts:
                self.skipTest(f"{path.name} is not built")

        def everything(self):
            return [p for pts in self.parts.values() for p in pts]

        def test_the_tram_is_the_lines_length_at_its_own_width(self):
            lo, hi = bounds([p for n, pts in self.parts.items() if n != "lights" for p in pts])
            self.assertAlmostEqual(hi[0] - lo[0], tram_layout.LENGTH_CM / 100.0, delta=0.06)
            self.assertAlmostEqual((hi[0] + lo[0]) / 2.0, 0.0, delta=0.03, msg="centred on its middle")
            self.assertTrue(2.2 <= hi[2] - lo[2] <= 2.6, f"{hi[2] - lo[2]:.2f} m wide")

        def test_it_has_a_body_a_roof_an_interior_and_lights(self):
            for name in ("body", "roof", "interior", "lights"):
                self.assertIn(name, self.parts, f"{path.name} has no {name}")
            roof_lo, _ = bounds(self.parts["roof"])
            self.assertGreater(roof_lo[1], 2.2, "the roof starts above the windows, so riders show from above")

        def test_a_seat_under_every_seated_slot(self):
            floor = tram_layout.FLOOR_CM / 100.0
            top = floor + tram_layout.SEAT_CM / 100.0
            pts = self.parts.get("interior", [])
            lo, hi = bounds(pts)
            self.assertAlmostEqual(lo[1], floor, delta=0.1, msg="the floor's top at the layout's floor")
            for x, left in tram_layout.seats_m():
                z = -left
                near = [p for p in pts if abs(p[0] - x) < 0.35 and abs(p[2] - z) < 0.4]
                self.assertTrue(near, f"no seat at ({x:.2f}, {z:.2f})")
                self.assertTrue(any(abs(p[1] - top) < 0.06 for p in near),
                                f"the seat at ({x:.2f}, {z:.2f}) is not {top:.2f} m high")

        def test_nothing_stands_in_the_doorways(self):
            floor = tram_layout.FLOOR_CM / 100.0
            for x0, x1 in tram_layout.doors_m():
                for p in self.parts.get("interior", []):
                    inside = x0 + 0.05 < p[0] < x1 - 0.05 and abs(p[2]) > 0.7 and floor + 0.05 < p[1] < 2.0
                    self.assertFalse(inside, f"the interior blocks the door {x0:.2f}..{x1:.2f} at {p}")

        def test_a_door_of_two_leaves_on_both_sides_at_each_of_the_layouts_doors(self):
            doors = tram_layout.doors_m()
            for name in door_nodes():
                self.assertIn(name, self.parts, f"{path.name} has no {name}")
                _, side, k, leaf = name.split("_")
                x0, x1 = doors[int(k)]
                lo, hi = bounds(self.parts[name])
                mid = (x0 + x1) / 2.0
                self.assertTrue(x0 - 0.1 <= lo[0] and hi[0] <= x1 + 0.1, f"{name} spans {lo[0]:.2f}..{hi[0]:.2f}")
                self.assertTrue(lo[0] >= mid - 0.06 if leaf == "fore" else hi[0] <= mid + 0.06,
                                f"{name} is its door's {leaf} leaf")
                self.assertTrue(hi[2] < 0 if side == "left" else lo[2] > 0, f"{name} on the {side}")
                self.assertTrue(hi[1] - lo[1] > 1.6, f"{name} is a door's height")

        def test_a_seated_rider_looks_out_of_the_side_windows(self):
            eye = (tram_layout.FLOOR_CM + tram_layout.SEATED_EYE_CM) / 100.0
            glass = [p for name, pts in material_points(path, "body").items() if name.startswith("glass")
                     for p in pts if abs(p[2]) > 1.0 and abs(p[0]) < tram_layout.LENGTH_CM / 200.0 - 1.0]
            self.assertTrue(glass, f"{path.name}'s body has no side glass")
            lo, hi = bounds(glass)
            self.assertLessEqual(lo[1], eye - WINDOW_BELOW_EYE,
                                 f"the windows start at {lo[1]:.2f} m, not {WINDOW_BELOW_EYE} m below a seated rider's eyes at {eye:.2f} m")
            self.assertGreaterEqual(hi[1], eye + WINDOW_ABOVE_EYE,
                                    f"the windows end at {hi[1]:.2f} m, not {WINDOW_ABOVE_EYE} m above a seated rider's eyes at {eye:.2f} m")

    return Tram

