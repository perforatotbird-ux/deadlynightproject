extends Node
# Stable controls: periodic refresh must never hide/recreate a pressed button.
const Style = preload("res://scripts/ui/UITheme.gd")
var player: Node
var buttons: Dictionary = {}
var tabs: TabContainer
var recipe: Label
var fire_info: Label
var sleep_info: Label
var sleep_hours: HSlider
var sleep_value: Label
var fuel_select: OptionButton
var fuel_amount: SpinBox
var log_select: OptionButton
var belt_select: OptionButton
var belt_info: Label
var status: Label
var progress: ProgressBar
var right_scroll: ScrollContainer
var rest: Button
var ui_scale:=1.0
var _tick:=0.0
var _inventory_signature:=""

func label(parent: Node, text: String, size: int=14) -> Label:
 var n:=Label.new();n.text=text;n.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;n.add_theme_font_size_override("font_size",size);parent.add_child(n);return n
func button(parent: Node, id: String, text: String, action: Callable) -> Button:
 var n:=Button.new();n.text=text;n.tooltip_text=text;n.clip_text=true;n.custom_minimum_size.y=44
 n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;Style.style_button(n);n.pressed.connect(action);parent.add_child(n);buttons[id]=n;return n
func column(parent: Node) -> VBoxContainer:
 var n:=VBoxContainer.new();n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;n.add_theme_constant_override("separation",10);parent.add_child(n);return n
func row(parent: Node) -> HBoxContainer:
 var n:=HBoxContainer.new();n.add_theme_constant_override("separation",10);parent.add_child(n);return n
func scroll(parent: Node) -> ScrollContainer:
 var n:=ScrollContainer.new();n.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;n.size_flags_vertical=Control.SIZE_EXPAND_FILL;parent.add_child(n);return n
func picker(parent: Node) -> OptionButton:
 var n:=OptionButton.new();n.custom_minimum_size.y=44;n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;n.clip_text=true;parent.add_child(n);return n
func page(title: String) -> VBoxContainer:
 var view:=scroll(tabs);view.name=title;return column(view)
func heading(parent: Node, text: String) -> void:
 label(parent,text,18).add_theme_color_override("font_color",Style.COLOR_ACCENT_GOLD)

