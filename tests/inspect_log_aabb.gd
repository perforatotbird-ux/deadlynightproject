extends SceneTree

func _init() -> void:
	var path = "res://assets/models/trees/tree_birch_log.glb"
	var scene = load(path)
	var inst = scene.instantiate()
	var mesh_inst = inst.find_child("Log_birch", true, false) as MeshInstance3D
	if not mesh_inst:
		for c in inst.get_children():
			if c is MeshInstance3D:
				mesh_inst = c
				break
	print("Log mesh AABB:", mesh_inst.mesh.get_aabb())
	quit(0)
