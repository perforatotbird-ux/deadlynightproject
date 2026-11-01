extends CanvasLayer
# Only this UI processes while paused. Debug flags are session-only, not save defaults.
const ThemeKit=preload("res://scripts/ui/JournalTheme.gd")
var session:Node
var commands=preload("res://scripts/dev/DevCommands.gd").new()
var panel:PanelContainer
var tabs:TabContainer
var readout:Label
var result:Label
var confirm:Control
var confirm_text:Label
var confirm_ok:Button
var pending:Callable
var inputs:Dictionary={}
var _mouse_before:=Input.MOUSE_MODE_VISIBLE
var _paused_before:=false
var _refresh:=0.0
func _ready() -> void:
 name="DevMenu";layer=150;process_mode=Node.PROCESS_MODE_ALWAYS;commands.session=session
 var shade:=ColorRect.new();shade.color=Color(0.01,0.02,0.025,0.92);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
 panel=PanelContainer.new();panel.theme=ThemeKit.theme();panel.add_theme_stylebox_override("panel",ThemeKit.box(Color("101c22"),Color("6eaaa5")));add_child(panel)
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",10);panel.add_child(box)
 var head:=HBoxContainer.new();box.add_child(head);label(head,"DEV / DEADLY NIGHT  ·  F8",20)
 var close_button:=button(head,"Закрыть",close_menu);close_button.size_flags_horizontal=0;close_button.custom_minimum_size.x=150
 label(box,"Мир на паузе. Команды меняют текущую игру. Читы сбрасываются при загрузке; изменённый прогресс помечается DEV.",12)
 readout=label(box,"",13)
 tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(tabs)
 _character();_world();_items();_travel();_events();_settings();_diagnostics()
 result=label(box,"Обычные сохранения не перезаписываются автоматически.",13)
 confirm=Control.new();confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(confirm)
 var dim:=ColorRect.new();dim.color=Color(0,0,0,0.8);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);confirm.add_child(dim)
 var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);confirm.add_child(center)
 var dialog:=PanelContainer.new();dialog.theme=panel.theme;dialog.custom_minimum_size=Vector2(420,0);dialog.add_theme_stylebox_override("panel",ThemeKit.box(Color("18252b"),ThemeKit.GOLD));center.add_child(dialog)
 var content:=VBoxContainer.new();content.add_theme_constant_override("separation",16);dialog.add_child(content)
 label(content,"Подтвердить Dev-команду",20);confirm_text=label(content,"");confirm_text.custom_minimum_size.x=390
 var actions:=row(content);confirm_ok=button(actions,"Выполнить",func():
  var action:=pending;pending=Callable();confirm.hide()
  if action.is_valid():action.call())
 button(actions,"Отмена",func():confirm.hide();pending=Callable());confirm.hide()
 panel.minimum_size_changed.connect(func():call_deferred("_resize"))
 get_viewport().size_changed.connect(_resize);_resize();hide()
func label(parent:Node,text:String,size:int=14) -> Label:
 var node:=Label.new();node.text=text;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.size_flags_horizontal=Control.SIZE_EXPAND_FILL;node.add_theme_font_size_override("font_size",size);parent.add_child(node);return node
func button(parent:Node,text:String,action:Callable) -> Button:
 var node:=Button.new();node.text=text;node.custom_minimum_size.y=36;node.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(node);node.pressed.connect(action);return node
func row(parent:Node) -> HBoxContainer:
 var node:=HBoxContainer.new();node.add_theme_constant_override("separation",8);parent.add_child(node);return node
func page(title:String) -> VBoxContainer:
 var sc:=ScrollContainer.new();sc.name=title;sc.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(sc)
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",10);box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;sc.add_child(box);return box
func number(parent:Node,key:String,title:String,value:float,low:float=0,high:float=100,step:float=1) -> SpinBox:
 var line:=row(parent);label(line,title)
 var spin:=SpinBox.new();spin.min_value=low;spin.max_value=high;spin.step=step;spin.value=value;spin.custom_minimum_size=Vector2(135,36);line.add_child(spin);inputs[key]=spin;return spin
