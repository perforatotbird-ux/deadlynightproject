extends SceneTree
const Items=preload("res://scripts/survival/SurvivalItems.gd")
var passes:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,text:String)->void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func run()->void:
 var arena:=Node3D.new();arena.name="MapViewer";root.add_child(arena);current_scene=arena
 var p=load("res://scenes/player/Player.tscn").instantiate();arena.add_child(p);p.set_active(true);p.set_physics_process(false);p.position=Vector3.ZERO
 var s=load("res://scripts/survival/SurvivalWorld.gd").new();arena.add_child(s);s.set_process(false)
 var f:Dictionary=s.Fire.create("cooking_limit_fire",Vector3(0,0,2));f.fuel=100000;f.state="burning";s.fires.append(f);s._spawn_fire(f);s.selected_fire=f.id
 var food:=Items.item("forest_fat");food.count=2;Items.transact(p,{},[food])
 s.open_backpack(f.id);var ui=p._backpack_ui;ui.cook_select.select(0);ui.refresh_actions()
 check(s.foraging.max_cook_amount("forest_fat")==2 and ui.cook_amount.max_value==2,"quantity is capped by mushroom count")
 ui.cook_amount.value=99;ui.refresh_actions()
 check(ui.cook_amount.value==2,"out-of-range selection clamps to actual stock")
 check(not s.foraging.begin_cook("forest_fat",3) and s.job.is_empty(),"direct over-limit request cannot start")
 check(s.foraging.begin_cook("forest_fat",2),"available two-portion batch starts")
 s.close_backpack();p.position.x+=20;s.advance(6)
 check(Items.count(p.inventory_slots,"forest_fat")==0 and Items.count(p.inventory_slots,"cooked_forest_fat")==2,"closed UI and walking away preserve cooking and exact ingredients")
 p.position.x-=20
 var fungus:=Items.item("stump_fan");fungus.count=3;Items.transact(p,{},[fungus,Items.item("water")]);s.vegetation.inspected["stump_fan"]=true
 check(s.foraging.max_cook_amount("wood_tea")==1,"multi-ingredient recipe uses limiting stock")
 check(not s.foraging.begin_cook("wood_tea",2),"tea cannot exceed safe water stock")
 s.open_backpack(f.id);ui.cook_select.select(1);ui.refresh_actions()
 check(ui.cook_amount.max_value==1 and not ui.cook_amount.editable and ui.buttons.cook.disabled,"empty recipe has disabled quantity and cook button")
 check(not s.foraging.begin_cook("forest_fat",0) and not s.foraging.begin_cook("forest_fat",-1),"zero and negative quantities rejected")
 print("COOKING LIMITS SUMMARY: %d PASS, %d FAIL" % [passes,failures])
 arena.free();await process_frame;quit(1 if failures else 0)
