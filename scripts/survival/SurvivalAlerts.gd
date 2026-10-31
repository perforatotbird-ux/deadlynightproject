extends RefCounted
# Read-only projection of actual gameplay state. No independent timers, invented
# diseases or damage; treatment/recovery clears the corresponding row next refresh.
static func collect(s:Node)->Array:
 var rows:Array=[]
 if s.health<=0:return rows
 if s.health<=25:_add(rows,"health","Критическое здоровье" if s.health<=10 else "Низкое здоровье",2 if s.health<=10 else 1)
 if s.body.conditions.has("bleeding"):_add(rows,"bleeding","Кровотечение · нужен бинт",2)
 if s.body.conditions.has("hypothermia"):_add(rows,"cold","Переохлаждение · согрейтесь",2)
 elif s.warmth<12:_add(rows,"cold","Замерзаете · теряете здоровье",2)
 elif s.warmth<20:_add(rows,"cold","Опасный холод · найдите огонь",2)
 elif s.warmth<35 and float(s.thermal_status().warmth_rate)<0:_add(rows,"cold","Вы мёрзнете · найдите укрытие",1)
 if s.body.water<15:_add(rows,"water","Обезвоживание · нужна вода" if s.body.water<=0 else "Мало воды · пора пить",2 if s.body.water<=0 else 1)
 if s.body.food<15:_add(rows,"food","Голодание · нужна еда" if s.body.food<=0 else "Вы голодны · найдите еду",2 if s.body.food<=0 else 1)
 if s.energy<15:_add(rows,"energy","Истощение · нужен сон" if s.energy<=0 else "Сильная усталость · отдохните",2 if s.energy<=0 else 1)
 if s.body.conditions.has("poison"):
  var poison:Dictionary=s.body.conditions.poison
  var title:String={"disorder":"Пищевое расстройство","medium":"Среднее отравление","severe":"Тяжёлое отравление"}.get(str(poison.get("tier","")),"Отравление")
  if float(poison.get("delay",0))>0:title+=" · скрытая фаза"
  _add(rows,"poison",title,2 if str(poison.get("tier",""))=="severe" and float(poison.get("delay",0))<=0 else 1)
 if s.body.conditions.has("sprain"):_add(rows,"sprain","Травма ноги · бег недоступен",1)
 if s.wetness>=70:_add(rows,"wetness","Сильно промокли · просушитесь",1)
 if s.body.stamina<=5:_add(rows,"stamina","Нет сил · переведите дыхание",1)
 if s.player.backpack_weight>s.player.max_backpack_kg:_add(rows,"overweight","Перегруз · движение замедлено",1)
 # Stable priority order means simultaneous dangers never replace one another.
 rows.sort_custom(func(a,b):return int(a.severity)>int(b.severity))
 return rows
static func _add(rows:Array,id:String,text:String,severity:int)->void:
 rows.append({"id":id,"text":text,"severity":severity})
