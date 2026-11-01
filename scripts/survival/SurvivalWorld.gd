extends Node
# One owner for world clock, weather, fire fuel and timed jobs. No OS timers.
const Items = preload("res://scripts/survival/SurvivalItems.gd")
const Fire = preload("res://scripts/survival/FireModel.gd")
const Pickup = preload("res://scripts/survival/ResourcePickup.gd")
const FireVisual = preload("res://scripts/survival/Campfire.gd")
const Shelter = preload("res://scripts/survival/Shelter.gd")
const UI = preload("res://scripts/survival/SurvivalHUD.gd")
const Thermal = preload("res://scripts/survival/ThermalModel.gd")
const WeatherSchedule = preload("res://scripts/weather/WeatherSchedule.gd")
const SeasonModel = preload("res://scripts/weather/SeasonModel.gd")
const WindModel = preload("res://scripts/weather/WindModel.gd")
const TIME_SCALE := 60.0
const BOIL_WORLD_SECONDS:=10.0 # Per 0.5 litre portion.
const SPLIT_SECONDS := 10.0
const CAMP_COST := {"stone":6,"brush":4}
static var travel: Dictionary = {}
var player: Node3D
var location := "forest"
var clock := 16.0*3600.0
var weather := "clear"
var weather_until := 16.0*3600.0+WeatherSchedule.FIRST_DRY_SECONDS
var wetness := 0.0
var warmth := 80.0
var energy := 100.0
var health := 100.0
var body=preload("res://scripts/survival/BodyModel.gd").new()
var rain_reserve:=2.0 # 0.5-litre portions, capped at 6; saved, never refilled on load.
var dev_menu:CanvasLayer
var dev_time_rate:=1.0
var dev_freeze_world:=false
var dev_events_enabled:=true
var dev_tainted:=false
var _last_need_warning:=""
var _supply_setup:=false
var matches := 12
var forest_beds:Array=[]
var bed_nodes:Array=[]
var needle_trees:Dictionary={}
var placement_kind:="camp_kit"
var fires: Array = []
var picked: Dictionary = {}
var resources: Dictionary = {}
var loaded_cells: Dictionary = {}
var dropped: Array = []
var fire_nodes: Array = []
var shelter: Node3D
var ui: CanvasLayer
var woodland:Node3D
var atmosphere: Node3D
var job: Dictionary = {}
var rng := RandomNumberGenerator.new()
var selected_fire := ""
var placing := false
var preview: MeshInstance3D
var placement: Dictionary = {}
var message := "[Tab] Журнал и состояние · Припасы у стоянки к северо-западу · [F8] Dev Menu"
var message_time := 15.0
var _scan := 0.0
var _visual_tick := 0.0
var weather_model=preload("res://scripts/weather/WeatherModel.gd").new()
var sky_renderer:Node3D
var rain_field:Node3D
var sky_events:Node3D
var weather_visual:Dictionary={}
var _rain_audio: AudioStreamPlayer
var _night_audio: AudioStreamPlayer
var _gust_audio:AudioStreamPlayer
var _wind_audio: AudioStreamPlayer
var _last_phase := ""
var _transitioning := false
var _cold_warned := false
var _old_felled: Dictionary = {}
var _old_logs: Array = []
var _mine_logs: Array = []
var _saved_door_closed := true
var _old_damaged:Dictionary={}
var _last_season:=-1
var sleep_point:Node3D
var _physics_ready:=false
var vegetation:Node3D
var foraging=preload("res://scripts/vegetation/ForagingActions.gd").new()

func has_sleep_access() -> bool:
 return is_instance_valid(sleep_point) and sleep_point.has_method("is_sleep_point") and sleep_point.can_interact(player)
func on_forest_bed() -> bool:
 return has_sleep_access() and sleep_point.get_script()==preload("res://scripts/survival/ForestBed.gd")
func safe_sleep_place() -> bool:
 return safe_shelter() or (location=="forest" and on_forest_bed())
func spend_bed(id:String) -> void:
 for bed in forest_beds:
  if str(bed.get("id",""))==id:bed["spent"]=true
 for node in bed_nodes:
  if is_instance_valid(node) and str(node.data.get("id",""))==id:node.refresh()
func record_tree_felling(id:String,species:String,pos:Vector3) -> void:
 vegetation.record_felling(id)
 if species!="spruce" or needle_trees.has(id):return
 needle_trees[id]=true
 var needles:=Items.item("spruce_needles");needles.count=10
 drop_resource(needles,pos+Vector3(0.9,0.12,0))
func _spawn_bed(data:Dictionary) -> void:
 if location!="forest":return
 var node=preload("res://scripts/survival/ForestBed.gd").new();node.session=self;node.data=data
 get_parent().add_child(node);node.global_position=_v3(data.pos);bed_nodes.append(node)
func open_sleep(point:Node3D) -> bool:
 if not is_instance_valid(point) or not point.has_method("is_sleep_point") or not point.can_interact(player):return false
 if health<=0 or placing or not job.is_empty() or (is_instance_valid(dev_menu) and dev_menu.visible) or get_tree().paused:return false
 sleep_point=point
 open_backpack("","rest")
 return true
func revoke_sleep_access() -> void:
 sleep_point=null
 if job.get("kind")=="rest":cancel_job()
 if is_instance_valid(player._backpack_ui):player._backpack_ui.hide_sleep()

func _physics_process(delta:float) -> void:
 if not is_instance_valid(player):return
 _physics_ready=true
 if sleep_point!=null and not has_sleep_access():
  revoke_sleep_access()
  if player._is_inventory_open:close_backpack()
 if location=="forest":
  _scan-=delta
  if _scan<=0:_scan=0.7;_stream_resources()
  if placing:_update_placement()


