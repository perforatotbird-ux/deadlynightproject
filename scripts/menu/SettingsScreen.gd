extends Control
class_name SettingsScreen

const UITheme = preload("res://scripts/ui/UITheme.gd")
const ConfirmDialog = preload("res://scripts/ui/ConfirmDialog.gd")
const SettingsManager = preload("res://scripts/core/SettingsManager.gd")

signal closed

var _tab_container: TabContainer = null
var _main_panel: PanelContainer = null
var _draft_keybindings: Dictionary = {}
var _rollback_active: bool = false
var _btn_apply: Button = null
var _btn_defaults: Button = null
var _btn_back: Button = null

# Graphics controls
var _opt_window_mode: OptionButton = null
var _opt_resolution: OptionButton = null
var _opt_sky:OptionButton
var _opt_rain:OptionButton
var _chk_lightning:CheckBox
var _slider_weather:HSlider
var _slider_thunder:HSlider
var _chk_vsync: CheckBox = null
var _opt_max_fps: OptionButton = null
var _opt_shadows: OptionButton = null
var _opt_view_dist: OptionButton = null

# Audio controls
var _slider_master: HSlider = null
var _slider_music: HSlider = null
var _slider_sfx: HSlider = null
var _slider_amb: HSlider = null
var _lbl_master: Label = null
var _lbl_music: Label = null
var _lbl_sfx: Label = null
var _lbl_amb: Label = null

# Controls settings
var _slider_sens: HSlider = null
var _lbl_sens: Label = null
var _chk_invert_y: CheckBox = null
var _slider_fov: HSlider = null
var _lbl_fov: Label = null
var _chk_bobbing: CheckBox = null
var _keybind_buttons: Dictionary = {}
var _awaiting_action: String = ""

# Gameplay settings
var _chk_hud: CheckBox = null
var _opt_autosave: OptionButton = null

# Resolution rollback state
var _prev_resolution: Vector2i
var _prev_mode: int
var _rollback_timer: Timer = null
var _rollback_seconds_left: int = 10
var _rollback_dialog: ConfirmDialog = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_refresh_focus.call_deferred()
	_load_current_values()
	get_viewport().size_changed.connect(_resize_panel)
	_resize_panel()
	_btn_back.grab_focus()

func _refresh_focus() -> void:
	UITheme.trap_focus(self)

func _build_ui() -> void:
	var scrim = ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.02, 0.03, 0.03, 0.88)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	_main_panel = PanelContainer.new()
	_main_panel.name = "SettingsPanel"
	_main_panel.add_theme_stylebox_override("panel", UITheme.create_panel_stylebox(UITheme.COLOR_BG_DARK, UITheme.COLOR_BORDER_SUBTLE, 8))
	center.add_child(_main_panel)
	
	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	_main_panel.add_child(root_vbox)
	
	# Header
	var top_box = HBoxContainer.new()
	root_vbox.add_child(top_box)
	
	var title = Label.new()
	title.text = "НАСТРОЙКИ"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	top_box.add_child(title)
	
	var sep1 = HSeparator.new()
	root_vbox.add_child(sep1)
	
	# Tabs
	_tab_container = TabContainer.new()
	_tab_container.name = "SettingsTabs"
	_tab_container.tab_changed.connect(func(_index): _refresh_focus.call_deferred())
	_tab_container.clip_contents = true
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_theme_font_size_override("font_size", 14)
	root_vbox.add_child(_tab_container)
	
	_build_graphics_tab()
	_build_audio_tab()
	_build_controls_tab()
	_build_gameplay_tab()
	
	var sep2 = HSeparator.new()
	root_vbox.add_child(sep2)
	
	# Bottom Action Bar
	var action_box = HBoxContainer.new()
	action_box.alignment = BoxContainer.ALIGNMENT_END
	action_box.add_theme_constant_override("separation", 14)
	root_vbox.add_child(action_box)
	
	_btn_defaults = Button.new()
	_btn_defaults.text = "По умолчанию"
	_btn_defaults.custom_minimum_size = Vector2(130, 38)
	UITheme.style_button(_btn_defaults)
	_btn_defaults.pressed.connect(_on_defaults_pressed)
	action_box.add_child(_btn_defaults)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_box.add_child(spacer)
	
	_btn_back = Button.new()
	_btn_back.text = "Назад"
	_btn_back.custom_minimum_size = Vector2(110, 38)
	UITheme.style_button(_btn_back)
	_btn_back.pressed.connect(_on_back_pressed)
	action_box.add_child(_btn_back)
	
	_btn_apply = Button.new()
	_btn_apply.text = "Применить"
	_btn_apply.custom_minimum_size = Vector2(130, 38)
	UITheme.style_button(_btn_apply, true)
	_btn_apply.pressed.connect(_on_apply_pressed)
	action_box.add_child(_btn_apply)

