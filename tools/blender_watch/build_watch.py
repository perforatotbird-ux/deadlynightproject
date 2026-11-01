"""DN / Traverse 01. Deterministic authored left forearm and round field watch.
Run inside Blender 4.5+, directly or through execute_blender_code (MCP).
Coordinates G are Godot's X-right/Y-up/Z-toward viewer; Blender maps (x,-z,y).
The anatomical topology and finger weights are CC0, see vendor/PROVENANCE.md.
"""
import bpy,bmesh,math,json,sys,os
from pathlib import Path
from mathutils import Vector, Quaternion
ROOT=Path(os.environ.get('DN_PROJECT',str(Path(__file__).resolve().parents[2])))
HERE=ROOT/'tools/blender_watch';sys.path.insert(0,str(HERE/'vendor'))
OUT=ROOT/'assets/models/viewmodels/watch';SOURCE=ROOT/'art/source/watch'
OUT.mkdir(parents=True,exist_ok=True);SOURCE.mkdir(parents=True,exist_ok=True)
PI=math.pi;TAU=math.tau

def P(g):return Vector((g[0],-g[2],g[1]))
def G(p):return Vector((p.x,p.z,-p.y))
def mat(name,color,rough=.5,metal=0,emit=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 s=m.node_tree.nodes.get('Principled BSDF');s.inputs['Base Color'].default_value=(*color,1);s.inputs['Roughness'].default_value=rough;s.inputs['Metallic'].default_value=metal
 if emit:s.inputs['Emission Color'].default_value=(*color,1);s.inputs['Emission Strength'].default_value=emit
 return m

def assign(o,m):o.data.materials.append(m);return o

def mesh(name,verts,faces,m=None):
 me=bpy.data.meshes.new(name+'Geometry');me.from_pydata([P(v) for v in verts],[],faces);me.update()
 ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob)
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
 for f in me.polygons:f.use_smooth=True
 if m:assign(ob,m)
 return ob

def bevel(o,width=.001,segments=3):
 mod=o.modifiers.new('Manufactured fillets','BEVEL');mod.width=width;mod.segments=segments
 return o

def box(name,size,loc,m,width=.0007):
 bpy.ops.mesh.primitive_cube_add(size=1,location=P(loc));o=bpy.context.object;o.name=name;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);assign(o,m)
 bevel(o,min(width,min(size)*.22))
 for f in o.data.polygons:f.use_smooth=True
 mod=o.modifiers.new('Face weighted normals','WEIGHTED_NORMAL');mod.keep_sharp=True
 return o

def revolve(name,profile,center,m,segments=96):
 verts=[];faces=[]
 for radius,z in profile:
  for i in range(segments):
   a=i*TAU/segments;verts.append((center[0]+radius*math.cos(a),center[1]+radius*math.sin(a),z))
 for j in range(len(profile)):
  for i in range(segments):faces.append((j*segments+i,j*segments+(i+1)%segments,((j+1)%len(profile))*segments+(i+1)%segments,((j+1)%len(profile))*segments+i))
 return mesh(name,verts,faces,m)

def text(name,body,loc,size,m):
 c=bpy.data.curves.new(name,'FONT');c.body=body;c.align_x='CENTER';c.align_y='CENTER';c.size=size;c.extrude=.000015;c.resolution_u=3
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.location=P(loc);o.rotation_euler=(PI/2,0,0);assign(o,m)
 return o

def tube_curve(name,points,radius,m):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=2;c.bevel_depth=radius;c.bevel_resolution=2
 s=c.splines.new('POLY');s.points.add(len(points)-1)
 for t,p in zip(s.points,points):t.co=(*P(p),1)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);assign(o,m);return o

def activate(o):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o

def frozen_copy(o,name):
 dg=bpy.context.evaluated_depsgraph_get();me=bpy.data.meshes.new_from_object(o.evaluated_get(dg),depsgraph=dg)
 c=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(c);return c

