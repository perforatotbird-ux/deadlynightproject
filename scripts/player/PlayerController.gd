extends CharacterBody3D
class_name PlayerController

const AxeArmRigScript = preload("res://scripts/player/AxeArmRig.gd")
const AXE_REST_POS := Vector3(0.29, -0.29, -0.43)
const AXE_REST_ROT := Vector3(-12.0, -18.0, -12.0)
const AXE_WINDUP_POS := Vector3(0.36, -0.14, -0.48)
const AXE_WINDUP_ROT := Vector3(24.0, -18.0, 14.0)
const AXE_CONTACT_POS := Vector3(0.035, -0.28, -0.50)
const AXE_CONTACT_ROT := Vector3(-66.0, 8.0, 16.0)
const AXE_FOLLOW_POS := Vector3(-0.015, -0.41, -0.48)
const AXE_FOLLOW_ROT := Vector3(-84.0, 6.0, 20.0)
# One shared playback scale doubles every phase, contact and cooldown together.
const AXE_ANIMATION_SPEED: float = 0.5
const AXE_WINDUP_TIME: float = 0.12
const AXE_STROKE_TIME: float = 0.10

const TreeChoppableScript = preload("res://scripts/props/TreeChoppable.gd")
const LogPickupScript = preload("res://scripts/props/LogPickup.gd")
const PauseMenuScript = preload("res://scripts/menu/PauseMenu.gd")
const SettingsManagerScript = preload("res://scripts/core/SettingsManager.gd")
const SaveManagerScript = preload("res://scripts/core/SaveManager.gd")

signal request_toggle_controller

@export var walk_speed: float = 4.5
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 2.5
@export var jump_velocity: float = 4.8
@export var mouse_sensitivity: float = 0.0022
@export var max_backpack_kg: float = 25.0

# Inventory Specs
const MAX_SLOTS: int = 16
const MAX_STACK: int = 10

const SPECIES_ITEM_DATA = {
	"birch": {
		"name": "Берёзовое полено",
		"unit_weight": 4.0,
		"color": Color(0.96, 0.96, 0.86),
		"burn_time": "1.5 ч",
		"heat": "+18 °C",
		"desc": "Плотная светлая древесина берёзы. Быстро разгорается и дает стабильное тепло в печи или костре."
	},
	"spruce": {
		"name": "Еловое полено",
		"unit_weight": 5.0,
		"color": Color(0.85, 0.50, 0.22),
		"burn_time": "1.8 ч",
		"heat": "+22 °C",
		"desc": "Смолистая хвойная древесина ели. При горении приятно трещит и быстро прогревает укрытие."
	},
	"oak": {
		"name": "Дубовое полено",
		"unit_weight": 9.0,
		"color": Color(0.60, 0.40, 0.20),
		"burn_time": "3.0 ч",
		"heat": "+30 °C",
		"desc": "Тяжелая и плотная древесина векового дуба. Горит медленно, оставляя долго тлеющие угли."
	},
	"beech": {
		"name": "Буковое полено",
		"unit_weight": 7.0,
		"color": Color(0.90, 0.82, 0.55),
		"burn_time": "2.5 ч",
		"heat": "+26 °C",
		"desc": "Качественная твердая древесина горного бука. Высокая теплоотдача и ровное бездымное пламя."
	}
}

# Toolbelt / Hotbar Configuration (Пояс инструментов выживальщика)
const HOTBAR_CONFIG = [
	{
		"id": "axe",
		"name": "Топор лесоруба",
		"short_name": "ТОПОР",
		"key": "1",
		"icon": "🪓",
		"desc": "[ЛКМ] Рубить деревья",
		"status": "100%"
	},
	{
		"id": "lantern",
		"name": "Штормовой фонарь",
		"short_name": "ФОНАРЬ",
		"key": "2",
		"icon": "🔦",
		"desc": "[ЛКМ] Вкл / Выкл свет",
		"status": "Керосин"
	},
	{
		"id": "compass",
		"name": "Полевой компас",
		"short_name": "КОМПАС",
		"key": "3",
		"icon": "🧭",
		"desc": "Навигация и азимут",
		"status": "Магнит"
	},
	{
		"id": "matches",
		"name": "Охотничьи спички",
		"short_name": "СПИЧКИ",
		"key": "4",
		"icon": "🔥",
		"desc": "[ЛКМ] Зажечь огонь",
		"status": "12 шт."
	},
	{
		"id": "knife",
		"name": "Охотничий нож",
		"short_name": "НОЖ",
		"key": "5",
		"icon": "🔪",
		"desc": "Снятие коры и крафт",
		"status": "Острый"
	}
]

var active_hotbar_slot: int = 0
var _is_lantern_on: bool = false
var _lantern_light: SpotLight3D = null

# Camera and Viewmodel Nodes
var _camera_pivot: Node3D = null
var _camera: Camera3D = null
var _raycast: RayCast3D = null
var _axe_sway_pivot: Node3D = null
var _axe_anim_pivot: Node3D = null
var _axe_model: Node3D = null
var _axe_arm_rig: Node3D = null
var _chop_tween: Tween = null

# Audio Players
var _audio_step: AudioStreamPlayer3D = null
var _audio_swing: AudioStreamPlayer3D = null
var _audio_hit: AudioStreamPlayer3D = null
var _audio_ui: AudioStreamPlayer = null

# Physics & State
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _camera_pitch: float = 0.0
var _base_fov: float = 75.0
var _camera_bobbing_enabled: bool = true
var _hud_enabled: bool = true
var _is_crouching: bool = false
var _target_camera_y: float = 1.6
var _current_camera_y: float = 1.6
var _step_timer: float = 0.0
var _can_chop: bool = true
var _chop_cooldown: float = 0.50
var _is_active: bool = true
var _is_mouse_captured: bool = true
var _is_inventory_open: bool = false
var _is_lmb_held: bool = false

var is_lmb_held: bool:
	get: return _is_lmb_held
	set(val): _is_lmb_held = val

# Viewmodel Sway & Bobbing
var _mouse_delta: Vector2 = Vector2.ZERO
var _bob_timer: float = 0.0
var _sway_offset: Vector3 = Vector3.ZERO
var _sway_rotation: Vector3 = Vector3.ZERO
var _camera_shake: float = 0.0

# Jump & Sprint States (Coyote time & Jump buffer)
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _is_sprint_jumping: bool = false

# Inventory Data
var inventory_slots: Array = []
var backpack_items: Array[Dictionary] = [] # Kept for API compatibility with tests
var backpack_weight: float = 0.0
var _selected_slot_index: int = -1

# HUD Elements
var _hud_layer: CanvasLayer = null
var _crosshair_dot: ColorRect = null
var _crosshair_ring: Control = null
var _prompt_label: Label = null
var _backpack_label: Label = null
var _speed_penalty_label: Label = null

# Toolbelt HUD Elements (Пояс инструментов)
var _toolbelt_panel: PanelContainer = null
var _hotbar_slot_buttons: Array[Button] = []
var _hotbar_slot_labels: Array[Label] = []
var _hotbar_status_labels: Array[Label] = []
var _hotbar_hotkey_labels: Array[Label] = []
var _tool_banner_label: Label = null
var _tool_banner_tween: Tween = null
var _compass_label: Label = null

