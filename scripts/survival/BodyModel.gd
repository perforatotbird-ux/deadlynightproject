extends RefCounted
# Calories are kcal; activity rates are per GAME hour. Other needs use game minutes.
# Stamina alone uses real seconds; food is a legacy percentage projection.
const LABELS:={"cold":"Переохлаждение","dehydration":"Обезвоживание","starvation":"Голодание","exhaustion":"Истощение","bleeding":"Кровопотеря","fall":"Падение","poison":"Отравление"}
const DEFAULT_TUNING:={"food_awake":0.05,"food_rest":0.035,"food_sprint":0.075,"water_awake":0.085,"water_rest":0.06,"water_sprint":0.14,"cold_damage":0.6,"thirst_damage":0.12,"hunger_damage":0.025,"exhaustion_damage":0.025,"bleed_damage":0.1,"sleep_heal":0.08}
var tuning:Dictionary=DEFAULT_TUNING.duplicate()
const MAX_CALORIES:=2500.0
const CALORIE_RATES:={"sleep":60.0,"idle":80.0,"walk":120.0,"sprint":220.0,"work":160.0}
var calories:=2125.0
# Compatibility projection for alerts, dev controls and pre-calorie saves.
var food:float:
 get:return calories/MAX_CALORIES*100.0
 set(value):calories=bounded(value,0,100)*MAX_CALORIES/100.0
var calorie_rate:=80.0
var calories_burned:=0.0
func burn_rate(resting:bool,sprinting:bool,moving:bool=false,working:bool=false,load_ratio:float=0.0,warmth:float=100.0) -> float:
 var activity:="sleep" if resting else ("sprint" if sprinting else ("work" if working else ("walk" if moving else "idle")))
 var legacy_key:="food_rest" if resting else ("food_sprint" if sprinting else "food_awake")
 var rate:=float(CALORIE_RATES[activity])*float(tuning[legacy_key])/float(DEFAULT_TUNING[legacy_key])
 if not resting and (moving or working or sprinting):rate*=1.0+clampf(load_ratio,0,2)*0.25
 if warmth<35:rate*=1.0+(35.0-maxf(0,warmth))/35.0*0.25
 return rate
func add_calories(amount:float) -> float:
 var before:=calories
 if is_finite(amount):calories=clampf(calories+maxf(0,amount),0,MAX_CALORIES)
 return calories-before
var water:=85.0
var stamina:=100.0
var cold_minutes:=0.0
var warm_minutes:=0.0
var conditions:Dictionary={}
var causes:Dictionary={}
var last_damage:=""
var death_reason:=""
var invulnerable:=false
var freeze_needs:=false
var _winded:=false
func tick(minutes:float,resting:bool,warmth:float,energy:float,sprinting:bool,moving:bool=false,working:bool=false,load_ratio:float=0.0) -> float:
 causes.clear()
 if minutes<=0 or freeze_needs:return 0.0
 var fed_minutes:=0.0 if calories<=0 else minutes
 if not freeze_needs:
  calorie_rate=burn_rate(resting,sprinting,moving,working,load_ratio,warmth)
  if calorie_rate>0:fed_minutes=minf(minutes,calories/calorie_rate*60.0)
  var spent:=minf(calories,minutes/60.0*calorie_rate)
  calories_burned+=spent
  calories=maxf(0,calories-spent)
  water=maxf(0,water-minutes*float(tuning["water_rest" if resting else ("water_sprint" if sprinting else "water_awake")]))
 if warmth<12:
  cold_minutes+=minutes;warm_minutes=0
  causes["cold"]=float(tuning.cold_damage)
  if cold_minutes>=30:conditions["hypothermia"]={"remaining":-1.0}
 elif warmth>45:
  cold_minutes=maxf(0,cold_minutes-minutes*2);warm_minutes+=minutes
  if warm_minutes>=120:conditions.erase("hypothermia")
 else:warm_minutes=0
 if water<=0:causes["dehydration"]=float(tuning.thirst_damage)
 if food<=0:causes["starvation"]=float(tuning.hunger_damage)
 if energy<=0:causes["exhaustion"]=float(tuning.exhaustion_damage)
 if conditions.has("bleeding"):causes["bleeding"]=float(tuning.bleed_damage)
 for id in conditions.keys():
  if id=="sprain":
   conditions[id]["remaining"]=maxf(0,float(conditions[id].get("remaining",240))-minutes*(2 if resting else 1))
   if conditions[id]["remaining"]<=0:conditions.erase(id)
 var poison_damage:=_tick_poison(minutes)
 var damage:=poison_damage
 for id in causes:
  if id!="poison":
   damage+=float(causes[id])*(minutes-fed_minutes if id=="starvation" else minutes)
   last_damage=LABELS.get(id,id)
 if invulnerable:return 0.0
 if damage>0:return -damage
 if resting and warmth>45 and food>0 and water>0 and not conditions.has("hypothermia") and not conditions.has("bleeding") and not conditions.has("poison"):return float(tuning.sleep_heal)*minutes
 return 0.0
func update_stamina(seconds:float,sprinting:bool) -> void:
 if freeze_needs:return
 stamina=clampf(stamina+seconds*(-12.0 if sprinting else (4.0 if poison_active() else 8.0)),0,100)
 if stamina<=5:_winded=true
 elif stamina>=25:_winded=false
func can_sprint(energy:float) -> bool:
 return not _winded and stamina>5 and energy>=10 and not conditions.has("sprain") and not conditions.has("hypothermia") and not poison_limits_effort()
