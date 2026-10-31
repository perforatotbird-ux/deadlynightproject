extends SceneTree
## Isolated actual MapViewer + native GUI acceptance for the minimal pause.
const Settings = preload("res://scripts/core/SettingsManager.gd")
const Saves = preload("res://scripts/core/SaveManager.gd")
var passes := 0
var failures := 0
var out := OS.get_environment("DN_QA_OUTPUT")
var capture_only := "--capture-only-render" in OS.get_cmdline_user_args()

func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if ok: passes += 1; print("PASS: ", text)
	else: failures += 1; printerr("FAIL: ", text)
func settle(frames: int = 4) -> void:
	for i in frames: await process_frame
func key(code: Key) -> void:
	for down in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code; event.physical_keycode = code; event.pressed = down
		root.push_input(event, true)
		await process_frame
	await settle()
func click(button: Button) -> void:
	var point = button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new(); motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.position = point; event.global_position = point; event.pressed = down
		root.push_input(event, true)
		await process_frame
	await settle()
func dialog() -> Control:
	for node in get_nodes_in_group("menu_confirmation"):
		if not node.is_queued_for_deletion(): return node
	return null
func shot(name: String) -> void:
	if out.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(out)
	if capture_only: RenderingServer.set_render_loop_enabled(true)
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	check(image.get_size() == root.size, "capture matches physical Window size: " + name)
	image.save_png(out.path_join(name + ".png"))
	if capture_only: RenderingServer.set_render_loop_enabled(false)
func resize_window(size: Vector2i) -> void:
	root.min_size = Vector2i(640,480)
	root.size = size
	await settle(8)
	check(root.size == size, "actual Window size is %s" % size)
func gamepad_cancel() -> void:
	await gamepad(JOY_BUTTON_B)
func gamepad(button: JoyButton) -> void:
	for down in [true, false]:
		var event = InputEventJoypadButton.new()
		event.button_index = button; event.pressed = down
		root.push_input(event, true)
		await process_frame
	await settle()

