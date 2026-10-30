extends CanvasLayer
class_name PauseMenu

const UITheme = preload("res://scripts/ui/UITheme.gd")
const ConfirmDialog = preload("res://scripts/ui/ConfirmDialog.gd")
const SaveManager = preload("res://scripts/core/SaveManager.gd")

signal resumed

var _root_center: CenterContainer = null
var _main_panel: PanelContainer = null
var _btn_resume: Button = null
var _btn_quick_save: Button = null
var _btn_load_game: Button = null
var _btn_settings: Button = null
var _btn_main_menu: Button = null
var _btn_quit: Button = null
var _slot_info_label: Label = null
var _toast_label: Label = null
var _toast_timer: SceneTreeTimer = null
var _active_subscreen: Control = null
var _root_control: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_ui()
	visible = false
	if _root_control:
		_root_control.visible = false

func _build_ui() -> void:
	_root_control = Control.new()
	_root_control.name = "RootPauseControl"
	_root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.visible = false
	add_child(_root_control)

	# Scrim overlay
	var scrim = ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.02, 0.03, 0.04, 0.78)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_control.add_child(scrim)
	
	_root_center = CenterContainer.new()
	_root_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_control.add_child(_root_center)
	
	_main_panel = PanelContainer.new()
	_main_panel.custom_minimum_size = Vector2(380, 500)
	_main_panel.add_theme_stylebox_override("panel", UITheme.create_panel_stylebox(UITheme.COLOR_BG_DARK, UITheme.COLOR_BORDER_SUBTLE, 8))
	_root_center.add_child(_main_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_main_panel.add_child(vbox)
	
	# Header
	var title = Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "DEADLY NIGHT · ВЕСЕННИЙ ЛЕС"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	vbox.add_child(subtitle)
	
	_slot_info_label = Label.new()
	_slot_info_label.text = "Слот: слот 1"
	_slot_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_info_label.add_theme_font_size_override("font_size", 11)
	_slot_info_label.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	vbox.add_child(_slot_info_label)
	
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 14)
	vbox.add_child(sep)
	
	# Nav Buttons
	_btn_resume = Button.new()
	_btn_resume.text = "  ▶  ПРОДОЛЖИТЬ  [ESC]"
	vbox.add_child(_btn_resume)
	
	_btn_quick_save = Button.new()
	_btn_quick_save.text = "  💾  БЫСТРОЕ СОХРАНЕНИЕ  [F5]"
	vbox.add_child(_btn_quick_save)
	
	_btn_load_game = Button.new()
	_btn_load_game.text = "  📥  ЗАГРУЗИТЬ СОХРАНЕНИЕ"
	vbox.add_child(_btn_load_game)
	
	_btn_settings = Button.new()
	_btn_settings.text = "  ⚙  НАСТРОЙКИ"
	vbox.add_child(_btn_settings)
	
	_btn_main_menu = Button.new()
	_btn_main_menu.text = "  🏠  ГЛАВНОЕ МЕНЮ"
	vbox.add_child(_btn_main_menu)
	
	_btn_quit = Button.new()
	_btn_quit.text = "  ✖  ВЫХОД ИЗ ИГРЫ"
	vbox.add_child(_btn_quit)
	
	var buttons = [_btn_resume, _btn_quick_save, _btn_load_game, _btn_settings, _btn_main_menu, _btn_quit]
	for b in buttons:
		UITheme.style_button(b)
		b.custom_minimum_size = Vector2(320, 42)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
	_btn_resume.pressed.connect(resume_game)
	_btn_quick_save.pressed.connect(_on_quick_save_pressed)
	_btn_load_game.pressed.connect(_on_load_game_pressed)
	_btn_settings.pressed.connect(_on_settings_pressed)
	_btn_main_menu.pressed.connect(_on_main_menu_pressed)
	_btn_quit.pressed.connect(_on_quit_pressed)
	
	# Toast notification label
	var toast_spacer = Control.new()
	toast_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(toast_spacer)
	
	_toast_label = Label.new()
	_toast_label.text = ""
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 12)
	_toast_label.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GREEN)
	_toast_label.visible = false
	vbox.add_child(_toast_label)

