extends Node3D
# Original reusable storm-lantern geometry. Camera forward is -Z; decorative
# rotations never control the world beam. Viewmodel geometry never casts shadows.
const VIEWMODEL_LAYER:=1<<19
var flame:MeshInstance3D
var glow:OmniLight3D
var _lit:=false
var _time:=0.0
func material(color:Color,metal:float=0.0,roughness:float=0.5)->StandardMaterial3D:
 var m:=StandardMaterial3D.new();m.albedo_color=color;m.metallic=metal;m.roughness=roughness;return m
func piece(id:String,mesh:Mesh,mat:Material,pos:Vector3=Vector3.ZERO)->MeshInstance3D:
 var n:=MeshInstance3D.new();n.name=id;n.mesh=mesh;n.material_override=mat;n.position=pos;n.layers=VIEWMODEL_LAYER;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(n);return n
func lathe(profile:Array,segments:int=48)->ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for j in profile.size()-1:
  for i in segments:
   var a:float=TAU*i/segments;var b:float=TAU*(i+1)/segments
   var p:Vector2=profile[j];var q:Vector2=profile[j+1]
   var v=[Vector3(p.x*cos(a),p.y,p.x*sin(a)),Vector3(q.x*cos(a),q.y,q.x*sin(a)),Vector3(q.x*cos(b),q.y,q.x*sin(b)),Vector3(p.x*cos(b),p.y,p.x*sin(b))]
   for k in [0,2,1,0,3,2]:st.add_vertex(v[k])
 st.index();st.generate_normals();return st.commit()
func rod(id:String,a:Vector3,b:Vector3,radius:float,mat:Material)->void:
 var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=a.distance_to(b);mesh.radial_segments=12
 var n:=piece(id,mesh,mat,(a+b)*0.5);n.basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()))
func _ready()->void:
 var iron:=material(Color("35433b"),0.65,0.55)
 var edge:=material(Color("65766a"),0.8,0.32)
 var brass:=material(Color("a98b4b"),0.8,0.3)
 var dark:=material(Color("171e1b"),0.35,0.7)
 # Beaded pressed-metal fuel reservoir, rolled rim and domed chimney cap.
 piece("FuelReservoir",lathe([Vector2(0,0),Vector2(.105,0),Vector2(.12,.012),Vector2(.123,.023),Vector2(.119,.032),Vector2(.11,.042),Vector2(.105,.073),Vector2(.079,.091),Vector2(0,.091)]),iron)
 piece("RolledFoot",lathe([Vector2(.12,.012),Vector2(.125,.017),Vector2(.125,.024),Vector2(.12,.028)]),edge)
 piece("BurnerBowl",lathe([Vector2(0,.09),Vector2(.07,.09),Vector2(.08,.104),Vector2(.076,.112),Vector2(.04,.124),Vector2(.025,.139),Vector2(0,.139)]),brass)
 var glass:=material(Color(.67,.80,.72,.075),0.0,0.12);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 piece("GlassGlobe",lathe([Vector2(.047,.12),Vector2(.068,.132),Vector2(.082,.163),Vector2(.087,.205),Vector2(.08,.253),Vector2(.058,.293),Vector2(.052,.31)]),glass)
 piece("GlobeLowerRing",lathe([Vector2(.062,.123),Vector2(.071,.129),Vector2(.071,.137),Vector2(.067,.14)]),edge)
 piece("ChimneyShoulder",lathe([Vector2(.05,.294),Vector2(.075,.301),Vector2(.099,.309),Vector2(.102,.316),Vector2(.096,.324),Vector2(.067,.345),Vector2(.053,.351)]),iron)
 piece("ChimneyTop",lathe([Vector2(.053,.35),Vector2(.053,.377),Vector2(.061,.383),Vector2(.063,.389),Vector2(.043,.403),Vector2(.023,.41),Vector2(0,.41)]),iron)
 # Raised copper vent slits wrap the chimney instead of a blank flat cylinder.
 for i in 16:
  var a:float=TAU*i/16;var vent:=BoxMesh.new();vent.size=Vector3(.011,.017,.002)
  var n:=piece("Vent%02d"%i,vent,dark,Vector3(.0535*cos(a),.363,.0535*sin(a)));n.rotation.y=-a+PI/2
 for side in [-1,1]:
  var x:float=side*.104
  rod("GuardLower",Vector3(x*.86,.048,0),Vector3(x,.155,0),.009,iron)
  rod("GuardUpper",Vector3(x,.155,0),Vector3(x*.83,.322,0),.009,iron)
  rod("HandleMount",Vector3(x*.83,.315,-.012),Vector3(x*.83,.315,.012),.015,brass)
 # Continuous arch-shaped wire bail, with a wrapped leather carry grip.
 var last:=Vector3(-.091,.32,0)
 for i in range(1,33):
  var a:float=PI-PI*i/32;var next:=Vector3(.091*cos(a),.32+.19*sin(a),0)
  rod("Bail%02d"%i,last,next,.0045,edge);last=next
 rod("CarryGrip",Vector3(-.029,.507,0),Vector3(.029,.507,0),.011,dark)
 var cap:=CylinderMesh.new();cap.top_radius=.023;cap.bottom_radius=.023;cap.height=.018;cap.radial_segments=24
 var filler:=piece("FillerCap",cap,brass,Vector3(.085,.07,.045));filler.rotation.z=-.35
 rod("WickAdjuster",Vector3(.04,.105,.035),Vector3(.09,.105,.062),.006,brass)
 var wheel:=CylinderMesh.new();wheel.top_radius=.014;wheel.bottom_radius=.014;wheel.height=.006;wheel.radial_segments=16
 var dial:=piece("WickDial",wheel,brass,Vector3(.092,.105,.063));dial.rotation.x=PI/2
 var wick:=CylinderMesh.new();wick.top_radius=.009;wick.bottom_radius=.012;wick.height=.025;piece("Wick",wick,dark,Vector3(0,.143,0))
 var fire:=SphereMesh.new();fire.radius=.013;fire.height=.063;fire.radial_segments=16;fire.rings=8
 var emissive:=material(Color("ffcd70"));emissive.emission_enabled=true;emissive.emission=Color("ffb84d");emissive.emission_energy_multiplier=1.7
 flame=piece("Flame",fire,emissive,Vector3(0,.179,0))
 glow=OmniLight3D.new();glow.name="GlobeGlow";glow.position=Vector3(0,.20,.25);glow.omni_range=1.3;glow.light_color=Color("ffc572");glow.light_energy=.65;glow.light_cull_mask=VIEWMODEL_LAYER;glow.shadow_enabled=false;add_child(glow)
 set_lit(_lit)
func set_lit(on:bool)->void:
 _lit=on
 if is_instance_valid(flame):flame.visible=on
 if is_instance_valid(glow):glow.visible=on
 set_process(on)
func _process(delta:float)->void:
 _time+=delta
 if is_instance_valid(flame):flame.scale=Vector3(1,1+sin(_time*9)*.06,1)
 if is_instance_valid(glow):glow.light_energy=.65+sin(_time*11)*.025
