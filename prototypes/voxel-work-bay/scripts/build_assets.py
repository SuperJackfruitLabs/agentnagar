"""Build the original voxel pilot in a fresh Blender process.

blender --background --factory-startup --python-exit-code 1 --python scripts/build_assets.py
Append `-- --render` to also capture the reference hero image.
The script owns its fresh scene; do not run inside an existing working file.
"""
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from geometry import palette
from workshop import furniture, environment
from character import create_character, RESIDENTS

ROOT = HERE.parent
OUT = ROOT / 'godot' / 'assets'
SOURCE = ROOT / 'source'
EVIDENCE = ROOT / 'evidence'

# The one-bay pilot review scene (work-bay.blend) stages a fixed, curated
# composition: it is authored content for an authoring render, not a view
# of the runtime cast. Keyed by profile (RESIDENTS[*]['source_profile'],
# the plan's "Profile" column, e.g. 'coder-kai') rather than by RESIDENTS'
# short table key or by iteration order, so the mapping names the resident
# it means. A resident whose source_profile is absent from this map is
# still exported as a GLB by the loop below; it simply is not staged in
# this particular review scene. Growing RESIDENTS does not require editing
# this map.
DEMO_SCENE = {
    'coder-kai': {'offset': (0,.65,0), 'action': 'typing'},
    'artistic-lyra': {'offset': (-1.65,-.15,0), 'action': 'idle'},
}
# The resident retained as the selected/editable rig when the review .blend
# is saved; must be one of DEMO_SCENE's residents.
PRESENTATION_SUBJECT = 'coder-kai'


def select(objects):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]


def point(obj, at):
    obj.rotation_euler = (Vector(at)-obj.location).to_track_quat('-Z','Y').to_euler()


def setup_render(scene):
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1440, 1080
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    background = next(n for n in scene.world.node_tree.nodes if n.type == 'BACKGROUND')
    background.inputs['Color'].default_value = (.63,.72,.77,1)
    background.inputs['Strength'].default_value = .4
    for name,position,power,size,color in (
        ('WarmKey',(1,-3,6),1050,5,(1,.83,.62)),
        ('WindowFill',(-2,1,5),750,4,(.73,.86,1)),
        ('SoftFront',(3,-6,3),450,4,(1,.93,.80)),
    ):
        data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size; data.color=color
        obj=bpy.data.objects.new(name,data); scene.collection.objects.link(obj)
        obj.location=position; point(obj,(0,0,1))
    camera_data=bpy.data.cameras.new('ReviewCamera')
    camera=bpy.data.objects.new('ReviewCamera',camera_data)
    scene.collection.objects.link(camera)
    camera.location=(7,-10,7.4); point(camera,(0,.2,1))
    camera_data.type='ORTHO'; camera_data.ortho_scale=9.7
    scene.camera=camera
    # Ground only for the authoring render, excluded from runtime exports.
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.305))
    ground=bpy.context.object; ground.name='RenderGround'
    mat=bpy.data.materials.new('RenderBackdrop'); mat.diffuse_color=(.68,.71,.65,1)
    ground.data.materials.append(mat)


