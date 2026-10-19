from PIL import Image
import numpy as np, json
import sys
D=sys.argv[1] if len(sys.argv)>1 else 'assets/sprites/characters'; J=json.load(open(D+'/characters.json'))
def masks(a):
    c=a[...,:3]/255.0; r,g,b=c[...,0],c[...,1],c[...,2]; L=c.mean(2); al=a[...,3]>0
    shirt=al&(b>0.59)&(b>r+0.06)&(L>0.59)
    pants=al&(b>r+0.1)&(L<=0.59)&(L>0.18)
    return shirt,pants,L
refs={}
for v in ['front','back','right']:
    a=np.array(Image.open(f'{D}/body_base/{v}.png')); s,p,L=masks(a)
    refs[v]=(np.median(L[s]),np.median(L[p]))
print(refs)
RS=np.mean([r[0] for r in refs.values()]); RP=np.mean([r[1] for r in refs.values()])
print('REF',RS,RP)
def recolor(a,sh,pa,v='front'):
    a=a.copy(); m=np.array(Image.open(f'{D}/body_base/{v}_mask.png')); s=m[...,0]>127; p=m[...,1]>127; L=a[...,:3].mean(2)/255
    RS=J['body'][v]['shirt_ref']; RP=J['body'][v]['pants_ref']
    for m,t,ref in [(s,sh,RS),(p,pa,RP)]:
        k=(L[m]/ref)[:,None]; a[...,:3][m]=np.clip(np.array(t)[None,:]*k,0,255)
    return a
S=4; cw=36*S; ch=60*S; n=len(J['characters'])
sheet=Image.new('RGBA',(cw*6,ch*((n+1)//2)),(58,60,72,255))
for i,e in enumerate(J['characters']):
    for j,v in enumerate(['front','back','right']):
        body=np.array(Image.open(f'{D}/body_base/{v}.png')); body=Image.fromarray(recolor(body,e['shirt'],e['pants'],v))
        head=Image.open(f"{D}/{e['heads'][v]['file']}"); ax,ay=e['heads'][v]['anchor']; nx,ny=J['body'][v]['neck']
        c=Image.new('RGBA',(36,60)); bx=18-int(round(nx)); by=60-body.height
        c.alpha_composite(body,(bx,by)); c.alpha_composite(head,(max(0,bx+int(round(nx-ax))),max(0,by+int(ny)-int(ay))))
        c=c.resize((36*S,60*S),Image.NEAREST)
        sheet.alpha_composite(c,((i%2)*3*cw+j*cw,(i//2)*ch))
sheet.save(D+'/_preview_cabeza_cuerpo_compartido.png')
