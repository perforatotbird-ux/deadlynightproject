extends SceneTree
## Run only with an isolated OS user-data directory; see Docs/menu_qa_report.md.
const Settings = preload("res://scripts/core/SettingsManager.gd")
const Saves = preload("res://scripts/core/SaveManager.gd")
const Confirm = preload("res://scripts/ui/ConfirmDialog.gd")
var passed := 0
var failed := 0
var screenshots := ""
var hide_world_rendering := false

func _init() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", label)
	else:
		failed += 1
		printerr("FAIL: ", label)

func settle(count: int = 3) -> void:
	for i in range(count):
		await process_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await settle(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await settle(2)

func click(button: Button) -> void:
	var point = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	root.push_input(event, true)
	await settle(1)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await settle(2)

func capture(label: String) -> void:
	if screenshots.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(screenshots.path_join(label + ".png"))

func dialog() -> Control:
	for node in get_nodes_in_group("menu_confirmation"):
		if not node.is_queued_for_deletion():
			return node
	return null

func run() -> void:
	if not OS.get_user_data_dir().contains("deadly-night-test"):
		printerr("Use an isolated user directory containing 'deadly-night-test'; refusing to touch real saves.")
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg == "--hide-world-rendering":
			hide_world_rendering = true
		if arg.begins_with("--screenshots="):
			screenshots = arg.trim_prefix("--screenshots=")
			DirAccess.make_dir_recursive_absolute(screenshots)
	var settings = Settings.get_instance()
	await settle()
	settings.reset_to_defaults()
	var saves = Saves.get_instance()
	await settle()
	for data in saves.list_save_slots():
		saves.delete_save(data.slot_id)
	var menu = load("res://scenes/menu/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await create_timer(0.9).timeout
	check(menu._btn_continue.disabled, "Continue disabled without saves")
	await capture("01-main-menu")
	await click(menu._btn_settings)
	await settle(5)
	var screen = menu._active_subscreen
	check(screen != null and screen.get_parent() is CanvasLayer, "Settings opens above the main-menu canvas")
	check(menu._btn_new_game.disabled, "Background menu cannot activate behind a subscreen")
	var viewport_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	check(viewport_rect.encloses(screen._main_panel.get_global_rect()), "Settings panel fits inside the viewport")
	check(screen._main_panel.get_global_rect().get_center().distance_to(viewport_rect.get_center()) < 2.0, "Settings panel is centered")
	check(screen.size == root.get_visible_rect().size, "Settings scrim covers the full viewport")
	for tab in range(4):
		screen._tab_container.current_tab = tab
		await settle(5)
		check(screen._tab_container.get_child(tab) is ScrollContainer, "Settings tab %d has bounded scrolling" % tab)
		await capture("02-settings-tab-%d" % tab)
	var old_volume = settings.get_setting("audio", "master_volume")
	screen._slider_master.value = 0.25
	check(is_equal_approx(settings.get_bus_volume_linear("Master"), 0.25), "Audio slider previews live")
	check(is_equal_approx(settings.get_setting("audio", "master_volume"), old_volume), "Audio preview does not mutate persisted settings")
	screen._start_rebinding("move_forward", screen._keybind_buttons.move_forward)
	await key(KEY_ESCAPE)
	check(is_instance_valid(screen) and screen._awaiting_action.is_empty(), "Escape cancels key capture without closing settings")
	screen._start_rebinding("move_forward", screen._keybind_buttons.move_forward)
	await key(KEY_Z)
	check(screen._draft_keybindings.move_forward == KEY_Z and settings.get_setting("controls", "keybindings").move_forward == KEY_W, "Key changes are staged until Apply")
	await key(KEY_ESCAPE)
	check(menu._active_subscreen == null and is_equal_approx(settings.get_bus_volume_linear("Master"), old_volume), "Back closes settings and restores audio preview")
	menu._btn_settings.pressed.emit()
	await settle()
	screen = menu._active_subscreen
	screen._on_defaults_pressed()
	await settle()
	check(dialog() != null, "Defaults requires confirmation")
	await key(KEY_ESCAPE)
	check(dialog() == null and is_instance_valid(screen), "Escape dismisses only the confirmation")
	# Exercise timeout, cancellation and keep paths even with headless display.
	screen._start_resolution_confirmation(0, Vector2i(1280, 720))
	await settle()
	screen._rollback_seconds_left = 1
	screen._rollback_timer.timeout.emit()
	await settle()
	check(not screen._rollback_active and dialog() == null, "Resolution timeout closes its dialog and timer")
	screen._start_resolution_confirmation(0, Vector2i(1280, 720))
	await settle()
	await key(KEY_ESCAPE)
	check(not screen._rollback_active and dialog() == null and is_instance_valid(screen), "Resolution Escape rolls back but keeps settings open")
	screen._start_resolution_confirmation(0, Vector2i(1280, 720))
	await settle()
	dialog()._btn_confirm.pressed.emit()
	await settle()
	check(not screen._rollback_active and dialog() == null, "Keep resolution completes confirmation")
	if DisplayServer.get_name() != "headless":
		screen._opt_resolution.selected = 1
		screen._on_apply_pressed()
		await settle(5)
		check(screen._rollback_active and dialog() != null, "Real window resize opens display confirmation")
		await key(KEY_ESCAPE)
		check(DisplayServer.window_get_size() == Vector2i(1280, 720), "Display cancellation restores actual window dimensions")
	screen._slider_fov.value = 95
	screen._chk_bobbing.button_pressed = false
	screen._chk_hud.button_pressed = false
	screen._slider_master.value = 0.4
	screen._draft_keybindings.move_forward = KEY_Z
	await click(screen._btn_apply)
	check(settings.get_setting("controls", "fov") == 95 and settings.get_setting("controls", "keybindings").move_forward == KEY_Z, "Apply persists controls and keybindings")
	check(is_equal_approx(settings.get_setting("audio", "master_volume"), 0.4), "Apply commits the audio preview")
	await key(KEY_ESCAPE)
	menu._btn_load_game.pressed.emit()
	await settle()
	screen = menu._active_subscreen
	check(screen._save_cards.is_empty() and screen._btn_load.disabled and screen._btn_delete.disabled, "Load menu handles an empty save list")
	await capture("03-empty-load-menu")
	await key(KEY_ESCAPE)
	menu._btn_credits.pressed.emit()
	await settle()
	check(menu._active_subscreen != null, "Credits opens")
	await capture("04-credits")
	await key(KEY_ESCAPE)
	check(menu._active_subscreen == null, "Credits returns to main menu")
	menu._btn_quit.pressed.emit()
	await settle()
	check(dialog() != null, "Quit requires confirmation")
	await capture("05-quit-confirmation")
	await key(KEY_ESCAPE)
	check(is_instance_valid(menu) and dialog() == null, "Quit can be cancelled")
	saves.save_game("slot_1", "manual", "QA occupied slot")
	menu._update_save_states()
	check(not menu._btn_continue.disabled, "Continue enabled after a save exists")
	menu._btn_new_game.pressed.emit()
	await settle()
	screen = menu._active_subscreen
	check(screen._slot_option.item_count == 5 and screen._diff_buttons.size() == 4, "New-game menu exposes five slots and four difficulty choices")
	for i in range(4):
		screen._diff_buttons[i].pressed.emit()
		check(screen._selected_difficulty_idx == i and not screen._diff_desc_label.text.is_empty(), "Difficulty selection %d updates description" % i)
	await capture("06-new-game")
	screen._on_start_pressed()
	await settle()
	check(dialog() != null, "Occupied slot requires overwrite confirmation")
	await key(KEY_ESCAPE)
	check(is_instance_valid(screen) and dialog() == null, "Overwrite cancellation keeps the new-game screen")
	screen._input_name.text = "Menu integration QA"
	screen._on_start_pressed()
	await settle()
	if hide_world_rendering:
		RenderingServer.set_render_loop_enabled(false)
	dialog()._btn_confirm.pressed.emit()
	await settle(8)
	if hide_world_rendering:
		current_scene.get_node("WorldMap").hide()
		RenderingServer.set_render_loop_enabled(true)
	check(current_scene != null and current_scene.name == "MapViewer", "Confirmed new game enters the real game scene")
	var game = current_scene
	var player = game.get_node("Player")
	check(is_equal_approx(player._camera.fov, 95) and not player._hud_layer.visible, "Applied FOV and HUD settings reach the real player")
	check(not player._camera_bobbing_enabled, "Camera bobbing preference reaches the player")
	var test_event := InputEventKey.new()
	test_event.keycode = KEY_Z
	check(player._event_matches_action(test_event, "move_forward"), "Rebound movement key is recognized in gameplay")
	settings.set_setting("graphics", "shadow_quality", 0)
	settings.set_setting("graphics", "view_distance", 0)
	settings.apply_graphics_settings()
	check(not game.get_node("DirectionalLight3D").shadow_enabled and is_equal_approx(player._camera.far, 1500), "Graphics settings affect shadows and camera draw distance")
	var pause = player._pause_menu
	await key(KEY_ESCAPE)
	check(paused and pause.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape opens in-game pause")
	await capture("07-pause")
	pause._btn_settings.pressed.emit()
	await settle(5)
	check(pause._active_subscreen != null and not pause._main_panel.visible, "Pause settings hide background actions")
	await capture("08-pause-settings")
	await key(KEY_ESCAPE)
	check(paused and pause.visible and pause._active_subscreen == null and pause._main_panel.visible, "Escape from pause settings returns to pause, not gameplay")
	pause._btn_main_menu.pressed.emit()
	await settle()
	await key(KEY_ESCAPE)
	check(paused and pause.visible and dialog() == null, "Escape cancels exit-to-main without resuming gameplay")
	pause._btn_quick_save.pressed.emit()
	check(pause._toast_label.visible and saves.has_any_saves(), "Pause quick-save produces visible feedback")
	pause._btn_load_game.pressed.emit()
	await settle(5)
	screen = pause._active_subscreen
	check(screen._save_cards.size() > 0 and not screen._btn_load.disabled, "Pause load menu lists saves")
	var count = screen._save_cards.size()
	screen._refresh_list()
	screen._refresh_list()
	await settle()
	check(screen._list_container.get_child_count() == count, "Refreshing saves does not duplicate cards")
	screen._on_delete_pressed()
	await settle()
	await key(KEY_ESCAPE)
	check(is_instance_valid(screen) and paused and dialog() == null, "Delete confirmation cancellation leaves load menu intact")
	await capture("09-populated-load-menu")
	screen._btn_load.pressed.emit()
	await settle(5)
	check(not paused and not pause.visible and pause._active_subscreen == null, "Loading from pause restores gameplay and closes pause")
	pause.open_pause()
	pause._on_main_menu_pressed()
	await settle()
	dialog()._btn_confirm.pressed.emit()
	await settle(8)
	check(not paused and current_scene.name == "MainMenu", "Confirmed exit returns to unpaused main menu")
	menu = current_scene
	if hide_world_rendering:
		RenderingServer.set_render_loop_enabled(false)
	menu._btn_continue.pressed.emit()
	await create_timer(0.6).timeout
	await settle(8)
	if hide_world_rendering:
		current_scene.get_node("WorldMap").hide()
		RenderingServer.set_render_loop_enabled(true)
	check(current_scene.name == "MapViewer", "Continue loads the latest save into gameplay")
	pause = current_scene.get_node("Player")._pause_menu
	pause.open_pause()
	pause._on_main_menu_pressed()
	await settle()
	dialog()._btn_confirm.pressed.emit()
	await settle(8)
	menu = current_scene
	menu._on_load_game_pressed()
	await settle()
	screen = menu._active_subscreen
	# Delete a real test save via the confirmation; keep the file operation isolated.
	var selected_slot: String = screen._save_data_list[screen._selected_idx].slot_id
	screen._on_delete_pressed()
	await settle()
	dialog()._btn_confirm.pressed.emit()
	await settle()
	check(saves.get_slot_metadata(selected_slot).is_empty(), "Confirmed deletion removes the selected slot")
	# A missing save must not dismiss the whole load menu.
	screen._save_data_list.clear()
	screen._save_data_list.append({"slot_id": "qa_missing_slot"})
	screen._selected_idx = 0
	screen._on_load_pressed()
	check(not screen.is_queued_for_deletion() and screen._detail_info_lbl.text.contains("Не удалось"), "Failed load stays open with an actionable error")
	await key(KEY_ESCAPE)
	menu._on_settings_pressed()
	await settle()
	screen = menu._active_subscreen
	screen._on_defaults_pressed()
	await settle()
	dialog()._btn_confirm.pressed.emit()
	await settle()
	check(settings.get_setting("controls", "fov") == 75.0 and settings.get_setting("controls", "keybindings").move_forward == KEY_W, "Confirmed defaults restore controls and bindings")
	check(settings.get_setting("gameplay", "hud_visible") == true, "Confirmed defaults restore gameplay settings")
	await key(KEY_ESCAPE)
	# A stale manifest must not leave Continue stuck behind a black fade.
	saves.save_game("qa_stale_continue", "manual", "Stale slot QA")
	DirAccess.remove_absolute("user://saves/qa_stale_continue.json")
	menu._update_save_states()
	menu._latest_slot_id = "qa_stale_continue"
	menu._on_continue_pressed()
	await create_timer(0.6).timeout
	await settle()
	check(current_scene == menu and not menu._fade_rect.visible and not menu._transitioning, "Failed Continue restores the main menu instead of a black screen")
	check(menu._status_label.text.contains("Не удалось"), "Failed Continue explains the error")
	saves.delete_save("qa_stale_continue")
	# Clean up scenes before singleton managers, while the renderer is still alive.
	current_scene = null
	menu.queue_free()
	await settle(4)
	paused = false
	for child in root.get_children():
		child.queue_free()
	await settle(4)
	print("MENU NAVIGATION SUMMARY: %d PASSED, %d FAILED" % [passed, failed])
	quit(1 if failed > 0 else 0)
