extends Node
# Persistent scene controls: no frame-by-frame rebuilding, no lost mouse releases.
const Style=preload("res://scripts/ui/UITheme.gd")
const Journal=preload("res://scripts/ui/JournalTheme.gd")
const Art=preload("res://scripts/ui/JournalArt.gd")
const Card=preload("res://scripts/ui/JournalCard.gd")
const ItemRow=preload("res://scripts/ui/JournalItemRow.gd")
const Catalog=preload("res://scripts/survival/CraftCatalog.gd")
const Plants=preload("res://scripts/vegetation/VegetationCatalog.gd")
var cook_select:OptionButton
var cook_amount:SpinBox
var cook_info:Label
var guide_entries:Dictionary={}
var _guide_signature:=""
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
var inspector_column:VBoxContainer
var right_scroll:ScrollContainer
var rest:Button
var ui_scale:=1.0
var _tick:=0.0
var _resize_pending:=false
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
var condition_temperature:Label
var condition_climate:Label
var condition_calories:Label
var condition_info:Label
var condition_values:Dictionary={}
var supply_select:OptionButton
var fire_page:VBoxContainer
var sleep_page:VBoxContainer

var navigation:VBoxContainer
var category_buttons:Array[Button]=[]
var tool_rows:Array[Button]=[]
var quick_buttons:Array[Button]=[]
var quick_keys:Array[Label]=[]
var quick_values:Array[Label]=[]
var quick_strip:HBoxContainer
var list_summary:Label
var application:Label
var belt_group:VBoxContainer
var drop_group:HBoxContainer
var selected_tool:=-1
var _hud_visibility:Dictionary={}
var _detail_key:=""
var _detail_tween:Tween
const CATEGORY_NAMES=["Все предметы","Ресурсы","Топливо","Снаряжение","Еда и вода","Медицина","Инструменты"]
const TOOL_KEYS=["axe","lantern","compass","matches","knife"]
const TOOL_USE=["Рубка деревьев и раскол брёвен во вкладке «Крафт».","Переносной источник света. Переключается действием выбранного инструмента.","Ориентирование по сторонам света.","Розжиг подготовленного костра. Спички расходуются при попытке розжига.","Постоянный инструмент. Обработка ресурсов ножом пока не реализована."]

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
 var shade:=ColorRect.new();shade.color=Color(0.015,0.023,0.02,0.62);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);p._inv_layer.add_child(shade)
 p._inv_root_panel=PanelContainer.new();p._inv_root_panel.name="InventoryPanel";p._inv_root_panel.theme=Journal.theme()
 p._inv_root_panel.add_theme_stylebox_override("panel",Journal.box(Journal.INK,Journal.LINE));p._inv_layer.add_child(p._inv_root_panel)
 var bg:=TextureRect.new();bg.texture=load(Art.ROOT+"journal_background.jpg");bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;bg.modulate=Color(0.7,0.75,0.72,0.18);p._inv_root_panel.add_child(bg)
 var margin:=MarginContainer.new();margin.add_theme_constant_override("margin_left",8);margin.add_theme_constant_override("margin_right",8);margin.add_theme_constant_override("margin_top",4);p._inv_root_panel.add_child(margin)
 var layout:=column(margin,8)
 var head:=row(layout,16);var mast:=column(head,0)
 label(mast,"DEADLY NIGHT / ПОЛЕВОЙ ЖУРНАЛ",11).add_theme_color_override("font_color",Journal.MUTED);heading(mast,"Снаряжение",26)
 var capacity:=column(head,4);capacity.size_flags_vertical=Control.SIZE_SHRINK_CENTER;capacity.size_flags_horizontal=Control.SIZE_FILL;capacity.custom_minimum_size.x=280
 p._inv_weight_label=label(capacity,"");p._inv_overweight_warning=label(capacity,"",12)
 p._inv_weight_bar=ProgressBar.new();p._inv_weight_bar.max_value=p.max_backpack_kg;p._inv_weight_bar.show_percentage=false;p._inv_weight_bar.custom_minimum_size=Vector2(180,4);capacity.add_child(p._inv_weight_bar)
 button(head,"close","Закрыть · Tab / Esc",func():player._toggle_inventory()).size_flags_horizontal=0
 tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;tabs.add_theme_font_size_override("font_size",15);layout.add_child(tabs)
 tabs.tab_changed.connect(func(_index):call_deferred("_focus_page"))
 _build_inventory();_build_craft();_build_fire();_build_sleep();_build_condition();_build_guide()
 _build_quick_strip(layout)
 layout.add_child(HSeparator.new())
 status=label(layout,"",13);status.custom_minimum_size.y=16
 var action:=row(layout);progress=ProgressBar.new();progress.show_percentage=false;progress.size_flags_horizontal=Control.SIZE_EXPAND_FILL;progress.custom_minimum_size.y=8;progress.size_flags_vertical=Control.SIZE_SHRINK_CENTER;action.add_child(progress)
 button(action,"cancel","Прервать",func():player.survival.cancel_job();refresh_actions()).size_flags_horizontal=0
 p._inv_root_panel.minimum_size_changed.connect(_queue_resize)
 get_viewport().size_changed.connect(resize);resize();refresh_actions()

