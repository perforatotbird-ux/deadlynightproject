extends SceneTree
var output:=""
func _initialize()->void:call_deferred("run")
func settle(frames:int=8)->void:
 for i in frames:await process_frame
func shot(name:String)->void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run()->void:
 if DisplayServer.get_name()=="headless":quit(0);return
 output=OS.get_environment("DN_QA_OUTPUT")
 if output.is_empty():output="user://qa/part2"
 DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1600,900)
 var arena:=Node3D.new();arena.name="MapViewer";root.add_child(arena);current_scene=arena
 var env:=WorldEnvironment.new();var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("667a78");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=0.75;env.environment=environment;arena.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-40,0);light.light_energy=1.1;arena.add_child(light)
 var p=load("res://scenes/player/Player.tscn").instantiate();arena.add_child(p);p.set_active(true);p.set_physics_process(false);p.position=Vector3(-900,25,1100)
 var s=load("res://scripts/survival/SurvivalWorld.gd").new();arena.add_child(s);s.set_process(false);s.clock=3*86400+19*3600+42*60
 await settle()
 s.ui.hide();p._hud_layer.hide();p.watch_arm.toggle();p.watch_arm.remaining=60;await create_timer(0.5).timeout
 await shot("watch")
 p.watch_arm.remaining=0;await create_timer(0.5).timeout
 # Surveyed test fixture only; production starts blank and reveals walking paths.
 for x in range(-1900,2000,120):
  for z in range(-1900,2000,120):s.map_model.explore(Vector2(x,z))
 for poi in s.map_model.landmarks:s.map_model.discovered[str(poi.id)]=true
 s.map_model.revision+=1
 s.map_model.add_marker(Vector2(-900,1100),"Лагерь у старта","camp")
 s.map_model.add_marker(Vector2(900,-700),"Вода у дороги","water")
 s.map_model.add_marker(Vector2(1500,-1500),"Крутой склон","danger")
 s.map_ui.open_map();s.map_ui.view.zoom=1;s.map_ui.view.pan=Vector2.ZERO;await settle(12);await shot("map_surveyed")
 s.map_ui.close_map();s.map_model.import_state({});s.map_model.explore(Vector2(-900,1100));s.map_model.explore(Vector2(-850,1030));s.map_model.explore(Vector2(-780,970));s.map_ui.open_map();s.map_ui.view.zoom=4;s.map_ui.view.center_player();await settle(12);await shot("map_exploration")
 s.map_ui.close_map();p._audio_ui.stop();await create_timer(0.2).timeout;arena.free();current_scene=null;await settle();quit(0)
