extends SceneTree
const Art=preload("res://scripts/ui/JournalArt.gd")
var passes:=0
var failures:=0
var graphical:=false
var out:="/data/hotfix-previews"
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 if ok:passes+=1;print("PASS: "+label)
 else:failures+=1;print("FAIL: "+label)
func settle(n:int=3) -> void:
 for i in n:await process_frame
func capture(label:String) -> void:
 if not graphical:return
 await settle();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out.path_join(label+".png"))
func run() -> void:
 graphical=DisplayServer.get_name()!="headless";root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720)
 if graphical:DirAccess.make_dir_recursive_absolute(out)
 for id in Art.IDS:check(Art.source_texture(Art.ROOT+"icons/"+id+".png")!=null,"source PNG fallback "+id)
 Art.cache["stone"]=null
 check(Art.texture("stone")!=null,"failed/null cache entry is retried")
 var fake:=FileAccess.open("user://fake_pointer.png",FileAccess.WRITE);fake.store_string("version https://git-lfs.github.com/spec/v1\n");fake.close()
 check(Art.source_texture("user://fake_pointer.png")==null,"LFS pointer is not passed to PNG decoder")
 var launcher:=FileAccess.get_file_as_string("res://run.bat")
 check(launcher.find("--editor --import")<launcher.find('start ""'),"launcher waits for import before game start")
 check('findstr /c:"ERROR:"' in launcher and "git lfs pull" in launcher,"launcher reports import errors / undownloaded LFS")
 var scene:=Node3D.new();scene.name="MapViewer";root.add_child(scene);current_scene=scene
 var ground:=StaticBody3D.new();ground.add_to_group("camp_ground");scene.add_child(ground)
 var shape:=BoxShape3D.new();shape.size=Vector3(160,1,160);var collision:=CollisionShape3D.new();collision.shape=shape;collision.position.y=-0.5;ground.add_child(collision)
 var geometry:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=shape.size;geometry.mesh=mesh;geometry.position.y=-0.5;var mat:=StandardMaterial3D.new();mat.albedo_color=Color(0.22,0.27,0.2);geometry.material_override=mat;ground.add_child(geometry)
 var env:=WorldEnvironment.new();env.name="WorldEnvironment";env.environment=Environment.new();env.environment.background_mode=Environment.BG_SKY;scene.add_child(env)
 var sun:=DirectionalLight3D.new();sun.name="DirectionalLight3D";sun.shadow_enabled=false;scene.add_child(sun)
 var p=load("res://scenes/player/Player.tscn").instantiate();scene.add_child(p);p.set_physics_process(false);p.set_active(true);p.position=Vector3(0,0.2,0)
 var s=load("res://scripts/survival/SurvivalWorld.gd").new();scene.add_child(s);s.set_process(false);s.shelter.position=Vector3(40,0,40)
 await physics_frame;await settle()
 var items=s.Items
 for id in ["stone","brush","flint","pyrite","camp_kit"]:items.transact(p,{},[items.item(id)])
 s.open_backpack();var ui=p._backpack_ui;await settle();ui.resize();await settle()
 check(ui.item_grid.columns==1 and ui.recipe_grid.columns==4,"compact inventory list and retained recipe grid")
 check(p._inv_slot_buttons[0].custom_minimum_size==Vector2(0,60),"inventory uses compact 60px rows")
 check(ui.recipe_cards.camp_kit.custom_minimum_size==Vector2(55,95),"recipe card minimum is half old 110x190")
 var c:Button=p._inv_slot_buttons[0];check(c.size.y<=76,"actual inventory card height is compact, not stretched back to 150")
 check(c.picture.texture!=null and c.caption.get_theme_font_size("font_size")>=12,"compact cards retain actual art and readable font")
 await capture("01_compact_inventory_720p")
 ui.tabs.current_tab=1;ui.select_recipe("camp_kit");await settle()
 check(ui.recipe_cards.camp_kit.size.y<=96,"actual recipe height is compact")
 await capture("02_compact_craft_720p")
 for resolution in [Vector2i(800,600),Vector2i(1920,1080)]:
  root.size=resolution;await settle();ui.resize();await settle()
  check(ui.item_grid.columns==1,"compact responsive list "+str(resolution))
  await capture("03_compact_craft_"+str(resolution.x))
 s.close_backpack();root.size=Vector2i(1280,720)
 s.clock=14*3600;s.weather="rain";s.weather_until=s.clock+10000;s.weather_model.reset(s.clock,true);s.weather_model.rain_style="heavy_rain";s._update_lighting()
 p._camera.look_at(Vector3(0,0,-6),Vector3.UP)
 var rain=s.rain_field
 for i in 90:rain.update_field(0.1,s.weather_visual,1)
 check(rain.ground_samples.size()>100,"bounded shared surface cache is populated")
 check(absf(rain.ground_height(Vector3(0,0,0)))<0.01,"surface cache reads actual terrain height")
 check(not rain.field.multimesh.use_custom_data,"terrain clipping is CPU-based, independent of renderer custom-data precision")
 var below:=0
 for i in rain.count:
  var local:Vector3=rain.positions[i];var world:Vector3=local+rain.global_position;var h:float=rain.ground_height(world)
  if h>-90000 and world.y<h+0.08:below+=1
 check(below==0,"no visible drop centers below sampled ground")
 check(rain.field.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"rain cannot project a comb of shadows")
 var airborne:=0
 for splash in rain.splashes:
  if splash.visible and absf(splash.global_basis.z.normalized().dot(p._camera.global_basis.z.normalized()))>0.99:airborne+=1
 check(airborne>0,"splash specks face camera, no coplanar ground rings")
 check("depth_draw_never" in rain.material.shader.code and "SPECULAR=0.0" in rain.material.shader.code,"rain has no transparent depth writes or specular stripe highlights")
 if graphical:
  Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;p._hud_layer.hide();s.ui.hide()
  for i in 4:
   for step in 3:rain.update_field(1.0/30,s.weather_visual,1)
   await capture("04_rain_ground_"+str(i))
 print("UI / RAIN HOTFIX SUMMARY: %d PASS, %d FAIL"%[passes,failures])
 scene.queue_free();await settle();quit.call_deferred(1 if failures else 0)
