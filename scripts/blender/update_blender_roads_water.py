"""
update_blender_roads_water.py
=============================
Интеграция дорог, воды, моста и брода в сцену Blender forest_map.blend (Этап А2):
- Обновление высот рельефа 256 чанков из heightmap_4096_v2.r16.
- Построение 3D-сплайнов дорог (Roads) и троп.
- Создание водной ленты реки Быстрая (Water) с материалом воды.
- Построение бревенчатого моста 12 м на BRIDGE (925, 37).
- Построение брода на FORD (795, 520).
- Рендеринг 4 контрольных ракурсов: BRIDGE, FORD, FORK, MINE_YARD.
- Сохранение сцены assets/source_blender/forest_map.blend.
"""

import os
import sys
import json
import math
from pathlib import Path

import bpy
import numpy as np

def load_heightmap_v2():
    r16_path = Path("data/heightmap_4096_v2.r16")
    raw = np.fromfile(str(r16_path), dtype='<u2').reshape((4096, 4096))
    return raw.astype(np.float32) * (400.0 / 65535.0)

def catmull_rom_spline(control_points, num_points_per_segment=25):
    pts = np.array(control_points, dtype=np.float64)
    if len(pts) < 2:
        return pts
    p_ext = np.vstack([pts[0] - (pts[1] - pts[0]), pts, pts[-1] + (pts[-1] - pts[-2])])
    spline_points = []
    for i in range(len(pts) - 1):
        p0, p1, p2, p3 = p_ext[i], p_ext[i+1], p_ext[i+2], p_ext[i+3]
        t = np.linspace(0.0, 1.0, num_points_per_segment, endpoint=(i == len(pts)-2))[:, None]
        t2 = t * t
        t3 = t2 * t
        point = 0.5 * (
            (2.0 * p1) +
            (-p0 + p2) * t +
            (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
            (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
        )
        spline_points.append(point)
    return np.vstack(spline_points)

def get_terrain_z(x, y, height):
    col = int(np.clip((x + 2000.0) / 4000.0 * 4095.0, 0, 4095))
    row = int(np.clip((2000.0 - y) / 4000.0 * 4095.0, 0, 4095))
    return float(height[row, col])

def update_terrain_meshes(height):
    """Обновление Z-координат вершин всех 256 чанков."""
    chunks_per_side = 16
    chunk_size = 250.0
    grid_res = 63
    world_size = 4000.0
    hm_size = 4096
    u = np.linspace(0.0, 1.0, grid_res + 1)
    v = np.linspace(0.0, 1.0, grid_res + 1)
    
    for cy in range(chunks_per_side):
        for cx in range(chunks_per_side):
            chunk_name = f"Chunk_{cx:02d}_{cy:02d}"
            obj = bpy.data.objects.get(chunk_name)
            if not obj:
                continue
                
            min_x = -2000.0 + cx * chunk_size
            min_y = -2000.0 + cy * chunk_size
            gx = min_x + u * chunk_size
            gy = min_y + v * chunk_size
            GX, GY = np.meshgrid(gx, gy)
            
            cols = np.clip(((GX + 2000.0) / world_size * (hm_size - 1)).astype(int), 0, hm_size - 1)
            rows = np.clip(((2000.0 - GY) / world_size * (hm_size - 1)).astype(int), 0, hm_size - 1)
            GZ = height[rows, cols].ravel()
            
            mesh = obj.data
            for idx, vert in enumerate(mesh.vertices):
                vert.co.z = GZ[idx]
            mesh.update()

def create_curve_object(name, points_3d, col, bevel_depth=0.1):
    curve_data = bpy.data.curves.new(name, type='CURVE')
    curve_data.dimensions = '3D'
    curve_data.bevel_depth = bevel_depth
    curve_data.bevel_resolution = 2
    
    polyline = curve_data.splines.new('POLY')
    polyline.points.add(len(points_3d) - 1)
    for i, pt in enumerate(points_3d):
        polyline.points[i].co = (pt[0], pt[1], pt[2], 1.0)
        
    obj = bpy.data.objects.new(name, curve_data)
    col.objects.link(obj)
    return obj

def build_roads_and_trails(spec, height, roads_col):
    """Построение 3D-кривых для дорог и троп."""
    # Дороги
    mat_road = bpy.data.materials.new("M_Road_Gravel")
    mat_road.use_nodes = True
    bsdf = mat_road.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.54, 0.52, 0.47, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.95
        
    for branch_id in ["road_main", "road_east_branch", "road_mine_branch"]:
        c_pts = spec["splines"][branch_id]
        spline = catmull_rom_spline(c_pts, num_points_per_segment=30)
        pts_3d = []
        for pt in spline:
            z = get_terrain_z(pt[0], pt[1], height) + 0.08  # чуть выше террейна
            pts_3d.append((pt[0], pt[1], z))
        obj = create_curve_object(f"Road_{branch_id}", pts_3d, roads_col, bevel_depth=1.9)
        obj.data.materials.append(mat_road)

    # Тропы
    mat_trail = bpy.data.materials.new("M_Trail_Dirt")
    mat_trail.use_nodes = True
    bsdf = mat_trail.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.35, 0.25, 0.17, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.9
        
    for tid, t_pts in spec["splines"]["trails"].items():
        spline = catmull_rom_spline(t_pts, num_points_per_segment=25)
        pts_3d = []
        for pt in spline:
            z = get_terrain_z(pt[0], pt[1], height) + 0.04
            pts_3d.append((pt[0], pt[1], z))
        obj = create_curve_object(f"Trail_{tid}", pts_3d, roads_col, bevel_depth=0.5)
        obj.data.materials.append(mat_trail)

def build_water_ribbon(spec, height, water_col):
    """Создание водной поверхности реки Быстрая и ручья."""
    mat_water = bpy.data.materials.new("M_River_Water")
    mat_water.use_nodes = True
    bsdf = mat_water.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.15, 0.35, 0.45, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.05
        if "Transmission Weight" in bsdf.inputs:
            bsdf.inputs["Transmission Weight"].default_value = 0.8
        elif "Transmission" in bsdf.inputs:
            bsdf.inputs["Transmission"].default_value = 0.8

    # Река
    river_pts = catmull_rom_spline(spec["splines"]["river"], num_points_per_segment=35)
    r_verts = []
    r_faces = []
    half_w = 3.5
    
    for i in range(len(river_pts)):
        p = river_pts[i]
        # Касательный вектор к сплайну
        if i < len(river_pts) - 1:
            tangent = river_pts[i+1] - p
        else:
            tangent = p - river_pts[i-1]
        t_len = math.hypot(tangent[0], tangent[1])
        if t_len == 0:
            norm = np.array([0.0, 1.0])
        else:
            norm = np.array([-tangent[1], tangent[0]]) / t_len
            
        # Уровень воды плавно от 35 м до 8 м
        frac = i / (len(river_pts) - 1)
        z_water = 34.0 - frac * 26.5
        
        p_left = (p[0] + norm[0] * half_w, p[1] + norm[1] * half_w, z_water)
        p_right = (p[0] - norm[0] * half_w, p[1] - norm[1] * half_w, z_water)
        
        idx = len(r_verts)
        r_verts.extend([p_left, p_right])
        if i > 0:
            r_faces.append((idx - 2, idx - 1, idx + 1, idx))
            
    mesh = bpy.data.meshes.new("River_Surface")
    mesh.from_pydata(r_verts, [], r_faces)
    mesh.update()
    obj = bpy.data.objects.new("River_Surface", mesh)
    obj.data.materials.append(mat_water)
    water_col.objects.link(obj)

def build_bridge_and_ford(height, props_col):
    """Построение бревенчатого моста 12 м на BRIDGE и брода на FORD."""
    # 1. Мост на BRIDGE (925, 37)
    bx, by = 925.0, 37.0
    bz = get_terrain_z(bx, by, height)
    
    mat_wood = bpy.data.materials.new("M_Bridge_Wood")
    mat_wood.use_nodes = True
    bsdf = mat_wood.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.4, 0.28, 0.18, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.8
        
    # Настил моста 12 м в длину (по оси X/направлению дороги), 4.5 м в ширину
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx, by, bz + 0.3))
    deck = bpy.context.active_object
    deck.name = "Bridge_Deck"
    deck.scale = (12.0, 4.5, 0.4)
    deck.data.materials.append(mat_wood)
    props_col.objects.link(deck)
    bpy.context.collection.objects.unlink(deck)

    # Перила моста
    for side in [-2.1, 2.1]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=12.0, location=(bx, by + side, bz + 1.2))
        rail = bpy.context.active_object
        rail.name = f"Bridge_Railing_{side}"
        rail.rotation_euler = (0.0, math.radians(90.0), 0.0)
        rail.data.materials.append(mat_wood)
        props_col.objects.link(rail)
        bpy.context.collection.objects.unlink(rail)
        
    # 2. Брод на FORD (795, 520)
    fx, fy = 795.0, 520.0
    fz = get_terrain_z(fx, fy, height)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(fx, fy, fz + 0.05))
    ford = bpy.context.active_object
    ford.name = "Ford_Crossing_Platform"
    ford.scale = (8.0, 4.0, 0.15)
    ford.data.materials.append(mat_wood)
    props_col.objects.link(ford)
    bpy.context.collection.objects.unlink(ford)

