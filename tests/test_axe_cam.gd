extends SceneTree

func _init() -> void:
	var cam = Camera3D.new()
	cam.fov = 80.0
	root.add_child(cam)
	
	var pivot = Node3D.new()
	pivot.position = Vector3(0.35, -0.28, -0.55)
	pivot.rotation_degrees = Vector3(-15.0, -10.0, -5.0)
	cam.add_child(pivot)
	
	var axe_scene = load("res://assets/models/props/axe_iron.glb")
	var axe = axe_scene.instantiate()
	pivot.add_child(axe)
	
	await process_frame
	
	var mesh_inst = axe.find_child("Axe_Iron", true, false) as MeshInstance3D
	var aabb = mesh_inst.mesh.get_aabb()
	print("Mesh AABB: ", aabb)
	
	# Check 8 corners of AABB in camera local space
	var corners = [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0, 0),
		aabb.position + Vector3(0, aabb.size.y, 0),
		aabb.position + Vector3(0, 0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
		aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
		aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size
	]
	
	print("CORNERS IN CAMERA SPACE:")
	for c in corners:
		var cam_pt = cam.to_local(mesh_inst.to_global(c))
		var is_behind = cam.is_position_behind(mesh_inst.to_global(c))
		print("  corner: ", c, " -> in cam: ", cam_pt, " behind: ", is_behind)
		
	quit(0)
