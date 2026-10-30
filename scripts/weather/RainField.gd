extends Node3D
# Renderer-independent bounded MultiMesh rain. No GPU collision dependency and
# no per-drop raycasts: the cabin's actual roof footprint clips fragments.
var session:Node
var rng:=RandomNumberGenerator.new()
var field:MultiMeshInstance3D
var positions:=PackedVector3Array()
var speeds:=PackedFloat32Array()
var material:ShaderMaterial
var count:=0
var _tick:=0.0
var _splash_tick:=0.0
var splashes:Array[MeshInstance3D]=[]
var splash_age:=PackedFloat32Array()
var _splash_index:=0
var splash_materials:Array[ShaderMaterial]=[]
# Shared coarse surface cache: never a physics query per drop.
const GROUND_STEP:=4.0
var ground_samples:Dictionary={}
var _ground_queue:Array[Vector2i]=[]
var _ground_origin:=Vector2i(2147483647,2147483647)
var _ground_tick:=0.0
func _ready() -> void:
 name="RainField";rng.seed=85091
 if session.location!="forest":visible=false;return
 var splash_mesh:=QuadMesh.new();splash_mesh.size=Vector2(0.10,0.12)
 var splash_mat:=ShaderMaterial.new();splash_mat.shader=preload("res://shaders/sky/splash.gdshader");splash_mesh.material=splash_mat
 for i in 12:
  var splash:=MeshInstance3D.new();splash.mesh=splash_mesh;splash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;splash.gi_mode=GeometryInstance3D.GI_MODE_DISABLED;var individual:=splash_mat.duplicate() as ShaderMaterial;splash.material_override=individual;splash_materials.append(individual);add_child(splash);splash.top_level=true;splash.visible=false;splashes.append(splash);splash_age.append(-1.0)
 field=MultiMeshInstance3D.new();add_child(field)
 material=ShaderMaterial.new();material.shader=preload("res://shaders/sky/rain.gdshader")
 var mesh:=QuadMesh.new();mesh.size=Vector2(0.009,0.17);mesh.material=material
 var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=900;mm.visible_instance_count=0
 field.multimesh=mm;field.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;field.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
 field.custom_aabb=AABB(Vector3(-25,-15,-25),Vector3(50,40,50))
 for i in 900:
  positions.append(Vector3(rng.randf_range(-17,17),rng.randf_range(-4,12),rng.randf_range(-17,17)));speeds.append(rng.randf_range(13,21))
func update_field(delta:float,state:Dictionary,quality:int) -> void:
 if not is_instance_valid(session.player):return
 if session.location!="forest":
  visible=false
  for splash in splashes:splash.visible=false
  return
 var rain:float=state.rain
 visible=session.location=="forest" and rain>0.01
 if not visible:
  for splash in splashes:splash.visible=false
  return
 _update_ground(delta)
 _update_splashes(delta,state)
 _tick+=delta
 if _tick<1.0/30.0:return
 var dt:=minf(_tick,0.1);_tick=0
 var max_count:int=[260,560,900][clampi(quality,0,2)]
 count=maxi(40,int(max_count*rain));field.multimesh.visible_instance_count=count
 # Follow continuously: rebase particle coordinates when the field origin moves.
 var center:Vector3=session.player.global_position
 var shift:=center-global_position;global_position=center
 var wind:Vector3=state.wind_direction*float(state.wind)*3.0
 var camera:Camera3D=session.player._camera
 var facing:Vector3=camera.global_basis.x
 var down:Vector3=(Vector3.DOWN*18+wind).normalized()
 var normal:=facing.cross(-down).normalized()
 var basis:=Basis(facing,-down,normal)
 material.set_shader_parameter("opacity",lerpf(0.12,0.35,session.daylight()))
 var roof:Node3D=session.shelter
 material.set_shader_parameter("roof_enabled",is_instance_valid(roof))
 if is_instance_valid(roof):
  material.set_shader_parameter("roof_min",roof.global_position+Vector3(-2.4,-0.15,-2.4))
  material.set_shader_parameter("roof_max",roof.global_position+Vector3(2.4,2.96,2.4))
 for i in count:
  var p:=positions[i]-shift
  p+=(wind+Vector3.DOWN*speeds[i])*dt
  p.x=wrapf(p.x,-17,17);p.z=wrapf(p.z,-17,17);p.y=wrapf(p.y,-4,12)
  var height:=ground_height(p+global_position)
  if height>-90000 and p.y+global_position.y<height+0.22:
   p=Vector3(rng.randf_range(-17,17),rng.randf_range(9,12),rng.randf_range(-17,17))
   height=ground_height(p+global_position)
  positions[i]=p
  var size:=0.7+float(i%5)*0.15
  field.multimesh.set_instance_transform(i,Transform3D(basis.scaled(Vector3(size,size,1)),p))

