extends SceneTree
var passes:=0
var failures:=0
var output:=OS.get_environment("DN_LANTERN_QA_OUTPUT")
var graphical:=false
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passes+=1;print("PASS: "+label)
 else:failures+=1;printerr("FAIL: "+label)
func settle(n:int=6):
 for i in n:await process_frame
func capture(id:String):
 if not graphical:return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(id+".png"))
func run():
 graphical=DisplayServer.get_name()!="headless" and not output.is_empty()
 if graphical:DirAccess.make_dir_recursive_absolute(output)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720)
 var scene:=Node3D.new();scene.name="MapViewer";root.add_child(scene);current_scene=scene
 var ground:=StaticBody3D.new();ground.add_to_group("camp_ground");scene.add_child(ground)
 var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(150,1,150);collision.shape=box;collision.position.y=-0.5;ground.add_child(collision)
 var env:=WorldEnvironment.new();env.name="WorldEnvironment";env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("15201d");scene.add_child(env)
 var p=load("res://scenes/player/Player.tscn").instantiate();scene.add_child(p);p.position=Vector3(0,0.2,0);p.set_active(true);p.set_physics_process(false)
 var s=load("res://scripts/survival/SurvivalWorld.gd").new();scene.add_child(s);s.set_process(false);s.set_physics_process(false);s.vegetation.set_physics_process(false);s.shelter.position=Vector3(40,0,40)
 await physics_frame;await settle()
 var ui=p._backpack_ui
 var alerts=preload("res://scripts/survival/SurvivalAlerts.gd")
 s.warmth=80;s.wetness=0;s.health=100;s.body.water=85;s.body.food=85;s.energy=100;s.body.stamina=100;s.body.conditions.clear();s.ui.refresh();await settle()
 check(s.ui.active_alerts.is_empty(),"healthy character has no fake warnings")
 check(s.ui.health_bar.value==100 and s.ui.vitals.visible,"always-visible authoritative health bar")
 check(s.ui.find_children("*","PanelContainer",true,false).is_empty(),"no old black top strip returns")
 await capture("hud_healthy_1280")
 var light:SpotLight3D=p._lantern_light
 p.select_hotbar_slot(1);await settle()
 check(p._lantern_model.visible and not light.visible,"slot 2 equips a real unlit lantern")
 check(p._lantern_model.find_children("*","MeshInstance3D",true,false).size()>50,"model has reservoir, globe, guards, vents and carry handle")
 var no_shadow:=true
 for mesh in p._lantern_model.find_children("*","MeshInstance3D",true,false):
  if mesh.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:no_shadow=false
 check(no_shadow,"lantern cannot shadow its own world beam")
 check(light.position.z<-.8 and light.position.z<p._lantern_model.position.z,"world beam originates in front of body and globe")
 check((light.light_cull_mask & p._lantern_model.VIEWMODEL_LAYER)==0,"world beam excludes decorative viewmodel geometry")
 for pose in [Vector2(0,0),Vector2(1.2,.6),Vector2(-2.0,-.7)]:
  p.rotation.y=pose.x;p._camera_pivot.rotation.x=pose.y
  check((-light.global_basis.z).dot(-p._camera.global_basis.z)>.999,"beam follows camera forward after yaw and pitch "+str(pose))
 p.rotation=Vector3.ZERO;p._camera_pivot.rotation=Vector3.ZERO
 # Night test room: only the carried beam can illuminate the front wall.
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.12,.15,.18);env.environment.ambient_light_energy=.12
 var wall:=MeshInstance3D.new();var wall_mesh:=BoxMesh.new();wall_mesh.size=Vector3(9,5,.2);wall.mesh=wall_mesh;wall.position=Vector3(0,1.5,-5)
 var stone:=StandardMaterial3D.new();stone.albedo_color=Color("73776a");stone.roughness=.9;wall.material_override=stone;scene.add_child(wall)
 var floor_mesh:=MeshInstance3D.new();var floor_box:=BoxMesh.new();floor_box.size=Vector3(20,.1,20);floor_mesh.mesh=floor_box;floor_mesh.material_override=stone;scene.add_child(floor_mesh)
 await settle();await capture("lantern_off_1280")
 var dark_sample:=0.0
 if graphical:dark_sample=sample_center()
 p._toggle_lantern();await settle(15)
 check(light.visible and p._lantern_model.flame.visible and p._lantern_model.glow.visible,"toggle powers beam, flame and model glow together")
 await capture("lantern_on_1280")
 if graphical:check(sample_center()>dark_sample+.025,"actual forward wall becomes brighter when lantern is switched on")
 p.select_hotbar_slot(0);await settle()
 check(not light.visible and not p._lantern_model.visible,"stowing lantern hides model and turns off world beam")
 p.select_hotbar_slot(1);await settle();check(light.visible and p._lantern_model.visible,"re-equipping restores remembered switch state")
 p._toggle_lantern();await settle();check(not light.visible and not p._lantern_model.flame.visible,"switch off extinguishes flame as well as light")
 s.health=9;s.warmth=5;s.wetness=95;s.body.water=0;s.body.food=0;s.energy=0;s.body.stamina=0;p.backpack_weight=30
 s.body.conditions={"bleeding":{"remaining":-1},"hypothermia":{"remaining":-1},"sprain":{"remaining":120},"poison":{"tier":"severe","remaining":180,"delay":0,"load":1}}
 var state:=str(s.body.export_state());s.ui.refresh();await settle()
 var ids:Array=[]
 for alert in s.ui.active_alerts:ids.append(alert.id)
 for id in ["health","bleeding","cold","water","food","energy","poison","sprain","wetness","stamina","overweight"]:check(id in ids,"HUD covers real danger/status: "+id)
 check(s.ui.health_bar.value==9,"health bar responds to damage")
 check(s.ui.active_alerts.size()==11,"simultaneous dangers coexist without duplicates or dropped alerts")
 check(state==str(s.body.export_state()),"HUD projection cannot damage or mutate the body")
 for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(800,600)]:
  root.size=dimensions;await settle(12);s.ui._resize();await settle()
  check(root.get_visible_rect().encloses(s.ui.vitals.get_global_rect()),"all warnings stay inside viewport: "+str(dimensions))
  check(s.ui.vitals.get_global_rect().end.y<dimensions.y-100,"warnings clear bottom toolbelt: "+str(dimensions))
  await capture("hud_dangers_%d"%dimensions.x)
 s.open_backpack();s.ui.refresh();check(not s.ui.vitals.visible,"HUD health and warnings hide behind journal")
 s.close_backpack();p._hud_enabled=false;s.ui.refresh();check(not s.ui.vitals.visible,"vitals respect HUD disabled setting")
 p._hud_enabled=true;s.health=100;s.warmth=80;s.wetness=0;s.energy=100;s.body.water=85;s.body.food=85;s.body.stamina=100;p.backpack_weight=0;s.body.conditions.clear();s.ui.refresh();await settle()
 check(s.ui.active_alerts.is_empty() and s.ui.health_bar.value==100,"recovery immediately clears injuries, dangers and low-health warning")
 s.warmth=18;s.ui.refresh();check(s.ui.active_alerts.size()==1 and s.ui.active_alerts[0].id=="cold","cold warning appears before cold causes health damage")
 s.health=0;s.ui.refresh();check(s.ui.active_alerts.is_empty() and s.ui.health_bar.value==0 and s.ui.context_label.visible,"death keeps zero health and death notice, not stale treatment warnings")
 scene.free();current_scene=null;await settle()
 print("LANTERN / STATUS HUD SUMMARY: %d PASS, %d FAIL"%[passes,failures]);quit(1 if failures else 0)
func sample_center()->float:
 var image:=root.get_texture().get_image();var sum:=0.0;var count:=0
 for y in range(220,360,8):
  for x in range(450,750,8):
   sum+=image.get_pixel(x,y).get_luminance();count+=1
 return sum/maxf(1,count)
