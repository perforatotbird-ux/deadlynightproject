# Original image generation prompts

## Milky Way diffuse texture

Generate a restrained premium wilderness survival game's MILKY WAY DIFFUSE TEXTURE. Wide 2:1 equirectangular spherical environment map, seamless left-right wrapping, completely empty near-black top/bottom polar zones. A faint delicate diagonal Milky Way dust band crossing the middle latitude, intricate wispy interstellar dust lanes and subtle cool blue-gray / warm ivory luminosity against very dark space. NO foreground, NO trees, NO horizon, NO sun, NO moon, NO planets, NO bright stars, NO stars as point sources (stars added separately by game), NO lettering. This is subtle distant galactic dust, NOT a bright purple fantasy nebula or science-fiction poster. Ensure dark reserved large open spaces for overlaid real-time star field. Physically inspired but artistic, excellent fine texture detail, strongest band no more than muted gray, ideally 2048x1024.

Actual returned raster: 1456×720, not a ready-to-use spherical panorama. See processing in `../build_assets.py` and the README.

## Lunar surface albedo

Create a clean game-ready LUNAR SURFACE ALBEDO disc texture, perfectly circular full moon centered in a square image, front orthographic view. Entire lunar face evenly illuminated with NO crescent, NO terminator, NO directional cast shadow; shader will apply moving phases. Detailed believable desaturated silver-gray highlands, charcoal lunar maria, fine crater ejecta and subtle ancient impact craters, not exaggerated. Exact disc radius approximately 43 percent of image width, plain pure black background, no stars, no glow, no atmosphere, no text, no labels, no border. Premium natural restrained texture for a realistic woodland survival night sky. Do not draw a shiny planet or fantasy moon. Large high resolution square.

Actual returned raster: 1024², disk nearly fills the frame. The runtime shader masks and phases the disk; it does not assume that the generator followed every geometric instruction.
