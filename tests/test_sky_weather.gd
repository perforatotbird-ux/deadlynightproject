extends SceneTree
const Model=preload("res://scripts/weather/WeatherModel.gd")
const Session=preload("res://scripts/survival/SurvivalWorld.gd")
var passes:=0
var failures:=0
var scene:Node3D
var p:Node3D
var s:Node
var graphical:=false
var out:="/data/weather-previews"
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 if ok:passes+=1;print("PASS: "+label)
 else:failures+=1;print("FAIL: "+label)
func settle(n:int=4) -> void:
 for i in n:await process_frame
func box(size:Vector3,pos:Vector3,color:Color) -> void:
 var body:=StaticBody3D.new();scene.add_child(body);body.position=pos
 var shape:=CollisionShape3D.new();var cube:=BoxShape3D.new();cube.size=size;shape.shape=cube;body.add_child(shape)
 var mesh:=MeshInstance3D.new();var b:=BoxMesh.new();b.size=size;mesh.mesh=b;var mat:=StandardMaterial3D.new();mat.albedo_color=color;mesh.material_override=mat;body.add_child(mesh)
func capture(label:String) -> void:
 if not graphical:return
 await settle(1);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out.path_join(label+".png"))
func state_for(kind:String,clock:float) -> void:
 s.clock=clock;s.weather="rain" if kind in ["light_rain","heavy_rain","storm"] else "clear";s.weather_until=clock+10000
 s.weather_model.reset(clock,s.weather=="rain");s.weather_model.rain_style=kind if s.weather=="rain" else "light_rain";s.weather_model.dry_style=kind if s.weather=="clear" else "clear"
 s._update_lighting()
