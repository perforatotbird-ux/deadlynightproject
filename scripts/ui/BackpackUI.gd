extends Node
# The backpack is the only crafting surface. No separate crafting modal/input state.
const Style = preload("res://scripts/ui/UITheme.gd")
var player: Node
var buttons: Dictionary = {}
var recipe: Label
var fire_info: Label
var status: Label
var progress: ProgressBar
var right_scroll: ScrollContainer
var rest: Button
var _tick:=0.0
var ui_scale:=1.0
func label(parent: Node, text: String, size: int=14) -> Label:
 var n:=Label.new();n.text=text;n.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;n.add_theme_font_size_override("font_size",size);parent.add_child(n);return n
func button(parent: Node, id: String, text: String, action: Callable) -> Button:
 var n:=Button.new();n.text=text;n.tooltip_text=text;n.clip_text=true;n.custom_minimum_size.y=44;n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;Style.style_button(n);n.pressed.connect(action);parent.add_child(n);buttons[id]=n;return n
func column(parent: Node) -> VBoxContainer:
 var n:=VBoxContainer.new();n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;n.add_theme_constant_override("separation",10);parent.add_child(n);return n
func scroll(parent: Node) -> ScrollContainer:
 var n:=ScrollContainer.new();n.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;n.size_flags_vertical=Control.SIZE_EXPAND_FILL;parent.add_child(n);return n
func build(p: Node) -> void:
 player=p
 p._inv_layer=CanvasLayer.new();p._inv_layer.name="InventoryLayer";p._inv_layer.layer=110;p._inv_layer.hide();p.add_child(p._inv_layer)
 var shade:=ColorRect.new();shade.color=Color(0.02,0.03,0.03,0.88);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);p._inv_layer.add_child(shade)
 p._inv_root_panel=PanelContainer.new();p._inv_root_panel.name="InventoryPanel";p._inv_root_panel.add_theme_stylebox_override("panel",Style.create_panel_stylebox(Style.COLOR_BG_DARK));p._inv_layer.add_child(p._inv_root_panel)
 var layout:=column(p._inv_root_panel)
 var head:=HBoxContainer.new();layout.add_child(head);label(head,"РЮКЗАК",22).add_theme_color_override("font_color",Style.COLOR_ACCENT_GOLD)
 button(head,"close","Закрыть · Tab / Esc",func():player._toggle_inventory())
 p._inv_weight_label=label(layout,"");p._inv_weight_bar=ProgressBar.new();p._inv_weight_bar.max_value=p.max_backpack_kg;p._inv_weight_bar.show_percentage=false;p._inv_weight_bar.custom_minimum_size.y=6;layout.add_child(p._inv_weight_bar)
 p._inv_overweight_warning=label(layout,"")
 var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",24);layout.add_child(body)
 var left:=column(scroll(body));left.size_flags_stretch_ratio=1
 var grid:=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);left.add_child(grid)
 for i in p.MAX_SLOTS:
  var b:=Button.new();b.custom_minimum_size=Vector2(80,68);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.clip_text=true;b.pressed.connect(p._on_slot_clicked.bind(i));grid.add_child(b);p._inv_slot_buttons.append(b)
 left.add_child(HSeparator.new());label(left,"СОЗДАНИЕ",16).add_theme_color_override("font_color",Style.COLOR_ACCENT_GOLD)
 recipe=label(left,"");button(left,"kit","Создать набор костра",func():player.survival.make_kit())
 label(left,"Выберите предмет в сетке для действий.\nМир продолжает жить, пока открыт рюкзак.")
 right_scroll=scroll(body);var right:=column(right_scroll)
 p._inv_empty_inspector_label=label(right,"Выберите предмет в рюкзаке",18)
 p._inv_inspector_box=column(right)
 p._inv_details_title=label(p._inv_inspector_box,"",18);p._inv_details_category=label(p._inv_inspector_box,"");p._inv_details_stats=label(p._inv_inspector_box,"");p._inv_details_desc=label(p._inv_inspector_box,"")
 button(p._inv_inspector_box,"split","Расколоть → 3 поленца · 10 с",func():player.survival.begin_split(player._selected_slot_index))
 button(p._inv_inspector_box,"place","Разместить костёр",func():player.survival.begin_placement())
 button(p._inv_inspector_box,"fuel","Добавить в костёр · 1 шт.",func():player.survival.add_fuel(player.survival.selected_fire,player._selected_slot_index))
 p._inv_btn_drop_one=button(p._inv_inspector_box,"drop_one","Выбросить 1 шт.",func():player.drop_selected_item(false))
 p._inv_btn_drop_all=button(p._inv_inspector_box,"drop_all","Выбросить весь стак",func():player.drop_selected_item(true))
 right.add_child(HSeparator.new());fire_info=label(right,"")
 button(right,"tinder","Добавить растопку · 1 хворост",func():player.survival.add_tinder(player.survival.selected_fire))
 button(right,"match","Спичка",func():player.survival.begin_ignition(player.survival.selected_fire,"match"))
 button(right,"spark","Кремень + пирит",func():player.survival.begin_ignition(player.survival.selected_fire,"spark"))
 rest=button(right,"rest","Отдохнуть 1 игровой час",func():player.survival.begin_rest())
 layout.add_child(HSeparator.new());status=label(layout,"",14);progress=ProgressBar.new();progress.show_percentage=false;progress.custom_minimum_size.y=12;layout.add_child(progress)
 button(layout,"cancel","Прервать действие",func():player.survival.cancel_job();refresh_actions())
 get_viewport().size_changed.connect(resize);resize();refresh_actions()
