"""Bake spektrafilm's sublayer grain into grain.json (next to stocks.json), as granularity per density.

spektrafilm develops grain per dye layer (cyan, magenta, yellow, read as R, G, B) and per
sublayer (fast, mid and slow emulsions: big, middling and small particles). Each sublayer's
particle count in a pixel is Poisson-binomial, so a pixel's density variance is

    Var = sum_s  D_s * od_s * (1 - u * D_s / Dmax_s)        od_s = Dmax_total * a_s / pixel area

with D_s the sublayer's share of the density (from the stock's layer curves), a_s its particle
area and u the uniformity (model/grain.py, apply_grain_to_density_layers). Variance times pixel
area does not depend on the pixel (Selwyn's law): that product, G = Var * area, is what is
baked here, as its square root (density x um), for each sublayer and channel at 33 densities
from 0 to the stock's dmax. FilmLab draws the grain from it at any scan's pixel size.

    $SP/venv/bin/python tools/filmsim/grain_bake.py XA/Resources/Stocks
"""
import json, sys
import numpy as np
from spektrafilm.profiles.io import load_profile
from spektrafilm.runtime.params_schema import GrainParams
from spektrafilm.model.density_curves import interp_density_cmy_layers

N = 33


def bake(film):
    p = load_profile(film)
    curves = np.asarray(p.data.density_curves, dtype=float)
    layers = np.asarray(p.data.density_curves_layers, dtype=float)
    normalized = curves - np.nanmin(curves, axis=0)   # as develop() hands them to apply_grain
    g = GrainParams()
    dmax_layers = np.nanmax(layers, axis=0)            # [sublayer, channel]
    dmax_total = np.sum(dmax_layers, axis=0)           # [channel]
    frac = dmax_layers / dmax_total[None, :]
    dmin_layers = frac * np.array(g.density_min)[None, :]
    dmax_layers = dmax_layers + dmin_layers
    area = g.particle_area_um2 * np.array(g.particle_scale)[None, :] * np.array(g.particle_scale_layers)[:, None]
    top = float(np.nanmax(normalized))
    d = np.linspace(0, top, N)
    # the sublayers' densities for a grey ramp of each channel's density
    ramp = np.repeat(d[:, None, None], 3, axis=2)      # [N, 1, 3]
    dl = interp_density_cmy_layers(ramp.copy(), normalized, layers, positive_film=p.info.type == 'positive')[:, 0]  # [N, sublayer, channel]
    dl = dl + dmin_layers[None]
    u = np.array(g.uniformity)[None, None, :]
    pr = np.clip(dl / dmax_layers[None], 1e-6, 1 - 1e-6)
    od_area = dmax_layers[None] * (area[None] / frac[None])  # od * pixel area, per sublayer and channel
    var_area = dl * od_area * (1 - u * pr)              # [N, sublayer, channel], density^2 * um^2
    cloud_um = np.sqrt(dmax_layers * area / frac) * g.blur_dye_clouds_um   # [sublayer, channel]
    return top, np.sqrt(np.maximum(var_area, 0)), cloud_um


def main(folder):
    stocks = json.load(open(folder + '/stocks.json'))
    out = {}
    for sid, s in stocks.items():
        film = s.get('film', '')
        if film.startswith('xa_'):
            continue   # XA's own profiles (Natura 1600, the black-and-white films): no layer data
        top, sd, cloud = bake(film)
        # sd: [sublayer][channel][density]; cloud_um: [sublayer][channel]
        out[sid] = {'dmax': round(top, 4),
                    'cloud_um': [[round(float(cloud[l, c]), 4) for c in range(3)] for l in range(3)],
                    'sd': [[[round(float(v), 5) for v in sd[:, l, c]] for c in range(3)] for l in range(3)]}
        mid = sd[N // 2]
        print(f"{sid:13} {film:20} dmax {top:.2f}  sd at mid (fast/mid/slow, R G B) "
              + "  ".join("/".join(f"{mid[l, c]:.3f}" for c in range(3)) for l in range(3))
              + "   clouds um " + "  ".join("/".join(f"{cloud[l, c]:.2f}" for c in range(3)) for l in range(3)))
    with open(folder + '/grain.json', 'w') as f:
        f.write('{\n' + ',\n'.join(f'"{k}": ' + json.dumps(v, separators=(',', ':')) for k, v in out.items()) + '\n}\n')


if __name__ == '__main__':
    main(sys.argv[1])
