extends RigidBody3D
class_name LogPickup

@export var species: String = "birch"
@export var weight_kg: float = 4.0

var _mesh_node: Node3D = null
var _time_alive: float = 0.0
var _last_valid_ground_y: float = -9999.0

func _ready() -> void:
	collision_layer = 4 # Interactable / Item layer
	collision_mask = 1  # Collides with terrain (layer 1)
	add_to_group("pickup_logs")
	continuous_cd = true
	
	# Heavy physical material with high friction to prevent sliding into crevices
	mass = clampf(weight_kg, 2.0, 10.0)
	var mat = PhysicsMaterial.new()
	mat.friction = 0.90
	mat.rough = true
	mat.bounce = 0.02
	physics_material_override = mat
	linear_damp = 1.8
	angular_damp = 2.5
	
	_last_valid_ground_y = global_position.y
	_load_model()

func _physics_process(delta: float) -> void:
	if freeze or not is_inside_tree():
		return
		
	_time_alive += delta
	
	# Periodic terrain anti-fallthrough check (prevents slipping through thin trimesh seams in ditches)
	var space = get_world_3d().direct_space_state
	if space != null:
		var check_top = Vector3(global_position.x, global_position.y + 2.5, global_position.z)
		var check_bot = Vector3(global_position.x, global_position.y - 3.5, global_position.z)
		var q = PhysicsRayQueryParameters3D.create(check_top, check_bot)
		q.collision_mask = 1 # Terrain
		var hit = space.intersect_ray(q)
		if not hit.is_empty():
			var ground_y = hit.position.y
			_last_valid_ground_y = ground_y
			# If log penetrated slightly below ground surface:
			if global_position.y < ground_y + 0.15:
				global_position.y = ground_y + 0.22
				if linear_velocity.y < 0.0:
					linear_velocity.y = 0.0
					
	# Failsafe: if log dropped through terrain into the underground void:
	if _last_valid_ground_y > -9000.0 and global_position.y < _last_valid_ground_y - 1.5:
		global_position.y = _last_valid_ground_y + 0.35
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		
	# Settle & freeze when resting to guarantee stability on slopes and zero physics drift
	if _time_alive > 1.2 and linear_velocity.length_squared() < 0.05 and angular_velocity.length_squared() < 0.05:
		freeze = true

func init_log(p_species: String, p_weight: float) -> void:
	species = p_species
	weight_kg = p_weight
	mass = clampf(weight_kg, 2.0, 10.0)
	_load_model()

func _load_model() -> void:
	if _mesh_node != null:
		_mesh_node.queue_free()
		
	var path = "res://assets/models/trees/tree_%s_log.glb" % species
	if ResourceLoader.exists(path):
		var scene = load(path)
		if scene:
			_mesh_node = scene.instantiate()
			# Round log cylinder is along Y; rotate 90° along X to lie horizontally along Z
			_mesh_node.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			add_child(_mesh_node)
	else:
		# Procedural fallback round log (бревно)
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.18
		cyl.bottom_radius = 0.18
		cyl.height = 1.0
		var m_inst = MeshInstance3D.new()
		m_inst.mesh = cyl
		m_inst.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		_mesh_node = m_inst
		add_child(_mesh_node)
	
	# Smooth capsule collision oriented along Z (no sharp corners that snag on ditch edges)
	if get_node_or_null("CollisionShape3D") == null:
		var col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var cap = CapsuleShape3D.new()
		cap.radius = 0.18
		cap.height = 1.0
		col.shape = cap
		col.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		add_child(col)

func get_interact_text() -> String:
	var sp_ru = "Берёзовое"
	match species:
		"spruce": sp_ru = "Еловое"
		"oak": sp_ru = "Дубовое"
		"beech": sp_ru = "Буковое"
	return "[E] Подобрать: %s бревно (%.1f кг)" % [sp_ru, weight_kg]

func pickup() -> Dictionary:
	queue_free()
	return {
		"species": species,
		"weight": weight_kg
	}
