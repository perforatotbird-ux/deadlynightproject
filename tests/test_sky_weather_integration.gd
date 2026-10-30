extends SceneTree
var passes:=0
var failures:=0
var graphical:=false
var out:="/data/weather-real"
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 if ok:passes+=1;print("PASS: "+label)
 else:failures+=1;print("FAIL: "+label)
func settle(n:int=4) -> void:
 for i in n:await process_frame
func capture(label:String) -> void:
 if not graphical:return
 await settle(1);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out.path_join(label+".png"))
func run() -> void:
 graphical=DisplayServer.get_name()!="headless"
 if graphical:DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1280,720)
 var map=load("res://scenes/viewer/MapViewer.tscn").instantiate();root.add_child(map);current_scene=map
 var p=map.get_node("Player");p.set_physics_process(false)
 var s=map.get_node("SurvivalWorld");s.set_process(false)
 if graphical:
  # Software-render fixture restriction, NOT a target PC performance benchmark.
  load("res://scripts/core/SettingsManager.gd").get_instance().set_setting("graphics","shadow_quality",0)
  for instance in map.find_children("*","MultiMeshInstance3D",true,false):
   if instance!=s.rain_field.field:instance.hide()
  map.get_node("DirectionalLight3D").shadow_enabled=false
  for camera in map.find_children("*","Camera3D",true,false):camera.far=220
  var terrain=map.get_node_or_null("WorldMap/Terrain")
  if terrain:
   for mesh in terrain.find_children("*","MeshInstance3D",true,false):
    var center:Vector3=mesh.global_transform*mesh.mesh.get_aabb().get_center()
    if Vector2(center.x-p.position.x,center.z-p.position.z).length()>450:mesh.hide()
  p._hud_layer.hide();s.ui.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 await settle(5)
 check(s.sky_renderer.environment==map.get_node("WorldEnvironment").environment,"actual MapViewer uses SkyRenderer's local Environment")
 s.clock=23*3600;s.weather="clear";s.weather_until=s.clock+20000;s.weather_model.reset(s.clock,false);s._update_lighting()
 p._camera.look_at(p._camera.global_position+s.weather_model.celestial(s.clock).moon*100,Vector3.UP)
 await capture("01_actual_forest_moon")
 var sm=load("res://scripts/core/SaveManager.gd").get_instance()
 s.sky_events.start_anomaly();s.sky_events.advance(5,s.weather_visual)
 check(sm.save_game("slot_sky_weather","manual","Sky weather QA"),"SaveManager writes sky/weather to disk")
 var payload=JSON.parse_string(FileAccess.get_file_as_string("user://saves/slot_sky_weather.json"))
 var phase:float=s.weather_model.initial_phase;var elapsed:float=s.sky_events.event.elapsed
 s.sky_events.suspend();s.weather_model.initial_phase=0;sm._apply_loaded_state(payload)
 check(s.weather_model.initial_phase==phase and s.sky_events.event.get("kind")=="anomaly" and absf(float(s.sky_events.event.elapsed)-elapsed)<0.001,"disk save restores model and active anomaly")
 check(s.sky_events.thunder.is_empty(),"disk load produces no stale thunder")
 s.sky_events.suspend();s.weather="rain";s.weather_model.reset(s.clock,true);s.weather_model.rain_style="storm";s._update_lighting()
 s.sky_events.start_lightning();s.sky_events.advance(0.02,s.weather_visual)
 check(not s.sky_events.thunder.is_empty(),"actual forest schedules a delayed directional roll")
 # Actual roof/door, not a fake hidden particle emitter.
 p.global_position=s.shelter.global_position+Vector3(0,0.2,0);s.shelter.set_door(false)
 p._camera.look_at(s.shelter.global_position+Vector3(0,1,12),Vector3.UP)
 for i in 45:s.rain_field.update_field(1.0/30,s.weather_visual,1)
 check(s.covered() and s.rain_field.visible,"actual cabin does not switch off outside rain")
 await capture("02_actual_cabin_rain")
 s.open_backpack("","rest");await settle()
 check(p._is_inventory_open and p._is_active,"weather keeps actual backpack interactive")
 await capture("03_actual_backpack");s.close_backpack()
 var before:float=s.clock;p.set_active(false);s._process(4)
 check(s.clock==before,"inactive/free camera freezes weather and world together")
 p.set_active(true);p.set_physics_process(false)
 var rain_style:String=s.weather_model.rain_style;var until:float=s.weather_until
 if graphical:
  print("SKY WEATHER GRAPHICAL SUBSET: %d PASS, %d FAIL"%[passes,failures]);current_scene.free();current_scene=null;await settle();quit.call_deferred(1 if failures else 0);return
 s.prepare_travel();change_scene_to_file("res://scenes/mine/MineInterior.tscn");await settle(8)
 var mine=current_scene.get_node("SurvivalWorld");mine.set_process(false);mine.player.set_physics_process(false)
 check(mine.location=="mine" and mine.weather=="rain" and mine.weather_until==until,"forest to mine carries external weather interval")
 check(mine.sky_renderer.environment==null and not is_instance_valid(mine.sky_renderer.moon),"mine has no exterior Environment writer or moon light")
 mine.sky_events.advance(1,mine.weather_visual);mine.rain_field.update_field(0.04,mine.weather_visual,1)
 check(not mine.rain_field.visible and mine.sky_events.thunder.is_empty(),"mine has neither outdoor particles nor thunder backlog")
 # Clock and profiles continue outside while underground.
 mine.clock+=6*3600;mine.weather_until=mine.clock+20000
 mine.weather_model.sample(mine.clock,mine.weather=="rain",mine.weather_until,mine.daylight())
 mine.prepare_travel();change_scene_to_file("res://scenes/viewer/MapViewer.tscn");await settle(8)
 var back=current_scene.get_node("SurvivalWorld");back.set_process(false);back.player.set_physics_process(false)
 check(back.weather_model.rain_style==rain_style and back.weather=="rain","mine to forest restores storm style")
 check(current_scene.find_children("MoonLight","DirectionalLight3D",true,false).size()==1,"round trip has exactly one moon")
 check(back.sky_events.thunder.is_empty() and back.sky_events.event.is_empty(),"returning never dumps missed outdoor events")
 print("SKY WEATHER INTEGRATION SUMMARY: %d PASS, %d FAIL"%[passes,failures])
 current_scene.free();current_scene=null;await settle();quit.call_deferred(1 if failures else 0)