func open_pause() -> void:
	visible = true
	if _root_control:
		_root_control.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Update slot info
	var sm = SaveManager.get_instance()
	if sm:
		var cur_slot = sm.current_slot_id if sm.current_slot_id != "" else "slot_1"
		var meta = sm.get_slot_metadata(cur_slot)
		var pt_name = meta.get("playthrough_name", sm.current_playthrough_name)
		var diff = meta.get("difficulty", sm.current_difficulty)
		_slot_info_label.text = "Прохождение: %s · Слот: %s · Режим: %s" % [pt_name, cur_slot, diff.capitalize()]
	else:
		_slot_info_label.text = "Одиночное выживание"
		
	_btn_resume.grab_focus()

func resume_game() -> void:
	if _active_subscreen != null:
		return
	if _root_control:
		_root_control.visible = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resumed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or UITheme.has_modal_dialog(self) or is_instance_valid(_active_subscreen):
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _active_subscreen != null:
				return # let subscreen handle escape
			resume_game()
		elif event.keycode == KEY_F5:
			get_viewport().set_input_as_handled()
			_on_quick_save_pressed()

func _on_quick_save_pressed() -> void:
	var sm = SaveManager.get_instance()
	if sm == null:
		_show_toast("Ошибка: Менеджер сохранений недоступен", true)
		return
		
	var target_slot = sm.current_slot_id if sm.current_slot_id != "" else "slot_1"
	var success = sm.save_game(target_slot, "manual")
	if success:
		_show_toast("✓ Игра успешно сохранена в [%s]" % target_slot, false)
	else:
		_show_toast("✗ Ошибка при сохранении игры", true)

func _on_load_game_pressed() -> void:
	if _active_subscreen != null:
		return
	var load_scene = load("res://scenes/menu/LoadGameScreen.tscn")
	if load_scene:
		_active_subscreen = load_scene.instantiate()
		_active_subscreen.process_mode = Node.PROCESS_MODE_ALWAYS
		_main_panel.hide()
		add_child(_active_subscreen)
		_active_subscreen.loaded.connect(func():
			_active_subscreen = null
			_main_panel.show()
			resume_game()
		)
		_active_subscreen.closed.connect(func():
			_active_subscreen = null
			_main_panel.show()
			_btn_load_game.grab_focus()
		)

func _on_settings_pressed() -> void:
	if _active_subscreen != null:
		return
	var settings_scene = load("res://scenes/menu/SettingsScreen.tscn")
	if settings_scene:
		_active_subscreen = settings_scene.instantiate()
		_active_subscreen.process_mode = Node.PROCESS_MODE_ALWAYS
		_main_panel.hide()
		add_child(_active_subscreen)
		_active_subscreen.closed.connect(func():
			_active_subscreen = null
			_main_panel.show()
			_btn_settings.grab_focus()
		)

func _on_main_menu_pressed() -> void:
	var dlg = ConfirmDialog.prompt(
		self,
		"Главное меню",
		"Вы действительно хотите выйти в главное меню?\nУбедитесь, что вы сохранили текущий прогресс.",
		"В меню",
		"Отмена",
		true
	)
	dlg.confirmed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
	)

func _on_quit_pressed() -> void:
	var dlg = ConfirmDialog.prompt(
		self,
		"Выход из игры",
		"Выйти из игры на рабочий стол?\nНесохраненный прогресс будет потерян.",
		"Выйти",
		"Отмена",
		true
	)
	dlg.confirmed.connect(func():
		get_tree().quit()
	)

func _show_toast(text: String, is_error: bool) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", UITheme.COLOR_DANGER if is_error else UITheme.COLOR_ACCENT_GREEN)
	_toast_label.visible = true
	_toast_label.modulate.a = 1.0
	
	var tw = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(2.2)
	tw.tween_property(_toast_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): _toast_label.visible = false)
