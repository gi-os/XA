import numpy as np, json, glob, time, sys
from PIL import Image
from scipy.ndimage import gaussian_filter, map_coordinates
import colour
B = glob.glob('build/lut_bundles/*portra400*2lut*')[0]
meta = json.load(open(B + '/bundle.json'))
def read_cube(p):
    n = None; rows = []
    for line in open(p):
        s = line.strip()
        if s.startswith('LUT_3D_SIZE'): n = int(s.split()[1])
        elif s and (s[0].isdigit() or s[0] == '-'): rows.append([float(x) for x in s.split()])
    a = np.array(rows, np.float32).reshape(n, n, n, 3)   # [b][g][r] order in .cube
    return a
def apply(lut, img):
    n = lut.shape[0]; x = np.clip(img, 0, 1) * (n - 1)
    out = np.empty_like(img)
    coords = [x[..., 2].ravel(), x[..., 1].ravel(), x[..., 0].ravel()]
    for c in range(3): out[..., c] = map_coordinates(lut[..., c], coords, order=1).reshape(img.shape[:2])
    return out
L1 = read_cube(glob.glob(B + '/*_film.cube')[0]); L2 = read_cube(glob.glob(B + '/*_print.cube')[0])
dmin = np.array(meta['wires']['cmy_film']['d_min']); dmax = np.array(meta['wires']['cmy_film']['d_max'])
def load(p, edge):
    im = Image.open(p).convert('RGB'); w,h = im.size; k = edge/max(w,h)
    return np.asarray(im.resize((round(w*k), round(h*k)), Image.LANCZOS)).astype(np.float32)/255
def phone_path(img, grain=True, halation=True, seed=1):
    t = time.time()
    x = img.copy()
    if halation:
        # Light that gets through bounces off the base into the red layer: blur the brightest light, add to red.
        lin = colour.cctf_decoding(x, 'sRGB') * 2.88
        hot = np.clip(lin - 1.0, 0, None)
        h = gaussian_filter(hot, sigma=(x.shape[1] / 1200 * 18, x.shape[1] / 1200 * 18, 0))
        lin = lin + h * np.array([0.35, 0.08, 0.0])
        x = colour.cctf_encoding(np.clip(lin / 2.88, 0, 1), 'sRGB').astype(np.float32)
    code = apply(L1, x)
    if grain:
        D = code * (dmax - dmin) + dmin
        rng = np.random.default_rng(seed)
        cell = max(1.0, x.shape[1] / 1600)
        n = gaussian_filter(rng.standard_normal(D.shape).astype(np.float32), sigma=(cell * 0.7, cell * 0.7, 0))
        n /= n.std() + 1e-6
        # Grain is strongest where there is density but not too much (Poisson-like): sigma ~ sqrt(D)
        amp = 0.045 * np.sqrt(np.clip(D, 0.02, None)) * np.array([0.9, 1.0, 1.3])
        D = D + n * amp
        code = (D - dmin) / (dmax - dmin)
    out = apply(L2, np.clip(code, 0, 1))
    return np.clip(out, 0, 1), time.time() - t
if __name__ == '__main__':
    src = {'stadium': 'stadium.png', 'hand': 'in1600.png'}
    for name in src:
        img = load(src[name], 900)
        o, dt = phone_path(img)
        Image.fromarray((o*255+0.5).astype(np.uint8)).save(f'p_{name}.jpg', quality=92)
        o2, _ = phone_path(img, grain=False, halation=False)
        Image.fromarray((o2*255+0.5).astype(np.uint8)).save(f'p0_{name}.jpg', quality=92)
        print(name, f'{dt:.2f}s numpy')
