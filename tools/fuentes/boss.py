from PIL import Image, ImageOps
from collections import deque
def key(im,th,line=None):
    im=im.convert('RGBA');w,h=im.size;p=im.load()
    if line:
        y0,y1=line
        for y in range(y0,y1):
            for x in range(w):
                r,g,b,a=p[x,y]
                if b>150 and b>r*1.5: p[x,y]=(0,0,0,255)
    bg=[[0]*w for _ in range(h)];q=deque()
    for x in range(w):q.append((x,0));q.append((x,h-1))
    for y in range(h):q.append((0,y));q.append((w-1,y))
    while q:
        x,y=q.popleft()
        if x<0 or y<0 or x>=w or y>=h or bg[y][x]:continue
        r,g,b,a=p[x,y]
        if max(r,g,b)>=th:continue
        bg[y][x]=1;q.extend(((x+1,y),(x-1,y),(x,y+1),(x,y-1)))
    for y in range(h):
        for x in range(w):
            if bg[y][x]:p[x,y]=(0,0,0,0)
    # componente principal
    seen=[[0]*w for _ in range(h)];comps=[]
    for y in range(h):
        for x in range(w):
            if p[x,y][3] and not seen[y][x]:
                c=[];q=deque([(x,y)]);seen[y][x]=1
                while q:
                    cx,cy=q.popleft();c.append((cx,cy))
                    for nx,ny in((cx+1,cy),(cx-1,cy),(cx,cy+1),(cx,cy-1)):
                        if 0<=nx<w and 0<=ny<h and p[nx,ny][3] and not seen[ny][nx]:seen[ny][nx]=1;q.append((nx,ny))
                comps.append(c)
    comps.sort(key=len,reverse=True);keep=set(comps[0])
    for c in comps[1:]:
        if len(c)>len(comps[0])*.02: keep.update(c)
    for y in range(h):
        for x in range(w):
            if (x,y) not in keep:p[x,y]=(0,0,0,0)
    return im
def mirror(im,cx,side):
    w,h=im.size
    if side=='left':half=im.crop((0,0,cx,h));full=Image.new('RGBA',(cx*2,h));full.paste(half,(0,0));full.paste(ImageOps.mirror(half),(cx,0))
    else:half=im.crop((cx,0,w,h));hw=w-cx;full=Image.new('RGBA',(hw*2,h));full.paste(ImageOps.mirror(half),(0,0));full.paste(half,(hw,0))
    return full.crop(full.getchannel('A').getbbox())
a=key(Image.open('assets/raw_overlord.png'),58)
b=key(Image.open('assets/raw_mecanico.png'),58,line=(30,60))
a.save('assets/k_overlord.png');b.save('assets/k_mecanico.png')
for side in('left','right'):
    mirror(a,478,side).save(f'assets/ov_{side}.png');mirror(b,366,side).save(f'assets/me_{side}.png')
o=Image.new('RGBA',(2000,620),(255,0,255,255))
o.alpha_composite(a,(0,0));o.alpha_composite(b,(1000,0))
o.alpha_composite(Image.open('assets/ov_left.png'),(0,310));o.alpha_composite(Image.open('assets/me_right.png'),(1000,310))
o.save('boss_keyed.png')
