extends SceneTree
const Catalog=preload("res://scripts/vegetation/VegetationCatalog.gd")
const Trees=preload("res://scripts/props/TreeChoppable.gd")
var passes:=0
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,text:String):
 if ok:passes+=1;print("PASS: ",text)
 else:failures+=1;print("FAIL: ",text)
func settle(n:int=4):
 for i in n:await process_frame
func stop_scene():
 if current_scene:
  var p=current_scene.get_node_or_null("Player");var s=current_scene.get_node_or_null("SurvivalWorld")
  if p:p.set_physics_process(false)
  if s:s.set_process(false)
func key(code:Key):
 for pressed in [true,false]:
  var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=pressed;root.push_input(e,true);await process_frame
func find_slot(p,id:String) -> int:
 for i in p.inventory_slots.size():
  if p.inventory_slots[i]!=null and p.inventory_slots[i].type==id:return i
 return -1
func run():
 scene_changed.connect(stop_scene)
 var sm=load("res://scripts/core/SaveManager.gd").get_instance()
 if "--load" in OS.get_cmdline_user_args():
  check(sm.load_game("vegetation_restart_qa"),"saved vegetation accepted in independent process")
  await settle(20);stop_scene();var s=current_scene.get_node("SurvivalWorld");var v=s.vegetation
  check(v.harvested.has("restart_marker:0") and v.inspected.has("stump_fan"),"harvest and field-guide discovery survive actual process restart")
  check(s.body.conditions.has("poison") and float(s.body.conditions.poison.delay)>90,"delayed toxin not reset by process restart")
  check(v.stumps.has("persistent_stump") and float(v.stumps.persistent_stump.start)<s.clock,"stump cycle retains true origin after restart")
  check(v.seed_value==Catalog.SEED and v.placement_version==1,"seed and placement version persisted through disk envelope")
  sm.delete_save("vegetation_restart_qa");current_scene.free();current_scene=null;await settle();print("VEGETATION RESTART SUMMARY: %d PASS, %d FAIL"%[passes,failures]);quit(1 if failures else 0);return
 var scene=load("res://scenes/viewer/MapViewer.tscn").instantiate();root.add_child(scene);current_scene=scene;stop_scene();await physics_frame;await settle()
 var s=scene.get_node("SurvivalWorld");var p=s.player;var v=s.vegetation
 v.set_physics_process(false)
 var profile:Array=[]
 for i in 14:
  v.stream();profile.append(v.last_profile.stream_us);await physics_frame
 var records:Array=[]
 for rs in v.patches.values():records.append_array(rs)
 print("PROFILE: ",JSON.stringify({"records":records.size(),"profiles_us":profile,"interactive":v.active.size(),"cells":v.cells.size(),"state_bytes":JSON.stringify(v.export_state()).length()}))
 check(records.size()>0 and v.cells.size()==25,"real terrain prepares sparse deterministic patches under streaming budget")
 check(v.active.size()<=96,"interactive collider budget respected")
 var mmi_count:=0
 for root_cell in v.cells.values():
  for n in root_cell.get_children():
   if n is MultiMeshInstance3D:mmi_count+=1
 check(mmi_count>0,"non-interactive distant vegetation batched as MultiMesh")
 var target
 for r in records:
  if Catalog.species(r.species).family=="berry":target=r;break
 check(target!=null,"actual starting route contains berry bushes")
 if target!=null:
  p.global_position=s._v3(target.pos)+Vector3(0,0.1,1.5);await physics_frame;v.stream();await physics_frame
  var plant=v.active.get(target.id)
  p._raycast.target_position=p._raycast.to_local(plant.global_position+Vector3.UP*0.45);p._raycast.force_raycast_update()
  check(p._raycast.is_colliding() and p._raycast.get_collider()==plant,"plant reachable with real E ray and terrain collision")
  p.inventory_slots.fill(null);s.Items.refresh(p)
  var before:int=v.remaining(target);await key(KEY_E)
  check(s.job.get("kind")=="harvest","real E begins existing timed job, not instant proximity pickup")
  s.advance(0.7);check(v.remaining(target)==before-1 and s.Items.count(p.inventory_slots,target.species)==1,"one group issued atomically and disappears")
  var size:int=v.harvested.size();s.advance(1)
  check(v.harvested.size()==size,"holding/elapsed time alone cannot repeat harvest")
  await key(KEY_E);p.global_position+=Vector3(2,0,0);s.advance(0.2)
  check(s.job.is_empty() and v.harvested.size()==size,"movement cancels harvest without losing crop")
  p.global_position-=Vector3(2,0,0);await physics_frame;p._raycast.force_raycast_update();await key(KEY_E);await key(KEY_TAB)
  check(s.job.is_empty() and p._is_inventory_open,"opening backpack cancels short collection")
  await key(KEY_TAB)
  for i in p.inventory_slots.size():var item=s.Items.item("stone");item.count=10;p.inventory_slots[i]=item
  s.Items.refresh(p);await key(KEY_E);s.advance(0.7)
  check(v.harvested.size()==size,"full backpack leaves remaining berry cluster intact")
  var snapshot:Dictionary=JSON.parse_string(JSON.stringify(v.export_state()));v.import_state(snapshot)
  check(v.remaining(target)==before-1,"collection survives unloading visual nodes and JSON state import")
 # Actual unknown-food modal, including Escape and keyboard inventory guard.
 p.inventory_slots.fill(null);s.Items.refresh(p);s.Items.transact(p,{},[s.Items.item("pale_bell")]);v.known.erase("pale_bell");s.open_backpack()
 s.request_use_supply(find_slot(p,"pale_bell"));await settle()
 check(get_first_node_in_group("menu_confirmation")!=null,"unknown mushroom opens explicit real confirmation dialog")
 await key(KEY_ESCAPE)
 check(p._is_inventory_open and s.Items.count(p.inventory_slots,"pale_bell")==1,"Escape cancels unknown-food confirmation without consuming or closing journal")
 s.request_use_supply(find_slot(p,"pale_bell"));await settle();var dlg=get_first_node_in_group("menu_confirmation")
 if dlg:dlg._on_confirm()
 await settle();check(s.Items.count(p.inventory_slots,"pale_bell")==0 and s.body.conditions.has("poison"),"explicit confirmed consumption applies real delayed toxin")
 s.Items.transact(p,{},[s.Items.item("antitoxin")]);s.use_supply(find_slot(p,"antitoxin"));s.close_backpack()
 check(not s.body.conditions.has("poison"),"normal medical use clears toxin without loading or Dev Menu")
 # Notes do not require an empty inventory slot.
 var notes=s.resources.get("camp_supply_9")
 if is_instance_valid(notes):notes.survival_interact()
 check(v.known.has("pale_bell") and s.picked.has("camp_supply_9"),"finite camp note teaches dangerous species without eating poison")
 check(s.resources.has("camp_supply_7") and s.resources.camp_supply_7.item_data.type=="antitoxin","treatment accessible before poisonous mushrooms enabled")
 p.inventory_slots.fill(null);s.Items.refresh(p)
 # An existing real campfire: no separate cooking station/inventory.
 p.global_position=s.shelter.global_position+Vector3(5,0,5);await physics_frame
 var fire=s.Fire.create("veg_test_fire",p.global_position+Vector3(1,0,0));fire.state="burning";fire.fuel=7200;s.fires.append(fire);s._spawn_fire(fire);s.selected_fire=fire.id;await physics_frame
 check(s._fire_in_reach(fire),"real cooking fire in reach and unoccluded")
 s.Items.transact(p,{},[s.Items.item("stump_fan"),s.Items.item("water")]);s.open_backpack(fire.id)
 check(s.foraging.begin_cook("wood_tea",1),"tea begins through existing context job")
 s.advance(2);s.cancel_job()
 check(s.Items.count(p.inventory_slots,"water")==1 and s.Items.count(p.inventory_slots,"wood_tea")==0,"cancellation keeps safe water and fungus, gives no tea")
 s.foraging.begin_cook("wood_tea",1);fire.state="cold";s.advance(0.1)
 check(s.job.is_empty() and s.Items.count(p.inventory_slots,"stump_fan")==1,"fire extinguishing immediately cancels cooking without item loss")
 fire.state="burning";check(s.foraging.begin_cook("wood_tea",1),"cooking can restart after fire relit");s.advance(5)
 check(s.Items.count(p.inventory_slots,"wood_tea")==1 and s.Items.count(p.inventory_slots,"water")==0 and s.Items.count(p.inventory_slots,"stump_fan")==0,"five game minutes commits real tea recipe exactly once")
 s.body.stamina=10;s.energy=12;s.body.conditions.sprain={"remaining":120};var energy:float=s.energy
 check(s.use_supply(find_slot(p,"wood_tea")) and s.body.stamina==35 and s.energy==energy and s.body.conditions.has("sprain"),"actual tea use restores short stamina only")
 s.close_backpack()
 # Accelerated sleep uses exactly the same poison integration, and wakes at active symptoms.
 p.global_position=s.shelter.bed.global_position+Vector3(0,0,0.35);await physics_frame;s.warmth=80;s.body.food=100;s.body.water=100;s.shelter.set_door(true);s.body.add_poison("severe")
 check(s.open_sleep(s.shelter.bed) and s.begin_rest(3),"sleep can begin during saved delayed poison, before active symptoms")
 var sleep_hp:float=s.health;s.advance(2.1)
 check(s.job.is_empty() and s.body.poison_active() and s.health<sleep_hp,"poison onset during accelerated sleep applies damage and interrupts rest")
 s.close_backpack();s.body.conditions.erase("poison")
 # Real existing fracture creates persistent stump and immediately registers zero-age growth.
 var tree:Node3D
 for n in get_nodes_in_group("choppable_trees"):
  if Catalog.eligible(n.get_effective_id()):tree=n;break
 if not is_instance_valid(tree):
  var world=scene.get_node("WorldMap");var nearest:=INF;var chosen:Dictionary={}
  for r in world._all_trees_data:
   if not Catalog.eligible(str(r.id)):continue
   var pos:=Vector3(float(r.pos[0]),float(r.pos[2]),-float(r.pos[1]));var distance:=pos.distance_squared_to(p.global_position)
   if distance<nearest:nearest=distance;chosen=r
  if not chosen.is_empty():
   var pos:=Vector3(float(chosen.pos[0]),float(chosen.pos[2]),-float(chosen.pos[1]))
   world._activate_dynamic_tree(chosen,pos);tree=world._dynamic_trees.get(chosen.id)
 check(is_instance_valid(tree),"eligible existing tree available for real fracture")
 if is_instance_valid(tree):
  var id:String=tree.get_effective_id();p.global_position=tree.global_position+Vector3(0,0,2);await physics_frame
  tree._voxel_trunk.request_fracture(0.65)
  var deadline:=Time.get_ticks_msec()+20000
  while not Trees.felled_tree_ids.has(id) and Time.get_ticks_msec()<deadline:await create_timer(0.01).timeout
  await settle(6)
  check(Trees.felled_tree_ids.has(id) and v.stumps.has(id) and not v.ready(v.stumps[id]),"actual cutting records permanent ID and no immediate fungi")
  s.clock+=Catalog.FIRST_GROWTH;v.advance(Catalog.FIRST_GROWTH,true);v._update_stumps(p.global_position)
  check(v.stump_nodes.size()>0,"mature fungi attached to actual fractured stump surface")
  for n in v.stump_nodes.values():check(n.get_parent().is_in_group("permanent_stumps") and n.position.is_finite(),"fungus physically parented to real stump, not floating world node")
  var node=v.stump_nodes.values()[0];var r:Dictionary=node.record
  check(v.mask(r)==0,"mature group has one available crop")
  var crop:int=v.stumps[id].crop
  p.inventory_slots.fill(null);s.Items.refresh(p)
  for index in crop:
   var key_id:="stump:"+id+":"+str(index);var fungus=v.stump_nodes.get(key_id)
   if not is_instance_valid(fungus):check(false,"mature harvest group exists");continue
   var outward:Vector3=fungus.global_position-tree.global_position;outward.y=0;outward=outward.normalized()
   p.global_position=tree.global_position+outward*1.6;await physics_frame
   p._raycast.target_position=p._raycast.to_local(fungus.global_position+Vector3.UP*0.13);p._raycast.force_raycast_update()
   var count_before:int=s.Items.count(p.inventory_slots,"stump_fan")
   fungus.survival_interact();s.advance(0.7)
   check(s.Items.count(p.inventory_slots,"stump_fan")==count_before+1,"individual real stump group harvested once")
  check(int(v.stumps[id].cycle)==1 and not v.ready(v.stumps[id]),"last harvested group starts five-day regrowth, not immediate refill")
  var next_delay:float=v.stumps[id].delay
  s.clock=float(v.stumps[id].start)+next_delay-1;v.advance(next_delay-1,true)
  check(not v.ready(v.stumps[id]),"regrowth respects full five-day minimum")
  s.clock+=1;v.advance(1,true)
  check(v.ready(v.stumps[id]) and int(v.stumps[id].crop)<=3,"regrowth yields at most one bounded crop")
  s.clock+=100*86400;v.advance(100*86400,true)
  check(int(v.stumps[id].cycle)==1 and int(v.stumps[id].crop)<=3,"long absence cannot accumulate a backlog of harvests")
 # Pause never advances Director humidity or poison because there are no autonomous timers.
 var wet:float=v.humid_clock;var clock:float=s.clock;paused=true;await create_timer(0.1,true).timeout;check(v.humid_clock==wet and s.clock==clock,"true pause stops world and growth clocks");paused=false
 v.harvested["restart_marker:0"]=true;v.inspect("stump_fan");v.record_felling("persistent_stump");s.clock+=60;s.body.add_poison("severe")
 check(sm.save_game("vegetation_restart_qa","manual","Vegetation restart QA"),"real SaveManager writes unified vegetation/body state")
 var saved_delay:float=s.body.conditions.poison.delay
 s.prepare_travel();change_scene_to_file("res://scenes/mine/MineInterior.tscn");await settle(15);stop_scene()
 var mine=current_scene.get_node("SurvivalWorld")
 check(mine.vegetation.harvested.has("restart_marker:0") and mine.vegetation.stumps.has("persistent_stump"),"forest to mine retains crop and stump cycles")
 check(mine.body.conditions.has("poison") and float(mine.body.conditions.poison.delay)<=saved_delay,"scene travel does not reset poison delay")
 mine.prepare_travel();change_scene_to_file("res://scenes/viewer/MapViewer.tscn");await settle(15);stop_scene()
 var forest=current_scene.get_node("SurvivalWorld")
 check(forest.vegetation.harvested.has("restart_marker:0") and forest.picked.has("camp_supply_9"),"mine round trip never restores collected crop or note")
 check(forest.vegetation.stumps.has("persistent_stump"),"round trip preserves growth start, not new tree timer")
 current_scene.free();current_scene=null;await settle();print("VEGETATION WORLD SUMMARY: %d PASS, %d FAIL"%[passes,failures]);quit(1 if failures else 0)