func build(p: Node) -> void:
 player=p
 p._inv_layer=CanvasLayer.new();p._inv_layer.name="InventoryLayer";p._inv_layer.layer=110;p._inv_layer.hide();p.add_child(p._inv_layer)
 var shade:=ColorRect.new();shade.color=Color(0.02,0.03,0.03,0.88);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);p._inv_layer.add_child(shade)
 p._inv_root_panel=PanelContainer.new();p._inv_root_panel.name="InventoryPanel"
 p._inv_root_panel.add_theme_stylebox_override("panel",Style.create_panel_stylebox(Style.COLOR_BG_DARK));p._inv_layer.add_child(p._inv_root_panel)
 var layout:=column(p._inv_root_panel)
 var head:=row(layout);heading(head,"РЮКЗАК")
 button(head,"close","Закрыть · Tab / Esc",func():player._toggle_inventory()).size_flags_horizontal=0
 var mass:=row(layout);p._inv_weight_label=label(mass,"");p._inv_overweight_warning=label(mass,"")
 p._inv_weight_bar=ProgressBar.new();p._inv_weight_bar.max_value=p.max_backpack_kg;p._inv_weight_bar.show_percentage=false;p._inv_weight_bar.custom_minimum_size.y=6;layout.add_child(p._inv_weight_bar)
 tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;tabs.add_theme_font_size_override("font_size",16);layout.add_child(tabs)
 var inventory:=HBoxContainer.new();inventory.name="Предметы";inventory.add_theme_constant_override("separation",20);tabs.add_child(inventory)
 var left:=column(scroll(inventory));var grid:=GridContainer.new();grid.columns=4
 grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);left.add_child(grid)
 for i in p.MAX_SLOTS:
  var b:=Button.new();b.custom_minimum_size=Vector2(80,68);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.clip_text=true
  b.pressed.connect(p._on_slot_clicked.bind(i));grid.add_child(b);p._inv_slot_buttons.append(b)
 label(left,"Рецепты — во вкладке «Крафт».\nПояс 6–8: быстрые предметы без переноса веса.")
 right_scroll=scroll(inventory);var right:=column(right_scroll)
 p._inv_empty_inspector_label=label(right,"Выберите предмет в сетке",18);p._inv_inspector_box=column(right)
 p._inv_details_title=label(p._inv_inspector_box,"",18);p._inv_details_category=label(p._inv_inspector_box,"")
 p._inv_details_stats=label(p._inv_inspector_box,"");p._inv_details_desc=label(p._inv_inspector_box,"")
 button(p._inv_inspector_box,"place","Разместить костёр",func():player.survival.begin_placement())
 var beltrow:=row(p._inv_inspector_box);belt_select=picker(beltrow)
 for i in 3:belt_select.add_item("Ячейка %d" % (i+6),i)
 button(beltrow,"belt","На пояс",func():player.assign_belt_item(player._selected_slot_index,belt_select.get_selected_id());refresh_actions())
 button(p._inv_inspector_box,"unbelt","Очистить выбранную ячейку пояса",func():player.clear_belt_item(belt_select.get_selected_id());refresh_actions())
 belt_info=label(p._inv_inspector_box,"")
 var drops:=row(p._inv_inspector_box)
 p._inv_btn_drop_one=button(drops,"drop_one","Выбросить 1",func():player.drop_selected_item(false))
 p._inv_btn_drop_all=button(drops,"drop_all","Выбросить всё",func():player.drop_selected_item(true))
 var craft:=page("Крафт");heading(craft,"Набор костра")
 recipe=label(craft,"");button(craft,"kit","Создать набор костра",func():player.survival.make_kit())
 craft.add_child(HSeparator.new());heading(craft,"Раскол бревна")
 label(craft,"1 бревно → 3 поленца · 10 реальных секунд · топор с пояса")
 log_select=picker(craft);button(craft,"split","Расколоть выбранное бревно",func():player.survival.begin_split(log_select.get_selected_id()))
 label(craft,"Готовый набор: «Предметы» → выбрать → «Разместить» или «На пояс».")
 var camp:=page("Костёр");heading(camp,"Управление костром");fire_info=label(camp,"")
 var fuelrow:=row(camp);fuel_select=picker(fuelrow);fuel_select.item_selected.connect(func(_index):refresh_actions())
 fuel_amount=SpinBox.new();fuel_amount.min_value=1;fuel_amount.max_value=10;fuel_amount.step=1;fuel_amount.value=1;fuel_amount.custom_minimum_size=Vector2(100,44);fuelrow.add_child(fuel_amount)
 button(camp,"fuel","Добавить выбранное топливо",func():player.survival.add_fuel(player.survival.selected_fire,fuel_select.get_selected_id(),int(fuel_amount.value)))
 camp.add_child(HSeparator.new())
 var ignition:=row(camp)
 button(ignition,"tinder","Растопка · 1 хворост",func():player.survival.add_tinder(player.survival.selected_fire))
 button(ignition,"match","Спичка",func():player.survival.begin_ignition(player.survival.selected_fire,"match"))
 button(camp,"spark","Высечь искру · кремень + пирит",func():player.survival.begin_ignition(player.survival.selected_fire,"spark"))
 label(camp,"Брёвна сначала расколите во вкладке «Крафт». Спичка и растопка расходуются при начале попытки.")
 var sleep:=page("Сон");heading(sleep,"Сколько спать? · 1–12 ч")
 sleep_value=label(sleep,"",20)
 sleep_hours=HSlider.new();sleep_hours.min_value=1;sleep_hours.max_value=12;sleep_hours.step=1;sleep_hours.value=1
 sleep_hours.custom_minimum_size.y=44;sleep.add_child(sleep_hours);sleep_hours.value_changed.connect(func(_v):refresh_actions())
 sleep_info=label(sleep,"")
 rest=button(sleep,"rest","Спать",func():player.survival.begin_rest(int(sleep_hours.value)))
 label(sleep,"Огонь, погода и холод продолжают действовать. Сон прервётся, если станет опасно холодно или откроется дверь. 1 игровой час = 1 реальная секунда сна.")
 layout.add_child(HSeparator.new());status=label(layout,"",14)
 progress=ProgressBar.new();progress.show_percentage=false;progress.custom_minimum_size.y=12;layout.add_child(progress)
 button(layout,"cancel","Прервать действие",func():player.survival.cancel_job();refresh_actions())
 get_viewport().size_changed.connect(resize);resize();refresh_actions()

