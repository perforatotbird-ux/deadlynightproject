"""
apply_terrain_materials.py
==========================
Настройка PBR-материала ландшафта в Blender (Этап А3):
- Создание процедурного шейдера M_Terrain_PBR с использованием запеченных 4K карт:
  terrain_albedo_4096.jpg и terrain_normal_4096.png.
- Мировые координаты (World Position Mapping) для бесшовного наложения на все 256 чанков.
- Рендеринг 4 контрольных ракурсов:
  1. render_mat_spawn.png (поляна старта: трава, дорога, тропа)
  2. render_mat_fork.png (развилка дороги: гравий, кюветы, лес)
  3. render_mat_cliffs.png (скалы массива PEAK со снежными лощинами)
  4. render_mat_riverbank.png (берег реки Быстрая: галька, вода, лес)
- Сохранение сцены assets/source_blender/forest_map.blend.
"""

import os
import sys
import math
from pathlib import Path

import bpy
import numpy as np

def load_heightmap_v2():
    r16_path = Path("data/heightmap_4096_v2.r16")
    raw = np.fromfile(str(r16_path), dtype='<u2').reshape((4096, 4096))
    return raw.astype(np.float32) * (400.0 / 65535.0)

def get_terrain_z(x, y, height):
    col = int(np.clip((x + 2000.0) / 4000.0 * 4095.0, 0, 4095))
    row = int(np.clip((2000.0 - y) / 4000.0 * 4095.0, 0, 4095))
    return float(height[row, col])

def setup_terrain_pbr_material():
    """Создание PBR-материала со всемирными UV-координатами."""
    mat_name = "M_Terrain_PBR"
    mat = bpy.data.materials.get(mat_name)
    if not mat:
        mat = bpy.data.materials.new(name=mat_name)
        
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    
    # 1. Output & Principled BSDF
    node_out = nodes.new(type="ShaderNodeOutputMaterial")
    node_out.location = (800, 0)
    
    node_bsdf = nodes.new(type="ShaderNodeBsdfPrincipled")
    node_bsdf.location = (500, 0)
    node_bsdf.inputs["Roughness"].default_value = 0.88
    links.new(node_bsdf.outputs["BSDF"], node_out.inputs["Surface"])
    
    # 2. Geometry Node (World Position)
    node_geom = nodes.new(type="ShaderNodeNewGeometry")
    node_geom.location = (-800, 0)
    
    # 3. Vector Math: Add (2000, 2000, 0) -> перенос начала координат
    node_add = nodes.new(type="ShaderNodeVectorMath")
    node_add.operation = 'ADD'
    node_add.location = (-600, 0)
    node_add.inputs[1].default_value = (2000.0, 2000.0, 0.0)
    links.new(node_geom.outputs["Position"], node_add.inputs[0])
    
    # 4. Vector Math: Multiply (1/4000, 1/4000, 0) -> нормализация в 0..1
    node_mul = nodes.new(type="ShaderNodeVectorMath")
    node_mul.operation = 'MULTIPLY'
    node_mul.location = (-400, 0)
    node_mul.inputs[1].default_value = (1.0 / 4000.0, 1.0 / 4000.0, 0.0)
    links.new(node_add.outputs["Vector"], node_mul.inputs[0])
    
    # 5. Image Texture: Albedo
    albedo_file = os.path.abspath("data/terrain_albedo_4096.jpg")
    img_albedo = bpy.data.images.load(albedo_file, check_existing=True)
    node_albedo = nodes.new(type="ShaderNodeTexImage")
    node_albedo.location = (-100, 150)
    node_albedo.image = img_albedo
    links.new(node_mul.outputs["Vector"], node_albedo.inputs["Vector"])
    links.new(node_albedo.outputs["Color"], node_bsdf.inputs["Base Color"])
    
    # 6. Image Texture: Normal Map
    normal_file = os.path.abspath("data/terrain_normal_4096.png")
    img_normal = bpy.data.images.load(normal_file, check_existing=True)
    img_normal.colorspace_settings.name = 'Non-Color'
    
    node_normal = nodes.new(type="ShaderNodeTexImage")
    node_normal.location = (-100, -150)
    node_normal.image = img_normal
    links.new(node_mul.outputs["Vector"], node_normal.inputs["Vector"])
    
    node_norm_map = nodes.new(type="ShaderNodeNormalMap")
    node_norm_map.location = (200, -150)
    node_norm_map.inputs["Strength"].default_value = 1.0
    links.new(node_normal.outputs["Color"], node_norm_map.inputs["Color"])
    links.new(node_norm_map.outputs["Normal"], node_bsdf.inputs["Normal"])
    
    return mat

