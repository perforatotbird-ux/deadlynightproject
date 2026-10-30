extends Node
# Persistent scene controls: no frame-by-frame rebuilding, no lost mouse releases.
const Style=preload("res://scripts/ui/UITheme.gd")
const Journal=preload("res://scripts/ui/JournalTheme.gd")
const Art=preload("res://scripts/ui/JournalArt.gd")
const Card=preload("res://scripts/ui/JournalCard.gd")
const Catalog=preload("res://scripts/survival/CraftCatalog.gd")
var player:Node
var buttons:Dictionary={}
var tabs:TabContainer
var recipe:Label
var fire_info:Label
var sleep_info:Label
var sleep_hours:HSlider
var sleep_value:Label
var fuel_select:OptionButton
var fuel_amount:SpinBox
var log_select:OptionButton
var belt_select:OptionButton
var belt_info:Label
var status:Label
var progress:ProgressBar
var right_scroll:ScrollContainer
var rest:Button
var ui_scale:=1.0
var _tick:=0.0
var _inventory_signature:=""
var selected_recipe:="camp_kit"
var recipe_cards:Dictionary={}
var recipe_title:Label
var recipe_desc:Label
var recipe_image:TextureRect
var recipe_tool:Label
var recipe_empty:Label
var ingredient_rows:Array=[]
var only_available:CheckButton
var search:LineEdit
var category:OptionButton
var sorting:OptionButton
var item_grid:GridContainer
var recipe_grid:GridContainer
var inventory_left:VBoxContainer
var inventory_right:VBoxContainer
var inspector_image:TextureRect
var fuel_image:TextureRect
var fuel_preview:Label
var ignition_reason:Label
var drop_amount:SpinBox
var belt_buttons:Array[Button]=[]
var item_empty:Label
var condition_info:Label
var condition_values:Dictionary={}
var supply_select:OptionButton
var fire_page:VBoxContainer
var sleep_page:VBoxContainer

func label(parent:Node,text:String,size:int=14) -> Label:
 var n:=Label.new();n.text=text;n.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;n.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 n.add_theme_font_size_override("font_size",size);parent.add_child(n);return n
func button(parent:Node,id:String,text:String,action:Callable) -> Button:
 var n:=Button.new();n.text=text;n.tooltip_text=text;n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;Journal.action(n)
 n.pressed.connect(action);parent.add_child(n);buttons[id]=n;Style.wire_button_sound(n);return n
func column(parent:Node,gap:int=10) -> VBoxContainer:
 var n:=VBoxContainer.new();n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;n.add_theme_constant_override("separation",gap);parent.add_child(n);return n
func row(parent:Node,gap:int=10) -> HBoxContainer:
 var n:=HBoxContainer.new();n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;n.add_theme_constant_override("separation",gap);parent.add_child(n);return n
func scroll(parent:Node) -> ScrollContainer:
 var n:=ScrollContainer.new();n.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;n.size_flags_vertical=Control.SIZE_EXPAND_FILL;parent.add_child(n);return n
func picker(parent:Node) -> OptionButton:
 var n:=OptionButton.new();n.custom_minimum_size.y=44;n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;n.clip_text=true;parent.add_child(n);return n
func picture(parent:Node,key:String,height:int=120) -> TextureRect:
 var n:=TextureRect.new();n.texture=Art.texture(key);n.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;n.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;n.custom_minimum_size.y=height;n.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(n);return n
func heading(parent:Node,text:String,size:int=22) -> Label:
 var n:=label(parent,text,size);n.add_theme_font_override("font",Journal.title_font());n.add_theme_color_override("font_color",Journal.GOLD);return n
func page(title:String) -> VBoxContainer:
 var n:=VBoxContainer.new();n.name=title;n.add_theme_constant_override("separation",12);tabs.add_child(n);return n
func sheet(parent:Node) -> VBoxContainer:
 var panel:=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel.add_theme_stylebox_override("panel",Journal.box(Color(0.06,0.09,0.075,0.85),Journal.LINE));parent.add_child(panel);return column(panel)

