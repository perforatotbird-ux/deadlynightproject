"""
build_blender_preview.py
========================
Создание сцены Blender forest_map.blend по Этапу А1 спецификации unified_level_design_mvp.md:
- 256 чанков по 250x250 м (сетка 4 м) со смещением из 16-битного heightmap.
- Коллекции: Terrain, Water, Roads, Vegetation, Props, Mine, POI_Markers, Lighting.
- Расстановка POI маркеров.
- Настройка камеры, освещения и рендеринг контрольных ракурсов (вид сверху, вид со SPAWN, вид с LOOKOUT).
"""

import sys
import os
import json
import math
from pathlib import Path

import bpy
import numpy as np

def setup_scene():
    """Очистка сцены и настройка метрических единиц."""
    # Удаляем все стандартные объекты
    bpy.ops.wm.read_factory_settings(use_empty=True)
    
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1.0
    scene.unit_settings.length_unit = 'METERS'
    
    # Создание коллекций
    collections = [
        "Terrain", "Water", "Roads", "Vegetation",
        "Props", "Mine", "POI_Markers", "Lighting", "Cameras"
    ]
    col_dict = {}
    for name in collections:
        col = bpy.data.collections.new(name)
        scene.collection.children.link(col)
        col_dict[name] = col
        
    return scene, col_dict

def load_heightmap():
    """Загрузка 16-битного heightmap через numpy."""
    r16_path = Path("data/heightmap_4096.r16")
    if not r16_path.exists():
        raise FileNotFoundError(f"Heightmap {r16_path} не найден!")
        
    raw = np.fromfile(str(r16_path), dtype='<u2').reshape((4096, 4096))
    height = raw.astype(np.float32) * (400.0 / 65535.0)
    return height

def create_terrain_chunks(height, terrain_col):
    """
    Создание 256 чанков (16x16) по 250x250 м с шагом сетки 4 м (64x64 ячейки).
    Имена: Chunk_XX_YY.
    """
    chunks_per_side = 16
    chunk_size = 250.0
    grid_res = 63  # 64 вершины на сторону -> шаг ~3.968 м
    world_size = 4000.0
    hm_size = 4096
    
    # Шаблоны сетки
    u = np.linspace(0.0, 1.0, grid_res + 1)
    v = np.linspace(0.0, 1.0, grid_res + 1)
    
    # Создаём базовый материал рельефа
    mat = bpy.data.materials.new(name="M_Terrain_Preview")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Roughness"].default_value = 0.85
        bsdf.inputs["Base Color"].default_value = (0.35, 0.45, 0.28, 1.0)
        
    for cy in range(chunks_per_side):
        for cx in range(chunks_per_side):
            chunk_name = f"Chunk_{cx:02d}_{cy:02d}"
            
            # Мировые координаты чанка (Blender: X восток, Y север)
            min_x = -2000.0 + cx * chunk_size
            max_x = min_x + chunk_size
            min_y = -2000.0 + cy * chunk_size
            max_y = min_y + chunk_size
            
            # Координаты сетки
            gx = min_x + u * chunk_size
            gy = min_y + v * chunk_size
            GX, GY = np.meshgrid(gx, gy)
            
            # Индексы в heightmap (строка 0 = Y=+2000м, столбец 0 = X=-2000м)
            cols = np.clip(((GX + 2000.0) / world_size * (hm_size - 1)).astype(int), 0, hm_size - 1)
            rows = np.clip(((2000.0 - GY) / world_size * (hm_size - 1)).astype(int), 0, hm_size - 1)
            GZ = height[rows, cols]
            
            # Вершины
            verts = np.stack([GX.ravel(), GY.ravel(), GZ.ravel()], axis=1).tolist()
            
            # Грани
            faces = []
            stride = grid_res + 1
            for j in range(grid_res):
                for i in range(grid_res):
                    v0 = j * stride + i
                    v1 = v0 + 1
                    v2 = (j + 1) * stride + i + 1
                    v3 = (j + 1) * stride + i
                    faces.append((v0, v1, v2, v3))
                    
            # Создание объекта
            mesh = bpy.data.meshes.new(chunk_name)
            mesh.from_pydata(verts, [], faces)
            mesh.update()
            
            obj = bpy.data.objects.new(chunk_name, mesh)
            obj.data.materials.append(mat)
            terrain_col.objects.link(obj)

def add_poi_markers(pois, marker_col):
    """Добавление визуальных маркеров POI в сцену."""
    for p in pois:
        pid = p["id"]
        x, y, z = p["position"]
        name = f"POI_{pid}"
        
        # Создаем пирамидку/маркер
        mesh = bpy.data.meshes.new(name)
        # Простая пирамида высотой 15 м
        h_m = 15.0
        w_m = 5.0
        verts = [
            (x - w_m, y - w_m, z),
            (x + w_m, y - w_m, z),
            (x + w_m, y + w_m, z),
            (x - w_m, y + w_m, z),
            (x, y, z + h_m)
        ]
        faces = [
            (0, 1, 2, 3),
            (0, 1, 4),
            (1, 2, 4),
            (2, 3, 4),
            (3, 0, 4)
        ]
        mesh.from_pydata(verts, [], faces)
        mesh.update()
        
        obj = bpy.data.objects.new(name, mesh)
        
        # Цвет маркера
        mat = bpy.data.materials.new(name=f"M_{name}")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            col = (1.0, 0.2, 0.2, 1.0) if pid in ["SPAWN", "MINE_YARD", "PEAK"] else (1.0, 0.8, 0.1, 1.0)
            bsdf.inputs["Base Color"].default_value = col
            bsdf.inputs["Emission Color"].default_value = col
            bsdf.inputs["Emission Strength"].default_value = 1.0
            
        obj.data.materials.append(mat)
        marker_col.objects.link(obj)

