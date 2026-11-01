extends RefCounted
# One cached texture per real item/species. No emoji fallback or duplicate inventory.
const ROOT:="res://assets/ui/field_journal/"
const IDS:=["brush","stone","flint","pyrite","camp_kit","log_birch","log_spruce","log_beech","log_oak","firewood_birch","firewood_spruce","firewood_beech","firewood_oak","axe","lantern","compass","matches","knife","bedroll","campfire"]
const PAINTED_IDS:=["water","raw_water","ration","berries","bandage","compress","antitoxin","field_notes","krasnitsa","sizovka","bolotnitsa","forest_fat","wood_fan","copper_false","pale_bell","stump_fan","cooked_forest_fat","cooked_wood_fan","cooked_copper_false","cooked_pale_bell","wood_tea","difficulty_explorer","difficulty_traveler","difficulty_survivor","difficulty_custom","category_all","category_resources","category_fuel","category_equipment","category_food","category_medicine","category_tools"]
static var cache:Dictionary={}
static func texture(id: String) -> Texture2D:
 if id=="":return null
 id={"tinder":"brush","spruce_needles":"brush","forest_bed":"bedroll"}.get(id,id)
 if cache.has(id) and cache[id]!=null:return cache[id]
 var loaded:Texture2D=null
 # Finished painted PNGs are preferred everywhere, including field-guide food.
 # Keep SVG compatibility only for legacy/missing resources, not as default art.
 for extension in [".png",".svg"]:
  var path:String=ROOT+"icons/"+id+extension
  loaded=load(path) if ResourceLoader.exists(path) else null
  if loaded==null and extension==".png":loaded=source_texture(path)
  if loaded!=null:break
 if loaded!=null:cache[id]=loaded # Never permanently cache a failed import.
 return loaded
static func source_texture(path:String) -> Texture2D:
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:return null
 if file.get_buffer(8)!=PackedByteArray([137,80,78,71,13,10,26,10]):return null
 file.close()
 var image:=Image.new()
 if image.load(ProjectSettings.globalize_path(path))!=OK:return null
 image.generate_mipmaps()
 return ImageTexture.create_from_image(image)
static func item_key(item: Dictionary) -> String:
 var kind:String=item.get("type",item.get("id",""))
 return kind+"_"+str(item.get("species","birch")) if kind in ["log","firewood"] else kind
