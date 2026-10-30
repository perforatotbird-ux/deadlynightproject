extends SceneTree
const Body=preload("res://scripts/survival/BodyModel.gd")
var passes:=0
var failures:=0
var p:Node3D
var s:Node
var graphical:=false
var out:="/data/health-dev-previews"
func _initialize() -> void:call_deferred("run")
func check(ok:bool,text:String) -> void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func settle(frames:int=4) -> void:
 for i in frames:await process_frame
func key(code:Key) -> void:
 var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;root.push_input(e,true);await process_frame
 e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=false;root.push_input(e,true);await process_frame
func click(button:Button) -> void:
 var pos:=button.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new();motion.position=pos;motion.global_position=pos;root.push_input(motion,true)
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=pos;e.global_position=pos;e.pressed=true;root.push_input(e,true);await process_frame
 e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=pos;e.global_position=pos;e.pressed=false;root.push_input(e,true);await process_frame
func capture(name:String) -> void:
 if not graphical:return
 await settle();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out.path_join(name+".png"))
func clear_items() -> void:p.inventory_slots.fill(null);s.Items.refresh(p)
func add(id:String,count:int=1) -> int:
 var item:Dictionary=s.Items.item(id);item.count=count;s.Items.transact(p,{},[item])
 for i in p.inventory_slots.size():
  if p.inventory_slots[i]!=null and p.inventory_slots[i].type==id:return i
 return -1
