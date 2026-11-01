extends Node3D
# A bounded, non-combat visual director. Timers are REAL unpaused seconds,
# never accelerated world hours; it has its own RNG, separate from ignition/weather.
const Visual=preload("res://scripts/atmosphere/NightVisual.gd")
const ORB_APPROACH_DISTANCE:=4.0
const MIN_DISTANCE:=14.0
const MAX_DISTANCE:=90.0
const MAX_ORBS:=3
const COOLDOWN_MIN:=65.0
const COOLDOWN_MAX:=135.0
const FADE_SECONDS:=1.8
var session:Node
var cooldown:=80.0
var rng:=RandomNumberGenerator.new()
var first_watcher_day:=2
var last_kind:=""
var last_dark:=false
var event:Dictionary={}
var visuals:Array[Node3D]=[]
var _curves:Array[Curve3D]=[]
var _safety_tick:=0.0
var _fading:=false
var _fade_left:=0.0
var rejected_candidates:=0

func _ready() -> void:
 name="AtmosphereDirector";rng.randomize();cooldown=rng.randf_range(70,120)
 first_watcher_day=rng.randi_range(2,3)
 last_dark=is_dark()
func is_dark() -> bool:
 return session!=null and session.daylight()<0.22
func watcher_allowed() -> bool:
 return is_instance_valid(session) and session.clock>=float(first_watcher_day-1)*86400.0
func allowed() -> bool:
 return is_instance_valid(session) and is_instance_valid(session.player) and session.location=="forest" and session.player._is_active and session.health>0
func advance(seconds: float, sleeping: bool=false) -> void:
 if seconds<=0 or get_tree().paused:return
 if not allowed():
  if session.location!="forest" or session.health<=0:suspend()
  return
 if sleeping or session.job.get("kind")=="rest":suspend();return
 var dark:=is_dark()
 if dark!=last_dark:
  if not dark and event.get("kind","") in ["eyes","orbs"]:_begin_fade()
  if dark and event.is_empty():cooldown=minf(cooldown,rng.randf_range(18,35))
  last_dark=dark
 if event.is_empty():
  if is_instance_valid(session.sky_events) and session.sky_events.busy():return
  cooldown=maxf(0,cooldown-seconds)
  if cooldown<=0:
   var kind:="crossing"
   if dark:
    kind="orbs" if rng.randf()<0.38 else "eyes"
    if kind==last_kind and rng.randf()<0.65:kind="eyes" if kind=="orbs" else "orbs"
   if kind!="orbs" and not watcher_allowed():
    if dark:kind="orbs"
    else:cooldown=rng.randf_range(20,35);return
   if not try_start_event(kind):cooldown=rng.randf_range(20,35)
  return
 event["elapsed"]=float(event["elapsed"])+seconds
 if _fading:_fade_left=maxf(0,_fade_left-seconds)
 _safety_tick-=seconds
 var check_safety:=_safety_tick<=0
 if check_safety:_safety_tick=0.2
 var t:=clampf(float(event["elapsed"])/float(event["duration"]),0,1)
 var envelope:=minf(smoothstep(0,FADE_SECONDS,float(event["elapsed"])),smoothstep(0,FADE_SECONDS,float(event["duration"])-float(event["elapsed"])))
 if _fading:envelope=minf(envelope,_fade_left/FADE_SECONDS)
 var camera:Camera3D=session.player._camera
 for i in range(visuals.size()-1,-1,-1):
  var node:=visuals[i];var curve:=_curves[i]
  if event["kind"]=="orbs" and session.player.global_position.distance_to(node.global_position)<ORB_APPROACH_DISTANCE:
   if rng.randf()<0.5:_orb_burst(node.global_position)
   node.free();visuals.remove_at(i);_curves.remove_at(i);event.paths.remove_at(i)
   continue
  var next:=curve.sample_baked(curve.get_baked_length()*t,true)
  if check_safety:
   var distance:float=session.player.global_position.distance_to(next)
   if (event["kind"]!="orbs" and distance<MIN_DISTANCE) or distance>MAX_DISTANCE+25 or not _segment_clear(node.global_position+_height_offset(),next+_height_offset()):_begin_fade()
  if not _fading:node.global_position=next
  if event["kind"]!="orbs":
   var target:=camera.global_position;target.y=node.global_position.y
   if node.global_position.distance_to(target)>0.01:node.look_at(target,Vector3.UP)
  var pulse:=0.9+0.1*sin(float(event["elapsed"])*1.3+i*2.2)
  node.set_opacity(envelope*pulse,clampf((0.45-session.daylight())/0.35,0,1))
 if visuals.is_empty() or t>=1 or (_fading and _fade_left<=0):finish_event()