def render_checkpoint_views(scene, cam_col, height):
    """Рендеринг 4 контрольных ракурсов Этапа А2: BRIDGE, FORD, FORK, MINE_YARD."""
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.engine = 'BLENDER_EEVEE'
    
    checkpoints = [
        {
            "name": "render_bridge.png",
            "pos": (885.0, 10.0, get_terrain_z(885.0, 10.0, height) + 12.0),
            "look_at": (925.0, 37.0, get_terrain_z(925.0, 37.0, height) + 1.0)
        },
        {
            "name": "render_ford.png",
            "pos": (760.0, 490.0, get_terrain_z(760.0, 490.0, height) + 10.0),
            "look_at": (795.0, 520.0, get_terrain_z(795.0, 520.0, height) + 0.5)
        },
        {
            "name": "render_fork.png",
            "pos": (550.0, 170.0, get_terrain_z(550.0, 170.0, height) + 14.0),
            "look_at": (600.0, 200.0, get_terrain_z(600.0, 200.0, height) + 1.0)
        },
        {
            "name": "render_mine_yard.png",
            "pos": (1060.0, 1140.0, get_terrain_z(1060.0, 1140.0, height) + 15.0),
            "look_at": (1130.0, 1210.0, get_terrain_z(1130.0, 1210.0, height) + 5.0)
        }
    ]
    
    for cp in checkpoints:
        cam_name = f"Cam_{cp['name'].replace('.png', '')}"
        cam_data = bpy.data.cameras.new(cam_name)
        cam_data.clip_end = 5000.0
        cam_obj = bpy.data.objects.new(cam_name, cam_data)
        cam_obj.location = cp["pos"]
        
        # Направление на точку
        dx = cp["look_at"][0] - cp["pos"][0]
        dy = cp["look_at"][1] - cp["pos"][1]
        dz = cp["look_at"][2] - cp["pos"][2]
        dist_xy = math.hypot(dx, dy)
        yaw = math.atan2(dy, dx) - math.pi / 2.0
        pitch = math.pi / 2.0 - math.atan2(dz, dist_xy)
        cam_obj.rotation_euler = (pitch, 0.0, yaw)
        
        cam_col.objects.link(cam_obj)
        scene.camera = cam_obj
        
        out_file = os.path.abspath(f"data/{cp['name']}")
        scene.render.filepath = out_file
        bpy.ops.render.render(write_still=True)
        print(f"-> Отрендерен ракурс: data/{cp['name']}")

