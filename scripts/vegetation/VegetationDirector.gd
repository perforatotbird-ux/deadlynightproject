extends Node3D
# Logical state persists independently of visual streaming. No timers on plants.
const Catalog=preload("res://scripts/vegetation/VegetationCatalog.gd")
const Patch=preload("res://scripts/vegetation/VegetationPatch.gd")
const Visuals=preload("res://scripts/vegetation/VegetationVisuals.gd")
const Plant=preload("res://scripts/vegetation/HarvestablePlant.gd")
const Items=preload("res://scripts/survival/SurvivalItems.gd")
var session:Node
var seed_value:=Catalog.SEED
var placement_version:=Catalog.VERSION
var harvested:Dictionary={}
var patches:Dictionary={}
var stumps:Dictionary={}
var inspected:Dictionary={}
var known:Dictionary={}
var legacy_excluded:Dictionary={}
var humid_clock:=0.0
var active:Dictionary={}
var cells:Dictionary={}
var supports:Dictionary={}
var stump_nodes:Dictionary={}
var tree_grid:Dictionary={}
var splines:Dictionary={}
var last_profile:Dictionary={}
var _tick:=0.0
var _rules_ready:=false
var exclusion_mask:Image
var _world:Node
var _indexed_chunks:Dictionary={}
func _ready() -> void:
 name="VegetationDirector"
 for id in Catalog.INITIAL_KNOWLEDGE:known[id]=true
func advance(world_seconds:float,raining:bool) -> void:
 humid_clock+=world_seconds*(1.0 if raining else Catalog.CLEAR_HUMIDITY)
func _physics_process(delta:float) -> void:
 if not is_instance_valid(session) or session.location!="forest" or not is_instance_valid(session.player):return
 _tick-=delta
 if _tick<=0:_tick=0.45;stream()
func _rules() -> void:
 if _rules_ready:return
 _rules_ready=true
 var texture:Texture2D=load("res://assets/models/vegetation/foraging_exclusions.png")
 if texture!=null:exclusion_mask=texture.get_image()
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/spec.json"))
 if data is Dictionary:splines=data.get("splines",{})
 _world=session.get_parent().get_node_or_null("WorldMap")
 if is_instance_valid(_world):
  for tree in _world._tutorial_records:_index_tree(tree)
func _index_tree(tree:Dictionary) -> void:
 var p:Array=tree.get("pos",[])
 if p.size()!=3:return
 var cell:=Vector2i(floori(float(p[0])/48),floori(-float(p[1])/48))
 if not tree_grid.has(cell):tree_grid[cell]=[]
 tree_grid[cell].append(Vector2(float(p[0]),-float(p[1])))
func _index_near(point:Vector2) -> void:
 # Reuse existing 250m world chunks; never scan all 55k trees to place a patch.
 if not is_instance_valid(_world):return
 var low_x:=clampi(floori((point.x-48+2000)/250),0,15);var high_x:=clampi(floori((point.x+48+2000)/250),0,15)
 var low_z:=clampi(floori((-point.y-48+2000)/250),0,15);var high_z:=clampi(floori((-point.y+48+2000)/250),0,15)
 for x in range(low_x,high_x+1):
  for z in range(low_z,high_z+1):
   var key:="Chunk_%02d_%02d"%[x,z]
   if _indexed_chunks.has(key):continue
   _indexed_chunks[key]=true
   for tree in _world._chunk_trees_data.get(key,[]):_index_tree(tree)
static func line_distance(point:Vector2,line:Array) -> float:
 var distance:=100000.0
 for i in range(1,line.size()):
  var a:=Vector2(float(line[i-1][0]),-float(line[i-1][1]));var b:=Vector2(float(line[i][0]),-float(line[i][1]))
  distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b)))
 return distance
func _nearest_tree(point:Vector2) -> float:
 _index_near(point)
 var result:=1000.0;var cell:=Vector2i(floori(point.x/48),floori(point.y/48))
 for x in range(cell.x-1,cell.x+2):
  for z in range(cell.y-1,cell.y+2):
   for p in tree_grid.get(Vector2i(x,z),[]):result=minf(result,point.distance_to(p))
 return result
