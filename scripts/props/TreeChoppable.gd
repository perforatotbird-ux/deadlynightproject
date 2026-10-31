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
var _break_height: float = 1.3
var _fall_pivot: Node3D = null
var _fall_preparing: bool = false
var _restoring_remnant: bool = false
var _target_fall_angle: float = deg_to_rad(88.0)

# Audio players
var _audio_hit: AudioStreamPlayer3D = null
var _audio_fall: AudioStreamPlayer3D = null

# Particles
var _particles: GPUParticles3D = null
var _dust_particles: GPUParticles3D = null

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
		"hp": 16, "logs": 3, "weight": 9.0,
		"color": Color(0.55, 0.35, 0.17),
		"height": 20.0, "radius": 0.70
	}
}

static var felled_tree_ids: Dictionary = {}
static var damaged_tree_states: Dictionary = {}

static func compact_felled_registry() -> Dictionary:
	# Keep legacy bool flags; modern records have one canonical identity.
	var result:Dictionary={}
	for key in felled_tree_ids:
		var info=felled_tree_ids[key]
		if info is Dictionary:
			var id:String=info.get("id","")
			if id=="":
				var p=info.get("pos",[])
				id="pos_%d_%d_%d"%[roundi(p[0]),roundi(p[1]),roundi(p[2])] if p.size()==3 else str(key)
			if not result.has(id):result[id]=info.duplicate(true)
		else:result[key]=info
	return result

func _remember_damage() -> void:
	if _voxel_trunk and not _is_falling and not _restoring_remnant:
		damaged_tree_states[get_effective_id()]={"cuts":_voxel_trunk.export_cuts()}

func restore_damage() -> void:
	if _voxel_trunk and not _restoring_remnant:
		var saved:Dictionary=damaged_tree_states.get(get_effective_id(),{})
		if not saved.is_empty():
			_voxel_trunk.restore_cuts(saved.get("cuts",[]));_voxel_trunk._schedule()

static var _collision_cache: Dictionary = {}

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
		_restore_remnant()
		return
		
	add_to_group("choppable_trees")
	_apply_species_config()
	_setup_collision()
	_setup_audio()
	_setup_particles()
	_setup_voxel_trunk()
	_update_mesh_stage(0)
	restore_damage()

func init_tree(p_species: String, p_id: String = "") -> void:
	species = p_species.to_lower()
	tree_id = p_id
	if _is_already_felled():
		_restore_remnant()
		return
	_restoring_remnant = false
	_apply_species_config()
	if is_inside_tree():
		_setup_collision()
		_setup_voxel_trunk()
		_update_mesh_stage(0)
		restore_damage()

func _setup_voxel_trunk() -> void:
	if _voxel_trunk != null and is_instance_valid(_voxel_trunk):
		_voxel_trunk.hide()
		_voxel_trunk.queue_free()
		
	var cfg = SPECIES_CONFIG.get(species, SPECIES_CONFIG["birch"])
	_voxel_trunk = VoxelTreeTrunkScript.new()
	_voxel_trunk.name = "VoxelTrunk"
	add_child(_voxel_trunk)
	# Bind damage to the authored bark instead of rendering an oversized shell.
	_voxel_trunk.init_trunk(species, cfg["radius"], cfg["height"], 0.04)
	_voxel_trunk.strength_hits = max_hp
	_voxel_trunk.fracture_ready.connect(_on_fracture_ready)
	_voxel_trunk.mesh_updated.connect(_on_cut_mesh_updated)

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
	# Large splinters plus a denser spray of fine sawdust, no opaque smoke cloud.
	_particles = _make_wood_burst("WoodChips", 96, 0.70, Vector3(0.025, 0.006, 0.013), 2.0, 4.8)
	_dust_particles = _make_wood_burst("WoodSawdust", 160, 0.48, Vector3(0.004, 0.003, 0.004), 0.7, 2.4)

func _make_wood_burst(node_name: String, count: int, life: float, size: Vector3, min_speed: float, max_speed: float) -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.name = node_name
	emitter.emitting = false
	emitter.one_shot = true
	emitter.explosiveness = 1.0
	emitter.amount = count
	emitter.lifetime = life
	emitter.randomness = 0.25
	emitter.local_coords = false
	emitter.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 0.6, 1)
	process.spread = 52.0
	process.initial_velocity_min = min_speed
	process.initial_velocity_max = max_speed
	process.gravity = Vector3(0, -8.5, 0)
	process.scale_min = 0.55
	process.scale_max = 1.5
	process.angular_velocity_min = -420.0
	process.angular_velocity_max = 420.0
	process.color = chip_color
	emitter.process_material = process
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.roughness = 0.95
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	emitter.draw_pass_1 = mesh
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(emitter)
	return emitter

