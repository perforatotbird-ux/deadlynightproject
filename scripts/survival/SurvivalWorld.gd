extends Node
# One owner for world clock, weather, fire fuel and timed jobs. No OS timers.
const Items = preload("res://scripts/survival/SurvivalItems.gd")
const Fire = preload("res://scripts/survival/FireModel.gd")
const Pickup = preload("res://scripts/survival/ResourcePickup.gd")
const FireVisual = preload("res://scripts/survival/Campfire.gd")
const Shelter = preload("res://scripts/survival/Shelter.gd")
const UI = preload("res://scripts/survival/SurvivalHUD.gd")
const TIME_SCALE := 60.0
const SPLIT_SECONDS := 10.0
const CAMP_COST := {"stone":6,"brush":4}
static var travel: Dictionary = {}
var player: Node3D
var location := "forest"
var clock := 16.0*3600.0
var weather := "clear"
var weather_until := 18.0*3600.0
var wetness := 0.0
var warmth := 80.0
var energy := 100.0
var health := 100.0
var matches := 12
var fires: Array = []
var picked: Dictionary = {}
var resources: Dictionary = {}
var loaded_cells: Dictionary = {}
var dropped: Array = []
var fire_nodes: Array = []
var shelter: Node3D
var ui: CanvasLayer
var job: Dictionary = {}
var rng := RandomNumberGenerator.new()
var selected_fire := ""
var placing := false
var preview: MeshInstance3D
var placement: Dictionary = {}
var message := "[Tab] Выживание · Собирайте хворост и камни · Стоянка к северо-западу от поляны"
var message_time := 15.0
var _scan := 0.0
var _visual_tick := 0.0
var _rain: GPUParticles3D
var _rain_audio: AudioStreamPlayer
var _night_audio: AudioStreamPlayer
var _wind_audio: AudioStreamPlayer
var _last_phase := ""
var _transitioning := false
var _cold_warned := false
var _old_felled: Dictionary = {}
var _old_logs: Array = []
var _mine_logs: Array = []
var _saved_door_closed := true

func _ready() -> void:
 name="SurvivalWorld";add_to_group("survival_session");rng.randomize()
 player=get_parent().get_node_or_null("Player")
 if player==null: return
 player.survival=self
 location="mine" if get_parent().name=="MineInterior" else "forest"
 ui=UI.new();ui.session=self;add_child(ui)
 if location=="forest":_create_shelter();_setup_weather_fx()
 if not travel.is_empty():
  var payload:=travel;travel={};import_state(payload["survival"])
  player.inventory_slots=payload["inventory"].duplicate(true);Items.refresh(player)
  if location=="forest":
   var exit_pos:=Vector3(1125,144,-1203)
   var ground=player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(exit_pos.x,300,exit_pos.z),Vector3(exit_pos.x,-10,exit_pos.z),1))
   if not ground.is_empty():exit_pos.y=ground.position.y+0.2
   player.global_position=exit_pos
   load("res://scripts/props/TreeChoppable.gd").felled_tree_ids=payload.get("felled",{})
   _restore_exterior_logs(payload.get("logs",[]))
   get_parent().get_node("WorldMap").restore_felled_stumps()
  else:_restore_exterior_logs(_mine_logs)
 _update_lighting()

func notify(text: String) -> void:
 message=text;message_time=6.0
 if is_instance_valid(player):player._show_tool_banner(text)

func _process(delta: float) -> void:
 if not is_instance_valid(player):return
 if not player._is_active:return
 advance(delta)
 if location=="forest":
  _scan-=delta
  if _scan<=0:_scan=0.7;_stream_resources()
  if placing:_update_placement()
 _visual_tick-=delta
 if _visual_tick<=0:
  _visual_tick=0.2;_update_lighting();ui.refresh()

 message_time=maxf(0,message_time-delta)

