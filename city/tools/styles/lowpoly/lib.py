"""Shared building blocks for the low-poly tropical kit (v2).

Blender is Z-up and the glTF exporter turns Blender +Y into -Z (Godot's
forward), so every piece faces Blender +Y unless its docstring says
otherwise. Units are metres. Every mesh is flat-shaded; each asset is merged
into as few objects as its animated or switchable parts allow, one material
slot per palette colour.

Colours are written in sRGB and converted to linear for the Principled BSDF,
so what the palette says is what the Godot pack shows.
"""
import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.geometry import tessellate_polygon

PALETTE = {
    # Building volumes: warm limewash, terracotta and clay.
    "limewash": "#F1E7D3",
    "limewash_shade": "#E2D3B8",
    "sandstone": "#DCC6A0",
    "stone": "#BFAE92",
    "stone_dark": "#9C8C74",
    "clay": "#C98552",
    "brick": "#B8643E",
    "terracotta": "#C4623A",
    "terracotta_light": "#D9774A",
    "terracotta_dark": "#9E4A2C",
    "copper": "#5E9E8A",
    "copper_light": "#7DB8A2",
    "copper_dark": "#44786A",
    # Accents.
    "jackfruit": "#F2B632",
    "jackfruit_dark": "#D6961E",
    "teal": "#2F8C8C",
    "teal_dark": "#1F6666",
    "coral": "#E07A5F",
    "pink": "#E88AA6",
    "cream": "#FFF6E0",
    "white": "#F4F1EA",
    "tram_red": "#C8453A",
    # Wood and metal.
    "wood": "#8A5A3B",
    "wood_light": "#B7875C",
    "wood_dark": "#5E3B26",
    "charcoal": "#2E2B2A",
    "iron": "#3B3A3C",
    "steel": "#7C8288",
    # Glass and light.
    "glass": "#34535F",
    "glass_light": "#5E8C98",
    "lamp_glow": "#FFD27A",
    "window_glow": "#FFC47A",
    "eye_glow": "#5FF4F2",
    "visor": "#15191F",
    # Greens: three for foliage, two for lawn.
    "leaf_dark": "#2F7A34",
    "leaf": "#3F8F3A",
    "leaf_light": "#6DB33F",
    "leaf_yellow": "#A7C94A",
    "grass": "#86B25E",
    "grass_dark": "#6F9C4B",
    # Ground and water.
    "paving": "#E4D2AE",
    "paving_light": "#EEDFC0",
    "paving_dark": "#CDB78F",
    "asphalt": "#6F6A64",
    "kerb": "#D9CDB6",
    "water": "#2D93A6",
    "water_light": "#4FB3C3",
    "soil": "#6B4A32",
    # People.
    "skin": "#C98E6B",
    "cloth": "#9AA6B2",
    "hair": "#3A2A1E",
    "book_a": "#7A3E48",
    "book_b": "#3E5C7A",
    "book_c": "#D9B44A",
}

# Materials that glow: emission strength in Blender units (Godot reads it
# as the material's emission; the pack scales it at night).
EMISSIVE = {"lamp_glow": 3.0, "window_glow": 1.5, "eye_glow": 4.0}
ROUGHNESS = {"glass": 0.12, "glass_light": 0.15, "water": 0.08, "water_light": 0.1, "copper": 0.5,
             "copper_light": 0.5, "copper_dark": 0.55, "visor": 0.2, "steel": 0.4, "iron": 0.5}
METALLIC = {"steel": 0.6, "copper": 0.25, "copper_light": 0.25, "copper_dark": 0.25}


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(name):
    h = PALETTE[name].lstrip("#")
    return [srgb_to_linear(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)]


def material(name):
    """The shared material for a palette colour (created once per scene)."""
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb(name), 1.0)
    bsdf.inputs["Roughness"].default_value = ROUGHNESS.get(name, 0.85)
    bsdf.inputs["Metallic"].default_value = METALLIC.get(name, 0.0)
    if name in EMISSIVE:
        bsdf.inputs["Emission Color"].default_value = (*rgb(name), 1.0)
        bsdf.inputs["Emission Strength"].default_value = EMISSIVE[name]
    return m