def setup():
 for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
 for block in [bpy.data.meshes,bpy.data.curves,bpy.data.materials,bpy.data.cameras,bpy.data.lights]:
  for item in list(block):
   if item.users==0:block.remove(item)
 for col in list(bpy.data.collections):
  if col.name!='Collection' and col.users==0:bpy.data.collections.remove(col)
 scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=24;scene.cycles.use_denoising=True
 scene.render.threads_mode='FIXED';scene.render.threads=2
 scene.render.resolution_x=1280;scene.render.resolution_y=800;scene.render.resolution_percentage=100
 scene.world.color=(.045,.045,.045);scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG'
 scene.render.film_transparent=False
setup()
skin=mat('Skin / warm neutral',(.47,.28,.19),.53)
bs=skin.node_tree.nodes.get('Principled BSDF');bs.inputs['Subsurface Weight'].default_value=.09
uv=skin.node_tree.nodes.new('ShaderNodeTexCoord')
for file,socket in [('skin_albedo.png','Base Color'),('skin_normal.png','Normal')]:
 im=bpy.data.images.load(str(OUT/file),check_existing=True);t=skin.node_tree.nodes.new('ShaderNodeTexImage');t.image=im;skin.node_tree.links.new(uv.outputs['UV'],t.inputs['Vector'])
 if socket=='Normal':
  im.colorspace_settings.name='Non-Color';n=skin.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.35;skin.node_tree.links.new(t.outputs['Color'],n.inputs['Color']);skin.node_tree.links.new(n.outputs['Normal'],bs.inputs[socket])
 else:skin.node_tree.links.new(t.outputs['Color'],bs.inputs[socket])
nailmat=mat('Nail / ivory keratin',(.43,.28,.21),.48)
cuticlemat=mat('Nail fold',(.31,.17,.12),.61)
rubber=mat('Strap / graphite elastomer',(.017,.022,.028),.78)
recess=mat('Recess / soft black',(.004,.007,.009),.86)
case=mat('Case / basalt composite',(.026,.036,.047),.36,.25)
steel=mat('Hardware / brushed titanium',(.20,.25,.29),.27,.85)
blue=mat('Bezel / deep petrol anodized',(.025,.12,.18),.29,.7)
lcd=mat('LCD / blue black',(.008,.025,.034),.26,.12,.15)
ink=mat('Dial / ice phosphor',(.39,.72,.75),.55,0,.45)
# Anatomical CC0 quad topology, adapted from MakeHuman hm08 (see vendor provenance).
# Palm, thenar eminence, finger webs, distal loops and wrist are one surface.
data=json.loads((HERE/'vendor/anatomical_left_forearm.json').read_text())
def adapt(v):
 g=Vector(v);g.y-=max(0,-g.x)*.060;g.z-=max(0,-g.x)*.22+.010;g.z=-g.z
 return g
vertices=[adapt(v) for v in data['vertices']]
joints={name:[adapt(v) for v in chain] for name,chain in data['joints'].items()}
# Bone-local flexion, with smooth distance-based blending around each knuckle.
chains={}
for label,js in joints.items():
 if label=='1':angles=[5,10,15]
 else:angles=[75,140,170]
 if label=='5':angles=[80,145,175]
 qs=[Quaternion(Vector((0,1,0)),math.radians(a)) for a in angles]
 if label=='1':qs=[Quaternion(Vector((0,0,1)),math.radians(-50))@q for q in qs]
 if label=='4':qs=[Quaternion(Vector((0,0,1)),math.radians(10))@q for q in qs]
 posed=[js[0]]
 for i in range(3):posed.append(posed[-1]+qs[i]@(js[i+1]-js[i]))
 if label=='5':
  for i in range(1,4):posed[i].y+=.006*i
 chains[label]=(js,qs,posed)
def segment_distance(v,a,b):
 d=b-a;t=max(0,min(1,(v-a).dot(d)/d.length_squared));return (v-(a+d*t)).length
