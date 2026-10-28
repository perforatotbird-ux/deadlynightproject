#!/usr/bin/env python3
"""
generate_materials_and_splatmap.py
==================================
Выполнение Этапа А3 (unified_level_design_mvp.md):
- Генерация двухслойного Splatmap 4096x4096 (splat_a и splat_b).
  splat_a: R=трава, G=лесная подстилка, B=скалы (>35°), A=тропы
  splat_b: R=гравий дороги, G=грязь/галька берегов, B=снег (>280м), A=резерв
- Шум на границах материалов (fBm / blue noise) для исключения искусственных стыков.
- Запекание композитного Terrain Albedo (terrain_albedo_4096.jpg) по канонической палитре.
- Запекание тангентной карты нормалей (terrain_normal_4096.png).
- Статистика покрытия поверхности по типам материалов в JSON.
"""

import sys
import os
import json
import time
import math
from pathlib import Path

import numpy as np
import scipy.ndimage as ndi
from PIL import Image

def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

def load_mask(path, shape=(4096, 4096)):
    if not path.exists():
        return np.zeros(shape, dtype=np.float32)
    img = Image.open(path).convert('L')
    return np.array(img, dtype=np.float32) / 255.0

def main():
    start_time = time.time()
    print("=" * 60)
    print("Deadly Night — Этап А3: Генерация Splatmap и запекание текстур")
    print("=" * 60)

    # 1. Загрузка данных
    spec = json.loads(Path("data/spec.json").read_text(encoding="utf-8"))
    size = 4096
    world_size = 4000.0
    dx = world_size / size

    r16_path = Path("data/heightmap_4096_v2.r16")
    if not r16_path.exists():
        print(f"ОШИБКА: {r16_path} не найден! Выполните Этап А2.")
        sys.exit(1)
        
    print("1/5. Загрузка heightmap v2 и масок Этапа А2...")
    raw = np.fromfile(str(r16_path), dtype='<u2').reshape((size, size))
    height = raw.astype(np.float32) * (400.0 / 65535.0)

    masks_dir = Path("data/masks")
    road_mask = load_mask(masks_dir / "road_mask.png")
    path_mask = load_mask(masks_dir / "path_mask.png")
    river_mask = load_mask(masks_dir / "river_mask.png")
    creek_mask = load_mask(masks_dir / "creek_mask.png")
    bank_mask = load_mask(masks_dir / "bank_mask.png")
    platform_mask = load_mask(masks_dir / "platform_mask.png")

    # 2. Расчет уклона, аспекта и шума границ
    print("2/5. Расчет уклонов, кривизны и пограничного шума...")
    gy, gx = np.gradient(height, dx)
    slope_rad = np.arctan(np.sqrt(gx * gx + gy * gy))
    slope_deg = np.degrees(slope_rad)

    # Высокочастотный шум для границ материалов (масштаб ~40 м)
    rng = np.random.default_rng(spec.get("seed", 20261028))
    noise_grid = rng.standard_normal((128, 128)).astype(np.float32)
    noise_4k = ndi.zoom(noise_grid, size / 128, order=1)[:size, :size]
    noise_4k = (noise_4k - np.mean(noise_4k)) / np.std(noise_4k)
    edge_noise = noise_4k * 0.15

    # Скалы: уклон > 35° с мягким переходом (30°..38°) + влияние шума
    rock_factor = smoothstep(30.0, 38.0, slope_deg + noise_4k * 3.0)

    # Снег: пятна в лощинах и на северных склонах выше 280 м
    # Северные склоны: gy < 0 (строка 0 = Север)
    north_facing = smoothstep(0.0, -0.3, gy / np.maximum(np.abs(gy), 1e-4))
    elevation_snow_factor = smoothstep(270.0, 370.0, height)
    # Пятнистость снега в карах и лощинах
    snow_patch_noise = smoothstep(0.2, 0.7, (noise_4k + 1.0) * 0.5)
    snow_factor = elevation_snow_factor * snow_patch_noise * (0.5 + 0.5 * north_facing)
    # Снег не держится на отвесных скалах > 45°
    snow_factor *= (1.0 - smoothstep(40.0, 50.0, slope_deg))

    # 3. Лесные зоны vs Поляны и луга
    print("3/5. Зонирование лесной подстилки, луговой травы и открытых полян...")
    # Координатная сетка
    xs = np.linspace(-2000.0, 2000.0, size)
    ys = np.linspace(2000.0, -2000.0, size)
    X, Y = np.meshgrid(xs, ys)

    # Открытые луга/поляны: SPAWN, MEADOW, CLEARCUT, MINE_YARD, горные плато > 300 м
    d_spawn = np.hypot(X - (-900.0), Y - (-1100.0))
    m_spawn = 1.0 - smoothstep(60.0, 95.0, d_spawn)

    d_meadow = np.hypot(X - (-1500.0), Y - 1300.0)
    m_meadow = 1.0 - smoothstep(180.0, 280.0, d_meadow)

    d_clearcut = np.hypot(X - (-1100.0), Y - 900.0)
    m_clearcut = 1.0 - smoothstep(120.0, 180.0, d_clearcut)

    # Альпийские луга выше 300 м
    m_alpine = smoothstep(290.0, 340.0, height)

    # Суммарная маска открытых лугов
    meadow_mask = np.clip(m_spawn + m_meadow + m_clearcut + m_alpine + platform_mask, 0.0, 1.0)

    # Базовая вероятность леса: между 60 и 280 м вне полян
    forest_zone = smoothstep(40.0, 80.0, height) * (1.0 - smoothstep(250.0, 310.0, height))
    forest_floor_raw = np.clip(forest_zone * (1.0 - meadow_mask) + edge_noise, 0.0, 1.0)
    grass_raw = np.clip((1.0 - forest_floor_raw) + edge_noise, 0.0, 1.0)

    # 4. Формирование слоев Splatmap
    print("4/5. Сборка слоев splat_a и splat_b с нормализацией весов...")
    
    # Специфические покрытия имеют приоритет над фоновой травой/лесом
    road_w = road_mask
    path_w = path_mask * (1.0 - road_w)
    bank_w = bank_mask * (1.0 - road_w) * (1.0 - path_w)
    snow_w = snow_factor * (1.0 - road_w) * (1.0 - path_w)
    rock_w = rock_factor * (1.0 - road_w) * (1.0 - path_w) * (1.0 - snow_w)

    # Фоновые слои
    remaining = np.maximum(0.0, 1.0 - (road_w + path_w + bank_w + snow_w + rock_w))
    forest_w = forest_floor_raw * remaining
    grass_w = grass_raw * remaining

    # Нормализация
    total_w = grass_w + forest_w + rock_w + path_w + road_w + bank_w + snow_w
    total_w = np.maximum(total_w, 1e-4)
    grass_w /= total_w
    forest_w /= total_w
    rock_w /= total_w
    path_w /= total_w
    road_w /= total_w
    bank_w /= total_w
    snow_w /= total_w

    # splat_a (RGBA): R=Grass, G=ForestFloor, B=Rock, A=Path
    splat_a = np.zeros((size, size, 4), dtype=np.uint8)
    splat_a[:, :, 0] = np.clip(grass_w * 255.0, 0, 255).astype(np.uint8)
    splat_a[:, :, 1] = np.clip(forest_w * 255.0, 0, 255).astype(np.uint8)
    splat_a[:, :, 2] = np.clip(rock_w * 255.0, 0, 255).astype(np.uint8)
    splat_a[:, :, 3] = np.clip(path_w * 255.0, 0, 255).astype(np.uint8)

    # splat_b (RGBA): R=Road, G=Bank, B=Snow, A=Reserve(0)
    splat_b = np.zeros((size, size, 4), dtype=np.uint8)
    splat_b[:, :, 0] = np.clip(road_w * 255.0, 0, 255).astype(np.uint8)
    splat_b[:, :, 1] = np.clip(bank_w * 255.0, 0, 255).astype(np.uint8)
    splat_b[:, :, 2] = np.clip(snow_w * 255.0, 0, 255).astype(np.uint8)
    splat_b[:, :, 3] = 0

    # Сохранение splatmap
    data_dir = Path("data")
    splat_a_path = data_dir / "splat_a.png"
    splat_b_path = data_dir / "splat_b.png"
    Image.fromarray(splat_a, mode='RGBA').save(splat_a_path)
    Image.fromarray(splat_b, mode='RGBA').save(splat_b_path)
    print(f"   -> Сохранен {splat_a_path} ({splat_a_path.stat().st_size / (1024*1024):.2f} МБ)")
    print(f"   -> Сохранен {splat_b_path} ({splat_b_path.stat().st_size / (1024*1024):.2f} МБ)")

    # 5. Запекание Albedo и Normal Map
    print("5/5. Запекание terrain_albedo_4096.jpg и terrain_normal_4096.png...")
    
    # Канонические цвета палитры ТЗ:
    c_grass  = np.array([141.0, 184.0,  74.0])  # #8DB84A молодая весенняя листва/трава
    c_forest = np.array([107.0,  82.0,  50.0])  # #6B5232 прошлогодняя подстилка
    c_rock   = np.array([ 90.0,  90.0,  92.0])  # #5A5A5C серый сланец/известняк
    c_path   = np.array([ 74.0,  58.0,  42.0])  # #4A3A2A влажная земля
    c_road   = np.array([138.0, 133.0, 120.0])  # #8A8578 гравий дороги
    c_bank   = np.array([ 77.0,  71.0,  60.0])  # #4D473C грязь и галька поймы
    c_snow   = np.array([230.0, 235.0, 240.0])  # #E6EBF0 тающий весенний снег

    # Векторное смешивание Albedo
    albedo_r = (grass_w * c_grass[0] + forest_w * c_forest[0] + rock_w * c_rock[0] +
                path_w * c_path[0] + road_w * c_road[0] + bank_w * c_bank[0] + snow_w * c_snow[0])
    albedo_g = (grass_w * c_grass[1] + forest_w * c_forest[1] + rock_w * c_rock[1] +
                path_w * c_path[1] + road_w * c_road[1] + bank_w * c_bank[1] + snow_w * c_snow[1])
    albedo_b = (grass_w * c_grass[2] + forest_w * c_forest[2] + rock_w * c_rock[2] +
                path_w * c_path[2] + road_w * c_road[2] + bank_w * c_bank[2] + snow_w * c_snow[2])

    # Микро-шум для натуральности поверхностей
    albedo_r = np.clip(albedo_r + noise_4k * 6.0, 0, 255).astype(np.uint8)
    albedo_g = np.clip(albedo_g + noise_4k * 6.0, 0, 255).astype(np.uint8)
    albedo_b = np.clip(albedo_b + noise_4k * 6.0, 0, 255).astype(np.uint8)

    albedo_img = Image.fromarray(np.stack([albedo_r, albedo_g, albedo_b], axis=-1), mode='RGB')
    albedo_path = data_dir / "terrain_albedo_4096.jpg"
    albedo_img.save(albedo_path, quality=92)
    print(f"   -> Сохранен Albedo: {albedo_path} ({albedo_path.stat().st_size / (1024*1024):.2f} МБ)")

    # Запекание карты нормалей в касательном пространстве
    # Nx = -gx, Ny = gy (Blender/OpenGL format), Nz = 1.0
    nx = -gx
    ny = gy
    nz = np.ones_like(nx)
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    nx *= inv_len
    ny *= inv_len
    nz *= inv_len

    norm_r = np.clip((nx * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    norm_g = np.clip((ny * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    norm_b = np.clip((nz * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)

    normal_img = Image.fromarray(np.stack([norm_r, norm_g, norm_b], axis=-1), mode='RGB')
    normal_path = data_dir / "terrain_normal_4096.png"
    normal_img.save(normal_path)
    print(f"   -> Сохранена Normal Map: {normal_path} ({normal_path.stat().st_size / (1024*1024):.2f} МБ)")

    # 6. Отчет покрытия
    report = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "resolution": [size, size],
        "coverage_percentage": {
            "grass_meadows": round(float(np.mean(grass_w)) * 100.0, 2),
            "forest_floor":  round(float(np.mean(forest_w)) * 100.0, 2),
            "rock_cliffs":   round(float(np.mean(rock_w)) * 100.0, 2),
            "dirt_paths":    round(float(np.mean(path_w)) * 100.0, 2),
            "gravel_roads":  round(float(np.mean(road_w)) * 100.0, 2),
            "river_banks":   round(float(np.mean(bank_w)) * 100.0, 2),
            "snow_patches":  round(float(np.mean(snow_w)) * 100.0, 2)
        },
        "outputs": {
            "splat_a": str(splat_a_path),
            "splat_b": str(splat_b_path),
            "albedo":  str(albedo_path),
            "normal":  str(normal_path)
        }
    }
    stats_file = data_dir / "splatmap_report.json"
    stats_file.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    
    elapsed = time.time() - start_time
    print("=" * 60)
    print(f"Генерация завершена за {elapsed:.2f} с!")
    print("Баланс покрытия поверхности:")
    for k, v in report["coverage_percentage"].items():
        print(f"  - {k:16s}: {v:5.2f}%")
    print("=" * 60)

if __name__ == "__main__":
    main()
