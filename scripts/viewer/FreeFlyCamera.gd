extends Camera3D
class_name FreeFlyCamera

signal request_toggle_controller

@export var move_speed: float = 25.0
@export var boost_speed: float = 100.0
@export var mouse_sensitivity: float = 0.003

var _velocity: Vector3 = Vector3.ZERO
var _mouse_captured: bool = false
var _hud_label: Label = null
var _mode_label: Label = null

func _ready() -> void:
	_setup_hud()

func set_active(active: bool) -> void:
	current = active
	set_process(active)
	set_process_unhandled_input(active)
	var canvas = get_node_or_null("FreeFlyHUD")
	if canvas:
		canvas.visible = active
	if active:
		_set_mouse_capture(true)

func _setup_hud() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "FreeFlyHUD"
	add_child(canvas)
	
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(16, 52)
	panel.custom_minimum_size = Vector2(340, 160)
	canvas.add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "DEADLY NIGHT — MAP VIEWER"
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)
	
	_mode_label = Label.new()
	_mode_label.text = "MODE: FREE FLY [F1: Switch to FPS]"
	_mode_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(_mode_label)
	
	_hud_label = Label.new()
	_hud_label.text = "Position: ---\nFPS: ---"
	vbox.add_child(_hud_label)
	
	var help = Label.new()
	help.text = "Controls: WASD + Q/E (elevate) | Shift: Turbo\nF1: Player / FreeFly | F2: Top-down | R: Spawn | ESC: Mouse"
	help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(help)

func _set_mouse_capture(captured: bool) -> void:
	_mouse_captured = captured
	if captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if not current:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _mouse_captured:
			_set_mouse_capture(true)
			
	if event.is_action_pressed("ui_cancel"): # ESC
		_set_mouse_capture(false)
		
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			request_toggle_controller.emit()
		elif event.keycode == KEY_F2:
			_toggle_top_down()
		elif event.keycode == KEY_R:
			_teleport_to_spawn()
			
	if _mouse_captured and event is InputEventMouseMotion:
		rotation.y -= event.relative.x * mouse_sensitivity
		rotation.x -= event.relative.y * mouse_sensitivity
		rotation.x = clamp(rotation.x, -deg_to_rad(89.0), deg_to_rad(89.0))

func _process(delta: float) -> void:
	if not current:
		return
		
	var input_dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1.0
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_E):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_Q):
		input_dir.y -= 1.0
		
	var speed = boost_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed
	
	# Transform input relative to camera yaw and pitch
	var forward = -global_transform.basis.z
	var right = global_transform.basis.x
	var up = Vector3.UP
	
	var dir = (forward * -input_dir.z + right * input_dir.x + up * input_dir.y).normalized()
	global_position += dir * speed * delta
	
	_update_hud()

func _update_hud() -> void:
	if _hud_label == null:
		return
		
	var pos = global_position
	var chunk_x = clampi(int(floor((pos.x + 2000.0) / 250.0)), 0, 15)
	var chunk_y = clampi(int(floor((-pos.z + 2000.0) / 250.0)), 0, 15)
	var chunk_name = "Chunk_%02d_%02d" % [chunk_x, chunk_y]
	var fps = Engine.get_frames_per_second()
	
	_hud_label.text = "Pos: (X: %.1f, Y: %.1f, Z: %.1f)\nChunk: %s | FPS: %d\nAlt: %.1f m" % [
		pos.x, pos.y, pos.z, chunk_name, fps, pos.y
	]

func _toggle_top_down() -> void:
	global_position = Vector3(0.0, 1200.0, 0.0)
	rotation_degrees = Vector3(-89.9, 0.0, 0.0)

func _teleport_to_spawn() -> void:
	# SPAWN is at (-900, 25, 1100)
	global_position = Vector3(-900.0, 32.0, 1105.0)
	rotation_degrees = Vector3(-10.0, 45.0, 0.0)
