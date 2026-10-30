# Weather audio sources

## thunder_01.ogg

- Author: rubberduck.
- Source: https://opengameart.org/content/100-cc0-sfx-2
- Download: https://opengameart.org/sites/default/files/sfx_100_v2.zip
- Original archive member: `sfx100v2_thunder_01.ogg`.
- License stated on the source page: **CC0** (https://creativecommons.org/publicdomain/zero/1.0/).
- Original recording retained; runtime pitch variation 0.84–1.08, not a generated placeholder.

## thunder_02.ogg

- Author: WuxiaScrub.
- Source: https://opengameart.org/content/rain-long-thunder
- Download: https://opengameart.org/sites/default/files/rain-thunder.ogg
- Source page: **CC0**, attribution optional.
- Edited from 19–29 seconds of the source (the documented long thunder near second 20); 2-second ending fade, Vorbis quality 5. This recording includes a quiet rain bed, not an isolated studio thunder stem.
- Reproduce: `ffmpeg -ss 19 -i rain-thunder.ogg -t 10 -af 'afade=t=out:st=8:d=2' -c:a libvorbis -q:a 5 thunder_02.ogg`.

No new rain or wind recordings were invented. Existing project rain, forest bed,
night ambience and canopy wind are reused under their existing provenance.
Two distinct recorded rolls plus bounded pitch variation reduce repetition;
this is not a large production thunder library. Indoor treatment uses gain and
distance-filter adjustment, not simulated propagation through the mine.
