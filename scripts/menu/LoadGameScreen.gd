extends Control
class_name LoadGameScreen

const UITheme = preload("res://scripts/ui/UITheme.gd")
const ConfirmDialog = preload("res://scripts/ui/ConfirmDialog.gd")
const SaveManager = preload("res://scripts/core/SaveManager.gd")

signal closed

var _list_container: VBoxContainer = null
var _detail_panel: PanelContainer = null
var _detail_title: Label = null
var _detail_type_badge: Label = null
var _detail_info_lbl: Label = null
var _btn_load: Button = null
var _btn_delete: Button = null
var _empty_label: Label = null

var _save_cards: Array[Button] = []
var _save_data_list: Array[Dictionary] = []
var _selected_idx: int = -1

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_refresh_list()

func _build_ui() -> void:
	# Scrim
	var scrim = ColorRect.new()
	scrim.anchors_preset = Control.PRESET_FULL_RECT
	scrim.color = Color(0.02, 0.03, 0.03, 0.88)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	
	var center = CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	add_child(center)
	
	var main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(900, 580)
	main_panel.add_theme_stylebox_override("panel", UITheme.create_panel_stylebox(UITheme.COLOR_BG_DARK, UITheme.COLOR_BORDER_SUBTLE, 8))
	center.add_child(main_panel)
	
	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	main_panel.add_child(root_vbox)
	
	# Header
	var top_box = HBoxContainer.new()
	root_vbox.add_child(top_box)
	
	var title = Label.new()
	title.text = "ЗАГРУЗКА ИГРЫ  ·  СОХРАНЕНИЯ ВЫЖИВАНИЯ"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	top_box.add_child(title)
	
	var sep1 = HSeparator.new()
	root_vbox.add_child(sep1)
	
	# Two-column layout (Left: Slot list, Right: Details)
	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 18)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content_hbox)
	
	# Left: Scrollable Slots List
	var left_box = VBoxContainer.new()
	left_box.custom_minimum_size = Vector2(480, 400)
	left_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(left_box)
	
	var list_scroll = ScrollContainer.new()
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_box.add_child(list_scroll)
	
	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 8)
	list_scroll.add_child(_list_container)
	
	_empty_label = Label.new()
	_empty_label.text = "Нет доступных сохранений.\nНачните 'Новую игру', чтобы отправиться в весенний лес."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.custom_minimum_size = Vector2(460, 200)
	_empty_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	_empty_label.visible = false
	left_box.add_child(_empty_label)
	
	# Right: Detailed Info Panel
	_detail_panel = PanelContainer.new()
	_detail_panel.custom_minimum_size = Vector2(360, 400)
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_theme_stylebox_override("panel", UITheme.create_panel_stylebox(Color(0.08, 0.10, 0.09, 0.75), Color(0.22, 0.28, 0.25, 0.55), 6))
	content_hbox.add_child(_detail_panel)
	
	var detail_vbox = VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 12)
	_detail_panel.add_child(detail_vbox)
	
	var d_header = HBoxContainer.new()
	detail_vbox.add_child(d_header)
	
	_detail_title = Label.new()
	_detail_title.text = "Выберите сохранение"
	_detail_title.add_theme_font_size_override("font_size", 16)
	_detail_title.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_header.add_child(_detail_title)
	
	_detail_type_badge = Label.new()
	_detail_type_badge.text = ""
	_detail_type_badge.add_theme_font_size_override("font_size", 11)
	_detail_type_badge.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	d_header.add_child(_detail_type_badge)
	
	var d_sep = HSeparator.new()
	detail_vbox.add_child(d_sep)
	
	_detail_info_lbl = Label.new()
	_detail_info_lbl.text = "Здесь отображаются подробные сведения о выбранном прогрессе выживания."
	_detail_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_info_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_info_lbl.add_theme_font_size_override("font_size", 13)
	_detail_info_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	detail_vbox.add_child(_detail_info_lbl)
	
	var sep2 = HSeparator.new()
	root_vbox.add_child(sep2)
	
	# Action Buttons
	var action_box = HBoxContainer.new()
	action_box.alignment = BoxContainer.ALIGNMENT_END
	action_box.add_theme_constant_override("separation", 14)
	root_vbox.add_child(action_box)
	
	var btn_refresh = Button.new()
	btn_refresh.text = "Обновить"
	btn_refresh.custom_minimum_size = Vector2(100, 38)
	UITheme.style_button(btn_refresh)
	btn_refresh.pressed.connect(_refresh_list)
	action_box.add_child(btn_refresh)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_box.add_child(spacer)
	
	_btn_delete = Button.new()
	_btn_delete.text = "Удалить"
	_btn_delete.custom_minimum_size = Vector2(110, 38)
	UITheme.style_button(_btn_delete, false, true)
	_btn_delete.disabled = true
	_btn_delete.pressed.connect(_on_delete_pressed)
	action_box.add_child(_btn_delete)
	
	var btn_back = Button.new()
	btn_back.text = "Назад"
	btn_back.custom_minimum_size = Vector2(110, 38)
	UITheme.style_button(btn_back)
	btn_back.pressed.connect(_on_back_pressed)
	action_box.add_child(btn_back)
	
	_btn_load = Button.new()
	_btn_load.text = "Загрузить сохранение"
	_btn_load.custom_minimum_size = Vector2(190, 38)
	UITheme.style_button(_btn_load, true)
	_btn_load.disabled = true
	_btn_load.pressed.connect(_on_load_pressed)
	action_box.add_child(_btn_load)

