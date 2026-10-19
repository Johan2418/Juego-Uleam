"""Tira de verificación: por fila, caminata pose 1 + todos los frames de la animación. Líneas guía: pies y=152, alto 88."""
import sys, glob, re
from PIL import Image, ImageDraw
R='assets/sprites/characters_anim'
rows=[l.split() for l in sys.argv[2:]]
out=sys.argv[1]
C=160; S=0.75
W=int(C*S*9)+170
img=Image.new('RGB',(W,int(C*S)*len(rows)),(70,70,80)); d=ImageDraw.Draw(img)
for r,(ch,anim,dr) in enumerate(rows):
    y=int(C*S)*r
    fs=[f'{R}/{ch}/walk_{dr}_0.png']+sorted(glob.glob(f'{R}/{ch}/{anim}_{dr}_[0-9].png'),key=lambda p:int(re.findall(r'_(\d+)\.png$',p)[0]))
    for i,f in enumerate(fs):
        im=Image.open(f).convert('RGBA').resize((int(C*S),int(C*S)),Image.NEAREST)
        img.paste(im,(170+i*int(C*S),y),im)
    for yy in (152,152-88): d.line([(170,y+int(yy*S)),(W,y+int(yy*S))],fill=(255,80,80) if yy==152 else (80,200,255))
    d.text((4,y+40),f'{ch}\n{anim}\n{dr}',fill='white')
img.save(out)
