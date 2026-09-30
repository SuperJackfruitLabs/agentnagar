"""Check the actual delivery boundary: missing rigs/clips/geometry fail here.

Run after build_assets.py. Khronos validation complements these pilot-specific
checks; this deliberately does not substitute for the Khronos validator.
"""
import json
from pathlib import Path
import struct
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'godot' / 'assets'


def glb(path):
    raw = path.read_bytes()
    n = struct.unpack_from('<I', raw, 12)[0]
    return json.loads(raw[20:20+n]), raw[28+n:]


def _stub_blender_modules_for_table_import():
    """character.py and geometry.py `import bpy`/`mathutils` at module level
    for mesh authoring, but RESIDENTS itself is plain data (strings and
    function references never called at import time). This file otherwise
    runs under plain python3, with no Blender process behind it, so a
    minimal stand-in lets the table be inspected without launching Blender."""
    import types
    if 'bpy' not in sys.modules:
        bpy_stub = types.ModuleType('bpy')
        bpy_stub.data = types.SimpleNamespace()
        bpy_stub.context = types.SimpleNamespace()
        bpy_stub.ops = types.SimpleNamespace()
        sys.modules['bpy'] = bpy_stub
    if 'mathutils' not in sys.modules:
        mathutils_stub = types.ModuleType('mathutils')
        mathutils_stub.Vector = object
        mathutils_stub.Euler = object
        sys.modules['mathutils'] = mathutils_stub


def _residents():
    """Import character.RESIDENTS under the Blender stub, plain python only.
    Reused everywhere this file needs the full cast rather than a hardcoded
    pair, so a resident added to the table is picked up automatically."""
    _stub_blender_modules_for_table_import()
    scripts_dir = str(ROOT / 'scripts')
    if scripts_dir not in sys.path:
        sys.path.insert(0, scripts_dir)
    from character import RESIDENTS
    return RESIDENTS


