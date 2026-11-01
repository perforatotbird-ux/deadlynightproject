extends SceneTree
var frames:=0
func _initialize() -> void:call_deferred("_setup")
func _setup() -> void:
 var root:=Node3D.new();get_root().add_child(root)
 var env:=WorldEnvironment.new();var e:=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("293333");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("e5e0d2");e.ambient_light_energy=.65;env.environment=e;root.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);light.light_energy=1.0;root.add_child(light)
 var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(1.1,2.1,2.6);camera.look_at(Vector3(1.1,0,0.65));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.7;camera.current=true
 var idx:=0
 for kind in ["stone","pyrite","flint","branch","forest_fat","wood_fan","copper_false","pale_bell","stump_fan"]:
  var path:String="res://assets/models/resources/"+kind+"_00.glb"
  if not ResourceLoader.exists(path):continue
  var node:=MeshInstance3D.new();node.mesh=preload("res://scripts/survival/ResourceModels.gd").mesh("brush" if kind=="branch" else str(kind));root.add_child(node);node.position=Vector3((idx%4)*.75,0,(idx/4)*.7);idx+=1
 var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(12,12);floor_mesh.mesh=plane
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color("444c37");mat.roughness=1;floor_mesh.material_override=mat;floor_mesh.position.y=-.015;root.add_child(floor_mesh)
func _process(_d:float) -> bool:
 frames+=1
 if frames==40:
  get_root().get_texture().get_image().save_png("/data/qa/resources-godot.png");quit()
 return false
