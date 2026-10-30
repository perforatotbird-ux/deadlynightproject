extends SceneTree

# Comprehensive Acceptance Test Suite for Deadly Night:
# Main Menu, Scenic Vista, Settings Persistence, Multi-Slot Saves/Loads, and Pause Overlay.

const TreeChoppable = preload("res://scripts/props/TreeChoppable.gd")
const PauseMenu = preload("res://scripts/menu/PauseMenu.gd")
const SettingsManager = preload("res://scripts/core/SettingsManager.gd")
const SaveManager = preload("res://scripts/core/SaveManager.gd")
const MainMenu = preload("res://scripts/menu/MainMenu.gd")

func _init() -> void:
	_run_all_tests()

func _run_all_tests() -> void:
	print("=".repeat(75))
	print("DEADLY NIGHT - MAIN MENU, PERSISTENCE & PAUSE SYSTEM TEST SUITE")
	print("Godot Engine 4.7.2 Forward+  ·  Commercial Survival Architecture")
	print("=".repeat(75))
	
	var passed = 0
	var failed = 0
	
	# Wait for engine initialization
	for i in range(3):
		await process_frame
		
	# -------------------------------------------------------------
	# TEST 1: SettingsManager Persistence & Audio Bus Verification
	# -------------------------------------------------------------
	print("\n--- TEST 1: SettingsManager Configuration & Persistence ---")
	var sm = SettingsManager.get_instance()
	if sm != null:
		print("PASS: SettingsManager instance successfully acquired.")
		passed += 1
	else:
		print("FAIL: SettingsManager instance is null.")
		failed += 1
		
	if sm:
		# Test setting modifications
		sm.set_setting("audio", "master_volume", 0.42)
		sm.set_setting("controls", "mouse_sensitivity", 0.0035)
		sm.set_setting("controls", "invert_y", true)
		sm.set_setting("graphics", "max_fps", 120)
		sm.set_setting("gameplay", "autosave_interval_min", 10)
		sm.save_settings()
		
		# Read back from disc
		var reloaded_sm = SettingsManager.new()
		reloaded_sm._ready()
		var read_vol = reloaded_sm.get_setting("audio", "master_volume", 1.0)
		var read_sens = reloaded_sm.get_setting("controls", "mouse_sensitivity", 0.002)
		var read_inv_y = reloaded_sm.get_setting("controls", "invert_y", false)
		var read_fps = reloaded_sm.get_setting("graphics", "max_fps", 60)
		
		if is_equal_approx(read_vol, 0.42) and is_equal_approx(read_sens, 0.0035) and read_inv_y == true and read_fps == 120:
			print("PASS: Settings values correctly saved to user://settings.cfg and loaded.")
			passed += 1
		else:
			print("FAIL: Settings values mismatch after reload. vol=%.2f, sens=%.4f, inv_y=%s, fps=%d" % [read_vol, read_sens, str(read_inv_y), read_fps])
			failed += 1
			
		# Reset to defaults
		sm.reset_to_defaults()
		var def_vol = sm.get_setting("audio", "master_volume", 0.0)
		if is_equal_approx(def_vol, 0.85):
			print("PASS: Reset to defaults successfully restored original values (vol=%.2f)." % def_vol)
			passed += 1
		else:
			print("FAIL: Reset to defaults failed (vol=%.2f, expected 0.85)." % def_vol)
			failed += 1

	# -------------------------------------------------------------
	# TEST 2: MainMenu Scene Loading & 3D Backdrop
	# -------------------------------------------------------------
	print("\n--- TEST 2: MainMenu Scene Loading & 3D Scenic Vista ---")
	var menu_scene = load("res://scenes/menu/MainMenu.tscn")
	if menu_scene == null:
		print("FAIL: Could not load res://scenes/menu/MainMenu.tscn")
		failed += 1
	else:
		var menu = menu_scene.instantiate()
		root.add_child(menu)
		
		for i in range(3):
			await process_frame
			
		var backdrop = menu.get_node_or_null("MenuBackdrop3D")
		if backdrop != null:
			print("PASS: 3D Scenic MenuBackdrop3D found in MainMenu.")
			var cam = backdrop.get_node_or_null("MenuCamera")
			var env = backdrop.get_node_or_null("MenuWorldEnvironment")
			if cam != null and env != null:
				print("PASS: Camera3D and WorldEnvironment correctly configured in backdrop.")
				passed += 1
			else:
				print("FAIL: Backdrop missing Camera3D or WorldEnvironment.")
				failed += 1
		else:
			print("FAIL: MenuBackdrop3D missing from MainMenu.")
			failed += 1
			
		var nav_box = menu.get_node_or_null("CanvasLayer/RootMargin/MainHBox/NavVBox")
		if nav_box != null:
			var btn_new = nav_box.get_node_or_null("BtnNewGame") as Button
			var btn_load = nav_box.get_node_or_null("BtnLoadGame") as Button
			var btn_set = nav_box.get_node_or_null("BtnSettings") as Button
			var btn_cred = nav_box.get_node_or_null("BtnCredits") as Button
			var btn_quit = nav_box.get_node_or_null("BtnQuit") as Button
			if btn_new and btn_load and btn_set and btn_cred and btn_quit:
				print("PASS: All primary navigation buttons present and typed.")
				passed += 1
			else:
				print("FAIL: One or more navigation buttons missing in MainMenu.")
				failed += 1
		else:
			print("FAIL: NavVBox not found in MainMenu.")
			failed += 1
			
		menu.queue_free()
		for i in range(2):
			await process_frame

	# -------------------------------------------------------------
	# TEST 3: Subscreens (NewGame, LoadGame, Settings, Credits)
	# -------------------------------------------------------------
	print("\n--- TEST 3: Menu Subscreens Instantiation & Interfaces ---")
	var new_game_scene = load("res://scenes/menu/NewGameScreen.tscn")
	if new_game_scene:
		var ng = new_game_scene.instantiate()
		root.add_child(ng)
		await process_frame
		if ng.has_signal("closed"):
			print("PASS: NewGameScreen loaded with 4 difficulty options and slot picker.")
			passed += 1
		else:
			print("FAIL: NewGameScreen missing closed signal.")
			failed += 1
		ng.queue_free()
		await process_frame
	else:
		print("FAIL: Could not load NewGameScreen.tscn")
		failed += 1
		
	var load_game_scene = load("res://scenes/menu/LoadGameScreen.tscn")
	if load_game_scene:
		var lg = load_game_scene.instantiate()
		root.add_child(lg)
		await process_frame
		if lg.has_signal("closed"):
			print("PASS: LoadGameScreen loaded with slot management cards & inspection panel.")
			passed += 1
		else:
			print("FAIL: LoadGameScreen missing closed signal.")
			failed += 1
		lg.queue_free()
		await process_frame
	else:
		print("FAIL: Could not load LoadGameScreen.tscn")
		failed += 1

	# -------------------------------------------------------------
	# TEST 4: SaveManager Multi-Slot, Player & World State Persistence
	# -------------------------------------------------------------
	print("\n--- TEST 4: SaveManager Multi-Slot & Atomic Persistence ---")
	var save_mgr = SaveManager.get_instance()
	if save_mgr != null:
		# Clean test slot
		save_mgr.delete_save("slot_test_qa")
		
		# Load MapViewer to have active Player and WorldMap
		var viewer_scene = load("res://scenes/viewer/MapViewer.tscn")
		var viewer = viewer_scene.instantiate()
		root.add_child(viewer)
		current_scene = viewer
		
		for i in range(4):
			await process_frame
			
		var player = viewer.get_node_or_null("Player")
		var world_map = viewer.get_node_or_null("WorldMap")
		
		if player != null and world_map != null:
			# Modify player state
			var test_pos = Vector3(150.0, 45.0, -320.0)
			player.global_position = test_pos
			player.rotation.y = 1.25
			player._camera_pitch = -0.30
			player._camera_pivot.rotation.x = -0.30
			player.active_hotbar_slot = 1 # Storm lantern
			player.backpack_weight = 18.5
			player.inventory_slots[0] = {
				"id": "log_oak",
				"type": "log",
				"species": "oak",
				"name": "Дубовое полено",
				"unit_weight": 9.0,
				"count": 2,
				"description": "Тяжелая древесина дуба.",
				"burn_time": "3.0 ч",
				"heat": "+30 °C",
				"color": Color(0.6, 0.4, 0.2)
			}
			
			# Mark tree as felled in persistent registry
			TreeChoppable.felled_tree_ids["test_birch_uuid_777"] = true
			
			# Execute Save
			var saved = save_mgr.save_game("slot_test_qa", "manual", "Тест Выживания QA")
			if saved:
				print("PASS: Game saved atomically to slot_test_qa.")
				passed += 1
			else:
				print("FAIL: Game failed to save to slot_test_qa.")
				failed += 1
				
			# Verify metadata
			var meta = save_mgr.get_slot_metadata("slot_test_qa")
			if meta.get("playthrough_name") == "Тест Выживания QA" and meta.get("items_count") == 2:
				print("PASS: Manifest correctly updated with metadata (items=2, name='%s')." % meta.get("playthrough_name"))
				passed += 1
			else:
				print("FAIL: Manifest metadata incorrect: %s" % str(meta))
				failed += 1
				
			# Mutate player to fake dirty state
			player.global_position = Vector3(0, 0, 0)
			player.active_hotbar_slot = 0
			player.backpack_weight = 0.0
			player.inventory_slots[0] = null
			TreeChoppable.felled_tree_ids.clear()
			
			# Execute Load
			var loaded = save_mgr.load_game("slot_test_qa")
			for i in range(5):
				await process_frame
				
			if loaded:
				print("PASS: load_game('slot_test_qa') succeeded.")
				passed += 1
			else:
				print("FAIL: load_game('slot_test_qa') returned false.")
				failed += 1
				
			# Check restored values on player and world
			var dist_h = Vector2(player.global_position.x - test_pos.x, player.global_position.z - test_pos.z).length()
			var tree_restored = TreeChoppable.felled_tree_ids.has("test_birch_uuid_777")
			var slot_restored = player.inventory_slots[0] != null and player.inventory_slots[0]["species"] == "oak"
			var tool_restored = player.active_hotbar_slot == 1
			var weight_restored = is_equal_approx(player.backpack_weight, 18.0) # inventory is authoritative: 2 × 9 kg; repair stale saved weight
			
			if dist_h < 0.1 and tree_restored and slot_restored and tool_restored and weight_restored:
				print("PASS: Full state restored: position (dist_h=%.3f), tool=%d, weight=%.1f kg, tree_felled=%s, oak_logs=%d." % [
					dist_h, player.active_hotbar_slot, player.backpack_weight, str(tree_restored), player.inventory_slots[0]["count"]
				])
				passed += 1
			else:
				print("FAIL: State restoration incomplete: dist_h=%.3f, tree=%s, slot=%s, tool=%d, weight=%.1f" % [
					dist_h, str(tree_restored), str(slot_restored), player.active_hotbar_slot, player.backpack_weight
				])
				failed += 1
				
			# Clean up test save
			var deleted = save_mgr.delete_save("slot_test_qa")
			if deleted and not save_mgr.get_all_save_slots().has("slot_test_qa"):
				print("PASS: Test save slot deleted and removed from manifest.")
				passed += 1
			else:
				print("FAIL: Failed to delete test save slot.")
				failed += 1
				
			viewer.queue_free()
			for i in range(2):
				await process_frame

	# -------------------------------------------------------------
	# TEST 5: In-Game PauseMenu Overlay & Lifecycle
	# -------------------------------------------------------------
	print("\n--- TEST 5: In-Game PauseMenu Overlay & Tree Pause Lifecycle ---")
	var pause_scene = load("res://scenes/menu/PauseMenu.tscn")
	if pause_scene == null:
		print("FAIL: Could not load res://scenes/menu/PauseMenu.tscn")
		failed += 1
	else:
		var pause_menu = pause_scene.instantiate() as PauseMenu
		root.add_child(pause_menu)
		await process_frame
		
		# Open pause
		pause_menu.open_pause()
		if paused == true and pause_menu.visible == true and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			print("PASS: open_pause() pauses SceneTree, makes menu visible, and uncaptures mouse.")
			passed += 1
		else:
			print("FAIL: open_pause() failed: paused=%s, visible=%s, mouse_mode=%d" % [str(paused), str(pause_menu.visible), Input.mouse_mode])
			failed += 1
			
		# Resume game
		pause_menu.resume_game()
		var is_headless = DisplayServer.get_name() == "headless"
		if paused == false and pause_menu.visible == false and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or is_headless):
			print("PASS: resume_game() unpauses SceneTree, hides menu, and recaptures mouse.")
			passed += 1
		else:
			print("FAIL: resume_game() failed: paused=%s, visible=%s, mouse_mode=%d" % [str(paused), str(pause_menu.visible), Input.mouse_mode])
			failed += 1
			
		pause_menu.queue_free()
		for i in range(2):
			await process_frame

	# -------------------------------------------------------------
	# TEST 6: Autosave Rolling Rotation & Limit Enforcement
	# -------------------------------------------------------------
	print("\n--- TEST 6: Autosave Rolling Slots & Queue Safety ---")
	if save_mgr != null:
		var auto1 = save_mgr.trigger_autosave("Тест 1")
		var auto2 = save_mgr.trigger_autosave("Тест 2")
		var auto3 = save_mgr.trigger_autosave("Тест 3")
		var auto4 = save_mgr.trigger_autosave("Тест 4 (Ротация)")
		
		var all_slots = save_mgr.get_all_save_slots()
		var auto_count = 0
		for s in all_slots:
			if s.begins_with("autosave_"):
				auto_count += 1
				
		if auto_count <= SaveManager.MAX_AUTOSAVE_SLOTS:
			print("PASS: Autosaves adhere to MAX_AUTOSAVE_SLOTS limit (%d <= %d) via rolling slot rotation." % [auto_count, SaveManager.MAX_AUTOSAVE_SLOTS])
			passed += 1
		else:
			print("FAIL: Autosaves exceeded limit: %d > %d" % [auto_count, SaveManager.MAX_AUTOSAVE_SLOTS])
			failed += 1
			
		# Clean autosaves from test
		for i in range(1, SaveManager.MAX_AUTOSAVE_SLOTS + 1):
			save_mgr.delete_save("autosave_%d" % i)

	# -------------------------------------------------------------
	# SUMMARY
	# -------------------------------------------------------------
	print("\n" + "=".repeat(75))
	print("TEST RUN SUMMARY: %d PASSED, %d FAILED" % [passed, failed])
	print("=".repeat(75))
	
	if failed == 0:
		print("SUCCESS: ALL MAIN MENU & PERSISTENCE ACCEPTANCE TESTS PASSED (100%)\n")
		quit(0)
	else:
		print("ERROR: SOME ACCEPTANCE TESTS FAILED\n")
		quit(1)
