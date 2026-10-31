extends SceneTree
const Items=preload("res://scripts/survival/SurvivalItems.gd")
var passes:=0
var failures:=0
var p:Node
var s:Node
var ui:Node
var out:=OS.get_environment("DN_QA_OUTPUT")
var capture_only:="--capture-only-render" in OS.get_cmdline_user_args()
func _initialize() -> void:call_deferred("run")
func check(ok:bool,text:String) -> void:
 if ok:passes+=1;print("PASS: ",text)
 else:failures+=1;printerr("FAIL: ",text)
func settle(n:int=5) -> void:
 for i in n:await process_frame
func shot(title:String) -> void:
 if out.is_empty() or DisplayServer.get_name()=="headless":return
 DirAccess.make_dir_recursive_absolute(out)
 if capture_only:RenderingServer.set_render_loop_enabled(true)
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image();check(image.get_size()==root.size,"physical screenshot "+title);image.save_png(out.path_join(title+".png"))
 if capture_only:RenderingServer.set_render_loop_enabled(false)
func click(b:Control) -> void:
 var at:=b.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new();motion.position=at;root.push_input(motion,true)
 for down in [true,false]:
  var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=at;e.global_position=at;e.pressed=down;root.push_input(e,true);await process_frame
 await settle()
func key(code:Key) -> void:
 for down in [true,false]:
  var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;root.push_input(e,true);await process_frame
 await settle()
func visible_rows() -> int:
 var n:=0
 for b in p._inv_slot_buttons:
  if b.visible:n+=1
 return n
func add(id:String,n:int=1) -> void:
 var item:=Items.item(id);item.count=n;check(Items.transact(p,{},[item]),"real transaction "+id)