func build(p:Node) -> void:
 player=p
 p._inv_layer=CanvasLayer.new();p._inv_layer.name="InventoryLayer";p._inv_layer.layer=110;p._inv_layer.hide();p.add_child(p._inv_layer)
 var shade:=ColorRect.new();shade.color=Color(0.015,0.023,0.02,0.93);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);p._inv_layer.add_child(shade)
 p._inv_root_panel=PanelContainer.new();p._inv_root_panel.name="InventoryPanel";p._inv_root_panel.theme=Journal.theme()
 p._inv_root_panel.add_theme_stylebox_override("panel",Journal.box(Journal.INK,Journal.LINE));p._inv_layer.add_child(p._inv_root_panel)
 var bg:=TextureRect.new();bg.texture=load(Art.ROOT+"journal_background.jpg");bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;bg.modulate=Color(0.7,0.75,0.67,0.55);p._inv_root_panel.add_child(bg)
 var margin:=MarginContainer.new();margin.add_theme_constant_override("margin_left",8);margin.add_theme_constant_override("margin_right",8);margin.add_theme_constant_override("margin_top",4);p._inv_root_panel.add_child(margin)
 var layout:=column(margin,10)
 var head:=row(layout);var mast:=column(head,0);label(mast,"DEADLY NIGHT  /  ПОЛЕВОЙ ЖУРНАЛ",11).add_theme_color_override("font_color",Journal.MUTED);heading(mast,"Снаряжение",30)
 button(head,"close","Закрыть   ·   Tab / Esc",func():player._toggle_inventory()).size_flags_horizontal=0
 var mass:=row(layout);p._inv_weight_label=label(mass,"");p._inv_overweight_warning=label(mass,"")
 p._inv_weight_bar=ProgressBar.new();p._inv_weight_bar.max_value=p.max_backpack_kg;p._inv_weight_bar.show_percentage=false;p._inv_weight_bar.custom_minimum_size.y=4;layout.add_child(p._inv_weight_bar)
 tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;tabs.add_theme_font_size_override("font_size",15);layout.add_child(tabs)
 tabs.tab_changed.connect(func(_index):call_deferred("_focus_page"))
 _build_inventory();_build_craft();_build_fire();_build_sleep();_build_condition()
 layout.add_child(HSeparator.new())
 status=label(layout,"",13);status.custom_minimum_size.y=20
 var action:=row(layout);progress=ProgressBar.new();progress.show_percentage=false;progress.size_flags_horizontal=Control.SIZE_EXPAND_FILL;progress.custom_minimum_size.y=8;progress.size_flags_vertical=Control.SIZE_SHRINK_CENTER;action.add_child(progress)
 button(action,"cancel","Прервать",func():player.survival.cancel_job();refresh_actions()).size_flags_horizontal=0
 p._inv_root_panel.minimum_size_changed.connect(func():call_deferred("resize"))
 get_viewport().size_changed.connect(resize);resize();refresh_actions()

func _build_inventory() -> void:
 var inventory:=page("Рюкзак")
 var toolbar:=row(inventory,8)
 search=LineEdit.new();search.placeholder_text="Найти предмет…";search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;search.custom_minimum_size=Vector2(80,44);toolbar.add_child(search)
 category=picker(toolbar);category.size_flags_horizontal=0
 for name in ["Все предметы","Ресурсы","Топливо","Размещаемое","Еда и вода","Медицина"]:category.add_item(name)
 sorting=picker(toolbar);sorting.size_flags_horizontal=0
 for name in ["По ячейке","По имени","По весу"]:sorting.add_item(name)
 search.text_changed.connect(func(_value):refresh_inventory());category.item_selected.connect(func(_value):refresh_inventory());sorting.item_selected.connect(func(_value):refresh_inventory())
 var body:=row(inventory,20);body.size_flags_vertical=Control.SIZE_EXPAND_FILL
 inventory_left=column(body,8);inventory_left.size_flags_stretch_ratio=1.12
 var sc:=scroll(inventory_left);var content:=column(sc)
 item_grid=GridContainer.new();item_grid.columns=8;item_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;item_grid.add_theme_constant_override("h_separation",6);item_grid.add_theme_constant_override("v_separation",6);content.add_child(item_grid)
 for i in player.MAX_SLOTS:
  var card:=Card.new();card.name="Item_%d" % i;card.pressed.connect(player._on_slot_clicked.bind(i));item_grid.add_child(card);player._inv_slot_buttons.append(card)
 item_empty=label(content,"Ничего не найдено. Измените поиск или категорию.");item_empty.hide()
 label(inventory_left,"ЗАКРЕПЛЁННЫЕ ИНСТРУМЕНТЫ",11).add_theme_color_override("font_color",Journal.MUTED)
 var tools:=row(inventory_left,4)
 for i in 5:
  var b:=Button.new();b.icon=Art.texture(["axe","lantern","compass","matches","knife"][i]);b.expand_icon=true;b.custom_minimum_size=Vector2(44,44);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.add_theme_constant_override("icon_max_width",30);b.tooltip_text=player.HOTBAR_CONFIG[i].name+" · "+str(i+1);b.pressed.connect(player.select_hotbar_slot.bind(i));tools.add_child(b)
 right_scroll=scroll(body);right_scroll.size_flags_stretch_ratio=1.0;inventory_right=column(right_scroll,10)
 p_inspector()
