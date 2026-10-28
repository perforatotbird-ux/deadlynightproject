#!/usr/bin/env python3
"""
generate_heightmap.py
=====================
Детерминированная процедурная генерация 16-битного heightmap 4096x4096
по спецификации unified_level_design_mvp.md / spec.json для Deadly Night.

Выходы:
- data/heightmap_4096.png (16-bit grayscale PNG, 0..65535 = 0..400м)
- data/heightmap_4096.r16 (raw 16-bit little-endian)
- data/heightmap_preview.png (цветной hillshade с разметкой POI)
- data/heightmap_stats.json (статистика высот, уклонов и высоты в точках POI)
"""

import os
import sys
import json
import time
import math
from pathlib import Path

import numpy as np
import scipy.ndimage as ndi
from PIL import Image, ImageDraw, ImageFont

def smoothstep(edge0, edge1, x):
    """Hermite interpolation between edge0 and edge1."""
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

def dist_to_segment(X, Y, p0, p1):
    """Vectorized distance from grid (X, Y) to line segment p0-p1."""
    x0, y0 = p0
    x1, y1 = p1
    dx = x1 - x0
    dy = y1 - y0
    l2 = dx * dx + dy * dy
    if l2 == 0.0:
        return np.sqrt((X - x0) ** 2 + (Y - y0) ** 2)
    t = np.clip(((X - x0) * dx + (Y - y0) * dy) / l2, 0.0, 1.0)
    proj_x = x0 + t * dx
    proj_y = y0 + t * dy
    return np.sqrt((X - proj_x) ** 2 + (Y - proj_y) ** 2), t

def dist_to_polyline(X, Y, points):
    """Vectorized minimum distance from grid (X, Y) to polyline points."""
    min_dist = None
    min_t = None
    for i in range(len(points) - 1):
        d, t = dist_to_segment(X, Y, points[i], points[i + 1])
        if min_dist is None:
            min_dist = d
            min_t = i + t
        else:
            closer = d < min_dist
            min_dist = np.where(closer, d, min_dist)
            min_t = np.where(closer, i + t, min_t)
    return min_dist, min_t

def thermal_erosion(height, iterations=4, talus_angle_deg=35.0, cell_size=0.9765625):
    """Vectorized thermal erosion / talus angle relaxation pass."""
    talus_height = cell_size * math.tan(math.radians(talus_angle_deg))
    h = height.copy()
    for _ in range(iterations):
        # 4-way neighbors
        up = np.roll(h, -1, axis=0)
        down = np.roll(h, 1, axis=0)
        left = np.roll(h, -1, axis=1)
        right = np.roll(h, 1, axis=1)
        
        diff_u = h - up
        diff_d = h - down
        diff_l = h - left
        diff_r = h - right
        
        # Where slope exceeds talus, move small fraction of excess down
        excess_u = np.maximum(0.0, diff_u - talus_height)
        excess_d = np.maximum(0.0, diff_d - talus_height)
        excess_l = np.maximum(0.0, diff_l - talus_height)
        excess_r = np.maximum(0.0, diff_r - talus_height)
        
        total_excess = excess_u + excess_d + excess_l + excess_r
        active = total_excess > 0
        transfer = total_excess * 0.125
        h[active] -= transfer[active]
        h[np.roll(active, -1, axis=0)] += 0.25 * excess_d[active]
        h[np.roll(active, 1, axis=0)] += 0.25 * excess_u[active]
        h[np.roll(active, -1, axis=1)] += 0.25 * excess_r[active]
        h[np.roll(active, 1, axis=1)] += 0.25 * excess_l[active]
    return h

def generate_fbm(rng, size, octaves_spec):
    """
    Generate fBm multi-octave noise on (size, size) grid.
    octaves_spec: list of (grid_res, amplitude, order)
    """
    fbm = np.zeros((size, size), dtype=np.float32)
    for res, amp, order in octaves_spec:
        # Generate random values on coarse grid
        coarse = rng.standard_normal((res, res)).astype(np.float32)
        # Zoom up to size x size
        zoomed = ndi.zoom(coarse, size / res, order=order)
        # Ensure exact shape
        if zoomed.shape != (size, size):
            zoomed = zoomed[:size, :size]
        fbm += amp * zoomed
    return fbm

