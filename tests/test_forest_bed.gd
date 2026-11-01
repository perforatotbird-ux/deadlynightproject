extends SceneTree
const Session=preload("res://scripts/survival/SurvivalWorld.gd")
const Items=preload("res://scripts/survival/SurvivalItems.gd")
var passes:=0
var failures:=0
var arena:Node3D
var p:Node3D
var s:Node
func check(ok:bool,text:String)->void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func add(id:String,amount:int)->void:
 var output:=Items.item(id);output.count=amount
 check(Items.transact(p,{},[output]),"add "+id)
func _initialize()->void:call_deferred("run")
func run()->void:
 arena=Node3D.new();arena.name="MapViewer";root.add_child(arena);current_scene=arena
 var ground:=StaticBody3D.new();ground.add_to_group("camp_ground");var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(200,1,200);col.shape=shape;ground.add_child(col);ground.position.y=-0.5;arena.add_child(ground)
 p=load("res://scenes/player/Player.tscn").instantiate();arena.add_child(p);p.set_active(true);p.set_physics_process(false);p.position=Vector3(0,0.1,0)
 s=Session.new();arena.add_child(s);s.set_process(false)
 await physics_frame
 check(not s.make_recipe("forest_bed"),"bed cannot be crafted without materials")
 s.record_tree_felling("spruce_test","spruce",Vector3(12,0,12))
 check(s.dropped.size()==1 and s.dropped[0].item.type=="spruce_needles" and s.dropped[0].item.count==10,"felled spruce drops ten needles into the world")
 s.record_tree_felling("spruce_test","spruce",Vector3(12,0,12));check(s.dropped.size()==1,"repeated felling event cannot duplicate needles")
 s.record_tree_felling("birch_test","birch",Vector3(14,0,12));check(s.dropped.size()==1,"birch does not drop spruce needles")
 add("brush",20);add("spruce_needles",10)
 check(s.make_recipe("forest_bed"),"twenty branches and ten needles craft bed")
 check(Items.count(p.inventory_slots,"brush")==0 and Items.count(p.inventory_slots,"spruce_needles")==0 and Items.count(p.inventory_slots,"forest_bed")==1,"recipe consumes exact inputs once")
 s.begin_placement("forest_bed");s.placement={"ok":true,"pos":[0,0,3]}
 check(s.confirm_placement(),"bed places on actual level ground")
 check(s.forest_beds.size()==1 and s.bed_nodes.size()==1 and Items.count(p.inventory_slots,"forest_bed")==0,"placement consumes one kit and creates one persistent bed")
 check(not s.confirm_placement(),"double placement cannot duplicate bed")
 p.position=Vector3(0,0.1,1);await physics_frame
 var bed=s.bed_nodes[0]
 check(s.open_sleep(bed) and s.on_forest_bed(),"E-equivalent interaction grants outdoor bed sleep access")
 s.body.freeze_needs=true;s.warmth=80
 check(s.begin_rest(8),"eight hours of sleep allowed without a cabin door")
 var saved:Dictionary=JSON.parse_string(JSON.stringify(s.export_state()));var id:String=bed.data.id
 s.cancel_job();s.import_state(saved);s.set_process(false)
 check(s.job.get("kind")=="rest" and s.job.get("bed_id")==id and s.on_forest_bed(),"save/load resumes bed sleep without resetting bed")
 s.body.freeze_needs=true;s.advance(8)
 check(s.job.is_empty() and bool(s.forest_beds[0].spent),"completed night wears out temporary bed")
 check(not s.bed_nodes[0].can_interact(p) and not s.open_sleep(s.bed_nodes[0]),"spent bed cannot be reused")
 var spent:Dictionary=JSON.parse_string(JSON.stringify(s.export_state()));s.import_state(spent)
 check(bool(s.forest_beds[0].spent) and not s.bed_nodes[0].sleep_enabled,"bed exhaustion survives reload")
 check(s.needle_trees.has("spruce_test"),"needle drop deduplication survives reload")
 # Interrupted sleep also wears the bed once actual sleep time elapsed.
 var second:={"id":"interrupted_bed","pos":[3,0,1],"spent":false};s.forest_beds.append(second);s._spawn_bed(second)
 p.position=Vector3(3,0.1,-1);await physics_frame
 check(s.open_sleep(s.bed_nodes[-1]),"second bed opens")
 s.warmth=80;s.body.freeze_needs=true;check(s.begin_rest(2),"interrupted bed starts sleep")
 s.advance(0.1);s.cancel_job();check(bool(second.spent),"partial sleep cannot be exploited for unlimited uses")
 check(preload("res://scripts/ui/JournalArt.gd").texture("forest_bed")!=null and preload("res://scripts/ui/JournalArt.gd").texture("spruce_needles")!=null,"new items have existing compatible artwork")
 print("FOREST BED SUMMARY: %d PASS, %d FAIL" % [passes,failures])
 p._audio_ui.stop()
 await create_timer(0.1).timeout
 arena.free();current_scene=null
 for i in 3:await process_frame
 quit(1 if failures else 0)
