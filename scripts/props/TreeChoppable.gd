extends StaticBody3D
class_name TreeChoppable

signal tree_felled(species, pos)

const VoxelTreeTrunkScript = preload("res://scripts/props/VoxelTreeTrunk.gd")

@export var species: String = "birch"
@export var tree_id: String = ""

var max_hp: int = 8
var current_hp: int = 8
var log_count: int = 3
var log_weight: float = 4.0
var chip_color: Color = Color(0.96, 0.96, 0.86)

var _current_stage: int = 0
var _visual_node: Node3D = null
var _voxel_trunk: Node3D = null
var _is_falling: bool = false
var _fall_direction: Vector3 = Vector3.FORWARD
var _fall_progress: float = 0.0
var _fall_duration: float = 1.2
var _fall_start_rot: Basis
var _target_fall_angle: float = deg_to_rad(88.0)

# Audio players
var _audio_hit: AudioStreamPlayer3D = null
var _audio_fall: AudioStreamPlayer3D = null

# Particles
var _particles: GPUParticles3D = null

const SPECIES_CONFIG = {
	"birch": {
		"hp": 8, "logs": 3, "weight": 4.0,
		"color": Color(0.96, 0.96, 0.86),
		"height": 18.0, "radius": 0.35
	},
	"spruce": {
		"hp": 12, "logs": 3, "weight": 5.0,
		"color": Color(0.82, 0.41, 0.12),
		"height": 24.0, "radius": 0.50
	},
	"beech": {
		"hp": 16, "logs": 3, "weight": 7.0,
		"color": Color(0.93, 0.86, 0.51),
		"height": 24.0, "radius": 0.60
	},
	"oak": {
		"hp": 20, "logs": 3, "weight": 9.0,
		"color": Color(0.55, 0.35, 0.17),
		"height": 20.0, "radius": 0.70
	}
}

static var felled_tree_ids: Dictionary = {}

func get_effective_id() -> String:
	if tree_id != "":
		return tree_id
	return "pos_%d_%d_%d" % [int(round(global_position.x)), int(round(global_position.y)), int(round(global_position.z))]

func _is_already_felled() -> bool:
	var eff_id = get_effective_id()
	if felled_tree_ids.has(eff_id):
		return true
	if tree_id != "" and felled_tree_ids.has(tree_id):
		return true
	var pos_id = "pos_%d_%d_%d" % [int(round(global_position.x)), int(round(global_position.y)), int(round(global_position.z))]
	if felled_tree_ids.has(pos_id):
		return true
	return false

func _ready() -> void:
	collision_layer = 2 # Choppable layer
	collision_mask = 0
	
	if _is_already_felled():
		_spawn_stump()
		queue_free()
		return
		
	add_to_group("choppable_trees")
	_apply_species_config()
	_setup_collision()
	_setup_audio()
	_setup_particles()
	_setup_voxel_trunk()
	_update_mesh_stage(0)

func init_tree(p_species: String, p_id: String = "") -> void:
	species = p_species.to_lower()
	tree_id = p_id
	if _is_already_felled():
		_spawn_stump()
		queue_free()
		return
	_apply_species_config()
	if is_inside_tree():
		_setup_collision()
		_setup_voxel_trunk()
		_update_mesh_stage(0)

func _setup_voxel_trunk() -> void:
	if _voxel_trunk != null and is_instance_valid(_voxel_trunk):
		_voxel_trunk.queue_free()
		
	var cfg = SPECIES_CONFIG.get(species, SPECIES_CONFIG["birch"])
	_voxel_trunk = VoxelTreeTrunkScript.new()
	_voxel_trunk.name = "VoxelTrunk"
	add_child(_voxel_trunk)
	# Voxel radius slightly encases low-poly cylinder (+0.015m) so cuts are crisp and clean
	_voxel_trunk.init_trunk(species, cfg["radius"] + 0.015, 3.2, 0.08)

func _apply_species_config() -> void:
	var cfg = SPECIES_CONFIG.get(species, SPECIES_CONFIG["birch"])
	max_hp = cfg["hp"]
	current_hp = max_hp
	log_count = cfg["logs"]
	log_weight = cfg["weight"]
	chip_color = cfg["color"]

