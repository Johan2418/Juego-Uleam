#!/usr/bin/env python3
"""Hojas turnaround (4 vistas u 8) -> cabezas + cuerpo base + characters.json.
Uso: python3 build_characters.py <dir_originales> <dir_salida_assets/sprites/characters>
Cada PNG en dir_originales se llama <id>.png. Cuerpo base = 'gorra'."""
import sys, os, json
import numpy as np
from PIL import Image
from scipy import ndimage

LABELS={'gorra':'Gorra','chaqueta':'Chaqueta de cuero','traje_azul':'Traje azul','traje_negro':'Traje negro','futbolista':'Futbolista','rubio':'Rubio','coleta':'Coleta','trenza':'Trenza','canoso':'Canoso','mochila':'Mochila','afro_rojo':'Afro rojo','bufanda':'Bufanda','explorador':'Explorador','pelirrojo':'Pelirrojo','hoodie':'Hoodie','rapado':'Rapado','wadrid':'Wadrid','marlonx_a':'MarlonX-a'}
ORDER=['wadrid','marlonx_a','gorra','chaqueta','traje_azul','traje_negro','futbolista','rubio','coleta','trenza','canoso','mochila','afro_rojo','bufanda','explorador','pelirrojo','hoodie','rapado']
COLOR_OVERRIDE={'chaqueta':{'shirt':[40,40,44],'pants':[125,125,132]},'futbolista':{'shirt':[200,45,55],'pants':[40,40,44]},'explorador':{'shirt':[120,80,50],'pants':[200,175,130]},'wadrid':{'shirt':[52,82,58],'pants':[70,100,150]},'marlonx_a':{'shirt':[70,66,78],'pants':[70,100,150]}}
BASE='gorra'

def boxes_of(a):
    bg=np.median(np.concatenate([a[0],a[-1],a[:,0],a[:,-1]]),axis=0)
    fg=np.abs(a-bg).sum(2)>60
    fg=ndimage.binary_fill_holes(ndimage.binary_closing(fg,iterations=3))
    lab,_=ndimage.label(fg)
    bx=[]
    for s in ndimage.find_objects(lab):
        if s[0].stop-s[0].start>300:
            bx.append((s[0].start,s[0].stop,s[1].start,s[1].stop))
    H=a.shape[0]
    bx.sort(key=lambda b:(0 if (b[0]+b[1])/2<H/2 else 1,b[2]))
    return bx,bg

def pitch_phase(L,axis):
    g=np.abs(np.diff(L,axis=axis))>40
    idx=np.where(g)[1] if axis==1 else np.where(g)[0]
    best=None
    for p10 in range(140,220):
        p=p10/10; z=np.mean(np.exp(2j*np.pi*(idx%p)/p)); R=abs(z)
        if best is None or R>best[0]: best=(R,p,(np.angle(z)%(2*np.pi))/(2*np.pi)*p)
    return best

def native_views(path):
    im=Image.open(path).convert('RGB'); a=np.array(im).astype(int); L=np.array(im.convert('L')).astype(int)
    bx,bg=boxes_of(a)
    rx=pitch_phase(L,1); ry=pitch_phase(L,0); p=(rx[1]+ry[1])/2
    xs=np.arange((rx[2]+1+p/2)%p,a.shape[1],p); ys=np.arange((ry[2]+1+p/2)%p,a.shape[0],p)
    xi=np.clip(np.round(xs).astype(int),0,a.shape[1]-1); yi=np.clip(np.round(ys).astype(int),0,a.shape[0]-1)
    r=max(2,int(p*0.25)); small=np.zeros((len(yi),len(xi),3))
    for Y,y in enumerate(yi):
        for X,x in enumerate(xi):
            small[Y,X]=np.median(a[max(0,y-r):y+r+1,max(0,x-r):x+r+1].reshape(-1,3),axis=0)
    alpha=np.abs(small-bg).sum(2)>45
    lab,_=ndimage.label(~alpha); border=np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]]))
    alpha=~np.isin(lab,border)
    rgba=np.dstack([small.astype(np.uint8),(alpha*255).astype(np.uint8)])
    # quitar halo verde
    R_,G_,B_=[rgba[...,k].astype(int) for k in range(3)]
    rgba[(G_>R_+25)&(G_>B_+25)&(G_>120),3]=0
    views=[]
    for b in bx:
        yy=np.where((ys>=b[0])&(ys<b[1]))[0]; xx=np.where((xs>=b[2])&(xs<b[3]))[0]
        c=rgba[yy.min():yy.max()+1,xx.min():xx.max()+1]; m=c[...,3]>0
        rr=np.where(m.any(1))[0]; cc=np.where(m.any(0))[0]
        views.append(c[rr.min():rr.max()+1,cc.min():cc.max()+1])
    if len(views)==8: return {'front':views[0],'back':views[1],'right':views[4]}, p
    return {'front':views[0],'back':views[1],'right':views[2]}, p

