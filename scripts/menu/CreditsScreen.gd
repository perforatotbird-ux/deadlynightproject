extends Control
class_name CreditsScreen

const UITheme = preload("res://scripts/ui/UITheme.gd")

signal closed

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	var scrim = ColorRect.new()
	scrim.anchors_preset = Control.PRESET_FULL_RECT
	scrim.color = Color(0.02, 0.03, 0.03, 0.88)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	
	var center = CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 500)
	panel.add_theme_stylebox_override("panel", UITheme.create_panel_stylebox(UITheme.COLOR_BG_DARK, UITheme.COLOR_BORDER_SUBTLE, 8))
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "ТИТРЫ  ·  О ПРОЕКТЕ DEADLY NIGHT"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	vbox.add_child(title)
	
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var text_lbl = Label.new()
	text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.add_theme_font_size_override("font_size", 13)
	text_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	
	var credits_text = """
DEADLY NIGHT — СИМУЛЯТОР ВЫЖИВАНИЯ В ДИКОЙ ПРИРОДЕ
Версия: v1.2-alpha

Разработка и геймдизайн:
• Архитектура, мир и процедурные системы: Antigravity AI & Deadly Night Core Team
• Игровой движок: Godot Engine v4.7.2.stable.official (Forward Plus)

3D Модели и визуальное окружение:
• Высокодетализированный горный ландшафт 4×4 км (256 чанков с физическими коллизиями)
• 55 430 деревьев 4 европейских пород (Берёза, Ель, Бук, Дуб) с динамическим воксельным разрушением
• Процедурное моделирование ассетов в Blender 5.2.1 LTS: деревья, пни, поленья, шахта, мост, вагонетки

Звуковой ландшафт:
• Sonniss GDC Game Audio Bundle (Royalty-Free без ограничений)
• OpenGameArt CC0 Audio Collection: лесной эмбиент, шаги, удары топора, ветер
• Динамический звуковой движок: реальные сэмплы ударов, шелест крон, пение весенних птиц

Управление и интерфейс:
• Аутентичная система выживания от первого лица с поясом инструментов
• Физика перегруза рюкзака (порог 25 кг) и механика рубки деревьев с динамическим заваливанием
• Модульная система сохранения с атомарной записью и защитой от сбоев

Благодарим вас за погружение в холодный весенний лес Deadly Night!
"""
	text_lbl.text = credits_text.strip_edges()
	scroll.add_child(text_lbl)
	
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	var action_box = HBoxContainer.new()
	action_box.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(action_box)
	
	var btn_close = Button.new()
	btn_close.text = "Назад"
	btn_close.custom_minimum_size = Vector2(130, 38)
	UITheme.style_button(btn_close, true)
	btn_close.pressed.connect(_on_close)
	action_box.add_child(btn_close)
	btn_close.grab_focus()

func _on_close() -> void:
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_close()
