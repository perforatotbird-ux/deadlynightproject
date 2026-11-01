extends SceneTree
var passes:=0
var failures:=0
func check(ok:bool,text:String)->void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func _initialize()->void:call_deferred("run")
func run()->void:
 var arena:=Node3D.new();arena.name="MapViewer";root.add_child(arena);current_scene=arena
 var p=load("res://scenes/player/Player.tscn").instantiate();arena.add_child(p);p.set_active(true);p.set_physics_process(false)
 var s=load("res://scripts/survival/SurvivalWorld.gd").new();arena.add_child(s);s.set_process(false);s.clock=2*86400+21*3600+7*60
 var watch=p.watch_arm
 check(watch.arm.get_node("LeftHand").mesh!=null and watch.arm.get_node("ForearmSleeve").mesh!=null,"watch uses authored left glove and sleeve meshes")
 check(watch.arm.has_node("LCD") and watch.arm.has_node("WatchStrap"),"physical watch display and wrist strap exist")
 var event:=InputEventKey.new();event.keycode=KEY_T;event.physical_keycode=KEY_T;event.pressed=true;p._input(event);watch._process(0.4)
 check(watch.visible and watch.blend==1,"T raises left arm to reading pose")
 check(watch.digits.text=="21:07" and watch.day_label.text=="DAY 03","digital watch shows game time, not operating-system time")
 s.clock+=60;watch.refresh_time();check(watch.digits.text=="21:08","display advances with game clock")
 watch._process(4);watch._process(0.4);check(not watch.visible and p._axe_sway_pivot.visible,"arm automatically lowers and restores tool model")
 p._is_inventory_open=true;watch.toggle();check(watch.remaining==0,"watch cannot start through inventory modal")
 p._is_inventory_open=false;s.health=0;watch.toggle();check(watch.remaining==0,"dead character cannot raise watch")
 p._audio_ui.stop();arena.free();current_scene=null
 print("WATCH SUMMARY: %d PASS, %d FAIL" % [passes,failures])
 for i in 3:await process_frame
 quit(1 if failures else 0)
