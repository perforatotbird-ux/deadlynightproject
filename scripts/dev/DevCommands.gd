extends RefCounted
# Whitelisted developer operations. No eval, shell commands or arbitrary property paths.
var session:Node
var history:PackedStringArray=[]
const STATS:=["health","warmth","wetness","energy","food","water","stamina","matches"]
func run(command:String,args:Dictionary={}) -> String:
 var answer:=_execute(command,args)
 history.append("%.0f · %s · %s" % [session.clock,command,answer])
 if history.size()>60:history.remove_at(0)
 return answer
func _execute(command:String,args:Dictionary) -> String:
 var s=session;var body=s.body
 match command:
  "stat":
   var key:=str(args.get("key",""));var value:float=float(args.get("value",0))
   if key not in STATS or not is_finite(value):return "Ошибка: неизвестный показатель или нечисловое значение"
   value=clampf(value,0,999 if key=="matches" else 100)
   if key in ["food","water","stamina"]:body.set(key,value)
   elif key=="matches":s.matches=int(value)
   else:s.set(key,value)
   if key=="health":
    if value<=0:body.last_damage="Команда разработчика";s._die()
    else:body.death_reason=""
  "heal":
   s.health=100;s.warmth=80;s.wetness=0;s.energy=100;body.import_state({"food":100,"water":100});s.cancel_job();s.notify("Состояние восстановлено (DEV)")
  "damage":s.apply_damage(clampf(float(args.get("amount",10)),0,100),"Команда разработчика")
  "condition":
   var id:=str(args.get("id",""))
   if id not in ["bleeding","sprain","hypothermia"]:return "Ошибка: неизвестное состояние"
   if bool(args.get("enabled",true)):
    body.conditions[id]={"remaining":240.0 if id=="sprain" else -1.0}
    if id=="hypothermia":body.warm_minutes=0
   else:body.conditions.erase(id)
  "tuning":
   var key:=str(args.get("key",""))
   if not body.tuning.has(key):return "Неизвестный параметр баланса"
   body.tuning[key]=body.bounded(args.get("value",0),0,10)
  "god":body.invulnerable=bool(args.get("enabled",false))
  "needs":body.freeze_needs=bool(args.get("enabled",false))
  "freeze":s.dev_freeze_world=bool(args.get("enabled",false))
  "rate":s.dev_time_rate=clampf(float(args.get("value",1)),0.1,10)
  "events":
   s.dev_events_enabled=bool(args.get("enabled",true))
   if not s.dev_events_enabled:s.atmosphere.suspend();s.sky_events.suspend()
  "clock":
   var hour:=float(args.get("hour",12));var day:=int(args.get("day",1))
   if not is_finite(hour):return "Ошибка времени"
   s.cancel_job();s.atmosphere.suspend();s.sky_events.suspend()
   s.clock=(clampi(day,1,999)-1)*86400.0+clampf(hour,0,23.99)*3600
   s.weather_until=s.clock+4*3600;s.weather_model.reset(s.clock,s.weather=="rain");s._update_lighting()
  "simulate":
   if s.dev_freeze_world:return "Сначала отключите остановку мирового времени"
   var hours:=clampf(float(args.get("hours",1)),0.01,24)
   s.cancel_job();s.atmosphere.suspend();s.sky_events.suspend();s.advance(hours*3600/s.TIME_SCALE);s._update_lighting()
  "weather":
   var kind:=str(args.get("kind","clear"))
   if not s.weather_model.PROFILES.has(kind):return "Ошибка: неизвестная погода"
   s.weather="rain" if kind in ["light_rain","heavy_rain","storm"] else "clear";s.weather_until=s.clock+6*3600
   s.weather_model.reset(s.clock,s.weather=="rain");s.weather_model.rain_style=kind if s.weather=="rain" else "light_rain";s.weather_model.dry_style=kind if s.weather=="clear" else "clear"
   s.weather_visual=s.weather_model.sample(s.clock,s.weather=="rain",s.weather_until,s.daylight());s._update_lighting()
  "give":
   var id:=str(args.get("id",""));var species:=str(args.get("species","birch"))
   if not s.Items.DEFINITIONS.has(id) and id not in ["firewood","log"]:return "Ошибка: неизвестный предмет"
   if species not in ["birch","spruce","beech","oak"]:return "Ошибка породы"
   var info:Dictionary=s.player.SPECIES_ITEM_DATA[species]
   var item:Dictionary=s.Items.item(id,species,float(info.unit_weight)/3.0) if id=="firewood" else s.Items.item(id)
   if id=="log":item={"id":"log_"+species,"type":"log","species":species,"name":str(info.name),"unit_weight":float(info.unit_weight),"count":1,"description":str(info.desc),"burn_time":"—","heat":"—","color":info.color}
   item.count=clampi(int(args.get("count",1)),1,160)
   if not s.Items.transact(s.player,{},[item]):return "Нет свободных ячеек: ничего не выдано"
  "clear_inventory":s.player.inventory_slots.fill(null);s.Items.refresh(s.player)
  "teleport":
   if not teleport(args.get("position",Vector3.ZERO)):return "Отказ: нет безопасной поверхности или место занято"
  "camp":
   if not is_instance_valid(s.shelter):return "Стоянки в этой сцене нет"
   s.cancel_job();s.player.global_position=s.shelter.to_global(Vector3(0,0.25,0));s.player.velocity=Vector3.ZERO;s.player._fall_speed=0
  "scene":
   var target:=str(args.get("location",""))
   if target not in ["mine","forest"] or target==s.location:return "Ошибка перехода"
   s.prepare_travel()
   s.get_tree().call_deferred("change_scene_to_file","res://scenes/mine/MineInterior.tscn" if target=="mine" else "res://scenes/viewer/MapViewer.tscn")
  "door":
   if not is_instance_valid(s.shelter):return "Стоянки в этой сцене нет"
   s.shelter.toggle_door()
  "fire":
   var fire:Dictionary=s.nearby_fire()
   if fire.is_empty():return "Нет доступного костра рядом"
   fire.fuel=clampf(float(args.get("minutes",60)),0,1440)*60;fire.state="burning" if fire.fuel>0 else "cold"
  "collector":s.rain_reserve=clampf(float(args.get("value",6)),0,6)
  "event":
   if s.location!="forest" or s.health<=0:return "События доступны живому игроку в лесу"
   var kind:=str(args.get("kind",""))
   if kind not in ["eyes","orbs","crossing","meteor","anomaly","lightning"]:return "Неизвестное событие"
   s.atmosphere.suspend();s.sky_events.suspend()
   if kind in ["eyes","orbs","crossing"]:
    if not s.atmosphere.try_start_event(kind,false):return "Событие отклонено: освещение/геометрия/дистанция"
   elif kind=="meteor":s.sky_events.start_meteor()
   elif kind=="anomaly":s.sky_events.start_anomaly()
   else:s.sky_events.start_lightning()
  "stop_events":s.atmosphere.suspend();s.sky_events.suspend()
  "snapshot":return snapshot()
  "restore_snapshot":return restore_snapshot()
  "diagnostics":
   var file:=FileAccess.open("user://dev_diagnostics.json",FileAccess.WRITE)
   if file==null:return "Не удалось записать отчёт"
   file.store_string(JSON.stringify(diagnostics(),"  "));return "Отчёт: user://dev_diagnostics.json"
  _:return "Неизвестная команда"
 s.dev_tainted=true;s.ui.refresh()
 return "Выполнено: "+command