class ExportTests(unittest.TestCase):
    def load(self, name):
        path = ASSETS / f'{name}.glb'
        self.assertTrue(path.is_file(), f'Missing actual export: {path}')
        raw = path.read_bytes()
        magic, version, length = struct.unpack_from('<4sII', raw)
        self.assertEqual((magic, version, length), (b'glTF', 2, len(raw)))
        size, kind = struct.unpack_from('<I4s', raw, 12)
        self.assertEqual(kind, b'JSON')
        return json.loads(raw[20:20+size])

    def test_all_assets_contain_portable_triangle_geometry(self):
        for name in ('environment', 'desk', 'chair', 'terminal', *_residents()):
            with self.subTest(asset=name):
                doc = self.load(name)
                self.assertTrue(doc.get('meshes'), f'{name} exported empty')
                self.assertFalse(doc.get('extensionsRequired'), 'Pilot requires no optional decoder')
                for mesh in doc['meshes']:
                    for primitive in mesh['primitives']:
                        self.assertEqual(primitive.get('mode', 4), 4)
                        self.assertIn('POSITION', primitive['attributes'])
                        self.assertIn('NORMAL', primitive['attributes'])

    def test_closed_assets_have_outward_triangle_winding(self):
        # A positive signed volume catches inside-out cuboids that look fine
        # in two-sided authoring renders but disappear with runtime culling.
        for name in ('environment', 'desk', 'chair', 'terminal', *_residents()):
            doc = self.load(name)
            raw = (ASSETS / f'{name}.glb').read_bytes()
            json_size = struct.unpack_from('<I', raw, 12)[0]
            binary = raw[28 + json_size:]

            def accessor(index):
                a = doc['accessors'][index]
                view = doc['bufferViews'][a['bufferView']]
                count = {'SCALAR': 1, 'VEC3': 3}[a['type']]
                code = {5123: 'H', 5125: 'I', 5126: 'f'}[a['componentType']]
                fmt = '<' + code * count
                stride = view.get('byteStride', struct.calcsize(fmt))
                start = view.get('byteOffset', 0) + a.get('byteOffset', 0)
                return [struct.unpack_from(fmt, binary, start + i * stride) for i in range(a['count'])]

            volume = 0.0
            for mesh in doc['meshes']:
                for primitive in mesh['primitives']:
                    vertices = accessor(primitive['attributes']['POSITION'])
                    indices = [v[0] for v in accessor(primitive['indices'])]
                    for offset in range(0, len(indices), 3):
                        a, b, c = (vertices[i] for i in indices[offset:offset+3])
                        volume += (a[0]*(b[1]*c[2]-b[2]*c[1])
                                   + a[1]*(b[2]*c[0]-b[0]*c[2])
                                   + a[2]*(b[0]*c[1]-b[1]*c[0])) / 6
            with self.subTest(asset=name):
                self.assertGreater(volume, 0, 'Closed asset triangles face inward')

    def test_character_keeps_skin_and_seven_distinct_animated_clips(self):
        for name in _residents():
            with self.subTest(asset=name):
                doc = self.load(name)
                self.assertTrue(doc.get('skins'), 'Character export lost its rig')
                self.assertGreaterEqual(len(doc['skins'][0]['joints']), 12)
                clips = {a['name']: a for a in doc.get('animations', [])}
                self.assertEqual(set(clips), {'idle', 'walk', 'seated_idle', 'typing', 'attend', 'sit_down', 'stand_up'})
                for clip_name, clip in clips.items():
                    with self.subTest(asset=name, clip=clip_name):
                        self.assertTrue(clip['channels'])
                        times = [doc['accessors'][s['input']] for s in clip['samplers']]
                        self.assertTrue(any(a['max'][0] > a['min'][0] for a in times))
                primitives = [p for m in doc['meshes'] for p in m['primitives']]
                self.assertTrue(all('JOINTS_0' in p['attributes'] and 'WEIGHTS_0' in p['attributes'] for p in primitives))

    def test_all_residents_share_rig_and_animation_data(self):
        # Every resident is compared against one reference (the cast's first
        # entry in RESIDENTS) rather than only a single pair, so the export
        # contract's parity claim actually covers all fourteen: bone names,
        # bind-pose transforms, inverse bind matrices, and full per-keyframe
        # sample data for every clip -- not just clip/bone *names*.
        def contract(name):
            d = self.load(name)
            raw = (ASSETS / f'{name}.glb').read_bytes()
            binary = raw[28 + struct.unpack_from('<I', raw, 12)[0]:]
            def data(index):
                a = d['accessors'][index]; v = d['bufferViews'][a['bufferView']]
                start = v.get('byteOffset', 0) + a.get('byteOffset', 0)
                width = {'SCALAR':1, 'VEC3':3, 'VEC4':4, 'MAT4':16}[a['type']] * 4
                stride = v.get('byteStride', width)
                return b''.join(binary[start+i*stride:start+i*stride+width] for i in range(a['count']))
            skin = d['skins'][0]
            bones = [(d['nodes'][i]['name'], d['nodes'][i].get('translation'), d['nodes'][i].get('rotation')) for i in skin['joints']]
            clips = {a['name']: [(d['nodes'][c['target']['node']]['name'], c['target']['path'],
                      data(a['samplers'][c['sampler']]['input']), data(a['samplers'][c['sampler']]['output']))
                      for c in a['channels']] for a in d['animations']}
            self.assertEqual(len(clips), 7)
            return bones, data(skin['inverseBindMatrices']), clips
        names = list(_residents())
        reference_name = names[0]
        reference = contract(reference_name)
        for name in names[1:]:
            with self.subTest(asset=name):
                self.assertEqual(contract(name), reference,
                                  f'{name} rig/animation data does not match reference {reference_name}: '
                                  'bone transforms, inverse bind matrices, or keyframes differ')

    def test_furniture_retains_mount_anchors(self):
        expected = {'desk': {'terminal_mount', 'chair_approach'},
                    'chair': {'seat_anchor'}, 'terminal': {'keyboard_anchor'}}
        for name, anchors in expected.items():
            doc = self.load(name)
            self.assertTrue(anchors <= {n.get('name') for n in doc['nodes']})

    def test_skinned_mesh_is_scene_root_without_ignored_parent_transform(self):
        for name in _residents():
            with self.subTest(asset=name):
                doc = self.load(name)
                roots = set(doc['scenes'][doc.get('scene', 0)]['nodes'])
                for index, node in enumerate(doc['nodes']):
                    if 'skin' in node:
                        self.assertIn(index, roots, 'Skinned mesh parent transforms are not portable')


class ResidentTable(unittest.TestCase):
    """Adding a resident must not require editing the pipeline by hand."""
    def test_every_resident_in_the_table_is_exported(self):
        for profile in _residents():
            self.assertTrue((ROOT/'godot/assets'/(profile+'.glb')).exists(),
                            f'{profile} is in RESIDENTS but was never exported')

    def test_pipeline_does_not_hardcode_the_cast(self):
        import re
        for name in ('build_assets.py','check_contacts.py'):
            text=(ROOT/'scripts'/name).read_text()
            for literal in ("'kai'",'"kai"',"'lyra'",'"lyra"','KaiRig','LyraRig'):
                self.assertNotIn(literal,text,
                                 f'{name} still names {literal} literally; it should read RESIDENTS')

    def test_every_resident_shares_the_rig_and_clip_set(self):
        RESIDENTS = _residents()
        reference=None
        for profile in sorted(RESIDENTS):
            doc,blob=glb(ROOT/'godot/assets'/(profile+'.glb'))
            clips=sorted(a['name'].split('|')[-1].split('/')[-1].lower() for a in doc.get('animations',[]))
            self.assertEqual(len(doc['skins'][0]['joints']),16,f'{profile} must bind 16 bones')
            self.assertEqual(clips,['attend','idle','seated_idle','sit_down','stand_up','typing','walk'],
                             f'{profile} must carry the same seven clips')
            joints=doc['skins'][0]['joints']
            bone_names=[doc['nodes'][i]['name'] for i in joints]
            if reference is None: reference=(profile,bone_names)
            else: self.assertEqual(bone_names,reference[1],
                                   f'{profile} bind differs from {reference[0]}: bone names or order do not match')


if __name__ == '__main__':
    unittest.main()
