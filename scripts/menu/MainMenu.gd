extends Control
class_name MainMenu

const UITheme = preload("res://scripts/ui/UITheme.gd")
const ConfirmDialog = preload("res://scripts/ui/ConfirmDialog.gd")
const SaveManager = preload("res://scripts/core/SaveManager.gd")

@onready var _nav_vbox: VBoxContainer = $CanvasLayer/RootMargin/MainHBox/NavVBox
@onready var _btn_continue: Button = $CanvasLayer/RootMargin/MainHBox/NavVBox/BtnContinue
@onready var _btn_new_game: Button = $CanvasLayer/RootMargin/MainHBox/NavVBox/BtnNewGame
@onready var _btn_load_game: Button = $CanvasLayer/RootMargin/MainHBox/NavVBox/BtnLoadGame
@onready var _btn_settings: Button = $CanvasLayer/RootMargin/MainHBox/NavVBox/BtnSettings
@onready var _btn_credits: Button = $CanvasLayer/RootMargin/MainHBox/NavVBox/BtnCredits
@onready var _btn_quit: Button = $CanvasLayer/RootMargin/MainHBox/NavVBox/BtnQuit
@onready var _status_label: Label = $CanvasLayer/RootMargin/BottomBar/StatusLabel
@onready var _fade_rect: ColorRect = $CanvasLayer/FadeRect

var _latest_slot_id: String = ""
var _active_subscreen: Control = null
var _transitioning: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_style_menu_buttons()
	_update_save_states()
	
	# Connect Button Events
	_btn_continue.pressed.connect(_on_continue_pressed)
	_btn_new_game.pressed.connect(_on_new_game_pressed)
	_btn_load_game.pressed.connect(_on_load_game_pressed)
	_btn_settings.pressed.connect(_on_settings_pressed)
	_btn_credits.pressed.connect(_on_credits_pressed)
	_btn_quit.pressed.connect(_on_quit_pressed)
	
	# Smooth fade-in on startup
	_fade_rect.visible = true
	_fade_rect.modulate.a = 1.0
	var tw = create_tween()
	tw.tween_property(_fade_rect, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func(): _fade_rect.visible = false)
	
	# Initial focus for keyboard / gamepad
	if not _btn_continue.disabled:
		_btn_continue.grab_focus()
	else:
		_btn_new_game.grab_focus()

func _style_menu_buttons() -> void:
	var buttons = [
		_btn_continue,
		_btn_new_game,
		_btn_load_game,
		_btn_settings,
		_btn_credits,
		_btn_quit
	]
	
	for btn in buttons:
		if btn:
			UITheme.style_button(btn)
			btn.custom_minimum_size = Vector2(260, 44)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			
			# Add subtle smooth hover indentation shift
			btn.mouse_entered.connect(func():
				var t = create_tween()
				t.tween_property(btn, "position:x", 8.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			)
			btn.mouse_exited.connect(func():
				var t = create_tween()
				t.tween_property(btn, "position:x", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			)

func _update_save_states() -> void:
	var sm = SaveManager.get_instance()
	if sm and sm.has_any_saves():
		_latest_slot_id = sm.get_latest_save_slot_id()
		var meta = sm.get_slot_metadata(_latest_slot_id)
		var pt_name = meta.get("playthrough_name", "Выживание")
		var dt = meta.get("datetime_str", "")
		
		_btn_continue.disabled = false
		_btn_continue.text = "  ▶  ПРОДОЛЖИТЬ"
		_btn_load_game.disabled = false
		
		if _status_label:
			_status_label.text = "Последнее сохранение: %s (%s) · Слот: %s" % [pt_name, dt, _latest_slot_id]
	else:
		_latest_slot_id = ""
		_btn_continue.disabled = true
		_btn_continue.text = "  ▶  ПРОДОЛЖИТЬ (НЕТ СОХРАНЕНИЙ)"
		_btn_load_game.disabled = false
		
		if _status_label:
			_status_label.text = "Сохранений не обнаружено. Создайте новую игру для начала выживания."

func _on_continue_pressed() -> void:
	if _latest_slot_id == "":
		return
	_fade_and_execute(func():
		var sm = SaveManager.get_instance()
		if sm:
			if not sm.load_game(_latest_slot_id):
				_transitioning = false
				_fade_rect.hide()
				_fade_rect.modulate.a = 0.0
				_on_subscreen_closed()
				_status_label.text = "Не удалось загрузить последнее сохранение. Выберите другой слот в меню загрузки."
		else:
			get_tree().change_scene_to_file("res://scenes/viewer/MapViewer.tscn")
	)

func _on_new_game_pressed() -> void:
	if is_instance_valid(_active_subscreen):
		return
	var new_game_scene = load("res://scenes/menu/NewGameScreen.tscn")
	if new_game_scene:
		var screen = new_game_scene.instantiate()
		_open_subscreen(screen)

func _on_load_game_pressed() -> void:
	if is_instance_valid(_active_subscreen):
		return
	var load_scene = load("res://scenes/menu/LoadGameScreen.tscn")
	if load_scene:
		var screen = load_scene.instantiate()
		_open_subscreen(screen)

func _on_settings_pressed() -> void:
	if is_instance_valid(_active_subscreen):
		return
	var settings_scene = load("res://scenes/menu/SettingsScreen.tscn")
	if settings_scene:
		var screen = settings_scene.instantiate()
		_open_subscreen(screen)

func _on_credits_pressed() -> void:
	if is_instance_valid(_active_subscreen):
		return
	var credits_scene = load("res://scenes/menu/CreditsScreen.tscn")
	if credits_scene:
		var screen = credits_scene.instantiate()
		_open_subscreen(screen)

func _open_subscreen(screen: Control) -> void:
	_active_subscreen = screen
	for button in [_btn_continue, _btn_new_game, _btn_load_game, _btn_settings, _btn_credits, _btn_quit]:
		button.disabled = true
	$CanvasLayer.add_child(screen)
	screen.closed.connect(_on_subscreen_closed)

func _on_subscreen_closed() -> void:
	_active_subscreen = null
	for button in [_btn_new_game, _btn_settings, _btn_credits, _btn_quit]:
		button.disabled = false
	_update_save_states()
	if not _btn_continue.disabled:
		_btn_continue.grab_focus()
	else:
		_btn_new_game.grab_focus()

func _on_quit_pressed() -> void:
	var dlg = ConfirmDialog.prompt(self, "Выход из игры", "Вы действительно хотите выйти из Deadly Night?", "Выйти", "Отмена", true)
	dlg.confirmed.connect(func():
		_fade_and_execute(func(): get_tree().quit())
	)

func _fade_and_execute(callback: Callable) -> void:
	if _transitioning:
		return
	_transitioning = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_rect.visible = true
	var tw = create_tween()
	tw.tween_property(_fade_rect, "modulate:a", 1.0, 0.45)
	tw.tween_callback(callback)
