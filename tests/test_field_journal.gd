extends SceneTree
const Items=preload("res://scripts/survival/SurvivalItems.gd")
const Art=preload("res://scripts/ui/JournalArt.gd")
var passes:=0
var failures:=0
var p:Node3D
var s:Node
var ui:Node
var graphical:=false
var out:="/data/journal-previews"
func _initialize() -> void:call_deferred("run")
func check(ok:bool,text:String) -> void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func settle() -> void:
 for i in 8:await process_frame
func add(id:String,count:int=1) -> void:
 var item:=Items.item(id);item.count=count;Items.transact(p,{},[item])
func run() -> void:
 graphical=DisplayServer.get_name()!="headless";root.size=Vector2i(1280,720)
 if graphical:DirAccess.make_dir_recursive_absolute(out)
 var arena:=Node3D.new();arena.name="MapViewer";root.add_child(arena);current_scene=arena
 var ground:=StaticBody3D.new();ground.add_to_group("camp_ground");var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(140,1,140);col.shape=shape;ground.add_child(col);ground.position.y=-0.5;arena.add_child(ground)
 p=load("res://scenes/player/Player.tscn").instantiate();arena.add_child(p);p.position=Vector3(0,0.1,0);p.set_active(true);p.set_physics_process(false)
 s=load("res://scripts/survival/SurvivalWorld.gd").new();arena.add_child(s);s.set_process(false)
 await physics_frame;await settle();ui=p._backpack_ui
 add("stone",6);add("brush",8);add("flint");add("pyrite");add("camp_kit")
 for species in ["birch","spruce","beech","oak"]:p._add_to_backpack({"species":species,"weight":4.0})
 s.open_backpack();p._on_slot_clicked(4);ui.select_recipe("camp_kit");await settle()
 check(ui.recipe_cards.size()==5,"five real recipe cards, no fictional content")
 for id in Art.IDS:check(Art.texture(id)!=null,"painted art loaded: "+id)
 ui.search.text="ПИРИТ";await settle();var visible:=0
 for card in p._inv_slot_buttons:
  if card.visible:visible+=1
 check(visible==1,"case-insensitive search filters original slots")
 ui.search.text="";ui.category.select(3);ui.refresh_inventory();visible=0
 for card in p._inv_slot_buttons:
  if card.visible:visible+=1
 check(visible==1,"placeables category")
 ui.category.select(0);ui.sorting.select(2);ui.refresh_inventory()
 check(p.inventory_slots[0].type=="stone","sort changes visuals, not authoritative inventory order")
 ui.sorting.select(0);ui.refresh_inventory()
 ui.tabs.current_tab=1;ui.select_recipe("split_oak");check(ui.log_select.item_count==1 and p.inventory_slots[ui.log_select.get_selected_id()].species=="oak","recipe picker only accepts matching species")
 var nodes:int=p._inv_root_panel.find_children("*","Control",true,false).size();var focus:Button=ui.buttons.split;focus.grab_focus()
 for i in 20:ui.refresh_actions()
 check(nodes==p._inv_root_panel.find_children("*","Control",true,false).size(),"refresh does not rebuild control tree")
 check(focus.has_focus(),"refresh retains keyboard focus")
 s.begin_split(ui.log_select.get_selected_id());var before:=str(s.job);ui.tabs.current_tab=2;ui.tabs.current_tab=1
 check(str(s.job)==before,"tab switch preserves active job")
 s.cancel_job();s.advance(10)
 check(Items.count(p.inventory_slots,"firewood")==0,"cancelled split awards no items")
 p._selected_slot_index=1;var count:=Items.count(p.inventory_slots,"brush");ui.drop_amount.value=3;p.drop_selected_amount(3)
 check(Items.count(p.inventory_slots,"brush")==count-3,"quantity drop removes exactly three")
 ui.select_recipe("camp_kit");ui.only_available.button_pressed=true;ui.refresh_actions()
 check(ui.recipe_cards.camp_kit.visible,"available filter retains possible recipe")
 ui.only_available.button_pressed=false
 # Capacity preview shares transaction validation and cannot mutate inventory.
 var backup:Array=p.inventory_slots.duplicate(true)
 for i in p.MAX_SLOTS:
  p.inventory_slots[i]=Items.item("stone" if i==0 else ("brush" if i==1 else "flint"));p.inventory_slots[i].count=10
 var full_state:=str(p.inventory_slots)
 check("место" in ui.Catalog.reason(p,ui.Catalog.recipe("camp_kit")),"full backpack explains missing output capacity")
 check(str(p.inventory_slots)==full_state,"recipe capacity preview has zero inventory mutation")
 p.inventory_slots[15]=null
 check(ui.Catalog.reason(p,ui.Catalog.recipe("camp_kit"))=="","free slot enables same recipe")
 p.inventory_slots=backup;Items.refresh(p)
 # Installed fire for representative enabled states; sleep shows its honest cot requirement.
 s.begin_placement();s.placement={"ok":true,"pos":[0,0,3]};s.confirm_placement();p.position=Vector3(0,0.1,1)
 var fire:Dictionary=s.fires[0];s.selected_fire=fire.id
 ui.select_recipe("split_birch");s.begin_split(ui.log_select.get_selected_id());s.advance(10)
 s.open_backpack(fire.id);ui.select_recipe("camp_kit");p._on_slot_clicked(1)
 ui.hide_context_pages()
 for resolution in [Vector2i(800,600),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
  root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO;root.min_size=Vector2i(640,480);root.size=resolution;await settle();ui.resize();await settle()
  for index in 3:
   ui.tabs.current_tab=index;ui.refresh_actions();await settle()
   var panel:Rect2=p._inv_root_panel.get_global_rect();var viewport:=root.get_visible_rect()
   check(viewport.encloses(panel),"%s tab %d shell in viewport" % [resolution,index])
   var content:Control=ui.tabs.get_current_tab_control()
   check(content.get_global_rect().end.y<=ui.status.get_global_rect().position.y,"%s tab %d content above footer" % [resolution,index])
   check(viewport.encloses(ui.status.get_global_rect()),"footer visible %s tab %d" % [resolution,index])
   if index==1:check(viewport.encloses(ui.buttons.kit.get_global_rect()),"craft primary action stays visible %s" % resolution)
   if graphical:
    await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out.path_join("%dx%d_tab_%d.png" % [resolution.x,resolution.y,index]))
 s.close_backpack();arena.free();current_scene=null;await settle()
 print("FIELD JOURNAL SUMMARY: %d PASS, %d FAIL" % [passes,failures]);quit(1 if failures else 0)
