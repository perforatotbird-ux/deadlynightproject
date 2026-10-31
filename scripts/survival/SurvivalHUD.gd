extends CanvasLayer
# No persistent top strip. Only essential, background-free contextual notices.
var session: Node
var context_label: Label
func _ready() -> void:
 add_to_group("gameplay_hud")
 layer=95
 context_label=Label.new();context_label.name="SurvivalContextNotice"
 context_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 context_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 context_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 context_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.9))
 context_label.add_theme_constant_override("shadow_offset_x",1)
 context_label.add_theme_constant_override("shadow_offset_y",1)
 add_child(context_label)
 get_viewport().size_changed.connect(_resize);_resize();refresh()
func _resize() -> void:
 var size:=get_viewport().get_visible_rect().size
 var physical:=Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name()!="headless" else size
 var scale:=maxf(1.0,size.x/maxf(physical.x,1))
 var width:=minf(800*scale,size.x-32*scale)
 context_label.position=Vector2((size.x-width)*0.5,size.y*0.65)
 context_label.size=Vector2(width,0)
 context_label.add_theme_font_size_override("font_size",roundi(16*scale))
func refresh() -> void:
 if not is_instance_valid(session) or not is_instance_valid(session.player) or context_label==null:return
 var s=session
 if s.player._hotbar_status_labels.size()>3:s.player._hotbar_status_labels[3].text="%d шт." % s.matches
 context_label.text=""
 if s.health<=0:context_label.text="ВЫ ПОГИБЛИ · "+s.body.death_reason+"\nEsc — меню загрузки · F8 — Dev Menu"
 elif s.placing:context_label.text=s.placement.get("reason","Выберите площадку")
 context_label.add_theme_color_override("font_color",Color("f0a78e") if s.health<=0 else Color("eee5d3"))
 context_label.visible=not context_label.text.is_empty() and s.player._hud_enabled and not s.player._is_inventory_open
 if is_instance_valid(s.player._backpack_ui):s.player._backpack_ui.refresh_actions()
