"""Fresh-process native/export check. Run with Blender --background --python ..."""
import bpy,bmesh,json,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];qa=ROOT/'art/source/watch/qa';qa.mkdir(exist_ok=True)
def topology(obj,weld=False):
 dg=bpy.context.evaluated_depsgraph_get();ev=obj.evaluated_get(dg);me=ev.to_mesh();me.calc_loop_triangles();count=len(me.loop_triangles)
 bm=bmesh.new();bm.from_mesh(me)
 if weld:bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
 report={'triangles':count,'boundary_edges':sum(e.is_boundary for e in bm.edges),'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges),'components_note':'UV-split GLB vertices welded at 0.1 micron only for topology inspection' if weld else 'native connected surface','invalid_vertices':sum(not all(math.isfinite(a) for a in v.co) for v in bm.verts)}
 bm.free();ev.to_mesh_clear();return report
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/source/watch/left_arm_round_watch.blend'))
source=topology(bpy.data.objects['LeftArm_EditableCage']);packed=[im.name for im in bpy.data.images if im.packed_file]
assert source['triangles']>=200000 and source['boundary_edges']==0 and source['nonmanifold_edges']==0,source
assert len(packed)>=2,'Source textures must be packed'
lights=[]
for o in bpy.data.objects:
 if o.type=='LIGHT':lights.append((o.name,o.data.copy(),o.matrix_world.copy()))
for o in list(bpy.data.objects):bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/viewmodels/watch/left_arm_round_watch.glb'))
arm=bpy.data.objects.get('LeftArm_Skin');assert arm is not None
fresh=topology(arm,True);assert fresh['invalid_vertices']==0 and fresh['boundary_edges']==0 and fresh['nonmanifold_edges']==0,fresh
mesh_objects=[o for o in bpy.data.objects if o.type=='MESH'];triangles=sum(topology(o)['triangles'] for o in mesh_objects)
assert len(mesh_objects)<=12 and 20000<triangles<100000
assert bpy.data.objects.get('DisplayAnchor') is not None
assert bpy.data.objects.get('LeftArm_EditableCage') is None and bpy.data.objects.get('PreviewTime') is None
assert not [o for o in bpy.data.objects if o.type in {'CAMERA','LIGHT'}]
report={'blender':bpy.app.version_string,'checks_passed':True,'source_arm':source,'source_packed_images':packed,'fresh_runtime_arm':fresh,'runtime_total_triangles':triangles,'runtime_mesh_objects':len(mesh_objects),'preview_time_exported':False,'scope':'static posed hand; rigid T animation tested in Godot, no individual-finger rig claimed'}
(qa/'source_export_validation.json').write_text(json.dumps(report,indent=2)+'\n')
# Render the actual reimported runtime file, not the authored high-poly object.
for name,data,matrix in lights:
 o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);o.matrix_world=matrix
d=bpy.data.cameras.new('FreshImportCamera');d.lens=60;d.clip_start=.001
cam=bpy.data.objects.new('FreshImportCamera',d);bpy.context.collection.objects.link(cam);cam.location=(.10,-.38,.115);cam.rotation_euler=(Vector((.004,-.01,0))-cam.location).to_track_quat('-Z','Y').to_euler()
s=bpy.context.scene;s.camera=cam;s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=24;s.cycles.use_denoising=True;s.render.threads_mode='FIXED';s.render.threads=2;s.render.resolution_x=1000;s.render.resolution_y=650;s.render.resolution_percentage=100;s.render.filepath=str(qa/'fresh_runtime_import.png');bpy.ops.render.render(write_still=True)
print('DN_SOURCE_EXPORT_VALIDATED',json.dumps(report))
