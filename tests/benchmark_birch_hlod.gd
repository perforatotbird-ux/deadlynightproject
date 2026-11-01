extends SceneTree
## Matched isolated render workload, NOT a full-game FPS or hardware prediction.
## --baseline selects the old chunk MultiMesh path; otherwise shipping BirchForest.
const Forest=preload("res://scripts/world/BirchForest.gd")
const Models=preload("res://scripts/core/ExternalModels.gd")
const Trees=preload("res://scripts/props/TreeChoppable.gd")
class OwnerWorld extends Node3D:
 const TreeChoppable=preload("res://scripts/props/TreeChoppable.gd")
var baseline:=false
var output:="/data/raw/birch-hlod.json"
var world:Node3D
var forest:RefCounted
var index:Dictionary={}
var hidden:Dictionary={}
var camera:Camera3D
func _initialize()->void:call_deferred("run")
func run()->void:
 for arg in OS.get_cmdline_user_args():
  if arg=="--baseline":baseline=true
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 if DisplayServer.get_name()=="headless":quit(2);return
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);root.size=Vector2i(960,540)
 world=OwnerWorld.new();root.add_child(world)
 forest=Forest.new(world)
 var chunks:Dictionary={};var records:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/vegetation_placements.json")).trees
 for record in records:
  if record.species!="birch" or record.get("tutorial",false):continue
  if not chunks.has(record.chunk):chunks[record.chunk]=[]
  chunks[record.chunk].append(record)
 var chunk:String=""
 for key in chunks:
  if chunk.is_empty() or chunks[key].size()>chunks[chunk].size():chunk=key
 var grouped:Dictionary={};var center:=Vector3.ZERO
 for record in chunks[chunk]:
  var key:=Models.tree_key("birch",record.id)
  if not grouped.has(key):grouped[key]=[]
  grouped[key].append(record);var a:Array=record.pos;center+=Vector3(a[0],a[2],-a[1])
 center/=chunks[chunk].size()
 for key in grouped:
  var mesh:Mesh=load(Models.BIRCH_ROOT+key+".res")
  if not baseline:forest.add_batch(world,key,grouped[key],mesh,index,hidden);continue
  var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=grouped[key].size()
  for i in grouped[key].size():
   var record:Dictionary=grouped[key][i];var a:Array=record.pos
   mm.set_instance_transform(i,Transform3D(Basis(Vector3.UP,deg_to_rad(record.get("yaw_deg",0.0))).scaled(Vector3.ONE*record.get("scale",1.0)),Vector3(a[0],a[2],-a[1])))
  var node:=MultiMeshInstance3D.new();node.multimesh=mm;world.add_child(node)
 camera=Camera3D.new();camera.far=4000;world.add_child(camera);camera.current=true
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);light.shadow_enabled=true;light.directional_shadow_max_distance=110;world.add_child(light)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0.25,0.34,0.44);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=0.6;world.add_child(environment)
 var report:Dictionary={"scope":"densest real birch chunk only; no terrain/gameplay; not full-game FPS","chunk":chunk,"trees":chunks[chunk].size(),"baseline":baseline,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"resolution":[960,540],"views":[]}
 for distance in [80.0,500.0]:
  camera.position=center+Vector3(0,35,distance);camera.look_at(center+Vector3(0,9,0))
  if not baseline:forest.update(camera.position,index,hidden,true)
  for warm in 4:await process_frame;await RenderingServer.frame_post_draw
  var samples:Array=[]
  for i in 6:
   var start:=Time.get_ticks_usec();await process_frame;await RenderingServer.frame_post_draw
   samples.append({"frame_ms":(Time.get_ticks_usec()-start)/1000.0,"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)})
  var near_count:=0
  for entry in index.values():
   if entry.near:near_count+=1
  report.views.append({"camera_distance":distance,"detail_trees":near_count,"samples":samples})
  root.get_texture().get_image().save_png(output.trim_suffix(".json")+"_%dm.png"%distance)
 var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("HLOD BENCHMARK ",output)
 world.free();quit()