func surface_allowed(record:Dictionary) -> Dictionary:
 var p:Vector2=record.xz
 if absf(p.x)>1980 or absf(p.y)>1980:return {}
 if exclusion_mask!=null:
  var col:=clampi(floori((p.x+2000)/4000*exclusion_mask.get_width()),0,exclusion_mask.get_width()-1)
  var row:=clampi(floori((p.y+2000)/4000*exclusion_mask.get_height()),0,exclusion_mask.get_height()-1)
  var exclusion:=exclusion_mask.get_pixel(col,row)
  if exclusion.r>0.05 or exclusion.g>0.05:return {}
 var water_dist:=minf(line_distance(p,splines.get("river",[])),line_distance(p,splines.get("creek",[])))
 if water_dist<8:return {}
 for id in ["road_main","road_east_branch","road_mine_branch"]:
  if line_distance(p,splines.get(id,[]))<5:return {}
 for line in splines.get("trails",{}).values():
  if line_distance(p,line)<2:return {}
 if is_instance_valid(session.shelter) and p.distance_to(Vector2(session.shelter.global_position.x,session.shelter.global_position.z))<8:return {}
 if p.distance_to(Vector2(1115,-1195))<35:return {} # Mine yard/portal.
 var q:=PhysicsRayQueryParameters3D.create(Vector3(p.x,1024,p.y),Vector3(p.x,-512,p.y),1)
 q.exclude=[session.player.get_rid()]
 var hit=session.player.get_world_3d().direct_space_state.intersect_ray(q)
 if hit.is_empty() or not hit.collider.is_in_group("camp_ground") or hit.normal.y<0.90:return {}
 var d:=Catalog.species(record.species);var nearest:=_nearest_tree(p)
 if nearest<1.3:return {}
 # Computed proxy masks, not a claim of simulated botany or measured moisture.
 match d.habitat:
  "canopy":
   if nearest>16:return {}
  "wet":
   if water_dist>90 and float(hit.position.y)>65:return {}
  "deadwood":
   if nearest>18 and p.distance_to(Vector2(-1500,300))>260:return {}
  "edge":
   if nearest>35:return {}
 var overhead=session.player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(hit.position+Vector3.UP*0.05,hit.position+Vector3.UP*1.5,1))
 if not overhead.is_empty():return {}
 # A small overlap query rejects rock/prop obstacles even where the vertical ray misses.
 var shape:=SphereShape3D.new();shape.radius=0.48
 var check:=PhysicsShapeQueryParameters3D.new();check.shape=shape;check.collision_mask=1|2;check.exclude=[session.player.get_rid()];check.transform.origin=hit.position+Vector3.UP*0.55
 if not session.player.get_world_3d().direct_space_state.intersect_shape(check,1).is_empty():return {}
 return {"id":record.id,"species":record.species,"pos":[hit.position.x,hit.position.y,hit.position.z],"yaw":record.yaw}
func _legacy_blocked(cell:Vector2i) -> bool:
 # Old berry IDs cannot be mapped to plants; conservatively exclude whole consumed 24m cells.
 for x in 2:
  for z in 2:
   if legacy_excluded.has("%d:%d"%[cell.x*2+x,cell.y*2+z]):return true
 return false
func prepare_cell(cell:Vector2i) -> Array:
 var key:=Patch.key(cell)
 if patches.has(key):
  patches[key]=patches[key].filter(func(record):return Patch.retained(record))
  return patches[key]
 _rules();var records:Array=[]
 if not _legacy_blocked(cell):
  for candidate in Patch.candidates(cell,seed_value,placement_version):
   var r:=surface_allowed(candidate)
   if not r.is_empty():records.append(r)
 patches[key]=records
 return records
func stream() -> void:
 var start:=Time.get_ticks_usec();var player_pos:Vector3=session.player.global_position
 var center:=Vector2i(floori(player_pos.x/48),floori(player_pos.z/48));var budget:=2
 var wanted:Array=[]
 for x in range(center.x-2,center.x+3):
  for z in range(center.y-2,center.y+3):wanted.append(Vector2i(x,z))
 wanted.sort_custom(func(a,b):return a.distance_squared_to(center)<b.distance_squared_to(center))
 for cell in wanted:
  var key:=Patch.key(cell)
  if cells.has(key):continue
  if budget<=0:break
  budget-=1;_build_cell(key,prepare_cell(cell))
 for key in cells.keys():
  var bits=str(key).split(":");var cell:=Vector2i(int(bits[0]),int(bits[1]))
  if absi(cell.x-center.x)>2 or absi(cell.y-center.y)>2:
   cells[key].queue_free();cells.erase(key)
 for key in active.keys():
  if not is_instance_valid(active[key]):active.erase(key);continue
  if active[key].global_position.distance_squared_to(player_pos)>14.0*14.0:
   active[key].queue_free();active.erase(key)
 var promotion_budget:=12
 # Promote only nearby plants; no per-plant processing, cap colliders at 96.
 for key in cells:
  for r in patches.get(key,[]):
   var pos:Vector3=session._v3(r.pos)
   if active.has(r.id) or active.size()+stump_nodes.size()>=96 or promotion_budget<=0 or pos.distance_squared_to(player_pos)>12.0*12.0:continue
   if Catalog.species(r.species).family!="berry" and remaining(r)==0:continue
   var n:=Plant.new();n.director=self;n.record=r;add_child(n);n.position=pos;n.rotation.y=float(r.yaw);active[r.id]=n;promotion_budget-=1
  _refresh_far(key)
 _stream_poi_supplies(player_pos)
 _update_stumps(player_pos)
 last_profile={"stream_us":Time.get_ticks_usec()-start,"interactive":active.size()+stump_nodes.size(),"loaded_cells":cells.size(),"visited_cells":patches.size()}
