extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if ok:passed+=1;print("PASS: "+label)
 else:failed+=1;print("FAIL: "+label)
func run() -> void:
 var map=load("res://scenes/viewer/MapViewer.tscn").instantiate();root.add_child(map);current_scene=map
 var p=map.get_node("Player");p.set_physics_process(false)
 for i in 5:await process_frame
 var s=map.get_node("SurvivalWorld");s.set_process(false);s.clock=2*86400+23*3600;s.weather_until=s.clock+100000
 var d=s.atmosphere;d.rng.seed=471233
 check(d!=null and d.session==s,"actual forest session owns one atmospheric director")
 for kind in ["eyes","orbs"]:
  var found:=false;var longest:=0.0
  for attempt in 10:
   var time:=Time.get_ticks_usec()
   found=d.try_start_event(kind,false)
   longest=maxf(longest,(Time.get_ticks_usec()-time)/1000.0)
   if found:break
  print("PLAN %s: maximum call %.2f ms" % [kind,longest])
  check(found,"real terrain supports "+kind+" event without spawning in structures")
  if found:
   d.advance(3)
   check(d.visuals.size()<=3 and d.visuals[0].global_position.distance_to(p.global_position)>=14,"real forest event stays distant and bounded")
   var sm=load("res://scripts/core/SaveManager.gd").get_instance()
   check(sm.save_game("slot_atmosphere_"+kind,"manual","Atmosphere QA"),"SaveManager writes active "+kind)
   var payload=JSON.parse_string(FileAccess.get_file_as_string("user://saves/slot_atmosphere_"+kind+".json"))
   var age:float=d.event["elapsed"];d.finish_event();sm._apply_loaded_state(payload)
   check(d.event.get("kind")==kind and absf(float(d.event.get("elapsed",0))-age)<0.001,"SaveManager restores active "+kind+" once")
   d.finish_event()
 s.atmosphere.cooldown=0.5
 var before:float=s.atmosphere.cooldown
 p.set_active(false);s._process(2)
 check(is_equal_approx(s.atmosphere.cooldown,before),"free camera does not advance atmospheric scheduler")
 p.set_active(true);p.set_physics_process(false)
 s.prepare_travel();change_scene_to_file("res://scenes/mine/MineInterior.tscn")
 for i in 7:await process_frame
 var mine=current_scene.get_node("SurvivalWorld");mine.set_process(false);mine.player.set_physics_process(false)
 check(mine.atmosphere.visuals.is_empty() and not mine.atmosphere.try_start_event("eyes",false),"actual mine transition never renders forest eyes")
 print("ATMOSPHERE INTEGRATION SUMMARY: %d PASS, %d FAIL" % [passed,failed])
 current_scene.free();current_scene=null
 for i in 3:await process_frame
 quit(1 if failed else 0)
