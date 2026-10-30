extends SceneTree

func _init() -> void:
	var s = load("res://assets/models/terrain/terrain_256_chunks.glb")
	var inst = s.instantiate()
	root.add_child(inst)
	
	# Chunk 04_03 in Godot is at X in [-1000, -750], Z in [1000, 1250]
	var chunk = inst.find_child("Chunk_04_03", true, false) as MeshInstance3D
	var mesh = chunk.mesh
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(mesh, 0)
	print("CHUNK 04_03 VERTICES COUNT: ", mdt.get_vertex_count())
	
	# Find vertex closest to X = -900, Z = 1100
	var best_dist = 1e9
	var best_vert = Vector3.ZERO
	for i in range(mdt.get_vertex_count()):
		var v = mdt.get_vertex(i)
		var d = Vector2(v.x - (-900.0), v.z - 1100.0).length()
		if d < best_dist:
			best_dist = d
			best_vert = v
			
	print("CLOSEST VERTEX TO (-900, 1100): ", best_vert, " dist: ", best_dist)
	quit(0)
