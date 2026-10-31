"""Original quiet wildlife/foley synthesis. No downloaded audio. Reproducible."""
from pathlib import Path
import numpy as np, wave
OUT=Path(__file__).resolve().parents[2]/'assets/sounds/woodland';OUT.mkdir(parents=True,exist_ok=True)
SR=22050;rng=np.random.default_rng(7019)
def save(name,a):
 a=np.asarray(a);a-=a.mean();peak=max(abs(a).max(),1e-9)
 a=a*(.65/peak) if peak>.65 else a
 with wave.open(str(OUT/(name+'.wav')),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes((a*32767).astype('<i2').tobytes())
def chirp(a,start,duration,f0,f1,amp=.35):
 t=np.arange(int(duration*SR))/SR;u=t/duration
 phase=2*np.pi*(f0*t+(f1-f0)*t*t/(2*duration)+35*np.sin(2*np.pi*13*t)/(2*np.pi*13))
 x=(np.sin(phase)+.12*np.sin(2*phase))*(np.sin(np.pi*u)**1.7)*amp
 n=int(start*SR);a[n:n+len(x)]+=x[:len(a)-n]
for k in range(3):
 a=np.zeros(int(2.8*SR));start=.18
 for i in range(6+k):
  dur=rng.uniform(.065,.18);chirp(a,start,dur,rng.uniform(2200,3900),rng.uniform(1600,4200),rng.uniform(.16,.32));start+=dur+rng.uniform(.04,.16)
 save('bird_'+str(k+1),a)
a=np.zeros(int(3.5*SR))
for start,dur in [(.15,.26),(.65,.68),(1.8,.25),(2.3,.7)]:
 t=np.arange(int(dur*SR))/SR;env=np.sin(np.pi*t/dur)**1.2;phase=2*np.pi*(410*t+26*dur/np.pi*np.sin(np.pi*t/dur))
 x=(np.sin(phase)+.18*np.sin(2*phase)+.05*np.sin(3*phase))*env*.24;n=int(start*SR);a[n:n+len(x)]+=x
save('owl',a)
a=np.zeros(8*SR)
for base in np.arange(.3,7.5,.84):
 for gap in [0,.10,.2]:chirp(a,base+gap,.055,4600,4750,.07)
save('crickets',a)
for name,dur in [('leaves',2.4),('wings',.85),('twig',1.4)]:
 t=np.arange(int(dur*SR))/SR;noise=rng.normal(0,1,len(t));low=np.convolve(noise,np.ones(13)/13,mode='same');band=noise-low
 if name=='leaves':env=np.sin(np.pi*t/dur)**2*(.4+.6*np.sin(2*np.pi*3.2*t)**2);x=band*env*.045+low*env*.15
 elif name=='wings':env=np.exp(-2*t)*(np.maximum(0,np.sin(2*np.pi*7*t))**4);x=low*env*.5
 else:
  env=np.exp(-30*t);x=band*env*.12+np.sin(2*np.pi*310*t)*np.exp(-20*t)*.16
  for start in [.045,.12,.32]:
   n=int(start*SR);x[n:]+=band[:len(x)-n]*np.exp(-45*t[:len(x)-n])*.08
 x*=np.minimum(1,t/.005)*np.minimum(1,(dur-t)/.025);save(name,x)
print('Generated',len(list(OUT.glob('*.wav'))),'original mono WAV assets')
