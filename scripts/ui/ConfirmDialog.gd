extends Control
class_name ConfirmDialog

const UITheme = preload("res://scripts/ui/UITheme.gd")

signal confirmed
signal cancelled

var _title_label: Label = null
var _message_label: Label = null
var _btn_confirm: Button = null
var _btn_cancel: Button = null
var _resolved: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("menu_confirmation")
	_build_ui()
	if _minimal_pause_owner():
		preload("res://scripts/ui/PauseTheme.gd").apply_screen(self)
	UITheme.trap_focus(self)

func setup(title: String, message: String, confirm_txt: String = "Подтвердить", cancel_txt: String = "Отмена", is_danger: bool = false) -> void:
	if _title_label:
		_title_label.text = title
	if _message_label:
		_message_label.text = message
	if _btn_confirm:
		_btn_confirm.text = confirm_txt
		if is_danger:
			_btn_confirm.add_theme_color_override("font_color", preload("res://scripts/ui/PauseTheme.gd").DANGER if _minimal_pause_owner() else UITheme.COLOR_DANGER)
	if _btn_cancel:
		_btn_cancel.text = cancel_txt
		_btn_cancel.grab_focus()

func _build_ui() -> void:
	# Dark backdrop scrim
	var scrim = ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.02, 0.03, 0.03, 0.82)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	
	# Centered Dialog Panel
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 200)
	panel.add_theme_stylebox_override("panel", UITheme.create_panel_stylebox(UITheme.COLOR_BG_DARK, UITheme.COLOR_BORDER_SUBTLE, 8))
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)
	
	_title_label = Label.new()
	_title_label.text = "Подтверждение"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", UITheme.COLOR_ACCENT_GOLD)
	vbox.add_child(_title_label)
	
	_message_label = Label.new()
	_message_label.text = "Вы уверены, что хотите выполнить это действие?"
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.custom_minimum_size = Vector2(420, 60)
	_message_label.add_theme_font_size_override("font_size", 14)
	_message_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	vbox.add_child(_message_label)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_theme_constant_override("separation", 14)
	vbox.add_child(hbox)
	
	_btn_cancel = Button.new()
	_btn_cancel.text = "Отмена"
	_btn_cancel.custom_minimum_size = Vector2(110, 38)
	UITheme.style_button(_btn_cancel)
	_btn_cancel.pressed.connect(_on_cancel)
	hbox.add_child(_btn_cancel)
	
	_btn_confirm = Button.new()
	_btn_confirm.text = "Подтвердить"
	_btn_confirm.custom_minimum_size = Vector2(130, 38)
	UITheme.style_button(_btn_confirm, true)
	_btn_confirm.pressed.connect(_on_confirm)
	hbox.add_child(_btn_confirm)
	
	_btn_cancel.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not (event is InputEventKey and event.echo):
			get_viewport().set_input_as_handled()
			_on_cancel()

func _minimal_pause_owner() -> bool:
	var node = get_parent()
	while node != null:
		if node.has_meta("minimal_pause_style"): return true
		node = node.get_parent()
	return false

func set_message(message: String) -> void:
	_message_label.text = message

func _on_confirm() -> void:
	if _resolved: return
	_resolved = true
	confirmed.emit()
	queue_free()

func _on_cancel() -> void:
	if _resolved: return
	_resolved = true
	cancelled.emit()
	queue_free()

static func prompt(parent: Node, title: String, message: String, confirm_txt: String = "Подтвердить", cancel_txt: String = "Отмена", is_danger: bool = false):
	var script = load("res://scripts/ui/ConfirmDialog.gd")
	var dlg = script.new()
	# A dedicated layer keeps confirmations above both main-menu and pause canvases.
	var layer = CanvasLayer.new()
	layer.layer = 200
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)
	var previous_focus = parent.get_viewport().gui_get_focus_owner()
	layer.add_child(dlg)
	dlg.tree_exited.connect(func():
		if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
			previous_focus.grab_focus()
		layer.queue_free()
	)
	dlg.setup(title, message, confirm_txt, cancel_txt, is_danger)
	return dlg
