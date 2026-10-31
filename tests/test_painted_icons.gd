extends SceneTree
const Art=preload("res://scripts/ui/JournalArt.gd")
var passes:=0
var failures:=0
var graphical:=false
var output:=OS.get_environment("DN_ICON_QA_OUTPUT")
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passes+=1;print("PASS: "+label)
 else:failures+=1;printerr("FAIL: "+label)
func settle(n:int=5):
 for i in n:await process_frame
func capture(id:String):
 if not graphical:return
 RenderingServer.set_render_loop_enabled(true);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(id+".png"));RenderingServer.set_render_loop_enabled(false)
func run():
 graphical=DisplayServer.get_name()!="headless" and not output.is_empty()
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720)
 if graphical:DirAccess.make_dir_recursive_absolute(output);RenderingServer.set_render_loop_enabled(false)
 check(Art.PAINTED_IDS.size()==32,"exactly 32 finished replacements for audited placeholders")
 for id in Art.PAINTED_IDS:
  var image:=Image.load_from_file("res://assets/ui/field_journal/icons/"+id+".png")
  check(image!=null and image.get_size()==Vector2i(320,320) and image.get_format()==Image.FORMAT_RGBA8,"RGBA 320x320: "+id)
  var texture:=Art.texture(id)
  check(texture!=null and texture.resource_path.ends_with(id+".png"),"runtime prefers painted PNG over legacy SVG: "+id)
  check(Art.source_texture(Art.ROOT+"icons/"+id+".png")!=null,"source fallback loads: "+id)
 for id in Art.IDS:check(Art.texture(id)!=null,"retained existing painted tool/resource: "+id)
 for id in preload("res://scripts/vegetation/VegetationCatalog.gd").FOOD_IDS:check(id in Art.PAINTED_IDS,"every plant/food ID has finished art: "+id)
 var menu=load("res://scripts/menu/NewGameScreen.gd").new();root.add_child(menu);await settle()
 for button in menu._diff_buttons:
  check(button.icon!=null and button.icon.resource_path.ends_with(".png"),"difficulty button uses image, not emoji: "+button.text)
 await capture("difficulty_1280");menu.free();await settle()
 var scene:=Node3D.new();scene.name="MapViewer";root.add_child(scene);current_scene=scene
 var ground:=StaticBody3D.new();ground.add_to_group("camp_ground");scene.add_child(ground);var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(150,1,150);collision.shape=box;collision.position.y=-0.5;ground.add_child(collision)
 var env:=WorldEnvironment.new();env.name="WorldEnvironment";env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("15201d");scene.add_child(env)
 var p=load("res://scenes/player/Player.tscn").instantiate();scene.add_child(p);p.position=Vector3(0,0.2,0);p.set_active(true);p.set_physics_process(false)
 var s=load("res://scripts/survival/SurvivalWorld.gd").new();scene.add_child(s);s.set_process(false);s.vegetation.set_physics_process(false);s.shelter.position=Vector3(40,0,40)
 await physics_frame;await settle()
 for id in ["water","raw_water","ration","berries","bandage","compress","antitoxin","field_notes","krasnitsa","sizovka","bolotnitsa","forest_fat","wood_fan","copper_false","pale_bell","stump_fan"]:
  s.Items.transact(p,{},[s.Items.item(id)])
 s.vegetation.learn_notes();s.open_backpack();p._backpack_ui.tabs.current_tab=0;await settle()
 for b in p._backpack_ui.category_buttons:check(b.icon!=null and "category_" in b.icon.resource_path,"dedicated category art: "+b.text)
 for node in s.resources.values():
  if node.item_data.get("type","") in ["water","raw_water","ration","bandage","compress","berries","antitoxin","field_notes","wood_tea"]:
   for child in node.get_children():
    if child is Sprite3D:check(child.texture.resource_path.ends_with(".png") and absf(child.texture.get_width()*child.pixel_size-0.28)<0.001,"pickup uses painted texture without enlarging world billboard")
 for dimensions in [Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=dimensions;await settle();p._backpack_ui.resize();await settle();await capture("inventory_%d"%dimensions.x)
  p._backpack_ui.tabs.current_tab=3;await settle();await capture("guide_top_%d"%dimensions.x)
  var sc:Node=p._backpack_ui.guide_entries.stump_fan.title
  while sc!=null and not sc is ScrollContainer:sc=sc.get_parent()
  if sc is ScrollContainer:sc.scroll_vertical=10000
  await settle();await capture("guide_bottom_%d"%dimensions.x)
  p._backpack_ui.tabs.current_tab=0
  if sc is ScrollContainer:sc.scroll_vertical=0
  check(root.get_visible_rect().encloses(p._inv_root_panel.get_global_rect()),"new art does not expand journal outside viewport: "+str(dimensions))
 # All cooked forms and tea also go through the real inventory inspector.
 s.close_backpack();p.inventory_slots.fill(null)
 for id in ["cooked_forest_fat","cooked_wood_fan","cooked_copper_false","cooked_pale_bell","wood_tea"]:s.Items.transact(p,{},[s.Items.item(id)])
 s.open_backpack();p._backpack_ui.tabs.current_tab=0;await settle();await capture("cooked_inventory_1920")
 scene.free();current_scene=null;await settle()
 print("PAINTED ICONS SUMMARY: %d PASS, %d FAIL"%[passes,failures]);quit(1 if failures else 0)
