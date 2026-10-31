"""Conservative 512² mask from the project's authored terrain masks.
R = roads/paths, G = rivers/creek. Max pooling preserves narrow exclusions.
Coordinates: x in [-2000,2000], Godot z in [-2000,2000], image row increases +z.
"""
from pathlib import Path
import hashlib, json
import numpy as np
from PIL import Image
root=Path(__file__).resolve().parents[2]
sources=['road_mask','path_mask','river_mask','creek_mask']
layers={name:np.array(Image.open(root/'data/masks'/f'{name}.png').convert('L')) for name in sources}
def downsample(a):
    h,w=a.shape
    assert h==w==4096
    return a.reshape(512,8,512,8).max(axis=(1,3))
roads=downsample(np.maximum(layers['road_mask'],layers['path_mask']))
water=downsample(np.maximum(layers['river_mask'],layers['creek_mask']))
output=root/'assets/models/vegetation'
output.mkdir(parents=True,exist_ok=True)
Image.fromarray(np.dstack([roads,water,np.zeros_like(roads)])).save(output/'foraging_exclusions.png')
manifest={'generator':'scripts/art/build_foraging_exclusions.py','size':[512,512],'pooling':'8x8 maximum','mapping':'col=(game_x+2000)/4000*512, row=(game_z+2000)/4000*512','sources':{str((root/'data/masks'/f'{name}.png').relative_to(root)):hashlib.sha256((root/'data/masks'/f'{name}.png').read_bytes()).hexdigest() for name in sources}}
(output/'foraging_exclusions.json').write_text(json.dumps(manifest,indent=2)+'\n')
