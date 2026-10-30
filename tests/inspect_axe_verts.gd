extends SceneTree

func _init() -> void:
	var axe_scene = load("res://assets/models/props/axe_iron.glb")
	var inst = axe_scene.instantiate()
	var mesh_inst = inst.find_child("Axe_Iron", true, false) as MeshInstance3D
	var mesh = mesh_inst.mesh
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(mesh, 0)
	print("Surface count:", mesh.get_surface_count())
	for s in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(s)
		var verts = arrays[Mesh.ARRAY_VERTEX]
		var min_v = Vector3(1e9, 1e9, 1e9)
		var max_v = Vector3(-1e9, -1e9, -1e9)
		for v in verts:
			min_v = min_v.min(v)
			max_v = max_v.max(v)
		print("Surface %d (%s) count %d: bounds [%s -> %s]" % [s, mesh.surface_get_material(s).resource_name, verts.size(), str(min_v), str(max_v)])
	quit(0)