func _ready() -> void:
 name="SurvivalWorld";add_to_group("survival_session");rng.randomize()
 player=get_parent().get_node_or_null("Player")
 if player==null: return
 player.survival=self
 foraging.session=self
 vegetation=preload("res://scripts/vegetation/VegetationDirector.gd").new();vegetation.session=self;add_child(vegetation)
 location="mine" if get_parent().name=="MineInterior" else "forest"
 ui=UI.new();ui.session=self;add_child(ui)
 weather_model.reset(clock,weather=="rain")
 if location=="forest":_create_shelter();_setup_weather_fx()
 else:_rain_audio=_loop_audio("res://assets/sounds/survival/rain_loop.wav",-80)
 sky_renderer=preload("res://scripts/weather/SkyRenderer.gd").new();sky_renderer.session=self;sky_renderer.model=weather_model;add_child(sky_renderer)
 rain_field=preload("res://scripts/weather/RainField.gd").new();rain_field.session=self;add_child(rain_field)
 sky_events=preload("res://scripts/weather/SkyEvents.gd").new();sky_events.session=self;sky_events.sky=sky_renderer;add_child(sky_events)
 atmosphere=preload("res://scripts/atmosphere/AtmosphereDirector.gd").new();atmosphere.session=self;add_child(atmosphere)
 woodland=preload("res://scripts/atmosphere/WoodlandLife.gd").new();woodland.session=self;add_child(woodland)
 if not travel.is_empty():
  var payload:=travel;travel={}
  player.inventory_slots=payload["inventory"].duplicate(true)
  import_state(payload["survival"]);Items.refresh(player)
  if location=="forest":
   var exit_pos:=Vector3(1125,144,-1203)
   var ground=player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(exit_pos.x,300,exit_pos.z),Vector3(exit_pos.x,-10,exit_pos.z),1))
   if not ground.is_empty():exit_pos.y=ground.position.y+0.2
   player.global_position=exit_pos
   load("res://scripts/props/TreeChoppable.gd").felled_tree_ids=payload.get("felled",{})
   load("res://scripts/props/TreeChoppable.gd").damaged_tree_states=payload.get("damaged",{})
   _restore_exterior_logs(payload.get("logs",[]))
   get_parent().get_node("WorldMap").reconcile_loaded_world()
  else:
   # Forest disk saves omit redundant exterior data, but travel carries it
   # explicitly. Keep it while in the mine so the return/save cannot lose it.
   _old_felled=payload.get("felled",_old_felled)
   _old_damaged=payload.get("damaged",_old_damaged)
   _old_logs=payload.get("logs",_old_logs)
   _restore_exterior_logs(_mine_logs)
 dev_menu=preload("res://scripts/dev/DevMenu.gd").new();dev_menu.session=self;add_child(dev_menu)
 if location=="forest":call_deferred("_setup_supplies")
 _update_lighting()

func notify(text: String) -> void:
 message=text;message_time=6.0
 if is_instance_valid(player):player._show_tool_banner(text)

func _process(delta: float) -> void:
 if not is_instance_valid(player):return
 var sleeping:bool=job.get("kind")=="rest"
 advance(delta*dev_time_rate)
 weather_visual=_apply_wind(weather_model.sample(clock,weather=="rain",weather_until,daylight(),SeasonModel.style_cuts(clock)))
 if not dev_events_enabled:
  # Suppress scheduling, not animation of manually started diagnostic events.
  atmosphere.cooldown=maxf(60,atmosphere.cooldown)
  sky_events.meteor_cooldown=maxf(60,sky_events.meteor_cooldown);sky_events.anomaly_cooldown=maxf(60,sky_events.anomaly_cooldown);sky_events.lightning_cooldown=maxf(60,sky_events.lightning_cooldown)
 sky_events.advance(delta,weather_visual,sleeping)
 rain_field.update_field(delta,weather_visual,int(load("res://scripts/core/SettingsManager.gd").get_instance().get_setting("graphics","rain_quality",1)))
 atmosphere.advance(delta,sleeping)
 woodland.advance(delta,weather_visual,sleeping)
 _visual_tick-=delta
 if _visual_tick<=0:
  _visual_tick=0.2;_update_lighting();ui.refresh()

 message_time=maxf(0,message_time-delta)

func advance(real_seconds: float) -> void:
 # Called by _process, which naturally stops with SceneTree pause.
 if real_seconds<=0 or health<=0 or dev_freeze_world:return
 if not job.is_empty() and not valid_job(job):
  cancel_job();notify("Незавершённое действие повреждено и отменено; игровые предметы не списаны.")
 var remaining:=real_seconds
 # Bounded integration preserves fuel/temperature order during accelerated sleep.
 while remaining>0.00001:
  # Change state at the persisted boundary, not at the end of an oversized
  # step. A loaded active interval is preserved; only future intervals change.
  _advance_weather_if_due()
  var factor:=3600.0 if job.get("kind")=="rest" else TIME_SCALE
  var dt:=minf(remaining,60.0/factor)
  dt=minf(dt,(weather_until-clock)/factor)
  if not job.is_empty():dt=minf(dt,maxf(0.000001,float(job["duration"])-float(job.get("elapsed",0))))
  var precipitation:=rain_intensity()
  var wind_strength:=float(wind().strength)
  # Split at fuel/ember depletion too, so the body still gets the heat for
  # the fraction of the minute during which the fire was actually burning.
  for f in fires:
   var lifetime:=Fire.time_to_change(f,precipitation,wind_strength)
   if lifetime>0:dt=minf(dt,lifetime/factor)
  remaining-=dt
  var world_dt:=dt*factor
  vegetation.advance(world_dt,weather=="rain")
  if precipitation>0:rain_reserve=minf(6,rain_reserve+world_dt/3600.0*precipitation)
  _update_body(world_dt,job.get("kind")=="rest")
  for f in fires:
   Fire.advance(f,world_dt,precipitation>0,precipitation,wind_strength)
   if f["state"]=="burning" and f["fuel"]<600 and not f.get("low_warning",false) and _fire_in_reach(f):
    f["low_warning"]=true
    notify("Костёр скоро погаснет: осталось меньше 10 игровых минут")
   elif f["fuel"]>=600:f["low_warning"]=false
  clock+=world_dt
  _advance_weather_if_due()
  weather_model.sample(clock,weather=="rain",weather_until,daylight(),SeasonModel.style_cuts(clock))
  var season_now:=season_index()
  if _last_season==-1:_last_season=season_now
  elif season_now!=_last_season:
   _last_season=season_now
   notify(SeasonModel.ARRIVAL[_last_season])
  if warmth<20 and not _cold_warned:_cold_warned=true;notify("Опасный холод! Найдите огонь или закрытое укрытие.")
  elif warmth>35:_cold_warned=false
  if health<=0:
   _die();break
  if not job.is_empty():
   if job.get("kind")=="harvest" and not vegetation.harvest_valid(job):
    cancel_job();notify("Сбор прерван: цель недоступна или открыт журнал");continue
   if job.get("kind")=="vegetation_cook" and not foraging.cooking_valid(job):
    cancel_job();notify("Готовка прервана: огонь погас или недоступен; ингредиенты сохранены");continue
   if job.get("kind")=="boil":
    var boiling_fire:=find_fire(str(job.get("fire","")))
    if boiling_fire.is_empty() or boiling_fire.get("state")!="burning" or not _fire_in_reach(boiling_fire):
     cancel_job();notify("Кипячение прервано: огонь погас или недоступен; вода сохранена");continue
   if job.get("kind")=="rest":
    if not has_sleep_access() or not safe_sleep_place() or warmth<20 or body.water<=0 or body.food<=0 or body.conditions.has("bleeding") or body.poison_limits_effort():
     cancel_job();notify("Отдых прерван: холод, открытая дверь, голод, жажда, кровотечение или отравление");continue
   elif player.global_position.distance_to(_v3(job.get("origin",[])))>0.7:
    cancel_job();notify("Действие прервано движением");continue
   job["elapsed"]=float(job.get("elapsed",0))+dt
   if job["elapsed"]+0.000001>=float(job["duration"]):_finish_job()

