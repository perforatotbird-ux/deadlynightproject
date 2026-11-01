extends SceneTree
var passes:=0
var failures:=0
func check(ok:bool,label:String)->void:
 if ok:passes+=1;print("PASS: "+label)
 else:failures+=1;print("FAIL: "+label)
func _initialize()->void:
 var patch=preload("res://scripts/vegetation/VegetationPatch.gd")
 var catalog=preload("res://scripts/vegetation/VegetationCatalog.gd")
 var berry_cells:=0
 for x in range(-12,12):
  for y in range(-12,12):
   var records:Array=patch.candidates(Vector2i(x,y),catalog.SEED,catalog.VERSION)
   if catalog.species(records[0].species).family=="berry":
    berry_cells+=1;check(records.size()==1,"one berry bush per original berry patch")
   else:check(records.size()==3,"mushroom density unchanged")
 check(berry_cells>0,"berry populations remain present")
 check(patch.retained({"id":"veg1:0:0:0:0","species":"krasnitsa"}) and not patch.retained({"id":"veg1:0:0:0:1","species":"krasnitsa"}),"old cached berry patches thin without changing retained IDs")
 print("PART2 SUMMARY: %d PASS, %d FAIL" % [passes,failures]);quit(1 if failures else 0)
