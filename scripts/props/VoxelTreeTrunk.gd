extends Node3D
class_name VoxelTreeTrunk

# Voxel types
const VOXEL_AIR: int = 0
const VOXEL_BARK: int = 1
const VOXEL_WOOD: int = 2

@export var species: String = "birch"
@export var voxel_size: float = 0.08
@export var trunk_radius: float = 0.35
@export var trunk_height: float = 3.2

var grid_w: int = 0
var grid_h: int = 0
var grid_r: int = 0
var center_x: int = 0
var center_z: int = 0

# 3D grid data: 1 byte per voxel
var _voxels: PackedByteArray = PackedByteArray()
var _mesh_instance: MeshInstance3D = null

# Materials
var _mat_bark: StandardMaterial3D = null
var _mat_wood: StandardMaterial3D = null

# Cross-section solid count per horizontal Y layer for instant structural check
var _layer_solid_counts: PackedInt32Array = PackedInt32Array()
var _layer_initial_counts: PackedInt32Array = PackedInt32Array()

# Species color palettes
const SPECIES_PALETTES = {
	"birch": {
		"bark": Color(0.92, 0.90, 0.86),
		"wood": Color(0.96, 0.96, 0.86),
		"roughness": 0.85
	},
	"spruce": {
		"bark": Color(0.29, 0.22, 0.16),
		"wood": Color(0.82, 0.41, 0.12),
		"roughness": 0.88
	},
	"beech": {
		"bark": Color(0.48, 0.49, 0.49),
		"wood": Color(0.93, 0.86, 0.51),
		"roughness": 0.80
	},
	"oak": {
		"bark": Color(0.24, 0.15, 0.10),
		"wood": Color(0.55, 0.35, 0.17),
		"roughness": 0.90
	}
}

func init_trunk(p_species: String, p_radius: float = 0.35, p_height: float = 3.2, p_voxel_size: float = 0.08) -> void:
	species = p_species.to_lower()
	trunk_radius = p_radius
	trunk_height = p_height
	voxel_size = p_voxel_size
	
	_setup_materials()
	_allocate_grid()
	_populate_voxels()
	_rebuild_mesh()

func _setup_materials() -> void:
	var pal = SPECIES_PALETTES.get(species, SPECIES_PALETTES["birch"])
	
	_mat_bark = StandardMaterial3D.new()
	_mat_bark.resource_name = "M_Bark_Voxel_" + species
	_mat_bark.albedo_color = pal["bark"]
	_mat_bark.roughness = pal["roughness"]
	_mat_bark.cull_mode = BaseMaterial3D.CULL_BACK
	
	_mat_wood = StandardMaterial3D.new()
	_mat_wood.resource_name = "M_Wood_Cut_Voxel_" + species
	_mat_wood.albedo_color = pal["wood"]
	_mat_wood.roughness = 0.65
	_mat_wood.cull_mode = BaseMaterial3D.CULL_BACK

func _allocate_grid() -> void:
	grid_r = int(ceil(trunk_radius / voxel_size)) + 1
	grid_w = grid_r * 2 + 1
	grid_h = int(ceil(trunk_height / voxel_size))
	center_x = grid_r
	center_z = grid_r
	
	var total_cells = grid_w * grid_h * grid_w
	_voxels.resize(total_cells)
	_voxels.fill(VOXEL_AIR)
	
	_layer_solid_counts.resize(grid_h)
	_layer_solid_counts.fill(0)
	_layer_initial_counts.resize(grid_h)
	_layer_initial_counts.fill(0)

func _populate_voxels() -> void:
	var r_sq = trunk_radius * trunk_radius
	var bark_thickness = voxel_size * 1.05
	var inner_r_sq = (trunk_radius - bark_thickness) * (trunk_radius - bark_thickness)
	
	for y in range(grid_h):
		var layer_count = 0
		for z in range(grid_w):
			var dz = (z - center_z) * voxel_size
			for x in range(grid_w):
				var dx = (x - center_x) * voxel_size
				var d_sq = dx * dx + dz * dz
				if d_sq <= r_sq:
					var idx = _coord_to_index(x, y, z)
					if d_sq >= inner_r_sq:
						_voxels[idx] = VOXEL_BARK
					else:
						_voxels[idx] = VOXEL_WOOD
					layer_count += 1
		_layer_solid_counts[y] = layer_count
		_layer_initial_counts[y] = layer_count

