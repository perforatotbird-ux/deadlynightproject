extends CanvasLayer
class_name PauseMenu

const UITheme = preload("res://scripts/ui/UITheme.gd")
const Look = preload("res://scripts/ui/PauseTheme.gd")
const ConfirmDialog = preload("res://scripts/ui/ConfirmDialog.gd")
const SaveManager = preload("res://scripts/core/SaveManager.gd")

signal resumed

var _main_panel: Control
var _btn_resume: Button
var _btn_quick_save: Button
var _btn_load_game: Button
var _btn_settings: Button
var _btn_main_menu: Button
var _btn_quit: Button
var _slot_info_label: Label
var _toast_label: Label
var _active_subscreen: Control
var _root_control: Control
var _brand: Label
var _title: Label
var _paused_label: Label
var _world_label: Label
var _last_save_label: Label
var _actions: VBoxContainer
var _footer: VBoxContainer
var _buttons: Array[Button] = []
var _shortcuts: Array[Label] = []
var _exit_gap: Control
var _hud_visibility: Dictionary = {}
var _previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _previous_hud_preference: bool = true
var _toast_tween: Tween
var _fade_tween: Tween
var _last_refresh: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	set_meta("minimal_pause_style", true)
	UITheme.ensure_gamepad_navigation()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	visible = false
	_root_control.hide()

func _build_ui() -> void:
	_root_control = Control.new()
	_root_control.name = "RootPauseControl"
	_root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root_control)

	# One inexpensive canvas gradient over the actual frozen player camera.
	# No screenshot substitution, screen-texture sampling or blur pass.
	var scrim = TextureRect.new()
	scrim.name = "ForestGradient"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.27, 0.48, 0.72, 1.0])
	gradient.colors = PackedColorArray([Color(0.025,0.045,0.035,0.98), Color(0.025,0.045,0.035,0.94), Color(0.025,0.045,0.035,0.90), Color(0.02,0.03,0.025,0.35), Color(0.02,0.03,0.025,0.24)])
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 1
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.RIGHT
	scrim.texture = texture
	_root_control.add_child(scrim)

	_main_panel = Control.new()
	_main_panel.name = "PauseNavigation"
	_main_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(_main_panel)
	_brand = _label("D E A D L Y   N I G H T", true)
	_main_panel.add_child(_brand)
	_title = _label("Пауза")
	_title.add_theme_font_override("font", Look.SERIF)
	_main_panel.add_child(_title)
	_paused_label = _label("ИГРА ПРИОСТАНОВЛЕНА", true)
	_paused_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# The camera may face a white sky: a quiet translucent backing keeps this
	# secondary caption readable independently of the real scene brightness.
	var caption = StyleBoxFlat.new()
	caption.bg_color = Color(0.025, 0.045, 0.035, 0.86)
	caption.content_margin_left = 10
	caption.content_margin_right = 10
	caption.content_margin_top = 6
	caption.content_margin_bottom = 6
	_paused_label.add_theme_stylebox_override("normal", caption)
	_root_control.add_child(_paused_label)

	_actions = VBoxContainer.new()
	_actions.name = "Actions"
	_main_panel.add_child(_actions)
	_btn_resume = _action("Продолжить", "Esc", resume_game, true)
	_btn_quick_save = _action("Сохранить игру", "F5", _on_quick_save_pressed)
	_btn_load_game = _action("Загрузить игру", "", _on_load_game_pressed)
	_btn_settings = _action("Настройки", "", _on_settings_pressed)
	_exit_gap = Control.new()
	_exit_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actions.add_child(_exit_gap)
	_btn_main_menu = _action("В главное меню", "", _on_main_menu_pressed)
	_btn_quit = _action("Выйти из игры", "", _on_quit_pressed)

	_footer = VBoxContainer.new()
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_panel.add_child(_footer)
	_world_label = _label("")
	_footer.add_child(_world_label)
	_slot_info_label = _label("", true)
	_footer.add_child(_slot_info_label)
	_last_save_label = _label("", true)
	_footer.add_child(_last_save_label)
	_toast_label = _label("")
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.hide()
	_root_control.add_child(_toast_label)