func _build_cell(key:String,records:Array) -> void:
 var root:=Node3D.new();root.name="Patch_"+key.replace(":","_");add_child(root);cells[key]=root
 for r in records:
  if r.species=="wood_fan":
   var wood:=StaticBody3D.new();wood.collision_layer=1;wood.collision_mask=0;root.add_child(wood);wood.position=session._v3(r.get("wood_base",r.pos))+Vector3(0,-0.01,0);wood.rotation.y=float(r.yaw)
   var m:=MeshInstance3D.new();var c:=CylinderMesh.new();c.top_radius=0.20;c.bottom_radius=0.22;c.height=0.95;c.radial_segments=7;m.mesh=c;m.rotation.z=PI/2;m.position.y=0.18
   var mat:=StandardMaterial3D.new();mat.albedo_color=Color("655848");mat.roughness=1;m.material_override=mat;wood.add_child(m)
   var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(0.95,0.40,0.40);col.shape=shape;col.position.y=0.20;wood.add_child(col)
   # Shelf sits on this actual authored deadwood, not an invisible conceptual log.
   if not r.has("wood_base"):
    r.wood_base=r.pos.duplicate();r.pos=session._arr(session._v3(r.pos)+Basis(Vector3.UP,float(r.yaw))*Vector3(0,0.12,0.18))
 _refresh_far(key)
func _refresh_far(key:String) -> void:
 var root:Node3D=cells[key];var groups:Dictionary={}
 for r in patches.get(key,[]):
  if active.has(r.id):continue
  var m:=mask(r)
  if Catalog.species(r.species).family!="berry" and m!=0:continue
  var variant:=0 if Catalog.species(r.species).family=="berry" else posmod(str(r.id).hash(),2)
  var k:=str(r.species)+":"+str(m)+":"+str(variant)
  if not groups.has(k):groups[k]={"mesh":Visuals.mesh(r.species,m,str(r.id)),"transforms":[]}
  groups[k].transforms.append(Transform3D(Basis(Vector3.UP,float(r.yaw)),session._v3(r.pos)))
 var signature:=str(groups.keys())+str(active.keys())+str(harvested.size())
 if root.get_meta("signature","")==signature:return
 root.set_meta("signature",signature)
 for child in root.get_children():
  if child is MultiMeshInstance3D:child.free()
 for group in groups.values():
  var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=group.mesh;mm.instance_count=group.transforms.size()
  for i in mm.instance_count:mm.set_instance_transform(i,group.transforms[i])
  var n:=MultiMeshInstance3D.new();n.multimesh=mm;root.add_child(n)
func mask(r:Dictionary) -> int:
 if r.has("tree"):
  var s:Dictionary=stumps.get(r.tree,{})
  return 0 if not s.is_empty() and ready(s) and not s.taken.has(int(r.group)) else 1
 var result:=0
 for i in int(Catalog.species(r.species).yield):
  if Patch.collected(harvested,r.id,i):result|=1<<i
 return result
func remaining(r:Dictionary) -> int:
 var n:=1 if r.has("tree") else int(Catalog.species(r.species).yield);var result:=0;var bits:=mask(r)
 for i in n:
  if (bits & (1<<i))==0:result+=1
 return result
func inspect(id:String) -> void:
 if inspected.has(id):return
 inspected[id]=true
 if id=="stump_fan":known[id]=true;session.notify("Запись в журнале: 1 пеньковый веер + безопасная вода → древесный чай у огня")
func learn_notes() -> void:
 for id in Catalog.SPECIES:known[id]=true;inspected[id]=true
 session.notify("Памятка изучена: свойства грибов добавлены в полевой журнал")
func journal_text(id:String) -> String:
 var d:=Catalog.species(id)
 return str(d.traits)+"\n"+(str(d.status) if known.has(id) else "Свойства неизвестны. Найдите памятку у стоянки; пробовать необязательно.")
