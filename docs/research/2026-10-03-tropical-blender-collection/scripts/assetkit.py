"""Shared original Blender primitives and export helpers for Codex asset studies."""
import bpy, bmesh, math, random, json
from pathlib import Path
from mathutils import Vector
def linear(v):
    return v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4

def rgb(code):
    return tuple(linear(int(code[i:i+2],16)/255) for i in (0,2,4))

def mat(name, code, rough=.75):
    m=bpy.data.materials.new(name); m.diffuse_color=(*rgb(code),1)
    m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*rgb(code),1)
    p.inputs['Roughness'].default_value=rough
    p.inputs['Specular IOR Level'].default_value=.25
    return m

def cube(name, loc, size, material, bevel=.007, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob=bpy.context.object; ob.name=name
    ob.dimensions=size; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    ob.data.materials.append(material)
    if bevel:
        m=ob.modifiers.new('Small intentional edge chamfer','BEVEL')
        m.width=bevel; m.segments=1
        bpy.ops.object.modifier_apply(modifier=m.name)
        # Large timber faces stay planar, bevels get their own normals.
        for p in ob.data.polygons: p.use_smooth=False
        m=ob.modifiers.new('Face weighted corner normals','WEIGHTED_NORMAL')
        m.keep_sharp=True; m.weight=40
        bpy.ops.object.modifier_apply(modifier=m.name)
    ob.rotation_euler=rot
    return ob

def cushion(name, loc, size, radius, materials, divisions, bulge=.012, rot=(0,0,0), seed=1):
    """Watertight rounded box with deliberately broad, irregular triangular facets."""
    rng=random.Random(seed); vertices=[]; faces=[]
    half=Vector(size)*.5
    # Edge coordinates are shared; jitter only interior coordinates of a face.
    coords=[]
    for n in divisions:
        coords.append([-1+2*i/n for i in range(n+1)])
    for axis in range(3):
        u=(axis+1)%3; v=(axis+2)%3
        for sign in (-1,1):
            base=len(vertices)
            for j,cv in enumerate(coords[v]):
                for i,cu in enumerate(coords[u]):
                    uv=[cu,cv]
                    if 0<i<len(coords[u])-1 and 0<j<len(coords[v])-1:
                        uv[0]+=rng.uniform(-.15,.15); uv[1]+=rng.uniform(-.15,.15)
                    p=Vector((0,0,0)); p[axis]=sign*half[axis]
                    p[u]=uv[0]*half[u]; p[v]=uv[1]*half[v]
                    core=Vector([max(-half[k]+radius,min(half[k]-radius,p[k])) for k in range(3)])
                    delta=p-core
                    p=core+delta.normalized()*radius
                    # Small upholstered swelling, while retaining crisp low-poly facets.
                    if axis==2:
                        p[2]+=sign*bulge*max(0,1-uv[0]**2)*max(0,1-uv[1]**2)
                    if axis==1:
                        p[1]+=sign*bulge*.6*max(0,1-uv[0]**2)*max(0,1-uv[1]**2)
                    vertices.append(p)
            nu=len(coords[u]); nv=len(coords[v])
            for j in range(nv-1):
                for i in range(nu-1):
                    a=base+j*nu+i; b=a+1; c=a+nu+1; d=a+nu
                    f=[(a,b,c),(a,c,d)] if rng.random()<.5 else [(a,b,d),(b,c,d)]
                    for tri in f: faces.append(tri if sign==1 else tuple(reversed(tri)))
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(vertices,[],faces); mesh.update()
    bm=bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(mesh); bm.free()
    ob=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(ob)
    ob.location=loc; ob.rotation_euler=rot
    for m in materials: mesh.materials.append(m)
    for p in mesh.polygons:
        p.material_index=rng.choices(range(len(materials)),weights=[5,3,2,1,1])[0]
    return ob

def detail_strip(name, verts, material):
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],[list(range(len(verts)))]); mesh.update()
    ob=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(ob)
    mesh.materials.append(material)
    return ob


ROOT=Path(__file__).resolve().parent.parent
REPO=next(p for p in ROOT.parents if (p/'COPYING.md').is_file() and (p/'city').is_dir())

def clean():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

def tag(ob,part='body'):
    ob['asset_part']=part
    return ob