def setup_lighting(light_col):
    """Настройка солнца (азимут 110°, высота 25°)."""
    sun_data = bpy.data.lights.new(name="Sun", type='SUN')
    sun_data.energy = 3.5
    sun_data.color = (1.0, 0.95, 0.85)
    
    sun_obj = bpy.data.objects.new(name="Sun", object_data=sun_data)
    # Направление света
    sun_obj.rotation_euler = (math.radians(65.0), 0.0, math.radians(-70.0))
    light_col.objects.link(sun_obj)

def render_views(scene, cam_col):
    """Создание камер и рендеринг контрольных ракурсов."""
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.engine = 'BLENDER_EEVEE'
    
    # 1. Вид сверху (Topdown)
    cam_top_data = bpy.data.cameras.new("Cam_Topdown")
    cam_top_data.clip_end = 10000.0
    cam_top = bpy.data.objects.new("Cam_Topdown", cam_top_data)
    cam_top.location = (0.0, 0.0, 3600.0)
    cam_top.rotation_euler = (0.0, 0.0, 0.0)
    cam_col.objects.link(cam_top)
    
    scene.camera = cam_top
    scene.render.filepath = os.path.abspath("data/render_topdown.png")
    bpy.ops.render.render(write_still=True)
    print("-> Отрендерен вид сверху: data/render_topdown.png")

    # 2. Вид со SPAWN на северо-восточные горы
    cam_spawn_data = bpy.data.cameras.new("Cam_Spawn")
    cam_spawn_data.clip_end = 6000.0
    cam_spawn = bpy.data.objects.new("Cam_Spawn", cam_spawn_data)
    cam_spawn.location = (-900.0, -1100.0, 27.0)
    # Направление в сторону (1500, 1500, 380)
    dx = 1500.0 - (-900.0)
    dy = 1500.0 - (-1100.0)
    dz = 380.0 - 27.0
    yaw = math.atan2(dy, dx) - math.pi / 2.0
    pitch = math.pi / 2.0 - math.atan2(dz, math.sqrt(dx*dx + dy*dy))
    cam_spawn.rotation_euler = (pitch + 0.1, 0.0, yaw)
    cam_col.objects.link(cam_spawn)
    
    scene.camera = cam_spawn
    scene.render.filepath = os.path.abspath("data/render_spawn_view.png")
    bpy.ops.render.render(write_still=True)
    print("-> Отрендерен ракурс со SPAWN: data/render_spawn_view.png")

    # 3. Вид с LOOKOUT на долину
    cam_look_data = bpy.data.cameras.new("Cam_Lookout")
    cam_look_data.clip_end = 6000.0
    cam_look = bpy.data.objects.new("Cam_Lookout", cam_look_data)
    cam_look.location = (700.0, 1550.0, 375.0)
    cam_look.rotation_euler = (math.radians(75.0), 0.0, math.radians(-130.0))
    cam_col.objects.link(cam_look)
    
    scene.camera = cam_look
    scene.render.filepath = os.path.abspath("data/render_lookout_view.png")
    bpy.ops.render.render(write_still=True)
    print("-> Отрендерен ракурс с LOOKOUT: data/render_lookout_view.png")

def main():
    print("=" * 60)
    print("Построение сцены Blender forest_map.blend")
    print("=" * 60)
    
    spec = json.loads(Path("data/spec.json").read_text(encoding="utf-8"))
    
    scene, col_dict = setup_scene()
    print("1/5. Создана чистая сцена и коллекции...")
    
    height = load_heightmap()
    print("2/5. Загружен 16-битный heightmap 4096x4096...")
    
    create_terrain_chunks(height, col_dict["Terrain"])
    print("3/5. Сгенерировано 256 чанков рельефа (сетка 4 м)...")
    
    add_poi_markers(spec["pois"], col_dict["POI_Markers"])
    print("4/5. Размещены маркеры POI...")
    
    setup_lighting(col_dict["Lighting"])
    render_views(scene, col_dict["Cameras"])
    print("5/5. Отрендерены 3 контрольных ракурса...")
    
    out_blend = Path("assets/source_blender/forest_map.blend")
    out_blend.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(out_blend.resolve()))
    print(f"-> Сохранена сцена: {out_blend} ({out_blend.stat().st_size / (1024*1024):.2f} МБ)")
    print("=" * 60)

if __name__ == "__main__":
    main()
