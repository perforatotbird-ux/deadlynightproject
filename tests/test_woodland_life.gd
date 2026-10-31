extends SceneTree
var passes:=0
var failures:=0
var output:=OS.get_environment("DN_WOODLAND_QA_OUTPUT")
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
 var d=s.woodland;d.rng.seed=99381
 s.clock=12*3600;s.weather="clear";s.weather_until=s.clock+100000;s.weather_model.reset(s.clock,false)
 var state:Dictionary=s.weather_model.sample(s.clock,false,s.weather_until,s.daylight())
 var body_before:String=str(s.body.export_state());var survival_rng:String=str(s.rng.state)
 for i in 100:d.advance(.05,state)
 var visible_birds:=0
 for bird in d.birds:
  if bird.visible:visible_birds+=1
 check(visible_birds>0 and visible_birds<=6,"daytime has a bounded flock on real terrain")
 check(d.insect_field.multimesh.visible_instance_count>0 and d.insect_field.multimesh.visible_instance_count<=48,"warm dry daytime has bounded flying insects")
 check(d.moth_field.multimesh.visible_instance_count==0,"moths do not replace daytime insect life")
 check(d.find_children("*","CollisionObject3D",true,false).is_empty(),"wildlife never blocks interaction rays or attacks player")
 check(d.voices.size()==4,"one-shot spatial audio pool is bounded")
 check(d.ground_queries<=9 and d.ground_cache.size()<=128,"terrain sampling is coarse and budgeted")
 check(str(s.rng.state)==survival_rng,"ecology cannot reroll weather, loot or fire ignition")
 check(str(s.body.export_state())==body_before,"wildlife cannot change health, conditions or needs")
 for key in d.SOUNDS:
  check(d.SOUNDS[key].get_length()>0,"original audio asset loads: "+key)
 var bird=d.birds[0];bird.visible=true;bird.age=3;bird.opacity=1;bird.position=Vector3(3,5,-8);bird.target=Vector3(-15,8,-10)
 d.scatter();check(bird.startled>0 and d.scatter_cooldown==12,"running/chopping disturbance sends the flock away with a cooldown")
 var elapsed:float=d.elapsed;paused=true;d.advance(20,state);paused=false;check(d.elapsed==elapsed,"true pause stops fauna movement and event timers")
 d.suspend();check(d.insect_field.multimesh.visible_instance_count==0 and not d.cricket.playing,"suspension removes insects and stops their loop")
 s.clock=23*3600;s.weather_model.reset(s.clock,false);state=s.weather_model.sample(s.clock,false,s.weather_until,s.daylight())
 p.select_hotbar_slot(1);p._toggle_lantern();await settle()
 for i in 180:d.advance(.05,state)
 check(d.insect_field.multimesh.visible_instance_count==0,"ordinary daytime insects disappear at night")
 check(d.moth_field.multimesh.visible_instance_count>0 and d.moth_field.multimesh.visible_instance_count<=10,"a few moths remain during a dry mild night")
 var target:Vector3=p._camera.global_position-p._camera.global_basis.z*1.7
 var near_lamp:=true
 for i in d.moth_field.multimesh.visible_instance_count:
  if d.moth_field.multimesh.get_instance_transform(i).origin.distance_to(target)>1.0:near_lamp=false
 if DisplayServer.get_name()!="headless":check(near_lamp,"night moths circle the real switched-on portable light, not the lens") # Dummy renderer cannot read back MultiMesh buffers.
 if DisplayServer.get_name()!="headless":
  var previous:Vector3=d.moth_field.multimesh.get_instance_transform(0).origin;p._camera.rotation.y=.8;d._update_insects(.05,state)
  check(d.moth_field.multimesh.get_instance_transform(0).origin.distance_to(previous)<.5,"moths follow light with inertia rather than teleporting with camera turns")
  p._camera.rotation=Vector3.ZERO
 var daytime_left:=0
 for b in d.birds:
  if b.visible and not b.owl:daytime_left+=1
 check(daytime_left==0,"day birds fade out instead of flying through the whole night")
 var hidden_point:Vector3=Vector3.INF
 for i in 8:
  d.ground_queries=0;hidden_point=d._hidden_sound_position()
  if hidden_point!=Vector3.INF:break
 check(hidden_point!=Vector3.INF and hidden_point.distance_to(p.global_position)>=14,"night sound source is distant and on actual ground")
 if hidden_point!=Vector3.INF:check(not p._camera.is_position_in_frustum(hidden_point),"night rustle is outside field of view, not a face-level jump scare")
 for a in d.voices:a.stop()
 check(d.play_sound("twig",Vector3(15,1,0),-20),"spatial night foley can play from a real position")
 check(d.voices[0].bus=="Ambience" and d.voices[0].volume_db<=-12,"wildlife respects ambience volume and conservative loudness")
 for i in 8:d.play_sound("leaves",Vector3(18,1,0),-20)
 check(d.voices.size()==4,"simultaneous events never allocate extra audio voices")
 s.dev_events_enabled=false;d.advance(.1,state)
 var any_audio:bool=d.cricket.playing
 for a in d.voices:any_audio=any_audio or a.playing
 check(not any_audio and d.pending_noise=="","developer event suppression stops sounds and queued night cues")
 s.dev_events_enabled=true
 var storm:Dictionary=state.duplicate();storm.rain=1.0;storm.wind=1.0
 for i in 100:d.advance(.05,storm)
 check(d.density==0 and d.moth_field.multimesh.visible_instance_count==0 and not d.cricket.playing,"strong rain suppresses exposed insects and cricket bed")
 s.location="mine";d.advance(.1,state)
 check(not d.allowed() and d.moth_field.multimesh.visible_instance_count==0,"mine interiors never contain forest fauna")
 s.location="forest";p.position=s.shelter.to_global(Vector3(0,.2,0));d.advance(.1,state)
 check(not d.allowed(),"closed shelter has no indoor birds or swarms")
 p.position=Vector3(0,.2,0);d.advance(.1,state,true);check(not d.was_active,"sleep suspends ecology without a catch-up event queue")
 s.health=0;d.advance(.1,state);check(not d.allowed(),"death stops fauna scheduling")
 s.health=100;p.set_active(false);d.advance(.1,state);check(not d.allowed(),"free camera does not continue scheduling wildlife")
 p.set_active(true);p.set_physics_process(false)
 # Inspect actual tiny creature geometry at delivery scale, not a poster substitute.
 if graphical:
  root.size=Vector2i(1280,720);s.clock=12*3600;s.weather_model.reset(s.clock,false);s._update_lighting();s.ui.hide();p._hud_layer.hide();p.select_hotbar_slot(5)
  var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-30,0);sun.light_energy=1.7;scene.add_child(sun)
  env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("829685");env.environment.ambient_light_energy=.55;env.environment.background_color=Color("849b95")
  bird=d.birds[0];bird.configure(false);bird.visible=true;bird.position=Vector3(0,2,-3.8);bird.rotation=Vector3(0,1.15,0);bird.animate(.1,1);p._camera.look_at(bird.global_position,Vector3.UP)
  await settle();await capture("songbird_geometry_1280")
  d.density=1;d.patches.clear();d.patches.append(Vector3(.1,1.6,-2.2));s.clock=12*3600;d._update_insects(.05,state);bird.hide();p._camera.rotation=Vector3.ZERO
  await settle();await capture("insects_day_1280")
  bird.configure(true);bird.show();bird.position=Vector3(0,2,-4);bird.animate(.1,1);bird.rotation=Vector3(0,1.05,0);d.insect_field.multimesh.visible_instance_count=0;p._camera.look_at(bird.global_position,Vector3.UP)
  await settle();await capture("owl_geometry_1280")
  bird.hide();s.clock=23*3600;s.weather_model.reset(s.clock,false);s._update_lighting();sun.light_energy=0;env.environment.ambient_light_energy=.13;env.environment.background_color=Color("15201d");p._camera.rotation=Vector3.ZERO;p.select_hotbar_slot(1)
  d._update_insects(.05,state)
  await settle();await capture("moths_lantern_night_1280")
 scene.free();current_scene=null;await settle()
 print("WOODLAND LIFE SUMMARY: %d PASS, %d FAIL"%[passes,failures]);quit(1 if failures else 0)
