extends Button
## Persistent presentation of an authoritative slot; never owns inventory data.
const Art=preload("res://scripts/ui/JournalArt.gd")
const Journal=preload("res://scripts/ui/JournalTheme.gd")
var picture:TextureRect
var caption:Label
var detail:Label
var badge:Label
var selected:=false
var _signature:=""
var _line:HBoxContainer
var _copy:VBoxContainer
var _tween:Tween
func _init() -> void:
 text="";custom_minimum_size=Vector2(0,60);size_flags_horizontal=Control.SIZE_EXPAND_FILL;focus_mode=Control.FOCUS_ALL
 _line=HBoxContainer.new();_line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(_line)
 picture=TextureRect.new();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;_line.add_child(picture)
 _copy=VBoxContainer.new();_copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_copy.size_flags_vertical=Control.SIZE_SHRINK_CENTER;_line.add_child(_copy)
 caption=Label.new();caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;_copy.add_child(caption)
 detail=Label.new();detail.add_theme_color_override("font_color",Journal.MUTED);_copy.add_child(detail)
 badge=Label.new();badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;badge.size_flags_vertical=Control.SIZE_SHRINK_CENTER;badge.add_theme_color_override("font_color",Journal.GOLD);_line.add_child(badge)
 for child in [_line,_copy,picture,caption,detail,badge]:child.mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_card_size(Vector2(0,60))
func present(key:String,title:String,info:String,stamp:String,chosen:bool=false,_available:bool=true) -> void:
 var signature:=str([key,title,info,stamp,chosen])
 if signature==_signature and (key=="" or picture.texture!=null):return
 var changed:=selected!=chosen
 _signature=signature;selected=chosen;picture.texture=Art.texture(key);caption.text=title;detail.text=info;badge.text=stamp
 tooltip_text=title+"\n"+info+"\n"+stamp
 var normal:=Journal.box(Color("28332f") if chosen else Color(0.055,0.085,0.078,0.78),Journal.GOLD if chosen else Color(0,0,0,0),0)
 normal.border_width_left=2 if chosen else 0;add_theme_stylebox_override("normal",normal)
 add_theme_stylebox_override("hover",Journal.box(Color("25332f"),Color(0,0,0,0),0))
 add_theme_stylebox_override("pressed",Journal.box(Color("344039"),Journal.GOLD,1))
 if changed and is_inside_tree():
  if is_instance_valid(_tween):_tween.kill()
  modulate=Color(0.84,0.86,0.84);_tween=create_tween();_tween.tween_property(self,"modulate",Color.WHITE,0.12)
func set_card_size(target:Vector2,scale_factor:float=1.0,_recipe:bool=false) -> void:
 custom_minimum_size=target
 _line.offset_left=10*scale_factor;_line.offset_right=-10*scale_factor;_line.offset_top=6*scale_factor;_line.offset_bottom=-6*scale_factor
 _line.add_theme_constant_override("separation",10*scale_factor);_copy.add_theme_constant_override("separation",2*scale_factor)
 picture.custom_minimum_size=Vector2(44,44)*scale_factor
 caption.add_theme_font_size_override("font_size",roundi(16*scale_factor));detail.add_theme_font_size_override("font_size",roundi(14*scale_factor));badge.add_theme_font_size_override("font_size",roundi(14*scale_factor))
