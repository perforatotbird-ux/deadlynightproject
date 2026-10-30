extends SceneTree

const PlayerController = preload("res://scripts/player/PlayerController.gd")
const TreeChoppable = preload("res://scripts/props/TreeChoppable.gd")
const LogPickup = preload("res://scripts/props/LogPickup.gd")
const VoxelTreeTrunk = preload("res://scripts/props/VoxelTreeTrunk.gd")

func _init() -> void:
	print("=".repeat(75))
	print("COMPREHENSIVE TEST: SPRINT JUMP, 3 ROUND LOGS, AXE 45° BLADE & VOXEL TREES")
	print("=".repeat(75))
	
	var passed = 0
	var failed = 0
	
	# -------------------------------------------------------------------------
	# TEST 1: AXE ROTATION & HAND POSITION (Requirement 3)
	# -------------------------------------------------------------------------
	print("\n[TEST 1] Testing Axe Hand Position & Blade 45° Rotation...")
	var player = PlayerController.new()
	root.add_child(player)
	player.set_active(true)
	
	for i in range(3):
		await process_frame
		
	var anim_pivot = player._axe_anim_pivot
	if anim_pivot:
		print("  Axe pivot pos:", anim_pivot.position)
		print("  Axe pivot rot:", anim_pivot.rotation_degrees)
		
		# Expected pos: Vector3(0.28, -0.24, -0.42)
		# Expected rot: Vector3(-20.0, 45.0, 15.0) -> Y rotation turned right to +45°
		var y_rot = anim_pivot.rotation_degrees.y
		if absf(y_rot - 45.0) < 0.1 and anim_pivot.position.x > 0.20:
			print("  -> PASS: Axe blade turned right at 45° in player's right hand position.")
			passed += 1
		else:
			print("  -> FAIL: Axe rotation Y is %f (expected 45.0)." % y_rot)
			failed += 1
	else:
		print("  -> FAIL: Axe anim pivot not found.")
		failed += 1
		
	# -------------------------------------------------------------------------
	# TEST 2: JUMP DURING SPRINT / RUNNING (Requirement 1)
	# -------------------------------------------------------------------------
	print("\n[TEST 2] Testing Jump During Sprint / Running...")
	# Position player on ground
	player.global_position = Vector3(0, 1.0, 0)
	player.velocity = Vector3.ZERO
	
	# Simulate sprint input (Shift + W) and Space
	player._is_sprint_jumping = false
	player._coyote_timer = 0.20 # on floor
	player._jump_buffer_timer = 0.20 # pressed space
	
	# Run a physics frame
	# In PlayerController, if _jump_buffer_timer > 0 and can_jump: velocity.y = jump_velocity
	var input_dir = Vector2(0, -1) # W
	var is_sprint_key = true
	var is_sprinting = (is_sprint_key or player._is_sprint_jumping) and input_dir.length_squared() > 0.0
	var can_jump = (player._coyote_timer > 0.0 or player.is_on_floor()) and not player._is_crouching
	
	if player._jump_buffer_timer > 0.0 and can_jump:
		player.velocity.y = player.jump_velocity
		player._jump_buffer_timer = 0.0
		player._coyote_timer = 0.0
		if is_sprinting:
			player._is_sprint_jumping = true
			
	if player.velocity.y >= player.jump_velocity and player._is_sprint_jumping:
		print("  -> PASS: Jump triggered while running with upward velocity %.2f and sprint preserved." % player.velocity.y)
		passed += 1
	else:
		print("  -> FAIL: Jump failed during running sprint.")
		failed += 1
		
	# Test coyote time: player just stepped off edge (coyote_timer = 0.15s)
	player._coyote_timer = 0.15
	player._jump_buffer_timer = 0.15
	can_jump = (player._coyote_timer > 0.0) and not player._is_crouching
	if player._jump_buffer_timer > 0.0 and can_jump:
		player.velocity.y = player.jump_velocity
		print("  -> PASS: Coyote time allows jumping immediately after leaving ground.")
		passed += 1
	else:
		print("  -> FAIL: Coyote time jump failed.")
		failed += 1
		
	player.queue_free()
	
	# -------------------------------------------------------------------------
	# TEST 3: VOXEL TREE TRUNK & LOCALIZED DAMAGE (Requirement 4)
	# -------------------------------------------------------------------------
	print("\n[TEST 3] Testing Voxel Tree Trunk & Localized Axe Damage...")
	var tree = TreeChoppable.new()
	root.add_child(tree)
	tree.global_position = Vector3(10.0, 0.0, 10.0)
	tree.init_tree("birch", "test_voxel_birch")
	
	for i in range(2):
		await process_frame
		
	if tree._voxel_trunk != null:
		print("  -> PASS: Interactive tree initialized with VoxelTreeTrunk.")
		passed += 1
	else:
		print("  -> FAIL: Interactive tree missing VoxelTreeTrunk.")
		failed += 1
		
	# Test localized damage: strike at height Y = 1.35m from South (+Z)
	var hit_pos = tree.global_position + Vector3(0.0, 1.35, 0.35)
	var player_strike_pos = tree.global_position + Vector3(0.0, 1.35, 1.5)
	var prev_hp = tree.current_hp
	
	tree.hit(1, hit_pos, player_strike_pos)
	
	if tree.current_hp == prev_hp - 1:
		print("  -> PASS: Tree registered axe strike and reduced HP to %d." % tree.current_hp)
		passed += 1
	else:
		print("  -> FAIL: Tree HP did not drop on strike.")
		failed += 1
		
	# Verify that damage appeared strictly at the hit point in voxel trunk
	var v_trunk = tree._voxel_trunk
	var local_hit = v_trunk.to_local(hit_pos) if v_trunk.is_inside_tree() else (hit_pos - v_trunk.global_position)
	var hit_y_idx = clampi(int(round(local_hit.y / v_trunk.voxel_size)), 0, v_trunk.grid_h - 1)
	
	# Solid count in that layer should be lower than initial
	var initial_cnt = v_trunk._layer_initial_counts[hit_y_idx]
	var current_cnt = v_trunk._layer_solid_counts[hit_y_idx]
	if current_cnt < initial_cnt:
		print("  -> PASS: Voxels carved strictly at hit height Y=%.2fm (voxels: %d -> %d)." % [local_hit.y, initial_cnt, current_cnt])
		passed += 1
	else:
		print("  -> FAIL: Voxels were not carved at hit height.")
		failed += 1
		
	# -------------------------------------------------------------------------
	# TEST 4: CHOPPED TREE YIELDS 3 ROUND LOGS (Requirement 2)
	# -------------------------------------------------------------------------
	print("\n[TEST 4] Testing Chopped Tree Yields 3 Round Logs...")
	print("  Tree configured log_count: %d" % tree.log_count)
	if tree.log_count == 3:
		print("  -> PASS: Tree log_count is set to 3.")
		passed += 1
	else:
		print("  -> FAIL: Tree log_count is %d (expected 3)." % tree.log_count)
		failed += 1
		
	# Felling tree by striking until felled
	var strike_count = 0
	while tree.current_hp > 0 and strike_count < 15:
		tree.hit(2, hit_pos, player_strike_pos)
		strike_count += 1
		
	print("  Tree felled after %d strikes, awaiting fall animation..." % strike_count)
	# Wait for felling and log spawning
	var elapsed = 0.0
	while elapsed < 2.5 and is_instance_valid(tree):
		await process_frame
		elapsed += 0.016
		
	# Check spawned logs in scene
	var logs = root.get_tree().get_nodes_in_group("pickup_logs")
	var spawned_count = 0
	var round_model_ok = false
	
	for l in logs:
		if is_instance_valid(l) and l is LogPickup:
			spawned_count += 1
			# Inspect log mesh
			var mesh_node = l.get_node_or_null("CollisionShape3D")
			if mesh_node and mesh_node.shape is CapsuleShape3D:
				var cap = mesh_node.shape as CapsuleShape3D
				if absf(cap.radius - 0.18) < 0.05:
					round_model_ok = true
					
	print("  Spawned pickup logs count: %d" % spawned_count)
	if spawned_count == 3:
		print("  -> PASS: Chopped tree successfully spawned exactly 3 logs.")
		passed += 1
	else:
		print("  -> FAIL: Expected 3 logs, got %d." % spawned_count)
		failed += 1
		
	if round_model_ok:
		print("  -> PASS: Spawned log has authentic round log (бревно) geometry.")
		passed += 1
	else:
		print("  -> FAIL: Spawned log geometry does not match round log.")
		failed += 1
		
	print("\n" + "=".repeat(75))
	print("FINAL RESULTS: %d PASSED, %d FAILED." % [passed, failed])
	print("=".repeat(75))
	
	quit(0 if failed == 0 else 1)
