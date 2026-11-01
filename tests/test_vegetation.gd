extends SceneTree
const Catalog=preload("res://scripts/vegetation/VegetationCatalog.gd")
const Patch=preload("res://scripts/vegetation/VegetationPatch.gd")
const Body=preload("res://scripts/survival/BodyModel.gd")
const Items=preload("res://scripts/survival/SurvivalItems.gd")
const Director=preload("res://scripts/vegetation/VegetationDirector.gd")
const Actions=preload("res://scripts/vegetation/ForagingActions.gd")
const Visuals=preload("res://scripts/vegetation/VegetationVisuals.gd")
var passes:=0
var failures:=0
class FakePlayer extends Node:
 var inventory_slots:Array=[]
 var backpack_weight:=0.0
 var backpack_items:Array=[]
 var survival:Node
 func _refresh_belt_labels():pass
 func _update_inventory_hud():pass
 func _refresh_inventory_ui():pass
class FakeSession extends Node:
 var energy:=80.0
 var warmth:=60.0
 var clock:=57600.0
 var location:="mine"
 var _old_felled:Dictionary={}
 var job:Dictionary={}
 var body=Body.new()
 var vegetation:Node
 var foraging=Actions.new()
 var player:Node
 var message:=""
 func notify(text):message=text
func _initialize():call_deferred("run")
func check(ok:bool,text:String):
 if ok:passes+=1;print("PASS: ",text)
 else:failures+=1;print("FAIL: ",text)
