extends SceneTree

const PlayerController = preload("res://scripts/player/PlayerController.gd")

func _init() -> void:
	_run_toolbelt_test()

func _run_toolbelt_test() -> void:
	print("=".repeat(70))
	print("RUNNING INVENTORY TOOLBELT / HOTBAR TEST (Godot 4.7.2)")
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
	
	# Settle frames
	for i in range(5):
		await process_frame
		
	var player = viewer.get_node_or_null("Player") as PlayerController
	if not player:
		print("FAIL: Player node not found")
		quit(1)
		return
		
	print("\n[TEST 1] Toolbelt Initialization...")
	if player._toolbelt_panel != null and player._hotbar_slot_buttons.size() == 5:
		print("  -> Toolbelt panel instantiated with 5 tool slots.")
		if player.active_hotbar_slot == 0 and player._axe_anim_pivot.visible:
			print("  -> Slot 0 (Axe) is active by default, viewmodel visible.")
			passed += 1
		else:
			print("  -> FAIL: Slot 0 was not active or axe viewmodel hidden.")
			failed += 1
	else:
		print("  -> FAIL: Toolbelt panel or slots missing.")
		failed += 1
		
	print("\n[TEST 2] Switching to Lantern (Key 2)...")
	var key2 = InputEventKey.new()
	key2.pressed = true
	key2.keycode = KEY_2
	player._input(key2)
	
	if player.active_hotbar_slot == 1 and not player._axe_anim_pivot.visible:
		print("  -> PASS: Key 2 equipped Storm Lantern, axe viewmodel stowed.")
		# Test LMB toggling lantern light
		var click_event = InputEventMouseButton.new()
		click_event.button_index = MOUSE_BUTTON_LEFT
		click_event.pressed = true
		player._input(click_event)
		
		if player._is_lantern_on and player._lantern_light.visible:
			print("  -> PASS: LMB toggled lantern light ON.")
			player._input(click_event) # Toggle off
			if not player._is_lantern_on and not player._lantern_light.visible:
				print("  -> PASS: LMB toggled lantern light OFF.")
				passed += 1
			else:
				print("  -> FAIL: Lantern light did not toggle off.")
				failed += 1
		else:
			print("  -> FAIL: Lantern light did not turn on.")
			failed += 1
	else:
		print("  -> FAIL: Slot 1 not equipped properly.")
		failed += 1

	print("\n[TEST 3] Switching to Compass (Key 3)...")
	var key3 = InputEventKey.new()
	key3.pressed = true
	key3.keycode = KEY_3
	player._input(key3)
	
	# Simulate 1 frame for physics process to update heading
	player._physics_process(0.016)
	
	if player.active_hotbar_slot == 2 and player._compass_label != null:
		print("  -> Compass label text: '%s'" % player._compass_label.text)
		if player._compass_label.text.contains("КОМПАС") and player._compass_label.visible:
			print("  -> PASS: Compass equipped and displaying dynamic azimuth.")
			passed += 1
		else:
			print("  -> FAIL: Compass label not visible or missing text.")
			failed += 1
	else:
		print("  -> FAIL: Slot 2 (Compass) not active.")
		failed += 1

	print("\n[TEST 4] Switching to Matches (Key 4) and Knife (Key 5)...")
	var key4 = InputEventKey.new()
	key4.pressed = true
	key4.keycode = KEY_4
	player._input(key4)
	var matches_ok = (player.active_hotbar_slot == 3 and player._tool_banner_label.text.contains("СПИЧКИ"))
	
	var key5 = InputEventKey.new()
	key5.pressed = true
	key5.keycode = KEY_5
	player._input(key5)
	var knife_ok = (player.active_hotbar_slot == 4 and player._tool_banner_label.text.contains("НОЖ"))
	
	if matches_ok and knife_ok:
		print("  -> PASS: Keys 4 & 5 properly equipped Matches and Hunting Knife.")
		passed += 1
	else:
		print("  -> FAIL: Matches or Knife selection failed.")
		failed += 1

	print("\n[TEST 5] Mouse Wheel Cycling...")
	# Currently at slot 4 (Knife). Wheel Down -> wrap to slot 0 (Axe)
	player.cycle_hotbar_slot(1)
	var wrap_to_axe = (player.active_hotbar_slot == 0 and player._axe_anim_pivot.visible)
	
	# Wheel Up -> back to slot 4 (Knife)
	player.cycle_hotbar_slot(-1)
	var wrap_to_knife = (player.active_hotbar_slot == 4)
	
	if wrap_to_axe and wrap_to_knife:
		print("  -> PASS: Mouse wheel smoothly cycles forward and backward across toolbelt.")
		passed += 1
	else:
		print("  -> FAIL: Mouse wheel cycling failed.")
		failed += 1

	print("\n[TEST 6] Re-equipping Axe and Prompt Verification...")
	player.select_hotbar_slot(0)
	if player.active_hotbar_slot == 0 and player._axe_anim_pivot.visible:
		print("  -> PASS: Axe re-equipped as primary tool, ready for action.")
		passed += 1
	else:
		print("  -> FAIL: Axe re-equip failed.")
		failed += 1

	print("=".repeat(70))
	print("TOOLBELT TEST SUMMARY: %d PASSED, %d FAILED." % [passed, failed])
	print("=".repeat(70))
	
	if failed == 0:
		quit(0)
	else:
		quit(1)
