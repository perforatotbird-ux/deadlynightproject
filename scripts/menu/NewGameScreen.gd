extends Control
class_name NewGameScreen

const UITheme = preload("res://scripts/ui/UITheme.gd")
const ConfirmDialog = preload("res://scripts/ui/ConfirmDialog.gd")
const SaveManager = preload("res://scripts/core/SaveManager.gd")

signal closed

const DIFFICULTIES = [
	{
		"id": "explorer",
		"name": "Исследователь",
		"icon": "difficulty_explorer",
		"desc": "Мягкий климат ранней весны. Дикие звери осторожны, ресурсы встречаются чаще, выносливость расходуется медленнее. Идеально для изучения мира."
	},
	{
		"id": "traveler",
		"name": "Путешественник",
		"icon": "difficulty_traveler",
		"desc": "Сбалансированное выживание. Реалистичные погодные условия, умеренная усталость, необходимость регулярного сбора древесины и поддержания тепла."
	},
	{
		"id": "survivor",
		"name": "Выживший",
		"icon": "difficulty_survivor",
		"desc": "Суровое противостояние дикой природе. Быстрое наступление холода, высокий расход калорий, ценные инструменты и минимальный запас припасов."
	},
	{
		"id": "custom",
		"name": "Пользовательский",
		"icon": "difficulty_custom",
		"desc": "Индивидуальная настройка сложности выживания под ваш персональный стиль игры."
	}
]

var _input_name: LineEdit = null
var _slot_option: OptionButton = null
var _selected_difficulty_idx: int = 1 # Traveler by default
var _diff_buttons: Array[Button] = []
var _diff_desc_label: Label = null
var _btn_start: Button = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_refresh_focus.call_deferred()
	_update_slot_choices()
	_select_difficulty(1)

func _refresh_focus() -> void:
	UITheme.trap_focus(self)

func _build_ui() -> void:
	# Dark Frosted Scrim
	var scrim = ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.02, 0.03, 0.03, 0.85)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 560)
	panel.add_theme_stylebox_override("panel", UITheme.create_panel_stylebox(UITheme.COLOR_BG_DARK, UITheme.COLOR_BORDER_SUBTLE, 8))
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)
	
	# Header
	var title = Label.new()
	title.text = "НОВАЯ ИГРА  ·  НАСТРОЙКА ВЫЖИВАНИЯ"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	vbox.add_child(title)
	
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)
	
	# Playthrough Name Field
	var name_box = HBoxContainer.new()
	name_box.add_theme_constant_override("separation", 12)
	vbox.add_child(name_box)
	
	var name_lbl = Label.new()
	name_lbl.text = "Название прохождения:"
	name_lbl.custom_minimum_size = Vector2(200, 30)
	name_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	name_box.add_child(name_lbl)
	
	_input_name = LineEdit.new()
	_input_name.text = "Весеннее выживание"
	_input_name.custom_minimum_size = Vector2(380, 34)
	_input_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_child(_input_name)
	
	# Slot Selector
	var slot_box = HBoxContainer.new()
	slot_box.add_theme_constant_override("separation", 12)
	vbox.add_child(slot_box)
	
	var slot_lbl = Label.new()
	slot_lbl.text = "Слот сохранения:"
	slot_lbl.custom_minimum_size = Vector2(200, 30)
	slot_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	slot_box.add_child(slot_lbl)
	
	_slot_option = OptionButton.new()
	_slot_option.custom_minimum_size = Vector2(380, 34)
	_slot_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_box.add_child(_slot_option)
	
	# Difficulty Selection Title
	var diff_title = Label.new()
	diff_title.text = "ВЫБЕРИТЕ УРОВЕНЬ СЛОЖНОСТИ:"
	diff_title.add_theme_font_size_override("font_size", 14)
	diff_title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	vbox.add_child(diff_title)
	
	# Difficulty Grid / Row
	var diff_grid = GridContainer.new()
	diff_grid.columns = 2
	diff_grid.add_theme_constant_override("h_separation", 12)
	diff_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(diff_grid)
	
	for i in range(DIFFICULTIES.size()):
		var d = DIFFICULTIES[i]
		var btn = Button.new()
		btn.text = d["name"]
		btn.icon = preload("res://scripts/ui/JournalArt.gd").texture(d["icon"])
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", 28)
		btn.custom_minimum_size = Vector2(335, 42)
		UITheme.style_button(btn)
		var idx = i
		btn.pressed.connect(func(): _select_difficulty(idx))
		diff_grid.add_child(btn)
		_diff_buttons.append(btn)
		
	# Difficulty Description Panel
	var desc_panel = PanelContainer.new()
	desc_panel.custom_minimum_size = Vector2(680, 75)
	desc_panel.add_theme_stylebox_override("panel", UITheme.create_panel_stylebox(Color(0.08, 0.10, 0.09, 0.8), Color(0.20, 0.25, 0.22, 0.5), 4))
	vbox.add_child(desc_panel)
	
	_diff_desc_label = Label.new()
	_diff_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diff_desc_label.add_theme_font_size_override("font_size", 13)
	_diff_desc_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	desc_panel.add_child(_diff_desc_label)
	
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	# Bottom Action Buttons
	var action_box = HBoxContainer.new()
	action_box.alignment = BoxContainer.ALIGNMENT_END
	action_box.add_theme_constant_override("separation", 16)
	vbox.add_child(action_box)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "Отмена"
	btn_cancel.custom_minimum_size = Vector2(130, 42)
	UITheme.style_button(btn_cancel)
	btn_cancel.pressed.connect(_on_cancel)
	action_box.add_child(btn_cancel)
	
	_btn_start = Button.new()
	_btn_start.text = "Начать выживание"
	_btn_start.custom_minimum_size = Vector2(180, 42)
	UITheme.style_button(_btn_start, true)
	_btn_start.pressed.connect(_on_start_pressed)
	action_box.add_child(_btn_start)
	
	_btn_start.grab_focus()