func _orb_burst(pos:Vector3) -> void:
 # Harmless, short flash: no damage, collider, loot or independent world timer.
 var burst:=Visual.new();burst.kind="orb";burst.tint=Color(0.75,1.0,0.85);add_child(burst);burst.global_position=pos;burst.set_opacity(1.0)
 var tween:=create_tween().set_parallel(true)
 tween.tween_property(burst,"scale",Vector3.ONE*3.5,0.35)
 tween.tween_method(func(value:float):
  if is_instance_valid(burst):burst.set_opacity(value),1.0,0.0,0.35)
 tween.chain().tween_callback(burst.queue_free)
func _height_offset() -> Vector3:
 return Vector3.ZERO if event.get("kind")=="orbs" else Vector3.UP*1.4
func _begin_fade() -> void:
 if _fading:return
 _fading=true;_fade_left=FADE_SECONDS
func suspend() -> void:
 # No catch-up sound/event queue after sleeping, entering the mine, or death.
 if not event.is_empty():last_kind=event.get("kind",last_kind)
 _clear_visuals();event={};cooldown=maxf(cooldown,30)
func finish_event() -> void:
 last_kind=event.get("kind",last_kind);_clear_visuals();event={}
 cooldown=rng.randf_range(COOLDOWN_MIN,COOLDOWN_MAX) if is_dark() else rng.randf_range(130,240)
func _clear_visuals() -> void:
 for node in visuals:
  if is_instance_valid(node):node.free()
 visuals.clear();_curves.clear();_fading=false;_fade_left=0

func try_start_event(kind: String, require_hidden: bool=true) -> bool:
 if is_instance_valid(session.sky_events) and session.sky_events.busy():return false
 if not allowed() or not event.is_empty() or kind not in ["eyes","orbs","crossing"]:return false
 if kind!="orbs" and not watcher_allowed():return false
 if kind in ["eyes","orbs"] and not is_dark():return false
 var center:Vector3=session.player.global_position
 var camp:=false
 for fire in session.fires:
  if fire.get("state")=="burning" and center.distance_to(_v3(fire["pos"]))<8:
   center=_v3(fire["pos"]);camp=true;break
 var count:=rng.randi_range(1,MAX_ORBS) if kind=="orbs" else 1
 var started:=Time.get_ticks_usec()
 for attempt in 4:
  if attempt>0 and Time.get_ticks_usec()-started>8000:return false
  var angle:=rng.randf_range(0,TAU)
  var radius:=rng.randf_range(22,38) if camp else rng.randf_range(30,46)
  if kind=="orbs":radius=rng.randf_range(32,52)
  if kind=="crossing":radius=maxf(radius,40)
  var anchor:=center+Vector3(cos(angle),0,sin(angle))*radius
  var curves:Array[Curve3D]=[]
  var paths:Array=[]
  for i in count:
   var curve:=_plan_orb(anchor+Vector3(i*1.5,0,i*0.7)) if kind=="orbs" else _plan_watcher(center,angle,radius,kind)
   if curve==null:break
   var point:=curve.sample_baked(0)
   var eye_pos:=point+(Vector3.ZERO if kind=="orbs" else Vector3.UP*2.47)
   if require_hidden and (_seen(eye_pos) or (kind!="orbs" and _seen(point+Vector3.UP))):break
   curves.append(curve);paths.append(_serialize_curve(curve))
  if curves.size()!=count:rejected_candidates+=1;continue
  var duration:=rng.randf_range(20,32) if kind=="orbs" else rng.randf_range(13,23)
  if kind=="crossing":duration=rng.randf_range(9,15)
  event={"kind":kind,"elapsed":0.0,"duration":duration,"paths":paths,"tint":rng.randf_range(0,1)}
  _curves=curves;_spawn_visuals();return true
 return false

