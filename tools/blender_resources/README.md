# Original forest resource assets
Blender 4.5.3 LTS; Python generators require bundled NumPy (ships with Blender).

```sh
blender -b -t 2 --python tools/blender_resources/build.py -- stone
blender -b -t 2 --python tools/blender_resources/build.py -- minerals
blender -b -t 2 --python tools/blender_resources/build.py -- branches
blender -b -t 2 --python tools/blender_resources/build.py -- fungi
blender -b -t 2 --python tools/blender_resources/validate.py -- fungi
godot --headless --editor --path . --import
godot --headless --path . -s tests/test_resource_models.gd -- --require-all
```

- Sources/evidence/manifests: `art/source/resources/` (excluded from Godot source import).
- Runtime: `assets/models/resources/*.glb` with Godot mesh LOD enabled.
- Loader: `ResourceModels.gd`, deterministic variant from persistent resource/patch ID,
  meshes cached per variant, one material/texture pair per family, vertex albedo enabled.
- Five fungal species, two variants each; species affects shape, not just recolor.
- MultiMesh grouping by species + harvest mask + variant (not unique patch ID).
- No new timers/process on individual assets; pickups culled at 85 m, streamed out by existing65m logic.
- Godot native preview: `tests/preview_resource_models.gd`; real forest preview:
  `tests/preview_resource_world.gd` (use disposable user profile; software-render QA hides distant nodes, not an FPS benchmark).
- GLBs/.blend/PNGs use Git LFS. Windows users must have LFS objects downloaded.
- Reference photographs are not shipped as textures. Geometry and textures generated here.
- Performance budget: see runtime_metrics.json for measured triangle/LOD counts, not FPS claims.
- Live Blender socket is unnecessary for this deterministic batch workflow; existing modeling,
  rendering, asset-validation and MCP-integration skills are retained in `.agents/skills`.
