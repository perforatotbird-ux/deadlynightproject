extends Node3D
class_name WorldMap

const TreeChoppable = preload("res://scripts/props/TreeChoppable.gd")

@export var load_all_trees: bool = true

var _terrain_root: Node3D = null
var _vegetation_root: Node3D = null
var _pois_root: Node3D = null
var _interactive_root: Node3D = null

# Species meshes cached
var _tree_meshes: Dictionary = {}
# All tree records from JSON
var _all_trees_data: Array = []
var _tutorial_records:Array=[]
# Interactive trees pool
var _interactive_trees: Dictionary = {}

# Dynamic proximity trees
var _dynamic_trees_root: Node3D = null
var _chunk_trees_data: Dictionary = {} # chunk_name -> [tree_data, ...]
var _tree_mmi_index: Dictionary = {}   # tree_id -> { "mm": mm, "index": i, "xform": original_xform }
var _dynamic_trees: Dictionary = {}    # tree_id -> TreeInteractive
var _player_ref: Node3D = null
var _dynamic_update_timer: float = 0.0
var _remnant_requested: Dictionary = {}
var _hidden_tree_ids:Dictionary={}

func _ready() -> void:
	_load_tree_models()
	_load_terrain()
	_load_pois_and_props()
	_load_vegetation()
	_spawn_tutorial_trees()
	_setup_dynamic_trees()

func _load_tree_models() -> void:
	var species = ["birch", "spruce", "beech", "oak"]
	for sp in species:
		var path = preload("res://scripts/core/ExternalModels.gd").tree_path(sp)
		if ResourceLoader.exists(path):
			var scene = load(path)
			if scene:
				var inst = scene.instantiate()
				var mesh_inst = _find_mesh_instance(inst)
				if mesh_inst and mesh_inst.mesh:
					_tree_meshes[sp] = mesh_inst.mesh
				# Cache the resource, not an orphaned scene instance on every menu/game cycle.
				inst.free()

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var res = _find_mesh_instance(child)
		if res:
			return res
	return null

func _load_terrain() -> void:
	_terrain_root = Node3D.new()
	_terrain_root.name = "Terrain"
	add_child(_terrain_root)
	
	var terrain_path = "res://assets/models/terrain/terrain_256_chunks.glb"
	if ResourceLoader.exists(terrain_path):
		print("[WorldMap] Loading 256 terrain chunks...")
		var scene = load(terrain_path)
		if scene:
			var inst = scene.instantiate()
			_terrain_root.add_child(inst)
			
			# Build collision on chunks
			_build_terrain_collisions(inst)
			print("[WorldMap] Terrain chunks loaded successfully.")

func _build_terrain_collisions(root: Node) -> void:
	var count = 0
	var meshes = _collect_all_meshes(root)
	for m_node in meshes:
		# Create trimesh collision for physical interaction
		m_node.create_trimesh_collision()
		for body in m_node.get_children():
			if body is StaticBody3D:body.add_to_group("camp_ground")
		count += 1
	print("[WorldMap] Generated collision for %d terrain chunk meshes." % count)

func _collect_all_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_collect_all_meshes(child))
	return result

