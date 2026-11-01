extends CanvasLayer
const Style=preload("res://scripts/ui/JournalTheme.gd")
var session:Node
var root_control:Control
var view:Control
var status:Label
var details:Label
var marker_name:LineEdit
var marker_kind:OptionButton
var mark_button:Button
var save_button:Button
var delete_button:Button
var locations:ItemList
var selected_id:=-1
var pending_point:=Vector2(INF,INF)
var _revision:=-1
var _refresh_tick:=0.0
var _old_mouse_mode:=Input.MOUSE_MODE_CAPTURED
func _ready()->void:
 layer=70;visible=false;name="ExplorationMapUI"
 root_control=PanelContainer.new();root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root_control.theme=Style.theme();root_control.add_theme_stylebox_override("panel",Style.box(Color("101c18"),Color("536255")));add_child(root_control)
 var margin:=MarginContainer.new()
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,18)
 root_control.add_child(margin)
 var main:=VBoxContainer.new();main.add_theme_constant_override("separation",10);margin.add_child(main)
 var head:=HBoxContainer.new();main.add_child(head)
 var title:=Label.new();title.text="ПОЛЕВАЯ КАРТА  /  ВЕСЕННИЙ ЛЕС";title.add_theme_font_override("font",Style.title_font());title.add_theme_font_size_override("font_size",26);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;title.custom_minimum_size.x=180;head.add_child(title)
 button(head,"−",func():view.zoom_at(0.8,view.size*0.5))
 button(head,"+",func():view.zoom_at(1.25,view.size*0.5))
 button(head,"К игроку",func():view.center_player())
 button(head,"Закрыть · M",close_map)
 status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;main.add_child(status)
 var body:=HBoxContainer.new();body.add_theme_constant_override("separation",18);body.size_flags_vertical=Control.SIZE_EXPAND_FILL;main.add_child(body)
 view=preload("res://scripts/ui/ExplorationMapView.gd").new();view.model=session.map_model;view.session=session;body.add_child(view)
 var sidebar_scroll:=ScrollContainer.new();sidebar_scroll.custom_minimum_size.x=260;sidebar_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(sidebar_scroll)
 var sidebar:=VBoxContainer.new();sidebar.custom_minimum_size.x=245;sidebar.add_theme_constant_override("separation",10);sidebar_scroll.add_child(sidebar)
 var legend:=Label.new();legend.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;legend.text="Дороги — охра\nРека и ручей — синий\nСиние точки — сырая вода\nГоризонтали — каждые 20 м\nТёмное — ещё не исследовано\nЗолотая стрелка — вы и ваш взгляд";sidebar.add_child(legend)
 mark_button=button(sidebar,"Новая отметка",func():selected_id=-1;view.selected_id=-1;pending_point=Vector2(INF,INF);view.mark_mode=true;details.text="Выберите исследованную точку на карте.";marker_name.clear();refresh_editor())
 marker_name=LineEdit.new();marker_name.placeholder_text="Подпись отметки";marker_name.max_length=60;sidebar.add_child(marker_name);marker_name.text_submitted.connect(func(_text):save_marker();marker_name.release_focus())
 marker_kind=OptionButton.new()
 for title_text in ["Ночлег","Еда","Вода","Опасность","Припасы","Маршрут"]:marker_kind.add_item(title_text)
 sidebar.add_child(marker_kind)
 details=Label.new();details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.custom_minimum_size=Vector2(240,42);sidebar.add_child(details)
 save_button=button(sidebar,"Сохранить отметку",save_marker)
 delete_button=button(sidebar,"Удалить отметку",delete_marker)
 var location_title:=Label.new();location_title.text="ОБНАРУЖЕННЫЕ МЕСТА";sidebar.add_child(location_title)
 locations=ItemList.new();locations.custom_minimum_size=Vector2(240,160);sidebar.add_child(locations)
 locations.item_selected.connect(func(index:int):
  var id:String=locations.get_item_metadata(index)
  for poi in session.map_model.landmarks:
   if poi.id==id:view.pan=Vector2.ZERO;view.pan+=view.size*0.5-view.to_screen(Vector2(poi.xz[0],poi.xz[1]));view.clamp_pan();view.queue_redraw())
 var help:=Label.new();help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;help.text="Колесо — масштаб · ЛКМ/СКМ + движение — перемещение\nВыберите отметку для редактирования · ПКМ по отметке — удалить\nМир не на паузе. Исследование и отметки сохраняются вместе с игрой.";main.add_child(help)
 view.point_selected.connect(select_point);view.marker_selected.connect(select_marker);view.view_changed.connect(refresh_status)
 refresh_editor()
