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
 var s=load("res://scripts/survival/SurvivalWorld.gd").new();arena.add_child(s);s.set_process(false)
 var view=s.map_ui.view
 for pair in [[0.0,Vector2.UP],[-PI/2,Vector2.RIGHT],[PI,Vector2.DOWN],[PI/2,Vector2.LEFT]]:
  p.rotation.y=pair[0]
  var direction:Vector2=view.player_heading()
  check(direction.dot(pair[1])>0.999,"camera heading projects correctly: "+str(pair[1]))
  var arrow:PackedVector2Array=view.player_arrow(Vector2.ZERO,direction)
  check(arrow[0].normalized().dot(direction)>0.999 and arrow[0].length()==17,"arrow tip, not tail, points along view")
 p._camera.rotation.y=0.4
 check(view.player_heading().distance_to(Vector2(-p._camera.global_basis.z.x,-p._camera.global_basis.z.z).normalized())<0.001,"heading follows actual camera rather than only body")
 p._camera.rotation.x=PI/2;p._camera.rotation.y=0
 check(view.player_heading().is_finite() and view.player_heading().length()>0.99,"looking straight up uses stable body yaw")
 print("MAP ARROW SUMMARY: %d PASS, %d FAIL" % [passes,failures])
 arena.free();await process_frame;quit(1 if failures else 0)
