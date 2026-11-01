extends SceneTree
## Acceptance of all five supplied variants, authored LODs, batching, cutting and saves.
const Models=preload("res://scripts/core/ExternalModels.gd")
const Trees=preload("res://scripts/props/TreeChoppable.gd")
class EmptyWorld extends "res://scripts/world/WorldMap.gd":
 func _ready() -> void:pass
var passes:=0
var failures:=0
var stage:Node3D
var results:Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 if ok:passes+=1;print("PASS: ",label)
 else:failures+=1;printerr("FAIL: ",label)
func id_for(variant:int) -> String:
 for i in 10000:
  var id:="lolipop_%d"%i
  if Models.birch_variant(id)==variant:return id
 return ""
func idle(tree:Node) -> void:
 var limit:=Time.get_ticks_msec()+30000
 while is_instance_valid(tree) and tree._voxel_trunk.is_busy() and Time.get_ticks_msec()<limit:await create_timer(0.003).timeout
 check(not is_instance_valid(tree) or not tree._voxel_trunk.is_busy(),"cut worker completes within 30 seconds")
func make_tree(id:String) -> Node:
 var tree:=Trees.new();tree.species="birch";tree.tree_id=id;stage.add_child(tree);tree.set_process(false);return tree
func bark_hit(tree:Node) -> Dictionary:
 var ray:=PhysicsRayQueryParameters3D.create(tree.to_global(Vector3(0,1.3,5)),tree.to_global(Vector3(0,1.3,-5)),2)
 return root.world_3d.direct_space_state.intersect_ray(ray)
