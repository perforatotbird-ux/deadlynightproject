extends Node3D
class_name VoxelTreeTrunk

# Historical class name retained for scene/save compatibility. Damage is now a
# continuous, elliptical displacement of the actual bark, NOT visible cube faces
# or a second oversized cylinder. The original mesh is never modified in-place.
@export var species: String = "birch"
@export var voxel_size: float = 0.04
@export var trunk_radius: float = 0.35
@export var trunk_height: float = 3.2

const MAX_EDGE: float = 0.035
const MAX_CUT_DEPTH_RATIO: float = 0.94
const SPECIES_PALETTES = {
	"birch": {"bark": Color(0.92, 0.90, 0.86), "wood": Color(0.96, 0.96, 0.86)},
	"spruce": {"bark": Color(0.29, 0.22, 0.16), "wood": Color(0.82, 0.41, 0.12)},
	"beech": {"bark": Color(0.48, 0.49, 0.49), "wood": Color(0.93, 0.86, 0.51)},
	"oak": {"bark": Color(0.24, 0.15, 0.10), "wood": Color(0.55, 0.35, 0.17)}
}

var grid_h: int = 0
# Compatibility section counters for callers of the previous trunk component.
# They now estimate remaining wood area, not exposed block faces.
var _layer_solid_counts: PackedInt32Array = PackedInt32Array()
var _layer_initial_counts: PackedInt32Array = PackedInt32Array()
var _mesh_instance: MeshInstance3D = null
var _sources: Array[Dictionary] = []
var _cuts: Array[Dictionary] = []
var _fallback: MeshInstance3D = null
var _mat_wood: StandardMaterial3D
var _prepared: bool = false

func init_trunk(p_species: String, p_radius: float = 0.35, p_height: float = 3.2, p_voxel_size: float = 0.04) -> void:
	species = p_species.to_lower()
	trunk_radius = p_radius
	trunk_height = p_height
	voxel_size = maxf(p_voxel_size, 0.01)
	grid_h = ceili(trunk_height / voxel_size)
	_layer_initial_counts.resize(grid_h)
	_layer_initial_counts.fill(maxi(1, int(PI * pow(trunk_radius / voxel_size, 2))))
	_layer_solid_counts = _layer_initial_counts.duplicate()
	var pal: Dictionary = SPECIES_PALETTES.get(species, SPECIES_PALETTES["birch"])
	_mat_wood = StandardMaterial3D.new()
	_mat_wood.resource_name = "M_Wood_Cut_Smooth_" + species
	_mat_wood.albedo_color = Color.WHITE
	_mat_wood.vertex_color_use_as_albedo = true
	_mat_wood.roughness = 0.85
	# Standalone/missing-asset fallback only. bind_visual() removes it completely.
	_fallback = MeshInstance3D.new()
	_fallback.name = "SmoothTrunkFallback"
	var cylinder := CylinderMesh.new()
	cylinder.height = trunk_height
	cylinder.top_radius = trunk_radius
	cylinder.bottom_radius = trunk_radius
	cylinder.radial_segments = 48
	var bark := StandardMaterial3D.new()
	bark.resource_name = "M_Bark_" + species
	bark.albedo_color = pal["bark"]
	cylinder.material = bark
	_fallback.mesh = cylinder
	_fallback.position.y = trunk_height * 0.5
	add_child(_fallback)
	_mesh_instance = _fallback

func bind_visual(visual: Node3D) -> void:
	_sources.clear()
	_prepared = false
	if visual == null:
		return
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		_sources.append({"node": mi, "original": mi.mesh, "surfaces": []})
	if not _sources.is_empty():
		_mesh_instance = _sources[0]["node"]
		if is_instance_valid(_fallback):
			_fallback.free()
		_fallback = null

func _prepare_sources() -> void:
	if _prepared:
		return
	if _sources.is_empty() and is_instance_valid(_fallback):
		_sources.append({"node": _fallback, "original": _fallback.mesh, "surfaces": []})
	for source in _sources:
		var mi: MeshInstance3D = source["node"]
		var mesh: Mesh = source["original"]
		var xform := global_transform.affine_inverse() * mi.global_transform
		source["surfaces"] = []
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var material := mesh.surface_get_material(s)
			var bark: bool = material != null and "bark" in material.resource_name.to_lower()
			var triangles: Array = []
			if bark:
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var count := indices.size() if not indices.is_empty() else vertices.size()
				for t in range(0, count, 3):
					var tri: Array = []
					for j in 3:
						var i := indices[t + j] if not indices.is_empty() else t + j
						tri.append({"p": xform * vertices[i], "n": (xform.basis.inverse().transposed() * normals[i]).normalized(), "uv": uvs[i] if i < uvs.size() else Vector2.ZERO, "c": colors[i] if i < colors.size() else Color.WHITE})
					_subdivide(tri, triangles)
			source["surfaces"].append({"original": arrays, "material": material, "triangles": triangles, "bark": bark})
	_prepared = true

