extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var arena:=Node3D.new();arena.name="MapViewer";root.add_child(arena);current_scene=arena
 var p=load("res://scenes/player/Player.tscn").instantiate();arena.add_child(p);p.set_active(true);p.set_physics_process(false);p.position=Vector3(-900,26,1100)
 var s=load("res://scripts/survival/SurvivalWorld.gd").new();arena.add_child(s);s.set_process(false)
 for x in 100:
  for y in 100:s.map_model.explored["%d:%d"%[x,y]]=true
 for poi in s.map_model.landmarks:s.map_model.discovered[poi.id]=true
 s.map_model.last_position=Vector2(-900,1100);s.map_model.revision+=1
 s.map_model.add_marker(Vector2(-900,1100),"Длинная отметка возле лесной стоянки и поляны старта","camp")
 s.map_model.add_marker(Vector2(700,-1550),"Опасный участок у скального выступа","danger")
 for i in 3:s.fires.append({"id":"qa_fire_"+str(i),"pos":[-910.0+i*14,26.0,1088.0],"state":"burning"})
 s.map_ui.open_map();s.map_ui.view.zoom=1.0;s.map_ui.view.queue_redraw()
 # Do not render the 3D world: this screenshot tests the real map CanvasLayer.
 p._hud_layer.hide();s.ui.hide();root.get_viewport().disable_3d=true
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 var dir:=OS.get_environment("MAP_QA_DIR");if dir.is_empty():dir="user://"
 validate_labels(s.map_ui.view)
 root.get_texture().get_image().save_png(dir+"/full.png")
 s.map_ui.select_marker(1);s.map_ui.view.zoom=4;s.map_ui.view.center_player()
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 validate_labels(s.map_ui.view)
 root.get_texture().get_image().save_png(dir+"/zoom.png")
 arena.free();await process_frame;quit()

func validate_labels(view:Control)->void:
 var rects:Array=view._placed_label_rects
 for i in rects.size():
  assert(view.map_rect().intersection(Rect2(Vector2.ZERO,view.size)).encloses(rects[i]),"label must stay inside map")
  for j in range(i):assert(not rects[i].intersects(rects[j]),"map label overlap")
 print("MAP LABEL LAYOUT PASS: ",rects.size()," non-overlapping labels")
