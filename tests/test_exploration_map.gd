extends SceneTree
const Model=preload("res://scripts/world/ExplorationMap.gd")
var passes:=0
var failures:=0
func check(ok:bool,text:String)->void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func _initialize()->void:call_deferred("run")
func run()->void:
 var model:=Model.new()
 check(model.landmarks.size()==16,"all twelve spec landmarks, cabin and three raw water sources included")
 check(model.explored.is_empty() and model.markers.is_empty(),"new map starts unexplored")
 var spawn:=Vector2(-900,1100);model.explore(spawn)
 check(model.is_revealed(spawn) and model.discovered.has("SPAWN"),"walking reveals ground and discovers real spawn landmark")
 check(not model.is_revealed(Vector2(1500,-1500)) and not model.discovered.has("PEAK"),"distant mountain and location label remain hidden")
 check(model.add_marker(Vector2(1500,-1500),"secret","route")==-1,"cannot mark unseen terrain")
 var id:=model.add_marker(spawn,"Мой лагерь","camp")
 check(id>0 and model.markers.size()==1,"explored terrain accepts custom mark")
 check(model.update_marker(id,"Опасный склон","danger") and model.markers[0].text=="Опасный склон","marker title and type can be edited")
 var saved:Dictionary=JSON.parse_string(JSON.stringify(model.export_state()))
 var restored:=Model.new();restored.import_state(saved)
 check(restored.explored==model.explored and restored.discovered==model.discovered and restored.markers==model.markers,"JSON roundtrip preserves fog, discoveries and annotations")
 var next_id:=restored.add_marker(spawn,"Вода","water");check(next_id>id,"marker IDs remain unique after reload")
 check(restored.remove_marker(id) and restored.markers.size()==1,"marker deletion persists authoritative state")
 model.explore(Vector2(1500,-1500));check(model.discovered.has("PEAK") and not model.is_revealed(Vector2.ZERO),"teleport reveals destination, never unexplored corridor")
 check(model.fog_texture().get_image().get_pixelv(model.cell_at(spawn)).a==0,"explored fog pixel is transparent")
 check(model.fog_texture().get_image().get_pixelv(model.cell_at(Vector2.ZERO)).a>0.99,"unexplored fog pixel is fully opaque")
 var atlas:=model.atlas_texture();check(atlas.get_width()==512 and atlas.get_height()==512,"topographic atlas generated from actual 16-bit terrain heightmap")
 var image:=atlas.get_image();check(image.get_pixel(100,100)!=image.get_pixel(450,450),"atlas includes varying terrain, not a flat placeholder")
 var corrupt:=Model.new();corrupt.import_state({"explored":["-1:0","500:500","bad","1:2"],"markers":[{"id":1,"xz":[0,0],"kind":"bogus"}]})
 check(corrupt.explored.size()==1 and corrupt.markers.is_empty(),"invalid saved cells and marker types are rejected")
 var arena:=Node3D.new();arena.name="MapViewer";root.add_child(arena);current_scene=arena
 var p=load("res://scenes/player/Player.tscn").instantiate();arena.add_child(p);p.position=Vector3(-900,25,1100);p.set_active(true);p.set_physics_process(false)
 var s=load("res://scripts/survival/SurvivalWorld.gd").new();arena.add_child(s);s.set_process(false)
 await process_frame
 var event:=InputEventKey.new();event.pressed=true;event.keycode=KEY_M;event.physical_keycode=KEY_M;p._input(event)
 check(s.map_ui.visible and p._is_map_open and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"M opens interactive map and releases cursor")
 var view=s.map_ui.view;view.size=Vector2(800,560)
 var point:=Vector2(-900,1100);check(view.to_world(view.to_screen(point)).distance_to(point)<0.01,"screen/world coordinate conversion roundtrips without mirroring")
 var cursor:=Vector2(300,200);var before:Vector2=view.to_world(cursor);view.zoom_at(1.25,cursor)
 check(view.to_world(cursor).distance_to(before)<0.01,"zoom stays anchored beneath mouse cursor")
 view.mark_mode=true
 for pressed in [true,false]:
  var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=pressed;click.position=view.to_screen(point);view._gui_input(click)
 check(s.map_ui.pending_point.distance_to(point)<0.01,"actual map click selects an explored annotation point")
 s.map_ui.marker_name.text="Лесной лагерь";s.map_ui.save_marker()
 check(s.map_model.markers.size()==1 and s.map_model.markers[0].text=="Лесной лагерь","UI editor creates a real saved marker")
 s.map_ui.select_marker(int(s.map_model.markers[0].id));s.map_ui.marker_name.text="Другой лагерь";s.map_ui.marker_kind.select(3);s.map_ui.save_marker()
 check(s.map_model.markers[0].text=="Другой лагерь" and s.map_model.markers[0].kind=="danger","UI edits existing mark without duplicating it")
 var payload:Dictionary=JSON.parse_string(JSON.stringify(s.export_state()));s.map_model.markers.clear();s.import_state(payload)
 check(s.map_model.markers.size()==1 and s.map_model.is_revealed(point) and not p._is_map_open,"SurvivalWorld restores map and safely closes stale overlay")
 s.map_ui.open_map();event.keycode=KEY_ESCAPE;event.physical_keycode=KEY_ESCAPE;p._input(event)
 check(not s.map_ui.visible and not p._is_map_open,"Escape closes map before pause/menu actions")
 s.location="mine";var cells:int=s.map_model.explored.size();s._process(0.1)
 check(s.map_model.explored.size()==cells,"mine coordinates never reveal unrelated forest cells")
 p._audio_ui.stop();await create_timer(0.1).timeout;arena.free();current_scene=null
 print("EXPLORATION MAP SUMMARY: %d PASS, %d FAIL" % [passes,failures])
 for i in 3:await process_frame
 quit(1 if failures else 0)
