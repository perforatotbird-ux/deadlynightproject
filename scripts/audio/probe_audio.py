"""Определение длительности/частоты OGG и MP3 без внешних зависимостей.

WAV читается через stdlib `wave`; OGG Vorbis — по granule-позиции последней
страницы; MP3 — по заголовку Xing/Info, при отсутствии — оценка по потоку.

Использование:
    python probe_audio.py <file> [<file> ...]
    python probe_audio.py --dir <dir> --csv out.csv
"""
from __future__ import annotations

import argparse
import csv
import os
import struct
import sys
import wave

# --- OGG Vorbis ------------------------------------------------------------

def _ogg_duration(path: str) -> dict:
    with open(path, "rb") as fh:
        data = fh.read()

    # Идентификационный заголовок: частота дискретизации в 1-й странице.
    rate = None
    idx = data.find(b"\x01vorbis")
    if idx != -1:
        rate = struct.unpack("<I", data[idx + 12:idx + 16])[0]

    # Последняя страница Ogg: ищем с конца сигнатуру "OggS".
    pos = data.rfind(b"OggS")
    granule = None
    if pos != -1 and pos + 14 <= len(data):
        granule = struct.unpack("<q", data[pos + 6:pos + 14])[0]

    dur = None
    if rate and granule and granule > 0:
        dur = granule / float(rate)
    return {"duration_s": round(dur, 2) if dur else None, "sample_rate": rate,
            "channels": None, "bit_depth": None}


# --- MP3 -------------------------------------------------------------------

_BITRATES_V1L3 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0]
_RATES_V1 = [44100, 48000, 32000, 0]


def _mp3_duration(path: str) -> dict:
    with open(path, "rb") as fh:
        data = fh.read()

    # Пропускаем ID3v2.
    off = 0
    if data[:3] == b"ID3" and len(data) > 10:
        size = ((data[6] & 0x7F) << 21) | ((data[7] & 0x7F) << 14) | \
               ((data[8] & 0x7F) << 7) | (data[9] & 0x7F)
        off = 10 + size

    # Ищем первый валидный кадр.
    frame = None
    for i in range(off, min(len(data) - 4, off + 200000)):
        if data[i] == 0xFF and (data[i + 1] & 0xE0) == 0xE0:
            b1, b2, b3 = data[i + 1], data[i + 2], data[i + 3]
            version = (b1 >> 3) & 0x03
            layer = (b1 >> 1) & 0x03
            if version == 3 and layer == 1:
                br_idx = (b2 >> 4) & 0x0F
                sr_idx = (b2 >> 2) & 0x03
                if br_idx not in (0, 15) and sr_idx != 3:
                    frame = (i, br_idx, sr_idx, (b3 >> 6) & 0x03)
                    break

    if not frame:
        return {"duration_s": None, "sample_rate": None, "channels": None, "bit_depth": None}

    start, br_idx, sr_idx, mode = frame
    rate = _RATES_V1[sr_idx]
    bitrate = _BITRATES_V1L3[br_idx] * 1000
    channels = 1 if mode == 3 else 2

    # Xing/Info: количество кадров даёт точную длительность.
    xing = data.find(b"Xing", start, start + 200)
    if xing == -1:
        xing = data.find(b"Info", start, start + 200)
    if xing != -1 and xing + 12 <= len(data):
        flags = struct.unpack(">I", data[xing + 4:xing + 8])[0]
        if flags & 0x01:
            frames = struct.unpack(">I", data[xing + 8:xing + 12])[0]
            dur = frames * 1152.0 / rate
            return {"duration_s": round(dur, 2), "sample_rate": rate,
                    "channels": channels, "bit_depth": None}

    dur = (len(data) - start) * 8.0 / bitrate if bitrate else None
    return {"duration_s": round(dur, 2) if dur else None, "sample_rate": rate,
            "channels": channels, "bit_depth": None}


# --- WAV -------------------------------------------------------------------

def _wav_info(path: str) -> dict:
    try:
        with wave.open(path, "rb") as wf:
            rate = wf.getframerate() or 1
            return {"duration_s": round(wf.getnframes() / float(rate), 2),
                    "sample_rate": rate, "channels": wf.getnchannels(),
                    "bit_depth": wf.getsampwidth() * 8}
    except Exception:  # noqa: BLE001
        return {"duration_s": None, "sample_rate": None, "channels": None, "bit_depth": None}


def probe(path: str) -> dict:
    ext = os.path.splitext(path)[1].lower()
    try:
        if ext == ".wav":
            return _wav_info(path)
        if ext == ".ogg":
            return _ogg_duration(path)
        if ext == ".mp3":
            return _mp3_duration(path)
    except Exception as exc:  # noqa: BLE001
        return {"duration_s": None, "sample_rate": None, "channels": None,
                "bit_depth": None, "error": str(exc)[:60]}
    return {"duration_s": None, "sample_rate": None, "channels": None, "bit_depth": None}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--dir")
    ap.add_argument("--csv")
    args = ap.parse_args()

    targets = list(args.files)
    if args.dir:
        for root, _d, names in os.walk(args.dir):
            targets += [os.path.join(root, n) for n in names
                        if os.path.splitext(n)[1].lower() in {".wav", ".ogg", ".mp3"}]
    if not targets:
        ap.print_help()
        return 2

    rows = []
    for t in sorted(targets):
        info = probe(t)
        rows.append({"path": t, "size_kb": round(os.path.getsize(t) / 1024.0, 1), **info})
        d = f"{info['duration_s']:.2f}s" if info["duration_s"] else "  ?"
        print(f"{d:>9}  {info['sample_rate'] or '?':>6}Hz  {os.path.basename(t)}")

    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
            w.writeheader()
            w.writerows(rows)
        print(f"\nCSV: {args.csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
