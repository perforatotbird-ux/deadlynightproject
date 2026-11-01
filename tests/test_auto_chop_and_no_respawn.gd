extends SceneTree

const PlayerController = preload("res://scripts/player/PlayerController.gd")
const TreeChoppable = preload("res://scripts/props/TreeChoppable.gd")

func _init() -> void:
	_run_auto_chop_and_no_respawn_test()

func _run_auto_chop_and_no_respawn_test() -> void:
	print("=".repeat(70))
	print("TESTING AUTO-CHOP (HOLD LMB) & NO TREE RESPAWN (Godot 4.7.2)")
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
	
	for i in range(5):
		await process_frame
		
	var player = viewer.get_node_or_null("Player") as PlayerController
	var world_map = viewer.get_node_or_null("WorldMap")
	if not player or not world_map:
		print("FAIL: Player or WorldMap not found")
		quit(1)
		return

	# Reset felled trees registry for clean test
	TreeChoppable.felled_tree_ids.clear()
	
	# Position player facing birch tutorial tree at (-900, 24.99, 1096)
	player.rotation = Vector3.ZERO
	player._camera_pitch = 0.0
	player._camera_pivot.rotation = Vector3.ZERO
	player.global_position = Vector3(-900.0, 25.5, 1098.5)
	player.active_hotbar_slot = 0 # Axe equipped
	
	for i in range(3):
		await process_frame
		
	var trees = root.get_tree().get_nodes_in_group("choppable_trees")
	var target_tree: TreeChoppable = null
	for t in trees:
		if t is TreeChoppable and t.species == "birch" and t.tree_id == "tree_055432":
			target_tree = t
			break
			
	if not target_tree:
		print("FAIL: Birch tree not found near spawn.")
		quit(1)
		return
		
	var target_tree_id = target_tree.get_effective_id()
	var target_pos = target_tree.global_position
	print("Target tree identified: ID='%s', pos=%s, initial HP=%d" % [target_tree_id, str(target_pos), target_tree.current_hp])

	# TEST 1: Hold LMB down -> auto-chop executes continuously
	print("\n[TEST 1] Holding LMB down for continuous auto-chop...")
	var press_event = InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	player._input(press_event)
	
	if player.is_lmb_held:
		print("  -> PASS: player.is_lmb_held is true on mouse button press.")
		passed += 1
	else:
		print("  -> FAIL: player.is_lmb_held is false.")
		failed += 1

	# Wait and allow auto-chop to strike repeatedly while holding LMB
	var timeout = 25.0
	var started = Time.get_ticks_msec()
	var elapsed = 0.0
	var prev_hp = target_tree.current_hp
	var observed_hp_drops = 0
	
	print("  -> Holding LMB and awaiting continuous auto-chop...")
	while elapsed < timeout and is_instance_valid(target_tree) and target_tree.current_hp > 0:
		await process_frame
		elapsed = (Time.get_ticks_msec()-started)/1000.0
		if target_tree.current_hp < prev_hp:
			observed_hp_drops += 1
			print("     [Auto-chop] Tree HP dropped to %d (strike #%d, elapsed %.2fs)" % [target_tree.current_hp, observed_hp_drops, elapsed])
			prev_hp = target_tree.current_hp
			
	if observed_hp_drops >= 3:
		print("  -> PASS: Continuous auto-chop occurred while holding LMB (%d strikes registered)." % observed_hp_drops)
		passed += 1
	else:
		print("  -> FAIL: Expected multiple auto-chop strikes, got %d." % observed_hp_drops)
		failed += 1

	# Let it finish felling if not already 0 HP
	while elapsed < 40.0 and is_instance_valid(target_tree) and target_tree.current_hp > 0:
		await process_frame
		elapsed = (Time.get_ticks_msec()-started)/1000.0
		
	# Release LMB
	var release_event = InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	player._input(release_event)
	
	if not player.is_lmb_held:
		print("  -> PASS: player.is_lmb_held is false after release.")
		passed += 1
	else:
		print("  -> FAIL: player.is_lmb_held is still true after release.")
		failed += 1

	# Wait for fall animation and logs to settle
	await create_timer(1.5).timeout

	# TEST 2: Tree is registered in TreeChoppable.felled_tree_ids
	print("\n[TEST 2] Verifying felled tree persistence in felled_tree_ids...")
	var is_registered = TreeChoppable.felled_tree_ids.has(target_tree_id)
	var pos_id = "pos_%d_%d_%d" % [int(round(target_pos.x)), int(round(target_pos.y)), int(round(target_pos.z))]
	if not is_registered:
		is_registered = TreeChoppable.felled_tree_ids.has(pos_id)
		
	if is_registered:
		print("  -> PASS: Felled tree ID '%s' is persistently recorded in felled_tree_ids." % target_tree_id)
		passed += 1
	else:
		print("  -> FAIL: Felled tree ID '%s' not found in felled_tree_ids (keys: %s)." % [target_tree_id, str(TreeChoppable.felled_tree_ids.keys())])
		failed += 1

	# TEST 3: Permanent stump exists
	print("\n[TEST 3] Verifying permanent stump presence...")
	var stumps = root.get_tree().get_nodes_in_group("permanent_stumps")
	var found_stump = false
	for s in stumps:
		if is_instance_valid(s) and (s is Node3D):
			if (s as Node3D).global_position.distance_to(target_pos) < 2.0:
				found_stump = true
				break
				
	if found_stump:
		print("  -> PASS: Permanent stump exists at felled tree location.")
		passed += 1
	else:
		print("  -> FAIL: No permanent stump found near %s." % str(target_pos))
		failed += 1

	# TEST 4: Standing tree cannot be re-instantiated
	print("\n[TEST 4] Testing prevention of standing tree re-instantiation...")
	var re_tree_scene = load("res://scenes/props/TreeInteractive.tscn")
	var re_tree = re_tree_scene.instantiate() as TreeChoppable
	re_tree.species = "birch"
	re_tree.tree_id = target_tree_id
	re_tree.position = target_pos
	viewer.add_child(re_tree)
	# Restoration is asynchronous and reconstructs the actual cut stump.
	var restore_deadline = Time.get_ticks_msec()+15000
	while is_instance_valid(re_tree) and not re_tree.is_queued_for_deletion() and Time.get_ticks_msec()<restore_deadline:
		await create_timer(0.01).timeout
	
	if not is_instance_valid(re_tree) or re_tree.is_queued_for_deletion():
		print("  -> PASS: Re-instantiating felled tree was automatically culled/freed.")
		passed += 1
	else:
		print("  -> FAIL: Re-instantiated tree was NOT culled!")
		failed += 1
		re_tree.queue_free()

	# TEST 5: WorldMap proximity streaming never respawns felled dynamic trees
	print("\n[TEST 5] Testing WorldMap streaming with a dynamic tree...")
	# Register a test dynamic tree as felled
	var test_dyn_id = "tree_dyn_test_999"
	var test_origin = Vector3(-880.0, 25.0, 1100.0)
	var test_pos_id = "pos_%d_%d_%d" % [int(round(test_origin.x)), int(round(test_origin.y)), int(round(test_origin.z))]
	TreeChoppable.felled_tree_ids[test_dyn_id] = true
	TreeChoppable.felled_tree_ids[test_pos_id] = true
	
	# Attempt to activate dynamic tree in WorldMap
	world_map._activate_dynamic_tree({
		"id": test_dyn_id,
		"species": "spruce",
		"scale": 1.0,
		"yaw_deg": 0.0
	}, test_origin)
	
	if not world_map._dynamic_trees.has(test_dyn_id):
		print("  -> PASS: WorldMap refused to activate dynamic tree recorded in felled_tree_ids.")
		passed += 1
	else:
		print("  -> FAIL: WorldMap spawned dynamic tree despite being in felled_tree_ids.")
		failed += 1

	print("\n" + "=".repeat(70))
	print("AUTO-CHOP & NO RESPAWN TEST SUMMARY: %d PASSED, %d FAILED." % [passed, failed])
	print("=".repeat(70))
	
	quit(0 if failed == 0 else 1)
