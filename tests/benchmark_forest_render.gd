extends SceneTree
## Full scene / full far plane, no QA chunk hiding. Use an isolated user profile.
const Settings=preload("res://scripts/core/SettingsManager.gd")
var output:="user://forest_benchmark.json"
var samples:=120
var warmup_frames:=60
var width:=1920
var height:=1080
var game:Node
func _initialize() -> void:
 # Must precede any Settings/session construction; never touch the player profile.
 ProjectSettings.set_setting("application/config/name","Deadly Night Benchmark")
 ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
 ProjectSettings.set_setting("application/config/custom_user_dir_name","DeadlyNightBenchmark")
 if OS.get_user_data_dir().replace("\\","/").get_file()!="DeadlyNightBenchmark":
  printerr("Benchmark profile isolation failed; refusing to run");quit(2);return
 if DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())!=OK:
  printerr("Cannot create isolated benchmark profile");quit(2);return
 call_deferred("run")
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
  if arg.begins_with("--samples="):samples=int(arg.trim_prefix("--samples="))
  if arg.begins_with("--width="):width=int(arg.trim_prefix("--width="));height=roundi(width*9.0/16.0)
 if DisplayServer.get_name()=="headless":printerr("Use a native display for rendering metrics");quit(2);return
 var settings=Settings.get_instance()
 for key in {"resolution_x":width,"resolution_y":height,"max_fps":0,"vsync":0,"view_distance":2,"shadow_quality":2,"sky_quality":2,"rain_quality":2,"fog_enabled":true,"window_mode":0}:
  settings.set_setting("graphics",key,{"resolution_x":width,"resolution_y":height,"max_fps":0,"vsync":0,"view_distance":2,"shadow_quality":2,"sky_quality":2,"rain_quality":2,"fog_enabled":true,"window_mode":0}[key])
 root.size=Vector2i(width,height);Engine.max_fps=0
 RenderingServer.set_render_loop_enabled(false)
 game=load("res://scenes/viewer/MapViewer.tscn").instantiate();root.add_child(game);current_scene=game
 var player=game.get_node("Player");player.set_physics_process(false);player.set_process_input(false)
 var session=player.survival;session.clock=13*3600;session.weather="clear";session._update_lighting();session.set_process(false)
 player.global_position=Vector3(-900,25.5,1098.5);player.rotation=Vector3.ZERO;player._camera_pitch=0;player._camera_pivot.rotation=Vector3.ZERO;player._camera.current=true
 settings.apply_graphics_settings()
 var world=game.get_node("WorldMap")
 for i in 8:await physics_frame;await process_frame
 var rid:=root.get_viewport_rid();RenderingServer.viewport_set_measure_render_time(rid,true)
 var report:Dictionary={"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"resolution":[width,height],"max_settings":true,"qa_visibility_reduction":false,"samples":[],"frames":samples,"profile":OS.get_user_data_dir(),"camera_far":player._camera.far,"player_position":[-900,25.5,1098.5],"logical_cpu_count":OS.get_processor_count(),"processor":OS.get_processor_name(),"warmup_frames":warmup_frames,"trees":world._all_trees_data.size()}
 print("FOREST BENCHMARK drawing full world, ",width,"x",height,"; profile=",OS.get_user_data_dir())
 RenderingServer.set_render_loop_enabled(true)
 for i in samples+warmup_frames:
  var start:=Time.get_ticks_usec()
  await process_frame;await RenderingServer.frame_post_draw
  if i>=warmup_frames:
   report.samples.append({"frame_ms":(Time.get_ticks_usec()-start)/1000.0,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(rid),"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"objects":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),"static_memory":Performance.get_monitor(Performance.MEMORY_STATIC),"texture_memory":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0})
 var file:=FileAccess.open(output,FileAccess.WRITE)
 if file==null:printerr("Cannot write benchmark output: ",output);quit(2);return
 file.store_string(JSON.stringify(report,"  "));file.close()
 print("FOREST BENCHMARK saved to ",output,"; renderer=",report.renderer,"; samples=",samples)
 RenderingServer.set_render_loop_enabled(false)
 game.free();current_scene=null
 for i in 12:await process_frame
 quit()
