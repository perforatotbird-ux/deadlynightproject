extends StaticBody3D
class_name TreeChoppable

signal tree_felled(species, pos)

@export var species: String = "birch"
@export var tree_id: String = ""

var max_hp: int = 8
var current_hp: int = 8
var log_count: int = 2
var log_weight: float = 4.0
var chip_color: Color = Color(0.96, 0.96, 0.86)

var _current_stage: int = 0
var _visual_node: Node3D = null
var _is_falling: bool = false
var _fall_direction: Vector3 = Vector3.FORWARD
var _fall_progress: float = 0.0
var _fall_duration: float = 2.5
var _fall_start_rot: Basis

# Audio players
var _audio_hit: AudioStreamPlayer3D = null
var _audio_fall: AudioStreamPlayer3D = null

# Particles
var _particles: GPUParticles3D = null

const SPECIES_CONFIG = {
	"birch": {
		"hp": 8, "logs": 2, "weight": 4.0,
		"color": Color(0.96, 0.96, 0.86),
		"height": 18.0, "radius": 0.35
	},
	"spruce": {
		"hp": 12, "logs": 3, "weight": 5.0,
		"color": Color(0.82, 0.41, 0.12),
		"height": 24.0, "radius": 0.50
	},
	"beech": {
		"hp": 16, "logs": 4, "weight": 7.0,
		"color": Color(0.93, 0.86, 0.51),
		"height": 24.0, "radius": 0.60
	},
	"oak": {
		"hp": 20, "logs": 5, "weight": 9.0,
		"color": Color(0.55, 0.35, 0.17),
		"height": 20.0, "radius": 0.70
	}
}

func _ready() -> void:
	collision_layer = 2 # Choppable layer
	collision_mask = 0
	_apply_species_config()
	_setup_collision()
	_setup_audio()
	_setup_particles()
	_update_mesh_stage(0)

func init_tree(p_species: String, p_id: String = "") -> void:
	species = p_species.to_lower()
	tree_id = p_id
	_apply_species_config()
	if is_inside_tree():
		_setup_collision()
		_update_mesh_stage(0)

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
	
	var hp_ratio = float(current_hp) / float(max_hp)
	var new_stage = 0
	if hp_ratio <= 0.10:
		new_stage = 3
	elif hp_ratio <= 0.35:
		new_stage = 2
	elif hp_ratio <= 0.70:
		new_stage = 1
		
	if new_stage != _current_stage and current_hp > 0:
		_update_mesh_stage(new_stage)
		
	if current_hp <= 0:
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
	# Disable collision so player can't walk into standing invisible trunk
	set_collision_layer_value(2, false)
	
	if _audio_fall:
		_audio_fall.play()
		
	_fall_progress = 0.0
	_fall_start_rot = global_transform.basis
	
	# Spawn Stump immediately at base
	_spawn_stump()

func _spawn_stump() -> void:
	var stump_path = "res://assets/models/trees/tree_%s_stump.glb" % species
	if ResourceLoader.exists(stump_path):
		var scene = load(stump_path)
		if scene:
			var stump = scene.instantiate()
			get_parent().add_child(stump)
			stump.global_position = global_position
			stump.global_basis = global_basis

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
	var max_angle = deg_to_rad(88.0) # falls almost flat to ground
	var current_angle = t * max_angle
	
	# Rotation axis is perpendicular to fall direction and UP
	var rot_axis = _fall_direction.cross(Vector3.UP).normalized()
	if rot_axis.length_squared() < 0.01:
		rot_axis = Vector3.RIGHT
		
	if _visual_node:
		_visual_node.transform.basis = Basis(rot_axis, current_angle)

func _on_tree_felled_complete() -> void:
	tree_felled.emit(species, global_position)
	
	# Spawn Wood Logs
	_spawn_logs()
	
	# Hide / remove fallen canopy after settling
	if _visual_node:
		var tween = create_tween()
		tween.tween_property(_visual_node, "scale", Vector3.ZERO, 1.0)
		tween.tween_callback(queue_free)
	else:
		queue_free()

func _spawn_logs() -> void:
	var log_script = load("res://scripts/props/LogPickup.gd")
	for i in range(log_count):
		var log_node = RigidBody3D.new()
		log_node.set_script(log_script)
		get_parent().add_child(log_node)
		
		# Scatter logs along fall vector
		var offset_dist = 2.0 + float(i) * 2.2
		var pos = global_position + _fall_direction * offset_dist + Vector3(randf_range(-0.5, 0.5), 0.8, randf_range(-0.5, 0.5))
		log_node.global_position = pos
		log_node.init_log(species, log_weight)
		
		# Small impulse
		log_node.apply_impulse(Vector3(randf_range(-1.0, 1.0), 1.5, randf_range(-1.0, 1.0)))

func get_interact_text() -> String:
	return "LMB: Chop %s Tree [HP: %d/%d]" % [species.capitalize(), current_hp, max_hp]