# Inventory UI Elements
var _inv_layer: CanvasLayer = null
var _inv_root_panel: PanelContainer = null
var _inv_weight_label: Label = null
var _inv_weight_bar: ProgressBar = null
var _inv_overweight_warning: Label = null
var _inv_slot_buttons: Array[Button] = []
var _inv_details_title: Label = null
var _inv_details_category: Label = null
var _inv_details_stats: Label = null
var _inv_details_desc: Label = null
var _inv_btn_drop_one: Button = null
var _inv_btn_drop_all: Button = null
var _inv_empty_inspector_label: Label = null
var _inv_inspector_box: VBoxContainer = null
var _pause_menu: Node = null
var survival: Node = null

func _ready() -> void:
	_init_inventory_data()
	_setup_camera_and_viewmodel()
	_setup_audio()
	_setup_hud()
	_setup_inventory_ui()
	_setup_pause_menu()
	_connect_save_manager_signals()
	_connect_settings_signals()
	_is_mouse_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _init_inventory_data() -> void:
	inventory_slots.clear()
	inventory_slots.resize(MAX_SLOTS)
	inventory_slots.fill(null)
	backpack_items.clear()
	backpack_weight = 0.0
	_selected_slot_index = -1

func set_active(active: bool) -> void:
	_is_active = active
	if not active:
		_cancel_chop()
		if is_instance_valid(survival):
			survival.cancel_job()
			survival.cancel_placement()
	if _camera:
		_camera.current = active
	if _hud_layer:
		_hud_layer.visible = active and _hud_enabled
	if _inv_layer and not active:
		_inv_layer.visible = false
		_is_inventory_open = false
	set_physics_process(active)
	set_process(active)
	set_process_input(active)
	if active and not _is_inventory_open:
		_is_mouse_captured = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_camera_and_viewmodel() -> void:
	# Camera Pivot (Handles pitch look & crouch height)
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_camera_pivot.position = Vector3(0.0, 1.6, 0.0)
	add_child(_camera_pivot)
	
	# Camera3D
	_camera = Camera3D.new()
	_camera.name = "PlayerCamera"
	_camera.fov = 75.0
	_camera.near = 0.05
	_camera.current = false
	_camera_pivot.add_child(_camera)
	
	# RayCast for interact & chopping (Generous 3.5m reach)
	_raycast = RayCast3D.new()
	_raycast.name = "InteractRay"
	_raycast.target_position = Vector3(0.0, 0.0, -3.5)
	_raycast.collision_mask = 1 | 2 | 4 | 8 # Layer 2: Trees, Layer 3/4: Logs, Props
	_camera.add_child(_raycast)
	_raycast.add_exception(self)
	
	# Viewmodel Hierarchy:
	# _camera -> _axe_sway_pivot (sway & bobbing) -> _axe_anim_pivot (chop animations) -> model
	_axe_sway_pivot = Node3D.new()
	_axe_sway_pivot.name = "AxeSwayPivot"
	_camera.add_child(_axe_sway_pivot)
	
	_axe_anim_pivot = Node3D.new()
	_axe_anim_pivot.name = "AxeAnimPivot"
	# Grip is the animation origin: the head rotates around the hands.
	_axe_anim_pivot.position = AXE_REST_POS
	_axe_anim_pivot.rotation_degrees = AXE_REST_ROT
	_axe_anim_pivot.scale = Vector3(0.75, 0.75, 0.75)
	_axe_sway_pivot.add_child(_axe_anim_pivot)
	
	var axe_path = "res://assets/models/props/axe_iron.glb"
	if ResourceLoader.exists(axe_path):
		var axe_scene = load(axe_path)
		if axe_scene:
			_axe_model = axe_scene.instantiate()
			_axe_anim_pivot.add_child(_axe_model)
			_axe_model.position.y = -0.15

	_axe_arm_rig = AxeArmRigScript.new()
	_axe_arm_rig.name = "AxeArms"
	_axe_sway_pivot.add_child(_axe_arm_rig)
	_axe_arm_rig.setup(_axe_anim_pivot)

	# Kerosene Storm Lantern SpotLight (Slot 2)
	_lantern_light = SpotLight3D.new()
	_lantern_light.name = "LanternLight"
	_lantern_light.spot_range = 28.0
	_lantern_light.spot_angle = 52.0
	_lantern_light.spot_attenuation = 1.2
	_lantern_light.light_color = Color(1.0, 0.84, 0.50) # Warm kerosene flame glow
	_lantern_light.light_energy = 3.0
	_lantern_light.shadow_enabled = true
	_lantern_light.position = Vector3(0.15, -0.15, -0.25)
	_lantern_light.visible = false
	_camera.add_child(_lantern_light)

func _setup_audio() -> void:
	_audio_step = AudioStreamPlayer3D.new()
	_audio_step.name = "StepAudio"
	_audio_step.bus = "Master"
	add_child(_audio_step)
	
	_audio_swing = AudioStreamPlayer3D.new()
	_audio_swing.name = "SwingAudio"
	_audio_swing.bus = "Master"
	add_child(_audio_swing)
	
	_audio_hit = AudioStreamPlayer3D.new()
	_audio_hit.name = "HitAudio"
	_audio_hit.bus = "Master"
	add_child(_audio_hit)
	
	_audio_ui = AudioStreamPlayer.new()
	_audio_ui.name = "UIAudio"
	add_child(_audio_ui)

func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "PlayerHUD"
	_hud_layer.layer = 90
	add_child(_hud_layer)
	
	# Center Reticle Container (Mouse filter ignore!)
	var center = Control.new()
	center.name = "CrosshairCenter"
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(center)
	
	# Reticle Dot
	_crosshair_dot = ColorRect.new()
	_crosshair_dot.custom_minimum_size = Vector2(4, 4)
	_crosshair_dot.position = Vector2(-2, -2)
	_crosshair_dot.color = Color(1.0, 1.0, 1.0, 0.7)
	_crosshair_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_crosshair_dot)
	
	# Reticle Ring (shown when aiming at an interactable object)
	_crosshair_ring = Control.new()
	_crosshair_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair_ring.visible = false
	center.add_child(_crosshair_ring)
	
	var r_top = ColorRect.new()
	r_top.position = Vector2(-1, -10)
	r_top.custom_minimum_size = Vector2(2, 5)
	r_top.color = Color(1.0, 0.85, 0.25, 0.9)
	r_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair_ring.add_child(r_top)
	
	var r_bot = ColorRect.new()
	r_bot.position = Vector2(-1, 5)
	r_bot.custom_minimum_size = Vector2(2, 5)
	r_bot.color = Color(1.0, 0.85, 0.25, 0.9)
	r_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair_ring.add_child(r_bot)
	
	var r_left = ColorRect.new()
	r_left.position = Vector2(-10, -1)
	r_left.custom_minimum_size = Vector2(5, 2)
	r_left.color = Color(1.0, 0.85, 0.25, 0.9)
	r_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair_ring.add_child(r_left)
	
	var r_right = ColorRect.new()
	r_right.position = Vector2(5, -1)
	r_right.custom_minimum_size = Vector2(5, 2)
	r_right.color = Color(1.0, 0.85, 0.25, 0.9)
	r_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair_ring.add_child(r_right)
	
	# Center Prompt Label (The Long Dark style)
	_prompt_label = Label.new()
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_label.position = Vector2(-250, 28)
	_prompt_label.custom_minimum_size = Vector2(500, 32)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 16)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_prompt_label)
	
	# Bottom Left Backpack / Survival Display
	var bp_panel = PanelContainer.new()
	bp_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bp_panel.position = Vector2(24, -135)
	bp_panel.custom_minimum_size = Vector2(340, 110)
	bp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(bp_panel)
	
	var bp_box = VBoxContainer.new()
	bp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bp_panel.add_child(bp_box)
	
	var title = Label.new()
	title.text = "ИНВЕНТАРЬ ВЫЖИВАНИЯ"
	title.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95))
	title.add_theme_font_size_override("font_size", 14)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bp_box.add_child(title)
	
	_backpack_label = Label.new()
	_backpack_label.text = "Рюкзак: 0.0 / 25.0 кг (0 поленьев)"
	_backpack_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_backpack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bp_box.add_child(_backpack_label)
	
	_speed_penalty_label = Label.new()
	_speed_penalty_label.text = ""
	_speed_penalty_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	_speed_penalty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bp_box.add_child(_speed_penalty_label)
	
	var tip = Label.new()
	tip.text = "[1-5 / Колесо] Инструменты  |  [ЛКМ] Действие  |  [E] Подобрать\n[TAB] Рюкзак  |  [Shift] Бег  |  [Ctrl] Присед  |  [F1] Свободная камера"
	tip.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	tip.add_theme_font_size_override("font_size", 12)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bp_box.add_child(tip)
	
	# Top Compass HUD Label (Active when compass tool is equipped)
	_compass_label = Label.new()
	_compass_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_compass_label.position = Vector2(-260, 42)
	_compass_label.custom_minimum_size = Vector2(520, 28)
	_compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compass_label.add_theme_font_size_override("font_size", 15)
	_compass_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	_compass_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_compass_label.add_theme_constant_override("shadow_offset_x", 1)
	_compass_label.add_theme_constant_override("shadow_offset_y", 1)
	_compass_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass_label.visible = false
	_hud_layer.add_child(_compass_label)

	# Bottom Toolbelt Container (Пояс инструментов выживальщика)
	_setup_toolbelt_hud()

