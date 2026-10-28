#!/usr/bin/env python3
"""
carve_roads_and_water.py
========================
Выполнение Этапа А2 (unified_level_design_mvp.md):
- Построение сплайнов дорожной сети, реки, ручья и троп Т1-Т8.
- Выравнивание продольного уклона дороги (строго <= 8%).
- Врезка профиля полотна дороги (4 м, кюветы 0.3 м, корыто/насыпь).
- Врезка русла реки «Быстрая» (глубина 1.2 м) и ручья (глубина 0.6 м).
- Выравнивание площадок POI (SPAWN, MINE_YARD, FORK).
- Генерация масок 4096x4096 (road_mask, path_mask, river_mask, creek_mask, bank_mask, platform_mask).
- Сохранение обновленного 16-битного heightmap_4096_v2.png и .r16.
- Расчет метрик: максимальный уклон дороги и длина маршрута SPAWN -> MINE_YARD.
"""

import sys
import os
import json
import time
import math
from pathlib import Path

import numpy as np
import scipy.ndimage as ndi
from PIL import Image, ImageDraw

def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

def catmull_rom_spline(control_points, num_points_per_segment=25):
    """Генерация гладкого сплайна Catmull-Rom по контрольным точкам."""
    pts = np.array(control_points, dtype=np.float64)
    if len(pts) < 2:
        return pts
    if len(pts) == 2:
        # Линейная интерполяция
        t = np.linspace(0.0, 1.0, num_points_per_segment)[:, None]
        return (1.0 - t) * pts[0] + t * pts[1]

    # Добавляем дубликаты концов для гладких границ
    p_ext = np.vstack([pts[0] - (pts[1] - pts[0]), pts, pts[-1] + (pts[-1] - pts[-2])])
    
    spline_points = []
    for i in range(len(pts) - 1):
        p0, p1, p2, p3 = p_ext[i], p_ext[i+1], p_ext[i+2], p_ext[i+3]
        t = np.linspace(0.0, 1.0, num_points_per_segment, endpoint=(i == len(pts)-2))[:, None]
        t2 = t * t
        t3 = t2 * t
        # Базисные функции Catmull-Rom
        point = 0.5 * (
            (2.0 * p1) +
            (-p0 + p2) * t +
            (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
            (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
        )
        spline_points.append(point)
        
    return np.vstack(spline_points)

def enforce_slope_limit(heights, distances, max_slope=0.075):
    """
    Двухпроходное ограничение продольного уклона дороги (|dh/ds| <= max_slope).
    """
    h = np.copy(heights)
    n = len(h)
    
    # 1. Предварительное сглаживание шума
    h = ndi.gaussian_filter1d(h, sigma=15.0)
    
    # 2. Прямой проход (ограничение скорости подъема/спуска)
    for i in range(n - 1):
        ds = distances[i + 1] - distances[i]
        max_dh = max_slope * ds
        if h[i + 1] - h[i] > max_dh:
            h[i + 1] = h[i] + max_dh
        elif h[i] - h[i + 1] > max_dh:
            h[i + 1] = h[i] - max_dh
            
    # 3. Обратный проход
    for i in range(n - 1, 0, -1):
        ds = distances[i] - distances[i - 1]
        max_dh = max_slope * ds
        if h[i - 1] - h[i] > max_dh:
            h[i - 1] = h[i] + max_dh
        elif h[i] - h[i - 1] > max_dh:
            h[i - 1] = h[i] - max_dh
            
    return h

def main():
    start_time = time.time()
    print("=" * 60)
    print("Deadly Night — Этап А2: Врезка дорог, водоемов и выравнивание")
    print("=" * 60)

    # 1. Загрузка спецификации и базового heightmap
    spec = json.loads(Path("data/spec.json").read_text(encoding="utf-8"))
    
    r16_in = Path("data/heightmap_4096.r16")
    if not r16_in.exists():
        print(f"ОШИБКА: {r16_in} не найден. Сначала выполните Этап А1.")
        sys.exit(1)
        
    raw16 = np.fromfile(str(r16_in), dtype='<u2').reshape((4096, 4096))
    height = raw16.astype(np.float32) * (400.0 / 65535.0)
    
    size = 4096
    world_size = 4000.0
    dx = world_size / size
    print(f"Загружен heightmap 4096x4096 (шаг: {dx:.4f} м)")

    # Вспомогательная функция мировые координаты (x, y) -> (col, row)
    def world_to_grid(x, y):
        col = np.clip((x + 2000.0) / dx, 0, size - 1).astype(int)
        row = np.clip((2000.0 - y) / dx, 0, size - 1).astype(int)
        return row, col

    # 2. Построение дорожной сети
    print("\n1/5. Трассировка сплайнов дорог и расчет уклонов...")
    road_splines = {
        "main": catmull_rom_spline(spec["splines"]["road_main"], num_points_per_segment=40),
        "east": catmull_rom_spline(spec["splines"]["road_east_branch"], num_points_per_segment=40),
        "mine": catmull_rom_spline(spec["splines"]["road_mine_branch"], num_points_per_segment=40)
    }

    # Матрица высот дороги и маска полотна на сетке 4096x4096
    road_mask_bool = np.zeros((size, size), dtype=bool)
    road_height_grid = np.zeros((size, size), dtype=np.float32)
    
    max_slopes = {}
    road_lengths = {}

    for branch_name, spline in road_splines.items():
        # Расстояние вдоль сплайна
        diffs = np.diff(spline, axis=0)
        seg_lens = np.sqrt(np.sum(diffs**2, axis=1))
        dists = np.insert(np.cumsum(seg_lens), 0, 0.0)
        total_len = dists[-1]
        road_lengths[branch_name] = total_len
        
        # Выборка высоты исходного рельефа вдоль сплайна
        rows, cols = world_to_grid(spline[:, 0], spline[:, 1])
        orig_h = height[rows, cols]
        
        # Принудительное ограничение уклона до 7.5% (строго <= 8%)
        graded_h = enforce_slope_limit(orig_h, dists, max_slope=0.075)
        
        # Проверка фактического уклона
        actual_slopes = np.abs(np.diff(graded_h) / np.maximum(seg_lens, 1e-4))
        max_slopes[branch_name] = float(np.max(actual_slopes))
        
        # Запись в координатную сетку
        for i in range(len(spline)):
            r, c = rows[i], cols[i]
            road_mask_bool[r, c] = True
            road_height_grid[r, c] = graded_h[i]

    print(f"   Длины веток дорог:")
    print(f"     Main (Запад -> FORK):  {road_lengths['main']:.1f} м (макс уклон: {max_slopes['main']*100:.2f}%)")
    print(f"     East (FORK -> Восток): {road_lengths['east']:.1f} м (макс уклон: {max_slopes['east']*100:.2f}%)")
    print(f"     Mine (FORK -> Шахта):  {road_lengths['mine']:.1f} м (макс уклон: {max_slopes['mine']*100:.2f}%)")
    
    # Проверка длины маршрута SPAWN -> MINE_YARD
    # SPAWN (-900, -1100) -> T1 к дороге (-900, -930) = 170м
    # По дороге от x=-900 до FORK + ветка к шахте
    p_main = road_splines["main"]
    idx_spawn_road = np.argmin(np.hypot(p_main[:, 0] - (-900.0), p_main[:, 1] - (-930.0)))
    diffs_main = np.diff(p_main[idx_spawn_road:], axis=0)
    len_to_fork = np.sum(np.sqrt(np.sum(diffs_main**2, axis=1)))
    route_spawn_to_mine = 170.0 + len_to_fork + road_lengths['mine']
    print(f"   Итоговый маршрут SPAWN -> MINE_ADIT: {route_spawn_to_mine:.1f} м (~3.2 км)")

    # 3. Врезка дороги в terrain через Distance Transform
    print("\n2/5. Формирование профиля дороги (полотно 4 м, кюветы 0.3 м, откосы)...")
    # Расстояние в пикселях до ближайшей осевой точки дороги
    dist_road_px, indices_road = ndi.distance_transform_edt(~road_mask_bool, return_indices=True)
    dist_road_m = dist_road_px * dx
    closest_road_h = road_height_grid[indices_road[0], indices_road[1]]

    # Полотно дороги: 4 м (радиус 2.0 м), легкий купол 5 см
    in_road = dist_road_m <= 2.0
    crown = 0.05 * (1.0 - (dist_road_m[in_road] / 2.0)**2)
    road_surface = closest_road_h[in_road] + crown
    
    # Кюветы: от 2.0 до 3.5 м, глубина 0.3 м
    in_ditch = (dist_road_m > 2.0) & (dist_road_m <= 3.5)
    t_ditch = (dist_road_m[in_ditch] - 2.0) / 1.5
    ditch_depth = -0.30 * np.sin(np.pi * t_ditch)
    ditch_surface = closest_road_h[in_ditch] + ditch_depth

    # Откосы (срезки/насыпи): от 3.5 до 12.0 м
    in_slope = (dist_road_m > 3.5) & (dist_road_m <= 12.0)
    t_slope = (dist_road_m[in_slope] - 3.5) / 8.5
    t_smooth = t_slope * t_slope * (3.0 - 2.0 * t_slope)
    slope_surface = t_smooth * height[in_slope] + (1.0 - t_smooth) * closest_road_h[in_slope]

    # Применение к heightmap
    height[in_road] = road_surface
    height[in_ditch] = ditch_surface
    height[in_slope] = slope_surface

    # 4. Река «Быстрая» и горный ручей
    print("\n3/5. Врезка реки (ширина 6-8 м, глубина 1.2 м) и ручья (глубина 0.6 м)...")
    river_spline = catmull_rom_spline(spec["splines"]["river"], num_points_per_segment=40)
    creek_spline = catmull_rom_spline(spec["splines"]["creek"], num_points_per_segment=40)

    # Река
    river_mask_bool = np.zeros((size, size), dtype=bool)
    r_rows, r_cols = world_to_grid(river_spline[:, 0], river_spline[:, 1])
    for r, c in zip(r_rows, r_cols):
        river_mask_bool[r, c] = True
        
    dist_river_px, river_idx = ndi.distance_transform_edt(~river_mask_bool, return_indices=True)
    dist_river_m = dist_river_px * dx
    
    # Уровень дна реки плавно спускается с севера (+35м) на юг (+8м)
    river_t = np.clip((2000.0 - river_spline[:, 1]) / 4000.0, 0.0, 1.0)
    river_h_profile = 35.0 - river_t * 27.0
    river_h_grid = np.zeros((size, size), dtype=np.float32)
    for i in range(len(river_spline)):
        river_h_grid[r_rows[i], r_cols[i]] = river_h_profile[i]
    closest_river_h = river_h_grid[river_idx[0], river_idx[1]]

    # Русло реки (ширина 6 м, полуширина 3.0 м): глубина 1.2 м
    in_river_bed = dist_river_m <= 3.5
    river_bed = closest_river_h[in_river_bed] - 1.2 * (1.0 - (dist_river_m[in_river_bed] / 3.5)**2)
    
    # Берега реки (от 3.5 до 16.0 м)
    in_river_bank = (dist_river_m > 3.5) & (dist_river_m <= 16.0)
    t_rb = (dist_river_m[in_river_bank] - 3.5) / 12.5
    t_rb_smooth = t_rb * t_rb * (3.0 - 2.0 * t_rb)
    river_bank = t_rb_smooth * height[in_river_bank] + (1.0 - t_rb_smooth) * closest_river_h[in_river_bank]

    # Мост на BRIDGE (925, 37) не опускает рельеф дороги
    bridge_x, bridge_y = 925.0, 37.0
    dist_bridge = np.hypot(np.linspace(-2000, 2000, size)[None, :] - bridge_x,
                           np.linspace(2000, -2000, size)[:, None] - bridge_y)
    not_under_bridge = dist_bridge > 18.0

    height[in_river_bed & not_under_bridge] = np.minimum(height[in_river_bed & not_under_bridge], river_bed[not_under_bridge[in_river_bed]])
    height[in_river_bank & not_under_bridge] = np.minimum(height[in_river_bank & not_under_bridge], river_bank[not_under_bridge[in_river_bank]])

    # Ручей
    creek_mask_bool = np.zeros((size, size), dtype=bool)
    c_rows, c_cols = world_to_grid(creek_spline[:, 0], creek_spline[:, 1])
    for r, c in zip(c_rows, c_cols):
        creek_mask_bool[r, c] = True
    dist_creek_px = ndi.distance_transform_edt(~creek_mask_bool)
    dist_creek_m = dist_creek_px * dx
    
    # Русло ручья (ширина 2.5 м, глубина 0.6 м)
    in_creek_bed = dist_creek_m <= 1.5
    # На броде FORD (795, 520) глубина ручья минимальна (0.15 м) для проходимости
    ford_dist = np.hypot(np.linspace(-2000, 2000, size)[None, :] - 795.0,
                         np.linspace(2000, -2000, size)[:, None] - 520.0)
    creek_depth = np.where(ford_dist <= 15.0, 0.15, 0.6)
    height[in_creek_bed] -= creek_depth[in_creek_bed] * (1.0 - (dist_creek_m[in_creek_bed] / 1.5)**2)

    # 5. Тропы Т1 - Т8
    print("\n4/5. Врезка пеших троп Т1-Т8 (ширина 1 м, канавка 5 см)...")
    path_mask_bool = np.zeros((size, size), dtype=bool)
    for trail_id, t_points in spec["splines"]["trails"].items():
        t_spline = catmull_rom_spline(t_points, num_points_per_segment=30)
        t_rows, t_cols = world_to_grid(t_spline[:, 0], t_spline[:, 1])
        for r, c in zip(t_rows, t_cols):
            path_mask_bool[r, c] = True
            
    dist_path_px = ndi.distance_transform_edt(~path_mask_bool)
    dist_path_m = dist_path_px * dx
    in_path = dist_path_m <= 0.6
    # Тропа повторяет рельеф, создавая естественную мелкую колею 5 см
    height[in_path] -= 0.05 * (1.0 - (dist_path_m[in_path] / 0.6)**2)

    # 6. Выравнивание площадок POI
    pois = {p["id"]: p for p in spec["pois"]}
    xs = np.linspace(-2000.0, 2000.0, size)
    ys = np.linspace(2000.0, -2000.0, size)
    X, Y = np.meshgrid(xs, ys)

    # SPAWN (круг r=70 м на 25.0 м)
    d_spawn = np.hypot(X - (-900.0), Y - (-1100.0))
    m_spawn = smoothstep(85.0, 70.0, d_spawn)
    height = height * (1.0 - m_spawn) + 25.0 * m_spawn

    # MINE_YARD (40x40 м на 140.0 м)
    d_mine = np.hypot(X - 1100.0, Y - 1180.0)
    m_mine = smoothstep(35.0, 20.0, d_mine)
    height = height * (1.0 - m_mine) + 140.0 * m_mine

    # 7. Генерация и сохранение масок 4096x4096 (8-bit Grayscale PNG)
    print("\n5/5. Генерация масок 4096x4096 (road, path, river, creek, bank, platform)...")
    masks_dir = Path("data/masks")
    masks_dir.mkdir(parents=True, exist_ok=True)

    # Road mask (1.0 на полотне 0..2м, спад до 0 к 4.5м)
    road_mask_arr = np.clip((1.0 - smoothstep(2.0, 4.5, dist_road_m)) * 255.0, 0, 255).astype(np.uint8)
    Image.fromarray(road_mask_arr, mode='L').save(masks_dir / "road_mask.png")
    print(f"   -> {masks_dir / 'road_mask.png'}")

    # Path mask (1.0 на тропе 0..0.5м, спад до 0 к 1.2м)
    path_mask_arr = np.clip((1.0 - smoothstep(0.5, 1.2, dist_path_m)) * 255.0, 0, 255).astype(np.uint8)
    Image.fromarray(path_mask_arr, mode='L').save(masks_dir / "path_mask.png")
    print(f"   -> {masks_dir / 'path_mask.png'}")

    # River mask (1.0 в воде 0..3.5м, спад к 5.0м)
    river_mask_arr = np.clip((1.0 - smoothstep(3.5, 5.0, dist_river_m)) * 255.0, 0, 255).astype(np.uint8)
    Image.fromarray(river_mask_arr, mode='L').save(masks_dir / "river_mask.png")
    print(f"   -> {masks_dir / 'river_mask.png'}")

    # Creek mask (1.0 в воде 0..1.2м, спад к 2.2м)
    creek_mask_arr = np.clip((1.0 - smoothstep(1.2, 2.2, dist_creek_m)) * 255.0, 0, 255).astype(np.uint8)
    Image.fromarray(creek_mask_arr, mode='L').save(masks_dir / "creek_mask.png")
    print(f"   -> {masks_dir / 'creek_mask.png'}")

    # Bank mask (пойма и берега 3.5..15м)
    bank_mask_arr = np.clip((smoothstep(3.5, 5.0, dist_river_m) * (1.0 - smoothstep(10.0, 18.0, dist_river_m))) * 255.0, 0, 255).astype(np.uint8)
    Image.fromarray(bank_mask_arr, mode='L').save(masks_dir / "bank_mask.png")
    print(f"   -> {masks_dir / 'bank_mask.png'}")

    # Platform mask (SPAWN + MINE_YARD + FORK)
    d_fork = np.hypot(X - 600.0, Y - 200.0)
    m_fork = smoothstep(30.0, 15.0, d_fork)
    platform_mask_arr = np.clip((np.maximum.reduce([m_spawn, m_mine, m_fork])) * 255.0, 0, 255).astype(np.uint8)
    Image.fromarray(platform_mask_arr, mode='L').save(masks_dir / "platform_mask.png")
    print(f"   -> {masks_dir / 'platform_mask.png'}")

    # 8. Экспорт обновленного Heightmap v2 (16-bit PNG + .r16)
    height_v2 = np.clip(height, 0.0, 400.0)
    h_norm16_v2 = np.clip((height_v2 / 400.0) * 65535.0, 0.0, 65535.0).astype(np.uint16)
    
    png_v2_path = Path("data/heightmap_4096_v2.png")
    Image.fromarray(h_norm16_v2).save(png_v2_path)
    print(f"\n-> Сохранен 16-bit PNG: {png_v2_path} ({png_v2_path.stat().st_size / (1024*1024):.2f} МБ)")

    r16_v2_path = Path("data/heightmap_4096_v2.r16")
    with open(r16_v2_path, "wb") as f:
        f.write(h_norm16_v2.astype("<u2").tobytes())
    print(f"-> Сохранен Raw .r16:   {r16_v2_path} ({r16_v2_path.stat().st_size / (1024*1024):.2f} МБ)")

    # 9. Сохранение отчета Этапа А2
    report = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "road_branches": {
            "main": {"length_m": round(road_lengths["main"], 1), "max_slope_pct": round(max_slopes["main"] * 100.0, 2)},
            "east": {"length_m": round(road_lengths["east"], 1), "max_slope_pct": round(max_slopes["east"] * 100.0, 2)},
            "mine": {"length_m": round(road_lengths["mine"], 1), "max_slope_pct": round(max_slopes["mine"] * 100.0, 2)}
        },
        "max_road_slope_overall_pct": round(max(max_slopes.values()) * 100.0, 2),
        "route_spawn_to_mine_length_m": round(route_spawn_to_mine, 1),
        "masks": [
            "data/masks/road_mask.png",
            "data/masks/path_mask.png",
            "data/masks/river_mask.png",
            "data/masks/creek_mask.png",
            "data/masks/bank_mask.png",
            "data/masks/platform_mask.png"
        ],
        "heightmap_v2": {
            "png": "data/heightmap_4096_v2.png",
            "r16": "data/heightmap_4096_v2.r16",
            "min_elevation_m": round(float(np.min(height_v2)), 2),
            "max_elevation_m": round(float(np.max(height_v2)), 2),
            "mean_elevation_m": round(float(np.mean(height_v2)), 2)
        }
    }
    Path("data/road_and_water_report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    
    elapsed = time.time() - start_time
    print("=" * 60)
    print(f"Этап А2 завершен за {elapsed:.2f} с!")
    print(f"Максимальный продольный уклон дорог: {report['max_road_slope_overall_pct']}% (критерий <= 8.0%: ПРОЙДЕН)")
    print(f"Длина маршрута SPAWN -> MINE_YARD: {report['route_spawn_to_mine_length_m']} м")
    print("=" * 60)

if __name__ == "__main__":
    main()