def mesh(name,vertices,faces,material,part='body'):
    m=bpy.data.meshes.new(name);m.from_pydata(vertices,[],faces);m.update()
    bm=bmesh.new();bm.from_mesh(m);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(m);bm.free()
    ob=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(ob)
    if isinstance(material,(list,tuple)):
        for x in material:m.materials.append(x)
    else:m.materials.append(material)
    return tag(ob,part)

def cylinder(name,loc,radius,depth,material,vertices=12,radius2=None,part='body'):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=radius,radius2=radius if radius2 is None else radius2,depth=depth,location=loc)
    ob=bpy.context.object;ob.name=name;ob.data.materials.append(material)
    return tag(ob,part)

def beam(name,a,b,radius,material,vertices=8,radius2=None,part='body'):
    a,b=Vector(a),Vector(b)
    ob=cylinder(name,(a+b)/2,radius,(b-a).length,material,vertices,radius2,part)
    ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return ob

def ico(name,loc,scale,material,subdivisions=1,part='body'):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions,radius=1,location=loc)
    ob=bpy.context.object;ob.name=name;ob.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if isinstance(material,(list,tuple)):
        for m in material:ob.data.materials.append(m)
        rng=random.Random(name)
        for p in ob.data.polygons:p.material_index=rng.randrange(len(material))
    else:ob.data.materials.append(material)
    return tag(ob,part)

def finish(name,parts=None,notes=None):
    """Save editable parts .blend and game GLB grouped by their asset_part tag.
    Non-emissive palettes become vertex colour, one material per part. Water,
    glass and light materials marked keep_material=True retain their BSDF.
    """
    if parts is None:parts=[o for o in bpy.context.scene.objects if o.type=='MESH']
    bpy.context.view_layer.update()
    root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
    for o in parts:o.parent=root
    root['authoring']='AI-authored by OpenAI Codex; original constructed Blender geometry'
    root['style']='lowpoly_tropical'
    root['status']='Review candidate, not adopted'
    dest=ROOT/'assets'/'lowpoly_tropical';dest.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(dest/(name+'.blend')))
    # Keep original parts in the blend; export their grouped copies.
    grouped={}
    for o in parts:grouped.setdefault(o.get('asset_part','body'),[]).append(o)
    export=[]
    for label,objects in grouped.items():
        copies=[]
        for ob in objects:
            dup=ob.copy();dup.data=ob.data.copy();bpy.context.collection.objects.link(dup);dup.parent=None;dup.matrix_world=ob.matrix_world.copy();copies.append(dup)
        bpy.ops.object.select_all(action='DESELECT')
        for ob in copies:ob.select_set(True)
        bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join()
        ob=bpy.context.object;ob.name=label;ob.parent=root
        # Game MultiMesh consumers use Mesh data directly, ignoring node transforms.
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        colors=ob.data.color_attributes.get('Color') or ob.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
        old=list(ob.data.materials)
        keep={i:m for i,m in enumerate(old) if m.get('keep_material',False)}
        palette=mat(name+' / '+label+' vertex palette','FFFFFF')
        attr=palette.node_tree.nodes.new('ShaderNodeVertexColor');attr.layer_name='Color'
        palette.node_tree.links.new(attr.outputs['Color'],palette.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
        new_indices={i:k+1 for k,i in enumerate(keep)}
        target_indices=[]
        for poly in ob.data.polygons:
            old_index=poly.material_index
            col=old[old_index].diffuse_color if old else (1,1,1,1)
            for k in poly.loop_indices:colors.data[k].color=col if old_index not in keep else (1,1,1,1)
            target_indices.append(new_indices.get(old_index,0))
        ob.data.materials.clear();ob.data.materials.append(palette)
        for m in keep.values():ob.data.materials.append(m)
        for poly,index in zip(ob.data.polygons,target_indices):poly.material_index=index
        export.append(ob)
    bpy.ops.object.select_all(action='DESELECT')
    for o in [root]+export:o.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(dest/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_normals=True,export_texcoords=False,export_materials='EXPORT')
    points=[o.matrix_world@v.co for o in export for v in o.data.vertices]
    report={'name':name,'triangles':sum(len(p.vertices)-2 for o in export for p in o.data.polygons),'parts':[o.name for o in export], 'editable_meshes':len(parts),'bounds_min':[round(min(v[i] for v in points),5) for i in range(3)],'bounds_max':[round(max(v[i] for v in points),5) for i in range(3)],'notes':notes or []}
    (dest/(name+'.json')).write_text(json.dumps(report,indent=2))
    print('FINISHED',json.dumps(report),flush=True)
    return report
