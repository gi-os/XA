import io, re, sys, resvg_py
from PIL import Image
sys.path.insert(0, '/tmp/bx'); from faces import FACES
OUT = sys.argv[1]
def fit(x, y, size, maxw, adv, suffix, ls, ei):
    w = suffix + sum(adv[int(d)] * size + ls for d in str(ei))
    s = min(1, maxw / w)
    return f'translate({x} {y}) scale({s:.4f}) translate({-x} {-y})'
for sid, (rated, body, F, _) in FACES.items():
    for p in range(-2, 3):
        ei = int(rated * 2 ** p)
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 400" width="960" height="600">'
               + body.replace('{fit}', fit(*F, ei)).replace('{ei}', str(ei)) + '</svg>')
        # resvg ignores font-stretch on the variable font: squeeze the condensed lines by hand.
        def squeeze(m):
            x = float(re.search(r' x="([\d.]+)"', m.group(0)).group(1))
            return m.group(0).replace('<text ', f'<text transform="translate({x} 0) scale(.74 1) translate({-x} 0)" ', 1)
        svg = re.sub(r'<text [^>]*font-stretch: 62%[^>]*>', squeeze, svg)
        png = bytes(resvg_py.svg_to_bytes(svg_string=svg, font_dirs=['/tmp/bx/fonts'], skip_system_fonts=True))
        im = Image.open(io.BytesIO(png)).convert('RGB')
        im.save(f'{OUT}/box_{sid}_{ei}.jpg', quality=86, optimize=True, progressive=False)
    print(sid)
