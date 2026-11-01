extends SceneTree
const Choppable = preload("res://scripts/props/TreeChoppable.gd")
class EmptyWorld extends "res://scripts/world/WorldMap.gd":
	func _ready() -> void:pass
var failures: int = 0
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func _initialize() -> void:call_deferred("run")
func idle(trunk: Node) -> void:
	var end := Time.get_ticks_msec()+15000
	while is_instance_valid(trunk) and trunk.is_busy() and Time.get_ticks_msec()<end:
		await create_timer(0.005).timeout
func run() -> void:
	for sp in ["birch","spruce","beech","oak"]:
		Choppable.felled_tree_ids.clear()
		var tree:=Choppable.new();tree.species=sp;tree.tree_id="fracture_"+sp
		root.add_child(tree)
		tree.set_process(false)
		await process_frame
		var trunk=tree._voxel_trunk
		var collider=tree.get_node("CollisionShape3D").shape
		var max_hit_us:=0
		for i in 2:
			var start:=Time.get_ticks_usec()
			tree.hit(1,Vector3(0,2.4,0.4),Vector3(0,1,2))
			max_hit_us=maxi(max_hit_us,Time.get_ticks_usec()-start)
			await idle(trunk)
		check(not tree._is_falling,sp+": two strikes do not destroy entire tree")
		check(trunk._mesh_instance.mesh!=null,sp+": asynchronous mesh applied")
		check(trunk._depth_at(Vector3(0,2.4,0.2))>0,sp+": rounded cut retained")
		# Many scattered strikes must not fell a tree by total HP alone.
		for y in [0.6,1.1,1.6,3.0]:
			tree.hit(1,Vector3(0,y,0.4),Vector3(0,1,2));await idle(trunk)
		check(not tree._is_falling,sp+": distributed damage does not trip global HP")
		for i in 35:
			if tree._is_falling:break
			tree.hit(1,Vector3(0,2.4,0.4),Vector3(0,1,2));await idle(trunk)
		check(tree._is_falling,sp+": sufficiently thinned section fractures")
		check(absf(tree._break_height-2.4)<0.08,sp+": global weakest section, not last/root height")
		check(tree._fall_pivot!=null and is_equal_approx(tree._fall_pivot.position.y,tree._break_height),sp+": upper mesh pivots at cut")
		var remnant:Node3D=null
		for s in get_nodes_in_group("permanent_stumps"):
			if s.get_meta("tree_id","")==tree.tree_id:remnant=s
		check(remnant!=null and absf(remnant.get_meta("cut_y")-2.4)<0.08,sp+": retained lower trunk has actual height")
		if remnant:
			var bounds: AABB=remnant.get_child(0).mesh.get_aabb()
			check(absf(bounds.end.y-tree._break_height)<0.005,sp+": lower geometry clipped at fracture plane")
		var upper_bounds:AABB=tree._visual_node.mesh.get_aabb()
		check(absf(upper_bounds.position.y-tree._break_height)<0.005,sp+": upper geometry starts at fracture plane")
		check(collider==tree.get_node("CollisionShape3D").shape,sp+": no per-strike collision BVH rebuild")
		print("PERF ",sp," main_hit_us=",max_hit_us," worker_us=",trunk.last_worker_usec," upload_us=",trunk.last_upload_usec)
		check(max_hit_us<10000,sp+": hit submission below 10ms")
		var saved=Choppable.felled_tree_ids[tree.tree_id]
		check(saved.has("cut_y") and saved.has("cuts") and saved.has("basis"),sp+": fracture metadata serializable")
		tree.free()
		if remnant:remnant.free()
		# Restore through JSON-compatible state, not an authored short stump.
		Choppable.felled_tree_ids["fracture_"+sp]=JSON.parse_string(JSON.stringify(saved))
		Choppable.felled_tree_ids.erase("pos_0_0_0")
		var restored:=Choppable.new();restored.species=sp;restored.tree_id="fracture_"+sp
		root.add_child(restored)
		var restored_trunk=restored._voxel_trunk
		await idle(restored_trunk)
		var recovered:Node3D=null
		for s in get_nodes_in_group("permanent_stumps"):
			if s.get_meta("tree_id","")=="fracture_"+sp:recovered=s
		check(recovered!=null and absf(float(recovered.get_meta("cut_y"))-2.4)<0.08,sp+": JSON reload preserves real remnant height")
		if recovered:recovered.free()
		await process_frame
	Choppable.felled_tree_ids.clear()
	var high:=Choppable.new();high.tree_id="high_cut"
	root.add_child(high);high.set_process(false)
	var ht=high._voxel_trunk
	# Isolate the global-weakest-section invariant from asset-specific forks and
	# branches intersecting y=6. Real authored variants are covered separately.
	high._visual_node.free()
	var controlled:=Node3D.new();high.add_child(controlled);high._visual_node=controlled
	var stem:=MeshInstance3D.new();var cylinder:=CylinderMesh.new()
	cylinder.height=18.0;cylinder.top_radius=0.25;cylinder.bottom_radius=0.25;cylinder.radial_segments=32
	var bark:=StandardMaterial3D.new();bark.resource_name="Test_Bark";cylinder.material=bark
	stem.mesh=cylinder;stem.position.y=9.0;controlled.add_child(stem);ht.bind_visual(controlled)
	ht.restore_cuts([{"angle":PI/2,"y":6.0,"work":8.0,"depth":0.0,"width":0.16,"height":0.12}])
	high.hit(1,Vector3(0,1.0,0.2),Vector3(0,1,2))
	await idle(ht)
	check(high._is_falling and absf(high._break_height-6.0)<0.08,"fracture above 3.2m follows earlier weakest cut, not last hit at 1m")
	high.free()
	for stump in get_nodes_in_group("permanent_stumps"):stump.free()
	Choppable.felled_tree_ids.clear()
	var basis:=Basis(Vector3.UP,0.7).scaled(Vector3.ONE*1.25)
	Choppable.felled_tree_ids["saved_world"]={"id":"saved_world","species":"birch","pos":[0,0,0],"cut_y":2.7,"cuts":[],"basis":[basis.x.x,basis.x.y,basis.x.z,basis.y.x,basis.y.y,basis.y.z,basis.z.x,basis.z.y,basis.z.z]}
	var player:=Node3D.new();player.name="Player";root.add_child(player)
	var world:=EmptyWorld.new();root.add_child(world)
	world.restore_felled_stumps();world.restore_felled_stumps()
	var deadline:=Time.get_ticks_msec()+15000
	var saved_stump:Node3D=null
	while saved_stump==null and Time.get_ticks_msec()<deadline:
		await create_timer(0.005).timeout
		for s in get_nodes_in_group("permanent_stumps"):
			if s.get_meta("tree_id","")=="saved_world":saved_stump=s
	check(saved_stump!=null,"world reload recreates saved lower trunk")
	if saved_stump:
		check(saved_stump.global_basis.is_equal_approx(basis),"saved remnant keeps yaw and scale")
		check(is_equal_approx(float(saved_stump.get_meta("cut_y")),2.7),"world reload keeps local cut height")
	var count:=0
	for s in get_nodes_in_group("permanent_stumps"):
		if s.get_meta("tree_id","")=="saved_world":count+=1
	check(count==1,"remnant restoration is deduplicated")
	world.free();player.free()
	Choppable.felled_tree_ids.clear()
	quit(0 if failures==0 else 1)