func _label(text: String, muted: bool = false) -> Label:
	var result = Label.new()
	result.text = text
	Look.label(result, 16, muted)
	return result

func _action(text: String, shortcut: String, callback: Callable, primary: bool = false) -> Button:
	var result = Button.new()
	result.text = text
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	Look.button(result, primary)
	UITheme.wire_button_sound(result)
	result.pressed.connect(callback)
	_actions.add_child(result)
	_buttons.append(result)
	var hint = _label(shortcut)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint.offset_right = -16
	result.add_child(hint)
	_shortcuts.append(hint)
	return result

func _layout() -> void:
	if not is_instance_valid(_root_control): return
	var viewport = get_viewport().get_visible_rect().size
	var physical = Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name() != "headless" else viewport
	var unit = maxf(1.0, viewport.x / maxf(physical.x, 1))
	var compact = physical.y < 680
	var margin = maxf(28 * unit, viewport.x * 0.052)
	var width = minf((400 if compact else 430) * unit, viewport.x - margin * 2)
	_main_panel.position = Vector2(margin, 0)
	_main_panel.size = Vector2(width, viewport.y)
	_brand.position = Vector2(0, (24 if compact else 56) * unit)
	_brand.add_theme_font_size_override("font_size", roundi((14 if compact else 16) * unit))
	_title.position = Vector2(-2, (45 if compact else 78) * unit)
	_title.add_theme_font_size_override("font_size", roundi((52 if compact else 72) * unit))
	_actions.position = Vector2(-22 * unit, (120 if compact else 208) * unit)
	_actions.size.x = width + 22 * unit
	_actions.add_theme_constant_override("separation", roundi(4 * unit))
	_exit_gap.custom_minimum_size.y = (14 if compact else 26) * unit
	for index in _buttons.size():
		var button = _buttons[index]
		button.custom_minimum_size = Vector2(0, (44 if compact else 52) * unit)
		button.add_theme_font_size_override("font_size", roundi((20 if compact else 24) * unit))
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style = Look.box(state)
			style.content_margin_left = 22 * unit
			style.content_margin_right = 66 * unit
			button.add_theme_stylebox_override(state, style)
		_shortcuts[index].offset_right = -16 * unit
		_shortcuts[index].add_theme_font_size_override("font_size", roundi(14 * unit))
	_footer.position = Vector2(0, viewport.y - (94 if compact else 102) * unit)
	_footer.size.x = width
	_footer.add_theme_constant_override("separation", roundi(5 * unit))
	for text in [_world_label, _slot_info_label, _last_save_label]:
		text.add_theme_font_size_override("font_size", roundi((14 if compact else 16) * unit))
		text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_paused_label.add_theme_font_size_override("font_size", roundi(12 * unit))
	_paused_label.reset_size()
	_paused_label.position = Vector2(viewport.x - _paused_label.get_minimum_size().x - margin, 56 * unit)
	_paused_label.visible = not compact and viewport.x > width + margin * 3 + _paused_label.get_minimum_size().x
	_toast_label.position = Vector2(margin, viewport.y - 94 * unit)
	_toast_label.size = Vector2(minf(width + 120 * unit, viewport.x - margin * 2), 80 * unit)
	_toast_label.add_theme_font_size_override("font_size", roundi(16 * unit))
	_fit_navigation.call_deferred()

func _fit_navigation() -> void:
	# Containers can retain their previous larger rectangle after shrinking a
	# window/font. Reset after minimum-size notifications have propagated.
	_actions.size.y = _actions.get_combined_minimum_size().y
	_footer.size.y = _footer.get_combined_minimum_size().y
	var viewport = get_viewport().get_visible_rect().size
	var physical = Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name() != "headless" else viewport
	var unit = maxf(1.0, viewport.x / maxf(physical.x, 1))
	var margin = maxf(28 * unit, viewport.x * 0.052)
	_paused_label.size = _paused_label.get_combined_minimum_size()
	_paused_label.position.x = viewport.x - _paused_label.size.x - margin