func pick(parent:Node,key:String,title:String,values:Array) -> OptionButton:
 var line:=row(parent);label(line,title);var node:=OptionButton.new();node.custom_minimum_size=Vector2(200,36);line.add_child(node)
 for value in values:node.add_item(str(value))
 inputs[key]=node;return node
func selected(key:String) -> String:return inputs[key].get_item_text(inputs[key].selected)
func toggle(parent:Node,text:String,command:String,initial:bool) -> void:
 var node:=CheckButton.new();node.text=text;node.set_pressed_no_signal(initial);parent.add_child(node);inputs[command]=node;node.toggled.connect(func(value):execute(command,{"enabled":value}))
func execute(command:String,args:Dictionary={}) -> void:
 if command=="scene":close_menu()
 result.text=commands.run(command,args);refresh_values(true)
func dangerous(text:String,action:Callable) -> void:
 pending=action;confirm_text.text=text;confirm.show();confirm_ok.grab_focus()
func _character() -> void:
 var box:=page("Персонаж")
 for key in commands.STATS:
  var line:=row(box);label(line,{"health":"Здоровье","warmth":"Тепло","wetness":"Намокание","energy":"Отдых","food":"Питание","water":"Вода","stamina":"Выносливость","matches":"Спички"}[key])
  var spin:=SpinBox.new();spin.max_value=999 if key=="matches" else 100;spin.custom_minimum_size=Vector2(120,36);line.add_child(spin);inputs[key]=spin
  button(line,"Применить",func():
   if key=="health" and spin.value<session.health:dangerous("Уменьшить здоровье персонажа? При 0% он погибнет.",func():execute("stat",{"key":key,"value":spin.value}))
   else:execute("stat",{"key":key,"value":spin.value}))
 var actions:=row(box);button(actions,"Полное восстановление",func():execute("heal"));button(actions,"Урон 10%",func():dangerous("Нанести персонажу 10% урона?",func():execute("damage",{"amount":10})))
 var status:=pick(box,"condition_id","Состояние",["bleeding","sprain","hypothermia"])
 var conditions:=row(box);button(conditions,"Добавить состояние",func():dangerous("Добавить травму или заболевание?",func():execute("condition",{"id":status.get_item_text(status.selected)})));button(conditions,"Снять состояние",func():execute("condition",{"id":selected("condition_id"),"enabled":false}))
 toggle(box,"Неуязвимость (потребности продолжают меняться)","god",false);toggle(box,"Заморозить показатели и состояния тела","needs",false)
func _world() -> void:
 var box:=page("Мир")
 number(box,"day","День",1,1,999);number(box,"hour","Час",16,0,23.99,0.25)
 button(box,"Установить часы без расхода ресурсов",func():dangerous("Переставить часы? Потребности и топливо не пересчитываются. Текущие действия и события отменятся.",func():execute("clock",{"day":inputs.day.value,"hour":inputs.hour.value})))
 number(box,"hours","Промотать игровых часов",1,0.1,24,0.1)
 button(box,"Симулировать время с последствиями",func():dangerous("Топливо и потребности будут израсходованы. Возможна гибель персонажа.",func():execute("simulate",{"hours":inputs.hours.value})))
 number(box,"rate_value","Скорость мирового времени ×",1,0.1,10,0.1);button(box,"Применить скорость",func():execute("rate",{"value":inputs.rate_value.value}))
 toggle(box,"Остановить мировые часы / потребности / топливо","freeze",false)
 pick(box,"weather_kind","Погода",session.weather_model.PROFILES.keys());button(box,"Применить погоду немедленно",func():execute("weather",{"kind":selected("weather_kind")}))
 var camp:=row(box);button(camp,"Переключить дверь стоянки",func():execute("door"));button(camp,"Наполнить дождесборник",func():execute("collector"))
 number(box,"fuel_minutes","Топливо ближайшего костра, мин",60,0,1440);button(box,"Установить топливо / огонь",func():execute("fire",{"minutes":inputs.fuel_minutes.value}))
