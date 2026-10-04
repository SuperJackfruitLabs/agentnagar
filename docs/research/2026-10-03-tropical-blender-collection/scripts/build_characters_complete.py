"""Original tropical residents. No legacy geometry/builders or downloaded assets.
Blender -b -t 2 --python scripts/build_characters_complete.py -- human robot
"""
import bpy,bmesh,math,json,sys,random
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from assetkit import mat,cube,cylinder,beam,ico,mesh,clean,rgb
ROOT=Path(__file__).resolve().parent.parent
DEST=ROOT/'assets'/'lowpoly_tropical';DEST.mkdir(parents=True,exist_ok=True)
PARTS=[];RIG=None

def bind(ob,label,bone):
    bm=bmesh.new();bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0000001)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.00000001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(ob.data);bm.free()
    ob['character_part']=label;ob['construction']='Original authored geometry';PARTS.append(ob)
    if isinstance(bone,str):ob.vertex_groups.new(name=bone).add(list(range(len(ob.data.vertices))),1,'REPLACE')
    else:
        for name,indices,weight in bone:ob.vertex_groups.new(name=name).add(indices,weight,'REPLACE')
    mod=ob.modifiers.new('Deform by anatomical skeleton','ARMATURE');mod.object=RIG
    ob.parent=RIG
    return ob

def box(name,loc,size,material,label,bone,bevel=.014):return bind(cube(name,loc,size,material,bevel),label,bone)
def ball(name,loc,size,material,label,bone,sub=2):return bind(ico(name,loc,size,material,sub),label,bone)
def rod(name,a,b,r,material,label,bone,r2=None,n=8):return bind(beam(name,a,b,r,material,n,r2),label,bone)

def ringform(name,rings,material,label,bone,sides=12):
    # Solid faceted elliptical cross sections; arbitrary centre and widths.
    vs=[];fs=[]
    for x,y,z,rx,ry in rings:
        for k in range(sides):
            a=math.tau*k/sides;vs.append((x+rx*math.cos(a),y+ry*math.sin(a),z))
    for j in range(len(rings)-1):
        for k in range(sides):
            a=j*sides+k;b=j*sides+(k+1)%sides;fs.append((a,b,b+sides,a+sides))
    fs += [tuple(reversed(range(sides))),tuple((len(rings)-1)*sides+k for k in range(sides))]
    ob=mesh(name,vs,fs,material)
    if callable(bone):
        for i,v in enumerate(ob.data.vertices):
            for bn,w in bone(v.co).items():
                group=ob.vertex_groups.get(bn) or ob.vertex_groups.new(name=bn);group.add([i],w,'REPLACE')
        return bind(ob,label,[])
    return bind(ob,label,bone)

def poly(name,vs,fs,material,label,bone):return bind(mesh(name,vs,fs,material),label,bone)

def rig_create(robot=False):
    global RIG,PARTS
    clean();PARTS=[]
    h=.80 if robot else .88;shoulder=1.22 if robot else 1.34;knee=.43 if robot else .46
    name='rig_robot' if robot else 'rig_human'
    arm=bpy.data.armatures.new(name+' skeleton');RIG=bpy.data.objects.new(name,arm);bpy.context.collection.objects.link(RIG);bpy.context.view_layer.objects.active=RIG;RIG.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    skeleton=[('hips',(0,0,h),(0,0,h+.12),None),('spine',(0,0,h+.12),(0,0,shoulder-.14),'hips'),('chest',(0,0,shoulder-.14),(0,0,shoulder),'spine'),('neck',(0,0,shoulder),(0,0,shoulder+.10),'chest'),('head',(0,0,shoulder+.1),(0,0,shoulder+.29),'neck')]
    for sign,suffix in [(-1,'r'),(1,'l')]:
        x=.22*sign;elbow=(.285*sign,0,shoulder-.235);wrist=(.34*sign,.005,shoulder-.45)
        skeleton += [('upper_arm_'+suffix,(x,0,shoulder),elbow,'chest'),('forearm_'+suffix,elbow,wrist,'upper_arm_'+suffix),('hand_'+suffix,wrist,(.35*sign,.012,shoulder-.535),'forearm_'+suffix),('thigh_'+suffix,(.10*sign,0,h),(.11*sign,0,knee),'hips'),('shin_'+suffix,(.11*sign,0,knee),(.11*sign,0,.105),'thigh_'+suffix),('foot_'+suffix,(.11*sign,0,.105),(.11*sign,.14,.065),'shin_'+suffix)]
    for name,head,tail,parent in skeleton:
        b=arm.edit_bones.new(name);b.head=head;b.tail=tail
        if parent:b.parent=arm.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT');RIG.show_in_front=True
    for p in RIG.pose.bones:p.rotation_mode='XYZ'
    RIG['rig_contract']='17 anatomical bones; hips root; +Y front; Z up'
    return h,shoulder,knee