func _load_pois_and_props() -> void:
	_pois_root = Node3D.new()
	_pois_root.name = "POIs_and_Props"
	add_child(_pois_root)
	
	# 1. Place Bridge at BRIDGE POI (925, 37, height 65)
	var bridge_path = "res://assets/models/props/bridge_wood.glb"
	if ResourceLoader.exists(bridge_path):
		var b_scene = load(bridge_path)
		if b_scene:
			var bridge = b_scene.instantiate()
			bridge.name = "POI_Bridge"
			# BRIDGE position: X=925, Elevation=65.0, Z=-37
			bridge.position = Vector3(925.0, 65.0, -37.0)
			# Align across the river
			bridge.rotation_degrees = Vector3(0.0, -75.0, 0.0)
			_pois_root.add_child(bridge)
			# Add collision for bridge
			for m in _collect_all_meshes(bridge):
				m.create_trimesh_collision()
				
	# 2. Place Mine Portal at MINE_ADIT (1130, 1210, elevation 143)
	var portal_path = "res://assets/models/mine/mine_portal.glb"
	if ResourceLoader.exists(portal_path):
		var p_scene = load(portal_path)
		if p_scene:
			var portal = p_scene.instantiate()
			portal.name = "POI_MinePortal"
			portal.position = Vector3(1130.0, 143.0, -1210.0)
			# Azimuth facing into the yard (-45 deg)
			portal.rotation_degrees = Vector3(0.0, -45.0, 0.0)
			_pois_root.add_child(portal)
			for m in _collect_all_meshes(portal):
				m.create_trimesh_collision()
				
			# Entrance trigger to Mine Interior
			var trigger = Area3D.new()
			trigger.name = "MineEntranceTrigger"
			trigger.position = Vector3(1130.0, 144.0, -1210.0)
			var t_col = CollisionShape3D.new()
			var t_box = BoxShape3D.new()
			t_box.size = Vector3(2.5, 2.5, 2.5)
			t_col.shape = t_box
			trigger.add_child(t_col)
			trigger.body_entered.connect(_on_mine_entrance_entered)
			_pois_root.add_child(trigger)
				
	# 3. Place Mine Cart & Rails at MINE_YARD (1100, 1180, elevation 140)
	var cart_path = "res://assets/models/mine/mine_cart.glb"
	if ResourceLoader.exists(cart_path):
		var c_scene = load(cart_path)
		if c_scene:
			var cart = c_scene.instantiate()
			cart.position = Vector3(1115.0, 140.5, -1195.0)
			cart.rotation_degrees = Vector3(0.0, -135.0, 0.0)
			_pois_root.add_child(cart)
			for m in _collect_all_meshes(cart):
				m.create_trimesh_collision()
				
	var rails_path = "res://assets/models/mine/mine_rails.glb"
	if ResourceLoader.exists(rails_path):
		var r_scene = load(rails_path)
		if r_scene:
			for ri in range(5):
				var rails = r_scene.instantiate()
				var offset = ri * 2.9
				rails.position = Vector3(1126.0 - offset * 0.707, 141.5 - offset * 0.05, -1206.0 + offset * 0.707)
				rails.rotation_degrees = Vector3(0.0, -135.0, 0.0)
				_pois_root.add_child(rails)
				
	# 4. Spawn 3D Markers & Floating Labels for all 12 POIs from spec.json
	_spawn_poi_markers()

