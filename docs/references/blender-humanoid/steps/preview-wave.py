import bpy,json
from pathlib import Path
root=Path(OUTPUT_DIR)
out=root/'wave-frames'
out.mkdir(exist_ok=True)
scene=bpy.context.scene
saved=(scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,scene.render.filepath,scene.frame_current)
try:
    scene.render.engine='BLENDER_WORKBENCH'
    scene.render.resolution_x=630
    scene.render.resolution_y=700
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    shading=scene.display.shading
    shading.light='STUDIO'
    shading.color_type='MATERIAL'
    shading.show_shadows=True
    shading.show_cavity=True
    shading.cavity_type='BOTH'
    shading.background_type='WORLD'
    for i,frame in enumerate(range(1,97,2)):
        if (out/f'{i:03d}.png').exists():
            continue
        scene.frame_set(frame)
        scene.render.filepath=str(out/f'{i:03d}.png')
        bpy.ops.render.render(write_still=True)
    print(json.dumps({'preview_frames':len(list(out.glob('*.png'))),'fps':12}))
finally:
    scene.render.engine,scene.render.resolution_x,scene.render.resolution_y,scene.render.filepath,frame=saved
    scene.frame_set(frame)
