extends SceneTree
var passes:=0
var failures:=0
var output:=OS.get_environment("DN_HUD_QA_OUTPUT")
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
 var s=load("res://scripts/survival/SurvivalWorld.gd").new();scene.add_child(s);s.set_process(false);s.vegetation.set_physics_process(false);s.shelter.position=Vector3(40,0,40)
 await physics_frame;await settle()
 var ui=p._backpack_ui
 s.ui.refresh()
 check(s.ui.find_children("*","PanelContainer",true,false).is_empty(),"top HUD panel is removed, not merely hidden")
 check(s.ui.context_label.text.is_empty() and not s.ui.context_label.visible,"ordinary gameplay has no persistent survival HUD text")
 check(p._hud_layer.visible,"crosshair, toolbelt and other player HUD stay enabled")
 check(p._hotbar_status_labels[3].text=="%d шт." % s.matches,"match counter still updates without top strip")
 await capture("gameplay_1280")
 s.open_backpack();ui.focus_condition();await settle()
 check(ui.condition_temperature.is_visible_in_tree(),"air temperature is a dedicated visible State field")
 for hour in [0,6,12,23]:
  s.clock=hour*3600;s.weather="clear";s.weather_until=s.clock+10000;s.weather_model.reset(s.clock,false);ui.refresh_actions()
  check(ui.condition_temperature.text=="Температура воздуха: %.1f °C" % s.air_temperature(),"temperature matches authoritative model at hour %d" % hour)
 s.clock=12*3600;s.weather_model.reset(s.clock,false);ui.refresh_actions();var warm_text:String=ui.condition_temperature.text
 s.clock=0;await create_timer(0.4).timeout
 check(ui.condition_temperature.text!=warm_text and ui.condition_temperature.text=="Температура воздуха: %.1f °C" % s.air_temperature(),"open State tab updates automatically as world temperature changes")
 s.weather="rain";s.weather_until=s.clock+10000;s.weather_model.reset(s.clock,true);ui.refresh_actions()
 check(ui.condition_temperature.text=="Температура воздуха: %.1f °C" % s.air_temperature(),"rain temperature uses actual air model, not comfort or felt temperature")
 for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(800,600)]:
  root.size=dimensions;await settle();ui.resize();await settle()
  check(root.get_visible_rect().encloses(ui.condition_temperature.get_global_rect()),"temperature stays inside viewport: "+str(dimensions))
  check(ui.condition_temperature.get_global_rect().end.y<=ui.condition_values.health.label.get_global_rect().position.y,"temperature does not overlap survival bars: "+str(dimensions))
  await capture("condition_%d" % dimensions.x)
 root.size=Vector2i(1280,720);await settle()
 s.close_backpack();s.placing=true;s.placement={"reason":"Посмотрите на землю в пределах 4,5 м"};s.ui.refresh()
 check(s.ui.context_label.visible and "землю" in s.ui.context_label.text,"placement validation notice remains without a black background")
 await settle();await capture("placement_1280")
 p._hud_enabled=false;s.ui.refresh();check(not s.ui.context_label.visible,"context notice respects HUD-off setting")
 p._hud_enabled=true;s.placing=false;s.placement={};s.ui.refresh();check(not s.ui.context_label.visible,"placement notice disappears after cancellation")
 s.health=0;s.body.death_reason="Переохлаждение";s.ui.refresh()
 check(s.ui.context_label.visible and "Переохлаждение" in s.ui.context_label.text,"death reason remains visible without top strip")
 await settle();await capture("death_1280")
 s.health=100;s.open_backpack();s.health=0;s.ui.refresh();check(p._is_inventory_open and not s.ui.context_label.visible,"context notice never overlays the journal")
 scene.free();current_scene=null;await settle()
 print("HUD / TEMPERATURE SUMMARY: %d PASS, %d FAIL" % [passes,failures]);quit(1 if failures else 0)