func _spawn_poi_markers() -> void:
	var spec_path = "res://data/spec.json"
	if not FileAccess.file_exists(spec_path):
		return
		
	var file = FileAccess.open(spec_path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
		
	var data = json.get_data()
	var pois = data.get("pois", [])
	
	for poi in pois:
		var pos_arr = poi.get("position", [0, 0, 0])
		# pos_arr: [X, Z_map, Elevation_Y]
		var px = pos_arr[0]
		var py = pos_arr[2]
		var pz = -pos_arr[1] # Flip map Y to Godot Z
		
		var marker = Node3D.new()
		marker.name = "Marker_" + poi.get("id", "POI")
		marker.position = Vector3(px, py, pz)
		_pois_root.add_child(marker)
		
		# Floating Billboard Label3D
		var label = Label3D.new()
		label.text = "[%s]\n%s (%.0fm)" % [poi.get("id"), poi.get("name"), py]
		label.position = Vector3(0.0, 6.0, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 28
		label.modulate = Color(1.0, 0.85, 0.3)
		label.outline_render_priority = 1
		label.outline_modulate = Color.BLACK
		label.outline_size = 6
		label.no_depth_test = true
		marker.add_child(label)
		
		# Visual beacon cylinder/pole
		var pole = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.15
		cyl.bottom_radius = 0.15
		cyl.height = 5.0
		var p_mat = StandardMaterial3D.new()
		p_mat.albedo_color = Color(1.0, 0.8, 0.2, 0.8)
		p_mat.emission_enabled = true
		p_mat.emission = Color(1.0, 0.8, 0.2)
		p_mat.emission_energy_multiplier = 2.0
		pole.mesh = cyl
		pole.material_override = p_mat
		pole.position = Vector3(0.0, 2.5, 0.0)
		marker.add_child(pole)

func _load_vegetation() -> void:
	_vegetation_root = Node3D.new()
	_vegetation_root.name = "Vegetation"
	add_child(_vegetation_root)
	
	var path = "res://data/vegetation_placements.json"
	if not FileAccess.file_exists(path):
		print("[WorldMap] No vegetation_placements.json found!")
		return
		
	print("[WorldMap] Loading vegetation scatter data...")
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		print("[WorldMap] Failed to parse vegetation_placements.json!")
		return
		
	var data = json.get_data()
	var trees = data.get("trees", [])
	_all_trees_data = trees
	print("[WorldMap] Loaded %d tree records from JSON." % trees.size())
	
	# Partition trees by chunk and species
	# chunk_map[chunk_name][species] = [tree_data, ...]
	var chunk_map = {}
	for tree in trees:
		# Exclude tutorial trees from MultiMesh so they can be interactive
		if tree.get("tutorial", false):
			continue
			
		var chunk_name = tree.get("chunk", "Chunk_00_00")
		var sp = tree.get("species", "birch")
		
		if not chunk_map.has(chunk_name):
			chunk_map[chunk_name] = {}
		if not chunk_map[chunk_name].has(sp):
			chunk_map[chunk_name][sp] = []
			
		chunk_map[chunk_name][sp].append(tree)
		
		# Index tree for spatial dynamic activation
		if not _chunk_trees_data.has(chunk_name):
			_chunk_trees_data[chunk_name] = []
		_chunk_trees_data[chunk_name].append(tree)
		
	# Create MultiMeshInstance3D per chunk & species
	var total_instances = 0
	for chunk_name in chunk_map.keys():
		var chunk_node = Node3D.new()
		chunk_node.name = chunk_name
		_vegetation_root.add_child(chunk_node)
		
		var sp_dict = chunk_map[chunk_name]
		for sp in sp_dict.keys():
			var tree_list = sp_dict[sp]
			var mesh = _tree_meshes.get(sp)
			if mesh == null:
				continue
				
			var mmi = MultiMeshInstance3D.new()
			mmi.name = "MMI_" + sp
			
			var mm = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = tree_list.size()
			
			for i in range(tree_list.size()):
				var t = tree_list[i]
				var pos_arr = t["pos"]
				# pos: [X, Z_map, Elevation_Y] -> Godot: [X, Elevation_Y, -Z_map]
				var origin = Vector3(pos_arr[0], pos_arr[2], -pos_arr[1])
				var yaw = deg_to_rad(t.get("yaw_deg", 0.0))
				var scl = t.get("scale", 1.0)
				
				var xform = Transform3D()
				xform.basis = Basis().rotated(Vector3.UP, yaw).scaled(Vector3.ONE * scl)
				xform.origin = origin
				
				# Record index for dynamic hiding/revealing
				var t_id = t.get("id", "")
				var pos_id = "pos_%d_%d_%d" % [int(round(origin.x)), int(round(origin.y)), int(round(origin.z))]
				var is_felled = (t_id != "" and TreeChoppable.felled_tree_ids.has(t_id)) or TreeChoppable.felled_tree_ids.has(pos_id)
				var original_xform:Transform3D=xform
				if is_felled:
					xform.basis = Basis().scaled(Vector3.ZERO)
				mm.set_instance_transform(i, xform)
				
				if t_id != "":
					_tree_mmi_index[t_id] = { "mm": mm, "index": i, "xform": original_xform }
					if is_felled:_hidden_tree_ids[t_id]=true
				
			mmi.multimesh = mm
			chunk_node.add_child(mmi)
			total_instances += tree_list.size()
			
	print("[WorldMap] Spawned %d trees across %d chunks using MultiMesh." % [total_instances, chunk_map.size()])

func _spawn_tutorial_trees() -> void:
	if not is_instance_valid(_interactive_root):
		_interactive_root = Node3D.new()
		_interactive_root.name = "InteractiveTrees"
		add_child(_interactive_root)
	
	var interactive_scene = load("res://scenes/props/TreeInteractive.tscn")
	if interactive_scene == null:
		return
		
	# Cache authored tutorial records; in-place loads must not scan 55k trees.
	if _tutorial_records.is_empty():
		for record in _all_trees_data:
			if record.get("tutorial",false):_tutorial_records.append(record)
	for tree in _tutorial_records:
		if tree.get("tutorial", false):
			var sp = tree.get("species", "birch")
			var tree_id = tree.get("id", "tut_tree")
			if _interactive_trees.has(tree_id) and is_instance_valid(_interactive_trees[tree_id]):continue
			var pos_arr = tree.get("pos")
			var origin = Vector3(pos_arr[0], pos_arr[2], -pos_arr[1])
			
			# If this is tree_055432 (birch), place it right in front of spawn (-900, 26, 1100)
			# at 4m distance so the player immediately has a tree right before their eyes!
			if tree_id == "tree_055432":
				origin = Vector3(-900.0, 24.99, 1096.0)
				
			var pos_id = "pos_%d_%d_%d" % [int(round(origin.x)), int(round(origin.y)), int(round(origin.z))]
			if TreeChoppable.felled_tree_ids.has(tree_id) or TreeChoppable.felled_tree_ids.has(pos_id):
				_ensure_saved_remnant(tree_id, origin, sp)
				continue
				
			var yaw = deg_to_rad(tree.get("yaw_deg", 0.0))
			var scl = tree.get("scale", 1.0)
			
			var inst = interactive_scene.instantiate()
			inst.species = sp
			inst.tree_id = tree_id
			inst.transform = _interactive_root.global_transform.affine_inverse() * Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*scl),origin)
			_interactive_root.add_child(inst)
			_interactive_trees[tree_id] = inst
			print("[WorldMap] Spawned tutorial %s tree (%s) at %s" % [sp.to_upper(), tree_id, str(origin)])

