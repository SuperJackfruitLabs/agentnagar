"""Bakes a kit piece's palette colours into vertex colours, so the many
copies the city places draw with a few materials instead of one per
colour: every material is a draw per copy per pass, so a house of fifteen
colours cost fifteen draws. Each face keeps its colour as a vertex colour
the material multiplies in.

- Plain colours merge into `baked_r<roughness>_m<metallic>` materials,
  grouped by roughness and metallic, each to the nearest quarter.
- Leaf cards merge into one masked `foliage_leaves`.
- Materials the game drives by name keep their own surface: glass, lit
  windows, lamps and their glow, neon, screens, the paving rain wets, and
  anything that glows.

The build drivers bake every piece that is not animated (people and
robots are painted part by part at runtime).
"""
import bpy

import foliage

CARDS = "foliage_leaves"
# Materials the game finds by name (KitTown._collect, Pack3D.WET_MATERIALS,
# the lit packs' neon and room glass): never merged.
KEEP = ("glass", "window_glow", "lamp_glow", "fairy_glow", "light", "neon", "screen", "paving", "asphalt",
        "kerb", "road", "path", "street")


def _info(m):
    """(linear rgb, group) of a kit material: its group is CARDS for a leaf
    card, None to keep it as it is, else the plain group's name."""
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    if m.name.endswith("_leaves"):
        for n in nt.nodes:
            if n.bl_idname == "ShaderNodeMix":
                return tuple(n.inputs["B"].default_value)[:3], CARDS, bsdf.inputs["Roughness"].default_value
    glows = bsdf.inputs["Emission Strength"].default_value > 0.0
    if m.name.startswith(KEEP) or glows or bsdf.inputs["Base Color"].is_linked:
        return None, None, 0.0
    rough = round(bsdf.inputs["Roughness"].default_value * 4) / 4
    metal = round(bsdf.inputs["Metallic"].default_value * 4) / 4
    return tuple(bsdf.inputs["Base Color"].default_value)[:3], "baked_r%d_m%d" % (int(rough * 100), int(metal * 100)), rough


def _vertex_colour_material(name, rough):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    cards = name == CARDS
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    col = nt.nodes.new("ShaderNodeVertexColor")
    col.layer_name = "Col"
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = int(name.rsplit("_m", 1)[1]) / 100 if "_m" in name else 0.0
    if not cards:
        nt.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
        return m
    # The leaf texture times the vertex colour, alpha cut as foliage.py's
    # cards (the pattern the glTF exporter writes as alphaMode MASK).
    m.use_backface_culling = True
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = foliage.leaf_image()
    tex.interpolation = "Linear"
    tex.extension = "EXTEND"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(tex.outputs["Color"], mix.inputs["A"])
    nt.links.new(col.outputs["Color"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    below = nt.nodes.new("ShaderNodeMath")
    below.operation = "LESS_THAN"
    nt.links.new(tex.outputs["Alpha"], below.inputs[0])
    below.inputs[1].default_value = foliage.CUTOFF
    keep = nt.nodes.new("ShaderNodeMath")
    keep.operation = "SUBTRACT"
    keep.inputs[0].default_value = 1.0
    nt.links.new(below.outputs[0], keep.inputs[1])
    nt.links.new(keep.outputs[0], bsdf.inputs["Alpha"])
    return m


def bake(obj):
    """Bakes `obj`'s plain and leaf-card colours into its vertex colours and
    merges those materials; kept materials stay as they are."""
    me = obj.data
    if not me.materials or not me.polygons:
        return
    info = [_info(m) if m is not None else (None, None, 0.0) for m in me.materials]
    if all(i[1] is None for i in info):
        return
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for p in me.polygons:
        rgb = info[p.material_index][0] or (1.0, 1.0, 1.0)
        for li in p.loop_indices:
            attr.data[li].color = (*rgb, 1.0)
    me.color_attributes.active_color = attr
    # The new slots, in first use: kept materials as they are, groups merged.
    slots, where = [], {}
    old = list(me.materials)
    for p in me.polygons:
        rgb, group, rough = info[p.material_index]
        key = group if group is not None else ("keep", p.material_index)
        if key not in where:
            where[key] = len(slots)
            slots.append(_vertex_colour_material(group, rough) if group is not None else old[p.material_index])
    faces = [where[info[p.material_index][1] if info[p.material_index][1] is not None else ("keep", p.material_index)]
             for p in me.polygons]
    me.materials.clear()
    for m in slots:
        me.materials.append(m)
    for p, k in zip(me.polygons, faces):
        p.material_index = k


def bake_scene():
    """Bakes every mesh object in the scene."""
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            bake(obj)