func _resize_panel() -> void:
	if _main_panel:
		var available = get_viewport_rect().size - Vector2(48, 48)
		_main_panel.custom_minimum_size = Vector2(minf(860, available.x), minf(600, available.y))

func _create_tab(title: String) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_tab_container.add_child(scroll)
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	return content

func _build_graphics_tab() -> void:
	var vbox = _create_tab("Графика")
	
	# Window Mode
	_opt_window_mode = _create_option_row(vbox, "Режим экрана:", SettingsManager.WINDOW_MODES)
	
	# Resolution
	var res_strings: Array[String] = []
	for r in SettingsManager.RESOLUTION_OPTIONS:
		res_strings.append("%d × %d" % [r.x, r.y])
	_opt_resolution = _create_option_row(vbox, "Разрешение экрана:", res_strings)
	
	# VSync
	_chk_vsync = _create_checkbox_row(vbox, "Вертикальная синхронизация (VSync)")
	
	# FPS limit
	var fps_strings = ["30 кадр/с", "60 кадр/с", "120 кадр/с", "144 кадр/с", "Без ограничений"]
	_opt_max_fps = _create_option_row(vbox, "Ограничение частоты кадров:", fps_strings)
	
	# Shadow Quality
	_opt_shadows = _create_option_row(vbox, "Качество теней:", ["Низкое", "Среднее", "Высокое"])
	
	# View Distance
	_opt_view_dist = _create_option_row(vbox, "Дальность прорисовки мира:", ["Близкая (1.5 км)", "Средняя (2.5 км)", "Дальняя (4.0 км)"])

	_opt_sky = _create_option_row(vbox, "Качество неба:", ["Низкое", "Среднее", "Высокое"])
	_opt_rain = _create_option_row(vbox, "Плотность дождя:", ["Низкая", "Средняя", "Высокая"])
	_chk_lightning = _create_checkbox_row(vbox, "Уменьшенные вспышки грозы")

func _build_audio_tab() -> void:
	var vbox = _create_tab("Звук")
	
	var weather_row = _create_slider_row(vbox, "Погодный фон:")
	_slider_weather = weather_row["slider"]
	_slider_weather.value_changed.connect(func(v): weather_row["label"].text = "%d%%" % int(v*100))
	var thunder_row = _create_slider_row(vbox, "Гром:")
	_slider_thunder = thunder_row["slider"]
	_slider_thunder.value_changed.connect(func(v): thunder_row["label"].text = "%d%%" % int(v*100))
	var r1 = _create_slider_row(vbox, "Общая громкость (Master):")
	_slider_master = r1["slider"]
	_lbl_master = r1["label"]
	_slider_master.value_changed.connect(func(v):
		_lbl_master.text = "%d%%" % int(v * 100)
		var sm = SettingsManager.get_instance()
		if sm: sm.preview_bus_volume_linear("Master", v)
	)
	
	var r2 = _create_slider_row(vbox, "Громкость музыки (Music):")
	_slider_music = r2["slider"]
	_lbl_music = r2["label"]
	_slider_music.value_changed.connect(func(v):
		_lbl_music.text = "%d%%" % int(v * 100)
		var sm = SettingsManager.get_instance()
		if sm: sm.preview_bus_volume_linear("Music", v)
	)
	
	var r3 = _create_slider_row(vbox, "Звуковые эффекты (SFX):")
	_slider_sfx = r3["slider"]
	_lbl_sfx = r3["label"]
	_slider_sfx.value_changed.connect(func(v):
		_lbl_sfx.text = "%d%%" % int(v * 100)
		var sm = SettingsManager.get_instance()
		if sm: sm.preview_bus_volume_linear("SFX", v)
	)
	
	var r4 = _create_slider_row(vbox, "Окружение леса (Ambience):")
	_slider_amb = r4["slider"]
	_lbl_amb = r4["label"]
	_slider_amb.value_changed.connect(func(v):
		_lbl_amb.text = "%d%%" % int(v * 100)
		var sm = SettingsManager.get_instance()
		if sm: sm.preview_bus_volume_linear("Ambience", v)
	)