func p_inspector() -> void:
 player._inv_empty_inspector_label=label(inventory_right,"Выберите предмет\n\nОписание, применение и быстрые назначения появятся здесь.",18)
 player._inv_inspector_box=column(inventory_right,8)
 inspector_image=picture(player._inv_inspector_box,"",108)
 player._inv_details_title=heading(player._inv_inspector_box,"",24)
 player._inv_details_category=label(player._inv_inspector_box,"");player._inv_details_category.add_theme_color_override("font_color",Journal.MUTED)
 player._inv_details_stats=label(player._inv_inspector_box,"");player._inv_inspector_box.add_child(HSeparator.new());player._inv_details_desc=label(player._inv_inspector_box,"")
 button(player._inv_inspector_box,"use_supply","Использовать",func():player.survival.use_supply(player._selected_slot_index);refresh_actions())
 button(player._inv_inspector_box,"place","Разместить костёр",func():player.survival.begin_placement())
 button(player._inv_inspector_box,"recipe_link","Открыть рецепт раскола",func():select_recipe("split_"+str(player.inventory_slots[player._selected_slot_index].get("species","birch")));tabs.current_tab=1)
 button(player._inv_inspector_box,"fuel_link","Добавить в костёр…",func():focus_fire();fuel_select.select(fuel_select.get_item_index(player._selected_slot_index));refresh_actions())
 label(player._inv_inspector_box,"БЫСТРЫЙ ДОСТУП  /  ПОЯС",11).add_theme_color_override("font_color",Journal.MUTED)
 var beltrow:=row(player._inv_inspector_box,6);belt_select=picker(beltrow)
 for i in 3:belt_select.add_item("Ячейка %d" % (i+6),i)
 button(beltrow,"belt","Назначить",func():player.assign_belt_item(player._selected_slot_index,belt_select.get_selected_id());refresh_actions())
 var belticons:=row(player._inv_inspector_box,6)
 for i in 3:
  var b:=Button.new();b.text=str(i+6);b.expand_icon=true;b.add_theme_constant_override("icon_max_width",30);b.custom_minimum_size.y=44;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.pressed.connect(func():belt_select.select(i));belticons.add_child(b);belt_buttons.append(b)
 button(player._inv_inspector_box,"unbelt","Убрать назначение",func():player.clear_belt_item(belt_select.get_selected_id());refresh_actions())
 belt_info=label(player._inv_inspector_box,"",12)
 var drops:=row(player._inv_inspector_box,6)
 drop_amount=SpinBox.new();drop_amount.min_value=1;drop_amount.max_value=10;drop_amount.value=1;drop_amount.custom_minimum_size=Vector2(70,44);drops.add_child(drop_amount)
 player._inv_btn_drop_one=button(drops,"drop_one","Выбросить",func():player.drop_selected_amount(int(drop_amount.value)))
 player._inv_btn_drop_all=button(drops,"drop_all","Всё",func():player.drop_selected_item(true))

func _build_craft() -> void:
 var craft:=page("Крафт");var toolbar:=row(craft)
 label(toolbar,"РЕЦЕПТЫ  /  ИЗГОТОВЛЕНИЕ В РЮКЗАКЕ",11).add_theme_color_override("font_color",Journal.MUTED)
 only_available=CheckButton.new();only_available.text="Доступные";only_available.custom_minimum_size.y=44;toolbar.add_child(only_available);only_available.toggled.connect(func(_value):refresh_actions())
 var body:=row(craft,20);body.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var left:=column(scroll(body));left.size_flags_stretch_ratio=1.12
 recipe_grid=GridContainer.new();recipe_grid.columns=4;recipe_grid.add_theme_constant_override("h_separation",8);recipe_grid.add_theme_constant_override("v_separation",8);left.add_child(recipe_grid)
 for r in Catalog.RECIPES:
  var card:=Card.new();card.custom_minimum_size.y=95;card.pressed.connect(select_recipe.bind(r.id));recipe_grid.add_child(card);recipe_cards[r.id]=card
 recipe_empty=label(left,"Пока нет доступных рецептов. Соберите материалы или выключите фильтр.");recipe_empty.hide()
 var detail_column:=column(body,8)
 var right:=column(scroll(detail_column),10)
 var recipe_head:=row(right,12);recipe_image=picture(recipe_head,"camp_kit",72);recipe_image.custom_minimum_size.x=90;recipe_title=heading(recipe_head,"",24)
 right.add_child(HSeparator.new());label(right,"МАТЕРИАЛЫ",11).add_theme_color_override("font_color",Journal.MUTED)
 for i in 2:
  var line:=row(right,8);var icon:=picture(line,"",36);icon.custom_minimum_size.x=36;var text:=label(line,"");ingredient_rows.append({"row":line,"icon":icon,"text":text})
 recipe_tool=label(right,"");recipe=label(right,"");recipe_desc=label(right,"")
 log_select=picker(right);log_select.item_selected.connect(func(_index):refresh_actions())
 button(detail_column,"kit","Собрать набор",func():player.survival.make_kit())
 button(detail_column,"split","Расколоть · 10 с",func():player.survival.begin_split(log_select.get_selected_id()))
 label(detail_column,"Готовый набор: «Рюкзак» → разместить или назначить на пояс.",12).add_theme_color_override("font_color",Journal.MUTED)

