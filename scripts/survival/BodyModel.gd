extends RefCounted
# Percent reserves; rates are per GAME minute. Stamina alone uses real seconds.
const LABELS:={"cold":"Переохлаждение","dehydration":"Обезвоживание","starvation":"Голодание","exhaustion":"Истощение","bleeding":"Кровопотеря","fall":"Падение"}
const DEFAULT_TUNING:={"food_awake":0.05,"food_rest":0.035,"food_sprint":0.075,"water_awake":0.085,"water_rest":0.06,"water_sprint":0.14,"cold_damage":0.6,"thirst_damage":0.12,"hunger_damage":0.025,"exhaustion_damage":0.025,"bleed_damage":0.1,"sleep_heal":0.08}
var tuning:Dictionary=DEFAULT_TUNING.duplicate()
var food:=85.0
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
func tick(minutes:float,resting:bool,warmth:float,energy:float,sprinting:bool) -> float:
 causes.clear()
 if minutes<=0 or freeze_needs:return 0.0
 if not freeze_needs:
  food=maxf(0,food-minutes*float(tuning["food_rest" if resting else ("food_sprint" if sprinting else "food_awake")]))
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
 var damage:=0.0
 for id in causes:
  damage+=float(causes[id])*minutes;last_damage=LABELS.get(id,id)
 if invulnerable:return 0.0
 if damage>0:return -damage
 if resting and warmth>45 and food>0 and water>0 and not conditions.has("hypothermia") and not conditions.has("bleeding"):return float(tuning.sleep_heal)*minutes
 return 0.0
func update_stamina(seconds:float,sprinting:bool) -> void:
 if freeze_needs:return
 stamina=clampf(stamina+seconds*(-12.0 if sprinting else 8.0),0,100)
 if stamina<=5:_winded=true
 elif stamina>=25:_winded=false
func can_sprint(energy:float) -> bool:
 return not _winded and stamina>5 and energy>=10 and not conditions.has("sprain") and not conditions.has("hypothermia")
func export_state() -> Dictionary:
 return {"food":food,"water":water,"stamina":stamina,"cold_minutes":cold_minutes,"warm_minutes":warm_minutes,"conditions":conditions.duplicate(true),"last_damage":last_damage,"death_reason":death_reason}
func import_state(data:Dictionary) -> void:
 food=bounded(data.get("food",85),0,100);water=bounded(data.get("water",85),0,100);stamina=bounded(data.get("stamina",100),0,100)
 cold_minutes=bounded(data.get("cold_minutes",0),0,100000);warm_minutes=bounded(data.get("warm_minutes",0),0,100000)
 conditions.clear();causes.clear()
 var saved:Variant=data.get("conditions",{})
 if saved is Dictionary:
  for id in ["bleeding","sprain","hypothermia"]:
   if saved.get(id) is Dictionary:conditions[id]={"remaining":bounded(saved[id].get("remaining",240),-1,100000)}
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
   "hypothermia":lines.append("Переохлаждение — согрейтесь выше 45% тепла на 2 игровых часа. Бег и восстановление здоровья ограничены.")
 if lines.is_empty():lines.append("Активных травм и заболеваний нет.")
 for id in causes:lines.append("%s: −%.1f%%/ч" % [LABELS.get(id,id),float(causes[id])*60])
 return "\n".join(lines)