func _midpoint(a: Dictionary, b: Dictionary) -> Dictionary:
	return {"p": (a["p"] + b["p"]) * 0.5, "n": (a["n"] + b["n"]).normalized(), "uv": (a["uv"] + b["uv"]) * 0.5, "c": a["c"].lerp(b["c"], 0.5)}

func _subdivide(tri: Array, output: Array, level: int = 0) -> void:
	var a: Vector3 = tri[0]["p"]
	var b: Vector3 = tri[1]["p"]
	var c: Vector3 = tri[2]["p"]
	# Keep canopy, branches and the entire upper tree at their original detail.
	var min_y := minf(a.y, minf(b.y, c.y))
	var max_y := maxf(a.y, maxf(b.y, c.y))
	var near_cut := false
	for cut in _cuts:
		if min_y <= float(cut["y"]) + 0.17 + MAX_EDGE and max_y >= float(cut["y"]) - 0.17 - MAX_EDGE:
			near_cut = true
			break
	if not near_cut:
		output.append(tri)
		return
	var min_r := minf(Vector2(a.x, a.z).length(), minf(Vector2(b.x, b.z).length(), Vector2(c.x, c.z).length()))
	if min_y > trunk_height + MAX_EDGE or min_r > trunk_radius * 1.5 or level >= 24:
		output.append(tri)
		return
	var lengths := [a.distance_squared_to(b), b.distance_squared_to(c), c.distance_squared_to(a)]
	var edge: int = 0
	if lengths[1] > lengths[edge]: edge = 1
	if lengths[2] > lengths[edge]: edge = 2
	if lengths[edge] <= MAX_EDGE * MAX_EDGE:
		output.append(tri)
		return
	var i := edge
	var j := (edge + 1) % 3
	var k := (edge + 2) % 3
	var m := _midpoint(tri[i], tri[j])
	_subdivide([tri[i], m, tri[k]], output, level + 1)
	_subdivide([m, tri[j], tri[k]], output, level + 1)

func carve(world_hit_pos: Vector3, world_strike_dir: Vector3, damage: int = 1) -> Dictionary:
	if damage <= 0:
		return {"carved_voxels": 0, "severed": false, "cut_y": 0.0, "remaining_ratio": 1.0}
	var hit := to_local(world_hit_pos)
	var direction := Vector2(hit.x, hit.z)
	# Proximity fallback used to send the tree CENTER, carving the wrong side.
	if direction.length_squared() < 0.0001:
		var local_strike := global_basis.inverse() * world_strike_dir
		direction = -Vector2(local_strike.x, local_strike.z)
	if direction.length_squared() < 0.0001:
		direction = Vector2(0.0, 1.0)
	var angle := direction.angle()
	hit.y = clampf(hit.y, 0.16, trunk_height - 0.16)
	var cut: Dictionary = {}
	for existing in _cuts:
		var arc := absf(wrapf(angle - float(existing["angle"]), -PI, PI)) * trunk_radius
		if arc < 0.075 and absf(hit.y - float(existing["y"])) < 0.065:
			cut = existing
			break
	if cut.is_empty():
		cut = {"angle": angle, "y": hit.y, "depth": 0.0, "width": 0.16, "height": 0.115}
		_cuts.append(cut)
		_prepared = false
	cut["depth"] = minf(float(cut["depth"]) + 0.055 * damage, trunk_radius * 1.5)
	cut["width"] = minf(float(cut["width"]) + 0.006 * damage, 0.25)
	cut["height"] = minf(float(cut["height"]) + 0.003 * damage, 0.17)
	# Reuse refined triangles on repeat strikes; refine again only for new cuts.
	_prepare_sources()
	_rebuild_mesh()
	var removed := _update_sections()
	var layer := clampi(roundi(hit.y / voxel_size), 0, grid_h - 1)
	var ratio := float(_layer_solid_counts[layer]) / float(_layer_initial_counts[layer])
	return {"carved_voxels": removed, "severed": ratio <= 0.28, "cut_y": hit.y, "remaining_ratio": ratio}

