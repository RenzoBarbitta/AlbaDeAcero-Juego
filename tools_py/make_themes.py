#!/usr/bin/env python3
"""Genera por código el arte de cada etapa: cielo, 3 capas de parallax y tiles.
Todo es original (procedural) y se puede regenerar con otra semilla/paleta.
Uso (desde la raíz del proyecto): python3 tools_py/make_themes.py"""
import math, random, os, shutil
from PIL import Image, ImageDraw

W, H = 480, 180

def hx(s, a=255):
    s = s.lstrip('#')
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)

def mix(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3)) + (255,)

def shade(c, k):
    if k >= 0:
        return mix(c, (255, 255, 255, 255), k)
    return mix(c, (0, 0, 0, 255), -k)

THEMES = {
 'fundicion': dict(sky=('#1a0d14', '#9a3f1c'), stars=False, glow='#ff8c42',
    far=('#3c1a18', 'jagged', 62, 40), mid=('#2a1411', 'chimneys', '#ff9a3c'),
    near=('#150a0a', 'pipes'), tile=('plates', '#5a3a34', '#b0704c', '#2c1816', '#ff8c42'),
    spike='#d9d2c8', spike_base='#ff8c42', sun=None),
 'ruinas': dict(sky=('#1d0f22', '#b84a3c'), stars=True, glow='#ff7a5a',
    far=('#3d1a28', 'jagged', 54, 34), mid=('#33141f', 'ruins', '#ffb05c'),
    near=('#180a10', 'rocks'), tile=('brick', '#6c4a4c', '#b07a74', '#33201f', '#e5402f'),
    spike='#cfc6c0', spike_base='#e5402f', sun=None, moon='#ffb8a0', moon_pos=(120, 34)),
 'glaciar': dict(sky=('#08183a', '#79cdee'), stars=True, glow='#bff0ff',
    far=('#2c5c92', 'peaks', 66, 30), mid=('#3d86b8', 'icetowers', '#e8fbff'),
    near=('#1c4e80', 'crystals'), tile=('ice', '#78b4de', '#eaf9ff', '#3a76a6', '#ffffff'),
    spike='#dff6ff', spike_base='#3a76a6', sun=None, aurora=True, moon='#f4fcff', moon_pos=(70, 22)),
 'volcan': dict(sky=('#110505', '#d24a1a'), stars=False, glow='#ff6a2a',
    far=('#2a0e0c', 'volcano', 80, 40), mid=('#240d0d', 'spires', '#ff5a2a'),
    near=('#100606', 'basalt'), tile=('rock', '#3c2c30', '#7a4a42', '#1c1214', '#ff5a2a'),
    spike='#b8a8a0', spike_base='#ff5a2a', sun=None),
 'central': dict(sky=('#07111b', '#1f8090'), stars=True, glow='#5ff0ff',
    far=('#0f2e3a', 'smooth', 40, 22), mid=('#12303c', 'pylons', '#ffd15c'),
    near=('#08161e', 'poles'), tile=('plates', '#31606c', '#74b4bc', '#16323a', '#ffd15c'),
    spike='#d8e4e8', spike_base='#ffd15c', sun=None, moon='#b8fbff', moon_pos=(430, 30)),
 'cantera': dict(sky=('#2d1a3c', '#f09a58'), stars=False, glow='#ffd08a',
    far=('#85503e', 'mesa', 64, 34), mid=('#68382f', 'mesas', '#ffcf8a'),
    near=('#2c1a1a', 'rocks'), tile=('rock', '#b48c5e', '#e8c890', '#6c4a32', '#ffe0a0'),
    spike='#e0d4c0', spike_base='#8a5a38', sun=('#ffe6a8', 46, 54, 26)),
 'biolab': dict(sky=('#04150f', '#27854f'), stars=True, glow='#8aff9a',
    far=('#0f3b2a', 'smooth', 46, 26), mid=('#0d3a2a', 'domes', '#8aff9a'),
    near=('#06150e', 'vines'), tile=('organic', '#30704c', '#7fd08a', '#133a28', '#b8ff8a'),
    spike='#d8f0d0', spike_base='#8aff9a', sun=None, moon='#d8ffc8', moon_pos=(250, 30)),
}