def soft_weights(z,joint,lower,upper,blend=.055):
    t=max(0,min(1,(z-joint+blend)/(2*blend)));return {lower:1-t,upper:t}

def hair_cap(label,style,M):
    # Alternative meshes occupy same head; runtime shows exactly one style.
    ob=ringform('Hair silhouette '+str(style),[(0,-.018,1.567,.082,.082),(0,-.013,1.638,.091,.086),(0,-.018,1.684,.068,.062),(0,-.018,1.696,.022,.025)],M,label,'head',12)
    if style==1:
        ball('Side swept hair crown',(-.034,.012,1.67),(.079,.077,.039),M,label,'head',1)
    elif style==2:
        for i in range(7):
            a=i*math.tau/7;ball('Short curls',(math.cos(a)*.065,math.sin(a)*.05,1.66),(.035,.038,.035),M,label,'head',1)
    elif style==3:ball('Tied back bun',(0,-.102,1.623),(.045,.034,.048),M,label,'head',1)
    # Forehead remains clear: cap bottom is trimmed above eyebrows except back.
    bpy.context.view_layer.update()
    for o in PARTS:
        if o.get('character_part')==label:
            for v in o.data.vertices:
                point=o.matrix_world@v.co
                if point.y>.014 and point.z<1.633:
                    point.z=1.633;v.co=o.matrix_world.inverted()@point
    return ob

