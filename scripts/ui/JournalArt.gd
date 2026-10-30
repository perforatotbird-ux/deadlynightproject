extends RefCounted
# One cached texture per real item/species. No emoji fallback or duplicate inventory.
const ROOT:="res://assets/ui/field_journal/"
const IDS:=["brush","stone","flint","pyrite","camp_kit","log_birch","log_spruce","log_beech","log_oak","firewood_birch","firewood_spruce","firewood_beech","firewood_oak","axe","lantern","compass","matches","knife","bedroll","campfire"]
static var cache:Dictionary={}
static func texture(id: String) -> Texture2D:
 if id=="":return null
 if not cache.has(id):
  var path:=ROOT+"icons/"+id+".png"
  cache[id]=load(path) if ResourceLoader.exists(path) else null
 return cache[id]
static func item_key(item: Dictionary) -> String:
 var kind:String=item.get("type",item.get("id",""))
 return kind+"_"+str(item.get("species","birch")) if kind in ["log","firewood"] else kind
