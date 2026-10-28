extends RigidBody3D
class_name LogPickup

@export var species: String = "birch"
@export var weight_kg: float = 4.0

var _mesh_node: Node3D = null

func _ready() -> void:
	collision_layer = 4 # Interactable / Item layer
	collision_mask = 1  # Collides with terrain
	continuous_cd = true
	_load_model()

func init_log(p_species: String, p_weight: float) -> void:
	species = p_species
	weight_kg = p_weight
	_load_model()

func _load_model() -> void:
	if _mesh_node != null:
		_mesh_node.queue_free()
		
	var path = "res://assets/models/trees/tree_%s_log.glb" % species
	if ResourceLoader.exists(path):
		var scene = load(path)
		if scene:
			_mesh_node = scene.instantiate()
			add_child(_mesh_node)
	
	# Ensure collision shape exists
	if get_node_or_null("CollisionShape3D") == null:
		var col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(0.35, 0.35, 1.0)
		col.shape = box
		add_child(col)

func get_interact_text() -> String:
	return "Press [E] to pick up %s log (%.1f kg)" % [species.capitalize(), weight_kg]

func pickup() -> Dictionary:
	queue_free()
	return {
		"species": species,
		"weight": weight_kg
	}
