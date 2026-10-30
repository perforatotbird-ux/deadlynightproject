extends SceneTree
const Choppable=preload("res://scripts/props/TreeChoppable.gd")
var output_dir: String="user://tree_fracture_previews"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output_dir=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size=Vector2i(1280,720)
	var stage:=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0.22,0.27,0.29)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(0.8,0.85,0.9);env.environment.ambient_light_energy=0.7;stage.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,20,0);light.light_energy=1.3;stage.add_child(light)
	var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(3.3,4.3,6.5);camera.look_at(Vector3(0,2.6,0));camera.current=true
	var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(50,50);ground.mesh=plane;stage.add_child(ground)
	var gm:=StandardMaterial3D.new();gm.albedo_color=Color(0.16,0.22,0.16);ground.material_override=gm
	var tree:=Choppable.new();tree.tree_id="preview_tree";stage.add_child(tree);tree.set_process(false)
	for i in 3:
		tree.hit(1,Vector3(0,2.4,0.24),Vector3(0,1.6,3))
		while tree._voxel_trunk.is_busy():await process_frame
	await capture("rounded_cut")
	for i in 20:
		if tree._is_falling:break
		tree.hit(1,Vector3(0,2.4,0.24),Vector3(0,1.6,3))
		while tree._voxel_trunk.is_busy():await process_frame
	await capture("split_at_cut")
	tree._process(0.7)
	await capture("fall_about_cut")
	for stump in get_nodes_in_group("permanent_stumps"):
		if tree._fall_pivot:tree._fall_pivot.hide()
		camera.position=Vector3(2.2,4.2,3.7);camera.look_at(Vector3(0,2,0))
		await capture("remaining_trunk")
	stage.free();quit()
func capture(label: String) -> void:
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join(label+".png"))
