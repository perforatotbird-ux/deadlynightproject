extends CanvasLayer
const Style = preload("res://scripts/ui/UITheme.gd")
var session: Node
var modal: Control
var panel: PanelContainer
var scroll: ScrollContainer
var hud_panel: PanelContainer
var hud: Label
var summary: Label
var fire_info: Label
var body_info: Label
var hint: Label
var progress: ProgressBar
var action_text: Label
var log_select: OptionButton
var fuel_select: OptionButton
var buttons: Dictionary = {}
var _inventory_signature := ""
func _ready() -> void:
 layer=95
 hud_panel=PanelContainer.new();hud_panel.position=Vector2(230,10);hud_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hud_panel.add_theme_stylebox_override("panel",Style.create_panel_stylebox(Color(0.035,0.055,0.05,0.88)));add_child(hud_panel)
 hud=Label.new();hud.add_theme_font_size_override("font_size",14);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hud_panel.add_child(hud)
 modal=Control.new();modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(modal)
 var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,0.72);modal.add_child(shade)
 panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",Style.create_panel_stylebox(Style.COLOR_BG_DARK));modal.add_child(panel)
 var layout:=VBoxContainer.new();layout.add_theme_constant_override("separation",12);panel.add_child(layout)
 var title:=Label.new();title.text="СТОЯНКА · ОГОНЬ · ВЫЖИВАНИЕ";title.add_theme_font_size_override("font_size",22);title.add_theme_color_override("font_color",Style.COLOR_ACCENT_GOLD);layout.add_child(title)
 summary=_label(layout,16)
 scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;layout.add_child(scroll)
 var content:=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",10);scroll.add_child(content)
 _heading(content,"01 / ПОДГОТОВКА")
 _label(content,14).text="Соберите хворост и камни на земле [E]. Обычные камни — для очага; кремень + пирит — для искры."
 _button(content,"kit","Собрать набор: 6 камней + 4 хвороста",func():session.make_kit())
 _button(content,"place","Разместить набор на земле",func():session.begin_placement())
 log_select=OptionButton.new();log_select.custom_minimum_size.y=40;content.add_child(log_select)
 _button(content,"split","Расколоть бревно → 3 поленца · 10 реальных секунд",func():session.begin_split(log_select.get_selected_id()))
 _heading(content,"02 / КОСТЁР РЯДОМ")
 fire_info=_label(content,15)
 fuel_select=OptionButton.new();fuel_select.custom_minimum_size.y=40;content.add_child(fuel_select)
 _button(content,"fuel","Добавить выбранное топливо",func():session.add_fuel(session.selected_fire,fuel_select.get_selected_id()))
 _button(content,"tinder","Добавить растопку: 1 хворост",func():session.add_tinder(session.selected_fire))
 _button(content,"match","Разжечь спичкой",func():session.begin_ignition(session.selected_fire,"match"))
 _button(content,"spark","Высечь искру: кремень + пирит",func():session.begin_ignition(session.selected_fire,"spark"))
 _heading(content,"03 / НОЧЛЕГ")
 body_info=_label(content,15)
 _button(content,"rest","Отдохнуть 1 игровой час · в закрытой стоянке",func():session.begin_rest())
 _label(content,14).text="Дождь мочит одежду и ускоряет расход топлива. Огонь согревает и сушит. Крыша защищает от дождя; закрытая дверь сохраняет тепло. Монстров в этом этапе ещё нет."
 layout.add_child(HSeparator.new())
 action_text=_label(layout,15);progress=ProgressBar.new();progress.custom_minimum_size.y=16;progress.show_percentage=false;layout.add_child(progress)
 hint=_label(layout,14);hint.add_theme_color_override("font_color",Style.COLOR_ACCENT_GOLD)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);layout.add_child(row)
 var cancel:=Button.new();cancel.text="Прервать действие";Style.style_button(cancel);cancel.custom_minimum_size.y=44;cancel.pressed.connect(func():session.cancel_job();refresh());row.add_child(cancel)
 var close:=Button.new();close.text="Вернуться в мир [B / Esc]";close.size_flags_horizontal=Control.SIZE_EXPAND_FILL;Style.style_button(close,true);close.custom_minimum_size.y=44;close.pressed.connect(session.close_panel);row.add_child(close)
 get_viewport().size_changed.connect(_resize);_resize();modal.hide();refresh()
