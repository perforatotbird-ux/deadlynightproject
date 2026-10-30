extends SceneTree
var failures:=0
var passes:=0
var output_dir:="/data/backpack-craft-previews"
var graphical:=false
func _initialize() -> void:call_deferred("run")
func check(ok: bool, text: String) -> void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func settle(frames: int=4) -> void:
 for i in frames:await process_frame
func key(code: Key) -> void:
 var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;root.push_input(e,true);await process_frame
 e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=false;root.push_input(e,true);await process_frame
func click(button: Button) -> void:
 var pos:=button.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new();motion.position=pos;motion.global_position=pos;root.push_input(motion,true)
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=pos;e.global_position=pos;e.pressed=true;root.push_input(e,true);await process_frame
 e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=pos;e.global_position=pos;e.pressed=false;root.push_input(e,true);await process_frame
func capture(label: String) -> void:
 if not graphical:return
 var survival=current_scene.get_node_or_null("SurvivalWorld")
 if survival:survival.ui.refresh()
 await settle(3);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output_dir.path_join(label+".png"))
func limit_preview(scene: Node) -> void:
 # llvmpipe QA only: retain real physics, nearby authored trees and cabin,
 # but hide distant scatter/terrain. This is NOT an FPS benchmark.
 if scene==null:return
 var player=scene.get_node_or_null("Player")
 if player:player.set_physics_process(false)
 if not graphical:return
 for n in scene.find_children("*","MultiMeshInstance3D",true,false):n.hide()
 for n in scene.find_children("*","Camera3D",true,false):n.far=150
 var sun=scene.get_node_or_null("DirectionalLight3D")
 if sun:sun.shadow_enabled=false
 var terrain=scene.get_node_or_null("WorldMap/Terrain")
 if terrain:
  for n in terrain.find_children("*","MeshInstance3D",true,false):
   var center:Vector3=n.global_transform*n.mesh.get_aabb().get_center()
   if Vector2(center.x+900,center.z-1100).length()>450:n.hide()