func _ground(point: Vector3) -> Dictionary:
 var top:=point+Vector3.UP*90;var bottom:=point-Vector3.UP*140
 var q:=PhysicsRayQueryParameters3D.create(top,bottom,1);q.exclude=[session.player.get_rid()]
 var hit=session.player.get_world_3d().direct_space_state.intersect_ray(q)
 if hit.is_empty() or not hit.collider.is_in_group("camp_ground") or hit.normal.y<0.82:return {}
 return hit
func _segment_clear(a: Vector3,b: Vector3) -> bool:
 if a.distance_squared_to(b)<0.0001:return true
 var q:=PhysicsRayQueryParameters3D.create(a,b,1|2|8);q.exclude=[session.player.get_rid()]
 return session.player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
func _space_clear(point: Vector3, orb: bool) -> bool:
 if session.player.global_position.distance_to(point)<MIN_DISTANCE:return false
 var query:=PhysicsShapeQueryParameters3D.new()
 if orb:
  var shape:=SphereShape3D.new();shape.radius=0.22;query.shape=shape;query.transform.origin=point
 else:
  var shape:=CapsuleShape3D.new();shape.radius=0.25;shape.height=2.8;query.shape=shape;query.transform.origin=point+Vector3.UP*1.5
 query.collision_mask=1|2|8;query.exclude=[session.player.get_rid()]
 return session.player.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func _seen(point: Vector3) -> bool:
 var camera:Camera3D=session.player._camera
 return camera.is_position_in_frustum(point) and _segment_clear(camera.global_position,point)
func _plan_peek(center:Vector3) -> Curve3D:
 var trees:Array=[]
 for tree in get_tree().get_nodes_in_group("choppable_trees"):
  var distance:float=center.distance_to(tree.global_position)
  if distance>=MIN_DISTANCE+2 and distance<=65:trees.append(tree)
 if trees.is_empty():return null
 var tree:Node3D=trees[rng.randi_range(0,trees.size()-1)]
 var away:Vector3=(tree.global_position-center).normalized();away.y=0;away=away.normalized()
 var side:=away.cross(Vector3.UP)*(1.0 if rng.randf()>0.5 else -1.0)
 var curve:=Curve3D.new();curve.bake_interval=0.15
 for i in 13:
  var point:=tree.global_position+away*0.9+side*sin(PI*i/12.0)*1.3
  var ground:=_ground(point)
  if ground.is_empty():return null
  point=ground.position+Vector3.UP*0.05
  if not _space_clear(point,false):return null
  if i>0 and not _segment_clear(curve.get_point_position(i-1)+Vector3.UP*1.4,point+Vector3.UP*1.4):return null
  curve.add_point(point)
 return curve
func _plan_watcher(center: Vector3, angle: float, radius: float, kind: String) -> Curve3D:
 if kind=="eyes" and not get_tree().get_nodes_in_group("choppable_trees").is_empty():return _plan_peek(center)
 var curve:=Curve3D.new();curve.bake_interval=0.35
 var sweep:=rng.randf_range(0.18,0.4) if kind=="eyes" else rng.randf_range(0.4,0.65)
 var direction:=1 if rng.randf()>0.5 else -1
 for i in 13:
  var a:=angle+sweep*direction*i/12.0
  var point:=center+Vector3(cos(a),0,sin(a))*radius
  var ground:=_ground(point)
  if ground.is_empty():return null
  point=ground.position+Vector3.UP*0.05
  if not _space_clear(point,false):return null
  if i>0 and not _segment_clear(curve.get_point_position(i-1)+Vector3.UP*1.4,point+Vector3.UP*1.4):return null
  curve.add_point(point)
 return curve
