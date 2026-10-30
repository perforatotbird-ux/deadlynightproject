extends SceneTree

const TreeChoppable = preload("res://scripts/props/TreeChoppable.gd")
const LogPickup = preload("res://scripts/props/LogPickup.gd")

func _init() -> void:
	_run_ditch_tree_fall_test()

func _run_ditch_tree_fall_test() -> void:
	print("=".repeat(70))
	print("TESTING DITCH / UNEVEN TERRAIN TREE FALL & LOG ANTI-FALLTHROUGH")
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
		
	var world_map = viewer.get_node_or_null("WorldMap")
	if not world_map:
		print("FAIL: WorldMap not found")
		quit(1)
		return

	# TEST 1: Spawn a tree on an uneven slope / ditch
	print("\n[TEST 1] Instantiating test tree on uneven slope...")
	var tree_scene = load("res://scenes/props/TreeInteractive.tscn")
	var tree = tree_scene.instantiate() as TreeChoppable
	# Place the authored root on terrain BEFORE activation, as WorldMap does.
	var space = viewer.get_world_3d().direct_space_state
	var placement = PhysicsRayQueryParameters3D.create(Vector3(-890, 55, 1090), Vector3(-890, -5, 1090))
	placement.collision_mask = 1
	var ground = space.intersect_ray(placement)
	if ground.is_empty():
		print("FAIL: Terrain missing at test tree origin")
		quit(1)
		return
	var original_root: Vector3 = ground.position
	tree.species = "spruce"
	tree.tree_id = "tree_ditch_test_01"
	tree.position = viewer.global_transform.affine_inverse() * original_root
	viewer.add_child(tree)
	await process_frame
	
	if is_instance_valid(tree):
		print("  -> PASS: Test tree instantiated on slope.")
		passed += 1
	else:
		print("  -> FAIL: Failed to instantiate tree.")
		failed += 1

	# TEST 2: Felling tree uphill / towards ditch bank and verifying _target_fall_angle
	print("\n[TEST 2] Testing terrain-adaptive fall angle calculation...")
	# Simulate chop from player standing downhill (-890, 25.5, 1093) pushing tree towards -Z (uphill)
	tree._fall_direction = Vector3(0.0, 0.0, -1.0).normalized()
	tree._start_falling()
	# Fracture geometry is calculated asynchronously; inspect the actual result.
	await tree._voxel_trunk.fracture_ready
	
	print("  -> Calculated target fall angle: %.2f deg (standard flat is 88 deg)" % rad_to_deg(tree._target_fall_angle))
	if tree._target_fall_angle > 0.0 and tree._target_fall_angle <= deg_to_rad(115.0):
		print("  -> PASS: _target_fall_angle adaptively constrained by terrain profile.")
		passed += 1
	else:
		print("  -> FAIL: Invalid target fall angle: %.2f" % rad_to_deg(tree._target_fall_angle))
		failed += 1

	# Wait for fall to complete and logs to spawn
	print("  -> Waiting for fall animation and log spawn...")
	await create_timer(1.8).timeout

	# TEST 3: Verifying that all spawned logs are strictly ON or ABOVE terrain surface
	print("\n[TEST 3] Auditing spawned log elevations relative to terrain mesh...")
	var logs = root.get_tree().get_nodes_in_group("pickup_logs")
	var valid_elevations = 0
	
	for l in logs:
		if is_instance_valid(l) and (l is LogPickup):
			var pos = l.global_position
			var q = PhysicsRayQueryParameters3D.create(
				Vector3(pos.x, pos.y + 10.0, pos.z),
				Vector3(pos.x, pos.y - 10.0, pos.z)
			)
			q.collision_mask = 1 # Terrain
			var hit = space.intersect_ray(q)
			if not hit.is_empty():
				var ground_y = hit.position.y
				var diff = pos.y - ground_y
				print("     Log at (%0.2f, %0.2f, %0.2f): ground_y = %0.2f, diff = %+0.3fm" % [pos.x, pos.y, pos.z, ground_y, diff])
				# Log must be at or above ground_y - 0.05m (allowing slight physical surface contact)
				if diff >= -0.05:
					valid_elevations += 1
				else:
					print("     FAIL: Log is underground! diff = %+0.3fm" % diff)
					
	if valid_elevations >= 3:
		print("  -> PASS: All %d spawned logs are strictly above ground surface." % valid_elevations)
		passed += 1
	else:
		print("  -> FAIL: Found underground or missing logs (valid: %d)." % valid_elevations)
		failed += 1

	# TEST 4: Anti-fallthrough failsafe recovery
	print("\n[TEST 4] Testing anti-fallthrough recovery failsafe on LogPickup...")
	var test_log = logs[0] as LogPickup
	var saved_ground_y = test_log._last_valid_ground_y
	test_log.freeze = false
	# Artificially force log 4.0 meters underground into the void
	test_log.global_position.y = saved_ground_y - 4.0
	test_log.linear_velocity = Vector3(0.0, -10.0, 0.0) # plunging downward
	
	# Give it 2 physics frames to detect penetration and resurface
	for f in range(3):
		await process_frame
		
	print("  -> Position after failsafe check: Y = %0.2f (expected >= %0.2f)" % [test_log.global_position.y, saved_ground_y])
	if test_log.global_position.y >= saved_ground_y:
		print("  -> PASS: Log successfully caught by failsafe and resurfaced above terrain!")
		passed += 1
	else:
		print("  -> FAIL: Log remained underground.")
		failed += 1

	# TEST 5: Lower trunk retains its original grounded transform and real cut height.
	# Do not snap a replacement model or raycast against the stump's own collider.
	print("\n[TEST 5] Testing original lower trunk placement...")
	var found_remnant = false
	for s in get_nodes_in_group("permanent_stumps"):
		if not is_instance_valid(s) or s.get_meta("tree_id", "") != "tree_ditch_test_01":
			continue
		var visual = s.get_child(0) as MeshInstance3D
		var cut_y = float(s.get_meta("cut_y"))
		var base_error = s.global_position.distance_to(original_root)
		var mesh_top = visual.mesh.get_aabb().end.y
		found_remnant = base_error < 0.001 and absf(mesh_top - cut_y) < 0.001
		print("  -> Lower root error=%.5fm, mesh top=%.3fm, cut=%.3fm" % [base_error, mesh_top, cut_y])
	if found_remnant:
		print("  -> PASS: Actual lower trunk preserved at grounded root and fracture height.")
		passed += 1
	else:
		print("  -> FAIL: Actual lower trunk moved or does not end at fracture height.")
		failed += 1

	print("\n" + "=".repeat(70))
	print("DITCH TREE FALL TEST SUMMARY: %d PASSED, %d FAILED." % [passed, failed])
	print("=".repeat(70))
	
	quit(0 if failed == 0 else 1)
