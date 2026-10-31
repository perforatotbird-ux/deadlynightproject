extends SceneTree
var passed:=0
var failed:=0
var output:=OS.get_environment("DN_TERRAIN_LIGHT_QA_OUTPUT")
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passed+=1;print("PASS: "+label)
 else:failed+=1;printerr("FAIL: "+label)
func settle():
 for i in 4:await process_frame
func capture(id:String):
 if output.is_empty() or DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(id+".png"))
func sample(camera:Camera3D,point:Vector3)->float:
 var image:=root.get_texture().get_image();var pixel:=camera.unproject_position(point);var value:=0.0
 for y in range(-2,3):
  for x in range(-2,3):value+=image.get_pixel(int(pixel.x)+x,int(pixel.y)+y).get_luminance()
 return value/25.0
func run():
 var graphical:=DisplayServer.get_name()!="headless"
 if graphical and not output.is_empty():DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1280,720)
 var scene:=Node3D.new();root.add_child(scene);current_scene=scene
 var terrain=load("res://assets/models/terrain/terrain_256_chunks.glb").instantiate();scene.add_child(terrain)
 var chunk:MeshInstance3D
 for node in terrain.find_children("*","MeshInstance3D",true,false):
  node.hide()
  if node.name=="Chunk_04_03":chunk=node;node.show()
 var original:StandardMaterial3D=chunk.get_active_material(0)
 var format:int=chunk.mesh.surface_get_format(0)
 check(not (format & Mesh.ARRAY_FORMAT_TEX_UV) or not (format & Mesh.ARRAY_FORMAT_TANGENT),"regression fixture is the actual terrain missing normal-map basis attributes")
 var env:=WorldEnvironment.new();var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("0a1014");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color(.2,.25,.3);environment.ambient_light_energy=.08;env.environment=environment;scene.add_child(env)
 var p=load("res://scenes/player/Player.tscn").instantiate();scene.add_child(p);p.position=Vector3(-900,25.2,1100);p.set_active(true);p.set_physics_process(false);p._hud_layer.hide();p._camera_pivot.rotation.x=-.42;p.select_hotbar_slot(1);p._toggle_lantern()
 await settle();await capture("terrain_before_material_fix")
 var before:=0.0
 if graphical:before=sample(p._camera,Vector3(-900,24.995,1094))
 preload("res://scripts/world/WorldMap.gd").prepare_terrain_lighting(terrain)
 var safe:StandardMaterial3D=chunk.get_active_material(0)
 check(not safe.normal_enabled,"invalid tangent-space map is bypassed on real terrain")
 check(original.normal_enabled and safe!=original,"imported source material is never mutated")
 check(safe.albedo_texture==original.albedo_texture and safe.roughness==original.roughness,"terrain colour texture and roughness are preserved")
 var valid:=true;var materials:={}
 for node in terrain.find_children("*","MeshInstance3D",true,false):
  var mat:StandardMaterial3D=node.get_active_material(0)
  valid=valid and not mat.normal_enabled;materials[mat.get_instance_id()]=true
 check(valid,"all 256 imported terrain chunks receive the fallback")
 check(materials.size()==1,"chunks share one safe material rather than duplicating textures")
 var first:=safe.get_instance_id();preload("res://scripts/world/WorldMap.gd").prepare_terrain_lighting(terrain)
 check(chunk.get_active_material(0).get_instance_id()==first,"material repair is idempotent")
 # Correctly authored replacement meshes must retain their normal-map detail.
 var good:=MeshInstance3D.new();good.mesh=PlaneMesh.new();var good_mat:=StandardMaterial3D.new();good_mat.normal_enabled=true;good.material_override=good_mat;terrain.add_child(good)
 preload("res://scripts/world/WorldMap.gd").prepare_terrain_lighting(terrain)
 check(good.get_active_material(0)==good_mat and good_mat.normal_enabled,"valid UV/tangent surfaces retain normal mapping")
 good.queue_free();await settle()
 p._toggle_lantern();await settle();var dark:Array[float]=[]
 var probes:Array[Vector3]=[Vector3(-900,24.995,1097),Vector3(-900,24.995,1094),Vector3(-900,24.995,1091),Vector3(-904,24.995,1096),Vector3(-896,24.995,1096)]
 if graphical:
  for point in probes:dark.append(sample(p._camera,point))
 p._toggle_lantern();await settle();await capture("terrain_after_material_fix")
 if graphical:
  check(sample(p._camera,probes[1])>before+.025,"normal-map repair removes the actual black half-plane ahead")
  for i in probes.size():check(sample(p._camera,probes[i])>dark[i]+.018,"real terrain lights smoothly ahead and beside player: "+str(probes[i]))
 scene.free();current_scene=null;await settle()
 print("TERRAIN LANTERN SUMMARY: %d PASS, %d FAIL"%[passed,failed]);quit(1 if failed else 0)
