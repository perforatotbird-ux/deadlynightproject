extends CanvasLayer
# Compact lower-right health + danger HUD, never a persistent top strip.
const Alerts=preload("res://scripts/survival/SurvivalAlerts.gd")
const MAX_ALERTS:=12
var vitals:VBoxContainer
var health_bar:ProgressBar
var health_value:Label
var calorie_value:Label
var alert_labels:Array[Label]=[]
var active_alerts:Array=[]
var session: Node
var context_label: Label
func _ready() -> void:
 add_to_group("gameplay_hud")
 layer=95
 _build_vitals()
 context_label=Label.new();context_label.name="SurvivalContextNotice"
 context_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 context_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 context_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 context_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.9))
 context_label.add_theme_constant_override("shadow_offset_x",1)
 context_label.add_theme_constant_override("shadow_offset_y",1)
 add_child(context_label)
 get_viewport().size_changed.connect(_resize);_resize();refresh()
func _build_vitals()->void:
 vitals=VBoxContainer.new();vitals.name="PlayerVitals";vitals.mouse_filter=Control.MOUSE_FILTER_IGNORE;vitals.add_theme_constant_override("separation",6);add_child(vitals)
 health_value=Label.new();health_value.add_theme_font_size_override("font_size",14);health_value.add_theme_color_override("font_shadow_color",Color(0,0,0,.9));health_value.add_theme_constant_override("shadow_offset_y",1);vitals.add_child(health_value)
 health_bar=ProgressBar.new();health_bar.name="HealthBar";health_bar.show_percentage=false;health_bar.custom_minimum_size.y=8;health_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var bg:=StyleBoxFlat.new();bg.bg_color=Color(.04,.07,.06,.8);bg.corner_radius_top_left=3;bg.corner_radius_top_right=3;bg.corner_radius_bottom_left=3;bg.corner_radius_bottom_right=3;health_bar.add_theme_stylebox_override("background",bg)
 var fill:=bg.duplicate();fill.bg_color=Color("90bda3");health_bar.add_theme_stylebox_override("fill",fill);vitals.add_child(health_bar)
 calorie_value=Label.new();calorie_value.add_theme_font_size_override("font_size",14);vitals.add_child(calorie_value)
 for i in MAX_ALERTS:
  var label:=Label.new();label.name="Status%d"%i;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",14);label.add_theme_color_override("font_shadow_color",Color(0,0,0,.95));label.add_theme_constant_override("shadow_offset_x",1);label.add_theme_constant_override("shadow_offset_y",1);label.hide();vitals.add_child(label);alert_labels.append(label)
 vitals.resized.connect(_place_vitals)
 vitals.minimum_size_changed.connect(_place_vitals)
func _place_vitals()->void:
 if not is_instance_valid(vitals):return
 vitals.size.y=vitals.get_combined_minimum_size().y
 var size:=get_viewport().get_visible_rect().size
 vitals.position=Vector2(size.x-vitals.size.x-24,maxf(76,size.y-148-vitals.size.y))
func _resize() -> void:
 var size:=get_viewport().get_visible_rect().size
 var physical:=Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name()!="headless" else size
 var scale:=maxf(1.0,size.x/maxf(physical.x,1))
 var width:=minf(800*scale,size.x-32*scale)
 context_label.position=Vector2((size.x-width)*0.5,size.y*0.65)
 context_label.size=Vector2(width,0)
 context_label.add_theme_font_size_override("font_size",roundi(16*scale))
 vitals.size.x=minf(310*scale,size.x*.36)
 _place_vitals()
func refresh() -> void:
 if not is_instance_valid(session) or not is_instance_valid(session.player) or context_label==null:return
 var s=session
 if s.player._hotbar_status_labels.size()>3:s.player._hotbar_status_labels[3].text="%d шт." % s.matches
 context_label.text=""
 if s.health<=0:context_label.text="ВЫ ПОГИБЛИ · "+s.body.death_reason+"\nEsc — меню загрузки · F8 — Dev Menu"
 elif s.placing:context_label.text=s.placement.get("reason","Выберите площадку")
 elif s.is_background_job():
  var names:={"split":"Раскол брёвен","vegetation_cook":"Готовка","boil":"Кипячение"}
  context_label.text="%s · осталось %.1f с · рюкзак: посмотреть / отменить" % [names.get(s.job.kind,"Создание"),maxf(0,float(s.job.duration)-float(s.job.elapsed))]
 context_label.add_theme_color_override("font_color",Color("f0a78e") if s.health<=0 else Color("eee5d3"))
 context_label.visible=not context_label.text.is_empty() and s.player._hud_enabled and not s.player._is_inventory_open and not s.player._is_map_open
 _refresh_vitals(s)
 if is_instance_valid(s.player._backpack_ui):s.player._backpack_ui.refresh_actions()
func _refresh_vitals(s:Node)->void:
 vitals.visible=s.player._hud_enabled and not s.player._is_inventory_open and not s.player._is_map_open and s.player._is_active
 health_bar.value=clampf(s.health,0,100)
 health_value.text="ЗДОРОВЬЕ  %.0f / 100" % s.health
 calorie_value.text="КАЛОРИИ  %.0f / %.0f · −%.0f ккал/ч" % [s.body.calories,s.body.MAX_CALORIES,s.body.calorie_rate]
 var color:=Color("e98e7c") if s.health<=25 else Color("90bda3")
 health_value.add_theme_color_override("font_color",color)
 var fill:StyleBoxFlat=health_bar.get_theme_stylebox("fill");fill.bg_color=color
 active_alerts=Alerts.collect(s)
 for i in MAX_ALERTS:
  var label:Label=alert_labels[i];label.visible=i<active_alerts.size()
  if i>=active_alerts.size():continue
  var alert:Dictionary=active_alerts[i]
  label.text=("! " if int(alert.severity)==2 else "• ")+str(alert.text)
  label.add_theme_color_override("font_color",Color("f4a18b") if int(alert.severity)==2 else Color("e6c584"))
 _place_vitals()
