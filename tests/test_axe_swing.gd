extends SceneTree
const Player = preload("res://scripts/player/PlayerController.gd")
const Choppable = preload("res://scripts/props/TreeChoppable.gd")
class Target extends Node3D:
	var hits: int = 0
	func hit(_damage: int, _point: Vector3, _player: Vector3) -> bool:
		hits += 1
		return false

var failures: int = 0
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var player := Player.new()
	root.add_child(player)
	player.set_physics_process(false)
	var target := Target.new()
	root.add_child(target)
	target.position = Vector3(0, 1.6, -1.4)
	target.add_to_group("choppable_trees")
	await process_frame
	check(player._axe_arm_rig._arms.size() == 2, "two hands attached to grip")
	player._sample_axe_arc(1.0, Player.AXE_REST_POS, Vector3(0.43, -0.16, -0.28), Vector3(0.39, -0.06, -0.25), Player.AXE_REST_ROT, Vector3(42, -28, -34))
	check(player._axe_anim_pivot.position.x > 0.30 and player._axe_anim_pivot.position.y > -0.10, "wind-up from right shoulder")
	player._cancel_chop()
	player._try_chop()
	await create_timer(0.08).timeout
	check(target.hits == 0, "wind-up does not apply damage early")
	await create_timer(0.20).timeout
	check(target.hits == 1, "one contact callback per swing")
	check(player._audio_hit.stream == null, "player does not duplicate tree impact sound")
	await create_timer(0.25).timeout
	check(player._can_chop and player._axe_anim_pivot.position.is_equal_approx(Player.AXE_REST_POS), "recovery and cooldown complete")
	player._try_chop()
	player.select_hotbar_slot(1)
	await create_timer(0.30).timeout
	check(target.hits == 1 and player._can_chop, "tool switch cancels pending impact")
	check(not player._axe_arm_rig.visible, "arms hidden with unequipped axe")
	player.select_hotbar_slot(0)
	player._try_chop()
	paused = true
	paused = false
	await create_timer(0.30).timeout
	check(target.hits == 1, "pause cancels pending swing")
	var tree := Choppable.new()
	tree.tree_id = "axe_effect_smoke"
	root.add_child(tree)
	tree._play_hit_sound()
	check(tree._audio_hit.stream.resource_path.ends_with("axe_hit_wood_01.ogg") and is_equal_approx(tree._audio_hit.pitch_scale, 1.0), "one fixed impact sample")
	check(tree._particles.amount == 96 and tree._dust_particles.amount == 160, "256 splinters/sawdust particles per hit")
	tree._emit_chips(Vector3(0, 1.3, 0.2), Vector3(0, 0, 1))
	check(tree._particles.emitting and tree._dust_particles.emitting, "both particle bursts emit at contact")
	player.free()
	target.free()
	tree.free()
	await process_frame
	quit(0 if failures == 0 else 1)
