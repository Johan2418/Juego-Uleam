from PIL import Image
import numpy as np, json
from scipy import ndimage
U='/root/.claude/uploads/4243cbca-3757-5316-9a25-b39b99375d0d/'
fs=['dfae8729','08f36895','c801644b','3f148e77','8afdcbd9','e5d658cb','f7d46480','0eb31c68','a473bab6','12ac2817','39b33022','6b8b21ea','d1c8433a','c95d8c26','b6edfd6c','c11136ea']
out={}
for i,f in enumerate(fs):
    a=np.array(Image.open(U+f+'-image.png').convert('RGB')).astype(int)
    bg=np.median(np.concatenate([a[0],a[-1],a[:,0],a[:,-1]]),axis=0)
    d=np.abs(a-bg).sum(2)
    fg=d>60
    fg=ndimage.binary_closing(fg,iterations=3)
    fg=ndimage.binary_fill_holes(fg)
    lab,n=ndimage.label(fg)
    objs=ndimage.find_objects(lab)
    boxes=[]
    for k,s in enumerate(objs):
        h=s[0].stop-s[0].start; w=s[1].stop-s[1].start
        if h>300: boxes.append((s[0].start,s[0].stop,s[1].start,s[1].stop))
    boxes.sort(key=lambda b:(b[0]//400,b[2]))
    out[i]=boxes
    print(i,len(boxes),[ (b[1]-b[0],b[3]-b[2]) for b in boxes])
json.dump(out,open('boxes.json','w'))
