extends RefCounted
## CC0 Quaternius models. Original resources remain available as safe fallbacks.
const ROOT := "res://assets/models/external/quaternius/"
const AXE := ROOT + "axe_quaternius.glb"
static func tree_path(species: String) -> String:
 var path := ROOT + "tree_%s.glb" % species
 return path if ResourceLoader.exists(path) else "res://assets/models/trees/tree_%s.glb" % species
static func axe_path() -> String:
 return AXE if ResourceLoader.exists(AXE) else "res://assets/models/props/axe_iron.glb"