func advance(real_seconds: float) -> void:
 # Called by _process, which naturally stops with SceneTree pause.
 if real_seconds<=0 or health<=0:return
 var remaining:=real_seconds
 # Bounded integration preserves fuel/temperature order during accelerated sleep.
 while remaining>0.00001:
  var factor:=3600.0 if job.get("kind")=="rest" else TIME_SCALE
  var dt:=minf(remaining,60.0/factor)
  if not job.is_empty():dt=minf(dt,maxf(0.000001,float(job["duration"])-float(job.get("elapsed",0))))
  remaining-=dt
  var world_dt:=dt*factor
  clock+=world_dt
  if clock>=weather_until:
   weather="rain" if weather=="clear" else "clear"
   weather_until=clock+rng.randf_range(2.0,4.0)*3600.0
   notify("Начинается дождь: хворост сложнее разжечь" if weather=="rain" else "Дождь закончился")
  for f in fires:
   Fire.advance(f,world_dt,weather=="rain")
   if f["state"]=="burning" and f["fuel"]<600 and not f.get("low_warning",false) and _fire_in_reach(f):
    f["low_warning"]=true
    notify("Костёр скоро погаснет: осталось меньше 10 игровых минут")
   elif f["fuel"]>=600:f["low_warning"]=false
  _update_body(world_dt,job.get("kind")=="rest")
  if warmth<20 and not _cold_warned:_cold_warned=true;notify("Опасный холод! Найдите огонь или закрытое укрытие.")
  elif warmth>35:_cold_warned=false
  if health<=0:
   job={};notify("Вы погибли от переохлаждения. Загрузите сохранение через меню.");break
  if not job.is_empty():
   if job.get("kind")=="rest":
    if not safe_shelter() or warmth<20:
     cancel_job();notify("Отдых прерван: холод или открытая дверь");continue
   elif player.global_position.distance_to(_v3(job.get("origin",[])))>0.7:
    cancel_job();notify("Действие прервано движением");continue
   job["elapsed"]=float(job.get("elapsed",0))+dt
   if job["elapsed"]+0.000001>=float(job["duration"]):_finish_job()

func hour() -> float:return fposmod(clock,86400.0)/3600.0
func daylight() -> float:return smoothstep(5.0,7.0,hour())*(1.0-smoothstep(18.0,20.0,hour()))
func air_temperature() -> float:return lerpf(4,15,daylight())-(3 if weather=="rain" else 0)
func safe_shelter() -> bool:return location=="forest" and is_instance_valid(shelter) and shelter.contains(player.global_position) and shelter.door_closed
func covered() -> bool:return location=="mine" or (is_instance_valid(shelter) and shelter.contains(player.global_position))
func heat_at_player() -> float:
 if location!="forest":return 0
 var heat:=0.0
 for f in fires:
  if f["state"] not in ["burning","embers"]:continue
  var pos:=_v3(f["pos"]);var dist:=player.global_position.distance_to(pos)
  if dist>4.5:continue
  var q:=PhysicsRayQueryParameters3D.create(pos+Vector3.UP*0.7,player.global_position+Vector3.UP,1)
  q.exclude=[player.get_rid()]
  if player.is_inside_tree() and not player.get_world_3d().direct_space_state.intersect_ray(q).is_empty():continue
  heat=maxf(heat,(1.0-dist/4.5)*(20 if f["state"]=="burning" else 6))
 return heat
func _update_body(world_dt: float, resting: bool) -> void:
 var minutes:=world_dt/60.0
 var under_roof:=covered();var heat:=heat_at_player()
 if weather=="rain" and not under_roof:wetness=minf(100,wetness+minutes*1.5)
 else:wetness=maxf(0,wetness-minutes*(0.25+heat*0.1))
 var felt:=air_temperature()-wetness*0.09+heat
 if location=="mine":felt=8.0-wetness*0.04
 elif safe_shelter():felt+=5.0
 warmth=clampf(warmth+minutes*(felt-7.0)*0.16,0,100)
 var effort:=0.025+(0.04 if player.velocity.length()>5 else 0.0)
 energy=clampf(energy+minutes*(0.5 if resting and warmth>=20 else -effort),0,100)
 if warmth<12:health=maxf(0,health-minutes*0.6)
 elif resting and warmth>45:health=minf(100,health+minutes*0.08)

func find_fire(id: String) -> Dictionary:
 for f in fires:
  if f["id"]==id:return f
 return {}