func _setup_dynamic_trees() -> void:
	_dynamic_trees_root = Node3D.new()
	_dynamic_trees_root.name = "DynamicTrees"
	add_child(_dynamic_trees_root)

func _process(delta: float) -> void:
	_dynamic_update_timer += delta
	if _dynamic_update_timer < 0.35:
		return
	_dynamic_update_timer = 0.0
	
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_node_or_null("../Player")
		if _player_ref == null:
			return
			
	var p_pos = _player_ref.global_position
	# Find player's current chunk
	var chunk_x = clampi(int(floor((p_pos.x + 2000.0) / 250.0)), 0, 15)
	var chunk_y = clampi(int(floor((-p_pos.z + 2000.0) / 250.0)), 0, 15)
	
	# Check adjacent chunks within 1 step
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var cx = chunk_x + dx
			var cy = chunk_y + dy
			if cx < 0 or cx > 15 or cy < 0 or cy > 15:
				continue
			var chunk_name = "Chunk_%02d_%02d" % [cx, cy]
			if not _chunk_trees_data.has(chunk_name):
				continue
				
			var tree_list = _chunk_trees_data[chunk_name]
			for t in tree_list:
				var t_id = t["id"]
				var pos_arr = t["pos"]
				var origin = Vector3(pos_arr[0], pos_arr[2], -pos_arr[1])
				var dist = p_pos.distance_to(origin)
				
				# Activate tree within 24m
				if dist <= 24.0:
					var pos_id = "pos_%d_%d_%d" % [int(round(origin.x)), int(round(origin.y)), int(round(origin.z))]
					if TreeChoppable.felled_tree_ids.has(t_id) or TreeChoppable.felled_tree_ids.has(pos_id):
						_set_mmi_tree_scale(t_id, 0.0)
						_ensure_saved_remnant(t_id, origin, str(t.get("species","birch")))
						continue
					if not _dynamic_trees.has(t_id) and not _interactive_trees.has(t_id):
						_activate_dynamic_tree(t, origin)
						
	# Deactivate distant dynamic trees (> 36m)
	var to_remove = []
	for t_id in _dynamic_trees.keys():
		var inst = _dynamic_trees[t_id]
		if is_instance_valid(inst) and (inst is Node3D):
			if p_pos.distance_to((inst as Node3D).global_position) > 36.0:
				to_remove.append(t_id)
		else:
			to_remove.append(t_id)
			
	for t_id in to_remove:
		_deactivate_dynamic_tree(t_id)

