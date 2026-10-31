"""Reproduce PNG icons from the original AI-painted atlases; no redraw.
Run from any directory. Chroma-key isolation preserves painted materials.
"""
from pathlib import Path
from collections import deque
import json,hashlib
import numpy as np
from PIL import Image,ImageFilter
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'assets/ui/field_journal/source/painted_refresh'
DEST=ROOT/'assets/ui/field_journal/icons'
SHEETS={
 'supplies_and_botany.jpg':['water','raw_water','ration','berries','bandage','compress','antitoxin','field_notes','krasnitsa','sizovka','bolotnitsa','forest_fat','wood_fan','copper_false','pale_bell','stump_fan'],
 'cooked_and_navigation.jpg':['cooked_forest_fat','cooked_wood_fan','cooked_copper_false','cooked_pale_bell','wood_tea','difficulty_explorer','difficulty_traveler','difficulty_survivor','difficulty_custom','category_all','category_resources','category_fuel','category_equipment','category_food','category_medicine','category_tools']}
def isolate(im):
 a=np.array(im.convert('RGB')).astype(float);h,w,_=a.shape
 border=np.concatenate([a[:4].reshape(-1,3),a[-4:].reshape(-1,3),a[:,:4].reshape(-1,3),a[:,-4:].reshape(-1,3)])
 bg=np.median(border,axis=0);distance=np.linalg.norm(a-bg,axis=2)
 # Flood only the near-background field, not dark shading enclosed inside art.
 candidate=distance<12;outside=np.zeros((h,w),bool);todo=deque()
 for x in range(w):
  for y in (0,h-1):
   if candidate[y,x] and not outside[y,x]:outside[y,x]=True;todo.append((y,x))
 for y in range(h):
  for x in (0,w-1):
   if candidate[y,x] and not outside[y,x]:outside[y,x]=True;todo.append((y,x))
 while todo:
  y,x=todo.popleft()
  for yy,xx in ((y-1,x),(y+1,x),(y,x-1),(y,x+1)):
   if 0<=yy<h and 0<=xx<w and candidate[yy,xx] and not outside[yy,xx]:outside[yy,xx]=True;todo.append((yy,xx))
 # Strict key also clears isolated background holes (gear hub/cup handle).
 outside|=distance<10
 mask=np.where(outside,0,255).astype('uint8')
 alpha=Image.fromarray(mask).filter(ImageFilter.GaussianBlur(0.3))
 out=im.convert('RGBA');out.putalpha(alpha)
 box=alpha.getbbox()
 if box is None:raise ValueError('Empty extracted icon')
 out=out.crop(box)
 scale=min(264/out.width,264/out.height)
 out=out.resize((round(out.width*scale),round(out.height*scale)),Image.Resampling.LANCZOS)
 canvas=Image.new('RGBA',(320,320));canvas.alpha_composite(out,((320-out.width)//2,(320-out.height)//2))
 return canvas

def main():
 manifest={'version':1,'art_direction':'Original AI-painted field-journal objects, matching existing Deadly Night tool art. No text, brands or third-party game assets.','size':[320,320],'sheets':{},'icons':{}}
 for sheet,ids in SHEETS.items():
  path=SOURCE/sheet;im=Image.open(path).convert('RGB');w,h=im.size
  manifest['sheets'][sheet]={'size':[w,h],'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
  for index,key in enumerate(ids):
   c=index%4;r=index//4
   # The second generated sheet has intentionally measured, unequal row
   # gutters. Do not assume requested aspect/grid was obeyed by the model.
   rows=[0,250,500,705,896] if sheet=='cooked_and_navigation.jpg' else [0,256,512,768,1024]
   box=(round(c*w/4),rows[r],round((c+1)*w/4),rows[r+1])
   icon=isolate(im.crop(box));target=DEST/(key+'.png');icon.save(target,optimize=True)
   manifest['icons'][key]={'sheet':sheet,'cell':index,'crop':list(box),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
 (SOURCE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('Extracted',len(manifest['icons']),'transparent painted icons')
if __name__=='__main__':main()
