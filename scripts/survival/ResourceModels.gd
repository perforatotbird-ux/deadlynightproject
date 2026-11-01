extends RefCounted
## Shared authored mid-poly meshes. Deterministic variants; no per-frame loading.
const COUNTS={"stone":4,"pyrite":3,"flint":3,"brush":5,"forest_fat":2,"wood_fan":2,"copper_false":2,"pale_bell":2,"stump_fan":2}
static var cache:Dictionary={}
static func mesh(kind:String,seed_key:String="") -> ArrayMesh:
 if not COUNTS.has(kind):return null
 var variant:=posmod(seed_key.hash(),int(COUNTS[kind])) if not seed_key.is_empty() else 0
 var name:="branch" if kind=="brush" else kind
 var key:="%s_%02d"%[name,variant]
 if cache.has(key):return cache[key]
 var path:="res://assets/models/resources/"+key+".glb"
 if not ResourceLoader.exists(path):return null
 var packed:=load(path) as PackedScene
 if packed==null:return null
 var root:=packed.instantiate()
 var found:ArrayMesh=_find(root)
 root.free()
 if found!=null:
  for surface in found.get_surface_count():
   var material:=found.surface_get_material(surface) as StandardMaterial3D
   if material!=null:
    material.vertex_color_use_as_albedo=true
    material.cull_mode=BaseMaterial3D.CULL_BACK
  cache[key]=found
 return found
static func _find(node:Node) -> ArrayMesh:
 if node is MeshInstance3D and node.mesh is ArrayMesh:return node.mesh
 for child in node.get_children():
  var found:=_find(child)
  if found!=null:return found
 return null
