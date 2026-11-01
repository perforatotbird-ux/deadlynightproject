extends SceneTree
const Session=preload("res://scripts/survival/SurvivalWorld.gd")
var passes:=0
var failures:=0
var scene:Node3D
var p:Node3D
var s:Node
var d:Node3D
var graphical:=false
var out:="/data/atmosphere-previews"
func _initialize() -> void:call_deferred("run")
func check(ok: bool,text: String) -> void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func settle(frames: int=3) -> void:
 for i in frames:await process_frame
func floor_or_wall(size: Vector3,pos: Vector3,color: Color,ground: bool=false) -> StaticBody3D:
 var body:=StaticBody3D.new();body.position=pos
 if ground:body.add_to_group("camp_ground")
 var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;col.shape=shape;body.add_child(col)
 var mesh:=MeshInstance3D.new();var cube:=BoxMesh.new();cube.size=size;mesh.mesh=cube
 var mat:=StandardMaterial3D.new();mat.albedo_color=color;mesh.material_override=mat;body.add_child(mesh);scene.add_child(body);return body
func night() -> void:s.clock=2*86400+23*3600;s.weather="clear";s.weather_until=s.clock+100000;s._update_lighting()
func start(kind: String) -> bool:
 for i in 8:
  if d.try_start_event(kind,false):return true
 return false
func capture(name: String) -> void:
 if not graphical:return
 await settle();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out.path_join(name+".png"))
func frame_visuals() -> void:
 var center:=Vector3.ZERO
 for v in d.visuals:center+=v.global_position+(Vector3.UP*1.8 if v.kind!="orb" else Vector3.ZERO)
 center/=d.visuals.size()
 p._camera.look_at(center,Vector3.UP)
