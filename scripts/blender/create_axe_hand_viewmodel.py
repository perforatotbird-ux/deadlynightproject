"""Original closed-grip leather hand and cloth sleeves, authored with Blender.
Run with Blender 5.2: blender -b --python this.py -- /path/to/repository
Also runs with the official bpy Python package. Exports self-contained .gltf;
no external downloads, proprietary mesh, textures or runtime Blender dependency.
"""
import bpy, math, json, base64, sys
from pathlib import Path
from mathutils import Vector, Matrix
ROOT = Path(sys.argv[sys.argv.index('--')+1]) if '--' in sys.argv else Path(__file__).resolve().parents[2]
WORK = Path('/data/axe-hand-work') if Path('/data').exists() else ROOT/'build/axe_hands'
WORK.mkdir(parents=True, exist_ok=True)
OUT = ROOT/'assets/models/viewmodels/axe_grip_hands.gltf'
OUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def v(p): return Vector((p[0], -p[2], p[1])) # Godot -> Blender, preserve metres

def mat(name, color, rough=.8):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*color,1); bs.inputs['Roughness'].default_value=rough
    return m
leather=mat('Worn brown leather glove',(.085,.045,.022),.84)
seam=mat('Glove seam leather',(.31,.215,.14),.92)
cloth=mat('Olive canvas sleeve',(.035,.055,.042),.96)
cuff=mat('Dark ribbed cuff',(.015,.025,.020),.98)

def objmesh(name, vertices, faces, material):
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(vertices,[],faces); mesh.update()
    o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o); o.data.materials.append(material)
    for p in mesh.polygons: p.use_smooth=True
    return o

def tube(name, points, radii, material, sides=12):
    pts=[v(p) for p in points]; verts=[]; faces=[]
    for i,p in enumerate(pts):
        t=(pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized()
        a=v((0,1,0)); a=(a-t*a.dot(t)).normalized(); b=t.cross(a).normalized()
        r=radii[i]; r=(r,r) if isinstance(r,(int,float)) else r
        for j in range(sides):
            q=p+a*(math.cos(j*2*math.pi/sides)*r[0])+b*(math.sin(j*2*math.pi/sides)*r[1]); verts.append(q)
    for i in range(len(pts)-1):
        for j in range(sides):
            a=i*sides+j; b=i*sides+(j+1)%sides; faces.append((a,b,b+sides,a+sides))
    faces.append(tuple(reversed(range(sides)))); faces.append(tuple((len(pts)-1)*sides+j for j in range(sides)))
    return objmesh(name,verts,faces,material)

def smooth_path(points,radii,steps=4):
    ps=[Vector(p) for p in points]; out=[]; rs=[]
    for i in range(len(ps)-1):
        p0=ps[max(0,i-1)];p1=ps[i];p2=ps[i+1];p3=ps[min(len(ps)-1,i+2)]
        for j in range(steps):
            t=j/steps
            out.append(tuple(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)))
            rs.append(radii[i]*(1-t)+radii[i+1]*t)
    out.append(tuple(ps[-1])); rs.append(radii[-1]); return out,rs

# Palm has an anatomical tapered wrist, broad metacarpals and a rounded heel.
sections=[(.158,-.021,.025,.019,.018),(.140,-.018,.024,.026,.023),(.117,-.012,.020,.033,.025),(.093,-.005,.011,.046,.028),(.068,.000,.004,.051,.027),(.046,.001,.000,.048,.024),(.028,.000,-.003,.034,.017)]
verts=[];faces=[];sides=20
for x,y,z,ry,rz in sections:
    for j in range(sides):
        a=j*2*math.pi/sides; verts.append(v((x,y+ry*math.cos(a),z+rz*math.sin(a))))
for i in range(len(sections)-1):
    for j in range(sides):
        a=i*sides+j; b=i*sides+(j+1)%sides; faces.append((a,b,b+sides,a+sides))
faces.extend([tuple(reversed(range(sides))),tuple((len(sections)-1)*sides+j for j in range(sides))])
parts=[objmesh('Palm',verts,faces,leather)]
# Four distinct fingers, with MCP/PIP/DIP bends wrapped around the handle.
for label,y,r,reach in [('Index',.031,.0105,1),('Middle',.009,.011,1.05),('Ring',-.014,.0102,.98),('Little',-.035,.0088,.87)]:
    pts=[(.054,y,-.018),(.032,y,-.032),(.006,y,-.041),(-.023,y,-.027),(-.029,y,.002),(-.018,y,.029),(-.004,y,.035)]
    pts=[(x*reach, yy, z) for x,yy,z in pts]
    points,rads=smooth_path(pts,[r*1.08,r,r*1.02,r*.96,r*.88,r*.82,r*.66],4)
    parts.append(tube(label,points,rads,leather,12))