def human():
    h,sh,knee=rig_create()
    skin=mat('Warm brown skin','A9744E');skinlight=mat('Nose and ear warmth','AB7853');shirt=mat('Ivory linen','EEE6D2');seam=mat('Linen shaded seam','D0C4AA');pants=mat('Olive twill','747953');hair=mat('Dark warm hair','30271F');shoe=mat('Leather shoes','72503B');sole=mat('Shoe sole','483A2D');white=mat('Warm eye whites','DED5BC');iris=mat('Brown iris','483526');dark=mat('Pupil and smile','39271F');hat=mat('Honey straw','DCA548');band=mat('Hat band','57412B');bag=mat('Terracotta canvas','A65F3B');baglight=mat('Bag flap edge','BB7547');brass=mat('Buckle brass','D3B57B')
    def torso_w(v):
        if v.z<1.05:return soft_weights(v.z,.98,'hips','spine',.09)
        return soft_weights(v.z,1.19,'spine','chest',.1)
    ringform('Shaped linen shirt',[(0,0,.88,.155,.086),(0,0,.94,.163,.094),(0,0,1.13,.152,.095),(0,0,1.28,.191,.104),(0,0,1.34,.177,.096),(0,0,1.365,.072,.065)],shirt,'top',torso_w,12)
    # Open spread collar and subtle placket follow torso, visibly constructed.
    for s in (-1,1):
        poly('Folded shirt collar',[(s*.032,.074,1.364),(s*.075,.095,1.341),(s*.095,.117,1.267),(s*.026,.120,1.313)],[(0,1,2),(0,2,3)],seam,'top','chest')
        poly('Collar light edge',[(s*.035,.078,1.366),(s*.077,.100,1.341),(s*.087,.119,1.277),(s*.028,.123,1.315)],[(0,1,2),(0,2,3)],shirt,'top','chest')
    box('Button placket',(0,.100,1.112),(.014,.008,.322),seam,'top','spine',.001)
    for z in [.98,1.075,1.17,1.25]:ball('Shirt button',(0,.108,z),(.006,.004,.006),brass,'details','spine' if z<1.2 else 'chest',1)
    ringform('Trouser seat',[(0,0,.81,.151,.085),(0,0,.91,.151,.081),(0,0,.955,.147,.08)],pants,'bottom','hips',12)
    for s,suf in [(-1,'r'),(1,'l')]:
        thigh='thigh_'+suf;shin='shin_'+suf;upper='upper_arm_'+suf;fore='forearm_'+suf;hand='hand_'+suf;foot='foot_'+suf
        ringform('Tailored trouser leg '+suf,[(s*.11,0,.10,.063,.069),(s*.11,0,.22,.06,.065),(s*.11,.005,.46,.066,.072),(s*.105,0,.64,.076,.08),(s*.09,0,.86,.083,.087)],pants,'bottom',lambda v,thigh=thigh,shin=shin:soft_weights(v.z,knee,shin,thigh,.045),10)
        ringform('Bare arm '+suf,[(s*.34,.005,.866,.037,.035),(s*.315,0,.985,.044,.045),(s*.285,0,1.10,.049,.048),(s*.253,0,1.23,.053,.056),(s*.218,0,1.32,.059,.061)],skin,'skin',lambda v,fore=fore,upper=upper:soft_weights(v.z,1.105,fore,upper,.04),10)
        ringform('Linen short sleeve '+suf,[(s*.263,0,1.19,.072,.072),(s*.245,0,1.27,.08,.078),(s*.20,0,1.335,.08,.08)],shirt,'top',upper,10)
        box('Relaxed palm '+suf,(s*.346,.007,.835),(.072,.047,.087),skin,'skin',hand,.016)
        for f in range(4):
            x=s*(.321+f*.016);length=[.047,.062,.057,.044][f]
            rod('Finger '+suf,(x,.014,.804),(x+s*.008,.028,.804-length),.008,skin,'skin',hand,.006,6)
        rod('Thumb '+suf,(s*.317,.014,.85),(s*.305,.035,.81),.012,skin,'skin',hand,.009,7)
        box('Leather shoe '+suf,(s*.11,.051,.065),(.147,.252,.116),shoe,'shoes',foot,.028)
        box('Rubber sole '+suf,(s*.11,.046,.021),(.153,.26,.04),sole,'shoes',foot,.009)
        box('Shoe vamp seam '+suf,(s*.11,.107,.122),(.11,.012,.005),baglight,'details',foot,.002)
    ringform('Neck',[(0,0,1.343,.048,.046),(0,0,1.443,.049,.047),(0,0,1.474,.056,.051)],skin,'skin','neck',12)
    # Head uses deliberate jaw, cheek, temple and crown rings instead of a sphere.
    ringform('Adult faceted head',[(0,.006,1.437,.045,.05),(0,.009,1.453,.064,.063),(0,.008,1.489,.080,.069),(0,.001,1.541,.090,.077),(0,-.002,1.595,.088,.078),(0,-.01,1.642,.074,.066),(0,-.012,1.676,.047,.045)],skin,'skin','head',16)
    # Protruding nose bridge/tip creates recognisable three-quarter face planes.
    poly('Nose planes',[(-.013,.073,1.57),(.013,.073,1.57),(-.021,.094,1.506),(.021,.094,1.506),(0,.116,1.517),(0,.079,1.496)],[(0,1,4),(0,4,2),(1,3,4),(2,4,5),(4,3,5),(3,2,5)],skinlight,'skin','head')
    for s in (-1,1):
        ball('Ear',(s*.091,-.003,1.535),(.021,.023,.038),skinlight,'skin','head',1)
        # Almond dark socket, ivory almond, small iris and pupil. Subtle brows.
        ball('Eye socket',(s*.036,.073,1.563),(.024,.010,.014),dark,'details','head',2)
        ball('Eye ivory',(s*.036,.080,1.564),(.020,.006,.010),white,'details','head',2)
        ball('Iris',(s*.034,.086,1.563),(.008,.003,.008),iris,'details','head',2)
        ball('Pupil',(s*.034,.0885,1.563),(.004,.0018,.006),dark,'details','head',1)
        ball('Eye glint',(s*.032,.090,1.567),(.002,.001,.002),white,'details','head',1)
        rod('Eyebrow',(s*.016,.080,1.586),(s*.056,.074,1.588),.0055,hair,'details','head',.004,6)
    # Slight upward corners read as a relaxed adult expression.
    for a,b in [((-.029,.077,1.482),(0,.085,1.479)),((0,.085,1.479),(.029,.077,1.482))]:rod('Relaxed smile',a,b,.0028,dark,'details','head',.0018,5)
    for i in range(4):hair_cap('hair_'+str(i),i,hair)
    # Honey sun hat, broad thin elliptical brim and tapered crown.
    ringform('Sunhat brim',[(0,-.005,1.666,.15,.132),(0,-.005,1.678,.154,.134),(0,-.005,1.686,.125,.11)],hat,'hat_sun','head',20)
    ringform('Sunhat crown',[(0,-.014,1.681,.10,.087),(0,-.014,1.71,.098,.085),(0,-.014,1.77,.080,.069),(0,-.014,1.788,.055,.048)],hat,'hat_sun','head',12)
    ringform('Sunhat woven band',[(0,-.014,1.687,.101,.088),(0,-.014,1.711,.099,.086)],band,'hat_sun','head',12)
    box('Canvas backpack body',(0,-.157,1.16),(.25,.16,.31),bag,'backpack','chest',.035)
    box('Backpack flap',(0,-.25,1.25),(.254,.025,.126),baglight,'backpack','chest',.018)
    box('Backpack central strap',(0,-.267,1.145),(.035,.016,.13),baglight,'backpack','chest',.005)
    box('Backpack brass clasp',(0,-.28,1.14),(.047,.016,.047),brass,'backpack','chest',.005)
    box('Backpack clasp inset',(0,-.29,1.14),(.029,.005,.027),bag,'backpack','chest',.002)
    for s in (-1,1):
        for a,b in [((s*.117,-.178,1.31),(s*.123,-.06,1.373)),((s*.123,-.06,1.373),(s*.132,.107,1.29)),((s*.132,.107,1.29),(s*.133,.108,1.02)),((s*.133,.108,1.02),(s*.11,-.135,1.03))]:rod('Backpack shoulder strap',a,b,.018,bag,'backpack','chest',.018,6)
    return 'character_human'