def main():
    print("=" * 60)
    print("Обновление сцены Blender (Дороги, Вода, Мост, Брод)")
    print("=" * 60)
    
    blend_path = Path("assets/source_blender/forest_map.blend")
    if not blend_path.exists():
        print(f"ОШИБКА: Сцена {blend_path} не найдена!")
        sys.exit(1)
        
    bpy.ops.wm.open_mainfile(filepath=str(blend_path.resolve()))
    scene = bpy.context.scene
    
    # Коллекции
    cols = {c.name: c for c in scene.collection.children}
    roads_col = cols.get("Roads", scene.collection)
    water_col = cols.get("Water", scene.collection)
    props_col = cols.get("Props", scene.collection)
    cam_col = cols.get("Cameras", scene.collection)
    
    spec = json.loads(Path("data/spec.json").read_text(encoding="utf-8"))
    height_v2 = load_heightmap_v2()
    print("1/5. Загружен heightmap_4096_v2.r16...")
    
    update_terrain_meshes(height_v2)
    print("2/5. Обновлены высоты 256 чанков рельефа под профиль дорог...")
    
    build_roads_and_trails(spec, height_v2, roads_col)
    print("3/5. Построены 3D-кривые дорог и троп...")
    
    build_water_ribbon(spec, height_v2, water_col)
    build_bridge_and_ford(height_v2, props_col)
    print("4/5. Создана лента реки Быстрая, мост BRIDGE и брод FORD...")
    
    render_checkpoint_views(scene, cam_col, height_v2)
    print("5/5. Отрендерены 4 контрольных ракурса...")
    
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path.resolve()))
    print(f"-> Сцена обновлена: {blend_path} ({blend_path.stat().st_size / (1024*1024):.2f} МБ)")
    print("=" * 60)

if __name__ == "__main__":
    main()
