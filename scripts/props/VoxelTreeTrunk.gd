extends Node3D
class_name VoxelTreeTrunk

signal fracture_ready(lower: ArrayMesh, upper: ArrayMesh, cut_y: float)
signal mesh_updated
const MeshJob = preload("res://scripts/props/TreeCutMeshJob.gd")
const SPECIES_PALETTES = {
	"birch":{"bark":Color(0.92,0.90,0.86),"wood":Color(0.96,0.96,0.86)},
	"spruce":{"bark":Color(0.29,0.22,0.16),"wood":Color(0.82,0.41,0.12)},
	"beech":{"bark":Color(0.48,0.49,0.49),"wood":Color(0.93,0.86,0.51)},
	"oak":{"bark":Color(0.24,0.15,0.10),"wood":Color(0.55,0.35,0.17)}
}
@export var species: String = "birch"
@export var voxel_size: float = 0.04
@export var trunk_radius: float = 0.35
@export var trunk_height: float = 18.0
var strength_hits: int = 8
var grid_h: int
var _layer_initial_counts := PackedInt32Array()
var _layer_solid_counts := PackedInt32Array()
var _cuts: Array = []
var _inputs: Array = []
var _materials: Array[Material] = []
var _prepared: Array = []
var _profiles: Dictionary = {}
var _visual: Node3D
var _mesh_instance: MeshInstance3D
var _fallback: MeshInstance3D
var _wood_material: StandardMaterial3D
var _job: RefCounted
var _task_id: int = -1
var _revision: int = 0
var _job_revision: int = 0
var _force_cut: float = -1.0
var _fractured: bool = false
var weakest_y: float = 1.3
var remaining_ratio: float = 1.0
var last_worker_usec: int = 0
var last_upload_usec: int = 0
var _last_lower: ArrayMesh
var _last_upper: ArrayMesh

func init_trunk(p_species: String, p_radius: float = 0.35, p_height: float = 18.0, p_voxel_size: float = 0.04) -> void:
	species = p_species.to_lower();trunk_radius=p_radius;trunk_height=p_height;voxel_size=maxf(p_voxel_size,0.01)
	grid_h=ceili(trunk_height/voxel_size)
	_layer_initial_counts.resize(grid_h);_layer_initial_counts.fill(10000)
	_layer_solid_counts=_layer_initial_counts.duplicate()
	_wood_material=StandardMaterial3D.new()
	_wood_material.resource_name="M_Wood_Cut_"+species
	_wood_material.albedo_color=Color.WHITE;_wood_material.vertex_color_use_as_albedo=true
	_wood_material.roughness=0.9
	_fallback=MeshInstance3D.new()
	var cylinder:=CylinderMesh.new();cylinder.height=trunk_height;cylinder.top_radius=trunk_radius;cylinder.bottom_radius=trunk_radius;cylinder.radial_segments=32
	var material:=StandardMaterial3D.new();material.resource_name="M_Bark_"+species;material.albedo_color=SPECIES_PALETTES.get(species,SPECIES_PALETTES["birch"])["bark"]
	cylinder.material=material;_fallback.mesh=cylinder;_fallback.position.y=trunk_height*0.5
	add_child(_fallback);_mesh_instance=_fallback
	set_process(false)

func bind_visual(visual: Node3D) -> void:
	_visual=visual;_inputs.clear();_materials.clear();_prepared.clear();_profiles.clear()
	if is_instance_valid(_fallback): _fallback.free();_fallback=null
	if not is_instance_valid(_mesh_instance): _mesh_instance=null
	for child in visual.find_children("*","MeshInstance3D",true,false): _snapshot(child)
	if not _inputs.is_empty():
		_mesh_instance=MeshInstance3D.new();_mesh_instance.name="DamagedTreeMesh";add_child(_mesh_instance)

func _snapshot(mi: MeshInstance3D) -> void:
	if mi.mesh==null:return
	var xform:=global_transform.affine_inverse()*mi.global_transform
	for i in mi.mesh.get_surface_count():
		var material:=mi.get_active_material(i)
		var bark:bool=material!=null and "bark" in material.resource_name.to_lower()
		var color:Color=SPECIES_PALETTES.get(species,SPECIES_PALETTES["birch"])["bark"]
		if bark and material is StandardMaterial3D:
			color=material.albedo_color
			material=material.duplicate();material.albedo_color=Color.WHITE;material.vertex_color_use_as_albedo=true
		var material_index:=_materials.size();_materials.append(material)
		_inputs.append({"arrays":mi.mesh.surface_get_arrays(i),"transform":xform,"bark":bark,"material":material_index,"bark_color":color})