func can_reach(point:Vector3,target:Node=null) -> bool:
 var p=session.player
 if session.health<=0 or p._is_inventory_open or session.get_tree().paused:return false
 if p._camera.global_position.distance_to(point)>3.5:return false
 var q:=PhysicsRayQueryParameters3D.create(p._camera.global_position,point,1|2|4|8);q.exclude=[p.get_rid()]
 var hit=p.get_world_3d().direct_space_state.intersect_ray(q)
 return hit.is_empty() or hit.get("collider")==target or hit.position.distance_to(point)<0.12
func begin_harvest(r:Dictionary,xform:Transform3D) -> bool:
 if not session.job.is_empty() or remaining(r)==0:return false
 var group:=0;var closest:=INF
 var hit_point:Vector3=session.player._raycast.get_collision_point() if session.player._raycast.is_colliding() else xform.origin
 for i in (1 if r.has("tree") else int(Catalog.species(r.species).yield)):
  if mask(r)&(1<<i):continue
  var dist:=hit_point.distance_squared_to(xform*Visuals.group_position(r.species,i))
  if dist<closest:closest=dist;group=i
 var target:Node=stump_nodes.get(r.id) if r.has("tree") else active.get(r.id)
 var point:Vector3=xform*Visuals.group_position(r.species,group)
 if not can_reach(point,target):return false
 session.job={"kind":"harvest","elapsed":0.0,"duration":0.65,"origin":session._arr(session.player.global_position),"plant":r.duplicate(true),"group":group,"point":session._arr(point)}
 session.notify("Сбор: "+str(Catalog.species(r.species).name));return true
func harvest_valid(job:Dictionary) -> bool:
 var r:Dictionary=job.get("plant",{});var target:Node=stump_nodes.get(r.get("id","")) if r.has("tree") else active.get(r.get("id",""))
 return is_instance_valid(target) and can_reach(session._v3(job.get("point",[])),target) and remaining(r)>0
func commit_harvest(job:Dictionary) -> bool:
 if not harvest_valid(job):return false
 var r:Dictionary=job.plant;var group:=int(job.group)
 if mask(r)&(1<<group):return false
 # Preview + mutation happen in one main-thread call; no await/save between them.
 if not Items.transact(session.player,{},[Items.item(r.species)],-1,true):session.notify("Рюкзак заполнен: урожай оставлен на растении");return false
 if not Items.transact(session.player,{},[Items.item(r.species)]):return false
 if r.has("tree"):
  var s:Dictionary=stumps[r.tree];s.taken.append(int(r.group))
  if s.taken.size()>=int(s.crop):
   s.cycle=int(s.cycle)+1;s.start=session.clock;s.humid_start=humid_clock;s.delay=Catalog.REGROWTH;s.taken=[];s.crop=Catalog.harvest_count(r.tree,int(s.cycle))
 else:harvested[r.id+":"+str(group)]=true
 if active.has(r.id):active[r.id].refresh()
 session.notify("Собрано: "+str(Catalog.species(r.species).name));return true
func record_felling(id:String) -> void:
 if stumps.has(id):return
 stumps[id]={"eligible":Catalog.eligible(id),"start":session.clock,"humid_start":humid_clock,"delay":Catalog.FIRST_GROWTH,"taken":[],"cycle":0,"crop":Catalog.harvest_count(id)}
func ready(s:Dictionary) -> bool:
 if not bool(s.get("eligible",false)):return false
 var first:=int(s.get("cycle",0))==0
 var delay:=Catalog.FIRST_GROWTH if first else float(s.delay)
 return session.clock-float(s.start)>=delay and (first or humid_clock-float(s.humid_start)>=delay*Catalog.HUMIDITY_FRACTION)
func attach_stump(node:StaticBody3D,id:String) -> void:
 if not is_instance_valid(node):return
 if id=="":id="pos_%d_%d_%d"%[roundi(node.global_position.x),roundi(node.global_position.y),roundi(node.global_position.z)]
 record_felling(id);supports[id]=weakref(node)
func _surface_point(stump:Node3D,angle:float,height:float) -> Vector3:
 # Intersect real fractured mesh in its local space, not guessed cylinder radius.
 var visual:MeshInstance3D
 for child in stump.get_children():
  if child is MeshInstance3D:visual=child;break
 if visual==null:return Vector3.INF
 var direction:=Vector3(cos(angle),0,sin(angle));var a:=direction*3+Vector3.UP*height;var b:=Vector3.UP*height;var best:=Vector3.INF;var dist:=INF
 var faces:=visual.mesh.get_faces()
 for i in range(0,faces.size(),3):
  var hit=Geometry3D.segment_intersects_triangle(a,b,faces[i],faces[i+1],faces[i+2])
  if hit!=null and a.distance_squared_to(hit)<dist:best=hit;dist=a.distance_squared_to(hit)
 return best
