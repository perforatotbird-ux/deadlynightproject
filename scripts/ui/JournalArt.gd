extends RefCounted
# One cached texture per real item/species. No emoji fallback or duplicate inventory.
const ROOT:="res://assets/ui/field_journal/"
const IDS:=["brush","stone","flint","pyrite","camp_kit","log_birch","log_spruce","log_beech","log_oak","firewood_birch","firewood_spruce","firewood_beech","firewood_oak","axe","lantern","compass","matches","knife","bedroll","campfire"]
static var cache:Dictionary={}
static func texture(id: String) -> Texture2D:
 if id=="":return null
 if cache.has(id) and cache[id]!=null:return cache[id]
 var path:=ROOT+"icons/"+id+(".svg" if id in ["water","raw_water","ration","berries","bandage","compress"] else ".png")
 var loaded:Texture2D=load(path) if ResourceLoader.exists(path) else null
 # Source-checkout fallback if the editor import cache is absent/stale.
 # Exported PCKs continue to use ResourceLoader and their imported textures.
 if loaded==null:loaded=source_texture(path)
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
