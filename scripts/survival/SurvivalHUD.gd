extends CanvasLayer
const Style = preload("res://scripts/ui/UITheme.gd")
var session: Node
var hud_panel: PanelContainer
var hud: Label
func _ready() -> void:
 add_to_group("gameplay_hud")
 layer=95
 hud_panel=PanelContainer.new();hud_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hud_panel.add_theme_stylebox_override("panel",Style.create_panel_stylebox(Color(0.035,0.055,0.05,0.88)));add_child(hud_panel)
 hud=Label.new();hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hud_panel.add_child(hud)
 get_viewport().size_changed.connect(_resize);_resize();refresh()
func _resize() -> void:
 var size:=get_viewport().get_visible_rect().size
 var physical:=Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name()!="headless" else size
 var scale:=maxf(1.0,size.x/maxf(physical.x,1))
 hud_panel.position=Vector2(16*scale,50*scale) if physical.x<1050 else Vector2(230,10)
 hud_panel.size.x=size.x-32*scale if physical.x<1050 else minf(800,size.x-460)
 hud.add_theme_font_size_override("font_size",roundi(14*scale))
func refresh() -> void:
 if not is_instance_valid(session.player) or hud==null:return
 var s=session;var slots:Array=s.player.inventory_slots
 if s.player._hotbar_status_labels.size()>3:s.player._hotbar_status_labels[3].text="%d шт." % s.matches
 var h:=int(s.hour());var m:=int(s.hour()*60)%60
 hud.text="День %d · %02d:%02d · %s · [Tab] состояние" % [int(s.clock/86400)+1,h,m,s.weather_description()]
 if s.dev_tainted:hud.text+=" · DEV"
 if s.health<=0:hud.text="ВЫ ПОГИБЛИ · "+s.body.death_reason+"\nEsc — меню загрузки · F8 — Dev Menu"
 hud.add_theme_color_override("font_color",Color("f0a78e") if s.health<=0 else Color("eee5d3"))
 hud.visible=s.player._hud_enabled and not s.player._is_inventory_open
 hud_panel.visible=hud.visible
 var fire:Dictionary=s.nearby_fire()
 if not fire.is_empty():hud.text+="\nКостёр: %.0f игровых мин топлива · [E] управление" % (float(fire["fuel"])/60)
 if s.placing:hud.text+="\n"+s.placement.get("reason","Выберите площадку")

 if is_instance_valid(s.player._backpack_ui):s.player._backpack_ui.refresh_actions()
