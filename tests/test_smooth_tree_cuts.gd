extends SceneTree

const Choppable = preload("res://scripts/props/TreeChoppable.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	print("PASS: " if condition else "FAIL: ", message)
	if not condition: failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var shared_before: Mesh = null
	for species in ["birch", "spruce", "beech", "oak"]:
		var tree := Choppable.new()
		tree.species = species
		tree.tree_id = "smooth_cut_" + species
		root.add_child(tree)
		await process_frame
		var trunk = tree._voxel_trunk
		check(trunk._fallback == null, species + ": no second trunk/halo")
		var mi: MeshInstance3D = trunk._mesh_instance
		shared_before = mi.mesh
		var original_count := shared_before.get_surface_count()
		var start := Time.get_ticks_msec()
		tree.hit(1, tree.global_position + Vector3(0, 1.3, 0.3), Vector3(0, 1.3, 1.5))
		check(mi.mesh != shared_before and shared_before.get_surface_count() == original_count, species + ": instance-local real mesh damage")
		check(mi.mesh.get_surface_count() > original_count, species + ": exposed wood surface")
		var p := Vector3(0, 1.3, 0.2)
		var first: float = trunk._depth_at(p)
		check(first > 0.025 and is_zero_approx(trunk._depth_at(Vector3(0, 1.6, 0.2))), species + ": local elliptical cavity")
		check(is_zero_approx(trunk._depth_at(Vector3(0, 1.3, -0.2))), species + ": opposite side unchanged")
		tree.hit(1, tree.global_position + Vector3(0, 1.3, 0.25), Vector3(0, 1.3, 1.5))
		check(trunk._depth_at(p) > first, species + ": repeat strike deepens same cut")
		await process_frame
		check(tree.get_node("CollisionShape3D").shape is ConcavePolygonShape3D, species + ": collision follows damaged bark")
		print("TIME ", species, ": two strikes ", Time.get_ticks_msec() - start, " ms")
		tree.free()
	quit(0 if failures == 0 else 1)
