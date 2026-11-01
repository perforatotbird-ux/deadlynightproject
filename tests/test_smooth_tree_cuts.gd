extends SceneTree

const Choppable = preload("res://scripts/props/TreeChoppable.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	print("PASS: " if condition else "FAIL: ", message)
	if not condition: failures += 1

func _initialize() -> void:
	call_deferred("run")

func settle(trunk: Node) -> void:
	var deadline := Time.get_ticks_msec()+15000
	while trunk.is_busy() and Time.get_ticks_msec()<deadline:
		await create_timer(0.005).timeout

func run() -> void:
	var shared_before: Mesh = null
	for species in ["birch", "spruce", "beech", "oak"]:
		Choppable.felled_tree_ids.clear()
		var tree := Choppable.new()
		tree.species = species
		tree.tree_id = "smooth_cut_" + species
		root.add_child(tree)
		await process_frame
		var trunk = tree._voxel_trunk
		check(trunk._fallback == null, species + ": no second trunk/halo")
		var mi: MeshInstance3D = trunk._mesh_instance
		shared_before = tree._visual_node.find_children("*","MeshInstance3D",true,false)[0].mesh
		var original_count := shared_before.get_surface_count()
		var start := Time.get_ticks_msec()
		tree.hit(1, tree.global_position + Vector3(0, 1.3, 0.3), Vector3(0, 1.3, 1.5))
		await settle(trunk)
		check(mi.mesh != shared_before and shared_before.get_surface_count() == original_count, species + ": instance-local real mesh damage")
		var exposed_wood := false
		for surface in mi.mesh.get_surface_count():
			exposed_wood = exposed_wood or mi.mesh.surface_get_material(surface)==trunk._wood_material
		check(exposed_wood, species + ": exposed notch uses separate wood material, not recolored bark")
		var p := Vector3(0, 1.3, 0.2)
		var first: float = trunk._depth_at(p)
		check(first > 0.025 and is_zero_approx(trunk._depth_at(Vector3(0, 1.6, 0.2))), species + ": local elliptical cavity")
		check(is_zero_approx(trunk._depth_at(Vector3(0, 1.3, -0.2))), species + ": opposite side unchanged")
		tree.hit(1, tree.global_position + Vector3(0, 1.3, 0.25), Vector3(0, 1.3, 1.5))
		await settle(trunk)
		check(trunk._depth_at(p) > first, species + ": repeat strike deepens same cut")
		await process_frame
		check(tree.get_node("CollisionShape3D").shape is ConcavePolygonShape3D, species + ": cached bark collider retained; axe impact analytically projected")
		print("TIME ", species, ": two strikes ", Time.get_ticks_msec() - start, " ms")
		tree.free()
	quit(0 if failures == 0 else 1)
