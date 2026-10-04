"""Render the black-and-white stock boxes, one face per speed (box_<id>_<ei>.jpg), like render.py.
  python render_bw.py <fonts dir> <out dir>"""
import io, sys, resvg_py
from PIL import Image, ImageFont
from faces_bw import F
FONTS, OUT = sys.argv[1], sys.argv[2]
ISO = [12, 16, 20, 25, 32, 40, 50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800,
       1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000, 6400, 8000, 10000, 12800]
# where each face's big number sits: x, y, size, room, font file, letter spacing
FIT = {'delancey3200': (248, 318, 150, 372, 'Anton-400.ttf', 2),
       'essexp3200': (348, 306, 140, 236, 'BebasNeue-400.ttf', 2),
       'bleecker400': (174, 338, 168, 330, 'DMSerifDisplay-400.ttf', 0)}
def nearest(v): return min(ISO, key=lambda i: abs(__import__('math').log2(i / v)))
for sid, (rated, body) in F.items():
    x, y, size, room, font, ls = FIT[sid]
    f = ImageFont.truetype(f'{FONTS}/{font}', size)
    for p in range(-2, 3):
        ei = nearest(rated * 2 ** p)
        w = f.getlength(str(ei)) + ls * (len(str(ei)) - 1)
        k = min(1, room / w)
        num = body.replace(f'<text x="{x}" y="{y}"', f'<text transform="translate({x} {y}) scale({k:.4f}) translate({-x} {-y})" x="{x}" y="{y}"', 1)
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 400" width="960" height="600">'
               + num.replace('{ei}', str(ei)) + '</svg>')
        png = bytes(resvg_py.svg_to_bytes(svg_string=svg, font_dirs=[FONTS], skip_system_fonts=True))
        Image.open(io.BytesIO(png)).convert('RGB').save(f'{OUT}/box_{sid}_{ei}.jpg', quality=86, optimize=True)
        print(sid, ei, round(k, 2))
