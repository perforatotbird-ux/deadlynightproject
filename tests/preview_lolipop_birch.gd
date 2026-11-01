extends SceneTree
const Models=preload("res://scripts/core/ExternalModels.gd")
const Trees=preload("res://scripts/props/TreeChoppable.gd")
var stage:Node3D
var camera:Camera3D
var out:String
func _initialize() -> void:call_deferred("run")
func capture(label:String) -> void:
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out.path_join(label+".png"))
 print("CAPTURE ",label)
func run() -> void:
 out=OS.get_environment("DN_QA_OUTPUT");if out.is_empty():out="user://lolipop_preview"
 DirAccess.make_dir_recursive_absolute(out)
 root.size=Vector2i(1800,650)
 stage=Node3D.new();root.add_child(stage);current_scene=stage
 var env:=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0.15,0.21,0.25)
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(0.86,0.92,1.0);env.environment.ambient_light_energy=0.65
 stage.add_child(env)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-42,-28,0);sun.light_energy=0.9;sun.shadow_enabled=true;stage.add_child(sun)
 var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(180,180);ground.mesh=plane
 var gm:=StandardMaterial3D.new();gm.albedo_color=Color(0.19,0.23,0.15);gm.roughness=1;ground.material_override=gm;ground.position.y=-0.02;stage.add_child(ground)
 camera=Camera3D.new();stage.add_child(camera);camera.current=true
 var gallery:=Node3D.new();stage.add_child(gallery)
 for variant in 5:
  var tree:Node3D=load(Models.BIRCH_ROOT+"birch_%d.tscn"%variant).instantiate();gallery.add_child(tree);tree.position.x=(variant-2)*12
  var label:=Label3D.new();label.text="LOLIPOP %d"%(variant+1);label.position=Vector3(tree.position.x,0.6,2);label.font_size=56;label.pixel_size=0.012;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;gallery.add_child(label)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=24
 camera.position=Vector3(0,13,55);camera.look_at(Vector3(0,9,0));await capture("gallery")
 root.size=Vector2i(1600,900)
 gallery.free()
 # Fixed camera directions on each freshly loaded exported variant.
 for variant in (0 if OS.get_cmdline_user_args().has("--cuts-only") else 5):
  var model:Node3D=load(Models.BIRCH_ROOT+"birch_%d.tscn"%variant).instantiate();stage.add_child(model)
  var directions={"front":Vector3(0,0,1),"back":Vector3(0,0,-1),"left":Vector3(-1,0,0),"right":Vector3(1,0,0),"perspective":Vector3(0.6,0.15,1).normalized(),"top":Vector3(0,1,0.001).normalized()}
  camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=22
  for view in directions:
   camera.position=Vector3(0,9,0)+directions[view]*35;camera.look_at(Vector3(0,9,0));await capture("variant_%d_%s"%[variant,view])
  camera.projection=Camera3D.PROJECTION_PERSPECTIVE
  model.free()
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 # First-hit / fracture evidence for every variant (especially forked bases).
 for variant in 5:
  Trees.felled_tree_ids.clear();Trees.damaged_tree_states.clear()
  var id:=""
  for i in 1000:
   if Models.birch_variant("preview_%d"%i)==variant:id="preview_%d"%i;break
  var tree:=Trees.new();tree.tree_id=id;stage.add_child(tree);tree.set_process(false)
  await physics_frame;await physics_frame
  var ray:=PhysicsRayQueryParameters3D.create(Vector3(0,1.3,5),Vector3(0,1.3,-5),2)
  var hit:=root.world_3d.direct_space_state.intersect_ray(ray)
  camera.position=Vector3(2.4,2.5,4.4);camera.look_at(Vector3(0,1.3,0))
  await capture("variant_%d_trunk_before"%variant)
  if not hit.is_empty():
   var point:Vector3=hit.position
   for i in 2:
    tree.hit(1,point,Vector3(0,1.3,5))
    while tree._voxel_trunk.is_busy():await create_timer(0.005).timeout
   await capture("variant_%d_trunk_cut"%variant)
   for i in 40:
    if tree._is_falling:break
    tree.hit(1,point,Vector3(0,1.3,5))
    while tree._voxel_trunk.is_busy():await create_timer(0.005).timeout
   tree._process(0.5);await capture("variant_%d_fracture"%variant)
   if tree._fall_pivot:tree._fall_pivot.hide()
   camera.position=Vector3(2.4,3.4,3);camera.look_at(Vector3(0,0.9,0));await capture("variant_%d_stump"%variant)
  tree.free()
  for stump in get_nodes_in_group("permanent_stumps"):stump.free()
 stage.free();current_scene=null;await process_frame;quit()
