extends SceneTree
const Session=preload("res://scripts/survival/SurvivalWorld.gd")
const Items=preload("res://scripts/survival/SurvivalItems.gd")
var passes:=0
var failures:=0
var p:Node3D
var s:Node
var graphical:=false
var out:="/data/backpack-tabs-previews"
func _initialize() -> void:call_deferred("run")
func check(ok: bool, text: String) -> void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func settle(frames: int=3) -> void:
 for i in frames:await process_frame
func key(code: Key) -> void:
 for pressed in [true,false]:
  var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=pressed;root.push_input(e,true);await process_frame
func pointer(pos: Vector2, pressed: bool) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=pos;e.global_position=pos;e.pressed=pressed;root.push_input(e,true)
func click(button: Control, hold: float=0.35) -> void:
 var pos:=button.get_global_rect().get_center()
 var m:=InputEventMouseMotion.new();m.position=pos;m.global_position=pos;root.push_input(m,true)
 pointer(pos,true)
 # Reproduce real human press/release spanning multiple periodic refreshes.
 for i in 3:
  await create_timer(hold/3).timeout;s.ui.refresh()
 pointer(pos,false);await settle()
func tab(index: int) -> void:
 var bar=p._backpack_ui.tabs.get_tab_bar();var pos:Vector2=bar.global_position+bar.get_tab_rect(index).get_center()
 pointer(pos,true);await process_frame;pointer(pos,false);await settle()
func shot(name: String) -> void:
 if not graphical:return
 await settle();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out.path_join(name+".png"))
func add(id: String, amount: int=1) -> void:
 var item:=Items.item(id);item["count"]=amount;Items.transact(p,{},[item])
func slot(type: String) -> int:
 for i in p.inventory_slots.size():
  if p.inventory_slots[i]!=null and p.inventory_slots[i].get("type")==type:return i
 return -1