# ------------------------------------------------------------------ cielo
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

def make_sky(th, rnd):
    top, bot = hx(th['sky'][0]), hx(th['sky'][1])
    img = Image.new('RGBA', (W, H))
    px = img.load()
    bands = 14
    for y in range(H):
        t = y / (H - 1)
        t = t ** 1.35
        f = t * (bands - 1)
        b0 = int(f)
        frac = f - b0
        for x in range(W):
            thr = BAYER[y % 4][x % 4] / 16.0
            b = b0 + (1 if frac > thr else 0)
            px[x, y] = mix(top, bot, min(1.0, b / (bands - 1)))
    d = ImageDraw.Draw(img)
    if th.get('stars'):
        for _ in range(110):
            x, y = rnd.randrange(W), rnd.randrange(int(H * 0.7))
            c = rnd.choice([(255, 255, 255, 255), (190, 215, 255, 255), (255, 235, 190, 255)])
            d.point((x, y), c)
            if rnd.random() < 0.12:
                d.point((x + 1, y), c); d.point((x, y + 1), c)
    if th.get('aurora'):
        for k, col in enumerate([(120, 255, 200), (140, 200, 255)]):
            for x in range(W):
                yy = 34 + k * 14 + int(10 * math.sin(x / 480 * 2 * math.pi * 2 + k) + 5 * math.sin(x / 480 * 2 * math.pi * 5))
                for dy in range(0, 9):
                    a = int(120 * (1 - dy / 9))
                    base = px[x, yy + dy]
                    px[x, yy + dy] = tuple(int(base[i] + (col[i] - base[i]) * a / 255) for i in range(3)) + (255,)
    if th['sun']:
        c, cx, cy, r = th['sun']
        c = hx(c)
        for rr, al in [(r + 14, 0.12), (r + 7, 0.2)]:
            d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=mix(px[cx, min(cy + rr, H - 1)], c, al))
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=c)
    elif th.get('stars'):
        cx, cy = th.get('moon_pos', (392, 40))
        r = 7
        mc = hx(th.get('moon', '#ebf0ff'))
        d.ellipse((cx - 14, cy - 14, cx + 14, cy + 14), fill=mix(px[cx, cy], mc, 0.12))
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=mc)
        d.ellipse((cx - r + 2, cy - r + 1, cx - r + 4, cy - r + 3), fill=shade(mc, -0.12))
    # horizonte brillante
    g = hx(th['glow'])
    for y in range(H - 34, H):
        t = (y - (H - 34)) / 34.0
        for x in range(W):
            if BAYER[y % 4][x % 4] / 16.0 < t * 0.35:
                px[x, y] = mix(px[x, y], g, 0.28)
    return img

# ------------------------------------------------------------------ helpers de capa
def wrap_call(fn, x, w):
    fn(x)
    if x + w > W: fn(x - W)
    if x < 0: fn(x + W)

def ridge_heights(kind, amp, rnd):
    ph = [rnd.random() * 6.28 for _ in range(6)]
    hs = []
    for x in range(W):
        t = x / W * 2 * math.pi
        if kind == 'smooth':
            v = 0.5 + 0.28 * math.sin(2 * t + ph[0]) + 0.17 * math.sin(3 * t + ph[1]) + 0.08 * math.sin(7 * t + ph[2])
        elif kind == 'jagged':
            v = 0.45 + 0.25 * abs(math.sin(3 * t + ph[0])) + 0.2 * abs(math.sin(5 * t + ph[1])) + 0.1 * math.sin(11 * t + ph[2])
        elif kind == 'peaks':
            a = abs(math.sin(2.5 * t + ph[0])); b = abs(math.sin(4.0 * t + ph[1]))
            v = 0.15 + 0.55 * (a ** 2.2) + 0.3 * (b ** 3)
        elif kind == 'volcano':
            c = math.cos(t - math.pi)
            v = 0.25 + 0.55 * max(0.0, 1 - abs(((x - 330) % W if (x - 330) % W < W / 2 else (x - 330) % W - W)) / 150) \
                + 0.12 * abs(math.sin(5 * t + ph[0]))
        else:  # mesa
            raw = 0.4 + 0.3 * math.sin(2 * t + ph[0]) + 0.2 * math.sin(3 * t + ph[1])
            v = round(raw * 5) / 5.0
        hs.append(v)
    return hs

