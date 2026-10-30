extends Node
class_name SaveManager

# SaveManager: Production-grade persistence, slot management and auto-saves for Deadly Night

signal save_started(slot_id)
signal save_completed(slot_id, success)
signal load_started(slot_id)
signal load_completed(slot_id, success)
signal save_deleted(slot_id)
signal autosave_triggered(slot_id)

const SettingsManagerScript = preload("res://scripts/core/SettingsManager.gd")

const SAVES_DIR = "user://saves"
const MANIFEST_PATH = "user://saves/manifest.json"
const SAVE_VERSION = 1

const MAX_MANUAL_SLOTS = 5
const MAX_AUTOSAVE_SLOTS = 3

var current_slot_id: String = "slot_1"
var current_playthrough_name: String = "Выживание"
var current_difficulty: String = "traveler" # explorer, traveler, survivor, custom

var _pending_load_payload: Dictionary = {}
var _autosave_timer: float = 0.0
var _session_playtime: float = 0.0
var _is_saving_in_progress: bool = false
var _rolling_autosave_idx: int = 1

static var _instance: Node = null
var _initialized: bool = false
var last_save_profile:Dictionary={}
# Deterministic failure injection only used by the acceptance suite.
var _test_write_failure_stage:=""


static func get_instance():
	if not is_instance_valid(_instance):
		_instance = load("res://scripts/core/SaveManager.gd").new()
		var main_loop = Engine.get_main_loop()
		if main_loop and main_loop is SceneTree and main_loop.root:
			main_loop.root.call_deferred("add_child", _instance)
		_instance._ready()
	return _instance

func _scene_tree() -> SceneTree:
	# A freshly acquired singleton is deferred into root during scene readiness.
	# Reads/loads must also work in that short interval, including cold startup.
	return get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree

func _enter_tree() -> void:
	if _instance == null:
		_instance = self

func _ready() -> void:
	if _initialized:
		return
	_initialized = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_saves_dir()

func _process(delta: float) -> void:
	_session_playtime += delta
	
	# Autosave check during active gameplay (if not paused and tree contains player)
	if not _scene_tree().paused and _is_gameplay_active():
		var interval_min = 5
		if SettingsManagerScript.get_instance():
			interval_min = SettingsManagerScript.get_instance().get_setting("gameplay", "autosave_interval_min", 5)
			
		if interval_min > 0:
			_autosave_timer += delta
			if _autosave_timer >= float(interval_min * 60):
				_autosave_timer = 0.0
				trigger_autosave("Периодическое выживание")

func _is_gameplay_active() -> bool:
	var current = _scene_tree().current_scene
	if current and (current.name == "MapViewer" or current.has_node("Player")):
		return true
	return false

func _ensure_saves_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		var err = DirAccess.make_dir_recursive_absolute(SAVES_DIR)
		if err != OK:
			printerr("[SaveManager] Failed to create directory: %s (error %d)" % [SAVES_DIR, err])

func has_any_saves() -> bool:
	var manifest = _load_manifest()
	return manifest.get("slots", {}).size() > 0

func get_latest_save_slot_id() -> String:
	var manifest = _load_manifest()
	var slots = manifest.get("slots", {})
	if slots.is_empty():
		return ""
		
	var best_slot = ""
	var best_time = -1
	for s_id in slots.keys():
		var s_info = slots[s_id]
		var t = s_info.get("timestamp", 0)
		if t > best_time:
			best_time = t
			best_slot = s_id
	return best_slot

func list_save_slots() -> Array[Dictionary]:
	var manifest = _load_manifest()
	var slots = manifest.get("slots", {})
	var result: Array[Dictionary] = []
	
	for s_id in slots.keys():
		var d = slots[s_id].duplicate()
		d["slot_id"] = s_id
		result.append(d)
		
	# Sort descending by timestamp (newest first)
	result.sort_custom(func(a, b): return a.get("timestamp", 0) > b.get("timestamp", 0))
	return result

func get_all_save_slots() -> Array[String]:
	var manifest = _load_manifest()
	var res: Array[String] = []
	for k in manifest.get("slots", {}).keys():
		res.append(str(k))
	return res

func get_slot_metadata(slot_id: String) -> Dictionary:
	var manifest = _load_manifest()
	var slots = manifest.get("slots", {})
	return slots.get(slot_id, {})

