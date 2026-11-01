extends Node3D
# Traverse 01: authored anatomical forearm + circular field watch, generated in Blender.
# The dense editable source is excluded from Godot; this is its runtime GLB.
const MODEL=preload("res://assets/models/viewmodels/watch/left_arm_round_watch.glb")
const REST:=Vector3(-0.46,-0.70,-0.28)
const RAISED:=Vector3(-0.055,-0.065,-0.21)
var player:Node
var blend:=0.0
var remaining:=0.0
var digits:Label3D
var day_label:Label3D
var arm:Node3D
func _ready()->void:
 name="WatchArm";position=REST;visible=false
 arm=MODEL.instantiate();arm.name="LeftWatchHand";add_child(arm)
 for mesh in arm.find_children("*","MeshInstance3D",true,false):
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var anchor:Node3D=arm.find_child("DisplayAnchor",true,false)
 assert(anchor!=null,"Authored watch needs a display anchor")
 digits=Label3D.new();digits.name="DigitalTime";digits.font_size=44;digits.pixel_size=0.00018
 digits.position=Vector3(0,0.0014,0.00020);digits.modulate=Color("c2e8e9");digits.outline_size=0;digits.no_depth_test=false
 anchor.add_child(digits)
 day_label=Label3D.new();day_label.name="WatchDay";day_label.font_size=16;day_label.pixel_size=0.00018
 day_label.position=Vector3(0,-0.007,0.00020);day_label.modulate=Color("8eb8bb");day_label.outline_size=0
 anchor.add_child(day_label)
 refresh_time()
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
 var eased:=smoothstep(0,1,blend)
 position=REST.lerp(RAISED,eased);rotation=Vector3(-0.65,0.25,-1.0).lerp(Vector3(-0.06,-0.12,-0.10),eased);visible=blend>0.001
 if is_instance_valid(player):player._axe_sway_pivot.visible=not visible
 if visible:refresh_time()