func run():
 var s:=FakeSession.new();root.add_child(s);s.player=FakePlayer.new();s.add_child(s.player);s.player.survival=s;s.player.inventory_slots.resize(16);s.foraging.session=s
 var v:=Director.new();v.session=s;s.add_child(v);s.vegetation=v
 check(Catalog.SPECIES.size()==8,"exactly three berries and five fungi")
 for id in Catalog.SPECIES:
  var d:Dictionary=Catalog.species(id);var item:=Items.item(id)
  check(not item.is_empty() and float(item.unit_weight)>0 and item.type==id,"real weighted item: "+id)
  var mesh:=Visuals.mesh(id)
  check(mesh!=null and mesh.get_surface_count()==1 and mesh.get_aabb().size.length()>0,"actual distinguishable mesh: "+id)
 check(Visuals.mesh("stump_fan").get_aabb().size!=Visuals.mesh("wood_fan").get_aabb().size,"tea fungus differs from food fan by tiers and silhouette, not only colour")
 check(Visuals.mesh("forest_fat").get_aabb().size!=Visuals.mesh("pale_bell").get_aabb().size,"mushroom silhouette differs beyond colour")
 check(Visuals.mesh("krasnitsa").get_aabb().size.y!=Visuals.mesh("bolotnitsa").get_aabb().size.y,"low trailing berry bush has distinct silhouette")
 var full:int=Visuals.mesh("krasnitsa",0).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
 check(Visuals.mesh("krasnitsa",1).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()<full,"one picked berry cluster disappears, bush remains")
 var a:=Patch.candidates(Vector2i(-19,22),Catalog.SEED,1);var b:=Patch.candidates(Vector2i(-19,22),Catalog.SEED,1)
 check(str(a)==str(b),"placement stable across recreation")
 check(a[0].id.begins_with("veg1:-19:22:0:"),"ID includes placement version, cell, patch, plant")
 check(Items.item("berries").type=="berries","legacy berry slots retain compatibility")
 v.import_state({}, {"-38:44:10":true})
 check(v._legacy_blocked(Vector2i(-19,22)),"legacy consumed berry excludes whole corresponding new patch cell")
 var tree_id:=""
 for i in 100:
  if Catalog.eligible("tree_"+str(i)):tree_id="tree_"+str(i);break
 v.record_felling(tree_id);var stump:Dictionary=v.stumps[tree_id]
 check(not v.ready(stump),"fresh player-felled stump has no fungi")
 s.clock+=Catalog.FIRST_GROWTH-1;v.advance(Catalog.FIRST_GROWTH-1,true)
 check(not v.ready(stump),"rain cannot bypass two-day minimum")
 s.clock+=1;v.advance(1,true);check(v.ready(stump),"two game days produces bounded crop")
 var saved:Dictionary=JSON.parse_string(JSON.stringify(v.export_state()));var v2:=Director.new();v2.session=s;s.add_child(v2);v2.import_state(saved)
 check(v2.ready(v2.stumps[tree_id]) and int(v2.stumps[tree_id].crop)<=3,"growth survives JSON round trip, crop capped at three")
 var dry:=Director.new();dry.session=s;s.add_child(dry);dry.record_felling(tree_id);s.clock+=Catalog.FIRST_GROWTH;dry.advance(Catalog.FIRST_GROWTH,false)
 check(dry.ready(dry.stumps[tree_id]),"first crop grows after two days even without rain")
 s._old_felled={"old_stump":true};dry.import_state({})
 check(float(dry.stumps.old_stump.start)==s.clock and not dry.ready(dry.stumps.old_stump),"old unknown stump age starts at migration time")
 var body:=Body.new();body.water=100;body.food=100
 body.add_poison("severe");check(not body.poison_active(),"severe poison has delayed onset")
 var hp:=body.tick(119,false,80,100,false);check(is_zero_approx(hp),"delayed toxin causes no premature damage")
 var restored:=Body.new();restored.import_state(JSON.parse_string(JSON.stringify(body.export_state())))
 check(is_equal_approx(float(restored.conditions.poison.delay),1),"remaining poison delay survives JSON save")
 var partial:=restored.tick(2,false,80,100,false)
 check(is_equal_approx(partial,-0.12),"crossing onset integrates exactly the active minute, not entire step")
 var one:=Body.new();one.water=100;one.food=100;one.add_poison("severe")
 var many:=Body.new();many.water=100;many.food=100;many.add_poison("severe")
 var single:=one.tick(180,true,80,100,false);var sum:=0.0
 for i in 180:sum+=many.tick(1,true,80,100,false)
 check(is_equal_approx(single,sum) and is_equal_approx(one.water,many.water),"poison identical over accelerated sleep and minute steps")
 check(not one.can_sprint(100),"active poison limits sprint")
 check(one.tick(1,true,80,100,false)<0,"poison blocks sleep health regeneration")
 for i in 20:one.add_poison("severe")
 check(float(one.conditions.poison.load)==3 and one.conditions.size()==1,"repeat doses bounded to one toxic burden at max 3")
 var disorder:=Body.new();disorder.add_poison("disorder");disorder.stamina=10;disorder.update_stamina(1,false)
 check(is_equal_approx(disorder.stamina,14),"food disorder halves short stamina recovery")
 for id in ["copper_false","pale_bell"]:
  s.player.inventory_slots.fill(null);Items.transact(s.player,{},[Items.item("cooked_"+id)])
  s.body=Body.new();s.vegetation.known.erase(id)
  check(not s.foraging.use(0,false) and Items.count(s.player.inventory_slots,"cooked_"+id)==1,"unknown cooked poison requires explicit confirmation: "+id)
  check(s.foraging.use(0,true) and s.body.conditions.has("poison"),"cooking does not detoxify: "+id)
 s.player.inventory_slots.fill(null);Items.transact(s.player,{},[Items.item("stump_fan")])
 check(not s.foraging.use(0,true) and Items.count(s.player.inventory_slots,"stump_fan")==1,"raw tea fungus cannot be eaten or lost")
 s.player.inventory_slots.fill(null);Items.transact(s.player,{},[Items.item("wood_tea")]);s.body=Body.new();s.body.stamina=90;s.body.water=20;s.body.conditions.sprain={"remaining":240}
 check(s.foraging.use(0) and s.body.stamina==100 and s.body.water==20+Items.WATER_RESTORE,"tea restores clamped stamina and existing water amount")
 check(s.body.conditions.has("sprain") and not s.body.can_sprint(100),"tea cannot remove injury or sprint restriction")
 s.player.inventory_slots.fill(null);Items.transact(s.player,{},[Items.item("antitoxin")]);s.body.add_poison("severe")
 check(s.foraging.use(0) and not s.body.conditions.has("poison"),"available medicine removes delayed or active toxic burden")
 s.player.inventory_slots.fill(null);Items.transact(s.player,{},[Items.item("krasnitsa")]);s.body.food=100
 check(not s.foraging.use(0) and Items.count(s.player.inventory_slots,"krasnitsa")==1,"full calorie reserve refuses edible plant without losing it")
 s.body.calories=1000;check(s.foraging.use(0) and s.body.calories==1125,"plant consumption uses canonical calorie amount")
 s.player.inventory_slots.fill(null);Items.transact(s.player,{},[Items.item("wood_tea")]);s.body.calories=1000
 check(s.foraging.use(0) and s.body.calories==1020,"tea supplies 20 kcal alongside water and stamina")
 var recipe:=s.foraging.cook_recipe("wood_tea",2)
 check(recipe.costs=={"stump_fan":2,"water":2} and recipe.minutes==10 and recipe.outputs[0].count==2,"tea recipe uses real fungus and safe water with five minutes each")
 check(s.foraging.cook_recipe("wood_tea",0).is_empty() and s.foraging.cook_recipe("water",1).is_empty(),"invalid amounts and recipes rejected")
 s.player.inventory_slots.fill(null);Items.transact(s.player,{},[Items.item("water"),Items.item("stump_fan")]);s.job={"kind":"vegetation_cook","recipe":"wood_tea","amount":1}
 check(not Items.transact(s.player,{"water":1}) and Items.count(s.player.inventory_slots,"water")==1,"reserved safe water cannot be dropped or consumed during cooking")
 s.job={};check(Items.transact(s.player,{"water":1,"stump_fan":1},[Items.item("wood_tea")]),"completion commits inputs and output as single transaction")
 s.free();print("VEGETATION UNIT SUMMARY: %d PASS, %d FAIL"%[passes,failures]);quit(1 if failures else 0)
