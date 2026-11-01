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

Final fungal stage: five species × two variants, 1240–4428 triangles; different domes,
bell profiles, stalk widths, annulus/volva, radial gills, fleshy and banded woody shelves.
Near/far deterministic variants match, harvest masks preserved, far batching retained.
Final sources consolidated with separated objects, studio lights/camera and packed maps.
All 25 final GLBs fresh-imported; seven evidence views each. Topology audit passes
all 25 (position-welded audit handles glTF hard-normal/UV splits): closed components,
outward winding, no zero-area faces, one material, UV and vertex colors present.
Actual Godot generated LOD index counts recorded in runtime_metrics.json (not assumed).
Models use shared material per family; individual nodes have no per-frame logic.

Regression: 11 suites pass, including real launch scene W/Tab/M/Esc/T (18/18), vegetation
55/55 and world persistence45/45, first-night104/104, integration28/28, food63/63,
cooking9/9, inventory7/7 and141/141, part2 578/578, script audit73/73.
The old first-night integration fixture lacked mandatory crafted tinder: corrected test
setup through existing make_recipe/add_tinder, without changing gameplay requirements.

Rendering limitation: full native forest exceeded this 4GB software-render sandbox;
final forest screenshot uses real terrain with distant render nodes hidden only in the
QA script. It is not a target-GPU FPS measurement. Production view distances unchanged.
Some shutdown resource warnings remain; no claim of warning-free engine exit.
