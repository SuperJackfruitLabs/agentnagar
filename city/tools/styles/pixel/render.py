"""Renders the pixel kit's Blender models (models.KIT) into raw passes for
post.py: one `<name>.npz` and `<name>.json` per model.

blender --background --factory-startup --python-exit-code 1 \\
    --python city/tools/styles/pixel/render.py -- RAW_DIR [NAME_PREFIX ...]

**Camera.** Orthographic, looking north-west and down at 30° (yaw 45°).
At 30° the ground foreshortens exactly 2:1, so one metre east is (+16, +8)
px and one metre south (-16, +8) px, with 16·√2 px per metre across the
view. A true orthographic view would draw one metre up as 19.6 px; the
pack's iso() draws it as 16 px (tile_w 32, metre_up 16), so every model is
squashed vertically by √(2/3) before it is rendered. The world origin
lands exactly on a pixel corner (`origin` in the JSON), so every anchor is
an integer pixel.

**Passes.** Workbench, flat lighting, no anti-aliasing, fixed resolution:
each pixel is exactly one face. Four renders read four colour attributes
written per face corner (see post.py for their meaning): `id` (material,
variation), `cell` (the 1 m world cell), `loc` (the position in the cell)
and `nrm` (the normal). All geometry is first cut on every whole-metre
plane, so a face lies in one cell and cells are exact. The render buffers
are half floats; every value is encoded in [0, 1] and decoded with margin.
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "lowpoly"))
import lib  # noqa: E402
import models  # noqa: E402
import palette  # noqa: E402

S = 16.0 * math.sqrt(2.0)             # px per metre across the view
K = math.sqrt(2.0 / 3.0)               # vertical squash
RIGHT = Vector((1 / math.sqrt(2), 1 / math.sqrt(2), 0.0))
UP = Vector((-1 / (2 * math.sqrt(2)), 1 / (2 * math.sqrt(2)), math.sqrt(3) / 2))
BACK = RIGHT.cross(UP)                 # toward the camera: south-east and up
PAD = 3
MATERIAL_INDEX = {k: i + 1 for i, k in enumerate(palette.MATERIALS)}
SMOOTH = {k for k, v in palette.MATERIALS.items() if v.get("smooth")}
EPS = 1e-6


def setup():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.render_aa = "OFF"
    sh = sc.display.shading
    sh.light = "FLAT"
    sh.color_type = "VERTEX"
    sh.show_object_outline = False
    sh.show_cavity = False
    sh.show_shadows = False
    sh.show_specular_highlight = False
    sh.show_xray = False
    sh.show_backface_culling = False
    sc.render.film_transparent = True
    sc.render.dither_intensity = 0.0
    sc.render.resolution_percentage = 100
    sc.render.pixel_aspect_x = sc.render.pixel_aspect_y = 1.0
    sc.render.use_compositing = False
    sc.render.use_sequencer = False
    sc.view_settings.view_transform = "Raw"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.0
    sc.view_settings.gamma = 1.0
    im = sc.render.image_settings
    im.file_format = "OPEN_EXR"
    im.color_mode = "RGBA"
    im.color_depth = "32"
    im.exr_codec = "NONE"


def split_material(name):
    key, _, var = name.partition("|")
    return key, int(var) if var else 128


def prepare(obj):
    """Cuts the mesh on whole-metre planes, writes the four attributes and
    squashes it; returns its vertices (Blender axes, squashed)."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.transform(obj.matrix_world)
    obj.matrix_world = Matrix.Identity(4)
    for axis in range(3):
        cos = [v.co[axis] for v in bm.verts]
        if not cos:
            continue
        for k in range(math.floor(min(cos)) + 1, math.ceil(max(cos))):
            no = Vector((0, 0, 0))
            no[axis] = 1.0
            co = Vector((0, 0, 0))
            co[axis] = float(k)
            bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-5,
                                   plane_co=co, plane_no=no)
    bm.normal_update()
    layers = {n: bm.loops.layers.float_color.new(n) for n in ("id", "cell", "loc", "nrm")}
    mats = [split_material(m.name) if m else ("", 128) for m in me.materials]
    for f in bm.faces:
        key, var = mats[f.material_index] if f.material_index < len(mats) else ("", 128)
        if key not in MATERIAL_INDEX:
            raise KeyError(f"{obj.name}: unknown material {key!r}")
        c = f.calc_center_median()
        gx, gz, gy = c.x, -c.y, c.z
        kx, kz, ky = math.floor(gx + EPS), math.floor(gz + EPS), math.floor(gy + EPS)
        if not (-128 <= kx < 128 and -128 <= kz < 128 and -32 <= ky < 224):
            raise ValueError(f"{obj.name}: cell {(kx, kz, ky)} out of range")
        ident = (MATERIAL_INDEX[key] / 255.0, var / 255.0, 0.0, 1.0)
        cell = ((kx + 128) / 255.0, (kz + 128) / 255.0, (ky + 32) / 255.0, 1.0)
        smooth = key in SMOOTH
        for loop in f.loops:
            p = loop.vert.co
            loc = (min(max(p.x - kx, 0.0), 1.0), min(max(-p.y - kz, 0.0), 1.0), min(max(p.z - ky, 0.0), 1.0), 1.0)
            n = loop.vert.normal if smooth else f.normal
            if not smooth and f.normal.dot(BACK) < 0.0:
                # Thin open geometry seen from behind (fronds, canopies,
                # awnings): shade the side the camera sees.
                n = -n
            loop[layers["id"]] = ident
            loop[layers["cell"]] = cell
            loop[layers["loc"]] = loc
            loop[layers["nrm"]] = (n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0)
    for v in bm.verts:
        v.co.z *= K
    bm.to_mesh(me)
    bm.free()
    return [v.co.copy() for v in me.vertices]


