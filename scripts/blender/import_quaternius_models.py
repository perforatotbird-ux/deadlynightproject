"""Adapt downloaded CC0 Quaternius meshes to existing Deadly Night sockets.
Run Blender with --background --factory-startup --disable-autoexec --python FILE.
No procedural replacement meshes: only authored geometry, transforms, materials.
"""
import bpy, math, json, hashlib
from bisect import bisect_left
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[2]
SOURCES=ROOT/'third_party/quaternius/source'
DEST=ROOT/'assets/models/external/quaternius'
TREES={
 'birch':('BirchTree_1.blend',18.0,0.35,(0.65544,0.68595,0.62574,1)),
 'spruce':('PineTree_1.blend',24.0,0.50,(0.29,0.22,0.16,1)),
 'beech':('CommonTree_3.blend',24.0,0.60,(0.48,0.49,0.49,1)),
 'oak':('CommonTree_1.blend',20.0,0.70,(0.24,0.15,0.10,1)),
}
REPORT=[]
def open_source(name):
 bpy.ops.wm.open_mainfile(filepath=str(SOURCES/name),load_ui=False,use_scripts=False)
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 assert meshes, name
 for o in list(bpy.context.scene.objects):
  if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
 for o in meshes:
  o.data=o.data.copy()
  for v in o.data.vertices:v.co=o.matrix_world@v.co
  o.matrix_world=Matrix.Identity(4)
 return meshes

def set_material(mat,name,color,metallic=0.0,roughness=0.9):
 mat.name=name;mat.diffuse_color=color;mat.use_nodes=True
 nodes=mat.node_tree.nodes;nodes.clear()
 out=nodes.new('ShaderNodeOutputMaterial');bs=nodes.new('ShaderNodeBsdfPrincipled')
 bs.inputs['Base Color'].default_value=color;bs.inputs['Roughness'].default_value=roughness;bs.inputs['Metallic'].default_value=metallic
 mat.node_tree.links.new(bs.outputs['BSDF'],out.inputs['Surface'])

