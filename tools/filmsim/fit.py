import numpy as np, colour, time
from PIL import Image
from scipy.optimize import minimize
from lutpath import load
from ours import ours, P0, apply, L1, L2
img = load('IMG_1011.png', 1500)
ref = np.asarray(Image.open('sp_det_IMG_1011_1500.png')).astype(np.float32) / 255
# fit on a central crop for speed, full-frame scales kept by um_per_px
H, W, _ = img.shape; um = 36000 / max(H, W)
ys, xs = slice(H//4, H//4 + 500), slice(W//4, W//4 + 600)
ic, rc = img[ys, xs], ref[ys, xs]
def loss(p):
    P = list(p) + [0]
    return float(np.mean((ours(ic, P, um_per_px=um) - rc) ** 2)) * 1e4
x0 = np.array(P0[:-1]); t = time.time()
print('start', loss(x0), 'tables only', float(np.mean((apply(L2, np.clip(apply(L1, ic), 0, 1)) - rc) ** 2)) * 1e4)
r = minimize(loss, x0, method='Nelder-Mead', options={'maxiter': 220, 'xatol': 1e-3, 'fatol': 1e-3})
print('fit', r.fun, np.round(r.x, 3).tolist(), '%.0fs' % (time.time() - t))
np.save('fitP.npy', r.x)
