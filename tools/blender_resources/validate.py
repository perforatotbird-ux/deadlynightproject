import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[2];stage=sys.argv[sys.argv.index('--')+1];S=R/'art/source/resources';data=json.loads((S/(stage+'_metrics.json')).read_text());report={}
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
assets=[]
for j,name in enumerate(data):
 bpy.ops.import_scene.gltf(filepath=str(R/'assets/models/resources'/(name+'.glb')))
 o=[o for o in bpy.context.selected_objects if o.type=='MESH'][0];m=o.data
 zeros=sum(p.area<1e-12 for p in m.polygons)
 assert zeros==0,(name,zeros)
 assert len(m.materials)==1
 assert len(m.uv_layers)>0 and len(m.color_attributes)>0
 assert all(math.isfinite(v.co.length) for v in m.vertices)
 report[name]={'triangles':sum(len(p.vertices)-2 for p in m.polygons),'zero_area':zeros,'materials':len(m.materials),'uv':True,'colors':True}
 # imported GLB has Y-up hierarchy; apply object world transform before arrange.
 world=o.matrix_world.copy();o.parent=None;o.matrix_world=world
 bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 assets.append(o)
(S/(stage+'_reimport.json')).write_text(json.dumps(report,indent=2))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True;scene.render.threads_mode='FIXED';scene.render.threads=2;scene.world.color=(.25,.25,.25)
center=Vector((0,0,0))
def aim(o):o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
for loc in [(-2,-3,4),(3,3,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=400;o.data.size=4;aim(o)
bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=5.3 if stage=='branches' else 3.4;scene.camera=cam;scene.render.resolution_x=1000;scene.render.resolution_y=650;scene.render.resolution_percentage=100
views={'perspective':(1,-3,3),'front':(0,-4,.1),'back':(0,4,.1),'left':(-4,0,.1),'right':(4,0,.1),'top':(0,0,4),'underside':(0,-1,-4)}
for key,d in views.items():
 cam.location=center+Vector(d);aim(cam)
 rotation=cam.rotation_euler.to_quaternion();right=rotation@Vector((1,0,0));up=rotation@Vector((0,1,0));spacing=1.23 if stage=='branches' else .76
 columns=min(4,len(assets));rows=math.ceil(len(assets)/columns)
 for idx,obj in enumerate(assets):
  bounds=[Vector(corner) for corner in obj.bound_box];localcenter=sum(bounds,Vector())/8
  obj.location=right*((idx%columns-(columns-1)/2)*spacing)+up*(((rows-1)/2-idx//columns)*spacing)-localcenter
 scene.render.filepath=str(S/(stage+'_'+key+'.png'));bpy.ops.render.render(write_still=True)
print('REIMPORT PASS',json.dumps(report))
