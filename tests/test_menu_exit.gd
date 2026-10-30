extends SceneTree
## Separate process: a successful confirmation must actually terminate the engine.
func _init() -> void:
	call_deferred("run")

func run() -> void:
	var from_pause = "--pause" in OS.get_cmdline_user_args()
	var scene = load("res://scenes/menu/PauseMenu.tscn" if from_pause else "res://scenes/menu/MainMenu.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	if from_pause:
		scene.open_pause()
	scene._on_quit_pressed()
	await process_frame
	var dialogs = get_nodes_in_group("menu_confirmation")
	if dialogs.is_empty():
		printerr("FAIL: exit confirmation missing")
		quit(1)
		return
	print("EXIT_CONFIRMATION_TEST: confirming ", "pause" if from_pause else "main-menu", " quit")
	dialogs[0]._btn_confirm.pressed.emit()
	await create_timer(2.0).timeout
	printerr("FAIL: confirmed exit did not terminate the engine")
	quit(1)
