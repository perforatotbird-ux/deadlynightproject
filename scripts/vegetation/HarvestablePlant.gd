extends StaticBody3D
# No per-plant process/timer. Director owns logical crop and proximity activation.
const Visuals=preload("res://scripts/vegetation/VegetationVisuals.gd")
const Catalog=preload("res://scripts/vegetation/VegetationCatalog.gd")
var director:Node
var record:Dictionary={}
var visual:MeshInstance3D
func _ready() -> void:
 collision_layer=4;collision_mask=0
 visual=MeshInstance3D.new();add_child(visual);refresh()
 var col:=CollisionShape3D.new();var shape:=BoxShape3D.new()
 shape.size=Vector3(1.1,0.85,1.1) if Catalog.species(record.species).family=="berry" else Vector3(0.40,0.46,0.40)
 col.shape=shape;col.position.y=shape.size.y*0.5;add_child(col)
func refresh() -> void:
 var bits:int=director.mask(record)
 visual.visible=Catalog.species(record.species).family=="berry" or bits==0
 if visual.visible:visual.mesh=Visuals.mesh(record.species,bits,str(record.id))
 collision_layer=4 if Catalog.species(record.species).family=="berry" or director.mask(record)==0 else 0
func get_interact_text() -> String:
 var d:=Catalog.species(record.species)
 var near:bool=director.session.player._camera.global_position.distance_to(global_position)<2.5
 if not near:return "Ягодный куст" if d.family=="berry" else "Гриб"
 director.inspect(record.species)
 return str(d.name)+(" · Ягод нет" if director.remaining(record)==0 else " · [E] Собрать")
func survival_interact() -> void:
 director.inspect(record.species)
 director.begin_harvest(record,global_transform)
