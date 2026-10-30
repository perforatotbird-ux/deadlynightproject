extends SceneTree
var output_dir: String = "user://axe_hand_previews"
const Player = preload("res://scripts/player/PlayerController.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output_dir = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1280, 720)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.19,0.22,0.25)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8,0.85,0.9)
	env.environment.ambient_light_energy = 0.65
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees = Vector3(-35,-25,0)
	light.light_energy = 1.2
	var player := Player.new()
	stage.add_child(player)
	player.set_physics_process(false)
	player.set_process_input(false)
	player._hud_layer.hide()
	player._camera.current = true
	await process_frame
	player._cancel_chop()
	await capture("rest")
	player._sample_axe_arc(1, Player.AXE_REST_POS, Vector3(0.42,-0.20,-0.39), Player.AXE_WINDUP_POS, Player.AXE_REST_ROT, Player.AXE_WINDUP_ROT)
	await capture("shoulder")
	player._sample_axe_arc(1, Player.AXE_WINDUP_POS, Vector3(0.33,0.04,-0.59), Player.AXE_CONTACT_POS, Player.AXE_WINDUP_ROT, Player.AXE_CONTACT_ROT)
	await capture("contact")
	player._sample_axe_arc(1, Player.AXE_CONTACT_POS, Vector3(-0.025,-0.34,-0.54), Player.AXE_FOLLOW_POS, Player.AXE_CONTACT_ROT, Player.AXE_FOLLOW_ROT)
	await capture("follow")
	stage.free()
	quit()
func capture(state: String) -> void:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join("godot_" + state + ".png"))
