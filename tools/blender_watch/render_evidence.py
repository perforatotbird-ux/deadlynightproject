"""Reproduce bounded Cycles CPU source renders, including palm-side review."""
import bpy,json,time
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/source/watch/left_arm_round_watch.blend'))
out=ROOT/'art/source/watch/qa';out.mkdir(exist_ok=True)
s=bpy.context.scene;s.render.resolution_x=800;s.render.resolution_y=500;s.render.resolution_percentage=100;s.cycles.samples=16
shots=[]
for name in ['HeroCamera','Diagnostic_Front','Diagnostic_Back','Diagnostic_Left','Diagnostic_Right','Diagnostic_Top']:
 cam=bpy.data.objects[name]
 if name.startswith('Diagnostic_'):
  target=Vector((-.14,0,0));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.96 if name=='Diagnostic_Top' else .67
 s.camera=cam;s.render.filepath=str(out/(name+'.png'));t=time.monotonic();bpy.ops.render.render(write_still=True);shots.append({'camera':name,'file':s.render.filepath,'seconds':round(time.monotonic()-t,2)})
# Close wrist/hand hero, preserving the same final mesh and material state.
cam=bpy.data.objects['HeroCamera'];cam.location=(.10,-.38,.115);target=Vector((.004,-.01,0));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=60
s.camera=cam;s.render.resolution_x=1100;s.render.resolution_y=720;s.cycles.samples=32;s.render.filepath=str(out/'watch_closeup.png');bpy.ops.render.render(write_still=True)
shots.append({'camera':'HeroCamera closeup','file':s.render.filepath})
# Palm-side detail verifies the folded digits and actual band contact.
s.render.resolution_x=800;s.render.resolution_y=500;s.cycles.samples=16
cam.location=(.13,.36,-.08);target=Vector((.045,0,0));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=56
s.render.filepath=str(out/'palm_detail.png');bpy.ops.render.render(write_still=True);shots.append({'camera':'palm detail','file':s.render.filepath})
(out/'render-manifest.json').write_text(json.dumps({'blender':bpy.app.version_string,'engine':'Cycles CPU','samples_diagnostic':16,'samples_hero':32,'color_management':'AgX','images':shots},indent=2))
print('DN_FINAL_EVIDENCE',len(shots))