func _resize() -> void:
 var size:=get_viewport().get_visible_rect().size
 var physical:=Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name()!="headless" else size
 # Canvas stretch must not reduce readable 16px controls to tiny 10px text.
 var scale:=maxf(1.0,size.x/maxf(physical.x,1))
 var dim:=Vector2(minf(790*scale,size.x-32*scale),minf(650*scale,size.y-32*scale))
 for n in modal.find_children("*","Control",true,false):
  if n is Label or n is Button or n is OptionButton:
   if not n.has_meta("survival_font"):n.set_meta("survival_font",n.get_theme_font_size("font_size"))
   n.add_theme_font_size_override("font_size",roundi(float(n.get_meta("survival_font"))*scale))
  if n is Button:n.custom_minimum_size.y=44*scale
  if n is VBoxContainer or n is HBoxContainer:n.add_theme_constant_override("separation",roundi(12*scale))
 panel.size=dim;panel.position=(size-dim)*0.5
 hud.add_theme_font_size_override("font_size",roundi(14*scale))
 hud_panel.position=Vector2(16*scale,50*scale) if physical.x<1050 else Vector2(230,10)
 hud_panel.size.x=size.x-32*scale if physical.x<1050 else minf(800,size.x-460)
func _label(parent: Node, size: int) -> Label:
 var label:=Label.new();label.add_theme_font_size_override("font_size",size);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(label);return label
func _heading(parent: Node, text: String) -> void:
 var label:=_label(parent,16);label.text=text;label.add_theme_color_override("font_color",Style.COLOR_ACCENT_GOLD)
func _button(parent: Node, id: String, text: String, fn: Callable) -> void:
 var b:=Button.new();b.text=text;b.custom_minimum_size.y=44;Style.style_button(b);b.pressed.connect(fn);parent.add_child(b);buttons[id]=b
func open(page: String) -> void:
 modal.show();refresh();call_deferred("_focus_section",page)
func _focus_section(page: String) -> void:
 if page=="rest":
  scroll.scroll_vertical=maxi(0,roundi(body_info.position.y)-36)
  if not buttons["rest"].disabled:buttons["rest"].grab_focus()
 elif session.selected_fire!="":
  scroll.scroll_vertical=maxi(0,roundi(fire_info.position.y)-36)
  if not buttons["match"].disabled:buttons["match"].grab_focus()
 else:
  scroll.scroll_vertical=0
  if not buttons["kit"].disabled:buttons["kit"].grab_focus()