def robot():
    h,sh,knee=rig_create(True)
    cream=mat('Warm ivory enamel','E6DCC6',.52);edge=mat('Cream shell edge','C8BDA4',.55);olive=mat('Civic olive panels','7F8760',.65);black=mat('Graphite joints','353B32',.68);glass=mat('Dark face glass','242C25',.28);eye=mat('Soft lime eye lamps','D7EEA6',.35);gold=mat('Golden leaf badge','D6B049',.5)
    bs=eye.node_tree.nodes.get('Principled BSDF');bs.inputs['Emission Color'].default_value=(*rgb('D7EEA6'),1);bs.inputs['Emission Strength'].default_value=.35
    ringform('Hip enamel shell',[(0,0,.67,.092,.076),(0,0,.75,.157,.099),(0,0,.84,.151,.093),(0,0,.87,.11,.079)],cream,'shell','hips',12)
    ringform('Waist flexible joint',[(0,0,.825,.084,.070),(0,0,.932,.089,.072)],black,'joint','spine',12)
    ringform('Torso carapace',[(0,0,.905,.107,.075),(0,0,.963,.15,.09),(0,0,1.10,.18,.109),(0,0,1.225,.191,.099),(0,0,1.265,.14,.078)],cream,'shell','chest',16)
    # Recessed softly bevelled belly plate, not painted decoration.
    box('Olive belly access plate',(0,.099,.995),(.205,.041,.178),olive,'panel','chest',.035)
    ringform('Telescopic neck',[(0,0,1.245,.049,.046),(0,0,1.363,.049,.046)],black,'joint','neck',12)
    box('Rounded robot head',(0,0,1.495),(.316,.245,.290),cream,'shell','head',.071)
    box('Recessed face surround',(0,.122,1.491),(.274,.037,.184),edge,'shell','head',.042)
    box('Dark rounded face glass',(0,.147,1.491),(.252,.027,.158),glass,'face','head',.037)
    for s in (-1,1):
        ball('Round friendly eye',(s*.057,.165,1.504),(.025,.009,.027),eye,'eyes','head',2)
        rod('Ear cup',(s*.149,0,1.498),(s*.18,0,1.498),.071,olive,'panel','head',.061,12)
        rod('Ear inset',(s*.18,0,1.498),(s*.187,0,1.498),.044,black,'joint','head',.044,12)
    # Solid folded leaf badge and visible stem.
    poly('Civic golden leaf',[(.066,.113,1.162),(.071,.119,1.211),(.115,.118,1.232),(.11,.123,1.178),(.092,.132,1.194)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)],gold,'badge','chest')
    rod('Badge vein',(.066,.135,1.161),(.106,.135,1.22),.0025,edge,'badge','chest',.001,5)
    for s,suf in [(-1,'r'),(1,'l')]:
        upper='upper_arm_'+suf;fore='forearm_'+suf;hand='hand_'+suf;thigh='thigh_'+suf;shin='shin_'+suf;foot='foot_'+suf
        ball('Shoulder universal joint',(s*.209,0,1.211),(.079,.074,.078),black,'joint',upper,2)
        ringform('Shoulder enamel cap',[(s*.23,0,1.147,.077,.076),(s*.23,0,1.222,.082,.078),(s*.217,0,1.276,.058,.055)],cream,'shell',upper,12)
        rod('Upper arm shell',(s*.245,0,1.148),(s*.279,0,1.019),.058,cream,'shell',upper,.049,10)
        ball('Elbow flex joint',(s*.285,0,.985),(.049,.05,.048),black,'joint',fore,2)
        rod('Elbow olive cap',(s*.287,.043,.985),(s*.287,.056,.985),.034,olive,'panel',fore,.034,10)
        rod('Forearm enamel',(s*.294,0,.94),(s*.33,.005,.805),.052,cream,'shell',fore,.040,10)
        ball('Wrist joint',(s*.34,.005,.77),(.034,.034,.035),black,'joint',hand,1)
        box('Hand enamel plate',(s*.348,.005,.728),(.066,.045,.079),cream,'shell',hand,.016)
        for f in range(4):
            x=s*(.323+f*.015)
            rod('Robot finger',(x,.005,.704),(x+s*.009,.018,.663),.008,black,'joint',hand,.007,6)
        rod('Robot thumb',(s*.316,.005,.747),(s*.303,.034,.71),.011,black,'joint',hand,.009,7)
        ball('Hip actuator',(s*.10,0,.783),(.074,.083,.078),black,'joint',thigh,2)
        ringform('Thigh armour '+suf,[(s*.11,0,.48,.062,.074),(s*.106,0,.64,.076,.087),(s*.10,0,.766,.073,.08)],cream,'shell',thigh,12)
        ball('Knee hinge',(s*.11,0,.431),(.055,.063,.055),black,'joint',shin,2)
        box('Knee olive pad',(s*.11,.063,.436),(.075,.029,.08),olive,'panel',shin,.015)
        ringform('Shin armour '+suf,[(s*.11,0,.139,.051,.056),(s*.11,0,.23,.06,.069),(s*.11,0,.34,.073,.075),(s*.11,0,.388,.061,.064)],cream,'shell',shin,12)
        ball('Ankle joint',(s*.11,0,.108),(.042,.046,.043),black,'joint',foot,1)
        box('Robot planted foot',(s*.11,.050,.065),(.14,.224,.109),cream,'shell',foot,.028)
        box('Robot tread',(s*.11,.05,.020),(.146,.228,.037),black,'joint',foot,.009)
    return 'character_robot'