func _build_controls_tab() -> void:
	var vbox = _create_tab("Управление")
	
	# Mouse Sensitivity
	var r_sens = _create_slider_row(vbox, "Чувствительность мыши:", 0.0005, 0.0060, 0.0001)
	_slider_sens = r_sens["slider"]
	_lbl_sens = r_sens["label"]
	_slider_sens.value_changed.connect(func(v):
		_lbl_sens.text = "%.4f" % v
	)
	
	_chk_invert_y = _create_checkbox_row(vbox, "Инверсия вертикальной оси мыши (Invert Y)")
	
	# FOV
	var r_fov = _create_slider_row(vbox, "Поле зрения (FOV):", 60.0, 100.0, 1.0)
	_slider_fov = r_fov["slider"]
	_lbl_fov = r_fov["label"]
	_slider_fov.value_changed.connect(func(v):
		_lbl_fov.text = "%d°" % int(v)
	)
	
	_chk_bobbing = _create_checkbox_row(vbox, "Покачивание камеры при ходьбе и дыхании")
	
	# Keybinds Table
	var kb_lbl = Label.new()
	kb_lbl.text = "НАЗНАЧЕНИЕ КЛАВИШ:"
	kb_lbl.add_theme_font_size_override("font_size", 14)
	kb_lbl.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	vbox.add_child(kb_lbl)
	
	var kb_grid = GridContainer.new()
	kb_grid.columns = 1
	kb_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kb_grid.add_theme_constant_override("h_separation", 16)
	kb_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(kb_grid)
	
	var bind_defs = [
		{"action": "move_forward", "name": "Движение вперёд"},
		{"action": "move_backward", "name": "Движение назад"},
		{"action": "move_left", "name": "Шаг влево"},
		{"action": "move_right", "name": "Шаг вправо"},
		{"action": "jump", "name": "Прыжок"},
		{"action": "sprint", "name": "Бег (Спринт)"},
		{"action": "crouch", "name": "Присед"},
		{"action": "interact", "name": "Действие / Подобрать"},
		{"action": "inventory", "name": "Открыть рюкзак"},
		{"action": "check_watch", "name": "Посмотреть часы"},
		{"action": "world_map", "name": "Карта местности"},
		{"action": "hotbar_1", "name": "Топор"},
		{"action": "hotbar_2", "name": "Фонарь"},
		{"action": "hotbar_3", "name": "Компас"},
		{"action": "hotbar_4", "name": "Спички"},
		{"action": "hotbar_5", "name": "Нож"},
		{"action": "hotbar_6", "name": "Быстрый предмет 6"},
		{"action": "hotbar_7", "name": "Быстрый предмет 7"},
		{"action": "hotbar_8", "name": "Быстрый предмет 8"},
		{"action": "toggle_camera", "name": "Камера отладки"}
	]
	
	for bd in bind_defs:
		var act = bd["action"]
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, 38)
		kb_grid.add_child(row)
		
		var l = Label.new()
		l.text = bd["name"]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
		row.add_child(l)
		
		var btn = Button.new()
		btn.text = "KEY"
		btn.custom_minimum_size = Vector2(120, 30)
		UITheme.style_button(btn)
		btn.pressed.connect(func(): _start_rebinding(act, btn))
		row.add_child(btn)
		_keybind_buttons[act] = btn

func _build_gameplay_tab() -> void:
	var vbox = _create_tab("Игра")
	
	_chk_hud = _create_checkbox_row(vbox, "Отображать элементы интерфейса выживания (HUD)")
	
	var auto_strings = ["Каждые 3 мин", "Каждые 5 мин", "Каждые 10 мин", "Каждые 15 мин", "Отключено"]
	_opt_autosave = _create_option_row(vbox, "Интервал автоматического сохранения:", auto_strings)

