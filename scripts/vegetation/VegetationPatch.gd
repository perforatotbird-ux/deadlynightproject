extends RefCounted
# Stable identities and deterministic candidates, independent of loaded Nodes.
const Catalog=preload("res://scripts/vegetation/VegetationCatalog.gd")
const CELL:=48.0
static func key(cell:Vector2i) -> String:return "%d:%d"%[cell.x,cell.y]
static func candidates(cell:Vector2i,seed_value:int,version:int) -> Array:
 var random:=RandomNumberGenerator.new();random.seed=("vegetation:%d:%d:%s"%[seed_value,version,key(cell)]).hash()
 var out:Array=[]
 # One memorable patch per cell, deliberately sparse; single species per patch.
 var center:=Vector2(cell.x*CELL+random.randf_range(10,38),cell.y*CELL+random.randf_range(10,38))
 var species_ids:=Catalog.SPECIES.keys();species_ids.erase("stump_fan")
 var id:String=species_ids[random.randi_range(0,species_ids.size()-1)]
 var count:=1 if Catalog.species(id).family=="berry" else 3
 for i in count:
  var offset:=Vector2(cos(i*2.4),sin(i*2.4))*random.randf_range(1.5,3.5)
  out.append({"id":"veg%d:%s:0:%d"%[version,key(cell),i],"species":id,"xz":center+offset,"yaw":random.randf_range(0,TAU)})
 return out
static func collected(mask:Dictionary,id:String,group:int) -> bool:return mask.has(id+":"+str(group))

static func retained(record:Dictionary) -> bool:
 # Keep the first stable bush ID; never regenerate collected bushes on migration.
 return Catalog.species(str(record.get("species",""))).get("family","")!="berry" or str(record.get("id","")).ends_with(":0")