func _advance_weather_if_due() -> void:
 if clock<weather_until:return
 weather="rain" if weather=="clear" else "clear"
 weather_until=clock+WeatherSchedule.duration(weather,rng)
 weather_model.sample(clock,weather=="rain",weather_until,daylight())
 notify("Начинается дождь: хворост сложнее разжечь" if weather=="rain" else "Дождь закончился")

func hour() -> float:return fposmod(clock,86400.0)/3600.0
func daylight() -> float:return SeasonModel.daylight(clock)
func season_index() -> int:return SeasonModel.season_index(clock)
func season_name() -> String:return SeasonModel.NAMES[season_index()]
func season_day() -> int:return SeasonModel.season_day(clock)
func season_progress() -> float:return SeasonModel.season_progress(clock)
func rain_intensity() -> float:
 return clampf(float(weather_model.sample(clock,weather=="rain",weather_until,daylight(),SeasonModel.style_cuts(clock)).rain),0,1)
func weather_description() -> String:
 var state:Dictionary=weather_model.sample(clock,weather=="rain",weather_until,daylight(),SeasonModel.style_cuts(clock))
 if weather=="clear" and float(state.rain)>0.01:return "дождь стихает"
 if weather=="rain" and float(state.rain)<0.01:return "начинается дождь"
 return {"clear":"ясно","broken":"переменная облачность","overcast":"пасмурно","mist":"туман","light_rain":"небольшой дождь","heavy_rain":"ливень","storm":"гроза"}.get(str(state.kind),"облачно")
func air_temperature() -> float:return SeasonModel.air_temperature(clock,daylight(),rain_intensity())
func wind() -> Dictionary:
 # Deterministic wind from clock + season + precipitation; same clock always
 # reproduces the same wind, so no extra save fields are needed.
 var state:Dictionary=weather_model.sample(clock,weather=="rain",weather_until,daylight(),SeasonModel.style_cuts(clock))
 return WindModel.sample(clock,SeasonModel.wind_base(clock),clampf(float(state.rain),0,1),clampf(float(state.storm),0,1))
func wind_description() -> String:return WindModel.describe(wind())
func wind_move_multiplier(move_dir:Vector3) -> float:
 var w:=wind()
 return WindModel.movement_multiplier(w.direction,float(w.strength),move_dir)
func _apply_wind(state:Dictionary) -> Dictionary:
 # One integration point: the visual weather dict carries the REAL wind for
 # RainField drift, gust audio and anything else reading state.wind.
 if state.is_empty():return state
 var w:=wind()
 state.wind=w.strength
 state.wind_direction=w.direction
 return state
func safe_shelter() -> bool:return location=="forest" and is_instance_valid(shelter) and shelter.contains(player.global_position) and shelter.door_closed
func covered() -> bool:return location=="mine" or (is_instance_valid(shelter) and shelter.contains(player.global_position))
func heat_at_player() -> float:
 if location!="forest":return 0
 var heat:=0.0
 for f in fires:
  if f["state"] not in ["burning","embers"]:continue
  var pos:=_v3(f["pos"]);var dist:=player.global_position.distance_to(pos)
  if dist>Thermal.HEAT_RADIUS:continue
  var q:=PhysicsRayQueryParameters3D.create(pos+Vector3.UP*0.7,player.global_position+Vector3.UP,1)
  q.exclude=[player.get_rid()]
  if player.is_inside_tree() and not player.get_world_3d().direct_space_state.intersect_ray(q).is_empty():continue
  heat=maxf(heat,Thermal.fire_heat(dist,str(f["state"])))
 return heat
func thermal_status(seconds:float=0.0) -> Dictionary:
 var state:Dictionary=weather_model.sample(clock,weather=="rain",weather_until,daylight(),SeasonModel.style_cuts(clock))
 var precipitation:=clampf(float(state.rain),0,1)
 var air:=SeasonModel.air_temperature(clock,daylight(),precipitation)
 var bed_rest:bool=job.get("kind")=="rest" and on_forest_bed()
 return Thermal.step(wetness,seconds,air+(8.0 if bed_rest else 0.0),heat_at_player(),float(wind().strength)*(0.3 if bed_rest else 1.0),precipitation,covered(),safe_shelter(),location=="mine")