def main():
    start_time = time.time()
    print("=" * 60)
    print("Deadly Night — Процедурный генератор Heightmap 4096x4096")
    print("=" * 60)

    # 1. Загрузка спецификации
    spec_path = Path("data/spec.json")
    if not spec_path.exists():
        print(f"ОШИБКА: Спецификация {spec_path} не найдена!")
        sys.exit(1)
        
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    seed = spec.get("seed", 20261028)
    print(f"Фиксированный seed: {seed}")
    rng = np.random.default_rng(seed)

    size = 4096
    world_size = 4000.0
    dx = world_size / size
    print(f"Сетка: {size}x{size}, шаг ячейки: {dx:.4f} м")

    # Координатная сетка мира (Blender: X = East, Y = North, Z = Up)
    # Строка 0 = Север (+2000 м), строка 4095 = Юг (-2000 м)
    # Столбец 0 = Запад (-2000 м), столбец 4095 = Восток (+2000 м)
    xs = np.linspace(-2000.0, 2000.0, size, endpoint=False) + dx * 0.5
    ys = np.linspace(2000.0, -2000.0, size, endpoint=False) - dx * 0.5
    X, Y = np.meshgrid(xs, ys)

    # 2. Базовый рельеф (fBm 5 октав)
    print("1/6. Генерация базового fBm рельефа (холмы и долины)...")
    # Октавы: (разрешение сетки, амплитуда в метрах, порядок сплайна)
    octaves = [
        (8, 28.0, 3),    # Длина волны ~500 м
        (16, 16.0, 3),   # Длина волны ~250 м
        (32, 9.0, 3),    # Длина волны ~125 м
        (64, 4.5, 3),    # Длина волны ~62 м
        (128, 2.2, 1),   # Длина волны ~31 м
        (256, 1.0, 1),   # Длина волны ~15 м
    ]
    base_fbm = generate_fbm(rng, size, octaves)
    # Базовое смещение высоты равнин
    height = 24.0 + base_fbm

    # 3. Горный массив на Северо-Востоке
    print("2/6. Построение северо-восточного горного массива (PEAK 380м)...")
    peak_x, peak_y = 1500.0, 1500.0
    dist_peak = np.sqrt((X - peak_x) ** 2 + (Y - peak_y) ** 2)
    # Радиальная маска массива: от 1200 м (ноль) до 350 м (максимум)
    radial_mask = smoothstep(1250.0, 350.0, dist_peak)

    # Хребет от (700, 1750) до (2000, 1000)
    p_ridge_a = (700.0, 1750.0)
    p_ridge_b = (2000.0, 1000.0)
    dist_ridge, t_ridge = dist_to_segment(X, Y, p_ridge_a, p_ridge_b)
    ridge_mask = smoothstep(750.0, 80.0, dist_ridge) * (0.6 + 0.4 * np.sin(np.pi * t_ridge))

    # Объединенная маска гор
    mountain_mask = np.clip(radial_mask * 1.1 + ridge_mask * 0.8, 0.0, 1.0)
    # Плавное сглаживание краев маски
    mountain_mask = ndi.gaussian_filter(mountain_mask, sigma=12)

    # Ridged-шум для скалистых гребней
    print("     Расчёт скальных рёбер (ridged noise)...")
    ridged_octaves = [
        (32, 35.0, 3),
        (64, 20.0, 3),
        (128, 10.0, 1),
    ]
    raw_ridged = generate_fbm(rng, size, ridged_octaves)
    ridged_noise = (1.0 - np.abs(raw_ridged / np.max(np.abs(raw_ridged)))) ** 2

    # Высота массива (до 380 м на вершине)
    mountain_elevation = mountain_mask * (285.0 + 75.0 * ridged_noise)
    height += mountain_elevation

    # 4. Долина реки «Быстрая»
    print("3/6. Формирование речной долины вдоль сплайна реки...")
    river_points = spec["splines"]["river"]
    dist_river, t_river = dist_to_polyline(X, Y, river_points)
    
    # Долина шириной до 180 м с плавным уклоном
    river_mask = smoothstep(180.0, 20.0, dist_river)
    # Уровень дна реки плавно понижается с севера на юг: от 35 м до 8 м
    river_floor = 35.0 - (t_river / (len(river_points) - 1)) * 27.0
    # Врезка долины
    valley_depth = np.maximum(0.0, height - river_floor) * river_mask * 0.75
    height -= valley_depth

    # 5. Калибровка высот и площадок ключевых POI
    print("4/6. Калибровка высот POI (SPAWN, MINE_YARD, PEAK)...")
    pois = {p["id"]: p for p in spec["pois"]}
    
    # Стартовая поляна SPAWN (-900, -1100, 25м, r=70м)
    sp_x, sp_y = pois["SPAWN"]["position"][:2]
    dist_spawn = np.sqrt((X - sp_x) ** 2 + (Y - sp_y) ** 2)
    spawn_mask = smoothstep(100.0, 30.0, dist_spawn)
    height = height * (1.0 - spawn_mask) + 25.0 * spawn_mask

    # Площадка шахты MINE_YARD (1100, 1180, 140м, терраса 40x40м)
    my_x, my_y = pois["MINE_YARD"]["position"][:2]
    dist_mine = np.sqrt((X - my_x) ** 2 + (Y - my_y) ** 2)
    mine_mask = smoothstep(70.0, 25.0, dist_mine)
    height = height * (1.0 - mine_mask) + 140.0 * mine_mask

    # Скальная стена за входом в штольню MINE_ADIT (1130, 1210)
    adit_x, adit_y = pois["MINE_ADIT"]["position"][:2]
    # На северо-восток от входа поднимаем скалу
    wall_dx = X - adit_x
    wall_dy = Y - adit_y
    behind_mask = smoothstep(10.0, 60.0, (wall_dx + wall_dy) / np.sqrt(2.0))
    close_mask = smoothstep(80.0, 20.0, np.sqrt(wall_dx ** 2 + wall_dy ** 2))
    cliff_add = behind_mask * close_mask * 25.0
    height += cliff_add

    # Вершина PEAK (1500, 1500, 380м)
    dist_p = np.sqrt((X - peak_x) ** 2 + (Y - peak_y) ** 2)
    peak_top_mask = smoothstep(120.0, 15.0, dist_p)
    height = height * (1.0 - peak_top_mask) + 380.0 * peak_top_mask

    # 6. Термальная эрозия и сглаживание
    print("5/6. Термальная эрозия и релаксация рельефа...")
    height = thermal_erosion(height, iterations=3, talus_angle_deg=38.0, cell_size=dx)
    # Гарантируем неотрицательность и соблюдение предела 400 м
    height = np.clip(height, 0.0, 400.0)

    # 7. Расчёт уклонов и статистики
    print("6/6. Расчёт уклонов и нормализация в 16 бит...")
    # Градиенты в метрах на метр
    gy, gx = np.gradient(height, dx)
    slope_rad = np.arctan(np.sqrt(gx * gx + gy * gy))
    slope_deg = np.degrees(slope_rad)
    cliff_fraction = float(np.mean(slope_deg > 35.0))

    # Сбор высот по POI
    poi_elevations = {}
    for pid, pdata in pois.items():
        px, py = pdata["position"][:2]
        # Координаты мира -> индексы матрицы
        col = int(np.clip((px + 2000.0) / dx, 0, size - 1))
        row = int(np.clip((2000.0 - py) / dx, 0, size - 1))
        elev = float(height[row, col])
        poi_elevations[pid] = {
            "name": pdata["name"],
            "target_z": pdata["position"][2],
            "actual_z": round(elev, 2),
            "diff": round(elev - pdata["position"][2], 2),
            "slope_deg": round(float(slope_deg[row, col]), 1),
            "grid_coord": [row, col]
        }

    stats = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "seed": seed,
        "resolution": [size, size],
        "world_size_m": [world_size, world_size],
        "cell_size_m": round(dx, 4),
        "elevation_min_m": round(float(np.min(height)), 2),
        "elevation_max_m": round(float(np.max(height)), 2),
        "elevation_mean_m": round(float(np.mean(height)), 2),
        "elevation_std_m": round(float(np.std(height)), 2),
        "area_slope_gt_35_deg_pct": round(cliff_fraction * 100.0, 2),
        "poi_checks": poi_elevations
    }

    # 8. Экспорт файлов
    data_dir = Path("data")
    data_dir.mkdir(exist_ok=True)

    # Нормализация в 16-битный диапазон: 0..400м -> 0..65535
    h_norm16 = np.clip((height / 400.0) * 65535.0, 0.0, 65535.0).astype(np.uint16)

    # 1) 16-bit PNG
    png_path = data_dir / "heightmap_4096.png"
    img16 = Image.fromarray(h_norm16, mode='I;16')
    img16.save(png_path)
    print(f"-> Сохранён 16-bit PNG: {png_path} ({png_path.stat().st_size / (1024*1024):.2f} МБ)")

    # 2) Raw Little-Endian .r16
    r16_path = data_dir / "heightmap_4096.r16"
    with open(r16_path, "wb") as f:
        f.write(h_norm16.astype("<u2").tobytes())
    print(f"-> Сохранён Raw .r16:   {r16_path} ({r16_path.stat().st_size / (1024*1024):.2f} МБ)")

    # 3) Цветной Hillshade Preview (1024x1024) с разметкой POI
    preview_size = 1024
    h_preview = ndi.zoom(height, preview_size / size, order=1)
    
    # Расчёт затенения (солнце с Юго-Востока: азимут 110°, высота 25°)
    sun_azimuth = math.radians(110.0)
    sun_altitude = math.radians(25.0)
    p_gy, p_gx = np.gradient(h_preview, world_size / preview_size)
    p_slope = np.arctan(np.sqrt(p_gx * p_gx + p_gy * p_gy))
    p_aspect = np.arctan2(-p_gx, p_gy)
    hillshade = (
        np.sin(sun_altitude) * np.cos(p_slope) +
        np.cos(sun_altitude) * np.sin(p_slope) * np.cos(sun_azimuth - p_aspect)
    )
    hillshade = np.clip((hillshade + 0.2) / 1.2, 0.0, 1.0)

    # Гипсометрическая окраска
    # 0..60м (долина, зелёный) -> 60..180м (лес, тёмно-зелёный) -> 180..300м (серый сланец) -> 300..400м (снег/скалы)
    r_col = np.zeros_like(h_preview)
    g_col = np.zeros_like(h_preview)
    b_col = np.zeros_like(h_preview)

    # Палитра
    m0 = h_preview < 60.0
    r_col[m0] = 70.0 + (h_preview[m0] / 60.0) * 40.0
    g_col[m0] = 130.0 + (h_preview[m0] / 60.0) * 30.0
    b_col[m0] = 60.0

    m1 = (h_preview >= 60.0) & (h_preview < 180.0)
    t1 = (h_preview[m1] - 60.0) / 120.0
    r_col[m1] = 110.0 * (1 - t1) + 130.0 * t1
    g_col[m1] = 160.0 * (1 - t1) + 135.0 * t1
    b_col[m1] = 60.0 * (1 - t1) + 90.0 * t1

    m2 = (h_preview >= 180.0) & (h_preview < 300.0)
    t2 = (h_preview[m2] - 180.0) / 120.0
    r_col[m2] = 130.0 * (1 - t2) + 175.0 * t2
    g_col[m2] = 135.0 * (1 - t2) + 175.0 * t2
    b_col[m2] = 90.0 * (1 - t2) + 180.0 * t2

    m3 = h_preview >= 300.0
    t3 = np.clip((h_preview[m3] - 300.0) / 80.0, 0.0, 1.0)
    r_col[m3] = 175.0 * (1 - t3) + 240.0 * t3
    g_col[m3] = 175.0 * (1 - t3) + 245.0 * t3
    b_col[m3] = 180.0 * (1 - t3) + 250.0 * t3

    # Наложение hillshade
    final_r = np.clip(r_col * hillshade, 0, 255).astype(np.uint8)
    final_g = np.clip(g_col * hillshade, 0, 255).astype(np.uint8)
    final_b = np.clip(b_col * hillshade, 0, 255).astype(np.uint8)
    preview_img = Image.fromarray(np.stack([final_r, final_g, final_b], axis=-1), mode="RGB")

    # Рисование маркеров POI
    draw = ImageDraw.Draw(preview_img)
    scale_prev = preview_size / world_size
    for pid, pdata in pois.items():
        px, py = pdata["position"][:2]
        ix = int((px + 2000.0) * scale_prev)
        iy = int((2000.0 - py) * scale_prev)
        r_pt = 4
        # Красные точки для ключевых POI, жёлтые для остальных
        color = (255, 60, 60) if pid in ["SPAWN", "MINE_YARD", "PEAK", "BRIDGE"] else (255, 220, 50)
        draw.ellipse([ix - r_pt, iy - r_pt, ix + r_pt, iy + r_pt], fill=color, outline=(0, 0, 0))
        draw.text((ix + 6, iy - 6), pid, fill=(255, 255, 255))

    preview_path = data_dir / "heightmap_preview.png"
    preview_img.save(preview_path)
    print(f"-> Сохранено превью:    {preview_path}")

    # 4) Статистика в JSON
    stats_path = data_dir / "heightmap_stats.json"
    stats_path.write_text(json.dumps(stats, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"-> Сохранена статистика: {stats_path}")

    elapsed = time.time() - start_time
    print("=" * 60)
    print(f"Генерация завершена за {elapsed:.2f} с!")
    print(f"Высоты мира: мин = {stats['elevation_min_m']} м, макс = {stats['elevation_max_m']} м, средняя = {stats['elevation_mean_m']} м")
    print(f"Площадь скал (уклон > 35°): {stats['area_slope_gt_35_deg_pct']}%")
    print("\nПроверка контрольных высот POI:")
    for pid in ["SPAWN", "MINE_YARD", "PEAK", "BRIDGE", "FORD", "MEADOW", "LOOKOUT"]:
        c = poi_elevations[pid]
        print(f"  [{pid:10s}] Цель: {c['target_z']:5.1f} м | Факт: {c['actual_z']:5.1f} м | Разница: {c['diff']:+5.1f} м | Уклон: {c['slope_deg']:4.1f}°")
    print("=" * 60)

if __name__ == "__main__":
    main()