func _setup_toolbelt_hud() -> void:
	# Floating tool description banner above hotbar
	_tool_banner_label = Label.new()
	_tool_banner_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tool_banner_label.position = Vector2(-240, -116)
	_tool_banner_label.custom_minimum_size = Vector2(480, 26)
	_tool_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tool_banner_label.add_theme_font_size_override("font_size", 13)
	_tool_banner_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_tool_banner_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_tool_banner_label.add_theme_constant_override("shadow_offset_x", 1)
	_tool_banner_label.add_theme_constant_override("shadow_offset_y", 1)
	_tool_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_tool_banner_label)
	
	# Main Toolbelt Panel Container (Пояс выживания)
	_toolbelt_panel = PanelContainer.new()
	_toolbelt_panel.name = "ToolbeltPanel"
	_toolbelt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toolbelt_panel.position = Vector2(-195, -82)
	_toolbelt_panel.custom_minimum_size = Vector2(390, 68)
	_toolbelt_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var belt_sb = StyleBoxFlat.new()
	belt_sb.bg_color = Color(0.06, 0.08, 0.10, 0.90)
	belt_sb.border_width_left = 1
	belt_sb.border_width_top = 1
	belt_sb.border_width_right = 1
	belt_sb.border_width_bottom = 1
	belt_sb.border_color = Color(0.30, 0.35, 0.40, 0.75)
	belt_sb.corner_radius_top_left = 6
	belt_sb.corner_radius_top_right = 6
	belt_sb.corner_radius_bottom_left = 6
	belt_sb.corner_radius_bottom_right = 6
	belt_sb.shadow_size = 14
	belt_sb.shadow_color = Color(0, 0, 0, 0.7)
	belt_sb.content_margin_left = 8
	belt_sb.content_margin_top = 6
	belt_sb.content_margin_right = 8
	belt_sb.content_margin_bottom = 6
	_toolbelt_panel.add_theme_stylebox_override("panel", belt_sb)
	_hud_layer.add_child(_toolbelt_panel)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_toolbelt_panel.add_child(hbox)
	
	_hotbar_slot_buttons.clear()
	_hotbar_slot_labels.clear()
	_hotbar_hotkey_labels.clear()
	
	for i in range(HOTBAR_CONFIG.size()):
		var item = HOTBAR_CONFIG[i]
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(66, 56)
		btn.focus_mode = Control.FOCUS_NONE # Important: prevent keyboard capture
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		btn.text = ""
		btn.name = "HotbarSlot_%d" % i
		
		var vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 0)
		btn.add_child(vbox)
		
		var top_row = HBoxContainer.new()
		top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(top_row)
		
		var key_lbl = Label.new()
		key_lbl.text = item.key
		key_lbl.add_theme_font_size_override("font_size", 10)
		key_lbl.add_theme_color_override("font_color", Color(0.70, 0.75, 0.80))
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_row.add_child(key_lbl)
		_hotbar_hotkey_labels.append(key_lbl)
		
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_row.add_child(spacer)
		
		var stat_lbl = Label.new()
		stat_lbl.text = item.status
		stat_lbl.add_theme_font_size_override("font_size", 8)
		stat_lbl.add_theme_color_override("font_color", Color(0.55, 0.60, 0.65))
		stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_row.add_child(stat_lbl)
		_hotbar_status_labels.append(stat_lbl)
		
		var icon_lbl = Label.new()
		icon_lbl.text = item.icon
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 18)
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon_lbl)
		
		var title_lbl = Label.new()
		title_lbl.text = item.short_name
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.add_theme_font_size_override("font_size", 9)
		title_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(title_lbl)
		_hotbar_slot_labels.append(title_lbl)
		
		var slot_idx = i
		btn.pressed.connect(func(): select_hotbar_slot(slot_idx))
		
		hbox.add_child(btn)
		_hotbar_slot_buttons.append(btn)
		
	_update_hotbar_ui()

func _update_hotbar_ui() -> void:
	for i in range(_hotbar_slot_buttons.size()):
		var btn = _hotbar_slot_buttons[i]
		var is_selected = (i == active_hotbar_slot)
		
		var sb = StyleBoxFlat.new()
		if is_selected:
			sb.bg_color = Color(0.16, 0.20, 0.25, 0.95)
			sb.border_width_left = 2
			sb.border_width_top = 2
			sb.border_width_right = 2
			sb.border_width_bottom = 2
			sb.border_color = Color(1.0, 0.82, 0.25, 0.98) # Survival Gold
			sb.shadow_size = 6
			sb.shadow_color = Color(1.0, 0.82, 0.25, 0.35)
		else:
			sb.bg_color = Color(0.08, 0.10, 0.12, 0.70)
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.border_color = Color(0.25, 0.28, 0.32, 0.60)
			sb.shadow_size = 0
			
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		sb.content_margin_left = 4
		sb.content_margin_top = 3
		sb.content_margin_right = 4
		sb.content_margin_bottom = 3
		
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		
		if i < _hotbar_hotkey_labels.size():
			_hotbar_hotkey_labels[i].add_theme_color_override("font_color", Color(1.0, 0.85, 0.30) if is_selected else Color(0.65, 0.70, 0.75))
		if i < _hotbar_slot_labels.size():
			_hotbar_slot_labels[i].add_theme_color_override("font_color", Color(1.0, 0.92, 0.45) if is_selected else Color(0.80, 0.84, 0.88))
			
	if active_hotbar_slot >= 0 and active_hotbar_slot < HOTBAR_CONFIG.size():
		var cur = HOTBAR_CONFIG[active_hotbar_slot]
		_show_tool_banner("[%s] %s  ·  %s" % [cur.key, cur.name.to_upper(), cur.desc])

