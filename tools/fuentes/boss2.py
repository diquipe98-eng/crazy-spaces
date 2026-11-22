from PIL import Image, ImageOps
import sys
sys.path.insert(0,'tools')
def erase(im,f):
    p=im.load();w,h=im.size
    for y in range(h):
        for x in range(w):
            if p[x,y][3] and f(x,y,p[x,y]):p[x,y]=(0,0,0,0)
def mirror_left(im,cx):
    h=im.size[1];half=im.crop((0,0,cx,h));full=Image.new('RGBA',(cx*2,h));full.paste(half,(0,0));full.paste(ImageOps.mirror(half),(cx,0));return full
ov=Image.open('assets/k_overlord.png').convert('RGBA')
erase(ov,lambda x,y,c:(y>175 and x<300) or (y>262 and 300<=x<478 and False))
ov=mirror_left(ov,478);ov=ov.crop(ov.getchannel('A').getbbox())
me=Image.open('assets/k_mecanico.png').convert('RGBA')
def mf(x,y,c):
    r,g,b,a=c
    if 12<=y<=52 and max(r,g,b)<120 and b>=r: return True   # restos de la línea de la arena
    if y>228 and not (330<=x<=402): return True               # balas rojas bajo el jefe
    if y>195 and (x<60 or x>670): return True
    return False
erase(me,mf)
# simetría: mitad izquierda limpia reflejada (eje en el núcleo central)
me=mirror_left(me,366);me=me.crop(me.getchannel('A').getbbox())
ov.save('assets/boss_overlord.png');me.save('assets/boss_mecanico.png')
print(ov.size,me.size)
o=Image.new('RGBA',(ov.width+me.width+20,max(ov.height,me.height)),(30,10,40,255));o.alpha_composite(ov,(0,0));o.alpha_composite(me,(ov.width+20,0));o.resize((o.width//2*1,o.height//2*1)).save('boss_final.png')
