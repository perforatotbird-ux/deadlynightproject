extends Node3D
# Rare events use real unpaused seconds. World clock only positions the sphere.
var session:Node
var sky:Node3D
var rng:=RandomNumberGenerator.new()
var meteor_cooldown:=220.0
var anomaly_cooldown:=850.0
var lightning_cooldown:=35.0
var event:Dictionary={}
var flash:=0.0
var flash_age:=-1.0
var thunder:Dictionary={}
var players:Array[AudioStreamPlayer3D]=[]
func _ready() -> void:
 name="SkyEvents";rng.randomize()
 meteor_cooldown=rng.randf_range(150,420);anomaly_cooldown=rng.randf_range(600,1500);lightning_cooldown=rng.randf_range(25,55)
 for i in 2:
  var audio:=AudioStreamPlayer3D.new();audio.stream=preload("res://assets/sounds/weather/thunder_01.ogg")
  audio.bus="Ambience" if AudioServer.get_bus_index("Ambience")>=0 else "Master"
  audio.attenuation_filter_cutoff_hz=6500;audio.attenuation_filter_db=-12
  audio.unit_size=800;audio.max_distance=6000;add_child(audio);players.append(audio)
func busy() -> bool:
 if not event.is_empty() or flash_age>=0 or not thunder.is_empty():return true
 for audio in players:
  if audio.playing:return true
 return false
func suspend() -> void:
 event={};thunder={};flash=0;flash_age=-1
 meteor_cooldown=maxf(30,meteor_cooldown);anomaly_cooldown=maxf(60,anomaly_cooldown);lightning_cooldown=maxf(25,lightning_cooldown)
 for audio in players:audio.stop()
 _uniform("meteor_age",-1.0);_uniform("anomaly_strength",0.0);_uniform("bolt_strength",0.0);_uniform("flash",0.0)
 if is_instance_valid(sky):sky.apply_flash(0.0)
func advance(seconds:float,state:Dictionary,sleeping:bool=false) -> void:
 if seconds<=0 or get_tree().paused:return
 if sleeping or session.health<=0:suspend();return
 if session.location=="mine" and not event.is_empty():
  event={};_uniform("meteor_age",-1.0);_uniform("anomaly_strength",0.0)
 meteor_cooldown=maxf(0,meteor_cooldown-seconds);anomaly_cooldown=maxf(0,anomaly_cooldown-seconds);lightning_cooldown=maxf(0,lightning_cooldown-seconds)
 var sm=load("res://scripts/core/SettingsManager.gd").get_instance()
 var reduced:bool=sm.get_setting("graphics","reduced_lightning",false)
 if flash_age>=0:
  flash_age+=seconds
  flash=exp(-flash_age*9.0)*(0.16 if reduced else 0.65)
  _uniform("bolt_strength",exp(-flash_age*18.0)*(0.15 if reduced else 0.8))
  if flash_age>1.1:flash_age=-1;flash=0;_uniform("bolt_strength",0.0)
 _uniform("flash",flash)
 if is_instance_valid(sky):sky.apply_flash(flash)
 if not thunder.is_empty():
  thunder["delay"]=float(thunder.delay)-seconds
  if thunder.delay<=0:
   var audio:AudioStreamPlayer3D=players[0] if not players[0].playing else players[1]
   audio.global_position=_v3(thunder.get("position",_arr(session.player.global_position+_v3(thunder.direction)*float(thunder.distance))))
   audio.stream=preload("res://assets/sounds/weather/thunder_01.ogg") if int(thunder.get("variant",0))==0 else preload("res://assets/sounds/weather/thunder_02.ogg")
   audio.pitch_scale=float(thunder.pitch)
   var volume:float=sm.get_setting("audio","thunder_volume",0.8)
   audio.volume_db=(-25.0 if session.location=="mine" else (-11.0 if session.covered() else 0.0))+linear_to_db(maxf(0.0001,volume))
   audio.play();thunder={}
 for audio in players:
  # Re-evaluate shelter attenuation while an existing roll is playing.
  if audio.playing:audio.attenuation_filter_cutoff_hz=1800 if session.covered() else 6500
  if audio.playing:audio.volume_db=(-25.0 if session.location=="mine" else (-11.0 if session.covered() else 0.0))+linear_to_db(maxf(0.0001,float(sm.get_setting("audio","thunder_volume",0.8))))
 if not event.is_empty():
  event["elapsed"]=float(event.elapsed)+seconds
  var t:=clampf(float(event.elapsed)/float(event.duration),0,1)
  if event.kind=="meteor":_uniform("meteor_age",float(event.elapsed))
  else:
   var start:=_v3(event.start);var end:=_v3(event.end)
   # C1 smooth bounded path, approximately 0.1-0.5 deg/s; no jitter.
   var c1:=_v3(event.get("control1",event.start));var c2:=_v3(event.get("control2",event.end))
   var u:=smoothstep(0,1,t)
   var dir:Vector3=(pow(1-u,3)*start+3*pow(1-u,2)*u*c1+3*(1-u)*u*u*c2+u*u*u*end).normalized()
   _uniform("anomaly_dir",dir);_uniform("anomaly_strength",smoothstep(0,4,float(event.elapsed))*smoothstep(0,5,float(event.duration)-float(event.elapsed))*0.7)
  if t>=1:
   event={};_uniform("meteor_age",-1.0);_uniform("anomaly_strength",0.0)
  return
 var ground_busy:bool=is_instance_valid(session.atmosphere) and not session.atmosphere.event.is_empty()
 if ground_busy or busy():return
 if float(state.storm)>0.8 and lightning_cooldown<=0:
  start_lightning();return
 if session.location!="forest":return
 if session.daylight()>0.12 or float(state.cloud)>0.55:return
 if meteor_cooldown<=0:start_meteor();return
 if anomaly_cooldown<=0:
  if rng.randf()<0.35:start_anomaly()
  else:anomaly_cooldown=rng.randf_range(600,1500)
