# Аудио-ассеты уровня 1 — происхождение и лицензии

Все файлы в этой папке — сторонние библиотеки. Ниже указано, что откуда взято.

## 1. OpenGameArt (CC0 / Public Domain)

CC0 не требует атрибуции. Указано для прослеживаемости.

| Файлы в проекте | Источник | Лицензия |
|---|---|---|
| `ambience/amb_forest_bed.mp3` | [Forest Ambience](https://opengameart.org/content/forest-ambience) | CC0 |
| `axe/axe_hit_wood_01…03.ogg`, `axe/axe_crack_01…04.ogg`, `axe/tree_fall_branch_01…02.ogg`, `props/rock_fall_01…09.ogg`, `mine/metal_hit_01…06.ogg`, `mine/metal_fall_01…05.ogg` | [75 CC0 Breaking / Falling / Hit SFX](https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx) | CC0 |
| `axe/tree_fall_combo.ogg` | [Tree Chop Fall Thud](https://opengameart.org/content/tree-chop-fall-thud) | CC0 |

## 2. Локальная библиотека «400 Sounds Pack»

Источник: `K:\concept art\400 Sounds Pack\` (копия в `K:\concept art\400 Sounds Pack.zip`).
Файл лицензии в паке отсутствует — **право использования не подтверждено документально**.

| Файлы в проекте | Исходные файлы |
|---|---|
| `ambience/amb_wind_canopy.wav` | `Environment/ambient_wind.wav` |
| `ambience/amb_stream_loop.wav` | `Environment/water_babbling_loop.wav` |
| `ambience/amb_drip_bed.wav` | `Environment/water_dripping.wav` |
| `footsteps/step_grass_01…04.wav` | `Footsteps/digital/digital_footstep_grass_1…4.wav` |
| `footsteps/step_litter_01…04.wav` | `Footsteps/digital/digital_footstep_snow_1…4.wav` |
| `footsteps/step_gravel_01…04.wav` | `Footsteps/foley_footstep_gravel_1…4.wav` |
| `footsteps/step_rock_01…04.wav` | `Footsteps/foley_footstep_concrete_1…4.wav` |
| `footsteps/step_wood_01…04.wav` | `Footsteps/digital/digital_footstep_wood_1…4.wav` |
| `footsteps/step_mud_01…04.wav` | `Footsteps/foley_footstep_vinyl_1…4.wav` |
| `footsteps/step_water_splash.wav` | `Environment/water_splashing.wav` |
| `footsteps/step_water_drop.wav` | `Environment/water_drop_medium.wav` |
| `axe/axe_equip.wav` | `Weapons/weapon_equip.wav` |
| `axe/axe_swing_01…02.wav` | `Other/whoosh_1…2.wav` |
| `axe/wood_thunk.wav` | `Materials/wood_small_hollow.wav` |
| `axe/chips_drop.wav` | `Materials/wood_small_drop.wav` |
| `axe/ground_thud.wav` | `Weapons/harsh_thud.wav` |
| `axe/log_pickup.wav` | `Materials/wood_small_pickup.wav` |
| `axe/log_gather.wav` | `Materials/wood_small_gather.wav` |
| `props/bridge_creak.wav` | `Environment/creaky_door_short.wav` |
| `props/portal_creak.wav` | `Environment/creaky_door_long.wav` |
| `props/cloth_01…02.wav` | `Materials/clothing_1…2.wav` |
| `mine/rail_clank.wav` | `Materials/metal_clang.wav` |
| `mine/metal_tap.wav` | `Materials/metal_blunt_tap.wav` |
| `mine/timber_creak.wav` | `Footsteps/foley_creak_1.wav` |
| `mine/lamp_light.wav` | `Other/light_match.wav` |
| `mine/flooded_water.wav` | `Environment/gurgling.wav` |
| `ui/*.wav` | `UI/select_1`, `UI/pop_1`, `UI/toggle_on/off`, `UI/synth_warning`, `Items/item_equip`, `UI/synth_process_complete` |
| `music/*.wav` | `Musical Effects/vibraphone_*` |

**Статус:** плейсхолдеры до подтверждения лицензии. Перед публичным билдом заменить на CC0-аналоги либо получить письменное разрешение автора пака.

## 3. Sonniss GDC Game Audio Bundle 2026

Источник: `K:\concept art\_audio_sources\sonniss_gdc2026\` (5 архивов, 6.92 ГБ).
Лицензия: royalty-free, **атрибуция не требуется**, коммерческое использование
без ограничений по числу проектов и сроку.

Все файлы сконвертированы в 48 кГц и нормализованы (`loudnorm`), монтажи
нарезаны по паузам. Скрипт: `scripts/audio/import_sonniss.py`.

| Файлы в проекте | Исходная библиотека |
|---|---|
| `ambience/amb_meadow_spring.ogg` | Just Sound Effects — Highlands of Norway |
| `ambience/amb_water_lap.ogg` | Just Sound Effects — Highlands of Norway |
| `mine/mine_roomtone_loop.ogg` | Epic Stock Media — Strange Game Ambient Loops 3 |
| `music/mus_tension_drone.ogg` | Epic Stock Media — Strange Game Ambient Loops 3 |
| `player/player_pant.wav` | SoundBits — Vox Hominis |
| `mine/metal_thud.wav`, `mine/metal_scrape.wav`, `mine/timber_screech.wav` | The Noisery — Moaning Metal |
| `axe/axe_swing_real_01…08.wav` | David Dumais Audio — Melee Weapons Pack 2 |
| `axe/axe_hit_real_01.wav` | 344 Audio — Medieval Weapons Vol. 2 |

## 4. Резерв

`K:\concept art\_audio_sources\sonniss_gdc2026\` — Sonniss GDC Game Audio Bundle 2026.
Royalty-free, атрибуция не требуется, коммерческое использование без ограничений.
Используется для замены плейсхолдеров, перечисленных в `Docs/audio_design_level1.md` §8.
