from PIL import Image
import numpy as np, json, os
from scipy import ndimage
U='/root/.claude/uploads/4243cbca-3757-5316-9a25-b39b99375d0d/'
names=['dfae8729','08f36895','c801644b','3f148e77','8afdcbd9','e5d658cb','f7d46480','0eb31c68','a473bab6','12ac2817','39b33022','6b8b21ea','d1c8433a','c95d8c26','b6edfd6c','c11136ea']
ids=['gorra','chaqueta','traje_azul','traje_negro','futbolista','rubio','coleta','trenza','canoso','mochila','afro_rojo','bufanda','explorador','pelirrojo','hoodie','rapado']
boxes=json.load(open('boxes.json'))
os.makedirs('native',exist_ok=True)
def pitch_phase(g, axis):
    gx=np.abs(np.diff(g,axis=axis))>40
    idx=np.where(gx)[1] if axis==1 else np.where(gx)[0]
    best=None
    for p10 in range(140,220,1):
        p=p10/10; ang=2*np.pi*(idx%p)/p; z=np.mean(np.exp(1j*ang)); R=abs(z)
        if best is None or R>best[0]: best=(R,p,(np.angle(z)%(2*np.pi))/(2*np.pi)*p)
    return best
info={}
for i,n in enumerate(names):
    im=Image.open(U+n+'-image.png').convert('RGB'); a=np.array(im).astype(int)
    L=np.array(im.convert('L')).astype(int)
    bg=np.median(np.concatenate([a[0],a[-1],a[:,0],a[:,-1]]),axis=0)
    rx=pitch_phase(L,1); ry=pitch_phase(L,0)
    p=(rx[1]+ry[1])/2
    # sample centers: transitions at phase -> centers at phase+p/2 (transition index is between k and k+1)
    ox=rx[2]+1+p/2; oy=ry[2]+1+p/2
    xs=np.arange(ox%p, a.shape[1], p); ys=np.arange(oy%p, a.shape[0], p)
    xi=np.clip(np.round(xs).astype(int),0,a.shape[1]-1); yi=np.clip(np.round(ys).astype(int),0,a.shape[0]-1)
    # median of 5x5 around centers for robustness
    small=np.zeros((len(yi),len(xi),3))
    r=max(2,int(p*0.25))
    for yy,y in enumerate(yi):
        for xx,x in enumerate(xi):
            small[yy,xx]=np.median(a[max(0,y-r):y+r+1,max(0,x-r):x+r+1].reshape(-1,3),axis=0)
    d=np.abs(small-bg).sum(2)
    alpha=(d>45)
    # keep bg-connected removal: flood from border
    lab,_=ndimage.label(~alpha)
    border=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))
    bgmask=np.isin(lab,list(border))
    alpha=~bgmask
    rgba=np.dstack([small.astype(np.uint8),(alpha*255).astype(np.uint8)])
    views=[]
    for b in boxes[str(i)]:
        y0=int(b[0]/p);y1=int(np.ceil(b[1]/p));x0=int(b[2]/p);x1=int(np.ceil(b[3]/p))
        # map via sample positions
        yy=np.where((ys>=b[0])&(ys<b[1]))[0]; xx=np.where((xs>=b[2])&(xs<b[3]))[0]
        crop=rgba[yy.min():yy.max()+1, xx.min():xx.max()+1]
        # trim
        m=crop[...,3]>0; r_=np.where(m.any(1))[0]; c_=np.where(m.any(0))[0]
        crop=crop[r_.min():r_.max()+1, c_.min():c_.max()+1]
        views.append(crop)
    nb=len(views)
    if nb==4: sel={'front':views[0],'back':views[1],'right':views[2],'left':views[3]}
    else: sel={'front':views[0],'back':views[1],'right':views[4],'left':views[7]}
    info[ids[i]]={'pitch':round(p,2),'sizes':{k:v.shape[:2] for k,v in sel.items()}}
    for k,v in sel.items():
        Image.fromarray(v,'RGBA').save(f'native/{ids[i]}_{k}.png')
    print(ids[i],round(p,2),rx[0].round(2),ry[0].round(2),{k:v.shape[:2] for k,v in sel.items()})
json.dump(info,open('native_info.json','w'),default=str)
