import numpy as np, time, colour, sys
from PIL import Image
from spektrafilm_lut_creator.builders import BundleBuilder
from spektrafilm_lut_creator.bundles import BundleSpec
from spektrafilm_lut_creator.color_spaces import decode_cctf, encode_cctf, input_exposure_gain, get as getcs
from lutpath import load, apply, read_cube
import glob, json
film, paper = 'kodak_portra_400', 'kodak_portra_endura'
spec = BundleSpec(film_profile=film, print_profiles=(paper,), input_color_space="sRGB", output_color_space="sRGB", topology="2lut", resolution=33)
b = BundleBuilder(spec)
pipe = b._make_pipeline(spec, getcs("sRGB"), getcs("sRGB"), paper)
gain = input_exposure_gain("sRGB", spec.stops_above_midgray)
B = glob.glob('build/lut_bundles/*portra400*2lut*')[0]
L1 = read_cube(glob.glob(B + '/*_film.cube')[0]); L2 = read_cube(glob.glob(B + '/*_print.cube')[0])
for name in ['IMG_0682', 'IMG_1011']:
    img = load(name + '.png', 900)
    t = time.time()
    ref = np.asarray(pipe.process((decode_cctf(img, 'sRGB') * gain).astype(np.float32)))
    ref = np.clip(encode_cctf(ref, 'sRGB'), 0, 1); tr = time.time() - t
    t = time.time(); fast = apply(L2, np.clip(apply(L1, img), 0, 1)); tf = time.time() - t
    lab = lambda x: colour.XYZ_to_Lab(colour.sRGB_to_XYZ(x))
    de = colour.delta_E(lab(ref), lab(fast), method='CIE 2000')
    print(name, 'model %.1fs  tables %.2fs  dE2000 mean %.2f  p95 %.2f  p99.9 %.2f' % (tr, tf, de.mean(), np.percentile(de, 95), np.percentile(de, 99.9)), flush=True)
