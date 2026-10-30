extends Node3D

# Original Blender-authored continuous glove mesh, not runtime box/sphere fingers.
# GLTF contains the palm, webbing, curled digits and opposed thumb in a fixed
# power grip; the two-bone sleeves solve towards its actual wrist socket.
const HANDS_SCENE = preload("res://assets/models/viewmodels/axe_grip_hands.gltf")
const WRIST_SOCKET := Vector3(0.165, -0.021, 0.025)
const UPPER_LENGTH: float = 0.36
const FOREARM_LENGTH: float = 0.34
var _arms: Array[Dictionary] = []
var _templates: Dictionary = {}

func setup(grip_pivot: Node3D) -> void:
	var source := HANDS_SCENE.instantiate()
	for child in source.find_children("*", "MeshInstance3D", true, false):
		_templates[child.name] = {"mesh": child.mesh, "transform": child.transform}
	source.free()
	for side in [1.0, -1.0]:
		var hand := Node3D.new()
		hand.name = "RightGrip" if side > 0 else "LeftGrip"
		grip_pivot.add_child(hand)
		# Right hand is the upper/control hand; left anchors the handle heel.
		hand.position = Vector3(0, 0.17 if side > 0 else -0.015, -0.055 if side > 0 else -0.032)
		var glove := Node3D.new()
		glove.name = "AnatomicalGlove"
		hand.add_child(glove)
		_add_piece("RightHand" if side > 0 else "LeftHand", glove)
		_add_piece("RightWristCuff" if side > 0 else "LeftWristCuff", glove)
		var wrist := Node3D.new()
		wrist.name = "WristSocket"
		wrist.position = Vector3(WRIST_SOCKET.x * side, WRIST_SOCKET.y, WRIST_SOCKET.z)
		glove.add_child(wrist)
		var upper := _add_piece("UpperSleeve", self)
		var forearm := _add_piece("ForearmSleeve", self)
		_arms.append({"hand": hand, "wrist": wrist, "side": side, "upper": upper, "forearm": forearm})
	update_pose()

func _add_piece(piece_name: String, parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = piece_name.replace(" ", "")
	if not _templates.has(piece_name):
		push_error("Missing Blender hand mesh: " + piece_name)
		return node
	node.mesh = _templates[piece_name]["mesh"]
	node.transform = _templates[piece_name]["transform"]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func update_pose() -> void:
	for arm in _arms:
		var side: float = arm["side"]
		var socket: Node3D = arm["wrist"]
		var wrist := to_local(socket.global_position)
		var shoulder := Vector3(side * 0.24, -0.22, 0.08)
		var offset := wrist - shoulder
		var distance := maxf(offset.length(), 0.001)
		var direction := offset / distance
		# Anatomical two-bone bend plane; elbows stay below/outside the grip,
		# instead of splitting every shoulder-wrist line at its midpoint.
		var pole := Vector3(side * 0.65, -1.0, 0.25)
		var bend := (pole - direction * pole.dot(direction)).normalized()
		var stretch := maxf(1.0, distance / (UPPER_LENGTH + FOREARM_LENGTH - 0.001))
		var upper_len := UPPER_LENGTH * stretch
		var fore_len := FOREARM_LENGTH * stretch
		var along := (upper_len * upper_len - fore_len * fore_len + distance * distance) / (2.0 * distance)
		var height := sqrt(maxf(0.0, upper_len * upper_len - along * along))
		var elbow := shoulder + direction * along + bend * height
		_segment(arm["upper"], shoulder, elbow)
		_segment(arm["forearm"], elbow, wrist)

func _segment(node: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var offset := b - a
	node.position = (a + b) * 0.5
	node.basis = Basis(Quaternion(Vector3.UP, offset.normalized()))
	# Blender sleeves are one metre long along Y, with modelled cloth folds.
	node.scale = Vector3(0.85, maxf(offset.length(), 0.001) + 0.015, 0.85)
