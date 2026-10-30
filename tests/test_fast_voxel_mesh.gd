extends SceneTree

const VoxelSize: float = 0.08

func _init() -> void:
	var radius = 0.35
	var height = 3.0
	var grid_r = int(ceil(radius / VoxelSize)) + 1
	var grid_w = grid_r * 2 + 1
	var grid_h = int(ceil(height / VoxelSize))
	
	var data = PackedByteArray()
	data.resize(grid_w * grid_h * grid_w)
	data.fill(0)
	var center_x = grid_r
	var center_z = grid_r
	
	for y in range(grid_h):
		for z in range(grid_w):
			for x in range(grid_w):
				var dx = (x - center_x) * VoxelSize
				var dz = (z - center_z) * VoxelSize
				var d_sq = dx * dx + dz * dz
				if d_sq <= radius * radius:
					var idx = x + y * grid_w + z * grid_w * grid_h
					if d_sq >= (radius - VoxelSize) * (radius - VoxelSize):
						data[idx] = 1
					else:
						data[idx] = 2
						
	# Benchmark fast direct ArrayMesh generation
	var t0 = Time.get_ticks_usec()
	var verts_bark = PackedVector3Array()
	var normals_bark = PackedVector3Array()
	var uvs_bark = PackedVector2Array()
	var indices_bark = PackedInt32Array()
	
	var verts_wood = PackedVector3Array()
	var normals_wood = PackedVector3Array()
	var uvs_wood = PackedVector2Array()
	var indices_wood = PackedInt32Array()
	
	# Pre-allocate
	verts_bark.resize(10000)
	normals_bark.resize(10000)
	uvs_bark.resize(10000)
	indices_bark.resize(15000)
	
	var v_bark_count = 0
	var i_bark_count = 0
	
	# Face template: 6 directions
	# +X, -X, +Y, -Y, +Z, -Z
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
	
	for y in range(grid_h):
		var base_y = y * VoxelSize
		for z in range(grid_w):
			var base_z = (z - center_z) * VoxelSize
			for x in range(grid_w):
				var idx = x + y * grid_w + z * grid_w * grid_h
				var val = data[idx]
				if val == 0:
					continue
				var base_x = (x - center_x) * VoxelSize
				var base_pos = Vector3(base_x, base_y, base_z)
				
				for f in range(6):
					var off = offsets[f]
					var nx = x + off.x
					var ny = y + off.y
					var nz = z + off.z
					var is_air = true
					if nx >= 0 and nx < grid_w and ny >= 0 and ny < grid_h and nz >= 0 and nz < grid_w:
						if data[nx + ny * grid_w + nz * grid_w * grid_h] != 0:
							is_air = false
					if is_air:
						var fc = face_corners[f]
						var n = fc[4]
						var start_v = v_bark_count
						if v_bark_count + 4 > verts_bark.size():
							verts_bark.resize(verts_bark.size() * 2)
							normals_bark.resize(normals_bark.size() * 2)
							uvs_bark.resize(uvs_bark.size() * 2)
						if i_bark_count + 6 > indices_bark.size():
							indices_bark.resize(indices_bark.size() * 2)
							
						verts_bark[v_bark_count] = base_pos + fc[0] * VoxelSize
						verts_bark[v_bark_count + 1] = base_pos + fc[1] * VoxelSize
						verts_bark[v_bark_count + 2] = base_pos + fc[2] * VoxelSize
						verts_bark[v_bark_count + 3] = base_pos + fc[3] * VoxelSize
						
						normals_bark[v_bark_count] = n
						normals_bark[v_bark_count + 1] = n
						normals_bark[v_bark_count + 2] = n
						normals_bark[v_bark_count + 3] = n
						
						uvs_bark[v_bark_count] = Vector2(0, 0)
						uvs_bark[v_bark_count + 1] = Vector2(0, 1)
						uvs_bark[v_bark_count + 2] = Vector2(1, 1)
						uvs_bark[v_bark_count + 3] = Vector2(1, 0)
						
						indices_bark[i_bark_count] = start_v
						indices_bark[i_bark_count + 1] = start_v + 1
						indices_bark[i_bark_count + 2] = start_v + 2
						indices_bark[i_bark_count + 3] = start_v
						indices_bark[i_bark_count + 4] = start_v + 2
						indices_bark[i_bark_count + 5] = start_v + 3
						
						v_bark_count += 4
						i_bark_count += 6

	verts_bark.resize(v_bark_count)
	normals_bark.resize(v_bark_count)
	uvs_bark.resize(v_bark_count)
	indices_bark.resize(i_bark_count)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts_bark
	arrays[Mesh.ARRAY_NORMAL] = normals_bark
	arrays[Mesh.ARRAY_TEX_UV] = uvs_bark
	arrays[Mesh.ARRAY_INDEX] = indices_bark
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var t1 = Time.get_ticks_usec()
	print("Direct ArrayMesh build time: %.2f ms! Verts: %d, Indices: %d" % [(t1 - t0) / 1000.0, v_bark_count, i_bark_count])
	quit(0)
