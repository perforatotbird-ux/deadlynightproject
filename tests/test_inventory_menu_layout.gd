extends SceneTree
var passed := 0
var failed := 0
var screenshot_dir := ""
func _init() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS: ", label)
	else:
		failed += 1
		printerr("FAIL: ", label)
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
func run() -> void:
	if not OS.get_user_data_dir().contains("deadly-night-test"):
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			screenshot_dir = arg.trim_prefix("--screenshots=")
			DirAccess.make_dir_recursive_absolute(screenshot_dir)
	root.size = Vector2i(1280, 720)
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var player = load("res://scenes/player/Player.tscn").instantiate()
	scene.add_child(player)
	player.set_active(true)
	player.set_physics_process(false)
	for i in range(3): await process_frame
	player._is_lmb_held = true
	await key(KEY_TAB)
	check(player._is_inventory_open and player._inv_layer.visible, "Tab opens inventory")
	check(not player._is_lmb_held, "Opening inventory cancels held tool use")
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(player._inv_root_panel.get_global_rect()), "Inventory panel fits the viewport")
	check(player._inv_slot_buttons.size() == 16, "Inventory exposes all sixteen slots")
	player._add_to_backpack({"species": "birch", "weight": 4.0})
	player._add_to_backpack({"species": "birch", "weight": 4.0})
	player._inv_slot_buttons[0].pressed.emit()
	check(player._selected_slot_index == 0 and not player._inv_btn_drop_one.disabled, "Selecting an occupied slot enables item actions")
	if DisplayServer.get_name() != "headless" and not screenshot_dir.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(screenshot_dir.path_join("10-inventory.png"))
	player._inv_btn_drop_one.pressed.emit()
	check(player.inventory_slots[0].count == 1, "Drop-one button removes one item from the stack")
	await key(KEY_ESCAPE)
	check(not player._is_inventory_open and not paused, "Escape closes inventory without opening pause")
	await key(KEY_ESCAPE)
	check(paused and player._pause_menu.visible, "Next Escape opens pause")
	player._pause_menu.resume_game()
	current_scene = null
	scene.queue_free()
	for i in range(4): await process_frame
	for child in root.get_children(): child.queue_free()
	for i in range(3): await process_frame
	print("INVENTORY MENU SUMMARY: %d PASSED, %d FAILED" % [passed, failed])
	quit(1 if failed else 0)