func _update_splashes(delta:float,state:Dictionary) -> void:
 for i in splashes.size():
  if splash_age[i]<0:continue
  splash_age[i]+=delta
  if splash_age[i]>0.24:splashes[i].visible=false;splash_age[i]=-1;continue
  splashes[i].scale=Vector3.ONE*(0.5+splash_age[i]*2)
  splash_materials[i].set_shader_parameter("opacity",0.16*(1.0-splash_age[i]/0.24))
 _splash_tick-=delta
 if _splash_tick>0:return
 _splash_tick=0.22 if float(state.rain)>0.6 else 0.45
 # At most two surface queries per tick, not one query per raindrop.
 for attempt in 2:
  var center:Vector3=session.player.global_position+Vector3(rng.randf_range(-5,5),0,rng.randf_range(-5,5))
  var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3.UP*7,center-Vector3.UP*5,1))
  if hit.is_empty() or not hit.collider.is_in_group("camp_ground") or hit.normal.y<0.7:continue
  if is_instance_valid(session.shelter):
   var local:Vector3=session.shelter.to_local(hit.position)
   if absf(local.x)<2.4 and absf(local.z)<2.4:continue
  var index:=_splash_index%12;_splash_index+=1
  var normal:Vector3=hit.normal
  # Camera-facing specks above the surface: no coplanar XZ rings / z-fighting.
  splashes[index].global_transform=Transform3D(session.player._camera.global_basis.scaled(Vector3.ONE*0.5),hit.position+normal*0.08)
  splash_materials[index].set_shader_parameter("opacity",0.16)
  splashes[index].visible=true;splash_age[index]=0

func _update_ground(delta:float) -> void:
 var pos:Vector3=session.player.global_position
 var origin:=Vector2i(floori(pos.x/GROUND_STEP),floori(pos.z/GROUND_STEP))
 if origin!=_ground_origin:
  _ground_origin=origin;_ground_queue.clear()
  for x in range(-5,6):
   for z in range(-5,6):
    var key:=origin+Vector2i(x,z)
    if not ground_samples.has(key):_ground_queue.append(key)
  _ground_queue.sort_custom(func(a:Vector2i,b:Vector2i):return a.distance_squared_to(origin)>b.distance_squared_to(origin))
  for key in ground_samples.keys():
   if absi(key.x-origin.x)>7 or absi(key.y-origin.y)>7:ground_samples.erase(key)
 _ground_tick-=delta
 if _ground_tick>0:return
 _ground_tick=0.1
 for i in mini(6,_ground_queue.size()):
  var key:Vector2i=_ground_queue.pop_back()
  var center:=Vector3((key.x+0.5)*GROUND_STEP,pos.y,(key.y+0.5)*GROUND_STEP)
  var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3.UP*25,center-Vector3.UP*60,1))
  ground_samples[key]=float(hit.position.y) if not hit.is_empty() and hit.collider.is_in_group("camp_ground") else -100000.0
func ground_height(world:Vector3) -> float:
 var key:=Vector2i(floori(world.x/GROUND_STEP),floori(world.z/GROUND_STEP))
 return float(ground_samples.get(key,-100000.0))