func nearby_fire() -> Dictionary:
 var best:Dictionary={};var dist:=3.2
 if location!="forest":return best
 for f in fires:
  var d:=player.global_position.distance_to(_v3(f["pos"]))
  if d<dist and _fire_in_reach(f):dist=d;best=f
 return best
func open_backpack(fire_id: String = "", page: String = "camp") -> void:
 if placing or health<=0:return
 selected_fire=fire_id
 if not player._is_inventory_open:player._toggle_inventory()
 player._backpack_ui.refresh_actions()
 if page=="rest":player._backpack_ui.call_deferred("focus_rest")
 elif fire_id!="":player._backpack_ui.call_deferred("focus_fire")
func close_backpack() -> void:
 cancel_job()
 if player._is_inventory_open:player._toggle_inventory()
func handle_input(event: InputEvent) -> bool:
 if placing:
  if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:cancel_placement();return true
  if event is InputEventMouseButton and event.pressed:
   if event.button_index==MOUSE_BUTTON_LEFT:confirm_placement();return true
   if event.button_index==MOUSE_BUTTON_RIGHT:cancel_placement();return true
  return event is InputEventMouseButton
 return false
func make_kit() -> bool:
 if health<=0:return false
 if not job.is_empty():return false
 var ok:=Items.transact(player,CAMP_COST,[Items.item("camp_kit")])
 notify("Набор костра собран. Теперь разместите его." if ok else "Нужно 6 камней, 4 хвороста и место в рюкзаке")
 ui.refresh();return ok
func begin_split(slot_index: int) -> bool:
 if not job.is_empty() or slot_index<0 or slot_index>=player.inventory_slots.size():return false
 var s=player.inventory_slots[slot_index]
 if s==null or s.get("type")!="log":return false
 if health<=0 or not player._is_inventory_open:return false
 player.select_hotbar_slot(0)
 job={"kind":"split","elapsed":0.0,"duration":SPLIT_SECONDS,"slot":slot_index,"item_id":s["id"],"weight":s["unit_weight"],"species":s["species"],"origin":_arr(player.global_position)}
 player._cancel_chop();ui.refresh();return true
func add_fuel(id: String, slot_index: int) -> bool:
 var f:=find_fire(id)
 if f.is_empty() or not _fire_in_reach(f) or not job.is_empty():return false
 if slot_index<0 or slot_index>=player.inventory_slots.size():return false
 var s=player.inventory_slots[slot_index]
 if s==null or s.get("type") not in ["firewood","brush"]:return false
 var seconds:=300.0 if s["type"]=="brush" else float(Fire.FUEL_SECONDS.get(s.get("species","birch"),1800.0))
 if not Items.transact(player,{s["id"]:1}):return false
 Fire.add_fuel(f,seconds);notify("Топливо добавлено");ui.refresh();return true
func add_tinder(id: String) -> bool:
 var f:=find_fire(id)
 if f.is_empty() or not _fire_in_reach(f) or not job.is_empty():return false
 if not Items.transact(player,{"brush":1}):notify("Нужен хворост для растопки");return false
 f["tinder"]+=1;ui.refresh();return true
func ignition_chance(method: String) -> float:return Fire.chance(method,wetness,weather=="rain")
func begin_ignition(id: String, method: String) -> bool:
 var f:=find_fire(id)
 if method not in ["match","spark"] or not job.is_empty() or f.is_empty() or not _fire_in_reach(f):return false
 if f["state"]=="burning":notify("Костёр уже горит");return false
 if f["fuel"]<=0 or f["tinder"]<=0:notify("Добавьте топливо и хворост для растопки");return false
 if method=="match":
  if matches<=0:notify("Спички закончились");return false
  matches-=1
 else:
  if Items.count(player.inventory_slots,"flint")<1 or Items.count(player.inventory_slots,"pyrite")<1:
   notify("Нужны кремень и пирит. Обычные камни не подходят.");return false
 f["tinder"]-=1
 for node in fire_nodes:
  if is_instance_valid(node) and node.data["id"]==id:node.ignition_fx(method)
 # Persist a pre-rolled outcome: loading an in-progress attempt cannot reroll it.
 var success:=rng.randf()<ignition_chance(method)
 job={"kind":"ignite","elapsed":0.0,"duration":2.0 if method=="match" else 5.0,"fire":id,"success":success,"origin":_arr(player.global_position)}
 notify("Розжиг: спичка и растопка потрачены" if method=="match" else "Высекаете искру: растопка потрачена");ui.refresh();return true