# Use the anatomical source's CC0 vertex weights, not nearest-finger guesses.
rest=[v.copy() for v in vertices];weighted=[Vector() for v in rest];totals=[0. for v in rest]
for bone,entries in data['weights'].items():
 label=bone[6];segment=int(bone[8])-1;js,qs,posed=chains[label]
 for vi,weight in entries:
  weighted[vi]+=(posed[segment]+qs[segment]@(rest[vi]-js[segment]))*weight;totals[vi]+=weight
for vi in range(len(vertices)):
 total=totals[vi]
 if total>1:vertices[vi]=weighted[vi]/total
 else:vertices[vi]=weighted[vi]+rest[vi]*(1-total)
hand=mesh('LeftArm_EditableCage',vertices,data['faces'],skin)
uv=hand.data.uv_layers.new(name='AnatomicalUV')
for poly,coords in zip(hand.data.polygons,data['uvs']):
 for li,co in zip(poly.loop_indices,coords):uv.data[li].uv=co
# A planar, capped forearm cut; remove the ragged partial source rings.
bm=bmesh.new();bm.from_mesh(hand.data)
bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.000001,plane_co=P((-.235,0,0)),plane_no=Vector((1,0,0)),clear_inner=True,clear_outer=False)
edge=[e for e in bm.edges if e.is_boundary]
# Continue the proximal viewmodel beyond the frustum; no severed cap in gameplay.
for cut_x in [-.27,-.34,-.42]:
 result=bmesh.ops.extrude_edge_only(bm,edges=edge)
 newverts=[v for v in result['geom'] if isinstance(v,bmesh.types.BMVert)]
 for v in newverts:v.co.x=cut_x
 edge=[e for e in bm.edges if e.is_boundary]
bmesh.ops.holes_fill(bm,edges=edge,sides=0);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(hand.data);bm.free()
# Self-contained viewmodel UVs allocate the full tile to the arm, not a whole body.
activate(hand);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.012);bpy.ops.object.mode_set(mode='OBJECT')
sub=hand.modifiers.new('Anatomical subdivision','SUBSURF');sub.levels=1;sub.render_levels=3
arm=frozen_copy(hand,'LeftArm_Skin')
for f in arm.data.polygons:f.use_smooth=True
# The watch is fitted around the actual narrow wrist. Axis is forearm X.
CX=-.025;RY=.0258;RZ=.0230;W=.023
v=[];f=[];N=128
for inner in [False,True]:
 for edge in [-1,1]:
  for i in range(N):
   a=i*TAU/N;ry=RY-(.002 if inner else 0);rz=RZ-(.002 if inner else 0)
   v.append((CX+edge*W/2,ry*math.sin(a),rz*math.cos(a)))
for i in range(N):
 j=(i+1)%N
 for a,b in [(0,1),(1,3),(3,2),(2,0)]:f.append((a*N+i,a*N+j,b*N+j,b*N+i))
strap=mesh('WatchStrap',v,f,rubber);bevel(strap,.00045,2)
# Moulded ribs / recessed vents fitted to curved band, symmetrical on both flanks.
for side in [-1,1]:
 for k in range(6):
  a=side*(.62+k*.24);pts=[]
  for i in range(16):
   x=CX-W*.38+W*.76*i/15;pts.append((x,(RY+.00015)*math.sin(a),(RZ+.00015)*math.cos(a)))
  tube_curve('Strap_moulded_rib',pts,.00035,case)
 for k in range(4):
  a=side*(.82+k*.30);pts=[]
  for i in range(10):
   x=CX-W*.23+W*.46*i/9;pts.append((x,(RY+.0003)*math.sin(a),(RZ+.0003)*math.cos(a)))
  tube_curve('Vent_recess',pts,.00042,recess)
