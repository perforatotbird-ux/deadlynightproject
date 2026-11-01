extends SceneTree
const Models=preload("res://scripts/survival/ResourceModels.gd")
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 var errors:=0
 var report:Dictionary={}
 var require_all:=OS.get_cmdline_user_args().has("--require-all")
 for kind in Models.COUNTS:
  # During staged delivery only validate available families; final QA expects all.
  var base:="branch" if kind=="brush" else str(kind)
  if not ResourceLoader.exists("res://assets/models/resources/"+base+"_00.glb"):
   if require_all:errors+=1;push_error("Missing family: "+base)
   continue
  var shared:=Models.mesh(str(kind),"runtime-check")
  if shared==null or not shared.surface_get_material(0).vertex_color_use_as_albedo:errors+=1
  if shared!=Models.mesh(str(kind),"runtime-check"):errors+=1
  for i in int(Models.COUNTS[kind]):
   var packed:=load("res://assets/models/resources/%s_%02d.glb"%[base,i]) as PackedScene
   if packed==null:errors+=1;continue
   var node:=packed.instantiate();var mesh:=Models._find(node)
   if mesh==null or mesh.get_surface_count()!=1:errors+=1
   else:
    var a:=mesh.surface_get_arrays(0);var inds:PackedInt32Array=a[Mesh.ARRAY_INDEX]
    var tris:=inds.size()/3
    if tris<500 or tris>10000:errors+=1
    if mesh.get_aabb().size.length()<0.1:errors+=1
    if a[Mesh.ARRAY_TEX_UV]==null or a[Mesh.ARRAY_COLOR]==null:errors+=1
    var data:=RenderingServer.mesh_get_surface(mesh.get_rid(),0)
    var lod_triangles:Array=[]
    var index_width:int=data.index_data.size()/data.index_count
    for lod in data.get("lods",[]):lod_triangles.append(lod.index_data.size()/index_width/3)
    if lod_triangles.is_empty():errors+=1
    report["%s_%02d"%[base,i]]={"triangles":tris,"lod_triangles":lod_triangles,"surfaces":mesh.get_surface_count(),"bounds_m":[mesh.get_aabb().size.x,mesh.get_aabb().size.y,mesh.get_aabb().size.z]}
    print("MODEL ",base," ",i," triangles=",tris," LODs=",lod_triangles)
   node.free()
 # Real pickup initialization exercises visuals and collider bounds, no survival state required.
 for kind in ["stone","pyrite","flint","brush"]:
  var pickup:=preload("res://scripts/survival/ResourcePickup.gd").new()
  pickup.item_data={"type":kind};pickup.resource_id="qa-"+kind;root.add_child(pickup)
  var visual:MeshInstance3D=null;var collider:CollisionShape3D=null
  for child in pickup.get_children():
   if child is MeshInstance3D:visual=child
   if child is CollisionShape3D:collider=child
  if visual==null or collider==null:errors+=1
  elif visual.mesh!=Models.mesh(kind,pickup.resource_id):errors+=1
  elif collider.shape.size.x<visual.mesh.get_aabb().size.x:errors+=1
  pickup.free()
 var report_path:=OS.get_environment("RESOURCE_QA_REPORT")
 if not report_path.is_empty():
  var file:=FileAccess.open(report_path,FileAccess.WRITE);file.store_string(JSON.stringify(report," "))
 print("RESOURCE MODEL ERRORS: ",errors);quit(0 if errors==0 else 1)