# ---- Scene helpers ----

def reset():
    """An empty scene: no objects, meshes, materials, armatures or actions."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.actions,
                  bpy.data.objects, bpy.data.cameras, bpy.data.lights, bpy.data.images):
        for item in list(block):
            block.remove(item)


def root(name):
    """An empty at the origin that parents an asset's parts."""
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    return e


def _object(name, bm, mats, parent=None, at=(0, 0, 0)):
    """Turns a bmesh into a flat-shaded object whose faces carry material
    indices into `mats` (a list of palette names)."""
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    for m in mats:
        me.materials.append(material(m))
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.location = at
    o.parent = parent
    return o


class Mesh:
    """Accumulates faceted geometry in one bmesh, one material slot per
    palette colour, and turns into a single object with `build()`."""

    def __init__(self):
        self.bm = bmesh.new()
        self.mats = []

    def slot(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _faces(self, verts, faces, mat):
        idx = self.slot(mat)
        vs = [self.bm.verts.new(v) for v in verts]
        out = []
        for f in faces:
            try:
                face = self.bm.faces.new([vs[i] for i in f])
            except ValueError:
                continue
            face.material_index = idx
            out.append(face)
        return out

    def box(self, size, at, mat, bevel=0.0, rot=None):
        """A box of `size` centred on `at`; `bevel` chamfers its edges;
        `rot` is an optional Matrix (3×3) applied about its centre."""
        sx, sy, sz = (s / 2 for s in size)
        v = [(x, y, z) for z in (-sz, sz) for y in (-sy, sy) for x in (-sx, sx)]
        f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        tmp = bmesh.new()
        tv = [tmp.verts.new(p) for p in v]
        for face in f:
            tmp.faces.new([tv[i] for i in face])
        if bevel > 0:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=min(bevel, min(size) / 2.05),
                            segments=1, affect="EDGES", profile=0.5)
        self._merge(tmp, mat, rot, at)

    def _merge(self, tmp, mat, rot, at):
        m = Matrix.Translation(Vector(at)) @ (rot.to_4x4() if rot is not None else Matrix.Identity(4))
        bmesh.ops.transform(tmp, matrix=m, verts=tmp.verts)
        idx = self.slot(mat)
        mapping = {}
        for tvx in tmp.verts:
            mapping[tvx] = self.bm.verts.new(tvx.co)
        for tf in tmp.faces:
            try:
                nf = self.bm.faces.new([mapping[x] for x in tf.verts])
                nf.material_index = idx
            except ValueError:
                pass
        tmp.free()

    def prism(self, profile, depth, at, mat, axis="y", rot=None):
        """A polygon `profile` [(u, v), ...] extruded `depth` along `axis`,
        centred on `at`. For axis y the profile lies in x (u) and z (v)."""
        tmp = bmesh.new()
        n = len(profile)
        h = depth / 2
        def p3(u, w, d):
            if axis == "y":
                return (u, d, w)
            if axis == "x":
                return (d, u, w)
            return (u, w, d)
        front = [tmp.verts.new(p3(u, w, -h)) for u, w in profile]
        back = [tmp.verts.new(p3(u, w, h)) for u, w in profile]
        tmp.faces.new(front)
        tmp.faces.new(list(reversed(back)))
        for k in range(n):
            tmp.faces.new([front[k], front[(k + 1) % n], back[(k + 1) % n], back[k]])
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        self._merge(tmp, mat, rot, at)

    def slab(self, outer, holes, thickness, at, mat, axis="y", reveal_mat=None, rot=None):
        """A flat slab whose face is `outer` [(u, v), ...] with `holes` cut
        through it, `thickness` deep along `axis` (y: u→x, v→z). The hole
        sides (reveals) take `reveal_mat` if given."""
        loops = [outer] + holes
        tris = tessellate_polygon([[Vector((u, v, 0)) for u, v in loop] for loop in loops])
        flat = [p for loop in loops for p in loop]
        h = thickness / 2
        def p3(u, w, d):
            if axis == "y":
                return (u, d, w)
            return (d, u, w)
        tmp = bmesh.new()
        front = [tmp.verts.new(p3(u, w, -h)) for u, w in flat]
        back = [tmp.verts.new(p3(u, w, h)) for u, w in flat]
        faces_front = []
        for a, b, c in tris:
            try:
                faces_front.append(tmp.faces.new([front[a], front[b], front[c]]))
                tmp.faces.new([back[c], back[b], back[a]])
            except ValueError:
                pass
        start = 0
        reveal_faces = []
        for li, loop in enumerate(loops):
            n = len(loop)
            for k in range(n):
                i, j = start + k, start + (k + 1) % n
                try:
                    f = tmp.faces.new([front[i], front[j], back[j], back[i]])
                    if li > 0:
                        reveal_faces.append(f)
                except ValueError:
                    pass
            start += n
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        if reveal_mat is not None:
            ri = self.slot(reveal_mat)
            mi = self.slot(mat)
            for f in tmp.faces:
                f.material_index = ri if f in reveal_faces else mi
            self._merge_indexed(tmp, rot, at)
        else:
            self._merge(tmp, mat, rot, at)

    def _merge_indexed(self, tmp, rot, at):
        m = Matrix.Translation(Vector(at)) @ (rot.to_4x4() if rot is not None else Matrix.Identity(4))
        bmesh.ops.transform(tmp, matrix=m, verts=tmp.verts)
        mapping = {tv: self.bm.verts.new(tv.co) for tv in tmp.verts}
        for tf in tmp.faces:
            try:
                nf = self.bm.faces.new([mapping[x] for x in tf.verts])
                nf.material_index = tf.material_index
            except ValueError:
                pass
        tmp.free()

    def cylinder(self, radius, depth, at, mat, sides=8, radius_top=None, rot=None, cap=True):
        """An upright faceted cylinder (or frustum) centred on `at`."""
        rt = radius if radius_top is None else radius_top
        tmp = bmesh.new()
        h = depth / 2
        bot = [tmp.verts.new((radius * math.cos(2 * math.pi * k / sides), radius * math.sin(2 * math.pi * k / sides), -h))
               for k in range(sides)]
        top = [tmp.verts.new((rt * math.cos(2 * math.pi * k / sides), rt * math.sin(2 * math.pi * k / sides), h))
               for k in range(sides)] if rt > 1e-6 else None
        if top is None:
            apex = tmp.verts.new((0, 0, h))
            for k in range(sides):
                tmp.faces.new([bot[k], bot[(k + 1) % sides], apex])
        else:
            for k in range(sides):
                tmp.faces.new([bot[k], bot[(k + 1) % sides], top[(k + 1) % sides], top[k]])
            if cap:
                tmp.faces.new(top)
        if cap:
            tmp.faces.new(list(reversed(bot)))
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        self._merge(tmp, mat, rot, at)

    def sphere(self, radius, at, mat, subdivisions=1, scale=(1, 1, 1), jitter=0.0, seed=0, hemisphere=False):
        """A faceted ico-sphere; `jitter` displaces vertices by up to that
        fraction of the radius (deterministic by `seed`) for foliage."""
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=subdivisions, radius=radius)
        if hemisphere:
            gone = [v for v in tmp.verts if v.co.z < -1e-4]
            bmesh.ops.delete(tmp, geom=gone, context="VERTS")
        rng = random.Random(seed)
        for v in tmp.verts:
            v.co.x *= scale[0]
            v.co.y *= scale[1]
            v.co.z *= scale[2]
            if jitter:
                v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * radius * jitter
        self._merge(tmp, mat, None, at)

    def dome(self, radius, at, mat, segments=16, rings=6, squash=1.0, ribs_mat=None):
        """A faceted hemisphere on `at` (optionally ribbed in `ribs_mat`)."""
        tmp = bmesh.new()
        grid = []
        for i in range(rings + 1):
            a = math.pi / 2 * i / rings
            ring = []
            for j in range(segments):
                b = 2 * math.pi * j / segments
                if i == rings:
                    ring = [None]
                    break
                ring.append(tmp.verts.new((math.cos(a) * math.cos(b) * radius, math.cos(a) * math.sin(b) * radius,
                                           math.sin(a) * radius * squash)))
            grid.append(ring)
        apex = tmp.verts.new((0, 0, radius * squash))
        for i in range(rings):
            for j in range(segments):
                j2 = (j + 1) % segments
                if i == rings - 1:
                    tmp.faces.new([grid[i][j], grid[i][j2], apex])
                else:
                    tmp.faces.new([grid[i][j], grid[i][j2], grid[i + 1][j2], grid[i + 1][j]])
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        self._merge(tmp, mat, None, at)
        if ribs_mat:
            for j in range(0, segments, 2):
                b = 2 * math.pi * j / segments
                for i in range(rings - 1):
                    a0 = math.pi / 2 * i / rings
                    a1 = math.pi / 2 * (i + 1) / rings
                    p0 = Vector((math.cos(a0) * math.cos(b), math.cos(a0) * math.sin(b), math.sin(a0) * squash)) * radius
                    p1 = Vector((math.cos(a1) * math.cos(b), math.cos(a1) * math.sin(b), math.sin(a1) * squash)) * radius
                    self.beam(Vector(at) + p0 * 1.01, Vector(at) + p1 * 1.01, 0.08, ribs_mat)

    def beam(self, a, b, thickness, mat, depth=None):
        """A square-section beam from point a to point b."""
        a, b = Vector(a), Vector(b)
        d = b - a
        length = d.length
        if length < 1e-6:
            return
        z = d.normalized()
        x = z.orthogonal().normalized()
        y = z.cross(x)
        rot = Matrix((x, y, z)).transposed()
        self.box((thickness, depth or thickness, length), (a + b) / 2, mat, rot=rot)

    def build(self, name, parent=None):
        return _object(name, self.bm, self.mats, parent)