def main():
    for path in (OUT,SOURCE,EVIDENCE): path.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    scene=bpy.context.scene
    scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1
    scene.render.fps=24
    materials=palette()
    assets=furniture(materials)
    assets['environment']=environment(materials)
    character_rigs={}
    for profile in RESIDENTS:
        rig,mesh=create_character(materials, profile)
        assets[profile]=[rig,mesh]
        character_rigs[profile]=rig
    manifest={'revision':'pilot-r004-full-cast','style':'02-voxel',
              'source_profiles':[resident['source_profile'] for resident in RESIDENTS.values()],
              'blender':bpy.app.version_string,'units':'metres; GLB Y-up',
              'references':{'00-city-perspectives':'r004','01-living-community':'r002',
                            '02-creating-exploring':'r002','03-interfaces-perspectives':'r003'},
              'provenance':'Original procedural meshes and animations; no imported geometry, textures or humanoid experiment assets.',
              'acceptance':'Pilot technical evidence only; full cast production acceptance pending.',
              # RESIDENTS' `review` field is the sole authority for this; it
              # is not restated here.
              'appearance_review':{resident['source_profile']:resident['review']
                                   for resident in RESIDENTS.values()},
              'motion':{'fps':24,'walk_period_seconds':32/24,'walk_stride_metres':.72,
                        'walk_speed_metres_per_second':.54,'transition_seconds':32/24,
                        'standing_forward_offset_metres':(.34**2-.05**2)**.5},
              'assets':{}}
    for name,objects in assets.items():
        select(objects)
        path=OUT/f'{name}.glb'
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
            export_yup=True,export_extras=True,export_cameras=False,export_lights=False,
            export_animations=(name in RESIDENTS),export_animation_mode='ACTIONS',
            export_anim_single_armature=True,export_armature_object_remove=True,
            export_force_sampling=True)
        meshes=[o for o in objects if o.type=='MESH']
        manifest['assets'][name]={'file':f'godot/assets/{name}.glb','bytes':path.stat().st_size,
            'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'source_vertices':sum(len(o.data.vertices) for o in meshes),
            'source_faces':sum(len(o.data.polygons) for o in meshes)}
    # Assemble editable review scene using exactly the runtime placements.
    # demo_scene maps each RESIDENTS profile staged in this review scene to
    # its DEMO_SCENE role, resolved via source_profile rather than table
    # order or the short table key.
    demo_scene = {profile:role for profile,resident in RESIDENTS.items()
                  for role in (DEMO_SCENE.get(resident['source_profile']),) if role}
    known_profiles = {resident['source_profile'] for resident in RESIDENTS.values()}
    assert set(DEMO_SCENE) <= known_profiles, \
        'DEMO_SCENE names a resident whose source_profile is not in RESIDENTS'
    assert PRESENTATION_SUBJECT in DEMO_SCENE, \
        'PRESENTATION_SUBJECT must be staged in DEMO_SCENE'
    # Residents not staged in this review composition (everyone but the
    # DEMO_SCENE pair) keep their rig/mesh objects in the .blend for
    # check_contacts.py and other tooling, but must not sit at the origin,
    # visible and overlapping the desk. Hide them from render and viewport
    # rather than deleting or exporting them out of the file.
    for profile in RESIDENTS:
        if profile not in demo_scene:
            for obj in assets[profile]:
                obj.hide_render = True
                obj.hide_viewport = True
    placements=[('chair',(0,.65,0)),('terminal',(0,-.12,.78))]
    placements+=[(profile,role['offset']) for profile,role in demo_scene.items()]
    for name,offset in placements:
        for obj in assets[name]:
            if obj.parent is None: obj.location=offset
    for profile,role in demo_scene.items():
        character_rigs[profile].animation_data.action=bpy.data.actions[role['action']]
    scene.frame_set(1)
    scene.frame_start=1; scene.frame_end=49
    setup_render(scene)
    # Retain editable rig, actions, meshes, anchors and presentation camera.
    subject_profile = next(profile for profile,resident in RESIDENTS.items()
                            if resident['source_profile']==PRESENTATION_SUBJECT)
    select([character_rigs[subject_profile]])
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'work-bay.blend'))
    manifest['source_sha256']=hashlib.sha256((SOURCE/'work-bay.blend').read_bytes()).hexdigest()
    recipe_files = ('build_assets.py', 'geometry.py', 'workshop.py', 'character.py')
    manifest['recipe_sha256']={name:hashlib.sha256((HERE/name).read_bytes()).hexdigest() for name in recipe_files}
    (ROOT/'asset-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('PILOT_EXPORTS_READY',json.dumps(manifest['assets']))
    if '--render' in sys.argv:
        scene.render.filepath=str(EVIDENCE/'blender-work-bay.png')
        bpy.ops.render.render(write_still=True)
        # Closer view exposes face, rig, apron and furniture contacts.
        scene.camera.location=(3,-4,2.7); point(scene.camera,(0,.20,.90))
        scene.camera.data.ortho_scale=3.4
        scene.render.resolution_x=1200; scene.render.resolution_y=1200
        scene.render.filepath=str(EVIDENCE/'blender-detail.png')
        bpy.ops.render.render(write_still=True)
        scene.camera.location=(1,-4,2.4); point(scene.camera,(-1.65,-.15,.95))
        scene.camera.data.ortho_scale=2.6
        scene.render.filepath=str(EVIDENCE/'blender-lyra.png')
        bpy.ops.render.render(write_still=True)


if __name__=='__main__': main()
