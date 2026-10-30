extends SceneTree

func _init() -> void:
	var s = load("res://assets/models/props/axe_iron.glb")
	if not s:
		print("FAILED TO LOAD AXE")
		quit(1)
	var inst = s.instantiate()
	print("AXE LOADED OK: ", inst)
	for child in inst.get_children():
		print("  child: ", child.name, " type: ", child.get_class())
		if child is MeshInstance3D:
			print("  mesh AABB: ", child.mesh.get_aabb())
			print("  materials: ", child.get_surface_override_material_count())
			for i in range(child.mesh.get_surface_count()):
				print("    surface ", i, " mat: ", child.mesh.surface_get_material(i))
	quit(0)
