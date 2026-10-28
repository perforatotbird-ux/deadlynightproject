"""
generate_tree_and_prop_assets.py - Blender 5.2 script
Generates low-poly 3D assets for Deadly Night MVP and exports to glTF 2.0 (.glb)
Covers:
- 4 Tree species (Birch, Spruce, Beech, Oak) with full trees, stumps, logs, and 4 chop stages
- Props: 4 bushes, 4 boulders, deadwood log, 12m bridge, survival axe
- Mine: timber portal, timber frame, mining cart, 3m rails, crate, barrel, rock rubble
"""

import bpy
import bmesh
import math
import os
import random
from mathutils import Vector, Matrix, Euler

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TREES_DIR = os.path.join(PROJECT_ROOT, "assets", "models", "trees")
PROPS_DIR = os.path.join(PROJECT_ROOT, "assets", "models", "props")
MINE_DIR = os.path.join(PROJECT_ROOT, "assets", "models", "mine")

for d in [TREES_DIR, PROPS_DIR, MINE_DIR]:
    os.makedirs(d, exist_ok=True)

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Ensure a collection exists
    if not bpy.data.collections:
        col = bpy.data.collections.new("SceneCollection")
        bpy.context.scene.collection.children.link(col)

def create_pbr_material(name, color_rgba, roughness=0.8, metallic=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color_rgba
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
    return mat

def export_glb(filepath, objects=None):
    if objects is None:
        objects = list(bpy.context.scene.objects)
    
    # Select only specified objects
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True
    )
    print(f"Exported: {filepath} ({os.path.getsize(filepath):,} bytes)")

# -------------------------------------------------------------
# 1. TREES GENERATOR
# -------------------------------------------------------------