func _coord_to_index(x: int, y: int, z: int) -> int:
	return x + y * grid_w + z * grid_w * grid_h

func _is_in_bounds(x: int, y: int, z: int) -> bool:
	return x >= 0 and x < grid_w and y >= 0 and y < grid_h and z >= 0 and z < grid_w

func carve(world_hit_pos: Vector3, world_strike_dir: Vector3, damage: int = 1) -> Dictionary:
	var local_hit = to_local(world_hit_pos) if is_inside_tree() else (world_hit_pos - global_position)
	
	# Clamp hit height to choppable trunk range
	local_hit.y = clampf(local_hit.y, voxel_size, trunk_height - voxel_size)
	
	# Determine carving notch size based on damage & blade impact
	var carve_radius_h = 0.16 + float(damage) * 0.02
	var carve_radius_v = 0.12 + float(damage) * 0.015
	var r_h_sq = carve_radius_h * carve_radius_h
	
	# Center of carving volume penetrating into the trunk towards the central axis
	var hit_center_dir = Vector2(-local_hit.x, -local_hit.z).normalized()
	var penetration_depth = 0.07 + float(damage) * 0.025
	var carve_center_x = local_hit.x + hit_center_dir.x * penetration_depth
	var carve_center_z = local_hit.z + hit_center_dir.y * penetration_depth
	var carve_center_y = local_hit.y
	
	# Bounding box in grid indices
	var min_x = clampi(int(floor((carve_center_x - carve_radius_h) / voxel_size)) + center_x, 0, grid_w - 1)
	var max_x = clampi(int(ceil((carve_center_x + carve_radius_h) / voxel_size)) + center_x, 0, grid_w - 1)
	var min_y = clampi(int(floor((carve_center_y - carve_radius_v) / voxel_size)), 0, grid_h - 1)
	var max_y = clampi(int(ceil((carve_center_y + carve_radius_v) / voxel_size)), 0, grid_h - 1)
	var min_z = clampi(int(floor((carve_center_z - carve_radius_h) / voxel_size)) + center_z, 0, grid_w - 1)
	var max_z = clampi(int(ceil((carve_center_z + carve_radius_h) / voxel_size)) + center_z, 0, grid_w - 1)
	
	var carved_count = 0
	for y in range(min_y, max_y + 1):
		var dy = (y * voxel_size - carve_center_y) / carve_radius_v
		var dy_sq = dy * dy
		if dy_sq > 1.0:
			continue
			
		for z in range(min_z, max_z + 1):
			var dz = (z - center_z) * voxel_size - carve_center_z
			for x in range(min_x, max_x + 1):
				var dx = (x - center_x) * voxel_size - carve_center_x
				# Ellipsoid test
				if (dx * dx + dz * dz) / r_h_sq + dy_sq <= 1.0:
					var idx = _coord_to_index(x, y, z)
					if _voxels[idx] != VOXEL_AIR:
						_voxels[idx] = VOXEL_AIR
						_layer_solid_counts[y] -= 1
						carved_count += 1
						
	# Check structural failure: find minimum remaining cross section
	var hit_y_idx = clampi(int(round(local_hit.y / voxel_size)), 0, grid_h - 1)
	var min_ratio = 1.0
	var weakest_y = local_hit.y
	
	for y in range(maxi(0, hit_y_idx - 2), mini(grid_h, hit_y_idx + 3)):
		var init_cnt = _layer_initial_counts[y]
		if init_cnt > 0:
			var ratio = float(_layer_solid_counts[y]) / float(init_cnt)
			if ratio < min_ratio:
				min_ratio = ratio
				weakest_y = float(y) * voxel_size
				
	# Rebuild voxel mesh to display carved notch
	_rebuild_mesh()
	
	var is_severed = (min_ratio <= 0.28) # Under 28% wood remaining means trunk snaps
	
	return {
		"carved_voxels": carved_count,
		"severed": is_severed,
		"cut_y": weakest_y,
		"remaining_ratio": min_ratio
	}

