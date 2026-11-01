extends SceneTree
const Items=preload("res://scripts/survival/SurvivalItems.gd")
var passes:=0
var failures:=0
var p:Node3D
var s:Node
func _initialize()->void:call_deferred("run")
func check(ok:bool,text:String)->void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func add(id:String,n:int)->void:
 var item:=Items.item(id);item.count=n;check(Items.transact(p,{},[item]),"add "+id)
func run()->void:
 var arena:=Node3D.new();arena.name="MapViewer";root.add_child(arena);current_scene=arena
 var ground:=StaticBody3D.new();ground.add_to_group("camp_ground");var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,1,100);col.shape=box;ground.position.y=-0.5;ground.add_child(col);arena.add_child(ground)
 p=load("res://scenes/player/Player.tscn").instantiate();arena.add_child(p);p.set_active(true);p.set_physics_process(false);p.position=Vector3(0,0.1,0)
 s=load("res://scripts/survival/SurvivalWorld.gd").new();arena.add_child(s);s.set_process(false);await physics_frame
 for i in 3:p._add_to_backpack({"species":"birch","weight":4.0})
 var slot:=-1
 for i in p.inventory_slots.size():
  if p.inventory_slots[i]!=null and p.inventory_slots[i].type=="log":slot=i;break
 s.open_backpack();check(s.begin_split(slot,3),"three-log task starts with 30 real seconds")
 check(s.job.duration==30,"batch duration remains 30 real seconds")
 s.advance(5);s.close_backpack()
 check(not p._is_inventory_open and not s.job.is_empty(),"closing craft UI preserves pending task")
 p.position.x+=12;s.advance(10)
 check(not s.job.is_empty() and s.job.elapsed==15,"movement does not cancel background splitting")
 var state:Dictionary=s.export_state();s.cancel_job();s.import_state(state)
 check(s.job.kind=="split" and s.job.elapsed==15,"save/load preserves elapsed background time")
 if p._is_inventory_open:p._toggle_inventory()
 s.ui.refresh();check(s.ui.context_label.text.contains("Раскол"),"progress is visible outside crafting menu")
 check(not s.begin_split(slot,1),"second task cannot duplicate reserved ingredients")
 s.advance(14.99);check(Items.count(p.inventory_slots,"firewood")==0,"no early batch completion")
 s.advance(0.01);check(Items.count(p.inventory_slots,"log")==0 and Items.count(p.inventory_slots,"firewood")==9,"batch completes while walking with UI closed")
 p._add_to_backpack({"species":"birch","weight":4.0});s.open_backpack()
 for i in p.inventory_slots.size():
  if p.inventory_slots[i]!=null and p.inventory_slots[i].type=="log":slot=i;break
 check(s.begin_split(slot),"another task starts after completion")
 s.cancel_job();check(Items.count(p.inventory_slots,"log")==1,"explicit cancel still keeps ingredients")
 print("BACKGROUND CRAFT SUMMARY: %d PASS, %d FAIL" % [passes,failures])
 p._audio_ui.stop()
 await create_timer(0.1).timeout
 arena.free();current_scene=null
 for i in 3:await process_frame
 quit(1 if failures else 0)
