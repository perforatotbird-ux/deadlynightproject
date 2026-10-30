"""Импорт звуков из Sonniss GDC 2026 в кит уровня 1.

Что делает:
  * конвертирует 96/192 кГц WAV в 48 кГц;
  * нормализует громкость (loudnorm) под целевой уровень категории;
  * длинные «монтажи» (несколько вариаций в одном файле) режет по паузам
    через silencedetect и раскладывает на отдельные варианты.

Требует ffmpeg. Путь берётся из FFMPEG_EXE или из стандартной папки сборки.

Запуск:
    python import_sonniss.py --dry-run
    python import_sonniss.py
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

STAGING = "K:/concept art/_audio_sources/sonniss_gdc2026/_staging"
DEST = "K:/Deadly Night/assets/sounds/level_01"

FFMPEG_CANDIDATES = [
    os.environ.get("FFMPEG_EXE", ""),
    "C:/Users/inval/.workbuddy-ai/binaries/ffmpeg/bin/ffmpeg.exe",
]

# Целевые уровни громкости (LUFS) и потолок True Peak.
LOUDNESS = {
    "loop_amb":  {"I": -26, "TP": -6},
    "loop_mus":  {"I": -28, "TP": -6},
    "oneshot":   {"I": -18, "TP": -3},
    "ui":        {"I": -18, "TP": -6},
}

# (фрагмент имени в staging, режим, целевой путь, комментарий)
JOBS = [
    ("AMBSwmp_Meadow Pipits",        "loop", "ambience/amb_meadow_spring.ogg",   "loop_amb"),
    ("AMBRoom_Factory Loop",         "loop", "mine/mine_roomtone_loop.ogg",      "loop_amb"),
    ("DSGNSynth_Dark Loop Mystic",   "loop", "music/mus_tension_drone.ogg",      "loop_mus"),
    ("WATRLap_Small Waves",          "loop", "ambience/amb_water_lap.ogg",       "loop_amb"),

    ("HMNBrth_Panting Male 02 04",   "one",  "player/player_pant.wav",           "oneshot"),
    ("DSGNImpt_Metal Hit Thud",      "one",  "mine/metal_thud.wav",              "oneshot"),
    ("DSGNTonl_Metal Scrape Low",    "one",  "mine/metal_scrape.wav",            "oneshot"),
    ("DSGNTonl_Designed Metal Bowed","one",  "mine/timber_screech.wav",          "oneshot"),

    # Монтажи: режем по паузам на отдельные вариации.
    ("WEAPBlnt_Spear And Stick",     "split", "axe/axe_hit_real",                "oneshot"),
    ("SWSH_SWING IMPACTS Quick",     "split", "axe/axe_swing_real",              "oneshot"),
]

SPLIT_LIMITS = (0.35, 3.0)   # какие сегменты считать валидным one-shot, с
SPLIT_MAX_VARIANTS = 8


def find_ffmpeg() -> str:
    for c in FFMPEG_CANDIDATES:
        if c and os.path.isfile(c):
            return c
    raise SystemExit("ffmpeg не найден. Задайте FFMPEG_EXE.")


def run(cmd: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                          errors="replace")


def convert(src: str, dst: str, loud: dict, ffmpeg: str) -> bool:
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    af = f"loudnorm=I={loud['I']}:TP={loud['TP']}:LRA=11"
    if dst.endswith(".ogg"):
        codec = ["-c:a", "libvorbis", "-q:a", "4"]
    else:
        codec = ["-c:a", "pcm_s16le"]
    cmd = [ffmpeg, "-y", "-i", src, "-af", af, "-ac", "2", "-ar", "48000", *codec, dst]
    p = run(cmd)
    if p.returncode != 0:
        print(f"   ffmpeg error: {p.stderr.strip().splitlines()[-1][:120]}")
        return False
    return True


def detect_segments(src: str, ffmpeg: str) -> list[tuple[float, float]]:
    """Возвращает границы непустых фрагментов по silencedetect."""
    p = run([ffmpeg, "-i", src, "-af", "silencedetect=noise=-38dB:d=0.20",
             "-f", "null", "-"])
    log = p.stderr
    dur_m = re.search(r"Duration: (\d+):(\d+):(\d+\.\d+)", log)
    if not dur_m:
        return []
    total = int(dur_m.group(1)) * 3600 + int(dur_m.group(2)) * 60 + float(dur_m.group(3))

    silences: list[tuple[float, float]] = []
    start = None
    for line in log.splitlines():
        m = re.search(r"silence_start: ([\d.]+)", line)
        if m:
            start = float(m.group(1))
        m = re.search(r"silence_end: ([\d.]+)", line)
        if m and start is not None:
            silences.append((start, float(m.group(1))))
            start = None
    if start is not None:
        silences.append((start, total))

    segs: list[tuple[float, float]] = []
    cursor = 0.0
    for s, e in silences:
        if s - cursor > 0.05:
            segs.append((cursor, s))
        cursor = max(cursor, e)
    if total - cursor > 0.05:
        segs.append((cursor, total))
    return segs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    ffmpeg = None if args.dry_run else find_ffmpeg()
    made: list[dict] = []

    for frag, mode, out_rel, loud_key in JOBS:
        hits = [f for f in os.listdir(STAGING) if frag.lower() in f.lower()]
        if not hits:
            print(f"! не найдено в staging: {frag}")
            continue
        src = os.path.join(STAGING, hits[0])
        loud = LOUDNESS[loud_key]

        if mode in ("loop", "one"):
            dst = os.path.join(DEST, out_rel)
            print(f"{mode:5} {os.path.basename(src)[:60]} -> {out_rel}")
            if not args.dry_run:
                if convert(src, dst, loud, ffmpeg):
                    made.append({"file": out_rel, "src": os.path.basename(src)})
            continue

        # split
        print(f"split {os.path.basename(src)[:60]}")
        if args.dry_run:
            continue
        segs = detect_segments(src, ffmpeg)
        segs = [(s, e) for s, e in segs if SPLIT_LIMITS[0] <= (e - s) <= SPLIT_LIMITS[1]]
        segs = segs[:SPLIT_MAX_VARIANTS]
        print(f"   сегментов после фильтра: {len(segs)}")
        for i, (s, e) in enumerate(segs, 1):
            dst = os.path.join(DEST, f"{out_rel}_{i:02d}.wav")
            tmp = os.path.join(tempfile.gettempdir(), f"seg_{i}.wav")
            p = run([ffmpeg, "-y", "-ss", f"{s:.3f}", "-to", f"{e:.3f}", "-i", src,
                     "-c:a", "pcm_s16le", tmp])
            if p.returncode != 0:
                continue
            if convert(tmp, dst, loud, ffmpeg):
                made.append({"file": f"{out_rel}_{i:02d}.wav",
                             "src": f"{os.path.basename(src)} [{s:.2f}-{e:.2f}]",
                             "dur": round(e - s, 2)})
                print(f"   -> {out_rel}_{i:02d}.wav  {e - s:.2f}s")

    if made and not args.dry_run:
        path = "K:/Deadly Night/data/audio_sonniss_import.json"
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(made, fh, ensure_ascii=False, indent=2)
        print(f"\nИмпортировано: {len(made)}. Отчёт: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
