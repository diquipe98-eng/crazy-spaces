from PIL import Image
from collections import deque
import math,base64,io,json
S='icons/'
def comps(a,w,h):
    seen=[[0]*w for _ in range(h)];out=[]
    for y in range(h):
        for x in range(w):
            if a[x,y]>0 and not seen[y][x]:
                q=deque([(x,y)]);seen[y][x]=1;c=[]
                while q:
                    cx,cy=q.popleft();c.append((cx,cy))
                    for nx,ny in((cx+1,cy),(cx-1,cy),(cx,cy+1),(cx,cy-1),(cx+1,cy+1),(cx-1,cy-1),(cx+1,cy-1),(cx-1,cy+1)):
                        if 0<=nx<w and 0<=ny<h and a[nx,ny]>0 and not seen[ny][nx]: seen[ny][nx]=1;q.append((nx,ny))
                out.append(c)
    return out
def clean(name,th,keepfrac=.12):
    im=Image.open(S+'cut_'+name+'.png').convert('RGBA');w,h=im.size;p=im.load()
    a=Image.new('L',(w,h));ap=a.load()
    for y in range(h):
        for x in range(w): ap[x,y]=255 if p[x,y][3]>200 else 0
    cs=comps(ap,w,h);big=max(len(c) for c in cs)
    keep=set()
    for c in cs:
        if len(c)>=big*keepfrac: keep.update(c)
    for y in range(h):
        for x in range(w):
            r,g,b,_=p[x,y];p[x,y]=(r,g,b,255 if (x,y) in keep else 0)
    im=im.crop(im.getchannel('A').getbbox());im.save(S+'fin_'+name+'.png')
for n in ['heart','coin','gear','clock','shield','laser','rocket','bomb','nova','magnet','plus']: clean(n,0)
# corazón vacío derivado del lleno
h=Image.open(S+'fin_heart.png');w,hh=h.size;hp=h.load();e=Image.new('RGBA',(w,hh));ep=e.load()
for y in range(hh):
    for x in range(w):
        if hp[x,y][3]==0: continue
        edge=any(not(0<=x+dx<w and 0<=y+dy<hh) or hp[x+dx,y+dy][3]==0 for dx,dy in((2,0),(-2,0),(0,2),(0,-2)))
        ep[x,y]=(92,108,150,255) if edge else (18,24,48,170)
e.save(S+'fin_heart_empty.png')
# insignias del campo: desvanecido radial
for n in ['p_plus','p_shield','p_magnet','p_chev']:
    im=Image.open(S+'cut_'+n+'.png').convert('RGBA');w,hh=im.size;p=im.load();cx,cy=w/2,hh/2;R=min(w,hh)/2
    for y in range(hh):
        for x in range(w):
            r,g,b,a=p[x,y];d=math.hypot(x+.5-cx,y+.5-cy)/R
            f=1 if d<.78 else max(0,(1-d)/.22)
            p[x,y]=(r,g,b,int(a*f))
    im.save(S+'fin_'+n+'.png')
for n in ['sound','pause']: Image.open(S+'cut_'+n+'.png').save(S+'fin_'+n+'.png')
names=['heart','heart_empty','coin','gear','clock','shield','laser','rocket','bomb','nova','magnet','plus','p_plus','p_shield','p_magnet','p_chev','sound','pause']
sheet=Image.new('RGBA',(9*150,2*150),(255,0,255,255))
data={}
for i,n in enumerate(names):
    im=Image.open(S+'fin_'+n+'.png');t=im.resize((im.width*2,im.height*2),Image.NEAREST);sheet.alpha_composite(t,((i%9)*150+3,(i//9)*150+3))
    b=io.BytesIO();im.save(b,'PNG',optimize=True);data[n]='data:image/png;base64,'+base64.b64encode(b.getvalue()).decode()
    print(n,im.size,len(b.getvalue()))
sheet.save('sheet_fin.png');json.dump(data,open('icons.json','w'))