func _build_inventory() -> void:
 var inventory:=page("Рюкзак")
 var body:=row(inventory,16);body.size_flags_vertical=Control.SIZE_EXPAND_FILL
 navigation=column(scroll(body),4);navigation.get_parent().size_flags_horizontal=Control.SIZE_FILL
 label(navigation,"КАТЕГОРИИ",11).add_theme_color_override("font_color",Journal.MUTED)
 category=OptionButton.new();category.hide();navigation.add_child(category)
 var icons=["category_all","category_resources","category_fuel","category_equipment","category_food","category_medicine","category_tools"]
 for i in CATEGORY_NAMES.size():
  category.add_item(CATEGORY_NAMES[i]);var index:int=i
  var nav:=button(navigation,"category_%d" % i,CATEGORY_NAMES[i],func():category.select(index);_change_category())
  nav.alignment=HORIZONTAL_ALIGNMENT_LEFT;nav.icon=Art.texture(icons[i]);nav.expand_icon=true;nav.add_theme_constant_override("icon_max_width",18);nav.add_theme_font_size_override("font_size",14)
  var flat:=Journal.box(Color(0,0,0,0),Color(0,0,0,0),0);flat.content_margin_left=6;flat.content_margin_right=6;nav.add_theme_stylebox_override("normal",flat);category_buttons.append(nav)
 inventory_left=column(body,8)
 var toolbar:=row(inventory_left,6)
 search=LineEdit.new();search.placeholder_text="Поиск…";search.clear_button_enabled=true;search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;search.custom_minimum_size=Vector2(80,44);toolbar.add_child(search)
 sorting=picker(toolbar);sorting.size_flags_horizontal=Control.SIZE_FILL
 for title in ["По ячейке","По имени","По весу"]:sorting.add_item(title)
 search.text_changed.connect(func(_value):refresh_inventory());category.item_selected.connect(func(_value):_change_category());sorting.item_selected.connect(func(_value):refresh_inventory())
 list_summary=label(inventory_left,"",12);list_summary.add_theme_color_override("font_color",Journal.MUTED)
 var sc:=scroll(inventory_left);var content:=column(sc,4)
 item_grid=GridContainer.new();item_grid.columns=1;item_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;item_grid.add_theme_constant_override("v_separation",4);content.add_child(item_grid)
 for i in player.MAX_SLOTS:
  var card:=ItemRow.new();card.name="Item_%d" % i;var index:int=i
  card.pressed.connect(func():selected_tool=-1;if_selected(index));item_grid.add_child(card);player._inv_slot_buttons.append(card)
 for i in 5:
  var tool:=ItemRow.new();var index:int=i;tool.name="Tool_%d" % i;tool.pressed.connect(func():selected_tool=index;player._selected_slot_index=-1;refresh_actions());content.add_child(tool);tool_rows.append(tool)
 item_empty=label(content,"Рюкзак пуст.

Подбирайте припасы в мире. Постоянные инструменты доступны на поясе.",16)
 body.add_child(VSeparator.new())
 inspector_column=column(body,6);inspector_column.size_flags_vertical=Control.SIZE_EXPAND_FILL
 right_scroll=scroll(inspector_column);inventory_right=column(right_scroll,10)
 p_inspector()
func if_selected(index:int) -> void:
 if player._selected_slot_index==index:
  player._selected_slot_index=-1;refresh_actions()
 else:player._on_slot_clicked(index)
func _change_category() -> void:
 selected_tool=-1;player._selected_slot_index=-1;refresh_inventory()
 # Opacity only, never a changing minimum-size or a disappearing pressed control.
 inventory_left.modulate=Color(1,1,1,0.85)
 create_tween().tween_property(inventory_left,"modulate",Color.WHITE,0.10)
func _build_quick_strip(parent:Node) -> void:
 quick_strip=row(parent,6)
 var caption:=column(quick_strip,0);caption.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 label(caption,"БЫСТРЫЙ ДОСТУП",11).add_theme_color_override("font_color",Journal.MUTED)
 label(caption,"5 инструментов · 3 назначения",12)
 for i in 8:
  var index:int=i;var b:=Button.new();b.expand_icon=true;b.custom_minimum_size=Vector2(50,50);b.size_flags_horizontal=Control.SIZE_FILL;b.add_theme_constant_override("icon_max_width",32);quick_strip.add_child(b)
  b.pressed.connect(func():player.select_hotbar_slot(index);refresh_actions());quick_buttons.append(b)
  var key:=Label.new();key.mouse_filter=Control.MOUSE_FILTER_IGNORE;key.add_theme_font_size_override("font_size",11);b.add_child(key);key.position=Vector2(3,0);quick_keys.append(key)
  var value:=Label.new();value.mouse_filter=Control.MOUSE_FILTER_IGNORE;value.add_theme_font_size_override("font_size",10);value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;value.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);value.offset_top=-14;value.offset_right=-3;b.add_child(value);quick_values.append(value)
