extends Node3D
const Meshes=preload("res://scripts/atmosphere/WoodlandMeshes.gd")
var wings:Array[Node3D]=[]
var materials:Array[StandardMaterial3D]=[]
var opacity:=0.0
var age:=0.0
var phase:=0.0
var owl:=false
var velocity:=Vector3.ZERO
var target:=Vector3.ZERO
var startled:=0.0
func _ready()->void:
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color("555346") if owl else Color("363e35");mat.roughness=.95;mat.cull_mode=BaseMaterial3D.CULL_BACK;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS;materials.append(mat)
 var body:=SphereMesh.new();body.radius=.078;body.height=.29;body.radial_segments=10;body.rings=6
 var torso:=piece("Body",body,mat,Vector3.ZERO);torso.rotation.x=PI/2
 var head_mesh:=SphereMesh.new();head_mesh.radius=.06 if owl else .043;head_mesh.height=.12 if owl else .085;head_mesh.radial_segments=10;head_mesh.rings=6
 piece("Head",head_mesh,mat,Vector3(0,.025,-.155))
 var beak:=PrismMesh.new();beak.size=Vector3(.035,.025,.075);piece("Beak",beak,mat,Vector3(0,.012,-.208))
 var tail:=PrismMesh.new();tail.size=Vector3(.09,.012,.18);piece("Tail",tail,mat,Vector3(0,0,.19))
 var wing_mat:StandardMaterial3D=mat.duplicate();wing_mat.cull_mode=BaseMaterial3D.CULL_DISABLED;materials.append(wing_mat)
 for side in [-1,1]:
  var pivot:=Node3D.new();add_child(pivot);wings.append(pivot)
  var wing:=piece("Wing",Meshes.wing(side),wing_mat,Vector3.ZERO);remove_child(wing);pivot.add_child(wing)
func piece(id:String,mesh:Mesh,mat:Material,pos:Vector3)->MeshInstance3D:
 var n:=MeshInstance3D.new();n.name=id;n.mesh=mesh;n.material_override=mat;n.position=pos;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(n);return n
func configure(is_owl:bool)->void:
 owl=is_owl
 for m in materials:m.albedo_color=Color("777363") if owl else Color("363e35")
 var head:=get_node_or_null("Head")
 if head:head.scale=Vector3.ONE*(1.4 if owl else 1.0)
func animate(delta:float,value:float)->void:
 opacity=clampf(value,0,1)
 age+=delta;startled=maxf(0,startled-delta)
 var rate:=13.0 if startled>0 else (5.0 if owl else 8.5)
 var flap:=sin(age*rate+phase)*(.68 if startled>0 else .38)
 for i in wings.size():wings[i].rotation.z=flap*(-1 if i==0 else 1)
 for m in materials:m.albedo_color.a=opacity
