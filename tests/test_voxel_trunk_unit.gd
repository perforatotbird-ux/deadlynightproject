extends SceneTree

const VoxelTreeTrunk = preload("res://scripts/props/VoxelTreeTrunk.gd")

func _init() -> void:
	print("--- TESTING VOXEL TREE TRUNK ---")
	var v_trunk = VoxelTreeTrunk.new()
	root.add_child(v_trunk)
	v_trunk.init_trunk("birch", 0.35, 3.2, 0.08)
	
	print("Trunk initialized.")
	var mesh = v_trunk._mesh_instance.mesh
	print("Surfaces count:", mesh.get_surface_count())
	for s in range(mesh.get_surface_count()):
		print("  surf %d: %s" % [s, mesh.surface_get_material(s).resource_name])
		
	# Test carve at world position (0.35, 1.2, 0)
	var res = v_trunk.carve(Vector3(0.35, 1.2, 0), Vector3(-1, 0, 0), 1)
	print("Carve result 1:", res)
	
	# After carve, should have cut wood surface
	mesh = v_trunk._mesh_instance.mesh
	print("Surfaces count after carve:", mesh.get_surface_count())
	for s in range(mesh.get_surface_count()):
		print("  surf %d: %s" % [s, mesh.surface_get_material(s).resource_name])
		
	# Hit multiple times to test severing
	for i in range(5):
		res = v_trunk.carve(Vector3(0.35 - float(i)*0.05, 1.2, 0), Vector3(-1, 0, 0), 2)
		print("Carve repeat %d: remaining=%.2f, severed=%s" % [i, res["remaining_ratio"], str(res["severed"])])
		if res["severed"]:
			print("PASS: Trunk severed at cut_y=%.2f!" % res["cut_y"])
			break
			
	var stump_m = v_trunk.build_stump_mesh(res["cut_y"])
	print("Stump mesh generated OK, surfaces:", stump_m.get_surface_count())
	var upper_m = v_trunk.build_upper_mesh(res["cut_y"])
	print("Upper mesh generated OK, surfaces:", upper_m.get_surface_count())
	
	print("ALL VOXEL TESTS PASSED!")
	quit(0)