func _player() -> Node:
	return get_parent() if get_parent() != null and get_parent().get("survival") != null else null

func open_pause() -> void:
	if visible or get_tree().paused: return
	_previous_mouse_mode = Input.mouse_mode
	var player = _player()
	if player:
		_previous_hud_preference = player._hud_enabled
		player._is_lmb_held = false
		player._cancel_chop()
	_hud_visibility.clear()
	_suppress_hud()
	visible = true
	_root_control.show()
	_main_panel.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_toast_tween): _toast_tween.kill()
	_toast_label.hide()
	_footer.show()
	_refresh_info()
	_layout()
	UITheme.trap_focus(_main_panel)
	_btn_resume.grab_focus()
	if is_instance_valid(_fade_tween): _fade_tween.kill()
	_root_control.modulate.a = 0.0
	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(_root_control, "modulate:a", 1.0, 0.15)

func _suppress_hud() -> void:
	for hud in get_tree().get_nodes_in_group("gameplay_hud"):
		if not is_instance_valid(hud): continue
		if not _hud_visibility.has(hud): _hud_visibility[hud] = hud.visible
		hud.hide()

func _restore_hud() -> void:
	for hud in _hud_visibility:
		if is_instance_valid(hud): hud.visible = _hud_visibility[hud]
	_hud_visibility.clear()
	var player = _player()
	if player:
		# Respect HUD preferences changed in Settings, rather than blindly showing it.
		if player._hud_enabled != _previous_hud_preference: player._apply_player_settings()
		if is_instance_valid(player.survival): player.survival.ui.refresh()

func _process(delta: float) -> void:
	if not visible: return
	_suppress_hud() # settings and same-scene loads can refresh HUD while paused
	_last_refresh += delta
	if _last_refresh >= 1.0:
		_last_refresh = 0.0
		_refresh_info()

func _refresh_info() -> void:
	var sm = SaveManager.get_instance()
	var difficulty = {"explorer":"Исследователь", "traveler":"Путешественник", "survivor":"Выживший", "custom":"Особые условия"}
	_slot_info_label.text = "Выживание · " + str(difficulty.get(sm.current_difficulty, "Особые условия"))
	var player = _player()
	_world_label.text = "Игра приостановлена"
	if player and is_instance_valid(player.survival):
		var clock = float(player.survival.clock)
		_world_label.text = "День %d · %02d:%02d" % [int(clock / 86400) + 1, int(fmod(clock, 86400) / 3600), int(fmod(clock, 3600) / 60)]
	var metadata = sm.get_slot_metadata(sm.current_slot_id)
	var timestamp = int(metadata.get("timestamp", 0))
	if timestamp <= 0:
		_last_save_label.text = "В этом слоте ещё нет сохранения"
	else:
		var minutes = maxi(0, int((Time.get_unix_time_from_system() - timestamp) / 60))
		if minutes == 0: _last_save_label.text = "Последнее сохранение: только что"
		elif minutes < 60: _last_save_label.text = "Последнее сохранение: %d мин назад" % minutes
		else: _last_save_label.text = "Последнее сохранение: " + str(metadata.get("datetime_str", ""))