func _activate_dynamic_tree(tree_data: Dictionary, origin: Vector3) -> void:
	var t_id = tree_data["id"]
	var pos_id = "pos_%d_%d_%d" % [int(round(origin.x)), int(round(origin.y)), int(round(origin.z))]
	if TreeChoppable.felled_tree_ids.has(t_id) or TreeChoppable.felled_tree_ids.has(pos_id):
		_set_mmi_tree_scale(t_id, 0.0)
		return
		
	var sp = tree_data.get("species", "birch")
	var yaw = deg_to_rad(tree_data.get("yaw_deg", 0.0))
	var scl = tree_data.get("scale", 1.0)
	
	var interactive_scene = load("res://scenes/props/TreeInteractive.tscn")
	if interactive_scene:
		var inst = interactive_scene.instantiate()
		inst.species = sp
		inst.tree_id = t_id
		inst.transform = _dynamic_trees_root.global_transform.affine_inverse() * Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*scl),origin)
		_dynamic_trees_root.add_child(inst)
		_dynamic_trees[t_id] = inst
		
		# Temporarily hide MultiMesh instance
		_set_mmi_tree_scale(t_id, 0.0)

func _deactivate_dynamic_tree(t_id: String) -> void:
	if _dynamic_trees.has(t_id):
		var inst = _dynamic_trees[t_id]
		if is_instance_valid(inst):
			if inst._is_falling or inst._fall_preparing or (inst._voxel_trunk and inst._voxel_trunk.is_busy()): return
			var pos_id = ""
			if inst is Node3D:
				pos_id = "pos_%d_%d_%d" % [int(round(inst.global_position.x)), int(round(inst.global_position.y)), int(round(inst.global_position.z))]
			var is_felled = TreeChoppable.felled_tree_ids.has(t_id) or (pos_id != "" and TreeChoppable.felled_tree_ids.has(pos_id))
			# If tree hasn't been chopped (still full HP) AND is not felled
			if not is_felled:
				_restore_mmi_tree_scale(t_id)
			else:
				_set_mmi_tree_scale(t_id, 0.0)
			inst.queue_free()
		_dynamic_trees.erase(t_id)

func _ensure_saved_remnant(t_id: String, fallback_position: Vector3, fallback_species: String = "birch") -> void:
	if _remnant_requested.has(t_id): return
	for pending in get_children():
		if pending is TreeChoppable and pending.tree_id==t_id and pending._restoring_remnant:
			_remnant_requested[t_id]=true
			return
	var pos_id := "pos_%d_%d_%d" % [roundi(fallback_position.x),roundi(fallback_position.y),roundi(fallback_position.z)]
	var stored_info = TreeChoppable.felled_tree_ids.get(t_id,TreeChoppable.felled_tree_ids.get(pos_id,{}))
	var info: Dictionary = stored_info if stored_info is Dictionary else {"id":t_id,"species":fallback_species,"pos":[fallback_position.x,fallback_position.y,fallback_position.z]}
	if info.is_empty(): return
	for stump in get_tree().get_nodes_in_group("permanent_stumps"):
		if stump.get_meta("tree_id","") == t_id:
			_remnant_requested[t_id]=true
			return
	_remnant_requested[t_id]=true
	var origin := fallback_position
	var stored = info.get("pos",[])
	if stored is Array and stored.size()==3: origin=Vector3(stored[0],stored[1],stored[2])
	elif stored is Vector3: origin=stored
	elif stored is String:
		var coords: PackedStringArray = stored.trim_prefix("(").trim_suffix(")").split(",")
		if coords.size()==3:origin=Vector3(float(coords[0]),float(coords[1]),float(coords[2]))
	var basis := Basis.IDENTITY
	var values: Array = info.get("basis",[])
	if values.size()==9:basis=Basis(Vector3(values[0],values[1],values[2]),Vector3(values[3],values[4],values[5]),Vector3(values[6],values[7],values[8]))
	var restore := TreeChoppable.new()
	restore.species=info.get("species","birch")
	restore.tree_id=t_id
	restore.transform=global_transform.affine_inverse()*Transform3D(basis,origin)
	add_child(restore) # _ready reconstructs the saved lower section asynchronously.

