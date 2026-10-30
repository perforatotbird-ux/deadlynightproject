extends "res://scripts/survival/ShelterInteract.gd"
# Capability shared by beds and future bedrolls. Session owns the interaction lease.
@export var interaction_distance:=2.8
@export var sleep_enabled:=true
func _ready() -> void:add_to_group("sleep_points")
func is_sleep_point() -> bool:return true
func can_interact(player:Node3D) -> bool:
 if not sleep_enabled or not is_instance_valid(player) or not is_inside_tree() or not is_visible_in_tree():return false
 var delta=player.global_position-global_position
 if Vector2(delta.x,delta.z).length()>interaction_distance or absf(delta.y)>2.0:return false
 var query=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*1.4,global_position,1)
 query.exclude=[player.get_rid(),get_rid()]
 return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func survival_interact() -> void:
 if is_instance_valid(shelter) and is_instance_valid(shelter.session):shelter.session.open_sleep(self)
