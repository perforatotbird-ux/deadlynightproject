extends Node3D
# Local, bounded ambient ecology. No colliders, loot, combat or survival changes.
# All scheduling uses real unpaused seconds and a private RNG, never world time.
const Bird=preload("res://scripts/atmosphere/WoodlandBird.gd")
const Meshes=preload("res://scripts/atmosphere/WoodlandMeshes.gd")
const MAX_BIRDS:=6
const MAX_INSECTS:=48
const MAX_MOTHS:=10
const MAX_VOICES:=4
const SOUNDS={"bird_1":preload("res://assets/sounds/woodland/bird_1.wav"),"bird_2":preload("res://assets/sounds/woodland/bird_2.wav"),"bird_3":preload("res://assets/sounds/woodland/bird_3.wav"),"owl":preload("res://assets/sounds/woodland/owl.wav"),"leaves":preload("res://assets/sounds/woodland/leaves.wav"),"twig":preload("res://assets/sounds/woodland/twig.wav"),"wings":preload("res://assets/sounds/woodland/wings.wav")}
var session:Node
var rng:=RandomNumberGenerator.new()
var birds:Array[Node3D]=[]
var insect_field:MultiMeshInstance3D
var moth_field:MultiMeshInstance3D
var insect_material:ShaderMaterial
var moth_material:ShaderMaterial
var voices:Array[AudioStreamPlayer3D]=[]
var cricket:AudioStreamPlayer3D
var ground_cache:Dictionary={}
var patches:Array[Vector3]=[]
var _origin:=Vector3(1e8,0,1e8)
var elapsed:=0.0
var density:=0.0
var _tick:=0.0
var _habitat_tick:=0.0
var call_cooldown:=10.0
var night_cooldown:=95.0
var scatter_cooldown:=0.0
var quiet_left:=0.0
var quiet_gain:=0.0
var pending_noise:=""
var last_sound:=""
var last_source:=Vector3.ZERO
var ground_queries:=0
var was_active:=false
var moth_centers:Array[Vector3]=[]
var _moths_initialized:=false
func _ready()->void:
 name="WoodlandLife";rng.randomize()
 insect_material=ShaderMaterial.new();insect_material.shader=preload("res://shaders/atmosphere/insect.gdshader")
 moth_material=insect_material.duplicate();moth_material.set_shader_parameter("wing_rate",18.0)
 insect_field=_field(MAX_INSECTS,false,insect_material);moth_field=_field(MAX_MOTHS,true,moth_material)
 for i in MAX_BIRDS:
  var bird:=Bird.new();bird.phase=rng.randf_range(0,TAU);add_child(bird);bird.hide();birds.append(bird)
 for i in MAX_VOICES:
  var audio:=AudioStreamPlayer3D.new();audio.bus="Ambience" if AudioServer.get_bus_index("Ambience")>=0 else "Master";audio.max_distance=65;audio.unit_size=8;audio.max_db=-9;audio.attenuation_filter_cutoff_hz=7500;add_child(audio);voices.append(audio)
 cricket=AudioStreamPlayer3D.new();var stream:AudioStreamWAV=preload("res://assets/sounds/woodland/crickets.wav").duplicate();stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=int(stream.get_length()*stream.mix_rate)
 cricket.stream=stream;cricket.bus=voices[0].bus;cricket.unit_size=6;cricket.max_distance=22;cricket.volume_db=-80;add_child(cricket)
 for i in MAX_MOTHS:moth_centers.append(Vector3.ZERO)
 call_cooldown=rng.randf_range(6,14);night_cooldown=rng.randf_range(65,115)
func _field(limit:int,moth:bool,material:Material)->MultiMeshInstance3D:
 var node:=MultiMeshInstance3D.new();var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=Meshes.insect(moth);mm.mesh.surface_set_material(0,material);mm.instance_count=limit;mm.visible_instance_count=0
 node.multimesh=mm;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.gi_mode=GeometryInstance3D.GI_MODE_DISABLED;add_child(node);return node
