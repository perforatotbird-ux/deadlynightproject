extends SceneTree

func _init() -> void:
	var hand_pos = Vector3(0.28, -0.24, -0.42)
	var tree_pos = Vector3(0.0, 0.0, -2.5) # Tree trunk straight in front
	var to_tree = (tree_pos - hand_pos).normalized()
	
	# Current angles in PlayerController:
	# _axe_anim_pivot.position = Vector3(0.26, -0.25, -0.42)
	# _axe_anim_pivot.rotation_degrees = Vector3(-20.0, -65.0, 15.0)
	
	print("To tree vector:", to_tree)
	
	# We want:
	# 1. Blade is rotated 45 degrees towards the tree trunk
	# 2. Blade turned to the right (compared to previous looking left)
	# Let's test combinations of rotation_degrees:
	var candidates = [
		Vector3(-15.0, -20.0, 30.0),
		Vector3(-20.0, 25.0, 15.0),
		Vector3(-15.0, 35.0, 10.0),
		Vector3(-20.0, 45.0, 15.0),
		Vector3(-10.0, 45.0, 20.0),
		Vector3(-15.0, 45.0, 0.0),
		Vector3(-25.0, 45.0, -15.0)
	]
	
	for rot in candidates:
		var b = Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))
		var blade = b * Vector3(0, 0, -1)
		var angle_to_tree = rad_to_deg(blade.angle_to(to_tree))
		var angle_to_forward = rad_to_deg(blade.angle_to(Vector3(0, 0, -1)))
		print("Rot %s: blade=%s, angle to tree=%.1f deg, angle to forward=%.1f deg" % [str(rot), str(blade), angle_to_tree, angle_to_forward])
		
	quit(0)
