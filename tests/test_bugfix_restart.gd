extends SceneTree
const Trees=preload("res://scripts/props/TreeChoppable.gd")
var passes:=0
var failures:=0
var s
var p
func _initialize():call_deferred("run")
func check(ok:bool,text:String):
 if ok:passes+=1;print("PASS: ",text)
 else:failures+=1;print("FAIL: ",text)
func settle(n:int=5):
 for i in n:await process_frame
func idle(tree):
 var end=Time.get_ticks_msec()+20000
 while is_instance_valid(tree) and tree._voxel_trunk.is_busy() and Time.get_ticks_msec()<end:await create_timer(0.005).timeout
func freeze_scene():
 p=current_scene.get_node("Player");s=current_scene.get_node("SurvivalWorld");p.set_physics_process(false);s.set_process(false);s.set_physics_process(false)
func run():
 var sm=load("res://scripts/core/SaveManager.gd").get_instance()
 var writing="--write" in OS.get_cmdline_user_args()
 if writing:
  var scene=load("res://scenes/viewer/MapViewer.tscn").instantiate();root.add_child(scene);current_scene=scene
  await physics_frame;await settle();freeze_scene();s._physics_ready=true;s._stream_resources()
  # Gather actual spawned natural resources, not a gift pile at spawn.
  var stones=0;var brush=0
  for id in s.resources.keys():
   var item=s.resources[id]
   if ":" not in id:continue
   if item.item_data.type=="stone" and stones<6:item.survival_interact();stones+=1
   elif item.item_data.type=="brush" and brush<4:item.survival_interact();brush+=1
  check(stones==6 and brush==4,"six natural stones and four brush collected for real recipe")
  var world=scene.get_node("WorldMap");var tree=world._interactive_trees.tree_055432
  var hits=0
  while not tree._is_falling and hits<40:
   tree.hit(1,tree.to_global(Vector3(0,1.3,0.3)),tree.to_global(Vector3(0,1.3,3)));await idle(tree);hits+=1
  check(tree._is_falling,"actual authored birch was felled")
  await create_timer(2.5).timeout
  var logs=get_nodes_in_group("pickup_logs");check(logs.size()==3,"felled tree produces three real world logs")
  p._collect_log(logs[0]);await settle()
  p.global_position=s.shelter.to_global(Vector3(0,0.3,1));await physics_frame
  s.open_backpack();var log_slot=-1
  for i in p.inventory_slots.size():
   if p.inventory_slots[i]!=null and p.inventory_slots[i].type=="log":log_slot=i
  check(s.begin_split(log_slot),"real harvested birch log splits inside cabin");s.advance(10)
  check(s.Items.count(p.inventory_slots,"firewood")==3,"harvested log gives three pieces")
  for i in p.inventory_slots.size():
   if p.inventory_slots[i]!=null and p.inventory_slots[i].type=="firewood":p._selected_slot_index=i;p.drop_selected_amount(1);break
  s.close_backpack();p.global_position=Vector3(-900,26,1100);await physics_frame
  s.open_backpack();check(s.make_kit(),"campfire recipe consumes naturally gathered materials")
  s.close_backpack()
  var target=p.global_position+Vector3(3,0,2)
  var hit=p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(target+Vector3.UP*5,target-Vector3.UP*5,1))
  s.begin_placement();s.placement=s.validate_placement(hit.position,hit.normal,hit.collider)
  check(s.confirm_placement(),"real terrain accepts crafted campfire placement")
  # Leave another actual tree partially cut, with species-specific material.
  var beech=world._interactive_trees.tree_055434
  beech.hit(1,beech.to_global(Vector3(0,1.3,0.5)),beech.to_global(Vector3(0,1.3,3)));await idle(beech)
  check(Trees.damaged_tree_states.has("tree_055434"),"standing beech damage registered before save")
  # A scene trip must retain exterior geometry and physical log snapshots.
  s.prepare_travel();change_scene_to_file("res://scenes/mine/MineInterior.tscn");await settle(10);freeze_scene()
  check(s._old_felled.has("tree_055432") and s._old_logs.size()==2,"mine retains exterior felled tree and two log snapshots")
  check(s._old_damaged.has("tree_055434"),"mine retains exterior standing beech cuts")
  s.prepare_travel();change_scene_to_file("res://scenes/viewer/MapViewer.tscn");await settle(10);freeze_scene()
  check(Trees.felled_tree_ids.has("tree_055432") and Trees.damaged_tree_states.has("tree_055434") and get_nodes_in_group("pickup_logs").size()==2,"forest return restores felled tree, partial damage and remaining logs")
  s.matches=8;s.body.food=57;s.body.water=62;s.clock=70000
  p.global_position=s.shelter.to_global(Vector3(0,0.3,1));await physics_frame
  p.global_position=s.shelter.to_global(Vector3(0,0.3,4));await physics_frame
  check(sm.save_game("bugfix_restart","manual","Restart acceptance"),"scenario E saves successfully")
  check(sm.save_game("bugfix_restart"),"scenario E overwrites same slot successfully")
  print("RESTART WRITE PROFILE: ",JSON.stringify(sm.last_save_profile))
 else:
  scene_changed.connect(freeze_scene)
  var t=Time.get_ticks_usec();check(sm.load_game("bugfix_restart"),"fresh process reads previously written slot")
  await settle(15);var elapsed=Time.get_ticks_usec()-t
  freeze_scene();var world=current_scene.get_node("WorldMap")
  check(s.fires.size()==1 and s.fire_nodes.size()==1,"fresh process restores exactly one installed campfire")
  check(Trees.felled_tree_ids.has("tree_055432"),"fresh process retains felled authored birch")
  check(get_nodes_in_group("pickup_logs").size()==2,"fresh process restores two uncollected physical logs")
  check(s.dropped.size()==1 and s.dropped[0].item.type=="firewood" and s.resources.has(s.dropped[0].id),"fresh process restores cabin-dropped split firewood")
  check(s.picked.size()==10,"fresh process retains ten collected natural resource identities")
  check(s.matches==8 and absf(s.clock-70000)<0.001 and s.body.food==57 and s.body.water==62,"fresh process restores exact body and time snapshot")
  var beech=world._interactive_trees.get("tree_055434")
  if is_instance_valid(beech):await idle(beech)
  check(is_instance_valid(beech) and beech._voxel_trunk.export_cuts().size()>0,"fresh process reconstructs partially damaged beech geometry")
  # In-place older slot load removes old stumps instead of accumulating them.
  var payload=sm._read_save_file("user://saves/bugfix_restart.json");payload.world.felled_tree_ids={};payload.world.damaged_trees={};sm._apply_loaded_state(payload);await settle()
  check(world._interactive_trees.has("tree_055432") and get_nodes_in_group("permanent_stumps").is_empty(),"loading an older uncut state removes remnants and restores standing tree")
  print("RESTART LOAD TOTAL US: ",elapsed)
  sm.delete_save("bugfix_restart")
 current_scene.queue_free();current_scene=null;await settle(12)
 print("RESTART %s SUMMARY: %d PASS, %d FAIL"%["WRITE" if writing else "READ",passes,failures]);quit(1 if failures else 0)