func _refresh_quick_strip() -> void:
 var bindings:Dictionary=player.SettingsManagerScript.get_instance().get_setting("controls","keybindings",{})
 for i in 8:
  var b:=quick_buttons[i];quick_keys[i].text=OS.get_keycode_string(int(bindings.get("hotbar_%d" % (i+1),KEY_1+i)))
  var title:="Не назначено";var key:="";var value:=""
  if i<5:
   key=TOOL_KEYS[i];title=player.HOTBAR_CONFIG[i].name
   if i==3 and is_instance_valid(player.survival):value=str(player.survival.matches)
   elif i==1:value="Вкл" if player._is_lantern_on else ""
  else:
   var slot:int=player.belt_item_slot(i-5)
   if slot>=0:
    var item:Dictionary=player.inventory_slots[slot];key=Art.item_key(item);title=item.name
    var count:=0
    for entry in player.inventory_slots:
     if entry!=null and entry.get("id")==item.id:count+=int(entry.count)
    value=str(count)
  b.icon=Art.texture(key) if key!="" else null;b.tooltip_text=quick_keys[i].text+" · "+title;quick_values[i].text=value
  var style:=Journal.box(Color("2c372f") if player.active_hotbar_slot==i else Color("16221f"),Journal.GOLD if player.active_hotbar_slot==i else Journal.LINE,1)
  style.content_margin_left=4;style.content_margin_right=4;style.content_margin_top=4;style.content_margin_bottom=4;b.add_theme_stylebox_override("normal",style)
func p_inspector() -> void:
 player._inv_empty_inspector_label=label(inventory_right,"Выберите предмет\n\nОписание, применение и быстрые назначения появятся здесь.",18)
 player._inv_inspector_box=column(inventory_right,8)
 var hero:=row(player._inv_inspector_box,12)
 inspector_image=picture(hero,"",112);inspector_image.custom_minimum_size.x=136;inspector_image.size_flags_horizontal=Control.SIZE_FILL
 var identity:=column(hero,6);identity.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 player._inv_details_category=label(identity,"",12);player._inv_details_category.add_theme_color_override("font_color",Journal.MUTED)
 player._inv_details_title=heading(identity,"",24)
 player._inv_details_stats=label(identity,"",14)
 player._inv_inspector_box.add_child(HSeparator.new());player._inv_details_desc=label(player._inv_inspector_box,"",16)
 application=label(player._inv_inspector_box,"",14);application.add_theme_color_override("font_color",Journal.MUTED)
 button(player._inv_inspector_box,"equip_tool","Выбрать инструмент",func():player.select_hotbar_slot(selected_tool);refresh_actions())
 button(player._inv_inspector_box,"use_supply","Использовать",func():player.survival.request_use_supply(player._selected_slot_index);refresh_actions())
 button(player._inv_inspector_box,"cook_link","Приготовить у костра…",func():focus_fire())
 button(player._inv_inspector_box,"place","Разместить костёр",func():player.survival.begin_placement())
 button(player._inv_inspector_box,"recipe_link","Открыть рецепт раскола",func():select_recipe("split_"+str(player.inventory_slots[player._selected_slot_index].get("species","birch")));tabs.current_tab=1)
 button(player._inv_inspector_box,"fuel_link","Добавить в костёр…",func():focus_fire();fuel_select.select(fuel_select.get_item_index(player._selected_slot_index));refresh_actions())
 belt_group=column(player._inv_inspector_box,6)
 label(belt_group,"БЫСТРЫЙ ДОСТУП  /  ПОЯС",11).add_theme_color_override("font_color",Journal.MUTED)
 var beltrow:=row(belt_group,6);belt_select=picker(beltrow)
 for i in 3:belt_select.add_item("Ячейка %d" % (i+6),i)
 button(beltrow,"belt","Назначить",func():player.assign_belt_item(player._selected_slot_index,belt_select.get_selected_id());refresh_actions())
 button(beltrow,"unbelt","Снять",func():player.clear_belt_item(belt_select.get_selected_id());refresh_actions())
 belt_info=label(belt_group,"",12);belt_info.hide()
 drop_group=row(inspector_column,6)
 var drops:=drop_group
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
 button(detail_column,"kit","Собрать набор",func():player.survival.make_recipe(selected_recipe))
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
 var cooking:=sheet(controls);heading(cooking,"04  /  Грибы и древесный чай",18)
 cook_select=picker(cooking)
 for r in Catalog.FIRE_RECIPES:cook_select.add_item(r.title)
 cook_select.item_selected.connect(func(_i):refresh_actions())
 var line:=row(cooking);cook_amount=SpinBox.new();cook_amount.min_value=1;cook_amount.max_value=10;cook_amount.step=1;cook_amount.value=1;cook_amount.custom_minimum_size=Vector2(80,44);line.add_child(cook_amount)
 cook_amount.value_changed.connect(func(_v):refresh_actions())
 button(line,"cook","Приготовить",func():player.survival.foraging.begin_cook(Catalog.FIRE_RECIPES[cook_select.selected].id,int(cook_amount.value));refresh_actions())
 cook_info=label(cooking,"",13)
 label(cooking,"Отмена, уход или погасший огонь сохраняют ингредиенты. Ядовитые грибы не обезвреживаются готовкой.",13)


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

