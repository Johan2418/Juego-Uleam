from PIL import Image
import numpy as np, json, colorsys
ids=['gorra','chaqueta','traje_azul','traje_negro','futbolista','rubio','coleta','trenza','canoso','mochila','afro_rojo','bufanda','explorador','pelirrojo','hoodie','rapado']
meta=json.load(open('parts_meta.json'))
BASE='gorra'
def regions(a):
    rgb=a[...,:3].astype(float); al=a[...,3]>0
    r,g,b=rgb[...,0],rgb[...,1],rgb[...,2]; L=rgb.mean(2)
    outline=al&(L<45)
    shirt=al&~outline&(b>150)&(b>r+15)&(L>150)
    pants=al&~outline&(b>r+25)&(L<=150)&(L>45)
    skin=al&~outline&(r>g+20)&(g>b+10)
    return dict(outline=outline,shirt=shirt,pants=pants,skin=skin)
def dominant(a,m):
    if m.sum()==0: return None
    px=a[...,:3][m].astype(int); q=(px//16)*16
    u,c=np.unique(q,axis=0,return_counts=True); t=u[c.argmax()]
    sel=np.all(q==t,axis=1); return px[sel].mean(0)
def targets(n,v):
    a=np.array(Image.open(f'parts/{n}_{v}_body.png')); cm=meta[n][v]; ny=cm['neck_y'];H=cm['h']
    al=a[...,3]>0; L=a[...,:3].mean(2); notout=al&(L>45)
    rr=regions(a); nos=notout&~rr['skin']
    torso=np.zeros_like(al); torso[ny+3:ny+3+int((H-ny)*0.35)]=True
    legs=np.zeros_like(al); legs[H-int((H-ny)*0.35):H-3]=True
    return dominant(a,nos&torso), dominant(a,nos&legs)
base=np.array(Image.open(f'parts/{BASE}_front_body.png'))
def recolor(v,shirt_t,pants_t):
    a=np.array(Image.open(f'parts/{BASE}_{v}_body.png')).copy()
    rr=regions(a); rgb=a[...,:3].astype(float)
    for key,t in [('shirt',shirt_t),('pants',pants_t)]:
        m=rr[key]
        if t is None or m.sum()==0: continue
        Ls=rgb[m].mean(1); ref=np.median(Ls)
        k=(Ls/ref)[:,None]
        a[...,:3][m]=np.clip(t[None,:]*k,0,255).astype(np.uint8)
    return a
out={}
for n in ids:
    s,p=targets(n,'front'); out[n]={'shirt':None if s is None else [int(x) for x in s],'pants':None if p is None else [int(x) for x in p]}
out.update({'chaqueta':{'shirt':[40,40,44],'pants':[125,125,132]},'futbolista':{'shirt':[200,45,55],'pants':[40,40,44]},'explorador':{'shirt':[120,80,50],'pants':[200,175,130]}})
S=5;cw=40*S;ch=64*S
sheet=Image.new('RGBA',(cw*8,ch*8),(58,60,72,255))

def comp(n,v,body):
    bm=meta[BASE][v]; cm=meta[n][v]
    head=Image.open(f'parts/{n}_{v}_head.png').crop((0,0,cm['w'],cm['neck_y']+1))
    s=(bm['h']-bm['neck_y'])/(cm['h']-cm['neck_y'])
    head=head.resize((max(1,round(head.width*s)),max(1,round(head.height*s))),Image.NEAREST)
    c=Image.new('RGBA',(40,64),(0,0,0,0)); ox=20-int(round(bm['neck_x'])); oy=64-bm['h']
    c.alpha_composite(Image.fromarray(body),(ox,oy))
    c.alpha_composite(head,(max(0,ox+int(round(bm['neck_x']-cm['neck_x']*s))),max(0,oy+bm['neck_y']+1-head.height)))
    return c
for i,n in enumerate(ids):
    x0=(i%2)*cw*4; y0=(i//2)*ch
    oc=out[n]
    st=None if oc['shirt'] is None else np.array(oc['shirt'],float); pt=None if oc['pants'] is None else np.array(oc['pants'],float)
    tiles=[Image.open(f'native/{n}_front.png')]+[comp(n,v,recolor(v,st,pt)) for v in ['front','back','right']]
    for j,t in enumerate(tiles):
        t=t.resize((t.width*S,t.height*S),Image.NEAREST)
        sheet.alpha_composite(t,(x0+j*cw+(cw-t.width)//2,y0+ch-t.height-6))
sheet.save('/tmp/cs/pkg/assets/sprites/characters/_preview_cabeza_cuerpo_compartido.png')
