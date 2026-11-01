"""Launch with Blender's --python; use a GUI or Xvfb, never --background."""
import os,importlib.util
import bpy
os.environ['BLENDER_MCP_DISABLE_TELEMETRY']='true'
path=os.environ.get('BLENDER_MCP_ADDON')
if not path:raise RuntimeError('Set BLENDER_MCP_ADDON to the installed ahujasid/blender-mcp addon.py')
spec=importlib.util.spec_from_file_location('dn_blender_mcp',path)
addon=importlib.util.module_from_spec(spec);spec.loader.exec_module(addon);addon.register()
for name in ['blendermcp_use_polyhaven','blendermcp_use_hyper3d','blendermcp_use_sketchfab','blendermcp_use_hunyuan3d']:
 if hasattr(bpy.context.scene,name):setattr(bpy.context.scene,name,False)
bridge=addon.BlenderMCPServer(host='127.0.0.1',port=int(os.environ.get('BLENDER_PORT','9876')));bridge.start()
if not bridge.running:raise RuntimeError('The Blender MCP bridge did not start')
print('DN_MCP_READY / loopback only / external generation disabled',flush=True)