func _create_option_row(parent: Control, label_text: String, options: Array) -> OptionButton:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 34)
	parent.add_child(hbox)
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(220, 30)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	hbox.add_child(lbl)
	
	var opt = OptionButton.new()
	opt.custom_minimum_size = Vector2(240, 34)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(options.size()):
		opt.add_item(options[i], i)
	hbox.add_child(opt)
	return opt

func _create_checkbox_row(parent: Control, label_text: String) -> CheckBox:
	var cb = CheckBox.new()
	cb.text = label_text
	cb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cb.tooltip_text = label_text
	cb.custom_minimum_size = Vector2(0, 34)
	cb.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	parent.add_child(cb)
	return cb

func _create_slider_row(parent: Control, label_text: String, min_v: float = 0.0, max_v: float = 1.0, step: float = 0.01) -> Dictionary:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 34)
	parent.add_child(hbox)
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(220, 30)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	hbox.add_child(lbl)
	
	var slider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.custom_minimum_size = Vector2(180, 30)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)
	
	var val_lbl = Label.new()
	val_lbl.text = "100%"
	val_lbl.custom_minimum_size = Vector2(60, 30)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	hbox.add_child(val_lbl)
	
	return {"slider": slider, "label": val_lbl}

func _load_current_values() -> void:
	var sm = SettingsManager.get_instance()
	if sm == null:
		return
		
	# Graphics
	_opt_window_mode.selected = sm.get_setting("graphics", "window_mode", 0)
	var rx = sm.get_setting("graphics", "resolution_x", 1280)
	var ry = sm.get_setting("graphics", "resolution_y", 720)
	var res_idx = 0
	for i in range(SettingsManager.RESOLUTION_OPTIONS.size()):
		var r = SettingsManager.RESOLUTION_OPTIONS[i]
		if r.x == rx and r.y == ry:
			res_idx = i
			break
	_opt_resolution.selected = res_idx
	_chk_vsync.button_pressed = (sm.get_setting("graphics", "vsync", 1) == 1)
	
	var max_fps = sm.get_setting("graphics", "max_fps", 60)
	var fps_idx = SettingsManager.FPS_LIMIT_OPTIONS.find(max_fps)
	_opt_max_fps.selected = fps_idx if fps_idx >= 0 else 1
	_opt_shadows.selected = sm.get_setting("graphics", "shadow_quality", 2)
	_opt_view_dist.selected = sm.get_setting("graphics", "view_distance", 2)
	_opt_sky.selected = sm.get_setting("graphics", "sky_quality", 1)
	_opt_rain.selected = sm.get_setting("graphics", "rain_quality", 1)
	_chk_lightning.button_pressed = sm.get_setting("graphics", "reduced_lightning", false)
	_slider_weather.value = sm.get_setting("audio", "weather_volume", 0.85)
	_slider_thunder.value = sm.get_setting("audio", "thunder_volume", 0.8)
	
	# Audio
	var mv = sm.get_bus_volume_linear("Master")
	_slider_master.set_value_no_signal(mv)
	_lbl_master.text = "%d%%" % int(mv * 100)
	
	var mu = sm.get_bus_volume_linear("Music")
	_slider_music.set_value_no_signal(mu)
	_lbl_music.text = "%d%%" % int(mu * 100)
	
	var sf = sm.get_bus_volume_linear("SFX")
	_slider_sfx.set_value_no_signal(sf)
	_lbl_sfx.text = "%d%%" % int(sf * 100)
	
	var am = sm.get_bus_volume_linear("Ambience")
	_slider_amb.set_value_no_signal(am)
	_lbl_amb.text = "%d%%" % int(am * 100)
	
	# Controls
	var sens = sm.get_setting("controls", "mouse_sensitivity", 0.0022)
	_slider_sens.value = sens
	_lbl_sens.text = "%.4f" % sens
	_chk_invert_y.button_pressed = sm.get_setting("controls", "invert_y", false)
	var fov = sm.get_setting("controls", "fov", 75.0)
	_slider_fov.value = fov
	_lbl_fov.text = "%d°" % int(fov)
	_chk_bobbing.button_pressed = sm.get_setting("controls", "camera_bobbing", true)
	
	_draft_keybindings = sm.get_setting("controls", "keybindings", {}).duplicate(true)
	_update_keybind_button_labels()
	
	# Gameplay
	_chk_hud.button_pressed = sm.get_setting("gameplay", "hud_visible", true)
	var auto_m = sm.get_setting("gameplay", "autosave_interval_min", 5)
	match auto_m:
		3: _opt_autosave.selected = 0
		5: _opt_autosave.selected = 1
		10: _opt_autosave.selected = 2
		15: _opt_autosave.selected = 3
		_: _opt_autosave.selected = 4

