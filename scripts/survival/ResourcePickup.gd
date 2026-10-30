extends StaticBody3D
var item_data: Dictionary = {}
var resource_id: String = ""
var session: Node
var collected:=false
func _ready() -> void:
 collision_layer=4;collision_mask=0
 var mat := StandardMaterial3D.new()
 if item_data.get("type")=="brush":
  mat.albedo_color=Color(0.31,0.20,0.11)
  for i in 4:
   var twig := MeshInstance3D.new();var c:=CylinderMesh.new();c.top_radius=0.012;c.bottom_radius=0.02;c.height=0.65;c.radial_segments=5
   twig.mesh=c;twig.material_override=mat;twig.rotation_degrees=Vector3(85,i*39,12);twig.position=Vector3((i-2)*0.06,0.07,0);add_child(twig)
 elif item_data.get("type") in ["water","raw_water","ration","bandage","compress","berries"]:
  var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(0.24,0.18,0.18);mesh.mesh=box;mesh.position.y=0.10
  mat.albedo_color={"water":Color("729a9a"),"raw_water":Color("777953"),"ration":Color("a48c55"),"bandage":Color("d6cfb3"),"compress":Color("b2b59a"),"berries":Color("754651")}[item_data.type]
  mesh.material_override=mat;add_child(mesh)
  var icon:=Sprite3D.new();icon.texture=load("res://assets/ui/field_journal/icons/"+str(item_data.type)+".svg");icon.pixel_size=0.0022;icon.billboard=BaseMaterial3D.BILLBOARD_ENABLED;icon.position.y=0.4;add_child(icon)
 else:
  var mesh := MeshInstance3D.new()
  var sphere:=SphereMesh.new();sphere.radius=0.16;sphere.height=0.24;sphere.radial_segments=7;sphere.rings=3;mesh.mesh=sphere
  mat.albedo_color={"stone":Color(0.46,0.49,0.47),"flint":Color(0.19,0.23,0.27),"pyrite":Color(0.58,0.45,0.19)}.get(item_data.get("type"),Color(0.6,0.4,0.2))
  mesh.material_override=mat;mesh.position.y=0.12;add_child(mesh)
 var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(0.55,0.25,0.55);col.shape=box;col.position.y=0.12;add_child(col)
func get_interact_text() -> String:return "[E] Собрать: "+item_data.get("name","Ресурс")
func survival_interact() -> void:
 if collected or not is_instance_valid(session) or session.health<=0:return
 if session.Items.transact(session.player,{},[item_data]):
  collected=true
  session.picked[resource_id]=true;session.resources.erase(resource_id);collision_layer=0;queue_free()
  session.notify("Собрано: "+item_data["name"])
 else:session.notify("Рюкзак заполнен: освободите ячейку")
