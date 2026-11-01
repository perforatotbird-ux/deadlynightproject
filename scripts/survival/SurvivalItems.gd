extends RefCounted
# All recipes use the existing backpack. Transactions commit only if outputs fit.
const Vegetation = preload("res://scripts/vegetation/VegetationCatalog.gd")
const WATER_RESTORE:=35.0
const DEFINITIONS = {
 "spruce_needles":{"name":"Еловая хвоя","unit_weight":0.03,"description":"Материал для лесной кровати. Сбор после рубки ели."},
 "forest_bed":{"name":"Лесная кровать","unit_weight":2.7,"description":"20 веток и 10 единиц еловой хвои. Разместите на земле: один ночлег, затем непригодна. Не заменяет крышу и костёр."},
 "field_notes": {"name":"Памятка грибника","unit_weight":0.02,"description":"Вымышленные островные виды: признаки, приготовление и предупреждения об отравлении."},
 "water": {"name":"Питьевая вода · 0,5 л", "unit_weight":0.5, "description":"Безопасная вода. Восстанавливает 35% запаса воды."},
 "raw_water": {"name":"Сырая вода · 0,5 л", "unit_weight":0.5, "description":"Нужно кипятить у горящего костра. Пить сырой нельзя."},
 "ration": {"name":"Походный рацион", "unit_weight":0.3, "description":"Готовая еда. 1125 ккал на порцию."},
 "berries": {"name":"Перезимовавшая клюква", "unit_weight":0.15, "description":"Ограниченный тестовый весенний сбор перезимовавших ягод. 300 ккал на порцию."},
 "bandage": {"name":"Бинт", "unit_weight":0.05, "description":"Останавливает кровотечение, но не возвращает здоровье."},
 "compress": {"name":"Компресс для ноги", "unit_weight":0.1, "description":"Снимает травму ноги. Без лечения она проходит со временем."},
 "tinder": {"name":"Хворост", "unit_weight":0.12, "description":"Растопка из веток. Необходима для розжига костра."},
 "brush": {"name":"Ветки", "unit_weight":0.12, "burn_time":"5 мин", "description":"Ветки для крафта и топлива. Из одной ветки можно сделать хворост."},
 "stone": {"name":"Камень", "unit_weight":0.35, "description":"Для каменного кольца костра. Обычный камень не даёт огневой искры."},
 "flint": {"name":"Кремень", "unit_weight":0.2, "description":"Искровой камень: ударять о пирит над сухим хворостом."},
 "pyrite": {"name":"Пирит", "unit_weight":0.2, "description":"В паре с кремнем позволяет высекать искры без спичек."},
 "camp_kit": {"name":"Набор костра", "unit_weight":2.58, "description":"6 камней и 4 ветки. Выберите набор в рюкзаке и нажмите «Разместить» на ровной открытой земле."}
}
# kcal per inventory portion; unrelated to short-term stamina or fatigue.
static func calories_for(id:String) -> float:
 if id=="ration":return 1125.0
 if id=="berries":return 300.0
 if id=="wood_tea":return 20.0
 var d:=Vegetation.species(Vegetation.item_species(id))
 return float(d.get("cooked_calories",0) if id.begins_with("cooked_") else d.get("calories",0))
static func item(id: String, species: String = "", unit_weight: float = -1.0) -> Dictionary:
 var d: Dictionary = DEFINITIONS.get(id, Vegetation.item_definition(id)).duplicate(true)
 if id == "firewood":
  d = {"burn_time":"%d мин" % {"birch":30,"spruce":36,"beech":50,"oak":60}.get(species,30), "name":"Поленце (%s)" % {"birch":"берёза","spruce":"ель","beech":"бук","oak":"дуб"}.get(species,species), "unit_weight":unit_weight, "description":"Расколотое топором бревно. Топливо для костра.", "species":species}
 d.merge({"id": id if species=="" else id+"_"+species, "type":id, "count":1, "color":Color(0.87,0.79,0.61), "burn_time":"—", "heat":"—"})
 var kcal:=calories_for(id)
 if kcal>0:d["calories"]=kcal
 return d
static func count(slots: Array, id: String) -> int:
 var total := 0
 for s in slots:
  if s != null and (s.get("type","")==id or s.get("id","")==id): total += int(s.get("count",0))
 return total
static func transact(player: Node, costs: Dictionary, outputs: Array = [], source_slot: int = -1, preview: bool = false) -> bool:
 # Cooking reserves input types; all normal drop/use transactions pass this gate.
 if is_instance_valid(player.get("survival")) and not preview:
  var pending:Dictionary=player.survival.job
  if pending.get("kind")=="boil" and costs.has("raw_water"):return false
  if pending.get("kind")=="vegetation_cook":
   var reserved:Dictionary=player.survival.foraging.cook_recipe(str(pending.recipe),int(pending.amount)).get("costs",{})
   for id in costs:
    if reserved.has(id):return false
 var slots: Array = player.inventory_slots.duplicate(true)
 for id in costs:
  if not (costs[id] is int or costs[id] is float) or float(costs[id])<=0 or float(costs[id])!=int(costs[id]):return false
  if count(slots,id)<int(costs[id]):return false
  var left := int(costs[id])
  var indices:=range(slots.size())
  if source_slot>=0 and source_slot<slots.size():indices.erase(source_slot);indices.push_front(source_slot)
  for i in indices:
   var s = slots[i]
   if s==null or (s.get("type","")!=id and s.get("id","")!=id):continue
   var n := mini(left,int(s["count"]));s["count"]-=n;left-=n
   if s["count"]==0:slots[i]=null
   if left==0:break
 for output in outputs:
  if not output is Dictionary or not output.has("id") or int(output.get("count",1))<=0 or not is_finite(float(output.get("unit_weight",0))) or float(output.get("unit_weight",0))<0 or float(output.get("count",1))!=int(output.get("count",1)):return false
  var left := int(output.get("count",1))
  for s in slots:
   if s!=null and s.get("id")==output["id"] and is_equal_approx(float(s.get("unit_weight",0)),float(output.get("unit_weight",0))):
    var n := mini(left,10-int(s["count"]));s["count"]+=n;left-=n
    if left==0:break
  for i in slots.size():
   if left==0:break
   if slots[i]==null:
    slots[i]=output.duplicate(true);slots[i]["count"]=mini(left,10);left-=int(slots[i]["count"])
  if left>0:return false
 if preview:return true # Same transaction validation, zero mutation and no UI callbacks.
 player.inventory_slots=slots
 refresh(player)
 return true
static func refresh(player: Node) -> void:
 player.backpack_weight=0.0
 player.backpack_items.clear()
 for s in player.inventory_slots:
  if s!=null:
   if s.get("type")=="brush":s["name"]="Ветки";s["description"]=DEFINITIONS.brush.description
   if not s.get("color") is Color:s["color"]=Color(0.87,0.79,0.61)
   player.backpack_weight+=float(s.get("unit_weight",0))*int(s["count"])
   if s.get("type")=="log":
    for i in int(s["count"]):player.backpack_items.append({"species":s.get("species","birch"),"weight":s["unit_weight"]})
 player._refresh_belt_labels()
 player._update_inventory_hud()
 player._refresh_inventory_ui()
