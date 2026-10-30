extends SceneTree
const Trunk = preload("res://scripts/props/VoxelTreeTrunk.gd")
func _initialize() -> void:call_deferred("run")
func wait_for_mesh(trunk: Node) -> void:
	var deadline:=Time.get_ticks_msec()+15000
	while trunk.is_busy() and Time.get_ticks_msec()<deadline:await create_timer(0.005).timeout
func run() -> void:
	var trunk:=Trunk.new();root.add_child(trunk);trunk.init_trunk("birch",0.35,3.2,0.04)
	trunk.carve(Vector3(0.35,1.2,0),Vector3.LEFT,1)
	await wait_for_mesh(trunk)
	assert(trunk._mesh_instance.mesh!=null)
	assert(trunk._depth_at(Vector3(0.35,1.2,0))>0)
	for i in 12:
		if trunk._fractured:break
		trunk.carve(Vector3(0.35,1.2,0),Vector3.LEFT,1)
		await wait_for_mesh(trunk)
	assert(trunk._fractured)
	assert(trunk.build_stump_mesh(trunk.weakest_y)!=null)
	assert(trunk.build_upper_mesh(trunk.weakest_y)!=null)
	print("PASS: asynchronous carving and actual lower/upper meshes")
	trunk.free();quit()
