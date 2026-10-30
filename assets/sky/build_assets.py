from PIL import Image,ImageDraw,ImageFilter,ImageOps
import math,random,numpy as np
from pathlib import Path
p=Path(__file__).resolve().parent
# Stable equal-area spherical sources projected analytically onto a cubemap.
# No equirectangular polar singularity or stretched stars near the celestial pole.
w,h=4096,2048;rng=random.Random(41873);records=[]
for i in range(6200):
 lon=rng.random()*math.tau;z=rng.uniform(-1,1);r=math.sqrt(1-z*z)
 direction=np.array([r*math.cos(lon),r*math.sin(lon),z])
 strength=rng.choices([.12,.28,.62,1.0],[64,26,8,2])[0]
 tint=np.array(rng.choice([(1,1,1),(.83,.91,1),(1,.94,.8),(1,.85,.68)]))
 records.append((direction,strength,tint))
faces=[('px',(1,0,0),(0,0,-1),(0,-1,0)),('nx',(-1,0,0),(0,0,1),(0,-1,0)),('py',(0,1,0),(1,0,0),(0,0,1)),('ny',(0,-1,0),(1,0,0),(0,0,-1)),('pz',(0,0,1),(1,0,0),(0,-1,0)),('nz',(0,0,-1),(-1,0,0),(0,-1,0))]
size=1024
for name,nn,rr,dd in faces:
 n=np.array(nn);right=np.array(rr);down=np.array(dd);a=np.zeros((size,size,3),np.float32)
 for direction,strength,tint in records:
  facing=np.dot(direction,n)
  if facing<.55:continue
  u=np.dot(direction,right)/facing;v=np.dot(direction,down)/facing
  if abs(u)>1.015 or abs(v)>1.015:continue
  x=(u+1)*size/2-.5;y=(v+1)*size/2-.5
  sigma=.00085 if strength<.5 else .0012
  radius=5
  xmin=max(0,int(x)-radius);xmax=min(size,int(x)+radius+1);ymin=max(0,int(y)-radius);ymax=min(size,int(y)+radius+1)
  if xmax<=xmin or ymax<=ymin:continue
  yy,xx=np.mgrid[ymin:ymax,xmin:xmax]
  dirs=n[None,None,:]+right[None,None,:]*((xx+.5)*2/size-1)[...,None]+down[None,None,:]*((yy+.5)*2/size-1)[...,None]
  dirs/=np.linalg.norm(dirs,axis=2)[...,None]
  dist2=np.sum((dirs-direction)**2,axis=2)
  a[ymin:ymax,xmin:xmax]+=np.exp(-dist2/(2*sigma*sigma))[...,None]*strength*tint
 Image.fromarray(np.uint8(np.clip(a,0,1)*255)).save(p/('stars_'+name+'.png'))
# Generated MW isn't an equirectangular panorama. Reproject as subtle equatorial band,
# fade to zero at both poles and blend its x edges before spherical use.
src=Image.open(p/'source/milky_way_generated.jpg').resize((w,h)).convert('RGB'); b=np.asarray(src).astype(float)/255
edge=180
for x in range(edge):
 t=(x+.5)/edge;q=(b[:,x].copy()+b[:,-1-x].copy())*.5
 b[:,x]=q*(1-t)+b[:,x]*t;b[:,-1-x]=q*(1-t)+b[:,-1-x]*t
fade=np.sin(np.linspace(0,math.pi,h))**5
b*=fade[:,None,None];Image.fromarray(np.uint8(np.clip(b,0,1)*255)).save(p/'milky_way.png')
Image.open(p/'source/moon_generated.jpg').resize((512,512)).save(p/'moon.png')

for name in ["milky_way"]:
 im=Image.open(p/(name+".png"));im.resize((1024,512),Image.Resampling.LANCZOS).save(p/(name+"_low.png"))