func thermal_description() -> String:
 var t:=thermal_status()
 var warmth_rate:float=t.warmth_rate;var wet_rate:float=t.wet_rate
 if (warmth>=100 and warmth_rate>0) or (warmth<=0 and warmth_rate<0):warmth_rate=0
 if (wetness>=100 and wet_rate>0) or (wetness<=0 and wet_rate<0):wet_rate=0
 var wind_line:=""
 var wind_strength:=float(wind().strength)
 if not covered() and wind_strength>=0.35:wind_line="Ветер: "+wind_description()+". Встречный ветер выстуживает быстрее.\n"
 return "Воздух %.1f °C · ощущается %.1f °C\n%sТепло: %+.1f%%/игр. мин · сырость: %+.1f%%/игр. мин\n%s" % [air_temperature(),float(t.felt),wind_line,warmth_rate,wet_rate,"Огонь согревает и сушит; сильнее всего в 1–2 м." if float(t.heat)>0 else ("Под крышей: защита от осадков, постепенная сушка." if covered() else "Сырость усиливает холод. Ищите огонь или укрытие.")]
func _update_body(world_dt: float, resting: bool) -> void:
 if body.freeze_needs:body.causes.clear();return
 var minutes:=world_dt/60.0
 var thermal:=thermal_status(world_dt)
 wetness=float(thermal.wetness)
 warmth=clampf(warmth+float(thermal.warmth_delta),0,100)
 var moving:bool=Vector2(player.velocity.x,player.velocity.z).length()>0.2
 var sprinting:bool=moving and (player._is_action_down("sprint") or player._is_sprint_jumping) and not player._is_crouching and body.can_sprint(energy)
 var effort:=0.09+(0.10 if sprinting else 0.0)+(0.08 if job.get("kind")=="split" or player._is_lmb_held else 0.0)
 if moving:
  var w:=wind()
  effort+=0.04*maxf(0.0,WindModel.headwind(w.direction,Vector3(player.velocity.x,0,player.velocity.z)))*float(w.strength)
 if not body.freeze_needs:energy=clampf(energy+minutes*(0.5 if resting and warmth>=20 else -effort),0,100)
 health=clampf(health+body.tick(minutes,resting,warmth,energy,sprinting,moving,job.get("kind")=="split" or player._is_lmb_held,player.backpack_weight/maxf(1,player.max_backpack_kg)),0,100)
 var warning:=""
 if body.water<15:warning="Мало воды. Пейте безопасную воду; сырую кипятите у костра."
 elif body.food<15:warning="Вы голодны. Найдите еду или соберите съедобные ягоды."
 elif energy<15:warning="Вы устали. Подготовьте стоянку и поспите."
 if warning!=_last_need_warning:
  _last_need_warning=warning
  if warning!="":notify(warning)

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
 if page=="rest" and has_sleep_access():player._backpack_ui.focus_rest()
 elif fire_id!="":player._backpack_ui.focus_fire()
func close_backpack() -> void:
 cancel_job()
 if is_instance_valid(player._backpack_ui):player._backpack_ui.hide_context_pages()
 sleep_point=null
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
 return make_recipe("camp_kit")
func make_recipe(recipe_id:String, amount:int=1) -> bool:
 if amount<1 or amount>1000:return false
 if health<=0:return false
 if not job.is_empty():return false
 var r:Dictionary=preload("res://scripts/survival/CraftCatalog.gd").recipe(recipe_id)
 if r.get("id")!=recipe_id or r.get("action")!="kit":return false
 var costs:Dictionary=r.costs.duplicate()
 for id in costs:costs[id]*=amount
 var output:=Items.item(recipe_id);output.count=amount
 var ok:=Items.transact(player,costs,[output])
 notify("Создано: "+str(Items.item(recipe_id).name) if ok else "Не хватает материалов или места в рюкзаке")
 ui.refresh();return ok
func valid_job(data:Dictionary) -> bool:
 if data.get("kind","") not in ["rest","split","ignite","boil","harvest","vegetation_cook"]:return false
 var duration=body.bounded(data.get("duration",0),0,100000)
 var elapsed=body.bounded(data.get("elapsed",0),0,100000)
 if duration<=0 or elapsed>duration:return false
 if not data.get("origin") is Array or data.origin.size()!=3:return false
 if data.kind=="harvest":return data.get("plant") is Dictionary and data.get("point") is Array and data.get("group") is int and duration<=2
 if data.kind=="vegetation_cook":return data.get("fire") is String and not foraging.cook_recipe(str(data.get("recipe","")),int(data.get("amount",0))).is_empty() and is_equal_approx(duration,float(foraging.cook_recipe(str(data.recipe),int(data.amount)).minutes))
 if data.kind=="split":
  var amount=body.bounded(data.get("amount",1),0,1000)
  return data.has("slot") and data.has("item_id") and data.has("weight") and data.has("species") and amount>=1 and amount==int(amount) and is_equal_approx(duration,SPLIT_SECONDS*amount)
 if data.kind=="boil":
  var amount=body.bounded(data.get("amount",1),0,1000)
  return data.get("fire") is String and amount>=1 and amount==int(amount) and is_equal_approx(duration,amount*BOIL_WORLD_SECONDS/TIME_SCALE)
 if data.kind=="ignite":return data.get("fire") is String and data.has("success")
 return duration<=12
func begin_split(slot_index: int, amount:int=1) -> bool:
 if not job.is_empty() or slot_index<0 or slot_index>=player.inventory_slots.size():return false
 var s=player.inventory_slots[slot_index]
 if s==null or s.get("type")!="log" or amount<1 or amount>int(s.get("count",0)):return false
 if health<=0 or not player._is_inventory_open:return false
 player.select_hotbar_slot(0)
 job={"kind":"split","elapsed":0.0,"duration":SPLIT_SECONDS*amount,"amount":amount,"slot":slot_index,"item_id":s["id"],"weight":s["unit_weight"],"species":s["species"],"origin":_arr(player.global_position)}
 player._cancel_chop();ui.refresh();return true
