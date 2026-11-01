extends SceneTree
# No gameplay/profile mutations: catch dependencies the editor importer may not compile.
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 if ok:print("[LaunchCheck] OK: "+message)
 else:failures+=1;printerr("[LaunchCheck] FAIL: "+message)
func run()->void:
 print("[LaunchCheck] Godot "+Engine.get_version_info().get("string","unknown"))
 for path in ["res://scripts/player/PlayerController.gd","res://scripts/player/WatchArm.gd","res://scripts/survival/SurvivalWorld.gd","res://scripts/viewer/MapViewer.gd"]:
  var script=load(path)
  check(script is Script and script.can_instantiate(),"script compiles: "+path)
 var player_scene=load("res://scenes/player/Player.tscn")
 check(player_scene is PackedScene,"player scene loads")
 if player_scene is PackedScene:
  var player=player_scene.instantiate()
  check(player!=null and player.has_method("set_active"),"player controller is attached")
  if player!=null:player.free()
 var path:="res://assets/models/viewmodels/watch/left_arm_round_watch.glb"
 var model=load(path) if ResourceLoader.exists(path) else null
 check(model is PackedScene,"watch GLB and its import cache load")
 if model is PackedScene:
  var arm=model.instantiate()
  check(arm is Node3D and arm.find_child("DisplayAnchor",true,false)!=null,"watch display anchor exists")
  check(arm.find_child("LeftArm_Skin",true,false) is MeshInstance3D,"watch skin mesh exists")
  arm.free()
 print("[LaunchCheck] "+("READY" if failures==0 else "FAILED: "+str(failures)))
 quit(0 if failures==0 else 1)
