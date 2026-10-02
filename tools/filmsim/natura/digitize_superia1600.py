"""Read the curves out of Fujifilm's Superia 1600 datasheet (AF3-145E) and build a spektrafilm
film profile for it. Natura 1600 was Superia 1600 sold under another name in Japan.

The datasheet's plots are vector paths, so the curves are read exactly, not traced by eye:
each Bézier segment is sampled and mapped through the plot's own grid lines.

Everything the datasheet does not publish (the dyes' individual spectra, the spectral
upsampling window, the coupler model) is kept from spektrafilm's Fujifilm X-tra 400 profile,
the closest stock it has (the same Superia family). That profile is CC BY-SA 4.0 by Andrea
Volpato; this derived profile is CC BY-SA 4.0 too, and says what was changed.

python digitize_superia1600.py superia_1600_datasheet.pdf fujifilm_xtra_400.json out.json
"""
import json, sys
import numpy as np
import pymupdf

pdf, template, out = sys.argv[1:4]
page = pymupdf.open(pdf)[5]
drawings = page.get_drawings()

def sample(path_index, n=60):
    pts = []
    for it in drawings[path_index]['items']:
        if it[0] == 'c':
            p0, c1, c2, p1 = (np.array([q.x, q.y]) for q in it[1:5])
            t = np.linspace(0, 1, n)[:, None]
            pts.append((1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * c1 + 3 * (1 - t) * t ** 2 * c2 + t ** 3 * p1)
        elif it[0] == 'l':
            p0, p1 = (np.array([q.x, q.y]) for q in it[1:3])
            t = np.linspace(0, 1, 8)[:, None]
            pts.append((1 - t) * p0 + t * p1)
    a = np.concatenate(pts)
    return a[np.argsort(a[:, 0])]

# Plot 17, characteristic curves: grid gives log H = −4 at x 84.6, 0 at x 258.5; D = 0 at y 291.4, 4 at y 118.4.
def char(i):
    a = sample(i)
    return -4 + (a[:, 0] - 84.6) / ((258.5 - 84.6) / 4), (291.4 - a[:, 1]) / ((291.4 - 118.4) / 4)
# Plot 18, spectral sensitivity: 400 nm at x 351.4, 700 at 522.8; one log unit = 231.7 − 174.5.
def sens(i):
    a = sample(i)
    return 400 + (a[:, 0] - 351.4) * 300 / (522.8 - 351.4), -(a[:, 1] - 174.5) / (231.7 - 174.5)
# Plot 20, spectral dye density: 400 nm at x 345.7, 700 at 527.1; D 0 at y 557.9, 2 at 440.3.
def dye(i):
    a = sample(i)
    return 400 + (a[:, 0] - 345.7) * 300 / (527.1 - 345.7), (557.9 - a[:, 1]) / ((557.9 - 440.3) / 2)

CHAR = {'red': 40, 'green': 41, 'blue': 39}
SENS = {'red': 58, 'green': 57, 'blue': 56}       # 59 is the cyan-sensitive 4th layer (not modelled)
MID, MIN = 68, 64

t = json.load(open(template))
d = t['data']
wl = np.array(d['wavelengths'], float)
le = np.array(d['log_exposure'], float)
tdc = np.array(d['density_curves'], float)
tls = np.array(d['log_sensitivity'], float)

def interp(x, y, grid, fill='extrapolate'):
    o = np.argsort(x); x, y = x[o], y[o]
    x, idx = np.unique(x, return_index=True); y = y[idx]
    v = np.interp(grid, x, y, left=np.nan, right=np.nan)
    if fill == 'extrapolate':
        # Toe flat below the data, shoulder carried on at the last slope above it.
        lo, hi = x[0], x[-1]
        v = np.where(grid < lo, y[0], v)
        k = (y[-1] - y[-8]) / (x[-1] - x[-8])
        v = np.where(grid > hi, y[-1] + k * (grid - hi), v)
    return v

# Density curves above base, in the template's exposure frame: the ISO speed point
# (0.15 over base fog, green) is put where the template has it.
curves = {c: char(i) for c, i in CHAR.items()}
def speed_point(x, y):
    y0 = y - y.min(); o = np.argsort(x)
    return float(np.interp(0.15, y0[o], x[o]))
g_le = le[np.argmin(np.abs(tdc[:, 1] - 0.15))]
shift = g_le - speed_point(*curves['green'])
dc = np.stack([interp(curves[c][0] + shift, curves[c][1] - curves[c][1].min(), le) for c in ('red', 'green', 'blue')], 1)

# Log sensitivity: the datasheet's shapes and the gaps between layers; the green peak placed
# where the template's is, so the exposure scale stays the template's.
s = {c: sens(i) for c, i in SENS.items()}
ls = np.stack([interp(s[c][0], s[c][1], wl, fill=None) for c in ('red', 'green', 'blue')], 1)
off = np.nanmax(tls[:, 1]) - np.nanmax(ls[:, 1])
ls = ls + off
ls = np.where(np.isnan(ls), -10.0, ls)   # outside the plotted range: next to no sensitivity

base = interp(*dye(MIN), wl, fill=None)
mid = interp(*dye(MID), wl, fill=None)
base = np.where(np.isnan(base), np.array(d['base_density'], float), base)
mid = np.where(np.isnan(mid), np.array(d['midscale_neutral_density'], float), mid)

d['density_curves'] = dc.tolist()
d['log_sensitivity'] = [[None if np.isnan(v) else float(v) for v in row] for row in ls]
d['base_density'] = base.tolist()
d['midscale_neutral_density'] = mid.tolist()
# The grain's layer split follows the new curves in proportion.
lay = np.array(d['density_curves_layers'], float)
scale = np.where(tdc > 1e-6, dc / np.maximum(tdc, 1e-6), 1)[:, None, :]
d['density_curves_layers'] = np.nan_to_num(lay * scale).tolist()
t['info'].update({'stock': 'xa_natura_1600', 'name': 'XA Natura 1600 (from Fujicolor Superia 1600 AF3-145E)'})
t['metadata']['license'] += (' MODIFIED for XA: density curves, log sensitivity, base and mid-scale densities replaced by '
                             'curves read from the Fujicolor Superia 1600 datasheet (AF3-145E); dye spectra, spectral '
                             'upsampling and coupler model kept from fujifilm_xtra_400.')
json.dump(t, open(out, 'w'))
print('shift', round(shift, 3), 'sens offset', round(off, 3))
print('density at le 0 (R,G,B):', dc[np.argmin(np.abs(le))].round(3), ' template:', tdc[np.argmin(np.abs(le))].round(3))
print('sens peaks (nm):', [int(wl[np.nanargmax(ls[:, c])]) for c in range(3)], 'values', np.nanmax(ls, 0).round(2), 'template', np.nanmax(tls, 0).round(2))