func add_fuel(id: String, slot_index: int, amount: int = 1) -> bool:
 var f:=find_fire(id)
 if f.is_empty() or not _fire_in_reach(f) or not job.is_empty():return false
 if slot_index<0 or slot_index>=player.inventory_slots.size():return false
 var s=player.inventory_slots[slot_index]
 if s==null or s.get("type") not in ["firewood","brush"] or amount<1 or amount>int(s.get("count",0)):return false
 var seconds:=Fire.BRANCH_FUEL_SECONDS if s["type"]=="brush" else float(Fire.FUEL_SECONDS.get(s.get("species","birch"),1800.0))
 if not Items.transact(player,{s["id"]:amount},[],slot_index):return false
 Fire.add_fuel(f,seconds*amount);notify("Топливо добавлено");ui.refresh();return true
func add_tinder(id: String) -> bool:
 var f:=find_fire(id)
 if f.is_empty() or not _fire_in_reach(f) or not job.is_empty():return false
 if not Items.transact(player,{"tinder":1}):notify("Нужен хворост для растопки");return false
 f["tinder"]+=1;ui.refresh();return true
func ignition_chance(method: String, fire_id:String="") -> float:
 var f:=find_fire(fire_id if fire_id!="" else selected_fire)
 if f.is_empty() or int(f.get("tinder",0))<=0 or float(f.get("fuel",0))<=0:return 0.0
 return Fire.chance(method,wetness,rain_intensity()>0,rain_intensity(),float(wind().strength))
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
 var chance:=ignition_chance(method,id)
 f["tinder"]-=1
 for node in fire_nodes:
  if is_instance_valid(node) and node.data["id"]==id:node.ignition_fx(method)
 # Persist a pre-rolled outcome: loading an in-progress attempt cannot reroll it.
 var success:=rng.randf()<chance
 job={"kind":"ignite","elapsed":0.0,"duration":2.0 if method=="match" else 5.0,"fire":id,"success":success,"origin":_arr(player.global_position)}
 notify("Розжиг: спичка и растопка потрачены" if method=="match" else "Высекаете искру: растопка потрачена");ui.refresh();return true
func _fire_in_reach(f: Dictionary) -> bool:
 if location!="forest" or player.global_position.distance_to(_v3(f["pos"]))>3.3:return false
 var q:=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP,_v3(f["pos"])+Vector3.UP*0.4,1)
 var excluded:Array[RID]=[player.get_rid()]
 for n in fire_nodes:
  if is_instance_valid(n) and n.data.get("id")==f.get("id"):excluded.append(n.get_rid())
 q.exclude=excluded
 return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
func rest_block_reason() -> String:
 if health<=0:return "Нельзя спать: персонаж погиб."
 if not job.is_empty():return "Сначала завершите или отмените текущее действие."
 if not has_sleep_access():return "Подойдите к действительной точке сна и нажмите E."
 if location!="forest":return "Нужна точка сна в лесу."
 if not on_forest_bed():
  if not covered():return "Нужна койка в лесной стоянке."
  if not safe_shelter():return "Закройте дверь стоянки."
 if warmth<20:return "Слишком холодно для сна. Сначала согрейтесь."
 if body.water<=0 or body.food<=0:return "Перед сном нужно поесть и попить."
 if body.conditions.has("bleeding"):return "Сначала остановите кровотечение."
 if body.poison_limits_effort():return "Сначала примите средство от отравления: симптомы прерывают сон."
 return ""
func begin_rest(hours: int = 1) -> bool:
 var reason:=rest_block_reason()
 if reason!="":notify(reason);return false
 if hours<1 or hours>12:notify("Выберите от 1 до 12 часов сна");return false
 job={"kind":"rest","elapsed":0.0,"duration":float(hours),"hours":hours,"origin":_arr(player.global_position)}
 if on_forest_bed():job["bed_id"]=str(sleep_point.data.id)
 ui.refresh();return true
func cancel_job() -> void:
 if job.get("kind")=="rest" and job.has("bed_id") and float(job.get("elapsed",0))>0:spend_bed(str(job.bed_id))
 job={}
func _finish_job() -> void:
 var done:=job.duplicate(true);job={}
 match done["kind"]:
  "harvest":vegetation.commit_harvest(done)
  "vegetation_cook":foraging.finish_cook(done)
  "split":
   var index:=int(done["slot"])
   var s=player.inventory_slots[index] if index>=0 and index<player.inventory_slots.size() else null
   if s==null or s.get("id")!=done["item_id"] or not is_equal_approx(float(s.get("unit_weight",0)),float(done["weight"])):notify("Бревно перемещено: раскол отменён");return
   var output:=Items.item("firewood",done["species"],float(done["weight"])/3.0);output["count"]=3*int(done.get("amount",1))
   notify("Расколото брёвен: %d · поленьев: %d" % [int(done.get("amount",1)),int(output.count)] if Items.transact(player,{done["item_id"]:int(done.get("amount",1))},[output],index) else "Не хватает места: бревно сохранено")
  "ignite":
   var f:=find_fire(done["fire"])
   if not f.is_empty() and _fire_in_reach(f) and f["fuel"]>0 and done["success"]:f["state"]="burning";notify("Костёр разгорелся")
   else:notify("Розжиг не удался. Добавьте растопку и попробуйте ещё раз.")
  "boil":
   var f:=find_fire(str(done.get("fire","")))
   if f.is_empty() or f.get("state")!="burning" or not _fire_in_reach(f):notify("Кипячение прервано: нужен горящий костёр рядом.")
   else:
    var output:=Items.item("water");output.count=int(done.get("amount",1))
    notify("Готово: %.1f л питьевой воды" % (output.count*0.5) if Items.transact(player,{"raw_water":output.count},[output]) else "Вода сохранена: нет сырой воды или места в рюкзаке")
  "rest":
   if done.has("bed_id"):spend_bed(str(done.bed_id))
   notify("Сон завершён: %d ч" % int(done.get("hours",1)))
 ui.refresh()

