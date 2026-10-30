extends SceneTree

const PlayerController = preload("res://scripts/player/PlayerController.gd")

func _init() -> void:
	_run_tld_controls_test()

func _run_tld_controls_test() -> void:
	print("=".repeat(70))
	print("RUNNING TLD CONTROLS & TREE CHOPPING TEST (Godot 4.7.2)")
	print("=".repeat(70))
	
	var passed = 0
	var failed = 0
	
	var viewer_scene = load("res://scenes/viewer/MapViewer.tscn")
	if not viewer_scene:
		print("FAIL: Could not load MapViewer.tscn")
		quit(1)
		return
		
	var viewer = viewer_scene.instantiate()
	root.add_child(viewer)
	
	# Wait 5 frames for _ready and physics to settle
	for i in range(5):
		await process_frame
		
	var player = viewer.get_node_or_null("Player") as PlayerController
	if not player:
		print("FAIL: Player node not found")
		quit(1)
		return
		
	print("\n[TEST 1] Player Active & Mouse Mode Check...")
	if player._is_active and player._camera.current:
		print("  -> PASS: Player is active and current camera is PlayerCamera.")
		passed += 1
	else:
		print("  -> FAIL: Player is not active.")
		failed += 1
		
	print("\n[TEST 2] Mouse Motion Look Test...")
	var initial_rot_y = player.rotation.y
	var initial_pitch = player._camera_pitch
	
	# Simulate mouse motion (rel X = 100, rel Y = 50)
	var motion_event = InputEventMouseMotion.new()
	motion_event.relative = Vector2(100.0, 50.0)
	player._input(motion_event)
	
	if player.rotation.y != initial_rot_y and player._camera_pivot.rotation.x != initial_pitch:
		print("  -> PASS: Mouse motion rotates character yaw and camera pitch.")
		passed += 1
	else:
		print("  -> FAIL: Mouse motion did not rotate camera.")
		failed += 1
		
	print("\n[TEST 3] Interact Prompt & Target Detection at SPAWN...")
	# Reset player facing towards -Z (directly at the birch tree at -900, 24.99, 1096)
	player.rotation = Vector3.ZERO
	player._camera_pitch = 0.0
	player._camera_pivot.rotation = Vector3.ZERO
	# Position player 2.5m away from birch tree
	player.global_position = Vector3(-900.0, 25.5, 1098.5)
	
	for i in range(3):
		await process_frame
		
	player._update_raycast_target()
	var prompt = player._prompt_label.text
	print("  -> Detected prompt: '%s'" % prompt)
	if prompt.contains("Рубить") and prompt.contains("Берёза"):
		print("  -> PASS: Reticle successfully detected tree and displayed survival HUD prompt.")
		passed += 1
	else:
		print("  -> FAIL: Prompt did not detect tree (got: '%s')." % prompt)
		failed += 1
		
	print("\n[TEST 4] Axe Chop Execution via Left Mouse Click...")
	var trees = root.get_tree().get_nodes_in_group("choppable_trees")
	var target_tree = null
	for t in trees:
		if t.species == "birch" and t.current_hp == 8:
			target_tree = t
			break
			
	if target_tree:
		var hp_before = target_tree.current_hp
		print("  -> Initial Birch Tree HP: %d" % hp_before)
		
		# Simulate Left Mouse Button click
		var click_event = InputEventMouseButton.new()
		click_event.button_index = MOUSE_BUTTON_LEFT
		click_event.pressed = true
		player._input(click_event)
		
		# Wait for swing hit delay (0.12s)
		await create_timer(0.15).timeout
		
		print("  -> HP after 1 chop: %d" % target_tree.current_hp)
		if target_tree.current_hp == hp_before - 1:
			print("  -> PASS: LMB click chopped tree, dealt 1 damage.")
			passed += 1
		else:
			print("  -> FAIL: Tree HP did not decrease after LMB click.")
			failed += 1
			
		# Finish chopping the tree down to 0
		print("  -> Chopping tree to 0 HP...")
		while target_tree.current_hp > 0:
			player._can_chop = true
			player._try_chop()
			await create_timer(0.12).timeout
			
		print("  -> Tree felled! Waiting for physics fall and log drop...")
		await create_timer(1.5).timeout
		
		# Check if logs spawned
		var logs = root.get_tree().get_nodes_in_group("pickup_logs")
		print("  -> Found %d dropped logs in world." % logs.size())
		if logs.size() > 0:
			print("  -> PASS: Logs successfully dropped on ground.")
			passed += 1
			
			# TEST 5: Pickup log with E
			print("\n[TEST 5] Picking up log via [E] key...")
			var log_item = logs[0]
			player.global_position = log_item.global_position + Vector3(0.5, 0.5, 0.5)
			var w_before = player.backpack_weight
			player._try_interact()
			print("  -> Backpack weight before: %.1f kg, after: %.1f kg." % [w_before, player.backpack_weight])
			if player.backpack_weight > w_before:
				print("  -> PASS: Log picked up into backpack.")
				passed += 1
			else:
				print("  -> FAIL: Log was not picked up.")
				failed += 1
		else:
			print("  -> FAIL: No logs spawned after felling.")
			failed += 1
	else:
		print("  -> FAIL: Target birch tree not found.")
		failed += 1
		
	print("\n" + "=".repeat(70))
	print("TLD CONTROLS TEST SUMMARY: %d PASSED, %d FAILED." % [passed, failed])
	print("=".repeat(70))
	
	var f = FileAccess.open("res://data/test_controls_report.txt", FileAccess.WRITE)
	if f:
		f.store_string("PASSED: %d, FAILED: %d\n" % [passed, failed])
		f.store_string("Player position: %s\n" % str(player.global_position))
		f.store_string("Player camera current: %s\n" % str(player._camera.current))
		f.store_string("Player rotation: %s\n" % str(player.rotation))
		f.store_string("Player prompt text: '%s'\n" % player._prompt_label.text)
		f.store_string("Backpack weight: %.1f\n" % player.backpack_weight)
		f.close()
	
	quit(0 if failed == 0 else 1)
