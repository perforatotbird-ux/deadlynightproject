extends RefCounted
## External assets: LOLIPOP birches (CC BY 4.0), Quaternius others (CC0).
const ROOT := "res://assets/models/external/quaternius/"
const BIRCH_ROOT := "res://assets/models/external/lolipop/"
const BIRCH_VARIANTS := 5
const AXE := ROOT + "axe_quaternius.glb"
static var _birch_manifest: Dictionary = {}

static func birch_variant(tree_id: String = "") -> int:
 # Stable ID, not RNG or position: forest, proximity, damage and saves agree.
 return posmod(tree_id.hash(), BIRCH_VARIANTS) if not tree_id.is_empty() else 0

static func tree_key(species: String, tree_id: String = "") -> String:
 return "birch_%d" % birch_variant(tree_id) if species == "birch" else species

static func tree_path(species: String, tree_id: String = "") -> String:
 if species == "birch":
  var birch := BIRCH_ROOT + "birch_%d.tscn" % birch_variant(tree_id)
  if ResourceLoader.exists(birch): return birch
 var path := ROOT + "tree_%s.glb" % species
 return path if ResourceLoader.exists(path) else "res://assets/models/trees/tree_%s.glb" % species

static func tree_radius(species: String, tree_id: String, fallback: float) -> float:
 if species != "birch" or not FileAccess.file_exists(BIRCH_ROOT+"manifest.json"):return fallback
 if _birch_manifest.is_empty():_birch_manifest=JSON.parse_string(FileAccess.get_file_as_string(BIRCH_ROOT+"manifest.json"))
 return float(_birch_manifest["variants"][birch_variant(tree_id)]["radius"])

static func axe_path() -> String:
 return AXE if ResourceLoader.exists(AXE) else "res://assets/models/props/axe_iron.glb"
