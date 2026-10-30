extends RefCounted
class_name UITheme

# UITheme: Authentic survival aesthetic for Deadly Night (Graphite, conifer green, frosted glass & gold accent)

const COLOR_BG_DARK = Color(0.06, 0.08, 0.07, 0.94)
const COLOR_BG_PANEL = Color(0.10, 0.13, 0.12, 0.90)
const COLOR_BORDER_SUBTLE = Color(0.28, 0.35, 0.32, 0.65)
const COLOR_BORDER_HOVER = Color(0.70, 0.80, 0.75, 0.90)
const COLOR_BORDER_ACTIVE = Color(0.95, 0.76, 0.32, 0.98) # Survival Gold
const COLOR_TEXT_PRIMARY = Color(0.92, 0.95, 0.93)
const COLOR_TEXT_MUTED = Color(0.60, 0.66, 0.64)
const COLOR_ACCENT_GOLD = Color(0.95, 0.76, 0.32)
const COLOR_ACCENT_GREEN = Color(0.35, 0.85, 0.45)
const COLOR_DANGER = Color(0.85, 0.32, 0.28)

static func create_panel_stylebox(bg: Color = COLOR_BG_PANEL, border: Color = COLOR_BORDER_SUBTLE, radius: int = 6) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = border
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = 14
	sb.content_margin_top = 12
	sb.content_margin_right = 14
	sb.content_margin_bottom = 12
	sb.shadow_size = 12
	sb.shadow_color = Color(0, 0, 0, 0.65)
	return sb

static func create_button_stylebox(state: String) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 18
	sb.content_margin_top = 10
	sb.content_margin_right = 18
	sb.content_margin_bottom = 10
	
	match state:
		"normal":
			sb.bg_color = Color(0.11, 0.14, 0.13, 0.80)
			sb.border_width_left = 2
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.border_color = Color(0.24, 0.30, 0.28, 0.70)
		"hover":
			sb.bg_color = Color(0.16, 0.22, 0.19, 0.95)
			sb.border_width_left = 3
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.border_color = COLOR_ACCENT_GOLD
			sb.shadow_size = 6
			sb.shadow_color = Color(0.95, 0.76, 0.32, 0.25)
		"pressed":
			sb.bg_color = Color(0.20, 0.26, 0.22, 0.98)
			sb.border_width_left = 4
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.border_color = COLOR_ACCENT_GOLD
		"disabled":
			sb.bg_color = Color(0.08, 0.10, 0.09, 0.40)
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.border_color = Color(0.18, 0.22, 0.20, 0.30)
		"focus":
			sb.bg_color = Color(0.14, 0.18, 0.16, 0.85)
			sb.border_width_left = 3
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.border_color = COLOR_ACCENT_GOLD
	return sb

static func style_button(btn: Button, is_accent: bool = false, is_danger: bool = false) -> void:
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.add_theme_stylebox_override("normal", create_button_stylebox("normal"))
	btn.add_theme_stylebox_override("hover", create_button_stylebox("hover"))
	btn.add_theme_stylebox_override("pressed", create_button_stylebox("pressed"))
	btn.add_theme_stylebox_override("disabled", create_button_stylebox("disabled"))
	btn.add_theme_stylebox_override("focus", create_button_stylebox("focus"))
	
	if is_accent:
		btn.add_theme_color_override("font_color", COLOR_ACCENT_GOLD)
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.50))
	elif is_danger:
		btn.add_theme_color_override("font_color", COLOR_DANGER)
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.45, 0.40))
	else:
		btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		btn.add_theme_color_override("font_hover_color", COLOR_ACCENT_GOLD)
		
	btn.add_theme_color_override("font_disabled_color", Color(0.40, 0.45, 0.42))
	btn.add_theme_font_size_override("font_size", 14)
	
	# Connect audio effects
	wire_button_sound(btn)

static func wire_button_sound(btn: Button) -> void:
	btn.mouse_entered.connect(func(): play_ui_sound("res://assets/sounds/level_01/ui/ui_hover.wav"))
	btn.pressed.connect(func(): play_ui_sound("res://assets/sounds/level_01/ui/ui_click.wav"))

static func play_ui_sound(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream == null:
		return
		
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var p = AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.stream = stream
		p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		tree.root.add_child(p)
		p.play()
		p.finished.connect(p.queue_free)


static func has_modal_dialog(owner: Node) -> bool:
	if not owner.is_inside_tree():
		return false
	for dialog in owner.get_tree().get_nodes_in_group("menu_confirmation"):
		if is_instance_valid(dialog) and not dialog.is_queued_for_deletion() and owner.is_ancestor_of(dialog):
			return true
	return false


static func trap_focus(owner: Control) -> void:
	# Keep keyboard/gamepad focus in the visible overlay, not in the menu behind it.
	var controls: Array[Control] = []
	_collect_focusable(owner, controls)
	for index in range(controls.size()):
		var control = controls[index]
		var previous = controls[(index - 1 + controls.size()) % controls.size()]
		var following = controls[(index + 1) % controls.size()]
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(following)
		control.focus_neighbor_top = control.focus_previous
		control.focus_neighbor_bottom = control.focus_next

static func _collect_focusable(node: Node, result: Array[Control]) -> void:
	if node is Window:
		return # Popup windows manage their own focus.
	if node is Control:
		if not node.is_visible_in_tree():
			return
		if node.focus_mode != Control.FOCUS_NONE and not (node is BaseButton and node.disabled):
			result.append(node)
	for child in node.get_children(true):
		_collect_focusable(child, result)
