extends SceneTree
## Verifies the shipped model paths, imported meshes and gameplay hookups.
const Models=preload("res://scripts/core/ExternalModels.gd")
const Trees=preload("res://scripts/props/TreeChoppable.gd")
const Player=preload("res://scripts/player/PlayerController.gd")
class EmptyWorld extends "res://scripts/world/WorldMap.gd":
 func _ready() -> void:pass
var failures:=0
var passes:=0
func check(ok:bool,text:String) -> void:
 if ok:passes+=1;print("PASS: ",text)
 else:failures+=1;printerr("FAIL: ",text)
func _initialize() -> void:call_deferred("run")
func mesh_of(node:Node) -> MeshInstance3D:
 if node is MeshInstance3D:return node
 for child in node.get_children():
  var mesh:=mesh_of(child)
  if mesh!=null:return mesh
 return null
func run() -> void:
 var stage:=Node3D.new();root.add_child(stage);current_scene=stage
 var world:=EmptyWorld.new();stage.add_child(world);world._load_tree_models()
 for sp in ["birch","spruce","beech","oak"]:
  var path:=Models.tree_path(sp)
  check(path.begins_with(Models.ROOT),sp+": external model is active, not fallback")
  var scene=load(path).instantiate();stage.add_child(scene)
  var meshes=scene.find_children("*","MeshInstance3D",true,false)
  check(meshes.size()==1,sp+": single baked mesh compatible with MultiMesh")
  var mesh:=mesh_of(scene);var bounds: AABB=mesh.mesh.get_aabb()
  check(absf(bounds.position.y)<0.01 and absf(bounds.end.y-float(Trees.SPECIES_CONFIG[sp].height))<0.05,sp+": ground pivot and configured tree height")
  check(mesh.transform.is_equal_approx(Transform3D.IDENTITY),sp+": no lost node transforms in distant forest")
  check(world._tree_meshes[sp]==mesh.mesh,sp+": forest uses downloaded mesh resource")
  var bark:=false;var canopy:=false
  for i in mesh.mesh.get_surface_count():
   var m=mesh.mesh.surface_get_material(i)
   bark=bark or "bark" in m.resource_name.to_lower();canopy=canopy or "foliage" in m.resource_name.to_lower()
  check(bark and canopy,sp+": bark collision/fracture tagging and canopy materials")
  var tree:=Trees.new();tree.species=sp;tree.tree_id="external_"+sp;stage.add_child(tree);tree.set_process(false)
  await physics_frame;await process_frame
  check(tree._visual_node.scene_file_path==path,sp+": interactive tree matches distant model")
  check(tree.get_node("CollisionShape3D").shape is ConcavePolygonShape3D,sp+": real bark collision retained")
  var ray:=PhysicsRayQueryParameters3D.create(tree.to_global(Vector3(0,1.3,3)),tree.to_global(Vector3(0,1.3,-3)),2)
  var hit:=root.world_3d.direct_space_state.intersect_ray(ray)
  check(not hit.is_empty() and hit.get("collider")==tree,sp+": actual physics ray reaches imported bark")
  scene.free();tree.free()
 var player:=Player.new();stage.add_child(player);player.set_physics_process(false)
 check(player._axe_model.scene_file_path==Models.AXE,"player equips downloaded axe")
 var axe:=mesh_of(player._axe_model);var axe_bounds: AABB=axe.mesh.get_aabb()
 check(absf(axe_bounds.size.y-0.678)<0.005,"axe length matches original animation and hand sockets")
 check(player._axe_model.position.is_equal_approx(Vector3(0,-0.15,0)),"original handle heel offset retained")
 check(player._axe_arm_rig._arms.size()==2,"both existing hands retained")
 player.select_hotbar_slot(1);check(not player._axe_anim_pivot.visible and not player._axe_arm_rig.visible,"tool switching hides axe and hands")
 player.select_hotbar_slot(0);check(player._axe_anim_pivot.visible and player._axe_arm_rig.visible,"tool switching restores axe")
 check(Models.tree_path("missing_species").contains("assets/models/trees/"),"missing external tree resolves to legacy resource path")
 stage.free();current_scene=null;await process_frame;await create_timer(0.25).timeout
 print("EXTERNAL MODELS SUMMARY: %d PASS, %d FAIL" % [passes,failures]);quit(1 if failures else 0)