func _refresh_list() -> void:
	for child in _list_container.get_children():
		child.queue_free()
	_save_cards.clear()
	_save_data_list.clear()
	_selected_idx = -1
	
	var sm = SaveManager.get_instance()
	if sm:
		_save_data_list = sm.list_save_slots()
		
	if _save_data_list.is_empty():
		_empty_label.visible = true
		_btn_load.disabled = true
		_btn_delete.disabled = true
		_detail_title.text = "Сохранений не найдено"
		_detail_type_badge.text = ""
		_detail_info_lbl.text = "Папка сохранений пуста.\nДля начала игры нажмите 'Новая игра' в главном меню."
		return
		
	_empty_label.visible = false
	
	for i in range(_save_data_list.size()):
		var data = _save_data_list[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(460, 68)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_button(btn)
		
		# Inner container for card layout
		var card_vbox = VBoxContainer.new()
		card_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(card_vbox)
		
		# Top row: Playthrough Name & Type Badge
		var row1 = HBoxContainer.new()
		row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(row1)
		
		var name_lbl = Label.new()
		name_lbl.text = data.get("playthrough_name", "Выживание")
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row1.add_child(name_lbl)
		
		var type_str = "РУЧНОЕ" if data.get("save_type") == "manual" else "АВТО"
		var badge = Label.new()
		badge.text = "[%s]" % type_str
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD if type_str == "РУЧНОЕ" else Color(0.4, 0.8, 1.0))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row1.add_child(badge)
		
		# Row 2: Location, Date & Playtime
		var row2 = HBoxContainer.new()
		row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(row2)
		
		var loc_lbl = Label.new()
		loc_lbl.text = "📍 %s" % data.get("location_name", "Лес")
		loc_lbl.add_theme_font_size_override("font_size", 11)
		loc_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
		loc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		loc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row2.add_child(loc_lbl)
		
		var time_lbl = Label.new()
		time_lbl.text = "🕒 %s" % data.get("datetime_str", "")
		time_lbl.add_theme_font_size_override("font_size", 11)
		time_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
		time_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row2.add_child(time_lbl)
		
		var idx = i
		btn.pressed.connect(func(): _select_save_slot(idx))
		
		_list_container.add_child(btn)
		_save_cards.append(btn)
		
	# Select first save by default
	if not _save_cards.is_empty():
		_select_save_slot(0)

func _select_save_slot(idx: int) -> void:
	if idx < 0 or idx >= _save_data_list.size():
		return
	_selected_idx = idx
	
	for i in range(_save_cards.size()):
		var card = _save_cards[i]
		if i == idx:
			card.add_theme_stylebox_override("normal", UITheme.create_button_stylebox("hover"))
		else:
			card.add_theme_stylebox_override("normal", UITheme.create_button_stylebox("normal"))
			
	var data = _save_data_list[idx]
	_btn_load.disabled = false
	_btn_delete.disabled = false
	
	_detail_title.text = data.get("playthrough_name", "Выживание")
	var is_auto = data.get("save_type") == "auto"
	_detail_type_badge.text = "[АВТОСОХРАНЕНИЕ]" if is_auto else "[РУЧНОЙ СЛОТ]"
	_detail_type_badge.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0) if is_auto else UITheme.COLOR_ACCENT_GOLD)
	
	var coords = data.get("coordinates", [0, 0, 0])
	var playtime_sec = data.get("playtime_seconds", 0.0)
	var mins = int(playtime_sec / 60.0)
	var hrs = int(mins / 60.0)
	var playtime_str = "%d ч %d мин" % [hrs, mins % 60] if hrs > 0 else "%d мин" % mins
	
	var diff_map = {
		"explorer": "Исследователь",
		"traveler": "Путешественник",
		"survivor": "Выживший",
		"custom": "Пользовательский"
	}
	var diff_ru = diff_map.get(data.get("difficulty", "traveler"), "Стандарт")
	
	var info_text = ""
	info_text += "• Идентификатор слота: %s\n" % data.get("slot_id", "")
	info_text += "• Сложность выживания: %s\n" % diff_ru
	info_text += "• Время сохранения: %s\n" % data.get("datetime_str", "")
	info_text += "• Общее время игры: %s\n\n" % playtime_str
	info_text += "• Текущая локация: %s\n" % data.get("location_name", "Дикий лес")
	info_text += "• Координаты мира: X: %.0f, Y: %.0f, Z: %.0f\n\n" % [coords[0], coords[1], coords[2]]
	info_text += "• Вес рюкзака: %.1f / 25.0 кг\n" % data.get("backpack_weight", 0.0)
	info_text += "• Предметов в инвентаре: %d шт.\n" % data.get("items_count", 0)
	
	_detail_info_lbl.text = info_text

func _on_load_pressed() -> void:
	if _selected_idx < 0 or _selected_idx >= _save_data_list.size():
		return
	var slot_id = _save_data_list[_selected_idx].get("slot_id", "")
	var sm = SaveManager.get_instance()
	if sm:
		sm.load_game(slot_id)
	queue_free()

func _on_delete_pressed() -> void:
	if _selected_idx < 0 or _selected_idx >= _save_data_list.size():
		return
	var data = _save_data_list[_selected_idx]
	var slot_id = data.get("slot_id", "")
	var pt_name = data.get("playthrough_name", "Выживание")
	
	var msg = "Удалить сохранение \"%s\" (%s)?\nЭто действие необратимо." % [pt_name, slot_id]
	var dlg = ConfirmDialog.prompt(self, "Удаление сохранения", msg, "Удалить", "Отмена", true)
	dlg.confirmed.connect(func():
		var sm = SaveManager.get_instance()
		if sm:
			sm.delete_save(slot_id)
		_refresh_list()
	)

func _on_back_pressed() -> void:
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_back_pressed()