# Physical buckle and keeper beneath the wrist.
for x in [CX-.010,CX+.010]:box('Buckle_rail',(.002,.018,.002),(x,-.002,-.0213),steel,.0006)
for y in [-.011,.007]:box('Buckle_bridge',(.022,.002,.002),(CX,y,-.0213),steel,.0006)
box('Buckle_tang',(.0018,.015,.0018),(CX,-.001,-.023),steel,.0005)
# Stepped multi-profile watch case, back plate, metal lip and petrol bezel.
center=(CX,0)
revolve('CaseBack',[(.0004,.0198),(.022,.0198),(.024,.021),(.024,.023),(.0004,.023)],center,steel)
revolve('RoundCase',[(.0004,.0215),(.0245,.0215),(.026,.023),(.0263,.027),(.0258,.030),(.0248,.0315),(.021,.0315),(.021,.028),(.0004,.028)],center,case)
revolve('PetrolBezel',[(.0204,.0297),(.0249,.0297),(.0254,.0305),(.0251,.0322),(.0245,.033),(.0203,.033),(.0199,.0324)],center,blue)
revolve('InnerMetalLip',[(.0195,.0318),(.0203,.0318),(.0205,.0327),(.0200,.0331),(.0195,.0329)],center,steel)
revolve('LCD',[(.00003,.0316),(.0195,.0316),(.0195,.0325),(.00003,.0325)],center,lcd)
# Paired lugs mechanically join case to rubber; rounded guards flank pushbuttons.
for side in [-1,1]:
 for x in [-1,1]:box('StrapLug',(.0075,.010,.007),(CX+x*.009,side*.024,.025),case,.0015)
 for y in [-.010,.010]:
  box('ButtonGuard',(.006,.009,.008),(CX+side*.0255,y,.026),case,.0014)
  box('PushButton',(.0035,.005,.0046),(CX+side*.029,y,.0266),steel,.001)
# Real face indices and four screw heads instead of a texture pretending to be a case.
for i in range(60):
 a=i*TAU/60;major=i%5==0;r=.0220
 o=box('BezelIndex_%02d'%i,(.00055 if not major else .00085,.001 if not major else .0018,.00012),(CX+math.sin(a)*r,math.cos(a)*r,.03313),ink,.00008)
 o.rotation_euler[1]=-a
for i in range(4):
 a=PI/4+i*PI/2;sx=CX+math.cos(a)*.023;sy=math.sin(a)*.023
 revolve('BezelScrew',[(.00003,.033),(.001,.033),(.0011,.03325),(.0009,.0335),(.00003,.0335)],(sx,sy),steel,24)
 box('ScrewSlot',(.0012,.00024,.00007),(sx,sy,.03355),recess,.00004)
text('Brand','TRAVERSE', (CX,.0123,.03272),.0027,ink)
text('ModelName','FIELD / 01',(CX,-.0129,.03272),.0019,ink)
# Editable, runtime-facing display anchor. No baked time, pulse or fake health stats.
anchor=bpy.data.objects.new('DisplayAnchor',None);bpy.context.collection.objects.link(anchor);anchor.location=P((CX,0,.03285))
# Source-only time sample for rendered previews. Real game uses Label3D.
time=text('PreviewTime','19:42',(CX,.0017,.03284),.0080,ink)
day=text('PreviewDay','DAY 04',(CX,-.007,.03284),.0027,ink)
time['preview_only']=True;day['preview_only']=True
# Separate editable high-poly construction, runtime assembly and preview staging.
source_col=bpy.data.collections.new('SOURCE / editable high-poly');bpy.context.scene.collection.children.link(source_col)
for c in list(hand.users_collection):c.objects.unlink(hand)
source_col.objects.link(hand);hand.hide_render=True;hand.hide_set(True)
runtime=[o for o in bpy.context.scene.objects if o!=hand and not o.get('preview_only')]
for o in runtime:
 if o.type in {'MESH','CURVE','FONT'}:o['asset_role']='watch_viewmodel'
# Parent all export nodes to a semantic assembly root.
root=bpy.data.objects.new('TraverseLeftArm',None);bpy.context.collection.objects.link(root)
for o in runtime:o.parent=root
# Materials ship as actual PBR textures, not Blender-only procedural nodes.
for im in bpy.data.images:
 if im.source=='FILE':im.pack()