func _queue_resize() -> void:
 if _resize_pending:return
 _resize_pending=true
 call_deferred("_settle_resize")
func _settle_resize() -> void:
 _resize_pending=false;resize()
func resize() -> void:
 if not is_instance_valid(player) or not is_inside_tree() or not player.is_inside_tree() or get_viewport()==null:return
 var size:=get_viewport().get_visible_rect().size
 var physical:=Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name()!="headless" else size
 ui_scale=clampf(size.x/maxf(1,physical.x),0.5,2.0)
 var small:=physical.x<1500
 var dim:=size*Vector2(0.94 if small else 0.86,0.92 if small else 0.84)
 # Cache immutable authored sizes, not results from previous resize passes.
 for node in player._inv_root_panel.find_children("*","Control",true,false):
  if node is ItemRow or node is Card:continue
  if not node.has_meta("journal_min"):node.set_meta("journal_min",node.custom_minimum_size)
  if node!=inspector_image:node.custom_minimum_size=Vector2(node.get_meta("journal_min"))*ui_scale
  if node is Label or node is Button or node is TabContainer or node is LineEdit:
   if not node.has_meta("journal_font"):node.set_meta("journal_font",node.get_theme_font_size("font_size"))
   var target_font:=maxi(9,roundi(float(node.get_meta("journal_font"))*ui_scale))
   if node.get_theme_font_size("font_size")!=target_font:node.add_theme_font_size_override("font_size",target_font)
  if node is BoxContainer:
   if not node.has_meta("journal_gap"):node.set_meta("journal_gap",node.get_theme_constant("separation"))
   node.add_theme_constant_override("separation",roundi(float(node.get_meta("journal_gap"))*ui_scale))
  if node is Button and not node is Card:node.custom_minimum_size.y=44*ui_scale
 navigation.get_parent().custom_minimum_size.x=(144 if small else 164)*ui_scale
 inventory_left.custom_minimum_size.x=clampf(physical.x*0.26,340,460)*ui_scale
 inventory_left.size_flags_horizontal=Control.SIZE_FILL
 buttons["close"].custom_minimum_size.x=200*ui_scale
 # More detailed artwork on tall displays, without pushing 720p actions below the fold.
 var hero_height:=clampf(112+(physical.y-720)*0.36,112,242)
 inspector_image.custom_minimum_size=Vector2(hero_height*1.4,hero_height)*ui_scale
 for card in player._inv_slot_buttons+tool_rows:
  if card.get_meta("row_scale",-1.0)!=ui_scale:card.set_card_size(Vector2(0,60)*ui_scale,ui_scale);card.set_meta("row_scale",ui_scale)
 for card in recipe_cards.values():
  if card.get_meta("row_scale",-1.0)!=ui_scale:card.set_card_size(Vector2(55,95)*ui_scale,ui_scale,true);card.set_meta("row_scale",ui_scale)
 for b in quick_buttons:b.custom_minimum_size=Vector2(50,50)*ui_scale;b.add_theme_constant_override("icon_max_width",roundi(32*ui_scale))
 for b in category_buttons:b.add_theme_constant_override("icon_max_width",roundi(18*ui_scale))
 player._inv_root_panel.size=dim;player._inv_root_panel.position=(size-player._inv_root_panel.size)/2
func set_journal_visible(open:bool) -> void:
 if open:
  for hud in get_tree().get_nodes_in_group("gameplay_hud"):
   if not _hud_visibility.has(hud):_hud_visibility[hud]=hud.visible
   hud.hide()
 else:
  for hud in _hud_visibility:
   if is_instance_valid(hud):hud.visible=_hud_visibility[hud]
  _hud_visibility.clear()