func _build_fire() -> void:
 fire_page=VBoxContainer.new();fire_page.name="FireInteraction";fire_page.size_flags_vertical=Control.SIZE_EXPAND_FILL;tabs.get_parent().add_child(fire_page);fire_page.hide()
 var camp:=fire_page;var body:=row(camp,20);body.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var overview:=column(scroll(body));overview.size_flags_stretch_ratio=0.65
 picture(overview,"campfire",170);heading(overview,"Огонь в лесу",24);fire_info=label(overview,"")
 label(overview,"Огонь согревает и сушит. Дождь ускоряет расход топлива. Брёвна сначала нужно расколоть.",14).add_theme_color_override("font_color",Journal.MUTED)
 var controls:=column(scroll(body),12)
 var fuel:=sheet(controls);heading(fuel,"01  /  Топливо",18)
 var selectrow:=row(fuel,8);fuel_image=picture(selectrow,"firewood_birch",44);fuel_image.custom_minimum_size.x=44
 fuel_select=picker(selectrow);fuel_select.item_selected.connect(func(_index):refresh_actions())
 fuel_amount=SpinBox.new();fuel_amount.min_value=1;fuel_amount.max_value=10;fuel_amount.step=1;fuel_amount.value=1;fuel_amount.custom_minimum_size=Vector2(72,44);selectrow.add_child(fuel_amount);fuel_amount.value_changed.connect(func(_value):refresh_actions())
 fuel_preview=label(fuel,"");button(fuel,"fuel","Добавить топливо",func():player.survival.add_fuel(player.survival.selected_fire,fuel_select.get_selected_id(),int(fuel_amount.value)))
 var tinder:=sheet(controls);heading(tinder,"02  /  Растопка",18);button(tinder,"tinder","Добавить хворост · 1 шт.",func():player.survival.add_tinder(player.survival.selected_fire))
 var ignition:=sheet(controls);heading(ignition,"03  /  Розжиг",18)
 var matchbutton:=button(ignition,"match","Спичка",func():player.survival.begin_ignition(player.survival.selected_fire,"match"));matchbutton.icon=Art.texture("matches");matchbutton.expand_icon=true;matchbutton.add_theme_constant_override("icon_max_width",32)
 var sparkbutton:=button(ignition,"spark","Кремень + пирит",func():player.survival.begin_ignition(player.survival.selected_fire,"spark"));sparkbutton.icon=Art.texture("flint");sparkbutton.expand_icon=true;sparkbutton.add_theme_constant_override("icon_max_width",32)
 ignition_reason=label(ignition,"",12)

func _build_sleep() -> void:
 sleep_page=VBoxContainer.new();sleep_page.name="SleepInteraction";sleep_page.size_flags_vertical=Control.SIZE_EXPAND_FILL;tabs.get_parent().add_child(sleep_page);sleep_page.hide()
 var sleep:=sleep_page;var body:=row(sleep,24);body.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var overview:=column(scroll(body));overview.size_flags_stretch_ratio=0.65
 picture(overview,"bedroll",180);heading(overview,"До рассвета",24)
 label(overview,"Отдыхайте в защищённой стоянке. Огонь, холод и погода продолжают действовать во время сна.").add_theme_color_override("font_color",Journal.MUTED)
 var controls:=column(scroll(body),16);heading(controls,"Продолжительность сна",24);sleep_value=label(controls,"",22)
 sleep_hours=HSlider.new();sleep_hours.min_value=1;sleep_hours.max_value=12;sleep_hours.step=1;sleep_hours.value=1;sleep_hours.custom_minimum_size.y=44;sleep_hours.tick_count=12;controls.add_child(sleep_hours);sleep_hours.value_changed.connect(func(_value):refresh_actions())
 var limits:=row(controls);label(limits,"1 час",12);var end:=label(limits,"12 часов",12);end.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 var condition:=sheet(controls);sleep_info=label(condition,"")
 rest=button(controls,"rest","Спать",func():player.survival.begin_rest(int(sleep_hours.value)))
 label(controls,"Сон прервётся при опасном холоде или открытой двери. Один игровой час занимает одну реальную секунду.",13).add_theme_color_override("font_color",Journal.MUTED)