func run() -> void:
 graphical=DisplayServer.get_name()!="headless";root.size=Vector2i(1280,720)
 if graphical:DirAccess.make_dir_recursive_absolute(out)
 var m=Model.new();m.reset(0,false)
 var b0:Dictionary=m.celestial(86399.9);var b1:Dictionary=m.celestial(86400.1)
 check(b0.sun.distance_to(b1.sun)<0.0001,"sun continuous through midnight")
 check(b0.moon.distance_to(b1.moon)<0.0001,"moon continuous through midnight")
 var n0:Dictionary=m.celestial(0);var n1:Dictionary=m.celestial(86400)
 check(n0.sun.distance_to(n1.sun)<0.00001,"no daily integration drift")
 check(absf(n0.phase-n1.phase)<0.12,"lunar phase evolves over days, not a single night")
 for h in [0,6,12,18,23]:
  var body:Dictionary=m.celestial(h*3600)
  check(absf(body.sun.length()-1)<0.00001 and absf(body.moon.length()-1)<0.00001,"unit celestial directions at hour %d"%h)
  check(absf((1-body.sun.dot(body.moon))*0.5-body.phase)<0.00001,"phase matches sun/moon elongation at hour %d"%h)
 var a:Dictionary=m.sample(0,false,7200,1);var pre:Dictionary=m.sample(7100,false,7200,1)
 check(pre.cloud>a.cloud+0.5 and pre.rain==0,"clouds precede rain without wetness penalty")
 var changed:Dictionary=m.sample(7201,true,18000,1)
 check(absf(changed.cloud-pre.cloud)<0.01,"no cloud discontinuity when binary weather changes")
 var rainy:Dictionary=m.sample(8201,true,18000,1)
 check(rainy.rain>0 and rainy.cloud>0.7,"rain ramps in under cloud cover")
 var data:Dictionary=JSON.parse_string(JSON.stringify(m.export_state()));var restored=Model.new();restored.import_state(data,8201,true)
 check(absf(restored.sample(8201,true,18000,1).cloud-rainy.cloud)<0.0001,"weather transition survives JSON")
 restored.import_state({},9000,true);check(restored.sample(9000,true,19000,0).rain>0,"legacy rain gets safe populated defaults")
 scene=Node3D.new();scene.name="MapViewer";root.add_child(scene);current_scene=scene
 box(Vector3(220,1,220),Vector3(0,-0.5,0),Color(0.12,0.16,0.12))
 var env:=WorldEnvironment.new();env.name="WorldEnvironment";env.environment=Environment.new();env.environment.background_mode=Environment.BG_SKY;env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.environment.fog_enabled=true;scene.add_child(env)
 var sun:=DirectionalLight3D.new();sun.name="DirectionalLight3D";scene.add_child(sun)
 # A deliberately small test grove: real opaque geometry exercises sky occlusion.
 for x in [-25,-18,-11,11,18,25]:
  box(Vector3(0.65,11,0.65),Vector3(x,5.5,-23),Color(0.09,0.12,0.1))
  var canopy:=MeshInstance3D.new();var cone:=CylinderMesh.new();cone.top_radius=0;cone.bottom_radius=4;cone.height=12;canopy.mesh=cone;var mat:=StandardMaterial3D.new();mat.albedo_color=Color(0.075,0.14,0.1);canopy.material_override=mat;scene.add_child(canopy);canopy.position=Vector3(x,12,-23)
 p=load("res://scenes/player/Player.tscn").instantiate();scene.add_child(p);p.set_active(true);p.set_physics_process(false);p.position=Vector3(0,0.2,0)
 s=Session.new();scene.add_child(s);s.set_process(false);s.shelter.position=Vector3(7,0.08,-3)
 await physics_frame;await settle()
 if graphical:p._hud_layer.hide();s.ui.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 p._camera.look_at(Vector3(0,10,-25),Vector3.UP)
 check(s.sky_renderer.material!=null and s.sky_renderer.environment.sky!=null,"live sky installed in exterior Environment")
 check(scene.find_children("MoonLight","DirectionalLight3D",true,false).size()==1,"one moon light, no per-star light nodes")
 var rng_before:=str(s.rng.state)
 for kind in ["clear","broken","overcast","light_rain","heavy_rain","storm","mist"]:
  state_for(kind,23*3600)
  check(s.weather_visual.kind==kind,"weather profile "+kind)
 check(str(s.rng.state)==rng_before,"weather visuals never consume survival/ignition RNG")
 for pair in [["01_dawn","clear",5.8],["02_day","clear",12.0],["03_sunset","broken",18.6],["04_moon_night","clear",23.0],["05_overcast","overcast",23.0],["06_storm","storm",23.0],["07_mist","mist",6.2]]:
  state_for(pair[1],float(pair[2])*3600)
  await capture(pair[0])
 state_for("clear",23*3600)
 var body:Dictionary=s.weather_model.celestial(s.clock)
 p._camera.look_at(p._camera.global_position+body.moon*100,Vector3.UP);await capture("08_moon_close")
 check(s.sky_renderer.moon.light_energy>0,"moon above horizon lights the forest")
 check(s.sky_renderer.moon.global_basis.z.dot(body.moon)>0.999,"moon light direction matches visible disk")
 s.weather_model.initial_phase=0;state_for("clear",0)
 check(s.sky_renderer.moon.light_energy<0.001,"new moon does not fill the night with light")
 await capture("09_new_moon");s.weather_model.initial_phase=0.46
 state_for("heavy_rain",14*3600);p._camera.look_at(s.shelter.global_position+Vector3(0,1,0),Vector3.UP)
 for i in 40:s.rain_field.update_field(1.0/30,s.weather_visual,1)
 check(s.rain_field.count>200,"bounded visible rain field")
 check(s.rain_field.material.get_shader_parameter("roof_enabled"),"cabin roof mask enabled independently of player cover")
 await capture("10_rain_outside")
 p.global_position=s.shelter.global_position+Vector3(0,0.2,0);s.shelter.set_door(false);p._camera.look_at(s.shelter.global_position+Vector3(0,1,12),Vector3.UP)
 for i in 40:s.rain_field.update_field(1.0/30,s.weather_visual,1)
 check(s.covered() and s.rain_field.visible and s.rain_field.count>0,"shelter keeps exterior rain visible through open door")
 await capture("11_rain_doorway")
 var roof_min:Vector3=s.rain_field.material.get_shader_parameter("roof_min");var roof_max:Vector3=s.rain_field.material.get_shader_parameter("roof_max")
 check(p.global_position.x>roof_min.x and p.global_position.x<roof_max.x and p.global_position.y<roof_max.y,"roof mask contains indoor rain fragments")
 s.sky_events.start_lightning()
 check(float(s.sky_events.thunder.delay)>=700.0/343 and float(s.sky_events.thunder.delay)<=2400.0/343,"thunder delay is distance / 343 m/s")
 check(not s.sky_events.players[0].playing,"thunder never plays simultaneously with flash")
 var reduced=load("res://scripts/core/SettingsManager.gd").get_instance();reduced.set_setting("graphics","reduced_lightning",true)
 s.sky_events.advance(0.016,s.weather_visual);var low:float=s.sky_events.flash
 reduced.set_setting("graphics","reduced_lightning",false);s.sky_events.flash_age=0;s.sky_events.advance(0.016,s.weather_visual)
 check(s.sky_events.flash>low*3,"reduced flashes preserve event with lower peak")
 await capture("12_lightning")
 s.sky_events.suspend();check(s.sky_events.thunder.is_empty() and s.sky_events.flash==0,"suspend cancels flash and thunder backlog")
 state_for("clear",23*3600);p.global_position=Vector3(0,0.2,0)
 s.sky_events.start_meteor();var duration:float=s.sky_events.event.duration
 check(duration<0.8 and duration>0.3,"meteor is brief, not an orbiting comet")
 var start:Vector3=s.sky_renderer.material.get_shader_parameter("meteor_start");p._camera.look_at(p._camera.global_position+start*100,Vector3.UP)
 s.sky_events.advance(duration*0.45,s.weather_visual);await capture("13_meteor")
 s.sky_events.advance(1,s.weather_visual);check(s.sky_events.event.is_empty(),"meteor clears without a persistent node")
 s.sky_events.start_anomaly();s.sky_events.advance(5,s.weather_visual)
 var old:Vector3=s.sky_renderer.material.get_shader_parameter("anomaly_dir")
 s.sky_events.advance(1.0/60,s.weather_visual);var moved:Vector3=s.sky_renderer.material.get_shader_parameter("anomaly_dir")
 check(old.angle_to(moved)<deg_to_rad(0.6)/60+0.00005,"anomaly has bounded sub-degree/second movement")
 p._camera.look_at(p._camera.global_position+moved*100,Vector3.UP);await capture("14_anomaly")
 var saved:Dictionary=JSON.parse_string(JSON.stringify(s.export_state()));s.import_state(saved)
 check(s.sky_events.event.get("kind")=="anomaly","long anomaly survives session JSON load")
 check(s.sky_events.thunder.is_empty(),"load never replays a pending thunder roll")
 var elapsed:float=s.sky_events.event.elapsed;paused=true;s.sky_events.advance(2,s.weather_visual);paused=false
 check(s.sky_events.event.elapsed==elapsed,"pause freezes real-time sky events")
 s.sky_events.advance(1,s.weather_visual,true);check(s.sky_events.event.is_empty(),"sleep clears ephemeral effects")
 s.sky_events.start_meteor();s.location="mine";s.sky_events.advance(1,s.weather_visual)
 check(s.sky_events.event.is_empty() and s.sky_events.thunder.is_empty(),"mine drops exterior events without catch-up")
 s.rain_field.update_field(0.04,s.weather_visual,2);check(not s.rain_field.visible,"mine has no outdoor rain")
 s.location="forest";s.sky_events.suspend()
 s.weather_model.initial_phase=0.46;state_for("clear",23*3600)
 s.import_state({"clock":82800,"weather":"rain","weather_until":100000})
 check(s.weather=="rain" and s.weather_visual.rain>0,"legacy session save migration")
 check(scene.find_children("MoonLight","DirectionalLight3D",true,false).size()==1,"loads do not duplicate moon lights")
 # Multi-day 1/6/12-hour clock jumps never synthesize past events.
 for hours in [1,6,12,48,72]:
  s.clock+=hours*3600;s._update_lighting()
  check(s.sky_events.thunder.is_empty(),"no replay after %d-hour clock jump"%hours)
 # CPU timings are isolated scene measurements, never advertised as hardware GPU FPS.
 var cpu_start:=Time.get_ticks_usec()
 for i in 120:s._update_lighting()
 print("WEATHER_CPU_UPDATE_US: ",float(Time.get_ticks_usec()-cpu_start)/120)
 if graphical:
  state_for("clear",23*3600);p._camera.look_at(p._camera.global_position+s.weather_model.celestial(s.clock).moon*100,Vector3.UP)
  root.size=Vector2i(1920,1080);await capture("15_moon_1080p")
  reduced.set_setting("graphics","sky_quality",0);s._update_lighting();await capture("16_low_quality_1080p")
  reduced.set_setting("graphics","sky_quality",1)
  for pair in [["17_dawn_1080p","clear",5.8],["18_day_1080p","clear",12.0],["19_sunset_1080p","broken",18.6],["20_night_1080p","clear",23.0],["21_overcast_1080p","overcast",23.0],["22_storm_1080p","storm",23.0],["23_mist_1080p","mist",6.2]]:
   state_for(pair[1],float(pair[2])*3600)
   var view:=Vector3(0,0.3,-1)
   if pair[0] in ["17_dawn_1080p","19_sunset_1080p"]:
    var direction:Vector3=s.weather_model.celestial(s.clock).sun
    view=Vector3(direction.x,0.25,direction.z).normalized()
   p._camera.look_at(p._camera.global_position+view*100,Vector3.UP)
   await capture(pair[0])
 if graphical and "--motion" in OS.get_cmdline_user_args():await capture_motion()
 print("SKY WEATHER SUMMARY: %d PASS, %d FAIL"%[passes,failures])
 scene.queue_free();await settle();quit.call_deferred(1 if failures else 0)

