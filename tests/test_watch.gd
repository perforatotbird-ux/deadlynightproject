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
 check(watch.arm.find_child("LeftArm_Skin",true,false).mesh!=null,"watch uses the new anatomical forearm GLB, not the old glove")
 check(watch.arm.find_child("LCD",true,false)!=null and watch.arm.find_child("WatchStrap",true,false)!=null and watch.arm.find_child("RoundCase",true,false)!=null,"circular case, physical display and wrist strap exist")
 var model_meshes=watch.arm.find_children("*","MeshInstance3D",true,false)
 var triangles:=0
 for mesh in model_meshes:
  for surface in mesh.mesh.get_surface_count():
   var arrays=mesh.mesh.surface_get_arrays(surface)
   triangles+=arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size()/3
 check(triangles>20000 and triangles<100000,"runtime asset retains detail within the viewmodel triangle budget")
 check(model_meshes.size()<=12,"repeated indices and hardware are batched, not 100 separate draw objects")
 check(watch.arm.find_child("PreviewTime",true,false)==null and watch.arm.find_child("LeftArm_EditableCage",true,false)==null,"baked preview time and dense source cage are excluded from game export")
 check(watch.digits.get_parent().name=="DisplayAnchor" and watch.digits.pixel_size<0.0003,"live game display is fitted to the round authored LCD")
 var event:=InputEventKey.new();event.keycode=KEY_T;event.physical_keycode=KEY_T;event.pressed=true;p._input(event);watch._process(0.4)
 check(watch.visible and watch.blend==1,"T raises left arm to reading pose")
 check(watch.digits.text=="21:07" and watch.day_label.text=="DAY 03","digital watch shows game time, not operating-system time")
 s.clock+=60;watch.refresh_time();check(watch.digits.text=="21:08","display advances with game clock")
 watch._process(4);watch._process(0.4);check(not watch.visible and p._axe_sway_pivot.visible,"arm automatically lowers and restores tool model")
 p._is_inventory_open=true;watch.toggle();check(watch.remaining==0,"watch cannot start through inventory modal")
 p._is_inventory_open=false;p._is_map_open=true;watch.toggle();check(watch.remaining==0,"watch cannot start through map modal")
 p._is_map_open=false;s.health=0;watch.toggle();check(watch.remaining==0,"dead character cannot raise watch")
 p._audio_ui.stop();arena.free();current_scene=null
 print("WATCH SUMMARY: %d PASS, %d FAIL" % [passes,failures])
 for i in 3:await process_frame
 quit(1 if failures else 0)
