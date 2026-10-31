# Portable storm lantern

Original reusable Godot scene: `portable_lantern.tscn`; source geometry:
`scripts/props/PortableLantern.gd`. No downloaded models or external textures.

The model includes a profiled pressed-metal fuel reservoir, rolled foot,
brass burner and wick adjustment, glass globe, two guards, ventilated chimney,
wire carry bail, leather grip and emissive flame. Height: approximately 0.52 m
before the first-person scale of 0.8. The scene exposes `set_lit(bool)`.

The first-person instance is mounted on the existing camera sway pivot. Slot 2
equips it; the existing tool-use action toggles flame and light. Stowing it hides
the model and disables the world beam, while preserving its switch state.

World illumination is a camera-child SpotLight3D, explicitly oriented along
camera local -Z and placed ahead of the model. Its rotation is independent of
the decorative model. Viewmodel geometry uses layer 20 (bit 19), casts no
shadows, and is excluded from the world beam. A small viewmodel-only warm fill
makes the globe and metal visible without illuminating terrain behind the player.

Tests: `tests/test_lantern_status_hud.gd`, including forward-axis checks under
yaw/pitch and a real-render luminance comparison of a wall in front of the player.