func _setup_collision() -> void:
	var cfg = SPECIES_CONFIG.get(species, SPECIES_CONFIG["birch"])
	var col = get_node_or_null("CollisionShape3D")
	if col == null:
		col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		add_child(col)
		
	var cylinder = CylinderShape3D.new()
	cylinder.height = cfg["height"]
	cylinder.radius = cfg["radius"]
	col.shape = cylinder
	col.position = Vector3(0.0, cfg["height"] / 2.0, 0.0)

func _setup_audio() -> void:
	_audio_hit = AudioStreamPlayer3D.new()
	_audio_hit.name = "HitAudio"
	_audio_hit.max_distance = 30.0
	_audio_hit.bus = "Master"
	add_child(_audio_hit)
	
	_audio_fall = AudioStreamPlayer3D.new()
	_audio_fall.name = "FallAudio"
	_audio_fall.max_distance = 60.0
	_audio_fall.bus = "Master"
	add_child(_audio_fall)
	
	var fall_stream = load("res://assets/sounds/level_01/axe/tree_fall_combo.ogg")
	if fall_stream:
		_audio_fall.stream = fall_stream

func _setup_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "WoodChips"
	_particles.emitting = false
	_particles.one_shot = true
	_particles.explosiveness = 0.9
	_particles.amount = 28
	_particles.lifetime = 0.8
	
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -9.8, 0)
	mat.scale_min = 0.05
	mat.scale_max = 0.12
	mat.color = chip_color
	_particles.process_material = mat
	
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.08, 0.04, 0.08)
	var chip_mat = StandardMaterial3D.new()
	chip_mat.albedo_color = chip_color
	chip_mat.roughness = 0.8
	box_mesh.material = chip_mat
	_particles.draw_pass_1 = box_mesh
	
	add_child(_particles)

func _update_mesh_stage(stage: int) -> void:
	_current_stage = stage
	if _visual_node != null:
		_visual_node.queue_free()
		
	var path = "res://assets/models/trees/tree_%s_stage_%d.glb" % [species, stage]
	if not ResourceLoader.exists(path):
		path = "res://assets/models/trees/tree_%s.glb" % species
		
	if ResourceLoader.exists(path):
		var scene = load(path)
		if scene:
			_visual_node = scene.instantiate()
			add_child(_visual_node)

func hit(damage: int, hit_point: Vector3, player_pos: Vector3) -> bool:
	if _is_falling or current_hp <= 0:
		return false
		
	current_hp -= damage
	_play_hit_sound()
	_emit_chips(hit_point)
	
	# Carve voxel trunk strictly where the axe hits
	var is_severed = false
	if _voxel_trunk:
		var strike_dir = (hit_point - player_pos).normalized()
		var carve_res = _voxel_trunk.carve(hit_point, strike_dir, damage)
		if carve_res.get("severed", false):
			is_severed = true
	
	var hp_ratio = float(current_hp) / float(max_hp)
	var new_stage = 0
	if hp_ratio <= 0.10:
		new_stage = 3
	elif hp_ratio <= 0.35:
		new_stage = 2
	elif hp_ratio <= 0.70:
		new_stage = 1
		
	if new_stage != _current_stage and current_hp > 0:
		_current_stage = new_stage
		
	if current_hp <= 0 or is_severed:
		# Direction away from player
		var away = (global_position - player_pos)
		away.y = 0.0
		if away.length_squared() < 0.001:
			away = Vector3.FORWARD
		else:
			away = away.normalized()
		_fall_direction = away
		_start_falling()
		return true
		
	return false

func _play_hit_sound() -> void:
	var hits = [
		"res://assets/sounds/level_01/axe/axe_hit_wood_01.ogg",
		"res://assets/sounds/level_01/axe/axe_hit_wood_02.ogg",
		"res://assets/sounds/level_01/axe/axe_hit_wood_03.ogg"
	]
	var pick = hits[randi() % hits.size()]
	if ResourceLoader.exists(pick):
		_audio_hit.stream = load(pick)
		_audio_hit.pitch_scale = randf_range(0.92, 1.08)
		_audio_hit.play()

func _emit_chips(point: Vector3) -> void:
	if _particles:
		_particles.global_position = point
		_particles.restart()
		_particles.emitting = true