def animate(robot=False):
    bpy.context.scene.render.fps=24
    for name,frames in [('idle',72),('walk',24),('sit',48),('typing',32)]:
        RIG.animation_data_create();action=bpy.data.actions.new(name);RIG.animation_data.action=action
        for f in range(1,frames+2):
            phase=(f-1)/frames*math.tau
            for p in RIG.pose.bones:p.rotation_euler=(0,0,0);p.location=(0,0,0)
            root=RIG.pose.bones['hips']
            if name in ('sit','typing'):
                # Pelvis at .54m, thighs forward and shins vertically down.
                root.location=RIG.data.bones['hips'].matrix_local.to_3x3().inverted()@Vector((0,0,.54-(.8 if robot else .88)))
                for suf in ['l','r']:
                    angle=math.acos((.54-(.43 if robot else .46))/(.37 if robot else .42))
                    RIG.pose.bones['thigh_'+suf].rotation_euler.x=angle
                    RIG.pose.bones['shin_'+suf].rotation_euler.x=-angle
                    RIG.pose.bones['upper_arm_'+suf].rotation_euler.x=.35 if name=='sit' else .54
                    RIG.pose.bones['forearm_'+suf].rotation_euler.x=.35 if name=='sit' else 1.0
                    RIG.pose.bones['hand_'+suf].rotation_euler.x=-.12+(.035*math.sin(phase+(0 if suf=='l' else math.pi)) if name=='typing' else 0)
                RIG.pose.bones['chest'].rotation_euler.x=.035+.015*math.sin(phase)
                RIG.pose.bones['head'].rotation_euler.x=.07 if name=='typing' else -.025
            elif name=='walk':
                root.location=RIG.data.bones['hips'].matrix_local.to_3x3().inverted()@Vector((0,0,.009*(1-math.cos(phase*2))))
                for sign,suf in [(1,'l'),(-1,'r')]:
                    q=phase+(0 if sign==1 else math.pi)
                    RIG.pose.bones['thigh_'+suf].rotation_euler.x=.38*math.sin(q)
                    RIG.pose.bones['shin_'+suf].rotation_euler.x=-.52*max(0,-math.sin(q))
                    RIG.pose.bones['foot_'+suf].rotation_euler.x=.09*math.sin(q)
                    RIG.pose.bones['upper_arm_'+suf].rotation_euler.x=-.26*math.sin(q)
                    RIG.pose.bones['forearm_'+suf].rotation_euler.x=.10+.10*max(0,math.sin(q))
                RIG.pose.bones['chest'].rotation_euler.z=.035*math.sin(phase)
            else:
                RIG.pose.bones['chest'].rotation_euler.x=.013*math.sin(phase)
                RIG.pose.bones['head'].rotation_euler.z=.018*math.sin(phase)
            if name in ('walk','sit','typing'):
                bpy.context.view_layer.update()
                graph=bpy.context.evaluated_depsgraph_get()
                soles=[o for o in PARTS if ('Rubber sole' in o.name or 'Robot tread' in o.name)]
                floor=min((o.evaluated_get(graph).matrix_world@v.co).z for o in soles for v in o.evaluated_get(graph).data.vertices)
                root.location += RIG.data.bones['hips'].matrix_local.to_3x3().inverted()@Vector((0,0,.001-floor))
            for p in RIG.pose.bones:
                p.keyframe_insert('rotation_euler',frame=f,group=p.name);p.keyframe_insert('location',frame=f,group=p.name)
        track=RIG.animation_data.nla_tracks.new();track.name=name;strip=track.strips.new(name,1,action);strip.name=name
        RIG.animation_data.action=None;track.mute=True
    for p in RIG.pose.bones:p.rotation_euler=(0,0,0);p.location=(0,0,0)
    bpy.context.scene.frame_set(1)

