extends SceneTree

func _init() -> void:
	var cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	root.add_child(cam)
	
	var pivot = Node3D.new()
	pivot.name = "AxePivot"
	# Position in right hand quadrant
	pivot.position = Vector3(0.28, -0.24, -0.42)
	# Blade turned right at 45° towards tree trunk
	pivot.rotation_degrees = Vector3(-20.0, 45.0, 15.0)
	pivot.scale = Vector3(0.75, 0.75, 0.75) # Scale to comfortable 1st person viewmodel size
	cam.add_child(pivot)
	
	var axe_scene = load("res://assets/models/props/axe_iron.glb")
	var axe = axe_scene.instantiate()
	pivot.add_child(axe)
	
	# Add light
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	root.add_child(light)
	
	for i in range(5):
		await process_frame
		
	var img = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png("data/test_axe_viewmodel.png")
		print("SAVED test_axe_viewmodel.png")
	quit(0)
