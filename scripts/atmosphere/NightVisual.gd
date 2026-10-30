extends Node3D
# Render-only apparition: deliberately no body, area, attack, or interaction API.
var kind:="eyes"
var cores:Array[MeshInstance3D]=[]
var halos:Array[MeshInstance3D]=[]
var body_parts:Array[MeshInstance3D]=[]
var core_material:StandardMaterial3D
var halo_material:StandardMaterial3D
var body_material:StandardMaterial3D
var local_light:OmniLight3D
var tint:=Color(0.65,0.9,0.78)
var opacity:=0.0

func _ready() -> void:
 core_material=_material(tint)
 core_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 core_material.emission_enabled=true;core_material.emission=tint;core_material.emission_energy_multiplier=2.5
 halo_material=_material(tint)
 halo_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 halo_material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
 halo_material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
 halo_material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
 var texture:=GradientTexture2D.new();texture.width=64;texture.height=64
 texture.fill=GradientTexture2D.FILL_RADIAL;texture.fill_from=Vector2(0.5,0.5);texture.fill_to=Vector2(0.5,1)
 var gradient:=Gradient.new();gradient.offsets=PackedFloat32Array([0,0.12,0.4,1])
 gradient.colors=PackedColorArray([Color(1,1,1,0.8),Color(1,1,1,0.45),Color(1,1,1,0.12),Color(1,1,1,0)])
 texture.gradient=gradient;halo_material.albedo_texture=texture
 if kind=="orb":
  cores.append(_sphere(Vector3.ZERO,Vector3(0.15,0.15,0.15),core_material))
  halos.append(_halo(Vector3.ZERO,1.1))
  local_light=OmniLight3D.new();local_light.light_color=tint;local_light.omni_range=1.8
  local_light.shadow_enabled=false;local_light.light_energy=0;add_child(local_light)
 else:
  body_material=_material(Color(0.022,0.032,0.028))
  _limb(Vector3(0,1.05,0),Vector3(0,2.18,0),0.17,0.22)
  _limb(Vector3(-0.17,2.04,0),Vector3(-0.38,1.12,-0.03),0.055,0.065)
  _limb(Vector3(0.17,2.04,0),Vector3(0.36,1.1,0.04),0.055,0.065)
  _limb(Vector3(-0.09,1.11,0),Vector3(-0.16,0.1,0),0.045,0.075)
  _limb(Vector3(0.09,1.11,0),Vector3(0.17,0.1,0),0.045,0.075)
  body_parts.append(_sphere(Vector3(0,2.43,-0.01),Vector3(0.13,0.25,0.12),body_material))
  for side in [-1,1]:
   var pos:=Vector3(side*0.13,2.47,-0.12)
   cores.append(_sphere(pos,Vector3(0.06,0.032,0.028),core_material))
   halos.append(_halo(pos+Vector3(0,0,-0.01),0.23))
 set_opacity(0)

func _material(color: Color) -> StandardMaterial3D:
 var material:=StandardMaterial3D.new();material.albedo_color=color
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 # Keep ordinary depth testing. Never use no_depth_test/x-ray rendering.
 material.no_depth_test=false;material.cull_mode=BaseMaterial3D.CULL_DISABLED
 return material
func _sphere(pos: Vector3, radii: Vector3, mat: Material) -> MeshInstance3D:
 var mesh:=SphereMesh.new();mesh.radius=1;mesh.height=2;mesh.radial_segments=10;mesh.rings=5
 var node:=MeshInstance3D.new();node.mesh=mesh;node.scale=radii;node.position=pos;node.material_override=mat
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);return node
func _halo(pos: Vector3, size: float) -> MeshInstance3D:
 var mesh:=QuadMesh.new();mesh.size=Vector2.ONE*size
 var node:=MeshInstance3D.new();node.mesh=mesh;node.position=pos;node.material_override=halo_material
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);return node
func _limb(a: Vector3,b: Vector3, bottom: float, top: float) -> void:
 var mesh:=CylinderMesh.new();mesh.bottom_radius=bottom;mesh.top_radius=top;mesh.height=a.distance_to(b);mesh.radial_segments=7
 var node:=MeshInstance3D.new();node.mesh=mesh;node.position=(a+b)*0.5;node.material_override=body_material
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);body_parts.append(node)
 var up:Vector3=(b-a).normalized();var right:=Vector3.FORWARD.cross(up).normalized()
 node.basis=Basis(right,up,right.cross(up).normalized())
func set_opacity(value: float, darkness: float=1.0) -> void:
 opacity=clampf(value,0,1)
 if core_material==null:return
 var eye_alpha:float=opacity*(darkness if kind!="orb" else 1.0)
 core_material.albedo_color=Color(tint,eye_alpha);core_material.emission=tint*eye_alpha
 halo_material.albedo_color=Color(tint,eye_alpha*0.65)
 for node in cores:node.visible=eye_alpha>0.01
 for node in halos:node.visible=eye_alpha>0.01
 if body_material:body_material.albedo_color=Color(0.022,0.032,0.028,opacity)
 if local_light:local_light.light_energy=eye_alpha*0.2