func _process(delta:float) -> void:
 _tick-=delta
 if _tick<=0:
  _tick=0.1
  if is_instance_valid(player) and player._is_inventory_open:set_journal_visible(true);refresh_actions()
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
 selected_tool=-1
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
   card.hide();continue
  var kind:String=item.get("type","");var title:String=item.get("name","Предмет")
  var accepted:=category.selected!=6 and (search.text.is_empty() or title.to_lower().contains(search.text.to_lower()))
  if category.selected==1:accepted=accepted and kind in ["stone","flint","pyrite","brush","log"]
  elif category.selected==2:accepted=accepted and kind in ["firewood","brush"]
  elif category.selected==4:accepted=accepted and (kind in ["water","raw_water","ration","berries"] or Plants.is_food(kind))
  elif category.selected==5:accepted=accepted and kind in ["bandage","compress","antitoxin"]
  elif category.selected==3:accepted=accepted and kind=="camp_kit"
  card.visible=accepted
  if accepted:visible_count+=1
  var stamp:="×%d" % int(item.get("count",1))
  for i in player.belt_items.size():
   if player.belt_items[i]==item.get("id"):stamp+="  ·  [%d]" % (i+6)
  var short_title:=title.replace(" полено"," · бревно").replace("Поленце (","Поленья · ").replace(")","")
  card.present(Art.item_key(item),short_title,"%.2f кг" % _slot_weight(index),stamp,chosen)
 for i in tool_rows.size():
  var tool=tool_rows[i];var title:String=player.HOTBAR_CONFIG[i].name
  tool.visible=category.selected==6 and (search.text.is_empty() or title.to_lower().contains(search.text.to_lower()))
  if tool.visible:visible_count+=1
  tool.present(TOOL_KEYS[i],title,"Постоянный инструмент","ПОЯС",selected_tool==i)
 item_empty.visible=visible_count==0
 item_empty.text="Ничего не найдено.\nИзмените поиск или категорию." if search.text!="" or category.selected!=0 else "Рюкзак пуст.\n\nПодбирайте припасы в мире. Постоянные инструменты доступны на поясе."
 var used:=0
 for entry in player.inventory_slots:
  if entry!=null:used+=1
 list_summary.text=("%d / %d ячеек · найдено %d" % [used,player.MAX_SLOTS,visible_count]) if category.selected!=6 else "Пояс · инструменты не занимают рюкзак"
 for i in category_buttons.size():
  var nav:=category_buttons[i];var chosen:bool=category.selected==i
  nav.add_theme_color_override("font_color",Journal.GOLD if chosen else Journal.MUTED)
  if not nav.has_meta("category_chosen") or nav.get_meta("category_chosen")!=chosen:
   nav.set_meta("category_chosen",chosen)
   var flat:=Journal.box(Color(0.73,0.63,0.42,0.08) if chosen else Color(0,0,0,0),Journal.GOLD,0);flat.border_width_left=2 if chosen else 0;flat.content_margin_left=6;flat.content_margin_right=6;nav.add_theme_stylebox_override("normal",flat)
 player._inv_overweight_warning.visible=not player._inv_overweight_warning.text.is_empty()
 _refresh_quick_strip()
 var item:Dictionary={}
 if player._selected_slot_index>=0 and player._selected_slot_index<player.MAX_SLOTS and player.inventory_slots[player._selected_slot_index]!=null:item=player.inventory_slots[player._selected_slot_index]
 buttons["equip_tool"].visible=selected_tool>=0
 belt_group.visible=selected_tool<0 and item.get("type","") in ["camp_kit","firewood","brush"]
 drop_group.visible=selected_tool<0 and not item.is_empty()
 player._inv_empty_inspector_label.visible=item.is_empty() and selected_tool<0;player._inv_inspector_box.visible=not item.is_empty() or selected_tool>=0
 var detail_key:=str(selected_tool)+":"+str(player._selected_slot_index)+":"+str(item.get("id",""))
 if _detail_key!=detail_key:
  _detail_key=detail_key
  if is_instance_valid(_detail_tween):_detail_tween.kill()
  player._inv_inspector_box.modulate=Color(1,1,1,0.75);_detail_tween=create_tween();_detail_tween.tween_property(player._inv_inspector_box,"modulate",Color.WHITE,0.14)
 if selected_tool>=0:
  inspector_image.texture=Art.texture(TOOL_KEYS[selected_tool]);player._inv_details_title.text=player.HOTBAR_CONFIG[selected_tool].name
  player._inv_details_category.text="ПОСТОЯННЫЙ ИНСТРУМЕНТ · ПОЯС"
  player._inv_details_stats.text="Не занимает ячейку рюкзака. Износ не моделируется."
  if selected_tool==3 and is_instance_valid(player.survival):player._inv_details_stats.text="Спичек осталось: %d" % player.survival.matches
  player._inv_details_desc.text=TOOL_USE[selected_tool];application.text="Выбор меняет активный инструмент. Действие — после закрытия журнала."
  return
 if item.is_empty():return
 inspector_image.texture=Art.texture(Art.item_key(item));player._inv_details_title.text=item.get("name","")
 player._inv_details_category.text={"log":"ДРЕВЕСИНА / БРЕВНО","firewood":"ТОПЛИВО","brush":"ВЕТКИ / ТОПЛИВО","tinder":"РАСТОПКА","camp_kit":"РАЗМЕЩАЕМЫЙ НАБОР","water":"ПИТЬЕВАЯ ВОДА","raw_water":"ВОДА / НУЖНО КИПЯТИТЬ","ration":"ПИТАНИЕ","berries":"ПИТАНИЕ / СБОР","bandage":"МЕДИЦИНА","compress":"МЕДИЦИНА","antitoxin":"МЕДИЦИНА / ОТРАВЛЕНИЕ","wood_tea":"НАПИТОК / ВЫНОСЛИВОСТЬ"}.get(item.get("type",""),"ПРИРОДНЫЙ МАТЕРИАЛ")
 var count:=int(item.get("count",1));var weight:=float(item.get("unit_weight",0))
 player._inv_details_stats.text="%d шт.   /   %.2f кг за шт.   /   %.2f кг всего" % [count,weight,count*weight]
 if item.get("type")=="firewood" and is_instance_valid(player.survival):player._inv_details_stats.text+="\nГорение: %d мин за поленце" % int(player.survival.Fire.FUEL_SECONDS.get(item.get("species","birch"),1800)/60)
 elif item.get("type")=="brush":player._inv_details_stats.text+="\nГорение: 5 мин за единицу"
 player._inv_details_desc.text=item.get("description","");drop_amount.max_value=maxi(1,count)
 application.text="ПРИМЕНЕНИЕ\n"+{"log":"Расколите во вкладке «Крафт», чтобы получить три поленца.","firewood":"Топливо для костра. Можно закрепить на поясе.","brush":"Топливо и материал для крафта хвороста и набора костра.","camp_kit":"Разместите на подходящей земле в лесу.","stone":"Материал для каменного кольца костра.","flint":"Розжиг костра вместе с пиритом. Не расходуется.","pyrite":"Розжиг костра вместе с кремнем. Не расходуется.","water":"Восстанавливает воду на 35 пунктов.","raw_water":"Кипятите у горящего костра, чтобы получить безопасную воду.","ration":"1125 ккал на порцию.","berries":"300 ккал на порцию.","bandage":"Останавливает кровотечение.","compress":"Снимает травму ноги."}.get(item.get("type",""),item.get("description",""))
 var plant_id:=Plants.item_species(str(item.get("type","")))
 if plant_id!="" and is_instance_valid(player.survival):
  player._inv_details_category.text="ПОЛЕВОЙ СБОР / "+("ПРИГОТОВЛЕН" if str(item.type).begins_with("cooked_") else "СЫРОЙ")
  player._inv_details_desc.text=player.survival.vegetation.journal_text(plant_id)
  application.text="ПРИМЕНЕНИЕ\n"+("Приготовить древесный чай: 1 гриб + 0,5 л безопасной воды у огня." if plant_id=="stump_fan" else "Съесть или приготовить у огня. Свойства вида — во вкладке «Растения».")
 if is_instance_valid(player.survival) and player.survival.Items.calories_for(str(item.get("type","")))>0:application.text+="\nЭнергия: %.0f ккал/порция · %.0f ккал/кг. Порция съедается целиком; избыток не запасается." % [player.survival.Items.calories_for(str(item.type)),player.survival.Items.calories_for(str(item.type))/maxf(0.001,float(item.get("unit_weight",0)))]
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
  for id in data.costs:ingredients.append({"icon":id,"title":{"stone":"Камни","brush":"Ветки"}.get(id,id),"have":player.survival.Items.count(player.inventory_slots,id) if is_instance_valid(player.survival) else 0,"need":data.costs[id]})
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
 buttons["use_supply"].visible=type in Plants.SUPPLY_IDS and type!="stump_fan"
 buttons["cook_link"].visible=type in ["forest_fat","wood_fan","copper_false","pale_bell","stump_fan"];buttons["cook_link"].disabled=busy or not valid or (valid and s.nearby_fire().is_empty())
 var use_reason:=""
 if not valid:use_reason="Недоступно вне игрового мира."
 elif busy:use_reason="Завершите текущее действие."
 elif type=="water" and s.body.water>=100:use_reason="Запас воды уже полон."
 elif type!="wood_tea" and s.Items.calories_for(type)>0 and s.body.food>=100:use_reason="Запас калорий уже полон."
 elif type=="bandage" and not s.body.conditions.has("bleeding"):use_reason="Нет кровотечения."
 elif type=="compress" and not s.body.conditions.has("sprain"):use_reason="Нет травмы ноги."
 elif type=="antitoxin" and not s.body.conditions.has("poison"):use_reason="Нет отравления."
 buttons["use_supply"].disabled=use_reason!="";buttons["use_supply"].tooltip_text=use_reason
 buttons["equip_tool"].disabled=busy
 buttons["use_supply"].text={"water":"Выпить · 0,5 л","raw_water":"Кипятить у костра · 5 мин","ration":"Съесть рацион","berries":"Съесть ягоды","bandage":"Перевязать рану","compress":"Наложить компресс","antitoxin":"Принять от отравления","wood_tea":"Выпить чай · +25 выносливости"}.get(type,"Использовать")
 var plant_kind:=Plants.item_species(type)
 if plant_kind!="" and plant_kind!="stump_fan":buttons["use_supply"].text="Съесть ягоды" if Plants.species(plant_kind).family=="berry" else "Съесть гриб"
 if valid:_refresh_condition(s);_refresh_guide(s)
 # Assign final states once. No false→true visibility/disabled pulses across refreshes.
 buttons["drop_one"].disabled=busy;buttons["drop_all"].disabled=busy
 buttons["place"].visible=valid and type=="camp_kit";buttons["place"].disabled=busy or not valid or (valid and s.location!="forest")
 buttons["belt"].disabled=busy or type not in ["camp_kit","firewood","brush"]
 buttons["unbelt"].disabled=busy or player.belt_items[belt_select.get_selected_id()]==""
 var names:Array=[]
 for i in 3:
  var slot:int=player.belt_item_slot(i)
  var kind:String=player.inventory_slots[slot].get("type","") if slot>=0 else ""
  names.append({"camp_kit":"Костёр","firewood":"Поленце","brush":"Ветки"}.get(kind,"—"))
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
  status.text="Выберите предмет в списке."
  buttons["recipe_link"].visible=type=="log";buttons["recipe_link"].disabled=true
  buttons["fuel_link"].visible=type in ["firewood","brush"];buttons["fuel_link"].disabled=true
  _refresh_recipe();refresh_inventory();return
 var brush:int=s.Items.count(player.inventory_slots,"brush");var stones:int=s.Items.count(player.inventory_slots,"stone")

 buttons["kit"].disabled=busy or stones<6 or brush<4
 var f:Dictionary=s.find_fire(s.selected_fire)
 if f.is_empty() or not s._fire_in_reach(f):f=s.nearby_fire();s.selected_fire=f.get("id","")
 var cooking_recipe:Dictionary=s.foraging.cook_recipe(str(Catalog.FIRE_RECIPES[cook_select.selected].id),int(cook_amount.value))
 var cooking_ready:bool=not f.is_empty() and f.get("state")=="burning" and not cooking_recipe.is_empty()
 buttons["cook"].disabled=busy or not cooking_ready or not s.Items.transact(player,cooking_recipe.costs,cooking_recipe.outputs,-1,true)
 if Catalog.FIRE_RECIPES[cook_select.selected].id=="wood_tea" and not s.vegetation.inspected.has("stump_fan"):buttons["cook"].disabled=true
 cook_amount.editable=not busy;cook_select.disabled=busy
 var ingredients:PackedStringArray=[]
 for id in cooking_recipe.get("costs",{}):ingredients.append("%s ×%d"%[s.Items.item(id).name,int(cooking_recipe.costs[id])])
 cook_info.text=(" + ".join(ingredients)+" · %.0f игровых минут"%float(cooking_recipe.get("minutes",0))) if cooking_ready else "Нужен горящий костёр рядом и ингредиенты в рюкзаке."
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
 sleep_info.text="Отдых %.0f%% · тепло %.0f%% · здоровье %.0f%%\nВода %.0f%% → ~%.0f%% · калории %.0f → ~%.0f ккал\nСон: ~%.0f ккал/ч (при текущем тепле)\n%s" % [s.energy,s.warmth,s.health,s.body.water,maxf(0,s.body.water-hours*3.6),s.body.calories,maxf(0,s.body.calories-hours*s.body.burn_rate(true,false,false,false,0,s.warmth)),s.body.burn_rate(true,false,false,false,0,s.warmth),reason if reason!="" else "Прогноз приблизительный: тепло может измениться. Сон прервётся при опасном состоянии."]
 rest.text="Спать %d ч" % hours;rest.disabled=busy or reason!=""
 sleep_hours.editable=not busy
 status.text=s.message if s.message_time>0 else "Мир не на паузе. Tab / Esc закрывает рюкзак и отменяет действие."
 if "Dev Menu" in status.text:status.text="Мир не на паузе · Tab / Esc — закрыть журнал"
 if active:
  progress.max_value=float(s.job["duration"]);progress.value=float(s.job["elapsed"])
  status.text="%s · %.1f / %.1f с" % [{"split":"Раскол","ignite":"Розжиг","rest":"Сон","boil":"Кипячение","harvest":"Сбор","vegetation_cook":"Готовка"}.get(s.job["kind"],"Действие"),s.job["elapsed"],s.job["duration"]]

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
 condition_temperature=label(overview,"",18)
 condition_temperature.name="AirTemperature"
 condition_climate=label(overview,"",13)
 condition_climate.name="Climate"
 condition_calories=label(overview,"",14)
 for id in ["health","warmth","water","food","energy","stamina","wetness"]:
  var line:=row(overview,8);var text:=label(line,{"health":"Здоровье","warmth":"Тепло","water":"Вода","food":"Калории","energy":"Отдых","stamina":"Выносливость","wetness":"Промокание"}[id],14)
  var bar:=ProgressBar.new();bar.custom_minimum_size=Vector2(90,20);bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bar.show_percentage=false;line.add_child(bar);var value_text:=label(line,"100%",14);value_text.size_flags_horizontal=0;value_text.custom_minimum_size.x=55;value_text.autowrap_mode=TextServer.AUTOWRAP_OFF;value_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;condition_values[id]={"label":text,"bar":bar,"value":value_text}
 label(overview,"Здоровье — последствия. Выносливость возвращается после передышки; усталость требует сна. Лечение останавливает причину, а не мгновенно возвращает здоровье.",14)
 var details:=column(scroll(body_row),12);heading(details,"Травмы и восстановление",24);condition_info=label(details,"")
 label(details,"Безопасная вода и готовая еда используются из рюкзака. У стоянки есть ограниченные припасы и дождесборник; съедобные ягоды встречаются в лесу. Сырую воду кипятите у горящего костра.",14)
 supply_select=picker(details)
 button(details,"condition_use","Использовать выбранный припас",func():player.survival.request_use_supply(supply_select.get_selected_id());refresh_actions())
 label(details,"Сон — подойдите к кровати и нажмите E. Здесь меню сна не открывается.",13)
 label(details,"Восстановление здоровья: сон, тепло выше 45%, питание и вода, отсутствие кровотечения и переохлаждения. Травма ноги проходит за 4 игровых часа или быстрее во сне.",13)
