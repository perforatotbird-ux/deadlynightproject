extends SceneTree

func _init() -> void:
	var s = load("res://assets/models/terrain/terrain_256_chunks.glb")
	var inst = s.instantiate()
	root.add_child(inst)
	
	# Sample heights for all 12 POIs
	var pois = {
		"SPAWN": Vector2(-900.0, 1100.0),
		"BRIDGE": Vector2(925.0, -37.0),
		"FORD": Vector2(795.0, -520.0),
		"FORK": Vector2(600.0, -200.0),
		"LOOKOUT": Vector2(700.0, -1550.0),
		"PEAK": Vector2(1500.0, -1500.0),
		"MINE_YARD": Vector2(1100.0, -1180.0),
		"MINE_ADIT": Vector2(1130.0, -1210.0),
		"HUT": Vector2(0.0, -300.0),
		"CLEARCUT": Vector2(-600.0, 0.0),
		"WINDFALL": Vector2(-1400.0, 600.0),
		"MEADOW": Vector2(-400.0, -400.0)
	}
	
	# Collect all meshes
	var all_meshes: Array[MeshInstance3D] = []
	_find_meshes(inst, all_meshes)
	print("FOUND %d CHUNK MESHES" % all_meshes.size())
	
	for name in pois.keys():
		var pt = pois[name]
		var best_v = Vector3.ZERO
		var best_d = 1e9
		for m in all_meshes:
			var aabb = m.mesh.get_aabb()
			if pt.x >= aabb.position.x - 5 and pt.x <= aabb.position.x + aabb.size.x + 5 and pt.y >= aabb.position.z - 5 and pt.y <= aabb.position.z + aabb.size.z + 5:
				var mdt = MeshDataTool.new()
				mdt.create_from_surface(m.mesh, 0)
				for i in range(mdt.get_vertex_count()):
					var v = mdt.get_vertex(i)
					var d = Vector2(v.x - pt.x, v.z - pt.y).length()
					if d < best_d:
						best_d = d
						best_v = v
		print("POI %-10s at (%7.1f, %7.1f) -> Terrain Vert: (%7.1f, %5.2f, %7.1f) [dist: %.2f m]" % [
			name, pt.x, pt.y, best_v.x, best_v.y, best_v.z, best_d
		])
	quit(0)

func _find_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_find_meshes(c, out)
