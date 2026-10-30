extends RefCounted
const INK:=Color("121a18")
const PAPER:=Color("eee5d3")
const MUTED:=Color("b9b8a9")
const GOLD:=Color("dabb7e")
const LINE:=Color("596257")
const GREEN:=Color("a9c8ad")
const RED:=Color("f0a78e")
static func box(color: Color=Color("18211e"),border: Color=Color("475148"),width: int=1) -> StyleBoxFlat:
 var b:=StyleBoxFlat.new();b.bg_color=color;b.border_color=border;b.set_border_width_all(width);b.set_corner_radius_all(2)
 b.content_margin_left=12;b.content_margin_right=12;b.content_margin_top=8;b.content_margin_bottom=8
 return b
static func theme() -> Theme:
 var t:=Theme.new();t.default_font_size=14
 var f:=SystemFont.new();f.font_names=PackedStringArray(["Arial","Noto Sans","DejaVu Sans"]);t.default_font=f
 for kind in ["Label","Button","OptionButton","CheckButton","LineEdit","SpinBox"]:
  t.set_color("font_color",kind,PAPER);t.set_color("font_disabled_color",kind,MUTED)
 for kind in ["Button","OptionButton"]:
  t.set_stylebox("normal",kind,box());t.set_stylebox("hover",kind,box(Color("29372e"),GOLD))
  t.set_stylebox("pressed",kind,box(Color("354233"),GOLD,2));t.set_stylebox("disabled",kind,box(Color("17201b"),Color("39433b")))
  var focus:=box(Color(0,0,0,0),GOLD,2);t.set_stylebox("focus",kind,focus)
  t.set_color("font_hover_color",kind,PAPER);t.set_color("font_pressed_color",kind,PAPER)
 t.set_stylebox("panel","TabContainer",StyleBoxEmpty.new())
 for state in ["tab_selected","tab_unselected","tab_hovered","tab_focus"]:
  var b:=box(Color("29372e") if state=="tab_selected" else Color("121a18"),GOLD if state=="tab_selected" else LINE)
  b.content_margin_left=20;b.content_margin_right=20;b.content_margin_top=10;b.content_margin_bottom=10
  t.set_stylebox(state,"TabContainer",b)
 t.set_color("font_selected_color","TabContainer",PAPER);t.set_color("font_unselected_color","TabContainer",MUTED)
 t.set_stylebox("normal","LineEdit",box());t.set_stylebox("focus","LineEdit",box(INK,GOLD))
 var track:=box(Color("26332b"),Color("26332b"),0);var fill:=box(GOLD,GOLD,0)
 for bar in [track,fill]:bar.content_margin_left=0;bar.content_margin_right=0;bar.content_margin_top=0;bar.content_margin_bottom=0
 t.set_stylebox("background","ProgressBar",track);t.set_stylebox("fill","ProgressBar",fill)
 var slider:=box(LINE,LINE,0);slider.content_margin_top=2;slider.content_margin_bottom=2;slider.content_margin_left=0;slider.content_margin_right=0
 var selected_track:=slider.duplicate();selected_track.bg_color=GOLD
 t.set_stylebox("slider","HSlider",slider);t.set_stylebox("grabber_area","HSlider",selected_track);t.set_stylebox("grabber_area_highlight","HSlider",selected_track)
 return t
static func title_font() -> Font:
 var font:=SystemFont.new();font.font_names=PackedStringArray(["Georgia","Noto Serif","DejaVu Serif"]);return font
static func action(button: Button) -> void:
 button.custom_minimum_size.y=44;button.clip_text=true;button.focus_mode=Control.FOCUS_ALL
 button.mouse_filter=Control.MOUSE_FILTER_STOP
