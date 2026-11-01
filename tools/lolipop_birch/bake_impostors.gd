extends SceneTree
## Eight azimuths, unlit albedo + alpha; no sun, ground or shadows baked into atlas.
const DIR="res://assets/models/external/lolipop/"
func _initialize()->void:call_deferred("run")
func run()->void:
 var viewport:=SubViewport.new();viewport.size=Vector2i(512,512);viewport.transparent_bg=true;viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=24;camera.near=0.1;camera.far=100;viewport.add_child(camera);camera.current=true
 for variant in 5:
  var tree:Node3D=load(DIR+"birch_%d.tscn"%variant).instantiate();viewport.add_child(tree)
  var mesh:MeshInstance3D=tree.get_child(0)
  mesh.lod_bias=1000.0 # Always bake authored LOD0, irrespective of viewport pixel error.
  for surface in mesh.mesh.get_surface_count():
   var mat:StandardMaterial3D=mesh.mesh.surface_get_material(surface).duplicate()
   mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.normal_enabled=false
   mesh.set_surface_override_material(surface,mat)
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var atlas:=Image.create(2048,256,false,Image.FORMAT_RGBA8)
  for view in 8:
   var angle:=TAU*view/8.0;camera.position=Vector3(sin(angle)*35,9,cos(angle)*35);camera.look_at(Vector3(0,9,0))
   for warm in 3:await process_frame;await RenderingServer.frame_post_draw
   var image:=viewport.get_texture().get_image();image.convert(Image.FORMAT_RGBA8);image.resize(256,256,Image.INTERPOLATE_LANCZOS)
   atlas.blit_rect(image,Rect2i(0,0,256,256),Vector2i(view*256,0))
  assert(atlas.save_png(DIR+"birch_%d_impostor.png"%variant)==OK)
  tree.free();print("IMPOSTOR baked ",variant)
 viewport.free();quit()