func run() -> void:
 graphical=DisplayServer.get_name()!="headless"
 if graphical:DirAccess.make_dir_recursive_absolute(output_dir);root.size=Vector2i(1280,720)
 var scene=load("res://scenes/viewer/MapViewer.tscn").instantiate();root.add_child(scene);current_scene=scene;limit_preview(scene)
 scene_changed.connect(func():limit_preview(current_scene))
 await settle(5)
 var p=scene.get_node("Player");var s=scene.get_node("SurvivalWorld");s.set_process(false);p.set_physics_process(false)
 check(s.player==p and p.survival==s,"real MapViewer / Player integration")
 check(s.resources.size()>0,"real terrain spawns gatherable resources")
 check(s.shelter.global_position.distance_to(p.global_position)<30,"physical first-night cabin near spawn")
 for id in ["stone","brush","flint","pyrite"]:
  var item=s.Items.item(id);item["count"]=6 if id in ["stone","brush"] else 1;s.Items.transact(p,{},[item])
 p._add_to_backpack({"species":"birch","weight":4.0})
 await key(KEY_TAB)
 check(p._is_inventory_open and p._is_inventory_open,"Tab opens the actual backpack through real input")
 p._backpack_ui.tabs.current_tab=1;p._backpack_ui.select_recipe("camp_kit");await settle()
 await capture("01_crafting_panel")
 await click(p._backpack_ui.buttons["kit"])
 check(s.Items.count(p.inventory_slots,"camp_kit")==1,"real mouse click reaches craft button")
 await key(KEY_ESCAPE)
 check(not p._is_inventory_open and not p._is_inventory_open,"Escape closes backpack and releases player")
 var target:Vector3=p.global_position+Vector3(3,0,2)
 var ground=p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(target+Vector3.UP*5,target-Vector3.UP*5,1))
 check(not ground.is_empty() and ground.collider.is_in_group("camp_ground"),"authored terrain tagged as valid ground")
 s.begin_placement();s.placement=s.validate_placement(ground.position,ground.normal,ground.collider)
 check(s.placement["ok"],"real forest placement passes physical checks")
 check(s.confirm_placement(),"place fire in real forest")
 var f:Dictionary=s.fires[0];p.global_position=Vector3(ground.position.x,ground.position.y+0.1,ground.position.z+2.0)
 s.selected_fire=f["id"]
 s.cancel_job();s.open_backpack(f["id"]);p.select_hotbar_slot(1)
 p._backpack_ui.tabs.current_tab=1;p._backpack_ui.select_recipe("split_birch");await settle()
 await capture("01b_selected_log")
 await click(p._backpack_ui.buttons["split"])
 check(s.job.get("kind")=="split" and p.active_hotbar_slot==0,"mouse split from backpack auto-equips axe")
 await capture("01c_split_progress")
 s.advance(10)
 for i in p.inventory_slots.size():
  if p.inventory_slots[i]!=null and p.inventory_slots[i].get("type")=="firewood":s.add_fuel(f["id"],i);break
 s.open_backpack(f["id"]);await capture("02_ready_to_ignite")
 s.begin_ignition(f["id"],"match");s.job["success"]=true;s.advance(2);s.close_backpack()
 check(f["state"]=="burning","real forest camp successfully burns")
 s.clock=20.5*3600;s.weather="clear";s.weather_until=s.clock+100000;s._update_lighting()
 p.rotation=Vector3.ZERO;p._camera_pitch=-0.32;p._camera_pivot.rotation.x=-0.32
 await capture("03_night_campfire")
 # Point toward the cabin, then inspect the interior near the cot.
 p.global_position=s.shelter.global_position+Vector3(0,0.2,1.2);p.rotation=Vector3.ZERO;p._camera_pivot.rotation.x=-0.25;p.select_hotbar_slot(1);p._toggle_lantern()
 check(s.safe_shelter(),"player enters actual physical shelter")
 await capture("04_shelter_interior")
 s.open_sleep(s.shelter.bed);await capture("05_rest_panel")
 if graphical:
  root.size=Vector2i(800,600);await settle();p._backpack_ui.resize();await capture("06_small_window")
  check(p._inv_root_panel.get_global_rect().end.x<=root.get_visible_rect().size.x and p._inv_root_panel.get_global_rect().end.y<=root.get_visible_rect().size.y,"modal fits smaller window")
  root.size=Vector2i(1280,720);await settle()
 for i in p.inventory_slots.size():
  if p.inventory_slots[i]!=null and p.inventory_slots[i].get("type")=="brush":p.assign_belt_item(i,2);break
 s.close_backpack()
 # Save/load while in the real scene, including an in-progress split/ignition already covered by units.
 var sm=load("res://scripts/core/SaveManager.gd").get_instance()
 s.matches=2;check(sm.save_game("slot_first_night_full","manual","Integration"),"full-scene SaveManager writes")
 var payload=JSON.parse_string(FileAccess.get_file_as_string("user://saves/slot_first_night_full.json"))
 s.matches=9;sm._apply_loaded_state(payload);check(s.matches==2 and s.fires.size()==1,"full-scene load restores survival once")
 # Real forest → mine → forest transition, not a mocked snapshot.
 s.shelter.set_door(false) # Exterior door state must survive a scene without a cabin.
 var exterior_fire_fuel:float=s.fires[0]["fuel"]
 s.prepare_travel();change_scene_to_file("res://scenes/mine/MineInterior.tscn")
 await settle(6)
 var mine=current_scene;var ms=mine.get_node("SurvivalWorld");ms.set_process(false);ms.player.set_physics_process(false)
 check(ms.location=="mine" and ms.matches==2,"mine retains match count and session")
 check(ms.player.belt_items[2]=="brush","mine retains crafted belt binding")
 check(ms.Items.count(ms.player.inventory_slots,"firewood")==2,"mine retains actual backpack")
 ms.advance(10)
 check(ms.fires[0]["fuel"]<exterior_fire_fuel,"outside camp keeps burning while player is in mine")
 check(sm.save_game("slot_first_night_mine","manual","Mine persistence"),"save inside mine")
 var mine_payload=JSON.parse_string(FileAccess.get_file_as_string("user://saves/slot_first_night_mine.json"))
 check(mine_payload["world"]["survival"]["location"]=="mine","save identifies interior location")
 var after_mine:float=ms.clock
 ms.prepare_travel();change_scene_to_file("res://scenes/viewer/MapViewer.tscn")
 await settle(6)
 var fs=current_scene.get_node("SurvivalWorld");fs.set_process(false);fs.player.set_physics_process(false)
 check(fs.matches==2 and fs.clock>=after_mine and fs.fires.size()==1 and not fs.shelter.door_closed,"return preserves time, matches and fire")
 check(Vector2(fs.player.global_position.x-1125,fs.player.global_position.z+1203).length()<1,"mine exit returns to entrance, not spawn")
 # SaveManager load must choose MineInterior instead of putting interior coordinates in the forest.
 check(sm.load_game("slot_first_night_mine"),"load saved mine slot")
 await settle(8)
 check(current_scene.name=="MineInterior" and current_scene.has_node("SurvivalWorld"),"loading selects the correct mine scene")
 var loaded=current_scene.get_node("SurvivalWorld");loaded.set_process(false)
 check(loaded.matches==2,"saved mine survival restored after scene load")
 check(loaded.player.belt_items[2]=="brush","saved mine restores crafted belt binding")
 print("FIRST NIGHT INTEGRATION SUMMARY: %d PASS, %d FAIL"%[passes,failures])
 current_scene.free();current_scene=null;await settle(2);quit(1 if failures else 0)
