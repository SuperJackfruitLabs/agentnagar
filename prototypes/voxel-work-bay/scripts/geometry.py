"""Small cuboid mesh builder: one object per asset, rigid bone weights.

Coordinates are Blender metres (Z up, character front -Y). glTF converts to
Y up automatically. Cuboids share materials, not separate scene objects.
"""
import bpy
from mathutils import Euler, Vector

COLORS = {
    'cream': '#e7ddbb', 'ivory': '#f7efd4', 'sand': '#baa880',
    'wood': '#ad6935', 'wood_light': '#d6954d', 'wood_dark': '#704222',
    'wood_honey': '#bc7b3d', 'cobalt': '#285782', 'blue_light': '#497a9b',
    'navy': '#203447', 'ink': '#172b30', 'metal': '#45585a',
    'steel': '#91a4a0', 'orange': '#e79432', 'orange_dark': '#bd5923',
    'green': '#407c43', 'leaf': '#68a747', 'leaf_light': '#91be58',
    'shell': '#f0f3ec', 'joint': '#303c40', 'display': '#081211',
    'led_green': '#39f28b', 'screen': '#122d34',
    'teal': '#278a82', 'coral': '#d57262', 'violet': '#685890',
    'mint': '#8ccba6', 'sky': '#a4d1d2', 'paper': '#f1e9ce',
}


def linear(channel):
    return channel / 12.92 if channel <= .04045 else ((channel + .055) / 1.055) ** 2.4


def palette():
    result = {}
    for name, color in COLORS.items():
        material = bpy.data.materials.new(name)
        material.diffuse_color = tuple(linear(int(color[i:i+2], 16) / 255) for i in (1, 3, 5)) + (1,)
        material.use_nodes = True
        shader = next(n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        shader.inputs['Base Color'].default_value = material.diffuse_color
        shader.inputs['Roughness'].default_value = .78
        if name in ('mint', 'led_green'):
            shader.inputs['Emission Color'].default_value = material.diffuse_color
            shader.inputs['Emission Strength'].default_value = .65 if name == 'led_green' else .22
        material.use_backface_culling = True
        result[name] = material
    return result


class Blocks:
    def __init__(self, name, materials):
        self.name, self.materials = name, materials
        self.vertices, self.faces, self.indices, self.weights = [], [], [], {}
        self.used = []

    def box(self, center, size, color, bone=None, rotation=None):
        if min(size) <= 0:
            raise ValueError('Cuboid dimensions must be positive')
        start = len(self.vertices)
        c = Vector(center)
        rot = Euler(rotation).to_matrix() if rotation else None
        for x, y, z in ((-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),
                        (1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)):
            v = Vector((x*size[0]/2, y*size[1]/2, z*size[2]/2))
            self.vertices.append(tuple(c + (rot @ v if rot else v)))
        if color not in self.used:
            self.used.append(color)
        for face in ((0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)):
            self.faces.append(tuple(start + i for i in reversed(face)))
            self.indices.append(self.used.index(color))
        if bone:
            self.weights.setdefault(bone, []).extend(range(start, start+8))

    def finish(self):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(obj)
        for name in self.used:
            mesh.materials.append(self.materials[name])
        for polygon, index in zip(mesh.polygons, self.indices):
            polygon.material_index = index
        for bone, vertices in self.weights.items():
            obj.vertex_groups.new(name=bone).add(vertices, 1.0, 'REPLACE')
        return obj


def anchor(name, position, parent):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = position
    obj['purpose'] = name
    return obj


def label(text, position, size, material, rotation=(1.57079632679, 0, 0)):
    data = bpy.data.curves.new('sign', 'FONT')
    data.body, data.size, data.extrude = text, size, .001
    data.align_x = 'CENTER'
    obj = bpy.data.objects.new('Sign_' + text.replace('\n', '_'), data)
    bpy.context.collection.objects.link(obj)
    obj.location, obj.rotation_euler = position, rotation
    data.materials.append(material)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target='MESH')
    obj.select_set(False)
    return obj