# Build camera and lights explicitly. Graybox/diagnostic cameras remain in source.
def camera(name,loc,target,lens=60,ortho=None):
 d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.location=P(loc);o.rotation_euler=(P(target)-o.location).to_track_quat('-Z','Y').to_euler();d.lens=lens;d.clip_start=.001
 if ortho:d.type='ORTHO';d.ortho_scale=ortho
 return o
hero=camera('HeroCamera',(.03,.13,.72),(-.055,0,0),58)
reference=camera('ReferenceCamera',(.20,.16,.67),(-.055,0,0),58)
for name,loc in [('Front',(0,0,.8)),('Back',(0,0,-.8)),('Left',(-.8,0,0)),('Right',(.8,0,0)),('Top',(0,.8,0))]:camera('Diagnostic_'+name,loc,(-.055,0,0),ortho=.52)
for name,loc,power,size,color in [('Key',(-.1,.25,.4),5,.32,(1,.89,.78)),('Fill',(.25,-.2,.25),2,.3,(.68,.82,1)),('Rim',(-.2,.2,-.15),4,.25,(.70,.84,1))]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=color;o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.location=P(loc);o.rotation_euler=(P((-.05,0,0))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.context.scene.camera=hero
# Batch repeated detail by material to avoid one draw call per tick/screw.
keep={'LeftArm_Skin','WatchStrap','RoundCase','LCD','DisplayAnchor'}
small=[o for o in runtime if o.name not in keep and o.type in {'MESH','CURVE','FONT'}]
for o in small:
 activate(o);bpy.ops.object.convert(target='MESH')
by_mat={}
for o in small:
 key=o.data.materials[0].name if o.data.materials else 'unassigned';by_mat.setdefault(key,[]).append(o)
for key,objects in by_mat.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();bpy.context.object.name='Detail_'+key.split(' / ')[0].replace(' ','_')
for o in root.children:
 if o.type!='MESH' or o.name=='LeftArm_Skin':continue
 # Apply remaining modifiers and clean tiny redundant manufacturing edges.
 activate(o);bpy.ops.object.convert(target='MESH')
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8)
 bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-9)
 bmesh.ops.triangulate(bm,faces=list(bm.faces))
 tiny=[f for f in bm.faces if f.calc_area()<=1e-12]
 if tiny:bmesh.ops.delete(bm,geom=tiny,context='FACES_ONLY')
 bm.to_mesh(o.data);bm.free();o.data.update()
runtime=list(root.children)
# Export only the runtime assembly; dense editable cage and time samples excluded.
bpy.ops.object.select_all(action='DESELECT');root.select_set(True)
for o in runtime:o.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(OUT/'left_arm_round_watch.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_materials='EXPORT',export_extras=True)
# Source defaults to the dense, editable anatomical surface; runtime copy stays separate.
hand.hide_render=False;hand.hide_set(False);arm.hide_render=True;arm.hide_set(True)
sub.levels=3
bpy.context.view_layer.update()
hi=hand.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh();hi.calc_loop_triangles();high_count=len(hi.loop_triangles);hand.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'left_arm_round_watch.blend'))
# Report evaluated counts and dimensions, not just control-cage counts.
dg=bpy.context.evaluated_depsgraph_get();triangles=0;verts_count=0
for o in runtime:
 if o.type=='MESH':
  m=o.evaluated_get(dg).to_mesh();m.calc_loop_triangles();triangles+=len(m.loop_triangles);verts_count+=len(m.vertices);o.evaluated_get(dg).to_mesh_clear()
metrics={'blender':bpy.app.version_string,'runtime_mesh_triangles':triangles,'runtime_vertices':verts_count,'runtime_nodes':len(runtime)+1,'high_poly_subdivision':3,'high_poly_arm_triangles':high_count,'arm_length_m':.57,'watch_diameter_m':.053,'source':str((SOURCE/'left_arm_round_watch.blend').relative_to(ROOT)),'export':str((OUT/'left_arm_round_watch.glb').relative_to(ROOT))}
(SOURCE/'build_metrics.json').write_text(json.dumps(metrics,indent=2))
print('DN_WATCH_BUILD',json.dumps(metrics))
