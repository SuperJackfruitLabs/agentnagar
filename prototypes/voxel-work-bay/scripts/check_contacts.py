"""Measure evaluated robot meshes across shared stable and transition clips.

blender --background source/work-bay.blend --python-exit-code 1 --python scripts/check_contacts.py
"""
import json
from pathlib import Path
import sys
import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from character import RESIDENTS

root=Path(__file__).resolve().parents[1]
scene=bpy.context.scene
failures=[]
summaries=[]
keyboard=bpy.data.objects['keyboard_anchor'].matrix_world.translation
keyboard_top=keyboard.z+.003
clips={'idle':96,'seated_idle':96,'typing':48,'attend':96,'sit_down':32,'stand_up':32,'walk':32}
total=0
for profile,resident in RESIDENTS.items():
    rig=bpy.data.objects[resident['rig_name']]
    body=bpy.data.objects[resident['mesh_name']]
    # Evaluate each resident at the same bay, without saving this inspection
    # arrangement. build_assets.py hides residents outside its DEMO_SCENE
    # review composition from viewport as well as render; an object with
    # hide_viewport=True is excluded from depsgraph evaluation, so
    # evaluated_get() below would silently return stale/unposed data. Clear
    # it here (in-memory only, never saved) so every resident is actually
    # evaluated, not just the two staged in DEMO_SCENE.
    rig.hide_viewport=False; body.hide_viewport=False
    rig.location=(0,.65,0)
    for name,duration in clips.items():
        rig.animation_data.action=bpy.data.actions[name]
        observations=[]
        fixed_feet={}
        walk_stance={}
        drift_max=0.0
        for frame in range(1,duration+2):
            scene.frame_set(frame)
            evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh=evaluated.to_mesh()
            bounds={}
            for group_name in ('Foot.L','Foot.R','Hand.L','Hand.R','Hips'):
                index=body.vertex_groups[group_name].index
                ids=[v.index for v in body.data.vertices if any(g.group==index for g in v.groups)]
                points=[evaluated.matrix_world@mesh.vertices[i].co for i in ids]
                bounds[group_name]={f'{edge}_{axis}':fn(getattr(p,axis) for p in points)
                                    for edge,fn in (('min',min),('max',max)) for axis in ('x','y','z')}
            for side,offset in (('L',0),('R',.5)):
                foot=bounds['Foot.'+side]
                z=foot['min_z']
                cycle=((frame-1)/32+offset)%1
                stance=name!='walk' or cycle<.5
                if stance and abs(z)>.008 or z<-.008:
                    failures.append(f'{profile} {name} frame {frame} {side} sole z={z:.5f}')
                centre_y=(foot['min_y']+foot['max_y'])/2
                if name in ('sit_down','stand_up'):
                    fixed_feet.setdefault(side,centre_y)
                    drift=abs(centre_y-fixed_feet[side])
                    drift_max=max(drift_max,drift)
                    if drift>.003:
                        failures.append(f'{profile} {name} frame {frame} {side} planted foot drift={drift:.5f}')
                if name=='walk' and stance:
                    # World-space travel is forward (-Y in Blender) at .54m/s.
                    world_y=centre_y-.54*(frame-1)/24
                    key=(side,int(((frame-1)/32+offset)//1))
                    walk_stance.setdefault(key,world_y)
                    drift=abs(world_y-walk_stance[key])
                    drift_max=max(drift_max,drift)
                    if drift>.003:
                        failures.append(f'{profile} walk frame {frame} {side} stance slide={drift:.5f}')
            if name in ('seated_idle','typing','attend') and abs(bounds['Hips']['min_z']-.48)>.008:
                failures.append(f'{profile} {name} frame {frame} hips miss chair seat')
            if name=='typing':
                for side in ('L','R'):
                    hand=bounds['Hand.'+side]
                    gap=hand['min_z']-keyboard_top
                    overlaps=(hand['max_x']>=keyboard.x-.255 and hand['min_x']<=keyboard.x+.255
                              and hand['max_y']>=keyboard.y-.0925 and hand['min_y']<=keyboard.y+.0925)
                    if not overlaps or not -.003<=gap<=.025:
                        failures.append(f'{profile} typing frame {frame} {side} misses keyboard gap={gap:.5f}')
            observations.append(bounds)
            total+=1
            evaluated.to_mesh_clear()
        summaries.append({'resident':profile,'clip':name,'frames_sampled':duration+1,
            'max_planted_foot_drift_metres':drift_max,
            'minimum_sole_height_metres':min(row['Foot.'+s]['min_z'] for row in observations for s in ('L','R')),
            'maximum_sole_height_metres':max(row['Foot.'+s]['min_z'] for row in observations for s in ('L','R')),
            'first_frame':observations[0],'last_frame':observations[-1]})
report={'method':'Evaluated mesh world-space vertex bounds on every authored frame; every resident in RESIDENTS checked in turn, each at the same inspection bay',
        'blender':bpy.app.version_string,'feet_tolerance_metres':.008,'plant_drift_tolerance_metres':.003,
        'typing_hand_check':'XY keyboard overlap; palm underside -3 to +25 mm from key tops',
        'keyboard_top_metres':keyboard_top,'seated_hip_underside_metres':.48,
        'walk_speed_metres_per_second':.54,'sample_count':total,'failures':failures,'clips':summaries}
(root/'evidence'/'contact-check.json').write_text(json.dumps(report,indent=2)+'\n')
print('CONTACT_CHECK',json.dumps({'failures':failures[:15],'failure_count':len(failures),'samples':total}))
if failures:
    raise RuntimeError('Furniture/foot contact checks failed')