def save_export(name):
    animate(name.endswith('robot'))
    RIG['authoring']='OpenAI Codex original constructed geometry, original weights and clips';RIG['status']='Review candidate'
    # Every source object remains separately editable in the Blender source.
    for ob in PARTS:
        if ob.get('character_part') in ['hair_1','hair_2','hair_3']:ob.hide_render=True
    bpy.ops.wm.save_as_mainfile(filepath=str(DEST/(name+'.blend')))
    grouped={}
    for o in PARTS:grouped.setdefault(o['character_part'],[]).append(o)
    exports=[]
    for label,objects in grouped.items():
        copies=[]
        for ob in objects:
            dup=ob.copy();dup.data=ob.data.copy();bpy.context.collection.objects.link(dup);dup.hide_render=False;dup.parent=RIG;copies.append(dup)
        bpy.ops.object.select_all(action='DESELECT')
        for ob in copies:ob.select_set(True)
        bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();ob=bpy.context.object;ob.name=label
        world=ob.matrix_world.copy();ob.parent=None;ob.matrix_world=world
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        exports.append(ob)
    bpy.ops.object.select_all(action='DESELECT');RIG.select_set(True)
    for ob in exports:ob.select_set(True)
    bpy.context.view_layer.objects.active=RIG
    bpy.ops.export_scene.gltf(filepath=str(DEST/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_skins=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_apply=False,export_texcoords=False)
    triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in exports)
    weights=[]
    for ob in exports:
        for v in ob.data.vertices:weights.append(sum(g.weight for g in v.groups))
    bpy.context.view_layer.update()
    points=[o.matrix_world@v.co for o in exports for v in o.data.vertices]
    report={'bounds_min':[round(min(p[i] for p in points),6) for i in range(3)],'bounds_max':[round(max(p[i] for p in points),6) for i in range(3)],'name':name,'triangles':triangles,'mesh_parts':list(grouped),'bones':[b.name for b in RIG.data.bones],'animations':['idle','walk','sit','typing'],'editable_meshes':len(PARTS),'weight_min':min(weights),'weight_max':max(weights),'unweighted_vertices':sum(w<.999 for w in weights)}
    (DEST/(name+'.json')).write_text(json.dumps(report,indent=2));print('FINISHED',json.dumps(report),flush=True)
    return report