func restore_felled_stumps() -> void:
	# Called after a loaded player's position is applied. Far remnants are
	# reconstructed lazily by the normal proximity loop, not all at world load.
	_remnant_requested.clear()
	var player := get_node_or_null("../Player") as Node3D
	if player == null:return
	var seen: Dictionary={}
	for key in TreeChoppable.felled_tree_ids:
		var stored_info=TreeChoppable.felled_tree_ids[key]
		# Old slots used boolean flags without shape/position data. Keep the
		# hidden tree; reconstruct its remnant lazily when its record is nearby.
		var info: Dictionary=stored_info if stored_info is Dictionary else {"id":str(key)}
		var t_id: String=info.get("id",key)
		if t_id=="":t_id=key
		if seen.has(t_id):continue
		seen[t_id]=true
		_set_mmi_tree_scale(t_id,0.0)
		for pool in [_interactive_trees,_dynamic_trees]:
			if pool.has(t_id):
				var standing=pool[t_id]
				if is_instance_valid(standing):standing.hide();standing.queue_free()
				pool.erase(t_id)
		var p=info.get("pos",[])
		if p is Array and p.size()==3:
			var origin:=Vector3(p[0],p[1],p[2])
			if origin.distance_squared_to(player.global_position)<70.0*70.0:_ensure_saved_remnant(t_id,origin)

func _set_mmi_tree_scale(t_id: String, scale_mult: float) -> void:
	if is_zero_approx(scale_mult):_hidden_tree_ids[t_id]=true
	else:_hidden_tree_ids.erase(t_id)
	if _tree_mmi_index.has(t_id):
		var data = _tree_mmi_index[t_id]
		var mm: MultiMesh = data["mm"]
		var idx: int = data["index"]
		var orig_xform: Transform3D = data["xform"]
		var new_xform = orig_xform
		new_xform.basis = orig_xform.basis.scaled(Vector3.ONE * scale_mult)
		mm.set_instance_transform(idx, new_xform)

func _restore_mmi_tree_scale(t_id: String) -> void:
	_hidden_tree_ids.erase(t_id)
	if _tree_mmi_index.has(t_id):
		var data = _tree_mmi_index[t_id]
		var mm: MultiMesh = data["mm"]
		var idx: int = data["index"]
		var orig_xform: Transform3D = data["xform"]
		mm.set_instance_transform(idx, orig_xform)

func _on_mine_entrance_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		print("[WorldMap] Player entered Mine Entrance! Transitioning to MineInterior...")
		var tree_ref = get_tree()
		if tree_ref:
			var session = get_parent().get_node_or_null("SurvivalWorld")
			if session: session.prepare_travel()
			tree_ref.change_scene_to_file.call_deferred("res://scenes/mine/MineInterior.tscn")

func reconcile_loaded_world() -> void:
	# Replace changed geometry, not every intact nearby tree on every load.
	# Pending old remnant jobs must not materialize after the new state applies.
	for builder in get_tree().get_nodes_in_group("remnant_builders"):
		if is_instance_valid(builder) and is_ancestor_of(builder):builder.free()
	for stump in get_tree().get_nodes_in_group("permanent_stumps"):
		if get_parent().is_ancestor_of(stump):stump.queue_free()
	for pool in [_interactive_trees,_dynamic_trees]:
		for id in pool.keys():
			var tree=pool[id]
			if not is_instance_valid(tree):pool.erase(id);continue
			if tree._is_already_felled() or tree._is_falling or tree._fall_preparing or tree._restoring_remnant:
				tree.free();pool.erase(id);continue
			var wanted:Array=TreeChoppable.damaged_tree_states.get(tree.get_effective_id(),{}).get("cuts",[])
			var actual:Array=tree._voxel_trunk.export_cuts() if tree._voxel_trunk else []
			if actual!=wanted:
				tree._apply_species_config();tree._setup_voxel_trunk();tree._update_mesh_stage(0);tree.restore_damage()
	for id in _hidden_tree_ids.keys():
		if not _dynamic_trees.has(id) and not _interactive_trees.has(id):_restore_mmi_tree_scale(id)
	if not is_instance_valid(_dynamic_trees_root):_setup_dynamic_trees()
	restore_felled_stumps()
	_spawn_tutorial_trees()