func run() -> void:
 graphical=DisplayServer.get_name()!="headless";root.size=Vector2i(1280,720)
 if graphical:DirAccess.make_dir_recursive_absolute(out)
 scene=Node3D.new();scene.name="MapViewer";root.add_child(scene);current_scene=scene
 floor_or_wall(Vector3(220,1,220),Vector3(0,-0.5,0),Color(0.09,0.13,0.1),true)
 var env:=WorldEnvironment.new();var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(0.016,0.025,0.036)
 environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color(0.12,0.18,0.23);environment.ambient_light_energy=0.25
 environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.environment=environment;scene.add_child(env)
 # Sparse physical trunks exercise candidate rejection and ground/collision masks.
 for x in [-16,-8,8,16]:
  for z in [-24,-14,-4,6,16]:
   floor_or_wall(Vector3(0.45,8,0.45),Vector3(x,4,z),Color(0.10,0.13,0.12))
 p=load("res://scenes/player/Player.tscn").instantiate();scene.add_child(p);p.set_active(true);p.set_physics_process(false);p.position=Vector3(0,0.1,0)
 s=Session.new();scene.add_child(s);s.set_process(false);d=s.atmosphere;d.rng.seed=891733;s.shelter.position=Vector3(85,0.08,85)
 await physics_frame;await settle();night()
 # Remove UI only from graphical captures; actual player camera and physics remain.
 if graphical:p._hud_layer.hide();s.ui.hide()
 d.first_watcher_day=2;s.clock=23*3600
 check(not d.watcher_allowed() and not d.try_start_event("eyes",false) and not d.try_start_event("crossing",false),"watcher never appears on first day")
 night()
 var health:float=s.health;var mass:float=p.backpack_weight
 var ignition_rng:String=str(s.rng.state)
 check(start("eyes"),"night eyes event plans on real ground")
 check(d.visuals.size()==1,"one apparition maximum")
 d.advance(3);check(d.visuals[0].opacity>0.8,"eyes fade in gradually")
 check(d.visuals[0].cores.size()==2 and d.visuals[0].halos.size()==2,"two emissive eyes with soft halos")
 check(not d.visuals[0].core_material.no_depth_test and not d.visuals[0].halo_material.no_depth_test,"eyes use depth testing, not x-ray")
 check(d.visuals[0].find_children("*","CollisionObject3D",true,false).is_empty(),"apparition has no contact collider")
 check(d.visuals[0].local_light==null,"eyes do not cast a costly point light")
 frame_visuals();await capture("01_distant_eyes")
 var state:Dictionary=JSON.parse_string(JSON.stringify(d.export_state()));var old_pos:Vector3=d.visuals[0].global_position
 d.import_state(state);check(not d.event.is_empty() and d.visuals[0].global_position.distance_to(old_pos)<0.01,"JSON restores active eyes position and elapsed time")
 check(str(s.rng.state)==ignition_rng,"atmosphere RNG cannot reroll weather or ignition")
 var expected:float=d.rng.randf();d.import_state(state);check(is_equal_approx(d.rng.randf(),expected),"private RNG sequence survives JSON")
 # Geometry fully between the actual camera and the eyes must occlude them.
 var target:Vector3=d.visuals[0].global_position+Vector3.UP*2.47
 var midpoint:Vector3=(p._camera.global_position+target)*0.5
 var wall:=floor_or_wall(Vector3(12,12,0.4),midpoint,Color(0.055,0.065,0.06))
 wall.look_at(Vector3(target.x,midpoint.y,target.z),Vector3.UP)
 await physics_frame
 check(not d._seen(target),"opaque wall blocks visibility test for glowing eyes")
 await capture("02_wall_occludes_eyes")
 wall.free();await physics_frame
 # An approaching player never reaches a solid creature or attack trigger.
 p.global_position=d.visuals[0].global_position+Vector3(0,0,4);d.advance(0.25)
 check(d._fading,"approach starts a soft withdrawal instead of contact")
 d.advance(2);check(d.event.is_empty() and d.visuals.is_empty(),"withdrawal cleans visual nodes")
 p.position=Vector3(0,0.1,0);p._camera.rotation=Vector3.ZERO
 check(start("orbs"),"orb event plans smooth random paths")
 check(d.visuals.size()>=1 and d.visuals.size()<=3,"one to three orbs, bounded workload")
 d.advance(3);frame_visuals();await capture("03_wandering_orbs")
 var curve:Curve3D=d._curves[0];var previous:=curve.sample_baked(0);var varied:=false;var clear:=true;var smooth:=true
 for i in 101:
  var point:=curve.sample_baked(curve.get_baked_length()*i/100.0,true)
  if absf(point.y-previous.y)>0.001:varied=true
  if point.distance_to(previous)>1:smooth=false
  if point.y<0.5 or not d._segment_clear(previous,point):clear=false
  previous=point
 check(varied and smooth,"orb follows a continuous, vertically varied curve")
 check(clear,"planned orb path stays above ground and outside obstacles")
 check(not d.visuals[0].local_light.shadow_enabled and d.visuals[0].local_light.omni_range<2,"orb light stays local and shadow-free")
 var before:Vector3=d.visuals[0].global_position;d.advance(0.1)
 check(d.visuals[0].global_position.distance_to(before)<0.25,"orb never teleports between normal frames")
 state=JSON.parse_string(JSON.stringify(d.export_state()));old_pos=d.visuals[0].global_position
 d.import_state(state)
 check(not d.event.is_empty() and d.visuals[0].global_position.distance_to(old_pos)<0.01,"orb trajectory resumes exactly after save/load")
 var time_before:float=d.event.get("elapsed",0);paused=true;d.advance(5);paused=false
 check(is_equal_approx(float(d.event.get("elapsed",0)),time_before),"pause freezes atmospheric motion")
 var orb_count:int=d.visuals.size()
 p.global_position=d.visuals[0].global_position+Vector3(0,0,3.5);d.advance(0.001)
 check(d.visuals.size()<orb_count,"orb bursts or vanishes when approached closer than four metres")
 p.position=Vector3(0,0.1,0)
 d.advance(3,true)
 check(d.event.is_empty() and d.cooldown>=30,"sleep clears visuals and prevents wake-up event backlog")
 s.clock=2*86400+12*3600
 check(not d.try_start_event("eyes",false) and not d.try_start_event("orbs",false),"no glowing eyes or orbs in daylight")
 check(start("crossing"),"rare distant silhouette remains possible in daytime")
 d.advance(3)
 check(not d.visuals[0].cores[0].visible,"daytime silhouette eyes are not glowing")
 d.finish_event();night()
 # Visible candidate rejection is deterministic even if the camera watches everything.
 var hidden_hits:=0
 for i in 6:
  if d.try_start_event("eyes",true):
   var eye_pos:Vector3=d.visuals[0].global_position+Vector3.UP*2.47
   if not d._seen(eye_pos):hidden_hits+=1
   d.finish_event()
 check(hidden_hits>0,"production spawn starts offscreen or behind real cover")
 var count_before:int=scene.get_tree().get_node_count()
 for i in 20:
  start("orbs");d.finish_event()
 check(scene.get_tree().get_node_count()==count_before,"repeated events do not leak scene nodes")
 var snapshot:Dictionary=d.export_state();d.cooldown=17;s.location="mine";d.advance(1)
 check(d.visuals.is_empty() and not d.try_start_event("eyes",false),"mine never spawns forest apparitions")
 s.location="forest";d.import_state(snapshot)
 check(s.health==health and p.backpack_weight==mass,"atmosphere never damages player or consumes items")
 # Parent session persistence includes the independent atmosphere state.
 var saved_session:Dictionary=JSON.parse_string(JSON.stringify(s.export_state()));d.cooldown=1;s.import_state(saved_session)
 check(is_equal_approx(d.cooldown,float(saved_session["atmosphere"]["cooldown"])),"SurvivalWorld persists event cooldown")
 check(d.get_script().get_source_code().find("begin_attack")==-1,"director has no combat entry point")
 print("ATMOSPHERE SUMMARY: %d PASS, %d FAIL" % [passes,failures])
 scene.free();current_scene=null;await settle();quit(1 if failures else 0)