def neck(a):
    m=a[...,3]>0; H=m.shape[0]
    w=np.array([(np.ptp(np.where(r)[0])+1 if r.any() else 0) for r in m])
    lo,hi=int(H*0.35),int(H*0.62); ny=lo+int(np.argmin(w[lo:hi]))
    xs=np.where(m[ny+2:ny+6].any(0))[0]
    return ny,(xs.min()+xs.max())/2

def body_mask(a):
    """R=camisa, G=pantalon. La cintura separa ambas zonas (por fila)."""
    c=a[...,:3]/255.0; r,g,b=c[...,0],c[...,1],c[...,2]; L=c.mean(2); al=a[...,3]>0
    shirt_c=al&(b>0.59)&(b>r+0.06)&(L>0.59)
    pants_c=al&(b>r+0.1)&(L<=0.59)&(L>0.18)
    H=a.shape[0]; waist=H
    for y in range(H//3,H):
        if pants_c[y].sum()>shirt_c[y].sum() and pants_c[y].sum()>=3: waist=y; break
    rows=np.arange(H)[:,None]
    shirt=(shirt_c|pants_c)&(rows<waist)
    pants=pants_c&(rows>=waist)
    m=np.zeros(a.shape,np.uint8); m[...,0]=shirt*255; m[...,1]=pants*255; m[...,3]=255
    return m,(round(float(np.median(L[shirt])),4),round(float(np.median(L[pants])),4))

def dominant(a,mask):
    if mask.sum()==0: return None
    px=a[...,:3][mask].astype(int); q=(px//16)*16
    u,c=np.unique(q,axis=0,return_counts=True); t=u[c.argmax()]
    return [int(v) for v in px[np.all(q==t,axis=1)].mean(0)]

def main(src,dst):
    os.makedirs(dst+'/heads',exist_ok=True); os.makedirs(dst+'/body_base',exist_ok=True)
    data={}
    for cid in ORDER:
        f=os.path.join(src,cid+'.png')
        if not os.path.exists(f): print('falta',f); continue
        v,p=native_views(f); data[cid]={}
        for k,a in v.items():
            ny,nx=neck(a); data[cid][k]=dict(img=a,ny=ny,nx=nx,h=a.shape[0])
        print(cid,'pitch',round(p,2),{k:(d['h'],d['ny']) for k,d in data[cid].items()})
    out={'base_body':BASE,'body':{},'characters':[]}
    for k in ['front','back','right']:
        d=data[BASE][k]; body=d['img'].copy(); body[:d['ny']+1]=0
        bim=Image.fromarray(body); bb=bim.getbbox(); bim=bim.crop(bb); bim.save(f'{dst}/body_base/{k}.png')
        mask,refs=body_mask(np.array(bim)); Image.fromarray(mask).save(f'{dst}/body_base/{k}_mask.png')
        out['body'][k]={'neck':[round(d['nx']-bb[0],1), d['ny']+1-bb[1]],'shirt_ref':refs[0],'pants_ref':refs[1]}
    for cid in ORDER:
        if cid not in data: continue
        e={'id':cid,'label':LABELS.get(cid,cid),'heads':{}}
        # colores de ropa (torso/piernas de la vista frontal)
        d=data[cid]['front']; a=d['img']; H=d['h']; ny=d['ny']
        al=a[...,3]>0; Lm=a[...,:3].mean(2); R_,G_,B_=[a[...,i].astype(int) for i in range(3)]
        skin=(R_>G_+20)&(G_>B_+10); ok=al&(Lm>45)&~skin
        torso=np.zeros_like(al); torso[ny+3:ny+3+int((H-ny)*0.35)]=True
        legs=np.zeros_like(al); legs[H-int((H-ny)*0.35):H-3]=True
        e['shirt']=dominant(a,ok&torso); e['pants']=dominant(a,ok&legs)
        e.update(COLOR_OVERRIDE.get(cid,{}))
        for k in ['front','back','right']:
            bm=data[BASE][k]; cm=data[cid][k]
            s=(bm['h']-bm['ny'])/(cm['h']-cm['ny'])
            h=Image.fromarray(cm['img'][:cm['ny']+1])
            h=h.resize((max(1,round(h.width*s)),max(1,round(h.height*s))),Image.NEAREST)
            bb=h.getbbox(); h=h.crop(bb); h.save(f'{dst}/heads/{cid}_{k}.png')
            e['heads'][k]={'file':f'heads/{cid}_{k}.png','anchor':[round(cm['nx']*s-bb[0],1),h.height]}
        out['characters'].append(e)
    json.dump(out,open(f'{dst}/characters.json','w'),indent=1,ensure_ascii=False)
    print('personajes:',len(out['characters']))

if __name__=='__main__':
    main(sys.argv[1],sys.argv[2])
