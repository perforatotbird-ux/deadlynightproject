extends SceneTree
var passes:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,text:String) -> void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func settle(frames:int=5) -> void:
 for i in frames:await process_frame
func stop_scene() -> void:
 if current_scene!=null:
  var player=current_scene.get_node_or_null("Player")
  var session=current_scene.get_node_or_null("SurvivalWorld")
  if player:player.set_physics_process(false)
  if session:session.set_process(false)
func key(code:Key) -> void:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;root.push_input(event,true);await process_frame
 event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=false;root.push_input(event,true);await process_frame
func run() -> void:
 scene_changed.connect(stop_scene)
 var scene=load("res://scenes/viewer/MapViewer.tscn").instantiate();root.add_child(scene);current_scene=scene;stop_scene();await physics_frame;await settle()
 var s=scene.get_node("SurvivalWorld");var p=s.player
 check(is_instance_valid(s.dev_menu) and s.resources.has("camp_supply_0"),"real forest contains health supplies and Dev Menu")
 check(scene.get_node_or_null("POITeleportUI")==null,"old always-visible debug teleport panel removed")
 p.global_position=s.shelter.to_global(Vector3(-0.8,0.2,1.2));await physics_frame
 var target=s.resources.camp_supply_0
 p._raycast.target_position=p._raycast.to_local(target.global_position+Vector3.UP*0.12);p._raycast.force_raycast_update()
 check(p._raycast.is_colliding() and p._raycast.get_collider()==target,"camp supply is reachable by the real interaction ray")
 await key(KEY_E);check(s.picked.has("camp_supply_0") and s.Items.count(p.inventory_slots,"ration")==1,"real E input picks up finite ration")
 var collector:Node3D
 for n in scene.get_children():
  if n.get_script()==load("res://scripts/survival/RainCollector.gd"):collector=n
 p.global_position=collector.global_position+Vector3(0,0.2,1.3);await physics_frame
 p._raycast.target_position=p._raycast.to_local(collector.global_position+Vector3.UP*0.25);p._raycast.force_raycast_update()
 check(p._raycast.is_colliding() and p._raycast.get_collider()==collector,"collector is reachable through real interaction")
 s.rain_reserve=2;await key(KEY_E);check(s.rain_reserve==1 and s.Items.count(p.inventory_slots,"raw_water")==1,"real E input collects stored raw water")
 s.body.food=37;s.body.water=42;s.body.conditions.sprain={"remaining":125};s.body.invulnerable=true;s.dev_tainted=true;s.shelter.set_door(false)
 var sm=load("res://scripts/core/SaveManager.gd").get_instance();check(sm.save_game("health_world_forest","manual","Health world QA"),"full forest disk save succeeds")
 var saved_food:float=s.body.food
 s.dev_menu.open_menu();s.dev_menu.execute("scene",{"location":"mine"});await settle(8)
 check(current_scene.name=="MineInterior" and not paused,"Dev scene transition exits pause and enters real mine")
 var mine=current_scene.get_node("SurvivalWorld");check(mine.body.food<=saved_food and mine.body.food>35 and mine.body.conditions.has("sprain"),"mine retains nutrition and injury")
 check(not mine.body.invulnerable and mine.dev_tainted,"scene transition resets cheats and retains DEV provenance")
 var old_water:float=mine.body.water;mine.advance(60);check(mine.body.water<old_water,"needs continue advancing inside mine")
 check(sm.save_game("health_world_mine","manual","Health mine QA"),"mine disk save succeeds")
 mine.dev_menu.open_menu();mine.dev_menu.execute("scene",{"location":"forest"});await settle(8)
 var forest=current_scene.get_node("SurvivalWorld");check(current_scene.name=="MapViewer" and not paused,"Dev return uses real forest scene")
 check(forest.picked.has("camp_supply_0") and not forest.resources.has("camp_supply_0"),"consumed starting supply does not duplicate across scene round trip")
 check(not forest.shelter.door_closed and forest.rain_reserve>=1,"exterior door and water reserve survive mine round trip")
 check(sm.load_game("health_world_mine"),"SaveManager accepts saved health state inside mine");await settle(10)
 var loaded=current_scene.get_node("SurvivalWorld");check(current_scene.name=="MineInterior" and loaded.body.conditions.has("sprain") and loaded.body.food>0,"disk load chooses correct scene and restores body")
 check(not loaded.body.invulnerable and not loaded.dev_freeze_world and loaded.dev_time_rate==1,"disk load never restores cheats/time overrides")
 sm.delete_save("health_world_forest");sm.delete_save("health_world_mine")
 current_scene.queue_free();current_scene=null;await settle();print("HEALTH WORLD SUMMARY: %d PASS, %d FAIL" % [passes,failures]);quit(1 if failures else 0)
