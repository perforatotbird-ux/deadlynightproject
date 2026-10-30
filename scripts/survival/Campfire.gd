extends StaticBody3D
var data: Dictionary
var session: Node
var light: OmniLight3D
var flame: GPUParticles3D
var coals: MeshInstance3D
var audio: AudioStreamPlayer3D
func _ready() -> void:
 collision_layer=1|8;collision_mask=0;add_to_group("survival_fires")
 var stone_mat:=StandardMaterial3D.new();stone_mat.albedo_color=Color(0.31,0.34,0.32);stone_mat.roughness=0.95
 for i in 10:
  var m:=MeshInstance3D.new();var s:=SphereMesh.new();s.radius=0.14;s.height=0.22;s.radial_segments=7;s.rings=3;m.mesh=s;m.material_override=stone_mat
  m.position=Vector3(cos(i*TAU/10)*0.48,0.10,sin(i*TAU/10)*0.48);add_child(m)
 var wood:=StandardMaterial3D.new();wood.albedo_color=Color(0.19,0.10,0.045)
 for i in 4:
  var m:=MeshInstance3D.new();var c:=CylinderMesh.new();c.height=0.65;c.top_radius=0.04;c.bottom_radius=0.055;c.radial_segments=7;m.mesh=c;m.material_override=wood;m.rotation_degrees=Vector3(80,i*75,0);m.position.y=0.13;add_child(m)
 coals=MeshInstance3D.new();var coalmesh:=CylinderMesh.new();coalmesh.top_radius=0.32;coalmesh.bottom_radius=0.32;coalmesh.height=0.035;coals.mesh=coalmesh;coals.position.y=0.04
 var coalmat:=StandardMaterial3D.new();coalmat.albedo_color=Color(0.2,0.06,0.02);coalmat.emission_enabled=true;coalmat.emission=Color(0.8,0.14,0.01);coals.material_override=coalmat;add_child(coals)
 light=OmniLight3D.new();light.light_color=Color(1,0.42,0.12);light.omni_range=9;light.position.y=0.7;light.shadow_enabled=false;add_child(light)
 flame=GPUParticles3D.new();flame.amount=38;flame.lifetime=0.7;flame.position.y=0.2;flame.visibility_aabb=AABB(Vector3(-1,-1,-1),Vector3(2,3,2))
 var p:=ParticleProcessMaterial.new();p.direction=Vector3.UP;p.spread=12;p.initial_velocity_min=0.5;p.initial_velocity_max=1.0;p.gravity=Vector3(0,0.4,0);p.scale_min=0.04;p.scale_max=0.12;p.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE;p.emission_sphere_radius=0.19
 var gradient:=Gradient.new();gradient.colors=PackedColorArray([Color(1,0.7,0.16,0.9),Color(1,0.15,0.015,0.6),Color(0.2,0.05,0.01,0)]);gradient.offsets=PackedFloat32Array([0,0.45,1]);var tex:=GradientTexture1D.new();tex.gradient=gradient;p.color_ramp=tex;flame.process_material=p
 var quad:=QuadMesh.new();quad.size=Vector2(0.22,0.35);var fm:=StandardMaterial3D.new();fm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;fm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;fm.vertex_color_use_as_albedo=true;fm.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
 var soft:=GradientTexture2D.new();soft.width=32;soft.height=32;soft.fill=GradientTexture2D.FILL_RADIAL;soft.fill_from=Vector2(0.5,0.5);soft.fill_to=Vector2(0.5,1);var falloff:=Gradient.new();falloff.colors=PackedColorArray([Color.WHITE,Color(1,1,1,0)]);soft.gradient=falloff;fm.albedo_texture=soft;quad.material=fm;flame.draw_pass_1=quad;add_child(flame)
 var col:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=0.6;shape.height=0.2;col.shape=shape;col.position.y=0.1;add_child(col)
 audio=AudioStreamPlayer3D.new();audio.max_distance=22;audio.bus="SFX" if AudioServer.get_bus_index("SFX")>=0 else "Master";add_child(audio)
 var stream=load("res://assets/sounds/survival/fire_loop.wav").duplicate() as AudioStreamWAV
 stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=int(stream.get_length()*stream.mix_rate);audio.stream=stream;audio.volume_db=-10
 sync_visual()
func sync_visual() -> void:
 var burning:bool=data["state"]=="burning";var hot:bool=burning or data["state"]=="embers"
 flame.emitting=burning;coals.visible=hot;light.visible=hot
 light.light_energy=(1.6+sin(Time.get_ticks_msec()*0.013)*0.12) if burning else 0.3
 if audio.stream and hot and not audio.playing:audio.play()
 if not hot and audio.playing:audio.stop()
func _process(_dt: float) -> void:sync_visual()
func get_interact_text() -> String:
 return "[E] Костёр · %s · топливо %.0f мин" % [{"unlit":"не разожжён","burning":"горит","embers":"угли","cold":"остыл"}.get(data["state"],""),float(data["fuel"])/60]
func survival_interact() -> void:session.open_backpack(data["id"])

func ignition_fx(method: String) -> void:
 var particles:=GPUParticles3D.new();particles.one_shot=true;particles.amount=16 if method=="spark" else 5;particles.lifetime=0.4;particles.position=Vector3(0,0.3,0)
 var p:=ParticleProcessMaterial.new();p.direction=Vector3.UP;p.spread=60;p.initial_velocity_min=0.5;p.initial_velocity_max=1.5;p.gravity=Vector3(0,-3,0);p.scale_min=0.01;p.scale_max=0.025;p.color=Color(1,0.65,0.15);particles.process_material=p
 var mesh:=SphereMesh.new();mesh.radius=1;mesh.height=2;mesh.radial_segments=4;mesh.rings=2
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color(1,0.6,0.08);mesh.material=mat;particles.draw_pass_1=mesh
 add_child(particles);particles.finished.connect(particles.queue_free);particles.emitting=true