func _fire_in_reach(f: Dictionary) -> bool:
 if location!="forest" or player.global_position.distance_to(_v3(f["pos"]))>3.3:return false
 var q:=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP,_v3(f["pos"])+Vector3.UP*0.4,1)
 q.exclude=[player.get_rid()]
 return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
func begin_rest() -> bool:
 if not job.is_empty() or not safe_shelter() or warmth<20:notify("Нужны закрытое укрытие и отсутствие опасного холода");return false
 job={"kind":"rest","elapsed":0.0,"duration":1.0,"origin":_arr(player.global_position)};ui.refresh();return true
func cancel_job() -> void:
 job={}
func _finish_job() -> void:
 var done:=job.duplicate(true);job={}
 match done["kind"]:
  "split":
   var index:=int(done["slot"])
   var s=player.inventory_slots[index] if index>=0 and index<player.inventory_slots.size() else null
   if s==null or s.get("id")!=done["item_id"] or not is_equal_approx(float(s.get("unit_weight",0)),float(done["weight"])):notify("Бревно перемещено: раскол отменён");return
   var output:=Items.item("firewood",done["species"],float(done["weight"])/3.0);output["count"]=3
   notify("Бревно расколото: 3 поленца" if Items.transact(player,{done["item_id"]:1},[output],index) else "Не хватает места: бревно сохранено")
  "ignite":
   var f:=find_fire(done["fire"])
   if not f.is_empty() and _fire_in_reach(f) and f["fuel"]>0 and done["success"]:f["state"]="burning";notify("Костёр разгорелся")
   else:notify("Розжиг не удался. Добавьте растопку и попробуйте ещё раз.")
  "rest":notify("Вы отдохнули 1 игровой час")
 ui.refresh()

func begin_placement() -> void:
 if placing or not job.is_empty() or health<=0:return
 if location!="forest" or Items.count(player.inventory_slots,"camp_kit")==0:notify("Сначала соберите набор костра");return
 close_backpack();placing=true
 preview=MeshInstance3D.new();var c:=CylinderMesh.new();c.top_radius=0.65;c.bottom_radius=0.65;c.height=0.06;preview.mesh=c
 var m:=StandardMaterial3D.new();m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;preview.material_override=m;get_parent().add_child(preview)
 notify("ЛКМ — поставить · ПКМ / Esc — отмена. Нужна ровная открытая земля.")
func validate_placement(pos: Vector3, normal: Vector3, surface: Object = null) -> Dictionary:
 if normal.dot(Vector3.UP)<cos(deg_to_rad(12)):return {"ok":false,"reason":"Слишком крутой склон"}
 if surface!=null:
  var n:Node=surface as Node
  if n and (n.is_in_group("water") or "water" in str(n.name).to_lower()):return {"ok":false,"reason":"Нельзя размещать в воде"}
 var space=player.get_world_3d().direct_space_state
 for offset in [Vector3.ZERO,Vector3(0.65,0,0),Vector3(-0.65,0,0),Vector3(0,0,0.65),Vector3(0,0,-0.65)]:
  var p:Vector3=pos+offset
  var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.5,p-Vector3.UP*0.5,1))
  if not hit.is_empty() and not hit.collider.is_in_group("camp_ground"):return {"ok":false,"reason":"Костёр можно ставить только на земле, не на сооружениях"}
  if hit.is_empty() or absf(hit.position.y-pos.y)>0.12:return {"ok":false,"reason":"Площадка неровная или край обрыва"}
 var ceiling=space.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3.UP*0.15,pos+Vector3.UP*4,1))
 if not ceiling.is_empty():return {"ok":false,"reason":"Костёр нельзя ставить под крышей или мостом"}
 var shape:=CylinderShape3D.new();shape.radius=0.78;shape.height=0.5
 var q:=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.transform=Transform3D(Basis.IDENTITY,pos+Vector3.UP*0.39);q.collision_mask=1|2|4|8
 if not space.intersect_shape(q,1).is_empty():return {"ok":false,"reason":"Слишком близко к препятствию или предмету"}
 return {"ok":true,"pos":_arr(pos),"reason":"ЛКМ — разместить костёр"}
