# Delivery state
Stone stage: four variants, 1024 triangles each, shared cached runtime geometry,
one surface, 512px original grain, UV + vertex colors. Export reimport: no zero-area
triangles, all material/UV/color attributes present. Seven GLB evidence views inspected.
Godot 4.7.2: import pass, asset checks pass, script audit 73/73 pass, native renderer
screenshot inspected. Loader explicitly enables vertex albedo (Godot importer leaves it off).

Minerals stage: three pyrite intergrowths (1888–2320 tris), three flint flakes (1024 tris).
Fresh GLB import/UV/color/material and zero-area checks pass; Godot model test passes.
Native screenshot inspected after correcting per-island outward winding; this correction
also updates the stone exports. Runtime materials/textures shared by family to avoid
keeping duplicate embedded texture copies for each variant.

Branches stage: five shapes/sizes, curved sweeps, fork junctions, short knots, bark scar,
end-grain rings, exported tangent normal texture. 1074–1530 triangles, one surface.
Seven GLB views and native Godot screenshot inspected. Model checks pass;
meshes/generate_lods=true verified in import configurations.