func _update_equipped_tool() -> void:
	_cancel_chop()
	if _axe_arm_rig:
		_axe_arm_rig.visible = active_hotbar_slot == 0
	if _axe_anim_pivot == null:
		return
		
	if active_hotbar_slot == 0: # Axe
		_axe_anim_pivot.visible = true
		if _lantern_light:
			_lantern_light.visible = false
		if _compass_label:
			_compass_label.visible = false
		_axe_anim_pivot.position = AXE_REST_POS
		_axe_anim_pivot.rotation_degrees = AXE_REST_ROT
	elif active_hotbar_slot == 1: # Lantern
		_axe_anim_pivot.visible = false
		if _lantern_light:
			_lantern_light.visible = _is_lantern_on
		if _compass_label:
			_compass_label.visible = false
	elif active_hotbar_slot == 2: # Compass
		_axe_anim_pivot.visible = false
		if _lantern_light:
			_lantern_light.visible = false
		if _compass_label:
			_compass_label.visible = true
	elif active_hotbar_slot == 3: # Matches
		_axe_anim_pivot.visible = false
		if _lantern_light:
			_lantern_light.visible = false
		if _compass_label:
			_compass_label.visible = false
	elif active_hotbar_slot == 4: # Knife
		_axe_anim_pivot.visible = false
		if _lantern_light:
			_lantern_light.visible = false
		if _compass_label:
			_compass_label.visible = false

func select_hotbar_slot(idx: int) -> void:
	if idx < 0 or idx >= HOTBAR_CONFIG.size():
		return
	if active_hotbar_slot == idx:
		return
	active_hotbar_slot = idx
	_update_hotbar_ui()
	_update_equipped_tool()
	
	if active_hotbar_slot == 0:
		_play_ui_sound("res://assets/sounds/level_01/axe/axe_equip.wav")
	else:
		_play_ui_sound("res://assets/sounds/level_01/props/cloth_01.wav")

func cycle_hotbar_slot(direction: int) -> void:
	if _is_inventory_open:
		return
	var new_slot = (active_hotbar_slot + direction) % HOTBAR_CONFIG.size()
	if new_slot < 0:
		new_slot += HOTBAR_CONFIG.size()
	select_hotbar_slot(new_slot)

func _show_tool_banner(text: String) -> void:
	if _tool_banner_label == null:
		return
	_tool_banner_label.text = text
	_tool_banner_label.modulate.a = 1.0
	if _tool_banner_tween and _tool_banner_tween.is_valid():
		_tool_banner_tween.kill()
	_tool_banner_tween = create_tween()
	_tool_banner_tween.tween_interval(2.2)
	_tool_banner_tween.tween_property(_tool_banner_label, "modulate:a", 0.0, 0.8)

func _use_active_tool() -> void:
	if _is_inventory_open:
		return
	match active_hotbar_slot:
		0:
			_try_chop()
		1:
			_toggle_lantern()
		2:
			_ping_compass()
		3:
			_strike_match()
		4:
			_use_knife()

func _toggle_lantern() -> void:
	if _lantern_light == null:
		return
	_is_lantern_on = not _is_lantern_on
	_lantern_light.visible = _is_lantern_on
	_play_ui_sound("res://assets/sounds/level_01/ui/ui_click.wav")
	_show_tool_banner("ШТОРМОВОЙ ФОНАРЬ: " + ("ВКЛЮЧЕН" if _is_lantern_on else "ВЫКЛЮЧЕН"))

func _ping_compass() -> void:
	_play_ui_sound("res://assets/sounds/level_01/ui/ui_click.wav")
	_show_tool_banner("ПОЛЕВОЙ КОМПАС: Азимут активен")

func _strike_match() -> void:
	if is_instance_valid(survival):
		var fire = survival.nearby_fire()
		if fire.is_empty():
			survival.notify("Подойдите к подготовленному костру. [Tab] — создание костра")
		else:
			survival.open_backpack(fire["id"])
		return
	_play_ui_sound("res://assets/sounds/level_01/ui/ui_click.wav")
	_show_tool_banner("ОХОТНИЧЬИ СПИЧКИ: Вспышка пламени!")
	if _lantern_light:
		_lantern_light.visible = true
		_lantern_light.light_energy = 5.0
		var tw = create_tween()
		tw.tween_property(_lantern_light, "light_energy", 0.0, 0.5)
		await tw.finished
		if is_instance_valid(_lantern_light):
			_lantern_light.visible = _is_lantern_on
			_lantern_light.light_energy = 3.0

func _use_knife() -> void:
	_play_ui_sound("res://assets/sounds/level_01/axe/axe_swing_01.wav")
	_show_tool_banner("ОХОТНИЧИЙ НОЖ: Готов к снятию бересты и крафту")

var _backpack_ui: Node
func _setup_inventory_ui() -> void:
	_backpack_ui = preload("res://scripts/ui/BackpackUI.gd").new()
	add_child(_backpack_ui)
	_backpack_ui.build(self)

func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if not _is_active or not _camera.current:
		return
		
	# Survival owns modal/placement input before tools and movement.
	if is_instance_valid(survival) and survival.handle_input(event):
		get_viewport().set_input_as_handled()
		return

	# Keyboard Events (TAB toggles inventory!)
	if event is InputEventKey and event.pressed and not event.echo:
		if _event_matches_action(event, "inventory"):
			get_viewport().set_input_as_handled()
			_toggle_inventory()
			return
		elif event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _is_inventory_open:
				_toggle_inventory()
			elif _pause_menu != null:
				_is_lmb_held = false
				_cancel_chop()
				_pause_menu.open_pause()
			else:
				_toggle_mouse_capture()
			return
		elif event.keycode == KEY_F5:
			get_viewport().set_input_as_handled()
			_trigger_quicksave()
			return
		elif _event_matches_action(event, "toggle_camera"):
			if not _is_inventory_open:
				request_toggle_controller.emit()
			return
		elif _event_matches_action(event, "interact"):
			if not _is_inventory_open:
				_try_interact()
			return
		elif _event_matches_action(event, "jump"):
			if not _is_inventory_open:
				_jump_buffer_timer = 0.20
		elif not _is_inventory_open:
			for index in range(5):
				if _event_matches_action(event, "hotbar_%d" % (index + 1)):
					select_hotbar_slot(index)
					return
			
	# If inventory is open, mouse is for UI clicking only (do not rotate camera!)
	if _is_inventory_open:
		return
		
	# Mouse Motion -> Look
	if event is InputEventMouseMotion:
		if _is_mouse_captured or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_handle_mouse_look(event.relative)
			return
			
	# Mouse Buttons & Wheel (FPS mode)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_lmb_held = event.pressed
			if event.pressed:
				_is_mouse_captured = true
				if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_use_active_tool()
			return
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_is_mouse_captured = true
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cycle_hotbar_slot(-1)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cycle_hotbar_slot(1)
			return

func _handle_mouse_look(rel: Vector2) -> void:
	var sens = mouse_sensitivity
	var invert_y = false
	var sm = SettingsManagerScript.get_instance()
	if sm != null:
		sens = sm.get_setting("controls", "mouse_sensitivity", mouse_sensitivity)
		invert_y = sm.get_setting("controls", "invert_y", false)
		
	# Horizontal Yaw on CharacterBody
	rotate_y(-rel.x * sens)
	
	# Vertical Pitch on CameraPivot
	var pitch_delta = rel.y * sens * (1.0 if invert_y else -1.0)
	_camera_pitch = clampf(_camera_pitch + pitch_delta, deg_to_rad(-85.0), deg_to_rad(85.0))
	_camera_pivot.rotation.x = _camera_pitch
	
	# Accumulate mouse delta for viewmodel inertia sway
	_mouse_delta += rel

