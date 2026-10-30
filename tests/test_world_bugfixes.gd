extends SceneTree
const Trees=preload("res://scripts/props/TreeChoppable.gd")
const Items=preload("res://scripts/survival/SurvivalItems.gd")
var passes:=0
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,text:String):
 if ok:passes+=1;print("PASS: ",text)
 else:failures+=1;print("FAIL: ",text)
func settle(n:int=4):
 for i in n:await process_frame
func key(code:Key):
 for down in [true,false]:
  var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;root.push_input(e,true);await process_frame
func idle(tree):
 var deadline=Time.get_ticks_msec()+20000
 while is_instance_valid(tree) and tree._voxel_trunk.is_busy() and Time.get_ticks_msec()<deadline:await create_timer(0.005).timeout
func make_scene():
 var scene=load("res://scenes/viewer/MapViewer.tscn").instantiate();root.add_child(scene);current_scene=scene
 scene.get_node("Player").set_physics_process(false)
 await physics_frame;await settle()
 return scene
func run():
 var scene=await make_scene();var s=scene.get_node("SurvivalWorld");var p=s.player;var ui=p._backpack_ui
 var sm=load("res://scripts/core/SaveManager.gd").get_instance()
 var t:float=s.clock;await create_timer(0.2).timeout;check(s.clock>t,"real process advances authoritative world clock")
 p.set_active(false);t=s.clock;await create_timer(0.2).timeout
 check(s.clock>t and s.ui.hud_panel.visible,"controller deactivation no longer hides time or stops simulation")
 p.set_active(true);p.set_physics_process(false);s.set_process(false)
 var positions=[Vector3(-900,26,1100),Vector3(-400,100,-400),Vector3(-1400,300,600),Vector3(1100,900,-1180)]
 for pos in positions:
  p.global_position=pos;await physics_frame;s._stream_resources()
  var natural=0;var types={}
  for id in s.resources:
   if ":" not in id:continue
   var n=s.resources[id];natural+=1;types[n.item_data.type]=true
   var q=PhysicsRayQueryParameters3D.create(n.global_position+Vector3.UP*0.05,n.global_position-Vector3.UP*0.3,1);q.exclude=[p.get_rid()]
   var hit=p.get_world_3d().direct_space_state.intersect_ray(q)
   if hit.is_empty() or not hit.collider.is_in_group("camp_ground"):check(false,"resource is supported by terrain: "+id)
  check(natural>=30 and types.has("stone") and types.has("brush"),"distributed resources at "+str(pos)+" count="+str(natural))
 # Natural collection persists across cell unload; player drops are streamed back too.
 p.global_position=positions[0];await physics_frame;s._stream_resources()
 var target
 for id in s.resources:
  if ":" in id and s.resources[id].item_data.type=="stone":
   if target==null or p.global_position.distance_to(s.resources[id].global_position)<p.global_position.distance_to(target.global_position):target=s.resources[id]
 var locations={}
 for id in s.resources:
  if ":" in id:locations[id]=s.resources[id].global_position
 var picked_id:String=target.resource_id
 p.global_position=target.global_position+Vector3(0,0.2,1.2);await physics_frame
 p._raycast.target_position=p._raycast.to_local(target.global_position+Vector3.UP*0.12);p._raycast.force_raycast_update()
 check(p._raycast.is_colliding() and p._raycast.get_collider()==target,"natural stone is reached by actual interaction ray")
 await key(KEY_E);await settle()
 check(s.picked.has(picked_id) and Items.count(p.inventory_slots,"stone")>0,"real resource pickup stores finite ID")
 var drop_pos=p.global_position+Vector3(1,0,0);s.drop_resource(Items.item("brush"),drop_pos);var drop_id:String=s.dropped[-1].id
 p.global_position=positions[1];await physics_frame;s._stream_resources();await settle()
 p.global_position=positions[0];await physics_frame;s._stream_resources();await settle()
 var stable_positions=true
 for id in locations:
  if s.resources.has(id) and not s.resources[id].global_position.is_equal_approx(locations[id]):stable_positions=false
 check(stable_positions,"collecting a resource does not shift RNG positions of remaining items")
 check(s.resources.has(drop_id) and not s.resources.has(picked_id),"distance streaming restores drops but never duplicates collected resources")
 # Cabin has no scene swap: compare instances before/after splitting.
 var instance=s.get_instance_id();var hud_id=s.ui.get_instance_id();var outdoor_ids=s.resources.keys()
 p.global_position=s.shelter.to_global(Vector3(0,0.3,1));await physics_frame
 check(not s.begin_rest() and not s.open_sleep(s.shelter.door),"being inside or using a door cannot authorize sleep")
 p._add_to_backpack({"species":"birch","weight":4.0});s.open_backpack();var log_slot=-1
 for i in p.inventory_slots.size():
  if p.inventory_slots[i]!=null and p.inventory_slots[i].type=="log":log_slot=i
 check(s.begin_split(log_slot),"birch log splitting starts inside real cabin");s.advance(10)
 check(Items.count(p.inventory_slots,"firewood")==3,"split produces three authoritative pieces")
 s.close_backpack();s.shelter.bed.sleep_enabled=false
 check(not s.open_sleep(s.shelter.bed),"disabled sleep point cannot open sleep UI")
 s.shelter.bed.sleep_enabled=true
 check(s.open_sleep(s.shelter.bed),"actual bed interaction authorizes contextual sleep panel");await settle()
 check(ui.sleep_page.visible and not ui.tabs.visible and ui.tabs.get_tab_count()==3,"sleep is not a general Tab page")
 s.warmth=80;s.energy=25;s.shelter.set_door(true);t=s.clock
 check(s.begin_rest(1),"bed starts one hour rest");s.advance(1)
 check(absf(s.clock-t-3600)<0.01 and s.energy>25,"bed rest advances same clock and restores fatigue")
 p.global_position=s.shelter.to_global(Vector3(10,0.2,0));await physics_frame;await settle()
 check(not p._is_inventory_open and not s.has_sleep_access() and not s.begin_rest(),"moving away revokes sleep lease and closes UI")
 s.set_process(true);t=s.clock;await create_timer(0.15).timeout;s.set_process(false)
 check(s.get_instance_id()==instance and s.ui.get_instance_id()==hud_id and s.ui.hud_panel.visible and s.clock>t,"exiting cabin preserves HUD instance and advancing clock")
 var retained=0
 for id in outdoor_ids:
  if s.resources.has(id) or s.picked.has(id):retained+=1
 check(retained==outdoor_ids.size(),"cabin split/exit preserves all exterior item identities")
 await key(KEY_TAB);await settle();check(p._is_inventory_open and ui.tabs.current_tab==2 and ui.tabs.visible,"Tab opens live character state first")
 check(ui.condition_values.has("wetness") and ui.condition_values.size()==7,"all actual survival values including wetness live in Tab")
 await key(KEY_ESCAPE);check(not p._is_inventory_open,"Escape closes Tab before pause")
 await key(KEY_ESCAPE);check(paused,"Escape opens true pause");t=s.clock;await create_timer(0.1,true).timeout;check(s.clock==t,"true pause stops world time")
 await key(KEY_ESCAPE);check(not paused,"Escape resumes true pause")
 s.set_process(true);await create_timer(0.1).timeout;s.set_process(false);check(s.clock>t,"clock resumes after pause")
 # Craft through the existing catalog; placement is still a separate validated step.
 Items.transact(p,{},[dict_item("stone",6),dict_item("brush",4)])
 s.open_backpack();ui.select_recipe("camp_kit")
 check(ui.Catalog.reason(p,ui.Catalog.recipe("camp_kit"))=="","campfire remains an ordinary shared catalog recipe")
 var stones=Items.count(p.inventory_slots,"stone");check(s.make_kit(),"shared recipe creates camp kit")
 check(Items.count(p.inventory_slots,"stone")==stones-6,"recipe debits exact resources once")
 var names=[]
 for i in ui.tabs.get_tab_count():names.append(ui.tabs.get_tab_title(i))
 check(not names.has("Костёр") and not names.has("Сон"),"general journal contains no campfire or sleep tabs")
 s.close_backpack()
 # Fault injection protects the last generation; corrupted current file recovers backup.
 check(sm.save_game("bugfix_atomic","manual","Stable"),"initial disk save succeeds")
 var path="user://saves/bugfix_atomic.json";var before=FileAccess.get_file_as_string(path)
 for stage in ["open","write","rename"]:
  sm._test_write_failure_stage=stage;s.matches=7
  check(not sm.save_game("bugfix_atomic"),"write failure "+stage+" returns false")
  check(FileAccess.get_file_as_string(path)==before,"write failure "+stage+" leaves old slot intact")
 sm._test_write_failure_stage="";s.matches=3;check(sm.save_game("bugfix_atomic"),"replacement succeeds after failure")
 var bak=sm._read_save_file(path+".bak");check(not bak.is_empty(),"previous generation is readable backup")
 var f=FileAccess.open(path,FileAccess.WRITE);f.store_string("{truncated");f.close()
 check(not sm._read_save_file(path).is_empty(),"truncated current file recovers previous valid generation")
 sm._is_saving_in_progress=true;check(not sm.save_game("bugfix_atomic"),"reentrant save rejected");sm._is_saving_in_progress=false
 check(not sm.save_game("../escape"),"invalid slot paths are rejected")
 sm.delete_save("bugfix_atomic")
 # Three clean worlds have natural scatter; no static session/pickup leakage.
 scene.queue_free();current_scene=null;await settle()
 for iteration in 2:
  Trees.felled_tree_ids.clear();Trees.damaged_tree_states.clear();load("res://scripts/survival/SurvivalWorld.gd").travel.clear()
  scene=await make_scene();s=scene.get_node("SurvivalWorld");s.set_process(false);s._stream_resources()
  var count=0
  for id in s.resources:
   if ":" in id:count+=1
  check(count>=30 and s.picked.is_empty(),"clean new world "+str(iteration+2)+" has natural resources without inherited collected IDs")
  scene.queue_free();current_scene=null;await settle()
 print("WORLD BUGFIX SUMMARY: %d PASS, %d FAIL"%[passes,failures]);quit(1 if failures else 0)
func dict_item(id:String,count:int)->Dictionary:
 var item=Items.item(id);item.count=count;return item