func _update_keybind_button_labels() -> void:
	var sm = SettingsManager.get_instance()
	if sm == null: return
	var binds = _draft_keybindings
	for act in _keybind_buttons.keys():
		var btn = _keybind_buttons[act]
		var kc = binds.get(act, KEY_NONE)
		btn.text = OS.get_keycode_string(kc) if kc != KEY_NONE else "Не задано"

func _start_rebinding(action: String, btn: Button) -> void:
	_update_keybind_button_labels()
	_awaiting_action = action
	btn.text = "[Нажмите...]"
	btn.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)

func _input(event: InputEvent) -> void:
	if UITheme.has_modal_dialog(self):
		return
	if _awaiting_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			if event.keycode == KEY_ESCAPE:
				_awaiting_action = ""
				_update_keybind_button_labels()
				return
			var key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			# F5 remains the global quick-save shortcut; do not silently create conflicts.
			if key == KEY_F5:
				_keybind_buttons[_awaiting_action].text = "F5 зарезервирована"
				return
			for action in _draft_keybindings:
				if action != _awaiting_action and _draft_keybindings[action] == key:
					_keybind_buttons[_awaiting_action].text = "Клавиша занята"
					return
			_draft_keybindings[_awaiting_action] = key
			_awaiting_action = ""
			_update_keybind_button_labels()
			return
		elif event is InputEventMouseButton and event.pressed:
			_awaiting_action = ""
			_update_keybind_button_labels()
			return
			
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_back_pressed()

func _on_apply_pressed() -> void:
	var sm = SettingsManager.get_instance()
	if sm == null:
		return
		
	# Check if resolution or window mode changed
	var old_mode = sm.get_setting("graphics", "window_mode", 0)
	var old_rx = sm.get_setting("graphics", "resolution_x", 1280)
	var old_ry = sm.get_setting("graphics", "resolution_y", 720)
	
	var new_mode = _opt_window_mode.selected
	var new_res = SettingsManager.RESOLUTION_OPTIONS[_opt_resolution.selected]
	
	var mode_changed = (new_mode != old_mode or new_res.x != old_rx or new_res.y != old_ry)
	
	sm.set_setting("controls", "keybindings", _draft_keybindings.duplicate(true))
	for entry in [["Master", _slider_master], ["Music", _slider_music], ["SFX", _slider_sfx], ["Ambience", _slider_amb]]:
		sm.set_bus_volume_linear(entry[0], entry[1].value)

	# Save updated values into sm
	sm.set_setting("graphics", "window_mode", new_mode)
	sm.set_setting("graphics", "resolution_x", new_res.x)
	sm.set_setting("graphics", "resolution_y", new_res.y)
	sm.set_setting("graphics", "vsync", 1 if _chk_vsync.button_pressed else 0)
	sm.set_setting("graphics", "max_fps", SettingsManager.FPS_LIMIT_OPTIONS[_opt_max_fps.selected])
	sm.set_setting("graphics", "shadow_quality", _opt_shadows.selected)
	sm.set_setting("graphics", "view_distance", _opt_view_dist.selected)
	sm.set_setting("graphics", "sky_quality", _opt_sky.selected)
	sm.set_setting("graphics", "rain_quality", _opt_rain.selected)
	sm.set_setting("graphics", "reduced_lightning", _chk_lightning.button_pressed)
	sm.set_setting("audio", "weather_volume", _slider_weather.value)
	sm.set_setting("audio", "thunder_volume", _slider_thunder.value)
	
	sm.set_setting("controls", "mouse_sensitivity", _slider_sens.value)
	sm.set_setting("controls", "invert_y", _chk_invert_y.button_pressed)
	sm.set_setting("controls", "fov", _slider_fov.value)
	sm.set_setting("controls", "camera_bobbing", _chk_bobbing.button_pressed)
	
	sm.set_setting("gameplay", "hud_visible", _chk_hud.button_pressed)
	var auto_intervals = [3, 5, 10, 15, 0]
	sm.set_setting("gameplay", "autosave_interval_min", auto_intervals[_opt_autosave.selected])
	
	sm.apply_all_settings()
	# Persist a display change only after confirmation, not during the unsafe trial.
	if mode_changed and DisplayServer.get_name() != "headless":
		_start_resolution_confirmation(old_mode, Vector2i(old_rx, old_ry))
	else:
		sm.save_to_disk()

