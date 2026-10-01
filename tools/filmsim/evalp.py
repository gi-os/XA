import numpy as np, colour, time
from PIL import Image
from lutpath import load
from ours import ours, apply, L1, L2
P = list(np.load('fitP.npy')) + [0]
lab = lambda x: colour.XYZ_to_Lab(colour.sRGB_to_XYZ(x))
for n in ['IMG_1011', 'IMG_0682']:
    img = load(n + '.png', 1500)
    ref = np.asarray(Image.open(f'sp_det_{n}_1500.png')).astype(np.float32) / 255
    tab = apply(L2, np.clip(apply(L1, img), 0, 1))
    t = time.time(); o = ours(img, P); dt = time.time() - t
    d0 = colour.delta_E(lab(ref), lab(tab), method='CIE 2000'); d1 = colour.delta_E(lab(ref), lab(o), method='CIE 2000')
    print(n, 'tables-only dE mean %.2f p95 %.2f | ours dE mean %.2f p95 %.2f | %.2fs numpy' % (d0.mean(), np.percentile(d0, 95), d1.mean(), np.percentile(d1, 95), dt))