func _start_falling() -> void:
	_is_falling = true
	var eff_id = get_effective_id()
	var info = {
		"species": species,
		"pos": global_position,
		"id": tree_id
	}
	felled_tree_ids[eff_id] = info
	if tree_id != "":
		felled_tree_ids[tree_id] = info
	var pos_id = "pos_%d_%d_%d" % [int(round(global_position.x)), int(round(global_position.y)), int(round(global_position.z))]
	felled_tree_ids[pos_id] = info

	# Immediately remove from choppable group & collision so it can never be hit or detected again
	remove_from_group("choppable_trees")
	set_collision_layer_value(2, false)
	
	if _audio_fall:
		_audio_fall.play()
		
	_fall_progress = 0.0
	_fall_start_rot = global_transform.basis
	_target_fall_angle = _calculate_target_fall_angle()
	
	# Spawn Stump immediately at base
	_spawn_stump()

func _calculate_target_fall_angle() -> float:
	if not is_inside_tree():
		return deg_to_rad(88.0)
	var space_state = get_world_3d().direct_space_state
	if space_state == null:
		return deg_to_rad(88.0)
		
	var cfg = SPECIES_CONFIG.get(species, SPECIES_CONFIG["birch"])
	var tree_h: float = cfg["height"]
	var radius: float = cfg["radius"]
	var base_pos: Vector3 = global_position
	
	# Sample distances along the fall direction: 2m up to tree_h in steps
	var min_contact_angle: float = deg_to_rad(88.0)
	var num_samples = int(clampf(tree_h / 2.0, 4.0, 10.0))
	
	for s in range(1, num_samples + 1):
		var d = (float(s) / float(num_samples)) * (tree_h * 0.9)
		if d < 1.5:
			continue
			
		var sample_x = base_pos.x + _fall_direction.x * d
		var sample_z = base_pos.z + _fall_direction.z * d
		
		# Raycast vertically from high above to below
		var ray_from = Vector3(sample_x, base_pos.y + 30.0, sample_z)
		var ray_to = Vector3(sample_x, base_pos.y - 30.0, sample_z)
		
		var query = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		query.collision_mask = 1 # Terrain
		var res = space_state.intersect_ray(query)
		
		if not res.is_empty():
			var terrain_y = res.position.y
			var delta_y = (terrain_y - base_pos.y) + radius
			# Angle where trunk at distance d touches terrain_y
			var ratio = clampf(delta_y / d, -0.98, 0.98)
			var contact_angle = acos(ratio)
			
			if contact_angle < min_contact_angle:
				min_contact_angle = contact_angle
				
	return clampf(min_contact_angle, deg_to_rad(25.0), deg_to_rad(115.0))

func _spawn_stump() -> void:
	if not is_inside_tree():
		return
	for s in get_tree().get_nodes_in_group("permanent_stumps"):
		if is_instance_valid(s) and s is Node3D:
			if (s as Node3D).global_position.distance_squared_to(global_position) < 0.36:
				return

	var stump_path = "res://assets/models/trees/tree_%s_stump.glb" % species
	if ResourceLoader.exists(stump_path):
		var scene = load(stump_path)
		if scene:
			var stump = scene.instantiate()
			var parent_node = get_parent()
			if parent_node == null or not is_instance_valid(parent_node):
				parent_node = get_tree().current_scene
			if parent_node:
				parent_node.add_child(stump)
				
				# Snap stump position to exact ground surface
				var stump_pos = global_position
				var space_state = get_world_3d().direct_space_state
				if space_state != null:
					var q = PhysicsRayQueryParameters3D.create(
						Vector3(stump_pos.x, stump_pos.y + 3.0, stump_pos.z),
						Vector3(stump_pos.x, stump_pos.y - 4.0, stump_pos.z)
					)
					q.collision_mask = 1 # Terrain
					var hit = space_state.intersect_ray(q)
					if not hit.is_empty():
						stump_pos.y = hit.position.y
						
				stump.global_position = stump_pos
				stump.global_basis = global_basis
				stump.add_to_group("permanent_stumps")