func _start_resolution_confirmation(old_mode: int, old_res: Vector2i) -> void:
	if _rollback_active:
		return
	_rollback_active = true
	_prev_mode = old_mode
	_prev_resolution = old_res
	_rollback_seconds_left = 10
	
	var msg = "Применить новые параметры экрана?\nВозврат к предыдущим через %d сек..." % _rollback_seconds_left
	_rollback_dialog = ConfirmDialog.prompt(self, "Подтверждение параметров экрана", msg, "Сохранить", "Вернуть назад")
	
	_rollback_timer = Timer.new()
	_rollback_timer.wait_time = 1.0
	_rollback_timer.autostart = true
	add_child(_rollback_timer)
	
	_rollback_timer.timeout.connect(func():
		_rollback_seconds_left -= 1
		if is_instance_valid(_rollback_dialog):
			_rollback_dialog.set_message("Применить новые параметры экрана?\nВозврат к предыдущим через %d сек..." % _rollback_seconds_left)
		if _rollback_seconds_left <= 0:
			_revert_resolution()
	)
	
	_rollback_dialog.confirmed.connect(func():
		_clear_resolution_confirmation()
		var sm = SettingsManager.get_instance()
		if sm: sm.save_to_disk()
	)
	_rollback_dialog.cancelled.connect(func():
		_revert_resolution()
	)

func _clear_resolution_confirmation() -> void:
	_rollback_active = false
	if is_instance_valid(_rollback_timer):
		_rollback_timer.stop()
		_rollback_timer.queue_free()
	if is_instance_valid(_rollback_dialog):
		_rollback_dialog.queue_free()

func _revert_resolution(refresh_ui: bool = true) -> void:
	if not _rollback_active:
		return
	_clear_resolution_confirmation()
	var sm = SettingsManager.get_instance()
	if sm:
		sm.set_setting("graphics", "window_mode", _prev_mode)
		sm.set_setting("graphics", "resolution_x", _prev_resolution.x)
		sm.set_setting("graphics", "resolution_y", _prev_resolution.y)
		sm.apply_graphics_settings()
		sm.save_to_disk()
		if refresh_ui:
			_load_current_values()

func _on_defaults_pressed() -> void:
	var dlg = ConfirmDialog.prompt(self, "Сброс настроек", "Сбросить все параметры к заводским значениям по умолчанию?", "Сбросить", "Отмена", true)
	dlg.confirmed.connect(func():
		var sm = SettingsManager.get_instance()
		if sm:
			var old_mode: int = sm.get_setting("graphics", "window_mode", 0)
			var old_res = Vector2i(sm.get_setting("graphics", "resolution_x", 1280), sm.get_setting("graphics", "resolution_y", 720))
			sm.reset_to_defaults(false)
			_load_current_values()
			var display_changed = old_mode != 0 or old_res != Vector2i(1280, 720)
			if display_changed and DisplayServer.get_name() != "headless":
				_start_resolution_confirmation(old_mode, old_res)
			else:
				sm.save_to_disk()
	)

func _exit_tree() -> void:
	if _rollback_active:
		_revert_resolution(false)
	var sm = SettingsManager.get_instance()
	if sm: sm.apply_audio_settings()

func _on_back_pressed() -> void:
	if _rollback_active:
		_revert_resolution()
	_awaiting_action = ""
	var sm = SettingsManager.get_instance()
	if sm: sm.apply_audio_settings()
	closed.emit()
	queue_free()