func run() -> void:
 stage=Node3D.new();root.add_child(stage);current_scene=stage
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Models.BIRCH_ROOT+"manifest.json"))
 var world:=EmptyWorld.new();stage.add_child(world);world._load_tree_models()
 var unique_shapes:Dictionary={}
 for variant in 5:
  var id:=id_for(variant);var label:="variant %d: "%variant
  var path:=Models.tree_path("birch",id)
  check(path==Models.BIRCH_ROOT+"birch_%d.tscn"%variant,label+"stable variant path")
  var instance:Node=load(path).instantiate();stage.add_child(instance)
  var visual:MeshInstance3D=instance.find_children("*","MeshInstance3D",true,false)[0]
  var mesh:Mesh=visual.mesh;var bounds:=mesh.get_aabb()
  check(instance.find_children("*","MeshInstance3D",true,false).size()==1,label+"single baked mesh")
  check(visual.transform.is_equal_approx(Transform3D.IDENTITY),label+"identity transform for MultiMesh")
  check(absf(bounds.position.y)<0.001 and absf(bounds.end.y-18)<0.001,label+"ground pivot and 18m height")
  check(world._tree_meshes[Models.tree_key("birch",id)]==mesh,label+"same mesh for distant and interactive tree")
  var triangles:=0;var bark_base:=false;var leaf:=false;var good_lods:=0
  var gpu_lod_triangles:=[0,0]
  for surface in mesh.get_surface_count():
   var arrays:=mesh.surface_get_arrays(surface);triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
   var material:StandardMaterial3D=mesh.surface_get_material(surface)
   check(material.albedo_texture!=null and material.normal_texture!=null and material.normal_enabled,label+"albedo/normal texture and tangent basis")
   check(material.albedo_texture.get_width()<=2048,label+"shared texture at most 2K")
   if "bark_base" in material.resource_name:bark_base=true
   if "foliage" in material.resource_name:
    leaf=material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and material.cull_mode==BaseMaterial3D.CULL_DISABLED
   var gpu_surface:Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),surface)
   var gpu_lods:Array=gpu_surface.get("lods",[])
   if gpu_lods.size()==2:good_lods+=1
   var index_stride: int=gpu_surface["index_data"].size()/arrays[Mesh.ARRAY_INDEX].size()
   for level in 2:
    gpu_lod_triangles[level]+=gpu_lods[level]["index_data"].size()/index_stride/3 if gpu_lods.size()==2 else arrays[Mesh.ARRAY_INDEX].size()/3
  check(triangles==manifest.variants[variant].levels[0].triangles,label+"authored LOD0 triangle count unchanged")
  check(good_lods>=2,label+"native authored LOD1 and LOD2 on bark and canopy")
  check(gpu_lod_triangles[0]==manifest.variants[variant].levels[1].triangles and gpu_lod_triangles[1]==manifest.variants[variant].levels[2].triangles,label+"native GPU LOD index counts exactly match authored levels")
  check(bark_base and leaf,label+"base stem tagged as bark; two-sided cutout canopy")
  instance.free()
  Trees.felled_tree_ids.clear();Trees.damaged_tree_states.clear()
  var tree=make_tree(id)
  await physics_frame;await process_frame;await physics_frame
  var collision=tree.get_node("CollisionShape3D").shape
  unique_shapes[collision.get_instance_id()]=true
  check(collision is ConcavePolygonShape3D,label+"authored bark collision")
  var hit:=bark_hit(tree)
  check(not hit.is_empty() and hit.get("collider")==tree,label+"real axe ray intersects base bark")
  if hit.is_empty():tree.free();continue
  var local_hit:Vector3=tree.to_local(hit.position)
  check(Vector2(local_hit.x,local_hit.z).length()<=tree._geometry_config().radius*1.5,label+"hit inside variant-specific damage radius")
  tree.hit(1,tree.to_global(local_hit),tree.to_global(Vector3(0,1.3,5)))
  await idle(tree)
  check(not tree._is_falling and not tree._voxel_trunk.export_cuts().is_empty(),label+"first hit creates cut without premature fracture")
  var tangent_ok:=true
  var cut_mesh:Mesh=tree._voxel_trunk._mesh_instance.mesh
  for surface in cut_mesh.get_surface_count():
   var arrays:Array=cut_mesh.surface_get_arrays(surface)
   tangent_ok=tangent_ok and arrays[Mesh.ARRAY_TANGENT]!=null and arrays[Mesh.ARRAY_TANGENT].size()==arrays[Mesh.ARRAY_VERTEX].size()*4
  check(tangent_ok,label+"deformed bark and cut surfaces have complete tangent basis")
  var saved:Dictionary=JSON.parse_string(JSON.stringify(Trees.damaged_tree_states))
  tree.free();await process_frame;Trees.damaged_tree_states=saved
  tree=make_tree(id);await idle(tree)
  check(Models.tree_path("birch",id)==tree._visual_node.scene_file_path,label+"save restoration keeps exact variant")
  check(not tree._voxel_trunk.export_cuts().is_empty(),label+"partial damage restored from JSON")
  var hits:=1
  while not tree._is_falling and hits<40:
   tree.hit(1,tree.to_global(local_hit),tree.to_global(Vector3(0,1.3,5)));await idle(tree);hits+=1
  check(tree._is_falling,label+"repeated real hits cause fracture")
  check(tree._voxel_trunk.last_cap_contours==(2 if variant in [2,3] else 1),label+"every independent stem has a triangulated cap")
  check(tree._fall_pivot!=null and absf(tree._fall_pivot.position.y-tree._break_height)<0.001,label+"upper tree pivots at actual cut")
  var stumps:=get_nodes_in_group("permanent_stumps")
  check(stumps.size()==1,label+"one permanent stump")
  if not stumps.is_empty():
   var stump_mesh:Mesh=stumps[0].get_child(0).mesh
   check(absf(stump_mesh.get_aabb().end.y-tree._break_height)<0.015,label+"stump top matches break height")
   var cap:Array=stump_mesh.surface_get_arrays(stump_mesh.get_surface_count()-1)
   var cap_vertices:PackedVector3Array=cap[Mesh.ARRAY_VERTEX]
   var winding_ok:=not cap_vertices.is_empty()
   for i in range(0,cap_vertices.size(),3):
    winding_ok=winding_ok and (cap_vertices[i+1]-cap_vertices[i]).cross(cap_vertices[i+2]-cap_vertices[i]).y<=0.000001
   check(winding_ok,label+"stump cap front winding faces upward in Godot")
  var felled:Dictionary=JSON.parse_string(JSON.stringify(Trees.compact_felled_registry()))
  check(felled.size()==1 and not Trees.damaged_tree_states.has(id),label+"canonical felling record replaces standing damage")
  tree._process(2.0)
  # LogPickup uses wood_logs group; validate the actual script too.
  var logs:=0
  for child in stage.get_children():
   if child.get_script()==load("res://scripts/props/LogPickup.gd"):logs+=1
  check(logs==3,label+"fall produces three birch logs")
  results.append({"variant":variant,"id":id,"hits":hits,"triangles":triangles,"radius":tree._geometry_config().radius,"cap_contours":tree._voxel_trunk.last_cap_contours,"last_worker_usec":tree._voxel_trunk.last_worker_usec})
  tree.free()
  for stump in stumps:stump.free()
  for child in stage.get_children():
   if child.get_script()==load("res://scripts/props/LogPickup.gd"):child.free()
  Trees.felled_tree_ids=felled;tree=make_tree(id);await idle(tree);await process_frame
  check(get_nodes_in_group("permanent_stumps").size()==1,label+"felled-save reload rebuilds stump, not standing tree")
  if is_instance_valid(tree):tree.free()
  for stump in get_nodes_in_group("permanent_stumps"):stump.free()
 check(unique_shapes.size()==5,"all five variants use separate collision cache entries")
 Trees.felled_tree_ids.clear();Trees.damaged_tree_states.clear()
 world._load_vegetation()
 var found:Dictionary={};var mapped:=true
 for record in world._all_trees_data:
  if record.get("species","")!="birch" or record.get("tutorial",false):continue
  var key:=Models.tree_key("birch",record.id);found[key]=true
  if world._tree_mmi_index.has(record.id):mapped=mapped and world._tree_mmi_index[record.id].mm.mesh==world._tree_meshes[key]
  else:mapped=false
 check(found.size()==5 and mapped,"real forest records batched into all five matching MultiMeshes")
 # Hide/restore logic must still address the right variant's batch.
 var candidate:Dictionary={}
 for record in world._all_trees_data:
  if record.get("species","")=="birch" and not record.get("tutorial",false):candidate=record;break
 var index:Dictionary=world._tree_mmi_index[candidate.id]
 world._set_mmi_tree_scale(candidate.id,0.0)
 check(world._hidden_tree_ids.has(candidate.id),"dynamic activation marks correct distant variant hidden")
 if DisplayServer.get_name()!="headless":check(index.mm.get_instance_transform(index.index).basis.determinant()==0.0,"GPU MultiMesh hides correct distant variant")
 world._restore_mmi_tree_scale(candidate.id)
 check(not world._hidden_tree_ids.has(candidate.id),"deactivation restores distant-variant visibility registry")
 if DisplayServer.get_name()!="headless":
  check(index.far_mm.get_instance_transform(index.far_index).is_equal_approx(index.far_xform),"GPU MultiMesh restores original far variant transform")
  check(is_zero_approx(index.mm.get_instance_transform(index.index).basis.determinant()),"inactive detail does not double-render far variant")
 var output:=OS.get_environment("DN_QA_OUTPUT")
 if not output.is_empty():
  DirAccess.make_dir_recursive_absolute(output)
  var f:=FileAccess.open(output.path_join("acceptance.json"),FileAccess.WRITE)
  f.store_string(JSON.stringify({"passes":passes,"failures":failures,"variants":results},"  "));f.close()
 world.free();stage.free();current_scene=null;await process_frame;await create_timer(0.2).timeout
 print("LOLIPOP BIRCH SUMMARY: %d PASS, %d FAIL"%[passes,failures]);quit(1 if failures else 0)
