"""A test composition of the voxel kit v2 on the district's layout
(city/fixtures/district): the workshop and library assembled from their
modules along their footprints, the square, trees, the tram, towers,
houses, the river and bridge, and static preview humans. Rendered from the
game's diagonal preset (yaw 32, pitch -36, 45 degree FOV, from the
south-east), a closer diagonal, a street view and top-down, into
previews/compose_*.png, for comparison with the 02-voxel sheets.

It also documents, in code, how the pack (task 4.2) can assemble the
modules: see workshop() and library().

blender --background --factory-startup --python-exit-code 1 \\
    --python city/tools/styles/voxel/compose.py -- [--open] [VIEW ...]

--open renders both buildings cut away (roofs hidden, near walls low).
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import humans  # noqa: E402
import palette  # noqa: E402
import stage  # noqa: E402
import voxel  # noqa: E402

ASSETS = HERE.parents[2] / "godot" / "styles" / "voxel" / "assets" / "v2"
OUT = HERE / "previews"
_collections = {}


def _collection(name):
    """The asset imported once into a hidden collection."""
    if name in _collections:
        return _collections[name]
    col = bpy.data.collections.new(f"asset_{name}")
    bpy.context.scene.collection.children.link(col)
    layer = bpy.context.view_layer.layer_collection.children[col.name]
    bpy.context.view_layer.active_layer_collection = layer
    path = ASSETS / f"{name}.glb"
    if not path.exists():
        path = OUT / "humans" / f"{name}.glb"
    bpy.ops.import_scene.gltf(filepath=str(path))
    layer.exclude = True
    bpy.context.view_layer.active_layer_collection = bpy.context.view_layer.layer_collection
    _collections[name] = col
    return col


def put(name, x, y, z, rot=0.0, tag=None):
    """Instance an asset at Godot (x, y, z), turned `rot` degrees about y
    (Godot's rotation.y, counter-clockwise seen from above)."""
    inst = bpy.data.objects.new(f"{name}", None)
    inst.instance_type = "COLLECTION"
    inst.instance_collection = _collection(name)
    inst.location = (x, -z, y)
    inst.rotation_euler = (0, 0, math.radians(rot))
    bpy.context.scene.collection.objects.link(inst)
    if tag:
        inst["tag"] = tag
    return inst


# ---- Buildings, assembled the way the pack can ----

def side_modules(length, door_at=None, door_w=4.0, pattern=("wall",), unit=4.0, half=2.0):
    """Modules along a side of `length` m: (offset of centre from the side's
    start, kind, width). A door bay of `door_w` centred at `door_at`, the
    rest filled with `unit` modules following `pattern`, and `half`
    fillers where the door breaks the unit grid."""
    out = []

    def fill(a, b):
        n = 0
        while b - a >= unit - 1e-6:
            out.append((a + unit / 2, pattern[n % len(pattern)], unit))
            a += unit
            n += 1
        if b - a >= half - 1e-6:
            out.append((a + half / 2, "half", half))

    if door_at is None:
        fill(0.0, length)
    else:
        fill(0.0, door_at - door_w / 2)
        out.append((door_at, "door", door_w))
        fill(door_at + door_w / 2, length)
    return out


# Side -> (rotation of a wall module, start corner, direction along).
def _sides(x0, z0, x1, z1):
    return {
        "north": (0.0, (x0, z0), (1, 0), x1 - x0),
        "south": (180.0, (x1, z1), (-1, 0), x1 - x0),
        "west": (90.0, (x0, z1), (0, -1), z1 - z0),
        "east": (-90.0, (x1, z0), (0, 1), z1 - z0),
    }


def _corners(x0, z0, x1, z1):
    return [((x0, z0), 0.0), ((x1, z0), -90.0), ((x1, z1), 180.0), ((x0, z1), 90.0)]


def workshop(open_=False, near=("east", "south")):
    """The guild hall, footprint x -34..-18, z -14..10 (workshop and
    commons): 5 m walls in 4 m bays (2 m fillers around the door), the
    plaza door on the east side at z = -6, sawtooth teeth arrayed along z
    with ridges along x (the profile shows on the east and west ends),
    rising to the south so the glass strips face the square's diagonal
    camera, as on the sheets. A roof bay turned -90 degrees runs its ridge
    toward -x, so it is placed at the bay's east end."""
    x0, z0, x1, z1 = -34.0, -14.0, -18.0, 10.0
    H = 5.0
    doors = {"east": -6.0 - z0}
    kinds = {"wall": "ws_wall", "window": "ws_window", "glazed": "ws_wall_glazed", "door": "ws_door",
             "half": "ws_wall_half"}
    lows = {"wall": "ws_wall_low", "window": "ws_wall_low", "glazed": "ws_wall_low", "door": "ws_door_low",
            "half": "ws_wall_low_half"}
    for side, (rot, (sx, sz), (dx, dz), length) in _sides(x0, z0, x1, z1).items():
        pattern = ("window", "glazed") if side in ("north", "south") else ("window", "wall")
        for off, kind, _ in side_modules(length, doors.get(side), pattern=pattern):
            name = (lows if open_ and side in near else kinds)[kind]
            put(name, sx + dx * off, 0, sz + dz * off, rot)
    for (cx, cz), rot in _corners(x0, z0, x1, z1):
        low = open_ and (("north" if cz == z0 else "south") in near or ("west" if cx == x0 else "east") in near)
        put("ws_corner_low" if low else "ws_corner", cx, 0, cz, rot)
    if open_:
        return  # the sign goes with the east wall it hangs on
    put("ws_sign", x1, 3.5, -6.0, -90.0)
    for zc in range(int(z0) + 2, int(z1), 4):
        for xs in range(int(x0), int(x1), 4):
            put("ws_roof_bay", xs + 4, H, zc, -90.0)
        put("ws_gable", x0 + 0.3, H, zc, -90.0)
        put("ws_gable", x1, H, zc, -90.0)


def library(open_=False, near=("west", "south")):
    """The library, footprint x 18..36, z -12..8 (the reading room): 6 m
    orange walls in 2 m modules, the 4 m entrance on the west side at
    z = -2, the barrel vault's axis along z (spanning the 18 m width), a
    white end cap at each end and 2 m segments between."""
    x0, z0, x1, z1 = 18.0, -12.0, 36.0, 8.0
    H = 6.0
    doors = {"west": z1 - (-2.0)}
    for side, (rot, (sx, sz), (dx, dz), length) in _sides(x0, z0, x1, z1).items():
        mods = side_modules(length, doors.get(side), pattern=("plain", "wall"), unit=2.0, half=2.0)
        for off, kind, _ in mods:
            if open_ and side in near:
                name = "lib_entrance_low" if kind == "door" else "lib_wall_low"
            else:
                name = {"door": "lib_entrance", "plain": "lib_wall_plain", "wall": "lib_wall"}[kind]
            put(name, sx + dx * off, 0, sz + dz * off, rot)
    for (cx, cz), rot in _corners(x0, z0, x1, z1):
        low = open_ and (("north" if cz == z0 else "south") in near or ("west" if cx == x0 else "east") in near)
        put("lib_corner_low" if low else "lib_corner", cx, 0, cz, rot)
    if open_:
        return  # the sign goes with the west wall it hangs on
    put("lib_sign", x0, 4.3, -2.0, 90.0)
    cx = (x0 + x1) / 2
    put("lib_vault_end", cx, H, z0, 0.0)
    z = z0 + 4.0
    while z < z1 - 4.0 - 1e-6:
        put("lib_vault", cx, H, z, 0.0)
        z += 2.0
    put("lib_vault_end", cx, H, z1, 180.0)


# ---- Ground and scenery ----

def tiles(x0, z0, x1, z1, pick, step=2.0, y=0.0, skip=()):
    z = z0 + step / 2
    while z < z1:
        x = x0 + step / 2
        while x < x1:
            if not any(a <= x < c and b <= z < d for (a, b, c, d) in skip):
                name = pick(x, z)
                if name:
                    put(name, x, y, z)
            x += step
        z += step


def paving(x, z):
    u = voxel.unit("pave", int(x // 2), int(z // 2))
    return "paving_a" if u < 0.45 else ("paving_b" if u < 0.9 else "paving_c")


def scenery():
    footprints = [(-34, -14, -18, 10), (18, -12, 36, 8)]
    park = (-34, 16, -18, 30)
    # Paving: the square, the tram stop, the terrace and the district edges.
    tiles(-36, -16, 38, 19, paving, skip=footprints + [park])
    tiles(*park, lambda x, z: "path_garden" if abs(z - 23) < 1 else "lawn_tile")
    # Streets: north z -22..-16, south z 22..26, the bridge approach.
    tiles(-44, -22, 50, -16, lambda x, z: "street_dash" if abs(z + 19) < 1 and int(x) % 4 == 0 else "street_tile")
    tiles(-18, 22, 50, 26, lambda x, z: "street_tile")
    tiles(-44, 22, -34, 26, lambda x, z: "street_tile")
    for x in (-16, 20):
        put("crosswalk", x, 0.005, -19)
    # Tram track and the tram at the stop.
    for x in range(-16, 50, 2):
        put("tram_track", x + 1, 0, 20.5)
    put("tram", 6, 0.1, 20.5)
    put("tram_shelter", -7, 0, 17.4, 180)
    put("tram_shelter", 7, 0, 17.4, 180)
    # River, quays, bridge.
    tiles(-70, -44, -44, 56, lambda x, z: "water_tile", step=4.0, y=-2.0)
    for z in range(-44, 56, 2):
        put("quay", -44, 0, z + 1, -90)
        put("quay", -70, 0, z + 1, 90)
    for x in range(-72, -42, 4):
        put("bridge_span", x + 2, 0, 24)
    for x in (-62, -54):
        put("bridge_pier", x, 0, 24)
    # Blocks.
    put("tower_a", -12.5, 0, -34.5)
    put("tower_b", 7.5, 0, -34.5, 90)
    put("tower_a", 27.5, 0, -34.5, 180)
    put("tower_b", -32, 0, -34.5, 0)
    put("tower_a", 46, 0, -34.5, 90)
    put("house_b", -39.5, 0, -9, -90)
    put("house_a", -39.5, 0, 1, -90)
    for n, x in enumerate((-7, -1, 11, 17, 29, 35)):
        put(("house_a", "house_b", "shop_a")[n % 3], x, 0, 31.5, 180)
    put("shop_a", 42, 0, -7.5, 90)
    put("shop_a", 42, 0, 2.5, 90)
    # Trees.
    put("tree_large", 0, 0, 0)
    for n, x in enumerate(range(-17, 18, 6)):
        put("tree_medium" if n % 2 else "tree_small", x, 0, -15)
    for n, x in enumerate(range(-15, 49, 6)):
        put("tree_small" if n % 2 else "tree_medium", x, 0, 27)
    for n, (x, z) in enumerate(((-31, 18), (-25, 19), (-21, 18), (-31, 28), (-26, 28), (-21, 27.5))):
        put(("tree_medium", "tree_small", "tree_medium")[n % 3], x, 0, z)
    # Square furniture.
    for n in range(10):
        a = 2 * math.pi * n / 10
        x, z = 4.5 * math.cos(a), 4.5 * math.sin(a)
        put("bench", x, 0, z, math.degrees(math.atan2(-math.cos(a), -math.sin(a))) + 180)
    for (x, z) in ((-12, -10), (12, -10), (-12, 10), (12, 10), (0, -12), (0, 12)):
        put("lamp", x, 0, z)
    for (x, z) in ((-16, -12), (16, -12), (-16, 12), (16, 12)):
        put("planter", x, 0, z)
    for (x, z) in ((-8, -12), (8, -12), (-8, 12), (8, 12)):
        put("flowerbed", x, 0, z)
    for x in range(-16, 17, 3):
        put("bollard", x + 0.15, 0, 18.6)
    for (x, z) in ((-12, 0), (12, 0)):
        put("planter_long", x, 0, z, 90)
    # Café terrace.
    for x in (-31, -27, -23):
        put("cafe_table", x, 0, 13)
        put("umbrella", x, 0, 13)
        put("cafe_chair", x - 0.9, 0, 13, -90)
        put("cafe_chair", x + 0.9, 0, 13, 90)


def people(n, seed="plaza"):
    """Static preview humans scattered on the square and the stop."""
    out = OUT / "humans"
    out.mkdir(parents=True, exist_ok=True)
    for v in humans.VARIANTS:
        path = out / f"human_{v}.glb"
        a = humans.static(v)
        path.write_bytes(voxel.glb_bytes(a.name, a.meshes(), palette.PALETTE, palette.PROPS))
    names = sorted(humans.VARIANTS)
    placed = 0
    t = 0
    while placed < n and t < n * 20:
        t += 1
        x = -17 + 34 * voxel.unit(seed, "x", t)
        z = -13 + 31 * voxel.unit(seed, "z", t)
        if math.hypot(x, z) < 5.5 or (abs(x) > 11 and abs(z) < 1.5) or 14.5 < z < 18.2 and abs(abs(x) - 7) < 2.5:
            continue
        v = names[int(voxel.unit(seed, "v", t) * len(names))]
        put(f"human_{v}", x, 0, z, 360 * voxel.unit(seed, "r", t))
        placed += 1


VIEWS = {
    # Godot target, distance, yaw, pitch (the rig's diagonal is 32 / -36).
    "diagonal": ((1.0, 0.0, 6.0), 78.0, 32.0, -36.0),
    "diagonal_near": ((2.0, 0.0, 2.0), 42.0, 32.0, -36.0),
    "street": ((0.0, 1.7, 17.0), 0.0, 0.0, -2.0),
    "topdown": ((-4.0, 0.0, 4.0), 110.0, 0.0, -89.0),
}


def render(view, suffix):
    target, dist, yaw, pitch = VIEWS[view]
    y, p = math.radians(yaw), math.radians(-pitch)
    off = (dist * math.cos(p) * math.sin(y), dist * math.sin(p), dist * math.cos(p) * math.cos(y))
    tx, ty, tz = target
    if view == "street":
        loc = Vector((tx, -tz, ty))
        aim = Vector((tx - 2.0, -(tz - 30.0), ty + 1.2))
    else:
        loc = Vector((tx + off[0], -(tz + off[2]), ty + off[1]))
        aim = Vector((tx, -tz, ty))
    cam = stage.camera(loc, aim)
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(45 if view != "street" else 55)
    bpy.context.scene.render.filepath = str(OUT / f"compose_{view}{suffix}.png")
    bpy.ops.render.render(write_still=True)
    print(f"compose: {view}{suffix}")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    open_ = "--open" in argv
    views = [a for a in argv if a in VIEWS] or list(VIEWS)
    OUT.mkdir(exist_ok=True)
    stage.reset()
    stage.setup(1600, 1000)
    # Lawn either side of the river (x -70..-44), which lies lower.
    for (x0, x1) in ((-44, 300), (-300, -70)):
        g = stage.ground(1, colour=(0.2, 0.5, 0.13))
        g.scale = (x1 - x0, 600, 1)
        g.location.x = (x0 + x1) / 2
    workshop(open_)
    library(open_)
    scenery()
    people(70)
    for view in views:
        render(view, "_open" if open_ else "")


main()
