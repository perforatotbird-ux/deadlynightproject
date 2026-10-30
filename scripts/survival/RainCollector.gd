extends StaticBody3D
var session:Node
func _ready() -> void:
 collision_layer=4;collision_mask=0
 var mesh:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=0.32;cylinder.bottom_radius=0.25;cylinder.height=0.45;cylinder.radial_segments=12;mesh.mesh=cylinder
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color(0.22,0.32,0.35);mat.metallic=0.6;mesh.material_override=mat;mesh.position.y=0.23;add_child(mesh)
 var col:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=0.34;shape.height=0.5;col.shape=shape;col.position.y=0.25;add_child(col)
 var label:=Label3D.new();label.text="СБОР ДОЖДЕВОЙ ВОДЫ\nСырую воду нужно кипятить";label.font_size=24;label.pixel_size=0.004;label.position.y=0.9;add_child(label)
func get_interact_text() -> String:
 return "[E] Набрать 0,5 л сырой воды · запас %.1f л" % (session.rain_reserve*0.5)
func survival_interact() -> void:
 if session.health<=0:return
 if session.rain_reserve<1:session.notify("Сборник пуст: дождитесь дождя.");return
 if session.Items.transact(session.player,{},[session.Items.item("raw_water")]):
  session.rain_reserve-=1;session.notify("Набрано 0,5 л. Кипятите у горящего костра через рюкзак.")
 else:session.notify("Рюкзак заполнен")
