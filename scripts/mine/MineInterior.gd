extends Node3D
class_name MineInterior

signal request_exit_mine

@export var return_to_exterior_scene: String = "res://scenes/viewer/MapViewer.tscn"

# Tunnel parameters
const TUNNEL_LENGTH: float = 70.0
const FRAME_SPACING: float = 3.0
const FRAME_COUNT: int = 23
const INCLINE_GRADE: float = 0.03 # 3% slope upwards

var _player: CharacterBody3D = null
var _ambient_audio: AudioStreamPlayer = null
var _fade_rect: ColorRect = null
var _fps_label: Label = null

func _ready() -> void:
	_setup_fade_ui()
	_setup_fps_counter()
	_setup_audio()
	_build_tunnel_geometry()
	_setup_entrance_exit_trigger()
	_spawn_player()
	_fade_in()

func _setup_fps_counter() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "MineFPSOverlay"
	canvas.layer = 120
	add_child(canvas)
	
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(16, 12)
	canvas.add_child(panel)
	
	_fps_label = Label.new()
	_fps_label.text = "FPS: -- (0.0 ms)"
	_fps_label.add_theme_font_size_override("font_size", 16)
	_fps_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	panel.add_child(_fps_label)

func _process(_delta: float) -> void:
	if _fps_label:
		var fps = Engine.get_frames_per_second()
		var ms = 1000.0 / maxf(float(fps), 1.0)
		_fps_label.text = "FPS: %d (%.1f ms)" % [fps, ms]
		if fps >= 55:
			_fps_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		elif fps >= 30:
			_fps_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			_fps_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

func _setup_fade_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "FadeUI"
	canvas.layer = 100
	add_child(canvas)
	
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0, 0, 0, 1)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_fade_rect)

func _fade_in() -> void:
	var tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, 0.5)

func _fade_out(callable: Callable) -> void:
	var tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, 0.5)
	tween.tween_callback(callable)

func _setup_audio() -> void:
	_ambient_audio = AudioStreamPlayer.new()
	_ambient_audio.name = "MineDripAmbient"
	_ambient_audio.bus = "Master"
	add_child(_ambient_audio)
	
	var stream = load("res://assets/sounds/level_01/ambience/amb_drip_bed.wav")
	if stream:
		_ambient_audio.stream = stream
		_ambient_audio.volume_db = -6.0
		_ambient_audio.play()

