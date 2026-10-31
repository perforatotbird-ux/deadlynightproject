extends SceneTree
## Actual shipped MapViewer, not a showcase scene. Seeding uses real item transactions.
const Settings=preload("res://scripts/core/SettingsManager.gd")
const Items=preload("res://scripts/survival/SurvivalItems.gd")
var passes:=0
var failures:=0
var out:=OS.get_environment("DN_QA_OUTPUT")
func _initialize() -> void:call_deferred("run")
func check(ok:bool,text:String) -> void:
 if ok:passes+=1;print("PASS: ",text)
 else:failures+=1;printerr("FAIL: ",text)
func settle(n:int=6) -> void:
 for i in n:await process_frame
func shot(name:String) -> void:
 if out.is_empty() or DisplayServer.get_name()=="headless":return
 DirAccess.make_dir_recursive_absolute(out);RenderingServer.set_render_loop_enabled(true)
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image();check(image.get_size()==root.size,"actual world capture "+name);image.save_png(out.path_join(name+".png"));RenderingServer.set_render_loop_enabled(false)
func run() -> void:
 if not OS.get_user_data_dir().contains("deadly-night-test"):quit(2);return
 Settings.get_instance().set_setting("graphics","shadow_quality",0)
 root.size=Vector2i(1280,720)
 if DisplayServer.get_name()!="headless":RenderingServer.set_render_loop_enabled(false)
 var game=load("res://scenes/viewer/MapViewer.tscn").instantiate();root.add_child(game);current_scene=game
 var p=game.get_node("Player");p.set_physics_process(false)
 var world=game.get_node("WorldMap");var origin:Vector3=p.global_position
 # Same test-only rendering budget as pause QA: retain actual nearby world.
 for chunk in world._vegetation_root.get_children():
  var at:=Vector3.ZERO
  if chunk.get_child_count()>0:
   var mmi=chunk.get_child(0)
   if mmi.multimesh.instance_count>0:at=mmi.multimesh.get_instance_transform(0).origin
  if Vector2(at.x-origin.x,at.z-origin.z).length()>300:chunk.hide()
 for mesh in world._collect_all_meshes(world._terrain_root):
  var aabb: AABB=mesh.global_transform*mesh.get_aabb()
  if not aabb.grow(220).has_point(origin):mesh.hide()
 p._camera.far=220;game.get_node("DirectionalLight3D").shadow_enabled=false;game.get_node("WorldMap/POIs_and_Props").hide();p.rotation.y=deg_to_rad(-35)
 await physics_frame;await settle(8)
 var s=p.survival;s.clock=17*3600+23*60;s.weather="clear";s._update_lighting();s.set_process(false)
 for id in ["stone","brush","camp_kit","water","ration","bandage","flint","pyrite"]:
  var item:=Items.item(id);item.count=3 if id in ["stone","brush"] else 1;check(Items.transact(p,{},[item]),"real world item "+id)
 p._add_to_backpack({"species":"birch","weight":4.0})
 s.open_backpack();var ui=p._backpack_ui;ui.tabs.current_tab=0;p._on_slot_clicked(2);p.assign_belt_item(2,0)
 check(not p._hud_layer.visible,"real world HUD suppressed")
 for size in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
  root.size=size;await settle(12);ui.resize();await settle(8)
  check(root.get_visible_rect().encloses(p._inv_root_panel.get_global_rect()),"actual world inventory fits "+str(size))
  await shot("world_inventory_%d" % size.x)
 var clock:float=s.clock;s.advance(60);check(s.clock>clock,"inventory does not pause survival simulation")
 s.close_backpack();check(p._hud_layer.visible,"actual world HUD restored")
 p._hud_layer.hide();s.open_backpack();s.close_backpack();check(not p._hud_layer.visible,"previously hidden HUD is not forced on")
 await create_timer(0.2).timeout;game.queue_free();current_scene=null;await settle()
 print("INVENTORY WORLD SUMMARY: %d PASS, %d FAIL" % [passes,failures]);quit(1 if failures else 0)