func resume_game() -> void:
	if not visible or is_instance_valid(_active_subscreen) or UITheme.has_modal_dialog(self): return
	if is_instance_valid(_fade_tween): _fade_tween.kill()
	_root_control.hide()
	visible = false
	get_tree().paused = false
	_restore_hud()
	Input.mouse_mode = _previous_mouse_mode
	var player = _player()
	if player:
		player._is_lmb_held = false
		player._is_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	resumed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or UITheme.has_modal_dialog(self): return
	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START):
		get_viewport().set_input_as_handled()
		if is_instance_valid(_active_subscreen):
			if _active_subscreen.get("_awaiting_action") != null and _active_subscreen._awaiting_action != "":
				_active_subscreen._awaiting_action = ""
				_active_subscreen._update_keybind_button_labels()
			elif _active_subscreen.has_method("_on_back_pressed"): _active_subscreen._on_back_pressed()
		else: resume_game()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5 and not is_instance_valid(_active_subscreen):
		get_viewport().set_input_as_handled()
		_on_quick_save_pressed()

func _on_quick_save_pressed() -> void:
	if is_instance_valid(_active_subscreen) or UITheme.has_modal_dialog(self): return
	var sm = SaveManager.get_instance()
	var slot = sm.current_slot_id if sm.current_slot_id != "" else "slot_1"
	if sm.save_game(slot, "manual"):
		_refresh_info()
		_show_toast("Игра сохранена", false)
	else: _show_toast("Не удалось сохранить игру. Проверьте доступ к папке сохранений и свободное место.", true)

func _open_screen(path: String, focus_button: Button) -> void:
	if is_instance_valid(_active_subscreen) or UITheme.has_modal_dialog(self): return
	var scene = load(path)
	if scene == null:
		_show_toast("Не удалось открыть экран. Попробуйте ещё раз.", true)
		return
	_active_subscreen = scene.instantiate()
	_active_subscreen.process_mode = Node.PROCESS_MODE_ALWAYS
	_active_subscreen.set_meta("minimal_pause_style", true)
	_main_panel.hide()
	_paused_label.hide()
	_toast_label.hide()
	add_child(_active_subscreen)
	Look.apply_screen(_active_subscreen)
	if _active_subscreen.has_method("_select_save_slot") and _active_subscreen._selected_idx >= 0:
		_active_subscreen._select_save_slot(_active_subscreen._selected_idx)
	_active_subscreen.closed.connect(func():
		_active_subscreen = null
		_main_panel.show()
		_layout()
		_suppress_hud()
		focus_button.grab_focus()
	)
	if _active_subscreen.has_signal("loaded"):
		_active_subscreen.loaded.connect(func():
			_active_subscreen = null
			_main_panel.show()
			resume_game()
		)

func _on_load_game_pressed() -> void:
	_open_screen("res://scenes/menu/LoadGameScreen.tscn", _btn_load_game)

func _on_settings_pressed() -> void:
	_open_screen("res://scenes/menu/SettingsScreen.tscn", _btn_settings)

func _on_main_menu_pressed() -> void:
	if UITheme.has_modal_dialog(self) or is_instance_valid(_active_subscreen): return
	var dialog = ConfirmDialog.prompt(self, "Вернуться в главное меню?", "Прогресс после последнего сохранения будет потерян.", "В главное меню", "Остаться", true)
	dialog.confirmed.connect(func():
		get_tree().paused = false
		var error = get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
		if error != OK:
			get_tree().paused = true
			_show_toast("Не удалось открыть главное меню.", true)
	)

func _on_quit_pressed() -> void:
	if UITheme.has_modal_dialog(self) or is_instance_valid(_active_subscreen): return
	var dialog = ConfirmDialog.prompt(self, "Выйти из игры?", "Прогресс после последнего сохранения будет потерян.", "Выйти", "Остаться", true)
	dialog.confirmed.connect(func(): get_tree().quit())

func _show_toast(text: String, is_error: bool) -> void:
	if is_instance_valid(_toast_tween): _toast_tween.kill()
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", Look.DANGER if is_error else Look.TEXT)
	_toast_label.modulate.a = 1.0
	_toast_label.show()
	_footer.hide()
	_toast_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_interval(5.0 if is_error else 2.5)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.2)
	_toast_tween.tween_callback(func():
		_toast_label.hide()
		_footer.show()
	)