func _process(delta: float) -> void:
	if not _is_falling:
		return
		
	_fall_progress += delta / _fall_duration
	if _fall_progress >= 1.0:
		_fall_progress = 1.0
		_is_falling = false
		_on_tree_felled_complete()
		return
		
	# Quadratic ease-in acceleration for realistic gravity toppling
	var t = _fall_progress * _fall_progress
	var current_angle = t * _target_fall_angle
	
	# Rotation axis is perpendicular to fall direction and UP
	var rot_axis = _fall_direction.cross(Vector3.UP).normalized()
	if rot_axis.length_squared() < 0.01:
		rot_axis = Vector3.RIGHT
		
	var fall_basis = Basis(rot_axis, current_angle)
	if _visual_node:
		_visual_node.transform.basis = fall_basis
	if _voxel_trunk:
		_voxel_trunk.transform.basis = fall_basis
		
		# Dynamic ground check during rotation: if tip or trunk reaches terrain, finish early
		if _fall_progress > 0.35 and is_inside_tree():
			var space_state = get_world_3d().direct_space_state
			if space_state != null:
				var cfg = SPECIES_CONFIG.get(species, SPECIES_CONFIG["birch"])
				var tree_h: float = cfg["height"]
				var tip_local = Vector3(0.0, tree_h * 0.85, 0.0)
				var tip_world = _visual_node.global_transform * tip_local if _visual_node else global_position + Vector3(0, tree_h, 0)
				var q = PhysicsRayQueryParameters3D.create(
					Vector3(tip_world.x, tip_world.y + 1.5, tip_world.z),
					Vector3(tip_world.x, tip_world.y - 1.5, tip_world.z)
				)
				q.collision_mask = 1 # Terrain
				var hit = space_state.intersect_ray(q)
				if not hit.is_empty():
					if tip_world.y <= hit.position.y + 0.3:
						_fall_progress = 1.0
						_is_falling = false
						_on_tree_felled_complete()
						return

func _on_tree_felled_complete() -> void:
	tree_felled.emit(species, global_position)
	
	# Spawn Wood Logs safely on ground (3 round logs)
	_spawn_logs()
	
	# Hide / remove fallen canopy after settling
	var tween = create_tween()
	var has_anim = false
	if _visual_node:
		tween.tween_property(_visual_node, "scale", Vector3.ZERO, 0.8)
		has_anim = true
	if _voxel_trunk:
		if has_anim:
			tween.parallel().tween_property(_voxel_trunk, "scale", Vector3.ZERO, 0.8)
		else:
			tween.tween_property(_voxel_trunk, "scale", Vector3.ZERO, 0.8)
			has_anim = true
	if has_anim:
		tween.tween_callback(queue_free)
	else:
		queue_free()

func _spawn_logs() -> void:
	var log_script = load("res://scripts/props/LogPickup.gd")
	var space_state = get_world_3d().direct_space_state if is_inside_tree() else null
	
	for i in range(log_count):
		var log_node = RigidBody3D.new()
		log_node.set_script(log_script)
		get_parent().add_child(log_node)
		
		# Scatter logs along fall vector
		var offset_dist = 2.0 + float(i) * 2.2
		var target_x = global_position.x + _fall_direction.x * offset_dist + randf_range(-0.35, 0.35)
		var target_z = global_position.z + _fall_direction.z * offset_dist + randf_range(-0.35, 0.35)
		var spawn_y = global_position.y + 0.8
		
		# Raycast downward at target position to find exact ground elevation (never spawn inside/under ground)
		if space_state != null:
			var ray_from = Vector3(target_x, global_position.y + 30.0, target_z)
			var ray_to = Vector3(target_x, global_position.y - 30.0, target_z)
			var q = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
			q.collision_mask = 1 # Terrain
			var hit = space_state.intersect_ray(q)
			if not hit.is_empty():
				spawn_y = hit.position.y + 0.45
				
		log_node.global_position = Vector3(target_x, spawn_y, target_z)
		log_node.init_log(species, log_weight)
		
		# Gentle upward impulse
		log_node.apply_impulse(Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3)))

func get_species_name_ru() -> String:
	match species:
		"birch": return "Берёза"
		"spruce": return "Ель"
		"oak": return "Дуб"
		"beech": return "Бук"
		_: return species.capitalize()

func get_interact_text() -> String:
	return "[ЛКМ] Рубить: %s [HP: %d/%d]" % [get_species_name_ru(), current_hp, max_hp]