def export(meshes,name):
 bpy.ops.object.select_all(action='DESELECT')
 for o in meshes:o.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0]
 if len(meshes)>1:bpy.ops.object.join()
 o=bpy.context.view_layer.objects.active;o.name=name;o.data.name=name
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 # Fully baked single mesh: WorldMap MultiMesh and close-up trees share it.
 bpy.ops.export_scene.gltf(filepath=str(DEST/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False,export_apply=True)
 vs=[v.co for v in o.data.vertices];o.data.calc_loop_triangles()
 REPORT.append({'model':name,'vertices':len(vs),'triangles':len(o.data.loop_triangles),'blender_bounds':[[min(v[a] for v in vs) for a in range(3)],[max(v[a] for v in vs) for a in range(3)]],'materials':[m.name for m in o.data.materials]})

for sp,(source,height,radius,bark_color) in TREES.items():
 meshes=open_source(source)
 trunk=[]
 for o in meshes:
  ids=set()
  for f in o.data.polygons:
   mat=o.data.materials[f.material_index]
   if not any(word in mat.name.lower() for word in ['green','leaf']):ids.update(f.vertices)
  trunk.extend(o.data.vertices[i].co.copy() for i in ids)
 assert trunk,source
 low=min(v.z for v in trunk);high=max(v.co.z for o in meshes for v in o.data.vertices)
 # Fit trunk radius at the gameplay strike band, not canopy width or roots.
 base=[v for v in trunk if v.z<low+0.06*(high-low)]
 center=Vector((sum(v.x for v in base)/len(base),sum(v.y for v in base)/len(base),0))
 zscale=height/(high-low)
 near=[v for v in trunk if 0.7<(v.z-low)*zscale<2.8]
 if len(near)<5:near=base
 # Radius relative to trunk centre: retained collision and carving parameters.
 radial=sorted(math.hypot(v.x-center.x,v.y-center.y) for v in near)
 fit_radius=radial[int((len(radial)-1)*0.90)]
 xy=radius/max(fit_radius,0.001)
 # The source birch has an offset/bent stem. Existing radial carving requires
 # the lower stem to contain local XZ=0. Straighten only that authored stem
 # (and transport its markings), retaining the source canopy and topology.
 centers=[]
 if sp=="birch":
  for step in range(41):
   y=step*0.2;z=low+y/zscale+0.00001
   crossings=[]
   for o in meshes:
    for face in o.data.polygons:
     material=o.data.materials[face.material_index].name.lower()
     if material!="white":continue
     coords=[o.data.vertices[i].co for i in face.vertices]
     for a,b in zip(coords,coords[1:]+coords[:1]):
      if (a.z<=z<b.z) or (b.z<=z<a.z):
       crossings.append(a.lerp(b,(z-a.z)/(b.z-a.z)))
   if crossings:
    c=Vector(((min(v.x for v in crossings)+max(v.x for v in crossings))/2,(min(v.y for v in crossings)+max(v.y for v in crossings))/2,0))
    centers.append(c)
   else:centers.append(centers[-1].copy() if centers else center.copy())
  # Calibrate the actual closed bark section at normal chopping height.
  at=low+1.3/zscale;ring=[]
  for o in meshes:
   for face in o.data.polygons:
    if o.data.materials[face.material_index].name.lower()!="white":continue
    coords=[o.data.vertices[i].co for i in face.vertices]
    for a,b in zip(coords,coords[1:]+coords[:1]):
     if (a.z<=at<b.z) or (b.z<=at<a.z):ring.append(a.lerp(b,(at-a.z)/(b.z-a.z)))
  middle=centers[6].lerp(centers[7],0.5)
  fit_radius=max(math.hypot(v.x-middle.x,v.y-middle.y) for v in ring)
  xy=radius/fit_radius
 for o in meshes:
  for v in o.data.vertices:
   y=(v.co.z-low)*zscale;c=center
   if centers:
    t=max(0,min(40,y/0.2));i=min(39,int(t));c=centers[i].lerp(centers[i+1],t-i)
   v.co=Vector(((v.co.x-c.x)*xy,(v.co.y-c.y)*xy,y))
  for mat in o.data.materials:
   old=mat.name.lower();col=tuple(mat.diffuse_color)
   if any(k in old for k in ['green','leaf']):
    # Preserve source's two foliage tones, slightly muted for the survival palette.
    col=(col[0]*0.90,col[1]*0.92,col[2]*0.90,col[3]);name='M_Foliage_'+sp+'_'+old
   elif 'black' in old:name='M_Bark_'+sp+'_markings'
   else:col=bark_color;name='M_Bark_'+sp
   set_material(mat,name,col)
 export(meshes,'tree_'+sp)

meshes=open_source('Axe.blend')
vs=[v.co.copy() for o in meshes for v in o.data.vertices]
low=min(v.z for v in vs);high=max(v.z for v in vs);scale=0.678/(high-low)
# Match the original +Y blade orientation in Blender (= -Z in Godot).
rotation=Matrix.Rotation(-math.pi/2,4,'Z')
grip=[v for v in vs if 0.12<(v.z-low)*scale<0.32]
center=Vector((sum(v.x for v in grip)/len(grip),sum(v.y for v in grip)/len(grip),low))
for o in meshes:
 for v in o.data.vertices:v.co=rotation@((v.co-center)*scale)
 for mat in o.data.materials:
  old=mat.name.lower();col=tuple(mat.diffuse_color)
  if 'grey' in old:set_material(mat,'M_Axe_Iron_Quaternius',col,0.75,0.38)
  elif 'red' in old:set_material(mat,'M_Axe_PaintedHead_Quaternius',col,0.35,0.6)
  else:set_material(mat,'M_Axe_Handle_Quaternius',col,0,0.84)
export(meshes,'axe_quaternius')
(ROOT/'third_party/quaternius/conversion-report.json').write_text(json.dumps(REPORT,indent=2)+'\n')
print('CONVERSION_OK',json.dumps(REPORT))
