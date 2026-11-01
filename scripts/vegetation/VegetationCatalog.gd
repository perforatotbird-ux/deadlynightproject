extends RefCounted
# Fictional island species; every number is provisional playtest tuning.
const VERSION:=2
const SEED:=20261028
const FIRST_GROWTH:=2.0*86400.0
const REGROWTH:=5.0*86400.0
const HUMIDITY_FRACTION:=0.25 # Required wet-equivalent share of cycle.
const CLEAR_HUMIDITY:=0.15 # Rain = 1; integrated in forest AND mine, independent of Nodes.
const ELIGIBILITY_PERCENT:=45
const SPECIES:={
 "krasnitsa":{"name":"Красница","family":"berry","weight":0.10,"calories":125.0,"water":1.0,"yield":3,"color":"b4493c","habitat":"edge","traits":"Раскидистые ветви; круглые красные грозди.","status":"Съедобна","regeneration":"none"},
 "sizovka":{"name":"Сизовка","family":"berry","weight":0.12,"calories":200.0,"water":1.0,"yield":2,"color":"6880a0","habitat":"canopy","traits":"Компактные высокие ветви; сизые овальные ягоды с восковым налётом.","status":"Съедобна","regeneration":"none"},
 "bolotnitsa":{"name":"Болотница","family":"berry","weight":0.12,"calories":75.0,"water":4.0,"yield":4,"color":"d5a148","habitat":"wet","traits":"Стелющиеся ветви; янтарные сегментированные плоды.","status":"Съедобна","regeneration":"none"},
 "forest_fat":{"name":"Лесной толстяк","family":"mushroom","weight":0.15,"calories":125.0,"cooked_calories":225.0,"yield":1,"color":"bb8c51","habitat":"canopy","traits":"Широкая округлая охристая шляпка и толстая короткая ножка.","status":"Съедобен","regeneration":"none"},
 "wood_fan":{"name":"Древесная веерница","family":"mushroom","weight":0.18,"calories":0.0,"cooked_calories":300.0,"raw_toxin":"disorder","yield":1,"color":"939b96","habitat":"deadwood","traits":"Серые веерообразные ярусы на старой древесине; выраженной центральной ножки нет.","status":"Требует приготовления","regeneration":"none"},
 "copper_false":{"name":"Медный ложник","family":"mushroom","weight":0.12,"calories":0.0,"cooked_calories":0.0,"toxin":"medium","yield":1,"color":"a45e36","habitat":"wet","traits":"Плоская медная шляпка, тонкая ножка с широким светлым кольцом. Готовка не обезвреживает.","status":"Ядовит","regeneration":"none"},
 "pale_bell":{"name":"Бледный колоколец","family":"mushroom","weight":0.12,"calories":0.0,"cooked_calories":0.0,"toxin":"severe","yield":1,"color":"dad4b5","habitat":"canopy","traits":"Высокая колокольчатая шляпка, тёмные радиальные пластинки, утолщённое основание. Готовка не обезвреживает.","status":"Ядовит","regeneration":"none"},
 "stump_fan":{"name":"Пеньковый веер","family":"tea","weight":0.08,"yield":1,"color":"be7947","habitat":"stump","traits":"Полосатые ржаво-охристые полки на боковой поверхности старого пня. Сырым не употребляется.","status":"Для древесного чая","regeneration":"regrowth"}
}
const FOOD_IDS:=["krasnitsa","sizovka","bolotnitsa","forest_fat","wood_fan","copper_false","pale_bell","stump_fan","cooked_forest_fat","cooked_wood_fan","cooked_copper_false","cooked_pale_bell","wood_tea"]
const CONSUMABLE_IDS:=["krasnitsa","sizovka","bolotnitsa","forest_fat","wood_fan","copper_false","pale_bell","cooked_forest_fat","cooked_wood_fan","cooked_copper_false","cooked_pale_bell","wood_tea"]
const SUPPLY_IDS:=["water","raw_water","ration","berries","bandage","compress","antitoxin"]+CONSUMABLE_IDS
const INITIAL_KNOWLEDGE:=["krasnitsa","sizovka","bolotnitsa","forest_fat"]
static func species(id:String) -> Dictionary:return SPECIES.get(id,{})
static func item_species(id:String) -> String:
 var raw:=id.trim_prefix("cooked_")
 return raw if SPECIES.has(raw) else ""
static func is_food(id:String) -> bool:return id=="wood_tea" or SPECIES.has(item_species(id))
static func item_definition(id:String) -> Dictionary:
 if id=="wood_tea":return {"name":"Древесный чай · 0,5 л","unit_weight":0.50,"description":"Пеньковый веер, сваренный в безопасной воде. +25 выносливости; вода как у питьевой воды. Не заменяет сон и не лечит травмы."}
 if id=="antitoxin":return {"name":"Средство от отравления","unit_weight":0.06,"description":"Игровое медицинское средство. Одна доза снимает пищевое отравление и его задержку; не восстанавливает утраченное здоровье."}
 var d:=species(item_species(id))
 if d.is_empty():return {}
 var cooked:=id.begins_with("cooked_")
 return {"name":str(d.name)+(" · приготовленный" if cooked else ""),"unit_weight":d.weight,"description":str(d.traits)+"\n"+effect_text(id),"plant_species":item_species(id),"cooked":cooked}
static func cook_output(id:String) -> String:
 return "cooked_"+id if SPECIES.has(id) and species(id).family=="mushroom" else ""
static func eligible(tree_id:String) -> bool:return not tree_id.is_empty()
static func harvest_count(tree_id:String,cycle:int=0) -> int:return 1+posmod((tree_id+":"+str(cycle)).hash(),3)

# Immediate, bounded gameplay trade-offs; no stackable permanent buffs or medical claims.
const FOOD_EFFECTS:={
 "krasnitsa":{"stamina":8.0,"water":-2.0},
 "sizovka":{"energy":3.0,"water":-3.0},
 "bolotnitsa":{"stamina":-3.0},
 "forest_fat":{"stamina":-3.0,"water":-2.0},
 "cooked_forest_fat":{"energy":5.0,"warmth":3.0,"water":-1.0},
 "cooked_wood_fan":{"energy":7.0,"warmth":4.0,"water":-3.0},
 "copper_false":{"water":-2.0},"cooked_copper_false":{"water":-2.0},
 "pale_bell":{"energy":-5.0},"cooked_pale_bell":{"energy":-5.0}
}
static func food_effects(id:String)->Dictionary:return FOOD_EFFECTS.get(id,{})
static func effect_text(id:String)->String:
 var names:={"stamina":"выносливость","energy":"бодрость","water":"запас воды","warmth":"тепло"}
 var parts:PackedStringArray=[]
 var effects:=food_effects(id).duplicate()
 var d:=species(item_species(id))
 if float(d.get("water",0))!=0:effects["water"]=float(effects.get("water",0))+float(d.water)
 for key in effects:
  if float(effects[key])!=0:parts.append("%+.0f %s" % [float(effects[key]),names[key]])
 var cooked:=id.begins_with("cooked_")
 var toxin:=str(d.get("toxin",d.get("raw_toxin","") if not cooked else ""))
 if toxin!="":parts.append({"disorder":"пищевое расстройство","medium":"среднее отравление","severe":"тяжёлое отравление с задержкой"}.get(toxin,"отравление"))
 if id=="stump_fan":return "Сырым не употребляется: ингредиент древесного чая."
 return "Свойства порции: "+" · ".join(parts)+". Не заменяет сон." if not parts.is_empty() else ""