func allowed()->bool:
 return is_instance_valid(session) and is_instance_valid(session.player) and session.location=="forest" and session.health>0 and session.player._is_active and not session.covered()
func night()->bool:return session.daylight()<.22
func weather_activity(state:Dictionary)->float:
 return clampf(1-float(state.get("rain",0))*1.5-float(state.get("wind",0))*.35,0,1)
func advance(seconds:float,state:Dictionary,sleeping:bool=false)->void:
 if seconds<=0 or get_tree().paused:return
 if not allowed() or sleeping or session.job.get("kind")=="rest":suspend();return
 was_active=true;elapsed+=minf(seconds,.25)
 var activity:=weather_activity(state)
 density=move_toward(density,activity,minf(seconds,.25)*.45)
 scatter_cooldown=maxf(0,scatter_cooldown-seconds)
 _habitat_tick-=seconds
 if _habitat_tick<=0:
  _habitat_tick=.8;_update_habitat()
 if patches.is_empty():return
 _tick+=seconds
 if _tick>=1.0/24:
  var dt:=minf(_tick,.1);_tick=0;_update_insects(dt,state);_update_birds(dt,activity)
 if not session.dev_events_enabled:
  for audio in voices:audio.stop()
  cricket.stop();pending_noise="";quiet_left=0;quiet_gain=0;return
 _audio(seconds,state,activity)
 quiet_gain=move_toward(quiet_gain,1.0 if quiet_left>0 else 0.0,minf(seconds,.25)*.8)
func suspend()->void:
 if not was_active and insect_field.multimesh.visible_instance_count==0:return
 was_active=false;density=0;_moths_initialized=false
 insect_field.multimesh.visible_instance_count=0;moth_field.multimesh.visible_instance_count=0
 for bird in birds:bird.hide();bird.age=0
 for audio in voices:audio.stop()
 cricket.stop();quiet_left=0;quiet_gain=0;pending_noise="";call_cooldown=maxf(call_cooldown,5);night_cooldown=maxf(night_cooldown,35)
func _ground(point:Vector3)->Dictionary:
 var key:=Vector2i(floori(point.x/5),floori(point.z/5))
 if ground_cache.has(key):return ground_cache[key]
 if ground_queries>=9:return {}
 ground_queries+=1
 var q:=PhysicsRayQueryParameters3D.create(Vector3(point.x,session.player.global_position.y+35,point.z),Vector3(point.x,session.player.global_position.y-65,point.z),1);q.exclude=[session.player.get_rid()]
 var hit=session.player.get_world_3d().direct_space_state.intersect_ray(q)
 var value:Dictionary=hit if not hit.is_empty() and hit.collider.is_in_group("camp_ground") and hit.normal.y>.7 else {}
 if ground_cache.size()>=128:ground_cache.erase(ground_cache.keys()[0])
 ground_cache[key]=value;return value
func _clear(a:Vector3,b:Vector3)->bool:
 var q:=PhysicsRayQueryParameters3D.create(a,b,1|2|8);q.exclude=[session.player.get_rid()]
 return session.player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
func _update_habitat()->void:
 ground_queries=0
 if ground_cache.size()>128:ground_cache.clear()
 var pos:Vector3=session.player.global_position
 if _origin.distance_to(pos)>22:
  _origin=pos;ground_cache.clear();patches.clear()
  for bird in birds:bird.hide();bird.age=0
 if patches.size()<4:
  for i in 4:
   var a:=rng.randf_range(0,TAU);var point:=pos+Vector3(cos(a),0,sin(a))*rng.randf_range(3,11)
   var hit:=_ground(point)
   if not hit.is_empty():
    var center:Vector3=hit.position+Vector3.UP*rng.randf_range(.6,1.7)
    var q:=PhysicsShapeQueryParameters3D.new();var shape:=SphereShape3D.new();shape.radius=1.25;q.shape=shape;q.transform.origin=center;q.collision_mask=2|8
    if session.player.get_world_3d().direct_space_state.intersect_shape(q,1).is_empty():patches.append(center)
   if patches.size()>=4:break
 if density<.1:return
 var limit:=1 if night() else MAX_BIRDS
 for i in birds.size():
  var bird:Node3D=birds[i]
  if i>=limit:continue
  if not bird.visible:_spawn_bird(bird)
  elif bird.global_position.distance_to(pos)>60:bird.hide();bird.age=0