def build_tree_mesh(species, stage=0):
    """
    Builds tree mesh with chop stage 0..3:
    Stage 0: Intact trunk
    Stage 1: Small wedge cut (~20% trunk depth) at height 1.0m
    Stage 2: Medium wedge cut (~50% trunk depth)
    Stage 3: Deep wedge cut (~80% trunk depth) with slight tilt
    """
    specs = {
        'birch': {
            'height': 18.0,
            'trunk_r_base': 0.22,
            'trunk_r_top': 0.08,
            'bark_color': (0.88, 0.86, 0.82, 1.0),
            'bark_dark': (0.15, 0.14, 0.13, 1.0),
            'foliage_color': (0.38, 0.59, 0.20, 1.0),
            'wood_inner': (0.96, 0.96, 0.86, 1.0),
            'canopy_style': 'birch'
        },
        'spruce': {
            'height': 24.0,
            'trunk_r_base': 0.35,
            'trunk_r_top': 0.06,
            'bark_color': (0.29, 0.22, 0.16, 1.0),
            'bark_dark': (0.18, 0.12, 0.08, 1.0),
            'foliage_color': (0.12, 0.23, 0.13, 1.0),
            'wood_inner': (0.82, 0.41, 0.12, 1.0),
            'canopy_style': 'spruce'
        },
        'beech': {
            'height': 24.0,
            'trunk_r_base': 0.40,
            'trunk_r_top': 0.14,
            'bark_color': (0.48, 0.49, 0.49, 1.0),
            'bark_dark': (0.32, 0.33, 0.33, 1.0),
            'foliage_color': (0.29, 0.50, 0.16, 1.0),
            'wood_inner': (0.93, 0.86, 0.51, 1.0),
            'canopy_style': 'beech'
        },
        'oak': {
            'height': 20.0,
            'trunk_r_base': 0.45,
            'trunk_r_top': 0.18,
            'bark_color': (0.24, 0.15, 0.10, 1.0),
            'bark_dark': (0.15, 0.09, 0.05, 1.0),
            'foliage_color': (0.23, 0.36, 0.15, 1.0),
            'wood_inner': (0.55, 0.35, 0.17, 1.0),
            'canopy_style': 'oak'
        }
    }
    
    cfg = specs[species]
    mat_bark = create_pbr_material(f"M_Bark_{species}", cfg['bark_color'], roughness=0.85)
    mat_foliage = create_pbr_material(f"M_Foliage_{species}", cfg['foliage_color'], roughness=0.7)
    mat_cut = create_pbr_material(f"M_CutWood_{species}", cfg['wood_inner'], roughness=0.6)

    # Base mesh for trunk
    bm = bmesh.new()
    
    height = cfg['height']
    r_base = cfg['trunk_r_base']
    r_top = cfg['trunk_r_top']
    n_seg = 10
    
    # Generate trunk segments
    # Stage 3 has slight tilt (2 degrees)
    tilt_angle = math.radians(2.5) if stage == 3 else 0.0
    
    levels = [
        (0.0, r_base * 1.15),
        (0.6, r_base),
        (1.0, r_base * 0.95), # chop zone
        (2.0, r_base * 0.90),
        (height * 0.3, r_base * 0.75),
        (height * 0.6, r_base * 0.50),
        (height * 0.85, r_base * 0.30),
        (height, r_top)
    ]
    
    prev_verts = []
    all_trunk_faces = []
    
    for lvl_idx, (z, r) in enumerate(levels):
        ring_verts = []
        # Calculate horizontal displacement if tilted above chop height
        x_shift = 0.0
        y_shift = 0.0
        if z > 1.0 and tilt_angle > 0:
            x_shift = (z - 1.0) * math.sin(tilt_angle)
            
        for s in range(n_seg):
            angle = s * (2.0 * math.pi / n_seg)
            # Add subtle organic noise
            r_noisy = r * (0.95 + 0.1 * math.sin(angle * 3 + z))
            vx = r_noisy * math.cos(angle) + x_shift
            vy = r_noisy * math.sin(angle) + y_shift
            vz = z
            
            # Carve chop notch on +X side (angle near 0) at height ~1.0m
            if stage > 0 and 0.8 <= z <= 1.2:
                # If vertex faces +X
                if math.cos(angle) > 0.2:
                    cut_depths = [0.0, 0.25, 0.55, 0.82]
                    depth = cut_depths[stage] * r_base * 2.0
                    vx = vx - depth * math.cos(angle) * (1.0 - abs(z - 1.0)/0.25)
            
            v = bm.verts.new((vx, vy, vz))
            ring_verts.append(v)
            
        if prev_verts:
            for s in range(n_seg):
                s_next = (s + 1) % n_seg
                face = bm.faces.new([
                    prev_verts[s], prev_verts[s_next],
                    ring_verts[s_next], ring_verts[s]
                ])
                face.material_index = 0 # bark
                all_trunk_faces.append(face)
        else:
            # Bottom cap
            bottom_cap = bm.faces.new(list(reversed(ring_verts)))
            bottom_cap.material_index = 0
            
        prev_verts = ring_verts
        
    # Top cap
    top_cap = bm.faces.new(ring_verts)
    top_cap.material_index = 0
    
    # Create Foliage clusters
    foliage_faces = []
    rnd = random.Random(hash(species) + 42)
    
    if cfg['canopy_style'] == 'spruce':
        # Conical tiers
        n_tiers = 6
        for t in range(n_tiers):
            tier_z = height * (0.28 + 0.65 * (t / n_tiers))
            tier_r = (1.0 - t / (n_tiers + 1)) * (height * 0.22)
            tier_h = height * 0.18
            
            # Cone frustum with 8 segments
            tier_verts_bottom = []
            tier_verts_top = []
            c_seg = 8
            for cs in range(c_seg):
                ca = cs * (2.0 * math.pi / c_seg) + (t * 0.3)
                rx = (tier_r * (0.85 + 0.3 * rnd.random())) * math.cos(ca)
                ry = (tier_r * (0.85 + 0.3 * rnd.random())) * math.sin(ca)
                v_bot = bm.verts.new((rx, ry, tier_z))
                v_top = bm.verts.new((rx * 0.3, ry * 0.3, tier_z + tier_h))
                tier_verts_bottom.append(v_bot)
                tier_verts_top.append(v_top)
                
            v_peak = bm.verts.new((0, 0, tier_z + tier_h * 1.1))
            for cs in range(c_seg):
                cs_n = (cs + 1) % c_seg
                f1 = bm.faces.new([tier_verts_bottom[cs], tier_verts_bottom[cs_n],
                                  tier_verts_top[cs_n], tier_verts_top[cs]])
                f1.material_index = 1 # foliage
                foliage_faces.append(f1)
                f2 = bm.faces.new([tier_verts_top[cs], tier_verts_top[cs_n], v_peak])
                f2.material_index = 1
                foliage_faces.append(f2)
                
    else:
        # Rounded leafy clumps (Birch, Beech, Oak)
        if cfg['canopy_style'] == 'birch':
            n_clusters = 5
            cluster_base_r = height * 0.16
            z_start = height * 0.45
        elif cfg['canopy_style'] == 'beech':
            n_clusters = 8
            cluster_base_r = height * 0.24
            z_start = height * 0.38
        else: # oak
            n_clusters = 9
            cluster_base_r = height * 0.28
            z_start = height * 0.32
            
        for c in range(n_clusters):
            cz = z_start + rnd.uniform(0.0, height * 0.5)
            spread = (height * 0.18) * (1.0 - (cz - z_start)/height)
            cx = rnd.uniform(-spread, spread)
            cy = rnd.uniform(-spread, spread)
            cr = cluster_base_r * rnd.uniform(0.7, 1.2)
            
            # Low-poly icosphere / dodecahedron cluster
            sub_bm = bmesh.new()
            bmesh.ops.create_icosphere(sub_bm, subdivisions=1, radius=cr)
            for v in sub_bm.verts:
                v.co.x += cx + rnd.uniform(-0.2, 0.2)
                v.co.y += cy + rnd.uniform(-0.2, 0.2)
                v.co.z += cz + rnd.uniform(-0.2, 0.2)
                # stretch canopy slightly vertically
                v.co.z *= 1.15
            
            # Merge into main bm
            temp_mesh = bpy.data.meshes.new("temp")
            sub_bm.to_mesh(temp_mesh)
            sub_bm.free()
            
            # Append verts/faces to main bm
            vert_offset = len(bm.verts)
            v_map = {}
            for v in temp_mesh.vertices:
                new_v = bm.verts.new(v.co)
                v_map[v.index] = new_v
            for p in temp_mesh.polygons:
                new_f = bm.faces.new([v_map[i] for i in p.vertices])
                new_f.material_index = 1 # foliage
                foliage_faces.append(new_f)
            bpy.data.meshes.remove(temp_mesh)

    # If notch cut exists, mark chop notch faces with cut wood material
    if stage > 0:
        for f in bm.faces:
            if f.material_index == 0:
                center = f.calc_center_median()
                if 0.75 <= center.z <= 1.25 and center.x > -0.1 and math.sqrt(center.x**2 + center.y**2) < r_base * 0.85:
                    f.material_index = 2 # cut wood material

    # Convert to Blender mesh & object
    mesh_name = f"Mesh_Tree_{species}_Stage_{stage}"
    mesh = bpy.data.meshes.new(mesh_name)
    bm.to_mesh(mesh)
    bm.free()
    
    # Assign materials
    mesh.materials.append(mat_bark)
    mesh.materials.append(mat_foliage)
    mesh.materials.append(mat_cut)
    
    # Low-poly faceted shading
    for poly in mesh.polygons:
        poly.use_smooth = False
        
    obj = bpy.data.objects.new(f"Tree_{species}_Stage_{stage}", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj

def build_tree_stump(species):
    """Generates tree stump (h = 0.6m)"""
    specs = {
        'birch': {'r': 0.24, 'bark': (0.88, 0.86, 0.82, 1.0), 'cut': (0.96, 0.96, 0.86, 1.0)},
        'spruce': {'r': 0.38, 'bark': (0.29, 0.22, 0.16, 1.0), 'cut': (0.82, 0.41, 0.12, 1.0)},
        'beech': {'r': 0.44, 'bark': (0.48, 0.49, 0.49, 1.0), 'cut': (0.93, 0.86, 0.51, 1.0)},
        'oak': {'r': 0.48, 'bark': (0.24, 0.15, 0.10, 1.0), 'cut': (0.55, 0.35, 0.17, 1.0)},
    }
    cfg = specs[species]
    mat_bark = create_pbr_material(f"M_Bark_Stump_{species}", cfg['bark'], roughness=0.85)
    mat_cut = create_pbr_material(f"M_Cut_Stump_{species}", cfg['cut'], roughness=0.6)
    
    bm = bmesh.new()
    r = cfg['r']
    n_seg = 10
    
    # Base ring at z=0 with root flare
    base_verts = []
    for s in range(n_seg):
        a = s * (2.0 * math.pi / n_seg)
        flare = 1.25 + 0.25 * math.sin(a * 4) # 4 root flares
        vx = r * flare * math.cos(a)
        vy = r * flare * math.sin(a)
        base_verts.append(bm.verts.new((vx, vy, 0.0)))
        
    # Top cut ring at z=0.6m
    top_verts = []
    for s in range(n_seg):
        a = s * (2.0 * math.pi / n_seg)
        # uneven cut surface
        cut_z = 0.58 + 0.05 * math.cos(a * 2)
        vx = r * 0.95 * math.cos(a)
        vy = r * 0.95 * math.sin(a)
        top_verts.append(bm.verts.new((vx, vy, cut_z)))
        
    # Side quads
    for s in range(n_seg):
        s_next = (s + 1) % n_seg
        f = bm.faces.new([base_verts[s], base_verts[s_next], top_verts[s_next], top_verts[s]])
        f.material_index = 0 # bark
        
    # Top face
    top_face = bm.faces.new(top_verts)
    top_face.material_index = 1 # cut wood
    
    # Bottom face
    bm.faces.new(list(reversed(base_verts)))
    
    mesh = bpy.data.meshes.new(f"Mesh_Stump_{species}")
    bm.to_mesh(mesh)
    bm.free()
    
    mesh.materials.append(mat_bark)
    mesh.materials.append(mat_cut)
    for p in mesh.polygons:
        p.use_smooth = False
        
    obj = bpy.data.objects.new(f"Stump_{species}", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj

def build_wood_log(species):
    """Generates pickable firewood log (len = 1.0m, r = 0.16m, split wedge)"""
    specs = {
        'birch': {'bark': (0.88, 0.86, 0.82, 1.0), 'cut': (0.96, 0.96, 0.86, 1.0)},
        'spruce': {'bark': (0.29, 0.22, 0.16, 1.0), 'cut': (0.82, 0.41, 0.12, 1.0)},
        'beech': {'bark': (0.48, 0.49, 0.49, 1.0), 'cut': (0.93, 0.86, 0.51, 1.0)},
        'oak': {'bark': (0.24, 0.15, 0.10, 1.0), 'cut': (0.55, 0.35, 0.17, 1.0)},
    }
    cfg = specs[species]
    mat_bark = create_pbr_material(f"M_Bark_Log_{species}", cfg['bark'], roughness=0.85)
    mat_cut = create_pbr_material(f"M_Cut_Log_{species}", cfg['cut'], roughness=0.6)
    
    bm = bmesh.new()
    length = 1.0
    r = 0.16
    
    # Half-cylinder split log
    n_seg = 6
    x_positions = [-length/2, length/2]
    
    rings = []
    for x in x_positions:
        ring = []
        # Center split edge
        ring.append(bm.verts.new((x, 0, 0)))
        for s in range(n_seg + 1):
            a = s * (math.pi / n_seg) # 0 to pi arc
            y = r * math.cos(a)
            z = r * math.sin(a)
            ring.append(bm.verts.new((x, y, z)))
        rings.append(ring)
        
    r0, r1 = rings[0], rings[1]
    
    # Bark curved surface
    for s in range(1, n_seg + 1):
        f = bm.faces.new([r0[s], r0[s+1], r1[s+1], r1[s]])
        f.material_index = 0 # bark
        
    # Split flat surface (bottom)
    f_split = bm.faces.new([r0[0], r1[0], r1[1], r0[1]])
    f_split.material_index = 1 # cut
    f_split2 = bm.faces.new([r0[n_seg + 1], r1[n_seg + 1], r1[0], r0[0]])
    f_split2.material_index = 1 # cut
    
    # End caps
    f_cap0 = bm.faces.new(list(reversed(r0)))
    f_cap0.material_index = 1 # cut
    f_cap1 = bm.faces.new(r1)
    f_cap1.material_index = 1 # cut
    
    mesh = bpy.data.meshes.new(f"Mesh_Log_{species}")
    bm.to_mesh(mesh)
    bm.free()
    
    mesh.materials.append(mat_bark)
    mesh.materials.append(mat_cut)
    for p in mesh.polygons:
        p.use_smooth = False
        
    obj = bpy.data.objects.new(f"Log_{species}", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj

# -------------------------------------------------------------
# 2. PROPS GENERATOR (Bushes, Boulders, Deadwood, Bridge, Axe)
# -------------------------------------------------------------

def build_bush(variant=1):
    """Low-poly bush variations"""
    colors = [
        (0.28, 0.48, 0.16, 1.0), # fresh green
        (0.35, 0.55, 0.22, 1.0), # lighter spring green
        (0.22, 0.40, 0.18, 1.0), # deep shrub green
        (0.40, 0.50, 0.20, 1.0)  # olive-yellowish green
    ]
    mat = create_pbr_material(f"M_Bush_{variant}", colors[variant - 1], roughness=0.75)
    
    bm = bmesh.new()
    rnd = random.Random(variant * 101)
    n_clumps = 3 + variant
    
    for c in range(n_clumps):
        cr = 0.5 + rnd.uniform(0.1, 0.4)
        cx = rnd.uniform(-0.5, 0.5)
        cy = rnd.uniform(-0.5, 0.5)
        cz = cr * 0.75 + rnd.uniform(0.0, 0.3)
        
        sub = bmesh.new()
        bmesh.ops.create_icosphere(sub, subdivisions=1, radius=cr)
        for v in sub.verts:
            v.co.x += cx
            v.co.y += cy
            v.co.z += cz
        
        temp_m = bpy.data.meshes.new("temp")
        sub.to_mesh(temp_m)
        sub.free()
        
        v_map = {}
        for v in temp_m.vertices:
            v_map[v.index] = bm.verts.new(v.co)
        for p in temp_m.polygons:
            bm.faces.new([v_map[i] for i in p.vertices])
        bpy.data.meshes.remove(temp_m)
        
    mesh = bpy.data.meshes.new(f"Mesh_Bush_{variant:02d}")
    bm.to_mesh(mesh)
    bm.free()
    
    mesh.materials.append(mat)
    for p in mesh.polygons:
        p.use_smooth = False
        
    obj = bpy.data.objects.new(f"Bush_{variant:02d}", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj

def build_boulder(variant=1):
    """Low-poly mossy granite boulders (1.0m to 3.0m scale)"""
    mat_stone = create_pbr_material(f"M_Boulder_{variant}", (0.38, 0.38, 0.36, 1.0), roughness=0.9)
    
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
    
    rnd = random.Random(variant * 777)
    scale_vec = Vector((
        1.0 + rnd.uniform(-0.3, 0.4),
        1.0 + rnd.uniform(-0.2, 0.3),
        0.7 + rnd.uniform(-0.2, 0.3)
    ))
    
    for v in bm.verts:
        v.co.x *= scale_vec.x
        v.co.y *= scale_vec.y
        v.co.z *= scale_vec.z
        # Faceted jagged displacement
        v.co += Vector((rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15)))
        # Flatten bottom slightly
        if v.co.z < 0.1:
            v.co.z *= 0.5
            
    mesh = bpy.data.meshes.new(f"Mesh_Boulder_{variant:02d}")
    bm.to_mesh(mesh)
    bm.free()
    
    mesh.materials.append(mat_stone)
    for p in mesh.polygons:
        p.use_smooth = False
        
    obj = bpy.data.objects.new(f"Boulder_{variant:02d}", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj

def build_deadwood_log():
    """Fallen deadwood log with broken branch stubs"""
    mat = create_pbr_material("M_Deadwood", (0.25, 0.20, 0.15, 1.0), roughness=0.92)
    bm = bmesh.new()
    
    length = 4.0
    r = 0.22
    n_seg = 8
    
    z_steps = [-length/2, -1.0, 0.5, length/2]
    prev_verts = []
    
    for z in z_steps:
        ring = []
        for s in range(n_seg):
            a = s * (2.0 * math.pi / n_seg)
            cur_r = r * (1.1 - (z + length/2)/(length + 1.0))
            vx = cur_r * math.cos(a) + (0.1 if abs(z) < 1.0 else 0.0)
            vy = cur_r * math.sin(a)
            vz = z
            ring.append(bm.verts.new((vx, vy, vz)))
        if prev_verts:
            for s in range(n_seg):
                s_next = (s + 1) % n_seg
                bm.faces.new([prev_verts[s], prev_verts[s_next], ring[s_next], ring[s]])
        else:
            bm.faces.new(list(reversed(ring)))
        prev_verts = ring
    bm.faces.new(prev_verts)
    
    # Orient horizontally along X axis
    for v in bm.verts:
        # Swap Y and Z so it lies flat on ground with base at z=0
        old_x, old_y, old_z = v.co.x, v.co.y, v.co.z
        v.co.x = old_z
        v.co.y = old_x
        v.co.z = old_y + r
        
    mesh = bpy.data.meshes.new("Mesh_Deadwood")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    for p in mesh.polygons:
        p.use_smooth = False
        
    obj = bpy.data.objects.new("Deadwood_Log", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj

def build_bridge_wood():
    """12m heavy timber bridge at BRIDGE POI (925, 37)"""
    mat_wood = create_pbr_material("M_Bridge_Wood", (0.35, 0.26, 0.18, 1.0), roughness=0.85)
    mat_iron = create_pbr_material("M_Bridge_Iron", (0.15, 0.15, 0.16, 1.0), roughness=0.6, metallic=0.7)
    
    bm = bmesh.new()
    length = 12.0
    width = 4.5
    
    # 3 Main longitudinal support beams
    beam_w = 0.4
    beam_h = 0.5
    beam_ys = [-width/2 + 0.4, 0.0, width/2 - 0.4]
    
    for by in beam_ys:
        bmesh.ops.create_cube(bm, size=1.0)
        # Transform the newly created cube vertices
        for v in bm.verts[-8:]:
            v.co.x *= length
            v.co.y *= beam_w
            v.co.z *= beam_h
            v.co.y += by
            v.co.z += -beam_h / 2
            
    # Deck Planks (30 planks across length)
    n_planks = 30
    plank_l = width + 0.4
    plank_w = length / n_planks * 0.92
    plank_h = 0.15
    
    for p in range(n_planks):
        px = -length/2 + (p + 0.5) * (length / n_planks)
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts[-8:]:
            v.co.x *= plank_w
            v.co.y *= plank_l
            v.co.z *= plank_h
            v.co.x += px
            v.co.z += plank_h / 2
            
    # Railings (Posts and Handrails on left & right)
    rail_h = 1.1
    for ry in [-width/2 - 0.1, width/2 + 0.1]:
        # Handrail beam
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts[-8:]:
            v.co.x *= length
            v.co.y *= 0.15
            v.co.z *= 0.15
            v.co.y += ry
            v.co.z += rail_h
            
        # 6 Posts along rail
        for post_i in range(6):
            post_x = -length/2 + post_i * (length / 5.0)
            bmesh.ops.create_cube(bm, size=1.0)
            for v in bm.verts[-8:]:
                v.co.x *= 0.18
                v.co.y *= 0.18
                v.co.z *= rail_h
                v.co.x += post_x
                v.co.y += ry
                v.co.z += rail_h / 2
                
    mesh = bpy.data.meshes.new("Mesh_Bridge_Wood")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat_wood)
    for p in mesh.polygons:
        p.use_smooth = False
        
    obj = bpy.data.objects.new("Bridge_Wood", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj

def build_survival_axe():
    """First-person survival woodcutter's axe"""
    mat_handle = create_pbr_material("M_Axe_Handle", (0.75, 0.60, 0.42, 1.0), roughness=0.6)
    mat_head = create_pbr_material("M_Axe_Iron", (0.22, 0.22, 0.24, 1.0), roughness=0.35, metallic=0.85)
    mat_edge = create_pbr_material("M_Axe_BladeEdge", (0.70, 0.72, 0.75, 1.0), roughness=0.2, metallic=0.95)
    
    bm = bmesh.new()
    
    # Handle: curved grip (length ~0.65m)
    h_len = 0.65
    n_h_seg = 8
    prev_h = []
    for i in range(n_h_seg):
        t = i / (n_h_seg - 1)
        z = t * h_len
        # subtle ergonomic S-curve
        y_curv = 0.03 * math.sin(t * math.pi * 1.5)
        w = 0.024 * (1.1 - 0.2 * t)
        d = 0.040 * (1.1 - 0.2 * t)
        
        # 4 verts for rectangular rounded cross-section
        v0 = bm.verts.new((-w/2, y_curv - d/2, z))
        v1 = bm.verts.new((w/2, y_curv - d/2, z))
        v2 = bm.verts.new((w/2, y_curv + d/2, z))
        v3 = bm.verts.new((-w/2, y_curv + d/2, z))
        ring = [v0, v1, v2, v3]
        if prev_h:
            for s in range(4):
                s_next = (s + 1) % 4
                f = bm.faces.new([prev_h[s], prev_h[s_next], ring[s_next], ring[s]])
                f.material_index = 0 # handle
        else:
            bm.faces.new(list(reversed(ring)))
        prev_h = ring
    bm.faces.new(prev_h)
    
    # Axe Head: forged iron head at top of handle
    head_z = h_len * 0.92
    # Eye collar
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts[-8:]:
        v.co.x *= 0.05
        v.co.y *= 0.12
        v.co.z *= 0.08
        v.co.z += head_z
    for f in bm.faces[-6:]:
        f.material_index = 1 # iron
        
    # Blade wedge pointing forward (+Y)
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts[-8:]:
        v.co.x *= 0.025 if v.co.y > 0 else 0.045
        v.co.y *= 0.14
        v.co.z *= (0.16 if v.co.y > 0 else 0.09) # flares out towards blade edge
        v.co.y += 0.10
        v.co.z += head_z
    for f in bm.faces[-6:]:
        f.material_index = 2 if any(v.co.y > 0.16 for v in f.verts) else 1
        
    mesh = bpy.data.meshes.new("Mesh_Axe")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat_handle)
    mesh.materials.append(mat_head)
    mesh.materials.append(mat_edge)
    for p in mesh.polygons:
        p.use_smooth = False
        
    obj = bpy.data.objects.new("Axe_Iron", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj

# -------------------------------------------------------------
# 3. MINE ASSETS (Portal, Frame, Cart, Rails, Rubble, Crate, Barrel)
# -------------------------------------------------------------

def build_mine_portal():
    """Portal at MINE_ADIT (3.0m wide x 2.6m high timber arch with stone facade)"""
    mat_timber = create_pbr_material("M_Mine_Timber", (0.30, 0.22, 0.14, 1.0), roughness=0.88)
    mat_stone = create_pbr_material("M_Mine_Stone", (0.32, 0.30, 0.28, 1.0), roughness=0.95)
    
    bm = bmesh.new()
    w = 3.0
    h = 2.6
    t_size = 0.35 # timber thickness
    
    # Left post
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts[-8:]:
        v.co.x *= t_size
        v.co.y *= t_size
        v.co.z *= h
        v.co.x -= (w/2 - t_size/2)
        v.co.z += h/2
    for f in bm.faces[-6:]:
        f.material_index = 0
        
    # Right post
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts[-8:]:
        v.co.x *= t_size
        v.co.y *= t_size
        v.co.z *= h
        v.co.x += (w/2 - t_size/2)
        v.co.z += h/2
    for f in bm.faces[-6:]:
        f.material_index = 0
        
    # Top beam
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts[-8:]:
        v.co.x *= (w + 0.6)
        v.co.y *= t_size * 1.1
        v.co.z *= t_size
        v.co.z += (h - t_size/2)
    for f in bm.faces[-6:]:
        f.material_index = 0
        
    # Corner braces
    for side in [-1, 1]:
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts[-8:]:
            v.co.x *= 0.6
            v.co.y *= t_size * 0.7
            v.co.z *= 0.18
            # angle brace
            v.co.x += side * (w/2 - 0.5)
            v.co.z += (h - 0.5)
        for f in bm.faces[-6:]:
            f.material_index = 0
            
    # Stone retaining walls flanking the entrance
    for side in [-1, 1]:
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts[-8:]:
            v.co.x *= 1.2
            v.co.y *= 1.8
            v.co.z *= (h + 0.8)
            v.co.x += side * (w/2 + 0.9)
            v.co.y -= 0.5
            v.co.z += (h + 0.8)/2
        for f in bm.faces[-6:]:
            f.material_index = 1
            
    # Overhead rock lintel
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts[-8:]:
        v.co.x *= (w + 2.5)
        v.co.y *= 1.5
        v.co.z *= 1.4
        v.co.y -= 0.4
        v.co.z += (h + 0.7)
    for f in bm.faces[-6:]:
        f.material_index = 1
        
    mesh = bpy.data.meshes.new("Mesh_Mine_Portal")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat_timber)
    mesh.materials.append(mat_stone)
    for p in mesh.polygons:
        p.use_smooth = False
        
    obj = bpy.data.objects.new("Mine_Portal", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj

def build_mine_frame():
    """Tunnel support arch (2.6m wide x 2.4m high)"""
    mat_timber = create_pbr_material("M_Mine_Frame", (0.33, 0.24, 0.16, 1.0), roughness=0.9)
    bm = bmesh.new()
    
    w = 2.6
    h = 2.4
    t = 0.22
    
    # Left post (slightly inclined inward at 3 degrees)
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts[-8:]:
        v.co.x *= t
        v.co.y *= t
        v.co.z *= h
        v.co.x -= (w/2 - t/2 - v.co.z * 0.05)
        v.co.z += h/2
        
    # Right post
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts[-8:]:
        v.co.x *= t
        v.co.y *= t
        v.co.z *= h
        v.co.x += (w/2 - t/2 - v.co.z * 0.05)
        v.co.z += h/2
        
    # Crossbeam lintel
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts[-8:]:
        v.co.x *= (w + 0.2)
        v.co.y *= t
        v.co.z *= t
        v.co.z += (h - t/2)
        
    mesh = bpy.data.meshes.new("Mesh_Mine_Frame")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat_timber)
    for p in mesh.polygons:
        p.use_smooth = False
        
    obj = bpy.data.objects.new("Mine_Frame", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj

def build_mine_rails():
    """3.0m track segment with 0.6m gauge and wooden ties"""
    mat_rail = create_pbr_material("M_Mine_Rail", (0.28, 0.26, 0.25, 1.0), roughness=0.4, metallic=0.8)
    mat_tie = create_pbr_material("M_Mine_Tie", (0.25, 0.18, 0.12, 1.0), roughness=0.9)
    
    bm = bmesh.new()
    length = 3.0
    gauge = 0.6
    
    # 2 Steel rails
    for rx in [-gauge/2, gauge/2]:
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts[-8:]:
            v.co.x *= 0.06
            v.co.y *= length
            v.co.z *= 0.08
            v.co.x += rx
            v.co.z += 0.10
        for f in bm.faces[-6:]:
            f.material_index = 0 # rail
            
    # 5 Wooden ties (sleepers)
    n_ties = 5
    for ti in range(n_ties):
        ty = -length/2 + (ti + 0.5) * (length / n_ties)
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts[-8:]:
            v.co.x *= 1.0
            v.co.y *= 0.18
            v.co.z *= 0.08
            v.co.y += ty
            v.co.z += 0.04
        for f in bm.faces[-6:]:
            f.material_index = 1 # tie
            
    mesh = bpy.data.meshes.new("Mesh_Mine_Rails")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat_rail)
    mesh.materials.append(mat_tie)
    for p in mesh.polygons:
        p.use_smooth = False
        
    obj = bpy.data.objects.new("Mine_Rails", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj

def build_mine_cart():
    """Rusty ore mining cart on iron flanged wheels"""
    mat_metal = create_pbr_material("M_Cart_Metal", (0.45, 0.25, 0.18, 1.0), roughness=0.7, metallic=0.6) # rusty iron
    mat_ore = create_pbr_material("M_Cart_Ore", (0.22, 0.20, 0.19, 1.0), roughness=0.95)
    
    bm = bmesh.new()
    
    # Cart body (tapered bucket)
    w_top, w_bot = 0.95, 0.70
    l_top, l_bot = 1.35, 1.05
    h_bucket = 0.65
    z_base = 0.25
    
    # Bucket outer shell
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts[-8:]:
        v.co.x *= (w_top if v.co.z > 0 else w_bot)
        v.co.y *= (l_top if v.co.z > 0 else l_bot)
        v.co.z *= h_bucket
        v.co.z += z_base + h_bucket/2
    for f in bm.faces[-6:]:
        f.material_index = 0
        
    # Ore contents inside
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts[-8:]:
        v.co.x *= w_top * 0.85
        v.co.y *= l_top * 0.85
        v.co.z *= 0.25
        v.co.z += z_base + h_bucket * 0.8
    for f in bm.faces[-6:]:
        f.material_index = 1 # ore
        
    # 4 Wheels
    wheel_r = 0.16
    wheel_w = 0.08
    wheel_xs = [-0.30, 0.30]
    wheel_ys = [-0.42, 0.42]
    
    for wx in wheel_xs:
        for wy in wheel_ys:
            bmesh.ops.create_cube(bm, size=1.0)
            for v in bm.verts[-8:]:
                v.co.x *= wheel_w
                v.co.y *= wheel_r * 2
                v.co.z *= wheel_r * 2
                v.co.x += wx
                v.co.y += wy
                v.co.z += wheel_r
            for f in bm.faces[-6:]:
                f.material_index = 0
                
    mesh = bpy.data.meshes.new("Mesh_Mine_Cart")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat_metal)
    mesh.materials.append(mat_ore)
    for p in mesh.polygons:
        p.use_smooth = False
        
    obj = bpy.data.objects.new("Mine_Cart", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj

def build_mine_crate():
    """Wooden supply crate (0.8 x 0.8 x 0.8m)"""
    mat = create_pbr_material("M_Crate_Wood", (0.42, 0.32, 0.22, 1.0), roughness=0.85)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=0.8)
    for v in bm.verts:
        v.co.z += 0.4
    mesh = bpy.data.meshes.new("Mesh_Crate")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    for p in mesh.polygons:
        p.use_smooth = False
    obj = bpy.data.objects.new("Mine_Crate", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj

def build_mine_barrel():
    """Wooden barrel with iron bands (r=0.35m, h=0.9m)"""
    mat_wood = create_pbr_material("M_Barrel_Wood", (0.38, 0.28, 0.18, 1.0), roughness=0.8)
    mat_iron = create_pbr_material("M_Barrel_Iron", (0.18, 0.18, 0.18, 1.0), roughness=0.5, metallic=0.8)
    
    bm = bmesh.new()
    n_seg = 10
    levels = [
        (0.0, 0.30),
        (0.2, 0.36),
        (0.45, 0.38),
        (0.7, 0.36),
        (0.9, 0.30)
    ]
    prev = []
    for z, r in levels:
        ring = []
        for s in range(n_seg):
            a = s * (2.0 * math.pi / n_seg)
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        if prev:
            for s in range(n_seg):
                s_next = (s + 1) % n_seg
                f = bm.faces.new([prev[s], prev[s_next], ring[s_next], ring[s]])
                f.material_index = 0
        else:
            bm.faces.new(list(reversed(ring)))
        prev = ring
    bm.faces.new(prev)
    
    mesh = bpy.data.meshes.new("Mesh_Barrel")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat_wood)
    mesh.materials.append(mat_iron)
    for p in mesh.polygons:
        p.use_smooth = False
    obj = bpy.data.objects.new("Mine_Barrel", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj

def build_mine_rubble():
    """Rock and timber rubble pile for caved-in hall"""
    mat_stone = create_pbr_material("M_Rubble_Stone", (0.35, 0.33, 0.32, 1.0), roughness=0.95)
    mat_wood = create_pbr_material("M_Rubble_Wood", (0.28, 0.20, 0.14, 1.0), roughness=0.9)
    
    bm = bmesh.new()
    rnd = random.Random(404)
    
    # 12 Fallen jagged boulders
    for i in range(12):
        sub = bmesh.new()
        bmesh.ops.create_icosphere(sub, subdivisions=1, radius=rnd.uniform(0.3, 0.9))
        dx = rnd.uniform(-2.5, 2.5)
        dy = rnd.uniform(-2.0, 2.0)
        dz = rnd.uniform(0.1, 1.2)
        for v in sub.verts:
            v.co += Vector((dx, dy, dz))
        temp_m = bpy.data.meshes.new("temp")
        sub.to_mesh(temp_m)
        sub.free()
        v_map = {}
        for v in temp_m.vertices:
            v_map[v.index] = bm.verts.new(v.co)
        for p in temp_m.polygons:
            f = bm.faces.new([v_map[idx] for idx in p.vertices])
            f.material_index = 0 # stone
        bpy.data.meshes.remove(temp_m)
        
    # 4 Shattered timber splinters
    for i in range(4):
        bmesh.ops.create_cube(bm, size=1.0)
        ang = rnd.uniform(0, math.pi)
        tx = rnd.uniform(-1.5, 1.5)
        ty = rnd.uniform(-1.5, 1.5)
        for v in bm.verts[-8:]:
            v.co.x *= 0.2
            v.co.y *= 2.0
            v.co.z *= 0.2
            v.co.rotate(Euler((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), ang)))
            v.co.x += tx
            v.co.y += ty
            v.co.z += 0.4
        for f in bm.faces[-6:]:
            f.material_index = 1 # wood
            
    mesh = bpy.data.meshes.new("Mesh_Rubble")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat_stone)
    mesh.materials.append(mat_wood)
    for p in mesh.polygons:
        p.use_smooth = False
    obj = bpy.data.objects.new("Mine_Rubble", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


# -------------------------------------------------------------
# MAIN EXPORT ROUTINE
# -------------------------------------------------------------

def main():
    print("=" * 60)
    print("STARTING 3D ASSET GENERATION & glTF EXPORT")
    print("=" * 60)
    
    species_list = ['birch', 'spruce', 'beech', 'oak']
    
    # 1. Trees: Full tree, 4 chop stages, Stump, Log
    for sp in species_list:
        print(f"\n--- Generating Tree Assets: {sp.upper()} ---")
        # Full tree (Stage 0)
        clear_scene()
        obj = build_tree_mesh(sp, stage=0)
        export_glb(os.path.join(TREES_DIR, f"tree_{sp}.glb"), [obj])
        
        # 4 Chop Stages (0, 1, 2, 3)
        for st in range(4):
            clear_scene()
            obj = build_tree_mesh(sp, stage=st)
            export_glb(os.path.join(TREES_DIR, f"tree_{sp}_stage_{st}.glb"), [obj])
            
        # Stump
        clear_scene()
        stump = build_tree_stump(sp)
        export_glb(os.path.join(TREES_DIR, f"tree_{sp}_stump.glb"), [stump])
        
        # Log
        clear_scene()
        log = build_wood_log(sp)
        export_glb(os.path.join(TREES_DIR, f"tree_{sp}_log.glb"), [log])
        
    # 2. Props
    print("\n--- Generating Props Assets ---")
    for b_idx in range(1, 5):
        clear_scene()
        bush = build_bush(b_idx)
        export_glb(os.path.join(PROPS_DIR, f"bush_{b_idx:02d}.glb"), [bush])
        
    for r_idx in range(1, 5):
        clear_scene()
        boulder = build_boulder(r_idx)
        export_glb(os.path.join(PROPS_DIR, f"boulder_{r_idx:02d}.glb"), [boulder])
        
    clear_scene()
    deadwood = build_deadwood_log()
    export_glb(os.path.join(PROPS_DIR, "deadwood_log.glb"), [deadwood])
    
    clear_scene()
    bridge = build_bridge_wood()
    export_glb(os.path.join(PROPS_DIR, "bridge_wood.glb"), [bridge])
    
    clear_scene()
    axe = build_survival_axe()
    export_glb(os.path.join(PROPS_DIR, "axe_iron.glb"), [axe])
    
    # 3. Mine
    print("\n--- Generating Mine Assets ---")
    clear_scene()
    portal = build_mine_portal()
    export_glb(os.path.join(MINE_DIR, "mine_portal.glb"), [portal])
    
    clear_scene()
    frame = build_mine_frame()
    export_glb(os.path.join(MINE_DIR, "mine_frame.glb"), [frame])
    
    clear_scene()
    rails = build_mine_rails()
    export_glb(os.path.join(MINE_DIR, "mine_rails.glb"), [rails])
    
    clear_scene()
    cart = build_mine_cart()
    export_glb(os.path.join(MINE_DIR, "mine_cart.glb"), [cart])
    
    clear_scene()
    crate = build_mine_crate()
    export_glb(os.path.join(MINE_DIR, "mine_crate.glb"), [crate])
    
    clear_scene()
    barrel = build_mine_barrel()
    export_glb(os.path.join(MINE_DIR, "mine_barrel.glb"), [barrel])
    
    clear_scene()
    rubble = build_mine_rubble()
    export_glb(os.path.join(MINE_DIR, "mine_rubble.glb"), [rubble])
    
    print("\n" + "=" * 60)
    print("ALL 3D ASSETS SUCCESSFULLY GENERATED & EXPORTED!")
    print("=" * 60)

if __name__ == "__main__":
    main()