func _items() -> void:
 var box:=page("Предметы")
 label(box,"Выдача использует обычные стаки, массу и лимит рюкзака. При нехватке места выдача отменяется целиком.")
 var ids:Array=session.Items.DEFINITIONS.keys();ids.append("firewood");ids.append("log");pick(box,"item_id","Предмет",ids);pick(box,"species","Порода древесины",["birch","spruce","beech","oak"]);number(box,"count","Количество",1,1,160)
 button(box,"Выдать",func():execute("give",{"id":selected("item_id"),"species":selected("species"),"count":int(inputs.count.value)}))
 button(box,"Очистить рюкзак",func():dangerous("Удалить все предметы из рюкзака? Закреплённые инструменты останутся.",func():execute("clear_inventory")))
 button(box,"Выдать набор для первой ночи",func():
  for id in ["camp_kit","brush","water","ration","bandage","compress"]:execute("give",{"id":id,"count":2}))
 label(box,"Размещение костра и обычное использование предметов — через полевой журнал после закрытия Dev Menu.")
func _travel() -> void:
 var box:=page("Перемещения")
 button(box,"В шахту" if session.location=="forest" else "Вернуться в лес",func():dangerous("Перейти в другую сцену через штатное сохранение состояния?",func():execute("scene",{"location":"mine" if session.location=="forest" else "forest"})))
 label(box,"Телепорт ищет землю и свободное место, сбрасывает скорость и накопленное падение. В шахте лесные POI недоступны.")
 button(box,"В лесную стоянку",func():execute("camp"))
 if session.location=="forest":
  var pois:Dictionary=load("res://scripts/viewer/MapViewer.gd").POI_LOCATIONS
  pick(box,"poi","Точка интереса",pois.keys());button(box,"Переместить к POI",func():execute("teleport",{"position":pois[selected("poi")]}))
 for axis in ["x","y","z"]:number(box,"pos_"+axis,axis.to_upper(),0,-2100,2100,0.1)
 button(box,"Безопасный телепорт по X/Z",func():execute("teleport",{"position":Vector3(inputs.pos_x.value,inputs.pos_y.value,inputs.pos_z.value)}))
 label(box,"Y вычисляется по поверхности; свободный полёт — F1 после закрытия. Кнопка перехода использует штатный перенос состояния между сценами.")
func _events() -> void:
 var box:=page("События");toggle(box,"Автоматические атмосферные и небесные события","events",true)
 pick(box,"event_kind","Вызвать событие",["eyes","orbs","crossing","meteor","anomaly","lightning"])
 button(box,"Запустить событие",func():dangerous("Вызвать событие? Молния может дать вспышку. После закрытия меню событие продолжится.",func():execute("event",{"kind":selected("event_kind")})))
 button(box,"Завершить текущие события / гром",func():execute("stop_events"))
 label(box,"Глаза и шары требуют ночи и безопасной геометрии. Dev-команда не отменяет минимальные дистанции и не добавляет контакт/урон.")
func _settings() -> void:
 var box:=page("Настройки");label(box,"Текущие настройки рендера и звука. Применяются через SettingsManager; не сохраняются на диск этой панелью.")
 var sm=load("res://scripts/core/SettingsManager.gd").get_instance()
 for section in ["graphics","audio"]:
  for key in sm.DEFAULTS[section]:
   if key in ["window_mode","resolution_x","resolution_y"]:continue
   var value:Variant=sm.get_setting(section,key)
   if value is bool:
    var check:=CheckButton.new();check.text=key;check.button_pressed=value;box.add_child(check);check.toggled.connect(func(v):sm.set_setting(section,key,v);sm.apply_all_settings())
   elif value is int or value is float:
    var spin:=number(box,"setting_"+key,key,float(value),0,1 if section=="audio" else (240 if key=="max_fps" else 2),0.05 if section=="audio" else 1)
    button(box,"Применить "+key,func():sm.set_setting(section,key,spin.value if section=="audio" else int(spin.value));sm.apply_all_settings())
 for key in session.body.tuning:
  var spin:=number(box,"tuning_"+key,"Баланс / "+key,float(session.body.tuning[key]),0,10,0.005)
  button(box,"Применить "+key,func():execute("tuning",{"key":key,"value":spin.value}))
 label(box,"Баланс — в % за игровую минуту. Изменения временные, сбрасываются при загрузке. Нулевой урон фактически отключает соответствующую опасность.")