func begin_placement(item_id:String="camp_kit") -> void:
 if placing or not job.is_empty() or health<=0:return
 if item_id not in ["camp_kit","forest_bed"]:return
 if location!="forest" or Items.count(player.inventory_slots,item_id)==0:notify("Сначала создайте предмет");return
 placement_kind=item_id
 close_backpack();placing=true
 preview=MeshInstance3D.new();var c:=CylinderMesh.new();c.top_radius=0.65;c.bottom_radius=0.65;c.height=0.06;preview.mesh=c
 if placement_kind=="forest_bed":
  var box:=BoxMesh.new();box.size=Vector3(1.0,0.08,2.0);preview.mesh=box
 var m:=StandardMaterial3D.new();m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;preview.material_override=m;get_parent().add_child(preview)
 notify("ЛКМ — поставить · ПКМ / Esc — отмена. Нужна ровная открытая земля.")
func validate_placement(pos: Vector3, normal: Vector3, surface: Object = null) -> Dictionary:
 if normal.dot(Vector3.UP)<cos(deg_to_rad(12)):return {"ok":false,"reason":"Слишком крутой склон"}
 if surface!=null:
  var n:Node=surface as Node
  if n and (n.is_in_group("water") or "water" in str(n.name).to_lower()):return {"ok":false,"reason":"Нельзя размещать в воде"}
 var space=player.get_world_3d().direct_space_state
 var offsets:=[Vector3.ZERO,Vector3(0.65,0,0),Vector3(-0.65,0,0),Vector3(0,0,0.65),Vector3(0,0,-0.65)]
 if placement_kind=="forest_bed":offsets=[Vector3.ZERO,Vector3(0.6,0,1.05),Vector3(-0.6,0,1.05),Vector3(0.6,0,-1.05),Vector3(-0.6,0,-1.05)]
 for offset in offsets:
  var p:Vector3=pos+offset
  var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.5,p-Vector3.UP*0.5,1))
  if not hit.is_empty() and not hit.collider.is_in_group("camp_ground"):return {"ok":false,"reason":"Костёр можно ставить только на земле, не на сооружениях"}
  if hit.is_empty() or absf(hit.position.y-pos.y)>0.12:return {"ok":false,"reason":"Площадка неровная или край обрыва"}
 var ceiling=space.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3.UP*0.15,pos+Vector3.UP*4,1))
 if not ceiling.is_empty():return {"ok":false,"reason":"Костёр нельзя ставить под крышей или мостом"}
 var shape:Shape3D
 if placement_kind=="forest_bed":
  var box:=BoxShape3D.new();box.size=Vector3(1.2,0.5,2.2);shape=box
 else:
  var cylinder:=CylinderShape3D.new();cylinder.radius=0.78;cylinder.height=0.5;shape=cylinder
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
 if not Items.transact(player,{placement_kind:1}):cancel_placement();return false
 if placement_kind=="forest_bed":
  var bed:={"id":"bed_%d_%d" % [int(clock*100),rng.randi()],"pos":_arr(pos),"spent":false}
  forest_beds.append(bed);_spawn_bed(bed);cancel_placement();notify("Лесная кровать установлена. [E] — один ночлег.");return true
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
 if not _physics_ready:return
 for d in dropped:
  if d.get("location","forest")==location and not picked.has(d["id"]) and Vector2(_v3(d["pos"]).x-player.global_position.x,_v3(d["pos"]).z-player.global_position.z).length()<60:_spawn_pickup(d["item"],d["id"],_v3(d["pos"]))
 if is_instance_valid(shelter) and player.global_position.distance_to(shelter.global_position)<60:_spawn_supplies()
 # Deterministic, finite per-cell resources; collected IDs survive unloading/loading.
 var center:=Vector2i(floori(player.global_position.x/24),floori(player.global_position.z/24))
 for x in range(center.x-1,center.x+2):
  for z in range(center.y-1,center.y+2):
   var key:="%d:%d" % [x,z]
   if loaded_cells.has(key):continue
   loaded_cells[key]=true
   var random:=RandomNumberGenerator.new();random.seed=hash("DeadlyNight:"+key)
   var types=["brush","brush","brush","brush","stone","stone","stone","stone","flint","pyrite","berries"]
   if posmod(hash("berry-density:"+key),2)==0:types[10]="brush"
   for i in types.size():
    var id:=key+":"+str(i)
    var pos:=Vector3(x*24+random.randf_range(2,22),player.global_position.y,z*24+random.randf_range(2,22))
    if picked.has(id) or types[i]=="berries":continue
    var query:=PhysicsRayQueryParameters3D.create(Vector3(pos.x,1024,pos.z),Vector3(pos.x,-512,pos.z),1)
    query.exclude=[player.get_rid()]
    var hit=player.get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty() or hit.normal.y<0.8 or not hit.collider.is_in_group("camp_ground"):continue
    # Avoid authored cabin floor/roof: scatter only terrain, never structures.
    if is_instance_valid(shelter) and Vector2(pos.x-shelter.global_position.x,pos.z-shelter.global_position.z).length()<3.5:continue
    _spawn_pickup(Items.item(types[i]),id,hit.position)
 for id in resources.keys():
  var n=resources[id]
  if is_instance_valid(n) and Vector2(n.global_position.x-player.global_position.x,n.global_position.z-player.global_position.z).length()>65:
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
 var state:={"version":4,"forest_beds":forest_beds.duplicate(true),"needle_trees":needle_trees.duplicate(),"vegetation":vegetation.export_state(),"body":body.export_state(),"rain_reserve":rain_reserve,"dev_tainted":dev_tainted,"sky_weather":weather_model.export_state(),"sky_events":sky_events.export_state() if is_instance_valid(sky_events) else {},"atmosphere":atmosphere.export_state(),"clock":clock,"weather":weather,"weather_until":weather_until,"wetness":wetness,"warmth":warmth,"energy":energy,"health":health,"matches":matches,"active_tool":player.active_hotbar_slot,"belt_items":player.belt_items.duplicate(),"lantern_on":player._is_lantern_on,"fires":fires.duplicate(true),"picked":picked.duplicate(),"dropped":dropped.duplicate(true),"job":job.duplicate(true),"rng_state":str(rng.state),"location":location,"door_closed":shelter.door_closed if is_instance_valid(shelter) else _saved_door_closed,"exterior_felled":_old_felled if location=="mine" else {},"exterior_damaged":_old_damaged if location=="mine" else {},"exterior_logs":_old_logs if location=="mine" else [],"mine_logs":_mine_logs}
 return state
