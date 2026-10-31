extends SceneTree
## Native screenshots from the shipped MapViewer. Only QA render budget is reduced.
const Settings=preload("res://scripts/core/SettingsManager.gd")
const Models=preload("res://scripts/core/ExternalModels.gd")
var output:=OS.get_environment("DN_QA_OUTPUT")
func _initialize() -> void:call_deferred("run")
func settle(n:int=6) -> void:
 for i in n:await process_frame
func capture(name:String) -> void:
 RenderingServer.set_render_loop_enabled(true)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
 RenderingServer.set_render_loop_enabled(false)
func run() -> void:
 if DisplayServer.get_name()=="headless" or output.is_empty() or not OS.get_user_data_dir().contains("deadly-night-test"):quit(2);return
 DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1600,900)
 Settings.get_instance().set_setting("graphics","shadow_quality",0)
 RenderingServer.set_render_loop_enabled(false)
 var game=load("res://scenes/viewer/MapViewer.tscn").instantiate();root.add_child(game);current_scene=game
 var p=game.get_node("Player");p.set_physics_process(false);p.set_process_input(false)
 p.global_position=Vector3(-900,25.5,1098.5);p.rotation=Vector3.ZERO;p._camera_pitch=0;p._camera_pivot.rotation=Vector3.ZERO;p._camera.current=true;p._camera.far=180;p.select_hotbar_slot(0)
 var world=game.get_node("WorldMap");var origin:Vector3=p.global_position
 # Hide distant geometry in QA only; source scene and shipping renderer stay unchanged.
 for chunk in world._vegetation_root.get_children():
  var at:=Vector3.ZERO
  if chunk.get_child_count()>0:
   var mmi=chunk.get_child(0)
   if mmi.multimesh.instance_count>0:at=mmi.multimesh.get_instance_transform(0).origin
  if Vector2(at.x-origin.x,at.z-origin.z).length()>240:chunk.hide()
 for mesh in world._collect_all_meshes(world._terrain_root):
  if not (mesh.global_transform*mesh.get_aabb()).grow(200).has_point(origin):mesh.hide()
 game.get_node("DirectionalLight3D").shadow_enabled=false;game.get_node("WorldMap/POIs_and_Props").hide()
 var survival=p.survival;survival.clock=13*3600;survival.weather="clear";survival._update_lighting();survival.set_process(false)
 await physics_frame;await settle(10)
 p._cancel_chop();await capture("game_axe_and_birch")
 var target=world._interactive_trees.get("tree_055432")
 if target!=null:
  target.set_process(false)
  var toward:Vector3=target.to_local(p._camera.global_position);toward.y=0;toward=toward.normalized()*float(target.SPECIES_CONFIG[target.species].radius)
  toward.y=target.to_local(p._camera.global_position).y
  target.hit(2,target.to_global(toward),p.global_position)
  var deadline:=Time.get_ticks_msec()+20000
  while target._voxel_trunk.is_busy() and Time.get_ticks_msec()<deadline:await create_timer(0.01).timeout
  print("WORLD_MODEL: ",target._visual_node.scene_file_path," cuts=",target._voxel_trunk.export_cuts().size())
  await capture("game_imported_bark_cut")
 var overview:=Camera3D.new();game.add_child(overview);overview.global_position=origin+Vector3(14,12,18);overview.look_at(origin+Vector3(0,6,-9));overview.far=200;overview.current=true;p._hud_layer.hide()
 await settle();await capture("game_forest_overview")
 print("EXTERNAL WORLD PREVIEW: 3 native captures; axe=",p._axe_model.scene_file_path)
 await create_timer(0.25).timeout;game.queue_free();current_scene=null;await settle(8);quit(0)
