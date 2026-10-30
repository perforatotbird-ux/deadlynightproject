extends SceneTree

func _init() -> void:
	var axe_scene = load("res://assets/models/props/axe_iron.glb")
	if not axe_scene:
		print("FAIL: cannot load axe_iron.glb")
		quit(1)
		return
	var inst = axe_scene.instantiate()
	var mesh_inst = inst.find_child("Axe_Iron", true, false) as MeshInstance3D
	print("Loaded axe mesh:", mesh_inst)
	print("Mesh AABB:", mesh_inst.mesh.get_aabb())
	
	# Current pivot settings in PlayerController:
	# pos: (0.26, -0.25, -0.42)
	# rot: (-20.0, -65.0, 15.0)
	var cur_rot = Vector3(-20.0, -65.0, 15.0)
	var cur_basis = Basis.from_euler(Vector3(deg_to_rad(cur_rot.x), deg_to_rad(cur_rot.y), deg_to_rad(cur_rot.z)))
	# In the axe mesh, the blade is along -Z, handle along +Y
	var blade_local = Vector3(0, 0, -1)
	var handle_local = Vector3(0, 1, 0)
	print("CURRENT BLADE DIR in cam space:", cur_basis * blade_local)
	print("CURRENT HANDLE DIR in cam space:", cur_basis * handle_local)
	
	# If blade faces right at 45 degrees towards the center tree trunk:
	# From right hand (x=0.26, z=-0.42) towards center tree (x=0, z=-2.5):
	# The angle in XZ plane is around -10 to -20 degrees towards center.
	# The user asked:
	# "Сейчас лезвие топора смотрит влево, разверни его в право под 45* градусов. 
	#  Лезвие модели топора должно быть повёрнуто к стволу дерева под 45* градусов."
	# If Y rotation is rotated to the right by +45 degrees or set to an angle where blade faces right-forward at 45*:
	for y_rot in [-45.0, -20.0, 0.0, 25.0, 45.0, 65.0]:
		var test_rot = Vector3(-15.0, y_rot, 10.0)
		var tb = Basis.from_euler(Vector3(deg_to_rad(test_rot.x), deg_to_rad(test_rot.y), deg_to_rad(test_rot.z)))
		print("Test rot Y=%f: blade dir=%s" % [y_rot, str(tb * blade_local)])
		
	quit(0)