func import_state(state: Dictionary) -> void:
 close_backpack();cancel_placement()
 body.import_state(state.get("body",{}));rain_reserve=body.bounded(state.get("rain_reserve",2),0,6)
 dev_time_rate=1.0;dev_freeze_world=false;dev_events_enabled=true;dev_tainted=bool(state.get("dev_tainted",false))
 clock=float(state.get("clock",16*3600));weather=state.get("weather","clear");weather_until=float(state.get("weather_until",clock+7200))
 wetness=clampf(float(state.get("wetness",0)),0,100);warmth=clampf(float(state.get("warmth",80)),0,100);energy=clampf(float(state.get("energy",100)),0,100);health=clampf(float(state.get("health",100)),0,100);matches=maxi(0,int(state.get("matches",12)))
 player.belt_items=state.get("belt_items",["","",""]).duplicate();player.belt_items.resize(3)
 player._refresh_belt_labels()
 player._is_lantern_on=bool(state.get("lantern_on",false));player.select_hotbar_slot(int(state.get("active_tool",player.active_hotbar_slot)))
 for node in bed_nodes:
  if is_instance_valid(node):node.free()
 bed_nodes.clear();sleep_point=null
 forest_beds=state.get("forest_beds",[]).duplicate(true);needle_trees=state.get("needle_trees",{}).duplicate()
 for bed in forest_beds:_spawn_bed(bed)
 fires=state.get("fires",[]).duplicate(true);picked=state.get("picked",{}).duplicate();dropped=state.get("dropped",[]).duplicate(true)
 _old_damaged=state.get("exterior_damaged",{});_old_felled=state.get("exterior_felled",{});_old_logs=state.get("exterior_logs",[]);_mine_logs=state.get("mine_logs",[])
 vegetation.import_state(state.get("vegetation",{}),picked)
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
 if saved_job.get("kind")=="boil" and not saved_job.has("amount"):
  saved_job["amount"]=1
  var ratio:=clampf(float(saved_job.get("elapsed",0))/maxf(0.001,float(saved_job.get("duration",5))),0,1)
  saved_job["duration"]=BOIL_WORLD_SECONDS/TIME_SCALE;saved_job["elapsed"]=ratio*saved_job.duration
 if not saved_job.is_empty() and valid_job(saved_job) and saved_job.get("kind")!="harvest":
  job=saved_job
  if job.get("kind")=="rest":
   if job.has("bed_id"):
    for node in bed_nodes:
     if str(node.data.get("id",""))==str(job.bed_id) and node.can_interact(player):sleep_point=node
    if not is_instance_valid(sleep_point):job={}
   elif is_instance_valid(shelter) and shelter.bed.can_interact(player):sleep_point=shelter.bed
   else:job={}
   player._backpack_ui.sleep_hours.value=clampi(int(saved_job.get("hours",saved_job.get("duration",1))),1,12)
  if not job.is_empty():open_backpack(job.get("fire",""),"rest" if job.get("kind")=="rest" else "camp")
 weather_model.import_state(state.get("sky_weather",{}),clock,weather=="rain")
 if is_instance_valid(sky_events):sky_events.import_state(state.get("sky_events",{}))
 atmosphere.import_state(state.get("atmosphere",{}))
 if _supply_setup:_spawn_supplies()
 _update_lighting();ui.refresh()
func prepare_travel() -> void:
 if _transitioning:return
 _transitioning=true;close_backpack();cancel_placement();atmosphere.suspend()
 if is_instance_valid(sky_events):sky_events.suspend()
 var trees=load("res://scripts/props/TreeChoppable.gd")
 var felled:Dictionary=trees.compact_felled_registry()
 var damaged:Dictionary=trees.damaged_tree_states.duplicate(true)
 var logs:Array=[]
 if location=="forest":
  for n in get_tree().get_nodes_in_group("pickup_logs"):logs.append({"species":n.species,"weight":n.weight_kg,"position":_arr(n.global_position)})
  _old_felled=felled;_old_damaged=damaged;_old_logs=logs
 else:
  _mine_logs=[]
  for n in get_tree().get_nodes_in_group("pickup_logs"):_mine_logs.append({"species":n.species,"weight":n.weight_kg,"position":_arr(n.global_position)})
  felled=_old_felled;damaged=_old_damaged;logs=_old_logs
 travel={"survival":export_state(),"inventory":player.inventory_slots.duplicate(true),"felled":felled,"damaged":damaged,"logs":logs}
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
 _gust_audio=_loop_audio("res://assets/sounds/level_01/ambience/amb_wind_canopy.wav",-80)
 _wind_audio=_loop_audio("res://assets/sounds/level_01/ambience/amb_forest_bed.mp3",-23)
