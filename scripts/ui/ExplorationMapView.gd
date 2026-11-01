extends Control
signal point_selected(point:Vector2)
signal marker_selected(id:int)
signal view_changed
var model:RefCounted
var session:Node
var zoom:=1.0
var pan:=Vector2.ZERO
var mark_mode:=false
var dragging:=false
var drag_distance:=0.0
var selected_id:=-1
var _label_rects:Array[Rect2]=[]
var _placed_label_rects:Array[Rect2]=[]
var _label_jobs:Array=[]
const LABEL_SIZE:=14
const LABEL_WIDTH:=220.0
const INK:=Color("263b34")
const MARK_COLORS:={"camp":Color("ae6438"),"food":Color("4f733b"),"water":Color("32779c"),"danger":Color("aa3f3d"),"supplies":Color("755b87"),"route":Color("795b37")}
const MARK_CODES:={"camp":"Л","food":"Е","water":"В","danger":"!","supplies":"З","route":"П"}
func _ready()->void:
 clip_contents=true;mouse_filter=Control.MOUSE_FILTER_STOP;texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 custom_minimum_size=Vector2(320,260);size_flags_horizontal=Control.SIZE_EXPAND_FILL;size_flags_vertical=Control.SIZE_EXPAND_FILL
 resized.connect(queue_redraw)
func map_rect()->Rect2:
 var side:=maxf(1,minf(size.x-32,size.y-32))*zoom
 return Rect2((size-Vector2.ONE*side)*0.5+pan,Vector2.ONE*side)
func to_screen(point:Vector2)->Vector2:return map_rect().position+(point+Vector2.ONE*2000.0)/4000.0*map_rect().size
func to_world(point:Vector2)->Vector2:return (point-map_rect().position)/map_rect().size*4000.0-Vector2.ONE*2000.0
func zoom_at(factor:float,point:Vector2)->void:
 var world:=to_world(point);zoom=clampf(zoom*factor,1,8);pan+=point-to_screen(world);clamp_pan();queue_redraw();view_changed.emit()
func clamp_pan()->void:
 var limit:=map_rect().size*0.5
 pan=pan.clamp(-limit,limit)
func center_player()->void:
 var point:Vector2=model.last_position
 if is_instance_valid(session) and session.location=="forest":point=Vector2(session.player.global_position.x,session.player.global_position.z)
 if point.is_finite():pan=Vector2.ZERO;pan+=size*0.5-to_screen(point);clamp_pan();queue_redraw();view_changed.emit()
func hit_marker(point:Vector2)->int:
 for i in range(model.markers.size()-1,-1,-1):
  var marker:Dictionary=model.markers[i]
  if to_screen(Vector2(marker.xz[0],marker.xz[1])).distance_to(point)<18:return int(marker.id)
 return -1
func _gui_input(event:InputEvent)->void:
 if event is InputEventMouseButton:
  if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom_at(1.25,event.position)
  elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom_at(0.8,event.position)
  elif event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE]:
   if event.pressed:dragging=true;drag_distance=0
   else:
    dragging=false
    if drag_distance<6 and event.button_index==MOUSE_BUTTON_LEFT:
     var id:=hit_marker(event.position)
     if id>=0:marker_selected.emit(id)
     elif mark_mode:point_selected.emit(to_world(event.position))
  elif event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
   var id:=hit_marker(event.position)
   if id>=0:model.remove_marker(id);selected_id=-1;queue_redraw();view_changed.emit()
  accept_event()
 elif event is InputEventMouseMotion and dragging:
  drag_distance+=event.relative.length();pan+=event.relative;clamp_pan();queue_redraw();view_changed.emit();accept_event()
func draw_route(points:Array,color:Color,width:float)->void:
 if points.size()<2:return
 var path:=PackedVector2Array()
 for p in points:path.append(to_screen(Vector2(float(p[0]),-float(p[1]))))
 draw_polyline(path,color,width,true)
func map_label(_font:Font,point:Vector2,text:String)->void:
 _label_jobs.append({"point":point,"text":text})
func reserve_icon(point:Vector2,radius:float)->void:
 _label_rects.append(Rect2(point-Vector2.ONE*radius,Vector2.ONE*radius*2))
func fit_label(font:Font,text:String)->String:
 var result:=text
 if font.get_string_size(result,HORIZONTAL_ALIGNMENT_LEFT,-1,LABEL_SIZE).x<=LABEL_WIDTH:return result
 while not result.is_empty() and font.get_string_size(result+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,LABEL_SIZE).x>LABEL_WIDTH:result=result.left(-1)
 return result+"…"
func place_label(font:Font,point:Vector2,text:String)->void:
 var display:=fit_label(font,text)
 var width:=font.get_string_size(display,HORIZONTAL_ALIGNMENT_LEFT,-1,LABEL_SIZE).x
 var height:=font.get_height(LABEL_SIZE)
 var bounds:=map_rect().intersection(Rect2(Vector2.ZERO,size)).grow(-6)
 for distance in [18.0,38.0,58.0,78.0]:
  for offset in [Vector2(distance,0),Vector2(-width-distance,0),Vector2(12,-distance),Vector2(12,distance),Vector2(-width-12,-distance),Vector2(-width-12,distance)]:
   var baseline:Vector2=point+offset
   var rect:=Rect2(baseline-Vector2(4,font.get_ascent(LABEL_SIZE)+2),Vector2(width+8,height+4))
   if not bounds.encloses(rect):continue
   var overlaps:=false
   for used in _label_rects:
    if used.grow(3).intersects(rect):overlaps=true;break
   if overlaps:continue
   _label_rects.append(rect);_placed_label_rects.append(rect)
   draw_rect(rect,Color(0.94,0.92,0.81,0.95))
   draw_string(font,baseline,display,HORIZONTAL_ALIGNMENT_LEFT,-1,LABEL_SIZE,INK)
   return
 # Dense landmarks keep their symbols; full names remain in the sidebar/editor.
