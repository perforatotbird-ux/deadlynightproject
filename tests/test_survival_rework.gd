extends SceneTree
const Items=preload("res://scripts/survival/SurvivalItems.gd")
const Craft=preload("res://scripts/survival/CraftCatalog.gd")
var passes:=0
var failures:=0
func check(ok:bool,text:String)->void:
 if ok:passes+=1;print("PASS: "+text)
 else:failures+=1;print("FAIL: "+text)
func _initialize()->void:
 check(Items.item("brush").name=="Ветки","legacy brush identity remains compatible but is named branches")
 check(Items.item("tinder").name=="Хворост","tinder is a separate item")
 check(Craft.recipe("tinder").costs=={"brush":1},"one branch crafts tinder")
 print("SURVIVAL REWORK SUMMARY: %d PASS, %d FAIL" % [passes,failures]);quit(1 if failures else 0)
