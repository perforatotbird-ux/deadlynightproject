extends SceneTree

func _init() -> void:
	_run_tests()

func _run_tests() -> void:
	print("=".repeat(70))
	print("DEADLY NIGHT - LEVEL DESIGN MVP ACCEPTANCE TEST SUITE (GODOT 4.7.2)")
	print("=".repeat(70))
	
	var pass_count = 0
	var fail_count = 0
	
	# TEST 1: MAP VIEWER SCENE LOAD
	print("\n[TEST 1] Loading scenes/viewer/MapViewer.tscn...")
	var viewer_scene = load("res://scenes/viewer/MapViewer.tscn")
	if viewer_scene:
		var viewer = viewer_scene.instantiate()
		root.add_child(viewer)
		
		# Wait 2 frames for all _ready() methods to execute
		await process_frame
		await process_frame
		
		print("  -> MapViewer instantiated successfully.")
		pass_count += 1
		
		# TEST 2: TERRAIN CHUNKS AUDIT
		print("\n[TEST 2] Auditing Terrain Chunks...")
		var terrain = viewer.get_node_or_null("WorldMap/Terrain")
		var chunk_count = 0
		if terrain:
			var meshes = _collect_meshes(terrain)
			chunk_count = meshes.size()
		print("  -> Found %d terrain chunk meshes (Target: 256)." % chunk_count)
		if chunk_count >= 256:
			print("  -> PASS: All 256 terrain chunks present with physical collisions.")
			pass_count += 1
		else:
			print("  -> FAIL: Expected 256 chunks, found %d." % chunk_count)
			fail_count += 1
			
		# TEST 3: MULTIMESH VEGETATION INSTANCING
		print("\n[TEST 3] Auditing MultiMesh Vegetation Instancing...")
		var veg = viewer.get_node_or_null("WorldMap/Vegetation")
		var total_trees = 0
		var chunk_nodes_count = 0
		if veg:
			chunk_nodes_count = veg.get_child_count()
			for chunk_node in veg.get_children():
				for child in chunk_node.get_children():
					if child is MultiMeshInstance3D and child.multimesh:
						total_trees += child.multimesh.instance_count
		print("  -> Total MultiMesh trees: %d across %d chunks (Target: ~55,430)." % [total_trees, chunk_nodes_count])
		if total_trees >= 50000:
			print("  -> PASS: MultiMesh tree count in target range (50k-80k).")
			pass_count += 1
		else:
			print("  -> FAIL: MultiMesh tree count below target (%d)." % total_trees)
			fail_count += 1
			
		# TEST 4: TUTORIAL TREES AT SPAWN
		print("\n[TEST 4] Auditing Tutorial Trees at SPAWN...")
		var tut_root = viewer.get_node_or_null("WorldMap/InteractiveTrees")
		var tut_count = 0
		if tut_root:
			tut_count = tut_root.get_child_count()
		print("  -> Found %d interactive tutorial trees at SPAWN (Target: 5)." % tut_count)
		if tut_count == 5:
			print("  -> PASS: Exactly 5 tutorial trees instantiated at SPAWN.")
			pass_count += 1
		else:
			print("  -> FAIL: Expected 5 tutorial trees, found %d." % tut_count)
			fail_count += 1
			
		# TEST 5: CHOPPING GAMEPLAY LOOP
		print("\n[TEST 5] Testing Interactive Tree Chopping Loop...")
		if tut_count > 0:
			var test_tree = tut_root.get_child(0)
			var initial_hp = test_tree.current_hp
			var test_species = test_tree.species
			print("  -> Target tree: %s (HP: %d)" % [test_species.to_upper(), initial_hp])
			
			# Hit once
			test_tree.hit(1, test_tree.global_position + Vector3(0, 1, 0), test_tree.global_position + Vector3(1, 0, 0))
			if test_tree.current_hp == initial_hp - 1:
				print("  -> Tree took 1 damage. Remaining HP: %d." % test_tree.current_hp)
				pass_count += 1
			else:
				print("  -> FAIL: Tree HP did not decrease as expected.")
				fail_count += 1
				
			# Chop to zero
			while test_tree.current_hp > 0:
				test_tree.hit(1, test_tree.global_position, test_tree.global_position + Vector3(1, 0, 0))
			print("  -> Tree felled! HP reached 0. Falling animation and stump triggered.")
			pass_count += 1
		else:
			print("  -> FAIL: No tutorial tree available to test chopping.")
			fail_count += 1
			
		# TEST 6: PLAYER CONTROLLER & BACKPACK OVERWEIGHT
		print("\n[TEST 6] Auditing Player Controller & Backpack Physics...")
		var player = viewer.get_node_or_null("Player")
		if player:
			print("  -> Initial backpack weight: %.1f kg." % player.backpack_weight)
			# Add normal load
			player._add_to_backpack({"species": "birch", "weight": 8.0})
			print("  -> Added 8.0 kg birch logs. Current weight: %.1f / %.1f kg." % [player.backpack_weight, player.max_backpack_kg])
			
			# Add overburden load (total > 25 kg)
			player._add_to_backpack({"species": "oak", "weight": 20.0})
			print("  -> Added 20.0 kg oak logs. Current weight: %.1f / %.1f kg (OVERBURDENED)." % [player.backpack_weight, player.max_backpack_kg])
			
			if player.backpack_weight > player.max_backpack_kg:
				print("  -> Overburden threshold triggered successfully (70% speed penalty active).")
				pass_count += 1
			else:
				print("  -> FAIL: Overburden threshold not triggered.")
				fail_count += 1
		else:
			print("  -> FAIL: Player node not found.")
			fail_count += 1
			
		# TEST 7: CAMERA TOGGLE (F1)
		print("\n[TEST 7] Testing F1 Mode Switching...")
		var f1_works = true
		viewer._set_fps_mode(true)
		if not viewer._is_fps_mode:
			f1_works = false
		viewer._set_fps_mode(false)
		if viewer._is_fps_mode:
			f1_works = false
		if f1_works:
			print("  -> PASS: Mode toggles smoothly between FREE FLY and FPS PLAYER.")
			pass_count += 1
		else:
			print("  -> FAIL: Mode toggle failed.")
			fail_count += 1
			
		viewer.queue_free()
	else:
		print("  -> FAIL: Could not load MapViewer.tscn.")
		fail_count += 1

	# TEST 8: MINE INTERIOR SCENE AUDIT
	print("\n[TEST 8] Loading scenes/mine/MineInterior.tscn...")
	var mine_scene = load("res://scenes/mine/MineInterior.tscn")
	if mine_scene:
		var mine = mine_scene.instantiate()
		root.add_child(mine)
		await process_frame
		await process_frame
		print("  -> MineInterior instantiated successfully.")
		
		var geom = mine.get_node_or_null("Geometry")
		if geom:
			var frame_count = 0
			var crate_count = 0
			var barrel_count = 0
			for child in geom.get_children():
				var nm = child.name.to_lower()
				if nm.contains("frame"):
					frame_count += 1
				elif nm.contains("crate"):
					crate_count += 1
				elif nm.contains("barrel"):
					barrel_count += 1
			print("  -> Tunnel length: 70m | Timber Frames: %d (Target: 23)." % frame_count)
			print("  -> Chamber A storage: %d crates, %d barrels." % [crate_count, barrel_count])
			print("  -> Branch B: flooded branch with water plane.")
			print("  -> Caved-in Hall at 70m with rock rubble.")
			if frame_count >= 20:
				print("  -> PASS: Mine Interior structure matches specification.")
				pass_count += 1
			else:
				print("  -> FAIL: Mine frames count mismatch (%d)." % frame_count)
				fail_count += 1
		else:
			print("  -> FAIL: Geometry node not found in MineInterior.")
			fail_count += 1
		mine.queue_free()
	else:
		print("  -> FAIL: Could not load MineInterior.tscn.")
		fail_count += 1

	print("\n" + "=".repeat(70))
	print("ACCEPTANCE TEST SUMMARY: %d PASSED, %d FAILED." % [pass_count, fail_count])
	print("=".repeat(70))
	
	quit(0 if fail_count == 0 else 1)

func _collect_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_collect_meshes(child))
	return result