func run() -> void:
	if not OS.get_user_data_dir().contains("deadly-night-test"):
		printerr("Use isolated XDG_DATA_HOME containing deadly-night-test"); quit(2); return
	var settings = Settings.get_instance()
	await settle()
	settings.set_setting("graphics", "shadow_quality", 0)
	settings.set_setting("gameplay", "hud_visible", true)
	if DisplayServer.get_name() != "headless": RenderingServer.set_render_loop_enabled(false)
	var game = load("res://scenes/viewer/MapViewer.tscn").instantiate()
	root.add_child(game); current_scene = game
	var player = game.get_node("Player")
	player.set_physics_process(false)
	var world = game.get_node("WorldMap")
	# QA rendering budget only: keep actual nearby terrain and forest, not a fake backdrop.
	var origin = player.global_position
	for chunk in world._vegetation_root.get_children():
		var chunk_pos = Vector3.ZERO
		if chunk.get_child_count() > 0:
			var mmi = chunk.get_child(0)
			if mmi.multimesh.instance_count > 0: chunk_pos = mmi.multimesh.get_instance_transform(0).origin
		if Vector2(chunk_pos.x-origin.x,chunk_pos.z-origin.z).length() > 300: chunk.hide()
	for mesh in world._collect_all_meshes(world._terrain_root):
		var aabb = mesh.global_transform * mesh.get_aabb()
		if not aabb.grow(220).has_point(origin): mesh.hide()
	player._camera.far = 220
	game.get_node("DirectionalLight3D").shadow_enabled = false
	game.get_node("WorldMap/POIs_and_Props").hide() # debug POI poles, test screenshots only
	player.rotation.y = deg_to_rad(-35)
	if DisplayServer.get_name() != "headless" and not capture_only: RenderingServer.set_render_loop_enabled(true)
	await physics_frame; await settle(8)
	var s = player.survival
	s.clock = 17 * 3600 + 23 * 60
	s.weather_model.reset(s.clock, false)
	var menu = player._pause_menu
	var saves = Saves.get_instance()
	saves.current_slot_id = "minimal_pause_qa"
	await key(KEY_ESCAPE)
	check(paused and menu.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "real Escape opens pause and releases mouse")
	check(root.gui_get_focus_owner() == menu._btn_resume, "Continue has initial keyboard focus")
	check(not menu._main_panel is PanelContainer, "pause has no central boxed panel")
	check(menu._buttons.size() == 6 and menu._btn_resume.text == "Продолжить", "six plain-language actions without emoji")
	check(menu._world_label.text.contains("17:23") and not menu._slot_info_label.text.contains("slot_"), "real clock and localized metadata, no slot identifier")
	var time = s.clock
	await create_timer(0.2, true).timeout
	check(s.clock == time, "authoritative world clock stops on pause")
	var hud_hidden = true
	for hud in get_nodes_in_group("gameplay_hud"): hud_hidden = hud_hidden and not hud.visible
	check(hud_hidden and not player._hud_layer.visible and not s.ui.visible, "crosshair, belt, survival HUD and FPS are hidden")
	check(menu._last_save_label.text.contains("нет сохранения"), "unsaved slot is not described as saved")
	for dimensions in [Vector2i(800,600),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		await resize_window(dimensions)
		var bounds = root.get_visible_rect()
		for button in menu._buttons:
			check(bounds.encloses(button.get_global_rect()), "%s action fits: %s" % [dimensions, button.text])
		check(menu._actions.get_global_rect().end.y < menu._footer.get_global_rect().position.y, "%s navigation and metadata do not overlap" % dimensions)
		check(bounds.encloses(menu._footer.get_global_rect()), "%s footer fits viewport" % dimensions)
		check(not menu._paused_label.visible or bounds.encloses(menu._paused_label.get_global_rect()), "%s pause caption fits viewport" % dimensions)
		await shot("pause_%dx%d" % [dimensions.x,dimensions.y])
	await resize_window(Vector2i(1280,720))
	await key(KEY_DOWN)
	check(root.gui_get_focus_owner() == menu._btn_quick_save, "Down moves keyboard focus to save")
	await click(menu._btn_quick_save)
	check(menu._toast_label.visible and menu._toast_label.text == "Игра сохранена" and saves.has_any_saves(), "actual mouse save writes slot and reports success")
	await shot("pause_save_success")
	var before = FileAccess.get_file_as_string("user://saves/minimal_pause_qa.json")
	saves._test_write_failure_stage = "write"
	await key(KEY_F5)
	check(menu._toast_label.text.begins_with("Не удалось") and FileAccess.get_file_as_string("user://saves/minimal_pause_qa.json") == before, "F5 write fault is reported and previous slot is intact")
	saves._test_write_failure_stage = ""
	await shot("pause_save_error")
	await click(menu._btn_settings)
	check(is_instance_valid(menu._active_subscreen) and not menu._main_panel.visible, "mouse opens settings and hides underlying navigation")
	await shot("pause_settings")
	await key(KEY_ESCAPE)
	check(paused and menu._active_subscreen == null and root.gui_get_focus_owner() == menu._btn_settings, "Escape from settings returns to pause with focus restored")
	await click(menu._btn_main_menu)
	check(dialog() != null and root.gui_get_focus_owner() == dialog()._btn_cancel, "exit confirmation defaults to safe action")
	await shot("pause_confirm")
	await key(KEY_ESCAPE)
	check(paused and menu.visible and dialog() == null, "Escape cancels only confirmation")
	await click(menu._btn_load_game)
	check(menu._active_subscreen._save_cards.size() > 0, "load screen lists the actual saved slot")
	check(not menu._active_subscreen._detail_info_lbl.text.contains("Координаты") and not menu._active_subscreen._detail_info_lbl.text.contains("Идентификатор"), "pause load details omit debug coordinates and slot IDs")
	await shot("pause_load")
	await gamepad_cancel()
	check(paused and menu._active_subscreen == null, "gamepad B returns from load to pause")
	settings.set_setting("gameplay", "hud_visible", false); player._apply_player_settings()
	await key(KEY_ESCAPE)
	check(not paused and not menu.visible and not player._hud_layer.visible, "resume respects HUD disabled during pause")
	check(not player._is_lmb_held, "resume does not carry a held axe attack")
	settings.set_setting("gameplay", "hud_visible", true); player._apply_player_settings()
	menu.open_pause(); await settle()
	await click(menu._btn_load_game)
	await click(menu._active_subscreen._btn_load)
	check(not paused and not menu.visible and menu._active_subscreen == null, "actual same-scene load exits pause")
	check(player._hud_layer.visible and s.ui.visible, "same-scene load restores gameplay HUD layers")
	await shot("gameplay_restored")
	menu.open_pause(); await settle(); await gamepad_cancel()
	check(not paused and not menu.visible, "gamepad B resumes from root pause")
	for i in 5:
		menu.open_pause(); await settle(1); menu.resume_game()
	check(menu._hud_visibility.is_empty() and player._hud_layer.visible, "repeated open/close does not lose HUD visibility")
	await gamepad(JOY_BUTTON_START)
	check(paused and menu.visible, "controller Start opens real gameplay pause")
	await gamepad(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() == menu._btn_quick_save, "controller D-pad moves actual GUI focus")
	menu._btn_settings.grab_focus()
	await gamepad(JOY_BUTTON_A)
	check(is_instance_valid(menu._active_subscreen), "controller A activates focused Settings")
	var settings_screen = menu._active_subscreen
	var action = settings_screen._keybind_buttons.keys()[0]
	settings_screen._start_rebinding(action, settings_screen._keybind_buttons[action])
	await gamepad_cancel()
	check(is_instance_valid(menu._active_subscreen) and settings_screen._awaiting_action == "", "controller B cancels key capture without closing settings")
	await gamepad_cancel()
	await gamepad(JOY_BUTTON_START)
	check(not paused and not menu.visible, "controller Start resumes pause after returning from settings")
	var health = s.health
	s.health = 0
	await gamepad(JOY_BUTTON_START)
	check(paused and menu.visible, "controller can open load menu after death")
	menu._on_quit_pressed(); menu._on_quit_pressed(); await settle()
	check(get_nodes_in_group("menu_confirmation").size() == 1, "repeated exit request creates only one confirmation")
	await gamepad_cancel()
	check(paused and dialog() == null, "controller B cancels exit without resuming the world")
	menu.resume_game(); s.health = health
	# An explicitly hidden HUD must stay hidden, rather than being blindly shown.
	player._hud_layer.hide(); menu.open_pause(); menu.resume_game()
	check(not player._hud_layer.visible, "pre-existing hidden HUD stays hidden")
	player._hud_layer.show()
	saves.delete_save("minimal_pause_qa")
	game.queue_free(); current_scene = null; await settle(8)
	await create_timer(0.3).timeout
	print("MINIMAL PAUSE SUMMARY: %d PASS, %d FAIL" % [passes, failures])
	quit(1 if failures else 0)
