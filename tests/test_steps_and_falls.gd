extends SceneTree
var passes:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passes+=1;print("PASS: "+label)
 else:failures+=1;print("FAIL: "+label)
func block(parent:Node3D,size:Vector3,pos:Vector3)->StaticBody3D:
 var body:=StaticBody3D.new();var shape:=BoxShape3D.new();shape.size=size;var col:=CollisionShape3D.new();col.shape=shape;body.add_child(col);parent.add_child(body);body.position=pos;return body
func run()->void:
 var arena:=Node3D.new();arena.name="MapViewer";root.add_child(arena);current_scene=arena
 block(arena,Vector3(30,1,30),Vector3(0,-0.5,0))
 var step:=block(arena,Vector3(2,0.35,2),Vector3(0,0.175,-1.5))
 var p=load("res://scenes/player/Player.tscn").instantiate();arena.add_child(p);p.position=Vector3(0,0.01,0);p.set_active(true);p.set_physics_process(false)
 await physics_frame;p.velocity=Vector3(0,-1,0);p.move_and_slide();await physics_frame
 p.velocity=Vector3(0,0,-4);p._coyote_timer=0.2
 check(p._try_step_up(Vector3(0,0,-0.3)),"capsule steps onto a 35 cm ledge")
 check(p.global_position.y>0.2 and p.global_position.y<0.4 and not p.test_move(p.global_transform,Vector3.UP*0.01),"capsule rests safely on ledge edge without penetration")
 p.position=Vector3(0,0.01,0);step.position.y=0.5;await physics_frame;p.velocity=Vector3(0,0,-4);p._coyote_timer=0.2
 check(not p._try_step_up(Vector3(0,0,-0.3)),"high ledge cannot be climbed by step teleport")
 step.position.y=0.175
 var ceiling:=block(arena,Vector3(2,0.15,2),Vector3(0,1.92,0));p.position=Vector3(0,0.01,0);await physics_frame
 check(not p._try_step_up(Vector3(0,0,-0.3)),"step cannot pass through a low ceiling")
 ceiling.free()
 var s=load("res://scripts/survival/SurvivalWorld.gd").new()
 s.land(25.0,0.4);check(s.health==100 and s.body.conditions.is_empty(),"small drop cannot injure even with stale high impact speed")
 s.land(8.0,1.2);check(s.health==100,"ordinary jump is harmless")
 s.land(17.0,6.0);check(s.health<100 and s.body.conditions.has("sprain"),"dangerous real fall still causes injury")
 s.free();p._audio_ui.stop();arena.free();current_scene=null
 print("STEPS AND FALLS SUMMARY: %d PASS, %d FAIL" % [passes,failures])
 for i in 3:await process_frame
 quit(1 if failures else 0)