func resize() -> void:
 if not is_instance_valid(player) or not is_inside_tree() or not player.is_inside_tree() or get_viewport()==null:return
 var size:=get_viewport().get_visible_rect().size
 var physical:=Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name()!="headless" else size
 ui_scale=maxf(1.0,size.x/maxf(1,physical.x))
 var dim:=Vector2(minf(1240*ui_scale,size.x-32*ui_scale),minf(820*ui_scale,size.y-32*ui_scale))
 player._inv_root_panel.size=dim;player._inv_root_panel.position=(size-dim)/2
 item_grid.columns=6 if dim.x<960*ui_scale else 8
 for card in player._inv_slot_buttons:card.set_card_size(Vector2(38,75)*ui_scale,ui_scale)
 for card in recipe_cards.values():card.set_card_size(Vector2(55,95)*ui_scale,ui_scale,true)
 for node in player._inv_root_panel.find_children("*","Control",true,false):
  if node is Label or node is Button or node is TabContainer or node is LineEdit:
   if not node.has_meta("journal_font"):node.set_meta("journal_font",node.get_theme_font_size("font_size"))
   var font_size:=roundi(float(node.get_meta("journal_font"))*ui_scale)
   if node.get_theme_font_size("font_size")!=font_size:node.add_theme_font_size_override("font_size",font_size)
  if node is Button and not node is Card:node.custom_minimum_size.y=44*ui_scale
 buttons["close"].custom_minimum_size.x=170*ui_scale
func _process(delta:float) -> void:
 _tick-=delta
 if _tick<=0:
  _tick=0.1
  if is_instance_valid(player) and player._is_inventory_open:refresh_actions()
func _focus_page() -> void:
 if not player._is_inventory_open:return
 resize()
 Style.trap_focus(player._inv_root_panel)
func hide_sleep() -> void:
 if is_instance_valid(sleep_page):sleep_page.hide()
 if is_instance_valid(tabs):tabs.show()
func hide_context_pages() -> void:
 if is_instance_valid(fire_page):fire_page.hide()
 hide_sleep()
func focus_condition() -> void:
 hide_context_pages();tabs.current_tab=2
func focus_rest() -> void:
 if not is_instance_valid(player.survival) or not player.survival.has_sleep_access():return
 fire_page.hide();tabs.hide();sleep_page.show()
func focus_fire() -> void:
 if not is_instance_valid(player.survival) or player.survival.nearby_fire().is_empty():return
 sleep_page.hide();tabs.hide();fire_page.show()
func show_selection() -> void:
 hide_context_pages();tabs.current_tab=0;right_scroll.scroll_vertical=0
func select_recipe(id:String) -> void:
 hide_context_pages();tabs.current_tab=1
 selected_recipe=id;_inventory_signature="";refresh_actions()
func _update_picker(node:OptionButton,types:Array,empty:String,species:String="") -> void:
 if node.get_popup().visible:return
 var selected:=node.get_selected_id();node.clear()
 for i in player.inventory_slots.size():
  var item=player.inventory_slots[i]
  if item!=null and item.get("type","") in types and (species=="" or item.get("species")==species):node.add_item("%s ×%d" % [item.get("name","Предмет"),item["count"]],i)
 if node.item_count==0:node.text=empty
 elif node.get_item_index(selected)>=0:node.select(node.get_item_index(selected))
