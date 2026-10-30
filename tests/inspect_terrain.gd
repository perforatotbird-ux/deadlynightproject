extends SceneTree

func _init() -> void:
	var s = load("res://assets/models/terrain/terrain_256_chunks.glb")
	var inst = s.instantiate()
	var chunk = inst.find_child("Chunk_04_03", true, false)
	if chunk and chunk is MeshInstance3D:
		var aabb = chunk.mesh.get_aabb()
		print("CHUNK 04_03 transform: ", chunk.transform)
		print("CHUNK 04_03 mesh AABB: ", aabb)
		print("GLOBAL AABB: ", chunk.global_transform * aabb)
	else:
		print("CHUNK NOT FOUND OR NOT MESH: ", chunk)
		for child in inst.get_children():
			print("Child: ", child.name, " type: ", child.get_class())
	quit(0)
