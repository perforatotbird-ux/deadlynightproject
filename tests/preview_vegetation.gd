extends SceneTree
const Settings=preload("res://scripts/core/SettingsManager.gd")
const Catalog=preload("res://scripts/vegetation/VegetationCatalog.gd")
const Visuals=preload("res://scripts/vegetation/VegetationVisuals.gd")
var output:=OS.get_environment("DN_QA_OUTPUT")
var failures:=0
func _initialize():call_deferred("run")
func settle(n:int=6):
 for i in n:await process_frame
func capture(id:String):
 RenderingServer.set_render_loop_enabled(true);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(id+".png"));RenderingServer.set_render_loop_enabled(false)
func run():
 if DisplayServer.get_name()=="headless" or output.is_empty():quit(2);return
 DirAccess.make_dir_recursive_absolute(output);root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1600,900)
 Settings.get_instance().set_setting("graphics","shadow_quality",0);RenderingServer.set_render_loop_enabled(false)
 # Native mesh study: actual production meshes, not a painted mockup.
 var gallery:=Node3D.new();root.add_child(gallery)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-25,0);light.light_energy=1.2;gallery.add_child(light)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("182421");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("bdc3b5");environment.environment.ambient_light_energy=0.65;gallery.add_child(environment)
 var camera:=Camera3D.new();gallery.add_child(camera);camera.position=Vector3(2.3,4.5,5.6);camera.look_at(Vector3(2.3,0.2,-1.0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.0;camera.current=true
 var idx:=0
 for id in Catalog.SPECIES:
  var mesh:=MeshInstance3D.new();mesh.mesh=Visuals.mesh(id);mesh.position=Vector3((idx%4)*1.5,0,-floorf(idx/4.0)*2.6);gallery.add_child(mesh)
  var label:=Label3D.new();label.text=Catalog.species(id).name;label.position=mesh.position+Vector3(0,0,0.60);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=36;label.pixel_size=0.004;label.no_depth_test=true;label.outline_size=4;label.modulate=Color("e4d8ba");gallery.add_child(label);idx+=1
 await settle();await capture("species_meshes");gallery.free()
 var game=load("res://scenes/viewer/MapViewer.tscn").instantiate();root.add_child(game);current_scene=game
 var p=game.get_node("Player");p.set_physics_process(false);p._camera.current=true;p._camera.far=150
 var s=p.survival;s.set_process(false);s.clock=12*3600;s.weather="clear";s._update_lighting();s.vegetation.set_physics_process(false)
 var world=game.get_node("WorldMap");var origin:Vector3=p.global_position
 for chunk in world._vegetation_root.get_children():
  var at:=Vector3.ZERO
  if chunk.get_child_count()>0:
   var mmi=chunk.get_child(0)
   if mmi.multimesh.instance_count>0:at=mmi.multimesh.get_instance_transform(0).origin
  if Vector2(at.x-origin.x,at.z-origin.z).length()>200:chunk.hide()
 for mesh in world._collect_all_meshes(world._terrain_root):
  if not (mesh.global_transform*mesh.get_aabb()).grow(160).has_point(origin):mesh.hide()
 game.get_node("DirectionalLight3D").shadow_enabled=false;world._pois_root.hide()
 await physics_frame
 for i in 13:s.vegetation.stream();await physics_frame
 var target:Dictionary={}
 for rs in s.vegetation.patches.values():
  for r in rs:
   if r.species=="krasnitsa":target=r;break
  if not target.is_empty():break
 if not target.is_empty():
  var pos:Vector3=s._v3(target.pos);p.global_position=pos+Vector3(0,0,1.8);p._camera_pitch=0;p.rotation.y=0;p._camera_pivot.rotation.x=-0.48
  s.vegetation.stream();await physics_frame;p._axe_model.hide()
  s.ui.refresh();await settle();await capture("world_berry_patch")
  var plant=s.vegetation.active.get(target.id)
  if is_instance_valid(plant):
   p._raycast.target_position=p._raycast.to_local(plant.global_position+Vector3.UP*0.5);p._raycast.force_raycast_update();plant.survival_interact();s.advance(0.7);s.ui.refresh();await settle();await capture("world_berry_picked")
 # Real fractured tree support, rendered after the real growth threshold (QA clock jump only).
 var chosen:Dictionary={};var nearest:=INF
 for r in world._all_trees_data:
  if not Catalog.eligible(str(r.id)):continue
  var pos:=Vector3(float(r.pos[0]),float(r.pos[2]),-float(r.pos[1]));var distance:=pos.distance_squared_to(origin)
  if distance<nearest:nearest=distance;chosen=r
 if not chosen.is_empty():
  var pos:=Vector3(float(chosen.pos[0]),float(chosen.pos[2]),-float(chosen.pos[1]));world._activate_dynamic_tree(chosen,pos);var tree=world._dynamic_trees.get(chosen.id)
  if is_instance_valid(tree):
   p.global_position=pos+Vector3(0,0,2);tree._voxel_trunk.request_fracture(0.65)
   var deadline:=Time.get_ticks_msec()+20000
   while not s.vegetation.stumps.has(chosen.id) and Time.get_ticks_msec()<deadline:await create_timer(0.01).timeout
   await create_timer(5.0).timeout;await settle(8);s.clock+=Catalog.FIRST_GROWTH;s.vegetation.advance(Catalog.FIRST_GROWTH,true);s.vegetation._update_stumps(p.global_position)
   if not s.vegetation.stump_nodes.is_empty():
    var fungus:Node3D=s.vegetation.stump_nodes.values()[0];var direction:Vector3= fungus.global_position-pos;direction.y=0;direction=direction.normalized()
    var cam:=Camera3D.new();game.add_child(cam);cam.global_position=pos+direction*1.4+Vector3.UP*1.35;cam.look_at(pos+Vector3.UP*0.3);cam.current=true;cam.far=100;cam.fov=60;p._hud_layer.hide();s.ui.hud_panel.hide()
    await settle();await capture("world_stump_fungi");cam.free();p._camera.current=true
 s.clock=12*3600
 s.vegetation.learn_notes()
 for dimensions in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
  root.content_scale_size=Vector2i.ZERO;root.size=dimensions;await settle()
  s.open_backpack();p._backpack_ui.tabs.current_tab=3;p._backpack_ui.resize();await settle();await capture("guide_%d"%dimensions.x)
  p._backpack_ui.tabs.current_tab=0
  p.global_position=s.shelter.global_position+Vector3(5,0,5);await physics_frame
  var fire=s.Fire.create("preview_fire",p.global_position+Vector3(1,0,0));fire.state="burning";fire.fuel=7200;s.fires=[fire];s._spawn_fire(fire);s.selected_fire=fire.id
  p.inventory_slots.fill(null);s.Items.transact(p,{},[s.Items.item("stump_fan"),s.Items.item("water")]);p._backpack_ui.focus_fire();p._backpack_ui.cook_select.select(4);p._backpack_ui.refresh_actions();p._backpack_ui.resize();await settle();var sc:Node=p._backpack_ui.cook_select
  while sc!=null and not sc is ScrollContainer:sc=sc.get_parent()
  if sc is ScrollContainer:sc.scroll_vertical=10000
  await settle();await capture("cooking_%d"%dimensions.x)
  # Structural bounds, not a substitute for visual inspection.
  var panel:Control=p._inv_root_panel
  if not root.get_visible_rect().encloses(panel.get_global_rect()):failures+=1;printerr("FAIL: panel outside viewport")
  if p._backpack_ui.buttons.cook.disabled:failures+=1;printerr("FAIL: valid cooking disabled")
  print("LAYOUT ",dimensions," panel=",panel.get_global_rect()," viewport=",root.get_visible_rect()," cook_disabled=",p._backpack_ui.buttons.cook.disabled)
  s.close_backpack()
 game.free();current_scene=null;await settle();print("VEGETATION PREVIEW COMPLETE, layout failures=",failures);quit(1 if failures else 0)