func save_game(slot_id: String = "", save_type: String = "manual", custom_name: String = "") -> bool:
	if slot_id=="":slot_id=current_slot_id
	if not _valid_slot_id(slot_id):return false
	if _is_saving_in_progress:
		print("[SaveManager] Save already in progress. Skipping.")
		return false
		
	_is_saving_in_progress = true
	save_started.emit(slot_id)
	
	if slot_id == "":
		slot_id = current_slot_id
	else:
		current_slot_id = slot_id
		
	_ensure_saves_dir()
	
	var started:=Time.get_ticks_usec()
	var mark:=started
	var memory_before:=OS.get_static_memory_usage()
	last_save_profile={}
	# Find player and world in active scene
	var scene_root = _scene_tree().current_scene
	var player_node: Node = null
	var world_node: Node = null
	
	if scene_root:
		player_node = scene_root.get_node_or_null("Player")
		world_node = scene_root.get_node_or_null("WorldMap")
		
	var p_data = {}
	var p_pos = Vector3(-900.0, 26.0, 1100.0)
	var p_rot = 0.0
	var p_pitch = 0.0
	var p_weight = 0.0
	var p_slots = []
	var p_tool = 0
	
	if player_node != null and is_instance_valid(player_node):
		p_pos = player_node.global_position
		p_rot = player_node.rotation.y
		p_pitch = player_node.get("_camera_pitch") if player_node.get("_camera_pitch") != null else 0.0
		p_weight = player_node.get("backpack_weight") if player_node.get("backpack_weight") != null else 0.0
		p_slots = player_node.inventory_slots.duplicate(true) if player_node.get("inventory_slots") != null else []
		p_tool = player_node.get("active_hotbar_slot") if player_node.get("active_hotbar_slot") != null else 0
		
	p_data = {
		"position": [p_pos.x, p_pos.y, p_pos.z],
		"rotation_y": p_rot,
		"camera_pitch": p_pitch,
		"backpack_weight": p_weight,
		"active_hotbar_slot": p_tool,
		"belt_items": player_node.belt_items.duplicate() if player_node != null else ["", "", ""],
		"inventory_slots": p_slots
	}
	
	last_save_profile["player_us"]=Time.get_ticks_usec()-mark;mark=Time.get_ticks_usec()
	var survival_node = scene_root.get_node_or_null("SurvivalWorld") if scene_root else null
	# World Data
	var TreeChoppableClass = load("res://scripts/props/TreeChoppable.gd")
	var felled_trees = {}
	if TreeChoppableClass != null and TreeChoppableClass.felled_tree_ids != null:
		felled_trees = TreeChoppableClass.compact_felled_registry()
		
	last_save_profile["voxel_us"]=Time.get_ticks_usec()-mark;mark=Time.get_ticks_usec()
	# Collect dropped logs
	var dropped_logs = []
	var logs_nodes = _scene_tree().get_nodes_in_group("pickup_logs")
	for l in logs_nodes:
		if is_instance_valid(l) and (l is Node3D):
			dropped_logs.append({
				"species": l.get("species") if l.get("species") != null else "birch",
				"weight": l.get("weight_kg") if l.get("weight_kg") != null else 4.0,
				"position": [(l as Node3D).global_position.x, (l as Node3D).global_position.y, (l as Node3D).global_position.z]
			})
			
	last_save_profile["items_us"]=Time.get_ticks_usec()-mark;mark=Time.get_ticks_usec()
	var w_data = {
		"felled_tree_ids": felled_trees,
		"damaged_trees": TreeChoppableClass.damaged_tree_states.duplicate(true),
		"dropped_logs": dropped_logs,
		"survival": survival_node.export_state() if survival_node else {}
	}
	
	last_save_profile["world_us"]=Time.get_ticks_usec()-mark;mark=Time.get_ticks_usec()
	var pt_name = custom_name if custom_name != "" else current_playthrough_name
	var now = Time.get_datetime_dict_from_system()
	var datetime_str = "%04d-%02d-%02d %02d:%02d" % [now["year"], now["month"], now["day"], now["hour"], now["minute"]]
	var unix_timestamp = int(Time.get_unix_time_from_system())
	
	var header = {
		"save_version": SAVE_VERSION,
		"slot_id": slot_id,
		"playthrough_name": pt_name,
		"save_type": save_type,
		"difficulty": current_difficulty,
		"timestamp": unix_timestamp,
		"datetime_str": datetime_str,
		"playtime_seconds": _session_playtime,
		"location_name": _get_location_name_near(p_pos),
		"coordinates": [p_pos.x, p_pos.y, p_pos.z],
		"backpack_weight": p_weight,
		"items_count": _count_inventory_items(p_slots)
	}
	
	var payload = {
		"header": header,
		"player": p_data,
		"world": w_data
	}
	
	last_save_profile["assemble_us"]=Time.get_ticks_usec()-mark;mark=Time.get_ticks_usec()
	# Compact JSON removes formatting cost; canonical tree IDs remove triple copies.
	var slot_file_path="%s/%s.json"%[SAVES_DIR,slot_id]
	var json_str=JSON.stringify(payload)
	last_save_profile["serialize_us"]=Time.get_ticks_usec()-mark;mark=Time.get_ticks_usec()
	last_save_profile["memory_delta"]=OS.get_static_memory_usage()-memory_before
	last_save_profile["bytes"]=json_str.to_utf8_buffer().size()
	last_save_profile["trees"]=felled_trees.size()
	last_save_profile["logs"]=dropped_logs.size()
	var success:=_atomic_write(slot_file_path,json_str)
	last_save_profile["disk_us"]=Time.get_ticks_usec()-mark;mark=Time.get_ticks_usec()
	if success:success=_update_manifest(slot_id,header)
	last_save_profile["metadata_us"]=Time.get_ticks_usec()-mark
	last_save_profile["total_us"]=Time.get_ticks_usec()-started
	_is_saving_in_progress=false
	save_completed.emit(slot_id,success)
	return success

