# Quaternius models for Deadly Night

Author: Quaternius. License: CC0 1.0 Universal.

- Ultimate Nature Pack: https://quaternius.com/packs/ultimatenature.html
- Survival Pack: https://quaternius.com/packs/survival.html
- License: https://creativecommons.org/publicdomain/zero/1.0/

Original licenses and source Blender files are retained here. `manifest.json`
records exact download URLs and SHA-256 hashes. Source files are excluded from
Godot importing with `third_party/.gdignore` (not from version control).

Mapping:
- BirchTree_1 → birch (18 m)
- PineTree_1 → gameplay spruce (24 m; stylized conifer, not botanical spruce)
- CommonTree_3 → gameplay beech (24 m; generic broadleaf, not botanical beech)
- CommonTree_1 → gameplay oak (20 m; generic broadleaf, not botanical oak)
- Axe → first-person axe (0.678 m; original animation and grip preserved)

Runtime GLBs: `assets/models/external/quaternius/`.
`ExternalModels.gd` resolves both forest and interactive-tree visuals to the same
mesh and falls back to original assets if the new resource is missing. Existing
fracture code uses bark-tagged surfaces. The lower birch stem is recentered
per height to preserve the radial carving contract; source topology is retained. Procedural cut faces, logs and old legacy
resources remain the project's own assets. Item icons have not been replaced.

Rebuild from repository root:

```bash
blender --background --factory-startup --disable-autoexec \
  --python scripts/blender/import_quaternius_models.py
godot --headless --path . --editor --import
```

The models are stylized low-poly. No claim of photorealism or exact botanical
species. No external Blender auto-run script was enabled.