func _update_placement() -> void:
 var cam=player._camera
 var hit=player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(cam.global_position,cam.global_position-cam.global_basis.z*4.5,1))
 placement={"ok":false,"reason":"Посмотрите на землю в пределах 4,5 м"}
 preview.visible=not hit.is_empty()
 if not hit.is_empty():preview.global_position=hit.position+Vector3.UP*0.04;placement=validate_placement(hit.position,hit.normal,hit.collider)
 preview.material_override.albedo_color=Color(0.3,0.9,0.55,0.5) if placement["ok"] else Color(0.95,0.25,0.2,0.5)
func confirm_placement() -> bool:
 if not placing or not placement.get("ok",false):notify(placement.get("reason","Нет площадки"));return false
 var pos:=_v3(placement["pos"])
 var check:=validate_placement(pos,Vector3.UP)
 if not check["ok"]:notify(check["reason"]);return false
 if not Items.transact(player,{"camp_kit":1}):cancel_placement();return false
 var f:=Fire.create("fire_%d_%d" % [int(clock*100),rng.randi()],pos);fires.append(f);_spawn_fire(f);cancel_placement();notify("Костёр установлен. [E] — добавить топливо и разжечь.");return true
func cancel_placement() -> void:
 placing=false;placement={}
 if is_instance_valid(preview):preview.queue_free()
 preview=null
func _spawn_fire(f: Dictionary) -> void:
 if location!="forest":return
 var n:=FireVisual.new();n.data=f;n.session=self;get_parent().add_child(n);n.global_position=_v3(f["pos"]);fire_nodes.append(n)
func _create_shelter() -> void:
 shelter=Shelter.new();shelter.session=self
 var pos:=Vector3(-914,25,1086)
 var hit=player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3.UP*30,pos-Vector3.UP*30,1))
 if not hit.is_empty():pos.y=hit.position.y+0.08
 get_parent().add_child(shelter);shelter.global_position=pos

func _stream_resources() -> void:
 # Deterministic, finite per-cell resources; collected IDs survive unloading/loading.
 var center:=Vector2i(floori(player.global_position.x/24),floori(player.global_position.z/24))
 for x in range(center.x-1,center.x+2):
  for z in range(center.y-1,center.y+2):
   var key:="%d:%d" % [x,z]
   if loaded_cells.has(key):continue
   loaded_cells[key]=true
   var random:=RandomNumberGenerator.new();random.seed=hash("DeadlyNight:"+key)
   var types=["brush","brush","brush","brush","stone","stone","stone","stone","flint","pyrite"]
   for i in types.size():
    var id:=key+":"+str(i)
    if picked.has(id):continue
    var pos:=Vector3(x*24+random.randf_range(2,22),player.global_position.y,z*24+random.randf_range(2,22))
    var hit=player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3.UP*70,pos-Vector3.UP*90,1))
    if hit.is_empty() or hit.normal.y<0.8 or not hit.collider.is_in_group("camp_ground"):continue
    # Avoid authored cabin floor/roof: scatter only terrain, never structures.
    if is_instance_valid(shelter) and Vector2(pos.x-shelter.global_position.x,pos.z-shelter.global_position.z).length()<3.5:continue
    _spawn_pickup(Items.item(types[i]),id,hit.position)
 for id in resources.keys():
  var n=resources[id]
  if is_instance_valid(n) and n.global_position.distance_to(player.global_position)>65:
   n.queue_free();resources.erase(id)
   var parts=str(id).split(":")
   if parts.size()>=3:loaded_cells.erase(parts[0]+":"+parts[1])
func _spawn_pickup(item: Dictionary, id: String, pos: Vector3) -> void:
 if resources.has(id):return
 var n:=Pickup.new();n.item_data=item;n.resource_id=id;n.session=self
 get_parent().add_child(n);n.global_position=pos;resources[id]=n
