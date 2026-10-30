extends RefCounted
# All recipes use the existing backpack. Transactions commit only if outputs fit.
const DEFINITIONS = {
 "brush": {"name":"Хворост", "unit_weight":0.12, "burn_time":"5 мин", "description":"Сухие веточки для костра и розжига."},
 "stone": {"name":"Камень", "unit_weight":0.35, "description":"Для каменного кольца костра. Обычный камень не даёт огневой искры."},
 "flint": {"name":"Кремень", "unit_weight":0.2, "description":"Искровой камень: ударять о пирит над сухим хворостом."},
 "pyrite": {"name":"Пирит", "unit_weight":0.2, "description":"В паре с кремнем позволяет высекать искры без спичек."},
 "camp_kit": {"name":"Набор костра", "unit_weight":2.58, "description":"6 камней и 4 хвороста. Выберите набор в рюкзаке и нажмите «Разместить» на ровной открытой земле."}
}
static func item(id: String, species: String = "", unit_weight: float = -1.0) -> Dictionary:
 var d: Dictionary = DEFINITIONS.get(id, {}).duplicate(true)
 if id == "firewood":
  d = {"burn_time":"%d мин" % {"birch":30,"spruce":36,"beech":50,"oak":60}.get(species,30), "name":"Поленце (%s)" % {"birch":"берёза","spruce":"ель","beech":"бук","oak":"дуб"}.get(species,species), "unit_weight":unit_weight, "description":"Расколотое топором бревно. Топливо для костра.", "species":species}
 d.merge({"id": id if species=="" else id+"_"+species, "type":id, "count":1, "color":Color(0.87,0.79,0.61), "burn_time":"—", "heat":"—"})
 return d
static func count(slots: Array, id: String) -> int:
 var total := 0
 for s in slots:
  if s != null and (s.get("type","")==id or s.get("id","")==id): total += int(s.get("count",0))
 return total
static func transact(player: Node, costs: Dictionary, outputs: Array = [], source_slot: int = -1) -> bool:
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
 player.inventory_slots=slots
 refresh(player)
 return true
static func refresh(player: Node) -> void:
 player.backpack_weight=0.0
 player.backpack_items.clear()
 for s in player.inventory_slots:
  if s!=null:
   if not s.get("color") is Color:s["color"]=Color(0.87,0.79,0.61)
   player.backpack_weight+=float(s.get("unit_weight",0))*int(s["count"])
   if s.get("type")=="log":
    for i in int(s["count"]):player.backpack_items.append({"species":s.get("species","birch"),"weight":s["unit_weight"]})
 player._refresh_belt_labels()
 player._update_inventory_hud()
 player._refresh_inventory_ui()
