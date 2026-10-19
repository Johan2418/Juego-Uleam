"""Mide alto de pie y ancho de cabeza de frames recortados (assets/sprites/characters_anim).
uso: python tools/measure_p4.py <personaje> <anim> [<anim>...]  -> tabla por dirección."""
import sys, glob, re
import numpy as np
from PIL import Image
ROOT='assets/sprites/characters_anim'
def metrics(path):
    a=np.array(Image.open(path).convert('RGBA'))[:,:,3]>40
    ys=np.where(a.any(1))[0]
    if len(ys)==0: return None
    y0,y1=ys[0],ys[-1]
    h=y1-y0+1
    rows=a[y0+6:y0+22]
    # ancho de cabeza: mayor tramo continuo por fila (evita armas separadas)
    ws=[]
    for r in rows:
        xs=np.where(r)[0]
        if len(xs)==0: continue
        segs=np.split(xs,np.where(np.diff(xs)>2)[0]+1)
        ws.append(max(len(s) for s in segs))
    return h, (np.median(ws) if ws else 0)
ch=sys.argv[1]
for anim in sys.argv[2:]:
    for d in ['down','up','right','down_right','up_right']:
        fs=sorted(glob.glob(f'{ROOT}/{ch}/{anim}_{d}_[0-9].png'), key=lambda p:int(re.findall(r'_(\d+)\.png$',p)[0]))
        if not fs: continue
        m=[metrics(f) for f in fs]; m=[x for x in m if x]
        hs=[x[0] for x in m]; ws=[x[1] for x in m]
        stand = hs[-1] if anim.endswith('8') and len(hs)==8 else float(np.median(hs))
        print(f'{anim:22s} {d:10s} n={len(fs)} stand_h={stand:5.1f} max_h={max(hs):4d} head_w(p25)={np.percentile(ws,25):5.1f} med={np.median(ws):5.1f}')