func _update_stumps(player_pos:Vector3) -> void:
 var promotion_budget:=6
 for id in supports.keys():
  var stump=supports[id].get_ref()
  if not is_instance_valid(stump):supports.erase(id);continue
  var s:Dictionary=stumps.get(id,{})
  var near:bool=stump.global_position.distance_squared_to(player_pos)<14*14
  for i in 3:
   var key:="stump:"+str(id)+":"+str(i)
   if not near or s.is_empty() or not ready(s) or i>=int(s.crop) or s.taken.has(i):
    if stump_nodes.has(key):
     if is_instance_valid(stump_nodes[key]):stump_nodes[key].queue_free()
     stump_nodes.erase(key)
    continue
   if stump_nodes.has(key):continue
   if active.size()+stump_nodes.size()>=96 or promotion_budget<=0:continue
   var angle:=posmod(("stump-angle:"+str(id)).hash(),6283)/1000.0+float(i)*TAU/3.0
   var height:=clampf(float(stump.get_meta("cut_y",0.6))*0.45,0.08,0.65)
   var anchors:Dictionary=stump.get_meta("vegetation_anchors",{})
   if not anchors.has(i):anchors[i]=_surface_point(stump,angle,height);stump.set_meta("vegetation_anchors",anchors)
   var point:Vector3=anchors[i]
   if not point.is_finite():continue # No surface support => no floating mushroom.
   var r:={"id":key,"species":"stump_fan","tree":str(id),"group":i}
   var n:=Plant.new();n.director=self;n.record=r;stump.add_child(n);n.position=point;n.rotation.y=PI/2-angle;stump_nodes[key]=n;promotion_budget-=1
func export_state() -> Dictionary:
 return {"version":placement_version,"seed":seed_value,"harvested":harvested.duplicate(),"patches":patches.duplicate(true),"stumps":stumps.duplicate(true),"humid_clock":humid_clock,"inspected":inspected.duplicate(),"known":known.duplicate(),"legacy_excluded":legacy_excluded.duplicate()}
func import_state(state:Dictionary,legacy_picked:Dictionary={}) -> void:
 for node in active.values():
  if is_instance_valid(node):node.free()
 for node in cells.values():
  if is_instance_valid(node):node.free()
 for node in stump_nodes.values():
  if is_instance_valid(node):node.free()
 active.clear();cells.clear();stump_nodes.clear()
 seed_value=int(state.get("seed",Catalog.SEED));placement_version=int(state.get("version",Catalog.VERSION))
 humid_clock=maxf(0,float(state.get("humid_clock",0)));harvested=state.get("harvested",{}).duplicate();patches=state.get("patches",{}).duplicate(true);stumps=state.get("stumps",{}).duplicate(true)
 for id in stumps:
  stumps[id]["eligible"]=true
  if int(stumps[id].get("cycle",0))==0:stumps[id]["delay"]=Catalog.FIRST_GROWTH
 inspected=state.get("inspected",{}).duplicate();known=state.get("known",{}).duplicate();legacy_excluded=state.get("legacy_excluded",{}).duplicate()
 for id in Catalog.INITIAL_KNOWLEDGE:known[id]=true
 if state.is_empty():
  for key in legacy_picked:
   var bits=str(key).split(":")
   if bits.size()==3 and str(key).ends_with(":10"):legacy_excluded[bits[0]+":"+bits[1]]=true
 var trees=load("res://scripts/props/TreeChoppable.gd")
 var felled:Dictionary=session._old_felled if session.location=="mine" else trees.compact_felled_registry()
 for id in felled:record_felling(str(id)) # Unknown old age starts now, never retroactively mature.

func _stream_poi_supplies(player_pos:Vector3) -> void:
 var spots:={"bridge":Vector2(912,-26),"hut":Vector2(-190,-790),"mine_route":Vector2(1080,-1150)}
 for key in spots:
  var p:Vector2=spots[key];var id:="poi_antitoxin_v1_"+str(key)
  if session.picked.has(id) or session.resources.has(id) or p.distance_to(Vector2(player_pos.x,player_pos.z))>55:continue
  var hit=session.player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,1024,p.y),Vector3(p.x,-512,p.y),1))
  if not hit.is_empty() and hit.collider.is_in_group("camp_ground"):session._spawn_pickup(Items.item("antitoxin"),id,hit.position+Vector3.UP*0.03)
