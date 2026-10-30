extends RefCounted

# WorkerThreadPool job: immutable packed-array inputs, no Node/SceneTree,
# rendering/physics API or shared mutable mesh resources on this thread.
const EDGE: float = 0.045
const SAMPLES: int = 48
const BREAK_RATIO: float = 0.65
var inputs: Array = []
var cuts: Array = []
var prepared: Array = []
var profiles: Dictionary = {}
var radius: float = 0.35
var height: float = 18.0
var strength: float = 8.0
var force_cut: float = -1.0
var wood_color: Color
var results: Array = []
var lower: Array = []
var upper: Array = []
var weakest_y: float = 1.3
var remaining_ratio: float = 1.0
var section_ratios: Dictionary = {}
var elapsed_usec: int = 0

func run() -> void:
	var start := Time.get_ticks_usec()
	# Profiles are taken from the actual authored stem, not cfg radius * 0.65.
	for cut in cuts:
		var profile := _profile(float(cut["y"]))
		var actual_radius := 0.0
		for p in profile: actual_radius += Vector2(p.x, p.z).length() / SAMPLES
		var work: float = float(cut.get("work", 1.0)) / maxf(strength, 1.0)
		cut["depth"] = actual_radius * 2.2 * work
		cut["width"] = actual_radius * minf(1.4, 0.8 + 0.6 * work)
		cut["height"] = minf(0.17, 0.115 + float(cut.get("work", 1.0)) * 0.003)
	_update_sections()
	if prepared.is_empty():
		for data in inputs: prepared.append(_prepare(data))
	for data in prepared:
		var damaged:=_damage(data)
		results.append({"arrays":damaged["arrays"],"material":data["material"],"bark":data["bark"]})
		if damaged.has("cut_arrays") and not damaged["cut_arrays"][Mesh.ARRAY_VERTEX].is_empty():
			results.append({"arrays":damaged["cut_arrays"],"material":-1,"bark":true})
	if force_cut >= 0.0 or remaining_ratio <= BREAK_RATIO:
		if force_cut >= 0.0: weakest_y = force_cut
		_split()
	elapsed_usec = Time.get_ticks_usec() - start

func _profile(y: float) -> PackedVector3Array:
	if profiles.has(y): return profiles[y]
	var segments: Array[Vector2] = []
	for data in inputs:
		if not data["bark"]: continue
		var arrays: Array = data["arrays"]
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else v.size()
		var xform: Transform3D = data["transform"]
		for t in range(0, count, 3):
			var tri: Array[Vector3] = []
			for j in 3: tri.append(xform * v[indices[t+j] if not indices.is_empty() else t+j])
			var cross_points: Array[Vector2] = []
			for j in 3:
				var a := tri[j]
				var b := tri[(j+1)%3]
				if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
					var p := a.lerp(b, (y-a.y)/(b.y-a.y))
					cross_points.append(Vector2(p.x,p.z))
			if cross_points.size() == 2:
				segments.append_array(cross_points)
	var result := PackedVector3Array()
	for i in SAMPLES:
		var e := Vector2(cos(TAU*i/SAMPLES),sin(TAU*i/SAMPLES))
		var nearest := INF
		for j in range(0, segments.size(), 2):
			var p := segments[j]
			var s := segments[j+1]-p
			var denom := e.cross(s)
			if absf(denom) < 0.000001: continue
			var t := p.cross(s)/denom
			var u := p.cross(e)/denom
			if t > 0.001 and u >= -0.0001 and u <= 1.0001: nearest = minf(nearest,t)
		if is_inf(nearest): nearest = radius * 0.65
		result.append(Vector3(e.x*nearest,y,e.y*nearest))
	profiles[y] = result
	return result

func _update_sections() -> void:
	var candidates: Dictionary = {}
	for cut in cuts:
		var cy := float(cut["y"])
		candidates[cy] = true
		for i in range(floori((cy-0.18)/0.04), ceili((cy+0.18)/0.04)+1):
			candidates[clampf(i*0.04,0.04,height-0.04)] = true
	for y in candidates:
		var ring := _profile(y)
		var intact_area := 0.0
		var damaged_area := 0.0
		for i in SAMPLES:
			var p: Vector3 = ring[i]
			var q: Vector3 = ring[(i+1)%SAMPLES]
			intact_area += Vector2(p.x,p.z).cross(Vector2(q.x,q.z))
			p = deform(p); q = deform(q)
			damaged_area += Vector2(p.x,p.z).cross(Vector2(q.x,q.z))
		var ratio := absf(damaged_area) / maxf(absf(intact_area),0.000001)
		section_ratios[y] = ratio
		if ratio < remaining_ratio:
			remaining_ratio = ratio
			weakest_y = y

