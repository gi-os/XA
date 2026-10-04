"""Gio's black-and-white boxes (tools/boxes/bw/*.svg, Oct 2026), one face per speed:
box_<id>_<ei>.jpg, 640x400 at 1.5x. The tape and DX strip are drawn by the app, so the SVG's
hidden tape and its DX strip are left off; the big number is re-set for each speed.

  python render_bw.py <archivo instances dir> <out dir>

Archivo is a variable font and resvg ignores font-variation-settings, so each weight/width the
faces use is a static instance (fontTools varLib.instancer) named ArchW<wght>w<wdth>[i]."""
import io, math, re, sys, resvg_py
from PIL import Image, ImageFont
FONTS, OUT = sys.argv[1], sys.argv[2]
ISO = [12, 16, 20, 25, 32, 40, 50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800,
       1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000, 6400, 8000, 10000, 12800]
# file, id, rated, big number's text as drawn, and the room it may take (px on the 640 face)
FACES = [('bleecker-400.svg', 'bleecker400', 400, '>400</text>', 340),
         ('delancey-3200.svg', 'delancey3200', 3200, '>3200</text>', 520),
         ('essex-p3200.svg', 'essexp3200', 3200, '>3200</text>', 440)]
def nearest(v): return min(ISO, key=lambda i: abs(math.log2(i / v)))
def fonts(s):
    def fix(m):
        st = m.group(0)
        w = re.search(r'font-weight: (\d+)', st); d = re.search(r"'wdth' (\d+)", st)
        it = 'i' if 'italic' in st else ''
        fam = f"Arch{w.group(1) if w else 400}w{d.group(1) if d else 100}{it}"
        st = st.replace('font-family: Archivo, sans-serif', f"font-family: '{fam}'")
        return re.sub(r'font-weight: \d+;|font-style: italic;', '', st)
    return re.sub(r'style="[^"]*Archivo[^"]*"', fix, s)
for fn, sid, rated, big, room in FACES:
    src = open(f'{sys.path[0]}/bw/{fn}').read()
    src = re.sub(r'<svg [^>]*>', '<svg xmlns="http://www.w3.org/2000/svg" width="960" height="600" viewBox="0 0 640 400">', src, 1)
    src = re.sub(r'<g style="opacity: 0;.*?</g>', '', src, flags=re.S)                  # the hidden tape
    src = re.sub(r'<rect x="(\d+)" y="40[13](\.5)?".*?>(</rect>)?', '', src)            # the DX strip
    src = fonts(src)
    tag = re.search(r'<text[^>]*' + re.escape(big), src).group(0)
    x = float(re.search(r' x="([\d.]+)"', tag).group(1)); y = float(re.search(r' y="([\d.]+)"', tag).group(1))
    size = float(re.search(r'font-size="([\d.]+)"', tag).group(1))
    fam = re.search(r"font-family: '([^']+)'", tag).group(1)
    f = ImageFont.truetype(f'{FONTS}/{fam}.ttf', int(size))
    for p in range(-2, 3):
        ei = nearest(rated * 2 ** p)
        k = min(1, room / f.getlength(str(ei)))
        t = tag.replace(big, f'>{ei}</text>').replace('<text ', f'<text transform="translate({x} {y}) scale({k:.4f}) translate({-x} {-y})" ', 1)
        svg = src.replace(tag, t)
        png = bytes(resvg_py.svg_to_bytes(svg_string=svg, font_dirs=[FONTS], skip_system_fonts=True))
        Image.open(io.BytesIO(png)).convert('RGB').save(f'{OUT}/box_{sid}_{ei}.jpg', quality=86, optimize=True)
        print(sid, ei, round(k, 2))