func _random_direction() -> Vector3:
 var az:=rng.randf_range(-PI,PI);var height:=rng.randf_range(0.35,1.15)
 return Vector3(cos(az)*cos(height),sin(height),sin(az)*cos(height))
func start_meteor() -> void:
 var start:=_random_direction();var end:Vector3=(start+Vector3(rng.randf_range(-0.2,0.2),-0.16,rng.randf_range(-0.2,0.2))).normalized()
 var duration:=rng.randf_range(0.35,0.75)
 event={"kind":"meteor","elapsed":0.0,"duration":duration}
 _uniform("meteor_start",start);_uniform("meteor_end",end);_uniform("meteor_age",0.0);_uniform("meteor_duration",duration)
 meteor_cooldown=rng.randf_range(150,420)
func start_anomaly() -> void:
 var start:=_random_direction();var end:Vector3=(start+Vector3(rng.randf_range(-0.1,0.1),0.05,rng.randf_range(-0.1,0.1))).normalized()
 event={"kind":"anomaly","start":_arr(start),"end":_arr(end),"elapsed":0.0,"duration":rng.randf_range(25,45),"color":rng.randi_range(0,3)}
 event["control1"]=_arr((start.lerp(end,0.3)+Vector3(0.025,0.02,-0.025)).normalized())
 event["control2"]=_arr((start.lerp(end,0.7)+Vector3(-0.025,-0.01,0.025)).normalized())
 _apply_anomaly_color();anomaly_cooldown=rng.randf_range(600,1500)
func _apply_anomaly_color() -> void:
 var colors:=[Vector3(0.4,0.57,0.75),Vector3(0.7,0.49,0.25),Vector3(0.35,0.59,0.56),Vector3(0.56,0.43,0.65)]
 _uniform("anomaly_color",colors[clampi(int(event.get("color",0)),0,3)])
func start_lightning() -> void:
 lightning_cooldown=rng.randf_range(25,60);flash_age=0;flash=0
 var az:=rng.randf_range(-PI,PI);var dir:=Vector3(cos(az),0,sin(az))
 var points:=PackedVector3Array()
 for i in 9:
  var height:=lerpf(0.7,0.06,float(i)/8)
  points.append((dir+Vector3(rng.randf_range(-0.018,0.018),height,rng.randf_range(-0.018,0.018))).normalized())
 _uniform("bolt_points",points)
 var branch:=PackedVector3Array()
 for i in 5:
  branch.append((points[3]+Vector3(0.015*i,-0.022*i,0.006*i)).normalized())
 _uniform("branch_points",branch)
 # Some events illuminate clouds without showing an exposed bolt.
 if rng.randf()<0.45:
  _uniform("branch_points",PackedVector3Array([Vector3.DOWN,Vector3.DOWN,Vector3.DOWN,Vector3.DOWN,Vector3.DOWN]))
  _uniform("bolt_points",PackedVector3Array([Vector3.DOWN,Vector3.DOWN,Vector3.DOWN,Vector3.DOWN,Vector3.DOWN,Vector3.DOWN,Vector3.DOWN,Vector3.DOWN,Vector3.DOWN]))
 var distance:=rng.randf_range(700,2400)
 thunder={"delay":distance/343.0,"distance":distance,"direction":_arr(dir),"pitch":rng.randf_range(0.84,1.08),"variant":rng.randi_range(0,1),"position":_arr(session.player.global_position+dir*distance)}
func _uniform(key:String,value:Variant) -> void:
 if is_instance_valid(sky) and sky.material!=null:sky.material.set_shader_parameter(key,value)
func export_state() -> Dictionary:
 return {"rng_state":str(rng.state),"meteor_cooldown":meteor_cooldown,"anomaly_cooldown":anomaly_cooldown,"lightning_cooldown":maxf(25,lightning_cooldown),"event":event.duplicate(true) if event.get("kind")=="anomaly" else {}}
func import_state(data:Dictionary) -> void:
 suspend()
 if data.has("rng_state"):rng.state=int(data.rng_state)
 meteor_cooldown=maxf(30,float(data.get("meteor_cooldown",220)));anomaly_cooldown=maxf(60,float(data.get("anomaly_cooldown",850)));lightning_cooldown=maxf(25,float(data.get("lightning_cooldown",35)))
 var saved:Dictionary=data.get("event",{})
 if session.location=="forest" and saved.get("kind")=="anomaly" and saved.has("start") and saved.has("end"):
  event=saved.duplicate(true);_apply_anomaly_color()
static func _arr(v:Vector3) -> Array:return [v.x,v.y,v.z]
static func _v3(a:Array) -> Vector3:return Vector3(a[0],a[1],a[2]) if a.size()==3 else Vector3.UP
