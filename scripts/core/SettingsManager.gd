extends Node
class_name SettingsManager

# SettingsManager: Centralized configuration persistence and application for Deadly Night

signal settings_applied
signal audio_volume_changed(bus_name, val)
signal graphics_changed
signal controls_changed
signal gameplay_changed

const CONFIG_PATH = "user://settings.cfg"

const RESOLUTION_OPTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

const WINDOW_MODES: Array[String] = [
	"Оконный",
	"Без рамок",
	"Полноэкранный"
]

const FPS_LIMIT_OPTIONS: Array[int] = [30, 60, 120, 144, 0] # 0 = Unlimited

const DEFAULTS: Dictionary = {
	"graphics": {
		"window_mode": 0,
		"resolution_x": 1280,
		"resolution_y": 720,
		"vsync": 1,
		"max_fps": 60,
		"shadow_quality": 2, # 0: Low, 1: Med, 2: High
		"view_distance": 2,  # 0: Near, 1: Med, 2: Far
		"fog_enabled": true,
		"sky_quality": 1,
		"rain_quality": 1,
		"reduced_lightning": false
	},
	"audio": {
		"master_volume": 0.85,
		"music_volume": 0.70,
		"sfx_volume": 0.90,
		"ambience_volume": 0.85,
		"weather_volume": 0.85,
		"thunder_volume": 0.8
	},
	"controls": {
		"mouse_sensitivity": 0.0022,
		"invert_y": false,
		"fov": 75.0,
		"camera_bobbing": true,
		"keybindings": {
			"move_forward": KEY_W,
			"move_backward": KEY_S,
			"move_left": KEY_A,
			"move_right": KEY_D,
			"jump": KEY_SPACE,
			"sprint": KEY_SHIFT,
			"crouch": KEY_CTRL,
			"interact": KEY_E,
			"inventory": KEY_TAB,
			"hotbar_1": KEY_1,
			"hotbar_2": KEY_2,
			"hotbar_3": KEY_3,
			"hotbar_4": KEY_4,
			"hotbar_5": KEY_5,
			"hotbar_6": KEY_6,
			"hotbar_7": KEY_7,
			"hotbar_8": KEY_8,
			"toggle_camera": KEY_F1
		}
	},
	"gameplay": {
		"hud_visible": true,
		"ui_scale": 1.0,
		"autosave_interval_min": 5, # 5 min default
		"subtitles": true,
		"language": "ru"
	}
}

var _config_data: Dictionary = {}

static var _instance: Node = null
var _initialized: bool = false

static func get_instance():
	if _instance == null:
		_instance = load("res://scripts/core/SettingsManager.gd").new()
		var main_loop = Engine.get_main_loop()
		if main_loop and main_loop is SceneTree and main_loop.root:
			main_loop.root.call_deferred("add_child", _instance)
		_instance._ready()
	return _instance

func _enter_tree() -> void:
	if _instance == null:
		_instance = self

func _ready() -> void:
	if _initialized:
		return
	_initialized = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_default_data()
	load_from_disk()
	apply_all_settings()

func _init_default_data() -> void:
	_config_data = DEFAULTS.duplicate(true)

func get_setting(section: String, key: String, default_val = null):
	if _config_data.has(section) and _config_data[section].has(key):
		return _config_data[section][key]
	if DEFAULTS.has(section) and DEFAULTS[section].has(key):
		return DEFAULTS[section][key]
	return default_val

func set_setting(section: String, key: String, value) -> void:
	if not _config_data.has(section):
		_config_data[section] = {}
	_config_data[section][key] = value

func load_from_disk() -> bool:
	var cfg = ConfigFile.new()
	var err = cfg.load(CONFIG_PATH)
	if err != OK:
		print("[SettingsManager] No existing settings.cfg found or error (%d). Using defaults." % err)
		return false

	for sec in _config_data.keys():
		if cfg.has_section(sec):
			for key in _config_data[sec].keys():
				if key == "keybindings":
					# Load nested keybindings
					var keys_dict = _config_data[sec]["keybindings"]
					for k_action in keys_dict.keys():
						if cfg.has_section_key(sec, "key_" + k_action):
							keys_dict[k_action] = cfg.get_value(sec, "key_" + k_action, keys_dict[k_action])
				elif cfg.has_section_key(sec, key):
					_config_data[sec][key] = cfg.get_value(sec, key, _config_data[sec][key])
					
	print("[SettingsManager] Settings loaded successfully from: %s" % CONFIG_PATH)
	return true

func save_to_disk() -> bool:
	var cfg = ConfigFile.new()
	for sec in _config_data.keys():
		for key in _config_data[sec].keys():
			if key == "keybindings":
				var keys_dict = _config_data[sec]["keybindings"]
				for k_action in keys_dict.keys():
					cfg.set_value(sec, "key_" + k_action, keys_dict[k_action])
			else:
				cfg.set_value(sec, key, _config_data[sec][key])
				
	var err = cfg.save(CONFIG_PATH)
	if err == OK:
		print("[SettingsManager] Settings saved to: %s" % CONFIG_PATH)
		return true
	else:
		printerr("[SettingsManager] Failed to save settings to %s (error %d)" % [CONFIG_PATH, err])
		return false

