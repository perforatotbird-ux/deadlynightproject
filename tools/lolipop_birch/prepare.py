#!/usr/bin/env python3
"""Split the supplied Sketchfab GLB into five grounded, 18m trees and authored LODs.
Run: python tools/lolipop_birch/prepare.py [source.glb]
Retains authored geometry/UV/normals; extracts shared 2K PNG textures.
The lower stem shares the leaf atlas in the source: tag its connected components
as bark separately, otherwise the game's axe/cut code would ignore that stem.
"""
import copy, io, json, struct, sys, hashlib
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
SRC=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'art/source/lolipop/five_birch_trees_pack_lowpoly_lods.glb'
OUT=ROOT/'assets/models/external/lolipop'; OUT.mkdir(parents=True,exist_ok=True)
with SRC.open('rb') as f:
 assert f.read(4)==b'glTF'; version,total=struct.unpack('<II',f.read(8)); assert version==2
 size,kind=struct.unpack('<II',f.read(8)); doc=json.loads(f.read(size));size,kind=struct.unpack('<II',f.read(8)); blob=f.read(size)
def read_acc(i):
 a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']]
 count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
 dtype=np.dtype({5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']])
 return np.ndarray((a['count'],count),dtype=dtype,buffer=blob,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',dtype.itemsize*count),dtype.itemsize)).copy()
names=['bark_color','bark_normal','atlas_color','atlas_normal']
for name,img in zip(names,doc['images']):
 v=doc['bufferViews'][img['bufferView']];im=Image.open(io.BytesIO(blob[v['byteOffset']:v['byteOffset']+v['byteLength']]))
 im.thumbnail((2048,2048),Image.Resampling.LANCZOS);im.save(OUT/(name+'.png'),optimize=True)
materials=copy.deepcopy(doc['materials'])
materials[1]['name']='Birch_foliage';materials[0]['name']='Birch_bark'
materials.append(copy.deepcopy(materials[1]));materials[2]['name']='Birch_bark_base';materials[2].pop('alphaMode',None);materials[2].pop('alphaCutoff',None)
# Main and authored LOD1 / LOD2 mesh pairs in supplied GLB. Ignore exhibit transforms.
sets=[[(4,5),(0,1),(2,3)],[(8,9),(10,11),(6,7)],[(14,15),(16,17),(12,13)],[(20,21),(22,23),(18,19)],[(26,27),(28,29),(24,25)]]
def components(vertices,indices):
 _,inv=np.unique(np.round(vertices,5),axis=0,return_inverse=True);parent=np.arange(max(inv)+1)
 def root(x):
  while parent[x]!=x:parent[x]=parent[parent[x]];x=parent[x]
  return x
 for tri in inv[indices]:
  for x in tri[1:]:parent[root(x)]=root(tri[0])
 groups={}
 for i,tri in enumerate(indices):groups.setdefault(root(inv[tri[0]]),[]).append(i)
 return list(groups.values())
report={'source_sha256':hashlib.sha256(SRC.read_bytes()).hexdigest(),'source_url':'https://sketchfab.com/3d-models/five-birch-trees-pack-lowpoly-lods-08fe5117138e4fdaa7ca440ef1201e07','author':'LOLIPOP (@lolipop_1707)','license':'CC-BY-4.0','texture_max_dimension':2048,'variants':[]}
for variant,levels in enumerate(sets):
 allv=np.concatenate([read_acc(doc['meshes'][mi]['primitives'][0]['attributes']['POSITION']) for mi in levels[0]])
 ground=float(allv[:,2].min());scale=18/(float(allv[:,2].max())-ground)
 entry={'variant':variant,'height':18.0,'levels':[]};bark_low=[]
 for lod,pair in enumerate(levels):
  primitives=[];data=bytearray();views=[];accessors=[];counts=[]
  def add(arr,kind):
   while len(data)%4:data.append(0)
   offset=len(data);data.extend(arr.tobytes());views.append({'buffer':0,'byteOffset':offset,'byteLength':arr.nbytes})
   a={'bufferView':len(views)-1,'componentType':5125 if arr.dtype.kind=='u' else 5126,'count':len(arr),'type':kind}
   if kind=='VEC3':a.update(min=arr.min(0).tolist(),max=arr.max(0).tolist())
   accessors.append(a);return len(accessors)-1
  for mi in pair:
   p=doc['meshes'][mi]['primitives'][0];attrs={k:read_acc(v) for k,v in p['attributes'].items()};idx=read_acc(p['indices']).reshape(-1,3)
   original=attrs['POSITION'].copy();is_atlas=mi==pair[1]
   groups=[(idx,0)]
   if is_atlas:
    low=[]
    for comp in components(original,idx):
     pts=original[idx[comp].ravel()]
     if pts[:,2].min()<0.10 and pts[:,2].max()<2.1:low.extend(comp)
    mask=np.zeros(len(idx),bool);mask[low]=True;assert mask.any(),f'No stem found for {variant} LOD{lod}'
    groups=[(idx[mask],2),(idx[~mask],1)]
   for selected,material in groups:
    used,remap=np.unique(selected.ravel(),return_inverse=True);aa={k:v[used].copy() for k,v in attrs.items()}
    for key in ['POSITION','NORMAL','TANGENT']:
     if key not in aa:continue
     old=aa[key].copy();aa[key][:,0]=old[:,0];aa[key][:,1]=old[:,2];aa[key][:,2]=-old[:,1]
     if key=='POSITION':aa[key][:,1]-=ground;aa[key]*=scale
    # Source materials are texture driven. Retain exact white tint (tests must not assume nonwhite).
    primitive={'attributes':{k:add(v.astype('<f4'),f'VEC{v.shape[1]}') for k,v in aa.items()},'indices':add(remap.astype('<u4').reshape(-1,1),'SCALAR'),'material':material,'mode':4}
    primitives.append(primitive);counts.append(len(selected))
    if lod==0 and material in [0,2]:bark_low.append(aa['POSITION'])
  out={'asset':{'version':'2.0','generator':'Deadly Night LOLIPOP adapter (authored topology retained)'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'name':f'Birch_{variant}_LOD{lod}','mesh':0}], 'meshes':[{'name':f'Birch_{variant}_LOD{lod}','primitives':primitives}],'materials':materials,'textures':copy.deepcopy(doc['textures']),'images':[{'uri':name+'.png'} for name in names], 'buffers':[{'byteLength':len(data)}], 'bufferViews':views,'accessors':accessors}
  if 'samplers' in doc:out['samplers']=doc['samplers']
  j=json.dumps(out,separators=(',',':')).encode();j+=b' '*((-len(j))%4);data+=b'\0'*((-len(data))%4)
  path=OUT/f'birch_{variant}_lod{lod}.glb'
  path.write_bytes(struct.pack('<III',0x46546C67,2,28+len(j)+len(data))+struct.pack('<II',len(j),0x4E4F534A)+j+struct.pack('<II',len(data),0x004E4942)+data)
  entry['levels'].append({'lod':lod,'triangles':sum(counts),'surface_triangles':counts,'file':path.name})
 low=np.concatenate(bark_low);low=low[(low[:,1]>.25)&(low[:,1]<3.0)]
 entry['radius']=round(max(.35,float(np.linalg.norm(low[:,[0,2]],axis=1).max())/1.45),4)
 report['variants'].append(entry)
(OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
