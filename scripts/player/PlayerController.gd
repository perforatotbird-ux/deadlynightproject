extends CharacterBody3D
class_name PlayerController

const TreeChoppableScript = preload("res://scripts/props/TreeChoppable.gd")
const LogPickupScript = preload("res://scripts/props/LogPickup.gd")

signal request_toggle_controller

@export var walk_speed: float = 4.5
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 2.5
@export var jump_velocity: float = 4.8
@export var mouse_sensitivity: float = 0.0025
@export var max_backpack_kg: float = 25.0

# Nodes
var _camera: Camera3D = null
var _camera_pivot: Node3D = null
var _axe_pivot: Node3D = null
var _axe_model: Node3D = null
var _raycast: RayCast3D = null

# Audio
var _audio_step: AudioStreamPlayer3D = null
var _audio_swing: AudioStreamPlayer3D = null
var _audio_ui: AudioStreamPlayer = null

# State
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _is_crouching: bool = false
var _target_camera_y: float = 1.6
var _current_camera_y: float = 1.6
var _step_timer: float = 0.0
var _can_chop: bool = true
var _chop_cooldown: float = 0.8

# Inventory
var backpack_items: Array[Dictionary] = []
var backpack_weight: float = 0.0

# HUD Elements
var _hud_layer: CanvasLayer = null
var _crosshair: Control = null
var _prompt_label: Label = null
var _backpack_label: Label = null
var _speed_penalty_label: Label = null

func _ready() -> void:
	_setup_camera_and_axe()
	_setup_audio()
	_setup_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_camera_and_axe() -> void:
	# Camera Pivot
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_camera_pivot.position = Vector3(0.0, 1.6, 0.0)
	add_child(_camera_pivot)
	
	# Camera3D
	_camera = Camera3D.new()
	_camera.name = "PlayerCamera"
	_camera.fov = 80.0
	_camera.current = false # activated by MapViewer
	_camera_pivot.add_child(_camera)
	
	# Raycast for chopping and pickup (range 2.0m)
	_raycast = RayCast3D.new()
	_raycast.name = "InteractRay"
	_raycast.target_position = Vector3(0, 0, -2.2)
	_raycast.collision_mask = 2 | 4 # Layer 2 (Trees), Layer 4 (Logs)
	_camera.add_child(_raycast)
	
	# Axe Viewmodel Pivot
	_axe_pivot = Node3D.new()
	_axe_pivot.name = "AxePivot"
	# Position in front and slightly right of camera
	_axe_pivot.position = Vector3(0.35, -0.28, -0.55)
	_axe_pivot.rotation_degrees = Vector3(-15.0, -10.0, -5.0)
	_camera.add_child(_axe_pivot)
	
	var axe_path = "res://assets/models/props/axe_iron.glb"
	if ResourceLoader.exists(axe_path):
		var axe_scene = load(axe_path)
		if axe_scene:
			_axe_model = axe_scene.instantiate()
			_axe_pivot.add_child(_axe_model)

func _setup_audio() -> void:
	_audio_step = AudioStreamPlayer3D.new()
	_audio_step.name = "StepAudio"
	_audio_step.bus = "Master"
	add_child(_audio_step)
	
	_audio_swing = AudioStreamPlayer3D.new()
	_audio_swing.name = "SwingAudio"
	_audio_swing.bus = "Master"
	add_child(_audio_swing)
	
	_audio_ui = AudioStreamPlayer.new()
	_audio_ui.name = "UIAudio"
	add_child(_audio_ui)

func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "PlayerHUD"
	add_child(_hud_layer)
	
	# Crosshair (small clean dot / plus)
	var center = Control.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	_hud_layer.add_child(center)
	_crosshair = center
	
	var dot = ColorRect.new()
	dot.custom_minimum_size = Vector2(4, 4)
	dot.position = Vector2(-2, -2)
	dot.color = Color(1.0, 1.0, 1.0, 0.8)
	center.add_child(dot)
	
	# Center Prompt Label
	_prompt_label = Label.new()
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_label.position = Vector2(-150, 24)
	_prompt_label.custom_minimum_size = Vector2(300, 40)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_hud_layer.add_child(_prompt_label)
	
	# Bottom Left Backpack Display
	var bp_panel = PanelContainer.new()
	bp_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bp_panel.position = Vector2(24, -130)
	bp_panel.custom_minimum_size = Vector2(320, 100)
	_hud_layer.add_child(bp_panel)
	
	var bp_box = VBoxContainer.new()
	bp_panel.add_child(bp_box)
	
	var title = Label.new()
	title.text = "SURVIVAL INVENTORY"
	title.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	bp_box.add_child(title)
	
	_backpack_label = Label.new()
	_backpack_label.text = "Backpack: 0.0 / 25.0 kg (0 logs)"
	bp_box.add_child(_backpack_label)
	
	_speed_penalty_label = Label.new()
	_speed_penalty_label.text = ""
	_speed_penalty_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	bp_box.add_child(_speed_penalty_label)
	
	var f1_tip = Label.new()
	f1_tip.text = "F1: FreeFly Camera | LMB: Chop | E: Interact"
	f1_tip.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	bp_box.add_child(f1_tip)

func set_active(active: bool) -> void:
	if _camera:
		_camera.current = active
	if _hud_layer:
		_hud_layer.visible = active
	if active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not _camera.current:
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			request_toggle_controller.emit()
			return
		elif event.keycode == KEY_E:
			_try_interact()
			return
			
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				_try_chop()
				
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity
		_camera_pivot.rotation.x -= event.relative.y * mouse_sensitivity
		_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, -deg_to_rad(85.0), deg_to_rad(85.0))

