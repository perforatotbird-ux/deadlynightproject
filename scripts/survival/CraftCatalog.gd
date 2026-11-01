extends RefCounted
# Presentation catalog: gameplay transactions remain in SurvivalWorld/SurvivalItems.
# Four species are four real results, not invented future recipes.
const FIRE_RECIPES:=[
 {"id":"forest_fat","title":"Лесной толстяк · 3 мин / шт."},
 {"id":"wood_fan","title":"Древесная веерница · 3 мин / шт."},
 {"id":"copper_false","title":"Медный ложник · готовка не обезвреживает"},
 {"id":"pale_bell","title":"Бледный колоколец · готовка не обезвреживает"},
 {"id":"wood_tea","title":"Древесный чай · гриб + 0,5 л воды · 5 мин"}
]
const RECIPES:=[
 {"id":"tinder","title":"Хворост","icon":"brush","action":"kit","costs":{"brush":1},"seconds":0,"output":1,"description":"Разберите одну ветку на сухой хворост для розжига."},
 {"id":"camp_kit","title":"Набор костра","icon":"camp_kit","action":"kit","costs":{"stone":6,"brush":4},"seconds":0,"output":1,"description":"Каменное кольцо и сухие ветки. После сборки разместите набор на ровной открытой земле."},
 {"id":"split_birch","title":"Поленья · берёза","icon":"firewood_birch","action":"split","species":"birch","seconds":10,"output":3,"description":"Светлые берёзовые поленья для костра. Одно бревно раскалывается на три части."},
 {"id":"split_spruce","title":"Поленья · ель","icon":"firewood_spruce","action":"split","species":"spruce","seconds":10,"output":3,"description":"Смолистая ель. Три поленца из одного елового бревна."},
 {"id":"split_beech","title":"Поленья · бук","icon":"firewood_beech","action":"split","species":"beech","seconds":10,"output":3,"description":"Плотная древесина бука. Три поленца из одного букового бревна."},
 {"id":"split_oak","title":"Поленья · дуб","icon":"firewood_oak","action":"split","species":"oak","seconds":10,"output":3,"description":"Тяжёлая дубовая древесина. Три поленца из одного дубового бревна."}
]
static func recipe(id: String) -> Dictionary:
 for r in RECIPES:
  if r.id==id:return r
 return RECIPES[0]
static func source_slots(player: Node, r: Dictionary) -> Array[int]:
 var slots:Array[int]=[]
 for i in player.inventory_slots.size():
  var item=player.inventory_slots[i]
  if item!=null and item.get("type")=="log" and item.get("species")==r.get("species"):slots.append(i)
 return slots
static func reason(player: Node,r: Dictionary) -> String:
 if not is_instance_valid(player.survival):return "Доступно только в игре"
 if player.survival.health<=0:return "Персонаж погиб"
 if r.action=="kit":
  for id in r.costs:
   if player.survival.Items.count(player.inventory_slots,id)<r.costs[id]:return "Не хватает материалов"
 elif source_slots(player,r).is_empty():return "Нет подходящего бревна"
 if not player.survival.job.is_empty():return "Завершите текущее действие"
 var items=player.survival.Items
 if r.action=="kit":
  if not items.transact(player,r.costs,[items.item(str(r.id))],-1,true):return "Нужно место в рюкзаке"
 else:
  var slot:int=source_slots(player,r)[0];var source:Dictionary=player.inventory_slots[slot]
  var output:Dictionary=items.item("firewood",str(source.species),float(source.unit_weight)/3.0);output.count=3
  if not items.transact(player,{source.id:1},[output],slot,true):return "Нужно место в рюкзаке"
 return ""
