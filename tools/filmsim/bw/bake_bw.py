"""Black-and-white stocks for XA: the same two tables as the colour stocks (scene light ->
negative density, negative density -> print), built from characteristic curves shaped like the
published ones instead of from spektrafilm (whose open-source release has no B&W negatives).

  python bake_bw.py ../../../XA/Resources/Stocks

Each stock: a panchromatic sensitivity (how much of each of the camera's R, G, B a frame of
the film sees), a negative curve (fog, a toe, then a straight line of slope gamma), and a paper
grade. The paper is placed so an 18% grey card prints as 18% grey, and the push offsets are
solved the same way, through the phone's own density step (FilmLab's xaDensity kernel).
"""
import json, sys, numpy as np

N = 33
DMIN, DMAX = -0.2, 3.0
EV = -1.5                 # the exposure FilmLab applies before the film table
LIFT = 0.0                # B&W: no colour-lab lift of a thin negative (FilmLab passes 0 for mono stocks)

STOCKS = {
    # Tri-X 400: punchy, long straight line, generous toe; normal paper grade.
    'bleecker400': dict(w=(0.25, 0.55, 0.20), fog=0.25, gamma=0.65, toe_x=-2.25, toe_s=0.25, system=1.18),
    # Delta 3200: a slower film pushed. Fog high, shadows thin out early, soft overall.
    'delancey3200': dict(w=(0.32, 0.50, 0.18), fog=0.36, gamma=0.55, toe_x=-1.95, toe_s=0.36, system=0.98),
    # T-MAX P3200: crisp and contrasty, tabular grain; hard paper.
    'essexp3200': dict(w=(0.27, 0.53, 0.20), fog=0.30, gamma=0.80, toe_x=-1.95, toe_s=0.20, system=1.42),
}

def lin(x): return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)
def enc(x):
    x = np.clip(x, 0, 1)
    return np.where(x <= 0.0031308, 12.92 * x, 1.055 * x ** (1 / 2.4) - 0.055)

def neg(s, logE):
    t = (logE - s['toe_x']) / s['toe_s']
    return s['fog'] + s['gamma'] * s['toe_s'] * np.logaddexp(0, t)          # softplus toe, then straight

def paper(D, kp, Dc):
    # paper: more negative density -> less light on the paper -> lighter print
    # A real paper's curve: a long toe into the whites and a quick shoulder into its deep black.
    R, Dpmin = 2.25, 0.06
    Dp = Dpmin + R * (1 / (1 + np.exp(-kp * (Dc - D)))) ** 0.5
    return np.clip(10 ** -(Dp - Dpmin) * 0.965, 0, 1)                        # paper white ~0.965

def film_code(s, rgb_enc):
    E = np.maximum(np.tensordot(lin(np.clip(rgb_enc, 0, 1)), np.array(s['w']), axes=([-1], [0])), 1e-5)
    D = neg(s, np.log10(E))
    return (D - DMIN) / (DMAX - DMIN)

def through(s, scene_lin, kp, Dc, push=0, off=0.0, grey_code=None):
    """Scene linear grey -> print linear, through FilmLab's steps (flat field: no local contrast)."""
    x = enc(np.clip(scene_lin * 2 ** (EV - push), 0, 1))
    code = film_code(s, np.array([x, x, x]))
    if grey_code is not None:
        g = grey_code
        e0, e1 = g - 0.28, g - 0.06
        t = np.clip((code - e0) / (e1 - e0), 0, 1); thin = 1 - t * t * (3 - 2 * t)
        code = code + thin * LIFT
    D = code * (DMAX - DMIN) + DMIN
    gam = 1 + 0.12 * push
    D = max(D, 0) * gam + min(D, 0) + off
    return paper(D, kp, Dc)

def solve(s):
    grey = 0.18
    gc = float(film_code(s, np.array([enc(grey * 2 ** EV)] * 3)))
    Dg = gc * (DMAX - DMIN) + DMIN
    best = None
    for kp in np.linspace(0.8, 6, 261):
        # Dc so grey prints grey (bisection; print rises with Dc)
        lo, hi = Dg - 3, Dg + 3
        for _ in range(60):
            mid = (lo + hi) / 2
            if paper(Dg, kp, mid) > grey: lo = mid      # too bright: more paper density
            else: hi = mid
        Dc = (lo + hi) / 2
        a, b = through(s, grey / 1.5, kp, Dc), through(s, grey * 1.5, kp, Dc)
        slope = (np.log(b) - np.log(a)) / (2 * np.log(1.5))
        err = abs(slope - s['system'])
        if best is None or err < best[0]: best = (err, kp, Dc, slope)
    _, kp, Dc, slope = best
    offs = {}
    for p in (-2, -1, 0, 1, 2, 3):
        lo, hi = -2.0, 2.0
        for _ in range(60):
            mid = (lo + hi) / 2
            if through(s, grey, kp, Dc, push=p, off=mid, grey_code=gc) > grey: hi = mid   # more density -> lighter print
            else: lo = mid
        offs[str(p)] = [round((lo + hi) / 2, 4)] * 3
    offs['0'] = [0.0] * 3
    return gc, kp, Dc, slope, offs

def bake(out):
    meta_path = f'{out}/stocks.json'
    meta = json.load(open(meta_path))
    g = np.linspace(0, 1, N)
    b, gg, r = np.meshgrid(g, g, g, indexing='ij')                           # r fastest
    rgb = np.stack([r, gg, b], -1).reshape(-1, 3)
    for sid, s in STOCKS.items():
        gc, kp, Dc, slope, offs = solve(s)
        code = film_code(s, rgb).astype(np.float32)
        film = np.repeat(code[:, None], 3, 1).astype(np.float32)
        D = g * (DMAX - DMIN) + DMIN                                         # print table: code -> print
        pr = enc(paper(D, kp, Dc))
        pb, pg_, prr = np.meshgrid(pr, pr, pr, indexing='ij')
        # neutral input in, neutral out: each channel through the paper on its own (the app makes the frame mono)
        printt = np.stack([prr, pg_, pb], -1).reshape(-1, 3).astype(np.float32)
        film.tofile(f'{out}/{sid}_film.bin'); printt.tofile(f'{out}/{sid}_print.bin')
        meta[sid] = {'film': f'xa_{sid}_bw', 'print': 'xa_bw_paper', 'size': N, 'dmin': [DMIN] * 3, 'dmax': [DMAX] * 3,
                     'ev': EV, 'push_offset': offs, 'grey_code': round(gc, 4), 'mono': True,
                     'paper': {'k': round(float(kp), 3), 'dc': round(float(Dc), 4)}, 'system_gamma': round(float(slope), 3)}
        print(sid, 'grey code', round(gc, 3), 'paper k', round(float(kp), 2), 'Dc', round(float(Dc), 3), 'system', round(float(slope), 3), offs)
    json.dump(meta, open(meta_path, 'w'), indent=2)

if __name__ == '__main__':
    bake(sys.argv[1])
