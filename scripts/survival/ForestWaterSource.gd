extends StaticBody3D
# Permanent raw-water gathering point. No direct drinking or safe-water shortcut.
var session:Node
var data:Dictionary={}
var next_draw_clock:=-1.0
func material(color:String)->StandardMaterial3D:
 var result:=StandardMaterial3D.new();result.albedo_color=Color(color);result.roughness=0.85;return result
func part(mesh:Mesh,pos:Vector3,mat:Material)->MeshInstance3D:
 var instance:=MeshInstance3D.new();instance.mesh=mesh;instance.position=pos;instance.material_override=mat;add_child(instance);return instance
func _ready()->void:
 name=str(data.get("id","RawWaterSource"));collision_layer=4;collision_mask=0;add_to_group("water");add_to_group("raw_water_sources")
 var well:bool=data.get("kind")=="well"
 var radius:=0.75 if well else (1.4 if data.get("kind")=="pool" else 0.85)
 var water:=CylinderMesh.new();water.top_radius=radius;water.bottom_radius=radius;water.height=0.035;water.radial_segments=48
 var wet:=material("485d49" if data.get("kind")=="pool" else "385c66");wet.roughness=0.2;wet.metallic=0.2
 part(water,Vector3(0,0.32 if well else 0.10,0),wet)
 var stone:=material("62645a")
 for i in 12:
  var angle:=TAU*i/12.0
  var rock:Mesh
  if well:
   var brick:=BoxMesh.new();brick.size=Vector3(0.40,0.45,0.31);rock=brick
  else:
   var sphere:=SphereMesh.new();sphere.radius=0.25;sphere.height=0.28;sphere.radial_segments=12;sphere.rings=6;rock=sphere
  var mesh:=part(rock,Vector3(sin(angle)*(radius+0.08),0.25 if well else 0.08,cos(angle)*(radius+0.08)),stone)
  mesh.rotation.y=angle;mesh.rotation.z=0.05*sin(i*2.0)
 if data.get("kind")=="spring":
  var boulder:=SphereMesh.new();boulder.radius=0.48;boulder.height=0.85;boulder.radial_segments=16;boulder.rings=8;part(boulder,Vector3(0,0.32,-0.8),stone)
  var stream:=CylinderMesh.new();stream.top_radius=0.025;stream.bottom_radius=0.07;stream.height=0.24;stream.radial_segments=12;part(stream,Vector3(0,0.24,-0.54),wet)
 var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=radius+0.25;shape.height=0.50 if well else 0.22;collision.shape=shape;collision.position.y=0.25 if well else 0.09;add_child(collision)
 var sign:=Label3D.new();sign.text=str(data.get("name","Источник"))+"\nСЫРАЯ ВОДА · НУЖНО КИПЯТИТЬ";sign.font_size=22;sign.pixel_size=0.003;sign.position.y=1.15;sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;add_child(sign)
func can_collect()->bool:
 if not is_instance_valid(session) or not is_instance_valid(session.player) or session.health<=0 or session.location!="forest" or session.get_tree().paused:return false
 if session.clock<next_draw_clock or session.player.global_position.distance_to(global_position)>3.3:return false
 var ray:=PhysicsRayQueryParameters3D.create(session.player.global_position+Vector3.UP,global_position+Vector3.UP*0.3,1|8)
 ray.exclude=[session.player.get_rid(),get_rid()]
 return session.player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func get_interact_text()->String:return "[E] Набрать 0,5 л сырой воды · "+str(data.get("name","Источник"))
func survival_interact()->void:
 if not can_collect():return
 if not session.Items.transact(session.player,{},[session.Items.item("raw_water")]):session.notify("Нет места в рюкзаке для 0,5 л воды");return
 next_draw_clock=session.clock+60.0
 session.notify("Набрано 0,5 л СЫРОЙ воды. Перед употреблением кипятите у костра.")