func _update_slot_choices() -> void:
	if _slot_option == null:
		return
	_slot_option.clear()
	
	var sm = SaveManager.get_instance()
	for i in range(1, SaveManager.MAX_MANUAL_SLOTS + 1):
		var s_id = "slot_%d" % i
		var meta = sm.get_slot_metadata(s_id) if sm else {}
		if not meta.is_empty():
			var pt = meta.get("playthrough_name", "Выживание")
			var dt = meta.get("datetime_str", "")
			_slot_option.add_item("Слот %d: [%s · %s]" % [i, pt, dt], i)
		else:
			_slot_option.add_item("Слот %d: [Свободно]" % i, i)
			
	_slot_option.selected = 0

func _select_difficulty(idx: int) -> void:
	if idx < 0 or idx >= DIFFICULTIES.size():
		return
	_selected_difficulty_idx = idx
	for i in range(_diff_buttons.size()):
		var btn = _diff_buttons[i]
		if i == idx:
			btn.add_theme_stylebox_override("normal", UITheme.create_button_stylebox("hover"))
			btn.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
		else:
			btn.add_theme_stylebox_override("normal", UITheme.create_button_stylebox("normal"))
			btn.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
			
	_diff_desc_label.text = DIFFICULTIES[idx]["desc"]

func _on_start_pressed() -> void:
	var slot_num = _slot_option.get_selected_id()
	var slot_id = "slot_%d" % slot_num
	var pt_name = _input_name.text.strip_edges()
	if pt_name == "":
		pt_name = "Выживание #%d" % slot_num
		
	var diff_id = DIFFICULTIES[_selected_difficulty_idx]["id"]
	var sm = SaveManager.get_instance()
	
	# Check if slot is occupied
	var meta = sm.get_slot_metadata(slot_id) if sm else {}
	if not meta.is_empty():
		var existing_name = meta.get("playthrough_name", "Выживание")
		var msg = "В слоте %d уже существует сохранение \"%s\".\nПерезаписать прохождение? Старые данные будут безвозвратно удалены." % [slot_num, existing_name]
		var dlg = ConfirmDialog.prompt(self, "Перезапись слота сохранения", msg, "Перезаписать", "Отмена", true)
		dlg.confirmed.connect(func(): _execute_start_game(slot_id, pt_name, diff_id))
	else:
		_execute_start_game(slot_id, pt_name, diff_id)

func _execute_start_game(slot_id: String, pt_name: String, diff_id: String) -> void:
	var sm = SaveManager.get_instance()
	if sm:
		sm.start_new_game(slot_id, pt_name, diff_id)
	else:
		get_tree().change_scene_to_file("res://scenes/viewer/MapViewer.tscn")
	queue_free()

func _on_cancel() -> void:
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if UITheme.has_modal_dialog(self):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_cancel()