func drop_resource(item: Dictionary, pos: Vector3) -> void:
 var id:="drop_%d_%d" % [rng.randi(),int(clock)]
 dropped.append({"id":id,"item":item.duplicate(true),"pos":_arr(pos),"location":location})
 _spawn_pickup(item,id,pos)

func export_state() -> Dictionary:
 var state:={"version":1,"clock":clock,"weather":weather,"weather_until":weather_until,"wetness":wetness,"warmth":warmth,"energy":energy,"health":health,"matches":matches,"active_tool":player.active_hotbar_slot,"lantern_on":player._is_lantern_on,"fires":fires.duplicate(true),"picked":picked.duplicate(),"dropped":dropped.duplicate(true),"job":job.duplicate(true),"rng_state":str(rng.state),"location":location,"door_closed":shelter.door_closed if is_instance_valid(shelter) else _saved_door_closed,"exterior_felled":_old_felled,"exterior_logs":_old_logs,"mine_logs":_mine_logs}
 return state
func import_state(state: Dictionary) -> void:
 close_backpack();cancel_placement()
 clock=float(state.get("clock",16*3600));weather=state.get("weather","clear");weather_until=float(state.get("weather_until",clock+7200))
 wetness=clampf(float(state.get("wetness",0)),0,100);warmth=clampf(float(state.get("warmth",80)),0,100);energy=clampf(float(state.get("energy",100)),0,100);health=clampf(float(state.get("health",100)),0,100);matches=maxi(0,int(state.get("matches",12)))
 player._is_lantern_on=bool(state.get("lantern_on",false));player.select_hotbar_slot(int(state.get("active_tool",player.active_hotbar_slot)))
 fires=state.get("fires",[]).duplicate(true);picked=state.get("picked",{}).duplicate();dropped=state.get("dropped",[]).duplicate(true)
 _old_felled=state.get("exterior_felled",{});_old_logs=state.get("exterior_logs",[]);_mine_logs=state.get("mine_logs",[])
 if state.has("rng_state"):rng.state=int(state["rng_state"])
 for n in fire_nodes:
  if is_instance_valid(n):n.free()
 fire_nodes.clear()
 for n in resources.values():
  if is_instance_valid(n):n.free()
 resources.clear();loaded_cells.clear()
 _saved_door_closed=bool(state.get("door_closed",true))
 if is_instance_valid(shelter):shelter.set_door(_saved_door_closed)
 for f in fires:_spawn_fire(f)
 for d in dropped:
  if d.get("location","forest")==location and not picked.has(d["id"]):_spawn_pickup(d["item"],d["id"],_v3(d["pos"]))
 var saved_job:Dictionary=state.get("job",{}).duplicate(true)
 if not saved_job.is_empty():
  job=saved_job
  open_backpack(job.get("fire",""),"rest" if job.get("kind")=="rest" else "camp")
 _update_lighting();ui.refresh()
func prepare_travel() -> void:
 if _transitioning:return
 _transitioning=true;close_backpack();cancel_placement()
 var felled:Dictionary=load("res://scripts/props/TreeChoppable.gd").felled_tree_ids.duplicate(true)
 var logs:Array=[]
 if location=="forest":
  for n in get_tree().get_nodes_in_group("pickup_logs"):logs.append({"species":n.species,"weight":n.weight_kg,"position":_arr(n.global_position)})
  _old_felled=felled;_old_logs=logs
 else:
  _mine_logs=[]
  for n in get_tree().get_nodes_in_group("pickup_logs"):_mine_logs.append({"species":n.species,"weight":n.weight_kg,"position":_arr(n.global_position)})
  felled=_old_felled;logs=_old_logs
 travel={"survival":export_state(),"inventory":player.inventory_slots.duplicate(true),"felled":felled,"logs":logs}
func _restore_exterior_logs(logs: Array) -> void:
 for n in get_tree().get_nodes_in_group("pickup_logs"):n.queue_free()
 for d in logs:
  var n=load("res://scripts/props/LogPickup.gd").new();get_parent().add_child(n);n.global_position=_v3(d["position"]);n.init_log(d["species"],float(d["weight"]))