func close() -> void:modal.hide()
func is_open() -> bool:return modal!=null and modal.visible
func refresh() -> void:
 if not is_instance_valid(session.player) or hud==null:return
 var s=session;var slots:Array=s.player.inventory_slots
 if s.player._hotbar_status_labels.size()>3:s.player._hotbar_status_labels[3].text="%d шт." % s.matches
 var h:=int(s.hour());var m:=int(s.hour()*60)%60
 var cold:String="опасно холодно" if s.warmth<20 else ("зябко" if s.warmth<50 else "тепло")
 var wet:String="мокро" if s.wetness>50 else ("сыро" if s.wetness>10 else "сухо")
 var roof:String="закрытая стоянка" if s.safe_shelter() else ("под крышей" if s.covered() else "на улице")
 hud.text="День %d · %02d:%02d · %s · %.0f°C · %s\n%s / %s · силы %.0f%% · здоровье %.0f%% · спички %d · [B] стоянка" % [int(s.clock/86400)+1,h,m,"дождь" if s.weather=="rain" else "ясно",s.air_temperature(),roof,cold,wet,s.energy,s.health,s.matches]
 hud.visible=s.player._hud_enabled and s.player._is_active and not is_open()
 hud_panel.visible=hud.visible
 var fire:Dictionary=s.nearby_fire()
 if not fire.is_empty():hud.text+="\nКостёр: %.0f игровых мин топлива · [E] управление" % (float(fire["fuel"])/60)
 if s.placing:hud.text+="\n"+s.placement.get("reason","Выберите площадку")
 if not is_open():return
 summary.text="Хворост %d · Камни %d · Кремень %d · Пирит %d · Спички %d" % [s.Items.count(slots,"brush"),s.Items.count(slots,"stone"),s.Items.count(slots,"flint"),s.Items.count(slots,"pyrite"),s.matches]
 var signature:=str(slots)
 if signature!=_inventory_signature:
  _inventory_signature=signature
  var old_log:=log_select.get_selected_id();var old_fuel:=fuel_select.get_selected_id()
  log_select.clear();fuel_select.clear()
  for i in slots.size():
   var item=slots[i]
   if item==null:continue
   var text:String="%s ×%d" % [item.get("name","Предмет"),item["count"]]
   if item.get("type")=="log":log_select.add_item(text,i)
   if item.get("type") in ["firewood","brush"]:fuel_select.add_item(text,i)
  if log_select.item_count==0:log_select.add_item("Нет брёвен в рюкзаке",-1)
  elif log_select.get_item_index(old_log)>=0:log_select.select(log_select.get_item_index(old_log))
  if fuel_select.item_count==0:fuel_select.add_item("Нет поленец или хвороста",-1)
  elif fuel_select.get_item_index(old_fuel)>=0:fuel_select.select(fuel_select.get_item_index(old_fuel))
 var busy:bool=not s.job.is_empty() or s.health<=0
 for b in buttons.values():b.disabled=busy or s.health<=0
 buttons["kit"].disabled=busy or s.Items.count(slots,"stone")<6 or s.Items.count(slots,"brush")<4
 buttons["place"].disabled=busy or s.location!="forest" or s.Items.count(slots,"camp_kit")<1
 buttons["split"].disabled=busy or s.Items.count(slots,"log")<1 or s.player.active_hotbar_slot!=0
 var f:Dictionary=s.find_fire(s.selected_fire)
 var ready:bool=not f.is_empty() and s._fire_in_reach(f)
 fire_info.text="Подойдите к костру и нажмите [E]." if not ready else "Состояние: %s · топливо %.0f мин%s · растопка %d" % [{"unlit":"не разожжён","burning":"горит","embers":"угли","cold":"остыл"}.get(f["state"],""),float(f["fuel"])/60," (в дождь расход ×1,5)" if s.weather=="rain" else "",int(f["tinder"])]
 for id in ["fuel","tinder","match","spark"]:buttons[id].disabled=busy or not ready
 buttons["fuel"].disabled=busy or not ready or (s.Items.count(slots,"firewood")+s.Items.count(slots,"brush")==0)
 buttons["tinder"].disabled=busy or not ready or s.Items.count(slots,"brush")==0
 buttons["match"].text="Спичка · шанс %.0f%% · 2 с · осталось %d" % [s.ignition_chance("match")*100,s.matches]
 buttons["spark"].text="Кремень + пирит · шанс %.0f%% · 5 с" % (s.ignition_chance("spark")*100)
 if ready:
  buttons["match"].disabled=busy or s.matches<1 or f["state"]=="burning" or f["fuel"]<=0 or f["tinder"]<=0
  buttons["spark"].disabled=busy or s.Items.count(slots,"flint")==0 or s.Items.count(slots,"pyrite")==0 or f["state"]=="burning" or f["fuel"]<=0 or f["tinder"]<=0
 buttons["rest"].disabled=busy or not s.safe_shelter() or s.warmth<20
 body_info.text="%s · %s · %s\nСилы %.0f%% · Здоровье %.0f%%. Мир и огонь продолжают жить во время отдыха." % [roof,cold,wet,s.energy,s.health]
 progress.visible=not s.job.is_empty()
 if not s.job.is_empty():
  action_text.text={"split":"Раскалываете бревно без анимации","ignite":"Пробуете разжечь огонь","rest":"Отдыхаете: время ускорено"}.get(s.job["kind"],"")
  action_text.text+=" · %.1f / %.1f с" % [float(s.job["elapsed"]),float(s.job["duration"])]
  progress.max_value=float(s.job["duration"]);progress.value=float(s.job["elapsed"])
 elif s.health<=0:action_text.text="Вы погибли. Закройте панель и загрузите сохранение через Esc."
 else:action_text.text="Мир не на паузе. Раскол: 10 реальных секунд; Esc отменяет действие."
 hint.text=s.message if s.message_time>0 else "Для паузы закройте панель и нажмите Esc."