func _rebuild_mesh() -> void:
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "VoxelTrunkMesh"
		add_child(_mesh_instance)
		
	var mesh = _generate_mesh(0, grid_h)
	_mesh_instance.mesh = mesh

func _generate_mesh(min_layer: int, max_layer: int) -> ArrayMesh:
	# Face templates for 6 directions: +X, -X, +Y, -Y, +Z, -Z
	var face_corners = [
		# +X face (normal: 1, 0, 0)
		[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1), Vector3(1, 0, 0)],
		# -X face (normal: -1, 0, 0)
		[Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0), Vector3(-1, 0, 0)],
		# +Y face (normal: 0, 1, 0)
		[Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)],
		# -Y face (normal: 0, -1, 0)
		[Vector3(0, 0, 1), Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, -1, 0)],
		# +Z face (normal: 0, 0, 1)
		[Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1), Vector3(0, 0, 1)],
		# -Z face (normal: 0, 0, -1)
		[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)]
	]
	
	var offsets = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1)
	]
	
	var v_bark = PackedVector3Array()
	var n_bark = PackedVector3Array()
	var uv_bark = PackedVector2Array()
	var i_bark = PackedInt32Array()
	
	var v_wood = PackedVector3Array()
	var n_wood = PackedVector3Array()
	var uv_wood = PackedVector2Array()
	var i_wood = PackedInt32Array()
	
	# Pre-allocate comfortable capacity
	v_bark.resize(6000)
	n_bark.resize(6000)
	uv_bark.resize(6000)
	i_bark.resize(9000)
	
	v_wood.resize(3000)
	n_wood.resize(3000)
	uv_wood.resize(3000)
	i_wood.resize(4500)
	
	var cb_v = 0
	var cb_i = 0
	var cw_v = 0
	var cw_i = 0
	
	var cl_min = clampi(min_layer, 0, grid_h - 1)
	var cl_max = clampi(max_layer, 1, grid_h)
	
	for y in range(cl_min, cl_max):
		var base_y = y * voxel_size
		for z in range(grid_w):
			var base_z = (z - center_z) * voxel_size
			for x in range(grid_w):
				var idx = _coord_to_index(x, y, z)
				var val = _voxels[idx]
				if val == VOXEL_AIR:
					continue
					
				var base_x = (x - center_x) * voxel_size
				var base_pos = Vector3(base_x, base_y, base_z)
				
				for f in range(6):
					var off = offsets[f]
					var nx = x + off.x
					var ny = y + off.y
					var nz = z + off.z
					var is_air = true
					if _is_in_bounds(nx, ny, nz):
						if _voxels[_coord_to_index(nx, ny, nz)] != VOXEL_AIR:
							is_air = false
					if not is_air:
						continue
						
					var fc = face_corners[f]
					var norm = fc[4]
					
					# If voxel is wood, or if bark faces a carved/interior cavity -> Cut Wood material
					var is_wood_face = (val == VOXEL_WOOD)
					if val == VOXEL_BARK and f in [2, 3]: # Top or bottom face exposed by cut
						is_wood_face = true
						
					if not is_wood_face:
						# Bark Surface
						if cb_v + 4 > v_bark.size():
							v_bark.resize(v_bark.size() * 2)
							n_bark.resize(n_bark.size() * 2)
							uv_bark.resize(uv_bark.size() * 2)
						if cb_i + 6 > i_bark.size():
							i_bark.resize(i_bark.size() * 2)
							
						var s_idx = cb_v
						v_bark[cb_v] = base_pos + fc[0] * voxel_size
						v_bark[cb_v + 1] = base_pos + fc[1] * voxel_size
						v_bark[cb_v + 2] = base_pos + fc[2] * voxel_size
						v_bark[cb_v + 3] = base_pos + fc[3] * voxel_size
						
						n_bark[cb_v] = norm
						n_bark[cb_v + 1] = norm
						n_bark[cb_v + 2] = norm
						n_bark[cb_v + 3] = norm
						
						uv_bark[cb_v] = Vector2(0, 0)
						uv_bark[cb_v + 1] = Vector2(0, 1)
						uv_bark[cb_v + 2] = Vector2(1, 1)
						uv_bark[cb_v + 3] = Vector2(1, 0)
						
						i_bark[cb_i] = s_idx
						i_bark[cb_i + 1] = s_idx + 1
						i_bark[cb_i + 2] = s_idx + 2
						i_bark[cb_i + 3] = s_idx
						i_bark[cb_i + 4] = s_idx + 2
						i_bark[cb_i + 5] = s_idx + 3
						
						cb_v += 4
						cb_i += 6
					else:
						# Cut Wood Surface
						if cw_v + 4 > v_wood.size():
							v_wood.resize(v_wood.size() * 2)
							n_wood.resize(n_wood.size() * 2)
							uv_wood.resize(uv_wood.size() * 2)
						if cw_i + 6 > i_wood.size():
							i_wood.resize(i_wood.size() * 2)
							
						var s_idx = cw_v
						v_wood[cw_v] = base_pos + fc[0] * voxel_size
						v_wood[cw_v + 1] = base_pos + fc[1] * voxel_size
						v_wood[cw_v + 2] = base_pos + fc[2] * voxel_size
						v_wood[cw_v + 3] = base_pos + fc[3] * voxel_size
						
						n_wood[cw_v] = norm
						n_wood[cw_v + 1] = norm
						n_wood[cw_v + 2] = norm
						n_wood[cw_v + 3] = norm
						
						uv_wood[cw_v] = Vector2(0, 0)
						uv_wood[cw_v + 1] = Vector2(0, 1)
						uv_wood[cw_v + 2] = Vector2(1, 1)
						uv_wood[cw_v + 3] = Vector2(1, 0)
						
						i_wood[cw_i] = s_idx
						i_wood[cw_i + 1] = s_idx + 1
						i_wood[cw_i + 2] = s_idx + 2
						i_wood[cw_i + 3] = s_idx
						i_wood[cw_i + 4] = s_idx + 2
						i_wood[cw_i + 5] = s_idx + 3
						
						cw_v += 4
						cw_i += 6

	var mesh = ArrayMesh.new()
	
	if cb_v > 0:
		v_bark.resize(cb_v)
		n_bark.resize(cb_v)
		uv_bark.resize(cb_v)
		i_bark.resize(cb_i)
		var arr_b = []
		arr_b.resize(Mesh.ARRAY_MAX)
		arr_b[Mesh.ARRAY_VERTEX] = v_bark
		arr_b[Mesh.ARRAY_NORMAL] = n_bark
		arr_b[Mesh.ARRAY_TEX_UV] = uv_bark
		arr_b[Mesh.ARRAY_INDEX] = i_bark
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr_b)
		mesh.surface_set_material(0, _mat_bark)
		
	if cw_v > 0:
		v_wood.resize(cw_v)
		n_wood.resize(cw_v)
		uv_wood.resize(cw_v)
		i_wood.resize(cw_i)
		var arr_w = []
		arr_w.resize(Mesh.ARRAY_MAX)
		arr_w[Mesh.ARRAY_VERTEX] = v_wood
		arr_w[Mesh.ARRAY_NORMAL] = n_wood
		arr_w[Mesh.ARRAY_TEX_UV] = uv_wood
		arr_w[Mesh.ARRAY_INDEX] = i_wood
		var surf_idx = mesh.get_surface_count()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr_w)
		mesh.surface_set_material(surf_idx, _mat_wood)
		
	return mesh

func build_stump_mesh(cut_y: float) -> ArrayMesh:
	var cut_layer = clampi(int(round(cut_y / voxel_size)), 1, grid_h)
	return _generate_mesh(0, cut_layer)

func build_upper_mesh(cut_y: float) -> ArrayMesh:
	var cut_layer = clampi(int(round(cut_y / voxel_size)), 0, grid_h - 1)
	return _generate_mesh(cut_layer, grid_h)