func _setup_pause_menu() -> void:
	var pause_scene = load("res://scenes/menu/PauseMenu.tscn")
	if pause_scene:
		_pause_menu = pause_scene.instantiate()
		add_child(_pause_menu)

func _connect_save_manager_signals() -> void:
	var sm = SaveManagerScript.get_instance()
	if sm and not sm.autosave_triggered.is_connected(_on_autosave_banner):
		sm.autosave_triggered.connect(_on_autosave_banner)

func _on_autosave_banner(slot_id: String) -> void:
	_show_tool_banner("💾 Автосохранение... [%s]" % slot_id)

func _trigger_quicksave() -> void:
	var sm = SaveManagerScript.get_instance()
	if sm:
		var slot = sm.current_slot_id if sm.current_slot_id != "" else "slot_1"
		var success = sm.save_game(slot, "manual")
		if success:
			_show_tool_banner("💾 Быстрое сохранение выполнено [%s]" % slot)
		else:
			_show_tool_banner("✗ Ошибка сохранения")

func _update_hud_display() -> void:
	_update_inventory_hud()
	_update_hotbar_ui()

func _toggle_mouse_capture() -> void:
	_is_lmb_held = false
	_is_mouse_captured = not _is_mouse_captured
	if _is_mouse_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _toggle_inventory() -> void:
	if is_instance_valid(survival) and survival.placing: survival.cancel_placement()
	_cancel_chop()
	_is_lmb_held = false
	_is_inventory_open = not _is_inventory_open
	if _is_inventory_open:
		_inv_layer.visible = true
		_is_mouse_captured = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_play_ui_sound("res://assets/sounds/level_01/ui/ui_inventory_open.wav")
		_refresh_inventory_ui()
	else:
		_inv_layer.visible = false
		if is_instance_valid(survival): survival.cancel_job()
		_is_mouse_captured = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_play_ui_sound("res://assets/sounds/level_01/ui/ui_inventory_close.wav")

func _physics_process(delta: float) -> void:
	if not _is_active or not _camera.current:
		return
	if is_instance_valid(survival) and survival.health <= 0:
		_cancel_chop()
		velocity.x=0; velocity.z=0
		return
		
	# Gravity & Ground snap with Coyote Time
	if is_on_floor():
		_coyote_timer = 0.20
		_is_sprint_jumping = false
		if velocity.y <= 0.0:
			velocity.y = -0.1
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
		velocity.y -= _gravity * delta
		
	# Jump buffer decay & input polling
	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	if _is_action_down("jump"):
		_jump_buffer_timer = 0.20
		
	# If inventory is open, player stands still
	if _is_inventory_open:
		_is_lmb_held = false
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		move_and_slide()
		return

	# Continuous Auto-Chop with Axe when LMB is held down
	if _is_lmb_held and active_hotbar_slot == 0 and _can_chop and not _is_inventory_open:
		_try_chop()
		
	# Crouch logic (Ctrl or C)
	_is_crouching = _is_action_down("crouch")
	# Keep the legacy C alias only while crouch uses its default key.
	var binds: Dictionary = SettingsManagerScript.get_instance().get_setting("controls", "keybindings", {})
	if binds.get("crouch", KEY_CTRL) == KEY_CTRL:
		_is_crouching = _is_crouching or Input.is_physical_key_pressed(KEY_C)
	_target_camera_y = 1.0 if _is_crouching else 1.6
	_current_camera_y = lerpf(_current_camera_y, _target_camera_y, delta * 10.0)
	_camera_pivot.position.y = _current_camera_y
	
	# Movement input (WASD - with physical scancode fallback for non-Latin layouts)
	var input_dir = Vector2.ZERO
	if _is_action_down("move_forward"):
		input_dir.y -= 1.0
	if _is_action_down("move_backward"):
		input_dir.y += 1.0
	if _is_action_down("move_left"):
		input_dir.x -= 1.0
	if _is_action_down("move_right"):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()
	
	# Speed calculation
	var is_sprint_key = _is_action_down("sprint")
	var is_sprinting = (is_sprint_key or _is_sprint_jumping) and input_dir.length_squared() > 0.0 and not _is_crouching
	var base_spd = walk_speed
	if _is_crouching:
		base_spd = crouch_speed
	elif is_sprinting:
		base_spd = sprint_speed
		
	# Jump execution (reliable during sprint, walking, slopes with coyote time & buffer)
	var can_jump = (_coyote_timer > 0.0 or is_on_floor()) and not _is_crouching
	if _jump_buffer_timer > 0.0 and can_jump:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		if is_sprinting:
			_is_sprint_jumping = true
		
	# Overweight penalty: 70% speed when backpack > 25 kg
	var speed_multiplier = 1.0
	if backpack_weight > max_backpack_kg:
		speed_multiplier = 0.70
		_speed_penalty_label.text = "ПЕРЕГРУЗ: Скорость снижена на 30%%"
	else:
		_speed_penalty_label.text = ""
		
	if is_instance_valid(survival):
		if survival.energy < 10.0:base_spd = minf(base_spd,walk_speed)
		if survival.warmth < 20.0:speed_multiplier *= 0.85
	var final_speed = base_spd * speed_multiplier
	
	# Movement vector relative to character heading
	var move_vec = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if move_vec.length_squared() > 0.0:
		velocity.x = lerpf(velocity.x, move_vec.x * final_speed, delta * 12.0)
		velocity.z = lerpf(velocity.z, move_vec.z * final_speed, delta * 12.0)
		_play_footstep(delta, final_speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, final_speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, final_speed * 10.0 * delta)
		
	move_and_slide()
	
	# The Long Dark Dynamic FOV kick on sprint
	var target_fov = minf(_base_fov + 7.0, 110.0) if is_sprinting else _base_fov
	_camera.fov = lerpf(_camera.fov, target_fov, delta * 6.0)
	
	# Update viewmodel sway, bobbing and camera shake
	_update_viewmodel_sway(delta, velocity.length())
	_update_raycast_target()
	
	# Update Compass readout if compass is equipped
	if active_hotbar_slot == 2 and _compass_label and _camera:
		var cam_rot_y = _camera.global_transform.basis.get_euler().y
		var deg = fposmod(-rad_to_deg(cam_rot_y), 360.0)
		var dirs = ["СЕВЕР", "СВ", "ВОСТОК", "ЮВ", "ЮГ", "ЮЗ", "ЗАПАД", "СЗ"]
		var dir_idx = int(round(deg / 45.0)) % 8
		_compass_label.text = "🧭 КОМПАС: %d° [%s]  ·  ОРИЕНТИР: ШАХТА (1100, 1000)  ·  СПАВН (-900, 1100)" % [int(deg), dirs[dir_idx]]
		_compass_label.visible = true
	elif _compass_label and _compass_label.visible:
		_compass_label.visible = false

