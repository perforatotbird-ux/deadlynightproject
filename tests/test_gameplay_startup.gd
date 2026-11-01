extends SceneTree
# Real run.bat scene with player physics ENABLED. Use an isolated XDG_DATA_HOME.
# --expect-missing-watch also exercises the externally damaged import-cache case.
var passes:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,text:String)->void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func frames(n:int)->void:
 for i in n:await physics_frame;await process_frame
func key(code:int)->void:
 for pressed in [true,false]:
  var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
  Input.parse_input_event(event)
  await process_frame
func run()->void:
 var missing:=OS.get_cmdline_user_args().has("--expect-missing-watch")
 var world=load("res://scenes/viewer/MapViewer.tscn").instantiate()
 root.add_child(world);current_scene=world
 await frames(12)
 var p=world.get_node("Player")
 check(p._is_active and p._camera.current and p.is_physics_processing(),"actual forest starts with active player physics and camera")
 check(is_instance_valid(p._hud_layer) and is_instance_valid(p._backpack_ui) and is_instance_valid(p._pause_menu),"HUD, backpack and pause finish initialization")
 check(is_instance_valid(p.survival),"survival is attached in the real forest")
 var start:Vector3=p.global_position
 Input.action_press("move_forward");await frames(24);Input.action_release("move_forward")
 var moved:=Vector2(p.global_position.x-start.x,p.global_position.z-start.z).length()
 check(moved>0.2,"W moves player through real world collision (%.2f m)" % moved)
 await key(KEY_TAB)
 check(p._is_inventory_open,"Tab opens backpack through viewport input")
 await key(KEY_TAB)
 check(not p._is_inventory_open,"Tab closes backpack")
 await key(KEY_M)
 check(p._is_map_open,"M opens field map")
 await key(KEY_M)
 check(not p._is_map_open,"M closes field map")
 await key(KEY_ESCAPE)
 check(paused and p._pause_menu.visible,"Escape opens pause menu and pauses world")
 p._pause_menu.resume_game();await frames(2)
 check(not paused and not p._pause_menu.visible,"resume returns control to player")
 await key(KEY_T);await frames(25)
 if missing:
  check(not p.watch_arm.model_ready and not p.watch_arm.visible,"broken visual stays disabled, T does not crash")
  check(p._axe_sway_pivot.visible,"missing watch never hides equipped tool")
 else:
  check(p.watch_arm.model_ready and p.watch_arm.visible,"T raises imported round watch in actual forest")
  check(p.watch_arm.digits.text.contains(":"),"live watch display contains game time")
 p.watch_arm.lower();await frames(25)
 start=p.global_position
 Input.action_press("move_backward");await frames(24);Input.action_release("move_backward")
 check(Vector2(p.global_position.x-start.x,p.global_position.z-start.z).length()>0.2,"movement still works after all UI interactions")
 # Exercise missing source independently of production cache.
 var optional=load("res://scripts/player/WatchArm.gd").new()
 optional.model_path="res://assets/nonexistent-watch-test.glb";optional.player=p;p._camera.add_child(optional)
 check(not optional.model_ready and not optional.can_check(),"absent optional model degrades safely")
 optional.toggle();optional._process(0.5);optional.free()
 print("GAMEPLAY STARTUP SUMMARY: %d PASS, %d FAIL" % [passes,failures])
 world.free();current_scene=null;await frames(3)
 quit(1 if failures else 0)
