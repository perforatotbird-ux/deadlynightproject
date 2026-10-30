"""Original procedural ambience; no samples or third-party recordings. Reproducible."""
from pathlib import Path
import random, math, wave, struct
ROOT=Path(__file__).resolve().parents[2]/'assets/sounds/survival'
SR=16000; N=SR*8
for name, seed in [('rain_loop',431),('fire_loop',903),('night_loop',127)]:
 r=random.Random(seed); samples=[]; low=0.; pop=0.
 for i in range(N):
  noise=r.uniform(-1,1);low=low*.975+noise*.025
  if name=='rain_loop':v=.2*noise+.45*low
  elif name=='fire_loop':
   if r.random()<.0018:pop=r.uniform(.12,.6)
   pop*=.96;v=.55*low+noise*pop+.025*noise
  else:v=low*.8+.018*math.sin(2*math.pi*83*i/SR)*(0.5+0.5*math.sin(2*math.pi*i/N))
  samples.append(v)
 # Circular seam bridge; the body remains stochastic, not an obvious pulse.
 blend=SR//8
 for j in range(blend):
  t=j/blend;samples[N-blend+j]=samples[N-blend+j]*(1-t)+samples[j]*t
 with wave.open(str(ROOT/(name+'.wav')),'wb') as w:
  w.setparams((1,2,SR,0,'NONE','not compressed'))
  w.writeframes(b''.join(struct.pack('<h',max(-32767,min(32767,int(v*32767)))) for v in samples))