func _update_viewmodel_sway(delta: float, h_speed: float) -> void:
	if not _camera_bobbing_enabled:
		if _axe_sway_pivot:
			_axe_sway_pivot.position = Vector3.ZERO
			_axe_sway_pivot.rotation = Vector3.ZERO
		_mouse_delta = Vector2.ZERO
		_camera_shake = 0.0
		_camera_pivot.rotation.x = _camera_pitch
		return
	if _axe_sway_pivot == null:
		return
		
	# 1. Idle Breathing + Walking Bobbing
	var bob_freq = 8.0 if h_speed > 3.0 else 5.0
	if h_speed > 0.2:
		_bob_timer += delta * bob_freq
	else:
		_bob_timer += delta * 1.5 # slow breathing
		
	var bob_x = sin(_bob_timer) * (0.012 if h_speed > 0.2 else 0.003)
	var bob_y = cos(_bob_timer * 2.0) * (0.008 if h_speed > 0.2 else 0.002)
	
	# 2. Mouse Look Lag / Inertia Sway
	var sway_x = clampf(-_mouse_delta.x * 0.0003, -0.04, 0.04)
	var sway_y = clampf(_mouse_delta.y * 0.0003, -0.04, 0.04)
	var target_pos = Vector3(bob_x + sway_x, bob_y + sway_y, 0.0)
	_sway_offset = _sway_offset.lerp(target_pos, delta * 8.0)
	
	# Target rotation sway
	var rot_z = clampf(-_mouse_delta.x * 0.03, -4.0, 4.0)
	var rot_x = clampf(-_mouse_delta.y * 0.03, -3.0, 3.0)
	_sway_rotation = _sway_rotation.lerp(Vector3(rot_x, 0.0, rot_z), delta * 8.0)
	
	_axe_sway_pivot.position = _sway_offset
	_axe_sway_pivot.rotation_degrees = _sway_rotation
	
	# Decay mouse delta
	_mouse_delta = _mouse_delta.lerp(Vector2.ZERO, delta * 12.0)
	
	# Camera shake decay
	if _camera_shake > 0.0:
		_camera_shake = maxf(0.0, _camera_shake - delta * 20.0)
		_camera_pivot.rotation.x = _camera_pitch + deg_to_rad(_camera_shake)

func _play_footstep(delta: float, current_speed: float) -> void:
	if not is_on_floor():
		return
	_step_timer += delta * (current_speed / walk_speed)
	if _step_timer >= 0.52:
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
	if _prompt_label == null:
		return
		
	var target_text = ""
	var is_interactable = false
	
	# 1. Check center RayCast3D
	if _raycast and _raycast.is_colliding():
		var collider = _raycast.get_collider()
		if collider:
			if collider.has_method("get_interact_text"):
				target_text = collider.get_interact_text()
				is_interactable = true
			elif collider.get_parent() and collider.get_parent().has_method("get_interact_text"):
				target_text = collider.get_parent().get_interact_text()
				is_interactable = true
				
	# 2. If raycast misses slightly, check forward cone for nearby choppable tree
	if target_text == "":
		var near_tree = _find_nearest_choppable_in_front(3.2)
		if near_tree and near_tree.has_method("get_interact_text"):
			target_text = near_tree.get_interact_text()
			is_interactable = true
			
	# If target is a tree but the active tool is not an axe:
	if is_interactable and target_text.contains("Рубить") and active_hotbar_slot != 0:
		target_text = target_text.replace("[ЛКМ] Рубить", "[1] Возьмите топор")
		
	_prompt_label.text = target_text
	_update_crosshair(is_interactable)

func _update_crosshair(highlighted: bool) -> void:
	if _crosshair_ring:
		_crosshair_ring.visible = highlighted
	if _crosshair_dot:
		_crosshair_dot.color = Color(1.0, 0.88, 0.2, 1.0) if highlighted else Color(1.0, 1.0, 1.0, 0.7)

func _try_chop() -> void:
	if not _can_chop or _is_inventory_open or not _is_active or active_hotbar_slot != 0 or get_tree().paused:
		return
	_can_chop = false
	_play_swing_animation_and_sound()

func _apply_chop_impact() -> void:
	# Damage, particles and the ONE impact sound happen at blade contact, not
	# on a separate timer that can outlive tool switches or cancelled swings.
	if not is_inside_tree() or not _is_active or _is_inventory_open or active_hotbar_slot != 0 or get_tree().paused:
		return
	var target_tree = null
	var hit_point = Vector3.ZERO
	
	# 1. Center RayCast check
	if _raycast:
		_raycast.force_raycast_update()
		if _raycast.is_colliding():
			var collider = _raycast.get_collider()
			if collider != null:
				if collider.has_method("hit"):
					target_tree = collider
					hit_point = _raycast.get_collision_point()
				elif collider.get_parent() != null and collider.get_parent().has_method("hit"):
					target_tree = collider.get_parent()
					hit_point = _raycast.get_collision_point()
					
	# 2. Forward proximity cone fallback (ensures chops within 3.2m always register)
	if target_tree == null:
		var near_tree = _find_nearest_choppable_in_front(3.2)
		if near_tree != null and near_tree.has_method("hit"):
			target_tree = near_tree
			# Preserve the player-facing side even when the center ray misses.
			var toward_player: Vector3 = global_position - target_tree.global_position
			toward_player.y = 0.0
			hit_point = target_tree.global_position + toward_player.normalized() * 0.25 + Vector3(0.0, 1.3, 0.0)
			
	# Execute hit
	if target_tree != null:
		target_tree.hit(1, hit_point, global_position)
		_trigger_hit_feedback()
		
func _find_nearest_choppable_in_front(max_dist: float) -> Node:
	var choppables = get_tree().get_nodes_in_group("choppable_trees")
	if choppables.is_empty():
		return null
		
	var cam_forward = -_camera.global_transform.basis.z
	var cam_pos = _camera.global_position
	var best_node: Node = null
	var best_dist: float = max_dist
	
	for node in choppables:
		if not is_instance_valid(node) or not (node is Node3D) or not node.has_method("hit"):
			continue
		var to_node = (node as Node3D).global_position - cam_pos
		var dist_h = Vector2(to_node.x, to_node.z).length()
		if dist_h <= max_dist and to_node.dot(cam_forward) > 0.0:
			var dir = to_node.normalized()
			if dir.dot(cam_forward) > 0.45: # within ~60 degree forward cone
				if dist_h < best_dist:
					best_dist = dist_h
					best_node = node
					
	return best_node