func _spawn_bird(bird:Node3D,require_hidden:bool=true)->bool:
 for attempt in 3:
  var angle:=rng.randf_range(0,TAU);var pos:Vector3=session.player.global_position+Vector3(cos(angle),0,sin(angle))*rng.randf_range(15,32)
  var hit:=_ground(pos)
  if hit.is_empty():continue
  pos=hit.position+Vector3.UP*rng.randf_range(5,11)
  if require_hidden and session.player._camera.is_position_in_frustum(pos):continue
  if not _clear(pos,pos+Vector3.UP*2):continue
  bird.configure(night());bird.animate(0,0);bird.position=pos;bird.target=pos+Vector3(rng.randf_range(-12,12),rng.randf_range(-1,2),rng.randf_range(-12,12));bird.velocity=(bird.target-pos).normalized()*3;bird.age=0;bird.visible=true;bird.scale=Vector3.ONE*(1.5 if bird.owl else 1.0);return true
 return false
func _update_birds(dt:float,activity:float)->void:
 for bird in birds:
  if not bird.visible:continue
  var matching:bool=bird.owl==night()
  if not matching or activity<.1:
   bird.animate(dt,maxf(0,bird.opacity-dt*.5))
   if bird.opacity<=0:bird.hide();bird.age=0
   continue
  var distance:float=bird.global_position.distance_to(session.player.global_position)
  var noisy:bool=session.player.velocity.length()>4 or session.player._camera_shake>.1
  if noisy and distance<23 and scatter_cooldown<=0:scatter();break
  var direction:Vector3=bird.target-bird.global_position
  if direction.length()<2 or bird.global_position.distance_to(_origin)>45:
   bird.target=_origin+Vector3(rng.randf_range(-25,25),rng.randf_range(6,13),rng.randf_range(-25,25));direction=bird.target-bird.global_position
  var speed:=7.5 if bird.startled>0 else (3.8 if bird.owl else 4.6)
  bird.velocity=bird.velocity.lerp(direction.normalized()*speed,clampf(dt*1.4,0,1))
  var next:Vector3=bird.global_position+bird.velocity*dt
  if not _clear(bird.global_position,bird.global_position+bird.velocity.normalized()*2):bird.target=bird.global_position+Vector3(0,4,0)-bird.velocity.normalized()*5
  else:bird.global_position=next
  if bird.velocity.length()>.1 and absf(bird.velocity.normalized().dot(Vector3.UP))<.98:bird.look_at(bird.global_position+bird.velocity,Vector3.UP)
  bird.animate(dt,minf(1,bird.age/2)*density)
func scatter()->void:
 scatter_cooldown=12
 for bird in birds:
  if not bird.visible:continue
  bird.startled=4;bird.target=bird.global_position+(bird.global_position-session.player.global_position).normalized()*18+Vector3.UP*5
 if session.dev_events_enabled:
  for bird in birds:
   if bird.visible:play_sound("wings",bird.global_position,-20);break
