"""Bake XA's film stocks: spektrafilm 2lut tables → XA/Resources/Stocks.

Each stock gets two 33³ tables as raw little-endian Float32 RGB, red fastest (the order
Core Image's colour cube wants), and one line in stocks.json with its density wire.
Run from a folder where `bake.py` has written build/lut_bundles (see README)."""
import glob, json, os, sys
import numpy as np
from lutpath import read_cube

STOCKS = {  # XA id: (bundle key, film, print)
    'bowery400': ('portra400', 'kodak_portra_400', 'kodak_portra_endura'),
    'bowery800': ('portra800', 'kodak_portra_800', 'kodak_portra_endura'),
    'coney200': ('gold200', 'kodak_gold_200', 'kodak_portra_endura'),
    'chelsea100': ('ektar100', 'kodak_ektar_100', 'kodak_portra_endura'),
    'prospect200': ('c200', 'fujifilm_c200', 'fujifilm_crystal_archive_typeii'),
    'canal500t': ('vision3500t', 'kodak_vision3_500t', 'kodak_2383'),
    'orchard400': ('xtra400', 'fujifilm_xtra_400', 'fujifilm_crystal_archive_typeii'),
    # Natura 1600 / Superia 1600, profile read from Fujifilm's datasheet (tools/filmsim/natura)
    'ludlow1600': ('xanatura', 'xa_natura_1600', 'fujifilm_crystal_archive_typeii'),
}
out = sys.argv[1]
meta = {}
for xa, (key, film, paper) in STOCKS.items():
    b = glob.glob(f'build/lut_bundles/*_{key}_*2lut*')[0]
    m = json.load(open(b + '/bundle.json'))
    for role, pat in (('film', '*_film.cube'), ('print', '*_print.cube')):
        t = read_cube(glob.glob(f'{b}/{pat}')[0])            # [b][g][r][3]
        t.astype('<f4').tofile(os.path.join(out, f'{xa}_{role}.bin'))
    w = m['wires']['cmy_film']
    meta[xa] = {'film': film, 'print': paper, 'size': t.shape[0], 'dmin': w['d_min'], 'dmax': w['d_max'],
                'gain': m['input_exposure']['gain'], 'spektrafilm': m['provenance']['spektrafilm_version']}
json.dump(meta, open(os.path.join(out, 'stocks.json'), 'w'), indent=1)
print(json.dumps(meta, indent=1)[:600])
