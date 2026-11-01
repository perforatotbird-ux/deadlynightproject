@tool
extends SceneTree
## Bake authored LOD topology into one ArrayMesh, usable by both MultiMesh and cutting.
## godot --headless --path . --script tools/lolipop_birch/bake_lods.gd
const DIR := "res://assets/models/external/lolipop/"
func _initialize() -> void:
 for variant in 5:
  var nodes: Array[Node] = []
  var meshes: Array[Mesh] = []
  for level in 3:
   var instance: Node = load(DIR+"birch_%d_lod%d.glb"%[variant,level]).instantiate()
   nodes.append(instance)
   var source: MeshInstance3D = instance.find_children("*", "MeshInstance3D", true, false)[0]
   meshes.append(source.mesh)
  var result := ArrayMesh.new()
  result.resource_name="LOLIPOP_Birch_%d"%variant
  var triangle_counts := [0,0,0]
  for surface in meshes[0].get_surface_count():
   var arrays: Array = meshes[0].surface_get_arrays(surface)
   var lods: Dictionary = {}
   for level in 3:
    var source: Array = meshes[level].surface_get_arrays(surface)
    var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
    triangle_counts[level]+=indices.size()/3
    if level==0: continue
    var offset: int = arrays[Mesh.ARRAY_VERTEX].size()
    for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
     if arrays[channel]!=null and source[channel]!=null:arrays[channel].append_array(source[channel])
    if arrays[Mesh.ARRAY_COLOR]!=null:
     if source[Mesh.ARRAY_COLOR]!=null:arrays[Mesh.ARRAY_COLOR].append_array(source[Mesh.ARRAY_COLOR])
     else:
      var white:=PackedColorArray();white.resize(source[Mesh.ARRAY_VERTEX].size());white.fill(Color.WHITE);arrays[Mesh.ARRAY_COLOR].append_array(white)
    var remapped:=PackedInt32Array()
    for index in indices:remapped.append(index+offset)
    if remapped.size()<arrays[Mesh.ARRAY_INDEX].size():lods[0.04 if level==1 else 0.12]=remapped
   result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],lods)
   var material: StandardMaterial3D=meshes[0].surface_get_material(surface).duplicate()
   material.normal_enabled=arrays[Mesh.ARRAY_TANGENT]!=null
   result.surface_set_material(surface,material)
  result.set_meta("author","LOLIPOP (@lolipop_1707)")
  result.set_meta("authored_lod_triangles",triangle_counts)
  assert(ResourceSaver.save(result,DIR+"birch_%d.res"%variant)==OK)
  var root_node:=Node3D.new();root_node.name="LOLIPOP_Birch_%d"%variant
  var visual:=MeshInstance3D.new();visual.name="BirchMesh";visual.mesh=load(DIR+"birch_%d.res"%variant);root_node.add_child(visual);visual.owner=root_node
  var scene:=PackedScene.new();assert(scene.pack(root_node)==OK)
  assert(ResourceSaver.save(scene,DIR+"birch_%d.tscn"%variant)==OK)
  print("BIRCH BAKE ",variant,": ",triangle_counts)
  root_node.free()
  for node in nodes:node.free()
 quit()
