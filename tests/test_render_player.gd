extends SceneTree

func _init() -> void:
	var viewer_scene = load("res://scenes/viewer/MapViewer.tscn")
	var viewer = viewer_scene.instantiate()
	root.add_child(viewer)
	
	# Wait 10 frames for physics and rendering to settle
	for i in range(10):
		await process_frame
		
	var img = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png("data/test_player_view_fixed.png")
		print("SAVED test_player_view_fixed.png")
		
	var player = viewer.get_node("Player") as CharacterBody3D
	print("PLAYER POS: ", player.global_position)
	print("PLAYER IS ON FLOOR: ", player.is_on_floor())
	quit(0)