func _refresh_condition(s:Node) -> void:
 condition_temperature.text="Температура воздуха: %.1f °C" % s.air_temperature()
 condition_climate.text="Сезон: %s, день %d из %d · сутки %d · ветер: %s" % [s.season_name(),s.season_day(),s.SeasonModel.SEASON_DAYS,int(s.clock/86400.0)+1,s.wind_description()]
 condition_calories.text="Запас энергии: %.0f / %.0f ккал\nРасход сейчас: %.0f ккал/игр. час" % [s.body.calories,s.body.MAX_CALORIES,s.body.calorie_rate]
 for id in condition_values:
  var value:float=s.body.get(id) if id in ["water","food","stamina"] else s.get(id)
  condition_values[id].bar.value=value
  condition_values[id].value.text=("%.0f ккал" % s.body.calories) if id=="food" else ("%.0f%%" % value)
  var danger:bool=value>70 if id=="wetness" else value<20
  condition_values[id].value.add_theme_color_override("font_color",Color("f0a78e") if danger else Color("eee5d3"))
 condition_info.text=("Причина гибели: "+s.body.death_reason+"\n" if s.health<=0 else "")+s.body.describe()+"\n\n"+s.thermal_description()
 _update_picker(supply_select,Plants.SUPPLY_IDS,"Нет еды, воды или медикаментов")
 buttons["condition_use"].disabled=s.health<=0 or not s.job.is_empty() or supply_select.item_count==0