func _depth_at(p: Vector3) -> float:
	if p.y < 0.0 or p.y > trunk_height:
		return 0.0
	var radius := Vector2(p.x, p.z).length()
	var angle := atan2(p.z, p.x)
	var depth := 0.0
	for cut in _cuts:
		var dy := (p.y - float(cut["y"])) / float(cut["height"])
		if absf(dy) >= 1.0: continue
		var arc := wrapf(angle - float(cut["angle"]), -PI, PI) * radius / float(cut["width"])
		var q := arc * arc + dy * dy
		if q < 1.0:
			# Elliptical bowl, continuous slope at the rim. No square faces/decals.
			depth = maxf(depth, float(cut["depth"]) * (1.0 - q) * sqrt(1.0 - q))
	return minf(depth, radius * MAX_CUT_DEPTH_RATIO)

func _deform(p: Vector3) -> Vector3:
	var radial := Vector3(p.x, 0.0, p.z)
	return p - radial.normalized() * _depth_at(p)

func _rebuild_mesh() -> void:
	var pal: Dictionary = SPECIES_PALETTES.get(species, SPECIES_PALETTES["birch"])
	for source in _sources:
		var mi: MeshInstance3D = source["node"]
		var inverse := mi.global_transform.affine_inverse() * global_transform
		var result := ArrayMesh.new()
		for surface in source["surfaces"]:
			if not surface["bark"]:
				result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface["original"])
				result.surface_set_material(result.get_surface_count() - 1, surface["material"])
				continue
			var intact := SurfaceTool.new()
			var cut_surface := SurfaceTool.new()
			intact.begin(Mesh.PRIMITIVE_TRIANGLES)
			cut_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var counts := [0, 0]
			for tri in surface["triangles"]:
				var depths := [_depth_at(tri[0]["p"]), _depth_at(tri[1]["p"]), _depth_at(tri[2]["p"])]
				var damaged: bool = maxf(depths[0], maxf(depths[1], depths[2])) > 0.0005
				var st: SurfaceTool = cut_surface if damaged else intact
				for v in tri:
					var p: Vector3 = v["p"]
					var n: Vector3 = v["n"]
					if damaged:
						# Transform the source normal using a numerical deformation Jacobian.
						# This stays smooth across triangle/material boundaries and keeps
						# uncut low-poly facets, rather than rounding the whole tree.
						var tangent := n.cross(Vector3.UP).normalized()
						if tangent.length_squared() < 0.01: tangent = n.cross(Vector3.RIGHT).normalized()
						var bitangent := n.cross(tangent).normalized()
						var dt := _deform(p + tangent * 0.001) - _deform(p - tangent * 0.001)
						var db := _deform(p + bitangent * 0.001) - _deform(p - bitangent * 0.001)
						n = dt.cross(db).normalized()
						var bark_color: Color = pal["bark"]
						var mat: Material = surface["material"]
						if mat is StandardMaterial3D: bark_color = mat.albedo_color
						st.set_color(bark_color.lerp(pal["wood"], smoothstep(0.0005, 0.008, _depth_at(p))))
					else:
						st.set_color(v["c"])
					st.set_normal((inverse.basis.inverse().transposed() * n).normalized())
					st.set_uv(v["uv"])
					st.add_vertex(inverse * _deform(p))
				counts[1 if damaged else 0] += 3
			if counts[0] > 0:
				intact.set_material(surface["material"])
				intact.commit(result)
			if counts[1] > 0:
				cut_surface.set_material(_mat_wood)
				cut_surface.commit(result)
		mi.mesh = result

func _update_sections() -> int:
	var removed := 0
	for y in grid_h:
		var area := 0.0
		# Estimate on the actual model radius, not the old oversized collider.
		var radius := trunk_radius * 0.65
		for i in 48:
			var angle := TAU * i / 48.0
			var p := Vector3(cos(angle) * radius, y * voxel_size, sin(angle) * radius)
			area += pow(1.0 - _depth_at(p) / radius, 2) / 48.0
		var count := roundi(_layer_initial_counts[y] * area)
		removed += maxi(0, _layer_solid_counts[y] - count)
		_layer_solid_counts[y] = count
	return removed

func get_damaged_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for source in _sources:
		meshes.append(source["node"])
	return meshes

func build_stump_mesh(cut_y: float) -> ArrayMesh:
	return _build_slice(0.0, clampf(cut_y, 0.01, trunk_height))

func build_upper_mesh(cut_y: float) -> ArrayMesh:
	return _build_slice(clampf(cut_y, 0.0, trunk_height - 0.01), trunk_height)

func _build_slice(bottom: float, top: float) -> ArrayMesh:
	# Compatibility helper; gameplay still uses its authored stump model.
	var cylinder := CylinderMesh.new()
	cylinder.height = top - bottom
	cylinder.top_radius = trunk_radius
	cylinder.bottom_radius = trunk_radius
	cylinder.radial_segments = 48
	var arrays := cylinder.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		vertices[i] = _deform(vertices[i] + Vector3.UP * (bottom + top) * 0.5)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _mat_wood)
	return mesh
