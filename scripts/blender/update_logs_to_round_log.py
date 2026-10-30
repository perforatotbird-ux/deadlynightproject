"""
update_logs_to_round_log.py
Regenerates round log (бревно) assets for all 4 species for Deadly Night
"""
import bpy
import bmesh
import math
import os

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TREES_DIR = os.path.join(PROJECT_ROOT, "assets", "models", "trees")

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
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

def build_round_log(species):
    """Generates authentic round log (бревно) cylinder (len = 1.0m, r = 0.18m)"""
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
    r = 0.18
    n_seg = 12
    
    # Cylinder oriented along Z axis
    z_positions = [-length / 2.0, length / 2.0]
    rings = []
    for z in z_positions:
        ring = []
        for s in range(n_seg):
            a = s * (2.0 * math.pi / n_seg)
            x = r * math.cos(a)
            y = r * math.sin(a)
            ring.append(bm.verts.new((x, y, z)))
        rings.append(ring)
        
    r0, r1 = rings[0], rings[1]
    
    # Bark cylindrical side faces
    for s in range(n_seg):
        s_next = (s + 1) % n_seg
        f = bm.faces.new([r0[s], r0[s_next], r1[s_next], r1[s]])
        f.material_index = 0 # Bark
        f.smooth = True
        
    # Flat cut end caps
    f_cap0 = bm.faces.new(list(reversed(r0)))
    f_cap0.material_index = 1 # Cut wood
    f_cap0.smooth = False
    
    f_cap1 = bm.faces.new(r1)
    f_cap1.material_index = 1 # Cut wood
    f_cap1.smooth = False
    
    mesh = bpy.data.meshes.new(f"Mesh_Log_{species}")
    bm.to_mesh(mesh)
    bm.free()
    
    mesh.materials.append(mat_bark)
    mesh.materials.append(mat_cut)
    
    obj = bpy.data.objects.new(f"Log_{species}", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj

def main():
    for sp in ['birch', 'spruce', 'beech', 'oak']:
        clear_scene()
        log_obj = build_round_log(sp)
        out_path = os.path.join(TREES_DIR, f"tree_{sp}_log.glb")
        export_glb(out_path, [log_obj])
    print("ALL ROUND LOG ASSETS EXPORTED SUCCESSFULLY!")

if __name__ == "__main__":
    main()