func _play_swing_animation_and_sound() -> void:
	if _axe_anim_pivot == null:
		_can_chop = true
		return
	if _chop_tween and _chop_tween.is_valid():
		_chop_tween.kill()
	var windup := AXE_WINDUP_POS
	var windup_rot := AXE_WINDUP_ROT
	var contact := AXE_CONTACT_POS
	var contact_rot := AXE_CONTACT_ROT
	var follow := AXE_FOLLOW_POS
	var follow_rot := AXE_FOLLOW_ROT
	_chop_tween = create_tween().set_speed_scale(AXE_ANIMATION_SPEED)
	# Deliberate shoulder lift, then accelerated circular downstroke.
	_chop_tween.tween_method(_sample_axe_arc.bind(AXE_REST_POS, Vector3(0.42, -0.20, -0.39), windup, AXE_REST_ROT, windup_rot), 0.0, 1.0, AXE_WINDUP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_chop_tween.tween_callback(_play_axe_whoosh)
	_chop_tween.tween_method(_sample_axe_arc.bind(windup, Vector3(0.33, 0.04, -0.59), contact, windup_rot, contact_rot), 0.0, 1.0, AXE_STROKE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_chop_tween.tween_callback(_apply_chop_impact)
	_chop_tween.tween_method(_sample_axe_arc.bind(contact, Vector3(-0.025, -0.34, -0.54), follow, contact_rot, follow_rot), 0.0, 1.0, 0.055).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_chop_tween.tween_interval(0.025)
	_chop_tween.tween_method(_sample_axe_arc.bind(follow, Vector3(0.30, -0.46, -0.36), AXE_REST_POS, follow_rot, AXE_REST_ROT), 0.0, 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_chop_tween.tween_interval(maxf(0.0, _chop_cooldown - 0.48))
	_chop_tween.tween_callback(func(): _can_chop = true)

func _sample_axe_arc(t: float, start: Vector3, control: Vector3, finish: Vector3, start_rot: Vector3, finish_rot: Vector3) -> void:
	var u := 1.0 - t
	_axe_anim_pivot.position = u * u * start + 2.0 * u * t * control + t * t * finish
	_axe_anim_pivot.rotation_degrees = start_rot.lerp(finish_rot, t)
	if _axe_arm_rig:
		_axe_arm_rig.update_pose()

func _play_axe_whoosh() -> void:
	var sound := "res://assets/sounds/level_01/axe/axe_swing_real_01.wav"
	if ResourceLoader.exists(sound) and _audio_swing:
		_audio_swing.stream = load(sound)
		_audio_swing.pitch_scale = 1.08
		_audio_swing.play()

func _cancel_chop() -> void:
	if _chop_tween and _chop_tween.is_valid():
		_chop_tween.kill()
	_chop_tween = null
	_can_chop = true
	_is_lmb_held = false
	if _audio_swing:
		_audio_swing.stop()
	if _axe_anim_pivot:
		_axe_anim_pivot.position = AXE_REST_POS
		_axe_anim_pivot.rotation_degrees = AXE_REST_ROT
	if _axe_arm_rig:
		_axe_arm_rig.update_pose()

func _trigger_hit_feedback() -> void:
	# The tree owns the impact sound. Do not layer a second player thud on it.
	_camera_shake = 1.2

func _try_interact() -> void:
	if _is_inventory_open:
		return
		
	# 1. Raycast check for pickup
	if _raycast and _raycast.is_colliding():
		var collider = _raycast.get_collider()
		if collider and collider.has_method("survival_interact"):
			collider.survival_interact()
			return
		if collider is LogPickupScript:
			_collect_log(collider)
			return
		elif collider and collider.get_parent() is LogPickupScript:
			_collect_log(collider.get_parent())
			return
			
	# 2. Proximity pickup fallback for nearby logs
	var logs = get_tree().get_nodes_in_group("pickup_logs")
	for l in logs:
		if is_instance_valid(l) and (l is Node3D):
			if global_position.distance_to((l as Node3D).global_position) < 3.0:
				if l.has_method("pickup"):
					_collect_log(l)
					return

func _collect_log(log_node: Node) -> void:
	# Never delete a world item before verifying backpack capacity.
	var has_room = false
	for slot in inventory_slots:
		if slot == null or (slot.get("type")=="log" and slot.get("species")==log_node.species and slot.get("count",0)<MAX_STACK):
			has_room = true
			break
	if not has_room:
		_show_tool_banner("Рюкзак заполнен: освободите ячейку")
		return
	var item_data = log_node.pickup()
	_add_to_backpack(item_data)
	_play_ui_sound("res://assets/sounds/level_01/props/log_pickup.wav")

func _play_ui_sound(path: String) -> void:
	if ResourceLoader.exists(path):
		_audio_ui.stream = load(path)
		_audio_ui.play()

# --- INVENTORY & STACKING LOGIC ---

func _add_to_backpack(item: Dictionary) -> void:
	var sp = item.get("species", "birch").to_lower()
	var info = SPECIES_ITEM_DATA.get(sp, SPECIES_ITEM_DATA["birch"])
	var weight = item.get("weight", info["unit_weight"])
	
	# 1. Look for existing stack of same species with room (< MAX_STACK)
	var target_slot_idx = -1
	for i in range(MAX_SLOTS):
		var s = inventory_slots[i]
		if s != null and s.get("type")=="log" and s.get("species") == sp and s.get("count", 0) < MAX_STACK:
			target_slot_idx = i
			break
			
	# 2. If no existing stack, find first empty slot
	if target_slot_idx == -1:
		for i in range(MAX_SLOTS):
			if inventory_slots[i] == null:
				target_slot_idx = i
				break
				
	if target_slot_idx != -1:
		if inventory_slots[target_slot_idx] != null:
			inventory_slots[target_slot_idx]["count"] += 1
		else:
			inventory_slots[target_slot_idx] = {
				"id": "log_" + sp,
				"type": "log",
				"species": sp,
				"name": info["name"],
				"unit_weight": info["unit_weight"],
				"count": 1,
				"description": info["desc"],
				"burn_time": info["burn_time"],
				"heat": info["heat"],
				"color": info["color"]
			}
			
	if target_slot_idx == -1:
		return
	# Always keep backpack_weight and backpack_items updated for tests/HUD
	backpack_weight += weight
	backpack_items.append(item)
	
	_update_inventory_hud()
	if _is_inventory_open:
		_refresh_inventory_ui()

func drop_selected_item(drop_all: bool = false) -> void:
	if _selected_slot_index < 0 or _selected_slot_index >= MAX_SLOTS:
		return
	drop_item(_selected_slot_index, drop_all)

func drop_item(slot_idx: int, drop_all: bool = false) -> void:
	if is_instance_valid(survival) and not survival.job.is_empty(): return
	if slot_idx < 0 or slot_idx >= MAX_SLOTS or inventory_slots[slot_idx] == null:
		return
		
	var slot = inventory_slots[slot_idx]
	if slot.get("type") != "log" and is_instance_valid(survival):
		var amount = int(slot["count"]) if drop_all else 1
		var item = slot.duplicate(true)
		item["count"] = 1
		if survival.Items.transact(self,{slot["id"]:amount},[],slot_idx):
			for i in amount:
				var forward = -_camera.global_basis.z
				forward.y = 0
				var pos = global_position + forward.normalized()*1.3 + Vector3(i*0.15,0.1,0)
				var q = PhysicsRayQueryParameters3D.create(pos+Vector3.UP*2,pos-Vector3.UP*3,1)
				var hit = get_world_3d().direct_space_state.intersect_ray(q)
				if not hit.is_empty():pos=hit.position
				survival.drop_resource(item,pos)
		return
	var sp = slot.get("species", "birch")
	var unit_w = slot.get("unit_weight", 4.0)
	var to_drop = slot["count"] if drop_all else 1
	
	slot["count"] -= to_drop
	backpack_weight = maxf(0.0, backpack_weight - unit_w * to_drop)
	
	# Remove corresponding records from backpack_items array
	var removed = 0
	for i in range(backpack_items.size() - 1, -1, -1):
		if backpack_items[i].get("species") == sp:
			backpack_items.remove_at(i)
			removed += 1
			if removed >= to_drop:
				break
				
	# Spawn physical log pickups in world in front of player
	var forward = -_camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.01 else Vector3.FORWARD
	
	var log_script = load("res://scripts/props/LogPickup.gd")
	for i in range(to_drop):
		var log_node = RigidBody3D.new()
		log_node.set_script(log_script)
		get_parent().add_child(log_node)
		
		var drop_pos = global_position + forward * (1.2 + float(i) * 0.4) + Vector3(randf_range(-0.3, 0.3), 0.6, randf_range(-0.3, 0.3))
		log_node.global_position = drop_pos
		log_node.init_log(sp, unit_w)
		log_node.apply_impulse(forward * 2.5 + Vector3(0, 1.2, 0))
		
	if slot["count"] <= 0:
		inventory_slots[slot_idx] = null
		if _selected_slot_index == slot_idx:
			_selected_slot_index = -1
			
	_play_ui_sound("res://assets/sounds/level_01/ui/ui_pickup.wav")
	_update_inventory_hud()
	_refresh_inventory_ui()

func _update_inventory_hud() -> void:
	var total_logs = 0
	for s in inventory_slots:
		if s != null:
			total_logs += s.get("count", 0)
			
	if _backpack_label:
		_backpack_label.text = "Рюкзак: %.1f / %.1f кг (%d предметов)" % [
			backpack_weight, max_backpack_kg, total_logs
		]

# --- INVENTORY UI REFRESH & INTERACTION ---

func _on_slot_clicked(slot_idx: int) -> void:
	_selected_slot_index = slot_idx
	_backpack_ui.show_selection()
	_play_ui_sound("res://assets/sounds/level_01/ui/ui_click.wav")
	_refresh_inventory_ui()

func _refresh_inventory_ui() -> void:
	if not _inv_layer or not _inv_layer.visible:
		return
		
	# 1. Update Weight Meter
	_inv_weight_label.text = "ВЕС ГРУЗА: %.1f / %.1f кг" % [backpack_weight, max_backpack_kg]
	_inv_weight_bar.value = backpack_weight
	
	var bar_fill = StyleBoxFlat.new()
	bar_fill.corner_radius_top_left = 3
	bar_fill.corner_radius_top_right = 3
	bar_fill.corner_radius_bottom_left = 3
	bar_fill.corner_radius_bottom_right = 3
	
	if backpack_weight > max_backpack_kg:
		bar_fill.bg_color = Color(0.95, 0.25, 0.25) # Danger red
		_inv_overweight_warning.text = "ВНИМАНИЕ: ПЕРЕГРУЗ (Скорость -30%)"
	elif backpack_weight >= max_backpack_kg * 0.8:
		bar_fill.bg_color = Color(0.95, 0.70, 0.20) # Warning amber
		_inv_overweight_warning.text = "Почти заполнен"
	else:
		bar_fill.bg_color = Color(0.28, 0.72, 0.52) # Calm green
		_inv_overweight_warning.text = ""
	_inv_weight_bar.add_theme_stylebox_override("fill", bar_fill)
	
	# 2. Update 16 Slots
	for i in range(MAX_SLOTS):
		var btn = _inv_slot_buttons[i]
		var item = inventory_slots[i]
		var is_selected = (i == _selected_slot_index)
		
		# Styling for slot button
		var sb = StyleBoxFlat.new()
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		sb.content_margin_left = 6
		sb.content_margin_top = 6
		sb.content_margin_right = 6
		sb.content_margin_bottom = 6
		
		if is_selected:
			sb.border_width_left = 2
			sb.border_width_top = 2
			sb.border_width_right = 2
			sb.border_width_bottom = 2
			sb.border_color = Color(1.0, 0.85, 0.25, 1.0) # Golden selection
			sb.bg_color = Color(0.16, 0.19, 0.24, 0.95)
		else:
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			sb.border_color = Color(0.25, 0.30, 0.35, 0.6)
			sb.bg_color = Color(0.10, 0.12, 0.15, 0.85)
			
		btn.add_theme_stylebox_override("normal", sb)
		
		var hover_sb = sb.duplicate()
		hover_sb.border_color = Color(0.6, 0.8, 1.0, 0.9) # Ice-blue hover
		btn.add_theme_stylebox_override("hover", hover_sb)
		
		if item != null:
			var sp_name = item.get("name", "Полено").replace(" полено", "").to_upper()
			var count = item.get("count", 1)
			var total_w = float(count) * item.get("unit_weight", 4.0)
			btn.text = "%s\nx%d\n(%.1f кг)" % [sp_name, count, total_w]
			btn.add_theme_color_override("font_color", item.get("color", Color.WHITE))
			btn.add_theme_font_size_override("font_size", roundi(14 * _backpack_ui.ui_scale))
		else:
			btn.text = "—"
			btn.add_theme_color_override("font_color", Color(0.3, 0.35, 0.4))
			btn.add_theme_font_size_override("font_size", roundi(14 * _backpack_ui.ui_scale))
			
	# 3. Update Inspector Panel
	if _selected_slot_index >= 0 and _selected_slot_index < MAX_SLOTS and inventory_slots[_selected_slot_index] != null:
		var item = inventory_slots[_selected_slot_index]
		_inv_empty_inspector_label.visible = false
		_inv_inspector_box.visible = true
		
		_inv_details_title.text = item.get("name", "Предмет")
		_inv_details_title.add_theme_color_override("font_color", item.get("color", Color(1.0, 0.9, 0.4)))
		_inv_details_category.text = "Тип: " + {"log":"Бревно", "firewood":"Топливо", "brush":"Растопка", "stone":"Материал", "camp_kit":"Набор для размещения"}.get(item.get("type", ""), "Материал")
		
		var count = item.get("count", 1)
		var unit_w = item.get("unit_weight", 4.0)
		var total_w = float(count) * unit_w
		_inv_details_stats.text = "В стаке: x%d шт.\nВес за шт.: %.1f кг\nОбщий вес: %.1f кг\nВремя горения: %s\nТеплоотдача: %s" % [
			count, unit_w, total_w, item.get("burn_time", "—"), item.get("heat", "—")
		]
		_inv_details_desc.text = item.get("description", "")
		_inv_btn_drop_one.text = "Выбросить 1 шт. (%.1f кг)" % unit_w
		_inv_btn_drop_all.text = "Выбросить весь стак (%d шт., %.1f кг)" % [count, total_w]
	else:
		_inv_empty_inspector_label.visible = true
		_inv_inspector_box.visible = false

	if is_instance_valid(_backpack_ui): _backpack_ui.refresh_actions()


func _connect_settings_signals() -> void:
	var sm = SettingsManagerScript.get_instance()
	if not sm.controls_changed.is_connected(_apply_player_settings):
		sm.controls_changed.connect(_apply_player_settings)
	if not sm.gameplay_changed.is_connected(_apply_player_settings):
		sm.gameplay_changed.connect(_apply_player_settings)
	_apply_player_settings()

func _apply_player_settings() -> void:
	var sm = SettingsManagerScript.get_instance()
	_base_fov = float(sm.get_setting("controls", "fov", 75.0))
	_camera_bobbing_enabled = bool(sm.get_setting("controls", "camera_bobbing", true))
	_hud_enabled = bool(sm.get_setting("gameplay", "hud_visible", true))
	var bindings: Dictionary = sm.get_setting("controls", "keybindings", {})
	for index in range(_hotbar_hotkey_labels.size()):
		_hotbar_hotkey_labels[index].text = OS.get_keycode_string(int(bindings.get("hotbar_%d" % (index + 1), KEY_1 + index)))
	if _camera:
		_camera.fov = _base_fov
	if _hud_layer:
		_hud_layer.visible = _is_active and _hud_enabled

func _event_matches_action(event: InputEventKey, action: String) -> bool:
	return SettingsManagerScript.get_instance().event_matches_action(event, action)

func _is_action_down(action: String) -> bool:
	return SettingsManagerScript.get_instance().is_binding_pressed(action)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		_cancel_chop()
