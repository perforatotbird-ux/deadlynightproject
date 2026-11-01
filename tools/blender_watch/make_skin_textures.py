"""Reproduce the original, non-photographic tiling skin maps. Python + numpy + Pillow."""
from PIL import Image,ImageFilter
import numpy as np
from pathlib import Path
p=Path(__file__).resolve().parents[2]/'assets/models/viewmodels/watch';p.mkdir(parents=True,exist_ok=True)
r=np.random.default_rng(1942);n=512
broad=np.asarray(Image.fromarray(r.integers(0,255,(32,32),dtype=np.uint8)).resize((n,n),Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(12)),dtype=float)/255-.5
grain=r.normal(0,1,(n,n));v=grain*1.3+broad*13
rgb=np.clip(np.array([180,132,108])[None,None,:]+v[:,:,None]*np.array([1,.65,.5]),0,255).astype('uint8')
Image.fromarray(rgb).save(p/'skin_albedo.png')
h=r.normal(0,1,(n,n));h=np.asarray(Image.fromarray(np.uint8(np.clip(h*30+128,0,255))).filter(ImageFilter.GaussianBlur(.6)),float)/255
ny,nx=np.gradient(h);normal=np.stack([-nx*.9,-ny*.9,np.ones_like(h)],axis=-1);normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
Image.fromarray(np.uint8((normal*.5+.5)*255)).save(p/'skin_normal.png')