func _update_mesh_stage(stage: int) -> void:
	_current_stage = stage
	if _visual_node != null:
		_visual_node.hide()
		_visual_node.queue_free()
		
	# Damage/fracture is cut from the same authored model as the distant forest.
	# Legacy stage silhouettes must not reappear after activation or save reload.
	var path = preload("res://scripts/core/ExternalModels.gd").tree_path(species)
		
	if ResourceLoader.exists(path):
		var scene = load(path)
		if scene:
			_visual_node = scene.instantiate()
			add_child(_visual_node)
			if _voxel_trunk:
				_voxel_trunk.bind_visual(_visual_node)
			_update_cut_collision()

func _update_cut_collision() -> void:
	if _visual_node == null:
		return
	var cached_col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _collision_cache.has(species) and cached_col:
		cached_col.position=Vector3.ZERO
		cached_col.set_deferred("shape",_collision_cache[species])
		return
	var faces := PackedVector3Array()
	# Only trunk/branch bark, never canopy: leaves must not block axe impacts.
	for node in _visual_node.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var xform := global_transform.affine_inverse() * mi.global_transform
		for surface in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(surface)
			if mat == null or not ("bark" in mat.resource_name.to_lower() or "wood_cut" in mat.resource_name.to_lower()):
				continue
			var arrays := mi.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for v in verts: faces.append(xform * v)
			else:
				for i in indices: faces.append(xform * verts[i])
	if faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	_collision_cache[species]=shape
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.position = Vector3.ZERO
		col.set_deferred("shape", shape)

func hit(damage: int, hit_point: Vector3, player_pos: Vector3) -> bool:
	if _is_falling or _fall_preparing:
		return false
		
	var local_hit := to_local(hit_point)
	var cfg: Dictionary = SPECIES_CONFIG.get(species,SPECIES_CONFIG["birch"])
	if Vector2(local_hit.x,local_hit.z).length()>float(cfg["radius"])*1.5:return false
	current_hp = maxi(1, current_hp - damage)
	if _voxel_trunk:
		hit_point = _voxel_trunk.project_hit(hit_point)
	_play_hit_sound()
	_emit_chips(hit_point, player_pos)
	
	# No mesh/BVH rebuild on the gameplay thread. Fracture is decided by the
	# worker's weakest real cross-section, never by summed HP across the tree.
	var away := global_position - player_pos
	away.y = 0.0
	_fall_direction = away.normalized() if away.length_squared() > 0.001 else Vector3.FORWARD
	if _voxel_trunk:
		_voxel_trunk.carve(hit_point, (hit_point-player_pos).normalized(), damage)
		_remember_damage()
	return false

func _on_cut_mesh_updated() -> void:
	var strength := clampf(inverse_lerp(0.65,1.0,_voxel_trunk.remaining_ratio),0.0,1.0)
	current_hp = maxi(1,ceili(max_hp*strength))

func _play_hit_sound() -> void:
	# Exactly one fixed impact sample, emitted only here (not again on player).
	var sound := "res://assets/sounds/level_01/axe/axe_hit_wood_01.ogg"
	if ResourceLoader.exists(sound) and _audio_hit:
		_audio_hit.stream = load(sound)
		_audio_hit.pitch_scale = 1.0
		_audio_hit.play()

func _emit_chips(point: Vector3, player_pos: Vector3) -> void:
	var outward := point - global_position
	outward.y = 0.0
	if outward.length_squared() < 0.001:
		outward = player_pos - global_position
		outward.y = 0.0
	outward = outward.normalized()
	for emitter in [_particles, _dust_particles]:
		if emitter == null:
			continue
		# Identity world basis prevents tree yaw/scale from turning spray inward.
		emitter.global_transform = Transform3D(Basis.IDENTITY, point + outward * 0.025)
		var process := emitter.process_material as ParticleProcessMaterial
		process.direction = (outward + Vector3.UP * 0.45).normalized()
		process.color = chip_color
		emitter.restart()
		emitter.emitting = true

func _start_falling() -> void:
	if _is_falling or _fall_preparing: return
	_fall_preparing = true
	if _voxel_trunk: _voxel_trunk.request_fracture(_break_height)

func _on_fracture_ready(lower: ArrayMesh, upper: ArrayMesh, cut_y: float) -> void:
	damaged_tree_states.erase(get_effective_id())
	_break_height = cut_y
	_spawn_stump(lower)
	if _restoring_remnant:
		queue_free()
		return
	_fall_preparing = false
	_is_falling = true
	current_hp = 0
	remove_from_group("choppable_trees")
	set_collision_layer_value(2, false)
	var b := global_basis
	var pos := global_position
	var info := {"species": species, "pos": [pos.x,pos.y,pos.z], "id": tree_id,
		"cut_y": cut_y, "cuts": _voxel_trunk.export_cuts(),
		"basis": [b.x.x,b.x.y,b.x.z,b.y.x,b.y.y,b.y.z,b.z.x,b.z.y,b.z.z]}
	for session in get_tree().get_nodes_in_group("survival_session"):
		if is_instance_valid(session.get("vegetation")):session.vegetation.record_felling(get_effective_id())
	felled_tree_ids[get_effective_id()] = info
	if tree_id != "": felled_tree_ids[tree_id] = info
	felled_tree_ids["pos_%d_%d_%d" % [roundi(pos.x),roundi(pos.y),roundi(pos.z)]] = info
	if _visual_node: _visual_node.hide(); _visual_node.queue_free()
	if _voxel_trunk._mesh_instance: _voxel_trunk._mesh_instance.hide()
	_fall_pivot = Node3D.new()
	_fall_pivot.name = "FracturePivot"
	add_child(_fall_pivot)
	_fall_pivot.position.y = cut_y
	var top := MeshInstance3D.new()
	top.name = "BrokenUpperTree"
	top.mesh = upper
	_fall_pivot.add_child(top)
	top.position.y = -cut_y
	_visual_node = top
	_fall_progress = 0.0
	_target_fall_angle = _calculate_target_fall_angle()
	if _audio_fall: _audio_fall.play()