func save_settings() -> bool:
	return save_to_disk()

func reset_to_defaults(persist: bool = true) -> void:
	_init_default_data()
	apply_all_settings()
	if persist:
		save_to_disk()

func apply_all_settings() -> void:
	apply_graphics_settings()
	apply_audio_settings()
	apply_controls_settings()
	apply_gameplay_settings()
	settings_applied.emit()

func apply_graphics_settings() -> void:
	var g = _config_data.get("graphics", DEFAULTS["graphics"])
	var mode = g.get("window_mode", 0)
	var rx = g.get("resolution_x", 1280)
	var ry = g.get("resolution_y", 720)
	var vsync = g.get("vsync", 1)
	var max_fps = g.get("max_fps", 60)
	
	# Window mode & Resolution
	if DisplayServer.get_name() != "headless":
		match mode:
			0: # Windowed
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				DisplayServer.window_set_size(Vector2i(rx, ry))
			1: # Borderless Fullscreen
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
				var screen_size = DisplayServer.screen_get_size()
				DisplayServer.window_set_size(screen_size)
				DisplayServer.window_set_position(Vector2i(0, 0))
			2: # Exclusive Fullscreen
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
				
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync == 1 else DisplayServer.VSYNC_DISABLED)

	Engine.max_fps = max_fps
	if is_inside_tree() and get_tree().current_scene:
		_apply_scene_graphics(get_tree().current_scene, g)
	graphics_changed.emit()

func _apply_scene_graphics(node: Node, graphics: Dictionary) -> void:
	var quality: int = clampi(int(graphics.get("shadow_quality", 2)), 0, 2)
	var distance_index: int = clampi(int(graphics.get("view_distance", 2)), 0, 2)
	if node is Camera3D:
		node.far = [1500.0, 2500.0, 4000.0][distance_index]
	if node is Light3D:
		if not node.has_meta("settings_original_shadow"):
			node.set_meta("settings_original_shadow", node.shadow_enabled)
		node.shadow_enabled = quality > 0 and node.get_meta("settings_original_shadow")
		if node is DirectionalLight3D:
			if not node.has_meta("settings_original_shadow_distance"):
				node.set_meta("settings_original_shadow_distance", node.directional_shadow_max_distance)
			var original: float = node.get_meta("settings_original_shadow_distance")
			node.directional_shadow_max_distance = original * (0.5 if quality == 1 else 1.0)
	if node is WorldEnvironment and node.environment:
		node.environment.fog_enabled = graphics.get("fog_enabled", true)
	for child in node.get_children():
		_apply_scene_graphics(child, graphics)

func apply_audio_settings() -> void:
	var a = _config_data.get("audio", DEFAULTS["audio"])
	_set_bus_vol("Master", a.get("master_volume", 0.85))
	_set_bus_vol("Music", a.get("music_volume", 0.70))
	_set_bus_vol("SFX", a.get("sfx_volume", 0.90))
	_set_bus_vol("Ambience", a.get("ambience_volume", 0.85))

func _set_bus_vol(bus_name: String, linear_vol: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		var clamped = clampf(linear_vol, 0.0, 1.0)
		var db = linear_to_db(clamped) if clamped > 0.001 else -80.0
		AudioServer.set_bus_volume_db(idx, db)
		AudioServer.set_bus_mute(idx, clamped <= 0.001)
		audio_volume_changed.emit(bus_name, clamped)

func get_bus_volume_linear(bus_name: String) -> float:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		if AudioServer.is_bus_mute(idx):
			return 0.0
		var db = AudioServer.get_bus_volume_db(idx)
		return db_to_linear(db)
	return get_setting("audio", bus_name.to_lower() + "_volume", 0.8)

func preview_bus_volume_linear(bus_name: String, linear_vol: float) -> void:
	_set_bus_vol(bus_name, linear_vol)

func set_bus_volume_linear(bus_name: String, linear_vol: float) -> void:
	var key = bus_name.to_lower() + "_volume"
	set_setting("audio", key, clampf(linear_vol, 0.0, 1.0))
	_set_bus_vol(bus_name, linear_vol)

func event_matches_action(event: InputEventKey, action: String) -> bool:
	var bindings: Dictionary = get_setting("controls", "keybindings", {})
	var code: int = int(bindings.get(action, KEY_NONE))
	return code != KEY_NONE and (event.physical_keycode == code or (event.physical_keycode == 0 and event.keycode == code))

func is_binding_pressed(action: String) -> bool:
	var bindings: Dictionary = get_setting("controls", "keybindings", {})
	var code: int = int(bindings.get(action, KEY_NONE))
	return code != KEY_NONE and (Input.is_action_pressed(action) or Input.is_physical_key_pressed(code) or Input.is_key_pressed(code))

func apply_controls_settings() -> void:
	var bindings: Dictionary = get_setting("controls", "keybindings", {})
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event = InputEventKey.new()
		event.physical_keycode = int(bindings[action])
		InputMap.action_add_event(action, event)
	controls_changed.emit()

func apply_gameplay_settings() -> void:
	gameplay_changed.emit()
