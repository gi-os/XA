"""Read the 4th (cyan-sensitive) layer's curve from the Superia 1600 datasheet, on the same scale
as the layer curves in xa_natura_1600.json (green peak placed where the profile's is).

python read_cyan.py superia_1600_datasheet.pdf ../natura/xa_natura_1600.json cyan_layer.json"""
import json, sys
import numpy as np
import pymupdf

pdf, profile, out = sys.argv[1:4]
d = pymupdf.open(pdf)[5].get_drawings()

def sample(i, n=80):
    pts = []
    for it in d[i]['items']:
        if it[0] == 'c':
            p0, c1, c2, p1 = (np.array([q.x, q.y]) for q in it[1:5])
            t = np.linspace(0, 1, n)[:, None]
            pts.append((1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * c1 + 3 * (1 - t) * t ** 2 * c2 + t ** 3 * p1)
    a = np.concatenate(pts)
    return a[np.argsort(a[:, 0])]

def sens(i):
    a = sample(i)
    return 400 + (a[:, 0] - 351.4) * 300 / (522.8 - 351.4), -(a[:, 1] - 174.5) / (231.7 - 174.5)

gx, gy = sens(57)                      # green-sensitive layer
cx, cy = sens(59)                      # the dashed cyan-sensitive layer
p = json.load(open(profile))['data']
ls = np.array([[np.nan if v is None else v for v in row] for row in p['log_sensitivity']], float)
off = np.nanmax(ls[:, 1]) - gy.max()  # same placement as the layer curves
wl = np.arange(380, 781, 5.0)
o = np.argsort(cx); cx, cy = np.unique(cx[o], return_index=True)[0], cy[o][np.unique(cx[o], return_index=True)[1]]
v = np.interp(wl, cx, cy + off, left=-10, right=-10)
json.dump({'source': 'Fujicolor Superia 1600 datasheet AF3-145E, section 18 (dashed curve)',
           'wavelengths': wl.tolist(), 'log_sensitivity': v.round(4).tolist()}, open(out, 'w'))
print('peak nm', wl[v.argmax()], 'peak log', v.max().round(3), 'green peak', np.nanmax(ls[:, 1]).round(3), 'span', cx.min().round(), cx.max().round())