func refresh_inventory() -> void:
 if not is_instance_valid(player) or search==null:return
 var visible_count:=0;var order:Array=range(player.MAX_SLOTS)
 if sorting.selected==1:order.sort_custom(func(a,b):return str((player.inventory_slots[a] if player.inventory_slots[a]!=null else {}).get("name","яяя"))<str((player.inventory_slots[b] if player.inventory_slots[b]!=null else {}).get("name","яяя")))
 elif sorting.selected==2:order.sort_custom(func(a,b):return _slot_weight(a)>_slot_weight(b))
 for rank in order.size():
  var index:int=order[rank]
  var card=player._inv_slot_buttons[index]
  if card.get_index()!=rank:item_grid.move_child(card,rank)
  var item=player.inventory_slots[index];var chosen:bool=index==player._selected_slot_index
  if item==null:
   card.visible=category.selected==0 and search.text.is_empty();card.present("","Пустая ячейка","","",chosen);continue
  var kind:String=item.get("type","");var title:String=item.get("name","Предмет")
  var accepted:=search.text.is_empty() or title.to_lower().contains(search.text.to_lower())
  if category.selected==1:accepted=accepted and kind in ["stone","flint","pyrite","brush","log"]
  elif category.selected==2:accepted=accepted and kind in ["firewood","brush"]
  elif category.selected==4:accepted=accepted and kind in ["water","raw_water","ration","berries"]
  elif category.selected==5:accepted=accepted and kind in ["bandage","compress"]
  elif category.selected==3:accepted=accepted and kind=="camp_kit"
  card.visible=accepted
  if accepted:visible_count+=1
  var stamp:="×%d" % int(item.get("count",1))
  for i in player.belt_items.size():
   if player.belt_items[i]==item.get("id"):stamp+="  ·  [%d]" % (i+6)
  var short_title:=title.replace(" полено"," · бревно").replace("Поленце (","Поленья · ").replace(")","")
  card.present(Art.item_key(item),short_title,"%.1f кг" % _slot_weight(index),stamp,chosen)
 item_empty.visible=visible_count==0 and (category.selected!=0 or not search.text.is_empty())
 var item:Dictionary={}
 if player._selected_slot_index>=0 and player._selected_slot_index<player.MAX_SLOTS and player.inventory_slots[player._selected_slot_index]!=null:item=player.inventory_slots[player._selected_slot_index]
 player._inv_empty_inspector_label.visible=item.is_empty();player._inv_inspector_box.visible=not item.is_empty()
 if item.is_empty():return
 inspector_image.texture=Art.texture(Art.item_key(item));player._inv_details_title.text=item.get("name","")
 player._inv_details_category.text={"log":"ДРЕВЕСИНА / БРЕВНО","firewood":"ТОПЛИВО","brush":"РАСТОПКА / ТОПЛИВО","camp_kit":"РАЗМЕЩАЕМЫЙ НАБОР","water":"ПИТЬЕВАЯ ВОДА","raw_water":"ВОДА / НУЖНО КИПЯТИТЬ","ration":"ПИТАНИЕ","berries":"ПИТАНИЕ / СБОР","bandage":"МЕДИЦИНА","compress":"МЕДИЦИНА"}.get(item.get("type",""),"ПРИРОДНЫЙ МАТЕРИАЛ")
 var count:=int(item.get("count",1));var weight:=float(item.get("unit_weight",0))
 player._inv_details_stats.text="%d шт.   /   %.2f кг за шт.   /   %.2f кг всего" % [count,weight,count*weight]
 if item.get("type")=="firewood" and is_instance_valid(player.survival):player._inv_details_stats.text+="\nГорение: %d мин за поленце" % int(player.survival.Fire.FUEL_SECONDS.get(item.get("species","birch"),1800)/60)
 elif item.get("type")=="brush":player._inv_details_stats.text+="\nГорение: 5 мин за единицу"
 player._inv_details_desc.text=item.get("description","");drop_amount.max_value=maxi(1,count)
func _slot_weight(index:int) -> float:
 var item=player.inventory_slots[index];return 0 if item==null else float(item.get("unit_weight",0))*int(item.get("count",0))
func _refresh_recipe() -> void:
 var visible_count:=0
 for data in Catalog.RECIPES:
  var reason:=Catalog.reason(player,data);var card=recipe_cards[data.id]
  card.visible=not only_available.button_pressed or reason==""
  if card.visible:visible_count+=1
  card.present(data.icon,data.title,"×%d  /  %s" % [data.output,"сборка" if data.seconds==0 else "%d с" % data.seconds],"Можно создать" if reason=="" else reason,selected_recipe==data.id,reason=="")
 recipe_empty.visible=visible_count==0
 var data:=Catalog.recipe(selected_recipe);recipe_image.texture=Art.texture(data.icon);recipe_title.text=data.title;recipe_desc.text=data.description
 var ingredients:Array=[]
 if data.action=="kit":
  for id in data.costs:ingredients.append({"icon":id,"title":{"stone":"Камни","brush":"Хворост"}.get(id,id),"have":player.survival.Items.count(player.inventory_slots,id) if is_instance_valid(player.survival) else 0,"need":data.costs[id]})
 else:
  var amount:=0
  for slot in Catalog.source_slots(player,data):amount+=int(player.inventory_slots[slot].count)
  ingredients.append({"icon":"log_"+str(data.species),"title":"Бревно нужной породы","have":amount,"need":1})
 for i in ingredient_rows.size():
  var entry:Dictionary=ingredient_rows[i];entry.row.visible=i<ingredients.size()
  if i>=ingredients.size():continue
  var material:Dictionary=ingredients[i];entry.icon.texture=Art.texture(material.icon)
  entry.text.text="%s   %d / %d  ·  %s" % [material.title,material.have,material.need,"есть" if material.have>=material.need else "не хватает"]
  entry.text.add_theme_color_override("font_color",Journal.GREEN if material.have>=material.need else Journal.RED)
 recipe_tool.text="Топор с пояса  ·  10 реальных секунд  ·  выход ×3" if data.action=="split" else "Без инструмента  ·  выход ×1"
 recipe.text=Catalog.reason(player,data)
 log_select.visible=data.action=="split";buttons["kit"].visible=data.action=="kit";buttons["split"].visible=data.action=="split"
 buttons[data.action].disabled=recipe.text!=""
 buttons[data.action].tooltip_text=recipe.text if recipe.text!="" else ("Собрать один набор" if data.action=="kit" else "Расколоть выбранное бревно за 10 секунд")
