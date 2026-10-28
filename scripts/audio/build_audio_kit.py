"""Сборка аудиокита уровня 1: копирование отобранных звуков в assets/sounds.

Источники:
  * локальный пак  K:/concept art/400 Sounds Pack
  * CC0-библиотека  K:/concept art/_audio_sources/opengameart

Скрипт ничего не удаляет и не перезаписывает чужие файлы: он только копирует
отобранное в целевую папку и снимает метрики громкости (для WAV).

Запуск:
    python build_audio_kit.py            # копирование + отчёт
    python build_audio_kit.py --dry-run  # только показать, что будет сделано
"""
from __future__ import annotations

import argparse
import csv
import os
import shutil

import numpy as np
from scipy.io import wavfile

LOCAL = "K:/concept art/400 Sounds Pack"
OGA = "K:/concept art/_audio_sources/opengameart"
DEST = "K:/Deadly Night/assets/sounds/level_01"

# (источник, путь внутри DEST, назначение в терминах игрового события)
MAPPING: list[tuple[str, str, str]] = [
    # ---------------- Ambience ----------------
    (f"{OGA}/Forest_Ambience.mp3", "ambience/amb_forest_bed.mp3",
     "AMB_FOREST_BED — весенний лес, птицы, дальний фон"),
    (f"{LOCAL}/Environment/ambient_wind.wav", "ambience/amb_wind_canopy.wav",
     "AMB_WIND_CANOPY — ветер в кронах"),
    (f"{LOCAL}/Environment/water_babbling_loop.wav", "ambience/amb_stream_loop.wav",
     "AMB_STREAM — ручей (брод)"),
    (f"{LOCAL}/Environment/water_dripping.wav", "ambience/amb_drip_bed.wav",
     "AMB_DRIP_BED — капель в шахте"),

    # ---------------- Footsteps ----------------
    *[(f"{LOCAL}/Footsteps/digital/digital_footstep_grass_{i}.wav",
       f"footsteps/step_grass_{i:02d}.wav", "STEP_GRASS") for i in (1, 2, 3, 4)],
    *[(f"{LOCAL}/Footsteps/digital/digital_footstep_snow_{i}.wav",
       f"footsteps/step_litter_{i:02d}.wav", "STEP_LITTER (сухая подстилка)") for i in (1, 2, 3, 4)],
    *[(f"{LOCAL}/Footsteps/foley_footstep_gravel_{i}.wav",
       f"footsteps/step_gravel_{i:02d}.wav", "STEP_GRAVEL (дорога)") for i in (1, 2, 3, 4)],
    *[(f"{LOCAL}/Footsteps/foley_footstep_concrete_{i}.wav",
       f"footsteps/step_rock_{i:02d}.wav", "STEP_ROCK (скалы, камень)") for i in (1, 2, 3, 4)],
    *[(f"{LOCAL}/Footsteps/digital/digital_footstep_wood_{i}.wav",
       f"footsteps/step_wood_{i:02d}.wav", "STEP_WOOD (мост, настил)") for i in (1, 2, 3, 4)],
    *[(f"{LOCAL}/Footsteps/foley_footstep_vinyl_{i}.wav",
       f"footsteps/step_mud_{i:02d}.wav", "STEP_MUD (грязь, берег)") for i in (1, 2, 3, 4)],
    (f"{LOCAL}/Environment/water_splashing.wav", "footsteps/step_water_splash.wav",
     "STEP_WATER — вход в воду / брод"),
    (f"{LOCAL}/Environment/water_drop_medium.wav", "footsteps/step_water_drop.wav",
     "STEP_WATER — короткий всплеск"),

    # ---------------- Axe ----------------
    (f"{LOCAL}/Weapons/weapon_equip.wav", "axe/axe_equip.wav", "AXE_EQUIP"),
    (f"{LOCAL}/Other/whoosh_1.wav", "axe/axe_swing_01.wav", "AXE_SWING v1"),
    (f"{LOCAL}/Other/whoosh_2.wav", "axe/axe_swing_02.wav", "AXE_SWING v2"),
    (f"{OGA}/sfx_breaking_and_falling/bfh1_wood_hit_01.ogg", "axe/axe_hit_wood_01.ogg", "AXE_HIT — сухая/лёгкая порода"),
    (f"{OGA}/sfx_breaking_and_falling/bfh1_wood_hit_02.ogg", "axe/axe_hit_wood_02.ogg", "AXE_HIT — средняя"),
    (f"{OGA}/sfx_breaking_and_falling/bfh1_wood_hit_03.ogg", "axe/axe_hit_wood_03.ogg", "AXE_HIT — плотная"),
    (f"{OGA}/sfx_breaking_and_falling/bfh1_wood_breaking_01.ogg", "axe/axe_crack_01.ogg", "AXE_CRACK — стадия 2"),
    (f"{OGA}/sfx_breaking_and_falling/bfh1_wood_breaking_02.ogg", "axe/axe_crack_02.ogg", "AXE_CRACK — стадия 2"),
    (f"{OGA}/sfx_breaking_and_falling/bfh1_wood_breaking_03.ogg", "axe/axe_crack_03.ogg", "AXE_CRACK — стадия 3"),
    (f"{OGA}/sfx_breaking_and_falling/bfh1_wood_breaking_04.ogg", "axe/axe_crack_04.ogg", "AXE_CRACK — стадия 3"),
    (f"{OGA}/chop-tree-fall.ogg", "axe/tree_fall_combo.ogg", "TREE_FALL — полный цикл падения"),
    (f"{OGA}/sfx_breaking_and_falling/bfh1_wood_falling_01.ogg", "axe/tree_fall_branch_01.ogg", "BRANCH_FALL v1"),
    (f"{OGA}/sfx_breaking_and_falling/bfh1_wood_falling_02.ogg", "axe/tree_fall_branch_02.ogg", "BRANCH_FALL v2"),
    (f"{LOCAL}/Materials/wood_small_hollow.wav", "axe/wood_thunk.wav", "AXE_HIT — глухой удар в ствол"),
    (f"{LOCAL}/Materials/wood_small_drop.wav", "axe/chips_drop.wav", "AXE_CHIPS — щепа"),
    (f"{LOCAL}/Weapons/harsh_thud.wav", "axe/ground_thud.wav", "TREE_IMPACT_GROUND"),
    (f"{LOCAL}/Materials/wood_small_pickup.wav", "axe/log_pickup.wav", "LOG_PICKUP"),
    (f"{LOCAL}/Materials/wood_small_gather.wav", "axe/log_gather.wav", "LOG_TO_BACKPACK"),

    # ---------------- World / props ----------------
    (f"{LOCAL}/Environment/creaky_door_short.wav", "props/bridge_creak.wav", "BRIDGE_CREAK"),
    (f"{LOCAL}/Environment/creaky_door_long.wav", "props/portal_creak.wav", "PORTAL_CREAK"),
    (f"{LOCAL}/Materials/clothing_1.wav", "props/cloth_01.wav", "CLOTH_RUSTLE v1"),
    (f"{LOCAL}/Materials/clothing_2.wav", "props/cloth_02.wav", "CLOTH_RUSTLE v2"),
    *[(f"{OGA}/sfx_breaking_and_falling/bfh1_rock_falling_{i:02d}.ogg",
       f"props/rock_fall_{i:02d}.ogg", "ROCK_FALL / осыпь") for i in (1, 2, 3, 4, 5, 6, 7, 8, 9)],

    # ---------------- Mine ----------------
    (f"{LOCAL}/Materials/metal_clang.wav", "mine/rail_clank.wav", "RAIL_CLANK"),
    (f"{LOCAL}/Materials/metal_blunt_tap.wav", "mine/metal_tap.wav", "METAL_TAP"),
    *[(f"{OGA}/sfx_breaking_and_falling/bfh1_metal_hit_{i:02d}.ogg",
       f"mine/metal_hit_{i:02d}.ogg", "METAL_HIT (рельсы, вагонетка)") for i in (1, 2, 3, 4, 5, 6)],
    *[(f"{OGA}/sfx_breaking_and_falling/bfh1_metal_falling_{i:02d}.ogg",
       f"mine/metal_fall_{i:02d}.ogg", "METAL_FALL (обрушение крепи)") for i in (1, 2, 3, 4, 5)],
    (f"{LOCAL}/Footsteps/foley_creak_1.wav", "mine/timber_creak.wav", "TIMBER_CREAK"),
    (f"{LOCAL}/Other/light_match.wav", "mine/lamp_light.wav", "LAMP_LIGHT"),
    (f"{LOCAL}/Environment/gurgling.wav", "mine/flooded_water.wav", "FLOODED_BRANCH — вода"),

    # ---------------- UI ----------------
    (f"{LOCAL}/UI/select_1.wav", "ui/ui_hover.wav", "UI_HOVER"),
    (f"{LOCAL}/UI/pop_1.wav", "ui/ui_click.wav", "UI_CLICK"),
    (f"{LOCAL}/UI/toggle_on.wav", "ui/ui_inventory_open.wav", "UI_INVENTORY_OPEN"),
    (f"{LOCAL}/UI/toggle_off.wav", "ui/ui_inventory_close.wav", "UI_INVENTORY_CLOSE"),
    (f"{LOCAL}/UI/synth_warning.wav", "ui/ui_overweight.wav", "UI_OVERWEIGHT"),
    (f"{LOCAL}/Items/item_equip.wav", "ui/ui_pickup.wav", "UI_PICKUP"),
    (f"{LOCAL}/UI/synth_process_complete.wav", "ui/ui_objective.wav", "UI_OBJECTIVE"),

    # ---------------- Music ----------------
    (f"{LOCAL}/Musical Effects/vibraphone_mystery.wav", "music/mus_sting_mystery.wav", "MUS_STING (плейсхолдер)"),
    (f"{LOCAL}/Musical Effects/vibraphone_level_start.wav", "music/mus_level_start.wav", "MUS_LEVEL_START (плейсхолдер)"),
]


