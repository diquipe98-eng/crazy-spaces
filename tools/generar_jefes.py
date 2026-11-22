"""Genera los sprites pixel art de los jefes nuevos (CENTINELA, COLMENA, VACÍO).
Dibuja formas simétricas en un lienzo pequeño, las sombrea por placas con luz
cenital, añade contorno, líneas de panel, remaches y núcleos emisivos, y escala x4.
Uso: python3 tools/generar_jefes.py   (escribe art/jefes/*.png e imprime las bocas)."""
from PIL import Image, ImageDraw
import json, math

ESC = 4
OUTLINE = (8, 8, 16, 255)

def hexc(h):
    h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4)) + (255,)

class Lienzo:
    def __init__(s, w, h):
        s.w, s.h = w, h
        s.lab = [[0] * w for _ in range(h)]
        s.mats = {0: None}
        s.glows = {}
        s.n = 0
        s.extra = []   # (x, y, tipo, mat)
    def _nuevo(s, mat, glow=None):
        s.n += 1; s.mats[s.n] = mat
        if glow: s.glows[s.n] = glow
        return s.n
    def _pintar(s, mask, lid):
        px = mask.load()
        for y in range(s.h):
            for x in range(s.w):
                if px[x, y]: s.lab[y][x] = lid
    def _espejo(s, pts):
        return [(s.w - 1 - x, y) for x, y in pts]
    def poly(s, pts, mat, espejo=True):
        for p in ([pts, s._espejo(pts)] if espejo else [pts]):
            m = Image.new('L', (s.w, s.h)); ImageDraw.Draw(m).polygon(p, fill=1)
            s._pintar(m, s._nuevo(mat))
    def elipse(s, caja, mat, espejo=False, glow=None):
        x0, y0, x1, y1 = caja
        cajas = [caja]
        if espejo: cajas.append((s.w - 1 - x1, y0, s.w - 1 - x0, y1))
        for c in cajas:
            m = Image.new('L', (s.w, s.h)); ImageDraw.Draw(m).ellipse(c, fill=1)
            g = None
            if glow: g = ((c[0] + c[2]) / 2, (c[1] + c[3]) / 2, max(1, (c[2] - c[0]) / 2), glow)
            s._pintar(m, s._nuevo(mat, g))
    def rect(s, caja, mat, espejo=False):
        x0, y0, x1, y1 = caja
        self_pts = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
        s.poly(self_pts, mat, espejo)
    def linea(s, a, b, tipo='surco', espejo=True):
        for (p, q) in ([(a, b), (s._espejo([a])[0], s._espejo([b])[0])] if espejo else [(a, b)]):
            n = int(max(abs(q[0] - p[0]), abs(q[1] - p[1]))) + 1
            for i in range(n):
                t = i / max(1, n - 1)
                s.extra.append((round(p[0] + (q[0] - p[0]) * t), round(p[1] + (q[1] - p[1]) * t), tipo))
    def remache(s, p, espejo=True):
        for q in ([p, s._espejo([p])[0]] if espejo else [p]):
            s.extra.append((q[0], q[1], 'remache'))

    def render(s):
        img = Image.new('RGBA', (s.w, s.h), (0, 0, 0, 0)); px = img.load()
        lab = s.lab
        def L(x, y):
            return lab[y][x] if 0 <= x < s.w and 0 <= y < s.h else 0
        # caja de cada placa para el degradado vertical
        cajas = {}
        for y in range(s.h):
            for x in range(s.w):
                l = lab[y][x]
                if l:
                    c = cajas.setdefault(l, [y, y]); c[0] = min(c[0], y); c[1] = max(c[1], y)
        for y in range(s.h):
            for x in range(s.w):
                l = lab[y][x]
                if not l: continue
                ramp = s.mats[l]
                if l in s.glows:
                    cx, cy, r, gr = s.glows[l]
                    d = math.hypot(x + .5 - cx, y + .5 - cy) / (r + .5)
                    k = min(len(gr) - 1, int(d * len(gr)))
                    px[x, y] = hexc(gr[len(gr) - 1 - k]); continue
                lvl = 2.0
                t = (y - cajas[l][0]) / max(1, cajas[l][1] - cajas[l][0])
                if t < .3: lvl += .5
                if t > .72: lvl -= .5
                if L(x, y - 1) != l: lvl += 1.5
                elif L(x, y - 2) != l: lvl += .5
                if L(x, y + 1) != l: lvl -= 1.5
                if (L(x - 1, y) != l or L(x + 1, y) != l) and L(x, y - 1) == l: lvl -= .7
                lvl = max(0, min(len(ramp) - 1, lvl))
                base = int(lvl); frac = lvl - base
                if frac >= .5 and (x + y) % 2 == 0 and base + 1 < len(ramp): base += 1   # tramado
                px[x, y] = hexc(ramp[base])
        for x, y, tipo in s.extra:
            if not (0 <= x < s.w and 0 <= y < s.h) or not lab[y][x] or lab[y][x] in s.glows: continue
            ramp = s.mats[lab[y][x]]
            if tipo == 'surco':
                px[x, y] = hexc(ramp[0])
                if y + 1 < s.h and lab[y + 1][x] == lab[y][x]: px[x, y + 1] = hexc(ramp[min(len(ramp) - 1, 3)])
            elif tipo == 'remache':
                px[x, y] = hexc(ramp[-1])
                if y + 1 < s.h and lab[y + 1][x]: px[x, y + 1] = hexc(ramp[0])
        # contorno exterior
        out = img.copy(); po = out.load()
        for y in range(s.h):
            for x in range(s.w):
                if lab[y][x]: continue
                if any(L(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    po[x, y] = OUTLINE
        return out.resize((s.w * ESC, s.h * ESC), Image.NEAREST)

    def boca(s, p):
        return [round((p[0] + .5 - s.w / 2) * ESC), round((p[1] + .5 - s.h / 2) * ESC)]

ACERO = ['#141a26', '#26324a', '#3d5172', '#62809e', '#9cc0d6', '#dcefff']
OSCURO = ['#0c0e16', '#181c2a', '#262c40', '#3a4258', '#55607a']
NARANJA = ['#3a1408', '#7a2c0c', '#c45a14', '#f09a2c', '#ffd27a']
GLOW_NAR = ['#702008', '#e05a10', '#ffa030', '#ffe090', '#ffffff']
QUITINA = ['#140a1e', '#2a1440', '#462468', '#6a3c94', '#9a6cc4', '#d0b0ee']
VERDE = ['#08200e', '#145a24', '#2aa040', '#6ee070', '#c8ffb0']
GLOW_VERDE = ['#104a10', '#30c030', '#80ff60', '#d8ffc0', '#ffffff']
MEMBRANA = ['#2a2048', '#46407a', '#6c68a8', '#9c9ad0', '#cfd0f0']
VACIO_M = ['#08040e', '#160a24', '#2a1442', '#462270', '#6c3aa0', '#a070d8']
NEGRO = ['#030206', '#08050f', '#120a1e', '#1c1030']
GLOW_MAG = ['#50083a', '#b0207a', '#ff4ab8', '#ffb0e8', '#ffffff']

def centinela():
    c = Lienzo(170, 110); W = 170
    # aletas traseras
    c.poly([(62, 24), (38, 6), (34, 12), (52, 32)], ACERO)
    # puentes a las cápsulas
    c.poly([(46, 44), (62, 40), (62, 62), (46, 66)], OSCURO)
    # cápsulas laterales y sus cañones
    c.poly([(18, 40), (26, 32), (44, 32), (52, 40), (52, 74), (44, 82), (26, 82), (18, 74)], ACERO)
    c.rect((29, 80, 39, 98), OSCURO, espejo=True)
    c.rect((27, 94, 41, 99), NARANJA, espejo=True)
    c.rect((20, 46, 50, 52), NARANJA, espejo=True)
    # casco central
    c.poly([(85, 6), (108, 16), (116, 34), (118, 62), (104, 92), (66, 92), (52, 62), (54, 34), (62, 16)], ACERO, espejo=False)
    c.poly([(70, 70), (100, 70), (96, 90), (74, 90)], OSCURO, espejo=False)
    c.rect((80, 86, 90, 104), OSCURO)
    c.rect((78, 100, 92, 105), NARANJA)
    c.elipse((70, 12, 100, 34), ACERO)
    c.elipse((76, 16, 94, 28), OSCURO)
    # ojo núcleo
    c.elipse((70, 44, 100, 72), OSCURO)
    c.elipse((74, 48, 96, 68), NARANJA, glow=GLOW_NAR)
    c.elipse((18, 55, 26, 63), NARANJA, espejo=True, glow=GLOW_NAR)
    c.elipse((80, 19, 90, 25), NARANJA, glow=GLOW_NAR)
    # detalles
    c.linea((62, 38), (68, 40)); c.linea((56, 64), (66, 80)); c.linea((22, 70), (48, 70))
    c.linea((24, 40), (46, 40)); c.linea((40, 10), (52, 26))
    for p in [(60, 30), (58, 50), (64, 84), (24, 36), (46, 78), (24, 78), (46, 36)]: c.remache(p)
    img = c.render()
    return img, {"nucleo": c.boca((85, 58)), "canones": [c.boca((34, 99)), c.boca((W - 1 - 34, 99))], "alas": [c.boca((22, 59)), c.boca((W - 1 - 22, 59))]}

def colmena():
    c = Lienzo(180, 124); W = 180
    # alas membranosas
    c.poly([(70, 40), (24, 8), (6, 26), (12, 56), (62, 62)], MEMBRANA)
    c.poly([(66, 62), (24, 72), (18, 94), (40, 92), (66, 76)], MEMBRANA)
    for a, b in [((66, 44), (14, 22)), ((64, 50), (10, 42)), ((62, 56), (18, 56)), ((64, 68), (24, 84))]:
        c.linea(a, b)
    # patas
    for a, b in [((72, 60), (48, 100)), ((74, 66), (58, 110)), ((70, 54), (40, 86))]:
        c.poly([a, (a[0] + 3, a[1] + 2), (b[0] + 2, b[1]), b], OSCURO)
    # abdomen con franjas
    c.elipse((60, 2, 120, 52), QUITINA)
    for y in (12, 22, 32, 42):
        c.linea((66, y), (89, y + 3))
    c.elipse((64, 18, 74, 28), VERDE, espejo=True, glow=GLOW_VERDE)
    # tórax y cabeza
    c.elipse((68, 38, 112, 74), QUITINA)
    c.elipse((82, 48, 98, 62), VERDE, glow=GLOW_VERDE)
    c.poly([(74, 68), (106, 68), (102, 92), (90, 100), (78, 92)], QUITINA, espejo=False)
    c.elipse((76, 72, 86, 82), VERDE, espejo=True, glow=GLOW_VERDE)
    # mandíbulas
    c.poly([(80, 88), (68, 100), (70, 116), (76, 112), (78, 102), (86, 96)], QUITINA)
    c.linea((76, 92), (72, 108))
    for p in [(70, 46), (74, 36), (80, 84), (66, 10)]: c.remache(p)
    img = c.render()
    return img, {"nucleo": c.boca((90, 55)), "canones": [c.boca((70, 115)), c.boca((W - 1 - 70, 115))], "alas": [c.boca((10, 34)), c.boca((W - 1 - 10, 34))]}

def vacio():
    c = Lienzo(150, 150); W = 150; cx = cy = 74.5
    # púas alrededor del anillo
    for ang in (90, 30, 330, 270):
        if ang in (90, 270):
            esp = False
        a = math.radians(ang)
        d = (math.cos(a), math.sin(a)); n = (-d[1], d[0])
        base = (cx + d[0] * 50, cy + d[1] * 50); punta = (cx + d[0] * 72, cy + d[1] * 72)
        pts = [(base[0] + n[0] * 9, base[1] + n[1] * 9), punta, (base[0] - n[0] * 9, base[1] - n[1] * 9)]
        c.poly(pts, VACIO_M, espejo=ang in (30, 330))
    c.elipse((16, 16, 133, 133), VACIO_M)
    c.elipse((30, 30, 119, 119), NEGRO)
    for k in range(12):
        a = math.radians(k * 30 + 15)
        c.linea((round(cx + math.cos(a) * 52), round(cy + math.sin(a) * 52)), (round(cx + math.cos(a) * 58), round(cy + math.sin(a) * 58)), espejo=False)
    c.elipse((10, 66, 26, 82), VACIO_M, espejo=True)
    c.elipse((13, 69, 23, 79), GLOW_MAG, espejo=True, glow=GLOW_MAG)
    c.elipse((56, 56, 93, 93), VACIO_M)
    c.elipse((61, 61, 88, 88), GLOW_MAG, glow=GLOW_MAG)
    for k in range(6):
        a = math.radians(k * 60 + 30)
        p = (round(cx + math.cos(a) * 44), round(cy + math.sin(a) * 44))
        c.elipse((p[0] - 3, p[1] - 3, p[0] + 3, p[1] + 3), GLOW_MAG, glow=GLOW_MAG)
    img = c.render()
    def polar(ang, r): return (cx + math.cos(math.radians(ang)) * r, cy + math.sin(math.radians(ang)) * r)
    return img, {"nucleo": c.boca((74, 74)), "canones": [c.boca(polar(150, 64)), c.boca(polar(30, 64))], "alas": [c.boca((17, 74)), c.boca((W - 1 - 17, 74))]}

if __name__ == '__main__':
    datos = {}
    for nombre, f in [('centinela', centinela), ('colmena', colmena), ('vacio', vacio)]:
        img, bocas = f()
        img.save(f'art/jefes/{nombre}.png')
        datos[nombre] = {"tam": img.size, **bocas}
    print(json.dumps(datos))