func run() -> void:
 if not OS.get_user_data_dir().contains("deadly-night-test"):quit(2);return
 root.size=Vector2i(1280,720)
 if capture_only and DisplayServer.get_name()!="headless":RenderingServer.set_render_loop_enabled(false)
 var arena:=Node3D.new();arena.name="MapViewer";root.add_child(arena);current_scene=arena
 var ground:=StaticBody3D.new();ground.add_to_group("camp_ground");var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(140,1,140);col.shape=shape;ground.add_child(col);ground.position.y=-0.5;arena.add_child(ground)
 p=load("res://scenes/player/Player.tscn").instantiate();arena.add_child(p);p.position=Vector3(0,0.1,0);p.set_active(true);p.set_physics_process(false)
 s=load("res://scripts/survival/SurvivalWorld.gd").new();arena.add_child(s);s.set_process(false)
 await physics_frame;await settle();ui=p._backpack_ui
 s.open_backpack();ui.tabs.current_tab=0;ui.resize();await settle()
 check(visible_rows()==0 and ui.item_empty.visible,"empty backpack has zero fake cells and useful hint")
 check(not p._hud_layer.visible,"journal suppresses underlying gameplay HUD")
 check(ui.quick_buttons.size()==8 and ui.tool_rows.size()==5,"real five tools + three assignments, no duplicate inventory")
 await shot("01_empty_1280")
 for id in ["stone","brush","flint","pyrite","camp_kit","water","raw_water","ration","berries","bandage","compress"]:add(id,2)
 p._add_to_backpack({"species":"oak","weight":4.0})
 check(Items.transact(p,{},[Items.item("firewood","oak",4.0/3)]),"real species fuel")
 await settle();check(visible_rows()==13,"partial backpack shows occupied slots only")
 await click(p._inv_slot_buttons[0]);check(p._selected_slot_index==0,"mouse selects authoritative slot")
 check(not ui.belt_group.visible and not ui.buttons.use_supply.visible,"stone exposes no fictional use or binding")
 await click(p._inv_slot_buttons[0]);check(p._selected_slot_index==-1 and p._inv_empty_inspector_label.visible,"second click deselects")
 await click(p._inv_slot_buttons[4]);check(ui.buttons.place.visible and ui.belt_group.visible,"camp kit contextual placement and belt")
 ui.belt_select.select(0);await click(ui.buttons.belt);check(p.belt_items[0]=="camp_kit","assign uses existing belt contract")
 check(ui.quick_values[5].text=="2","quick strip actual aggregate amount")
 await click(ui.quick_buttons[0]);check(p.active_hotbar_slot==0,"quick strip selects existing tool")
 var before:=str(p.inventory_slots);ui.sorting.select(2);ui.refresh_inventory();check(str(p.inventory_slots)==before,"weight sorting cannot mutate source")
 ui.sorting.select(0);ui.search.text="ПИРИТ";ui.search.text_changed.emit(ui.search.text);await settle();check(visible_rows()==1,"case insensitive search")
 ui.search.text="zzzz";ui.search.text_changed.emit(ui.search.text);await settle();check(ui.item_empty.visible and visible_rows()==0,"no results is not empty cells")
 ui.search.text="";ui.search.text_changed.emit(ui.search.text);await click(ui.category_buttons[5]);check(visible_rows()==2,"medicine category actual types")
 await click(ui.category_buttons[6]);check(visible_rows()==0 and ui.tool_rows[0].visible,"tools projected separately from backpack slots")
 await click(ui.tool_rows[3]);check(ui.buttons.equip_tool.visible and not ui.drop_group.visible and not ui.belt_group.visible,"permanent tool cannot be dropped or re-bound")
 check(str(s.matches) in p._inv_details_stats.text,"matches count from survival, not literal hotbar status")
 await shot("02_tools_1280")
 await click(ui.category_buttons[0]);p._on_slot_clicked(5);s.body.water=45;ui.refresh_actions()
 var water:int=Items.count(p.inventory_slots,"water");await click(ui.buttons.use_supply)
 check(Items.count(p.inventory_slots,"water")==water-1 and s.body.water==80,"use water changes real inventory and hydration")
 p._on_slot_clicked(9);check(ui.buttons.use_supply.disabled,"bandage honestly disabled without bleeding")
 s.body.conditions["bleeding"]={"remaining":-1.0};ui.refresh_actions();check(not ui.buttons.use_supply.disabled,"bandage available for actual bleeding")
 await click(ui.buttons.use_supply);check(not s.body.conditions.has("bleeding"),"bandage treats actual condition")
 p._on_slot_clicked(10);check(ui.buttons.use_supply.disabled,"compress disabled without sprain")
 s.body.conditions["sprain"]={"remaining":240.0};ui.refresh_actions();await click(ui.buttons.use_supply);check(not s.body.conditions.has("sprain"),"compress treats actual sprain")
 p._on_slot_clicked(0);ui.drop_amount.value=1;await click(ui.buttons.drop_one);check(Items.count(p.inventory_slots,"stone")==1,"quantity drop uses existing logic")
 var nodes:int=p._inv_root_panel.find_children("*","Control",true,false).size();ui.search.grab_focus()
 for i in 20:ui.refresh_actions()
 check(ui.search.has_focus() and nodes==p._inv_root_panel.find_children("*","Control",true,false).size(),"refresh preserves controls and input focus")
 # Exercise both project canvas stretch and non-stretch host viewports.
 for stretched in [true,false]:
  root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if stretched else Window.CONTENT_SCALE_MODE_DISABLED
  root.content_scale_size=Vector2i(1280,720) if stretched else Vector2i.ZERO
  for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
   root.size=resolution;await settle(10);ui.resize();await settle(10)
   ui.tabs.current_tab=0;p._on_slot_clicked(12);await settle()
   var panel:Rect2=p._inv_root_panel.get_global_rect();var view:=root.get_visible_rect()
   check(view.encloses(panel),"shell inside "+str(resolution)+" stretch="+str(stretched))
   check(ui.inventory_left.get_global_rect().end.x<=ui.right_scroll.get_global_rect().position.x,"columns never overlap "+str(resolution))
   check(panel.encloses(ui.quick_strip.get_global_rect()),"quick strip inside shell "+str(resolution))
   check(panel.encloses(ui.search.get_global_rect()),"search inside shell "+str(resolution))
   check(panel.encloses(ui.drop_group.get_global_rect()),"drop actions always visible "+str(resolution))
   for b in ui.category_buttons+[ui.buttons.close]:
    var width:float=b.get_theme_font("font").get_string_size(b.text,HORIZONTAL_ALIGNMENT_LEFT,-1,b.get_theme_font_size("font_size")).x
    var icon_width:float=b.get_theme_constant("icon_max_width")+b.get_theme_constant("h_separation") if b.icon!=null else 0.0
    check(width+icon_width+b.get_theme_stylebox("normal").get_minimum_size().x<=b.size.x+1,"navigation label not clipped: "+b.text+" "+str(resolution))
   check(p._inv_slot_buttons[0].size.y/ui.ui_scale<=61,"compact 60px physical row "+str(resolution))
   check(ui.quick_buttons[0].size.y/ui.ui_scale<=54,"compact quick slot "+str(resolution))
   if stretched:
    await shot("03_inventory_%d" % resolution.x)
    for tab in [1,2]:
     ui.tabs.current_tab=tab;await settle();check(view.encloses(ui.tabs.get_current_tab_control().get_global_rect()),"tab inside viewport "+str(tab)+str(resolution));await shot("04_tab_%d_%d" % [tab,resolution.x])
 ui.tabs.current_tab=0;ui.category.select(0)
 for i in p.MAX_SLOTS:p.inventory_slots[i]=Items.item("stone");p.inventory_slots[i].count=10
 Items.refresh(p);ui.refresh_actions();await settle()
 check(visible_rows()==16 and p.backpack_weight>p.max_backpack_kg,"full 160-item backpack and real overweight")
 check(not Items.transact(p,{},[Items.item("ration")]),"full bag rejects overflowing transaction")
 p._on_slot_clicked(0);check(ui.drop_amount.max_value==10,"stack inspector uses real count")
 await shot("05_full_stacks_1920")
 await key(KEY_ESCAPE);check(not p._is_inventory_open,"Escape closes journal without opening pause");check(p._hud_layer.visible,"closing journal restores gameplay HUD snapshot")
 await key(KEY_TAB);check(p._is_inventory_open and ui.tabs.current_tab==2,"Tab reopens existing condition landing page")
 await key(KEY_TAB);check(not p._is_inventory_open,"Tab closes journal")
 s.close_backpack();await create_timer(0.2).timeout;arena.free();current_scene=null;await settle()
 print("INVENTORY REDESIGN SUMMARY: %d PASS, %d FAIL" % [passes,failures]);quit(1 if failures else 0)