func _update_insects(dt:float,_state:Dictionary)->void:
 var temp:float=session.air_temperature()
 var day_count:=int(MAX_INSECTS*density) if not night() and temp>7 else 0
 var lamp:bool=night() and session.player.active_hotbar_slot==1 and session.player._is_lantern_on
 var moth_count:=int(MAX_MOTHS*density) if night() and temp>3 else 0
 insect_field.multimesh.visible_instance_count=day_count;moth_field.multimesh.visible_instance_count=moth_count
 for mat in [insect_material,moth_material]:mat.set_shader_parameter("life_time",elapsed);mat.set_shader_parameter("opacity",density*.85);mat.set_shader_parameter("observer",session.player._camera.global_position)
 for i in day_count:
  var anchor:Vector3=patches[i%patches.size()];var phase:=elapsed*(.55+float(i%7)*.075)+i*2.3
  var pos:=anchor+Vector3(sin(phase)*1.1,sin(phase*1.7)*.35,cos(phase*.83)*.9)
  var size:=.18 if i%4 else .65
  insect_field.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,phase).scaled(Vector3.ONE*size),pos))
 if moth_count==0:_moths_initialized=false
 for i in moth_count:
  var anchor:Vector3=session.player._camera.global_position-session.player._camera.global_basis.z*1.7 if lamp else patches[i%patches.size()]
  moth_centers[i]=anchor if not _moths_initialized else moth_centers[i].lerp(anchor,clampf(dt*2.4,0,1))
  var phase:=elapsed*(1.1+float(i%4)*.15)+i*2.4
  var pos:=moth_centers[i]+Vector3(sin(phase)*(.5 if lamp else 1.4),cos(phase*1.7)*.3,cos(phase)*.4)
  moth_field.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,phase).scaled(Vector3.ONE*.65),pos))
 _moths_initialized=moth_count>0
func _audio(seconds:float,state:Dictionary,activity:float)->void:
 var dark:=night()
 quiet_left=maxf(0,quiet_left-seconds)
 var insects:bool=dark and session.air_temperature()>3.5 and activity>.25
 if insects and not cricket.playing:cricket.play()
 if not insects:cricket.stop()
 cricket.global_position=patches[0]
 cricket.volume_db=-26+linear_to_db(maxf(.001,activity))-18*quiet_gain
 if activity<=.25:
  pending_noise="";quiet_left=0;call_cooldown=maxf(call_cooldown,5);night_cooldown=maxf(night_cooldown,35);return
 call_cooldown-=seconds;night_cooldown-=seconds
 var busy:bool=(is_instance_valid(session.sky_events) and session.sky_events.busy()) or (is_instance_valid(session.atmosphere) and not session.atmosphere.event.is_empty())
 if busy:return
 if pending_noise!="" and quiet_left<=0:
  var point:=_hidden_sound_position()
  if point!=Vector3.INF:play_sound(pending_noise,point,-20)
  pending_noise="";night_cooldown=rng.randf_range(70,140);call_cooldown=maxf(call_cooldown,10);return
 if activity>.25 and call_cooldown<=0 and quiet_left<=0:
  var pos:=_hidden_sound_position() if dark else _bird_source()
  if pos!=Vector3.INF:play_sound("owl" if dark else "bird_%d"%rng.randi_range(1,3),pos,-18 if dark else -22)
  call_cooldown=rng.randf_range(32,70) if dark else rng.randf_range(7,19)
 if dark and night_cooldown<=0 and pending_noise=="":
  pending_noise="twig" if rng.randf()<.5 else "leaves";quiet_left=rng.randf_range(3.5,6.5)
 if not dark:pending_noise="";quiet_left=0;night_cooldown=maxf(night_cooldown,40)
func _bird_source()->Vector3:
 for bird in birds:
  if bird.visible and bird.age>2:return bird.global_position
 return Vector3.INF
func _hidden_sound_position()->Vector3:
 for i in 4:
  var a:=rng.randf_range(0,TAU);var pos:Vector3=session.player.global_position+Vector3(cos(a),0,sin(a))*rng.randf_range(15,30)
  var hit:=_ground(pos)
  if hit.is_empty():continue
  pos=hit.position+Vector3.UP*1.0
  if session.player._camera.is_position_in_frustum(pos):continue
  if _clear(session.player._camera.global_position,pos):return pos
 return Vector3.INF
func play_sound(kind:String,point:Vector3,volume:float)->bool:
 if not SOUNDS.has(kind) or not allowed():return false
 for audio in voices:
  if audio.playing:continue
  audio.stream=SOUNDS[kind];audio.global_position=point;audio.volume_db=clampf(volume,-45,-12);audio.pitch_scale=rng.randf_range(.95,1.05);audio.play();last_sound=kind;last_source=point;return true
 return false
