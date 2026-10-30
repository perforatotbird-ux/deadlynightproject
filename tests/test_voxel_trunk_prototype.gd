extends SceneTree

const VoxelSize: float = 0.08

func _init() -> void:
	print("Testing Voxel Trunk Prototype...")
	var t0 = Time.get_ticks_usec()
	
	var radius = 0.35
	var height = 3.0
	var grid_r = int(ceil(radius / VoxelSize)) + 1
	var grid_w = grid_r * 2 + 1
	var grid_h = int(ceil(height / VoxelSize))
	
	print("Grid dims: %d x %d x %d (total %d cells)" % [grid_w, grid_h, grid_w, grid_w * grid_h * grid_w])
	
	# Byte array for voxels: 0=air, 1=bark, 2=wood
	var data = PackedByteArray()
	data.resize(grid_w * grid_h * grid_w)
	data.fill(0)
	
	var center_x = grid_r
	var center_z = grid_r
	
	var solid_count = 0
	for y in range(grid_h):
		for z in range(grid_w):
			for x in range(grid_w):
				var dx = (x - center_x) * VoxelSize
				var dz = (z - center_z) * VoxelSize
				var d_sq = dx * dx + dz * dz
				if d_sq <= radius * radius:
					var idx = x + y * grid_w + z * grid_w * grid_h
					if d_sq >= (radius - VoxelSize) * (radius - VoxelSize):
						data[idx] = 1 # Bark
					else:
						data[idx] = 2 # Wood
					solid_count += 1
					
	var t1 = Time.get_ticks_usec()
	print("Init time: %.2f ms, solid voxels: %d" % [(t1 - t0) / 1000.0, solid_count])
	
	# Test carve at height y=1.2m, x=radius, z=0 (hitting from +X)
	var hit_local = Vector3(radius, 1.2, 0.0)
	var carve_radius = 0.20
	var carve_r_sq = carve_radius * carve_radius
	var carved_count = 0
	
	var t2 = Time.get_ticks_usec()
	for y in range(grid_h):
		var dy = y * VoxelSize - hit_local.y
		if absf(dy) > carve_radius:
			continue
		for z in range(grid_w):
			var dz = (z - center_z) * VoxelSize - hit_local.z
			for x in range(grid_w):
				var dx = (x - center_x) * VoxelSize - hit_local.x
				if dx * dx + dy * dy + dz * dz <= carve_r_sq:
					var idx = x + y * grid_w + z * grid_w * grid_h
					if data[idx] != 0:
						data[idx] = 0
						carved_count += 1
						
	var t3 = Time.get_ticks_usec()
	print("Carve time: %.2f ms, carved voxels: %d" % [(t3 - t2) / 1000.0, carved_count])
	
	# Benchmark face generation
	var t4 = Time.get_ticks_usec()
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var face_count = 0
	
	# Directions: +X, -X, +Y, -Y, +Z, -Z
	var offsets = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1)
	]
	
	for y in range(grid_h):
		for z in range(grid_w):
			for x in range(grid_w):
				var idx = x + y * grid_w + z * grid_w * grid_h
				var val = data[idx]
				if val == 0:
					continue
				for off in offsets:
					var nx = x + off.x
					var ny = y + off.y
					var nz = z + off.z
					var is_air = true
					if nx >= 0 and nx < grid_w and ny >= 0 and ny < grid_h and nz >= 0 and nz < grid_w:
						var n_idx = nx + ny * grid_w + nz * grid_w * grid_h
						is_air = (data[n_idx] == 0)
					if is_air:
						face_count += 1
						
	var t5 = Time.get_ticks_usec()
	print("Meshing exposed face count: %d, scan time: %.2f ms" % [face_count, (t5 - t4) / 1000.0])
	print("PROTOTYPE TEST COMPLETED SUCCESSFULLY.")
	quit(0)
