extends SceneTree
const Trees=preload("res://scripts/props/TreeChoppable.gd")
var passes:=0
var failures:=0
var records=[]
var scene:Node3D
var cam:Camera3D
var output_dir:="user://qa"
func _initialize():call_deferred("run")
func check(ok:bool,text:String):
 if ok:passes+=1;print("PASS: ",text)
 else:failures+=1;print("FAIL: ",text)
func idle(tree):
 var until=Time.get_ticks_msec()+20000
 while is_instance_valid(tree) and tree._voxel_trunk.is_busy() and Time.get_ticks_msec()<until:await create_timer(0.003).timeout
func tree_new(sp:String,id:String):
 var tree=Trees.new();tree.species=sp;tree.tree_id=id;scene.add_child(tree);tree.set_process(false);return tree
func strike(tree):
 var r:float=Trees.SPECIES_CONFIG[tree.species].radius
 tree.hit(1,tree.to_global(Vector3(0,1.3,r)),tree.to_global(Vector3(0,1.3,3)))
 await idle(tree)
func capture(name:String):
 if DisplayServer.get_name()=="headless":return
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output_dir.path_join("visual/")+name+".png")
func verify_bark(tree,label:String):
 var trunk=tree._voxel_trunk;var bark_ok=false
 for i in trunk._mesh_instance.mesh.get_surface_count():
  var mat=trunk._mesh_instance.mesh.surface_get_material(i)
  if "bark" not in mat.resource_name.to_lower():continue
  var a=trunk._mesh_instance.mesh.surface_get_arrays(i);var colors=a[Mesh.ARRAY_COLOR];var vertices=a[Mesh.ARRAY_VERTEX]
  var source:Material
  for original in trunk._materials:
   if original!=null and original.resource_name==mat.resource_name:source=original
  bark_ok=source==mat and (mat.albedo_texture!=null or mat.albedo_color!=Color.WHITE)
  for j in vertices.size():
   if vertices[j].y>3.5:
    bark_ok=bark_ok and colors[j].is_equal_approx(Color.WHITE);break
 check(bark_ok,label+": undamaged bark retains exact authored material and original vertex colors")
func run():
 output_dir=OS.get_environment("DN_QA_OUTPUT") if not OS.get_environment("DN_QA_OUTPUT").is_empty() else "user://qa"
 DirAccess.make_dir_recursive_absolute(output_dir.path_join("visual"))
 root.size=Vector2i(1280,720);scene=Node3D.new();root.add_child(scene);current_scene=scene
 var env=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color(0.1,0.15,0.16);e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color.WHITE;e.ambient_light_energy=0.6;env.environment=e;scene.add_child(env)
 var light=DirectionalLight3D.new();scene.add_child(light);light.rotation_degrees=Vector3(-35,-25,0)
 cam=Camera3D.new();scene.add_child(cam);cam.position=Vector3(1.8,2.8,5);cam.look_at(Vector3(0,2,0));cam.current=true
 for sp in ["birch","spruce","beech","oak"]:
  Trees.felled_tree_ids.clear();Trees.damaged_tree_states.clear()
  var tree=tree_new(sp,"material_"+sp);await process_frame;await capture(sp+"_before")
  var trunk=tree._voxel_trunk;var originals=[]
  for input in trunk._inputs:originals.append(input.bark_color)
  await strike(tree);verify_bark(tree,sp+" first strike");await capture(sp+"_after")
  await strike(tree);verify_bark(tree,sp+" repeated strike")
  check(not tree._is_falling,sp+": repeated light damage retains standing tree")
  var saved=JSON.parse_string(JSON.stringify(Trees.damaged_tree_states));tree.free();await process_frame
  Trees.damaged_tree_states=saved;tree=tree_new(sp,"material_"+sp);await idle(tree)
  check(tree._voxel_trunk.export_cuts().size()>0,sp+": partial cuts survive JSON restoration")
  verify_bark(tree,sp+" loaded partial tree")
  var hits=2
  while not tree._is_falling and hits<60:
   await strike(tree);hits+=1
  check(tree._is_falling,sp+": real repeated strikes reach physical fracture")
  check(not Trees.damaged_tree_states.has(tree.tree_id),sp+": felling clears standing-damage registry")
  var saved_felled=JSON.parse_string(JSON.stringify(Trees.compact_felled_registry()));var id=tree.tree_id
  check(saved_felled.size()==1,sp+": canonical save contains one record per felled tree")
  tree.free()
  for stump in get_nodes_in_group("permanent_stumps"):stump.free()
  Trees.felled_tree_ids=saved_felled;tree=tree_new(sp,id);await idle(tree);await process_frame
  var found=false
  for stump in get_nodes_in_group("permanent_stumps"):
   var mesh=stump.get_child(0).mesh
   for i in mesh.get_surface_count():
    var mat=mesh.surface_get_material(i)
    if mat!=null and "bark" in mat.resource_name.to_lower():found=true
   stump.free()
  check(found,sp+": loaded fractured stump retains species bark material")
  records.append({"species":sp,"tool":"iron_axe","damage":1,"hits":hits,"strength":Trees.SPECIES_CONFIG[sp].hp})
  await process_frame
 # Same current algorithm/assets and strike location, old oak strength only.
 Trees.felled_tree_ids.clear();Trees.damaged_tree_states.clear();var oak=tree_new("oak","old_oak");oak._voxel_trunk.strength_hits=20;var old_hits=0
 while not oak._is_falling and old_hits<60:await strike(oak);old_hits+=1
 records.append({"species":"oak_before","tool":"iron_axe","damage":1,"hits":old_hits,"strength":20})
 check(old_hits>records[3].hits,"oak requires fewer real strikes than previous strength 20")
 var f=FileAccess.open(output_dir.path_join("chop_counts.json"),FileAccess.WRITE);f.store_string(JSON.stringify(records));f.close()
 print("CHOP COUNTS: ",JSON.stringify(records))
 oak.free()
 for stump in get_nodes_in_group("permanent_stumps"):stump.free()
 scene.queue_free();current_scene=null;await process_frame;await create_timer(0.25).timeout;print("TREE MATERIAL BALANCE SUMMARY: %d PASS, %d FAIL"%[passes,failures]);quit(1 if failures else 0)
