extends SceneTree
var passes:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,text:String)->void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func settle(n:int=7)->void:
 for i in n:await process_frame
func run()->void:
 var map=load("res://scenes/viewer/MapViewer.tscn").instantiate();root.add_child(map);current_scene=map
 var p=map.get_node("Player");p.set_physics_process(false);await settle()
 var s=map.get_node("SurvivalWorld");s.set_process(false)
 var point:=Vector2(p.global_position.x,p.global_position.z);s.map_model.explore(point)
 var id:int=s.map_model.add_marker(point,"У тропы","route")
 check(id>0,"real forest allows marker at explored player location")
 var manager=load("res://scripts/core/SaveManager.gd").get_instance()
 check(manager.save_game("slot_map_forest","manual","Map QA"),"SaveManager writes forest map to actual disk slot")
 var saved=JSON.parse_string(FileAccess.get_file_as_string("user://saves/slot_map_forest.json"))
 s.map_model.import_state({});manager._apply_loaded_state(saved)
 check(s.map_model.markers.size()==1 and s.map_model.is_revealed(point),"actual disk load restores discoveries and annotations")
 var cells:int=s.map_model.explored.size();s.prepare_travel();change_scene_to_file("res://scenes/mine/MineInterior.tscn");await settle()
 var mine=current_scene.get_node("SurvivalWorld");mine.set_process(false);mine.player.set_physics_process(false)
 check(mine.map_model.markers.size()==1 and mine.map_model.explored.size()==cells,"forest-to-mine transition preserves map without revealing mine coordinates")
 check(mine.map_ui.open_map(),"forest map remains readable inside mine")
 mine.map_ui.close_map()
 check(manager.save_game("slot_map_mine","manual","Mine map QA"),"mine save persists the forest map")
 mine.prepare_travel();change_scene_to_file("res://scenes/viewer/MapViewer.tscn");await settle()
 var forest=current_scene.get_node("SurvivalWorld");forest.set_process(false);forest.player.set_physics_process(false)
 check(forest.map_model.markers.size()==1 and forest.map_model.markers[0].text=="У тропы","return to forest keeps custom annotations")
 check(forest.map_model.explored.size()>=cells,"return never resets explored forest cells")
 print("EXPLORATION MAP WORLD SUMMARY: %d PASS, %d FAIL" % [passes,failures])
 current_scene.free();current_scene=null;await settle();quit(1 if failures else 0)