def frame(points):
    """Resolution, origin pixel and camera for points (squashed)."""
    xs = [S * p.dot(RIGHT) for p in points]
    ys = [-S * p.dot(UP) for p in points]
    x0, x1 = math.floor(min(xs)) - PAD, math.ceil(max(xs)) + PAD
    y0, y1 = math.floor(min(ys)) - PAD, math.ceil(max(ys)) + PAD
    w, h = x1 - x0, y1 - y0
    cx, cy = -x0, -y0
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = w, h
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.sensor_fit = "HORIZONTAL"
    cam.ortho_scale = w / S
    cam.clip_start = 1.0
    cam.clip_end = 2000.0
    co = bpy.data.objects.new("cam", cam)
    sc.collection.objects.link(co)
    loc = RIGHT * ((w / 2 - cx) / S) + UP * ((cy - h / 2) / S) + BACK * 900.0
    basis = Matrix((RIGHT, UP, BACK)).transposed()
    co.matrix_world = Matrix.Translation(loc) @ basis.to_4x4()
    sc.camera = co
    return w, h, (cx, cy)


def render_pass(meshes, attr, path):
    for me in meshes:
        me.color_attributes.active_color_name = attr
    sc = bpy.context.scene
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(str(path), check_existing=False)
    w, h = img.size
    arr = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(arr)
    bpy.data.images.remove(img)
    Path(path).unlink()
    return np.flipud(arr.reshape(h, w, 4))


# The walking band (metres up), and how near a sprite's declared band
# shapes must hold its geometry (inside) and reach it (tight).
BAND = (0.25, 1.9)
INSIDE_M = 0.002
TIGHT_M = 0.005


def band_points(objs):
    """Where the models' geometry stands in the walking band: every vertex
    between its planes once each face is cut on them, as (x, z) in Godot
    axes about the origin (the ground point)."""
    points = []
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.transform(o.matrix_world)
        for h in BAND:
            bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-6,
                                   plane_co=Vector((0, 0, h)), plane_no=Vector((0, 0, 1)))
        points += [(v.co.x, -v.co.y) for v in bm.verts if BAND[0] - EPS <= v.co.z <= BAND[1] + EPS]
        bm.free()
    return points