func _physics_process(delta: float) -> void:
	if not _camera.current:
		return
		
	# Gravity
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
		
	# Crouch logic
	_is_crouching = Input.is_key_pressed(KEY_CTRL)
	_target_camera_y = 1.0 if _is_crouching else 1.6
	_current_camera_y = lerp(_current_camera_y, _target_camera_y, delta * 10.0)
	_camera_pivot.position.y = _current_camera_y
	
	# Jump
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor() and not _is_crouching:
		velocity.y = jump_velocity
		
	# Input direction
	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()
	
	# Speed selection
	var base_spd = walk_speed
	if _is_crouching:
		base_spd = crouch_speed
	elif Input.is_key_pressed(KEY_SHIFT) and input_dir.length_squared() > 0.0:
		base_spd = sprint_speed
		
	# Overweight penalty (70% speed when backpack > 25 kg)
	var speed_multiplier = 1.0
	if backpack_weight > max_backpack_kg:
		speed_multiplier = 0.70
		_speed_penalty_label.text = "OVERBURDENED: Speed reduced to 70%%"
	else:
		_speed_penalty_label.text = ""
		
	var final_speed = base_spd * speed_multiplier
	
	# Direction relative to body facing
	var move_vec = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if move_vec.length_squared() > 0.0:
		velocity.x = move_vec.x * final_speed
		velocity.z = move_vec.z * final_speed
		_play_footstep(delta, final_speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, final_speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, final_speed * 8.0 * delta)
		
	move_and_slide()
	_update_viewmodel_sway(delta, velocity.length())
	_update_raycast_target()

func _update_viewmodel_sway(delta: float, h_speed: float) -> void:
	if _axe_pivot == null:
		return
	# Gentle idle bobbing + movement sway
	var time = Time.get_ticks_msec() / 1000.0
	var bob_x = sin(time * 2.0) * 0.015
	var bob_y = cos(time * 4.0) * 0.010
	if h_speed > 0.5:
		bob_x += sin(time * 8.0) * 0.035
		bob_y += abs(cos(time * 8.0)) * 0.025
	_axe_pivot.position = Vector3(0.35 + bob_x, -0.28 + bob_y, -0.55)

func _play_footstep(delta: float, current_speed: float) -> void:
	if not is_on_floor():
		return
	_step_timer += delta * (current_speed / walk_speed)
	if _step_timer >= 0.55:
		_step_timer = 0.0
		var steps = [
			"res://assets/sounds/level_01/footsteps/step_grass_01.wav",
			"res://assets/sounds/level_01/footsteps/step_grass_02.wav",
			"res://assets/sounds/level_01/footsteps/step_grass_03.wav",
			"res://assets/sounds/level_01/footsteps/step_grass_04.wav"
		]
		var pick = steps[randi() % steps.size()]
		if ResourceLoader.exists(pick):
			_audio_step.stream = load(pick)
			_audio_step.pitch_scale = randf_range(0.95, 1.05)
			_audio_step.play()

func _update_raycast_target() -> void:
	if _raycast == null:
		return
		
	if _raycast.is_colliding():
		var collider = _raycast.get_collider()
		if collider is TreeChoppableScript:
			_prompt_label.text = collider.get_interact_text()
		elif collider is LogPickupScript:
			_prompt_label.text = collider.get_interact_text()
		elif collider.has_method("get_interact_text"):
			_prompt_label.text = collider.get_interact_text()
		else:
			_prompt_label.text = ""
	else:
		_prompt_label.text = ""

func _try_chop() -> void:
	if not _can_chop:
		return
		
	_can_chop = false
	_play_swing_animation_and_sound()
	
	# Execute hit if raycast hits choppable tree
	if _raycast.is_colliding():
		var collider = _raycast.get_collider()
		if collider is TreeChoppableScript:
			var hit_pt = _raycast.get_collision_point()
			collider.hit(1, hit_pt, global_position)
			
	# Cooldown timer
	await get_tree().create_timer(_chop_cooldown).timeout
	_can_chop = true

func _play_swing_animation_and_sound() -> void:
	var swings = [
		"res://assets/sounds/level_01/axe/axe_swing_01.wav",
		"res://assets/sounds/level_01/axe/axe_swing_02.wav"
	]
	var pick = swings[randi() % swings.size()]
	if ResourceLoader.exists(pick):
		_audio_swing.stream = load(pick)
		_audio_swing.pitch_scale = randf_range(0.95, 1.05)
		_audio_swing.play()
		
	if _axe_pivot:
		var tween = create_tween()
		# Fast forward slash
		tween.tween_property(_axe_pivot, "rotation_degrees", Vector3(-45.0, 35.0, -35.0), 0.12).set_trans(Tween.TRANS_QUAD)
		# Slower return to ready stance
		tween.tween_property(_axe_pivot, "rotation_degrees", Vector3(-15.0, -10.0, -5.0), 0.35).set_trans(Tween.TRANS_SINE)

func _try_interact() -> void:
	if not _raycast.is_colliding():
		return
		
	var collider = _raycast.get_collider()
	if collider is LogPickupScript:
		var item_data = collider.pickup()
		_add_to_backpack(item_data)
		# Play log pickup sound
		var s = "res://assets/sounds/level_01/props/log_pickup.wav"
		if ResourceLoader.exists(s):
			_audio_ui.stream = load(s)
			_audio_ui.play()

func _add_to_backpack(item: Dictionary) -> void:
	backpack_items.append(item)
	backpack_weight += item["weight"]
	_update_inventory_hud()

func _update_inventory_hud() -> void:
	if _backpack_label:
		_backpack_label.text = "Backpack: %.1f / %.1f kg (%d logs)" % [
			backpack_weight, max_backpack_kg, backpack_items.size()
		]