func _valid_slot_id(id:String) -> bool:
	if id.is_empty() or id.length()>80:return false
	for c in id:
		if not (c in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"):return false
	return true

func _atomic_write(path:String,text:String) -> bool:
	# Old slot is never removed first. A verified temporary file is promoted via
	# rename (replace); an independently readable previous generation remains .bak.
	var tmp:=path+".tmp"
	if _test_write_failure_stage=="open":return false
	var f=FileAccess.open(tmp,FileAccess.WRITE)
	if f==null:return false
	f.store_string(text);f.flush()
	var good:=f.get_error()==OK and f.get_length()==text.to_utf8_buffer().size()
	f.close()
	if not good or _test_write_failure_stage=="write":return false
	# Check bytes read back, not just a successful open/rename return code.
	f=FileAccess.open(tmp,FileAccess.READ)
	if f==null:return false
	good=f.get_length()==text.to_utf8_buffer().size() and f.get_as_text()==text
	f.close()
	if not good:return false
	if FileAccess.file_exists(path):
		var previous=JSON.parse_string(FileAccess.get_file_as_string(path))
		if previous is Dictionary:
			if DirAccess.copy_absolute(path,path+".bak")!=OK:return false
	if _test_write_failure_stage=="rename":return false
	return DirAccess.rename_absolute(tmp,path)==OK

func _read_save_file(path:String) -> Dictionary:
	for candidate in [path,path+".bak"]:
		var f=FileAccess.open(candidate,FileAccess.READ)
		if f==null:continue
		var parsed=JSON.parse_string(f.get_as_text());f.close()
		if parsed is Dictionary and parsed.get("header") is Dictionary and parsed.get("world") is Dictionary and parsed.get("player") is Dictionary:
			return parsed
	return {}

func trigger_autosave(context_desc: String = "") -> bool:
	var slot_id = "autosave_%d" % _rolling_autosave_idx
	_rolling_autosave_idx = (_rolling_autosave_idx % MAX_AUTOSAVE_SLOTS) + 1
	var auto_name = "Автосохранение (%s)" % (context_desc if context_desc != "" else "Мир")
	var success = save_game(slot_id, "auto", auto_name)
	if success:
		autosave_triggered.emit(slot_id)
	return success

func load_game(slot_id: String) -> bool:
	if not _valid_slot_id(slot_id):return false
	load_started.emit(slot_id)
	var data:=_read_save_file("%s/%s.json"%[SAVES_DIR,slot_id])
	if data.is_empty():
		load_completed.emit(slot_id,false);return false
	if int(data.header.get("save_version",1))>SAVE_VERSION:
		load_completed.emit(slot_id,false);return false

	_pending_load_payload = data
	current_slot_id = slot_id
	var hdr = data.get("header", {})
	current_playthrough_name = hdr.get("playthrough_name", "Выживание")
	current_difficulty = hdr.get("difficulty", "traveler")
	_session_playtime = hdr.get("playtime_seconds", 0.0)
	
	# Transition to MapViewer if not already in game
	var current_scene = _scene_tree().current_scene
	if current_scene == null and _scene_tree().root:
		current_scene = _scene_tree().root.get_node_or_null("MapViewer")
		
	var target_name = "MineInterior" if data.get("world",{}).get("survival",{}).get("location", "forest") == "mine" else "MapViewer"
	load("res://scripts/survival/SurvivalWorld.gd").travel.clear()
	if current_scene == null or current_scene.name != target_name:
		print("[SaveManager] Changing scene to %s for save payload application..." % target_name)
		_scene_tree().change_scene_to_file("res://scenes/mine/MineInterior.tscn" if target_name=="MineInterior" else "res://scenes/viewer/MapViewer.tscn")
		# Hook deferred application when scene loads
		call_deferred("_apply_pending_load_when_ready")
	else:
		_apply_loaded_state(_pending_load_payload)
		_pending_load_payload.clear()
		load_completed.emit(slot_id, true)
		
	return true

func _apply_pending_load_when_ready() -> void:
	# Await 3 physics frames for MapViewer, Player, and WorldMap to initialize
	for i in range(3):
		await _scene_tree().process_frame
		
	if not _pending_load_payload.is_empty():
		_apply_loaded_state(_pending_load_payload)
		load_completed.emit(current_slot_id, true)
		_pending_load_payload.clear()

func _apply_loaded_state(payload: Dictionary) -> void:
	var scene_root = _scene_tree().current_scene
	if scene_root == null and _scene_tree().root:
		scene_root = _scene_tree().root.get_node_or_null("MapViewer")
	if scene_root == null:
		return
		
	var player_node = scene_root.get_node_or_null("Player")
	var world_node = scene_root.get_node_or_null("WorldMap")
	
	# 1. Apply World Data (felled trees and logs)
	var w_data = payload.get("world", {})
	var TreeChoppableClass = load("res://scripts/props/TreeChoppable.gd")
	if TreeChoppableClass != null:
		TreeChoppableClass.felled_tree_ids = w_data.get("felled_tree_ids", {}).duplicate(true)
		TreeChoppableClass.damaged_tree_states = w_data.get("damaged_trees", {}).duplicate(true)
		
	# Clean up any existing pickup logs before restoring
	for l in _scene_tree().get_nodes_in_group("pickup_logs"):
		if is_instance_valid(l):
			l.queue_free()
			
	# Re-spawn saved dropped logs
	var log_script = load("res://scripts/props/LogPickup.gd")
	var dropped_logs = w_data.get("dropped_logs", [])
	for l_data in dropped_logs:
		var pos_arr = l_data.get("position", [0, 0, 0])
		var sp = l_data.get("species", "birch")
		var w = l_data.get("weight", 4.0)
		var log_node = RigidBody3D.new()
		log_node.set_script(log_script)
		scene_root.add_child(log_node)
		log_node.global_position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
		log_node.init_log(sp, w)
		
	# 2. Apply Player Data
	var p_data = payload.get("player", {})
	if player_node != null and is_instance_valid(player_node):
		var pos_arr = p_data.get("position", [-900.0, 26.0, 1100.0])
		player_node.global_position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
		player_node.velocity=Vector3.ZERO
		player_node._fall_speed=0.0
		player_node.rotation.y = p_data.get("rotation_y", 0.0)
		if player_node.get("_camera_pitch") != null:
			player_node._camera_pitch = p_data.get("camera_pitch", 0.0)
			if player_node.get("_camera_pivot") != null and player_node._camera_pivot != null:
				player_node._camera_pivot.rotation.x = player_node._camera_pitch
				
		var slots = p_data.get("inventory_slots", [])
		if player_node.get("inventory_slots") != null:
			player_node.inventory_slots = slots.duplicate(true)
			load("res://scripts/survival/SurvivalItems.gd").refresh(player_node)
		if player_node.get("backpack_weight") != null:
			player_node.backpack_weight = p_data.get("backpack_weight", 0.0)
			
		player_node.belt_items = p_data.get("belt_items", ["", "", ""]).duplicate()
		player_node.belt_items.resize(3)
		player_node._refresh_belt_labels()
		var tool_idx = p_data.get("active_hotbar_slot", 0)
		if player_node.has_method("select_hotbar_slot"):
			player_node.select_hotbar_slot(tool_idx)
			
		if player_node.has_method("_refresh_inventory_ui"):
			player_node._refresh_inventory_ui()
		if player_node.has_method("_update_hud_display"):
			player_node._update_hud_display()
			
	var survival_node = scene_root.get_node_or_null("SurvivalWorld")
	if survival_node:
		survival_node.Items.refresh(player_node)
		survival_node.import_state(w_data.get("survival",{}))
	if world_node != null and world_node.has_method("restore_felled_stumps"):
		world_node.reconcile_loaded_world()
	print("[SaveManager] Loaded game state successfully applied to active scene.")

func delete_save(slot_id: String) -> bool:
	if not _valid_slot_id(slot_id):return false
	for suffix in [".json.bak",".json.tmp",".tmp"]:
		if FileAccess.file_exists("%s/%s%s"%[SAVES_DIR,slot_id,suffix]):DirAccess.remove_absolute("%s/%s%s"%[SAVES_DIR,slot_id,suffix])
	var slot_file_path = "%s/%s.json" % [SAVES_DIR, slot_id]
	if FileAccess.file_exists(slot_file_path):
		DirAccess.remove_absolute(slot_file_path)
		
	var manifest = _load_manifest()
	var slots = manifest.get("slots", {})
	if slots.has(slot_id):
		slots.erase(slot_id)
		manifest["slots"] = slots
		_save_manifest(manifest)
		
	print("[SaveManager] Deleted save slot: %s" % slot_id)
	save_deleted.emit(slot_id)
	return true

func start_new_game(slot_id: String, playthrough_name: String, difficulty: String) -> void:
	current_slot_id = slot_id
	current_playthrough_name = playthrough_name
	current_difficulty = difficulty
	_session_playtime = 0.0
	_autosave_timer = 0.0
	
	# Clear static felled trees registry
	var TreeChoppableClass = load("res://scripts/props/TreeChoppable.gd")
	if TreeChoppableClass != null:
		TreeChoppableClass.felled_tree_ids.clear()
		TreeChoppableClass.damaged_tree_states.clear()
	_pending_load_payload.clear()
		
	load("res://scripts/survival/SurvivalWorld.gd").travel.clear()
	# Switch to MapViewer.tscn
	_scene_tree().change_scene_to_file("res://scenes/viewer/MapViewer.tscn")
	
	# Save initial new game state after scene ready
	call_deferred("_save_initial_new_game_state")

func _save_initial_new_game_state() -> void:
	for i in range(3):
		await _scene_tree().process_frame
	save_game(current_slot_id, "manual", current_playthrough_name)

func _load_manifest() -> Dictionary:
	_ensure_saves_dir()
	for path in [MANIFEST_PATH,MANIFEST_PATH+".bak"]:
		var f=FileAccess.open(path,FileAccess.READ)
		if f==null:continue
		var parsed=JSON.parse_string(f.get_as_text());f.close()
		if parsed is Dictionary and parsed.get("slots") is Dictionary:return parsed
	return {"version":SAVE_VERSION,"slots":{}}

func _save_manifest(manifest: Dictionary) -> bool:
	return _atomic_write(MANIFEST_PATH,JSON.stringify(manifest))

func _update_manifest(slot_id: String, header: Dictionary) -> bool:
	var manifest = _load_manifest()
	if not manifest.has("slots"):manifest["slots"]={}
	manifest["slots"][slot_id]=header
	return _save_manifest(manifest)

func _get_location_name_near(pos: Vector3) -> String:
	var pois = {
		"Лагерь на поляне (SPAWN)": Vector3(-900.0, 26.0, 1100.0),
		"Деревянный мост через реку": Vector3(925.0, 66.0, -37.0),
		"Заброшенная шахта": Vector3(1130.0, 144.0, -1210.0),
		"Горная смотровая площадка": Vector3(700.0, 366.0, -1550.0),
		"Лесная хижина": Vector3(0.0, 21.0, -300.0),
		"Зона ветровала": Vector3(-1400.0, 42.0, 600.0)
	}
	var closest_name = "Лесная глушь"
	var min_dist = 250.0
	for p_name in pois.keys():
		var d = pos.distance_to(pois[p_name])
		if d < min_dist:
			min_dist = d
			closest_name = p_name
	return closest_name

func _count_inventory_items(slots: Array) -> int:
	var total = 0
	for s in slots:
		if s != null and s is Dictionary:
			total += s.get("count", 1)
	return total
