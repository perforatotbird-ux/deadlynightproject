extends SceneTree
const Session = preload("res://scripts/survival/SurvivalWorld.gd")
const Items = preload("res://scripts/survival/SurvivalItems.gd")
const Fire = preload("res://scripts/survival/FireModel.gd")
var failures:=0
var passes:=0
var arena:Node3D
var p:Node3D
var s:Node
func check(ok: bool, text: String) -> void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func reset_inventory() -> void:p._init_inventory_data()
func add(id: String, count: int=1) -> void:
 var item:=Items.item(id);item["count"]=count;check(Items.transact(p,{},[item]),"add "+id)
func _init() -> void:call_deferred("run")
func run() -> void:
 arena=Node3D.new();arena.name="MapViewer";root.add_child(arena);current_scene=arena
 var floorbody:=StaticBody3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(140,1,140)
 var col:=CollisionShape3D.new();col.shape=shape;floorbody.position.y=-0.5;floorbody.add_to_group("camp_ground");floorbody.add_child(col);arena.add_child(floorbody)
 p=load("res://scenes/player/Player.tscn").instantiate();arena.add_child(p);p.position=Vector3(0,0.1,0);p.set_active(true);p.set_physics_process(false)
 await physics_frame
 s=Session.new();arena.add_child(s);s.set_process(false);s.shelter.position=Vector3(8,0.08,0)
 await physics_frame
 check(s.matches==12,"limited starting matches")
 check(Fire.chance("match",0,false)==0.85 and Fire.chance("spark",0,false)==0.25,"configured 85% / 25% dry ignition")
 check(Fire.chance("match",100,true)>Fire.chance("spark",100,true),"matches always more likely than sparks")
 check(Fire.chance("match",100,true)<Fire.chance("match",0,false),"rain/wetness reduce success")
 check(not s.make_kit(),"cannot craft without materials")
 add("stone",6);add("brush",4)
 var w:float=p.backpack_weight
 check(s.make_kit(),"craft camp kit")
 check(Items.count(p.inventory_slots,"stone")==0 and Items.count(p.inventory_slots,"brush")==0,"recipe consumes exact inputs")
 check(is_equal_approx(p.backpack_weight,w),"craft conserves material weight")
 check(not s.make_kit(),"repeated craft cannot duplicate kit")
 check(not s.validate_placement(Vector3(0,0,4),Vector3(1,0,0))["ok"],"reject steep surface")
 check(s.validate_placement(Vector3(0,0,4),Vector3.UP)["ok"],"accept clear level ground")
 check(not s.validate_placement(Vector3(8,0.15,0),Vector3.UP)["ok"],"reject indoor placement")
 var obstruction:=StaticBody3D.new();var oc:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1,2,1);oc.shape=box;obstruction.add_child(oc);arena.add_child(obstruction);obstruction.position=Vector3(0,1,6)
 await physics_frame
 check(not s.validate_placement(Vector3(0,0,6),Vector3.UP)["ok"],"reject occupied footprint")
 s.begin_placement();s.placement={"ok":true,"pos":[0,0,3]}
 check(s.confirm_placement(),"place crafted camp on ground")
 check(s.fires.size()==1 and Items.count(p.inventory_slots,"camp_kit")==0,"placement spends kit once")
 check(not s.confirm_placement(),"double confirm cannot duplicate fire")
 var f:Dictionary=s.fires[0];p.position=Vector3(0,0.1,1)
 check(not s.begin_ignition(f["id"],"match"),"cannot ignite without fuel")
 check(s.matches==12,"blocked ignition does not spend match")
 # Logs use exact existing backpack representation.
 p._add_to_backpack({"species":"birch","weight":4.0})
 var slot:=-1
 for i in p.inventory_slots.size():
  if p.inventory_slots[i]!=null and p.inventory_slots[i].get("type")=="log":slot=i;break
 var before:float=p.backpack_weight
 check(s.begin_split(slot),"begin axe split")
 s.advance(9.99)
 check(Items.count(p.inventory_slots,"log")==1 and Items.count(p.inventory_slots,"firewood")==0,"no output before 10 real seconds")
 s.advance(0.01)
 check(Items.count(p.inventory_slots,"log")==0 and Items.count(p.inventory_slots,"firewood")==3,"one log yields exactly 3 pieces at 10 seconds")
 check(is_equal_approx(before,p.backpack_weight),"splitting preserves species weight")
 p._add_to_backpack({"species":"oak","weight":9.0})
 for i in p.inventory_slots.size():
  if p.inventory_slots[i]!=null and p.inventory_slots[i].get("type")=="log":slot=i;break
 check(s.begin_split(slot),"begin cancellable split")
 s.advance(2);s.cancel_job();check(Items.count(p.inventory_slots,"log")==1,"cancel keeps unconsumed log")
 p.active_hotbar_slot=1;check(not s.begin_split(slot),"splitting requires selected axe");p.active_hotbar_slot=0
 var fuel_slot:=-1
 for i in p.inventory_slots.size():
  if p.inventory_slots[i]!=null and p.inventory_slots[i].get("type")=="firewood":fuel_slot=i;break
 check(s.add_fuel(f["id"],fuel_slot),"add a firewood piece")
 check(is_equal_approx(f["fuel"],1800) and Items.count(p.inventory_slots,"firewood")==2,"fuel species/time and atomic consumption")
 check(not s.begin_ignition(f["id"],"spark"),"ordinary stones are not ignition pair")
 add("flint");add("pyrite")
 check(s.begin_ignition(f["id"],"spark"),"spark fallback with real mineral pair")
 s.job["success"]=false;s.advance(5)
 check(s.matches==12 and f["state"]=="unlit" and f["tinder"]==3,"failed spark spends tinder, not matches")
 check(s.begin_ignition(f["id"],"match"),"start match attempt")
 check(s.matches==11 and f["tinder"]==2,"match and tinder spent at attempt start")
 s.job["success"]=true
 var saved:Dictionary=JSON.parse_string(JSON.stringify(s.export_state()))
 s.cancel_job();s.import_state(saved);f=s.fires[0]
 check(not s.job.is_empty() and s.job["success"],"loading preserves pre-rolled ignition result")
 s.advance(2);check(f["state"]=="burning","successful attempt ignites fire")
 var n:int=s.matches;check(not s.begin_ignition(f["id"],"match") and s.matches==n,"burning fire cannot spend another match")
 var fuel:float=f["fuel"];s.advance(1);check(is_equal_approx(fuel-f["fuel"],60),"one real second consumes one game minute")
 var model:=Fire.create("unit",Vector3.ZERO);model["fuel"]=60;model["state"]="burning"
 Fire.advance(model,120,false);check(model["state"]=="embers" and is_equal_approx(model["embers"],540),"overflow step accounts for embers")
 Fire.advance(model,540,false);check(model["state"]=="cold","embers eventually go cold")
 Fire.add_fuel(model,300);check(model["state"]=="cold","cold fuel needs new ignition")
 model["state"]="burning";model["fuel"]=300;Fire.advance(model,100,true);check(is_equal_approx(model["fuel"],150),"rain increases fuel use by 1.5")
 # Body and shelter.
 s.clock=23*3600;s.weather="rain";s.weather_until=s.clock+100000;s.wetness=0;s.warmth=80
 p.position=Vector3(20,0.2,20);s.advance(10);check(s.wetness>0 and s.warmth<80,"rain and cold affect exposed body")
 p.global_position=s.shelter.global_position+Vector3(0,0.2,0);s.shelter.set_door(true)
 check(s.safe_shelter(),"closed physical cabin is recognized")
 var wet:float=s.wetness;s.advance(10);check(s.wetness<wet,"under roof player dries instead of getting wet")
 s.shelter.set_door(false);check(not s.safe_shelter() and s.covered(),"roof protection separate from closed-door warmth")
 check(not s.begin_rest(),"cannot sleep with open door")
 s.shelter.set_door(true);s.warmth=80;s.energy=30;s.weather="clear";s.weather_until=s.clock+100000
 check(s.begin_rest(),"rest allowed in closed cabin")
 var time_before:float=s.clock;s.advance(1)
 check(is_equal_approx(s.clock-time_before,3600) and s.energy>30,"one-hour sleep advances clock and restores energy")
 check(not s.job.has("kind"),"sleep completes")
 # Heat and drying, no wall penetration.
 p.position=Vector3(0,0.1,1);f["state"]="burning";f["fuel"]=100000;s.wetness=80;s.warmth=30
 check(s.heat_at_player()>0,"near fire supplies heat")
 var warmth:float=s.warmth;wet=s.wetness;s.advance(10)
 check(s.warmth>warmth and s.wetness<wet,"fire warms and dries player")
 # Full backpack transaction rollback.
 var original:Array=p.inventory_slots.duplicate(true)
 for i in p.inventory_slots.size():p.inventory_slots[i]={"id":"junk_%d"%i,"type":"junk","count":10,"unit_weight":1}
 var slots_before:=JSON.stringify(p.inventory_slots)
 check(not Items.transact(p,{},[Items.item("brush")]),"full backpack rejects pickup")
 check(JSON.stringify(p.inventory_slots)==slots_before,"failed transaction is atomic")
 p.inventory_slots=original;Items.refresh(p)
 # Failed match consumes its attempt; zero matches still permits mineral sparks.
 f["state"]="unlit";f["fuel"]=1800;f["tinder"]=4;s.matches=1
 check(s.begin_ignition(f["id"],"match"),"last match can start an attempt")
 s.job["success"]=false;s.advance(2)
 check(s.matches==0 and f["state"]=="unlit","failed attempt consumes last match")
 check(not s.begin_ignition(f["id"],"match"),"zero matches cannot start a free attempt")
 check(s.begin_ignition(f["id"],"spark"),"spark fallback works with zero matches")
 s.job["success"]=true;s.advance(5)
 check(f["state"]=="burning" and s.matches==0,"spark success lights fire without replenishing matches")
 # Real walls block both heat and remote fire manipulation.
 var wall:=StaticBody3D.new();var wc:=CollisionShape3D.new();var ws:=BoxShape3D.new();ws.size=Vector3(2,2,0.15);wc.shape=ws;wall.add_child(wc);arena.add_child(wall);wall.position=Vector3(0,1,2)
 await physics_frame
 check(is_zero_approx(s.heat_at_player()) and not s._fire_in_reach(f),"heat and fire interactions do not penetrate walls")
 wall.free();await physics_frame
 check(s.heat_at_player()>0 and s._fire_in_reach(f),"heat and interaction return after obstacle removal")
 # Physical door genuinely closes the opening, not just a status flag.
 p.position=Vector3(20,0.1,20);s.shelter.set_door(true);await physics_frame
 var dq:=PhysicsRayQueryParameters3D.create(Vector3(8,1,4),Vector3(8,1,0),1);dq.exclude=[p.get_rid()]
 var blocked=p.get_world_3d().direct_space_state.intersect_ray(dq)
 check(not blocked.is_empty() and blocked.collider==s.shelter.door,"closed cabin door has physical collision")
 s.shelter.set_door(false);await physics_frame
 check(p.get_world_3d().direct_space_state.intersect_ray(dq).is_empty(),"open cabin door clears doorway")
 # Inputs remain intact when split output has nowhere to go.
 var backup:Array=p.inventory_slots.duplicate(true)
 for i in p.inventory_slots.size():p.inventory_slots[i]={"id":"junk_%d"%i,"type":"junk","count":10,"unit_weight":1}
 p.inventory_slots[0]={"id":"log_birch","type":"log","species":"birch","count":2,"unit_weight":4.0}
 check(s.begin_split(0),"split may begin with a full backpack")
 s.advance(10)
 check(Items.count(p.inventory_slots,"log")==2 and Items.count(p.inventory_slots,"firewood")==0,"failed split output rolls back consumed input")
 p.inventory_slots=backup;Items.refresh(p)
 s.clock=86390;s.weather="clear";s.weather_until=s.clock+100000;s.advance(1)
 check(s.clock>86400 and s.hour()<1,"midnight wraps hour without resetting elapsed world time")
 s.weather_until=s.clock+1;s.advance(1);check(s.weather=="rain","weather changes at persisted world deadline")
 s.warmth=0;s.wetness=100;var hp:float=s.health;s.advance(10)
 check(s.health<hp and s.health>0,"prolonged dangerous cold damages health gradually")
 s.health=100;s.warmth=80;s.wetness=0;s.weather="clear";s.weather_until=s.clock+100000
 p.global_position=s.shelter.global_position+Vector3(0,0.2,0);s.shelter.set_door(true)
 check(s.begin_rest(),"begin rest for clock-boundary test")
 var t0:float=s.clock;s.advance(1.1)
 check(absf((s.clock-t0)-3606)<0.01,"rest ends at exactly one hour; leftover frame resumes normal time")
 p.position=Vector3(0,0.1,0)
 # Resource streaming is finite, collection doesn't respawn.
 p.position=Vector3(0,0.1,0);s._stream_resources()
 check(s.resources.size()>0,"world actually contains gatherable resources")
 var resource=s.resources.values()[0];var id:String=resource.resource_id;resource.survival_interact();await process_frame
 check(s.picked.has(id) and not s.resources.has(id),"gather spends world pickup once")
 s.loaded_cells.clear();s._stream_resources();check(not s.resources.has(id),"collected resource does not regenerate")
 # SaveManager actual disk JSON roundtrip; color types repaired.
 var sm=load("res://scripts/core/SaveManager.gd").get_instance();await process_frame
 current_scene=arena;s.matches=3;s.clock=84600;s.wetness=33;s.shelter.set_door(false)
 check(sm.save_game("slot_survival_qa","manual","First night QA"),"SaveManager writes actual survival save")
 var save=JSON.parse_string(FileAccess.get_file_as_string("user://saves/slot_survival_qa.json"))
 s.matches=99;s.clock=0;s.wetness=0;sm._apply_loaded_state(save)
 check(s.matches==3 and is_equal_approx(s.clock,84600) and is_equal_approx(s.wetness,33),"SaveManager restores clock/body/matches")
 check(not s.shelter.door_closed and s.fires.size()==1,"SaveManager restores door and fires without duplicates")
 check(s.picked.has(id),"gathered IDs persist through disk save")
 check(p.inventory_slots.filter(func(x):return x!=null and not x.get("color") is Color).is_empty(),"JSON item colors normalized for inventory UI")
 # Actual tree pause: no world time, fuel or job advances.
 s.cancel_job();p.position=Vector3(0,0.1,1);s.set_process(true)
 var clock_before:float=s.clock;var fuel_before:float=s.fires[0]["fuel"]
 paused=true;await create_timer(0.15,true).timeout
 check(is_equal_approx(s.clock,clock_before) and is_equal_approx(s.fires[0]["fuel"],fuel_before),"pause freezes clock and fire")
 paused=false;s.set_process(false)
 # Real wall-clock 10-second split, including pause, no animation.
 reset_inventory();p._add_to_backpack({"species":"birch","weight":4.0});p.active_hotbar_slot=0;s.health=100;s.warmth=80;s.weather="clear";s.weather_until=s.clock+100000
 s.open_panel();check(s.begin_split(0),"real-time split starts")
 s.set_process(true)
 var started:=Time.get_ticks_msec()
 await create_timer(0.2).timeout
 paused=true;var elapsed_before:float=s.job.get("elapsed",0)
 await create_timer(0.2,true).timeout
 check(is_equal_approx(float(s.job.get("elapsed",0)),elapsed_before),"pause freezes 10-second action")
 paused=false
 while not s.job.is_empty():await process_frame
 var duration:float=(Time.get_ticks_msec()-started)/1000.0
 s.set_process(false)
 check(duration>=10.15 and duration<12.0 and Items.count(p.inventory_slots,"firewood")==3,"actual elapsed split = %.2fs including 0.2s paused"%duration)
 print("FIRST NIGHT SUMMARY: %d PASS, %d FAIL" % [passes,failures])
 s.close_panel();arena.free();await process_frame;quit(1 if failures>0 else 0)
