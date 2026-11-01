extends SceneTree
const Items=preload("res://scripts/survival/SurvivalItems.gd")
var passes:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,text:String)->void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func settle(n:int=4)->void:
 for i in n:await physics_frame;await process_frame
func run()->void:
 var world=load("res://scenes/viewer/MapViewer.tscn").instantiate();root.add_child(world);current_scene=world
 var p=world.get_node("Player");p.set_physics_process(false)
 var s=world.get_node("SurvivalWorld");s.set_process(false);await settle(6)
 check(s.water_sources.size()==3,"three persistent raw-water sources spawn on actual forest terrain")
 for source in s.water_sources:
  var at:Vector3=source.global_position
  var ground=p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*2,at-Vector3.UP*2,1))
  check(not ground.is_empty() and absf(ground.position.y-at.y)<0.04,str(source.name)+" is grounded, not floating")
  p.global_position=at+Vector3(0,0.1,1.9);await settle(2)
  check(source.can_collect(),str(source.name)+" is reachable from bank")
  var before:int=Items.count(p.inventory_slots,"raw_water")
  source.survival_interact();source.survival_interact()
  check(Items.count(p.inventory_slots,"raw_water")==before+1,"one interaction yields 0.5 l raw only; cooldown blocks immediate repeat")
  s.map_model.explore(Vector2(at.x,at.z))
  check(s.map_model.discovered.has(str(source.data.id)),"exploration discovers source on map")
  p.global_position=at+Vector3(10,0,0);s.clock+=61
  check(not source.can_collect(),"cannot collect water remotely")
 var source=s.water_sources[0] if not s.water_sources.is_empty() else null
 if source!=null:
  p.global_position=source.global_position+Vector3(0,0.1,1.9);await settle(2)
  var before:int=Items.count(p.inventory_slots,"water")
  var raw_slot:=-1
  for i in p.inventory_slots.size():
   if p.inventory_slots[i]!=null and p.inventory_slots[i].type=="raw_water":raw_slot=i;break
  check(raw_slot>=0 and not s.use_supply(raw_slot) and Items.count(p.inventory_slots,"water")==before,"source water cannot be drunk or bypass boiling")
  var f:Dictionary=s.Fire.create("qa_source_fire",p.global_position+Vector3.RIGHT*2);f.state="burning";f.fuel=10000;s.fires.append(f);s._spawn_fire(f);s.selected_fire=f.id
  check(s.begin_boil(1),"gathered water enters existing boiling workflow")
  s.advance(10.0/60.0)
  check(Items.count(p.inventory_slots,"water")==before+1,"0.5 litre becomes safe after ten game seconds")
  var saved:Array=p.inventory_slots.duplicate(true)
  for i in p.inventory_slots.size():
   var stone:=Items.item("stone");stone.count=10;p.inventory_slots[i]=stone
  source.next_draw_clock=-1
  source.survival_interact();check(Items.count(p.inventory_slots,"raw_water")==0 and source.next_draw_clock==-1,"full backpack does not consume source cooldown or create hidden water")
  p.inventory_slots=saved;s.health=0;check(not source.can_collect(),"dead player cannot collect")
  s.health=100;s.location="mine";check(not source.can_collect(),"forest source unavailable from mine");s.location="forest"
  await s._setup_water_sources();check(s.water_sources.size()==3,"reinitialization cannot duplicate sources")
 print("WATER SOURCES SUMMARY: %d PASS, %d FAIL" % [passes,failures])
 world.free();current_scene=null;await settle();quit(1 if failures else 0)