# Opposed thumb comes around the other side, crossing the index finger.
points,rads=smooth_path([(.112,.021,.020),(.090,.043,.029),(.066,.058,.037),(.040,.062,.041),(.016,.050,.041),(-.002,.039,.038)],[.023,.022,.018,.0155,.0135,.0105],5)
parts.append(tube('Opposed thumb',points,rads,leather,14))
# Remesh the joined volume: palm/webbing/fingers are ONE continuous hand mesh.
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();hand=parts[0];hand.name='RightHand'
hand.data.remesh_voxel_size=.00165
bpy.ops.object.voxel_remesh()
sm=hand.modifiers.new('Sculpt surface relaxation','SMOOTH');sm.factor=.48;sm.iterations=5
bpy.ops.object.modifier_apply(modifier=sm.name)
dec=hand.modifiers.new('Game mesh reduction','DECIMATE');dec.ratio=min(1,3800/len(hand.data.polygons))
bpy.ops.object.modifier_apply(modifier=dec.name)
for p in hand.data.polygons:p.use_smooth=True
# Wrist cuff, in hand-local coordinates; follows the same grip transform.
points=[(.150,-.021,.025),(.160,-.021,.025),(.173,-.022,.026)]
cuffmesh=tube('RightWristCuff',points,[(.026,.024),(.028,.026),(.028,.026)],cuff,18)
# Rig marker used to connect forearm to the wrist, not to the handle centre.
marker=bpy.data.objects.new('WristSocket',None);bpy.context.collection.objects.link(marker);marker.location=v((.165,-.021,.025))

# Sleeves have radial cloth folds, shaped elbow volume and tapered wrist ends.
def sleeve(name,radii):
    vertices=[];faces=[];n=20;rows=len(radii)
    for i,r in enumerate(radii):
        y=-.5+i/(rows-1)
        for j in range(n):
            angle=j*2*math.pi/n
            wrinkle=1+.035*math.sin(j*3.0+i*1.7)+.018*math.cos(j*5-i*.8)
            vertices.append(v((math.cos(angle)*r*wrinkle,y,math.sin(angle)*r*wrinkle)))
    for i in range(rows-1):
        for j in range(n):
            a=i*n+j;b=i*n+(j+1)%n;faces.append((a,b,b+n,a+n))
    o=objmesh(name,vertices,faces,cloth)
    o.data.materials.append(cuff)
    for p in o.data.polygons:
        if name=='ForearmSleeve' and p.center.z>.40:p.material_index=1
    return o
upper=sleeve('UpperSleeve',[.073,.076,.073,.069,.071,.064,.062,.061,.058])
fore=sleeve('ForearmSleeve',[.059,.061,.056,.055,.053,.052,.048,.047,.040,.039])
# Bake a left-hand mesh with corrected winding: no negative runtime scale or
# flipped back-face culling on the inside of the glove.
left_parts=[]
for original,name in [(hand,'LeftHand'),(cuffmesh,'LeftWristCuff')]:
    left=original.copy();left.data=original.data.copy();left.name=name
    bpy.context.collection.objects.link(left)
    left.data.transform(Matrix.Diagonal((-1,1,1,1)))
    left.data.flip_normals();left_parts.append(left)
# Organise source assets, keeping the sleeve source meshes off the hand preview.
for o in [upper,fore]+left_parts:o.hide_render=True
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'axe_grip_hands.blend'))
for o in [upper,fore]+left_parts:o.hide_render=False
# Shared mesh material data, metres, glTF Y-up; use embedded buffer so Git/Godot
# do not require an LFS binary or texture downloads to load this viewmodel.
bpy.ops.export_scene.gltf(filepath=str(WORK/'hands.gltf'),export_format='GLTF_SEPARATE',export_animations=False,export_cameras=False,export_lights=False,export_yup=True)
d=json.loads((WORK/'hands.gltf').read_text())
for buf in d.get('buffers',[]):
    buf['uri']='data:application/octet-stream;base64,'+base64.b64encode((WORK/buf['uri']).read_bytes()).decode()
OUT.write_text(json.dumps(d,separators=(',',':')))
print('EXPORTED',OUT,OUT.stat().st_size,'hand polygons',len(hand.data.polygons))
# Blender preview: original axe is imported only into the preview/source scene.
for o in [upper,fore]+left_parts:o.hide_render=True
axe_path=ROOT/'assets/models/props/axe_iron.glb'
if axe_path.exists():
    prior=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(axe_path))
    for o in set(bpy.data.objects)-prior:
        if o.parent is None:o.location+=v((0,-.15,0))
# Hand centre is where the axe handle actually curves at this grip height.
for o in [hand,cuffmesh,marker]:o.location+=v((0,0,-.035))
world=bpy.context.scene.world or bpy.data.worlds.new('World');bpy.context.scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.14,.16,1);world.node_tree.nodes['Background'].inputs[1].default_value=.45

def area(name,pos,energy,size):
    light=bpy.data.lights.new(name,'AREA');light.energy=energy;light.shape='DISK';light.size=size
    o=bpy.data.objects.new(name,light);bpy.context.collection.objects.link(o);o.location=v(pos);o.rotation_euler=(v((.02,.15,0))-o.location).to_track_quat('-Z','Y').to_euler()
area('Soft key',(.5,.6,.6),15,.6);area('Edge light',(-.4,.2,-.5),10,.5)
camdata=bpy.data.cameras.new('Preview camera');cam=bpy.data.objects.new('Preview camera',camdata);bpy.context.collection.objects.link(cam)
cam.location=v((.52,.26,.58));target=v((.045,.03,-.03));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();camdata.type='ORTHO';camdata.ortho_scale=.43
scene=bpy.context.scene;scene.camera=cam;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1000;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(WORK/'hand_grip_preview.png');scene.view_settings.view_transform='AgX'
bpy.ops.render.render(write_still=True)
# Editable .blend opens as a clean grip study with the project's axe reference;
# hidden template sleeves/left-hand data remain available in the Outliner.
for o in [upper,fore,marker]+left_parts:o.hide_set(True)
bpy.ops.object.select_all(action='DESELECT');hand.hide_set(False);hand.select_set(True);bpy.context.view_layer.objects.active=hand
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'axe_grip_hands.blend'))
