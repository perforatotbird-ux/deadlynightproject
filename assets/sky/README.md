# Living sky art direction and provenance

## Target palettes (linear shader values, not screenshots)

- Day: blue zenith `(0.16, 0.36, 0.64)`, pale haze, neutral cloud undersides.
- Sunset: low amber/copper toward the sun, blue overhead; no all-screen orange filter.
- Moonlit night: deep blue zenith `(0.012, 0.024, 0.052)`, silver disk, weak cool directional light.
- New moon: same faint atmospheric horizon, no artificial moon fill; lantern/fire remain valuable.
- Storm: dense charcoal clouds, restrained blue-white illumination, no full-screen white flash.

## Assets

- `source/moon_generated.jpg`: AI-generated original artwork, 1024². Prompt direction:
  *Neutral full face of a cratered moon, detailed gray albedo, flat lighting, centered circular disk, black outside disk, no crescent, no halo, no stars, no typography.*
- `source/milky_way_generated.jpg`: AI-generated original artwork, 1456×720. Prompt direction:
  *Restrained natural Milky Way dust band, dark navy background, faint irregular cool white/cream structure and dark lanes, no planets, no prominent stars, no Moon, no sci-fi nebula, no lettering.*
  This source is **not** a finished panorama or an astronomical chart. The shader uses a processed, seam-blended, pole-faded equatorial background layer at low intensity.
- `moon.png`: downsampled 512² disk; the shader, not the image, computes the lit hemisphere using the same sun direction as lighting.
- `stars_{px,nx,py,ny,pz,nz}.png`: six 1024² cubemap faces, deterministic equal-area spherical sources, seed 41873, natural tint/brightness tiers. Stars are analytically splatted by angular distance across face boundaries, eliminating equirectangular polar stretching. Artistic field, not catalogued constellations. Runtime Cubemap objects with mipmaps are built once and cached per profile; the low profile uses 256² faces.
- `milky_way.png`: 4096×2048 processed band; horizontal edge blend and zero signal at poles.
- `milky_way_low.png`: 1024×512 low-quality diffuse band, generated offline.
- `build_assets.py`: reproducible processing (`Pillow`, `numpy`); run from any directory. No per-frame CPU texture generation; cubemap upload/mipmap creation occurs once per cached profile. Runtime cubemaps and diffuse-band import files use mipmaps to reduce shimmer.

The saved model includes its weather seed and astronomical parameters. The star **asset** has its own documented fixed seed; changing the weather seed does not silently regenerate constellations.
