#!/usr/bin/env python3
"""Sprites nuevos: resorte, checkpoint, mina, chip, tobera de llamas e icono."""
from PIL import Image, ImageDraw
import os
OUT = (10, 10, 20, 255)
def C(h, a=255):
    h = h.lstrip('#'); return (int(h[0:2],16), int(h[2:4],16), int(h[4:6],16), a)
os.makedirs('assets/sprites/world', exist_ok=True)

def spring(extended):
    h = 14 if extended else 9
    im = Image.new('RGBA', (16, 14), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    bot = 13
    d.rectangle((1, bot - 3, 14, bot), fill=C('#454c73'), outline=OUT)
    d.line((2, bot - 3, 13, bot - 3), fill=C('#7d86a8'))
    top = bot - h + 1
    y = bot - 4; flip = False
    while y > top + 3:
        d.line((4, y, 11, y - 2) if not flip else (11, y, 4, y - 2), fill=C('#d7dbe6'))
        d.line((4, y + 1, 11, y - 1) if not flip else (11, y + 1, 4, y - 1), fill=OUT)
        y -= 2; flip = not flip
    d.rectangle((1, top, 14, top + 2), fill=C('#ffd15c'), outline=OUT)
    d.line((2, top + 1, 13, top + 1), fill=C('#fff0a8'))
    return im
spring(False).save('assets/sprites/world/spring_0.png')
spring(True).save('assets/sprites/world/spring_1.png')

def checkpoint(on):
    im = Image.new('RGBA', (16, 32), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rectangle((3, 28, 12, 31), fill=C('#454c73'), outline=OUT)
    d.line((4, 28, 11, 28), fill=C('#7d86a8'))
    d.rectangle((7, 4, 8, 28), fill=C('#a8b0c0'), outline=OUT)
    d.rectangle((6, 2, 9, 4), fill=C('#ffd15c' if on else '#5a6070'), outline=OUT)
    col = C('#59d0ff') if on else C('#5a6070')
    lig = C('#c8f4ff') if on else C('#7d86a8')
    d.polygon([(9, 6), (15, 8), (15, 13), (9, 15)], fill=col, outline=OUT)
    d.line((10, 8, 14, 9), fill=lig)
    if on: d.point((12, 11), C('#ffffff'))
    return im
checkpoint(False).save('assets/sprites/world/checkpoint_off.png')
checkpoint(True).save('assets/sprites/world/checkpoint_on.png')

def mine(armed):
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    for (x1, y1, x2, y2) in [(8,0,8,3),(8,12,8,15),(0,8,3,8),(12,8,15,8),(2,2,4,4),(11,11,13,13),(2,13,4,11),(11,4,13,2)]:
        d.line((x1, y1, x2, y2), fill=C('#a8b0c0'))
    d.ellipse((3, 3, 12, 12), fill=C('#3a4056'), outline=OUT)
    d.arc((4, 4, 11, 11), 200, 290, fill=C('#7d86a8'))
    d.ellipse((6, 6, 9, 9), fill=C('#ff3b3b') if armed else C('#7a1c24'), outline=OUT)
    return im
mine(False).save('assets/sprites/world/mine_0.png')
mine(True).save('assets/sprites/world/mine_1.png')

im = Image.new('RGBA', (10, 10), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
d.polygon([(5,0),(9,2),(9,7),(5,9),(1,7),(1,2)], fill=C('#ffd15c'), outline=OUT)
d.polygon([(5,2),(7,3),(7,6),(5,7),(3,6),(3,3)], fill=C('#b9791f'))
d.line((2, 2, 4, 1), fill=C('#fff0a8')); d.point((5, 4), C('#ffe9a0'))
im.save('assets/sprites/ui/pickup_chip.png')

im = Image.new('RGBA', (16, 6), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
d.rectangle((0, 1, 15, 5), fill=C('#454c73'), outline=OUT)
d.line((1, 1, 14, 1), fill=C('#7d86a8'))
for x in (3, 7, 11): d.rectangle((x, 3, x + 1, 4), fill=C('#ff8c42'))
im.save('assets/sprites/world/jet.png')

svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<rect width="128" height="128" rx="18" fill="#0b0c1a"/>
<circle cx="64" cy="84" r="46" fill="#ff8c42"/>
<circle cx="64" cy="84" r="34" fill="#ffd15c"/>
<rect x="0" y="84" width="128" height="44" fill="#0b0c1a"/>
<path d="M18 84 L36 60 L52 78 L70 52 L90 78 L110 62 L112 84 Z" fill="#2a2a5a"/>
<rect x="38" y="30" width="52" height="30" rx="6" fill="#59d0ff"/>
<rect x="46" y="38" width="36" height="12" rx="3" fill="#0b0c1a"/>
<rect x="52" y="42" width="8" height="4" fill="#ffd15c"/><rect x="68" y="42" width="8" height="4" fill="#ffd15c"/>
</svg>'''
open('icon.svg', 'w').write(svg)
print('ok')