func resize() -> void:
 if not is_instance_valid(player):return
 var size:=get_viewport().get_visible_rect().size
 var physical:=Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name()!="headless" else size
 ui_scale=maxf(1.0,size.x/maxf(1,physical.x))
 var dim:=Vector2(minf(940*ui_scale,size.x-32*ui_scale),minf(620*ui_scale,size.y-32*ui_scale))
 for n in player._inv_root_panel.find_children("*","Control",true,false):
  if n is Label or n is Button or n is TabBar or n is LineEdit:
   if not n.has_meta("base_font"):n.set_meta("base_font",n.get_theme_font_size("font_size"))
   n.add_theme_font_size_override("font_size",roundi(float(n.get_meta("base_font"))*ui_scale))
  if n is Button:n.custom_minimum_size.y=44*ui_scale
 tabs.add_theme_font_size_override("font_size",roundi(16*ui_scale))
 for b in player._inv_slot_buttons:b.custom_minimum_size=Vector2(80,68)*ui_scale
 fuel_amount.custom_minimum_size=Vector2(100,44)*ui_scale;sleep_hours.custom_minimum_size.y=44*ui_scale
 buttons["close"].custom_minimum_size.x=180*ui_scale
 player._inv_root_panel.size=dim;player._inv_root_panel.position=(size-dim)/2
func _process(delta: float) -> void:
 _tick-=delta
 if _tick<=0:
  _tick=0.1
  if player._is_inventory_open:refresh_actions()
func focus_rest() -> void:tabs.current_tab=3
func focus_fire() -> void:tabs.current_tab=2
func show_selection() -> void:
 tabs.current_tab=0;right_scroll.scroll_vertical=0
func _update_picker(picker_node: OptionButton, types: Array, empty: String) -> void:
 # Do not rebuild a popup while the player is selecting an entry.
 if picker_node.get_popup().visible:return
 var selected:=picker_node.get_selected_id();picker_node.clear()
 for i in player.inventory_slots.size():
  var item=player.inventory_slots[i]
  if item!=null and item.get("type","") in types:picker_node.add_item("%s ×%d" % [item.get("name","Предмет"),item["count"]],i)
 if picker_node.item_count==0:picker_node.text=empty
 elif picker_node.get_item_index(selected)>=0:picker_node.select(picker_node.get_item_index(selected))