func refresh_actions() -> void:
 if not is_instance_valid(player):return
 var s=player.survival;var valid:=is_instance_valid(s)
 var item:Dictionary={}
 if player._selected_slot_index>=0 and player._selected_slot_index<player.inventory_slots.size() and player.inventory_slots[player._selected_slot_index]!=null:item=player.inventory_slots[player._selected_slot_index]
 var type:String=item.get("type","")
 var busy:bool=valid and (not s.job.is_empty() or s.health<=0)
 buttons["use_supply"].visible=type in ["water","raw_water","ration","berries","bandage","compress"]
 buttons["use_supply"].disabled=busy or not valid
 buttons["use_supply"].text={"water":"Выпить · 0,5 л","raw_water":"Кипятить у костра · 5 мин","ration":"Съесть рацион","berries":"Съесть ягоды","bandage":"Перевязать рану","compress":"Наложить компресс"}.get(type,"Использовать")
 if valid:_refresh_condition(s)
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
  _inventory_signature=signature;_update_picker(log_select,["log"],"Нет брёвен нужной породы",str(Catalog.recipe(selected_recipe).get("species","")));_update_picker(fuel_select,["firewood","brush"],"Нет топлива — расколите бревно")
 buttons["kit"].disabled=busy or not valid;buttons["split"].disabled=busy or not valid or log_select.get_selected_id()<0
 if not valid:
  for id in ["fuel","tinder","match","spark","rest"]:buttons[id].disabled=true
 var active:bool=valid and not s.job.is_empty()
 progress.visible=active;buttons["cancel"].visible=active;buttons["cancel"].disabled=not active
 if not valid:
  recipe.text="Крафт доступен в игровом мире.";fire_info.text="Костёр недоступен.";sleep_info.text="Сон доступен в игровой стоянке."
  status.text="Выберите предмет в сетке."
  buttons["recipe_link"].visible=type=="log";buttons["recipe_link"].disabled=true
  buttons["fuel_link"].visible=type in ["firewood","brush"];buttons["fuel_link"].disabled=true
  _refresh_recipe();refresh_inventory();return
 var brush:int=s.Items.count(player.inventory_slots,"brush");var stones:int=s.Items.count(player.inventory_slots,"stone")

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
 sleep_info.text="Отдых %.0f%% · тепло %.0f%% · здоровье %.0f%%\nВода %.0f%% → ~%.0f%% · питание %.0f%% → ~%.0f%%\n%s" % [s.energy,s.warmth,s.health,s.body.water,maxf(0,s.body.water-hours*3.6),s.body.food,maxf(0,s.body.food-hours*2.1),reason if reason!="" else "Потребности расходуются. Сон прервётся при опасном состоянии."]
 rest.text="Спать %d ч" % hours;rest.disabled=busy or reason!=""
 sleep_hours.editable=not busy
 status.text=s.message if s.message_time>0 else "Мир не на паузе. Tab / Esc закрывает рюкзак и отменяет действие."
 if active:
  progress.max_value=float(s.job["duration"]);progress.value=float(s.job["elapsed"])
  status.text="%s · %.1f / %.1f с" % [{"split":"Раскол","ignite":"Розжиг","rest":"Сон","boil":"Кипячение"}.get(s.job["kind"],"Действие"),s.job["elapsed"],s.job["duration"]]

 # Refresh content in place; never hide/re-enable a pressed control as an intermediate state.
 buttons["recipe_link"].visible=type=="log";buttons["recipe_link"].disabled=busy
 buttons["fuel_link"].visible=type in ["firewood","brush"];buttons["fuel_link"].disabled=busy or not ready
 drop_amount.editable=not busy
 player._inv_btn_drop_one.text="Выбросить";player._inv_btn_drop_all.text="Всё"
 for i in belt_buttons.size():
  var slot:int=player.belt_item_slot(i)
  var entry:Dictionary=player.inventory_slots[slot] if slot>=0 else {}
  belt_buttons[i].icon=Art.texture(Art.item_key(entry)) if not entry.is_empty() else null
  belt_buttons[i].tooltip_text="%d: %s" % [i+6,entry.get("name","Пустая ячейка")]
 if fuel_slot>=0 and available>0:
  var fuel:Dictionary=player.inventory_slots[fuel_slot];fuel_image.texture=Art.texture(Art.item_key(fuel))
  var seconds:float=300 if fuel.get("type")=="brush" else float(s.Fire.FUEL_SECONDS.get(fuel.get("species","birch"),1800))
  fuel_preview.text="Добавить %d шт. → +%d мин горения" % [int(fuel_amount.value),int(seconds*fuel_amount.value/60)]
 else:fuel_image.texture=null;fuel_preview.text="Нет топлива. Расколите бревно во вкладке «Крафт»."
 var ignition_block:=""
 if busy:ignition_block="Завершите текущее действие."
 elif not ready:ignition_block="Нужен костёр рядом, без препятствия между вами."
 elif f["state"]=="burning":ignition_block="Огонь уже горит. Можно добавить топливо."
 elif f["fuel"]<=0:ignition_block="Сначала добавьте топливо."
 elif f["tinder"]<=0:ignition_block="Добавьте сухую растопку."
 else:ignition_block="Одна попытка расходует растопку; спичка тоже расходуется при старте."
 ignition_reason.text=ignition_block
 buttons["fuel"].tooltip_text="Подойдите к костру и выберите топливо" if buttons["fuel"].disabled else fuel_preview.text
 buttons["match"].text="Спичка · %d%% · 2 с · осталось %d" % [roundi(s.ignition_chance("match")*100),s.matches]
 buttons["match"].tooltip_text=ignition_block+(" Нет спичек." if s.matches<1 else "")
 buttons["spark"].tooltip_text=ignition_block+" Нужны кремень и пирит; инструменты не расходуются."
 rest.tooltip_text="Завершите текущее действие." if busy else ("Начать выбранный отдых" if not rest.disabled else s.rest_block_reason())
 _refresh_recipe();refresh_inventory()

