extends Node3D
class_name MapViewer

@onready var world_map: Node3D = $WorldMap
@onready var free_fly_cam: Camera3D = $FreeFlyCamera
@onready var player: CharacterBody3D = $Player

var _is_fps_mode: bool = false
var _sun: DirectionalLight3D = null
var _fps_label: Label = null

const POI_LOCATIONS = {
	"SPAWN": Vector3(-900.0, 26.0, 1100.0),
	"BRIDGE": Vector3(925.0, 66.0, -37.0),
	"FORD": Vector3(795.0, 66.0, -520.0),
	"FORK": Vector3(600.0, 78.0, -200.0),
	"LOOKOUT": Vector3(700.0, 366.0, -1550.0),
	"PEAK": Vector3(1500.0, 381.0, -1500.0),
	"MINE_YARD": Vector3(1100.0, 142.0, -1180.0),
	"MINE_ADIT": Vector3(1130.0, 144.0, -1210.0),
	"HUT": Vector3(0.0, 21.0, -300.0),
	"CLEARCUT": Vector3(-600.0, 32.0, 0.0),
	"WINDFALL": Vector3(-1400.0, 42.0, 600.0),
	"MEADOW": Vector3(-400.0, 2.0, -400.0)
}

func _ready() -> void:
	# Connect F1 signals from both cameras
	if free_fly_cam:
		free_fly_cam.request_toggle_controller.connect(_toggle_mode)
	if player:
		player.request_toggle_controller.connect(_toggle_mode)
		
	# Start at SPAWN
	player.global_position = POI_LOCATIONS["SPAWN"]
	free_fly_cam.global_position = POI_LOCATIONS["SPAWN"] + Vector3(0, 3, 5)
	free_fly_cam.look_at(POI_LOCATIONS["SPAWN"])
	
	# Default to FIRST PERSON PLAYER on startup, press F1 for FreeFly
	_set_fps_mode(true)
	_setup_poi_teleport_ui()
	_setup_fps_counter()
	load("res://scripts/core/SettingsManager.gd").get_instance().call_deferred("apply_graphics_settings")

func _setup_fps_counter() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "GlobalFPSOverlay"
	canvas.layer = 120 # above all other UI
	add_child(canvas)
	
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(16, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
			_fps_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4)) # green
		elif fps >= 30:
			_fps_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # yellow
		else:
			_fps_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3)) # red

func _toggle_mode() -> void:
	_set_fps_mode(not _is_fps_mode)

func _set_fps_mode(fps: bool) -> void:
	_is_fps_mode = fps
	if _is_fps_mode:
		# Sync player pos if switching from freefly
		if free_fly_cam:
			free_fly_cam.set_active(false)
		if player:
			player.set_active(true)
		print("[MapViewer] Mode switched to: FIRST PERSON PLAYER")
	else:
		if player:
			var p_pos = player.global_position
			player.set_active(false)
			if free_fly_cam:
				free_fly_cam.global_position = p_pos + Vector3(0, 2.5, 3)
				free_fly_cam.look_at(p_pos + Vector3(0, 1.5, 0))
		if free_fly_cam:
			free_fly_cam.set_active(true)
		print("[MapViewer] Mode switched to: FREE FLY CAMERA")

func _setup_poi_teleport_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "POITeleportUI"
	add_child(canvas)
	
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-220, 16)
	panel.custom_minimum_size = Vector2(200, 300)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(vbox)
	
	var lbl = Label.new()
	lbl.text = "POI FAST TRAVEL"
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(190, 260)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(scroll)
	
	var btn_vbox = VBoxContainer.new()
	btn_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(btn_vbox)
	
	for poi_id in POI_LOCATIONS.keys():
		var btn = Button.new()
		btn.text = poi_id
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		btn.pressed.connect(func(): _teleport_to_poi(poi_id))
		btn_vbox.add_child(btn)

func _teleport_to_poi(poi_id: String) -> void:
	if not POI_LOCATIONS.has(poi_id):
		return
	var dest = POI_LOCATIONS[poi_id]
	if _is_fps_mode:
		if player:
			player.global_position = dest
	else:
		if free_fly_cam:
			free_fly_cam.global_position = dest + Vector3(0, 15, 20)
			free_fly_cam.look_at(dest)
	print("[MapViewer] Teleported to: %s at %s" % [poi_id, str(dest)])
