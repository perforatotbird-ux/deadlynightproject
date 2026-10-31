extends SceneTree
# Deliberately saturated QA fixture; never used by normal placement or gameplay.
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/viewer/MapViewer.tscn").instantiate();root.add_child(game);current_scene=game
 var s=game.get_node("SurvivalWorld");var p=s.player;var v=s.vegetation
 p.set_physics_process(false);s.set_process(false);v.set_physics_process(false);await physics_frame;await process_frame
 var records:Array=[];var center:=Vector2i(floori(p.global_position.x/48),floori(p.global_position.z/48))
 for i in 192:
  var position:Vector3=p.global_position+Vector3(cos(i*2.4)*8,0,sin(i*2.4)*8)
  records.append({"id":"stress_fixture:"+str(i),"species":"krasnitsa","pos":[position.x,position.y,position.z],"yaw":0.0})
  if i%2==0:v.harvested["stress_fixture:"+str(i)+":0"]=true
 v.import_state({"patches":{"%d:%d"%[center.x,center.y]:records},"harvested":v.harvested})
 var samples:Array=[]
 for i in 16:v.stream();samples.append(v.last_profile.duplicate());await physics_frame
 var start:=Time.get_ticks_usec();var encoded:=JSON.stringify(v.export_state());var encoding_us:=Time.get_ticks_usec()-start
 var sm=load("res://scripts/core/SaveManager.gd").get_instance();start=Time.get_ticks_usec();var ok:bool=sm.save_game("vegetation_stress_qa","manual","QA stress fixture");var save_us:=Time.get_ticks_usec()-start
 var report:={"fixture":"192 berry bushes inside active radius, half with harvested group; intentionally denser than world placement","samples":samples,"state_bytes_utf8":encoded.to_utf8_buffer().size(),"json_encoding_us":encoding_us,"full_save_ok":ok,"full_save_us":save_us,"save_pipeline":sm.last_save_profile}
 print("VEGETATION STRESS: ",JSON.stringify(report))
 sm.delete_save("vegetation_stress_qa");var valid:bool=v.active.size()==96 and ok
 current_scene=null;game.free();await process_frame;quit(0 if valid else 1)
