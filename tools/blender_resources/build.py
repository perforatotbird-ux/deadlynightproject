import bpy, math, random, json, sys
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'assets/models/resources'; SRC=ROOT/'art/source/resources'
STAGE=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'stone'
random.seed(421)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
# Packed, exportable original grain texture, shared by each family.
def material(family):
 import numpy as np
 rng=np.random.default_rng(42); n=512
 y,x=np.mgrid[:n,:n]; grain=rng.random((n,n))
 if family=='branch': g=.70+.10*np.sin(x*.37+np.sin(y*.023)*3)+.10*grain+.07*np.sin(x*1.3)
 elif family=='pyrite':g=.80+.08*np.sin(x*1.7)+.12*grain
 elif family=='fungi':g=.80+.12*grain+.07*np.sin(x*.13+np.sin(y*.03))
 else:g=.76+.18*grain+.025*np.sin(x*.09+np.sin(y*.035)*4)*np.sin(y*.07)
 pix=np.ones((n,n,4),dtype=np.float32);pix[:,:,:3]=g[:,:,None]
 im=bpy.data.images.new(family+'_grain',width=n,height=n);im.pixels.foreach_set(pix.ravel());im.filepath_raw=str(OUT/(family+'_grain.png'));im.file_format='PNG';im.save();im.pack()
 m=bpy.data.materials.new(family+'_PBR');m.use_nodes=True;nd=m.node_tree.nodes;lk=m.node_tree.links;p=nd.get('Principled BSDF');p.inputs['Roughness'].default_value=.36 if family=='pyrite' else .82;p.inputs['Metallic'].default_value=.82 if family=='pyrite' else 0
 t=nd.new('ShaderNodeTexImage');t.image=im;c=nd.new('ShaderNodeVertexColor');c.layer_name='Color';mix=nd.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;lk.new(t.outputs['Color'],mix.inputs[1]);lk.new(c.outputs['Color'],mix.inputs[2]);lk.new(mix.outputs[0],p.inputs['Base Color']);return m
FAMILY={'stone':'stone','minerals':'pyrite','branches':'branch','fungi':'fungi'}[STAGE];MAT=material(FAMILY)
V=[];F=[];C=[];UV=[]
def reset():V.clear();F.clear();C.clear();UV.clear()
def vert(p,c,uv=(0,0)):
 V.append(tuple(p));C.append((*c[:3],1));UV.append(uv);return len(V)-1
def face(*ids):F.append(ids)
def surface(rings,n,color,offset=(0,0,0), fan=False):
 # rings: radius,height; asymmetry is deterministic and continuous.
 rows=[]
 for j,(r,z) in enumerate(rings):
  row=[]
  for i in range(n):
   a=2*math.pi*i/n;w=1+.035*math.sin(a*5+1)+.018*math.cos(a*9)
   rr=r*w;zz=z+(.008*math.sin(a*4)*r/.2)
   co=color(j/(len(rings)-1),a) if callable(color) else color
   row.append(vert((offset[0]+rr*math.cos(a),offset[1]+rr*math.sin(a),offset[2]+zz),co,(i/n,j/(len(rings)-1))))
  rows.append(row)
 for j in range(len(rows)-1):
  for i in range(n):k=(i+1)%n;face(rows[j][i],rows[j][k],rows[j+1][k],rows[j+1][i])
 for row,rev in [(rows[0],True),(rows[-1],False)]:
  p=sum((Vector(V[i]) for i in row),Vector())/n;idx=vert(p,C[row[0]][:3],(.5,.5))
  for i in range(n):
   a,b=row[i],row[(i+1)%n];face(idx,b,a) if rev else face(idx,a,b)
def tube(points,radii,color,n=12):
 rows=[]
 for j,pt in enumerate(points):
  p=Vector(pt);d=Vector(points[min(j+1,len(points)-1)])-Vector(points[max(j-1,0)]);d.normalize();u=d.cross(Vector((0,0,1)))
  if u.length<.01:u=d.cross(Vector((0,1,0)))
  u.normalize();v=d.cross(u);row=[]
  for i in range(n):
   a=i*2*math.pi/n;r=radii[j]*(1+.055*math.sin(i*2.7+j*.3));co=color(j,i) if callable(color) else color
   row.append(vert(p+r*(u*math.cos(a)+v*math.sin(a)),co,(i/n,j/(len(points)-1))))
  rows.append(row)
 for j in range(len(rows)-1):
  for i in range(n):k=(i+1)%n;face(rows[j][i],rows[j][k],rows[j+1][k],rows[j+1][i])
 for row,pt,rev in [(rows[0],points[0],True),(rows[-1],points[-1],False)]:
  center=vert(pt,(.56,.38,.20),(.5,.5))
  for i in range(n):
   a,b=row[i],row[(i+1)%n];face(center,b,a) if rev else face(center,a,b)
