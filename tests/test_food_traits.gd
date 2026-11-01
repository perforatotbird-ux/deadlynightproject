extends SceneTree
const Items=preload("res://scripts/survival/SurvivalItems.gd")
const Plants=preload("res://scripts/vegetation/VegetationCatalog.gd")
var passes:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,text:String)->void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func run()->void:
 var arena:=Node3D.new();arena.name="MapViewer";root.add_child(arena);current_scene=arena
 var p=load("res://scenes/player/Player.tscn").instantiate();arena.add_child(p);p.set_active(true);p.set_physics_process(false)
 var s=load("res://scripts/survival/SurvivalWorld.gd").new();arena.add_child(s);s.set_process(false)
 for id in Plants.FOOD_EFFECTS:
  s.body.calories=1000;s.body.water=50;s.body.stamina=50;s.energy=50;s.warmth=50;s.body.conditions.clear()
  s.vegetation.known[Plants.item_species(id)]=true
  check(Items.transact(p,{},[Items.item(id)]),"add "+id)
  var slot:=-1
  for i in p.inventory_slots.size():
   if p.inventory_slots[i]!=null and p.inventory_slots[i].id==id:slot=i;break
  check(s.use_supply(slot),"consume "+id)
  var effects:Dictionary=Plants.food_effects(id)
  var d:Dictionary=Plants.species(Plants.item_species(id))
  check(is_equal_approx(s.body.water,50+float(d.get("water",0))+float(effects.get("water",0))),id+" water trade-off")
  check(is_equal_approx(s.body.stamina,50+float(effects.get("stamina",0))) and is_equal_approx(s.energy,50+float(effects.get("energy",0))),id+" stamina/fatigue trade-off")
  check(is_equal_approx(s.warmth,50+float(effects.get("warmth",0))),id+" cooked warmth")
  check(Plants.item_definition(id).description.contains("Свойства порции"),id+" inspector explains effects")
 check(Plants.food_effects("cooked_copper_false")==Plants.food_effects("copper_false") and s.body.conditions.has("poison"),"cooking toxic mushrooms does not detoxify")
 s.body.calories=1000;s.body.stamina=98;s.body.water=0;s.energy=99;s.warmth=99
 Items.transact(p,{},[Items.item("krasnitsa")])
 for i in p.inventory_slots.size():
  if p.inventory_slots[i]!=null and p.inventory_slots[i].id=="krasnitsa":s.use_supply(i);break
 check(s.body.stamina==100 and s.body.water>=0 and s.energy<=100,"benefits and drawbacks stay bounded")
 print("FOOD TRAITS SUMMARY: %d PASS, %d FAIL" % [passes,failures])
 arena.free();await process_frame;quit(1 if failures else 0)