func carve(world_hit_pos: Vector3, world_strike_dir: Vector3, damage: int = 1) -> Dictionary:
	if damage<=0 or _fractured:return {"queued":false,"severed":_fractured,"cut_y":weakest_y,"remaining_ratio":remaining_ratio,"carved_voxels":0}
	var hit:=to_local(world_hit_pos)
	hit.y=clampf(hit.y,0.12,trunk_height-0.12)
	var radial:=Vector2(hit.x,hit.z)
	if radial.length_squared()<0.0001:
		var strike:=global_basis.inverse()*world_strike_dir;radial=-Vector2(strike.x,strike.z)
	if radial.length_squared()<0.0001:radial=Vector2(0,1)
	var angle:=radial.angle()
	var cut:Dictionary={}
	for existing in _cuts:
		if absf(wrapf(angle-float(existing["angle"]),-PI,PI))*trunk_radius<0.075 and absf(hit.y-float(existing["y"]))<0.065:cut=existing;break
	if cut.is_empty():
		cut={"angle":angle,"y":hit.y,"work":0.0,"depth":0.0,"width":0.16,"height":0.12}
		_cuts.append(cut);_prepared=[]
	cut["work"]=float(cut["work"])+damage
	# Cheap prediction only. Exact shape/remaining area comes back from worker.
	cut["depth"]=float(cut["depth"])+0.055*damage
	_revision+=1;_schedule()
	return {"queued":true,"severed":false,"cut_y":weakest_y,"remaining_ratio":remaining_ratio,"carved_voxels":damage}

func request_fracture(cut_y: float = -1.0) -> void:
	_force_cut=clampf(cut_y if cut_y>=0 else weakest_y,0.12,trunk_height-0.12)
	_prepared=[];_revision+=1;_schedule()

func restore_cuts(saved: Array) -> void:
	_cuts=saved.duplicate(true);_prepared=[];_revision+=1

func _schedule() -> void:
	if _task_id>=0 or _fractured:return
	if _inputs.is_empty() and is_instance_valid(_fallback):_snapshot(_fallback)
	_job=MeshJob.new();_job.inputs=_inputs;_job.cuts=_cuts.duplicate(true)
	_job.prepared=_prepared;_job.profiles=_profiles.duplicate()
	_job.radius=trunk_radius;_job.height=trunk_height;_job.strength=strength_hits
	_job.wood_color=SPECIES_PALETTES.get(species,SPECIES_PALETTES["birch"])["wood"]
	_job.force_cut=_force_cut;_job_revision=_revision
	_task_id=WorkerThreadPool.add_task(_job.run,false,"Tree cut / fracture")
	set_process(true)

func _process(_delta: float) -> void:
	if _task_id<0 or not WorkerThreadPool.is_task_completed(_task_id):return
	WorkerThreadPool.wait_for_task_completion(_task_id);_task_id=-1
	var job=_job;_job=null
	_profiles=job.profiles;last_worker_usec=job.elapsed_usec
	if _job_revision!=_revision:
		# Never display a stale hit over a newer one. Inputs/cache are immutable.
		_schedule();return
	_cuts=job.cuts;_prepared=job.prepared;weakest_y=job.weakest_y;remaining_ratio=job.remaining_ratio
	for y in job.section_ratios:
		var index:=clampi(roundi(y/voxel_size),0,grid_h-1)
		_layer_solid_counts[index]=roundi(10000*job.section_ratios[y])
	var start:=Time.get_ticks_usec()
	if not job.lower.is_empty():
		_last_lower=_make_mesh(job.lower);_last_upper=_make_mesh(job.upper)
		_fractured=true;set_process(false)
		fracture_ready.emit(_last_lower,_last_upper,weakest_y)
	else:
		_mesh_instance.transform=Transform3D.IDENTITY
		_mesh_instance.mesh=_make_mesh(job.results)
		if is_instance_valid(_visual):_visual.hide()
		last_upload_usec=Time.get_ticks_usec()-start
		set_process(false);mesh_updated.emit()

func _make_mesh(data: Array) -> ArrayMesh:
	var mesh:=ArrayMesh.new()
	for surface in data:
		if surface["arrays"][Mesh.ARRAY_VERTEX].is_empty():continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface["arrays"])
		mesh.surface_set_material(mesh.get_surface_count()-1,_materials[surface["material"]] if surface["material"]>=0 else _wood_material)
	return mesh

func is_busy() -> bool:return _task_id>=0
func export_cuts() -> Array:return _cuts.duplicate(true)
func _depth_at(p: Vector3) -> float:
	var r:=Vector2(p.x,p.z).length();var angle:=atan2(p.z,p.x);var d:=0.0
	for cut in _cuts:
		var dy:float=(p.y-float(cut["y"]))/float(cut["height"])
		if absf(dy)>=1:continue
		var dx:float=wrapf(angle-float(cut["angle"]),-PI,PI)*r/float(cut["width"])
		var q:=dx*dx+dy*dy
		if q<1:d=maxf(d,float(cut["depth"])*(1-q)*sqrt(1-q))
	return minf(d,r*0.94)
func _deform(p: Vector3) -> Vector3:return p-Vector3(p.x,0,p.z).normalized()*_depth_at(p)
func project_hit(world_point: Vector3) -> Vector3:return to_global(_deform(to_local(world_point)))
func get_damaged_meshes() -> Array[MeshInstance3D]:return [_mesh_instance]
func build_stump_mesh(_cut_y: float) -> ArrayMesh:return _last_lower
func build_upper_mesh(_cut_y: float) -> ArrayMesh:return _last_upper

func _exit_tree() -> void:
	if _task_id >= 0:
		var reaper = preload("res://scripts/props/TreeCutTaskReaper.gd").new()
		reaper.task_id = _task_id
		reaper.job = _job
		get_tree().root.add_child.call_deferred(reaper)
		_task_id = -1
		_job = null
