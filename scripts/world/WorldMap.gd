extends Node3D
class_name WorldMap

@export var load_all_trees: bool = true

var _terrain_root: Node3D = null
var _vegetation_root: Node3D = null
var _pois_root: Node3D = null
var _interactive_root: Node3D = null

# Species meshes cached
var _tree_meshes: Dictionary = {}
# All tree records from JSON
var _all_trees_data: Array = []
# Interactive trees pool
var _interactive_trees: Dictionary = {}

func _ready() -> void:
	_load_tree_models()
	_load_terrain()
	_load_pois_and_props()
	_load_vegetation()
	_spawn_tutorial_trees()

func _load_tree_models() -> void:
	var species = ["birch", "spruce", "beech", "oak"]
	for sp in species:
		var path = "res://assets/models/trees/tree_%s.glb" % sp
		if ResourceLoader.exists(path):
			var scene = load(path)
			if scene:
				var inst = scene.instantiate()
				var mesh_inst = _find_mesh_instance(inst)
				if mesh_inst and mesh_inst.mesh:
					_tree_meshes[sp] = mesh_inst.mesh

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
	
	# 1. Place Bridge at BRIDGE POI (925, 37, height 36.8)
	var bridge_path = "res://assets/models/props/bridge_wood.glb"
	if ResourceLoader.exists(bridge_path):
		var b_scene = load(bridge_path)
		if b_scene:
			var bridge = b_scene.instantiate()
			bridge.name = "POI_Bridge"
			# BRIDGE position: X=925, Elevation=36.8, Z=37
			bridge.position = Vector3(925.0, 36.8, 37.0)
			# Align across the river
			bridge.rotation_degrees = Vector3(0.0, 75.0, 0.0)
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
			portal.position = Vector3(1130.0, 143.0, 1210.0)
			# Azimuth 225 deg (South-West facing)
			portal.rotation_degrees = Vector3(0.0, 225.0, 0.0)
			_pois_root.add_child(portal)
			for m in _collect_all_meshes(portal):
				m.create_trimesh_collision()
				
			# Entrance trigger to Mine Interior
			var trigger = Area3D.new()
			trigger.name = "MineEntranceTrigger"
			trigger.position = Vector3(1130.0, 144.0, 1210.0)
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
			cart.position = Vector3(1115.0, 140.5, 1195.0)
			cart.rotation_degrees = Vector3(0.0, 45.0, 0.0)
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
				rails.position = Vector3(1126.0 - offset * 0.707, 141.5 - offset * 0.05, 1206.0 - offset * 0.707)
				rails.rotation_degrees = Vector3(0.0, 45.0, 0.0)
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
		var pz = pos_arr[1]
		
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
				# pos: [X, Z_map, Elevation_Y]
				var origin = Vector3(pos_arr[0], pos_arr[2], pos_arr[1])
				var yaw = deg_to_rad(t.get("yaw_deg", 0.0))
				var scl = t.get("scale", 1.0)
				
				var xform = Transform3D()
				xform.basis = Basis().rotated(Vector3.UP, yaw).scaled(Vector3.ONE * scl)
				xform.origin = origin
				mm.set_instance_transform(i, xform)
				
			mmi.multimesh = mm
			chunk_node.add_child(mmi)
			total_instances += tree_list.size()
			
	print("[WorldMap] Spawned %d trees across %d chunks using MultiMesh." % [total_instances, chunk_map.size()])

func _spawn_tutorial_trees() -> void:
	_interactive_root = Node3D.new()
	_interactive_root.name = "InteractiveTrees"
	add_child(_interactive_root)
	
	var interactive_scene = load("res://scenes/props/TreeInteractive.tscn")
	if interactive_scene == null:
		return
		
	# Find tutorial trees
	for tree in _all_trees_data:
		if tree.get("tutorial", false):
			var sp = tree.get("species", "birch")
			var pos_arr = tree.get("pos")
			var origin = Vector3(pos_arr[0], pos_arr[2], pos_arr[1])
			var yaw = deg_to_rad(tree.get("yaw_deg", 0.0))
			var scl = tree.get("scale", 1.0)
			
			var inst = interactive_scene.instantiate()
			_interactive_root.add_child(inst)
			inst.global_position = origin
			inst.rotation = Vector3(0, yaw, 0)
			inst.scale = Vector3.ONE * scl
			inst.init_tree(sp, tree.get("id", "tut_tree"))
			_interactive_trees[tree.get("id")] = inst
			print("[WorldMap] Spawned tutorial %s tree at %s" % [sp.to_upper(), str(origin)])

func _on_mine_entrance_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		print("[WorldMap] Player entered Mine Entrance! Transitioning to MineInterior...")
		var tree_ref = get_tree()
		if tree_ref:
			tree_ref.change_scene_to_file("res://scenes/mine/MineInterior.tscn")
