extends SceneTree
const Models=preload("res://scripts/survival/ResourceModels.gd")
func _initialize() -> void:call_deferred("_run")
func settle(n:int) -> void:
 for i in n:await physics_frame;await process_frame
func _run() -> void:
 var world=load("res://scenes/viewer/MapViewer.tscn").instantiate();root.add_child(world);current_scene=world
 var p=world.get_node("Player");p.set_physics_process(false)
 # Software-render QA fixture: real world geometry, but hide distant chunks before first draw.
 # This is not a benchmark and does not change production visibility settings.
 for mesh in world.find_children("*","MultiMeshInstance3D",true,false):mesh.hide()
 for mesh in world.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh!=null:
   var center:Vector3=mesh.global_transform*mesh.mesh.get_aabb().get_center()
   if Vector2(center.x-p.global_position.x,center.z-p.global_position.z).length()>150:mesh.hide()
 for light in world.find_children("*","DirectionalLight3D",true,false):light.shadow_enabled=false
 for camera in world.find_children("*","Camera3D",true,false):camera.far=80
 await settle(8)
 var base:Vector3=p.global_position+Vector3(7,0,-4)
 var n:=0
 for kind in ["stone","pyrite","flint","brush","forest_fat","wood_fan","copper_false","pale_bell","stump_fan"]:
  var at:=base+Vector3((n%3-1)*.85,0,-(n/3)*.8);n+=1
  var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*20,at-Vector3.UP*30,1);query.exclude=[p.get_rid()]
  var hit=p.get_world_3d().direct_space_state.intersect_ray(query)
  if hit.is_empty():push_error("No ground under preview");quit(1);return
  var model:=MeshInstance3D.new();model.mesh=Models.mesh(kind);world.add_child(model);model.global_position=hit.position+Vector3.UP*.005
 var camera:=Camera3D.new();world.add_child(camera);camera.global_position=base+Vector3(0,2.5,2.7);camera.look_at(base+Vector3(0,0,-.8));camera.fov=55;camera.far=80;camera.current=true
 for canvas in world.find_children("*","CanvasLayer",true,false):canvas.visible=false
 for canvas in root.find_children("GlobalFPSOverlay","CanvasLayer",true,false):canvas.visible=false
 await settle(18)
 root.get_texture().get_image().save_png("/data/qa/resources-forest.png")
 print("FOREST RESOURCE PREVIEW PASS")
 world.free();current_scene=null;Models.cache.clear();Models.materials.clear();await settle(2);quit()