func _build_condition() -> void:
 var health_page:=page("Состояние");var body_row:=row(health_page,20);body_row.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var overview:=column(scroll(body_row),12)
 heading(overview,"Состояние персонажа",24)
 for id in ["health","warmth","water","food","energy","stamina","wetness"]:
  var line:=row(overview,8);var text:=label(line,{"health":"Здоровье","warmth":"Тепло","water":"Вода","food":"Питание","energy":"Отдых","stamina":"Выносливость","wetness":"Промокание"}[id],14)
  var bar:=ProgressBar.new();bar.custom_minimum_size=Vector2(90,20);bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bar.show_percentage=false;line.add_child(bar);var value_text:=label(line,"100%",14);value_text.size_flags_horizontal=0;value_text.custom_minimum_size.x=55;value_text.autowrap_mode=TextServer.AUTOWRAP_OFF;value_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;condition_values[id]={"label":text,"bar":bar,"value":value_text}
 label(overview,"Здоровье — последствия. Выносливость возвращается после передышки; усталость требует сна. Лечение останавливает причину, а не мгновенно возвращает здоровье.",14)
 var details:=column(scroll(body_row),12);heading(details,"Травмы и восстановление",24);condition_info=label(details,"")
 label(details,"Безопасная вода и готовая еда используются из рюкзака. У стоянки есть ограниченные припасы и дождесборник; съедобные ягоды встречаются в лесу. Сырую воду кипятите у горящего костра.",14)
 supply_select=picker(details)
 button(details,"condition_use","Использовать выбранный припас",func():player.survival.use_supply(supply_select.get_selected_id());refresh_actions())
 label(details,"Сон — подойдите к кровати и нажмите E. Здесь меню сна не открывается.",13)
 label(details,"Восстановление здоровья: сон, тепло выше 45%, питание и вода, отсутствие кровотечения и переохлаждения. Травма ноги проходит за 4 игровых часа или быстрее во сне.",13)
func _refresh_condition(s:Node) -> void:
 for id in condition_values:
  var value:float=s.body.get(id) if id in ["water","food","stamina"] else s.get(id)
  condition_values[id].bar.value=value
  condition_values[id].value.text="%.0f%%" % value
  var danger:bool=value>70 if id=="wetness" else value<20
  condition_values[id].value.add_theme_color_override("font_color",Color("f0a78e") if danger else Color("eee5d3"))
 condition_info.text=("Причина гибели: "+s.body.death_reason+"\n" if s.health<=0 else "")+s.body.describe()
 _update_picker(supply_select,["water","raw_water","ration","berries","bandage","compress"],"Нет еды, воды или медикаментов")
 buttons["condition_use"].disabled=s.health<=0 or not s.job.is_empty() or supply_select.item_count==0
