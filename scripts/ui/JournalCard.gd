extends Button
const Art=preload("res://scripts/ui/JournalArt.gd")
const Journal=preload("res://scripts/ui/JournalTheme.gd")
var picture:TextureRect
var caption:Label
var detail:Label
var badge:Label
var selected:=false
var _signature:=""
func _init() -> void:
 text="";custom_minimum_size=Vector2(76,150);size_flags_horizontal=Control.SIZE_EXPAND_FILL;focus_mode=Control.FOCUS_ALL
 var v:=VBoxContainer.new();v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);v.offset_left=7;v.offset_right=-7;v.offset_top=5;v.offset_bottom=-6;v.add_theme_constant_override("separation",2);add_child(v)
 badge=Label.new();badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;badge.add_theme_font_size_override("font_size",12);v.add_child(badge)
 picture=TextureRect.new();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.size_flags_vertical=Control.SIZE_EXPAND_FILL;picture.custom_minimum_size.y=62;v.add_child(picture)
 caption=Label.new();caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.add_theme_font_size_override("font_size",14);caption.custom_minimum_size.y=30;v.add_child(caption)
 detail=Label.new();detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;detail.add_theme_font_size_override("font_size",12);detail.add_theme_color_override("font_color",Journal.MUTED);v.add_child(detail)
 for child in [v,badge,picture,caption,detail]:child.mouse_filter=Control.MOUSE_FILTER_IGNORE
func present(key: String, title: String, info: String, stamp: String, chosen: bool=false, available: bool=true) -> void:
 var signature:=str([key,title,info,stamp,chosen,available])
 if signature==_signature:return
 _signature=signature;selected=chosen;picture.texture=Art.texture(key);caption.text=title;detail.text=info;badge.text=stamp
 badge.add_theme_color_override("font_color",Journal.GOLD if available else Journal.RED)
 tooltip_text=title+"\n"+info+"\n"+stamp
 add_theme_stylebox_override("normal",Journal.box(Color("2a352b") if chosen else Color(0.065,0.095,0.08,0.84),Journal.GOLD if chosen else Color("4b5549"),2 if chosen else 1))
 add_theme_stylebox_override("hover",Journal.box(Color("2d3a2e"),Journal.GOLD))
 add_theme_stylebox_override("pressed",Journal.box(Color("384533"),Journal.GOLD,2))