def peak_dbfs(path: str) -> tuple[float | None, float | None]:
    """Возвращает (peak_dBFS, rms_dBFS) для WAV. Для сжатых форматов — (None, None)."""
    if not path.lower().endswith(".wav"):
        return None, None
    try:
        rate, data = wavfile.read(path)
    except Exception:  # noqa: BLE001
        return None, None

    if data.dtype == np.int16:
        x = data.astype(np.float32) / 32768.0
    elif data.dtype == np.int32:
        x = data.astype(np.float32) / 2147483648.0
    elif data.dtype == np.uint8:
        x = (data.astype(np.float32) - 128.0) / 128.0
    else:
        x = data.astype(np.float32)

    if x.size == 0:
        return None, None
    peak = float(np.max(np.abs(x)))
    rms = float(np.sqrt(np.mean(np.square(x))))
    to_db = lambda v: 20.0 * np.log10(v) if v > 1e-9 else -120.0  # noqa: E731
    return round(to_db(peak), 2), round(to_db(rms), 2)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    rows: list[dict] = []
    missing: list[str] = []

    for src, rel, purpose in MAPPING:
        dst = os.path.join(DEST, rel)
        exists = os.path.isfile(src)
        if not exists:
            missing.append(src)
            continue
        if not args.dry_run:
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)
        peak, rms = peak_dbfs(src)
        rows.append({
            "file": rel,
            "purpose": purpose,
            "src": src.replace("K:/concept art/", ""),
            "size_kb": round(os.path.getsize(src) / 1024.0, 1),
            "peak_dbfs": peak,
            "rms_dbfs": rms,
            "gain_to_-3db": round(-3.0 - peak, 1) if peak is not None else None,
        })

    print(f"Скопировано: {len(rows)} / {len(MAPPING)}")
    if missing:
        print(f"Не найдено источников: {len(missing)}")
        for m in missing:
            print("   !", m)

    if not args.dry_run:
        report = "K:/Deadly Night/data/audio_kit_report.csv"
        os.makedirs(os.path.dirname(report), exist_ok=True)
        with open(report, "w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
            w.writeheader()
            w.writerows(rows)
        print("Отчёт:", report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
