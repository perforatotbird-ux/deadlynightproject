extends SceneTree
var passed:=0
var failed:=0
var output:=OS.get_environment("DN_WOODLAND_REAL_OUTPUT")
func capture(id:String)->void:
 if output.is_empty() or DisplayServer.get_name()=="headless":return
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(id+".png"))
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1;print("PASS: "+label)
 else:failed+=1;printerr("FAIL: "+label)
func run()->void:
 var map=load("res://scenes/viewer/MapViewer.tscn").instantiate();root.add_child(map);current_scene=map
 var p=map.get_node("Player");p.set_active(true);p.set_physics_process(false)
 var s=map.get_node("SurvivalWorld");s.set_process(false);s.set_physics_process(false)
 var d=s.woodland;d.rng.seed=92204
 if not output.is_empty() and DisplayServer.get_name()!="headless":
  DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,720)
  load("res://scripts/core/SettingsManager.gd").get_instance().set_setting("graphics","shadow_quality",0)
  map.get_node("DirectionalLight3D").shadow_enabled=false
  for camera in map.find_children("*","Camera3D",true,false):camera.far=100
  # Keep genuine nearby trees; omit remote instances only for software-render QA.
  for node in map.get_node("WorldMap").find_children("*","MultiMeshInstance3D",true,false):
   var original:MultiMesh=node.multimesh;var keep:Array[Transform3D]=[]
   for i in original.instance_count:
    var transform:Transform3D=original.get_instance_transform(i)
    if (node.global_transform*transform.origin).distance_to(p.global_position)<85:keep.append(transform)
   var local:=MultiMesh.new();local.transform_format=MultiMesh.TRANSFORM_3D;local.mesh=original.mesh;local.instance_count=keep.size()
   for i in keep.size():local.set_instance_transform(i,keep[i])
   node.multimesh=local
  var terrain=map.get_node_or_null("WorldMap/Terrain")
  if terrain:
   for mesh in terrain.find_children("*","MeshInstance3D",true,false):
    var center:Vector3=mesh.global_transform*mesh.mesh.get_aabb().get_center()
    if Vector2(center.x-p.position.x,center.z-p.position.z).length()>350:mesh.hide()
  p.select_hotbar_slot(5);p._hud_layer.hide();s.ui.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 for i in 6:await process_frame
 check(d!=null and d.session==s,"actual forest owns one local woodland director")
 s.clock=12*3600;s.weather="clear";s.weather_until=s.clock+100000;s.weather_model.reset(s.clock,false)
 var state:Dictionary=s.weather_model.sample(s.clock,false,s.weather_until,s.daylight())
 for i in 300:d.advance(.05,state)
 var count:=0
 for bird in d.birds:
  if bird.visible:count+=1
 check(not d.patches.is_empty(),"real spawn terrain supplies outdoor insect habitat")
 check(count>0 and count<=6,"birds populate the actual forest without a global tree scan")
 check(d.insect_field.multimesh.visible_instance_count>0,"warm real forest has daytime insect life")
 s._update_lighting();await capture("actual_forest_day_1280")
 s.clock=23*3600;s.weather_model.reset(s.clock,false);state=s.weather_model.sample(s.clock,false,s.weather_until,s.daylight())
 s._update_lighting();p.select_hotbar_slot(1);p._is_lantern_on=false;p._toggle_lantern()
 d.call_cooldown=1000;d.night_cooldown=.01;s.atmosphere.finish_event();s.sky_events.suspend()
 d.advance(.05,state)
 check(d.pending_noise in ["twig","leaves"] and d.quiet_left>=3 and d.quiet_gain>0,"night tension begins with quiet rather than an instant loud cue")
 d.last_sound=""
 for i in 160:d.advance(.05,state)
 check(d.pending_noise=="" and d.night_cooldown>60,"one quiet interval produces no repeated event queue")
 check(d.last_sound in ["twig","leaves"],"real forest plays rare spatial night foley")
 await capture("actual_forest_night_1280")
 if d.last_sound!="":check(not p._camera.is_position_in_frustum(d.last_source),"real night cue stays outside the player's view")
 d.pending_noise="twig";d.quiet_left=5
 var storm:=state.duplicate();storm.rain=1.0;storm.wind=1.0;d.advance(.05,storm)
 check(d.pending_noise=="" and d.quiet_left==0,"storm cancels queued wildlife cues instead of releasing them together later")
 d.pending_noise="leaves";d.quiet_left=4;s.clock=12*3600;d.advance(.05,state)
 check(d.pending_noise=="" and d.quiet_left==0,"sunrise clears a pending night scare")
 s.open_backpack("","rest")
 var before:float=d.elapsed;s._process(0)
 check(d.elapsed==before,"opening journal does not advance fauna during zero time")
 s.close_backpack()
 s.prepare_travel();change_scene_to_file("res://scenes/mine/MineInterior.tscn")
 for i in 8:await process_frame
 var mine=current_scene.get_node("SurvivalWorld");mine.set_process(false);mine.player.set_physics_process(false);mine.woodland.advance(.1,state)
 check(not mine.woodland.allowed(),"actual mine transition disables woodland scheduling")
 check(mine.woodland.insect_field.multimesh.visible_instance_count==0 and not mine.woodland.cricket.playing,"mine has no outdoor swarms or cricket loop")
 print("WOODLAND INTEGRATION SUMMARY: %d PASS, %d FAIL"%[passed,failed])
 current_scene.free();current_scene=null
 for i in 3:await process_frame
 quit(1 if failed else 0)
