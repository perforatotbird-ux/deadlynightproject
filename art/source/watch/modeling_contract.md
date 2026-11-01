# Traverse 01 — left-arm watch viewmodel

## Reference observations
User-provided photograph: bare left forearm entering from the left, semi-closed hand, round black/navy sports watch, protective bezel, physical side buttons, flexible dark strap. The second pointing hand, background/legs, branding and pulse display are not requested geometry.

## Deliverables
- Editable high-poly `.blend`, subdivision 3 anatomical arm, complete separate watch parts.
- Runtime PBR `.glb`, no baked preview time, real-time labels attached by `DisplayAnchor` in Godot.
- Deterministic Python construction and original tiling skin maps.
- Installed modeling/character/MCP/render/validation skills, pinned provenance and licenses.
- Native Godot reading pose and Blender multiview evidence.

## Scope and constraints
- Smooth anatomy, not a low-poly glove or a set of intersecting finger primitives.
- Anatomical base is an explicitly credited CC0 topology derivative, not claimed as sculpted from scratch.
- Watch design is original: Traverse Field / 01, circular petrol bezel, composite body, titanium hardware, rubber strap and buckle.
- Watch diameter approximately 53 mm; detailed source arm approximately 249k triangles; runtime whole assembly below 100k triangles and 12 mesh objects.
- Static finger pose; T moves the whole viewmodel. No individual-finger rig or touch-screen interaction is claimed.
- UI shows the game clock and day only, not fabricated pulse/medical measurements.
- Runtime compatibility target: Godot 4.7.2, Forward+ project, actual visual check on Compatibility software renderer. Target-GPU Forward+ FPS remains unverified.

## Review stages
1. Contract/reference: silhouette and watch construction extracted from supplied photograph.
2. Proportions: successive geometry/pose reviews; primitive-style hand rejected.
3. Primary form: connected anatomical palm/webs/digits, flexed fingers and thumb opposition.
4. Refinement: wrist/band fit, capped proximal extension, bevels and smooth silhouette.
5. Materials: original skin albedo/normal maps; distinct elastomer/composite/anodized metal/dial.
6. Presentation: opened native first-person screenshot, hero and complementary views.
7. Export: fresh Blender import and Godot behavior/geometry tests; reproducible rebuild.
