"""Limpia el recorte del logo: quita motas sueltas, el halo gris/blanco del fondo
original y los semitransparentes grises, y añade un contorno oscuro de 2 px que
suaviza el borde dentado. Uso: python3 tools/limpiar_logo.py entrada.png salida.png"""
import sys
from collections import deque
from PIL import Image, ImageFilter

ent, sal = sys.argv[1], sys.argv[2]
im = Image.open(ent).convert('RGBA'); W, H = im.size; px = im.load()

def sat(p):
    r, g, b = p[:3]; return max(r, g, b) - min(r, g, b)
def grisaceo(p):
    return sat(p) < 40 and max(p[:3]) > 70

# 1) semitransparentes grises fuera
for y in range(H):
    for x in range(W):
        p = px[x, y]
        if 0 < p[3] < 255 and grisaceo(p):
            px[x, y] = (0, 0, 0, 0)
# 2) halo: píxeles grisáceos claros pegados al vacío, varias pasadas
for _ in range(3):
    borrar = []
    for y in range(H):
        for x in range(W):
            p = px[x, y]
            if p[3] == 0 or not grisaceo(p): continue
            if any(0 <= x+dx < W and 0 <= y+dy < H and px[x+dx, y+dy][3] == 0 for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))):
                borrar.append((x, y))
    for x, y in borrar: px[x, y] = (0, 0, 0, 0)
# 3) motas: componentes pequeñas; se conservan las estrellitas de color
vis = bytearray(W * H); quitadas = 0
for y0 in range(H):
    for x0 in range(W):
        if vis[y0*W+x0] or px[x0, y0][3] == 0: continue
        comp = []; q = deque([(x0, y0)]); vis[y0*W+x0] = 1
        while q:
            x, y = q.popleft(); comp.append((x, y))
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nx, ny = x+dx, y+dy
                    if 0 <= nx < W and 0 <= ny < H and not vis[ny*W+nx] and px[nx, ny][3] > 0:
                        vis[ny*W+nx] = 1; q.append((nx, ny))
        if len(comp) < 400:
            color = sum(sat(px[x, y]) for x, y in comp) / len(comp)
            if len(comp) < 12 or color < 70:
                for x, y in comp: px[x, y] = (0, 0, 0, 0)
                quitadas += 1
# 4) alfa a 255 para lo que queda y contorno oscuro de 2 px
for y in range(H):
    for x in range(W):
        p = px[x, y]
        if 0 < p[3] < 255: px[x, y] = p[:3] + (255,)
alfa = im.getchannel('A')
borde = alfa.filter(ImageFilter.MaxFilter(5))
fondo = Image.new('RGBA', (W, H), (11, 8, 32, 0)); fondo.putalpha(borde)
fondo.alpha_composite(im)
fondo.save(sal)
print('motas quitadas:', quitadas)