func _build_tunnel_geometry() -> void:
	var root = Node3D.new()
	root.name = "Geometry"
	add_child(root)
	
	var frame_scene = load("res://assets/models/mine/mine_frame.glb")
	var rails_scene = load("res://assets/models/mine/mine_rails.glb")
	var crate_scene = load("res://assets/models/mine/mine_crate.glb")
	var barrel_scene = load("res://assets/models/mine/mine_barrel.glb")
	var rubble_scene = load("res://assets/models/mine/mine_rubble.glb")
	
	# Materials for rock tunnel walls, ceiling, floor
	var mat_rock = StandardMaterial3D.new()
	mat_rock.albedo_color = Color(0.22, 0.20, 0.19)
	mat_rock.roughness = 0.95
	
	var mat_wet_rock = StandardMaterial3D.new()
	mat_wet_rock.albedo_color = Color(0.15, 0.14, 0.13)
	mat_wet_rock.roughness = 0.25
	
	# 1. Main Tunnel Walls & Floor (70m along -Z axis)
	# Floor
	var floor_box = CSGBox3D.new()
	floor_box.size = Vector3(3.2, 0.4, TUNNEL_LENGTH + 6.0)
	floor_box.position = Vector3(0.0, -0.2, -TUNNEL_LENGTH / 2.0)
	floor_box.material = mat_rock
	floor_box.use_collision = true
	root.add_child(floor_box)
	
	# Left wall
	var left_wall = CSGBox3D.new()
	left_wall.size = Vector3(0.4, 3.2, TUNNEL_LENGTH + 6.0)
	left_wall.position = Vector3(-1.5, 1.4, -TUNNEL_LENGTH / 2.0)
	left_wall.material = mat_rock
	left_wall.use_collision = true
	root.add_child(left_wall)
	
	# Right wall
	var right_wall = CSGBox3D.new()
	right_wall.size = Vector3(0.4, 3.2, TUNNEL_LENGTH + 6.0)
	right_wall.position = Vector3(1.5, 1.4, -TUNNEL_LENGTH / 2.0)
	right_wall.material = mat_rock
	right_wall.use_collision = true
	root.add_child(right_wall)
	
	# Ceiling
	var ceiling = CSGBox3D.new()
	ceiling.size = Vector3(3.2, 0.4, TUNNEL_LENGTH + 6.0)
	ceiling.position = Vector3(0.0, 2.7, -TUNNEL_LENGTH / 2.0)
	ceiling.material = mat_rock
	ceiling.use_collision = true
	root.add_child(ceiling)
	
	# 2. Place 23 Timber Frames and Rails along main adit
	for i in range(FRAME_COUNT):
		var z = -float(i) * FRAME_SPACING
		var y = float(i) * (FRAME_SPACING * INCLINE_GRADE)
		
		# Timber support frame
		if frame_scene:
			var frame = frame_scene.instantiate()
			frame.name = "Mine_Frame_%02d" % i
			frame.position = Vector3(0.0, y, z)
			root.add_child(frame)
			
		# Steel Rails (every 3m)
		if rails_scene:
			var rails = rails_scene.instantiate()
			rails.name = "Mine_Rails_%02d" % i
			rails.position = Vector3(0.0, y, z)
			root.add_child(rails)
			
		# Emergency Lanterns at intervals (every 4th frame)
		if i % 4 == 1:
			var light = OmniLight3D.new()
			light.position = Vector3(0.0, y + 2.1, z)
			light.light_color = Color(1.0, 0.75, 0.4) # warm amber lantern
			light.light_energy = 1.6
			light.omni_range = 7.5
			light.shadow_enabled = true
			root.add_child(light)
			
	# 3. Chamber A (Storage room on left at 30m, 8x6m)
	var z_a = -30.0
	var y_a = 30.0 * INCLINE_GRADE
	var chamber_a_floor = CSGBox3D.new()
	chamber_a_floor.size = Vector3(8.0, 0.4, 6.0)
	chamber_a_floor.position = Vector3(-4.5, y_a - 0.2, z_a)
	chamber_a_floor.material = mat_rock
	chamber_a_floor.use_collision = true
	root.add_child(chamber_a_floor)
	
	var chamber_a_ceil = CSGBox3D.new()
	chamber_a_ceil.size = Vector3(8.0, 0.4, 6.0)
	chamber_a_ceil.position = Vector3(-4.5, y_a + 2.7, z_a)
	chamber_a_ceil.material = mat_rock
	chamber_a_ceil.use_collision = true
	root.add_child(chamber_a_ceil)
	
	# Crates and barrels in Chamber A
	if crate_scene:
		for ci in range(5):
			var crate = crate_scene.instantiate()
			crate.name = "Mine_Crate_%02d" % ci
			crate.position = Vector3(-4.0 - ci * 0.7, y_a, z_a - 1.5 + (ci % 2) * 0.8)
			crate.rotation_degrees = Vector3(0, ci * 35.0, 0)
			root.add_child(crate)
			
	if barrel_scene:
		for bi in range(4):
			var barrel = barrel_scene.instantiate()
			barrel.name = "Mine_Barrel_%02d" % bi
			barrel.position = Vector3(-6.5 + (bi % 2) * 0.8, y_a, z_a + 1.2 - (bi / 2) * 0.8)
			root.add_child(barrel)
			
	var light_a = OmniLight3D.new()
	light_a.position = Vector3(-4.5, y_a + 2.2, z_a)
	light_a.light_color = Color(1.0, 0.8, 0.45)
	light_a.light_energy = 2.2
	light_a.omni_range = 9.0
	root.add_child(light_a)
	
	# 4. Branch B (Right side drift at 45m, 25m long, flooded end)
	var z_b = -45.0
	var y_b = 45.0 * INCLINE_GRADE
	var branch_b_floor = CSGBox3D.new()
	branch_b_floor.size = Vector3(25.0, 0.4, 2.8)
	branch_b_floor.position = Vector3(13.5, y_b - 0.2, z_b)
	branch_b_floor.material = mat_rock
	branch_b_floor.use_collision = true
	root.add_child(branch_b_floor)
	
	var branch_b_ceil = CSGBox3D.new()
	branch_b_ceil.size = Vector3(25.0, 0.4, 2.8)
	branch_b_ceil.position = Vector3(13.5, y_b + 2.5, z_b)
	branch_b_ceil.material = mat_rock
	branch_b_ceil.use_collision = true
	root.add_child(branch_b_ceil)
	
	# Flooded water plane in last 6m of Branch B
	var water_plane = CSGBox3D.new()
	water_plane.size = Vector3(7.0, 0.3, 2.6)
	water_plane.position = Vector3(22.0, y_b + 0.15, z_b)
	var mat_water = StandardMaterial3D.new()
	mat_water.albedo_color = Color(0.1, 0.25, 0.3, 0.85)
	mat_water.roughness = 0.05
	mat_water.metallic = 0.1
	water_plane.material = mat_water
	root.add_child(water_plane)
	
	# 5. Caved-in Hall at 70m (12x10x4m natural MVP boundary)
	var z_end = -TUNNEL_LENGTH
	var y_end = TUNNEL_LENGTH * INCLINE_GRADE
	var hall_floor = CSGBox3D.new()
	hall_floor.size = Vector3(12.0, 0.4, 10.0)
	hall_floor.position = Vector3(0.0, y_end - 0.2, z_end - 5.0)
	hall_floor.material = mat_rock
	hall_floor.use_collision = true
	root.add_child(hall_floor)
	
	var hall_ceil = CSGBox3D.new()
	hall_ceil.size = Vector3(12.0, 0.4, 10.0)
	hall_ceil.position = Vector3(0.0, y_end + 3.8, z_end - 5.0)
	hall_ceil.material = mat_rock
	hall_ceil.use_collision = true
	root.add_child(hall_ceil)
	
	# Massive rock rubble blocking passage
	if rubble_scene:
		var rubble = rubble_scene.instantiate()
		rubble.position = Vector3(0.0, y_end, z_end - 7.0)
		rubble.scale = Vector3(1.5, 1.5, 1.5)
		root.add_child(rubble)
		
	var light_hall = OmniLight3D.new()
	light_hall.position = Vector3(0.0, y_end + 3.0, z_end - 5.0)
	light_hall.light_color = Color(0.9, 0.6, 0.3)
	light_hall.light_energy = 1.5
	light_hall.omni_range = 10.0
	root.add_child(light_hall)
	
	# Entrance daylight spill
	var entrance_light = DirectionalLight3D.new()
	entrance_light.position = Vector3(0.0, 2.0, 5.0)
	entrance_light.rotation_degrees = Vector3(-15.0, 180.0, 0.0)
	entrance_light.light_energy = 0.8
	entrance_light.light_color = Color(0.8, 0.85, 0.95)
	root.add_child(entrance_light)

func _setup_entrance_exit_trigger() -> void:
	# Area3D at entrance (z = 1.5m) to exit back to forest exterior
	var exit_area = Area3D.new()
	exit_area.name = "ExitTrigger"
	exit_area.position = Vector3(0.0, 1.2, 2.0)
	add_child(exit_area)
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2.8, 2.5, 1.5)
	col.shape = box
	exit_area.add_child(col)
	
	exit_area.body_entered.connect(_on_exit_body_entered)

func _on_exit_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_fade_out(func():
			get_tree().change_scene_to_file(return_to_exterior_scene)
		)

func _spawn_player() -> void:
	var player_scene = load("res://scenes/player/Player.tscn")
	if player_scene:
		_player = player_scene.instantiate()
		add_child(_player)
		# Place player just inside entrance looking into tunnel
		_player.global_position = Vector3(0.0, 0.1, 0.0)
		_player.rotation_degrees = Vector3(0, 180, 0)
		_player.set_active(true)
