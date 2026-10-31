extends RefCounted
## Scoped pause styling; does not replace the main menu or the field journal.
const SANS = preload("res://assets/fonts/pause/LiberationSans-Regular.ttf")
const SERIF = preload("res://assets/fonts/pause/LiberationSerif-Regular.ttf")
const TEXT = Color("e9e5db")
const MUTED = Color("b4bcb5")
const ACCENT = Color("c7aa70")
const DANGER = Color("eda397")
const BG = Color("101713")

static func box(state: String = "normal") -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.content_margin_left = 22
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	if state in ["hover", "pressed", "focus"]:
		style.bg_color = Color(0.78, 0.67, 0.44, 0.07 if state != "pressed" else 0.14)
		style.border_width_left = 3
		style.border_color = ACCENT
	return style

static func button(control: Button, primary: bool = false) -> void:
	control.focus_mode = Control.FOCUS_ALL
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.add_theme_font_override("font", SANS)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		control.add_theme_stylebox_override(state, box(state))
	control.add_theme_color_override("font_color", TEXT if primary else MUTED)
	control.add_theme_color_override("font_hover_color", ACCENT)
	control.add_theme_color_override("font_focus_color", ACCENT)
	control.add_theme_color_override("font_pressed_color", TEXT)
	control.add_theme_color_override("font_disabled_color", Color("818b83"))
	control.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	control.add_theme_constant_override("outline_size", 0)

static func label(control: Label, size: int = 16, muted: bool = false) -> void:
	control.add_theme_font_override("font", SANS)
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", MUTED if muted else TEXT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE

static func apply_screen(node: Node) -> void:
	# Only used for screens opened from pause. Explicit original overrides cannot
	# be replaced just by assigning an inherited Theme, so restyle them locally.
	if node is Label:
		label(node, maxi(16, node.get_theme_font_size("font_size")))
		if node.text in ["НАСТРОЙКИ", "ЗАГРУЗКА ИГРЫ  ·  СОХРАНЕНИЯ ВЫЖИВАНИЯ", "Настройки", "Загрузка игры"]:
			node.text = "Настройки" if node.text in ["НАСТРОЙКИ", "Настройки"] else "Загрузка игры"
			node.add_theme_font_override("font", SERIF)
			node.add_theme_font_size_override("font_size", 30)
	if node is Button:
		button(node)
		node.add_theme_font_size_override("font_size", 18)
		node.custom_minimum_size.y = maxf(44, node.custom_minimum_size.y)
	if node is PanelContainer:
		var panel = StyleBoxFlat.new()
		panel.bg_color = Color(0.045, 0.065, 0.055, 0.97)
		panel.content_margin_left = 24
		panel.content_margin_right = 24
		panel.content_margin_top = 20
		panel.content_margin_bottom = 20
		node.add_theme_stylebox_override("panel", panel)
	if node is ColorRect:
		node.color = Color(0.025, 0.04, 0.03, 0.68)
	for child in node.get_children():
		apply_screen(child)
