extends SceneTree
var failures:=0
var count:=0
func _initialize() -> void:
 scan("res://scripts")
 print("SCRIPT AUDIT: %d scripts, %d failures" % [count,failures]);quit(1 if failures else 0)
func scan(path: String) -> void:
 for file in DirAccess.get_files_at(path):
  if file.ends_with(".gd"):
   count+=1
   var script=load(path.path_join(file))
   if script==null or not script.can_instantiate():failures+=1;print("FAIL SCRIPT: "+path.path_join(file))
 for dir in DirAccess.get_directories_at(path):scan(path.path_join(dir))