def rock(scale,seed,flint=False):
 rng=random.Random(seed);n=32;rows=[];ph=[rng.uniform(-.3,.3) for _ in range(8)]
 for j in range(1,17):
  lat=math.pi*j/17;row=[]
  for i in range(n):
   a=i*math.tau/n;noise=1+.12*math.sin(a*3+ph[0]+lat*2)+.065*math.sin(a*7+lat*5+ph[1]);r=math.sin(lat)*noise
   z=math.cos(lat);z=max(-.78,z)
   if flint:z=z*.65+.10*math.cos(r*25+a*.8)
   p=(r*math.cos(a)*scale[0],r*math.sin(a)*scale[1],(z+.80)*scale[2]);co=(.15,.18,.20) if flint else ((.30+.055*(seed%4)+.035*math.sin(a*3),.32+.035*(seed%3)+.025*math.sin(lat*4),.30+.028*(seed%2)))
   if flint and (j>12 or (i<7 and j>5)):co=(.64,.59,.47)
   row.append(vert(p,co,(i/n,j/17)))
  rows.append(row)
 for j in range(len(rows)-1):
  for i in range(n):k=(i+1)%n;face(rows[j][i],rows[j][k],rows[j+1][k],rows[j+1][i])
 for row in [rows[0],rows[-1]]:
  p=sum((Vector(V[i]) for i in row),Vector())/n;v=vert(p,C[row[0]][:3],(.5,.5))
  for i in range(n):face(v,row[i],row[(i+1)%n]) if row==rows[-1] else face(v,row[(i+1)%n],row[i])
def append_object(o,color):
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 mesh=o.to_mesh();base=len(V)
 for v in mesh.vertices:vert(o.matrix_world@v.co,color,(v.co.x*8,v.co.y*8))
 for p in mesh.polygons:face(*(base+i for i in p.vertices))
 o.to_mesh_clear();bpy.data.objects.remove(o,do_unlink=True)
