"""Calibrate each baked stock's exposure and its push/pull printing.

ev: the exposure (stops) that puts an 18% grey card on the negative so it prints as 18% grey
(sRGB 0.461). A phone frame is already exposed for its middle tones, so this is the neutral place
to start. The old single −0.9 EV left every stock about 0.6 stop bright.

push_offset: a pushed roll gets less light and longer development (contrast γ = 1 + 0.12·push);
the lab then prints it back to a normal middle grey. These are the density offsets, per channel,
that the printer adds for each push from −2 to +3, so a push changes contrast, shadows and grain
but not overall brightness.

python calibrate_ev.py ../../XA/Resources/Stocks
"""
import json, sys
import numpy as np
from scipy.ndimage import map_coordinates

S = sys.argv[1].rstrip('/') + '/'
meta = json.load(open(S + 'stocks.json'))
GREY = 0.4614   # sRGB of 18% linear

def load(n, k):
    return np.fromfile(S + n, dtype=np.float32).reshape(k, k, k, 3)  # [b][g][r], red fastest

def look(t, x):
    k = t.shape[0] - 1
    f = np.clip(np.asarray(x, float).reshape(-1, 3), 0, 1) * k
    return np.stack([map_coordinates(t[..., c], [f[:, 2], f[:, 1], f[:, 0]], order=1) for c in range(3)], -1)

dec = lambda x: np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)
enc = lambda x: np.where(x <= 0.0031308, x * 12.92, 1.055 * np.clip(x, 0, None) ** (1 / 2.4) - 0.055)

for k, m in meta.items():
    n = m['size']
    film, prnt = load(k + '_film.bin', n), load(k + '_print.bin', n)
    dmin, dmax = np.array(m['dmin']), np.array(m['dmax'])
    code = lambda ev: look(film, enc(np.clip(np.full(3, dec(GREY) * 2 ** ev), 0, 1)))[0]
    lo, hi = -4.0, 1.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if look(prnt, code(mid))[0, 1] > GREY: hi = mid
        else: lo = mid
    ev = (lo + hi) / 2
    D0 = code(ev) * (dmax - dmin) + dmin
    offs = {}
    for p in range(-2, 4):
        D = code(ev - p) * (dmax - dmin) + dmin
        gam = 1 + 0.12 * p
        D = np.maximum(D, 0) * gam + np.minimum(D, 0)
        offs[str(p)] = [round(float(v), 4) for v in (D0 - D)]
    m['ev'] = round(ev, 3)
    m['push_offset'] = offs
    print(k, m['ev'], offs['1'], offs['2'])
json.dump(meta, open(S + 'stocks.json', 'w'), indent=1)
