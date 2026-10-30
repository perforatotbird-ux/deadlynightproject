extends SceneTree

func _init() -> void:
	var s = load("res://assets/models/trees/tree_birch.glb")
	var inst = s.instantiate()
	print("Tree Birch instance:", inst)
	for c in inst.get_children():
		print("  child:", c.name, " type:", c.get_class())
		if c is MeshInstance3D:
			print("    mesh AABB:", c.mesh.get_aabb())
			for sm in range(c.mesh.get_surface_count()):
				print("    surf %d: %s" % [sm, c.mesh.surface_get_material(sm).resource_name])
	quit(0)