func button(parent:Node,text:String,action:Callable)->Button:
 var b:=Button.new();b.text=text;b.custom_minimum_size.y=40;b.pressed.connect(action);parent.add_child(b);return b
func open_map()->bool:
 if not is_instance_valid(session.player) or not session.player._is_active or session.health<=0 or (not session.job.is_empty() and not session.is_background_job()) or session.placing:return false
 if session.player._is_inventory_open:session.close_backpack()
 _old_mouse_mode=Input.mouse_mode;visible=true;session.player._is_map_open=true;session.player._cancel_chop();
 if is_instance_valid(session.player.watch_arm):session.player.watch_arm.lower()
 session.player._hud_layer.hide();session.ui.refresh();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 if session.location=="forest":session.map_model.explore(Vector2(session.player.global_position.x,session.player.global_position.z))
 session.map_model.atlas_texture();_revision=-1;refresh_status();view.queue_redraw();return true
func close_map()->void:
 if not visible:return
 visible=false;view.dragging=false;view.mark_mode=false;selected_id=-1;view.selected_id=-1;pending_point=Vector2(INF,INF);refresh_editor();session.player._is_map_open=false;session.player._hud_layer.visible=session.player._hud_enabled and session.player._is_active;session.ui.refresh();Input.mouse_mode=_old_mouse_mode
func select_point(point:Vector2)->void:
 if not session.map_model.is_revealed(point):details.text="Сначала исследуйте эту часть леса.";return
 pending_point=point;selected_id=-1;view.selected_id=-1;details.text="Точка %.0f, %.0f м" % [point.x,-point.y];refresh_editor()
func select_marker(id:int)->void:
 for marker in session.map_model.markers:
  if int(marker.id)!=id:continue
  selected_id=id;view.selected_id=id;marker_name.text=marker.text;marker_kind.select(session.map_model.MARKER_KINDS.find(marker.kind));pending_point=Vector2(marker.xz[0],marker.xz[1]);details.text="Редактирование отметки";refresh_editor();view.queue_redraw();return
func save_marker()->void:
 var kind:String=session.map_model.MARKER_KINDS[marker_kind.selected]
 if selected_id>=0:session.map_model.update_marker(selected_id,marker_name.text,kind)
 elif pending_point.is_finite():selected_id=session.map_model.add_marker(pending_point,marker_name.text,kind)
 if selected_id<0:details.text="Отметка не добавлена: выберите изученную точку (лимит 256).";return
 view.selected_id=selected_id;view.mark_mode=false;details.text="Отметка сохранена в состоянии игры.";refresh_editor();refresh_status();view.queue_redraw()
func delete_marker()->void:
 if selected_id>=0:session.map_model.remove_marker(selected_id)
 selected_id=-1;view.selected_id=-1;pending_point=Vector2(INF,INF);refresh_editor();refresh_status();view.queue_redraw()
func refresh_editor()->void:
 save_button.disabled=not pending_point.is_finite();delete_button.disabled=selected_id<0
func refresh_status()->void:
 if selected_id>=0:
  var found:=false
  for marker in session.map_model.markers:
   if int(marker.id)==selected_id:found=true;break
  if not found:selected_id=-1;pending_point=Vector2(INF,INF);refresh_editor()
 status.text="Исследовано %.1f%% · мест %d/%d · отметок %d/256 · масштаб ×%.2f%s" % [session.map_model.coverage(),session.map_model.discovered.size(),session.map_model.landmarks.size(),session.map_model.markers.size(),view.zoom," · в шахте показан последний путь в лесу" if session.location=="mine" else ""]
 if _revision!=session.map_model.revision:
  _revision=session.map_model.revision;locations.clear()
  for poi in session.map_model.landmarks:
   if session.map_model.discovered.has(str(poi.id)):locations.add_item(str(poi.name));locations.set_item_metadata(locations.item_count-1,str(poi.id))
  view.queue_redraw()
func _process(delta:float)->void:
 if not visible:return
 if session.health<=0 or not session.player._is_active:close_map();return
 _refresh_tick-=delta
 if _refresh_tick<=0:_refresh_tick=0.25;refresh_status();view.queue_redraw()