def apply_material_to_all_chunks(mat):
    chunks_per_side = 16
    count = 0
    for cy in range(chunks_per_side):
        for cx in range(chunks_per_side):
            chunk_name = f"Chunk_{cx:02d}_{cy:02d}"
            obj = bpy.data.objects.get(chunk_name)
            if obj:
                if len(obj.data.materials) == 0:
                    obj.data.materials.append(mat)
                else:
                    obj.data.materials[0] = mat
                count += 1
    return count

def render_material_views(scene, cam_col, height):
    """Рендеринг 4 контрольных ракурсов текстурирования."""
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.engine = 'BLENDER_EEVEE'
    
    views = [
        {
            "name": "render_mat_spawn.png",
            "pos": (-900.0, -1140.0, get_terrain_z(-900.0, -1140.0, height) + 12.0),
            "look_at": (-880.0, -1070.0, get_terrain_z(-880.0, -1070.0, height) + 2.0)
        },
        {
            "name": "render_mat_fork.png",
            "pos": (570.0, 160.0, get_terrain_z(570.0, 160.0, height) + 14.0),
            "look_at": (605.0, 205.0, get_terrain_z(605.0, 205.0, height) + 1.0)
        },
        {
            "name": "render_mat_cliffs.png",
            "pos": (1250.0, 1250.0, get_terrain_z(1250.0, 1250.0, height) + 25.0),
            "look_at": (1500.0, 1500.0, 380.0)
        },
        {
            "name": "render_mat_riverbank.png",
            "pos": (920.0, -40.0, get_terrain_z(920.0, -40.0, height) + 8.0),
            "look_at": (900.0, 0.0, 26.0)
        }
    ]
    
    for v in views:
        cam_name = f"Cam_{v['name'].replace('.png', '')}"
        cam_data = bpy.data.cameras.new(cam_name)
        cam_data.clip_end = 5000.0
        cam_obj = bpy.data.objects.new(cam_name, cam_data)
        cam_obj.location = v["pos"]
        
        dx = v["look_at"][0] - v["pos"][0]
        dy = v["look_at"][1] - v["pos"][1]
        dz = v["look_at"][2] - v["pos"][2]
        dist_xy = math.hypot(dx, dy)
        yaw = math.atan2(dy, dx) - math.pi / 2.0
        pitch = math.pi / 2.0 - math.atan2(dz, dist_xy)
        cam_obj.rotation_euler = (pitch, 0.0, yaw)
        
        cam_col.objects.link(cam_obj)
        scene.camera = cam_obj
        
        out_file = os.path.abspath(f"data/{v['name']}")
        scene.render.filepath = out_file
        bpy.ops.render.render(write_still=True)
        print(f"-> Отрендерен ракурс: data/{v['name']}")

def main():
    print("=" * 60)
    print("Настройка PBR-текстур ландшафта в Blender (Этап А3)")
    print("=" * 60)
    
    blend_path = Path("assets/source_blender/forest_map.blend")
    if not blend_path.exists():
        print(f"ОШИБКА: {blend_path} не найден!")
        sys.exit(1)
        
    bpy.ops.wm.open_mainfile(filepath=str(blend_path.resolve()))
    scene = bpy.context.scene
    
    cols = {c.name: c for c in scene.collection.children}
    cam_col = cols.get("Cameras", scene.collection)
    
    height = load_heightmap_v2()
    print("1/4. Загружен heightmap_v2 для расчёта высот камер...")
    
    mat = setup_terrain_pbr_material()
    print("2/4. Создан PBR-шейдер M_Terrain_PBR (Albedo 4K + Normal Map 4K)...")
    
    count = apply_material_to_all_chunks(mat)
    print(f"3/4. Материал назначен на все {count} чанков рельефа...")
    
    render_material_views(scene, cam_col, height)
    print("4/4. Отрендерены 4 контрольных ракурса материалов...")
    
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path.resolve()))
    print(f"-> Сцена сохранена: {blend_path} ({blend_path.stat().st_size / (1024*1024):.2f} МБ)")
    print("=" * 60)

if __name__ == "__main__":
    main()
