extends Node3D
class_name MenuBackdrop3D

# MenuBackdrop3D: Atmospheric early spring mixed forest with abandoned mine vista

@export var camera_sway_speed: float = 0.12
@export var camera_sway_amount: float = 0.45

var _camera: Camera3D = null
var _time: float = 0.0
var _initial_cam_pos: Vector3
var _initial_cam_rot: Vector3

var _audio_wind: AudioStreamPlayer = null
var _audio_birds: AudioStreamPlayer = null
var _audio_music: AudioStreamPlayer = null

func _ready() -> void:
	_setup_environment()
	_setup_lighting()
	_setup_ground()
	_setup_mine_and_props()
	_setup_vegetation()
	_setup_camera()
	_setup_audio()

func _setup_environment() -> void:
	var we = WorldEnvironment.new()
	we.name = "MenuWorldEnvironment"
	add_child(we)
	
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.24, 0.32, 0.42)      # Cold overcast steel blue
	sky_mat.sky_horizon_color = Color(0.55, 0.62, 0.68)  # Misty pale horizon
	sky_mat.ground_bottom_color = Color(0.12, 0.14, 0.13) # Damp forest loam
	sky_mat.ground_horizon_color = Color(0.48, 0.54, 0.58)
	sky_mat.sun_angle_max = 30.0
	sky.sky_material = sky_mat
	env.sky = sky
	
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.65, 0.70, 0.75)
	env.ambient_light_sky_contribution = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	
	# Atmospheric multi-layered spring fog
	env.fog_enabled = true
	env.fog_light_color = Color(0.58, 0.66, 0.72)
	env.fog_density = 0.015
	env.fog_aerial_perspective = 0.4
	
	we.environment = env

func _setup_lighting() -> void:
	var sun = DirectionalLight3D.new()
	sun.name = "MenuSunLight"
	sun.transform.basis = Basis(Vector3(1, 0, 0), deg_to_rad(-28)).rotated(Vector3(0, 1, 0), deg_to_rad(45))
	sun.light_color = Color(0.92, 0.95, 0.98) # Pale cool morning spring sun
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	add_child(sun)

func _setup_ground() -> void:
	var ground_mesh = PlaneMesh.new()
	ground_mesh.size = Vector2(80.0, 80.0)
	ground_mesh.subdivide_width = 16
	ground_mesh.subdivide_depth = 16
	
	var mi = MeshInstance3D.new()
	mi.name = "MenuGround"
	mi.mesh = ground_mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.18, 0.15) # Loam, pine needles and early spring moss
	mat.roughness = 0.92
	mi.material_override = mat
	add_child(mi)

func _setup_mine_and_props() -> void:
	# Middle-ground rocky hillside behind mine portal
	var hill = MeshInstance3D.new()
	var hill_mesh = BoxMesh.new()
	hill_mesh.size = Vector3(32.0, 10.0, 18.0)
	hill.mesh = hill_mesh
	var hill_mat = StandardMaterial3D.new()
	hill_mat.albedo_color = Color(0.18, 0.20, 0.21) # Wet dark slate rock face
	hill_mat.roughness = 0.88
	hill.material_override = hill_mat
	hill.position = Vector3(6.0, 2.5, -24.0)
	hill.rotation_degrees = Vector3(5.0, -15.0, 0.0)
	add_child(hill)
	
	# Abandoned Mine Portal
	var portal_path = "res://assets/models/mine/mine_portal.glb"
	if ResourceLoader.exists(portal_path):
		var p_scene = load(portal_path)
		if p_scene:
			var portal = p_scene.instantiate()
			portal.name = "MenuMinePortal"
			portal.position = Vector3(5.5, 0.0, -16.5)
			portal.rotation_degrees = Vector3(0.0, -25.0, 0.0)
			add_child(portal)
			
	# Mine rails & cart leading out of portal
	var rails_path = "res://assets/models/mine/mine_rails.glb"
	if ResourceLoader.exists(rails_path):
		var r_scene = load(rails_path)
		if r_scene:
			for i in range(3):
				var rails = r_scene.instantiate()
				rails.position = Vector3(4.8 - float(i) * 1.8, 0.05, -14.5 + float(i) * 2.6)
				rails.rotation_degrees = Vector3(0.0, -25.0, 0.0)
				add_child(rails)
				
	var cart_path = "res://assets/models/mine/mine_cart.glb"
	if ResourceLoader.exists(cart_path):
		var c_scene = load(cart_path)
		if c_scene:
			var cart = c_scene.instantiate()
			cart.position = Vector3(2.6, 0.1, -11.5)
			cart.rotation_degrees = Vector3(0.0, -32.0, 0.0)
			add_child(cart)