func export_state() -> Dictionary:
 return {"nutrition_version":1,"calories":calories,"calories_burned":calories_burned,"food":food,"water":water,"stamina":stamina,"cold_minutes":cold_minutes,"warm_minutes":warm_minutes,"conditions":conditions.duplicate(true),"last_damage":last_damage,"death_reason":death_reason}
func import_state(data:Dictionary) -> void:
 food=bounded(data.get("food",85),0,100);water=bounded(data.get("water",85),0,100);stamina=bounded(data.get("stamina",100),0,100)
 if data.has("calories"):calories=bounded(data.calories,0,MAX_CALORIES)
 calories_burned=bounded(data.get("calories_burned",0),0,1e12);calorie_rate=100.0
 cold_minutes=bounded(data.get("cold_minutes",0),0,100000);warm_minutes=bounded(data.get("warm_minutes",0),0,100000)
 conditions.clear();causes.clear()
 var saved:Variant=data.get("conditions",{})
 if saved is Dictionary:
  for id in ["bleeding","sprain","hypothermia"]:
   if saved.get(id) is Dictionary:conditions[id]={"remaining":bounded(saved[id].get("remaining",240),-1,100000)}
 var poison:Variant=saved.get("poison",{}) if saved is Dictionary else {}
 if poison is Dictionary and str(poison.get("tier","")) in ["disorder","medium","severe"]:
  conditions["poison"]={"tier":str(poison.tier),"delay":bounded(poison.get("delay",0),0,120),"remaining":bounded(poison.get("remaining",0),0,720),"load":bounded(poison.get("load",1),1,3)}
 last_damage=str(data.get("last_damage",""));death_reason=str(data.get("death_reason",""))
 invulnerable=false;freeze_needs=false;_winded=stamina<=5;tuning=DEFAULT_TUNING.duplicate()
static func bounded(value:Variant,low:float,high:float) -> float:
 var number:=float(value) if value is float or value is int else low
 return clampf(number,low,high) if is_finite(number) else low
func describe() -> String:
 var lines:PackedStringArray=[]
 for id in conditions:
  match id:
   "bleeding":lines.append("Кровотечение — используйте бинт. Потеря здоровья: %.1f%%/игровой час." % (float(tuning.bleed_damage)*60))
   "sprain":lines.append("Травма ноги — компресс или отдых. До восстановления: %.0f мин; бег недоступен." % float(conditions[id].remaining))
   "poison":
    var p:Dictionary=conditions[id]
    lines.append("%s · нагрузка %.0f/3 · %s. Средство от отравления у стоянки и POI; восстанавливайте воду. Сон не лечит яд." % [{"disorder":"Пищевое расстройство","medium":"Среднее отравление","severe":"Тяжёлое отравление"}.get(p.tier,"Отравление"),float(p.load),("начало через %.0f мин" % float(p.delay)) if float(p.delay)>0 else ("осталось %.0f мин" % float(p.remaining))])
   "hypothermia":lines.append("Переохлаждение — согрейтесь выше 45% тепла на 2 игровых часа. Бег и восстановление здоровья ограничены.")
 if lines.is_empty():lines.append("Активных травм и заболеваний нет.")
 for id in causes:lines.append("%s: −%.1f%%/ч" % [LABELS.get(id,id),float(causes[id])*60])
 return "\n".join(lines)

# One bounded toxic burden, not an unbounded list of timed effects.
const POISON_TUNING:={"disorder":{"delay":0.0,"duration":180.0,"damage":0.0,"water":0.04},"medium":{"delay":0.0,"duration":240.0,"damage":0.045,"water":0.05},"severe":{"delay":120.0,"duration":360.0,"damage":0.12,"water":0.10}}
func add_poison(tier:String) -> void:
 if not POISON_TUNING.has(tier):return
 var t:Dictionary=POISON_TUNING[tier]
 if not conditions.has("poison"):
  conditions.poison={"tier":tier,"delay":t.delay,"remaining":t.duration,"load":1.0};return
 var p:Dictionary=conditions.poison
 var rank:={"disorder":0,"medium":1,"severe":2}
 p.load=minf(3,float(p.load)+1)
 if int(rank[tier])>int(rank[p.tier]):
  # Existing symptoms are never deferred by another dose.
  p.delay=minf(float(p.delay),float(t.delay));p.tier=tier
 p.remaining=minf(720,maxf(float(p.remaining),float(t.duration)))
func poison_active() -> bool:return conditions.has("poison") and float(conditions.poison.get("delay",0))<=0 and float(conditions.poison.get("remaining",0))>0
func poison_limits_effort() -> bool:return poison_active() and conditions.poison.tier!="disorder"
func _tick_poison(minutes:float) -> float:
 if not conditions.has("poison"):return 0.0
 var p:Dictionary=conditions.poison;var delay:=float(p.delay);var active_minutes:=minf(float(p.remaining),maxf(0,minutes-delay))
 p.delay=maxf(0,delay-minutes)
 var t:Dictionary=POISON_TUNING[p.tier];var damage:=active_minutes*float(t.damage)*float(p.load)
 water=maxf(0,water-active_minutes*float(t.water)*float(p.load));p.remaining=maxf(0,float(p.remaining)-active_minutes)
 if active_minutes>0:
  causes["poison"]=float(t.damage)*float(p.load);last_damage="Отравление"
  # Damage is integrated for only the active fraction below; do not count it twice.
 if float(p.remaining)<=0:conditions.erase("poison")
 return damage
func refresh_winded() -> void:
 if stamina>=25:_winded=false