def rotz(degrees):
    return Matrix.Rotation(math.radians(degrees), 3, "Z")


def rotx(degrees):
    return Matrix.Rotation(math.radians(degrees), 3, "X")


def roty(degrees):
    return Matrix.Rotation(math.radians(degrees), 3, "Y")


def arch(x0, x1, spring, rise=None, segments=8):
    """Points of a round arch over [x0, x1] springing at height `spring`,
    left to right (a hole outline's top)."""
    r = (x1 - x0) / 2
    rise = r if rise is None else rise
    cx = (x0 + x1) / 2
    return [(cx - math.cos(math.pi * k / segments) * r, spring + math.sin(math.pi * k / segments) * rise)
            for k in range(segments + 1)]


def arched_hole(x0, x1, sill, spring, rise=None, segments=8):
    """A hole outline: a rectangle from `sill` to `spring` topped by an arch,
    wound clockwise as tessellate_polygon expects for holes."""
    top = arch(x0, x1, spring, rise, segments)
    return [(x0, sill)] + top + [(x1, sill)]


def rect_hole(x0, x1, z0, z1):
    return [(x0, z0), (x0, z1), (x1, z1), (x1, z0)]


# ---- Export ----

def export(path, animations=False):
    """Writes the scene as a GLB the pinned Khronos validator accepts."""
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_yup=True,
                              export_apply=True, export_animations=animations,
                              export_cameras=False, export_lights=False,
                              export_extras=False, export_skins=animations,
                              export_morph=False)


def triangles():
    """Triangles in the scene's meshes, as the exporter will write them."""
    total = 0
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            for p in o.data.polygons:
                total += len(p.vertices) - 2
    return total