func sample_field(p: Vector3) -> Vector4:
	var r := Vector2(p.x,p.z).length()
	if r < 0.000001:return Vector4.ZERO
	var angle := atan2(p.z,p.x)
	var sample := Vector4.ZERO # depth, d/dr, d/dtheta, d/dy
	for cut in cuts:
		var h := float(cut["height"])
		var dy := p.y-float(cut["y"])
		if absf(dy)>=h:continue
		var phi := wrapf(angle-float(cut["angle"]),-PI,PI)
		var w := float(cut["width"])
		var q := phi*phi*r*r/(w*w)+dy*dy/(h*h)
		if q>=1.0:continue
		var root := sqrt(1.0-q)
		var d := float(cut["depth"])*(1.0-q)*root
		if d>sample.x:
			var slope := -3.0*float(cut["depth"])*root
			sample=Vector4(d,slope*phi*phi*r/(w*w),slope*phi*r*r/(w*w),slope*dy/(h*h))
	if sample.x>=r*0.94:return Vector4(r*0.94,0.94,0,0)
	return sample

func depth_at(p: Vector3) -> float:return sample_field(p).x

func deform(p: Vector3) -> Vector3:
	return p-Vector3(p.x,0,p.z).normalized()*depth_at(p)

func _empty_arrays() -> Array:
	var a: Array = []; a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector3Array(); a[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	a[Mesh.ARRAY_TEX_UV] = PackedVector2Array(); a[Mesh.ARRAY_COLOR] = PackedColorArray()
	return a

func _prepare(data: Dictionary) -> Dictionary:
	var output := _empty_arrays()
	var arrays: Array = data["arrays"]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count := indices.size() if not indices.is_empty() else vertices.size()
	var xform: Transform3D = data["transform"]
	var normal_basis := xform.basis.inverse().transposed()
	for t in range(0,count,3):
		var tri: Array = []
		for j in 3:
			var i := indices[t+j] if not indices.is_empty() else t+j
			tri.append([xform*vertices[i],(normal_basis*normals[i]).normalized(),uvs[i] if i < uvs.size() else Vector2.ZERO,colors[i] if i < colors.size() else Color.WHITE])
		if data["bark"]: _refine(tri,output)
		else: _append_tri(output,tri)
	return {"arrays":output,"bark":data["bark"],"material":data["material"],"bark_color":data["bark_color"]}

func _mid(a: Array, b: Array) -> Array:
	return [(a[0]+b[0])*0.5,(a[1]+b[1]).normalized(),(a[2]+b[2])*0.5,a[3].lerp(b[3],0.5)]

func _refine(tri: Array, output: Array, level: int = 0) -> void:
	var a: Vector3 = tri[0][0]; var b: Vector3 = tri[1][0]; var c: Vector3 = tri[2][0]
	if minf(Vector2(a.x,a.z).length(),minf(Vector2(b.x,b.z).length(),Vector2(c.x,c.z).length())) > radius*1.5:
		_append_tri(output,tri);return
	var near_cut := false
	var lo := minf(a.y,minf(b.y,c.y)); var hi := maxf(a.y,maxf(b.y,c.y))
	for cut in cuts:
		if lo <= float(cut["y"])+0.22 and hi >= float(cut["y"])-0.22: near_cut = true; break
	if force_cut >= 0.0 and lo <= force_cut+0.1 and hi >= force_cut-0.1: near_cut = true
	if not near_cut or level >= 24:
		_append_tri(output,tri); return
	var lengths := [a.distance_squared_to(b),b.distance_squared_to(c),c.distance_squared_to(a)]
	var edge: int = 0
	if lengths[1] > lengths[edge]: edge = 1
	if lengths[2] > lengths[edge]: edge = 2
	if lengths[edge] <= EDGE*EDGE: _append_tri(output,tri); return
	var j := (edge+1)%3; var k := (edge+2)%3
	var midpoint := _mid(tri[edge],tri[j])
	_refine([tri[edge],midpoint,tri[k]],output,level+1)
	_refine([midpoint,tri[j],tri[k]],output,level+1)

func _append_tri(arrays: Array, tri: Array) -> void:
	for v in tri:
		arrays[Mesh.ARRAY_VERTEX].append(v[0]); arrays[Mesh.ARRAY_NORMAL].append(v[1])
		arrays[Mesh.ARRAY_TEX_UV].append(v[2]); arrays[Mesh.ARRAY_COLOR].append(v[3])

func _damage(data: Dictionary) -> Dictionary:
	if not data["bark"]: return {"arrays":data["arrays"],"material":data["material"],"bark":false}
	var arrays: Array = data["arrays"].duplicate()
	var original: PackedVector3Array = data["arrays"][Mesh.ARRAY_VERTEX]
	var v := PackedVector3Array(); var n := PackedVector3Array(); var depths := PackedFloat32Array()
	v.resize(original.size());n.resize(original.size());depths.resize(original.size())
	var source_normals: PackedVector3Array = data["arrays"][Mesh.ARRAY_NORMAL]
	for i in original.size():
		var p := original[i]; var normal := source_normals[i]
		var r := Vector2(p.x,p.z).length()
		var field := sample_field(p) if r<=radius*1.5 else Vector4.ZERO
		var d := field.x
		var radial := Vector3(p.x,0,p.z).normalized()
		v[i] = p-radial*d
		if d > 0.0001:
			# Analytic inverse-transpose Jacobian: one cut-field evaluation,
			# instead of six finite-difference deformations per vertex.
			var tangent := Vector3(-radial.z,0,radial.x)
			var nr := normal.dot(radial)/maxf(0.01,1.0-field.y)
			var nt := (normal.dot(tangent)+nr*field.z/r)/maxf(0.01,1.0-d/r)
			var ny := normal.y+nr*field.w
			normal = (radial*nr+tangent*nt+Vector3.UP*ny).normalized()
		n[i] = normal
		depths[i]=d
	# Never turn the whole stem into a white vertex-colored material. Keep
	# intact triangles on their original surface; exposed notch triangles get
	# the separate species-specific wood material, also used by fracture caps.
	var bark_arrays:=_empty_arrays();var cut_arrays:=_empty_arrays()
	for i in range(0,v.size(),3):
		var tri:Array=[]
		var exposed:=maxf(depths[i],maxf(depths[i+1],depths[i+2]))>0.0005
		for j in 3:
			tri.append([v[i+j],n[i+j],arrays[Mesh.ARRAY_TEX_UV][i+j],arrays[Mesh.ARRAY_COLOR][i+j]])
		_append_tri(cut_arrays if exposed else bark_arrays,tri)
	return {"arrays":bark_arrays,"cut_arrays":cut_arrays,"material":data["material"],"bark":true}

func _split() -> void:
	for data in results:
		var a: Array = data["arrays"]
		var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var low := _empty_arrays(); var high := _empty_arrays()
		for i in range(0,vertices.size(),3):
			var tri: Array = []
			for j in 3: tri.append([vertices[i+j],a[Mesh.ARRAY_NORMAL][i+j],a[Mesh.ARRAY_TEX_UV][i+j],a[Mesh.ARRAY_COLOR][i+j]])
			_clip(tri,low,true);_clip(tri,high,false)
		if not low[Mesh.ARRAY_VERTEX].is_empty(): lower.append({"arrays":low,"material":data["material"],"bark":data["bark"]})
		if not high[Mesh.ARRAY_VERTEX].is_empty(): upper.append({"arrays":high,"material":data["material"],"bark":data["bark"]})
	# The deformed star-shaped stem contour closes both fracture surfaces.
	var ring := _profile(weakest_y)
	var cap_low := _empty_arrays(); var cap_high := _empty_arrays()
	var center := Vector3(0,weakest_y,0)
	for i in SAMPLES:
		var p := deform(ring[i]);var q := deform(ring[(i+1)%SAMPLES])
		_append_tri(cap_low,[[center,Vector3.UP,Vector2.ZERO,wood_color],[q,Vector3.UP,Vector2(q.x,q.z),wood_color],[p,Vector3.UP,Vector2(p.x,p.z),wood_color]])
		_append_tri(cap_high,[[center,Vector3.DOWN,Vector2.ZERO,wood_color],[p,Vector3.DOWN,Vector2(p.x,p.z),wood_color],[q,Vector3.DOWN,Vector2(q.x,q.z),wood_color]])
	lower.append({"arrays":cap_low,"material":-1,"bark":true});upper.append({"arrays":cap_high,"material":-1,"bark":true})

func _clip(tri: Array, output: Array, below: bool) -> void:
	var polygon: Array = []
	for i in 3:
		var a: Array = tri[i];var b: Array = tri[(i+1)%3]
		var inside_a: bool = a[0].y <= weakest_y if below else a[0].y >= weakest_y
		var inside_b: bool = b[0].y <= weakest_y if below else b[0].y >= weakest_y
		if inside_a: polygon.append(a)
		if inside_a != inside_b:
			var t: float = (weakest_y-a[0].y)/(b[0].y-a[0].y)
			polygon.append([a[0].lerp(b[0],t),a[1].lerp(b[1],t).normalized(),a[2].lerp(b[2],t),a[3].lerp(b[3],t)])
	for i in range(1,polygon.size()-1): _append_tri(output,[polygon[0],polygon[i],polygon[i+1]])
