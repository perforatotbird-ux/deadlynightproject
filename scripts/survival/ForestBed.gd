extends "res://scripts/survival/SleepPoint.gd"
# One sleeping session, persisted by SurvivalWorld; no wall/roof or healing cheat.
var session:Node
var data:Dictionary={}
var bedding:StandardMaterial3D
func _ready() -> void:
 super._ready();name="ForestBed";collision_layer=1|8;collision_mask=0
 var wood:=StandardMaterial3D.new();wood.albedo_color=Color("67513a")
 bedding=StandardMaterial3D.new()
 for i in 10:
  var mesh:=MeshInstance3D.new();var branch:=CylinderMesh.new();branch.top_radius=0.022;branch.bottom_radius=0.032;branch.height=0.95;branch.radial_segments=5;mesh.mesh=branch;mesh.rotation.z=PI/2;mesh.position=Vector3(0,0.10,-0.85+i*0.19);mesh.material_override=wood;add_child(mesh)
 var top:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(0.9,0.14,1.9);top.mesh=box;top.position.y=0.19;top.material_override=bedding;add_child(top)
 var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1.0,0.25,2.0);col.shape=shape;col.position.y=0.13;add_child(col)
 refresh()
func refresh() -> void:
 sleep_enabled=not bool(data.get("spent",false))
 if bedding:bedding.albedo_color=Color("334b2e") if sleep_enabled else Color("6b6050")
func can_interact(player:Node3D) -> bool:
 if bool(data.get("spent",false)) or not sleep_enabled or not is_instance_valid(player) or not is_inside_tree() or not is_visible_in_tree():return false
 var delta:Vector3=player.global_position-global_position
 if Vector2(delta.x,delta.z).length()>interaction_distance or absf(delta.y)>2.0:return false
 var query:=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*1.4,global_position+Vector3.UP*0.25,1)
 query.exclude=[player.get_rid(),get_rid()]
 return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func get_interact_text() -> String:
 return "Лесная кровать изношена" if bool(data.get("spent",false)) else "[E] Лесная кровать · один ночлег"
func survival_interact() -> void:
 if is_instance_valid(session):session.open_sleep(self)