func _loop_audio(path: String, volume: float) -> AudioStreamPlayer:
 var audio:=AudioStreamPlayer.new();var stream=load(path).duplicate()
 if stream is AudioStreamWAV:stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=int(stream.get_length()*stream.mix_rate)
 elif stream is AudioStreamMP3:stream.loop=true
 audio.stream=stream;audio.volume_db=volume;audio.bus="Ambience" if AudioServer.get_bus_index("Ambience")>=0 else "Master";add_child(audio);audio.play();return audio
func _setup_weather_fx() -> void:
 _rain_audio=_loop_audio("res://assets/sounds/survival/rain_loop.wav",-80)
 _night_audio=_loop_audio("res://assets/sounds/survival/night_loop.wav",-80)
 _wind_audio=_loop_audio("res://assets/sounds/level_01/ambience/amb_forest_bed.mp3",-23)
 _rain=GPUParticles3D.new();_rain.amount=600;_rain.lifetime=0.7;_rain.visibility_aabb=AABB(Vector3(-12,-10,-12),Vector3(24,25,24))
 var p:=ParticleProcessMaterial.new();p.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;p.emission_box_extents=Vector3(9,0.5,9);p.direction=Vector3(0.12,-1,0);p.spread=4;p.initial_velocity_min=17;p.initial_velocity_max=22;p.gravity=Vector3(0,-4,0);_rain.process_material=p
 var mesh:=BoxMesh.new();mesh.size=Vector3(0.008,0.18,0.008);var m:=StandardMaterial3D.new();m.albedo_color=Color(0.6,0.72,0.8,0.4);m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mesh.material=m;_rain.draw_pass_1=mesh;get_parent().add_child(_rain)
func _update_lighting() -> void:
 if location=="mine":
  var entrance=get_parent().get_node_or_null("Geometry/EntranceDaylight")
  if entrance:entrance.light_energy=0.8*daylight()
  return
 var day:=daylight()
 var sun=get_parent().get_node_or_null("DirectionalLight3D")
 if sun:
  sun.rotation_degrees=Vector3(-((hour()-6)/12.0)*180,25,0)
  sun.light_energy=lerpf(0.015,1.3,day)*(0.6 if weather=="rain" else 1)
  sun.light_color=Color(0.55,0.65,1).lerp(Color(1,0.93,0.76),day)
 var envnode=get_parent().get_node_or_null("WorldEnvironment")
 if envnode:
  var env:Environment=envnode.environment
  env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
  env.ambient_light_sky_contribution=0.0
  env.ambient_light_energy=lerpf(0.035,0.7,day)*(0.7 if weather=="rain" else 1)
  env.ambient_light_color=Color(0.3,0.4,0.65).lerp(Color(0.7,0.75,0.8),day)
  env.fog_light_color=Color(0.025,0.04,0.065).lerp(Color(0.65,0.72,0.8),day)
  env.fog_density=0.0015 if weather=="rain" else 0.0008
  var sky=env.sky.sky_material as ProceduralSkyMaterial
  if sky:
   sky.ground_bottom_color=Color(0.005,0.008,0.012).lerp(Color(0.2,0.22,0.2),day)
   sky.ground_horizon_color=Color(0.01,0.018,0.025).lerp(Color(0.55,0.6,0.62),day)
   sky.sky_top_color=Color(0.007,0.012,0.03).lerp(Color(0.38,0.58,0.82),day)
   sky.sky_horizon_color=Color(0.025,0.035,0.065).lerp(Color(0.68,0.76,0.84),day)
 if _rain:
  _rain.global_position=player.global_position+Vector3.UP*10;_rain.emitting=weather=="rain" and not covered()
 if _rain_audio:_rain_audio.volume_db=(-27 if covered() else -15) if weather=="rain" else -80
 if _wind_audio:_wind_audio.volume_db=lerpf(-52,-23,day)
 if _night_audio:_night_audio.volume_db=lerpf(-20,-65,day)
 var phase:="ночь" if day<0.1 else ("сумерки" if hour()>18 else "день")
 if phase!=_last_phase:
  if _last_phase!="":notify("Наступает "+phase+". Подготовьте свет и укрытие.")
  _last_phase=phase
static func _arr(v: Vector3) -> Array:return [v.x,v.y,v.z]
static func _v3(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2]) if a.size()==3 else Vector3.ZERO
