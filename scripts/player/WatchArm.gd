extends Node3D
# Reuse the authored left glove/sleeve, with a physical digital wristwatch.
const HANDS=preload("res://assets/models/viewmodels/axe_grip_hands.gltf")
const REST:=Vector3(-0.55,-0.85,-0.40)
const RAISED:=Vector3(-0.015,-0.16,-0.43)
var player:Node
var blend:=0.0
var remaining:=0.0
var digits:Label3D
var day_label:Label3D
var arm:Node3D
func _ready()->void:
 name="WatchArm";position=REST;visible=false
 arm=Node3D.new();arm.name="LeftWatchHand";add_child(arm)
 var source:=HANDS.instantiate()
 for mesh in source.find_children("*","MeshInstance3D",true,false):
  if mesh.name not in ["LeftHand","LeftWristCuff","ForearmSleeve"]:continue
  var copy:=MeshInstance3D.new();copy.name=mesh.name;copy.mesh=mesh.mesh;copy.transform=mesh.transform;copy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;arm.add_child(copy)
  if mesh.name=="ForearmSleeve":copy.position=Vector3(-0.33,-0.021,0.025);copy.rotation.z=PI/2;copy.scale=Vector3(0.85,0.4,0.85)
 source.free()
 var strap:=MeshInstance3D.new();strap.name="WatchStrap";var ring:=CylinderMesh.new();ring.top_radius=0.048;ring.bottom_radius=0.048;ring.height=0.036;strap.mesh=ring;strap.rotation.z=PI/2;strap.position=Vector3(-0.165,-0.021,0.025);strap.material_override=material(Color("202629"));arm.add_child(strap)
 box("WatchCase",Vector3(0.093,0.070,0.024),Vector3(-0.165,-0.021,0.073),Color("353c3d"))
 box("LCD",Vector3(0.080,0.054,0.003),Vector3(-0.165,-0.021,0.087),Color("9bac82"),true)
 digits=Label3D.new();digits.name="DigitalTime";digits.font_size=44;digits.pixel_size=0.00048;digits.position=Vector3(-0.165,-0.013,0.091);digits.modulate=Color("182b22");digits.outline_size=0;digits.no_depth_test=false;arm.add_child(digits)
 day_label=Label3D.new();day_label.name="WatchDay";day_label.font_size=16;day_label.pixel_size=0.00048;day_label.position=Vector3(-0.165,-0.038,0.091);day_label.modulate=Color("182b22");day_label.outline_size=0;arm.add_child(day_label)
 refresh_time()
func material(color:Color,unshaded:bool=false)->StandardMaterial3D:
 var m:=StandardMaterial3D.new();m.albedo_color=color
 if unshaded:m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 return m
func box(title:String,size:Vector3,pos:Vector3,color:Color,unshaded:bool=false)->void:
 var n:=MeshInstance3D.new();n.name=title;var mesh:=BoxMesh.new();mesh.size=size;n.mesh=mesh;n.position=pos;n.material_override=material(color,unshaded);n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;arm.add_child(n)
func can_check()->bool:
 return is_instance_valid(player) and player._is_active and not player._is_inventory_open and not player._is_map_open and is_instance_valid(player.survival) and player.survival.health>0 and player.survival.job.is_empty() and not player.survival.placing and not (is_instance_valid(player._pause_menu) and player._pause_menu.visible)
func toggle()->void:
 if not can_check():return
 player._cancel_chop();remaining=0.0 if remaining>0 else 3.5
func lower()->void:remaining=0.0
func refresh_time()->void:
 if not is_instance_valid(player) or not is_instance_valid(player.survival):return
 var clock:float=player.survival.clock
 var minute:=floori(clock/60.0)
 digits.text="%02d:%02d" % [posmod(minute/60,24),posmod(minute,60)]
 day_label.text="DAY %02d" % (floori(clock/86400.0)+1)
func _process(delta:float)->void:
 if not can_check():remaining=0
 remaining=maxf(0,remaining-delta)
 blend=move_toward(blend,1.0 if remaining>0 else 0.0,delta/0.32)
 position=REST.lerp(RAISED,smoothstep(0,1,blend));rotation.z=lerpf(-0.45,-0.12,blend);visible=blend>0.001
 if is_instance_valid(player):player._axe_sway_pivot.visible=not visible
 if visible:refresh_time()