def check_band(spec, objs):
    """Holds a model to the shapes its info declares in the walking band
    (`band_shapes`, about its origin before its turn by `facing`;
    things.py), as the collision audit reads its sprites: every point of it in the band inside one of them, and each
    reached by it on every side (a disc at its radius). A model changed
    without its shapes stops the build here."""
    shapes = spec["info"]["band_shapes"]
    t = math.radians(spec["info"].get("facing", 0))
    c, s = math.cos(t), math.sin(t)
    # Back in the model's own frame: the facing turns it clockwise.
    points = [(x * c + z * s, -x * s + z * c) for x, z in band_points(objs)]
    if not points and shapes:
        raise ValueError(f"{spec['name']}: nothing in the band, but it declares {shapes}")
    reached = [[math.inf, -math.inf, math.inf, -math.inf, 0.0] for _ in shapes]
    for x, z in points:
        inside = False
        for k, sh in enumerate(shapes):
            if sh[0] == "rect":
                _, x0, x1, z0, z1 = sh
                if x0 - INSIDE_M <= x <= x1 + INSIDE_M and z0 - INSIDE_M <= z <= z1 + INSIDE_M:
                    inside = True
                    r = reached[k]
                    r[0], r[1], r[2], r[3] = min(r[0], x), max(r[1], x), min(r[2], z), max(r[3], z)
            else:
                _, radius, cx, cz = sh
                d = math.hypot(x - cx, z - cz)
                if d <= radius + INSIDE_M:
                    inside = True
                    reached[k][4] = max(reached[k][4], d)
        if not inside:
            raise ValueError(f"{spec['name']}: ({x:.3f}, {z:.3f}) in the band lies outside its shapes {shapes}")
    for sh, r in zip(shapes, reached):
        edges = list(zip(sh[1:5], r[:4])) if sh[0] == "rect" else [(sh[1], r[4])]
        if any(abs(want - got) > TIGHT_M for want, got in edges):
            raise ValueError(f"{spec['name']}: its band shape {sh} is not what it draws there ({r})")


def render(spec, raw_dir):
    lib.reset()
    spec["build"]()
    bpy.context.view_layer.update()
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if "band_shapes" in spec["info"]:
        check_band(spec, objs)
    points = []
    for o in objs:
        points += prepare(o)
    w, h, origin = frame(points)
    meshes = [o.data for o in objs]
    base = raw_dir / spec["name"]
    passes = {a: render_pass(meshes, a, f"{base}.{a}.exr") for a in ("id", "cell", "loc", "nrm")}
    alpha = passes["id"][:, :, 3] > 0.5
    code = lambda a, c: np.rint(passes[a][:, :, c] * 255.0).astype(np.int32)  # noqa: E731
    cell = np.stack([code("cell", 0) - 128, code("cell", 1) - 128, code("cell", 2) - 32], -1)
    np.savez_compressed(
        f"{base}.npz",
        alpha=alpha,
        mat=np.where(alpha, code("id", 0), 0).astype(np.uint8),
        var=code("id", 1).astype(np.uint8),
        cell=np.where(alpha[..., None], cell, 0).astype(np.int16),
        loc=passes["loc"][:, :, :3].astype(np.float32),
        nrm=(passes["nrm"][:, :, :3] * 2.0 - 1.0).astype(np.float32),
    )
    Path(f"{base}.json").write_text(json.dumps({"name": spec["name"], "size": [w, h], "origin": list(origin),
                                                "params": spec["params"]}, sort_keys=True))
    print(f"pixel render: {spec['name']} {w}x{h}")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    raw_dir = Path(argv[0])
    raw_dir.mkdir(parents=True, exist_ok=True)
    wanted = argv[1:]
    setup()
    for spec in models.KIT:
        if wanted and not any(spec["name"].startswith(w) for w in wanted):
            continue
        render(spec, raw_dir)


main()
