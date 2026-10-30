extends SceneTree

const PlayerController = preload("res://scripts/player/PlayerController.gd")

func _init() -> void:
	_run_inventory_tests()

func _run_inventory_tests() -> void:
	print("=".repeat(70))
	print("RUNNING INVENTORY & STACKING SYSTEM TEST (Godot 4.7.2)")
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
	if not player:
		print("FAIL: Player node not found")
		quit(1)
		return
		
	print("\n[TEST 1] Initial Inventory State...")
	print("  -> Initial weight: %.1f kg, Slots count: %d" % [player.backpack_weight, player.inventory_slots.size()])
	if player.backpack_weight == 0.0 and player.inventory_slots.size() == 16:
		print("  -> PASS: 16 empty slots, initial weight 0.0 kg.")
		passed += 1
	else:
		print("  -> FAIL: Initial state incorrect.")
		failed += 1
		
	print("\n[TEST 2] Wood Stacking Logic...")
	# Add first birch log
	player._add_to_backpack({"species": "birch", "weight": 4.0})
	var slot0 = player.inventory_slots[0]
	if slot0 != null and slot0["species"] == "birch" and slot0["count"] == 1:
		print("  -> Added log 1: Slot 0 has Birch x1 (weight: %.1f kg)" % player.backpack_weight)
	else:
		print("  -> FAIL: First log not added to slot 0.")
		failed += 1
		
	# Add second birch log (should stack into slot 0!)
	player._add_to_backpack({"species": "birch", "weight": 4.0})
	slot0 = player.inventory_slots[0]
	if slot0 != null and slot0["species"] == "birch" and slot0["count"] == 2 and player.inventory_slots[1] == null:
		print("  -> Added log 2: Successfully stacked into Slot 0! Birch x%d (weight: %.1f kg)" % [slot0["count"], player.backpack_weight])
		print("  -> PASS: Wood logs stack properly in the same slot.")
		passed += 1
	else:
		print("  -> FAIL: Wood logs did not stack into slot 0.")
		failed += 1
		
	# Add oak log (different species -> goes to slot 1)
	player._add_to_backpack({"species": "oak", "weight": 9.0})
	var slot1 = player.inventory_slots[1]
	if slot1 != null and slot1["species"] == "oak" and slot1["count"] == 1:
		print("  -> Added Oak log: Placed into Slot 1! Oak x1 (Total weight: %.1f kg)" % player.backpack_weight)
		print("  -> PASS: Different species occupies next slot.")
		passed += 1
	else:
		print("  -> FAIL: Oak log not placed into slot 1.")
		failed += 1
		
	print("\n[TEST 3] TAB Inventory Open & Mouse Mode Toggle...")
	# Simulate TAB press
	var tab_event = InputEventKey.new()
	tab_event.keycode = KEY_TAB
	tab_event.pressed = true
	player._input(tab_event)
	
	if player._is_inventory_open and player._inv_layer.visible:
		print("  -> PASS: TAB key opened inventory, inventory layer visible.")
		passed += 1
	else:
		print("  -> FAIL: TAB key did not open inventory.")
		failed += 1
		
	print("\n[TEST 4] Slot Selection & Drop Mechanics...")
	# Select slot 0 (Birch x2)
	player._on_slot_clicked(0)
	if player._selected_slot_index == 0 and player._inv_inspector_box.visible:
		print("  -> PASS: Slot 0 selected, inspector details populated.")
		passed += 1
	else:
		print("  -> FAIL: Slot selection failed.")
		failed += 1
		
	# Drop 1 birch log
	var w_before_drop = player.backpack_weight
	player.drop_selected_item(false) # drop 1
	slot0 = player.inventory_slots[0]
	if slot0 != null and slot0["count"] == 1 and player.backpack_weight == w_before_drop - 4.0:
		print("  -> PASS: Dropped 1 log. Remaining in stack: x1, backpack weight: %.1f kg." % player.backpack_weight)
		passed += 1
	else:
		print("  -> FAIL: Dropping 1 log failed.")
		failed += 1
		
	print("\n[TEST 5] TAB Inventory Close...")
	# Simulate TAB press again to close
	player._input(tab_event)
	if not player._is_inventory_open and not player._inv_layer.visible and player._is_mouse_captured:
		print("  -> PASS: TAB key closed inventory, returned to mouse look.")
		passed += 1
	else:
		print("  -> FAIL: Closing inventory failed.")
		failed += 1
		
	print("\n" + "=".repeat(70))
	print("INVENTORY TEST SUMMARY: %d PASSED, %d FAILED." % [passed, failed])
	print("=".repeat(70))
	
	quit(0 if failed == 0 else 1)
