extends Node3D

# Lightweight first-person two-hand rig: hands remain attached to the handle,
# while sleeve segments follow camera-relative shoulders and bent elbows.
var _arms: Array[Dictionary] = []

func setup(grip_pivot: Node3D) -> void:
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = Color(0.12, 0.17, 0.14)
	sleeve.roughness = 0.95
	var glove := StandardMaterial3D.new()
	glove.albedo_color = Color(0.21, 0.13, 0.075)
	glove.roughness = 0.9
	for side in [1.0, -1.0]:
		var hand := Node3D.new()
		hand.name = "RightGrip" if side > 0 else "LeftGrip"
		grip_pivot.add_child(hand)
		hand.position = Vector3(0.0, 0.0 if side > 0 else 0.17, -0.035 if side > 0 else -0.055)
		var palm := MeshInstance3D.new()
		var palm_mesh := BoxMesh.new()
		palm_mesh.size = Vector3(0.048, 0.085, 0.065)
		palm.mesh = palm_mesh
		palm.material_override = glove
		palm.position.x = side * 0.033
		hand.add_child(palm)
		# Four curled fingers wrap the handle instead of a floating mitten.
		for finger in 4:
			for joint in 3:
				var angle: float = side * (0.5 + joint * 0.85)
				var knuckle := MeshInstance3D.new()
				var mesh := SphereMesh.new()
				mesh.radius = 0.013
				mesh.height = 0.026
				mesh.radial_segments = 8
				mesh.rings = 4
				knuckle.mesh = mesh
				knuckle.material_override = glove
				knuckle.position = Vector3(cos(angle) * side * 0.03, -0.028 + finger * 0.019, sin(angle) * 0.03)
				hand.add_child(knuckle)
		var thumb := MeshInstance3D.new()
		var thumb_mesh := CapsuleMesh.new()
		thumb_mesh.radius = 0.014
		thumb_mesh.height = 0.057
		thumb_mesh.radial_segments = 8
		thumb_mesh.rings = 2
		thumb.mesh = thumb_mesh
		thumb.material_override = glove
		thumb.position = Vector3(-side * 0.014, 0.035, 0.021)
		thumb.rotation.z = side * 0.8
		hand.add_child(thumb)
		var upper := _make_sleeve(sleeve, 0.065)
		var forearm := _make_sleeve(sleeve, 0.047)
		_arms.append({"hand": hand, "side": side, "upper": upper, "forearm": forearm})
	update_pose()

func _make_sleeve(material: Material, radius: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = 0.3
	mesh.radial_segments = 10
	mesh.rings = 3
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func update_pose() -> void:
	for arm in _arms:
		var side: float = arm["side"]
		var hand: Node3D = arm["hand"]
		var wrist := to_local(hand.global_position)
		var shoulder := Vector3(side * 0.27, -0.20, 0.13)
		var elbow := shoulder.lerp(wrist, 0.5) + Vector3(side * 0.10, -0.14, 0.08)
		_segment(arm["upper"], shoulder, elbow)
		_segment(arm["forearm"], elbow, wrist)

func _segment(node: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var offset := b - a
	node.position = (a + b) * 0.5
	node.basis = Basis(Quaternion(Vector3.UP, offset.normalized()))
	var mesh := node.mesh as CapsuleMesh
	mesh.height = maxf(mesh.radius * 2.0, offset.length() + 0.025)