func run() -> void:
 graphical=DisplayServer.get_name()!="headless";root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720)
 if graphical:DirAccess.make_dir_recursive_absolute(out)
 var b:=Body.new();var food:=b.food;var water:=b.water
 check(is_zero_approx(b.tick(60,false,80,100,false)),"healthy awake body does not lose health")
 check(b.food<food and b.water<water,"food and water decrease with game time")
 var awake_food:float=food-b.food;b.import_state({});b.tick(60,true,80,100,false)
 check(85-b.food<awake_food,"sleep reduces food consumption")
 b.water=0;b.food=0;var loss:=b.tick(1,false,0,0,false)
 check(is_equal_approx(loss,-0.77) and b.causes.size()==4,"damage sources are explicit and additive")
 b.import_state({});b.tick(30,false,0,100,false);check(b.conditions.has("hypothermia"),"30 cold minutes cause hypothermia")
 check(not b.can_sprint(100),"hypothermia disables sprint")
 b.tick(119,true,80,100,false);check(b.conditions.has("hypothermia"),"hypothermia is not cured immediately by warmth")
 b.tick(1,true,80,100,false);check(not b.conditions.has("hypothermia"),"two warm hours cure hypothermia")
 b.conditions.bleeding={"remaining":-1};check(b.tick(1,true,80,100,false)<0,"bleeding blocks regeneration and damages")
 b.conditions.erase("bleeding");check(b.tick(1,true,80,100,false)>0,"warm nourished sleep regenerates health")
 b.conditions.sprain={"remaining":240};b.tick(120,true,80,100,false);check(not b.conditions.has("sprain"),"sleep accelerates sprain recovery")
 b.import_state({});b.update_stamina(9,true);check(b.stamina==0 and not b.can_sprint(100),"sprint exhausts short-term stamina")
 b.update_stamina(1,false);check(not b.can_sprint(100),"exhaustion has recovery hysteresis, no sprint oscillation")
 b.update_stamina(3,false);check(b.can_sprint(100),"breathing break restores sprint without sleep")
 b.conditions.sprain={"remaining":100};check(not b.can_sprint(100),"sprain blocks sprint")
 b.invulnerable=true;check(is_zero_approx(b.tick(1,false,0,0,false)),"god mode suppresses health damage")
 var state:=b.export_state();b.import_state(state);check(not b.invulnerable and not b.freeze_needs,"cheats never restored from body save")
 check(b.conditions.has("sprain") and is_equal_approx(b.conditions.sprain.remaining,99),"conditions and remaining duration round trip")
 b.import_state({"food":-50,"water":INF,"stamina":999,"conditions":{"unknown":{},"bleeding":false}})
 check(b.food==0 and b.water==0 and b.stamina==100 and b.conditions.is_empty(),"body migration clamps invalid data and ignores unknown conditions")
 b.import_state({});check(b.food==85 and b.water==85,"old saves get playable need defaults")
 var scene:=Node3D.new();scene.name="MapViewer";root.add_child(scene);current_scene=scene
 var ground:=StaticBody3D.new();ground.add_to_group("camp_ground");var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(160,1,160);col.shape=shape;ground.position.y=-0.5;ground.add_child(col);scene.add_child(ground)
 var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=shape.size;mesh.mesh=box;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("364039");mesh.material_override=mat;ground.add_child(mesh)
 var env:=WorldEnvironment.new();env.name="WorldEnvironment";env.environment=Environment.new();env.environment.background_mode=Environment.BG_SKY;scene.add_child(env)
 var sun:=DirectionalLight3D.new();sun.name="DirectionalLight3D";scene.add_child(sun)
 p=load("res://scenes/player/Player.tscn").instantiate();scene.add_child(p);p.position=Vector3(6,0.2,6);p.set_active(true);p.set_physics_process(false)
 s=load("res://scripts/survival/SurvivalWorld.gd").new();scene.add_child(s);s.set_process(false);s.shelter.position=Vector3.ZERO
 await physics_frame;await settle()
 check(s.resources.size()==7,"finite authored camp supplies exist without filling inventory")
 var supply=s.resources.camp_supply_0;supply.survival_interact();check(s.picked.has("camp_supply_0") and s.Items.count(p.inventory_slots,"ration")==1,"camp supplies are normal pickups and persist collected ID")
 s._spawn_supplies();check(not s.resources.has("camp_supply_0"),"collected camp supply cannot respawn")
 clear_items();var slot:=add("water");s.body.water=10
 check(s.use_supply(slot) and s.body.water==45 and s.Items.count(p.inventory_slots,"water")==0,"drinking consumes exactly one portion atomically")
 slot=add("ration");s.body.food=20;check(s.use_supply(slot) and s.body.food==65,"ration restores nutrition")
 slot=add("berries");check(s.use_supply(slot) and s.body.food==77,"edible berries restore nutrition")
 slot=add("bandage");check(not s.use_supply(slot) and s.Items.count(p.inventory_slots,"bandage")==1,"bandage is not wasted without bleeding")
 s.body.conditions.bleeding={"remaining":-1};var hp:float=s.health;check(s.use_supply(slot) and not s.body.conditions.has("bleeding") and s.health==hp,"bandage removes bleeding without instant healing")
 slot=add("compress");s.body.conditions.sprain={"remaining":100};check(s.use_supply(slot) and not s.body.conditions.has("sprain"),"compress treats sprain")
 slot=add("raw_water");check(not s.use_supply(slot) and s.Items.count(p.inventory_slots,"raw_water")==1,"raw water cannot be drunk without boiling")
 p.position=Vector3(12,0.2,12);var fire:Dictionary={"id":"qa_fire","pos":[12,0.05,10],"state":"burning","fuel":10000.0,"tinder":2};s.fires.append(fire);s.weather="clear";s.weather_until=s.clock+100000
 check(s.begin_boil(),"boiling starts near accessible burning fire")
 s.advance(5);check(s.Items.count(p.inventory_slots,"raw_water")==0 and s.Items.count(p.inventory_slots,"water")==1,"five-minute boiling produces one safe portion")
 add("raw_water");check(s.begin_boil(),"second boiling can start")
 s.cancel_job();check(s.Items.count(p.inventory_slots,"raw_water")==1,"cancelled boiling never consumes input")
 var collector:Node
 for node in scene.get_children():
  if node.get_script()==load("res://scripts/survival/RainCollector.gd"):collector=node
 s.rain_reserve=1;collector.survival_interact();check(s.rain_reserve==0 and s.Items.count(p.inventory_slots,"raw_water")==2,"collector yields only stored raw water")
 collector.survival_interact();check(s.rain_reserve==0 and s.Items.count(p.inventory_slots,"raw_water")==2,"empty collector cannot duplicate water")
 s.weather="rain";s.advance(60);check(s.rain_reserve>0 and s.rain_reserve<=6,"rain replenishes bounded water reserve")
 s.health=100;s.body.import_state({});s.land(7);check(s.health==100 and s.body.conditions.is_empty(),"ordinary jump landing causes no injury")
 s.land(17);check(s.health==72 and s.body.conditions.has_all(["bleeding","sprain"]),"dangerous fall applies impact damage and injuries")
 s.body.invulnerable=true;s.land(40);check(s.health==72,"god mode protects against fall trauma")
 s.body.invulnerable=false
 s.health=100;s.body.import_state({});p.position=Vector3(25,8,25);p.velocity=Vector3.ZERO;p._fall_speed=0;p.set_physics_process(true)
 for frame in 180:
  await physics_frame
  if s.health<100:break
 p.set_physics_process(false)
 check(s.health<100 and s.body.conditions.has("sprain"),"real CharacterBody landing dispatches fall injury")
 var saved:Dictionary=s.export_state();check(saved.version==3 and saved.has("body"),"survival schema v3 includes body")
 s.body.food=0;s.import_state(saved);check(s.body.conditions.has("sprain") and s.body.food>0,"SurvivalWorld restores conditions and needs")
 s.import_state({"clock":57600,"health":100});check(s.body.food==85 and not s.body.conditions.has("bleeding"),"SurvivalWorld accepts pre-health saves")
 var dev=s.dev_menu;var cmd=dev.commands
 check(dev.tabs.get_tab_count()==7,"Dev Menu exposes seven subsystem pages")
 check(cmd.run("unknown").contains("Неизвестная"),"unknown commands cannot execute code")
 cmd.run("stat",{"key":"water","value":500});check(s.body.water==100,"developer setters clamp stats")
 cmd.run("stat",{"key":"health","value":NAN});check(s.health==100,"developer setter rejects NaN")
 cmd.run("tuning",{"key":"food_awake","value":0.2});check(s.body.tuning.food_awake==0.2,"Dev tuning exposes need rates without arbitrary property access")
 check(cmd.run("give",{"id":"imaginary"}).contains("Ошибка"),"unknown item cannot be spawned")
 clear_items();cmd.run("give",{"id":"water","count":12});check(s.Items.count(p.inventory_slots,"water")==12 and is_equal_approx(p.backpack_weight,6),"dev grants use real stack limits and weight")
 cmd.run("give",{"id":"log","species":"oak","count":2});check(s.Items.count(p.inventory_slots,"log")==2 and is_equal_approx(p.backpack_weight,24),"developer logs preserve canonical species weight")
 cmd.run("give",{"id":"firewood","species":"oak"});check(is_equal_approx(p.backpack_weight,27),"developer split wood uses one third of log mass")
 cmd.run("condition",{"id":"bleeding"});check(s.body.conditions.has("bleeding"),"dev condition injection uses body model")
 cmd.run("heal");check(s.health==100 and s.body.conditions.is_empty(),"heal preset restores healthy state")
 cmd.run("god",{"enabled":true});check(s.body.invulnerable,"dev god toggle")
 cmd.run("needs",{"enabled":true});var frozen_food:float=s.body.food;s._update_body(3600,false);check(s.body.food==frozen_food,"freeze-needs stops body changes")
 cmd.run("needs",{"enabled":false});cmd.run("god",{"enabled":false})
 var t:float=s.clock;cmd.run("freeze",{"enabled":true});s.advance(10);check(s.clock==t,"world freeze stops game clock")
 cmd.run("freeze",{"enabled":false});cmd.run("clock",{"day":2,"hour":23});check(s.clock==169200,"clock setter changes day/hour without simulation")
 cmd.run("weather",{"kind":"storm"});check(s.weather=="rain" and s.weather_model.sample(s.clock,true,s.weather_until,0).storm>0.9,"storm preset changes gameplay and visuals together")
 cmd.run("weather",{"kind":"clear"});s.warmth=80;s.wetness=0;var need:float=s.body.water;t=s.clock;cmd.run("simulate",{"hours":1});check(is_equal_approx(s.clock-t,3600) and s.body.water<need,"time simulation applies needs and clock together")
 check(cmd.teleport(Vector3(20,0,20)) and p.position.y>=0,"teleport projects to free terrain")
 check(not cmd.teleport(Vector3(9999,0,0)),"teleport refuses out-of-map positions")
 cmd.run("snapshot");s.body.water=1;cmd.run("restore_snapshot");check(s.body.water>1 and not s.body.invulnerable and s.dev_tainted,"separate dev snapshot restores state but not cheats")
 cmd.run("events",{"enabled":false});cmd.run("event",{"kind":"meteor"})
 var event_age:float=s.sky_events.event.get("elapsed",0);s._process(0.2)
 check(not s.sky_events.event.is_empty() and float(s.sky_events.event.get("elapsed",0))>event_age,"manual event animates while automatic scheduling is disabled")
 cmd.run("stop_events");cmd.run("events",{"enabled":true})
 cmd.run("diagnostics");check(FileAccess.file_exists("user://dev_diagnostics.json"),"diagnostic JSON written")
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 var mouse_before:=Input.mouse_mode
 await key(KEY_F8);check(dev.visible and paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"F8 opens modal Dev Menu with pause and mouse release")
 dev.tabs.current_tab=0;await settle()
 var apply_button:Button
 for node in dev.panel.find_children("*","Button",true,false):
  if node.text=="Применить":apply_button=node;break
 dev.inputs.health.value=95;await click(apply_button)
 await capture("dev_confirmation_720p")
 check(dev.confirm.visible and s.health==100,"real stat button requests confirmation before reducing health")
 await click(dev.confirm_ok);check(s.health==95,"real confirmation click applies the chosen health stat")
 cmd.run("heal");dev.refresh_values(true)
 var before:float=s.clock;await settle(6);check(s.clock==before,"world stays frozen behind developer panel")
 for i in dev.tabs.get_tab_count():
  dev.tabs.current_tab=i;await settle();check(dev.panel.get_global_rect().end.y<=720,"Dev page %d fits 720p" % i);await capture("dev_%d_720p" % i)
 dev.dangerous("Test confirmation",func():s.health=1);check(dev.confirm.visible and s.health>1,"destructive command waits for confirmation")
 await key(KEY_ESCAPE);check(not dev.confirm.visible and dev.visible,"Escape dismisses confirmation before closing Dev Menu")
 await key(KEY_F8);check(not paused and not dev.visible and Input.mouse_mode==mouse_before,"closing Dev Menu restores pause/mouse state")
 s.health=0;s.body.last_damage="Тест";s._die();s.ui.refresh();await capture("death_720p");await key(KEY_F8);check(dev.visible,"Dev Menu remains available after death");cmd.run("heal");await key(KEY_F8)
 clear_items()
 for id in ["water","raw_water","ration","berries","bandage","compress"]:add(id)
 s.open_backpack();p._on_slot_clicked(0);await capture("supplies_720p")
 p._backpack_ui.tabs.current_tab=4;s.body.conditions.bleeding={"remaining":-1};s.body.conditions.sprain={"remaining":240};s.body.water=14;s.body.food=20
 await capture("health_720p")
 check(p._backpack_ui.condition_values.size()==6,"journal exposes six separate body indicators")
 for id in ["water","raw_water","ration","berries","bandage","compress"]:check(load("res://scripts/ui/JournalArt.gd").texture(id)!=null,"new supply icon loaded: "+id)
 root.size=Vector2i(800,600);await settle();p._backpack_ui.resize();await capture("health_800")
 s.close_backpack();dev.open_menu()
 for i in dev.tabs.get_tab_count():
  dev.tabs.current_tab=i;await settle();check(dev.panel.get_global_rect().end.x<=800 and dev.panel.get_global_rect().end.y<=600,"Dev page %d fits 800x600" % i);await capture("dev_%d_800" % i)
 dev.close_menu();s.body.conditions.clear();s.health=100;s.ui.refresh();await capture("hud_800")
 # Actual SaveManager disk round trip; isolated user directory used by runner.
 var sm=load("res://scripts/core/SaveManager.gd").get_instance();s.body.food=37;s.body.water=42;s.body.conditions.sprain={"remaining":125};s.body.invulnerable=true
 check(sm.save_game("health_qa","manual","Health QA"),"SaveManager writes health schema to disk")
 var payload:Variant=JSON.parse_string(FileAccess.get_file_as_string("user://saves/health_qa.json"));s.body.food=0;sm._apply_loaded_state(payload)
 check(s.body.food==37 and s.body.water==42 and s.body.conditions.has("sprain") and not s.body.invulnerable,"SaveManager restores needs and trauma, not cheats")
 sm.delete_save("health_qa")
 scene.queue_free();await settle();print("HEALTH DEV SUMMARY: %d PASS, %d FAIL" % [passes,failures]);quit(1 if failures else 0)