func _saved_felling() -> Dictionary:
	var key := get_effective_id()
	if felled_tree_ids.has(key):
		return felled_tree_ids[key] if felled_tree_ids[key] is Dictionary else {}
	key = "pos_%d_%d_%d" % [roundi(global_position.x),roundi(global_position.y),roundi(global_position.z)]
	var info = felled_tree_ids.get(key,{})
	return info if info is Dictionary else {}

func _restore_remnant() -> void:
	add_to_group("remnant_builders")
	_restoring_remnant = true
	_apply_species_config()
	_setup_voxel_trunk()
	_update_mesh_stage(0)
	if _visual_node: _visual_node.hide()
	var saved := _saved_felling()
	_break_height = float(saved.get("cut_y",0.6)) # Legacy saves have no cut height.
	_voxel_trunk.restore_cuts(saved.get("cuts",[]))
	_voxel_trunk.request_fracture(_break_height)

func _calculate_target_fall_angle() -> float:
	if not is_inside_tree():
		return deg_to_rad(88.0)
	var space_state = get_world_3d().direct_space_state
	if space_state == null:
		return deg_to_rad(88.0)
		
	var cfg = SPECIES_CONFIG.get(species, SPECIES_CONFIG["birch"])
	var tree_h: float = maxf(0.5, cfg["height"] - _break_height) * global_basis.y.length()
	var radius: float = cfg["radius"] * global_basis.x.length()
	var base_pos: Vector3 = global_transform * Vector3(0,_break_height,0)
	
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

func _spawn_stump(mesh: ArrayMesh) -> void:
	if not is_inside_tree(): return
	for stump in get_tree().get_nodes_in_group("permanent_stumps"):
		if stump is Node3D and stump.global_position.distance_squared_to(global_position) < 0.01: return
	var stump := StaticBody3D.new()
	stump.name = "RemainingTrunk"
	stump.collision_layer = 1
	stump.collision_mask = 0
	get_parent().add_child(stump)
	stump.global_transform = global_transform
	stump.add_to_group("permanent_stumps")
	stump.set_meta("cut_y",_break_height)
	stump.set_meta("tree_id",get_effective_id())
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	stump.add_child(visual)
	# Build one inexpensive stationary collider; never a per-hit triangle BVH.
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.height = maxf(0.05,_break_height)
	shape.radius = SPECIES_CONFIG.get(species,SPECIES_CONFIG["birch"])["radius"] * 0.65
	col.shape = shape
	col.position.y = _break_height * 0.5
	stump.add_child(col)
	for session in get_tree().get_nodes_in_group("survival_session"):
		if is_instance_valid(session.get("vegetation")):
			session.vegetation.call_deferred("attach_stump",stump,get_effective_id())

func _process(delta: float) -> void:
	if not _is_falling or _fall_pivot == null:
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
	
	# World fall direction converted to the tree's yaw/scale frame. Rotate only
	# the upper mesh around the cut, not the whole tree around its roots.
	var local_direction := global_basis.inverse() * _fall_direction
	local_direction.y = 0.0
	var axis := Vector3.UP.cross(local_direction.normalized()).normalized()
	if axis.length_squared() < 0.01: axis = Vector3.RIGHT
	_fall_pivot.basis = Basis(axis,current_angle)
	if _fall_progress > 0.35 and is_inside_tree():
		var space_state := get_world_3d().direct_space_state
		var tree_h: float = SPECIES_CONFIG.get(species,SPECIES_CONFIG["birch"])["height"]
		var tip: Vector3 = _visual_node.global_transform * Vector3(0,tree_h*0.85,0)
		var q := PhysicsRayQueryParameters3D.create(tip+Vector3.UP*1.5,tip-Vector3.UP*1.5,1)
		var contact := space_state.intersect_ray(q)
		if not contact.is_empty() and tip.y <= contact.position.y+0.3:
			_is_falling = false
			_on_tree_felled_complete()

func _on_tree_felled_complete() -> void:
	tree_felled.emit(species, global_position)
	
	# Spawn Wood Logs safely on ground (3 round logs)
	_spawn_logs()
	
	# Leave the separately parented lower trunk completely untouched.
	if _fall_pivot:
		var tween := create_tween()
		tween.tween_property(_fall_pivot,"scale",Vector3.ZERO,0.8)
		tween.tween_callback(queue_free)
	else: queue_free()

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
