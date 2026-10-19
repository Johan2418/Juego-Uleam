from PIL import Image
import numpy as np, json, os
ids=['gorra','chaqueta','traje_azul','traje_negro','futbolista','rubio','coleta','trenza','canoso','mochila','afro_rojo','bufanda','explorador','pelirrojo','hoodie','rapado']
os.makedirs('parts',exist_ok=True)
meta={}
def load(n,v): return np.array(Image.open(f'native/{n}_{v}.png'))
def clean(a):
    # drop greenish fringe pixels
    r,g,b,al=[a[...,k].astype(int) for k in range(4)]
    fr=(g>r+25)&(g>b+25)&(g>120)
    a=a.copy(); a[fr,3]=0; return a
def neck_row(a):
    m=a[...,3]>0; H=m.shape[0]
    w=np.array([ (np.ptp(np.where(r)[0])+1 if r.any() else 0) for r in m])
    lo,hi=int(H*0.35),int(H*0.62)
    return lo+int(np.argmin(w[lo:hi]))
for n in ids:
    meta[n]={}
    for v in ['front','back','right']:
        a=clean(load(n,v)); H=a.shape[0]
        ny=neck_row(a)
        # neck center x = center of body mask just below neck
        m=a[...,3]>0
        rowsb=m[ny+2:ny+6]; xs=np.where(rowsb.any(0))[0]; cx=(xs.min()+xs.max())/2
        head=a.copy(); head[ny+1:]=0
        body=a.copy(); body[:ny+1]=0
        Image.fromarray(head).save(f'parts/{n}_{v}_head.png'); Image.fromarray(body).save(f'parts/{n}_{v}_body.png')
        meta[n][v]={'neck_y':int(ny),'neck_x':float(cx),'h':H,'w':a.shape[1]}
json.dump(meta,open('parts_meta.json','w'),indent=1)
print({n:[meta[n][v]['neck_y'] for v in meta[n]] for n in ids})
print({n:[meta[n][v]['h']-meta[n][v]['neck_y'] for v in meta[n]] for n in ids})
