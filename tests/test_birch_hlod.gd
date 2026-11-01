extends SceneTree
const Forest=preload("res://scripts/world/BirchForest.gd")
const Trees=preload("res://scripts/props/TreeChoppable.gd")
class EmptyWorld extends "res://scripts/world/WorldMap.gd":
 func _ready()->void:pass
var passes:=0
var failures:=0
func check(ok:bool,label:String)->void:
 if ok:passes+=1;print("PASS: ",label)
 else:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var world:=EmptyWorld.new();root.add_child(world);world.set_process(false)
 world._load_tree_models();Trees.felled_tree_ids.clear();world._load_vegetation();world._setup_dynamic_trees()
 var forest:RefCounted=world._birch_forest
 var birches:=0;var interactions:=0
 for records in world._interaction_cells.values():interactions+=records.size()
 check(interactions==55430,"every non-tutorial record in 32m interaction grid")
 var bounds_ok:=true;var transforms_ok:=true
 for id in world._tree_mmi_index:
  var d:Dictionary=world._tree_mmi_index[id]
  if not d.has("far_mm"):continue
  birches+=1
  var pos:Vector3=d.far_xform.origin
  bounds_ok=bounds_ok and d.far_mm.custom_aabb.has_point(pos+Vector3(0,18*d.far_xform.basis.x.length(),0))
  var center:=Vector3((d.cell.x+0.5)*Forest.CELL_SIZE,0,(d.cell.y+0.5)*Forest.CELL_SIZE)
  transforms_ok=transforms_ok and (d.xform.origin+center).is_equal_approx(pos)
 check(birches==14758,"all 14758 scattered birches have paired near/far representation")
 check(bounds_ok,"rotating impostor bounds contain tree tops")
 check(transforms_ok,"128m detail batches rebase transforms without moving trees")
 var id:String=""
 for candidate in world._tree_mmi_index:
  if world._tree_mmi_index[candidate].has("far_mm"):id=candidate;break
 var d:Dictionary=world._tree_mmi_index[id];var pos:Vector3=d.far_xform.origin
 forest.update(pos,world._tree_mmi_index,world._hidden_tree_ids,true)
 check(d.near,"nearby tree selects authored detailed geometry")
 var active_before:int=forest.active.size()
 forest.update(pos+Vector3(1,0,0),world._tree_mmi_index,world._hidden_tree_ids)
 check(forest.active.size()==active_before,"stationary/small-motion frame skips world-cell traversal")
 world._set_mmi_tree_scale(id,0.0)
 check(world._hidden_tree_ids.has(id) and d.near,"interactive hide preserves active cell state")
 native_check(d,true,true,"interactive hide masks both render representations")
 forest.update(pos+Vector3(1000,0,1000),world._tree_mmi_index,world._hidden_tree_ids,true)
 check(not d.near and world._hidden_tree_ids.has(id),"teleport demotes cell without reviving hidden tree")
 native_check(d,true,true,"hidden tree remains absent after demotion")
 world._restore_mmi_tree_scale(id)
 native_check(d,true,false,"restore far tree only, no doubled detail")
 check(not world._hidden_tree_ids.has(id),"visibility registry restored")
 forest.update(pos,world._tree_mmi_index,world._hidden_tree_ids,true)
 native_check(d,false,true,"promotion swaps far for exactly one detailed tree")
 var cell:Vector2i=d.cell;var cell_center:=Vector3((cell.x+0.5)*Forest.CELL_SIZE,pos.y,(cell.y+0.5)*Forest.CELL_SIZE)
 forest.update(cell_center+Vector3(270,0,0),world._tree_mmi_index,world._hidden_tree_ids,true)
 check(d.near,"hysteresis retains active tree inside leave radius")
 forest.update(cell_center+Vector3(370,0,0),world._tree_mmi_index,world._hidden_tree_ids,true)
 check(not d.near,"cell demotes beyond leave radius")
 world._update_nearby_trees(pos)
 check(world._last_candidate_count>0 and world._last_candidate_count<200,"interaction lookup examines local records, not nine 250m chunks")
 print("LOCAL_CANDIDATES ",world._last_candidate_count)
 for tree in world._dynamic_trees.values():tree.free()
 world._dynamic_trees.clear();world.free();await process_frame
 print("BIRCH HLOD SUMMARY: %d PASS, %d FAIL"%[passes,failures]);quit(1 if failures else 0)
func native_check(d:Dictionary,near_hidden:bool,far_hidden:bool,label:String)->void:
 if DisplayServer.get_name()=="headless":return
 var near:Transform3D=d.mm.get_instance_transform(d.index)
 var far:Transform3D=d.far_mm.get_instance_transform(d.far_index)
 check(is_zero_approx(near.basis.determinant())==near_hidden and is_zero_approx(far.basis.determinant())==far_hidden,label)