func refresh_actions() -> void:
 if not is_instance_valid(player):return
 var s=player.survival;var valid:=is_instance_valid(s)
 var item:Dictionary={}
 if player._selected_slot_index>=0 and player._selected_slot_index<player.inventory_slots.size() and player.inventory_slots[player._selected_slot_index]!=null:item=player.inventory_slots[player._selected_slot_index]
 var type:String=item.get("type","")
 var busy:bool=valid and (not s.job.is_empty() or s.health<=0)
 # Assign final states once. No false→true visibility/disabled pulses across refreshes.
 buttons["drop_one"].disabled=busy;buttons["drop_all"].disabled=busy
 buttons["place"].visible=valid and type=="camp_kit";buttons["place"].disabled=busy or not valid or (valid and s.location!="forest")
 buttons["belt"].disabled=busy or type not in ["camp_kit","firewood","brush"]
 buttons["unbelt"].disabled=busy or player.belt_items[belt_select.get_selected_id()]==""
 var names:Array=[]
 for i in 3:
  var slot:int=player.belt_item_slot(i)
  var kind:String=player.inventory_slots[slot].get("type","") if slot>=0 else ""
  names.append({"camp_kit":"Костёр","firewood":"Поленце","brush":"Хворост"}.get(kind,"—"))
 belt_info.text="6: %s · 7: %s · 8: %s" % names
 var signature:=str(player.inventory_slots)
 if signature!=_inventory_signature and not log_select.get_popup().visible and not fuel_select.get_popup().visible:
  _inventory_signature=signature;_update_picker(log_select,["log"],"Нет брёвен");_update_picker(fuel_select,["firewood","brush"],"Нет топлива — расколите бревно")
 buttons["kit"].disabled=busy or not valid;buttons["split"].disabled=busy or not valid or log_select.get_selected_id()<0
 if not valid:
  for id in ["fuel","tinder","match","spark","rest"]:buttons[id].disabled=true
 var active:bool=valid and not s.job.is_empty()
 progress.visible=active;buttons["cancel"].visible=active;buttons["cancel"].disabled=not active
 if not valid:
  recipe.text="Крафт доступен в игровом мире.";fire_info.text="Костёр недоступен.";sleep_info.text="Сон доступен в игровой стоянке."
  status.text="Выберите предмет в сетке.";return
 var brush:int=s.Items.count(player.inventory_slots,"brush");var stones:int=s.Items.count(player.inventory_slots,"stone")
 recipe.text="6 камней + 4 хвороста → набор костра\nВ рюкзаке: камни %d / 6 · хворост %d / 4" % [stones,brush]
 buttons["kit"].disabled=busy or stones<6 or brush<4
 var f:Dictionary=s.find_fire(s.selected_fire)
 if f.is_empty() or not s._fire_in_reach(f):f=s.nearby_fire();s.selected_fire=f.get("id","")
 var ready:=not f.is_empty();var fuel_slot:=fuel_select.get_selected_id();var available:=0
 if fuel_slot>=0 and fuel_slot<player.inventory_slots.size() and player.inventory_slots[fuel_slot]!=null:available=int(player.inventory_slots[fuel_slot]["count"])
 fuel_amount.max_value=maxi(1,available);fuel_amount.editable=not busy and available>0
 fuel_select.disabled=busy or available<1
 fire_info.text="Подойдите к костру и нажмите E. Действия доступны на расстоянии до 3,3 м без препятствий."
 buttons["fuel"].disabled=busy or not ready or available<1
 buttons["tinder"].disabled=busy or not ready or brush<1
 var ignite:bool=ready and not busy and f["state"]!="burning" and f["fuel"]>0 and f["tinder"]>0
 buttons["match"].disabled=not ignite or s.matches<1
 buttons["spark"].disabled=not ignite or s.Items.count(player.inventory_slots,"flint")<1 or s.Items.count(player.inventory_slots,"pyrite")<1
 buttons["match"].text="Спичка · %.0f%% · %d шт." % [s.ignition_chance("match")*100,s.matches]
 buttons["spark"].text="Кремень + пирит · %.0f%% · 5 с" % (s.ignition_chance("spark")*100)
 if ready:fire_info.text="%s · топлива %.0f мин · растопка %d" % [{"unlit":"Не разожжён","burning":"Горит","embers":"Угли","cold":"Остыл"}.get(f["state"],"Костёр"),float(f["fuel"])/60,int(f["tinder"])]
 var hours:=int(sleep_hours.value)
 var remaining:=maxf(0,float(s.job.get("duration",hours))-float(s.job.get("elapsed",0))) if s.job.get("kind")=="rest" else float(hours)
 var wake:=fposmod(s.hour()+remaining,24)
 sleep_value.text="%d ч · пробуждение около %02d:%02d" % [hours,int(wake),int(wake*60)%60]
 var reason:String=s.rest_block_reason()
 sleep_info.text="Силы %.0f%% · тепло %.0f%% · здоровье %.0f%%\n%s" % [s.energy,s.warmth,s.health,reason if reason!="" else "Стоянка закрыта. Можно спать."]
 rest.text="Спать %d ч" % hours;rest.disabled=busy or reason!=""
 sleep_hours.editable=not busy
 status.text=s.message if s.message_time>0 else "Мир не на паузе. Tab / Esc закрывает рюкзак и отменяет действие."
 if active:
  progress.max_value=float(s.job["duration"]);progress.value=float(s.job["elapsed"])
  status.text="%s · %.1f / %.1f с" % [{"split":"Раскол","ignite":"Розжиг","rest":"Сон"}.get(s.job["kind"],"Действие"),s.job["elapsed"],s.job["duration"]]