func _setup_vegetation() -> void:
	var species_list = ["spruce", "birch", "beech", "oak"]
	var tree_scenes = {}
	for sp in species_list:
		var p = "res://assets/models/trees/tree_%s.glb" % sp
		if ResourceLoader.exists(p):
			tree_scenes[sp] = load(p)
			
	# Hand-crafted natural vista layout (Framing the camera view)
	var tree_placements = [
		# Right foreground framing (Tall evergreen spruces)
		{"sp": "spruce", "pos": Vector3(7.5, 0, -4.5), "rot": 35.0, "scl": 1.25},
		{"sp": "spruce", "pos": Vector3(10.0, 0, -8.0), "rot": 110.0, "scl": 1.4},
		{"sp": "spruce", "pos": Vector3(8.5, 0, -12.0), "rot": 210.0, "scl": 1.15},
		
		# Left foreground framing (White-bark birches & beech with young spring foliage)
		{"sp": "birch", "pos": Vector3(-6.5, 0, -5.5), "rot": -45.0, "scl": 1.1},
		{"sp": "beech", "pos": Vector3(-9.0, 0, -9.0), "rot": 75.0, "scl": 1.2},
		{"sp": "birch", "pos": Vector3(-7.5, 0, -13.0), "rot": 140.0, "scl": 1.3},
		
		# Midground depth trees
		{"sp": "birch", "pos": Vector3(-2.2, 0, -11.0), "rot": 20.0, "scl": 0.95},
		{"sp": "spruce", "pos": Vector3(2.5, 0, -19.5), "rot": -80.0, "scl": 1.3},
		{"sp": "spruce", "pos": Vector3(9.5, 0, -21.0), "rot": 45.0, "scl": 1.35},
		{"sp": "oak", "pos": Vector3(-4.5, 0, -17.5), "rot": 190.0, "scl": 1.1},
		{"sp": "beech", "pos": Vector3(0.5, 0, -25.0), "rot": 60.0, "scl": 1.25}
	]
	
	for t in tree_placements:
		var scene = tree_scenes.get(t["sp"])
		if scene:
			var inst = scene.instantiate()
			inst.position = t["pos"]
			inst.rotation_degrees = Vector3(0, t["rot"], 0)
			inst.scale = Vector3.ONE * t["scl"]
			add_child(inst)
			
	# Fallen mossy logs and stumps on forest floor
	var stump_path = "res://assets/models/trees/tree_birch_stump.glb"
	if ResourceLoader.exists(stump_path):
		var s_scene = load(stump_path)
		if s_scene:
			var stump = s_scene.instantiate()
			stump.position = Vector3(-3.5, 0, -6.0)
			stump.rotation_degrees = Vector3(0, 30, 0)
			add_child(stump)
			
	var log_path = "res://assets/models/trees/tree_spruce_log.glb"
	if ResourceLoader.exists(log_path):
		var l_scene = load(log_path)
		if l_scene:
			var log1 = l_scene.instantiate()
			log1.position = Vector3(3.2, 0.15, -6.5)
			log1.rotation_degrees = Vector3(0, -55, 0)
			add_child(log1)

func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "MenuCamera"
	_camera.position = Vector3(0.0, 1.8, 0.0)
	_camera.rotation_degrees = Vector3(-3.5, 8.0, 0.0)
	_camera.fov = 68.0
	_camera.current = true
	add_child(_camera)
	
	_initial_cam_pos = _camera.position
	_initial_cam_rot = _camera.rotation_degrees

func _setup_audio() -> void:
	# 1. Forest wind canopy loop
	var wind_path = "res://assets/sounds/level_01/ambience/amb_wind_canopy.wav"
	if ResourceLoader.exists(wind_path):
		_audio_wind = AudioStreamPlayer.new()
		_audio_wind.name = "MenuAmbWind"
		_audio_wind.stream = load(wind_path)
		_audio_wind.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
		_audio_wind.volume_db = -6.0
		add_child(_audio_wind)
		_audio_wind.play()
		
	# 2. Early spring birds & meadow atmosphere
	var birds_path = "res://assets/sounds/level_01/ambience/amb_meadow_spring.ogg"
	if ResourceLoader.exists(birds_path):
		_audio_birds = AudioStreamPlayer.new()
		_audio_birds.name = "MenuAmbBirds"
		_audio_birds.stream = load(birds_path)
		_audio_birds.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
		_audio_birds.volume_db = -10.0
		add_child(_audio_birds)
		_audio_birds.play()
		
	# 3. Subdued tension survival drone music
	var music_path = "res://assets/sounds/level_01/music/mus_tension_drone.ogg"
	if ResourceLoader.exists(music_path):
		_audio_music = AudioStreamPlayer.new()
		_audio_music.name = "MenuMusic"
		_audio_music.stream = load(music_path)
		_audio_music.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
		_audio_music.volume_db = -12.0
		add_child(_audio_music)
		_audio_music.play()

func _process(delta: float) -> void:
	_time += delta
	if _camera:
		# Subtle, tranquil cinematic breathing motion
		var offset_x = sin(_time * camera_sway_speed) * camera_sway_amount * 0.4
		var offset_y = cos(_time * camera_sway_speed * 1.5) * camera_sway_amount * 0.15
		var rot_yaw = sin(_time * camera_sway_speed * 0.8) * 0.75
		
		_camera.position = _initial_cam_pos + Vector3(offset_x, offset_y, 0.0)
		_camera.rotation_degrees = _initial_cam_rot + Vector3(0.0, rot_yaw, 0.0)
