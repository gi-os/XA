import numpy as np, glob, json
from scipy.ndimage import gaussian_filter
from lutpath import apply, read_cube
B = glob.glob('build/lut_bundles/*portra400*2lut*')[0]
meta = json.load(open(B + '/bundle.json'))
L1 = read_cube(glob.glob(B + '/*_film.cube')[0]); L2 = read_cube(glob.glob(B + '/*_print.cube')[0])
dmin = np.array(meta['wires']['cmy_film']['d_min']); dmax = np.array(meta['wires']['cmy_film']['d_max'])
GB = 0.9
DB = 0.6
G = meta['input_exposure']['gain']
def dec(x): return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)
def enc(x): x = np.clip(x, 0, None); return np.where(x <= 0.0031308, x * 12.92, 1.055 * x ** (1 / 2.4) - 0.055)
def blur(x, s): return gaussian_filter(x, sigma=(s, s, 0)) if s > 0.05 else x
# px: the frame is 36mm across, so one pixel is 36000/width microns
def ours(img, P, grain_seed=None, um_per_px=None):
    h, w, _ = img.shape
    um = um_per_px or 36000 / max(w, h)
    sc_w, sc_s, ha_r, ha_g, ha_s, k_c, s_c, us_a, us_s, k_t, s_t, g_amp = P
    lin = dec(img) * G
    lin = (1 - sc_w) * lin + sc_w * blur(lin, sc_s / um)
    hal = blur(lin, ha_s / um)
    lin = lin + hal * np.array([ha_r, ha_g, 0.0])
    code = apply(L1, np.clip(enc(lin / G), 0, 1))
    D = code * (dmax - dmin) + dmin
    D = D + k_c * (D - blur(D, s_c / um)) + k_t * (D - blur(D, s_t / um))
    if DB > 0: D = blur(D, DB)   # the dye clouds soften the image as they form
    if grain_seed is not None and g_amp > 0:
        rng = np.random.default_rng(grain_seed)
        # Dye clouds in the three layers sit on top of each other: mostly shared, a little each.
        common = rng.standard_normal(D.shape[:2] + (1,)).astype(np.float32)
        own = rng.standard_normal(D.shape).astype(np.float32)
        n = blur(np.sqrt(0.85) * common + np.sqrt(0.15) * own, GB)
        n /= n.std() + 1e-6
        D = D + n * g_amp * np.sqrt(np.clip(D - dmin, 0.01, None)) * np.array([1.05, 1.86, 2.05])
    out = apply(L2, np.clip((D - dmin) / (dmax - dmin), 0, 1))
    if us_a > 0:
        out = out + us_a * (out - blur(out, us_s))
    return np.clip(out, 0, 1)
P0 = [0.251, 13.078, 0.055, 0.015, 39.312, 0.485, 9.917, 0.649, 1.217, 0.1, 200.0, 0.03]
