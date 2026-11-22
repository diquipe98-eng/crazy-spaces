from PIL import Image, ImageFilter
from collections import deque
import json,sys
S='icons/'
# nombre: (raw, subcaja dentro del raw, umbral de oscuridad)
spec={
 'heart':('raw_heart2',None,70),'heart_empty':('raw_heart_empty',None,40),'coin':('raw_coin',None,60),
 'gear':('raw_gear2',(6,0,65,62),60),'clock':('raw_clock',None,60),'shield':('raw_shield2',None,55),
 'sound':('raw_sound',None,30),'pause':('raw_pause',None,30),
 'laser':('raw_s_laser',(7,7,73,58),50),'rocket':('raw_r2_rocket',(6,6,72,70),55),'bomb':('raw_r2_bomb',(6,6,72,70),55),
 'nova':('raw_r2_star',(6,6,74,70),55),'magnet':('raw_r2_magnet',(6,6,72,70),55),'plus':('raw_r2_plus',(6,6,72,70),55),
 'vortex':('raw_s_vortex',(7,7,73,58),50),'energy':('raw_s_energy',(7,7,73,58),50),
 'p_plus':('raw_p_plus',None,75),'p_shield':('raw_p_shield',None,75),'p_magnet':('raw_p_magnet',None,95),'p_chev':('raw_p_chev',None,110),
}
def cut(name,raw,box,th):
    im=Image.open(S+raw+'.png').convert('RGBA')
    if box: im=im.crop(box)
    w,h=im.size;px=im.load()
    bg=[[False]*w for _ in range(h)]
    dark=lambda p:max(p[:3])<th
    q=deque()
    for x in range(w):
        for y in (0,h-1): q.append((x,y))
    for y in range(h):
        for x in (0,w-1): q.append((x,y))
    while q:
        x,y=q.popleft()
        if x<0 or y<0 or x>=w or y>=h or bg[y][x] or not dark(px[x,y]): continue
        bg[y][x]=True; q.extend(((x+1,y),(x-1,y),(x,y+1),(x,y-1)))
    a=Image.new('L',(w,h),0);ap=a.load()
    for y in range(h):
        for x in range(w):
            if not bg[y][x]: ap[x,y]=255
            else:
                # borde suave: halo luminoso que roza el contorno conserva algo de alfa
                m=max(px[x,y][:3]); ap[x,y]=max(0,min(255,int((m-th*.45)/(th*.55)*160))) if m>th*.45 else 0
    # quitar motas aisladas
    a=a.filter(ImageFilter.MedianFilter(3)) if name.startswith('p_') else a
    im.putalpha(a)
    bb=a.point(lambda v:255 if v>40 else 0).getbbox()
    im=im.crop(bb); im.save(S+'cut_'+name+'.png'); return im
out=[]
for k,(raw,box,th) in spec.items(): out.append((k,cut(k,raw,box,th)))
sheet=Image.new('RGBA',(8*170,3*170),(255,0,255,255))
for i,(k,im) in enumerate(out):
    t=im.resize((im.width*2,im.height*2),Image.NEAREST); sheet.alpha_composite(t,((i%8)*170+3,(i//8)*170+3))
sheet.save('sheet_cut.png')