func _update_lighting() -> void:
 var day:=daylight()
 weather_visual=_apply_wind(weather_model.sample(clock,weather=="rain",weather_until,day,SeasonModel.style_cuts(clock)))
 if location=="mine":
  var entrance=get_parent().get_node_or_null("Geometry/EntranceDaylight")
  if entrance:entrance.light_energy=0.8*daylight()
  if _rain_audio:
   var settings=load("res://scripts/core/SettingsManager.gd").get_instance()
   _rain_audio.volume_db=lerpf(-80,-44,weather_visual.rain)+linear_to_db(maxf(0.0001,float(settings.get_setting("audio","weather_volume",0.85))))
  return
 if is_instance_valid(sky_renderer):sky_renderer.update_sky(weather_visual,sky_events.flash if is_instance_valid(sky_events) else 0.0)
 var sm=load("res://scripts/core/SettingsManager.gd").get_instance()
 var weather_gain:=linear_to_db(maxf(0.0001,float(sm.get_setting("audio","weather_volume",0.85))))
 if _rain_audio:_rain_audio.volume_db=lerpf(-60,-15,weather_visual.rain)+(-12 if covered() else 0)+weather_gain
 if _wind_audio:_wind_audio.volume_db=lerpf(-44,-21,maxf(day*0.5,weather_visual.wind))+weather_gain
 if _gust_audio:_gust_audio.volume_db=lerpf(-55,-19,weather_visual.wind)+weather_gain+(-10 if covered() else 0)
 if _night_audio:_night_audio.volume_db=lerpf(-20,-65,day)-(10*woodland.quiet_gain if is_instance_valid(woodland) else 0)
 var phase:="ночь" if day<0.1 else ("сумерки" if hour()>18 else "день")
 if phase!=_last_phase:
  if _last_phase!="":notify("Наступает "+phase+". Подготовьте свет и укрытие.")
  _last_phase=phase
static func _arr(v: Vector3) -> Array:return [v.x,v.y,v.z]
static func _v3(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2]) if a.size()==3 else Vector3.ZERO

func _die() -> void:
 job={};cancel_placement()
 if is_instance_valid(player):player._cancel_chop()
 if body.death_reason=="":body.death_reason=body.last_damage if body.last_damage!="" else "Истощение"
 notify("Вы погибли: %s. Esc — загрузить сохранение." % body.death_reason)
 if is_instance_valid(atmosphere):atmosphere.suspend()
 if is_instance_valid(sky_events):sky_events.suspend()
func apply_damage(amount:float,cause:String) -> void:
 if health<=0 or body.invulnerable or not is_finite(amount) or amount<=0:return
 health=maxf(0,health-amount);body.causes.clear();body.last_damage=cause
 if health<=0:_die()
func land(impact_speed:float,drop_height:float=-1.0) -> void:
 if not is_finite(impact_speed) or (drop_height>=0 and drop_height<2.5):return
 if impact_speed<12 or body.invulnerable or health<=0:return
 apply_damage((impact_speed-10)*4,"Падение")
 if health<=0:return
 body.conditions["sprain"]={"remaining":240.0}
 if impact_speed>=16:body.conditions["bleeding"]={"remaining":-1.0}
 notify("Травма после падения. Откройте «Состояние» в журнале.")
func request_use_supply(slot:int) -> bool:return foraging.request_use(slot)
func use_supply(slot:int,confirmed_unknown:bool=false) -> bool:
 if health<=0 or not job.is_empty() or slot<0 or slot>=player.inventory_slots.size():return false
 var item=player.inventory_slots[slot]
 if item==null:return false
 var kind:String=item.get("type","")
 if Items.Vegetation.is_food(kind) or kind=="antitoxin":return foraging.use(slot,confirmed_unknown)
 if kind=="raw_water":return begin_boil()
 if kind not in ["water","ration","berries","bandage","compress"]:return false
 if kind=="water" and body.water>=100:notify("Запас воды полон");return false
 if kind in ["ration","berries"] and body.food>=100:notify("Вы сыты");return false
 if kind=="bandage" and not body.conditions.has("bleeding"):notify("Нет кровотечения");return false
 if kind=="compress" and not body.conditions.has("sprain"):notify("Нет травмы ноги");return false
 if not Items.transact(player,{item.id:1},[],slot):return false
 match kind:
  "water":body.water=minf(100,body.water+Items.WATER_RESTORE)
  "ration":body.add_calories(Items.calories_for(kind))
  "berries":body.add_calories(Items.calories_for(kind))
  "bandage":body.conditions.erase("bleeding")
  "compress":body.conditions.erase("sprain")
 notify("Использовано: "+str(item.name));ui.refresh();return true
func begin_boil(amount:int=1) -> bool:
 if amount<1 or amount>1000 or health<=0 or not job.is_empty() or Items.count(player.inventory_slots,"raw_water")<amount:return false
 var f:=nearby_fire()
 if f.is_empty() or f.get("state")!="burning":notify("Для кипячения нужен горящий костёр рядом");return false
 var output:=Items.item("water");output.count=amount
 if not Items.transact(player,{"raw_water":amount},[output],-1,true):notify("Нет места для питьевой воды");return false
 job={"kind":"boil","elapsed":0.0,"duration":amount*BOIL_WORLD_SECONDS/TIME_SCALE,"amount":amount,"fire":f.id,"origin":_arr(player.global_position)}
 notify("Кипячение %.1f л: %.0f игровых секунд. Вода расходуется только при завершении." % [amount*0.5,amount*BOIL_WORLD_SECONDS]);return true
func _setup_supplies() -> void:
 if _supply_setup or not is_instance_valid(shelter):return
 _supply_setup=true
 _spawn_supplies()
 var collector=preload("res://scripts/survival/RainCollector.gd").new();collector.session=self;get_parent().add_child(collector);collector.global_position=shelter.to_global(Vector3(3.2,0,0))

func _spawn_supplies() -> void:
 if not is_instance_valid(shelter):return
 var supply_ids:=["ration","ration","water","water","bandage","bandage","compress","antitoxin","antitoxin","field_notes"]
 for i in supply_ids.size():
  var id:="camp_supply_"+str(i)
  if not picked.has(id):_spawn_pickup(Items.item(supply_ids[i]),id,shelter.to_global(Vector3(-1.2+(i%4)*0.65,0.15,0.1+(i/4)*0.6)))
