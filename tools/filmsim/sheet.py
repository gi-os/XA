import numpy as np, glob, json, time
from PIL import Image, ImageDraw
from lutpath import load, read_cube
import ours as O
P = list(np.load('fitP.npy'))
def use(key):
    B = glob.glob(f'build/lut_bundles/*{key}*2lut*')[0]; m = json.load(open(B + '/bundle.json'))
    O.L1 = read_cube(glob.glob(B + '/*_film.cube')[0]); O.L2 = read_cube(glob.glob(B + '/*_print.cube')[0])
    O.dmin = np.array(m['wires']['cmy_film']['d_min']); O.dmax = np.array(m['wires']['cmy_film']['d_max'])
stocks = [('portra400', 'PORTRA 400'), ('portra800', 'PORTRA 800'), ('gold200', 'GOLD 200'), ('ektar100', 'EKTAR 100'), ('c200', 'FUJI C200'), ('vision3500t', 'VISION3 500T')]
EV = -0.9
tw = 420
rows = []
for n in ['IMG_0682', 'IMG_1011']:
    img = load(n + '.png', 1200)
    # exposure: scale the scene light before the film sees it
    img_ev = O.enc(np.clip(O.dec(img) * 2 ** EV, 0, 1)).astype(np.float32)
    row = [('iPhone', img)]
    for key, title in stocks:
        use(key); t = time.time()
        row.append((title, O.ours(img_ev, P + [0.012], grain_seed=5)))
    rows.append(row)
th = int(tw * rows[0][0][1].shape[0] / rows[0][0][1].shape[1])
c = Image.new('RGB', (len(rows[0]) * (tw + 8), len(rows) * (th + 30)), 'black'); d = ImageDraw.Draw(c)
for r, row in enumerate(rows):
    for i, (t, a) in enumerate(row):
        im = Image.fromarray((np.clip(a, 0, 1) * 255 + .5).astype(np.uint8)).resize((tw, th), Image.LANCZOS)
        c.paste(im, (i * (tw + 8), r * (th + 30) + 24)); d.text((i * (tw + 8) + 4, r * (th + 30) + 6), t, fill='white')
c.save('stocks_sheet.jpg', quality=88)
print(c.size)
