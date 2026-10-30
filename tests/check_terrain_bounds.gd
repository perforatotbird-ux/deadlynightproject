extends SceneTree

func _init() -> void:
	var s = load("res://assets/models/terrain/terrain_256_chunks.glb")
	var inst = s.instantiate()
	var min_pos = Vector3(1e9, 1e9, 1e9)
	var max_pos = Vector3(-1e9, -1e9, -1e9)
	var chunks = []
	for child in inst.get_children():
		if child is MeshInstance3D:
			var aabb = child.mesh.get_aabb()
			min_pos.x = minf(min_pos.x, aabb.position.x)
			min_pos.y = minf(min_pos.y, aabb.position.y)
			min_pos.z = minf(min_pos.z, aabb.position.z)
			max_pos.x = maxf(max_pos.x, aabb.position.x + aabb.size.x)
			max_pos.y = maxf(max_pos.y, aabb.position.y + aabb.size.y)
			max_pos.z = maxf(max_pos.z, aabb.position.z + aabb.size.z)
			if child.name.contains("04_03") or child.name.contains("00_00") or child.name.contains("15_15"):
				chunks.append("%s: AABB = %s" % [child.name, str(aabb)])
	print("ALL 256 CHUNKS BOUNDS IN GODOT:")
	print("  MIN: ", min_pos)
	print("  MAX: ", max_pos)
	print("SAMPLE CHUNKS:")
	for c in chunks:
		print("  ", c)
	quit(0)