func run() -> void:
 graphical=DisplayServer.get_name()!="headless";root.size=Vector2i(1280,720)
 if graphical:DirAccess.make_dir_recursive_absolute(out)
 var arena:=Node3D.new();arena.name="MapViewer";root.add_child(arena);current_scene=arena
 var floorbody:=StaticBody3D.new();var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(140,1,140);col.shape=shape;floorbody.add_child(col);floorbody.position.y=-0.5;floorbody.add_to_group("camp_ground");arena.add_child(floorbody)
 p=load("res://scenes/player/Player.tscn").instantiate();arena.add_child(p);p.position=Vector3(0,0.1,0);p.set_active(true);p.set_physics_process(false)
 s=Session.new();arena.add_child(s);s.set_process(false);s.shelter.position=Vector3(8,0.08,0)
 await physics_frame;await settle()
 add("stone",6);add("brush",8);add("flint");add("pyrite");p._add_to_backpack({"species":"birch","weight":4.0})
 await key(KEY_TAB);var ui=p._backpack_ui
 check(ui.tabs.get_tab_count()==4,"four backpack tabs")
 await tab(1);check(ui.tabs.current_tab==1,"real mouse switches to recipes")
 await shot("01_craft");await click(ui.buttons["kit"])
 check(Items.count(p.inventory_slots,"camp_kit")==1,"held craft click survives repeated refresh")
 await tab(0);await click(p._inv_slot_buttons[slot("camp_kit")]);var mass:float=p.backpack_weight
 await click(ui.buttons["belt"])
 check(p.belt_items[0]=="camp_kit" and is_equal_approx(mass,p.backpack_weight),"bind crafted kit to belt without moving/duplicating inventory")
 await shot("02_belt_assignment")
 await key(KEY_TAB);await key(KEY_6)
 check(p.active_hotbar_slot==5 and not p._axe_anim_pivot.visible,"key 6 equips crafted quick slot")
 pointer(Vector2(640,360),true);await process_frame;pointer(Vector2(640,360),false);await settle()
 check(s.placing,"LMB on crafted belt kit starts placement")
 await key(KEY_TAB);check(not s.placing and p._is_inventory_open,"Tab cancels placement before opening bag")
 s.begin_placement();s.placement={"ok":true,"pos":[0,0,3]};check(s.confirm_placement(),"place kit for camp tests")
 check(p.belt_items[0]=="","consumed last kit clears shortcut")
 p.position=Vector3(0,0.1,1);s.open_backpack();await tab(1);p.select_hotbar_slot(1)
 await click(ui.buttons["split"]);check(s.job.get("kind")=="split","held split click in recipes starts job")
 await shot("03_split");s.advance(10)
 check(Items.count(p.inventory_slots,"firewood")==3,"split yields three firewood pieces")
 var f:Dictionary=s.fires[0];s.open_backpack(f["id"]);await settle()
 check(ui.tabs.current_tab==2,"fire interaction opens dedicated camp tab")
 ui.fuel_select.select(ui.fuel_select.get_item_index(slot("firewood")));ui.refresh_actions();ui.fuel_amount.value=2
 await shot("04_camp");await click(ui.buttons["fuel"])
 check(Items.count(p.inventory_slots,"firewood")==1 and is_equal_approx(f["fuel"],3600),"held GUI fuel click adds selected amount exactly once")
 var tinder:int=f["tinder"];await click(ui.buttons["tinder"])
 check(f["tinder"]==tinder+1,"held tinder click survives periodic refresh")
 var matches:int=s.matches;await click(ui.buttons["match"])
 check(s.job.get("kind")=="ignite" and s.matches==matches-1,"held ignition click starts once")
 if not s.job.is_empty():s.job["success"]=true;s.advance(2)
 check(f["state"]=="burning","GUI ignition burns camp")
 # Nonselected fuels remain accessible through the camp picker.
 p.position=s.shelter.global_position+Vector3(0,0.2,0);s.shelter.set_door(true);s.warmth=80;s.energy=20
 s.shelter.bed.survival_interact();await settle()
 check(ui.tabs.current_tab==3 and not ui.rest.disabled,"cot opens enabled sleep tab")
 var slider_rect:Rect2=ui.sleep_hours.get_global_rect()
 var slider_point:Vector2=slider_rect.position+Vector2(slider_rect.size.x*0.75,slider_rect.size.y*0.5)
 pointer(slider_point,true);await process_frame;pointer(slider_point,false);await settle()
 check(ui.sleep_hours.value>6,"sleep slider responds to actual mouse input")
 ui.sleep_hours.grab_focus();await key(KEY_HOME)
 for i in 5:await key(KEY_RIGHT)
 check(ui.sleep_hours.value==6,"sleep slider responds to real input and selects six hours")
 await shot("05_sleep_six_hours")
 var clock:float=s.clock;await click(ui.rest)
 check(s.job.get("kind")=="rest" and s.job.get("hours")==6,"held sleep click starts requested duration")
 s.advance(2);var state:Dictionary=JSON.parse_string(JSON.stringify(s.export_state()));s.import_state(state);await settle()
 check(s.job.get("hours")==6 and is_equal_approx(float(s.job.get("elapsed",0)),2),"save/load keeps multi-hour sleep progress")
 s.advance(4);check(s.job.is_empty() and absf(s.clock-clock-21600)<0.02,"six hours sleep advances world by exactly six hours")
 s.shelter.set_door(false);ui.refresh_actions()
 check(ui.rest.disabled and "дверь" in ui.sleep_info.text,"open door explains why sleep unavailable")
 s.shelter.set_door(true);s.warmth=0;ui.refresh_actions()
 check(ui.rest.disabled and "холодно" in ui.sleep_info.text,"dangerous cold explicitly blocks sleep")
 s.warmth=80
 check(not s.begin_rest(0) and not s.begin_rest(13),"invalid sleep durations rejected")
 # Shortcuts persist and act on inventory, not copies.
 p.position=Vector3(0,0.1,1);s.open_backpack(f["id"])
 check(p.assign_belt_item(slot("firewood"),1),"bind crafted fuel to belt 7")
 var saved:Dictionary=s.export_state();p.belt_items=["","",""];s.import_state(saved)
 check(p.belt_items[1]=="firewood_birch","survival save restores crafted belt binding")
 s.close_backpack();await key(KEY_7);var fuel:float=f["fuel"]
 # import replaces dictionaries; find authoritative fire again.
 f=s.find_fire(f["id"]);fuel=f["fuel"]
 pointer(Vector2(640,360),true);await process_frame;pointer(Vector2(640,360),false);await settle()
 check(Items.count(p.inventory_slots,"firewood")==0 and is_equal_approx(f["fuel"],fuel+1800),"belt LMB adds fuel and consumes one authoritative item")
 check(p.belt_items[1]=="","empty fuel shortcut clears")
 s.open_backpack();await tab(0);await shot("06_inventory")
 check(ui.buttons["split"].disabled,"empty recipe picker does not expose a false actionable slot")
 if graphical:
  root.size=Vector2i(800,600);await settle();ui.resize()
  for i in 4:
   await tab(i);await shot("07_small_tab_%d" % i)
   check(ui.tabs.get_current_tab_control().get_global_rect().position.y>=ui.tabs.get_tab_bar().get_global_rect().end.y-1,"tab %d content does not overlap tab bar" % i)
   check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(p._inv_root_panel.get_global_rect()),"small window tab %d stays within viewport" % i)
 s.close_backpack();await settle();arena.free();current_scene=null;await settle()
 print("BACKPACK TABS SUMMARY: %d PASS, %d FAIL" % [passes,failures]);quit(1 if failures else 0)