func _plan_orb(anchor: Vector3) -> Curve3D:
 var knots:Array[Vector3]=[];var phase:=rng.randf_range(0,TAU)
 for i in 6:
  var point:=anchor+Vector3(sin(i*0.9+phase)*rng.randf_range(2,4),0,i*2.0-5)
  var ground:=_ground(point)
  if ground.is_empty():return null
  point=ground.position+Vector3.UP*rng.randf_range(1.3,3.4);knots.append(point)
 var curve:=Curve3D.new();curve.bake_interval=0.35
 for i in knots.size():
  var before:Vector3=knots[maxi(0,i-1)];var after:Vector3=knots[mini(knots.size()-1,i+1)]
  var tangent:Vector3=(after-before)/6.0;curve.add_point(knots[i],-tangent,tangent)
 var previous:=curve.sample_baked(0)
 for i in 41:
  var point:=curve.sample_baked(curve.get_baked_length()*i/40.0,true)
  var ground:=_ground(point)
  if ground.is_empty() or point.y<float(ground.position.y)+0.5 or not _space_clear(point,true) or not _segment_clear(previous,point):return null
  previous=point
 return curve
func _spawn_visuals() -> void:
 _fading=false;_safety_tick=0
 var orb:bool=event["kind"]=="orbs"
 for i in _curves.size():
  var node:=Visual.new();node.kind="orb" if orb else "eyes"
  node.tint=Color(0.55,0.9,0.78).lerp(Color(0.85,0.77,0.43),float(event.get("tint",0))) if orb else Color(0.96,0.73,0.38)
  add_child(node)
  var t:=clampf(float(event.get("elapsed",0))/float(event["duration"]),0,1)
  node.global_position=_curves[i].sample_baked(_curves[i].get_baked_length()*t,true);visuals.append(node)

func export_state() -> Dictionary:
 var saved:=event.duplicate(true)
 if _fading:saved={}
 return {"version":2,"first_watcher_day":first_watcher_day,"cooldown":COOLDOWN_MIN if _fading else cooldown,"rng_state":str(rng.state),"last_kind":last_kind,"last_dark":last_dark,"event":saved}
func import_state(state: Dictionary) -> void:
 _clear_visuals();event={}
 first_watcher_day=clampi(int(state.get("first_watcher_day",first_watcher_day)),2,3)
 cooldown=clampf(float(state.get("cooldown",80)),0,240);last_kind=str(state.get("last_kind",""));last_dark=bool(state.get("last_dark",is_dark()))
 if state.has("rng_state"):rng.state=int(state["rng_state"])
 var saved:Dictionary=state.get("event",{}).duplicate(true)
 if saved.is_empty() or not allowed() or saved.get("kind","") not in ["eyes","orbs","crossing"]:return
 if saved.get("kind")!="orbs" and not watcher_allowed():return
 if saved.get("kind") in ["eyes","orbs"] and not is_dark():return
 if float(saved.get("duration",0))<=0 or float(saved.get("elapsed",0))>=float(saved["duration"]):return
 var paths:Array=saved.get("paths",[])
 if paths.is_empty() or paths.size()>MAX_ORBS:return
 var restored:Array[Curve3D]=[]
 for path in paths:
  if not path is Array or path.size()<2 or path.size()>16:return
  var curve:=_deserialize_curve(path)
  var position:=curve.sample_baked(curve.get_baked_length()*clampf(float(saved.get("elapsed",0))/float(saved["duration"]),0,1),true)
  if session.player.global_position.distance_to(position)>MAX_DISTANCE or not _space_clear(position,saved["kind"]=="orbs"):return
  restored.append(curve)
 event=saved;_curves=restored;_spawn_visuals();advance(0.000001)
func _serialize_curve(curve: Curve3D) -> Array:
 var points:Array=[]
 for i in curve.point_count:points.append([_arr(curve.get_point_position(i)),_arr(curve.get_point_in(i)),_arr(curve.get_point_out(i))])
 return points
func _deserialize_curve(points: Array) -> Curve3D:
 var curve:=Curve3D.new();curve.bake_interval=0.35
 for point in points:curve.add_point(_v3(point[0]),_v3(point[1]),_v3(point[2]))
 return curve
func _arr(v: Vector3) -> Array:return [v.x,v.y,v.z]
func _v3(v: Array) -> Vector3:return Vector3(float(v[0]),float(v[1]),float(v[2])) if v.size()>=3 else Vector3.ZERO
