extends SceneTree
const Items=preload("res://scripts/survival/SurvivalItems.gd")
const Craft=preload("res://scripts/survival/CraftCatalog.gd")
var passes:=0
var failures:=0
func check(ok:bool,text:String)->void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func _initialize()->void:
 check(Items.item("brush").name=="Ветки","legacy brush identity remains compatible but is named branches")
 check(Items.item("tinder").name=="Хворост","tinder is a separate item")
 check(Craft.recipe("tinder").costs=={"brush":1},"one branch crafts tinder")
 var f:Dictionary=preload("res://scripts/survival/FireModel.gd").create("test",Vector3.ZERO)
 check(f.tinder==0,"new fire does not contain free tinder")
 var world=preload("res://scripts/survival/SurvivalWorld.gd").new()
 world.fires=[f];world.selected_fire="test";f.fuel=300
 check(world.ignition_chance("match")==0,"no tinder means zero ignition chance")
 f.tinder=1
 check(world.ignition_chance("match")>0,"added tinder enables an ignition chance")
 var fire_model=preload("res://scripts/survival/FireModel.gd")
 var branch_fire:Dictionary=fire_model.create("branch",Vector3.ZERO)
 fire_model.add_fuel(branch_fire,fire_model.BRANCH_FUEL_SECONDS);branch_fire.state="burning"
 fire_model.advance(branch_fire,299.0,false)
 check(branch_fire.state=="burning" and branch_fire.fuel==1.0,"one branch burns through 299 game seconds")
 fire_model.advance(branch_fire,1.0,false)
 check(branch_fire.state=="embers" and branch_fire.fuel==0.0,"one branch expires at exactly five game minutes")
 check(preload("res://scripts/vegetation/VegetationCatalog.gd").FIRST_GROWTH==172800.0,"first stump crop waits exactly two game days")
 check(preload("res://scripts/vegetation/VegetationCatalog.gd").eligible("any_player_tree"),"every player-felled stump is eligible")
 var body_model=preload("res://scripts/survival/BodyModel.gd").new()
 check(body_model.burn_rate(true,false)*8+body_model.burn_rate(false,false,true)*8+body_model.burn_rate(false,false)*8==2080.0,"balanced mixed day consumes 2080 kcal before load/cold")
 world.free()
 print("SURVIVAL REWORK SUMMARY: %d PASS, %d FAIL" % [passes,failures]);quit(1 if failures else 0)