def cube(p,s,rot):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p,rotation=rot);o=bpy.context.object;o.scale=(s,s,s);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);b=o.modifiers.new('Crystal edge wear','BEVEL');b.width=.0025;b.segments=2;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=b.name);append_object(o,(.65,.46,.13))
def save(name):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(V,[],F);mesh.update();
 import bmesh
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);mesh.materials.append(MAT)
 col=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
 for i,c in enumerate(C):col.data[i].color=c
 uv=mesh.uv_layers.new(name='UVMap')
 for p in mesh.polygons:
  p.use_smooth=True
  for li in p.loop_indices:uv.data[li].uv=UV[mesh.loops[li].vertex_index]
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 # Explicit normals, triangulated topology, one mesh and surface; Godot generates LOD on import.
 tri=o.modifiers.new('Export triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_vertex_color="ACTIVE",export_all_vertex_colors=True)
 bounds=[list(o.dimensions),len(mesh.vertices),len(mesh.polygons)]
 MET[name]={'dimensions_m':bounds[0],'vertices':bounds[1],'triangles':bounds[2],'surfaces':1}
 o.hide_render=True;return o
MET={};objects=[]
if STAGE=='stone':
 for i,s in enumerate([(.18,.14,.12),(.23,.14,.09),(.14,.12,.16),(.25,.18,.055)]):reset();rock(s,40+i);objects.append(save('stone_%02d'%i))
elif STAGE=='minerals':
 for i in range(3):
  reset();rock((.12,.095,.05),90+i)
  for j in range(8+i*2):cube((random.uniform(-.09,.09),random.uniform(-.07,.07),random.uniform(.06,.13)),random.uniform(.035,.085),tuple(random.uniform(-.65,.65) for _ in range(3)))
  objects.append(save('pyrite_%02d'%i))
 MAT=material('flint')
 for i,s in enumerate([(.19,.12,.065),(.15,.10,.09),(.23,.08,.04)]):reset();rock(s,120+i,True);objects.append(save('flint_%02d'%i))
elif STAGE=='branches':
 for i in range(5):
  reset();length=.42+i*.15
  pts=[(-length*.5+length*j/17,.025*math.sin(j*.22+i),.032+.015*math.sin(j*.3)) for j in range(18)];r=[(.026+i*.002)*(1-.65*j/17) for j in range(18)]
  bark=lambda j,k:(.20+.05*math.sin(k*2.5+j*.3),.115+.025*math.sin(k*2.5),.055)
  tube(pts,r,bark,16)
  if i!=0:
   p=Vector(pts[9]);fork=[p+Vector((j*.012,j*.013,math.sin(j*.1)*.03)) for j in range(13)];tube(fork,[.017*(1-.8*j/12) for j in range(13)],bark,12)
  if i>2:
   p=Vector(pts[5]);tube([p,p+Vector((.02,-.08,.025)),p+Vector((.08,-.18,.03))],[.018,.012,.005],bark,12)
  objects.append(save('branch_%02d'%i))
elif STAGE=='fungi':
 for species in ['forest_fat','wood_fan','copper_false','pale_bell','stump_fan']:
  for variant in range(2):
   reset();k=1+variant*.14
   if species in ['wood_fan','stump_fan']:
    tea=species=='stump_fan'
    for tier in range(3 if tea else 2):
     n=40;nr=9;rows=[];r=(.21-tier*.035)*k;z=.07+tier*.07
     # thick closed shell, fan spread from eccentric attachment point, scalloped margin
     for side in range(2):
      rows=[]
      for j in range(nr):
       t=(j+1)/nr;row=[]
       for aidx in range(n+1):
        a=-2.3+4.6*aidx/n;rad=r*t*(1+.045*math.cos(a*11));x=math.sin(a)*rad;y=math.cos(a)*rad
        h=z+.045*(1-t)+.009*math.sin(a*5)*t-(.008 if tea else .020)*side
        bands= .5+.5*math.sin(t*29)
        co=((.25+.25*bands,.12+.19*bands,.045+.10*bands) if tea else (.42+.18*t,.43+.17*t,.37+.15*t)) if side==0 else (.66,.62,.48)
        row.append(vert((x,y,h),co,(aidx/n,t)))
       rows.append(row)
      for j in range(nr-1):
       for aidx in range(n):
        ids=(rows[j][aidx],rows[j][aidx+1],rows[j+1][aidx+1],rows[j+1][aidx]);face(*(ids if side==0 else ids[::-1]))
      if side==0:top=rows
      else:bottom=rows
     for aidx in range(n):face(top[-1][aidx],bottom[-1][aidx],bottom[-1][aidx+1],top[-1][aidx+1])
     for edge in [0,n]:
      for j in range(nr-1):face(top[j][edge],top[j+1][edge],bottom[j+1][edge],bottom[j][edge])
     for aidx in range(n):face(top[0][aidx],top[0][aidx+1],bottom[0][aidx+1],bottom[0][aidx])
     if not tea:
      for g in range(24):
       a=-2.2+g*4.4/23;tube([(math.sin(a)*r*.18,math.cos(a)*r*.18,z+.018),(math.sin(a)*r*.6,math.cos(a)*r*.6,z-.002),(math.sin(a)*r*.94,math.cos(a)*r*.94,z-.017)],[.0025,.002,.0008],(.42,.40,.31),3)
   else:
    fat=species=='forest_fat';bell=species=='pale_bell';h=(.23 if fat else .31)*k
    tube([(.01*math.sin(j*.3),0,j*h/12) for j in range(13)],[(.055 if fat else .018)*(1-.3*j/12)+( .025*(1-j/12)**4 if bell else 0) for j in range(13)],(.69,.60,.43),20)
    if fat:profile=[(.008,h+.12),(.055,h+.12),(.11,h+.10),(.17,h+.06),(.21,h+.015),(.21,h),(.17,h-.018),(.10,h-.027),(.035,h-.02)]
    elif bell:profile=[(.006,h+.15),(.025,h+.14),(.045,h+.11),(.075,h+.065),(.11,h+.005),(.13,h-.04),(.125,h-.05),(.085,h-.04),(.025,h+.015)]
    else:profile=[(.006,h+.046),(.025,h+.044),(.05,h+.016),(.10,h+.012),(.16,h),(.18,h-.012),(.17,h-.022),(.10,h-.03),(.025,h-.02)]
    base=(.46,.29,.095) if fat else ((.73,.68,.52) if bell else (.55,.24,.075))
    def cc(t,a):
     if t>.65:return (.47,.43,.27) if fat else (.26,.23,.19)
     stripe=.92+.08*math.cos(a*(29 if bell else 7));return tuple(c*stripe for c in base)
    surface(profile,40,cc)
    if not fat:
     for g in range(30):
      a=g*math.tau/30;rad=.12 if bell else .165
      tube([(.022*math.cos(a),.022*math.sin(a),h-.025),(rad*.65*math.cos(a),rad*.65*math.sin(a),h-.039),(rad*math.cos(a),rad*math.sin(a),h-.037)],[.002,.0025,.0008],(.30,.27,.20),3)
    if species=='copper_false':surface([(.018,h*.61),(.052,h*.58),(.057,h*.55),(.020,h*.53)],32,(.77,.68,.47))
   objects.append(save(species+'_%02d'%variant))
# Save native sources before presentation offsets.
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(STAGE+'.blend')))
(SRC/(STAGE+'_metrics.json')).write_text(json.dumps(MET,indent=2))
# Render reusable evidence grid; texture is exactly the exported material.
for index,o in enumerate(objects):o.hide_render=False;o.location=(index%4*.75,index//4*.85,0)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True;scene.render.threads_mode='FIXED';scene.render.threads=2;scene.world.color=(.24,.24,.24)
center=Vector(((min(4,len(objects))-1)*.375,((len(objects)-1)//4)*.425,.08))
def aim(obj,p):obj.rotation_euler=(Vector(p)-obj.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=center+Vector((.15,-2.8,3.1)));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=3.3 if len(objects)>3 else 2.7;aim(cam,center);scene.camera=cam
for loc,power,size in [((-2,-2,4),400,4),((3,2,3),300,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=size;aim(l,center)
scene.render.resolution_x=1400;scene.render.resolution_y=1000 if len(objects)>4 else 650;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG';scene.render.filepath=str(SRC/(STAGE+'_preview.png'));bpy.ops.render.render(write_still=True)
print('ASSET_METRICS',json.dumps(MET))