func resize() -> void:
 if not is_instance_valid(player):return
 var size:=get_viewport().get_visible_rect().size
 var physical:=Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name()!="headless" else size
 ui_scale=maxf(1.0,size.x/maxf(1,physical.x))
 var dim:=Vector2(minf(1000*ui_scale,size.x-32*ui_scale),minf(680*ui_scale,size.y-32*ui_scale))
 for n in player._inv_root_panel.find_children("*","Control",true,false):
  if n is Label or n is Button:
   if not n.has_meta("base_font"):n.set_meta("base_font",n.get_theme_font_size("font_size"))
   n.add_theme_font_size_override("font_size",roundi(float(n.get_meta("base_font"))*ui_scale))
  if n is Button:n.custom_minimum_size.y=44*ui_scale
 for b in player._inv_slot_buttons:b.custom_minimum_size=Vector2(80,68)*ui_scale
 player._inv_root_panel.size=dim;player._inv_root_panel.position=(size-dim)/2
func _process(delta: float) -> void:
 _tick-=delta
 if _tick<=0:
  _tick=0.1
  if player._is_inventory_open:refresh_actions()
func focus_rest() -> void:
 right_scroll.ensure_control_visible(rest)
func focus_fire() -> void:
 right_scroll.ensure_control_visible(fire_info)
func show_selection() -> void:
 right_scroll.scroll_vertical=0
func refresh_actions() -> void:
 if not is_instance_valid(player):return
 var s=player.survival
 var valid:=is_instance_valid(s)
 var item:Dictionary={}
 if player._selected_slot_index>=0 and player._selected_slot_index<player.inventory_slots.size() and player.inventory_slots[player._selected_slot_index]!=null:item=player.inventory_slots[player._selected_slot_index]
 var type:String=item.get("type","")
 var busy:bool=valid and (not s.job.is_empty() or s.health<=0)
 for id in buttons:
  if id!="close":buttons[id].disabled=busy or not valid
 # Dropping during a timed transaction can change its source slot. Lock it.
 buttons["drop_one"].disabled=busy;buttons["drop_all"].disabled=busy
 buttons["split"].visible=valid and type=="log"
 buttons["place"].visible=valid and type=="camp_kit"
 buttons["fuel"].visible=valid and type in ["brush","firewood"]
 for id in ["tinder","match","spark","rest"]:buttons[id].visible=false
 fire_info.visible=valid;recipe.visible=valid;buttons["kit"].visible=valid
 progress.visible=false;buttons["cancel"].visible=false
 if not valid:status.text="Выберите предмет, чтобы посмотреть описание и доступные действия.";return
 var stones:int=s.Items.count(player.inventory_slots,"stone");var brush:int=s.Items.count(player.inventory_slots,"brush")
 recipe.text="Костёр\nКамни: %d / 6 · Хворост: %d / 4" % [stones,brush]
 buttons["kit"].disabled=busy or stones<6 or brush<4
 buttons["place"].disabled=busy or s.location!="forest"
 var f:Dictionary=s.find_fire(s.selected_fire)
 if f.is_empty() or not s._fire_in_reach(f):
  f=s.nearby_fire();s.selected_fire=f.get("id","")
 var ready:=not f.is_empty()
 fire_info.text="Подойдите к костру: здесь появятся действия розжига."
 buttons["fuel"].disabled=busy or not ready
 if ready:
  fire_info.text="КОСТЁР · %s\nТопливо: %.0f мин · Растопка: %d" % [{"unlit":"не разожжён","burning":"горит","embers":"угли","cold":"остыл"}.get(f["state"],""),float(f["fuel"])/60,f["tinder"]]
  for id in ["tinder","match","spark"]:buttons[id].visible=true
  buttons["tinder"].disabled=busy or brush<1
  var ignite:bool=not busy and f["state"]!="burning" and f["fuel"]>0 and f["tinder"]>0
  buttons["match"].text="Спичка · %.0f%% · осталось %d" % [s.ignition_chance("match")*100,s.matches]
  buttons["spark"].text="Кремень + пирит · %.0f%%" % (s.ignition_chance("spark")*100)
  buttons["match"].disabled=not ignite or s.matches<1
  buttons["spark"].disabled=not ignite or s.Items.count(player.inventory_slots,"flint")<1 or s.Items.count(player.inventory_slots,"pyrite")<1
 rest.visible=s.covered();rest.disabled=busy or not s.safe_shelter() or s.warmth<20
 status.text=s.message if s.message_time>0 else "Раскол: 10 реальных секунд. Закрытие рюкзака отменяет действие."
 if not s.job.is_empty():
  progress.visible=true;buttons["cancel"].visible=true;buttons["cancel"].disabled=false
  progress.max_value=float(s.job["duration"]);progress.value=float(s.job["elapsed"])
  status.text="%s · %.1f / %.1f с" % [{"split":"Раскалываете бревно","ignite":"Разжигаете костёр","rest":"Отдыхаете"}.get(s.job["kind"],"Действие"),s.job["elapsed"],s.job["duration"]]