func _diagnostics() -> void:
 var box:=page("Диагностика");label(box,"Снимок содержит персонажа, инвентарь и SurvivalWorld только текущей сцены. Это НЕ полный SaveManager: геометрия надрубов и физические брёвна не откатываются.")
 button(box,"Записать отдельный Dev-снимок",func():dangerous("Перезаписать user://dev_snapshot.json? Обычные слоты не затрагиваются.",func():execute("snapshot")))
 button(box,"Восстановить Dev-снимок",func():dangerous("Восстановить персонажа и SurvivalWorld? Только та же сцена. Текущие изменения этих данных будут потеряны.",func():execute("restore_snapshot")))
 button(box,"Записать диагностику JSON",func():execute("diagnostics"))
 button(box,"Показать последние команды",func():result.text="\n".join(commands.history.slice(maxi(0,commands.history.size()-5))))
func _resize() -> void:
 if not is_inside_tree() or panel==null or get_viewport()==null:return
 var size:=get_viewport().get_visible_rect().size;panel.position=Vector2(16,16);panel.size=size-Vector2(32,32)
func _input(event:InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_F8:
   if visible:close_menu()
   else:open_menu()
   get_viewport().set_input_as_handled()
  elif visible and event.keycode==KEY_ESCAPE:
   if confirm.visible:confirm.hide();pending=Callable()
   else:close_menu()
   get_viewport().set_input_as_handled()
func open_menu() -> void:
 if visible or session._transitioning or get_tree().paused:return
 _paused_before=get_tree().paused;_mouse_before=Input.mouse_mode
 session.player._is_lmb_held=false;session.player._cancel_chop()
 if session.player._is_inventory_open:session.close_backpack()
 session.cancel_placement();session.cancel_job();session.player.velocity=Vector3.ZERO
 get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;show();refresh_values(true);call_deferred("_resize")
func close_menu() -> void:
 pending=Callable()
 if not visible:return
 confirm.hide();hide();get_tree().paused=_paused_before
 Input.mouse_mode=_mouse_before;session.player._is_mouse_captured=Input.mouse_mode==Input.MOUSE_MODE_CAPTURED;session.player._jump_buffer_timer=0
func refresh_values(fill:bool=true) -> void:
 var s=session
 readout.text="%s · %s · %.1f ч · здоровье %.1f%% · питание %.1f%% · вода %.1f%% · %.0f FPS · узлов %d%s\nСезон: %s, день %d/%d · воздух %.1f °C · ветер: %s" % [s.location,str(s.player.global_position),s.clock/3600,s.health,s.body.food,s.body.water,Engine.get_frames_per_second(),get_tree().get_node_count()," · DEV" if s.dev_tainted else "",s.season_name(),s.season_day(),s.SeasonModel.SEASON_DAYS,s.air_temperature(),s.wind_description()]
 if fill:
  for key in commands.STATS:inputs[key].value=s.body.get(key) if key in ["food","water","stamina"] else s.get(key)
  inputs.day.value=int(s.clock/86400)+1;inputs.hour.value=s.hour();inputs.rate_value.value=s.dev_time_rate
  for axis in ["x","y","z"]:inputs["pos_"+axis].value=s.player.global_position[["x","y","z"].find(axis)]
 for key in ["god","needs","freeze","events"]:
  inputs[key].set_pressed_no_signal({"god":s.body.invulnerable,"needs":s.body.freeze_needs,"freeze":s.dev_freeze_world,"events":s.dev_events_enabled}[key])
func _process(delta:float) -> void:
 if not visible:return
 _refresh-=delta
 if _refresh<=0:_refresh=0.5;refresh_values(false)
func _exit_tree() -> void:
 if visible and is_inside_tree():get_tree().paused=_paused_before
