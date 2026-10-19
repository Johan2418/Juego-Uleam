from PIL import Image
import numpy as np, json, os, shutil
ids=['gorra','chaqueta','traje_azul','traje_negro','futbolista','rubio','coleta','trenza','canoso','mochila','afro_rojo','bufanda','explorador','pelirrojo','hoodie','rapado']
labels={'gorra':'Gorra','chaqueta':'Chaqueta de cuero','traje_azul':'Traje azul','traje_negro':'Traje negro','futbolista':'Futbolista','rubio':'Rubio','coleta':'Coleta','trenza':'Trenza','canoso':'Canoso','mochila':'Mochila','afro_rojo':'Afro rojo','bufanda':'Bufanda','explorador':'Explorador','pelirrojo':'Pelirrojo','hoodie':'Hoodie','rapado':'Rapado'}
meta=json.load(open('parts_meta.json')); oc=json.load(open('outfit_colors.json'))
over={'chaqueta':{'shirt':[40,40,44],'pants':[125,125,132]},'futbolista':{'shirt':[200,45,55],'pants':[40,40,44]},'explorador':{'shirt':[120,80,50],'pants':[200,175,130]}}
oc.update(over)
BASE='gorra'; R='pkg/assets/sprites/characters'
if os.path.exists('pkg'): shutil.rmtree('pkg')
os.makedirs(R+'/heads'); os.makedirs(R+'/body_base')
chars=[]
for v in ['front','back','right']:
    bm=meta[BASE][v]; b=Image.open(f'parts/{BASE}_{v}_body.png'); bb=b.getbbox()
    b.crop(bb).save(f'{R}/body_base/{v}.png')
    meta[BASE][v]['body_neck']=[bm['neck_x']-bb[0], bm['neck_y']+1-bb[1]]
bodymeta={v:{'neck':meta[BASE][v]['body_neck']} for v in ['front','back','right']}
for n in ids:
    e={'id':n,'label':labels[n],'shirt':oc[n]['shirt'],'pants':oc[n]['pants'],'heads':{}}
    for v in ['front','back','right']:
        bm=meta[BASE][v]; cm=meta[n][v]
        s=(bm['h']-bm['neck_y'])/(cm['h']-cm['neck_y'])
        h=Image.open(f'parts/{n}_{v}_head.png').crop((0,0,cm['w'],cm['neck_y']+1))
        h=h.resize((max(1,round(h.width*s)),max(1,round(h.height*s))),Image.NEAREST)
        bb=h.getbbox(); h=h.crop(bb)
        h.save(f'{R}/heads/{n}_{v}.png')
        e['heads'][v]={'file':f'heads/{n}_{v}.png','anchor':[round(cm['neck_x']*s-bb[0],1), h.height]}
    chars.append(e)
json.dump({'base_body':'gorra','body':bodymeta,'characters':chars},open(f'{R}/characters.json','w'),indent=1,ensure_ascii=False)
print(len(os.listdir(R+'/heads')))
