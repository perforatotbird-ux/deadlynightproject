import bpy,bmesh,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];report={}
for path in sorted((ROOT/'assets/models/resources').glob('*.glb')):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.ops.import_scene.gltf(filepath=str(path))
 objects=[o for o in bpy.context.selected_objects if o.type=='MESH'];assert len(objects)==1,path.name
 o=objects[0];m=o.data;bm=bmesh.new();bm.from_mesh(m)
 # glTF splits vertices at hard normals/UV seams; weld positions for topology audit only.
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
 bad=sum(not e.is_manifold for e in bm.edges);zero=sum(f.calc_area()<1e-12 for f in bm.faces)
 pending=set(bm.faces);volumes=[]
 while pending:
  first=pending.pop();todo=[first];island={first}
  while todo:
   f=todo.pop()
   for e in f.edges:
    for q in e.link_faces:
     if q in pending:pending.remove(q);island.add(q);todo.append(q)
  volume=0
  for f in island:
   a=f.verts[0].co
   for j in range(1,len(f.verts)-1):volume+=a.dot(f.verts[j].co.cross(f.verts[j+1].co))/6
  volumes.append(volume)
 assert bad==0,(path.name,'nonmanifold',bad)
 assert zero==0,(path.name,'zero area',zero)
 assert all(v>0 for v in volumes),(path.name,'inward islands',volumes)
 assert len(m.uv_layers)>0 and len(m.color_attributes)>0 and len(m.materials)==1
 report[path.stem]={'triangles':sum(len(p.vertices)-2 for p in m.polygons),'nonmanifold_edges':bad,'zero_area':zero,'closed_components':len(volumes),'outward_winding':True,'UV':True,'vertex_colors':True,'materials':1}
 bm.free()
assert len(report)==25,len(report)
(ROOT/'art/source/resources/topology_audit.json').write_text(json.dumps(report,indent=2));print('TOPOLOGY AUDIT: 25 assets PASS')
