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
 add("brush",5);check(s.make_recipe("tinder",3),"craft selected three tinder portions")
 check(Items.count(p.inventory_slots,"brush")==2 and Items.count(p.inventory_slots,"tinder")==3,"batch recipe consumes and yields exact counts")
 check(not s.make_recipe("tinder",0) and not s.make_recipe("tinder",3),"zero and unaffordable craft rejected")
 for i in 3:p._add_to_backpack({"species":"birch","weight":4.0})
 var slot:=-1
 for i in p.inventory_slots.size():
  if p.inventory_slots[i]!=null and p.inventory_slots[i].type=="log":slot=i;break
 s.open_backpack();check(s.begin_split(slot,3),"start three-log split")
 s.advance(29.99);check(Items.count(p.inventory_slots,"log")==3 and Items.count(p.inventory_slots,"firewood")==0,"batch has no premature output")
 s.advance(0.01);check(Items.count(p.inventory_slots,"log")==0 and Items.count(p.inventory_slots,"firewood")==9,"three logs produce nine pieces after thirty real seconds")
 var f:Dictionary=s.Fire.create("batch_fire",Vector3(0,0,2));f.fuel=100000;f.state="burning";s.fires.append(f);s._spawn_fire(f)
 add("raw_water",2);check(s.begin_boil(2),"select one litre from two half-litre portions")
 check(not Items.transact(p,{"raw_water":1}),"boiling reserves raw water against removal")
 s.advance(19.9/60.0);check(Items.count(p.inventory_slots,"raw_water")==2,"one litre remains raw until twenty game seconds")
 s.advance(0.1/60.0);check(Items.count(p.inventory_slots,"raw_water")==0 and Items.count(p.inventory_slots,"water")==2,"one litre completes exactly at twenty game seconds")
 add("raw_water",2);check(s.begin_boil(1),"select only half litre from available litre")
 s.advance(10.0/60.0);check(Items.count(p.inventory_slots,"raw_water")==1 and Items.count(p.inventory_slots,"water")==3,"unselected half litre stays raw")
 check(s.begin_boil(1),"start cancellable boiling");s.cancel_job();check(Items.count(p.inventory_slots,"raw_water")==1,"cancellation preserves reserved water")
 print("SURVIVAL BATCHES SUMMARY: %d PASS, %d FAIL" % [passes,failures])
 p._audio_ui.stop()
 await create_timer(0.1).timeout
 arena.free();current_scene=null
 for i in 3:await process_frame
 quit(1 if failures else 0)