def draw_ridge(img, base_y, amp, kind, col, rnd, rim=None):
    d = ImageDraw.Draw(img)
    hs = ridge_heights(kind, amp, rnd)
    for x in range(W):
        top = int(base_y - hs[x] * amp)
        d.line((x, top, x, H), fill=col)
        if rim:
            d.point((x, top), rim)
            if kind in ('peaks', 'volcano'):
                d.point((x, top + 1), rim)
    if kind == 'volcano':
        cx = 330
        top = int(base_y - hs[cx] * amp)
        d.ellipse((cx - 9, top - 2, cx + 9, top + 4), fill=(255, 120, 50, 255))
        d.ellipse((cx - 5, top - 1, cx + 5, top + 2), fill=(255, 210, 120, 255))
        for k in range(12):
            d.point((cx - 3 + (k * 5) % 7 - k // 3, top + 5 + k * 2), (255, 100, 40, 255))

# ------------------------------------------------------------------ capa media
def mid_layer(style, col, light, rnd):
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = hx(col); lc = hx(light)
    top_edge = shade(c, 0.16)
    base = H - 6

    if style in ('chimneys', 'ruins', 'buildings'):
        x = rnd.randrange(0, 20)
        while x < W - 14:
            w = rnd.randrange(26, 52)
            h = rnd.randrange(44, 100) if style != 'chimneys' else rnd.randrange(30, 62)
            def draw(xx, w=w, h=h):
                top = base - h
                if style == 'ruins':
                    pts = [(xx, base), (xx, top + rnd.randrange(0, 12))]
                    sx = xx
                    while sx < xx + w:
                        sx += rnd.randrange(4, 9)
                        pts.append((min(sx, xx + w), top + rnd.randrange(-6, 14)))
                    pts += [(xx + w, base)]
                    d.polygon(pts, fill=c)
                else:
                    d.rectangle((xx, top, xx + w, base), fill=c)
                    d.line((xx, top, xx + w, top), fill=top_edge)
                for wy in range(top + 6, base - 6, 7):
                    for wx in range(xx + 4, xx + w - 3, 6):
                        if rnd.random() < (0.35 if style != 'ruins' else 0.12):
                            d.rectangle((wx, wy, wx + 1, wy + 2), fill=lc)
                if style == 'chimneys':
                    cw = 7
                    cx0 = xx + rnd.randrange(4, max(5, w - 12))
                    ch = rnd.randrange(24, 46)
                    d.rectangle((cx0, top - ch, cx0 + cw, top), fill=shade(c, 0.05))
                    d.rectangle((cx0 - 1, top - ch, cx0 + cw + 1, top - ch + 2), fill=shade(c, 0.22))
                    for k in range(4):
                        r = 4 + k * 2
                        d.ellipse((cx0 + 2 - r + k * 3, top - ch - 6 - k * 9 - r, cx0 + 2 + r + k * 3, top - ch - 6 - k * 9 + r),
                                  fill=mix(c, hx('#6a5a58'), 0.18 + 0.05 * k))
                if style == 'buildings' and rnd.random() < 0.5:
                    d.line((xx + w // 2, top - 8, xx + w // 2, top), fill=top_edge)
            wrap_call(draw, x, w)
            x += w + rnd.randrange(2, 10)
    elif style in ('icetowers', 'spires'):
        x = rnd.randrange(0, 20)
        while x < W - 10:
            w = rnd.randrange(16, 32)
            h = rnd.randrange(54, 112)
            def draw(xx, w=w, h=h):
                tip = (xx + w // 2 + rnd.randrange(-3, 4), base - h)
                d.polygon([(xx, base), (xx + 2, base - h * 0.55), tip, (xx + w - 2, base - h * 0.5), (xx + w, base)], fill=c)
                d.polygon([(xx + w // 2, base), tip, (xx + w - 2, base - h * 0.5), (xx + w, base)], fill=shade(c, -0.14))
                d.line((tip[0], tip[1], xx + 2, base - h * 0.55), fill=lc if style == 'icetowers' else shade(c, 0.35))
                if style == 'spires':
                    for k in range(5):
                        yy = base - 6 - k * 14
                        d.line((xx + w // 2 - 2, yy, xx + w // 2 + 2, yy + 3), fill=lc)
            wrap_call(draw, x, w)
            x += w + rnd.randrange(-6, 12)
    elif style == 'mesas':
        x = rnd.randrange(0, 20)
        while x < W - 10:
            w = rnd.randrange(42, 80)
            h = rnd.randrange(40, 90)
            def draw(xx, w=w, h=h):
                top = base - h
                d.polygon([(xx, base), (xx + 6, top + 8), (xx + 10, top), (xx + w - 10, top), (xx + w - 6, top + 8), (xx + w, base)], fill=c)
                for k in range(1, 6):
                    yy = top + k * (h // 6)
                    d.line((xx + 4 - k, yy, xx + w - 4 + k, yy), fill=shade(c, 0.08 if k % 2 else -0.1))
                d.line((xx + 10, top, xx + w - 10, top), fill=lc)
            wrap_call(draw, x, w)
            x += w + rnd.randrange(8, 36)
    elif style == 'domes':
        x = rnd.randrange(0, 20)
        while x < W - 10:
            w = rnd.randrange(46, 90)
            h = int(w * rnd.uniform(0.42, 0.62))
            def draw(xx, w=w, h=h):
                d.pieslice((xx, base - h, xx + w, base + h), 180, 360, fill=c)
                d.arc((xx, base - h, xx + w, base + h), 180, 360, fill=shade(c, 0.25))
                for k in range(1, 4):
                    d.arc((xx + k * w // 8, base - h, xx + w - k * w // 8, base + h), 180, 360, fill=shade(c, 0.09))
                d.ellipse((xx + w // 2 - 3, base - h // 2 - 3, xx + w // 2 + 3, base - h // 2 + 3), fill=lc)
                d.rectangle((xx + w // 2 - 1, base - 6, xx + w // 2 + 1, base), fill=lc)
            wrap_call(draw, x, w)
            x += w + rnd.randrange(4, 24)
    elif style == 'pylons':
        x = rnd.randrange(0, 30)
        pts = []
        while x < W - 20:
            h = rnd.randrange(86, 124)
            def draw(xx, h=h):
                tp = (xx, base - h)
                d.polygon([(xx - 14, base), tp, (xx + 14, base)], outline=shade(c, 0.28))
                for k in range(1, 7):
                    yy = base - k * h // 7
                    half = int(14 * (yy - tp[1]) / h)
                    d.line((xx - half, yy, xx + half, yy), fill=shade(c, 0.2))
                d.line((xx - 22, tp[1] + 12, xx + 22, tp[1] + 12), fill=shade(c, 0.3))
                d.ellipse((xx - 2, tp[1] - 2, xx + 2, tp[1] + 2), fill=lc)
                d.ellipse((xx - 24, tp[1] + 10, xx - 20, tp[1] + 14), fill=lc)
                d.ellipse((xx + 20, tp[1] + 10, xx + 24, tp[1] + 14), fill=lc)
            wrap_call(draw, x, 30)
            pts.append((x, h))
            x += rnd.randrange(80, 120)
        for i in range(len(pts)):
            x0, h0 = pts[i]
            x1, h1 = pts[(i + 1) % len(pts)]
            if x1 < x0: x1 += W
            for s in (-22, 22):
                for xx in range(int(x0 + 22), int(x1 - 22)):
                    t = (xx - (x0 + 22)) / max(1, (x1 - 22) - (x0 + 22))
                    y = (base - h0 + 12) * (1 - t) + (base - h1 + 12) * t + 14 * math.sin(t * math.pi)
                    d.point((xx % W, int(y)), shade(c, 0.22))
                break
    # suelo de la capa
    d.rectangle((0, base, W, H), fill=c)
    return img

# ------------------------------------------------------------------ capa cercana
def near_layer(style, col, rnd):
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = hx(col)
    rim = shade(c, 0.22)
    base = H - 8
    # ondulaciones del suelo
    for x in range(W):
        y = base + 4 + int(3 * math.sin(x / W * 2 * math.pi * 3) + 2 * math.sin(x / W * 2 * math.pi * 7))
        d.line((x, y, x, H), fill=c)
    if style == 'poles':
        for x in range(30, W, 120):
            wrap_call(lambda xx: (d.rectangle((xx, 20, xx + 2, H), fill=c), d.rectangle((xx - 10, 28, xx + 12, 30), fill=c),
                                  d.rectangle((xx - 10, 40, xx + 12, 41), fill=c), d.point((xx + 1, 18), (255, 90, 90, 255))), x, 4)
        for x in range(0, W, 120):
            for xx in range(x + 30, x + 150):
                d.point((xx % W, 30 + int(8 * math.sin((xx - x - 30) / 120 * math.pi))), rim)
    elif style in ('pipes', 'basalt'):
        for x in range(10, W, 60):
            h = rnd.randrange(34, 86)
            w = 9 if style == 'pipes' else 13
            def draw(xx, h=h, w=w):
                d.rectangle((xx, base - h, xx + w, H), fill=c)
                d.line((xx + 1, base - h, xx + 1, H), fill=rim)
                if style == 'pipes':
                    d.rectangle((xx - 2, base - h, xx + w + 2, base - h + 3), fill=rim)
                    d.rectangle((xx - 2, base - h // 2, xx + w + 2, base - h // 2 + 2), fill=rim)
                else:
                    d.polygon([(xx, base - h), (xx + w, base - h), (xx + w - 2, base - h - 5), (xx + 2, base - h - 4)], fill=c)
            wrap_call(draw, x, 14)
    elif style in ('crystals', 'rocks'):
        for x in range(0, W, 38):
            xx0 = x + rnd.randrange(0, 20)
            for k in range(rnd.randrange(2, 4)):
                w = rnd.randrange(8, 16); h = rnd.randrange(14, 46) if style == 'crystals' else rnd.randrange(10, 26)
                def draw(xx, w=w, h=h, k=k):
                    xx += k * 7
                    if style == 'crystals':
                        d.polygon([(xx, base + 6), (xx + 2, base - h + 8), (xx + w // 2, base - h), (xx + w - 2, base - h + 8), (xx + w, base + 6)], fill=c)
                        d.line((xx + w // 2, base - h, xx + 2, base - h + 8), fill=rim)
                    else:
                        d.polygon([(xx, base + 6), (xx + 3, base - h + 4), (xx + w // 2, base - h), (xx + w, base - h + 6), (xx + w + 2, base + 6)], fill=c)
                        d.line((xx + 3, base - h + 4, xx + w // 2, base - h), fill=rim)
                wrap_call(draw, xx0, w + 20)
    elif style == 'vines':
        for x in range(8, W, 44):
            h = rnd.randrange(30, 70)
            def draw(xx, h=h):
                pts = []
                for t in range(0, h, 2):
                    pts.append((xx + int(4 * math.sin(t / 9.0)), base - t))
                d.line(pts, fill=c, width=2)
                d.ellipse((xx - 7, base - h - 4, xx + 7, base - h + 4), fill=c)
                d.point((xx - 3, base - h - 2), rim); d.point((xx + 2, base - h - 1), rim)
            wrap_call(draw, x, 16)
    return img

# ------------------------------------------------------------------ tiles
def body_pattern(style, base, light, dark, accent, rnd):
    img = Image.new('RGBA', (16, 16), base)
    d = ImageDraw.Draw(img)
    if style == 'plates':
        d.rectangle((0, 0, 15, 15), outline=dark)
        d.line((1, 1, 14, 1), fill=shade(base, 0.12)); d.line((1, 1, 1, 14), fill=shade(base, 0.12))
        for p in ((3, 3), (12, 3), (3, 12), (12, 12)):
            d.point(p, light); d.point((p[0] + 1, p[1] + 1), dark)
        d.line((5, 8, 10, 8), fill=dark); d.point((8, 8), accent)
    elif style == 'brick':
        d.rectangle((0, 0, 15, 15), fill=base)
        for row in range(4):
            y = row * 4
            d.line((0, y, 15, y), fill=dark)
            off = 0 if row % 2 == 0 else 4
            for x in range(off, 16, 8):
                d.line((x, y, x, y + 3), fill=dark)
            for x in range(off + 1, 16, 8):
                d.line((x, y + 1, min(15, x + 5), y + 1), fill=shade(base, 0.15))
        d.point((rnd.randrange(16), rnd.randrange(16)), accent)
    elif style == 'ice':
        for _ in range(26):
            d.point((rnd.randrange(16), rnd.randrange(16)), shade(base, 0.12 if rnd.random() < 0.5 else -0.1))
        d.line((2, 4, 6, 8), fill=light); d.line((6, 8, 5, 12), fill=light); d.line((10, 2, 13, 7), fill=shade(base, 0.35))
        d.line((0, 15, 15, 15), fill=dark)
    elif style == 'rock':
        for _ in range(40):
            d.point((rnd.randrange(16), rnd.randrange(16)), shade(base, rnd.choice([-0.12, 0.1, 0.18])))
        d.line((1, 6, 8, 6), fill=dark); d.line((8, 6, 8, 12), fill=dark); d.line((8, 12, 15, 12), fill=dark)
        d.point((3, 3), accent)
    else:  # organic
        for _ in range(34):
            d.point((rnd.randrange(16), rnd.randrange(16)), shade(base, rnd.choice([-0.14, 0.12])))
        d.ellipse((4, 6, 9, 11), outline=dark)
        d.point((6, 8), accent)
        d.line((11, 2, 13, 5), fill=dark)
    return img

def make_tiles(name, th, outdir, rnd):
    style, base, light, dark, accent = th['tile']
    base, light, dark, accent = hx(base), hx(light), hx(dark), hx(accent)
    body = body_pattern(style, base, light, dark, accent, rnd)
    body.save(os.path.join(outdir, 'tile_mid.png'))
    top = body.copy()
    d = ImageDraw.Draw(top)
    d.rectangle((0, 0, 15, 2), fill=shade(base, 0.2))
    d.line((0, 0, 15, 0), fill=light)
    d.line((0, 2, 15, 2), fill=accent if style in ('plates', 'brick', 'rock') else shade(base, -0.1))
    d.line((0, 3, 15, 3), fill=dark)
    if style in ('organic', 'ice'):
        for x in range(0, 16, 3):
            d.point((x, 3), light); d.point((x + 1, 4), shade(light, -0.1))
    top.save(os.path.join(outdir, 'tile_top.png'))
    # plataforma flotante: superficie + bloque + luces inferiores
    pl = Image.new('RGBA', (16, 16), dark)
    d = ImageDraw.Draw(pl)
    d.rectangle((0, 0, 15, 10), fill=base)
    d.line((0, 0, 15, 0), fill=light)
    d.line((0, 1, 15, 1), fill=shade(base, 0.18))
    d.line((0, 10, 15, 10), fill=dark)
    d.rectangle((0, 11, 15, 15), fill=shade(dark, -0.2))
    d.line((0, 11, 15, 11), fill=shade(base, -0.28))
    d.rectangle((6, 13, 9, 14), fill=accent)
    d.point((2, 5), dark); d.point((13, 5), dark); d.line((4, 6, 11, 6), fill=shade(base, -0.12))
    pl.save(os.path.join(outdir, 'tile_platform.png'))
    # plataforma que se desmorona
    cr = pl.copy()
    d = ImageDraw.Draw(cr)
    d.line((3, 2, 6, 7), fill=dark); d.line((6, 7, 5, 10), fill=dark)
    d.line((11, 1, 9, 5), fill=dark); d.line((9, 5, 12, 9), fill=dark)
    d.line((0, 0, 15, 0), fill=shade(accent, -0.1))
    for x in (1, 7, 13): d.point((x, 12), accent)
    cr.save(os.path.join(outdir, 'tile_crumble.png'))
    # pinchos
    sp = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(sp)
    sc, sb = hx(th['spike']), hx(th['spike_base'])
    d.rectangle((0, 12, 15, 15), fill=shade(sb, -0.35))
    for x in range(0, 16, 4):
        d.polygon([(x, 12), (x + 2, 1), (x + 4, 12)], fill=sc)
        d.polygon([(x + 2, 1), (x + 4, 12), (x + 2, 12)], fill=shade(sc, -0.3))
        d.point((x + 2, 1), sb)
    d.line((0, 12, 15, 12), fill=sb)
    sp.save(os.path.join(outdir, 'spike.png'))

# ------------------------------------------------------------------ main
def build():
    root = 'assets/sprites/themes'
    os.makedirs(root, exist_ok=True)
    # la etapa nocturna conserva el arte original del juego
    ciudad = os.path.join(root, 'ciudad')
    os.makedirs(ciudad, exist_ok=True)
    src = 'assets/sprites/tiles'
    for a, b in [('bg_sky.png', 'bg_sky.png'), ('bg_far.png', 'bg_far.png'), ('bg_mid.png', 'bg_mid.png'),
                 ('bg_near.png', 'bg_near.png'), ('tile_top.png', 'tile_top.png'), ('tile_mid.png', 'tile_mid.png'),
                 ('tile_platform.png', 'tile_platform.png'), ('spike.png', 'spike.png')]:
        if os.path.exists(os.path.join(src, a)):
            shutil.copy(os.path.join(src, a), os.path.join(ciudad, b))
    # variante desmoronable de la ciudad
    if os.path.exists(os.path.join(ciudad, 'tile_platform.png')):
        im = Image.open(os.path.join(ciudad, 'tile_platform.png')).convert('RGBA')
        d = ImageDraw.Draw(im)
        d.line((3, 2, 6, 7), fill=(10, 10, 20, 255)); d.line((6, 7, 5, 10), fill=(10, 10, 20, 255))
        d.line((11, 1, 9, 5), fill=(10, 10, 20, 255)); d.line((9, 5, 12, 9), fill=(10, 10, 20, 255))
        for x in (1, 7, 13): d.point((x, 12), (255, 140, 66, 255))
        im.save(os.path.join(ciudad, 'tile_crumble.png'))
    for i, (name, th) in enumerate(THEMES.items()):
        rnd = random.Random(1000 + i * 37)
        out = os.path.join(root, name)
        os.makedirs(out, exist_ok=True)
        make_sky(th, rnd).save(os.path.join(out, 'bg_sky.png'))
        far = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        draw_ridge(far, 130, th['far'][2], th['far'][1], hx(th['far'][0]), rnd, rim=shade(hx(th['far'][0]), 0.25))
        far.save(os.path.join(out, 'bg_far.png'))
        mid_layer(th['mid'][1], th['mid'][0], th['mid'][2], rnd).save(os.path.join(out, 'bg_mid.png'))
        near_layer(th['near'][1], th['near'][0], rnd).save(os.path.join(out, 'bg_near.png'))
        make_tiles(name, th, out, rnd)
        print('tema', name)

if __name__ == '__main__':
    build()