def validate_reimport():
    results={}
    for name in ['character_human','character_robot']:
        clean()
        for a in list(bpy.data.actions):bpy.data.actions.remove(a)
        bpy.ops.import_scene.gltf(filepath=str(DEST/(name+'.glb')))
        rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
        skinned=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
        assert len(rig.data.bones)==17
        clips={t.name:t.strips[0].action for t in rig.animation_data.nla_tracks}
        assert set(clips)=={'idle','walk','sit','typing'}
        for t in rig.animation_data.nla_tracks:t.mute=True
        record={'bones':len(rig.data.bones),'skinned_meshes':len(skinned),'clips':{},'unweighted_vertices':0}
        for ob in skinned:
            for v in ob.data.vertices:
                assert abs(sum(g.weight for g in v.groups)-1)<.0001
        for clip,action in clips.items():
            rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
            samples=[]
            for f in [1,(action.frame_range.y+1)/4,(action.frame_range.y+1)/2]:
                bpy.context.scene.frame_set(int(f));bpy.context.view_layer.update()
                hands=[list(rig.matrix_world@rig.pose.bones['hand_'+side].head) for side in ['l','r']]
                feet=[list(rig.matrix_world@rig.pose.bones['foot_'+side].head) for side in ['l','r']]
                samples.append({'frame':int(f),'hips':[round(x,5) for x in rig.pose.bones['hips'].head],'hands':hands,'ankles':feet})
                # Evaluated geometry proves armature deformation survived GLB reimport.
                graph=bpy.context.evaluated_depsgraph_get();vs=[]
                for ob in skinned:
                    evaluated=ob.evaluated_get(graph);vs += [evaluated.matrix_world@v.co for v in evaluated.data.vertices]
                samples[-1]['bounds_min']=[round(min(p[i] for p in vs),5) for i in range(3)]
                samples[-1]['bounds_max']=[round(max(p[i] for p in vs),5) for i in range(3)]
            record['clips'][clip]=samples
        assert record['clips']['walk'][0]['hands']!=record['clips']['walk'][1]['hands']
        assert record['clips']['sit'][0]['hips'][2] < record['clips']['idle'][0]['hips'][2]-.2
        results[name]=record
    (ROOT/'reports'/'characters-reimport-validation.json').write_text(json.dumps(results,indent=2))
    print('REIMPORT_VALIDATED',json.dumps({n:{'bones':x['bones'],'skinned_meshes':x['skinned_meshes'],'clips':list(x['clips'])} for n,x in results.items()}),flush=True)

def pose_proof():
    # Static evaluated proof poses from the shipped GLB, separate from game assets.
    for name in ['character_human','character_robot']:
        clean()
        for a in list(bpy.data.actions):bpy.data.actions.remove(a)
        bpy.ops.import_scene.gltf(filepath=str(DEST/(name+'.glb')))
        rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
        sources=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers) and o.name not in ['hair_1','hair_2','hair_3']]
        actions={t.name:t.strips[0].action for t in rig.animation_data.nla_tracks}
        for t in rig.animation_data.nla_tracks:t.mute=True
        proof=[]
        for index,(clip,frame) in enumerate([('idle',1),('walk',7),('sit',1),('typing',9)]):
            action=actions[clip];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
            bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();graph=bpy.context.evaluated_depsgraph_get()
            for source in sources:
                evaluated=source.evaluated_get(graph);data=bpy.data.meshes.new_from_object(evaluated,preserve_all_data_layers=True,depsgraph=graph)
                ob=bpy.data.objects.new(clip+' / '+source.name,data);bpy.context.collection.objects.link(ob);ob.matrix_world=source.matrix_world;ob.location.x+=index*.95-1.425;proof.append(ob)
        for ob in list(bpy.context.scene.objects):
            if ob not in proof:bpy.data.objects.remove(ob,do_unlink=True)
        bpy.ops.object.select_all(action='DESELECT')
        for ob in proof:ob.select_set(True)
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'reports'/(name+'-pose-proof.blend')))
        bpy.ops.export_scene.gltf(filepath=str(ROOT/'reports'/(name+'-pose-proof.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_texcoords=False)
        print('POSE_PROOF',name,'left-to-right idle,walk,sit,typing',flush=True)

if __name__=='__main__':
    chosen=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['human','robot']
    if chosen==['pose-proof']:
        pose_proof();sys.exit(0)
    if chosen==['validate']:
        validate_reimport();sys.exit(0)
    for c in chosen:
        save_export(human() if c=='human' else robot())
