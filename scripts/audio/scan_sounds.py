"""Инвентаризация аудио-библиотек: длительность, каналы, частота, размер.

Использование:
    python scan_sounds.py <root_dir> [--csv out.csv]

Читает WAV через stdlib `wave` (без внешних зависимостей), остальные форматы
фиксирует без метаданных.
"""
from __future__ import annotations

import argparse
import csv
import os
import sys
import wave

AUDIO_EXT = {".wav", ".ogg", ".mp3", ".flac", ".aiff", ".aif"}


def probe_wav(path: str) -> dict:
    try:
        with wave.open(path, "rb") as wf:
            frames = wf.getnframes()
            rate = wf.getframerate() or 1
            return {
                "duration_s": round(frames / float(rate), 3),
                "channels": wf.getnchannels(),
                "sample_rate": rate,
                "bit_depth": wf.getsampwidth() * 8,
            }
    except Exception as exc:  # noqa: BLE001 - битые файлы не должны ломать скан
        return {"duration_s": None, "channels": None, "sample_rate": None,
                "bit_depth": None, "error": str(exc)[:80]}


def scan(root: str) -> list[dict]:
    rows: list[dict] = []
    for dirpath, _dirnames, filenames in os.walk(root):
        for name in filenames:
            ext = os.path.splitext(name)[1].lower()
            if ext not in AUDIO_EXT:
                continue
            full = os.path.join(dirpath, name)
            meta = probe_wav(full) if ext == ".wav" else {
                "duration_s": None, "channels": None,
                "sample_rate": None, "bit_depth": None,
            }
            rows.append({
                "path": os.path.relpath(full, root).replace("\\", "/"),
                "name": name,
                "ext": ext,
                "size_kb": round(os.path.getsize(full) / 1024.0, 1),
                **meta,
            })
    rows.sort(key=lambda r: r["path"])
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--csv", default=None)
    args = ap.parse_args()

    if not os.path.isdir(args.root):
        print(f"Нет такой папки: {args.root}", file=sys.stderr)
        return 2

    rows = scan(args.root)
    total_mb = sum(r["size_kb"] for r in rows) / 1024.0
    print(f"Файлов: {len(rows)}, суммарно {total_mb:.1f} МБ")

    by_ext: dict[str, int] = {}
    for r in rows:
        by_ext[r["ext"]] = by_ext.get(r["ext"], 0) + 1
    print("По форматам:", ", ".join(f"{k}={v}" for k, v in sorted(by_ext.items())))

    if args.csv:
        os.makedirs(os.path.dirname(os.path.abspath(args.csv)), exist_ok=True)
        with open(args.csv, "w", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
            writer.writeheader()
            writer.writerows(rows)
        print(f"CSV: {args.csv}")

    for r in rows[:40]:
        dur = f"{r['duration_s']:.2f}s" if r["duration_s"] else "  ?  "
        print(f"{dur:>8}  {r['size_kb']:>8.1f}K  {r['path']}")
    if len(rows) > 40:
        print(f"... ещё {len(rows) - 40}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
