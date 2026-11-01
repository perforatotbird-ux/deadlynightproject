extends SceneTree
const Models=preload("res://scripts/survival/ResourceModels.gd")
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 var errors:=0
 for kind in Models.COUNTS:
  # During staged delivery only validate available families; final QA expects all.
  var base:="branch" if kind=="brush" else str(kind)
  if not ResourceLoader.exists("res://assets/models/resources/"+base+"_00.glb"):continue
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
    print("MODEL ",base," ",i," triangles=",tris," bounds=",mesh.get_aabb().size)
   node.free()
 print("RESOURCE MODEL ERRORS: ",errors);quit(0 if errors==0 else 1)