func _build_guide() -> void:
 var guide:=page("Растения")
 label(guide,"ОСТРОВНОЙ ПОЛЕВОЙ СПРАВОЧНИК",12).add_theme_color_override("font_color",Journal.MUTED)
 label(guide,"Вымышленные игровые виды. Не руководство по съедобности настоящих растений и грибов. Памятка у стоянки раскрывает свойства без рискованной дегустации.",14)
 var entries:=column(scroll(guide),12)
 for id in Plants.SPECIES:
  var entry:=sheet(entries);var line:=row(entry,16);picture(line,id,64).custom_minimum_size.x=80
  var text:=column(line,4);var title:=heading(text,"",20);var details:=label(text,"",14)
  guide_entries[id]={"title":title,"details":details}
func _refresh_guide(s:Node) -> void:
 var signature:=str(s.vegetation.inspected)+str(s.vegetation.known)
 if signature==_guide_signature:return
 _guide_signature=signature
 for id in guide_entries:
  var found:bool=s.vegetation.inspected.has(id) or s.vegetation.known.has(id)
  var e:Dictionary=guide_entries[id];var d:Dictionary=Plants.species(id)
  e.title.text=d.name if found else "Неизученный вид"
  e.details.text=s.vegetation.journal_text(id) if found else "Осмотрите растение в лесу, чтобы зарисовать признаки."
