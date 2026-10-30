extends SceneTree
func _initialize():call_deferred("run")
func run():
 var baseline="--baseline" in OS.get_cmdline_user_args()
 var output=OS.get_environment("DN_QA_OUTPUT")
 if output=="":output="user://qa"
 DirAccess.make_dir_recursive_absolute(output)
 var manager=load("res://tests/fixtures/SaveManager_3501a69.gd" if baseline else "res://scripts/core/SaveManager.gd").new();root.add_child(manager);manager.set_process(false)
 var scene=load("res://scenes/viewer/MapViewer.tscn").instantiate();root.add_child(scene);current_scene=scene
 var s=scene.get_node("SurvivalWorld");s.set_process(false);s.player.set_physics_process(false)
 await physics_frame;await process_frame
 var registry=load("res://scripts/props/TreeChoppable.gd");var rows=[]
 for count in [0,3,1000]:
  registry.felled_tree_ids.clear();s.picked.clear()
  for i in count:
   var d={"id":"bench_"+str(i),"species":"oak","pos":[1500+i*2,200,-1800],"basis":[1,0,0,0,1,0,0,0,1],"cut_y":1.3,"cuts":[{"angle":1.2,"y":1.3,"work":12.0,"depth":0.4,"width":0.3,"height":0.17}]}
   registry.felled_tree_ids[d.id]=d;registry.felled_tree_ids["alias_"+str(i)]=d;registry.felled_tree_ids["pos_"+str(i)]=d
   for j in 4:s.picked["%d:%d:0"%[i,j]]=true
  for iteration in 6:
   if iteration==0 and count==0:manager.delete_save("bugfix_bench")
   var mem=OS.get_static_memory_usage();var t=Time.get_ticks_usec()
   var ok=manager.save_game("bugfix_bench","manual","Benchmark")
   var total=Time.get_ticks_usec()-t
   var f=FileAccess.open("user://saves/bugfix_bench.json",FileAccess.READ);t=Time.get_ticks_usec();var parsed=JSON.parse_string(f.get_as_text());var parse_us=Time.get_ticks_usec()-t;f.close()
   var apply_us=0
   if iteration==5:
    t=Time.get_ticks_usec();manager._apply_loaded_state(parsed);apply_us=Time.get_ticks_usec()-t
   rows.append({"apply_us":apply_us,"full_load_us":parse_us+apply_us,"count":count,"iteration":iteration,"ok":ok,"total_us":total,"read_parse_us":parse_us,"memory_delta":OS.get_static_memory_usage()-mem,"profile":manager.last_save_profile.duplicate()})
 var out=FileAccess.open(output.path_join("benchmark_")+("before" if baseline else "after")+".json",FileAccess.WRITE);out.store_string(JSON.stringify(rows));out.close()
 manager.delete_save("bugfix_bench");scene.queue_free();await process_frame;print("BENCHMARK COMPLETE baseline=",baseline);quit()