func capture_motion() -> void:
 load("res://scripts/core/SettingsManager.gd").get_instance().set_setting("graphics","sky_quality",1)
 root.size=Vector2i(1280,720)
 var folder:="/data/weather-motion"
 DirAccess.make_dir_recursive_absolute(folder)
 s.sky_events.suspend();s.atmosphere.suspend();p.global_position=Vector3(0,0.2,0)
 var index:=0
 for clip in ["stars_pan","meteor","anomaly","lightning","rain","roof"]:
  s.sky_events.suspend();state_for("clear",23*3600)
  var length:=30
  var center:Vector3=s.weather_model.celestial(s.clock).moon
  if clip=="meteor":
   s.sky_events.start_meteor();center=s.sky_renderer.material.get_shader_parameter("meteor_start");length=20
  elif clip=="anomaly":
   s.sky_events.start_anomaly();s.sky_events.advance(5,s.weather_visual);center=s.sky_renderer.material.get_shader_parameter("anomaly_dir");length=50
  elif clip=="lightning":
   state_for("storm",23*3600);s.sky_events.start_lightning()
   var points:PackedVector3Array=s.sky_renderer.material.get_shader_parameter("bolt_points")
   center=points[4] if points[4].y>0 else Vector3(0,0.4,-1)
  elif clip in ["rain","roof"]:
   state_for("heavy_rain",14*3600);center=Vector3(0,0.15,-1)
   if clip=="roof":p.global_position=s.shelter.global_position+Vector3(0,0.2,0);s.shelter.set_door(false);center=Vector3(0,0.05,1)
   for i in 30:s.rain_field.update_field(1.0/30,s.weather_visual,1)
  p._camera.look_at(p._camera.global_position+center*100,Vector3.UP)
  var camera_basis:Basis=p._camera.global_basis
  for frame in length:
   if clip=="stars_pan":
    s.clock+=6;s._update_lighting()
    p._camera.global_basis=Basis(Vector3.UP,deg_to_rad(float(frame)*0.25))*camera_basis
   else:
    s.sky_events.advance(0.1,s.weather_visual)
    s.rain_field.update_field(0.1,s.weather_visual,1)
   await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(folder.path_join("frame_%04d.png"%index));index+=1
  print("MOTION CLIP ",clip," frames ",length)
