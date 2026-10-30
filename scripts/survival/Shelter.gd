extends Node3D
# A deliberately small, physical first-night cabin, not the unfinished HUT POI.
var door_closed := true
var door: StaticBody3D
var session: Node
var bed: StaticBody3D
func _ready() -> void:
 var wood:=StandardMaterial3D.new();wood.albedo_color=Color(0.22,0.28,0.22)
 var roof:=StandardMaterial3D.new();roof.albedo_color=Color(0.13,0.17,0.16)
 _box(self,Vector3(4.4,0.12,4.4),Vector3(0,0.0,0),wood)
 _box(self,Vector3(0.18,2.7,4.4),Vector3(-2.1,1.4,0),wood)
 _box(self,Vector3(0.18,2.7,4.4),Vector3(2.1,1.4,0),wood)
 _box(self,Vector3(4.4,2.7,0.18),Vector3(0,1.4,-2.1),wood)
 _box(self,Vector3(1.5,2.7,0.18),Vector3(-1.4,1.4,2.1),wood)
 _box(self,Vector3(1.5,2.7,0.18),Vector3(1.4,1.4,2.1),wood)
 _box(self,Vector3(1.3,0.5,0.18),Vector3(0,2.5,2.1),wood)
 _box(self,Vector3(4.8,0.18,4.8),Vector3(0,2.85,0),roof)
 door=StaticBody3D.new();door.name="CabinDoor";door.collision_layer=1|8;add_child(door);door.position=Vector3(-0.65,0,2.1)
 _box(door,Vector3(1.3,2.25,0.12),Vector3(0.65,1.15,0),wood,false)
 door.set_script(preload("res://scripts/survival/ShelterInteract.gd"));door.shelter=self;door.kind="door"
 bed=StaticBody3D.new();bed.name="Cot";bed.collision_layer=1|8;add_child(bed);bed.position=Vector3(-1.1,0.3,-0.8)
 _box(bed,Vector3(1.1,0.3,1.9),Vector3.ZERO,roof,false)
 bed.set_script(preload("res://scripts/survival/ShelterInteract.gd"));bed.shelter=self;bed.kind="bed"
 var sign:=Label3D.new();sign.text="ЛЕСНАЯ СТОЯНКА\nДверь — [E] · Отдых — у койки";sign.font_size=32;sign.pixel_size=0.006;sign.position=Vector3(0,2.5,2.22);add_child(sign)
 set_door(door_closed)
func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, own_body: bool = true) -> void:
 var b:Node3D=StaticBody3D.new() if own_body else parent
 if own_body:parent.add_child(b)
 var m:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;m.mesh=mesh;m.material_override=mat;m.position=pos;b.add_child(m)
 var c:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;c.shape=shape;c.position=pos;b.add_child(c)
func contains(point: Vector3) -> bool:
 var p:=to_local(point);return absf(p.x)<1.95 and absf(p.z)<1.95 and p.y>0.0 and p.y<2.8
func set_door(closed: bool) -> void:
 door_closed=closed
 if door:door.rotation.y=0.0 if closed else -PI*0.5
func toggle_door() -> void:
 if not door_closed and is_instance_valid(session) and is_instance_valid(session.player):
  var p:=to_local(session.player.global_position)
  if absf(p.x)<0.95 and absf(p.z-2.1)<0.65:
   session.notify("Отойдите от дверного проёма");return
 set_door(not door_closed)
