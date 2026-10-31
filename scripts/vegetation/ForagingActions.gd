extends RefCounted
# Cooking uses SurvivalWorld.job and existing inventory transactions, never another clock/job loop.
const Catalog=preload("res://scripts/vegetation/VegetationCatalog.gd")
const Items=preload("res://scripts/survival/SurvivalItems.gd")
var session:Node
func cook_recipe(id:String,amount:int) -> Dictionary:
 if amount<1 or amount>10:return {}
 if id=="wood_tea":
  var tea:=Items.item(id);tea.count=amount
  return {"costs":{"stump_fan":amount,"water":amount},"outputs":[tea],"minutes":5.0*amount}
 var result:=Catalog.cook_output(id)
 if result=="":return {}
 var food:=Items.item(result);food.count=amount
 return {"costs":{id:amount},"outputs":[food],"minutes":3.0*amount}
func begin_cook(id:String,amount:int=1) -> bool:
 if session.health<=0 or not session.job.is_empty():return false
 if id=="wood_tea" and not session.vegetation.inspected.has("stump_fan"):
  session.notify("Сначала осмотрите пеньковый веер или прочитайте памятку с рецептом");return false
 var recipe:=cook_recipe(id,amount);var fire:Dictionary=session.find_fire(session.selected_fire)
 if fire.is_empty():fire=session.nearby_fire()
 if recipe.is_empty() or fire.is_empty() or fire.get("state")!="burning" or not session._fire_in_reach(fire):session.notify("Нужен доступный горящий костёр");return false
 if not Items.transact(session.player,recipe.costs,recipe.outputs,-1,true):session.notify("Не хватает ингредиентов или места для результата");return false
 session.job={"kind":"vegetation_cook","elapsed":0.0,"duration":float(recipe.minutes),"recipe":id,"amount":amount,"fire":fire.id,"origin":session._arr(session.player.global_position)}
 session.notify("Готовка: %.0f игровых минут. Ингредиенты зарезервированы до завершения."%float(recipe.minutes));return true
func cooking_valid(job:Dictionary) -> bool:
 var fire:Dictionary=session.find_fire(str(job.get("fire","")))
 return not fire.is_empty() and fire.get("state")=="burning" and session._fire_in_reach(fire)
func finish_cook(job:Dictionary) -> bool:
 var recipe:=cook_recipe(str(job.get("recipe","")),int(job.get("amount",0)))
 if recipe.is_empty() or not cooking_valid(job):return false
 var result:=Items.transact(session.player,recipe.costs,recipe.outputs)
 session.notify("Готово: "+str(recipe.outputs[0].name) if result else "Готовка отменена: ингредиенты сохранены")
 return result
func request_use(slot:int) -> bool:
 var p=session.player
 if session.get_tree().get_first_node_in_group("menu_confirmation")!=null:return false
 if session.health<=0 or not session.job.is_empty() or slot<0 or slot>=p.inventory_slots.size() or p.inventory_slots[slot]==null:return false
 var item:Dictionary=p.inventory_slots[slot];var species:=Catalog.item_species(str(item.get("type","")))
 if species!="" and Catalog.species(species).family=="mushroom" and not session.vegetation.known.has(species):
  var identity:=str(item.id)
  var dlg=preload("res://scripts/ui/ConfirmDialog.gd").prompt(p,"Неизвестный гриб","Свойства этого вида неизвестны. Готовка не гарантирует безопасность. Всё равно съесть?","Съесть на свой риск","Отмена",true)
  dlg.confirmed.connect(func():
   if p._is_inventory_open and slot<p.inventory_slots.size() and p.inventory_slots[slot]!=null and str(p.inventory_slots[slot].id)==identity:session.use_supply(slot,true)
  )
  return false
 return session.use_supply(slot)
func use(slot:int,confirmed:bool=false) -> bool:
 var item:Dictionary=session.player.inventory_slots[slot];var id:=str(item.get("type",""));var species:=Catalog.item_species(id)
 if id=="antitoxin":
  if not session.body.conditions.has("poison"):session.notify("Признаков отравления нет");return false
  if not Items.transact(session.player,{item.id:1},[],slot):return false
  session.body.conditions.erase("poison");session.notify("Отравление снято. Восстановите воду и отдохните.");return true
 if id=="wood_tea":
  if not Items.transact(session.player,{item.id:1},[],slot):return false
  session.body.stamina=minf(100,session.body.stamina+25);session.body.water=minf(100,session.body.water+Items.WATER_RESTORE)
  session.body.refresh_winded();session.notify("Древесный чай: +25 выносливости. Сон и ограничения бега не изменены.");return true
 if species=="":return false
 var d:=Catalog.species(species);var cooked:=id.begins_with("cooked_")
 if d.family=="tea":session.notify("Используется для приготовления чая у костра");return false
 if d.family=="mushroom" and not session.vegetation.known.has(species) and not confirmed:session.notify("Для неизвестного гриба требуется явное подтверждение");return false
 if not Items.transact(session.player,{item.id:1},[],slot):return false
 session.body.food=minf(100,session.body.food+float(d.get("cooked_food",0) if cooked else d.get("food",0)))
 session.body.water=minf(100,session.body.water+float(d.get("water",0)))
 var toxin:=str(d.get("toxin",d.get("raw_toxin","") if not cooked else ""))
 if toxin!="":session.body.add_poison(toxin)
 session.vegetation.known[species]=true;session.vegetation.inspected[species]=true
 session.notify("Использовано: "+str(item.name));return true
