# Portable storm lantern

Original reusable Godot scene: `portable_lantern.tscn`; source geometry:
`scripts/props/PortableLantern.gd`. No downloaded models or external textures.

The model includes a profiled pressed-metal fuel reservoir, rolled foot,
brass burner and wick adjustment, glass globe, two guards, ventilated chimney,
wire carry bail, leather grip and emissive flame. Height: approximately 0.52 m
before the first-person scale of 0.8. The scene exposes `set_lit(bool)`.

The first-person instance is mounted on the existing camera sway pivot. Slot 2
equips it; the existing tool-use action toggles flame and light. Stowing it hides
the model and disables world illumination, while preserving its switch state.

World illumination uses one warm OmniLight3D (14 m range, smooth 1.35 distance
attenuation, energy 2.2) instead of a directional flashlight cone. The source
tracks the actual flame through camera pitch, yaw and viewmodel sway. A short
camera-to-globe physics ray keeps it 12 cm on the visible side of close walls,
trunks and props; after clearing the obstacle it returns to the globe.

Cube shadow maps retain real obstacle shadows without a spotlight edge or a
dual-paraboloid hemisphere seam. Viewmodel geometry uses layer 20 (bit 19), casts
no shadows and is excluded from world illumination. The small viewmodel-only
warm fill is unchanged; it does not illuminate terrain. No extra world lights
were added. The surrounding forest remains dark beyond the local light radius.

Tests: `tests/test_lantern_status_hud.gd`: globe tracking under yaw/pitch,
close-wall source retraction, stowing/toggling, real-render forward-wall
luminance, and floor illumination at 3, 6 and 9 metres plus both sides while
looking down. Native captures compare lamp-off and lamp-on ground coverage.

Terrain regression: the current terrain GLB has a tangent-space normal texture
but lacks the UV/tangent attributes needed to apply it. `WorldMap` supplies one
shared material fallback for those surfaces, disabling only invalid normal
mapping and retaining geometric normals, colour texture and roughness. This
removes the black lighting half-plane present even with shadows disabled.
Valid UV/tangent surfaces keep their normal maps. Source assets, mesh geometry
and collision are unchanged. `tests/test_terrain_lantern_lighting.gd` renders
lamp-off/on samples on the actual imported spawn chunk, not just a test plane.
