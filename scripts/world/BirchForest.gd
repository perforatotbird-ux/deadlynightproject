extends RefCounted
## HLOD: preserve authored geometry nearby; eight-view impostors retain the far forest.
const CELL_SIZE:=128.0
const ENTER:=256.0
const LEAVE:=288.0
const DIR="res://assets/models/external/lolipop/"
var cells:Dictionary={}
var far_meshes:Dictionary={}
var world:Node3D
var last_position:=Vector3(INF,INF,INF)
var active:Dictionary={}
var shader:Shader=preload("res://scripts/world/birch_impostor.gdshader")
func _init(owner_world:Node3D)->void:world=owner_world
func cell_key(p:Vector3)->Vector2i:return Vector2i(floori(p.x/CELL_SIZE),floori(p.z/CELL_SIZE))
func mesh_for(key:String)->Mesh:
 if far_meshes.has(key):return far_meshes[key]
 var variant:=int(key.trim_prefix("birch_"))
 var material:=ShaderMaterial.new();material.shader=shader
 material.set_shader_parameter("atlas",load(DIR+"birch_%d_impostor.png"%variant))
 var mesh:=QuadMesh.new();mesh.size=Vector2(24,24);mesh.center_offset=Vector3(0,9,0);mesh.material=material
 far_meshes[key]=mesh;return mesh
func add_batch(parent:Node3D,key:String,records:Array,detail:Mesh,index:Dictionary,hidden:Dictionary)->void:
 # Far batch: large source chunk, one surface, no shadow passes.
 var far:=MultiMesh.new();far.transform_format=MultiMesh.TRANSFORM_3D;far.mesh=mesh_for(key);far.instance_count=records.size()
 var far_node:=MultiMeshInstance3D.new();far_node.name="HLOD_"+key;far_node.multimesh=far;far_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 # Quad rotates in shader. Supply conservative bounds for every camera azimuth.
 var bounds:=AABB();var first:=true
 var groups:Dictionary={}
 for i in records.size():
  var record:Dictionary=records[i];var a:Array=record.pos
  var pos:=Vector3(a[0],a[2],-a[1]);var cell:=cell_key(pos)
  if not groups.has(cell):groups[cell]=[]
  groups[cell].append([record,i,pos])
  var scale_value:float=record.get("scale",1.0)
  var b:=AABB(pos-Vector3(18,3,18)*scale_value,Vector3(36,24,36)*scale_value)
  bounds=b if first else bounds.merge(b);first=false
 far.custom_aabb=bounds;parent.add_child(far_node)
 for cell in groups:
  var local_records:Array=groups[cell]
  var center:=Vector3((cell.x+0.5)*CELL_SIZE,0,(cell.y+0.5)*CELL_SIZE)
  var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=detail;mm.instance_count=local_records.size()
  var node:=MultiMeshInstance3D.new();node.name="Detail_"+key;node.position=center;node.multimesh=mm;node.visible=false;parent.add_child(node)
  if not cells.has(cell):cells[cell]={"nodes":[],"ids":[]}
  cells[cell].nodes.append(node)
  for i in local_records.size():
   var entry:Array=local_records[i];var record:Dictionary=entry[0];var id:String=record.get("id","")
   var full:=Transform3D(Basis(Vector3.UP,deg_to_rad(record.get("yaw_deg",0.0))).scaled(Vector3.ONE*record.get("scale",1.0)),entry[2])
   var local:=full;local.origin-=center
   var pos_id:="pos_%d_%d_%d"%[roundi(full.origin.x),roundi(full.origin.y),roundi(full.origin.z)]
   if world.TreeChoppable.felled_tree_ids.has(id) or world.TreeChoppable.felled_tree_ids.has(pos_id):hidden[id]=true
   index[id]={"mm":mm,"index":i,"xform":local,"far_mm":far,"far_index":entry[1],"far_xform":full,"cell":cell,"near":false}
   cells[cell].ids.append(id)
   sync(index[id],hidden.has(id))
func sync(data:Dictionary,hidden:bool)->void:
 var near_x:Transform3D=data.xform;var far_x:Transform3D=data.far_xform
 if hidden or not data.near:near_x.basis=Basis.IDENTITY.scaled(Vector3.ZERO)
 if hidden or data.near:far_x.basis=Basis.IDENTITY.scaled(Vector3.ZERO)
 data.mm.set_instance_transform(data.index,near_x)
 data.far_mm.set_instance_transform(data.far_index,far_x)
func update(position:Vector3,index:Dictionary,hidden:Dictionary,force:bool=false)->void:
 if not force and position.distance_squared_to(last_position)<64:return
 last_position=position
 var wanted:Dictionary={};var cell:=cell_key(position)
 # Fixed-size local lookup, not a traversal of all world cells.
 for x in range(cell.x-3,cell.x+4):
  for z in range(cell.y-3,cell.y+4):
   var key:=Vector2i(x,z)
   if not cells.has(key):continue
   var cx:float=(x+0.5)*CELL_SIZE;var cz:float=(z+0.5)*CELL_SIZE
   var dx:=position.x-cx;var dz:=position.z-cz
   var radius:=LEAVE if active.has(key) else ENTER
   if dx*dx+dz*dz<=radius*radius:wanted[key]=true
 for key in active:
  if not wanted.has(key):set_cell(key,false,index,hidden)
 for key in wanted:
  if not active.has(key):set_cell(key,true,index,hidden)
 active=wanted
func set_cell(key:Vector2i,near:bool,index:Dictionary,hidden:Dictionary)->void:
 for id in cells[key].ids:
  var data:Dictionary=index[id];data.near=near;sync(data,hidden.has(id))
 for node in cells[key].nodes:node.visible=near