func teleport(destination:Vector3) -> bool:
 if not destination.is_finite() or absf(destination.x)>2100 or absf(destination.z)>2100:return false
 var s=session;var player=s.player
 var query:=PhysicsRayQueryParameters3D.create(Vector3(destination.x,500,destination.z),Vector3(destination.x,-100,destination.z),1)
 query.exclude=[player.get_rid()]
 var hit=player.get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty() or not hit.collider.is_in_group("camp_ground") or hit.normal.y<0.75:return false
 var pos:Vector3=hit.position+Vector3.UP*0.2
 var clearance:=PhysicsShapeQueryParameters3D.new();var shape:=CapsuleShape3D.new();shape.radius=0.35;shape.height=1.8;clearance.shape=shape;clearance.transform.origin=pos+Vector3.UP*0.9;clearance.exclude=[player.get_rid()];clearance.collision_mask=1|2|8
 if not player.get_world_3d().direct_space_state.intersect_shape(clearance,1).is_empty():return false
 s.cancel_job();s.cancel_placement();s.atmosphere.suspend();s.sky_events.suspend();player.global_position=pos;player.velocity=Vector3.ZERO;player._fall_speed=0
 return true
func snapshot() -> String:
 var s=session
 var file:=FileAccess.open("user://dev_snapshot.json",FileAccess.WRITE)
 if file==null:return "Ошибка записи снимка"
 var state:Dictionary=s.export_state();state.dev_tainted=true
 file.store_string(JSON.stringify({"version":1,"location":s.location,"position":[s.player.position.x,s.player.position.y,s.player.position.z],"inventory":s.player.inventory_slots,"survival":state},"  "))
 return "Снимок записан отдельно от обычных сохранений: user://dev_snapshot.json"
func restore_snapshot() -> String:
 if not FileAccess.file_exists("user://dev_snapshot.json"):return "Снимка нет"
 var data:Variant=JSON.parse_string(FileAccess.get_file_as_string("user://dev_snapshot.json"))
 if not data is Dictionary or data.get("version")!=1 or data.get("location")!=session.location:return "Нужен снимок версии 1 из текущей сцены"
 if not data.get("inventory") is Array or data.inventory.size()!=session.player.MAX_SLOTS or not data.get("survival") is Dictionary or not data.get("position") is Array or data.position.size()!=3:return "Повреждённый снимок"
 for item in data.inventory:
  if item!=null and (not item is Dictionary or not item.has_all(["id","type","count","unit_weight"])):return "Повреждённый инвентарь"
 session.player.inventory_slots=data.inventory.duplicate(true);session.Items.refresh(session.player);session.import_state(data.survival)
 session.player.position=Vector3(float(data.position[0]),float(data.position[1]),float(data.position[2]));session.player.velocity=Vector3.ZERO;session.player._fall_speed=0;session.dev_tainted=true
 return "Снимок восстановлен. Читы сброшены. Деревья/физические брёвна не входят в снимок."
func diagnostics() -> Dictionary:
 var s=session
 return {"scene":s.location,"position":str(s.player.global_position),"fps":Engine.get_frames_per_second(),"nodes":s.get_tree().get_node_count(),"clock":s.clock,"health":s.health,"body":s.body.export_state(),"job":s.job,"fires":s.fires.size(),"resources":s.resources.size(),"rain_particles":s.rain_field.count,"ground_samples":s.rain_field.ground_samples.size(),"weather":s.weather_model.export_state(),"dev_tainted":s.dev_tainted,"history":Array(history)}