func _draw()->void:
 _label_rects.clear();_placed_label_rects.clear();_label_jobs.clear()
 _label_rects.append(Rect2(10,6,70,32));_label_rects.append(Rect2(14,size.y-62,300,52))
 draw_rect(Rect2(Vector2.ZERO,size),Color("111d19"))
 if model==null:return
 var rect:=map_rect();draw_texture_rect(model.atlas_texture(),rect,false)
 # Roads, water and paths are fully mapped underneath opaque unexplored fog.
 var splines:Dictionary=model.spec.get("splines",{})
 for id in ["road_main","road_east_branch","road_mine_branch"]:
  draw_route(splines.get(id,[]),Color("766b4e"),maxf(2,zoom*2.0))
  draw_route(splines.get(id,[]),Color("ddc895"),maxf(1,zoom*0.85))
 for line in splines.get("trails",{}).values():draw_route(line,Color("8b7e61"),maxf(1,zoom*0.6))
 draw_route(splines.get("river",[]),Color("4e8f9d"),maxf(3,zoom*4.0));draw_route(splines.get("creek",[]),Color("6a9ca5"),maxf(2,zoom*1.5))
 var font:=get_theme_default_font()
 for i in range(1,8):
  var offset:=rect.size.x*i/8.0
  draw_line(rect.position+Vector2(offset,0),rect.position+Vector2(offset,rect.size.y),Color(0.16,0.25,0.20,0.12),1)
  draw_line(rect.position+Vector2(0,offset),rect.position+Vector2(rect.size.x,offset),Color(0.16,0.25,0.20,0.12),1)
 draw_texture_rect(model.fog_texture(),rect,false)
 for poi in model.landmarks:
  if not model.discovered.has(str(poi.id)):continue
  var point:=to_screen(Vector2(poi.xz[0],poi.xz[1]))
  if str(poi.id).begins_with("WATER_"):draw_circle(point,5,Color("32779c"))
  else:draw_rect(Rect2(point-Vector2.ONE*3,Vector2.ONE*6),INK)
  reserve_icon(point,5);map_label(font,point,str(poi.name))
 if is_instance_valid(session):
  for fire in session.fires:
   var at:=Vector2(fire.pos[0],fire.pos[2])
   if model.is_revealed(at):
    draw_circle(to_screen(at),4,Color("be6033"));reserve_icon(to_screen(at),6);map_label(font,to_screen(at),"Костёр")
  for bed in session.forest_beds:
   var at:=Vector2(bed.pos[0],bed.pos[2])
   if model.is_revealed(at):
    reserve_icon(to_screen(at),10);draw_string(font,to_screen(at),"×" if bed.get("spent",false) else "Л",HORIZONTAL_ALIGNMENT_LEFT,-1,16,INK)
 for marker in model.markers:
  var point:=to_screen(Vector2(marker.xz[0],marker.xz[1]));var color:Color=MARK_COLORS[marker.kind]
  reserve_icon(point,16 if int(marker.id)==selected_id else 12)
  if int(marker.id)==selected_id:draw_arc(point,14,0,TAU,24,Color("f4e4b1"),2,true)
  draw_circle(point,10,color);draw_string(font,point+Vector2(-4,5),MARK_CODES[marker.kind],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
  if zoom>=1.5 or int(marker.id)==selected_id:map_label(font,point,str(marker.text))
 var player_pos:Vector2=model.last_position
 if is_instance_valid(session) and session.location=="forest":player_pos=Vector2(session.player.global_position.x,session.player.global_position.z)
 if player_pos.is_finite():
  var point:=to_screen(player_pos);reserve_icon(point,22)
  var arrow:=player_arrow(point,player_heading())
  draw_colored_polygon(arrow,Color("e8b84f"))
  var outline:=arrow.duplicate();outline.append(arrow[0]);draw_polyline(outline,INK,3,true)
 for label_job in _label_jobs:place_label(font,label_job.point,label_job.text)
 draw_rect(rect,Color("69796b"),false,2)
 draw_string(font,Vector2(20,27),"С  ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("eee5d3"))
 var scale_width:=rect.size.x*500.0/4000.0;var at:=Vector2(24,size.y-30)
 draw_line(at,at+Vector2(scale_width,0),Color("eee5d3"),3);draw_string(font,at+Vector2(0,-8),"500 м",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("eee5d3"))

func player_heading()->Vector2:
 if not is_instance_valid(session) or session.location!="forest":return Vector2.UP
 var p:Node3D=session.player
 var forward:Vector3=-p._camera.global_basis.z if is_instance_valid(p._camera) else -p.global_basis.z
 var direction:=Vector2(forward.x,forward.z)
 if direction.length_squared()<0.0001:direction=Vector2(-p.global_basis.z.x,-p.global_basis.z.z)
 return direction.normalized() if direction.length_squared()>0.0001 else Vector2.UP
func player_arrow(point:Vector2,direction:Vector2)->PackedVector2Array:
 var forward:=direction.normalized();var right:=Vector2(-forward.y,forward.x)
 return PackedVector2Array([point+forward*17,point-forward*11+right*10,point-forward*5,point-forward*11-right*10])
